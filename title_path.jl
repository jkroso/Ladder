# The file's name in the top bar, the path that it grows into, and the lists and the search under a › of the path
#
# The path, the list of a folder and the search are in one file because each
# needs the types and the constants of the others.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" draw ishovered cursor show_tooltip! redraw_in! rect popup! close_popup! placed! popups sync_mouse!
@use "github.com/jkroso/UI.jl/Interface/window" drag_window!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./markdown" Kind
@use "./find" => Searches
@use "./remote" => Remote
@use "./folders" => Folders
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
@use "./takeoff_view" exports...
@use "./fill_view" exports...
@use "./view_block" exports...
@use "./slides_view" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...
@use "./agent/window" exports...
@use "./code_thing" exports...
@use "./copied_blocks" exports...
@use "./top_bar" exports...
@use "./right_panel" exports...
@use "./commands" exports...
@use "./sidebar" exports...

export FolderList, FolderRow, PartArrow, RUN_ICONS, SearchButton, SearchChip, SearchFound,
       SearchMenu, SearchOption, TS_KEY, TS_MENU, TS_MOST, TS_ROWS, TS_WIDE, TT_AIM, TT_ARROW,
       TT_BROAD, TT_EDGE, TT_H, TT_LIST, TT_MARK, TT_MOST, TT_NARROW, TT_PAD, TT_PART, TT_ROOM,
       TT_ROWS, TT_WAIT, TitleArrow, TitleCrumb, TitleGap, TitlePart, TitleSearch, TitleTrail,
       ask_search!, bar_name, caret_run, close_folder_lists!, close_search_menu!,
       close_title_search!, crumb_tip!, edited_wide, focus_parts, folder_arrow, folder_lists,
       heading_mark, kind_options, left_list!, left_search!, list_key, listing_parts, menu_rows!,
       open_beside!, open_folder_list!, open_search_menu!, open_title_search!, part_goes,
       part_width, parts_wide, pin_trail!, read_folder!, rest_tick!, rows!, search_box,
       search_field, search_file_name, search_go!, search_heading, search_icon, search_kind_name,
       search_kinds_name, search_list, search_place, search_rows!, search_summary, search_tick!,
       searchable, show_title_trail!, take_option!, title_edited, title_go!, title_listing,
       title_parts, title_place, title_steps, title_trail!, title_wide, title_widths,
       trail_can_show, trail_ground, trail_parts_wide, trail_pinned, trail_view, under_lines,
       unfill_page!, SearchAsked, search_asked, TitlePathState

# --- the file's name in the top bar ----------------------------------------------------------

# The window has no title bar, so you move it by dragging the top bar
onkey(t::TopBar, ::KeyPress{Keys.mouse_left}) = drag_window!(window_of(t))

# A right-click on the file's name shows the same menu as a right-click on the
# file in the sidebar. While the file is renamed from there, a text field with
# its name is where the name was.

describe(t::Title) = begin
  e = editor(t)
  b = e.buf
  title_trail!(e, t)   # the path shows over the bar while the mouse is over the name
  nofile(e) && return Box()   # a window with no file has no name to show
  if !isempty(b.path) && renaming(e, :title) == b.path
    # The field grows as the name gets longer
    wide = clamp(measure(Face(SANS, "", 13px, colours.ink, false), renamer(e).text) + 24px, 160px, 420px)
    return Box(width(wide), height(22px), padding(5px, 0px), radius(4px), Alignment.Start, background(colours.bg),
               border(1px, :solid, colours.accent), renamer(e))
  end
  edited = title_edited(e)
  # A name that's too long for its room in the bar ends in …, so that its start still shows
  room = something(bar_space(e).title, 10_000px) - (edited ? 70px : 16px)
  named = bar_name(e)
  # The headings over the caret and the component that it's on follow the name, as the path does. The name
  # stays in the middle while they change, so as much room as they take is empty before it. When there's
  # too little room, the biggest headings go first.
  parts = focus_parts(e)
  face = Face(SANS, "", 13px, colours.ink, false)
  while !isempty(parts) && measure(face, named) + 2parts_wide(parts) > room
    popfirst!(parts)
  end
  after = parts_wide(parts)
  state_of(e, TitlePathState).lead = isempty(parts) ? 0px : after + 6px   # how far the name is from the left of the title, for the path
  Row(child_gap=6px, Alignment.Center,
    (isempty(parts) ? () : (Box(width(after)),))...,
    label(elide(named, 13px, max(room - 2after, 40px)), 13px, color=colours.dim),
    (edited ? (label("— edited", 13px, color=colours.faint),) : ())...,
    (isempty(parts) ? () : (title_parts(parts),))...)
end

"""
The headings and the component after the file's name in the top bar, each
after a ›, with the sizes that the path gives them. A heading shows only its
mark, like H2, so that the path stays short. A component's name is its kind,
like Sheet.
"""
title_parts(parts) =
  Row(Alignment.Center, name="Parts",
    # The room round each piece is a Box of its own: a label in a Row with padding is at the Row's top, not in its middle
    (Row(Alignment.Center,
       Box(width(TT_ARROW), height(16px), Alignment.Center, justify=Alignment.Center, Icon("chevron-right", size=8px, color=colours.faint)),
       Box(width(TT_PAD)),
       (x.level < 7 ? (heading_mark(x, colours.dim),) :
        (Icon(x.icon, size=11px, color=colours.faint), Box(width(4px)), label(elide(x.title, 13px, TT_PART), 13px, color=colours.dim)))...,
       Box(width(TT_PAD)))
     for x in parts)...)

"""
The name that the top bar shows: the page's title, or the name of its file.
A page from a web server has the last name of its address, like `City` or
`notes.md`, as the path shows it, and the path starts with the server's name.
"""
bar_name(e) = something(page_title(e), (at = web_address(e.buf.path); isempty(at) ? name(e.buf) : Remote.trail(at)[end][1]))

"""
True when the file's name says "— edited", in the top bar and in its path: the
file has changes that aren't saved. A page whose parts of other pages were
changed there is edited too, since ⌘S saves them with it, and so is a page of
a kind that has changes of its own, like a SolidCraft design.
"""
title_edited(e) = (b = e.buf; dirty(b) || any(dirty, shown_buffers(e)) || page_edited(e))

onkey(t::Title, ::KeyPress{Keys.mouse_right}) = begin
  e = editor(t)
  isempty(e.buf.path) || isremote(e.buf.path) || file_menu!(e, window_of(t), e.buf.path; at=:title)
  handled
end

# --- the path in the top bar -----------------------------------------------------------------
#
# Hold the mouse over the file's name in the top bar, and the name grows into
# its path: the name of each folder on the way to the file, like
# `~ › Desktop › Canon › Quotes.md`. The file's name stays where it was, and
# the folders come in to its left. The path floats over the rest of the bar,
# so nothing in the bar moves. When the window is too narrow for every name,
# the folders furthest from the file shrink to their first letter, as in the
# sidebar. The path goes when the mouse leaves it.
#
#   - A click on a folder opens it in the page: its own page, like the home
#     folder's or a desktop's, or a list of what's in it.
#   - A click on a › shows a list of what's in the folder before it, under
#     the ›. Rest the mouse on a folder in it, and a list of what's in that
#     folder opens beside it. Click a file to show it, or a folder to open it.
#     See "the list of a folder, under a › of the path".
#   - A right-click on a name shows the menu of that folder or file.
#   - A click on the file's name pins the path: it stays open when the mouse
#     leaves it, and while you open folders from it, until a second click on
#     the name. A pinned path is in the middle of the bar, where the file's
#     name is, and has no border or shadow, since it's part of the bar. Its
#     file's name isn't shaded, as no name is until the mouse is over it.
#     The pin is a setting: every window has it, and it stays the next time
#     the app opens.
#
# After the file's name come the headings over the caret, from the biggest,
# and the component that the caret is on: `welcome.md › H2 › Sheet`. A heading
# shows only its mark, so the path stays short, and a component its icon and
# the name of its kind, as the sidebar has them. When the caret is in inline
# code, a link, bold words or another run of a line that's drawn its own way,
# that run comes last, by its kind: `welcome.md › H2 › Code`. The bar shows them
# after the name all the time, and the path shows them too. A click on a
# heading of the path puts the caret on it. A page that's only read has no
# caret, and so none.
#
# A › follows the file's name and each heading of the path, as one follows
# each folder. A click on it shows a search of what's in the file, or under
# the heading: see "a search of a page's parts".
#
# So you can go anywhere from the top bar, with the sidebar hidden.

