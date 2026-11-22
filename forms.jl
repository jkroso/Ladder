# A form adds rows to a table of the page. In a document it's a code block in
# the language `form`, under the table:
#
#     | Client | Due        | Status |
#     |--------|------------|--------|
#     | Smith  | 2026-11-25 | Quote  |
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
#
# A column says what its field is from the cells that it has:
#
# - All numbers, like 12, 4.5 or $4,200: a field for a number.
# - All days, like 2026-11-25: a field for a day.
# - A few words that come again, like Quote and Booked: a field with a button
#   for each of those words, which puts the word in the field.
# - Anything else: a field for words.
#
# This file reads the block's lines, works out each field, and writes the row.
# It draws nothing.

"The language of a block that adds rows to a table"
const FORM = "form"

"What a form's block says: the words at its top, and the heading of the table that it adds to"
Base.@kwdef struct Form
  title::String = ""
  to::String = ""
end

"What the lines of a form's block say. A line that isn't `title:` or `to:` is left out."
query(lines) = begin
  title, to = "", ""
  for line in lines
    m = match(r"^\s*(title|to)\s*:\s*(.*?)\s*$"i, line)
    m === nothing && continue
    lowercase(m[1]) == "title" ? (title = String(m[2])) : (to = String(m[2]))
  end
  Form(title=title, to=to)
end

"A field of a form: the name of its column, what it takes (:words, :number or :day), and the words that its buttons put in it"
struct Field
  name::String
  kind::Symbol
  choices::Vector{String}
end

const NUMBER = r"^[-+]?[$€£¥]?\s*[-+]?(\d{1,3}(,\d{3})+|\d+)?(\.\d+)?\s*%?$"
const DAY = r"^\d{4}-\d{1,2}-\d{1,2}$"

"The most words that a field has a button for"
const MOST_CHOICES = 6

"True when the cell `text` is a number, like 12, -4.5, \$4,200 or 15%"
isnumber(text) = occursin(NUMBER, text) && occursin(r"\d", text)

"""
The field of each column of a table whose rows are `rows`, the first of them
the names of the columns. A column with no name is called by its number.
"""
fields(rows) = begin
  isempty(rows) && return Field[]
  names = rows[1]
  out = Field[]
  for (c, name) in enumerate(names)
    cells = String[strip(r[c]) for r in rows[2:end] if c <= length(r) && !isempty(strip(r[c]))]
    name = isempty(strip(name)) ? "Column $c" : String(strip(name))
    kind = isempty(cells) ? :words : all(isnumber, cells) ? :number : all(x -> occursin(DAY, x), cells) ? :day : :words
    words = unique(cells)
    # Words that come again, and not too many of them, are the choices of the field
    choices = kind == :words && 1 < length(words) <= MOST_CHOICES && length(cells) > length(words) ? words : String[]
    push!(out, Field(name, kind, choices))
  end
  out
end

"The cell that `text`, typed in a field, makes: on one line, with each | marked so that it doesn't end the cell"
cell(text) = replace(strip(replace(text, r"\s*\n\s*" => " ")), "|" => "\\|")

"The line of a table that holds the cells `cells`"
row_line(cells) = "| " * join(cell.(cells), " | ") * " |"
