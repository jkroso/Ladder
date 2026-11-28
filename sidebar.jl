# The sidebar: the rows of the file finder's list, the parts of a page that have changes that aren't saved, the sidebar's edge and the folder at its top

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI Theme describe detach! add_child! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" => Tree
@use "./markdown" Kind Line classify
@use "./sheet" parts shown
@use "./merge" changes
@use "github.com/jkroso/URI.jl/FS" => FS AbstractDirectory
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
@use "./file_view" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...
@use "./timelog_view" exports...
@use "./page_extras" exports...
@use "./agent/page" exports...
@use "./folder_kinds" exports...
@use "./sum_functions" exports...
@use "./copied_blocks" exports...
@use "./top_bar" exports...
@use "./editing" exports...
@use "./palette" exports...
@use "./finder" exports...

export COMPONENTS, LAYOUTS, PanelEdge, SIDEBAR_GUIDES, SIDEBAR_ICONS, TRAIL_ARROW, TRAIL_GAP,
       TRAIL_PAD, TRAIL_SIZE, TrailName, chose!, edited, edited_entries, go_entry!, goes, outline!,
       page_elsewhere, panel_edge, show_folder!, show_open_file!, trail_names

# --- the sidebar --------------------------------------------------------------------------

# A row of the file finder's list, or of the project picker's, looks like a row of the command palette's
describe(r::FileRow) = begin
  e = editor(r)
  c = omni(e)
  on = r.finder == e.picked
  # A line is between two rows, but not at an edge of the row that's chosen
  ruled = r.finder > 1 && !on && e.picked != r.finder - 1
  changed = haskey(e.buffers, r.path) && dirty(e.buffers[r.path])
  # The letters that were typed are in bold where the name has them
  parts = [Box(omni_label(text, 14, c.ink, weight=typed ? OMNI_MATCH : OMNI_NAME)) for (text, typed) in letter_runs(basename(r.path), input(e).text)]
  Row(width(grow=grow), height(px(OMNI_ROW_ONE)), padding(14px, 0px), child_gap=10px, name="File",
      background(on ? c.selected : c.drop), border(1px, :solid, ruled ? c.rule : clear)[:top],
    Box(width(grow=grow), Alignment.Start, clip_x=true, Row(parts...)),
    # A page with changes that aren't saved says so at the right, faint, and a project says where it is
    (changed ? (Box(omni_label("Not saved", 12, on ? c.ink2 : c.muted)),) :
     e.popup == :projects ? (Box(omni_label(project_place(r.path), 12, on ? c.ink2 : c.muted)),) : ())...)
end

cursor(::FileRow) = :hand
# The mouse over a row chooses it, as it does in the command palette
onmouse(r::FileRow, ::MouseMove) = (editor(r).picked = r.finder; handled)

onkey(r::FileRow, ::KeyPress{Keys.mouse_left}) = picker_open!(editor(r), r.path)

# The sidebar is a tree, UI.jl's ListTree. Each file of the folder is a group.
# The items in it are the file's headings and its components: the sheets and
# what its `ui` blocks show. A heading is a group too when it has smaller
# headings or components under it. The tree keeps which groups are open and
# which item the keyboard is on.
#
# Each item starts with an icon that says what it is. The tree draws no arrows.
# While the mouse is over a group, the group's icon is an arrow that shows
# whether it's open, and a click on the icon opens or closes the group.

"The icon that a file, a heading or a component starts with in the sidebar, in the place a tree has its arrow"
mark(l, icon; size=13px) = begin
  item = l.parent
  # A file that's open and has nothing under it has no arrow, since there's nothing to open or close.
  # A closed file might have headings, so it has one.
  over = item isa Tree.ItemGroup && Tree.hovered(item) && (item.collapsed || any(c -> c isa Tree.TreeItem, item.children))
  # The box never shrinks. A name too long for the sidebar would shrink it to its icon, and the
  # arrow is narrower than the icon, so the name would move left when the mouse came over it.
  Box(fixed(18px), height(grow=grow), Alignment.Center,
    (isempty(icon) ? () : (Icon(over ? (item.collapsed ? "chevron-right" : "chevron-down") : icon,
                                size=over ? 10px : size, color=colours.dim),))...)
