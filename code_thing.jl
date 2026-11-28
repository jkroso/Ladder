# The code of a thing, and moving a block by its handle
#
# A function draws each thing that a window shows: the method of `describe`
# for the thing's type. Hold ⌘ and ⌥ and click a thing, and its line stays,
# with buttons on its top edge after its label. Show Code shows that method in
# a window beside this one. The agent's logo opens the command palette with
# Ask Agent, with the thing as its A, ready for the words of the change or
# the question. A click anywhere else, or Esc, takes the line
# and its buttons away. While ⌘ and ⌥ are down, a line
# goes round the thing under the mouse, with a label: the name of its type,
# and the file and the line of its method.
#
# Show Code, in the command palette, takes the thing as its node, as Ask For
# Change does: it starts as what the caret is on, shown as a blue A, and a
# click chooses another and shows its code at once. Return shows the code of
# A. With the caret in a paragraph, it starts with nothing, so a click
# chooses. A block of Julia code shows where it is in its file.
#
# The window with the code shows a file that Ladder loaded. Code that you run
# there runs in the module that the file made, and not in a module of its own:
# see `loaded_module`. So change the method and press ⌘Return in it. Julia has
# the new method, and each window draws the thing again with it. The change
# lasts until Ladder quits. ⌘S writes it to the file, as it does for any file.
#
# The window shows the whole file, with the method's first line near its top,
# however long the file is: see "the lines of a long file".
#
# The picker is a tool of the window, as UI.jl's layout inspector is. A tool
# sees each click before the window's own parts do. A window has one tool, so
# the picker waits while the inspector is open.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe window_of
@use "github.com/jkroso/UI.jl/Interface/draw" hittest redraw_in! rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" load_icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/SVG" render_svg
@use "./markdown" Kind Span classify words front_matter wikitarget
@use "./math" => Maths
@use "./columns" => Columns
@use "github.com/jkroso/UI.jl/Interface/draw" set_tool! window_tool invalidate_layout!
@use Colors: @colorant_str, RGBA
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./math_view" exports...
@use "./file_view" exports...
@use "./columns_view" exports...
@use "./slides_view" exports...
@use "./run_code" exports...
@use "./agent/page" exports...

export SOURCE_FILES, drawn_by, BUILT_JULIA, JULIA_CODE, code_under, TextRun, pick_name, run_kind, span_kind,
       run_on, RUN_ROOM, text_run, code_label, code_picker, picks, code_tick!, asks_whom, same_thing,
       shown_now, PICK_LINE, LABEL_CLOSE, close_spot, pick_mark, PULSE_TIME, spin_ring, BlockDrag, block_drag,
       drop_tried, whole_block, HANDLE_WIDE, HANDLE_TALL, draw_handle, grab_block!, Drop, SIDE_DEAD,
       alone_line, column_of, empty_line, take_out!, put_in!, place_of, shares_text, rearranged, drop_target,
       drop_block!, rearrange!, window_beside, LADDER_FOLDER, ladder_folder, ladder_file

"Where the source of a file of code is on this Mac, by where it was on the Mac that built the app. The app fills it in when it starts: see app/app.jl."
const SOURCE_FILES = Dict{String,String}()

"The module that Kip made from the Julia file at `path`, or nothing when Ladder hasn't loaded that file. `path` is the file's real path."
loaded_module(path::AbstractString) = begin
  m = get(Kip.modules, path, nothing)
  m isa Module ? m : nothing
end

"""
The line of `lines`, the lines of a file as it is now, that the method `m`
starts on. Julia knows the line that the method was on when its file was
loaded, which is `line`. A file that was changed since then can have it on
another line, so this looks for the nearest line that starts a method of that
name for those types. It gives `line` when it finds none.
"""
settled_line(m::Method, lines, line::Int) = begin
  types = Base.unwrap_unionall(m.sig).parameters[2:end]
  names = [string(nameof(T)) for T in types if T isa DataType && T !== Any]
  # The name can have a module before it, and `function` or a macro before that
  starts = Regex("^\\s*(?:@\\w+\\s+)*(?:function\\s+)?(?:[\\w.]+\\.)?\\Q$(m.name)\\E\\(")
  fits(i) = 1 <= i <= length(lines) && occursin(starts, lines[i]) && all(n -> occursin(n, lines[i]), names)
  fits(line) && return line
  for far in 1:length(lines)
    fits(line - far) && return line - far
    fits(line + far) && return line + far
  end
  clamp(line, 1, max(length(lines), 1))
end

"The method that draws `x`: the method of `describe` for its type. It's nothing for a thing that no method draws."
drawn_by(x::SemanticUI) = try which(describe, Tuple{typeof(x)}) catch; nothing end
drawn_by(x) = nothing

"""
The file on this Mac that has the method `m`, and its line there. A method of
Julia's own is in Julia's folder of code: see `julia_file`. It's nothing when
this Mac doesn't have the file, as for a method that code made with no file.
"""
code_place(m::Method) = begin
  path = String(m.file)
  path = get(SOURCE_FILES, path, path)
  isabspath(path) && isfile(path) && return (realpath(path), Int(m.line))
  file = julia_file(m, path)
  file === nothing ? nothing : (file, Int(m.line))
end

"The folder of Ladder's own code, as `ladder_folder` found it, or nothing before it looked"
const LADDER_FOLDER = Ref{Union{Nothing,String}}(nothing)

"The folder of Ladder's own code, as `code_place` gives the files there: the folder of main.jl"
ladder_folder() = begin
  found = LADDER_FOLDER[]
  found === nothing || return found
  place = code_place(first(methods(ladder_folder)))
  LADDER_FOLDER[] = place === nothing ? "" : dirname(place[1])
end

