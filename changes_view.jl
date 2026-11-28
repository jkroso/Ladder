# The view of a block of changes to accept or reject
#
# A code block in the language `changes` holds a diff, and shows each of its
# changes with the lines that go in red and the lines that come in green.
# changes.jl says how the block is written. Each change has an Accept and a
# Reject button. Your choice is written at the end of the change's @@ line,
# so an agent that waits for the page reads it in the lines that you changed.
#
# Accept makes the change in the file that the diff names. A click on
# Accepted, or on Reject, takes the change out of the file again. A change
# that Ladder can't make, because its file has other lines now, keeps the
# choice that it had, and a line under its row says why.
#
# The lines have the colours of code in the language of their file. Where a
# line that comes is a new version of a line that goes, the words that are
# different have a darker mark. A line that's too long goes on under itself.
# Two buttons at the top choose how the lines show: the new lines under the
# old, or the old lines at the left and the new at the right. That choice is a
# setting, so every block of changes shows the same way.
#
# A click on a line opens a field under it, for what you say about that line.
# Your words are written at the end of the block as you type them, so the
# agent reads them with your choices. Return closes the field, and Esc puts
# back what the comment said before. A comment shows under its line. A click
# on it opens it again, and empty words take it away.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor rect with_clip
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./html" escape
@use "./markdown" words
@use "./highlight" tokens
@use "./sheet" parts shown folded
@use "./changes" => Diffs
@use Colors: RGBA
@use "./base" exports...
@use "./ask_view" exports...

export CHANGES, DIFF_ROW, DIFF_SIZE, BESIDE_LEAST, NOTE_ROW, NOTE_FIELD, ChangesView, HunkArea,
       note_input, noting!, stop_noting!, DiffText, DiffBand, DiffLayout, diff_face, hang,
       note_face, note_box, tally_words, short_path, change_words, decide!, change_file!, hatch,
       diff_side, changes_html, reload_changed!

const CHANGES = Diffs.CHANGES
const DIFF_ROW = 19.0        # px: how tall a line of a change is
const DIFF_SIZE = 12px       # how big the text of those lines is
const BESIDE_LEAST = 600.0   # px: the narrowest block that shows the old lines beside the new
const NOTE_ROW = 17.0        # px: how tall a line of a comment is
const NOTE_FIELD = 30.0      # px: how tall the field for a comment is
push!(BLOCK_ICONS, "file-diff", "check-lg", "x-lg", "view-stacked", "layout-split", "exclamation-triangle")

"What a `changes` block shows: each change of a diff, with buttons that accept it and reject it"
@def mutable struct ChangesView <: SemanticUI
  n::Int = 0                               # its place among the page's blocks of changes
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Diffs.Changes = Diffs.Changes(String[], Diffs.Hunk[])
  lines::Vector{String} = String[]         # the lines that `data` was read from
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons and the lines of each change, kept between frames
  laid::Dict{Any,Any} = Dict{Any,Any}()    # the lines of each change as they're drawn, kept until the block is read again
  noting::Union{Nothing,Tuple{Int,Int}} = nothing   # the line that you're writing a comment on: its change, and which of the change's lines
  before::String = ""                      # what that comment said when its field opened, for Esc to put back
  failed::Dict{Int,String} = Dict{Int,String}()   # why Ladder couldn't make a change in its file, or take it out, by the change's number
end

"The lines of one change"
@def mutable struct HunkArea <: SemanticUI
  of::Any = nothing
  k::Int = 0
  over::Int = 0   # the line of the change that the mouse is on, or 0
end

