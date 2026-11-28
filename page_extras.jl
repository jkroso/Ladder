# Footnotes, find in the page, spelling, comments in the margin, the page as HTML, and the lines that just changed on the disk
#
# [^name] in a line points to a footnote, and a line that starts [^name]: holds
# the footnote's text. The page shows a small number in place of each: 1 for
# the first footnote that the text points to, and so on. Hold ⌘ and click a
# number to go to its footnote, and click the footnote's number to go back.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" rectangle rounded_rectangle
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" scene
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor redraw_in! popup! close_popup!
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" Mermaid
@use "./spelling" misspelt learn!
@use "./html" html footnotes NOTE escape
@use "./markdown" Kind classify spans words
@use "./sheet" parts shown
@use "./spreadsheet" moved
@use "./merge" follow
@use Colors: RGBA
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
@use "./additions" exports...
@use "./folder_page" exports...
@use "./linkcard_view" exports...
@use "./math_view" exports...
@use "./julia_levels" exports...
@use "./file_view" exports...
@use "./columns_view" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...
@use "./timelog_view" exports...
@use "./slides_view" exports...
@use "./agent/page" marking
@use "./media_view" table_html

export notes, follow_note!, NOTE_KEY, NOTE_WAIT, NOTE_CARD_W, note_at, note_card, note_peek!,
       FindBar, FindButton, find_input, open_find!, found, go_found!, find_step!, find_tick!,
       find_key!, FIND_W, findbar, CHECKED, spellable, misspellings, misspelling_at, respell!,
       spelling!, stretches, FOUND, annotate, COMMENT_W, COMMENT_GAP, COMMENT_PAD, COMMENT_SPACE,
       COMMENT_LEADING, PageComment, has_comments, comments_in, comment_w, comment_room,
       comment_balance, with_comments, page_comments, comment_face, Comments, CommentCard,
       mark_commented, add_comment!, selected_word, same_word, outline_same_word, spell_act!,
       SVG_TEXT_AS_SHAPES, diagram_svg, export_html!, stay!, FRESH, FRESH_FADE, fresh!, fresh,
       draw_fresh, NotePeek, note_peeked, FindState, CommentsSeen, FreshLines, save_panel

"The number of each footnote of the document, by name"
notes(e) = (b = e.buf; get!(() -> footnotes(b.lines), e.flows, (:notes, b.path, b.version)))

"The number that shows for the footnote `name`, as text"
note_mark(e, name) = (n = get(notes(e), String(name), 0); n == 0 ? String(name) : string(n))

"Go from where a footnote's number was clicked to its footnote, or from the footnote back to the first place that points to it"
follow_note!(e, name) = begin
  b = e.buf
  starts(text) = (m = match(NOTE, text); m !== nothing && m[1] == name)
  w = window_of(e)
  here = w === nothing ? b.caret[1] : locate(e, w.mouse)[1]
  to = if starts(b.lines[here])
    i = findfirst(text -> !starts(text) && occursin("[^$name]", text), b.lines)
    i === nothing ? nothing : (i, length(first(split(b.lines[i], "[^$name]"))))
  else
    i = findfirst(starts, b.lines)
    i === nothing ? nothing : line_end(b, i)
  end
  to === nothing && return
  b.caret = b.anchor = to
  touch!(e)
end

# When the mouse rests on a footnote's number in the text, a card under the
# number shows the footnote, as the page reads, so you can read it without
# going to the end of the page. The card goes when the mouse leaves the number,
# when a key like ⌘ is held, and while the mouse button is down.

const NOTE_KEY = :footnote   # the key of the popup with a footnote's card
const NOTE_WAIT = 0.25       # seconds that the mouse rests on a number before its card shows
const NOTE_CARD_W = 380px    # how wide the card is

"""
The footnote number under the mouse at `pos`, in a line that points to the
footnote: the footnote's name, and where the number is in the page's text, or
nothing. The number at the start of the footnote's own line isn't one.
"""
note_at(e, pos) = begin
  (isempty(e.layout) || e.buf.view != :markdown) && return nothing
  line, _ = locate(e, pos)
  it = item(e, line)
  f = it.content
  (f isa Flow && it.first == it.last) || return nothing
  x, y = pos[1] - e.origin[1], pos[2] - e.origin[2] - it.top
  for (k, vl) in enumerate(f.lines)
    top = line_top(f, k)
    top <= y < top + vl.high || continue
    for s in vl.segs
      (startswith(s.link, '^') && s.x - 2px <= x < s.x + s.w + 2px) || continue
      name = String(s.link[2:end])
      m = match(NOTE, e.buf.lines[it.first])
      m !== nothing && m[1] == name && return nothing
      return (line=it.first, name=name, x=s.x, top=it.top + top, w=s.w, high=vl.high)
    end
  end
  nothing
end

