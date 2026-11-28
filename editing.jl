# Editing: typing, deleting, the pairs of brackets and quotes, and copying the selection

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" light window_of
@use "github.com/jkroso/UI.jl/Interface/draw" ui
@use "github.com/jkroso/UI.jl/Interface/fonts" skia_font
@use "./markdown" Kind spans words opens_callout
@use "./highlight" tokens
@use "./sheet" SHEET parts
@use "./spreadsheet" SPREADSHEET moved
@use "./pasteboard" => Pasteboard
@use InteractiveUtils: clipboard
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
@use "./sheet_view" exports...
@use "./contact_view" exports...
@use "./result_block" exports...
@use "./code_names" exports...
@use "./page_extras" exports...
@use "./agent/window" exports...
@use "./agent/pane" exports...
@use "./sum_functions" exports...
@use "./dropped_files" exports...
@use "./copied_blocks" exports...

@use "./canvas_view" keep_copy keep_pasted passing
export CLOSING, ENDING, OPENERS, OPENING, PAIRS, PAIR_REACH, SLIDE_TIME, backstep, bracket_pair,
       bracket_runs, caret_pair, carry, copy_selection!, erase!, glow_bracket_pair, in_empty_pair,
       in_long_string, indent!, indent_lines!, neighbour, newline!, next_cell!, opened, pair!,
       parts_of, pass, quotes, screen_edge, shift_lines!, sidebar_room!, sliding, surround!,
       text_size, typed_code, word_step, zoom!, BracketsState, after, opens, toggle_panel!,
       with_others

# --- editing -----------------------------------------------------------------------------

"Put `new` where the selection is, or at the caret"
type!(e, new; typing=false) = begin
  b = e.buf
  run = picked(b)
  if run !== nothing
    isempty(new) && return e
    # What's pasted or inserted while the caret is on a part as a whole goes on a line of its own under the part
    b.caret = b.anchor = line_end(b, run[2])
    new = "\n" * new
  end
  cell = cellat(b, b.caret)
  if cell !== nothing && b.caret[1] == b.anchor[1]
    # In a row of a table, typing only ever changes the cell the caret is in
    lo, hi = selection(b)
    (within(cell, lo[2]) && within(cell, hi[2])) || (b.anchor = b.caret)
    new = replace(new, '\n' => ' ')
  end
  lo, hi = selection(b)
  # A third ` that opens a code block. Inside a block it would close that block instead.
  fence = new == "`" && lo == hi && kinds(b)[lo[1]].kind != Kind.code && strip(b.lines[lo[1]]) == "``" && lo[2] == length(b.lines[lo[1]])
  if rich(b) && lo != hi
    # As rich text, the markup of text that's only partly selected stays, after what's typed
    from, to, kept = richcut(b, lo, hi, typed=!isempty(new))
    edit!(b, from, to, new * kept; typing)
    parts = split(new, '\n')
    b.caret = b.anchor = (from[1] + length(parts) - 1, length(parts) == 1 ? from[2] + length(new) : length(last(parts)))
  else
    edit!(b, lo, hi, new; typing)
  end
  if fence
    # The line that closes the block is typed too. Without it, the block would
    # take the line that opens the next block as its end, and turn every block
    # after it inside out.
    at = b.caret
    edit!(b, at, at, "\n```")
    b.caret = b.anchor = at
  end
  touch!(e)
end

"The place one character of the file before or after `p`"
neighbour(b::Buffer, (i, col)::Pos, by::Int) =
  by < 0 ? (col > 0 ? (i, col - 1) : i > 1 ? line_end(b, i - 1) : (i, col)) :
           (col < length(b.lines[i]) ? (i, col + 1) : i < length(b.lines) ? (i + 1, 0) : (i, col))

"""
The place one character before or after `p`. As rich text that's one
character that shows: the place is past any markup that's in the way, and past
the whole of something that shows as one thing, like the number of a footnote.
"""
beside(b::Buffer, p::Pos, by::Int) = begin
  rich(b) || return neighbour(b, p, by)
  run = p == b.caret ? picked(b) : nothing
  # From a part that the caret is on as a whole, it's the end of the line before the part or the start of the line after it
  run === nothing || return by < 0 ? (run[1] > 1 ? line_end(b, run[1] - 1) : p) : (run[2] < length(b.lines) ? (run[2] + 1, 0) : p)
  i, col = p
  hidden, whole = unseen(b, i), wholes(b, i)
  if by < 0
    for (a, z) in hidden
      a < col <= z && (col = a)
    end
    col <= 0 && return neighbour(b, (i, 0), by)
    k = findfirst(r -> r[2] == col, whole)
    (i, k === nothing ? col - 1 : whole[k][1])
  else
    for (a, z) in hidden
      a <= col < z && (col = z)
    end
    col >= length(b.lines[i]) && return neighbour(b, line_end(b, i), by)
    k = findfirst(r -> r[1] == col, whole)
    (i, k === nothing ? col + 1 : whole[k][2])
  end
