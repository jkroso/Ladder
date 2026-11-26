# Draws an SVG: the drawing of an <svg> element of a page, or of a file.
#
#     draw(canvas, element, look, x, y, w, h)   # the drawing of an <svg> element, in a rectangle of the canvas
#     found = image(bytes)                      # a picture of an SVG file: its width, its height and Skia's picture, or nothing
#
# `look` gives the style of each element, as style.jl works it out: a shape
# is drawn as the page's CSS says, and as its own tag says (`fill="red"`).
#
# What's drawn: paths, rectangles, circles, ovals, lines and shapes of many
# points. Text, with its parts (<tspan>). Groups, drawings in drawings, and a
# shape that's used again (<use>, <symbol>). Colours that run into each other
# (<linearGradient>, <radialGradient>). A shape that cuts another
# (<clipPath>). What moves, turns or stretches a shape (`transform`), and how
# see-through it is.
#
# What isn't: pictures in a drawing (<image>), patterns, masks, filters, the
# ends of lines (<marker>), and what moves.

@use Skia
@use "./dom" Element Text attr document walk
@use "./style" Style styles colour alpha
@use "./text" font drawn advances

const SAME = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
"The move `a` after the move `b`: each is the six numbers of a matrix"
times(a, b) = (a[1] * b[1] + a[3] * b[2], a[2] * b[1] + a[4] * b[2], a[1] * b[3] + a[3] * b[4], a[2] * b[3] + a[4] * b[4],
               a[1] * b[5] + a[3] * b[6] + a[5], a[2] * b[5] + a[4] * b[6] + a[6])
shift(x, y) = (1.0, 0.0, 0.0, 1.0, Float64(x), Float64(y))
stretch(x, y) = (Float64(x), 0.0, 0.0, Float64(y), 0.0, 0.0)
skia(m) = Ref(Skia.sk_matrix_t(Float32(m[1]), Float32(m[3]), Float32(m[5]), Float32(m[2]), Float32(m[4]), Float32(m[6]), 0f0, 0f0, 1f0))
rect(x, y, w, h) = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))

const NUMBER = r"[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?"
"The numbers that `v` writes, with spaces, commas or nothing between them"
numbers(v) = Float64[Base.parse(Float64, m.match) for m in eachmatch(NUMBER, v)]

"The matrix that a tag's `transform` writes, like `translate(10 20) rotate(45)`"
transform(v) = begin
  m = SAME
  for found in eachmatch(r"(matrix|translate|scale|rotate|skewx|skewy)\s*\(([^)]*)\)"i, v)
    name, n = lowercase(found[1]), numbers(found[2])
    isempty(n) && continue
    t = if name == "matrix"
      length(n) == 6 ? (n...,) : SAME
    elseif name == "translate"
      shift(n[1], get(n, 2, 0.0))
    elseif name == "scale"
      stretch(n[1], get(n, 2, n[1]))
    elseif name == "rotate"
      r = deg2rad(n[1])
      turn = (cos(r), sin(r), -sin(r), cos(r), 0.0, 0.0)
      length(n) >= 3 ? times(times(shift(n[2], n[3]), turn), shift(-n[2], -n[3])) : turn
    elseif name == "skewx"
      (1.0, 0.0, tand(n[1]), 1.0, 0.0, 0.0)
    else
      (1.0, tand(n[1]), 0.0, 1.0, 0.0, 0.0)
    end
    m = times(m, t)
  end
  m
end

"The number that a length of an SVG is, or nothing: a percent is of `of`, and an em is `em`"
measure(v, of=0.0, em=16.0) = begin
  m = match(r"^\s*([-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?)\s*(px|%|em|rem|pt|pc|mm|cm|in|ex)?\s*$"i, v)
  m === nothing && return nothing
  x = Base.parse(Float64, m[1])
  u = lowercase(something(m[2], "px"))
  u == "%" ? x / 100 * of : u == "em" ? x * em : u == "rem" ? 16x : u == "ex" ? x * em / 2 : u == "pt" ? x * 4 / 3 : u == "pc" ? 16x :
  u == "mm" ? x * 96 / 25.4 : u == "cm" ? x * 96 / 2.54 : u == "in" ? 96x : x
