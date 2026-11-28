# When a line last changed: a click on the number of a line shows the commit that last changed it
#
# Its commands are in main.jl.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" WrapMode window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in! popup! close_popup!
@use "./markdown" Kind
@use "./sheet" number_at
@use "./git" => Git
@use "github.com/jkroso/UI.jl/Interface/draw" Bubble
@use Colors: RGBA
@use Dates: Dates
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
@use "./julia_levels" exports...
@use "./page_extras" exports...
@use "./day_view" exports...

export LineAsked, day_words, history_words, line_history!, line_tick!

# --- when a line last changed ---------------------------------------------------------------
#
# A click on the number of a line, in a file that git keeps, shows the commit
# that last changed the line: its day, who made it, its first line, and the
# lines that the file had there before. git is asked about the text as the
# window has it, so a line that you changed and didn't commit says so. The
# words stay until the next click, key or scroll. git answers in a later
# frame, so the window never waits for it.

"The line whose number the point `pos` of the window is on, or nothing: the page shows numbers, and the point is beside the text, on them"
number_at(e, pos) = begin
  (numbers(e) && !isempty(e.layout)) || return nothing
  x, y = pos
  left = e.origin[1] + sideways(e)   # the numbers stay at the left of a page that's scrolled sideways
  (left - gutter(e) <= x < left - NUMBER_GAP / 2 && y >= e.origin[2]) || return nothing
  locate(e, pos)[1]
end

"What's asked of git about a line, and what it said: the line, the process, the caret, version and scroll that the words stay for, and the commit with the lines before it"
@def mutable struct LineAsked
  line::Int = 0
  root::String = ""
  process::Any = nothing
  out::Any = nothing
  stays::Any = nothing
  found::Any = nothing     # a Git.Blamed once git has answered, or false when it has nothing to say
  before::Vector{String} = String[]
end

"Ask git which commit last changed line `i` of the page. True when git keeps the page, so there's something to ask."
line_history!(e, i::Int) = begin
  b = e.buf
  h = isempty(b.path) ? nothing : page_history(page_key(b.path))
  h === nothing && return false
  asked = try
    process, out = Git.blame(h.root, h.rel, i, join(b.lines, "\n"))
    LineAsked(line=i, root=h.root, process=process, out=out)
  catch
    return false
  end
  e.nodes[:line_asked] = asked
  redraw_in!(e, 0)
  true
end

"The day of a time in seconds, like 14 Nov 2026"
day_words(at::Real) = Dates.format(Dates.unix2datetime(at) + (Dates.now() - Dates.now(Dates.UTC)), "d u yyyy")

"What the window says of the commit that last changed a line. The line as it was has the colours of code in `lang`, like julia, and `open` is the quote of a docstring that's open at its start, or '\\0'."
history_words(a::LineAsked, lang="", open='\0') = begin
  c = a.found
  c === false && return Box(padding(10px, 7px), label("git has nothing on this line.", 12px, color=TIP_INK))
  isempty(c.hash) && return Box(padding(10px, 7px), label("Changed since the last commit.", 12px, color=TIP_INK))
  said(text; family=SANS, color=TIP_INK) = Text(length(text) > 90 ? first(text, 89) * "…" : text, size=12px, family=family, color=color, wrap=WrapMode.none)
  rows = Any[said("$(day_words(c.at))  ·  $(c.who)  ·  $(first(c.hash, 7))", color=RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)), said(c.words)]
  if isempty(a.before)
    push!(rows, said("This commit added the line.", color=RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)))
  else
    push!(rows, said("Before:", color=RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)))
    append!(rows, tip_code([length(l) > 90 ? first(l, 89) * "…" : l for l in first(a.before, 6)], lang; open))
    length(a.before) > 6 && push!(rows, said("and $(length(a.before) - 6) more", color=RGBA(TIP_INK.r, TIP_INK.g, TIP_INK.b, 0.65)))
  end
  Box(padding(10px, 8px), Column(Alignment.Start, child_gap=3px, [Box(r) for r in rows]...))
end

"In each frame: read what git said about a line, show it beside the line's number, and take it away after the next click, key or scroll"
line_tick!(e) = begin
  a = get(e.nodes, :line_asked, nothing)
  a isa LineAsked || return nothing
  w, b = window_of(e), e.buf
  if a.found === nothing
    yield()   # git's end is noticed by a task, which gets its turn here
    process_exited(a.process) || return (redraw_in!(e, 0.05); nothing)
    found = Git.read_blame(String(take!(a.out)))
    a.found = something(found, false)
    found === nothing || isempty(found.hash) || (a.before = try Git.before(a.root, found) catch; String[] end)
    a.stays = (b.path, b.version, b.caret, e.scroll.offset)
  end
  if w === nothing || a.stays != (b.path, b.version, b.caret, e.scroll.offset) || !(1 <= a.line <= length(e.layout))
    w === nothing || close_popup!(w, :line_asked)
    delete!(e.nodes, :line_asked)
    return nothing
  end
  it = item(e, a.line)
  spot = (e.origin[1] + sideways(e) - gutter(e), e.origin[2] + it.top, gutter(e) - NUMBER_GAP / 2, it.content isa Flow ? it.content.lines[1].high : it.tall)
  # The words look as a tooltip does. They stay while the mouse moves, which a tooltip doesn't.
  l = kinds(b)[a.line]
  lang = l.kind == Kind.code ? shared_lang(l.lang) : ""
  # The line as it was is taken to start inside a docstring when the line as it is does
  popup!(w, Bubble(content=history_words(a, lang, string_opens(b)[a.line]), target=spot), anchor=spot, placement=:bottom, gap=4px, key=:line_asked, input=false)
  nothing
end



# ⌘⇧A starts a session at once, in the folder of the file that shows
