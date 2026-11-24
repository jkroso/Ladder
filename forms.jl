# A form adds rows to a table of the page. In a document it's a code block in
# the language `form`, under the table:
#
#     | Client | Due        | Status | Price  | Paid |
#     |--------|------------|--------|--------|------|
#     | Smith  | 2026-11-25 | Quote  | $4,200 | No   |
#
#     ```form
#     title: New job
#     ```
#
# The form has a field for each column of the table, and a button that adds a
# row with what's in the fields. Each line of the block is optional:
#
# - `title` is the words at the top of the form. Without it, the form says
#   which table it adds to.
# - `to` names the heading of the table that it adds to, when that isn't the
#   table nearest above it. A heading with a number after it, like `Jobs 2`,
#   names the second table under that heading.
# - A line with the name of a column says what its field takes: `Due: day`,
#   `Price: number`, `Start: time`, `Paid: yes/no`, `Notes: words`, or the
#   words of a chooser, like `Status: Quote, Booked, Done`.
#
# A column with no such line says what its field takes from the cells that it
# has. Every cell with something in it has to be of the one kind:
#
# - Days, like 2026-11-25, 25 Nov 2026 or 25/11/2026: a field for a day.
# - Times, like 14:30 or 2:30 pm: a field for a time.
# - One of two words that mean yes and no, like Yes and No, or ✓ and nothing:
#   a box to tick.
# - Numbers, like 12, 4.5, $4,200 or 12 L: a field for a number.
# - A few words that come again and again, like Quote and Booked: a chooser
#   with those words. They are no more than six, and the column has two
#   cells or more for each of them. A column of clients, where a name comes
#   twice now and then, stays a field for words.
# - Anything else: a field for words.
#
# What's typed in a field for a day, a time or a number is written in the row
# the way that the column writes it: `25 nov` becomes 2026-11-25 in a column of
# days like 2026-11-25, and `700` becomes $700 in a column of dollars.
#
# This file reads the block's lines, works out each field, and writes the row.
# It draws nothing.

@use Dates: Dates, Date, Day
@use "./chart" number
@use "./schedule" => Schedules

"The language of a block that adds rows to a table"
const FORM = "form"

"""
What a form's block says: the words at its top, the heading of the table that
it adds to, and each other line as the name before its colon and the words after
"""
Base.@kwdef struct Form
  title::String = ""
  to::String = ""
  says::Vector{Pair{String,String}} = Pair{String,String}[]
end
Base.:(==)(a::Form, b::Form) = a.title == b.title && a.to == b.to && a.says == b.says

"What the lines of a form's block say. A line with no colon is left out."
query(lines) = begin
  title, to, says = "", "", Pair{String,String}[]
  for line in lines
    m = match(r"^\s*([^:]*[^:\s])\s*:\s*(.*?)\s*$", line)
    m === nothing && continue
    key = lowercase(m[1])
    key == "title" ? (title = String(m[2])) : key == "to" ? (to = String(m[2])) : push!(says, String(m[1]) => String(m[2]))
  end
  Form(title=title, to=to, says=says)
end

"""
A field of a form: the name of its column, and what it takes. `kind` is
:words, :number, :day, :time or :tick, and the rest say how the column writes
that kind.
"""
Base.@kwdef struct Field
  name::String
  kind::Symbol = :words
  choices::Vector{String} = String[]   # the words of its chooser, when it takes one of a few words
  before::String = ""                  # what the column's numbers have before them, like $
  after::String = ""                   # what they have after them, like % or " m"
  commas::Bool = false                 # its numbers have a comma at each thousand
  style::Symbol = :iso                 # how a day is written (:iso, :words or :slashes), or a time (:h24, :padded or :ampm)
  yes::String = "Yes"                  # what a ticked box writes
  no::String = "No"                    # what an empty box writes
end

"The most words that a chooser has, when the column's cells say what they are"
const MOST_CHOICES = 6

# --- days -----------------------------------------------------------------------------

