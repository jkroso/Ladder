# The app's windows: the editor of each, the file or the folder that it opens, closing a file, what the whole window shows, and more windows

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" scene
@use "github.com/jkroso/UI.jl/Interface/abstract" with_theme describe add_child! window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "github.com/jkroso/UI.jl/Interface/window" set_dark!
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/media" silence!
@use "./sheet" shown
@use "./spreadsheet" moved
@use "./remote" => Remote
@use "./trash" => Trash
@use "./folders" => Folders
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
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
@use "./julia_levels" exports...
@use "./fill_view" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./schedule_view" exports...
@use "./check_view" exports...
@use "./find_view" exports...
@use "./terminal_view" exports...
@use "./slides_view" exports...
@use "./blog_page" exports...
@use "./git_page" exports...
@use "./run_code" exports...
@use "./code_names" exports...
@use "./code_nav" exports...
@use "./design_view" exports...
@use "./media_view" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...
@use "./agent/window" exports...
@use "./agent/pane" exports...
@use "./code_thing" exports...
@use "./agent/ask" exports...
@use "./news_page" exports...
@use "./folder_kinds" exports...
@use "./remote_page" exports...
@use "./sandbox" exports...
@use "./table_bar" exports...
@use "./page_as_app" exports...
@use "./showed_before" exports...
@use "./line_history" exports...
@use "./copied_blocks" exports...
@use "./markdown_app" exports...
@use "./editing" exports...
@use "./right_panel" exports...
@use "./caret_glide" exports...
@use "./page_layout" exports...
@use "./renames" exports...
@use "./centient_job" exports...
@use "./tabs" exports...
@use "./transclusion" exports...
@use "./startup_page" exports...
@use "./palette" exports...
@use "./finder" exports...
@use "./sidebar" exports...

export WELCOME, closes_to, current_folder, describe_window, leave_page!, window_body, window_over,
       window_view

# --- the app -------------------------------------------------------------------------

editor(node) = begin
  while !(node isa Editor)
    node = node.parent
  end
  node
end

"""
A part of the page joins the children of the document, so one part can find
another by a walk of the tree: up to the document, then through its children.
`layout!` empties that list and gives the document each part of the page that
shows, so the children are the parts of this page, in the order of their lines.
The paragraphs, the headings and the other blocks that are made for the lines
on screen follow them.
"""
own!(d::Document, node) = begin
  parent = getfield(node, :parent)
  (parent === nothing || (parent === d && !listed(d, node))) && add_child!(d, node)
  node
end

"True if `node` is in the list of the children of `d`"
listed(d::Document, node) = getfield(node, :prevsibling) !== nothing || getfield(d, :firstchild) === node

"""
Take every child out of the document's list. Each one keeps the document as
its parent, so a node that an earlier frame made can still reach the editor.
"""
unlist!(d::Document) = begin
  child = getfield(d, :firstchild)
  while child !== nothing
    next = getfield(child, :nextsibling)
    setfield!(child, :prevsibling, nothing)
    setfield!(child, :nextsibling, nothing)
    child = next
  end
  setfield!(d, :firstchild, nothing)
  d
end

"Open the editor on a file, or on the first Markdown file in a folder"
build_editor(path) = begin
  # An address on the web is asked for once the window is on the screen: see "a page from a web server".
  # A name like `my.notes/new.md` is a file when the folder `my.notes` is there.
  Remote.typed(path) === nothing || ispath(expanduser(path)) || isdir(dirname(abspath(expanduser(path)))) ||
    return navigate!(blank_editor(), path)
  path = abspath(expanduser(path))
  e = blank_editor()
  isdir(path) ? open_on_folder!(e, path) : open!(e, path)
  e
end

"An editor that shows no file yet"
blank_editor() = begin
  e = Editor()
  load_sheet_font()
  load_omni_font()
  load_site_font()
  window_parts(e).input = own!(e, TextInput(placeholder="Find a file", font_family=SANS, font_size=15px,
                                              look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text)))
  e
end

"""
Show the folder at `path` in a window that's opened on it: its first Markdown
file, or the folder's own page when it has no Markdown file. A folder of a
kind that shows in the page, like a desktop, shows there: see `show_opened!`.
The sidebar lists the folder, and it stays closed until you open it.
"""
open_on_folder!(e, path) = begin
  e.folder = path
  list_files!(e)
  isempty(e.files) ? show_beside!(e, path) : open!(e, e.files[1])
  e.nodes[:opened_on] = (path, e.buf.path)
  show_opened!(e)
  e
end