"""
The card of the footnote `name` of the page of `e`: its number, over its text
as the page reads, a little smaller than the page's own text. It's nothing
when the page has no line that holds the footnote.
"""
note_card(e, name) = begin
  b = e.buf
  i = findfirst(l -> (m = match(NOTE, l); m !== nothing && m[1] == name), b.lines)
  i === nothing && return nothing
  line = b.lines[i]
  text = String(SubString(line, ncodeunits(match(NOTE, line).match) + 1))
  isempty(strip(text)) && return nothing
  wide = NOTE_CARD_W - 2 * 6px - 2 * 14px   # the card has 6px of room on each side, and the text 14px inside that
  zoom = e.zoom
  e.zoom = zoom * PAGE_ZOOM
  # -1 says that the line isn't one of the document's, so its inline code isn't run
  f = try laid(e, text, classify([text])[1], false, -1, wide) finally e.zoom = zoom end
  Column(fixed(NOTE_CARD_W), Alignment.Start, padding(6px), radius(8px), background(colours.block),
         border(1px, :solid, colours.line), lifted, child_gap=4px, name="Footnote",
    Row(width(grow=grow), height(22px), padding(8px, 0px), child_gap=6px, Alignment.Center,
      Icon("superscript", size=12px, color=colours.dim), label("Footnote $(note_mark(e, name))", 12px, color=colours.dim)),
    Box(width(grow=grow), height(tall(f) + 2TEXT_PAD), padding(14px, 0px), radius(5px), background(colours.bg),
      Column(width(grow=grow), Alignment.Start, spacer(TEXT_PAD), describe(e, Item(0, 0, 0px, tall(f), f), f))))
end

"The footnote whose number the mouse is on, which the window keeps so that its card shows once the mouse has rested there: see `note_peek!`"
@def mutable struct NotePeek
  on::Union{Nothing,NamedTuple{(:at, :since, :shown)}} = nothing   # the footnote, since when, and whether its card shows
end

"True while the mouse is on the number of a footnote of the page of `e`"
note_peeked(e) = state_of(e, NotePeek).on !== nothing

"""
In each frame: show the card of the footnote whose number the mouse has
rested on, and take it away when the mouse leaves the number.
"""
note_peek!(e) = begin
  w = window_of(e)
  w === nothing && return nothing
  over = e.popup == :none && unmodified(w) && !(Keys.mouse_left in w.keys) && ishovered(node!(Document, e, :document))
  found = over ? note_at(e, w.mouse) : nothing
  kept = state_of(e, NotePeek)
  was = kept.on
  if found === nothing
    was === nothing && return nothing
    kept.on = nothing
    close_popup!(w, NOTE_KEY)
    return nothing
  end
  if was === nothing || was.at != found
    was === nothing || close_popup!(w, NOTE_KEY)
    kept.on = (at=found, since=time(), shown=false)
    redraw_in!(e, NOTE_WAIT)
    return nothing
  end
  was.shown && return nothing
  wait = NOTE_WAIT - (time() - was.since)
  wait > 0 && return (redraw_in!(e, wait); nothing)
  kept.on = (at=found, since=was.since, shown=true)
  card = note_card(e, found.name)
  card === nothing && return nothing
  popup!(w, card, anchor=(e.origin[1] + found.x, e.origin[2] + found.top, max(found.w, 4px), found.high),
         placement=:below, gap=4px, key=NOTE_KEY, input=false)
  nothing
end

# --- find in the page ----------------------------------------------------------------------
#
# In a file with no search under a › of the path in the top bar, like a file of
# code, ⌘F opens a bar at the top right of the page. (In a page of Markdown, ⌘F
# shows that search: see `find!`.) Each place in the document that has the
# bar's text gets a mark, and the selection goes to the first one after the
# caret. Return and ⌘G go to the next place, ⇧Return and ⌘⇧G go to the one
# before, and esc closes the bar. Capitals don't matter.

"The bar that finds text in the page"
@def mutable struct FindBar <: SemanticUI end
"A button of that bar: `:previous`, `:next` or `:close`"
@def mutable struct FindButton <: SemanticUI
  action::Symbol = :next
end

"What a window keeps of the bar that finds text in the page, between frames"
@def mutable struct FindState
  open::Bool = false                           # the bar shows
  input::Union{Nothing,TextInput} = nothing    # the bar's field, once it has been asked for
  text::String = ""                            # the field's text when the page last went to a place that has it
  found::Union{Nothing,Tuple{Tuple{String,Int,String},Vector{NTuple{3,Int}}}} = nothing   # the page, its version and the text that the places were last found for, and the places
end

finding(e) = state_of(e, FindState).open
find_input(e) = begin
  s = state_of(e, FindState)
  s.input === nothing && (s.input = own!(e, TextInput(placeholder="Find in the page", font_family=SANS, font_size=14px,
                                                     look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))))
  s.input::TextInput
end

"Open the bar and give it the keyboard. What's selected goes into it, if that's part of one line."
open_find!(e) = begin
  b = e.buf
  i = find_input(e)
  lo, hi = selection(b)
  selecting(b) && lo[1] == hi[1] && (i.text = rest(head(b.lines[lo[1]], hi[2]), lo[2]))
  i.anchor, i.cursor = 0, length(i.text)
  s = state_of(e, FindState)
  s.open = true
  s.text = i.text
  focus(i)
  nothing
