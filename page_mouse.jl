# The mouse on the page: the place under a point, a click on a link, and a word or a line that a click picks

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" hittest
@use "./markdown" Kind words isdone
@use "./sheet" number_at
@use "./repeats" => Repeats
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl" URI
@use "./base" exports...
@use "./math_view" exports...
@use "./julia_levels" exports...
@use "./schedule_view" exports...
@use "./slides_view" exports...
@use "./code_nav" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...
@use "./chart_view" exports...
@use "./drag_number" exports...
@use "./line_history" exports...
@use "./todo_clock" exports...
@use "./givers" exports...
@use "./webpage_view" html_shown
@use "./showed_before" note_place! input
@use "./columns_view" item_under

export follow_heading!, go_lines!, heading_slug, holds, inline_at, link_at, linked_file, page_uri,
       pick_clicked!, read_step, word_at

# --- the mouse on the page --------------------------------------------------------------

"The place in the document under a point in the window"
locate(e, (x, y)) = begin
  # On a page that's scrolled sideways, a point on the numbers of the lines is on the first part of the line that shows
  dx, dy = max(x - e.origin[1], sideways(e)), y - e.origin[2]
  items = e.layout
  isempty(items) && return e.buf.caret
  it = items[item_under(e, dx, dy)]
  # Until the next frame, the layout can be of the page that showed before, as when a click opened another
  # file and the mouse moved with its button still down. That page can have more lines than this one.
  it.last <= length(e.buf.lines) || return e.buf.caret
  if it.content isa Grid
    g = it.content
    # The row and the column under the point
    r = something(findfirst(r -> dy < it.top + cell_origin(g, r, 1)[2] + g.heights[r], eachindex(g.rows)), length(g.rows))
    c = something(findlast(c -> dx >= cell_origin(g, r, c)[1], eachindex(g.widths)), 1)
    cells = g.cells[r]
    isempty(cells) && return line_end(e.buf, g.rows[r])
    # A row can have fewer cells than the table has columns
    c = min(c, length(cells))
    f = g.flows[r][c]
    x, y = cell_origin(g, r, c)
    k = line_at(f, dy - it.top - y)
    return (g.rows[r], cellcol(f, k, dx - x, cells[c]))
  end
  it.content isa Sheet && return locate(e, it, it.content, dx - item_room(e, it)[1], dy - it.top)
  if it.content isa Live
    # A point on a live block counts as the end of the line above it or the start of the line below
    above = dy < it.top + it.tall/2 ? it.first > 1 : it.last == length(e.buf.lines)
    return above && it.first > 1 ? line_end(e.buf, it.first - 1) : it.last < length(e.buf.lines) ? (it.last + 1, 0) : (it.first, 0)
  end
  f = it.content::Flow
  # A line of the page before can be longer than this page's line of the same number
  (it.first, min(colat(f, line_at(f, dy - it.top), dx), length(e.buf.lines[it.first])))
end

"The link under a point in the window, or nothing. A link in a cell of a table counts too."
link_at(e, pos) = begin
  line, col = locate(e, pos)
  it = item(e, line)
  c = it.content
  # Each cell of a table has its own lines of text. Their columns are the columns of the row's line.
  r = c isa Grid ? findfirst(==(line), c.rows) : nothing
  flows = c isa Flow ? [c] : r === nothing ? Flow[] : c.flows[r]
  for f in flows, vl in f.lines, seg in vl.segs
    seg.col <= col < seg.col + seg.n && !isempty(seg.link) && return seg.link
  end
  nothing
end

