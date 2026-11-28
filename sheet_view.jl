# The views of spreadsheets and of sheets, and the names a sheet offers
#
# A code block in the language `spreadsheet` is drawn as a spreadsheet. Each
# line of the block is a row, with a | between its cells, as in a table. A row
# of letters is over the cells, one for each column. A column of numbers is on
# their left, one for each row. A cell that starts with = is a formula: a Julia
# expression that can use the other cells by name, like B2 * C2 or sum(D2:D9).
# The cell shows what its formula comes to. While the caret is in the cell, it
# shows the formula.
#
# It's laid out as a `Grid`, so the caret moves as it does in a table, and the
# bar over the grid adds and removes a row or a column. Hold ⌥ and click the
# spreadsheet to see it as lines of code.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" rectangle
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" WrapMode describe
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw show_tooltip!
@use "github.com/jkroso/UI.jl/Interface/objc" sel
@use "github.com/jkroso/UI.jl/Interface/fonts" register_font
@use "./pictures" natural
@use "./markdown" Kind
@use "./highlight" tokens
@use "./sheet" SHEET Result sheetcells parts uses tally known ident cases
@use "./spreadsheet" SPREADSHEET spreadcells spreadtexts isformula letters answers moved
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./julia_levels" exports...
@use "./csv_view" exports...
@use "./file_view" exports...

export SPREAD_Y, gridrows, cellnames, spreadgrid, spreadsheet, ring, spreadop!, droprow!,
       SpreadBlock, SHEET_GAP, SHEET_X, SHEET_Y, RAISE, RESULT_X, load_sheet_font, drawn,
       exprpieces, chip_w, sheet_case, sheetgrid, row_top, expr_x, cellflow, cellunder, rowunder,
       place, sheetseg, sheetlines, next_row!, sheet_tab!, erase_row!, isnamechar, offered,
       suggesting, suggestion, suggest_key!, suggestbox, LinkNotes, Suggesting, enter

const SPREAD_Y = 5px   # above and below the text of a cell

"""
The lines that open and close the spreadsheet that line `i` is in, or nothing.
A spreadsheet needs a row, and it shows as lines of code while the caret is on
the line that opens or closes it.
"""
spread(b::Buffer, i::Int) = drawn(b, i, SPREADSHEET)

"True when line `i` is a row of a spreadsheet"
inspread(b::Buffer, i::Int) = begin
  run = spread(b, i)
  run !== nothing && run[1] < i < run[2]
end

"The lines that are the rows of the table or the spreadsheet that line `i` is in"
gridrows(b::Buffer, i::Int) = begin
  run = spread(b, i)
  run === nothing ? tablerows(table(b, i)) : collect(run[1]+1:run[2]-1)
end

"The name of every cell of a spreadsheet that has `rows` rows and `cols` columns"
cellnames(rows::Int, cols::Int) = [letters(c) * string(r) for r in 1:rows for c in 1:cols]

"Lay out the spreadsheet whose code block opens on line `from` and closes on line `to`"
spreadgrid(e, from::Int, to::Int) = begin
  b = e.buf
  caret = alone(b, b.caret[1]) && from < b.caret[1] < to ? b.caret : nothing
  build() = begin
    base = Face(body(e), size=body(e).size * 0.94)
    lh = base.size * 1.5
    rows = collect(from+1:to-1)
    cells = [spreadcells(b.lines[i]) for i in rows]
    texts = [spreadtexts(b.lines[i]) for i in rows]
    # The cells are only worked out again when the text of one changes
    values = get!(() -> answers(texts), e.flows, (:answers, texts))
    ncols = maximum(length, cells)
    typing(r, c) = caret !== nothing && caret[1] == rows[r] && c <= length(cells[r]) && within(cells[r][c], caret[2])
    # What the cell in row `r`, column `c` shows. With `on`, it's the cell with the caret.
    shows(r, c, on) = begin
      c <= length(cells[r]) || return Piece[]
      i, cell, v = rows[r], cells[r][c], values[r][c]
      # The cell with the caret shows the spaces typed after its text
      upto = on ? max(cell.hi, caret[2]) : cell.hi
      isformula(texts[r][c]) || return cellpieces(e, i, b.lines[i], cell.lo, upto, base, on)
      # A formula shows what it comes to. With the caret in its cell, it shows the formula, and each cell that it names is a chip.
      on && return exprpieces(b.lines[i], cell.lo, upto, cellnames(length(rows), ncols), base)
      [piece(v.failed ? "!" : v.text, cell.lo, base, atomic=true, n=cell.hi - cell.lo)]
    end
    # The columns are as wide as they are with no caret in a cell, so a column keeps its width
    # while you edit one of its cells. A formula that's wider than its column wraps.
    resting = [[shows(r, c, false) for c in 1:ncols] for r in eachindex(rows)]
    parts = [[typing(r, c) ? shows(r, c, true) : resting[r][c] for c in 1:ncols] for r in eachindex(rows)]
    # Each column gets room in proportion to its longest cell, as in a table
    natural = [clamp(maximum(row -> sum(wide, row[c], init=0px), resting, init=0px) + 2CELL_X, 60px, e.width * 0.75) for c in 1:ncols]
    gutter = max(measure(Face(base, family=SANS, size=base.size * 0.72), string(length(rows))) + 14px, base.size * 1.9)
    space = e.width - gutter - 1px * (ncols + 2)
    least = [min(natural[c], max(maximum(row -> maximum(unbroken, row[c], init=0px), resting, init=0px) + 2CELL_X, 36px)) for c in 1:ncols]
    widths = share_widths(natural, least, space)
    flows = [[align(wrap(row[c], widths[c] - 2CELL_X; lh, size=base.size, left=CELL_X), widths[c] - 2CELL_X,
                    # A number stays on the right while you type it. A formula is on the left while its cell shows it.
                    c <= length(cells[r]) && values[r][c].number && !(typing(r, c) && isformula(texts[r][c])) ? :right : :left)
              for c in 1:ncols] for (r, row) in enumerate(parts)]
    heights = [maximum(tall, row) + 2SPREAD_Y for row in flows]
    Grid(rows, widths, heights, cells, flows, lh + 1px, gutter + 1px, values)
  end
  # What inline code made can change its size, so a spreadsheet with some in it is laid out again each time
  any(text -> occursin(INLINE, text), @view b.lines[from:to]) && return build()
  get!(build, e.flows, (:spread, from, b.lines[from:to], caret))
