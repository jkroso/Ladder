# Maths, set the way TeX sets it. A formula is written in TeX's language:
#
#     \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
#
# `formula(tex, size, display)` reads the TeX and works out where each character
# and each line of the formula goes. `paint` draws that on a Skia canvas, and
# `mathml(tex)` writes the same formula in MathML, for a page of HTML.
#
# The characters come from STIX Two Math, a font that every Mac has. A maths
# font holds a table called MATH, with the numbers that a formula is set by:
# how far up a superscript goes, how thick the line of a fraction is, and the
# bigger and taller shapes of each bracket, root sign and sum sign. This file
# reads that table itself, and follows the rules of Appendix G of The TeXbook
# with its numbers. A Mac without the font has no formulas: see `available`.
#
# What it reads:
#
#   - letters, digits and signs, x^2 and x_i, primes like f'
#   - \frac, \dfrac, \tfrac, \binom, \sqrt and \sqrt[3]
#   - Greek letters, and the signs of LaTeX and amsmath: \leq, \to, \infty ...
#   - \sum, \int, \prod and the rest, with limits over and under them
#   - \left( ... \right), \middle, and \big, \Big, \bigg, \Bigg
#   - \hat, \bar, \vec, \tilde, \dot, \overline, \underbrace and so on
#   - \sin, \lim, \max and so on, \operatorname and \text
#   - \mathbf, \mathbb, \mathcal, \mathfrak, \mathrm, \mathsf, \mathtt
#   - matrix, pmatrix, bmatrix, vmatrix, cases, array, aligned and gathered
#   - \\ for a new line and & to line the lines up, \quad and the other spaces
#
# A command that it doesn't know shows as its name, and `problems` lists them.

@use "github.com/jkroso/MiniFB.jl/skia" fontmgr sk_color
@use Skia

# --- the font ----------------------------------------------------------------------------

const FONT_FILE = "/System/Library/Fonts/Supplemental/STIXTwoMath.otf"
const FAMILY = "STIX Two Math"

"One of the pieces that a tall bracket is put together from"
struct Piece
  glyph::UInt16
  start::Float64      # how far the piece before it can lie over its start
  stop::Float64       # and the piece after it over its end
  long::Float64
  extender::Bool      # true for a piece that's there as many times as the bracket needs
end

"The bigger shapes of one glyph: whole glyphs, each with how long it is, and the pieces to make any length from"
struct Shapes
  whole::Vector{Tuple{UInt16,Float64}}
  pieces::Vector{Piece}
end

"A maths font. Its numbers are in the font's own units: `em` of them are as long as the size of the text."
struct MathFont
  face::Ptr{Skia.sk_typeface_t}
  ruler::Ptr{Skia.sk_font_t}                # the font at a size of `em`, so what it measures is in the font's units
  em::Float64
  numbers::Dict{Symbol,Float64}             # the table's constants, by the names that OpenType gives them
  slant::Dict{UInt16,Float64}               # how far the top of a glyph leans past its width
  top::Dict{UInt16,Float64}                 # where an accent goes over a glyph, from the glyph's start
  tall::Dict{UInt16,Shapes}
  wide::Dict{UInt16,Shapes}
  overlap::Float64                          # the least that two pieces of a bracket lie over each other
  glyphs::Dict{Char,UInt16}
  sizes::Dict{UInt16,NTuple{5,Float64}}     # of each glyph: its width, and the left, top, right and bottom of its ink
end

# The lengths of the MATH table's constants, in the order that the table holds them
const LENGTHS = (:mathLeading, :axisHeight, :accentBaseHeight, :flattenedAccentBaseHeight, :subscriptShiftDown,
  :subscriptTopMax, :subscriptBaselineDropMin, :superscriptShiftUp, :superscriptShiftUpCramped, :superscriptBottomMin,
  :superscriptBaselineDropMax, :subSuperscriptGapMin, :superscriptBottomMaxWithSubscript, :spaceAfterScript,
  :upperLimitGapMin, :upperLimitBaselineRiseMin, :lowerLimitGapMin, :lowerLimitBaselineDropMin, :stackTopShiftUp,
  :stackTopDisplayStyleShiftUp, :stackBottomShiftDown, :stackBottomDisplayStyleShiftDown, :stackGapMin,
  :stackDisplayStyleGapMin, :stretchStackTopShiftUp, :stretchStackBottomShiftDown, :stretchStackGapAboveMin,
  :stretchStackGapBelowMin, :fractionNumeratorShiftUp, :fractionNumeratorDisplayStyleShiftUp,
  :fractionDenominatorShiftDown, :fractionDenominatorDisplayStyleShiftDown, :fractionNumeratorGapMin,
  :fractionNumDisplayStyleGapMin, :fractionRuleThickness, :fractionDenominatorGapMin, :fractionDenomDisplayStyleGapMin,
  :skewedFractionHorizontalGap, :skewedFractionVerticalGap, :overbarVerticalGap, :overbarRuleThickness,
  :overbarExtraAscender, :underbarVerticalGap, :underbarRuleThickness, :underbarExtraDescender, :radicalVerticalGap,
  :radicalDisplayStyleVerticalGap, :radicalRuleThickness, :radicalExtraAscender, :radicalKernBeforeDegree,
  :radicalKernAfterDegree)

# A font file holds its numbers with the big end first
u16(d, o) = (UInt16(d[o+1]) << 8) | d[o+2]
i16(d, o) = reinterpret(Int16, u16(d, o))
u32(d, o) = (UInt32(u16(d, o)) << 16) | u16(d, o + 2)

"The glyphs that the coverage table at `o` lists, in its order"
coverage(d, o) = begin
  u16(d, o) == 1 && return UInt16[u16(d, o + 4 + 2k) for k in 0:Int(u16(d, o + 2))-1]
  out = UInt16[]
  for k in 0:Int(u16(d, o + 2))-1
    append!(out, u16(d, o + 4 + 6k):u16(d, o + 6 + 6k))
  end
  out
end

"The length that the table at `o` holds for each glyph that it covers"
lengths(d, o) = begin
  glyphs = coverage(d, o + u16(d, o))
  Dict{UInt16,Float64}(glyphs[k] => i16(d, o + 4k) for k in 1:Int(u16(d, o + 2)))
end

"The bigger shapes that the table at `o` holds for one glyph"
shapes(d, o) = begin
  whole = [(u16(d, o + 4 + 4k), Float64(u16(d, o + 6 + 4k))) for k in 0:Int(u16(d, o + 2))-1]
  pieces = Piece[]
  if u16(d, o) != 0
    p = o + u16(d, o)
    for k in 0:Int(u16(d, p + 4))-1
      q = p + 6 + 10k
      push!(pieces, Piece(u16(d, q), u16(d, q + 2), u16(d, q + 4), u16(d, q + 6), isodd(u16(d, q + 8))))
    end
  end
  Shapes(whole, pieces)
end

"The typeface of the installed font of the family `name`, or nothing when the Mac has none"
typeface(name) = begin
  style = Skia.sk_fontstyle_new(Int32(400), Int32(Skia.SK_FONT_STYLE_WIDTH_NORMAL), Skia.SK_FONT_STYLE_SLANT_UPRIGHT)
  face = Skia.sk_fontmgr_match_family_style(fontmgr[], name, style)
  Skia.sk_fontstyle_delete(style)
  face == C_NULL && return nothing
  # Skia gives another font when it has none of that family
  found = Skia.sk_typeface_get_family_name(face)
  same = unsafe_string(Skia.sk_string_get_c_str(found)) == name
  Skia.sk_string_delete(found)
  same ? face : nothing
end

"Read the maths font from its file, or nothing when the Mac doesn't have it"
read_font(path=FONT_FILE) = begin
  isfile(path) || return nothing
  face = typeface(FAMILY)
  face === nothing && return nothing
  d = read(path)
  tables = Dict(String(d[12+16k+1:12+16k+4]) => Int(u32(d, 12 + 16k + 8)) for k in 0:Int(u16(d, 4))-1)
  haskey(tables, "MATH") && haskey(tables, "head") || return nothing
  em = Float64(u16(d, tables["head"] + 18))
  m = tables["MATH"]
  c = m + u16(d, m + 4)
  numbers = Dict{Symbol,Float64}(:scriptPercentScaleDown => i16(d, c), :scriptScriptPercentScaleDown => i16(d, c + 2),
                                 :delimitedSubFormulaMinHeight => u16(d, c + 4), :displayOperatorMinHeight => u16(d, c + 6))
  for (k, name) in enumerate(LENGTHS)
    numbers[name] = i16(d, c + 4 + 4k)
  end
  numbers[:radicalDegreeBottomRaisePercent] = i16(d, c + 8 + 4length(LENGTHS))
  g = m + u16(d, m + 6)
  slant = u16(d, g) == 0 ? Dict{UInt16,Float64}() : lengths(d, g + u16(d, g))
  top = u16(d, g + 2) == 0 ? Dict{UInt16,Float64}() : lengths(d, g + u16(d, g + 2))
  v = m + u16(d, m + 8)
  nt, nw = Int(u16(d, v + 6)), Int(u16(d, v + 8))
  covered(o) = o == 0 ? UInt16[] : coverage(d, v + o)
  tall = Dict{UInt16,Shapes}(glyph => shapes(d, v + u16(d, v + 8 + 2k)) for (k, glyph) in enumerate(covered(u16(d, v + 2))) if k <= nt)
  wide = Dict{UInt16,Shapes}(glyph => shapes(d, v + u16(d, v + 8 + 2nt + 2k)) for (k, glyph) in enumerate(covered(u16(d, v + 4))) if k <= nw)
  MathFont(face, Skia.sk_font_new_with_values(face, Float32(em), 1f0, 0f0), em, numbers, slant, top, tall, wide,
           Float64(u16(d, v)), Dict{Char,UInt16}(), Dict{UInt16,NTuple{5,Float64}}())
end

const loaded = Ref{Any}(missing)

"The maths font, or nothing when the Mac doesn't have it"
font() = begin
  loaded[] === missing && (loaded[] = try read_font() catch; nothing end)
  loaded[]::Union{Nothing,MathFont}
end

"True when formulas can be set: the Mac has the maths font"
available() = font() !== nothing

