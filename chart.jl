# A chart draws the numbers of a table. In a document the chart is a code block
# in the language `chart`:
#
#     ```chart
#     kind: lines
#     title: Sales and costs
#     by: Month
#     show: Sales, Costs
#     from: Budget
#     ```
#
# `kind` is `bars`, `lines` or `pie`. Without it, the chart has bars.
# `by` names the column whose words name each bar. Without it, that's the
# first column that isn't numbers. `show` names the columns of numbers to
# draw. Without it, the chart draws each column of numbers.
#
# The numbers come from a table of the page: a table, a spreadsheet or a
# sheet. `from` names the heading that the table is under. Without it, the
# chart draws the table that's nearest above it. A line that shows a CSV file
# as a table counts as a table, and `from` can name a CSV file, like
# `from: prices.csv`. The chart then draws the file's numbers. `from` can
# name several tables, with commas between them, like
# `from: The solar cells, The chips`. The chart then draws the columns of
# each over the same names, so two sheets over the same range are two lines.
#
# A chart can hold its own rows too. They go under the settings, with a |
# between the cells, and the first row has the names of the columns:
#
#     ```chart
#     kind: pie
#
#     Room | Area
#     Kitchen | 14
#     Lounge | 22
#     ```
#
# This file reads and writes those lines, and turns the rows of a table into
# what a chart shows. It draws nothing.
#
# A row named In all, Total or Sum adds the others up. The chart keeps that
# row apart from the bars and the slices, and writes it on its own. A cell
# whose value has a unit, like USD, is read in that unit. The words million
# and billion are only for a cell that is text.

@use "github.com/jkroso/Units.jl" => Units
@use "github.com/jkroso/Units.jl/Money" => Cash

"The language of a code block that is a chart"
const CHART = "chart"

"The kinds of chart, and the words that a block can name each one by"
const KINDS = (bars=("bars", "bar", "columns", "column"), lines=("lines", "line"), pie=("pie", "pies"))

mutable struct Chart
  kind::Symbol                   # :bars, :lines or :pie
  title::String
  by::String                     # the column whose words name each bar, or "" for the first column that isn't numbers
  show::Vector{String}           # the columns to draw, or none for every column of numbers
  from::String                   # the heading that the table is under, or a CSV file, or "" for the table above the chart
  rows::Vector{Vector{String}}   # the chart's own rows
  other::Vector{String}          # the settings that this file doesn't know, kept as they are
end

Chart() = Chart(:bars, "", "", String[], "", Vector{String}[], String[])

"The cells of a row that has a | between them"
cells(line::AbstractString) = String[strip(c) for c in split(strip(strip(line), '|'), '|')]

"The names in a list that has commas between them"
listed(text::AbstractString) = String[strip(n) for n in split(text, ',') if !isempty(strip(n))]

"The kind of chart that `word` names, or nothing"
kind(word::AbstractString) = begin
  w = lowercase(strip(word))
  for k in keys(KINDS)
    w in KINDS[k] && return k
  end
  nothing
end

"Read a chart from the lines of its block"
chart(lines) = begin
  c = Chart()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    if occursin('|', text)
      push!(c.rows, cells(text))
      continue
    end
    m = isempty(c.rows) ? match(r"^(\w+)\s*:\s*(.*)$", text) : nothing
    key, value = m === nothing ? ("", "") : (lowercase(m[1]), String(strip(m[2])))
    if key == "kind" && kind(value) !== nothing
      c.kind = kind(value)
    elseif key == "title"
      c.title = value
    elseif key == "by"
      c.by = value
    elseif key == "show"
      c.show = listed(value)
    elseif key == "from"
      c.from = value
    elseif isempty(c.rows) && kind(text) !== nothing
      c.kind = kind(text)   # the kind by itself, like `pie`
    elseif isempty(c.rows)
      push!(c.other, String(text))
    else
      push!(c.rows, [String(text)])   # a row with one cell
    end
  end
  c
end

"The lines of a chart's block"
written(c::Chart) = begin
  out = String["kind: " * KINDS[c.kind][1]]
  isempty(c.title) || push!(out, "title: " * c.title)
  isempty(c.by) || push!(out, "by: " * c.by)
  isempty(c.show) || push!(out, "show: " * join(c.show, ", "))
  isempty(c.from) || push!(out, "from: " * c.from)
  append!(out, c.other)
  isempty(c.rows) || push!(out, "", (join(row, " | ") for row in c.rows)...)
  out
