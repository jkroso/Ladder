# The view of a `sketch` block
#
# A code block in the language `sketch` is a drawing. sketch.jl says how the
# block is written. You draw in it where it is in the page. Only the button
# that shows beside its top right corner while the mouse is over it makes it
# fill the window, where it has more room. A click or a pinch never does. A
# page that can't change shows only the drawing. The buttons at its top choose
# a tool: the arrow selects a shape, and the others draw by hand, a line, an
# arrow, a box, an oval or words. The dots after them choose the colour of the
# next shape, or of the shape that's selected.
#
#   - Drag in the sketch to draw with the tool. For words, click where they
#     go and type them there. Return, or a click somewhere else, adds them,
#     and Esc leaves them out.
#   - Click words twice with the arrow, or once with the tool for words, to
#     change them where they are. Esc leaves them as they were, and words
#     with nothing left in them are taken away.
#   - With the arrow, click a shape to select it, and drag it to move it.
#     Delete takes the selected shape away.
#   - The shape that's selected glows, and has a circle on each place that
#     changes it: the ends of a line, each place of a line drawn by hand, the
#     corners of a box and the middle of each side of an oval. Drag a circle
#     to move that place.
#   - After the dots come the numbers that say how a shape is drawn: how thick
#     its line is, how round the corners of a box are, and how big words are.
#     The buttons each side of a number change it, for the shape that's
#     selected, or for the shapes that the tool draws next. Click a number
#     to type another, and press Return.
#   - The sketch gets taller when a shape is near its bottom edge. In the
#     page, the wheel scrolls the page past it.
#   - Esc chooses the arrow tool. With that tool, Esc gives the keyboard back
#     to the page's text, or puts a sketch that fills the window back in the
#     page. So does the last button there.
#
# Each shape is a line of the block, so the file holds the whole drawing, and
# ⌘Z takes back the last thing you drew.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" tabbed!
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor redraw_in! MouseScroll Pinch onpinch with_clip
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon icon_cache
@use "github.com/jkroso/UI.jl/Interface/Semantic/SVG" SVGPath
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./pictures" picture
@use "./markdown" words
@use "./sheet" parts
@use "./sketch" => Sketches
@use Colors: RGBA
@use "./base" exports...

export SKETCH, SKETCH_TOOLS, SKETCH_SETTINGS, SKETCH_BAR, HANDLE, HANDLE_REACH, ROUND_CORNER, sketch_icon,
       SketchView, SketchArea, InkDot, sketch_colour, sketch_area, sketch_input, sketch_room, sketch_scale,
       picked_shape, new_shape, shown_settings, setting, most, stepped, number_input, set_setting!,
       settle_number!, stepper, sketch_place, sketch_measure, narrow, draw_curve, draw_shape, handle_under,
       draw_handles, edited_shape, typed_shape, typed_index, type_words!, draw_typing, sketch_html

const SKETCH = Sketches.SKETCH
"The tools of a sketch: the icon of each one's button, and what the button's tooltip says"
const SKETCH_TOOLS = ((:select, "cursor", "Select a shape, and drag it to move it"), (:pen, "pencil", "Draw by hand"),
                      (:line, "slash-lg", "Draw a line"), (:arrow, "arrow-up-right", "Draw an arrow"), (:box, "square", "Draw a box"),
                      (:oval, "circle", "Draw an oval"), (:text, "type", "Write words: click where they go, and type them there"))
push!(BLOCK_ICONS, "pencil", "slash-lg", "arrow-up-right", "square", "circle", "type", "trash", "cursor",
      "border-width", "fonts", "dash", "plus", "arrows-fullscreen", "fullscreen-exit")
"""
For each part of how a shape is drawn: its icon at the top of a sketch, what
the tooltips of its two buttons say, and how much one click changes it.
"""
const SKETCH_SETTINGS = (width=("border-width", "Make the line thinner", "Make the line thicker", 0.5),
                         radius=("round-corner", "Make the corners less round", "Make the corners rounder", 1.0),
                         size=("fonts", "Make the words smaller", "Make the words bigger", 1.0))
const SKETCH_BAR = 646px   # the room that the top of a sketch needs to show everything in one row
const HANDLE = 4.5         # px: the radius of the circle on a place of the selected shape
const HANDLE_REACH = 8.0   # px: how near the mouse is to a circle to drag it

# UI.jl has no icon for a round corner. This is one, in a square 16 wide: a line that turns a corner.
const ROUND_CORNER = "M1.75 14L1.75 8A6.25 6.25 0 0 1 8 1.75L14 1.75A0.75 0.75 0 0 1 14 3.25L8 3.25A4.75 4.75 0 0 0 3.25 8L3.25 14A0.75 0.75 0 0 1 1.75 14Z"