end

"A spreadsheet as nodes: the grid of a table, with a row of letters over it and a column of numbers on its left"
spreadsheet(e::Editor, it::Item, g::Grid) = begin
  b = e.buf
  line = border(1px, :solid, colours.line; between=true)
  size = body(e).size * 0.94
  at = alone(b, b.caret[1]) ? gridcell(g, b.caret) : nothing
  # The letter and the number of the caret's cell are darker
  name(text, on) = Box(height(grow=grow), Alignment.Center, justify=Alignment.Center,
                       label(text, size * 0.72, color=on ? colours.ink : colours.dim, weight=on ? "Semibold" : ""))
  cell(r, c) = begin
    v = c <= length(g.values[r]) ? g.values[r][c] : nothing
    # A formula that went wrong shows a !, which says what went wrong while the mouse is over it
    (v !== nothing && v.failed && at != (r, c)) || return rows(g.flows[r][c])
    [Box(padding(CELL_X, 0px), own!(node!(Document, e, :document), Trouble(message=v.text, size=size * 0.9)))]
  end
  # Its corners are round, as a chart's are. The letters are the first of its rows, and the last row's number has a round corner.
  n = length(g.rows) + 1
  head = Row(width(grow=grow), height(g.head - 1px), Alignment.Start, line[:between], inner_round(1, n), background(colours.head),
    Box(fixed(g.left - 1px), height(grow=grow)),
    [Box(fixed(g.widths[c]), height(grow=grow), name(letters(c), at !== nothing && at[2] == c)) for c in eachindex(g.widths)]...)
  body_rows = [Row(width(grow=grow), height(g.heights[r]), Alignment.Start, line[:between], inner_round(r + 1, n), background(colours.bg),
                 Box(fixed(g.left - 1px), height(grow=grow), background(colours.head), radius(0px, 0px, 0px, inner_round(r + 1, n).bl),
                     name(string(r), at !== nothing && at[1] == r)),
                 [Column(fixed(g.widths[c]), height(grow=grow), Alignment.Start, justify=Alignment.Center, cell(r, c)...)
                  for c in eachindex(g.widths)]...)
               for r in eachindex(g.rows)]
  Box(width(grow=grow), padding(0px, TABLE_GAP),
    Column(width(grow=grow), Alignment.Start, line, radius(BLOCK_ROUND), name="Spreadsheet", head, body_rows...))
end

"Draw a line around the cell in row `r`, column `c` of a spreadsheet whose item has its top left corner at (x, y)"
ring(ctx, g::Grid, (r, c), x, y) =
  rectangle(ctx, x + g.left + 1px * c + sum(g.widths[1:c-1], init=0px) - 0.5px,
            y + TABLE_GAP + g.head + 1px * r + sum(g.heights[1:r-1], init=0px) - 0.5px,
            g.widths[c] + 1px, g.heights[r] + 1px, stroke=colours.accent, border=1.5px)

"""
Add or remove a row or a column of the spreadsheet the caret is in, at the
caret. Each formula still names the same cells after it: a cell that moved has
a new name, so the formula is written with that name.
"""
spreadop!(e, action::Symbol) = begin
  b = e.buf
  i = b.caret[1]
  inspread(b, i) || return
  s, t = spread(b, i)
  rows = map(spreadtexts, b.lines[s+1:t-1])
  n = maximum(length, rows)
  rows = [[row; fill("", n - length(row))] for row in rows]
  r = i - s                                           # the caret's row
  c = nearest(spreadcells(b.lines[i]), b.caret[2])    # and its column
  if action == :addrow
    r += 1
    rows = [moved.(row, 1, row=r) for row in rows]
    insert!(rows, r, fill("", n))
  elseif action == :delrow
    length(rows) == 1 && return
    deleteat!(rows, r)
    rows = [moved.(row, -1, row=r + 1) for row in rows]
    r = min(r, length(rows))
  elseif action == :addcol
    c += 1
    rows = [moved.(row, 1, col=c) for row in rows]
    foreach(row -> insert!(row, c, ""), rows)
  elseif action == :delcol
    n == 1 && return
    foreach(row -> deleteat!(row, c), rows)
    rows = [moved.(row, -1, col=c + 1) for row in rows]
    c = min(c, n - 1)
  else
    return
  end
  edit!(b, (s + 1, 0), line_end(b, t - 1), join(map(tableline, rows), "\n"))
  b.caret = b.anchor = (s + r, spreadcells(b.lines[s+r])[c].hi)
  touch!(e)
end

"Backspace in an empty row of a spreadsheet removes the row, and the last row takes the spreadsheet with it"
droprow!(e) = begin
  b = e.buf
  i = b.caret[1]
  s, t = spread(b, i)
  t - s == 2 && return (edit!(b, (s, 0), line_end(b, t), ""); touch!(e))
  spreadop!(e, :delrow)
  above = max(i - 1, s + 1)
  b.caret = b.anchor = (above, spreadcells(b.lines[above])[end].hi)
  touch!(e)