"""
Show the folder that the window was opened on in the page, when it's of a kind
that shows there, as a desktop is. A folder whose own page says its kind is
plain until that page has run, so the window asks again then. A window that
shows another file by then keeps that file.
"""
show_opened!(e) = begin
  on = get(e.nodes, :opened_on, nothing)
  on === nothing && return
  path, was = on
  (e.folder == path && e.buf.path == was) || return (delete!(e.nodes, :opened_on); nothing)
  d = directory(e)
  (d isa AbstractDirectory && !(d isa FS.Directory) && page_first(e, d) && page_view(e, d) !== nothing) || return
  delete!(e.nodes, :opened_on)
  open!(e, d)
  nothing
end

# The sidebar's folder, and each folder and file in it, is an object of the
# file system (FS.jl): a `File`, a `Directory`, or a kind of directory, which
# is a type under `AbstractDirectory`. Each directory makes the objects of what
# it holds, from the directory at `/` down. The sidebar asks the folder's
# object what to list and how to list it, and asks each object in the list for
# its icon, for what follows its name and for what a click on it does:
# `entries`, `folder_view`, `entry_icon`, `entry_marks` and `open!`. So code
# from the startup page gives a kind of folder its own way in the sidebar with
# a method for the folder's type, as it does for a component of a page. The
# page asks too: `page_view` gives what it shows for a file or a folder of a
# kind, `page_fills` says whether that's as wide as the window,
# `page_covers` says whether it covers the page's whole space, as a desktop does,
# and `crumb_in_page` whether it goes up to the window's top with the file's path in it.
# And the window asks: `window_view` makes all of it, `side_menu` a side menu
# in the sidebar's place and `bread_crumb` the middle of the top bar. See "the whole window".
#
#     @def struct NotesDirectory <: Ladder.AbstractDirectory end
#     Ladder.FS.kinds[fs"/Users/jake/Notes"] = NotesDirectory
#     Ladder.entry_icon(::NotesDirectory) = "box"
#
# A folder gets its kind from `FS.kinds`, by its path, or from a page of its
# own, the file `.ladder` in it: see "a folder's own page".

"""
Read the sidebar's folder again: what it lists, and the object of each one.
The objects are new each time, so a folder that code gave a kind since the
last time has that kind now.
"""
list_files!(e) = begin
  empty!(e.entries)
  d = isdir(e.folder) ? FS.get(FSPath(e.folder)) : nothing
  found = d isa AbstractDirectory ? entries(e, d) : FSObject[]
  d isa AbstractDirectory && (e.entries[e.folder] = d)
  e.listed = String[joinpath(e.folder, o.path.name) for o in found]
  foreach((path, o) -> e.entries[path] = o, e.listed, found)
  # The file finder lists the Markdown files
  e.files = String[path for (path, o) in zip(e.listed, found) if isfile(o) && ismarkdown(path)]
end

"""
What the sidebar lists of the directory `d`: its folders, then its files, each
in the order of their names. A name that starts with a dot is hidden, as it is
in the Finder, and so is a file or a folder that you ignore, unless the sidebar
shows those. .DS_Store is the Finder's own file, and never shows. What's
neither a folder nor a file isn't listed. The home folder lists the Mac's
Trash, whose folder is hidden, since the Finder has it in the Dock and Ladder
has no other place for it.
"""
entries(e, d::AbstractDirectory) = begin
  dir = string(d.path)
  trash = Sys.isapple() && dir == homedir() ? basename(Trash.trash()) : ""
  ignored = Folders.ignored()
  shows(n) = e.hidden ? n != ".DS_Store" : !left_out(joinpath(dir, n), ignored) || n == trash
  found = FSObject[]
  # macOS doesn't let Ladder read some folders, like the Trash without Full Disk Access. Those list nothing.
  names = try readdir(dir) catch; String[] end
  for name in sort!(names, by=lowercase)
    shows(name) || continue
    # A link that leads nowhere, a socket, and a file that left since the folder was read have no object to list
    o = try FS.child(d, name) catch; nothing end
    o === nothing || push!(found, o)
  end
  [filter(isdir, found); filter(isfile, found)]
end

"The object of the sidebar's folder, or nothing when no folder is there"
directory(e) = get(e.entries, e.folder, nothing)

"The object of the folder or the file at `path`: the one that the sidebar lists, or else a new one. Nothing when nothing is there."
object(e, path) = get(() -> ispath(path) ? FS.get(FSPath(path)) : nothing, e.entries, path)

"The name that `o` has in the sidebar: its own name, unless its kind has a better one, as the Trash has"
entry_name(o::FSObject) = basename(rstrip(string(o.path), '/'))

