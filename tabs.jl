# The files that are open, as tabs at the top of the sidebar

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe describe! reuse! detach! add_child! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" => Tree
@use "./remote" => Remote
@use "./term/view" => Terms
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS FSObject
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
@use "./run_code" exports...
@use "./agent/window" exports...
@use "./agent/page" exports...
@use "./news_page" exports...
@use "./showed_before" exports...
@use "./top_bar" exports...
@use "./editing" exports...

export TABS_MOST, TAB_KEYS_WAIT, TabClose, TabLabel, add_tab!, choose_tab!, close_tab!,
       drop_gone_tabs!, fill_tabs!, focus_panel!, new_tab, new_tab!, own_scroll!, own_side_menu,
       show_tab!, show_tab_page!, side_menu, side_tick!, sidebar_view, tab_after_close!, tab_dots,
       tab_folder, tab_keys, tab_keys_shown!, tab_list, tab_marks, tab_menu!, tab_name, tab_rows,
       tab_tree, tabbable

# --- the files that are open, as tabs -------------------------------------------------------
#
# Each file that shows in the window stays open as a tab at the top of the
# sidebar, over the folder, until ⌘W closes it. The tabs are in the order that
# their files opened, so a new one goes at the bottom. A click on a tab shows
# its file again, from where it was scrolled to, and the tab of the file that
# shows is shaded. While the mouse is over a tab, an × at its right end closes
# it, and so does a click with the middle button. A tab whose file has changes
# that aren't saved has a dot where the × shows. A tab shows what the tree
# shows of its file too: git's letter, like M for a file with changes, and a
# dot when an agent waits for the page. A terminal's tab has a ring that
# turns while its shell runs a command. A right-click shows the file's menu. A folder that shows in the page has no tab, and nor have the
# pages of the settings. When two tabs have the same name, each shows the name
# of its folder after it. When the tabs need more room than a third of the
# window, they scroll, and the tab of the file that shows stays in sight.
#
# ⌘W closes the tab of the file that shows: see "closing a file". ⌘T opens a
# new tab: the window shows no file, a tab called New Tab is at the bottom of
# the tabs, and the file finder opens. The file that you choose shows in that
# tab. ⌘W on it closes it, and the tab that showed last shows again. ⌘1 shows
# the first tab, ⌘2 the second, and so on to ⌘9. While ⌘ is held by itself,
# each of the first nine tabs shows its keys at its right end, like ⌘1. They
# show after `TAB_KEYS_WAIT`, so a quick ⌘S doesn't flash them. A file that
# gets a new name keeps its tab, and the tab of a file that goes to the Trash
# closes. Ladder keeps the front window's tabs when it quits, and opens with
# them the next time: see "where Ladder opens".

"The files that are open in the window of `e`, as tabs at the top of the sidebar, in the order that they opened"
tabs(e) = get!(() -> String[], e.nodes, :tabs)::Vector{String}

"True when the page at `path` can have a tab: a file, a new page that has no file yet, or a page from a web server. A folder can't."
tabbable(path) = !isempty(path) && (isremote(path) || !isdir(path) || news_tab(path))

"True when the folder at `path` is a folder of news, whose front page you read as a page, so it has a tab: see `news_companion!`"
news_tab(path) = isdir(path) && (try FS.get(FSPath(path)) isa NewsDirectory catch; false end)

"Show the page of the tab of `path`: its file, or the front page of a folder of news"
show_tab_page!(e, path) = isdir(path) ? open_folder!(e, path) : open!(e, path)

"Give the file that the window of `e` shows a tab at the bottom of the tabs, unless it has one. A page of the settings gets none."
add_tab!(e) = begin
  path = e.buf.path
  tabbable(path) && !issettings(e) && !(path in tabs(e)) && push!(tabs(e), path)
  e
end

