# Lines, shapes and words drawn straight onto a canvas of Skia's: what a takeoff's
# plan, a map, a sketch and a schedule draw with. Each one makes its paint and
# deletes it again.
#
#     trace(ctx, [(0, 0), (40, 20)], colours.ink, 2)   # a line through two places
#     round_box(ctx, 10, 10, 80, 24, 6, fill=colours.float)

@use "github.com/jkroso/MiniFB.jl/skia" sk_color
@use Skia
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font
@use "./look" exports...

export plan_sampling, paint_picture, ink, path_through, trace, write_ink, round_box, disc

"How a picture is drawn bigger or smaller than it is: by straight lines between its pixels"
const plan_sampling = Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0),
                                                 Skia.SK_FILTER_MODE_LINEAR, Skia.SK_MIPMAP_MODE_NONE)

"Draw the part `from` of a picture of Skia's into the part `to` of the window. Each is a left, a top, a width and a height."
paint_picture(ctx, image, from, to) = begin
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  paint_picture(ctx, image, from, to, paint)
  Skia.sk_paint_delete(paint)
end

"The same, drawn with `paint`, which the caller deletes"
paint_picture(ctx, image, from, to, paint) = begin
  a = Ref(Skia.sk_rect_t(Float32(from[1]), Float32(from[2]), Float32(from[1] + from[3]), Float32(from[2] + from[4])))
  b = Ref(Skia.sk_rect_t(Float32(to[1]), Float32(to[2]), Float32(to[1] + to[3]), Float32(to[2] + to[4])))
  Skia.sk_canvas_draw_image_rect(ctx, image, a, b, Ref(plan_sampling), paint, Skia.SRC_RECT_CONSTRAINT_FAST)
end

"A paint for lines `wide` px wide, or for filling when `wide` is 0"
ink(colour, wide=0.0) = begin
  paint = Skia.sk_paint_new()
  Skia.sk_paint_set_antialias(paint, true)
  Skia.sk_paint_set_color(paint, sk_color(colour))
  Skia.sk_paint_set_style(paint, wide > 0 ? Skia.SK_PAINT_STYLE_STROKE : Skia.SK_PAINT_STYLE_FILL)
  if wide > 0
    Skia.sk_paint_set_stroke_width(paint, Float32(wide))
    Skia.sk_paint_set_stroke_join(paint, Skia.SK_STROKE_JOIN_ROUND)
    Skia.sk_paint_set_stroke_cap(paint, Skia.SK_STROKE_CAP_ROUND)
  end
  paint
end

"Skia's path through the places `ps`. `closed` joins its end to its start."
path_through(ps, closed) = begin
  shape = Skia.sk_path_new()
  for (i, (x, y)) in enumerate(ps)
    i == 1 ? Skia.sk_path_move_to(shape, Float32(x), Float32(y)) : Skia.sk_path_line_to(shape, Float32(x), Float32(y))
  end
  closed && Skia.sk_path_close(shape)
  shape
end

"""
Draw a line through the places `ps`. `fill` colours what's inside it, but not
what's inside one of the outlines `holes`. `closed` joins its end to its start.
`dashed` draws it in dashes.
"""
trace(ctx, ps, colour, wide; fill=nothing, closed=false, holes=(), dashed=false) = begin
  length(ps) < 2 && return
  shape = path_through(ps, closed)
  if fill !== nothing
    paint = ink(fill)
    Skia.sk_canvas_save(ctx)
    for hole in holes
      length(hole) < 3 && continue
      cut = path_through(hole, true)
      Skia.sk_canvas_clip_path_with_operation(ctx, cut, Skia.SK_CLIP_OP_DIFFERENCE, true)
      Skia.sk_path_delete(cut)
    end
    Skia.sk_canvas_draw_path(ctx, shape, paint)
    Skia.sk_canvas_restore(ctx)
    Skia.sk_paint_delete(paint)
  end
  paint = ink(colour, wide)
  if dashed
    dashes = Float32[6, 5]
    effect = Skia.sk_path_effect_create_dash(dashes, Cint(2), 0f0)
    Skia.sk_paint_set_path_effect(paint, effect)
    Skia.sk_path_effect_unref(effect)
  end
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(shape)
end

"Write `words` on the canvas, with their left end at `x` and the line that they stand on at `y`"
write_ink(ctx, words, x, y, face::Face) = begin
  paint = ink(face.color)
  blob = Skia.sk_textblob_make_from_string(words, skia_font(face.family, face.size, face.style).raw, Skia.SK_TEXT_ENCODING_UTF8)
  Skia.sk_canvas_draw_text_blob(ctx, blob, Float32(x), Float32(y), paint)
  Skia.sk_textblob_unref(blob)
  Skia.sk_paint_delete(paint)
end

"Draw a box whose corners have the radius `r`. `fill` colours it in, and `line` draws its edge, `wide` px wide."
round_box(ctx, x, y, w, h, r; fill=nothing, line=nothing, wide=1.0) = begin
  shape = Skia.sk_path_new()
  rect = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))
  Skia.sk_path_add_rounded_rect(shape, rect, Float32(r), Float32(r), Skia.SK_PATH_DIRECTION_CW)
  for paint in ((fill === nothing ? () : (ink(fill),))..., (line === nothing ? () : (ink(line, wide),))...)
    Skia.sk_canvas_draw_path(ctx, shape, paint)
    Skia.sk_paint_delete(paint)
  end
  Skia.sk_path_delete(shape)
end

"Draw a filled circle"
disc(ctx, x, y, r, colour) = begin
  paint = ink(colour)
  Skia.sk_canvas_draw_circle(ctx, Float32(x), Float32(y), Float32(r), paint)
  Skia.sk_paint_delete(paint)
end
