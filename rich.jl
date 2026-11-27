# Rich text and plain text, and tables. Rich text shows a line as it reads, and
# plain text shows its symbols. This is where a line's pieces become a Flow and
# a table becomes a Grid.
#
#     flow(e, i)                   # line `i` of the page, laid out
#     grid(e, from, to)            # the table on lines `from` to `to`, laid out

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "./pictures" natural
@use "./html" NOTE
@use "./markdown" Kind Line Span Cell spans tablecells isdivider MATTER TOML_MATTER MATH only_id
@use "./markdown" COMMENT
@use "./sheet" sheetcells parts shown
@use "./spreadsheet" spreadcells
@use "./math" => Maths
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...

export spread, sheet, spare_flows!, maths_line, has_maths, column_fold, column_at, column_flow, block_source,
       transcludes, html_block, block_is_whole, file_line, TEXT_KINDS, rich, alone, pictured, israw, by_runs,
       raw_part, marked_runs, closes_run, runs_at, richspans, unseen, wholes, first_stop, solid, free, part,
       comment_only, comment_fold, picked, step_over, settle_rich, stand!, markpairs, cutmask, richcut,
       halves!, flow, laid, restyle!, table, tablerows, rowcells, within, cellat, nearest, settle,
       settle_cells, row_edge, cellpieces, celltexts, tableline, aligns, align, share_widths, grid, TABLE_GAP,
       cell_origin, cellcol, gridcell, unbroken, spare, PICTURE_LINE, incode, end_room

# The kinds of block decide these, so this file only names them.

"The run of rows of the spreadsheet that line `i` of `b` is in"
function spread end

"The run of rows of the sheet that line `i` of `b` is in"
function sheet end

"Forget the laid-out lines of the editor `e` when it keeps too many"
function spare_flows! end

"True when line `i` of `b` holds only a formula between \$\$ and \$\$"
function maths_line end

"True when `tex` is a formula that can be set"
function has_maths end

"The columns that line `i` of `b` starts, when the page puts blocks side by side, or nothing"
function column_fold end

"The column that line `i` of the page shows in, or nothing"
function column_at end

"Line `i` of the page, in the column `c`, laid out for the column's width"
function column_flow end

"Where the function of a block comes from, or nothing when no file defines its language"
function block_source end

"True when line `i` of `b` holds only a link that shows a part of another page"
function transcludes end

"The first and the last line of the HTML that line `i` of `b` is in, or nothing"
function html_block end

"True when the closed block of the language `lang`, on lines `s` to `t` of `b`, is stepped over as a whole by the caret"
function block_is_whole end

"Lay out `text`, line `i` of a file that shows as text in the editor `e`"
function file_line end

# --- rich text and plain text ----------------------------------------------------------------
#
# A page is written in one of two ways. A click on the snake or the ladder in the
# top bar changes from one to the other, and so does ⌘E. You can change the text in both.
# The two are levels of abstraction. Plain text is the low level: the page's
# symbols. Rich text is the high level: the graphics that the symbols make.
#
# As rich text, a line shows the way it reads: bold words are bold, and the
# characters that make them bold don't show. A diagram shows as a diagram. A
# line stays that way when the caret comes onto it, so the caret has rules:
#
#   - It can't stop among characters that don't show, like the ** of bold
#     text or the # of a heading. A key that moves it goes over them.
#   - It stays on the side of them that it came from. After **bold**, a caret
#     that came from the left is in the bold text, and what's typed there is
#     bold. A caret that came from the right is after the bold text.
#   - It doesn't go into a part of the page that shows as one thing: a
#     diagram, a form, a picture, a line across the page. It goes onto the
#     part as a whole, and a line goes round the part. Return then gives the
#     part the keyboard, so you can type in a field of a form. ⌫ takes the
#     part away. ↑ and ↓ go on to the line before it and the line after it.
#   - It steps over the ``` lines of a code block, which don't show.
#
# Only a part that's being typed shows its markup: the caret is on it because
# its text was typed there, and it stays as text until the caret leaves.
# Without that, a line like ```mermaid could never be typed.
#
# As plain text, the part of the page nearest the caret shows its markup. In a
# line of text, that's the run that the caret is in: bold words, a link, inline
# code, a formula. With the caret in plain words, no run shows its markup. With
# the caret in what starts the line, like the # of a heading, that shows. The
# rest of the line still reads as rich text, so a long paragraph keeps its look
# while it's changed. The same goes for the cell of a table. A line that shows
# as one thing, like a picture, shows all its markup, and so does the whole of a
# code block or a diagram. The caret goes anywhere: the run that it goes into
# shows its markup, so it never stops among characters that don't show. Every
# other part of the page still shows as rich text.

"The kinds of line whose text shows without its markup in rich text"
const TEXT_KINDS = (Kind.paragraph, Kind.heading, Kind.bullet, Kind.ordered, Kind.todo, Kind.blockquote)

"True when the page is written as rich text: it's a document, and the part with the caret doesn't show its markup"
rich(b::Buffer) = !b.plain && b.view == :markdown

"True when the caret is on line `i`, and the selection doesn't reach another line"
alone(b::Buffer, i::Int) = !caretless(b) && i == b.caret[1] == b.anchor[1]

