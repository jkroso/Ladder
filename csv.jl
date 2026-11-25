# Reads a CSV file as the rows of a table. A page shows the file as a table
# when a line holds only a link to it, written as a picture is:
#
#     ![Prices](prices.csv)
#
# Each line of the file is a row, and a mark is between two cells of a row. The
# mark is a comma, a tab or a semicolon: the one that the first row has most
# of. A .tsv file has tabs. A cell that holds the mark, a quote or a line break
# is in quotes, and a quote in such a cell is written twice:
#
#     Item,Note
#     Paint,"Two coats, low sheen"
#     Timber,"The ""good"" pine"
#
# The first row has the names of the columns. A line with nothing on it is no
# row. A table keeps the first `MOST_COLUMNS` columns and the first `MOST_ROWS`
# rows under the names, and a file is read as far as `MOST_BYTES`. The page
# that shows a whole CSV file asks for more rows and more of the file.
#
# This file reads the rows, and says what kind of thing each column holds:
# numbers, days, yes or no, or text. It also writes a changed cell back into
# its row, and adds and takes away a column, so that a page can change the file.
# It changes only the cells that it's asked to: the rest of the row stays as the
# file has it, quotes and all. It draws nothing.

@use "./chart" isnumber
@use Dates: Dates, Date, DateTime

const MOST_COLUMNS = 40
const MOST_ROWS = 5_000         # under the row of names
const MOST_BYTES = 4_000_000    # a longer file is read this far

"The table that a file holds"
struct Table
  rows::Vector{Vector{String}}   # the text of each cell. The first row has the names of the columns.
  numbers::Vector{Bool}          # true for each column that holds numbers
  more::Bool                     # the file has rows after these
  problem::String                # why there's no table to show, or ""
end

"A table with no rows, and why it has none"
nothing_to_show(problem) = Table(Vector{String}[], Bool[], false, problem)

"""
The cells of one row of a CSV file. `mark` is the character between two
cells. A cell that has the mark in it is in quotes, and a quote in such a cell
is written twice.
"""
cells(line, mark::Char) = begin
  out, cell, quoted = String[], IOBuffer(), false
  chars = collect(line)
  i = 1
  while i <= length(chars)
    c = chars[i]
    if quoted && c == '"' && i < length(chars) && chars[i+1] == '"'
      write(cell, '"')
      i += 1
    elseif c == '"'
      quoted = !quoted
    elseif c == mark && !quoted
      push!(out, String(take!(cell)))
    else
      write(cell, c)
    end
    i += 1
  end
  push!(out, String(take!(cell)))
  out
end

"The mark between the cells of `line`: the one of a comma, a tab and a semicolon that it has most of. A mark in quotes doesn't count."
mark(line) = begin
  marks = (',', '\t', ';')
  counts, quoted = [0, 0, 0], false
  for c in line
    k = findfirst(==(c), marks)
    c == '"' ? (quoted = !quoted) : k === nothing || quoted || (counts[k] += 1)
  end
  marks[argmax(counts)]
end

"""
The rows of `text`, each as the text of its line. A line break between two
quotes is part of a cell, so its row goes on to the next line. A line with
nothing on it is no row. No more than `most` rows are read.
"""
records(text; most=typemax(Int)) = begin
  out, row, quoted = String[], IOBuffer(), false
  add!() = (s = String(take!(row)); isempty(strip(s)) || push!(out, s))
  for c in text
    if c == '\n' && !quoted
      add!()
      length(out) >= most && return out
    else
      c == '"' && (quoted = !quoted)
      write(row, c)
    end
  end
  add!()
  out
end

"""
Which columns of `rows` hold numbers. The first row has the names. A column
holds numbers when most of its cells that hold something are numbers, as a
chart counts them: `\$1,200`, `45%` and `2.4 m` are numbers.
"""
numbers(rows) = begin
  wide = isempty(rows) ? 0 : maximum(length, rows)
  map(1:wide) do c
    full = [row[c] for row in @view(rows[2:end]) if c <= length(row) && !isempty(strip(row[c]))]
    !isempty(full) && 2count(isnumber, full) > length(full)
  end
end