"The font's glyph for `c`. It's 0 for a character that the font doesn't have."
glyph(f::MathFont, c::Char) = get!(() -> Skia.sk_font_unichar_to_glyph(f.ruler, Int32(c)), f.glyphs, c)

"How wide `g` is, and the left, top, right and bottom of its ink. Top is up from the line that it stands on, and bottom is down from it."
measure(f::MathFont, g::UInt16) = get!(f.sizes, g) do
  bounds = Ref(Skia.sk_rect_t(0f0, 0f0, 0f0, 0f0))
  wide = Skia.sk_font_measure_text(f.ruler, Ref(g), Csize_t(2), Skia.SK_TEXT_ENCODING_GLYPH_ID, bounds, C_NULL)
  r = bounds[]
  (Float64(wide), Float64(r.left), -Float64(r.top), Float64(r.right), Float64(r.bottom))
end

const sized_fonts = Dict{Float32,Ptr{Skia.sk_font_t}}()

# A built app starts with the font that the build read, and the Skia objects of
# that font are gone by then. So each start reads the font again.
__init__() = (loaded[] = missing; empty!(sized_fonts); nothing)

"The font at `size` px, to draw with"
sized(f::MathFont, size) = begin
  length(sized_fonts) > 200 && (foreach(Skia.sk_font_delete, values(sized_fonts)); empty!(sized_fonts))
  get!(sized_fonts, Float32(size)) do
    raw = Skia.sk_font_new_with_values(f.face, Float32(size), 1f0, 0f0)
    # A glyph goes where the formula says, not to the nearest whole pixel, and keeps its shape at every size
    Skia.sk_font_set_subpixel(raw, true)
    Skia.sk_font_set_hinting(raw, Skia.SK_FONT_HINTING_NONE)
    raw
  end
end

# --- what a formula is made of -----------------------------------------------------------
#
# The TeX is read into nodes. A node's class says how much room it gets beside
# its neighbours, as in TeX: :ord for a letter, :op for a sum sign, :bin for a
# plus sign, :rel for an equals sign, :open and :close for brackets, :punct for
# a comma and :inner for a part in \left and \right.

abstract type Node end

"One character"
struct Sym <: Node
  char::Char
  class::Symbol
end

"What's between { and }"
struct Group <: Node
  items::Vector{Node}
end

"A node with a subscript, a superscript, primes, or more than one of them"
struct Scripts <: Node
  base::Node
  sub::Union{Node,Nothing}
  sup::Union{Node,Nothing}
  primes::Int         # how many ' follow it, like the one of f'
end

"A node that \\limits or \\nolimits follows: its scripts go over and under it, or beside it"
struct Limits <: Node
  body::Node
  on::Bool
end

"One thing over another, like a fraction. `style` is 1 for \\dfrac, 2 for \\tfrac and 0 for the size that suits its place."
struct Frac <: Node
  num::Node
  den::Node
  rule::Bool          # false for \binom, which has no line
  left::Char          # the brackets round it, or '.' for none
  right::Char
  style::Int
end

struct Root <: Node
  body::Node
  degree::Union{Node,Nothing}
end

"Parts between brackets that are as tall as the parts: \\left( ... \\middle| ... \\right)"
struct Fenced <: Node
  delims::Vector{Char}        # one more than there are parts. '.' is no bracket.
  parts::Vector{Vector{Node}}
end

"A mark over a node, like the hat of \\hat{x}"
struct Accent <: Node
  char::Char
  body::Node
  wide::Bool          # it's as wide as the node, like \widehat
end

"A line over or under a node"
struct Bar <: Node
  body::Node
  over::Bool
end

"A brace or an arrow that's as wide as the node it's over or under"
struct Stretch <: Node
  char::Char
  body::Node
  over::Bool
end

"A node with others set small over and under it, like \\overset"
struct Stack <: Node
  base::Node
  over::Union{Node,Nothing}
  under::Union{Node,Nothing}
  class::Symbol
end

"Upright words: the name of a function, or the text of \\text"
struct Words <: Node
  text::String
  class::Symbol
  limits::Bool        # its scripts go over and under it in a formula on a line of its own, like \lim
  bad::Bool           # it's the name of a command that isn't known
end

"Room between two nodes, in mu: an 18th of the size of the text"
struct Space <: Node
  mu::Float64
end

"What follows is set at another size: 0 for \\displaystyle, 1 for \\textstyle, 2 for \\scriptstyle and 3 for \\scriptscriptstyle"
struct Style <: Node
  level::Int
end

"Rows of cells: a matrix, the cases of a function, or lines that are lined up"
struct Rows <: Node
  rows::Vector{Vector{Group}}
  kind::Symbol        # :matrix, :small, :cases, :aligned or :gathered
  left::Char
  right::Char
  align::String       # l, c or r for each column. The last one is for the columns after it too.
end

"A bracket of one of the sizes of \\big, \\Big, \\bigg and \\Bigg"
struct Sized <: Node
  char::Char
  size::Int
  class::Symbol
end

"A node that's given a class, like \\mathrel{...}"
struct Classed <: Node
  class::Symbol
  body::Node
end

"Room as big as a node, with nothing in it"
struct Phantom <: Node
  body::Node
end

"A node with a box round it"
struct Boxed <: Node
  body::Node
end

# --- the commands ------------------------------------------------------------------------

const SYMBOLS = Dict{String,Tuple{Char,Symbol}}()

for (class, words) in (
  :ord => "alpha α beta β gamma γ delta δ epsilon ϵ varepsilon ε zeta ζ eta η theta θ vartheta ϑ iota ι kappa κ varkappa ϰ
           lambda λ mu μ nu ν xi ξ omicron ο pi π varpi ϖ rho ρ varrho ϱ sigma σ varsigma ς tau τ upsilon υ phi ϕ varphi φ
           chi χ psi ψ omega ω Gamma Γ Delta Δ Theta Θ Lambda Λ Xi Ξ Pi Π Sigma Σ Upsilon Υ Phi Φ Psi Ψ Omega Ω
           infty ∞ partial ∂ nabla ∇ forall ∀ exists ∃ nexists ∄ emptyset ∅ varnothing ∅ hbar ℏ hslash ℏ ell ℓ Re ℜ Im ℑ
           aleph ℵ beth ℶ gimel ℷ wp ℘ angle ∠ measuredangle ∡ sphericalangle ∢ triangle △ square □ Box □ blacksquare ■
           Diamond ◊ lozenge ◊ neg ¬ lnot ¬ top ⊤ bot ⊥ prime ′ backslash \\ degree ° checkmark ✓ sharp ♯ flat ♭
           natural ♮ clubsuit ♣ diamondsuit ♢ heartsuit ♡ spadesuit ♠ imath 𝚤 jmath 𝚥 surd √ complement ∁ S § P ¶
           pounds £ copyright © dag † ddag ‡ vert | Vert ‖ | ‖ % % # # & & _ _ \$ \$ eth ð mho ℧ Finv Ⅎ
           bigstar ★ maltese ✠ diagup ╱ diagdown ╲ infin ∞ vdots ⋮ ddots ⋱",
  :inner => "dots … ldots … cdots ⋯ dotsc … dotsb ⋯ dotsm ⋯ dotsi ⋯ dotso …",
  :bin => "pm ± mp ∓ times × div ÷ cdot ⋅ ast ∗ star ⋆ circ ∘ bullet ∙ cap ∩ cup ∪ uplus ⊎ sqcap ⊓ sqcup ⊔ vee ∨ lor ∨
           wedge ∧ land ∧ setminus ∖ smallsetminus ∖ wr ≀ oplus ⊕ ominus ⊖ otimes ⊗ oslash ⊘ odot ⊙ amalg ⨿
           triangleleft ◁ triangleright ▷ bigtriangleup △ bigtriangledown ▽ ltimes ⋉ rtimes ⋊ dotplus ∔ boxplus ⊞
           boxminus ⊟ boxtimes ⊠ boxdot ⊡ diamond ⋄ dagger † ddagger ‡ barwedge ⊼ veebar ⊻ circledast ⊛ circledcirc ⊚
           circleddash ⊝ centerdot ⋅ intercal ⊺ divideontimes ⋇ lhd ⊲ rhd ⊳ unlhd ⊴ unrhd ⊵ bigcirc ◯",
  :rel => "le ≤ leq ≤ ge ≥ geq ≥ ne ≠ neq ≠ equiv ≡ approx ≈ sim ∼ simeq ≃ cong ≅ propto ∝ in ∈ notin ∉ ni ∋ owns ∋
           subset ⊂ supset ⊃ subseteq ⊆ supseteq ⊇ nsubseteq ⊈ nsupseteq ⊉ subsetneq ⊊ supsetneq ⊋ sqsubset ⊏
           sqsupset ⊐ sqsubseteq ⊑ sqsupseteq ⊒ ll ≪ gg ≫ prec ≺ succ ≻ preceq ⪯ succeq ⪰ perp ⊥ parallel ∥
           nparallel ∦ mid ∣ nmid ∤ vdash ⊢ dashv ⊣ models ⊨ vDash ⊨ Vdash ⊩ asymp ≍ doteq ≐ bowtie ⋈ smile ⌣ frown ⌢
           triangleq ≜ coloneqq ≔ eqqcolon ≕ lesssim ≲ gtrsim ≳ leqslant ⩽ geqslant ⩾ lessgtr ≶ gtrless ≷ approxeq ≊
           thicksim ∼ thickapprox ≈ backsim ∽ eqsim ≂ lll ⋘ ggg ⋙ nless ≮ ngtr ≯ nleq ≰ ngeq ≱ nsim ≁ ncong ≇
           therefore ∴ because ∵ between ≬ pitchfork ⋔ varpropto ∝ multimap ⊸ lt < gt >
           to → rightarrow → gets ← leftarrow ← leftrightarrow ↔ Rightarrow ⇒ Leftarrow ⇐ Leftrightarrow ⇔ implies ⟹
           impliedby ⟸ iff ⟺ longrightarrow ⟶ longleftarrow ⟵ longleftrightarrow ⟷ Longrightarrow ⟹ Longleftarrow ⟸
           Longleftrightarrow ⟺ mapsto ↦ longmapsto ⟼ uparrow ↑ downarrow ↓ updownarrow ↕ Uparrow ⇑ Downarrow ⇓
           Updownarrow ⇕ nearrow ↗ searrow ↘ swarrow ↙ nwarrow ↖ hookrightarrow ↪ hookleftarrow ↩ rightharpoonup ⇀
           rightharpoondown ⇁ leftharpoonup ↼ leftharpoondown ↽ rightleftharpoons ⇌ leftrightharpoons ⇋ leadsto ⇝
           rightsquigarrow ⇝ twoheadrightarrow ↠ twoheadleftarrow ↞ rightarrowtail ↣ nrightarrow ↛ nleftarrow ↚
           nRightarrow ⇏ nLeftarrow ⇍ rightrightarrows ⇉ leftleftarrows ⇇ circlearrowleft ↺ circlearrowright ↻
           upharpoonright ↾ downharpoonright ⇂ restriction ↾ Lsh ↰ Rsh ↱",
  :op => "sum ∑ prod ∏ coprod ∐ int ∫ iint ∬ iiint ∭ oint ∮ oiint ∯ bigcup ⋃ bigcap ⋂ bigsqcup ⨆ bigvee ⋁ bigwedge ⋀
          bigoplus ⨁ bigotimes ⨂ bigodot ⨀ biguplus ⨄ intop ∫ smallint ∫",
  :open => "lbrace { { { langle ⟨ lfloor ⌊ lceil ⌈ lvert | lVert ‖ lbrack [ lparen ( llbracket ⟦ ulcorner ⌜ llcorner ⌞",
  :close => "rbrace } } } rangle ⟩ rfloor ⌋ rceil ⌉ rvert | rVert ‖ rbrack ] rparen ) rrbracket ⟧ urcorner ⌝ lrcorner ⌟",
  :punct => "colon :")
  parts = split(words)
  for k in 1:2:length(parts)
    length(parts[k+1]) == 1 || error("the list of symbols is out of step at $(parts[k])")
    SYMBOLS[parts[k]] = (only(parts[k+1]), class)
  end
