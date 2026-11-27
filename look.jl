# The look of Ladder's pages: their fonts, their colours in each theme, the
# room round the page's parts, and the words of a label. A `Face` says how a
# run of text is drawn, and `measure` says how wide it is. A character that a
# font lacks is drawn in a font that has it (see `runs`).
#
# main.jl and the views of the kinds of folder use it, so that a view can
# draw as the page does without main.jl.
#
#     label("Downloads", 13px, color=colours.dim)
#     measure(Face(SANS, "", 13px, colours.ink, false), "Downloads")
#     use!(NIGHT)                 # draw with the night theme's colours from now on

@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" WrapMode
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font
@use "github.com/jkroso/MiniFB.jl/skia" measure_text
@use Skia
@use Colors: @colorant_str, RGBA, Colorant

# --- look --------------------------------------------------------------------

const SANS = isfile("/System/Library/Fonts/SFNS.ttf") ? ".SF NS" : "Helvetica"
const SERIF = "Charter"
const MONO = "Menlo"
# Code is drawn in the light weight of the Mac's own font with letters of one width, so it reads
# lighter than the page's text. Menlo has no light weight. A Mac without that font draws code in
# Menlo. A character that the font lacks, like ∈, is in the font that macOS picks for it.
const CODE_FONT, CODE_STYLE = isfile("/System/Library/Fonts/SFNSMono.ttf") ? (".SF NS Mono", "Light") : (MONO, "")
const CODE_SLANT = String(strip(CODE_STYLE * " Italic"))   # the style of a comment
const CODE_SCALE = 0.86   # how big code is beside the page's text, until the settings page changes it

"""
The font of code and its weight, for the window that's being laid out and
drawn. Each window sets them from its settings as it starts a frame, so each
part of the window that shows code uses the font that the settings page chose.
"""
const code_type = Ref((CODE_FONT, CODE_STYLE))
codefont() = code_type[][1]
codestyle() = code_type[][2]
codeslant() = String(strip(codestyle() * " Italic"))   # the style of a comment
const SYMBOL_FONT = "Lucida Grande"

Base.@kwdef mutable struct Palette
  bg::Colorant        # the page
  ink::Colorant       # text
  dim::Colorant       # quotes, the title
  faint::Colorant     # markup characters like ** and #
  marker::Colorant    # bullets and list numbers
  line::Colorant      # table lines and rules
  chip::Colorant      # behind `code`
  chip_line::Colorant
  block::Colorant     # behind a code block
  head::Colorant      # a table's heading row
  stripe::Colorant    # every second row of a table
  accent::Colorant    # links
  select::Colorant
  panel::Colorant     # the sidebar
  hover::Colorant
  active::Colorant    # the open file in the sidebar
  float::Colorant     # the file finder, and the other things that float over the page
  shade::Colorant     # dims the window behind the file finder
  # In a code block
  comment::Colorant
  string::Colorant
  number::Colorant
  keyword::Colorant
  call::Colorant      # the name of a function being called
  type::Colorant
  # In a diff, and in a change that the page shows
  added::Colorant = colorant"rgb(40,128,56)"     # a line that's added
  removed::Colorant = colorant"rgb(186,52,40)"   # a line that's taken away
end

const SEPIA = Palette(bg=colorant"rgb(243,236,218)", ink=colorant"rgb(60,52,42)", dim=colorant"rgb(128,116,98)",
                      faint=colorant"rgb(176,164,140)", marker=colorant"rgb(150,136,112)",
                      line=colorant"rgb(212,203,180)", chip=colorant"rgb(234,227,206)",
                      chip_line=colorant"rgb(217,208,185)", block=colorant"rgb(236,229,209)",
                      head=colorant"rgb(234,227,207)", stripe=colorant"rgb(238,231,212)",
                      accent=colorant"rgb(156,86,38)", select=RGBA(0.72, 0.52, 0.2, 0.28),
                      panel=colorant"rgb(236,228,208)", hover=colorant"rgb(228,220,198)",
                      active=colorant"rgb(222,213,189)", float=colorant"rgb(248,243,229)",
                      shade=RGBA(0.2, 0.15, 0.05, 0.18),
                      comment=colorant"rgb(150,138,115)", string=colorant"rgb(84,116,44)",
                      number=colorant"rgb(170,98,20)", keyword=colorant"rgb(150,58,108)",
                      call=colorant"rgb(48,98,140)", type=colorant"rgb(36,116,110)")

