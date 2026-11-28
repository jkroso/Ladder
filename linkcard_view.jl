# The view of a link card
#
# A line that holds only the address of a web page, written as a picture's
# is, like ![Julia](https://julialang.org), shows a card: the page's title,
# two lines of its description, its picture, and the name of its site beside
# the site's icon. The line's own text shows again while the caret is on it,
# as a picture's does. A click on the card with ⌘ held opens its address in
# the browser. In a page that's never changed, a click opens it with no key
# held. Any other click puts the caret on the line.
#
# What's at the address decides what the line shows. An address whose name
# ends as a picture's, a video's, a sound's or a table's does, like .png, shows
# that, and Ladder asks for no card. For any other address, Ladder gets the
# start of what's there, in the background. A web page shows as a card.
# Anything else, like a picture whose address doesn't end in .png, shows as a
# picture. Until Ladder knows, the line shows a card with the address.
#
# Ladder reads what the page says of itself. See linkcard.jl. It keeps that,
# and the picture, in a folder of the Mac's caches, so the card shows at once
# the next time, and with no network. When the page can't be had, the card
# shows the address. Ladder asks the web for nothing in a window that isn't
# on the screen. An email shows no cards: each such line in it is a picture.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe window_of handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor open_url redraw_in!
@use "github.com/jkroso/UI.jl/Interface/image" image_aspect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./pictures" picture
@use "./markdown" words
@use "./linkcard" => Cards
@use "./eml" => Eml
@use Colors: RGBA
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./host" exports...
@use "./folder_page" exports...

export BROWSER, cards_dir, LinkCard, CARD_TITLE, CARD_WORDS, CARD_SOURCE, CARD_LINE, CARD_PAD, card_tall,
       shortened, covered, online, card_picture, NOT_CARDS, card_address, card_item, opening, card_html

push!(BLOCK_ICONS, "globe")

"What opens the address of a card: the browser. A test puts its own function here."
const BROWSER = Ref{Function}(open_url)

"The folder that keeps what the cards read from the web, and their pictures"
cards_dir() = isempty(MEDIA_CACHE[]) ? joinpath(homedir(), "Library", "Caches", "Ladder", "cards") : joinpath(MEDIA_CACHE[], "cards")

"A card that a line of the page shows: what the web page at the line's address says of itself"
@def mutable struct LinkCard <: SemanticUI
  line::Int = 0
  words::String = ""     # the line's words for the card, between its [ and ], which show while the page has no title
  card::Cards.Card = Cards.Card("")
  picture::String = ""   # the key of the page's picture, for an Image, or "" while there's none
  icon::String = ""      # and the key of the site's icon
end

# The sizes of a card's title, of its description and of the name of its site, as parts of the size of the page's text
const CARD_TITLE, CARD_WORDS, CARD_SOURCE = 0.92, 0.8, 0.74
const CARD_LINE = 1.36   # how tall a line of a card is, as a part of the size of its text
const CARD_PAD = 0.65    # the room inside a card's edge, as a part of the size of the page's text

"How tall a card is in a page whose text is `s` tall. Every card is as tall as the next, so the page's text doesn't move when a card fills in."
card_tall(s) = s * (2CARD_PAD + CARD_LINE * (CARD_TITLE + 2CARD_WORDS + CARD_SOURCE) + 0.45)

"`words` cut short with … so that they're no wider than `room` in `face`"
shortened(face::Face, words::AbstractString, room) = begin
  (room <= 0px || measure(face, words) <= room) && return String(words)
  cs = collect(words)
  lo, hi = 0, length(cs)
  while lo < hi
    mid = (lo + hi + 1) ÷ 2
    measure(face, rstrip(String(cs[1:mid])) * "…") <= room ? (lo = mid) : (hi = mid - 1)
  end
  rstrip(String(cs[1:lo])) * "…"
end

"The picture with the key `key` in a box `wide` by `tall`. The picture fills the box, and the box cuts off what doesn't fit."
covered(key, wide, tall) = begin
  aspect = image_aspect(key)
  w, h = aspect > wide / tall ? (tall * aspect, tall) : (wide, wide / aspect)
  Box(fixed(wide), height(tall), radius(6px), clip=true, Image(key, fixed(w), height(h)))
end

"""
True when Ladder can ask the web for what a card shows: the page isn't an
email, and its window is on the screen. A window that a test makes isn't, so a
test asks the web for nothing, unless it put its own function in place of `curl`.
"""
online(e) = !Eml.isemail(e.buf.path) && (Cards.getter[] !== Cards.curl || (w = window_of(e); w !== nothing && !isempty(w.glfw)))

"The key, for an Image, of the picture at the web address `url`, or \"\" while Ladder has none. It asks for the next frame while the picture is on its way."
card_picture(e, url) = begin
  file, coming = Cards.picture!(url, cards_dir(), ask=online(e))
  coming && redraw_in!(e, 0.2)   # look again soon
  file === nothing ? "" : something(picture_key(file), "")
end

# The ends of the names of the files that a line shows as what they are, and never as a card
const NOT_CARDS = (PICTURES..., MAC_PICTURES..., VIDEOS..., SOUNDS..., TABLES..., ".pdf")

