# The cards that show while ⌘ is held: what a name is, and the start of the page that a link goes to

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" WrapMode describe window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered show_tooltip! hide_tooltip! popup!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./markdown" Kind classify words front_matter wikitarget
@use "./highlight" left_open
@use "./sheet" shown nudged ident
@use "./spreadsheet" moved
@use "./contact" => Contacts
@use "github.com/jkroso/UI.jl/Interface/draw" popups
@use Colors: RGBA
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
@use "./sketch_view" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./live_view" exports...
@use "./timelog_view" exports...
@use "./contact_view" exports...
@use "./code_names" exports...
@use "./code_nav" exports...
@use "./page_extras" exports...
@use "./agent/kinds" exports...
@use "./agent/ask" exports...
@use "./drag_number" exports...
@use "./givers" exports...
@use "./page_mouse" exports...

export PEEK_LINES, PEEK_PAGE_HIGH, PEEK_PAGE_W, PEEK_WAIT, PagePeek, inline_codes, linked_page,
       page_peek, peek_card, peek_from, peek_lines, peek_page_lines, peeks!, scrub_to!, Scrubbing, scrubbing

# --- a card of what a name is ---
#
# While ⌘ is held, a name that has a place where it's defined is marked. When
# the mouse rests on it for a moment, a card under it shows that place: the
# name's documentation and the first lines of its code, from the page or from
# another file. A link's card has where it goes. The card goes when the mouse
# moves, and comes again when the mouse rests.
#
# No card shows until the mouse moves after ⌘ goes down. ⌘ is often pressed
# for a key like ⌘S, and what is under a mouse that didn't move is chance.

const PEEK_WAIT = 0.6   # seconds that the mouse rests on a name before its card shows
const PEEK_LINES = 8    # the most lines of code that a card shows

"""
The lines of `lines` that a card shows for the definition on line `at`: its
documentation above it, and the lines of its code, as many as `most`, up to
the line `last`.
"""
peek_lines(lines, at::Int, last::Int, most=PEEK_LINES) = begin
  from = peek_from(lines, at)
  stop = min(last, at + most - 1)
  while stop > at && isempty(strip(lines[stop])); stop -= 1 end
  [length(l) > 100 ? first(l, 99) * "…" : l for l in lines[from:stop]]
end

"The first line that a card shows for the definition on line `at` of `lines`: the first of the documentation above it that shows"
peek_from(lines, at::Int) = begin
  from = at
  above = at > 1 ? strip(lines[at-1]) : ""
  if startswith(above, '"') && endswith(above, '"')
    # One line of documentation, like "Words" or """Words"""
    from = at - 1
    # Documentation of several lines ends with three quotes, and starts on the line that starts with three quotes
    if endswith(above, "\"\"\"") && !(startswith(above, "\"\"\"") && length(above) >= 6)
      from = something(findprev(l -> startswith(strip(l), "\"\"\""), lines, at - 2), at - 1)
    end
  elseif endswith(above, "\"\"\"")
    from = something(findprev(l -> startswith(strip(l), "\"\"\""), lines, at - 2), at)
  end
  max(from, at - 6)   # long documentation shows its last lines, next to the code
end

"""
What the card of the words `found`, which `cmd_words` gave, shows: where a
link goes, or where a name is defined, with the lines there. It's nothing
when there's nothing to show.
"""
peek_card(e, found) = begin
  line, lo, hi = found
  b = e.buf
  it = item(e, line)
  segs = it.content isa Flow ? [s for vl in it.content.lines for s in vl.segs] : []
  k = findfirst(s -> s.col <= lo < s.col + s.n && !isempty(s.link), segs)
  # Each line has a set height: a Text alone in a box can be less tall than its line, and the lines then overlap
  said(text; family=SANS, color=TIP_INK) = Box(height(17px), Text(text, size=12px, family=family, color=color, wrap=WrapMode.none))
  faint = RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)
  if k !== nothing
    # A link to a page shows the start of the page, unless the setting is off. Any other link says where it goes.
    page = e.peeks ? linked_page(e, segs[k].link) : nothing
    card = page === nothing ? nothing : page_peek(e, page...)
    return something(card, Box(padding(10px, 7px), said(segs[k].link)))
  end
  place = Base.invokelatest(definition, e, (line, lo))
  place === nothing && return nothing
  # `open` says if the first line that shows is inside a docstring, when long documentation shows only its last lines
  head, lines, lang, open = if place isa Method
    spot = code_place(place)
    spot === nothing && return nothing
    file, at = spot
    _, all, starts = file_parts(file)
    at = settled_line(place, all, at)
    j = max(1, searchsortedlast(starts, at))
    last = j == length(starts) ? length(all) : starts[j+1] - 1
    open = foldl((q, l) -> left_open(l, "julia", q), view(all, 1:peek_from(all, at)-1), init='\0')
    ("$(basename(file)):$at", peek_lines(all, at, last), "julia", open)
  else
    at = place[1]
    # A name of a function, like a variable in it, is one line. A name of the whole page shows its code.
    local_name = any(m -> m.at == place && m.span !== nothing, page_bounds(e))
    j = local_name ? nothing : findfirst(c -> c.first <= at <= c.last, code_blocks(e))
    last = local_name ? at : j === nothing ? at + PEEK_LINES - 1 : code_blocks(e)[j].last
    l = kinds(b)[at]
    ("line $at", peek_lines(b.lines, at, min(last, length(b.lines))), l.kind == Kind.code ? shared_lang(l.lang) : "julia",
     string_opens(b)[peek_from(b.lines, at)])
  end
  # The code has the colours that it has in the page
  Box(padding(10px, 8px), Column(Alignment.Start, child_gap=1px, said(head, color=faint), tip_code(lines, lang; open)...))