const PAPER = Palette(bg=colorant"rgb(255,255,255)", ink=colorant"rgb(36,36,36)", dim=colorant"rgb(120,120,120)",
                      faint=colorant"rgb(178,178,178)", marker=colorant"rgb(140,140,140)",
                      line=colorant"rgb(224,224,224)", chip=colorant"rgb(243,243,243)",
                      chip_line=colorant"rgb(226,226,226)", block=colorant"rgb(246,246,246)",
                      head=colorant"rgb(244,244,244)", stripe=colorant"rgb(250,250,250)",
                      accent=colorant"rgb(22,100,210)", select=RGBA(0.26, 0.52, 0.96, 0.28),
                      panel=colorant"rgb(246,246,246)", hover=colorant"rgb(236,236,236)",
                      active=colorant"rgb(226,226,226)", float=colorant"rgb(255,255,255)",
                      shade=RGBA(0, 0, 0, 0.16),
                      comment=colorant"rgb(140,140,140)", string=colorant"rgb(30,120,60)",
                      number=colorant"rgb(180,95,0)", keyword=colorant"rgb(170,40,130)",
                      call=colorant"rgb(30,90,180)", type=colorant"rgb(0,120,130)")

const NIGHT = Palette(bg=colorant"rgb(30,30,32)", ink=colorant"rgb(222,220,214)", dim=colorant"rgb(150,148,142)",
                      faint=colorant"rgb(100,99,96)", marker=colorant"rgb(132,130,124)",
                      line=colorant"rgb(62,62,66)", chip=colorant"rgb(46,46,50)",
                      chip_line=colorant"rgb(66,66,72)", block=colorant"rgb(40,40,43)",
                      head=colorant"rgb(44,44,48)", stripe=colorant"rgb(36,36,39)",
                      accent=colorant"rgb(110,170,255)", select=RGBA(0.35, 0.58, 1.0, 0.35),
                      panel=colorant"rgb(38,38,41)", hover=colorant"rgb(52,52,56)",
                      active=colorant"rgb(62,62,68)", float=colorant"rgb(44,44,48)",
                      shade=RGBA(0, 0, 0, 0.4),
                      comment=colorant"rgb(112,112,118)", string=colorant"rgb(160,200,120)",
                      number=colorant"rgb(230,170,100)", keyword=colorant"rgb(200,130,220)",
                      call=colorant"rgb(120,170,250)", type=colorant"rgb(110,200,200)",
                      added=colorant"rgb(130,200,120)", removed=colorant"rgb(240,120,110)")

const THEMES = (sepia=SEPIA, paper=PAPER, night=NIGHT)
const colours = deepcopy(SEPIA)

# The colours of a page of a blog: the cream paper, warm ink and rubric red of
# the blog's site, as the canon tool makes jake.rosoman.info. Code keeps the
# colours of the sepia theme. See "the look of a blog's site".
const SITE = Palette(bg=colorant"rgb(245,239,225)", ink=colorant"rgb(43,38,32)", dim=colorant"rgb(110,99,82)",
                     faint=colorant"rgb(170,158,136)", marker=colorant"rgb(140,128,106)",
                     line=colorant"rgb(221,209,184)", chip=colorant"rgb(236,227,207)",
                     chip_line=colorant"rgb(221,209,184)", block=colorant"rgb(250,246,236)",
                     head=colorant"rgb(236,227,207)", stripe=colorant"rgb(240,233,216)",
                     accent=colorant"rgb(150,56,32)", select=RGBA(0.59, 0.22, 0.13, 0.2),
                     panel=colorant"rgb(237,230,213)", hover=colorant"rgb(231,223,204)",
                     active=colorant"rgb(224,215,194)", float=colorant"rgb(250,246,236)",
                     shade=RGBA(0.2, 0.15, 0.05, 0.18),
                     comment=SEPIA.comment, string=SEPIA.string, number=SEPIA.number,
                     keyword=SEPIA.keyword, call=SEPIA.call, type=SEPIA.type)