end

close_find!(e) = (state_of(e, FindState).open = false; focus(e); touch!(e); nothing)

"Each place in the document that has the bar's text: its line, and the columns where it starts and ends"
found(e) = begin
  b = e.buf
  q = finding(e) ? lowercase(find_input(e).text) : ""
  key = (b.path, b.version, q)
  kept = state_of(e, FindState).found
  kept !== nothing && kept[1] == key && return kept[2]
  out = NTuple{3,Int}[]
  n = length(q)
  if n > 0
    for (i, line) in enumerate(b.lines)
      low = lowercase(line)
      for at in findall(q, low)
        lo = length(low, 1, first(at)) - 1
        push!(out, (i, lo, lo + n))
      end
    end
  end
  state_of(e, FindState).found = (key, out)
  out
end

"Select the place at `k` of the places found, and scroll to it"
go_found!(e, k) = begin
  i, lo, hi = found(e)[k]
  b = e.buf
  b.anchor, b.caret = (i, lo), (i, hi)
  touch!(e)
end

"Go to the next place after the selection, or with `by` of -1 to the one before it. After the last place comes the first."
find_step!(e, by=1) = begin
  places = found(e)
  isempty(places) && return
  lo, hi = selection(e.buf)
  k = by > 0 ? findfirst(p -> (p[1], p[2]) >= hi, places) : findlast(p -> (p[1], p[3]) <= lo, places)
  go_found!(e, something(k, by > 0 ? 1 : length(places)))
end

"When the bar's text changes, go to the first place at or after the start of the selection"
find_tick!(e) = begin
  finding(e) || return
  text = find_input(e).text
  s = state_of(e, FindState)
  text == s.text && return
  s.text = text
  places = found(e)
  isempty(places) && return
  lo, _ = selection(e.buf)
  go_found!(e, something(findfirst(p -> (p[1], p[2]) >= lo, places), 1))
end

"What a key does while the bar has the keyboard. `command` is the command that the key bindings give the key, or nothing."
find_key!(e, w, K, command) = begin
  if K == Keys.escape && unmodified(w)
    close_find!(e)
  elseif K == Keys.enter && (unmodified(w) || only_held(w, Keys.shft))
    # ⇧Return goes back to the place found before
    find_step!(e, only_held(w, Keys.shft) ? -1 : 1)
  elseif command == :find
    i = find_input(e)
    i.anchor, i.cursor = 0, length(i.text)
  elseif command in (:find_next, :find_last) || (command !== nothing && command_kind(command) == :window)
    run!(e, w, command)
  end
  nothing
end

const FIND_W = 330px

describe(f::FindBar) = begin
  e = editor(f)
  i = find_input(e)
  i.color, i.placeholder_color = colours.ink, colours.faint
  places = found(e)
  lo, hi = selection(e.buf)
  k = lo[1] == hi[1] ? something(findfirst(==((lo[1], lo[2], hi[2])), places), 0) : 0
  count = isempty(i.text) ? "" : isempty(places) ? "Not found" : k == 0 ? string(length(places)) : "$k of $(length(places))"
  Row(fixed(FIND_W), height(38px), padding(0px, 6px, 0px, 12px), child_gap=6px, radius(9px), background(colours.float),
      border(1px, :solid, colours.line), lifted,
    Icon("search", size=13px, color=colours.dim), Box(width(2px)), i,
    label(count, 12px, color=colours.dim), Box(width(2px)),
    [node!(() -> FindButton(action=a), e, (:find, a)) for a in (:previous, :next, :close)]...)
end

cursor(::FindBar) = :ibeam
onkey(f::FindBar, ::KeyPress{Keys.mouse_left}) = (focus(find_input(editor(f))); handled)

describe(b::FindButton) = Box(width(24px), height(24px), radius(5px), background(ishovered(b) ? colours.hover : clear),
  Icon(b.action == :previous ? "chevron-up" : b.action == :next ? "chevron-down" : "x-lg", size=11px, color=colours.dim))

