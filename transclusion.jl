# A part of another page, which a line like ![[Ideas#Plans]] shows in this page

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./markdown" Kind words front_matter block_id only_id
@use "./sheet" shown
@use "./spreadsheet" moved
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
@use "./folder_page" exports...
@use "./views" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...
@use "./page_mouse" exports...
@use "./commands" exports...

export DEEPEST_PART, KEEP_PART, LiveCover, PART_NOTE_H, PART_TAB, PartSource, TRANSCLUSION,
       Transclusion, block_link!, copy_link_to_block!, enter_shown!, heading_lines, heading_words,
       host_paths, keep_shown!, leave_part!, live_cover, open_part!, part_editor, part_tall,
       reveal_part!, show_part!, transclusion_blocks, transclusion_lines, transclusions

# --- a part of another page ----------------------------------------------------------------
#
# A line that holds only a link like ![[Ideas#Plans]] shows that part of the
# page Ideas in this page. Ted Nelson called that a transclusion, and Notion
# calls it a synced block. The part isn't a copy. It's the other page's own
# lines: type in it here and the other page changes, and a change there shows
# here at once. ⌘S saves both pages. What comes after the # names the part:
#
#   - ![[Ideas]] is the whole page, without its front matter.
#   - ![[Ideas#Plans]] is the heading Plans and the lines under it, up to the
#     next heading that's as big as it or bigger.
#   - ![[Ideas#^prices]] is the block that has the name prices, as Obsidian
#     names one: see `block_id` in markdown.jl. The command Copy Link To Block
#     names the block at the caret, and copies the link that shows it.
#   - ![[Ideas#table 2]] is the second table of the page. A kind is one of
#     paragraph, heading, list, quote, table, code and picture, or the
#     language of a code block, like board, canvas or julia. Without a number,
#     it's the first one. Code counts the code blocks that show as code.
#
# A heading with the name comes first, so a heading called "Table 2" wins over
# the second table. The page is found as a wiki link finds it: see `wiki_path`.
#
# An editor of its own shows the part. It edits the other page's lines, and
# shows only the lines of the part. Ladder's keys work in it as they do in any
# page. A click in its text puts its caret there, and Return gives it the
# keyboard while the caret is on the part as a whole. ↑ on its first line, ↓
# on its last line and esc go back to this page. A key for the window, like
# ⌘W, is this page's. A live block of the other page, like a board or a chart,
# shows there what it shows in its own page, but a click on it does nothing.

"A line that holds only a link to a part of another page. The name of the part is after the [[."
const TRANSCLUSION = r"^\s*!\[\[([^\]|]+)(?:\|[^\]]*)?\]\]\s*$"

"True when line `i` holds only a link that shows a part of another page"
transcludes(b::Buffer, i::Int) = (line = b.lines[i]; occursin("![[", line) && occursin(TRANSCLUSION, line) && !in_browser(b.path))

"How many parts of other pages can show inside each other: a part of a page that shows a part of a page that…"
const DEEPEST_PART = 3

"How tall the line is that shows in place of a part that isn't there"
const PART_NOTE_H = 28px

"""
The room over the text of a part of another page. The button that opens the
other page sits there, on the line round the part. A click goes only to what's
inside its parent's box, so the button can't be over the line above the part.
"""
const PART_TAB = 15px

"A part of another page, as a line of this page shows it"
@def mutable struct Transclusion <: SemanticUI
  line::Int = 0            # the line of this page that names the part
  target::String = ""      # what the line names, like "Ideas#Plans"
  path::String = ""        # the other page's file
  sub::Any = nothing       # the editor of the other page's lines
  note::String = ""        # what shows in place of a part that isn't there
  tall::px = 0px
end

"What covers a live block in a part of another page, so that a click on the block does nothing"
@def mutable struct LiveCover <: SemanticUI
  tall::px = 0px
end

"The button over a part of another page that opens that page"
@def mutable struct PartSource <: SemanticUI
  of::Any = nothing   # the Transclusion
end

"The files of `e`'s page, of the page that shows a part of it, and so on up to the window's page"
host_paths(e) = (h = hosted(e); h === nothing ? [e.buf.path] : [e.buf.path; host_paths(h)])

"The views of the parts of other pages that `e`'s page shows"
transclusions(e) = [v for (k, v) in e.nodes if v isa Transclusion && k[2] == e.buf.path]

