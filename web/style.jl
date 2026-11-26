# Works out how each element of a page looks: its `Style`, from the page's
# CSS, what its tag says (`<td bgcolor=red width=50%>`), and what a browser
# gives each tag to start with.
#
#     doc = document(html)
#     look = styles(doc, 700)      # for a page 700 px wide
#     s = look[element]
#     s.display, s.color, s.size   # :block, 0xff000000, 16.0
#     px(s.width, 700)             # a length in px, where a percent is of 700
#     look.before[element]         # the style of its `::before`, when it has one. Also `after` and `marker`.
#
# A length is a `Len`: so many px, a share of something that's known later
# (the width of the box that the element is in), `auto`, or a word like
# `min-content`. A colour is a UInt32 like 0xAARRGGBB.
#
# What's here: the cascade, with layers (@layer), `!important`, `inherit`,
# `initial`, `unset` and `revert`. Variables (`--x`, `var(--x)`). Sums
# (`calc()`, `min()`, `max()`, `clamp()`). Every way to write a colour. The
# parts of an element (`::before`, `::after`, `::marker`). Rules for the box
# that an element is in (@container), once `containers` says how big each is.
# Fonts from the web (@font-face). Animations (@keyframes): with a time, each
# element looks as its animations make it then. With none, an element shows
# the end of an animation that stops and stays there. With a time and a
# `Clock`, a style that changes from one layout to the next takes the time
# that its `transition` says.
#
# Dark mode: `with(() -> styles(doc, 700), DARK => true)` works out the styles
# for a screen in dark mode, so `@media (prefers-color-scheme: dark)` is for
# it. An element whose `color-scheme` (or the page's `<meta
# name="color-scheme">`) says it can be dark takes the dark colours of the
# system then: `canvas`, `canvastext`, links, form fields and the second
# colour of `light-dark()`. A page that says `color-scheme: dark` is dark on
# any screen. One that says nothing stays light, as in a browser.

@use "./dom" Element Text Document attr walk
@use "./css" Declaration Rule Stylesheet Selector sheet read! declarations matches media container container_name pieces closing resolve selectors DARK
using Base.ScopedValues: ScopedValue, with
@use "./text" => Fonts

# --- lengths ------------------------------------------------------------------------------

struct Len
  px::Float64
  pct::Float64    # a share of what the length is a percent of: 0.5 for 50%
  em::Float64     # so many of the element's font size. It's px by the time the style is made.
  auto::Bool
  how::Symbol     # :length, or a word in place of a length: :min_content, :max_content, :fit_content, :stretch, :content
  math::Any       # nothing, or the `Math` of a length that's the least or the most of several
end

"A length that's worked out from others when what a percent is of is known: the least of them, the most, their sum, or one of them made bigger"
struct Math
  op::Symbol            # :min, :max, :add or :scale
  args::Vector{Len}
  k::Float64
end

Len(px::Real) = Len(px, 0, 0, false, :length, nothing)
Len(px, pct, em, auto) = Len(px, pct, em, auto, :length, nothing)
Len(m::Math) = Len(0, 0, 0, false, :length, m)
const AUTO = Len(0, 0, 0, true)
const ZERO = Len(0)
percent(share) = Len(0, share, 0, false)
"A word in place of a length, like `min-content`"
word(how::Symbol) = Len(0, 0, 0, false, how, nothing)

solve(m::Math, base) = m.op == :min ? minimum(a -> px(a, base), m.args) : m.op == :max ? maximum(a -> px(a, base), m.args) :
                       m.op == :add ? sum(a -> px(a, base), m.args) : px(m.args[1], base) * m.k

"`l` in px, where a percent is of `base`"
px(l::Len, base=0.0) = l.math === nothing ? l.px + l.pct * (isfinite(base) ? base : 0.0) : solve(l.math::Math, base)
isauto(l::Len) = l.auto
ispercent(l::Len) = l.math === nothing ? l.pct != 0 : any(ispercent, (l.math::Math).args)
"True for a word in place of a length, like `min-content`"
iskey(l::Len) = l.how != :length
Base.:+(a::Len, b::Len) = a.math === nothing && b.math === nothing ? Len(a.px + b.px, a.pct + b.pct, a.em + b.em, false) : Len(Math(:add, [a, b], 1.0))
Base.:*(a::Len, k::Real) = a.math === nothing ? Len(a.px * k, a.pct * k, a.em * k, false) : Len(Math(:scale, [a], Float64(k)))
Base.:-(a::Len, b::Len) = a + b * -1

"`l` with its ems as px, for a font `size` px tall"
flat(l::Len, size) = begin
  if l.math === nothing
    return l.em == 0 ? l : Len(l.px + l.em * size, l.pct, 0, l.auto, l.how, nothing)
  end
  m = l.math::Math
  out = Len(Math(m.op, Len[flat(a, size) for a in m.args], m.k))
  ispercent(out) ? out : Len(px(out))
end

"What's known of the page while a style is worked out"
struct Context
  wide::Float64     # how wide the page is, in px
  root::Float64     # the font size of the <html> element
  quirks::Bool      # a number with no unit is px
  high::Float64     # how high the window that the page is seen through is
end
Context(wide, root, quirks) = Context(wide, root, quirks, 800.0)

const UNITS = Dict("px" => 1.0, "pt" => 4 / 3, "pc" => 16.0, "in" => 96.0, "cm" => 96 / 2.54, "mm" => 96 / 25.4, "q" => 96 / 101.6)
const NUMBER = r"^([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)([a-z%]*)$"
const ANGLES = Dict("deg" => π / 180, "rad" => 1.0, "grad" => π / 200, "turn" => 2π)

"What the number `x` with the unit `unit` is: a length, or a plain number (an angle is in radians), or nothing"
quantity(x, unit, c::Context) =
  unit == "" ? x : unit == "%" ? Len(0, x / 100, 0, false) : unit == "px" ? Len(x) :
  unit == "em" ? Len(0, 0, x, false) : unit in ("ex", "ch") ? Len(0, 0, x / 2, false) : unit == "cap" ? Len(0, 0, 0.7x, false) :
  unit == "ic" ? Len(0, 0, x, false) : unit == "lh" ? Len(0, 0, 1.2x, false) : unit == "rlh" ? Len(1.2x * c.root) :
  unit == "rem" ? Len(x * c.root) :
  unit in ("vw", "svw", "lvw", "dvw", "vi", "cqw", "cqi") ? Len(x * c.wide / 100) :
  unit in ("vh", "svh", "lvh", "dvh", "vb", "cqh", "cqb") ? Len(x * c.high / 100) :
  unit in ("vmin", "svmin", "lvmin", "dvmin", "cqmin") ? Len(x * min(c.wide, c.high) / 100) :
  unit in ("vmax", "svmax", "lvmax", "dvmax", "cqmax") ? Len(x * max(c.wide, c.high) / 100) :
  haskey(UNITS, unit) ? Len(x * UNITS[unit]) : haskey(ANGLES, unit) ? x * ANGLES[unit] :
  unit in ("s", "ms", "x", "dppx", "dpi", "hz") ? x : nothing

"The length that `v` writes, or nothing. With `bare`, a number with no unit is px."
len(v::AbstractString, c::Context; bare=c.quirks, percent=true) = begin
  v = lowercase(strip(v))
  v == "auto" && return AUTO
  m = match(NUMBER, v)
  if m !== nothing
    x = tryparse(Float64, m[1])
    x === nothing && return nothing
    unit = m[2]
    unit == "" && return x == 0 || bare ? Len(x) : nothing
    unit == "%" && return percent ? Len(0, x / 100, 0, false) : nothing
    l = quantity(x, unit, c)
    return l isa Len ? l : nothing
  end
  occursin('(', v) || return nothing
  x = math(v, c)
  x isa Len ? (percent || !ispercent(x) ? x : nothing) : x isa Float64 && (x == 0 || bare) ? Len(x) : nothing
end

"The number that `v` writes, as it is or as a sum, or nothing"
number(v::AbstractString, c::Context) = begin
  x = tryparse(Float64, v)
  x !== nothing && return x
  occursin('(', v) || return nothing
  x = math(v, c)
  x isa Float64 ? x : nothing
end

"The angle that `v` writes, in radians, or nothing. A plain 0 is an angle."
angle(v::AbstractString) = begin
  m = match(r"^([+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?)(deg|rad|grad|turn)?$", lowercase(strip(v)))
  m === nothing && return nothing
  x = Base.parse(Float64, m[1])
  m[2] === nothing ? (x == 0 ? 0.0 : nothing) : x * ANGLES[m[2]]
end

"True for a length that's less than nothing whatever it's a share of. A sum like `100% - 20px` isn't."
negative(l::Len) = l.math === nothing && max(l.px, l.pct, l.em) <= 0 && min(l.px, l.pct, l.em) < 0

"A length that isn't `auto` and isn't less than nothing"
size_len(v, c; kw...) = (l = len(v, c; kw...); l === nothing || l.auto || negative(l) ? nothing : l)
"A length that can be `auto`, and isn't less than nothing"
box_len(v, c; kw...) = (l = len(v, c; kw...); l === nothing || negative(l) ? nothing : l)

const MATH = r"[a-z][a-z0-9-]*\(|\(|\)|,|[*/]|[+-](?=\s)|[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?[a-z%]*|-?[a-z][a-z-]*"

plain(a) = a isa Len && a.math === nothing && a.pct == 0 && a.em == 0 && !a.auto

"What the function `name` of a sum makes of `args`: each is a length, a number or a word"
apply(name, args) = begin
  any(isnothing, args) && return nothing
  nums = all(a -> a isa Float64, args)
  if name == "calc"
    length(args) == 1 ? args[1] : nothing
  elseif name in ("min", "max")
    isempty(args) && return nothing
    f = name == "min" ? min : max
    nums ? f(args...) : !all(a -> a isa Len, args) ? nothing : all(plain, args) ? Len(f((a.px for a in args)...)) : Len(Math(Symbol(name), Len[args...], 1.0))
  elseif name == "clamp"
    length(args) == 3 || return nothing
    lo, mid, hi = args
    top = hi isa Symbol ? mid : apply("min", Any[mid, hi])
    lo isa Symbol ? top : apply("max", Any[lo, top])
  elseif name == "abs" && length(args) == 1
    nums ? abs(args[1]) : plain(args[1]) ? Len(abs(args[1].px)) : nothing
  elseif name == "sign" && length(args) == 1
    nums ? sign(args[1]) : plain(args[1]) ? sign(args[1].px) : nothing
  elseif name == "round"
    how = !isempty(args) && args[1] isa Symbol ? popfirst!(args) : :nearest
    f = how == :up ? ceil : how == :down ? floor : how == :to_zero ? trunc : round
    a = args[1]
    b = length(args) > 1 ? args[2] : (a isa Len ? Len(1) : 1.0)
    a isa Float64 && b isa Float64 ? (b == 0 ? NaN : f(a / b) * b) : plain(a) && plain(b) && b.px != 0 ? Len(f(a.px / b.px) * b.px) : nothing
  elseif name in ("mod", "rem") && length(args) == 2
    f = name == "mod" ? mod : rem
    nums ? f(args...) : all(plain, args) && args[2].px != 0 ? Len(f(args[1].px, args[2].px)) : nothing
  elseif name in ("sin", "cos", "tan", "asin", "acos", "atan", "sqrt", "exp") && length(args) == 1 && nums
    name == "sin" ? sin(args[1]) : name == "cos" ? cos(args[1]) : name == "tan" ? tan(args[1]) : name == "asin" ? asin(clamp(args[1], -1, 1)) :
    name == "acos" ? acos(clamp(args[1], -1, 1)) : name == "atan" ? atan(args[1]) : name == "sqrt" ? sqrt(max(0.0, args[1])) : exp(args[1])
  elseif name == "pow" && length(args) == 2 && nums
    Float64(args[1]^args[2])
  elseif name == "atan2" && length(args) == 2
    nums ? atan(args...) : all(plain, args) ? atan(args[1].px, args[2].px) : nothing
  elseif name == "log" && nums && length(args) in (1, 2)
    length(args) == 1 ? log(max(args[1], 0.0)) : log(args[2], max(args[1], 0.0))
  elseif name == "hypot" && !isempty(args)
    nums ? hypot(args...) : all(plain, args) ? Len(hypot((a.px for a in args)...)) : nothing
  else
    nothing
  end
end

"""
What a sum like `calc(100% - 2 * 10px)` or `clamp(1rem, 2.5vw, 2rem)` comes
to: a length, a number, or nothing. `names` gives the numbers that words
stand for, as in a colour that's worked out from another.
"""
math(s::AbstractString, c::Context; names=nothing) = begin
  toks = [m.match for m in eachmatch(MATH, lowercase(s))]
  i = Ref(1)
  peek() = i[] <= length(toks) ? toks[i[]] : ""
  take() = (t = peek(); i[] += 1; t)
  value() = begin
    t = take()
    if t == "("
      v = total()
      take()
      return v
    elseif endswith(t, "(")
      name = replace(t[1:end-1], r"^(webkit|moz)-" => "")
      args = Any[]
      if peek() != ")"
        push!(args, total())
        while peek() == ","
          take()
          push!(args, total())
        end
      end
      take()
      return apply(name, args)
    end
    m = match(NUMBER, t)
    if m !== nothing
      x = tryparse(Float64, m[1])
      return x === nothing ? nothing : quantity(x, m[2], c)
    end
    names !== nothing && haskey(names, t) && return names[t]
    t == "pi" ? Float64(π) : t == "e" ? Float64(ℯ) : t == "infinity" ? Inf : t == "-infinity" ? -Inf : t == "" ? nothing : Symbol(replace(t, '-' => '_'))
  end
  product() = begin
    a = value()
    while peek() in ("*", "/")
      op = take()
      b = value()
      (a === nothing || b === nothing) && return nothing
      a = op == "*" ? (a isa Len && b isa Float64 ? a * b : a isa Float64 && b isa Len ? b * a : a isa Float64 && b isa Float64 ? a * b : nothing) :
          b isa Float64 && b != 0 ? (a isa Len ? a * (1 / b) : a isa Float64 ? a / b : nothing) : nothing
    end
    a
  end
  total() = begin
    a = product()
    while peek() in ("+", "-")
      op = take()
      b = product()
      a = a isa Len && b isa Len ? (op == "+" ? a + b : a - b) : a isa Float64 && b isa Float64 ? (op == "+" ? a + b : a - b) : nothing
    end
    a
  end
  v = total()
  v isa Symbol ? nothing : v
end

"What `calc(...)` comes to as a length, or nothing: kept for the callers that have only what's in its brackets"
calc(s::AbstractString, c::Context) = (v = math("calc(" * s * ")", c); v isa Len ? v : nothing)

# --- colours ------------------------------------------------------------------------------

const COLOURS = Dict{String,UInt32}(
  "black" => 0xff000000, "silver" => 0xffc0c0c0, "gray" => 0xff808080, "grey" => 0xff808080, "white" => 0xffffffff, "maroon" => 0xff800000,
  "red" => 0xffff0000, "purple" => 0xff800080, "fuchsia" => 0xffff00ff, "magenta" => 0xffff00ff, "green" => 0xff008000, "lime" => 0xff00ff00,
  "olive" => 0xff808000, "yellow" => 0xffffff00, "navy" => 0xff000080, "blue" => 0xff0000ff, "teal" => 0xff008080, "aqua" => 0xff00ffff,
  "cyan" => 0xff00ffff, "orange" => 0xffffa500, "aliceblue" => 0xfff0f8ff, "antiquewhite" => 0xfffaebd7, "aquamarine" => 0xff7fffd4,
  "azure" => 0xfff0ffff, "beige" => 0xfff5f5dc, "bisque" => 0xffffe4c4, "blanchedalmond" => 0xffffebcd, "blueviolet" => 0xff8a2be2,
  "brown" => 0xffa52a2a, "burlywood" => 0xffdeb887, "cadetblue" => 0xff5f9ea0, "chartreuse" => 0xff7fff00, "chocolate" => 0xffd2691e,
  "coral" => 0xffff7f50, "cornflowerblue" => 0xff6495ed, "cornsilk" => 0xfffff8dc, "crimson" => 0xffdc143c, "darkblue" => 0xff00008b,
  "darkcyan" => 0xff008b8b, "darkgoldenrod" => 0xffb8860b, "darkgray" => 0xffa9a9a9, "darkgrey" => 0xffa9a9a9, "darkgreen" => 0xff006400,
  "darkkhaki" => 0xffbdb76b, "darkmagenta" => 0xff8b008b, "darkolivegreen" => 0xff556b2f, "darkorange" => 0xffff8c00, "darkorchid" => 0xff9932cc,
  "darkred" => 0xff8b0000, "darksalmon" => 0xffe9967a, "darkseagreen" => 0xff8fbc8f, "darkslateblue" => 0xff483d8b, "darkslategray" => 0xff2f4f4f,
  "darkslategrey" => 0xff2f4f4f, "darkturquoise" => 0xff00ced1, "darkviolet" => 0xff9400d3, "deeppink" => 0xffff1493, "deepskyblue" => 0xff00bfff,
  "dimgray" => 0xff696969, "dimgrey" => 0xff696969, "dodgerblue" => 0xff1e90ff, "firebrick" => 0xffb22222, "floralwhite" => 0xfffffaf0,
  "forestgreen" => 0xff228b22, "gainsboro" => 0xffdcdcdc, "ghostwhite" => 0xfff8f8ff, "gold" => 0xffffd700, "goldenrod" => 0xffdaa520,
  "greenyellow" => 0xffadff2f, "honeydew" => 0xfff0fff0, "hotpink" => 0xffff69b4, "indianred" => 0xffcd5c5c, "indigo" => 0xff4b0082,
  "ivory" => 0xfffffff0, "khaki" => 0xfff0e68c, "lavender" => 0xffe6e6fa, "lavenderblush" => 0xfffff0f5, "lawngreen" => 0xff7cfc00,
  "lemonchiffon" => 0xfffffacd, "lightblue" => 0xffadd8e6, "lightcoral" => 0xfff08080, "lightcyan" => 0xffe0ffff,
  "lightgoldenrodyellow" => 0xfffafad2, "lightgray" => 0xffd3d3d3, "lightgrey" => 0xffd3d3d3, "lightgreen" => 0xff90ee90, "lightpink" => 0xffffb6c1,
  "lightsalmon" => 0xffffa07a, "lightseagreen" => 0xff20b2aa, "lightskyblue" => 0xff87cefa, "lightslategray" => 0xff778899,
  "lightslategrey" => 0xff778899, "lightsteelblue" => 0xffb0c4de, "lightyellow" => 0xffffffe0, "limegreen" => 0xff32cd32, "linen" => 0xfffaf0e6,
  "mediumaquamarine" => 0xff66cdaa, "mediumblue" => 0xff0000cd, "mediumorchid" => 0xffba55d3, "mediumpurple" => 0xff9370db,
  "mediumseagreen" => 0xff3cb371, "mediumslateblue" => 0xff7b68ee, "mediumspringgreen" => 0xff00fa9a, "mediumturquoise" => 0xff48d1cc,
  "mediumvioletred" => 0xffc71585, "midnightblue" => 0xff191970, "mintcream" => 0xfff5fffa, "mistyrose" => 0xffffe4e1, "moccasin" => 0xffffe4b5,
  "navajowhite" => 0xffffdead, "oldlace" => 0xfffdf5e6, "olivedrab" => 0xff6b8e23, "orangered" => 0xffff4500, "orchid" => 0xffda70d6,
  "palegoldenrod" => 0xffeee8aa, "palegreen" => 0xff98fb98, "paleturquoise" => 0xffafeeee, "palevioletred" => 0xffdb7093, "papayawhip" => 0xffffefd5,
  "peachpuff" => 0xffffdab9, "peru" => 0xffcd853f, "pink" => 0xffffc0cb, "plum" => 0xffdda0dd, "powderblue" => 0xffb0e0e6, "rebeccapurple" => 0xff663399,
  "rosybrown" => 0xffbc8f8f, "royalblue" => 0xff4169e1, "saddlebrown" => 0xff8b4513, "salmon" => 0xfffa8072, "sandybrown" => 0xfff4a460,
  "seagreen" => 0xff2e8b57, "seashell" => 0xfffff5ee, "sienna" => 0xffa0522d, "skyblue" => 0xff87ceeb, "slateblue" => 0xff6a5acd,
  "slategray" => 0xff708090, "slategrey" => 0xff708090, "snow" => 0xfffffafa, "springgreen" => 0xff00ff7f, "steelblue" => 0xff4682b4,
  "tan" => 0xffd2b48c, "thistle" => 0xffd8bfd8, "tomato" => 0xffff6347, "turquoise" => 0xff40e0d0, "violet" => 0xffee82ee, "wheat" => 0xfff5deb3,
  "whitesmoke" => 0xfff5f5f5, "yellowgreen" => 0xff9acd32, "transparent" => 0x00000000,
  # The colours of the system, as a light Mac has them
  "-webkit-link" => 0xff0000ee, "linktext" => 0xff0000ee, "visitedtext" => 0xff551a8b, "activetext" => 0xffff0000, "-webkit-activelink" => 0xffff0000,
  "windowtext" => 0xff000000, "window" => 0xffffffff, "canvas" => 0xffffffff, "canvastext" => 0xff000000, "buttonface" => 0xffefefef,
  "buttontext" => 0xff000000, "buttonborder" => 0xff767676, "field" => 0xffffffff, "fieldtext" => 0xff000000, "highlight" => 0xffb3d7ff,
  "highlighttext" => 0xff000000, "selecteditem" => 0xff0063e1, "selecteditemtext" => 0xffffffff, "mark" => 0xffffff00, "marktext" => 0xff000000,
  "graytext" => 0xff808080, "accentcolor" => 0xff0a7aff, "accentcolortext" => 0xffffffff, "threedface" => 0xffefefef, "menu" => 0xffefefef,
  "menutext" => 0xff000000, "infobackground" => 0xffffffe1, "infotext" => 0xff000000, "activeborder" => 0xff767676, "inactiveborder" => 0xff767676,
  "threedshadow" => 0xff767676, "threeddarkshadow" => 0xff767676, "threedhighlight" => 0xffefefef, "threedlightshadow" => 0xffefefef,
  "buttonhighlight" => 0xffefefef, "buttonshadow" => 0xff767676, "captiontext" => 0xff000000, "inactivecaptiontext" => 0xff808080,
  "background" => 0xffffffff, "appworkspace" => 0xffffffff, "scrollbar" => 0xffffffff, "activecaption" => 0xffffffff, "inactivecaption" => 0xffffffff)

# The colours of the system that differ in the dark scheme, as WebKit on a Mac in dark mode has them. Some are see-through.
const NIGHT = Dict{String,UInt32}(
  "-webkit-link" => 0xff9e9eff, "linktext" => 0xff9e9eff, "visitedtext" => 0xffd0adf0, "activetext" => 0xffff9e9e, "-webkit-activelink" => 0xffff9e9e,
  "window" => 0xff1e1e1e, "canvas" => 0xff1e1e1e, "background" => 0xff1e1e1e, "inactiveborder" => 0xff1e1e1e, "inactivecaption" => 0xff1e1e1e,
  "canvastext" => 0xffffffff, "highlighttext" => 0xffffffff, "infotext" => 0xffffffff, "captiontext" => 0xffffffff, "inactivecaptiontext" => 0xffffffff,
  "windowtext" => 0xd9ffffff, "buttontext" => 0xd9ffffff, "fieldtext" => 0xd9ffffff, "menutext" => 0xd9ffffff, "activecaption" => 0xd9ffffff,
  "buttonface" => 0x40ffffff, "field" => 0x40ffffff, "threedface" => 0x40ffffff, "graytext" => 0x40ffffff,
  "threedlightshadow" => 0x1affffff, "buttonhighlight" => 0x1affffff, "threedhighlight" => 0xffb4b4b4, "highlight" => 0xcc3f638b,
  "menu" => 0xff373737, "activeborder" => 0xff1aa9ff, "appworkspace" => 0xffffffff)