"""
True when the file at `path`, as `code_place` gives it, is one that Ladder's
window is made of: main.jl and the files beside it, and the files of agent
mode and Ask Agent in the folder `agent`. A thing that such a file draws is
Ladder's own. A page's code draws the rest.
"""
ladder_file(path::AbstractString) = dirname(path) in (ladder_folder(), joinpath(ladder_folder(), "agent"))

"""
The folder of Julia's own code when Ladder was loaded. In the built app it's
the folder of the Julia that built the app. The app has no copy of Julia's
code, and this Mac can still have that Julia.
"""
const BUILT_JULIA = normpath(Sys.BINDIR, Base.DATAROOTDIR, "julia")

"""
What Ladder found of Julia's own code: the folder of the Julia that it found
it for, `bin`, the folders of Julia's code on this Mac, `dirs`, and the file
that each method's file is, as `julia_file` found it, or nothing, `files`.
Julia's code doesn't change while Ladder runs. The built app runs from its own
folder, so it doesn't use what the build found.
"""
const JULIA_CODE = Ref{Any}(nothing)

"What Ladder found of Julia's own code, as `JULIA_CODE` keeps it"
julia_code() = begin
  found = JULIA_CODE[]
  found !== nothing && found.bin == Sys.BINDIR && return found
  # `isdir` throws when macOS doesn't let Ladder look, as in the build's self-test, which can't see the Julia that built it
  seen(dir) = try isdir(dir) catch; false end
  dirs = unique(String[form for dir in (normpath(Sys.BINDIR, Base.DATAROOTDIR, "julia"), BUILT_JULIA) if seen(dir)
                       for form in (dir, realpath(dir))])
  JULIA_CODE[] = (bin=Sys.BINDIR, dirs=dirs, files=Dict{Tuple{String,Bool},Union{String,Nothing}}())
end

"True when the file at `path` is in a folder of Julia's own code. Ladder shows it and never changes it, as it does an email."
julia_own(path::AbstractString) = any(dir -> startswith(path, dir * "/"), julia_code().dirs)

"""
The file of Julia's own code that `path`, the file of the method `m`, is on
this Mac, or nothing. A method of Base or Core names its file by its place in
Base's folder, like `essentials.jl`. A method of Julia's standard library or
of its compiler names it by where it was on the Mac that built Julia, and that
path has `share/julia/` in it. The file is looked for in the Julia that runs
Ladder, then in the Julia that built it. Ladder shows the file and never
changes it: see `julia_own`.
"""
julia_file(m::Method, path::AbstractString) = begin
  base = Base.moduleroot(m.module) in (Base, Core)
  code = julia_code()
  get!(code.files, (String(path), base)) do
    k = findlast("share/julia/", path)
    # Only Base and Core name a file by its place in Base's folder. A file that code made with no file is called "none".
    k === nothing && !base && return nothing
    rest = k === nothing ? joinpath("base", path) : path[last(k)+1:end]
    for dir in code.dirs
      file = joinpath(dir, rest)
      isfile(file) && return realpath(file)
    end
    nothing
  end
end

"The thing under the mouse of the window `w` that has code to show, with the method that draws it: the nearest part of the window whose method is in a file on this Mac. It's nothing over a place with none."
code_under(w) = begin
  node = text_run(hittest(w), w)
  while node !== nothing
    m = drawn_by(node)
    m === nothing || code_place(m) === nothing || return (node, m)
    node = node.parent
  end
  nothing
end

# A paragraph, a heading, a list or a quote draws its words as runs of text,
# and a link or bold words in it are runs too. They aren't parts of the
# window, so the part under the mouse there is the whole block. ⌘⌥ looks in
# the block for the run under the mouse, and picks it when it's drawn its own
# way. Its code is the function that gives it that look. A node in a line, like
# a switch that inline code made, is a part of the window, and picks itself.

"""
A run of a line's text that's drawn its own way: a link, a wiki link, bold,
slanted, struck or highlighted words, a comment, inline code, what inline code
came to, a footnote's number, or a to-do item's box. It's in the block that holds its line, and
isn't drawn as a node of its own. `code` is the method that gives it its look.
"""
@def mutable struct TextRun <: SemanticUI
  kind::String = ""     # what it is, like "Link"
  line::Int = 0         # the line of the page that it's on
  from::Int = 0         # the columns of that line that it draws: from `from` up to `to`
  to::Int = 0
  code::Any = nothing
end

drawn_by(r::TextRun) = r.code

"What the label over a thing calls the part `x` of the window: the name of its type, or what a run of text is"
pick_name(x) = string(nameof(typeof(x)))
pick_name(r::TextRun) = r.kind

"""
What the run `seg` of a line's text is, and the method that gives it its look,
or nothing for a run of plain words. `s` is the span of the line that it's
part of, or nothing. `raw` is true while the line's markup shows.
"""
run_kind(seg::Seg, s, raw::Bool) = begin
  isbox(seg) && return ("To-do box", which(todo_box, Tuple{Seg}))
  kind = span_kind(seg.link, s, raw)
  kind === nothing && return nothing
  kind, (kind in ("Footnote", "Code", "Highlighted") ? which(describe, Tuple{Seg}) :
         kind == "Value" ? which(inline, Tuple{Any,Int,Span,Face}) : which(face, Tuple{Face,Span}))
end

"""
What a run of a line's text is, like "Link" or "Code", or nothing for plain
words and markup. `link` is where the run goes, when it's part of a link. `s`
is the span of the line that it's part of, or nothing. `raw` is true while the
line's markup shows: inline code that runs is then code, and not its value.
"""
span_kind(link, s, raw::Bool) =
  startswith(link, '^') ? "Footnote" :
  !isempty(link) ? (wikitarget(link) === nothing ? "Link" : "Wiki link") :
  s === nothing || s.markup ? nothing :
  s.live && !raw ? "Value" : s.code ? "Code" : s.comment ? "Comment" : s.highlit ? "Highlighted" :
  s.math ? "Formula" : s.strike ? "Struck" :
  s.bold && s.italic ? "Bold italic" : s.bold ? "Bold" : s.italic ? "Italic" : nothing

