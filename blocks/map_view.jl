# The view of a `map` block: a map of a place
#
# A code block in the language `map` shows the map round a place, with a pin
# on the place and the address under it. map.jl says how the block is
# written. A program of its own asks the Mac's maps for two things: where the
# place is, and the picture of the map. The window never waits for that
# program. Until the picture is there, the block shows a grey box. What comes
# back is kept on the Mac, so a page shows its map at once the next time,
# with no network.
#
#   - The − and the + on the map show more and less of what's round the
#     place. The block keeps that as a line like `zoom: 15`.
#   - A drag moves the map. When the mouse lets go, the block keeps the
#     middle of what shows as a line like `centre: -33.86120, 151.21010`.
#     A third button beside the − takes that line away, so the place is in
#     the middle again.
#   - A click moves the place: the pin goes where the click was, and the
#     block's place becomes that point's latitude and longitude.
#   - Open in Maps opens the Mac's Maps app at the place.
#   - The button beside the map's top right corner makes it fill the window,
#     as a picture does, and so does Return with the caret on the map.
#
# The picture has no pin in it. Ladder draws the pin over the picture, on the
# point where the place is. So a click moves the pin in the same frame, and
# the picture stays the one that it was: it depends on the middle, the zoom,
# the size and dark or light, and not on the place. The address under the map
# comes later, when the program has it.
#
# Every picture is drawn where its own middle is on the map that shows now.
# So after a drag or a change of zoom, the picture that showed stays in its
# place until the right one is there, and the map never jumps.
#
# A window that isn't on the screen, like one a test makes, never runs the
# program and never opens the Maps app. A test puts functions of its own in
# `Maps.HELPER`, `Maps.FINDER` and `Maps.OPENER` to see what the block does
# with them.

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! Pinch onpinch with_clip with_round_clip
@use "github.com/jkroso/UI.jl/Interface/image" image_source has_image
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" problem
@use "./pictures" picture
@use "./html" escape
@use "./markdown" Kind words front_matter
@use "./sheet" parts shown
@use "./map" => Maps
@use Colors: @colorant_str, RGBA
@use "github.com/jkroso/UI.jl/Interface/image" register_image
@use "./base" exports...
@use "./sketch_view" exports...
@use "./fill_view" pinch_open

export MAP, MAP_PAUSE, MAP_ROUND, MAP_SLACK, MapView, MapArea, map_place, map_wide, map_zoom, map_facts,
       map_pin, map_middle, map_spot, map_shows, map_changes, map_moves, map_find!, map_picture!, map_words,
       map_address, map_pin_in, map_full!, pin_bend, pin_ink, pinned_png, map_drop!, map_html, OTHER_PIN,
       PIN_REACH, page_places, map_others, map_around, other_point, other_at

@use "github.com/jkroso/UI.jl/Interface/image" register_image

const MAP = Maps.MAP
# Seconds that a map keeps one width before Ladder asks for a picture that wide, and that a pin
# keeps its place before Ladder makes the picture that fills the window
const MAP_PAUSE = 0.3
const MAP_ROUND = 7.0   # the radius of the map's top corners, which are just inside the round corners of its block
const MAP_SLACK = 4.0   # px that the mouse can move between a press and a release that are still a click
push!(BLOCK_ICONS, "geo-alt", "plus-lg", "dash-lg", "box-arrow-up-right", "crosshair")

"What a `map` block shows: a picture of the map round a place, a pin on the place, and the address under it"
@def mutable struct MapView <: SemanticUI
  n::Int = 0                               # its place among the page's maps
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Maps.Site = Maps.Site()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  asked::Any = nothing                     # how wide the map is, and when it got that width
  # What's known of a place: the place, what `Maps.found!` last said of it, and the latitude, the longitude and the address that Apple has for it
  place::Any = nothing
  got::Any = nothing                       # what `Maps.picture!` last said of the picture that the map needs now, and whether the program can run
  # The last picture that was there: its file, its zoom, the latitude and the longitude in its middle, and how wide it is.
  # It shows until the next one is there.
  shown::Any = nothing
  # While the mouse button is down on the map: where it went down, the middle of the map then, and whether the mouse has dragged the map
  grab::Any = nothing
  at::Any = nothing                        # the latitude and the longitude in the middle of the map while a drag moves it
  pinned::Any = nothing                    # the picture and the point that the picture with a pin in it was last made from
  due::Any = nothing                       # the picture and the point that it's to be made from next, and since when
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the picture was last drawn in the window
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons and its picture, kept between frames
end

