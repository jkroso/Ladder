# Saving a page when you leave its window, a setting
#
# Its commands are in main.jl.

@use GLFW
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg with_pool
@use "../base" exports...
@use "../additions" exports...
@use "../files/file_view" exports...
@use "../blocks/schedule_view" exports...
@use "../code/run_code" exports...
@use "../window/last_place" exports...

export PAGE_AREA_W, autosave!, left!

# --- saving a page when you leave its window ------------------------------------------------
#
# Ladder writes a page to its file when you press ⌘S, and at no other time.
# A setting changes that: with it on, a window writes its pages when it stops
# being the front window. That's when you click another window, change to
# another app, or hide Ladder. A page with no file has nowhere to go, so it
# stays as it is.

"Turn on or off whether a page is written to its file when its window stops being the front window"
autosave!(e, on::Bool) = (e.autosave = on; save_settings!(e); rerun!(e, :autosave); e)
# The command palette has it as a command, which asks whether it's on or off
add_command!(autosave!, title="Turn on or off saving a page when you leave its window")

"""
The window of `e` stopped being the front window. With the setting on, each
page of the window that has changes is written to its file.
"""
left!(e) = begin
  e.autosave || return e
  write_blocks!(e)   # a block's own changes count as changes to the page
  dirty(e.buf) && writes(e.buf) && save_page!(e)   # a page from a web server keeps its changes in the window
  foreach(b -> b === e.buf || !dirty(b) || save!(b), values(e.buffers))
  redraw_in!(e, 0)   # the top bar no longer says that the page has changes
  e
end

"Have macOS tell `e` when its window `w` comes to the front, and when it stops being the front window. A window that isn't on the screen is never the front one."
watch_front!(e, w) = begin
  isempty(w.glfw) && return w
  GLFW.SetWindowFocusCallback(w.glfw[1], (_, front) -> begin
    # A name of a page's module that acts on a window acts on the front one, when it shows the page
    front && (FRONT_WINDOW[] = e; e.settings || (LAST_FRONT[] = e); return)
    try
      Base.invokelatest(left!, e)
    catch
      # A page that can't be written stays as it is, with its changes, for ⌘S to try
    end
    nothing
  end)
  w
end

const PAGE_AREA_W = 850px   # the width of the page's part of a new window: room for the page at the width it starts with, and the space beside it

"How tall the part of the main screen is that a window can use, under the menu bar and over the Dock"
screen_room() = begin
  if Sys.isapple() && Sys.ARCH == :aarch64
    # macOS gives the rectangle as four numbers: where it starts, how wide it is and how tall
    frame = with_pool() do
      screen = msg(cls("NSScreen"), "mainScreen")
      screen == C_NULL ? nothing : ccall((:objc_msgSend, libobjc), NTuple{4,Float64}, (Ptr{Cvoid}, Ptr{Cvoid}), screen, sel("visibleFrame"))
    end
    frame === nothing || return px(frame[4])
  end
  # Anywhere else, leave room for a menu bar and a Dock of the usual size
  Screen().size[2] - 110px
end

"""
The size that a new window opens at. The page's part of it, beside the
sidebar, has the shape of a sheet of A4 paper that stands up: √2 times as tall
as it's wide. So the window is that wide plus the width of the sidebar, and the
page keeps its shape while the sidebar is open. The page's part is
`PAGE_AREA_W` wide, or as big as fits on a screen that isn't tall enough for that.
`side` is how wide the sidebar is.
"""
paper_window(room::px=screen_room(), side::px=PANEL_W) = begin
  tall = min(num(PAGE_AREA_W) * √2, num(room) - 20)   # a little space under the window
  (px(round(tall / √2)) + side, px(round(tall)))
end
