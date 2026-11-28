# A page as slides
#
# ⌃⌘⇧P, or Show as Slides in the page's menu, shows the page one part at a
# time, for when you show a plan to someone. A slide starts at each heading of
# level 1 or 2, and at each line across the page. slides.jl says which lines
# each slide shows.
#
#   - The window shows one slide and nothing else of the app: no sidebar, and
#     nothing in the top bar. The slide is in the middle of the window. Its
#     text is up to twice as big as the page's, so that the slide suits the
#     window's height. A slide that's too tall at the page's own size scrolls.
#   - →, ↓, Space, Page Down and Return go to the next slide. ←, ↑, Page Up
#     and ⇧Space go back. Home and End go to the first slide and the last.
#   - A click on the right half of the window goes on, and a click on the left
#     half goes back. A click on a to-do item's box ticks it, and a click on a
#     link opens it. A part of a block that takes clicks, like the button of a
#     video, still takes them.
#   - Everything in a slide shows as it does in the page. A video plays, and
#     stops when another slide shows.
#   - Nothing that's typed changes the text, and there's no caret.
#   - Esc, or ⌃⌘⇧P again, shows the page again, with the caret at the start of
#     the slide that showed last.
#   - When the file changes on the disk, the slides show the new text. The
#     slide with the same number stays, or the last one when there are fewer.
#
# The slides belong to one window. The document draws a slide as it draws the
# page: `layout!` lays out the page, and `slide_items` keeps the items of the
# slide's lines. The editor's zoom is bigger while a slide shows. The page has
# its own zoom again when the slides end.

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of focus handled version
@use "github.com/jkroso/UI.jl/Interface/draw" cursor hittest redraw_in!
@use "github.com/jkroso/UI.jl/Interface/media" silence!
@use "../markdown" spans
@use "./slides" => Slides
@use "../base" exports...
@use "../window/fill_view" filled
@use "../files/file_view" exports...
@use "../blocks/columns_view" exports...
@use "../files/long_file" exports...

export SlideShow, SLIDE_COMMANDS, slideshow, slide_room, page_slides, show_slides!, end_slides!, slides!,
       go_slide!, slide_tick!, own_zoom!, zoom_to!, usual_zoom!, slide_span, span_tall, slide_items,
       fit_slide!, slide_key!, takes_click, slide_press!, slide_cursor, slides_over, SlidesState

"The slides of a page, while they show in a window"
Base.@kwdef mutable struct SlideShow
  path::String = ""                    # the page. The slides end when another file shows.
  at::Int = 1                          # the number of the slide that shows
  first::Int = 1                       # the number of the slide that showed first
  list::Vector{Slides.Slide} = Slides.Slide[]
  version::Int = -1                    # the version of the page that `list` was read from
  caret::Pos = (1, 0)                  # where the page's caret was in the last frame
  zoom::Float64 = 1.0                  # the page's own zoom
  set::Float64 = 1.0                   # the zoom that the slides last gave the editor
  scale::Float64 = 1.0                 # how many times bigger than the page's text the slide's text is
  talls::Vector{px} = px[]             # how tall each slide is at the page's own zoom
  measured::Any = nothing              # the page, the window's width and the settings that `talls` was worked out for
  scales::Dict{Tuple{Int,px},Float64} = Dict{Tuple{Int,px},Float64}()   # the scale of each slide that has shown, for the room it had
  fitted::Any = nothing                # the slide and the room that `scale` is for
  fitted_at::Float64 = 0.0             # when `scale` was worked out
  measuring::Bool = false              # true while the whole page is laid out, to learn `talls`
  tall::px = 0px                       # how tall the slide was when it was last laid out
  seen::Union{Nothing,px} = nothing    # how tall it was in the first frame after `scale` was worked out
  panel::Bool = false                  # the sidebar showed before the slides did
  offset::px = 0px                     # how far the page was scrolled then
end

"The commands that do what they always do while the page shows as slides. A key of any other command does nothing."
const SLIDE_COMMANDS = (:save, :inspector)

