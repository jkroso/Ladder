# Draws a page of HTML: reads it, works out its styles, lays it out and draws
# it with Skia, with no browser.
#
#     p = page(html; wide=700)
#     p.wide, p.tall             # how big the page is, in px
#     draw(canvas, p)            # draw it, with its top left corner at the canvas's
#     draw(canvas, p; top=400, bottom=900)   # or only what's between two heights of it
#     draw(canvas, p; at=2.5)    # with its GIFs as they are 2.5 seconds after it was first shown: `changes(p, 2.5)` says when to draw again
#     save(p, "page.png")        # a picture of all of it
#     p.links                    # each rectangle of the page that's a link, and where it goes
#     p.words                    # its words in the order that the HTML has them, with where each letter is
#     link(p, x, y)              # the link at a point of the page, or nothing
#
# `zoom` makes everything in the page that much bigger, as a browser's zoom
# does. The page is still `wide` px wide.
#
# The page runs no script here: `live` in live.jl makes a page whose scripts
# run. The page asks the web for nothing. A picture that's
# written into the page (`src="data:..."`) is drawn. For any other picture,
# and for a sheet of CSS or a font that the page names, `load(address)` is
# asked for the bytes of its file, or nothing. With none, a picture is an
# empty box. `base` is the address of the page, which the addresses in it are
# from.
#
# With `high`, the page is seen through a window that high, as in a browser:
# `height: 100%` of the page and `100vh` are that high, and a box that's fixed
# is placed in it. With none, the page is as tall as its content.
#
# What it draws: the HTML and the CSS of today, without what needs a script or
# the passing of time. See the top of each file for what that file knows.
#
# What it doesn't draw yet: text from right to left in its own order, and text
# down the page. Letters that join, as in Arabic, and an emoji that's made of
# several characters. `::first-letter` and `::first-line`. `backdrop-filter`.
# A picture as a border (`border-image: url(...)`). The page in an <iframe>:
# a video of YouTube in one shows as its picture, with its name and an arrow,
# and the frame is a link to the video's page (see embed.jl).
#
# What moves: with `at`, the page is drawn as it is that many seconds after
# it was first shown. Each animation of its CSS is as far as it has got then.
# A <video> that plays shows its picture of that time, and so does a picture
# file that moves, like a GIF. A video makes no sound. With a `Clock` too, a
# style that changes from one layout to the next takes the time that its
# `transition` says. A <canvas> shows what the page's scripts drew on it: see
# canvas.jl.
#
# The parts: dom.jl reads the HTML into a tree. css.jl reads CSS. style.jl
# works out the style of each element. box.jl makes the boxes. layout.jl gives
# each its size and place. paint.jl draws them. svg.jl draws an SVG. text.jl
# finds fonts and measures text. video.jl reads the pictures of a video file.
# canvas.jl is the surface of a <canvas> and the drawing on it, and context.jl
# gives it to a page's scripts. For a page with scripts: jsc.jl runs
# JavaScript, script.jl and window.jl give a script the page, and live.jl lays
# the page out again after a script changes it. view.jl shows a page in a
# window that UI.jl draws. browser.jl is a web view: it gets a page from the
# web with files.jl, scrolls it, and takes the mouse and the keyboard for it.
# form.jl says what a form sends.

@use Skia
@use "github.com/jkroso/MiniFB.jl/skia" srgb
@use Base64: base64decode
@use "./dom" document Document
@use "./css" resolve
@use "./svg" => Svg
@use "./video" => Film
@use "./embed" => Embed
@use "./box" boxes Box
@use "./style" styles isauto ispercent Clock commit!
@use "./layout" layout!
@use "./paint" => Paint
@use "./css" DARK
using Base.ScopedValues: with

"""
The pictures of a page: each address that it names, with the picture's size
and Skia's picture, or nothing. `Pictures(load)` makes an empty set, where
`load(address)` gives the bytes of a picture that isn't written into the
page. A set that's given to `page` again saves reading each picture again,
as when the page is laid out for another width.
"""
mutable struct Pictures
  found::Dict{String,Any}
  load::Function
  films::Dict{String,Any}   # each video that the page names, or nothing
end
# A `load` can give `:waiting` for a file that's on its way: live.jl gives that to a script, which can wait. A picture, a
# sheet or a font that isn't here yet is left out, as one that can't be had is.
Pictures(load) = finalizer(release, Pictures(Dict{String,Any}(), src -> (got = load(src); got === :waiting ? nothing : got), Dict{String,Any}()))

