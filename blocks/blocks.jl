# A fenced code block that Ladder shows as something of its own, like a chart
# or a map, is a type that `BLOCKS` names by the block's language. This file has
# the functions that the page asks of a block, with what each does when a type
# doesn't say. A block's own file gives its type the methods that differ.
#
#     BLOCKS[ASK] = AskView        # the block of the language `ask`
#     block_name(::Type{AskView}) = "Question"

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "../html" html
@use "../markdown" Kind words
@use "./sheet" parts
@use Colors: RGBA
@use "../host" editor
@use "../folder_page" own! node!
@use "../look" exports...
@use "../flow" exports...
@use "../buffer" exports...
@use "../editor_type" exports...
@use "../faces" exports...
@use "../rich" exports...

export act!, keyboard_part, reread!, BlockKind, BLOCKS, block_name, block_icon, block_make, block_insert,
       block_is_code, block_safe, block_outline_inside, block_outline, block_table_kind, block_tables!,
       block_names, block_places, block_lines, block_view, prepare_block!, measure_block!, block_item,
       block_layout, block_place, block_html, write_block!, block_tick!, before_save!, blocks_tick!,
       block_part!, part!, BlockButton, PlanButton, block_button!, block_look, block_bar, block_note,
       BLOCK_ROUND, inner_round, css_colour, can_fill, filling, unfill!, full_block, before_fill!, fill_focus, full!, named

# Each kind of block decides these for its own parts, so this file only names them.

"Do what the button `action` of the block `v` says, in the window `w`"
function act! end

"The part of the block `v` that takes the keys, while the block fills the window"
function keyboard_part end

"Read the block `v` again from its lines `lines`, when they changed"
function reread! end

# --- blocks ------------------------------------------------------------------------------
#
# Every built-in fenced code block that Ladder shows as something of its own is
# a type (its view type, or a tag type for stateless/grid blocks), mapped from
# its fence language in `BLOCKS`. Behaviour is defined by methods on that type
# (and on view instances), matching Ladder's folder dispatch (`AbstractDirectory`):
# `block_name`, `block_icon`, `block_insert`, `block_is_whole`, `block_is_code`,
# `block_safe`, `block_outline`, `block_layout`, `block_html`,
# `block_tables!`, `block_table_kind`, `block_names`, `block_places`, `reread!`,
# `block_tick!`, `before_save!`, `full!`.
#
# A view-backed block has these fields: `n`, its place among the page's blocks
# in its language, `first` and `last`, the lines of its block, `lines`, the lines
# that it was last read from, and `parts`, its buttons and the rest that's kept
# between frames. `reread!(view, lines)` reads it again.

"Adapter for extensions that register a block as `BLOCKS[lang] = BlockKind(name, icon, view, html)`"
struct BlockKind
  name::String   # what the sidebar calls it
  icon::String   # and the icon beside that name
  view::Any      # the type or constructor of its view
  html::Any      # `html(e, view)` is the block as HTML, or nothing to show its lines
end

"The languages whose blocks show as a component or built-in view, mapped to their block type"
const BLOCKS = Dict{String,Any}()

# --- block dispatch protocol (defaults; each block type overrides only where it differs) ---

block_name(T::Type) = string(nameof(T))
block_name(k::BlockKind) = k.name

block_icon(T::Type) = "puzzle"
block_icon(k::BlockKind) = k.icon

block_make(T::Type, n::Int) = T(n=n)
block_make(k::BlockKind, n::Int) = k.view(n=n)

"The Insert menu entry `(menu_name, lines, caret)` for a block type, or nothing"
block_insert(T) = nothing
block_insert(lang::AbstractString) = block_insert(BLOCKS[lang])

"True when the closed block of type `T` with body `code` is stepped over as a whole unit by the caret"
block_is_whole(T, code::AbstractString) = true
block_is_whole(b::Buffer, lang::AbstractString, s::Int, t::Int) =
  haskey(BLOCKS, lang) && block_is_whole(BLOCKS[lang], join(b.lines[s+1:t-1], "\n"))

"True when the block's lines are Julia code that participates in name completion"
block_is_code(T) = false