"The path of the file that the top bar shows, as names to click"
@def mutable struct TitleTrail <: SemanticUI
  path::String = ""
  steps::Vector{Tuple{String,String}} = Tuple{String,String}[]   # the name and the path of each step, as they show. "…" has no path.
  all::Vector{Tuple{String,String}} = Tuple{String,String}[]     # each step with its whole name, as it would show with room for all of them
  size::Any = nothing                                            # how big the window was when the path was put in place
  crumbs::Dict{String,Any} = Dict{String,Any}()                  # the TitleCrumb of each step, by its path
  gap::Any = nothing                                             # the TitleGap, when an … stands for folders that there's no room for
  arrows::Dict{String,Any} = Dict{String,Any}()                  # the TitleArrow after each folder, by the folder's path
  parts::Vector{Entry} = Entry[]                                 # the headings over the caret and the component that it's on, after the file's name
  marks::Dict{Int,Any} = Dict{Int,Any}()                         # the TitlePart of each of those
  drops::Dict{Int,Any} = Dict{Int,Any}()                         # the PartArrow after the file's name (0) and after each heading, by its place in `parts`
  centred::Bool = false                                          # true when it's in the middle of the bar, as a pinned path is
  title_at::Any = nothing                                        # where the file's name was in the bar when the path was put in place
end

"A heading over the caret, or the component that the caret is on, after the file's name in the path"
@def mutable struct TitlePart <: SemanticUI
  k::Int = 0   # which of the path's parts it is
end

"The › after the file's name, or after a heading, in the path. A click shows a search of what's in the file, or under the heading."
@def mutable struct PartArrow <: SemanticUI
  k::Int = 0   # 0 after the file's name, or the place in the path's parts of the heading that it's after
end

"One name of the path in the top bar: a folder, or the file at the end"
@def mutable struct TitleCrumb <: SemanticUI
  path::String = ""
  name::String = ""   # as it shows, which can be shorter than its whole name
  full::String = ""   # its whole name
  last::Bool = false
end

"The … of the path in the top bar, in the place of folders that there's no room for"
@def mutable struct TitleGap <: SemanticUI
  names::Vector{String} = String[]   # the folders that it stands for, from the left
end

"The › after a folder's name in the top bar. A click shows a menu of what's in the folder."
@def mutable struct TitleArrow <: SemanticUI
  path::String = ""
end

const TT_H = 26px       # how tall the path is
const TT_PAD = 7px      # inside a name, on each side
const TT_ARROW = 14px   # how wide a › is
const TT_EDGE = 4px     # inside the path, at each end
const TT_WAIT = 0.15    # how many seconds the mouse is over the name before the path shows
const TT_MOST = 80      # the most things that a list of a folder shows
const TT_PART = 180px   # how wide the name of a component in the path can be
const TT_MARK = 14px    # how big a heading's mark is in the path, like H2

"""
True when a click on the file's name pinned the path open, so it stays when
the mouse leaves it. It's a setting: each window has the path pinned, and it
stays pinned the next time the app opens. A page that shows the path itself,
like a SolidCraft design in its toolbar, has little room for it, so there the
path shows only while the mouse is over the name: see `crumb_in_page`.
"""
trail_pinned(e) = e.pinned && !crumb_in_page(e)

"How wide each name of `steps` is in the top bar. The file's name is a little bolder."
title_widths(steps) = [measure(Face(SANS, i == length(steps) ? "Medium" : "", 13px, colours.ink, false), n) + 2TT_PAD
                       for (i, (n, _)) in enumerate(steps)]

"How wide the path of `steps` is, from edge to edge"
title_wide(steps) = sum(title_widths(steps)) + TT_ARROW * (length(steps) - 1) + 2TT_EDGE + 2px

"""
The mark of the heading `x` in the path, like H2. The letters of the mark sit
high in its icon, so it's 1px lower than the middle, to stand on the line of
the names beside it.
"""
heading_mark(x::Entry, color) = Box(padding(1px, 0px, 0px, 0px), Icon(x.icon, size=TT_MARK, color=color))

"How wide the heading or the component `x` is in the path: a heading's mark, or a component's icon and name"
part_width(x::Entry) = (x.level < 7 ? TT_MARK : measure(Face(SANS, "", 13px, colours.ink, false), elide(x.title, 13px, TT_PART)) + 15px) + 2TT_PAD

"How wide the headings and the component after the file's name are, with a › before each"
parts_wide(parts) = sum((part_width(x) + TT_ARROW for x in parts), init=0px)

"True when the path has a › after the file's name, to search the file: a Markdown page, of the Mac or from a web server"
searchable(e) = e.buf.view == :markdown && (isfile(e.buf.path) || isremote(e.buf.path))

"True when the path ends with a › after the name of the folder that the page shows, which lists what's in it, as each › after a folder does"
folder_arrow(e) = e.buf.view == :file && !isremote(e.buf.path) && isdir(e.buf.path)

"How wide the path's parts after the file's name are: each heading and the component, with the › before each, and the › after the last heading, or the › after a folder's name"
trail_parts_wide(e, parts) = searchable(e) ? parts_wide(parts) + (isempty(parts) || parts[end].level < 7 ? TT_ARROW : 0px) : folder_arrow(e) ? TT_ARROW : 0px

"""
The headings over the caret, from the biggest, then the component that the
caret is on, if it's on one, as the sidebar names them, then the run of text
that the caret is in, like inline code or a link (see `caret_run`). The path in
the top bar shows them after the file's name. A page with no caret has none:
one that's only read, one that Ladder only shows, and one that isn't Markdown.
"""
focus_parts(e) = begin
  b = e.buf
  (b.view == :markdown && !caretless(b)) || return Entry[]
  line = b.caret[1]
  ks = kinds(b)
  # The bar asks in every frame, and a code block in a language of its own makes `outline` look for a file, so it's kept until the text changes
  s = state_of(e, TitlePathState)
  kept = s.outline
  found = kept !== nothing && kept[1] === b && kept[2] == b.version ? kept[3] : (s.outline = (b, b.version, outline(b)))[3]
  heads, on = Entry[], nothing
  for x in found
    x.line > line && break
    if x.level < 7
      # A heading takes the place of the last one of its size or smaller
      while !isempty(heads) && heads[end].level >= x.level
        pop!(heads)
      end
      push!(heads, x)
      on = nothing
    else
      # The caret is on a component from the line that opens its block to the one that closes it
      close = something(findnext(k -> k.kind == Kind.fence, ks, x.line + 1), length(b.lines))
      on = line <= close ? x : nothing
    end
  end
  on === nothing || push!(heads, on)
  run = caret_run(b)
  run === nothing ? heads : push!(heads, run)
end

"The icon of each kind of run of text in the path in the top bar, by the name that `span_kind` gives it"
const RUN_ICONS = Dict("Code" => "code", "Link" => "link-45deg", "Wiki link" => "link", "Footnote" => "superscript",
                       "Value" => "lightning-charge", "Comment" => "chat-left-text", "Highlighted" => "highlighter",
                       "Formula" => "plus-slash-minus", "Struck" => "type-strikethrough", "Bold" => "type-bold",
                       "Bold italic" => "type-bold", "Italic" => "type-italic")
push!(BLOCK_ICONS, values(RUN_ICONS)...)

"""
The run of text that the caret is in, as the last part of the path in the top
bar: inline code, a link, bold words, or another run that's drawn its own way,
as ⌘⌥ picks them. Its title is its kind, like Code, and its level is 8, deeper
than a component's. It's nothing on plain words, and on a line with no runs,
like a line of a code block. The caret is in a run from just before its first
letter to just after its last, inside its markup.
"""
caret_run(b) = begin
  line, col = b.caret
  kinds(b)[line].kind in (TEXT_KINDS..., Kind.table) || return nothing
  open = raw_part(b, line)
  for s in richspans(b, line)[2]
    (!s.markup && s.col <= col <= s.col + length(s.text)) || continue
    kind = span_kind(s.link, s, israw(b, line) || markup_shows(open, s.col, s.col + length(s.text)))
    kind === nothing || return Entry(line, 8, kind, RUN_ICONS[kind], line)
  end
  nothing
end

"""
The steps of `all` that fit in `room`. The names furthest from the file shrink
to their first letter, from the left, as the sidebar's trail does. If that
still doesn't fit, an … takes the place of names after the first, and last of
all the file's own name loses its middle.
"""
title_steps(all, room) = begin
  short = copy(all)
  initial(n) = startswith(n, '.') ? first(n, 2) : first(n, 1)
  for i in 2:length(short)-1
    title_wide(short) <= room && return short
    short[i] = (initial(short[i][1]), short[i][2])
  end
  while title_wide(short) > room && length(short) > 2 && short[2][1] != "…"
    deleteat!(short, 2)
    length(short) > 2 ? (short[2] = ("…", "")) : insert!(short, 2, ("…", ""))
  end
  while title_wide(short) > room && length(short) > 3
    deleteat!(short, 3)
  end
  name, at = short[end]
  k = length(name) ÷ 2
  while title_wide(short) > room && k > 2
    k -= 1
    short[end] = (first(name, k) * "…" * last(name, k), at)
  end
  short
end

"""
True when the path of the file can show over the top bar: the window has a
file, of the Mac or of a web server, whose name isn't being changed, and no
list like the file finder covers the page.
"""
trail_can_show(e) = begin
  path = e.buf.path
  # A page from a web server has a path too, from the server's name
  !nofile(e) && (isremote(path) || (isabspath(path) && isdir(dirname(path)))) && renaming(e, :title) != path && e.popup == :none