"What a window keeps of the slides of a page"
Base.@kwdef mutable struct SlidesState
  show::Union{Nothing,SlideShow} = nothing   # the slides that show in the window, or nothing while the page shows
end

"The slides that show in the window of `e`, or nothing while the page shows"
slideshow(e) = state_of(e, SlidesState).show

"How tall a slide can be before it scrolls: the window's height, less the top bar and the room above and below the page's text"
slide_room(e) = max(0px, window_size(e)[2] - above_page(e) - PAGE_TOP - page_bottom(e))

"""
The slides of the page that shows. The blocks that a `columns` block puts
side by side stay on one slide, so a heading among them starts no slide.
"""
page_slides(e) = begin
  b = e.buf
  spans = [first(first(g.spans)):last(last(g.spans)) for g in column_groups(e) if !isempty(g.spans)]
  Slides.slides(b.lines, kinds(b), held=i -> any(span -> i in span, spans))
end

"""
Show the page as slides, from the slide that the caret is in. A page with
nothing to show stays as it is, and so does a file that isn't a page. Nothing
happens while something else fills the window, like a sketch or a picture.
"""
show_slides!(e) = begin
  b = e.buf
  (slideshow(e) === nothing && b.view == :markdown && !filled(e) && e.popup == :none) || return e
  list = page_slides(e)
  isempty(list) && return e
  finding(e) && close_find!(e)
  # A slide has no caret and nothing selected, and a drag on it selects nothing
  b.anchor = b.caret
  empty!(b.others)
  e.clicked = (0.0, (0, 0), 0)
  at = Slides.number(list, b.caret[1])
  state_of(e, SlidesState).show = SlideShow(path=b.path, at=at, first=at, caret=b.caret, zoom=e.zoom, set=e.zoom,
                                            panel=e.panel, offset=e.scroll.offset)
  # The sidebar goes at once, without sliding
  e.panel, e.slid = false, 0.0
  e.scroll.offset = 0px
  focus(e)
  e
end

"""
Show the page again. The sidebar and the page's zoom are what they were. The
caret is at the start of the slide that showed last, and that line is near the
top of the window. When that's the slide that showed first, with the caret in
it, the caret and the page stay where they were.
"""
end_slides!(e) = begin
  s = slideshow(e)
  s === nothing && return handled
  state_of(e, SlidesState).show = nothing
  zoom = own_zoom!(e, s)
  e.zoom == zoom || (e.zoom = zoom; empty!(e.flows); rerun!(e, :zoom))
  e.panel, e.slid = s.panel, 0.0
  b = get(e.buffers, s.path, nothing)
  b === nothing && return handled
  b.reading = false
  # Another file shows now. The page is where it was when it next shows.
  b === e.buf || return (b.offset = s.offset; handled)
  e.scroll.offset = s.offset
  list = page_slides(e)
  k = clamp(s.at, 1, max(1, length(list)))
  if !isempty(list) && !(k == s.first && Slides.number(list, b.caret[1]) == k)
    b.caret = b.anchor = (list[k].first, 0)
    hold!(e, list[k].first, 24px - PAGE_TOP)   # the next frame puts that line near the top of the window
    e.reveal = true
  end
  e.blink = time()
  e.goal = nothing
  focus(e)
  handled
end

"Show the page as slides, or show it as a page again"
slides!(e) = slideshow(e) === nothing ? show_slides!(e) : end_slides!(e)

"Show slide `k` from its top, or the first or the last slide when there's no slide `k`"
go_slide!(e, k) = begin
  s = slideshow(e)
  s === nothing && return handled
  k = clamp(k, 1, max(1, length(s.list)))
  k == s.at && return handled
  silence!()   # a video or a sound that the last slide was playing stops
  s.at = k
  e.scroll.offset = 0px
  window_of(e) === nothing || focus(e)   # a part of the last slide that had the keyboard doesn't show now
  handled
end