"The part of a map that shows the picture"
@def mutable struct MapArea <: SemanticUI
  of::Any = nothing
end

reread!(v::MapView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Maps.site(lines)
  v
end

"The place of the block, as two blocks that name one place have it"
map_place(v::MapView) = lowercase(Maps.query(v.data.place))

"How wide the picture of the map is, in px: as wide as the page's text"
map_wide(v::MapView) = round(Int, num(editor(v).width))

"The zoom that the map's picture is made at: the block's, or a higher one on a page that's too wide for it"
map_zoom(v::MapView) = (a = map_around(v); Maps.fit(a === nothing ? v.data.zoom : a.zoom, map_wide(v), Maps.TALL))

"What Apple has for the block's place, or nothing while that isn't known"
map_facts(v::MapView) = (p = v.place; p !== nothing && p.key == map_place(v) ? p.facts : nothing)

"""
Where the pin is: the latitude and the longitude of the block's place. For an
address, that's what Apple has for it. It's nothing until that's known.
"""
map_pin(v::MapView) = begin
  at = Maps.coordinates(v.data.place)
  at !== nothing && return at
  found = map_facts(v)
  found === nothing ? nothing : (found.lat, found.lon)
end

"""
The latitude and the longitude in the middle of the map: where a drag has it
now, what the block's `centre` line says, or the place. It has the five
decimal places that a block keeps, as the middle of a picture has. It's
nothing while the place of an address isn't known.
"""
map_middle(v::MapView) = begin
  v.at === nothing || return v.at
  # A map with no place of its own has the places from the rest of its page round its middle
  a = map_around(v)
  middle = something(v.data.centre, map_pin(v), a === nothing ? nothing : a.centre, Some(nothing))
  middle === nothing ? nothing : Maps.rounded(middle)
end

"""
Where the picture that the map has is on a map `w` px by `h` px that shows
what the block says now: its left, its top, its width and its height, in px
from that map's top left corner. It's nothing when the map has no picture,
or the middle of the map isn't known.
"""
map_spot(v::MapView, w, h) = begin
  shown, middle = v.shown, map_middle(v)
  (shown === nothing || middle === nothing) && return nothing
  zoom = map_zoom(v)
  # A picture that was made at another zoom is drawn as big as the map of this zoom is
  k = 2.0^(zoom - shown.zoom)
  wide, tall = shown.wide * k, Maps.TALL * k
  cx, cy = Maps.point(shown.centre, middle, zoom, w, h)
  (cx - wide / 2, cy - tall / 2, wide, tall)
end

"True when the map has a picture to draw: some of the picture that it has is in the map that shows now"
map_shows(v::MapView) = begin
  w, h = map_wide(v), Maps.TALL
  r = map_spot(v, w, h)
  r !== nothing && r[1] < w && r[1] + r[3] > 0 && r[2] < h && r[2] + r[4] > 0
end

"True when the page can be changed: a page that's read-only takes no drag and no click"
map_changes(v::MapView) = (b = editor(v).buf; !readonly(b) && !b.fixed)

"True when a drag can move the map and a click can move its place: the page can be changed, and the map shows a picture"
map_moves(v::MapView) = map_changes(v) && map_shows(v) && !isempty(v.data.place)

"""
What Apple has for the block's place. The program that finds a place is
started here, when the place isn't kept. A latitude and a longitude need no
finding, and are asked for only to learn their address. What comes back is
read once.
"""
map_find!(v::MapView, runs) = begin
  key = map_place(v)
  p = v.place
  p !== nothing && p.key == key && p.facts !== nothing && return p
  # A map with no place of its own has nothing to find
  isempty(v.data.place) && return v.place = (key=key, found=(state=:none, file="", problem="", wait=Inf), facts=nothing)
  ask(start) = Maps.found!(media_dir(), v.data.place; start)
  found = ask(runs)
  facts = found.state == :there ? Maps.facts(found.file) : nothing
  # A file that holds something else is taken away, and made again later
  found.state == :there && facts === nothing && (Maps.spoiled!(found.file); found = ask(false))
  v.place = (key=key, found=found, facts=facts)
end

"""
The picture that the map needs now: as wide as the page's text, at the block's
zoom, with the middle of the map in its middle, dark on a dark page.
`Maps.picture!` says what it gives. The program that makes the picture is
started here, when the picture isn't kept. While the window changes size, the
map has another width in each frame, so the program is only started once the
width has stayed for a moment. While the place of an address isn't known, the
map has no middle, and no picture is asked for.
"""
map_picture!(v::MapView) = begin
  s = v.data
  wide, dark, zoom = map_wide(v), dark_page(), map_zoom(v)
  (v.asked === nothing || v.asked[1] != wide) && (v.asked = (wide, v.asked === nothing ? 0.0 : time()))
  rest = MAP_PAUSE - (time() - v.asked[2])
  runs = on_screen(v) || Maps.HELPER[] !== Maps.run_program
  place = map_find!(v, runs)
  map_others(v, runs)   # the places from the rest of the page are asked for too
  around = map_around(v)
  # The picture is of what the block says, and not of where a drag has the map now: the block changes when the mouse lets go
  middle = something(s.centre, map_pin(v), around === nothing ? nothing : around.centre, Some(nothing))
  p = nothing
  if middle !== nothing
    middle = Maps.rounded(middle)
    ask(start) = Maps.picture!(media_dir(), middle, zoom, wide, Maps.TALL, dark; start)
    p = ask(runs && rest <= 0)
    # A file that was cut short is no picture. It's taken away, and made again later.
    p.state == :there && !whole_picture(p.file) && (Maps.spoiled!(p.file); p = ask(false))
    p.state == :there && (v.shown = (file=p.file, zoom=zoom, centre=middle, wide=wide))
  end
  v.shown === nothing || isfile(v.shown.file) || (v.shown = nothing)
  # The window looks again when a program may have finished, when the width has stayed, or when it's time to try again
  wait = min(place.found.wait, p === nothing ? Inf : p.wait, runs && rest > 0 ? rest : Inf)
  isfinite(wait) && redraw_in!(v, max(wait, 0.05))
  v.got = (p, runs)
end

"What a map says in place of a picture that isn't there, or \"\" when it has a picture to show"
map_words(v::MapView) = begin
  map_shows(v) && return ""
  p, runs = v.got
  # Without a middle, the map waits for the place. With one, it waits for the picture.
  waits = p === nothing ? v.place.found : p
  waits.state == :lost ? waits.problem : waits.state == :failed ? waits.problem * (runs ? " It tries again in a minute." : "") :
  waits.state == :none && !runs ? Maps.FAILED : "Finding the place…"
end

"""
The words under a map: the address that Apple has for the place, or the place
as the block has it until that's known. An address that Apple's maps don't
have says so here, when the map shows a picture all the same.
"""
map_address(v::MapView) = begin
  found = map_facts(v)
  found === nothing || isempty(found.address) || return found.address
  lost = v.place !== nothing && v.place.key == map_place(v) && v.place.found.state == :lost
  lost && map_shows(v) ? v.data.place * ". " * v.place.found.problem : v.data.place
end

"""
The point of the picture that the map has where the pin is, in px from the
picture's top left corner. It's nothing when the place isn't known, or isn't
in that picture.
"""
map_pin_in(v::MapView) = begin
  shown, pin = v.shown, map_pin(v)
  (shown === nothing || pin === nothing) && return nothing
  at = Maps.point(pin, shown.centre, shown.zoom, shown.wide, Maps.TALL)
  0 <= at[1] <= shown.wide && 0 <= at[2] <= Maps.TALL ? at : nothing
end

"""
The key, for an Image, of the picture that fills the window: the map's
picture with the pin drawn in it, since what fills the window is a picture
and no more. A map whose place isn't in its picture fills the window as it
is.

That picture takes some hundredths of a second to make. So it's made a
moment after the picture or the pin last changed, and not in the frame of
the click that moved the pin. Until the first one is made, the map fills the
window without its pin.
"""
map_full!(v::MapView) = begin
  shown, at = v.shown, map_pin_in(v)
  at === nothing && return shown.file
  key = "the map with its pin $(objectid(v))"
  want = (shown.file, at)
  if v.pinned != want
    (v.due === nothing || v.due[1] != want) && (v.due = (want, time()))
    if v.grab === nothing && time() - v.due[2] >= MAP_PAUSE
      was = has_image(key) ? image_source(key) : nothing
      register_image(key, pinned_png(shown.file, at))
      was === nothing || Skia.sk_image_unref(was.raw)   # the picture that the key had isn't needed
      v.pinned, v.due = want, nothing
    else
      redraw_in!(v, MAP_PAUSE)
    end
  end
  has_image(key) ? key : shown.file
end

describe(v::MapView) = begin
  e = editor(v)
  s = v.data
  with_theme(component_theme(e.zoom)) do
    isempty(s.place) && isempty(page_places(e)) && return Column(block_look()..., clip=true, name="Map",
      block_note("Write an address in this block, or a latitude and a longitude, to see the map of that place. A map with no address shows the addresses of the page's contacts."))
    map_picture!(v)
    others = map_others(v)
    area = block_part!(() -> MapArea(of=v), v, :area)
    least, most = first(Maps.ZOOMS), last(Maps.ZOOMS)
    # On a page that's too wide for the lowest zooms, the − stops at the lowest zoom that a picture is made at
    lowest = s.zoom <= least || Maps.fit(s.zoom - 1, map_wide(v), Maps.TALL) == map_zoom(v)
    buttons = Row(radius(7px), padding(2px), child_gap=1px, background(colours.float), border(1px, :solid, colours.line),
      (s.centre === nothing ? () : (block_button!(v, :home, :home, icon="crosshair", tip="Put the place back in the middle of the map"),))...,
      block_button!(v, :out, (:zoom, -1), icon="dash-lg", tip="Show more of what's round the place", off=lowest),
      block_button!(v, :in, (:zoom, 1), icon="plus-lg", tip="Show the place closer", off=s.zoom >= most))
    # A map with no place of its own is as close as shows every place from the page, and says how many those are
    own = !isempty(s.place)
    under = own ? map_address(v) : isempty(others) ? "Finding the places of this page…" :
            length(others) == 1 ? "1 place from this page: " * others[1].name : "$(length(others)) places from this page: " * join((o.name for o in others), ", ")
    Column(block_look()..., clip=true, name="Map",
      Stack(width(grow=grow), height(px(Maps.TALL)), Alignment.Start,
        map_shows(v) ? fillable(v, (:picture, map_full!(v)), area, wide=:grow) : area,
        (own ? (Row(width(grow=grow), padding(8px), Alignment.Start, justify=Alignment.End, buttons),) : ())...),
      Row(width(grow=grow), padding(own ? 5px : 9px, 6px, own ? 5px : 9px, 12px), child_gap=8px, Alignment.Center,
        Box(Icon("geo-alt", size=14px, color=colours.dim)),
        Box(width(grow=grow), Alignment.Start, clip_x=true, Text(under, size=12.5px, family=SANS, color=colours.dim, wrap=WrapMode.words)),
        (own ? (block_button!(v, :open, :open, words="Open in Maps", icon="box-arrow-up-right", tip="Open the Maps app at this place"),) : ())...))
  end
end

describe(a::MapArea) = begin
  words = map_words(a.of)
  # Only its top corners are round, as the corners of its block are
  Box(width(grow=grow), height(px(Maps.TALL)), Alignment.Center, justify=Alignment.Center, padding(60px, 0px),
      radius(px(MAP_ROUND), px(MAP_ROUND), 0px, 0px), background(colours.block),
      (isempty(words) ? () : (Box(Text(words, size=13px, family=SANS, color=colours.dim, wrap=WrapMode.words)),))...)
end

"The places along the bend from `a` to `d` that `b` and `c` pull towards them, without `a`"
pin_bend(a, b, c, d, steps=12) = [(1 - t)^3 .* a .+ 3t * (1 - t)^2 .* b .+ 3t^2 * (1 - t) .* c .+ t^3 .* d for t in (1:steps) ./ steps]

"""
Draw a pin whose point is at `(x, y)`: a red drop with a white dot in it, as
maps mark a place. It's drawn as a shape, so it's sharp however big the
canvas draws it, on the screen and on paper.
"""
pin_ink(ctx, x, y; fill=RGBA(0.92, 0.26, 0.21, 1.0), line=RGBA(0.70, 0.16, 0.13, 1.0)) = begin
  r, cy = 11.0, y - 26.0   # the radius of the pin's round head, and how high its middle is
  shape = [(x, y); pin_bend((x, y), (x - 2, y - 9), (x - r, cy + 9), (x - r, cy));
           [(x - r * cos(a), cy - r * sin(a)) for a in (1:23) .* (π / 24)];
           (x + r, cy); pin_bend((x + r, cy), (x + r, cy + 9), (x + 2, y - 9), (x, y))]
  # A soft shadow on the ground under the point
  shadow = ink(RGBA(0.0, 0.0, 0.0, 0.25))
  ground = Ref(Skia.sk_rect_t(Float32(x - 5), Float32(y - 2), Float32(x + 5), Float32(y + 2)))
  Skia.sk_canvas_draw_oval(ctx, ground, shadow)
  Skia.sk_paint_delete(shadow)
  trace(ctx, shape, line, 1.0; fill, closed=true)
  disc(ctx, x, cy, 4, RGBA(1.0, 1.0, 1.0, 1.0))
end

"""
The picture in `file` with a pin drawn on the point `at` of it, in px from its
top left corner, as the bytes of a PNG file. The page of HTML and the map
that fills the window show that picture, since each shows a picture and no
more.
"""
pinned_png(file, at) = begin
  image = image_source(file)
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_OPAQUE, image.width, image.height))
  GC.@preserve info begin
    surface = Skia.sk_surface_make_raster_n32_premul(pointer_from_objref(info), C_NULL)
    surface == C_NULL && return read(file)
    canvas = Skia.sk_surface_get_canvas(surface)
    paint_picture(canvas, image.raw, (0, 0, image.width, image.height), (0, 0, image.width, image.height))
    # The pin is as big on the picture as it is on the page, where the picture has `Maps.SCALE` pixels to the px
    Skia.sk_canvas_scale(canvas, Float32(Maps.SCALE), Float32(Maps.SCALE))
    pin_ink(canvas, at[1], at[2])
    drawn = Skia.sk_surface_make_image_snapshot(surface)
    encoded = Skia.sk_encode_png(C_NULL, drawn, Int32(6))
    bytes = copy(unsafe_wrap(Array, Ptr{UInt8}(Skia.sk_data_get_data(encoded)), Skia.sk_data_get_size(encoded)))
    Skia.sk_data_unref(encoded)
    Skia.sk_image_unref(drawn)
    Skia.sk_surface_unref(surface)
    bytes
  end