end

"The place one word before or after `p`"
word_step(b::Buffer, p::Pos, by::Int) = begin
  i, col = p
  chars = collect(b.lines[i])
  # As rich text, a line's text can start after characters that don't show, like the # of a heading
  (by < 0 ? col <= first_stop(b, i) : col == length(chars)) && return beside(b, p, by)
  if by < 0
    while col > 0 && !isword(chars[col]); col -= 1 end
    while col > 0 && isword(chars[col]); col -= 1 end
  else
    while col < length(chars) && !isword(chars[col+1]); col += 1 end
    while col < length(chars) && isword(chars[col+1]); col += 1 end
  end
  (i, col)
end



"The place one line up or down from the caret, which is in row `r`, column `c` of a table"
vertical(e, it::Item, (r, c), by::Int) = begin
  b = e.buf
  g = it.content::Grid
  f = g.flows[r][c]
  k, x = spot(f, b.caret[2])
  x = e.goal = something(e.goal, x)
  1 <= k + by <= length(f.lines) && return (b.caret[1], cellcol(f, k + by, x, g.cells[r][c]))
  r += by
  if r < 1
    return it.first > 1 ? line_end(b, it.first - 1) : b.caret
  elseif r > length(g.rows)
    # ↓ on the last row of a table at the end of the document starts a line below it
    it.last == length(b.lines) && edit!(b, line_end(b, it.last), line_end(b, it.last), "\n")
    return (it.last + 1, 0)
  end
  isempty(g.cells[r]) && return (g.rows[r], 0)
  c = min(c, length(g.cells[r]))
  f = g.flows[r][c]
  (g.rows[r], cellcol(f, by < 0 ? length(f.lines) : 1, x, g.cells[r][c]))
end

"The start or end of the line of the screen that the caret is on"
screen_edge(e, by::Int) = begin
  cell = cellat(e.buf, e.buf.caret)
  cell === nothing || return (e.buf.caret[1], by < 0 ? cell.lo : cell.hi)
  i, col = e.buf.caret
  f = flow(e, i)
  k, _ = spot(f, col)
  vl = f.lines[k]
  by < 0 ? (i, vl.from) : (i, k < length(f.lines) ? max(vl.from, vl.to - 1) : vl.to)
end

"""
Where a selection that grows to `p` ends. It steps over the ``` lines of a code
block that the selection didn't start in, and over the whole of a block that
shows as one thing, like a diagram or a contact, because those lines don't show.
"""
pass(b::Buffer, p::Pos, by::Int) = begin
  ks = kinds(b)
  i = p[1]
  ks[i].kind in (Kind.fence, Kind.code) || return p
  s, t = codeblock(b, i)
  s <= b.anchor[1] <= t && return p
  whole = solid(b, i)
  if whole !== nothing && whole[1] < whole[2]
    # Under a block that ends the document there's no line to go to, so the selection ends where the block does
    by > 0 && whole[2] == length(b.lines) && return line_end(b, whole[2])
    i = by < 0 ? whole[1] - 1 : whole[2] + 1
  elseif ks[i].kind == Kind.fence
    i += by
  else
    return p
  end
  1 <= i <= length(b.lines) || return p
  by < 0 ? line_end(b, i) : (i, 0)
end

"Move the caret to `p`, which was reached by going in the direction `by`. With `extend`, the selection grows to it."
move!(e, p::Pos, extend::Bool; keep_goal=false, by=0) = begin
  p = settle(e.buf, p, by)
  extend && by != 0 && (p = pass(e.buf, p, by))
  e.buf.caret = p
  extend || (e.buf.anchor = p)
  touch!(e; keep_goal)
end

erase!(e, to::Pos) = begin
  b = e.buf
  picked(b) === nothing || return delete_lines!(e)   # the part that the caret is on as a whole goes
  insheet(b, b.caret[1]) && !selecting(b) && erase_row!(e, to) && return
  cell = cellat(b, b.caret)
  # In a table, a cell's edges can't be deleted
  cell === nothing || selecting(b) || (to[1] == b.caret[1] && within(cell, to[2])) || return
  selecting(b) || (b.anchor = to)
  type!(e, "")
end