end

struct SpreadBlock end
BLOCKS[SPREADSHEET] = SpreadBlock
block_name(::Type{SpreadBlock}) = "Spreadsheet"
block_icon(::Type{SpreadBlock}) = "grid-3x3"
block_insert(::Type{SpreadBlock}) = ("Spreadsheet", ["```$SPREADSHEET", "|  |  |  |", "|  |  |  |", "|  |  |  |", "```"], (2, 2))
block_is_whole(::Type{SpreadBlock}, ::AbstractString) = false
block_outline_inside(::Type{SpreadBlock}) = true
block_table_kind(::Type{SpreadBlock}) = "spreadsheet"
block_html(::Type{SpreadBlock}, e, lang::AbstractString, s::Int, t::Int) = nothing
block_layout(::Type{SpreadBlock}, e, lang::AbstractString, i::Int, n::Int) =
  (run = drawn(e.buf, i, SPREADSHEET); run === nothing ? nothing : (run[2], spreadgrid(e, run...)))
block_tables!(::Type{SpreadBlock}, e, i::Int, t::Int, under::AbstractString, out) = begin
  b = e.buf
  texts = [spreadtexts(b.lines[r]) for r in i+1:t-1]
  values = get!(() -> answers(texts), e.flows, (:answers, texts))
  rows = [String[isformula(text) ? (values[r][c].failed ? "" : values[r][c].text) : String(strip(text)) for (c, text) in enumerate(row)]
          for (r, row) in enumerate(texts)]
  push!(out, (first=i, last=t, under=under, rows=rows, headed=false, ranged=false))
end

# --- sheets ----------------------------------------------------------------------------
#
# A code block in the language `sheet` is drawn as a sheet, like the one in
# Centient's notepad. Each line of the block is a row: a name, an = and a Julia
# expression. The expression can use the names of the rows above it the way
# they're written, and those names show as chips. What each row comes to shows
# on its right. A row without a name shows its number instead.
#
# The caret moves from cell to cell, as it does in a table. Tab and shift-Tab
# go to the next and the last cell, and Return starts a row. Hold ⌥ and click
# the sheet to see it as lines of code.

const SHEET_GAP = 8px   # above and below a sheet
const SHEET_X = 10px    # beside the text of a cell
const SHEET_Y = 4px     # above the first row and below the last
const RAISE = 0.28      # of the size of the text: how far a character from the spare font goes up, twice over
const RESULT_X = 8px    # beside the text of what a row comes to

"""
Read the sheet's font from its file. A request for a weight of this font by
name can come back in another weight, so the file is read itself. This runs each time an
editor is made, because a built app forgets its fonts when it starts.
"""
load_sheet_font() = isempty(SHEET_FILE) || register_font(SHEET_FILE)

"""
The lines that open and close the sheet that line `i` is in, or nothing. A
sheet needs a row, and it shows as lines of code while the caret is on the
line that opens or closes it.
"""
sheet(b::Buffer, i::Int) = drawn(b, i, SHEET)

"The lines that open and close the code block in the language `lang` that line `i` is in, when the block is drawn as a sheet or a spreadsheet"
drawn(b::Buffer, i::Int, lang::String) = begin
  ks = kinds(b)
  (ks[i].kind == Kind.fence || (ks[i].kind == Kind.code && ks[i].lang == lang)) || return nothing
  s, t = codeblock(b, i)
  (t > s + 1 && ks[s].kind == Kind.fence && ks[s].lang == lang && ks[t].kind == Kind.fence && ks[t].level == 1) || return nothing
  israw(b, s) || israw(b, t) ? nothing : (s, t)
end

"True when line `i` is a row of a sheet"
insheet(b::Buffer, i::Int) = begin
  run = sheet(b, i)
  run !== nothing && run[1] < i < run[2]
end

"""
The runs of text in the expression that is columns `lo` to `hi` of `text`. Each
of `names` is a chip, and a * that multiplies shows as ×.
"""
exprpieces(text::String, lo::Int, hi::Int, names, base::Face) = begin
  expr = rest(head(text, hi), lo)
  chars = collect(expr)
  faces = fill(base, length(chars))
  times = [c == '*' for c in chars]
  for t in tokens(expr, "julia")
    t.kind == :plain && continue
    span = t.col+1:t.col+length(t.text)
    faces[span] .= Ref(Face(base, color=getfield(colours, t.kind)))
    # A * in a string or a comment is only a *
    t.kind in (:string, :comment) && (times[span] .= false)
  end
  for (a, z, _) in uses(expr, names)
    faces[a+1:z] .= Ref(Face(base, chip=true))
  end
  out = Piece[]
  i = 1
  while i <= length(chars)
    if times[i]
      push!(out, piece("×", lo + i - 1, faces[i], atomic=true, n=1))
      i += 1
      continue
    end
    j = i
    while j < length(chars) && faces[j+1] === faces[i] && !times[j+1]; j += 1 end
    push!(out, piece(String(chars[i:j]), lo + i - 1, faces[i]))
    i = j + 1
  end
  out
end

"How wide the chip that shows `r` is. A row that went wrong shows a !."
chip_w(face::Face, r::Result) =
  isempty(r.text) ? 0px : r.failed ? measure(face, "!") + 2RESULT_X : sum(measure(f, t) for (t, f) in runs(r.text, face)) + 2RESULT_X