end

# The picture is drawn at its own size, with its middle where that latitude and longitude is on the map that
# shows now. So a picture that was made for another width, or for another middle, shows the same streets in
# the same places until the right one is there, and the part with no picture yet is grey. The pin is drawn
# over it, on the place. A place that isn't in the map that shows has no pin, and nothing is drawn outside
# the map's box.
draw(ctx, size, ui::ConcreteRect, a::MapArea) = begin
  v = a.of
  x, y, w, h = v.box = (num(ui.left), num(ui.top), num(ui.width), num(ui.height))
  r = map_spot(v, w, h)
  (r !== nothing && map_shows(v) && whole_picture(v.shown.file)) || return
  # Only the top corners are round: the box that's cut out goes on under the map's foot
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    with_round_clip(ctx, ui.left, ui.top, ui.width, ui.height + px(2MAP_ROUND), px(MAP_ROUND)) do
      image = image_source(v.shown.file)
      paint_picture(ctx, image.raw, (0, 0, image.width, image.height), (x + r[1], y + r[2], r[3], r[4]))
      # The places from the rest of the page have pins of another colour, under the map's own. The one that the
      # mouse is on, here or on its contact's card, has a ring round its head.
      hot = other_at(v)
      for o in map_others(v)
        at = other_point(v, o)
        at === nothing && continue
        (o === hot || marked(v, o.name)) && disc(ctx, x + at[1], y + at[2] - 26, 15.5, tint(OTHER_PIN[1], 0.35))
        pin_ink(ctx, x + at[1], y + at[2], fill=OTHER_PIN[1], line=OTHER_PIN[2])
      end
      pin = map_pin(v)
      pin === nothing && return
      at = Maps.point(pin, map_middle(v), map_zoom(v), w, h)
      0 <= at[1] <= w && 0 <= at[2] <= h && pin_ink(ctx, x + at[1], y + at[2])
    end
  end
