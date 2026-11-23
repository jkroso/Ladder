# A sheet is a list of rows that work things out, like the one in Centient's
# notepad. Each row has a name and a Julia expression, and the expression can
# use the names of the rows above it the way they're written: "Wall length * 2".
# In a document it's a code block in the language `sheet`, one row to a line:
#
#     ```sheet
#     Wall length = 12m
#     Wall height = 2.4m
#     Area = wall length * wall height
#     ```
#
# This file reads a row, finds the names in an expression and works out the
# value of every row. Numbers can have units, from Units.jl: 12m, 25mm, 2hr.
# A row like `1m in cm` gives a value in another unit: 100cm. Money has
# units too: 22USD/W * 1GW is 22 billion USD.
# Columns count characters from 0, as they do in markdown.jl.

@use "github.com/jkroso/Units.jl" => Units
@use "github.com/jkroso/Units.jl/Imperial" => Imperial
@use "github.com/jkroso/Units.jl/Money" => Cash
@use "./markdown" Cell

"The language of a code block that is a sheet"
const SHEET = "sheet"

const NOT_A_NAME = "()[]{}\"'`+*/^<>!|&,;=\\"

"The index of the = that ends the name of a row, or 0 when the row has no name"
separator(chars) = begin
  q = findfirst(==('='), chars)
  q === nothing && return 0
  q < length(chars) && chars[q+1] == '=' && return 0
  any(c -> c in NOT_A_NAME, chars[1:q-1]) ? 0 : q
end

"The text of `chars[from:to]` as a cell, without the spaces around it. The caret can go as far as `limit`."
cell(chars, from, to, limit) = begin
  a = findnext(!isspace, chars, from)
  (a === nothing || a > to) && return nothing
  z = findprev(!isspace, chars, to)
  Cell(a - 1, z, max(z, limit))
end

"""
The cells of one row of a sheet: its name and its expression, or only its
expression when the row has no name. A row like ` = 2 + 2` has a name that is
empty.
"""
sheetcells(text::AbstractString) = begin
  chars = collect(text)
  n = length(chars)
  q = separator(chars)
  if q == 0
    return [something(cell(chars, 1, n, n), Cell(0, 0, n))]
  end
  # One space before the = is left alone, and one after it
  name = something(cell(chars, 1, q - 1, q - 2), Cell(0, 0, max(0, q - 2)))
  lo = min(q + 1, n)
  [name, something(cell(chars, q + 1, n, n), Cell(lo, lo, n))]
end

"The name and the expression of a row, as text"
parts(text::AbstractString) = begin
  chars = collect(text)
  cs = sheetcells(text)
  get(c) = String(chars[c.lo+1:c.hi])
  length(cs) == 1 ? ("", get(cs[1])) : (get(cs[1]), get(cs[2]))
end

"The name Julia knows a row by: \"Wall length\" is wall_length. It's empty when the row's name has no letters or digits."
ident(name::AbstractString) = begin
  s = strip(replace(lowercase(strip(name)), r"[^a-z0-9]+" => "_"), '_')
  isempty(s) ? "" : isdigit(first(s)) ? "_" * s : String(s)
end

isname(c::Char) = isletter(c) || isdigit(c) || c == '_'

"True for each character of `chars` that is code, not part of a string or a comment"
code(chars) = begin
  out = trues(length(chars))
  i = 1
  while i <= length(chars)
    c = chars[i]
    if c == '#'
      out[i:end] .= false
      break
    elseif c == '"'
      j = i + 1
      while j <= length(chars) && chars[j] != '"'
        j += chars[j] == '\\' ? 2 : 1
      end
      out[i:min(j, end)] .= false
      i = j
    end
    i += 1
  end
  out
end

"True when a name can start at `chars[i]`: after something that isn't part of a name, or after a number as in 2area"
starts(chars, i) = begin
  i == 1 && return true
  c = chars[i-1]
  # After a dot it's a field of a value, unless the dot ends a number
  c == '.' && return i > 2 && isdigit(chars[i-2])
  isname(c) || return true
  isdigit(c) || return false
  k = i - 1
  while k > 1 && (isdigit(chars[k-1]) || chars[k-1] == '.'); k -= 1 end
  k == 1 || !isname(chars[k-1])
