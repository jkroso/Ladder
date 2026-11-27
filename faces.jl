# The faces of the page's text: the size and the weight of its text and of its
# headings, the font of code, how a callout and inline code are drawn, and the
# pieces that a line of text is made of before it's wrapped.
#
#     face(e, line)                # how line `line` of the page is drawn
#     pieces(e, text, line, raw)   # the runs of a line's text, each in its face

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" fontmgr
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI WrapMode light describe detach! inputs Theme
@use "github.com/jkroso/UI.jl/Interface/fonts" weight_of weight_name isitalic installed_faces skia_font
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./html" NOTE
@use "./markdown" Kind Line Span spans words isdone MATTER TOML_MATTER opens_callout
@use "./markdown" COMMENT
@use "./highlight" tokens
@use "./sheet" shown
@use "./math" => Maths
@use Colors: RGBA
@use "./folder_page" own! node!
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...

export note_mark, equation, ticked_then, evaluate, keep_value!, TEXT_SIZE, body, HEADINGS, SITE_HEADINGS,
       face, highlighter, WEIGHT_NAMES, HEAVIEST, weight_label, text_style, slanted, bolder, emboldened,
       Weight, font_weights, text_weights, nearest_weight, weight_called, text_weight, piece,
       installed_weight, use_code_font!, isfixed, font_label, font_family, fixed_fonts, once_each, COPIES,
       PICTURE_FONTS, code_fonts, TODO_OPEN, TODO_DONE, isbox, shows_box, pieces, CALLOUT_ICONS,
       callout_colour, callout_name, callout_tint, CalloutMark, CALLOUT_GAP, icon_size, wide, callout_mark,
       INLINE, inline_lines, ordinal, sums_run, sums_shown, made, fit, INLINE_W, inline, LONGEST_VALUE, said,
       SYMBOLS, symbols!, codeblock, code_size, CELL_LANG, geometry, SITE_FONT, NEWS_TYPE, NEWS_HEADINGS,
       markup_shows, component_theme, SHEET_FILE, SHEET_FONT, SHEET_WEIGHT, capitals, capital

# The kinds of block and of mark decide these, so this file only names them.

"The number that shows for the footnote `name`, as text"
function note_mark end

"The piece that stands for the formula of a span, in text drawn in a face"
function equation end

"How the to-do item on line `i` of the page was on the day that the page shows, or nothing"
function ticked_then end

"Run the code `code` of a live block or of inline code on the page of the editor `e`, and give what it shows"
function evaluate end

"Keep what the `n`th sum `code` of the page of the editor `e` came to, so that the sheets under it can use it"
function keep_value! end

# --- faces -----------------------------------------------------------------------------

const TEXT_SIZE = 17px   # of the page's text, before it's zoomed
# A page of a blog has the typeface of the blog's site, in its usual weight. See "the look of a blog's site".
body(e) = e.look == :site ? Face(SITE_FONT[], "", TEXT_SIZE * e.zoom, colours.ink, false) :
          # An article in a folder of news has a newspaper's typeface. See "a folder of news".
          e.look == :news ? Face(NEWS_TYPE, "", TEXT_SIZE * e.zoom, colours.ink, false) :
                            Face(e.font, nearest_weight(e.font, e.weight).style, TEXT_SIZE * e.zoom, colours.ink, false)
const HEADINGS = (2.1, 1.75, 1.4, 1.2, 1.05, 1.0)
"How much bigger than the text each level of heading is on a page of a blog, as its site has them"
const SITE_HEADINGS = (2.3, 1.4, 1.12, 1.0, 1.0, 1.0)

"The face a line's plain text is drawn in"
face(e, line::Line) = begin
  b = body(e)
  k = line.kind
  # A blog's site has its headings a little lighter than bold
  k == Kind.heading && e.look == :site && return Face(b, style=line.level == 4 ? "SemiBold Italic" : "SemiBold", size=b.size * SITE_HEADINGS[line.level])
  k == Kind.heading && e.look == :news && return Face(b, style="Bold", size=b.size * NEWS_HEADINGS[line.level])
  k == Kind.heading ? Face(emboldened(b), size=b.size * HEADINGS[line.level]) :
  # A callout's text is the page's own. Its title is bold, in the colour of its kind.
  opens_callout(line) ? Face(emboldened(b), color=callout_colour(line.lang)) :
  k == Kind.blockquote ? (isempty(line.lang) ? Face(b, style=slanted(b.style), color=colours.dim) : b) :
  # A comment on lines of its own is in the page's font, and dim
  line.lang == COMMENT ? Face(b, color=colours.dim) :
  # The text of a cell's field is in the editor's own font: see "the field of a cell"
  k == Kind.code && line.lang == CELL_LANG ? b :
  # Code is the size that the settings page chooses. The markup of a table or a rule is code's usual size.
  k in (Kind.code, Kind.fence) ? Face(b, family=codefont(), style=codestyle(), size=code_size(e)) :
  k in (Kind.table, Kind.rule) ? Face(b, family=codefont(), style=codestyle(), size=b.size * CODE_SCALE) : b
