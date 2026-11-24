# A terminal in a window: what shows a terminal's screen, and gives the keys
# and the mouse to the program that runs in it.
#
#     v = TerminalView(path="work.vt", wide=800px, high=600px)
#
# `path` is a file that keeps what the terminal shows, as `saved` of screen.jl
# writes it. The view shows what the file has. A file with nothing in it gets a
# shell at once, in the folder that the file is in. A file with text shows it,
# with a line under it that says Return starts a shell, so that only looking at
# a file runs nothing and changes nothing. While a shell runs, what it writes
# goes into the file a moment after it comes. `dir` is another folder to start
# the shell in, and `command` another program to run.
#
# With a program running, the keys are the program's: letters, Return, the
# arrows, Control with a letter, and the rest. These are the view's own:
#
#   ⌘C  copies the text that's selected       ⌘V  pastes
#   ⌘A  selects everything                    ⌘K  forgets the lines above the cursor's
#   ⇧PageUp ⇧PageDown ⇧Home ⇧End  go back through the lines that scrolled away
#
# Any other key with ⌘ is the app's. The wheel goes back through the lines
# that scrolled away too. A drag selects text, two clicks a word and three a
# line. A program that asks for the mouse, as vim does, gets the clicks and
# the wheel, and ⇧ held with them keeps them for the view.
#
# The app sets `wide`, `high`, `size`, the font and the colours on each frame,
# and `wake`, a function that makes the window draw: the program's output is
# read on another thread, which calls it. `tick!` takes what the program wrote
# when the view isn't shown. `close!` ends the program and writes the file.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" onkey onmouse ontype onscroll KeyPress KeyRelease MouseMove Typed Keys flt
@use "github.com/jkroso/MiniFB.jl/skia" fontmgr
@use "github.com/jkroso/Font.jl/units" px
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific" ConcreteRect
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe handled window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" draw cursor rect redraw_in! MouseScroll clipboard clipboard! with_clip
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font
@use Colors: RGBA
@use Skia
@use "./screen" => Screens
@use "./screen" Terminal Cell Line feed! answers! saved restore! settle!
@use "./pty" => Ptys

const PAD = 10.0          # px between the edges of the view and its cells
const WHEEL = 30.0        # px that one step of the wheel scrolls
const SAVE_AFTER = 2.0    # seconds from when a program writes until the file has it
const AGAIN_CLICK = 0.4   # seconds between two clicks at one cell that make them a double click
const MOST_FILE = 64_000_000   # bytes. A longer file isn't read: it's no terminal's.
const PIECE = 32_000      # bytes of a program's output that are read at a time
const READ_FOR = 0.008    # seconds of a frame that go to reading what a program wrote. What's left waits for the next frame.
const MOST_UNREAD = 1_000_000   # bytes that wait to be read before more is taken from the program, which then waits too

"The program that a view starts when it names none. While this is empty, that's the person's shell. A test puts a shell here that reads no settings."
const USUAL = Ref(String[])

# The 16 colours that programs name by number, for a dark back and for a light one. An app gives its own.
const DARK = UInt32[0x1d1f21, 0xcc6666, 0xb5bd68, 0xf0c674, 0x81a2be, 0xb294bb, 0x8abeb7, 0xc5c8c6,
                    0x666666, 0xd54e53, 0xb9ca4a, 0xe7c547, 0x7aa6da, 0xc397d8, 0x70c0b1, 0xeaeaea]
const LIGHT = UInt32[0x24292e, 0xc82829, 0x4d7a00, 0xa67400, 0x4271ae, 0x8959a8, 0x2a8a90, 0x6a737d,
                     0x959da5, 0xb31d28, 0x22863a, 0x8a6400, 0x005cc5, 0x6f42c1, 0x1b7c83, 0xd1d5da]

@def mutable struct TerminalView <: SemanticUI
  path::String = ""               # the file that keeps what the terminal shows, or "" for none
  dir::String = ""                # the folder that a program starts in: the file's, if this is ""
  command::Vector{String} = String[]   # the program: the person's shell, if this is empty
  wide::px = 800px
  high::px = 600px
  size::Float64 = 13.0            # of the text, in px
  family::String = "Menlo"
  style::String = ""
  ink::UInt32 = 0x00c5c8c6        # the text, as red, green and blue
  paper::UInt32 = 0x001d1f21      # what's behind it
  dim::UInt32 = 0x00808080        # the line that says how to start a shell
  select::UInt32 = 0x4d4285f4     # over the text that's selected. Its first byte is how solid it is.
  palette::Vector{UInt32} = DARK
  wake::Any = () -> nothing
  shown::Bool = false             # only show the file: no program starts, and the keys do nothing
  term::Any = nothing             # the Terminal
  shell::Any = nothing            # the program that runs, or nothing
  fresh::Bool = false             # the file had nothing in it, so a shell starts when the view first shows
  ran::Bool = false               # a program ran in the view and ended
  status::Union{Int,Nothing} = nothing   # the number that it ended with
  unread::Vector{UInt8} = UInt8[] # what the program wrote and the terminal hasn't read yet
  read::Int = 0                   # how many of those bytes it has read
  dirty::Bool = false             # the program wrote something that the file doesn't have
  due::Float64 = 0.0              # when the file is written
  back::Int = 0                   # how many lines back in the past the view is
  wheel::Float64 = 0.0            # the part of a line that the wheel has gone and the view hasn't
  anchor::Union{Nothing,Tuple{Int,Int}} = nothing   # where the selection started and where it ends: a line's number
  head::Union{Nothing,Tuple{Int,Int}} = nothing     #   and a cell's. The number counts the lines that the past lost too.
  drag::Symbol = :none            # what a drag selects by, :cells, :words or :lines, or :program while the program hears the mouse
  began::Tuple{Tuple{Int,Int},Tuple{Int,Int}} = ((0, 0), (0, 0))   # the word or the line that a drag by words or by lines started on
  clicked::Tuple{Float64,Int,Int,Int} = (0.0, 0, 0, 0)   # when the button last went down, on which line and cell, and how many times
  told::Tuple{Int,Int} = (0, 0)   # the cell that the program last heard the mouse was on
  seen::Float64 = 0.0             # when the view was last shown
  woke::Float64 = 0.0             # when the window was last asked to draw
  had::Bool = false               # the view had the keyboard when it was last shown
