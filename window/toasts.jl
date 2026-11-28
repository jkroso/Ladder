# Toasts: what says that code which Ladder ran by itself failed, in each window

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe window_of handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor redraw_in! popup! close_popup!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "../markdown" words
@use "../agent/waiters" => Agent
@use "./update" => Update
@use "../folders/folders" => Folders
@use Colors: @colorant_str, RGBA
@use "../base" exports...
@use "../code/julia_levels" exports...
@use "../files/file_view" exports...
@use "./last_place" exports...

export TOASTS, TOAST_DARK, TOAST_EDGE, TOAST_LIGHT, TOAST_LINES, TOAST_W, ToastClose, Toasts,
       open_editor, toast_colours, toast_lines, toasts_tick!

# --- toasts ---------------------------------------------------------------------------
#
# Code that Ladder runs by itself, the startup page's and a folder's own page's,
# has no window of its own to say that it failed in, and it can fail before a
# window opens. So each window says so with a toast: a card at its bottom
# right, in the colours of the toast that Centient shows for an error. It says
# what stopped and why, as Julia says it.
#
# A toast stays until you close it with its ×, or until the same page runs
# again with nothing wrong. Every window shows the same toasts, so a toast
# that's closed in one window is closed in all of them.

"The toasts that each window shows, the oldest first: what each is about (`key`), what stopped (`title`) and why (`words`)"
const TOASTS = NamedTuple{(:key, :title, :words),Tuple{Any,String,String}}[]

"How wide a toast is: wider than Centient's, which are 360px, so that a line of code that Julia quotes fits"
const TOAST_W = 480px
"How far a toast is from the window's right and bottom edges"
const TOAST_EDGE = 16px
"The most lines of what went wrong that a toast shows"
const TOAST_LINES = 8
"The colours of a toast for an error on a light page and on a dark one, which are Centient's"
const TOAST_LIGHT = (bg=colorant"#fee2e2", line=colorant"#dc2626", ink=colorant"#991b1b", hover=RGBA(0.6, 0.106, 0.106, 0.1))
const TOAST_DARK = (bg=colorant"#341a1d", line=colorant"#f87171", ink=colorant"#fca5a5", hover=RGBA(0.988, 0.647, 0.647, 0.12))

"Show a toast in each window that says `title`, and why in `words`. It takes the place of the toast about the same `key`."
toast!(key, title::AbstractString, words::AbstractString) = begin
  filter!(it -> it.key != key, TOASTS)
  push!(TOASTS, (key=key, title=String(title), words=String(words)))
  foreach(e -> redraw_in!(e, 0), editors)
  nothing
end

"Close the toast about `key` in every window, if there's one"
untoast!(key) = begin
  any(it -> it.key == key, TOASTS) || return nothing
  filter!(it -> it.key != key, TOASTS)
  foreach(e -> redraw_in!(e, 0), editors)
  nothing
end

"The toasts of a window, a card for each, one over the other at the bottom right"
@def mutable struct Toasts <: SemanticUI
  closes::Dict{Any,Any} = Dict{Any,Any}()   # the × of each toast, by its key
end

"The × of the toast about `key`, which closes it"
@def mutable struct ToastClose <: SemanticUI
  key::Any = nothing
end

"The colours of a toast on the page that shows"
toast_colours() = dark_page() ? TOAST_DARK : TOAST_LIGHT

"""
The lines that a toast shows of what went wrong, each with whether it wraps:
as many as fit, and … for the rest. A file in the home folder starts with ~,
and the words that say only where Julia was, `LoadError:` and `in expression
starting at`, go, as does the ⭒ of the name of a page's module, which the font
of code doesn't have. The lines of code that Julia quotes after `# Error @` don't
wrap, so that the mark under the place that's wrong stays under it. When the
mark is further in than `room` characters, each of those lines starts further
in, after …, so that the place shows.
"""
toast_lines(words, room=typemax(Int)) = begin
  out = Tuple{String,Bool}[]
  code = false
  for line in split(rstrip(replace(words, homedir() => "~", "LoadError: " => "", "⭒" => "")), '\n')
    startswith(line, "in expression starting at") && continue
    push!(out, (String(rstrip(line)), !code || startswith(line, "# Error @")))
    startswith(line, "# Error @") ? (code = true) : (code && startswith(line, '#') && (code = false))
  end
  mark = findfirst(((s, wraps),) -> !wraps && startswith(s, '#') && '╙' in s, out)
  if mark !== nothing
    at = length(out[mark][1], 1, findfirst('╙', out[mark][1]))
    if at > room - 8
      cut = at - room ÷ 2
      out = [wraps ? (s, wraps) : (length(s) > cut ? "…" * s[nextind(s, 0, cut + 1):end] : "", wraps) for (s, wraps) in out]
    end
  end
  length(out) > TOAST_LINES ? [first(out, TOAST_LINES); ("…", true)] : out