end

"The face for one span of a line whose plain text is drawn in `base`"
face(base::Face, s::Span) = begin
  s.markup && return Face(base, color=colours.faint)
  # A comment shows only while its line's markup shows, and then it's dim
  s.comment && return Face(base, color=colours.dim)
  # The TeX of a formula, while it shows as it's written, is in the font of code
  s.math && return Face(codefont(), codestyle(), base.size * 0.86, base.color, false)
  # Inline code that runs is Julia, so its parts get the colours they have in a code block
  s.code && return Face(codefont(), codestyle(), base.size * 0.86, base.color, true, s.live ? "julia" : "")
  f = s.bold ? emboldened(base) : base
  s.italic && !isitalic(f.style) && (f = Face(f, style=slanted(f.style)))
  Face(f, color=!isempty(s.link) ? colours.accent : s.strike ? colours.faint : base.color, highlit=s.highlit)
end

"The colour behind ==words==: a highlighter's yellow, a little darker on a dark page"
highlighter() = dark_page() ? RGBA(0.85, 0.68, 0.1, 0.38) : RGBA(1.0, 0.85, 0.2, 0.45)

# --- the weights of the page's text and of code --------------------------------------
#
# The page's text and code can each be lighter or heavier than the font's usual
# weight. The settings pages list the weights that each font has, up to
# Semibold, by the names that the font gives them. Code starts in Light, so
# that it reads lighter than the page's text. Bold text and headings are
# heavier than the rest: Bold, or Extra bold when the text is Semibold. A font
# that lacks the weight you chose draws the one nearest to it, and the next
# font that has the weight draws it again.
#
# A weight is kept as the Mac's number for it, like 300 for Light. Fonts don't
# agree on names: Helvetica Neue's UltraLight is lighter than its Thin, and
# Charter calls its usual weight Roman. The Mac's numbers don't always agree
# with the names either: it says that Source Code Pro's ExtraLight weighs 300
# and its Light 342. So a font's weights are in the order of the Mac's numbers,
# with the font's own names, and each is drawn by its name.

"What the settings pages call each weight of a font whose faces the Mac hides, like SF Mono, from 100 to 900"
const WEIGHT_NAMES = ("Thin", "Extra light", "Light", "Regular", "Medium", "Semibold", "Bold", "Extra bold", "Black")
const HEAVIEST = 650   # the heaviest that the page's text and code can be: Semibold. Heavier text would hide what's bold.

weight_label(w::Integer) = WEIGHT_NAMES[clamp(round(Int, w / 100), 1, length(WEIGHT_NAMES))]

"The style of a face of the weight `w`, as Skia reads it: \"\" for Regular, or like \"Light\" and \"Bold Italic\""
text_style(w::Integer, italic::Bool=false) = begin
  name = w == 400 ? "" : weight_name(w)
  italic ? String(strip("$name Italic")) : name
end

"The style of the slanted face of `style`, like \"Light Italic\""
slanted(style::AbstractString) = isempty(style) ? "Italic" : "$style Italic"

"The weight of bold text among text of the weight `w`"
bolder(w::Integer) = max(700, w + 200)

"The face `f` made bold. A face that's bold already, like a heading's, stays as it is."
emboldened(f::Face) = begin
  w = weight_of(f.style)
  w >= 700 ? f : Face(f, style=text_style(bolder(w), isitalic(f.style)))
end

"A weight of a font: what the settings pages call it, the style that draws it, and the Mac's number for it"
const Weight = @NamedTuple{label::String, style::String, weight::Int}
const font_weights = Dict{String,Vector{Weight}}()