"""
The run of text at the point `(x, y)` of the window of `e` that's drawn its
own way, or nothing. A link takes in each run of its words, even where bold
words or markup split them.
"""
run_on(e, (x, y)) = begin
  rich(e.buf) && !isempty(e.layout) || return nothing
  dx, dy = x - e.origin[1], y - e.origin[2]
  dy >= 0px || return nothing
  it = e.layout[item_under(e, dx, dy)]
  f = it.content
  (f isa Flow && 1 <= it.first <= length(e.buf.lines) && kinds(e.buf)[it.first].kind in TEXT_KINDS) || return nothing
  dx -= item_room(e, it)[1]
  segs = [seg for vl in f.lines for seg in vl.segs]
  k = findfirst(vl -> it.top + f.above + vl.top <= dy < it.top + f.above + vl.top + vl.high, f.lines)
  k === nothing && return nothing
  hit = findfirst(seg -> seg.x <= dx < seg.x + seg.w, f.lines[k].segs)
  hit === nothing && return nothing
  seg = f.lines[k].segs[hit]
  seg.node === nothing || return nothing
  _, line_spans = richspans(e.buf, it.first)
  j = findlast(o -> o.col <= seg.col < o.col + length(o.text), line_spans)
  s = j === nothing ? nothing : line_spans[j]
  found = run_kind(seg, s, f.raw)
  found === nothing && return nothing
  kind, code = found
  # The runs round this one that are part of it: the rest of a link, the rest of a span
  ours(o) = !isempty(seg.link) ? o.link == seg.link : s !== nothing && kind != "Footnote" && kind != "To-do box" && s.col <= o.col < s.col + length(s.text)
  i = findfirst(o -> o === seg, segs)
  lo = hi = i
  while lo > 1 && ours(segs[lo-1]); lo -= 1 end
  while hi < length(segs) && ours(segs[hi+1]); hi += 1 end
  TextRun(kind=kind, line=it.first, from=segs[lo].col, to=segs[hi].col + max(segs[hi].n, 1), code=code)
end

"Where the run `r` is in the window: round each piece of it, on each of the lines that it's on. It's nothing when the page has no such run now."
rect(r::TextRun) = begin
  e = editor(r)
  (e isa Editor && !isempty(e.layout) && 1 <= r.line <= length(e.buf.lines)) || return nothing
  it = item(e, r.line)
  f = it.content
  f isa Flow || return nothing
  box = nothing
  for vl in f.lines, seg in vl.segs
    r.from <= seg.col < r.to || continue
    y = it.top + f.above + vl.top
    box = box === nothing ? (seg.x, seg.x + seg.w, y, y + vl.high) :
      (min(box[1], seg.x), max(box[2], seg.x + seg.w), min(box[3], y), max(box[4], y + vl.high))
  end
  box === nothing && return nothing
  # A little room on each side, so the line round it doesn't touch its first and last letters
  left = e.origin[1] + item_room(e, it)[1] - RUN_ROOM
  (left=left + box[1], top=e.origin[2] + box[3], width=box[2] - box[1] + 2RUN_ROOM, height=box[4] - box[3])
end

const RUN_ROOM = 2px

"""
The part of the window to show the code of, when `node` is the part under the
mouse of the window `w`: the run of text under the mouse that's drawn its own
way, when `node` is a block of the page's text and there's such a run. It's
`node` itself anywhere else.
"""
text_run(node, w) = begin
  node isa Union{Paragraph,Heading,List,Quote} || return node
  r = run_on(editor(node), (w.mouse[1], w.mouse[2]))
  r === nothing && return node
  setfield!(r, :parent, node)   # so it can reach the editor, and ⌥↑ goes from it to the block
  r
end

"What a window's label says of the method `m`: its file's name, with the folder that holds it for a file called main.jl, and its line"
code_label(m::Method) = begin
  file, line = code_place(m)
  name = basename(file)
  name == "main.jl" && (name = joinpath(basename(dirname(file)), name))
  "$name:$line"
end

code_picker(e) = get!(() -> CodePicker(editor=e), e.nodes, :code_picker)::CodePicker

"""
True while a click in the window `w` shows the code of the thing that it's on:
while ⌘ and ⌥ are down with no other key that's held. With ⇧ or ⌃ down as
well, as with a key that holds all four, it isn't.
"""
picks(t::CodePicker, w) = only_held(w, Keys.cmd | Keys.opt)

"Give the window of `e` its picker, unless it has a tool, like the layout inspector"
code_tick!(e) = begin
  w = window_of(e)
  w === nothing || window_tool(w) !== nothing || set_tool!(w, code_picker(e))
  nothing
end

"The name of the agent that Ask Agent asks from the window of `e`: the one that shares the page, or else the one that Settings chose"
asks_whom(e) = (name = sharer(e); isempty(name) ? e.ai : name)

"""
True when `a` and `b` are the same thing of the window. A run of text is made
again each time, so it's the same when it's the same columns of the same line.
A paragraph, a heading and each other block of the page is made again on each
frame too, so it's the same when it's the same kind of block from the same line.
"""
same_thing(a, b) = a === b
same_thing(a::TextRun, b::TextRun) = (a.line, a.from, a.to) == (b.line, b.from, b.to)
same_thing(a::Block, b::Block) = a === b || (typeof(a) === typeof(b) && a.first == b.first && editor(a) === editor(b))