"How many times the size of its text a page of a blog is wide: the site's 52rem column at its 19px text"
const SITE_MEASURE = 43.8
"The colours that a site's rules draw darker, under the heading of a list, and the gold of a review's stars"
const SITE_RULE = colorant"rgb(196,179,145)"
const SITE_STARS = colorant"rgb(143,101,22)"
const SITE_INK2 = colorant"rgb(87,78,65)"   # the site's text that's a little lighter than its ink, like a description

# A component's label is 13/12 of its theme's size. This makes a label as tall as the page's text.
const LABEL = 12 / 13

"Draw with the colours in `p` from now on"
use!(p::Palette) = foreach(n -> setfield!(colours, n, getfield(p, n)), fieldnames(Palette))

const TOPBAR_H = 44px
const PANEL_W = 230px     # how wide the sidebar is until you drag its edge
# The narrowest and widest that you can drag it. The narrowest still has room for the buttons of the top bar
# that are over it: 84px for the close, minimise and zoom buttons, 32px for each of the sidebar's two buttons,
# and 72px for the two arrows with 8px after them. So the arrows never stick out past the sidebar's edge.
const PANEL_MIN = 220px
const PANEL_MAX = 480px
const PROSE_W = 780px    # the widest the text gets, before zooming, until the settings page changes it
const PAGE_X = 32px      # the least space beside the text
const PAGE_TOP = 28px
const PAGE_BOTTOM = 160px
const CODE_END = 100px   # how much of a code file still shows at the top of the window when it's scrolled to the end
const CHIP_X = 5px       # space inside a `code` chip, left and right of its text
const BLOCK_X = 16px     # space inside a code block, left of its text
const QUOTE_X = 18px
const CELL_X = 14px
const CELL_Y = 9px

const grow = GrowType.Grow
const clear = RGBA(0, 0, 0, 0)
# The shadow under what floats over the page: a popup, a list of names, the bar over a table
const lifted = shadow(0, 8, 24, RGBA(0, 0, 0, 0.22))
fixed(w) = width(preferred=w, grow=GrowType.None)
spacer(h) = Box(width(grow=grow), height(h))
num(l) = Float64(convert(px, l).value)

"""
Words on one line in the sans-serif font. A character that the font lacks, like
the ⚡ at the end of an email's subject, is in a font that has it (see `spared`).
The words are then a row of parts, not one `Text`.
"""
label(s, size=13px; color=colours.ink, weight="") = begin
  t = Text(s, size=size, family=SANS, subfamily=weight, color=color, wrap=WrapMode.none)
  isascii(t.content) && return t
  face = Face(SANS, weight, t.size, color, false)
  hasall(face, t.content) ? t : Row(Alignment.Start, spared(t.content, face)...)
end

# --- fonts and measuring -------------------------------------------------------

"How a run of text is drawn. A chip is the box behind `code`."
struct Face
  family::String
  style::String
  size::px
  color::Colorant
  chip::Bool
  lang::String    # the language of code whose parts each get a colour, or "" for text in one colour
  highlit::Bool   # true for ==words==, which have a highlighter's colour behind them
end

Face(family, style, size, color, chip, lang="") = Face(family, style, size, color, chip, lang, false)
Face(f::Face; style=f.style, size=f.size, color=f.color, family=f.family, chip=f.chip, lang=f.lang, highlit=f.highlit) =
  Face(family, style, size, color, chip, lang, highlit)

const measured = Dict{Tuple{String,String,Float32,String},px}()

"""
How wide `s` is in `face`. It's kept, because the same words are measured every
frame. A character that the font lacks is as wide as it is in the font that
draws it (see `runs`), not as wide as the empty box that would stand for it.
"""
measure(face::Face, s::AbstractString) = begin
  isempty(s) && return 0px
  length(measured) > 200_000 && empty!(measured)
  get!(measured, (face.family, face.style, Float32(num(face.size)), String(s))) do
    hasall(face, s) ? width_in(face, s) : sum(((t, f),) -> width_in(f, t), runs(s, face))
  end