"""
True while the styles being worked out are for an element whose colour
scheme is dark: the system's colours, like `canvas`, are those of `NIGHT`
then, and `light-dark()` gives its second colour. `styles` sets it from each
element's `color-scheme`.
"""
const DARK_SCHEME = ScopedValue(false)

"The background of a page whose colour scheme is dark, where the page gives none"
const DARK_CANVAS = 0xff1e1e1e

argb(r, g, b, a=1.0) = UInt32(round(clamp(a, 0, 1) * 255)) << 24 | UInt32(round(clamp(r, 0, 255))) << 16 | UInt32(round(clamp(g, 0, 255))) << 8 | UInt32(round(clamp(b, 0, 255)))
alpha(c::UInt32) = (c >> 24) / 255
# In a style, this stands for the element's own text colour until that's known. It's a colour that draws nothing, which no page writes.
const CURRENT = 0x00fffe01

"The colour of six or eight hex digits, or of three or four"
hex(h) = begin
  all(c -> isdigit(c) || 'a' <= c <= 'f', h) || return nothing
  n = length(h)
  n in (3, 4) && (h = join(c^2 for c in h))
  n in (3, 4, 6, 8) || return nothing
  x = Base.parse(UInt32, h[1:6], base=16)
  a = length(h) == 8 ? Base.parse(UInt32, h[7:8], base=16) : 0x000000ff
  a << 24 | x
end

hue(p, q, t) = (t = mod(t, 1); t < 1 / 6 ? p + (q - p) * 6t : t < 1 / 2 ? q : t < 2 / 3 ? p + (q - p) * (2 / 3 - t) * 6 : p)

# Each way to write a colour is a space. These turn a colour of a space into red, green and blue from 0 to 1, and back.
lin(c) = abs(c) <= 0.04045 ? c / 12.92 : sign(c) * ((abs(c) + 0.055) / 1.055)^2.4
gam(c) = abs(c) <= 0.0031308 ? 12.92c : sign(c) * (1.055 * abs(c)^(1 / 2.4) - 0.055)
times(m, v) = (m[1] * v[1] + m[2] * v[2] + m[3] * v[3], m[4] * v[1] + m[5] * v[2] + m[6] * v[3], m[7] * v[1] + m[8] * v[2] + m[9] * v[3])
const RGB_XYZ = (0.41239079926595934, 0.357584339383878, 0.1804807884018343, 0.21263900587151027, 0.715168678767756, 0.07219231536073371,
                 0.01933081871559182, 0.11919477979462598, 0.9505321522496607)
const XYZ_RGB = (3.2409699419045226, -1.537383177570094, -0.4986107602930034, -0.9692436362808796, 1.8759675015077202, 0.04155505740717559,
                 0.05563007969699366, -0.20397695888897652, 1.0569715142428786)
const P3_XYZ = (0.4865709486482162, 0.26566769316909306, 0.1982172852343625, 0.2289745640697488, 0.6917385218365064, 0.079286914093745,
                0.0, 0.04511338185890264, 1.043944368900976)
const XYZ_P3 = (2.493496911941425, -0.9313836179191239, -0.40271078445071684, -0.8294889695615747, 1.7626640603183463, 0.023624685841943577,
                0.03584583024378447, -0.07617238926804182, 0.9568845240076872)
const D65_D50 = (1.0479297925449969, 0.022946870601609652, -0.05019226628920524, 0.02962780877005599, 0.9904344267538799, -0.017073799063418826,
                 -0.009243040646204504, 0.015055191490298152, 0.7518742814281371)
const D50_D65 = (0.955473421488075, -0.02309845494876471, 0.06325924320057072, -0.0283697093338637, 1.0099953980813041, 0.021041441191917323,
                 0.012314014864481998, -0.020507649298898964, 1.330365926242124)
const WHITE = (0.3457 / 0.3585, 1.0, (1 - 0.3457 - 0.3585) / 0.3585)

hsl_rgb(h, s, l) = begin
  q = l < 0.5 ? l * (1 + s) : l + s - l * s
  p = 2l - q
  (hue(p, q, h / 360 + 1 / 3), hue(p, q, h / 360), hue(p, q, h / 360 - 1 / 3))
end
rgb_hsl(r, g, b) = begin
  hi, lo = max(r, g, b), min(r, g, b)
  l = (hi + lo) / 2
  d = hi - lo
  d == 0 && return (0.0, 0.0, l)
  s = d / (1 - abs(2l - 1))
  h = hi == r ? mod((g - b) / d, 6) : hi == g ? (b - r) / d + 2 : (r - g) / d + 4
  (60h, s, l)
end
hwb_rgb(h, w, k) = begin
  w + k >= 1 && return (w / (w + k), w / (w + k), w / (w + k))
  map(x -> x * (1 - w - k) + w, hsl_rgb(h, 1.0, 0.5))
end
rgb_hwb(r, g, b) = (rgb_hsl(r, g, b)[1], min(r, g, b), 1 - max(r, g, b))
oklab_rgb(L, a, b) = begin
  l, m, s = (L + 0.3963377774a + 0.2158037573b)^3, (L - 0.1055613458a - 0.0638541728b)^3, (L - 0.0894841775a - 1.2914855480b)^3
  map(gam, (4.0767416621l - 3.3077115913m + 0.2309699292s, -1.2684380046l + 2.6097574011m - 0.3413193965s, -0.0041960863l - 0.7034186147m + 1.7076147010s))
end
rgb_oklab(r, g, b) = begin
  r, g, b = lin(r), lin(g), lin(b)
  l, m, s = cbrt(0.4122214708r + 0.5363325363g + 0.0514459929b), cbrt(0.2119034982r + 0.6806995451g + 0.1073969566b), cbrt(0.0883024619r + 0.2817188376g + 0.6299787005b)
  (0.2104542553l + 0.7936177850m - 0.0040720468s, 1.9779984951l - 2.4285922050m + 0.4505937099s, 0.0259040371l + 0.7827717662m - 0.8086757660s)
end
lab_rgb(L, a, b) = begin
  e, k = 216 / 24389, 24389 / 27
  fy = (L + 16) / 116
  fx, fz = a / 500 + fy, fy - b / 200
  xyz = ((fx^3 > e ? fx^3 : (116fx - 16) / k) * WHITE[1], (L > k * e ? fy^3 : L / k) * WHITE[2], (fz^3 > e ? fz^3 : (116fz - 16) / k) * WHITE[3])
  map(gam, times(XYZ_RGB, times(D50_D65, xyz)))
end
rgb_lab(r, g, b) = begin
  e, k = 216 / 24389, 24389 / 27
  xyz = times(D65_D50, times(RGB_XYZ, (lin(r), lin(g), lin(b))))
  f = map((v, w) -> (t = v / w; t > e ? cbrt(t) : (k * t + 16) / 116), xyz, WHITE)
  (116f[2] - 16, 500 * (f[1] - f[2]), 200 * (f[2] - f[3]))
end
polar(l, a, b) = (l, hypot(a, b), mod(rad2deg(atan(b, a)), 360))
square(l, c, h) = (l, c * cosd(h), c * sind(h))

const ROUND = ("hsl", "hwb", "lch", "oklch")   # the spaces whose colours have a hue

"The red, green and blue, from 0 to 1, of the colour with the channels `x`, `y` and `z` in `space`"
from_space(space, x, y, z) =
  space == "srgb" ? (x, y, z) : space == "srgb-linear" ? map(gam, (x, y, z)) : space == "hsl" ? hsl_rgb(x, y, z) : space == "hwb" ? hwb_rgb(x, y, z) :
  space == "oklab" ? oklab_rgb(x, y, z) : space == "oklch" ? oklab_rgb(square(x, y, z)...) : space == "lab" ? lab_rgb(x, y, z) :
  space == "lch" ? lab_rgb(square(x, y, z)...) : space in ("xyz", "xyz-d65") ? map(gam, times(XYZ_RGB, (x, y, z))) :
  space == "xyz-d50" ? map(gam, times(XYZ_RGB, times(D50_D65, (x, y, z)))) :
  space == "display-p3" ? map(gam, times(XYZ_RGB, times(P3_XYZ, map(lin, (x, y, z))))) : (x, y, z)

"The channels in `space` of the colour with the red, green and blue `r`, `g` and `b`, from 0 to 1"
to_space(space, r, g, b) =
  space == "srgb" ? (r, g, b) : space == "srgb-linear" ? map(lin, (r, g, b)) : space == "hsl" ? rgb_hsl(r, g, b) : space == "hwb" ? rgb_hwb(r, g, b) :
  space == "oklab" ? rgb_oklab(r, g, b) : space == "oklch" ? polar(rgb_oklab(r, g, b)...) : space == "lab" ? rgb_lab(r, g, b) :
  space == "lch" ? polar(rgb_lab(r, g, b)...) : space in ("xyz", "xyz-d65") ? times(RGB_XYZ, map(lin, (r, g, b))) :
  space == "xyz-d50" ? times(D65_D50, times(RGB_XYZ, map(lin, (r, g, b)))) :
  space == "display-p3" ? map(gam, times(XYZ_P3, times(RGB_XYZ, map(lin, (r, g, b))))) : (r, g, b)

unpack(c::UInt32) = (((c >> 16) & 0xff) / 255, ((c >> 8) & 0xff) / 255, (c & 0xff) / 255, (c >> 24) / 255)
const PLAIN = Context(0.0, 16.0, false)

"The words of what's in a colour's brackets: a comma or a space is between two, and a `/` is a word of its own"
channels(inside) = begin
  out = IOBuffer()
  depth = 0
  for ch in inside
    ch == '(' ? (depth += 1) : ch == ')' ? (depth -= 1) : nothing
    depth == 0 && ch == ',' ? print(out, ' ') : depth == 0 && ch == '/' ? print(out, " / ") : print(out, ch)
  end
  terms(String(take!(out)))
end

"The colour that `name(inside)` writes, like `oklch(60% 0.2 240 / 50%)`, or nothing"
functional(name, inside) = begin
  if name == "light-dark"
    parts = pieces(inside, ',')
    return isempty(parts) ? nothing : colour(parts[length(parts) > 1 && DARK_SCHEME[] ? 2 : 1])
  elseif name == "color-mix"
    parts = [strip(p) for p in pieces(inside, ',')]
    length(parts) == 3 || return nothing
    m = match(r"^in\s+([a-z0-9-]+)", parts[1])
    m === nothing && return nothing
    space = m[1]
    one(p) = begin
      ws = terms(p)
      share = findfirst(w -> endswith(w, '%'), ws)
      k = share === nothing ? nothing : tryparse(Float64, chop(ws[share]))
      c = colour(join((ws[i] for i in eachindex(ws) if i != share), " "))
      c isa UInt32 ? (c, k) : nothing
    end
    a, b = one(parts[2]), one(parts[3])
    (a === nothing || b === nothing) && return nothing
    pa, pb = a[2], b[2]
    pa === nothing && pb === nothing && ((pa, pb) = (50.0, 50.0))
    pa === nothing && (pa = 100 - pb)
    pb === nothing && (pb = 100 - pa)
    pa + pb <= 0 && return nothing
    dim = min(1.0, (pa + pb) / 100)
    t = pb / (pa + pb)
    ra, rb = unpack(a[1]), unpack(b[1])
    ca, cb = to_space(space, ra[1:3]...), to_space(space, rb[1:3]...)
    al = ra[4] * (1 - t) + rb[4] * t
    mixed = ntuple(3) do i
      if (space in ROUND) && i == (space in ("hsl", "hwb") ? 1 : 3)
        d = mod(cb[i] - ca[i] + 180, 360) - 180   # round the short way
        return mod(ca[i] + d * t, 360)
      end
      # A see-through colour counts for less
      al <= 0 ? ca[i] : (ca[i] * ra[4] * (1 - t) + cb[i] * rb[4] * t) / al
    end
    r, g, bl = from_space(space, mixed...)
    return argb(255r, 255g, 255bl, al * dim)
  end
  haskey(SPACES, name) || name == "color" || return nothing
  ws = channels(inside)
  names = nothing
  if !isempty(ws) && ws[1] == "from" && length(ws) > 2
    origin = colour(ws[2])
    origin isa UInt32 || return nothing
    ws = ws[3:end]
    r, g, b, a = unpack(origin)
    space = name == "color" ? (isempty(ws) ? "srgb" : ws[1]) : SPACES[name][1]
    x, y, z = to_space(space, r, g, b)
    keys = name == "color" ? (occursin("xyz", space) ? ("x", "y", "z") : ("r", "g", "b")) : SPACES[name][2]
    scale = name in ("rgb", "rgba") ? (255.0, 255.0, 255.0) : name in ("hsl", "hsla") ? (1.0, 100.0, 100.0) : name == "hwb" ? (1.0, 100.0, 100.0) : (1.0, 1.0, 1.0)
    names = Dict{String,Any}(keys[1] => x * scale[1], keys[2] => y * scale[2], keys[3] => z * scale[3], "alpha" => a)
  end
  space = "srgb"
  if name == "color"
    isempty(ws) && return nothing
    space = popfirst!(ws)
  end
  cut = findfirst(==("/"), ws)
  comps = cut === nothing ? ws : ws[1:cut-1]
  # The old way has the alpha as a fourth number
  al = cut !== nothing && cut < length(ws) ? ws[cut+1] : length(comps) == 4 ? pop!(comps) : "1"
  length(comps) == 3 || return nothing
  # A channel: `full` is what 100% of it is, and `turn` is true for a hue
  chan(t, full; turn=false) = begin
    t == "none" && return 0.0
    endswith(t, '%') && (x = tryparse(Float64, chop(t))) !== nothing && return x / 100 * full
    turn && (x = angle(t)) !== nothing && return rad2deg(x)
    (x = tryparse(Float64, t)) !== nothing && return x
    x = math(t, PLAIN; names)
    x isa Float64 ? x : nothing
  end
  a = chan(al, 1.0)
  a === nothing && return nothing
  rgb = if name in ("rgb", "rgba")
    v = (chan(comps[1], 255.0), chan(comps[2], 255.0), chan(comps[3], 255.0))
    any(isnothing, v) ? nothing : v ./ 255
  elseif name in ("hsl", "hsla", "hwb")
    # A plain number is a percent here
    v = (chan(comps[1], 360.0; turn=true), chan(comps[2], 100.0), chan(comps[3], 100.0))
    any(isnothing, v) ? nothing : (name == "hwb" ? hwb_rgb : hsl_rgb)(v[1], clamp(v[2] / 100, 0, 1), clamp(v[3] / 100, 0, 1))
  elseif name in ("lab", "oklab")
    v = (chan(comps[1], name == "lab" ? 100.0 : 1.0), chan(comps[2], name == "lab" ? 125.0 : 0.4), chan(comps[3], name == "lab" ? 125.0 : 0.4))
    any(isnothing, v) ? nothing : from_space(name, v...)
  elseif name in ("lch", "oklch")
    v = (chan(comps[1], name == "lch" ? 100.0 : 1.0), chan(comps[2], name == "lch" ? 150.0 : 0.4), chan(comps[3], 360.0; turn=true))
    any(isnothing, v) ? nothing : from_space(name, v...)
  else
    v = (chan(comps[1], 1.0), chan(comps[2], 1.0), chan(comps[3], 1.0))
    any(isnothing, v) ? nothing : from_space(space, v...)
  end
  rgb === nothing ? nothing : argb(255rgb[1], 255rgb[2], 255rgb[3], a)
end

# Each way to write a colour with a word and brackets: its space, and the names of its channels
const SPACES = Dict("rgb" => ("srgb", ("r", "g", "b")), "rgba" => ("srgb", ("r", "g", "b")), "hsl" => ("hsl", ("h", "s", "l")), "hsla" => ("hsl", ("h", "s", "l")),
                    "hwb" => ("hwb", ("h", "w", "b")), "lab" => ("lab", ("l", "a", "b")), "lch" => ("lch", ("l", "c", "h")),
                    "oklab" => ("oklab", ("l", "a", "b")), "oklch" => ("oklch", ("l", "c", "h")))

"""
The colour that `v` writes, or nothing: a name, #rgb, #rrggbb, rgb(), hsl(),
hwb(), lab(), lch(), oklab(), oklch(), color(), color-mix(), light-dark(), or
one of these worked out from another (`rgb(from red r g b / 50%)`).
`currentcolor` is the symbol `:current`. With `loose`, as in a tag's
`bgcolor`, the hex digits need no # before them.
"""
colour(v::AbstractString; loose=false) = begin
  v = lowercase(strip(v))
  haskey(NIGHT, v) && DARK_SCHEME[] && return NIGHT[v]
  haskey(COLOURS, v) && return COLOURS[v]
  v == "currentcolor" && return :current
  startswith(v, '#') && return hex(SubString(v, 2))
  m = match(r"^([a-z-]+)\((.*)\)$"s, v)
  m !== nothing && return functional(m[1], m[2])
  loose && length(v) in (3, 6) ? hex(v) : nothing
end

"A colour for a style: the element's own text colour is `CURRENT` until it's known"
paint(v) = (x = colour(v); x === :current ? CURRENT : x)

# --- the parts of a style that hold several things ----------------------------------------

"One step of a `transform`: a move by `x` and `y`, or a turn, a stretch or a slant with the numbers `n`"
struct Turn
  kind::Symbol            # :move, :spin or :matrix
  x::Len
  y::Len
  n::NTuple{6,Float64}    # of a matrix: a, b, c, d, e, f, as CSS's matrix() has them. Of a spin: the angle in radians, then zeros.
end

"One shadow of a box or of text. The colour is `CURRENT` for the element's own."
struct Shade
  dx::Float64
  dy::Float64
  blur::Float64
  spread::Float64
  color::UInt32
  inset::Bool
end

"One step of a `filter`, like blur(4px) or brightness(1.2)"
struct Effect
  kind::Symbol
  x::Float64
  y::Float64
  z::Float64
  color::UInt32
end

"How big a track of a grid can be: a length, a share of what's left (`fr`), or as its content asks"
struct Size
  kind::Symbol     # :length, :fr, :auto, :min_content, :max_content or :fit (fit-content, no more than `len`)
  len::Len
  fr::Float64
end
struct Track
  min::Size
  max::Size
end
const ANY_TRACK = Track(Size(:auto, ZERO, 0.0), Size(:auto, ZERO, 0.0))

"The columns or the rows that a grid's style gives it"
struct Template
  tracks::Vector{Track}             # the tracks, up to a `repeat(auto-fill, ...)`
  again::Vector{Track}              # the tracks that are there as often as fits
  after::Vector{Track}              # the tracks after those
  fit::Bool                         # with `auto-fit`, a track that's there again and has nothing in it takes no room
  names::Dict{String,Vector{Int}}   # the lines that have each name
end
const NO_TEMPLATE = Template(Track[], Track[], Track[], false, Dict{String,Vector{Int}}())

const NO_STRINGS = String[]
const NO_TURNS = Turn[]
const NO_SHADES = Shade[]
const NO_EFFECTS = Effect[]
const NO_TRACKS = Track[]
const NO_AREAS = Vector{String}[]
const NO_VARS = Dict{String,String}()
const ONE_REPEAT = [(:repeat, :repeat)]
const ONE_PLACE = [(ZERO, ZERO)]
const ONE_SIZE = Any[:auto]
const ONE_CLIP = [:border]
const ONE_ORIGIN = [:padding]
# No z-index
const NO_Z = typemin(Int)

# --- a style ------------------------------------------------------------------------------

const Sides{T} = NTuple{4,T}   # the top, the right, the bottom and the left
sides(x) = (x, x, x, x)