"Forget the pictures that weren't there, so that they're asked for again: one may have come from the web since"
retry!(p::Pictures) = (filter!(kv -> kv.second !== nothing, p.found); filter!(kv -> kv.second !== nothing, p.films); p)

# No page shows a picture bigger than this many pixels across or down, so a bigger one is kept at this size
const MOST = 2048
const SAMPLING = Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0), Skia.SK_FILTER_MODE_LINEAR, Skia.SK_MIPMAP_MODE_LINEAR)

"""
Skia's picture of the bytes of a picture's file, with the size that the file
says, or nothing. The picture is read into pixels here, once. A picture that's
left as the bytes of its file is read again each time it's drawn, which makes
a page with a photo slow to scroll.
"""
decode(bytes::Vector{UInt8}) = begin
  isempty(bytes) && return nothing
  data = Skia.sk_data_new_with_copy(bytes, Csize_t(length(bytes)))
  file = Skia.sk_image_new_from_encoded(data)
  Skia.sk_data_unref(data)
  # A drawing in SVG is drawn here, since Skia reads none
  file == C_NULL && return occursin("<svg", String(bytes[1:min(end, 4096)])) ? Svg.image(bytes) : nothing
  w, h = Int(Skia.sk_image_get_width(file)), Int(Skia.sk_image_get_height(file))
  (w > 0 && h > 0) || (Skia.sk_image_unref(file); return nothing)
  k = min(1.0, MOST / max(w, h))
  tw, th = max(1, round(Int, w * k)), max(1, round(Int, h * k))
  # The pixels are sRGB, so Skia converts a picture with a colour profile of its own, such as a Display P3 photo,
  # as it draws it here. Without a colour space Skia would keep the picture's numbers, and the photo would look dull.
  info = Ref(Skia.sk_image_info_t(srgb[], Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, tw, th))
  image = GC.@preserve info begin
    surface = Skia.sk_surface_make_raster_n32_premul(pointer_from_objref(info), C_NULL)
    # With no room for the pixels, the picture stays as the bytes of its file
    surface == C_NULL && return (w, h, Ptr{Cvoid}(file))
    canvas = Skia.sk_surface_get_canvas(surface)
    Skia.sk_canvas_clear(canvas, 0x00000000)
    paint = Skia.sk_paint_new()
    Skia.sk_paint_set_antialias(paint, true)
    from = Ref(Skia.sk_rect_t(0f0, 0f0, Float32(w), Float32(h)))
    to = Ref(Skia.sk_rect_t(0f0, 0f0, Float32(tw), Float32(th)))
    Skia.sk_canvas_draw_image_rect(canvas, file, from, to, Ref(SAMPLING), paint, Skia.SRC_RECT_CONSTRAINT_FAST)
    Skia.sk_paint_delete(paint)
    made = Skia.sk_surface_make_image_snapshot(surface)
    Skia.sk_surface_unref(surface)
    made
  end
  Skia.sk_image_unref(file)
  image == C_NULL ? nothing : (w, h, Ptr{Cvoid}(image))
end

"The bytes that an address like `data:image/png;base64,...` holds, or nothing"
inline_bytes(src) = begin
  m = match(r"^data:[^,]*?(;base64)?,(.*)$"is, src)
  m === nothing && return nothing
  try
    m[1] === nothing ? Vector{UInt8}(replace(m[2], r"%([0-9a-fA-F]{2})" => s -> Char(Base.parse(UInt8, s[2:3], base=16)))) :
                       base64decode(replace(m[2], r"\s" => ""))
  catch
    nothing
  end
end

"What the set has for the address `src`: a picture's size and Skia's picture, the `Reel` of a picture file that moves, or nothing"
lookup(p::Pictures, src::AbstractString) = begin
  src = String(strip(src))
  isempty(src) && return nothing
  get!(p.found, src) do
    bytes = startswith(lowercase(src), "data:") ? inline_bytes(src) : p.load(src)
    bytes === nothing && return nothing
    bytes = Vector{UInt8}(bytes)
    # A GIF, or a PNG or a WebP that moves, is read one picture at a time: see video.jl
    moving = Film.reel(bytes)
    moving === nothing ? decode(bytes) : moving
  end
end

# Of a picture file that moves, this is its first picture
(p::Pictures)(src::AbstractString) = begin
  found = lookup(p, src)
  found isa Film.Reel ? (found.wide, found.high, found.first.image) : found
end

