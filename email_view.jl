# An email as it was sent, and the files that came with it
#
# Most email is written as HTML, with its sender's colours, layout and buttons.
# At the high level, where the top bar shows the ladder, an email shows that
# way: web/ lays the HTML out as a page, as wide as the page's text, and the
# window draws it under the email's card, in place of the lines that mail.jl
# made of the same HTML. The links to the files that came with the email stay
# under it. A click on a link of the email opens it, and the mouse over a link
# says where it goes.
#
# Down a level, where the top bar shows the snake, the email shows its words
# as a page, as an email with no HTML always does. So does an email that
# can't be laid out, and any email while the find bar is open.
#
# Ladder asks the web for nothing to draw an email, so its sender can't tell
# when you open it. A picture that the email has from a web site is an empty
# box then, and a button over the email fetches those pictures. An email that
# you asked that of once shows its pictures from then on, and so does each
# email from the same address. The file "picture senders" in Ladder's own
# folder lists those addresses, one on each line. Take an address out of it,
# and the emails from it that you didn't click the button on ask again.
#
# A picture of the email that moves, like a GIF, moves here too. The email is
# laid out once, and the window is drawn again each time such a picture shows
# its next picture, up to 30 times a second.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" rectangle
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect with_round_clip clipboard!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./html" html
@use "./markdown" words front_matter
@use "./sheet" parts shown
@use "./eml" => Eml
@use "./webpage" => Webpages
@use "./web" => Web
@use "./web/select" => WebSelect
@use Colors: @colorant_str
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./blocks" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./map_view" exports...
@use "./file_view" exports...

export SENT_LINE, SENT_QUICK, SENT_FAILED, SENT_FRAME, SENT_PAGE, SentEmail, SentPage, sent_dir, sent_mark,
       picture_senders_file, picture_senders, picture_sender!, sent_html, sent_email, sent_page!, sent_bytes,
       sent_arrivals!, SENT_LEVELS, sent_problem, sent_lines, attached_from, sent_item, sent_mouse, sent_link,
       sent_place, sent_select!, sent_copy!, sent_select_all!, sent_keys, sent_address, FILE_ICON, FILE_NAME,
       FILE_SIZE, FILE_PAD, FILE_WIDE, FILE_GAP, FILE_LINE, FILE_LINK, AttachedFile, AttachedFiles, file_tall,
       attached_file, attached_item, files_across, icon_name

const SENT_LINE = 1px       # how thick the line round an email is. The email is drawn inside it.
const SENT_QUICK = 0.02     # an email that takes longer than this many seconds to lay out waits until the window's width has stayed
const SENT_FAILED = "Ladder can't draw this email as it was sent."
const SENT_FRAME = 1 / 30   # an email with a picture that moves is drawn again no sooner than this many seconds after the last time

"The function that lays an email out, as `Web.page` does. A test puts a function of its own here."
const SENT_PAGE = Ref{Any}(Web.page)

"An email as it was sent: the page that web/ made of its HTML"
@def mutable struct SentEmail <: SemanticUI
  path::String = ""                          # the email's file
  read::Float64 = -1.0                       # when the file had last changed, as its HTML was read
  html::String = ""                          # the email's HTML, or "" for an email with none
  remote::Bool = false                       # the HTML has pictures from a web site
  pictures::Bool = false                     # and you asked for them, for this email or for each email from its sender
  sender::String = ""                        # the address that the email is from, in lower case, or ""
  store::Any = nothing                       # the pictures of the HTML that are read already, which each layout uses again
  waiting::Set{String} = Set{String}()       # the addresses of the pictures that are on their way from the web
  landed::Int = 0                            # how many of them have come, or couldn't be fetched
  arrived::Int = 0                           # and how many had when the page was last asked for
  asked::Any = nothing                       # the width, the zoom and the pictures that the page needs now, and since when
  shown::Any = nothing                       # the page that shows, what it was laid out for, when, and how long that took
  since::Float64 = 0.0                       # when the email first showed: its pictures that move, like a GIF, started then
  failed::Any = nothing                      # what the page couldn't be laid out for
  parts::Dict{Any,Any} = Dict{Any,Any}()     # its button, and the part that shows the page
end

