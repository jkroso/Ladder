# A terminal's screen, with no window and no program: the characters that a
# program wrote, where a terminal shows them.
#
#     t = Terminal(24, 80)
#     feed!(t, "\e[1;31mred\e[m and plain\r\n")   # what a program wrote
#     words(t)                                    # "red and plain"
#     t.lines[1].cells[1]                         # the r: its character, colours and style
#     answers!(t)                                 # what the terminal says back, to give to the program
#     resize!(t, 30, 100)
#     saved(t)                                    # text that makes the same lines again in another terminal
#
# What a program writes is text with escape codes in it, as an xterm reads
# them: codes that move the cursor, colour the text, erase, scroll a part of
# the screen, and switch to a second screen that a program like vim draws on.
# `feed!` takes the bytes as they come, cut anywhere.
#
# The screen is `rows` lines of `cols` cells. A line that scrolls off the top
# goes to `past`, which keeps the last `most` of them. A line whose text was
# too long for the width is `wrapped`: it goes on in the next line. `resize!`
# to another width lays such text out again, so no word is lost.
#
# `saved` writes the past and the screen as text with only colour and style
# codes, one line of text for each line that the program wrote, however it was
# wrapped. Kero writes its `.vt` files the same way. `restore!` reads such a
# file back.
#
# `key`, `control`, `mouse`, `paste` and `focus` give the bytes that a
# terminal sends a program for what the person does.

@use "github.com/jkroso/Prospects.jl" @def

# A cell's style, one bit each. A character that's two cells wide, like 界, is a WIDE cell and then a TAIL cell.
const BOLD = 0x0001
const FAINT = 0x0002
const ITALIC = 0x0004
const UNDERLINE = 0x0008
const INVERSE = 0x0010
const HIDDEN = 0x0020
const STRIKE = 0x0040
const WIDE = 0x0080
const TAIL = 0x0100
const STYLES = BOLD | FAINT | ITALIC | UNDERLINE | INVERSE | HIDDEN | STRIKE

# A colour is 0 for the terminal's own, or one of the 256 numbered colours, or a colour by its red, green and blue
const NUMBERED = 0x01000000
const DIRECT = 0x02000000
numbered(n) = NUMBERED | UInt32(clamp(n, 0, 255))
direct(r, g, b) = DIRECT | UInt32(clamp(r, 0, 255)) << 16 | UInt32(clamp(g, 0, 255)) << 8 | UInt32(clamp(b, 0, 255))

"One place of the screen: its character, its colours and its style. `mark` is the number of the accents that go on the character, in the terminal's `marks`, or 0."
struct Cell
  ch::Char
  fg::UInt32
  bg::UInt32
  flags::UInt16
  mark::UInt16
end

const BLANK = Cell(' ', 0x00000000, 0x00000000, 0x0000, 0x0000)
blank(bg::UInt32) = Cell(' ', 0x00000000, bg, 0x0000, 0x0000)
isblank(c::Cell) = c.ch == ' ' && c.bg == 0 && c.flags & (INVERSE | UNDERLINE | STRIKE | TAIL) == 0 && c.mark == 0

"A line of cells. A `wrapped` line goes on in the next one: its text was too long for the width."
mutable struct Line
  cells::Vector{Cell}
  wrapped::Bool
end
Line(cols::Integer, bg::UInt32=0x00000000) = Line(fill(blank(bg), cols), false)

"How many cells of a line are in use: all but the blanks at its end"
used(cells::Vector{Cell}) = something(findlast(!isblank, cells), 0)
isblank(l::Line) = used(l.cells) == 0

"What the code that keeps the cursor keeps: where it is and how it writes"
struct Kept
  row::Int
  col::Int
  fg::UInt32
  bg::UInt32
  flags::UInt16
  origin::Bool
  drawing::Tuple{Bool,Bool}
  shifted::Bool
end

# What the reader of the bytes is in the middle of
const GROUND = 0    # text
const ESCAPE = 1    # after ESC
const CSI = 2       # after ESC [, until a letter ends the code
const OSC = 3       # after ESC ], until BEL or ESC \ ends the words
const STRING = 4    # words for the terminal that this one doesn't read, until ESC \ ends them

@def mutable struct Terminal
  rows::Int = 24
  cols::Int = 80
  lines::Vector{Line} = Line[]    # the screen, from its top line
  past::Vector{Line} = Line[]     # the lines that scrolled off the top, the oldest first
  most::Int = 10_000              # how many lines of the past are kept
  gone::Int = 0                   # how many lines the past has lost, so a line can be named by a number that stays its own
  held::Vector{Line} = Line[]     # the first screen, while a program draws on the second
  second::Bool = false            # true while the second screen shows, as vim's does
  # The cursor, and the colours and the style that it writes with
  row::Int = 1
  col::Int = 1
  pending::Bool = false           # the cursor wrote in the last cell, and the next character starts the next line
  fg::UInt32 = 0x00000000
  bg::UInt32 = 0x00000000
  flags::UInt16 = 0x0000
  kept::Union{Kept,Nothing} = nothing
  top::Int = 1                    # the first and the last line of the part of the screen that scrolls
  bottom::Int = 24
  tabs::BitVector = falses(0)
  drawing::Tuple{Bool,Bool} = (false, false)   # the two sets of characters: true for the one that draws lines
  shifted::Bool = false                        # the second of them is in use
  last::Char = ' '                # the last character written, for the code that writes it again
  # What a program asked for
  wrap::Bool = true               # text that's too long goes on in the next line
  origin::Bool = false            # the cursor's lines count from the top of the part that scrolls
  insert::Bool = false            # a character pushes the ones after it along
  app_cursor::Bool = false        # the arrow keys send the codes of an app, not of a shell
  app_keypad::Bool = false
  bracketed::Bool = false         # pasted text comes between two codes, so the program can tell it from typing
  shows::Bool = true              # the cursor shows
  shape::Int = 0                  # of the cursor: 0 to 2 a block, 3 and 4 a line under, 5 and 6 a bar
  tracks::Symbol = :none          # the mouse: :press for its buttons, :drag for moves with a button down too, :any for every move
  sgr_mouse::Bool = false         # the mouse's places are written as numbers, so they can be past column 223
  focus::Bool = false             # the program hears when the terminal gets and loses the keyboard
  title::String = ""
  folder::String = ""             # the folder that the shell says it's in
  bells::Int = 0
  # The colours that the terminal's own text and back have, for a program that asks
  ink::UInt32 = 0x00000000
  paper::UInt32 = 0x00ffffff
  # The reader
  state::Int = GROUND
  seq::Vector{UInt8} = UInt8[]    # the bytes of the code that's being read
  text::Vector{UInt8} = UInt8[]   # the words of an OSC code
  esc::Bool = false               # the last byte of the words was ESC
  left::Vector{UInt8} = UInt8[]   # the start of a character whose other bytes haven't come
  params::Vector{Int} = Int[]
  joined::Vector{Bool} = Bool[]   # true for a number that a colon joins to the one before
  reply::IOBuffer = IOBuffer()
  answering::Bool = true          # false while a saved file is read: nothing is there to answer
  marks::Vector{String} = String[]
  mark_ids::Dict{String,Int} = Dict{String,Int}()
  changed::Int = 0                # goes up each time bytes are read
