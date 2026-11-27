# A question that the page asks you, with answers to choose from. In a
# document it's a code block in the language `ask`:
#
#     ```ask
#     Which database should the app use?
#     ( ) SQLite. It's one file, and needs no server.
#     (x) Postgres
#     > We already run Postgres for the other app.
#     ```
#
# The lines at the top are the question. A line that starts with `( )` is an
# answer, and you choose one of those. `(x)` is the one that's chosen. A line
# that starts with `[ ]` is an answer too, and you choose as many of those as
# you like: `[x]` is a chosen one. A line that starts with `>` is what you
# typed under the answers. A question with no answers to choose from has only
# that line.
#
# A question can ask for a value that you set, too:
#
#     ```ask
#     How should the logo look?
#     Size: 48px (16px to 96px)
#     Colour: #e8632b
#     ```
#
# A line with a name, a number and its range in brackets is a slider: the
# number is where it's set, and the range is how far it goes. A line with a
# name and a colour like #e8632b is a colour to pick. Setting the slider or
# picking a colour writes the new value in the line.
#
# An agent writes the block, and reads your answer in the lines that you
# changed. This file reads and writes those lines. It draws nothing.

@use Printf: @sprintf

"The language of a code block that is a question"
const ASK = "ask"

"An answer to choose"
mutable struct Option
  text::String
  chosen::Bool
  many::Bool   # true when it's one of those that you choose any number of
end

"""
A value that you set: a number on a slider, or a colour. Its line is `head`,
then the value as `shown` writes it, then `tail`, so the rest of the line
stays as it was written.
"""
mutable struct Field
  name::String
  kind::Symbol       # :slider or :colour
  number::Float64    # where a slider is set
  low::Float64       # how far a slider goes
  high::Float64
  digits::Int        # how many digits after the point a slider's numbers have
  colour::String     # a colour, like #e8632b
  head::String       # the line before the value, like "Size: "
  tail::String       # the line after it, like "px (16px to 96px)"
end

mutable struct Question
  words::Vector{String}     # the lines of the question
  options::Vector{Option}
  note::String              # what was typed under the answers
  fields::Vector{Field}
  order::Vector{Tuple{Symbol,Int}}   # each line in turn: (:words, i), (:option, i), (:field, i) or (:note, 0)
end

Question() = Question(String[], Option[], "", Field[], Tuple{Symbol,Int}[])

# An answer can start as a to-do item does, with a - before its box
const OPTION = r"^\s*(?:[-*]\s+)?([(\[])([ xX✓]?)[)\]]\s+(.*)$"
const NOTE = r"^\s*>\s?(.*)$"
const NUMBER = "-?\\d+(?:\\.\\d+)?"
# A name, a number with a unit or none, and the range in brackets: "Size: 48px (16px to 96px)"
const SLIDER = Regex("^\\s*(?:[-*]\\s+)?([^:(]+?):\\s*($NUMBER)(\\s*[^\\s\\d(.\\-][^\\s(]*)?\\s*\\(\\s*($NUMBER)\\s*[^\\s\\d)]*\\s+to\\s+($NUMBER)\\s*[^\\s\\d)]*\\s*\\)\\s*\$")
# A name and a colour: "Colour: #e8632b"
const COLOUR = r"^\s*(?:[-*]\s+)?([^:(]+?):\s*(#(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{3}))\s*$"

"How many digits the number `text` has after its point"
digits_of(text::AbstractString) = (k = findfirst('.', text); k === nothing ? 0 : length(text) - k)

"The value that the line `line` sets, or nothing when it sets none"
field(line::AbstractString) = begin
  m = match(SLIDER, line)
  if m !== nothing
    low, high = parse(Float64, m[4]), parse(Float64, m[5])
    if low < high
      at = m.offsets[2]
      stop = at + ncodeunits(m[2])
      return Field(String(strip(m[1])), :slider, parse(Float64, m[2]), low, high, maximum(digits_of, (m[2], m[4], m[5])), "",
                   line[1:prevind(line, at)], line[stop:end])
    end
  end
  m = match(COLOUR, line)
  m === nothing && return nothing
  at = m.offsets[2]
  Field(String(strip(m[1])), :colour, 0.0, 0.0, 0.0, 0, String(m[2]), line[1:prevind(line, at)], line[at+ncodeunits(m[2]):end])
end

"A slider's number as its line writes it, with as many digits after the point as the line's numbers have, or a colour"
shown(f::Field, number=f.number) = f.kind == :colour ? f.colour : f.digits == 0 ? string(round(Int, number)) : @sprintf("%.*f", f.digits, number)

"The number `number` of the slider `f` with its unit, like 48px or 12 mm"
said(f::Field, number=f.number) = shown(f, number) * rstrip(first(split(f.tail, '(')))

"The smallest step of a slider: 1 for whole numbers, 0.1 for numbers with one digit after the point, and so on"
step(f::Field) = 1 / 10.0^f.digits

"The line of a field, with its value now"
line(f::Field) = f.head * shown(f) * f.tail

"Set the slider `f` to `number`, as its line can write it"
set!(f::Field, number::Real) = (f.number = round(clamp(number, f.low, f.high), digits=f.digits); f)

"Read a question from the lines of its block"
question(lines) = begin
  q = Question()
  typed = String[]
  for line in lines
    isempty(strip(line)) && continue
    m = match(OPTION, line)
    if m !== nothing
      push!(q.options, Option(String(strip(m[3])), !isempty(strip(m[2])), m[1] == "["))
      push!(q.order, (:option, length(q.options)))
    elseif (m = match(NOTE, line)) !== nothing
      isempty(strip(m[1])) || push!(typed, strip(m[1]))
      push!(q.order, (:note, 0))
    elseif (f = field(line)) !== nothing
      push!(q.fields, f)
      push!(q.order, (:field, length(q.fields)))
    else
      push!(q.words, String(strip(line)))
      push!(q.order, (:words, length(q.words)))
    end
  end
  q.note = join(typed, " ")
  q
end

"""
The lines of a question's block, in the order that they were read in. What
was typed goes where it was first, or at the end.
"""
written(q::Question) = begin
  order = isempty(q.order) ? [[(:words, i) for i in eachindex(q.words)]; [(:field, i) for i in eachindex(q.fields)]; [(:option, i) for i in eachindex(q.options)]] : q.order
  out = String[]
  noted = isempty(strip(q.note))
  for (kind, i) in order
    if kind == :words
      push!(out, q.words[i])
    elseif kind == :field
      push!(out, line(q.fields[i]))
    elseif kind == :option
      o = q.options[i]
      box = o.many ? (o.chosen ? "[x]" : "[ ]") : (o.chosen ? "(x)" : "( )")
      push!(out, "$box $(o.text)")
    elseif !noted
      push!(out, "> " * q.note)
      noted = true
    end
  end
  noted || push!(out, "> " * q.note)
  out
end

"""
Choose answer `i`, or take the choice away if it's chosen already. One of the
answers that you choose one of takes the place of the one that was chosen.
"""
choose!(q::Question, i::Int) = begin
  o = q.options[i]
  was = o.chosen
  o.many || foreach(other -> other.many || (other.chosen = false), q.options)
  o.chosen = !was
  q
end

"True when the question has an answer: one that's chosen, or words that were typed"
answered(q::Question) = any(o -> o.chosen, q.options) || !isempty(strip(q.note))

"The whole question in a line"
asked(q::Question) = join(q.words, " ")