"""
The part of an email as it was sent that draws the page, and takes the mouse
for the email's links and its words. A place in the words is how many of
their letters come before it, as `WebSelect.place` gives it.
"""
@def mutable struct SentPage <: SemanticUI
  of::Any = nothing
  said::Bool = false                 # its tooltip shows, with where a link goes
  anchor::Int = 0                    # the place where the selection of the words starts
  caret::Int = 0                     # and the place where it ends, which the mouse moves while you drag
  clicked::Any = (0.0, -1, 0)        # when the last click was, at which place, and how many clicks there have been there
  grown::Tuple{Int,Int} = (0, 0)     # what the click selected, which a drag makes bigger: the place, or the word or the paragraph at it
  grain::Int = 1                     # what a drag selects: 1 a letter at a time, 2 a word, 3 a paragraph
  down::Any = nothing                # where the mouse went down in the window, while it's down
  link::String = ""                  # the link that the mouse went down on. It opens when the mouse comes up on it, after no drag.
end

"The folder that keeps what's known of the email at `path`"
sent_dir(path) = joinpath(media_dir(), "emails", string(hash(abspath(path)), base=16))

"The file in an email's folder that says you asked for its pictures from the web"
sent_mark(path) = joinpath(sent_dir(path), ".pictures")

"The file in Ladder's own folder that lists the addresses whose emails get their pictures from the web, one on each line"
picture_senders_file() = joinpath(dirname(settings_file()), "picture senders")

"The addresses whose emails get their pictures from the web, in lower case"
picture_senders() = begin
  file = picture_senders_file()
  lines = isfile(file) ? (try readlines(file) catch; String[] end) : String[]
  Set(lowercase(strip(l)) for l in lines if !isempty(strip(l)))
end

"Note that each email from `address` gets its pictures from the web from now on"
picture_sender!(address) = begin
  (isempty(address) || address in picture_senders()) && return
  try
    mkpath(dirname(picture_senders_file()))
    open(io -> println(io, address), picture_senders_file(), "a")
  catch err
    @warn "Ladder couldn't note that this sender's emails get their pictures" address exception=err
  end
  nothing
end

"The page's email as it was sent, when the page is an email with HTML, or nothing. Its HTML is read here, once."
sent_html(e) = begin
  b = e.buf
  (b.view == :markdown && Eml.isemail(b.path) && isfile(b.path)) || return nothing
  v = node!(SentEmail, e, :sent_email)
  at = mtime(b.path)
  if v.path != b.path || v.read != at
    v.path, v.read, v.html = b.path, at, Eml.webpage(b.path)
    v.remote = Webpages.remote(v.html)
    v.sender = Eml.sender(b.lines)
    v.pictures = v.remote && (isfile(sent_mark(b.path)) || (!isempty(v.sender) && v.sender in picture_senders()))
    v.asked = v.shown = v.failed = v.store = nothing
    v.since = time()
    empty!(v.waiting)
    v.landed = v.arrived = 0
    # Nothing of the email that showed before stays selected
    page = get(v.parts, :page, nothing)
    page === nothing || (page.anchor = page.caret = 0)
  end
  isempty(v.html) ? nothing : v
end

"""
The email that shows, as it was sent, or nothing while the page shows its
words: at the low level, for an email with no HTML, and when it can't be laid
out. While the find bar is open, the page shows the email's words, since
those are what the bar finds and marks.
"""
sent_email(e) = begin
  v = e.plain || finding(e) ? nothing : sent_html(e)
  v === nothing && return nothing
  sent_page!(e, v)
  v.shown === nothing ? nothing : v
end

