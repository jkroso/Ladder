# The menu of a file or a folder in the sidebar, the name that a rename types, and the commands of a file and of a folder

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered
@use "github.com/jkroso/UI.jl/Interface/window" system_menu
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" => Tree
@use "./eml" => Eml
@use "./folders" => Folders
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use InteractiveUtils: clipboard
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
@use "./desktop_page" exports...
@use "./page_extras" exports...
@use "./agent/pane" exports...
@use "./showed_before" exports...
@use "./markdown_app" exports...
@use "./renames" exports...
@use "./tabs" exports...
@use "./commands" exports...

export FOLDER_MENU, copy_path, duplicate!, finish_rename!, new_folder!, new_terminal!, repath,
       stop_rename!, wiki_link, NewlyMade

# --- the menu of a file ---------------------------------------------------------------------
#
# A right-click on a file or a folder in the sidebar, or on the name of the file
# that shows in the top bar, shows a menu that renames it, duplicates it,
# copies its path, shows it in the Finder or moves it to the Trash. A folder's
# menu also makes a new page or a new folder in it, and opens it in a new
# window. A file's menu also opens it in a new window or in the app that the
# Mac uses for it, and copies a wiki link to it. A right-click under the files
# shows the menu of the sidebar's own folder. It's a menu of macOS's own, so it
# looks and works like the other menus on the Mac. A window that isn't on a
# screen, like the one a test makes, gets a menu that Ladder draws.

"The menu of the sidebar's own folder, for a right-click under the files that it lists"
const FOLDER_MENU = ["New Page", "New Folder", "New Terminal", "New Agent Session", "-", "Copy Path", "Show in Finder"]

"""
Show the menu of the file or the folder at `path`. `at` is where you
right-clicked: its name in the `:sidebar` or in the `:title` of the top bar,
or its icon on a `:desktop`. Rename puts the text field there.
"""
file_menu!(e, w, path; at=:sidebar, items=file_menu(path)) = begin
  act(i) = file_act!(e, path, get(items, i, ""); at)
  # A new file that isn't saved yet isn't on the disk, so the Finder can't show it, and there's nothing to copy, to open or to ignore
  off = ispath(path) ? Int[] : findall(in(("Open in New Window", "Duplicate", "Show in Finder", "Ignore")), items)
  system_menu(w, items, act; off) || drawn_menu!(w, items, act; off)
  nothing
end

"Do to the file or the folder at `path` what the item `name` of its menu says"
file_act!(e, path, name; at=:sidebar) =
  name == "New Page" ? new_page!(e, path) :
  name == "New Folder" ? new_folder!(e, path) :
  name == "New Terminal" ? new_terminal!(e, path) :
  name == "New Agent Session" ? new_agent_session!(e, path) :
  name == "Open in New Window" ? (show_window!(page_window(path, e), window_of(e)); nothing) :
  startswith(name, "Open in ") ? open_outside(path) :
  name == "Rename" ? rename!(e, path; at) :
  name == "Duplicate" ? duplicate!(e, path) :
  name == "Copy Path" ? clipboard(path) :
  name == "Copy Link" ? clipboard(wiki_link(path)) :
  name == "Show in Finder" ? show_in_finder(path) :
  name == "Add to Favourites" ? Folders.favourite!(path) :
  name == "Remove from Favourites" ? Folders.unfavourite!(path) :
  name == "Ignore" ? ignore!(e, path) :
  name == "Stop Ignoring" ? ignore!(e, path, false) :
  name == "Move to Trash" ? trash!(e, path) : nothing

"Open a Finder window on the folder of the file at `path`, with the file selected"
show_in_finder(path) = (Sys.isapple() && ispath(path) && run(pipeline(`open -R $path`, stdout=devnull, stderr=devnull), wait=false); nothing)