end

describe(t::Toasts) = begin
  c = toast_colours()
  filter!(((key, _),) -> any(it -> it.key == key, TOASTS), t.closes)
  cards = map(TOASTS) do it
    x = get!(() -> own!(t, ToastClose(key=it.key)), t.closes, it.key)
    face = Face(codefont(), codestyle(), 12px, c.ink, false)
    room = floor(Int, num(TOAST_W - 24px) / num(measure(face, "0")))   # how many characters of code fit across the toast
    lines = [Box(width(grow=grow), Alignment.Start, Text(line, size=12px, family=codefont(), subfamily=codestyle(), color=c.ink,
                                                         wrap=wraps ? WrapMode.words : WrapMode.none))
             for (line, wraps) in toast_lines(it.words, room)]
    Box(width(TOAST_W), padding(14px, 12px, 12px, 12px), radius(12px), border(1px, :solid, c.line), background(c.bg), lifted,
      Column(width(grow=grow), Alignment.Start, child_gap=6px,
        # A Box of its own keeps the title from taking half of the row
        Row(width(grow=grow), Alignment.Center, child_gap=8px, Box(width(grow=grow), Alignment.Start, omni_label(it.title, 15, c.ink, weight="SemiBold")), x),
        # A line that's too long for the toast goes past its right edge, out of sight
        Box(width(grow=grow), Alignment.Start, clip_x=true, Column(width(grow=grow), Alignment.Start, child_gap=6px, lines...))))
  end
  Column(width(grow=grow), Alignment.End, child_gap=8px, name="Toasts", cards...)
end

describe(x::ToastClose) = (c = toast_colours();
  Box(fixed(20px), radius(10px), Alignment.Center, background(ishovered(x) ? c.hover : clear), Icon("x-lg", size=12px, color=c.ink)))
cursor(::ToastClose) = :hand
onmouse(::ToastClose, ::MouseMove) = handled
onkey(x::ToastClose, ::KeyPress{Keys.mouse_left}) = (untoast!(x.key); handled)

"""
Show the toasts at the bottom right of the window of `e`, or none when there
are none. While the palette of commands shows, they're over its bar.
"""
toasts_tick!(e) = begin
  win = window_of(e)
  win === nothing && return
  isempty(TOASTS) && return close_popup!(win, :toasts)
  wide, high = window_size(e)
  bottom = high - TOAST_EDGE
  e.popup == :commands && (bottom = min(bottom, px(palette_plan(e, palette(e)).band.y) - TOAST_EDGE))
  t = node!(Toasts, e, :toasts)
  # Under the toasts the mouse is theirs, and anywhere else it's the window's: a click elsewhere leaves them
  popup!(win, t, anchor=(wide - TOAST_EDGE - TOAST_W, bottom, TOAST_W, 0px), placement=:top, width=TOAST_W, key=:toasts, modal=false)
  nothing
end

"""
Open an editor window and run it until it closes. `args` can name a Markdown
file or a folder, and `--paper` or `--night` to choose the colours for this
window. With no file, the window shows where Ladder was when it last quit, or
else the startup page: see "where Ladder opens".
"""
open_editor(args) = begin
  move_old_folders!()
  # macOS can pass its own -options to an app it opens, so skip anything with a dash
  paths = filter(a -> !startswith(a, "-"), args)
  Agent.announce()   # an agent's script knows from now on that this Ladder can send it a page
  home = startup_page!()
  Folders.page!()   # the page that lists what you ignore, which the Settings page links to
  run_startup!(home)
  was = isempty(paths) ? take_place!() : nothing
  # The code of the startup page can have made methods since this function started, like those of a kind of folder
  e = was === nothing ? build_editor(isempty(paths) ? home : paths[1]) : Base.invokelatest(place_editor, was)
  load_settings!(e)
  "--night" in args && (e.theme = :night)
  "--paper" in args && (e.theme = :paper)
  e.remember = true
  e.size = paper_window(screen_room(), e.side)
  w = window!(e, title="Ladder", size=e.size)
  was === nothing || put_place!(e, was)
  # This returns when the last window has closed. The window is drawn with the methods of the startup page's code too.
  Base.invokelatest(display, w)
  keep_place!(quit_editor(e))
  # What code from the startup page does last, like the end of a look for email
  foreach(f -> Base.invokelatest(f), values(AT_QUIT))
  # Each extension moves up to the new code that Ladder fetched, which loads the next time that Ladder opens
  x = Update.extensions()
  Update.quit!(x)
  # After Restart Ladder, the program that puts a newer version of the app in its place opens it again too
  x.again && (Update.own().again = true)
  # A newer version of the app that's ready takes the app's place once Ladder has quit
  Update.quit!(Update.own()) || Update.reopen!(x)
end