"""
Lay the email out for what the page needs now: as wide as the page's text, at
the page's zoom, with the pictures that have come from the web. Most email
takes a few thousandths of a second, and is laid out again in each frame
while the window changes size. An email that takes longer waits until the
width has stayed for a moment. Until then the page that was laid out for the
width before shows, as wide as the page is now.
"""
sent_page!(e, v::SentEmail) = begin
  sent_arrivals!(e, v)
  # The page is laid out for the room inside the line round the email
  want = (round(Int, num(e.width - 2SENT_LINE)), round(Float64(e.zoom), digits=2), v.pictures, v.arrived)
  (v.shown !== nothing && v.shown.want == want) && return v
  v.failed == want && return v
  if v.shown !== nothing && v.shown.took > SENT_QUICK && v.shown.want[2:4] == want[2:4]
    (v.asked === nothing || v.asked[1] != want) && (v.asked = (want, time()))
    rest = MAP_PAUSE - (time() - v.asked[2])
    rest > 0 && return (redraw_in!(e, max(rest, 0.05)); v)
  end
  v.store === nothing && (v.store = Web.Pictures(src -> sent_bytes(e, v, src)))
  t = time()
  page = try SENT_PAGE[](v.html; wide=want[1], zoom=want[2], fit=true, pictures=v.store) catch; nothing end
  if page === nothing
    v.failed, v.shown = want, nothing
  else
    v.failed, v.shown = nothing, (page=page, want=want, at=time(), took=time() - t)
  end
  v
end

"""
The bytes of the picture at the web address `src`, for an email that you asked
to get its pictures, or nothing while the picture isn't here. A window that
isn't on the screen fetches nothing.
"""
sent_bytes(e, v::SentEmail, src) = begin
  (v.pictures && startswith(src, r"https?://"i)) || return nothing
  (on_screen(e) || haskey(fetches, src)) || return nothing
  file = fetched(e, src)
  if file === nothing
    get(fetches, src, nothing) isa Base.Process && push!(v.waiting, src)
    return nothing
  end
  try read(file) catch; nothing end
end

"""
Note which of the email's pictures have come from the web, so that the email
is laid out again with them: once they're all here, and twice a second while
some are still on their way.
"""
sent_arrivals!(e, v::SentEmail) = begin
  for src in collect(v.waiting)
    fetched(e, src)   # this looks whether the picture has come, and asks for another frame while it hasn't
    get(fetches, src, nothing) isa Base.Process && continue
    delete!(v.waiting, src)
    v.landed += 1
  end
  v.landed == v.arrived && return
  (isempty(v.waiting) || v.shown === nothing || time() - v.shown.at > 0.5) || return
  v.arrived = v.landed
  v.store === nothing || Web.retry!(v.store)
  nothing
end

"What the two levels of an email with HTML show, from the lower, as the tips of the snake and the ladder say it"
const SENT_LEVELS = ("the plain text email", "the HTML email")

"""
Why the window shows the words of the page's email at the level where it
should show the email as it was sent, or nothing. It's so when the email
can't be laid out.
"""
sent_problem(e) = begin
  v = sent_html(e)
  (v === nothing || e.plain) && return nothing
  v.shown === nothing && v.failed !== nothing ? SENT_FAILED : nothing
end

"The lines of the page that the email as it was sent stands for: from the line after its card to the line before the links to its files"
sent_lines(e) = begin
  b = e.buf
  first = front_matter(b.lines) + 1
  last = attached_from(e) - 1
  first <= last ? (first, last) : nothing
end

"The first of the lines at the end of the email's page that link to its files. See `Eml.attached`."
attached_from(e) = (b = e.buf; get!(() -> Eml.attached(b.path, b.lines), e.flows, (:attached, b.path, b.version)))

"What the email as it was sent shows on the page, with how tall it is"
sent_item(e, v::SentEmail) = begin
  own!(node!(Document, e, :document), v)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(v)), (e.width, 99999px))
  Live(v, concrete.height + 2LIVE_GAP)
end

describe(v::SentEmail) = begin
  e = editor(v)
  with_theme(component_theme(e.zoom)) do
    words = isempty(v.sender) ? "Get this email's pictures from the web. Its sender can then tell that you opened it." :
      "Get this email's pictures from the web, and the pictures of each email from $(v.sender) from now on. The sender can then tell when you open them."
    bar = v.remote && !v.pictures && v.shown !== nothing ?
      (Row(width(grow=grow), Alignment.Center, justify=Alignment.End, block_button!(v, :pictures, :pictures, words="Load pictures", icon="image", tip=words)),) : ()
    # The links to the email's files are under it, with some room between
    Column(width(grow=grow), Alignment.Start, child_gap=4px, name="Email as sent", bar..., block_part!(() -> SentPage(of=v), v, :page), Box(height(6px)))
  end