end

"""
Show the path of the file over the top bar while the mouse is over the file's
name, once it has been there for a moment, and take it away when the mouse
leaves the name and the path. ⌘F shows it too, with the search under the ›
after the file's name: see `find!`.
"""
title_trail!(e, t) = begin
  w = window_of(t)
  w === nothing && return
  path = e.buf.path
  open = any(p -> p.key == :title_trail, popups(w))
  # A list of a folder under a ›, or a search under one, keeps the path, until a click or Esc takes it away
  searching = any(p -> p.key == TS_KEY, popups(w))
  listing = searching || any(p -> p.content isa FolderList, popups(w))
  # A pinned path shows while the bar shows the file's name, with the mouse anywhere
  pinned = trail_pinned(e) && slideshow(e) === nothing && !as_app(e) && !screening(e)
  # ⌘F asked for the search, which opens once the path is in place
  asked = search_asked(e)
  if !((ishovered(t) || listing || pinned || asked) && trail_can_show(e))
    state_of(e, TitlePathState).hover = nothing
    state_of(e, SearchAsked).words = nothing
    listing && (close_folder_lists!(e, w); close_title_search!(e, w))
    open && close_popup!(w, :title_trail)
    return
  end
  searching && search_tick!(e, w)
  s = state_of(e, TitlePathState)
  since = s.hover = something(s.hover, time())
  !pinned && !asked && time() - since < TT_WAIT && return redraw_in!(e, TT_WAIT)
  kept = s.trail
  # The path follows the file's name when the name moves, as it does while a sidebar or git's panel slides open.
  # The name's place is from the last frame, so one more frame checks that the path is where the name is now.
  placed = open && kept !== nothing && kept.path == path && kept.size == window_size(e) && kept.parts == focus_parts(e) &&
           (kept.centred || !pinned) && kept.title_at == title_place(e, t)
  placed || (show_title_trail!(e, t, w, path); redraw_in!(e, 0))
  # A top bar that hides moves the path while it slides out, and a move closes the search. So the search waits for the bar.
  asked && placed && !bar_sliding(e) && ask_search!(e, w, kept)
  # A window hears nothing when the mouse leaves it, so the path looks for itself. A pinned path stays, so it looks only while the mouse is on it.
  isempty(w.glfw) || (pinned && !ishovered(t)) || (sync_mouse!(w); redraw_in!(e, 0.2))
  nothing
end

"""
Where the file's name is in the top bar, or in a page that shows the path
itself: the left edge, the top and the width of its node, the room in it
before the name, how far the bar has slid, and whether the name says "— edited"
"""
title_place(e, t) = (r = rect(t); r === nothing ? nothing : (r.left, r.top, r.width, state_of(e, TitlePathState).lead, bar_top(e), title_edited(e)))

"How wide \"— edited\" is after the file's name in the path, with the room after it, or 0px when the file has no changes"
edited_wide(e) = title_edited(e) ? measure(Face(SANS, "", 13px, colours.ink, false), "— edited") + TT_PAD : 0px

"Put the path to `path` over the top bar, with the file's name where the bar shows it"
show_title_trail!(e, t, w, path) = begin
  r = rect(t)
  r === nothing && return
  # The path moves, so a list or a search under one of its › would point at nothing
  close_folder_lists!(e, w)
  any(p -> p.key == TS_KEY, popups(w)) && close_title_search!(e, w)
  wide = window_size(e)[1]
  # The Mac draws its close, minimise and zoom buttons over the window, so the path starts after them
  start = mac_buttons_room(e) + 4px
  # In a page that shows the path itself, like a design's toolbar, the path has the room that the page gives the name
  inpage = crumb_in_page(e)
  room = inpage ? min(something(bar_space(e).title, wide), wide - 8px - start) : wide - 8px - start
  all = trail_steps(path)
  all[end] = (bar_name(e), path)   # the file's name as the bar shows it
  parts = focus_parts(e)
  more = trail_parts_wide(e, parts) + edited_wide(e)   # what follows the file's name
  shown = title_steps(all, room - more)
  # In the page the name is in the middle of its room, and the path stays in that room. The file's name stays where it
  # was, under the mouse, so the folders before it have only the room from the left end to the name, and their names
  # shrink to fit it, as in the sidebar.
  lo = r.left + r.width / 2 - room / 2
  if inpage
    left = r.left + state_of(e, TitlePathState).lead - lo   # the room for the folders, before the name
    shown = title_steps(all, min(room - more, left + title_widths(all[end:end])[1] - TT_PAD + TT_EDGE + 1px))
  end
  s = state_of(e, TitlePathState)
  s.trail === nothing && (s.trail = own!(t, TitleTrail()))
  v = s.trail
  v.path == path || (empty!(v.crumbs); empty!(v.arrows))
  # A pinned path is in the middle of the bar. After a click unpins it, it stays there until it closes, so the name doesn't move from under the mouse.
  v.centred = trail_pinned(e) || (v.centred && any(p -> p.key == :title_trail, popups(w)))
  v.path, v.steps, v.all, v.size, v.parts, v.title_at = path, shown, all, window_size(e), parts, title_place(e, t)
  widths = title_widths(shown)
  total = title_wide(shown) + more
  # How far the file's name is from the path's left edge
  before = sum(widths[1:end-1], init=0px) + TT_ARROW * (length(shown) - 1) + TT_EDGE + 1px + TT_PAD
  # The name is in the middle of its room in the bar, with the headings after it and as much room before it, so the middle of the name's node is the bar's
  x = v.centred ? r.left + r.width / 2 - total / 2 : r.left + state_of(e, TitlePathState).lead - before
  # In the page the path stays in the name's room, so it lies over nothing else of the page
  inpage && (x = clamp(x, lo, max(lo, lo + room - total)))
  x = clamp(x, start, max(start, wide - 8px - total))
  top = inpage ? r.top + (r.height - TT_H) / 2 : bar_top(e) + (TOPBAR_H - TT_H) / 2
  popup!(w, v, anchor=(x, top), placement=:below, gap=0px, width=total, key=:title_trail, modal=false, theme=menu_theme())
  nothing
end

# The path lies over the middle of the bar, so it has the bar's colours there: a web page's, when the bar has them
describe(v::TitleTrail) = with_colours(() -> trail_view(v), bar_inks(editor(v))[2])

trail_view(v::TitleTrail) = begin
  # The path goes when the bar stops showing the file's name: as slides, as an app, or under a video that fills the screen
  e = editor(v)
  (slideshow(e) !== nothing || as_app(e) || screening(e) || nofile(e)) && (w = window_of(v); w === nothing || close_popup!(w, :title_trail))
  arrow() = Box(width(TT_ARROW), height(grow=grow), Alignment.Center, justify=Alignment.Center,
                Icon("chevron-right", size=8px, color=colours.faint))
  parts = Any[]
  n = length(v.steps)
  for (i, (name, path)) in enumerate(v.steps)
    if i > 1
      # The › after a folder lists what's in it. The one after an … stands for folders that aren't shown, and one
      # after a folder of a web server only stands between two names, since a server doesn't say what's in a folder.
      before = v.steps[i-1][2]
      push!(parts, isempty(before) || isremote(before) ? arrow() : get!(() -> own!(v, TitleArrow(path=before)), v.arrows, before))
    end
    if isempty(path)
      # The … knows the names of the folders that it stands for: those between the steps either side of it
      g = v.gap === nothing ? (v.gap = own!(v, TitleGap())) : v.gap
      from, to = (findfirst(s -> s[2] == v.steps[j][2], v.all) for j in (i - 1, i + 1))
      g.names = from === nothing || to === nothing ? String[] : first.(v.all[from+1:to-1])
      push!(parts, g)
    else
      c = get!(() -> own!(v, TitleCrumb(path=path)), v.crumbs, path)
      c.name, c.last = name, i == n
      k = findfirst(s -> s[2] == path, v.all)
      c.full = k === nothing ? name : v.all[k][1]
      push!(parts, c)
    end
  end
  # A file with changes that aren't saved says so after its name, as the name in the bar does
  title_edited(e) && push!(parts, Box(height(grow=grow), padding(0px, TT_PAD, 0px, 0px), Alignment.Center, justify=Alignment.Center,
                                      label("— edited", 13px, color=colours.faint)))
  # A folder that the page shows has a › after its name, which lists what's in it
  if folder_arrow(e) && n > 0 && !isempty(v.steps[n][2])
    at = v.steps[n][2]
    push!(parts, get!(() -> own!(v, TitleArrow(path=at)), v.arrows, at))
  end
  # The headings over the caret and the component that it's on. A › follows the file's name and each heading.
  if searchable(e)
    drop(k) = get!(() -> own!(v, PartArrow(k=k)), v.drops, k)
    push!(parts, drop(0))
    for k in eachindex(v.parts)
      push!(parts, get!(() -> own!(v, TitlePart(k=k)), v.marks, k))
      v.parts[k].level < 7 && push!(parts, drop(k))
    end
  end
  # Each name fills the height inside the border and 1px more, so its hover box has as much room above it as below.
  # A pinned path has no shadow and no border: it's part of the bar, not something that floats over the page. Its
  # border is clear, so that its names stay where they are.
  pinned = trail_pinned(e)
  Row(width(grow=grow), height(TT_H), padding(TT_EDGE, 1px), radius(7px), Alignment.Center, name="Path",
      background(trail_ground(e)), border(1px, :solid, pinned ? clear : colours.line), (pinned ? () : (lifted,))..., parts...)