"The table that `text` holds, which is the text of a CSV file. Each row has a cell for each column. It keeps `most` rows under the names."
table(text::AbstractString; most=MOST_ROWS) = begin
  text = replace(text, "\r\n" => "\n", '\r' => '\n')
  startswith(text, '﻿') && (text = chop(text, head=1, tail=0))   # the mark that some apps start a file with
  lines = records(text, most=most + 2)
  isempty(lines) && return Table(Vector{String}[], Bool[], false, "")
  more = length(lines) > most + 1
  more && pop!(lines)
  of_records(lines, more)
end

"The table whose rows have the text `lines`, one row to each. `more` says that the file has rows after them."
of_records(lines, more) = begin
  between = mark(lines[1])
  # The spaces around a cell's text aren't part of it
  rows = [String[strip(cell) for cell in first(cells(line, between), MOST_COLUMNS)] for line in lines]
  wide = maximum(length, rows)
  foreach(row -> append!(row, fill("", wide - length(row))), rows)
  Table(rows, numbers(rows), more, "")
end

"""
The table that the lines of a CSV file hold, as `table` reads it, and the lines
that each of its rows is on: see `rows_at`. It keeps `most` rows under the names.
"""
table(lines::Vector{String}; most=MOST_ROWS) = begin
  at = rows_at(lines, most=most + 2)
  isempty(at) && return Table(Vector{String}[], Bool[], false, ""), at
  more = length(at) > most + 1
  more && pop!(at)
  texts = [length(r) == 1 ? lines[first(r)] : join(view(lines, r), "\n") for r in at]
  startswith(texts[1], '﻿') && (texts[1] = chop(texts[1], head=1, tail=0))
  of_records(texts, more), at
end

"""
The lines of `lines`, the text of a CSV file, that each of its rows is on. A
row is one line, or more when a cell in quotes has a line break in it. A line
with nothing on it is no row, as `records` has it. No more than `most` rows.
"""
rows_at(lines; most=typemax(Int)) = begin
  out = UnitRange{Int}[]
  start, quoted, blank = 0, false, true
  for (i, line) in enumerate(lines)
    start == 0 && (start = i; blank = true)
    for c in line
      c == '"' && (quoted = !quoted)
    end
    blank && (blank = isempty(strip(line)))
    quoted && continue
    blank || push!(out, start:i)
    start = 0
    length(out) >= most && return out
  end
  # A quote that's never closed runs to the end of the file
  start > 0 && !blank && push!(out, start:length(lines))
  out
end

# --- what kind of thing a column holds --------------------------------------------------
#
# A column holds numbers when most of its cells that hold something are
# numbers, as `numbers` has it. It holds days when most of them are days or
# times, like 2026-11-25, 25/11/2026, 25 Nov 2026 or 2026-11-25 22:29. It holds
# yes or no when every one of them is yes, no, true, false, y or n. Any other
# column holds text. A page puts each kind in its own order: numbers by their
# size, days by their time, yes before no, and text A to Z with the numbers in
# it by their size, so that "Item 2" comes before "Item 10".

const YES = ("yes", "y", "true", "✓", "✔")
const NO = ("no", "n", "false", "✗", "✘")

"True when `text` says yes, false when it says no, and nothing when it says neither"
yesno(text::AbstractString) = (s = lowercase(strip(text)); s in YES ? true : s in NO ? false : nothing)

const MONTH_NAMES = ("january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december")

"The month that `word` names, like 11 for nov or November, or nothing"
month_of(word) = (w = lowercase(word); length(w) < 3 ? nothing : findfirst(m -> startswith(m, w), MONTH_NAMES))