end

# --- the font -------------------------------------------------------------------------------

"A font at a size, with the glyph that it has for each of the first 128 characters"
struct Fount
  raw::Any
  glyphs::Vector{UInt16}
end

const founts = Dict{Tuple{String,String,Float32},Fount}()
const cell_sizes = Dict{Tuple{String,String,Float32},NTuple{3,Float64}}()
const stand_ins = Dict{Char,Any}()                    # the face that has a character that the view's font lacks
const stand_in_fonts = Dict{Tuple{Any,Float32},Any}()

# A built app starts with what these held while it was built, and the fonts that they point at aren't there any more
__init__() = (empty!(founts); empty!(cell_sizes); empty!(stand_ins); empty!(stand_in_fonts); nothing)

fount(family, style, size) = get!(founts, (String(family), String(style), Float32(size))) do
  raw = skia_font(family, px(size), style).raw
  Fount(raw, UInt16[Skia.sk_font_unichar_to_glyph(raw, Int32(c)) for c in 0:127])
end

"The font of a cell with the style `flags`"
fount(v::TerminalView, flags::UInt16=0x0000) = begin
  bold, italic = flags & Screens.BOLD != 0, flags & Screens.ITALIC != 0
  fount(v.family, bold && italic ? "Bold Italic" : bold ? "Bold" : italic ? String(strip(v.style * " Italic")) : v.style, v.size)
end

"How wide and how tall a cell is, and how far under its top the letters stand, in px. Each is a whole number of the pixels of a Retina screen, so the cells have sharp edges."
cell(v::TerminalView) = get!(cell_sizes, (v.family, v.style, Float32(v.size))) do
  raw = fount(v).raw
  m = Ref{Skia.sk_font_metrics_t}()
  Skia.sk_font_get_metrics(raw, m)
  wide = Skia.sk_font_measure_text(raw, pointer("M"), UInt64(1), Skia.SK_TEXT_ENCODING_UTF8, C_NULL, C_NULL)
  (max(1.0, round(2wide) / 2), max(1.0, ceil(2 * (m[].descent - m[].ascent + m[].leading)) / 2), round(2 * (m[].leading / 2 - m[].ascent)) / 2)
end

"The font that draws `c`: `f` when it has the character, or else a font of this Mac that has it"
font_for(v::TerminalView, f::Fount, c::Char) = begin
  Skia.sk_font_unichar_to_glyph(f.raw, Int32(c)) != 0 && return f.raw
  face = get!(stand_ins, c) do
    st = Skia.sk_fontstyle_new(Int32(400), Int32(Skia.SK_FONT_STYLE_WIDTH_NORMAL), Skia.SK_FONT_STYLE_SLANT_UPRIGHT)
    found = Skia.sk_fontmgr_match_family_style_character(fontmgr[], v.family, st, C_NULL, Int32(0), Int32(c))
    Skia.sk_fontstyle_delete(st)
    found
  end
  face == C_NULL && return f.raw
  get!(() -> Skia.sk_font_new_with_values(face, Float32(v.size), 1f0, 0f0), stand_in_fonts, (face, Float32(v.size)))
end

# --- the terminal and its program -----------------------------------------------------------

"The line under the cells, or nothing: it says how to start a shell while none runs"
hint(v::TerminalView) = begin
  (v.shown || running(v)) && return nothing
  if !v.ran
    # A path that's too long for the view is cut to the folder's name
    words = "Press Return to start a shell in "
    room = floor(Int, (Float64(flt(v.wide)) - 2PAD) / cell(v)[1]) - length(words)
    return words * (length(short(folder(v))) <= room ? short(folder(v)) : basename(folder(v)))
  end
  "The shell ended" * (v.status in (0, nothing) ? "" : " with status $(v.status)") * ". Press Return to start another."
end

"A path with ~ for the home folder"
short(path) = (home = homedir(); path == home ? "~" : startswith(path, home * "/") ? "~" * path[length(home)+1:end] : path)

"The folder that a program of the view starts in"
folder(v::TerminalView) = !isempty(v.dir) ? v.dir : !isempty(v.path) ? dirname(abspath(v.path)) : homedir()

"How many lines and how many cells fit in the view"
grid(v::TerminalView) = begin
  cw, ch, _ = cell(v)
  under = hint(v) === nothing ? 0.0 : ch + PAD / 2
  (max(1, floor(Int, (Float64(flt(v.high)) - 2PAD - under) / ch)), max(2, floor(Int, (Float64(flt(v.wide)) - 2PAD) / cw)))
end

"The Terminal of the view. It's made when it's first asked for, with what the file has."
terminal(v::TerminalView) = begin
  v.term === nothing || return v.term
  rows, cols = grid(v)
  t = Terminal(rows, cols, ink=v.ink, paper=v.paper)
  bytes = try isfile(v.path) && filesize(v.path) <= MOST_FILE ? read(v.path) : UInt8[] catch; UInt8[] end
  isempty(bytes) ? (v.fresh = !v.shown) : restore!(t, bytes)
  v.term = t
end

running(v::TerminalView) = v.shell !== nothing

"Start the view's program: the person's shell, in the folder that the file is in"
start!(v::TerminalView) = begin
  (running(v) || v.shown) && return v
  t = terminal(v)
  v.fresh = false
  rows, cols = grid_running(v)
  resize!(t, rows, cols)
  command = !isempty(v.command) ? v.command : !isempty(USUAL[]) ? USUAL[] : Ptys.shell()
  v.shell = Ptys.start(command; dir=folder(v), rows, cols, wake=() -> wake!(v))
  v.back = 0
  unselect!(v)
  redraw_in!(v, 0)
  v