end

describe(l::FileLabel) = begin
  e = editor(l)
  o = object(e, l.path)
  folder = o isa AbstractDirectory
  changed = haskey(e.buffers, l.path) && dirty(e.buffers[l.path])
  # While the file is renamed, a text field with its name is where the name was
  name = renaming(e, :sidebar) == l.path ?
    Box(width(grow=grow), height(22px), padding(5px, 0px), radius(4px), Alignment.Start, background(colours.bg),
        border(1px, :solid, colours.accent), renamer(e)) :
    # A hidden folder or page is fainter than the others, as it is in the Finder, and so is one that you ignore
    folder ? Box(width(grow=grow), Alignment.Start, label(entry_name(o), color=ishidden(entry_name(o)) || ignored_shown(e, l.path) ? colours.dim : colours.ink)) :
    ismarkdown(l.path) ?
    Box(width(grow=grow), Alignment.Start, label(basename(l.path), color=(ishidden(l.path) || ignored_shown(e, l.path)) && l.path != e.buf.path ? colours.dim : colours.ink,
                                                 weight=l.path == e.buf.path ? "Semibold" : "")) :
    # A file that Ladder only shows has its whole name, and it's fainter until it's the file that shows
    Box(width(grow=grow), Alignment.Start, label(basename(l.path), color=l.path == e.buf.path ? colours.ink : colours.dim,
                                                 weight=l.path == e.buf.path ? "Semibold" : ""))
  # A page that an agent waits for has a dot in the colour of the Nudge button
  awaited = ismarkdown(l.path) && !isempty(agents(e, l.path))
  Row(width(grow=grow), height(grow=grow), padding(0px, 8px, 0px, 0px), child_gap=4px, clip=true, name="File",
    mark(l, o === nothing ? file_icon(l.path) : entry_icon(o)),
    name,
    (o === nothing ? () : entry_marks(e, o))...,   # what a kind of folder or of file adds, like how many emails of a folder aren't read
    (awaited ? (Box(width(6px), height(6px), radius(3px), background(colours.accent)),) : ())...,
    (changed ? (Box(width(6px), height(6px), radius(3px), background(colours.dim)),) : ())...)
end

describe(l::EntryLabel) =
  Row(width(grow=grow), height(grow=grow), padding(0px, 8px, 0px, 0px), child_gap=4px, clip=true, name="Entry",
    mark(l, l.icon),
    Box(width(grow=grow), Alignment.Start, label(l.title, 12px, color=l.line == 0 ? colours.faint : colours.dim)),
    # A heading or a component whose lines have changes that aren't saved has a dot, as its file has
    (edited(l) ? (Box(width(5px), height(5px), radius(2.5px), background(colours.dim)),) : ())...)

# --- the parts of a page that have changes that aren't saved ----------------------------
#
# A file with changes that aren't saved has a dot beside its name in the
# sidebar. Each heading and each component of that file whose own lines
# changed has a dot too, so the sidebar shows where the changes are. A change
# belongs to the nearest thing above it in the sidebar: a line in a component's
# block belongs to the component, and any other line belongs to the heading
# that it's under. A heading whose group is closed has a dot when anything in
# the group changed. Lines that were taken away count for the line that's now
# where they were. The dots go when the page is saved.

