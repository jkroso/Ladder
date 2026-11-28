# A spreadsheet is a grid of cells that work things out, like the ones in Excel
# and Numbers. In a document it's a code block in the language `spreadsheet`,
# one row to a line, with a | between the cells as a table has:
#
#     ```spreadsheet
#     | Wall  | Length | Height | Area         |
#     | North | 12m    | 2.4m   | = B2 * C2    |
#     | East  | 8m     | 2.4m   | = B3 * C3    |
#     | Total |        |        | = sum(D2:D3) |
#     ```
#
# Each column has a letter and each row has a number, so B2 is the second cell
# of the second row. A cell that starts with = is a formula: a Julia expression
# that can use the other cells by name. D2:D3 is every cell from D2 to D3 that
# has something in it. Any other cell is a number, a number with a unit from
# Units.jl, or text.
#
# This file reads the cells of a row, works out what every cell comes to, and
# changes the names in a formula when a row or a column is added or removed.
# Columns of text count characters from 0, as they do in markdown.jl.

@use "./markdown" Cell tablecells
@use "./sheet" units shown brief problem code

"The language of a code block that is a spreadsheet"
const SPREADSHEET = "spreadsheet"

"The cells of one row. A line with no | in it is one cell."
spreadcells(text::AbstractString) = begin
  cs = tablecells(text)
  isempty(cs) || return cs
  chars = collect(text)
  a = findfirst(!isspace, chars)
  a === nothing ? [Cell(0, 0, length(chars))] : [Cell(a - 1, findlast(!isspace, chars), length(chars))]
end

"The text of each cell of a row"
spreadtexts(text::AbstractString) = begin
  chars = collect(text)
  [String(chars[c.lo+1:c.hi]) for c in spreadcells(text)]
end

"True when a cell with this text is a formula"
isformula(text::AbstractString) = startswith(lstrip(text), '=')

"The letters of column `c`: A for the first, Z for the 26th, then AA"
letters(c::Int) = c <= 26 ? string('A' + c - 1) : letters((c - 1) ÷ 26) * letters((c - 1) % 26 + 1)

"The number of the column that has these letters"
column(s::AbstractString) = foldl((n, c) -> 26n + (uppercase(c) - 'A' + 1), s, init=0)

"The name of the cell in row `r`, column `c`"
cellname((r, c)) = letters(c) * string(r)

const NAME = r"^([A-Za-z]{1,2})([1-9]\d*)$"

"The row and the column of the cell that `name` names, or nothing when it isn't the name of a cell"
place(name::AbstractString) = begin
  m = match(NAME, name)
  m === nothing ? nothing : (parse(Int, m[2]), column(m[1]))
end
# A unit keeps its name, if one is ever spelled like a cell
place(name::Symbol) = isdefined(units(), name) ? nothing : place(string(name))

# --- what a cell that isn't a formula holds ------------------------------------------------

const PLAIN = r"^([-+]?)\$?((?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d*)?|\.\d+)(%?)$"
const WITH_UNIT = r"^([-+]?(?:\d+\.?\d*|\.\d+))\s?([\p{L}°µ][\p{L}\d²³⁻¹°µ/^*·]*)$"

"""
What a cell that isn't a formula holds: a number like 1,200 or \$4.50 or 15%,
a number with a unit like 2.4m, or else its text.
"""
literal(s::AbstractString) = begin
  m = match(PLAIN, s)
  if m !== nothing
    digits = replace(m[2], "," => "")
    n = something(tryparse(Int, digits), tryparse(Float64, digits))
    m[1] == "-" && (n = -n)
    return m[3] == "%" ? n / 100 : n
  end
  m = match(WITH_UNIT, s)
  m === nothing && return String(s)
  # A unit has no brackets, so this can't call a function
  try
    v = Core.eval(units(), Meta.parse(m[1] * m[2]))
    v isa Number ? v : String(s)
  catch
    String(s)
  end
end

# --- the functions that take cells ---------------------------------------------------------

"Every number among `xs`, and in the ranges among them. Text isn't a number, so a range can take in a heading."
numbers(xs...) = begin
  out = Any[]
  add(x) = x isa AbstractArray ? foreach(add, x) : x isa Union{AbstractString,Nothing} ? nothing : push!(out, x)
  foreach(add, xs)
  out
end

total(xs...) = (v = numbers(xs...); isempty(v) ? 0 : reduce(+, v))
total(f::Function, xs...) = total(map(f, numbers(xs...)))
mean(xs...) = (v = numbers(xs...); isempty(v) ? 0 : reduce(+, v) / length(v))
largest(xs...) = (v = numbers(xs...); isempty(v) ? 0 : maximum(v))
smallest(xs...) = (v = numbers(xs...); isempty(v) ? 0 : minimum(v))
howmany(xs...) = length(numbers(xs...))
howmany(f::Function, xs...) = count(f, numbers(xs...))

"The names a formula calls these functions by. Each has the name Excel gives it too."
const FUNCTIONS = (:sum => total, :mean => mean, :average => mean, :max => largest, :min => smallest, :count => howmany,
                   :SUM => total, :AVERAGE => mean, :MAX => largest, :MIN => smallest, :COUNT => howmany)

const scope = Ref{Any}(nothing)

"The module that every formula runs in. It has the units that a sheet has, and the functions that take cells."
home() = begin
  scope[] === nothing || return scope[]
  mod = Module(:Spreadsheet)
  Core.eval(mod, Expr(:block, Expr(:const, Expr(:(=), :SheetUnits, units())), Expr(:using, Expr(:., :., :SheetUnits))))
  Core.eval(mod, Expr(:block, [Expr(:const, Expr(:(=), name, f)) for (name, f) in FUNCTIONS]...))
  scope[] = mod
