# Front matter as a card, and a cover picture
#
# While the caret isn't in it, front matter shows as a card: a small FRONTMATTER
# heading, then each key with what it's set to. A click on the card puts the
# caret in the line that was clicked, and the lines show as they're written.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw cursor with_round_clip
@use "github.com/jkroso/UI.jl/Interface/image" image_source
@use "./pictures" picture
@use "./markdown" words
@use "./mime" => Mime
@use "./base" exports...

export MatterCard, MatterRow, matter_rows, COVER_MOST, COVER_GAP, CoverPicture, cover_key, cover_part,
       matter_card, email_head, edit_matter!

"Front matter, shown as a card"
@def mutable struct MatterCard <: SemanticUI
  rows::Vector{Tuple{Int,String,String}} = Tuple{Int,String,String}[]   # the line, the key and what it's set to
  size::px = 13px                                                       # of the text
end

"A key of front matter and what it's set to, in its card"
@def mutable struct MatterRow <: SemanticUI
  line::Int = 0
  key::String = ""
  value::String = ""
  keys::px = 0px    # how wide the widest key is, so that what each is set to starts in one place
  size::px = 13px
end

"""
The keys of the front matter that ends at line `t`, each with the line it's on and
what it's set to. A line that goes on from the one above, like an item of a list,
joins what that key is set to. A comment isn't shown.
"""
matter_rows(lines, t) = begin
  toml = rstrip(lines[1]) == "+++"
  key = toml ? r"^\s*((?:\"[^\"]*\"|'[^']*'|[\w.-])+)\s*=\s*(.*)$" : r"^([^:#\s-][^:#]*):(?:\s+(.*)|$)"
  rows = Tuple{Int,String,String}[]
  for i in 2:t-1
    text = rstrip(lines[i])
    (isempty(strip(text)) || startswith(lstrip(text), '#')) && continue
    m = match(key, text)
    if m !== nothing
      push!(rows, (i, String(m[1]), something(m[2], "")))
    elseif toml && startswith(lstrip(text), '[') && !isempty(rows) && !endswith(last(rows)[3], ',') && !endswith(last(rows)[3], '[')
      push!(rows, (i, String(strip(text)), ""))   # a [table] that starts a group of keys
    elseif isempty(rows)
      push!(rows, (i, "", String(strip(text))))
    else
      # An item of a list, or the next part of a value that goes over several lines
      at, k, v = pop!(rows)
      part = strip(replace(strip(text), r"^-\s+" => ""))
      push!(rows, (at, k, isempty(v) ? String(part) : endswith(v, '[') ? v * part : v * (startswith(text, r"\s*-\s") ? ", " : " ") * part))
    end
  end
  rows
end

# --- a cover picture ---------------------------------------------------------------------------
#
# A key `cover` in the front matter names a picture, as a picture's line does:
# a file, named from the page's folder, or an address on the web.
#
#     ---
#     title: Kitchen
#     cover: photos/kitchen.jpg
#     ---
#
# The picture goes across the top of the page. It's as wide as the page's text,
# a third as tall as that, and no taller than `COVER_MOST`. It fills that room:
# its middle shows, and what's over the edges of the room is cut off. The card
# of the front matter is under it, without the `cover` key. Front matter that
# has only a cover shows only the picture. A click on the picture selects the
# front matter, and ⌥-click shows its lines, where you change the cover. A
# cover that isn't a picture, or isn't there, shows nothing, and the card shows
# the key as it's written. A page as HTML has the picture at its top too.

const COVER_MOST = 260px   # how tall a cover can be
const COVER_GAP = 16px     # between the cover and the card under it

"The cover picture across the top of the page, with the card of the front matter under it, or with no card"
@def mutable struct CoverPicture <: SemanticUI
  key::String = ""    # of the picture, for an Image
  wide::px = 0px
  tall::px = 0px
  card::Any = nothing
end