"""
The first lines of the headings and the components of `b` that have changes
which aren't saved. It's worked out once for each version of the text.
"""
edited_entries(e, b::Buffer) = begin
  key = (:edited, b.path)
  kept = get(e.nodes, key, nothing)
  kept !== nothing && kept[1] == (b.version, b.saved) && return kept[2]::Set{Int}
  found = Set{Int}()
  if dirty(b)
    entries, ks, n = outline(b), kinds(b), length(b.lines)
    starts = [x.line for x in entries]
    # A component's lines end where its block closes. A heading's go on to the next thing in the sidebar.
    ends = [x.level == 7 ? something(findnext(k -> k.kind == Kind.fence, ks, x.line + 1), n) : n for x in entries]
    for (_, new) in changes(b.disk, b.lines)
      for i in (isempty(new) ? (clamp(first(new), 1, n):clamp(first(new), 1, n)) : new)
        at = searchsortedlast(starts, i)
        # Past the end of a component, the line belongs to the heading above the component
        while at > 0 && i > ends[at]
          at = something(findprev(k -> entries[k].level < 7, 1:at-1, at - 1), 0)
        end
        at > 0 && push!(found, starts[at])
      end
    end
  end
  e.nodes[key] = ((b.version, b.saved), found)
  found
end

"True when the lines of this heading or component have changes that aren't saved. A closed group answers for all that's in it."
edited(l::EntryLabel) = begin
  e = editor(l)
  b = get(e.buffers, l.path, nothing)
  (b === nothing || l.line == 0 || !dirty(b)) && return false
  found = edited_entries(e, b)
  isempty(found) && return false
  l.line in found && return true
  item = l.parent
  item isa Tree.ItemGroup && item.collapsed && any(inner -> inner.firstchild.line in found, items(item, hidden=true))
end

# The name that the sidebar gives each component of UI.jl, and its icon
const COMPONENTS = Dict(
  "Checkbox" => ("Checkbox", "check2-square"), "Toggle" => ("Switch", "toggle-on"),
  "RadioGroup" => ("Radio buttons", "ui-radios"), "Dropdown" => ("Menu", "menu-button-wide"), "Select" => ("Menu", "menu-button-wide"),
  "Slider" => ("Slider", "sliders"), "ColorPicker" => ("Colour picker", "palette"),
  "TextInput" => ("Text field", "input-cursor-text"), "KeyCombo" => ("Keys", "command"),
  "Tooltip" => ("Tooltip", "chat-square-text"), "ListTree" => ("Tree", "list-nested"),
  "Inspector" => ("Inspector", "braces"), "Table" => ("Table", "table"), "Button" => ("Button", "hand-index"),
  "ProgressBar" => ("Progress bar", "hr"), "STLViewer" => ("3D model", "box"),
  "AudioPlayer" => ("Sound", "music-note-beamed"), "VideoPlayer" => ("Video", "film"), "AudioRecorder" => ("Recorder", "mic"),
  "Mermaid" => ("Diagram", "diagram-3"))
const LAYOUTS = ("Box", "Row", "Column", "Stack", "Scroll", "Text", "Image")
"Every icon that the sidebar can show. The built app reads them all when it's made."
const SIDEBAR_ICONS = unique(["eye", "eye-slash", "file-earmark-text", "chevron-right", "chevron-down", "puzzle",
                              ("type-h$n" for n in 1:6)..., (icon for (_, icon) in values(COMPONENTS))...,
                              (block_icon(T) for T in values(BLOCKS) if !isempty(block_icon(T)))...])

"""
The name and the icon of what a block of `ui` code shows. It's read from the
code, so the block needn't have run: the first component of UI.jl that the
code names, or else the first thing it makes that isn't a layout.
"""
component(code) = begin
  made = String[]
  for line in code
    startswith(lstrip(line), "@use") && continue
    append!(made, (m[1] for m in eachmatch(r"\b([A-Z]\w*)\(", line)))
  end
  i = findfirst(name -> haskey(COMPONENTS, name), made)
  i === nothing || return COMPONENTS[made[i]]
  i = findfirst(name -> !(name in LAYOUTS) && !isdefined(Base, Symbol(name)), made)
  i === nothing ? ("Layout", "bounding-box") : (made[i], "puzzle")