cursor(::FindButton) = :hand
onkey(b::FindButton, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(b)
  b.action == :close ? close_find!(e) : find_step!(e, b.action == :previous ? -1 : 1)
  handled
end

"The find bar, placed at the top right of the window, under the top bar. Nothing when it's closed."
findbar(e) = finding(e) ? (Row(width(grow=grow), height(grow=grow), Alignment.Start, justify=Alignment.End,
                               padding(bar_bottom(e) + 6px, 22px, 0px, 0px), node!(FindBar, e, :findbar)),) : ()

# --- spelling --------------------------------------------------------------------------------
#
# macOS checks the spelling of the page's text. A word that its dictionary
# doesn't have gets a line of red dots under it. A right-click on the word
# offers the words it may have been meant to be, and Learn Spelling, which
# teaches the dictionary the word. Code isn't checked, and nor is the word that
# the caret is in, which may not be finished. The settings page turns it off.

const CHECKED = (Kind.paragraph, Kind.heading, Kind.bullet, Kind.ordered, Kind.todo, Kind.blockquote)

"""
True when `text` is a word that a dictionary could have. The name of a file,
like notes.md, a name from code, like page_width, and a web address aren't,
and nor is the app's own name.
"""
spellable(text::AbstractString) = text != "Ladder" && !any(c -> isdigit(c) || c in "._/@:\\", text)

"Every word of line `i` that's spelt wrong: the columns where it starts and ends"
misspellings(e, i) = begin
  b = e.buf
  text, line = b.lines[i], kinds(b)[i]
  # A page that's never changed is somebody's words as they wrote them, so its spelling isn't marked
  # ... and a slide is for someone to read, so nor is its spelling
  (e.spelling && !b.fixed && slideshow(e) === nothing && line.kind in CHECKED) || return Tuple{Int,Int}[]
  get!(e.flows, (:spelling, text, line.prefix)) do
    out = Tuple{Int,Int}[]
    occursin(PICTURE_LINE, text) && return out
    for s in spans(rest(text, line.prefix), line.prefix)
      # The address of a link and the name of a footnote are markup, so only the words that show are checked. A comment doesn't show.
      (s.markup || s.comment || s.code || s.math || startswith(s.link, '^')) && continue
      for (lo, hi) in misspelt(s.text)
        spellable(rest(head(s.text, hi), lo)) && push!(out, (s.col + lo, s.col + hi))
      end
    end
    out
  end
end

"The wrong word at `at`, as its line and its columns, or nothing"
misspelling_at(e, at::Pos) = begin
  k = findfirst(((lo, hi),) -> lo <= at[2] <= hi, misspellings(e, at[1]))
  k === nothing ? nothing : (at[1], misspellings(e, at[1])[k]...)
end

"Change the spelling of every line again, after the dictionary learns a word"
respell!(e) = (filter!(kv -> !(kv.first isa Tuple && first(kv.first) === :spelling), e.flows); e)

"Turn the spelling check on or off"
spelling!(e, on::Bool) = (e.spelling = on; save_settings!(e); rerun!(e, :spelling); e)
add_command!(spelling!, title="Turn the spelling check on or off")

"""
Where columns `from` to `to` of `f` are on the screen. A line of the document
can wrap, so there's one for each line of the screen that has some of them: its
left, its right, its top and its height, from the top left of `f`.
"""
stretches(f::Flow, from, to) = begin
  out = NTuple{4,px}[]
  for (k, vl) in enumerate(f.lines)
    (from < vl.to && to > vl.from) || continue
    x1, x2 = xcol(vl, max(from, vl.from)), xcol(vl, min(to, vl.to))
    x2 > x1 && push!(out, (x1, x2, line_top(f, k), vl.high))
  end
  out
end

const FOUND = RGBA(1.0, 0.78, 0.16, 0.45)   # the colour of the mark over a place that the find bar found

"Draw a mark over each place that the find bar found, and a line of dots under each word that's spelt wrong"
annotate(ctx, e, ui) = begin
  b = e.buf
  places = found(e)
  (isempty(places) && !e.spelling) && return
  lo, hi = selection(b)
  for it in e.layout[e.shown]
    f = it.content
    f isa Flow || continue
    i, top = it.first, ui.top + it.top
    k = searchsortedfirst(places, (i, 0, 0))
    while k <= length(places) && places[k][1] == i
      _, from, to = places[k]
      k += 1
      # The place that's selected has the selection's colour already
      (lo, hi) == ((i, from), (i, to)) && continue
      for (x1, x2, y, high) in stretches(f, from, to)
        tall = f.size * 1.35
        rounded_rectangle(ctx, ui.left + x1, top + y + (high - tall) / 2, x2 - x1, tall, 3px, background=FOUND)
      end
    end
    for (from, to) in misspellings(e, i)
      # A word that's still being typed isn't wrong yet
      !b.reading && b.caret[1] == i && from <= b.caret[2] <= to && continue
      for (x1, x2, y, high) in stretches(f, from, to)
        under = top + y + high / 2 + f.size * 0.46
        for x in num(x1):3.0:num(x2)-1.5
          rectangle(ctx, ui.left + px(x), under, 1.5px, 1.5px, background=SPELL_RED, border=0px)
        end
      end
    end
  end
end

# --- comments in the margin --------------------------------------------------------------
#
# A comment is written as CriticMarkup writes it: {>>a comment<<}. The words
# that it's about go before it, between {== and ==}, and have a highlighter's
# colour behind them: {==these words==}{>>a comment<<}. A comment with no words
# before it is about the place where it is. Rich text hides the comment's
# markup and its words, and shows each comment as a card in the margin at the
# right of the text, level with the words that it's about. A comment that would
# go over the card above it goes under that card. When the window is too narrow
# for the cards beside the text, the text gets narrower.
#
# The mouse over a card marks the words that it's about. A click on a card
# puts the caret in its comment and takes that part of the page down a level,
# so the comment shows as it's written, to change. ⌘E takes it up again. Add
# Comment (⌘⌥M) puts a comment on the words that are selected.

const COMMENT_W = 230px      # how wide a comment's card is, before zooming
const COMMENT_GAP = 36px     # the room between the text and the cards
const COMMENT_PAD = 10px     # the room round a card's words
const COMMENT_SPACE = 8px    # the least room between two cards
const COMMENT_LEADING = 1.4  # how tall a line of a card is, for the size of its words

"A comment of the page: its line, the column where its words start, its words, the columns of the words that it's about, and how far down the page they are"
struct PageComment
  line::Int
  col::Int
  text::String
  lo::Int
  hi::Int
  at::px
end

"What a window keeps of whether its page has a comment for the margin: the page, its version, and whether it had one then"
@def mutable struct CommentsSeen
  seen::Union{Nothing,Tuple{String,Int,Bool}} = nothing
end

"True when the page shows comments in the margin: a page of Markdown, as rich text, with a comment in it"
has_comments(e) = begin
  b = e.buf
  (b.view == :markdown && !numbered(b) && wraps(e) && slideshow(e) === nothing && lowered(e) === nothing && hosted(e) === nothing) || return false
  seen = state_of(e, CommentsSeen).seen
  seen !== nothing && seen[1] == b.path && seen[2] == b.version && return seen[3]
  ks = kinds(b)
  # {>> in code, or in a table, is no comment that the margin shows
  yes = any(i -> occursin("{>>", b.lines[i]) && !(ks[i].kind in (Kind.code, Kind.fence, Kind.table)) &&
                 !isempty(comments_in(spans(rest(b.lines[i], ks[i].prefix), ks[i].prefix))), eachindex(b.lines))
  state_of(e, CommentsSeen).seen = (b.path, b.version, yes)
  yes
end

"Where the words of each {>>comment<<} are in `ss`, the spans of a line"
comments_in(ss) = [k for (k, s) in enumerate(ss) if s.comment && k > 1 && ss[k-1].markup && ss[k-1].text == "{>>"]

comment_w(e) = COMMENT_W * e.zoom

"How much room the page's comments take at the right of its text: none when it has none"
comment_room(e) = has_comments(e) ? comment_w(e) + COMMENT_GAP * e.zoom : 0px

"""
The room before a page's text that balances the comments at its right, so
that the text stays in the middle of `space` while the window is wide enough.
"""
comment_balance(e, space) = (extra = comment_room(e); clamp(space - 2PAGE_X - e.width - extra, 0px, extra))

"The page's text, with its comments in a column at its right"
with_comments(e, page) = begin
  comment_room(e) == 0px && return page
  before = comment_balance(e, page_span(e)[2])
  Row(Alignment.Start, Box(fixed(before)), page, Box(fixed(COMMENT_GAP * e.zoom)), node!(Comments, e, :comments))
end

"The comments of the page that rich text shows, from the top, with where each goes in the margin"
page_comments(e) = begin
  b = e.buf
  out = PageComment[]
  has_comments(e) || return out
  ks = kinds(b)
  for it in e.layout
    f = it.content
    (f isa Flow && !f.raw && it.first == it.last) || continue
    text = b.lines[it.first]
    (occursin("{>>", text) && !(ks[it.first].kind in (Kind.code, Kind.fence, Kind.table))) || continue
    start = ks[it.first].prefix
    ss = spans(rest(text, start), start)
    open = raw_part(b, it.first)   # a comment that the caret is in shows in the text, as it's written
    for k in comments_in(ss)
      s = ss[k]
      markup_shows(open, s.col, s.col + length(s.text)) && continue
      # The words that it's about are between the {== and ==} just before it
      lo = hi = ss[k-1].col
      if k > 2 && ss[k-2].markup && ss[k-2].text == "==}"
        open = findlast(t -> t.markup && t.text == "{==", view(ss, 1:k-3))
        open === nothing || ((lo, hi) = (ss[open].col + 3, ss[k-2].col))
      end
      row, _ = spot(f, lo)
      push!(out, PageComment(it.first, s.col, strip(s.text), lo, hi, it.top + line_top(f, row)))
    end
  end
  out
end

comment_face(e) = Face(SANS, "", body(e).size * 0.78, colours.ink, false)

"The column of the page's comments, each card level with the words that it's about"
@def mutable struct Comments <: SemanticUI end

"One comment of the page, as a card in the margin"
@def mutable struct CommentCard <: SemanticUI
  line::Int = 0
  col::Int = 0                   # the column where the comment's words start
  lo::Int = 0                    # the columns of the words that it's about
  hi::Int = 0
  lines::Vector{String} = String[]
end

describe(n::Comments) = begin
  e = editor(n)
  face = comment_face(e)
  high = face.size * COMMENT_LEADING
  parts = Any[]
  bottom = 0px   # where the last card ends
  for (k, note) in enumerate(page_comments(e))
    lines = filter(!isempty, wrapped(face, note.text, num(comment_w(e) - 2COMMENT_PAD)))
    # The card's first line is level with the words, and a card never goes over the one above it
    at = max(note.at - COMMENT_PAD + (body(e).size * 1.35 - high) / 2, k == 1 ? 0px : bottom + COMMENT_SPACE * e.zoom)
    push!(parts, spacer(at - bottom))
    card = node!(CommentCard, e, (:comment_card, k))
    card.line, card.col, card.lo, card.hi, card.lines = note.line, note.col, note.lo, note.hi, lines
    push!(parts, card)
    bottom = at + 2COMMENT_PAD + high * max(1, length(lines))
  end
  Column(fixed(comment_w(e)), Alignment.Start, parts...)
end

describe(c::CommentCard) = begin
  e = editor(c)
  face = comment_face(e)
  high = face.size * COMMENT_LEADING
  words = isempty(c.lines) ? [Row(height(high), Alignment.Center, spared("An empty comment", Face(face, color=colours.faint))...)] :
                             [Row(height(high), Alignment.Center, spared(line, face)...) for line in c.lines]
  Column(fixed(comment_w(e)), Alignment.Start, padding(COMMENT_PAD), radius(6px), name="Comment",
         background(ishovered(c) ? colours.active : colours.block), words...)
end

cursor(::CommentCard) = :hand

"A click on a card puts the caret at the start of its comment, and shows the comment as it's written"
onkey(c::CommentCard, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(c)
  b = e.buf
  1 <= c.line <= length(b.lines) || return handled
  b.caret = b.anchor = (c.line, c.col)
  e.plain || level!(e)
  focus(e)
  touch!(e)
  handled
end

"While the mouse is over a comment's card, mark the words that it's about"
mark_commented(ctx, e, ui) = begin
  has_comments(e) || return
  for k in eachindex(page_comments(e))
    card = get(e.nodes, (:comment_card, k), nothing)
    (card isa CommentCard && ishovered(card)) || continue
    it = item(e, card.line)
    (it.first == card.line && it.content isa Flow) || continue
    f = it.content
    for (x1, x2, y, high) in stretches(f, card.lo, max(card.hi, card.lo + 1))
      tall = f.size * 1.35
      rounded_rectangle(ctx, ui.left + x1 - 2px, ui.top + it.top + y + (high - tall) / 2, x2 - x1 + 4px, tall, 3px, background=highlighter())
    end
  end
end

"""
Put a comment on the words that are selected, in the line where the selection
starts, and put the caret in it to type. With nothing selected, the comment is
about the place where the caret is. The caret's part of the page goes down a
level, so the comment shows as it's written.
"""
add_comment!(e) = begin
  b = e.buf
  (b.view == :markdown && !readonly(b)) || return e
  lo, hi = selection(b)
  hi[1] == lo[1] || (hi = (lo[1], length(b.lines[lo[1]])))
  words = excerpt(b, lo, hi)
  new = isempty(words) ? "{>><<}" : "{==" * words * "==}{>><<}"
  edit!(b, lo, hi, new)
  b.caret = b.anchor = (lo[1], lo[2] + length(new) - 3)
  e.plain || level!(e)
  touch!(e)
  e
end

"""
The word that's selected, or nothing. It's the text of a selection that has
only the characters of a word, all in one line.
"""
selected_word(b::Buffer) = begin
  lo, hi = selection(b)
  (lo != hi && lo[1] == hi[1]) || return nothing
  text = excerpt(b, lo, hi)
  all(isword, text) ? text : nothing
end

"""
The other places on screen that have the selected word. Each one is its line
and its columns, then the text that it's in as it's laid out, and where the top
left of that is from the top left of the page's text. A line of a table has
them in each of its cells. The word is found only where it's a word by itself,
as ⌘D finds it, so these are the places that ⌘D would select. A place that's
selected already isn't one of them.
"""
same_word(e) = begin
  b = e.buf
  out = Tuple{Int,Int,Int,Flow,px,px}[]
  word = selected_word(b)
  word === nothing && return out
  taken = [(b.anchor, b.caret); others(b)]
  free(i, from, to) = !any(t -> clash(((i, from), (i, to)), t), taken)
  for it in e.layout[e.shown]
    g = it.content
    if g isa Flow
      i = it.first
      for (from, to) in places(b.lines[i], word, true)
        free(i, from, to) && push!(out, (i, from, to, g, 0px, it.top))
      end
    elseif g isa Grid
      for (r, i) in enumerate(g.rows), (from, to) in places(b.lines[i], word, true)
        c = findfirst(cell -> cell.lo <= from && to <= cell.limit, g.cells[r])
        (c === nothing || !free(i, from, to)) && continue
        x, y = cell_origin(g, r, c)
        push!(out, (i, from, to, g.flows[r][c], x, it.top + y))
      end
    end
  end
  out
end

"Draw a line round each of the other places that have the word that's selected. The page's text is at `ui`."
outline_same_word(ctx, e, ui) = begin
  line = tint(colours.select, 0.8)
  for (_, from, to, f, x, y) in same_word(e), (x1, x2, top, high) in stretches(f, from, to)
    tall = num(f.size) * 1.35
    round_box(ctx, num(ui.left + x + x1) - 1.5, num(ui.top + y + top) + (num(high) - tall) / 2, num(x2 - x1) + 3, tall, 3.0, line=line)
  end
end

"What the item at `k` of the spelling part of the page's menu does. `fixes` are the words it offers for the wrong word at `wrong`."
spell_act!(e, wrong, fixes, k) = begin
  i, lo, hi = wrong
  b = e.buf
  if k <= length(fixes)
    edit!(b, (i, lo), (i, hi), fixes[k])
    b.caret = b.anchor = (i, lo + length(fixes[k]))
    touch!(e)
  elseif k == max(1, length(fixes)) + 1
    learn!(rest(head(b.lines[i], hi), lo))
    respell!(e)
  end
  nothing
end

# --- the page as HTML ------------------------------------------------------------------------
#
# ⌘⇧E, and Export as HTML in the page's menu, write the document as a page of
# HTML that a browser can show. A sheet goes in as a table of its names and
# what they come to. A diagram goes in as a picture in SVG, drawn as the editor
# draws it. A live block goes in as its code, and inline code goes in as the
# text it made, when it made text.

"The sheet between lines `s` and `t`, as an HTML table, or nothing while the sheet shows as code"
sheet_html(e, s, t) = begin
  k = findfirst(it -> it.first == s && it.content isa Sheet, e.layout)
  k === nothing && return nothing
  sheet, b = e.layout[k].content, e.buf
  rows = map(eachindex(sheet.rows)) do r
    line, cells = b.lines[sheet.rows[r]], sheet.cells[r]
    text(c) = escape(rest(head(line, c.hi), c.lo))
    name = length(cells) > 1 ? text(cells[1]) : ""
    "<tr><td>$name</td><td><code>$(isempty(cells) ? "" : text(cells[end]))</code></td><td>$(escape(sheet.results[r].text))</td></tr>"
  end
  "<table>\n" * join(rows, "\n") * "\n</table>"
end

# Skia's SVG canvas draws text as shapes with this flag, so it needs no font where it's shown
const SVG_TEXT_AS_SHAPES = UInt32(1)

"""
The diagram that `code` describes, as a picture in SVG, or nothing if the code
can't be drawn as a diagram. It has the Sepia colours, which the page of HTML
has too, and it's as big as it is in the editor at its usual size. Its text is
drawn as shapes, so it looks the same on a computer that hasn't got the font.
"""
diagram_svg(code::AbstractString) = begin
  isdiagram(code) || return nothing
  was = deepcopy(colours)
  use!(SEPIA)
  stream = Skia.sk_dynamic_memory_wstream_new()
  try
    m = Mermaid(code)
    geo = with_theme(component_theme()) do
      convert(GeometricUI, m)
    end
    made = m.made === nothing ? nothing : m.made[2]
    (made === nothing || made isa Exception) && return nothing
    w, h = ceil(Int, made.w), ceil(Int, made.h)
    (w > 0 && h > 0) || return nothing
    size = (px(w), px(h))
    scene = describe(Column(fixed(px(w)), Alignment.Start, geo), size)
    bounds = Ref(Skia.sk_rect_t(0f0, 0f0, Float32(w), Float32(h)))
    canvas = GC.@preserve bounds Skia.sk_surface_make_canvas_svg(Base.unsafe_convert(Ptr{Skia.sk_rect_t}, bounds),
                                                                 Skia.sk_dynamic_memory_wstream_as_wstream(stream), SVG_TEXT_AS_SHAPES)
    draw(canvas, size, scene)
    # Skia writes the end of the SVG when the canvas is deleted. Its C functions can't delete
    # a canvas, so the canvas's C++ destructor does it.
    ccall((:_ZN8SkCanvasD0Ev, Skia.libskia), Cvoid, (Ptr{Cvoid},), canvas)
    bytes = Vector{UInt8}(undef, Skia.sk_dynamic_memory_wstream_bytes_written(stream))
    Skia.sk_dynamic_memory_wstream_read(stream, bytes, Csize_t(0), Csize_t(length(bytes)))
    # In a page of HTML the SVG needs no line that says it's XML. A viewBox lets a narrow window show it smaller.
    svg = replace(String(bytes), r"^<\?xml[^>]*>\s*" => "")
    replace(svg, "<svg " => "<svg viewBox=\"0 0 $w $h\" role=\"img\" ", count=1)
  finally
    Skia.sk_dynamic_memory_wstream_delete(stream)
    use!(was)
  end
end

"The `mermaid` code block from line `s` to line `t` as HTML: its diagram, or nothing to show its code, as the editor does when the block isn't closed or can't be drawn"
diagram_html(e, s, t) = begin
  ks = kinds(e.buf)
  t > s && ks[t].kind == Kind.fence && ks[t].level == 1 || return nothing
  svg = diagram_svg(join(e.buf.lines[s+1:t-1], "\n"))
  svg === nothing ? nothing : "<div class=\"diagram\">\n$svg</div>"
end

"The document as a page of HTML"
page_html(e) = begin
  write_blocks!(e)   # a block that a file defines is in the page as what it holds now
  b = e.buf
  styled = Ref(false)   # whether the rules that give a card its look are in the page yet
  html(b.lines, title=title(b.path),
       block=(lang, s, t) -> haskey(BLOCKS, lang) ? block_html(e, lang, s, t) : nothing,
       value=code -> (made = get(e.nodes, (:inline, b.path, code, 1), nothing); made isa Tuple && !made[2] ? made[1] : nothing),
       file=text -> (made = table_html(e, text)) !== nothing ? made : card_html(e, text, styled),
       columns=html_columns(e))
end

"Ask where to save a file, with `name` to start with, in the document's folder. It gives the path, or nothing if you cancel."
save_panel(e, name) = with_pool() do
  panel = msg(cls("NSSavePanel"), "savePanel")
  msg(panel, "setNameFieldStringValue:", nsstring(name))
  msg(panel, "setDirectoryURL:", msg(cls("NSURL"), "fileURLWithPath:", nsstring(docdir(e))))
  # 1 is the panel's Save button
  ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), panel, sel("runModal")) == 1 || return nothing
  jstring(msg(msg(panel, "URL"), "path"))