"Return starts a new line. What else it does depends on the block the caret is in."
newline!(e) = begin
  b = e.buf
  picked(b) === nothing || return enter_part!(e)   # Return gives the keyboard to the part that the caret is on
  insheet(b, b.caret[1]) && b.caret[1] == b.anchor[1] && return next_row!(e)
  isempty(rowcells(b, b.caret)) || return next_cell!(e, false, down=true)
  selecting(b) ? type!(e, "\n") : newline!(e, block(b, b.caret[1]))
end

newline!(e, block) = begin
  b = e.buf
  i, col = b.caret
  if rich(b) && kinds(b)[i].kind == Kind.heading && col <= first_stop(b, i) < length(b.lines[i])
    # As rich text, Return at the start of a heading's text moves the heading down a line
    edit!(b, (i, 0), (i, 0), "\n")
    b.caret = b.anchor = (i + 1, col)
    return touch!(e)
  end
  shut, opened = halves!(b)
  type!(e, shut * "\n" * opened)
end

# In a list or a quote, the new line carries it on
newline!(e, ::Type{<:Union{List,Quote,Paragraph}}) = begin
  b = e.buf
  i, col = b.caret
  text, line = b.lines[i], kinds(b)[i]
  k = line.kind
  col < line.prefix && return type!(e, "\n")
  lead = head(text, line.prefix)
  # The line after the one that names a callout is a line of the callout: it starts with the > and no more
  if opens_callout(line)
    shut, opened = halves!(b)
    return type!(e, shut * "\n> " * opened)
  end
  # Return on an empty list item ends the list
  # What starts the item goes as it's written. As rich text, a selection that's
  # deleted keeps what starts its line, so `type!` would leave the item there.
  if length(text) == line.prefix && k != Kind.paragraph
    edit!(b, (i, 0), (i, line.prefix), "")
    return touch!(e)
  end
  # As rich text, bold text that the new line cuts in two is bold on both lines
  shut, opened = halves!(b)
  type!(e, shut * "\n" * carry(lead, k) * opened)
end

"What starts the line after a list item or a quote that starts with `lead`: the next number, or a to-do box with no tick"
carry(lead, k::Kind) = begin
  k == Kind.todo && return replace(lead, r"\[[xX]\]" => "[ ]")
  m = k == Kind.ordered ? match(r"^(\s*)(\d+)(.*)$", lead) : nothing
  m === nothing ? lead : string(m[1], parse(Int, m[2]) + 1, m[3])
end

# In code, the new line starts under the text of the line before. It starts
# one step further in after a line that opens a block.
newline!(e, ::Type{CodeBlock}) = begin
  b = e.buf
  i, col = b.caret
  line = kinds(b)[i]
  if line.kind == Kind.fence && line.level == 0 && line.lang == SHEET && col == length(b.lines[i])
    # The line that opens a sheet. Its first row starts with a place for a name.
    type!(e, "\n = ")
    b.caret = b.anchor = (i + 1, 0)
    return touch!(e)
  end
  if line.kind == Kind.fence && line.level == 0 && line.lang == SPREADSHEET && col == length(b.lines[i])
    # The line that opens a spreadsheet. Its first row starts with three cells, and the caret goes to the first.
    type!(e, "\n|  |  |  |")
    b.caret = b.anchor = (i + 1, 2)
    return touch!(e)
  end
  line.kind == Kind.fence && return type!(e, "\n")
  before = head(b.lines[i], col)
  type!(e, "\n" * match(r"^ *", before).match * (opens(before, line.lang) ? indentation(e, CodeBlock) : ""))
end

const OPENERS = r"^\s*(function|if|elseif|else|for|while|let|try|catch|finally|struct|mutable struct|module|macro|quote)\b"

"True when a line of code that ends with `text` opens a block, so the next line goes further in"
opens(text::AbstractString, lang::AbstractString) = begin
  s = rstrip(text)
  isempty(s) && return false
  last(s) in "([{" && return true
  lowercase(lang) in ("python", "py") && return last(s) == ':'
  lowercase(lang) in ("julia", "jl", LIVE, RESULT) || return false
  occursin(r"\b(begin|do( [\w, ]+)?)$", s) || (occursin(OPENERS, s) && !occursin(r"\bend$", s))
end

"Where backspace deletes back to from the caret: one character, or one step of `n` of the spaces that start a line"
backstep(b::Buffer, block, n=length(STEP)) = begin
  i, col = b.caret
  indented = col > 0 && !selecting(b) && all(==(' '), head(b.lines[i], col))
  indented ? (i, col - (col - 1) % n - 1) : beside(b, b.caret, -1)
end

# In a table the spaces belong to a cell
backstep(b::Buffer, ::Type{Table}, n=0) = beside(b, b.caret, -1)