end

"What the path lies on: the page's colour, as the bar has, or in a page that shows the path itself, the colour of its place there (see `page_crumb`)"
trail_ground(e) = crumb_in_page(e) ? something(bar_space(e).ground, colours.bg) : colours.bg

# A name is shaded only while the mouse is over it, so a pinned path doesn't look as if its file were chosen
describe(c::TitleCrumb) =
  Box(height(grow=grow), padding(TT_PAD, 0px), radius(5px), Alignment.Center, justify=Alignment.Center, name="Step",
      background(ishovered(c) ? colours.hover : clear),
    label(c.name, 13px, color=c.last ? colours.ink : colours.dim, weight=c.last ? "Medium" : ""))

describe(g::TitleGap) =
  Box(height(grow=grow), padding(TT_PAD, 0px), Alignment.Center, justify=Alignment.Center, name="Gap",
    label("…", 13px, color=colours.faint))

# A name that's shorter than its whole name, to fit, shows its whole name in a tooltip while the mouse is over it.
# The … shows the names of the folders that it stands for.
onmouse(c::TitleCrumb, ev::MouseMove) = (c.name == c.full || crumb_tip!(c, ev.window, c.full); nothing)
onmouse(g::TitleGap, ev::MouseMove) = (isempty(g.names) || crumb_tip!(g, ev.window, join(g.names, " › ")); nothing)

"Show `words` in a tooltip under `node`, a part of the path. The path is a popup, so the tooltip goes by the node's rectangle: one that follows a node in a popup closes at once."
crumb_tip!(node, w, words) = (r = rect(node); r === nothing || show_tooltip!(w, tip_label(words), r.left, r.top, r.width, r.height, placement=:bottom, gap=6px); nothing)

describe(a::TitleArrow) = begin
  # It's shaded while its list shows under it
  w = window_of(a)
  dropped = w !== nothing && any(p -> p.content isa FolderList && p.content.arrow === a, popups(w))
  Box(width(TT_ARROW), height(grow=grow), radius(4px), Alignment.Center, justify=Alignment.Center, name="Arrow",
      background(ishovered(a) || dropped ? colours.hover : clear),
    Icon("chevron-right", size=8px, color=colours.faint))
end

describe(p::TitlePart) = begin
  v = p.parent
  p.k in eachindex(v.parts) || return Box(width(0px))
  x = v.parts[p.k]
  last = p.k == length(v.parts)
  # A heading shows only its mark, like H2, and a component its icon and its kind
  Row(height(grow=grow), padding(TT_PAD, 0px), radius(5px), child_gap=4px, Alignment.Center, name="Part",
      background(part_goes(p) && ishovered(p) ? colours.hover : clear),
    (x.level < 7 ? (heading_mark(x, last ? colours.ink : colours.dim),) :
     (Icon(x.icon, size=11px, color=colours.faint), label(elide(x.title, 13px, TT_PART), 13px, color=last ? colours.ink : colours.dim)))...)
end

describe(a::PartArrow) = begin
  # It's shaded while its search shows under it
  w = window_of(a)
  dropped = w !== nothing && any(p -> p.content isa TitleSearch && p.content.arrow === a, popups(w))
  Box(width(TT_ARROW), height(grow=grow), radius(4px), Alignment.Center, justify=Alignment.Center, name="Arrow",
      background(ishovered(a) || dropped ? colours.hover : clear),
    Icon("chevron-right", size=8px, color=colours.faint))
end

cursor(::TitleCrumb) = :hand
cursor(p::TitlePart) = part_goes(p) ? :hand : :arrow
cursor(::PartArrow) = :hand

"""
True when a click on the part `p` of the path goes somewhere. The last part is
where the caret is already, so it goes nowhere while the page shows. While a
view, a model or a block fills the window, every part goes back to the page.
"""
part_goes(p::TitlePart) = (v = p.parent; p.k in eachindex(v.parts) && (p.k < length(v.parts) || filled(editor(p))))

"""
Put the page back when something fills the window in its place: a view, a
picture or a model, a takeoff or a sketch, or the lines of a block. A click on
a heading or a component in the path in the top bar does this before it goes
to that heading or component in the page.
"""
unfill_page!(e) = begin
  v = zooming(e)
  v === nothing || zoom_out!(v, false)
  # Only this page's block: a block of another page still fills the window when Back goes to that page
  block = full_block(e)
  block === nothing || (block.full = false)
  lowered(e) === nothing || widen!(e)
  nothing
end

# A click on a heading puts the caret on it, as a click on it in the sidebar does. While something fills the window, the page comes back first.
onkey(p::TitlePart, ev::KeyPress{Keys.mouse_left}) = begin
  v = p.parent
  e = editor(p)
  part_goes(p) && (unfill_page!(e); focus(e); go_entry!(e, v.parts[p.k].line, v.parts[p.k].caret))
  handled
end
onkey(a::PartArrow, ev::KeyPress{Keys.mouse_left}) = open_title_search!(editor(a), ev.window, a)
cursor(::TitleArrow) = :hand