"The pages whose lines the parts on `e`'s page edit, with the pages that parts of those edit, and so on"
shown_buffers(e) = begin
  out = Buffer[]
  for v in transclusions(e)
    v.sub === nothing && continue
    any(b -> b === v.sub.buf, out) || push!(out, v.sub.buf)
    foreach(b -> any(c -> c === b, out) || push!(out, b), shown_buffers(v.sub))
  end
  out
end

"""
The blocks of the page that `b` holds, in order, as the kind of each, the
language of a code block, and its first and last line. The front matter and a
line that only names the block above it aren't blocks.
"""
transclusion_blocks(b::Buffer) = begin
  ks, lines = kinds(b), b.lines
  n = length(lines)
  out = Tuple{String,String,Int,Int}[]
  i = front_matter(lines) + 1
  lists = (Kind.bullet, Kind.ordered, Kind.todo)
  # The lines after `i` that go on in the block of line `i`
  run(more) = (t = i; while t < n && more(t + 1); t += 1 end; t)
  while i <= n
    k = ks[i]
    if k.kind == Kind.blank || only_id(lines[i])
      i += 1
      continue
    end
    kind, lang, t = if k.kind in (Kind.fence, Kind.code)
      s, t = codeblock(b, i)
      # A block that shows as what it makes, like a board, isn't code
      (solid(b, i) == (s, t) ? "block" : "code", k.lang, t)
    elseif k.kind == Kind.heading
      ("heading", "", i)
    elseif k.kind == Kind.rule
      ("rule", "", i)
    elseif k.kind == Kind.table
      ("table", "", run(j -> ks[j].kind == Kind.table))
    elseif k.kind in lists
      # A list goes on through the lines that are indented under its items
      ("list", "", run(j -> ks[j].kind in lists || (ks[j].kind == Kind.paragraph && ks[j].level > 0)))
    elseif k.kind == Kind.blockquote
      ("quote", "", run(j -> ks[j].kind == Kind.blockquote))
    elseif pictured(b, i) || transcludes(b, i)
      ("picture", "", i)
    else
      ("paragraph", "", run(j -> ks[j].kind == Kind.paragraph && !only_id(lines[j]) && !pictured(b, j) && !transcludes(b, j)))
    end
    push!(out, (kind, lang, i, t))
    i = t + 1
  end
  out
end

"""
The first and last line of the part of the page in `b` that `part` names, as
what comes after the # of a link like ![[Ideas#Plans]] names one, or nothing
when the page has no such part. "" names the whole page.
"""
transclusion_lines(b::Buffer, part::AbstractString) = begin
  lines, ks = b.lines, kinds(b)
  n = length(lines)
  part = String(strip(part))
  trimmed((s, t)) = (while t > s && isempty(strip(lines[t])); t -= 1 end; s <= t ? (s, t) : nothing)
  isempty(part) && return trimmed((min(front_matter(lines) + 1, n), n))
  found = transclusion_blocks(b)
  if startswith(part, '^')
    # The block whose last line ends with the name, or the block over a line that holds only the name
    name = part[2:end]
    i = findfirst(l -> block_id(l) == name, lines)
    i === nothing && return nothing
    if only_id(lines[i])
      above = findlast(x -> x[4] < i, found)
      return above === nothing ? nothing : found[above][3:4]
    end
    at = findfirst(x -> x[3] <= i <= x[4], found)
    at === nothing && return nothing
    kind, _, s, t = found[at]
    kind == "heading" && return heading_lines(b, i)
    # In a list, the name is on one item, and the part is that item with the lines indented under it
    if kind == "list"
      last = t
      t = i
      while t < last && ks[t+1].level > ks[i].level; t += 1 end
      return (i, t)
    end
    return (s, t)
  end
  # A heading with the name
  slug = heading_slug(part)
  i = findfirst(j -> ks[j].kind == Kind.heading && heading_slug(heading_words(b, j)) == slug, 1:n)
  i === nothing || return heading_lines(b, i)
  # A kind and a number, like table 2
  m = match(r"^(\p{L}[\p{L}\p{N}_+-]*)\s*(\d*)$", part)
  m === nothing && return nothing
  want, nth = lowercase(m[1]), isempty(m[2]) ? 1 : parse(Int, m[2])
  want = get(Dict("paragraphs" => "paragraph", "headings" => "heading", "lists" => "list", "quotes" => "quote",
                  "tables" => "table", "pictures" => "picture", "image" => "picture"), want, want)
  fits = [(s, t) for (kind, lang, s, t) in found if kind == want || (kind in ("code", "block") && lowercase(lang) == want)]
  1 <= nth <= length(fits) ? fits[nth] : nothing