"""
Show the menu of the file or the folder in the sidebar that the mouse is over,
if it's over one, or of the file of a tab. Under the files, it's the menu of
the sidebar's own folder, unless a kind of folder lists what it holds its own way.
"""
file_menu!(e, w) = begin
  e.panel || return
  # The mouse finds the item of the row that it's over, in either tree
  tab = Tree.item_under(tab_tree(e), w)
  tab !== nothing && tab.parent === tab_tree(e) && return tab_menu!(e, w, tab.firstchild.path)
  tree = file_tree(e)
  item = Tree.item_under(tree, w)
  if item === nothing
    (w.mouse[2] > bar_bottom(e) && isdir(e.folder) && ishovered(node!(Sidebar, e, :sidebar)) && files_listed(e)) || return
    return file_menu!(e, w, e.folder, items=[FOLDER_MENU; "-"; favourite_item(e.folder)])
  end
  item.firstchild isa FileLabel || return
  path = item.firstchild.path
  # The tree takes the keyboard, so the file that the menu is for stays marked
  focus(tree)
  tree.focused = item
  file_menu!(e, w, path)
end

"""
A path in the folder `dir` for something new called `base`, with the ending
`ending`, that nothing has yet: `base` itself, or else `base` with 2, 3 and so
on after it, as the Finder does. A page that's open and not saved yet has its path.
"""
free_path(e, dir, base, ending="") = begin
  taken(p) = ispath(p) || haskey(e.buffers, p)
  path = joinpath(dir, base * ending)
  n = 2
  while taken(path)
    path = joinpath(dir, "$base $n$ending")
    n += 1
  end
  path
end

"Make a new empty page in the folder `dir` and show it. Its name is a text field in the sidebar, to type the name it should have."
new_page!(e, dir) = begin
  path = free_path(e, dir, "Untitled", ".md")
  try touch(path) catch; return end   # the disk said no
  open!(e, path)
  list_files!(e)
  rename!(e, path, new=:page)
  nothing
end

"""
Make a new terminal in the folder `dir` and show it: an empty file called
Terminal.vt, which gets a shell in that folder as soon as it shows. The file
keeps what the terminal shows: see "a terminal's file".
"""
new_terminal!(e, dir) = begin
  path = free_path(e, dir, "Terminal", ".vt")
  try touch(path) catch; return end   # the disk said no
  open!(e, path)
  list_files!(e)
  nothing
end

"Make a new empty folder in the folder `dir`, and show `dir` in the sidebar. The new folder's name is a text field, to type the name it should have."
new_folder!(e, dir) = begin
  path = free_path(e, dir, "Untitled")
  try mkdir(path) catch; return end
  dir == e.folder ? list_files!(e) : go_folder!(e, dir)
  rename!(e, path, new=:folder)
  nothing
end

"""
Make a copy of the file or the folder at `path` beside it, with a name like
"notes copy.md", as the Finder does. A page with changes that aren't saved is
copied with them.
"""
duplicate!(e, path) = begin
  ispath(path) || return
  folder = isdir(path)
  dup = free_path(e, dirname(path), (folder ? basename(path) : title(path)) * " copy", folder ? "" : splitext(path)[2])
  try cp(path, dup) catch; return end
  b = get(e.buffers, path, nothing)
  b !== nothing && dirty(b) && writes(b) && write(dup, join(b.lines, "\n"))
  list_files!(e)
  nothing
end

"The wiki link to the file at `path`, like [[Ideas]] for a page or [[plan.pdf]] for another file"
wiki_link(path) = "[[" * (ismarkdown(path) ? title(path) : basename(path)) * "]]"

"The text field that a file's new name is typed in"
renamer(e) = node!(e, :renamer) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"What kind of new thing the file that's being renamed is, when it was made a moment ago to be given its name: see `rename!`"
@def mutable struct NewlyMade
  kind::Union{Nothing,Symbol} = nothing   # :page, :folder or :file, or nothing for a file that was there already
end

