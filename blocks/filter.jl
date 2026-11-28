# A filter shows only some of the rows of a table: the rows of a CSV file, of a
# JSON file or of a table of the page that meet its conditions. In a document
# it's a code block in the language `filter`:
#
#     ```filter
#     from: orders.json
#     where: Status is shipped, packed
#     where: Total > 100
#     show: Id, Customer.name, Total
#     sort: Total, largest first
#     ```
#
# `from` names a CSV file, a TSV file or a JSON file beside the page, or the
# heading that a table of the page is under. Without it, the block shows the
# table that's nearest above it.
#
# A JSON file holds a list of things. Each thing in the list is a row, and each
# of its keys is a column. A key of an object inside a thing is a column too,
# named with a dot: `Customer.name`. `at` says where the list is in the file,
# as keys with dots between them, like `at: data.orders`. Without it, the list
# is the file's whole value, or else the first list of objects in it.
#
# Each `where` line is a condition, and a row shows when it meets every one. A
# condition is the name of a column, a test, and what the test looks for:
#
# - `is` and `is not`: the cell is one of the values, or none of them. Commas
#   go between the values. `=` and `!=` are the same tests.
# - `has` and `has no`: the cell has the words in it, or doesn't
# - `starts with` and `ends with`
# - `>`, `<`, `>=` and `<=`: numbers, like $1,200 or 45%. Other cells go in the
#   order of the alphabet, so dates written as 2026-11-21 work too.
# - `is empty` and `is not empty`
#
# Capitals don't count. A value with a comma or a quote in it goes in quotes.
# A line that has no `where:` in front of it is a condition too.
#
# `show` names the columns to show, in their order. Without it, every column
# shows. `sort` names the column that the rows are in the order of. After a
# comma, `largest first` or `Z to A` puts them the other way round.
#
# This file reads and writes those lines, and finds the rows that meet the
# conditions. It draws nothing, and reads no file.

@use "./numbers" number

"The language of a code block that is a filter"
const FILTER = "filter"

"What a filter asks for"
mutable struct Filter
  from::String                 # the file or the heading of the table, or ""
  at::String                   # where the list is in a JSON file, or ""
  conditions::Vector{String}   # each `where` line, as it's written
  show::Vector{String}         # the names of the columns to show, or none for every column
  sort::String                 # the column that the rows are in the order of, or ""
  way::String                  # the words after its comma, like "largest first", or ""
  other::Vector{String}        # the lines that this file doesn't know, kept as they are
end

Filter() = Filter("", "", String[], String[], "", "", String[])

"The words after a `sort` line's comma that put the rows the other way round"
const BACKWARDS = ("largest first", "biggest first", "most first", "highest first", "newest first", "latest first",
                   "z to a", "z-a", "z–a", "desc", "descending", "down", "reversed", "backwards")
"And the words that put them the usual way, which a block needn't have"
const FORWARDS = ("smallest first", "least first", "lowest first", "oldest first", "earliest first",
                  "a to z", "a-z", "a–z", "asc", "ascending", "up")

"True when the rows of `f` go the other way round: largest first, or Z to A"
down(f::Filter) = lowercase(strip(f.way)) in BACKWARDS

"""
The values in `text`, with commas between them. A value in quotes can have a
comma in it, and a quote in it is written twice: `"Smith, J", Jones`
"""
values_in(text::AbstractString) = begin
  out, cell, quoted = String[], IOBuffer(), false
  chars = collect(text)
  i = 1
  while i <= length(chars)
    c = chars[i]
    if quoted && c == '"' && i < length(chars) && chars[i+1] == '"'
      write(cell, '"')
      i += 1
    elseif c == '"'
      quoted = !quoted
    elseif c == ',' && !quoted
      push!(out, String(strip(String(take!(cell)))))
    else
      write(cell, c)
    end
    i += 1
  end
  push!(out, String(strip(String(take!(cell)))))
  filter(!isempty, out)
end

"`values` as a line writes them, with commas between them. A value with a comma or a quote in it goes in quotes."
listed(values) = join((occursin(r"[,\"]", v) || v != strip(v) ? "\"" * replace(v, "\"" => "\"\"") * "\"" : v for v in values), ", ")

