# Drawing by hand for the design editor: lines, arcs and words over the
# picture of a design, and the editor's own icons.
#
#     line(ctx, (10, 10), (90, 40), colour, 1.5)
#     arc(ctx, (50, 50), 20, 0, 90, colour, 1.5)      # from 0° a quarter turn, clockwise on the screen
#     words(ctx, "45.00 mm", 50, 50, 12, colour, at=:middle)
#     icon(ctx, "extrude", 8, 8, 24, ink, accent)
#
# Every place is in px of the window, as a plain number.
#
# An icon is drawn on a grid of 24 by 24 from two outlines, written as SVG
# writes a path: one that's filled with the accent colour, and one that's
# drawn as lines in the colour of text. `Glyph("extrude")` is a node that
# shows one. A name that this file doesn't draw is one of the Bootstrap icons
# that UI.jl has, like "eye" or "folder".

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" flt
@use "github.com/jkroso/MiniFB.jl/skia" measure_text sk_color
@use "github.com/jkroso/Font.jl" ["units" px]
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe theme inputs
@use "github.com/jkroso/UI.jl/Interface/draw" draw
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" load_icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/SVG" render_svg
@use Colors: Colorant, RGBA, RGB, red, green, blue, alpha
@use Skia

f(x) = Float32(x)

"`colour` with `a` times its own opacity"
faded(colour::Colorant, a) = RGBA(red(colour), green(colour), blue(colour), alpha(colour) * a)

"""
A colour between `a` and `b`: `t` of the way to `b`. It works in Float64,
because a colour from `colorant"…"`, as Ladder's themes are, has 8-bit parts,
and with those 0 - 0.97 wraps round to 0.03.
"""
mixed(a::Colorant, b::Colorant, t) = begin
  a, b = RGB{Float64}(a), RGB{Float64}(b)
  RGBA(red(a) + (red(b) - red(a)) * t, green(a) + (green(b) - green(a)) * t, blue(a) + (blue(b) - blue(a)) * t, 1.0)
end

"How bright a colour is, from 0 to 1"
bright(c::Colorant) = 0.299red(c) + 0.587green(c) + 0.114blue(c)

"A paint of `colour`: one that fills, or with `width` over 0 one that draws lines that wide. `dash` is how long each dash and each gap is."
paint(colour::Colorant; width=0.0, dash=nothing) = begin
  p = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(p, true)
  Skia.sk_paint_set_color(p, sk_color(convert(RGBA{Float64}, colour)))
  if width > 0
    Skia.sk_paint_set_style(p, Skia.sk_paint_style_t(1))
    Skia.sk_paint_set_stroke_width(p, f(width))
    Skia.sk_paint_set_stroke_cap(p, Skia.SK_STROKE_CAP_ROUND)
    Skia.sk_paint_set_stroke_join(p, Skia.sk_stroke_join_t(1))
    if dash !== nothing
      lengths = Float32[dash[1], dash[2]]
      effect = Skia.sk_path_effect_create_dash(lengths, Int32(2), 0f0)
      Skia.sk_paint_set_path_effect(p, effect)
      Skia.sk_path_effect_unref(effect)
    end
  end
  p
end

"Draw with a paint, and free it after"
painted(draw, colour; kw...) = (p = paint(colour; kw...); try draw(p) finally Skia.sk_paint_delete(p) end; nothing)

line(ctx, a, b, colour, width=1.0; dash=nothing) = through(ctx, (a, b), colour, width; dash)

"A line through `points`. With `fill` it's closed and filled."
through(ctx, points, colour, width=1.0; closed=false, fill=false, dash=nothing) = begin
  length(points) < 2 && return
  shape = Skia.sk_path_new()
  Skia.sk_path_move_to(shape, f(points[1][1]), f(points[1][2]))
  for i in 2:length(points)
    Skia.sk_path_line_to(shape, f(points[i][1]), f(points[i][2]))
  end
  (closed || fill) && Skia.sk_path_close(shape)
  painted(p -> Skia.sk_canvas_draw_path(ctx, shape, p), colour; width=fill ? 0.0 : width, dash)
  Skia.sk_path_delete(shape)
