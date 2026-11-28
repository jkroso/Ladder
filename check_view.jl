# Checks of the page's code, a check that's changed where it is, and checks in a file of Julia code
#
# A code block in the language `check` holds a line of Julia for each thing
# that must be true, like `area(room) == 12` or `length(walls) > 3`. A blank
# line and a comment are no check.
#
# The block has three levels. At the highest, it's a row of dots: a green dot
# for each check that passes, and a red one for each that doesn't. The mouse
# over a dot shows its line, and what it found. A click on the dots opens the
# block, to the level under that: each line with a tick or a cross. A line that
# compares two values and fails says what each of them was, and a line that
# stops says why. A click on the top of the open block shows the dots again. At
# the lowest level, the block shows as its lines of Julia, with the caret in
# them, as ⌥-click shows it. With the caret on the block as a whole or in its
# lines, the ladder in the top bar goes up and down these levels, and ⌘E too.
#
# Each check of the open block can be changed where it is: a click on its line
# puts a field there, which shows the line as Julia code. Return or a click
# somewhere else writes it into the block, and the check runs again. A line
# that's left empty takes the check away, and Esc leaves it as it was. The
# last line of the list adds a check, and stays open for another one. The
# lines of the block are Julia too, with the colours and the names that a
# `julia` block has.
#
# The lines run in the module of the page's code, with the names that the
# page's `julia` blocks made. They run again when a line of the block changes,
# and each time the page's code runs, as it does with ⌘Return. A click that
# opens the block, and the button at the top of the open block, run them again
# too.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe window_of focus handled version
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" => TextInputs
@use "./html" escape
@use "./markdown" Kind words
@use "./sheet" parts shown
@use "./spreadsheet" moved
@use Colors: @colorant_str
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
@use "./csv_view" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...
@use "./gallery_view" exports...

export CHECK, CHECK_GOOD, Checked, COMPARES, value_brief, check_line, CheckView, ischeck, checks,
       check_places, checked!, check_words, check_colour, CheckDot, CHECK_DOT, check_tip, CheckTop,
       open_checks!, check_fixed, CHECK_INSET, check_face, CheckLine, check_line!, check_input, julia_look,
       open_check!, settle_check!, describe_dots, CHECK_LEVELS, in_lines, check_in_charge, check_html,
       FILE_CHECK, file_checks, file_checks_tick!, LIVE_WAIT, part_expr, defines_function, live_checks_tick!,
       check_note, mark_checks, hover_check!, file_results, check_part, next_check!, expression_at,
       check_value, add_check!, CheckButtons, check_buttons

const CHECK = "check"
push!(BLOCK_ICONS, "check2-square", "check-circle-fill", "x-circle-fill", "exclamation-triangle-fill", "arrow-clockwise")
const CHECK_GOOD = colorant"rgb(52,150,86)"
"One line of a `check` block as it came out: its code, how it went, which is :pass, :fail or :stop, and what there is to say of one that didn't pass"
struct Checked
  code::String
  went::Symbol
  said::String
end

"The functions that compare two values. A check that calls one and fails says what the two values were."
const COMPARES = (:(==), :(!=), :≠, :≈, :≉, :(<), :(<=), :≤, :(>), :(>=), :≥, :(===), :(!==), :isa, :in, :∈, :∉, :⊆, :isequal, :isapprox)

"`value` in a few characters, as Julia writes it"
value_brief(value) = (s = try Base.invokelatest(repr, value) catch; "a value" end; length(s) > 40 ? first(s, 39) * "…" : s)

"Run `code`, one line of a `check` block, in the module of the page's code, and give how it went"
check_line(e, code::AbstractString) = begin
  path = isempty(e.buf.path) ? joinpath(e.folder, "untitled.md") : e.buf.path
  # The first line of what went wrong, without the long name that Julia has for the page's module
  why(err) = replace(String(first(split(trouble(err), '\n'))), r" in `Main\.[^`]*`" => "")
  ex = try Meta.parse(code) catch err; return Checked(code, :stop, why(err)) end
  Meta.isexpr(ex, (:incomplete, :error)) && return Checked(code, :stop, "Julia can't read this line.")
  two = Meta.isexpr(ex, :call, 3) && ex.args[1] in COMPARES
  # A line that compares two values gives both, with what the comparison came to
  ran = two ? "let var\"#left\" = ($(ex.args[2])), var\"#right\" = ($(ex.args[3])); (var\"#left\", var\"#right\", $(ex.args[1])(var\"#left\", var\"#right\")) end" : String(code)
  value = try
    cd(() -> running_code(m -> run_in(m, ran, path), e), isdir(docdir(e)) ? docdir(e) : pwd())
  catch err
    return Checked(code, :stop, why(err))
  end
  came = two ? value[3] : value
  came === true && return Checked(code, :pass, "")
  came === false || return Checked(code, :fail, "It came to $(value_brief(came)), which is neither true nor false.")
  Checked(code, :fail, two ? "$(value_brief(value[1])) $(ex.args[1]) $(value_brief(value[2]))" : "")