end

"A terminal with a blank screen of `rows` lines and `cols` cells"
Terminal(rows::Integer, cols::Integer; kw...) = begin
  t = Terminal(; rows=max(rows, 1), cols=max(cols, 1), kw...)
  t.lines = [Line(t.cols) for _ in 1:t.rows]
  t.bottom = t.rows
  t.tabs = stops(t.cols)
  t
end

"A stop every 8 cells, where a tab goes to"
stops(cols) = BitVector(k > 1 && k % 8 == 1 for k in 1:cols)

"Say `words` back to the program"
reply!(t::Terminal, words) = (t.answering && write(t.reply, words); nothing)

"What the terminal said back to the program since this was last asked"
answers!(t::Terminal) = String(take!(t.reply))

# --- reading --------------------------------------------------------------------------------

feed!(t::Terminal, words::AbstractString) = feed!(t, Vector{UInt8}(codeunits(words)))

"Read what a program wrote. The bytes can stop anywhere, even inside a character or a code: the rest comes with the next call."
feed!(t::Terminal, bytes::AbstractVector{UInt8}) = begin
  data = bytes
  if !isempty(t.left)
    data = vcat(t.left, bytes)
    empty!(t.left)
  end
  i, n = 1, length(data)
  @inbounds while i <= n
    b = data[i]
    if t.state == GROUND && b >= 0x20 && b != 0x7f
      if b < 0x80
        char!(t, Char(b))
        i += 1
      else
        size = b >= 0xf0 ? 4 : b >= 0xe0 ? 3 : b >= 0xc0 ? 2 : 1
        # A character whose last bytes haven't come waits for them
        if i + size - 1 > n && all(k -> data[k] & 0xc0 == 0x80, i+1:n)
          append!(t.left, @view data[i:n])
          break
        end
        c, took = character(data, i, size)
        char!(t, c)
        i += took
      end
    else
      byte!(t, b)
      i += 1
    end
  end
  t.changed += 1
  t
end

"The character whose first byte is at `i` and which says it has `size` bytes, and how many bytes it took. Bytes that are no character give �."
character(data, i, size) = begin
  b = data[i]
  (size == 1 || b >= 0xf8) && return ('�', 1)
  code = UInt32(b & (0xff >> (size + 1)))
  for k in i+1:i+size-1
    (k <= length(data) && data[k] & 0xc0 == 0x80) || return ('�', 1)
    code = code << 6 | (data[k] & 0x3f)
  end
  (code > 0x10ffff || 0xd800 <= code <= 0xdfff) && return ('�', size)
  (Char(code), size)
end

"Read a byte that isn't text: a control character, or a byte of a code"
byte!(t::Terminal, b::UInt8) = begin
  s = t.state
  (s == OSC || s == STRING) && return string_byte!(t, b)
  if b == 0x1b
    t.state = ESCAPE
    empty!(t.seq)
  elseif b < 0x20
    control!(t, b)
  elseif b >= 0x7f
    # a byte that no code has
  elseif s == ESCAPE
    b <= 0x2f ? push!(t.seq, b) : escape!(t, b)
  elseif s == CSI
    if b >= 0x40
      t.state = GROUND
      csi!(t, b)
    elseif length(t.seq) < 256
      push!(t.seq, b)
    end
  end
  nothing
end

"Read a byte of the words that a code holds, like the window's title"
string_byte!(t::Terminal, b::UInt8) = begin
  if t.esc
    t.esc = false
    b == UInt8('\\') && return finish_string!(t, "\e\\")
    # ESC and anything else starts a new code, and the words are lost
    t.state = ESCAPE
    empty!(t.seq)
    return byte!(t, b)
  end
  if b == 0x1b
    t.esc = true
  elseif b == 0x07 && t.state == OSC
    finish_string!(t, "\a")
  elseif b == 0x18 || b == 0x1a
    t.state = GROUND
  elseif t.state == OSC && length(t.text) < 4096
    push!(t.text, b)
  end
  nothing
end

finish_string!(t::Terminal, ending) = begin
  t.state == OSC && osc!(t, ending)
  t.state = GROUND
  nothing
end

"Do what a control character says"
control!(t::Terminal, b::UInt8) = begin
  if b == 0x0a || b == 0x0b || b == 0x0c
    linefeed!(t)
  elseif b == 0x0d
    t.col, t.pending = 1, false
  elseif b == 0x08
    t.col, t.pending = max(1, t.col - 1), false
  elseif b == 0x09
    tab!(t, 1)
  elseif b == 0x07
    t.bells += 1
  elseif b == 0x0e
    t.shifted = true
  elseif b == 0x0f
    t.shifted = false
  end
  nothing
end

"Go on `n` tab stops, or back with a negative `n`"
tab!(t::Terminal, n) = begin
  t.pending = false
  for _ in 1:abs(n)
    if n > 0
      t.col = something(findnext(t.tabs, min(t.col + 1, t.cols)), t.cols)
      t.col > t.cols && (t.col = t.cols)
    else
      t.col = t.col <= 1 ? 1 : something(findprev(t.tabs, t.col - 1), 1)
    end
  end
  t
end

# The characters that the line-drawing set has in place of ` to ~
const DRAWN = collect("◆▒␉␌␍␊°±␤␋┘┐┌└┼⎺⎻─⎼⎽├┤┴┬│≤≥π≠£·")

"How many cells a character takes: 2 for one like 界 or an emoji, 0 for an accent that goes on the character before"
cells_of(c::Char) = isascii(c) ? 1 : clamp(Base.Unicode.textwidth(c), 0, 2)