end
"A length that the tag of `e` says, or `default`"
side(e::Element, name, default, of=0.0) = something(measure(attr(e, name), of), default)
"A share that a tag says: `0.5` or `50%`"
share(v, default) = (x = measure(v, 1.0); x === nothing ? default : x)

"What's known while a drawing is drawn"
mutable struct Drawn
  canvas::Any
  look::Any
  ids::Dict{String,Element}        # the elements of the drawing that have a name
  wide::Float64                    # how big the drawing's own space is: a percent is of this
  high::Float64
  via::Union{Style,Nothing}        # the style of the <use> that the shape is drawn for
  depth::Int
end

"The style of `e`, or the style of a plain element when the page gave it none"
style(d::Drawn, e::Element) = (s = get(d.look, e, nothing); s === nothing ? DEFAULT : s)
const DEFAULT = Style()

"""
What the style of `e` says of `name`, like `fill`, or `default`. A shape
that's drawn for a <use> takes what the <use> says, where it says nothing
itself.
"""
said(d::Drawn, e::Element, s::Style, name, default) = begin
  v = get(s.vars, name, nothing)
  if d.via !== nothing && !haskey(e.attrs, name)
    up = e.parent === nothing ? nothing : get(d.look, e.parent, nothing)
    from = up === nothing ? nothing : get(up.vars, name, nothing)
    # What it has from the element round it, it didn't say
    (v === nothing || v == from) && (v = get(d.via.vars, name, v))
  end
  something(v, default)
end

"The address that a tag's `href` names, without its #"
target(e::Element) = lstrip(strip(attr(e, "href", attr(e, "xlink:href"))), '#')
"The element that `url(#name)` names, or nothing"
named(d::Drawn, v) = (m = match(r"url\(\s*[\"']?#([^\"')]+)[\"']?\s*\)"i, v); m === nothing ? nothing : get(d.ids, String(strip(m[1])), nothing))

"What a gradient's tag says of `name`, or what the gradient that it's made from says"
inherited(d::Drawn, g::Element, name, default) = begin
  for _ in 1:8
    haskey(g.attrs, name) && return g.attrs[name]
    next = get(d.ids, target(g), nothing)
    (next === nothing || next === g) && break
    g = next
  end
  default
end

"The colours of a gradient and where each is, from 0 to 1"
stops(d::Drawn, g::Element) = begin
  for _ in 1:8
    found = [k for k in g.children if k isa Element && k.tag == "stop"]
    if !isempty(found)
      colors, places = UInt32[], Float32[]
      for k in found
        s = style(d, k)
        c = colour(get(s.vars, "stop-color", "black"))
        c = c isa UInt32 ? c : c === :current ? s.color : 0xff000000
        a = clamp(something(tryparse(Float64, strip(get(s.vars, "stop-opacity", "1"))), 1.0), 0, 1) * s.opacity
        push!(colors, (c & 0x00ffffff) | UInt32(round(alpha(c) * a * 255)) << 24)
        at = clamp(share(attr(k, "offset"), 0.0), 0, 1)
        push!(places, Float32(isempty(places) ? at : max(at, places[end])))
      end
      return (colors, places)
    end
    next = get(d.ids, target(g), nothing)
    (next === nothing || next === g) && break
    g = next
  end
  (UInt32[], Float32[])
end