# The time of day after a day, like 22:29, 22:29:05, 10:30 pm or 22:29:05.123Z. A time zone after it is left out.
const CLOCK = raw"(?:(?:\s*,\s*|\s+|t)(\d{1,2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?\s*(am|pm)?\s*(?:z|utc|gmt|[+-]\d{2}:?\d{2}|[a-z]{3,4})?)?\s*$"
const ISO_DAY = Regex(raw"^\s*(\d{4})[-/](\d{1,2})[-/](\d{1,2})" * CLOCK, "i")
# A year of two digits is only after a slash, so a number like 1.2.10 is no day
const NUMBER_DAY = Regex(raw"^\s*(\d{1,2})[/.-](\d{1,2})[/.-](\d{4}|(?<=/)\d{2})" * CLOCK, "i")
const WORD_DAY = Regex(raw"^\s*(?:[a-z]{3,9}\.?,?\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+([a-z]{3,9})\.?,?\s+(\d{4})" * CLOCK, "i")
const MONTH_FIRST = Regex(raw"^\s*(?:[a-z]{3,9}\.?,?\s+)?([a-z]{3,9})\.?\s+(\d{1,2})(?:st|nd|rd|th)?,?\s+(\d{4})" * CLOCK, "i")

"The time on day `y`-`m`-`d` at the time of day that `m` found from its 4th capture on, or nothing when there's no such day"
at_time(y, mo, d, m::RegexMatch) = begin
  Dates.validargs(Date, y, mo, d) === nothing || return nothing
  h = m[4] === nothing ? 0 : parse(Int, m[4])
  mi = m[5] === nothing ? 0 : parse(Int, m[5])
  s = m[6] === nothing ? 0 : parse(Int, m[6])
  if m[7] !== nothing
    1 <= h <= 12 || return nothing
    h = lowercase(m[7]) == "pm" ? h % 12 + 12 : h % 12
  end
  (h < 24 && mi < 60 && s < 60) || return nothing
  DateTime(y, mo, d, h, mi, s)
end

"""
The time that the cell `text` names, or nothing when it names none: a day like
2026-11-25, 25/11/2026, 25 Nov 2026, Wed, 25 Nov 2026 or November 25, 2026,
with or without a time of day after it. `dayfirst` says whether 3/4/2026 is
the 3rd of April, as in Australia, or March the 4th. See `dayfirst`.
"""
when(text::AbstractString; dayfirst=true) = begin
  year(y) = (n = parse(Int, y); length(y) == 2 ? 2000 + n : n)
  m = match(ISO_DAY, text)
  m === nothing || return at_time(parse(Int, m[1]), parse(Int, m[2]), parse(Int, m[3]), m)
  m = match(NUMBER_DAY, text)
  if m !== nothing
    a, b = parse(Int, m[1]), parse(Int, m[2])
    return dayfirst ? at_time(year(m[3]), b, a, m) : at_time(year(m[3]), a, b, m)
  end
  m = match(WORD_DAY, text)
  if m !== nothing
    month = month_of(m[2])
    return month === nothing ? nothing : at_time(year(m[3]), month, parse(Int, m[1]), m)
  end
  m = match(MONTH_FIRST, text)
  m === nothing && return nothing
  month = month_of(m[1])
  month === nothing ? nothing : at_time(year(m[3]), month, parse(Int, m[2]), m)
end

"""
Whether the days in `cells` that are written with numbers, like 3/4/2026, have
the day first. They do unless one of them has a number over 12 in its middle,
like 4/23/2026, and none has one first.
"""
dayfirst(cells) = begin
  for x in cells
    m = match(r"^\s*(\d{1,2})[/.-](\d{1,2})[/.-]\d", x)
    m === nothing && continue
    parse(Int, m[1]) > 12 && return true
    parse(Int, m[2]) > 12 && return false
  end
  true
end

"Whether the days in each column of `rows` that are written with numbers have the day first, as `dayfirst` says. The first row has the names."
dayfirsts(rows) = begin
  wide = isempty(rows) ? 0 : maximum(length, rows)
  [dayfirst(row[c] for row in @view(rows[2:end]) if c <= length(row)) for c in 1:wide]
end

"""
What kind of thing each column of `rows` holds: :number, :day, :yesno or
:text. The first row has the names. A column with nothing in it holds text.
"""
kinds(rows) = begin
  wide = isempty(rows) ? 0 : maximum(length, rows)
  map(1:wide) do c
    full = [row[c] for row in @view(rows[2:end]) if c <= length(row) && !isempty(strip(row[c]))]
    isempty(full) && return :text
    all(x -> yesno(x) !== nothing, full) && return :yesno
    2count(isnumber, full) > length(full) && return :number
    first = dayfirst(full)
    2count(x -> when(x, dayfirst=first) !== nothing, full) > length(full) ? :day : :text
  end