"How an element looks. What a child gets from its parent is under the line."
Base.@kwdef mutable struct Style
  display::Symbol = :inline
  position::Symbol = :static                    # :static, :relative, :absolute, :fixed or :sticky
  float::Symbol = :none
  clear::Symbol = :none
  opacity::Float64 = 1.0
  overflow::Symbol = :visible
  borderbox::Bool = false                       # the width and the height are of the border, not of the content
  width::Len = AUTO
  height::Len = AUTO
  minwidth::Len = AUTO                          # `auto` is nothing, but for a thing in a flex box, where it's as narrow as the content can be
  minheight::Len = AUTO
  maxwidth::Len = AUTO                          # `auto` for none
  maxheight::Len = AUTO
  aspect::Tuple{Float64,Bool} = (NaN, false)    # the width over the height, and whether a picture's own shape comes first
  margin::Sides{Len} = sides(ZERO)
  padding::Sides{Len} = sides(ZERO)
  border::Sides{Len} = sides(Len(3))            # how thick each line is. It's nothing while its style is :none.
  borderstyle::Sides{Symbol} = sides(:none)
  bordercolor::Sides{Any} = sides(:current)
  borderimage::String = ""
  radius::Sides{Len} = sides(ZERO)              # of the top left corner, the top right, the bottom right and the bottom left: how far across
  radiusv::Sides{Len} = sides(ZERO)             # and how far down
  inset::Sides{Len} = sides(AUTO)               # top, right, bottom and left, for an element with a position
  zindex::Int = NO_Z
  background::UInt32 = 0x00000000
  image::Vector{String} = NO_STRINGS            # the background's pictures, the top one first: each a `url(...)` or a gradient, as it's written
  repeat::Vector{Tuple{Symbol,Symbol}} = ONE_REPEAT   # for each picture, across and down: :repeat, :no_repeat, :space or :round
  bgposition::Vector{Tuple{Len,Len}} = ONE_PLACE
  bgsize::Vector{Any} = ONE_SIZE                # for each: :auto, :cover, :contain, or the width and the height
  bgclip::Vector{Symbol} = ONE_CLIP             # for each: :border, :padding, :content or :text
  bgorigin::Vector{Symbol} = ONE_ORIGIN
  valign::Tuple{Symbol,Len} = (:baseline, ZERO)
  decoration::UInt8 = 0x00                      # the lines that this element asks for: 1 under, 2 through, 4 over
  decostyle::Symbol = :solid
  decocolor::UInt32 = CURRENT
  decothick::Len = AUTO
  tablelayout::Symbol = :auto
  shadow::Vector{Shade} = NO_SHADES
  outline::Len = Len(3)                         # the line round the box, outside its border
  outlinestyle::Symbol = :none
  outlinecolor::UInt32 = CURRENT
  outlineoffset::Len = ZERO
  loose::Tuple{Bool,Bool} = (false, false)      # its top and its bottom margin are the ones that a browser gives its tag, which a page with no doctype drops at the edge of a cell
  # A flex box and what's in one
  flexdir::Symbol = :row
  flexwrap::Symbol = :nowrap
  justify::Symbol = :normal                     # justify-content
  alignitems::Symbol = :normal
  aligncontent::Symbol = :normal
  justifyitems::Symbol = :normal
  alignself::Symbol = :auto
  justifyself::Symbol = :auto
  grow::Float64 = 0.0
  shrink::Float64 = 1.0
  basis::Len = AUTO
  order::Int = 0
  gap::Tuple{Len,Len} = (AUTO, AUTO)            # between rows and between columns. `auto` is the usual gap.
  # A grid and what's in one
  gridcols::Template = NO_TEMPLATE
  gridrows::Template = NO_TEMPLATE
  autocols::Vector{Track} = NO_TRACKS
  autorows::Vector{Track} = NO_TRACKS
  autoflow::Symbol = :row                       # :row, :column, :row_dense or :column_dense
  gridareas::Vector{Vector{String}} = NO_AREAS
  gridplace::Sides{Any} = sides(:auto)          # the row it starts at, the column it starts at, the row it ends at and the column: a line, (:span, n), a name or :auto
  # Columns of text
  colcount::Int = 0
  colwidth::Len = AUTO
  colrule::Len = Len(3)
  colrulestyle::Symbol = :none
  colrulecolor::UInt32 = CURRENT
  # A picture's place in its box
  objectfit::Symbol = :fill
  objectat::Tuple{Len,Len} = (percent(0.5), percent(0.5))
  # What changes how the box is drawn
  transform::Vector{Turn} = NO_TURNS
  translate::Vector{Turn} = NO_TURNS
  rotate::Vector{Turn} = NO_TURNS
  scale::Vector{Turn} = NO_TURNS
  origin::Tuple{Len,Len} = (percent(0.5), percent(0.5))
  filter::Vector{Effect} = NO_EFFECTS
  blend::Symbol = :normal
  isolate::Bool = false
  clippath::String = ""
  mask::String = ""
  # What a part of an element (`::before`) holds, and the counters
  content::String = ""
  counterreset::String = ""
  counterincrement::String = ""
  counterset::String = ""
  textoverflow::Symbol = :clip
  lineclamp::Int = 0
  appearance::Symbol = :auto
  container::Symbol = :none                     # :none, :inline_size or :size: rules can ask how big it is
  containername::String = ""
  # ---------------------------------------------------------------------------------------
  visible::Bool = true
  color::UInt32 = 0xff000000
  family::Vector{String} = NO_STRINGS
  size::Float64 = 16.0
  weight::Int = 400
  italic::Bool = false
  stretch::Float64 = 100.0                      # how wide its letters are, in percent of the font's normal width: `font-stretch`
  smallcaps::Bool = false
  lineheight::Tuple{Symbol,Float64} = (:normal, 0.0)   # :normal, :number (so many font sizes) or :px
  align::Symbol = :start                        # :start, :end, :left, :right, :center, :justify, and :wk_left, :wk_center, :wk_right, which move blocks too
  alignlast::Symbol = :auto
  direction::Symbol = :ltr
  textcase::Symbol = :none                      # text-transform
  letterspacing::Len = ZERO
  wordspacing::Len = ZERO
  whitespace::Symbol = :normal                  # :normal, :nowrap, :pre, :pre_wrap or :pre_line
  textwrap::Symbol = :auto                      # :auto, :balance for lines of about one length, or :pretty for lines that WebKit picks for the whole paragraph
  tabsize::Float64 = 8.0
  indent::Len = ZERO
  wrap::Symbol = :normal                        # :normal, :break_word (a long word breaks to fit), :anywhere (and its box can be that narrow) or :all (any word breaks)
  collapse::Bool = false                        # the borders of a table's cells are one line
  cellspacing::Tuple{Float64,Float64} = (0.0, 0.0)
  emptycells::Bool = true
  listtype::Symbol = :disc
  listtext::String = ""                         # what a list item shows before it, when the page gives the words
  listimage::String = ""
  listinside::Bool = false
  captionbottom::Bool = false
  quotes::String = "auto"
  textshadow::Vector{Shade} = NO_SHADES
  stroke::Len = ZERO                            # the line round each letter
  strokecolor::UInt32 = CURRENT
  textfill::UInt32 = CURRENT                    # the colour inside each letter, when it isn't the text's colour
  underoffset::Len = AUTO
  rendering::Symbol = :auto                     # :auto or :pixelated: how a picture is made bigger
  accent::UInt32 = 0x00000000                   # the colour of a ticked box, or nothing for the system's
  lines::UInt8 = 0x00                           # the lines that its text is drawn with, from this element and the ones round it
  linecolor::UInt32 = 0xff000000
  linestyle::Symbol = :solid
  linethick::Float64 = 0.0                      # 0 for as thick as the font says
  vars::Dict{String,String} = NO_VARS           # the page's variables (`--x`), and how an SVG shape is drawn (`fill`, `stroke`)
end

const INHERITED = (:visible, :color, :family, :size, :weight, :italic, :stretch, :smallcaps, :lineheight, :align, :alignlast, :direction, :textcase,
                   :letterspacing, :wordspacing, :whitespace, :textwrap, :tabsize, :indent, :wrap, :collapse, :cellspacing, :emptycells, :listtype,
                   :listtext, :listimage, :listinside, :captionbottom, :quotes, :textshadow, :stroke, :strokecolor, :textfill, :underoffset,
                   :rendering, :accent, :lines, :linecolor, :linestyle, :linethick, :vars)
const DEFAULT = Style()

# The style that a child of an element with the style `parent` starts with. It's written out field by field, which is much
# quicker than a loop over the names of the fields.
@eval begin
  "The style that a child of an element with the style `parent` starts with"
  child(parent::Style) = begin
    s = Style()
    $((:(s.$f = parent.$f) for f in INHERITED)...)
    s
  end
end

"How thick the border of side `i` is, in px"
border(s::Style, i) = s.borderstyle[i] in (:none, :hidden) ? 0.0 : s.border[i].px

"How tall a line of text is, for a font whose own line is `normal` px tall"
lineheight(s::Style, normal) = s.lineheight[1] == :normal ? Float64(normal) : s.lineheight[1] == :number ? s.lineheight[2] * s.size : s.lineheight[2]

# --- what each property takes -------------------------------------------------------------

struct Prop
  field::Symbol
  side::Int          # which of the four sides, or 0 for the whole field
  read::Function     # (value in lower case, value, Context, parent's Style) → what the field takes, or nothing
  get::Function      # (Style) → what the field holds
  set::Function      # (Style, value) → gives the field the value
end

const PROPS = Dict{String,Prop}()
# A function for each field that reads it, and one that gives it a value: these are quicker than a field that's named when the page is read
const GETTERS = Dict{Symbol,Function}(f => @eval(s::Style -> s.$f) for f in fieldnames(Style))
const SETTERS = Dict{Symbol,Function}(f => @eval((s::Style, v) -> (s.$f = v)) for f in fieldnames(Style))
prop!(read, name, field, side=0) = PROPS[name] = Prop(field, side, read, GETTERS[field], SETTERS[field])
"A property that takes one of `words`. Each is the symbol of its name, or what it's paired with."
words!(name, field, words...) = begin
  table = Dict{String,Any}(w isa Pair ? w : w => Symbol(replace(w, '-' => '_')) for w in words)
  prop!((v, _, _, _) -> get(table, v, nothing), name, field)
end

"`v` cut at its spaces, with what's in brackets or quotes kept whole"
terms(v) = filter(!isempty, strip.(pieces(replace(v, r"\s+" => " "), ' ')))

const SIDE_NAMES = ("top", "right", "bottom", "left")
const DISPLAYS = Dict("inline" => :inline, "block" => :block, "inline-block" => :inline_block, "none" => :none, "list-item" => :list_item,
  "table" => :table, "inline-table" => :inline_table, "table-row" => :table_row, "table-cell" => :table_cell, "table-row-group" => :table_row_group,
  "table-header-group" => :table_header_group, "table-footer-group" => :table_footer_group, "table-column" => :table_column,
  "table-column-group" => :table_column_group, "table-caption" => :table_caption, "flex" => :flex, "inline-flex" => :inline_flex,
  "grid" => :grid, "inline-grid" => :inline_grid, "flow-root" => :flow_root, "contents" => :contents, "-webkit-box" => :old_box,
  "-webkit-inline-box" => :inline_flex, "-webkit-flex" => :flex, "-webkit-inline-flex" => :inline_flex, "-ms-flexbox" => :flex, "-ms-grid" => :grid,
  "block flow" => :block, "inline flow" => :inline, "block flow-root" => :flow_root, "inline flow-root" => :inline_block, "block flex" => :flex,
  "inline flex" => :inline_flex, "block grid" => :grid, "inline grid" => :inline_grid, "ruby" => :inline, "ruby-text" => :inline, "math" => :inline,
  "run-in" => :inline)
prop!((v, _, _, _) -> get(DISPLAYS, v, nothing), "display", :display)
words!("position", :position, "static", "relative", "absolute", "fixed", "sticky", "-webkit-sticky" => :sticky)
words!("float", :float, "none", "left", "right", "inline-start" => :left, "inline-end" => :right)
words!("clear", :clear, "none", "left", "right", "both", "inline-start" => :left, "inline-end" => :right)
# What overflows is cut off when it's cut off across or down: `overflow: hidden auto` says each
prop!("overflow", :overflow) do v, _, _, _
  ws = split(v)
  (isempty(ws) || length(ws) > 2 || !all(w -> w in ("visible", "hidden", "clip", "scroll", "auto", "overlay"), ws)) && return nothing
  all(==("visible"), ws) ? :visible : :hidden
end
words!("box-sizing", :borderbox, "border-box" => true, "content-box" => false)
words!("visibility", :visible, "visible" => true, "hidden" => false, "collapse" => false)
words!("table-layout", :tablelayout, "auto", "fixed")
words!("font-style", :italic, "normal" => false, "italic" => true, "oblique" => true)
words!("text-align", :align, "start", "end", "left", "right", "center", "justify", "-webkit-left" => :wk_left, "-webkit-right" => :wk_right,
       "-webkit-center" => :wk_center, "-moz-center" => :wk_center, "-moz-left" => :wk_left, "-moz-right" => :wk_right, "match-parent" => :start,
       "-webkit-match-parent" => :start, "justify-all" => :justify)
words!("text-align-last", :alignlast, "auto", "start", "end", "left", "right", "center", "justify")
words!("direction", :direction, "ltr", "rtl")
words!("text-transform", :textcase, "none", "uppercase", "lowercase", "capitalize", "full-width" => :none, "full-size-kana" => :none)
words!("white-space", :whitespace, "normal", "nowrap", "pre", "pre-wrap", "pre-line", "break-spaces" => :pre_wrap, "-webkit-nowrap" => :nowrap)
words!("white-space-collapse", :whitespace, "collapse" => :normal, "preserve" => :pre_wrap, "preserve-breaks" => :pre_line, "break-spaces" => :pre_wrap,
       "preserve-spaces" => :pre_wrap)
words!("text-wrap-style", :textwrap, "auto", "balance", "pretty", "stable" => :auto)
words!("border-collapse", :collapse, "collapse" => true, "separate" => false)
words!("empty-cells", :emptycells, "show" => true, "hide" => false)
words!("list-style-position", :listinside, "inside" => true, "outside" => false)
words!("caption-side", :captionbottom, "bottom" => true, "top" => false, "block-end" => true, "block-start" => false)
const LIST_TYPES = Dict{String,Symbol}(w => Symbol(replace(w, '-' => '_')) for w in
  ("disc", "circle", "square", "decimal", "none", "lower-alpha", "upper-alpha", "lower-roman", "upper-roman", "lower-greek", "decimal-leading-zero",
   "disclosure-open", "disclosure-closed"))
merge!(LIST_TYPES, Dict("lower-latin" => :lower_alpha, "upper-latin" => :upper_alpha))
prop!("list-style-type", :listtype) do v, _, _, _
  haskey(LIST_TYPES, v) && return LIST_TYPES[v]
  # Words in quotes are shown as they are. Any other way to count is 1, 2, 3.
  startswith(v, '"') || startswith(v, '\'') ? :text : occursin(r"^[a-z-]+$", v) ? :decimal : nothing
end
words!("overflow-wrap", :wrap, "normal", "break-word", "anywhere")
words!("word-wrap", :wrap, "normal", "break-word", "anywhere")
words!("word-break", :wrap, "normal", "break-all" => :all, "break-word" => :anywhere, "keep-all" => :normal, "auto-phrase" => :normal)
words!("line-break", :wrap, "anywhere" => :anywhere)
words!("flex-direction", :flexdir, "row", "row-reverse", "column", "column-reverse")
words!("flex-wrap", :flexwrap, "nowrap", "wrap", "wrap-reverse")
words!("object-fit", :objectfit, "fill", "contain", "cover", "none", "scale-down")
words!("text-overflow", :textoverflow, "clip", "ellipsis")
words!("isolation", :isolate, "isolate" => true, "auto" => false)
words!("image-rendering", :rendering, "auto", "pixelated", "crisp-edges" => :pixelated, "-webkit-optimize-contrast" => :auto, "smooth" => :auto,
       "high-quality" => :auto, "optimizequality" => :auto, "optimizespeed" => :pixelated)
words!("mix-blend-mode", :blend, "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge", "color-burn", "hard-light", "soft-light",
       "difference", "exclusion", "hue", "saturation", "color", "luminosity", "plus-lighter" => :plus, "plus-darker" => :multiply)
words!("text-decoration-style", :decostyle, "solid", "double", "dotted", "dashed", "wavy")
words!("column-rule-style", :colrulestyle, "none", "hidden" => :none, "solid", "dashed", "dotted", "double", "groove" => :solid, "ridge" => :solid,
       "inset" => :solid, "outset" => :solid)
words!("container-type", :container, "normal" => :none, "size", "inline-size", "scroll-state" => :none)
words!("grid-auto-flow", :autoflow, "row", "column", "dense" => :row_dense, "row dense" => :row_dense, "column dense" => :column_dense,
       "dense row" => :row_dense, "dense column" => :column_dense)
prop!((v, _, _, _) -> v == "none" ? :none : occursin(r"^[a-z-]+$", v) ? :auto : nothing, "appearance", :appearance)
prop!((v, raw, _, _) -> v == "none" ? "" : String(strip(raw)), "container-name", :containername)

prop!((v, _, c, _) -> (x = endswith(v, '%') ? (y = tryparse(Float64, chop(v)); y === nothing ? nothing : y / 100) : number(v, c)) === nothing ? nothing : clamp(x, 0, 1), "opacity", :opacity)
prop!((v, _, c, _) -> v == "auto" ? NO_Z : (x = number(v, c)) === nothing ? nothing : round(Int, x), "z-index", :zindex)
prop!((v, _, c, _) -> (x = number(v, c)) === nothing ? nothing : round(Int, x), "order", :order)
prop!((v, _, c, _) -> (x = number(v, c)) === nothing || x < 0 ? nothing : x, "flex-grow", :grow)
prop!((v, _, c, _) -> (x = number(v, c)) === nothing || x < 0 ? nothing : x, "flex-shrink", :shrink)

# The words that a width can be in place of a length
const WIDTH_WORDS = Dict("min-content" => :min_content, "max-content" => :max_content, "fit-content" => :fit_content, "-webkit-fit-content" => :fit_content,
                         "-moz-fit-content" => :fit_content, "-webkit-min-content" => :min_content, "-webkit-max-content" => :max_content,
                         "-moz-min-content" => :min_content, "-moz-max-content" => :max_content, "stretch" => :stretch, "-webkit-fill-available" => :stretch,
                         "-moz-available" => :stretch, "fill-available" => :stretch, "intrinsic" => :max_content, "min-intrinsic" => :min_content)
"A width: a length, `auto`, or a word like `min-content`. `fit-content(200px)` is the length with the word."
extent(v, c) = begin
  haskey(WIDTH_WORDS, v) && return word(WIDTH_WORDS[v])
  if startswith(v, "fit-content(") && endswith(v, ")")
    l = size_len(v[13:end-1], c)
    return l === nothing ? nothing : Len(l.px, l.pct, l.em, false, :fit_limit, nothing)
  end
  box_len(v, c)
end
prop!((v, _, c, _) -> extent(v, c), "width", :width)
# A height that's a word is as tall as the content, which `auto` is too
prop!((v, _, c, _) -> haskey(WIDTH_WORDS, v) || startswith(v, "fit-content(") ? AUTO : box_len(v, c), "height", :height)
prop!((v, _, c, _) -> v == "auto" ? AUTO : extent(v, c), "min-width", :minwidth)
prop!((v, _, c, _) -> v == "auto" || haskey(WIDTH_WORDS, v) ? AUTO : size_len(v, c), "min-height", :minheight)
prop!((v, _, c, _) -> v == "none" ? AUTO : extent(v, c), "max-width", :maxwidth)
prop!((v, _, c, _) -> v == "none" || haskey(WIDTH_WORDS, v) ? AUTO : size_len(v, c), "max-height", :maxheight)
prop!((v, _, c, _) -> v == "content" ? word(:content) : extent(v, c), "flex-basis", :basis)
prop!("aspect-ratio", :aspect) do v, _, c, _
  v == "auto" && return (NaN, false)
  own = occursin(r"(^|\s)auto(\s|$)", v)
  parts = split(strip(replace(v, r"(^|\s)auto(\s|$)" => " ")), '/')
  a = number(strip(parts[1]), c)
  b = length(parts) > 1 ? number(strip(parts[2]), c) : 1.0
  a === nothing || b === nothing || a <= 0 || b <= 0 ? nothing : (a / b, own)
end

const THICK = Dict("thin" => Len(1), "medium" => Len(3), "thick" => Len(5))
const LINES = Dict(w => Symbol(w) for w in ("none", "hidden", "solid", "dashed", "dotted", "double", "groove", "ridge", "inset", "outset"))
thick(v, c) = haskey(THICK, v) ? THICK[v] : size_len(v, c; percent=false)
for (i, side) in enumerate(SIDE_NAMES)
  prop!((v, _, c, _) -> len(v, c), "margin-$side", :margin, i)
  prop!((v, _, c, _) -> size_len(v, c), "padding-$side", :padding, i)
  prop!((v, _, c, _) -> thick(v, c), "border-$side-width", :border, i)
  prop!((v, _, _, _) -> get(LINES, v, nothing), "border-$side-style", :borderstyle, i)
  prop!((v, _, _, _) -> colour(v), "border-$side-color", :bordercolor, i)
  prop!((v, _, c, _) -> len(v, c), side, :inset, i)
end
for (i, corner) in enumerate(("top-left", "top-right", "bottom-right", "bottom-left"))
  prop!((v, _, c, _) -> size_len(v, c), "border-$corner-radius-x", :radius, i)
  prop!((v, _, c, _) -> size_len(v, c), "border-$corner-radius-y", :radiusv, i)
end
prop!((v, raw, _, _) -> v == "none" ? "" : String(strip(raw)), "border-image", :borderimage)
prop!((v, raw, _, _) -> v == "none" ? "" : String(strip(raw)), "border-image-source", :borderimage)
prop!((v, _, c, _) -> thick(v, c), "outline-width", :outline)
prop!((v, _, _, _) -> v == "auto" ? :solid : get(LINES, v, nothing), "outline-style", :outlinestyle)
prop!((v, _, _, _) -> v == "invert" ? CURRENT : paint(v), "outline-color", :outlinecolor)
prop!((v, _, c, _) -> (l = len(v, c; percent=false)) === nothing || l.auto ? nothing : l, "outline-offset", :outlineoffset)
prop!((v, _, c, _) -> thick(v, c), "column-rule-width", :colrule)
prop!((v, _, _, _) -> paint(v), "column-rule-color", :colrulecolor)
prop!((v, _, c, _) -> v == "auto" ? 0 : (x = number(v, c)) === nothing || x < 1 ? nothing : round(Int, x), "column-count", :colcount)
prop!((v, _, c, _) -> v == "auto" ? AUTO : size_len(v, c; percent=false), "column-width", :colwidth)
prop!((v, _, c, _) -> v == "normal" ? AUTO : size_len(v, c), "row-gap", :gap, 1)
prop!((v, _, c, _) -> v == "normal" ? AUTO : size_len(v, c), "column-gap", :gap, 2)

prop!((v, _, _, s) -> (x = colour(v)) === :current ? s.color : x, "color", :color)
prop!((v, _, _, _) -> paint(v), "background-color", :background)
prop!((v, _, _, _) -> v == "auto" ? 0x00000000 : paint(v), "accent-color", :accent)
prop!((v, _, _, _) -> paint(v), "text-decoration-color", :decocolor)
prop!((v, _, c, _) -> v in ("auto", "from-font") ? AUTO : size_len(v, c), "text-decoration-thickness", :decothick)
prop!((v, _, c, _) -> v == "auto" ? AUTO : (l = len(v, c)) === nothing ? nothing : l, "text-underline-offset", :underoffset)
prop!((v, _, _, _) -> paint(v), "-webkit-text-fill-color", :textfill)
prop!((v, _, _, _) -> paint(v), "-webkit-text-stroke-color", :strokecolor)
prop!((v, _, c, _) -> thick(v, c), "-webkit-text-stroke-width", :stroke)

"Each part of `v` between two commas that are in no brackets, as `one` reads it, or nothing when it reads one of them as nothing"
several(one, v) = begin
  out = [one(strip(p)) for p in pieces(v, ',')]
  isempty(out) || any(isnothing, out) ? nothing : out
end

"True for a picture that CSS can write: an address or a gradient"
picture(v) = startswith(v, "url(") || occursin("gradient(", v) || startswith(v, "image-set(") || startswith(v, "-webkit-image-set(") || startswith(v, "image(")
prop!("background-image", :image) do v, raw, _, _
  found = several(p -> lowercase(p) == "none" ? "" : picture(lowercase(p)) ? String(p) : nothing, raw)
  found === nothing ? nothing : all(isempty, found) ? NO_STRINGS : Vector{String}(found)
end
const REPEATS = Dict("repeat" => :repeat, "no-repeat" => :no_repeat, "space" => :space, "round" => :round)
prop!("background-repeat", :repeat) do v, _, _, _
  found = several(v) do p
    p == "repeat-x" && return (:repeat, :no_repeat)
    p == "repeat-y" && return (:no_repeat, :repeat)
    ws = split(p)
    length(ws) in (1, 2) && all(w -> haskey(REPEATS, w), ws) ? (REPEATS[ws[1]], REPEATS[ws[end]]) : nothing
  end
  found === nothing ? nothing : Vector{Tuple{Symbol,Symbol}}(found)
end

"Where a picture goes in a box, as `center top` or `right 10px bottom 20%` writes it: how far across and how far down"
place(v, c) = begin
  ws = split(v)
  isempty(ws) && return nothing
  edge(w) = w == "center" ? percent(0.5) : w in ("left", "top") ? ZERO : w in ("right", "bottom") ? percent(1) : nothing
  x = y = nothing
  if length(ws) <= 2
    length(ws) == 1 && (ws = ws[1] in ("top", "bottom") ? ["center", ws[1]] : [ws[1], "center"])
    (ws[1] in ("top", "bottom") || ws[2] in ("left", "right")) && (ws = reverse(ws))
    x = something(edge(ws[1]), Some(len(ws[1], c)))
    y = something(edge(ws[2]), Some(len(ws[2], c)))
  else
    # A side with how far in from it: `right 10px bottom 20%`
    i = 1
    while i <= length(ws)
      w = ws[i]
      off = i < length(ws) && edge(ws[i+1]) === nothing ? len(ws[i+1], c) : nothing
      at = edge(w)
      at === nothing && return nothing
      off === nothing || (at = w in ("right", "bottom") ? percent(1) - off : off; i += 1)
      w in ("left", "right") ? (x = at) : w in ("top", "bottom") ? (y = at) : x === nothing ? (x = at) : (y = at)
      i += 1
    end
    x === nothing && (x = percent(0.5))
    y === nothing && (y = percent(0.5))
  end
  x === nothing || y === nothing || x.auto || y.auto ? nothing : (x, y)
end
prop!((v, _, c, _) -> (found = several(p -> place(p, c), v); found === nothing ? nothing : Vector{Tuple{Len,Len}}(found)), "background-position", :bgposition)
prop!((v, _, c, _) -> place(v, c), "object-position", :objectat)
prop!("transform-origin", :origin) do v, _, c, _
  ws = split(v)
  place(join(ws[1:min(2, length(ws))], " "), c)