"Write a character at the cursor"
char!(t::Terminal, c::Char) = begin
  t.drawing[t.shifted ? 2 : 1] && '`' <= c <= '~' && (c = DRAWN[c - '`' + 1])
  w = cells_of(c)
  w == 0 && return mark!(t, c)
  if t.pending
    t.pending = false
    if t.wrap
      t.lines[t.row].wrapped = true
      index!(t)
      t.col = 1
    end
  end
  if w == 2 && t.col >= t.cols
    # A wide character with one cell left starts the next line
    (t.wrap && t.cols > 1) || return t
    t.lines[t.row].cells[t.col] = blank(t.bg)
    t.lines[t.row].wrapped = true
    index!(t)
    t.col = 1
  end
  cells = t.lines[t.row].cells
  col = t.col
  if t.insert
    for k in t.cols:-1:col+w
      cells[k] = cells[k-w]
    end
  end
  split!(cells, col)
  w == 2 && split!(cells, col + 1)
  cells[col] = Cell(c, t.fg, t.bg, t.flags | (w == 2 ? WIDE : 0x0000), 0x0000)
  w == 2 && (cells[col+1] = Cell(' ', t.fg, t.bg, t.flags | TAIL, 0x0000))
  t.last = c
  if col + w > t.cols
    t.col, t.pending = t.cols, t.wrap
  else
    t.col = col + w
  end
  t
end

"Before cell `k` is written over: a wide character that has one of its two cells there loses the other too"
split!(cells, k) = begin
  c = cells[k]
  c.flags & TAIL != 0 && k > 1 && (cells[k-1] = blank(cells[k-1].bg))
  c.flags & WIDE != 0 && k < length(cells) && (cells[k+1] = blank(cells[k+1].bg))
  nothing
end

"Put an accent on the character before the cursor"
mark!(t::Terminal, c::Char) = begin
  k = t.pending ? t.col : t.col - 1
  k < 1 && return t
  cells = t.lines[t.row].cells
  cells[k].flags & TAIL != 0 && k > 1 && (k -= 1)
  cell = cells[k]
  had = cell.mark == 0 ? "" : t.marks[cell.mark]
  length(had) >= 8 && return t
  both = had * c
  id = get!(t.mark_ids, both) do
    push!(t.marks, both)
    length(t.marks)
  end
  id > typemax(UInt16) && return t
  cells[k] = Cell(cell.ch, cell.fg, cell.bg, cell.flags, UInt16(id))
  t
end

"What shows in a cell: its character with its accents"
shown(t::Terminal, c::Cell) = c.mark == 0 ? string(c.ch) : c.ch * t.marks[c.mark]

# --- moving and scrolling -------------------------------------------------------------------

"Move the part of the screen that scrolls up `n` lines. On the first screen, a line that leaves the top of the screen goes to the past."
scroll_up!(t::Terminal, n=1) = begin
  for _ in 1:min(n, t.bottom - t.top + 1)
    line = t.lines[t.top]
    deleteat!(t.lines, t.top)
    insert!(t.lines, t.bottom, Line(t.cols, t.bg))
    t.second || t.top != 1 || remember!(t, line)
  end
  t
end

"Add a line to the past, which keeps its last `most` lines"
remember!(t::Terminal, line::Line) = begin
  push!(t.past, line)
  over = length(t.past) - t.most
  over > 0 && (deleteat!(t.past, 1:over); t.gone += over)
  t
end

scroll_down!(t::Terminal, n=1) = begin
  for _ in 1:min(n, t.bottom - t.top + 1)
    deleteat!(t.lines, t.bottom)
    insert!(t.lines, t.top, Line(t.cols, t.bg))
  end
  t
end

"Go down a line. At the bottom of the part that scrolls, the text goes up instead."
index!(t::Terminal) = (t.row == t.bottom ? scroll_up!(t) : t.row < t.rows && (t.row += 1); t)
reverse_index!(t::Terminal) = (t.row == t.top ? scroll_down!(t) : t.row > 1 && (t.row -= 1); t)
linefeed!(t::Terminal) = (t.pending = false; index!(t))

"Put the cursor at a line and a cell, counted from the top of the part that scrolls when the program asked for that"
place!(t::Terminal, row, col) = begin
  t.pending = false
  t.row = t.origin ? clamp(row + t.top - 1, t.top, t.bottom) : clamp(row, 1, t.rows)
  t.col = clamp(col, 1, t.cols)
  t
end

up!(t::Terminal, n) = (t.pending = false; t.row = max(t.row - n, t.row >= t.top ? t.top : 1); t)
down!(t::Terminal, n) = (t.pending = false; t.row = min(t.row + n, t.row <= t.bottom ? t.bottom : t.rows); t)

keep!(t::Terminal) = (t.kept = Kept(t.row, t.col, t.fg, t.bg, t.flags, t.origin, t.drawing, t.shifted); t)

restore_cursor!(t::Terminal) = begin
  k = t.kept
  k === nothing && return place!(t, 1, 1)
  t.row, t.col, t.pending = clamp(k.row, 1, t.rows), clamp(k.col, 1, t.cols), false
  t.fg, t.bg, t.flags, t.origin, t.drawing, t.shifted = k.fg, k.bg, k.flags, k.origin, k.drawing, k.shifted
  t
end

"Show the second screen, blank, or the first one again as it was"
second!(t::Terminal, on::Bool) = begin
  on == t.second && return t
  if on
    t.held = t.lines
    t.lines = [Line(t.cols) for _ in 1:t.rows]
  else
    t.lines = t.held
    t.held = Line[]
  end
  t.second, t.pending = on, false
  t.top, t.bottom = 1, t.rows
  t
end

# --- erasing --------------------------------------------------------------------------------

"Blank the cells `from` to `to` of a line, in the colour that the cursor writes on"
erase!(t::Terminal, row, from, to) = begin
  line = t.lines[row]
  from, to = max(from, 1), min(to, t.cols)
  from <= to || return t
  split!(line.cells, from)
  split!(line.cells, to)
  line.cells[from:to] .= Ref(blank(t.bg))
  to == t.cols && (line.wrapped = false)
  t
end

erase_lines!(t::Terminal, rows) = (foreach(r -> erase!(t, r, 1, t.cols), rows); t)