"""
Where a sheet with a row over a range shows itself: at the value of that row
that the mouse is on, in a chart of the sheet or in any other part of the
page, as a number from 0 at the first value to 1 at the last. It's nothing
while the mouse is on no such value: the sheet then shows both ends.
"""
sheet_case(e, texts, given) = begin
  name = pointed(e)
  name === nothing && return nothing
  over = get!(() -> sheet_work(() -> cases(texts; given, cache=e.flows), e), e.flows, (:cases, texts, given))
  over === nothing && return nothing
  k = findfirst(row -> plain_name(row[1]) == name, view(over.table, 2:length(over.table)))
  k === nothing ? nothing : over.places[k]
end

"Lay out the sheet whose code block opens on line `from` and closes on line `to`"
sheetgrid(e, from::Int, to::Int) = begin
  b = e.buf
  caret = from < b.caret[1] < to && b.caret[1] == b.anchor[1] ? b.caret : nothing
  # The layout holds the number of each row's line, so it's kept for these lines only
  # The names that the sheet has from the parts of the page over it, like the measures of a takeoff and the sums in its lines of text
  given = sheet_given(e, from)
  # While the mouse is on one value of a chart of a sheet with a row over a range, the sheet shows itself at that value
  at = sheet_case(e, [parts(b.lines[i]) for i in from+1:to-1], given)
  get!(e.flows, (:sheet, from, b.lines[from+1:to-1], caret, given, at)) do
    size = body(e).size * 0.86
    lh = size * 1.7
    ink = Face(SHEET_FONT, SHEET_WEIGHT, size, colours.ink, false)
    rows = collect(from+1:to-1)
    cells = [sheetcells(b.lines[i]) for i in rows]
    texts = [parts(b.lines[i]) for i in rows]
    # The rows are only worked out again when the text of one changes
    results = get!(() -> sheet_work(() -> tally(texts; given, at, cache=e.flows), e), e.flows, (:sheetrun, texts, given, at))
    # The cell with the caret shows the spaces typed after its text
    upto(i, c) = caret !== nothing && caret[1] == i && within(c, caret[2]) ? max(c.hi, caret[2]) : c.hi
    names = map(zip(rows, cells)) do (i, cs)
      length(cs) == 2 || return Piece[]
      text = rest(head(b.lines[i], upto(i, cs[1])), cs[1].lo)
      isempty(text) ? Piece[] : [piece(text, cs[1].lo, ink)]
    end
    name_w = clamp(maximum(ps -> sum(p -> measure(p.face, p.text), ps, init=0px), names, init=0px) + 2px, 3size, e.width * 0.4)
    # An expression has the room that its row's name and result leave it
    room = e.width - 3px - 4SHEET_X - name_w
    # While the sheet shows itself at one value, a result is narrower than the range that it shows the rest of the
    # time. The expressions wrap for the wider of the two, so the sheet keeps its height. If it got shorter, a chart
    # under it would move away from the mouse, the sheet would show the range again, and the two would shake.
    ends = at === nothing ? results : get!(() -> sheet_work(() -> tally(texts; given, at=nothing, cache=e.flows), e), e.flows, (:sheetrun, texts, given, nothing))
    exprs = map(enumerate(rows)) do (r, i)
      c = cells[r][end]
      chip = max(chip_w(ink, results[r]), chip_w(ink, ends[r]))
      wrap(exprpieces(b.lines[i], c.lo, upto(i, c), known(texts, r, given), ink), max(80px, room - chip - (chip > 0px ? SHEET_X : 0px)); lh, size)
    end
    nameflows = [wrap(ps, name_w; lh, size) for ps in names]
    heights = [max(tall(n), tall(x)) for (n, x) in zip(nameflows, exprs)]
    Sheet(rows, cells, nameflows, exprs, results, heights, name_w, size)
  end
end

tall(s::Sheet) = sum(s.heights) + 2px + 2SHEET_Y + 2SHEET_GAP

"How far the top of row `r` is from the top of the sheet's item"
row_top(s::Sheet, r::Int) = SHEET_GAP + 1px + SHEET_Y + sum(s.heights[1:r-1], init=0px)

"How far the text of an expression starts from the left of the sheet"
expr_x(s::Sheet) = 2px + 3SHEET_X + s.name_w

"The layout of cell `k` of row `r`, and how far its text starts from the left of the sheet"
cellflow(s::Sheet, r::Int, k::Int) =
  length(s.cells[r]) == 2 && k == 1 ? (s.names[r], 1px + SHEET_X) : (s.exprs[r], expr_x(s))

"Which cell of row `r` is under a point `x` from the left of the sheet"
cellunder(s::Sheet, r::Int, x::px) = length(s.cells[r]) == 2 && x < expr_x(s) - SHEET_X ? 1 : length(s.cells[r])

"The row of the sheet under a point `y` from the top of its item"
rowunder(s::Sheet, y::px) = something(findfirst(r -> y < row_top(s, r) + s.heights[r], eachindex(s.rows)), length(s.rows))

"The place in row `r` nearest to `x`, on the first line of the row's cell, or on its last when `by` is -1"
place(s::Sheet, r::Int, by::Int, x::px) = begin
  k = cellunder(s, r, x)
  f, dx = cellflow(s, r, k)
  (s.rows[r], cellcol(f, by < 0 ? length(f.lines) : 1, x - dx, s.cells[r][k]))
end

"Where the caret goes when ↑ or ↓ brings it into a sheet from the line above or below it"
enter(e, it::Item, s::Sheet, by::Int, x::px) = place(s, by > 0 ? 1 : length(s.rows), by, x)

