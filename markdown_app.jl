# The app for Markdown files: the button that makes Ladder the app that opens them, and the files that macOS asks it to open

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" open_url redraw_in!
@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring with_pool
@use "./app/facts" APP_ID
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
@use "./views" exports...
@use "./live_view" DefaultAsked

export MARKDOWN_TYPE, app_path, await_default!, inbox, markdown_type, open_outside, open_outside!,
       outside_button, receive!

# --- the app for Markdown files ----------------------------------------------------------
#
# macOS keeps, for each kind of file, the app that opens it when you
# double-click one. The settings page has a button that makes Ladder that app
# for Markdown files. macOS then tells Ladder which file to open with a
# message, not with an argument, so the app keeps a list of the files it's
# been asked for and the window opens them.

const MARKDOWN_TYPE = "net.daringfireball.markdown"   # macOS's name for the kind of file that Markdown is

"macOS's object for the kind of file that Markdown is"
markdown_type() = begin
  # The class is in a framework that a window loads, but a test without a window hasn't
  ccall(:dlopen, Ptr{Cvoid}, (Cstring, Cint), "/System/Library/Frameworks/UniformTypeIdentifiers.framework/UniformTypeIdentifiers", 1)
  msg(cls("UTType"), "typeWithIdentifier:", nsstring(MARKDOWN_TYPE))
end

"Where the Ladder app is on this Mac, or an empty string when it isn't installed"
app_path() = Sys.isapple() ? with_pool(() -> url_path(msg(workspace(), "URLForApplicationWithBundleIdentifier:", nsstring(APP_ID)))) : ""

"The app that opens a Markdown file when you double-click one, or an empty string when macOS can't say"
markdown_app() = begin
  Sys.isapple() || return ""
  with_pool() do
    type = markdown_type()
    type == C_NULL ? "" : url_path(msg(workspace(), "URLForApplicationToOpenContentType:", type))
  end
end

"""
Open the file at `path` in the app that the Mac uses for it. A file that the
Mac has no app for shows in the Finder.
"""
open_outside(path) = begin
  isfile(path) || return
  isempty(opener(path)) && Sys.isapple() ? show_in_finder(path) : open_url(path)
  nothing
end

"Open the file that the page shows in the app that the Mac uses for it"
open_outside!(e) = (open_outside(e.buf.path); e)

"""
The top bar's button that opens the file of a page that's only shown in the
app that the Mac uses for it, since that app can change it. A folder, or a
file that no app opens, has no button: it would only show it in the Finder.
Nor has an HTML file: its app is a web browser, and Ladder is one for it.
"""
outside_button(e) = isempty(opener(e.buf.path)) || html_page(e.buf) ? () : (button(e, :outside, "box-arrow-up-right"),)

"""
Ask macOS to make Ladder the app that opens Markdown files. macOS shows a
dialog of its own that asks you to confirm, and changes the app when you say
yes. It's true when macOS was asked. It's false when the Ladder app isn't
installed on this Mac, because macOS would then ask about an app with no name.
"""
make_default!() = begin
  (Sys.isapple() && !isempty(app_path())) || return false
  with_pool() do
    # 0xffffffff is every way of opening a file: to read it, to change it and so on
    ccall((:LSSetDefaultRoleHandlerForContentType, "/System/Library/Frameworks/CoreServices.framework/CoreServices"), Int32,
          (Ptr{Cvoid}, UInt32, Ptr{Cvoid}), nsstring(MARKDOWN_TYPE), 0xffffffff, nsstring(APP_ID)) == 0
  end
end

"""
Look for your answer to macOS's dialog, twice a second for two minutes after
the button on the settings page. When the app for Markdown files changes, the
blocks that show which app it is run again.
"""
await_default!(e) = begin
  kept = state_of(e, DefaultAsked)
  asked = kept.asked
  asked === nothing && return
  at, before, checked = asked
  now = time()
  if now - checked >= 0.5
    if markdown_app() != before
      kept.asked = nothing
      return rerun!(e, :app)
    end
    now - at > 120 && return (kept.asked = nothing)
    kept.asked = (at, before, now)
  end
  # Nothing else may happen in the window while the dialog is open, so ask for the next look
  redraw_in!(e, 0.5)
end

"""
The files that macOS asked Ladder to open, which it hasn't opened yet. macOS
asks when you double-click a Markdown file in the Finder or drop one on
Ladder's icon. The app puts its own list here.
"""
const inbox = Ref(String[])

"""
Show the last file or folder that macOS asked for. A window shows one file, so
that's the one to show. The settings window keeps its page: another window
shows the file, and with no other window open, a new one does.
"""
receive!(e) = begin
  files = inbox[]
  isempty(files) && return
  if issettings(e)
    i = findfirst(o -> !issettings(o), editors)
    if i === nothing
      path = pop!(files)
      empty!(files)
      ispath(path) && show_window!(page_window(path, e), window_of(e))
    else
      # That window may have nothing else to draw for, so ask it to draw
      w = window_of(editors[i])
      w === nothing || stale!(w)
    end
    return
  end
  path = pop!(files)
  empty!(files)
  isdir(path) ? open_on_folder!(e, path) : isfile(path) && open!(e, path)
  touch!(e)
end