end

describe(a::SentPage) = begin
  v = a.of
  e = editor(v)
  wide = e.width
  page = v.shown.page
  # The email is as wide as the page's text, also while it waits to be laid out for a width that has just changed
  inside = wide - 2SENT_LINE
  # A picture of the email that moves, like a GIF, shows its next picture when that's due: the window is drawn again then
  at = time() - v.since
  next = Web.changes(v.shown.page, at)
  isfinite(next) && redraw_in!(a, max(SENT_FRAME, next - at))
  Column(fixed(wide), Alignment.Start, radius(6px), border(SENT_LINE, :solid, colours.line), background(colorant"white"),
    Box(fixed(inside), height(px(round(Int, page.tall) * num(inside) / round(Int, page.wide)))))
end

# The email is drawn inside the line round it: its page, and over that the words that are selected, while the email
# has the keyboard. An email is written for a white page, so it's drawn on one.
draw(ctx, size, ui::ConcreteRect, a::SentPage) = begin
  shown = a.of.shown
  shown === nothing && return
  left, top, wide, tall = ui.left + SENT_LINE, ui.top + SENT_LINE, ui.width - 2SENT_LINE, ui.height - 2SENT_LINE
  (wide > 0px && tall > 0px) || return
  page = shown.page
  by = num(wide) / round(Int, page.wide)
  w, n = window_of(a), WebSelect.letter_count(page.words)
  marks = w === nothing || w.focus !== a ? () : WebSelect.marks(page.words, clamp(a.anchor, 0, n), clamp(a.caret, 0, n))
  with_round_clip(ctx, left, top, wide, tall, 5px) do
    Skia.sk_canvas_save(ctx)
    Skia.sk_canvas_translate(ctx, Float32(num(left)), Float32(num(top)))
    Skia.sk_canvas_scale(ctx, Float32(by), Float32(by))
    # Its pictures that move are drawn as they are now, this long after the email first showed
    Web.draw(ctx, shown.page; at=time() - a.of.since)
    for (x, y, across, high) in marks
      rectangle(ctx, x, y, across, high, background=colours.select)
    end
    Skia.sk_canvas_restore(ctx)
  end
end

"""
Where the mouse is on the page of the email, in the px of the page as it was
laid out, or nothing. With it are where the page starts in the window, and
how many px of the page a px of the window is.
"""
sent_mouse(a::SentPage) = begin
  w, v = window_of(a), a.of
  (w === nothing || v.shown === nothing) && return nothing
  r = rect(a)
  r.width > 2SENT_LINE || return nothing
  # The page starts inside the line round the email
  left, top = r.left + SENT_LINE, r.top + SENT_LINE
  by = round(Int, v.shown.page.wide) / num(r.width - 2SENT_LINE)
  (x=num(w.mouse[1] - left) * by, y=num(w.mouse[2] - top) * by, left=left, top=top, by=by)
end

"The link of the email that the mouse is over, as `Web.link` gives it, and its rectangle in the window, or nothing"
sent_link(a::SentPage) = begin
  m = sent_mouse(a)
  m === nothing && return nothing
  l = Web.link(a.of.shown.page, m.x, m.y)
  by = m.by
  l === nothing ? nothing : (url=l.url, box=(m.left + px(l.left / by), m.top + px(l.top / by), px(l.wide / by), px(l.tall / by)))
end

"The place in the email's words that's nearest the mouse, or nothing"
sent_place(a::SentPage) = (m = sent_mouse(a); m === nothing ? nothing : WebSelect.place(a.of.shown.page.words, m.x, m.y))

cursor(::SentEmail) = :arrow
cursor(a::SentPage) = begin
  sent_link(a) === nothing || return :hand
  m = sent_mouse(a)
  m !== nothing && WebSelect.over_words(a.of.shown.page.words, m.x, m.y) ? :ibeam : :arrow
end

"""
Select the words of the email from where the click selected them to the place
`at`. After two clicks, the drag selects whole words, and after three, whole
paragraphs, as it does in a browser.
"""
sent_select!(a::SentPage, at) = begin
  s = a.of.shown.page.words
  lo, hi = a.grown
  from, to = a.grain == 2 ? WebSelect.word(s, at) : a.grain == 3 ? WebSelect.paragraph(s, at) : (at, at)
  a.anchor, a.caret = at < lo ? (hi, from) : (lo, max(hi, to))
  a