# In code, a bracket that you type comes with the bracket that closes it, and
# the caret stays between the two. A quote comes with the quote that ends the
# string. This is so in a file of code and in a code block of a page.
#
#   - The closing one only comes where it can't join a word: at the end of the
#     line, or before a space, a comma or another closing bracket.
#   - A closing bracket or a quote that you type where the same one already is
#     goes over that one. So `f(x)` typed one key after another is `f(x)`.
#   - With text selected, a bracket or a quote goes round the text, and the
#     text stays selected.
#   - A quote that's typed in a string ends the string, and comes alone. A ' after
#     a name is Julia's transpose, or the ' of a word like "don't", and comes alone too.
#   - A third quote after two makes the six quotes of a string of several lines.
#   - ⌫ between the two of a pair that has nothing in it takes both away.

const PAIRS = Dict('(' => ')', '[' => ']', '{' => '}', '"' => '"', '\'' => '\'')
const CLOSING = Set(values(PAIRS))

"True when line `i` is code that's typed as text. A row of a sheet or a spreadsheet is typed as a cell."
typed_code(b::Buffer, i::Int) = (k = kinds(b)[i]; k.kind == Kind.code && k.lang != CELL_LANG && !insheet(b, i) && !inspread(b, i))

"How many quotes in `text` start or end a string. One after a \\ is a character of its string."
quotes(text::AbstractString) = count(r"(?<!\\)\"", text)

"True when line `i` up to `before` is inside a string of several lines: an odd number of \"\"\" come before it in its code"
in_long_string(b::Buffer, i::Int, before::AbstractString) = begin
  top = b.view == :code ? 1 : codeblock(b, i)[1] + 1
  isodd(sum(l -> count("\"\"\"", l), @view(b.lines[top:i-1]), init=0) + count("\"\"\"", before))
end

"""
Type the character `c` at the caret, as code does: a bracket or a quote comes
with the one that closes it. It returns false, and types nothing, where `c` is
typed as any other character is.
"""
pair!(e, c::Char) = begin
  b = e.buf
  picked(b) === nothing || return false
  lo, hi = minmax(b.caret, b.anchor)
  all(i -> typed_code(b, i), lo[1]:hi[1]) || return false
  close = get(PAIRS, c, nothing)
  if lo != hi
    # A bracket or a quote goes round the text that's selected, and the text stays selected
    close === nothing && return false
    back = b.caret < b.anchor
    edit!(b, lo, hi, c * excerpt(b, lo, hi) * close)
    from, to = (lo[1], lo[2] + 1), (hi[1], hi[2] + (lo[1] == hi[1]))
    b.anchor, b.caret = back ? (to, from) : (from, to)
    touch!(e)
    return true
  end
  i, col = lo
  before, after = head(b.lines[i], col), rest(b.lines[i], col)
  next = isempty(after) ? nothing : first(after)
  if next == c && c in CLOSING
    # The one that closes is already here, so the caret goes over it
    b.caret = b.anchor = (i, col + 1)
    touch!(e)
    return true
  end
  close === nothing && return false
  # Before a word, the one that closes would have to be moved to the word's end by hand
  roomy = next === nothing || isspace(next) || next in ")]},;:" || (c in "([{" && next == '"')
  roomy || return false
  if c == '"' && endswith(before, "\"\"") && !endswith(before, "\"\"\"")
    # The third quote of three. It starts a string of several lines, or it ends the one that the caret is in.
    in_long_string(b, i, chop(before, tail=2)) && return false
    close = "\"\"\""
  elseif c == '"'
    isodd(quotes(before)) && return false   # this quote ends a string
  elseif c == '\'' && !isempty(before)
    prev = last(before)
    (isnamechar(prev) || prev in ")]}'") && return false
  end
  edit!(b, lo, lo, c * close, typing=true)
  b.caret = b.anchor = (i, col + 1)
  touch!(e)
  true
end

"True when the caret is in code between a bracket or a quote and the one that closes it, with nothing between them"
in_empty_pair(b::Buffer) = begin
  i, col = b.caret
  line = b.lines[i]
  (!selecting(b) && 0 < col < length(line) && typed_code(b, i)) || return false
  at = nextind(line, 0, col)
  get(PAIRS, line[at], nothing) == line[nextind(line, at)]
end

# In code, the two brackets that the caret is between glow: the nearest ( [
# or { before the caret that's still open there, and the bracket that closes
# it. The two can be on different lines. Each has a soft light in its own
# shape, in the colour of a link, and two that touch have one light.
#
#   - A bracket in a string or a comment isn't one of the code's brackets. With
#     the caret in a string or a comment, the brackets are the ones in the
#     strings or the comments of the caret's line.
#   - A bracket that's closed by another kind of bracket doesn't glow.
#   - Nothing glows while text is selected.