"""
The weights of `family` that the page's text or code can be in, lightest
first, by the names that the font gives them. A font whose faces the Mac
hides, like SF Mono, has the weights that it draws when asked for 100, 200
and so on. There are none when the Mac has no font of that family.
"""
text_weights(family::AbstractString) = get!(font_weights, String(family)) do
  faces = filter(f -> !f.italic && f.width == Int(Skia.SK_FONT_STYLE_WIDTH_NORMAL), installed_faces(family))
  found = if isempty(faces)
    Weight[(label=weight_label(w), style=text_style(w), weight=w) for w in filter(>(0), [installed_weight(family, w) for w in 100:100:900])]
  else
    # The usual face draws with no style, as it did before there were weights to choose
    usual(f) = f.weight == 400 && lowercase(f.name) in ("regular", "roman", "normal")
    Weight[(label=f.name, style=usual(f) ? "" : f.name, weight=f.weight) for f in faces]
  end
  found = sort!(unique(w -> w.weight, found), by=w -> w.weight)
  light = filter(w -> w.weight <= HEAVIEST, found)
  # A font that has only heavy weights draws its lightest
  isempty(light) ? found[1:min(1, end)] : light
end

"""
The weight of `family` nearest to `w`: the one that text of the weight `w` is
drawn in. Of two that are as near, it's the one nearer to Regular.
"""
nearest_weight(family::AbstractString, w::Integer) = begin
  has = text_weights(family)
  isempty(has) && return (label=weight_label(w), style=text_style(w), weight=Int(w))
  argmin(x -> (abs(x.weight - w), abs(x.weight - 400)), has)
end

"The Mac's number for the weight of `family` called `name`, like \"Light\""
weight_called(family::AbstractString, name::AbstractString) = begin
  has = text_weights(family)
  i = findfirst(w -> w.label == name, has)
  i === nothing && error("The weights of $(font_label(family)) are $(join([w.label for w in has], ", ", " and ")). $name isn't one of them.")
  has[i].weight
end

"`w` if text can be that heavy"
text_weight(w::Integer) = 0 < w <= HEAVIEST ? Int(w) : error("A weight of text goes from 1, the lightest, to $HEAVIEST, which is Semibold. $w isn't one of them.")

piece(text, col, face; atomic=false, n=length(text), link="", node=nothing, words=false) = Piece(text, col, n, face, atomic, link, node, words)

# --- the font of code ------------------------------------------------------------------
#
# Code is drawn in a font whose letters are all one width. The settings page
# lists each such font on the Mac, and code is drawn in the one you choose, in
# the weight you choose. Code starts in the font's light weight when the font
# has one, as SF Mono has, so that code reads lighter than the page's text.

"The weight of the face of `family` nearest to `weight`, or 0 when the Mac has no font of that family"
installed_weight(family::AbstractString, weight::Integer) = begin
  style = Skia.sk_fontstyle_new(Int32(weight), Int32(Skia.SK_FONT_STYLE_WIDTH_NORMAL), Skia.SK_FONT_STYLE_SLANT_UPRIGHT)
  typeface = Skia.sk_fontmgr_match_family_style(fontmgr[], String(family), style)
  Skia.sk_fontstyle_delete(style)
  typeface == C_NULL && return 0
  found = Skia.sk_typeface_get_fontstyle(typeface)
  w = Int(Skia.sk_fontstyle_get_weight(found))
  Skia.sk_fontstyle_delete(found)
  Skia.sk_typeface_unref(typeface)
  w
end

"Draw code in the font and weight that `e`'s settings choose, from now until another window starts to draw"
use_code_font!(e) = (code_type[] = (e.code_font, nearest_weight(e.code_font, e.code_weight).style); e)

"True when every letter of `family` is as wide as every other, as in a font for code"
isfixed(family) = begin
  f = Face(family, "", 20px, colours.ink, false)
  all(c -> has(f, c), "iMw0") && measure(f, "i") == measure(f, "M") == measure(f, "0")
end

# The Mac's own font for code has a hidden name, and the list calls it SF Mono
font_label(family) = family == ".SF NS Mono" ? "SF Mono" : family
font_family(label) = label == "SF Mono" && CODE_FONT == ".SF NS Mono" ? CODE_FONT : label

const fixed_fonts = String[]