end

"A circle round `c`. With no `width` it's filled."
circle(ctx, c, r, colour, width=0.0; dash=nothing) = painted(p -> Skia.sk_canvas_draw_circle(ctx, f(c[1]), f(c[2]), f(r), p), colour; width, dash)

"A part of a circle round `c`: from the angle `from`, in degrees clockwise from 3 o'clock, `sweep` degrees on"
arc(ctx, c, r, from, sweep, colour, width=1.0; dash=nothing) = begin
  shape = Skia.sk_path_new()
  oval = Ref(Skia.sk_rect_t(f(c[1] - r), f(c[2] - r), f(c[1] + r), f(c[2] + r)))
  abs(sweep) >= 360 ? Skia.sk_path_add_circle(shape, f(c[1]), f(c[2]), f(r), Skia.SK_PATH_DIRECTION_CW) :
                      Skia.sk_path_arc_to_with_oval(shape, oval, f(from), f(sweep), true)
  painted(p -> Skia.sk_canvas_draw_path(ctx, shape, p), colour; width, dash)
  Skia.sk_path_delete(shape)
end

"A box with round corners. With no `width` it's filled."
box(ctx, x, y, w, h, colour; radius=0.0, width=0.0) = begin
  shape = Skia.sk_path_new()
  Skia.sk_path_add_rounded_rect(shape, Ref(Skia.sk_rect_t(f(x), f(y), f(x + w), f(y + h))), f(radius), f(radius), Skia.SK_PATH_DIRECTION_CW)
  painted(p -> Skia.sk_canvas_draw_path(ctx, shape, p), colour; width)
  Skia.sk_path_delete(shape)
end

"How wide `text` is at `size` px"
wide(text, size; family="Helvetica", style="") = Float64(measure_text(skia_font(family, px(size), style), text)[1])

"""
Write `text` at `size` px. `at` says what `(x, y)` is of the words: `:left`
their left end, `:middle` their middle, `:right` their right end. `y` is the
middle of their height.
"""
words(ctx, text, x, y, size, colour; at=:left, family="Helvetica", style="") = begin
  isempty(text) && return
  font = skia_font(family, px(size), style)
  w = at == :left ? 0.0 : Float64(measure_text(font, text)[1])
  left = at == :middle ? x - w / 2 : at == :right ? x - w : x
  blob = Skia.sk_textblob_make_from_string(text, font.raw, Skia.SK_TEXT_ENCODING_UTF8)
  blob == C_NULL && return
  painted(p -> Skia.sk_canvas_draw_text_blob(ctx, blob, f(left), f(y + 0.36size), p), colour)
  Skia.sk_textblob_unref(blob)
end

# --- icons ----------------------------------------------------------------------------

ring(x, y, r) = "M$(x - r) $y a$r $r 0 1 0 $(2r) 0 a$r $r 0 1 0 $(-2r) 0 Z"
oval(x, y, rx, ry) = "M$(x - rx) $y a$rx $ry 0 1 0 $(2rx) 0 a$rx $ry 0 1 0 $(-2rx) 0 Z"