erase_screen!(t::Terminal, how) = begin
  t.pending = false
  if how == 0
    erase!(t, t.row, t.col, t.cols)
    erase_lines!(t, t.row+1:t.rows)
  elseif how == 1
    erase_lines!(t, 1:t.row-1)
    erase!(t, t.row, 1, t.col)
  elseif how == 2
    erase_lines!(t, 1:t.rows)
  elseif how == 3
    t.gone += length(t.past)
    empty!(t.past)
  end
  t
end

erase_line!(t::Terminal, how) = begin
  t.pending = false
  how == 0 ? erase!(t, t.row, t.col, t.cols) : how == 1 ? erase!(t, t.row, 1, t.col) : how == 2 ? erase!(t, t.row, 1, t.cols) : t
end

"Put `n` blank lines in at the cursor's line, which pushes the lines under it down, or with `n` under 0 take lines out"
shift_lines!(t::Terminal, n) = begin
  t.top <= t.row <= t.bottom || return t
  top = t.top
  t.top = t.row
  n > 0 ? scroll_down!(t, n) : scroll_up_inside!(t, -n)
  t.top = top
  t.col, t.pending = 1, false
  t
end

# Lines that are taken out of the middle of the screen never go to the past
scroll_up_inside!(t::Terminal, n) = begin
  for _ in 1:min(n, t.bottom - t.top + 1)
    deleteat!(t.lines, t.top)
    insert!(t.lines, t.bottom, Line(t.cols, t.bg))
  end
  t
end

"Put `n` blank cells in at the cursor, or with `n` under 0 take cells out. The cells after move along."
shift_cells!(t::Terminal, n) = begin
  t.pending = false
  cells = t.lines[t.row].cells
  col = t.col
  split!(cells, col)
  count = min(abs(n), t.cols - col + 1)
  if n > 0
    for k in t.cols:-1:col+count
      cells[k] = cells[k-count]
    end
    cells[col:col+count-1] .= Ref(blank(t.bg))
  else
    for k in col:t.cols-count
      cells[k] = cells[k+count]
    end
    cells[t.cols-count+1:t.cols] .= Ref(blank(t.bg))
  end
  t
end

"Everything as a new terminal has it, but the past"
reset!(t::Terminal) = begin
  t.second && second!(t, false)
  soft_reset!(t)
  t.lines = [Line(t.cols) for _ in 1:t.rows]
  t.row, t.col, t.kept = 1, 1, nothing
  t.tabs = stops(t.cols)
  t.tracks, t.sgr_mouse, t.focus, t.bracketed, t.app_keypad = :none, false, false, false, false
  t
end

"What a program asked for goes back to what a new terminal has. The text stays."
soft_reset!(t::Terminal) = begin
  t.fg, t.bg, t.flags = 0x00000000, 0x00000000, 0x0000
  t.wrap, t.origin, t.insert, t.app_cursor, t.shows, t.pending = true, false, false, false, true, false
  t.top, t.bottom = 1, t.rows
  t.drawing, t.shifted = (false, false), false
  t
end

# --- the codes ------------------------------------------------------------------------------

"Do what the code ESC `b` says. `t.seq` has what came between the two."
escape!(t::Terminal, b::UInt8) = begin
  t.state = GROUND
  c = Char(b)
  if isempty(t.seq)
    c == '[' ? (t.state = CSI) :
    c == ']' ? (t.state = OSC; t.esc = false; empty!(t.text)) :
    c in "PX^_" ? (t.state = STRING; t.esc = false) :
    c == '7' ? keep!(t) :
    c == '8' ? restore_cursor!(t) :
    c == 'D' ? linefeed!(t) :
    c == 'E' ? (linefeed!(t); t.col = 1) :
    c == 'H' ? (t.tabs[t.col] = true) :
    c == 'M' ? (t.pending = false; reverse_index!(t)) :
    c == 'c' ? reset!(t) :
    c == '=' ? (t.app_keypad = true) :
    c == '>' ? (t.app_keypad = false) : nothing
  elseif t.seq[1] == UInt8('(')
    t.drawing = (c == '0', t.drawing[2])
  elseif t.seq[1] == UInt8(')')
    t.drawing = (t.drawing[1], c == '0')
  elseif t.seq[1] == UInt8('#') && c == '8'
    # The code that tests a screen fills it with E
    foreach(l -> (fill!(l.cells, Cell('E', 0x00000000, 0x00000000, 0x0000, 0x0000)); l.wrapped = false), t.lines)
  end
  nothing
end

"The numbers of the code in `t.seq`, with -1 for one that's left out. Returns the character before them, like ?, and the characters after them."
numbers!(t::Terminal) = begin
  seq = t.seq
  empty!(t.params)
  empty!(t.joined)
  i = 1
  sign = '\0'
  !isempty(seq) && 0x3c <= seq[1] <= 0x3f && (sign = Char(seq[1]); i = 2)
  n, colon, seen = -1, false, false
  while i <= length(seq) && 0x30 <= seq[i] <= 0x3b
    b = seq[i]
    if b <= 0x39
      n = min(max(n, 0) * 10 + (b - 0x30), 99_999)
      seen = true
    else
      push!(t.params, n)
      push!(t.joined, colon)
      n, colon, seen = -1, b == 0x3a, true
    end
    i += 1
  end
  seen && (push!(t.params, n); push!(t.joined, colon))
  (sign, String(seq[i:end]))
end

"The `i`th number of the code, or `usual` when it's left out or 0"
amount(t::Terminal, i, usual=1) = i <= length(t.params) && t.params[i] > 0 ? t.params[i] : usual
"The `i`th number of the code, or `usual` when it's left out"
number(t::Terminal, i, usual=0) = i <= length(t.params) && t.params[i] >= 0 ? t.params[i] : usual