"""
The names in `fonts` with each font once, where a font comes in copies whose
letters are the same. A Nerd Font comes as X Nerd Font, X Nerd Font Mono and X
Nerd Font Propo, whose icons differ. A variable font, X Var, is X with its
weights in one file. The plain X stays, or the one there is.
"""
once_each(fonts) = filter(f -> !(endswith(f, COPIES) && replace(f, COPIES => "") in fonts), fonts)
const COPIES = r"(?<= Nerd Font) (Mono|Propo)$| Var$"

# Fonts of pictures, not letters, though each picture is as wide as the next
const PICTURE_FONTS = ("Webdings", "Wingdings", "Wingdings 2", "Wingdings 3", "Symbol", "Zapf Dingbats", "Bodoni Ornaments")

"The families of the fonts on this Mac whose letters are all one width, in order, with the one that code is drawn in at first"
code_fonts() = begin
  if isempty(fixed_fonts)
    names = String[]
    name = Skia.sk_string_new_empty()
    for i in 0:Skia.sk_fontmgr_count_families(fontmgr[])-1
      Skia.sk_fontmgr_get_family_name(fontmgr[], Cint(i), name)
      push!(names, unsafe_string(Skia.sk_string_get_c_str(name)))
    end
    Skia.sk_string_delete(name)
    # A font whose name starts with a dot is the Mac's own, for its menus and windows
    found = filter(f -> !startswith(f, '.') && font_family(f) == f && !(f in PICTURE_FONTS) && isfixed(f), unique(names))
    append!(fixed_fonts, sort!(once_each(found), by=lowercase))
  end
  unique([CODE_FONT; fixed_fonts])
end

# The text that stands for the box of a to-do item. The box is drawn in its place, so only the text's width matters.
# Both hold the same characters, so an empty box and a ticked one are the same width.
const TODO_OPEN, TODO_DONE = "[ ] ", "] [ "
"True when `seg` is the box of a to-do item"
isbox(seg) = seg.atomic && (seg.text == TODO_OPEN || seg.text == TODO_DONE)

"True when `f` is the layout of a to-do item that shows its box, and not the - [ ] that makes the box"
shows_box(f) = f isa Flow && f.kind == Kind.todo && !f.raw && any(isbox, first(f.lines).segs)