end

# The size once a program runs: the line that says how to start one is gone then
grid_running(v::TerminalView) = begin
  cw, ch, _ = cell(v)
  (max(1, floor(Int, (Float64(flt(v.high)) - 2PAD) / ch)), max(2, floor(Int, (Float64(flt(v.wide)) - 2PAD) / cw)))
end

"Ask the window to draw, since the program wrote something. While nothing shows the view, that's asked only twice a second."
wake!(v::TerminalView) = begin
  now = time()
  (now - v.seen < 0.25 || now - v.woke > 0.5) || return
  v.woke = now
  v.wake()
  nothing
end

"""
Take what the program wrote since the last time, and write the file when it's
time to. The view does this each time it shows. An app calls it for a view
that isn't shown, so that its program doesn't wait.
"""
tick!(v::TerminalView) = begin
  s, t = v.shell, v.term
  s === nothing && return v
  # A program that writes a lot, like one that prints a long file, is read a part in each frame, so that the window
  # stays yours meanwhile
  length(v.unread) - v.read < MOST_UNREAD && append!(v.unread, take!(s))
  if v.read < length(v.unread)
    before = length(t.past) + t.gone
    began = time()
    while v.read < length(v.unread) && time() - began < READ_FOR
      to = min(v.read + PIECE, length(v.unread))
      feed!(t, @view v.unread[v.read+1:to])
      v.read = to
    end
    # What's left is read in the next frame, which comes at once while the view shows
    v.read == length(v.unread) ? (empty!(v.unread); v.read = 0) : redraw_in!(v, time() - v.seen < 0.25 ? 0 : 0.2)
    # A view that's back in the past stays on the lines that it shows
    v.back > 0 && (v.back = min(v.back + length(t.past) + t.gone - before, length(t.past)))
    said = answers!(t)
    isempty(said) || Ptys.send!(s, said)
    v.dirty || (v.due = time() + SAVE_AFTER)
    v.dirty = true
  end
  if Ptys.done(s) && isempty(v.unread)
    v.status, v.shell, v.ran = Ptys.status(s), nothing, true
    Ptys.stop!(s)
    settle!(t)
    v.dirty = true
    save!(v)
  elseif v.dirty && time() >= v.due
    save!(v)
  end
  v
end

"Write the file, if the program wrote something that it doesn't have"
save!(v::TerminalView) = begin
  (v.dirty && v.term !== nothing && !isempty(v.path)) || return v
  v.dirty = false
  # A file that can't be written, like one in a folder that's only read, stays as it is
  try write(v.path, saved(v.term)) catch end
  v
end

"End the view's program and write the file. An app calls this when the window closes."
close!(v::TerminalView) = begin
  s = v.shell
  if s !== nothing
    v.term === nothing || (feed!(v.term, @view v.unread[v.read+1:end]); feed!(v.term, take!(s)); v.dirty = true)
    empty!(v.unread)
    v.read = 0
    Ptys.stop!(s)
    v.shell, v.ran = nothing, true
    v.term === nothing || settle!(v.term)
  end
  save!(v)
end

"Send bytes to the program, as typing does. The view shows the newest lines again."
type!(v::TerminalView, bytes) = begin
  (running(v) && !isempty(bytes)) || return v
  Ptys.send!(v.shell, bytes)
  v.back = 0
  unselect!(v)
  v
end

# --- what shows -----------------------------------------------------------------------------

focused(v::TerminalView) = (w = window_of(v); w !== nothing && w.focus === v)

colour(c::UInt32) = RGBA(((c >> 16) & 0xff) / 255, ((c >> 8) & 0xff) / 255, (c & 0xff) / 255, 1.0)

describe(v::TerminalView) = begin
  t = terminal(v)
  v.seen = time()
  t.ink, t.paper = v.ink, v.paper
  v.fresh && start!(v)
  tick!(v)
  rows, cols = grid(v)
  if (rows, cols) != (t.rows, t.cols)
    resize!(t, rows, cols)
    running(v) && resize!(v.shell, rows, cols)
    unselect!(v)   # the lines are laid out again, so the places of the selection are no longer its own
  end
  v.back = clamp(v.back, 0, length(t.past))
  # A view that only shows a file has no cursor to keep on the screen, so it shows the file's last lines in all its room
  v.shown && (v.back = min(length(t.past), t.rows - something(findlast(!Screens.isblank, t.lines), 0)))
  # A program that asked to hear about the keyboard is told when the view gets it and loses it
  has = focused(v)
  has == v.had || (v.had = has; running(v) && Ptys.send!(v.shell, Screens.focus(t, has)))
  edge_scroll!(v)
  v.dirty && redraw_in!(v, max(0.05, v.due - time()))
  # What a program writes wakes the window. Should a wake be lost, the window still looks twice a second.
  running(v) && redraw_in!(v, 0.5)
  Box(width(v.wide), height(v.high), background(colour(v.paper)))
end

"The colour of a cell's character and the colour behind it, as red, green and blue"
colours(v::TerminalView, c::Cell) = begin
  fg, bg = named(v, c.fg, v.ink), named(v, c.bg, v.paper)
  c.flags & Screens.INVERSE != 0 && ((fg, bg) = (bg, fg))
  c.flags & Screens.FAINT != 0 && (fg = between(fg, bg))
  c.flags & Screens.HIDDEN != 0 && (fg = bg)
  (fg, bg)
end

named(v::TerminalView, c::UInt32, own::UInt32) =
  c == 0 ? own & 0x00ffffff :
  c & Screens.DIRECT != 0 ? c & 0x00ffffff :
  (n = c & 0xff; n < 16 ? v.palette[n+1] & 0x00ffffff : Screens.colour256(n))