"The name of an icon at the top of a sketch. The round corner goes among UI.jl's icons the first time that it's asked for."
sketch_icon(name) = begin
  name == "round-corner" || return name
  kept = get(icon_cache, name, nothing)
  (kept === nothing || first(kept.paths).d != ROUND_CORNER) && (icon_cache[name] = (paths=[SVGPath(d=ROUND_CORNER)], viewbox=(0f0, 0f0, 16f0, 16f0)))
  name
end

"What a `sketch` block shows: a drawing, and the tools that draw it"
@def mutable struct SketchView <: SemanticUI
  n::Int = 0                               # its place among the page's sketches
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Sketches.Sketch = Sketches.Sketch()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  tool::Symbol = :pen
  colour::Symbol = :ink                    # the colour of the next shape
  # How the next shape is drawn: how thick its line is, how round the corners of a box are, and how big words are
  next::Dict{Symbol,Float64} = Dict(:width => Sketches.WIDTH, :radius => Sketches.RADIUS, :size => Sketches.TEXT_SIZE)
  draft::Any = nothing                     # the shape that's being drawn, or nothing
  picked::Int = 0                          # the place of the shape that's selected, or 0
  # A drag of the selected shape: where the mouse was last, whether the shape has changed, and the number of
  # the circle that's dragged, or 0 when the whole shape is
  grab::Any = nothing
  asking::Any = nothing                    # the place in the drawing where words are being typed, or nothing
  editing::Int = 0                         # the place among the shapes of the words that are being changed, or 0 when the words are new
  clicked::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # when and where the drawing was last clicked
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the drawing was last drawn in the window
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons and its text field, kept between frames
  typing::Any = nothing                    # the part of how a shape is drawn whose number has the keyboard, like `:width`, or nothing
  full::Bool = false                       # it fills the window, over the page
  tall::px = 0px                           # how tall it was in the page when it was last laid out there
  pinned::px = 0px                         # how far the page was scrolled when it filled the window
end

"The part of a sketch that's drawn in"
@def mutable struct SketchArea <: SemanticUI
  of::Any = nothing
end
"A dot in the top of a sketch that chooses a colour"
@def mutable struct InkDot <: SemanticUI
  of::Any = nothing
  colour::Symbol = :ink
end

