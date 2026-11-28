# A JSON file as a tree
#
# A JSON file shows as a tree of its values, as the inspector of a `ui` block
# shows a Julia value. The first row is the file's whole value, so you can see
# whether the file holds an object or a list. Each key of an object, and each
# item of a list, is a row, a step in from the row of what holds it. The row
# of an object or a list has an arrow, and a click on the row opens it or
# closes it. ⌥-click opens or closes everything in it too. A closed one shows
# on its row what it holds, as much as the row has room for. An open one says
# how many keys or items it has, in its brackets: {3 keys} or [22 items]. At
# first the tree is open as far as about a window of rows goes. The place of
# an item in its list counts from 0, as JSON's own tools count it.
#
# A click also chooses the row and gives the tree the keyboard. Then ↑ and ↓
# go from row to row, → opens a row or goes into it, ← closes it or goes to
# the row that holds it, and Return opens or closes it. ⌘C copies the value of
# the row: a string as its text, and an object or a list as JSON. Esc gives
# the keyboard back to the page.
#
# The tree is the file at its highest level, as the graphics are of a page. ⌘E
# goes down a level to the file's text, which you can select and search, and
# ⌘E again goes back up to the tree, open as it was. The file has two more
# levels under its text: its bytes in hexadecimal, and under those its bits.
# The ladder in the top bar opens into a slider with a stop for each of the
# four levels. See "the slider of the levels". From its bits to its bytes to
# its text, the window stays at the same place in the file. A file that isn't
# JSON after all, and one bigger than MOST_JSON, only shows as text.
#
# Only the rows that are in the window are made, so a long tree costs no more
# to draw than a short one.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./sheet" parts shown
@use "github.com/jkroso/JSON.jl" JSONObject JSONNumber json_value write_json
@use "./term/view" => Terms
@use InteractiveUtils: clipboard
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./sketch_view" exports...
@use "./csv_view" exports...

export JSONS, MOST_JSON, JSON_STEP, JSON_ARROW, JSON_PAD, MOST_STRING, JSON_READ, json_of, json_page,
       json_items, json_length, json_holder, json_count, json_copy, JSONRow, JSONTree, plant!, json_rows,
       json_rows!, json_opened, json_toggle!, json_each, json_row_h, json_face, json_words, json_quoted,
       json_brief, json_peek, json_shown, json_under, json_row, json_choose!, file_level!, place_in_file,
       line_of_byte

const JSONS = (".json", ".geojson")
const MOST_JSON = 32_000_000   # bytes. A bigger JSON file only shows as text.
const JSON_STEP = 18px         # how far in each level of the tree is
const JSON_ARROW = 16px        # the room for the arrow of an object or a list
const JSON_PAD = 6px           # between the ends of a row's highlight and its text
const MOST_STRING = 2000       # characters. A longer string stops there on its row.

"What each JSON file that was read holds, with when the file had last changed then. Only the last few are kept."
const JSON_READ = Dict{String,Tuple{Float64,Any}}()