"The colour halfway between two"
between(a::UInt32, b::UInt32) = begin
  mid(shift) = (((a >> shift) & 0xff) + ((b >> shift) & 0xff)) >> 1
  mid(16) << 16 | mid(8) << 8 | mid(0)
end

solid(c::UInt32) = 0xff000000 | c

"Fill a rectangle of the canvas with a colour whose first byte is how solid it is"
patch(ctx, paint, x, y, w, h, colour::UInt32) = begin
  Skia.sk_paint_set_color(paint, colour)
  Skia.sk_canvas_draw_rect(ctx, Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h))), paint)
end

"Draw the glyphs `ids` of a font at the places `xs`, on the line whose letters stand at `y`"
glyphs!(ctx, paint, font, ids::Vector{UInt16}, xs::Vector{Float32}, y) = begin
  n = length(ids)
  n == 0 && return
  builder = Skia.sk_textblob_builder_new()
  run = unsafe_load(Skia.sk_textblob_builder_alloc_run_pos_h(builder, font, Cint(n), 0f0, C_NULL))
  GC.@preserve ids xs begin
    unsafe_copyto!(run.glyphs, pointer(ids), n)
    unsafe_copyto!(run.pos, pointer(xs), n)
  end
  blob = Skia.sk_textblob_builder_make(builder)
  Skia.sk_textblob_builder_delete(builder)
  Skia.sk_canvas_draw_text_blob(ctx, blob, 0f0, Float32(y), paint)
  Skia.sk_textblob_unref(blob)
  nothing
end

"Draw the character of one cell, with its accents, in the colour `fg`"
character!(ctx, paint, v::TerminalView, t, c::Cell, x, y, fg::UInt32) = begin
  words = Screens.shown(t, c)
  font = font_for(v, fount(v, c.flags), c.ch)
  Skia.sk_paint_set_color(paint, solid(fg))
  GC.@preserve words Skia.sk_canvas_draw_simple_text(ctx, pointer(words), Csize_t(ncodeunits(words)), Skia.SK_TEXT_ENCODING_UTF8, Float32(x), Float32(y), font, paint)
  nothing
end

# The characters that draw boxes are drawn here and not by a font, so that the lines of one cell meet the lines of the
# next, whatever the font and the height of a line. Each has four arms from the middle of its cell: to the left, to
# the right, up and down. An arm is 0 for none, 1 for a light line, 2 for a heavy one and 3 for a double one. The
# characters with dashes are drawn as lines.
const ARMS = "1100220000110022110022000011002211002200001100220101020101020202" *   # ─ to ┏
             "1001200110022002011002100120022010102010102020200111021101210112" *   # ┐ to ┟
             "0122022102120222101120111021101210222021201220221101210112012201" *   # ┠ to ┯
             "1102210212022202111021101210221011202120122022201111211112112211" *   # ┰ to ┿
             "1121111211222121122121121212222122122122122222221100220000110022" *   # ╀ to ╏
             "3300003303010103030330011003300303100130033030101030303003110133" *   # ═ to ╟
             "0333301110333033330111033303331011303330331111333333010110011010" *   # ╠ to ╯
             "0110000000000000100000100100000120000020020000021200001221000021"     # ╰ to ╿

"The four arms of the box character `c`: left, right, up and down"
arms(c::Char) = (k = 4 * (Int(c) - 0x2500); ntuple(i -> Int(ARMS[k+i] - '0'), 4))

# The quarters of a cell that each of ▖ to ▟ fills: upper left 1, upper right 2, lower left 4, lower right 8
const QUARTERS = (4, 8, 1, 13, 9, 7, 11, 2, 6, 14)

"""
Draw the arm of a box character on one `side` of its cell, `wide` across: from
the edge of the cell to the middle `(cx, cy)`, and `past` further, or with a
negative `past` that much short of it.
"""
arm!(ctx, paint, side, x, y, cw, ch, cx, cy, wide, past, colour) =
  side == 1 ? patch(ctx, paint, x, cy - wide / 2, cx + past - x, wide, colour) :
  side == 2 ? patch(ctx, paint, cx - past, cy - wide / 2, x + cw - cx + past, wide, colour) :
  side == 3 ? patch(ctx, paint, cx - wide / 2, y, wide, cy + past - y, colour) :
              patch(ctx, paint, cx - wide / 2, cy - past, wide, y + ch - cy + past, colour)

"""
Draw a box character that has a double line. A double arm is a line three
times as wide with the colour behind the cell down its middle, so its two
lines turn a corner and meet a crossing line as they should.
"""
doubles!(ctx, paint, sides, x, y, cw, ch, cx, cy, thin, fg::UInt32, bg::UInt32) = begin
  crossing(i) = i <= 2 ? (sides[3], sides[4]) : (sides[1], sides[2])
  opposite(i) = sides[i + (isodd(i) ? 1 : -1)]
  for i in 1:4
    sides[i] == 3 || continue
    a, b = crossing(i)
    arm!(ctx, paint, i, x, y, cw, ch, cx, cy, 3thin, 3 in (a, b) ? 1.5thin : a + b > 0 ? thin / 2 : 0.0, solid(fg))
  end
  for i in 1:4
    sides[i] == 3 || continue
    arm!(ctx, paint, i, x, y, cw, ch, cx, cy, thin, 3 in crossing(i) ? thin / 2 : opposite(i) == 3 ? 0.0 : -thin / 2, solid(bg))
  end
  for i in 1:4
    sides[i] == 1 || continue
    a, b = crossing(i)
    # A light arm goes through a crossing, stops at the near line of a double line that goes on both ways, and goes
    # to the far line of one that turns away
    past = opposite(i) > 0 ? 0.0 : a == b == 3 ? -thin / 2 : 3 in (a, b) ? 1.5thin : thin / 2
    arm!(ctx, paint, i, x, y, cw, ch, cx, cy, thin, past, solid(fg))
  end
  true
end