"""
Give `paint` the colour or the gradient that `v` writes for a shape with the
style `s`, in the rectangle `box`, `see` see-through. It's false for a shape
that isn't drawn. A shader that it makes is given back to unref.
"""
source!(d::Drawn, paint, v, s::Style, box, see) = begin
  v = strip(v)
  lowercase(v) == "none" && return (false, C_NULL)
  if startswith(lowercase(v), "url(")
    g = named(d, v)
    rest = strip(replace(v, r"^url\([^)]*\)"i => ""))
    if g !== nothing && g.tag in ("lineargradient", "radialgradient")
      colors, places = stops(d, g)
      isempty(colors) && return (false, C_NULL)
      if length(colors) == 1
        Skia.sk_paint_set_color(paint, (colors[1] & 0x00ffffff) | UInt32(round(alpha(colors[1]) * see * 255)) << 24)
        return (true, C_NULL)
      end
      boxed = lowercase(inherited(d, g, "gradientunits", "objectBoundingBox")) != "userspaceonuse"
      m = transform(inherited(d, g, "gradienttransform", ""))
      # A gradient that's measured by its shape goes from 0 to 1 across the shape's rectangle
      boxed && (m = times(times(shift(box[1], box[2]), stretch(max(box[3], 1e-9), max(box[4], 1e-9))), m))
      w, h = boxed ? (1.0, 1.0) : (d.wide, d.high)
      at(name, default, of) = something(measure(inherited(d, g, name, default), of), 0.0)
      spread = lowercase(inherited(d, g, "spreadmethod", "pad"))
      mode = Skia.sk_tile_mode_t(spread == "repeat" ? 1 : spread == "reflect" ? 2 : 0)
      shader = if g.tag == "lineargradient"
        points = [Skia.sk_point_t(Float32(at("x1", "0%", w)), Float32(at("y1", "0%", h))), Skia.sk_point_t(Float32(at("x2", "100%", w)), Float32(at("y2", "0%", h)))]
        Skia.sk_shader_new_linear_gradient(points, colors, places, Cint(length(colors)), mode, skia(m))
      else
        cx, cy = at("cx", "50%", w), at("cy", "50%", h)
        r = at("r", "50%", boxed ? 1.0 : hypot(w, h) / sqrt(2))
        fx, fy = something(measure(inherited(d, g, "fx", ""), w), cx), something(measure(inherited(d, g, "fy", ""), h), cy)
        Skia.sk_shader_new_two_point_conical_gradient(Ref(Skia.sk_point_t(Float32(fx), Float32(fy))), 0f0, Ref(Skia.sk_point_t(Float32(cx), Float32(cy))), Float32(r),
                                                       colors, places, Cint(length(colors)), mode, skia(m))
      end
      shader == C_NULL && return (false, C_NULL)
      Skia.sk_paint_set_color(paint, UInt32(round(clamp(see, 0, 1) * 255)) << 24 | 0x00ffffff)
      Skia.sk_paint_set_shader(paint, shader)
      return (true, shader)
    end
    # What can't be drawn has a colour after it to stand in, or nothing
    isempty(rest) && return (false, C_NULL)
    v = rest
  end
  c = colour(v)
  c = c isa UInt32 ? c : c === :current ? s.color : nothing
  c === nothing && return (false, C_NULL)
  a = alpha(c) * see
  a <= 0 && return (false, C_NULL)
  Skia.sk_paint_set_color(paint, (c & 0x00ffffff) | UInt32(round(clamp(a, 0, 1) * 255)) << 24)
  (true, C_NULL)
end

number(v, default) = something(tryparse(Float64, strip(v)), default)