"The key of the picture that the `cover` of the front matter names, or nothing. `rows` are the keys of the front matter."
cover_key(e, rows) = begin
  k = findfirst(r -> lowercase(r[2]) == "cover", rows)
  k === nothing && return nothing
  src = String(strip(rows[k][3], ['"', '\'', ' ']))
  isempty(src) && return nothing
  in_browser(e.buf.path) && (src = something(remote_src(e, src), ""); isempty(src) && return nothing)
  path = startswith(src, r"https?://") ? fetched(e, src) : abspath(docdir(e), expanduser(src))
  path === nothing ? nothing : picture_key(path)
end

# The room at the top is empty, and `draw` paints the picture into it, as a gallery's square does
describe(c::CoverPicture) = begin
  picture = Box(fixed(c.wide), height(c.tall), radius(8px), background(colours.block), name="Cover")
  Column(width(grow=grow), Alignment.Start, child_gap=COVER_GAP, picture, (c.card === nothing ? () : (geometry(c.card),))...)
end

"The part of a picture `w` by `h` pixels that fills a room `wide` by `tall`: its middle, as wide or as tall as it is, whichever fills the room"
cover_part(w, h, wide, tall) = w / h > wide / tall ?
  ((w - h * wide / tall) / 2, 0.0, h * wide / tall, Float64(h)) :
  (0.0, (h - w * tall / wide) / 2, Float64(w), w * tall / wide)

draw(ctx, size, ui::ConcreteRect, c::CoverPicture) = begin
  image = try image_source(c.key) catch; nothing end
  image === nothing && return
  wide, tall = num(c.wide), num(c.tall)
  with_round_clip(ctx, ui.left, ui.top, px(wide), px(tall), 8px) do
    paint_picture(ctx, image.raw, cover_part(image.width, image.height, wide, tall), (num(ui.left), num(ui.top), wide, tall))
  end
end

cursor(::CoverPicture) = :arrow
onkey(c::CoverPicture, ev::KeyPress{Keys.mouse_left}) = click_page!(c, ev)

"The front matter that ends at line `t`, as a card, as the top of an email, or as what code from the startup page shows there, or nothing when its page's kind of folder hides it. A `cover` key puts a picture over it."
matter_card(e, t) = begin
  rows = matter_rows(e.buf.lines, t)
  cover = cover_key(e, rows)
  cover === nothing || (rows = filter(r -> lowercase(r[2]) != "cover", rows))
  card = first_answer(MATTER_CARDS, e, rows)
  # A kind of folder can show the front matter of a page that it holds its own way, as a blog shows a book review's
  o = card === nothing ? text_object(e) : nothing
  o === nothing || (card = matter_view(e, o.parent, o, rows))
  if card === false
    # ... or nothing in its place. With the caret on it as a whole, it shows as a card, so you see what ⌫ would take
    # away, and Return shows its lines.
    picked(e.buf) == (1, t) || return nothing
    card = nothing
  end
  if card === nothing
    # An email that came or went shows the top of an email in place of its keys. That top has levels of its own.
    card = email_shows(e, Dict(lowercase(k) => v for (_, k, v) in rows)) ? email_head!(e) : node!(MatterCard, e, :matter)
    card.rows = rows
    card.size = body(e).size * 0.76
  end
  if cover !== nothing
    c = node!(CoverPicture, e, :cover_picture)
    c.key, c.wide, c.tall = cover, e.width, min(e.width / 3, COVER_MOST)
    # Front matter with only a cover shows only the picture
    c.card = card isa MatterCard && isempty(rows) ? nothing : own!(node!(Document, e, :document), card)
    card = c
  end
  own!(node!(Document, e, :document), card)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(card)), (e.width, 9999px))
  Live(card, concrete.height + 2LIVE_GAP)
end

"The table in lines `from` to `to` as what its page's kind of folder shows in its place, or nothing when the kind shows the table: see `table_view`"
table_item(e, from, to) = begin
  o = text_object(e)
  o === nothing && return nothing
  node = table_view(e, o.parent, o, from, to)
  node === nothing && return nothing
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