"The column of the sort line `text`, and the words after its comma"
sort_of(text::AbstractString) = begin
  i = findlast(',', text)
  i !== nothing && return (String(strip(text[1:prevind(text, i)])), String(strip(text[nextind(text, i):end])))
  low = lowercase(text)
  for words in (BACKWARDS..., FORWARDS...)
    endswith(low, " " * words) && return (String(strip(text[1:prevind(text, end, length(words))])), String(text[end-length(words)+1:end]))
  end
  (String(strip(text)), "")
end

"Read what a filter asks for from the lines of its block"
query(lines) = begin
  f = Filter()
  for line in lines
    text = String(strip(line))
    isempty(text) && continue
    m = match(r"^(\w+)\s*:\s*(.*)$", text)
    key, value = m === nothing ? ("", "") : (lowercase(m[1]), String(strip(m[2])))
    if key == "from"
      f.from = value
    elseif key == "at"
      f.at = value
    elseif key in ("where", "when", "if", "and")
      isempty(value) || push!(f.conditions, value)
    elseif key in ("show", "columns")
      append!(f.show, values_in(value))
    elseif key in ("sort", "order")
      f.sort, f.way = isempty(value) ? ("", "") : sort_of(value)
    elseif m !== nothing
      push!(f.other, text)
    else
      push!(f.conditions, text)   # a condition by itself, like `Total > 100`
    end
  end
  f
end

"The lines of the block"
written(f::Filter) = begin
  out = String[]
  isempty(f.from) || push!(out, "from: " * f.from)
  isempty(f.at) || push!(out, "at: " * f.at)
  append!(out, ["where: " * c for c in f.conditions])
  isempty(f.show) || push!(out, "show: " * listed(f.show))
  isempty(f.sort) || push!(out, "sort: " * f.sort * (isempty(f.way) ? "" : ", " * f.way))
  append!(out, f.other)
  out
end

# --- conditions ------------------------------------------------------------------------------

"""
The tests that a condition can have: the words of each, and what it is. A
longer one comes before a shorter one that it starts with, like `is not`
before `is`.
"""
const TESTS = (("is not empty", :full), ("isn't empty", :full), ("is empty", :empty),
               ("is not", :isnt), ("isn't", :isnt), ("is", :is),
               ("has no", :lacks), ("doesn't have", :lacks), ("does not have", :lacks), ("lacks", :lacks),
               ("has", :has), ("contains", :has), ("starts with", :starts), ("ends with", :ends),
               ("!=", :isnt), ("≠", :isnt), ("==", :is), (">=", :ge), ("≥", :ge), ("<=", :le), ("≤", :le),
               ("=", :is), (">", :gt), ("<", :lt))

"How each test reads, as a filter writes it"
const TEST_WORDS = Dict(:full => "is not empty", :empty => "is empty", :is => "is", :isnt => "is not", :has => "has",
                        :lacks => "has no", :starts => "starts with", :ends => "ends with",
                        :gt => ">", :lt => "<", :ge => ">=", :le => "<=")

"A condition of a filter, read against the names of the columns"
struct Condition
  text::String           # as it's written
  column::Int            # the column that it tests, or 0 when it has a problem
  test::Symbol           # like :is or :gt
  values::Vector{String} # what the test looks for
  problem::String        # why the filter can't use it, in words, or ""
end

"True when `c` is a character that a test made of marks, like >=, starts with"
ismark(c::Char) = c in "=!<>≠≥≤"

"The test at the start of `text`, and what's after it, or nothing when `text` doesn't start with a test"
test_at(text::AbstractString) = begin
  low = lowercase(text)
  for (words, test) in TESTS
    startswith(low, words) || continue
    rest = text[nextind(text, 0, length(words) + 1):end]
    # A test in words ends where its word does: `is` isn't the start of `island`
    ismark(words[1]) || isempty(rest) || isspace(rest[1]) || continue
    return (test, String(strip(rest)))
  end
  nothing
end

"The column whose name is `name`, or 0. Capitals don't count."
column_of(name::AbstractString, names) = something(findfirst(n -> lowercase(strip(n)) == lowercase(strip(name)), names), 0)