"Do what the code ESC [ … `b` says"
csi!(t::Terminal, b::UInt8) = begin
  sign, after = numbers!(t)
  c = Char(b)
  if sign == '?'
    return isempty(after) ? private!(t, c) : after == "\$" && c == 'p' ? report_mode!(t, number(t, 1), true) : nothing
  elseif sign == '>'
    c == 'c' && reply!(t, "\e[>1;10;0c")
    c == 'q' && reply!(t, "\eP>|Ladder\e\\")
    return
  elseif sign != '\0'
    return
  end
  if !isempty(after)
    after == " " && c == 'q' && (t.shape = number(t, 1))
    after == "!" && c == 'p' && soft_reset!(t)
    after == "\$" && c == 'p' && report_mode!(t, number(t, 1), false)
    return
  end
  n = amount(t, 1)
  if c == 'm'
    style!(t)
  elseif c == 'H' || c == 'f'
    place!(t, n, amount(t, 2))
  elseif c == 'A'
    up!(t, n)
  elseif c == 'B' || c == 'e'
    down!(t, n)
  elseif c == 'C' || c == 'a'
    t.col, t.pending = min(t.col + n, t.cols), false
  elseif c == 'D'
    t.col, t.pending = max(t.col - n, 1), false
  elseif c == 'E'
    down!(t, n); t.col = 1
  elseif c == 'F'
    up!(t, n); t.col = 1
  elseif c == 'G' || c == '`'
    t.col, t.pending = clamp(n, 1, t.cols), false
  elseif c == 'd'
    place!(t, n, t.col)
  elseif c == 'J'
    erase_screen!(t, number(t, 1))
  elseif c == 'K'
    erase_line!(t, number(t, 1))
  elseif c == 'L'
    shift_lines!(t, n)
  elseif c == 'M'
    shift_lines!(t, -n)
  elseif c == '@'
    shift_cells!(t, n)
  elseif c == 'P'
    shift_cells!(t, -n)
  elseif c == 'X'
    t.pending = false
    erase!(t, t.row, t.col, t.col + n - 1)
  elseif c == 'S'
    scroll_up!(t, n)
  elseif c == 'T'
    scroll_down!(t, n)
  elseif c == 'I'
    tab!(t, n)
  elseif c == 'Z'
    tab!(t, -n)
  elseif c == 'b'
    foreach(_ -> char!(t, t.last), 1:min(n, t.rows * t.cols))
  elseif c == 'g'
    k = number(t, 1)
    k == 0 ? (t.tabs[t.col] = false) : k == 3 && fill!(t.tabs, false)
  elseif c == 'r'
    top, bottom = n, amount(t, 2, t.rows)
    top < bottom <= t.rows && ((t.top, t.bottom) = (top, bottom); place!(t, 1, 1))
  elseif c == 's'
    keep!(t)
  elseif c == 'u'
    restore_cursor!(t)
  elseif c == 'h' || c == 'l'
    for k in t.params
      k == 4 && (t.insert = c == 'h')
    end
  elseif c == 'c'
    number(t, 1) == 0 && reply!(t, "\e[?62;22c")
  elseif c == 'n'
    k = number(t, 1)
    k == 5 && reply!(t, "\e[0n")
    k == 6 && reply!(t, "\e[$(t.origin ? t.row - t.top + 1 : t.row);$(t.col)R")
  elseif c == 't'
    k = number(t, 1)
    k == 18 && reply!(t, "\e[8;$(t.rows);$(t.cols)t")
  end
  nothing
end

"Turn on or off what the code ESC [ ? … h or l names"
private!(t::Terminal, c::Char) = begin
  if c == 'h' || c == 'l'
    on = c == 'h'
    for k in t.params
      k == 1 ? (t.app_cursor = on) :
      k == 6 ? (t.origin = on; place!(t, 1, 1)) :
      k == 7 ? (t.wrap = on) :
      k == 25 ? (t.shows = on) :
      k == 47 || k == 1047 ? second!(t, on) :
      k == 1048 ? (on ? keep!(t) : restore_cursor!(t)) :
      k == 1049 ? (on ? (keep!(t); second!(t, true)) : (second!(t, false); restore_cursor!(t))) :
      k == 1000 ? (t.tracks = on ? :press : :none) :
      k == 1002 ? (t.tracks = on ? :drag : :none) :
      k == 1003 ? (t.tracks = on ? :any : :none) :
      k == 1004 ? (t.focus = on) :
      k == 1006 ? (t.sgr_mouse = on) :
      k == 2004 ? (t.bracketed = on) : nothing
    end
  elseif c == 'J'
    erase_screen!(t, number(t, 1))
  elseif c == 'K'
    erase_line!(t, number(t, 1))
  elseif c == 'n'
    number(t, 1) == 6 && reply!(t, "\e[?$(t.row);$(t.col)R")
  elseif c == 'u'
    # A program asks if the keys can be sent in kitty's way. They can't.
    isempty(t.params) && reply!(t, "\e[?0u")
  end
  nothing
end

"Answer a program that asks if something is on: 1 for on, 2 for off, 0 for a thing that this terminal doesn't know"
report_mode!(t::Terminal, k, private) = begin
  on = private ? (k == 1 ? t.app_cursor : k == 6 ? t.origin : k == 7 ? t.wrap : k == 25 ? t.shows : k in (47, 1047, 1049) ? t.second :
                  k == 1000 ? t.tracks == :press : k == 1002 ? t.tracks == :drag : k == 1003 ? t.tracks == :any :
                  k == 1004 ? t.focus : k == 1006 ? t.sgr_mouse : k == 2004 ? t.bracketed : nothing) :
                 (k == 4 ? t.insert : nothing)
  reply!(t, "\e[$(private ? "?" : "")$k;$(on === nothing ? 0 : on ? 1 : 2)\$y")
end

"Set the colours and the style that the cursor writes with, as the code ESC [ … m says"
style!(t::Terminal) = begin
  p, j = t.params, t.joined
  isempty(p) && return (t.fg = t.bg = 0x00000000; t.flags = 0x0000; t)
  i = 1
  while i <= length(p)
    n = max(p[i], 0)
    next = i + 1
    if n == 0
      t.fg = t.bg = 0x00000000
      t.flags = 0x0000
    elseif n == 1
      t.flags |= BOLD
    elseif n == 2
      t.flags |= FAINT
    elseif n == 3
      t.flags |= ITALIC
    elseif n == 4
      # 4:0 is no line under the text, and 4:3 is a wavy one, which shows as a straight one
      if i < length(p) && j[i+1]
        p[i+1] == 0 ? (t.flags &= ~UNDERLINE) : (t.flags |= UNDERLINE)
        next = i + 2
      else
        t.flags |= UNDERLINE
      end
    elseif n == 7
      t.flags |= INVERSE
    elseif n == 8
      t.flags |= HIDDEN
    elseif n == 9
      t.flags |= STRIKE
    elseif n == 21
      t.flags |= UNDERLINE
    elseif n == 22
      t.flags &= ~(BOLD | FAINT)
    elseif n == 23
      t.flags &= ~ITALIC
    elseif n == 24
      t.flags &= ~UNDERLINE
    elseif n == 27
      t.flags &= ~INVERSE
    elseif n == 28
      t.flags &= ~HIDDEN
    elseif n == 29
      t.flags &= ~STRIKE
    elseif 30 <= n <= 37
      t.fg = numbered(n - 30)
    elseif n == 38 || n == 48 || n == 58
      colour, next = extended(p, j, i)
      colour === nothing || (n == 38 ? (t.fg = colour) : n == 48 ? (t.bg = colour) : nothing)
    elseif n == 39
      t.fg = 0x00000000
    elseif 40 <= n <= 47
      t.bg = numbered(n - 40)
    elseif n == 49
      t.bg = 0x00000000
    elseif 90 <= n <= 97
      t.fg = numbered(n - 90 + 8)
    elseif 100 <= n <= 107
      t.bg = numbered(n - 100 + 8)
    end
    # The numbers that a colon joins to one that's done with are its own
    while next <= length(p) && j[next]
      next += 1
    end
    i = next
  end
  t