"""
The runs of text that line `text` is drawn as. With `raw`, the markup shows.
With `open`, only the runs of the line in those columns show it: see `raw_part`.
"""
pieces(e, text::String, line::Line, raw::Bool, i::Int=0; open=nothing) = begin
  base = face(e, line)
  out = Piece[]
  k = line.kind
  if k == Kind.code && line.lang == MATTER
    # In front matter, the key is fainter than what it's set to, and a comment slants
    m = match(r"^(\s*(?:-\s+)?)([^:#\s][^:#]*:)(.*)$", text)
    if startswith(lstrip(text), '#') || m === nothing
      comment = startswith(lstrip(text), '#')
      isempty(text) || push!(out, piece(text, 0, comment ? Face(base, color=colours.comment, style=codeslant()) : base))
    else
      isempty(m[1]) || push!(out, piece(String(m[1]), 0, base))
      push!(out, piece(String(m[2]), length(m[1]), Face(base, color=colours.dim)))
      isempty(m[3]) || push!(out, piece(String(m[3]), length(m[1]) + length(m[2]), base))
    end
    return out
  elseif k == Kind.code && line.lang == TOML_MATTER
    # TOML front matter looks like YAML front matter: a key and its = are fainter, and so is a
    # [table] line that starts a group of keys. A comment slants.
    m = match(r"^(\s*)((?:\"[^\"]*\"|'[^']*'|[\w.-])+\s*=)(.*)$", text)
    if startswith(lstrip(text), '#')
      push!(out, piece(text, 0, Face(base, color=colours.comment, style=codeslant())))
    elseif startswith(lstrip(text), '[') && m === nothing
      push!(out, piece(text, 0, Face(base, color=colours.dim)))
    elseif m === nothing
      isempty(text) || push!(out, piece(text, 0, base))
    else
      isempty(m[1]) || push!(out, piece(String(m[1]), 0, base))
      push!(out, piece(String(m[2]), length(m[1]), Face(base, color=colours.dim)))
      isempty(m[3]) || push!(out, piece(String(m[3]), length(m[1]) + length(m[2]), base))
    end
    return out
  elseif line.lang == COMMENT && k in (Kind.code, Kind.fence)
    # A comment on lines of its own shows only while the caret is in it. Its words are dim, and its %% are faint.
    k == Kind.fence && !raw && return out
    a = k == Kind.fence && line.level == 0 ? length(match(r"^\s*%%", text).match) : 0
    z = k == Kind.fence && line.level == 1 ? length(text) - length(match(r"%%\s*$", text).match) : length(text)
    a > 0 && push!(out, piece(head(text, a), 0, Face(base, color=colours.faint)))
    z > a && push!(out, piece(rest(head(text, z), a), a, base))
    z < length(text) && push!(out, piece(rest(text, z), z, Face(base, color=colours.faint)))
    return out
  elseif k == Kind.code && line.lang == CELL_LANG
    # The text of a cell's field has no colours of code
    isempty(text) || push!(out, piece(text, 0, base))
    return out
  elseif k == Kind.code && line.lang in (HEX, BITS)
    # In a line of a file's bytes, the place in the file is faint and the bytes as characters are dim
    n = ncodeunits(text)
    chars = line.lang == HEX ? HEX_CHARS : BITS_CHARS
    for (lo, hi, colour) in ((0, HEX_BYTES, colours.faint), (HEX_BYTES, chars, base.color), (chars, n, colours.dim))
      lo < n && push!(out, piece(text[lo+1:min(hi, n)], lo, Face(base, color=colour)))
    end
    return out
  elseif k == Kind.code
    # Each part of a line of code has its own colour, and comments slant. A `check` block's lines are Julia.
    # A line inside a docstring of several lines is all the colour of a string.
    for t in tokens(text, shared_lang(line.lang), i > 0 ? string_open(e.buf, i, text) : '\0')
      colour = t.kind == :plain ? base.color : getfield(colours, t.kind)
      push!(out, piece(t.text, t.col, Face(base, color=colour, style=t.kind == :comment ? codeslant() : base.style)))
    end
    return out
  elseif k in (Kind.fence, Kind.table, Kind.rule)
    k == Kind.fence && !raw && return out
    isempty(text) || push!(out, piece(text, 0, k == Kind.table ? base : Face(base, color=colours.faint)))
    return out
  end
  # True when the columns `lo` to `hi` show their markup
  written(lo, hi) = raw || markup_shows(open, lo, hi)
  lead = head(text, line.prefix)
  bare = written(0, line.prefix)   # true when what starts the line shows as it's written
  if k in (Kind.bullet, Kind.ordered, Kind.todo)
    line.level > 0 && push!(out, piece(head(lead, line.level), 0, base))
    mark = Face(emboldened(base), color=colours.marker)
    if k == Kind.bullet && !bare
      push!(out, piece("•  ", line.level, mark, atomic=true, n=line.prefix - line.level))
    elseif k == Kind.todo && !bare
      # On another day than today, the box shows how the item stands then: see `ticked_then`
      push!(out, piece(something(ticked_then(e, i), isdone(text)) ? TODO_DONE : TODO_OPEN, line.level, base, atomic=true, n=line.prefix - line.level))
    else
      push!(out, piece(rest(lead, line.level), line.level, mark))
    end
    # A to-do item that's done reads fainter
    k == Kind.todo && something(bare ? nothing : ticked_then(e, i), isdone(text)) && (base = Face(base, color=colours.dim))
  elseif k == Kind.paragraph
    isempty(lead) || push!(out, piece(lead, 0, base))
  elseif opens_callout(line) && !bare
    # The line that names a callout's kind shows the kind's icon, and its name when the line has no title of its own
    push!(out, callout_mark(e, line, base, length(text) > line.prefix))
  elseif bare && !isempty(lead)
    push!(out, piece(lead, 0, Face(base, color=colours.faint)))
  end
  start = line.prefix
  note = k == Kind.paragraph ? match(NOTE, text) : nothing
  note === nothing || written(0, length(note.match)) && (note = nothing)
  if note !== nothing
    # The line that holds a footnote's text starts with the footnote's number
    start = length(note.match)
    push!(out, piece(note_mark(e, note[1]) * ".  ", 0, Face(base, color=colours.accent), atomic=true, n=start, link="^" * note[1]))
  end
  for s in spans(rest(text, start), start)
    shown = written(s.col, s.col + length(s.text))
    (s.markup || s.comment) && !shown && continue
    if startswith(s.link, '^') && !shown
      # [^name] shows as the footnote's number, small and raised
      push!(out, piece(note_mark(e, s.text), s.col, Face(base, size=base.size * 0.7, color=colours.accent), atomic=true, n=length(s.text), link=s.link))
      continue
    end
    # $x^2$ shows as the formula that its TeX describes
    if s.math && !shown && Maths.available()
      push!(out, equation(e, s, base))
      continue
    end
    # Line -1 isn't one of the document's lines: it's a line of a file under a path. Its inline code shows as code.
    s.live && !shown && i >= 0 && runs_sums(e) ? push!(out, inline(e, i, s, base)) : symbols!(out, s.text, s.col, face(base, s), s.link)
  end
  out