"Each icon: what's filled with the accent colour, and what's drawn as lines"
const ICONS = Dict{String,NTuple{2,String}}(
  "sketch" => ("M7 17 L12 8 L17 17 Z", "M4 4 H20 V20 H4 Z"),
  "extrude" => ("M4 17 L12 13 L20 17 L12 21 Z", "M4 17 L12 13 L20 17 L12 21 Z M12 16 V3 M8 7 L12 3 L16 7"),
  "revolve" => ("M12 7 H18 V17 H12 Z", "M12 2 V22 M12 7 H18 V17 H12 M8 9 A6 4 0 0 0 8 16 M8 16 l-2.5 -1 M8 16 l0.5 -2.8"),
  "hole" => ("M3 7 H9 V19 H3 Z M15 7 H21 V19 H15 Z", "M3 7 H21 M9 7 V19 M15 7 V19 M3 19 H9 M15 19 H21"),
  "fillet" => ("M5 19 V11 A6 6 0 0 1 11 5 H19 V19 Z", "M5 19 V11 A6 6 0 0 1 11 5 H19 V19 Z"),
  "chamfer" => ("M5 19 V11 L11 5 H19 V19 Z", "M5 19 V11 L11 5 H19 V19 Z"),
  "shell" => ("M4 6 H8 V16 H16 V6 H20 V20 H4 Z", "M4 6 H8 V16 H16 V6 H20 V20 H4 Z"),
  "presspull" => ("M4 14 H20 V20 H4 Z", "M4 14 H20 V20 H4 Z M12 11 V3 M9 6 L12 3 L15 6"),
  "move" => ("", "M12 3 V21 M3 12 H21 M9 6 L12 3 L15 6 M9 18 L12 21 L15 18 M6 9 L3 12 L6 15 M18 9 L21 12 L18 15"),
  "mirror" => ("M4 18 L10 6 V18 Z", "M4 18 L10 6 V18 Z M14 18 V6 L20 18 Z M12 2 V5 M12 8 V11 M12 14 V17 M12 20 V22"),
  "pattern_rect" => ("M4 4 H10 V10 H4 Z", "M4 4 H10 V10 H4 Z M14 4 H20 V10 H14 Z M4 14 H10 V20 H4 Z M14 14 H20 V20 H14 Z"),
  "pattern_circ" => (ring(12, 5, 2.6), ring(12, 5, 2.6) * ring(19, 12, 2.6) * ring(12, 19, 2.6) * ring(5, 12, 2.6) * "M12 11 V13 M11 12 H13"),
  "plane" => ("M3 15 L10 6 H21 L14 15 Z", "M3 15 L10 6 H21 L14 15 Z"),
  "axis" => (ring(5, 19, 1.8) * ring(19, 5, 1.8), "M5 19 L19 5"),
  "point" => (ring(12, 12, 3), "M12 3 V8 M12 16 V21 M3 12 H8 M16 12 H21"),
  "box" => ("M12 3 L20 7 L12 11 L4 7 Z", "M12 3 L20 7 V16 L12 21 L4 16 V7 Z M4 7 L12 11 L20 7 M12 11 V21"),
  "cylinder" => (oval(12, 6, 7, 3), oval(12, 6, 7, 3) * "M5 6 V18 a7 3 0 0 0 14 0 V6"),
  "sphere" => (ring(12, 12, 8.5), ring(12, 12, 8.5) * "M3.5 12 a8.5 3.2 0 0 0 17 0"),
  "torus" => (oval(12, 12, 9, 5.5), oval(12, 12, 9, 5.5) * "M8.5 11.5 a3.5 1.6 0 0 0 7 0"),
  "cone" => ("M12 3 L19 18 a7 2.6 0 0 1 -14 0 Z", "M12 3 L19 18 a7 2.6 0 0 1 -14 0 Z M5 18 a7 2.6 0 0 1 14 0"),
  "sweep" => (ring(5, 18, 2.6), ring(5, 18, 2.6) * "M7.5 17 C14 15 9 7 20 5 M17 3.5 L20 5 L18 8"),
  "loft" => (oval(12, 5.5, 4, 2), oval(12, 5.5, 4, 2) * oval(12, 18, 8, 3) * "M8 5.5 L4 18 M16 5.5 L20 18"),
  "combine" => ("M10 10 H15 V15 H10 Z", "M4 4 H15 V15 H4 Z M10 10 H20 V20 H10 Z"),
  "line" => (ring(5, 19, 1.8) * ring(19, 5, 1.8), "M5 19 L19 5"),
  "rect" => ("", "M4 6 H20 V18 H4 Z"),
  "rect_center" => (ring(12, 12, 1.6), "M4 6 H20 V18 H4 Z"),
  "circle" => (ring(12, 12, 1.6), ring(12, 12, 8)),
  "arc3" => (ring(4, 17, 1.6) * ring(20, 17, 1.6), "M4 17 A9.5 9.5 0 0 1 20 17"),
  "polygon" => ("", "M12 3 L20 7.5 V16.5 L12 21 L4 16.5 V7.5 Z"),
  "slot" => ("", "M8 7 H16 a5 5 0 0 1 0 10 H8 a5 5 0 0 1 0 -10 Z"),
  "spline" => ("", "M3 16 C8 0 14 26 21 7"),
  "ellipse" => ("", oval(12, 12, 9, 5.5)),
  "text" => ("", "M6 6 H18 M12 6 V19 M9.5 19 H14.5"),
  "trim" => ("", "M12 3 V21 M3 12 H7 M17 12 H21 M9 10 l-1.5 4 M15 10 l1.5 4"),
  "offset" => ("", "M5 19 V10 a5 5 0 0 1 5 -5 H19 M10 19 V13 a3 3 0 0 1 3 -3 H19"),
  "dimension" => ("", "M4 5 V19 M20 5 V19 M4 12 H20 M7.5 8.5 L4 12 L7.5 15.5 M16.5 8.5 L20 12 L16.5 15.5"),
  "construction" => ("", "M4 20 L7.5 16.5 M10.5 13.5 L13.5 10.5 M16.5 7.5 L20 4"),
  "project" => ("M4 19 L8 14 H20 L16 19 Z", "M4 19 L8 14 H20 L16 19 Z M12 3 V11 M9 8 L12 11 L15 8"),
  "sketch_fillet" => ("", "M5 20 V12 a7 7 0 0 1 7 -7 H20"),
  "c_hv" => ("", "M6 4 V15 M9 19 H20"),
  "c_coincident" => (ring(12, 12, 2.6), ring(12, 12, 7)),
  "c_tangent" => ("", ring(12, 14.5, 6) * "M3 8.5 H21"),
  "c_equal" => ("", "M5 9 H19 M5 15 H19"),
  "c_parallel" => ("", "M5 20 L12 4 M12 20 L19 4"),
  "c_perpendicular" => ("", "M4 19 H20 M12 19 V5"),
  "c_fix" => ("M5 11 H19 V20 H5 Z", "M5 11 H19 V20 H5 Z M8 11 V8 a4 4 0 0 1 8 0 V11"),
  "c_midpoint" => ("M12 14 L8.5 7 H15.5 Z", "M4 16 H20 M12 14 L8.5 7 H15.5 Z"),
  "c_concentric" => ("", ring(12, 12, 8) * ring(12, 12, 4)),
  "c_collinear" => ("", "M3 14 L10 11 M14 9.3 L21 6.3 M4 19 L20 12"),
  "c_symmetry" => ("", "M12 2 V5 M12 8 V11 M12 14 V17 M12 20 V22 M4 8 L8 17 M20 8 L16 17"),
  "measure" => ("", "M3 15 L15 3 L21 9 L9 21 Z M7 14 l2 2 M10 11 l2.5 2.5 M13 8 l2 2"),
  "center_of_mass" => ("M12 12 H4 A8 8 0 0 1 12 4 Z M12 12 H20 A8 8 0 0 1 12 20 Z", ring(12, 12, 8) * "M12 2 V22 M2 12 H22"),
  "section" => ("M12 3 L12 21 L4 16 V7 Z", "M12 3 L20 7 V16 L12 21 L4 16 V7 Z M12 3 V21 M4 7 L12 11 M15 9.5 L20 7"),
  "interference" => ("M10 10 H14 V14 H10 Z", "M4 4 H14 V14 H4 Z M10 10 H20 V20 H10 Z"),
  "properties" => ("M4 5 H7 V8 H4 Z M4 11 H7 V14 H4 Z M4 17 H7 V20 H4 Z", "M10 6.5 H20 M10 12.5 H20 M10 18.5 H17"),
  "params" => ("", "M9 20 C11 20 11 17 11.5 12 C12 6 12 4 15 4 M8 11 H15 M15 14 L20 20 M20 14 L15 20"),
  "feature" => ("M12 3 L20 7 L12 11 L4 7 Z", "M12 3 L20 7 V16 L12 21 L4 16 V7 Z M4 7 L12 11 L20 7 M12 11 V21"),
  "body" => ("M12 3 L20 7 V16 L12 21 L4 16 V7 Z", "M12 3 L20 7 V16 L12 21 L4 16 V7 Z M4 7 L12 11 L20 7 M12 11 V21"),
  "orbit" => ("", "M19.5 9 A8 8 0 1 0 20 13 M20 4 V9 H15"),
  "fit" => ("", "M4 9 V4 H9 M15 4 H20 V9 M20 15 V20 H15 M9 20 H4 V15 M9 9 H15 V15 H9 Z"),
  "perspective" => ("", "M4 8 L20 4 V20 L4 16 Z M12 6 V18"),
  "draft" => ("M6 19 L9 5 H15 L18 19 Z", "M6 19 L9 5 H15 L18 19 Z M3 19 H21"),
  "scale" => ("M4 12 H12 V20 H4 Z", "M4 12 H12 V20 H4 Z M4 4 H20 V20 M14 10 L19 5 M15 5 H19 V9"),
  "split" => ("M4 5 H10 V19 H4 Z", "M4 5 H10 V19 H4 Z M14 5 H20 V19 H14 Z M12 2 V22"),
  "thread" => ("", "M7 4 H17 V20 H7 Z M7 8 L17 6 M7 12 L17 10 M7 16 L17 14"),
  "rib" => ("M6 19 L16 7 V19 Z", "M4 19 H20 M18 4 V19 M6 19 L16 7 V19"),
  "delete" => ("", "M5 7 H19 M9 7 V4 H15 V7 M7 7 L8 20 H16 L17 7 M10.5 10.5 V16.5 M13.5 10.5 V16.5"),
)

