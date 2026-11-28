# A page as an app: Show As App opens the page in a window that has only the page
#
# Its commands are in main.jl.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "./sheet" shown
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
@use "./additions" exports...
@use "./folder_page" exports...
@use "./views" exports...

export app_tick!, show_as_app!, AppWindow

# --- a page as an app -------------------------------------------------------------------------
#
# The command Show As App opens the page in a window that has only the page:
# no sidebar, no caret, and a top bar with nothing in it, which you drag to
# move the window. The page's blocks work as they do in any window, so a page
# with a board, a chart and a few sliders is a small tool that you leave open.
# What a block changes is written to the page's file at once, since the window
# has nothing that says a page isn't saved. No key changes the page's text
# there. The command, run in that window, makes it a window that changes the
# page again.

"What a window keeps of a page shown as an app"
@def mutable struct AppWindow
  on::Bool = false   # the window shows its page as an app
end

"True when the window of `e` shows its page as an app"
as_app(e) = state_of(e, AppWindow).on

"In each frame of a window that shows its page as an app: keep the caret away, and write what a block changed"
app_tick!(e) = begin
  as_app(e) || return nothing
  b = e.buf
  b.reading = true
  e.panel = false
  dirty(b) && writes(b) && save!(b)
  nothing
end

"Show the page as an app, in a window of its own: only the page, with no sidebar, no caret and nothing in the top bar. In that window, go back to a window that changes the page."
show_as_app!(e) = begin
  if as_app(e)
    state_of(e, AppWindow).on = false
    e.buf.reading = false
    redraw_in!(e, 0)
    return nothing
  end
  b = e.buf
  (b.view == :markdown && !isempty(b.path)) || error("Only a page of Markdown that's in a file shows as an app.")
  dirty(b) && writes(b) && save!(b)
  shown = build_editor(b.path)
  same_settings!(shown, e)
  shown.remember = false   # what this window sets, like a sidebar that's shut, isn't written to the settings
  shown.panel = false
  state_of(shown, AppWindow).on = true
  shown.buf.reading = true
  by = window_of(e)
  size, at = by === nothing ? (paper_window(screen_room(), 0px), (0px, 0px)) : ((by.size[1], by.size[2]), (by.position[1] + 30px, by.position[2] + 30px))
  shown.size = size
  show_window!(window!(shown, title=something(page_title(shown), splitext(basename(b.path))[1]), size=size, position=at), by)
  shown
end
add_command!(show_as_app!, title="Show the page as an app, in a window of its own: only its blocks, with no sidebar or caret, and nothing in the top bar", kind=:look)