end

# --- callouts ------------------------------------------------------------------------------
#
# A callout is a quote that stands out: a note, a tip, a warning. Its first
# line names its kind, as GitHub writes it: `> [!NOTE]`. The lines of the quote
# under that one are the callout's text. The page shows the first line as the
# kind's icon and its name, like "Note", in the kind's colour. Words after the
# `]` are a title, and show in place of the name. The callout's lines have a
# line of that colour down their left, and a little of the colour behind them.
# `markdown.jl` reads the lines.

"The icon of each kind of callout"
const CALLOUT_ICONS = (note="info-circle", tip="lightbulb", important="exclamation-square", warning="exclamation-triangle", caution="exclamation-octagon")

"The colour of a kind of callout. Each is a colour that code has in this page's colours."
callout_colour(kind) =
  kind == "tip" ? colours.string : kind == "important" ? colours.keyword : kind == "warning" ? colours.number :
  kind == "caution" ? removed_colour() : colours.call

"What a callout of this kind is called when it has no title of its own, like \"Note\""
callout_name(kind) = uppercasefirst(kind)

"The colour behind the lines of a callout: a little of its kind's colour over the page"
callout_tint(kind) = (c = RGBA(callout_colour(kind)); RGBA(c.r, c.g, c.b, dark_page() ? 0.12 : 0.08))

"What shows in place of the `> [!NOTE]` that starts a callout: the kind's icon, and the kind's name when `name` isn't empty"
@def mutable struct CalloutMark <: SemanticUI
  kind::String = "note"
  name::String = ""
  face::Face = Face("", "", TEXT_SIZE, colours.ink, false)   # of the name
end

const CALLOUT_GAP = 0.45   # the room between the icon and the words after it, as a part of the size of the text

icon_size(m::CalloutMark) = px(round(num(m.face.size) * 0.95))
wide(m::CalloutMark) = icon_size(m) + m.face.size * CALLOUT_GAP + measure(m.face, m.name)

describe(m::CalloutMark) =
  Row(fixed(wide(m)), Alignment.Center, justify=Alignment.Start, child_gap=m.face.size * CALLOUT_GAP,
    Icon(getproperty(CALLOUT_ICONS, Symbol(m.kind)), size=icon_size(m), color=m.face.color),
    (isempty(m.name) ? () : (Box(Text(m.name, size=m.face.size, family=m.face.family, subfamily=m.face.style, color=m.face.color, wrap=WrapMode.none)),))...)

inputs(m::CalloutMark) = (m.kind, m.name, m.face)

"""
The piece that stands for what starts the first line of a callout, in text
drawn in `base`. `titled` is true when the line has a title of its own after
it. The piece then shows only the icon.
"""
callout_mark(e, line::Line, base::Face, titled::Bool) = begin
  m = CalloutMark(kind=line.lang, name=titled ? "" : callout_name(line.lang), face=base)
  # It's part of its line, which is laid out once and kept. It can reach the document, and it isn't one of the document's children.
  setfield!(m, :parent, node!(Document, e, :document))
  piece(callout_name(line.lang), 0, base, atomic=true, n=line.prefix, node=Inline(m, wide(m), base.size * 1.2))
end

# --- inline code -------------------------------------------------------------------------
#
# !`code` in a line of text is inline code. The page runs the code and shows
# what it makes in place of the code: a node, like a switch or a file path, or
# any other value as text. The code shows again while the caret is on its line.

const INLINE = "!`"   # what inline code starts with

"The lines of `b` that have inline code"
inline_lines(e, b::Buffer) = get!(e.flows, (:inline, b.path, b.version)) do
  [i for (i, text) in enumerate(b.lines) if occursin(INLINE, text)]
end