# The names of SolidCraft's own icons that this file draws under another name
const SAME_ICON = Dict("arc_center" => "arc3", "arc_tangent" => "arc3", "rect3" => "rect", "rect_rounded" => "slot", "circle2" => "circle", "circle3" => "circle",
  "polygon_circumscribed" => "polygon", "polygon_edge" => "polygon", "slot_center" => "slot", "slot_overall" => "slot", "spline_cv" => "spline",
  "pattern_path" => "pattern_rect", "sketch_rect_pattern" => "pattern_rect", "sketch_circ_pattern" => "pattern_circ", "sketch_mirror" => "mirror",
  "sketch_move" => "move", "sketch_scale" => "scale", "sketch_text" => "text", "split_body" => "split", "split_face" => "split",
  "plane_angle" => "plane", "plane_midplane" => "plane", "plane_tangent" => "plane", "plane_three_points" => "plane", "plane_two_edges" => "plane",
  "plane_axis_point" => "plane", "plane_perpendicular" => "plane", "plane_along_path" => "plane", "plane_auto" => "plane",
  "axis_edge" => "axis", "axis_two_points" => "axis", "axis_two_planes" => "axis", "axis_through_cylinder" => "axis", "axis_normal_to_face" => "axis",
  "point_vertex" => "point", "point_center" => "point", "point_two_edges" => "point", "point_three_planes" => "point", "point_edge_plane" => "point",
  "point_along_path" => "point", "sketch_chamfer" => "chamfer", "offset_face" => "presspull", "pipe" => "sweep", "coil" => "thread",
  "surface_extrude" => "extrude", "surface_revolve" => "revolve", "surface_sweep" => "sweep", "surface_loft" => "loft", "construction_line" => "construction",
  "centerline" => "construction", "line_mid" => "line", "c_smooth" => "c_tangent", "c_polygon" => "polygon", "emboss" => "text", "delete_face" => "delete")

