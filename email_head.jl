# The top of an email: its subject, who sent it and when, and who it's to, and every field of its header a level down
#
# This file also says when the top of a page, like the top of an email, has
# the ladder in the top bar: see `head_in_charge`. email_view.jl has the
# email under its top, as it was sent.

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" cursor
@use "./markdown" words front_matter
@use "./sheet" folded
@use "./eml" => Eml
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./file_view" exports...
@use "./live_view" exports...
@use "./cover_view" exports...

export HEAD_LEVELS, fold, header_fields!, own_levels, part_of, whole_header

# --- the top of an email -----------------------------------------------------------
#
# An email that came or went shows the top of an email in place of the card of
# its front matter: its subject, who sent it and when, and who it's to. That
# top is a part of the page with two levels of its own. A level down, it shows
# every field of the email's header, like Received, Message-ID and
# DKIM-Signature, each with its value. A page that's an email but not an .eml
# file shows the keys of its front matter there.
#
# A click on the top gives it the keyboard, and a line goes round it. On a page
# that can change, the caret can also go onto it as a whole. The ladder in the
# top bar is then the top's: ⌘E, the ladder and the slider go between its two
# levels, and it keeps the keyboard. Esc, a click on the page, or a key that
# scrolls the page gives the keyboard back to the page. The top stays at its
# level until another file shows. On a page that can change, Return shows the
# front matter as it's written.

const HEAD_LEVELS = ("every field of the email's header", "the email's subject, sender and date")   # from the lower

"The top of the email that the page shows. It goes back to its highest level when another file shows."
email_head!(e) = begin
  h = node!(EmailHead, e, :email_head)
  h.path == e.buf.path || (h.path = e.buf.path; h.full = false)
  h.wide = e.width
  h
end

describe(h::EmailHead) = h.full ? whole_header(h) : email_head(h, Dict(lowercase(k) => v for (_, k, v) in h.rows))

"""
The fields of the email's header: those of its file, read again only when the
file changes. A page that's an email but not an .eml file has the keys of its
front matter, and so has a file whose header can't be read.
"""
header_fields!(h::EmailHead) = begin
  keys = [k => v for (_, k, v) in h.rows if !isempty(k)]
  Eml.isemail(h.path) || return keys
  now = (h.path, mtime(h.path))
  h.read_for == now || (h.fields = Eml.header_fields(h.path); h.read_for = now)
  isempty(h.fields) ? keys : h.fields
end

"""
`s` in lines no wider than `room` in `face`, joined with line breaks, for a
Text that breaks only there. Lines break at spaces. A word that's too wide for
a line of its own, like a DKIM signature, goes on from the line that it starts
on, when a quarter of that line or more is free. It breaks after its last
hyphen that fits, or between two characters when no hyphen fits. A line is as
wide as its characters added up.
"""
fold(s::AbstractString, face::Face, room) = begin
  wide(c::Char) = measure(face, string(c))
  space = wide(' ')
  # How many characters at the start of `word` fit in `free`: up to its last hyphen that fits, when one does
  fitting(word, free) = begin
    fits, hyphen, sofar = 0, 0, 0px
    for c in word
      sofar += wide(c)
      sofar > free && break
      fits += 1
      c == '-' && (hyphen = fits)
    end
    hyphen > 0 ? hyphen : fits
  end
  lines = String[]
  line, x, started = IOBuffer(), 0px, false
  for word in split(s)
    w = sum(wide, word, init=0px)
    if started && x + space + w <= room
      print(line, ' ', word)
      x += space + w
      continue
    end
    more = String(word)
    if started && w > room && room - x - space >= room / 4
      cut = fitting(more, room - x - space)
      cut > 0 && print(line, ' ', first(more, cut))
      more = String(chop(more, head=cut, tail=0))
      w = sum(wide, more, init=0px)
    end
    started && push!(lines, String(take!(line)))
    while w > room
      cut = max(fitting(more, room), 1)
      push!(lines, first(more, cut))
      more = String(chop(more, head=cut, tail=0))
      w = sum(wide, more, init=0px)
    end
    print(line, more)
    x, started = w, true
  end
  started && push!(lines, String(take!(line)))
  join(lines, '\n')
end

