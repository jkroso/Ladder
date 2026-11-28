# The view of a `find` block: a list of what was found in the pages of a folder, and the list that a button at its top opens
#
# A code block in the language `find` lists the lines that match in every page
# of a folder: every to-do item that isn't ticked, say, or each line that has
# some words. find.jl says how the block is written. The list has the name of
# each page over that page's lines. A click on a line opens its page at that
# line. A click on the box of a to-do item ticks it in its own page. If that
# page isn't open, or is open with nothing to save, Ladder writes the tick to
# the page's file at once. An item that you tick stays in the list, ticked,
# until another page shows.
#
# The top of the list changes what it asks for, so the block's lines needn't
# be seen: a field for the words that a line must have, a button that opens a
# list of the kinds of thing to list, and one that opens a list of the folders
# when the page has folders beside it. Each of the two lists floats under its
# button, as the takeoff's list of units does, with a field at its top that
# searches it. The kinds are those of find.jl: the kinds of line, and each
# kind of block, which is listed by the heading that it's under. Each change
# goes into the block's lines. Under them, a line says
# what the list is of and where it looked. It counts only the lines that
# match, not the items that were ticked here.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor rect popup! close_popup! placed!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" problem
@use "./html" escape
@use "./markdown" Line classify words
@use "./repeats" => Repeats
@use "./find" => Searches
@use "./folders" => Folders
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./takeoff_view" exports...
@use "./schedule_view" exports...

export FIND, FIND_MOST, FIND_PAGES, FIND_EVERY, FIND_BUDGET, FIND_BAR, FIND_MENU, SearchPage,
       SearchRow, SearchTick, search_input, search_folders, look_in!, list_kind!, choice_words,
       choice_rows, open_choices!, pages_under, PAGE_TEXTS, search_folder, page_name, tick_found!,
       forget_ticked!, search_words, find_html, choice_matches

const FIND = Searches.FIND
const FIND_MOST = 200     # the most lines that a list shows
const FIND_PAGES = 3000   # the most pages that a list reads
const FIND_EVERY = 3      # seconds between two looks at the folder, while the window is drawn
const FIND_BUDGET = 0.3   # seconds that one look at the folder can take
const FIND_BAR = 440px     # the room that the top of a list needs to show its field and its buttons in one row
const FIND_MENU = :find_choices   # the key of the list that a button at the top opens
push!(BLOCK_ICONS, "search", "file-earmark-text", "folder", "code-slash")

"The name of a page, over the lines of that page in the list"
@def mutable struct SearchPage <: SemanticUI
  of::Any = nothing
  path::String = ""
end
"A line of the list"
@def mutable struct SearchRow <: SemanticUI
  of::Any = nothing
  i::Int = 0
  box::Any = nothing   # its SearchTick
end
"The box of a to-do item in the list. A click ticks the item in its own page."
@def mutable struct SearchTick <: SemanticUI
  of::Any = nothing    # the row
end