end

"The headings and the components among `lines`, from the top. `folder` is the folder of their page, where a file can define a kind of block."
outline(lines::Vector{String}, kinds::Vector{Line}, folder::AbstractString="") = begin
  out = Entry[]
  for (i, l) in enumerate(kinds)
    if l.kind == Kind.heading
      push!(out, Entry(i, l.level, rest(lines[i], l.prefix), "type-h$(l.level)", i))
    elseif l.kind == Kind.fence && l.level == 0 && haskey(BLOCKS, l.lang)
      # The line that closes the block, or the last line when nothing closes it
      close = something(findnext(k -> k.kind == Kind.fence, kinds, i + 1), length(lines))
      entry = block_outline(BLOCKS[l.lang], lines, i, close)
      entry === nothing || push!(out, entry)
    elseif l.kind == Kind.fence && l.level == 0 && block_source(lines[i], l.lang, folder) !== nothing
      # A block that a file defines has the name of its language. The caret goes under the block.
      close = something(findnext(k -> k.kind == Kind.fence, kinds, i + 1), length(lines))
      push!(out, Entry(i, 7, uppercasefirst(replace(l.lang, '_' => ' ')), "puzzle", min(close + 1, length(lines))))
    end
  end
  out
end
outline(b::Buffer) = outline(b.lines, kinds(b), isempty(b.path) ? "" : dirname(b.path))