end
prop!("background-size", :bgsize) do v, _, c, _
  found = several(v) do p
    p in ("cover", "contain", "auto") && return Symbol(p)
    ws = split(p)
    length(ws) in (1, 2) || return nothing
    w = len(ws[1], c)
    h = length(ws) == 2 ? len(ws[2], c) : AUTO
    w === nothing || h === nothing ? nothing : (w, h)
  end
  found === nothing ? nothing : Vector{Any}(found)
end
const BOXES = Dict("border-box" => :border, "padding-box" => :padding, "content-box" => :content, "text" => :text)
prop!((v, _, _, _) -> (found = several(p -> get(BOXES, p, nothing), v); found === nothing ? nothing : Vector{Symbol}(found)), "background-clip", :bgclip)
prop!((v, _, _, _) -> (found = several(p -> get(BOXES, p, nothing), v); found === nothing ? nothing : Vector{Symbol}(found)), "background-origin", :bgorigin)

prop!("vertical-align", :valign) do v, _, c, _
  v in ("baseline", "top", "middle", "bottom", "sub", "super", "text-top", "text-bottom") && return (Symbol(replace(v, '-' => '_')), ZERO)
  v == "-webkit-baseline-middle" && return (:middle, ZERO)
  l = len(v, c)
  l === nothing || l.auto ? nothing : (:length, l)
end
prop!("text-decoration-line", :decoration) do v, _, _, _
  v == "none" && return 0x00
  bits = 0x00
  for w in split(v)
    bits |= w == "underline" ? 0x01 : w == "line-through" ? 0x02 : w == "overline" ? 0x04 : w in ("blink", "spelling-error", "grammar-error") ? 0x00 : return nothing
  end
  bits
end

"The shadows that `v` writes for a box or for text, where an em is `size` px"
shades(v, c, size) = begin
  lowercase(strip(v)) == "none" && return NO_SHADES
  found = several(v) do one
    nums = Float64[]
    color = CURRENT
    inset = false
    for w in terms(one)
      lw = lowercase(w)
      if lw == "inset"
        inset = true
      elseif (l = len(lw, c; percent=false)) !== nothing && !l.auto
        push!(nums, px(flat(l, size)))
      elseif (x = paint(lw)) !== nothing
        color = x
      else
        return nothing
      end
    end
    length(nums) in 2:4 ? Shade(nums[1], nums[2], max(0.0, get(nums, 3, 0.0)), get(nums, 4, 0.0), color, inset) : nothing
  end
  found === nothing ? nothing : Vector{Shade}(found)
end
prop!((v, raw, c, parent) -> shades(raw, c, parent.size), "box-shadow", :shadow)
prop!((v, raw, c, parent) -> shades(raw, c, parent.size), "text-shadow", :textshadow)

"The words in the brackets of each function of `v`, like `rotate(45deg) scale(2, 3)`: its name, and what's between its commas or spaces"
calls(v) = begin
  out = Tuple{String,Vector{String}}[]
  upto = 0
  for m in eachmatch(r"([a-zA-Z0-9-]+)\(", v)
    # A function in the brackets of another is part of it
    m.offset <= upto && continue
    open = m.offset + ncodeunits(m.match) - 1
    stop = closing(v, open, '(', ')')
    stop > lastindex(v) && break
    upto = stop
    inside = SubString(v, open + 1, prevind(v, stop))
    args = occursin(',', inside) ? [String(strip(a)) for a in pieces(inside, ',')] : [String(a) for a in terms(inside)]
    push!(out, (lowercase(m[1]), args))
  end
  out
end

matrix(a, b, c, d, e, f) = Turn(:matrix, ZERO, ZERO, (a, b, c, d, e, f))
"A turn by `r` radians. It keeps the angle, so that an animation can turn a box all the way round."
spin(r) = Turn(:spin, ZERO, ZERO, (Float64(r), 0.0, 0.0, 0.0, 0.0, 0.0))

"The steps of a `transform`, or nothing when one can't be read. One that turns out of the page is drawn as flat as it would look from the front."
turns(v, c) = begin
  lowercase(strip(v)) == "none" && return NO_TURNS
  out = Turn[]
  l(a) = (x = len(lowercase(a), c; bare=true); x === nothing || x.auto ? nothing : x)
  n(a) = number(lowercase(a), c)
  an(a) = (x = angle(a); x !== nothing ? x : (y = math(a, c); y isa Float64 ? y : nothing))
  for (name, args) in calls(v)
    isempty(args) && return nothing
    step = if name == "translate" || name == "translate3d"
      x, y = l(args[1]), length(args) > 1 ? l(args[2]) : ZERO
      x === nothing || y === nothing ? nothing : Turn(:move, x, y, (0.0, 0.0, 0.0, 0.0, 0.0, 0.0))
    elseif name == "translatex"
      (x = l(args[1])) === nothing ? nothing : Turn(:move, x, ZERO, (0.0, 0.0, 0.0, 0.0, 0.0, 0.0))
    elseif name == "translatey"
      (y = l(args[1])) === nothing ? nothing : Turn(:move, ZERO, y, (0.0, 0.0, 0.0, 0.0, 0.0, 0.0))
    elseif name == "scale" || name == "scale3d"
      a = endswith(args[1], '%') ? something(tryparse(Float64, chop(args[1])), NaN) / 100 : n(args[1])
      b = length(args) > 1 ? (endswith(args[2], '%') ? something(tryparse(Float64, chop(args[2])), NaN) / 100 : n(args[2])) : a
      a === nothing || b === nothing ? nothing : matrix(a, 0.0, 0.0, b, 0.0, 0.0)
    elseif name == "scalex"
      (a = n(args[1])) === nothing ? nothing : matrix(a, 0.0, 0.0, 1.0, 0.0, 0.0)
    elseif name == "scaley"
      (a = n(args[1])) === nothing ? nothing : matrix(1.0, 0.0, 0.0, a, 0.0, 0.0)
    elseif name in ("rotate", "rotatez")
      (r = an(args[1])) === nothing ? nothing : spin(r)
    elseif name == "rotate3d" && length(args) == 4
      r = an(args[4])
      axis = (n(args[1]), n(args[2]), n(args[3]))
      r === nothing || any(isnothing, axis) ? nothing : axis[3] != 0 && axis[1] == 0 && axis[2] == 0 ? spin(r * sign(axis[3])) :
        matrix(axis[2] != 0 ? cos(r) : 1.0, 0.0, 0.0, axis[1] != 0 ? cos(r) : 1.0, 0.0, 0.0)
    elseif name == "rotatex"
      (r = an(args[1])) === nothing ? nothing : matrix(1.0, 0.0, 0.0, cos(r), 0.0, 0.0)
    elseif name == "rotatey"
      (r = an(args[1])) === nothing ? nothing : matrix(cos(r), 0.0, 0.0, 1.0, 0.0, 0.0)
    elseif name == "skew"
      a, b = an(args[1]), length(args) > 1 ? an(args[2]) : 0.0
      a === nothing || b === nothing ? nothing : matrix(1.0, tan(b), tan(a), 1.0, 0.0, 0.0)
    elseif name == "skewx"
      (a = an(args[1])) === nothing ? nothing : matrix(1.0, 0.0, tan(a), 1.0, 0.0, 0.0)
    elseif name == "skewy"
      (a = an(args[1])) === nothing ? nothing : matrix(1.0, tan(a), 0.0, 1.0, 0.0, 0.0)
    elseif name == "matrix" && length(args) == 6
      m = map(n, args)
      any(isnothing, m) ? nothing : matrix(m...)
    elseif name == "matrix3d" && length(args) == 16
      m = map(n, args)
      any(isnothing, m) ? nothing : matrix(m[1], m[2], m[5], m[6], m[13], m[14])
    elseif name in ("translatez", "scalez", "perspective")
      continue
    else
      nothing
    end
    step === nothing && return nothing
    push!(out, step)
  end
  out
end
prop!((v, raw, c, _) -> turns(raw, c), "transform", :transform)
prop!("translate", :translate) do v, _, c, _
  v == "none" && return NO_TURNS
  ws = split(v)
  turns("translate(" * join(ws[1:min(2, length(ws))], ", ") * ")", c)
end
prop!("rotate", :rotate) do v, _, c, _
  v == "none" && return NO_TURNS
  ws = split(v)
  length(ws) == 1 ? turns("rotate($(ws[1]))", c) : length(ws) == 2 && ws[1] in ("x", "y", "z") ? turns("rotate$(ws[1])($(ws[2]))", c) :
  length(ws) == 2 && ws[2] in ("x", "y", "z") ? turns("rotate$(ws[2])($(ws[1]))", c) : length(ws) == 4 ? turns("rotate3d(" * join(ws, ", ") * ")", c) : nothing
end
prop!("scale", :scale) do v, _, c, _
  v == "none" && return NO_TURNS
  ws = split(v)
  turns("scale(" * join(ws[1:min(2, length(ws))], ", ") * ")", c)
end

prop!("filter", :filter) do v, raw, c, parent
  v == "none" && return NO_EFFECTS
  out = Effect[]
  for (name, args) in calls(raw)
    amount(default) = isempty(args) ? default : endswith(args[1], '%') ? something(tryparse(Float64, chop(args[1])), NaN) / 100 : something(number(lowercase(args[1]), c), NaN)
    e = if name == "blur"
      l = isempty(args) ? ZERO : len(lowercase(args[1]), c; percent=false)
      l === nothing ? nothing : Effect(:blur, px(flat(l, parent.size)), 0.0, 0.0, 0x00000000)
    elseif name in ("brightness", "contrast", "grayscale", "invert", "opacity", "saturate", "sepia")
      x = amount(1.0)
      isnan(x) ? nothing : Effect(Symbol(name), max(0.0, x), 0.0, 0.0, 0x00000000)
    elseif name == "hue-rotate"
      r = isempty(args) ? 0.0 : angle(args[1])
      r === nothing ? nothing : Effect(:hue, r, 0.0, 0.0, 0x00000000)
    elseif name == "drop-shadow"
      found = shades(join(args, " "), c, parent.size)
      found === nothing || isempty(found) ? nothing : Effect(:shadow, found[1].dx, found[1].dy, found[1].blur, found[1].color)
    elseif name == "url"
      continue
    else
      nothing
    end
    e === nothing && return nothing
    push!(out, e)
  end
  out
end
prop!((v, raw, _, _) -> v == "none" ? "" : String(strip(raw)), "clip-path", :clippath)
prop!("mask-image", :mask) do v, raw, _, _
  v == "none" && return ""
  first = strip(pieces(raw, ',')[1])
  picture(lowercase(first)) ? String(first) : nothing
end

prop!((v, raw, _, _) -> String(strip(raw)), "content", :content)
prop!((v, raw, _, _) -> v == "none" ? "" : String(strip(raw)), "counter-reset", :counterreset)
prop!((v, raw, _, _) -> v == "none" ? "" : String(strip(raw)), "counter-increment", :counterincrement)
prop!((v, raw, _, _) -> v == "none" ? "" : String(strip(raw)), "counter-set", :counterset)
prop!((v, raw, _, _) -> String(strip(raw)), "quotes", :quotes)
prop!((v, raw, _, _) -> v == "none" ? "" : startswith(v, "url(") ? String(strip(raw)) : nothing, "list-style-image", :listimage)
prop!((v, _, c, _) -> v == "none" ? 0 : (x = number(v, c)) === nothing || x < 1 ? nothing : round(Int, x), "-webkit-line-clamp", :lineclamp)
prop!((v, _, c, _) -> v == "none" ? 0 : (x = number(first(split(v)), c)) === nothing || x < 1 ? nothing : round(Int, x), "line-clamp", :lineclamp)
prop!("tab-size", :tabsize) do v, _, c, parent
  (x = number(v, c)) !== nothing && return max(0.0, x)
  l = size_len(v, c; percent=false)
  l === nothing ? nothing : px(flat(l, parent.size)) / max(1.0, parent.size / 4)
end
prop!("font-variant-caps", :smallcaps) do v, _, _, _
  v in ("small-caps", "all-small-caps", "petite-caps", "all-petite-caps") ? true : v in ("normal", "unicase", "titling-caps") ? false : nothing
end
prop!((v, _, _, _) -> occursin("small-caps", v) ? true : false, "font-variant", :smallcaps)

const GENERIC = ("serif", "sans-serif", "monospace", "cursive", "fantasy", "system-ui", "ui-sans-serif", "ui-serif", "ui-monospace", "ui-rounded", "math",
                 "emoji", "fangsong")
prop!("font-family", :family) do v, raw, _, _
  names = [String(strip(strip(n), ['"', '\''])) for n in pieces(raw, ',')]
  names = filter(!isempty, map(n -> lowercase(n) in GENERIC ? lowercase(n) : n, names))
  isempty(names) ? nothing : names
end
const SIZES = Dict("xx-small" => 9.0, "x-small" => 10.0, "small" => 13.0, "medium" => 16.0, "large" => 18.0, "x-large" => 24.0, "xx-large" => 32.0,
                   "xxx-large" => 48.0, "-webkit-xxx-large" => 48.0)
prop!("font-size", :size) do v, _, c, parent
  haskey(SIZES, v) && return SIZES[v]
  v == "smaller" && return parent.size / 1.2
  v == "larger" && return parent.size * 1.2
  v == "math" && return parent.size
  l = size_len(v, c)
  l === nothing ? nothing : px(flat(l, parent.size), parent.size)
end
# The words of `font-stretch`, and the percent of a normal width that each is
const STRETCHES = Dict("ultra-condensed" => 50.0, "extra-condensed" => 62.5, "condensed" => 75.0, "semi-condensed" => 87.5, "normal" => 100.0,
                       "semi-expanded" => 112.5, "expanded" => 125.0, "extra-expanded" => 150.0, "ultra-expanded" => 200.0)
"The percent of a normal width that `font-stretch: v` says, or nothing"
stretch(v, c=PLAIN) = haskey(STRETCHES, v) ? STRETCHES[v] : endswith(v, '%') && (x = number(chop(v), c)) !== nothing && x >= 0 ? Float64(x) : nothing
prop!((v, _, c, _) -> stretch(v, c), "font-width", :stretch)
prop!("font-weight", :weight) do v, _, c, parent
  v == "normal" ? 400 : v == "bold" ? 700 : v == "bolder" ? (parent.weight < 400 ? 400 : parent.weight < 600 ? 700 : 900) :
  v == "lighter" ? (parent.weight < 600 ? 100 : parent.weight < 800 ? 400 : 700) :
  (x = number(v, c)) !== nothing && 1 <= x <= 1000 ? round(Int, x) : nothing
end
prop!("line-height", :lineheight) do v, _, c, _
  v == "normal" && return (:normal, 0.0)
  (x = number(v, c)) !== nothing && return x >= 0 ? (:number, x) : nothing
  l = size_len(v, c)
  # A percent or an em is of this element's font size, which isn't known yet
  l === nothing ? nothing : l.math !== nothing ? (:px, px(l, 16.0)) : l.pct != 0 || l.em != 0 ? (:em, l.pct + l.em + l.px / 16) : (:px, l.px)
end
spacing(v, c) = v == "normal" ? ZERO : (l = len(v, c)) === nothing || l.auto ? nothing : ispercent(l) ? ZERO : l
prop!((v, _, c, _) -> spacing(v, c), "letter-spacing", :letterspacing)
prop!((v, _, c, _) -> spacing(v, c), "word-spacing", :wordspacing)
prop!((v, _, c, _) -> (l = len(first(terms(v)), c)) === nothing || l.auto ? nothing : l, "text-indent", :indent)
prop!("border-spacing", :cellspacing) do v, _, c, _
  ls = [size_len(w, c; percent=false) for w in split(v)]
  (isempty(ls) || length(ls) > 2 || any(isnothing, ls)) && return nothing
  (ls[1].px, ls[end].px)
end

# How a thing is placed in the room that it has, as `justify-content`, `align-items` and the rest say
const PLACES = Dict("normal" => :normal, "auto" => :auto, "stretch" => :stretch, "center" => :center, "start" => :start, "end" => :end,
                    "flex-start" => :flex_start, "flex-end" => :flex_end, "self-start" => :start, "self-end" => :end, "left" => :start, "right" => :end,
                    "baseline" => :baseline, "space-between" => :space_between, "space-around" => :space_around, "space-evenly" => :space_evenly,
                    "anchor-center" => :center)
placing(v) = begin
  v = strip(replace(v, r"\b(safe|unsafe|legacy|first|last)\b" => ""))
  get(PLACES, v, nothing)
end
for (name, field) in (("justify-content", :justify), ("align-items", :alignitems), ("align-content", :aligncontent), ("justify-items", :justifyitems),
                      ("align-self", :alignself), ("justify-self", :justifyself))
  prop!((v, _, _, _) -> placing(v), name, field)
end

# --- grids --------------------------------------------------------------------------------

"How big a track of a grid can be, as `1fr`, `200px`, `auto` or `min-content` writes it, or nothing"
track_size(v, c) = begin
  v == "auto" && return Size(:auto, ZERO, 0.0)
  v == "min-content" && return Size(:min_content, ZERO, 0.0)
  v == "max-content" && return Size(:max_content, ZERO, 0.0)
  if (m = match(r"^([0-9.]+)fr$", v)) !== nothing
    x = tryparse(Float64, m[1])
    return x === nothing ? nothing : Size(:fr, ZERO, x)
  end
  l = size_len(v, c)
  l === nothing ? nothing : Size(:length, l, 0.0)
end

"The track that `v` writes: one size, `minmax(a, b)` or `fit-content(a)`, or nothing"
track(v, c) = begin
  v = lowercase(strip(v))
  if startswith(v, "minmax(") && endswith(v, ")")
    parts = pieces(v[8:end-1], ',')
    length(parts) == 2 || return nothing
    lo, hi = track_size(strip(parts[1]), c), track_size(strip(parts[2]), c)
    (lo === nothing || hi === nothing) && return nothing
    # A share of what's left is no least size
    lo.kind == :fr && (lo = Size(:auto, ZERO, 0.0))
    return Track(lo, hi)
  elseif startswith(v, "fit-content(") && endswith(v, ")")
    l = size_len(v[13:end-1], c)
    return l === nothing ? nothing : Track(Size(:auto, ZERO, 0.0), Size(:fit, l, 0.0))
  end
  s = track_size(v, c)
  s === nothing ? nothing : s.kind == :fr ? Track(Size(:auto, ZERO, 0.0), s) : Track(s, s)
end

"The tracks that a list like `100px 1fr minmax(0, 2fr)` writes, with no names, or nothing"
track_list(v, c) = begin
  out = Track[]
  for w in terms(v)
    startswith(w, '[') && continue
    t = track(w, c)
    t === nothing && return nothing
    push!(out, t)
  end
  out
end

"The columns or the rows that `grid-template-columns: v` writes, or nothing"
template(v, c) = begin
  lowercase(strip(v)) in ("none", "subgrid", "masonry") && return NO_TEMPLATE
  tracks, again, after = Track[], Track[], Track[]
  names = Dict{String,Vector{Int}}()
  fit = false
  into = tracks
  name!(w) = for n in split(strip(w, ['[', ']']))
    # A name after the tracks that repeat is counted from the end, which isn't known here
    into === tracks && push!(get!(() -> Int[], names, String(n)), length(tracks) + 1)
  end
  for w in terms(v)
    lw = lowercase(w)
    if startswith(w, '[')
      name!(w)
    elseif startswith(lw, "repeat(") && endswith(lw, ")")
      parts = pieces(w[8:end-1], ',')
      length(parts) >= 2 || return nothing
      count = lowercase(strip(parts[1]))
      inner = join(parts[2:end], ",")
      if count in ("auto-fill", "auto-fit")
        found = track_list(inner, c)
        (found === nothing || !isempty(again)) && return nothing
        again = found
        fit = count == "auto-fit"
        into = after
      else
        n = tryparse(Int, count)
        (n === nothing || n < 1) && return nothing
        for _ in 1:min(n, 1000), x in terms(inner)
          if startswith(x, '[')
            name!(x)
          else
            t = track(x, c)
            t === nothing && return nothing
            push!(into, t)
          end
        end
      end
    elseif lw == "subgrid"
      continue
    else
      t = track(w, c)
      t === nothing && return nothing
      push!(into, t)
    end
  end
  Template(tracks, again, after, fit, names)
end
prop!((v, raw, c, _) -> template(raw, c), "grid-template-columns", :gridcols)
prop!((v, raw, c, _) -> template(raw, c), "grid-template-rows", :gridrows)
prop!((v, raw, c, _) -> track_list(raw, c), "grid-auto-columns", :autocols)
prop!((v, raw, c, _) -> track_list(raw, c), "grid-auto-rows", :autorows)
prop!("grid-template-areas", :gridareas) do v, raw, _, _
  v == "none" && return NO_AREAS
  rows = [String.(split(m[1])) for m in eachmatch(r"[\"']([^\"']*)[\"']", raw)]
  isempty(rows) || any(r -> length(r) != length(rows[1]), rows) ? nothing : rows
end
"Where a thing of a grid starts or ends: a line, `(:span, n)`, a name or :auto"
grid_line(v, raw) = begin
  v == "auto" && return :auto
  ws = split(v)
  if ws[1] == "span"
    n = findfirst(w -> tryparse(Int, w) !== nothing, ws)
    return (:span, n === nothing ? 1 : max(1, Base.parse(Int, ws[n])))
  end
  n = findfirst(w -> tryparse(Int, w) !== nothing, ws)
  n !== nothing && return (x = Base.parse(Int, ws[n]); x == 0 ? nothing : x)
  occursin(r"^[-_a-z0-9]+$"i, strip(raw)) ? String(strip(raw)) : nothing
end
for (i, name) in enumerate(("grid-row-start", "grid-column-start", "grid-row-end", "grid-column-end"))
  prop!((v, raw, _, _) -> grid_line(v, raw), name, :gridplace, i)
end

# --- properties that stand for several ----------------------------------------------------

"One to four values as the four sides: `1px 2px` is the top and bottom, then the right and left"
four(ws) = length(ws) == 1 ? (ws[1], ws[1], ws[1], ws[1]) : length(ws) == 2 ? (ws[1], ws[2], ws[1], ws[2]) :
           length(ws) == 3 ? (ws[1], ws[2], ws[3], ws[2]) : length(ws) == 4 ? (ws[1], ws[2], ws[3], ws[4]) : nothing

"The width, the style and the colour that a `border` value writes, each as it's written, or nothing"
border_parts(v) = begin
  width = style = color = nothing
  for w in terms(v)
    lw = lowercase(w)
    if haskey(LINES, lw) || lw == "auto"
      style === nothing || return nothing
      style = lw
    elseif haskey(THICK, lw) || occursin(r"^[0-9.]", lw) || occursin(r"^(calc|min|max|clamp)\(", lw)
      width === nothing || return nothing
      width = lw
    elseif colour(lw) !== nothing
      color === nothing || return nothing
      color = lw
    else
      return nothing
    end
  end
  (something(width, "medium"), something(style, "none"), something(color, "currentcolor"))
end

"`v` with a space on each side of each `/` that's in no brackets and no quotes: the `/` of an address stays as it is"
slashes(v) = begin
  out = IOBuffer()
  depth = 0
  quoted = '\0'
  for ch in v
    quoted != '\0' ? (ch == quoted && (quoted = '\0')) : ch in ('"', '\'') ? (quoted = ch) : ch == '(' ? (depth += 1) : ch == ')' ? (depth -= 1) : nothing
    ch == '/' && depth <= 0 && quoted == '\0' ? print(out, " / ") : print(out, ch)
  end
  String(take!(out))
end