"Close the tabs of files that have gone from the Mac and that the window has no page of, as when another app deleted one"
drop_gone_tabs!(e) = filter!(p -> p == e.buf.path || isremote(p) || showable(e, p) || news_tab(p), tabs(e))

"""
Take the tab of the file that shows out of the tabs, and give the tab that
shows in its place: the one that was under it, or the one above when it was
the last. On a page that has no tab, like a folder's, it's the tab that showed
last. It's nothing when no other tab is open.
"""
tab_after_close!(e) = begin
  drop_gone_tabs!(e)
  ts = tabs(e)
  i = findfirst(==(e.buf.path), ts)
  if i === nothing
    isempty(ts) && return nothing
    j = findlast(in(ts), e.back)
    return j === nothing ? ts[end] : e.back[j]
  end
  deleteat!(ts, i)
  isempty(ts) ? nothing : ts[min(i, end)]
end

"""
Close the tab of the file at `path`. When its file is the one that shows, the
file closes as ⌘W closes it, and the tab under it shows.
"""
close_tab!(e, path) = begin
  path == e.buf.path && return (close_file!(e); nothing)
  filter!(!=(path), tabs(e))
  nothing
end

"True while the window shows the new tab that ⌘T opened, with no file in it yet"
new_tab(e) = get(e.nodes, :new_tab, false) && nofile(e)

"""
Open a new tab, at the bottom of the tabs, and the file finder, to find the
file to show in it. A new tab that shows already stays. The settings window
has no tabs.
"""
new_tab!(e) = begin
  e = top_editor(e)
  issettings(e) && return e
  nofile(e) || show_no_file!(e)
  e.nodes[:new_tab] = true
  open_finder!(e)
  e
end

"Show the `n`th tab, from the top. Nothing happens when there are fewer tabs."
show_tab!(e, n) = begin
  e = top_editor(e)
  drop_gone_tabs!(e)
  n <= length(tabs(e)) && choose_tab!(e, tabs(e)[n])
  nothing
end

"The tabs' rows, by the path of each one's file: the tabs, and \"\" for a new tab that shows"
tab_rows(e) = new_tab(e) ? [tabs(e); ""] : tabs(e)

"Show the file of the tab at `path`, and give the text the keyboard. A tab whose file has gone closes."
choose_tab!(e, path) = begin
  drop_gone_tabs!(e)
  path in tabs(e) && path != e.buf.path && show_tab_page!(e, path)
  focus(e)
  nothing
end

"A file that's open, as a tab at the top of the sidebar"
@def mutable struct TabLabel <: SemanticUI
  path::String = ""
  close::Any = nothing   # its ×, made the first time the mouse is over the tab
end

"The × at the right end of a tab, while the mouse is over the tab. A click on it closes the tab."
@def mutable struct TabClose <: SemanticUI
  path::String = ""
end

"The tabs' list. It's a tree with no groups, so its rows look as the rows of the sidebar's tree of files do."
tab_tree(e) = node!(() -> Tree.ListTree(guides=true, frame=false, arrows=false, onchoose=item -> choose_tab!(e, item.firstchild.path)), e, :tab_tree)

"The name of the tab of `path`: the file's name, or the last name of the address of a page from a web server. A new tab has no file."
tab_name(path) = isempty(path) ? "New Tab" : (at = web_address(path); isempty(at) ? basename(path) : Remote.trail(at)[end][1])

"""
The name of the folder that the file of a tab is in, when another tab has the
same name, or nothing. It tells the two apart. `fill_tabs!` finds the names
that two tabs have.
"""
tab_folder(e, path) = !isempty(path) && !isremote(path) && tab_name(path) in get(e.nodes, :tab_twins, ()) ? basename(dirname(path)) : nothing