end

# --- numbers -----------------------------------------------------------------------

"Words that say how many thousands a number is, from the largest"
const SCALES = (("trillion", 1e12), ("billion", 1e9), ("million", 1e6), ("thousand", 1e3))

"""
The number that a cell holds, with what's written before it and after it, or
nothing when the cell isn't a number. `\$1,200` is 1200 with a \$ before it,
`45%` is 45 with a % after it, and `2.4 m` is 2.4 with ` m` after it.
`22.4 billion USD` is 22.4 billion, and `100 million USD` is 100 million.
`2.6e-8%` is 2.6 × 10⁻⁸ with a % after it, as Julia writes a very small number.
"""
number(text::AbstractString) = begin
  s = replace(strip(text), r"^\*\*(.*)\*\*$" => s"\1", r"^`(.*)`$" => s"\1")
  m = match(r"^([-−–+]?)\s*([$€£¥]?)\s*((?:\d[\d,]*(?:\.\d+)?|\.\d+)(?:[eE][-+]?\d+)?)\s*(%|[^\d\s,.][^\d]{0,11})?$", s)
  m === nothing && return nothing
  x = parse(Float64, replace(m[3], "," => ""))
  after = m[4] === nothing ? "" : m[4] == "%" ? "%" : " " * m[4]
  x, after = scaled(x, after)
  (m[1] in ("-", "−", "–") ? -x : x, String(m[2]), after)
end

"The number `x` is, in its own unit, with what is written before it and after it. A value with no unit is nothing, so the chart reads the cell's text."
reading(x) = nothing
reading(x::Real) = isfinite(Float64(x)) ? (Float64(x), "", "") : nothing
reading(x::Cash.Money{code}) where code = begin
  v = Float64(x.value)
  isfinite(v) || return nothing
  mark = Cash.symbols[code]
  mark == :$ ? (v, "", " $code") : (v, string(mark), "")
end
reading(x::Units.Unit) = begin
  v = try Float64(x.value) catch; return nothing end
  isfinite(v) || return nothing
  unit = Units.abbr(typeof(x))
  isempty(unit) ? (v, "", "") : unit == "%" ? (v, "", "%") : (v, "", " " * unit)
end

"`x` times the thousand, million, billion or trillion at the front of `after`. That word comes off `after`."
scaled(x, after) = begin
  rest, low = lstrip(after), lowercase(lstrip(after))
  for (word, scale) in SCALES
    n = ncodeunits(word)
    (startswith(low, word) && (n == ncodeunits(low) || !isletter(low[n + 1]))) || continue
    tail = strip(rest[nextind(rest, n):end])
    return x * scale, isempty(tail) ? "" : startswith(tail, "%") ? tail : " " * tail
  end
  x, String(after)
end

isnumber(text::AbstractString) = number(text) !== nothing

"`s` with a comma after each three digits of its whole part"
commas(s::AbstractString) = replace(s, r"(?<=\d)(?=(\d{3})+(?!\d))" => ",", count=typemax(Int))

"A number the way a person writes it: 54 not 54.0, and 14,285.7 not 14285.714285714286"
words(x::Real) = begin
  isfinite(x) || return string(x)
  places = abs(x) >= 100 ? 1 : 2
  whole, part = divrem(round(Int, abs(x) * 10^places), 10^places)
  part = rstrip(lpad(part, places, '0'), '0')
  (x < 0 && (whole > 0 || !isempty(part)) ? "−" : "") * commas(string(whole)) * (isempty(part) ? "" : "." * part)
end

"A big number the way a person says it: 22.4 billion, 100 million. A smaller one stays as `words` writes it."
spoken(x::Real) = begin
  scale = x >= 1e12 ? (1e12, " trillion") : x >= 1e9 ? (1e9, " billion") : x >= 1e6 ? (1e6, " million") : nothing
  scale === nothing ? words(x) : words(x / scale[1]) * scale[2]
end

"A number on a chart's side, short where the numbers get big: 12K, 3.5M, 22.4B"
short(x::Real, most::Real) = begin
  div, mark = most >= 1e12 ? (1e12, "T") : most >= 1e9 ? (1e9, "B") : most >= 1e6 ? (1e6, "M") : most >= 1e4 ? (1e3, "K") : (1.0, "")
  words(x / div) * mark