end

"""
The class of each character that a command stands for, for a character that's
typed as itself, like ∞. A character that commands give two classes to, like
‖, isn't here, and is a letter's class.
"""
const CLASSES = begin
  found = Dict{Char,Set{Symbol}}()
  for (char, class) in values(SYMBOLS)
    isascii(char) || class == :ord || push!(get!(found, char, Set{Symbol}()), class)
  end
  Dict{Char,Symbol}(char => only(classes) for (char, classes) in found if length(classes) == 1)
end

"The characters of the keyboard that aren't letters or digits, with what each shows as and its class"
const KEYS = Dict{Char,Tuple{Char,Symbol}}(
  '+' => ('+', :bin), '-' => ('−', :bin), '*' => ('∗', :bin), '/' => ('/', :ord), '=' => ('=', :rel), '<' => ('<', :rel),
  '>' => ('>', :rel), ':' => (':', :rel), ',' => (',', :punct), ';' => (';', :punct), '(' => ('(', :open),
  '[' => ('[', :open), ')' => (')', :close), ']' => (']', :close), '|' => ('|', :ord), '!' => ('!', :close),
  '?' => ('?', :close), '.' => ('.', :ord), '`' => ('‵', :ord))

"The names of functions, each with true if its scripts go over and under it in a formula on a line of its own"
const FUNCTIONS = Dict{String,Bool}(
  (name => false for name in split("arccos arcsin arctan arg cos cosh cot coth csc deg dim exp hom ker lg ln log sec sin sinh tan tanh"))...,
  (name => true for name in split("det gcd inf lim liminf limsup max min Pr sup injlim projlim argmax argmin"))...)

"What some functions show as, when it isn't their name"
const FUNCTION_WORDS = Dict("liminf" => "lim inf", "limsup" => "lim sup", "injlim" => "inj lim", "projlim" => "proj lim",
                            "argmax" => "arg max", "argmin" => "arg min")

"The marks that go over a node, as the characters that join the letter before them"
const ACCENTS = Dict{String,Char}("hat" => '̂', "widehat" => '̂', "tilde" => '̃', "widetilde" => '̃',
  "bar" => '̄', "dot" => '̇', "ddot" => '̈', "dddot" => '⃛', "vec" => '⃗', "check" => '̌',
  "widecheck" => '̌', "breve" => '̆', "acute" => '́', "grave" => '̀', "mathring" => '̊')

"The braces and arrows that are as wide as what they're over or under: the character, and true if it goes over"
const STRETCHES = Dict{String,Tuple{Char,Bool}}("overbrace" => ('⏞', true), "underbrace" => ('⏟', false),
  "overrightarrow" => ('→', true), "overleftarrow" => ('←', true), "overleftrightarrow" => ('↔', true),
  "underrightarrow" => ('→', false), "underleftarrow" => ('←', false), "overbracket" => ('⎴', true),
  "underbracket" => ('⎵', false), "overparen" => ('⏜', true), "underparen" => ('⏝', false))

const VARIANTS = Dict{String,Symbol}("mathrm" => :upright, "mathup" => :upright, "mathnormal" => :italic, "mathit" => :italic,
  "mathbf" => :bold, "boldsymbol" => :bolditalic, "bm" => :bolditalic, "pmb" => :bolditalic, "mathbb" => :bb, "Bbb" => :bb,
  "mathcal" => :cal, "mathscr" => :cal, "mathfrak" => :frak, "mathsf" => :sf, "mathtt" => :tt)

"The commands that show their text as it's written, with the letters that it's in"
const TEXTS = Dict{String,Symbol}("text" => :upright, "textrm" => :upright, "textnormal" => :upright, "mbox" => :upright,
  "hbox" => :upright, "textup" => :upright, "textbf" => :bold, "textit" => :italic, "textsf" => :sf, "texttt" => :tt)

const SPACES = Dict{String,Float64}("," => 3, "thinspace" => 3, ":" => 4, ">" => 4, "medspace" => 4, ";" => 5,
  "thickspace" => 5, "!" => -3, "negthinspace" => -3, "negmedspace" => -4, "negthickspace" => -5, " " => 5, "nobreakspace" => 5,
  "space" => 5, "enspace" => 9, "enskip" => 9, "quad" => 18, "qquad" => 36)

const STYLES = Dict{String,Int}("displaystyle" => 0, "textstyle" => 1, "scriptstyle" => 2, "scriptscriptstyle" => 3)

"The commands that give a node a class"
const CLASSERS = Dict{String,Symbol}("mathord" => :ord, "mathop" => :op, "mathbin" => :bin, "mathrel" => :rel,
  "mathopen" => :open, "mathclose" => :close, "mathpunct" => :punct, "mathinner" => :inner)

"What can follow \\left, \\right and \\big, with the bracket that each is"
const DELIMS = Dict{String,Char}("(" => '(', ")" => ')', "[" => '[', "]" => ']', "|" => '|', "." => '.', "/" => '/',
  "<" => '⟨', ">" => '⟩', "\\{" => '{', "\\}" => '}', "\\|" => '‖', "\\langle" => '⟨', "\\rangle" => '⟩',
  "\\lfloor" => '⌊', "\\rfloor" => '⌋', "\\lceil" => '⌈', "\\rceil" => '⌉', "\\vert" => '|', "\\lvert" => '|',
  "\\rvert" => '|', "\\Vert" => '‖', "\\lVert" => '‖', "\\rVert" => '‖', "\\lbrace" => '{', "\\rbrace" => '}',
  "\\lbrack" => '[', "\\rbrack" => ']', "\\lparen" => '(', "\\rparen" => ')', "\\backslash" => '\\',
  "\\uparrow" => '↑', "\\downarrow" => '↓', "\\updownarrow" => '↕', "\\Uparrow" => '⇑', "\\Downarrow" => '⇓',
  "\\Updownarrow" => '⇕', "\\llbracket" => '⟦', "\\rrbracket" => '⟧', "\\lgroup" => '⟮', "\\rgroup" => '⟯')

"What \\not makes of the sign after it"
const NEGATED = Dict{Char,Char}('=' => '≠', '<' => '≮', '>' => '≯', '∈' => '∉', '∋' => '∌', '≡' => '≢', '≤' => '≰',
  '≥' => '≱', '⊂' => '⊄', '⊃' => '⊅', '⊆' => '⊈', '⊇' => '⊉', '∼' => '≁', '≈' => '≉', '≅' => '≇', '≃' => '≄',
  '∣' => '∤', '∥' => '∦', '∃' => '∄', '→' => '↛', '←' => '↚', '⇒' => '⇏', '⇐' => '⇍', '⊢' => '⊬', '⊨' => '⊭',
  '≺' => '⊀', '≻' => '⊁')

"The rows of each kind of block that starts with \\begin: its kind, its brackets and how its columns line up"
const BLOCKS = Dict{String,Tuple{Symbol,Char,Char,String}}(
  "matrix" => (:matrix, '.', '.', "c"), "pmatrix" => (:matrix, '(', ')', "c"), "bmatrix" => (:matrix, '[', ']', "c"),
  "Bmatrix" => (:matrix, '{', '}', "c"), "vmatrix" => (:matrix, '|', '|', "c"), "Vmatrix" => (:matrix, '‖', '‖', "c"),
  "smallmatrix" => (:small, '.', '.', "c"), "array" => (:matrix, '.', '.', "c"), "subarray" => (:small, '.', '.', "c"),
  "cases" => (:cases, '{', '.', "l"), "dcases" => (:cases, '{', '.', "l"), "rcases" => (:cases, '.', '}', "l"),
  (name => (:aligned, '.', '.', "rl") for name in split("aligned align align* split alignat alignat* alignedat eqnarray eqnarray* flalign flalign*"))...,
  (name => (:gathered, '.', '.', "c") for name in split("gathered gather gather* equation equation* multline multline* displaymath math"))...)

const BIG = r"^(big|Big|bigg|Bigg)([lrm]?)$"
const INTEGRALS = ('∫', '∬', '∭', '∮', '∯', '∰', '⨌')

# --- the letters of \mathbf, \mathbb and the rest ----------------------------------------
#
# Unicode has the letters of maths in each style as characters of their own:
# 𝑥 is an italic x, 𝐱 a bold one and 𝕩 a double-struck one. A few were
# characters before the rest, like ℝ, and their places in the lists are empty.