end

"The words of the heading on line `i`, without its #s and without the name of its block"
heading_words(b::Buffer, i::Int) = begin
  text = rest(b.lines[i], kinds(b)[i].prefix)
  block_id(text) === nothing ? text : rstrip(text[1:prevind(text, findlast(==('^'), text))])
end

"The heading on line `i` and the lines under it, up to the next heading that's as big or bigger, without the empty lines at the end"
heading_lines(b::Buffer, i::Int) = begin
  ks, n = kinds(b), length(b.lines)
  t = i
  while t < n && !(ks[t+1].kind == Kind.heading && ks[t+1].level <= ks[i].level); t += 1 end
  while t > i && isempty(strip(b.lines[t])); t -= 1 end
  (i, t)
end

"What line `i` shows when it holds a link to a part of another page. It's the `n`th such line of the page."
transclusion_item(e, i, n) = begin
  v = get!(Transclusion, e.nodes, (:part, e.buf.path, n))
  own!(node!(Document, e, :document), v)
  v.line = i
  show_part!(v, e, String(strip(match(TRANSCLUSION, e.buf.lines[i])[1])))
  Live(v, part_tall(v) + 2LIVE_GAP)
end

"How tall a part of another page is on the page that shows it, with the room over it for its button"
part_tall(v::Transclusion) = isempty(v.note) ? PART_TAB + v.tall : v.tall

"""
Find the part that `target`, like "Ideas#Plans", names, and lay out its lines
for the page of `e`. While the part's editor has the keyboard, the part keeps
the lines that it has, with the lines that typing adds, so a heading that's
being renamed doesn't make it go.
"""
show_part!(v::Transclusion, e, target::String) = begin
  v.target = target
  name, part = occursin('#', target) ? String.(split(target, '#', limit=2)) : (target, "")
  name = String(strip(name))
  path = isempty(name) ? e.buf.path : wiki_path(e, name)
  shown = isempty(name) ? title(path) : name
  note(words) = (v.note = words; v.tall = PART_NOTE_H; v)
  isfile(path) || return note("There's no page called $shown")
  ismarkdown(path) || return note("Only a page of Markdown can show a part of itself here")
  path in host_paths(e) && return note("A page can't show a part of itself")
  length(host_paths(e)) >= DEEPEST_PART && return note("Parts of pages show inside each other too deeply to show $shown here")
  if v.sub === nothing || v.path != path
    v.sub = part_editor(e, path)
    setfield!(v.sub, :parent, v)
  end
  v.path = path
  sub = v.sub
  b = sub.buf
  refresh!(b)   # a change that something else made to the other page's file shows here too
  w = window_of(e)
  typing = w !== nothing && w.focus === sub
  kept = get(sub.nodes, :kept, nothing)
  span = if typing && kept !== nothing
    # Every change while it types is in the part, so its last line moves down as lines are added
    (s, t), had = kept
    s <= length(b.lines) ? (s, clamp(t + length(b.lines) - had, s, length(b.lines))) : nothing
  else
    transclusion_lines(b, part)
  end
  span === nothing && return note("$shown has no $(isempty(part) ? "lines" : part)")
  v.note = ""
  sub.nodes[:span] = span
  sub.nodes[:kept] = (span, length(b.lines))
  # While no part of this page has the other page's caret, every line of the part shows as it reads
  (w !== nothing && w.focus isa Editor && w.focus.buf === b) || (b.reading = true; sub.plain = false)
  follow_host!(sub, e)
  layout!(sub, e.width)
  v.tall = isempty(sub.layout) ? 0px : lowest(sub, sub.layout)
  typing && sub.reveal && keep_shown!(v, e)
  v
end

"An editor of the page at `path`, for a part of it that the page of `e` shows. It edits the lines that the window has open for that page."
part_editor(e, path) = begin
  sub = Editor()
  sub.buffers = e.buffers
  sub.buf = get!(() -> load(path), e.buffers, path)
  sub.nodes[:input] = own!(sub, TextInput())
  sub.nodes[:host] = e
  sub
