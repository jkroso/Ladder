# The view of a `signature` block
#
# A code block in the language `signature` is a place where a person signs
# the page with the mouse or the trackpad. signature.jl says how the block is
# written. The block shows a box with a line to sign on, and under it the
# name of who signs. A block with no name has a field there to type it in.
#
#   - Press in the box and drag to draw. Each stroke is a line of the block,
#     so the file holds the signature, and ⌘Z takes back the last stroke.
#   - The first stroke writes the day and the time. From then on the block
#     says who signed and on which day.
#   - A stroke that leaves the box goes on when the mouse comes back. The
#     page's text doesn't select meanwhile, and the page doesn't scroll.
#   - While the mouse is over a signed block, a Clear button shows. It takes
#     the strokes and the day away, and ⌘Z brings them back.
#   - A page that can't be changed, like an email, takes no strokes.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor MouseScroll with_round_clip
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./pictures" picture
@use "./html" escape
@use "./markdown" words
@use "./sheet" parts
@use "./signature" => Signatures
@use Dates: Dates
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./faces" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./sketch_view" exports...
@use "./schedule_view" exports...

export SIGNATURE, SIGN_STEP, sign_clock, SignatureView, SignArea, sign_area, signer_input, sign_wide,
       sign_scale, sign_place, signature_html

const SIGNATURE = Signatures.SIGNATURE
push!(BLOCK_ICONS, "pen")
const SIGN_STEP = 1.0   # how far the mouse moves, in the box's own measure, before a stroke gets a new place
"The clock that says when a block is signed. A test puts its own clock here."
const sign_clock = Ref{Function}(Dates.now)

"What a `signature` block shows: a box to sign in, and the name of who signs"
@def mutable struct SignatureView <: SemanticUI
  n::Int = 0                               # its place among the page's signatures
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Signatures.Signature = Signatures.Signature()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  draft::Any = nothing                     # the places of the stroke that's being drawn, or nothing
  asked::Bool = false                      # the block had no name once, so its field takes the name
  stay::px = 0px                           # how far the page was scrolled when the stroke started
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the box was last drawn in the window
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its box, its field and its button, kept between frames
end

"The box of a signature that's drawn in"
@def mutable struct SignArea <: SemanticUI
  of::Any = nothing
end

sign_area(v::SignatureView) = block_part!(() -> SignArea(of=v), v, :area)