"""
Draw the character `c` in the cell at `(x, y)` if it's one that draws boxes or
blocks, U+2500 to U+259F. It's true when it was drawn, and false for any
other character, which a font draws. `bg` is the colour behind the cell.
"""
box!(ctx, paint, c::Char, x, y, cw, ch, fg::UInt32, bg::UInt32, size) = begin
  '\u2500' <= c <= '\u259f' || return false
  thin = max(1.0, round(size / 13))
  mx, my = x + floor(2 * (cw - thin) / 2) / 2, y + floor(2 * (ch - thin) / 2) / 2   # the top left of a thin line through the middle
  if c >= '\u2580'
    return blocks!(ctx, paint, c, x, y, cw, ch, fg)
  elseif '\u256d' <= c <= '\u2570'
    # A round corner: a line from one edge to another that turns through a quarter of a circle
    right, down = c in "╭╰", c in "╭╮"
    cx, cy = mx + thin / 2, my + thin / 2
    r = min(cw, ch) / 2
    shape = Skia.sk_path_new()
    Skia.sk_path_move_to(shape, Float32(cx), Float32(down ? y + ch : y))
    Skia.sk_path_line_to(shape, Float32(cx), Float32(down ? cy + r : cy - r))
    Skia.sk_path_quad_to(shape, Float32(cx), Float32(cy), Float32(right ? cx + r : cx - r), Float32(cy))
    Skia.sk_path_line_to(shape, Float32(right ? x + cw : x), Float32(cy))
    stroke!(ctx, paint, shape, fg, thin)
    return true
  elseif '\u2571' <= c <= '\u2573'
    shape = Skia.sk_path_new()
    if c != '╲'
      Skia.sk_path_move_to(shape, Float32(x), Float32(y + ch))
      Skia.sk_path_line_to(shape, Float32(x + cw), Float32(y))
    end
    if c != '╱'
      Skia.sk_path_move_to(shape, Float32(x), Float32(y))
      Skia.sk_path_line_to(shape, Float32(x + cw), Float32(y + ch))
    end
    stroke!(ctx, paint, shape, fg, thin)
    return true
  end
  l, r, u, d = arms(c)
  3 in (l, r, u, d) && return doubles!(ctx, paint, (l, r, u, d), x, y, cw, ch, mx + thin / 2, my + thin / 2, thin, fg, bg)
  thick(k) = k * thin
  # Each arm goes from its edge to the far side of the lines that cross it, so a corner has no notch
  across, along = thick(max(u, d)), thick(max(l, r))
  l > 0 && patch(ctx, paint, x, my - (thick(l) - thin) / 2, mx - x + (thin + across) / 2, thick(l), solid(fg))
  r > 0 && patch(ctx, paint, mx + (thin - across) / 2, my - (thick(r) - thin) / 2, x + cw - mx - (thin - across) / 2, thick(r), solid(fg))
  u > 0 && patch(ctx, paint, mx - (thick(u) - thin) / 2, y, thick(u), my - y + (thin + along) / 2, solid(fg))
  d > 0 && patch(ctx, paint, mx - (thick(d) - thin) / 2, my + (thin - along) / 2, thick(d), y + ch - my - (thin - along) / 2, solid(fg))
  true
end

"Draw the line `shape`, `wide` across, in the colour `fg`, and free it"
stroke!(ctx, paint, shape, fg::UInt32, wide) = begin
  Skia.sk_paint_set_color(paint, solid(fg))
  Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
  Skia.sk_paint_set_stroke_width(paint, Float32(wide))
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(0))
  Skia.sk_path_delete(shape)
  nothing
end

"Draw a block character, U+2580 to U+259F: a part of the cell that's filled"
blocks!(ctx, paint, c::Char, x, y, cw, ch, fg::UInt32) = begin
  k = Int(c) - 0x2580
  full = solid(fg)
  if k == 0
    patch(ctx, paint, x, y, cw, ch / 2, full)                              # ▀
  elseif k <= 8
    patch(ctx, paint, x, y + ch * (8 - k) / 8, cw, ch * k / 8, full)       # ▁ to █
  elseif k <= 15
    patch(ctx, paint, x, y, cw * (16 - k) / 8, ch, full)                   # ▉ to ▏
  elseif k == 16
    patch(ctx, paint, x + cw / 2, y, cw / 2, ch, full)                     # ▐
  elseif k <= 19
    patch(ctx, paint, x, y, cw, ch, UInt32(64 * (k - 16)) << 24 | fg)      # ░ ▒ ▓
  elseif k == 20
    patch(ctx, paint, x, y, cw, ch / 8, full)                              # ▔
  elseif k == 21
    patch(ctx, paint, x + cw * 7 / 8, y, cw / 8, ch, full)                 # ▕
  else
    q = QUARTERS[k-21]
    q & 1 != 0 && patch(ctx, paint, x, y, cw / 2, ch / 2, full)
    q & 2 != 0 && patch(ctx, paint, x + cw / 2, y, cw / 2, ch / 2, full)
    q & 4 != 0 && patch(ctx, paint, x, y + ch / 2, cw / 2, ch / 2, full)
    q & 8 != 0 && patch(ctx, paint, x + cw / 2, y + ch / 2, cw / 2, ch / 2, full)
  end
  true
end

"The first and the last cell that's selected in the line numbered `id`, or nothing"
picked(v::TerminalView, id::Int) = begin
  (v.anchor === nothing || v.head === nothing || v.anchor == v.head) && return nothing
  a, b = minmax(v.anchor, v.head)
  a[1] <= id <= b[1] || return nothing
  from = id == a[1] ? a[2] : 1
  to = id == b[1] ? b[2] - 1 : typemax(Int)
  from <= to ? (from, to) : nothing
end

const LINED = Screens.UNDERLINE | Screens.STRIKE
const LOOKS = Screens.BOLD | Screens.ITALIC | LINED