"True when the block is shown on foreign pages without trust"
block_safe(T) = false

"True when clicking the block's sidebar outline entry puts the caret inside (`i + 1`) instead of after (`close + 1`)"
block_outline_inside(T) = false

"The sidebar outline entry for a block of type `T` opening at line `i` and closing at `close`, or nothing"
block_outline(T, lines::Vector{String}, i::Int, close::Int) =
  Entry(i, 7, block_name(T), block_icon(T), min((block_outline_inside(T) ? i : close) + 1, length(lines)))

"What a form/source calls a table contributed by a block of type `T`"
block_table_kind(T) = "block"

"Contribute any table(s) from a closed block of type `T` (lines `i`..`t`) to `out`"
block_tables!(T, e, i::Int, t::Int, under::AbstractString, out) = nothing

"Named values contributed by a block of type `T` for sheets and inline sums"
block_names(T, lines) = Tuple{String,String}[]

"Map places contributed by a block of type `T`"
block_places(T, lines) = @NamedTuple{name::String, place::String, line::Int}[]

"The first and the last line of the `n`th code block of `b` in the language `lang`, or nothing"
block_lines(b::Buffer, lang::String, n::Int) = begin
  ks = kinds(b)
  seen = 0
  for i in eachindex(ks)
    (ks[i].kind == Kind.fence && ks[i].level == 0 && ks[i].lang == lang) || continue
    (seen += 1) == n || continue
    t = codeblock(b, i)[2]
    return t > i && ks[t].kind == Kind.fence && ks[t].level == 1 ? (i, t) : nothing
  end
  nothing
end

"The view of the `n`th block of the page that shows in the language `lang`"
block_view(e, lang, n) = begin
  v = get!(() -> block_make(BLOCKS[lang], n), e.nodes, (:block, lang, e.buf.path, n))
  own!(node!(Document, e, :document), v)
  v
end

"Prepare a block view `v` after `reread!` and before measuring its height in `block_item`"
prepare_block!(e, v) = v

"Measure the height of a block view `v` for page layout"
measure_block!(e, v) = begin
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(v)), (e.width, 9999px))
  can_fill(v) && (v.tall = concrete.height)
  concrete.height
end

"What the block in the language `lang` from line `i` to line `t` shows. `n` is its place among the page's blocks in that language."
block_item(e, lang, i, t, n) = begin
  v = block_view(e, lang, n)
  v.first, v.last = i, t
  reread!(v, e.buf.lines[i+1:t-1])
  prepare_block!(e, v)
  # A block that fills the window is drawn over the page, and its room in the page stays empty
  filling(v) && return Live(Box(width(grow=grow), height(v.tall)), v.tall + 2LIVE_GAP)
  Live(v, measure_block!(e, v) + 2LIVE_GAP)
end

"Lay out the block of type `T` in `lang` opening on line `i` (the `n`th in `lang` on the page). Returns `(last_line, content)` or nothing."
block_layout(T, e, lang::AbstractString, i::Int, n::Int) = begin
  b = e.buf
  ks = kinds(b)
  t = codeblock(b, i)[2]
  (!incode(b, i) && t > i && ks[t].kind == Kind.fence && ks[t].level == 1) || return nothing
  (t, block_item(e, lang, i, t, n))
end

"The place of the block that opens on line `s` among the blocks of `b` in the language `lang`"
block_place(b::Buffer, lang, s) = count(i -> (k = kinds(b)[i]; k.kind == Kind.fence && k.level == 0 && k.lang == lang), 1:s)

"A view-backed block as HTML, or nothing to show its lines"
block_html(e, v) = nothing

"The closed block of type `T` in `lang` from line `s` to line `t` as HTML, or nothing to show its lines"
block_html(T, e, lang::AbstractString, s::Int, t::Int) = begin
  v = block_view(e, lang, block_place(e.buf, lang, s))
  v.first, v.last = s, t
  reread!(v, e.buf.lines[s+1:t-1])
  block_html(e, v)