const WEEKDAYS = ("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday")

"""
The day that `text`, typed in a field, names, or nothing when it names none.
It reads what `Schedules.date` reads, like 2026-11-25, 25 Nov and 25/11, and
also tomorrow, yesterday, a day of the week like fri (the next one after
`today`), a number like 25 (the next 25th, from `today` on), and +3 (three
days after `today`).
"""
day(text::AbstractString; today::Date=Dates.today()) = begin
  s = lowercase(strip(text))
  isempty(s) && return nothing
  d = Schedules.date(s; today)
  d === nothing || return d
  s == "tomorrow" && return today + Day(1)
  s == "yesterday" && return today - Day(1)
  m = match(r"^\+(\d{1,3})$", s)
  m === nothing || return today + Day(parse(Int, m[1]))
  if occursin(r"^\d{1,2}$", s)
    n = parse(Int, s)
    for k in 0:62
      Dates.day(today + Day(k)) == n && return today + Day(k)
    end
    return nothing
  end
  k = length(s) >= 3 ? findfirst(w -> startswith(w, s), WEEKDAYS) : nothing
  k === nothing ? nothing : today + Day(mod1(k - Dates.dayofweek(today), 7))
end

"How the cell `text` writes a day: :iso for 2026-11-25, :words for 25 Nov 2026, :slashes for 25/11/2026, or nothing when it's no day"
day_style(text::AbstractString) = begin
  Schedules.date(text) === nothing && return nothing
  occursin(r"^\d{4}-\d{1,2}-\d{1,2}$", text) ? :iso : occursin(r"^\d{1,2} [A-Za-z]{3,9} \d{4}$", text) ? :words :
  occursin(r"^\d{1,2}/\d{1,2}/\d{4}$", text) ? :slashes : nothing
end

"The day `d` as a cell, written in `style`"
written(d::Date, style::Symbol) =
  style == :words ? "$(Dates.day(d)) $(Dates.monthabbr(d)) $(Dates.year(d))" :
  style == :slashes ? "$(Dates.day(d))/$(Dates.month(d))/$(Dates.year(d))" : string(d)

# --- times ----------------------------------------------------------------------------

"""
The hour and the minute that `text`, typed in a field, names, or nothing when
it names no time. It reads 14:30, 1430, 2:30 pm, 2.30pm, 2pm and 9.
"""
clock(text::AbstractString) = begin
  s = lowercase(strip(text))
  m = match(r"^(\d{1,2})(?:[:.]?(\d{2}))?\s*([ap])\.?m?\.?$", s)
  if m !== nothing
    h, min = parse(Int, m[1]), m[2] === nothing ? 0 : parse(Int, m[2])
    (1 <= h <= 12 && min < 60) || return nothing
    return (h % 12 + (m[3] == "p" ? 12 : 0), min)
  end
  m = match(r"^(\d{1,2})(?:[:.]?(\d{2}))?$", s)
  m === nothing && return nothing
  h, min = parse(Int, m[1]), m[2] === nothing ? 0 : parse(Int, m[2])
  h < 24 && min < 60 ? (h, min) : nothing
end

"How the cell `text` writes a time: :ampm for 2:30 pm, :padded for 09:05, :h24 for 9:05, or nothing when it's no time"
time_style(text::AbstractString) = begin
  clock(text) === nothing && return nothing
  occursin(r"^\d{1,2}([:.]\d{2})?\s*[ap]\.?m\.?$"i, text) ? :ampm : occursin(r"^0\d:\d{2}$", text) ? :padded :
  occursin(r"^\d{1,2}:\d{2}$", text) ? :h24 : nothing
end

"The time `h`:`min` as a cell, written in `style`"
written(h::Int, min::Int, style::Symbol) = begin
  mm = lpad(min, 2, '0')
  style == :ampm ? "$(mod1(h, 12)):$(mm) $(h < 12 ? "am" : "pm")" : style == :padded ? "$(lpad(h, 2, '0')):$(mm)" : "$(h):$(mm)"