describe(l::TabLabel) = begin
  e = editor(l)
  shortcut = tab_keys(e, l.path)
  shows = l.path == e.buf.path
  over = Tree.hovered(l.parent)
  over && l.close === nothing && (l.close = own!(l, TabClose()))
  over && (l.close.path = l.path)
  closer = over && isempty(shortcut)
  folder = tab_folder(e, l.path)
  # The × has its middle where the last dot has its middle, so it shows in the dot's place: the row's end has less room while it shows
  Row(width(grow=grow), height(grow=grow), padding(0px, closer ? 8px + 3px - 9px : 8px, 0px, 0px), child_gap=4px, clip=true, name="Tab",
    # A folder with a tab is a folder of news
    mark(l, isempty(l.path) ? "plus-lg" : !isempty(web_address(l.path)) ? "globe" : isdir(l.path) ? "newspaper" : file_icon(l.path)),
    # The name loses its end, and not the × after it, when it's too long for the sidebar
    Box(width(grow=grow), Alignment.Start, clip_x=true,
      Row(Alignment.Center, child_gap=6px,
        Box(label(tab_name(l.path), color=colours.ink, weight=shows ? "Semibold" : "")),
        (folder === nothing ? () : (Box(label(folder, 11px, color=colours.faint)),))...)),
    tab_marks(e, l.path)...,
    # While ⌘ is held, the keys that show the tab take the place of the × and the dots
    (!isempty(shortcut) ? (Box(label(shortcut, 12px, color=colours.dim)),) :
     # The × takes the place of the dots as the mouse comes over the tab, and nothing moves to make room for it
     closer ? (l.close,) : tab_dots(e, l.path))...)
end

"""
The dots at the end of the tab of the file at `path`, as the sidebar's tree
has them: one in the colour of the Nudge button for a page that an agent
waits for, and a grey one for changes that aren't saved.
"""
tab_dots(e, path) = begin
  awaited = !isempty(path) && !isremote(path) && ismarkdown(path) && !isempty(agents(e, path))
  changed = haskey(e.buffers, path) && dirty(e.buffers[path])
  ((awaited ? (Box(width(6px), height(6px), radius(3px), background(colours.accent), name="Dot"),) : ())...,
   (changed ? (Box(width(6px), height(6px), radius(3px), background(colours.dim), name="Dot"),) : ())...)
end

"How long ⌘ is held by itself before the tabs show their keys, in seconds. A shortcut like ⌘S is quicker, so it doesn't flash them."
const TAB_KEYS_WAIT = 0.4

"""
True when the tabs show the keys that show them: ⌘ has been held by itself for
`TAB_KEYS_WAIT`. Until then, the window draws again when that time comes.
"""
tab_keys_shown!(e) = begin
  w = window_of(e)
  (w !== nothing && only_held(w, Keys.cmd)) || return (delete!(e.nodes, :tab_keys_since); false)
  since = get!(e.nodes, :tab_keys_since, time())
  left = TAB_KEYS_WAIT - (time() - since)
  left > 0 && (redraw_in!(e, left); return false)
  true
end

"The keys that show the tab of the file at `path`, like ⌘1, while the tabs show their keys, or \"\""
tab_keys(e, path) = begin
  get(e.nodes, :tab_keys_shown, false) || return ""
  n = findfirst(==(path), tabs(e))
  (n === nothing || n > 9) ? "" : String(strip(hint(e, Symbol(:tab_, n))))
end

"""
What the tab of the file at `path` shows of the file's state, after its name,
as the sidebar's tree shows it: git's letter for a file with changes, like M
or U. A terminal's tab has a ring that turns while its shell runs a command,
and none while the shell waits for one. The dots come after these: see `tab_dots`.
"""
tab_marks(e, path) = begin
  (isempty(path) || isremote(path)) && return ()
  o = object(e, path)
  v = get(e.nodes, (:term, path), nothing)
  talk = get(e.nodes, (:chat, path), nothing)   # a session's tab has the ring while its agent works
  working = (v !== nothing && Terms.busy(v)) || (talk isa AgentPane && talk.session !== nothing && talk.session.busy)
  working && redraw_in!(e, SPIN_FRAME)   # the ring turns
  ((o isa FSObject ? entry_marks(e, o) : ())...,
   (working ? (Box(fixed(18px), height(18px), Alignment.Center, justify=Alignment.Center, Spinner(size=11px)),) : ())...)