end

"""
The colour that the numbers after `p[i]` name, where `p[i]` is 38, 48 or 58,
and the place of the first number after them. The numbers come as 5 and a
colour's number, or as 2 and a red, a green and a blue, with ; or : between.
"""
extended(p, j, i) = begin
  if i < length(p) && j[i+1]
    last = i + 1
    while last < length(p) && j[last+1]
      last += 1
    end
    sub = @view p[i+1:last]
    colour = sub[1] == 5 && length(sub) >= 2 ? numbered(sub[2]) :
             sub[1] == 2 && length(sub) >= 4 ? direct(sub[end-2], sub[end-1], sub[end]) : nothing
    return (colour, last + 1)
  end
  kind = i < length(p) ? p[i+1] : -1
  kind == 5 && i + 2 <= length(p) && return (numbered(p[i+2]), i + 3)
  kind == 2 && i + 4 <= length(p) && return (direct(p[i+2], p[i+3], p[i+4]), i + 5)
  (nothing, length(p) + 1)
end

"Do what the words of the code ESC ] … say: `ending` is what ended them, and an answer ends the same way"
osc!(t::Terminal, ending) = begin
  words = String(copy(t.text))
  isvalid(words) || return
  cut = findfirst(';', words)
  code, rest = cut === nothing ? (words, "") : (words[1:cut-1], words[cut+1:end])
  if code == "0" || code == "2"
    t.title = first(filter(!iscntrl, rest), 200)
  elseif code == "7"
    m = match(r"^file://[^/]*(/.*)$", rest)
    m === nothing || (t.folder = unescaped(m[1]))
  elseif code in ("10", "11", "12") && rest == "?"
    c = code == "11" ? t.paper : t.ink
    part(shift) = string((c >> shift) & 0xff, base=16, pad=2)^2
    reply!(t, "\e]$code;rgb:$(part(16))/$(part(8))/$(part(0))$ending")
  end
  nothing
end

"A path of an address with each %41 as the character that it stands for"
unescaped(path) = begin
  out = UInt8[]
  bytes = codeunits(path)
  i = 1
  while i <= length(bytes)
    if bytes[i] == UInt8('%') && i + 2 <= length(bytes)
      n = tryparse(UInt8, String(bytes[i+1:i+2]), base=16)
      n === nothing ? push!(out, bytes[i]) : (push!(out, n); i += 2)
    else
      push!(out, bytes[i])
    end
    i += 1
  end
  String(out)
end

# --- another size ---------------------------------------------------------------------------

"""
The lines `all` laid out again `cols` wide. A line that was wrapped and the
lines that it goes on in are one line of text, which wraps at the new width.
`spots` are places in the old lines, each a line's number and a cell's, and
the second thing returned is where each of them is in the new lines.
"""
reflow(all::Vector{Line}, spots, cols::Int) = begin
  out = Line[]
  moved = collect(Tuple{Int,Int}, spots)
  i = 1
  while i <= length(all)
    last = i
    while last < length(all) && all[last].wrapped
      last += 1
    end
    # The cells of one line of text, and where each old line starts in them
    cells = Cell[]
    offsets = Int[]
    for m in i:last
      push!(offsets, length(cells))
      row = all[m].cells
      n = m == last ? used(row) : length(row)
      # The cells up to a spot on the line stay, so the spot keeps its place
      for (line, col) in spots
        line == m && (n = max(n, min(col - 1, length(row))))
      end
      append!(cells, @view row[1:n])
    end
    starts = Int[]
    at = 1
    while true
      push!(starts, at)
      stop = min(at + cols - 1, length(cells))
      # A wide character isn't cut in two
      stop < length(cells) && stop > at && cells[stop].flags & WIDE != 0 && (stop -= 1)
      piece = cells[at:stop]
      append!(piece, fill(BLANK, cols - length(piece)))
      push!(out, Line(piece, stop < length(cells)))
      at = stop + 1
      at > length(cells) && break
    end
    made = length(out) - length(starts)   # the lines before this line of text
    for (k, (line, col)) in enumerate(spots)
      i <= line <= last || continue
      offset = offsets[line-i+1] + col   # the place in the cells, from 1
      piece = something(findlast(<=(offset), starts), 1)
      moved[k] = (made + piece, clamp(offset - starts[piece] + 1, 1, cols))
    end
    i = last + 1
  end
  (out, moved)
end