end

cursor(::MapView) = :arrow
# UI.jl has no open hand, so a map that a drag can move has the hand that points
cursor(a::MapArea) = map_moves(a.of) || other_at(a.of) !== nothing ? :hand : :arrow
onpinch(v::MapView, ev::Pinch) = pinch_open(v, ev)

# A press on the map starts a drag that moves the map, or a click that moves the place. The press is the
# map's own, so the page's text takes no caret and no selection from it. With ⌥ held, the press shows the
# block's lines, as it does on any block. A page that can't be changed takes no drag and no click.
onkey(a::MapArea, ev::KeyPress{Keys.mouse_left}) = begin
  v = a.of
  # A click on the pin of a place from the rest of the page goes to the place's line
  o = only_held(v, Keys.opt) ? nothing : other_at(v)
  o === nothing || (hide_tooltip!(ev.window); return show_line!(editor(v), o.line))
  (only_held(v, Keys.opt) || !map_moves(v)) && return nothing
  w = ev.window
  focus(editor(v))
  v.grab = (from=(num(w.mouse[1]), num(w.mouse[2])), middle=map_middle(v), dragged=false)
  handled
end

# While the button is down, the mouse is the map's wherever it goes, so the page doesn't select text behind it
onmouse(a::MapArea, ev::MouseMove) = begin
  v = a.of
  g = v.grab
  if g === nothing
    # The mouse on the pin of a place from the rest of the page says whose place it is
    o = other_at(v)
    o === nothing && return nothing
    at = other_point(v, o)
    show_tooltip!(ev.window, tip_label(o.name * "  ·  " * o.place), px(v.box[1] + at[1] - 11), px(v.box[2] + at[2] - 37), 22px, 37px, placement=:top, gap=4px)
    return nothing
  end
  Keys.mouse_left in ev.window.keys || (map_drop!(v); return handled)
  dx, dy = num(ev.position[1]) - g.from[1], num(ev.position[2]) - g.from[2]
  (g.dragged || hypot(dx, dy) >= MAP_SLACK) || return handled
  g.dragged || (v.grab = merge(g, (dragged=true,)))
  zoom = map_zoom(v)
  v.at = Maps.held(Maps.moved(g.middle, dx, dy, zoom), zoom, Maps.TALL)
  handled
