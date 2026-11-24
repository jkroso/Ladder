# The fields of numbers in the design editor hold Julia code, like
# `4.5cm + 2mm*1.5`. Julia works out what a field comes to, with the units of
# Units.jl, `deg` for a degree as SolidCraft writes it, and each parameter of
# the design by its name, like `d1`, as it is now.
#
# SolidCraft keeps the text of each length of a design, and works it out
# again when a parameter that it names changes. Its own sums are mostly
# Julia's: `4.5cm + 2mm*1.5` and `d1/2 + 1inch` are the same in both. Some
# aren't: SolidCraft reads `cos(pi/3)` with pi/3 in degrees, and `2 + 3cm` as
# 32 mm where Units.jl gets 5 cm. So the editor asks SolidCraft what the text
# comes to (`expr.evaluate`). When that's what Julia got, SolidCraft gets the
# text itself, and keeps following the parameters that it names. When it
# isn't, SolidCraft gets the number that Julia got, like `50 mm`, and the
# comment of that parameter keeps the code:
#
#     Julia: 2 + 3cm = 50 mm
#
# The comment keeps the code too when SolidCraft gets it written another way,
# like `pi*2mm` for `π*2mm`. The field shows the code again while the
# parameter's text is still what SolidCraft got. A comment whose text doesn't
# match any more is left alone. The line goes under what the comment said
# before, which stays.

@use "github.com/jkroso/Units.jl" => Units
@use "github.com/jkroso/Units.jl/Imperial" => Imperial
@use "../highlight" tokens

const made = Ref{Any}(nothing)

"""
A module that has every unit of Units.jl, and `deg` for a degree. A design's
module takes them with `using`, so a parameter can have the name of a unit.
It's made when it's first needed, as a module made while Julia compiles this
file couldn't have names put in it.
"""
units() = begin
  made[] === nothing || return made[]
  mod = Module(:DesignUnits)
  seen = Set{Symbol}()
  for src in (Units, Imperial), n in names(src; all=true)
    s = string(n)
    (n === nameof(src) || n in seen || n in (:eval, :include) || startswith(s, "#") || startswith(s, "include") ||
     !isdefined(src, n) || Base.isexported(Base, n)) && continue
    push!(seen, n)
    Core.eval(mod, :(const $n = $(QuoteNode(getfield(src, n)))))
  end
  Core.eval(mod, :(const deg = $(QuoteNode(getfield(Units, :°)))))
  push!(seen, :deg)
  Core.eval(mod, Expr(:export, seen...))
  made[] = mod
end

"A new module for the code of a design's fields"
workspace() = begin
  m = Module(:Design)
  Core.eval(m, :(const DesignUnits = $(units())))
  Core.eval(m, :(using .DesignUnits))
  Core.eval(m, :(eval(x) = Core.eval($m, x)))
  m
end

"""
What the parameter `p` is, as SolidCraft lists it: a length in mm, an angle
in degrees, and any other as a number. It's nothing for a parameter of text.
"""
value_of(p) = begin
  value = get(p, "value", nothing)
  value isa Real || return nothing
  unit = String(something(get(p, "unit", ""), ""))
  unit in ("deg", "rad") ? value * Units.° : unit in ("", "unitless") ? value : value * Units.mm
end

"Give the module `m` each parameter of the design by its name, with its value as `value_of` gives it"
parameters!(m::Module, params) = begin
  for p in params
    name = Symbol(String(p["name"]))
    Base.isidentifier(name) || continue
    x = value_of(p)
    x === nothing && continue
    try Core.eval(m, :($name = $(QuoteNode(x)))) catch end
  end
  m
end

"What `code` comes to in the module `m`: `(value, false)`, or `(error, true)` when it fails"
evaluate(m::Module, code::AbstractString) =
  try
    (Base.include_string(m, String(code), "field"), false)
  catch err
    (err isa LoadError ? err.error : err, true)
  end

"The value `x` as Julia shows it, or a line that says what went wrong"
shown(x, failed=false) = begin
  failed || return sprint(show, x, context=:limit => true)
  lines = split(sprint(showerror, x), '\n')
  # A parse error says what's wrong on its last line, under a picture of where it is
  i = findlast(l -> occursin("──", l), lines)
  i === nothing ? String(strip(first(lines))) : "ParseError: " * strip(last(split(lines[i], "──")))
end

"A number as SolidCraft takes it: 48 not 48.0"
figures(x::Real) = isinteger(x) && abs(x) < 1e15 ? string(round(Int, x)) : string(Float64(x))