"The icon that `o` has in the sidebar"
entry_icon(o::AbstractDirectory) = "folder"
entry_icon(o::FSObject) = file_icon(string(o.path))

"""
What follows the name of `o` in its row of the sidebar, like how many emails of
a folder aren't read: nodes, or `()`. A kind of folder has a method with three
arguments to say it for each thing that it holds: `entry_marks(e, d, o)`,
where `d` is the directory that holds `o`.
"""
entry_marks(e, o::FSObject) = entry_marks(e, o.parent, o)
entry_marks(e, d, o) = ()

"""
How the sidebar lists the directory `d`: `(list=..., bar=...)`. `list` is a
node that shows in place of the tree of what `entries` gives, or nothing to
leave the tree. `bar` is a node for a line over the list, or nothing. `d` is
nothing when the sidebar's folder isn't there.
"""
folder_view(e, d) = (list=nothing, bar=nothing)

"""
What the page shows for `o`, a file or a folder, in place of Ladder's own
viewer: a node, or nothing to leave Ladder's viewer. A kind of folder has a
method of this to show itself in the page, as a folder of films shows their
posters, or to show a file that it holds its own way. A folder shows in the
page after `open!(e, path)` with the folder's path.
"""
page_view(e, o) = nothing

"True when what `page_view` gives for `o` is as wide as the window has room for, as a table is, and not as wide as a page's text"
page_fills(e, o) = false

"""
True when a window that's opened on the folder `d` shows what `page_view`
gives for it. It's false for a kind of folder whose first page of text is the
better start, as a folder that git keeps is: its Readme shows.
"""
page_first(e, d) = true

"""
The object of the file or the folder that the page shows in a viewer, or
nothing when it isn't there. One that the sidebar doesn't list is found again
after a second, and not in each frame.
"""
page_object(e) = begin
  path = e.buf.path
  (e.buf.view == :file && !isempty(path)) || return nothing
  haskey(e.entries, path) && return e.entries[path]
  kept = get(e.nodes, :page_object, nothing)
  kept !== nothing && kept[1] == path && time() - kept[2] < 1 && return kept[3]
  o = try object(e, path) catch; nothing end
  e.nodes[:page_object] = (path, time(), o)
  o
end

"""
True when what `page_view` gives for `o` covers the page's whole space in the
window: from the sidebar to the window's right edge, and from the top bar to
the bottom. It has no space round it, and the page doesn't scroll. A desktop
covers the page so, with its wallpaper.
"""
page_covers(e, o) = false

"""
True when what `page_view` gives for `o` runs up to the top of the window, and
shows the file's path itself, as a SolidCraft design does in its toolbar. The
top bar then has only its left end, with its buttons, over the sidebar. The
page has the rest of the bar's room, and shows the path that the bar would
have with `page_crumb`. Only a page that covers the page's space has it: see
`page_covers`.
"""
crumb_in_page(e, o) = false

"True when what `page_view` gives for `o` has changes that aren't in its file. The name of the file says \"— edited\" then."
page_edited(e, o) = false

"""
What shows in a panel at the right of the window, beside what `page_view`
gives for `o`: a node, or nothing for no panel. The page of a repository has
git's panel there. The panel runs from the top of the window to the bottom, as
the sidebar does, and the top bar's button at its right end hides it. A page
that covers the page's space (see `page_covers`) leaves it room, and any other
page gets narrower beside it, as a folder in a repository does.
"""
page_side(e, o) = nothing

"""
Take a step back in what `page_view` gives for `o`, before the window shows the
file that showed before: true when it took one. The page of a repository goes
from a commit back to the repository's files.
"""
page_back!(e, o) = false

"""
What shows under the text of the page `o`, which the directory `d` holds: a
node, or nothing. A kind of folder has a method of this to add to each page
that it holds, as a folder of notes lists the pages that link to the page.
It's as wide as the page's text, `e.width`, and it scrolls with the text.
"""
page_foot(e, d, o) = nothing

"""
What shows in place of the card of the front matter of the page `o`, which the
directory `d` holds, while the caret isn't in it: a node, nothing for the
card, or `false` for nothing at all. A kind of folder has a method of this to
show the front matter of the pages that it holds its own way, as a blog shows
a book review's title and stars, and shows none on a folder's own page.
`rows` are the front matter's keys, each as its line, the key and what it's
set to, as it's written.
"""
matter_view(e, d, o, rows) = nothing

"""
What shows in place of the table in lines `from` to `to` of the page `o`,
which the directory `d` holds, while the caret isn't in it: a node, or
nothing for the table. A kind of folder has a method of this to show a table
of its pages its own way, as a blog on a web server shows the table of a
folder's files as the list that the folder has on the Mac.
"""
table_view(e, d, o, from, to) = nothing