"""
The part of the window that is `x` in this frame. A block of the page is made
again on each frame, so it's the block of this frame that's the same thing.
It's nothing when the page doesn't show that block now.
"""
shown_now(x) = x
shown_now(b::Block) = begin
  parts = shown_parts(editor(b))
  k = findfirst(p -> p isa Block && same_thing(p, b), parts)
  k === nothing ? nothing : parts[k]
end

const PICK_LINE = colorant"rgb(48,128,236)"

const LABEL_CLOSE = 18.0   # how wide the × at the end of a label is: see `pick_mark`

"Where the × at the end of the label at `r`, as `pick_mark` gives it, is"
close_spot(r) = (r[1] + r[3] - LABEL_CLOSE, r[2], LABEL_CLOSE, r[4])

"""
Draw a line round the place `r` of the window `w`, and a label with `words`
over its top left corner. With no place, the label is under the top bar. With
no words, there's no label. `room` is the width that something after the
label, on the same line, needs in the window. With `close`, the label ends
with an ×, at `close_spot` of where it is.
"""
pick_mark(ctx, w, r, words; colour=PICK_LINE, room=0.0, lift=0.0, busy=false, avoid=nothing, close=false) = begin
  x, y = 16.0, 64.0
  if r !== nothing
    x, y, wide, tall = num(r.left), num(r.top), num(r.width), num(r.height)
    # While an agent works on the thing, the colour inside the line pulses
    fill = busy ? 0.08 + 0.14 * (0.5 - 0.5 * cos(2π * time() / PULSE_TIME)) : 0.08
    round_box(ctx, x + 0.5, y + 0.5, max(1, wide - 1), max(1, tall - 1), 3; fill=RGBA(colour.r, colour.g, colour.b, fill), line=colour, wide=1.5)
  end
  isempty(words) && return nothing
  face = Face(SANS, "", 11px, colorant"white", false)
  # and the label has a ring that turns before its words
  turn = busy ? 15.0 : 0.0
  across = num(measure(face, words)) + 12 + turn + (close ? LABEL_CLOSE - 2 : 0.0)
  # The label sits on the thing's top edge, and comes down into the thing where the window has no room over it.
  # A thing whose top is above the window, like a whole file, has its label at the top of the window.
  # `room` is how much more the label needs after it, for the buttons that follow it
  left = clamp(x, 0.0, max(0.0, num(w.size[1]) - across - room))
  # `lift` puts it that much higher, over the label of another request about the same thing, or lower where there's no room
  top = y >= 18 + lift ? y - 18 - lift : max(y, 0.0) + lift
  # `avoid` has the labels drawn already. One that this one would cover pushes it up a row, or down where there's no room.
  if avoid !== nothing
    covers(at) = any(o -> left < o[1] + o[3] && o[1] < left + across && at < o[2] + o[4] && o[2] < at + 18, avoid)
    tries = 0
    while covers(top) && tries < 8
      top = top >= 20 ? top - 20 : top + 20
      tries += 1
    end
    push!(avoid, (left, top, across, 18.0))
  end
  round_box(ctx, left, top, across, 18, 3; fill=colour)
  busy && spin_ring(ctx, left + 11, top + 9, 4.0, colorant"white")
  write_ink(ctx, words, left + 6 + turn, top + 13, face)
  if close
    x, y, wide, tall = close_spot((left, top, across, 18.0))
    mx, my = num(w.mouse[1]), num(w.mouse[2])
    # The × is darker under the mouse
    x <= mx <= x + wide && y <= my <= y + tall && round_box(ctx, x + 1, y + 2, wide - 3, tall - 4, 3; fill=RGBA(0, 0, 0, 0.22))
    shape = load_icon("x-lg")
    render_svg(ctx, px(x + 4.5), px(y + 4.5), px(9), px(9), shape.paths, shape.viewbox, colorant"white")
  end
  (left, top, across, 18.0)   # where the label is, for a click on it
end

"How many seconds the colour inside the line round a thing that an agent works on takes to pulse once"
const PULSE_TIME = 1.6

"A ring of radius `r` round (`x`, `y`) in `colour`: faint, with a quarter of it in full that goes round once in `SPIN_TURN` seconds, as a `Spinner`'s does"
spin_ring(ctx, x, y, r, colour; wide=1.5) = begin
  ring = ink(RGBA(colour, 0.35), wide)
  Skia.sk_canvas_draw_circle(ctx, Float32(x), Float32(y), Float32(r), ring)
  Skia.sk_paint_delete(ring)
  oval = Ref(Skia.sk_rect_t(Float32(x - r), Float32(y - r), Float32(x + r), Float32(y + r)))
  arc = ink(colour, wide)
  Skia.sk_canvas_draw_arc(ctx, oval, Float32(360 * mod(time(), SPIN_TURN) / SPIN_TURN), 90f0, false, arc)
  Skia.sk_paint_delete(arc)
end