"Draw the Skia path `path` as the style of `e` says: filled, and with a line round it"
ink(d::Drawn, e::Element, s::Style, path) = begin
  s.visible || return
  bounds = Ref(Skia.sk_rect_t(0f0, 0f0, 0f0, 0f0))
  Skia.sk_path_get_bounds(path, bounds)
  box = (Float64(bounds[].left), Float64(bounds[].top), Float64(bounds[].right - bounds[].left), Float64(bounds[].bottom - bounds[].top))
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  ok, shader = source!(d, paint, said(d, e, s, "fill", "black"), s, box, clamp(number(said(d, e, s, "fill-opacity", "1"), 1.0), 0, 1))
  if ok
    Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(0))
    Skia.sk_path_set_filltype(path, Skia.sk_path_fill_type_t(lowercase(said(d, e, s, "fill-rule", "nonzero")) == "evenodd" ? 1 : 0))
    Skia.sk_canvas_draw_path(d.canvas, path, paint)
  end
  shader == C_NULL || Skia.sk_shader_unref(shader)
  Skia.sk_paint_delete(paint)
  wide = something(measure(said(d, e, s, "stroke-width", "1"), hypot(d.wide, d.high) / sqrt(2), s.size), 1.0)
  wide > 0 || return
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  ok, shader = source!(d, paint, said(d, e, s, "stroke", "none"), s, box, clamp(number(said(d, e, s, "stroke-opacity", "1"), 1.0), 0, 1))
  if ok
    Skia.sk_paint_set_style(paint, Skia.sk_paint_style_t(1))
    Skia.sk_paint_set_stroke_width(paint, Float32(wide))
    cap = lowercase(said(d, e, s, "stroke-linecap", "butt"))
    Skia.sk_paint_set_stroke_cap(paint, Skia.sk_stroke_cap_t(cap == "round" ? 1 : cap == "square" ? 2 : 0))
    join = lowercase(said(d, e, s, "stroke-linejoin", "miter"))
    Skia.sk_paint_set_stroke_join(paint, Skia.sk_stroke_join_t(join == "round" ? 1 : join == "bevel" ? 2 : 0))
    Skia.sk_paint_set_stroke_miter(paint, Float32(number(said(d, e, s, "stroke-miterlimit", "4"), 4.0)))
    dash = numbers(said(d, e, s, "stroke-dasharray", "none"))
    effect = C_NULL
    if !isempty(dash) && any(>(0), dash)
      isodd(length(dash)) && (dash = [dash; dash])
      effect = Skia.sk_path_effect_create_dash(Float32.(dash), Cint(length(dash)), Float32(something(measure(said(d, e, s, "stroke-dashoffset", "0")), 0.0)))
      Skia.sk_paint_set_path_effect(paint, effect)
    end
    Skia.sk_canvas_draw_path(d.canvas, path, paint)
    effect == C_NULL || Skia.sk_path_effect_unref(effect)
  end
  shader == C_NULL || Skia.sk_shader_unref(shader)
  Skia.sk_paint_delete(paint)
  nothing
end

"The Skia path of the shape `e`, or nothing when `e` is no shape. The caller deletes it."
shape(d::Drawn, e::Element) = begin
  tag = e.tag
  w, h = d.wide, d.high
  p = Skia.sk_path_new()
  if tag == "path"
    Skia.sk_path_parse_svg_string(p, attr(e, "d")) || (Skia.sk_path_delete(p); return nothing)
  elseif tag == "rect"
    x, y, rw, rh = side(e, "x", 0.0, w), side(e, "y", 0.0, h), side(e, "width", 0.0, w), side(e, "height", 0.0, h)
    (rw > 0 && rh > 0) || (Skia.sk_path_delete(p); return nothing)
    rx, ry = measure(attr(e, "rx"), w), measure(attr(e, "ry"), h)
    rx === nothing && (rx = ry)
    ry === nothing && (ry = rx)
    rx === nothing || rx <= 0 || ry <= 0 ? Skia.sk_path_add_rect(p, rect(x, y, rw, rh), Skia.SK_PATH_DIRECTION_CW) :
      Skia.sk_path_add_rounded_rect(p, rect(x, y, rw, rh), Float32(min(rx, rw / 2)), Float32(min(ry, rh / 2)), Skia.SK_PATH_DIRECTION_CW)
  elseif tag == "circle"
    r = side(e, "r", 0.0, hypot(w, h) / sqrt(2))
    r > 0 || (Skia.sk_path_delete(p); return nothing)
    Skia.sk_path_add_circle(p, Float32(side(e, "cx", 0.0, w)), Float32(side(e, "cy", 0.0, h)), Float32(r), Skia.SK_PATH_DIRECTION_CW)
  elseif tag == "ellipse"
    rx, ry = side(e, "rx", 0.0, w), side(e, "ry", 0.0, h)
    (rx > 0 && ry > 0) || (Skia.sk_path_delete(p); return nothing)
    cx, cy = side(e, "cx", 0.0, w), side(e, "cy", 0.0, h)
    Skia.sk_path_add_oval(p, rect(cx - rx, cy - ry, 2rx, 2ry), Skia.SK_PATH_DIRECTION_CW)
  elseif tag == "line"
    Skia.sk_path_move_to(p, Float32(side(e, "x1", 0.0, w)), Float32(side(e, "y1", 0.0, h)))
    Skia.sk_path_line_to(p, Float32(side(e, "x2", 0.0, w)), Float32(side(e, "y2", 0.0, h)))
  elseif tag in ("polyline", "polygon")
    n = numbers(attr(e, "points"))
    length(n) >= 4 || (Skia.sk_path_delete(p); return nothing)
    Skia.sk_path_move_to(p, Float32(n[1]), Float32(n[2]))
    for i in 3:2:length(n)-1
      Skia.sk_path_line_to(p, Float32(n[i]), Float32(n[i+1]))
    end
    tag == "polygon" && Skia.sk_path_close(p)
  else
    Skia.sk_path_delete(p)
    return nothing
  end
  p