end

# A click with the middle button closes a tab, as it does in a web browser
onkey(l::TabLabel, ::KeyPress{Keys.mouse_middle}) = (close_tab!(editor(l), l.path); handled)

describe(c::TabClose) =
  Box(fixed(18px), height(18px), radius(4px), Alignment.Center, justify=Alignment.Center, name="Close",
      background(ishovered(c) ? colours.active : clear),
    Icon("x-lg", size=10px, color=ishovered(c) ? colours.ink : colours.dim))

cursor(::TabClose) = :hand
onkey(c::TabClose, ::KeyPress{Keys.mouse_left}) = (close_tab!(editor(c), c.path); handled)

"""
The file's menu, for a right-click on its tab. It has no Rename, since the
name of the file that's renamed is a text field in the sidebar's tree, and
the file may not be in the folder that the tree lists. A page from a web server has no menu.
"""
tab_menu!(e, w, path) = begin
  (isremote(path) || !ispath(path)) && return nothing
  file_menu!(e, w, path, items=filter(!=("Rename"), file_menu(path)))
end

"""
Make the tabs' list hold a row for each tab, and shade the tab of the file
that shows. Tabs whose files have gone close, once a second.
"""
fill_tabs!(e, tree) = begin
  t = get(e.nodes, :tabs_checked, 0.0)
  time() - t > 1 && (drop_gone_tabs!(e); e.nodes[:tabs_checked] = time())
  ts = tabs(e)
  rows = tab_rows(e)
  if [item.firstchild.path for item in tree.children] != rows
    kept = Dict(item.firstchild.path => item for item in tree.children)
    foreach(detach!, collect(tree.children))
    foreach(p -> add_child!(tree, get(() -> Tree.Item(TabLabel(path=p)), kept, p)), rows)
  end
  listed = collect(tree.children)
  i = findfirst(item -> item.firstchild.path == e.buf.path, listed)
  tree.focused = i === nothing ? nothing : listed[i]
  seen = Set{String}()
  e.nodes[:tab_twins] = Set(n for n in map(tab_name, ts) if n in seen || (push!(seen, n); false))
  tree
end

"""
Give the Scroll `s` a place of its own. A Scroll with none takes the place that
its node keeps for the Scroll that it made at that point in the frame, so the
tabs' scroll, which shows only while there are many tabs, would take the
place of the folder's files.
"""
own_scroll!(s) = (getfield(s, :state) === nothing && (s.offset = 0px); s)

"The most of the sidebar's height that the tabs take, as a part of the window's height. More tabs scroll."
const TABS_MOST = 1/3

"""
The tabs at the top of the sidebar, with a line under them, or nothing when no
tab is open. When they need more room than `TABS_MOST` of the window, they
scroll, and the tab of the file that shows comes into sight when another file
shows.
"""
tab_list(e) = begin
  rows = tab_rows(e)
  isempty(rows) && return ()
  e.nodes[:tab_keys_shown] = tab_keys_shown!(e)
  tree = fill_tabs!(e, tab_tree(e))
  high = Tree.ROW_HEIGHT   # the height of a row while the theme's text has its usual size, as the sidebar's has
  pad = 6px
  needs = high * length(rows) + 2pad
  room = max(high + 2pad, (window_size(e)[2] - above_page(e)) * TABS_MOST)
  scroll = node!(() -> own_scroll!(Scroll(width(grow=grow), height(grow=grow))), e, :tabs_scroll)
  at = findfirst(==(e.buf.path), rows)
  if needs > room && at !== nothing && get(e.nodes, :tab_shown, "") != e.buf.path
    # The scroll knows how tall it is once it has been laid out, so a scroll that's new waits a frame
    if scroll.viewport > 0px
      scroll_into_view!(scroll, high * (at - 1), high * at + 2pad)   # with the room above the tab and under it
      e.nodes[:tab_shown] = e.buf.path
    else
      redraw_in!(e, 0)
    end
  end
  list = Column(width(grow=grow), Alignment.Start, padding(pad, 8px, pad, 8px),
                with_theme(() -> describe!(tree), panel_theme()))
  (Box(width(grow=grow), height(min(needs, room)), Alignment.Start, name="Tabs", border(1px, :solid, colours.line)[:bottom],
       needs > room ? reuse!(scroll, list) : list),)