"Where the capital letters, the small letters, the digits, the capital Greek letters and the small Greek letters of each style start. 0 is for none."
const ALPHABETS = Dict{Symbol,NTuple{5,UInt32}}(
  :italic => (0x1d434, 0x1d44e, 0, 0, 0x1d6fc), :bold => (0x1d400, 0x1d41a, 0x1d7ce, 0x1d6a8, 0x1d6c2),
  :bolditalic => (0x1d468, 0x1d482, 0x1d7ce, 0x1d71c, 0x1d736), :bb => (0x1d538, 0x1d552, 0x1d7d8, 0, 0),
  :cal => (0x1d49c, 0x1d4b6, 0, 0, 0), :frak => (0x1d504, 0x1d51e, 0, 0, 0), :sf => (0x1d5a0, 0x1d5ba, 0x1d7e2, 0, 0),
  :tt => (0x1d670, 0x1d68a, 0x1d7f6, 0, 0))

"The letters that have a character of their own outside the lists"
const ODD_LETTERS = Dict{Tuple{Symbol,Char},Char}((:italic, 'h') => 'ℎ', (:bb, 'C') => 'ℂ', (:bb, 'H') => 'ℍ',
  (:bb, 'N') => 'ℕ', (:bb, 'P') => 'ℙ', (:bb, 'Q') => 'ℚ', (:bb, 'R') => 'ℝ', (:bb, 'Z') => 'ℤ', (:cal, 'B') => 'ℬ',
  (:cal, 'E') => 'ℰ', (:cal, 'F') => 'ℱ', (:cal, 'H') => 'ℋ', (:cal, 'I') => 'ℐ', (:cal, 'L') => 'ℒ', (:cal, 'M') => 'ℳ',
  (:cal, 'R') => 'ℛ', (:cal, 'e') => 'ℯ', (:cal, 'g') => 'ℊ', (:cal, 'o') => 'ℴ', (:frak, 'C') => 'ℭ', (:frak, 'H') => 'ℌ',
  (:frak, 'I') => 'ℑ', (:frak, 'R') => 'ℜ', (:frak, 'Z') => 'ℨ')

# The small Greek letters that come in two shapes have the second shape after ω in each list
const GREEK_ODD = Dict{Char,Int}('ϵ' => 26, 'ϑ' => 27, 'ϰ' => 28, 'ϕ' => 29, 'ϱ' => 30, 'ϖ' => 31)

"`c` in the letters of `variant`: italic for a letter of a formula, :upright for the letter as it is"
styled(c::Char, variant::Symbol) = begin
  variant == :upright && return c
  haskey(ODD_LETTERS, (variant, c)) && return ODD_LETTERS[(variant, c)]
  upper, lower, digit, Greek, greek = ALPHABETS[variant]
  'A' <= c <= 'Z' && upper != 0 && return Char(upper + (c - 'A'))
  'a' <= c <= 'z' && lower != 0 && return Char(lower + (c - 'a'))
  '0' <= c <= '9' && digit != 0 && return Char(digit + (c - '0'))
  '\u0391' <= c <= '\u03a9' && Greek != 0 && return Char(Greek + (c - '\u0391'))   # Α to Ω
  '\u03b1' <= c <= '\u03c9' && greek != 0 && return Char(greek + (c - '\u03b1'))   # α to ω
  haskey(GREEK_ODD, c) && greek != 0 && return Char(greek + GREEK_ODD[c])
  c
end

"The plain letter that the italic letter `c` is: x for 𝑥. Any other character is itself."
plain(c::Char) = begin
  c == 'ℎ' && return 'h'
  n = UInt32(c)
  0x1d434 <= n <= 0x1d44d && return 'A' + (n - 0x1d434)
  0x1d44e <= n <= 0x1d467 && return 'a' + (n - 0x1d44e)
  0x1d6fc <= n <= 0x1d714 && return '\u03b1' + (n - 0x1d6fc)
  for (odd, k) in GREEK_ODD
    n == 0x1d6fc + k && return odd
  end
  c
end

# --- reading TeX -------------------------------------------------------------------------

mutable struct Reader
  chars::Vector{Char}
  i::Int
  variant::Symbol             # the letters that a letter is read as
  problems::Vector{String}
end

"The next token of the TeX, or nothing at its end: a command like \\frac, or one character. The spaces between tokens don't count."
token!(r::Reader) = begin
  n = length(r.chars)
  while r.i <= n && isspace(r.chars[r.i])
    r.i += 1
  end
  r.i > n && return nothing
  c = r.chars[r.i]
  r.i += 1
  if c == '%'
    # The rest of the line is a comment
    while r.i <= n && r.chars[r.i] != '\n'
      r.i += 1
    end
    return token!(r)
  end
  (c == '\\' && r.i <= n) || return string(c)
  j = r.i
  while j <= n && isascii(r.chars[j]) && isletter(r.chars[j])
    j += 1
  end
  j == r.i && (j += 1)   # a command of one character that isn't a letter, like \{
  name = String(r.chars[r.i:j-1])
  r.i = j
  "\\" * name
end

"The next token, which stays to be read"
ahead(r::Reader) = begin
  i = r.i
  t = token!(r)
  r.i = i
  t
end

"The nodes up to the end of the TeX, or up to one of the tokens `stops`, which stays to be read"
list(r::Reader, stops=()) = begin
  out = Node[]
  while true
    t = ahead(r)
    (t === nothing || t in stops) && break
    token!(r)
    if t == "^" || t == "_"
      script!(out, t == "^", arg(r))
    elseif t == "'"
      n = 1
      while ahead(r) == "'"
        token!(r)
        n += 1
      end
      s = scripts!(out)
      push!(out, Scripts(s.base, s.sub, s.sup, s.primes + n))
    elseif t == "\\limits" || t == "\\nolimits"
      isempty(out) || (out[end] = Limits(out[end] isa Limits ? out[end].body : out[end], t == "\\limits"))
    else
      atom!(out, r, t)
    end
  end
  out
end

"Take the last node of `out` from it, as a node that has scripts. With no node there, the scripts are on nothing."
scripts!(out) = begin
  base = isempty(out) ? Group(Node[]) : pop!(out)
  base isa Scripts ? base : Scripts(base, nothing, nothing, 0)
end

"Give the last node of `out` the script `a`: over it for `up`, and under it otherwise"
script!(out, up::Bool, a::Node) = begin
  s = scripts!(out)
  # A second script in the same place goes after the first
  join(old) = old === nothing ? a : Group(Node[old, a])
  push!(out, up ? Scripts(s.base, s.sub, join(s.sup), s.primes) : Scripts(s.base, join(s.sub), s.sup, s.primes))
end

"What a command takes: the next token, or all that's between { and }"
arg(r::Reader) = begin
  t = token!(r)
  t === nothing && return Group(Node[])
  out = Node[]
  if t == "{"
    out = list(r, ("}",))
    ahead(r) == "}" && token!(r)
  else
    atom!(out, r, t)
  end
  length(out) == 1 && !(out[1] isa Style) ? out[1] : Group(out)
end

"The characters between { and } as they're written, for a command that takes words"
raw(r::Reader) = begin
  n = length(r.chars)
  while r.i <= n && isspace(r.chars[r.i])
    r.i += 1
  end
  r.i > n && return ""
  if r.chars[r.i] != '{'
    r.i += 1
    return string(r.chars[r.i-1])
  end
  depth, from = 1, r.i + 1
  r.i += 1
  while r.i <= n && depth > 0
    c = r.chars[r.i]
    c == '\\' && (r.i += 1)
    c == '{' && (depth += 1)
    c == '}' && (depth -= 1)
    r.i += 1
  end
  String(r.chars[from:min(n, r.i - 1 - (depth == 0))])
end

"The bracket that the next token names, for \\left, \\right and \\big. '.' is no bracket."
delimiter(r::Reader) = begin
  t = token!(r)
  t === nothing ? '.' : get(DELIMS, t, length(t) == 1 ? only(t) : '.')
end

"A length like 2em or 3pt, in mu"
const LENGTH = r"^\s*(-?\d*\.?\d+)\s*(em|ex|pt|mu|px|mm|cm)\s*$"
in_mu(text) = begin
  m = match(LENGTH, text)
  m === nothing && return 0.0
  parse(Float64, m[1]) * Dict("em" => 18.0, "ex" => 8.0, "pt" => 1.8, "mu" => 1.0, "px" => 1.35, "mm" => 5.1, "cm" => 51.0)[m[2]]
end

"The rows of cells up to one of `stops`. & ends a cell and \\\\ ends a row."
table(r::Reader, stops=()) = begin
  rows, row = Vector{Group}[], Group[]
  while true
    push!(row, Group(list(r, ("&", "\\\\", "\\cr", stops...))))
    t = ahead(r)
    if t == "&"
      token!(r)
    elseif t == "\\\\" || t == "\\cr"
      token!(r)
      # \\[2pt] asks for more room under the row, which isn't given
      m = match(r"^\s*\[[^\]\[]*(em|ex|pt|mu|px|mm|cm)\s*\]", String(r.chars[r.i:min(end, r.i + 20)]))
      m === nothing || (r.i += length(m.match))
      push!(rows, row)
      row = Group[]
    else
      break
    end
  end
  push!(rows, row)
  # A \\ after the last row starts no row
  length(rows) > 1 && all(cell -> isempty(cell.items), rows[end]) && pop!(rows)
  rows
end

"Add what the token `t` stands for to `out`"
atom!(out, r::Reader, t::String) = begin
  if t == "{"
    items = list(r, ("}",))
    ahead(r) == "}" && token!(r)
    push!(out, Group(items))
  elseif t == "}" || t == "&"
    # One that nothing opened is left out
  elseif !startswith(t, '\\') || t == "\\"
    c = only(t)
    if c == '~'
      push!(out, Space(5.0))
    elseif haskey(KEYS, c)
      push!(out, Sym(KEYS[c]...))
    elseif isletter(c) || isdigit(c)
      push!(out, Sym(styled(c, r.variant), get(CLASSES, c, :ord)))
    else
      push!(out, Sym(c, get(CLASSES, c, :ord)))
    end
  else
    command!(out, r, String(SubString(t, 2)))
  end
  out
end