end

"""
Show the card of the words `found` when the mouse has rested on them for a
moment while ⌘ is held, and take it away when the mouse is on other words.
The mouse must move after ⌘ goes down before a card shows.
"""
peek!(e, w, found) = begin
  # Where the mouse was when ⌘ went down, or :moved once it has moved from there
  kept = cmd_card(e)
  kept.mouse === nothing && (kept.mouse = w.mouse)
  still = kept.mouse
  still === :moved || w.mouse == still || (kept.mouse = still = :moved)
  was = kept.peek
  if found === nothing || was === nothing || was.words != found
    was === nothing || !was.shown || hide_tooltip!(w)
    kept.peek = found === nothing ? nothing : (words=found, since=time(), shown=false)
    return
  end
  # A mouse move took the card away. It comes again when the mouse rests.
  if was.shown
    any(p -> p.key == :tooltip, popups(w)) || (kept.peek = (words=found, since=time(), shown=false))
    return
  end
  # The moment of rest starts when the mouse first moves
  still === :moved || (kept.peek = (words=found, since=time(), shown=false); return)
  time() - was.since < PEEK_WAIT && return
  card = peek_card(e, found)
  kept.peek = (words=found, since=was.since, shown=true)
  card === nothing && return
  line, lo, hi = found
  it = item(e, line)
  f = it.content::Flow
  k, x = spot(f, lo)
  _, x2 = spot(f, hi)
  top = e.origin[2] + it.top + line_top(f, k)
  # The start of a page is a card of the page's own colours, and not a dark box. It goes as a tooltip does, when the mouse moves.
  card isa PagePeek && return popup!(w, card.layout, anchor=(e.origin[1] + x, top, max(x2 - x, 4px), f.lines[k].high),
                                     placement=:below, gap=4px, key=:tooltip, input=false)
  show_tooltip!(w, card, e.origin[1] + x, top, max(x2 - x, 4px), f.lines[k].high; placement=:bottom, gap=4px)
end

# --- the start of a page in a link's card ---
#
# While ⌘ is held, the card of a link to a page shows the start of that page,
# as the page reads, so you can read it without leaving your own page. A link
# to a heading, like [[Ideas#Plans]], shows the page from that heading to the
# next heading that's as big. A page that's open shows as it is now, with what
# isn't saved yet. The setting "Show a page when I hold ⌘ over its link" turns
# this off, and the card then says where the link goes, as for any other link.

const PEEK_PAGE_W = 440px      # how wide the card of a page is
const PEEK_PAGE_HIGH = 280px   # the most of the page that shows. A longer page is cut there.

"The start of a page, for the card of a link to it: what shows, kept apart from other cards so that it isn't put in a dark box"
struct PagePeek
  layout::Any
  flows::Vector{Flow}   # the lines of the page that it shows, laid out
end

"""
The page that the link `url` goes to, and the heading of the page that it
names, or "" for none. It's nothing for a link that doesn't go to a Markdown
page that's there: a web address, a footnote, a file of another kind, or a
wiki link to a page that isn't made yet.
"""
linked_page(e, url::AbstractString) = begin
  startswith(url, '^') && return nothing   # a footnote
  in_browser(e.buf.path) && return nothing   # a page from a web server links to no page of the Mac
  target = wikitarget(url)
  path, heading = if target !== nothing
    name, mark = occursin('#', target) ? String.(split(target, '#', limit=2)) : (String(target), "")
    name = String(strip(name))
    (isempty(name) ? e.buf.path : wiki_path(e, name), mark)
  else
    # A link to anything but a file, like an https: or a mailto: address, isn't a page
    to = linked_file(e, url)
    to === nothing && return nothing
    (to[1], unescaped(to[2]))
  end
  (ismarkdown(path) && (isfile(path) || path == e.buf.path && !isempty(e.buf.lines))) || return nothing
  (path, String(strip(heading)))