# --- move a block by its handle ------------------------------------------------------------------
#
# The line round a block of the page that a click with ⌘ and ⌥ down chose has
# a handle at its top left, in the margin beside the block's first line, as
# Notion has: six dots. Drag the handle, and a blue line shows where the block
# goes. The block goes there when the button comes up, and keeps its line. One
# ⌘Z puts it back. Esc stops the drag, and the block stays where it was.
#
# A blue line across the page is a gap between two blocks: the block goes
# there. A blue line down the side of a block makes columns, as in Notion.
# Over the left or the right quarter of a block, the dragged block goes beside
# it: the two become columns, with a `columns` block over them that says 2.
# Beside a column of a group, the block is a new column there, and the group's
# number grows by one. A column that's dragged out of its group leaves it, and
# the number goes down by one. A group with one column left loses its
# `columns` block. A gap between the blocks under a heading that's a column
# puts the block in that column.
#
# Columns are what columns.jl reads: a column holds one block, or a heading and
# the blocks under it. So a heading takes the blocks under it into a column
# with it, and a column that starts with a heading moves with its blocks. A
# place where the page couldn't hold what the drop asks for has no blue line,
# like the right of a heading for a paragraph, which the heading's column
# would take in.
#
# A block is what the line goes round: a paragraph, a heading, a whole list, a
# quote, a table, a block of code, or a block that shows what it makes, like a
# board or a chart. A run of text, like a link, has no handle. Nor has a part
# of a block, like a card of a board, nor the front matter, nor a `columns`
# block, nor a page that you can't change. The block goes to a place among the
# blocks that show, so the wheel scrolls the page while the button is down, to
# a place further away.
#
# Where the block meets the lines of another block, an empty line keeps them
# apart, so a paragraph doesn't join the paragraph above it. Where it leaves
# two empty lines together, one goes.

"""
The handle on the line round a block that a click with ⌘ and ⌥ down chose,
and a drag of the block by it. `at` is where the handle was drawn in the last
frame, or nothing when the chosen thing has none. While the block is dragged,
`lines` are its first and last lines, and `node` and `method` are the chosen
thing, which keeps its line in the block's new place. `lines` is nothing when
there's no drag.
"""
@def mutable struct BlockDrag
  at::Any = nothing
  lines::Any = nothing
  node::Any = nothing
  method::Any = nothing
end

block_drag(e) = get!(() -> BlockDrag(), e.nodes, :block_drag)::BlockDrag

"What each place that a drag of a block came over would make of the page, so that it's worked out once in a drag"
drop_tried(e) = get!(() -> Dict{Any,Any}(), e.nodes, :drop_tried)::Dict{Any,Any}

"True while a block of the page in the window of the picker `t` is dragged by its handle"
dragging(t::CodePicker) = (d = get(t.editor.nodes, :block_drag, nothing); d isa BlockDrag && d.lines !== nothing)

"""
The block of the page in `e` that the thing `x` is, when a drag can move it:
`x` itself when it's a block of the page's lines, or the block that shows it,
when `x` is all that a block shows, like a board. It's nothing for a part of
a block, for the front matter, for a `columns` block, and in a page that you
can't change.
"""
whole_block(e, x) = begin
  b = e.buf
  (b.view == :markdown && !readonly(b) && !b.fixed && slideshow(e) === nothing && lowered(e) === nothing) || return nothing
  found = x isa Block ? x : nothing
  shows(it) = it.content isa Live && (it.content.node === x || (it.content.node isa FileBlock && it.content.node.value === x))
  if found === nothing
    for p in shown_parts(e)
      p isa LiveBlock && any(shows, p.items) && (found = p; break)
    end
  end
  (found === nothing || found.first <= front_matter(b.lines) || Columns.opens(kinds(b)[found.first])) && return nothing
  found
end

const HANDLE_WIDE = 14.0
const HANDLE_TALL = 18.0

"""
Draw the handle of a block at the left of the top of `r`, the place of the
line round it: six dots, darker under the mouse and while it's `held`. It
gives where the handle is, for a press on it.
"""
draw_handle(ctx, w, r, held::Bool) = begin
  left, top = max(2.0, num(r.left) - HANDLE_WIDE - 4), num(r.top)
  x, y = num(w.mouse[1]), num(w.mouse[2])
  over = held || (left <= x <= left + HANDLE_WIDE && top <= y <= top + HANDLE_TALL)
  colour = over ? PICK_LINE : RGBA(PICK_LINE.r, PICK_LINE.g, PICK_LINE.b, 0.55)
  for across in (-1, 1), down in (-1, 0, 1)
    disc(ctx, left + HANDLE_WIDE / 2 + across * 2.75, top + HANDLE_TALL / 2 + down * 5, 1.6, colour)
  end
  (left, top, HANDLE_WIDE, HANDLE_TALL)
end

"Start a drag of the block that a click with ⌘ and ⌥ down chose, when `(x, y)` is on its handle. It's true when it did."
grab_block!(t::CodePicker, x, y) = begin
  d = block_drag(t.editor)
  (d.at !== nothing && t.chosen !== nothing) || return false
  left, top, wide, tall = d.at
  (left <= x <= left + wide && top <= y <= top + tall) || return false
  node, m = t.chosen
  block = whole_block(t.editor, shown_now(node))
  block === nothing && return false
  d.lines, d.node, d.method = (block.first, block.last), node, m
  empty!(drop_tried(t.editor))
  redraw_in!(t.editor, 0)
  true
end

"""
A place that a dragged block can go. `side` is :gap for a gap between two
blocks: the block goes in front of line `line`, or after it when `after`.
`inner` is true for a gap between the blocks under a heading that's a column,
so the block goes into that column. `side` is :left or :right for beside the
block or the column that starts on line `line`, to make a column of the block.
`x`, `y` and `long` are where the blue line that shows it is: across from
`(x, y)` and `long` wide for a gap, or down from `(x, y)` and `long` tall for a side.
"""
struct Drop
  side::Symbol
  line::Int
  after::Bool
  inner::Bool
  x::Float64
  y::Float64
  long::Float64
end

"How far into a block the mouse has to be before its left quarter is a place beside it. The handle is just outside the block, so a drag straight down from it makes no columns."
const SIDE_DEAD = 16.0

"True when line `i` of `lines`, whose kinds are `ks`, is a block by itself, like a line that holds only a picture or a formula. `column_groups` asks the same of a page."
alone_line(lines, ks, i) = ks[i].kind == Kind.paragraph && (
  (occursin("![", lines[i]) && occursin(PICTURE_LINE, lines[i])) ||
  (occursin("\$\$", lines[i]) && maths_text(lines[i]) !== nothing && Maths.available()))