"Add what the command `name` makes to `out`. It reads what the command takes."
command!(out, r::Reader, name::String) = begin
  if haskey(SYMBOLS, name)
    c, class = SYMBOLS[name]
    # A small Greek letter slants, and a capital one is upright, as TeX has them
    push!(out, Sym('\u03b1' <= c <= '\u03c9' || haskey(GREEK_ODD, c) || r.variant != :italic ? styled(c, r.variant) : c, class))
  elseif haskey(FUNCTIONS, name)
    push!(out, Words(get(FUNCTION_WORDS, name, name), :op, FUNCTIONS[name], false))
  elseif name in ("frac", "dfrac", "tfrac", "cfrac")
    num = arg(r)
    push!(out, Frac(num, arg(r), true, '.', '.', name == "frac" ? 0 : name == "tfrac" ? 2 : 1))
  elseif name in ("binom", "dbinom", "tbinom")
    num = arg(r)
    push!(out, Frac(num, arg(r), false, '(', ')', name == "binom" ? 0 : name == "tbinom" ? 2 : 1))
  elseif name == "sqrt"
    degree = nothing
    if ahead(r) == "["
      token!(r)
      degree = Group(list(r, ("]",)))
      ahead(r) == "]" && token!(r)
    end
    push!(out, Root(arg(r), degree))
  elseif name == "left"
    delims, parts = Char[delimiter(r)], Vector{Node}[]
    while true
      push!(parts, list(r, ("\\right", "\\middle")))
      t = token!(r)
      t === nothing && (push!(delims, '.'); break)
      push!(delims, delimiter(r))
      t == "\\right" && break
    end
    push!(out, Fenced(delims, parts))
  elseif name == "right" || name == "middle"
    delimiter(r)   # one that no \left opened is left out
  elseif name == "begin"
    kind = raw(r)
    align = kind in ("array", "subarray", "alignat", "alignat*", "alignedat") ? raw(r) : ""
    rows = table(r, ("\\end",))
    ahead(r) == "\\end" && (token!(r); raw(r))
    haskey(BLOCKS, kind) || push!(r.problems, "\\begin{$kind}")
    what, left, right, columns = get(BLOCKS, kind, BLOCKS["gathered"])
    startswith(kind, "array") && (columns = filter(in("lcr"), align); isempty(columns) && (columns = "c"))
    push!(out, Rows(rows, what, left, right, columns))
  elseif name == "end"
    raw(r)
  elseif haskey(TEXTS, name)
    letters = TEXTS[name]
    text = replace(raw(r), r"\\([^A-Za-z])" => s"\1", r"\s+" => " ")
    push!(out, Words(letters == :upright ? text : map(c -> styled(c, letters), text), :ord, false, false))
  elseif name == "operatorname"
    star = r.i <= length(r.chars) && r.chars[r.i] == '*'
    star && (r.i += 1)
    push!(out, Words(replace(raw(r), r"\\([,;: ])" => " ", r"\s+" => " "), :op, star, false))
  elseif haskey(VARIANTS, name)
    was, r.variant = r.variant, VARIANTS[name]
    push!(out, arg(r))
    r.variant = was
  elseif haskey(ACCENTS, name)
    push!(out, Accent(ACCENTS[name], arg(r), startswith(name, "wide")))
  elseif name in ("overline", "underline", "underbar")
    push!(out, Bar(arg(r), name == "overline"))
  elseif haskey(STRETCHES, name)
    c, over = STRETCHES[name]
    push!(out, Stretch(c, arg(r), over))
  elseif name in ("overset", "stackrel", "underset")
    script = arg(r)
    base = arg(r)
    class = name == "stackrel" ? :rel : classof(base)
    push!(out, name == "underset" ? Stack(base, nothing, script, class) : Stack(base, script, nothing, class))
  elseif haskey(SPACES, name)
    push!(out, Space(SPACES[name]))
  elseif name in ("hspace", "hskip", "kern", "mkern", "mskip", "hspace*")
    push!(out, Space(in_mu(raw(r))))
  elseif haskey(STYLES, name)
    push!(out, Style(STYLES[name]))
  elseif haskey(CLASSERS, name)
    push!(out, Classed(CLASSERS[name], arg(r)))
  elseif occursin(BIG, name)
    m = match(BIG, name)
    size = findfirst(==(m[1]), ("big", "Big", "bigg", "Bigg"))
    push!(out, Sized(delimiter(r), size, m[2] == "l" ? :open : m[2] == "r" ? :close : m[2] == "m" ? :rel : :ord))
  elseif name == "not"
    found = Node[]
    t = token!(r)
    t === nothing || atom!(found, r, t)
    if length(found) == 1 && found[1] isa Sym && haskey(NEGATED, found[1].char)
      push!(out, Sym(NEGATED[found[1].char], found[1].class))
    else
      append!(out, found)
    end
  elseif name == "bmod"
    push!(out, Words("mod", :bin, false, false))
  elseif name in ("pmod", "pod", "mod")
    push!(out, Space(name == "mod" ? 12.0 : 8.0))
    name == "mod" || push!(out, Sym('(', :open))
    name == "pod" || append!(out, [Words("mod", :ord, false, false), Space(6.0)])
    push!(out, arg(r))
    name == "mod" || push!(out, Sym(')', :close))
  elseif name == "phantom" || name == "hphantom" || name == "vphantom"
    push!(out, Phantom(arg(r)))
  elseif name in ("boxed", "fbox")
    push!(out, Boxed(arg(r)))
  elseif name == "textcolor" || name == "colorbox"
    raw(r)   # the colour, which isn't used
    push!(out, arg(r))
  elseif name in ("color", "label", "tag", "tag*")
    raw(r)
  elseif name in ("nonumber", "notag", "hline", "displaylimits", "relax", "allowbreak", "nobreak", "hfill", "strut",
                  "mathstrut", "/", "-", "\\", "cr", "bigl", "noindent", "centering", "limits", "nolimits")
    # These change nothing that shows here
  else
    push!(r.problems, "\\" * name)
    push!(out, Words("\\" * name, :ord, false, true))
  end
  out
end

"""
The nodes of the formula `tex`, with the commands in it that aren't known.
Lines that end in \\\\ outside any block are rows: they're lined up at their
&, or each is in the middle when they have none.
"""
nodes(tex::AbstractString) = begin
  r = Reader(collect(tex), 1, :italic, String[])
  rows = table(r)
  out = length(rows) == 1 && length(rows[1]) == 1 ? rows[1][1].items :
        Node[Rows(rows, any(row -> length(row) > 1, rows) ? :aligned : :gathered, '.', '.', any(row -> length(row) > 1, rows) ? "rl" : "c")]
  (out, r.problems)
end

"The class of a node: how much room it gets beside its neighbours"
classof(n::Node) = :ord
classof(n::Sym) = n.class
classof(n::Scripts) = classof(n.base)
classof(n::Limits) = classof(n.body)
classof(n::Fenced) = :inner
classof(n::Words) = n.class
classof(n::Space) = :space
classof(n::Stack) = n.class
classof(n::Sized) = n.class
classof(n::Classed) = n.class
classof(n::Rows) = n.left == '.' && n.right == '.' ? :ord : :inner

# --- setting a formula -------------------------------------------------------------------
#
# Each node is set as a box: how wide it is, how far it goes up from the line
# that it stands on and how far down, and the marks that draw it. A mark is a
# glyph or a filled rectangle. Lengths are in px, and up is positive.

"A glyph at a size, or a rectangle. A glyph's place is where it starts on the line that it stands on. A rectangle's is its bottom left corner."
struct Mark
  glyph::UInt16   # 0 for a rectangle
  x::Float64
  y::Float64
  w::Float64      # a rectangle's width, or a glyph's size
  h::Float64
  bad::Bool       # it's part of the name of a command that isn't known
end

struct Box
  w::Float64
  h::Float64
  d::Float64
  marks::Vector{Mark}
  slant::Float64    # how far the top of its last glyph leans past `w`
  glyph::UInt16     # the glyph that it's the box of, or 0 for a box of more than one
end

Box(w, h, d, marks=Mark[]) = Box(w, h, d, marks, 0.0, 0x0000)

"The marks of `b`, moved right by `dx` and up by `dy`"
moved(b::Box, dx, dy) = Mark[Mark(m.glyph, m.x + dx, m.y + dy, m.w, m.h, m.bad) for m in b.marks]

"`b`, `dy` higher"
raised(b::Box, dy) = Box(b.w, b.h + dy, b.d - dy, moved(b, 0.0, dy), b.slant, b.glyph)

"Where a node is set: the font, the size of the text around the formula, and the style, which says how big the node is"
struct Place
  font::MathFont
  size::Float64
  level::Int        # 0 for a formula on a line of its own, 1 for one in a line of text, 2 for a script and 3 for a script's script
  cramped::Bool     # under something, like the part under the line of a fraction, where superscripts go up less
end

Place(c::Place; level=c.level, cramped=c.cramped) = Place(c.font, c.size, level, cramped)

"The size of the glyphs at `c`"
em(c::Place) = c.size * (c.level <= 1 ? 1.0 : c.font.numbers[c.level == 2 ? :scriptPercentScaleDown : :scriptScriptPercentScaleDown] / 100)
unit(c::Place) = em(c) / c.font.em
mu(c::Place) = em(c) / 18
"One of the font's lengths, by its name in the MATH table, in px at `c`"
len(c::Place, name::Symbol) = c.font.numbers[name] * unit(c)
"How far the middle of a sign like + is over the line that the letters stand on"
axis(c::Place) = len(c, :axisHeight)

above(c::Place) = Place(c, level=c.level <= 1 ? 2 : 3)                  # a superscript
below(c::Place) = Place(c, level=c.level <= 1 ? 2 : 3, cramped=true)    # a subscript
upper(c::Place) = Place(c, level=min(c.level + 1, 3))                   # the top of a fraction
lower(c::Place) = Place(c, level=min(c.level + 1, 3), cramped=true)     # and its bottom
cramp(c::Place) = Place(c, cramped=true)

"The box of one glyph"
glyphbox(c::Place, g::UInt16; bad=false) = begin
  wide, _, top, _, bottom = measure(c.font, g)
  s = unit(c)
  Box(wide * s, top * s, bottom * s, [Mark(g, 0.0, 0.0, em(c), 0.0, bad)], get(c.font.slant, g, 0.0) * s, g)
end

charbox(c::Place, char::Char) = glyphbox(c, glyph(c.font, char))

"`b` moved up or down so that its middle is level with the middle of a + sign"
centred(c::Place, b::Box) = raised(b, axis(c) - (b.h - b.d) / 2)