end

"Cut what's drawn next to the shapes of the <clipPath> `c`"
cut!(d::Drawn, c::Element) = begin
  all = Skia.sk_path_new()
  for k in c.children
    k isa Element || continue
    one = k.tag == "use" ? (t = get(d.ids, target(k), nothing); t === nothing ? nothing : shape(d, t)) : shape(d, k)
    one === nothing && continue
    m = transform(attr(k, "transform"))
    k.tag == "use" && (m = times(m, shift(side(k, "x", 0.0, d.wide), side(k, "y", 0.0, d.high))))
    m == SAME || Skia.sk_path_transform(one, skia(m))
    Skia.sk_path_add_path(all, one, Skia.sk_path_add_mode_t(0))
    Skia.sk_path_delete(one)
  end
  m = transform(attr(c, "transform"))
  m == SAME || Skia.sk_path_transform(all, skia(m))
  Skia.sk_canvas_clip_path_with_operation(d.canvas, all, Skia.SK_CLIP_OP_INTERSECT, true)
  Skia.sk_path_delete(all)
end

"The four numbers of a tag's `viewBox`, or nothing"
viewbox(e::Element) = (n = numbers(attr(e, "viewbox")); length(n) == 4 && n[3] > 0 && n[4] > 0 ? (n[1], n[2], n[3], n[4]) : nothing)

"The move that puts the space `view` of a drawing in a rectangle `w` by `h`, as the tag's `preserveAspectRatio` says"
fitted(e::Element, view, w, h) = begin
  how = lowercase(strip(attr(e, "preserveaspectratio", "xMidYMid meet")))
  sx, sy = w / view[3], h / view[4]
  if !startswith(how, "none")
    sx = sy = occursin("slice", how) ? max(sx, sy) : min(sx, sy)
  end
  ax, ay = sits(how)
  times(shift((w - view[3] * sx) * ax, (h - view[4] * sy) * ay), times(stretch(sx, sy), shift(-view[1], -view[2])))
end

"Where a tag's `preserveAspectRatio` puts a drawing in a box of another shape: how far across and how far down, from 0 to 1"
sits(how) = (occursin("xmin", how) ? 0.0 : occursin("xmax", how) ? 1.0 : 0.5, occursin("ymin", how) ? 0.0 : occursin("ymax", how) ? 1.0 : 0.5)