"""
Which one of the document's pieces of inline code with this code the span `s`
of line `i` is: 1 for the first. Two pieces with the same code each make a
node of their own.
"""
ordinal(e, i::Int, s::Span) = ordinal(e, i, s.col, s.text)

"Which one of the document's pieces of inline code `code` the one whose code starts at column `col` of line `i` is"
ordinal(e, i::Int, col::Int, code::AbstractString) = begin
  b = e.buf
  marked = INLINE * code * "`"
  1 <= i <= length(b.lines) || return 1
  before = sum(j -> count(marked, b.lines[j]), Iterators.filter(<(i), inline_lines(e, b)), init=0)
  before + count(marked, head(b.lines[i], max(0, col - length(INLINE)))) + 1
end

# How many times a sum in a line of text has run. What's worked out from what the sums show, like the
# numbers that a chart draws from a table, is worked out again when this changes.
const sums_run = Ref(0)

"""
The text of a cell of a table, with what each sum in it shows in place of its
code: "\$!`price`" is "\$12". `i` is the cell's line, and `col` the column
where `text` starts in it. A sum that hasn't run yet, that went wrong or that
made a node shows nothing. This runs no sum, as the sums run in the order of
the page, and `sums_run` says when they've run again.
"""
sums_shown(e, i::Int, col::Int, text::AbstractString) = begin
  occursin(INLINE, text) || return text
  out = IOBuffer()
  at = 1
  for m in eachmatch(r"!`([^`]+)`", text)
    print(out, text[at:prevind(text, m.offset)])
    code = String(m[1])
    made = get(e.nodes, (:inline, e.buf.path, code, ordinal(e, i, col + length(text, 1, m.offset) + 1, code)), nothing)
    made isa Tuple && !made[2] && print(out, made[1])
    at = m.offset + ncodeunits(m.match)
  end
  print(out, text[at:end])
  String(take!(out))
end

"""
What the `n`th piece of inline code `code` of the document made. It's a Shown
when the code made a node. For any other value it's the value as text, and
true if that text says what went wrong.
"""
made(e, code::String, n::Int) = begin
  foreign(e.buf.path) && return (code, false)   # a page from a web server runs no code, and nor does an email, so the code itself shows
  key = (:inline, e.buf.path, code, n)
  get!(e.nodes, key) do
    sums_run[] += 1
    out = evaluate(e, code, key=key, inline=true)
    out isa Tuple && (keep_value!(e, code, n, out[2]); return out)
    shown = Shown(value=out, inline=true)
    out isa SemanticUI && own!(shown, out)
    shown
  end
end

"Lay out what inline code made, to learn how much room it takes in its line"
fit(e, shown) = begin
  # It's part of its line. It can reach the document, and it isn't one of the document's children:
  # a line is laid out once and kept, so the document isn't given it again on each frame.
  shown.parent === nothing && setfield!(shown, :parent, node!(Document, e, :document))
  concrete = describe(Row(Alignment.Start, geometry(shown)), (e.width, 9999px))
  # A node with no width of its own, like a slider, takes all the room it's given. In a line it gets this much.
  w = concrete.width < 16px ? INLINE_W * e.zoom : concrete.width
  Inline(shown, min(w, e.width), concrete.height)
end

const INLINE_W = 180px   # of a node in a line of text that has no width of its own, before the text is zoomed

"The piece that stands for the inline code of span `s`, on line `i`, in text drawn in `base`"
inline(e, i::Int, s::Span, base::Face) = begin
  out = made(e, s.text, ordinal(e, i, s))
  n = length(s.text)
  out isa Tuple || return piece(s.text, s.col, base, atomic=true, n=n, node=fit(e, out))
  text, failed = out
  # A value between == and ==, or in the words that a comment is about, has the highlighter's colour behind it too
  piece(text, s.col, Face(base, color=failed ? colours.accent : base.color, highlit=s.highlit), atomic=true, n=n, words=true)
end

const LONGEST_VALUE = 200   # characters of a value that inline code shows as text

"""
A value as the text that inline code shows for it. A number reads the way a
sheet shows it: 28.8 and not 28.799999999999997, with or without a unit.
"""
said(value) = begin
  text = value isa AbstractString ? String(value) : value === nothing ? "nothing" : Base.invokelatest(shown, value)
  text = replace(text, r"\s*\n\s*" => " ")
  length(text) > LONGEST_VALUE ? first(text, LONGEST_VALUE) * "…" : text