"""
The link that's drawn under a point in the window, or nothing. `link_at` gives
the link nearest to a point, which is right for a click with ⌘ held. A point
beside a line, or between two lines, is on no link here, so a click with no
key held opens a link only when the click is on its words. A link in a cell
of a table counts too.
"""
link_on(e, (x, y)) = begin
  dx, dy = x - e.origin[1], y - e.origin[2]
  (dy >= 0px && !isempty(e.layout)) || return nothing
  it = e.layout[item_under(e, dx, dy)]
  c = it.content
  c isa Flow && return link_on(c, dx, dy - it.top)
  c isa Grid || return nothing
  # Each cell of a table has its own lines of text, from the top left of the cell
  for r in eachindex(c.rows), col in eachindex(c.flows[r])
    cx, cy = cell_origin(c, r, col)
    found = link_on(c.flows[r][col], dx - cx, dy - it.top - cy)
    found === nothing || return found
  end
  nothing
end

"The link that's drawn at `dx` across and `dy` down from the top left of `f`, or nothing"
link_on(f::Flow, dx::px, dy::px) = begin
  for vl in f.lines
    top = f.above + vl.top
    top <= dy < top + vl.high || continue
    for seg in vl.segs
      !isempty(seg.link) && seg.x <= dx < seg.x + seg.w && return seg.link
    end
  end
  nothing
end

isword(c::Char) = isletter(c) || isdigit(c) || c == '_' || c == '\''

"The columns of the word around column `col` of `line`"
word_at(line::String, col::Int) = begin
  chars = collect(line)
  lo = hi = clamp(col, 0, length(chars))
  while lo > 0 && isword(chars[lo]); lo -= 1 end
  while hi < length(chars) && isword(chars[hi+1]); hi += 1 end
  (lo, hi)
end

"The caret moved or the text changed, so show the caret"
touch!(e; keep_goal=false) = begin
  e.buf.reading = false
  e.blink = time()
  e.reveal = true
  keep_goal || (e.goal = nothing)
  confine!(e)
end

"The line of the to-do item whose box is under a point in the window, or nothing"
todo_at(e, (x, y)) = begin
  isempty(e.layout) && return nothing
  dx, dy = x - e.origin[1], y - e.origin[2]
  it = e.layout[item_under(e, dx, dy)]
  f = it.content
  shows_box(f) || return nothing
  # The box is on the item's first line
  it.top + f.above <= dy < it.top + f.above + first(f.lines).high || return nothing
  for seg in first(f.lines).segs
    isbox(seg) && return seg.x <= dx < seg.x + seg.w ? it.first : nothing
  end
  nothing
end

"What inline code made that's under a point in the window: its Inline, or nothing"
inline_at(e, (x, y)) = begin
  isempty(e.layout) && return nothing
  dx, dy = x - e.origin[1], y - e.origin[2]
  it = e.layout[item_under(e, dx, dy)]
  c = it.content
  if c isa Grid
    for r in eachindex(c.rows), col in eachindex(c.flows[r])
      cx, cy = cell_origin(c, r, col)
      found = inline_at(c.flows[r][col], dx - cx, dy - it.top - cy)
      found === nothing || return found
    end
    return nothing
  end
  c isa Flow ? inline_at(c, dx, dy - it.top) : nothing
end

inline_at(f::Flow, dx::px, dy::px) = begin
  (0px <= dy < tall(f)) || return nothing
  for seg in f.lines[line_at(f, dy)].segs
    seg.node !== nothing && seg.x <= dx < seg.x + seg.w && return seg.node
  end
  nothing
end

"""
Tick the box of the to-do item on line `i`, or take its tick away. The caret
stays where it is. A tick of an item that repeats, like one that ends with
"every week", adds the next one under it: see repeats.jl.
"""
tick!(e, i::Int) = begin
  # On another day than today, the box shows how the item stands then, which a click can't change
  ticked_then(e, i) === nothing || return e
  tick_item!(e.buf, i, !isdone(e.buf.lines[i]))
  stop_clock!(e, i)   # a tick stops the clock of a time log that runs on the item
  e
end