end

"""
Where `text` uses one of `names`, as (lo, hi, name) with the columns the name
runs from and to. A name counts whatever its capitals are, and only as whole
words outside a string or a comment. The longest name wins, so "wall" doesn't
take the start of "wall length".
"""
uses(text::AbstractString, names) = begin
  chars = collect(text)
  low = map(lowercase, chars)
  free = code(chars)
  out = Tuple{Int,Int,String}[]
  for name in sort(collect(names), by=length, rev=true)
    want = map(lowercase, collect(strip(name)))
    n = length(want)
    n == 0 && continue
    for i in 1:length(chars)-n+1
      (low[i:i+n-1] == want && all(free[i:i+n-1]) && starts(chars, i)) || continue
      i + n <= length(chars) && isname(chars[i+n]) && continue
      free[i:i+n-1] .= false
      push!(out, (i - 1, i + n - 1, String(name)))
    end
  end
  sort!(out)
end

"`text` with each of `names` written as Julia knows it"
rewrite(text::AbstractString, names) = begin
  chars = collect(text)
  out = IOBuffer()
  at = 0
  for (lo, hi, name) in uses(text, names)
    print(out, String(chars[at+1:lo]), ident(name))
    at = hi
  end
  print(out, String(chars[at+1:end]))
  String(take!(out))
end

# --- a number that a drag changes ------------------------------------------------------------
#
# A row that is one number, with or without a unit, can be changed with a drag
# on what it comes to. So can a sum in a line of text. These say where that
# number is in the code, and what it is after a drag.

const UNIT = raw"[\p{L}°µ]+[²³]?(?:\^-?\d+)?"
const ONE_NUMBER = Regex("^(\\s*(?:[\\p{L}_][\\p{L}\\p{N}_]*\\s*=\\s*)?)(-?\\d+(?:\\.\\d+)?)\\s*(?:$UNIT(?:\\s*[/*]\\s*$UNIT)*)?\\s*\$")

"""
Where the number of `code` is, when the code is one number: alone, like `16`,
with a unit, like `16m` or `16m^2 / litre`, or either with a name before it,
like `l = 16m`. It gives how many characters come before the number, and how
many come before its end. It's nothing for any other code.
"""
number_at(code::AbstractString) = begin
  m = match(ONE_NUMBER, code)
  m === nothing && return nothing
  # What comes after the number is a unit, like the m of 16m, and not a name, like the area of 2area
  after = SubString(code, m.offsets[2] + ncodeunits(m[2]))
  all(w -> isdefined(units(), Symbol(rstrip(w.match, ('²', '³')))), eachmatch(r"[\p{L}°µ²³]+", after)) || return nothing
  (length(m[1]), length(m[1]) + length(m[2]))
end

"""
The number that `text` writes, `steps` steps on. A step is one of the number's
last digit: 16 goes to 17, and 2.40 goes to 2.41. A number that isn't under 0
doesn't go under it.
"""
nudged(text::AbstractString, steps::Int) = begin
  dot = findfirst('.', text)
  places = dot === nothing ? 0 : length(text) - dot
  was = parse(Float64, text)
  x = was + steps / 10.0^places
  was >= 0 && (x = max(x, 0.0))
  places == 0 ? string(round(Int, x)) : Base.Ryu.writefixed(x, places)
end

"What a row came to. `text` is its value as the row shows it, or what went wrong. `solved` is true for a row that the sheet worked out backwards, from the answer that a row under it must come to."
struct Result
  text::String
  failed::Bool
  solved::Bool
end

Result(text, failed) = Result(text, failed, false)

const NONE = Result("", false)

"Every name of `mod` that a sheet can use"
bindings(mod::Module) = begin
  out = Dict{Symbol,Any}()
  for n in names(mod; all=true)
    s = string(n)
    (n === nameof(mod) || n === :eval || startswith(s, "#") || startswith(s, "include") || !isdefined(mod, n)) && continue
    out[n] = getfield(mod, n)
  end
  out