"True when line `i` holds only a picture, a sound or a video"
pictured(b::Buffer, i::Int) = kinds(b)[i].kind == Kind.paragraph && occursin("![", b.lines[i]) && occursin(PICTURE_LINE, b.lines[i])

"""
True when all of line `i` shows its markup. It has to have the caret. As plain
text that's enough, unless it's a line of text, which shows the markup of one
run at a time: see `raw_part`. As rich text, the line also has to be one that
shows as something other than its text, which is only so while it's typed: a
``` line, a line across the page, a picture, a table's line of dashes.
"""
israw(b::Buffer, i::Int) =
  alone(b, i) && (!rich(b) ? !by_runs(b, i) : (picked(b) === nothing && (kinds(b)[i].kind in (Kind.fence, Kind.rule, Kind.table) || pictured(b, i) || maths_line(b, i) || transcludes(b, i) || only_id(b.lines[i]) ||
                                                                          html_block(b, i) !== nothing)))

"""
True when line `i`, as plain text, shows its markup a run at a time, and not
all at once: a line of text, but not one that shows as one thing, like a
picture or a formula on a line of its own.
"""
by_runs(b::Buffer, i::Int) =
  b.view == :markdown && kinds(b)[i].kind in TEXT_KINDS && !(pictured(b, i) || maths_line(b, i) || transcludes(b, i) || only_id(b.lines[i]) || html_block(b, i) !== nothing)

"""
The columns of line `i` that show their markup as plain text, as a list of the
first and last column of each run, or nothing when none do. They're the run
that the caret is in, like bold words, a link or inline code, or what starts
the line when the caret is in that, like the # of a heading. The rest of the
line reads as rich text. With a selection, the run at its other end shows its
markup too, so that neither end moves. It's always nothing as rich text, and
for a line that shows all its markup: see `israw`.
"""
raw_part(b::Buffer, i::Int) = begin
  (alone(b, i) && !rich(b) && b.view == :markdown) || return nothing
  if kinds(b)[i].kind == Kind.table
    # A row of a table that's drawn as a grid shows the run that the caret is in, inside its cell
    run = table(b, i)
    (run !== nothing && i != run[1] + 1) || return nothing
  else
    by_runs(b, i) || return nothing
  end
  lead, runs = marked_runs(b, i)
  out = Tuple{Int,Int}[]
  for col in (b.anchor[2], b.caret[2])
    # What starts the line shows while the caret is in it. At its end the caret is at the start of the text, which shows anyway.
    found = col < lead ? [(0, lead)] : runs_at(runs, col)
    foreach(r -> r in out || push!(out, r), found)
  end
  isempty(out) ? nothing : out
end

"""
The runs of line `i` that show their markup as one, each as the column where
its markup starts and the column where it ends: bold words, a link, inline
code, a formula, the number of a footnote, a comment, and markup that's alone,
like the \\ before a *. A run inside another comes before it. Before them, the
column where the line's text starts after what starts the line, like the # of
a heading, or 0 when nothing that starts the line is hidden in rich text.
"""
marked_runs(b::Buffer, i::Int) = begin
  start, ss = richspans(b, i)
  line = kinds(b)[i]
  lead = line.kind == Kind.paragraph && start == line.prefix ? 0 : start
  out = Tuple{Int,Int}[]
  opened = Int[]
  for (k, s) in enumerate(ss)
    s.markup || continue
    if !isempty(opened) && closes_run(ss[last(opened)].text, s.text)
      push!(out, (ss[pop!(opened)].col, s.col + length(s.text)))
    elseif s.text == "\\" || occursin(r"^\s*\^", s.text)
      # The \ before a character, and the name of a block at the end of its line, are runs by themselves
      push!(out, (s.col, s.col + length(s.text)))
    else
      push!(opened, k)
    end
  end
  # Markup that's never closed is a run by itself
  foreach(k -> push!(out, (ss[k].col, ss[k].col + length(ss[k].text))), opened)
  (lead, out)
end

"True when the markup `c` closes a run that the markup `o` opened, as `spans` reads them"
closes_run(o::AbstractString, c::AbstractString) =
  o == "[" ? startswith(c, "](") : o == "[^" ? c == "]" : o == "!`" ? c == "`" : startswith(o, "[[") ? endswith(c, "]]") :
  o == "{==" ? c == "==}" : o == "{>>" ? c == "<<}" : o == c

"""
The runs among `runs` that show their markup while the caret is at `col`: the
innermost one that it's inside, or each one that it's at an edge of. At an
edge, the run's markup shows which side of it the caret is on.
"""
runs_at(runs, col::Int) = begin
  inside = filter(r -> r[1] < col < r[2], runs)
  isempty(inside) ? filter(r -> r[1] == col || r[2] == col, runs) : [argmin(r -> r[2] - r[1], inside)]
end

"""
The spans of line `i` as rich text reads them: the text after what starts the
line, or the text of each cell of a row of a table. `start` is the column
where that text starts.
"""
richspans(b::Buffer, i::Int) = begin
  text, line = b.lines[i], kinds(b)[i]
  if line.kind in TEXT_KINDS
    note = line.kind == Kind.paragraph ? match(NOTE, text) : nothing
    start = note === nothing ? line.prefix : length(note.match)
    return (start, spans(rest(text, start), start))
  end
  out = Span[]
  line.kind == Kind.table && table(b, i) !== nothing || return (0, out)
  for c in tablecells(text)
    append!(out, spans(rest(head(text, c.hi), c.lo), c.lo))
  end
  (0, out)