"The condition `text` as it reads with a test and what's after it, with the column called `name`"
make(text, name, column, test, rest) = begin
  if test in (:empty, :full)
    isempty(rest) || return Condition(text, 0, test, String[], "“$(text)” has more after “$(TEST_WORDS[test])” than it needs.")
    return Condition(text, column, test, String[], "")
  end
  values = test in (:is, :isnt) ? values_in(rest) : (v = values_in(rest); length(v) == 1 ? v : [String(strip(rest, '"'))])
  isempty(values) && return Condition(text, 0, test, String[], "“$(text)” doesn't say what to look for.")
  Condition(text, column, test, values, "")
end

"""
The condition `text` read against `names`, the names of the columns. It
starts with the name of a column. Of the names that it starts with, the
longest is the one, so `Total tax > 5` tests the column `Total tax` and not
`Total`.
"""
condition(text::AbstractString, names) = begin
  text = String(strip(text))
  low = lowercase(text)
  # The names that the text starts with, longest first
  starts = sort!([c for c in eachindex(names) if !isempty(strip(names[c])) && startswith(low, lowercase(strip(names[c])))],
                 by=c -> -length(strip(names[c])))
  for c in starts
    rest = text[nextind(text, 0, length(strip(names[c])) + 1):end]
    (isempty(rest) || isspace(rest[1]) || ismark(rest[1])) || continue
    found = test_at(String(strip(rest)))
    found === nothing && continue
    return make(text, names[c], c, found...)
  end
  # The column has no name that the text starts with. The test says where its name ends.
  for (i, _) in pairs(text)
    i == 1 || isspace(text[prevind(text, i)]) || ismark(text[i]) || continue
    found = test_at(text[i:end])
    found === nothing && continue
    name = String(strip(text[1:prevind(text, i)]))
    isempty(name) && return Condition(text, 0, found[1], String[], "“$(text)” doesn't name a column.")
    return Condition(text, 0, found[1], String[], "No column is called “$(name)”.")
  end
  Condition(text, 0, :none, String[], "“$(text)” has no test, like is, has or >.")
end

"True when two cells are the same: the same words, or the same number"
alike(a::AbstractString, b::AbstractString) = begin
  lowercase(strip(a)) == lowercase(strip(b)) && return true
  x = number(a)
  x === nothing && return false
  y = number(b)
  y !== nothing && x[1] == y[1]
end

"""
How the cell `a` compares with `b`: -1 when it comes first, 1 when it comes
after, and 0 when they're the same. Two numbers compare as numbers. Anything
else compares in the order of the alphabet, so dates written as 2026-11-21 go
in the order of their days.
"""
compare(a::AbstractString, b::AbstractString) = begin
  x, y = number(a), number(b)
  x !== nothing && y !== nothing && return cmp(x[1], y[1])
  cmp(lowercase(strip(a)), lowercase(strip(b)))
end

"True when the cell `cell` meets the condition `c`"
meets(c::Condition, cell::AbstractString) = begin
  t = c.test
  t == :empty && return isempty(strip(cell))
  t == :full && return !isempty(strip(cell))
  t == :is && return any(v -> alike(cell, v), c.values)
  t == :isnt && return !any(v -> alike(cell, v), c.values)
  low, v = lowercase(cell), lowercase(c.values[1])
  t == :has && return occursin(v, low)
  t == :lacks && return !occursin(v, low)
  t == :starts && return startswith(lstrip(low), v)
  t == :ends && return endswith(rstrip(low), v)
  isempty(strip(cell)) && return false   # an empty cell is no number, and no date
  o = compare(cell, c.values[1])
  t == :gt ? o > 0 : t == :lt ? o < 0 : t == :ge ? o >= 0 : o <= 0
end

"""
`items` in the order of their cells, which `cell(item)` gives. With `numbers`,
the cells that are numbers go in the order of their numbers, and come before
the rest. `down` puts them the other way round. Empty cells go last
whichever way. Items whose cells are the same keep their order.
"""
ordered(items, cell, numbers::Bool, down::Bool) = begin
  blank = [x for x in items if isempty(strip(cell(x)))]
  full = [x for x in items if !isempty(strip(cell(x)))]
  if numbers
    found = [(x, number(cell(x))) for x in full]
    counted = sort!([(x, n[1]) for (x, n) in found if n !== nothing], by=last, rev=down)
    words = sort!([(x, lowercase(cell(x))) for (x, n) in found if n === nothing], by=last, rev=down)
    return [first.(counted); first.(words); blank]
  end
  [sort(full, by=x -> lowercase(cell(x)), rev=down); blank]
