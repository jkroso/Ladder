# Where Ladder opens: the file or the folder that the front window showed when you last quit it

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/window" hide_titlebar! place_window_buttons!
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
@use "./design_view" exports...
@use "./showed_before" exports...
@use "./copied_blocks" exports...

export LAST_FRONT, PLACE_FILE, keep_place!, place_editor, put_place!, quit_editor, quit_place,
       take_place!

# --- where Ladder opens --------------------------------------------------------------------
#
# Ladder opens where you were when you last quit it: the file or the folder
# that the front window showed, with the caret and the scroll where they were.
# The tabs of the files that were open in it are open again, but for those
# whose files have gone. The sidebar lists the folder that it listed then, and
# it stays closed until you open it. A window whose file and folder ⌘W closed was at the folder that
# its sidebar listed. The settings window doesn't count: Ladder opens where
# the last window in front of the others was.
#
# Ladder reads the place when it opens, deletes it, and writes it again when it
# quits. So a page that stops Ladder before it quits isn't where Ladder opens
# the next time, and the startup page shows. The startup page shows too the
# first time, and when the file or the folder has gone. A file that's named on
# the command line, as in `julia main.jl notes.md`, shows in the place's
# stead, and Ladder keeps the place for the next time. A file that macOS opens
# Ladder with, after a double-click in the Finder or the `ladder` command,
# shows after the place, so ⌘⌥← goes back to the place.

"The file that keeps where Ladder was when it last quit. A test names a file of its own here."
const PLACE_FILE = Ref(joinpath(homedir(), "Library", "Application Support", "Ladder", "place"))

"The last window that was in front, of the windows that aren't the settings window, or nothing"
const LAST_FRONT = Ref{Any}(nothing)

"""
Where the window of `e` is, for the next time Ladder opens: the file or the
folder that its page shows, the folder that its sidebar lists, its caret, its
anchor, how far it's scrolled and the files of its tabs. A window that shows no file is at the folder
that its sidebar lists. It's nothing when that's nowhere on the Mac.
"""
quit_place(e) = begin
  p = place_now(e)
  path = isempty(p.path) ? e.folder : p.path
  ispath(path) || return nothing
  (; p..., path, folder=e.folder, tabs=filter(ispath, tabs(e)))
end

"Write where the window of `e` is into the place file, for the next time Ladder opens. A place that's nowhere leaves the file as it was."
keep_place!(e) = begin
  p = quit_place(e)
  p === nothing && return nothing
  try
    mkpath(dirname(PLACE_FILE[]))
    write(PLACE_FILE[], "path=$(p.path)\nfolder=$(p.folder)\ncaret=$(p.caret[1]),$(p.caret[2])\nanchor=$(p.anchor[1]),$(p.anchor[2])\noffset=$(p.offset.value)\n" *
                        join("tab=$t\n" for t in p.tabs))
  catch
    # A file that can't be written only means that Ladder opens on the startup page
  end
  nothing
end

"""
Where Ladder was when it last quit, as `quit_place` gives it, or nothing when
there's no place or it has gone from the Mac. It deletes the place file, which
`keep_place!` writes again when Ladder quits.
"""
take_place!() = begin
  file = PLACE_FILE[]
  isfile(file) || return nothing
  kept = Dict{String,String}()
  tabbed = String[]   # a line for each tab
  for line in eachline(file)
    i = findfirst('=', line)
    i === nothing && continue
    line[1:i-1] == "tab" ? push!(tabbed, line[i+1:end]) : (kept[line[1:i-1]] = line[i+1:end])
  end
  rm(file, force=true)
  path = get(kept, "path", "")
  # A folder that the Finder shows as one file, like an app, would open in its own app
  (ispath(path) && !(isdir(path) && ispackage(path))) || return nothing
  pair(s) = (m = match(r"^(\d+),(\d+)$", s); m === nothing ? (1, 0) : (parse(Int, m[1]), parse(Int, m[2])))
  (path=path, folder=get(kept, "folder", ""), caret=pair(get(kept, "caret", "")), anchor=pair(get(kept, "anchor", "")),
   offset=px(something(tryparse(Float64, get(kept, "offset", "")), 0.0)), tabs=filter(p -> isfile(p) || news_tab(p), tabbed))
end

"An editor at the place `p` that `take_place!` gave: its file, or its folder in the page, its tabs, and the folder that its sidebar listed"
place_editor(p) = begin
  e = blank_editor()
  append!(tabs(e), p.tabs)   # the file of the place has a tab among them, or gets one at the bottom
  isdir(p.path) ? open_folder!(e, p.path) : open!(e, p.path)
  isdir(p.folder) && e.folder != p.folder && go_folder!(e, p.folder)
  e
end

"Put the caret and the scroll of the window of `e` where they were at the place `p`, when it's a file that shows"
put_place!(e, p) = (e.buf.path == p.path && !isdir(p.path) && go_place!(e, p); e)

"The window whose place Ladder keeps when it quits: the last one that was in front, of those that aren't the settings window, or else `first`"
quit_editor(first) = (f = LAST_FRONT[]; f isa Editor ? f : first)

# The close, minimise and zoom buttons line up with the sidebar's button, in the middle of the top bar
onopen(e::Editor, w::Window) = (watch_front!(e, w); watch_close!(e, w); place_window_buttons!(hide_titlebar!(w), TOPBAR_H / 2, TOPBAR_H / 2))