end

"""
The parts of line `i` that take no room in rich text, each as the column it
starts at and the column it ends at: markup like **, and what starts a heading,
a list item or a quote. Two that touch are one. The caret can't stop inside
one. The part that starts a line starts at -1, so that column 0 is inside it.
"""
unseen(b::Buffer, i::Int) = begin
  start, ss = richspans(b, i)
  out = Tuple{Int,Int}[]
  kinds(b)[i].kind == Kind.paragraph && start == kinds(b)[i].prefix || start == 0 || push!(out, (-1, start))
  for s in ss
    # A comment, like %%note%%, takes no room either
    (s.markup || s.comment) || continue
    a, z = s.col, s.col + length(s.text)
    !isempty(out) && last(out)[2] == a ? (out[end] = (last(out)[1], z)) : push!(out, (a, z))
  end
  out
end

"The parts of line `i` that each show as one thing in rich text: the name of a footnote, inline code that runs, and a formula"
wholes(b::Buffer, i::Int) =
  Tuple{Int,Int}[(s.col, s.col + length(s.text)) for s in richspans(b, i)[2]
                 if !s.markup && (s.live || (s.math && Maths.available()) || startswith(s.link, '^')) && length(s.text) > 1]

"The first column of line `i` where the caret can stop in rich text: where the text of a heading or a list item starts"
first_stop(b::Buffer, i::Int) = begin
  rich(b) || return 0
  hidden = unseen(b, i)
  isempty(hidden) || first(hidden)[1] >= 0 ? 0 : first(hidden)[2]
end

"""
The first and last line of the part of the page that line `i` is in, when the
caret steps over that part in rich text. That's a part that shows as one
thing: a block that shows as a diagram, a plan, a chart and so on, the front
matter, a formula on lines of its own, a picture, a line across the page, a
table's line of dashes. A ``` line is such a part by itself. Nothing for a
line of text or of code.
"""
solid(b::Buffer, i::Int) = begin
  # A `columns` block that takes no room is such a part, with the empty lines after it that take none
  fold = column_fold(b, i)
  fold === nothing || return fold
  # So is a comment on lines of its own, with the empty lines after it that take no room
  fold = comment_fold(b, i)
  fold === nothing || return fold
  # So are lines of HTML
  tags = html_block(b, i)
  tags === nothing || return tags
  ks = kinds(b)
  k = ks[i]
  if k.kind in (Kind.fence, Kind.code)
    s, t = codeblock(b, i)
    lang = ks[s].lang
    closed = t > s && ks[s].kind == Kind.fence && ks[t].kind == Kind.fence && ks[t].level == 1
    whole = closed && (lang in (MATTER, TOML_MATTER) || block_is_whole(b, lang, s, t) ||
                       (lang == MATH && has_maths(join(b.lines[s+1:t-1], "\n"))) || block_source(b, s) !== nothing)
    return whole ? (s, t) : k.kind == Kind.fence ? (i, i) : nothing
  end
  (k.kind == Kind.rule || pictured(b, i) || maths_line(b, i) || transcludes(b, i)) && return (i, i)
  if k.kind == Kind.table
    run = table(b, i)
    run !== nothing && i == run[1] + 1 && return (i, i)
  end
  nothing
end

"""
True when the caret can go to line `i` from line `from`. It can't go into a
part that shows as one thing, but it can move about in one that it's already
in, which shows as text because it's being typed. A ``` line only has the
caret while it's typed.
"""
free(b::Buffer, i::Int, from::Int) = begin
  run = solid(b, i)
  run === nothing && return true
  kinds(b)[i].kind == Kind.fence ? from == i : run[1] <= from <= run[2]
end

"""
The first and last line of the part of the page that line `i` is in, when the
caret can be on that part as a whole: a block that shows as a diagram, a form,
a plan and so on, the front matter, a picture, a line across the page. Nothing
for any other line. A ``` line of a code block isn't such a part, and nor is
a table's line of dashes: neither shows, so the caret steps over them.
"""
part(b::Buffer, i::Int) = begin
  run = solid(b, i)
  run === nothing && return nothing
  k = kinds(b)[i].kind
  # A `columns` block that takes no room doesn't show either, and nor does a comment on lines of its own
  k == Kind.table || (k == Kind.fence && run[1] == run[2]) || column_fold(b, i) !== nothing || comment_fold(b, i) !== nothing ? nothing : run
end

"True when `text`, a line of text, holds only a comment, like %%note%%"
comment_only(text::AbstractString) =
  occursin("%%", text) && (ss = spans(strip(text)); !isempty(ss) && all(s -> s.comment || (s.markup && s.text == "%%"), ss))