const PAIR_REACH = 2000   # lines. A bracket that's further from the caret than this isn't looked for.
const OPENING, ENDING = "([{", ")]}"

"What each character of line `i` is a part of: :code, :string or :comment"
parts_of(b::Buffer, i::Int) = begin
  out = Symbol[]
  for t in tokens(b.lines[i], shared_lang(kinds(b)[i].lang))
    append!(out, fill(t.kind in (:string, :comment) ? t.kind : :code, length(t.text)))
  end
  out
end

"""
The places of the two brackets that the caret is between, in code: the one that
opens and the one that closes. Nothing when the caret isn't between two.
"""
bracket_pair(b::Buffer) = begin
  i, col = b.caret
  (!selecting(b) && picked(b) === nothing && typed_code(b, i)) || return nothing
  here = parts_of(b, i)
  col = min(col, length(here))   # a caret that a change left past the end of its line is at the end
  before = col > 0 ? here[col] : :code
  after = col < length(here) ? here[col+1] : before == :comment ? :comment : :code
  # At the edge of a string, the caret is in the code
  part = before == after ? before : :code
  top, bottom = b.view == :code ? (1, length(b.lines)) : codeblock(b, i) .+ (1, -1)
  top, bottom = part == :code ? (max(top, i - PAIR_REACH), min(bottom, i + PAIR_REACH)) : (i, i)
  # The characters of line `l` that are brackets of the caret's part, or nothing when it has none
  brackets(l) = begin
    any(in("()[]{}"), b.lines[l]) || return nothing
    parts = l == i ? here : parts_of(b, l)
    [(k, c) for (k, c) in enumerate(b.lines[l]) if (c in OPENING || c in ENDING) && parts[k] == part]
  end
  open = nothing
  closed = Char[]   # the brackets between the caret and here that close one before here
  for l in i:-1:top
    found = brackets(l)
    found === nothing && continue
    for (k, c) in Iterators.reverse(found)
      l == i && k > col && continue
      if c in ENDING
        push!(closed, c)
      elseif isempty(closed)
        open = (l, k - 1, c)
        break
      elseif closed[end] == PAIRS[c]
        pop!(closed)
      end
    end
    open === nothing || break
  end
  open === nothing && return nothing
  opened = Char[]   # what closes the brackets that open between the caret and here
  for l in i:bottom
    found = brackets(l)
    found === nothing && continue
    for (k, c) in found
      l == i && k <= col && continue
      if c in OPENING
        push!(opened, PAIRS[c])
      elseif isempty(opened)
        return c == PAIRS[open[3]] ? ((open[1], open[2]), (l, k - 1)) : nothing
      elseif opened[end] == c
        pop!(opened)
      end
    end
  end
  nothing
end

"What a window keeps of the brackets that the caret is between"
@def mutable struct BracketsState
  pair::Union{Nothing,Tuple} = nothing   # the text and the place of the caret that the brackets were last looked for at, and what was found
end

"The two brackets that the caret is between. They're looked for once for each place of the caret in each version of the text."
caret_pair(e) = begin
  b = e.buf
  key = (b.path, b.version, b.caret, b.anchor)
  s = state_of(e, BracketsState)
  kept = s.pair
  kept !== nothing && kept[1] == key && return kept[2]
  found = bracket_pair(b)
  s.pair = (key, found)
  found
end

"""
The runs of text that glow for the two brackets at `found`: the line of each,
and its columns. Two brackets with nothing between them are one run, so they
have one light.
"""
bracket_runs((open, close)) =
  open[1] == close[1] && close[2] == open[2] + 1 ? [(open[1], open[2], open[2] + 2)] : [(i, col, col + 1) for (i, col) in (open, close)]