end

"Cell `c` of `row`. A row that's too short for it has an empty one there."
cell_of(row, c::Int) = c <= length(row) ? row[c] : ""

"""
What the filter `f` shows of `rows`. The first row has the names of the
columns, and `numbers` says which columns hold numbers. It has:

- `conditions`: each `where` line, read against the names
- `rows`: the places in `rows` of the rows that meet every condition, in the order that they show in
- `columns`: the columns that show, in their order
- `sorted`: the column that the rows are in the order of, or 0
- `problems`: what the block asks for that it can't do, in words

A condition with a problem leaves the rows as they are.
"""
subset(f::Filter, rows, numbers) = begin
  names = isempty(rows) ? String[] : rows[1]
  conditions = [condition(c, names) for c in f.conditions]
  good = [c for c in conditions if isempty(c.problem)]
  keep = [r for r in 2:length(rows) if all(c -> meets(c, cell_of(rows[r], c.column)), good)]
  problems = String[c.problem for c in conditions if !isempty(c.problem)]
  sorted = isempty(f.sort) ? 0 : column_of(f.sort, names)
  isempty(f.sort) || sorted > 0 || push!(problems, "No column is called “$(f.sort)”, so the rows aren't sorted.")
  sorted > 0 && (keep = ordered(keep, r -> cell_of(rows[r], sorted), get(numbers, sorted, false), down(f)))
  shown = [column_of(n, names) for n in f.show]
  for (n, c) in zip(f.show, shown)
    c == 0 && push!(problems, "No column is called “$(n)”, so it doesn't show.")
  end
  columns = unique(filter(>(0), shown))
  isempty(columns) && (columns = collect(eachindex(names)))
  (conditions=conditions, rows=keep, columns=columns, sorted=sorted, problems=problems)
end

# --- what a click on a column writes ---------------------------------------------------------

"The place among the conditions of `f` of the first one that tests column `c` of `names` with `test`, or 0"
condition_for(f::Filter, names, c::Int, test::Symbol) = begin
  k = findfirst(t -> (x = condition(t, names); x.column == c && x.test == test), f.conditions)
  something(k, 0)
end

"""
Make the condition of `f` that tests column `c` of `names` with `test` look
for `values`: change it, add it, or take it away when `values` is empty. It
changes the first such condition, and leaves the others as they are.
"""
look_for!(f::Filter, names, c::Int, test::Symbol, values) = begin
  k = condition_for(f, names, c, test)
  values = filter(!isempty, [String(strip(v)) for v in values])
  line = names[c] * " " * TEST_WORDS[test] * " " * (test in (:is, :isnt) ? listed(values) : (isempty(values) ? "" : values[1]))
  if isempty(values)
    k > 0 && deleteat!(f.conditions, k)
  elseif k > 0
    f.conditions[k] = line
  else
    push!(f.conditions, line)
  end
  f
end

"The values that the condition of `f` that tests column `c` of `names` with `test` looks for, or none"
looked_for(f::Filter, names, c::Int, test::Symbol) = begin
  k = condition_for(f, names, c, test)
  k == 0 ? String[] : condition(f.conditions[k], names).values
end

"""
Put the rows of `f` in the order of column `c` of `names`, or the other way
round with `down`. `numbers` says whether the column holds numbers, which
chooses the words. With `c` 0, the rows go back to the table's order.
"""
sort_by!(f::Filter, names, c::Int, down::Bool, numbers::Bool) = begin
  f.sort = c == 0 ? "" : names[c]
  f.way = c == 0 || !down ? "" : numbers ? "largest first" : "Z to A"
  f
end

"Show every column of `names` that shows now but column `c`"
hide!(f::Filter, names, c::Int, shown) = (f.show = [names[k] for k in shown if k != c]; f)

"""
What the filter shows, in words, for `n` rows of `total`: `12 of 340 rows`, or
`340 rows` when every row shows
"""
summary(n::Int, total::Int; more::Bool=false) = begin
  commas(n) = replace(string(n), r"(?<=\d)(?=(\d{3})+$)" => ",")
  every = more ? "the first $(commas(total)) rows" : "$(commas(total)) row$(total == 1 ? "" : "s")"
  n == total ? every : "$(commas(n)) of $every"
end
