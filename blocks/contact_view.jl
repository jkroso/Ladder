# The view of a `contact` block, contacts from a vCard, and the work that names a contact
#
# A code block in the language `contact` holds contacts: people and
# companies. contact.jl says how the block is written. Each contact shows as
# a card: a round picture, the name, the role and the company under it, and a
# row for each other detail. A block with nothing in it shows a card with a
# place for a name.
#
#   - A click on a row uses it. An email address starts a new email, a phone
#     number a call, an address shows in the Maps app, and a web address
#     opens in the browser. Each one goes through `BROWSER`, as the address
#     of a link card does, so a test opens nothing.
#   - While the mouse is over a row, a button at its right end copies its value.
#   - Two clicks on the name, the role, the company or the value of a row
#     change those words where they are, with no box round them. Return keeps
#     the change, esc leaves it, and a click somewhere else keeps it. An
#     emptied value takes its line out of the block. So a click on a row
#     waits a moment for a second click before it opens anything.
#   - While the mouse is over a card, two buttons show at its top right. The
#     + opens a menu of the details to add. The other one writes the contact
#     as a vCard file and opens the file, so the Contacts app asks to add it.
#   - While the mouse is over the block, a button under the last card adds a contact.
#   - A vCard file that's dropped on the page becomes a block of its
#     contacts, and one that's dropped on a block joins it. ⌘V does the same
#     with a contact that was copied in the Contacts app.
#   - A page that can't be changed, like an email, takes no changes. Its
#     rows still open and copy.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor open_url show_tooltip! hide_tooltip! show_menu! redraw_in! rect with_round_clip clipboard!
@use "github.com/jkroso/UI.jl/Interface/image" image_source
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./markdown" Kind words
@use "./sheet" parts shown
@use "./spreadsheet" letters
@use "./pasteboard" => Pasteboard
@use "./find" => Searches
@use "./contact" => Contacts
@use "./eml" => Eml
@use "./base" exports...
@use "./linkcard_view" exports...
@use "./takeoff_view" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./schedule_view" exports...
@use "./calendar_view" exports...

export CONTACT, CONTACT_WIDE, CONTACT_FACE, CONTACT_PAD, CONTACT_NAME, CONTACT_LINE, CONTACT_WAIT,
       CONTACT_COPIED, CONTACT_MENU, CONTACT_ICONS, CONTACT_COPIES, ContactView, ContactCard, ContactFace,
       ContactWords, ContactRow, ContactButton, contact_input, contact_field, contact_part!, contact_card!,
       contact_words!, contact_row!, contact_button!, contact_of, contact_cards, contact_wide, change!,
       contact_twice!, contact_opens, use_row!, keep_contact!, contact_act!, contact_photo, contact_lines,
       contact_html, file_contacts, split_contacts, contacts_at, add_contacts!, put_contacts!,
       paste_contacts!, copied_contacts, WORK_ROWS, ContactWork, contact_names, names_one, contact_work,
       work_of

const CONTACT = Contacts.CONTACT
push!(BLOCK_ICONS, "person-vcard", "person", "building", "envelope", "telephone", "geo-alt", "globe", "card-text", "tag",
      "plus", "plus-circle", "person-plus", "copy", "check")
const CONTACT_WIDE = 420px   # how wide a card is at the usual size of the text, in a page with room for it
const CONTACT_FACE = 44px    # how wide the round picture is
const CONTACT_PAD = 12px     # the room inside a card's edge, and between the picture and the words
const CONTACT_NAME = 22px    # how tall the line of the name is
const CONTACT_LINE = 20px    # and each other line of a card
const CONTACT_WAIT = 0.35    # how many seconds a click on a row waits for a second click
const CONTACT_COPIED = 1.2   # how many seconds the button of a row shows that it copied
"The details that the + of a card adds: what the menu calls each, and its kind"
const CONTACT_MENU = [("Email", :email), ("Phone", :phone), ("Address", :address), ("Website", :web), ("Note", :note)]
"The icon of a row of each kind. A row of any other kind has a tag."
const CONTACT_ICONS = Dict(:email => "envelope", :phone => "telephone", :address => "geo-alt", :web => "globe", :note => "card-text", :company => "building")
"What the button of a row of each kind copies, as its tooltip says it"
const CONTACT_COPIES = Dict(:email => "the email address", :phone => "the phone number", :address => "the address", :web => "the web address", :note => "the note")

"What a `contact` block shows: a card for each contact of the block"
@def mutable struct ContactView <: SemanticUI
  n::Int = 0                               # its place among the page's blocks of contacts
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Vector{Contacts.Contact} = Contacts.Contact[]
  lines::Vector{String} = String[]         # the lines that `data` was read from
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its cards, their rows and buttons, and the field, kept between frames
  # What's being changed where it is, or nothing: the contact's place in the block, then the line of the
  # contact, or `:name` for its name, or the kind of a new detail, like `:email`
  editing::Any = nothing
  waiting::Any = nothing                   # a click on a row that opens something: when it was, the contact and the line
  clicked::Any = (0.0, nothing, 0.0, 0.0)  # when the last click was, what it was on and where
  copied::Any = (0.0, 0, 0)                # when a value was last copied, and its contact and its line
  menu::Int = 0                            # the card whose menu of details is open, or 0