"""
The object of the page of text that shows, or nothing. One that the sidebar
doesn't list is found again after a second, and not in each frame. A page
from a web server is a `WebPage`, in the web folders that it's in.
"""
text_object(e) = begin
  path = e.buf.path
  (at = web_address(path); isempty(at)) || return web_page(at)
  haskey(e.entries, path) && return e.entries[path]
  kept = get(e.nodes, :text_object, nothing)
  kept !== nothing && kept[1] == path && time() - kept[2] < 1 && return kept[3]
  o = try object(e, path) catch; nothing end
  e.nodes[:text_object] = (path, time(), o)
  o
end

"What shows under the text of the page, or nothing: see `page_foot(e, d, o)`. Only a page of Markdown that shows whole has it."
page_foot(e) = begin
  b = e.buf
  (b.view == :markdown && !isempty(b.path) && !filled(e) && slideshow(e) === nothing) || return nothing
  o = text_object(e)
  o === nothing ? nothing : with_theme(() -> page_foot(e, o.parent, o), component_theme(e.zoom))
end

"True when a kind of folder or of file shows the page its own way, as wide as the window has room for"
own_page(e) = (o = page_object(e); o !== nothing && page_fills(e, o))

"True when the folder or the file that shows covers the page's whole space with a view of its own"
page_covered(e) = (o = page_object(e); o !== nothing && page_covers(e, o))

"What covers the page's whole space, when the folder or the file that shows is of a kind that covers it, or nothing"
page_cover(e) = begin
  o = page_object(e)
  (o !== nothing && page_covers(e, o)) || return nothing
  # The Box is made inside the theme too. A node that `page_view` gives, like a SolidCraft design's
  # editor, is described when it's put in the Box, and it takes the theme of that moment.
  with_theme(component_theme(e.zoom)) do
    own = page_view(e, o)
    own === nothing ? nothing : Box(width(grow=grow), height(grow=grow), Alignment.Start, own)
  end
end

"True when the page that shows runs up to the top of the window, with the file's path in it: see `crumb_in_page(e, o)`"
crumb_in_page(e) = (o = page_object(e); o !== nothing && !filled(e) && page_covers(e, o) && crumb_in_page(e, o))

"""
How much room the page leaves at its top for the top bar. A page that shows
the file's path itself leaves none: it starts at the top of the window, or in
agent mode at the top of the page's card.
"""
under_bar(e) = crumb_in_page(e) ? (agent_shows(e) ? PAGE_CARD_GAP : 0px) : above_page(e)

"""
The path of the file, for a page that shows the path itself (see
`crumb_in_page`): what `bread_crumb` gives, which is the file's name that
opens into its path, as the top bar has it. It has `room` at most, and it lies
on the colour `ground`, which a pinned path has under it too.
"""
page_crumb(e, room, ground) = begin
  bar_space(e).title = room
  bar_space(e).ground = ground
  bread_crumb(e, window_object(e))
end

"""
How far past the sidebar's edge the left end of the top bar reaches over the
page: the room of the Mac's close, minimise and zoom buttons and of the bar's
own buttons, while the sidebar is too narrow for them. A page that shows the
path itself leaves this room at its top left. A bar that hides takes none.
"""
bar_corner(e) = hides_bar(e) ? 0px : bar_space(e).past_side

"True when the page that shows has changes that aren't in its file: see `page_edited(e, o)`"
page_edited(e) = (o = page_object(e); o !== nothing && page_edited(e, o))

"How wide and how tall the page's space in the window is: beside the sidebar, and under the top bar"
page_room(e) = begin
  w, h = window_size(e)
  # In agent mode, the page is on a card between the two panes
  agent_shows(e) && return (page_span(e)[2], max(h - under_bar(e) - PAGE_CARD_GAP, 1px))
  side = lowered(e) === nothing ? side_w(e) : 0px
  (max(w - side, 1px), max(h - under_bar(e), 1px))
end

"""
Where the page's space is across the window: its left edge, and how wide it
is. It's beside the sidebar. In agent mode it's the page's card, between the
agent's pane and the outline.
"""
page_span(e) = begin
  agent_shows(e) && return page_card_span(e)
  w, _ = window_size(e)
  side = lowered(e) === nothing ? side_w(e) : 0px
  (side, w - side)
end

