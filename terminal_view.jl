# A terminal's file, which shows as a terminal
#
# A file whose name ends in .vt keeps what a terminal shows: text with the
# codes that colour it, as Kero writes for each of its sessions. Such a file
# opens as a terminal, which covers the page's whole space in the window. That's
# its highest level, over its bits, its bytes in hexadecimal and its text, so
# ⌘E shows the text with its codes.
#
# A file with nothing in it gets a shell at once, in the folder that the file
# is in: New Terminal in a folder's menu makes such a file. A file with text
# shows the text, and a line under it says that Return starts a shell. So a
# file that you only look at, like one of Kero's, runs nothing and isn't
# changed. What the shell writes goes into the file a moment after it comes,
# so the file has it the next time.
#
# While the terminal shows it has the keyboard, and the keys are the shell's.
# The keys with ⌘ are still the window's, but ⌘C, ⌘V, ⌘A and ⌘K, which are the
# terminal's: term/view.jl says what they do. The shell runs on while the
# window shows other files, and what it wrote is there when the window comes
# back. It ends when it's told to, with `exit`, and when the window closes.
# The terminal has the font of code, at the size that code has, and the
# colours of the window's theme: a program's red is the theme's. The
# Terminal page of the settings has the rest: the caret's shape and whether
# it blinks, whether what the mouse selects is copied, whether ⌥ is a Meta
# key, what a program's bell does, and how many lines a terminal keeps.
#
# A program in the terminal can say which command starts it again, as an agent
# does with the name of its session. When Ladder closes while that program
# runs, the terminal starts a shell the next time its file shows, and runs the
# command there: term/resume.jl has the rules. The records of this are with
# Ladder's own files, never in the terminal's file.

@use "github.com/jkroso/Prospects.jl" @def
@use GLFW
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "./sheet" shown
@use "./term/view" => Terms
@use Colors: RGBA, Colorant
@use "./look" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./strokes" exports...
@use "./host" exports...
@use "./folder_page" exports...

export terminals, term_colour, term_mix, term_palette, TERM_BELLS, term_setting!,
       term_settings_text, read_term_setting!, term_part, term_tick!, close_terminals!, Terminals,
       term_choice, term_page, term_look!, term_shown

"True when the page shows a terminal's file at one of its levels: as the terminal, its text, its bytes in hexadecimal or its bits"
term_page(b::Buffer) = b.view in FILE_VIEWS && lowercase(splitext(b.path)[2]) in TERMINALS && isfile(b.path)

"True when the page shows a terminal's file as the terminal"
term_shown(e) = e.buf.view == :file && hosted(e) === nothing && term_page(e.buf)

"The terminals of a window"
@def mutable struct Terminals
  list::Vector{Terms.TerminalView} = Terms.TerminalView[]   # one for each terminal's file that the window has shown and that's still there
end

"The terminals of the window of `e`: one for each terminal's file that it has shown and that's still there"
terminals(e) = state_of(e, Terminals).list

"A colour as the terminal's view takes it: its red, green and blue, a byte each"
term_colour(c::Colorant) = (c = convert(RGBA{Float64}, c); UInt32(round(Int, 255c.r)) << 16 | UInt32(round(Int, 255c.g)) << 8 | UInt32(round(Int, 255c.b)))

"The colour that's `t` of the way from `a` to `b`"
term_mix(a::UInt32, b::UInt32, t) = begin
  part(shift) = UInt32(round(Int, ((a >> shift) & 0xff) * (1 - t) + ((b >> shift) & 0xff) * t))
  part(16) << 16 | part(8) << 8 | part(0)
end

"""
The 16 colours that programs name by number, from the theme's colours: black,
red, green, yellow, blue, magenta, cyan and white, and then a stronger one of
each. The six hues are the theme's colours for code, so a program's red is
the red of a line that a diff takes away. Black is the darkest and white the
lightest that reads on the page, since programs write the one on the other.
"""
term_palette() = begin
  c = colours
  ink, bg = term_colour(c.ink), term_colour(c.bg)
  dark = sum(k -> (0.299, 0.587, 0.114)[k] * ((bg >> (24 - 8k)) & 0xff), 1:3) < 128   # how bright the page is
  hues = map(term_colour, (c.removed, c.added, c.number, c.call, c.keyword, c.type))
  strong = map(h -> term_mix(h, dark ? 0x00ffffff : ink, 0.25), hues)
  UInt32[dark ? term_colour(c.line) : ink, hues..., dark ? term_mix(ink, bg, 0.2) : term_colour(c.dim),
         term_colour(c.comment), strong..., dark ? ink : term_colour(c.line)]