"""
Tick the to-do item on line `i` of `b` when `done`, or take its tick away, in
one edit, so one ⌘Z takes it back. The item that a tick of a repeating item
adds goes in the same edit. The caret and the other end of the selection stay
with their text.
"""
tick_item!(b::Buffer, i::Int, done::Bool) = begin
  new, z = Repeats.tick(b.lines, i, done; today=calendar_today())
  caret, anchor = b.caret, b.anchor
  edit!(b, (i, 0), line_end(b, z), join(new, "\n"))
  grow = length(new) - (z - i + 1)
  # A line after the item moves down or up with the line that went in or out. One that went takes it to the item's last line.
  keep((l, c)) = l > z ? (l + grow, c) : l < i + length(new) ? (l, min(c, length(b.lines[l]))) : line_end(b, i + length(new) - 1)
  b.caret, b.anchor = keep(caret), keep(anchor)
  b
end

press!(e, pos) = begin
  slideshow(e) === nothing || return slide_press!(e, pos)   # a click on a slide goes to the next one, or back
  # ⌥-click on a part of another page shows the link that names the part, as ⌥-click on any part shows its lines
  (hosted(e) !== nothing && only_held(e, Keys.opt)) && return press!(hosted(e), pos)
  empty!(e.glides)   # a click puts the caret at its new place at once, even a click that changes the text
  b = e.buf
  # A click on the number of a line asks git when the line last changed. The click puts the caret on the line too.
  # Julia compiles line_history! and definition! when they're first used, not with this function, so a first click doesn't wait for them.
  numbered = number_at(e, pos)
  numbered === nothing || Base.invokelatest(line_history!, e, numbered)
  box = only_held(e, Keys.opt) ? nothing : todo_at(e, pos)
  if box !== nothing
    # A click on a to-do item's box ticks it, and doesn't move the caret
    focus(e)
    e.popup = :none
    e.clicked = (time(), (box, 0), 0)
    return tick!(e, box)
  end
  # A press on what a number comes to takes hold of the number: a drag then changes it
  found = unmodified(e) ? scrub_at(e, pos) : nothing
  found === nothing || return scrub!(e, found, pos)
  # A click on the value of a name, like !`energy`, goes to where the page gives the name its value
  given = unmodified(e) ? giver_at(e, pos) : nothing
  given === nothing || return go_to_giver!(e, given)
  it = e.layout[item_under(e, pos[1] - e.origin[1], pos[2] - e.origin[2])]
  made = only_held(e, Keys.opt) ? nothing : inline_at(e, pos)
  # A click on a formula in a line of text puts the caret beside it, as a click on a word does
  if made !== nothing && !(made.node isa Equation)
    # What inline code made takes its own clicks, as a live block does. A click with ⌥ held shows the code.
    e.popup = :none
    e.clicked = (time(), (it.first, 0), 0)
    took(e) || focus(e)
    return
  end
  if it.content isa Live && !only_held(e, Keys.opt)
    # A live block takes its own clicks. A part of it that took the keyboard, like a text field, keeps it.
    e.popup = :none
    e.clicked = (time(), (it.first, 0), 0)
    took(e) || focus(e)
    pick_clicked!(e, it)
    return
  end
  focus(e)
  e.popup = :none
  # ⌘ with another key held, like ⇧ or ⌃, opens no link
  if only_held(e, Keys.cmd)
    url = link_at(e, pos)
    url === nothing || return follow!(e, url)
    # In Julia code, a click on a name goes to where the name is defined
    it.content isa Flow && Base.invokelatest(definition!, e, locate(e, pos)) === true && return
  elseif follows_links(b) && only_held(e, Keys(0))
    # A page that's never changed has no caret for a click to place, so a click with no key held on a link opens it.
    # So does one in a page from a web server, as in a browser. A click anywhere else puts the caret there.
    url = link_on(e, pos)
    url === nothing || return follow!(e, url)
  end
  if it.content isa Live
    # A click with ⌥ held shows the block's code. A part of one line, like a picture, shows its line, with the caret at the end.
    e.clicked = (time(), (it.first, 0), 0)
    b.caret = b.anchor = it.last > it.first ? (it.first + 1, 0) : line_end(b, it.first)
    return touch!(e)
  end
  it.content isa Sheet && press!(e, it, it.content, pos) && return touch!(e)
  if it.content isa Grid && isspread(it.content) && only_held(e, Keys.opt)
    # A click on a spreadsheet with ⌥ held shows it as lines of code
    b.caret = b.anchor = line_end(b, it.first)
    return touch!(e)
  end
  at = settle(b, locate(e, pos))
  t, before, count = e.clicked
  count = time() - t < 0.4 && before == at ? count % 3 + 1 : 1
  e.clicked = (time(), at, count)
  if count == 2
    lo, hi = word_at(b.lines[at[1]], at[2])
    b.anchor, b.caret = (at[1], lo), (at[1], hi)
  elseif count == 3
    # Three clicks select the line, or in a table the cell
    cell = cellat(b, at)
    lo, hi = cell === nothing ? (0, length(b.lines[at[1]])) : (cell.lo, cell.hi)
    b.anchor, b.caret = (at[1], lo), (at[1], hi)
  else
    b.caret = at
    only_held(e, Keys.shft) || (b.anchor = at)
  end
  touch!(e)