# A click on the file's name pins the path. In a page that shows the path itself the path is never pinned, so there it does nothing.
onkey(c::TitleCrumb, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(c)
  c.last ? (crumb_in_page(e) || pin_trail!(e)) : title_go!(e, ev.window, c.path)
  handled
end

"Pin the path in the top bar open, or let it close again when the mouse leaves it, in each window, and keep that in the settings"
pin_trail!(e) = (e.pinned = !e.pinned; save_settings!(e); nothing)
onkey(a::TitleArrow, ev::KeyPress{Keys.mouse_left}) = (open_folder_list!(editor(a), ev.window, a); handled)

# A right-click on a name shows the menu of its folder or file, as in the sidebar. Only the file's own name can be renamed in the bar.
onkey(c::TitleCrumb, ev::KeyPress{Keys.mouse_right}) = begin
  e = editor(c)
  isremote(c.path) && return handled   # a folder of a web server has no file menu, but the file of the browser folder that shows has
  c.last ? file_menu!(e, ev.window, c.path; at=:title) : file_menu!(e, ev.window, c.path; items=filter(!=("Rename"), file_menu(c.path)))
  handled
end

"""
Do what a choice of the folder or the file at `path` in the top bar does: a
file shows, and a folder opens in the page. A folder of a web server is asked
for, as a link to it is: its page shows when it has one in Markdown.
"""
title_go!(e, w, path) = (close_folder_lists!(e, w); close_popup!(w, :title_trail); isremote(path) ? get_page!(e, path) : open_folder!(e, path); nothing)

"What's in the folder `dir`, by name, its folders first, or nothing when it can't be read. Hidden ones, and the ones that you ignore, show while the sidebar shows them."
title_listing(e, dir) = begin
  names = try readdir(dir) catch; return nothing end
  ignored = Folders.ignored()
  filter!(n -> n != ".DS_Store" && (e.hidden || !left_out(joinpath(dir, n), ignored)), names)
  folder(n) = (p = joinpath(dir, n); isdir(p) && !ispackage(p))
  kinds = Dict(n => folder(n) for n in names)
  sort!(names, by=n -> (!kinds[n], lowercase(n)))
  (names, kinds)
end

# --- the list of a folder, under a › of the path ---
#
# A click on a › of the path shows what's in the folder before it, in a list
# under the ›. It looks like the other lists that float beside what they're
# for, like the list of a `find` block's kinds (see `float_list`), with a field
# at its top that has the keyboard. Its folders come first, then its files.
# What's on the way to the file that shows is in bold.
#
#   - Type in the field, and the list keeps the names that have the words typed.
#   - A click on a name, or Return, shows the file or opens the folder in the page.
#   - Rest the mouse on a folder, or press →, and a list of what's in it opens
#     beside it, as a submenu does. ← takes that list away again.
#   - The up and down arrows pick a name. Esc, a click somewhere else, or a
#     second click on the › takes every list away.
#
# The lists are popups with no parent in the window, so a key that they don't
# use goes to the field, and never on to the page.

const TT_LIST = :folder_list   # the key of the popup of the list under a ›. Each list beside it adds its level.
const TT_ROWS = 12             # the rows that a list shows before it scrolls
const TT_NARROW = 200px        # how wide a list is, at least
const TT_BROAD = 320px         # and at most
const TT_ROOM = 72px           # how much wider a list is than the longest name in it: its icon, its › and its edges
const TT_AIM = 18px            # how far the caret of the list under a › is from the list's left edge

"A list of what's in a folder, under a › of the path in the top bar, or beside a folder of such a list"
@def mutable struct FolderList <: SemanticUI
  of::Any = nothing                       # the window's Editor
  dir::String = ""
  level::Int = 1                          # 1 under a ›, 2 beside a folder of that list, and so on
  arrow::Any = nothing                    # the › that it drops from, at level 1
  all::Vector{String} = String[]          # what's in the folder, its folders first
  folders::Set{String} = Set{String}()    # which of those are folders
  names::Vector{String} = String[]        # the rows: those that have the words typed in the field, no more than TT_MOST
  more::Int = 0                           # how many more have the words typed
  unread::Bool = false                    # Ladder can't read the folder
  typed::String = ""                      # the words in the field when the rows were chosen
  pick::Int = 0                           # the row that Return takes, or 0
  shown::Int = 0                          # the row that the list last scrolled to
  rest::Tuple{Int,Float64} = (0, 0.0)     # the row that the mouse rests on, and since when
  open::String = ""                       # the folder whose list shows beside this one
  side::Symbol = :below                   # where the list is beside the ›, for its caret
  wide::Any = TT_NARROW
  parts::Dict{Any,Any} = Dict{Any,Any}()  # its field, its scroll and its rows
end

"A row of a list of a folder: one thing in the folder"
@def mutable struct FolderRow <: SemanticUI
  of::Any = nothing
  k::Int = 0
end

"The key of the popup of a list of a folder at `level`"
list_key(level) = level == 1 ? TT_LIST : Symbol(TT_LIST, "_", level)

"The lists of folders that show in the window `w`, from the one under the › on"
folder_lists(w) = sort!(FolderList[p.content for p in popups(w) if p.content isa FolderList], by=l -> l.level)

"""
Take away the lists of folders that are deeper than `level`, and with 0 every
one of them. The keyboard goes back to the page from the field of the list
under the ›.
"""
close_folder_lists!(e, w, level=0) = begin
  for l in folder_lists(w)
    l.level > level || continue
    close_popup!(w, list_key(l.level))
    l.level == 1 && left_list!(e, w, l)
  end
  foreach(l -> l.level == level && (l.open = ""), folder_lists(w))
  nothing
end

"Give the keyboard back to the page when the field of the list `l`, which has gone, has it"
left_list!(e, w, l) = (w.focus === get(l.parts, :field, nothing) && focus(e); nothing)

"Read what's in the folder of the list `l`, and make the list wide enough for its names"
read_folder!(l::FolderList) = begin
  found = title_listing(l.of, l.dir)
  l.unread = found === nothing
  names, kinds = something(found, (String[], Dict{String,Bool}()))
  l.all, l.folders = names, Set{String}(n for n in names if kinds[n])
  face = Face(SANS, "Semibold", 13px, colours.ink, false)
  l.wide = clamp(maximum((measure(face, n) for n in first(names, TT_MOST)), init=0px) + TT_ROOM, TT_NARROW, TT_BROAD)
  rows!(l, "")
end

"Make the rows of `l` the names that have every word of `typed`. Its first name that starts with them is picked."
rows!(l::FolderList, typed) = begin
  words = split(lowercase(typed))
  found = filter(n -> all(w -> occursin(w, lowercase(n)), words), l.all)
  l.typed, l.names, l.more = typed, first(found, TT_MOST), max(0, length(found) - TT_MOST)
  start = findfirst(n -> startswith(lowercase(n), lowercase(typed)), l.names)
  l.pick = isempty(l.names) ? 0 : isempty(typed) ? 1 : something(start, 1)
  l
end

"""
Show the list of what's in the folder before the › `a`, under it, with the
keyboard in its field. What's on the way to the file that shows is picked.
When the list shows already, the click on its › takes it away.
"""
open_folder_list!(e, w, a::TitleArrow) = begin
  was = [l for l in folder_lists(w) if l.level == 1]
  close_folder_lists!(e, w)
  !isempty(was) && only(was).arrow === a && return handled
  r = rect(a)
  r === nothing && return handled
  l = read_folder!(FolderList(of=e, dir=a.path, arrow=a))
  l.pick = something(findfirst(n -> inside_path(e.buf.path, joinpath(l.dir, n)), l.names), l.pick)
  field = l.parts[:field] = own!(l, TextInput(placeholder="Filter…", font_family=SANS, font_size=13px,
                                               look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text)))
  field.color = colours.ink
  # The caret at the top of the list points at the middle of the ›
  popup!(w, l, anchor=(r.left + r.width / 2 - TT_AIM, r.top, 0px, r.height), placement=:below, gap=8px, width=l.wide,
         key=TT_LIST, theme=component_theme(), onclose=() -> (close_folder_lists!(e, w); left_list!(e, w, l)))
  focus(field)
  redraw_in!(e, 0)   # the › stays shaded while its list shows
  handled
end

"""
Show what's in the folder of row `k` of the list `l` in a list beside the row,
with its first row in line with it: at the right of `l`, or at its left when
the window has no room at the right. With `keys`, as → opens it, its first
row is picked.
"""
open_beside!(l::FolderList, k; keys=false) = begin
  e, w = l.of, window_of(l)
  row = get(l.parts, (:row, k), nothing)
  (w === nothing || row === nothing || !(k in eachindex(l.names))) && return
  r, me = rect(row), rect(l)
  (r === nothing || me === nothing) && return
  close_folder_lists!(e, w, l.level)
  inner = read_folder!(FolderList(of=e, dir=joinpath(l.dir, l.names[k]), level=l.level + 1))
  keys || (inner.pick = 0)
  x = me.left + me.width + 2px
  x + inner.wide > window_size(e)[1] - 4px && (x = me.left - inner.wide - 2px)
  popup!(w, inner, anchor=(x, r.top - 7px, 0px, 0px), placement=:below, width=inner.wide, key=list_key(inner.level),
         theme=component_theme(), onclose=() -> (l.open = ""))
  l.open = inner.dir
  nothing
end

"""
After the mouse has rested on a row of `l` for a moment: a folder's list opens
beside it, or the list beside `l` goes when the row is a file's. A mouse that
only passes over rows on its way to the list beside changes nothing.
"""
rest_tick!(l::FolderList) = begin
  k, since = l.rest
  row = get(l.parts, (:row, k), nothing)
  (k in eachindex(l.names) && row !== nothing && ishovered(row)) || return
  want = l.names[k] in l.folders ? joinpath(l.dir, l.names[k]) : ""
  want == l.open && return
  wait = TT_WAIT - (time() - since)
  wait > 0 && return redraw_in!(l.of, wait + 0.01)
  w = window_of(l)
  isempty(want) ? (w === nothing || close_folder_lists!(l.of, w, l.level)) : open_beside!(l, k)
  nothing
end

describe(l::FolderList) = begin
  field = get(l.parts, :field, nothing)
  if field !== nothing
    # New words in the field choose the rows again, and the list beside goes
    typed = String(strip(field.text))
    typed == l.typed || (rows!(l, typed); w = window_of(l); w === nothing || close_folder_lists!(l.of, w, l.level))
  end
  rest_tick!(l)
  n, high = length(l.names), FLOAT_ROW
  body = if n == 0
    float_none(l.unread ? "Ladder can't read this folder" : isempty(l.all) ? "This folder is empty" : "Nothing has that name")
  else
    scroll = get!(() -> Scroll(width(grow=grow)), l.parts, :scroll)
    # Half a row at the bottom says that the list goes on
    scroll.height = height(n <= TT_ROWS ? n * high : TT_ROWS * high - high / 2)
    l.shown == l.pick || (l.shown = l.pick; l.pick > 0 && scroll_into_view!(scroll, high * (l.pick - 1), high * l.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [get!(() -> own!(l, FolderRow(of=l, k=k)), l.parts, (:row, k)) for k in 1:n]...))
  end
  more = l.more == 0 ? () : (float_none(l.level == 1 ? "$(l.more) more. Type a name to find them." : "$(l.more) more"),)
  float_list(field, Column(width(grow=grow), Alignment.Start, body, more...), name="Folder")
end

placed!(l::FolderList, side) = (l.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, l::FolderList) = l.arrow === nothing ? nothing : caret(ctx, ui, l.side, rect(l.arrow))

describe(r::FolderRow) = begin
  l = r.of
  r.k in eachindex(l.names) || return Box(height(0px))
  c = found_colours()
  name = l.names[r.k]
  path = joinpath(l.dir, name)
  folder = name in l.folders
  Row(width(grow=grow), height(FLOAT_ROW), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center, name="Thing",
      background(l.pick == r.k || l.open == path ? c.pick : c.frame),
    Icon(folder ? "folder" : file_icon(path), size=13px, color=c.dim),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true,
      label(elide(name, 13px, l.wide - TT_ROOM), 13px, color=c.ink, weight=inside_path(l.of.buf.path, path) ? "Semibold" : "")),
    (folder ? (Icon("chevron-right", size=8px, color=c.dim),) : ())...)
end

cursor(::FolderRow) = :hand