"""
The picture at the address `src` as it is `at` seconds after its page was
first shown, and when it stops changing: 0 for a picture that doesn't move,
and Inf for one that never stops. With no time, a picture that moves is its
first picture. The third thing that it gives is when the picture next
changes. `held` is given each picture of a moment that's handed out, so that
Skia's picture lasts for as long as `held` does.
"""
moment(p::Pictures, src::AbstractString, at, held) = begin
  found = lookup(p, src)
  found isa Film.Reel || return (found, 0.0, Inf)
  shown = at === nothing ? found.first : Film.frame(found, at)
  push!(held, shown)
  ((found.wide, found.high, shown.image), Film.stops(found), Film.after(found, something(at, 0.0)))
end

"""
What stands for the page at the address `src` in an <iframe>, when that page
is a video that embed.jl knows: `watch` is the address of the video's page
for a browser, `title` is the video's name, and `picture` is its picture as
`p` has it, or nothing. YouTube says the name and the picture in a file of
JSON, which `p`'s `load` is asked for. Until that has come, a video has no
name, and a list of videos has no picture. The picture is the biggest that
YouTube has of the video. Nothing for any other page.
"""
embed(p::Pictures, src::AbstractString) = begin
  v = Embed.video(src)
  v === nothing && return nothing
  said = p.load(v.about)
  title, picture = said === nothing ? ("", "") : Embed.facts(said)
  isempty(picture) && (picture = v.picture)
  isempty(picture) && return (watch=v.watch, title=title, picture=nothing)
  # The biggest picture that has come: a video with no big picture gives no file at that address
  shown = nothing
  for address in Embed.sharper(picture)
    shown = p(address)
    shown === nothing || break
  end
  (watch=v.watch, title=title, picture=shown)
end

"The video at the address `src`, as video.jl reads it, or nothing"
film(p::Pictures, src::AbstractString) = begin
  src = String(strip(src))
  isempty(src) && return nothing
  get!(p.films, src) do
    bytes = startswith(lowercase(src), "data:") ? inline_bytes(src) : p.load(src)
    bytes === nothing ? nothing : Film.video(Vector{UInt8}(bytes), src)
  end
end

release(p::Pictures) = begin
  for found in values(p.found)
    found === nothing ? nothing : found isa Film.Reel ? close(found) : Skia.sk_image_unref(found[3])
  end
  empty!(p.found)
  foreach(v -> v === nothing || close(v), values(p.films))
  empty!(p.films)
end

"A page of HTML that's laid out and ready to draw"
struct Page
  wide::Float64
  tall::Float64
  zoom::Float64
  list::Paint.List
  links::Vector{Paint.Link}
  words::Vector{Paint.Words}
  pictures::Pictures
  root::Box       # the box of its <html> element, with the boxes of the rest in it
  at::Union{Float64,Nothing}   # how many seconds after it was first shown the page looks like this, or nothing for the page as it comes to rest
  until::Float64  # how many seconds after it was first shown the page stops changing: Inf when it never does, 0 when nothing in it moves
  held::Vector{Any}   # the picture files that move, with their pictures of this moment that the page draws: they last for as long as the page does
  next::Float64   # when the page next looks different, in seconds after it was first shown: `at` itself while something changes all the time
end

"True when the page will look different a moment later: an animation or a transition of it runs, a video in it plays, or a picture in it moves"
moving(p::Page) = p.at !== nothing && p.at < p.until

"""
True when the page looks different `at` seconds after it was first shown
than it's drawn: lay it out again then. A page whose only motion is a picture
file like a GIF is due when that file shows its next picture.
"""
due(p::Page, at) = moving(p) && at >= p.next

"""
Start or stop the <video> at the point `(x, y)` of the page, as a click on it
does in a browser, when the video shows its buttons (`controls`). True when
there was one: lay the page out again then, to see it play.
"""
toggle!(p::Page, x, y) = begin
  x, y = x / p.zoom, y / p.zoom
  i = findlast(q -> q.element.tag == "video" && q.left <= x < q.left + q.wide && q.top <= y < q.top + q.tall, p.list.places)
  (i === nothing || !haskey(p.list.places[i].element.attrs, "controls")) && return false
  e = p.list.places[i].element
  at, again = something(p.at, 0.0), haskey(e.attrs, "loop")
  how = Film.play(e)
  Film.spot(how, at, again)[2] ? Film.pause!(how, at, again) : Film.play!(how, at, again)
  true
end