"The text field at the top of a list. It holds the words that a line must have."
search_input(v::SearchView) = block_part!(v, :input) do
  TextInput(placeholder="Words to find", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

reread!(v::SearchView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Searches.query(lines)
  v.shown = nothing
  empty!(v.pages)
  # The field shows the words that the block has, as it does after ⌘Z takes some of them back.
  # A space that was just typed after a word stays in the field.
  i = search_input(v)
  split(i.text) == v.data.with || (i.text = join(v.data.with, " "); i.anchor = i.cursor = length(i.text))
  v
end

"Write what the list asks for into the lines of its block, and work the list out again"
ask!(v::SearchView; typing=false) = begin
  v.shown = nothing
  empty!(v.pages)
  write_block!(v, FIND, Searches.written(v.data); typing)
end

"""
What happens to a list in each frame, before the page is laid out: the words
that were typed in its field are written into its block. The words make the
list shorter. They don't change the kind of line that it lists.
"""
block_tick!(v::SearchView) = begin
  choosing_tick!(v)
  words = String.(split(search_input(v).text))
  q = v.data
  words == q.with && return v
  q.what === nothing && (q.what = Searches.kind(q))
  q.with = words
  ask!(v, typing=true)
end

"The folders that the list can look in: the folders beside the page, and the one that the block names now"
search_folders(v::SearchView) = begin
  dir = docdir(editor(v))
  ignored = Folders.ignored()
  found = isdir(dir) ? sort!([f for f in readdir(dir) if !left_out(joinpath(dir, f), ignored) && f != "node_modules" && isdir(joinpath(dir, f))], by=lowercase) : String[]
  folder = v.data.folder
  isempty(folder) || folder in found || pushfirst!(found, folder)
  found
end

"Look in the folder `name` beside the page, or in the page's own folder when `name` is empty"
look_in!(v::SearchView, name) = (v.data.folder = String(name); ask!(v))

"List things of the kind `kind`, one of the kinds of find.jl, like :todo or :takeoff"
list_kind!(v::SearchView, kind) = (v.data.what = kind; ask!(v))

"What the button `c` says: the kind of thing that its list is of now, or the folder that the list looks in"
choice_words(c::SearchChoice) = begin
  q = c.of.data
  c.what == :folder ? (isempty(q.folder) ? "This folder" : q.folder) : Searches.title(Searches.kind(q))
end

describe(c::SearchChoice) =
  Row(height(26px), padding(9px, 0px), child_gap=6px, radius(6px), Alignment.Center, name="Menu",
      border(1px, :solid, c.of.asking == c.what ? colours.accent : colours.line), background(ishovered(c) ? colours.hover : colours.bg),
    (c.what == :folder ? (Icon("folder", size=13px, color=colours.dim),) : ())...,
    Box(label(choice_words(c), 12px)), Icon("chevron-down", size=9px, color=colours.dim))

cursor(::SearchChoice) = :hand
onkey(c::SearchChoice, ev::KeyPress{Keys.mouse_left}) = open_choices!(c, ev.window)

# --- the list that a button at the top opens -----------------------------------------------
#
# A click on a button shows its list under it: every kind of thing that a
# `find` block can list, or the page's own folder and the folders beside it.
# The keyboard goes to the field at the top of the list, and the list keeps
# the rows that have every word typed there. A kind is found by any of the
# names that a block can give it, so "tasks" finds To-do items. The up and
# down arrows pick a row, and so does the mouse. Return or a click takes it.
# Esc, or a click somewhere else, closes the list and changes nothing.

"The field at the top of the list that a button opens"
choice_input(v::SearchView) = block_part!(v, :filter) do
  TextInput(placeholder="Filter…", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"""
Every row of the list that the button for `what` opens. A row has its `key`,
which is the kind or the folder that goes into the block, the `name` that it
shows, and the `words` that find it.
"""
choice_rows(v::SearchView, what::Symbol) = begin
  what == :kind && return Any[(key=k, name=Searches.title(k), words=[Searches.WHATS[k].names..., Searches.WHATS[k].langs...]) for k in keys(Searches.WHATS)]
  Any[(key="", name="This folder", words=["this folder"]); [(key=f, name=f, words=[f]) for f in search_folders(v)]]
end

"True when the row `r` has every one of the words in `typed`"
choice_matches(r, typed::AbstractString) = all(w -> any(h -> occursin(w, lowercase(h)), r.words), split(lowercase(typed)))

"True when the row `r` is what the list of `v` asks for now"
chosen(v::SearchView, r) = r.key isa Symbol ? r.key == Searches.kind(v.data) : r.key == v.data.folder

"Show the list of the button `c` under it, with the keyboard in its field"
open_choices!(c::SearchChoice, window) = begin
  v = c.of
  stop_choosing!(v)
  input = choice_input(v)
  input.color = colours.ink
  input.text = ""
  input.anchor = input.cursor = 0
  v.back = window.focus === search_input(v)
  v.asking, v.typed = c.what, ""
  v.rows = choice_rows(v, c.what)
  v.pick = something(findfirst(r -> chosen(v, r), v.rows), 1)
  focus(input)
  menu = ChoiceMenu(of=v, button=c)
  v.parts[:menu] = menu
  popup!(window, menu, anchor=c, placement=:bottom, gap=9px, width=230px, key=FIND_MENU,
         onclose=() -> stop_choosing!(v), theme=component_theme(editor(v).zoom))
  handled
end

"Take the list of a button away. The keyboard goes back to the field that had it, or to the page."
stop_choosing!(v::SearchView) = begin
  v.asking === nothing && return handled
  v.asking = nothing
  v.rows = Any[]
  w = window_of(v)
  w === nothing && return handled
  close_popup!(w, FIND_MENU)
  w.focus === choice_input(v) && focus(v.back ? search_input(v) : editor(v))
  handled
end

"Take row `k` of the list that shows: the list of `v` is of that kind, or it looks in that folder"
choose!(v::SearchView, k::Int) = begin
  (v.asking !== nothing && k in eachindex(v.rows)) || return stop_choosing!(v)
  what, key = v.asking, v.rows[k].key
  stop_choosing!(v)
  what == :kind ? list_kind!(v, key) : look_in!(v, key)
  handled
end

"""
What happens in each frame to the list that a button opened: it closes when a
click somewhere else took the keyboard from its field, and it keeps the rows
that have the words in the field. New words pick the row whose name starts
with them, or the first row.
"""
choosing_tick!(v::SearchView) = begin
  v.asking === nothing && return
  w = window_of(v)
  (w === nothing || w.focus !== choice_input(v)) && return stop_choosing!(v)
  typed = String(strip(choice_input(v).text))
  typed == v.typed && return
  v.typed = typed
  v.rows = filter!(r -> choice_matches(r, typed), choice_rows(v, v.asking))
  v.pick = something(findfirst(r -> startswith(lowercase(r.name), lowercase(typed)), v.rows), 1)
end

describe(r::ChoiceRow) = begin
  v = r.of
  r.k <= length(v.rows) || return Box(height(0px))
  row = v.rows[r.k]
  float_row(row.name, get(row, :short, ""), picked=v.pick == r.k, on=chosen(v, row))
end

cursor(::ChoiceRow) = :hand
# ⌘-click on a table in a chart's list adds it to the tables that the chart draws, or takes it away
onkey(r::ChoiceRow, ev::KeyPress{Keys.mouse_left}) = r.of isa SourceChooser && only_held(ev, Keys.cmd) ? toggle_source!(r.of, r.k) : choose!(r.of, r.k)
# The mouse picks the row that it's over, as the arrow keys do
onmouse(r::ChoiceRow, ::MouseMove) = begin
  v = r.of
  v.pick = r.k
  menu = get(v.parts, :menu, nothing)
  menu === nothing || (menu.pick = r.k)   # it's in sight already, so the list doesn't scroll to it
  handled
end

describe(m::ChoiceMenu) = begin
  v = m.of
  n, high = length(v.rows), FLOAT_ROW
  scroll = get!(() -> Scroll(width(grow=grow)), v.parts, :choice_scroll)
  body = if n == 0
    float_none(v.asking == :folder ? "No folder has that name" : "Nothing has that name")
  else
    # Half a row at the bottom says that the list goes on
    scroll.height = height(n <= MOST_CHOICES ? n * high : MOST_CHOICES * high - high / 2)
    m.pick == v.pick || (m.pick = v.pick; scroll_into_view!(scroll, high * (v.pick - 1), high * v.pick))
    reuse!(scroll, Column(width(grow=grow), Alignment.Start, [block_part!(() -> ChoiceRow(of=v, k=k), v, (:choice_row, k)) for k in 1:n]...))
  end
  float_list(choice_input(v), body, name="Choices")
end

placed!(m::ChoiceMenu, side) = (m.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, m::ChoiceMenu) = caret(ctx, ui, m.side, rect(m.button))

# The list sees a key before its field does. The arrows pick a row, Return takes it, and Esc closes the list.
onkey(m::ChoiceMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? choose!(m.of, m.of.pick) :
  m.of isa SourceChooser && only_held(ev, Keys.cmd) ? toggle_source!(m.of, m.of.pick) : nothing   # ⌘Return adds the table, as ⌘-click does
onkey(m::ChoiceMenu, ev::KeyPress{Keys.escape}) = unmodified(ev) ? stop_choosing!(m.of) : nothing
onkey(m::ChoiceMenu, ev::KeyPress{Keys.down}) = unmodified(ev) ? (v = m.of; v.pick = min(v.pick + 1, max(1, length(v.rows))); handled) : nothing
onkey(m::ChoiceMenu, ev::KeyPress{Keys.up}) = unmodified(ev) ? (v = m.of; v.pick = max(v.pick - 1, 1); handled) : nothing

# Return in the field gives the keyboard back to the page
onkey(v::SearchView, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (focus(editor(v)); handled) : nothing

"""
The Markdown files in `folder`, then those of each folder in it, in the order
of their names, and whether that's all of them. A folder whose name starts
with a dot is left out, and so is a file or a folder that you ignore. A folder
with a great many files in it, like a whole disk, is read for a part of a
second only, so that the window doesn't stop.
"""
pages_under(folder; budget=FIND_BUDGET) = begin
  out, whole, started = String[], true, time()
  ignored = Folders.ignored()
  for (root, dirs, files) in walkdir(folder, onerror=_ -> nothing)
    filter!(d -> !left_out(joinpath(root, d), ignored) && d != "node_modules", dirs)
    sort!(dirs, by=lowercase)
    append!(out, (joinpath(root, f) for f in sort(files, by=lowercase) if ismarkdown(f) && !left_out(joinpath(root, f), ignored)))
    (length(out) > FIND_PAGES || time() - started > budget) && (whole = false; break)
  end
  first(out, FIND_PAGES), whole
end

"""
The pages of `folder`, with when the file of each last changed. The folder is
read again after a few seconds, and after longer when reading it takes long.
"""
folder_pages(folder) = begin
  kept = get(FOLDER_PAGES, folder, nothing)
  kept !== nothing && time() < kept.next && return kept
  started = time()
  pages, whole = pages_under(folder)
  found = [(path, mtime(path)) for path in pages]
  FOLDER_PAGES[folder] = (next=time() + max(FIND_EVERY, 20 * (time() - started)), read=started, pages=found, whole=whole)
end

# The text of each page that a list has read, with when the file last changed, so a file is read again only when it changes
const PAGE_TEXTS = Dict{String,Tuple{Float64,Vector{String},Vector{Line}}}()

"""
The lines of the page at `path`, what each line is, and a mark that changes
when the page's text does. A page that's open gives its text as it is now,
with the changes that aren't saved. `at` is when the page's file last changed.
"""
page_text(e, path, at) = begin
  b = get(e.buffers, path, nothing)
  b !== nothing && !readonly(b) && return b.lines, kinds(b), (:open, b.version)
  kept = get(PAGE_TEXTS, path, nothing)
  kept !== nothing && kept[1] == at && return kept[2], kept[3], at
  lines = filesize(path) > 2_000_000 ? String[] : try text(path) catch; String[] end
  length(PAGE_TEXTS) > 2FIND_PAGES && empty!(PAGE_TEXTS)
  PAGE_TEXTS[path] = (at, lines, classify(lines))
  lines, PAGE_TEXTS[path][3], at
end

"The folder that the list looks in"
search_folder(e, q::Searches.Query) = isempty(q.folder) ? docdir(e) : abspath(joinpath(docdir(e), expanduser(q.folder)))

"""
What the list shows: the lines that match, page by page, whether every page of
the folder was read, and why there are no lines when the folder can't be read.
It's worked out again when a page changes in Ladder, and when the folder is
read again. Only the pages that changed are looked through again.
"""
found!(v::SearchView) = begin
  e = editor(v)
  q = v.data
  folder = search_folder(e, q)
  listed = isdir(folder) ? folder_pages(folder) : nothing
  # ⌘Z gives a page the version that it had before, so the version of each open page is looked at, not only the newest one
  key = (v.lines, hash([b.version for b in values(e.buffers)]), listed === nothing ? 0.0 : listed.read, folder, length(v.kept))
  v.shown !== nothing && v.shown[1] == key && return v.shown[2]
  listed === nothing && return (v.shown = (key, (matches=Searches.Match[], whole=true, problem="There's no folder called “$(q.folder)” beside this page.")))[2]
  every, kept = Searches.Match[], Searches.Match[]
  for (path, at) in listed.pages
    lines, ks, mark = page_text(e, path, at)
    had = get(v.pages, path, nothing)
    ms = had !== nothing && had[1] == mark ? had[2] : (v.pages[path] = (mark, Searches.matches(q, path, lines, ks)))[2]
    # An item whose box was clicked here stays in the list, though it no longer matches
    for k in v.kept
      k.path == path || continue
      i = Searches.locate(k, lines, ks)
      i === nothing && continue
      push!(kept, Searches.Match(path, i, k.text, k.kind))
      any(m -> m.line == i, ms) || (ms = sort!([ms; kept[end]], by=m -> m.line))
    end
    append!(every, ms)
  end
  v.kept = kept
  key = (key[1:4]..., length(v.kept))
  (v.shown = (key, (matches=every, whole=listed.whole, problem="")))[2]
end

"The name of the page at `path` as the list shows it: where it is in the list's folder, without the end of its file's name"
page_name(v::SearchView, path) = splitext(relpath(path, search_folder(editor(v), v.data)))[1]

describe(p::SearchPage) =
  Row(width(grow=grow), height(30px), padding(12px, 0px), child_gap=7px, Alignment.Center, name="Page",
    Icon("file-earmark-text", size=13px, color=colours.dim),
    Box(label(page_name(p.of, p.path), 12.5px, color=ishovered(p) ? colours.accent : colours.ink, weight="Semibold")), Box(width(grow=grow)))

describe(t::SearchTick) = begin
  row = t.of
  ms = found!(row.of).matches
  done = row.i <= length(ms) && ms[row.i].kind == :done
  side = 15px
  Box(fixed(side), height(side), radius(4px), Alignment.Center, justify=Alignment.Center,
      (done ? (background(colours.accent),) : (border(1.5px, :solid, ishovered(t) ? colours.accent : colours.marker),))...,
      (done ? (Icon("check", size=13px, color=colours.bg),) : ())...)
end

describe(r::SearchRow) = begin
  ms = found!(r.of).matches
  r.i <= length(ms) || return Box(height(0px))
  m = ms[r.i]
  r.box === nothing && (r.box = SearchTick(of=r); setfield!(r.box, :parent, r))
  boxed = m.kind in (:todo, :done)
  Row(width(grow=grow), padding(4px, 12px, 4px, 31px), child_gap=9px, Alignment.Start, name="Found", background(ishovered(r) ? colours.hover : clear),
    (boxed ? (Box(padding(0px, 1px, 0px, 0px), r.box),) : ())...,
    # A block has the icon of its kind, as it has in the sidebar
    (Searches.isblock(m.kind) ? (Box(padding(0px, 2px, 0px, 0px), Icon(block_icon(m.kind), size=13px, color=colours.dim)),) : ())...,
    Box(width(grow=grow), Text(m.text, size=13.5px, family=SANS, subfamily=m.kind == :heading ? "Semibold" : "",
                               color=m.kind == :done ? colours.dim : colours.ink, wrap=WrapMode.words)))
end

cursor(::Union{SearchPage,SearchRow,SearchTick}) = :hand
cursor(::SearchView) = :arrow

"The icon of the kind of block `kind`, one of the kinds of find.jl. It's the one that the sidebar shows beside such a block."
block_icon(kind::Symbol) = begin
  kind == :code && return "code-slash"
  lang = first(Searches.WHATS[kind].langs)
  haskey(BLOCKS, lang) ? block_icon(BLOCKS[lang]) : "puzzle"
end

"""
Show the page at `path`, with the caret at the end of the line that `m` is on
now. For a block that shows as a component, the caret goes to the line under
it: in the block, it would show the block's lines.
"""
visit!(e, path, m=nothing) = begin
  path == e.buf.path || open!(e, path)
  focus(e)
  m === nothing && return handled
  b = e.buf
  i = Searches.locate(m, b.lines, kinds(b))
  i === nothing && return handled
  Searches.isblock(m.kind) || return show_line!(e, i)
  under = last(Searches.block_span(kinds(b), i)) + 2
  show_line!(e, m.kind == :code ? min(i + 1, length(b.lines)) : min(under, length(b.lines)))
end

onkey(p::SearchPage, ::KeyPress{Keys.mouse_left}) = visit!(editor(p.of), p.path)
onkey(r::SearchRow, ::KeyPress{Keys.mouse_left}) = begin
  ms = found!(r.of).matches
  r.i <= length(ms) ? visit!(editor(r.of), ms[r.i].path, ms[r.i]) : handled
end

"""
Tick the to-do item `m` in its own page when `done` is true, or take its tick
away. A page that's open is changed as if you'd clicked the box there. If it
isn't the page that shows, and it had nothing to save, it's saved. A page
that isn't open is changed in its file. It's false when the item isn't there
any more, or its page can't be written.
"""
tick_page!(e, m::Searches.Match, done::Bool) = begin
  b = get(e.buffers, m.path, nothing)
  if b !== nothing && !readonly(b)
    i = Searches.locate(m, b.lines, kinds(b))
    i === nothing && return false
    clean = !dirty(b)
    tick_item!(b, i, done)
    b !== e.buf && clean && save!(b)
  else
    isfile(m.path) || return false
    lines = text(m.path)
    i = Searches.locate(m, lines)
    i === nothing && return false
    new, z = Repeats.tick(lines, i, done; today=calendar_today())
    splice!(lines, i:z, new)
    # A file that can't be written, like one of the pages that come with the app, stays as it is
    try write(m.path, join(lines, "\n")) catch; return false end
    empty!(FOLDER_PAGES)   # the folder is read again, so that a list has the file as it is now
  end
  true
end

"""
Tick the to-do item `m` of a list in its own page, or take its tick away: see
`tick_page!`. The item stays in the list until another page shows.
"""
tick_found!(v::SearchView, m::Searches.Match) = begin
  e = editor(v)
  done = m.kind != :done
  tick_page!(e, m, done) || return handled
  # The item stays in this list. A second click, which puts it back as it was, lets it go.
  now = Searches.Match(m.path, m.line, m.text, done ? :done : :todo)
  k = findfirst(x -> x.path == m.path && x.text == m.text && x.kind == m.kind, v.kept)
  k === nothing ? push!(v.kept, now) : (v.kept[k] = now)
  Searches.kind(v.data) == now.kind && filter!(x -> !(x.path == now.path && x.text == now.text), v.kept)
  v.shown = nothing
  handled
end

"The lists of the page that shows let go of the items that were ticked in them. `open!` does this when another page takes its place."
forget_ticked!(e) = for (key, v) in e.nodes
  v isa SearchView && key[3] == e.buf.path && !isempty(v.kept) && (empty!(v.kept); v.shown = nothing)
end

onkey(t::SearchTick, ::KeyPress{Keys.mouse_left}) = begin
  row = t.of
  ms = found!(row.of).matches
  row.i <= length(ms) ? tick_found!(row.of, ms[row.i]) : handled
end

"""
What the top of the list says: what it lists, how many lines match and where
it looks. An item that was ticked here stays in the list, but it no longer
matches, so it isn't counted.
"""
search_words(v::SearchView) = begin
  q = v.data
  own = [m for m in found!(v).matches if Searches.counted(q, m)]
  Searches.summary(q, length(own), length(unique(m.path for m in own)))
end

describe(v::SearchView) = begin
  e = editor(v)
  found = found!(v)
  ms = found.matches
  q = v.data
  with_theme(component_theme(e.zoom)) do
    input = search_input(v)
    input.color = colours.ink
    w = window_of(v)
    typing = w !== nothing && w.focus === input
    field = Row(width(grow=grow), height(26px), padding(8px, 0px), child_gap=7px, radius(6px), Alignment.Center, background(colours.bg),
                border(1px, :solid, typing ? colours.accent : colours.line),
                Icon("search", size=12px, color=colours.dim), Box(width(grow=grow), height(grow=grow), input))
    # The button for the folder shows only when there's another folder to choose
    menus = (block_part!(() -> SearchChoice(of=v, what=:kind), v, :kind),
             (isempty(search_folders(v)) ? () : (block_part!(() -> SearchChoice(of=v, what=:folder), v, :folder),))...)
    gap() = Box(width(4px))   # a new one each time: a box can be in the page only once
    bars = editor(v).width < FIND_BAR ?
           (block_bar(field), block_bar(menus[1], gap(), menus[2:end]..., Box(width(grow=grow)))) :
           (block_bar(field, gap(), menus[1], gap(), menus[2:end]...),)
    total = Row(width(grow=grow), padding(9px, 12px, 3px, 12px), Alignment.Start, Box(label(search_words(v), 12px, color=colours.dim)), Box(width(grow=grow)))
    isempty(found.problem) || return Column(block_look()..., clip=true, name="Found", bars..., block_note(found.problem))
    rows = Any[total]
    pages = 0
    for i in 1:min(length(ms), FIND_MOST)
      if i == 1 || ms[i-1].path != ms[i].path
        page = block_part!(() -> SearchPage(of=v), v, (:page, pages += 1))
        page.path = ms[i].path
        push!(rows, page)
      end
      push!(rows, block_part!(() -> SearchRow(of=v, i=i), v, (:row, i)))
    end
    length(ms) > FIND_MOST && push!(rows, block_note("And $(length(ms) - FIND_MOST) more. Add words to the block's with: line to list fewer."))
    found.whole || push!(rows, block_note("This folder has more pages than Ladder reads for a list. Name a folder in it with the block's in: line."))
    Column(block_look()..., clip=true, name="Found", bars..., rows..., Box(height(6px)))
  end
end

"The list as HTML: the name of each page, and its lines under it"
find_html(e, v::SearchView) = begin
  ms = found!(v).matches
  isempty(ms) && return "<p>$(escape(Searches.summary(v.data, 0, 0)))</p>"
  out = String[]
  for (i, m) in enumerate(ms)
    if i == 1 || ms[i-1].path != m.path
      i == 1 || push!(out, "</ul>")
      push!(out, "<p><strong>$(escape(page_name(v, m.path)))</strong></p>\n<ul style=\"list-style: none; padding-left: 0.5em\">")
    end
    push!(out, "<li>$(m.kind == :done ? "☑ " : m.kind == :todo ? "☐ " : "")$(escape(m.text))</li>")
  end
  join(out, "\n") * "\n</ul>"
end

BLOCKS[FIND] = SearchView
block_name(::Type{SearchView}) = "Find"
block_icon(::Type{SearchView}) = "search"
block_insert(::Type{SearchView}) = ("Find", ["```$FIND", "```", "", ""], (4, 0))
block_html(e, v::SearchView) = find_html(e, v)