end

"Copy the words of the email that are selected. It's false when none are."
sent_copy!(a::SentPage) = begin
  v, w = a.of, window_of(a)
  (w === nothing || v.shown === nothing || a.anchor == a.caret) && return false
  words = WebSelect.copied(v.shown.page.words, a.anchor, a.caret)
  isempty(words) ? false : (clipboard!(w, words); true)
end

"Select all the words of the email"
sent_select_all!(a::SentPage) = begin
  a.of.shown === nothing || ((a.anchor, a.caret) = (0, WebSelect.letter_count(a.of.shown.page.words)))
  a
end

"The part of the window's email that draws its page, when it has the keyboard, or nothing"
sent_keys(e) = (w = window_of(e); w !== nothing && w.focus isa SentPage ? w.focus : nothing)

# The mouse over a link says where the link goes, since the words of a link can say anything.
# With the button down, the mouse selects the words that it goes over.
onmouse(a::SentPage, ev::MouseMove) = begin
  w = ev.window
  if a.down !== nothing && Keys.mouse_left in w.keys && a.of.shown !== nothing
    at = sent_place(a)
    at === nothing || sent_select!(a, at)
    # A drag is no click, so the link that it started on doesn't open
    hypot(num(w.mouse[1] - a.down[1]), num(w.mouse[2] - a.down[2])) > 4 && (a.link = "")
    a.said && hide_tooltip!(w)
    a.said = false
    return nothing
  end
  a.down = nothing
  l = sent_link(a)
  if l !== nothing
    show_tooltip!(ev.window, tip_label(sent_address(l.url)), l.box..., placement=:bottom, gap=6px)
  elseif a.said
    hide_tooltip!(ev.window)
  end
  a.said = l !== nothing
  nothing
end

"A web address as a tooltip says it: without mailto:, and with its middle left out when it's long"
sent_address(url) = begin
  url = String(chopprefix(url, r"^mailto:"i))
  length(url) <= 90 ? url : first(url, 60) * "…" * last(url, 25)
end

"""
A click on the email gives it the keyboard, so that ⌘C copies the words that
it selects. One click puts the selection's start at the place, two select the
word there, and three its paragraph. With ⇧ held, the click moves the end of
the selection there. The page notes the click too, and leaves the keyboard
with the email.
"""
onkey(a::SentPage, ev::KeyPress{Keys.mouse_left}) = begin
  s = a.of.shown === nothing ? nothing : a.of.shown.page.words
  at = sent_place(a)
  (s === nothing || at === nothing) && return nothing
  focus(a)
  w = ev.window
  t, before, n = a.clicked
  n = time() - t < 0.4 && before == at ? n % 3 + 1 : 1
  a.clicked = (time(), at, n)
  a.grain = n
  a.grown = n == 2 ? WebSelect.word(s, at) : n == 3 ? WebSelect.paragraph(s, at) : only_held(a, Keys.shft) ? (a.anchor, a.anchor) : (at, at)
  sent_select!(a, at)
  a.down = (w.mouse[1], w.mouse[2])
  l = sent_link(a)
  a.link = l === nothing || !unmodified(a) ? "" : l.url
  nothing
end

# A click on a link of the email opens it in the app that the Mac uses for it, once the button comes up on the
# link with no drag. A drag from a link selects its words.
onkey(a::SentPage, ev::KeyRelease{Keys.mouse_left}) = begin
  a.down = nothing
  url, a.link = a.link, ""
  l = isempty(url) ? nothing : sent_link(a)
  (l === nothing || l.url != url) && return nothing
  hide_tooltip!(ev.window)
  a.said = false
  a.caret = a.anchor
  Webpages.open_link(url)
  handled
end