"""
The top of an email a level down: every field of the email's header, each
with its value, in a card like the card of front matter. The names of the
fields take no more than a third of the card, and a name or a value that's
too wide breaks onto more lines.
"""
whole_header(h::EmailHead) = begin
  s = h.size
  keyface = Face(SANS, "Semibold", s, colours.dim, false)
  face = Face(SANS, "", s, colours.ink, false)
  gap = s * 0.9
  inner = h.wide - 2s - 2px   # inside the card's line and the room at its sides
  folded = something(h.folded, ((), nothing))
  fields = header_fields!(h)
  if folded[2] != (h.wide, s, fields)
    keys = min(maximum(f -> measure(keyface, f[1]), fields, init=0px), inner / 3)
    room = max(inner - keys - gap, 40px) * 0.98   # a little room for the letters' widths that `fold` adds up
    rows = [(fold(k, keyface, keys), fold(v, face, room)) for (k, v) in fields]
    folded = h.folded = ((keys, rows), (h.wide, s, fields))
  end
  keys, rows = folded[1]
  lines(words, sub, colour) = Text(words, size=s, family=SANS, subfamily=sub, color=colour, wrap=WrapMode.newlines)
  Column(width(grow=grow), Alignment.Start, padding(s, s * 0.7), child_gap=s * 0.4, radius(6px),
         border(1px, :solid, colours.line), background(colours.block), name="Email header",
    # The heading has a little more room under it than the rows have between them
    Box(padding(0px, 0px, s * 0.2, 0px), label("HEADER", s * 0.72, color=colours.dim, weight="Bold")),
    (Row(width(grow=grow), Alignment.Start, padding(0px, s * 0.15), child_gap=gap,
       Box(fixed(keys), Alignment.Start, lines(k, "Semibold", colours.dim)),
       Box(width(grow=grow), Alignment.Start, lines(v, "", colours.ink)))
     for (k, v) in rows)...)
end

levels(::EmailHead) = HEAD_LEVELS
level(h::EmailHead) = h.full ? 1 : 2
level!(h::EmailHead, i::Int) = (h.full = i == 1; h)

"""
What shows the page's front matter, like the top of an email, while the top
bar asks it for its levels: while it or a part of it has the keyboard, or
while the caret is on it as a whole. Otherwise it's nothing. One with no
levels of its own, like the card of front matter, is never in charge: the
page answers for it, as it does for any part with none. So code from the
startup page can show front matter as a part with levels of its own: see
`MATTER_CARDS`.
"""
head_in_charge(e) = begin
  w = window_of(e)
  (w === nothing || isempty(e.layout)) && return nothing
  it = e.layout[1]
  (it.content isa Live && it.first == 1 && it.last == front_matter(e.buf.lines)) || return nothing
  h = it.content.node
  # A part with none passes the question up to the window. If the window asked that part again, the two would ask each other without end.
  own_levels(h) || return nothing
  (part_of(w.focus, h) || ((w.focus === e || w.focus === input(e)) && picked(e.buf) == (it.first, it.last))) ? h : nothing
end

"True when `node` has levels of its own: its type has a method of `levels`, and not only the one that passes the question on to the part that it's in"
own_levels(node) = which(levels, Tuple{typeof(node)}) !== which(levels, Tuple{SemanticUI})

"True when `node` is `part`, or is in it"
part_of(node, part) = begin
  while node isa SemanticUI
    node === part && return true
    node = node.parent
  end
  false
end

cursor(::EmailHead) = :arrow
onkey(h::EmailHead, ::KeyPress{Keys.mouse_left}) = (focus(h); handled)
# On a page that can change, Return shows the front matter as it's written, as it does for any front matter
onkey(h::EmailHead, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (caretless(editor(h).buf) ? nothing : edit_matter!(h, isempty(h.rows) ? 1 : first(h.rows)[1])) : nothing
# A key that isn't held with ⌘ or ⌃, like Space or ↓, gives the keyboard back to the page, and the page takes the key.
# So the keys that scroll an email still scroll it. A shortcut like ⌘E goes on to the window with the top keeping the keyboard.
onkey(h::EmailHead, ev::KeyPress{K}) where K = begin
  w = ev.window
  (K in (Keys.cmd, Keys.ctrl, Keys.opt, Keys.shft, Keys.fn, Keys.capslock, Keys.escape) || Keys.cmd in w.keys || Keys.ctrl in w.keys) && return nothing
  focus(editor(h))
  nothing
end