"""
The glyph `g` at least `target` px long: tall, or wide when `tall` is false.
The font has bigger shapes of a bracket, and pieces that make one of any
length. A tall one that's made of pieces stands on the line.
"""
stretched(c::Place, g::UInt16, target; tall=true) = begin
  base = glyphbox(c, g)
  long(b) = tall ? b.h + b.d : b.w
  shapes = get(tall ? c.font.tall : c.font.wide, g, nothing)
  (shapes === nothing || long(base) >= target) && return base
  for (shape, _) in shapes.whole
    b = glyphbox(c, shape)
    long(b) >= target && return b
  end
  isempty(shapes.pieces) && return isempty(shapes.whole) ? base : glyphbox(c, last(shapes.whole)[1])
  # The pieces that repeat are there as many times as it takes
  s = unit(c)
  pieces(n) = [p for p in shapes.pieces for _ in 1:(p.extender ? n : 1)]
  longest(ps) = sum(p -> p.long, ps) - c.font.overlap * (length(ps) - 1)
  n = 0
  while longest(pieces(n)) * s < target && n < 400 && any(p -> p.extender, shapes.pieces)
    n += 1
  end
  ps = pieces(n)
  # The pieces lie over each other by a little more than they must, to make the length that's asked for
  more = length(ps) > 1 ? max(0.0, longest(ps) - target / s) / (length(ps) - 1) : 0.0
  marks, at, across, up, down = Mark[], 0.0, 0.0, 0.0, 0.0
  for (k, p) in enumerate(ps)
    wide, _, top, _, bottom = measure(c.font, p.glyph)
    if tall
      push!(marks, Mark(p.glyph, 0.0, (at + bottom) * s, em(c), 0.0, false))
      across = max(across, wide)
    else
      push!(marks, Mark(p.glyph, at * s, 0.0, em(c), 0.0, false))
      up, down = max(up, top), max(down, bottom)
    end
    at += p.long
    k < length(ps) && (at -= min(c.font.overlap + more, p.stop, ps[k+1].start))
  end
  tall ? Box(across * s, at * s, 0.0, marks) : Box(at * s, up * s, down * s, marks)
end

"A node's box and its class, in a row of nodes"
struct Item
  box::Box
  class::Symbol
  tight::Bool   # it's in a script, where there's less room between the nodes
end

const CLASS_ORDER = (:ord, :op, :bin, :rel, :open, :close, :punct, :inner)

# The room between two nodes, by the class of the first and of the second: 1 is thin, 2 is medium and 3 is thick.
# One that's less than 0 is only there outside a script. It's the table of chapter 18 of The TeXbook.
const ROOM = ((0, 1, -2, -3, 0, 0, 0, -1),
              (1, 1, 0, -3, 0, 0, 0, -1),
              (-2, -2, 0, 0, -2, 0, 0, -2),
              (-3, -3, 0, 0, -3, 0, 0, -3),
              (0, 0, 0, 0, 0, 0, 0, 0),
              (0, 1, -2, -3, 0, 0, 0, -1),
              (-1, -1, 0, -1, -1, -1, -1, -1),
              (-1, 1, -2, -3, -1, 0, -1, -1))

"The room between a node of the class `a` and one of the class `b` after it, in mu"
room(a::Symbol, b::Symbol, tight::Bool) = begin
  n = ROOM[findfirst(==(a), CLASS_ORDER)][findfirst(==(b), CLASS_ORDER)]
  n < 0 && tight ? 0 : abs(n) + (n == 0 ? 0 : 2)
end

"The boxes of `nodes`, each with its class. A \\displaystyle or one of the others changes the size of the nodes after it."
items(c::Place, nodes) = begin
  out = Item[]
  for n in nodes
    if n isa Style
      c = Place(c, level=n.level)
      continue
    end
    push!(out, Item(set(c, n), classof(n), c.level >= 2))
  end
  out
end

"Put the boxes of `items` in a row, with the room between them that their classes ask for"
pack(c::Place, items::Vector{Item}) = begin
  length(items) == 1 && return items[1].box
  classes = Symbol[it.class for it in items]
  # A + or a − with nothing to add to or take from is a sign, not an operation: the − of −x and of (−x)
  prev = 0
  for (i, class) in enumerate(classes)
    class == :space && continue
    if class == :bin && (prev == 0 || classes[prev] in (:bin, :op, :rel, :open, :punct))
      classes[i] = :ord
    elseif class in (:rel, :close, :punct) && prev != 0 && classes[prev] == :bin
      classes[prev] = :ord
    end
    prev = i
  end
  prev != 0 && classes[prev] == :bin && (classes[prev] = :ord)
  marks, x, h, d, prev = Mark[], 0.0, 0.0, 0.0, 0
  for (i, it) in enumerate(items)
    if classes[i] != :space
      if prev != 0
        x += room(classes[prev], classes[i], it.tight) * mu(c)
        # A letter that leans gets room for its top before a node that stands up straight
        before = items[prev].box
        prev == i - 1 && before.glyph != 0 && !(it.box.glyph != 0 && it.box.slant > 0) && (x += before.slant)
      end
      prev = i
    end
    append!(marks, moved(it.box, x, 0.0))
    x += it.box.w
    h, d = max(h, it.box.h), max(d, it.box.d)
  end
  Box(x, h, d, marks)
end

"The box of a row of nodes"
row(c::Place, nodes) = pack(c, items(c, nodes))

"The box of the node `n` set at `c`"
set(c::Place, n::Sym) = begin
  n.class == :op || return charbox(c, n.char)
  # A sum sign is bigger in a formula on a line of its own, and its middle is level with the middle of a + sign
  g = glyph(c.font, n.char)
  b = centred(c, c.level == 0 ? stretched(c, g, len(c, :displayOperatorMinHeight)) : glyphbox(c, g))
  Box(b.w, b.h, b.d, b.marks, b.slant, 0x0000)
end

set(c::Place, n::Group) = row(c, n.items)
set(c::Place, n::Space) = Box(n.mu * mu(c), 0.0, 0.0)
set(c::Place, n::Limits) = set(c, n.body)
set(c::Place, n::Classed) = set(c, n.body)
set(c::Place, n::Phantom) = (b = set(c, n.body); Box(b.w, b.h, b.d))
set(c::Place, n::Style) = Box(0.0, 0.0, 0.0)

set(c::Place, n::Words) = begin
  marks, x, h, d = Mark[], 0.0, 0.0, 0.0
  s = unit(c)
  for char in n.text
    g = glyph(c.font, char)
    wide, _, top, _, bottom = measure(c.font, g)
    push!(marks, Mark(g, x, 0.0, em(c), 0.0, n.bad))
    x += wide * s
    h, d = max(h, top * s), max(d, bottom * s)
  end
  Box(x, h, d, marks)
end

"True when the scripts of `n` go over and under it at `c`, and not beside it"
limited(c::Place, n::Node) = false
limited(c::Place, n::Limits) = n.on
limited(c::Place, n::Sym) = n.class == :op && c.level == 0 && !(n.char in INTEGRALS)
limited(c::Place, n::Words) = n.limits && c.level == 0
limited(c::Place, n::Classed) = n.class == :op && c.level == 0
limited(c::Place, n::Stretch) = true

"True for a sign like ∫, whose scripts go beside it in the places that its lean leaves"
bigsign(n::Node) = n isa Sym && n.class == :op
bigsign(n::Limits) = bigsign(n.body)

set(c::Place, n::Scripts) = begin
  nucleus = set(c, n.base)
  sup = n.sup === nothing ? nothing : set(above(c), n.sup)
  sub = n.sub === nothing ? nothing : set(below(c), n.sub)
  # The font's prime is small and high already, so it's set at the size of the letter and on the letter's line
  primes = n.primes == 0 ? nothing : pack(c, [Item(charbox(c, '′'), :ord, false) for _ in 1:n.primes])
  limited(c, n.base) || return scripted(c, nucleus, sup, sub, bigsign(n.base), primes)
  primes === nothing || (nucleus = pack(c, [Item(nucleus, :ord, false), Item(primes, :ord, false)]))
  stacked(c, nucleus, sup, sub)
end

"`nucleus` with `sup` after it and above, and `sub` after it and below. Either can be nothing. `primes` go between it and `sup`."
scripted(c::Place, nucleus::Box, sup, sub, big::Bool, primes=nothing) = begin
  up = down = 0.0
  if nucleus.glyph == 0
    # Scripts on more than one character go by its top and bottom
    up = nucleus.h - len(c, :superscriptBaselineDropMax)
    down = nucleus.d + len(c, :subscriptBaselineDropMin)
  end
  if sup !== nothing
    up = max(up, len(c, c.cramped ? :superscriptShiftUpCramped : :superscriptShiftUp), sup.d + len(c, :superscriptBottomMin))
  end
  if sub !== nothing
    down = max(down, len(c, :subscriptShiftDown))
    sup === nothing && (down = max(down, sub.h - len(c, :subscriptTopMax)))
  end
  if sup !== nothing && sub !== nothing
    short = len(c, :subSuperscriptGapMin) - ((up - sup.d) - (sub.h - down))
    if short > 0
      down += short
      low = len(c, :superscriptBottomMaxWithSubscript) - (up - sup.d)
      low > 0 && (up += low; down -= low)
    end
  end
  marks = copy(nucleus.marks)
  w, h, d = nucleus.w, nucleus.h, nucleus.d
  after = len(c, :spaceAfterScript)
  x = nucleus.w + (big ? 0.0 : nucleus.slant)
  if primes !== nothing
    append!(marks, moved(primes, x, 0.0))
    x += primes.w
    w, h = max(w, x + (sup === nothing ? after : 0.0)), max(h, primes.h)
  end
  if sup !== nothing
    append!(marks, moved(sup, x, up))
    w, h = max(w, x + sup.w + after), max(h, up + sup.h)
  end
  if sub !== nothing
    x = nucleus.w - (big ? nucleus.slant : 0.0)
    append!(marks, moved(sub, x, -down))
    w, d = max(w, x + sub.w + after), max(d, down + sub.d)
  end
  Box(w, h, d, marks)
end