end

"""
The numbers to write beside a chart whose values go from `lo` to `hi`: about
`n` of them, each a round number, with the first at or under `lo` and the last
at or over `hi`.
"""
ticks(lo::Real, hi::Real, n::Int=5) = begin
  if lo == hi
    # One number alone is in the middle
    room = lo == 0 ? 1.0 : abs(lo) / 2
    lo, hi = lo - room, hi + room
  end
  raw = (hi - lo) / max(n, 1)
  power = 10.0^floor(log10(raw))
  steps = (1, 2, 2.5, 5, 10)
  step = power * steps[findfirst(k -> k * power >= raw * (1 - 1e-9), steps)]
  [round(k * step, digits=10) for k in floor(lo / step + 1e-9):ceil(hi / step - 1e-9)]
end

# --- what a chart shows --------------------------------------------------------------

"One column of numbers. A cell that isn't a number is nothing."
struct Series
  name::String
  values::Vector{Union{Nothing,Float64}}
end

"What a chart shows: the name of each bar, and each column of numbers"
struct Data
  labels::Vector{String}
  series::Vector{Series}
  before::String    # what's written before each number, like \$, when every number has the same
  after::String     # and after each number, like % or m
  problem::String   # why there's nothing to draw, or ""
  more::Int         # how many columns of numbers it leaves out, because a chart has `MOST` colours
  apart::Union{Nothing,Tuple{String,Float64}}   # a total row, kept out of the bars and the slices: its name, then its number
end

Data(labels, series, before, after, problem, more=0) = Data(labels, series, before, after, problem, more, nothing)
nothing_to_draw(problem) = Data(String[], Series[], "", "", problem)

"The most columns that a chart draws. Each has a colour of its own, and a chart has this many colours."
const MOST = 8

same(a::AbstractString, b::AbstractString) = lowercase(strip(a)) == lowercase(strip(b))

"The most slices that a pie has: one for each colour. The smallest of any more are one slice, called Other."
const SLICES = MOST

"""
What the chart `c` shows of a table. `rows` holds the text of each cell of
each row. With `headed`, the first row has the names of the columns. Without
it, the first row is the names when none of its cells but the first is a number.
With `by_first`, the first column names each row, even when it holds numbers,
unless the chart names another: the rows of a sheet over a range are like that.
With `part`, the table is one of several that the chart draws. A column that
`show` names and this table doesn't have is in another table, so it isn't a
problem, and a pie's slices are made when the tables are together.
`values` holds the amount of each cell, in the same place as `rows`. A cell
whose amount has a unit is read from that unit. The text is used when it has none.
"""
data(c::Chart, rows::Vector{Vector{String}}; headed::Bool=false, by_first::Bool=false, part::Bool=false, values=nothing) = begin
  if values !== nothing && length(values) == length(rows)
    kept = [i for (i, row) in enumerate(rows) if any(!isempty, row)]
    rows, values = rows[kept], values[kept]
  else
    rows = filter(row -> any(!isempty, row), rows)
    values = nothing
  end
  isempty(rows) && return nothing_to_draw("This table has no rows yet.")
  wide = maximum(length, rows)
  cell(row, k) = k <= length(row) ? row[k] : ""
  headed = headed || (length(rows) > 1 && !any(isnumber, rows[1][2:end]) && !(wide == 1 && isnumber(rows[1][1])))
  head = headed ? [cell(rows[1], k) for k in 1:wide] : fill("", wide)
  body = headed ? rows[2:end] : rows
  isempty(body) && return nothing_to_draw("This table has no rows under its headings yet.")
  origin = length(rows) - length(body) + 1
  # The amount of the cell in row `r` of the whole table, or nothing
  amount_at(r, k) = values === nothing || !(1 <= r <= length(values)) || k > length(values[r]) ? nothing : values[r][k]
  readat(i, k) = begin
    got = reading(amount_at(origin + i - 1, k))
    got === nothing ? number(cell(body[i], k)) : got
  end
  column(k) = [cell(row, k) for row in body]
  # A column of numbers has a number in most of its cells that hold something
  numeric(k) = begin
    idx = [i for i in eachindex(body) if !isempty(cell(body[i], k)) || reading(amount_at(origin + i - 1, k)) !== nothing]
    !isempty(idx) && 2count(i -> readat(i, k) !== nothing, idx) > length(idx)
  end
  by = !isempty(c.by) ? findfirst(k -> same(head[k], c.by), 1:wide) : by_first ? 1 : findfirst(k -> !numeric(k), 1:wide)
  !isempty(c.by) && by === nothing && return nothing_to_draw("The table has no column called “$(c.by)”.")
  shown = Int[]
  for name in c.show
    k = findfirst(k -> same(head[k], name), 1:wide)
    k === nothing && (part ? continue : return nothing_to_draw("The table has no column called “$(name)”."))
    numeric(k) || return nothing_to_draw("The column “$(name)” has no numbers.")
    push!(shown, k)
  end
  part && !isempty(c.show) && isempty(shown) && return Data(String[], Series[], "", "", "")   # what it shows is in the other tables
  isempty(shown) && (shown = [k for k in 1:wide if k != by && numeric(k)])
  isempty(shown) && return nothing_to_draw("This table has no column of numbers.")
  labels = by === nothing ? string.(1:length(body)) : column(by)
  found = [readat(i, k) for i in eachindex(body), k in shown]
  marks(place) = unique(n[place] for n in found if n !== nothing)
  before, after = marks(2), marks(3)
  series = [Series(isempty(head[k]) ? (length(shown) == 1 ? "" : "Column $k") : head[k],
                   Union{Nothing,Float64}[n === nothing ? nothing : n[1] for n in found[:, j]]) for (j, k) in enumerate(shown)]
  d = Data(labels, first(series, MOST), length(before) == 1 ? before[1] : "", length(after) == 1 ? after[1] : "", "", max(length(series) - MOST, 0))
  d = part ? d : without_total(d)
  c.kind == :pie && !part ? slices(d) : d