"""
Start to rename the file or the folder at `path`. Its name becomes a text
field, in the sidebar or in the top bar, as `at` says. Both show the whole
name, so the field has the whole name. The part of a file's name before its
ending is selected, and all of a folder's name, since a folder has no ending.
`new` is the kind of thing that it is when it was made a moment ago to be
given its name, like :page.
"""
rename!(e, path; at=:sidebar, new=nothing) = begin
  i = renamer(e)
  i.color = colours.ink
  i.text = basename(path)
  i.anchor, i.cursor = 0, length(isdir(path) ? i.text : title(path))
  e.nodes[:renaming] = path
  e.nodes[:renaming_at] = at
  got = focus(i)
  new === nothing || (state_of(e, NewlyMade).kind = new)
  got
end

"The path of the file that's being renamed in `at`, the `:sidebar` or the `:title`. It's \"\" when none is."
renaming(e, at) = get(e.nodes, :renaming_at, :sidebar) == at ? get(e.nodes, :renaming, "") : ""

"""
Take the text field away. The keyboard goes back to the sidebar, or to the
text when the field was in the top bar or was the name of a new page.
"""
stop_rename!(e) = begin
  delete!(e.nodes, :renaming)
  made = state_of(e, NewlyMade)
  new, made.kind = made.kind, nothing
  at = pop!(e.nodes, :renaming_at, :sidebar)
  at == :desktop ? focus_desktop!(e) : at == :title || new == :page ? focus(e) : focus(file_tree(e))
end

"Return gives the file the name that's typed, and esc leaves it with the name it has"
rename_key!(e, K) = begin
  unmodified(e) || return nothing
  if K == Keys.escape
    stop_rename!(e)
  elseif K == Keys.enter && finish_rename!(e)
    stop_rename!(e)
  end
  nothing
end

"A click somewhere else while a file is renamed gives the file the name that's typed"
ended_rename!(e) = begin
  w = window_of(e)
  (w === nothing || !haskey(e.nodes, :renaming) || w.focus === renamer(e)) && return
  finish_rename!(e)
  delete!(e.nodes, :renaming)
  delete!(e.nodes, :renaming_at)
  state_of(e, NewlyMade).kind = nothing
  nothing
end

"""
Give the file or the folder that's being renamed the name in the text field.
A file keeps its ending, like .md, unless the name is typed with one: a
Markdown ending, or the ending it has. A folder has no ending, so a dot in its
name is only part of the name. It's false when another file or folder has
that name already, and then nothing changes.
"""
finish_rename!(e) = begin
  old = get(e.nodes, :renaming, "")
  name = String(strip(renamer(e).text))
  (isempty(old) || isempty(name) || occursin('/', name)) && return true
  ending = isdir(old) ? "" : splitext(old)[2]
  typed = ismarkdown(name) || lowercase(splitext(name)[2]) == lowercase(ending)
  new = joinpath(dirname(old), typed ? name : name * ending)
  new == old && return true
  # A Mac's disk takes Notes.md and notes.md to be one file, so a change of capitals isn't a clash
  ispath(new) && lowercase(new) != lowercase(old) && return false
  # A page that was made a moment ago has no links to it yet, though pages can link to its name, Untitled
  move!(e, old, new, links=state_of(e, NewlyMade).kind === nothing)
  true
end

"True when `p` is the path `at`, or the path of something in the folder at `at`"
inside_path(p, at) = p == at || startswith(p, at * "/")

"The path that `p` gets when what's at `old` gets the path `new`. What's in a folder moves with it."
repath(p, old, new) = inside_path(p, old) ? new * p[ncodeunits(old)+1:end] : p

"The keys of `d` that are paths of what's at `at`: `at` itself, and what's in it when it's a folder"
paths_inside(d, at) = [p for p in keys(d) if inside_path(p, at)]

"The keys of the editor's nodes that it keeps for a file by its path, for the files at `at`"
nodes_inside(e, at; kinds=(:read, :outline, :fileview)) =
  [k for k in keys(e.nodes) if k isa Tuple{Symbol,String} && k[1] in kinds && inside_path(k[2], at)]