end

"Give the editor of a part the choices of the editor of the page that shows it: its colours, font, text size and keys"
follow_host!(sub, e) = begin
  for f in (:theme, :look, :font, :weight, :zoom, :code_scale, :code_font, :code_weight, :indent, :wrap, :spelling,
            :glide, :bundle, :rebound, :widest, :size, :autosave)
    setfield!(sub, f, getfield(e, f))
  end
  # Text that was laid out in another font or at another size is laid out again
  key = (e.theme, e.look, e.font, e.weight, e.zoom, e.code_scale, e.code_font, e.code_weight)
  get(sub.nodes, :style, nothing) == key || (sub.nodes[:style] = key; empty!(sub.flows))
  sub
end

"Scroll the page of `e` so that the caret of the part that `v` shows is in the window"
keep_shown!(v::Transclusion, e) = begin
  sub = v.sub
  sub.reveal = false
  b = sub.buf
  it = item(sub, b.caret[1])
  top, high = it.top, it.tall
  if it.content isa Flow
    k, _ = spot(it.content, b.caret[2])
    top, high = it.top + line_top(it.content, k), it.content.lines[k].high
  end
  # The page's own layout isn't done, so the place of the part on it is found after it is
  e.nodes[:show_part] = (v.line, top, high)
end

"Scroll the window's page to the caret of a part of another page that it shows, once the page is laid out"
reveal_part!(e) = begin
  kept = pop!(e.nodes, :show_part, nothing)
  (kept === nothing || isempty(e.layout)) && return
  line, top, high = kept
  at = item(e, line).top + LIVE_GAP + PART_TAB + top
  scroll_into_view!(e.scroll, PAGE_TOP + at - 30px, PAGE_TOP + at + high + 40px)
end

describe(v::Transclusion) = begin
  isempty(v.note) || return Row(width(grow=grow), height(v.tall), Alignment.Center, child_gap=6px,
    Icon("link-45deg", size=14px, color=colours.faint), Box(label(v.note, 13px, color=colours.dim)))
  doc = node!(Document, v.sub, :document)
  w = window_of(v)
  page = Box(width(grow=grow), height(part_tall(v)), Alignment.Start, padding(PART_TAB, 0px, 0px, 0px), doc)
  # The name of the page that the part comes from shows at its top right while the mouse is over it or it has the keyboard
  on = ishovered(v) || (w !== nothing && w.focus === v.sub)
  on || return page
  source = node!(() -> PartSource(of=v), v.sub, :source)
  Stack(width(grow=grow), height(part_tall(v)), Alignment.Start, page,
    Row(width(grow=grow), Alignment.Start, justify=Alignment.End, padding(0px, 6px, 0px, 0px), source))
end

"Draw a line round a part of another page while the mouse is over it or it has the keyboard"
draw(ctx, size, ui::ConcreteRect, v::Transclusion) = begin
  isempty(v.note) || return
  w = window_of(v)
  on = w !== nothing && w.focus === v.sub
  (on || ishovered(v)) || return
  top, high = num(ui.top) + num(PART_TAB), num(ui.height) - num(PART_TAB)
  round_box(ctx, num(ui.left) - RING_OUT, top - num(LIVE_GAP) + 2, num(ui.width) + 2RING_OUT, high + 2num(LIVE_GAP) - 4, 8.0,
            line=on ? tint(colours.accent, 0.75) : colours.line, wide=on ? 1.5 : 1.0)
  # The button that opens the other page sits on the line, so it's drawn again over the line
  for row in ui.children
    row isa ConcreteRect || continue
    for chip in row.children
      chip isa ConcreteRect && chip.from.from isa PartSource && draw(ctx, chip.size, chip)
    end
  end
end

# A click in the part's text is for its editor, which puts the caret there. A click that the part's editor didn't take,
# like one on the room round its text, puts this page's caret on the part as a whole.
onkey(v::Transclusion, ev::KeyPress{Keys.mouse_left}) =
  (w = ev.window; v.sub !== nothing && (w.focus === v.sub || only_held(w, Keys.opt)) ? handled : click_page!(v, ev))
# A key that the part's editor had is done with: it isn't for this page too
onkey(::Transclusion, ::KeyPress) = handled
onmouse(::Transclusion, ::MouseMove) = handled