# The mouse picks the row that it's over, as the arrow keys do
onmouse(r::FolderRow, ::MouseMove) = begin
  l = r.of
  l.pick = l.shown = r.k   # it's in sight already, so the list doesn't scroll to it
  l.rest[1] == r.k || (l.rest = (r.k, time()); redraw_in!(l.of, TT_WAIT + 0.01))
  handled
end

onkey(r::FolderRow, ev::KeyPress{Keys.mouse_left}) = begin
  l = r.of
  r.k in eachindex(l.names) && title_go!(l.of, ev.window, joinpath(l.dir, l.names[r.k]))
  handled
end

# The list that opened last sees a key before the field does
onkey(l::FolderList, ev::KeyPress{Keys.down}) = unmodified(ev) ? (isempty(l.names) || (l.pick = min(l.pick + 1, length(l.names))); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.up}) = unmodified(ev) ? (isempty(l.names) || (l.pick = max(l.pick - 1, 1)); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.enter}) =
  unmodified(ev) ? (l.pick in eachindex(l.names) && title_go!(l.of, ev.window, joinpath(l.dir, l.names[l.pick])); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.right}) =
  unmodified(ev) && l.pick in eachindex(l.names) && l.names[l.pick] in l.folders ? (open_beside!(l, l.pick; keys=true); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.left}) = unmodified(ev) && l.level > 1 ? (close_folder_lists!(l.of, ev.window, l.level - 1); handled) : nothing