"""
The lines of a comment, when line `i` is one of them: the first and the last.
That's a comment on lines of its own, or a line that holds only a comment.
Nothing for any other line. The empty lines after it are part of it too, as
many as there are empty lines before it, so the room that's left where it
was is the room between two blocks of the page. As rich text, none of them
take room, and the caret steps over them. See `column_fold`, which does the
same for a `columns` block.
"""
comment_fold(b::Buffer, i::Int) = begin
  b.view == :markdown || return nothing
  ks = kinds(b)
  lone(k) = ks[k].kind == Kind.paragraph && comment_only(b.lines[k])
  j = i
  if ks[i].kind == Kind.blank
    # An empty line is one of them when the comment is the first thing over it
    while j > 1 && ks[j].kind == Kind.blank
      j -= 1
    end
    ((ks[j].kind == Kind.fence && ks[j].level == 1 && ks[j].lang == COMMENT) || lone(j)) || return nothing
  elseif !(ks[i].kind in (Kind.fence, Kind.code) && ks[i].lang == COMMENT) && !lone(i)
    return nothing
  end
  s, t = ks[j].kind == Kind.paragraph ? (j, j) : codeblock(b, j)
  bare(k) = 1 <= k <= length(ks) && ks[k].kind == Kind.blank
  n = 0
  while bare(s - n - 1) && bare(t + n + 1)
    n += 1
  end
  i <= t + n ? (s, t + n) : nothing
end

"""
The first and last line of the part of the page that the caret is on as a
whole, or nothing when it's in text. The caret is on a part when it's at the
very start of the part's first line, in rich text, with nothing selected. The
part then shows as what it makes, with a line round it, and not as its code.
"""
picked(b::Buffer) = begin
  key = (b.version, b.caret, b.anchor, b.plain, b.reading)
  key == b.picked_for && return b.picked
  i, col = b.caret
  run = rich(b) && col == 0 && alone(b, i) && i <= length(b.lines) ? part(b, i) : nothing
  b.picked_for = key
  b.picked = run !== nothing && run[1] == i ? run : nothing
end

"""
The first line after `i`, or with `by` of -1 before it, that the caret can go
to from line `from`: a line of text, or a line of a part that the caret can be
on as a whole. It's 0, or a line past the last, when there's none.
"""
step_over(b::Buffer, i::Int, by::Int, from::Int) = begin
  while 1 <= i <= length(b.lines) && !free(b, i, from) && part(b, i) === nothing
    s, t = solid(b, i)
    i = by > 0 ? t + 1 : s - 1
  end
  i
end

"Where the caret goes in rich text when it's sent to `p` from `from`, going in the direction `by`: the nearest place where it can stop, or the start of a part that it goes onto as a whole"
settle_rich(b::Buffer, p::Pos, by::Int, from::Pos) = begin
  i, col = p
  if !free(b, i, from[1])
    found = false
    for d in (by < 0 ? (-1, 1) : (1, -1))
      j = step_over(b, i, d, from[1])
      1 <= j <= length(b.lines) || continue
      # The caret goes onto a part like a diagram as a whole: to the start of its first line
      free(b, j, from[1]) || return (part(b, j)[1], 0)
      i, col, by, found = j, d > 0 ? 0 : length(b.lines[j]), d, true
      break
    end
    found || return p   # the page has nothing but lines that don't show
  end
  for (a, z) in Iterators.flatten((unseen(b, i), wholes(b, i)))
    a < col < z || continue
    col = a < 0 || by > 0 ? z : by < 0 ? a : col - a < z - col ? a : z
  end
  (i, col)
end

"""
Look at where the caret is, before the page is laid out. As rich text, a caret
that something put among characters that don't show goes to the nearest place
where it can stop. In a file that was just opened, and after a change from
plain text to rich text, a caret that's in a part of the page that shows as
one thing goes onto the part as a whole. At any other time it stays in such a
part, which then shows as text: a key or a click can't take it there, so
something meant to. A click with ⌥ held does, and so does the menu that
inserts a block.
"""
stand!(b::Buffer) = begin
  b.caret == b.stood && return b
  # The caret is on no line while the page is drawn for paper, so it has nowhere to stand
  b.caret[1] < 1 && return b
  if rich(b) && !selecting(b) && isempty(b.others)
    b.caret = b.anchor = b.stood === nothing ? settle(b, b.caret, 1, from=(0, 0)) :
                                               settle(b, b.caret, cmp(b.caret, b.stood), from=b.caret)
  end
  b.stood = b.caret
  b
end

"""
The pairs of markup in `ss`, the spans of a line: for each, the place in `ss` of
the span that opens it and of the one that closes it, like the two ** of bold
text. A pair that's inside another comes before it.
"""
markpairs(ss) = begin
  out = Tuple{Int,Int}[]
  open = Int[]
  for (k, s) in enumerate(ss)
    (s.markup && s.text != "\\") || continue
    o = isempty(open) ? "" : ss[last(open)].text
    closes = !isempty(o) && (o == "[" ? startswith(s.text, "](") : o == "[^" ? s.text == "]" : o == "!`" ? s.text == "`" : o == s.text)
    closes ? push!(out, (pop!(open), k)) : push!(open, k)
  end
  out
end