end

onkey(a::MapArea, ::KeyRelease{Keys.mouse_left}) = a.of.grab === nothing ? nothing : (map_drop!(a.of); handled)
# The button can come up while the mouse is off the map, where the map doesn't hear of it
block_tick!(v::MapView) = (v.grab !== nothing && !held(v, Keys.mouse_left) && map_drop!(v); v)

"""
The mouse button came up. After a drag, the middle of what shows is written
as the block's `centre` line. After a click, the block's place becomes the
latitude and the longitude of the point that was clicked, and the middle that
showed is written too, so the map stays where it is, with the picture that it
had, and only the pin moves. ⌘Z takes either back.
"""
map_drop!(v::MapView) = begin
  g, v.grab = v.grab, nothing
  at, v.at = v.at, nothing
  (g === nothing || !map_changes(v)) && return v
  s = v.data
  if g.dragged
    at === nothing && return v
    s.centre = Maps.rounded(at)
  else
    clicked = Maps.latlon((g.from[1] - v.box[1], g.from[2] - v.box[2]), g.middle, map_zoom(v), v.box[3], v.box[4])
    s.centre === nothing && (s.centre = g.middle)
    s.place = Maps.text(clicked)
  end
  write_block!(v, MAP, Maps.written(s))
  v
end

act!(v::MapView, action, w) = begin
  if action == :open
    # Only a window that's on the screen opens another app
    (on_screen(v) || Maps.OPENER[] !== Maps.open_app) && Maps.open_place(v.data.place)
  elseif action == :home
    v.data.centre = nothing
    write_block!(v, MAP, Maps.written(v.data))
  elseif action isa Tuple && action[1] == :zoom
    Maps.zoom!(v.data, action[2]) && write_block!(v, MAP, Maps.written(v.data))
  end
  handled