"The text field that takes the name of who signs"
signer_input(v::SignatureView) = block_part!(v, :input) do
  TextInput(placeholder="Type your name", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

reread!(v::SignatureView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Signatures.signature(lines)
  # The field shows the name that the block has, as it does after ⌘Z takes some of it back
  i = signer_input(v)
  strip(i.text) == v.data.name || (i.text = v.data.name; i.anchor = i.cursor = length(i.text))
  v
end

"True for a signature in a page that can't be changed, like an email. It takes no strokes."
locked(v::SignatureView) = (b = editor(v).buf; readonly(b) || b.fixed)

"True while the page is drawn for paper. Printing puts the caret on no line."
on_paper(v::SignatureView) = editor(v).buf.caret[1] == 0

"""
True when a field under the box takes the name: the block has no name, or it
had none and the name was typed in the field. A signed block has no field.
"""
asks(v::SignatureView) = begin
  isempty(v.data.name) && (v.asked = true)
  v.asked && !Signatures.issigned(v.data) && !locked(v) && !on_paper(v)
end

"How wide the box is in the page: 420 px at the usual size of the text, and no wider than the page's text"
sign_wide(v::SignatureView) = (e = editor(v); min(px(Signatures.WIDE * e.zoom), e.width))

"How many px of the window one of the box's own measure is"
sign_scale(v::SignatureView) = v.box[3] > 0 ? v.box[3] / Signatures.WIDE : num(sign_wide(v)) / Signatures.WIDE

"The place in the box that's at `pos` in the window. A place outside the box has numbers that are outside it."
sign_place(v::SignatureView, pos) = (s = sign_scale(v); ((num(pos[1]) - v.box[1]) / s, (num(pos[2]) - v.box[2]) / s))

describe(a::SignArea) = begin
  wide = sign_wide(a.of)
  Box(fixed(wide), height(wide * (Signatures.TALL / Signatures.WIDE)), radius(8px), border(1px, :solid, colours.line),
      background(takeoff_back()), name="Box to sign in")
end

draw(ctx, size, ui::ConcreteRect, a::SignArea) = begin
  v = a.of
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  v.box[3] > 0 || return
  s = sign_scale(v)
  at(p) = (v.box[1] + p[1] * s, v.box[2] + p[2] * s)
  with_round_clip(ctx, ui.left, ui.top, ui.width, ui.height, 8px) do
    # The line to sign on, and the ✕ at its left end, as paper forms have
    trace(ctx, [at((Signatures.EDGE, Signatures.LINE)), at((Signatures.WIDE - Signatures.EDGE, Signatures.LINE))], colours.marker, 1.0)
    foreach(((from, to),) -> trace(ctx, [at(from), at(to)], colours.dim, max(1.0, 1.5s)), Signatures.CROSS)
    # The words go with the first stroke. A page that takes no strokes doesn't ask for one.
    if !Signatures.issigned(v.data) && v.draft === nothing && !locked(v)
      face = Face(SANS, "", 13px * editor(v).zoom, colours.faint, false)
      write_ink(ctx, "Sign here", v.box[1] + (v.box[3] - num(measure(face, "Sign here"))) / 2, at((0.0, Signatures.LINE - 12))[2], face)
    end
    # The ink is the colour of the page's text, with round ends
    paint = ink(colours.ink, max(1.2, Signatures.INK * s))
    foreach(points -> draw_curve(ctx, at.(points), paint), v.data.strokes)
    v.draft === nothing || draw_curve(ctx, at.(v.draft), paint)
    Skia.sk_paint_delete(paint)
  end
end

cursor(a::SignArea) = locked(a.of) ? :arrow : :crosshair
cursor(::SignatureView) = :arrow

# A press in the box starts a stroke. The click goes on to the page, which takes the keyboard back from the
# name's field. With ⌥ held the page shows the block's lines, and a page that can't be changed takes no strokes.
onkey(a::SignArea, ev::KeyPress{Keys.mouse_left}) = begin
  v = a.of
  (only_held(v, Keys.opt) || locked(v) || v.box[3] <= 0) && return nothing
  v.draft === nothing || drop!(v)   # a stroke that no frame has taken yet
  v.draft = Signatures.Place[sign_place(v, ev.window.mouse)]
  v.stay = editor(v).scroll.offset
  nothing
end

# UI.jl gives the box each move of the mouse while its button is down, in the box or out of it
onmouse(a::SignArea, ev::MouseMove) = begin
  v = a.of
  v.draft === nothing && return nothing
  Keys.mouse_left in ev.window.keys || return handled
  p = sign_place(v, ev.position)
  hypot((p .- v.draft[end])...) >= SIGN_STEP && push!(v.draft, p)
  handled   # the drag is the signature's, so the page's text doesn't select
end

# The wheel doesn't scroll the page under a stroke that's being drawn
onscroll(a::SignArea, ::MouseScroll) = a.of.draft === nothing ? nothing : handled

"The mouse let go. The stroke that was drawn joins the signature, and the first stroke writes the day and the time."
drop!(v::SignatureView) = begin
  points = v.draft
  v.draft = nothing
  points === nothing && return v
  Signatures.sign!(v.data, points, sign_clock[]()) && write_block!(v, SIGNATURE, Signatures.written(v.data))
  v
end

block_tick!(v::SignatureView) = begin
  if v.draft !== nothing
    # The page stays where it was while a stroke is drawn, whatever scrolls it
    held(v, Keys.mouse_left) ? (editor(v).scroll.offset = v.stay) : drop!(v)
  end
  # What was typed in the field is written into the block as the name
  name = String(strip(signer_input(v).text))
  name == v.data.name && return v
  v.data.name = name
  write_block!(v, SIGNATURE, Signatures.written(v.data), typing=true)
end

describe(v::SignatureView) = begin
  e = editor(v)
  s = v.data
  signed = Signatures.issigned(s)
  input = signer_input(v)
  input.color = colours.ink
  w = window_of(v)
  typing = w !== nothing && w.focus === input
  with_theme(component_theme(e.zoom)) do
    # Under the box: who signed and when, or the field that takes the name, or the name. The words are
    # bigger in a page whose text is bigger, as the box is.
    size = 13px * e.zoom
    under = signed ? (Box(width(grow=grow), Text(Signatures.caption(s), size=size, family=SANS, color=colours.dim, wrap=WrapMode.words)),) :
            asks(v) ? (Box(fixed(min(sign_wide(v), 240px * e.zoom)), height(28px * e.zoom), padding(9px, 0px), radius(6px), background(colours.bg),
                           border(1px, :solid, typing ? colours.accent : colours.line), input), Box(width(grow=grow))) :
            (Box(width(grow=grow), Text(s.name, size=size, family=SANS, subfamily="Medium", color=colours.ink, wrap=WrapMode.words)),)
    # The Clear button shows while the mouse is over a signed block, and never on paper
    clear = signed && ishovered(v) && v.draft === nothing && !locked(v) && !on_paper(v) ?
      (block_button!(v, :clear, :clear, words="Clear", tip="Take the signature away"),) : ()
    Box(width(grow=grow), Alignment.Start,
      Column(fixed(sign_wide(v)), Alignment.Start, child_gap=6px, name="Signature",
        sign_area(v),
        Row(width(grow=grow), height(min=26px), child_gap=8px, Alignment.Center, under..., clear...)))
  end
end

# Clear takes the strokes and the day away in one change, so one ⌘Z brings them back
act!(v::SignatureView, action, w) = begin
  action == :clear || return handled
  Signatures.clear!(v.data)
  write_block!(v, SIGNATURE, Signatures.written(v.data))
  handled
end

# Return in the name's field gives the keyboard back to the page
onkey(v::SignatureView, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (focus(editor(v)); handled) : nothing

"The signature as HTML: a picture of the box and its strokes, with who signed and when under it"
signature_html(e, v::SignatureView) = begin
  s = v.data
  picture = Signatures.svg(s, ink="#2b2622", line="#d8d0bd", mark="#6b6259")
  under = Signatures.issigned(s) ? Signatures.caption(s) : s.name
  "<div class=\"diagram\">\n$picture\n</div>" *
  (isempty(under) ? "" : "\n<p style=\"margin-top: -0.5em; font-size: 0.88em; color: #6b6259\">$(escape(under))</p>")
end

BLOCKS[SIGNATURE] = SignatureView
block_name(::Type{SignatureView}) = "Signature"
block_icon(::Type{SignatureView}) = "pen"
block_insert(::Type{SignatureView}) = ("Signature", ["```$SIGNATURE", "```", "", ""], (4, 0))
block_html(e, v::SignatureView) = signature_html(e, v)