end

# --- working the cells out -----------------------------------------------------------------

"What a cell comes to. `text` is what the cell shows in place of a formula, or what went wrong."
struct Value
  text::String
  failed::Bool
  number::Bool   # a number goes on the right of its cell, and text on the left
end

const EMPTY = Value("", false, false)

"A cell that this one uses went wrong"
struct Broken <: Exception
  at::Tuple{Int,Int}
end

"A cell uses itself, perhaps by way of other cells. `at` is where the loop was found."
struct Loop <: Exception
  at::Tuple{Int,Int}
end

"True when `ex` is a range of cells, like B2:B9"
isrange(ex) = ex isa Expr && ex.head == :call && length(ex.args) == 3 && ex.args[1] == :(:) &&
              all(a -> a isa Symbol && place(a) !== nothing, ex.args[2:3])

"""
Work out every cell of a spreadsheet. `rows` holds the text of each cell of
each row. A formula can use a cell that's anywhere in the grid, so each cell is
worked out when the first formula needs it. A cell that goes wrong says so, and
so does each cell that uses it.
"""
answers(rows) = begin
  mod = home()
  values = Dict{Tuple{Int,Int},Any}()
  errors = Dict{Tuple{Int,Int},String}()
  busy = Set{Tuple{Int,Int}}()
  width = maximum(length, rows, init=0)
  text(r, c) = r <= length(rows) && c <= length(rows[r]) ? strip(rows[r][c]) : ""
  # `ex` with the value of each cell where its name was. A cell with nothing in it counts as 0.
  fill(ex) = ex
  fill(s::Symbol) = (at = place(s); at === nothing ? s : QuoteNode(something(value(at), 0)))
  fill(ex::Expr) = begin
    ex.head == :quote && return ex
    isrange(ex) || return Expr(ex.head, map(fill, ex.args)...)
    (r1, c1), (r2, c2) = place(ex.args[2]), place(ex.args[3])
    found = Any[]
    for r in min(r1, r2):min(max(r1, r2), length(rows)), c in min(c1, c2):min(max(c1, c2), width)
      v = value((r, c))
      v === nothing || push!(found, v)
    end
    QuoteNode(found)
  end
  work(s) = begin
    isempty(s) && return nothing
    isformula(s) || return literal(s)
    # A | in a formula has a \ before it, so that it doesn't end the cell
    ex = Meta.parse(replace(chop(s, head=1, tail=0), "\\|" => "|"))
    ex isa Expr && ex.head in (:incomplete, :error) && throw(Meta.ParseError("This isn't finished"))
    Core.eval(mod, fill(ex))
  end
  value(at) = begin
    haskey(values, at) && return values[at]
    haskey(errors, at) && throw(Broken(at))
    at in busy && throw(Loop(at))
    push!(busy, at)
    try
      values[at] = work(text(at...))
    catch err
      errors[at] = err isa Broken ? "$(cellname(err.at)) has a problem" : err isa Loop ? "This cell uses itself" : problem(err)
      # Each cell of a loop is part of it. A cell outside the loop only uses a cell that went wrong.
      throw(err isa Loop && err.at != at ? err : Broken(at))
    finally
      delete!(busy, at)
    end
  end
  [map(eachindex(row)) do c
     at = (r, c)
     try
       v = value(at)
       v === nothing ? EMPTY :
       isformula(text(r, c)) ? Value(v isa AbstractString ? brief(v) : brief(Base.invokelatest(shown, v)), false, !(v isa AbstractString)) :
                               Value(text(r, c), false, v isa Number)
     catch
       Value(get(errors, at, "This can't be worked out"), true, false)
     end
   end for (r, row) in enumerate(rows)]
end

# --- when a row or a column is added or removed --------------------------------------------

isname(c::Char) = isletter(c) || isdigit(c) || c == '_'

"""
Where `text` names a cell, as (lo, hi, row, column) with the columns of the
text that the name runs from and to. A name counts as a whole word outside a
string or a comment, or after a number, as in 2B3.
"""
named(text::AbstractString) = begin
  chars = collect(text)
  free = code(chars)
  out = NTuple{4,Int}[]
  i = 1
  while i <= length(chars)
    isname(chars[i]) || (i += 1; continue)
    j = i
    while j < length(chars) && isname(chars[j+1]); j += 1 end
    # After a dot it's a field of a value, unless the dot is in a number
    field = i > 1 && chars[i-1] == '.' && !(i > 2 && isdigit(chars[i-2]))
    k = something(findnext(!isdigit, chars, i), j + 1)
    word = String(chars[k:j])
    # 2e5 is a number, not 2 times the cell E5
    exponent = k > i && occursin(r"^[eEf]\d+$", word)
    at = field || exponent || !all(free[i:j]) ? nothing : place(word)
    at === nothing || push!(out, (k - 1, j, at...))
    i = j + 1
  end
  out
end

"""
The formula `text` after rows or columns moved by `by`. With `row`, each cell
it names in that row or under it moves. With `col`, each cell in that column or
right of it moves. A cell that isn't a formula stays as it is.
"""
moved(text::AbstractString, by::Int; row=nothing, col=nothing) = begin
  isformula(text) || return String(text)
  chars = collect(text)
  out = IOBuffer()
  at = 0
  for (lo, hi, r, c) in named(text)
    moves = row === nothing ? c >= col : r >= row
    moves || continue
    r, c = row === nothing ? (r, c + by) : (r + by, c)
    print(out, String(chars[at+1:lo]), letters(max(c, 1)), max(r, 1))
    at = hi
  end
  print(out, String(chars[at+1:end]))
  String(take!(out))
end

export SPREADSHEET, Value, spreadcells, spreadtexts, isformula, letters, answers, moved