"The name that this file draws for the icon `name`, or nothing when it's none of its own"
own(name) = haskey(ICONS, name) ? name : haskey(SAME_ICON, name) ? SAME_ICON[name] : nothing

"The icon of a step of a design, from the kind of step that SolidCraft names, like ExtrudeFeature"
step_icon(kind::AbstractString) = begin
  k = lowercase(replace(kind, "Feature" => ""))
  k = get(STEP_ICONS, k, k)
  own(k) === nothing ? "feature" : k
end
const STEP_ICONS = Dict("rectangularpattern" => "pattern_rect", "circularpattern" => "pattern_circ", "pathpattern" => "pattern_rect", "presspull" => "presspull",
  "constructionplane" => "plane", "constructionaxis" => "axis", "constructionpoint" => "point", "combine" => "combine", "splitbody" => "split",
  "offsetface" => "presspull", "import" => "body", "base" => "body", "move" => "move")

"Draw the icon `name` in a square of `size` px at `(x, y)`, its lines in the colour `ink` and what it fills in `accent`"
icon(ctx, name, x, y, size, ink::Colorant, accent::Colorant) = begin
  mine = own(name)
  if mine === nothing
    data = try load_icon(name) catch; nothing end
    data === nothing || render_svg(ctx, px(x + 0.1size), px(y + 0.1size), px(0.8size), px(0.8size), data.paths, data.viewbox, ink)
    return
  end
  fill, lines = ICONS[mine]
  Skia.sk_canvas_save(ctx)
  Skia.sk_canvas_translate(ctx, f(x), f(y))
  Skia.sk_canvas_scale(ctx, f(size / 24), f(size / 24))
  for (d, colour, width) in ((fill, faded(accent, 0.85), 0.0), (lines, ink, 1.5 * min(1.0, 24 / max(size, 14) + 0.25)))
    isempty(d) && continue
    shape = Skia.sk_path_new()
    Skia.sk_path_parse_svg_string(shape, d)
    painted(p -> Skia.sk_canvas_draw_path(ctx, shape, p), colour; width)
    Skia.sk_path_delete(shape)
  end
  Skia.sk_canvas_restore(ctx)