end

# The page's fonts have no ⌘, ⌫ or arrows, so those characters are drawn in one that does
const SYMBOLS = r"[⌘⌥⇧⌃⏎⇥⌫⌦⎋←→↑↓]+"

"""
Add `text` to `out`, with its keyboard symbols in a font that has them. That's
Lucida Grande, and for a symbol that it hasn't got, like ⏎, a font that macOS picks.
"""
symbols!(out, text, col, face, link="") = begin
  at = 1
  add(part, f) = isempty(part) || (push!(out, piece(String(part), col, f; link)); col += length(part))
  for m in eachmatch(SYMBOLS, text)
    add(SubString(text, at, prevind(text, m.offset)), face)
    for (part, f) in runs(m.match, Face(face, family=SYMBOL_FONT, style=""))
      add(part, f)
    end
    at = m.offset + ncodeunits(m.match)
  end
  add(SubString(text, at), face)
  out
end

"The first and last line of the code block that line `i` is in, with the lines that open and close it"
codeblock(b::Buffer, i::Int) = begin
  ks = kinds(b)
  s = t = i
  while s > 1 && !(ks[s].kind == Kind.fence && ks[s].level == 0); s -= 1 end
  while t < length(ks) && !(ks[t].kind == Kind.fence && ks[t].level == 1 && t > s); t += 1 end
  (s, t)
end

"How big code is: a part of the size of the page's text, so it grows and shrinks with it"
code_size(e) = body(e).size * e.code_scale

const CELL_LANG = "cell"   # the language of the text of a field of a table: plain text, in the table's font

# The code of a live block can load methods that are newer than the frame that
# ran it, so the node is described with the newest methods there are
geometry(node::SemanticUI) = Base.invokelatest(convert, GeometricUI, node)

geometry(node::GeometricUI) = detach!(node)

"The family of the text of a page of a blog: Literata once its files are read, and Charter before that or without them"
const SITE_FONT = Ref(SERIF)

# A newspaper's look: Georgia, on newsprint, in black ink. The masthead is in Big Caslon. Both come with every Mac.
"The typeface of a newspaper's text and headlines"
const NEWS_TYPE = "Georgia"

"How much bigger than the text each level of heading is in an article"
const NEWS_HEADINGS = (2.0, 1.3, 1.1, 1.0, 1.0, 1.0)

"True when the columns `lo` to `hi` of a line show their markup, where `open` is what `raw_part` gave for the line"
markup_shows(open, lo::Int, hi::Int) = open !== nothing && any(r -> r[1] <= lo && hi <= r[2], open)

# --- the theme of the components on the page ------------------------------------------

"The page's colours, font and text size, for the components that a live block shows"
component_theme(zoom=1.0) = Theme(size=TEXT_SIZE * zoom * LABEL, surface=colours.float, text=colours.ink, dim=colours.dim, line=colours.line,
                          track=colours.faint, hover=colours.hover, select=colours.active,
                          accent=colours.accent, on_accent=colours.bg, family=SANS, mono=SHEET_FONT, mono_style=SHEET_WEIGHT,
                          number=colours.number, string=colours.string, symbol=colours.call,
                          keyword=colours.keyword, type=colours.type)

# A sheet's text is in Source Code Pro ExtraLight, a step lighter than
# Centient's Light. A Mac without that font gets the font of the code blocks.
const SHEET_FILE = something(findfirst(isfile, joinpath.((joinpath(homedir(), "Library/Fonts"), "/Library/Fonts"),
                                                         "SourceCodePro-ExtraLight.ttf")) |>
                             i -> i === nothing ? nothing : joinpath((joinpath(homedir(), "Library/Fonts"), "/Library/Fonts")[i],
                                                                     "SourceCodePro-ExtraLight.ttf"), "")

const SHEET_FONT = isempty(SHEET_FILE) ? MONO : "Source Code Pro"

const SHEET_WEIGHT = isempty(SHEET_FILE) ? "" : "ExtraLight"

const capitals = Dict{Tuple{String,String,Float32},px}()

"How tall a capital letter of `face` is"
capital(face::Face) = get!(capitals, (face.family, face.style, Float32(num(face.size)))) do
  metrics = Ref{Skia.sk_font_metrics_t}()
  Skia.sk_font_get_metrics(skia_font(face.family, face.size, face.style).raw, metrics)
  px(metrics[].capHeight)
end