end

const prelude = Ref{Any}(nothing)

"The currencies that a sheet has, like USD and €, from Units.jl's Money"
const CURRENCIES = (:USD, :AUD, :NZD, :EUR, :GBP, :JPY, :€, :£, :¥)

"A module that holds the units, for every sheet to use"
units() = begin
  prelude[] === nothing || return prelude[]
  mod = Module(:SheetUnits)
  money = Dict{Symbol,Any}(n => getfield(Cash, n) for n in CURRENCIES if isdefined(Cash, n))
  all = merge(bindings(Units), bindings(Imperial), money)
  Core.eval(mod, Expr(:block, [Expr(:const, Expr(:(=), n, QuoteNode(v))) for (n, v) in all]...))
  Core.eval(mod, Expr(:export, keys(all)...))
  prelude[] = mod
end

commas(s::AbstractString) = replace(s, r"(?<=\d)(?=(\d{3})+$)" => ",")

"A number the way a person writes it: 54 not 54.0, and 14,285.7 not 14285.714285714286"
shown(x::Integer) = commas(string(x))
shown(x::Bool) = string(x)
shown(x::Rational) = isone(denominator(x)) ? shown(numerator(x)) : shown(float(x))
shown(x::AbstractFloat) = begin
  isfinite(x) || return string(x)
  isinteger(x) && abs(x) < 1e15 && return shown(round(Int, x))
  (abs(x) >= 1e15 || abs(x) < 1e-4) && return string(round(x, sigdigits=6))
  # Big numbers keep fewer places after the point
  places = abs(x) >= 100 ? 2 : abs(x) >= 1 ? 4 : 6
  s = rstrip(rstrip(Base.Ryu.writefixed(Float64(x), places), '0'), '.')
  whole, part = occursin('.', s) ? split(s, '.') : (s, "")
  isempty(part) ? commas(whole) : commas(whole) * "." * part
end
# Any other kind of number, like the 3.05 that 48.3 billion USD over 15.8 billion USD comes to, shows as a float does
shown(x::Real) = shown(float(x))
shown(x::AbstractString) = repr(x)
"""
An amount of money the way a person says it: 28.3 billion USD, and not
28,300,000,000.00 USD. An amount under a million shows its cents, unless it
has none: 22 USD, 22.50 USD and 1,500 USD.
"""
shown(x::Cash.Money{code}) where code = begin
  v = Float64(x.value)
  scale = abs(v) >= 1e12 ? (1e12, " trillion") : abs(v) >= 1e9 ? (1e9, " billion") : abs(v) >= 1e6 ? (1e6, " million") : nothing
  n = scale === nothing ? cents(v) : shown(round(v / scale[1], sigdigits=3)) * scale[2]
  mark = Cash.symbols[code]
  mark == :$ ? "$n $code" : "$mark$n"
end

"An amount with its cents, like 1,500.50, or with none when it has none, like 1,500"
cents(v::Real) = begin
  whole, part = divrem(round(Int, abs(v) * 100), 100)
  (v < 0 && whole + part > 0 ? "-" : "") * commas(string(whole)) * (part == 0 ? "" : "." * lpad(part, 2, '0'))
end
shown(::Nothing) = ""
shown(f::Function) = "ƒ"
shown(x) = begin
  # The % of 1,700GW·%·yr goes into its number: 17GW·yr
  y = folded(x)
  y === x || return shown(y)
  s = sprint(show, x)
  # A number with a unit, like 28.799999999999997m², shows its number the same way
  m = match(r"^(-?[\d,]*\.?\d+(?:e[+-]?\d+)?)(\D.*)$", s)
  n = m === nothing ? nothing : tryparse(Float64, replace(m[1], "," => ""))
  n === nothing ? s : shown(n) * m[2]
end