"""
Which characters of line `i` go when the columns `x` to `y` of it are deleted
as rich text: true for each one that goes. The text between goes. Markup
stays if it still has text to mark, so bold text that loses its last words
is still bold, and it goes with the last of its text. With `lead`, what starts
the line goes too: that's for a line that's joined to the one before it.
"""
cutmask(b::Buffer, i::Int, x::Int, y::Int; lead=false) = begin
  text, line = b.lines[i], kinds(b)[i]
  n = length(text)
  gone = falses(n)
  if !(line.kind in TEXT_KINDS || (line.kind == Kind.table && table(b, i) !== nothing))
    gone[x+1:y] .= true
    return gone
  end
  start, ss = richspans(b, i)
  mark = falses(n)
  lead && (gone[1:min(start, y)] .= true)
  # Text that no span holds, like the | between two cells, goes as it would in plain text
  held = falses(n)
  for s in ss
    held[s.col+1:s.col+length(s.text)] .= true
    s.markup ? (mark[s.col+1:s.col+length(s.text)] .= true) : (gone[max(s.col, x)+1:min(s.col + length(s.text), y)] .= true)
  end
  for c in max(x, start)+1:y
    held[c] || (gone[c] = true)
  end
  # The \ before a character goes with the character
  for s in ss
    s.markup && s.text == "\\" && s.col + 2 <= n && gone[s.col+2] && (gone[s.col+1] = true)
  end
  for (o, c) in markpairs(ss)
    from, to = ss[o].col + length(ss[o].text), ss[c].col
    all(k -> mark[k] || gone[k], from+1:to) || continue
    any(k -> gone[k], from+1:to) || continue   # nothing between them was deleted, so they stay
    gone[ss[o].col+1:from] .= true
    gone[to+1:to+length(ss[c].text)] .= true
  end
  gone
end

"""
What to change to delete the text from `lo` to `hi` as rich text: the place
where the change starts, the place where it ends, and the markup between them
that stays. The change can reach past `lo` and `hi`, to take the markup of
text that's all deleted. `typed` is true when something is typed in its place.
"""
richcut(b::Buffer, lo::Pos, hi::Pos; typed=false) = begin
  kept(i, gone, x, y) = String([c for (k, c) in enumerate(b.lines[i]) if x < k <= y && !gone[k]])
  reach(gone, x, y) = (min(x, something(findfirst(gone), x + 1) - 1), max(y, something(findlast(gone), y)))
  if lo[1] == hi[1]
    gone = cutmask(b, lo[1], lo[2], hi[2])
    x, y = reach(gone, lo[2], hi[2])
    return ((lo[1], x), (hi[1], y), kept(lo[1], gone, x, y))
  end
  # A selection that takes all the text of its first line takes what starts that line too, like the # of a
  # heading. The last line then keeps what starts it, unless its text all goes. Any other selection joins
  # what's left of the last line to the first, without what starts the last. So does one that's typed over:
  # what's typed is in the first line, with what starts it.
  whole = !typed && lo[2] <= first_stop(b, lo[1])
  top = whole ? trues(length(b.lines[lo[1]])) : cutmask(b, lo[1], lo[2], length(b.lines[lo[1]]))
  bottom = cutmask(b, hi[1], 0, hi[2], lead=!whole || hi[2] >= length(b.lines[hi[1]]))
  x = whole ? 0 : reach(top, lo[2], lo[2])[1]
  _, y = reach(bottom, hi[2], hi[2])
  ((lo[1], x), (hi[1], y), kept(lo[1], top, x, length(b.lines[lo[1]])) * kept(hi[1], bottom, 0, y))
end

"""
What Return adds in rich text to keep the look of each half of the text that
the caret is in: the markup that closes what's open at the caret, to end the
first line, and the markup that opens it again, to start the next. A caret
at the very start or end of bold text goes outside it first, so neither line
gets bold text with nothing in it.
"""
halves!(b::Buffer) = begin
  i, col = b.caret
  (rich(b) && !selecting(b) && kinds(b)[i].kind in TEXT_KINDS) || return ("", "")
  _, ss = richspans(b, i)
  found = markpairs(ss)
  inside((o, c)) = (ss[o].col + length(ss[o].text), ss[c].col)
  moved = true
  while moved
    moved = false
    for p in found
      from, to = inside(p)
      col == to && to > from && (col = to + length(ss[p[2]].text); moved = true)
      col == from && to > from && (col = ss[p[1]].col; moved = true)
    end
  end
  b.caret = b.anchor = (i, col)
  around = [p for p in found if inside(p)[1] < col < inside(p)[2]]
  (join(ss[c].text for (_, c) in around), join(ss[o].text for (o, _) in reverse(around)))
end

"Lay out line `i` of the document"
flow(e, i::Int, raw::Bool=israw(e.buf, i)) = begin
  # A line in a column of the page is laid out for the column's width. See "blocks of the page side by side".
  column = column_at(e, i)
  column === nothing || return column_flow(e, column, i, raw)
  text, line = e.buf.lines[i], kinds(e.buf)[i]
  if e.buf.view == :code
    # A line of a file of code is laid out as a line of a file that's only shown is. Inside a docstring its colours differ.
    spare_flows!(e)
    return get!(() -> file_line(e, text, line, i), e.flows, (:file, text, line, string_opens(e.buf)[i]))
  end
  # The lines that open and close a code block show while the caret is in the block. As rich text, one only shows while it's typed.
  # A comment's first and last lines have its words, so they show with the rest of it
  line.kind == Kind.fence && (raw = rich(e.buf) && line.lang != COMMENT ? israw(e.buf, i) : incode(e.buf, i))
  # As plain text, a line of text shows the markup of the run that the caret is in, and the rest of it reads as rich text
  open = raw ? nothing : raw_part(e.buf, i)
  build() = laid(e, text, line, raw, i; open)
  # The last line of a field that has a button at its end leaves room for the button. It's laid out afresh each time.
  i == length(e.buf.lines) && (room = end_room(e)) > 0px && return laid(e, text, line, raw, i; open, tail=room)
  # What inline code made can change its size, so its line is laid out again each time
  !raw && occursin(INLINE, text) && !(line.kind in (Kind.code, Kind.fence, Kind.rule)) && return build()
  spare_flows!(e)
  # A footnote's number comes from the rest of the document, which `notes` reads once for each
  # version of it. So the line is kept for that version, and laid out again after a change.
  !raw && occursin("[^", text) && return get!(build, e.flows, (text, line, raw, open, :notes, e.buf.path, e.buf.version))
  # On another day than today, the box of a to-do item shows the tick of that day, so the line is kept with it
  then = line.kind == Kind.todo && !raw ? ticked_then(e, i) : nothing
  then === nothing || return get!(build, e.flows, (text, line, raw, open, :then, then))
  # A line of code inside a docstring has other colours than the same line outside it
  line.kind == Kind.code && return get!(build, e.flows, (text, line, raw, string_opens(e.buf)[i]))
  get!(build, e.flows, (text, line, raw, open))