end

"Write the document as a page of HTML, to the file that you choose"
export_html!(e, w) = begin
  e.buf.view == :markdown || return nothing   # only a Markdown file is a page
  # A window that isn't on the screen, like one a test makes, has no panel to ask with
  (Sys.isapple() && !isempty(w.glfw)) || return nothing
  path = save_panel(e, title(e.buf.path) * ".html")
  # The panel took the keyboard, so the window never heard the keys that opened it come up
  w.keys = Keys(0)
  path === nothing && return nothing
  try
    write(path, page_html(e))
  catch
  end
  nothing
end

"""
The file changed on the disk, and `moved` is the lines that changed. Keep the
line at the top of the window where it is, so the text you're reading doesn't
jump when an agent adds lines above it.
"""
stay!(e, moved) = begin
  y = e.scroll.offset
  i = findfirst(it -> it.top + it.tall > y, e.layout)
  i === nothing && return
  it = e.layout[i]
  hold!(e, clamp(follow(moved, it.first), 1, length(e.buf.lines)), it.top - y)
end

# --- the lines that just changed on the disk ------------------------------------------------
#
# When something else changes the file, like an agent, a bar shows for a few
# seconds in the margin beside each line that it changed or added, and fades.
# While the diff button shows the file's changes since the last commit, a
# button with an eye beside it shows the bars again, beside every line that
# was changed since you last sent the page. They stay until you click the
# button again, or hide the changes.