"""
Make the two brackets that the caret is between glow: a soft light in the shape
of each bracket, and the bracket over it in the light's colour. The page's text
is at `ui`.
"""
glow_bracket_pair(ctx, e, ui) = begin
  b = e.buf
  (caretless(b) || readonly(b)) && return
  w = window_of(e)
  (w !== nothing && w.focus === e) || return   # as the caret does, the light shows while the page has the keyboard
  found = caret_pair(e)
  found === nothing && return
  light, lit = ink(tint(colours.accent, 0.65)), ink(colours.accent)
  blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 3f0, true)
  Skia.sk_paint_set_maskfilter(light, blur)
  for it in e.layout[e.shown], (i, from, to) in bracket_runs(found)
    f = it.content
    (f isa Flow && it.first == i) || continue
    for (k, vl) in enumerate(f.lines), seg in vl.segs
      lo, hi = max(from, seg.col), min(to, seg.col + seg.n)
      (hi > lo && seg.node === nothing && !seg.atomic) || continue
      words = String(collect(seg.text)[lo-seg.col+1:hi-seg.col])
      x = num(ui.left + seg.x + inset(seg, lo - seg.col))
      # The brackets stand on the line that the text stands on
      y = num(ui.top + it.top + line_top(f, k) + (vl.high + capital(seg.face)) / 2)
      blob = Skia.sk_textblob_make_from_string(words, skia_font(seg.face.family, seg.face.size, seg.face.style).raw, Skia.SK_TEXT_ENCODING_UTF8)
      # The light is drawn twice, since a bracket is thin
      for paint in (light, light, lit)
        Skia.sk_canvas_draw_text_blob(ctx, blob, Float32(x), Float32(y), paint)
      end
      Skia.sk_textblob_unref(blob)
    end
  end
  Skia.sk_maskfilter_unref(blur)
  Skia.sk_paint_delete(light)
  Skia.sk_paint_delete(lit)
end

"Tab moves text in, and shift-Tab moves it back out. What they move depends on the block the caret is in."
indent!(e, out::Bool) = begin
  b = e.buf
  insheet(b, b.caret[1]) && return sheet_tab!(e, out)
  isempty(rowcells(b, b.caret)) || return next_cell!(e, out)
  indent!(e, out, block(b, b.caret[1]))
end

indent!(e, out::Bool, block) = out ? nothing : type!(e, STEP)

# In code, Tab goes to the next step. With a selection, or with shift, it moves every line the selection touches.
indent!(e, out::Bool, ::Type{CodeBlock}) = begin
  b = e.buf
  tab = indentation(e, CodeBlock)   # as many spaces as the settings page says
  out || selecting(b) || return type!(e, " " ^ (length(tab) - b.caret[2] % length(tab)))
  shift_lines!(e, out, tab, ==(Kind.code))
end

"""
Move each line that the caret or the selection is on in by `step`, or with
`out` back out by as much of `step` as it starts with. Only the lines whose
kind `takes` move, and a line with nothing in it stays as it is.
"""
shift_lines!(e, out::Bool, step::AbstractString, takes) = begin
  b = e.buf
  ends = Dict(:caret => b.caret, :anchor => b.anchor)
  lo, hi = minmax(b.caret, b.anchor)
  for i in lo[1]:hi[1]
    takes(kinds(b)[i].kind) || continue
    n = out ? min(length(step), length(match(r"^ *", b.lines[i]).match)) : length(step)
    (isempty(b.lines[i]) || n == 0) && continue
    edit!(b, (i, 0), (i, out ? n : 0), out ? "" : step)
    for (name, (l, col)) in ends
      l == i && (ends[name] = (i, max(0, col + (out ? -n : n))))
    end
  end
  b.caret, b.anchor = ends[:caret], ends[:anchor]
  touch!(e)
end

"""
What ⌘] and ⌘[ do: they move the lines that the caret or the selection is on
in or out a step, wherever the caret is in the line. In code a step is the
indent that the settings page gives, and in a list it's a level of the list.
"""
indent_lines!(e, out::Bool) = begin
  b = e.buf
  t = block(b, b.caret[1])
  t === CodeBlock ? shift_lines!(e, out, indentation(e, CodeBlock), ==(Kind.code)) :
  t === List ? shift_lines!(e, out, STEP, in((Kind.bullet, Kind.ordered, Kind.todo))) : nothing
end

# ⌘] and ⌘[ have a use only on a page that you can change. On one that you can't, the keys go to another
# command that has them, if code from the startup page added one. See `command_here`.
works_here(e, ::Union{Val{:indent_line},Val{:outdent_line}}) = !readonly(e.buf) && !e.buf.fixed

# In a list, Tab moves the item in and shift-Tab moves it back out
indent!(e, out::Bool, ::Type{List}) = begin
  b = e.buf
  i, col = b.caret
  selecting(b) && return out ? nothing : type!(e, STEP)
  n = out ? min(2, kinds(b)[i].level) : 2
  edit!(b, (i, 0), (i, out ? n : 0), out ? "" : "  ")
  b.caret = b.anchor = (i, max(0, col + (out ? -n : n)))
  touch!(e)
end