end

"""
The map as HTML: its picture with the pin drawn in it, when a picture is
kept, and the address under it as a link to Apple Maps. The picture is in the
page itself, so the page needs no other file. A page of HTML is light, so it
gets the light map when that one is kept. Nothing is asked of Apple's maps
for it.
"""
map_html(e, v::MapView) = begin
  s = v.data
  isempty(s.place) && return nothing
  found = Maps.found!(media_dir(), s.place, start=false)
  facts = found.state == :there ? Maps.facts(found.file) : nothing
  pin = something(Maps.coordinates(s.place), facts === nothing ? nothing : (facts.lat, facts.lon), Some(nothing))
  middle = something(s.centre, pin, Some(nothing))
  wide, zoom = map_wide(v), map_zoom(v)
  # The picture that the block asks for, light or else dark, or else the picture that the map shows now
  picture = nothing
  if middle !== nothing
    middle = Maps.rounded(middle)
    kept = [Maps.picture!(media_dir(), middle, zoom, wide, Maps.TALL, dark, start=false) for dark in (false, true)]
    k = findfirst(p -> p.state == :there, kept)
    k === nothing || (picture = (file=kept[k].file, zoom=zoom, centre=middle, wide=wide))
  end
  picture === nothing && v.shown !== nothing && isfile(v.shown.file) && map_shows(v) && (picture = v.shown)
  address = escape(facts === nothing || isempty(facts.address) ? s.place : facts.address)
  shows = ""
  if picture !== nothing && whole_picture(picture.file)
    at = pin === nothing ? nothing : Maps.point(pin, picture.centre, picture.zoom, picture.wide, Maps.TALL)
    inside = at !== nothing && 0 <= at[1] <= picture.wide && 0 <= at[2] <= Maps.TALL
    bytes = inside ? pinned_png(picture.file, at) : read(picture.file)
    shows = "<img src=\"$(Maps.data_uri(bytes))\" alt=\"A map of $address\" width=\"$(picture.wide)\">\n"
  end
  "<div class=\"diagram\">\n$shows<p><a href=\"$(escape(Maps.link(s.place)))\">$address</a></p>\n</div>"