"""
In each frame while the slides show, before the page is laid out. The slides
are read again from a page that changed, and the slide with the same number
stays. The slides end when another file shows, or when the page has nothing
left to show. The page has no caret, and its sidebar stays away.
"""
slide_tick!(e) = begin
  s = slideshow(e)
  s === nothing && return
  b = e.buf
  (b.path == s.path && b.view == :markdown) || return end_slides!(e)
  if b.version != s.version
    s.list = page_slides(e)
    s.version = b.version
    isempty(s.list) && return end_slides!(e)
    s.at = clamp(s.at, 1, length(s.list))
  elseif b.caret != s.caret
    # Something sent the caret to a line, like a link to a heading or two clicks on a card of a board. That line's slide shows.
    go_slide!(e, Slides.number(s.list, b.caret[1]))
  end
  s.caret = b.anchor = b.caret
  b.reading = true
  e.panel = false
  # The page doesn't scroll to its caret, or to the line that it showed before a change
  e.reveal = false
  hold!(e, nothing)
  fit_slide!(e, s)
  nothing
end

"""
The page's own zoom while the slides show. When something else gave the editor
a zoom since the slides last did, like the settings window, that's the page's
zoom from then on.
"""
own_zoom!(e, s::SlideShow) = (e.zoom == s.set || (s.zoom = e.zoom; s.measured = nothing); s.zoom)

"Give the editor the zoom `z` for a slide. Text of another size is laid out again, and a live block that reads the size runs again."
zoom_to!(e, s::SlideShow, z) = begin
  e.zoom == z || (e.zoom = z; empty!(e.flows); rerun!(e, :zoom))
  s.set = z
end

"""
Give the editor the page's own zoom, before the settings are kept and given to
the other windows. The bigger text of a slide is no setting. The next frame
makes the slide's text bigger again.
"""
usual_zoom!(e) = begin
  s = slideshow(e)
  s === nothing && return e
  zoom_to!(e, s, own_zoom!(e, s))
  s.fitted = nothing
  e
end

"Which of `items` show the lines of `slide`, or nothing when none does"
slide_span(items, slide::Slides.Slide) = begin
  lo = findfirst(it -> it.last >= slide.first, items)
  hi = findlast(it -> it.first <= slide.last, items)
  lo === nothing || hi === nothing || hi < lo ? nothing : lo:hi
end

"How tall the items `span` of `items` are together"
span_tall(items, span) = items[last(span)].top + items[last(span)].tall - items[first(span)].top

"""
The items of the page that the window shows. While the page shows as slides,
they're the items of one slide's lines, in the middle of the room that the
window has for them. A slide that's taller than that room starts at the top.
"""
slide_items(e, items) = begin
  s = slideshow(e)
  (s === nothing || s.measuring || e.buf.path != s.path || !(s.at in eachindex(s.list))) && return items
  span = slide_span(items, s.list[s.at])
  span === nothing && return items
  s.tall = span_tall(items, span)
  by = px(round(num(max(0px, (slide_room(e) - s.tall) / 2)))) - items[first(span)].top
  [Item(it.first, it.last, it.top + by, it.tall, it.content) for it in items[span]]
end

"""
Give the editor the zoom that suits the slide that shows: the page's own zoom,
times the slide's scale. The scale is worked out once for each slide and the
room it has. To work it out, the whole page is laid out at its own zoom, to
learn how tall each slide is. Then the slide is laid out at the scales that
`Slides.fit` tries. It's all done again when the page changes, or the window's
width, or a setting that changes the text's size.
"""
fit_slide!(e, s::SlideShow) = begin
  b = e.buf
  zoom = own_zoom!(e, s)
  # A picture that came from the web a moment later makes the slide taller than it was fitted for
  if s.seen === nothing
    s.seen = s.tall
  elseif s.tall != s.seen
    time() - s.fitted_at < 0.25 ? redraw_in!(e, 0.25) : (s.measured = nothing)
  end
  key = (b.version, window_size(e)[1], zoom, e.widest, e.font, e.weight, e.code_scale, e.code_font, e.code_weight)
  if s.measured != key
    zoom_to!(e, s, zoom)
    s.measuring = true
    items = try layout!(e) finally s.measuring = false end
    s.talls = px[(span = slide_span(items, slide); span === nothing ? 0px : span_tall(items, span)) for slide in s.list]
    s.measured = key
    s.fitted = nothing
    empty!(s.scales)
  end
  room = slide_room(e)
  if s.fitted != (s.at, room)
    s.scale = get!(s.scales, (s.at, room)) do
      Slides.fit(num(s.talls[s.at]), num(room)) do scale
        zoom_to!(e, s, zoom * scale)
        layout!(e)
        num(s.tall)
      end
    end
    s.fitted, s.fitted_at, s.seen = (s.at, room), time(), nothing
  end
  zoom_to!(e, s, zoom * s.scale)