"""
While the email has the keyboard, ⌘C copies the words that are selected, and
⌘A selects them all. A key that isn't held with ⌘ or ⌃, like Space or ↓, gives
the keyboard back to the page, and the page takes the key, so the keys that
scroll an email still scroll it. Esc only gives the keyboard back.
"""
onkey(a::SentPage, ev::KeyPress{K}) where K = begin
  w = ev.window
  (ismouse(K) || K in (Keys.cmd, Keys.ctrl, Keys.opt, Keys.shft, Keys.fn, Keys.capslock)) && return nothing
  cmd = only_held(w, Keys.cmd)
  cmd && K == Keys.c && return (sent_copy!(a); handled)
  cmd && K == Keys.a && return (sent_select_all!(a); handled)
  (Keys.cmd in w.keys || Keys.ctrl in w.keys) && return nothing
  focus(editor(a))
  K == Keys.escape ? handled : nothing
end

"Do what a button of the email does: get the email's pictures from the web, now and each time it shows, and the pictures of each email from the same sender"
act!(v::SentEmail, action, w) = begin
  action == :pictures || return handled
  v.pictures = true
  v.store === nothing || Web.retry!(v.store)
  try
    mkpath(sent_dir(v.path))
    touch(sent_mark(v.path))
  catch
  end
  picture_sender!(v.sender)
  redraw_in!(v, 0.0)
  handled
end

# --- the files that came with an email --------------------------------------------------
#
# The lines at the end of an email's page link to the files that came with it,
# like the PDF of an invoice. Each shows as a file's icon, with the file's name
# and its size under it, as the Finder and Mail show a file. The icon says what
# kind of file it is. When there are more than fit across the page, they go on
# in the next row. A click on one opens the file, as a click on its link did.
# A picture that came with an email isn't one of these: it shows as a picture.

# The sizes of a file's icon, of its name and of its size, and the room round them, as parts of the size of the page's text
const FILE_ICON, FILE_NAME, FILE_SIZE, FILE_PAD = 2.4, 0.76, 0.68, 0.45
const FILE_WIDE, FILE_GAP = 7.4, 0.4   # how wide each file is, and the room between two, as parts of the same size
const FILE_LINE = 1.3                  # how tall a line of a file's name is, as a part of the size of its text

"A line that holds only a link: its words and its address"
const FILE_LINK = r"^\[([^\]]*)\]\(([^)\s]+)\)$"

"One of the files that came with an email, as its icon with its name and its size under it"
@def mutable struct AttachedFile <: SemanticUI
  name::String = ""
  path::String = ""
  lines::Vector{String} = String[]   # the name as it shows: in one line or two, and cut short when it doesn't fit
  cut::Bool = false                  # true when the lines leave out part of the name
  bytes::String = ""                 # how big the file is, in words
  shown::Any = nothing               # the size of the text and the name that the lines were made for
end

"The files that the lines `from` to `to` of an email's page link to, which show as icons in rows"
@def mutable struct AttachedFiles <: SemanticUI
  from::Int = 0
  to::Int = 0
  files::Vector{AttachedFile} = AttachedFile[]
end

"How tall a file's icon is with its name and its size under it, in a page whose text is `s` tall"
file_tall(s) = s * (2FILE_PAD + FILE_ICON + 0.35 + FILE_LINE * (2FILE_NAME + FILE_SIZE))

"""
The name and the path of the file that line `i` of an email's page links to,
when the line is one of the links at the end to the email's own files and the
file isn't a picture. It's nothing for any other line.
"""
attached_file(e, i) = begin
  b = e.buf
  i >= attached_from(e) || return nothing
  m = match(FILE_LINK, b.lines[i])
  m === nothing && return nothing
  path = unescaped(String(m[2]))
  startswith(path, Eml.attachments(b.path) * "/") ? (String(m[1]), path) : nothing
end

"""
What lines `i` on show when line `i` is the first of the links to the files
that came with an email: the icons of the files of that line and of the links
that follow it. It's nothing for any other line.
"""
attached_item(e, i) = begin
  found = attached_file(e, i)
  found === nothing && return nothing
  files = [found]
  j = i
  while j < length(e.buf.lines) && (next = attached_file(e, j + 1)) !== nothing
    push!(files, next)
    j += 1
  end
  v = node!(AttachedFiles, e, (:attached_files, i))
  v.from, v.to = i, j
  v.files = map(files) do (name, path)
    k = findfirst(f -> f.path == path, v.files)
    k === nothing || return v.files[k]
    f = AttachedFile(name=name, path=path, bytes=isfile(path) ? bytes(filesize(path)) : "")
    setfield!(f, :parent, v)
    f
  end
  own!(node!(Document, e, :document), v)
  s = body(e).size
  across = files_across(e, length(files))
  rows = cld(length(files), across)
  Live(v, rows * file_tall(s) + (rows - 1) * FILE_GAP * s + 2LIVE_GAP)