"""
How a picture of the <svg> `e`, `w` by `h` px, keeps its shape in a box of
another shape, as a browser draws an SVG file in an <img>: where it sits
across and down the box, from 0 to 1, and whether it covers the box and is
cut off. Nothing for a drawing that's stretched to the box as a photo is: one
with no `viewBox`, or whose tag says `none`.
"""
kept(e::Element, w, h) = begin
  view = viewbox(e)
  how = lowercase(strip(attr(e, "preserveaspectratio", "xMidYMid meet")))
  (view === nothing || startswith(how, "none")) && return nothing
  # A picture with another shape than the drawing's space has bands beside the drawing already, so it's left as it is
  abs(w * view[4] - h * view[3]) > 0.01 * h * view[3] && return nothing
  (sits(how)..., occursin("slice", how))
end

"Draw the letters of `chars` in the font of the style `s`, with the first at `x` on the line at `y`. It gives how wide they are."
letters(d::Drawn, e::Element, s::Style, chars, x, y) = begin
  f = font(s.family, s.size, s.weight, s.italic, s.stretch)
  widths = advances(f, chars)
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  ok, shader = source!(d, paint, said(d, e, s, "fill", "black"), s, (x, y - s.size, sum(widths; init=0.0), s.size), clamp(number(said(d, e, s, "fill-opacity", "1"), 1.0), 0, 1))
  if ok && s.visible
    at = 0.0
    i = 1
    while i <= length(chars)
      use, id, _ = drawn(f, chars[i])
      ids, xs = UInt16[], Float32[]
      start = at
      # A run of letters that one font has
      while i <= length(chars)
        other, id, _ = drawn(f, chars[i])
        other === use || break
        id == 0 || (push!(ids, id); push!(xs, Float32(at - start)))
        at += widths[i]
        i += 1
      end
      isempty(ids) && continue
      builder = Skia.sk_textblob_builder_new()
      run = unsafe_load(Skia.sk_textblob_builder_alloc_run_pos_h(builder, use.raw, Cint(length(ids)), 0f0, C_NULL))
      GC.@preserve ids xs begin
        unsafe_copyto!(run.glyphs, pointer(ids), length(ids))
        unsafe_copyto!(run.pos, pointer(xs), length(xs))
      end
      blob = Skia.sk_textblob_builder_make(builder)
      Skia.sk_textblob_builder_delete(builder)
      Skia.sk_canvas_draw_text_blob(d.canvas, blob, Float32(x + start), Float32(y), paint)
      Skia.sk_textblob_unref(blob)
    end
  end
  shader == C_NULL || Skia.sk_shader_unref(shader)
  Skia.sk_paint_delete(paint)
  sum(widths; init=0.0)
end

"All the text in `e`, with each run of spaces as one"
words(e::Element) = replace(join(k isa Text ? k.text : k.tag in ("tspan", "textpath", "a") ? words(k) : "" for k in e.children), r"\s+" => " ")
"How wide the text in `e` is, as its styles say"
breadth(d::Drawn, e::Element) = begin
  s = style(d, e)
  f = font(s.family, s.size, s.weight, s.italic, s.stretch)
  sum(k isa Text ? sum(advances(f, collect(replace(k.text, r"\s+" => " "))); init=0.0) : k.tag in ("tspan", "textpath", "a") ? breadth(d, k) : 0.0 for k in e.children; init=0.0)
end