const FRESH = 4.0        # how many seconds a bar shows
const FRESH_FADE = 1.5   # how many of them it takes to fade

"What a window keeps of the lines that changed on the disk a moment ago: when they changed, the page, and the runs of lines"
@def mutable struct FreshLines
  at::Float64 = 0.0
  path::String = ""
  runs::Vector{UnitRange{Int}} = UnitRange{Int}[]
end

"Remember the lines that just changed. `moved` is what `refresh!` gave."
fresh!(e, moved) = begin
  s = state_of(e, FreshLines)
  s.at, s.path, s.runs = time(), e.buf.path, UnitRange{Int}[c[2] for c in moved if !isempty(c[2])]
  (s.at, s.path, s.runs)
end

"The runs of lines of the page that changed on the disk in the last few seconds"
fresh(e) = begin
  s = state_of(e, FreshLines)
  (s.path == e.buf.path && time() - s.at < FRESH) && return s.runs
  s.at, s.path, s.runs = 0.0, "", UnitRange{Int}[]
  s.runs
end

"Draw a bar in the margin beside each item on screen that shows a line that just changed. The text starts at `left`, and its first line is at `top`."
draw_fresh(ctx, e, left, top) = begin
  slideshow(e) === nothing || return   # a slide shows the new text, and no bar beside it
  # The button in the top bar keeps the bars of all the agent's changes on the page. They don't fade.
  kept = marking(e) ? theirs(e) : UnitRange{Int}[]
  runs = isempty(kept) ? fresh(e) : kept
  isempty(runs) && return
  strength = isempty(kept) ? clamp((FRESH - (time() - state_of(e, FreshLines).at)) / FRESH_FADE, 0, 1) : 1.0
  ink = RGBA(colours.accent, strength * 0.7)
  for it in e.layout[e.shown]
    any(r -> first(r) <= it.last && last(r) >= it.first, runs) || continue
    rectangle(ctx, left - 16px, top + it.top, 3px, it.tall, background=ink, border=0px)
  end
end