"""
`x` without the units of it that have no dimension, like the % of
1,700GW·%·yr, which go into its number: 17GW·yr. A value with only such
units, like 85%, stays as it is, and so does any other value.
"""
folded(x) = begin
  x isa Units.AbstractCombination || return x
  parts = collect(Units.subunits(typeof(x)))
  plain(u) = Units.abstract_dimension(u) == Units.NullDimension
  (any(plain, parts) && !all(plain, parts)) || return x
  rest = filter(!plain, parts)
  # One unit to the power 1, like the USD of USD·%, is that unit itself, so the value shows as money does
  T = length(rest) == 1 && Units.power(rest[1]) == 1 ? Units.unwrap(rest[1]) : prod(u -> Units.unwrap(u)^Units.power(u), rest)
  try convert(T, x) catch; x end
end

const LONGEST = 48   # characters of a value or an error that a row shows

brief(s::AbstractString) = begin
  s = replace(first(split(s, '\n')), r"\s+" => " ")
  length(s) > LONGEST ? first(s, LONGEST - 1) * "…" : String(s)
end

"What went wrong, in a few words"
problem(err) = begin
  err isa UndefVarError && return "$(err.var) isn't a name here"
  err isa Meta.ParseError && return "This isn't finished"
  # Printing an error can fail too. A MethodError prints the types of its
  # values, and Units.jl can't print a type like the one `m^2m^2area` makes.
  try
    brief(sprint(showerror, err))
  catch
    "This can't be worked out"
  end
end

# --- a sheet that works backwards --------------------------------------------------------------
#
# A row whose expression starts with a ? is a row that the sheet works out.
# What comes after the ? is where the sheet starts to look, and it gives the
# row its unit: "? 12m". A row under it says what it must come to, with a
# second = and the answer: "Tins = ceil(litres / 4litre) = 3". The sheet then
# finds the value of the first row that makes the second one come to that.
#
#     Wall length = ? 12m
#     Area = wall length * 2.4m
#     Litres = area * 2 / (16m^2 / litre) = 6litre
#
# Here the wall is 20m long. A row with a ? is worked out from the first row
# under it that has an answer. After that row, a sheet can have another row
# with a ? and its answer. A row with a ? and no answer under it is the value
# after the ?.

"What comes after the ? of a row that the sheet works out, or nothing when the row has no ?"
unknown(expr::AbstractString) = (m = match(r"^\s*\?\s*(.*?)\s*$", expr); m === nothing ? nothing : String(m[1]))

"True when `left` is what a function's definition starts with, like f(x, y), where no value is the name of a row. `ids` are the names of the rows, as Julia knows them."
signature(left, ids) =
  left isa Symbol || (Meta.isexpr(left, :call) && left.args[1] isa Symbol && all(a -> a isa Symbol && !(a in ids), left.args[2:end]))

"""
The two sides of a row that says what it must come to, like
`ceil(litres / 4litre) = 3`: the expression and the answer. It's nothing for
any other row. `ex` is the row's expression as Julia reads it.
"""
goal(ex, ids) = ex isa Expr && ex.head == :(=) && length(ex.args) == 2 && !signature(ex.args[1], ids) ? (ex.args[1], ex.args[2]) : nothing

"How far `value` is from `target`, as a plain number. Two amounts with units give the number of the first one's unit."
apart(value, target) = (d = value - target; d isa Real ? Float64(d) : Float64(getfield(d, :value)))

"""
The number `s` that makes `f(s)` come to 0, or nothing when none is found. It
starts to look at 1. `f` can go up in steps, as a sum with `ceil` does: any
number on the step that's at 0 is an answer.
"""
solve(f) = begin
  near(y) = abs(y) < 1e-9
  a, fa = 1.0, f(1.0)
  near(fa) && return a
  # Straight on from two points, again and again, finds the answer of a sum that's smooth
  b, fb = 1.1, f(1.1)
  for _ in 1:60
    near(fb) && return b
    (isfinite(fb) && fb != fa) || break
    a, fa, b = b, fb, b - fb * (b - a) / (fb - fa)
    isfinite(b) || break
    fb = f(b)
  end
  near(fb) && isfinite(b) && return b
  # If not, find two numbers with the answer between them, and halve the room between them
  f1 = f(1.0)
  for other in Iterators.flatten(((2.0^k, 2.0^-k) for k in 1:60))
    lo, hi = minmax(1.0, other)
    flo, fhi = lo == 1.0 ? (f1, f(other)) : (f(other), f1)
    near(fhi) && return hi
    near(flo) && return lo
    (isfinite(flo) && isfinite(fhi) && sign(flo) != sign(fhi)) || continue
    for _ in 1:200
      mid = (lo + hi) / 2
      fm = f(mid)
      near(fm) && return mid
      sign(fm) == sign(flo) ? ((lo, flo) = (mid, fm)) : ((hi, fhi) = (mid, fm))
      hi - lo < 1e-12 * max(1.0, abs(hi)) && break
    end
    return nothing
  end
  nothing