"""
One run of text of a sheet, in a box as tall as the line with the text in the
middle of it. A name of another row is a chip with round ends.
"""
sheetseg(seg::Seg, lh::px) = begin
  f = seg.face
  t = Text(seg.text, size=f.size, family=f.family, subfamily=f.style, color=f.color, wrap=WrapMode.none)
  f.chip || return Box(fixed(seg.w), height(lh), Alignment.Center, t)
  h = f.size * 1.45
  Box(fixed(seg.w), height(lh), Alignment.Center,
    Box(fixed(seg.w), height(h), padding(CHIP_X, 0px), radius(h / 2), background(colours.chip), border(1px, :solid, colours.chip_line), t))
end

sheetlines(f::Flow) =
  [Row(width(grow=grow), height(f.lh), Alignment.Center, padding(0px, 0px, 0px, vl.x), clip=true,
       [sheetseg(seg, f.lh) for seg in vl.segs]...) for vl in f.lines]

describe(e::Editor, it::Item, s::Sheet) = begin
  b = e.buf
  lh = s.size * 1.7
  n = length(s.rows)
  bare(f) = isempty(f.lines[1].segs)
  hint(text) = Row(height(lh), Text(text, size=s.size, family=SHEET_FONT, subfamily=SHEET_WEIGHT, color=colours.faint, wrap=WrapMode.none))
  rows = map(1:n) do r
    above, below = (r == 1 ? SHEET_Y : 0px), (r == n ? SHEET_Y : 0px)
    pad = padding(above, SHEET_X, below, SHEET_X)
    # The caret is in this row's expression
    typing = b.caret[1] == b.anchor[1] == s.rows[r] && nearest(s.cells[r], b.caret[2]) == length(s.cells[r])
    res = s.results[r]
    w = chip_w(Face(SHEET_FONT, SHEET_WEIGHT, s.size, colours.ink, false), res)
    chip = isempty(res.text) ? () :
      (Column(fixed(w + SHEET_X), height(grow=grow), Alignment.Start, padding(above + 1px, SHEET_X, 0px, 0px),
         res.failed ? own!(node!(Document, e, :document), Trouble(message=res.text, size=s.size)) :
           # A value that the sheet worked out backwards, from an answer under it, has a line round it in the accent colour
           Row(fixed(w), height(lh - 2px), Alignment.Center, padding(RESULT_X, 0px), radius(6px), background(colours.chip),
               (res.solved ? (border(1px, :solid, colours.accent),) : ())...,
             # Menlo's raised signs sit lower than Source Code Pro's raised digits, so they go up a little
             [Box(padding(0px, 0px, f.family == SHEET_FONT ? 0px : s.size * RAISE, 0px),
                Text(t, size=s.size, family=f.family, subfamily=f.style, color=res.solved ? colours.accent : colours.ink, wrap=WrapMode.none))
              for (t, f) in runs(res.text, Face(SHEET_FONT, SHEET_WEIGHT, s.size, colours.ink, false))]...)),)
    Row(width(grow=grow), height(s.heights[r] + above + below), Alignment.Start,
      # A row without a name shows its number
      Column(fixed(s.name_w + 2SHEET_X + 1px), height(grow=grow), Alignment.Start, pad, border(1px, :solid, colours.line)[:right],
        (bare(s.names[r]) ? (hint(string(r)),) : sheetlines(s.names[r]))...),
      Column(width(grow=grow), height(grow=grow), Alignment.Start, pad,
        (bare(s.exprs[r]) && typing ? (hint("expression"),) : sheetlines(s.exprs[r]))...),
      chip...)
  end
  Box(width(grow=grow), padding(0px, SHEET_GAP),
    Column(width(grow=grow), Alignment.Start, radius(6px), background(colours.float), border(1px, :solid, colours.line), name="Sheet",
      rows...))
end

describe(t::Trouble) = begin
  w = measure(Face(SHEET_FONT, SHEET_WEIGHT, t.size, colours.accent, false), "!") + 2RESULT_X
  Box(fixed(w), height(t.size * 1.7 - 2px), padding(RESULT_X, 0px), radius(6px), background(colours.chip),
    Text("!", size=t.size, family=MONO, subfamily="Bold", color=colours.accent, wrap=WrapMode.none))
end