"""
What the value `x` of a field of the kind `kind` is to SolidCraft:
`(sent, kind, number)`, with what SolidCraft gets, the kind of value that
`expr.evaluate` is asked for, and the number that it comes to there (mm for a
length, radians for an angle). A list of three for a `:vector` has no number.
It's words that say what's wrong when `x` isn't the kind of thing the field
takes. A plain number is in the design's own unit, as SolidCraft reads one.
"""
reading(x, kind::Symbol) = begin
  if kind == :vector
    (x isa Union{Tuple,AbstractVector} && length(x) == 3) || return "needs three numbers, like 0, 0, 10mm, and this comes to $(shown(x))"
    out = Any[]
    for p in x
      r = reading(p, :length)
      r isa String && return "needs three numbers or lengths, and this comes to $(shown(x))"
      push!(out, r.number === nothing ? r.sent : r.kind == "length" ? r.number : p)
    end
    return (sent=out, kind="", number=nothing)
  end
  x isa Units.ScalingUnit && (x = Float64(x))
  if x isa Units.Length && kind in (:length, :number)
    mm = Float64(convert(Units.mm, x).value)
    return (sent=figures(mm) * " mm", kind="length", number=mm)
  elseif x isa Units.Angle && kind in (:angle, :number)
    degrees = Float64(convert(Units.°, x).value)
    return (sent=figures(degrees) * " deg", kind="angle", number=deg2rad(degrees))
  elseif x isa Real && !(x isa Bool) && isfinite(x)
    kind == :count && !isinteger(x) && return "needs a whole number, and this comes to $(shown(x))"
    return (sent=figures(x), kind="unitless", number=Float64(x))
  end
  "needs " * (kind == :length ? "a length" : kind == :angle ? "an angle" : kind == :count ? "a whole number" : "a number") *
    ", and this comes to $(shown(x))"
end

"""
SolidCraft's text of a length as Julia code: a unit is joined to its number,
`8 mm` is `8mm`, and an inch is `inch`, as `in` is a word of Julia's.
"""
julia_code(text::AbstractString) = begin
  s = replace(String(text), r"(?<=[\d.)])\s+(mm|cm|m|um|µm|in|inch|ft|deg|rad)\b" => s"\1")
  replace(s, r"(?<=[\d.)])in\b" => "inch")
end

"Julia code as SolidCraft reads it, as near as can be. `expr.evaluate` says whether it comes to the same."
solidcraft_code(code::AbstractString) = replace(String(code), "π" => "pi")

const MARK = "Julia: "

"The comment of a parameter that SolidCraft gets the number `sent` for, which keeps the code that it came from"
comment(code::AbstractString, sent::AbstractString) = MARK * String(code) * " = " * String(sent)

"""
The code that the comment `note` of a parameter keeps, while the parameter's
text is still `text`, the number that the code came to. Else nothing.
"""
kept(note, text) = begin
  (note isa AbstractString && text isa AbstractString) || return nothing
  for line in split(note, '\n')
    startswith(line, MARK) || continue
    rest = chopprefix(line, MARK)
    at = findlast(" = ", rest)
    at === nothing && continue
    strip(rest[nextind(rest, last(at)):end]) == strip(text) && return String(rest[1:prevind(rest, first(at))])
  end
  nothing
end

"The comment `old` with its line of code made `line`, or taken away when `line` is nothing. Its other lines stay."
with_code(old, line) = begin
  lines = [l for l in split(string(something(old, "")), '\n') if !startswith(l, MARK) && !isempty(strip(l))]
  line === nothing || push!(lines, line)
  join(lines, '\n')
end

"The text that a field shows for a parameter whose text in SolidCraft is `text`, with the comment `note`"
field_code(text, note=nothing) = begin
  code = kept(note, text)
  code !== nothing ? code : julia_code(string(text))
end

"""
The pieces of the code `code`, each with its colour from `palette`, as in a
code block: a number has the colour `palette.number`, and so on. A piece with
no colour of its own has `nothing`.
"""
parts(code::AbstractString, palette) = begin
  out = Pair{String,Any}[]
  chars = collect(code)
  at = 0
  for t in tokens(code, "julia")
    t.col > at && push!(out, String(chars[at+1:t.col]) => nothing)
    push!(out, t.text => t.kind == :plain || !hasproperty(palette, t.kind) ? nothing : getproperty(palette, t.kind))
    at = t.col + length(t.text)
  end
  at < length(chars) && push!(out, String(chars[at+1:end]) => nothing)
  out
end

"The colour of each piece of the code `code`, as a TextInput's `colours` takes them: how many characters it has, and its colour"
pieces(code::AbstractString, palette) = Pair{Int,Any}[length(s) => c for (s, c) in parts(code, palette)]