end

# --- a row over a range -------------------------------------------------------------------------
#
# A row can be every value from one to another: "Wall length = 8m to 20m".
# The sheet is then many sheets, one for each value on the way. A row shows
# what it comes to at the two ends, like "19.2m² to 48m²". `cases` gives every
# one of those sheets as the rows of a table, so that a chart can draw what
# the other rows come to over the range. A sheet has one such row: its first.

"The two ends of a row over a range, like `8m to 20m`, as code. It's nothing for any other row. `names` are the names that the row can use."
ends(expr::AbstractString, names) = begin
  m = match(r"^(.*\S)\s+to\s+(\S.*)$", rewrite(expr, names))
  m === nothing || !all(code(collect(m.match))[m.offsets[1] + ncodeunits(m[1]):m.offsets[2] - 1]) ? nothing : (String(m[1]), String(m[2]))
end

"The place of the first row of `rows` that is over a range, or 0. With `own`, a row before that place doesn't count."
ranged(rows, own::Int=1) = begin
  seen = String[]
  for (i, (name, expr)) in enumerate(rows)
    i >= own && ends(expr, seen) !== nothing && return i
    isempty(ident(name)) || push!(seen, String(strip(name)))
  end
  0
end

"""
The place in `all` of the row over a range of a sheet whose rows come after
the `given` names that it has from outside it. It's the sheet's own row, so a
sheet over another sheet with a range has a range of its own. A sheet with no
such row can be over the range of a name from outside it.
"""
range_row(all, given::Int) = (k = ranged(all, given + 1); k == 0 ? ranged(all) : k)

"How many steps a range from 0 to `far` is cut into, so that each step is a round number: 20 of them or more"
steps(far::Real) = begin
  (isfinite(far) && far != 0) || return 1
  raw = abs(far) / 20
  power = 10.0^floor(log10(raw))
  step = power * (1, 2, 2.5, 5)[findlast(k -> k * power <= raw * (1 + 1e-9), (1, 2, 2.5, 5))]
  clamp(round(Int, abs(far) / step), 1, 60)
end

# --- a value in another unit -----------------------------------------------------------------
#
# "1m in cm" comes to 100cm. Julia reads it as in(1m, cm), which always goes
# wrong: a unit is a type, and Julia can't look inside a type. So a sheet can
# give it this meaning without changing any code that works. With anything
# but a unit on its right, in means what it means in Julia: 3 in [1, 2, 3].

"`x` in the unit `unit`, or Julia's `x in y` when `y` isn't a unit"
into(x, unit::Type{<:Units.Unit}) = convert(unit, x)
into(x, y) = x in y

"`ex` with each `a in b` changed to a call to `into`"
converting(ex) = ex
converting(ex::Expr) = begin
  ex.head == :quote && return ex
  args = map(converting, ex.args)
  ex.head == :call && length(args) == 3 && args[1] === :in ? Expr(:call, into, args[2], args[3]) : Expr(ex.head, args...)
end