"The group of columns among `gs`, and the column of it, that line `i` is in, by their places. It's nothing for a line in no column."
column_of(gs, i::Int) = begin
  for (gi, g) in enumerate(gs), (k, span) in enumerate(g.spans)
    i in span && return (gi, k)
  end
  nothing
end

"A line of the page as a move puts the lines in a new order: the line that it was, or 0 for a new line, and its text"
const Moved = Pair{Int,String}

empty_line(x::Moved) = isempty(strip(x.second))

"Take the lines that were lines `span` of the page out of `doc`. Where that leaves two empty lines together, or one at the start or the end, one goes too."
take_out!(doc::Vector{Moved}, span) = begin
  p, q = findfirst(x -> x.first in span, doc), findlast(x -> x.first in span, doc)
  p === nothing && return doc
  deleteat!(doc, p:q)
  if p <= length(doc) && empty_line(doc[p]) && (p == 1 || empty_line(doc[p-1]))
    deleteat!(doc, p)
  elseif p > length(doc) && p > 1 && empty_line(doc[p-1])
    deleteat!(doc, p - 1)
  end
  doc
end

"Put the lines `chunk` into `doc` in front of place `p`, with an empty line between them and a line next to them that isn't empty"
put_in!(doc::Vector{Moved}, p::Int, chunk) = begin
  before = p > 1 && !empty_line(doc[p-1]) ? Moved[0 => ""] : Moved[]
  after = p <= length(doc) && !empty_line(doc[p]) ? Moved[0 => ""] : Moved[]
  splice!(doc, p:p-1, [before; chunk; after])
  doc
end

"Where the line that was line `i` of the page is in `doc`, or nothing when it went"
place_of(doc::Vector{Moved}, i::Int) = findfirst(x -> x.first == i, doc)

"What a `columns` block says for columns with these shares of the width: how many there are, when they're all as wide"
shares_text(shares) = all(==(first(shares)), shares) ? string(length(shares)) :
  join((isinteger(x) ? string(Int(x)) : string(x) for x in shares), " ")

"""
The lines of the page `lines` after the block of lines `s` to `t` goes to
`drop`, each with the line that it was. `ks` says what kind each line is, and
`gs` is the page's groups of columns. It's nothing when the page would be the
same, or when the columns that columns.jl reads from the new lines aren't the
ones that the drop asks for. `check` false leaves that out, as for a gap on a
page with no columns, where nothing can turn into a column.

A block that starts a column moves with its column. A block that goes beside
another takes the blocks under it, when it's a heading, and so does the block
that it goes beside.
"""
rearranged(lines, ks, gs, s::Int, t::Int, drop::Drop; check=true) = begin
  alone(i) = alone_line(lines, ks, i)
  own = column_of(gs, s)
  own !== nothing && first(gs[own[1]].spans[own[2]]) != s && (own = nothing)
  unit = own !== nothing ? gs[own[1]].spans[own[2]] : drop.side == :gap ? (s:t) : (s:Columns.column_end(ks, s; alone))
  drop.line in unit && return nothing
  share(gi, k) = k <= length(gs[gi].shares) ? gs[gi].shares[k] : 1.0
  # The shares of the width of the columns of each group that the drop changes, by the group's place in `gs`
  shares = Dict{Int,Vector{Float64}}()
  wants(gi) = get!(shares, gi) do
    n = length(gs[gi].spans)
    Float64[share(gi, k) for k in 1:n]
  end
  doc = Moved[i => lines[i] for i in eachindex(lines)]
  chunk = Moved[i => lines[i] for i in unit]
  own === nothing || deleteat!(wants(own[1]), own[2])
  take_out!(doc, unit)
  target, them = nothing, nothing
  if drop.side == :gap
    p = place_of(doc, drop.line)
    p === nothing && return nothing
    put_in!(doc, drop.after ? p + 1 : p, chunk)
  elseif (target = column_of(gs, drop.line)) !== nothing
    gi, k = target
    span = gs[gi].spans[k]
    # A column that left the same group from before this one leaves this one a place further up
    at = own !== nothing && own[1] == gi && own[2] < k ? k - 1 : k
    # A column keeps its width in its own group. A new one is as wide as the one it's beside.
    insert!(wants(gi), drop.side == :left ? at : at + 1, own !== nothing && own[1] == gi ? share(own...) : share(gi, k))
    p = drop.side == :left ? findfirst(x -> x.first in span, doc) : findlast(x -> x.first in span, doc) + 1
    put_in!(doc, p, chunk)
  else
    them = drop.line:Columns.column_end(ks, drop.line; alone)
    fence = Moved[0 => "```$COLUMN_BLOCK", 0 => "2", 0 => "```"]
    p = place_of(doc, drop.line)
    if drop.side == :left
      put_in!(doc, p, [fence; Moved[0 => ""]; chunk])
    else
      put_in!(doc, p, fence)
      put_in!(doc, findlast(x -> x.first in them, doc) + 1, chunk)
    end
  end
  # Each group that the drop changed says its new number of columns, or loses its `columns` block when one or none is left
  for (gi, sh) in shares
    g = gs[gi]
    if length(sh) <= 1
      take_out!(doc, g.first:g.last)
    else
      p, q = place_of(doc, g.first), place_of(doc, g.last)
      splice!(doc, p+1:q-1, Moved[0 => shares_text(sh)])
    end
  end
  new = last.(doc)
  new == lines && return nothing
  check || return doc
  # The columns that the drop asks for, each as the lines that it holds, by the line that each was
  held(span) = Set(i for i in span if !isempty(strip(lines[i])))
  want = Vector{Set{Int}}[held.(g.spans) for g in gs]
  moved = held(unit)
  own === nothing ? foreach(g -> foreach(c -> setdiff!(c, moved), g), want) : deleteat!(want[own[1]], own[2])
  if drop.side == :gap
    c = drop.inner ? column_of(gs, drop.line) : nothing
    c === nothing || union!(want[c[1]][c[2]], moved)
  elseif target !== nothing
    gi, k = target
    insert!(want[gi], drop.side == :left ? (own !== nothing && own[1] == gi && own[2] < k ? k - 1 : k) :
                      (own !== nothing && own[1] == gi && own[2] < k ? k : k + 1), moved)
  else
    push!(want, drop.side == :left ? [moved, held(them)] : [held(them), moved])
  end
  wanted = Set(w for (gi, w) in enumerate(want) if !isempty(w) && !(haskey(shares, gi) && length(shares[gi]) <= 1))
  # The columns that columns.jl reads from the new lines
  newks = classify(new)
  found = Columns.groups(new, newks, alone=i -> alone_line(new, newks, i))
  got(span) = Set(doc[i].first for i in span if doc[i].first != 0 && !empty_line(doc[i]))
  Set(got.(g.spans) for g in found if !isempty(g.spans)) == wanted ? doc : nothing