end
block_html(k::BlockKind, e, lang::AbstractString, s::Int, t::Int) = begin
  k.html === nothing && return nothing
  v = block_view(e, lang, block_place(e.buf, lang, s))
  v.first, v.last = s, t
  reread!(v, e.buf.lines[s+1:t-1])
  k.html(e, v)
end

"The block in the language `lang` that opens on line `s`, as HTML, or nothing to show its lines"
block_html(e, lang::AbstractString, s::Int, t::Int) = begin
  haskey(BLOCKS, lang) || return nothing
  ks = kinds(e.buf)
  t > s && ks[t].kind == Kind.fence && ks[t].level == 1 || return nothing
  block_html(BLOCKS[lang], e, lang, s, t)
end

"""
Write `new` as the lines of the block of `v`, a view in the language `lang`.
The caret stays where it was in the text, and ⌘Z takes the change back. With
`typing`, changes that come one soon after another are taken back together.
"""
write_block!(v, lang, new::Vector{String}; typing=false, reread::Bool=true) = begin
  e = editor(v)
  b = e.buf
  readonly(b) && return v
  span = block_lines(b, lang, v.n)
  span === nothing && return v
  i, t = span
  v.first, v.last = i, t
  old = b.lines[i+1:t-1]
  new == old && return (reread ? reread!(v, new) : (v.lines = new; v))
  caret, anchor = b.caret, b.anchor
  edit!(b, line_end(b, i), line_end(b, t - 1), isempty(new) ? "" : "\n" * join(new, "\n"); typing)
  by = length(new) - length(old)
  moved(p) = p[1] >= t ? (p[1] + by, p[2]) : p[1] > i ? (i, 0) : p
  b.caret, b.anchor = moved(caret), moved(anchor)
  v.last += by
  reread ? reread!(v, new) : (v.lines = new; v)
end

"What happens to a block's view in each frame, before the page is laid out. Most kinds of block need nothing."
block_tick!(v) = v

"What a block's view does right before its page is saved. Most kinds of block need nothing."
before_save!(v) = v

"Do what each block of the page that shows needs in this frame"
blocks_tick!(e) = for (key, node) in collect(e.nodes)
  (key isa Tuple && length(key) == 4 && key[1] == :block && key[3] == e.buf.path) || continue
  block_tick!(node)
  filling(node) || continue
  # A block whose lines have gone goes back to the page. Under one that fills the window, the page stays where it was.
  block_lines(e.buf, key[2], node.n) === nothing ? (node.full = false) : (e.scroll.offset = node.pinned)
end

"A part of the block view `v` that's kept between frames"
block_part!(make, v, key) = begin
  node = get!(make, v.parts, key)
  node.parent === nothing && setfield!(node, :parent, v)
  node
end
part!(make, v, key) = block_part!(make, v, key)

"A button of a block. A click does `act!(view, action, window)`."
@def mutable struct BlockButton <: SemanticUI
  of::Any = nothing
  action::Any = :none
  icon::String = ""
  words::String = ""
  tip::String = ""
  on::Bool = false                            # it's lit, like the kind of chart that shows now
  off::Bool = false                           # it does nothing now, and shows that
  bold::Bool = false                          # it's filled with colour, like the one button that a question waits for
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
end
const PlanButton = BlockButton

"The button of the block view `v` that's kept under `key`, with what it does and shows now"
block_button!(v, key, action; icon="", words="", tip="", on=false, off=false, bold=false) = begin
  b = block_part!(() -> BlockButton(of=v), v, (:button, key))
  b.action, b.icon, b.words, b.tip, b.on, b.off, b.bold = action, icon, words, tip, on, off, bold
  b
end

describe(b::BlockButton) = begin
  ishovered(b) || (b.quiet = false)
  filled = b.bold && !b.off
  colour = b.off ? colours.faint : filled ? colours.bg : b.on ? colours.accent : colours.dim
  back = filled ? (ishovered(b) ? RGBA(colours.accent, 0.85) : colours.accent) :
         b.on ? colours.active : ishovered(b) && !b.off ? colours.hover : clear
  Box(height(26px), padding(filled ? 10px : 7px, 0px), radius(6px), Alignment.Center, name="Button", background(back),
    Row(Alignment.Center, child_gap=5px,
      (isempty(b.icon) ? () : (Icon(b.icon, size=14px, color=colour),))...,
      (isempty(b.words) ? () : (label(b.words, 12px, color=b.off ? colours.faint : filled ? colours.bg : colours.ink, weight=filled ? "Semibold" : ""),))...))