end

"""
What a key does while the page shows as slides. It's `handled`, or nothing for
a key that the page still takes: the key of a command in `SLIDE_COMMANDS`, and
Esc while a part of a block has the keyboard, which gives the keyboard back.
"""
slide_key!(e, K, w, command) = begin
  if K == Keys.escape && unmodified(w)
    (w.focus === e || w.focus === nothing) || return nothing
    return end_slides!(e)
  end
  command == :slides && return end_slides!(e)
  command in SLIDE_COMMANDS && return nothing
  # A sketch that fills the window has the keys that come this far
  full_block(e) === nothing || return handled
  # Each key turns the slides only by itself. Space with ⇧ goes back.
  back = K == Keys.space && only_held(w, Keys.shft)
  (unmodified(w) || back) || return handled
  s = slideshow(e)
  K in (Keys.right, Keys.down, Keys.pagedown, Keys.enter) || (K == Keys.space && !back) ? go_slide!(e, s.at + 1) :
  K in (Keys.left, Keys.up, Keys.pageup) || (K == Keys.space && back) ? go_slide!(e, s.at - 1) :
  K == Keys.home ? go_slide!(e, 1) :
  K == Keys._end ? go_slide!(e, length(s.list)) : handled
end

"""
True when the click that's happening now is for a part of a block, and not for
the slide. The part took the keyboard, or it shows a hand while the mouse is
over it, as a button does.
"""
takes_click(e) = begin
  took(e) && return true
  w = window_of(e)
  node = w === nothing ? nothing : hittest(w)
  while node !== nothing && !(node isa Union{Document,Page,Editor})
    cursor(node) == :hand && return true
    node = node.parent
  end
  false
end

"""
A click on a slide. On a to-do item's box, it ticks the item. On a link, it
opens the link. On the left half of the window it goes back a slide, and on
the right half it goes on. A click that a part of a block took does nothing more.
"""
slide_press!(e, pos) = begin
  e.clicked = (time(), (0, 0), 0)   # a drag from here selects nothing
  box = todo_at(e, pos)
  box === nothing || return (focus(e); tick!(e, box); handled)
  takes_click(e) && return nothing
  focus(e)
  # A click with a key of ⌃, ⌘, ⌥ or ⇧ held opens no link and turns no slide
  unmodified(e) || return handled
  url = link_on(e, pos)
  url === nothing || return (follow!(e, url); handled)
  s = slideshow(e)
  go_slide!(e, pos[1] < window_size(e)[1] / 2 ? s.at - 1 : s.at + 1)
end

"The mouse over a slide is a hand on a to-do item's box and on a link, and an arrow anywhere else"
slide_cursor(e) = begin
  w = window_of(e)
  w !== nothing && (todo_at(e, w.mouse) !== nothing || (unmodified(w) && link_on(e, w.mouse) !== nothing)) ? :hand : :arrow
end

"""
What shows over a slide: its number and how many slides there are, at the
bottom right of the window, and a thin bar along the bottom edge. The bar is as
long as the part of the slides that has shown.
"""
slides_over(e) = begin
  s = slideshow(e)
  (s === nothing || isempty(s.list)) && return ()
  n = length(s.list)
  (Column(width(grow=grow), height(grow=grow), Alignment.End, justify=Alignment.End,
     Box(padding(0px, 18px, 10px, 0px), label("$(s.at) / $n", 12px, color=colours.faint)),
     Row(width(grow=grow), height(3px), Alignment.Start,
       Box(width(percent=s.at / n), height(3px), background(tint(colours.ink, 0.16))))),)
end