"""
The headings and the components of the file at `path`. A file that has been
opened gives those of its text as it is now, with the changes that aren't
saved. Any other file is read from the disk, and read again when it changes there.
"""
outline(e::Editor, path::String) = begin
  haskey(e.buffers, path) && return outline(e.buffers[path])
  isfile(path) || return Entry[]
  at = mtime(path)
  kept = get(e.nodes, (:read, path), nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  lines = text(path)
  found = outline(lines, classify(lines), dirname(path))
  e.nodes[(:read, path)] = (at, found)
  found
end

const SIDEBAR_GUIDES = true   # draw the lines that join each item in the sidebar to the item it's in

"The sidebar's tree"
file_tree(e) = node!(() -> Tree.ListTree(guides=SIDEBAR_GUIDES, frame=false, arrows=false, onchoose=item -> choose!(e, item)), e, :tree)

"The items in `parent` and in the groups in it, from the top. With `hidden`, those in a closed group too."
items(parent; hidden=false, out=Tree.TreeItem[]) = begin
  for item in parent.children
    item isa Tree.TreeItem || continue
    push!(out, item)
    item isa Tree.ItemGroup && (hidden || !item.collapsed) && items(item; hidden, out)
  end
  out
end

"""
Mark that the sidebar's tree took a key, like Return on a heading, which comes
to the editor next, so that the editor doesn't take it too. The tree keeps a
click that chose an item, so a click is never marked: the mark would stay,
and the editor would leave out the next click or key, like a right-click.
"""
chose!(e) = begin
  w = window_of(e)
  (w === nothing || !(Keys.mouse_left in w.keys)) && (e.nodes[:chose] = true)
  nothing
end

"""
A click on the name of a file shows the file in the page. A file that isn't
Markdown is only shown: the page doesn't change it. A folder shows its own folders and files. A click on a heading or a
component goes to it, and opens its file first if another file is showing.
Return does the same for the item the keyboard is on. Each gives the keyboard
to the text.
"""
choose!(e, item) = begin
  l = item.firstchild
  o = l isa FileLabel ? object(e, l.path) : nothing
  o isa AbstractDirectory && return (open!(e, o); chose!(e); nothing)
  # A group's name shows what's in the group. Only its icon hides that.
  item isa Tree.ItemGroup && (item.collapsed = false)
  l.path == e.buf.path || (o === nothing ? open!(e, l.path) : open!(e, o))
  focus(e)
  chose!(e)
  (l isa EntryLabel && l.line > 0) || return
  go_entry!(e, l.line, l.caret)
end

"""
Put the caret on line `caret` of the page that shows, for the heading or the
component that starts on `line`, with that line near the top of the window.
"""
go_entry!(e, line, caret) = begin
  b = e.buf
  b.reading = false
  at = clamp(caret, 1, length(b.lines))
  b.caret = b.anchor = settle(b, (at, length(b.lines[at])))
  # The caret stays in a `columns` block that takes no room, so that the block shows its lines
  column_fold(b, at) === nothing || (b.caret = b.anchor = b.stood = line_end(b, at))
  # Put its first line near the top of the window rather than just on screen.
  # The next frame does it, once it has laid out the file that's showing.
  hold!(e, clamp(line, 1, length(b.lines)), 24px - PAGE_TOP)
  e.blink = time()
end

"Put the headings and the components of a file in its group, when they aren't the ones that it has"
outline!(e, group) = begin
  path = group.firstchild.path
  found = outline(e, path)
  found == get(e.nodes, (:outline, path), nothing) && return
  e.nodes[(:outline, path)] = found
  old = items(group, hidden=true)
  labels = [item.firstchild for item in old]
  if !isempty(found) && length(labels) == length(found) &&
     all(l.level == x.level && l.title == x.title && l.icon == x.icon for (l, x) in zip(labels, found))
    # The same ones on other lines, as when a line is typed above them
    foreach((l, x) -> (l.line = x.line; l.caret = x.caret), labels, found)
    return
  end
  closed = Set((item.firstchild.level, item.firstchild.title) for item in old if item isa Tree.ItemGroup && item.collapsed)
  foreach(detach!, [item for item in group.children if item isa Tree.TreeItem])
  # A file with no headings or components has nothing under it
  isempty(found) && return
  # Each one goes in the nearest heading above it that is bigger
  above = Any[(0, group)]
  for (k, x) in enumerate(found)
    while above[end][1] >= x.level
      pop!(above)
    end
    label = EntryLabel(path=path, line=x.line, level=x.level, title=x.title, icon=x.icon, caret=x.caret)
    if k < length(found) && found[k+1].level > x.level
      item = Tree.ItemGroup(label)
      item.collapsed = (x.level, x.title) in closed
      add_child!(above[end][2], item)
      push!(above, (x.level, item))
    else
      add_child!(above[end][2], Tree.Item(label))
    end
  end
end

"The item for where the caret is: the last heading or component above it that shows, or its file"
here(e, tree) = begin
  i = findfirst(group -> group.firstchild.path == e.buf.path, collect(tree.children))
  i === nothing && return nothing
  group = collect(tree.children)[i]
  (!(group isa Tree.ItemGroup) || group.collapsed) && return group
  at = findlast(item -> 0 < item.firstchild.line <= e.buf.caret[1], items(group))
  at === nothing ? group : items(group)[at]
end

"""
Open the group of the file that shows, so the sidebar lists its headings, and
close the group of the file that showed before. It's done once each time
another file shows, and the first time the sidebar lists the file. Between
those times, a click on a file's icon opens or closes its group, and the group
stays as the click left it.
"""
show_open_file!(e, tree) = begin
  listed = collect(tree.children)
  i = findfirst(item -> item.firstchild.path == e.buf.path, listed)
  shown = i === nothing ? nothing : listed[i]
  before = get(e.nodes, :open_file, nothing)
  shown === before && return
  before isa Tree.ItemGroup && (before.collapsed = true)
  shown isa Tree.ItemGroup && (shown.collapsed = false)
  e.nodes[:open_file] = shown
end

"Make the sidebar's tree show the folder's files and the headings of each file that's open in it"
fill_tree!(e, tree) = begin
  tree.guides = SIDEBAR_GUIDES
  if [group.firstchild.path for group in tree.children] != e.listed
    kept = Dict(group.firstchild.path => group for group in tree.children)
    foreach(detach!, collect(tree.children))
    for p in e.listed
      add_child!(tree, get(kept, p) do
        delete!(e.nodes, (:outline, p))   # a new group has no headings in it yet
        # A file that isn't Markdown has no headings to list
        isfile(p) && ismarkdown(p) ? Tree.ItemGroup(FileLabel(path=p)) : Tree.Item(FileLabel(path=p))
      end)
    end
  end
  show_open_file!(e, tree)
  for group in tree.children
    group isa Tree.ItemGroup && !group.collapsed && outline!(e, group)
  end
  ended_rename!(e)
  w = window_of(e)
  shown = items(tree)
  if w === nothing || w.focus !== tree
    # While the text has the keyboard, the tree marks where the caret is
    tree.focused = here(e, tree)
  elseif !any(item -> item === tree.focused, shown)
    tree.focused = something(here(e, tree), get(shown, 1, nothing), Some(nothing))
  elseif tree.focused !== get(e.nodes, :tree_at, nothing)
    # An arrow key moved to another item. Keep it in sight.
    high = Tree.ROW_HEIGHT   # the height of a row while the theme's text has its usual size, as the sidebar's has
    row = findfirst(item -> item === tree.focused, shown)
    scroll_into_view!(e.files_scroll, high * (row - 1), high * row)
  end
  e.nodes[:tree_at] = tree.focused
  tree
end

"The colours of the sidebar's tree"
panel_theme() = Theme(size=Tree.LABEL_SIZE, surface=colours.panel, text=colours.ink, dim=colours.dim, line=colours.line,
                      hover=colours.hover, select=colours.active, family=SANS)

# --- the edge of the sidebar ----------------------------------------------------------
#
# Drag the line at the sidebar's right edge to make the sidebar wider or
# narrower. A strip a few pixels wide lies over the line, so the mouse
# catches it easily, and the cursor shows arrows that point left and right
# over it. The sidebar keeps the width you give it, in the settings file too.

@def mutable struct PanelEdge <: SemanticUI
  grab::px = 0px   # how far right of the sidebar's edge the mouse was when the drag started
end

describe(::PanelEdge) = Box(width(EDGE_W), height(grow=grow), name="Edge")

cursor(::PanelEdge) = :resize_x

onkey(p::PanelEdge, ev::KeyPress{Keys.mouse_left}) = (p.grab = ev.window.mouse[1] - panel_w(editor(p)); handled)

onmouse(p::PanelEdge, ev::MouseMove) = begin
  held(p, Keys.mouse_left) || return
  side!(editor(p), ev.position[1] - p.grab)
  handled
end

"The strip over the sidebar's edge, while the sidebar is open and not sliding. It starts under the top bar."
panel_edge(e) = e.panel && !sliding(e) && lowered(e) === nothing ?
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(above_page(e), 0px, 0px, panel_w(e) - EDGE_W / 2),
       node!(PanelEdge, e, :edge)),) : ()