end

"Names of a row that adds the others up"
const TOTALS = ("in all", "total", "totals", "sum", "overall")

total_row(name) = lowercase(strip(name)) in TOTALS

"""
The rows of `d` with a total taken out. The total is the last row named In all,
Total or Sum, and it has a number. With one column of numbers, that row is
`apart`, so the chart can write it on its own.
"""
without_total(d::Data) = begin
  i = findlast(total_row, d.labels)
  i === nothing && return d
  any(s -> s.values[i] !== nothing, d.series) || return d
  keep = [k for k in eachindex(d.labels) if k != i]
  isempty(keep) && return d
  apart = length(d.series) == 1 ? (d.labels[i], d.series[1].values[i]) : nothing
  Data(d.labels[keep], [Series(s.name, s.values[keep]) for s in d.series], d.before, d.after, d.problem, d.more, apart)
end

"""
What the chart `c` shows of several tables at once: the `data` of each, with
the name that the chart calls it by in `names`. Each table's columns are drawn
over the same names, like the years of two sheets over the same range. A name
that only some tables have is a gap in the lines of the others. When every
name is a number, they go in the order of their numbers. Two columns with the
same name get the names of their tables after them.
"""
joined(c::Chart, ds::Vector{Data}, names::Vector{String}) = begin
  for (d, name) in zip(ds, names)
    isempty(d.problem) && continue
    return nothing_to_draw(replace(d.problem, r"^(The|This) table " => "The table “$(name)” ", "The column “" => "The column of “$(name)” called “"))
  end
  missed = [n for n in c.show if !any(d -> any(s -> same(s.name, n), d.series), ds)]
  isempty(missed) || return nothing_to_draw("No table has a column called “$(missed[1])”.")
  labels = unique(l for d in ds for l in d.labels)
  all(isnumber, labels) && sort!(labels, by=l -> number(l)[1])
  place = Dict(l => k for (k, l) in enumerate(labels))
  series = Series[]
  for (d, name) in zip(ds, names), s in d.series
    values = Vector{Union{Nothing,Float64}}(nothing, length(labels))
    for (k, l) in enumerate(d.labels)
      k <= length(s.values) && (values[place[l]] = s.values[k])
    end
    twice = count(d -> any(t -> same(t.name, s.name), d.series), ds) > 1
    push!(series, Series(twice ? "$(s.name) ($name)" : s.name, values))
  end
  isempty(series) && return nothing_to_draw("These tables have no column of numbers.")
  agreed(f) = (marks = unique(f(d) for d in ds if !isempty(d.series)); length(marks) == 1 ? marks[1] : "")
  d = Data(labels, first(series, MOST), agreed(d -> d.before), agreed(d -> d.after), "",
           sum(d -> d.more, ds) + max(length(series) - MOST, 0))
  c.kind == :pie ? slices(d) : d