end

# --- boxes to tick --------------------------------------------------------------------

"The pairs of words that mean yes and no in a column, in small letters. A pair with no second word leaves the cell empty for no."
const TICKS = (("yes", "no"), ("y", "n"), ("true", "false"), ("✓", "✗"), ("✔", "✘"), ("[x]", "[ ]"), ("x", ""))

"`word` with its letters big or small as those of `like` are: YES beside NO, Yes beside No"
cased(word, like) = isempty(like) || !any(isletter, like) ? word : all(c -> !isletter(c) || isuppercase(c), like) && length(like) > 1 ? uppercase(word) :
                    isuppercase(first(like)) ? uppercasefirst(word) : word

"""
The words that a column with the cells `cells` writes for yes and for no, or
nothing when its cells aren't all one of two such words. `blanks` is true when
the column has empty cells too. Those are its no, when it has no word for no.
"""
tick_words(cells, blanks::Bool) = begin
  isempty(cells) && return nothing
  low = lowercase.(cells)
  for (yes, no) in TICKS
    all(c -> c == yes || (!isempty(no) && c == no), low) || continue
    y, n = findfirst(==(yes), low), findfirst(==(no), low)
    n === nothing && blanks && return (cells[y], "")
    return (y === nothing ? cased(yes, cells[n]) : cells[y], n === nothing ? cased(no, cells[y]) : cells[n])
  end
  nothing
end

# --- numbers --------------------------------------------------------------------------

"True when the cell `text` is a number, like 12, -4.5, \$4,200, 15% or 12 L"
isnumber(text) = number(text) !== nothing

"The digits `digits` of a number, with a comma at each thousand of the part before its point"
grouped(digits::AbstractString) = begin
  whole, rest = (i = findfirst('.', digits); i === nothing ? (digits, "") : (digits[1:i-1], digits[i:end]))
  occursin(r"^\d{4,}$", whole) || return String(digits)
  replace(whole, r"(?<=\d)(?=(\d{3})+$)" => ",") * rest
end

"""
The number `text`, typed in the field `f`, as a cell, or nothing when it's no
number. A number that's typed bare gets what the column's numbers have before
them and after them, and their commas: 4200 is \$4,200 in a column of dollars.
"""
amount(f::Field, text::AbstractString) = begin
  s = String(strip(text))
  n = number(s)
  n === nothing && return nothing
  (isempty(n[2]) && isempty(n[3])) || return s
  m = match(r"^([-−–+]?)\s*(.*)$", s)
  m[1] * f.before * (f.commas ? grouped(m[2]) : m[2]) * f.after
end

"True when the number `text` has something before it or after it, like \$ or m"
marked(text::AbstractString) = (n = number(text); n !== nothing && !(isempty(n[2]) && isempty(n[3])))

"""
The cell `cell` of the field `f` as its field shows it. A number loses what
the column's numbers have before them and after them, since the field shows
those beside what's typed: \$4,200 is 4,200.
"""
shown(f::Field, cell::AbstractString) = begin
  n = f.kind == :number ? number(cell) : nothing
  (n !== nothing && marked(cell) && n[2] == f.before && n[3] == f.after) || return String(cell)
  s = isempty(f.before) ? String(cell) : replace(cell, f.before => "", count=1)
  String(strip(isempty(f.after) ? s : chopsuffix(s, f.after)))
end

# --- the field of each column ---------------------------------------------------------

"""
What the words after a column's name in a form's block say that its field
takes: a kind, and the words to choose from. It's nothing for words that name
no kind.
"""
named(words::AbstractString) = begin
  s = lowercase(strip(words))
  s in ("day", "date") && return (:day, String[])
  s in ("number", "amount") && return (:number, String[])
  s == "time" && return (:time, String[])
  s in ("yes/no", "yes or no", "tick", "tick box", "checkbox") && return (:tick, String[])
  s in ("words", "text") && return (:words, String[])
  occursin(',', s) || return nothing
  (:words, String[strip(w) for w in split(words, ',') if !isempty(strip(w))])