describe(c::MatterCard) = begin
  s = c.size
  e = editor(c)
  # Code from the startup page can give the card another name, as a draft of an email has
  title = something(first_answer(MATTER_TITLES, e), "FRONTMATTER")
  keyface = Face(SANS, "Semibold", s, colours.dim, false)
  keys = maximum(r -> measure(keyface, r[2]), c.rows, init=0px)
  Column(width(grow=grow), Alignment.Start, padding(s, s * 0.7), child_gap=s * 0.4, radius(6px),
         border(1px, :solid, colours.line), background(colours.block), name="Front matter",
    # The heading has a little more room under it than the rows have between them
    Box(padding(0px, 0px, s * 0.2, 0px), label(title, s * 0.72, color=colours.dim, weight="Bold")),
    [MatterRow(line=at, key=k, value=v, keys=keys, size=s) for (at, k, v) in c.rows]...)
end

describe(r::MatterRow) = begin
  s, keys = r.size, r.keys
  Row(width(grow=grow), Alignment.Start, padding(0px, s * 0.15), child_gap=(keys > 0px ? s * 0.9 : 0px),
    (keys > 0px ? (Box(fixed(keys), label(r.key, s, color=colours.dim, weight="Semibold")),) : ())...,
    Box(width(grow=grow), Alignment.Start, Text(r.value, size=s, family=SANS, color=colours.ink, wrap=WrapMode.words)))
end

"""
The top of an email at its highest level: the subject as a title, then who
sent it with the date at the right, then who it's to. `said` is what the front
matter sets each key to.
"""
email_head(c::EmailHead, said) = begin
  s = c.size
  # Each person's name, or the address of one with no name
  people(key) = join((isempty(name) ? address : name for (name, address) in Mime.addresses(get(said, key, ""))), ", ")
  from = Mime.addresses(get(said, "from", ""))
  name, address = isempty(from) ? (get(said, "from", ""), "") : (first(from)[1], first(from)[2])
  isempty(name) && ((name, address) = (address, ""))
  subject = get(said, "subject", "")
  line(words) = Box(width(grow=grow), Alignment.Start, Text(words, size=s, family=SANS, color=colours.dim, wrap=WrapMode.words))
  high = s * 1.5   # a line of one size of text, with room for the tails of its letters
  Column(width(grow=grow), Alignment.Start, padding(0px, s * 0.2, s * 1.1, 0px), child_gap=s * 0.55, name="Email head",
         border(1px, :solid, colours.line)[:bottom],
    Box(width(grow=grow), Alignment.Start, padding(0px, 0px, s * 0.5, 0px),
      Text(isempty(subject) ? "No subject" : subject, size=s * 1.6, family=SANS, subfamily="Semibold", color=colours.ink, wrap=WrapMode.words)),
    # A line of text is as tall as its capitals, with the foot of its letters at its bottom. So the
    # inner Row, which puts each part at its bottom, puts the name, the address and the date on one line.
    # The address is cut at its sides only, so the tops of its tall letters show.
    Row(width(grow=grow), height(high),
      Row(width(grow=grow), Alignment.End, child_gap=s * 0.6,
        Box(label(name, s * 1.05, weight="Semibold")),
        Box(width(grow=grow), Alignment.Start, clip_x=true, label(address, s, color=colours.dim)),
        Box(label(get(said, "date", ""), s, color=colours.dim)))),
    (haskey(said, "to") ? (line("To " * people("to")),) : ())...,
    (haskey(said, "cc") ? (line("Cc " * people("cc")),) : ())...)
end

cursor(::Union{MatterCard,MatterRow}) = :arrow
onkey(c::Union{MatterCard,MatterRow}, ev::KeyPress{Keys.mouse_left}) = click_page!(c, ev)

"Put the caret at the end of line `i` of the front matter, so it shows as it's written"
edit_matter!(node, i) = begin
  e = editor(node)
  b = e.buf
  b.caret = b.anchor = (i, length(b.lines[i]))
  focus(e)
  touch!(e)
  handled
end