end

"""
The slices of a pie: the first column of numbers, biggest first. A number
that's nothing or less has no slice. The smallest of more than `SLICES` slices
are one slice, called Other.
"""
slices(d::Data) = begin
  s = d.series[1]
  parts = [(d.labels[i], s.values[i]) for i in eachindex(s.values) if s.values[i] !== nothing && s.values[i] > 0]
  isempty(parts) && return nothing_to_draw("A pie needs numbers that are more than nothing.")
  sort!(parts, by=last, rev=true)
  if length(parts) > SLICES
    rest = sum(last, parts[SLICES:end])
    parts = [parts[1:SLICES-1]; ("Other", rest)]
  end
  Data(first.(parts), [Series(s.name, Union{Nothing,Float64}[last(p) for p in parts])], d.before, d.after, "", 0, d.apart)
end

"A number of the chart `d` in words, with what its table writes before and after each number"
amount(d::Data, x::Real) = (x < 0 ? "−" : "") * d.before * spoken(abs(x)) * d.after

"The least and the most of the numbers that `d` shows, or nothing when it shows none"
extent(d::Data) = begin
  all = [v for s in d.series for v in s.values if v !== nothing]
  isempty(all) ? nothing : extrema(all)
end

"""
The numbers beside a chart of `d`. Bars stand on the line of 0, so 0 is always
one of them. Lines show 0 too, unless every number is far from it.
"""
scale(d::Data, kind::Symbol) = begin
  ex = extent(d)
  ex === nothing && return [0.0, 1.0]
  lo, hi = ex
  near = kind == :bars || lo <= 0 <= hi || (lo > 0 && lo < 0.6hi) || (hi < 0 && hi > 0.6lo)
  near ? ticks(min(lo, 0.0), max(hi, 0.0)) : ticks(lo, hi)
end

# --- where each part of a chart goes -----------------------------------------------------
#
# `plot` turns what a chart shows into marks: the bars, the lines, the dots,
# the slices, the words and the lines behind them, each with its place. The
# editor draws the marks in its window, and `svg` writes them as a picture
# for a page of HTML. So the two always show the same chart.

"""
One part of a chart, and where it goes. What `at` holds depends on its kind:

- `:bar`: its left, top, width and height. `style` is `:up` or `:down`, the way that it stands from the line of 0.
- `:line`: nothing. It goes through `points`.
- `:dot`: its middle, then its radius.
- `:slice`: the middle of its pie, then the two angles that it's between. `size` is the pie's radius, and `points` is its outline.
- `:rule`: its two ends. `style` is `:strong` for the line of 0.
- `:swatch`: its left, top, width and height.
- `:words`: where its text starts, ends or has its middle, as `style` says: `:start`, `:end` or `:middle`. `size` is the size of its text, and `tone` is `:ink` or `:dim`.

`colour` is the place of its colour among the chart's colours, or 0. `label` and
`series` say which number it stands for, or 0 when it stands for none.
"""
struct Mark
  kind::Symbol
  at::NTuple{4,Float64}
  points::Vector{NTuple{2,Float64}}
  text::String
  colour::Int
  style::Symbol
  tone::Symbol
  size::Float64
  label::Int
  series::Int
end

Mark(kind, at; points=NTuple{2,Float64}[], text="", colour=0, style=:none, tone=:dim, size=11.0, label=0, series=0) =
  Mark(kind, Float64.(at), points, text, colour, style, tone, Float64(size), label, series)

const SMALL = 11.0    # the size of the words of a chart
const LEGEND_H = 22.0 # how tall a row of the names of the colours is
const BAR_MOST = 24.0 # the widest that a bar gets
const BAR_GAP = 2.0   # between two bars that are side by side

"`text`, cut short with … so that it's no wider than `room`. `measure(text, size)` says how wide text is."
fit(text::AbstractString, room::Real, measure, size=SMALL) = begin
  measure(text, size) <= room && return String(text)
  chars = collect(text)
  while !isempty(chars) && measure(String(chars) * "…", size) > room
    pop!(chars)
  end
  isempty(chars) ? "" : rstrip(String(chars)) * "…"
end