"""
Work out every row of a sheet, from the top. `rows` holds the name and the
expression of each one. A row that goes wrong says so, and the rows after it
carry on. It gives what each row comes to, and the value of each row that has
a name, under the name that Julia knows it by. `at` says where a row over a
range is: 0 at its first value, 1 at its last. The third thing that it gives
is how far apart those two values are, as a number, or nothing. The fourth is
the names of the rows, as they're written.

`prior` is what `begun` gave for the first rows: they aren't worked out again.
After each row, `each` is given the row's place and the names and values that
the sheet knows then.
"""
work(rows; at::Real=0, over::Int=ranged(rows), prior=nothing, each=nothing) = begin
  mod = Module(:Sheet)
  Core.eval(mod, Expr(:block, Expr(:const, Expr(:(=), :SheetUnits, units())), Expr(:using, Expr(:., :., :SheetUnits))))
  read(expr, names) = converting(Meta.parse(rewrite(expr, names)))
  ids(names) = Set(Symbol(ident(n)) for n in names)
  # Each row that the sheet works out, with the row that says what it must come to
  pairs, free, seen = Dict{Int,Int}(), 0, String[]
  for (i, (name, expr)) in enumerate(rows)
    if free == 0
      unknown(expr) === nothing || (free = i)
    elseif unknown(expr) === nothing
      ex = try read(expr, seen) catch; nothing end
      goal(ex, ids(seen)) === nothing || (pairs[free] = i; free = 0)
    end
    isempty(ident(name)) || push!(seen, String(strip(name)))
  end
  answers = Set(values(pairs))
  far = nothing
  names = prior === nothing ? String[] : copy(prior.names)
  named = prior === nothing ? Pair{String,Any}[] : copy(prior.named)
  assign!(mod, [Symbol(id) => value for (id, value) in named])
  keep!(name, value) = begin
    id = ident(name)
    isempty(id) && return
    assign!(mod, [Symbol(id) => value])
    filter!(n -> ident(n) != id, names)
    push!(names, String(strip(name)))
    filter!(p -> p.first != id, named)
    push!(named, id => value)
  end
  result_of(i, name, expr) = begin
    prior === nothing || i > prior.n || return prior.results[i]
    isempty(strip(expr)) && return NONE
    try
      start = unknown(expr)
      if start !== nothing
        first = isempty(start) ? 1 : Core.eval(mod, read(start, names))
        wanted = get(pairs, i, 0)
        if wanted == 0
          keep!(name, first)
          return Result(brief(Base.invokelatest(shown, first)), false)
        end
        # The value is so many times the value after the ?, which gives it its unit
        unit = first isa Number && iszero(first) ? typeof(first)(1) : first
        id = Symbol(ident(name))
        trial(s) = begin
          known = copy(names)
          isempty(ident(name)) || (assign!(mod, [id => unit * s]); push!(known, String(strip(name))))
          for (row, x) in rows[i+1:wanted-1]
            (isempty(strip(x)) || unknown(x) !== nothing) && continue
            v = Core.eval(mod, read(x, known))
            isempty(ident(row)) || (assign!(mod, [Symbol(ident(row)) => v]); push!(known, String(strip(row))))
          end
          left, right = goal(read(rows[wanted][2], known), ids(known))
          Base.invokelatest(apart, Core.eval(mod, left), Core.eval(mod, right))
        end
        s = solve(trial)
        s === nothing && return Result("No value here gives the answer below", true)
        value = round(unit * s, sigdigits=12)   # 20m, and not 20.00000000000001m
        keep!(name, value)
        return Result(brief(Base.invokelatest(shown, value)), false, true)
      end
      if i == over
        # The row is somewhere between its two values
        lo, hi = (Core.eval(mod, converting(Meta.parse(side))) for side in ends(expr, names))
        gap = hi - lo
        far = gap isa Real ? Float64(gap) : Float64(getfield(gap, :value))
        value = at == 0 ? lo : at == 1 ? hi : round(lo + gap * at, sigdigits=12)
        keep!(name, value)
        return Result(brief(Base.invokelatest(shown, value)), false)
      end
      ex = read(expr, names)
      ex isa Expr && ex.head in (:incomplete, :error) && return Result("This isn't finished", true)
      i in answers && (ex = goal(ex, ids(names))[1])   # the row shows what its own side of the = comes to
      value = Core.eval(mod, ex)
      keep!(name, value)
      Result(brief(Base.invokelatest(shown, value)), false)
    catch err
      Result(problem(err), true)
    end
  end
  results = map(enumerate(rows)) do (i, (name, expr))
    result = result_of(i, name, expr)
    each === nothing || each(i, named, names)
    result
  end
  results, named, far, names