"""
Give the terminal another size. On the first screen, text that was wrapped is
laid out again at the new width, and lines go to the past or come back from
it so that the cursor stays on the screen. The second screen is cut or gets
blank cells: the program that draws on it draws it again.
"""
Base.resize!(t::Terminal, rows::Integer, cols::Integer) = begin
  rows, cols = max(rows, 1), max(cols, 1)
  (rows, cols) == (t.rows, t.cols) && return t
  main = t.second ? t.held : t.lines
  cursor = t.second ? (t.kept === nothing ? (1, 1) : (clamp(t.kept.row, 1, t.rows), clamp(t.kept.col, 1, t.cols))) : (t.row, t.col)
  all = vcat(t.past, main)
  spots = [(length(t.past) + cursor[1], cursor[2]), (length(t.past) + 1, 1)]
  cols == t.cols || ((all, spots) = reflow(all, spots, cols))
  at, top = spots[1], spots[2][1]
  # The blank lines under the cursor go, and the screen is the lines from where its top was. If the cursor
  # would be under the screen then, the screen starts further down.
  resize!(all, max(at[1], something(findlast(!isblank, all), 0)))
  top = clamp(max(top, at[1] - rows + 1), 1, length(all))
  screen = all[top:min(end, top + rows - 1)]
  while length(screen) < rows
    push!(screen, Line(cols))
  end
  t.past = all[1:top-1]
  over = length(t.past) - t.most
  over > 0 && (deleteat!(t.past, 1:over); t.gone += over)
  cursor = (at[1] - top + 1, at[2])
  if t.second
    t.held = screen
    k = t.kept
    k === nothing || (t.kept = Kept(cursor[1], cursor[2], k.fg, k.bg, k.flags, k.origin, k.drawing, k.shifted))
    # The second screen keeps its top left corner
    resize!(t.lines, min(length(t.lines), rows))
    for line in t.lines
      n = length(line.cells)
      resize!(line.cells, cols)
      cols > n && (line.cells[n+1:cols] .= Ref(BLANK))
      line.wrapped = false
    end
    while length(t.lines) < rows
      push!(t.lines, Line(cols))
    end
    t.row, t.col = clamp(t.row, 1, rows), clamp(t.col, 1, cols)
  else
    t.lines = screen
    t.row, t.col = cursor
  end
  t.rows, t.cols, t.pending = rows, cols, false
  t.top, t.bottom = 1, rows
  t.tabs = stops(cols)
  t.changed += 1
  t
end

# --- the text -------------------------------------------------------------------------------

"Every line that the terminal has: its past, then its screen. The screen is the first one while the second shows only if `first` is true."
everything(t::Terminal; first=false) = vcat(t.past, first && t.second ? t.held : t.lines)

"How many lines the terminal has: its past and its screen"
height(t::Terminal) = length(t.past) + t.rows

"The line with the number `k`, where 1 is the oldest line of the past, or nothing"
line(t::Terminal, k::Integer) = begin
  n = length(t.past)
  1 <= k <= n ? t.past[k] : n < k <= n + t.rows ? t.lines[k-n] : nothing
end

"The text of cells `from` to `to` of a line"
words(t::Terminal, l::Line, from=1, to=length(l.cells)) = begin
  io = IOBuffer()
  for k in max(from, 1):min(to, length(l.cells))
    c = l.cells[k]
    c.flags & TAIL != 0 && continue
    write(io, c.ch)
    c.mark == 0 || write(io, t.marks[c.mark])
  end
  String(take!(io))
end

"""
The text between two places, each a line's number and a cell's, with the
second place's cell left out. A line that was wrapped is one line of the
text, and the blanks at the end of a line are left out.
"""
words(t::Terminal, from::Tuple{Int,Int}, to::Tuple{Int,Int}) = begin
  from > to && ((from, to) = (to, from))
  io = IOBuffer()
  for k in from[1]:to[1]
    l = line(t, k)
    l === nothing && continue
    a = k == from[1] ? from[2] : 1
    b = k == to[1] ? to[2] - 1 : length(l.cells)
    l.wrapped || (b = min(b, used(l.cells)))
    write(io, words(t, l, a, b))
    k < to[1] && !l.wrapped && write(io, '\n')
  end
  String(take!(io))
end

"All the text of the terminal, without the blank lines at its end"
words(t::Terminal) = String(rstrip(words(t, (1, 1), (height(t), t.cols + 1)), '\n'))

"The first and the last cell of the word at cell `col` of the line numbered `k`: letters, digits and the characters of a path"
word_at(t::Terminal, k::Integer, col::Integer) = begin
  l = line(t, k)
  (l === nothing || !(1 <= col <= length(l.cells))) && return (col, col)
  inword(c::Cell) = c.flags & TAIL != 0 || isletter(c.ch) || isdigit(c.ch) || c.ch in "_-./~:@%+#=?&"
  inword(l.cells[col]) || return (col, col)
  a = b = col
  while a > 1 && inword(l.cells[a-1])
    a -= 1
  end
  while b < length(l.cells) && inword(l.cells[b+1])
    b += 1
  end
  (a, b)
end

"The code that sets a colour: `base` is 30 for the text and 40 for what's behind it"
colour_code(c::UInt32, base) =
  c & DIRECT != 0 ? "$(base + 8);2;$((c >> 16) & 0xff);$((c >> 8) & 0xff);$(c & 0xff)" :
  c & NUMBERED != 0 ? (n = c & 0xff; n < 8 ? "$(base + n)" : n < 16 ? "$(base + 52 + n)" : "$(base + 8);5;$n") : ""

"The code that sets a cell's colours and style, from none"
style_code(fg, bg, flags) = begin
  parts = String["0"]
  for (bit, n) in ((BOLD, 1), (FAINT, 2), (ITALIC, 3), (UNDERLINE, 4), (INVERSE, 7), (HIDDEN, 8), (STRIKE, 9))
    flags & bit != 0 && push!(parts, string(n))
  end
  fg == 0 || push!(parts, colour_code(fg, 30))
  bg == 0 || push!(parts, colour_code(bg, 40))
  "\e[" * join(parts, ';') * "m"
end

"""
Write the past and the first screen as text that makes them again: each line
of text on a line of its own, however it was wrapped, with codes only for
colour and style. The blank lines at the end are left out.
"""
saved(io::IO, t::Terminal) = begin
  all = everything(t, first=true)
  last = something(findlast(!isblank, all), 0)
  pen = (0x00000000, 0x00000000, 0x0000)
  plain = pen
  for i in 1:last
    l = all[i]
    n = l.wrapped && i < last ? length(l.cells) : used(l.cells)
    for k in 1:n
      c = l.cells[k]
      c.flags & TAIL != 0 && continue
      style = (c.fg, c.bg, c.flags & STYLES)
      style == pen || (write(io, style_code(style...)); pen = style)
      write(io, c.ch)
      c.mark == 0 || write(io, t.marks[c.mark])
    end
    if !(l.wrapped && i < last)
      # The colour behind the text mustn't fill the rest of the line
      pen == plain || (write(io, "\e[0m"); pen = plain)
      i < last && write(io, "\r\n")
    end
  end
  pen == plain || write(io, "\e[0m")
  nothing
end

saved(t::Terminal) = sprint(saved, t)