end

BLOCKS[MAP] = MapView
block_name(::Type{MapView}) = "Map"
block_icon(::Type{MapView}) = "geo-alt"
block_insert(::Type{MapView}) = ("Map", ["```$MAP", "", "```"], (2, 0))
block_html(e, v::MapView) = map_html(e, v)

# --- the places that a map has from the rest of its page ------------------------------------------
#
# A map shows more than its own place. Each address of a contact of the
# page has a pin on the map too, in another colour, and so has the address
# in the page's front matter. The mouse over such a pin says whose it is, and
# a click goes to its line of the page. A map with no place of its own shows
# all of those places, and is as close as shows them all.
#
# The map asks: `block_places(lang, lines)` says which places a block of one
# kind gives, and `page_places` gathers them. A kind of block that has a place
# joins in with a line there. While the mouse is on a contact's card, its pin
# is marked, and the other way round: see "one thing in many parts of the page".

const OTHER_PIN = (colorant"#2a78d6", colorant"#1d5fb0")   # what fills the pin of a place from the page, and the line round it
const PIN_REACH = 14.0   # px from the middle of a pin's head that the mouse is still on the pin

"""
The places that a block in the language `lang` gives the maps of its page:
each with the name of whose place it is, the place as the block has it, and
the line of the block that it's on. `lines` are the lines of the block. A
block of contacts gives the address of each contact that has one.
"""
block_places(lang::AbstractString, lines) =
  haskey(BLOCKS, lang) ? block_places(BLOCKS[lang], lines) : @NamedTuple{name::String, place::String, line::Int}[]