"""
The names of the colours, in rows across the top of a chart that's `wide`
wide. It gives the marks, and how tall the rows are together. A chart of one
column of numbers has no names: its title says what it shows.
"""
legend(d::Data, wide::Real, measure) = begin
  marks = Mark[]
  length(d.series) > 1 || d.more > 0 || return marks, 0.0
  x, y = 12.0, 2.0
  entries = [(j, s.name) for (j, s) in enumerate(d.series)]
  d.more > 0 && push!(entries, (0, d.more == 1 ? "and 1 more column that isn't drawn" : "and $(d.more) more columns that aren't drawn"))
  for (j, name) in entries
    words = fit(name, wide - 44, measure, 12.0)
    w = (j > 0 ? 16.0 : 0.0) + measure(words, 12.0) + 18
    x > 12 && x + w > wide && ((x, y) = (12.0, y + LEGEND_H))
    j > 0 && push!(marks, Mark(:swatch, (x, y + 4, 10, 10), colour=j))
    push!(marks, Mark(:words, (x + (j > 0 ? 16 : 0), y + 13, 0, 0), text=words, style=:start, tone=j > 0 ? :ink : :dim, size=12.0))
    x += w
  end
  marks, y + LEGEND_H
end

"""
The marks of a chart of `d` that's `wide` wide and `tall` tall. `kind` is
`:bars`, `:lines` or `:pie`. `measure(text, size)` says how wide text is.
"""
plot(d::Data, kind::Symbol, wide::Real, tall::Real, measure) = begin
  (isempty(d.series) || isempty(d.labels)) && return Mark[]
  kind == :pie && return pie(d, wide, tall, measure)
  marks, top = legend(d, wide, measure)
  top += 18
  if d.apart !== nothing
    name, v = d.apart
    push!(marks, Mark(:words, (wide - 14, top + 4, 0, 0), text=name * "  " * amount(d, v), style=:end, tone=:ink, size=12.0))
    top += 18
  end
  ts = scale(d, kind)
  lo, hi = ts[1], ts[end]
  most = max(abs(lo), abs(hi))
  beside = [(t < 0 ? "−" : "") * d.before * short(abs(t), most) * d.after for t in ts]
  left = maximum(w -> measure(w, SMALL), beside) + 20
  right, bottom = 14.0, 26.0
  pw, ph = max(wide - left - right, 10.0), max(tall - top - bottom, 10.0)
  y(v) = top + (hi - v) / (hi - lo) * ph
  for (t, words) in zip(ts, beside)
    push!(marks, Mark(:rule, (left, y(t), left + pw, y(t)), style=t == 0 ? :strong : :none))
    push!(marks, Mark(:words, (left - 8, y(t) + 4, 0, 0), text=words, style=:end))
  end
  n, m = length(d.labels), length(d.series)
  band = pw / n
  middle(i) = left + (i - 0.5) * band
  # A name goes under every bar where there's room, or under every second or third one where there isn't
  widest = min(maximum(l -> measure(l, SMALL), d.labels), 96.0)
  every = max(1, ceil(Int, (widest + 10) / band))
  for i in 1:every:n
    words = fit(d.labels[i], max(band * every - 6, 16.0), measure)
    isempty(words) || push!(marks, Mark(:words, (middle(i), top + ph + 17, 0, 0), text=words, style=:middle))
  end
  base = y(clamp(0.0, lo, hi))
  if kind == :bars
    bw = clamp((band * 0.72 - BAR_GAP * (m - 1)) / m, 1.0, BAR_MOST)
    group = m * bw + BAR_GAP * (m - 1)
    # One column of numbers has each number over its bar, where they all have room
    said = [v === nothing ? "" : amount(d, v) for v in d.series[1].values]
    capped = m == 1 && maximum(w -> measure(w, SMALL), said) <= band - 6
    for i in 1:n, (j, s) in enumerate(d.series)
      v = s.values[i]
      v === nothing && continue
      x = middle(i) - group / 2 + (j - 1) * (bw + BAR_GAP)
      tip = y(v)
      push!(marks, Mark(:bar, (x, min(tip, base), bw, abs(tip - base)), colour=j, style=v >= 0 ? :up : :down, label=i, series=j))
      capped && push!(marks, Mark(:words, (x + bw / 2, v >= 0 ? tip - 5 : tip + 13, 0, 0), text=said[i], style=:middle))
    end
  else
    for (j, s) in enumerate(d.series)
      run = NTuple{2,Float64}[]
      # A cell that isn't a number makes a gap in the line
      for i in 1:n+1
        v = i <= n ? s.values[i] : nothing
        if v === nothing
          length(run) > 1 && push!(marks, Mark(:line, (0, 0, 0, 0), points=run, colour=j))
          run = NTuple{2,Float64}[]
        else
          push!(run, (middle(i), y(v)))
        end
      end
    end
    # The dots go over every line. A chart with a lot of numbers has a dot only where a number stands alone.
    for (j, s) in enumerate(d.series), i in 1:n
      v = s.values[i]
      v === nothing && continue
      alone = (i == 1 || s.values[i-1] === nothing) && (i == n || s.values[i+1] === nothing)
      push!(marks, Mark(:dot, (middle(i), y(v), n <= 40 || alone ? 4.0 : 0.0, 0), colour=j, label=i, series=j))
    end
  end
  marks