end

"What a `check` block shows: how each of its lines went"
@def mutable struct CheckView <: SemanticUI
  n::Int = 0                            # its place among the page's check blocks
  first::Int = 0                        # the lines of its block, when the page was last laid out
  last::Int = 0
  lines::Vector{String} = String[]      # the block's lines
  results::Vector{Checked} = Checked[]
  ran::Any = nothing                    # the checks, the count of runs of the page's code and the page that `results` are of
  open::Bool = false                    # it shows each check with what it found, and not a row of dots
  editing::Int = 0                      # the check whose line is being changed, or one more than there are for a new check. 0 is none.
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its dots, its top, its button, its lines and its field, kept between frames
end

reread!(v::CheckView, lines) = (lines == v.lines || (v.lines = lines); v)

"True when a line of a block is a check: it isn't blank and isn't a comment"
ischeck(line) = !isempty(strip(line)) && !startswith(strip(line), '#')

"The lines of a `check` block that are checks: each line that isn't blank and isn't a comment"
checks(lines) = [String(strip(l)) for l in lines if ischeck(l)]

"Where each check is in the lines of a `check` block"
check_places(lines) = findall(ischeck, lines)

"Run the checks of `v`, unless they ran since they last changed and since the page's code last ran"
checked!(v::CheckView) = begin
  e = editor(v)
  key = (checks(v.lines), CODE_RUNS[], e.buf.path)
  v.ran == key && return v
  v.results = Checked[check_line(e, code) for code in key[1]]
  v.ran = key
  v
end

"What the top of a `check` block says: how many of its checks pass"
check_words(results) = begin
  n, passed = length(results), count(r -> r.went == :pass, results)
  n == 0 ? "No checks yet. Write one on each line, like total == 12." :
  passed < n ? "$passed of $n check$(n == 1 ? "" : "s") pass$(passed == 1 ? "es" : "")" :
  n == 1 ? "The check passes" : "All $n checks pass"
end

"The colour of the dot of a check that went as `r` did"
check_colour(r::Checked) = r.went == :pass ? CHECK_GOOD : CHECK_BAD

"A dot of a `check` block at its highest level. The mouse over it shows the check's line, and what it found."
@def mutable struct CheckDot <: SemanticUI
  of::Any = nothing
  i::Int = 0                                  # the check that it's for, in the results of `of`
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
end

const CHECK_DOT = 10px   # across a dot of a closed `check` block

describe(d::CheckDot) = begin
  rs = d.of.results
  colour = d.i <= length(rs) ? check_colour(rs[d.i]) : colours.faint
  # The room round a dot is a part of it, so the mouse finds it easily
  Box(padding(3px), Box(fixed(CHECK_DOT), height(CHECK_DOT), radius(CHECK_DOT / 2), background(colour)))
end