"Draw the text of `e`, a <text> or a part of one. `pen` is where the next letter goes."
text!(d::Drawn, e::Element, pen::Ref{Tuple{Float64,Float64}}, fresh::Ref{Bool}) = begin
  s = style(d, e)
  s.display == :none && return
  x, y = pen[]
  xs, ys = numbers(attr(e, "x")), numbers(attr(e, "y"))
  placed = !isempty(xs)
  isempty(xs) || (x = something(measure(first(split(strip(attr(e, "x")), r"[\s,]+")), d.wide, s.size), xs[1]))
  isempty(ys) || (y = something(measure(first(split(strip(attr(e, "y")), r"[\s,]+")), d.high, s.size), ys[1]))
  x += something(measure(attr(e, "dx"), d.wide, s.size), 0.0)
  y += something(measure(attr(e, "dy"), d.high, s.size), 0.0)
  if placed || e.tag == "text"
    # Text that says where it starts can have its middle or its end there
    anchor = lowercase(said(d, e, s, "text-anchor", "start"))
    anchor == "middle" ? (x -= breadth(d, e) / 2) : anchor == "end" ? (x -= breadth(d, e)) : nothing
    fresh[] = true
  end
  base = lowercase(said(d, e, s, "dominant-baseline", get(s.vars, "alignment-baseline", "auto")))
  lift = base in ("middle", "central") ? 0.35 * s.size : base in ("hanging", "text-before-edge", "text-top") ? 0.8 * s.size : 0.0
  pen[] = (x, y)
  for k in e.children
    if k isa Text
      t = replace(k.text, r"\s+" => " ")
      # No space starts a line of text
      fresh[] && (t = lstrip(t))
      isempty(t) && continue
      fresh[] = false
      x, y = pen[]
      pen[] = (x + letters(d, e, s, collect(t), x, y + lift), y)
    elseif k.tag in ("tspan", "textpath", "a")
      text!(d, k, pen, fresh)
    end
  end
end

"Draw the element `e` of a drawing, and what's in it"
render(d::Drawn, e::Element) = begin
  d.depth > 40 && return
  tag = e.tag
  tag in ("defs", "symbol", "clippath", "mask", "lineargradient", "radialgradient", "pattern", "marker", "style", "title", "desc", "metadata", "filter",
          "script", "foreignobject") && return
  s = style(d, e)
  (s.display == :none || s.opacity <= 0) && return
  canvas = d.canvas
  Skia.sk_canvas_save(canvas)
  m = transform(attr(e, "transform"))
  m == SAME || Skia.sk_canvas_concat(canvas, skia(m))
  if !isempty(s.clippath)
    c = named(d, s.clippath)
    c === nothing || c.tag != "clippath" || cut!(d, c)
  end
  faded = s.opacity < 1
  faded && Skia.sk_canvas_save_layer_alpha(canvas, C_NULL, round(UInt8, clamp(s.opacity, 0, 1) * 255))
  d.depth += 1
  if tag in ("g", "a", "switch")
    for k in e.children
      k isa Element && render(d, k)
    end
  elseif tag == "svg"
    inner!(d, e, side(e, "x", 0.0, d.wide), side(e, "y", 0.0, d.high), side(e, "width", d.wide, d.wide), side(e, "height", d.high, d.high))
  elseif tag == "use"
    t = get(d.ids, target(e), nothing)
    if t !== nothing && t !== e
      Skia.sk_canvas_translate(canvas, Float32(side(e, "x", 0.0, d.wide)), Float32(side(e, "y", 0.0, d.high)))
      was = d.via
      d.via = s
      if t.tag in ("symbol", "svg")
        inner!(d, t, 0.0, 0.0, side(e, "width", side(t, "width", d.wide, d.wide), d.wide), side(e, "height", side(t, "height", d.high, d.high), d.high))
      else
        render(d, t)
      end
      d.via = was
    end
  elseif tag == "text"
    text!(d, e, Ref((0.0, 0.0)), Ref(true))
  else
    p = shape(d, e)
    if p !== nothing
      ink(d, e, s, p)
      Skia.sk_path_delete(p)
    end
  end
  d.depth -= 1
  faded && Skia.sk_canvas_restore(canvas)
  Skia.sk_canvas_restore(canvas)
  nothing
end