end

"""
The lines of the page at `path`, their kinds, and the lines of them that the
card of a link shows: from the heading `heading` to the next heading that's as
big, or from the top, after the page's front matter. A page that's open gives
its lines as they are now. It's nothing when the file can't be read as text.
"""
peek_page_lines(e, path, heading) = begin
  b = path == e.buf.path ? e.buf : get(e.buffers, path, nothing)
  lines = if b !== nothing
    b.lines
  else
    found = reading(path, tidy=false)
    found === nothing && return nothing
    found[1]
  end
  isempty(lines) && return nothing
  ks = classify(lines)
  from, to = front_matter(lines) + 1, length(lines)
  if !isempty(heading)
    slug = heading_slug(heading)
    i = findfirst(i -> ks[i].kind == Kind.heading && heading_slug(rest(lines[i], ks[i].prefix)) == slug, eachindex(ks))
    if i !== nothing
      from = i
      next = findnext(j -> ks[j].kind == Kind.heading && ks[j].level <= ks[i].level, eachindex(ks), i + 1)
      next === nothing || (to = next - 1)
    end
  end
  while from < to && isempty(strip(lines[from])); from += 1 end
  while to > from && isempty(strip(lines[to])); to -= 1 end
  (lines, ks, from:to)
end

"""
The card of a link to the page at `path`: the page's name, with the heading
`heading` after it, over the start of the page as it reads, a little smaller
than the page's own text. Only as many lines are laid out as the card shows.
It's nothing when the page has nothing to show.
"""
page_peek(e, path, heading) = begin
  found = peek_page_lines(e, path, heading)
  found === nothing && return nothing
  lines, ks, shown = found
  wide = PEEK_PAGE_W - 2 * 6px - 2 * 14px   # the card has 6px of room on each side, and the page 14px inside that
  zoom = e.zoom
  e.zoom = zoom * PAGE_ZOOM
  flows = Flow[]
  # -1 says that the line isn't one of the document's, so its inline code isn't run
  try
    total = 0px
    for i in shown
      push!(flows, laid(e, lines[i], ks[i], false, -1, wide))
      total += tall(flows[end])
      total > PEEK_PAGE_HIGH && break
    end
  finally
    e.zoom = zoom
  end
  isempty(flows) && return nothing
  total = sum(tall, flows)
  name = splitext(basename(path))[1]
  title = isempty(heading) ? name : "$name  ›  $heading"
  PagePeek(Column(fixed(PEEK_PAGE_W), Alignment.Start, padding(6px), radius(8px), background(colours.block),
                  border(1px, :solid, colours.line), lifted, child_gap=4px,
    Row(width(grow=grow), height(22px), padding(8px, 0px), child_gap=6px, clip=true,
      Icon("file-earmark-text", size=12px, color=colours.dim), label(title, 12px, color=colours.dim)),
    Box(width(grow=grow), height(min(total, PEEK_PAGE_HIGH) + 2TEXT_PAD), padding(14px, 0px), radius(5px), background(colours.bg), clip=true,
      Column(width(grow=grow), Alignment.Start, spacer(TEXT_PAD),
        [describe(e, Item(0, 0, 0px, tall(f), f), f) for f in flows]...))), flows)
end

"Turn on or off whether the card of a link to a page shows the start of the page, while ⌘ is held"
peeks!(e, on::Bool) = (e.peeks = on; save_settings!(e); rerun!(e, :peeks); e)
add_command!(peeks!, title="Turn on or off showing a page when you hold ⌘ over its link")

"Make the agent called `name` the one that Ladder starts for a change or a question: see \"the agents that Ladder can start\""
preferred_agent!(e, name::String) = begin
  any(k -> k.name == name, AGENT_KINDS) || error("Ladder can't start an agent called $name.")
  e.ai = name
  save_settings!(e)
  rerun!(e, :ai)
  redraw_windows!()   # the logo on the line round a thing shows the new agent
  e
end

"The number that the mouse holds while a drag changes it, which the window keeps until the mouse lets go: see `scrub!`"
@def mutable struct Scrubbing
  # The number's line and where it starts and ends there, where the mouse took hold of it, its text then,
  # how many steps the drag has changed it by, and whether the mouse has moved
  held::Union{Nothing,NamedTuple{(:line, :lo, :hi, :x, :text, :steps, :moved)}} = nothing
end

"True while the mouse holds a number of the page of `e`"
scrubbing(e) = state_of(e, Scrubbing).held !== nothing