# What lets a page that's wider than its window be as narrow as the window: a table, a picture or a block of code
# shrinks to the page, and a long word breaks
const FIT = """
table { max-width: 100% !important }
img, video { max-width: 100% !important }
img[width][height] { height: auto !important }
pre { white-space: pre-wrap !important }
body { overflow-wrap: break-word !important }
[data-fit-page] { width: auto !important; min-width: 0 !important }
table[data-fit-page] { width: 100% !important }
"""

"Mark each element under `b` whose style says a width that makes it wider than `wide` px, so that `FIT` takes the width away"
mark_wide!(b::Box, wide) = begin
  s = b.style
  if b.element !== nothing && b.kind != :image && b.kind != :text && !isauto(s.width) && !ispercent(s.width) && b.width > wide + 1
    b.element.attrs["data-fit-page"] = ""
  end
  foreach(k -> mark_wide!(k, wide), b.children)
end

"""
Lay out the page that `html` writes, `wide` px wide. `load(address)` gives the
bytes of a picture that the page names, or nothing. `pictures` is a set of
pictures to use in place of `load`: see `Pictures`. `css` is CSS that goes
after the page's own.

With `fit`, a page whose content is wider than `wide` is made to fit: a width
that the HTML gives a table or a cell, wider than the page, is taken away, and
a picture or a block of code shrinks to the page. Outlook gives the table
round an email the width of its sender's window, which can be 2000 px. A page
whose content still can't be that narrow is as wide as its content, up to
`widest` px, and `p.wide` says how wide that is.

`high` is how high the window that the page is seen through is, or nothing
for a page that's as tall as its content. `base` is the address of the page.

With `dark`, the page is laid out for a screen in dark mode: what it says
for `@media (prefers-color-scheme: dark)` is for it, and a page whose
`color-scheme` says it can be dark has the dark colours of the system.

`at` is how many seconds ago the page was first shown: its animations are
drawn as they are at that time. `moving(p)` says whether the page will look
different a moment later, and `p.until` says when it stops changing. With no
time, the page is drawn as it comes to rest. Give the same `clock`, a
`Clock()`, each time that one document is laid out again as time passes: an
animation that an element gets later starts then, and a style that changes
takes the time that its `transition` says.
"""
page(html::AbstractString; kw...) = page(document(html); kw...)

"Lay out the page of a document that's read already. live.jl lays a page out again with this after a script changes its document."
page(doc::Document; dark=false, wide=700, zoom=1.0, load=src -> nothing, pictures=Pictures(load), css="", fit=false, widest=2000, high=nothing, base="", at=nothing,
     clock=nothing) = with(DARK => dark) do
  from = isempty(doc.base) ? String(base) : resolve(base, doc.base)
  inner = wide / zoom
  window = high === nothing ? NaN : high / zoom
  seen = isnan(window) ? 800.0 : window   # what `100vh` is of, when there's no window
  held, flicker, soon = Any[], 0.0, Inf   # the pictures of this moment, when the last picture file that moves stops, and when the first of them changes
  find = src -> begin
    found, stops, next = moment(pictures, resolve(from, src), at, held)
    flicker, soon = max(flicker, stops), min(soon, next)
    found
  end
  # A picture that moves is drawn as it is when the page is drawn: the page holds it, to say when it next changes
  reels = src -> begin
    found = lookup(pictures, resolve(from, src))
    found isa Film.Reel || return nothing
    any(x -> x === found, held) || push!(held, found)
    found
  end
  at === nothing || (at = max(0.0, Float64(at)))
  until = 0.0
  lay(across, extra) = begin
    make(containers) = begin
      # A font or a sheet can be written into the page as a `data:` address, as a picture can
      sheets = address -> startswith(lowercase(address), "data:") ? inline_bytes(address) : pictures.load(address)
      look = styles(doc, across; extra, high=seen, load=sheets, base=String(base), containers, at, clock, commit=false)
      root = boxes(doc, look; pictures=find, films=src -> film(pictures, resolve(from, src)), reels, embeds=src -> embed(pictures, resolve(from, src)), at,
                   wide=across, high=seen)
      until = look.until
      (look, root, layout!(root, across, doc.mode; high=window))
    end
    look, root, tall = make(nothing)
    if look.contained
      # Some rules ask how big the box that an element is in is. Now that each box has a size, the styles are worked out again.
      sizes = IdDict{Any,Tuple{Float64,Float64,String}}()
      note(b::Box) = begin
        if b.element !== nothing && b.style.container != :none
          sizes[b.element] = (b.width - b.padding[2] - b.padding[4] - b.border[2] - b.border[4], b.height - b.padding[1] - b.padding[3] - b.border[1] - b.border[3], b.style.containername)
        end
        foreach(note, b.children)
        foreach(note, b.over)
      end
      note(root)
      look, root, tall = make(sizes)
    end
    (root, tall, Paint.list(root, across, tall; pictures=find, base=from, at))
  end
  root, tall, l = lay(inner, css)
  if fit && Paint.right(l) > inner + 1
    mark_wide!(root, inner)
    root, tall, l = lay(inner, css * FIT)
    needs = min(widest / zoom, ceil(Paint.right(l)))
    if needs > inner + 1
      inner = needs
      root, tall, l = lay(inner, css * FIT)
    end
  end
  # The styles of the last time are the page's: the clock keeps what they noted
  clock === nothing || commit!(clock)
  z(link::Paint.Link) = (left=link.left * zoom, top=link.top * zoom, wide=link.wide * zoom, tall=link.tall * zoom, url=link.url)
  z(w::Paint.Words) = (before=w.before, top=w.top * zoom, tall=w.tall * zoom, edges=w.edges .* zoom, letters=w.letters, from=w.from, seen=w.seen .* zoom)
  Page(ceil(inner * zoom), ceil(tall * zoom), Float64(zoom), l, zoom == 1 ? l.links : map(z, l.links), zoom == 1 ? l.words : map(z, l.words), pictures, root, at, max(until, flicker), held,
       at === nothing ? Inf : at < until ? at : soon)