end

"""
How much room the last line of the text of `e` leaves free at its right end,
for a button that lies over the end of the words there, like the model's
button in the field of an agent's pane. Usually none.
"""
end_room(e) = get(e.nodes, :end_room, 0px)::px

"""
Lay out `text`, line `i` of the document, which is a line of the kind `line`,
for a page that's `wide`. `open` is what `raw_part` gives for the line. Its
last line on the screen leaves `tail` free at its right end: see `wrap`.
"""
laid(e, text, line::Line, raw::Bool, i::Int, wide=e.width; open=nothing, tail=0px) = begin
  base = face(e, line)
  ps = spare(pieces(e, text, line, raw, i; open))
  k = line.kind
  # A hidden ``` line leaves a little room at the top or bottom of its block, and so does a line that only names the block over it
  lh = k == Kind.heading ? base.size * 1.35 : body(e).size * ((k == Kind.fence || (k == Kind.paragraph && only_id(text))) && !raw ? 0.6 : 1.65)
  # Lines of bigger code are further apart. The lines of a comment are laid out as text.
  code = k in (Kind.code, Kind.fence) && line.lang != COMMENT
  code && (lh *= e.code_scale / CODE_SCALE)
  left = code ? BLOCK_X : k == Kind.blockquote ? QUOTE_X : 0px
  # Lines that a list item wraps onto start under its text, not under its bullet
  hang = k in (Kind.bullet, Kind.ordered, Kind.todo) ? sum(p -> measure(p.face, p.text), ps[1:min(end, line.level > 0 ? 2 : 1)], init=0px) : left
  above = k == Kind.heading ? lh * 0.3 : 0px
  below = k == Kind.heading ? lh * 0.12 : 0px
  f = wrap(ps, wide; lh, size=base.size, left, hang, above, below, kind=k, raw, tail)
  # A blog's site has its first heading in the middle of the page
  k == Kind.heading && line.level == 1 && e.look == :site ? align(f, wide, :center) : f
end

"Forget every layout, after something that changes how all the text is drawn"
restyle!(e) = (empty!(e.flows); e.reveal = true; e)

# --- tables ----------------------------------------------------------------------------
#
# A table is a line of cells, a line of dashes, then more lines of cells. It's
# drawn as a grid, and the caret moves from cell to cell. The line of dashes
# isn't drawn. If the caret gets onto it, the table shows as plain lines.

"The first and last line of the table that line `i` is part of, or nothing"
table(b::Buffer, i::Int) = begin
  ks = kinds(b)
  ks[i].kind == Kind.table || return nothing
  s = t = i
  while s > 1 && ks[s-1].kind == Kind.table; s -= 1 end
  while t < length(ks) && ks[t+1].kind == Kind.table; t += 1 end
  t > s && isdivider(b.lines[s+1]) ? (s, t) : nothing
end

"The lines of a table that are rows of cells"
tablerows((s, t)) = [s; s+2:t]

"The cells of the row that `p` is in, when that row is drawn in a grid or a sheet"
rowcells(b::Buffer, p::Pos) = begin
  insheet(b, p[1]) && return sheetcells(b.lines[p[1]])
  inspread(b, p[1]) && return spreadcells(b.lines[p[1]])
  run = table(b, p[1])
  (run === nothing || p[1] == run[1] + 1) ? Cell[] : tablecells(b.lines[p[1]])
end

within(c::Cell, col::Int) = c.lo <= col <= c.limit

"The cell that `p` is in, or nothing"
cellat(b::Buffer, p::Pos) = begin
  cs = rowcells(b, p)
  i = findfirst(c -> within(c, p[2]), cs)
  i === nothing ? nothing : cs[i]
end

"Which of `cs` column `col` is in, or is nearest to"
nearest(cs, col::Int) = argmin(i -> within(cs[i], col) ? 0 : min(abs(col - cs[i].lo), abs(col - cs[i].limit)), eachindex(cs))

"""
Where the caret goes when it's sent to `p`. In a table that's the same place
if `p` is in a cell. Otherwise it's the next cell in the direction `by`, or the
nearest cell when `by` is 0.
"""
settle(b::Buffer, p::Pos, by::Int=0; from::Pos=b.caret) = begin
  rich(b) || return settle_cells(b, p, by)
  # A caret that's on a part as a whole isn't in the part's text, so it can't move about in that text
  from == b.caret && picked(b) !== nothing && (from = (0, 0))
  # As rich text the caret also keeps off what doesn't show. A place that one rule gives can break the other, so both look again.
  for _ in 1:4
    q = settle_rich(b, settle_cells(b, p, by), by, from)
    q == p && break
    p = q
  end
  p