end

"""
Where the lines `s` to `t` of the page in `e` go when a drag of them is at the
point `(x, y)` of the window: a `Drop`, with the lines of the page after the
move, or nothing when no place there takes them. Over the left or the right
quarter of a block, or of a column, it's beside that block or column. Any
other place is the nearest gap between two blocks: of the page, or between
the blocks under a heading that's a column, when the mouse is in it.
"""
drop_target(e, (s, t), x, y) = begin
  b = e.buf
  ks, gs = kinds(b), column_groups(e)
  shown = Tuple{Any,NTuple{4,Float64}}[]
  for p in shown_parts(e)
    p isa Block || continue
    r = try rect(p) catch; nothing end
    r === nothing || push!(shown, (p, (num(r.left), num(r.top), num(r.width), num(r.height))))
  end
  isempty(shown) && return nothing
  # The room in the window of the blocks that start on lines `a` to `z`: its left, its top, its width and its height
  room(a, z) = begin
    rs = [r for (p, r) in shown if a <= p.first <= z]
    isempty(rs) && return nothing
    left, top = minimum(r -> r[1], rs), minimum(r -> r[2], rs)
    (left, top, maximum(r -> r[1] + r[3], rs) - left, maximum(r -> r[2] + r[4], rs) - top)
  end
  tried(drop) = begin
    key = (b.version, s, t, drop.side, drop.line, drop.after, drop.inner)
    got = get!(() -> rearranged(b.lines, ks, gs, s, t, drop; check=!isempty(gs) || drop.side != :gap), drop_tried(e), key)
    got === nothing ? nothing : (drop, got)
  end
  # Over the left or the right quarter of a block, or of the column that it's in, it goes beside that
  for (p, r) in shown
    (r[1] <= x <= r[1] + r[3] && r[2] <= y <= r[2] + r[4]) || continue
    c = column_of(gs, p.first)
    line = c === nothing ? p.first : first(gs[c[1]].spans[c[2]])
    s <= line <= t && break
    z = c === nothing ? Columns.column_end(ks, line; alone=i -> alone_line(b.lines, ks, i)) : last(gs[c[1]].spans[c[2]])
    left, top, wide, tall = something(room(line, z), r)
    side = left + SIDE_DEAD <= x < left + wide / 4 ? :left : x > left + wide * 3 / 4 ? :right : nothing
    side === nothing && break
    found = tried(Drop(side, line, false, false, side == :left ? left - 5 : left + wide + 5, top, tall))
    found === nothing || return found
    break
  end
  # The rows of the page: each block, or each group of columns. A gap is in front of each, and after the last.
  rows = Tuple{Int,Int,Float64,Float64,Int}[]   # its first and last line, its top and bottom, and its group's place or 0
  for (p, r) in shown
    c = column_of(gs, p.first)
    gi = c === nothing ? 0 : c[1]
    if gi != 0 && !isempty(rows) && rows[end][5] == gi
      a, z, top, bottom, _ = rows[end]
      rows[end] = (a, z, min(top, r[2]), max(bottom, r[2] + r[4]), gi)
    else
      push!(rows, (gi == 0 ? p.first : gs[gi].first, gi == 0 ? p.last : last(gs[gi].spans[end]), r[2], r[2] + r[4], gi))
    end
  end
  page_left = minimum(r[1] for (_, r) in shown)
  page_wide = maximum(r[1] + r[3] for (_, r) in shown) - page_left
  matter = front_matter(b.lines)
  gaps = Drop[]
  for (k, row) in enumerate(rows)
    row[1] > matter || continue   # nothing goes in front of the front matter
    push!(gaps, Drop(:gap, row[1], false, false, page_left, k == 1 ? row[3] - 4 : (rows[k-1][4] + row[3]) / 2, page_wide))
  end
  push!(gaps, Drop(:gap, rows[end][2], true, false, page_left, rows[end][4] + 4, page_wide))
  # A column that starts with a heading has a gap between each two of its blocks, and after its last
  for g in gs, span in g.spans
    ks[first(span)].kind == Kind.heading || continue
    area = room(first(span), last(span))
    (area !== nothing && area[1] <= x <= area[1] + area[3] && area[2] <= y <= area[2] + area[4] + 20) || continue
    under = [(p, r) for (p, r) in shown if first(span) <= p.first <= last(span)]
    for k in 2:length(under)
      p, r = under[k]
      push!(gaps, Drop(:gap, p.first, false, true, area[1], (under[k-1][2][2] + under[k-1][2][4] + r[2]) / 2, area[3]))
    end
    p, r = under[end]
    push!(gaps, Drop(:gap, p.last, true, true, area[1], r[2] + r[4] + 4, area[3]))
  end
  tried(gaps[argmin([abs(g.y - y) for g in gaps])])