onkey(l::FolderList, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (close_folder_lists!(l.of, ev.window); handled) : nothing

# --- a search of a page's parts, from a › of the path in the top bar ---
#
# In the path in the top bar, a › follows the file's name and each heading. A
# click on it shows a search of what's in the file, or under the heading. It
# floats under the ›, as the list of a folder does under a folder's ›, and the
# path stays while it shows.
#
#   - With nothing typed and no kinds chosen, it lists the headings and the
#     components there, as the sidebar does. A click on one goes to it.
#   - The kinds are those of a `find` block (find.jl): to-do items, headings,
#     table rows, code blocks, sheets, sketches and the rest. The Kinds button
#     lists them, with a tick beside each kind that's chosen. A click on a row
#     ticks it or takes its tick away, and the list stays for more. Each kind
#     that's chosen shows in the field as a chip. A click on a chip takes it away.
#   - Kinds and words go together, and either can be left out. Kinds with no
#     words list every thing of those kinds. Words with no kinds find any line,
#     and any block that has them in its own lines.
#   - The › that was clicked says where the search looks: the whole file, or
#     under its heading. The search has no button to choose another place.
#   - The up and down arrows pick a row, and Return or a click shows it. Tab
#     opens the list of kinds. Backspace in an empty field takes the last kind
#     away. Esc, or a click somewhere else, closes the search.

const TS_KEY = :title_search          # the key of the search's popup
const TS_MENU = :title_search_menu    # and of the list of kinds that its Kinds button opens
const TS_WIDE = 480px                 # how wide the search is, at most
const TS_MOST = 200                   # the most rows that its list shows
const TS_ROWS = 12                    # the rows that show before the list scrolls

"A search of what's in a page, or under one of its headings, under a › of the path in the top bar"
@def mutable struct TitleSearch <: SemanticUI
  of::Any = nothing                     # the window's Editor
  arrow::Any = nothing                  # the › that it hangs from
  page::String = ""                     # the file that the path ends with
  under::Int = 0                        # the line of the heading that it looks under, or 0 for the whole file
  wants::Vector{Symbol} = Symbol[]      # the kinds of thing that it finds, in the order they were chosen
  wide::Any = TS_WIDE                   # how wide it is
  key::Any = nothing                    # what the rows were worked out for
  rows::Vector{Any} = Any[]             # what it shows: a thing that was found, or a heading or component that's there
  things::Int = 0                       # how many things it found
  total::Int = 0                        # how many rows its list would have with no limit
  pick::Int = 0                         # the row that Return shows
  shown::Int = 0                        # the row that the list last scrolled to
  side::Symbol = :below                 # the side of the › that it's on, for its caret
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its field, its chips, its Kinds button, its scroll and its rows
end

"What a window keeps of the path in its top bar, between frames"
@def mutable struct TitlePathState
  lead::px = 0px                                 # how far the file's name is from the left of the title in the bar, for the path
  outline::Union{Nothing,Tuple} = nothing        # the text that shows, its version and its outline, kept until the text changes: see `focus_parts`
  hover::Union{Nothing,Float64} = nothing        # when the mouse came over the file's name, or nothing while the path has no reason to show
  trail::Union{Nothing,TitleTrail} = nothing     # the path, or nothing until it first shows
  search::Union{Nothing,TitleSearch} = nothing   # the search that last opened under a › of the path, or nothing
end

"A kind that the search finds, in its field. A click takes it away."
@def mutable struct SearchChip <: SemanticUI
  of::Any = nothing
  kind::Symbol = :todo
end

"The button at the right of the search's field, which chooses the kinds of thing to find"
@def mutable struct SearchButton <: SemanticUI
  of::Any = nothing
end

"A row of the search's list"
@def mutable struct SearchFound <: SemanticUI
  of::Any = nothing
  k::Int = 0
end

"The list of kinds under the search's Kinds button, with a field at its top that filters it"
@def mutable struct SearchMenu <: SemanticUI
  of::Any = nothing                       # the search
  button::Any = nothing                   # the button that it's under
  rows::Vector{Any} = Any[]               # the rows that have the words in its field
  typed::String = ""                      # the words in its field when the rows were chosen
  pick::Int = 1                           # the row that Return takes
  shown::Int = 0                          # the row that the list last scrolled to
  side::Symbol = :bottom                  # the side of the button that it's on
  parts::Dict{Any,Any} = Dict{Any,Any}()  # its field, its scroll and its rows
end

"A row of that list: a kind of thing"
@def mutable struct SearchOption <: SemanticUI
  of::Any = nothing
  k::Int = 0
end

"The field of the search, where the words go"
search_field(s::TitleSearch) = s.parts[:field]

"A text field of the search or of the list of kinds under its button"
search_box(placeholder) = begin
  f = TextInput(placeholder=placeholder, font_family=SANS, font_size=13px,
                look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
  f.color, f.placeholder_color = colours.ink, colours.faint
  f
end

"The icon of a kind of thing that the search finds. A kind of block has the icon that the sidebar shows beside such a block."
search_icon(k::Symbol) =
  k == :todo ? "square" : k == :done ? "check-square" : k == :heading ? "type-h1" :
  k == :paragraph ? "text-paragraph" : k == :bullet ? "list-ul" : k == :ordered ? "list-ol" : k == :blockquote ? "quote" :
  k == :table ? "table" : k == :link ? "link-45deg" : k == :picture ? "image" : Searches.isblock(k) ? block_icon(k) : "text-left"

"What the search calls things of the kind `k` in its list of kinds and its chips: To-do items"
search_kinds_name(k::Symbol) = Searches.title(k)

"What the search calls one thing of the kind `k`, at the right of its row: To-do item"
search_kind_name(k::Symbol) = uppercasefirst(Searches.WHATS[k].one)

"The heading that the search looks under, as the sidebar has it, or nothing"
search_heading(s::TitleSearch) = s.under == 0 ? nothing : (i = findfirst(x -> x.line == s.under, outline(s.of, s.page)); i === nothing ? nothing : outline(s.of, s.page)[i])

"The name of the page at `path` in the search: its file's name, or the last name of the address of a page from a web server"
search_file_name(path) = (at = web_address(path); isempty(at) ? basename(path) : Remote.trail(at)[end][1])

"The name of the place where the search looks: its heading, or its file"
search_place(s::TitleSearch) =
  s.under > 0 ? (h = search_heading(s); h === nothing ? search_file_name(s.page) : h.title) : search_file_name(s.page)

"The lines of the page that are under the heading on line `under`: up to the next heading as big as it or bigger. With 0, every line."
under_lines(ks, under) = begin
  (0 < under <= length(ks) && ks[under].kind == Kind.heading) || return 1:length(ks)
  stop = findnext(l -> l.kind == Kind.heading && l.level <= ks[under].level, ks, under + 1)
  under:(stop === nothing ? length(ks) : stop - 1)
end

"""
Show a search of what's in the file, or under the heading, that the › `a` of
the path follows, under the ›, with the keyboard in its field. A second click
on the › takes it away.
"""
open_title_search!(e, w, a::PartArrow) = begin
  was = [p.content for p in popups(w) if p.key == TS_KEY]
  close_title_search!(e, w)
  !isempty(was) && only(was).arrow === a && return handled
  close_folder_lists!(e, w)
  v = a.parent
  r = rect(a)
  r === nothing && return handled
  under = a.k in eachindex(v.parts) ? v.parts[a.k].line : 0
  s = TitleSearch(of=e, arrow=a, page=e.buf.path, under=under)
  s.parts[:field] = own!(s, search_box(""))
  s.wide = min(TS_WIDE, window_size(e)[1] - 16px)
  state_of(e, TitlePathState).search = s
  # The caret at the top of the search points at the middle of the ›
  popup!(w, s, anchor=(r.left + r.width / 2 - TT_AIM, r.top, 0px, r.height), placement=:below, gap=8px, width=s.wide,
         key=TS_KEY, theme=component_theme(), onclose=() -> (close_popup!(w, TS_MENU); left_search!(e, w)))
  focus(search_field(s))
  redraw_in!(e, 0)   # the › stays shaded while its search shows
  handled
end

placed!(s::TitleSearch, side) = (s.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, s::TitleSearch) = caret(ctx, ui, s.side, rect(s.arrow))

"Take the search away, with the list under one of its buttons. The keyboard goes back to the page."
close_title_search!(e, w) = (close_popup!(w, TS_MENU); close_popup!(w, TS_KEY); left_search!(e, w))

"Give the keyboard back to the page when a field of the search, which has gone, has it"
left_search!(e, w) = begin
  s = state_of(e, TitlePathState).search
  f = w.focus
  s !== nothing && (f === search_field(s) || (f isa SemanticUI && f.parent isa SearchMenu)) && focus(e)
  nothing
end

"""
⌘F, and Find… in the page's menu. On a page of Markdown, the path shows over
the top bar with the search under the › after the file's name, which looks
through the whole page. What's selected goes into its field, if that's part of
one line. While the search shows, ⌘F selects the words in its field. A file
with no › to search from, like a file of code, gets the bar that finds text in
the page instead: see `open_find!`.
"""
find!(e, w=window_of(e)) = begin
  w === nothing && return open_find!(e)
  s = state_of(e, TitlePathState).search
  if s !== nothing && any(p -> p.key == TS_KEY, popups(w))
    f = search_field(s)
    f.anchor, f.cursor = 0, length(f.text)
    focus(f)
    return nothing
  end
  (searchable(e) && trail_can_show(e) && slideshow(e) === nothing && !as_app(e) && !screening(e)) || return open_find!(e)
  b = e.buf
  lo, hi = selection(b)
  state_of(e, SearchAsked).words = selecting(b) && lo[1] == hi[1] ? rest(head(b.lines[lo[1]], hi[2]), lo[2]) : ""
  redraw_in!(e, 0)
  nothing
end

"The search that ⌘F asked for and that hasn't opened yet, which the window keeps until the path in the top bar is in place: see `ask_search!`"
@def mutable struct SearchAsked
  words::Union{Nothing,String} = nothing   # the words that the search starts with, "" for none, or nothing when no search is asked for
end

"True when ⌘F asked for the search of the window of `e`, and it hasn't opened yet"
search_asked(e) = state_of(e, SearchAsked).words !== nothing

"Open the search that ⌘F asked for, under the › after the file's name of the path `v`, once the › has a place"
ask_search!(e, w, v::TitleTrail) = begin
  a = get(v.drops, 0, nothing)
  (a !== nothing && rect(a) !== nothing) || return redraw_in!(e, 0)
  asked = state_of(e, SearchAsked)
  words, asked.words = asked.words::String, nothing
  open_title_search!(e, w, a)
  s = state_of(e, TitlePathState).search
  if s !== nothing && s.arrow === a
    f = search_field(s)
    f.text = words
    f.anchor, f.cursor = 0, length(words)
  end
  nothing
end

"""
What happens to the search in each frame, before the window is laid out: the
list of kinds goes when a click somewhere else took the keyboard from the
list's field.
"""
search_tick!(e, w) = begin
  for p in popups(w)
    p.key == TS_MENU && w.focus !== p.content.parts[:field] && close_popup!(w, TS_MENU)
  end
  nothing
end

"""
Work out what the search shows, when its words or its kinds have changed, or
when a page has changed in Ladder. It looks through the page, or the part of
it under its heading.
"""
search_rows!(s::TitleSearch) = begin
  e = s.of
  words = String.(split(lowercase(search_field(s).text)))
  # ⌘Z gives a page the version that it had before, so the version of each open page is looked at, not only the newest one
  key = (s.under, copy(s.wants), words, hash([b.version for b in values(e.buffers)]))
  key == s.key && return s
  s.key = key
  rows, things, total = Any[], 0, 0
  at = isfile(s.page) ? mtime(s.page) : 0.0
  lines, ks, _ = page_text(e, s.page, at)
  span = under_lines(ks, s.under)
  if isempty(words) && isempty(s.wants)
    # Nothing asked: the headings and the components there, each in the heading over it, as the sidebar has them
    over = Int[]
    for x in outline(e, s.page)
      x.line in span && x.line != s.under || continue
      while !isempty(over) && over[end] >= x.level
        pop!(over)
      end
      push!(rows, (kind=:entry, path=s.page, x=x, depth=length(over)))
      x.level < 7 && push!(over, x.level)
    end
    total = length(rows)
  else
    for (m, as) in Searches.search(s.wants, words, s.page, lines, ks)
      m.line in span || continue
      things += 1
      length(rows) < TS_MOST && push!(rows, (kind=:thing, path=s.page, m=m, as=as))
    end
    total = things
  end
  s.rows, s.things, s.total = rows, things, total
  s.pick = isempty(rows) ? 0 : 1
  s.shown = 0
  s
end

"True when the search shows what's there, because nothing is asked"
listing_parts(s::TitleSearch) = !isempty(s.rows) && s.rows[1].kind == :entry

"What the foot of the search's list says: how many things it found, and where"
search_summary(s::TitleSearch) = begin
  place = search_place(s)
  where = s.under > 0 ? "under $place" : "in $place"
  s.things == 0 && return "Nothing found $where."
  more = s.total > length(s.rows) ? " The list shows the first $(length(s.rows)) rows." : ""
  "$(s.things == 1 ? "1 thing" : "$(s.things) things") $where." * more
end

"Show what row `k` of the search has, and close the search: a heading or a component goes to it, and a thing shows in its page"
search_go!(s::TitleSearch, w, k) = begin
  k in eachindex(s.rows) || return handled
  row = s.rows[k]
  e = s.of
  close_title_search!(e, w)
  # A view or a block that fills the window goes back in the page, so the page shows what was chosen
  row.path == e.buf.path && unfill_page!(e)
  if row.kind == :entry
    row.path == e.buf.path || open!(e, row.path)
    focus(e)
    go_entry!(e, row.x.line, row.x.caret)
  else
    visit!(e, row.path, row.m)
  end
  handled
end

describe(s::TitleSearch) = begin
  field = search_field(s)
  place = search_place(s)
  field.placeholder = s.under > 0 ? "Search under " * place : "Search " * place
  search_rows!(s)
  c = found_colours()
  chips = [get!(() -> own!(s, SearchChip(of=s, kind=k)), s.parts, (:chip, k)) for k in s.wants]
  kinds = get!(() -> own!(s, SearchButton(of=s)), s.parts, :kinds)
  top = Row(width(grow=grow), height(grow=grow), child_gap=5px, Alignment.Center,
    Icon("search", size=12px, color=c.dim), chips...,
    Box(width(grow=grow), height(grow=grow), field),
    kinds)
  float_list(top, Column(width(grow=grow), Alignment.Start, search_list(s)...), name="Search")
end

"The rows under the search's field, and the line under them that says what was found"
search_list(s::TitleSearch) = begin
  c = found_colours()
  n, high = length(s.rows), FLOAT_ROW
  if n == 0
    asked = !isempty(split(search_field(s).text)) || !isempty(s.wants)
    return (float_none(asked ? search_summary(s) : "There are no headings or components here"),)
  end
  scroll = get!(() -> Scroll(width(grow=grow)), s.parts, :scroll)
  # Half a row at the bottom says that the list goes on
  scroll.height = height(n <= TS_ROWS ? n * high : TS_ROWS * high - high / 2)
  s.shown == s.pick || (s.shown = s.pick; s.pick > 0 && scroll_into_view!(scroll, high * (s.pick - 1), high * s.pick))
  reuse!(scroll, Column(width(grow=grow), Alignment.Start, [get!(() -> own!(s, SearchFound(of=s, k=k)), s.parts, (:row, k)) for k in 1:n]...))
  listing_parts(s) && return (scroll,)
  (scroll, Box(width(grow=grow), height(1px), background(c.rule)), float_none(search_summary(s)))
end

describe(r::SearchFound) = begin
  s = r.of
  r.k in eachindex(s.rows) || return Box(height(0px))
  row = s.rows[r.k]
  c = found_colours()
  back = background(s.pick == r.k ? c.pick : c.frame)
  if row.kind == :entry
    # A heading or a component, under the heading over it, as in the sidebar
    x = row.x
    return Row(width(grow=grow), height(FLOAT_ROW), padding(0px, 8px, 0px, 8px + 14px * row.depth), radius(6px), child_gap=8px,
               Alignment.Center, name="Part", back,
      Icon(x.icon, size=12px, color=c.dim),
      Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true,
        label(elide(x.title, 13px, s.wide - 60px - 14px * row.depth), 13px, color=c.ink)))
  end
  m, as = row.m, row.as
  kind = search_kind_name(as)
  room = s.wide - 120px - measure(Face(SANS, "", 12px, c.ink, false), kind)
  Row(width(grow=grow), height(FLOAT_ROW), padding(0px, 8px, 0px, 8px), radius(6px), child_gap=8px,
      Alignment.Center, name="Thing", back,
    Icon(search_icon(as), size=12px, color=c.dim),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true,
      label(elide(m.text, 13px, room), 13px, color=m.kind == :done ? c.dim : c.ink, weight=as == :heading ? "Semibold" : "")),
    Box(label(kind, 12px, color=c.dim)))