end

"Show the sidebar, if it's hidden, and give it the keyboard"
focus_panel!(e) = begin
  e.panel || toggle_panel!(e)
  focus(file_tree(e))
end

"""
The sidebar keeps its width as it slides in and out from the left edge of the
window, so only its right part shows while it's partly out. At its top are the
tabs of the files that are open. Under them, it lists the folder's files, and
under each file that's open in the list, that file's headings and components.
In agent mode it's dark, on the window's glass, as the agent's pane beside
it is, with a line between the two.
"""
describe(s::Sidebar) = (dark = agent_shows(editor(s)); with_pane_colours(() -> sidebar_view(s, dark), dark))

sidebar_view(s::Sidebar, dark::Bool) = begin
  e = editor(s)
  wide = panel_w(e)
  shows = wide * opened(e)
  # A folder shows as a tree of its files, unless code from the startup page lists it another way, as a folder of emails is listed
  own = folder_view(e, directory(e))
  list = own.list === nothing ? Column(width(grow=grow), Alignment.Start, padding(0px, 8px, 12px, 8px),
                                       with_theme(() -> describe!(fill_tree!(e, file_tree(e))), panel_theme())) : own.list
  own_scroll!(e.files_scroll)   # the tabs' scroll comes and goes over it
  Row(fixed(shows), height(grow=grow), Alignment.Start, clip=true,
    Column(fixed(wide), height(grow=grow), Alignment.Start, background(dark ? clear : colours.panel), name="Files",
           border(1px, :solid, dark ? on_glass(0.1) : colours.line)[:right], offset_x=shows - wide,
      (dark ? (PaneColours(on=true, across=true),) : ())...,   # it's drawn with the panes' colours too: see `PaneColours`
      Box(width(grow=grow), height(max(above_page(e), SIDE_GAP) - (dark ? 1px : 0px))),   # under the top bar
      tab_list(e)...,                            # the files that are open, over the folder
      Row(width(grow=grow), height(30px), padding(16px, 0px), Alignment.Center, clip=true, name="Folder",
        folder_trail(e, wide - 32px)...),
      (own.bar === nothing ? () : (own.bar,))...,
      reuse!(e.files_scroll, list),
      (dark ? (PaneColours(on=false, across=true),) : ())...))
end

"""
The side menu of the window while it's about `o`: a node. Ladder's own is its
sidebar. A kind of folder has a method of this to have a side menu of its own
in the sidebar's place: `side_menu(e, d)` for the folder, and
`side_menu(e, d, o)` for each thing `o` that it holds. Ladder's sidebar isn't
there then: nothing of it shows, not its colour, its line, its tabs or its
list. So the kind's menu draws all of itself, on the page's colour.

The kind's menu has the sidebar's room. It's as wide as the sidebar, which you
drag, and it runs from the top of the window to the bottom, so the window's
buttons and the left end of the top bar lie over its top: `above_page(e)` is
how tall that part is. It slides in and out as the sidebar does.

A kind's menu can have a compact form, which stays while the sidebar is
closed: a method of `compact_width` for the menu's node says how wide that is.
The menu then never slides out. It narrows to that width, and it's laid out as
wide as it shows. While the sidebar is closed, `e.panel` is false, and the
menu draws its compact form. Such a menu is always there, so the top bar's own
button that shows and hides the sidebar goes. A method of `side_button` for the
menu's node gives a button of the menu's own for that place.
"""
side_menu(e, o) = side_menu(e, o.parent, o)
side_menu(e, ::Nothing) = side_menu(e, nothing, nothing)
side_menu(e, d, o) = node!(Sidebar, e, :sidebar)