"""
Show the file at `path`. A file that's already open keeps its changes. The
file that leaves goes on the list that `go_back!` reads, unless `record` is false.
A folder shows too, when its kind has a method of `page_view`. The sidebar
then lists the folder itself, as a click on it in the sidebar does, so the
sidebar's path and the top bar's end with the same folder, as going back to it
shows too. For a file, the sidebar lists the folder that it's in. A file that shows
gets a tab in the sidebar, if it hasn't one: see "the files that are open, as tabs".
"""
open!(e, path; record=true) = begin
  # A link in a part of another page opens its page in the window, not in the part
  hosted(e) === nothing || return open!(top_editor(e), path; record)
  # A page from a web server that isn't here yet is asked for, and shows when it has come
  isremote(path) && !haskey(e.buffers, path) && return get_page!(e, path; record)
  leave_page!(e, path; record)
  e.buf = get!(e.buffers, path) do
    isfile(path) ? (in_browser(path) ? web_buffer(path) : load(path)) : isdir(path) ? Buffer(path=path, view=:file) : Buffer(path=path)
  end
  add_tab!(e)   # the file stays open as a tab in the sidebar until ⌘W closes it
  delete!(e.nodes, :new_tab)   # a file that shows in a new tab takes the tab's place
  # The sidebar lists a folder that shows, so its path ends where the top bar's does, and the folder that a file is in. It goes on
  # listing the folder that it lists while a page from a web server shows, or a view's copy of a file from one.
  at = isdir(path) ? path : dirname(path)
  if e.folder != at && isempty(web_address(path))
    e.folder = at
    list_files!(e)
  end
  e.scroll.offset = e.buf.offset
  e.popup = :none
  e.goal = nothing
  w = window_of(e)
  w === nothing || focus(e)
  e
end

"""
Get the window ready to show the page at `path`, or no page when `path` is "".
The page that leaves keeps what its blocks hold and where it was scrolled to.
It goes on the list that `go_back!` reads, unless `record` is false.
"""
leave_page!(e, path; record=true) = begin
  # A sound that the last page was playing stops. A new window has no last page, and another window's sound plays on.
  isempty(e.buffers) || silence!()
  write_blocks!(e)   # the page that leaves keeps what its blocks hold
  e.buf.offset = e.scroll.offset
  from = e.buf.path
  from == path || forget_ticked!(e)   # an item that was ticked in a list of what's found leaves that list
  from == path || delete!(e.nodes, (:html, from))   # the page of an HTML file ends, with its scripts
  from == path || leave_design!(e, from)            # and a design with no changes gives up SolidCraft's program
  # A new file ends the list of files to go forward to, as a new address does in a web browser
  record && !isempty(from) && from != path && (push!(e.back, from); empty!(e.ahead))
  e
end

# --- closing a file ----------------------------------------------------------------------
#
# ⌘W closes the file that the window shows, and its tab in the sidebar. The
# tab under it shows, or the one above when it was the last tab. ⌘W on the
# last tab shows the folder that its file is in, as a click on that folder in
# the sidebar's trail does, but it opens no file: a blog's folder shows only
# its list, not its Readme. ⌘W on a folder's page shows the tab that showed
# last, and with no tabs open it closes the folder, and the window stays open
# with no file in it. ⌘W in a window that shows no file closes the window, and
# Ladder quits when its last window closes. So three presses of ⌘W close the
# window of a file that's the only tab: the file, its folder, then the window.
# The settings window closes at once while it shows a page of the settings. A
# file that closes keeps its changes, and ⌘⌥← shows it again, in a new tab.

"True when the window shows no file, because ⌘W closed the page that it showed"
nofile(e) = isempty(e.buf.path) && e.buf.fixed

"""
The folder that the window shows when ⌘W closes its file, or nothing. A
folder's own page, a page that isn't a file on the Mac, and a file in a
folder that the Finder shows as one file, like an app, have none.
"""
closes_to(e) = begin
  path = e.buf.path
  (isabspath(path) && !isdir(path)) || return nothing
  folder = dirname(path)
  isdir(folder) && !ispackage(folder) ? folder : nothing
end

"""
Close the file that the window shows, and its tab, and show the tab under it.
With no other tab open, show the folder that the file is in. A page with no
such folder closes to no file. The page keeps its changes, and goes on the
list that `go_back!` reads.
"""
close_file!(e) = begin
  delete!(e.nodes, :new_tab)   # a new tab closes too
  next = tab_after_close!(e)
  next === nothing || return show_tab_page!(e, next)
  folder = closes_to(e)
  # The folder shows its list, not a file of its own like a blog's Readme, or ⌘W on that Readme would show it again
  folder === nothing || return open_folder!(e, folder, own=false)
  show_no_file!(e)
end