end

"""
Give each name of `pairs` its value in the module `mod`, as `name = value`
there does. This has no code to lower, so it's much faster: a sheet over a
range gives the names of the sums that it reads at each place of the range.
"""
assign!(mod::Module, pairs) = begin
  try
    foreach(((name, _),) -> Core.declare_global(mod, name, true), pairs)
    Base.invokelatest(setglobals!, mod, pairs)
  catch
    # A name that can't be given a value this way, like a constant, says why as `name = value` does
    foreach(((name, value),) -> Core.eval(mod, Expr(:(=), name, QuoteNode(value))), pairs)
  end
  nothing
end

setglobals!(mod, pairs) = foreach(((name, value),) -> setglobal!(mod, name, value), pairs)

"""
What `work` makes of the rows of `all` over the row `over`, which is over a
range: what each of them comes to, and the names and values that it knows
after them. They come out the same at every place of the range, so the sheet
works them out once and starts from them at each place. It's nothing when
there are no such rows, or when one of them is worked out backwards, as that
can need a row under it. `cache` is where it's kept, as `tally` says.
"""
begun(all, over::Int, cache) = begin
  n = over - 1
  (n >= 1 && !any(((_, expr),) -> unknown(expr) !== nothing, all[1:n])) || return nothing
  rows = all[1:n]
  kept(cache, (:begun, rows)) do
    chains = get!(() -> Any[], cache, :sheet_chains)
    # The rows that were worked out before, as far as they're the same as these
    k, before = 0, nothing
    for c in chains
      j = 0
      while j < min(n, length(c.rows)) && c.rows[j+1] == rows[j+1]; j += 1 end
      j > k && ((k, before) = (j, c))
    end
    after = k == 0 ? Tuple{Vector{Pair{String,Any}},Vector{String}}[] : before.after[1:k]
    prior = k == 0 ? nothing : (n=k, results=before.results[1:k], named=after[k][1], names=after[k][2])
    note(i, named_now, names_now) = i > k && push!(after, (copy(named_now), copy(names_now)))
    results, named, _, names = work(rows; over=0, prior, each=note)
    filter!(c -> c.rows != rows, chains)
    pushfirst!(chains, (; rows, results, after))
    length(chains) > LINKED && pop!(chains)
    (; n, results, named, names)
  end
end

# A sheet under a page of sums is worked out again when a sum changes, as on
# each step of a drag. Two things keep that fast:
#
# - What a sheet came to is kept, by its rows and the names from outside it
#   that they read. So a sheet that doesn't read the sum that changed has
#   nothing to work out.
# - `begun` keeps the rows from outside a sheet that it worked out lately, in
#   a chain: what the sheet knew after each row. When one sum changes, the sums
#   over it are the same as before, so only that sum and the sums under it run
#   again. A sum that takes long, like one that adds up thousands of numbers,
#   then runs only when it or a sum that it reads changes.
#
# Both are kept in the `cache` that the page gives, which is the page's own,
# so they're forgotten as the rest of what the page laid out is. A sheet with
# no page keeps them here, and only some of them.

const KEPT = Dict{Any,Any}()
const KEEP = 300    # things that KEPT holds: past this many, they're all forgotten
const LINKED = 8    # chains that `begun` keeps: about as many as a page has sheets

"What `f` gives, kept in `cache` by `key`: it's worked out only the first time"
kept(f, cache, key) = begin
  haskey(cache, key) && return cache[key]
  value = f()
  cache === KEPT && length(KEPT) >= KEEP && empty!(KEPT)
  cache[key] = value
end