"Take hold of the number at `found`, which `scrub_at` gave, with the mouse at `pos`"
scrub!(e, found, pos) = begin
  i, lo, hi = found
  b = e.buf
  state_of(e, Scrubbing).held = (line=i, lo=lo, hi=hi, x=num(pos[1]), text=rest(head(b.lines[i], hi), lo), steps=0, moved=false)
  b.typed = 0.0   # the drag is taken back by itself, and not with what was typed before it
  e.popup = :none
  e.clicked = (time(), (i, 0), 0)
  took(e) || focus(e)
  e
end

"Give the number that the mouse holds the value for where the mouse is now, and write it into its line. The caret stays with its text."
scrub_to!(e, pos) = begin
  s = something(state_of(e, Scrubbing).held)
  b = e.buf
  steps = scrub_steps(num(pos[1]) - s.x) * (only_held(e, Keys.shft) ? 10 : 1)
  (steps == s.steps || !(1 <= s.line <= length(b.lines))) && return e
  new = nudged(s.text, steps)
  caret, anchor = b.caret, b.anchor
  edit!(b, (s.line, s.lo), (s.line, s.hi), new, typing=true)
  by = length(new) - (s.hi - s.lo)
  kept(p) = p[1] == s.line && p[2] >= s.hi ? (p[1], p[2] + by) : p
  b.caret, b.anchor = kept(caret), kept(anchor)
  state_of(e, Scrubbing).held = (; s..., hi=s.lo + length(new), steps, moved=true)
  e
end

"What happens in each frame to a number that the mouse holds: when the mouse lets go, the drag ends. A press that never moved was a click, and puts the caret there."
scrub_tick!(e) = begin
  s = state_of(e, Scrubbing).held
  (s === nothing || held(e, Keys.mouse_left)) && return e
  state_of(e, Scrubbing).held = nothing
  b = e.buf
  b.typed = 0.0
  w = window_of(e)
  if !s.moved && w !== nothing
    b.caret = b.anchor = settle(b, locate(e, w.mouse))
    touch!(e)
  end
  e
end

"The code of each sum in a line of text of the page, in the order of the page"
inline_codes(e, b::Buffer) = get!(e.flows, (:inline_codes, b.path, b.version)) do
  String[m[1] for i in inline_lines(e, b) for m in eachmatch(r"!`([^`]+)`", b.lines[i])]
end

"""
Run again the sums in a line of text that come after a sum that changed, so
that a sum which uses a name follows the sum that gives the name its value.
What a sum made is forgotten, and the sum runs when its line is next laid
out. A sum that made a node, like a switch, keeps its node, so the switch
stays on. A node made from names that the page's sums and sheets give, like
!`ProgressBar(value=done / jobs)`, is made again, so it follows the numbers.
`also` is what else the sums read, as `inline_given!` gives it: when that
changes, every sum runs again.
"""
inline_tick!(e) = begin
  b = e.buf
  b.view == :markdown || return e
  key = (:inline_seen, b.path)
  seen = get(e.nodes, key, nothing)
  seen !== nothing && seen[1] == b.version && return e
  codes = inline_codes(e, b)
  also = inline_given!(e)
  e.nodes[key] = (b.version, codes, also)
  seen === nothing && return e
  also == seen[3] || (CODE_RUNS[] += 1)   # a row of a sheet has a new value, so the page's `check` blocks run again
  (codes == seen[2] && also == seen[3]) && return e
  from = also == seen[3] ? something(findfirst(i -> i > length(seen[2]) || seen[2][i] != codes[i], eachindex(codes)), length(codes) + 1) : 1
  counts = Dict{String,Int}()
  # The names that the page's sums and sheets give
  names = Set{Symbol}(Iterators.flatten((filter(!isnothing, sum_name.(codes)), (Symbol(ident(name)) for (name, _) in page_given(e)))))
  for (i, code) in enumerate(codes)
    n = counts[code] = get(counts, code, 0) + 1
    i >= from || continue
    was = get(e.nodes, (:inline, b.path, code, n), nothing)
    (was isa Tuple || (was isa Shown && follows(code, names))) && delete!(e.nodes, (:inline, b.path, code, n))
  end
  # A sum that the page no longer has is forgotten too, so that it runs if it comes back
  for k in collect(keys(e.nodes))
    (k isa Tuple && length(k) == 4 && k[1] == :inline && k[2] == b.path && e.nodes[k] isa Tuple) || continue
    get(counts, k[3], 0) < k[4] && delete!(e.nodes, k)
  end
  e
end

pointed(v::ContactView) = begin
  # A to-do item under a contact's details is the item, and not the contact
  for r in values(v.parts)
    r isa ContactWork && ishovered(r) || continue
    m = work_of(r)
    return m === nothing ? nothing : m.text
  end
  for card in values(v.parts)
    card isa ContactCard && ishovered(card) || continue
    c = contact_of(v, card.k)
    return c === nothing || isempty(Contacts.title(c)) ? nothing : Contacts.title(c)
  end
  nothing
end