"`nucleus` with `over` in the middle over it and `under` in the middle under it. Either can be nothing."
stacked(c::Place, nucleus::Box, over, under) = begin
  w = max(nucleus.w, over === nothing ? 0.0 : over.w, under === nothing ? 0.0 : under.w)
  marks = moved(nucleus, (w - nucleus.w) / 2, 0.0)
  h, d = nucleus.h, nucleus.d
  if over !== nothing
    y = nucleus.h + max(len(c, :upperLimitGapMin) + over.d, len(c, :upperLimitBaselineRiseMin))
    append!(marks, moved(over, (w - over.w) / 2 + nucleus.slant / 2, y))
    h = y + over.h
  end
  if under !== nothing
    y = nucleus.d + max(len(c, :lowerLimitGapMin) + under.h, len(c, :lowerLimitBaselineDropMin))
    append!(marks, moved(under, (w - under.w) / 2 - nucleus.slant / 2, -y))
    d = y + under.d
  end
  Box(w, h, d, marks)
end

set(c::Place, n::Stack) = stacked(c, set(c, n.base), n.over === nothing ? nothing : set(above(c), n.over),
                                  n.under === nothing ? nothing : set(below(c), n.under))

set(c::Place, n::Frac) = begin
  n.style == 0 || (c = Place(c, level=n.style - 1))
  display = c.level == 0
  num, den = set(upper(c), n.num), set(lower(c), n.den)
  a = axis(c)
  thick = n.rule ? len(c, :fractionRuleThickness) : 0.0
  if n.rule
    up = max(len(c, display ? :fractionNumeratorDisplayStyleShiftUp : :fractionNumeratorShiftUp),
             a + thick / 2 + len(c, display ? :fractionNumDisplayStyleGapMin : :fractionNumeratorGapMin) + num.d)
    down = max(len(c, display ? :fractionDenominatorDisplayStyleShiftDown : :fractionDenominatorShiftDown),
               thick / 2 - a + len(c, display ? :fractionDenomDisplayStyleGapMin : :fractionDenominatorGapMin) + den.h)
  else
    up = len(c, display ? :stackTopDisplayStyleShiftUp : :stackTopShiftUp)
    down = len(c, display ? :stackBottomDisplayStyleShiftDown : :stackBottomShiftDown)
    short = len(c, display ? :stackDisplayStyleGapMin : :stackGapMin) - ((up - num.d) - (den.h - down))
    short > 0 && (up += short / 2; down += short / 2)
  end
  w = max(num.w, den.w)
  side = 0.12 * em(c)   # a little room on each side, as TeX leaves
  marks = [moved(num, side + (w - num.w) / 2, up); moved(den, side + (w - den.w) / 2, -down)]
  n.rule && push!(marks, Mark(0x0000, side, a - thick / 2, w, thick, false))
  box = Box(w + 2side, up + num.h, down + den.d, marks)
  n.left == '.' && n.right == '.' ? box : fenced(c, [n.left, n.right], [box])
end

set(c::Place, n::Root) = begin
  body = set(cramp(c), n.body)
  thick = len(c, :radicalRuleThickness)
  gap = len(c, c.level == 0 ? :radicalDisplayStyleVerticalGap : :radicalVerticalGap)
  sign = stretched(c, glyph(c.font, '√'), body.h + body.d + gap + thick)
  tall = sign.h + sign.d
  # A sign that's taller than it has to be leaves half of what's spare over the body
  gap += max(0.0, tall - (body.h + body.d + gap + thick)) / 2
  top = body.h + gap + thick   # of the line over the body, which starts at the top of the sign
  sign = raised(sign, top - sign.h)
  marks = [sign.marks; moved(body, sign.w, 0.0); Mark(0x0000, sign.w, top - thick, body.w, thick, false)]
  box = Box(sign.w + body.w, top + len(c, :radicalExtraAscender), max(body.d, sign.d), marks)
  n.degree === nothing && return box
  degree = set(Place(c, level=3), n.degree)
  before, after = len(c, :radicalKernBeforeDegree), len(c, :radicalKernAfterDegree)
  y = c.font.numbers[:radicalDegreeBottomRaisePercent] / 100 * tall - sign.d + degree.d
  x = max(0.0, before + degree.w + after)   # where the sign starts: the degree is over its start
  Box(x + box.w, max(box.h, y + degree.h), box.d, [moved(degree, max(0.0, before), y); moved(box, x, 0.0)])
end

"The boxes `parts` with the brackets `delims` before, between and after them, each as tall as the tallest part"
fenced(c::Place, delims::Vector{Char}, parts::Vector{Box}) = begin
  a = axis(c)
  reach = max(maximum(b -> b.h, parts, init=0.0) - a, maximum(b -> b.d, parts, init=0.0) + a)
  # A bracket can be a little shorter than what it's round, as TeX lets it
  target = max(2reach * 0.901, 2reach - 0.5 * em(c))
  out = Item[]
  for (k, char) in enumerate(delims)
    class = k == 1 ? :open : k == length(delims) ? :close : :ord
    push!(out, Item(char == '.' ? Box(0.12 * em(c), 0.0, 0.0) : centred(c, stretched(c, glyph(c.font, char), target)), class, c.level >= 2))
    k <= length(parts) && push!(out, Item(parts[k], :ord, c.level >= 2))
  end
  pack(c, out)
end

set(c::Place, n::Fenced) = fenced(c, n.delims, Box[row(c, part) for part in n.parts])

const BIG_SIZES = (1.2, 1.8, 2.4, 3.0)   # how tall the brackets of \big, \Big, \bigg and \Bigg are, in the size of the text

set(c::Place, n::Sized) =
  n.char == '.' ? Box(0.0, 0.0, 0.0) : centred(c, stretched(c, glyph(c.font, n.char), BIG_SIZES[n.size] * em(c)))

set(c::Place, n::Accent) = begin
  body = set(cramp(c), n.body)
  f, s = c.font, unit(c)
  g = glyph(f, n.char)
  if n.wide && haskey(f.wide, g)
    # The widest shape of the mark that's no wider than what it's over
    for (shape, _) in f.wide[g].whole
      wide = measure(f, shape)
      wide[4] - wide[2] > body.w / s && break
      g = shape
    end
  end
  _, left, top, right, _ = measure(f, g)
  # The mark goes over the place that the font gives for it: over the top of a letter that leans, not over its middle
  from = get(f.top, g, (left + right) / 2) * s
  to = body.glyph != 0 && haskey(f.top, body.glyph) ? f.top[body.glyph] * s : body.w / 2
  up = body.h - min(body.h, len(c, :accentBaseHeight))
  Box(body.w, max(body.h, up + top * s), body.d, [body.marks; Mark(g, to - from, up, em(c), 0.0, false)], body.slant, 0x0000)
end

set(c::Place, n::Bar) = begin
  body = set(n.over ? cramp(c) : c, n.body)
  if n.over
    gap, thick = len(c, :overbarVerticalGap), len(c, :overbarRuleThickness)
    Box(body.w, body.h + gap + thick + len(c, :overbarExtraAscender), body.d,
        [body.marks; Mark(0x0000, 0.0, body.h + gap, body.w, thick, false)], body.slant, 0x0000)
  else
    gap, thick = len(c, :underbarVerticalGap), len(c, :underbarRuleThickness)
    Box(body.w, body.h, body.d + gap + thick + len(c, :underbarExtraDescender),
        [body.marks; Mark(0x0000, 0.0, -body.d - gap - thick, body.w, thick, false)])
  end
end

set(c::Place, n::Stretch) = begin
  body = set(n.over ? cramp(c) : c, n.body)
  mark = stretched(c, glyph(c.font, n.char), body.w, tall=false)
  w = max(body.w, mark.w)
  gap = len(c, n.over ? :overbarVerticalGap : :underbarVerticalGap)
  at = moved(body, (w - body.w) / 2, 0.0)
  # The ink of the mark, not the line that it stands on, is the gap away from the body
  n.over ? Box(w, body.h + gap + mark.d + mark.h, body.d, [at; moved(mark, (w - mark.w) / 2, body.h + gap + mark.d)]) :
           Box(w, body.h, body.d + gap + mark.h + mark.d, [at; moved(mark, (w - mark.w) / 2, -body.d - gap - mark.h)])
end

set(c::Place, n::Boxed) = begin
  body = set(c, n.body)
  pad, thick = 0.3 * em(c), max(0.04 * em(c), 0.6)
  w, h, d = body.w + 2pad + 2thick, body.h + pad + thick, body.d + pad + thick
  frame = [Mark(0x0000, 0.0, -d, w, thick, false), Mark(0x0000, 0.0, h - thick, w, thick, false),
           Mark(0x0000, 0.0, -d, thick, h + d, false), Mark(0x0000, w - thick, -d, thick, h + d, false)]
  Box(w, h, d, [moved(body, pad + thick, 0.0); frame])
end

set(c::Place, n::Rows) = begin
  lined = n.kind in (:aligned, :gathered)
  # The lines of a formula are as big as the formula. The cells of a matrix are the size of a formula in a line of text.
  cell = lined ? c : Place(c, level=n.kind == :small ? 2 : max(c.level, 1), cramped=false)
  # In lines that are lined up, each second cell starts with a sign like =, which gets the room that it has after a letter
  boxes = [Box[row(cell, n.kind == :aligned && iseven(k) ? Node[Group(Node[]); g.items] : g.items) for (k, g) in enumerate(r)] for r in n.rows]
  columns = maximum(length, boxes, init=0)
  columns == 0 && return Box(0.0, 0.0, 0.0)
  size = em(cell)
  widths = [maximum(r -> length(r) >= k ? r[k].w : 0.0, boxes) for k in 1:columns]
  # Each row is at least as tall as a line of text, so the rows of a matrix are the same distance apart
  more = lined ? 0.15size : 0.0
  heights = [max(0.84size, maximum(b -> b.h, r, init=0.0)) + more for r in boxes]
  depths = [max(0.36size, maximum(b -> b.d, r, init=0.0)) + more for r in boxes]
  gap(k) = n.kind == :aligned ? (iseven(k) ? 2size : 0.0) : n.kind == :small ? 0.5size : size   # after column k
  side(k) = n.kind == :aligned ? (isodd(k) ? 'r' : 'l') : n.align[min(k, length(n.align))]
  lefts = [sum(widths[1:k-1], init=0.0) + sum(gap, 1:k-1, init=0.0) for k in 1:columns]
  w = lefts[end] + widths[end]
  tall = sum(heights) + sum(depths)
  marks, y = Mark[], tall / 2 + axis(c)
  for (i, r) in enumerate(boxes)
    y -= heights[i]
    for (k, b) in enumerate(r)
      spare = widths[k] - b.w
      append!(marks, moved(b, lefts[k] + (side(k) == 'l' ? 0.0 : side(k) == 'r' ? spare : spare / 2), y))
    end
    y -= depths[i]
  end
  box = Box(w, tall / 2 + axis(c), tall / 2 - axis(c), marks)
  n.left == '.' && n.right == '.' ? box : fenced(c, [n.left, n.right], [box])