"Draw one line of cells with its top left corner at `(x0, y)`"
line!(ctx, paint, v::TerminalView, t, l::Line, x0, y, id, ids, xs) = begin
  cw, ch, base = cell(v)
  row = l.cells
  n = min(length(row), t.cols)
  paper = v.paper & 0x00ffffff
  # What's behind the cells, a run of one colour at a time
  i = 1
  while i <= n
    bg = colours(v, row[i])[2]
    j = i
    while j < n && colours(v, row[j+1])[2] == bg
      j += 1
    end
    bg == paper || patch(ctx, paint, x0 + (i - 1) * cw, y, (j - i + 1) * cw, ch, solid(bg))
    i = j + 1
  end
  sel = picked(v, id)
  if sel !== nothing
    from, to = sel[1], min(sel[2], t.cols)
    from <= to && patch(ctx, paint, x0 + (from - 1) * cw, y, (to - from + 1) * cw, ch, v.select)
  end
  # The characters, a run of one font and one colour at a time
  i = 1
  while i <= n
    c = row[i]
    if c.flags & Screens.TAIL != 0 || (c.ch == ' ' && c.mark == 0 && c.flags & LINED == 0)
      i += 1
      continue
    end
    fg, bg = colours(v, c)
    look = c.flags & LOOKS
    j = i
    if isascii(c.ch) && c.mark == 0
      f = fount(v, c.flags)
      empty!(ids)
      empty!(xs)
      while j <= n
        d = row[j]
        (isascii(d.ch) && d.mark == 0 && d.flags & LOOKS == look && d.flags & Screens.TAIL == 0 && colours(v, d)[1] == fg) || break
        d.ch == ' ' || (push!(ids, f.glyphs[Int(d.ch)+1]); push!(xs, Float32(x0 + (j - 1) * cw)))
        j += 1
      end
      Skia.sk_paint_set_color(paint, solid(fg))
      glyphs!(ctx, paint, f.raw, ids, xs, y + base)
    else
      box!(ctx, paint, c.ch, x0 + (i - 1) * cw, y, cw, ch, fg, bg, v.size) || character!(ctx, paint, v, t, c, x0 + (i - 1) * cw, y + base, fg)
      j = i + 1
    end
    if look & LINED != 0
      thick = max(1.0, round(v.size / 13))
      look & Screens.UNDERLINE != 0 && patch(ctx, paint, x0 + (i - 1) * cw, y + base + 2, (j - i) * cw, thick, solid(fg))
      look & Screens.STRIKE != 0 && patch(ctx, paint, x0 + (i - 1) * cw, y + base - round(v.size * 0.3), (j - i) * cw, thick, solid(fg))
    end
    i = j
  end
  nothing
end

draw(ctx, size, ui::ConcreteRect, v::TerminalView) = begin
  t = v.term
  t === nothing && return
  cw, ch, base = cell(v)
  left, top = Float64(flt(ui.left)), Float64(flt(ui.top))
  wide, high = Float64(flt(ui.width)), Float64(flt(ui.height))
  x0, y0 = left + PAD, top + PAD
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  ids, xs = UInt16[], Float32[]
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    past = length(t.past)
    for r in 1:t.rows
      k = past - v.back + r
      l = Screens.line(t, k)
      l === nothing || line!(ctx, paint, v, t, l, x0, y0 + (r - 1) * ch, t.gone + k, ids, xs)
    end
    # The cursor shows on the newest lines, while a program runs that hasn't hidden it
    row = t.row + v.back
    if running(v) && t.shows && row <= t.rows
      x, y = x0 + (t.col - 1) * cw, y0 + (row - 1) * ch
      c = t.lines[t.row].cells[t.col]
      c.flags & Screens.TAIL != 0 && t.col > 1 && (c = t.lines[t.row].cells[t.col-1]; x -= cw)
      across = c.flags & Screens.WIDE != 0 ? 2cw : cw
      ink = solid(v.ink & 0x00ffffff)
      if !focused(v)
        # A view without the keyboard has the outline of the cursor
        patch(ctx, paint, x, y, across, 1, ink)
        patch(ctx, paint, x, y + ch - 1, across, 1, ink)
        patch(ctx, paint, x, y, 1, ch, ink)
        patch(ctx, paint, x + across - 1, y, 1, ch, ink)
      elseif t.shape in (3, 4)
        patch(ctx, paint, x, y + ch - 2, across, 2, ink)
      elseif t.shape in (5, 6)
        patch(ctx, paint, x, y, 2, ch, ink)
      else
        patch(ctx, paint, x, y, across, ch, ink)
        c.ch == ' ' && c.mark == 0 || character!(ctx, paint, v, t, c, x, y + base, v.paper & 0x00ffffff)
      end
    end
    words = hint(v)
    if words !== nothing
      Skia.sk_paint_set_color(paint, solid(v.dim & 0x00ffffff))
      GC.@preserve words Skia.sk_canvas_draw_simple_text(ctx, pointer(words), Csize_t(ncodeunits(words)), Skia.SK_TEXT_ENCODING_UTF8,
                                                         Float32(x0), Float32(top + high - PAD - ch + base), fount(v).raw, paint)
    end
    # A bar at the right says where the view is in the past
    if v.back > 0 && !v.shown
      all = past + t.rows
      tall = max(24.0, high * t.rows / all)
      at = (high - tall) * (past - v.back) / max(past, 1)
      patch(ctx, paint, left + wide - 7, top + at + 2, 4, tall - 4, 0x59000000 | (v.ink & 0x00ffffff))
    end
  end
  Skia.sk_paint_delete(paint)
  nothing
end

# --- the selection --------------------------------------------------------------------------

unselect!(v::TerminalView) = (v.anchor = v.head = nothing; v.drag in (:cells, :words, :lines) && (v.drag = :none); v)

"The text that's selected, or \"\""
selected(v::TerminalView) = begin
  t = v.term
  (t === nothing || v.anchor === nothing || v.head === nothing || v.anchor == v.head) && return ""
  a, b = minmax(v.anchor, v.head)
  # A line that the past has lost since it was selected isn't there to copy
  here(p) = p[1] - t.gone < 1 ? (1, 1) : (p[1] - t.gone, p[2])
  Screens.words(t, here(a), here(b))