"Show no file in the window: an empty page that nothing can be typed in"
show_no_file!(e) = begin
  leave_page!(e, "")
  e.buf = Buffer(fixed=true)
  e.scroll.offset = 0px
  e.popup = :none
  e.goal = nothing
  e
end

"""
What ⌘W does: close the file that the window shows, or the window when it
shows a page of the settings, or no file and no tab is open.
"""
close_file_or_window!(e, w) = (issettings(e) || (nofile(e) && isempty(tabs(e)) && !new_tab(e))) ? (closes!(e, w) && close(w)) : close_file!(e)

# --- the whole window ---------------------------------------------------------------------

describe(e::Editor) = begin
  scene = describe_window(e)
  # A folder's page that waits runs when the frame is made, so that no part of a frame meets code that's
  # newer than the frame. The next frame is drawn with what the page loaded.
  isempty(FOLDER_PAGES_DUE) || run_folder_pages!()
  # A web folder's page runs then too, once its site may run code. See "a web folder's own page".
  isempty(WEB_PAGES_DUE) || run_web_folder_pages!()
  ask_sandbox!(e)
  haskey(e.nodes, :reload_ask) && ask_reload!(e)
  scene
end

"""
Keep line `line` of the page of `e` at `top` under the top of the page's space
in the window, when the next frame has laid the page out. So a line that the
window jumps to goes near the top of the window, and text that wraps again
stays where it was. With nothing for `line`, the next frame leaves the page
where it finds it.
"""
hold!(e::Editor, line, top) = (next_frame(e).hold = (Int(line), convert(px, top)); nothing)
hold!(e::Editor, ::Nothing) = (next_frame(e).hold = nothing; nothing)