"""
Go to the next cell of a table and select what's in it, or with `back` the one
before. With `down`, go to the same cell of the next row. Going on from the end
of the table adds a row.
"""
next_cell!(e, back::Bool; down=false) = begin
  b = e.buf
  i, col = b.caret
  rows = gridrows(b, i)
  r = findfirst(==(i), rows)
  cs = rowcells(b, b.caret)
  c = nearest(cs, col)
  if down
    r += 1
  elseif back
    c -= 1
    c < 1 && (r -= 1; c = 0)
  else
    c += 1
    c > length(cs) && (r += 1; c = 1)
  end
  r < 1 && return
  if r > length(rows)
    t = last(rows)
    edit!(b, line_end(b, t), line_end(b, t), "\n|" * repeat("  |", maximum(i -> length(rowcells(b, (i, 0))), rows)))
    push!(rows, t + 1)
  end
  cs = rowcells(b, (rows[r], 0))
  isempty(cs) && return move!(e, (rows[r], 0), false)
  cell = cs[c == 0 ? length(cs) : min(c, length(cs))]
  b.anchor, b.caret = (rows[r], cell.lo), (rows[r], cell.hi)
  touch!(e)
end

"Put `mark` around the selection, or take it away if it's there already"
surround!(e, mark::String) = begin
  b = e.buf
  picked(b) === nothing || return
  lo, hi = selection(b)
  lo[1] == hi[1] || return
  if rich(b)
    # As rich text, each end of a selection can be on either side of markup that doesn't show. A selection
    # of all the text that `mark` marks is that text, whichever side its ends are on.
    _, ss = richspans(b, lo[1])
    hidden = unseen(b, lo[1])
    for (o, c) in markpairs(ss)
      ss[o].text == mark || continue
      from, to = ss[o].col + length(mark), ss[c].col
      opens = findfirst(r -> r[1] <= ss[o].col && from <= r[2], hidden)
      closes = findfirst(r -> r[1] <= to && to + length(mark) <= r[2], hidden)
      (opens === nothing || closes === nothing) && continue
      hidden[opens][1] <= lo[2] <= hidden[opens][2] && hidden[closes][1] <= hi[2] <= hidden[closes][2] || continue
      lo, hi = (lo[1], from), (hi[1], to)
      break
    end
  end
  i, n = lo[1], length(mark)
  line = b.lines[i]
  inner = rest(head(line, hi[2]), lo[2])
  if lo[2] >= n && rest(head(line, lo[2]), lo[2] - n) == mark && head(rest(line, hi[2]), n) == mark
    edit!(b, (i, lo[2] - n), (i, hi[2] + n), inner)
    b.anchor, b.caret = (i, lo[2] - n), (i, hi[2] - n)
  else
    edit!(b, lo, hi, mark * inner * mark)
    b.anchor, b.caret = (i, lo[2] + n), (i, hi[2] + n)
  end
  touch!(e)
end

"""
Copy what's selected. With several selections, each one's text goes on a line
of its own, in the order of the page. With none, the part that the caret is on
as a whole, like a board or a picture, is copied as its lines. A whole block
pastes in another page as a part of this one: see "a block that's copied
pastes as a part of its page".
"""
copy_selection!(e) = begin
  b = e.buf
  run = picked(b)
  (selecting(b) || run !== nothing) && write_blocks!(e)   # a block that a file defines is copied as what it holds now
  spans = selecting(b) ? [selection(b)] : Tuple{Pos,Pos}[]
  with_others(() -> selecting(b) && push!(spans, selection(b)), b)
  isempty(spans) && run !== nothing && push!(spans, ((run[1], 0), line_end(b, run[2])))
  isempty(spans) && return false
  text = join((excerpt(b, s...) for s in sort(spans)), "\n")
  copied!(e, length(spans) == 1 ? only(spans) : nothing, text)
  copy_text!(e, text)
end

"""
Put what the clipboard holds into the text at the caret. Files that were
copied in the Finder go in the way a dropped file does: a picture shows as a
picture, and a video, a sound, a PDF or any other file as a path that shows
what's in the file. A picture that was copied as itself, like a screenshot, is
written to a file in the media folder beside the document first. So is a PDF,
a sound or a video that was copied as itself. Anything else is pasted as text.

A file in a folder for temporary files is copied to that media folder,
and the copy is what goes in. An app that takes screenshots puts its picture
on the clipboard as a file like that, and macOS removes the file later.
"""
paste!(e) = begin
  part = owner_of(e)
  part isa PaneField && return paste_for_agent!(part.pane, e)
  b = e.buf
  paths = Pasteboard.files()
  if isempty(paths)
    text = Sys.isapple() ? Pasteboard.text() : clipboard()
    # A whole block that was copied from another page goes in as a part of that page
    link = pasted_part(e, text)
    link === nothing || return paste_part!(e, link)
    # A contact that was copied in the Contacts app goes in as a block of contacts
    list = copied_contacts(e, text)
    isempty(list) || return paste_contacts!(e, list)
    # A picture that's copied from a web page comes with its address as text, and the picture is what's wanted
    found = isempty(strip(text)) || occursin(r"^\s*\w+://\S+\s*$", text) ? Pasteboard.media() : nothing
    path = found === nothing ? nothing : keep_pasted(e, found...)
    path === nothing && return each_selection!(() -> type!(e, replace(text, "\r\n" => "\n", '\r' => '\n', '\t' => "  ")), e)
    paths = [path]
  end
  paths = [passing(e, p) ? something(keep_copy(e, p), p) : p for p in paths]
  selecting(b) && type!(e, "")
  put_files!(e, paths, settle(b, b.caret))