end

# --- a formula, ready to draw ------------------------------------------------------------

"A formula that's been set: its box, and the commands of its TeX that aren't known"
struct Formula
  box::Box
  problems::Vector{String}
end

wide(f::Formula) = f.box.w
"How far the formula goes up from the line that it stands on"
height(f::Formula) = f.box.h
"And how far down"
depth(f::Formula) = f.box.d

const set_formulas = Dict{Tuple{String,Float64,Bool},Formula}()

"""
The formula `tex`, set in text of `size` px. With `display` it's set for a
line of its own, where fractions and sum signs are bigger than in a line of
text. It's kept, so it costs nothing to ask for it in every frame. `available`
has to be true.
"""
formula(tex::AbstractString, size::Real, display::Bool=false) = begin
  length(set_formulas) > 2000 && empty!(set_formulas)
  get!(set_formulas, (String(tex), Float64(size), display)) do
    found, problems = nodes(tex)
    Formula(row(Place(font(), Float64(size), display ? 0 : 1, false), found), problems)
  end
end

"A paint that fills with `colour`"
fill_paint(colour) = begin
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_paint_set_color(paint, sk_color(colour))
  Skia.sk_paint_set_style(paint, Skia.SK_PAINT_STYLE_FILL)
  paint
end

"""
Draw `f` on the canvas `ctx` in `colour`, with its left end at `x` and the
line that it stands on at `y`. The name of a command that isn't known is in
the colour `wrong`.
"""
paint(ctx, f::Formula, x, y, colour, wrong=colour) = begin
  face = font()
  paints = (fill_paint(colour), fill_paint(wrong))
  for m in f.box.marks
    p = paints[m.bad ? 2 : 1]
    if m.glyph == 0
      rect = Ref(Skia.sk_rect_t(Float32(x + m.x), Float32(y - m.y - m.h), Float32(x + m.x + m.w), Float32(y - m.y)))
      Skia.sk_canvas_draw_rect(ctx, rect, p)
    else
      Skia.sk_canvas_draw_simple_text(ctx, Ref(m.glyph), Csize_t(2), Skia.SK_TEXT_ENCODING_GLYPH_ID,
                                      Float32(x + m.x), Float32(y - m.y), sized(face, m.w), p)
    end
  end
  foreach(Skia.sk_paint_delete, paints)
end

# --- a formula as MathML -----------------------------------------------------------------
#
# A page of HTML holds a formula as MathML, which every browser sets itself.

escaped(s) = replace(string(s), "&" => "&amp;", "<" => "&lt;", ">" => "&gt;", "\"" => "&quot;")

"The marks that go over a node, as MathML writes them"
const ACCENT_SIGNS = Dict{Char,String}('̂' => "^", '̃' => "~", '̄' => "¯", '̇' => "˙", '̈' => "¨",
  '⃛' => "⃛", '⃗' => "→", '̌' => "ˇ", '̆' => "˘", '́' => "´", '̀' => "`", '̊' => "˚")

isnumeral(n) = n isa Sym && n.class == :ord && (isdigit(n.char) || n.char == '.')

"The nodes `items` as MathML. The digits of a number are one element."
ml(items::Vector{<:Node}) = begin
  out, i = IOBuffer(), 1
  while i <= length(items)
    if isnumeral(items[i]) && isdigit(items[i].char)
      j = i
      while j < length(items) && isnumeral(items[j+1])
        j += 1
      end
      # A full stop at the end of a number ends the sentence, not the number
      items[j].char == '.' && (j -= 1)
      print(out, "<mn>", String([n.char for n in items[i:j]]), "</mn>")
      i = j + 1
    else
      print(out, ml(items[i]))
      i += 1
    end
  end
  String(take!(out))
end

"One element that holds `items`"
mrow(items::Vector{<:Node}) = "<mrow>" * ml(items) * "</mrow>"
mrow(n::Node) = n isa Group ? mrow(n.items) : ml(n)

fence(c::Char) = c == '.' ? "" : "<mo fence=\"true\">" * escaped(c) * "</mo>"

ml(n::Sym) = begin
  c = plain(n.char)
  n.class == :ord && isdigit(c) && return "<mn>$c</mn>"
  n.class == :ord && c != '′' && return "<mi>" * escaped(c) * "</mi>"
  # A bracket that's written as itself stays the size of the text. Only \left and \right make it grow.
  "<mo" * (n.class in (:open, :close) ? " stretchy=\"false\"" : "") * ">" * escaped(c) * "</mo>"
end

ml(n::Group) = mrow(n.items)
ml(n::Limits) = ml(n.body)
ml(n::Classed) = ml(n.body)
ml(n::Style) = ""
ml(n::Phantom) = "<mphantom>" * mrow(n.body) * "</mphantom>"
ml(n::Boxed) = "<mrow style=\"border: 1px solid; padding: 0.25em\">" * ml(n.body) * "</mrow>"
ml(n::Space) = "<mspace width=\"$(round(n.mu / 18, digits=3))em\"/>"
ml(n::Sized) = n.char == '.' ? "" :
  "<mo minsize=\"$(BIG_SIZES[n.size])em\" maxsize=\"$(BIG_SIZES[n.size])em\">" * escaped(n.char) * "</mo>"

ml(n::Words) = begin
  text = escaped(replace(n.text, ' ' => ' '))
  n.class == :ord ? "<mtext>$text</mtext>" : n.limits ? "<mo movablelimits=\"true\">$text</mo>" : "<mi>$text</mi>"
end

"True when the scripts of `n` go over and under it in MathML. The browser puts them beside a sum sign in a line of text."
stacks(n::Node) = false
stacks(n::Limits) = n.on
stacks(n::Sym) = n.class == :op && !(n.char in INTEGRALS)
stacks(n::Words) = n.limits
stacks(n::Stretch) = true

ml(n::Scripts) = begin
  # Primes are the start of the superscript
  primes = "<mo>" * "′"^n.primes * "</mo>"
  sup = n.primes == 0 ? (n.sup === nothing ? "" : mrow(n.sup)) : n.sup === nothing ? primes : "<mrow>" * primes * ml(n.sup) * "</mrow>"
  base, sub = mrow(n.base), n.sub === nothing ? "" : mrow(n.sub)
  tags = stacks(n.base) ? ("munder", "mover", "munderover") : ("msub", "msup", "msubsup")
  tag = isempty(sup) ? tags[1] : isempty(sub) ? tags[2] : tags[3]
  "<$tag>" * base * sub * sup * "</$tag>"
end

ml(n::Stack) = begin
  tag = n.over === nothing ? "munder" : n.under === nothing ? "mover" : "munderover"
  "<$tag>" * mrow(n.base) * (n.under === nothing ? "" : mrow(n.under)) * (n.over === nothing ? "" : mrow(n.over)) * "</$tag>"
end

ml(n::Frac) = begin
  inner = "<mfrac" * (n.rule ? "" : " linethickness=\"0\"") * ">" * mrow(n.num) * mrow(n.den) * "</mfrac>"
  n.style == 0 || (inner = "<mstyle displaystyle=\"$(n.style == 1)\">" * inner * "</mstyle>")
  n.left == '.' && n.right == '.' ? inner : "<mrow>" * fence(n.left) * inner * fence(n.right) * "</mrow>"
end

ml(n::Root) = n.degree === nothing ? "<msqrt>" * mrow(n.body) * "</msqrt>" : "<mroot>" * mrow(n.body) * mrow(n.degree) * "</mroot>"

ml(n::Fenced) = begin
  out = IOBuffer()
  for (k, c) in enumerate(n.delims)
    print(out, fence(c))
    k <= length(n.parts) && print(out, ml(n.parts[k]))
  end
  "<mrow>" * String(take!(out)) * "</mrow>"
end

ml(n::Accent) = "<mover accent=\"true\">" * mrow(n.body) * "<mo" * (n.wide ? "" : " stretchy=\"false\"") * ">" *
                get(ACCENT_SIGNS, n.char, string(n.char)) * "</mo></mover>"
ml(n::Bar) = n.over ? "<mover accent=\"true\">" * mrow(n.body) * "<mo>‾</mo></mover>" :
                      "<munder accentunder=\"true\">" * mrow(n.body) * "<mo>_</mo></munder>"
ml(n::Stretch) = (tag = n.over ? "mover" : "munder"; "<$tag>" * mrow(n.body) * "<mo stretchy=\"true\">$(n.char)</mo></$tag>")

ml(n::Rows) = begin
  out = IOBuffer()
  print(out, "<mtable>")
  for r in n.rows
    print(out, "<mtr>")
    for (k, cell) in enumerate(r)
      side = n.kind == :aligned ? (isodd(k) ? "right" : "left") :
             (a = n.align[min(k, length(n.align))]; a == 'l' ? "left" : a == 'r' ? "right" : "center")
      # The two cells that meet at an = have no room between them
      pad = n.kind != :aligned ? "" : isodd(k) ? "; padding-right: 0" : "; padding-left: 0"
      print(out, "<mtd style=\"text-align: $side$pad\">", ml(n.kind == :aligned && iseven(k) ? Node[Group(Node[]); cell.items] : cell.items), "</mtd>")
    end
    print(out, "</mtr>")
  end
  print(out, "</mtable>")
  inner = String(take!(out))
  n.left == '.' && n.right == '.' ? inner : "<mrow>" * fence(n.left) * inner * fence(n.right) * "</mrow>"
end

"The formula `tex` as MathML. With `display` it's on a line of its own."
mathml(tex::AbstractString; display::Bool=false) =
  "<math xmlns=\"http://www.w3.org/1998/Math/MathML\"" * (display ? " display=\"block\"" : "") * ">" * ml(nodes(tex)[1]) * "</math>"

export formula, paint, mathml, available, wide, height, depth, Formula
