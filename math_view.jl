# Diagrams and formulas in the page
#
# A code block in the language `mermaid` shows the diagram that its code
# describes: a flowchart, a sequence diagram, a state diagram, a class diagram,
# a pie chart, a mind map, an entity relationship diagram, a Gantt chart or a
# timeline. UI.jl's Mermaid component reads the code and draws it. Click
# it with ⌥ held to see its code, or as plain text put the caret in the block.
# A diagram of the first five kinds can be changed while it fills the window:
# see "a picture, a diagram or a page that fills the window". The last four
# fill the window too, and are changed in their code.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw show_tooltip!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" Mermaid problem
@use "./markdown" Kind Span words
@use "./sheet" shown
@use "./math" => Maths
@use "./base" exports...

export DIAGRAM, isdiagram, diagram, DiagramBlock, Equation, typeset, half_height, MATHS_LINE, maths_text,
       MATHS_SMALLEST, equation_item

const DIAGRAM = "mermaid"

"True when `code` is the code of a diagram that can be drawn"
isdiagram(code::AbstractString) = problem(code) === nothing

"What the `mermaid` block with this code shows: its diagram, or nothing if the code can't be drawn as one"
diagram(e, code::String) = begin
  isdiagram(code) || return nothing
  # A Shown gives the diagram the page's colours and font, as it does for what a live block makes
  node = get!(e.nodes, (:diagram, code)) do
    shown = Shown(value=Mermaid(code))
    own!(shown, shown.value)
    shown
  end
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

struct DiagramBlock end
BLOCKS[DIAGRAM] = DiagramBlock
block_name(::Type{DiagramBlock}) = "Diagram"
block_icon(::Type{DiagramBlock}) = "diagram-3"
block_insert(::Type{DiagramBlock}) = ("Diagram", ["```$DIAGRAM", "flowchart LR", "  A[Start] --> B[End]", "```"], (3, 2))
block_is_whole(::Type{DiagramBlock}, code::AbstractString) = isdiagram(code)
block_safe(::Type{DiagramBlock}) = true
block_html(::Type{DiagramBlock}, e, lang::AbstractString, s::Int, t::Int) = diagram_html(e, s, t)
block_outline(::Type{DiagramBlock}, lines::Vector{String}, i::Int, close::Int) =
  isdiagram(join(view(lines, i+1:close-1), "\n")) ? Entry(i, 7, "Diagram", "diagram-3", min(close + 1, length(lines))) : nothing
block_layout(::Type{DiagramBlock}, e, lang::AbstractString, i::Int, n::Int) = begin
  b = e.buf; ks = kinds(b); t = codeblock(b, i)[2]
  !incode(b, i) && t > i && ks[t].kind == Kind.fence && ks[t].level == 1 && (c = diagram(e, join(b.lines[i+1:t-1], "\n"))) !== nothing ? (t, c) : nothing
end

# --- formulas ---------------------------------------------------------------------------
#
# A formula is written in TeX between dollar signs. $x^2$ is a formula in a
# line of text. A formula on lines of its own goes between a line of $$ and
# another, or between $$ and $$ on one line, or in a code block in the language
# `math`. It's in the middle of the page, and its fractions and sum signs are
# bigger. math.jl reads the TeX and says where each character goes.
#
# In a line of text the formula is one thing: the caret goes over it in one
# step, and ⌘E shows its TeX. On lines of its own it's a part of the page, as
# a diagram is: the caret goes onto it as a whole, and Return shows its TeX.

"A formula as it's set: in a line of text, or with `display` on lines of its own in the middle of the page"
@def mutable struct Equation <: SemanticUI
  tex::String = ""
  size::px = TEXT_SIZE         # of the text that it's in
  display::Bool = false
  colour::Any = nothing        # of the text that it's in, or nothing for the page's ink
  mid::px = 0px                # in a line of text: how far the middle of the line's capital letters is over the line they stand on
end

"The formula of `m`, with where each of its characters goes"
typeset(m::Equation) = Maths.formula(m.tex, num(m.size), m.display)