# --- the folder at the top of the sidebar ---------------------------------------------

const TRAIL_SIZE = 12px
const TRAIL_ARROW = 7px   # the size of the arrow between two names
const TRAIL_GAP = 2px     # on each side of an arrow
const TRAIL_PAD = 3px     # inside a name, on each side, so its hover background has room

"""
The names of the folders on the way to `folder`, each with where it is, in no
more than `room` with an arrow between each two. The sidebar is narrow, so when
the names don't fit, the ones furthest from the folder shrink to their first
letter, from the left, like `~ › D › Canon › City`. If that still doesn't fit, an
… takes the place of names after the first, and last of all the folder's own
name loses its middle. The … has no path.
"""
trail_names(folder, room) = begin
  short = steps(folder)
  face(i) = Face(SANS, i == length(short) ? "Semibold" : "", TRAIL_SIZE, colours.ink, false)
  wide() = sum(i -> measure(face(i), short[i][1]) + 2TRAIL_PAD, eachindex(short)) + (length(short) - 1) * (TRAIL_ARROW + 2TRAIL_GAP)
  # A hidden folder keeps its dot, so .config shrinks to .c
  initial(n) = startswith(n, '.') ? first(n, 2) : first(n, 1)
  for i in 2:length(short)-1
    wide() <= room && return short
    short[i] = (initial(short[i][1]), short[i][2])
  end
  while wide() > room && length(short) > 2 && short[2][1] != "…"
    # The first name stays, so the trail still shows where it starts
    deleteat!(short, 2)
    length(short) > 2 ? (short[2] = ("…", "")) : insert!(short, 2, ("…", ""))
  end
  while wide() > room && length(short) > 3
    deleteat!(short, 3)
  end
  # A folder whose own name is too long loses the middle of it
  name, at = short[end]
  k = length(name) ÷ 2
  while wide() > room && k > 2
    k -= 1
    short[end] = (first(name, k) * "…" * last(name, k), at)
  end
  short