"""
Read a saved file into the terminal: its lines show, and the cursor is at the
start of a new line after them. Nothing is answered, and nothing that the
file asks for stays on, since no program is there.
"""
restore!(t::Terminal, bytes::AbstractVector{UInt8}) = begin
  t.answering = false
  # git can take the carriage return out of each line end of a file that it keeps. A file with none has every line
  # start at the left all the same.
  if !(0x0d in bytes)
    whole = UInt8[]
    foreach(b -> (b == 0x0a && push!(whole, 0x0d); push!(whole, b)), bytes)
    bytes = whole
  end
  feed!(t, bytes)
  settle!(t)
  t.answering = true
  t
end

"""
Leave the terminal as a program that has ended should have left it: the first
screen shows, nothing that the program asked for stays on, and the cursor is
at the start of a new line. A program that's stopped, and a file that ends in
the middle of a code, leave things on.
"""
settle!(t::Terminal) = begin
  t.state = GROUND
  empty!(t.left)
  t.second && second!(t, false)
  soft_reset!(t)
  t.tracks, t.sgr_mouse, t.focus, t.bracketed, t.app_keypad, t.insert = :none, false, false, false, false, false
  t.col == 1 || feed!(t, "\r\n")
  t
end

"Forget the past and the lines of the first screen above the cursor's line, which goes to the top of the screen"
clear!(t::Terminal) = begin
  t.gone += length(t.past)
  empty!(t.past)
  t.changed += 1
  (t.second || t.row == 1) && return t
  n = t.row - 1
  deleteat!(t.lines, 1:n)
  append!(t.lines, [Line(t.cols) for _ in 1:n])
  t.gone += n
  t.row = 1
  t
end

# --- what the terminal sends ----------------------------------------------------------------

# The keys that are held with a key, added up
const SHIFT = 1
const ALT = 2
const CTRL = 4

const ARROWS = Dict(:up => 'A', :down => 'B', :right => 'C', :left => 'D', :home => 'H', :end => 'F')
const FUNCTIONS = Dict(:f1 => 'P', :f2 => 'Q', :f3 => 'R', :f4 => 'S')
const TILDES = Dict(:insert => 2, :delete => 3, :pageup => 5, :pagedown => 6, :f5 => 15, :f6 => 17, :f7 => 18, :f8 => 19,
                    :f9 => 20, :f10 => 21, :f11 => 23, :f12 => 24)

"""
The bytes that a key sends the program: `name` is one of :enter, :tab,
:backspace, :escape, :up, :down, :left, :right, :home, :end, :pageup,
:pagedown, :insert, :delete and :f1 to :f12, and `held` adds up SHIFT, ALT
and CTRL. A key that sends nothing gives "".
"""
key(t::Terminal, name::Symbol, held::Integer=0) = begin
  m = held + 1
  if haskey(ARROWS, name)
    c = ARROWS[name]
    # ⌥← and ⌥→ go back and on a word, as they do in the Mac's own terminal
    held == ALT && name == :left && return "\eb"
    held == ALT && name == :right && return "\ef"
    return held == 0 ? (t.app_cursor ? "\eO$c" : "\e[$c") : "\e[1;$m$c"
  elseif haskey(FUNCTIONS, name)
    c = FUNCTIONS[name]
    return held == 0 ? "\eO$c" : "\e[1;$m$c"
  elseif haskey(TILDES, name)
    n = TILDES[name]
    return held == 0 ? "\e[$n~" : "\e[$n;$m~"
  end
  name == :enter ? (held & ALT != 0 ? "\e\r" : held == SHIFT ? "\n" : "\r") :
  name == :tab ? (held & SHIFT != 0 ? "\e[Z" : "\t") :
  name == :backspace ? (held & ALT != 0 ? "\e\x7f" : held & CTRL != 0 ? "\b" : "\x7f") :
  name == :escape ? "\e" : ""
end

"The byte that the Control key and the key of `c` send, or nothing: Control and C is the byte 3"
control(c::Char) = begin
  c = lowercase(c)
  'a' <= c <= 'z' ? Char(c - 'a' + 1) :
  c in " 2@" ? '\0' :
  c in "[3" ? '\e' :
  c in "\\4" ? '\x1c' :
  c in "]5" ? '\x1d' :
  c in "6^" ? '\x1e' :
  c in "7-_/" ? '\x1f' :
  c in "8?" ? '\x7f' : nothing
end

"""
The bytes that the mouse sends the program, or "" when the program didn't ask
for them. `what` is :press, :release or :move. `button` is 0 for the left
button, 1 for the middle one, 2 for the right one, 3 for none, 64 for the
wheel going up and 65 for it going down. `row` and `col` are the cell.
"""
mouse(t::Terminal, what::Symbol, button::Integer, row::Integer, col::Integer, held::Integer=0) = begin
  t.tracks == :none && return ""
  what == :move && (t.tracks == :press || (t.tracks == :drag && button == 3)) && return ""
  b = button + (what == :move ? 32 : 0) + (held & SHIFT != 0 ? 4 : 0) + (held & ALT != 0 ? 8 : 0) + (held & CTRL != 0 ? 16 : 0)
  t.sgr_mouse && return "\e[<$b;$col;$row$(what == :release ? 'm' : 'M')"
  what == :release && (b = b - button + 3)
  (col > 223 || row > 223) && return ""
  String(UInt8[0x1b, UInt8('['), UInt8('M'), UInt8(32 + b), UInt8(32 + col), UInt8(32 + row)])
end

"The bytes that send pasted `text` to the program, between the two codes that mark it when the program asked for them"
paste(t::Terminal, text::AbstractString) = begin
  text = replace(text, "\r\n" => "\r", '\n' => '\r')
  t.bracketed ? "\e[200~" * replace(text, "\e[201~" => "") * "\e[201~" : text
end

"The bytes that tell the program that the terminal got or lost the keyboard, or \"\" when it didn't ask"
focus(t::Terminal, on::Bool) = t.focus ? (on ? "\e[I" : "\e[O") : ""

# --- the 256 numbered colours ---------------------------------------------------------------

"The red, green and blue of the numbered colour `n`, from 16 to 255: a cube of 216 colours, then 24 greys"
colour256(n::Integer) = begin
  if n >= 232
    v = UInt32(8 + 10 * (n - 232))
    return v << 16 | v << 8 | v
  end
  n -= 16
  level(k) = UInt32(k == 0 ? 0 : 55 + 40k)
  level(n ÷ 36) << 16 | level(n ÷ 6 % 6) << 8 | level(n % 6)
end