end

"The line of the form `f` for the column called `name`, as the words after its colon, or nothing. The last such line counts."
said(f::Form, name::AbstractString) = (k = findlast(p -> lowercase(p.first) == lowercase(name), f.says); k === nothing ? nothing : f.says[k].second)

"The thing that most of `things` are. Of two that come as often, it's the one that comes first."
most(things) = (u = unique(things); u[argmax([count(==(x), things) for x in u])])

"""
The field of each column of a table whose rows are `rows`, the first of them
the names of the columns. A column with no name is called by its number. A
line of `form` with a column's name says what its field takes. Without one,
the column's cells say.
"""
fields(rows, form::Form=Form()) = begin
  isempty(rows) && return Field[]
  names = rows[1]
  out = Field[]
  for (c, name) in enumerate(names)
    all_cells = String[strip(r[c]) for r in rows[2:end] if c <= length(r)]
    cells = filter(!isempty, all_cells)
    name = isempty(strip(name)) ? "Column $c" : String(strip(name))
    words = said(form, name)
    told = words === nothing ? nothing : named(words)
    days, times = filter(!isnothing, day_style.(cells)), filter(!isnothing, time_style.(cells))
    ticks = tick_words(cells, length(cells) < length(all_cells))
    kind = told !== nothing ? told[1] : isempty(cells) ? :words : length(days) == length(cells) ? :day :
           length(times) == length(cells) ? :time : ticks !== nothing ? :tick : all(isnumber, cells) ? :number : :words
    choices = told === nothing ? String[] : told[2]
    if told === nothing && kind == :words
      # A few words, with two cells or more for each, are the words of a chooser
      u = unique(cells)
      1 < length(u) <= MOST_CHOICES && length(cells) >= 2length(u) && (choices = u)
    end
    numbers = filter(!isnothing, number.(cells))
    same(part) = !isempty(numbers) && all(n -> n[part] == numbers[1][part], numbers) ? numbers[1][part] : ""
    style = kind == :day ? (isempty(days) ? :iso : most(days)) : kind == :time ? (isempty(times) ? :h24 : most(times)) : :iso
    yes, no = something(ticks, ("Yes", "No"))
    push!(out, Field(name=name, kind=kind, choices=choices, before=same(2), after=same(3), commas=any(c -> occursin(r"\d,\d{3}", c), cells),
                     style=style, yes=yes, no=no))
  end
  out
end

"""
The lines of `form` that say what a field takes, and can't: each is the name
before its colon, the words after it, and :column when the table whose columns
are `names` has no such column, or :kind when the words name no kind of field.
"""
stray(form::Form, names) = begin
  out = Tuple{String,String,Symbol}[]
  for (name, words) in form.says
    any(n -> lowercase(strip(n)) == lowercase(name), names) || (push!(out, (name, words, :column)); continue)
    named(words) === nothing && push!(out, (name, words, :kind))
  end
  out
end

"""
What `text`, typed in the field `f`, puts in its cell, written as the column
writes it, or nothing when `text` isn't what the field takes. Nothing typed is
an empty cell.
"""
value(f::Field, text::AbstractString; today::Date=Dates.today()) = begin
  s = String(strip(text))
  isempty(s) && return ""
  if f.kind == :day
    d = day(s; today)
    d === nothing ? nothing : written(d, f.style)
  elseif f.kind == :time
    t = clock(s)
    t === nothing ? nothing : written(t..., f.style)
  elseif f.kind == :number
    amount(f, s)
  else
    s
  end
end

"The cell that `text`, typed in a field, makes: on one line, with each | marked so that it doesn't end the cell"
cell(text) = replace(strip(replace(text, r"\s*\n\s*" => " ")), "|" => "\\|")

"The line of a table that holds the cells `cells`"
row_line(cells) = "| " * join(cell.(cells), " | ") * " |"