describe(c::LiveCover) = Box(width(grow=grow), height(c.tall))
onkey(::LiveCover, ::KeyPress{Keys.mouse_left}) = handled
onmouse(::LiveCover, ::MouseMove) = handled
cursor(::LiveCover) = :arrow

"What covers the live block that `it` shows in the part of another page that `e` edits"
live_cover(e, it::Item) = (c = node!(LiveCover, e, (:cover, it.first)); c.tall = it.content.tall - 2LIVE_GAP; c)

describe(s::PartSource) = begin
  v = s.of
  Row(height(18px), padding(7px, 0px), child_gap=4px, radius(9px), Alignment.Center,
      background(ishovered(s) ? colours.active : colours.bg), border(1px, :solid, colours.line),
    Box(label(splitext(basename(v.path))[1], 11px, color=colours.dim)), Icon("box-arrow-up-right", size=10px, color=colours.dim))
end
cursor(::PartSource) = :hand
onkey(s::PartSource, ::KeyPress{Keys.mouse_left}) = (open_part!(s.of); handled)
onmouse(::PartSource, ::MouseMove) = handled

"Show the page that `v` shows a part of, with the part's first line near the top of the window"
open_part!(v::Transclusion) = begin
  top = top_editor(editor(v))
  s = v.sub === nothing ? 1 : get(v.sub.nodes, :span, (1, 1))[1]
  open!(top, v.path)
  show_line!(top, s)
  top.nodes[:hold] = (s, 24px - PAGE_TOP)
  top
end

"""
Give the keyboard to the part that `v` shows, with its caret at the start of
the part's first line, or at `at` in the other page's lines.
"""
enter_shown!(v::Transclusion, at=nothing) = begin
  sub = v.sub
  (sub === nothing || !isempty(v.note)) && return nothing
  b = sub.buf
  s, t = sub.nodes[:span]
  b.reading = false
  b.caret = b.anchor = settle(b, something(at, (s, 0)), 1)
  confine!(sub)
  focus(sub)
  touch!(sub)
  sub
end

"""
Give the keyboard back to the page that shows the part that `e` edits. Its
caret goes onto the part as a whole, or with `by` of -1 or 1 on to the line
over the part or under it.
"""
leave_part!(e, by::Int=0) = begin
  host = hosted(e)
  v = getfield(e, :parent)
  e.buf.reading = true
  e.plain = false
  hb = host.buf
  hb.caret = hb.anchor = (v.line, 0)
  focus(host)
  touch!(host)
  w = window_of(host)
  by == 0 || w === nothing || run!(host, w, by < 0 ? :up : :down)
  host
end

"Commands for the window that leave the keyboard in the part of another page that has it"
const KEEP_PART = (:save, :bigger, :smaller, :usual_size, :inspector, :sidebar, :hidden_files, :settings, :commands)

"""
What a key does in a part of another page before the part's editor does what
it does with a key. True when the key is done with. A command for the window
runs in the window's own page. ⌘E shows the part's lines as they're written.
"""
part_key!(e, w, K, command, select) = begin
  b = e.buf
  s, t = e.nodes[:span]
  kind = command === nothing ? :none : COMMANDS[command].kind
  K == Keys.escape && unmodified(w) && return (leave_part!(e); true)
  if command == :plain
    e.plain = !e.plain
    return true
  end
  if kind == :window || command in (:find, :find_next, :find_last)
    if !(command in KEEP_PART)
      f = e
      while hosted(f) !== nothing; f = leave_part!(f) end
    end
    run!(top_editor(e), w, command, select)
    return true
  end
  # ↑ on the first line and ↓ on the last go on to the page that shows the part
  if command in (:up, :down) && !select && isempty(others(b))
    by = command == :up ? -1 : 1
    p = vertical(e, by)
    (p[1] < s || p[1] > t || p == b.caret) && return (leave_part!(e, by); true)
  end
  # A key that would join the part's first line to the line over it, or its last line to the line under it, does nothing
  if !selecting(b) && ((command in (:erase_back, :erase_word_back, :erase_line_start) && b.caret == (s, 0)) ||
                       (command in (:erase, :erase_word) && b.caret == line_end(b, t)))
    return true
  end
  # A live block in the part is only shown: the caret can be on it as a whole, and nothing changes it
  picked(b) !== nothing && (K == Keys.enter || kind in (:edit, :type))
end