"""
True when a line of `e` that holds only `src`, written as a picture is, can
show a card: `src` is a web address, its name doesn't end as a picture's, a
video's, a sound's or a table's does, and the page isn't an email.
"""
card_address(e, src) = Cards.isaddress(src) && !Eml.isemail(e.buf.path) && !(lowercase(splitext(Cards.path(src))[2]) in NOT_CARDS)

"""
What line `i` shows when it holds only the address `src` of a web page,
written as a picture is: a card. `words` are the line's words for the card.
It's nothing when the address can't show a card, and when what's there turned
out not to be a page. That line shows what's there as a picture.
"""
card_item(e, i, src, words) = begin
  card_address(e, src) || return nothing
  card, coming = Cards.lookup!(src, cards_dir(), ask=online(e))
  coming && redraw_in!(e, 0.2)   # look again soon
  card.page || return nothing
  c = node!(LinkCard, e, (:link_card, i))
  # A picture that the card has already isn't looked for again on each frame
  same = c.card == card
  c.line, c.words, c.card = i, words, card
  same && !isempty(c.picture) || (c.picture = card_picture(e, card.image))
  same && !isempty(c.icon) || (c.icon = card_picture(e, card.icon))
  own!(node!(Document, e, :document), c)
  Live(c, card_tall(body(e).size) + 2LIVE_GAP)
end

describe(c::LinkCard) = begin
  e = editor(c)
  s, wide, card = body(e).size, e.width, c.card
  pad = s * CARD_PAD
  inside = card_tall(s) - 2pad - 2px
  # The picture is at the right, and takes no more than a third of the card
  across = isempty(c.picture) ? 0px : min(inside * 1.75, wide * 0.3)
  room = wide - 2pad - 2px - (across > 0px ? across + pad : 0px)
  # An address that stands in for the title isn't bold
  heading = Cards.heading(card, c.words)
  title = Face(SANS, heading == card.url ? "" : "Semibold", s * CARD_TITLE, colours.ink, false)
  words = Face(SANS, "", s * CARD_WORDS, colours.dim, false)
  source = Face(SANS, "", s * CARD_SOURCE, colours.faint, false)
  line(face, text, room) = Box(width(grow=grow), height(face.size * CARD_LINE), Alignment.Start, justify=Alignment.Center,
                               label(shortened(face, text, room), face.size, color=face.color, weight=face.style))
  # The description has two lines at most, and the second ends in … when there's more
  under = Cards.blurb(card, c.words)
  told = isempty(under) ? String[] : wrapped(words, under, num(room))
  length(told) > 2 && (told = [told[1], join(told[2:end], " ")])
  mark = source.size * 1.15
  # Many sites have a dark icon with nothing behind it, which a dark page would hide. There it has a light square behind it.
  page = convert(RGBA{Float64}, colours.bg)
  behind = page.r + page.g + page.b < 1.5 ? (background(RGBA(1, 1, 1, 0.85)),) : ()
  Row(width(grow=grow), height(card_tall(s)), padding(pad), child_gap=pad, radius(8px), border(1px, :solid, colours.line),
      background(ishovered(c) && opening(c) ? colours.hover : colours.block), name="Link card",
    Column(width(grow=grow), height(inside), Alignment.Start,
      line(title, heading, room),
      (line(words, text, room) for text in told)...,
      Box(width(grow=grow), height(grow=grow)),
      Row(width(grow=grow), height(source.size * CARD_LINE), justify=Alignment.Start, child_gap=s * 0.35,
        isempty(c.icon) ? Icon("globe", size=mark, color=colours.faint) : Image(c.icon, fixed(mark), height(mark), radius(3px), behind...),
        Box(label(shortened(source, Cards.source(card), room - mark - s * 0.35), source.size, color=source.color)))),
    (across > 0px ? (covered(c.picture, across, inside),) : ())...)
end

"True when a click on the card now opens its address: ⌘ alone is held, or the page is one that's never changed and no key is held"
opening(c::LinkCard) = only_held(c, Keys.cmd) || (follows_links(editor(c).buf) && unmodified(c))

cursor(c::LinkCard) = opening(c) ? :hand : :arrow
# A click with ⌘ held opens the address. Any other click goes to the page, which puts the caret on the card as a whole.
# The address shows in Ladder when its site has a viewer of its own, and in your browser when it has none.
onkey(c::LinkCard, ev::KeyPress{Keys.mouse_left}) =
  opening(c) ? (site_shows!(editor(c), c.card.url) || BROWSER[](c.card.url); handled) : click_page!(c, ev)

"""
The HTML of the line `text` when it shows a card: the card as a link in a box.
It's nothing for any other line. The rules that give a card its look come with
the first card of the page. `styled` is true once they're in.
"""
card_html(e, text, styled::Ref{Bool}) = begin
  occursin("![", text) || return nothing
  m = match(PICTURE_LINE, text)
  m === nothing && return nothing
  src = unescaped(String(m[2]))
  card_address(e, src) || return nothing
  card = first(Cards.lookup!(src, cards_dir(), ask=online(e)))
  card.page || return nothing
  rules = styled[] ? "" : "<style>\n" * Cards.STYLE * "</style>\n"
  styled[] = true
  rules * Cards.markup(card, unescaped(String(m[1])))
end