"What one picture of a `background` value writes: its colour, picture, repeat, place, size, and the boxes that it starts from and is cut to. Each is as it's written, or nothing."
background_layer(value) = begin
  color = image = repeat = size = nothing
  place, boxes = String[], String[]
  ws = terms(slashes(value))
  i = 1
  while i <= length(ws)
    w = ws[i]
    lw = lowercase(w)
    if lw == "/"
      j = i + 1
      while j <= length(ws) && j <= i + 2 && (lowercase(ws[j]) in ("cover", "contain", "auto") || occursin(r"^[0-9.]|^(calc|min|max|clamp)\(", lowercase(ws[j]))) j += 1 end
      size = join(ws[i+1:j-1], " ")
      i = j - 1
    elseif picture(lw)
      image = w
    elseif lw in ("repeat", "no-repeat", "repeat-x", "repeat-y", "space", "round")
      repeat = repeat === nothing ? lw : repeat * " " * lw
    elseif lw in ("left", "right", "top", "bottom", "center") || occursin(r"^-?[0-9.]|^(calc|min|max|clamp)\(", lw)
      push!(place, lw)
    elseif lw in ("border-box", "padding-box", "content-box", "text")
      push!(boxes, lw)
    elseif lw in ("scroll", "fixed", "local", "none")
    elseif colour(lw) !== nothing
      color = lw
    else
      return nothing
    end
    i += 1
  end
  (color, image, repeat, isempty(place) ? nothing : join(place, " "), size, isempty(boxes) ? nothing : boxes[1], isempty(boxes) ? nothing : boxes[end])
end

# The sides that the words of a page that's read from left to right, top to bottom, stand for
const FLOW_SIDES = Dict("block-start" => "top", "block-end" => "bottom", "inline-start" => "left", "inline-end" => "right")
const FLOW_CORNERS = Dict("start-start" => "top-left", "start-end" => "top-right", "end-start" => "bottom-left", "end-end" => "bottom-right")
const FLOW_SIZES = Dict("inline-size" => "width", "block-size" => "height", "min-inline-size" => "min-width", "min-block-size" => "min-height",
                        "max-inline-size" => "max-width", "max-block-size" => "max-height", "overflow-inline" => "overflow", "overflow-block" => "overflow",
                        "grid-row-gap" => "row-gap", "grid-column-gap" => "column-gap", "-webkit-appearance" => "appearance", "-moz-appearance" => "appearance",
                        "-webkit-background-clip" => "background-clip", "-webkit-mask-image" => "mask-image", "text-wrap-mode" => "text-wrap-mode",
                        "-webkit-box-flex" => "flex-grow", "-webkit-text-decoration-color" => "text-decoration-color", "font-stretch" => "font-width")

"The longer names that the property `name` stands for, each with its value, or nothing when it stands for itself"
expand(name, value) = begin
  out = Pair{String,String}[]
  if name in ("margin", "padding", "inset")
    vs = four(terms(value))
    vs === nothing && return out
    for (side, v) in zip(SIDE_NAMES, vs)
      push!(out, (name == "inset" ? side : "$name-$side") => v)
    end
  elseif name in ("border-width", "border-style", "border-color")
    vs = four(terms(value))
    vs === nothing && return out
    kind = name[8:end]
    for (side, v) in zip(SIDE_NAMES, vs)
      push!(out, "border-$side-$kind" => v)
    end
  elseif name == "border" || name in ("border-top", "border-right", "border-bottom", "border-left")
    parts = border_parts(value)
    parts === nothing && return out
    for side in (name == "border" ? SIDE_NAMES : (name[8:end],)), (kind, v) in zip(("width", "style", "color"), parts)
      push!(out, "border-$side-$kind" => v)
    end
    name == "border" && push!(out, "border-image" => "none")
  elseif (m = match(r"^(margin|padding|inset|border)-(inline|block)(?:-(start|end))?(?:-(width|style|color))?$", name)) !== nothing
    # What's said of the start and the end of a line or a block is said of a side
    what, axis, edge, kind = m[1], m[2], m[3], m[4]
    names = edge === nothing ? (axis == "inline" ? ("left", "right") : ("top", "bottom")) : (FLOW_SIDES["$axis-$edge"],)
    full(side) = what == "inset" ? side : kind === nothing ? "$what-$side" : "$what-$side-$kind"
    if what == "border" && kind === nothing
      foreach(side -> push!(out, "border-$side" => value), names)
    else
      ws = terms(value)
      (isempty(ws) || length(ws) > length(names)) && return out
      for (i, side) in enumerate(names)
        push!(out, full(side) => ws[min(i, length(ws))])
      end
    end
  elseif name in ("border-radius", "-webkit-border-radius", "-moz-border-radius")
    halves = split(value, '/')
    hs = four(terms(halves[1]))
    vs = length(halves) > 1 ? four(terms(halves[2])) : hs
    (hs === nothing || vs === nothing) && return out
    for (corner, h, v) in zip(("top-left", "top-right", "bottom-right", "bottom-left"), hs, vs)
      push!(out, "border-$corner-radius-x" => h, "border-$corner-radius-y" => v)
    end
  elseif (m = match(r"^border-(top-left|top-right|bottom-right|bottom-left|start-start|start-end|end-start|end-end)-radius$", name)) !== nothing
    corner = get(FLOW_CORNERS, m[1], m[1])
    ws = terms(value)
    isempty(ws) && return out
    push!(out, "border-$corner-radius-x" => ws[1], "border-$corner-radius-y" => ws[end])
  elseif name == "outline"
    parts = border_parts(value)
    parts === nothing && return out
    push!(out, "outline-width" => parts[1], "outline-style" => parts[2], "outline-color" => parts[3])
  elseif name == "column-rule"
    parts = border_parts(value)
    parts === nothing && return out
    push!(out, "column-rule-width" => parts[1], "column-rule-style" => parts[2], "column-rule-color" => parts[3])
  elseif name == "columns"
    push!(out, "column-count" => "auto", "column-width" => "auto")
    for w in terms(value)
      lowercase(w) == "auto" || push!(out, (occursin(r"^[0-9]+$", w) ? "column-count" : "column-width") => w)
    end
  elseif name == "background"
    layers = [background_layer(p) for p in pieces(value, ',')]
    (isempty(layers) || any(isnothing, layers)) && return out
    col(i, default) = join((something(l[i], default) for l in layers), ", ")
    push!(out, "background-color" => something(layers[end][1], "transparent"), "background-image" => col(2, "none"), "background-repeat" => col(3, "repeat"),
          "background-position" => col(4, "0% 0%"), "background-size" => col(5, "auto"), "background-origin" => col(6, "padding-box"),
          "background-clip" => col(7, "border-box"))
  elseif name == "font"
    lv = lowercase(strip(value))
    if lv in ("caption", "icon", "menu", "message-box", "small-caption", "status-bar")
      push!(out, "font-style" => "normal", "font-weight" => "normal", "font-size" => "13px", "line-height" => "normal", "font-family" => "system-ui")
      return out
    end
    ws = terms(value)
    i = 1
    style, weight, caps, width = "normal", "normal", "normal", "normal"
    while i <= length(ws) && !occursin(r"^[0-9.]|^(calc|min|max|clamp|var)\(", lowercase(ws[i])) && !haskey(SIZES, lowercase(ws[i])) && !(lowercase(ws[i]) in ("smaller", "larger"))
      w = lowercase(ws[i])
      w in ("italic", "oblique") ? (style = w) : w in ("bold", "bolder", "lighter") ? (weight = w) : w == "small-caps" ? (caps = w) :
      haskey(STRETCHES, w) ? (width = w) : nothing
      i += 1
    end
    # A weight like 600 looks like a size: it's a weight when a size comes after it
    if i < length(ws) && occursin(r"^[1-9]\d{0,2}$", ws[i]) && (occursin(r"^[0-9.]|^(calc|min|max|clamp)\(", lowercase(ws[i+1])) || haskey(SIZES, lowercase(ws[i+1])))
      weight = ws[i]
      i += 1
    end
    i < length(ws) || return out   # a size and a family are both needed
    size = split(ws[i], '/')
    height = length(size) > 1 ? size[2] : "normal"
    # The line height can stand apart: `12px / 1.5`
    i + 2 <= length(ws) && ws[i+1] == "/" && ((height, i) = (ws[i+2], i + 2))
    push!(out, "font-style" => style, "font-weight" => weight, "font-variant-caps" => caps, "font-width" => width, "font-size" => size[1], "line-height" => height,
          "font-family" => join(ws[i+1:end], " "))
  elseif name == "list-style"
    for w in terms(value)
      lw = lowercase(w)
      lw in ("inside", "outside") ? push!(out, "list-style-position" => lw) : startswith(lw, "url(") ? push!(out, "list-style-image" => w) :
      lw == "none" ? push!(out, "list-style-type" => "none", "list-style-image" => "none") : push!(out, "list-style-type" => w)
    end
  elseif name in ("text-decoration", "-webkit-text-decoration")
    lines = String[]
    push!(out, "text-decoration-style" => "solid", "text-decoration-color" => "currentcolor", "text-decoration-thickness" => "auto")
    for w in terms(value)
      lw = lowercase(w)
      lw in ("none", "underline", "line-through", "overline", "blink") ? push!(lines, lw) :
      lw in ("solid", "double", "dotted", "dashed", "wavy") ? push!(out, "text-decoration-style" => lw) :
      lw in ("auto", "from-font") || occursin(r"^[0-9.]", lw) ? push!(out, "text-decoration-thickness" => lw) :
      colour(lw) !== nothing ? push!(out, "text-decoration-color" => lw) : nothing
    end
    isempty(lines) || push!(out, "text-decoration-line" => join(lines, " "))
  elseif name == "flex"
    ws = terms(lowercase(value))
    grow, shrink, basis = "1", "1", "0%"
    if ws == ["none"]
      grow, shrink, basis = "0", "0", "auto"
    elseif ws == ["auto"]
      basis = "auto"
    elseif ws == ["initial"]
      grow, basis = "0", "auto"
    else
      nums = [w for w in ws if tryparse(Float64, w) !== nothing]
      rest = [w for w in ws if tryparse(Float64, w) === nothing]
      (length(rest) > 1 || length(nums) > 3 || isempty(ws)) && return out
      length(nums) >= 1 && (grow = nums[1])
      length(nums) >= 2 && (shrink = nums[2])
      # A third number is a basis with no unit, which only 0 can be
      length(nums) == 3 && (basis = nums[3] * "px")
      isempty(rest) || (basis = rest[1])
    end
    push!(out, "flex-grow" => grow, "flex-shrink" => shrink, "flex-basis" => basis)
  elseif name == "flex-flow"
    for w in terms(lowercase(value))
      push!(out, (w in ("nowrap", "wrap", "wrap-reverse") ? "flex-wrap" : "flex-direction") => w)
    end
  elseif name in ("gap", "grid-gap")
    ws = terms(value)
    length(ws) in (1, 2) || return out
    push!(out, "row-gap" => ws[1], "column-gap" => ws[end])
  elseif name in ("place-content", "place-items", "place-self")
    ws = terms(replace(lowercase(value), r"\b(first|last|safe|unsafe)\s+" => ""))
    length(ws) in (1, 2) || return out
    kind = name[7:end]
    push!(out, "align-$kind" => ws[1], "justify-$kind" => ws[end])
  elseif name in ("grid-row", "grid-column")
    parts = [strip(p) for p in split(value, '/')]
    length(parts) in (1, 2) || return out
    # With one name, the thing ends where the area of that name ends
    stop = length(parts) == 2 ? parts[2] : occursin(r"^[-_a-z]+$"i, parts[1]) && !(lowercase(parts[1]) in ("auto", "span")) ? parts[1] : "auto"
    push!(out, "$name-start" => parts[1], "$name-end" => stop)
  elseif name == "grid-area"
    parts = [String(strip(p)) for p in split(value, '/')]
    length(parts) in 1:4 || return out
    named(p) = occursin(r"^[-_a-z]+$"i, p) && !(lowercase(p) in ("auto", "span"))
    col = length(parts) >= 2 ? parts[2] : named(parts[1]) ? parts[1] : "auto"
    rowend = length(parts) >= 3 ? parts[3] : named(parts[1]) ? parts[1] : "auto"
    colend = length(parts) == 4 ? parts[4] : named(col) ? col : "auto"
    push!(out, "grid-row-start" => parts[1], "grid-column-start" => col, "grid-row-end" => rowend, "grid-column-end" => colend)
  elseif name in ("grid-template", "grid")
    lv = lowercase(strip(value))
    if lv == "none"
      push!(out, "grid-template-rows" => "none", "grid-template-columns" => "none", "grid-template-areas" => "none")
    elseif occursin('"', value) || occursin('\'', value)
      # Each row is its areas in quotes, with how tall it is after them. The columns come after a `/`.
      halves = pieces(value, '/')
      rows, areas = String[], String[]
      for w in terms(halves[1])
        if startswith(w, '"') || startswith(w, '\'')
          length(areas) > length(rows) && push!(rows, "auto")
          push!(areas, w)
        elseif !startswith(w, '[')
          push!(rows, w)
        end
      end
      length(areas) > length(rows) && push!(rows, "auto")
      push!(out, "grid-template-areas" => join(areas, " "), "grid-template-rows" => join(rows, " "))
      length(halves) > 1 && push!(out, "grid-template-columns" => String(strip(halves[2])))
    else
      halves = [String(strip(p)) for p in pieces(value, '/')]
      length(halves) == 2 || return out
      flow(h) = occursin(r"\bauto-flow\b", lowercase(h))
      tracks(h) = String(strip(replace(h, r"\b(auto-flow|dense)\b"i => "")))
      if flow(halves[1])
        push!(out, "grid-auto-flow" => (occursin("dense", lowercase(halves[1])) ? "row dense" : "row"), "grid-template-columns" => halves[2])
        isempty(tracks(halves[1])) || push!(out, "grid-auto-rows" => tracks(halves[1]))
      elseif flow(halves[2])
        push!(out, "grid-auto-flow" => (occursin("dense", lowercase(halves[2])) ? "column dense" : "column"), "grid-template-rows" => halves[1])
        isempty(tracks(halves[2])) || push!(out, "grid-auto-columns" => tracks(halves[2]))
      else
        push!(out, "grid-template-rows" => halves[1], "grid-template-columns" => halves[2])
      end
    end
  elseif name in ("mask", "-webkit-mask")
    found = [w for w in terms(pieces(value, ',')[1]) if picture(lowercase(w))]
    push!(out, "mask-image" => (isempty(found) ? "none" : found[1]))
  elseif name == "container"
    parts = [strip(p) for p in split(value, '/')]
    push!(out, "container-name" => parts[1])
    length(parts) > 1 && push!(out, "container-type" => parts[2])
  elseif name == "-webkit-text-stroke"
    for w in terms(value)
      push!(out, (colour(lowercase(w)) !== nothing ? "-webkit-text-stroke-color" : "-webkit-text-stroke-width") => w)
    end
  elseif name == "text-wrap"
    # What the shorthand leaves out goes back to its first value, so `text-wrap: wrap` ends `pretty`
    v = lowercase(strip(value))
    if v in ("inherit", "initial", "unset", "revert", "revert-layer")
      push!(out, "text-wrap-mode" => v, "text-wrap-style" => v)
    else
      mode, how = "wrap", "auto"
      for w in terms(v)
        w in ("wrap", "nowrap") ? (mode = w) : (how = w)
      end
      push!(out, "text-wrap-mode" => mode, "text-wrap-style" => how)
    end
  elseif name == "-webkit-box-orient"
    push!(out, "flex-direction" => (lowercase(strip(value)) == "vertical" ? "column" : "row"))
  elseif name == "-webkit-box-pack"
    v = lowercase(strip(value))
    push!(out, "justify-content" => (v == "justify" ? "space-between" : v == "end" ? "flex-end" : v == "center" ? "center" : "flex-start"))
  elseif name == "-webkit-box-align"
    v = lowercase(strip(value))
    push!(out, "align-items" => (v == "end" ? "flex-end" : v == "start" ? "flex-start" : v in ("center", "baseline", "stretch") ? v : "stretch"))
  elseif haskey(FLOW_SIZES, name) && FLOW_SIZES[name] != name
    push!(out, FLOW_SIZES[name] => value)
  elseif name in ("-webkit-box-sizing", "-moz-box-sizing")
    push!(out, "box-sizing" => value)
  elseif name in ("-webkit-box-shadow", "-moz-box-shadow")
    push!(out, "box-shadow" => value)
  else
    return nothing
  end
  out
end

# How an SVG shape is drawn. A style keeps these with its variables: a child has its parent's.
const SHAPE = Set(["fill", "fill-opacity", "fill-rule", "stroke", "stroke-width", "stroke-linecap", "stroke-linejoin", "stroke-miterlimit", "stroke-dasharray",
                   "stroke-dashoffset", "stroke-opacity", "stop-color", "stop-opacity", "clip-rule", "text-anchor", "dominant-baseline", "alignment-baseline",
                   "paint-order", "vector-effect", "shape-rendering", "marker-start", "marker-mid", "marker-end", "flood-color", "flood-opacity"])

# What's understood and changes nothing in a page that's drawn once: no mouse, no time, no printer
const UNUSED = Set(["cursor", "pointer-events", "user-select", "resize", "caret-color", "touch-action", "will-change", "transition", "transition-property",
                    "transition-duration", "transition-timing-function", "transition-delay", "transition-behavior", "animation", "animation-name",
                    "animation-duration", "animation-timing-function", "animation-delay", "animation-iteration-count", "animation-direction",
                    "animation-fill-mode", "animation-play-state", "animation-composition", "animation-timeline", "scroll-behavior", "scroll-snap-type",
                    "scroll-snap-align", "scroll-snap-stop", "scroll-margin", "scroll-margin-top", "scroll-padding", "scroll-padding-top", "scrollbar-width",
                    "scrollbar-color", "scrollbar-gutter", "overscroll-behavior", "overscroll-behavior-x", "overscroll-behavior-y", "contain",
                    "content-visibility", "contain-intrinsic-size", "backface-visibility", "perspective", "perspective-origin", "transform-style",
                    "transform-box", "font-kerning", "font-feature-settings", "font-variation-settings", "font-optical-sizing", "font-synthesis",
                    "font-display", "font-size-adjust", "font-variant-numeric", "font-variant-ligatures", "font-variant-east-asian",
                    "font-variant-alternates", "font-variant-position", "font-palette", "font-language-override", "text-rendering", "-webkit-font-smoothing",
                    "-moz-osx-font-smoothing", "text-size-adjust", "-webkit-tap-highlight-color", "-webkit-touch-callout", "hyphens", "hyphenate-character",
                    "orphans", "widows", "page-break-before", "page-break-after", "page-break-inside", "break-before", "break-after", "break-inside",
                    "unicode-bidi", "writing-mode", "text-orientation", "text-underline-position", "text-decoration-skip-ink", "text-decoration-skip",
                    "hanging-punctuation", "color-scheme", "forced-color-adjust", "print-color-adjust", "-webkit-print-color-adjust",
                    "background-attachment", "background-blend-mode", "backdrop-filter", "mask-size", "mask-position", "mask-repeat", "mask-mode",
                    "mask-type", "mask-clip", "mask-origin", "mask-composite", "shape-outside", "shape-margin", "shape-image-threshold", "zoom",
                    "box-decoration-break", "math-style", "math-depth", "view-transition-name", "anchor-name", "position-anchor", "position-area",
                    "field-sizing", "interpolate-size", "overflow-anchor", "overflow-clip-margin", "text-emphasis", "text-emphasis-style",
                    "text-emphasis-color", "text-emphasis-position", "ruby-position", "ruby-align", "column-fill", "column-span", "border-image-slice",
                    "border-image-width", "border-image-outset", "border-image-repeat", "image-orientation", "speak", "speak-as", "timeline-scope",
                    "view-timeline", "scroll-timeline", "offset", "offset-path", "offset-distance", "offset-rotate", "text-justify", "text-combine-upright",
                    "initial-letter", "line-height-step", "block-ellipsis", "text-box", "text-box-trim", "text-box-edge", "text-spacing-trim", "text-autospace",
                    "white-space-trim", "counter-style", "user-drag", "app-region", "all"])

"True when `name: value` is a declaration that's understood: what an @supports asks"
known(name, value) = begin
  startswith(name, "--") && return true
  p = get(PROPS, name, nothing)
  if p !== nothing
    v = lowercase(strip(value))
    return v in ("inherit", "initial", "unset", "revert", "revert-layer") || occursin("var(", v) || try p.read(v, value, PLAIN, DEFAULT) !== nothing catch; false end
  end
  longer = expand(name, value)
  longer !== nothing && return !isempty(longer) && all(((n, v),) -> n == name || known(n, v), longer)
  (name in SHAPE || name in UNUSED) && return true
  m = match(r"^-(?:webkit|moz|ms|o)-(.+)$", name)
  m !== nothing && known(m[1], value)
end

get_side(s::Style, p::Prop) = p.side == 0 ? p.get(s) : p.get(s)[p.side]
set_side!(s::Style, p::Prop, v) = (p.side == 0 ? p.set(s, v) : p.set(s, Base.setindex(p.get(s), v, p.side)); nothing)

"""
`value` with each `var(--x)` as what the variable holds, and each `env(...)`
as nothing: no screen of a page that's drawn has a part cut off. `vars(name)`
gives the value of a variable, or nothing. It's nothing when a variable that
it needs has no value and no stand-in.
"""
substitute(value::AbstractString, vars::Function, depth=0) = begin
  depth > 32 && return nothing
  out = String(value)
  while true
    m = match(r"\b(var|env)\(", out)
    m === nothing && return out
    open = m.offset + ncodeunits(m.match) - 1
    stop = closing(out, open, '(', ')')
    stop > lastindex(out) && return nothing
    inside = SubString(out, open + 1, prevind(out, stop))
    comma = nothing
    level = 0
    for (i, ch) in pairs(inside)
      ch == '(' ? (level += 1) : ch == ')' ? (level -= 1) : nothing
      ch == ',' && level == 0 && (comma = i; break)
    end
    name = strip(comma === nothing ? inside : SubString(inside, firstindex(inside), prevind(inside, comma)))
    spare = comma === nothing ? nothing : strip(SubString(inside, nextind(inside, comma)))
    found = m[1] == "var" ? vars(String(name)) : nothing
    with = found !== nothing ? substitute(found, vars, depth + 1) : spare !== nothing ? substitute(spare, vars, depth + 1) : m[1] == "env" ? "0px" : nothing
    with === nothing && return nothing
    out = out[1:prevind(out, m.offset)] * with * out[nextind(out, stop):end]
  end
end