end

"Where the caret goes when it's sent to `p`, by the rules of a table, a sheet and a spreadsheet"
settle_cells(b::Buffer, p::Pos, by::Int=0) = begin
  run = sheet(b, p[1])
  run === nothing || return settle(b, run, p, by)
  run = spread(b, p[1])
  run === nothing || return settle(b, run, p, by, spreadcells)
  run = table(b, p[1])
  run === nothing && return p
  s, t = run
  i, col = p
  if i == s + 1
    # The line of dashes. Step over it, unless that's where a click put the caret.
    by == 0 && return p
    j = by < 0 ? s : s + 2
    return j > t ? (t < length(b.lines) ? (t + 1, 0) : p) : settle_cells(b, (j, col))
  end
  cs = tablecells(b.lines[i])
  (isempty(cs) || any(c -> within(c, col), cs)) && return p
  rows = tablerows(run)
  r = findfirst(==(i), rows)
  if by < 0
    c = findlast(c -> c.limit < col, cs)
    c === nothing || return (i, cs[c].hi)
    r > 1 && return row_edge(b, rows[r-1], 1)
    s > 1 ? line_end(b, s - 1) : (i, cs[1].lo)
  elseif by > 0
    c = findfirst(c -> c.lo > col, cs)
    c === nothing || return (i, cs[c].lo)
    r < length(rows) && return row_edge(b, rows[r+1], -1)
    t < length(b.lines) ? (t + 1, 0) : (i, cs[end].hi)
  else
    c = cs[nearest(cs, col)]
    (i, clamp(col, c.lo, c.limit))
  end
end

"The start of the first cell of row `i`, or with `by` of 1 the end of its last cell"
row_edge(b::Buffer, i::Int, by::Int) = begin
  cs = tablecells(b.lines[i])
  isempty(cs) ? (i, 0) : by < 0 ? (i, cs[1].lo) : (i, cs[end].hi)
end

"""
The runs of text in a cell that shows columns `lo` to `hi` of `text`. With
`raw`, the markup shows. With `open`, only the runs in those columns show it:
see `raw_part`.
"""
cellpieces(e, i::Int, text::String, lo::Int, hi::Int, base::Face, raw::Bool; open=nothing) = begin
  out = Piece[]
  for s in spans(rest(head(text, hi), lo), lo)
    shown = raw || markup_shows(open, s.col, s.col + length(s.text))
    (s.markup || s.comment) && !shown && continue
    s.math && !shown && Maths.available() ? push!(out, equation(e, s, base)) :
    s.live && !shown && runs_sums(e) ? push!(out, inline(e, i, s, base)) : symbols!(out, s.text, s.col, face(base, s), s.link)
  end
  out
end

"How wide a piece is before it's wrapped"
wide(p::Piece) = p.node === nothing ? measure(p.face, p.text) : p.node.w

"The text of each cell of a row of a table, without the spaces around it"
celltexts(line::AbstractString) = begin
  chars = collect(strip(line))
  !isempty(chars) && chars[1] == '|' && popfirst!(chars)
  !isempty(chars) && chars[end] == '|' && (length(chars) < 2 || chars[end-1] != '\\') && pop!(chars)
  out, cell = String[], Char[]
  for (i, c) in enumerate(chars)
    c == '|' && (i == 1 || chars[i-1] != '\\') ? (push!(out, strip(String(cell))); empty!(cell)) : push!(cell, c)
  end
  push!(out, strip(String(cell)))
end

tableline(cells) = "| " * join(cells, " | ") * " |"

"The side each column's text sits on, from the table's line of dashes: :left, :center or :right"
aligns(divider::AbstractString) =
  [startswith(c, ':') && endswith(c, ':') ? :center : endswith(c, ':') ? :right : :left for c in celltexts(divider)]

"Move each line of `f` across so its text sits on `side` of a space `room` wide"
align(f::Flow, room::px, side::Symbol) = begin
  side == :left && return f
  lines = map(f.lines) do vl
    dx = max(0px, room - sum(seg -> seg.w, vl.segs, init=0px)) * (side == :center ? 0.5 : 1)
    VLine([Seg(s.text, s.col, s.n, s.face, s.atomic, s.link, s.x + dx, s.w, s.node) for s in vl.segs], vl.x + dx, vl.from, vl.to, vl.top, vl.high)
  end
  Flow(lines, f.lh, f.size, f.above, f.below, f.kind, f.raw)
end

"""
How wide each column of a table is, when the table has `space` across it.
`natural` is how wide each column's text is on one line, and `least` is how
wide its longest word or number is. When the columns all fit, they share out
the room that's left by their natural widths. When they don't, each column
keeps the room that its longest word needs, and the columns share what's left
by how much more each one needs. So text wraps before a word or a number is cut
short, as in a spreadsheet or a browser.
"""
share_widths(natural, least, space) =
  sum(natural) <= space ? natural .* (num(space) / num(sum(natural))) :
  sum(least) >= space ? least .* (num(space) / num(sum(least))) :
  least .+ (natural .- least) .* (num(space - sum(least)) / num(sum(natural .- least)))