reread!(v::SketchView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Sketches.sketch(lines)
  v.picked = min(v.picked, length(v.data.shapes))
  v
end

"The colour that a sketch draws the colour called `name` in"
sketch_colour(name::Symbol) = begin
  cs = series_colours()
  name == :red ? cs[8] : name == :blue ? cs[1] : name == :green ? cs[6] : name == :orange ? cs[2] : colours.ink
end

sketch_area(v::SketchView) = block_part!(() -> SketchArea(of=v), v, :area)

"""
The text field that holds the words that are being typed into the drawing. It
has the keyboard while they're typed, and it isn't shown: the drawing shows
its words where they will be.
"""
sketch_input(v::SketchView) = block_part!(v, :input) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"How much room the sketch has from side to side: the page's text, or the window when it fills the window"
sketch_room(v::SketchView) = v.full ? window_size(editor(v))[1] : editor(v).width

"How many px of the window one of the sketch's own measure is"
sketch_scale(v::SketchView) = v.box[3] > 0 ? v.box[3] / Sketches.WIDE : num(sketch_room(v) - (v.full ? 0px : 2px)) / Sketches.WIDE

"The shape that's selected, or nothing"
picked_shape(v::SketchView) = 1 <= v.picked <= length(v.data.shapes) ? v.data.shapes[v.picked] : nothing

"A new shape, in the colour and drawn the way that the top of the sketch says now"
new_shape(v::SketchView, kind, points, text="") = begin
  shape = Sketches.Shape(kind, v.colour, points, text)
  foreach(name -> Sketches.set!(shape, name, v.next[name]), Sketches.settings(kind))
  shape
end

"""
The parts of how a shape is drawn that the top of the sketch shows now: those
of the shape that's selected, or those of the shapes that the tool draws.
"""
shown_settings(v::SketchView) = (s = picked_shape(v); s !== nothing ? Sketches.settings(s) : v.tool == :select ? () : Sketches.settings(v.tool))

"What a part of how a shape is drawn is now: for the shape that's selected, or for the next shape"
setting(v::SketchView, name) = (s = picked_shape(v); s === nothing ? v.next[name] : getfield(s, name))

"The most that a part of how a shape is drawn can be now. The corners of the box that's selected are no rounder than half its shorter side."
most(v::SketchView, name) = begin
  top = Sketches.LIMITS[name][2]
  s = picked_shape(v)
  (name == :radius && s !== nothing) || return top
  l, t, r, b = Sketches.bounds(s)
  min(top, round(min(r - l, b - t) / 2, digits=1))
end

"The number that a click takes `n` to: the next whole step up, or the next one down"
stepped(name, n, up) = begin
  step = SKETCH_SETTINGS[name][4]
  to = up ? (floor(n / step + 1e-9) + 1) * step : (ceil(n / step - 1e-9) - 1) * step
  clamp(to, Sketches.LIMITS[name]...)
end

"The text field that holds the number of one part of how a shape is drawn"
number_input(v::SketchView, name) = block_part!(v, (:number, name)) do
  TextInput(placeholder="", font_family=SANS, font_size=12px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"""
Give a part of how a shape is drawn the number `n`: to the shape that's
selected, and to the shapes that are drawn next. A number that's too small or
too big becomes the nearest that the part can be.
"""
set_setting!(v::SketchView, name, n::Real) = begin
  n = round(clamp(n, Sketches.LIMITS[name][1], most(v, name)), digits=1)
  v.next[name] = n
  s = picked_shape(v)
  (s === nothing || getfield(s, name) == n) || (Sketches.set!(s, name, n); commit!(v))
  v
end

"The number that was typed is taken, and its field lets go of it. Text that isn't a number changes nothing."
settle_number!(v::SketchView) = begin
  name = v.typing
  name === nothing && return v
  v.typing = nothing
  n = tryparse(Float64, strip(number_input(v, name).text))
  (n === nothing || !isfinite(n)) ? v : set_setting!(v, name, n)
end

"""
The number of one part of how a shape is drawn, at the top of a sketch, with
its icon and a button each side that changes it. The number is a text field:
a click in it selects the number, and Return takes what's typed.
"""
stepper(v::SketchView, name) = begin
  icon, less, more, _ = SKETCH_SETTINGS[name]
  n = setting(v, name)
  field = number_input(v, name)
  field.color = colours.ink
  typing = v.typing == name
  # While nobody types in it, the field shows the number as it is now
  typing || (field.text = Sketches.figure(n); field.anchor = field.cursor = 0)
  Row(Alignment.Center, name="Setting",
    Box(fixed(22px), height(26px), Alignment.Center, justify=Alignment.Center, Icon(sketch_icon(icon), size=14px, color=colours.dim)),
    block_button!(v, (:less, name), (:set, name, false), icon="dash", tip=less, off=n <= Sketches.LIMITS[name][1]),
    # The field is as wide as its number, in the middle of its room, so the number is half way between the two buttons
    Box(fixed(34px), height(26px), Alignment.Center, justify=Alignment.Center,
      Box(fixed(px(clamp(sketch_measure(field.text, 12) + 14, 20, 34))), height(22px), padding(5px, 0px), radius(5px),
          border(1px, :solid, typing ? colours.accent : ishovered(field) ? colours.line : clear), background(typing ? colours.bg : clear), field)),
    block_button!(v, (:more, name), (:set, name, true), icon="plus", tip=more, off=n >= most(v, name)))
end

"The place in the sketch that's under the mouse"
sketch_place(v::SketchView, w) = (s = sketch_scale(v); ((num(w.mouse[1]) - v.box[1]) / s, (num(w.mouse[2]) - v.box[2]) / s))

"How wide the words of a text shape are, in the sketch's own measure"
sketch_measure(text, size) = num(measure(Face(SANS, "", px(size), colours.ink, false), text))

"Write the sketch into its block"
commit!(v::SketchView) = write_block!(v, SKETCH, Sketches.written(v.data))

describe(::InkDot) = Box(fixed(22px), height(26px), name="Colour")

# The dot and the ring round it are drawn about the middle of the dot's box, so the ring is never off the dot
draw(ctx, size, ui::ConcreteRect, d::InkDot) = begin
  v = d.of
  on = (v.picked > 0 ? v.data.shapes[v.picked].colour : v.colour) == d.colour
  x, y = Float32(num(ui.left + ui.width / 2)), Float32(num(ui.top + ui.height / 2))
  disc(colour, r, wide=0.0) = (paint = ink(colour, wide); Skia.sk_canvas_draw_circle(ctx, x, y, Float32(r), paint); Skia.sk_paint_delete(paint))
  disc(sketch_colour(d.colour), 5)
  (on || ishovered(d)) && disc(on ? colours.accent : colours.marker, 7.25, 1.5)
end

cursor(::InkDot) = :hand

# A click on a colour gives it to the shape that's selected, and to the shapes that are drawn next
onkey(d::InkDot, ::KeyPress{Keys.mouse_left}) = begin
  v = d.of
  v.colour = d.colour
  v.picked > 0 && (v.data.shapes[v.picked].colour = d.colour; commit!(v))
  v.asking === nothing || focus(sketch_input(v))   # the words that are being typed take the colour, and the keyboard stays with them
  handled
end

"True for a sketch with too little room for all of its top in one row. How a shape is drawn then has a row of its own."
narrow(v::SketchView) = sketch_room(v) < SKETCH_BAR

describe(v::SketchView) = begin
  e = editor(v)
  with_theme(component_theme(e.zoom)) do
    # In the page, a page that can't change shows only the drawing
    v.full || !readonly(e.buf) ||
      return Box(width(grow=grow), Alignment.Start, fillable(v, (:block, v), Column(block_look()..., clip=true, name="Sketch", sketch_area(v)), wide=:grow))
    settings = [stepper(v, name) for name in shown_settings(v)]
    beside = narrow(v) || isempty(settings) ? () : (rule(), settings...)
    # The last button puts a sketch that fills the window back in the page. In the page, the button beside its top
    # right corner makes it fill the window.
    full = v.full ? (block_button!(v, :full, :full, icon="fullscreen-exit", tip="Back to the page  esc"),) : ()
    tools = ([block_button!(v, tool, (:tool, tool), icon=icon, tip=tip, on=v.tool == tool) for (tool, icon, tip) in SKETCH_TOOLS]..., rule(),
             [block_part!(() -> InkDot(of=v, colour=c), v, (:ink, c)) for c in Sketches.COLOURS]..., beside...,
             Box(width(grow=grow)),
             (v.picked > 0 ? (block_button!(v, :delete, :delete, icon="trash", tip="Take the selected shape away  Delete"),) : ())..., full...)
    # The second row is there all the time in a narrow sketch, so that the drawing stays where it is when a shape is selected
    bars = (block_bar(tools...), (narrow(v) ? (block_bar(settings..., Box(width(grow=grow))),) : ())...)
    # In the page its tools are over its drawing, so that you draw where it is
    v.full || return Box(width(grow=grow), Alignment.Start, fillable(v, (:block, v), Column(block_look()..., clip=true, name="Sketch", bars..., sketch_area(v)), wide=:grow))
    # In the window it takes all the room under the top bar. The wheel scrolls through a drawing that's taller than that.
    list = get!(() -> Scroll(width(grow=grow), height(grow=grow)), v.parts, :list)
    Column(width(grow=grow), height(grow=grow), Alignment.Start, background(takeoff_back()), name="Sketch", bars..., reuse!(list, sketch_area(v)))
  end
end

"In the page a sketch shows only its drawing, so words that were being typed are added and no shape stays selected."
before_fill!(v::SketchView, on::Bool) = begin
  on || (settle_number!(v); answer!(v); v.picked = 0; v.draft = v.grab = nothing)
  v.box = (0.0, 0.0, 0.0, 0.0)   # it's another size now, so how big it's drawn is worked out afresh
end

# A pinch on a sketch in the page doesn't make it fill the window. Only the button beside its top right corner does.
onpinch(::SketchView, ::Pinch) = nothing

"How tall the drawing is in a sketch that fills the window, when its shapes need less: the window, under the top bar and the sketch's buttons"
full_room(v::SketchView) = num(window_size(editor(v))[2] - above_page(editor(v)) - (narrow(v) ? 76px : 38px))

act!(v::SketchView, action, w) = begin
  settle_number!(v)
  # A button beside a number changes the words that are being typed, and they stay open. Any other button adds them first.
  (action isa Tuple && action[1] == :set) || answer!(v)
  if action == :delete
    1 <= v.picked <= length(v.data.shapes) || return handled
    deleteat!(v.data.shapes, v.picked)
    v.picked = 0
    commit!(v)
  elseif action == :full
    return full!(v, !v.full)
  elseif action[1] == :tool
    v.tool = action[2]
    v.tool == :select || (v.picked = 0)
  elseif action[1] == :set
    # A button beside a number changes it for the shape that's selected, and for the shapes that are drawn next
    _, name, up = action
    set_setting!(v, name, stepped(name, setting(v, name), up))
  end
  focus(v.asking === nothing ? sketch_area(v) : sketch_input(v))
  handled
end

describe(a::SketchArea) = begin
  v = a.of
  # While a shape is drawn or moved, the sketch keeps its height, and gets taller when the mouse lets go
  tall = Sketches.tall(v.data) * sketch_scale(v)
  # One that fills the window goes down to the window's foot, or further
  Box(width(grow=grow), height(px(v.full ? max(tall, full_room(v)) : tall)))
end

"Draw a line through `points` whose corners are round, as a line drawn by hand has them"
draw_curve(ctx, points, paint) = begin
  length(points) < 2 && return
  shape = Skia.sk_path_new()
  Skia.sk_path_move_to(shape, Float32(points[1][1]), Float32(points[1][2]))
  # The line goes from the middle of each part to the middle of the next, and bends at the place between
  for i in 2:length(points)-1
    mid = (points[i] .+ points[i+1]) ./ 2
    Skia.sk_path_quad_to(shape, Float32(points[i][1]), Float32(points[i][2]), Float32(mid[1]), Float32(mid[2]))
  end
  Skia.sk_path_line_to(shape, Float32(points[end][1]), Float32(points[end][2]))
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_path_delete(shape)
end

"""
Draw one shape of a sketch whose top left corner is at `(x0, y0)` in the
window. `s` is how many px one of the sketch's measure is. With `glow`, it
draws a soft light in the shape and the colour of the shape, which goes under
the shape that's selected.
"""
draw_shape(ctx, shape, x0, y0, s; glow=false) = begin
  at(p) = (x0 + p[1] * s, y0 + p[2] * s)
  words = shape.kind == :text
  # A line is never so thin in a small sketch that it can't be seen
  wide = max(min(1.2, 0.6shape.width), shape.width * s)
  colour = sketch_colour(shape.colour)
  # The light is the colour of the shape, and fainter
  paint = glow ? ink(RGBA(colour, 0.35), words ? 0.0 : wide + 4) : ink(colour, words ? 0.0 : wide)
  blur = glow ? Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 2.5f0, true) : nothing
  glow && Skia.sk_paint_set_maskfilter(paint, blur)
  stroke(ps) = (line = path_through(ps, false); Skia.sk_canvas_draw_path(ctx, line, paint); Skia.sk_path_delete(line))
  if words
    x, y = at(shape.points[1])
    blob = Skia.sk_textblob_make_from_string(shape.text, skia_font(SANS, px(shape.size * s), "").raw, Skia.SK_TEXT_ENCODING_UTF8)
    # The light under words is drawn twice, since words are thin
    for _ in 1:(glow ? 2 : 1)
      Skia.sk_canvas_draw_text_blob(ctx, blob, Float32(x), Float32(y), paint)
    end
    Skia.sk_textblob_unref(blob)
  elseif shape.kind in (:box, :oval)
    l, t, r, b = Sketches.bounds(shape)
    (x1, y1), (x2, y2) = at((l, t)), at((r, b))
    edges = Ref(Skia.sk_rect_t(Float32(x1), Float32(y1), Float32(x2), Float32(y2)))
    if shape.kind == :oval
      Skia.sk_canvas_draw_oval(ctx, edges, paint)
    else
      # The corners of a small box are no rounder than half its shorter side
      bend = Float32(min(shape.radius * s, (x2 - x1) / 2, (y2 - y1) / 2))
      outline = Skia.sk_path_new()
      Skia.sk_path_add_rounded_rect(outline, edges, bend, bend, Skia.SK_PATH_DIRECTION_CW)
      Skia.sk_canvas_draw_path(ctx, outline, paint)
      Skia.sk_path_delete(outline)
    end
  elseif shape.kind == :pen
    draw_curve(ctx, at.(shape.points), paint)
  else
    stroke(at.(shape.points))
    if shape.kind == :arrow
      a, b = Sketches.barbs(shape)
      stroke([at(a), at(shape.points[2]), at(b)])
    end
  end
  glow && Skia.sk_maskfilter_unref(blur)
  Skia.sk_paint_delete(paint)
end

"The number of the circle of the selected shape that's under the mouse, or nothing"
handle_under(v::SketchView, w) = begin
  shape = picked_shape(v)
  (shape === nothing || w === nothing || v.box[3] <= 0) && return nothing
  Sketches.handle(shape, sketch_place(v, w), HANDLE_REACH / sketch_scale(v))
end

"Draw a circle on each place of the selected shape that a drag moves. The one under the mouse, or the one that's dragged, is filled."
draw_handles(ctx, v::SketchView, shape, s) = begin
  hot = v.grab !== nothing ? (v.grab[3] == 0 ? nothing : v.grab[3]) : v.tool == :select ? handle_under(v, window_of(v)) : nothing
  # The places of a line drawn by hand are close together, so their circles are smaller
  r = shape.kind == :pen ? 0.7HANDLE : HANDLE
  for (k, p) in enumerate(Sketches.handles(shape))
    x, y = Float32(v.box[1] + p[1] * s), Float32(v.box[2] + p[2] * s)
    for paint in (ink(k == hot ? colours.accent : takeoff_back()), ink(colours.accent, 1.5))
      Skia.sk_canvas_draw_circle(ctx, x, y, Float32(r), paint)
      Skia.sk_paint_delete(paint)
    end
  end
end

draw(ctx, size, ui::ConcreteRect, a::SketchArea) = begin
  v = a.of
  v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  v.box[3] > 0 || return
  s = sketch_scale(v)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    isempty(v.data.shapes) && v.draft === nothing && v.asking === nothing &&
      write_ink(ctx, readonly(editor(v).buf) ? "Nothing is drawn here" : "Drag here to draw", v.box[1] + 16, v.box[2] + 28, Face(SANS, "", 13px, colours.faint, false))
    for (k, shape) in enumerate(v.data.shapes)
      k == v.editing && continue   # words that are being changed show as they're typed
      # The shape that's selected glows
      k == v.picked && draw_shape(ctx, shape, v.box[1], v.box[2], s, glow=true)
      draw_shape(ctx, shape, v.box[1], v.box[2], s)
    end
    v.draft === nothing || draw_shape(ctx, v.draft, v.box[1], v.box[2], s)
    # And it has a circle on each place that a drag moves
    chosen = picked_shape(v)
    chosen === nothing || draw_handles(ctx, v, chosen, s)
    v.asking === nothing || draw_typing(ctx, v, s)
  end
end

"The words that are being changed, or nothing when the words that are typed are new"
edited_shape(v::SketchView) = begin
  s = 1 <= v.editing <= length(v.data.shapes) ? v.data.shapes[v.editing] : nothing
  s !== nothing && s.kind == :text ? s : nothing
end

"The words that are being typed, as the shape that they will be"
typed_shape(v::SketchView) = begin
  old, text = edited_shape(v), sketch_input(v).text
  old === nothing ? new_shape(v, :text, [v.asking], text) : Sketches.Shape(:text, old.colour, [v.asking], text, old.width, old.radius, old.size)
end

"""
The place among the characters of the words that are being typed that's
nearest to `p`, a place in the sketch. It's nothing when `p` isn't on the words.
"""
typed_index(v::SketchView, p) = begin
  text, size = sketch_input(v).text, typed_shape(v).size
  x, y = v.asking
  to(n) = x + sketch_measure(first(text, n), size)
  (x - 4 <= p[1] <= to(length(text)) + 4 && y - size <= p[2] <= y + 0.3size) || return nothing
  argmin(n -> abs(to(n) - p[1]), 0:length(text))
end

"Start typing in the drawing: new words at `at`, or with `k` the `k`th shape's words, with the caret where `p` is in them"
type_words!(v::SketchView, at, k=0, p=at) = begin
  field = sketch_input(v)
  v.asking, v.editing = at, k
  field.text = k == 0 ? "" : v.data.shapes[k].text
  field.anchor = field.cursor = something(typed_index(v, p), length(field.text))
  field.last_action = time()
  v.picked = k   # so the colours and the size at the top are those of the words
  v.grab = nothing
  focus(field)
  handled
end

"Note a click at `(x, y)`. True when it's the second of two clicks in one place."
click_twice!(v::SketchView, x, y) = begin
  at, cx, cy = v.clicked
  v.clicked = (time(), x, y)
  time() - at < 0.35 && hypot(x - cx, y - cy) < 4
end

"""
Draw the words that are being typed where they will be in the drawing, in
their colour and at their size, with the caret after the place that the next
character goes in, and the colour of a selection behind the words that are
selected.
"""
draw_typing(ctx, v::SketchView, s) = begin
  field = sketch_input(v)
  shape = typed_shape(v)
  x, y = v.box[1] + v.asking[1] * s, v.box[2] + v.asking[2] * s
  tall = shape.size * s
  face = Face(SANS, "", px(tall), colours.ink, false)
  to(n) = x + num(measure(face, first(field.text, n)))
  lo, hi = minmax(field.anchor, field.cursor)
  lo == hi || round_box(ctx, to(lo), y - 0.95tall, to(hi) - to(lo), 1.25tall, 2.0, fill=colours.select)
  isempty(field.text) || draw_shape(ctx, shape, v.box[1], v.box[2], s)
  # The caret blinks, and it's lit just after a key
  mod(time() - field.last_action, 1.0) < 0.5 && trace(ctx, [(to(field.cursor), y - 0.9tall), (to(field.cursor), y + 0.2tall)], colours.accent, 1.5)
end

cursor(a::SketchArea) = begin
  v = a.of
  readonly(editor(v).buf) && return :arrow
  v.tool == :select || return v.tool == :text ? :ibeam : :crosshair
  v.grab !== nothing || handle_under(v, window_of(a)) !== nothing ? :hand : :arrow
end
cursor(::SketchView) = :arrow

onkey(a::SketchArea, ev::KeyPress{Keys.mouse_left}) = begin
  v, w = a.of, ev.window
  # A click draws in the page too. With ⌥ held, the page shows the block's lines.
  v.full || !only_held(v, Keys.opt) || return nothing
  readonly(editor(v).buf) && return handled
  p = sketch_place(v, w)
  twice = click_twice!(v, num(w.mouse[1]), num(w.mouse[2]))
  # A click on the words that are being typed puts the caret there
  if v.asking !== nothing && (n = typed_index(v, p)) !== nothing
    field = sketch_input(v)
    field.anchor = field.cursor = n
    field.last_action = time()
    return handled
  end
  answer!(v)          # words that were being typed are added where they are
  settle_number!(v)   # a number that was typed goes to the shape that it was typed for
  focus(a)
  k = Sketches.hit(v.data, p, 7.0, sketch_measure)
  words = k !== nothing && v.data.shapes[k].kind == :text
  if v.tool == :select
    # A circle of the shape that's selected is taken before a shape is
    h = handle_under(v, w)
    h === nothing || (k = v.picked)
    # Two clicks on words change them where they are
    h === nothing && words && twice && return type_words!(v, v.data.shapes[k].points[1], k, p)
    v.picked = something(k, 0)
    v.grab = k === nothing ? nothing : (p, false, something(h, 0))
  elseif v.tool == :text
    # A click on words changes them. Anywhere else, new words go where the click was: the middle of their height is at the mouse.
    words ? type_words!(v, v.data.shapes[k].points[1], k, p) : type_words!(v, (p[1], p[2] + 0.35v.next[:size]))
  else
    v.picked = 0
    v.draft = new_shape(v, v.tool, v.tool == :pen ? [p] : [p, p])
  end
  handled
end

onmouse(a::SketchArea, ev::MouseMove) = begin
  v, w = a.of, ev.window
  (v.draft === nothing && v.grab === nothing) && return nothing
  Keys.mouse_left in w.keys || return handled
  p = sketch_place(v, w)
  if v.draft !== nothing
    d = v.draft
    # A line drawn by hand gets a new place when the mouse has moved a little
    d.kind == :pen ? (hypot((p .- d.points[end])...) >= 1.5 && push!(d.points, p)) : (d.points[2] = p)
  elseif (shape = picked_shape(v)) !== nothing
    from, _, h = v.grab
    (p == from) && return handled
    # A circle goes where the mouse is, and takes its place of the shape with it. Without one, the whole shape moves.
    h == 0 ? Sketches.move!(shape, p[1] - from[1], p[2] - from[2]) : Sketches.pull!(shape, h, p)
    v.grab = (p, true, h)
  end
  handled   # the drag is the sketch's, so the page's text doesn't select
end

"The mouse let go. The shape that was drawn joins the sketch, and a shape that moved or changed is written down."
drop!(v::SketchView) = begin
  d, g = v.draft, v.grab
  v.draft = v.grab = nothing
  if d !== nothing
    d.kind == :pen && (d.points = Sketches.simplify(d.points))
    # A click without a drag draws nothing
    (d.kind == :pen ? length(d.points) < 2 : Sketches.slight(d)) && return v
    push!(v.data.shapes, d)
    commit!(v)
  elseif g !== nothing && g[2]
    commit!(v)
  end
  v
end

"""
Take the words that were typed. New words are added as a text shape, at the
place that was clicked. Words that were changed are written down, and taken
away when nothing is left of them.
"""
answer!(v::SketchView) = begin
  v.asking === nothing && return handled
  words = join(split(sketch_input(v).text), " ")
  p, k, old = v.asking, v.editing, edited_shape(v)
  stop_asking!(v)
  if old !== nothing
    isempty(words) ? (deleteat!(v.data.shapes, k); v.picked = 0) : (old.text = words)
    commit!(v)
  elseif k == 0 && !isempty(words)
    push!(v.data.shapes, new_shape(v, :text, [p], words))
    commit!(v)
  end
  handled
end

"Stop typing words into the drawing. New words are left out, and words that were being changed stay as they were. The keyboard goes back to the drawing."
stop_asking!(v::SketchView) = begin
  v.asking = nothing
  v.editing = 0
  v.tool == :select || (v.picked = 0)
  w = window_of(v)
  w !== nothing && w.focus === sketch_input(v) && focus(sketch_area(v))
  handled
end

# Return takes the number that was typed for how a shape is drawn, and Esc leaves the number as it was
onkey(v::SketchView, ev::KeyPress{Keys.enter}) = !unmodified(ev) ? nothing :
  v.typing !== nothing ? (settle_number!(v); focus(sketch_area(v)); handled) : v.asking === nothing ? nothing : answer!(v)
onkey(v::SketchView, ev::KeyPress{Keys.escape}) = !unmodified(ev) ? nothing :
  v.typing !== nothing ? (v.typing = nothing; focus(sketch_area(v)); handled) : v.asking === nothing ? nothing : stop_asking!(v)
onmouse(v::SketchView, ::MouseMove) = v.full || (held(v, Keys.mouse_left) && (v.draft !== nothing || v.grab !== nothing)) ? handled : nothing
# A click beside a button of a sketch that fills the window is the sketch's, and not the page's under it
onkey(v::SketchView, ::KeyPress{Keys.mouse_left}) = v.full ? (focus(sketch_area(v)); handled) : nothing

# The wheel over a sketch that fills the window scrolls a drawing that's taller than the window. It never
# scrolls the page under the sketch, which UI.jl would choose first. In the page, the wheel scrolls the page.
onscroll(a::SketchArea, ev::MouseScroll) = begin
  v = a.of
  v.full || return nothing
  list = get(v.parts, :list, nothing)
  list === nothing || (list.offset = clamp(list.offset - 30ev.delta[2], 0px, max(0px, px(v.box[4] - full_room(v)))))
  handled
end
onscroll(v::SketchView, ::MouseScroll) = v.full ? handled : nothing

block_tick!(v::SketchView) = begin
  (v.draft !== nothing || v.grab !== nothing) && !held(v, Keys.mouse_left) && drop!(v)
  # A click somewhere else took the keyboard from the words that were being typed. They're added.
  w = window_of(v)
  v.asking !== nothing && w !== nothing && w.focus !== sketch_input(v) && answer!(v)
  # The words that were being changed have gone, as after ⌘Z
  v.editing > 0 && edited_shape(v) === nothing && stop_asking!(v)
  v.asking === nothing || redraw_in!(v, 0.25)   # the caret blinks
  # A click in a number gave it the keyboard, and its text is selected so that typing takes its place.
  # A click somewhere else took the keyboard from it, and a number that was typed is kept.
  if w !== nothing
    at = findfirst(name -> w.focus === get(v.parts, (:number, name), nothing), keys(SKETCH_SETTINGS))
    name = at === nothing ? nothing : keys(SKETCH_SETTINGS)[at]
    if name != v.typing
      settle_number!(v)
      v.typing = name
      name === nothing || tabbed!(number_input(v, name))
    end
  end
  v
end

# Esc lets go of the shape that's selected, then chooses the arrow tool, then puts a sketch that fills the window
# back in the page, then gives the keyboard back to the text. In the page the page's text takes that Esc. Delete
# takes the shape away.
onkey(a::SketchArea, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  v = a.of
  v.picked > 0 && return (v.picked = 0; handled)
  v.tool == :select || return (v.tool = :select; handled)
  v.full ? full!(v, false) : nothing
end
onkey(a::SketchArea, ::KeyPress{K}) where K = begin
  v = a.of
  K in (Keys.backspace, Keys.delete) && unmodified(window_of(a)) && return v.picked > 0 ? act!(v, :delete, window_of(a)) : handled
  if (command = command_of(editor(v), window_of(a), K)) in (:undo, :redo)
    b = editor(v).buf
    command == :redo ? redo!(b) : undo!(b)
    return handled
  end
  nothing
end

"The sketch as HTML: a picture of it"
sketch_html(e, v::SketchView) = begin
  isempty(v.data.shapes) && return nothing
  cs = css_colour.(SERIES_LIGHT)
  picture = Sketches.svg(v.data, colours=(ink="#2b2622", red=cs[8], blue=cs[1], green=cs[6], orange=cs[2]), family="-apple-system, Helvetica, sans-serif")
  "<div class=\"diagram\">\n$picture\n</div>"
end

BLOCKS[SKETCH] = SketchView
block_name(::Type{SketchView}) = "Sketch"
block_icon(::Type{SketchView}) = "pencil"
block_insert(::Type{SketchView}) = ("Sketch", ["```$SKETCH", "```", "", ""], (4, 0))
block_html(e, v::SketchView) = sketch_html(e, v)