end

"""
Draw the page on a Skia canvas, with its top left corner at `(x, y)`. With
`top` and `bottom`, only what's between those two heights of the page is
drawn.

With `at`, a picture of the page that moves, like a GIF, is drawn as it is
that many seconds after the page was first shown, with no new layout:
`changes(p, at)` says when to draw the page again. With none, it's drawn as
it was when the page was laid out. Only a picture in an <img> does this: one
behind a box, and all else that moves, needs a new layout.
"""
draw(canvas, p::Page; x=0.0, y=0.0, top=-Inf, bottom=Inf, at=p.at) = begin
  Skia.sk_canvas_save(canvas)
  Skia.sk_canvas_translate(canvas, Float32(x), Float32(y))
  Skia.sk_canvas_scale(canvas, Float32(p.zoom), Float32(p.zoom))
  Paint.draw(canvas, p.list; top=top / p.zoom, bottom=bottom / p.zoom, at)
  Skia.sk_canvas_restore(canvas)
end

"""
When the page next draws differently with no new layout, in seconds after it
was first shown, for a page that's drawn `at` seconds after that: when the
first of its pictures that move shows its next picture. Inf with none, and
when they have all stopped.
"""
changes(p::Page, at) = minimum(Float64[Film.after(r, at) for r in p.held if r isa Film.Reel]; init=Inf)

"The link at the point `(x, y)` of the page, or nothing"
link(p::Page, x, y) = begin
  # A link that's written later is drawn over one that's written before it
  i = findlast(l -> l.left <= x <= l.left + l.wide && l.top <= y <= l.top + l.tall, p.links)
  i === nothing ? nothing : p.links[i]
end

"""
Save a picture of the page as a PNG file, with `scale` pixels to the px.
`background` is the colour behind a page that has none of its own.
"""
save(p::Page, path::AbstractString; scale=2.0, background=0xffffffff) = begin
  w, h = max(1, round(Int, p.wide * scale)), max(1, round(Int, p.tall * scale))
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_PREMUL, w, h))
  GC.@preserve info begin
    surface = Skia.sk_surface_make_raster_n32_premul(pointer_from_objref(info), C_NULL)
    surface == C_NULL && error("Skia could not make a picture $w by $h")
    canvas = Skia.sk_surface_get_canvas(surface)
    Skia.sk_canvas_clear(canvas, background)
    Skia.sk_canvas_scale(canvas, Float32(scale), Float32(scale))
    draw(canvas, p)
    image = Skia.sk_surface_make_image_snapshot(surface)
    encoded = Skia.sk_encode_png(C_NULL, image, Int32(6))
    write(path, unsafe_wrap(Array, Ptr{UInt8}(Skia.sk_data_get_data(encoded)), Skia.sk_data_get_size(encoded)))
    Skia.sk_data_unref(encoded)
    Skia.sk_image_unref(image)
    Skia.sk_surface_unref(surface)
  end
  path
end