"What the window shows, and what Ladder does in each frame before it"
describe_window(e::Editor) = begin
  # A page of a blog looks as the blog's site does, whatever the theme. Text laid out in the other look is laid out again.
  look = page_look(e)
  look == e.look || (e.look = look; restyle!(e))
  colours_over[], pane_dark[] = nothing, false   # the page's colours, whatever the last frame left
  use!(look == :site ? SITE : look == :news ? NEWS : getproperty(THEMES, e.theme))
  use_code_font!(e)
  # What each part of Ladder does in this frame, before the page is laid out. Each one that's named here has an
  # order, and its line says what it must come before or after. Work with no order has no line here: its own file
  # adds it with `each_frame!`, and `frame_ticks!` does it. See additions.jl.
  side_tick!(e)   # first: the side menu of this frame, and how wide it is. All that asks how wide the page is comes after it.
  win = window_of(e)
  if win !== nothing && e.applied != look_key(e)
    set_dark!(win, look_key(e) == :night)
    e.applied = look_key(e)
  end
  receive!(e)   # a file that macOS asked for shows: before all that works on the page that shows
  await_default!(e)
  remote_tick!(e)   # a page from the web that came shows: before `refresh!`, and before all that works on the page that shows
  moved = refresh!(e.buf)
  moved === nothing || (stay!(e, moved); fresh!(e, moved))
  # The bars beside the lines that just changed fade, so the window is drawn again while they show
  isempty(fresh(e)) || redraw_in!(e, 1/30)
  find_tick!(e)     # it moves the caret and scrolls to what's found: before blocks_tick! and zoom_tick!, which keep the page where it was, and before confine!
  sound_tick!(e)    # it puts the words of a recording in the text: before inline_tick! and each other tick that looks for a change to the text
  blocks_tick!(e)   # each block writes its lines, and one that fills the window keeps the page where it was: after find_tick!, before inline_tick!
  point_tick!(e)    # it reads where the last frame put each line: before layout!
  scrub_tick!(e)    # a click on a number puts the caret there: before confine!, slide_tick! and line_tick!
  inline_tick!(e)   # after all that changes the text here, and before file_checks_tick!, which runs the checks again when a sum has a new value
  confine!(e)   # while the lines of a block fill the window, the caret stays in them: after all that moves the caret
  job_tick!(e)      # its words hang from a button of the top bar: before bar_tick!, which keeps the bar out while something hangs from it
  update_tick!(e)   # the blocks of the settings page that show an update run again: before layout!
  folder_pages_tick!(e)   # it can show a folder in the page: before all from zoom_tick! down that asks which file shows
  startup_tick!(e)  # the words under the top bar: after remote_tick!, whose words it shows in this frame, and before bar_tick!, since it reads where the bar was
  frame_ticks!(e)   # the work with no order, which each file added with `each_frame!`: before bar_tick!, as words of it can hang from the bar
  foreach(f -> f(e), values(EACH_FRAME))   # what code from the startup page does in each frame, like a look for new email
  zoom_tick!(e)     # after all that scrolls or shows another file: the page under what fills the window stays where it was
  slide_tick!(e)    # after all that moves the caret or changes the text: the caret's slide shows, and the slides have no caret and no sidebar
  screen_tick!(e)   # before bar_tick!: a bar that hides in full screen goes in the frame that the window fills its screen
  bar_tick!(e)      # after all whose words hang from the bar, and after screen_tick!
  run_tick!(e)      # it takes what the page's code came to: before file_checks_tick!, which runs the checks again after code ran
  term_tick!(e)     # the terminals that the window doesn't show: after all that can show another file
  # These three give the agents' tasks their turn, and what one finds depends on the ones before it. ask_tick! runs the code
  # that an agent changed and can put its answer in the page: before the checks, line_tick! and app_tick!. chat_tick! sees to
  # the sessions that the window doesn't show: after all that can show another file.
  ask_tick!(e)
  session_tick!(e)
  chat_tick!(e)
  live_checks_tick!(e)   # before file_checks_tick!: the checks of a function that it ran again run in the same frame. It reads the checks that the last frame found.
  file_checks_tick!(e)   # after all that changes the text or runs code
  line_tick!(e)     # after all that moves the caret, scrolls or changes the text: git's words about a line go when one of those happens
  app_tick!(e)      # after all that changes the text: it writes the page, and keeps the caret and the sidebar away
  layout!(e)
  inline_diff!(e)   # room for the lines that went from the file, while the window shows what changed in it
  # A page whose long lines don't wrap scrolls sideways as far as its longest line goes, and no further when the window grows
  if !wraps(e)
    e.reach = maximum(it -> it.content isa Flow ? extent(it.content) : 0px, e.layout, init=0px)
    scroll_sideways!(e, 0px)
  end
  # A live block that changed the size of the text stays where it was in the window
  asked = next_frame(e)
  hold, asked.hold = asked.hold, nothing
  hold === nothing || (e.scroll.offset = max(0px, item(e, hold[1]).top - hold[2]))
  e.reveal && (reveal!(e); e.reveal = false)
  reveal_part!(e)   # the caret of a part of another page that has the keyboard
  # The window is drawn again as soon as a key or the mouse does something, so
  # typing shows without waiting for a frame that was already under way. Between
  # times it only wakes to blink the caret.
  if win !== nothing
    # While the sidebar or the panel at the right slides, the top bar's buttons slide, the command palette slides, or the caret moves to a new place, each frame is drawn as soon as it can be
    win.animating = sliding(e) || right_sliding(e) || clearing(e) || gliding(e) || palette_moving(e) || bar_sliding(e)
    # A part of a live block that has the keyboard, like a text field, blinks its own caret
    soon, asked.soon = asked.soon, false
    win.wake = soon ? 0.05 : win.focus === e ? 0.51 - mod(time() - e.blink, 0.5) :
               win.focus === nothing ? 0.0 : 0.25
  end
  window_view(e, window_object(e))
end

# The window is made by `window_view`, for the object of the file or the folder
# that the window shows. So a kind of folder, or a kind of file, can have a
# window of its own, as it can have a page of its own with `page_view`. Two
# parts of Ladder's own window are functions of the object too, for a kind that
# wants only that part its own way: `side_menu` is the side menu, which takes
# the sidebar's place, and `bread_crumb` is what the middle of the top bar shows.
#
#     @def struct ShopDirectory <: Ladder.AbstractDirectory end
#     Ladder.side_menu(e, d::ShopDirectory) = shop_menu(e, d)        # while the window shows the folder
#     Ladder.side_menu(e, d::ShopDirectory, o) = shop_menu(e, d)     # while it shows a thing that the folder holds
#
# Each of the three has a method with three arguments, as `entry_marks` has:
# `d` is the directory that holds `o`. The folders in a folder of a kind have
# the kind that `FS.kind` gives them, so a kind can keep its window all the way down.

"""
The object that the window is about: the file or the folder that it shows. A
window that shows no file is about the folder that its sidebar lists. Nothing
when there's no such object.
"""
window_object(e) = begin
  o = e.buf.view == :file ? page_object(e) : text_object(e)
  o === nothing && isempty(e.buf.path) ? directory(e) : o
end