end

"How wide `s` is in the font of `face`, with no other font for the characters that it lacks"
width_in(face::Face, s::AbstractString) = px(measure_text(skia_font(face.family, face.size, face.style), s)[1])

# --- the characters that a font lacks ----------------------------------------------

const drawable = Dict{Tuple{String,String,Char},Bool}()

"True when the font of `face` has a letter shape for `c`"
has(face::Face, c::Char) =
  get!(drawable, (face.family, face.style, c)) do
    Skia.sk_font_unichar_to_glyph(skia_font(face.family, face.size, face.style).raw, Int32(c)) != 0
  end

const stand_ins = Dict{Tuple{String,Char},String}()

"""
The name of a font on this Mac that has the character `c`, or "" when none
has. macOS picks it, as it does for the text of an app in the font `family`:
`family` when it has the character, and if not a font of symbols, of another
script or of emoji. Code asks with Menlo, which has most signs.
"""
font_with(c::Char, family::AbstractString=MONO) = get!(stand_ins, (String(family), c)) do
  style = Skia.sk_fontstyle_new(Int32(400), Int32(Skia.SK_FONT_STYLE_WIDTH_NORMAL), Skia.SK_FONT_STYLE_SLANT_UPRIGHT)
  found = Skia.sk_fontmgr_match_family_style_character(Skia.sk_fontmgr_ref_default(), family, style, C_NULL, Int32(0), Int32(c))
  Skia.sk_fontstyle_delete(style)
  found == C_NULL && return ""
  name = Skia.sk_typeface_get_family_name(found)
  family = unsafe_string(Skia.sk_string_get_c_str(name))
  Skia.sk_string_delete(name)
  # The font is asked for by its name from here on, so it has to answer to that name
  has(Face(family, "", 12px, colours.ink, false), c) ? family : ""
end

const one_wide = Dict{Tuple{String,String},Bool}()

"True when each letter of the font of `face` is as wide as the others, as in a font of code"
one_width(face::Face) = get!(one_wide, (face.family, face.style)) do
  f = skia_font(face.family, 12px, face.style)
  measure_text(f, "i")[1] == measure_text(f, "M")[1]
end

"""
The font that macOS starts from to find a font for a character that `face`
lacks. Code and the symbols of keys start from Menlo, which has most signs.
Text starts from its own font, as in TextEdit.
"""
stand_in_from(face::Face) = one_width(face) || face.family == SYMBOL_FONT ? MONO : face.family

"""
`text` in runs, each with the face to draw it in. A character that the font of
`face` doesn't have is in a font that has it (see `stand_in_from`). In code,
that's Menlo for the raised minus of m⁻¹, and a font of symbols for the ⋮ in a
big matrix. Charter has no raised minus, so the minus of yr⁻¹ in a page's text
is Lucida Grande's.
"""
runs(text::AbstractString, face::Face) = begin
  out = Tuple{String,Face}[]
  for c in text
    family = isascii(c) || has(face, c) ? face.family : font_with(c, stand_in_from(face))
    f = family == face.family || isempty(family) ? face : Face(face, family=family, style="")
    if !isempty(out) && last(out)[2] === f
      out[end] = (last(out)[1] * c, f)
    else
      push!(out, (string(c), f))
    end
  end
  out
end

"True when the font of `face` has every character of `text`"
hasall(face::Face, text::AbstractString) = all(c -> isascii(c) || has(face, c), text)

"How wide `text` is in the face `f`, with each character that the font lacks in a font that has it"
spared_width(text::AbstractString, f::Face) = isempty(text) ? 0px : sum(measure(pf, part) for (part, pf) in runs(text, f))

"`text` in the face `f`, as the parts of a row. A character that the font lacks is in a font that has it."
spared(text::AbstractString, f::Face) =
  [Box(fixed(measure(pf, part)), Alignment.Start,
     Text(part, size=pf.size, family=pf.family, subfamily=pf.style, color=pf.color, wrap=WrapMode.none)) for (part, pf) in runs(text, f)]