end

"The text of a cell as it goes in order: in small letters, with each run of digits as long as the others, so that item 2 comes before item 10"
sortkey(text::AbstractString) = replace(lowercase(text), r"\d+" => d -> lpad(d, 20, '0'))

# --- changing the file ------------------------------------------------------------------

"""
Where each cell of the row `text` is in it, as the characters of each, counted
from 1, with its quotes. An empty cell is a range with no characters in it,
just after the mark before it. A mark in quotes is part of its cell.
"""
spans(text::AbstractString, mark::Char) = begin
  chars = collect(text)
  out = UnitRange{Int}[]
  start = !isempty(chars) && chars[1] == '﻿' ? 2 : 1   # the mark that some apps start a file with
  quoted = false
  for i in start:length(chars)
    c = chars[i]
    if c == '"'
      quoted = !quoted   # a quote written twice, in quotes, turns it off and on again
    elseif c == mark && !quoted
      push!(out, start:i-1)
      start = i + 1
    end
  end
  push!(out, start:length(chars))
  out
end

"The text of a cell as a CSV file writes it: in quotes when it has the mark, a quote or a line break in it, with each quote written twice"
written(cell::AbstractString, mark::Char) =
  any(c -> c == mark || c == '"' || c == '\n' || c == '\r', cell) ? "\"" * replace(cell, "\"" => "\"\"") * "\"" : String(cell)

"The row `text` with `new` in its cell `c`. A row with fewer cells gets empty ones up to it. The other cells stay as they're written."
with_cell(text::AbstractString, mark::Char, c::Int, new::AbstractString) = begin
  at = spans(text, mark)
  cell = written(new, mark)
  c > length(at) && return text * string(mark)^(c - length(at)) * cell
  chars = collect(text)
  String(chars[1:first(at[c])-1]) * cell * String(chars[last(at[c])+1:end])
end

"The row `text` with a new cell after its cell `c`, or at its start when `c` is 0. A row with fewer cells gets empty ones up to it."
with_new_cell(text::AbstractString, mark::Char, c::Int, new::AbstractString) = begin
  at = spans(text, mark)
  cell = written(new, mark)
  c == 0 && return cell * string(mark) * text
  c >= length(at) && return text * string(mark)^(c - length(at) + 1) * cell
  chars = collect(text)
  String(chars[1:last(at[c])]) * string(mark) * cell * String(chars[last(at[c])+1:end])
end

"The row `text` without its cell `c`, and the mark beside it"
without_cell(text::AbstractString, mark::Char, c::Int) = begin
  at = spans(text, mark)
  c > length(at) && return String(text)
  length(at) == 1 && return ""
  chars = collect(text)
  c == 1 ? String(chars[first(at[2]):end]) : String(chars[1:last(at[c-1])]) * String(chars[last(at[c])+1:end])
end

"""
The table in the file at `path`, with no more than `most` rows under the names
and from no more than `upto` bytes of the file. When the file isn't there,
isn't text or has no rows, the table has no rows, and its `problem` says why in
words for the page. It never throws.
"""
load(path; most=MOST_ROWS, upto=MOST_BYTES) = begin
  name = basename(path)
  isfile(path) || return nothing_to_show("Ladder can't find the file $name.")
  try
    bytes = open(io -> read(io, upto + 1), path)
    more = length(bytes) > upto
    if more
      # A file that was cut short can stop part way through a row, so it ends at its last whole line
      stop = findlast(==(0x0a), @view bytes[1:upto])
      stop === nothing && return nothing_to_show("Ladder can't read $name as a table.")
      resize!(bytes, stop)
    end
    0x00 in view(bytes, 1:min(length(bytes), 4000)) && return nothing_to_show("Ladder can't read $name as a table. It isn't a file of text.")
    text = String(bytes)
    isvalid(text) || return nothing_to_show("Ladder can't read $name as a table. It isn't a file of text.")
    t = table(text, most=most)
    isempty(t.rows) && return nothing_to_show("The file $name has no rows yet.")
    Table(t.rows, t.numbers, t.more || more, "")
  catch
    nothing_to_show("Ladder can't read the file $name.")
  end
end