draw(ctx, size, ui::ConcreteRect, t::Trouble) = (t.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(t::Trouble, ev::MouseMove) =
  show_tooltip!(ev.window, tip_label(t.message), t.rect..., placement=:bottom, gap=6px)

"""
The boxes that cover the selected part of a sheet whose top left corner is at
(x, y). A selection that covers several lines takes each row whole.
"""
marks(e, it::Item, s::Sheet, x, y) = begin
  b = e.buf
  out = Rect[]
  selecting(b) || return out
  lo, hi = selection(b)
  if b.caret[1] != b.anchor[1]
    n = length(s.rows)
    bottom = y + it.tall - SHEET_GAP
    lo[1] <= it.first && hi[1] >= it.first && push!(out, (num(x), num(y), num(x + 7px), num(y + SHEET_GAP)))
    for (r, i) in enumerate(s.rows)
      lo[1] <= i <= hi[1] || continue
      top = r == 1 ? y + SHEET_GAP : y + row_top(s, r)
      push!(out, (num(x), num(top), num(x + item_room(e, it)[2]), num(r == n ? bottom : y + row_top(s, r + 1))))
    end
    lo[1] <= it.last && hi[1] >= it.last && push!(out, (num(x), num(bottom), num(x + 7px), num(y + it.tall)))
    return out
  end
  r = findfirst(==(b.caret[1]), s.rows)
  r === nothing && return out
  sel = selected(b, s.rows[r])
  for (k, cell) in enumerate(s.cells[r])
    (sel[1] < cell.limit && sel[2] > cell.lo) || continue
    f, dx = cellflow(s, r, k)
    append!(out, marks(f, x + dx, y + row_top(s, r), (max(sel[1], cell.lo), min(sel[2], cell.limit), false), margin=false))
  end
  out
end

"Draw the caret in the cell of a sheet that it's in. The sheet's top left corner is at (x, y)."
caret(ctx, e, s::Sheet, x, y) = begin
  p = e.buf.caret
  r = findfirst(==(p[1]), s.rows)
  r === nothing && return
  f, dx = cellflow(s, r, nearest(s.cells[r], p[2]))
  caret(ctx, e, f, x + dx, y + row_top(s, r), p[2])
end

"The place in a sheet under a point that is (dx, dy) from the top left of its item"
locate(e, it::Item, s::Sheet, dx, dy) = begin
  r = rowunder(s, dy)
  k = cellunder(s, r, dx)
  f, x = cellflow(s, r, k)
  line = clamp(floor(Int, num(dy - row_top(s, r)) / num(f.lh)) + 1, 1, length(f.lines))
  (s.rows[r], cellcol(f, line, dx - x, s.cells[r][k]))
end

"""
A click on a sheet. It returns true when it has put the caret somewhere itself.
With ⌥ held, the sheet shows as lines of code. A click where a row's name goes
gives a row that has no name a place for one.
"""
press!(e, it::Item, s::Sheet, pos) = begin
  b = e.buf
  if only_held(e, Keys.opt)
    b.caret = b.anchor = line_end(b, it.first)
    return true
  end
  r = rowunder(s, pos[2] - e.origin[2] - it.top)
  (length(s.cells[r]) == 1 && pos[1] - e.origin[1] - item_room(e, it)[1] < expr_x(s) - SHEET_X) || return false
  name_row!(e, s.rows[r])
  true
end

"Give the row on line `i`, which has no name, a place for one, and put the caret there"
name_row!(e, i::Int) = begin
  b = e.buf
  edit!(b, (i, 0), (i, 0), " = ")
  b.caret = b.anchor = (i, 0)
  e.clicked = (time(), (i, 0), 1)
  touch!(e)
end

"""
Where the caret goes when it's sent to `p` in the sheet that runs from line `s`
to line `t`. See `settle` for a table. A spreadsheet works the same way, with
`cells` to read the cells of a row.
"""
settle(b::Buffer, (s, t)::Tuple{Int,Int}, p::Pos, by::Int, cells=sheetcells) = begin
  i, col = p
  first_cell(i) = (i, cells(b.lines[i])[1].lo)
  last_cell(i) = (i, cells(b.lines[i])[end].hi)
  # The lines that open and close the sheet don't show, so the caret steps over them
  i == s && return by < 0 && s > 1 ? line_end(b, s - 1) : first_cell(s + 1)
  i == t && return by > 0 && t < length(b.lines) ? (t + 1, 0) : last_cell(t - 1)
  cs = cells(b.lines[i])
  any(c -> within(c, col), cs) && return p
  if by < 0
    c = findlast(c -> c.limit < col, cs)
    c === nothing || return (i, cs[c].hi)
    i - 1 > s ? last_cell(i - 1) : s > 1 ? line_end(b, s - 1) : first_cell(i)
  elseif by > 0
    c = findfirst(c -> c.lo > col, cs)
    c === nothing || return (i, cs[c].lo)
    i + 1 < t ? first_cell(i + 1) : t < length(b.lines) ? (t + 1, 0) : last_cell(i)
  else
    c = cs[nearest(cs, col)]
    (i, clamp(col, c.lo, c.limit))
  end
end

"The place one line up or down from the caret, which is in a sheet"
vertical(e, it::Item, s::Sheet, by::Int) = begin
  b = e.buf
  # The caret can be on the line that opens or closes the sheet, at the end of a selection
  r = something(findfirst(==(b.caret[1]), s.rows), b.caret[1] <= it.first ? 1 : length(s.rows))
  k = nearest(s.cells[r], b.caret[2])
  f, dx = cellflow(s, r, k)
  line, x = spot(f, b.caret[2])
  x = e.goal = something(e.goal, x + dx)
  1 <= line + by <= length(f.lines) && return (b.caret[1], cellcol(f, line + by, x - dx, s.cells[r][k]))
  r += by
  1 <= r <= length(s.rows) && return place(s, r, by, x)
  if by < 0
    it.first == 1 && return b.caret
    f = flow(e, it.first - 1, b.plain && !by_runs(b, it.first - 1))
    return (it.first - 1, colat(f, length(f.lines), x))
  end
  # ↓ on the last row of a sheet at the end of the document starts a line below it
  it.last == length(b.lines) && edit!(b, line_end(b, it.last), line_end(b, it.last), "\n")
  (it.last + 1, colat(flow(e, it.last + 1, b.plain && !by_runs(b, it.last + 1)), 1, x))
end

"Return in a sheet starts a row under the caret's row. In a last row that's empty, it ends the sheet instead."
next_row!(e) = begin
  b = e.buf
  i = b.caret[1]
  s, t = sheet(b, i)
  if i == t - 1 && t - s > 2 && all(isempty, parts(b.lines[i]))
    edit!(b, line_end(b, i - 1), line_end(b, t), "\n" * b.lines[t] * "\n")
    b.caret = b.anchor = (t, 0)
    return touch!(e)
  end
  edit!(b, line_end(b, i), line_end(b, i), "\n = ")
  b.caret = b.anchor = (i + 1, 0)
  touch!(e)
end

"""
Tab in a sheet goes to the next cell and selects what's in it, or with `back`
to the one before. Going on from the last cell adds a row, and going back from
an expression that has no name makes a place for one.
"""
sheet_tab!(e, back::Bool) = begin
  b = e.buf
  i, col = b.caret
  s, t = sheet(b, i)
  cs = sheetcells(b.lines[i])
  k = nearest(cs, col)
  pick(i, c) = begin
    b.anchor, b.caret = (i, c.lo), (i, c.hi)
    touch!(e)
  end
  if back
    length(cs) == 1 && return name_row!(e, i)
    k == 2 && return pick(i, cs[1])
    return i - 1 > s ? pick(i - 1, sheetcells(b.lines[i-1])[end]) : nothing
  end
  k < length(cs) && return pick(i, cs[2])
  i + 1 < t && return pick(i + 1, sheetcells(b.lines[i+1])[1])
  edit!(b, line_end(b, i), line_end(b, i), "\n = ")
  b.caret = b.anchor = (i + 1, 0)
  touch!(e)
end

"""
Backspace in a sheet, when it does more than delete a character. In a row
that's empty it takes the row away, and the last row takes the sheet with it.
At the start of an expression it goes back to the row's name. It returns true
when it did one of these.
"""
erase_row!(e, to::Pos) = begin
  b = e.buf
  i, col = b.caret
  to < b.caret || return false
  s, t = sheet(b, i)
  cs = sheetcells(b.lines[i])
  if all(isempty, parts(b.lines[i]))
    if t - s == 2
      edit!(b, (s, 0), line_end(b, t), "")
    elseif i - 1 > s
      edit!(b, line_end(b, i - 1), line_end(b, i), "")
    else
      edit!(b, (i, 0), (i + 1, 0), "")
      b.caret = b.anchor = settle(b, (i, 0), 1)
    end
    touch!(e)
    return true
  end
  (length(cs) == 2 && col == cs[2].lo && nearest(cs, col) == 2) || return false
  b.caret = b.anchor = (i, cs[1].hi)
  touch!(e)
  true
end

# --- the names a sheet offers ----------------------------------------------------------
#
# While you type a name in an expression of a sheet, a list under the caret
# shows the names of the rows above that start the same way. ↑ and ↓ choose
# one, Return or Tab types the rest of it, and esc hides the list.

isnamechar(c::Char) = isletter(c) || isdigit(c) || c == '_'

"""
The names that the text before the caret could be the start of: the line, the
column where the name starts, and the names. Nothing when the caret isn't in an
expression of a sheet, or no name fits. A name fits when it starts with what's
typed, or when one of its words does.
"""
offered(e) = begin
  b = e.buf
  i, col = b.caret
  selecting(b) && return nothing
  # The sheet of a SolidCraft design's parameters shows the design's own list of names: see cad/view.jl
  design_field_of(e) isa DesignSheet && return nothing
  # A code block offers names too, and the name of a wiki link offers pages
  insheet(b, i) || return (found = code_offered(e); found === nothing ? wiki_offered(e) : found)
  cs = sheetcells(b.lines[i])
  c = cs[end]
  (c.lo <= col <= c.limit && nearest(cs, col) == length(cs)) || return nothing
  s, _ = sheet(b, i)
  rows = [parts(b.lines[j]) for j in s+1:i-1]
  names = known(rows, length(rows) + 1, page_given(e, s, sums=true))
  isempty(names) && return nothing
  chars = collect(b.lines[i])
  # In the middle of a word, nothing is offered
  col < length(chars) && isnamechar(chars[col+1]) && return nothing
  before = map(lowercase, chars[c.lo+1:col])
  # The longest run of words before the caret that starts a name wins, so "wall l" finds "Wall length"
  for from in max(1, length(before) - 40):length(before)
    (isletter(before[from]) || before[from] == '_') || continue
    from > 1 && isnamechar(before[from-1]) && continue
    typed = String(before[from:end])
    fits(n) = lowercase(n) != typed && (startswith(lowercase(n), typed) || any(w -> startswith(w, typed), split(lowercase(n))))
    found = filter(fits, names)
    isempty(found) || return (i, c.lo + from - 1, found)
    # A whole name is typed already, so its last words aren't the start of another
    any(n -> lowercase(n) == typed, names) && return nothing
  end
  nothing
end

"Which name of the list of names is chosen, and the list that esc hid. Each is kept with the place its list is for."
@def mutable struct Suggesting
  at::Tuple{Int,Int} = (0, 0)       # the line, and the column where the name starts, of the list that `chosen` is for
  chosen::Int = 1                   # which name of that list is chosen
  hidden::Tuple{Int,Int} = (0, 0)   # the same place of the list that esc hid, or (0, 0)
end

"Which name of the list is chosen, and the list that esc hid, for the window of `e`"
suggesting(e) = state_of(e, Suggesting)

"The list of names to show now: the line, the column where the name starts, the names and which one is chosen. Or nothing."
suggestion(e) = begin
  caretless(e.buf) && return nothing
  found = offered(e)
  state = suggesting(e)
  # A list that esc hid stays hidden while its name is being typed, and no longer
  if state.hidden != (0, 0) && (found === nothing || state.hidden != (found[1], found[2]))
    state.hidden = (0, 0)
  end
  found === nothing && return nothing
  i, start, names = found
  state.hidden == (i, start) && return nothing
  (i, start, names, state.at == (i, start) ? clamp(state.chosen, 1, length(names)) : 1)
end

"What a key does while the list of names shows. It returns true when the key was for the list."
suggest_key!(e, K) = begin
  found = suggestion(e)
  found === nothing && return false
  i, start, names, chosen = found
  state = suggesting(e)
  if K == Keys.down || K == Keys.up
    state.at, state.chosen, state.hidden = (i, start), mod1(chosen + (K == Keys.down ? 1 : -1), length(names)), (0, 0)
  elseif K == Keys.enter || K == Keys.tab
    complete!(e, i, start, names[chosen])
  elseif K == Keys.escape
    state.at, state.chosen, state.hidden = (0, 0), 1, (i, start)
  else
    return false
  end
  touch!(e)
  true
end

"The folder of each page that the list of names offers for a link, by the name that the list shows, which the window keeps for the list: see `wiki_offered`"
@def mutable struct LinkNotes
  notes::Dict{String,String} = Dict{String,String}()
end

"The list of names, placed in the window under the name being typed. Nothing when there's no list to show."
suggestbox(e) = begin
  found = suggestion(e)
  found === nothing && return ()
  i, start, names, chosen = found
  it = item(e, i)
  s = it.content
  # Where the name starts, from the left of the page's text and from the top of the item, and the font of the list
  if s isa Sheet
    r = findfirst(==(i), s.rows)
    r === nothing && return ()
    f, dx = cellflow(s, r, length(s.cells[r]))
    k, x = spot(f, start)
    face = Face(SHEET_FONT, SHEET_WEIGHT, s.size, colours.ink, false)
    across, down = item_room(e, it)[1] + dx + x, row_top(s, r) + f.lh * k
  elseif s isa Flow
    # In a code block, the list is under the line of the screen that the name is on. In a wiki link too.
    k, x = spot(s, start)
    prose = kinds(e.buf)[i].kind != Kind.code
    face = prose ? body(e) : Face(codefont(), codestyle(), s.size, colours.ink, false)
    across, down = x, line_top(s, k) + s.lines[k].high
  else
    return ()
  end
  # In Julia code, each name has what it is at the right of its row, in a paler colour. A page has its folder there.
  notes = !(s isa Flow) ? fill("", length(names)) :
          prose ? [get(state_of(e, LinkNotes).notes, n, "") for n in names] : name_notes(e, i, names)
  pale = Face(face, color=colours.dim)
  span(note) = sum(((part, f),) -> measure(f, part), runs(note, pale), init=0px)
  needs(n, note) = measure(face, n) + (isempty(note) ? 0px : NOTE_GAP + span(note))
  wide = max(150px, maximum(map(needs, names, notes)) + 26px)
  list = Column(fixed(wide), Alignment.Start, padding(4px), radius(7px), background(colours.float), border(1px, :solid, colours.line), lifted,
    name="Names",
    [Row(width(grow=grow), height(face.size * 1.8), Alignment.Center, padding(8px, 0px), radius(4px),
         background(j == chosen ? colours.active : clear),
       (isempty(note) ? (Text(n, size=face.size, family=face.family, subfamily=face.style, color=colours.ink, wrap=WrapMode.none),) :
        (Box(Text(n, size=face.size, family=face.family, subfamily=face.style, color=colours.ink, wrap=WrapMode.none)),
         Box(width(grow=grow), height(1px)), spared(note, pale)...))...)
     for (j, (n, note)) in enumerate(zip(names, notes))]...)
  # A list that's too wide for the room at its right stays in the window
  left = clamp(text_left(e) + across - 9px, 8px, max(8px, window_size(e)[1] - 8px - wide))
  top = above_page(e) + PAGE_TOP + it.top - e.scroll.offset + down + 3px
  top >= above_page(e) || return ()
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), list),)
end