"""
The names of `given` that `rows` need: each one that a row uses, each one
that the expression of a needed name uses, and so on up. A sheet under a page
of sums then works out only the sums that it reads.
"""
needed(given, rows) = begin
  isempty(given) && return given
  # The rows' own names count too, so "tile price" isn't read as "tile" and "price"
  names = unique!(String[s for (name, _) in Iterators.flatten((given, rows)) for s in (String(strip(name)), ident(name)) if !isempty(s)])
  want = Set{String}()
  look(text) = foreach(((_, _, name),) -> push!(want, ident(name)), uses(text, names))
  foreach(((_, expr),) -> look(expr), rows)
  keep = falses(length(given))
  for i in reverse(eachindex(given))
    name, expr = given[i]
    id = ident(name)
    (!isempty(id) && id in want) || continue
    keep[i] = true
    look(expr)
  end
  given[keep]
end

"""
What each row of a sheet comes to. `given` holds the names that the sheet has
from outside it, like a measure of a takeoff: each with an expression for its
value, as a row has. They're worked out first, as rows over the first row
would be, so a row can use them, and a row with the same name takes the name.
What the sheet comes to is kept in `cache`: a page gives the place where it
keeps what it laid out, so that it's forgotten with the rest.
"""
tally(rows; given=(), at=nothing, cache=KEPT) = begin
  given = needed(collect(given), rows)
  all = Tuple{String,String}[given..., rows...]
  kept(cache, (:tally, all, at)) do
    mine(results) = results[length(given)+1:end]
    # With a row over a range, each row shows what it comes to at the two ends, or at the one place `at`
    over = range_row(all, length(given))
    prior = begun(all, over, cache)
    if at !== nothing || over == 0
      results = work(all; at=something(at, 0), over, prior)[1]
      # The row over a range shows that it's at one place of the range
      at !== nothing && over > 0 && !results[over].failed && (results[over] = Result(results[over].text, false, true))
      return mine(results)
    end
    map(mine(work(all; over, prior)[1]), mine(work(all; at=1, over, prior)[1])) do lo, hi
      lo.failed ? lo : hi.failed ? hi : lo.text == hi.text ? lo : Result(brief("$(lo.text) to $(hi.text)"), false)
    end
  end
end

"""
A sheet with a row over a range, as the rows of a table: one for each value
of that row, from its first to its last. The first column is that row, and
the others are the rows under it that have a name and change with it. The
first row of the table has the names. `places` says where each of the other
rows is in the range, from 0 to 1. It's nothing for a sheet with no row over
a range, or with no row that changes. It's kept in `cache`, as `tally` says.
"""
cases(rows; given=(), cache=KEPT) = begin
  given = needed(collect(given), rows)
  all = Tuple{String,String}[given..., rows...]
  over = range_row(all, length(given))
  over == 0 && return nothing
  kept(cache, (:cases, all)) do
    prior = begun(all, over, cache)
    first, _, far = work(all; over, prior)
    (far === nothing || first[over].failed) && return nothing
    n = steps(far)
    places = [k / n for k in 0:n]
    runs = [k == 0 ? first : work(all; at=places[k+1], over, prior)[1] for k in 0:n]
    # A row is a column of the table when it has a name, works at every value, and changes
    shown = [i for i in over+1:length(all) if !isempty(ident(all[i][1])) && !any(r -> r[i].failed || isempty(r[i].text), runs) && any(r -> r[i].text != runs[1][i].text, runs)]
    isempty(shown) && return nothing
    columns = [over; shown]
    table = Vector{String}[String[strip(all[i][1]) for i in columns]]
    append!(table, (String[r[i].text for i in columns] for r in runs))
    (table=table, places=places)
  end
end

"The value of each name of `rows`, under the name that Julia knows it by: wall_length for \"Wall length\""
name_values(rows) = work(rows)[2]

"The names that the expression of row `r` can use: those of the rows above it, and those that the sheet has from outside it"
known(rows, r::Int, given=()) = unique(String[strip(name) for (name, _) in Iterators.flatten((given, rows[1:r-1])) if !isempty(ident(name))])

export SHEET, Result, sheetcells, parts, ident, uses, tally, known, name_values, ident, number_at, nudged, cases