"Draw what's in the <svg> or the <symbol> `e`, in a rectangle `w` by `h` whose corner is at `(x, y)`"
inner!(d::Drawn, e::Element, x, y, w, h) = begin
  (w > 0 && h > 0) || return
  canvas = d.canvas
  Skia.sk_canvas_save(canvas)
  view = viewbox(e)
  wide, high = d.wide, d.high
  Skia.sk_canvas_translate(canvas, Float32(x), Float32(y))
  lowercase(get(style(d, e).vars, "overflow", "")) == "visible" || e.tag == "symbol" ||
    Skia.sk_canvas_clip_rect_with_operation(canvas, rect(0, 0, w, h), Skia.SK_CLIP_OP_INTERSECT, true)
  if view === nothing
    d.wide, d.high = w, h
  else
    Skia.sk_canvas_concat(canvas, skia(fitted(e, view, w, h)))
    d.wide, d.high = view[3], view[4]
  end
  for k in e.children
    k isa Element && render(d, k)
  end
  d.wide, d.high = wide, high
  Skia.sk_canvas_restore(canvas)
  nothing
end

"The elements in `e` that have a name, by their names"
names(e::Element) = begin
  out = Dict{String,Element}()
  walk(e) do k
    id = attr(k, "id")
    isempty(id) || haskey(out, id) || (out[id] = k)
  end
  out
end

# The names of each drawing that's been drawn, so that they're found once
const NAMED = IdDict{Element,Dict{String,Element}}()
__init__() = empty!(NAMED)

"""
Draw the <svg> element `e` in the rectangle `(x, y, w, h)` of the canvas.
`look` gives the style of each element of the page.
"""
draw(canvas, e::Element, look, x, y, w, h) = begin
  # A shape can be named anywhere in the page
  top = e
  while top.parent !== nothing
    top = top.parent
  end
  length(NAMED) > 8 && empty!(NAMED)
  ids = get!(() -> names(top), NAMED, top)
  d = Drawn(canvas, look, ids, w, h, nothing, 0)
  inner!(d, e, x, y, w, h)
end

"How big the tag of the <svg> `e` says its drawing is: a width or a height that it doesn't give is from the shape of its space, or 300 by 150"
natural(e::Element) = begin
  w, h = measure(attr(e, "width")), measure(attr(e, "height"))
  occursin('%', attr(e, "width")) && (w = nothing)
  occursin('%', attr(e, "height")) && (h = nothing)
  view = viewbox(e)
  w !== nothing && h !== nothing ? (w, h) : view === nothing ? (something(w, 300.0), something(h, 150.0)) :
  w !== nothing ? (w, w * view[4] / view[3]) : h !== nothing ? (h * view[3] / view[4], h) : (view[3], view[4])
end

"""
A picture of the SVG file with the bytes `bytes`: its width and its height in
px, Skia's picture of it with `scale` pixels to the px, and how it keeps its
shape in a box of another shape (see `kept`). Nothing when the bytes are no
SVG.
"""
image(bytes; scale=2.0, most=2048) = begin
  doc = try document(String(copy(bytes))) catch; return nothing end
  top = Ref{Any}(nothing)
  walk(k -> top[] === nothing && k.tag == "svg" && (top[] = k), doc.root)
  e = top[]
  e === nothing && return nothing
  w, h = natural(e)
  (w > 0 && h > 0) || return nothing
  look = styles(doc, w; high=h)
  k = min(scale, most / max(w, h))
  pw, ph = max(1, ceil(Int, w * k)), max(1, ceil(Int, h * k))
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, pw, ph))
  made = GC.@preserve info begin
    surface = Skia.sk_surface_make_raster_n32_premul(pointer_from_objref(info), C_NULL)
    surface == C_NULL && return nothing
    canvas = Skia.sk_surface_get_canvas(surface)
    Skia.sk_canvas_clear(canvas, 0x00000000)
    Skia.sk_canvas_scale(canvas, Float32(pw / w), Float32(ph / h))
    inner!(Drawn(canvas, look, names(doc.root), w, h, nothing, 0), e, 0.0, 0.0, w, h)
    out = Skia.sk_surface_make_image_snapshot(surface)
    Skia.sk_surface_unref(surface)
    out
  end
  made == C_NULL ? nothing : (w, h, Ptr{Cvoid}(made), kept(e, w, h))
end