"""
Copy a link that shows the block at the caret in another page, like
![[Ideas#^prices]]. A block without a name gets one from its first words: at
the end of its last line, or on a line under a list, a table or a code block.
"""
copy_link_to_block!(e) = begin
  link = block_link!(e)
  link === nothing && return nothing
  clipboard(link)
  e.nodes[:result] = ("Copied $link", time())
  redraw_in!(e, 0)
  link
end
works_here(e, ::Val{:copy_link_to_block}) = e.buf.view == :markdown && !readonly(e.buf)

"The link that shows the block at the caret in another page, as `copy_link_to_block!` makes it, or nothing. The block gets a name if it has none."
block_link!(e) = begin
  b = e.buf
  (b.view == :markdown && !readonly(b) && !b.fixed && isfile(b.path)) || return nothing
  i = b.caret[1]
  found = transclusion_blocks(b)
  at = findfirst(x -> x[3] <= i <= x[4], found)
  at === nothing && return nothing
  _, _, s, t = found[at]
  # A heading's link shows the lines under it too
  kinds(b)[s].kind == Kind.heading && ((s, t) = heading_lines(b, s))
  name = node_name!(b, s, t)
  touch!(e)
  "![[$(title(b.path))#^$name]]"
end

"""
The block of `b` that lines `s` to `t` are the whole of, or nothing: a block
of the page, a heading with the lines under it, or an item of a list with the
lines indented under it. The front matter isn't one, and nor is a line that
already shows a part of another page.
"""
whole_node(b::Buffer, s::Int, t::Int) = begin
  (b.view == :markdown && front_matter(b.lines) < s <= t <= length(b.lines)) || return nothing
  ks = kinds(b)
  ks[s].kind == Kind.heading && return heading_lines(b, s) == (s, t) ? (s, t) : nothing
  found = transclusion_blocks(b)
  at = findfirst(x -> x[3] <= s <= x[4], found)
  at === nothing && return nothing
  kind, _, from, to = found[at]
  (kind == "picture" && transcludes(b, s)) && return nothing
  from == s && to == t && return (s, t)
  kind == "list" || return nothing
  last = s
  while last < to && ks[last+1].level > ks[s].level; last += 1 end
  last == t ? (s, t) : nothing
end

"""
The name of the block of `b` from line `s` to line `t`, which a link from
another page uses, like `prices` in ![[costs#^prices]]. A block without one
gets one from the first words of its first line: at the end of the line of a heading or an item
of a list, at the end of a paragraph's last line, or on a line under anything
else. The caret stays where it was in the text.
"""
node_name!(b::Buffer, s::Int, t::Int) = begin
  ks = kinds(b)
  found = transclusion_blocks(b)
  at = findfirst(x -> x[3] == s, found)
  kind, lang = at === nothing ? ("item", "") : found[at][1:2]
  ks[s].kind == Kind.heading && (kind = "heading")
  kind == "list" && found[at][4] != t && (kind = "item")
  ends = kind in ("heading", "item") ? s : kind == "paragraph" ? t : 0
  name = ends > 0 ? block_id(b.lines[ends]) : nothing
  # A name on a line under the block names it too, but not a heading's lines or an item's: that's the name of their last block
  under = kind in ("heading", "item") || t == length(b.lines) || !only_id(b.lines[t+1]) ? nothing : block_id(b.lines[t+1])
  name = something(name, under, Some(nothing))
  name === nothing || return name
  words = kind in ("code", "block") ? [isempty(lang) ? "code" : lang] :
          kind in ("table", "picture") ? [kind] :
          first(split(lowercase(replace(b.lines[s], r"[^\p{L}\p{N}\s]" => " "))), 4)
  words = first(filter(w -> !isempty(w) && w != "x", String.(words)), 3)
  base = isempty(words) ? kind : join(words, '-')
  taken = Set(something(block_id(l), "") for l in b.lines)
  name, k = base, 1
  while name in taken; k += 1; name = "$base-$k" end
  caret, anchor = b.caret, b.anchor
  if ends > 0
    edit!(b, line_end(b, ends), line_end(b, ends), " ^" * name)
    b.caret, b.anchor = caret, anchor
  else
    edit!(b, line_end(b, t), line_end(b, t), "\n^" * name)
    moved(p) = p[1] > t ? (p[1] + 1, p[2]) : p
    b.caret, b.anchor = moved(caret), moved(anchor)
  end
  name
end