end

describe(c::SearchChip) = begin
  f = found_colours()
  Row(height(20px), padding(0px, 4px, 0px, 6px), radius(5px), child_gap=4px, Alignment.Center, name="Kind",
      background(ishovered(c) ? f.line : f.pick),
    Icon(search_icon(c.kind), size=11px, color=f.dim),
    label(search_kinds_name(c.kind), 12px, color=f.ink),
    Icon("x", size=12px, color=f.dim))
end

describe(b::SearchButton) = begin
  s = b.of
  c = found_colours()
  w = window_of(b)
  dropped = w !== nothing && any(p -> p.content isa SearchMenu && p.content.button === b, popups(w))
  Row(height(20px), padding(6px, 0px), radius(5px), child_gap=4px, Alignment.Center, name="Kinds",
      background(ishovered(b) || dropped ? c.pick : clear),
    Icon("funnel", size=11px, color=c.dim),
    label(isempty(s.wants) ? "Any kind" : "Kinds", 12px, color=c.dim),
    Icon("chevron-down", size=8px, color=c.dim))
end

cursor(::Union{SearchFound,SearchChip,SearchButton,SearchOption}) = :hand

# The mouse picks the row that it's over, as the arrow keys do. It's in sight already, so the list doesn't scroll to it.
onmouse(r::SearchFound, ::MouseMove) = (s = r.of; s.pick = s.shown = r.k; handled)
onkey(r::SearchFound, ev::KeyPress{Keys.mouse_left}) = search_go!(r.of, ev.window, r.k)
onkey(c::SearchChip, ev::KeyPress{Keys.mouse_left}) = (s = c.of; filter!(!=(c.kind), s.wants); focus(search_field(s)); handled)
onkey(b::SearchButton, ev::KeyPress{Keys.mouse_left}) = open_search_menu!(b.of, ev.window)

# The search sees a key before its field does
onkey(s::TitleSearch, ev::KeyPress{Keys.down}) = unmodified(ev) ? (isempty(s.rows) || (s.pick = min(s.pick + 1, length(s.rows))); handled) : nothing
onkey(s::TitleSearch, ev::KeyPress{Keys.up}) = unmodified(ev) ? (isempty(s.rows) || (s.pick = max(s.pick - 1, 1)); handled) : nothing
onkey(s::TitleSearch, ev::KeyPress{Keys.enter}) = unmodified(ev) ? search_go!(s, ev.window, s.pick) : nothing
onkey(s::TitleSearch, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (close_title_search!(s.of, ev.window); handled) : nothing
onkey(s::TitleSearch, ev::KeyPress{Keys.tab}) = unmodified(ev) ? open_search_menu!(s, ev.window) : nothing
# Backspace in an empty field takes the last kind away
onkey(s::TitleSearch, ev::KeyPress{Keys.backspace}) =
  unmodified(ev) && isempty(search_field(s).text) && !isempty(s.wants) ? (pop!(s.wants); handled) : nothing
# The key that finds, like ⌘F, selects the words in the field. The page never sees it, since the search has no parent there.
onkey(s::TitleSearch, ev::KeyPress{K}) where K =
  get(keys_now(s.of).commands, (Stroke(ev.window.keys & HELD, K),), nothing) == :find ? (find!(s.of, ev.window); handled) : nothing

# --- the list of kinds under the search's Kinds button ---

"""
The rows of the list of kinds: any kind, then each kind of a `find` block. A
row is found by any name that a `find` block knows its kind by.
"""
kind_options() =
  Any[(key=nothing, name="Any kind", icon="asterisk", words=["any kind", "all", "every"]);
      [(key=k, name=search_kinds_name(k), icon=search_icon(k), words=[Searches.WHATS[k].names..., Searches.WHATS[k].langs...])
       for k in keys(Searches.WHATS)]]

"Make the rows of the list `m` those that have every word of `typed`. The first whose name starts with them is picked."
menu_rows!(m::SearchMenu, typed) = begin
  m.typed = typed
  m.rows = filter(r -> choice_matches(r, typed), kind_options())
  m.pick = isempty(m.rows) ? 0 : something(findfirst(r -> startswith(lowercase(r.name), lowercase(typed)), m.rows), 1)
  m
end

"""
Show the list of kinds under the search's Kinds button. The keyboard goes to
the field at its top. A second click on the button takes the list away.
"""
open_search_menu!(s::TitleSearch, w) = begin
  was = any(p -> p.key == TS_MENU, popups(w))
  close_search_menu!(s, w)
  was && return handled
  b = s.parts[:kinds]
  r = rect(b)
  r === nothing && return handled
  m = SearchMenu(of=s, button=b)
  m.parts[:field] = own!(m, search_box("Filter…"))
  menu_rows!(m, "")
  # A button in a popup is anchored by where it is: a popup anchored at a node follows it in the window's own parts, and this one isn't there
  popup!(w, m, anchor=(r.left, r.top, r.width, r.height), placement=:bottom, gap=9px, width=250px,
         key=TS_MENU, theme=component_theme(), onclose=() -> left_search!(s.of, w))
  focus(m.parts[:field])
  handled
end

"Take the list of kinds away. The keyboard goes back to the search's field."
close_search_menu!(s::TitleSearch, w) = begin
  f = w.focus
  close_popup!(w, TS_MENU)
  f isa SemanticUI && f.parent isa SearchMenu && focus(search_field(s))
  handled
end

"""
Take row `k` of the list `m`. A kind is chosen, or its choice is taken back,
and the list stays, so that more can be chosen. Any kind takes every choice
back.
"""
take_option!(m::SearchMenu, w, k) = begin
  k in eachindex(m.rows) || return handled
  s, key = m.of, m.rows[k].key
  key === nothing ? empty!(s.wants) : key in s.wants ? filter!(!=(key), s.wants) : push!(s.wants, key)
  handled
end

describe(m::SearchMenu) = begin
  f = m.parts[:field]
  typed = String(strip(f.text))
  typed == m.typed || menu_rows!(m, typed)
  n, high = length(m.rows), FLOAT_ROW
  body = if n == 0
    float_none("Nothing has that name")
  else
    scroll = get!(() -> Scroll(width(grow=grow)), m.parts, :scroll)
    # Half a row at the bottom says that the list goes on
    most = MOST_CHOICES + 3
    scroll.height = height(n <= most ? n * high : most * high - high / 2)
    m.shown == m.pick || (m.shown = m.pick; m.pick > 0 && scroll_into_view!(scroll, high * (m.pick - 1), high * m.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [get!(() -> own!(m, SearchOption(of=m, k=k)), m.parts, (:row, k)) for k in 1:n]...))
  end
  float_list(f, body, name="Kinds")
end

placed!(m::SearchMenu, side) = (m.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, m::SearchMenu) = caret(ctx, ui, m.side, rect(m.button))

describe(o::SearchOption) = begin
  m = o.of
  o.k in eachindex(m.rows) || return Box(height(0px))
  r = m.rows[o.k]
  s = m.of
  c = found_colours()
  # A kind that's chosen has a tick
  on = r.key === nothing ? isempty(s.wants) : r.key in s.wants
  Row(width(grow=grow), height(FLOAT_ROW), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center, name="Option",
      background(m.pick == o.k ? c.pick : c.frame),
    Icon(r.icon, size=13px, color=c.dim),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true, label(r.name, 13px, color=c.ink, weight=on ? "Semibold" : "")),
    (on ? (Icon("check2", size=13px, color=c.ink),) : ())...)
end

onmouse(o::SearchOption, ::MouseMove) = (m = o.of; m.pick = m.shown = o.k; handled)
onkey(o::SearchOption, ev::KeyPress{Keys.mouse_left}) = take_option!(o.of, ev.window, o.k)

# The list sees a key before its field does. Return takes a row, and Esc or Tab goes back to the search's field.
onkey(m::SearchMenu, ev::KeyPress{Keys.down}) = unmodified(ev) ? (isempty(m.rows) || (m.pick = min(m.pick + 1, length(m.rows))); handled) : nothing
onkey(m::SearchMenu, ev::KeyPress{Keys.up}) = unmodified(ev) ? (isempty(m.rows) || (m.pick = max(m.pick - 1, 1)); handled) : nothing
onkey(m::SearchMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? take_option!(m, ev.window, m.pick) : nothing
onkey(m::SearchMenu, ev::KeyPress{Keys.escape}) = unmodified(ev) ? close_search_menu!(m.of, ev.window) : nothing
onkey(m::SearchMenu, ev::KeyPress{Keys.tab}) = unmodified(ev) ? close_search_menu!(m.of, ev.window) : nothing