end

"One name in the trail at the top of the sidebar. A click shows that folder in the sidebar."
@def mutable struct TrailName <: SemanticUI
  path::String = ""   # empty for the … that stands for names left out
  name::String = ""
  last::Bool = false  # the folder that the sidebar shows
end

"The folder at the top of the sidebar, as a trail of names"
folder_trail(e, room) = begin
  names = trail_names(e.folder, room)
  arrow() = Box(padding(TRAIL_GAP, 0px), Icon("chevron-right", size=TRAIL_ARROW, color=colours.faint))
  parts = Any[]
  for (i, (n, at)) in enumerate(names)
    i > 1 && push!(parts, arrow())
    # Each name is kept, so it knows when the mouse is over it
    t = node!(() -> TrailName(), e, (:trail, i))
    t.path, t.name, t.last = at, n, i == length(names)
    push!(parts, t)
  end
  parts
end

"""
True when a click on the name `t` goes somewhere: to a folder further up, or,
for the sidebar's own folder, to that folder while the window shows another page.
"""
goes(t::TrailName) = !isempty(t.path) && (!t.last || page_elsewhere(editor(t)))

"True when the window shows another page than the sidebar's own folder"
page_elsewhere(e) = (d = directory(e); d isa AbstractDirectory && e.buf.path != string(d.path))

describe(t::TrailName) =
  Box(padding(TRAIL_PAD, 1px), radius(4px), background(goes(t) && ishovered(t) ? colours.hover : clear),
    label(t.name, TRAIL_SIZE, color=t.last ? colours.ink : colours.dim, weight=t.last ? "Semibold" : ""))

cursor(t::TrailName) = goes(t) ? :hand : :arrow

onkey(t::TrailName, ::KeyPress{Keys.mouse_left}) = goes(t) ? (open_folder!(editor(t), t.path); handled) : nothing

"""
Open the folder at `path` in the page: its own page, like the home folder's,
a desktop's or a blog's Readme, or else a list of what's in it. The sidebar
lists the folder, and a sidebar that's hidden stays hidden. The trail at the
top of the sidebar, the path in the top bar and the home folder's page open a
folder this way. With `own` false, a folder whose own page is a file in it,
like a blog, shows only its list: ⌘W does that, so it opens no file.
"""
open_folder!(e, path; own=true) = begin
  (isdir(path) && !ispackage(path)) || return show_path!(e, path)
  # The folder's own page says its kind, and loads the code of the kind. It runs now if it hasn't.
  folder_pages!(path)
  Base.invokelatest(own ? follow_folder! : show_folder!, e, path)
end

show_folder!(e, path) = (go_folder!(e, path); show_beside!(e, path); e)

# The backdrop is behind the file finder, and a click on it closes the finder. It doesn't
# dim the page, as the command palette doesn't.
describe(b::Backdrop) = Box(width(grow=grow), height(grow=grow))
onkey(b::Backdrop, ::KeyPress) = (e = editor(b); e.popup = :none; focus(e))