end

select_all!(v::TerminalView) = begin
  t = terminal(v)
  v.anchor, v.head = (t.gone + 1, 1), (t.gone + Screens.height(t), t.cols + 1)
  redraw_in!(v, 0)
  v
end

"Copy the text that's selected to the clipboard. It's false when none is."
copy!(v::TerminalView, w) = (words = selected(v); isempty(words) ? false : (clipboard!(w, words); true))

"""
Where a place of the window is in the cells: the line of the screen and the
cell that it's over, and the gap between two cells that it's nearest to,
which is 1 before the first cell. The line and the cell can be past the edges.
"""
cell_at(v::TerminalView, at) = begin
  r = rect(v)
  r === nothing && return nothing
  cw, ch, _ = cell(v)
  x, y = Float64(flt(at[1] - r.left)) - PAD, Float64(flt(at[2] - r.top)) - PAD
  (floor(Int, y / ch) + 1, floor(Int, x / cw) + 1, round(Int, x / cw) + 1)
end

"The number of the line that shows in line `row` of the view"
line_id(v::TerminalView, row) = (t = v.term; t.gone + length(t.past) - v.back + clamp(row, 1, t.rows))

"Make the selection reach the place `at` of the cells, by cells, words or lines as the drag started"
extend!(v::TerminalView, at) = begin
  t = v.term
  row, col, gap = at
  id = line_id(v, row)
  if v.drag == :cells
    v.head = (id, row < 1 ? 1 : row > t.rows ? t.cols + 1 : clamp(gap, 1, t.cols + 1))
  elseif v.drag in (:words, :lines)
    a, b = v.began
    col = clamp(col, 1, t.cols)
    from, to = v.drag == :lines ? (1, t.cols) : Screens.word_at(t, id - t.gone, col)
    (id, col) < a ? ((v.anchor, v.head) = (b, (id, from))) :
    (id, col) >= b ? ((v.anchor, v.head) = (a, (id, to + 1))) : ((v.anchor, v.head) = (a, b))
  end
  redraw_in!(v, 0)
  v
end

"While a drag that selects has the mouse above or below the cells, the view goes that way through the lines"
edge_scroll!(v::TerminalView) = begin
  v.drag in (:cells, :words, :lines) || return
  w = window_of(v)
  w === nothing && return
  Keys.mouse_left in w.keys || return (v.drag = :none; nothing)
  at = cell_at(v, w.mouse)
  at === nothing && return
  step = at[1] < 1 ? 1 : at[1] > v.term.rows ? -1 : 0
  step == 0 && return
  v.back = clamp(v.back + step, 0, length(v.term.past))
  extend!(v, at)
  redraw_in!(v, 0.03)
  nothing
end

# --- the mouse ------------------------------------------------------------------------------

const HELD = Keys.ctrl | Keys.cmd | Keys.opt | Keys.shft
held_keys(w) = w.keys & HELD

"The keys that are held, as the program is told of them"
held_code(w) = (Keys.shft in w.keys ? Screens.SHIFT : 0) | (Keys.opt in w.keys ? Screens.ALT : 0) | (Keys.ctrl in w.keys ? Screens.CTRL : 0)

"True when the program gets the mouse: it asked for it, and ⇧ isn't held to keep the mouse for the view"
hears_mouse(v::TerminalView, w) = running(v) && v.term.tracks != :none && !(Keys.shft in w.keys)

cursor(v::TerminalView) = (w = window_of(v); v.shown || (w !== nothing && hears_mouse(v, w)) ? :arrow : :ibeam)

"Tell the program of the mouse: `what` is :press, :release or :move"
tell!(v::TerminalView, w, what, button, at) = begin
  t = v.term
  row, col = clamp(at[1], 1, t.rows), clamp(at[2], 1, t.cols)
  v.told = (row, col)
  Ptys.send!(v.shell, Screens.mouse(t, what, button, row, col, held_code(w)))
  nothing
end

onkey(v::TerminalView, ev::KeyPress{Keys.mouse_left}) = begin
  v.shown && return nothing
  w = ev.window
  focus(v)
  t = terminal(v)
  at = cell_at(v, w.mouse)
  at === nothing && return handled
  if hears_mouse(v, w)
    v.drag = :program
    tell!(v, w, :press, 0, at)
    return handled
  end
  row, col, gap = at
  id = line_id(v, row)
  col, gap = clamp(col, 1, t.cols), clamp(gap, 1, t.cols + 1)
  now = time()
  times = now - v.clicked[1] < AGAIN_CLICK && v.clicked[2:3] == (id, col) ? v.clicked[4] % 3 + 1 : 1
  v.clicked = (now, id, col, times)
  if times == 1
    # ⇧ and a click makes the selection reach the click
    held_keys(w) == Keys.shft && v.anchor !== nothing ? (v.head = (id, gap)) : (v.anchor = v.head = (id, gap))
    v.drag = :cells
  else
    from, to = times == 3 ? (1, t.cols) : Screens.word_at(t, id - t.gone, col)
    v.anchor, v.head = (id, from), (id, to + 1)
    v.began = (v.anchor, v.head)
    v.drag = times == 3 ? :lines : :words
  end
  redraw_in!(v, 0)
  handled
end

onkey(v::TerminalView, ev::KeyRelease{Keys.mouse_left}) = begin
  v.shown && return nothing
  if v.drag == :program && running(v)
    at = cell_at(v, ev.window.mouse)
    at === nothing || tell!(v, ev.window, :release, 0, at)
  end
  v.drag = :none
  handled
end