"""
All that the window shows while it's about `o`: a node as big as the window.
Ladder's own is `window_body(e)` with `window_over(e)` over it. A kind of
folder has a method of this to make the whole window itself: `window_view(e, d)`
for the folder, and `window_view(e, d, o)` for each thing `o` that it holds.
Such a window needs `window_over(e)...` at its end to keep the top bar, the
file finder and the command palette.
"""
window_view(e, o) = window_view(e, o.parent, o)
window_view(e, ::Nothing) = window_view(e, nothing, nothing)
window_view(e, d, o) = Stack(width(grow=grow), height(grow=grow), Alignment.Start, name="Editor", window_body(e), window_over(e)...)

"""
The sidebar, the page and the panel at the right, side by side. The sidebar
runs from the top of the window to the bottom, and the top bar lies over the
top of the sidebar and the page.
"""
window_body(e) = agent_shows(e) ? agent_body(e) : Row(width(grow=grow), height(grow=grow), Alignment.Start, background(colours.bg),
  # The lines of a block that fill the window take the sidebar's room too
  (side_w(e) > 0px && lowered(e) === nothing && !as_app(e) ? (side_part(e),) : ())...,
  Column(width(grow=grow), height(grow=grow), Alignment.Start,
    Box(width(grow=grow), height(under_bar(e))),   # under the top bar
    node!(Page, e, :page)),
  right_panel(e)...)

"""
What lies over the sidebar and the page, from the lowest to the highest: the
edge of the sidebar that you drag, what floats over the page, the top bar,
and last the file finder or the command palette.
"""
window_over(e) = begin
  # The command palette has nothing behind it that dims the page, and it shows while it slides down after it closes
  popup = palette_shows(e) ? (palette(e),) : e.popup == :none ? () : (node!(Backdrop, e, :backdrop), finder(e))
  (panel_edge(e)..., tablebar(e)..., put_back_over(e)..., outcome_over(e)..., callbox(e)..., suggestbox(e)..., findbar(e)..., sound_over(e)..., fill_over(e)..., task_over(e)..., slides_over(e)..., takeoff_over(e)..., zoom_over(e)...,
   (screening(e) || bar_shown(e) == 0 ? () : (bar_back(e)..., node!(TopBar, e, :topbar)))...,   # a video that fills the screen is all that the window shows
   popup...)
end

# --- windows ------------------------------------------------------------------------------
#
# Ladder can have more than one window open, each with an editor of its own.
# The settings page opens in a window of its own, so the page you were working
# on stays as it was. ⌘W closes the file that a window shows, and then the
# window. Ladder quits when its last window closes. See "closing a file".

const WELCOME = joinpath(@__DIR__, "pages", "welcome.md")

"""
Make a window for the editor `e`. `show_window!` puts it on the screen. Until
it closes, `e` gets each setting that changes in another window.
"""
window!(e; kw...) = begin
  w = Window(e; kw...)
  push!(editors, e)
  focus(e)
  w
end

"""
Put the window `w` on the screen, if the window `by` that asked for it is on
the screen. A test's window isn't, so the windows that it opens aren't either.
"""
show_window!(w, by) = (by !== nothing && isopen(by) && open(w); w)

onclose(e::Editor, ::Window) = (Base.filter!(o -> o !== e, editors); close_designs!(e); close_terminals!(e); close_agent!(e); close_chats!(e); close_asks!(e); nothing)

"""
A window that shows the Markdown file or the folder at `path`, with the
settings of the editor `like`. `show_window!` puts it on the screen.
"""
page_window(path, like) = begin
  e = build_editor(path)
  same_settings!(e, like)
  e.remember = like.remember
  e.size = paper_window(screen_room(), e.side)
  window!(e, title="Ladder", size=e.size)
end

"""
The folder that the window of `e` is in: the folder that its page shows, or
the folder of the file that it shows. A window with no file is in the folder
that its sidebar lists.
"""
current_folder(e) = begin
  path = e.buf.path
  isdir(path) && return path
  !isempty(path) && isdir(dirname(path)) && return dirname(path)
  isdir(e.folder) ? e.folder : homedir()
end

"""
⌘N: open a new window on the folder that the window of `e` is in. Its page
shows the folder, as a click on the folder in the top bar's path does, and its
sidebar is closed. It's as big as the window of `e`, and a little lower and to
the right, as the Mac puts a new window. It gives the new window's editor.
"""
new_window!(e) = begin
  e = top_editor(e)
  folder = current_folder(e)
  shown = blank_editor()
  same_settings!(shown, e)
  shown.remember = e.remember
  show_path!(shown, folder)
  by = window_of(e)
  size, at = by === nothing ? (paper_window(screen_room(), e.side), (0px, 0px)) :
                              ((by.size[1], by.size[2]), (by.position[1] + 30px, by.position[2] + 30px))
  shown.size = size
  show_window!(window!(shown, title="Ladder", size=size, position=at), by)
  shown
end