end

"""
After a click on the live block that `it` shows, put the caret on the block as a
whole, as ↑ and ↓ do, so that it has the line round it. A click that a part of
the block takes for itself, like a click on a button, never comes here. A click
that a part uses and lets go on to the page, like a stroke of a pen or a click
in a field, puts the caret on the block too, unless the part moved the caret.
A click with a key like ⌘ or ⇧ held leaves the caret where it is. The page
doesn't scroll, because the block is under the mouse.
"""
pick_clicked!(e, it::Item) = begin
  b = e.buf
  (unmodified(e) && rich(b) && !b.fixed && b.caret == b.stood) || return
  # A part of the block that changed its lines leaves the caret where it is
  part(b, it.first) == (it.first, it.last) || return
  b.caret = b.anchor = (it.first, 0)
  touch!(e)
  e.reveal = false
end

"""
Give a click on `node` to the page, as a click on its text is given. A part of
the page like a picture, a table from a CSV file or the front matter has no use
for a click of its own, so the page puts the caret on the part as a whole, or
with ⌥ held shows its lines as they're written. Such a part's node hangs from
the editor, not from the page's text, so the click doesn't get there by itself.
"""
click_page!(node, ev) = (press!(editor(node), ev.window.mouse); handled)

"""
How far a key scrolls the page while it's read, or nothing for a key that doesn't
scroll it. `command` is the command that the key runs while the page isn't read.
The keys that move the caret up and down scroll a little. The keys that move it
a screen, and Space, scroll a screen less a little, so a line or two stays in
sight. Home, End and the keys that move the caret to the top or the bottom of
the page scroll that far.
"""
read_step(e, K, command, down) = begin
  screen = e.scroll.viewport - 40px
  # Home, End and Space with no command scroll only by themselves, with no key of ⌃, ⌘, ⌥ and ⇧ held. Space with ⇧ goes back.
  plain = down == Keys(0)
  command == :up ? -50px :
  command == :down ? 50px :
  command == :page_up ? -screen :
  command == :page_down ? screen :
  command == :doc_start || (K == Keys.home && (command == :line_start || (command === nothing && plain))) ? px(-Inf) :
  command == :doc_end || (K == Keys._end && (command == :line_end || (command === nothing && plain))) ? px(Inf) :
  command === nothing && K == Keys.space && (plain || down == Keys.shft) ? (plain ? screen : -screen) : nothing
end

"Scroll the page by `by`, as far as it goes"
scroll_page!(e, by) = begin
  s = e.scroll
  s.offset = clamp(s.offset + by, 0px, max(0px, s.content_height - s.viewport))
  e
end

"True when `a` is `b` or holds it"
holds(a, b) = begin
  while b !== nothing
    b === a && return true
    b = b.parent
  end
  false
end