onmouse(v::TerminalView, ev::MouseMove) = begin
  (v.shown || v.term === nothing) && return nothing
  w = ev.window
  at = cell_at(v, ev.position)
  at === nothing && return nothing
  down = Keys.mouse_left in w.keys
  if v.drag == :program || (v.drag == :none && hears_mouse(v, w) && !down)
    # The program hears a move only when the mouse comes to another cell
    running(v) && (clamp(at[1], 1, v.term.rows), clamp(at[2], 1, v.term.cols)) != v.told && tell!(v, w, :move, down ? 0 : 3, at)
  elseif down && v.drag != :none
    extend!(v, at)
  end
  handled
end

onscroll(v::TerminalView, ev::MouseScroll) = begin
  v.shown && return nothing
  w = ev.window
  held = held_keys(w)
  (held == Keys(0) || held == Keys.shft) || return nothing   # the wheel with ⌘ is the app's
  t = terminal(v)
  _, ch, _ = cell(v)
  gone = v.wheel + Float64(flt(ev.delta[2])) * WHEEL / ch
  lines = trunc(Int, gone)
  v.wheel = gone - lines
  lines == 0 && return handled
  if hears_mouse(v, w)
    at = something(cell_at(v, w.mouse), (1, 1, 1))
    foreach(_ -> tell!(v, w, :press, lines > 0 ? 64 : 65, at), 1:min(abs(lines), 5))
  elseif running(v) && t.second
    # A program on the second screen, like a pager, has no past to go back in: it gets the arrow keys
    Ptys.send!(v.shell, Screens.key(t, lines > 0 ? :up : :down)^min(abs(lines), 10))
  else
    v.back = clamp(v.back + lines, 0, length(t.past))
  end
  redraw_in!(v, 0)
  handled
end

# --- the keys -------------------------------------------------------------------------------

# The keys that send the program a code, by the name that `Screens.key` knows them by
const NAMES = Dict{Keys,Symbol}(Keys.enter => :enter, Keys.tab => :tab, Keys.backspace => :backspace, Keys.escape => :escape,
                                Keys.up => :up, Keys.down => :down, Keys.left => :left, Keys.right => :right,
                                Keys.home => :home, Keys._end => :end, Keys.pageup => :pageup, Keys.pagedown => :pagedown,
                                Keys.insert => :insert, Keys.delete => :delete,
                                (getproperty(Keys, Symbol(:f, n)) => Symbol(:f, n) for n in 1:12)...)

# The character of each key that sends something with Control held
const CHARS = Dict{Keys,Char}((getproperty(Keys, Symbol(c)) => c for c in 'a':'z')...,
                              (getproperty(Keys, Symbol(d)) => Char('0' + d) for d in 2:8)...,
                              Keys.space => ' ', Keys.left_bracket => '[', Keys.right_bracket => ']', Keys.backslash => '\\',
                              Keys.slash => '/', Keys.minus => '-')

"Go `lines` back through the lines that scrolled away, or on with a negative number"
back!(v::TerminalView, lines) = (v.back = clamp(v.back + lines, 0, length(terminal(v).past)); redraw_in!(v, 0); v)

"What a key that moves does to a view that goes through its lines: true when it's such a key"
scroll_key!(v::TerminalView, name) = begin
  t = terminal(v)
  name == :pageup ? back!(v, t.rows - 1) :
  name == :pagedown ? back!(v, 1 - t.rows) :
  name == :home ? back!(v, length(t.past)) :
  name == :end ? back!(v, -length(t.past)) :
  name == :up ? back!(v, 1) :
  name == :down ? back!(v, -1) : return false
  true
end

onkey(v::TerminalView, ev::KeyPress{K}) where K = begin
  v.shown && return nothing
  w = ev.window
  # The right button has no menu here, and the other buttons are the app's
  K == Keys.mouse_right && return handled
  K in (Keys.mouse_middle, Keys.mouse_back, Keys.mouse_forward) && return nothing
  # A key that's held with others sends nothing itself
  K in (Keys.cmd, Keys.shft, Keys.opt, Keys.ctrl, Keys.capslock, Keys.fn) && return nothing
  held = held_keys(w)
  t = terminal(v)
  if Keys.cmd in w.keys
    # With ⌘ and no other key held, four keys are the view's. Any other key with ⌘ is the app's.
    held == Keys.cmd || return nothing
    K == Keys.c && return copy!(v, w) ? handled : nothing
    K == Keys.v && return (type!(v, Screens.paste(t, clipboard(w))); handled)
    K == Keys.a && return (select_all!(v); handled)
    K == Keys.k && return (Screens.clear!(t); v.back = 0; unselect!(v); v.dirty = running(v); redraw_in!(v, 0); handled)
    return nothing
  end
  name = get(NAMES, K, nothing)
  if !running(v)
    # With no program, Return starts the shell, and the keys that move go through the lines
    K == Keys.enter && held == Keys(0) && return (start!(v); handled)
    held == Keys(0) && name !== nothing && scroll_key!(v, name)
    return handled
  end
  # ⇧ with a key that moves by pages goes through the lines that scrolled away. A program on the second screen has none.
  held == Keys.shft && !t.second && name in (:pageup, :pagedown, :home, :end) && return (scroll_key!(v, name); handled)
  bytes = if name !== nothing
    Screens.key(t, name, held_code(w))
  elseif Keys.ctrl in w.keys
    c = get(CHARS, K, nothing)
    b = c === nothing ? nothing : Screens.control(c)
    b === nothing ? "" : (Keys.opt in w.keys ? "\e" : "") * b
  else
    ""   # a key that types comes as its character: see `ontype`
  end
  type!(v, bytes)
  handled
end

# A key that types comes as its character, so each keyboard types its own letters, and ⌥ makes the characters that it
# makes everywhere on a Mac. Control with a key was sent when the key went down.
ontype(v::TerminalView, ev::Typed) = begin
  v.shown && return nothing
  c = ev.char
  (iscntrl(c) || '' <= c <= '' || Keys.ctrl in ev.window.keys) && return handled
  type!(v, string(c))
  handled
end

export TerminalView