end





"A path in `dir` that no file has yet: `stem` and `ext`, with a number after the stem if that name is taken"
unused(dir, stem, ext) = begin
  path = joinpath(dir, stem * ext)
  n = 1
  while ispath(path)
    path = joinpath(dir, "$stem-$(n += 1)$ext")
  end
  path
end





zoom!(e, z) = (e.zoom = clamp(z, 0.6, 2.5); save_settings!(e); rerun!(e, :zoom); restyle!(e))

"The size of the page's text, to the nearest pixel"
text_size(e) = round(Int, TEXT_SIZE.value * e.zoom)
# The page's text is a whole number of pixels tall, so the settings page can show its size as a number
"The zoom that makes the page's text `size` pixels tall. Sizes are whole numbers from 11 to 42."
zoom_for(size) = clamp(round(Int, size), 11, 42) / TEXT_SIZE.value

"The one after `x` in `list`, going back to the start after the last"
after(list, x) = list[mod1(findfirst(==(x), list) + 1, length(list))]

const SLIDE_TIME = 0.25   # seconds for the sidebar to slide in or out

"""
Show the sidebar if it's hidden, or hide it. It slides from where it is now.
In agent mode it's at the left of the agent's pane, and the window grows by
its width where the screen has room: see `sidebar_room!`.
"""
toggle_panel!(e) = begin
  e.slid_from = opened(e)
  e.slid = time()
  e.panel = !e.panel
  agent_shows(e) && sidebar_room!(e)
  e.panel
end

"""
In agent mode, make the window of `e` wider by the sidebar's width as the
sidebar opens, at the window's left edge. So the agent's pane and the page's
card keep their widths, and they stay where they are on the screen, as far
as the screen allows. As the sidebar closes, the window gives back what it
grew by. The sidebar is then there or gone at once, with no slide, as the
window's new size is. A window that can't grow, like one that fills a
screen, stays as it is: there the pane and the card give the sidebar its room.
"""
sidebar_room!(e) = begin
  w = window_of(e)
  (w === nothing || e.full_screen) && return nothing
  wide, tall = w.size
  x, y = w.position
  if e.panel
    screen = w.screen
    grow = px(round(num(clamp(screen.size[1] - wide, 0px, clamp(e.side, PANEL_MIN, PANEL_MAX)))))
    grow > 0px || return nothing
    left = px(round(num(clamp(x - grow, screen.position[1], max(screen.position[1], screen.position[1] + screen.size[1] - wide - grow)))))
    state_of(e, AgentMode).grew = (grew=grow, moved=left - x)
    w.position = typeof(w.position)(left, y)
    w.size = typeof(w.size)(wide + grow, tall)
  else
    mode = state_of(e, AgentMode)
    was, mode.grew = mode.grew, nothing
    was === nothing && return nothing
    w.size = typeof(w.size)(max(wide - was.grew, 400px), tall)
    w.position = typeof(w.position)(x - was.moved, y)
  end
  e.slid = 0.0
  empty!(e.flows)   # the page's text is as wide as its new place allows
  nothing
end

sliding(e) = time() - e.slid < SLIDE_TIME

"How far a slide from `from` to `to` that started at the time `at` has gone. It takes `take` seconds."
eased(from, to, at; take=SLIDE_TIME) = begin
  t = (time() - at) / take
  t < 1 || return to
  t = t < 0.5 ? 4t^3 : 1 - (2 - 2t)^3 / 2   # slow at the start and the end
  from + (to - from) * t
end

"How far the sidebar is open, from 0 to 1"
opened(e) = eased(e.slid_from, e.panel ? 1.0 : 0.0, e.slid)

"Do `f` with each of the other selections in the main one's place, then put the main one back. It's for drawing them."
with_others(f, b::Buffer) = begin
  list = copy(others(b))
  isempty(list) && return
  main, many = (b.anchor, b.caret), b.many
  b.many = true
  try
    for s in list
      b.anchor, b.caret = s
      f()
    end
  finally
    b.anchor, b.caret = main
    b.many = many
  end
end