"""
Every place that the page gives its maps, with the line of the page that
each is on: the address in the page's front matter, and what each block
gives. They're found again when the page has changed.
"""
page_places(e) = begin
  b = e.buf
  get!(e.flows, (:places, b.path, b.version)) do
    out = @NamedTuple{name::String, place::String, line::Int}[]
    matter = 2:front_matter(b.lines)-1
    # The place is called what the front matter calls the page, or else what the page's file is called
    title = something((match(r"^title\s*:\s*(\S.*?)\s*$"i, b.lines[i]) for i in matter)..., Some(nothing))
    called = title === nothing ? splitext(basename(b.path))[1] : String(strip(title[1], ['"', '\'']))
    for i in matter
      m = match(r"^(?:address|place|site)\s*:\s*(\S.*?)\s*$"i, b.lines[i])
      m === nothing || push!(out, (name=called, place=String(strip(m[1], ['"', '\''])), line=i))
    end
    ks = kinds(b)
    for (i, k) in enumerate(ks)
      (k.kind == Kind.fence && k.level == 0 && haskey(BLOCKS, k.lang)) || continue
      t = codeblock(b, i)[2]
      (t > i && ks[t].kind == Kind.fence && ks[t].level == 1) || continue
      append!(out, ((name=p.name, place=p.place, line=i + p.line) for p in block_places(BLOCKS[k.lang], b.lines[i+1:t-1])))
    end
    out
  end
end

"""
The places from the rest of the page that the map `v` can show: each with its
name, its line of the page, and its latitude and longitude. A place is one of
them once Apple's maps have said where it is. With `runs`, the program that
asks them starts for a place that isn't kept yet. The map's own place isn't
one of them.
"""
map_others(v::MapView, runs::Bool=false) = begin
  e = editor(v)
  kept = get(e.flows, (:map_others, objectid(v)), nothing)
  kept !== nothing && kept[1] == (e.buf.version, map_place(v)) && kept[2] && return kept[3]
  out = @NamedTuple{name::String, place::String, line::Int, at::Maps.LatLon}[]
  whole = true
  for p in page_places(e)
    lowercase(Maps.query(p.place)) == map_place(v) && continue
    at = Maps.coordinates(p.place)
    if at === nothing
      found = Maps.found!(media_dir(), p.place; start=runs)
      facts = found.state == :there ? Maps.facts(found.file) : nothing
      if facts === nothing
        # The window looks again when the program may have finished
        found.state in (:coming, :none) && (whole = false; isfinite(found.wait) && redraw_in!(v, max(found.wait, 0.05)))
        continue
      end
      at = (facts.lat, facts.lon)
    end
    push!(out, (name=p.name, place=p.place, line=p.line, at=at))
  end
  e.flows[(:map_others, objectid(v))] = ((e.buf.version, map_place(v)), whole, out)
  out
end

"The middle and the zoom of a map with no place of its own, which shows the places from the rest of its page. It's nothing when the map has a place, or the page gives none that's known."
map_around(v::MapView) = begin
  isempty(v.data.place) || return nothing
  ats = [o.at for o in map_others(v)]
  isempty(ats) ? nothing : Maps.around(ats, v.data.zoom, map_wide(v), Maps.TALL)
end

"The point of the map that shows now where the place `o` from the page is, in px from the map's top left corner, or nothing when it isn't in the map"
other_point(v::MapView, o) = begin
  middle = map_middle(v)
  middle === nothing && return nothing
  _, _, w, h = v.box
  at = Maps.point(o.at, middle, map_zoom(v), w, h)
  0 <= at[1] <= w && 0 <= at[2] <= h ? at : nothing
end

"The place from the page whose pin the mouse is on, or nothing"
other_at(v::MapView) = begin
  w = window_of(v)
  a = get(v.parts, :area, nothing)
  (w === nothing || a === nothing || !ishovered(a) || v.grab !== nothing || !map_shows(v)) && return nothing
  x, y = num(w.mouse[1]) - v.box[1], num(w.mouse[2]) - v.box[2]
  for o in map_others(v)
    at = other_point(v, o)
    # The head of a pin is over its point
    at !== nothing && hypot(x - at[1], y - (at[2] - 26)) <= PIN_REACH && return o
  end
  nothing
end

pointed(v::MapView) = (o = other_at(v); o === nothing ? nothing : o.name)