end

const TERM_BELLS = (:flash, :sound, :none)
"The choice of `options` that `x` names, for a live block of the settings: a word like \"bar\", or a number"
term_choice(options, x) = begin
  c = x isa AbstractString ? Symbol(lowercase(x)) : x
  c in options || error("A terminal's setting can be $(join(string.(options), ", ", " or ")), not $(repr(x)).")
  c
end

"Change the terminal's setting `name` in every window, and keep it"
term_setting!(e, name::Symbol, value) = begin
  setfield!(TERM_SETTINGS, name, value)
  save_settings!(e)
  any(o -> o === e, editors) || rerun!(e, :terminal)
  foreach(o -> (rerun!(o, :terminal); redraw_in!(o, 0)), editors)
  e
end

"The terminal's settings as the file of the settings has them: a line for each, like term.caret=bar"
term_settings_text() = join("term.$name=$(getfield(TERM_SETTINGS, name))\n" for name in fieldnames(TermSettings))

"Take the terminal's setting `name` from the file of the settings. A value that it can't be leaves it as it was."
read_term_setting!(name, value) = begin
  s = TERM_SETTINGS
  if name == "caret" || name == "bell"
    c = Symbol(value)
    c in (name == "caret" ? TERM_CARETS : TERM_BELLS) && setfield!(s, Symbol(name), c)
  elseif name in ("blink", "copies", "meta", "again")
    setfield!(s, Symbol(name), value == "true")
  elseif name == "most"
    n = tryparse(Int, value)
    n in TERM_PASTS && (s.most = n)
  end
  nothing
end

"Give the terminal `v` the font of code and the colours of the theme, as the window of `e` has them now, and the terminal's settings"
term_look!(v, e) = begin
  v.family, v.style, v.size = codefont(), codestyle(), Float64(num(code_size(e)))
  v.ink, v.paper, v.dim = term_colour(colours.ink), term_colour(colours.bg), term_colour(colours.dim)
  v.select = UInt32(round(Int, 255convert(RGBA{Float64}, colours.select).alpha)) << 24 | term_colour(colours.select)
  v.palette = term_palette()
  s = TERM_SETTINGS
  v.caret, v.blink, v.copies, v.meta, v.bell, v.most, v.again = s.caret, s.blink, s.copies, s.meta, s.bell, s.most, s.again
  v
end

"""
The terminal of the terminal's file that the page shows, with the room that
the page has. It has the keyboard while nothing else has taken it: the field
that finds text, the sidebar and the command palette take it and give it back.
"""
term_part(e) = begin
  b = e.buf
  v = node!(e, (:term, b.path)) do
    made = Terms.TerminalView(path=b.path)
    push!(terminals(e), made)
    made
  end
  v.wide, v.high = page_room(e)
  term_look!(v, e)
  w = window_of(e)
  # The shell's output is read on another thread, which wakes the window to show it. A window that isn't on a screen has nothing to wake.
  v.wake = () -> (w === nothing || isempty(w.glfw) || GLFW.PostEmptyEvent(); nothing)
  if w !== nothing
    (w.focus === e || w.focus === nothing) && e.popup == :none && focus(v)
    w.focus === v && e.popup != :none && focus(e)   # what floats over the page, like the command palette, has the keys
  end
  # The top bar says what the program calls its window, as a terminal app's title does
  b.about = v.term === nothing ? "" : v.term.title
  v
end

"""
See to the terminals that the window doesn't show now. A shell that writes
while the window shows another file is read, so that it doesn't wait. A
terminal that isn't shown gives the keyboard back, as when ⌘E shows its
file's text. One whose file has gone ends.
"""
term_tick!(e) = begin
  isempty(terminals(e)) && return
  shown = term_shown(e) ? get(e.nodes, (:term, e.buf.path), nothing) : nothing
  w = window_of(e)
  for v in copy(terminals(e))
    v === shown && continue
    w !== nothing && w.focus === v && focus(e)
    if isfile(v.path)
      Terms.tick!(v)
    else
      delete!(e.nodes, (:term, v.path))
      Base.filter!(o -> o !== v, terminals(e))
      Terms.forget!(v)   # and nothing that ran in it starts again
      v.path = ""   # the file has gone, so nothing writes it again
      Terms.close!(v)
    end
  end
  nothing
end

"End the shell of every terminal of the window of `e`, and write its file: the window has closed"
close_terminals!(e) = begin
  isempty(terminals(e)) && return
  foreach(Terms.close!, terminals(e))
  empty!(terminals(e))
  nothing
end