end

"""
End the drag of a block: the block goes to the place that the blue line
shows, and keeps its line round it there. It's true when a block was dragged.
"""
drop_block!(t::CodePicker, w) = begin
  d = block_drag(t.editor)
  d.lines === nothing && return false
  (s, l), node, m = d.lines, d.node, d.method
  e = t.editor
  found = drop_target(e, (s, l), num(w.mouse[1]), num(w.mouse[2]))
  d.lines = d.node = d.method = nothing
  empty!(drop_tried(e))
  start = found === nothing ? nothing : rearrange!(e, found[2], s)
  # A block of the page is the block that starts on the same line in each frame, so its line goes with it
  if start !== nothing && node isa Block
    node.first, node.last = start, start + l - s
  end
  t.chosen = (node, m)
  redraw_in!(e, 0)
  true
end

"""
Give the page in `e` the lines of `doc`, which a move put in a new order, in
one edit, so one ⌘Z puts them back. The caret and the other end of the
selection stay with their text. It gives the line that was line `s` before.
"""
rearrange!(e, doc::Vector{Moved}, s::Int) = begin
  b = e.buf
  old, new = b.lines, last.(doc)
  # Only the lines between those that are the same at the start and at the end change
  lo = 1
  while lo <= min(length(old), length(new)) && old[lo] == new[lo]
    lo += 1
  end
  z, y = length(old), length(new)
  while z >= lo && y >= lo && old[z] == new[y]
    z -= 1; y -= 1
  end
  # An edit has a line to change at each end, so lines that only went in, or only went, take a line that stays with them
  (z < lo || y < lo) && (lo > 1 ? (lo -= 1) : (z += 1; y += 1))
  caret, anchor = b.caret, b.anchor
  edit!(b, (lo, 0), line_end(b, z), join(new[lo:y], "\n"))
  now = Dict(i => k for (k, (i, _)) in enumerate(doc) if i != 0)
  # A line that went takes the caret to the end of the line before it
  follow((i, col)) = begin
    j = findlast(k -> haskey(now, k), 1:i)
    j === nothing && return (1, 0)
    at = now[j]
    (at, j == i ? min(col, length(b.lines[at])) : length(b.lines[at]))
  end
  b.caret, b.anchor = follow(caret), follow(anchor)
  redraw_in!(e, 0)
  now[s]
end

"While a block is dragged by its handle, draw the blue line that shows where it would go: across the page for a gap, down the side of a block for a column"
draw_drag(ctx, w, t::CodePicker) = begin
  dragging(t) || return nothing
  found = drop_target(t.editor, block_drag(t.editor).lines, num(w.mouse[1]), num(w.mouse[2]))
  found === nothing && return nothing
  drop = found[1]
  drop.side == :gap ? round_box(ctx, drop.x, drop.y - 1.5, drop.long, 3, 1.5; fill=PICK_LINE) :
                      round_box(ctx, drop.x - 1.5, drop.y, 3, drop.long, 1.5; fill=PICK_LINE)
  disc(ctx, drop.x, drop.y, 3.5, PICK_LINE)
  nothing
end

"""
Show the method `m` in a window beside the window of `e`: the file that has
it, with the caret on its first line. A window that shows the file already
comes to the front. It gives the editor of that window, or nothing when this
Mac doesn't have the file.
"""
show_code!(e, m::Method) = begin
  place = code_place(m)
  place === nothing && return nothing
  file, line = place
  k = findfirst(o -> o !== e && !isempty(o.buf.path) && (o.buf.path == file || page_key(o.buf.path) == file), editors)
  # Julia knows the line that the method was on when its file was loaded. The file can have changed since, on the disk or in its window.
  show_place!(e, file, settled_line(m, k === nothing ? text(file) : editors[k].buf.lines, line))
end

"""
Show line `line` of the file `file` in a window beside the window of `e`, with
the caret on it, near the top of the window. A window that shows the file
already comes to the front. It gives the editor of that window.
"""
show_place!(e, file::AbstractString, line::Int) = begin
  by = window_of(e)
  k = findfirst(o -> o !== e && !isempty(o.buf.path) && (o.buf.path == file || page_key(o.buf.path) == file), editors)
  if k === nothing
    shown = build_editor(file)
    same_settings!(shown, e)
    shown.remember = e.remember
    shown.panel = false
    size, at = window_beside(by)
    shown.size = size
    show_window!(window!(shown, title="Ladder", size=size, position=at), by)
  else
    shown = editors[k]
    w = window_of(shown)
    w === nothing || !isopen(w) || front!(w)
  end
  show_line!(shown, line)
  # The method's first line goes near the top of the window. The next frame does it, once it has laid out the file.
  shown.nodes[:hold] = (line, 24px - PAGE_TOP)
  shown
end

"The size and the place of a window that opens beside the window `by`: at its right where the screen has room, or else at its left, or else over its right half"
window_beside(by) = begin
  by === nothing && return (paper_window(screen_room(), 0px), (0px, 0px))
  screen = Screen().size[1]
  wide, tall = min(by.size[1], 760px), by.size[2]
  left, top = by.position
  right = left + by.size[1]
  at = right + wide <= screen ? right : left - wide >= 0px ? left - wide : max(0px, screen - wide)
  ((wide, tall), (at, top))
end

"Draw each window again with the methods that Julia has now, after code gave a function a new one"
redraw_windows!() =
  for o in editors
    w = window_of(o)
    w === nothing && continue
    invalidate_layout!(w)
    redraw_in!(o, 0)
  end