cursor(::CheckDot) = :hand
draw(ctx, size, ui::ConcreteRect, d::CheckDot) = (d.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

"What the tooltip of a check's dot says: its line, in the colours of its code, and what it found when it didn't pass"
check_tip(r::Checked) = begin
  code = Column(Alignment.Start, tip_code(split(r.code, '\n'))...)
  isempty(r.said) && return Box(padding(10px, 7px), code)
  said = Text(r.said, size=12px, family=codefont(), subfamily=codestyle(), color=TIP_INK, wrap=WrapMode.none)
  Box(padding(10px, 7px), Column(Alignment.Start, child_gap=6px, code, said))
end

onmouse(d::CheckDot, ev::MouseMove) = begin
  rs = d.of.results
  d.i <= length(rs) && show_tooltip!(ev.window, check_tip(rs[d.i]), d.rect..., placement=:bottom, gap=6px)
end

"The top of an open `check` block. A click on it closes the block, so that it shows its dots."
@def mutable struct CheckTop <: SemanticUI
  of::Any = nothing
end

describe(t::CheckTop) = begin
  v = t.of
  rs = v.results
  good = all(r -> r.went == :pass, rs)
  Row(width(grow=grow), height(34px), padding(0px, 6px, 0px, 12px), child_gap=8px, Alignment.Center, background(colours.block),
      Box(fixed(16px), Alignment.Center, justify=Alignment.Center,
          isempty(rs) ? Icon("check2-square", size=14px, color=colours.dim) : Icon(good ? "check-circle-fill" : "x-circle-fill", size=14px, color=good ? CHECK_GOOD : CHECK_BAD)),
      Box(width(grow=grow), Alignment.Start, label(check_words(rs), 13px, weight="Medium")),
      Box(label(ishovered(t) ? "Click to show only the dots" : "", 11px, color=colours.faint)),
      block_button!(v, :again, :again, icon="arrow-clockwise", tip="Run the checks again"))
end

cursor(::CheckTop) = :hand
onkey(t::CheckTop, ev::KeyPress{Keys.mouse_left}) = unmodified(ev) ? (hide_tooltip!(ev.window); open_checks!(t.of, false); handled) : nothing

"Show each check of `v` with what it found, with `open`, or only a dot for each check. Opening runs the checks again."
open_checks!(v::CheckView, open::Bool) = begin
  open && (v.ran = nothing)
  # A check that's being changed is written as the block closes
  open || v.editing == 0 || (settle_check!(v); focus(editor(v)))
  v.open = open
  redraw_in!(editor(v), 0)
  v
end

act!(v::CheckView, action, w) = begin
  action == :again && (v.ran = nothing; redraw_in!(editor(v), 0))
  handled
end

describe(v::CheckView) = begin
  checked!(v)
  rs = v.results
  v.open || return describe_dots(v)
  mark(r) = r.went == :pass ? Icon("check-circle-fill", size=14px, color=CHECK_GOOD) :
            Icon(r.went == :fail ? "x-circle-fill" : "exclamation-triangle-fill", size=14px, color=CHECK_BAD)
  # What a check found is in a box as tall as its lines, so that the words under it don't come up into it
  words(text, size, colour) = Box(width(grow=grow), Alignment.Start, padding(CHECK_INSET, 3px), Text(text, size=size, family=codefont(), subfamily=codestyle(), color=colour, wrap=WrapMode.words))
  row(k, sign) = Row(width(grow=grow), padding(12px, 3px), child_gap=5px, Alignment.Start,
                     Box(fixed(16px), height(25px), Alignment.Center, justify=Alignment.Center, sign),
                     Column(width(grow=grow), Alignment.Start, check_line!(v, k),
                            (k > length(rs) || isempty(rs[k].said) ? () : (words(rs[k].said, 12px, CHECK_BAD),))...))
  # The last row adds a check, unless the page can't be changed
  adds = check_fixed(v) ? () : (row(length(rs) + 1, Icon("plus", size=14px, color=colours.faint)),)
  Column(block_look()..., clip=true, name="Check",
    block_part!(() -> CheckTop(of=v), v, :top),
    (isempty(rs) && isempty(adds) ? () : (Column(width(grow=grow), Alignment.Start, padding(0px, 5px), (row(k, mark(r)) for (k, r) in enumerate(rs))..., adds...),))...)
end

# --- a check that's changed where it is

"True when the page can't be changed, so its checks can't be"
check_fixed(v::CheckView) = (b = editor(v).buf; readonly(b) || b.fixed)

const CHECK_INSET = 4px   # between the left of a check's line and its code, so that a line under the mouse has room round its words

"The font of a check's code, in the open block"
check_face() = Face(codefont(), codestyle(), 13px, colours.ink, false)

"The line of a check in an open `check` block. A click on it puts a field in its place, to change it."
@def mutable struct CheckLine <: SemanticUI
  of::Any = nothing
  k::Int = 0   # the check that it's for, in the order of the block's checks. One more than there are is the line that adds a check.
end

"The line of the check `k` of `v`, kept between frames"
check_line!(v::CheckView, k::Int) = block_part!(() -> CheckLine(of=v, k=k), v, (:line, k))

"""
The field that takes the place of a check's line while you change it. It
shows its text as Julia code, each part in its colour, with no box round it.
"""
check_input(v::CheckView) = block_part!(v, :edit) do
  TextInput(placeholder="A check, like total == 12", font_family=codefont(), font_size=13px, look=julia_look)
end

"""
How a field of one line of Julia looks: no box, and each part of the code in
its colour. The field's own text is under the colours, and can't be seen. It's
the first text in the field, so the caret and the selection go by it.
"""
julia_look(input, text) = begin
  isempty(input.text) && return Row(width(grow=grow), height(grow=grow), clip=true, text)
  size = TextInputs.text_size(input)
  under = Text(input.text, size=size, family=TextInputs.family(input), color=clear, wrap=WrapMode.none)
  parts = value_parts(input.text, Face(TextInputs.family(input), codestyle(), size, TextInputs.ink(input), false))
  Row(width(grow=grow), height(grow=grow), clip=true,
      Row(width(grow=grow), clip_x=true, Stack(Alignment.Start, offset_x=-input.scroll, under, Row(Alignment.Center, parts...))))
end

describe(l::CheckLine) = begin
  v = l.of
  rs = v.results
  v.editing == l.k && return Row(width(grow=grow), height(25px), padding(CHECK_INSET, 0px), Alignment.Center,
                                 Box(width(grow=grow), height(grow=grow), check_input(v)))
  shown = l.k <= length(rs) ? Row(Alignment.Center, value_parts(rs[l.k].code, check_face())...) :
          Text("Add a check", size=13px, family=codefont(), subfamily=codestyle(), color=colours.faint, wrap=WrapMode.none)
  Row(width(grow=grow), height(25px), padding(CHECK_INSET, 0px), radius(5px), Alignment.Center, clip=true,
      background(ishovered(l) && !check_fixed(v) ? colours.hover : clear), shown)
end

cursor(l::CheckLine) = check_fixed(l.of) ? :arrow : :ibeam

# A click puts the caret in the field where it was in the line. A click with a modifier key down is the page's.
onkey(l::CheckLine, ev::KeyPress{Keys.mouse_left}) = begin
  v = l.of
  (unmodified(ev) && !check_fixed(v) && v.editing != l.k) || return nothing
  hide_tooltip!(ev.window)
  r = rect(l)
  col = r === nothing ? 0 : round(Int, num(ev.window.mouse[1] - r.left - CHECK_INSET) / num(measure(check_face(), "0")))
  open_check!(v, l.k, col)
end

"""
Put a field in the place of the check `k` of `v`, with the caret at `col` in
its line. A check that was being changed is written first.
"""
open_check!(v::CheckView, k::Int, col::Int=typemax(Int)) = begin
  was, n = v.editing, length(check_places(v.lines))
  settle_check!(v)
  # A check that was taken away or added before this one moves it
  0 < was < k && (k += length(check_places(v.lines)) - n)
  places = check_places(v.lines)
  input = check_input(v)
  input.font_family = codefont()
  input.text = k <= length(places) ? String(strip(v.lines[places[k]])) : ""
  input.anchor = input.cursor = clamp(col, 0, length(input.text))
  input.scroll = 0px
  v.editing = k
  focus(input)
  handled
end

"""
Write what the field of `v` holds into the line of its check, and take the
field away. An empty field takes the check away, and the field of a new check
adds one at the end of the block.
"""
settle_check!(v::CheckView) = begin
  k, v.editing = v.editing, 0
  (k == 0 || check_fixed(v)) && return v
  text = String(strip(check_input(v).text))
  lines, places = copy(v.lines), check_places(v.lines)
  if k <= length(places)
    i = places[k]
    text == strip(lines[i]) && return v
    # The line keeps the space before it
    isempty(text) ? deleteat!(lines, i) : (lines[i] = match(r"^\s*", lines[i]).match * text)
  else
    isempty(text) && return v
    push!(lines, text)
  end
  write_block!(v, CHECK, lines)
end

# Return writes the check. After a new check, the field stays at the end of the list for another one.
onkey(v::CheckView, ev::KeyPress{Keys.enter}) = begin
  (unmodified(ev) && v.editing != 0 && ev.window.focus === check_input(v)) || return nothing
  adding = v.editing > length(check_places(v.lines)) && !isempty(strip(check_input(v).text))
  settle_check!(v)
  adding ? open_check!(v, length(check_places(v.lines)) + 1) : focus(editor(v))
  handled
end
# Esc leaves the check as it was
onkey(v::CheckView, ev::KeyPress{Keys.escape}) = begin
  (unmodified(ev) && v.editing != 0 && ev.window.focus === check_input(v)) || return nothing
  v.editing = 0
  focus(editor(v))
  handled
end

"A click somewhere else writes what the field of a check holds"
block_tick!(v::CheckView) = begin
  v.editing == 0 && return v
  w = window_of(v)
  (w === nothing || w.focus !== check_input(v)) && settle_check!(v)
  v
end

"""
A closed `check` block: a dot for each check, in rows as wide as the page
leaves them, and after the dots how many pass. With the mouse over it, the
words also say that a click shows each check.
"""
describe_dots(v::CheckView) = begin
  rs = v.results
  dots = [block_part!(() -> CheckDot(of=v, i=i), v, (:dot, i)) for i in eachindex(rs)]
  # The words after the dots need about 280px
  across = max(1, floor(Int, num(editor(v).width - 280px) / num(CHECK_DOT + 6px)))
  rows = [Row(Alignment.Center, dots[i:min(i + across - 1, end)]...) for i in 1:across:length(dots)]
  words = check_words(rs) * (!isempty(rs) && ishovered(v) ? ". Click to see each one." : "")
  Row(width(grow=grow), Alignment.Center, padding(0px, 4px), child_gap=4px, name="Check",
      (isempty(rows) ? () : (Column(Alignment.Start, rows...),))...,
      Box(width(grow=grow), Alignment.Start, padding(0px, 0px, 0px, 6px), label(words, 13px, color=colours.dim)))
end

cursor(::CheckView) = :hand
# A click on the dots opens the block. A click on an open block, out of its top and its lines, does nothing.
# With ⌥ held, the click is the page's, and it shows the block's lines.
onkey(v::CheckView, ev::KeyPress{Keys.mouse_left}) = unmodified(ev) ? (v.open || (hide_tooltip!(ev.window); open_checks!(v, true)); handled) : nothing

# The levels of a `check` block, from the lowest: its lines, each check with what it found, and a dot for each check
const CHECK_LEVELS = ("the checks as lines of Julia", "each check, with what it found", "a dot for each check")

levels(::CheckView) = CHECK_LEVELS

"True while the caret is in the lines of the block of `v`, so that the block shows as its lines"
in_lines(v::CheckView) = begin
  b = editor(v).buf
  span = block_lines(b, CHECK, v.n)
  span !== nothing && span[1] <= b.caret[1] <= span[2] && picked(b) != span
end

level(v::CheckView) = in_lines(v) ? 1 : v.open ? 2 : 3

level!(v::CheckView, i::Int) = begin
  e = editor(v)
  b = e.buf
  span = block_lines(b, CHECK, v.n)
  span === nothing && return v
  s, t = span
  if i == 1
    # The block shows its lines, with the caret at the start of the first, as a click with ⌥ held puts it
    b.caret = b.anchor = (min(s + 1, t), 0)
  else
    i == 2 ? open_checks!(v, true) : open_checks!(v, false)
    # The caret leaves the block's lines and goes onto the block as a whole, so the block shows as what it makes
    s <= b.caret[1] <= t && (b.caret = b.anchor = (s, 0))
  end
  touch!(e)
  v
end

"""
The view of the `check` block that the caret is on as a whole, or in the lines
of, in a page that shows rich text. It's nothing when the caret is elsewhere.
The top bar asks this block for its levels.
"""
check_in_charge(e) = begin
  b = e.buf
  (rich(b) && !caretless(b) && !julia_file(b)) || return nothing
  i = b.caret[1]
  1 <= i <= length(b.lines) || return nothing
  ks = kinds(b)
  ks[i].kind in (Kind.fence, Kind.code) || return nothing
  s, t = codeblock(b, i)
  (t > s && ks[s].kind == Kind.fence && ks[s].level == 0 && ks[s].lang == CHECK && ks[t].kind == Kind.fence && ks[t].level == 1) || return nothing
  s <= b.anchor[1] <= t || return nothing
  block_view(e, CHECK, block_place(b, CHECK, s))
end

check_html(e, v::CheckView) = begin
  checked!(v)
  "<p><strong>$(escape(check_words(v.results)))</strong></p>\n<ul>\n" *
    join(("<li>$(r.went == :pass ? "✓" : "✗") <code>$(escape(r.code))</code>$(isempty(r.said) ? "" : ": " * escape(r.said))</li>" for r in v.results), "\n") * "\n</ul>"
end

BLOCKS[CHECK] = CheckView
block_name(::Type{CheckView}) = "Check"
block_icon(::Type{CheckView}) = "check2-square"
block_insert(::Type{CheckView}) = ("Check", ["```$CHECK", "", "```"], (2, 0))
block_is_code(::Type{CheckView}) = true
block_html(e, v::CheckView) = check_html(e, v)

# --- checks in a file of Julia code ---
#
# A comment like `# check: share("70%") == 0.7` in a file of Julia code is a
# check, as a line of a `check` block is. It runs in the module of the file's
# code, and a dot at the end of its line says how it went: green when it comes
# to true, and red when it doesn't, with the two values that it compared, or
# with why it stopped. The checks run when the window opens the file, when a
# check changes, and each time code runs, as it does with ⌘Return. A name that
# the file's code makes is there once that code ran: in a file that Ladder
# loaded, at once, and in any other file after ⌘Return in its function. The
# top bar says how many pass, and a click there goes to the next that fails.
# The command Add Check writes a check of the call at the caret, with the
# value that it has now.

const FILE_CHECK = r"^\s*#\s*check:\s*(.*\S)\s*$"

"""
The checks of a file of Julia code: the line of each, and its code. `opens[i]`
is the quote of a string in three quotes that's open at the start of line i,
as `string_opens` gives it. A line in such a string, like the middle of a
docstring or of a prompt for an agent, is text and not a check.
"""
file_checks(lines, opens=nothing) = begin
  out = Tuple{Int,String}[]
  for (i, l) in enumerate(lines)
    occursin("check:", l) || continue
    opens === nothing || opens[i] == '\0' || continue
    m = match(FILE_CHECK, l)
    m === nothing || push!(out, (i, String(m[1])))
  end
  out
end

"True for a window that shows a file of Julia code as its text"
julia_file(e) = endswith(e.buf.path, ".jl") && e.buf.view == :code

"""
In each frame: find the checks of a file of Julia code when its text changed,
and run them when a check changed or code ran since they last ran. What they
found is in `e.nodes[:file_checks]`.
"""
file_checks_tick!(e) = begin
  julia_file(e) || return nothing
  b = e.buf
  s = get(e.nodes, :file_checks, nothing)
  if s === nothing || s.version != b.version
    s = (version=b.version, found=file_checks(b.lines, string_opens(b)), ran=s === nothing ? nothing : s.ran,
         results=s === nothing ? Dict{String,Checked}() : s.results)
  end
  key = (unique(last.(s.found)), CODE_RUNS[])
  if !isempty(key[1]) && key != s.ran
    s = (; s..., ran=key, results=Dict(code => check_line(e, code) for code in key[1]))
  end
  e.nodes[:file_checks] = s
  nothing
end

# A function with checks over it runs again by itself, a second after you stop
# typing, in the module that the file's code has: the one that Ladder made
# when it loaded the file, or when ⌘Return ran code of it. Then its checks run
# again. Other code runs only when you run it, as code that does something
# when it runs can do harm. Code that doesn't run yet, like a line that's half
# typed, leaves the checks as they were.

"How long after the last change to its text a function with checks over it runs again, in seconds"
const LIVE_WAIT = 1.0

"""
The expression of `code`, a top part of a file of Julia code, or nothing when
Julia can't read it or it has more than one. Comments after it are read as
nothing, which `Meta.parse` doesn't do.
"""
part_expr(code::AbstractString) = begin
  all = try Meta.parseall(code) catch; return nothing end
  found = [x for x in all.args if !(x isa LineNumberNode)]
  length(found) == 1 && !Meta.isexpr(found[1], (:error, :incomplete)) ? found[1] : nothing
end

"True when `ex`, a top part of a file of Julia code, defines a function, with its documentation or without"
defines_function(ex) = definition_of(ex) !== nothing

"""
In each frame: a second after the text of a file of Julia code last changed,
run each function of it that has checks over it, and that changed since it
last ran. See "checks in a file of Julia code".
"""
live_checks_tick!(e) = begin
  julia_file(e) || return nothing
  b = e.buf
  s = get(e.nodes, :file_checks, nothing)
  (s === nothing || isempty(s.found)) && return nothing
  key = page_key(b.path)
  mod = something(loaded_module(key), Some(get(PAGE_MODULES, key, nothing)))
  mod === nothing && return nothing
  live = get(e.nodes, :live_checks, nothing)
  # The module has each function as the window had it when the module was first seen, or as it last ran since
  if live === nothing || live.mod !== mod
    e.nodes[:live_checks] = (mod=mod, version=b.version, typed=b.version, changed=0.0,
                             start=Set(t for (_, t) in part_texts(b.lines)), ran=Dict{String,String}())
    return nothing
  end
  live.version == b.version && return nothing
  # Each change starts the wait again
  if live.typed != b.version
    e.nodes[:live_checks] = (; live..., typed=b.version, changed=time())
    redraw_in!(e, LIVE_WAIT)
    return nothing
  end
  wait = LIVE_WAIT - (time() - live.changed)
  wait > 0 && (redraw_in!(e, wait); return nothing)
  # The first line of code under each check is a line of the function that it checks
  under = Set(code_start(b.lines, i) for (i, _) in s.found)
  ran = 0
  for (first, code) in part_texts(b.lines)
    any(l -> first <= l <= first + count('\n', code), under) || continue
    def = definition_of(part_expr(code))
    def === nothing && continue
    # The function is known by its first line, like `twice(x)`
    key = string(def_call(def))
    (haskey(live.ran, key) ? live.ran[key] == code : code in live.start) && continue
    try
      # Blank lines before the code give each of its lines the number that it has in the file
      Base.include_string(mod, "\n"^(first - 1) * code, String(b.path))
      live.ran[key] = code
      ran += 1
    catch
      # Code that doesn't run yet leaves the checks as they were
    end
  end
  e.nodes[:live_checks] = (; live..., version=b.version)
  ran > 0 && (CODE_RUNS[] += 1; redraw_windows!())   # the checks run again
  nothing
end

"What a check of a file says after its dot: nothing when it passed, the values that it compared, or why it stopped"
check_note(r::Checked, loaded::Bool) = begin
  r.went == :pass && return ""
  note = r.went == :fail ? (isempty(r.said) ? "It came to false." : r.said) : r.said
  # A name that the file makes isn't there until the file's code runs
  !loaded && r.went == :stop && occursin("UndefVarError", note) && (note = rstrip(note, '.') * ". Press ⌘Return in its function to run it.")
  length(note) > 100 ? first(note, 99) * "…" : note
end

"The buttons that follow a check's line, as the last frame drew them, which the window keeps for a click on one: see `mark_checks` and `check_button!`"
@def mutable struct CheckButtons
  drawn::Vector{Any} = Any[]   # for each button: what it does, where it is in the window, and its check
end

"The buttons that follow a check's line in the window of `e`, as the last frame drew them"
check_buttons(e) = state_of(e, CheckButtons).drawn

"""
Draw a dot at the end of each line of a file of Julia code that's a check,
green or red, and what a check that failed found. While the mouse or the
caret is on a check's line, buttons follow: Show Steps, and Fix It for one
that fails. The page's text is at `ui`.
"""
mark_checks(ctx, e, ui) = begin
  buttons = check_buttons(e)
  empty!(buttons)
  s = get(e.nodes, :file_checks, nothing)
  (s === nothing || isempty(s.found) || s.version != e.buf.version) && return nothing
  rows = Dict(s.found)
  loaded = loaded_module(page_key(e.buf.path)) !== nothing
  w = window_of(e)
  mouse = w === nothing ? -1.0 : num(w.mouse[2])
  for it in e.layout[e.shown]
    f = it.content
    f isa Flow || continue
    code = get(rows, it.first, nothing)
    code === nothing && continue
    r = get(s.results, code, nothing)
    r === nothing && continue
    k = length(f.lines)
    vl = f.lines[k]
    right = isempty(vl.segs) ? 0px : last(vl.segs).x + last(vl.segs).w
    mid = num(ui.top + it.top + line_top(f, k) + vl.high / 2)
    x = num(ui.left + right) + 10
    round_box(ctx, x, mid - 4, 8, 8, 4; fill=check_colour(r))
    note = check_note(r, loaded)
    face = Face(SANS, "", px(round(num(f.size) * 0.85)), check_colour(r), false)
    isempty(note) || write_ink(ctx, note, x + 14, mid + 4, face)
    # Buttons for the check that the mouse or the caret is on: see "a check that fails"
    top = num(ui.top + it.top)
    (e.buf.caret[1] == it.first || top <= mouse < top + num(it.tall)) || continue
    left = x + 14 + (isempty(note) ? 0 : num(measure(face, note)) + 10)
    small = Face(SANS, "Medium", px(round(num(f.size) * 0.75)), colours.dim, false)
    for (action, words) in ((:steps, "Show Steps"), (:fix, "Fix It"))
      (action == :fix && (r.went == :pass || needs_run(e, r))) && continue
      across = num(measure(small, words)) + 14
      round_box(ctx, left, mid - 9, across, 18, 5; fill=colours.hover)
      write_ink(ctx, words, left + 7, mid + 4, small)
      push!(buttons, (action, (left, mid - 9, across, 18.0), FileCheck(it.first, code, r.went)))
      left += across + 6
    end
  end
  nothing
end

"Draw the window again when the mouse at `pos` moves onto the line of a check of a file of Julia code, or off it, for the buttons beside a check: see `mark_checks`"
hover_check!(e, pos) = begin
  s = get(e.nodes, :file_checks, nothing)
  (julia_file(e) && s !== nothing && !isempty(s.found) && !isempty(e.layout)) || return nothing
  i = locate(e, pos)[1]
  on = any(((l, _),) -> l == i, s.found) ? i : 0
  get(e.nodes, :check_hover, 0) == on && return nothing
  e.nodes[:check_hover] = on
  redraw_in!(e, 0)
  nothing
end

"The checks of the file of `e` that ran, each with its line and how it went, from the top"
file_results(e) = begin
  s = get(e.nodes, :file_checks, nothing)
  s === nothing && return Tuple{Int,Checked}[]
  [(i, s.results[code]) for (i, code) in s.found if haskey(s.results, code)]
end

"The count of the checks in the top bar, for a file of Julia code that has checks"
check_part(e) = julia_file(e) && !isempty(file_results(e)) ? (node!(CheckCount, e, :check_count),) : ()

describe(c::CheckCount) = begin
  e = editor(c)
  results = last.(file_results(e))
  ishovered(c) || (c.quiet = false)
  Box(height(28px), padding(8px, 0px), radius(6px), background(ishovered(c) ? colours.hover : clear),
    label(check_words(results), 12px, color=all(r -> r.went == :pass, results) ? CHECK_GOOD : CHECK_BAD))
end
cursor(::CheckCount) = :hand
tip(c::CheckCount) = all(((_, r),) -> r.went == :pass, file_results(editor(c))) ? "Go to the next check" : "Go to the next check that fails"
onkey(c::CheckCount, ::KeyPress{Keys.mouse_left}) = (next_check!(editor(c)); hush!(c))

"Put the caret on the next check of the file after the caret's line that fails, round to the top again. When none fails, the next check."
next_check!(e) = begin
  found = file_results(e)
  failing = filter(((_, r),) -> r.went != :pass, found)
  lines = first.(isempty(failing) ? found : failing)
  isempty(lines) && return nothing
  i = something(findfirst(>(e.buf.caret[1]), lines), 1)
  note_place!(e)   # ⌘⌥← comes back here
  show_line!(e, lines[i])
  hold!(e, max(lines[i] - 3, 1), 24px - PAGE_TOP)
  nothing
end

"""
The Julia expression at the caret of the window of `e`, for Add Check, with
its line: what's selected, or else the name at the caret with the names that
dots join it to and what's in the brackets after it, like `share("70%")`.
"""
expression_at(e) = begin
  b = e.buf
  lo, hi = selection(b)
  if lo != hi
    lo[1] == hi[1] || error("Select an expression on one line.")
    return (lo[1], String(strip(excerpt(b, lo, hi))))
  end
  found = name_at(b, b.caret)
  found === nothing && error("Put the caret on a call, like share(\"70%\"), or select an expression.")
  i = b.caret[1]
  chars = collect(b.lines[i])
  from = found.col - sum(o -> length(o) + 1, found.owners, init=0)   # where the names before it start
  stop = found.col + length(found.name)                             # its last character
  if stop < length(chars) && chars[stop+1] == '('
    depth = 0
    for k in stop+1:length(chars)
      chars[k] == '(' && (depth += 1)
      chars[k] == ')' && (depth -= 1)
      if depth == 0
        stop = k
        break
      end
    end
    depth == 0 || error("The brackets after $(found.name) don't close on this line.")
  end
  (i, String(chars[from+1:stop]))
end

"`value` as Julia writes it, for a check to compare with. It's an error when that's too long, or isn't Julia that reads back."
check_value(code, value) = begin
  s = Base.invokelatest(repr, value)
  ex = Meta.parse(s; raise=false)
  (length(s) > 80 || Meta.isexpr(ex, (:error, :incomplete))) && error("$code comes to $(value_brief(value)), which is too long to write in a check.")
  s
end

"""
Write a check of the expression at the caret over its function, with the value
that the expression has now, like `# check: share("70%") == 0.7`. Ladder runs
the expression in the module of the file's code. Later, a change that gives
another value turns the check's dot red. See "checks in a file of Julia code".
"""
add_check!(e) = begin
  julia_file(e) || error("A check of this kind goes in a file of Julia code.")
  b = e.buf
  i, code = expression_at(e)
  value = try
    cd(() -> running_code(m -> run_in(m, code, b.path), e), isdir(docdir(e)) ? docdir(e) : pwd())
  catch err
    why = String(first(split(trouble(err), '\n')))
    error("Ladder couldn't work out $code. $why" * (loaded_module(page_key(b.path)) === nothing ? " Press ⌘Return in its function first." : ""))
  end
  check = value === true ? code : value === false ? "!($code)" : "$code == $(check_value(code, value))"
  # The check goes over the function that the caret is in, after its documentation and the checks that it has
  at = min(code_start(b.lines, first(part_lines(b.lines, i))), i)
  indent = match(r"^\s*", b.lines[at]).match
  caret, anchor = b.caret, b.anchor
  edit!(b, (at, 0), (at, 0), "$(indent)# check: $check\n")
  moved(p) = p[1] >= at ? (p[1] + 1, p[2]) : p
  b.caret, b.anchor = moved(caret), moved(anchor)
  nothing
end
add_command!(add_check!, title="Write a check of the call at the caret over its function, with the value that the call has now", kind=:edit)

works_here(e, ::Val{:add_check}) = julia_file(e)