"""
True when the node that has the keyboard is something other than the text, and
the click that is happening now is on that node, or on a part of it, or on a
node that holds it. A click on a list in a live block gives the list the
keyboard, and the click goes on to the page after the list has taken it.
"""
took(e) = begin
  w = window_of(e)
  w === nothing && return false
  f, under = w.focus, hittest(w)
  (f === nothing || f === e || f === input(e) || under === nothing) && return false
  holds(f, under) || holds(under, f)
end

"A heading as a link names it: its letters and digits in lower case, with a - where anything else is. `Live blocks` is `live-blocks`."
heading_slug(words) = String(strip(replace(lowercase(plain_cell(words)), r"[^\p{L}\p{N}]+" => "-"), '-'))

"""
Follow a link that names a heading of a page: `welcome.md#tables`, or `#tables`
for a heading of the page that shows. The page opens, and the heading goes to
the top of the window. It's true when the link names a page. It's false for any
other link with a # in it, like the address of a web page.
"""
follow_heading!(e, url) = begin
  to = linked_file(e, url)
  (to !== nothing && occursin('#', url) && ismarkdown(to[1]) && isfile(to[1])) || return false
  go_heading!(e, to[1], unescaped(to[2]))
end

"Show the page at `path` with its heading `name` near the top of the window. A page with no such heading shows from where it was. It's true."
go_heading!(e, path, name) = begin
  hosted(e) === nothing || return go_heading!(top_editor(e), path, name)   # a link in a part of another page goes there in the window
  path == e.buf.path || open!(e, path)
  b = e.buf
  ks = kinds(b)
  slug = heading_slug(name)
  i = findfirst(i -> ks[i].kind == Kind.heading && heading_slug(rest(b.lines[i], ks[i].prefix)) == slug, eachindex(ks))
  i === nothing && return true
  show_line!(e, i)
  # Its line goes near the top of the window. The next frame does it, once it has laid out the page.
  hold!(e, i, 24px - PAGE_TOP)
  true
end

"""
The file:// address of the page of `e`, which its links are read from. A page
with no file is read from its folder. A reply of the agent is read from the
folder that the agent works in, as its page is there.
"""
page_uri(e) = URI{:file}(path=FSPath(isempty(e.buf.path) ? joinpath(e.folder, "Untitled") : e.buf.path))

"""
The file of the Mac that the link `url` in the page of `e` names, with what
follows its # as it's written, or nothing for a link to anything else, like a
web page or an email address. URI.jl reads the link as one in the page's own
file, so `plan.md#tables` is beside the page, `#tables` is in the page, and
`file:///Users/sam/plan.md#L12`, as an agent like Antigravity writes one, is
where it says. A path from ~, like `~/Mail`, is from the home folder.
"""
linked_file(e, url::AbstractString) = begin
  to = URI(url, page_uri(e))
  to isa URI{:file} || return nothing
  (string(to.path), to.fragment)
end

"""
Follow a link to lines of a file, as an agent writes one: `plan.md#L12`, or
`plan.md#L12-L20` for lines 12 to 20. The file shows in the window, with the
caret on the first of the lines and that line near the top of the window, as
a click on a heading in the outline does. A number past the end of the file
is its last line. It's false for a link that names no lines of a file that's
there.
"""
go_lines!(e, url) = begin
  to = linked_file(e, url)
  to === nothing && return false
  path, mark = to
  m = match(r"^L(\d+)(?:-L?\d+)?$", mark)
  (m !== nothing && isfile(path)) || return false
  e = top_editor(e)   # a link in a reply of the agent, or in a part of another page, shows in the window
  path == e.buf.path ? note_place!(e) : open!(e, path)   # ⌘⌥← comes back here
  # A file that shows as a picture, or a page that HTML makes, has no lines to go to
  (e.buf.path == path && !html_shown(e) && !isempty(e.buf.lines)) || return true
  line = clamp(parse(Int, m[1]), 1, length(e.buf.lines))
  show_line!(e, line)
  # The next frame puts the line near the top of the window, once it has laid out the file
  hold!(e, line, 24px - PAGE_TOP)
  true
end