end

"A node that shows an icon of the editor"
@def mutable struct Glyph <: SemanticUI
  name::String = ""
  size::px = 18px
  color::Any = nothing    # of its lines: the theme's text colour when nothing
  accent::Any = nothing   # of what it fills: the theme's accent when nothing
end
Glyph(name::AbstractString; kw...) = Glyph(; name=String(name), kw...)

describe(g::Glyph) = Box(width(min=g.size, preferred=g.size), height(min=g.size, preferred=g.size))
inputs(g::Glyph) = (g.name, g.size, g.color, g.accent)
draw(ctx, size, ui::ConcreteRect, g::Glyph) = begin
  t = theme(g)
  icon(ctx, g.name, flt(ui.left), flt(ui.top), flt(ui.width), g.color === nothing ? t.text : g.color, g.accent === nothing ? t.accent : g.accent)
end

"How many seconds the ring of a `Spinner` takes to go round once"
const SPIN_TURN = 0.9

"""
A ring that turns, `size` across, as a sign that something works: a faint
ring with a quarter of it darker, which goes round once in `SPIN_TURN`
seconds. It looks as Ladder's own spinner does. It turns only while the window
draws, so whatever shows it asks for frames.
"""
@def mutable struct Spinner <: SemanticUI
  size::px = 12px
  color::Any = nothing   # the theme's dim colour when nothing
end

describe(s::Spinner) = Box(width(min=s.size, preferred=s.size), height(min=s.size, preferred=s.size), name="Spinner")
draw(ctx, size, ui::ConcreteRect, s::Spinner) = begin
  c = s.color === nothing ? theme(s).dim : s.color
  wide = max(flt(s.size) / 7, 1.5)
  r = (min(flt(ui.width), flt(ui.height)) - wide) / 2
  middle = (flt(ui.left) + flt(ui.width) / 2, flt(ui.top) + flt(ui.height) / 2)
  circle(ctx, middle, r, faded(c, 0.3), wide)
  arc(ctx, middle, r, 360 * mod(time(), SPIN_TURN) / SPIN_TURN, 90, c, wide)
end