"How far a formula in a line of text goes over and under the middle of the line. A row of the page puts the middle of each thing in it at the same height."
half_height(m::Equation) = (f = typeset(m); px(max(Maths.height(f) - num(m.mid), Maths.depth(f) + num(m.mid))))

describe(m::Equation) = begin
  f = typeset(m)
  m.display ? Box(width(grow=grow), height(px(Maths.height(f) + Maths.depth(f)))) : Box(fixed(px(Maths.wide(f))), height(2half_height(m)))
end

draw(ctx, size, ui::ConcreteRect, m::Equation) = begin
  f = typeset(m)
  # On lines of its own it's in the middle of the page. In a line of text it stands on the line that the letters stand on.
  x = m.display ? ui.left + max(0px, ui.width - px(Maths.wide(f))) / 2 : ui.left
  y = m.display ? ui.top + px(Maths.height(f)) : ui.top + half_height(m) + m.mid
  Maths.paint(ctx, f, num(x), num(y), something(m.colour, colours.ink), colours.accent)
  nothing
end

# The mouse over a formula that has a command that Ladder doesn't know says which. Two lines with the
# same text show the same formula, so the words go under the mouse, not under where the formula was drawn.
onmouse(m::Equation, ev::MouseMove) = begin
  words = tip(m)
  isempty(words) && return nothing
  x, y = ev.position
  show_tooltip!(ev.window, tip_label(words), x - 1px, y - 10px, 2px, 20px, placement=:bottom, gap=6px)
  nothing
end

"What the mouse over a formula says: the commands of its TeX that Ladder doesn't know, or nothing when it knows them all"
tip(m::Equation) = (unknown = unique(typeset(m).problems); isempty(unknown) ? "" : "Ladder doesn't know " * join(unknown, ", ", " or "))

"The piece that stands for the formula of span `s`, in text drawn in `base`"
equation(e, s::Span, base::Face) = begin
  m = Equation(tex=s.text, size=base.size, colour=base.color, mid=capital(base) / 2)
  # It's part of its line, which is laid out once and kept. It can reach the document, and it isn't one of the document's children.
  setfield!(m, :parent, node!(Document, e, :document))
  piece(s.text, s.col, base, atomic=true, n=length(s.text), node=Inline(m, px(Maths.wide(typeset(m))), 2half_height(m)))
end

const MATHS_LINE = r"^\s*\$\$(.*\S.*)\$\$\s*$"

"The TeX of a line that holds only a formula between \$\$ and \$\$, or nothing for any other line"
maths_text(text::AbstractString) = begin
  m = match(MATHS_LINE, text)
  m === nothing || occursin("\$\$", m[1]) ? nothing : String(strip(m[1]))
end

"True when line `i` holds only a formula between \$\$ and \$\$, which shows on a line of its own"
maths_line(b::Buffer, i::Int) =
  kinds(b)[i].kind == Kind.paragraph && occursin("\$\$", b.lines[i]) && maths_text(b.lines[i]) !== nothing && Maths.available()

"True when `tex` is a formula that can be set: it has something in it, and the Mac has the font for maths"
has_maths(tex::AbstractString) = !isempty(strip(tex)) && Maths.available()

const MATHS_SMALLEST = 0.5   # how small a formula that's wider than the page gets, as a part of the size of the text

"What a formula on lines of its own shows, or nothing if `tex` can't be set"
equation_item(e, tex) = begin
  (tex === nothing || !has_maths(tex)) && return nothing
  m = get!(() -> Equation(tex=String(tex), display=true), e.nodes, (:equation, String(tex)))
  own!(node!(Document, e, :document), m)
  m.size = body(e).size
  # A formula that's wider than the page is smaller, so that all of it shows
  wide = px(Maths.wide(typeset(m)))
  wide > e.width && (m.size *= max(MATHS_SMALLEST, e.width / wide))
  f = typeset(m)
  Live(m, px(Maths.height(f) + Maths.depth(f)) + 2LIVE_GAP)
end