"""
How wide the side menu `menu` stays while the sidebar is closed: its compact
form, like a rail of icons. 0px is a menu that goes when the sidebar closes,
as Ladder's sidebar does. A kind of folder has a method of this for the node
that its `side_menu` gives.
"""
compact_width(menu) = 0px

"""
The button that the top bar has for the side menu `menu`, in the place of its
own button that shows and hides the sidebar: a node 30px wide at the most, or
nothing. The top bar lies over the top of the menu and takes the clicks there,
so a button in that place is the bar's to draw. It's asked only for a menu
with a compact form. Its click calls `toggle_panel!(e)`.
"""
side_button(menu) = nothing

"""
Find the side menu of the window of `e` for this frame, before anything is
laid out: the page beside it needs its width. `side_part` shows it.
"""
side_tick!(e) = begin
  menu = side_menu(e, window_object(e))
  own = !(menu isa Sidebar)
  window_parts(e).side_menu = menu
  e.nodes[:own_side_menu] = own
  least = own ? clamp(compact_width(menu), 0px, panel_w(e)) : 0px
  e.nodes[:side_least] = least
  # In agent mode the agent's pane is beside the side menu, and it gives the menu its room: see `menu_room`. While the
  # menu slides, the pane is as wide as it is beside the open menu, so its words don't wrap again in each frame.
  e.nodes[:menu_room] = !agent_shows(e) ? 0px : e.panel || sliding(e) ? panel_w(e) : least
  agent_shows(e) && sliding(e) && redraw_in!(e, 0)   # one more frame after the slide ends gives the pane its room back
  nothing
end

"How wide the side menu stays while the sidebar is closed: its compact form's width, or 0px"
side_least(e) = get(e.nodes, :side_least, 0px)

"""
How wide the sidebar is now, or the side menu that a kind of folder has in its
place: all of its width while it's open, none while it's closed, or the width
of its compact form, and between the two while it slides.
"""
menu_w(e) = (least = side_least(e); least + (panel_w(e) - least) * opened(e))

"""
How wide all that's at the left of the page is now: the sidebar, or the side
menu that a kind of folder has in its place, and in agent mode the agent's
pane beside it.
"""
side_w(e) = menu_w(e) + (agent_shows(e) ? agent_wide(e) : 0px)

"""
What's at the left of the window of `e`: Ladder's sidebar, or the side menu
that a kind of folder has in its place, in the sidebar's room.
"""
side_part(e) = begin
  window_parts(e).side_menu === nothing && side_tick!(e)
  menu = window_parts(e).side_menu
  menu isa Sidebar && return menu
  wide, shows = panel_w(e), menu_w(e)
  # A menu with a compact form narrows to it, and is laid out as wide as it shows
  side_least(e) > 0px && return Row(fixed(shows), height(grow=grow), Alignment.Start, clip=sliding(e), name="Side menu", menu)
  # Another keeps its width while it slides, as the sidebar does. Once it's open nothing clips it, so a shadow of its own shows whole.
  Row(fixed(shows), height(grow=grow), Alignment.Start, clip=opened(e) < 1, name="Side menu",
    Column(fixed(wide), height(grow=grow), Alignment.Start, offset_x=shows - wide, menu))
end

"True when the window has a side menu that a kind of folder made, in the place of Ladder's sidebar"
own_side_menu(e) = get(e.nodes, :own_side_menu, false) === true

"True when the sidebar shows Ladder's own tree of the folder's files, and not a list or a menu that a kind of folder made"
files_listed(e) = !own_side_menu(e) && folder_view(e, directory(e)).list === nothing