"Give the style `s` what `name: value` declares. A value that the property can't take changes nothing."
set!(s::Style, name::AbstractString, value::AbstractString, c::Context, parent::Style) = begin
  startswith(name, "--") && return nothing
  if occursin("var(", value) || occursin("env(", value)
    vars = s.vars
    value = substitute(value, n -> get(vars, n, nothing))
    value === nothing && return nothing
  end
  if name == "list-style-type" && occursin(r"^\s*[\"']", value)
    # The words that stand for the bullet
    s.listtype, s.listtext = :text, String(strip(strip(value), ['"', '\'']))
    return nothing
  end
  p = get(PROPS, name, nothing)
  if p === nothing
    if name == "all"
      # Every property starts again, but the variables stay
      v = lowercase(strip(value))
      v in ("initial", "unset", "inherit") || return nothing
      from = v == "initial" ? DEFAULT : v == "unset" ? child(parent) : parent
      for f in fieldnames(Style)
        f in (:vars, :direction) || setfield!(s, f, getfield(from, f))
      end
      return nothing
    elseif name in ("overflow-x", "overflow-y")
      # What's cut off across or down is cut off: the other way then scrolls, which is cut off too
      v = lowercase(strip(value))
      v in ("hidden", "clip", "scroll", "auto", "overlay") ? (s.overflow = :hidden) : v == "inherit" ? (s.overflow = parent.overflow) : nothing
      return nothing
    elseif name == "text-wrap-mode"
      v = lowercase(strip(value))
      s.whitespace = v == "nowrap" ? (s.whitespace in (:pre, :pre_wrap) ? :pre : :nowrap) : v == "wrap" ? (s.whitespace == :nowrap ? :normal : s.whitespace == :pre ? :pre_wrap : s.whitespace) : s.whitespace
      return nothing
    elseif name in ("background-position-x", "background-position-y")
      l = (w = lowercase(strip(first(pieces(value, ','))))) in ("left", "top") ? ZERO : w in ("right", "bottom") ? percent(1) : w == "center" ? percent(0.5) : len(w, c)
      (l === nothing || l.auto) && return nothing
      s.bgposition = [name[end] == 'x' ? (l, at[2]) : (at[1], l) for at in s.bgposition]
      return nothing
    end
    longer = expand(name, value)
    if longer === nothing
      if name in SHAPE
        s.vars === parent.vars && (s.vars = copy(s.vars))
        lowercase(strip(value)) == "inherit" ? (haskey(parent.vars, name) ? (s.vars[name] = parent.vars[name]) : delete!(s.vars, name)) : (s.vars[name] = String(strip(value)))
        return nothing
      end
      # A name with a browser's own start, like -webkit-transform, is the name without it
      m = match(r"^-(?:webkit|moz|ms|o)-(.+)$", name)
      m === nothing || set!(s, m[1], value, c, parent)
      return nothing
    end
    for (n, v) in longer
      set!(s, n, v, c, parent)
    end
    return nothing
  end
  v = lowercase(strip(value))
  # The words that every property takes all start with one of three letters
  wide = !isempty(v) && v[1] in ('i', 'u', 'r')
  got = wide && v == "inherit" ? get_side(parent, p) :
        wide && v in ("initial", "unset", "revert", "revert-layer") ? get_side(p.field in INHERITED && v != "initial" ? parent : DEFAULT, p) : p.read(v, value, c, parent)
  got === nothing || set_side!(s, p, got)
  nothing
end

# Turn the ems of the plain lengths of a style into px: written out field by field, which is quicker than a loop over the names
@eval flatten!(s::Style, size) = begin
  $((:(s.$f = flat(s.$f, size)) for f in (:width, :height, :minwidth, :minheight, :maxwidth, :maxheight, :indent, :letterspacing, :wordspacing, :basis, :outline,
                                          :outlineoffset, :colwidth, :colrule, :decothick, :underoffset, :stroke))...)
  $((:(s.$f = map(l -> flat(l, size), s.$f)) for f in (:margin, :padding, :border, :radius, :radiusv, :inset))...)
  nothing
end

const BLOCKS = Dict(:inline => :block, :inline_block => :block, :table_cell => :block, :table_row => :block, :table_row_group => :block,
                    :table_header_group => :block, :table_footer_group => :block, :table_caption => :block, :table_column => :block,
                    :table_column_group => :block, :inline_table => :table, :inline_flex => :flex, :inline_grid => :grid)

"Turn the ems of the lengths of `s` into px, now that its font size is known, and work out what follows from its other values"
settle!(s::Style, parent::Style, tag="") = begin
  # A table takes no centring from a tag's `align` round it: what's in it starts at the left again
  tag == "table" && s.align in (:wk_left, :wk_center, :wk_right) && (s.align = :start)
  size = s.size
  f(l::Len) = flat(l, size)
  flatten!(s, size)
  s.gap = map(f, s.gap)
  s.origin = map(f, s.origin)
  s.objectat = map(f, s.objectat)
  s.bgposition === ONE_PLACE || (s.bgposition = [map(f, at) for at in s.bgposition])
  s.bgsize === ONE_SIZE || (s.bgsize = Any[x isa Tuple ? map(f, x) : x for x in s.bgsize])
  s.valign = (s.valign[1], f(s.valign[2]))
  s.lineheight[1] == :em && (s.lineheight = (:px, s.lineheight[2] * size))
  for name in (:transform, :translate)
    ts = getfield(s, name)
    isempty(ts) || any(t -> t.x.em != 0 || t.y.em != 0, ts) && setfield!(s, name, [Turn(t.kind, f(t.x), f(t.y), t.n) for t in ts])
  end
  fs(x::Size) = x.len.em == 0 ? x : Size(x.kind, f(x.len), x.fr)
  ft(ts) = isempty(ts) ? ts : [Track(fs(t.min), fs(t.max)) for t in ts]
  for name in (:gridcols, :gridrows)
    t = getfield(s, name)
    t === NO_TEMPLATE || setfield!(s, name, Template(ft(t.tracks), ft(t.again), ft(t.after), t.fit, t.names))
  end
  s.autocols = ft(s.autocols)
  s.autorows = ft(s.autorows)
  # The colours that are the text's own
  s.bordercolor = map(c -> c === :current ? s.color : c, s.bordercolor)
  s.background == CURRENT && (s.background = s.color)
  s.outlinecolor == CURRENT && (s.outlinecolor = s.color)
  s.colrulecolor == CURRENT && (s.colrulecolor = s.color)
  # The old kind of flex box. One that cuts its text off after some lines is a plain block.
  s.display == :old_box && (s.display = s.lineclamp > 0 ? :block : :flex)
  # A float and an element with a place of its own are blocks, and so is a thing in a flex box or a grid
  inside = parent.display in (:flex, :inline_flex, :grid, :inline_grid)
  if s.display != :none && (s.float != :none || s.position in (:absolute, :fixed) || inside)
    (s.position in (:absolute, :fixed) || inside) && (s.float = :none)
    s.display = get(BLOCKS, s.display, s.display)
  end
  # The lines under and through text go on through the text of what's in the element, but not into a box of its own
  apart = s.display in (:inline_block, :inline_table, :inline_flex, :inline_grid) || s.float != :none || s.position in (:absolute, :fixed)
  s.lines = (apart ? 0x00 : parent.lines) | s.decoration
  if s.decoration != 0
    s.linecolor = s.decocolor == CURRENT ? s.color : s.decocolor
    s.linestyle = s.decostyle
    s.linethick = isauto(s.decothick) ? 0.0 : px(s.decothick, size)
  end
  s
end

# --- what a browser gives each tag --------------------------------------------------------

const BROWSER = sheet("""
html, body, div, p, h1, h2, h3, h4, h5, h6, address, blockquote, center, dl, dt, dd, ol, ul, menu, dir, pre, listing, xmp, plaintext, hr, form,
fieldset, legend, article, aside, footer, header, main, nav, section, figure, figcaption, details, summary, hgroup, optgroup, search { display: block }
head, meta, title, link, style, script, base, template, area, param, datalist, noembed, noframes, map, source, track, rp, dialog:not([open]),
audio:not([controls]), input[type=hidden], [popover], [hidden] { display: none }
html { color: canvastext }
body { margin: 8px }
p, dl { margin: 1em 0 }
blockquote, figure { margin: 1em 40px }
h1 { font-size: 2em; margin: 0.67em 0; font-weight: bold }
h2 { font-size: 1.5em; margin: 0.83em 0; font-weight: bold }
h3 { font-size: 1.17em; margin: 1em 0; font-weight: bold }
h4 { margin: 1.33em 0; font-weight: bold }
h5 { font-size: 0.83em; margin: 1.67em 0; font-weight: bold }
h6 { font-size: 0.67em; margin: 2.33em 0; font-weight: bold }
b, strong, th { font-weight: bold }
i, em, cite, var, address, dfn { font-style: italic }
u, ins { text-decoration: underline }
s, strike, del { text-decoration: line-through }
abbr[title], acronym[title] { text-decoration: underline dotted }
a:any-link { color: -webkit-link; text-decoration: underline }
big { font-size: larger }
small { font-size: smaller }
sub { vertical-align: sub; font-size: smaller }
sup { vertical-align: super; font-size: smaller }
pre, listing, xmp, plaintext { white-space: pre; margin: 1em 0; font-family: monospace; font-size: 13px }
code, kbd, samp, tt { font-family: monospace; font-size: 0.8125em }
pre code, pre kbd, pre samp, pre tt { font-size: 1em }
center { text-align: -webkit-center }
hr { border: 1px inset gray; margin: 0.5em auto; overflow: hidden }
ul, menu, dir { list-style-type: disc; margin: 1em 0; padding-left: 40px }
ol { list-style-type: decimal; margin: 1em 0; padding-left: 40px }
li { display: list-item }
ul ul, ol ul { list-style-type: circle }
ul ul ul, ul ol ul, ol ul ul, ol ol ul { list-style-type: square }
ul ul, ul ol, ol ul, ol ol { margin-top: 0; margin-bottom: 0 }
dd { margin-left: 40px }
table { display: table; border-collapse: separate; border-spacing: 2px; border-color: gray; box-sizing: border-box; text-indent: 0 }
thead { display: table-header-group; vertical-align: middle; border-color: inherit }
tbody { display: table-row-group; vertical-align: middle; border-color: inherit }
tfoot { display: table-footer-group; vertical-align: middle; border-color: inherit }
tr { display: table-row; vertical-align: inherit; border-color: inherit }
td, th { display: table-cell; vertical-align: inherit; padding: 1px }
th { text-align: center }
caption { display: table-caption; text-align: center }
col { display: table-column }
colgroup { display: table-column-group }
img, input, button, select, textarea, svg, video, canvas, iframe, object, embed, audio, progress, meter, marquee { display: inline-block }
button, input[type=submit], input[type=button], input[type=reset] { padding: 2px 8px 3px; border: 0 solid #c8c8c8; border-radius: 5px; background-color: light-dark(#e9e9eb, #2f2f2f);
  color: light-dark(buttontext, #dfdfdf); font: 11px system-ui; text-align: center; white-space: pre; text-indent: 0; letter-spacing: normal; text-transform: none; box-sizing: border-box }
input { padding: 3px 6px; border: 1px solid #c8c8c8; border-radius: 5px; font: 11px system-ui; width: 141px; background-color: light-dark(field, #1e1e1e); color: light-dark(fieldtext, #fff); white-space: pre;
  overflow: hidden; text-indent: 0; letter-spacing: normal; text-transform: none; text-align: start }
input[type=submit], input[type=button], input[type=reset], input[type=image] { width: auto; overflow: visible }
input[type=checkbox], input[type=radio] { width: 12px; height: 12px; margin: 3px 3px 3px 4px; padding: 0; border: 0; background: none; box-sizing: border-box }
input[type=range] { width: 129px; height: 16px; margin: 2px; padding: 0; border: 0; background: none }
input[type=color] { width: 44px; height: 23px; padding: 1px 2px; box-sizing: border-box }
input[type=file] { border: 0; padding: 0; background: none; width: 238px }
input[type=image] { border: 0; padding: 0; background: none }
textarea { padding: 2px; border: 1px solid #c8c8c8; border-radius: 5px; font: 11px monospace; background-color: light-dark(field, #1e1e1e); color: light-dark(fieldtext, #fff); white-space: pre-wrap;
  overflow-wrap: break-word; overflow: hidden; text-indent: 0; letter-spacing: normal; text-transform: none; text-align: start; vertical-align: text-bottom }
select { padding: 3px 26px 4px 12px; border: 0 solid #c8c8c8; border-radius: 5px; font: 11px system-ui; background-color: light-dark(#e9e9eb, #2f2f2f); color: light-dark(fieldtext, #dfdfdf); white-space: pre;
  overflow: hidden; text-indent: 0; letter-spacing: normal; text-transform: none; text-align: start; box-sizing: border-box; line-height: 13px }
select[multiple], select[size] { padding: 2px; border-width: 1px; background-color: light-dark(field, #1e1e1e); white-space: pre }
fieldset { border: 2px groove gray; margin: 0 2px; padding: 0.35em 0.75em 0.625em; min-width: min-content }
legend { padding: 0 2px; width: fit-content }
mark { background-color: yellow; color: black }
nobr { white-space: nowrap }
svg { overflow: hidden }
iframe { border: 2px inset gray }
progress { width: 10em }
meter { width: 5em }
progress, meter { height: 1em; vertical-align: -0.2em; box-sizing: border-box }
details > summary { display: list-item; list-style: disclosure-closed inside }
details[open] > summary { list-style-type: disclosure-open }
details:not([open]) > :not(summary) { display: none }
dialog { position: absolute; left: 0; right: 0; width: fit-content; height: fit-content; margin: auto; border: 3px solid; padding: 1em; background-color: canvas; color: canvastext }
slot { display: contents }
q::before { content: open-quote }
q::after { content: close-quote }
ruby { display: inline-flex; flex-direction: column-reverse; align-items: center; text-indent: 0; line-height: 1 }
rt { display: block; font-size: 50%; line-height: 1; text-align: center; white-space: nowrap }
bdo[dir=rtl] { direction: rtl }
math { display: inline-block; font-family: math, serif; white-space: nowrap; text-indent: 0; letter-spacing: normal; line-height: normal }
mi { font-style: italic }
mfrac { display: inline-flex; flex-direction: column; align-items: center; vertical-align: middle; padding: 0 2px }
mfrac > :first-child { border-bottom: 1px solid; padding: 0 2px }
msup > :nth-child(2), msubsup > :nth-child(3), mover > :nth-child(2) { vertical-align: super; font-size: 70% }
msub > :nth-child(2), msubsup > :nth-child(2), munder > :nth-child(2) { vertical-align: sub; font-size: 70% }
msqrt::before { content: "√" }
msqrt { border-top: 1px solid }
mtable { display: inline-table; vertical-align: middle }
mtr { display: table-row }
mtd { display: table-cell; padding: 0.2em 0.4em; text-align: center }
annotation, annotation-xml { display: none }
""")

# In a page with no doctype, a table doesn't take its text's size and weight from what it's in
const QUIRKS = sheet("table { font-size: medium; font-weight: normal; font-style: normal; white-space: normal; line-height: normal; text-align: start }")

# The tags whose margins a page with no doctype drops at the top of the page and at the edges of a cell
const LOOSE = Set(["p", "blockquote", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "menu", "dir", "dl", "pre", "listing", "plaintext", "xmp"])

# --- what a tag says about its looks ------------------------------------------------------

const FONT_SIZES = ("x-small", "small", "medium", "large", "x-large", "xx-large", "xxx-large")
const ALIGNS = Dict("left" => "-webkit-left", "right" => "-webkit-right", "center" => "-webkit-center", "middle" => "-webkit-center", "justify" => "justify")

"The length that a tag writes like `width=600` or `width=\"50%\"`, as CSS writes it, or nothing"
measure(v; zero=true) = begin
  m = match(r"^\s*([0-9]*\.?[0-9]+)\s*(%)?", v)
  m === nothing && return nothing
  !zero && Base.parse(Float64, m[1]) == 0 && return nothing
  m[1] * (m[2] === nothing ? "px" : "%")
end

"The table that the cell or the row `e` is in"
table_of(e::Element) = begin
  p = e.parent
  while p !== nothing && p.tag != "table"
    p = p.parent
  end
  p
end

"How thick the `border` of a table's tag says its border is, in px. A border with no number is 1 px."
border_attr(table::Element) = begin
  haskey(table.attrs, "border") || return 0.0
  m = match(r"^\s*([0-9]*\.?[0-9]+)", table.attrs["border"])
  m === nothing ? 1.0 : Base.parse(Float64, m[1])
end

"The address in a tag's `background`, as CSS writes a picture"
url(v) = "url(\"" * replace(strip(v), '"' => "%22") * "\")"

# The tags of an SVG drawing. What one says of how it's drawn (`fill="red"`) is a style that any CSS wins over.
const SVG_TAGS = Set(["svg", "g", "path", "rect", "circle", "ellipse", "line", "polyline", "polygon", "text", "tspan", "textpath", "use", "defs", "symbol",
                      "lineargradient", "radialgradient", "stop", "clippath", "mask", "pattern", "image", "marker", "switch", "foreignobject"])
const SVG_LOOKS = ("opacity", "display", "visibility", "color", "font-size", "font-family", "font-weight", "font-style", "letter-spacing", "word-spacing",
                   "text-decoration", "clip-path", "mask", "filter")