end

"How many of `n` files fit across the page of `e`"
files_across(e, n) = (s = body(e).size; clamp(floor(Int, num(e.width + FILE_GAP * s) / num((FILE_WIDE + FILE_GAP) * s)), 1, max(n, 1)))

describe(v::AttachedFiles) = begin
  e = editor(v)
  across = files_across(e, length(v.files))
  rows = Iterators.partition(v.files, across)
  Column(width(grow=grow), Alignment.Start, child_gap=FILE_GAP * body(e).size, name="Attached files",
    (Row(Alignment.Start, child_gap=FILE_GAP * body(e).size, row...) for row in rows)...)
end

"""
The name of a file as it shows under its icon, as the Finder writes it: in one
line, or in two when it's too wide for one, with each line no wider than
`room` in `face`. A name that's too long for two lines loses letters from the
middle of its second line, so the end of the name still shows. It's the lines,
and whether any of the name is left out.
"""
icon_name(face::Face, name, room) = begin
  fits(s) = measure(face, s) <= room
  fits(name) && return ([String(name)], false)
  cs = collect(name)
  n = 1
  while n < length(cs) - 1 && fits(String(cs[1:n+1])); n += 1 end
  top(k) = String(rstrip(String(cs[1:k])))
  rest(k) = String(lstrip(String(cs[k+1:end])))
  # The first line ends after a space or a mark in the name, when one is in its second half. When the
  # rest is then too wide for the second line, but not when the first line is as full as it can be, it ends there.
  mark = findlast(c -> c in (' ', '-', '_', '.', ','), cs[1:n])
  k = mark !== nothing && mark > n ÷ 2 ? mark : n
  fits(rest(k)) && return ([top(k), rest(k)], false)
  fits(rest(n)) && return ([top(n), rest(n)], false)
  rs = collect(rest(k))
  for keep in length(rs)-1:-1:1
    head = keep ÷ 2
    line = rstrip(String(rs[1:head])) * "…" * String(rs[end-(keep-head)+1:end])
    fits(line) && return ([top(k), line], true)
  end
  ([top(k), "…"], true)
end

describe(f::AttachedFile) = begin
  e = editor(f)
  s = body(e).size
  wide, pad = FILE_WIDE * s, FILE_PAD * s
  name = Face(SANS, "", FILE_NAME * s, colours.ink, false)
  if f.shown != (s, f.name)
    f.lines, f.cut = icon_name(name, f.name, wide - 2pad)
    f.shown = (s, f.name)
  end
  icon = FILE_ICON * s
  line(text, size, color) = Box(height(size * FILE_LINE), Alignment.Center, label(text, size, color=color))
  Column(fixed(wide), height(file_tall(s)), padding(pad), Alignment.Center, radius(8px), name="Attached file",
         background(ishovered(f) ? colours.hover : clear),
    Box(fixed(icon), height(icon), Alignment.Center, justify=Alignment.Center, Icon(file_icon(f.path), size=icon, color=colours.dim)),
    Box(height(0.35s)),
    (line(l, name.size, colours.ink) for l in f.lines)...,
    (isempty(f.bytes) ? () : (line(f.bytes, FILE_SIZE * s, colours.faint),))...)
end

cursor(::AttachedFile) = :hand

# A name that's cut short shows whole under the file
onmouse(f::AttachedFile, ev::MouseMove) = f.cut ?
  (r = rect(f); show_tooltip!(ev.window, tip_label(f.name), r.left, r.top, r.width, r.height, placement=:bottom, gap=6px)) : nothing

# A click opens the file, as a click on its link did. A click with ⌥ held is the page's.
onkey(f::AttachedFile, ::KeyPress{Keys.mouse_left}) = begin
  only_held(f, Keys.opt) && return nothing
  isfile(f.path) && open!(editor(f), f.path)
  handled
end