BLOCKS[SHEET] = SheetBlock
block_name(::Type{SheetBlock}) = "Sheet"
block_icon(::Type{SheetBlock}) = "calculator"
block_insert(::Type{SheetBlock}) = ("Sheet", ["```$SHEET", " = ", "```"], (2, 0))
block_is_whole(::Type{SheetBlock}, ::AbstractString) = false
block_outline_inside(::Type{SheetBlock}) = true
block_table_kind(::Type{SheetBlock}) = "sheet"
block_html(::Type{SheetBlock}, e, lang::AbstractString, s::Int, t::Int) = sheet_html(e, s, t)
block_layout(::Type{SheetBlock}, e, lang::AbstractString, i::Int, n::Int) =
  (run = drawn(e.buf, i, SHEET); run === nothing ? nothing : (run[2], sheetgrid(e, run...)))
block_tables!(::Type{SheetBlock}, e, i::Int, t::Int, under::AbstractString, out) = begin
  b = e.buf
  texts = [parts(b.lines[r]) for r in i+1:t-1]
  given = sheet_given(e, i)
  # A sheet with a row over a range is a table with a row for each value of that row
  over = get!(() -> sheet_work(() -> cases(texts; given, cache=e.flows), e), e.flows, (:cases, texts, given))
  if over !== nothing
    push!(out, (first=i, last=t, under=under, rows=over.table, headed=true, ranged=true))
    return
  end
  results = get!(() -> sheet_work(() -> tally(texts; given, cache=e.flows), e), e.flows, (:sheetrun, texts, given, nothing))
  rows = [String[strip(name), results[r].failed ? "" : results[r].text] for (r, (name, _)) in enumerate(texts)]
  push!(out, (first=i, last=t, under=under, rows=rows, headed=false, ranged=false))
end
block_names(::Type{SheetBlock}, lines) = Tuple{String,String}[row for row in parts.(lines) if !isempty(ident(row[1]))]