end

"The share that `v` is of `total`, like 28.6%"
percent(v::Real, total::Real) = words(round(100v / total, digits=1)) * "%"

"The marks of a pie of `d`: its slices on the left, and the name and the share of each on the right"
pie(d::Data, wide::Real, tall::Real, measure) = begin
  marks = Mark[]
  values = Float64[v for v in d.series[1].values]
  total = sum(values)
  r = max(min(tall - 24, wide * 0.42) / 2, 10.0)
  cx, cy = 16 + r, tall / 2
  from = -π / 2
  for (i, v) in enumerate(values)
    to = from + 2π * v / total
    steps = max(2, ceil(Int, (to - from) / 0.05))
    outline = [(cx, cy); [(cx + r * cos(a), cy + r * sin(a)) for a in range(from, to, length=steps + 1)]]
    push!(marks, Mark(:slice, (cx, cy, from, to), points=outline, colour=i, size=r, label=i, series=1))
    from = to
  end
  x = cx + r + 28
  row = 24.0
  shares = ["$(amount(d, v))  ·  $(percent(v, total))" for v in values]
  total_words = d.apart === nothing ? "" : amount(d, d.apart[2])
  # The shares are in a column of their own, after the longest name. The total sits under them.
  room = max(wide - x - 16 - maximum(s -> measure(s, 12.0), [shares; total_words]) - 40, 30.0)
  names = [fit(l, room, measure, 12.0) for l in d.labels]
  named = d.apart === nothing ? names : [names; fit(d.apart[1], room, measure, 12.0)]
  right = min(wide - 16, x + 16 + maximum(n -> measure(n, 12.0), named) + 40 + maximum(s -> measure(s, 12.0), [shares; total_words]))
  y = cy - row * (length(values) + (d.apart === nothing ? 0 : 1)) / 2
  for i in eachindex(values)
    push!(marks, Mark(:swatch, (x, y + 7, 10, 10), colour=i))
    push!(marks, Mark(:words, (x + 16, y + 16, 0, 0), text=names[i], style=:start, tone=:ink, size=12.0))
    wide - x > 200 && push!(marks, Mark(:words, (right, y + 16, 0, 0), text=shares[i], style=:end, size=12.0))
    y += row
  end
  if d.apart !== nothing
    y += 4
    push!(marks, Mark(:rule, (x, y, right, y)))
    push!(marks, Mark(:words, (x, y + 18, 0, 0), text=named[end], style=:start, tone=:ink, size=12.0))
    wide - x > 200 && push!(marks, Mark(:words, (right, y + 18, 0, 0), text=total_words, style=:end, size=12.0))
  end
  marks
end

"""
The mark that stands for a number at the place `(x, y)`, or nothing. A bar
counts for the whole height of the chart over and under it, and a dot for a
little way round it, so that neither is hard to point at.
"""
hit(marks::Vector{Mark}, x::Real, y::Real) = begin
  best, near = nothing, 14.0
  for m in marks
    m.label == 0 && continue
    if m.kind == :bar
      m.at[1] - 1 <= x <= m.at[1] + m.at[3] + 1 && return m
    elseif m.kind == :dot
      far = hypot(x - m.at[1], y - m.at[2])
      far < near && ((best, near) = (m, far))
    elseif m.kind == :slice
      dx, dy = x - m.at[1], y - m.at[2]
      hypot(dx, dy) <= m.size || continue
      a = mod(atan(dy, dx) + π / 2, 2π) - π / 2   # the angle, counted from the top as the slices are
      m.at[3] <= a < m.at[4] && return m
    end
  end
  best