"The field for what you say about a line"
note_input(v::ChangesView) = block_part!(v, :note) do
  TextInput(placeholder="Say something about this line", font_family=SANS, font_size=12.5px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

reread!(v::ChangesView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Diffs.changes(lines)
  empty!(v.laid)
  # What went wrong was about the changes that the block had
  v.failed = Dict{Int,String}()
  v.noting === nothing && return v
  k, j = v.noting
  # The line that the field is under can go, when an agent writes the block again
  (k <= length(v.data.hunks) && j <= length(v.data.hunks[k].rows)) || return (v.noting = nothing; v)
  # The field shows what the block says, as it does after ⌘Z takes some of it back
  i = note_input(v)
  said = get(v.data.notes, (k, j), "")
  i.text == said || (i.text = said; i.anchor = i.cursor = length(said))
  v
end

"What happens to a block of changes in each frame, before the page is laid out: what was typed in its field is written into its block"
block_tick!(v::ChangesView) = begin
  v.noting === nothing && return v
  w = window_of(v)
  # A click somewhere else closes the field
  w !== nothing && w.focus !== note_input(v) && return stop_noting!(v)
  text = note_input(v).text
  text == get(v.data.notes, v.noting, "") && return v
  Diffs.note!(v.data, v.noting..., text)
  write_block!(v, CHANGES, Diffs.written(v.data), typing=true)
end

"Open the field under line `j` of change `k`, with what you said about the line in it"
noting!(v::ChangesView, k, j) = begin
  stop_noting!(v)
  i = note_input(v)
  i.text = get(v.data.notes, (k, j), "")
  i.anchor = i.cursor = length(i.text)
  v.noting, v.before = (k, j), i.text
  empty!(v.laid)
  focus(i)
  v
end

"Close the field. What was typed stays as the comment, without the spaces at its ends. Without `keep`, the comment says what it said before."
stop_noting!(v::ChangesView; keep=true) = begin
  v.noting === nothing && return v
  k, j = v.noting
  i = note_input(v)
  text = keep ? String(strip(i.text)) : v.before
  v.noting = nothing
  empty!(v.laid)
  w = window_of(v)
  w !== nothing && w.focus === i && focus(editor(v))
  text == get(v.data.notes, (k, j), "") && return v
  Diffs.note!(v.data, k, j, text)
  write_block!(v, CHANGES, Diffs.written(v.data), typing=keep)
end

"A line of a change, ready to draw"
struct DiffText
  chars::Vector{Char}
  xs::Vector{Float64}                           # how far across each character starts, and where the last one ends
  parts::Vector{Tuple{UnitRange{Int},Symbol}}   # the characters that have a colour of their own, and which colour
  marks::Vector{UnitRange{Int}}                 # the characters that the other version of the line doesn't have
  indent::Float64                               # how far across its first word starts
end

"""
One line across a change: the row that shows at each side, or 0, and the
characters of that row on each line of text. Or what you said about row
`note`, which shows under that row: `said` has its words, line by line, and
it's empty while the field for them is open.
"""
struct DiffBand
  top::Float64
  tall::Float64
  rows::NTuple{2,Int}
  lines::NTuple{2,Vector{UnitRange{Int}}}
  note::Int
  said::Vector{String}
end

DiffBand(top, tall, rows, lines) = DiffBand(top, tall, rows, lines, 0, String[])

"The lines of a change as they're drawn at one width. With `beside`, the old lines are at the left and the new at the right."
struct DiffLayout
  beside::Bool
  texts::Vector{DiffText}
  bands::Vector{DiffBand}
  digits::Float64   # how wide a column of line numbers is, or 0 when the change has none
  gutter::Float64   # the room for the numbers at the left of a side
  room::Float64     # how wide the text of a side can be
  tall::Float64
end

"The face of a line of a change"
diff_face(colour=colours.ink) = Face(codefont(), codestyle(), DIFF_SIZE, colour, false)

"How far in a line of a row starts when it isn't the row's first: as far as the row's first word, so the code keeps its shape"
hang(t::DiffText, room) = min(t.indent, room / 2)

"The characters of each line of text that the row `t` takes when it has `room` px across. It breaks after a space where it can."
folded(t::DiffText, room) = begin
  n = length(t.chars)
  out = UnitRange{Int}[]
  s = 1
  while s <= n
    space = isempty(out) ? room : room - hang(t, room)
    stop = s   # the last character that fits. A line holds one character at least.
    while stop < n && t.xs[stop+2] - t.xs[s] <= space
      stop += 1
    end
    if stop < n
      k = stop
      while k > s && !isspace(t.chars[k])
        k -= 1
      end
      k > s && !all(isspace, view(t.chars, s:k)) && (stop = k)
    end
    push!(out, s:stop)
    s = stop + 1
  end
  isempty(out) ? [1:0] : out
end

"How wide the lines of a change are in the block of `v`: as wide as the page's text, less the line at each edge of the block. What holds `v` can say otherwise."
diff_wide(v::ChangesView) = diff_wide(getfield(v, :parent), v)
diff_wide(_, v::ChangesView) = num(editor(v).width) - 2

"The face of a comment"
note_face() = Face(SANS, "", 12.5px, colours.ink, false)

"""
Where the box of a comment is across lines `wide` px wide, and how wide it is.
`sign` is of the row that the comment is on. With the old lines beside the
new, the comment on a line that goes is under the old lines, and any other is
under the new lines.
"""
note_box(beside, gutter, sign, wide) = begin
  half = floor(wide / 2)
  !beside ? (gutter, wide - gutter - 10) : sign == '-' ? (gutter, half - gutter - 10) : (half + gutter, wide - half - gutter - 10)
end

"True when the block of `v` shows the old lines beside the new, with lines `wide` px wide"
beside(v::ChangesView, wide=diff_wide(v)) = editor(v).beside && wide >= BESIDE_LEAST

"The lines of change `k` of `v`, laid out `wide` px wide"
laid(v::ChangesView, k, wide=diff_wide(v)) = get!(v.laid, (k, wide, beside(v, wide), codefont(), codestyle())) do
  h = v.data.hunks[k]
  face = diff_face()
  step = num(measure(face, "0"))
  shown(r) = replace(r.text, '\t' => "  ")
  other, marks = Diffs.matched(h; text=shown)
  lang = lowercase(lstrip(splitext(h.file)[2], '.'))
  texts = map(enumerate(h.rows)) do (j, r)
    chars = collect(shown(r))
    xs = zeros(length(chars) + 1)
    for (i, c) in enumerate(chars)
      xs[i+1] = xs[i] + (isascii(c) ? step : num(measure(face, string(c))))
    end
    parts = [(t.col+1:t.col+length(t.text), t.kind) for t in tokens(String(chars), lang) if !all(isspace, t.text)]
    word = findfirst(!isspace, chars)
    DiffText(chars, xs, parts, marks[j], word === nothing ? 0.0 : xs[word])
  end
  numbered = any(r -> r.old > 0 || r.new > 0, h.rows)
  digits = numbered ? num(measure(Face(face, size=10.5px), string(maximum(r -> max(r.old, r.new), h.rows)))) + 10 : 0.0
  two = beside(v, wide)
  gutter = !numbered ? 12.0 : two ? digits + 10 : 2digits + 10
  room = max((two ? floor(wide / 2) : wide) - gutter - 16 - 8, 12step)
  bands = DiffBand[]
  top = 0.0
  for (l, r) in (two ? Diffs.sides(h, other) : [(j, 0) for j in eachindex(h.rows)])
    lines = (l == 0 ? UnitRange{Int}[] : folded(texts[l], room), r == 0 ? UnitRange{Int}[] : folded(texts[r], room))
    tall = DIFF_ROW * max(length(lines[1]), length(lines[2]), 1)
    push!(bands, DiffBand(top, tall, (l, r), lines))
    top += tall
    # What you said about a row is under it, and so is the field for it
    for j in unique((l, r))
      j == 0 && continue
      said = v.noting == (k, j) ? String[] : haskey(v.data.notes, (k, j)) ?
             wrapped(note_face(), v.data.notes[(k, j)], note_box(two, gutter, h.rows[j].sign, wide)[2] - 20) : continue
      tall = isempty(said) ? NOTE_FIELD + 8 : NOTE_ROW * length(said) + 18
      push!(bands, DiffBand(top, tall, (0, 0), (UnitRange{Int}[], UnitRange{Int}[]), j, said))
      top += tall
    end
  end
  DiffLayout(two, texts, bands, digits, gutter, room, top)
end

"How many lines a change adds and takes away, as two small numbers"
tally_words(added, removed) =
  ((added > 0 ? (Box(label("+$(commas(added))", 12px, color=added_colour(), weight="Medium")),) : ())...,
   (removed > 0 ? (Box(label("−$(commas(removed))", 12px, color=removed_colour(), weight="Medium")),) : ())...)

"The end of a file's path that fits in `limit` characters, with … for the folders that it leaves out"
short_path(file, limit=44) = begin
  length(file) <= limit && return file
  parts = split(file, '/')
  k = length(parts)
  while k > 1 && sum(length, parts[k-1:end]) + length(parts) - k + 3 <= limit
    k -= 1
  end
  k == 1 ? file : "…/" * join(parts[k:end], '/')
end

"What the row over a change says: its file, and where the change is in it, like `app.js` and `lines 10 to 13`"
change_words(h) = begin
  place = Diffs.place(h)
  isempty(h.file) ? ("", place) : (short_path(h.file), lowercasefirst(place))
end

describe(v::ChangesView) = begin
  e = editor(v)
  c = v.data
  with_theme(component_theme(e.zoom)) do
    isempty(c.hunks) && return Column(block_look()..., clip=true, name="Changes",
      block_note("This block has no changes yet. Put a diff in it, as git diff writes one: a line that starts with @@, then the lines that go with a - before each, and the lines that come with a +."))
    all = length(c.hunks) > 1 ?
      (rule(), block_button!(v, :accept_all, (:all, :accepted), icon="check-lg", words="Accept all", tip="Make every change in its file"),
       block_button!(v, :reject_all, (:all, :rejected), icon="x-lg", words="Reject all", tip="Reject every change, and take the ones that you accepted out of their files")) : ()
    # The button of the way that the lines show now is lit. A block that's too narrow shows the new lines under the old.
    two = beside(v)
    narrow = diff_wide(v) < BESIDE_LEAST
    ways = (rule(), block_button!(v, :under, (:beside, false), icon="view-stacked", on=!two, tip="Show the new lines under the old lines"),
            block_button!(v, :beside, (:beside, true), icon="layout-split", on=two, off=narrow,
                          tip=narrow ? "The window is too narrow to show the old lines beside the new lines" : "Show the old lines beside the new lines"))
    bar = block_bar(Box(padding(6px, 0px), label(Diffs.summary(c), 12px, color=colours.dim)), Box(width(grow=grow)),
                    Row(child_gap=8px, padding(6px, 0px), tally_words(Diffs.counts(c)...)...), ways..., all...)
    rows = Any[]
    for (k, h) in enumerate(c.hunks)
      state = h.state
      file, place = change_words(h)
      name = isempty(h.file) ? "its file" : basename(h.file)
      push!(rows, Row(width(grow=grow), height(34px), padding(0px, 6px, 0px, 12px), child_gap=8px, Alignment.Center, clip=true,
                      border(1px, :solid, colours.line)[:top], background(colours.stripe),
        Row(child_gap=5px, (isempty(file) ? () : (Box(label(file, 12px, weight="Semibold")),))...,
            (isempty(place) ? () : (Box(label(place, 12px, color=colours.dim)),))...),
        Row(width(grow=grow), clip=true, Alignment.Start,
            Box(Text(h.about, size=11.5px, family=codefont(), subfamily=codestyle(), color=colours.faint, wrap=WrapMode.none))),
        tally_words(Diffs.counts(h)...)...,
        block_button!(v, (:accept, k), (:choose, k, :accepted), icon="check-lg", words=state == :accepted ? "Accepted" : "Accept",
                      on=state == :accepted, tip=state == :accepted ? "Take this change out of $name again" : "Make this change in $name"),
        block_button!(v, (:reject, k), (:choose, k, :rejected), icon="x-lg", words=state == :rejected ? "Rejected" : "Reject",
                      on=state == :rejected, tip=state == :rejected ? "Take your choice away" :
                                                 state == :accepted ? "Reject this change, and take it out of $name" : "Reject this change")))
      # Why Ladder couldn't change the file, under the row
      haskey(v.failed, k) && push!(rows, Row(width(grow=grow), padding(8px, 12px), child_gap=8px, Alignment.Start,
                                             border(1px, :solid, colours.line)[:top], background(RGBA(removed_colour(), 0.08)),
        Icon("exclamation-triangle", size=14px, color=removed_colour()),
        beside_mark(14px, Text(v.failed[k], size=12.5px, family=SANS, color=removed_colour(), wrap=WrapMode.words))))
      push!(rows, block_part!(() -> HunkArea(of=v, k=k), v, (:hunk, k)))
    end
    Column(block_look()..., clip=true, name="Changes", bar, rows...)
  end
end

cursor(::ChangesView) = :arrow
cursor(a::HunkArea) = a.over == 0 ? :arrow : :hand

# Return closes the field for a comment, and Esc puts back what the comment said before
onkey(v::ChangesView, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (v.noting === nothing ? nothing : (stop_noting!(v); handled)) : nothing
onkey(v::ChangesView, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (v.noting === nothing ? nothing : (stop_noting!(v, keep=false); handled)) : nothing

"The line of the change of `a` at the place `x`, `y` of the window: a row of the change or the comment on one. 0 when no line is there."
row_at(a::HunkArea, x, y) = begin
  v, r = a.of, rect(a)
  (r === nothing || a.k > length(v.data.hunks)) && return 0
  l = laid(v, a.k)
  dx, dy = x - num(r.left), y - num(r.top) - 4
  for band in l.bands
    band.top <= dy < band.top + band.tall || continue
    return band.note != 0 ? band.note : band.rows[l.beside && dx >= floor(num(r.width) / 2) ? 2 : 1]
  end
  0
end

onmouse(a::HunkArea, ev::MouseMove) = (a.over = readonly(editor(a.of).buf) ? 0 : row_at(a, num(ev.position[1]), num(ev.position[2])); nothing)

# A click on a line opens the field for what you say about it
onkey(a::HunkArea, ev::KeyPress{Keys.mouse_left}) = begin
  # With ⌥ held, the click is the page's, and it shows the block's lines
  (readonly(editor(a.of).buf) || only_held(a, Keys.opt)) && return nothing
  j = row_at(a, num(ev.window.mouse[1]), num(ev.window.mouse[2]))
  j == 0 ? stop_noting!(a.of) : a.of.noting == (a.k, j) || noting!(a.of, a.k, j)
  handled
end

act!(v::ChangesView, action, w) = begin
  action[1] == :beside && return (beside!(editor(v), action[2]); handled)
  action[1] == :unsay && return (note_input(v).text = ""; stop_noting!(v); handled)
  stop_noting!(v)
  readonly(editor(v).buf) && return handled
  empty!(v.failed)
  if action[1] == :choose
    k, state = action[2], action[3]
    # A click on the choice that a change has takes it away
    decide!(v, k, v.data.hunks[k].state == state ? :open : state)
  else
    foreach(k -> decide!(v, k, action[2]), eachindex(v.data.hunks))
  end
  failed = v.failed
  write_block!(v, CHANGES, Diffs.written(v.data))
  v.failed = failed   # reading the block again forgets them
  handled
end

"""
Give change `k` of `v` the choice `state`, and make its file agree: an
accepted change is in the file, and any other is not. When Ladder can't make
the change in the file, or take it out again, the change keeps the choice
that it had, and `v.failed` says why.
"""
decide!(v::ChangesView, k, state) = begin
  h = v.data.hunks[k]
  h.state == state && return v
  # A choice that's taken away from a rejected change changes no file
  h.state == :rejected && state == :open && return (h.state = state; v)
  back = state != :accepted
  why = change_file!(v, h; back)
  # A change that wasn't accepted is rejected whatever Ladder finds in its file. It's
  # there only when ⌘Z took the choice away after Ladder made it, and then it comes out.
  why === nothing || (back && h.state != :accepted) ? (h.state = state) : (v.failed[k] = why)
  v
end

"Make the change `h` of `v` in its file, or take it out again with `back`. The result is nothing, or words that say why Ladder couldn't."
change_file!(v::ChangesView, h; back=false) = begin
  isempty(h.file) && return "This change doesn't name its file, so Ladder can't make it. A diff names the file in a line that starts with +++, over the change."
  path = Diffs.located(h.file, dirname(abspath(editor(v).buf.path)))
  name = basename(h.file)
  was = isfile(path) ? text(path) : String[]
  done = try
    Diffs.apply!(path, h; back)
  catch err
    return "Ladder couldn't change $path. " * sprint(showerror, err)
  end
  # A file of code that Ladder loaded runs the code that changed, so what it draws is drawn the new way
  if done == :made
    mod = loaded_module(page_key(path))
    mod === nothing || reload_changed!(mod, page_key(path), was)
  end
  done in (:made, :already) ? nothing :
  done == :nofile ? "There's no file at $path, so Ladder didn't make this change." :
  done == :twice ? "The lines that this change takes away are in $name more than once, and the change has no line numbers to say which. Ladder didn't change the file." :
  back ? "The lines that this change put in $name aren't there now, so Ladder didn't change the file." :
         "The lines that this change takes away aren't in $name now, so Ladder didn't change the file."
end

"Show the old lines of every block of changes beside the new lines, or the new lines under the old"
beside!(e, on::Bool) = (e.beside = on; rewrap!(e))   # the line under the mouse stays where it is

describe(a::HunkArea) = begin
  v = a.of
  a.k <= length(v.data.hunks) || return Box(width(grow=grow), height(0px))
  l = laid(v, a.k)
  at = v.noting === nothing || v.noting[1] != a.k ? nothing : findfirst(b -> b.note == v.noting[2], l.bands)
  at === nothing && return Box(width(grow=grow), height(px(l.tall + 8)))
  # The field for a comment is where the comment's box will be. The lines round it are drawn over this.
  band = l.bands[at]
  wide = diff_wide(v)
  x, w = note_box(l.beside, l.gutter, v.data.hunks[a.k].rows[band.note].sign, wide)
  input = note_input(v)
  input.color = colours.ink
  win = window_of(v)
  Column(width(grow=grow), height(px(l.tall + 8)), Alignment.Start,
    Box(height(px(band.top + 8))),
    Row(width(grow=grow), height(px(NOTE_FIELD)), padding(0px, px(wide - x - w), 0px, px(x)), child_gap=4px, Alignment.Center,
      Box(width(grow=grow), height(px(NOTE_FIELD)), padding(9px, 0px), radius(6px), background(colours.bg),
          border(1px, :solid, win !== nothing && win.focus === input ? colours.accent : colours.line), input),
      block_button!(v, :unsay, (:unsay,), icon="trash", tip="Delete this comment")))
end

"Fill a box with slanted lines: the side of a change that has no line. The lines of one box go on in the box under it."
hatch(ctx, x, y, w, h, above) = begin
  shape = Skia.sk_path_new()
  gap = 6.0
  # Each line goes up to the right. `c` is how far across it would cross the top of the change's lines.
  for c in (floor((y - above) / gap) * gap):gap:(w + y + h - above)
    Skia.sk_path_move_to(shape, Float32(x + c - (y + h - above)), Float32(y + h))
    Skia.sk_path_line_to(shape, Float32(x + c - (y - above)), Float32(y))
  end
  paint = ink(RGBA(colours.ink, 0.09), 1.0)
  with_clip(ctx, px(x), px(y), px(w), px(h)) do
    Skia.sk_canvas_draw_path(ctx, shape, paint)
  end
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(shape)
end

"""
Draw one side of a line across a change, `wide` px wide with its top left at
`x` and `y`: the row's number, its sign and its text, on the colour of a line
that goes or comes. A change that's rejected is `pale`.
"""
diff_side(ctx, l::DiffLayout, h, band::DiffBand, side, x, y, wide, pale, above) = begin
  j = band.rows[side]
  j == 0 && return hatch(ctx, x, y, wide, band.tall, above)
  r, t = h.rows[j], l.texts[j]
  # A line that stays shows at both sides, with its old number at the left and its new one at the right
  colour = r.sign == '+' ? added_colour() : r.sign == '-' ? removed_colour() : nothing
  colour === nothing || round_box(ctx, x, y, wide, band.tall, 0; fill=RGBA(colour, pale ? 0.05 : 0.13))
  small = Face(diff_face(colour === nothing || pale ? colours.faint : colour), size=10.5px)
  for (i, number) in enumerate(l.beside ? (side == 1 ? r.old : r.new,) : (r.old, r.new))
    number > 0 && write_ink(ctx, string(number), x + 6 + i * l.digits - num(measure(small, string(number))), y + 13.5, small)
  end
  code = diff_face(pale ? colours.faint : colours.ink)
  colour === nothing || write_ink(ctx, r.sign == '-' ? "−" : "+", x + l.gutter, y + 13.5, Face(code, color=pale ? colours.faint : colour))
  for (n, span) in enumerate(band.lines[side])
    isempty(span) && continue
    top = y + (n - 1) * DIFF_ROW
    from = x + l.gutter + 16 + (n > 1 ? hang(t, l.room) : 0.0) - t.xs[first(span)]   # where the row's first character would be
    if colour !== nothing && !pale
      # The words that the other version of the line doesn't have
      for m in t.marks
        lo, hi = max(first(m), first(span)), min(last(m), last(span))
        lo <= hi && round_box(ctx, from + t.xs[lo] - 1, top + 2, t.xs[hi+1] - t.xs[lo] + 2, DIFF_ROW - 4, 3; fill=RGBA(colour, 0.24))
      end
    end
    for (chars, kind) in t.parts
      lo, hi = max(first(chars), first(span)), min(last(chars), last(span))
      lo <= hi || continue
      face = pale || kind == :plain ? code : Face(code, color=getfield(colours, kind), style=kind == :comment ? codeslant() : code.style)
      write_ink(ctx, String(t.chars[lo:hi]), from + t.xs[lo], top + 13.5, face)
    end
  end
end

draw(ctx, size, ui::ConcreteRect, a::HunkArea) = begin
  hunks = a.of.data.hunks
  a.k <= length(hunks) || return
  h = hunks[a.k]
  left, top, wide = num(ui.left), num(ui.top) + 4, num(ui.width)
  l = laid(a.of, a.k, wide)
  half = floor(wide / 2)
  # A change that's rejected is pale
  pale = h.state == :rejected
  over = ishovered(a) ? a.over : 0
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    for band in l.bands
      y = top + band.top
      if band.note != 0
        # What you said about the row over this, in a box. While its field is open, the field is here.
        isempty(band.said) && continue
        x, w = note_box(l.beside, l.gutter, h.rows[band.note].sign, wide)
        round_box(ctx, left + x, y + 4, w, band.tall - 8, 6; fill=colours.bg, line=over == band.note ? colours.accent : colours.line)
        for (n, words) in enumerate(band.said)
          write_ink(ctx, words, left + x + 10, y + 9 + n * NOTE_ROW - 4.5, Face(note_face(), color=pale ? colours.dim : colours.ink))
        end
        continue
      end
      if over != 0 && over in band.rows && !haskey(a.of.data.notes, (a.k, over)) && a.of.noting != (a.k, over)
        # A mark at the end of the line that the mouse is on says that a click adds a comment
        right = !l.beside || band.rows[2] == over ? left + wide : left + half
        mark = Face(SANS, "Semibold", 13px, colours.bg, false)
        round_box(ctx, right - 24, y + 2, 16, 15, 4; fill=colours.accent)
        write_ink(ctx, "+", right - 16 - num(measure(mark, "+")) / 2, y + 14, mark)
      end
      if l.beside
        diff_side(ctx, l, h, band, 1, left, y, half, pale, top)
        diff_side(ctx, l, h, band, 2, left + half, y, wide - half, pale, top)
      else
        diff_side(ctx, l, h, band, 1, left, y, wide, pale, top)
      end
    end
    l.beside && round_box(ctx, left + half, num(ui.top), 1, num(ui.height), 0; fill=colours.line)
    # A change that's accepted has a green edge
    h.state == :accepted && round_box(ctx, left, num(ui.top), 3, num(ui.height), 0; fill=added_colour())
  end
end

"The changes as HTML: each one with its file, where it is and your choice, its lines, and what you said about them"
changes_html(e, v::ChangesView) = begin
  c = v.data
  isempty(c.hunks) && return nothing
  parts = map(enumerate(c.hunks)) do (k, h)
    about = join(filter(!isempty, [h.file, Diffs.place(h), h.state == :open ? "" : uppercasefirst(string(h.state))]), " · ")
    lines = map(h.rows) do r
      text = escape((r.sign == ' ' ? "  " : r.sign == '-' ? "− " : "+ ") * r.text)
      r.sign == '+' ? "<span style=\"background: #e2f2dc; display: block\">$text</span>" :
      r.sign == '-' ? "<span style=\"background: #f8dfda; display: block\">$text</span>" : "<span style=\"display: block\">$text</span>"
    end
    # What you said about a line is under the change, with the line
    said = join("\n<blockquote><code>$(escape(h.rows[j].sign * h.rows[j].text))</code><br>$(escape(c.notes[(k, j)]))</blockquote>"
                for j in eachindex(h.rows) if haskey(c.notes, (k, j)))
    "<p><strong>$(escape(about))</strong></p>\n<pre><code>" * join(lines) * "</code></pre>" * said
  end
  join(parts, "\n")
end

BLOCKS[CHANGES] = ChangesView
block_name(::Type{ChangesView}) = "Changes"
block_icon(::Type{ChangesView}) = "file-diff"
block_html(e, v::ChangesView) = changes_html(e, v)

"""
Run each part of the code of the file at `file` that's new since the file had
the lines `before`, in the module `mod` that the file made. So a function
that was changed in the file is changed in the app that runs, and every
window draws again. It gives how many parts ran, and what went wrong with the
first that failed, or "".
"""
reload_changed!(mod::Module, file::AbstractString, before::Vector{String}) = begin
  was = Set(t for (_, t) in part_texts(before))
  ran, failed = 0, ""
  for (first, code) in part_texts(text(file))
    (code in was || isempty(strip(code))) && continue
    try
      # Blank lines before the code give each of its lines the number that it has in the file
      Base.include_string(mod, "\n"^(first - 1) * code, String(file))
      ran += 1
    catch err
      isempty(failed) && (failed = trouble(err))
    end
  end
  ran > 0 && (CODE_RUNS[] += 1; redraw_windows!())   # the checks of a page or a file run again
  (ran, failed)
end

# Code that Ladder never ran has no module to run in. The file changes, and that's all.
reload_changed!(::Nothing, file::AbstractString, before::Vector{String}) = (0, "")