end

cursor(b::BlockButton) = b.off ? :arrow : :hand
draw(ctx, size, ui::ConcreteRect, b::BlockButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::BlockButton, ev::MouseMove) = begin
  (b.quiet || isempty(b.tip)) && return
  show_tooltip!(ev.window, tip_label(b.tip), b.rect..., placement=:bottom, gap=6px)
end

onkey(b::BlockButton, ev::KeyPress{Keys.mouse_left}) = begin
  b.quiet = true
  hide_tooltip!(ev.window)
  b.off ? handled : act!(b.of, b.action, ev.window)
end

const BLOCK_ROUND = 8px   # how round the corners of a block are, and of a table

"What a block's box looks like in the page: round corners and a thin line, as a schedule has"
block_look() = (width(grow=grow), Alignment.Start, radius(BLOCK_ROUND), border(1px, :solid, colours.line), background(takeoff_back()))

"""
The corners of row `r` of the `n` rows in a box with round corners and a 1px
line round it, like a table. The first row's top corners and the last row's
bottom corners follow the inside of that line, so the row's colour stays in it.
"""
inner_round(r, n) = radius(r == 1 ? BLOCK_ROUND - 1px : 0px, r == n ? BLOCK_ROUND - 1px : 0px)

"The row of buttons at the top of a block"
block_bar(parts...) = Row(width(grow=grow), height(38px), padding(6px, 0px), child_gap=2px, Alignment.Center, background(colours.block), parts...)

"A line of quiet words in a block that has nothing to show yet"
block_note(words) = Row(width(grow=grow), padding(16px, 20px), Alignment.Center, clip=true,
                        Box(width(grow=grow), Text(words, size=13px, family=SANS, color=colours.dim, wrap=WrapMode.words)))

"A colour as CSS writes it, like #2a78d6"
css_colour(c) = (c = RGBA(c); "#" * join(string(round(Int, 255x), base=16, pad=2) for x in (c.r, c.g, c.b)))

"""
True for a kind of view that can fill the window, over the page: a takeoff, a
schedule, a sketch or a canvas. Such a view has the fields `full`, `tall`, which
is how tall it was in the page, and `pinned`, which is how far the page was scrolled.
"""
can_fill(v) = hasfield(typeof(v), :full) && hasfield(typeof(v), :pinned)
"True for a view that fills the window now"
filling(v) = can_fill(v) && v.full

"Put the block of the current page that fills the window back in the page"
unfill!(e) = for (key, node) in e.nodes
  filling(node) && key isa Tuple && length(key) == 4 && key[1] == :block && key[3] == e.buf.path && (node.full = false)
end

"The block of the page that fills the window, or nothing"
full_block(e) = begin
  for (key, node) in e.nodes
    filling(node) && key isa Tuple && length(key) == 4 && key[1] == :block && key[3] == e.buf.path && return node
  end
  nothing
end

"Per-view preparation before toggling fullscreen"
before_fill!(v, on::Bool) = v
"Where keyboard focus goes after toggling fullscreen"
fill_focus(v, on::Bool) = on ? keyboard_part(v) : editor(v)

"Make a fillable block fill the window, or put it back in the page"
full!(v, on::Bool) = begin
  e = editor(v)
  on && unfill!(e)   # one block of the page at a time fills the window
  before_fill!(v, on)
  v.full = on
  v.pinned = e.scroll.offset
  target = fill_focus(v, on)
  target === nothing || focus(target)
  handled
end

"The function called `name` of the module `from`, or nothing if the module has none"
named(from, name::Symbol) = Base.invokelatest(isdefined, from, name) ? Base.invokelatest(getglobal, from, name) : nothing

"`path` as the text names it: from the folder of the document when it's in that folder, and whole when it isn't"
named(e, path) = (dir = docdir(e); startswith(path, dir * "/") ? relpath(path, dir) : path)