"""
Give the file or the folder at `old` the path `new`: on the disk, and in
everything the editor keeps by path. The files in a folder go with it, so a
file of the folder that shows, or that's open with changes, keeps showing.
The links to it in the pages of its project change to match, unless `links`
is false. See "links that follow a rename".
"""
move!(e, old, new; links=true) = begin
  found = links && ispath(old) ? links_into(e, old, new) : nothing
  if ispath(old)
    try
      Base.Filesystem.rename(old, new)
    catch
      return   # the disk said no, so it keeps its name
    end
  end
  to(p) = repath(p, old, new)
  for p in paths_inside(e.buffers, old)
    b = e.buffers[to(p)] = pop!(e.buffers, p)
    b.path = to(p)
  end
  # Going back to the file still finds it, and its tab stays open
  map!(to, e.back, e.back)
  map!(to, e.ahead, e.ahead)
  map!(to, tabs(e), tabs(e))
  foreach(p -> READ[to(p)] = pop!(READ, p), paths_inside(READ, old))
  foreach(k -> e.nodes[(k[1], to(k[2]))] = pop!(e.nodes, k), nodes_inside(e, old, kinds=(:read, :outline)))
  for item in items(file_tree(e), hidden=true)
    item.firstchild.path = to(item.firstchild.path)
  end
  e.folder = to(e.folder)
  desktop_moved!(e, old, new)   # an icon of a desktop keeps its place under its new name
  found === nothing || relink!(e, found, old, new)
  list_files!(e)
end

# --- the commands of a file and of a folder --------------------------------------------------
#
# Each takes a file or a folder by its type, so it shows in the palette while
# one is in focus, and works on the nearest: the row of the sidebar that the
# arrows are on, or else the file that shows. A command of a folder works on
# the folder that holds that file.

# The name is typed where it shows: in the sidebar, or in the top bar when the sidebar doesn't list it
rename!(e, o::FSObject) = (path = path_of(o); rename!(e, path, at=e.panel && path in e.listed ? :sidebar : :title); nothing)
duplicate!(e, o::FSObject) = (duplicate!(e, path_of(o)); nothing)
trash!(e, o::FSObject) = (trash!(e, path_of(o)); nothing)
show_in_finder(o::FSObject) = show_in_finder(path_of(o))
"Copy the path of the file or the folder `o`, to paste it somewhere"
copy_path(o::FSObject) = (clipboard(path_of(o)); nothing)
new_page!(e, d::AbstractDirectory) = new_page!(e, path_of(d))
new_folder!(e, d::AbstractDirectory) = new_folder!(e, path_of(d))
new_terminal!(e, d::AbstractDirectory) = new_terminal!(e, path_of(d))

let group = "The file or the folder in focus"
  add_command!(rename!; group, title="Give the file or the folder another name")
  add_command!(duplicate!; group, title="Make a copy of the file or the folder beside it")
  add_command!(trash!; group, name=:move_to_trash, title="Move the file or the folder to the Trash")
  add_command!(show_in_finder; group, title="Show the file or the folder in the Finder")
  add_command!(copy_path; group, title="Copy the path of the file or the folder")
  add_command!(new_page!; group, title="Make a new page in the folder")
  add_command!(new_folder!; group, title="Make a new folder in the folder")
  # ⌘⇧T makes a terminal at once, in the folder of the file that shows
  add_command!(new_terminal!; group, title="Make a new terminal in the folder", keys="cmd+shift+t")
end

"""
True when the page that shows is an email that came or went, so that its
front matter shows as the top of an email: an .eml file, or a page whose front
matter `said` has who it's from, a date and a subject.
"""
email_shows(e, said) = begin
  b = e.buf
  b.view == :markdown && haskey(said, "date") && (Eml.isemail(b.path) || (haskey(said, "from") && haskey(said, "subject")))
end