end

"The card of one contact"
@def mutable struct ContactCard <: SemanticUI
  of::Any = nothing
  k::Int = 0
end
"The round picture of a card: the photo, the initials, or a building for a company"
@def mutable struct ContactFace <: SemanticUI
  of::Any = nothing
  k::Int = 0
  key::String = ""   # of the photo, for drawing, or "" when the card has none to show
end
"Words of a card that two clicks change where they are: the name, the role or the company"
@def mutable struct ContactWords <: SemanticUI
  of::Any = nothing
  k::Int = 0
  i::Any = :name       # the line of the contact, or `:name`
  room::px = 0px       # how wide the words can be
  tight::Bool = false  # other words follow them on their line, so the field is as wide as what's typed
end
"A row of a card: one detail, with its icon"
@def mutable struct ContactRow <: SemanticUI
  of::Any = nothing
  k::Int = 0
  i::Any = 0           # the line of the contact, or the kind of a new detail that's being typed
  room::px = 0px       # how wide the row is
end
"A small button of a card, with only an icon. A click does `contact_act!(view, action, window)`."
@def mutable struct ContactButton <: SemanticUI
  of::Any = nothing
  action::Any = (:none,)
  icon::String = ""
  tip::String = ""
  quiet::Bool = false   # clicked, so no tooltip until the mouse leaves it
end

"The field that takes the place of words of a card while you change them"
contact_input(v::ContactView) = block_part!(v, :edit) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"""
That field in a box with no border and no background, set to draw its text
`size` tall. `sizing` says how wide and how tall the box is.
"""
contact_field(v::ContactView, size, sizing...) = begin
  input = contact_input(v)
  input.color = colours.ink
  theme = component_theme(editor(v).zoom)
  # A size in points is a part of the theme's size
  input.font_size = (12 * num(size) / num(theme.size))pt
  with_theme(() -> Box(sizing..., input), theme)
end

"""
A part of a block of contacts that's kept between frames. `parent` is the part
that it's drawn in. So the mouse over a button of a row is over the row too,
and over the row's card.
"""
contact_part!(make, v::ContactView, key, parent) = begin
  node = get!(make, v.parts, key)
  node.parent === nothing && setfield!(node, :parent, parent)
  node
end

contact_card!(v::ContactView, k) = contact_part!(() -> ContactCard(of=v, k=k), v, (:card, k), v)
contact_words!(v::ContactView, k, i) = contact_part!(() -> ContactWords(of=v, k=k, i=i), v, (:words, k, i), contact_card!(v, k))
contact_row!(v::ContactView, k, i) = contact_part!(() -> ContactRow(of=v, k=k, i=i), v, (:row, k, i), contact_card!(v, k))
"The button of the block that's kept for `action`, with what it shows now"
contact_button!(v::ContactView, action, icon, tip, parent) = begin
  b = contact_part!(() -> ContactButton(of=v), v, (:button, action), parent)
  b.action, b.icon, b.tip = action, icon, tip
  b
end