"What the tag of `e` says about how it looks, as declarations, which any CSS for the element wins over"
hints(e::Element) = begin
  out = Pair{String,String}[]
  a(name) = strip(get(e.attrs, name, ""))
  has(name) = haskey(e.attrs, name)
  say(name, v) = v === nothing || isempty(v) || push!(out, name => v)
  tag = e.tag
  has("dir") && lowercase(a("dir")) in ("ltr", "rtl") && say("direction", lowercase(a("dir")))
  if tag == "body"
    say("background-color", a("bgcolor"))
    say("color", a("text"))
    has("background") && !isempty(a("background")) && say("background-image", url(a("background")))
    for (attr, sides) in (("marginwidth", ("left", "right")), ("leftmargin", ("left",)), ("rightmargin", ("right",)),
                          ("marginheight", ("top", "bottom")), ("topmargin", ("top",)), ("bottommargin", ("bottom",)))
      has(attr) && foreach(side -> say("margin-$side", measure(a(attr))), sides)
    end
  elseif tag == "table"
    say("width", measure(a("width"); zero=false))
    say("height", measure(a("height")))
    say("background-color", a("bgcolor"))
    has("background") && !isempty(a("background")) && say("background-image", url(a("background")))
    if has("border")
      n = border_attr(e)
      say("border-width", "$(n)px")
      say("border-style", n > 0 ? "outset" : "none")
    end
    say("border-color", a("bordercolor"))
    has("cellspacing") && say("border-spacing", measure(a("cellspacing")))
    align = lowercase(a("align"))
    align in ("left", "right") && say("float", align)
    align == "center" && (say("margin-left", "auto"); say("margin-right", "auto"))
    has("hspace") && (say("margin-left", measure(a("hspace"))); say("margin-right", measure(a("hspace"))))
    has("vspace") && (say("margin-top", measure(a("vspace"))); say("margin-bottom", measure(a("vspace"))))
  elseif tag in ("td", "th")
    say("width", measure(a("width"); zero=false))
    say("height", measure(a("height"); zero=false))
    say("background-color", a("bgcolor"))
    has("background") && !isempty(a("background")) && say("background-image", url(a("background")))
    haskey(ALIGNS, lowercase(a("align"))) && say("text-align", ALIGNS[lowercase(a("align"))])
    lowercase(a("valign")) in ("top", "middle", "bottom", "baseline") && say("vertical-align", lowercase(a("valign")))
    has("nowrap") && say("white-space", "nowrap")
    table = table_of(e)
    if table !== nothing
      haskey(table.attrs, "cellpadding") && say("padding", measure(table.attrs["cellpadding"]))
      # A table with a border draws a line round each of its cells
      if border_attr(table) > 0
        say("border-width", "1px")
        say("border-style", "inset")
        say("border-color", get(table.attrs, "bordercolor", "gray"))
      end
    end
  elseif tag in ("tr", "thead", "tbody", "tfoot")
    say("background-color", a("bgcolor"))
    haskey(ALIGNS, lowercase(a("align"))) && say("text-align", ALIGNS[lowercase(a("align"))])
    lowercase(a("valign")) in ("top", "middle", "bottom", "baseline") && say("vertical-align", lowercase(a("valign")))
    tag == "tr" && say("height", measure(a("height"); zero=false))
  elseif tag in ("col", "colgroup")
    say("width", measure(a("width"); zero=false))
  elseif tag == "img" || (tag == "input" && lowercase(a("type")) == "image")
    say("width", measure(a("width")))
    say("height", measure(a("height")))
    if has("border") && (w = measure(a("border"))) !== nothing
      say("border-width", w)
      say("border-style", "solid")
    end
    align = lowercase(a("align"))
    align in ("left", "right") && say("float", align)
    align in ("top", "middle", "bottom", "texttop") && say("vertical-align", align == "texttop" ? "text-top" : align)
    align in ("absmiddle", "abscenter") && say("vertical-align", "middle")
    has("hspace") && (say("margin-left", measure(a("hspace"))); say("margin-right", measure(a("hspace"))))
    has("vspace") && (say("margin-top", measure(a("vspace"))); say("margin-bottom", measure(a("vspace"))))
  elseif tag in ("video", "canvas", "iframe", "embed", "object")
    say("width", measure(a("width")))
    say("height", measure(a("height")))
    tag == "iframe" && a("frameborder") in ("0", "no") && say("border-style", "none")
  elseif tag == "font"
    say("color", a("color"))
    say("font-family", a("face"))
    if (m = match(r"^([+-]?)(\d+)", a("size"))) !== nothing
      n = Base.parse(Int, m[2])
      n = m[1] == "+" ? 3 + n : m[1] == "-" ? 3 - n : n
      say("font-size", FONT_SIZES[clamp(n, 1, 7)])
    end
  elseif tag in ("p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "center")
    haskey(ALIGNS, lowercase(a("align"))) && say("text-align", ALIGNS[lowercase(a("align"))])
  elseif tag == "hr"
    say("width", measure(a("width")))
    has("size") && say("height", measure(a("size")))
    if has("color")
      say("border-color", a("color"))
      say("background-color", a("color"))
      say("border-style", "solid")
    end
    align = lowercase(a("align"))
    align == "left" && (say("margin-left", "0"); say("margin-right", "auto"))
    align == "right" && (say("margin-left", "auto"); say("margin-right", "0"))
  elseif tag in ("ul", "ol", "li")
    kind = a("type")
    say("list-style-type", get(Dict("1" => "decimal", "a" => "lower-alpha", "A" => "upper-alpha", "i" => "lower-roman", "I" => "upper-roman"), kind, lowercase(kind)))
  elseif tag == "br"
    clear = lowercase(a("clear"))
    say("clear", clear == "all" ? "both" : clear)
  elseif tag == "textarea"
    cols = something(tryparse(Int, a("cols")), 20)
    rows = something(tryparse(Int, a("rows")), 2)
    # As wide as so many letters and the bar that scrolls it, and as tall as so many lines
    say("width", "calc($(round(0.6 * cols, digits=2))em + 18px)")
    say("height", "$(round(rows * 13 / 11, digits=3))em")
  elseif tag == "input" && has("size") && (n = tryparse(Int, a("size"))) !== nothing && n > 0
    say("width", "$(round(0.55 * n + 0.6, digits=2))em")
  elseif tag in SVG_TAGS
    # A length of an SVG has px when it has no unit
    lenient(v) = occursin(r"^[0-9.]+$", v) ? v * "px" : v
    tag == "svg" && (say("width", lenient(a("width"))); say("height", lenient(a("height"))))
    for (name, v) in e.attrs
      (name in SHAPE || name in SVG_LOOKS) && say(name, name == "font-size" ? lenient(strip(v)) : strip(v))
    end
  end
  out
end

# --- the style of each element ------------------------------------------------------------

"The rules of a page, and which of them can be for an element, by what the last part of its selector asks"
struct Index
  ids::Dict{String,Vector{Rule}}
  classes::Dict{String,Vector{Rule}}
  tags::Dict{String,Vector{Rule}}
  rest::Vector{Rule}
end

Index(rules) = begin
  s = Index(Dict(), Dict(), Dict(), Rule[])
  for r in rules
    part = r.selector.parts[1]
    into = !isempty(part.id) ? get!(() -> Rule[], s.ids, part.id) : !isempty(part.classes) ? get!(() -> Rule[], s.classes, part.classes[1]) :
           !isempty(part.tag) ? get!(() -> Rule[], s.tags, part.tag) : s.rest
    push!(into, r)
  end
  s
end

"Call `f` with each rule of `s` that's for the element `e`, or for a part of it"
each_rule(f, s::Index, e::Element) = begin
  try_all(rules) = foreach(r -> matches(r.selector, e) && f(r), rules)
  id = attr(e, "id")
  isempty(id) || haskey(s.ids, id) && try_all(s.ids[id])
  for k in split(attr(e, "class"))
    haskey(s.classes, k) && try_all(s.classes[k])
  end
  haskey(s.tags, e.tag) && try_all(s.tags[e.tag])
  try_all(s.rest)
end

const BROWSER_INDEX = Index(BROWSER)
const QUIRKS_INDEX = Index(QUIRKS)

"The style of each element of a page, and of the parts of an element that the page's CSS makes"
mutable struct Look
  styles::IdDict{Element,Style}
  before::IdDict{Element,Style}
  after::IdDict{Element,Style}
  marker::IdDict{Element,Style}
  sheet::Stylesheet
  contained::Bool                # some rule asks how big the box that an element is in is (@container)
  until::Float64                 # how many seconds after the page was first shown its last animation stops: Inf for one that never does, 0 with none
end
Base.getindex(l::Look, e::Element) = l.styles[e]
Base.haskey(l::Look, e::Element) = haskey(l.styles, e)
Base.get(l::Look, e::Element, default) = get(l.styles, e, default)

# One declaration that's for an element: whether it's !important, where it's from (0 the browser, 1 the tag, 2 the page, 3 the
# element's own style, 4 an animation), its layer, how specific its rule is, its order, and what it declares
const Found = Tuple{Bool,Int,Int,NTuple{3,Int},Int,String,String}

# --- what moves ---------------------------------------------------------------------------

"One animation that an element's style names"
struct Motion
  name::String       # of its @keyframes
  long::Float64      # how many seconds one run takes
  delay::Float64     # how many seconds it waits before the first run
  count::Float64     # how many runs: Inf for one that never stops
  way::Symbol        # :normal, :reverse, :alternate or :alternate_reverse
  fill::Symbol       # :none, :forwards, :backwards or :both: whether it shows before its first run and after its last
  ease::String       # how it speeds up and slows down between two steps, as CSS writes it
  paused::Bool
end

"One change of an element's style that takes time: a `transition`"
struct Run
  field::Symbol      # the part of the style that changes
  from::Any
  to::Any
  start::Float64     # how many seconds after the page was first shown the change was seen
  long::Float64      # how many seconds it takes
  delay::Float64     # how many seconds it waits first
  ease::String       # how it speeds up and slows down, as CSS writes it
  name::String       # the property, as CSS names it
end
const NO_RUNS = Run[]

"What a clock keeps of an element from one time that its styles are worked out to the next"
struct Shown
  style::Any         # the element's style as it is with no change under way
  runs::Vector{Run}  # the changes that are under way
  busy::Bool         # an animation of the element was running
end

"""
What a page that changes with time keeps from one layout to the next: when
each of its animations started, and each element's style the last time, with
the changes of it that take time (`transition`). A page that's laid out again
and again as time passes is given the same clock each time. So an animation
that an element gets later starts then, and a style that changes takes the
time that its `transition` says.

The styles of a page can be worked out several times for one layout. What
the clock keeps changes only when `commit!` is called, after the last time.
`events!` gives what ended since it was last asked, for a page's scripts.
"""
mutable struct Clock
  began::IdDict{Any,Dict{String,Tuple{Float64,Bool}}}   # for an element, or an element and its part: when each of its animations was first seen, and whether its end was told
  shown::IdDict{Any,Shown}
  ended::Vector{Tuple{Any,String,String,Float64}}       # what ended: the element, "animationend" or "transitionend", the animation's or the property's name, and how long it took
  nextbegan::IdDict{Any,Dict{String,Tuple{Float64,Bool}}}   # what these three will be once the styles that are being worked out are the page's
  nextshown::IdDict{Any,Shown}
  nextended::Vector{Tuple{Any,String,String,Float64}}
end
Clock() = Clock(IdDict{Any,Dict{String,Tuple{Float64,Bool}}}(), IdDict{Any,Shown}(), Tuple{Any,String,String,Float64}[],
                IdDict{Any,Dict{String,Tuple{Float64,Bool}}}(), IdDict{Any,Shown}(), Tuple{Any,String,String,Float64}[])

"Start to work the styles out again: what the last time noted and didn't commit is dropped"
again!(k::Clock) = (empty!(k.nextbegan); empty!(k.nextshown); empty!(k.nextended); k)

"""
When the animation `name` of `who` started: now, `at` seconds after the page
was first shown, unless the clock has met it before. With `over`, the
animation has ended, and that's noted for `events!` the first time.
"""
started!(k::Clock, who, name, at; over=NaN) = begin
  start, told = get(get(k.began, who, NO_STARTS), name, (Float64(at), false))
  if !isnan(over) && !told
    told = true
    push!(k.nextended, (who, "animationend", String(name), Float64(over)))
  end
  get!(() -> Dict{String,Tuple{Float64,Bool}}(), k.nextbegan, who)[name] = (start, told)
  start
end
const NO_STARTS = Dict{String,Tuple{Float64,Bool}}()

"The styles that were just worked out are the page's: keep what they noted. An animation that the page has no more is forgotten, so one that comes back starts again."
commit!(k::Clock) = begin
  k.began, k.nextbegan = k.nextbegan, IdDict{Any,Dict{String,Tuple{Float64,Bool}}}()
  k.shown, k.nextshown = k.nextshown, IdDict{Any,Shown}()
  append!(k.ended, k.nextended)
  empty!(k.nextended)
  k
end

"What ended since this was last asked: for each, the element, \"animationend\" or \"transitionend\", the animation's or the property's name, and how many seconds it took"
events!(k::Clock) = (out = copy(k.ended); empty!(k.ended); out)

const WAYS = Dict("normal" => :normal, "reverse" => :reverse, "alternate" => :alternate, "alternate-reverse" => :alternate_reverse)
const FILLS = Dict("none" => :none, "forwards" => :forwards, "backwards" => :backwards, "both" => :both)
const EASES = Dict("ease" => (0.25, 0.1, 0.25, 1.0), "ease-in" => (0.42, 0.0, 1.0, 1.0), "ease-out" => (0.0, 0.0, 0.58, 1.0), "ease-in-out" => (0.42, 0.0, 0.58, 1.0))
const NO_MOTIONS = Motion[]

"How many seconds a time like `1.5s` or `200ms` is, or nothing"
seconds(v) = begin
  m = match(r"^([+-]?(?:[0-9]*\.)?[0-9]+)(s|ms)$", v)
  m === nothing ? nothing : Base.parse(Float64, m[1]) / (m[2] == "ms" ? 1000 : 1)
end

iseasing(w) = haskey(EASES, w) || w in ("linear", "step-start", "step-end") || occursin(r"^(cubic-bezier|steps|linear)\(", w)

"The animations that the declarations `found` give an element. `vars` holds the element's variables."
motions(found::Vector{Found}, vars) = begin
  names, longs, delays, counts = String[], Float64[], Float64[], Float64[]
  ways, fills, eases, states = Symbol[], Symbol[], String[], Bool[]
  list(v) = [String(strip(p)) for p in pieces(v, ',')]
  for x in found
    name = x[6]
    startswith(name, "-webkit-animation") && (name = name[9:end])
    startswith(name, "animation") || continue
    value = x[7]
    occursin("var(", value) && (value = substitute(value, n -> get(vars, n, nothing)))
    value === nothing && continue
    if name == "animation"
      foreach(empty!, (names, longs, delays, counts, ways, fills, eases, states))
      for one in list(value)
        who, times, count, way, fill, ease, paused = "none", Float64[], 1.0, :normal, :none, "ease", false
        named = false
        for word in terms(one)
          w = lowercase(word)
          if (t = seconds(w)) !== nothing
            push!(times, t)
          elseif w == "infinite"
            count = Inf
          elseif occursin(r"^[0-9.]+$", w) && (n = tryparse(Float64, w)) !== nothing
            count = n
          elseif iseasing(w)
            ease = w
          elseif haskey(WAYS, w)
            way = WAYS[w]
          elseif haskey(FILLS, w) && (w != "none" || named)
            fill = FILLS[w]
          elseif w in ("running", "paused")
            paused = w == "paused"
          elseif !named
            who, named = String(strip(word, ['"', '\''])), true
          end
        end
        push!(names, who); push!(longs, get(times, 1, 0.0)); push!(delays, get(times, 2, 0.0)); push!(counts, count)
        push!(ways, way); push!(fills, fill); push!(eases, ease); push!(states, paused)
      end
    elseif name == "animation-name"
      names = [String(strip(n, ['"', '\''])) for n in list(value)]
    elseif name == "animation-duration"
      longs = [something(seconds(lowercase(v)), 0.0) for v in list(value)]
    elseif name == "animation-delay"
      delays = [something(seconds(lowercase(v)), 0.0) for v in list(value)]
    elseif name == "animation-iteration-count"
      counts = [lowercase(v) == "infinite" ? Inf : max(0.0, something(tryparse(Float64, v), 1.0)) for v in list(value)]
    elseif name == "animation-direction"
      ways = [get(WAYS, lowercase(v), :normal) for v in list(value)]
    elseif name == "animation-fill-mode"
      fills = [get(FILLS, lowercase(v), :none) for v in list(value)]
    elseif name == "animation-timing-function"
      eases = [lowercase(v) for v in list(value)]
    elseif name == "animation-play-state"
      states = [lowercase(v) == "paused" for v in list(value)]
    end
  end
  isempty(names) && return NO_MOTIONS
  pick(v, i, default) = isempty(v) ? default : v[mod1(i, length(v))]
  [Motion(n, pick(longs, i, 0.0), pick(delays, i, 0.0), pick(counts, i, 1.0), pick(ways, i, :normal), pick(fills, i, :none), pick(eases, i, "ease"), pick(states, i, false))
   for (i, n) in enumerate(names) if lowercase(n) != "none"]
end

"How far along a curve of CSS's `cubic-bezier(x1, y1, x2, y2)` is, `x` of the way through its time"
bezier(x1, y1, x2, y2, x) = begin
  (x <= 0 || x >= 1) && return clamp(x, 0.0, 1.0)
  at(a, b, t) = 3 * a * t * (1 - t)^2 + 3 * b * t^2 * (1 - t) + t^3
  lo, hi = 0.0, 1.0
  for _ in 1:40
    mid = (lo + hi) / 2
    at(x1, x2, mid) < x ? (lo = mid) : (hi = mid)
  end
  at(y1, y2, (lo + hi) / 2)
end

"How far a change has got, `x` of the way through its time, when it speeds up and slows down as `how` says: `ease`, `steps(4)` and the like"
eased(how::AbstractString, x) = begin
  how == "linear" && return x
  curve = get(EASES, how, nothing)
  curve === nothing || return bezier(curve..., x)
  how == "step-start" && return 1.0
  how == "step-end" && return x >= 1 ? 1.0 : 0.0
  if (m = match(r"^cubic-bezier\(([^)]*)\)$", how)) !== nothing
    n = [tryparse(Float64, strip(p)) for p in split(m[1], ',')]
    return length(n) == 4 && !any(isnothing, n) ? bezier(clamp(n[1], 0, 1), n[2], clamp(n[3], 0, 1), n[4], x) : x
  elseif (m = match(r"^steps\(\s*([0-9]+)\s*(?:,\s*([a-z-]+)\s*)?\)$", how)) !== nothing
    n = max(1, Base.parse(Int, m[1]))
    x >= 1 && return 1.0
    done = floor(x * n)
    jump = something(m[2], "end")
    return jump in ("start", "jump-start") ? (done + 1) / n : jump == "jump-none" ? (n == 1 ? 0.0 : done / (n - 1)) : jump == "jump-both" ? (done + 1) / (n + 1) : done / n
  elseif (m = match(r"^linear\(([^)]*)\)$", how)) !== nothing
    # The points of a line with corners: each is how far the change has got, and where in the time that is
    points = Tuple{Float64,Float64}[]
    parts = [split(strip(p)) for p in split(m[1], ',')]
    for (i, p) in enumerate(parts)
      y = isempty(p) ? nothing : tryparse(Float64, p[1])
      y === nothing && return x
      at = length(p) > 1 && endswith(p[2], '%') ? something(tryparse(Float64, chop(p[2])), NaN) / 100 : i == 1 ? 0.0 : i == length(parts) ? 1.0 : NaN
      push!(points, (at, y))
    end
    isempty(points) && return x
    # A point with no place is spread evenly between the ones that have a place
    i = 1
    while i <= length(points)
      if isnan(points[i][1])
        j = something(findnext(p -> !isnan(p[1]), points, i), length(points))
        from = points[i-1][1]
        to = isnan(points[j][1]) ? 1.0 : points[j][1]
        for k in i:j-1
          points[k] = (from + (to - from) * (k - i + 1) / (j - i + 1), points[k][2])
        end
        i = j
      end
      i += 1
    end
    j = something(findfirst(p -> p[1] >= x, points), length(points))
    j == 1 && return points[1][2]
    (x0, y0), (x1, y1) = points[j-1], points[j]
    return x1 > x0 ? y0 + (y1 - y0) * (x - x0) / (x1 - x0) : y1
  end
  x
end

# --- a value between two ------------------------------------------------------------------

between(a::Float64, b::Float64, t) = a + (b - a) * t

"""
The value that's `t` of the way from `a` to `b`: 0 gives `a` and 1 gives `b`.
Two numbers, two lengths, two colours, two shadows and two transforms have
values between them. Anything else is `a` for the first half and `b` after.
"""
mix(a, b, t) = a === b || t < 0.5 ? a : b
mix(a::Float64, b::Float64, t) = a == b ? a : isfinite(a) && isfinite(b) ? between(a, b, t) : t < 0.5 ? a : b
mix(a::Int, b::Int, t) = a == b || a == NO_Z || b == NO_Z ? (t < 0.5 ? a : b) : round(Int, between(Float64(a), Float64(b), t))
simple(l::Len) = !l.auto && l.how == :length && l.math === nothing
mix(a::Len, b::Len, t) = a === b ? a : simple(a) && simple(b) ? Len(between(a.px, b.px, t), between(a.pct, b.pct, t), between(a.em, b.em, t), false, :length, nothing) : t < 0.5 ? a : b
mix(a::UInt32, b::UInt32, t) = begin
  (a == b || a == CURRENT || b == CURRENT) && return t < 0.5 ? a : b
  part(x, k) = Float64((x >> k) & 0xff)
  αa, αb = part(a, 24) / 255, part(b, 24) / 255
  α = between(αa, αb, t)
  α <= 0 && return 0x00000000
  # A colour that's see-through pulls the other less far towards itself
  one(k) = round(UInt32, clamp((part(a, k) * αa * (1 - t) + part(b, k) * αb * t) / α, 0.0, 255.0))
  round(UInt32, clamp(α, 0.0, 1.0) * 255) << 24 | one(16) << 16 | one(8) << 8 | one(0)
end
mix(a::Tuple, b::Tuple, t) = begin
  a === b && return a
  # A word in it, like the `px` of a line height, says what its numbers mean: with two words, there's nothing between
  (length(a) != length(b) || any(i -> a[i] isa Union{Symbol,Bool,AbstractString} && a[i] != b[i], eachindex(a))) && return t < 0.5 ? a : b
  map((x, y) -> mix(x, y, t), a, b)
end
mix(a::Vector{T}, b::Vector{T}, t) where T<:Union{Tuple,Len} = a === b ? a : length(a) == length(b) ? T[mix(x, y, t) for (x, y) in zip(a, b)] : t < 0.5 ? a : b
mix(a::Vector{Any}, b::Vector{Any}, t) = a === b ? a : length(a) == length(b) ? Any[mix(x, y, t) for (x, y) in zip(a, b)] : t < 0.5 ? a : b

mix(a::Shade, b::Shade, t) = Shade(between(a.dx, b.dx, t), between(a.dy, b.dy, t), between(a.blur, b.blur, t), between(a.spread, b.spread, t), mix(a.color, b.color, t), a.inset)
mix(a::Vector{Shade}, b::Vector{Shade}, t) = begin
  a === b && return a
  n = max(length(a), length(b))
  # A shadow that only one of them has comes out of nothing
  one(v, other, i) = i <= length(v) ? v[i] : Shade(0.0, 0.0, 0.0, 0.0, 0x00000000, other[i].inset)
  pairs = [(one(a, b, i), one(b, a, i)) for i in 1:n]
  any(p -> p[1].inset != p[2].inset, pairs) ? (t < 0.5 ? a : b) : Shade[mix(x, y, t) for (x, y) in pairs]
end

"The step of a filter that changes nothing, of the kind of `e`"
still(e::Effect) = Effect(e.kind, e.kind in (:brightness, :contrast, :opacity, :saturate) ? 1.0 : 0.0, 0.0, 0.0, 0x00000000)
mix(a::Effect, b::Effect, t) = Effect(a.kind, between(a.x, b.x, t), between(a.y, b.y, t), between(a.z, b.z, t), mix(a.color, b.color, t))
mix(a::Vector{Effect}, b::Vector{Effect}, t) = begin
  a === b && return a
  isempty(a) && return Effect[mix(still(y), y, t) for y in b]
  isempty(b) && return Effect[mix(x, still(x), t) for x in a]
  length(a) == length(b) && all(i -> a[i].kind == b[i].kind, eachindex(a)) ? Effect[mix(x, y, t) for (x, y) in zip(a, b)] : t < 0.5 ? a : b
end

const SAME_TURN = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
"The step of a transform that changes nothing, of the kind of `t`"
still(t::Turn) = Turn(t.kind, ZERO, ZERO, t.kind == :matrix ? SAME_TURN : (0.0, 0.0, 0.0, 0.0, 0.0, 0.0))
mix(a::Turn, b::Turn, t) = Turn(a.kind, mix(a.x, b.x, t), mix(a.y, b.y, t), map((x, y) -> between(x, y, t), a.n, b.n))

"The six numbers of the matrix of one step of a transform that has no percent in it"
six(t::Turn) = t.kind == :move ? (1.0, 0.0, 0.0, 1.0, t.x.px, t.y.px) : t.kind == :spin ? (cos(t.n[1]), sin(t.n[1]), -sin(t.n[1]), cos(t.n[1]), 0.0, 0.0) : t.n
after(m, n) = (m[1] * n[1] + m[3] * n[2], m[2] * n[1] + m[4] * n[2], m[1] * n[3] + m[3] * n[4], m[2] * n[3] + m[4] * n[4],
               m[1] * n[5] + m[3] * n[6] + m[5], m[2] * n[5] + m[4] * n[6] + m[6])

"What a matrix does, apart: how far it moves, how much it stretches across and down, how far it slants and how far it turns"
parts(m) = begin
  a, b, c, d = m[1:4]
  sx = hypot(a, b)
  sx == 0 || (a /= sx; b /= sx)
  slant = a * c + b * d
  c -= a * slant
  d -= b * slant
  sy = hypot(c, d)
  sy == 0 || (c /= sy; d /= sy; slant /= sy)
  a * d < b * c && (a = -a; b = -b; slant = -slant; sx = -sx)
  (m[5], m[6], sx, sy, slant, atan(b, a))
end

mix(a::Vector{Turn}, b::Vector{Turn}, t) = begin
  a === b && return a
  isempty(a) && return Turn[mix(still(y), y, t) for y in b]
  isempty(b) && return Turn[mix(x, still(x), t) for x in a]
  length(a) == length(b) && all(i -> a[i].kind == b[i].kind, eachindex(a)) && return Turn[mix(x, y, t) for (x, y) in zip(a, b)]
  # Two lists of other steps: each as one matrix, and between what the two matrices do. That needs lengths in px.
  whole(v) = all(s -> s.kind != :move || (simple(s.x) && simple(s.y) && s.x.pct == 0 && s.y.pct == 0 && s.x.em == 0 && s.y.em == 0), v)
  (whole(a) && whole(b)) || return t < 0.5 ? a : b
  pa, pb = parts(foldl(after, six.(a); init=SAME_TURN)), parts(foldl(after, six.(b); init=SAME_TURN))
  turn = pb[6] - pa[6]
  turn > π ? (turn -= 2π) : turn < -π ? (turn += 2π) : nothing   # the short way round
  x, y, sx, sy, slant = (between(pa[i], pb[i], t) for i in 1:5)
  r = pa[6] + turn * t
  m = after(after((cos(r), sin(r), -sin(r), cos(r), x, y), (1.0, 0.0, slant, 1.0, 0.0, 0.0)), (sx, 0.0, 0.0, sy, 0.0, 0.0))
  Turn[Turn(:matrix, ZERO, ZERO, m)]
end

Base.copy(s::Style) = Style((getfield(s, f) for f in fieldnames(Style))...)
@eval mix!(s::Style, a::Style, b::Style, t) = begin
  $((:(s.$f = mix(a.$f, b.$f, t)) for f in fieldnames(Style))...)
  s
end

"Each property that `name: value` stands for, with its value: the four sides of a `margin`, and the like"
longhands!(out, name, value) = begin
  if !haskey(PROPS, name)
    longer = expand(name, value)
    if longer !== nothing
      foreach(((n, v),) -> longhands!(out, n, v), longer)
      return out
    end
    m = match(r"^-(?:webkit|moz|ms|o)-(.+)$", name)
    m === nothing || return longhands!(out, m[1], value)
  end
  push!(out, String(name) => String(value))
  out
end

"""
Give `s` the look that the steps of a @keyframes make of it, `p` of the way
through one run: 0 at its start and 1 at its end. A property that a step says
nothing of goes from the step before that says it to the next that does, and
from or to what `s` has when there's none. `how` is how the change speeds up
and slows down between two steps.
"""
pose!(s::Style, steps, p, how, c::Context, parent::Style) = begin
  said = Dict{String,Vector{Tuple{Float64,String,String}}}()   # for each property: where it's said, its value there, and how it goes on from there
  order = String[]
  vars = s.vars
  for (at, declared) in steps
    own = how
    for d in declared
      d.name == "animation-timing-function" && (own = lowercase(strip(d.value)))
    end
    for d in declared
      (d.name == "animation-timing-function" || startswith(d.name, "--")) && continue
      value = occursin("var(", d.value) ? substitute(d.value, n -> get(vars, n, nothing)) : d.value
      value === nothing && continue
      for (name, v) in longhands!(Pair{String,String}[], d.name, value)
        list = get!(() -> (push!(order, name); Tuple{Float64,String,String}[]), said, name)
        i = findfirst(x -> x[1] == at, list)
        i === nothing ? push!(list, (at, v, own)) : (list[i] = (at, v, own))
      end
    end
  end
  # The properties that are between the same two steps go together
  groups = Dict{Tuple{Float64,Float64,String},Vector{Tuple{String,Union{String,Nothing},Union{String,Nothing}}}}()
  spans = Tuple{Float64,Float64,String}[]
  for name in order
    list = said[name]
    i, j = findlast(x -> x[1] <= p, list), findfirst(x -> x[1] > p, list)
    span = (i === nothing ? 0.0 : list[i][1], j === nothing ? 1.0 : list[j][1], i === nothing ? how : list[i][3])
    push!(get!(() -> (push!(spans, span); valtype(groups)()), groups, span), (name, i === nothing ? nothing : list[i][2], j === nothing ? nothing : list[j][2]))
  end
  for span in spans
    a, b = copy(s), copy(s)
    for (name, from, to) in groups[span]
      from === nothing || set!(a, name, from, c, parent)
      to === nothing || set!(b, name, to, c, parent)
    end
    mix!(s, a, b, span[2] > span[1] ? eased(span[3], (p - span[1]) / (span[2] - span[1])) : 0.0)
  end
  s
end

"How far through a run the animation `m` is, `t` seconds after it started, or nothing when it shows nothing then"
progress(m::Motion, t) = begin
  t -= m.delay
  whole = m.long <= 0 ? 0.0 : m.long * m.count
  run, p = if t < 0
    m.fill in (:backwards, :both) || return nothing
    (0.0, 0.0)
  elseif t >= whole || m.long <= 0
    m.fill in (:forwards, :both) || return nothing
    isfinite(m.count) || return nothing
    # It stays as its last run ended
    m.count == 0 ? (0.0, 0.0) : isinteger(m.count) ? (m.count - 1, 1.0) : (floor(m.count), m.count - floor(m.count))
  else
    n = t / m.long
    (floor(n), n - floor(n))
  end
  back = m.way == :reverse || (m.way == :alternate && isodd(Int(run))) || (m.way == :alternate_reverse && iseven(Int(run)))
  back ? 1 - p : p
end

"""
Give `s` what its animations make of it `at` seconds after the page was first
shown, and say when the last of them stops: Inf for one that never does, and
0 with none. With no time, an animation that ends and stays is shown as it
ends, and the others show nothing: that's the page as it comes to rest.
`start(name, over)` gives when an animation of the element started, and is
told how many seconds the animation took once it's over: NaN before that.
"""
move!(s::Style, found::Vector{Found}, frames, c::Context, parent::Style, at, start) = begin
  until = 0.0
  for m in motions(found, s.vars)
    steps = get(frames, m.name, nothing)
    steps === nothing && continue
    began = start(m.name, NaN)
    stops = began + m.delay + m.long * m.count
    m.paused || m.long <= 0 || (until = max(until, stops))
    # An animation that's over is noted, for the page's scripts
    at === nothing || m.paused || m.long <= 0 || at < stops || start(m.name, m.long * m.count)
    p = progress(m, at === nothing ? Inf : m.paused ? 0.0 : at - began)
    p === nothing || pose!(s, steps, p, m.ease, c, parent)
  end
  until
end

# --- changes that take time ---------------------------------------------------------------

"What a `transition` says of one property: how long a change of it takes"
struct Glide
  what::String       # the property, or "all"
  long::Float64
  delay::Float64
  ease::String
end
const NO_GLIDES = Glide[]

"The transitions that the declarations `found` give an element. `vars` holds the element's variables."
glides(found::Vector{Found}, vars) = begin
  whats, longs, delays, eases = String[], Float64[], Float64[], String[]
  said = false
  list(v) = [String(strip(p)) for p in pieces(v, ',')]
  for x in found
    name = x[6]
    (startswith(name, "transition") || startswith(name, "-webkit-transition")) || continue
    name[1] == '-' && (name = name[9:end])
    value = x[7]
    occursin("var(", value) && (value = substitute(value, n -> get(vars, n, nothing)))
    value === nothing && continue
    said = true
    if name == "transition"
      foreach(empty!, (whats, longs, delays, eases))
      for one in list(value)
        what, times, ease = "all", Float64[], "ease"
        for word in terms(one)
          w = lowercase(word)
          (t = seconds(w)) !== nothing ? push!(times, t) : iseasing(w) ? (ease = w) : (what = w)
        end
        push!(whats, what); push!(longs, get(times, 1, 0.0)); push!(delays, get(times, 2, 0.0)); push!(eases, ease)
      end
    elseif name == "transition-property"
      whats = lowercase.(list(value))
    elseif name == "transition-duration"
      longs = [something(seconds(lowercase(v)), 0.0) for v in list(value)]
    elseif name == "transition-delay"
      delays = [something(seconds(lowercase(v)), 0.0) for v in list(value)]
    elseif name == "transition-timing-function"
      eases = [lowercase(v) for v in list(value)]
    end
  end
  said || return NO_GLIDES
  isempty(whats) && push!(whats, "all")
  pick(v, i, default) = isempty(v) ? default : v[mod1(i, length(v))]
  [Glide(w, pick(longs, i, 0.0), pick(delays, i, 0.0), pick(eases, i, "ease")) for (i, w) in enumerate(whats) if w != "none"]
end

# The parts of a style that a property with several parts changes, where `expand` can't say
const SEVERAL = Dict("background" => [:background, :image, :bgposition, :bgsize], "border" => [:border, :bordercolor], "border-color" => [:bordercolor],
                     "border-width" => [:border], "border-radius" => [:radius, :radiusv], "outline" => [:outline, :outlinecolor, :outlineoffset],
                     "font" => [:size, :weight, :lineheight], "flex" => [:grow, :shrink, :basis], "text-decoration" => [:decocolor, :decothick],
                     "inset" => [:inset], "margin" => [:margin], "padding" => [:padding], "gap" => [:gap])
const EVERY_PART = Symbol[f for f in fieldnames(Style) if f != :vars]
const PARTS = Dict{String,Vector{Symbol}}()

"The parts of a style that the property `name` changes: all of them for `all`"
parts_of(name::AbstractString) = name == "all" ? EVERY_PART : get!(PARTS, name) do
  haskey(PROPS, name) && return Symbol[PROPS[name].field]
  haskey(SEVERAL, name) && return SEVERAL[name]
  longer = try longhands!(Pair{String,String}[], name, "initial") catch; Pair{String,String}[] end
  unique!(Symbol[PROPS[n].field for (n, _) in longer if haskey(PROPS, n)])
end

"The name that CSS has for the part `field` of a style, for the side of it that differs between `old` and `new`"
property(field::Symbol, old, new) = begin
  side = old isa Tuple && new isa Tuple && length(old) == length(new) ? something(findfirst(i -> !same(old[i], new[i]), eachindex(old)), 0) : 0
  names = sort!([n for (n, p) in PROPS if p.field == field && (p.side == 0 || p.side == side) && n[1] != '-']; by=n -> (length(n), n))
  isempty(names) ? String(field) : names[1]
end

same(a, b) = a === b || isequal(a, b)

"The value of a change that's under way, `t` seconds after it started to move"
value(r::Run, t) = t <= 0 ? r.from : r.field == :visible ? (r.from || r.to) : mix(r.from, r.to, eased(r.ease, t / r.long))

# The parts of a style that are the colour of the text when nothing else is said, and whether the value `v` of one is that colour
const FOLLOWERS = (:bordercolor, :outlinecolor, :colrulecolor)
follows(v, color) = v isa Tuple ? all(x -> x == color, v) : v == color

# What says that every inherited part of a parent's style may be moving: the parent has an animation
const EVERY = Symbol[:every]

"""
Give `s`, the style that was just worked out for `who`, the changes of it that
take time, `at` seconds after the page was first shown. A part of the style
that isn't what the clock `k` saw the last time starts to change when a
`transition` of the element is for it, from what it looks like now. `found`
holds the element's declarations, and `parent` is its parent's style as it
looks now. `moving` names the parts of the parent's style that are changing:
what an element only has from its parent is no change of its own. `busy` says
that an animation of the element runs.

Gives the parts that are changing for what's in the element, and when the last
of the changes ends.
"""
change!(k::Clock, s::Style, parent::Style, found::Vector{Found}, who, moving, busy::Bool, at) = begin
  before = get(k.shown, who, nothing)
  runs = before === nothing ? NO_RUNS : before.runs
  specs = any(x -> startswith(x[6], "transition") || startswith(x[6], "-webkit-transition"), found) ? glides(found, s.vars) : NO_GLIDES
  if before !== nothing && before.style !== s && !(isempty(specs) && isempty(runs))
    old = before.style::Style
    # What an animation changes is no change that takes time: not while it runs, and not at the layout that first sees it over
    still = busy || before.busy
    kept = Run[]
    # A change that's under way goes on while what it goes to is still the style
    for r in runs
      same(r.to, getfield(s, r.field)) && push!(kept, r)
    end
    if !still && !isempty(specs)
      seen = Set{Symbol}()
      for spec in Iterators.reverse(specs), f in parts_of(spec.what)
        f in seen && continue   # of two that are for one property, the later one counts
        push!(seen, f)
        from, to = getfield(old, f), getfield(s, f)
        same(from, to) && continue
        # What the element only has from its parent changes with the parent
        f in INHERITED && (moving === EVERY || f in moving) && same(to, getfield(parent, f)) && continue
        # A border or a line in the colour of the text changes with the text
        f in FOLLOWERS && s.color != old.color && follows(to, s.color) && follows(from, old.color) && continue
        i = findfirst(r -> r.field == f, runs)
        i === nothing || same(runs[i].to, to) && continue
        spec.long > 0 || continue
        # Two values with nothing between them change at once. Whether an element shows is the one that waits.
        f == :visible || (mid = mix(from, to, 0.5); !same(mid, from) && !same(mid, to)) || continue
        i === nothing || (from = value(runs[i], at - runs[i].start - runs[i].delay))
        push!(kept, Run(f, from, to, at, spec.long, spec.delay, spec.ease, property(f, from, to)))
      end
    end
    runs = kept
  end
  until = 0.0
  target = s
  going = moving
  if !isempty(runs)
    target = copy(s)
    going = moving === EVERY ? EVERY : Symbol[moving; [r.field for r in runs]]
    left = Run[]
    for r in runs
      t = at - r.start - r.delay
      if t >= r.long
        push!(k.nextended, (who, "transitionend", r.name, r.long))
      else
        setfield!(s, r.field, value(r, t))
        until = max(until, r.start + r.delay + r.long)
        push!(left, r)
      end
    end
    runs = left
    # A border or a line in the colour of the text has the colour that the text has now
    if s.color != target.color
      for f in FOLLOWERS
        v = getfield(target, f)
        follows(v, target.color) && setfield!(s, f, v isa Tuple ? map(_ -> s.color, v) : s.color)
      end
    end
  end
  busy && (going = EVERY)
  k.nextshown[who] = Shown(target, runs, busy)
  (going, until)
end
const NOT_MOVING = Symbol[]

"The faces of a font that an @font-face of the page gives the family `name`: for each, what it says"
faces_of(sheet::Stylesheet, name) = [f for f in sheet.faces if lowercase(strip(strip(get(f, "font-family", "")), ['"', '\''])) == lowercase(name)]

"The first and the last weight that an @font-face says its font is for"
weights(v) = begin
  ws = [w == "normal" ? 400 : w == "bold" ? 700 : something(tryparse(Float64, w), 400.0) for w in split(lowercase(v))]
  isempty(ws) ? (400, 400) : (round(Int, minimum(ws)), round(Int, maximum(ws)))
end

"The narrowest and the widest that an @font-face's `font-stretch`, like `75% 100%` or `condensed`, says that it's for, in percent of a normal width"
stretches(v) = begin
  ws = Float64[x for x in (stretch(w) for w in split(lowercase(v))) if x !== nothing]
  isempty(ws) ? (100.0, 100.0) : (minimum(ws), maximum(ws))
end

"The ranges of letters that an @font-face's `unicode-range` names"
ranges(v) = begin
  out = UnitRange{UInt32}[]
  for part in split(v, ',')
    m = match(r"^u\+([0-9a-f?]+)(?:-([0-9a-f]+))?$", lowercase(strip(part)))
    m === nothing && continue
    lo = tryparse(UInt32, replace(m[1], '?' => '0'), base=16)
    hi = m[2] !== nothing ? tryparse(UInt32, m[2], base=16) : tryparse(UInt32, replace(m[1], '?' => 'f'), base=16)
    lo === nothing || hi === nothing || push!(out, lo:hi)
  end
  out
end

"""
The name that text.jl knows the page's font `name` by, when the page gives it
with @font-face and one of its files can be read, or `name`. `load(address)`
gives the bytes of a file.
"""
web_family(sheet::Stylesheet, name, load) = begin
  found = faces_of(sheet, name)
  isempty(found) && return name
  described = map(found) do f
    sources = Any[]
    for src in pieces(get(f, "src", ""), ',')
      src = strip(src)
      if (m = match(r"^local\(\s*[\"']?([^\"')]*)[\"']?\s*\)"i, src)) !== nothing
        push!(sources, String(strip(m[1])))
      elseif (m = match(r"^url\(\s*(?:\"([^\"]*)\"|'([^']*)'|([^)]*?))\s*\)(?:\s*format\(\s*[\"']?([^\"')]*)[\"']?\s*\))?"i, src)) !== nothing
        kind = lowercase(something(m[4], ""))
        address = String(strip(something(m[1], m[2], m[3])))
        # Skia reads no font of these kinds
        (kind in ("embedded-opentype", "svg") || occursin(r"\.(eot|svg)([?#]|$)"i, address)) && continue
        push!(sources, () -> load(address))
      end
    end
    (weights(get(f, "font-weight", "400")), occursin(r"italic|oblique", lowercase(get(f, "font-style", "normal"))), ranges(get(f, "unicode-range", "")), sources,
     get(f, "src", ""), stretches(get(f, "font-stretch", get(f, "font-width", "normal"))))
  end
  key = "web:" * string(hash((lowercase(name), [(d[1], d[2], d[5], d[6]) for d in described])), base=16)
  Fonts.web!(key, [(d[1], d[2], d[3], d[4], d[6]) for d in described]) ? key : name
end

"""
What the declarations `found` of an element say its `color-scheme` is, or
nothing when they say nothing of it: then it has its parent's. The one that
wins is the one that would win in `apply!`.
"""
said_scheme(found) = begin
  best = nothing
  for x in found
    x[6] == "color-scheme" || continue
    (best === nothing || x[1:5] >= best[1:5]) && (best = x)
  end
  best === nothing && return nothing
  v = lowercase(strip(best[7]))
  v in ("inherit", "unset", "revert", "revert-layer") || occursin("var(", v) ? nothing : v == "initial" ? "normal" : String(v)
end

"""
True when an element whose `color-scheme` is `v`, like `light dark`, has the
dark colours, on a screen that's in dark mode when `dark`. One that can be
light or dark follows the screen, and one that's only dark is always dark.
"""
dark_scheme(v, dark) = (words = split(v); "dark" in words && (dark || !("light" in words)))

"What the page's `<meta name=\"color-scheme\">` says its colour scheme is, or \"normal\""
page_scheme(doc::Document) = begin
  for head in doc.root.children
    (head isa Element && head.tag == "head") || continue
    for m in head.children
      m isa Element && m.tag == "meta" && lowercase(strip(attr(m, "name"))) == "color-scheme" && return lowercase(strip(attr(m, "content")))
    end
  end
  "normal"
end

"""
The style of each element of `doc`, on a page `wide` px wide in a window
`high` px high. `extra` is CSS that the page didn't write, which goes after
the page's own. `load(address)` gives the bytes or the text of a sheet or a
font that the page names, or nothing. `base` is the address of the page.
`containers` gives how wide and how high the box of an element is, and its
names, for the rules that ask (@container): without it, no such rule is for
anything.

`at` is how many seconds ago the page was first shown: each element looks as
its animations make it then, and `look.until` says when the last of them
stops. With no time, the page is as it comes to rest. `clock` is a `Clock`
for a page whose styles are worked out again and again as time passes: with
one, a style that changes takes the time that its `transition` says. With
`commit=false`, the clock keeps nothing of these styles until `commit!` is
called: for the styles of one layout that are worked out several times.
"""
styles(doc::Document, wide; extra="", high=800, load=address -> nothing, base="", containers=nothing, at=nothing, clock=nothing, commit=true) = begin
  clock === nothing || again!(clock)
  text(address) = begin
    found = load(address)
    found === nothing ? nothing : found isa AbstractString ? String(found) : String(copy(found))
  end
  css = Stylesheet(load=text, supports=known)
  css.wide, css.high = wide, high
  from = isempty(doc.base) ? base : resolve(base, doc.base)
  for (words, m) in doc.sheets
    read!(css, words; media=isempty(strip(m)) ? String[] : [m], base=from)
  end
  isempty(extra) || read!(css, extra)
  rules = filter(r -> all(q -> media(q, wide, high), r.media), css.rules)
  page = Index(rules)
  look = Look(IdDict{Element,Style}(), IdDict{Element,Style}(), IdDict{Element,Style}(), IdDict{Element,Style}(), css, any(r -> !isempty(r.container), css.rules), 0.0)
  quirks = doc.mode == :quirks
  rootsize = Ref(16.0)
  families = Dict{String,String}()
  family(name) = get!(() -> web_family(css, name, address -> load(resolve(from, address))), families, name)
  # A rule in a later layer wins. A rule in no layer wins over them all. With !important, it's the other way round.
  rank(layer, important) = important ? (layer == 0 ? -typemax(Int) : -layer) : (layer == 0 ? typemax(Int) : layer)
  # True when each @container round the rule `r` is so for the element `e`
  inside(r::Rule, e::Element) = containers !== nothing && all(r.container) do q
    name = container_name(q)
    p = e.parent
    while p !== nothing
      box = get(containers, p, nothing)
      box !== nothing && (isempty(name) || name in split(box[3])) && return container(q, box[1], box[2])
      p = p.parent
    end
    false
  end
  # Give `s` the declarations `found`: the ones that win come last. It gives whether the top and the bottom margin are the browser's own.
  apply!(s::Style, found::Vector{Found}, c::Context, parent::Style, who) = begin
    sort!(found; alg=MergeSort, by=x -> x[1:5])
    start(name, over) = clock === nothing ? 0.0 : started!(clock, who, name, something(at, 0.0); over)
    move() = begin
      stops = move!(s, found, css.frames, c, parent, at, start)
      look.until = max(look.until, stops)
      at !== nothing && at < stops && (animated[] = true)
      nothing
    end
    # `revert` takes away what the page says of a property, so that the browser's own stays
    for name in unique(x[6] for x in found if lowercase(strip(x[7])) == "revert")
      last = findlast(x -> x[6] == name, found)
      lowercase(strip(found[last][7])) == "revert" && filter!(x -> !(x[6] == name && x[2] >= 2), found)
    end
    # The variables first, since the rest can use them. A variable's value is worked out here, where it's declared.
    own = nothing
    for x in found
      startswith(x[6], "--") || continue
      own === nothing && (own = Dict{String,String}())
      own[x[6]] = x[7]
    end
    if own !== nothing
      before = s.vars
      made = Dict{String,Union{String,Nothing}}()
      busy = Set{String}()
      value(name) = begin
        haskey(own, name) || return get(before, name, nothing)
        haskey(made, name) && return made[name]
        name in busy && return nothing   # it needs itself
        push!(busy, name)
        raw = own[name]
        v = lowercase(strip(raw)) in ("inherit", "unset", "revert") ? get(before, name, nothing) : lowercase(strip(raw)) == "initial" ? nothing :
            occursin("var(", raw) ? substitute(raw, value) : raw
        delete!(busy, name)
        made[name] = v
      end
      vars = copy(before)
      for name in keys(own)
        v = value(name)
        v === nothing ? delete!(vars, name) : (vars[name] = v)
      end
      s.vars = vars
    end
    top = bottom = false
    normal = true
    for (i, (important, origin, _, _, _, name, value)) in enumerate(found)
      # What an animation makes of the element goes over what isn't !important
      if normal && important
        normal = false
        isempty(css.frames) || move()
      end
      # Whether the margins that win are the browser's own
      if startswith(name, "margin")
        name in ("margin", "margin-top", "margin-block", "margin-block-start") && (top = origin == 0)
        name in ("margin", "margin-bottom", "margin-block", "margin-block-end") && (bottom = origin == 0)
      end
      # A tag's own lengths and colours are read more loosely than CSS
      if origin == 1
        value = name in ("background-color", "color", "border-color") && !(colour(value) isa UInt32) ?
                ((x = colour(value; loose=true)) isa UInt32 ? "#" * string(x & 0x00ffffff, base=16, pad=6) : continue) : value
      end
      set!(s, name, value, c, parent)
    end
    normal && !isempty(css.frames) && move()
    (top, bottom)
  end
  found = Found[]
  animated = Ref(false)   # an animation of the element whose style is being worked out runs
  timed = clock !== nothing && at !== nothing
  # Give the style `s` of `who` the changes of it that take time, and give the parts of it that are changing
  glide(s, parent, declared, who, moving) = begin
    going, stops = change!(clock, s, parent, declared, who, moving, animated[], at)
    look.until = max(look.until, stops)
    going
  end
  prefers = DARK[]
  root_dark = Ref(false)   # the colour scheme of the page's <html> is dark
  visit(e::Element, parent::Style, moving=NOT_MOVING, scheme="normal") = begin
    c = Context(wide, rootsize[], quirks, high)
    s = child(parent)
    empty!(found)
    parts = nothing   # the declarations for each part of the element: `::before` and the like
    add(into, origin, layer, weight, order, name, value, important) = push!(into, (important, origin, rank(layer, important), weight, order, name, value))
    from_index(index, origin) = each_rule(index, e) do r
      isempty(r.container) || inside(r, e) || return
      into = found
      if r.selector.pseudo != :none
        r.selector.pseudo in (:before, :after, :marker) || return
        parts === nothing && (parts = Dict{Symbol,Vector{Found}}())
        into = get!(() -> Found[], parts, r.selector.pseudo)
      end
      for d in r.declarations
        add(into, origin, r.layer, r.selector.weight, r.order, d.name, d.value, d.important)
      end
    end
    from_index(BROWSER_INDEX, 0)
    quirks && from_index(QUIRKS_INDEX, 0)
    for (i, (name, value)) in enumerate(hints(e))
      add(found, 1, 0, (0, 0, 0), i, name, value, false)
    end
    from_index(page, 2)
    for (i, d) in enumerate(declarations(attr(e, "style")))
      add(found, 3, 0, (0, 0, 0), i, d.name, d.value, d.important)
    end
    if e.parent === nothing && !isempty(css.props)
      # A variable that the page gives a first value has it from the top of the page down
      s.vars = merge(css.props, s.vars)
    end
    # The element's colour scheme, which what's in it has too unless it says another
    here = something(said_scheme(found), scheme)
    dark = dark_scheme(here, prefers)
    e.parent === nothing && (root_dark[] = dark)
    finish(moving) = begin
      animated[] = false
      top, bottom = apply!(s, found, c, parent, e)
      settle!(s, parent, e.tag)
      e.tag in LOOSE && (s.loose = (top, bottom))
      isempty(css.faces) || s.family === parent.family || (s.family = String[family(name) for name in s.family])
      timed && (moving = glide(s, parent, found, e, moving))
      e.parent === nothing && (rootsize[] = s.size)
      look.styles[e] = s
      if parts !== nothing
        for (part, declared) in parts
          ps = child(s)
          animated[] = false
          apply!(ps, declared, c, s, (e, part))
          settle!(ps, s)
          isempty(css.faces) || ps.family === s.family || (ps.family = String[family(name) for name in ps.family])
          timed && glide(ps, s, declared, (e, part), moving)
          if part == :marker
            look.marker[e] = ps
          elseif !(lowercase(ps.content) in ("", "none", "normal")) && ps.display != :none
            (part == :before ? look.before : look.after)[e] = ps
          end
        end
      end
      for k in e.children
        k isa Element && visit(k, s, moving, here)
      end
    end
    dark == DARK_SCHEME[] ? finish(moving) : with(() -> finish(moving), DARK_SCHEME => dark)
  end
  visit(doc.root, Style(), NOT_MOVING, page_scheme(doc))
  # What the page's <html> or <body> says of what overflows is for the window, which shows all of the page here
  top = look.styles[doc.root]
  top.overflow == :visible && haskey(look.styles, doc.body) && (look.styles[doc.body].overflow = :visible)
  top.overflow = :visible
  # Where a page whose colour scheme is dark gives no background, it's dark, as the window is in a browser
  if root_dark[] && alpha(top.background) == 0 && isempty(top.image)
    body = get(look.styles, doc.body, nothing)
    (body === nothing || (alpha(body.background) == 0 && isempty(body.image))) && (top.background = DARK_CANVAS)
  end
  clock === nothing || !commit || commit!(clock)
  look
end