end

"What the number that `m` stands for is, in words: the name of its bar, the name of its column and the number"
said(d::Data, m::Mark) = begin
  s = d.series[m.series]
  v = s.values[m.label]
  share = m.kind == :slice ? "  ·  " * percent(v, sum(x -> something(x, 0.0), s.values)) : ""
  name = length(d.series) > 1 && !isempty(s.name) ? "$(d.labels[m.label])  ·  $(s.name)" : d.labels[m.label]
  "$name:  $(amount(d, v))$share"
end

# --- a chart as a picture for a page of HTML ---------------------------------------------

xml(s::AbstractString) = replace(s, "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")
coord(x::Real) = (r = round(x, digits=1); r == round(r) ? string(round(Int, r)) : string(r))

"The outline of a bar, for an SVG path. The end that's away from the line of 0 has round corners."
bar_path(m::Mark) = begin
  x, y, w, h = m.at
  r = min(4.0, w / 2, h)
  c = coord
  m.style == :down ?
    "M$(c(x)),$(c(y))H$(c(x + w))V$(c(y + h - r))Q$(c(x + w)),$(c(y + h)) $(c(x + w - r)),$(c(y + h))H$(c(x + r))Q$(c(x)),$(c(y + h)) $(c(x)),$(c(y + h - r))Z" :
    "M$(c(x)),$(c(y + h))V$(c(y + r))Q$(c(x)),$(c(y)) $(c(x + r)),$(c(y))H$(c(x + w - r))Q$(c(x + w)),$(c(y)) $(c(x + w)),$(c(y + r))V$(c(y + h))Z"
end

"""
The marks of a chart as an SVG picture. `colours` holds the colour of each
column of numbers, and `ink`, `dim`, `line` and `surface` are the colours of
the page's text, its quiet text, its lines and the page itself, each as CSS
writes a colour.
"""
svg(marks::Vector{Mark}, wide::Real, tall::Real; colours, ink, dim, line, surface, family="sans-serif") = begin
  out = IOBuffer()
  c = coord
  through(points) = join(("$(c(x)),$(c(y))" for (x, y) in points), " ")
  println(out, "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 $(c(wide)) $(c(tall))\" width=\"$(c(wide))\" font-family=\"$(xml(family))\" role=\"img\">")
  for m in marks
    colour = m.colour == 0 ? dim : colours[m.colour]
    if m.kind == :rule
      println(out, "<line x1=\"$(c(m.at[1]))\" y1=\"$(c(m.at[2]))\" x2=\"$(c(m.at[3]))\" y2=\"$(c(m.at[4]))\" stroke=\"$(m.style == :strong ? dim : line)\" stroke-width=\"1\"/>")
    elseif m.kind == :bar
      println(out, "<path d=\"$(bar_path(m))\" fill=\"$colour\"/>")
    elseif m.kind == :line
      println(out, "<polyline points=\"$(through(m.points))\" fill=\"none\" stroke=\"$colour\" stroke-width=\"2\" stroke-linejoin=\"round\" stroke-linecap=\"round\"/>")
    elseif m.kind == :dot
      m.at[3] > 0 && println(out, "<circle cx=\"$(c(m.at[1]))\" cy=\"$(c(m.at[2]))\" r=\"$(c(m.at[3]))\" fill=\"$colour\" stroke=\"$surface\" stroke-width=\"2\"/>")
    elseif m.kind == :slice
      println(out, "<polygon points=\"$(through(m.points))\" fill=\"$colour\" stroke=\"$surface\" stroke-width=\"2\" stroke-linejoin=\"round\"/>")
    elseif m.kind == :swatch
      println(out, "<rect x=\"$(c(m.at[1]))\" y=\"$(c(m.at[2]))\" width=\"$(c(m.at[3]))\" height=\"$(c(m.at[4]))\" rx=\"2.5\" fill=\"$colour\"/>")
    elseif m.kind == :words
      anchor = m.style == :end ? "end" : m.style == :middle ? "middle" : "start"
      println(out, "<text x=\"$(c(m.at[1]))\" y=\"$(c(m.at[2]))\" font-size=\"$(c(m.size))\" text-anchor=\"$anchor\" fill=\"$(m.tone == :ink ? ink : dim)\">$(xml(m.text))</text>")
    end
  end
  print(out, "</svg>")
  String(take!(out))
end