"""
What the JSON file at `path` holds, or nothing if it isn't JSON or is bigger
than MOST_JSON. A file is read once, and again when it changes.
"""
json_of(path) = begin
  at = mtime(path)
  kept = get(JSON_READ, path, nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  value = 0 < filesize(path) <= MOST_JSON ? (try json_value(read(path)) catch; nothing end) : nothing
  length(JSON_READ) >= 4 && empty!(JSON_READ)
  JSON_READ[path] = (at, value)
  value
end

"True when the page shows a JSON file that can show as a tree: as the tree, or at a level under it, as the file's text, its bytes in hexadecimal or its bits"
json_page(b::Buffer) = b.view in FILE_VIEWS && lowercase(splitext(b.path)[2]) in JSONS && isfile(b.path) && json_of(b.path) !== nothing

json_items(o::JSONObject) = zip(o.keys, o.values)
json_items(l::Vector{Any}) = zip(0:length(l)-1, l)
"How many keys or items `v` has. A value that's neither an object nor a list has none."
json_length(o::JSONObject) = length(o.keys)
json_length(l::Vector{Any}) = length(l)
json_length(_) = 0
json_holder(v) = v isa JSONObject || v isa Vector{Any}

"How many keys or items `v` has, in words"
json_count(o::JSONObject) = (n = length(o.keys); "$(commas(n)) key$(n == 1 ? "" : "s")")
json_count(l::Vector{Any}) = (n = length(l); "$(commas(n)) item$(n == 1 ? "" : "s")")

"What ⌘C copies of `v`: a string as its text, and any other value as JSON"
json_copy(v::AbstractString) = String(v)
json_copy(v) = sprint(write_json, v, 0)

"A row of a JSON file's tree: how many steps in it is, the key of its value or its place in its list, and its value"
struct JSONRow
  depth::Int
  key::Union{Nothing,String,Int}
  value::Any
end

"The tree of the JSON file at `path`"
@def mutable struct JSONTree <: SemanticUI
  path::String = ""
  root::Any = nothing
  open::IdDict{Any,Bool} = IdDict{Any,Bool}()   # the objects and the lists that are open
  rows::Vector{JSONRow} = JSONRow[]             # the rows that show, worked out again when one opens or closes
  chosen::Int = 0                               # the row that the arrow keys are on, or 0 for none
end

"""
Show the tree of `root`, open as far as about `most` rows go. The top object
or list is always open. Then each level opens as a whole while there's room
for all of it.
"""
plant!(t::JSONTree, root, most=60) = begin
  t.root, t.chosen = root, 0
  empty!(t.open)
  level = json_holder(root) ? Any[root] : Any[]
  count = 0
  while !isempty(level)
    n = sum(json_length, level)
    count > 0 && count + n > most && break
    foreach(v -> t.open[v] = true, level)
    count += n
    level = Any[x for v in level for (_, x) in json_items(v) if json_length(x) > 0]
  end
  t.rows = json_rows(t)
  t
end

"""
The rows that show. The first is the file's whole value, so a file that holds
a list shows that it's a list, and with that row closed the tree is that one
row. Under each object or list that's open are the rows of its keys or items.
"""
json_rows(t::JSONTree) = json_rows!(JSONRow[], t.open, 0, nothing, t.root)
json_rows!(rows, open, depth, key, value) = begin
  push!(rows, JSONRow(depth, key, value))
  if json_holder(value) && get(open, value, false)
    for (k, x) in json_items(value)
      json_rows!(rows, open, depth + 1, k, x)
    end
  end
  rows
end

"True when row `i` is an object or a list that's open"
json_opened(t::JSONTree, i) = (v = t.rows[i].value; json_holder(v) && get(t.open, v, false))

"Open row `i` if it's closed, or close it. With `all`, everything in it opens or closes with it."
json_toggle!(t::JSONTree, i; all=false) = begin
  v = t.rows[i].value
  json_length(v) > 0 || return t
  shut = json_opened(t, i)
  set!(x) = shut ? delete!(t.open, x) : (t.open[x] = true)
  all ? json_each(set!, v) : set!(v)
  t.rows = json_rows(t)
  t
end

"Call `f` on `v` and on each object and list in it that has something in it"
json_each(f, v) = begin
  json_length(v) > 0 || return
  f(v)
  for (_, x) in json_items(v)
    json_each(f, x)
  end
end

"How far apart the rows of the tree are: as far as the lines of the file's text"
json_row_h(e) = code_size(e) * 1.5 / CODE_SCALE

"The face of the tree's text: the font of code, in `colour`"
json_face(e, colour=colours.ink) = Face(codefont(), codestyle(), code_size(e), colour, false)

"Words of the tree, in `colour`. Each is in a box, so it's as wide as it is and no wider."
json_words(e, s, colour) = Box(height(grow=grow), Alignment.Center,
  Text(s, size=code_size(e), family=codefont(), subfamily=codestyle(), color=colour, wrap=WrapMode.none))

"`s` as a string of JSON, in its quotes, no longer than `room` characters. A longer one stops with an …"
json_quoted(s, room) = begin
  q = sprint(write_json, length(s) > MOST_STRING ? first(s, MOST_STRING) : s, 0)
  length(q) <= room && length(s) <= MOST_STRING ? q : first(q, max(2, room - 2)) * "…\""
end

"What `x` shows as in a closed object or list: an object or a list in short, and a string no longer than 40 characters"
json_brief(x) = json_holder(x) ? (x isa JSONObject ? (json_length(x) == 0 ? "{}" : "{…}") : (json_length(x) == 0 ? "[]" : "[…]")) :
                x isa AbstractString ? json_quoted(x, 40) : sprint(write_json, x, 0)

"""
What a closed object or list holds, on one line of no more than `room`
characters, as far as there's room. The end says how many more there are.
"""
json_peek(v, room) = begin
  object = v isa JSONObject
  n = json_length(v)
  parts = String[]
  used = 2
  for (key, x) in json_items(v)
    part = (object ? key * ": " : "") * json_brief(x)
    left = n - length(parts) - 1   # how many come after this one
    more = left > 0 ? length(", … $(commas(left)) more") : 0
    !isempty(parts) && used + 2 + length(part) + more > room && break
    used += (isempty(parts) ? 0 : 2) + length(part)
    push!(parts, part)
  end
  left = n - length(parts)
  inside = join(parts, ", ") * (left > 0 ? ", … $(commas(left)) more" : "")
  object ? "{" * inside * "}" : "[" * inside * "]"
end

"The text of the value of a row, and its colour, no longer than `room` characters"
json_shown(t::JSONTree, i, room) = begin
  v = t.rows[i].value
  v isa AbstractString ? (json_quoted(v, room), colours.string) :
  v isa JSONNumber ? (v.text, colours.number) :
  v isa Bool || v === nothing ? (sprint(write_json, v, 0), colours.keyword) :
  json_length(v) == 0 ? (json_brief(v), colours.dim) :
  json_opened(t, i) ? (v isa JSONObject ? "{" * json_count(v) * "}" : "[" * json_count(v) * "]", colours.dim) :
                      (json_peek(v, room), colours.dim)
end

"The row of the tree that the mouse is over, or 0"
json_under(t::JSONTree) = begin
  ishovered(t) || return 0
  r, w = rect(t), window_of(t)
  (r === nothing || w === nothing) && return 0
  i = floor(Int, (w.mouse[2] - r.top) / json_row_h(editor(t))) + 1
  1 <= i <= length(t.rows) ? i : 0
end

"Row `i` of the tree. `over` is true while the mouse is over it, and `keys` while the tree has the keyboard."
json_row(t::JSONTree, e, i, over, keys) = begin
  row = t.rows[i]
  h = json_row_h(e)
  tint = i == t.chosen ? (keys ? colours.select : colours.active) : over ? colours.hover : clear
  key = row.key === nothing ? () :
        row.key isa Int ? (json_words(e, string(row.key), colours.faint), json_words(e, ": ", colours.faint)) :
                          (json_words(e, row.key, colours.call), json_words(e, ": ", colours.dim))
  # The code font is monospaced, so the room for the value is a number of characters
  wide = measure(json_face(e), "0")
  keyed = row.key === nothing ? 0 : length(string(row.key)) + 2
  room = max(12, floor(Int, (e.width - 2JSON_PAD - JSON_STEP * row.depth - JSON_ARROW) / wide) - keyed)
  text, colour = json_shown(t, i, room)
  arrow = json_length(row.value) > 0 ? Icon(json_opened(t, i) ? "chevron-down" : "chevron-right", size=10px, color=colours.dim) : Box()
  Row(width(grow=grow), height(h), Alignment.Center, padding(JSON_PAD, 0px), radius(4px), background(tint), clip=true,
    Box(width(JSON_STEP * row.depth)), Box(width(JSON_ARROW), height(grow=grow), Alignment.Center, arrow),
    key..., json_words(e, text, colour))
end

describe(t::JSONTree) = begin
  e = editor(t)
  h = json_row_h(e)
  n = length(t.rows)
  _, high = window_size(e)
  # Only the rows that are in the window are made, and a few more above and below
  lo = clamp(floor(Int, (e.scroll.offset - page_top(e) - LIVE_GAP) / h) - 6, 0, n)
  hi = min(n, lo + ceil(Int, high / h) + 12)
  over = json_under(t)
  w = window_of(t)
  keys = w !== nothing && w.focus === t
  Column(width(grow=grow), Alignment.Start,
    spacer(h * lo), [json_row(t, e, i, i == over, keys) for i in lo+1:hi]..., spacer(h * (n - hi)))
end

cursor(t::JSONTree) = (i = json_under(t); i > 0 && json_length(t.rows[i].value) > 0 ? :hand : :arrow)

# A click chooses a row and gives the tree the keyboard. On an object or a list it opens it or closes it,
# and with ⌥ it opens or closes everything in it too.
onkey(t::JSONTree, ev::KeyPress{Keys.mouse_left}) = begin
  i = json_under(t)
  focus(t)
  i == 0 && return handled
  t.chosen = i
  json_toggle!(t, i, all=only_held(ev, Keys.opt))
  handled
end

"Choose row `i`, and scroll the page so that it's in the window"
json_choose!(t::JSONTree, i) = begin
  isempty(t.rows) && return handled
  t.chosen = clamp(i, 1, length(t.rows))
  e = editor(t)
  r = rect(t)
  r === nothing && return handled
  h = json_row_h(e)
  top = r.top + h * (t.chosen - 1)   # where the row is in the window
  _, high = window_size(e)
  top < above_page(e) + h ? scroll_page!(e, top - above_page(e) - h) : top + 2h > high ? scroll_page!(e, top + 2h - high) : nothing
  handled
end

onkey(t::JSONTree, ev::KeyPress{Keys.down}) = unmodified(ev) ? json_choose!(t, t.chosen + 1) : nothing
onkey(t::JSONTree, ev::KeyPress{Keys.up}) = unmodified(ev) ? json_choose!(t, max(1, t.chosen - 1)) : nothing
# → opens a closed row, and goes into one that's open
onkey(t::JSONTree, ev::KeyPress{Keys.right}) = begin
  unmodified(ev) || return nothing
  i = t.chosen
  i == 0 && return json_choose!(t, 1)
  json_length(t.rows[i].value) == 0 && return handled
  json_opened(t, i) ? json_choose!(t, i + 1) : (json_toggle!(t, i); handled)
end
# ← closes an open row, and goes out of one that's closed, to the row that holds it
onkey(t::JSONTree, ev::KeyPress{Keys.left}) = begin
  unmodified(ev) || return nothing
  i = t.chosen
  i == 0 && return json_choose!(t, 1)
  json_opened(t, i) && return (json_toggle!(t, i); handled)
  d = t.rows[i].depth
  d == 0 ? handled : json_choose!(t, findprev(r -> r.depth < d, t.rows, i))
end
onkey(t::JSONTree, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (t.chosen > 0 && json_toggle!(t, t.chosen); handled) : nothing
onkey(t::JSONTree, ev::KeyPress{Keys.c}) = begin
  only_held(ev, Keys.cmd) || return nothing
  t.chosen > 0 && clipboard(json_copy(t.rows[t.chosen].value))
  handled
end

"Show the file of the page at the level `view`: :bits, :hex, :text, or :file for the tree of a JSON file and the table of a CSV file"
file_level!(e, view::Symbol) = begin
  b = e.buf
  # A CSV file's table and its text are the same lines, so a change at one level shows at the other. Its bytes are
  # the file's, so a change that isn't saved is written first. See "changing a CSV file".
  table_text(b) && view in (:file, :text) && return table_level!(e, view)
  table_text(b) && b.saved != b.version && save!(b)
  edits = table_text(b)
  at = place_in_file(e)
  # A terminal writes its file a moment after its shell writes. It writes it now, so that the file's text is what the terminal shows.
  term_page(b) && (v = get(e.nodes, (:term, b.path), nothing); v === nothing || Terms.save!(v))
  # A session's file is written now too, so that its text is what the session shows
  chat_page(b) && (p = get(e.nodes, (:chat, b.path), nothing); p === nothing || keep_talk!(p))
  shown = look(b.path, view)
  b.lines, b.about, b.view = shown.lines, shown.about, shown.view
  b.caret = b.anchor = (1, 0)
  b.saved = b.version += 1
  # A step back from the bytes to the text, or on, would put lines of one level in place of the other's
  (edits || table_text(b)) && (empty!(b.undo); empty!(b.redo))
  table_text(b) && (b.disk = copy(b.lines))
  e.scroll.offset = 0px
  # The window stays at the same place in the file, between its bits, its bytes and its text
  line = line_of_byte(b, at)
  line > 1 && hold!(e, line, 0px)
  focus(e)
  e
end

"""
How far into its file the line at the top of the window starts, in bytes, while
the page shows a file's bits, its bytes in hexadecimal or its text. It's 0 for
anything else. A line of text counts as its characters and its line break, so
in a file with tabs or with very long lines it's only near the place.
"""
place_in_file(e) = begin
  b = e.buf
  (b.view in (:bits, :hex, :text) && !isempty(e.layout) && e.scroll.offset > 0px) || return 0
  k = something(findfirst(it -> it.top + it.tall > e.scroll.offset, e.layout), 1)
  line = e.layout[k].first
  b.view == :bits ? BITS_ROW * (line - 1) : b.view == :hex ? 16(line - 1) : sum(l -> ncodeunits(l) + 1, @view(b.lines[1:line-1]), init=0)
end

"The line of the page that has byte `at` of its file, counted from 0, for a page that shows a file's bits, its bytes in hexadecimal or its text. It's 1 for any other page."
line_of_byte(b::Buffer, at::Int) = begin
  n = length(b.lines)
  b.view == :bits && return clamp(at ÷ BITS_ROW + 1, 1, n)
  b.view == :hex && return clamp(at ÷ 16 + 1, 1, n)
  b.view == :text || return 1
  upto = 0
  for (i, l) in enumerate(b.lines)
    upto += ncodeunits(l) + 1
    upto > at && return i
  end
  n
end