reread!(v::ContactView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Contacts.contacts(lines)
  # The line that was being changed can go, as when ⌘Z takes it back
  v.editing = v.waiting = nothing
  v
end

"True for contacts in a page that can't be changed, like an email. They take no changes."
locked(v::ContactView) = (b = editor(v).buf; readonly(b) || b.fixed)

"The contact at `k` of the block. A place after the last one has a contact with nothing in it: the one that a new name starts."
contact_of(v::ContactView, k::Int) = k in eachindex(v.data) ? v.data[k] : Contacts.Contact()

"How many cards the block shows: one for each contact, one for a block with none, and one more while a new contact gets its name"
contact_cards(v::ContactView) = max(1, length(v.data), v.editing === nothing ? 0 : v.editing[1])

"How wide a card is in the page: 420 px at the usual size of the text, and no wider than the page's text"
contact_wide(v::ContactView) = (e = editor(v); min(CONTACT_WIDE * e.zoom, e.width))

"""
Keep what the field holds: write it into the line that was being changed, as
the name, or as a new detail. A contact that's left with no lines goes out of
the block. It's true when that changed the block.
"""
settle!(v::ContactView) = begin
  v.editing === nothing && return false
  k, what = v.editing
  text = contact_input(v).text
  v.editing = nothing
  locked(v) && return false
  list = Contacts.contacts(v.lines)
  fresh = k > length(list)
  c = fresh ? Contacts.Contact() : list[k]
  changed = what === :name ? Contacts.rename!(c, text) : what isa Symbol ? Contacts.add!(c, what, text) : Contacts.set!(c, what, text)
  changed || return false
  fresh && Contacts.add!(list, c)
  isempty(c.lines) && Contacts.remove!(list, k)
  write_block!(v, CONTACT, Contacts.written(list))
  true
end

"""
Put the field in the place of words of contact `k`, with the words in it and
selected. `what` is the line of the contact, or `:name`, or the kind of a new
detail, which starts with nothing in it.
"""
change!(v::ContactView, k::Int, what) = begin
  locked(v) && return handled
  c = contact_of(v, k)
  words = what === :name ? Contacts.title(c) : what isa Symbol ? "" : what in eachindex(c.lines) ? c.lines[what].value : nothing
  words === nothing && return handled
  input = contact_input(v)
  input.text = words
  input.anchor, input.cursor, input.scroll = 0, length(words), 0px
  input.placeholder = what === :name ? "Name" : what isa Symbol ? first(CONTACT_MENU[findfirst(m -> last(m) == what, CONTACT_MENU)]) : ""
  v.editing, v.waiting = (k, what), nothing
  v.clicked = (0.0, nothing, 0.0, 0.0)
  # The press isn't a click on the page's text, so the text doesn't select when the mouse moves
  e = editor(v)
  e.clicked = (e.clicked[1], e.clicked[2], 0)
  focus(input)
  handled
end

"Note a click on `what`. True when it's the second of two clicks in one place."
contact_twice!(v::ContactView, what, w) = begin
  at, on, x, y = v.clicked
  mx, my = num(w.mouse[1]), num(w.mouse[2])
  v.clicked = (time(), what, mx, my)
  time() - at < CONTACT_WAIT && on == what && hypot(mx - x, my - y) < 4
end

"True when the block can open something now. A window that isn't on the screen opens nothing, unless a test put its own function in place of the browser."
contact_opens(v::ContactView) = on_screen(v) || BROWSER[] !== open_url

"Open what line `i` of contact `k` names: a new email, a call, the Maps app or the browser"
use_row!(v::ContactView, k, i) = begin
  c = contact_of(v, k)
  i in eachindex(c.lines) || return nothing
  to = Contacts.link(c.lines[i])
  to === nothing || !contact_opens(v) || BROWSER[](to)
  nothing
end

"Write contact `k` as a vCard file in a folder for temporary files, and open the file, so the Contacts app asks to add it"
keep_contact!(v::ContactView, k) = begin
  c = contact_of(v, k)
  (Contacts.isblank(c) || !contact_opens(v)) && return nothing
  path = joinpath(mktempdir(), Contacts.filename(c))
  write(path, Contacts.vcard(c))
  BROWSER[](path)
  nothing
end

"Do what a button of a card does"
contact_act!(v::ContactView, action, w) = begin
  kind = action[1]
  # What was being changed is kept first. A line that went with it leaves the others in new places.
  n = length(v.lines)
  settle!(v)
  length(v.lines) == n || kind == :new || return handled
  if kind == :copy
    c = contact_of(v, action[2])
    if action[3] in eachindex(c.lines)
      clipboard!(w, c.lines[action[3]].value)
      v.copied = (time(), action[2], action[3])
      redraw_in!(v, CONTACT_COPIED + 0.05)   # so that the button shows its own icon again
    end
  elseif kind == :more
    # The menu hangs under the button, which stays while the menu is open
    k = action[2]
    v.menu = k
    show_menu!(w, [first(m) for m in CONTACT_MENU], w.mouse[1], w.mouse[2], 150px, theme=menu_theme(), item_height=28px, lift=3.0,
               under=v.parts[(:button, action)], gap=4px,
               onselect=j -> (v.menu = 0; j in eachindex(CONTACT_MENU) && change!(v, k, last(CONTACT_MENU[j])); nothing))
  elseif kind == :keep
    keep_contact!(v, action[2])
  elseif kind == :new
    change!(v, length(v.data) + 1, :name)
  end
  handled
end

"""
What happens to a block of contacts in each frame, before the page is laid
out. A click somewhere else keeps what the field holds. A click on a row
that no second click followed opens what the row names.
"""
block_tick!(v::ContactView) = begin
  w = window_of(v)
  typing = w !== nothing && w.focus === contact_input(v)
  v.editing === nothing || typing || settle!(v)
  # The field went, as when ⌘Z took its line back, so the page has the keyboard again
  v.editing === nothing && typing && focus(editor(v))
  if v.waiting !== nothing && time() - v.waiting[1] >= CONTACT_WAIT
    _, k, i = v.waiting
    v.waiting = nothing
    use_row!(v, k, i)
  end
  v
end

# The keys that the field has no use for come here. Return keeps what's typed, and esc leaves the words as they were.
onkey(v::ContactView, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (ev.window.focus === contact_input(v) ? (settle!(v); focus(editor(v)); handled) : nothing) : nothing
onkey(v::ContactView, ev::KeyPress{Keys.escape}) = unmodified(ev) ? (ev.window.focus === contact_input(v) ? (v.editing = nothing; focus(editor(v)); handled) : nothing) : nothing

# Return, while the caret is on the block as a whole, starts on the name of its first contact
keyboard_part(v::ContactView) = locked(v) ? nothing : (v.editing === nothing && change!(v, 1, :name); contact_input(v))

describe(b::ContactButton) = begin
  ishovered(b) || (b.quiet = false)
  z = editor(b.of).zoom
  Box(fixed(20px * z), height(20px * z), radius(5px * z), Alignment.Center, name="Button", background(ishovered(b) ? colours.active : clear),
      Row(Alignment.Center, Icon(b.icon, size=13px * z, color=colours.dim)))
end

cursor(::ContactButton) = :hand
onmouse(b::ContactButton, ev::MouseMove) = begin
  (b.quiet || isempty(b.tip)) && return
  show_tooltip!(ev.window, tip_label(b.tip), b, placement=:bottom, gap=6px)
end
onkey(b::ContactButton, ev::KeyPress{Keys.mouse_left}) = begin
  b.quiet = true
  hide_tooltip!(ev.window)
  contact_act!(b.of, b.action, ev.window)
end

"""
The key, for drawing, of the picture that a contact names, or "" while there's
none to show. A file is named from the page's folder, as a picture line names
one. A picture from the web is fetched in the background and kept, as the
picture of a link card is. An email asks a web site for nothing.
"""
contact_photo(e, src::AbstractString) = begin
  isempty(src) && return ""
  occursin(r"^https?://"i, src) && return Eml.isemail(e.buf.path) ? "" : card_picture(e, src)
  something(picture_key(abspath(docdir(e), expanduser(unescaped(src)))), "")
end

describe(f::ContactFace) = begin
  v = f.of
  e = editor(v)
  z = e.zoom
  c = contact_of(v, f.k)
  side = CONTACT_FACE * z
  f.key = contact_photo(e, Contacts.photo(c))
  # With no photo: a building for a company, the initials of a person, and a head for a contact with no name yet
  letters = Contacts.initials(Contacts.title(c))
  mark = !isempty(f.key) ? () : Contacts.iscompany(c) ? (Icon("building", size=20px * z, color=colours.accent),) :
         isempty(letters) ? (Icon("person", size=22px * z, color=colours.faint),) :
         (label(letters, 16px * z, color=colours.accent, weight="Semibold"),)
  Box(fixed(side), height(side), radius(side / 2), Alignment.Center, name="Picture",
      background(isempty(letters) && !Contacts.iscompany(c) ? colours.hover : tint(colours.accent, 0.13)), Row(Alignment.Center, mark...))
end

# The photo fills the circle. What doesn't fit in a square is cut off at its sides, or at its top and bottom.
draw(ctx, size, ui::ConcreteRect, f::ContactFace) = begin
  isempty(f.key) && return
  source = try image_source(f.key) catch; return end
  w, h = Float64(source.width), Float64(source.height)
  side = min(w, h)
  side > 0 || return
  with_round_clip(ctx, ui.left, ui.top, ui.width, ui.height, ui.width / 2) do
    paint_picture(ctx, source.raw, ((w - side) / 2, (h - side) / 2, side, side), (num(ui.left), num(ui.top), num(ui.width), num(ui.height)))
  end
end

describe(t::ContactWords) = begin
  v = t.of
  z = editor(v).zoom
  c = contact_of(v, t.k)
  name = t.i === :name
  size, tall = name ? (15px * z, CONTACT_NAME * z) : (13px * z, CONTACT_LINE * z)
  if v.editing == (t.k, t.i)
    # The words are changed where they are, with no box round them. A field with words after it is as wide as what's typed.
    field = contact_input(v)
    typed = measure(Face(SANS, "", size, colours.ink, false), isempty(field.text) ? field.placeholder : field.text) + 4px * z
    wide = t.tight ? fixed(clamp(typed, 24px * z, max(24px * z, t.room))) : width(grow=grow)
    return contact_field(v, size, wide, height(tall))
  end
  words = name ? Contacts.title(c) : t.i in eachindex(c.lines) ? c.lines[t.i].value : ""
  face = Face(SANS, name ? "Semibold" : "", size, name ? colours.ink : colours.dim, false)
  # A contact with no name says where its name goes
  shown, colour = isempty(words) && name ? (on_paper(editor(v)) || locked(v) ? "" : "Name", colours.faint) : (shortened(face, words, t.room), face.color)
  Row(height(tall), Box(label(shown, size, color=colour, weight=face.style)))
end

cursor(t::ContactWords) = :arrow
# Two clicks change the words. A contact with no name takes its name at the first click. Any other click goes on to the page.
onkey(t::ContactWords, ev::KeyPress{Keys.mouse_left}) = begin
  v = t.of
  (only_held(v, Keys.opt) || locked(v) || v.editing == (t.k, t.i)) && return nothing
  twice = contact_twice!(v, (t.k, t.i), ev.window)
  settle!(v) && return nothing   # the click kept what was being changed, and the lines aren't where they were
  nameless = t.i === :name && isempty(Contacts.title(contact_of(v, t.k)))
  twice || nameless ? change!(v, t.k, t.i) : nothing
end

"The lines that the value of the detail `d` takes in a row with `room` for it. An address and a note wrap. Anything else is one line."
contact_lines(d::Contacts.Detail, face::Face, room) =
  d.kind in (:email, :web, :phone) || isempty(d.value) ? [d.value] : wrapped(face, d.value, num(room))

describe(r::ContactRow) = begin
  v, k = r.of, r.k
  e = editor(v)
  z = e.zoom
  c = contact_of(v, k)
  # A new detail that's being typed has no line yet
  d = r.i isa Symbol ? Contacts.Detail(r.i, "", "") : r.i in eachindex(c.lines) ? c.lines[r.i] : nothing
  d === nothing && return Box(height(0px))
  size, line, gap = 13px * z, CONTACT_LINE * z, 7px * z
  editing = v.editing == (k, r.i)
  to = Contacts.link(d)
  face = Face(SANS, "", size, to === nothing ? colours.ink : colours.accent, false)
  grey = Face(SANS, "", size, colours.dim, false)
  # The label of a row that has one is cut short before it takes more than a third of the row
  caption = shortened(grey, Contacts.caption(d), r.room / 3)
  room = r.room - 15px * z - gap - (isempty(caption) ? 0px : measure(grey, caption) + gap) - 20px * z - gap
  lines = contact_lines(d, face, room)
  cell(words, colour) = Row(height(line), Box(label(words, size, color=colour)))
  value = if editing
    # The words are changed where they are, with no box round them. The row stays as tall as it was.
    Column(width(grow=grow), Alignment.Start, contact_field(v, size, width(grow=grow), height(line)),
           (length(lines) > 1 ? (Box(height(line * (length(lines) - 1))),) : ())...)
  else
    Column(width(grow=grow), Alignment.Start, (cell(shortened(face, words, room), face.color) for words in lines)...)
  end
  over = ishovered(r) && !editing && !isempty(d.value) && !on_paper(e)
  done = v.copied[2:3] == (k, r.i) && time() - v.copied[1] < CONTACT_COPIED
  button = over || done ? (contact_button!(v, (:copy, k, r.i), done ? "check" : "copy", "Copy " * get(CONTACT_COPIES, d.kind, "this"), r),) : ()
  Row(width(grow=grow), Alignment.Start, child_gap=gap, name="Detail",
    Box(fixed(15px * z), height(line), Alignment.Center, Row(Alignment.Center, Icon(get(CONTACT_ICONS, d.kind, "tag"), size=13px * z, color=colours.dim))),
    (isempty(caption) ? () : (cell(caption, colours.dim),))...,
    value,
    Box(fixed(20px * z), height(line), Alignment.Center, button...))
end

cursor(r::ContactRow) = begin
  c = contact_of(r.of, r.k)
  r.i in eachindex(c.lines) && Contacts.link(c.lines[r.i]) !== nothing ? :hand : :arrow
end

# A click on a row opens what the row names, once it's known that no second click comes. Two clicks change
# the row's value. The click goes on to the page, which takes the keyboard back from the field.
onkey(r::ContactRow, ev::KeyPress{Keys.mouse_left}) = begin
  v = r.of
  (only_held(v, Keys.opt) || v.editing == (r.k, r.i)) && return nothing
  twice = contact_twice!(v, (r.k, r.i), ev.window)
  settle!(v) && return nothing   # the click kept what was being changed, and the lines aren't where they were
  c = contact_of(v, r.k)
  r.i in eachindex(c.lines) || return nothing
  # A page that can't be changed has no second click to wait for
  locked(v) && return use_row!(v, r.k, r.i)
  twice && return change!(v, r.k, r.i)
  if Contacts.link(c.lines[r.i]) !== nothing
    v.waiting = (time(), r.k, r.i)
    redraw_in!(v, CONTACT_WAIT + 0.02)
  end
  nothing
end

describe(card::ContactCard) = begin
  v, k = card.of, card.k
  e = editor(v)
  z = e.zoom
  c = contact_of(v, k)
  pad = CONTACT_PAD * z
  inner = contact_wide(v) - 2pad - 2px - CONTACT_FACE * z - pad   # how wide the column beside the picture is
  over = !on_paper(e) && (ishovered(card) || v.menu == k)
  # The buttons have their room at the top right, so the name isn't cut shorter when they show
  buttons = 44px * z
  name = contact_words!(v, k, :name)
  name.room, name.tight = inner - buttons - 4px * z, false
  filler(node) = v.editing == (k, node.i) && !node.tight ? () : (Box(width(grow=grow)),)
  head = Row(width(grow=grow), height(CONTACT_NAME * z), justify=Alignment.Start, name, filler(name)...,
    Row(fixed(buttons), height(20px * z), child_gap=2px * z, justify=Alignment.End,
      (over && !locked(v) ? (contact_button!(v, (:more, k), "plus", "Add a detail", card),) : ())...,
      (over && !Contacts.isblank(c) ? (contact_button!(v, (:keep, k), "person-plus", "Add to Contacts", card),) : ())...))
  # Under the name of a person: the role, a comma, the company
  role, firm = Contacts.under(c)
  grey = Face(SANS, "", 13px * z, colours.dim, false)
  both = role !== nothing && firm !== nothing
  comma = both ? measure(grey, ",") + 4px * z : 0px
  under = Any[]
  taken = 0px
  if role !== nothing
    t = contact_words!(v, k, role)
    # The company keeps half of the line at the least
    t.tight, t.room = both, both ? max(inner / 2, inner - comma - measure(grey, c.lines[firm].value)) : inner
    taken = min(measure(grey, c.lines[role].value), t.room)
    push!(under, t)
    both && push!(under, Row(height(CONTACT_LINE * z), Box(label(",", 13px * z, color=colours.dim))), Box(width(4px * z)))
  end
  if firm !== nothing
    t = contact_words!(v, k, firm)
    t.tight, t.room = false, inner - taken - comma
    push!(under, t)
  end
  tag = isempty(under) ? () : (Row(width(grow=grow), height(CONTACT_LINE * z), justify=Alignment.Start, under..., filler(under[end])...),)
  rows = Any[contact_row!(v, k, i) for i in Contacts.rows(c)]
  # A new detail that's being typed is a row at the end
  v.editing !== nothing && v.editing[1] == k && v.editing[2] isa Symbol && v.editing[2] !== :name && push!(rows, contact_row!(v, k, v.editing[2]))
  foreach(r -> r.room = inner, rows)
  # Under the details: the to-do items that name the contact, with a line over them
  work = contact_work(v, k)
  jobs = isempty(work) ? () :
    (Box(height(6px * z)), Box(fixed(inner), height(1px), background(colours.line)), Box(height(4px * z)),
     [(r = contact_part!(() -> ContactWork(of=v, k=k, i=i), v, (:work_row, k, i), card); r.room = inner; r) for i in 1:min(length(work), WORK_ROWS)]...,
     (length(work) > WORK_ROWS ? (Row(fixed(inner), height(CONTACT_LINE * z), padding(0px, 0px, 0px, 25px * z), Alignment.Center,
                                    Box(label("and $(length(work) - WORK_ROWS) more", 11.5px * z, color=colours.faint)), Box(width(grow=grow))),) : ())...)
  # A card with only a name, or a name and the line under it, has them level with the middle of the picture
  # A card is marked while the mouse is on its contact in another part of the page, like its pin on a map
  lit = !ishovered(card) && !isempty(Contacts.title(c)) && marked(v, Contacts.title(c))
  Row(fixed(contact_wide(v)), isempty(rows) && isempty(jobs) ? Alignment.Center : Alignment.Start, padding(pad), child_gap=pad, radius(8px), border(1px, :solid, lit ? colours.accent : colours.line),
      background(lit ? mark_colour(colours.block) : colours.block), clip=true, name="Contact",
    contact_part!(() -> ContactFace(of=v, k=k), v, (:face, k), card),
    Column(width(grow=grow), Alignment.Start, head, tag..., (isempty(rows) ? () : (Box(height(5px * z)),))..., rows..., jobs...))
end

cursor(::ContactCard) = :arrow
cursor(::ContactView) = :arrow

describe(v::ContactView) = begin
  e = editor(v)
  z = e.zoom
  wide = contact_wide(v)
  cards = [contact_card!(v, k) for k in 1:contact_cards(v)]
  # The button that adds a contact has its room under the last card, so the page doesn't move when it shows.
  # It's there while the mouse is over the block, and not while a new contact gets its name.
  adds = !locked(v) && !on_paper(e)
  starting = v.editing !== nothing && v.editing[1] > length(v.data)
  more = !adds ? () : (Row(fixed(wide), height(22px * z), justify=Alignment.Start,
    (ishovered(v) && !starting && !isempty(v.data) ? (contact_button!(v, (:new,), "plus-circle", "Add a contact", v),) : ())...),)
  Box(width(grow=grow), Alignment.Start,
    Column(fixed(wide), Alignment.Start, name="Contacts",
      Column(fixed(wide), Alignment.Start, child_gap=8px * z, cards...), more...))
end

"The contacts of the block as HTML: a card for each one, with the class names of the h-card microformat"
contact_html(e, v::ContactView) = Contacts.markup(v.data)

BLOCKS[CONTACT] = ContactView
block_name(::Type{ContactView}) = "Contact"
block_icon(::Type{ContactView}) = "person-vcard"
block_insert(::Type{ContactView}) = ("Contact", ["```$CONTACT", "", "```"], (2, 0))
block_html(e, v::ContactView) = contact_html(e, v)
block_places(::Type{ContactView}, lines) = begin
  out = @NamedTuple{name::String, place::String, line::Int}[]
  at = 0
  for c in Contacts.contacts(lines)
    at += c.before
    k = Contacts.place(c, :address)
    k === nothing || push!(out, (name=Contacts.title(c), place=c.lines[k].value, line=at + k))
    at += length(c.lines)
  end
  out
end

# --- contacts from a vCard ---------------------------------------------------------------------
#
# The Contacts app writes a contact as a vCard: a .vcf file, or text that
# starts with BEGIN:VCARD. contact.jl reads one. A vCard file that's dropped
# on the page, or pasted, goes in as a block of its contacts.

"The contacts that the file at `path` holds, when it's a vCard file. Any other file has none, and so has one that can't be read."
file_contacts(path::AbstractString) = begin
  (isfile(path) && lowercase(splitext(path)[2]) in (".vcf", ".vcard")) || return Contacts.Contact[]
  try Contacts.from_vcard(read(path, String)) catch; Contacts.Contact[] end
end

"The contacts of the vCard files among `paths`, and the paths that are left"
split_contacts(paths) = begin
  list = Contacts.Contact[]
  rest = filter(paths) do p
    found = file_contacts(p)
    foreach(c -> Contacts.add!(list, c), found)
    isempty(found)
  end
  (list, rest)
end

"The block of contacts under the mouse, or nothing. Only a block that the page shows now is where it was last drawn."
contacts_at(e, w) = begin
  x, y = w.mouse
  for it in view(e.layout, intersect(e.shown, eachindex(e.layout)))
    node = it.content isa Live ? it.content.node : nothing
    node isa ContactView || continue
    r = rect(node)
    r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height && return node
  end
  nothing
end

"Add `list` to the contacts of the block, each one after an empty line. It's true when the block took them."
add_contacts!(v::ContactView, list) = begin
  (isempty(list) || locked(v)) && return false
  settle!(v)
  all = Contacts.contacts(v.lines)
  foreach(c -> Contacts.add!(all, c), list)
  write_block!(v, CONTACT, Contacts.written(all))
  true
end

"""
Put the contacts of `list` into the text at `at`, and give the place for the
caret. In a block of contacts, they join the block. Anywhere else, they go in
as a new block under the block that `at` is in, as a picture that's dropped
does, and the caret goes to an empty line under it.
"""
put_contacts!(e, list, at::Pos) = begin
  b = e.buf
  (isempty(list) || readonly(b) || b.fixed) && return at
  ks = kinds(b)
  if ks[at[1]].kind in (Kind.fence, Kind.code)
    s, t = codeblock(b, at[1])
    if ks[s].lang == CONTACT && t > s && ks[t].kind == Kind.fence && ks[t].level == 1
      all = Contacts.contacts(b.lines[s+1:t-1])
      foreach(c -> Contacts.add!(all, c), list)
      edit!(b, line_end(b, s), line_end(b, t - 1), "\n" * join(Contacts.written(all), "\n"))
      return (s, 0)
    end
  end
  under = block_end(b, at[1])
  empty = isempty(strip(b.lines[under]))
  block = ["```$CONTACT"; Contacts.written(collect(Contacts.Contact, list)); "```"]
  # An empty line goes under the block, for the caret, unless the page has one there
  spare = under < length(b.lines) && isempty(strip(b.lines[under+1]))
  edit!(b, empty ? (under, 0) : line_end(b, under), line_end(b, under), (empty ? "" : "\n\n") * join(block, "\n") * (spare ? "" : "\n"))
  (under + (empty ? 0 : 2) + length(block), 0)
end

"Put the contacts of `list` in the page at the caret, in place of what's selected, as ⌘V does with a contact that was copied"
paste_contacts!(e, list) = begin
  b = e.buf
  selecting(b) && type!(e, "")
  b.caret = b.anchor = put_contacts!(e, list, settle(b, b.caret))
  focus(e)
  touch!(e)
end

"""
The contacts that ⌘V pastes, or none: the clipboard holds the text of a
vCard, or a contact that was copied in the Contacts app. In a code block of
another language, a vCard is pasted as its text.
"""
copied_contacts(e, text::AbstractString) = begin
  b = e.buf
  b.view == :markdown || return Contacts.Contact[]   # a file of code has no blocks
  k = kinds(b)[b.caret[1]]
  k.kind == Kind.code && kinds(b)[codeblock(b, b.caret[1])[1]].lang != CONTACT && return Contacts.Contact[]
  card = Contacts.isvcard(text) ? text : Sys.isapple() ? Pasteboard.vcard() : ""
  try Contacts.from_vcard(card) catch; Contacts.Contact[] end
end

# --- the work that names a contact --------------------------------------------------------------
#
# Under the details of a contact, its card lists the to-do items that name
# the contact and aren't ticked yet: the items of this page, and of every
# page of this page's folder and of the folders in it. A person is named by
# the whole name, or by the first name alone. A click on an item goes to its
# line, in its own page. The mouse on an item marks it in the other parts of
# the page that show it: see "one thing in many parts of the page".
#
# The card reads the pages as a `find` block does, with `folder_pages` and
# `page_text`, so a page is read again only when it changes. A page that
# can't be changed, like an email, lists none.

const WORK_ROWS = 4   # the most items that a card lists. Under them, a line says how many more there are.
push!(BLOCK_ICONS, "square")

"A row under the details of a contact: a to-do item that names the contact"
@def mutable struct ContactWork <: SemanticUI
  of::Any = nothing
  k::Int = 0        # the contact
  i::Int = 0        # the item's place among the contact's items
  room::px = 0px    # how wide the row is
end

"The words that name the contact `c` in a line of text: its whole name, and for a person the first name too, when it has three letters or more"
contact_names(c::Contacts.Contact) = begin
  title = String(strip(Contacts.title(c)))
  isempty(title) && return String[]
  first_name = String(first(split(title)))
  !Contacts.iscompany(c) && first_name != title && length(first_name) >= 3 ? [title, first_name] : [title]
end

"True when `text` has one of `names` in it as whole words. Capital letters make no difference."
names_one(text::AbstractString, names) = begin
  low = lowercase(text)
  any(names) do name
    n = lowercase(name)
    at = findfirst(n, low)
    while at !== nothing
      before = first(at) == firstindex(low) ? ' ' : low[prevind(low, first(at))]
      after = last(at) == lastindex(low) ? ' ' : low[nextind(low, last(at))]
      (isletter(before) || isdigit(before) || isletter(after) || isdigit(after)) || return true
      at = findnext(n, low, nextind(low, first(at)))
    end
    false
  end
end

"""
The to-do items that name contact `k` of the block and aren't ticked, in
every page of this page's folder and of the folders in it. They're found
again when a page changes in Ladder, and when the folder is read again.
"""
contact_work(v::ContactView, k::Int) = begin
  e = editor(v)
  names = contact_names(contact_of(v, k))
  folder = docdir(e)
  (isempty(names) || locked(v) || !isdir(folder)) && return Searches.Match[]
  listed = folder_pages(folder)
  key = (names, hash([b.version for b in values(e.buffers)]), listed.read)
  kept = get(e.flows, (:contact_work, objectid(v), k), nothing)
  kept !== nothing && kept[1] == key && return kept[2]
  pages = get!(() -> Dict{String,Any}(), e.flows, :contact_todos)   # the open items of each page, for every card of the window
  every = Searches.Query(:todo, String[], "", String[])
  out = Searches.Match[]
  for (path, at) in listed.pages
    lines, ks, mark = page_text(e, path, at)
    had = get(pages, path, nothing)
    items = had !== nothing && had[1] == mark ? had[2] : (pages[path] = (mark, Searches.matches(every, path, lines, ks)))[2]
    append!(out, (m for m in items if m.kind == :todo && names_one(m.text, names)))
  end
  e.flows[(:contact_work, objectid(v), k)] = (key, out)
  out
end

"The to-do item that the row `r` shows, or nothing when the contact has it no more"
work_of(r::ContactWork) = (found = contact_work(r.of, r.k); r.i in eachindex(found) ? found[r.i] : nothing)

describe(r::ContactWork) = begin
  v = r.of
  e = editor(v)
  z = e.zoom
  m = work_of(r)
  m === nothing && return Box(height(0px))
  # An item of another page says which page it's in
  page = m.path == e.buf.path ? "" : splitext(relpath(m.path, docdir(e)))[1]
  grey = Face(SANS, "", 11.5px * z, colours.faint, false)
  tail = isempty(page) ? 0px : min(measure(grey, page), r.room * 0.4) + 8px * z
  Row(fixed(r.room), height(CONTACT_LINE * z), child_gap=7px * z, Alignment.Center, radius(4px), clip=true, name="Item",
      background(ishovered(r) ? colours.hover : clear),
    Box(fixed(18px * z), Alignment.Center, Icon("square", size=12px * z, color=colours.dim)),
    Box(label(elide(m.text, 13px * z, r.room - 25px * z - tail), 13px * z, color=colours.ink)), Box(width(grow=grow)),
    (isempty(page) ? () : (Box(label(elide(page, 11.5px * z, tail - 8px * z), 11.5px * z, color=colours.faint)),))...)
end

cursor(::ContactWork) = :hand
onkey(r::ContactWork, ::KeyPress{Keys.mouse_left}) = (m = work_of(r); m === nothing ? handled : visit!(editor(r.of), m.path, m))