"Lay out the table in lines `from` to `to` of the document"
grid(e, from::Int, to::Int) = begin
  b = e.buf
  caret = from <= b.caret[1] <= to ? b.caret : nothing
  # As plain text, the run that the caret is in shows its markup, inside the caret's cell
  open = caret === nothing ? nothing : raw_part(b, caret[1])
  build() = begin
    base = Face(body(e), size=body(e).size * 0.94)
    lh = base.size * 1.5
    rows = tablerows((from, to))
    cells = [tablecells(b.lines[i]) for i in rows]
    ncols = max(1, maximum(length, cells))
    parts = map(enumerate(rows)) do (r, i)
      map(1:ncols) do c
        c <= length(cells[r]) || return Piece[]
        cell = cells[r][c]
        # The cell with the caret shows the spaces typed after its text, and as plain text the markup of the run that the caret is in
        active = caret !== nothing && caret[1] == i && within(cell, caret[2])
        cellpieces(e, i, b.lines[i], cell.lo, active ? max(cell.hi, caret[2]) : cell.hi,
                   r == 1 ? emboldened(base) : base, false; open=active ? open : nothing)
      end
    end
    # Each column gets room in proportion to its longest cell, and never less than its longest word needs
    natural = [maximum(row -> sum(wide, row[c], init=0px), parts, init=0px) + 2CELL_X for c in 1:ncols]
    natural = [clamp(w, 60px, e.width * 0.75) for w in natural]
    least = [min(natural[c], max(maximum(row -> maximum(unbroken, row[c], init=0px), parts, init=0px) + 2CELL_X, 36px)) for c in 1:ncols]
    widths = share_widths(natural, least, e.width - 1px * (ncols + 1))
    sides = aligns(b.lines[from+1])
    flows = [[align(wrap(row[c], widths[c] - 2CELL_X; lh, size=base.size, left=CELL_X), widths[c] - 2CELL_X, get(sides, c, :left))
              for c in 1:ncols] for row in parts]
    heights = [maximum(f -> tall(f), row) + 2CELL_Y for row in flows]
    Grid(rows, widths, heights, cells, flows)
  end
  # What inline code made can change its size, so a table with some in it is laid out again each time
  any(text -> occursin(INLINE, text), @view b.lines[from:to]) && return build()
  get!(build, e.flows, (:grid, from, b.lines[from:to], caret, b.plain, open))
end

const TABLE_GAP = 8px   # above and below a table
tall(g::Grid) = g.head + sum(g.heights) + 1px * (length(g.heights) + 1) + 2TABLE_GAP

"Where the text of row `r`, column `c` starts, from the top left of the table's item"
cell_origin(g::Grid, r::Int, c::Int) =
  (g.left + 1px * c + sum(g.widths[1:c-1], init=0px),
   TABLE_GAP + g.head + 1px * r + sum(g.heights[1:r-1], init=0px) + (g.heights[r] - tall(g.flows[r][c]))/2)

"The column in `cell` nearest to `x` on line `k` of its flow"
cellcol(f::Flow, k::Int, x::px, cell::Cell) =
  isempty(f.lines[k].segs) ? cell.lo : clamp(colat(f, k, x), cell.lo, cell.limit)

"The row and column of `g` that holds the caret at `p`, or nothing"
gridcell(g::Grid, p::Pos) = begin
  r = findfirst(==(p[1]), g.rows)
  (r === nothing || isempty(g.cells[r])) && return nothing
  (r, nearest(g.cells[r], p[2]))
end

"How wide the longest part of `p` is that can't go onto two lines: a word, a number or what a formula comes to"
unbroken(p::Piece) =
  p.node !== nothing ? p.node.w : p.atomic && !p.words ? measure(p.face, p.text) :
  maximum(word -> measure(p.face, word), split(p.text), init=0px) + (p.face.chip ? 2(CHIP_X + 1px) : 0px)

"""
The pieces `ps` of a line, with each character that the code font lacks in a
piece of its own, in a font that has it. A `code` chip stays one piece, and
draws those characters itself.
"""
spare(ps::Vector{Piece}) = begin
  whole(p) = p.face.family != codefont() || p.face.chip || p.atomic || p.node !== nothing || hasall(p.face, p.text)
  all(whole, ps) && return ps
  out = Piece[]
  for p in ps
    whole(p) && (push!(out, p); continue)
    col = p.col
    for (part, f) in runs(p.text, p.face)
      push!(out, Piece(part, col, length(part), f, false, p.link, nothing, false))
      col += length(part)
    end
  end
  out
end

const PICTURE_LINE = r"^\s*(?:\[\s*)?!\[([^\]]*)\]\(\s*(?|<([^>\n]+)>|([^)\s\"<](?:[^)\"\n]*[^)\s\"])?))(?:\s+\"[^\"]*\")?\s*\)(?:\s*\]\([^)]*\))?\s*$"

"""
True when the caret is in the code block that line `i` is in, and the selection
doesn't reach out of the block. A selection that goes through a block leaves it
as it reads.
"""
incode(b::Buffer, i::Int) = begin
  caretless(b) && return false
  s, t = codeblock(b, i)
  # A block that the caret is on as a whole shows as what it makes
  s <= b.caret[1] <= t && s <= b.anchor[1] <= t && picked(b) === nothing
end
