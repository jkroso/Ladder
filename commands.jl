# Commands and their keys: the key bindings, the commands for whole lines, what code from the startup page adds, and functions that are commands
#
# Each thing that a key does is a command with a name. COMMANDS has them all,
# and the key bindings page lists them in COMMAND_GROUPS. add_command! makes a
# function a command of the command palette: additions.jl has it, and each
# file adds its own commands with it.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor hide_menu!
@use "./markdown" Kind MATH
@use "./sheet" parts
@use "./spreadsheet" letters
@use "./pasteboard" => Pasteboard
"""
True while Ladder is built into an app (see app/bundle.jl). Kip then loads
each file as it's built, and never compiles a copy of it to keep.
"""
const BUILDING_APP = haskey(ENV, "KIP_FROZEN") && ccall(:jl_generating_output, Cint, ()) == 1
# The layout inspector is a tool for working on Ladder's layout, so the app
# that's built leaves it out. Its @use line stays on a line of its own, where Kip finds it.
if !BUILDING_APP
  @use "github.com/jkroso/UI.jl/Interface/inspector" toggle_inspector!
end
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
@use "./views" exports...
@use "./takeoff_view" exports...
@use "./julia_levels" exports...
@use "./csv_view" exports...
@use "./fill_view" exports...
@use "./sheet_view" exports...
@use "./live_view" exports...
@use "./long_file" exports...
@use "./schedule_view" exports...
@use "./timelog_view" exports...
@use "./slides_view" exports...
@use "./run_code" exports...
@use "./module_view" exports...
@use "./code_names" exports...
@use "./design_view" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...
@use "./agent/kinds" exports...
@use "./agent/page" exports...
@use "./agent/pane" exports...
@use "./agent/ask" exports...
@use "./table_bar" exports...
@use "./showed_before" exports...
@use "./page_mouse" exports...
@use "./copied_blocks" exports...
@use "./editing" exports...
@use "./page_menu" exports...
@use "./printing" exports...
@use "./tabs" exports...

export ADDED_ORDER, AT_EACH, AgentChoice, BUILDING_APP, BUNDLES, Bundle, COMMANDS,
       COMMAND_GROUPS, COMMENT_MARKS, Colours, FIELD_KEYS, HOLDS, InsertKind, KEY_NAMES,
       KEY_OF, KEY_ROW_H, KEY_SIGNS, KeyList, KeyReset, KeyRow, PAGE_NAMES, SETTINGS_FOLDERS,
       Shortcut, Stroke, TAB_ORDINALS, TYPING_KEYS, TabCommand,
       add_insert!, bundle!, bundle_keys, caps, caret_number, caret_page!, caret_step!,
       caret_value, caret_word, clashes, command!, command_here, duplicate_lines!, erase_back!,
       erase_line_end!, erase_next!, erase_start!, findfirst_here, follow_lines!, in_order!,
       insert_block!, key_asking, key_bindings!, key_does!, keycap, keys!, keys_now, lost_note!,
       move_lines!, number_plus, pressed!, put_commands!, read_shortcuts, read_stroke, rebind!,
       select_lines!, select_next!, select_word!, side_button!, step_value!, stop_asking_keys!,
       switch_agent!, toggle_comment!, touched, typing_key, with_added, TreeTook, tree_took!, KeysState, KeysAsked

# --- key bindings ------------------------------------------------------------------------
#
# Each thing that a key does is a command with a name, like `:save`. A shortcut
# is the keys that run a command: one key with the keys that are held with it,
# like ⌘S, or two of those pressed one after the other, like ⌃X ⌃S. A bundle
# gives every command its shortcuts. Ladder starts with the bundle called
# "Ladder". Each other bundle has the keys of another editor. The key bindings
# page of the settings chooses the bundle, and gives any one command another
# shortcut. The bundle and those changes are settings: every window has the
# same keys, and the settings file keeps them.
#
# A command's kind says where it works:
#   :window  whatever has the keyboard, and on a file that's only shown
#   :look    while the text has the keyboard, and on a file that's only shown as text
#   :edit    while the text has the keyboard. It changes the text.
#   :move    it moves the caret. With ⇧ held too, it grows the selection.
#   :type    it changes the text at the caret, like ⌫. While the page is read it does nothing.
#
# Return, esc and Space have no command. What each does depends on where the caret is.

"A key, and the keys of ⌃, ⌘, ⌥ and ⇧ that are held with it"
struct Stroke
  held::Keys
  key::Keys
end

"The keys that run a command: one stroke, or two that are pressed one after the other"
const Shortcut = Tuple{Vararg{Stroke}}

"What a window keeps of its key bindings and of the keys that were just pressed, between frames"
@def mutable struct KeysState
  # The key bindings as `keys_now` last made them, with the bundle, the changed shortcuts and the count of commands that they were made for
  made::Union{Nothing,@NamedTuple{bundle::String, rebound::Dict{Symbol,String}, of::Dict{Symbol,Vector{Shortcut}}, commands::Dict{Shortcut,Symbol},
                                  also::Dict{Shortcut,Vector{Symbol}}, starts::Set{Stroke}, count::Int}} = nothing
  stroke::Union{Nothing,Stroke} = nothing   # the first key of a shortcut of two, while the window waits for the second
  mute::Float64 = 0.0                       # when a key that types a character ran a command, so that its character is dropped
  stepped::Int = -1                         # the version of the text after `step_value!` last changed it
end

"What a window keeps of the key bindings page while you give a command new keys"
@def mutable struct KeysAsked
  asking::Union{Nothing,Symbol} = nothing   # the command whose row waits for new keys
  note::Tuple{Symbol,String} = (:none, "")  # a command, and what the list says under its row: see `lost_note!`
  refused::Union{Nothing,String} = nothing  # why the row didn't take the keys that were pressed, in words
end

# The keys that are held with another key: the name that the settings file has for each, and the Mac's sign for it
const HOLDS = ((Keys.ctrl, "ctrl", "⌃"), (Keys.cmd, "cmd", "⌘"), (Keys.opt, "opt", "⌥"), (Keys.shft, "shift", "⇧"))
"Each key that a shortcut can have, by the name that the settings file has for it, like \"z\", \"f5\" or \"pageup\""
const KEY_NAMES = Dict{String,Keys}(lstrip(string(name), '_') => getproperty(Keys, name) for name in keys(instances(Keys))
                                    if !(name in (:shft, :cmd, :opt, :ctrl, :capslock, :fn, :mouse_left, :mouse_right, :mouse_middle, :mouse_back, :mouse_forward)))
const KEY_OF = Dict{Keys,String}(key => name for (name, key) in KEY_NAMES)

"What the key bindings page shows for a key that isn't a letter, a number or an F key"
const KEY_SIGNS = Dict{Keys,String}(
  Keys.enter => "Return", Keys.tab => "Tab", Keys.space => "Space", Keys.backspace => "⌫", Keys.delete => "⌦", Keys.escape => "esc",
  Keys.left => "←", Keys.right => "→", Keys.up => "↑", Keys.down => "↓",
  Keys.home => "Home", Keys._end => "End", Keys.pageup => "Page Up", Keys.pagedown => "Page Down",
  Keys.tilde => "`", Keys.minus => "-", Keys.equal => "=", Keys.left_bracket => "[", Keys.right_bracket => "]", Keys.semicolon => ";",
  Keys.apostrophe => "'", Keys.comma => ",", Keys.period => ".", Keys.slash => "/", Keys.backslash => "\\", Keys.plus => "+", Keys.times => "*")

const TYPING_KEYS = ("tilde", "minus", "equal", "left_bracket", "right_bracket", "semicolon", "apostrophe", "comma", "period", "slash",
                     "backslash", "times", "plus", "space")

"True when the key `K` types a character: a letter, a number or a sign. A shortcut with it needs ⌘, ⌃ or ⌥ too."
typing_key(K) = (name = get(KEY_OF, K, ""); length(name) == 1 || startswith(name, "num") || name in TYPING_KEYS)

"The stroke that `text` writes, like \"cmd+shift+z\", or nothing when it writes none"
read_stroke(text::AbstractString) = begin
  parts = split(text, '+')
  key = get(KEY_NAMES, last(parts), nothing)
  key === nothing && return nothing
  held = Keys(0)
  for part in parts[1:end-1]
    i = findfirst(h -> h[2] == part, HOLDS)
    i === nothing && return nothing
    held |= HOLDS[i][1]
  end
  Stroke(held, key)
end

"The shortcuts that `text` writes, with a comma between them, like \"cmd+z, ctrl+x u\". One that can't be read is left out."
read_shortcuts(text::AbstractString) = begin
  out = Shortcut[]
  for part in split(text, ','; keepempty=false)
    strokes = map(read_stroke, split(part))
    (isempty(strokes) || length(strokes) > 2 || any(isnothing, strokes)) && continue
    push!(out, Tuple(strokes))
  end
  out
end

"How the settings file writes a stroke, a shortcut or a command's shortcuts. `read_shortcuts` reads it back."
written(s::Stroke) = join([[name for (key, name, _) in HOLDS if key in s.held]; KEY_OF[s.key]], '+')
written(s::Shortcut) = join(map(written, s), ' ')
written(list::Vector{Shortcut}) = join(map(written, list), ", ")

"How a stroke or a shortcut reads, like ⌘⇧Z or ⌃X ⌃S"
caps(s::Stroke) = join([sign for (key, _, sign) in HOLDS if key in s.held]) * get(() -> uppercase(KEY_OF[s.key]), KEY_SIGNS, s.key)
caps(s::Shortcut) = join(map(caps, s), ' ')

# A `Command` is something that a key does: its name, what the key bindings page calls it, its kind, its
# keys in the bundle called Ladder, and what it does. additions.jl has the type.

"Move the caret one character left or right. With a selection and no ⇧, it goes to that end of the selection."
caret_step!(e, by::Int, select::Bool) = begin
  b = e.buf
  lo, hi = selection(b)
  move!(e, selecting(b) && !select ? (by < 0 ? lo : hi) : beside(b, b.caret, by), select; by)
end

"Move the caret most of a screen up or down"
caret_page!(e, by::Int, select::Bool) = foreach(_ -> move!(e, vertical(e, by), select; keep_goal=true, by), 1:20)

"What ⌫ does: it takes away a row of a table that has nothing in it, or what's before the caret"
erase_back!(e) = begin
  b = e.buf
  picked(b) === nothing || return delete_lines!(e)   # the part that the caret is on as a whole goes
  emptyrow(b) && return backrow!(e)
  erase_start!(e) && return
  if in_empty_pair(b)
    # The bracket that closes goes with the bracket that it came with
    i, col = b.caret
    b.anchor, b.caret = (i, col - 1), (i, col + 1)
    return type!(e, "")
  end
  blk = block(b, b.caret[1])
  erase!(e, backstep(b, blk, length(indentation(e, blk))))
end

"""
What ⌫ does in rich text when the caret is at the start of a line's text. It
returns true when it did it, and false when the caret is somewhere else.

- In a heading, a list item or a quote, it makes the line a paragraph. An item
  of a list inside a list goes out a step first.
- After a part that shows as one thing, like a diagram or a picture, it takes
  away a line with nothing on it. A line with text stays. Either way the caret
  goes onto the part, and ⌫ again takes the part away.
"""
erase_start!(e) = begin
  b = e.buf
  (rich(b) && !selecting(b)) || return false
  i, col = b.caret
  line = kinds(b)[i]
  hidden = unseen(b, i)
  if !isempty(hidden) && first(hidden)[1] < 0 && col <= first(hidden)[2]
    n = line.kind in (Kind.bullet, Kind.ordered, Kind.todo) && line.level >= 2 ? 2 : richspans(b, i)[1]
    edit!(b, (i, 0), (i, n), "")
    b.caret = b.anchor = (i, max(0, col - n))
    touch!(e)
    return true
  end
  at = something(findfirst(r -> r[1] < col <= r[2], hidden), 0)
  (at == 0 ? col : hidden[at][1]) == 0 && i > 1 && !free(b, i - 1, i) || return false
  if isempty(b.lines[i]) && line.kind != Kind.code
    edit!(b, line_end(b, i - 1), (i, 0), "")
    b.caret = b.anchor = settle(b, line_end(b, i - 1), -1, from=(0, 0))
  else
    return (move!(e, line_end(b, i - 1), false, by=-1); true)
  end
  touch!(e)
  true
end

"""
What ⌦ does: it takes away what's after the caret. As rich text, at the end of
a line it joins the next line's text to it, without what starts that line.
"""
erase_next!(e) = begin
  b = e.buf
  picked(b) === nothing || return delete_lines!(e)   # the part that the caret is on as a whole goes
  to = beside(b, b.caret, 1)
  if rich(b) && !selecting(b) && to[1] > b.caret[1]
    j = to[1]
    # The caret goes onto a part that comes next, and ⌦ again takes that part away. It stays before a ``` line.
    free(b, j, b.caret[1]) || return part(b, j) === nothing ? nothing : move!(e, to, false, by=1)
    to = (j, first_stop(b, j))
  end
  erase!(e, to)
end

"Take away the rest of the caret's line. At the end of a line, it joins the next line to it."
erase_line_end!(e) = (b = e.buf; at = line_end(b, b.caret[1]); at == b.caret ? erase_next!(e) : erase!(e, at))

# --- commands for whole lines ---

"The first and last line that the selection touches. A selection that ends at the start of a line doesn't touch that line."
touched(b::Buffer) = begin
  run = picked(b)
  run === nothing || return run   # all the lines of the part that the caret is on as a whole
  lo, hi = minmax(b.caret, b.anchor)
  (lo[1], hi[2] == 0 && hi[1] > lo[1] ? hi[1] - 1 : hi[1])
end

"Put the caret at `caret` and the other end of the selection at `anchor`, each `by` lines further down, after their lines moved"
follow_lines!(e, caret::Pos, anchor::Pos, by::Int) = begin
  b = e.buf
  place((i, col)) = i + by > length(b.lines) ? line_end(b, length(b.lines)) : (max(1, i + by), min(col, length(b.lines[max(1, i + by)])))
  b.caret, b.anchor = place(caret), place(anchor)
  touch!(e)
end

"Take away each line that the selection touches"
delete_lines!(e) = begin
  b = e.buf
  s, t = touched(b)
  col = b.caret[2]
  if t < length(b.lines)
    edit!(b, (s, 0), (t + 1, 0), "")
  elseif s > 1
    edit!(b, line_end(b, s - 1), line_end(b, t), "")
  else
    edit!(b, (1, 0), line_end(b, t), "")
  end
  i = min(s, length(b.lines))
  # The caret comes to the line afresh, so in rich text it isn't left on a line that doesn't show
  b.caret = b.anchor = settle(b, (i, min(col, length(b.lines[i]))), 1, from=(0, 0))
  touch!(e)
end

"Put a copy of the lines that the selection touches under them. The caret goes to the copy."
duplicate_lines!(e) = begin
  b = e.buf
  s, t = touched(b)
  caret, anchor = b.caret, b.anchor
  edit!(b, line_end(b, t), line_end(b, t), "\n" * join(b.lines[s:t], "\n"))
  follow_lines!(e, caret, anchor, t - s + 1)
end

"Move the lines that the selection touches one line up or down"
move_lines!(e, by::Int) = begin
  b = e.buf
  s, t = touched(b)
  caret, anchor = b.caret, b.anchor
  if by < 0
    s > 1 || return
    edit!(b, (s - 1, 0), line_end(b, t), join([b.lines[s:t]; b.lines[s-1]], "\n"))
  else
    t < length(b.lines) || return
    edit!(b, (s, 0), line_end(b, t + 1), join([b.lines[t+1]; b.lines[s:t]], "\n"))
  end
  follow_lines!(e, caret, anchor, by)
end

"Select the whole of the caret's line. With a selection, it grows to the end of its last line. Again, it takes the next line too."
select_lines!(e) = begin
  b = e.buf
  lo, hi = minmax(b.caret, b.anchor)
  b.anchor = (lo[1], 0)
  move!(e, hi[1] < length(b.lines) ? (hi[1] + 1, 0) : line_end(b, hi[1]), true; by=1)
end

"""
Do `f` at each selection: at the main one, then at each of the others with it
in the main one's place. An edit that one of them makes moves the ones after
it, and one ⌘Z takes back what they all did.
"""
each_selection!(f, e) = begin
  b = e.buf
  n = length(others(b))
  (n == 0 || b.many) && return f()
  undos = length(b.undo)
  b.many = true
  try
    for _ in 0:n
      f()
      # The main selection goes to the back of the queue, and the next one takes its place
      push!(b.others, (b.anchor, b.caret))
      b.anchor, b.caret = popfirst!(b.others)
    end
  finally
    b.many = false
  end
  length(b.undo) > undos + 1 && resize!(b.undo, undos + 1)
  # Two selections that came to the same place are one
  kept = Tuple{Pos,Pos}[]
  for s in b.others
    clash(s, (b.anchor, b.caret)) || any(k -> clash(s, k), kept) || push!(kept, s)
  end
  b.others = kept
  keep_others!(b)
  nothing
end

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

"The columns of each place in `line` that has `text`. With `whole`, only where it's a word by itself."
places(line::AbstractString, text::AbstractString, whole::Bool) = begin
  out = Tuple{Int,Int}[]
  at = firstindex(line)
  while (r = findnext(text, line, at)) !== nothing
    before, after = prevind(line, first(r)), nextind(line, last(r))
    if whole && ((before >= 1 && isword(line[before])) || (after <= ncodeunits(line) && isword(line[after])))
      at = nextind(line, first(r))
      continue
    end
    lo = length(line, 1, before)
    push!(out, (lo, lo + length(text)))
    at = after
  end
  out
end

"""
Select the next place that has the text of the selection as well, and go to
it. After the end of the page it looks from the top. Text that is one word is
found only where it's a word by itself. A live block's own text isn't looked at.
"""
select_next!(e) = begin
  b = e.buf
  lo, hi = selection(b)
  (lo != hi && lo[1] == hi[1]) || return
  text = excerpt(b, lo, hi)
  whole = all(isword, text)
  taken = [(b.anchor, b.caret); others(b)]
  found = [((i, from), (i, to)) for i in eachindex(b.lines) for (from, to) in places(b.lines[i], text, whole)]
  for s in [filter(s -> s[1] >= hi, found); filter(s -> s[1] < lo, found)]
    (any(t -> clash(s, t), taken) || item(e, s[1][1]).content isa Live) && continue
    push!(b.others, (b.anchor, b.caret))
    b.anchor, b.caret = s
    keep_others!(b)
    return
  end
end

"""
Select the word that the caret is in or beside. With a selection, each end of
it goes out to the edge of the word that it's in. With whole words selected
already, the next place that has the same text is selected as well, so what's
typed next goes in at each of them. With no word at the caret, nothing changes.

The selection that was there first stays first in `others`, so Escape can go
back to it.
"""
select_word!(e) = begin
  b = e.buf
  grew = Ref(false)
  each_selection!(e) do
    lo, hi = selection(b)
    from = (lo[1], word_at(b.lines[lo[1]], lo[2])[1])
    to = (hi[1], word_at(b.lines[hi[1]], hi[2])[2])
    (from, to) == (lo, hi) && return
    b.anchor, b.caret = from, to
    grew[] = true
  end
  grew[] || select_next!(e)
  touch!(e)
end

"What starts a comment in each language of code, by the language's name or the end of its file's name"
const COMMENT_MARKS = Dict{String,String}(
  (lang => "#" for lang in ("jl", "julia", "ui", "py", "python", "rb", "ruby", "sh", "bash", "zsh", "fish", "toml", "yaml", "yml", "r", "perl", "pl", "make", "dockerfile"))...,
  (lang => "//" for lang in ("js", "javascript", "jsx", "ts", "typescript", "tsx", "c", "h", "cpp", "hpp", "cc", "java", "swift", "rs", "rust", "go", "kt", "kotlin",
                             "scala", "cs", "php", "dart", "zig"))...,
  (lang => "--" for lang in ("lua", "sql", "hs", "haskell", "elm"))...,
  (lang => ";" for lang in ("lisp", "el", "clj", "clojure", "scm", "scheme"))...,
  (lang => "%" for lang in ("tex", "latex", MATH, "erl", "erlang"))..., "mermaid" => "%%")

"""
Make a comment of each line of code that the selection touches, or make code
of them again if each is a comment already. A line with nothing on it stays
as it is. Outside code, where a comment has no mark, nothing changes.
"""
toggle_comment!(e) = begin
  b = e.buf
  picked(b) === nothing || return
  s, t = touched(b)
  ks = kinds(b)
  lines = [i for i in s:t if ks[i].kind == Kind.code && !isempty(strip(b.lines[i]))]
  isempty(lines) && return
  mark = get(COMMENT_MARKS, lowercase(ks[first(lines)].lang), nothing)
  mark === nothing && return
  indent(i) = length(b.lines[i]) - length(lstrip(b.lines[i]))
  on = all(i -> startswith(lstrip(b.lines[i]), mark), lines)
  at = minimum(indent, lines)   # every mark goes at the indent of the line that's furthest out
  ends = Dict(:caret => b.caret, :anchor => b.anchor)
  new = b.lines[s:t]
  for i in lines
    line = b.lines[i]
    from = on ? indent(i) : at
    # A comment's mark has a space after it, which goes with the mark
    n = !on ? length(mark) + 1 : length(mark) + (startswith(rest(line, from + length(mark)), " ") ? 1 : 0)
    new[i-s+1] = on ? head(line, from) * rest(line, from + n) : head(line, from) * mark * " " * rest(line, from)
    for (name, (l, col)) in ends
      l == i && (ends[name] = (i, on ? (col > from ? max(from, col - n) : col) : (col >= from ? col + n : col)))
    end
  end
  # One change, so one ⌘Z puts every line back
  edit!(b, (s, 0), line_end(b, t), join(new, "\n"))
  b.caret, b.anchor = ends[:caret], ends[:anchor]
  touch!(e)
end

# ⌃↑ and ⌃↓ change the value at the caret a step. A number goes a step bigger or smaller, as a drag on a
# sum does: a step is one of its last digit. Unlike a drag, ⌃↓ takes a number under 0. true and false swap,
# with either key. Any other word goes up from small letters, to a capital at its front, to all capitals,
# and ⌃↓ takes it back down. The value can be anywhere in the text: in a sum, in a sheet, in code, in a
# date or a time. Presses one after another are taken back by one ⌘Z.

"""
Where the number is that the column `col` of `line` is in, or at either end
of: the columns that it runs from and to. Nothing when no digit touches the
column. A number has digits, and can have a dot and more digits after them,
like 2.40. Digits with a dot on each side, like the parts of 1.2.3, are each a
number of their own. A - just before the digits is the number's sign, unless a
letter, a digit or a bracket comes before it, like the - of x-1 or of 2026-11-21.
"""
caret_number(line::AbstractString, col::Int) = begin
  c = collect(line)
  n = length(c)
  digit(i) = 1 <= i <= n && isdigit(c[i])
  at = digit(col + 1) ? col + 1 : digit(col) ? col : col < n && c[col+1] == '-' && digit(col + 2) ? col + 2 : 0
  at == 0 && return nothing
  lo = hi = at                      # the first and the last of the number's characters, from 1
  while digit(lo - 1) lo -= 1 end
  while digit(hi + 1) hi += 1 end
  run = (lo, hi)
  # Digits, a dot and digits are one number
  if lo > 2 && c[lo-1] == '.' && digit(lo - 2)
    lo -= 2
    while digit(lo - 1) lo -= 1 end
  elseif hi < n - 1 && c[hi+1] == '.' && digit(hi + 2)
    hi += 2
    while digit(hi + 1) hi += 1 end
  end
  # With a dot more at either end, it's a list of numbers, like 1.2.3 or 192.168.0.1, and the caret's is one of them
  dotted(i, j) = (i >= 2 && c[i-1] == '.' && digit(i - 2)) || (j < n && c[j+1] == '.' && digit(j + 2))
  (lo, hi) != run && dotted(lo, hi) && ((lo, hi) = run)
  lo >= 2 && c[lo-1] == '-' && !(lo >= 3 && (isletter(c[lo-2]) || isdigit(c[lo-2]) || c[lo-2] in ")]}_")) && (lo -= 1)
  # The caret was before a - that isn't a sign, like the one of x|-1
  lo - 1 <= col || return nothing
  (lo - 1, hi)
end

"""
The number that `text` writes, `steps` steps on. A step is one of its last
digit: 16 goes to 17, 2.40 to 2.41, and 0 to -1 after a step back. It has as
many digits after its dot as before, and a number with a 0 at its front keeps
its width, so 09 goes to 10 and 007 to 008.
"""
number_plus(text::AbstractString, steps::Int) = begin
  neg = startswith(text, '-')
  body = neg ? text[2:end] : text
  dot = findfirst('.', body)
  places = dot === nothing ? 0 : length(body) - dot
  whole = dot === nothing ? body : body[1:dot-1]
  digits = replace(body, "." => "")
  # In whole numbers, so that 2.4 and a step of 0.01 don't make 2.4099999
  v = parse(BigInt, digits) * (neg ? -1 : 1) + steps
  wide = length(whole) > 1 && startswith(whole, '0') ? length(digits) : places + 1
  s = lpad(string(abs(v)), wide, '0')
  places > 0 && (s = s[1:end-places] * "." * s[end-places+1:end])
  v < 0 ? "-" * s : s
end

"""
Where the word is that the column `col` of `line` is in, or at either end of:
the columns that it runs from and to. A word has letters, digits and _, and an
apostrophe between two letters, like don't. Nothing when no word touches the column.
"""
caret_word(line::AbstractString, col::Int) = begin
  c = collect(line)
  n = length(c)
  inword(i) = 1 <= i <= n && (isletter(c[i]) || isdigit(c[i]) || c[i] == '_' ||
                              (c[i] in "'’" && 1 < i < n && isletter(c[i-1]) && isletter(c[i+1])))
  lo = hi = col
  while inword(lo) lo -= 1 end
  while inword(hi + 1) hi += 1 end
  lo == hi ? nothing : (lo, hi)
end

"""
The word `w` a step up, or a step down when `up` is false. It's `w` itself
when it can't go further. true and false swap, and so do True and False, and
TRUE and FALSE. Any other word goes up from small letters, to a capital at its
front, to all capitals: word, Word, WORD. A step down goes back: WORD, Word, word.
"""
word_step(w::AbstractString, up::Bool) = begin
  low = lowercase(w)
  if low in ("true", "false")
    other = low == "true" ? "false" : "true"
    return w == uppercase(w) ? uppercase(other) : isuppercase(first(w)) ? uppercasefirst(other) : other
  end
  c = collect(w)
  letters = findall(isletter, c)
  isempty(letters) && return w
  f = first(letters)
  caps = all(i -> isuppercase(c[i]), letters)
  if up
    !isuppercase(c[f]) ? (c[f] = uppercase(c[f])) : caps || (c = collect(uppercase(w)))
  else
    caps && length(letters) > 1 ? (c = collect(lowercase(w)); c[f] = uppercase(c[f])) : isuppercase(c[f]) && (c[f] = lowercase(c[f]))
  end
  String(c)
end

"""
The value at the column `col` of `line`, `steps` steps on: the columns that it
runs from and to, and its new text. It's the number that the column is in or at,
or else the word. A word with digits, like 16m or h1, is its number, so the
caret can be after the unit of 16m. Nothing when there's no value there, or
when it can't go further.
"""
caret_value(line::AbstractString, col::Int, steps::Int) = begin
  at = caret_number(line, col)
  w = caret_word(line, col)
  if at === nothing && w !== nothing
    # The digit in the word that's nearest the caret, before it or else after it
    c = collect(line)
    lo, hi = w
    before = findlast(isdigit, c[lo+1:col])
    after = findfirst(isdigit, c[col+1:hi])
    at = before !== nothing ? caret_number(line, lo + before) : after !== nothing ? caret_number(line, col + after - 1) : nothing
  end
  at === nothing || return (at..., number_plus(rest(head(line, at[2]), at[1]), steps))
  w === nothing && return nothing
  word = rest(head(line, w[2]), w[1])
  new = word_step(word, steps > 0)
  new == word ? nothing : (w..., new)
end

"Make the value at the caret `steps` steps bigger, or smaller for steps under 0. See `caret_value`. The caret and the selection stay with their text."
step_value!(e, steps::Int) = begin
  b = e.buf
  (readonly(b) || b.fixed) && return
  i, col = b.caret
  found = caret_value(b.lines[i], col, steps)
  found === nothing && return
  lo, hi, new = found
  caret, anchor = b.caret, b.anchor
  # A press right after a press, with no other change between them, is taken back with it
  b.typed = state_of(e, KeysState).stepped == b.version ? time() : 0.0
  edit!(b, (i, lo), (i, hi), new, typing=true)
  b.typed = 0.0   # and what's typed after it is taken back by itself
  state_of(e, KeysState).stepped = b.version
  # A place in the number stays as far from its end as it was, so the caret at the end of 9 is at the end of 10
  by = length(new) - (hi - lo)
  kept(p) = p[1] != i || p[2] <= lo ? p : (i, max(lo, p[2] + by))
  b.caret, b.anchor = kept(caret), kept(anchor)
  touch!(e)
end

# `ADDED_COMMANDS`, in additions.jl, has each command that `add_commands!` added, with the name of its
# group, in the order that they came. A file that loads before this one adds its commands before
# `COMMAND_GROUPS` is made. And a hot reload makes `COMMAND_GROUPS` again when a name in it changes,
# and doesn't call `add_command!` again. So the list takes these in when it's made: see `with_added`.

"""
Put each of `commands` in the group of `groups` called `group`, at the end,
or in the place of the one that has its name. A group that isn't there yet
comes last.
"""
put_commands!(groups, group::AbstractString, commands) = begin
  i = findfirst(g -> first(g) == group, groups)
  i === nothing && (push!(groups, String(group) => Command[]); i = length(groups))
  list = last(groups[i])
  for c in commands
    k = findfirst(o -> o.name == c.name, list)
    k === nothing ? push!(list, c) : (list[k] = c)
  end
  groups
end

"""
The groups of the commands that functions make, and each group's commands in
the order that the key bindings page lists them. Each file adds its own
commands, and the files load in another order than this one, so this list
keeps each row of the page where it was. A command that isn't named here
needs no line: it comes after these, in the order that it was added.
"""
const ADDED_ORDER = [
  "The file or the folder in focus" => [
    :rename, :duplicate, :move_to_trash, :show_in_finder, :copy_path, :new_page, :new_folder, :new_terminal,
    :new_agent_session, :add_to_favourites, :remove_from_favourites],
  "Commands that ask for something" => [
    :go_to, :go_to_definition, :rename_in_code, :find_uses, :add_check, :run_all, :insert, :theme, :text_size,
    :key_bindings, :switch_agent, :spelling, :peeks, :word_count, :copy_link_to_block,
    :navigate, :reload_page, :open_in_browser, :show_as_app,
    :agent_mode, :end_agent_session, :ask_agent, :show_change, :undo_change, :show_code, :keep_this_change,
    :stop_agent, :fix_check, :ask_for_checks, :show_steps,
    :trust_site, :stop_trusting_site, :add_to_favourites, :remove_from_favourites,
    :right_panel, :push, :pull, :merge, :rebase, :commit, :commit_all, :commit_staged, :commit_ticked,
    :show_changes_in_place, :next_change, :previous_change,
    :go_to_favourite, :show_folder_as, :show_interests, :show_feeds, :open_news, :get_the_news, :autosave]]

"""
Put the commands of each group of `groups` that `ADDED_ORDER` names in its
order. The other commands of the group come after them, in the order that
they have.
"""
in_order!(groups) = begin
  for (group, names) in ADDED_ORDER
    i = findfirst(g -> first(g) == group, groups)
    i === nothing && continue
    place(c) = something(findfirst(==(c.name), names), length(names) + 1)
    sort!(last(groups[i]), by=place, alg=MergeSort)   # a sort that keeps the order of the commands with one place
  end
  groups
end

"""
`groups` with each command that `add_commands!` added put in its group. The
groups that `ADDED_ORDER` names come first after the ones of `groups`, in
its order.
"""
with_added(groups) = begin
  foreach(((group, _),) -> put_commands!(groups, group, ()), ADDED_ORDER)
  foreach(((group, c),) -> put_commands!(groups, group, (c,)), ADDED_COMMANDS)
  in_order!(groups)
end

"""
The commands, in the groups and the order that the key bindings page shows
them. Each has its shortcuts in the bundle called Ladder.
"""
const COMMAND_GROUPS = with_added([
  "Files and windows" => [
    Command(:save, "Save the file", :window, "cmd+s", (e, w, _) -> save_page!(e)),
    Command(:new_window, "Open a new window on the folder that you're in", :window, "cmd+n", (e, w, _) -> new_window!(e)),
    Command(:open, "Find a file by name", :window, "cmd+o", (e, w, _) -> open_finder!(e)),
    Command(:open_project, "Find a project by name and open it", :window, "cmd+p", (e, w, _) -> open_projects!(e)),
    Command(:home, "Open your home folder in the page", :window, "cmd+shift+h", (e, w, _) -> go_home!(e)),
    Command(:commands, "Show the command palette, to run a command by its name", :window, "cmd+shift+p", (e, w, _) -> toggle_palette!(e)),
    Command(:back, "Go back to the line or the file that showed before", :window, "cmd+opt+left", (e, w, _) -> go_back!(e)),
    Command(:forward, "Go forward again, to the line or the file that you went back from", :window, "cmd+opt+right", (e, w, _) -> go_forward!(e)),
    Command(:print, "Print the page", :window, "cmd+opt+p", (e, w, _) -> print!(e, w)),
    Command(:export, "Export the page as HTML", :window, "cmd+shift+e", (e, w, _) -> export_html!(e, w)),
    Command(:slides, "Show the page as slides, or as a page again", :window, "ctrl+cmd+shift+p", (e, w, _) -> slides!(e)),
    Command(:close, "Close the file, or the window when it shows no file", :window, "cmd+w", (e, w, _) -> close_file_or_window!(e, w)),
    Command(:settings, "Show or hide the settings", :window, "cmd+comma", (e, w, _) -> toggle_settings!(e)),
    Command(:sidebar, "Show or hide the sidebar", :window, "cmd+backslash", (e, w, _) -> toggle_panel!(e)),
    Command(:sidebar_keys, "Give the sidebar the keyboard", :window, "cmd+shift+backslash", (e, w, _) -> focus_panel!(e)),
    Command(:plain, "Go down a level in the part that the caret is in, or up again", :window, "cmd+e", (e, w, _) -> level!(e)),
    Command(:hidden_files, "Show or hide the hidden and ignored files in the sidebar", :window, "cmd+shift+period", (e, w, _) -> hidden!(e, !e.hidden)),
    Command(:bigger, "Make the text bigger", :window, "cmd+equal", (e, w, _) -> zoom!(e, zoom_for(text_size(e) + 1))),
    Command(:smaller, "Make the text smaller", :window, "cmd+minus", (e, w, _) -> zoom!(e, zoom_for(text_size(e) - 1))),
    Command(:usual_size, "Put the text back to its usual size", :window, "cmd+0", (e, w, _) -> zoom!(e, 1.0)),
    # The app that's built has no layout inspector
    (BUILDING_APP ? () : (Command(:inspector, "Show or hide the layout inspector", :window, "cmd+opt+i", (e, w, _) -> toggle_inspector!(w)),))...],
  "The text" => [
    Command(:undo, "Undo", :edit, "cmd+z", (e, w, _) -> (undo!(e.buf); touch!(e))),
    Command(:redo, "Redo", :edit, "cmd+shift+z", (e, w, _) -> (redo!(e.buf); touch!(e))),
    Command(:cut, "Cut", :edit, "cmd+x", (e, w, _) -> cut!(e)),
    Command(:copy, "Copy", :look, "cmd+c", (e, w, _) -> copy_selection!(e)),
    Command(:paste, "Paste", :edit, "cmd+v", (e, w, _) -> paste!(e)),
    Command(:select_all, "Select all", :look, "cmd+a", (e, w, _) -> select_all!(e)),
    Command(:select_word, "Select the word at the caret", :look, "cmd+d", (e, w, _) -> select_word!(e)),
    Command(:find, "Find in the page", :look, "cmd+f", (e, w, _) -> find!(e, w)),
    Command(:find_next, "Go to the next place that's found", :look, "cmd+g", (e, w, _) -> find_step!(e, 1)),
    Command(:find_last, "Go to the place that's found before", :look, "cmd+shift+g", (e, w, _) -> find_step!(e, -1)),
    Command(:bold, "Make the selection bold", :edit, "cmd+b", (e, w, _) -> e.buf.view == :markdown && surround!(e, "**")),
    Command(:italic, "Make the selection italic", :edit, "cmd+i", (e, w, _) -> e.buf.view == :markdown && surround!(e, "*")),
    Command(:value_up, "Make the number or the word at the caret a step bigger", :edit, "ctrl+up", (e, w, _) -> step_value!(e, 1)),
    Command(:value_down, "Make the number or the word at the caret a step smaller", :edit, "ctrl+down", (e, w, _) -> step_value!(e, -1)),
    # In a `julia` code block these run the code that the caret is in. Anywhere else, the first sends the page
    # to the agent that waits for it, and with no agent, each starts a new line as Return does.
    Command(:run, "Run the code at the caret, or nudge the agent", :edit, "cmd+enter",
            (e, w, _) -> run_here!(e) || (isempty(agents(e)) ? newline!(e) : send!(e))),
    Command(:run_step, "Run the code at the caret and go to the next line", :type, "shift+enter",
            (e, w, _) -> run_here!(e, step=true) || newline!(e))],
  "Lines" => [
    Command(:select_line, "Select the line", :look, "cmd+shift+l", (e, w, _) -> select_lines!(e)),
    Command(:line_up, "Move the line up", :edit, "cmd+opt+left_bracket", (e, w, _) -> move_lines!(e, -1)),
    Command(:line_down, "Move the line down", :edit, "cmd+opt+right_bracket", (e, w, _) -> move_lines!(e, 1)),
    Command(:duplicate_line, "Copy the line to the line under it", :edit, "cmd+shift+d", (e, w, _) -> duplicate_lines!(e)),
    Command(:delete_line, "Delete the line", :edit, "cmd+shift+k", (e, w, _) -> delete_lines!(e)),
    Command(:comment, "Make a line of code a comment, or code again", :edit, "cmd+slash", (e, w, _) -> toggle_comment!(e)),
    Command(:indent, "Indent, or go to the next cell of a table", :type, "tab", (e, w, _) -> indent!(e, false)),
    Command(:outdent, "Take an indent away, or go back a cell", :type, "shift+tab", (e, w, _) -> indent!(e, true)),
    Command(:indent_line, "Move the line in a step, wherever the caret is", :edit, "cmd+right_bracket", (e, w, _) -> indent_lines!(e, false)),
    Command(:outdent_line, "Move the line out a step, wherever the caret is", :edit, "cmd+left_bracket", (e, w, _) -> indent_lines!(e, true))],
  "The caret" => [
    Command(:left, "Left", :move, "left", (e, w, select) -> (e.by_step = true; caret_step!(e, -1, select))),
    Command(:right, "Right", :move, "right", (e, w, select) -> (e.by_step = true; caret_step!(e, 1, select))),
    Command(:up, "Up", :move, "up", (e, w, select) -> (e.by_step = true; move!(e, vertical(e, -1), select; keep_goal=true, by=-1))),
    Command(:down, "Down", :move, "down", (e, w, select) -> (e.by_step = true; move!(e, vertical(e, 1), select; keep_goal=true, by=1))),
    Command(:word_left, "To the word before", :move, "opt+left", (e, w, select) -> (e.by_step = true; move!(e, word_step(e.buf, e.buf.caret, -1), select; by=-1))),
    Command(:word_right, "To the next word", :move, "opt+right", (e, w, select) -> (e.by_step = true; move!(e, word_step(e.buf, e.buf.caret, 1), select; by=1))),
    Command(:line_start, "To the start of the line", :move, "cmd+left, home", (e, w, select) -> move!(e, screen_edge(e, -1), select; by=-1)),
    Command(:line_end, "To the end of the line", :move, "cmd+right, end", (e, w, select) -> move!(e, screen_edge(e, 1), select; by=1)),
    Command(:doc_start, "To the top of the page", :move, "cmd+up", (e, w, select) -> move!(e, (1, 0), select; by=-1)),
    Command(:doc_end, "To the bottom of the page", :move, "cmd+down", (e, w, select) -> move!(e, line_end(e.buf, length(e.buf.lines)), select; by=1)),
    Command(:page_up, "Up a screen", :move, "pageup", (e, w, select) -> caret_page!(e, -1, select)),
    Command(:page_down, "Down a screen", :move, "pagedown", (e, w, select) -> caret_page!(e, 1, select))],
  "Deleting" => [
    Command(:erase_back, "Delete what's before the caret", :type, "backspace", (e, w, _) -> erase_back!(e)),
    Command(:erase, "Delete what's after the caret", :type, "delete", (e, w, _) -> erase_next!(e)),
    Command(:erase_word_back, "Delete to the start of the word", :type, "opt+backspace", (e, w, _) -> erase!(e, word_step(e.buf, e.buf.caret, -1))),
    Command(:erase_word, "Delete to the end of the word", :type, "opt+delete", (e, w, _) -> erase!(e, word_step(e.buf, e.buf.caret, 1))),
    Command(:erase_line_start, "Delete to the start of the line", :type, "cmd+backspace", (e, w, _) -> erase!(e, (e.buf.caret[1], 0))),
    Command(:erase_line_end, "Delete to the end of the line", :type, "ctrl+k", (e, w, _) -> erase_line_end!(e))]])

"""
Each command, by its name. Two groups can each have a command with one name,
like Add To Favourites for a folder and for a page from the web. The name
then stands for the one that was added last.
"""
const COMMANDS = Dict{Symbol,Command}(c.name => c for c in Command[reduce(vcat, last.(COMMAND_GROUPS)); last.(ADDED_COMMANDS)])

list_commands!(group::AbstractString, commands) = begin
  put_commands!(COMMAND_GROUPS, group, commands)
  in_order!(COMMAND_GROUPS)
  foreach(c -> COMMANDS[c.name] = c, commands)
  nothing
end

"What kind of command the command `name` is: :type, :move, :edit, :look or :window"
command_kind(name::Symbol) = COMMANDS[name].kind

"Open the command palette on the command called `name`, to ask for what it takes"
open_palette!(e, name::Symbol) = open_palette!(e, COMMANDS[name])

"""
The bundles of key bindings, in the order that the key bindings page offers
them. Each lists only the commands whose shortcuts are different from the
ones in the bundle called Ladder, with the shortcuts it gives them.
"""
const BUNDLES = [
  "Ladder" => Pair{Symbol,String}[],
  # ⌘P finds a project in every bundle, so printing has another key. The slides' key, ⌃⌘⇧P, is free in every bundle.
  "VS Code" => [
    :back => "ctrl+minus", :forward => "ctrl+shift+minus",
    :line_up => "opt+up", :line_down => "opt+down", :duplicate_line => "opt+shift+down, opt+shift+up"],
  "Sublime Text" => [
    :back => "ctrl+minus", :forward => "ctrl+shift+minus",
    :sidebar => "cmd+k cmd+b, cmd+backslash", :redo => "cmd+shift+z, cmd+y",
    :line_up => "ctrl+cmd+up", :line_down => "ctrl+cmd+down", :delete_line => "ctrl+shift+k",
    :erase_line_start => "cmd+backspace, cmd+k cmd+backspace", :erase_line_end => "ctrl+k, cmd+k cmd+k"],
  # Emacs's own keys come first, and the Mac's keys still work where Emacs has no other use for them
  "Emacs" => [
    :save => "ctrl+x ctrl+s, cmd+s", :open => "ctrl+x ctrl+f, cmd+o", :close => "ctrl+x ctrl+c, cmd+w",
    :undo => "ctrl+slash, ctrl+x u, cmd+z", :cut => "ctrl+w, cmd+x", :copy => "opt+w, cmd+c", :paste => "ctrl+y, cmd+v",
    :commands => "opt+x, cmd+shift+p", :select_all => "ctrl+x h, cmd+a", :select_word => "opt+shift+2, cmd+d", :find => "ctrl+s, cmd+f", :find_last => "ctrl+r, cmd+shift+g", :comment => "opt+semicolon, cmd+slash",
    :left => "ctrl+b, left", :right => "ctrl+f, right", :up => "ctrl+p, up", :down => "ctrl+n, down",
    :word_left => "opt+b, opt+left", :word_right => "opt+f, opt+right",
    :line_start => "ctrl+a, cmd+left, home", :line_end => "ctrl+e, cmd+right, end",
    :doc_start => "opt+shift+comma, cmd+up", :doc_end => "opt+shift+period, cmd+down",
    :page_up => "opt+v, pageup", :page_down => "ctrl+v, pagedown",
    :erase => "ctrl+d, delete", :erase_word => "opt+d, opt+delete"]]

"The shortcuts that the bundle called `name` gives each command"
bundle_keys(name::AbstractString) = begin
  theirs = Dict(last(BUNDLES[something(findfirst(b -> first(b) == name, BUNDLES), 1)]))
  Dict{Symbol,Vector{Shortcut}}(c.name => read_shortcuts(get(theirs, c.name, c.keys)) for c in values(COMMANDS))
end

"""
The key bindings as they are now. `of` has the shortcuts of each command: the
bundle's, with the ones that the key bindings page changed. `commands` has the
command of each shortcut, and `starts` each stroke that starts a shortcut of two.
`also` has the other commands of a shortcut that two or more commands have.
"""
keys_now(e) = begin
  made = state_of(e, KeysState).made
  # Code from the startup page can add commands, so the bindings are made again when there are more
  made !== nothing && made.bundle == e.bundle && made.rebound === e.rebound && made.count == length(COMMANDS) && return made
  of = bundle_keys(e.bundle)
  for (name, text) in e.rebound
    haskey(of, name) && (of[name] = read_shortcuts(text))
  end
  commands = Dict{Shortcut,Symbol}()
  also = Dict{Shortcut,Vector{Symbol}}()
  # A shortcut that two commands have runs the one that the page lists first, where that one has a use: see `command_here`
  for (_, cs) in COMMAND_GROUPS, c in cs, s in of[c.name]
    haskey(commands, s) ? push!(get!(Vector{Symbol}, also, s), c.name) : (commands[s] = c.name)
  end
  starts = Set{Stroke}(first(s) for s in keys(commands) if length(s) == 2)
  state_of(e, KeysState).made = (bundle=e.bundle, rebound=e.rebound, of=of, commands=commands, also=also, starts=starts, count=length(COMMANDS))
end

"""
The command that the shortcut `s` runs in the window of `e`, with the key
bindings `ks`, or nothing. Of the commands that have the shortcut, it's the
first that has a use there (see `works_here`). So code from the startup page
can give a key that Ladder has a use where Ladder's command has none, like ⌘]
on a page that you can't change. When none has a use, it's the first.
"""
command_here(e, ks, s) = begin
  name = get(ks.commands, s, nothing)
  others = get(ks.also, s, nothing)
  (others === nothing || works_here(e, Val(name))) && return name
  something(findfirst_here(e, others), name)
end

"The first of the commands `names` that has a use in the window of `e`, or nothing"
findfirst_here(e, names) = (i = findfirst(n -> works_here(e, Val(n)), names); i === nothing ? nothing : names[i])

"The command that the key `K` runs by itself in window `w`, with the keys that are held there, or nothing"
command_of(e, w, K) = command_here(e, keys_now(e), (Stroke(w.keys & HELD, K),))

"""
The command that the key `K` runs in window `w`, with the keys that are held
there, and true when ⇧ is held to grow the selection. The command is `:wait`
for a key that does nothing by itself: the first key of a shortcut of two, or
a second key that ends no shortcut. It's nothing for a key with no command.
"""
command!(e, w, K) = begin
  (ismouse(K) || K in HELD || K == Keys.capslock || K == Keys.fn) && return (nothing, false)
  ks = keys_now(e)
  s = Stroke(w.keys & HELD, K)
  kept = state_of(e, KeysState)
  before, kept.stroke = kept.stroke, nothing
  name, select = if before !== nothing
    (something(command_here(e, ks, (before, s)), :wait), false)
  elseif haskey(ks.commands, (s,))
    (command_here(e, ks, (s,)), false)
  elseif s in ks.starts
    kept.stroke = s
    (:wait, false)
  else
    # ⇧ with the keys of a command that moves the caret grows the selection. With a key like ⌫, it changes nothing.
    found = Keys.shft in s.held ? get(ks.commands, (Stroke(setdiff(s.held, Keys.shft), K),), nothing) : nothing
    kind = found === nothing ? :none : COMMANDS[found].kind
    kind == :move ? (found, true) : kind == :type ? (found, false) : (nothing, false)
  end
  # A key that types a character types nothing when it's the key of a command, like ⌥F in the Emacs bundle
  name !== nothing && typing_key(K) && !(Keys.cmd in s.held) && !(Keys.ctrl in s.held) && (kept.mute = time())
  (name, select)
end

"The commands that are done at each selection when there are several: the ones that go along a line, and the ones that delete"
const AT_EACH = Set([:left, :right, :word_left, :word_right, :line_start, :line_end, :bold, :italic, :value_up, :value_down,
                     :erase_back, :erase, :erase_word_back, :erase_word, :erase_line_start, :erase_line_end])

"Run the command called `name` in the window `w` of `e`"
run!(e, w, name::Symbol, select::Bool=false) =
  name in AT_EACH ? each_selection!(() -> COMMANDS[name].run(e, w, select), e) : COMMANDS[name].run(e, w, select)

"The first shortcut of the command `name` with two spaces before it, to end a tooltip with, or nothing when the command has no keys"
hint(e, name::Symbol) = (list = keys_now(e).of[name]; isempty(list) ? "" : "  " * caps(first(list)))

"True when one of the shortcuts `a` and `b` starts with the other, so the keys of one would run the other"
clashes(a::Shortcut, b::Shortcut) = (n = min(length(a), length(b)); a[1:n] == b[1:n])

"""
Use the bundle called `bundle`, with the shortcuts in `rebound` for the commands
that have other keys than the bundle's. Every window gets them, and they're kept.
"""
keys!(e, bundle::String, rebound::Dict{Symbol,String}) = begin
  usual = bundle_keys(bundle)
  # A command that has the bundle's own shortcuts again isn't changed any more
  e.bundle, e.rebound = bundle, filter(((name, text),) -> haskey(usual, name) && read_shortcuts(text) != usual[name], rebound)
  state_of(e, KeysState).stroke = nothing
  save_settings!(e)
  rerun!(e, :bundle)
  rerun!(e, :rebound)
  e
end

"Use the bundle of key bindings called `name`. Every command gets the bundle's keys, so the keys that were changed go back too."
bundle!(e, name::String) = begin
  any(b -> first(b) == name, BUNDLES) || error("The bundles of key bindings are $(join(first.(BUNDLES), ", ", " and ")). $name isn't one of them.")
  keys!(e, name, Dict{Symbol,String}())
end

"""
Give the command `name` the shortcut `s`, and no other. A command that had
those keys, or keys that start the same way, loses them. Returns the names
of the commands that lost a shortcut.
"""
rebind!(e, name::Symbol, s::Shortcut) = begin
  new = copy(e.rebound)
  lost = Symbol[]
  for (other, list) in keys_now(e).of
    other == name && continue
    kept = filter(o -> !clashes(o, s), list)
    length(kept) == length(list) && continue
    new[other] = written(kept)
    push!(lost, other)
  end
  new[name] = written(Shortcut[s])
  keys!(e, e.bundle, new)
  lost
end

"Give the command `name` the bundle's shortcuts again. A command that has one of them now loses it."
put_back!(e, name::Symbol) = begin
  new = copy(e.rebound)
  delete!(new, name)
  lost = Symbol[]
  for s in bundle_keys(e.bundle)[name], (other, list) in keys_now(e).of
    other == name && continue
    kept = filter(o -> !clashes(o, s), read_shortcuts(get(new, other, written(list))))
    length(kept) == length(list) && continue
    new[other] = written(kept)
    other in lost || push!(lost, other)
  end
  keys!(e, e.bundle, new)
  lost
end

# The key bindings page shows the commands in a list. Each row has the command's shortcuts at its right.
# A click on a row waits for the keys of its new shortcut.

"The list of the commands on the key bindings page"
@def mutable struct KeyList <: SemanticUI end
"A command's row in that list. A click on it waits for the command's new keys."
@def mutable struct KeyRow <: SemanticUI
  name::Symbol = :save
end
"The words in a row that give its command the bundle's keys again"
@def mutable struct KeyReset <: SemanticUI
  name::Symbol = :save
end

const KEY_ROW_H = 34px

"A shortcut as the list shows it: its keys in a box"
keycap(s::Shortcut) = Box(height(22px), padding(7px, 0px), radius(5px), background(colours.float), border(1px, :solid, colours.line),
                          label(caps(s), 12px, color=colours.ink))

"The command whose row waits for new keys, or nothing"
key_asking(e) = state_of(e, KeysAsked).asking

"Stop waiting for a command's new keys, and give the keyboard back to the text"
stop_asking_keys!(e) = (state_of(e, KeysAsked).asking = nothing; focus(e); handled)

"What the list says under the row of `name`, after its new keys took the keys of the commands in `lost`"
lost_note!(e, name::Symbol, lost) = begin
  isempty(lost) && return (state_of(e, KeysAsked).note = (:none, ""))
  titles = [COMMANDS[other].title for other in lost]
  none = [other for other in lost if isempty(keys_now(e).of[other])]
  state_of(e, KeysAsked).note = (name, "\"$(join(titles, "\", \"", "\" and \""))\" had $(length(lost) == 1 ? "this key" : "these keys") before." *
                              (isempty(none) ? "" : length(lost) == 1 ? " It has no key now." : " $(length(none)) of them have no key now."))
end

describe(l::KeyList) = begin
  e = editor(l)
  row(name) = node!(() -> KeyRow(name=name), e, (:key_row, name))
  Column(width(grow=grow), Alignment.Start, name="Key bindings",
    Iterators.flatten(((Box(width(grow=grow), height(40px), padding(10px, 0px, 6px, 10px), Alignment.End,
                            Row(width(grow=grow), label(group, 12px, color=colours.dim, weight="Semibold"))),
                        map(c -> row(c.name), cs)...) for (group, cs) in COMMAND_GROUPS))...)
end

describe(r::KeyRow) = begin
  e = editor(r)
  w = window_of(e)
  waits = key_asking(e) == r.name
  # A click somewhere else gives the keyboard to something else, and the row stops waiting
  waits && (w === nothing || w.focus !== r) && (state_of(e, KeysAsked).asking = nothing; waits = false)
  list = keys_now(e).of[r.name]
  under = state_of(e, KeysAsked).note
  # Words by themselves would take half of the row, so each is in a box that's as wide as the words
  right = waits ? (Box(label(something(state_of(e, KeysAsked).refused, "Press the new keys, or esc to keep these"), 12px, color=colours.accent)),) :
          isempty(list) ? (Box(label("No keys", 12px, color=colours.faint)),) : map(keycap, list)
  row = Row(width(grow=grow), height(KEY_ROW_H), padding(10px, 0px), radius(6px), child_gap=6px, name="Command",
            background(waits ? colours.active : ishovered(r) ? colours.hover : clear),
    # A long title is cut off where the row ends, so that it doesn't push the keys out past the page's right edge
    Box(width(grow=grow), Alignment.Start, clip_x=true, label(COMMANDS[r.name].title, 14px)),
    (haskey(e.rebound, r.name) && !waits ? (node!(() -> KeyReset(name=r.name), e, (:key_reset, r.name)),) : ())...,
    right...)
  under[1] == r.name || return row
  Column(width(grow=grow), Alignment.Start, row,
    Box(width(grow=grow), padding(10px, 0px, 8px, 10px), Alignment.Start, label(under[2], 12px, color=colours.dim)))
end

cursor(::KeyRow) = :hand

onkey(r::KeyRow, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(r)
  asked = state_of(e, KeysAsked)
  asked.asking, asked.refused, asked.note = r.name, nothing, (:none, "")
  focus(r)
  handled
end

# While a row waits, the next key with the keys held with it is the command's new shortcut. esc leaves the command as it was.
onkey(r::KeyRow, ev::KeyPress{K}) where K = begin
  e = editor(r)
  key_asking(e) == r.name || return nothing
  ismouse(K) && return nothing
  (K in HELD || K == Keys.capslock || K == Keys.fn) && return handled
  K == Keys.escape && return stop_asking_keys!(e)
  s = Stroke(ev.window.keys & HELD, K)
  # The text gets the keyboard back before the key types its character, like the π of ⌥P, so the character is dropped
  typing_key(K) && !(Keys.cmd in s.held) && !(Keys.ctrl in s.held) && (state_of(e, KeysState).mute = time())
  if typing_key(K) && !(Keys.cmd in s.held) && !(Keys.ctrl in s.held) && !(Keys.opt in s.held)
    state_of(e, KeysAsked).refused = "$(caps(s)) types a character. Hold ⌘, ⌃ or ⌥ with it."
    return handled
  elseif K == Keys.enter && s.held == Keys(0)
    state_of(e, KeysAsked).refused = "Return starts a new line. Hold ⌘, ⌃, ⌥ or ⇧ with it."
    return handled
  end
  lost_note!(e, r.name, rebind!(e, r.name, (s,)))
  stop_asking_keys!(e)
end
ontype(r::KeyRow, ::Typed) = key_asking(editor(r)) == r.name ? handled : nothing

describe(b::KeyReset) = Box(height(22px), padding(7px, 0px), radius(5px), background(ishovered(b) ? colours.active : clear),
                            label("Put back", 12px, color=colours.dim))
cursor(::KeyReset) = :hand
onkey(b::KeyReset, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(b)
  lost_note!(e, b.name, put_back!(e, b.name))
  handled
end

# A mouse can have two buttons at its side, which go back and forward in a web browser. Here they do what
# ⌘⌥← and ⌘⌥→ do. A press of one isn't for the place that the mouse is over. It comes to the part of the
# window that has the keyboard, and from there to here.
onkey(e::Editor, ev::KeyPress{Keys.mouse_back}) = side_button!(e, ev.window, :back)
onkey(e::Editor, ev::KeyPress{Keys.mouse_forward}) = side_button!(e, ev.window, :forward)

"Run the `command` of a button at the side of the mouse: `:back` or `:forward`"
side_button!(e, w, command) = begin
  e = top_editor(e)   # in a part of another page, they go back and forward in the window's page
  # While a picture fills the window, or the file finder is open, the page under it stays, as it does for the keys
  (zooming(e) === nothing && e.popup == :none) || return nothing
  run!(e, w, command)
  nothing
end

"Whether the sidebar's tree took the key that comes to the editor next, so that the editor leaves it: see `chose!`"
@def mutable struct TreeTook
  key::Bool = false
end

"True when the sidebar's tree took the key or the click that has just come to the editor `e`. The editor asks once for each."
tree_took!(e) = (s = state_of(e, TreeTook); took = s.key; s.key = false; took)

# A press of a mouse button that nothing under the mouse took comes here. It has a method of its own, so the
# first click in a window doesn't wait for the code of the key bindings to be made ready.
onkey(e::Editor, ev::Union{KeyPress{Keys.mouse_left},KeyPress{Keys.mouse_right},KeyPress{Keys.mouse_middle}}) = begin
  tree_took!(e) && return
  # While a picture or a model fills the window, a right-click has no menu
  zooming(e) === nothing || e.popup != :none || return
  slideshow(e) === nothing || return   # nor has a right-click on a slide
  ev isa KeyPress{Keys.mouse_right} && return context_menu!(e, ev.window)
  nothing
end

"""
What a key does. The key bindings say which command it runs. Return, esc and
Space have no command: what they do depends on where the caret is.
"""
# Julia compiles a function once for each type that it's called with, and each key's press has
# a type of its own. So the press gives its key on as a value, and the long function that says
# what a key does is compiled once, for the first key that's pressed. Before that, each key
# waited at its first press: ⌘V for more than a second.
onkey(e::Editor, ev::KeyPress{K}) where K = pressed!(e, ev.window, K)

"The key `K` was pressed in the window `w` while `e` or a part of it had the keyboard"
pressed!(e::Editor, w, K) = begin
  # A key that the sidebar's tree took, like Return on a heading, comes here next. It isn't for the text.
  tree_took!(e) && return
  # The first key of a shortcut of two, like ⌃X, does nothing but wait for the second
  command, select = command!(e, w, K)
  command == :wait && return
  command == :paste || return key_does!(e, w, K, command, select)
  # The key that pastes reads the clipboard now. An app that takes dictation puts its words there, presses
  # the key, and half a second later puts back what was there before. The first paste waits longer than
  # that for Julia to compile it, and it got that older thing, like a screenshot.
  mine = Pasteboard.hold!()
  try
    key_does!(e, w, K, command, select)
  finally
    mine && Pasteboard.release!()
  end
end

"""
Do what the key `K` does in the window `w` of `e`, where `command` is the
command that the key runs, or nothing: see `command!`. It's compiled once for
a key with a command and a key with none, so the first key that's pressed
compiles it for them all.
"""
key_does!(e::Editor, w, K, @nospecialize(command), select) = begin
  # In a small editor, like the field of a cell of a table or a part of another page, the key is its owner's
  # first: see `owner_key!`. Return in the words that you type to an agent gives them to the agent, and Tab in
  # a cell goes to the next cell. The window's own editor has no owner, so its keys all go on from here.
  done = owner_key!(owner_of(e), e, w, K, command, select)
  done === :text || return done
  # While the command palette shows, every key is its own, whatever part of it has the keyboard
  e.popup == :commands && return (palette_key!(e, w, K, command); K == Keys.tab ? handled : nothing)
  kind = command === nothing ? :none : COMMANDS[command].kind
  # The commands that close the window and show the settings work whatever has the keyboard. A slider
  # on the settings page takes the keyboard when it's dragged, and ⌘, still closes that window.
  command in (:close, :settings) && return (run!(e, w, command); nothing)
  # While a picture or a model fills the window, the keys are its own. Esc puts the page back.
  zoomed = zooming(e)
  zoomed === nothing || e.popup != :none || zoom_key!(zoomed, K, w, command) !== handled || return
  # The picture, the PDF file or the video that covers a file's own page takes the keys that are its own
  zoomed === nothing && e.popup == :none && file_key!(e, K, w, command) === handled && return
  # While the page shows as slides, the keys go from one slide to another. Esc shows the page again.
  slideshow(e) === nothing || slide_key!(e, K, w, command) !== handled || return
  shift = only_held(w, Keys.shft)
  b = e.buf
  # While a part of a live block has the keyboard, the keys are its own and don't change the text.
  # Escape gives the keyboard back to the text. A command for the window, like the one that saves, still runs.
  if w.focus !== e && w.focus !== input(e)
    if w.focus === find_input(e)
      find_key!(e, w, K, command)
    elseif w.focus === renamer(e)
      rename_key!(e, K)
    elseif K == Keys.escape && unmodified(w)
      hide_menu!(w)
      focus(e)
    elseif command in (:sidebar, :sidebar_keys) && w.focus === file_tree(e)
      # While the sidebar has the keyboard, its two commands give the keyboard back to the text, and the first hides it too
      command == :sidebar && toggle_panel!(e)
      focus(e)
    elseif any(f -> f(e, w, K), values(FIELD_KEYS))
      # Code from the startup page took the key, like Return in a field of a form that it shows
    elseif kind == :window
      run!(e, w, command)
    end
    # Tab goes from one field of a live block to the next. In the field that finds text, and the one
    # that renames a file, it stays where it is.
    return K == Keys.tab && (w.focus === find_input(e) || w.focus === renamer(e)) ? handled : nothing
  end
  e.popup in (:finder, :projects) && return (finder_key!(e, K); K == Keys.tab ? handled : nothing)
  # The list of names under a sheet's expression takes ↑, ↓, Return, Tab and esc
  unmodified(w) && suggest_key!(e, K) && return nothing
  # Esc hides the box that lists what a function takes
  unmodified(w) && call_key!(e, K) && return nothing
  # While the page is read, there's no caret to move, so the keys that would move it scroll the
  # page. A key that would change the text at the caret does nothing. Any other command still
  # works, and one that moves the caret, like undo, puts it back.
  if caretless(b) || readonly(b)
    step = read_step(e, K, command, held_keys(w))
    step === nothing || return (scroll_page!(e, step); nothing)
    K == Keys.escape || kind in (:window, :look, :edit) || return nothing
  end
  # A file that's only shown takes the commands that don't change it. Its text can be selected, copied and searched.
  if readonly(b) && K != Keys.escape
    kind == :window || (kind == :look && b.view != :file) || return nothing
  end
  if K == Keys.escape && finding(e) && unmodified(w)
    close_find!(e)
  elseif K == Keys.escape && unmodified(w)
    # Escape closes a popup. With none open, it takes away what the page's code came to. With
    # none of that either, it hides the caret, and so every line shows as it reads.
    if e.popup != :none
      e.popup = :none
    elseif !isempty(others(b))
      # With several selections, Escape leaves the one that was there first, and the page goes back to it
      b.anchor, b.caret = first(b.others)
      empty!(b.others)
      touch!(e)
    elseif lowered(e) !== nothing
      # The lines of a block that fill the window go back among the lines of the page
      widen!(e)
    elseif !forget_outcomes!(e)
      b.anchor = b.caret
      b.reading = true
    end
  elseif command !== nothing
    run!(e, w, command, select)
  elseif K == Keys.enter && (unmodified(w) || shift)
    each_selection!(() -> newline!(e), e)
  end
  nothing
end

# What a key types comes as a character, so each keyboard types its own letters:
# ß on a German keyboard, é from ⌥E and then E, and an emoji from the Mac's
# emoji list. A key that's held with ⌘ types nothing.
ontype(e::Editor, ev::Typed) = begin
  # The key that types this just ran a command, like ⌥F in the Emacs bundle, so it types nothing
  kept = state_of(e, KeysState)
  muted, kept.mute = kept.mute, 0.0
  time() - muted < 0.5 && return handled
  # A character that a part of a live block didn't take comes here next. It isn't for the text.
  ev.window.focus === e || return nothing
  zooming(e) === nothing || return handled   # the page under a picture that fills the window doesn't change
  c = ev.char
  # macOS has characters of its own for keys like the arrows, which aren't text
  (iscntrl(c) || '\uf700' <= c <= '\uf8ff') && return nothing
  # While the page is read, a key that would change the text does nothing. A file that's only shown is never changed.
  (caretless(e.buf) || readonly(e.buf)) && return nothing
  # Nor does a character change a part that the caret is on as a whole, like a diagram
  picked(e.buf) === nothing || return nothing
  # In code, a bracket or a quote comes with the one that closes it
  each_selection!(() -> pair!(e, c) || type!(e, string(c), typing=true), e)
  # A code block offers names only just after a character is typed
  typed_here!(e)
  # The ( of a call opens the box of what the function takes, and so does a , or a ; in a call
  c in ('(', ',', ';') && call_typed!(e, c)
  handled
end

# --- what code from the startup page adds to -------------------------------------------
#
# Ladder is one program, and code that the startup page loads can add to it.
# That code has Ladder's module, so it calls Ladder's functions as Ladder's own
# files do. The tables here are for the other way: the things that Ladder
# does at its own times, and that such code can have a part in. Each table
# holds functions by a name that the code chooses, like `:email`. So code that
# is loaded twice puts its function in the same place twice, and Ladder calls
# it once.
#
#     Ladder.EACH_FRAME[:email] = e -> look_for_email(e)
#
# Ladder has no table for a kind of block, a command or a key, because it has
# those already: a kind of block goes in `BLOCKS`, `add_insert!` puts it in
# the Insert menu, and `add_commands!` adds commands, with their keys, to the
# ones that the key bindings page lists. `add_command!` makes a function a
# command that the command palette asks the arguments of. It has no table for a folder or a
# file either. Each is an object, and a kind of folder is a type, so code
# writes a method for the type: see `list_files!`.

"More names for the code of a window's pages: `f(m, e)` adds them to the module `m` that the code runs in"
const PAGE_NAMES = Dict{Symbol,Any}()
"A key that code takes while a field of a live block has the keyboard: `f(e, w, K)` is true when it took the key `K`"
const FIELD_KEYS = Dict{Symbol,Any}()
"More folders whose pages show in the settings window as pages of the settings, each by a name"
const SETTINGS_FOLDERS = Dict{Symbol,String}()

"""
Add a kind of block to the Insert menu of a page, before the item called
`before`, or at the end of the blocks. `lines` are what the item writes into
the page, and `caret` is the line of those and the column that the caret goes
to. An item with a name that the menu has takes that item's place.
"""
add_insert!(name::AbstractString, lines, caret; before="Link Card") = begin
  menu = last(PAGE_MENU[findfirst(x -> x isa Pair && first(x) == "Insert", PAGE_MENU)])
  item = (String(name), String.(lines), caret)
  i = findfirst(x -> x isa Tuple && x[1] == name, INSERTS)
  i === nothing || return (INSERTS[i] = item; nothing)
  i = something(findfirst(x -> x isa Tuple && x[1] == before, INSERTS), length(INSERTS))
  insert!(INSERTS, i, item)
  insert!(menu, i, String(name))
  nothing
end

"The buttons that code from the startup page adds to the top bar for the page that shows"
bar_parts(e) = Tuple(Iterators.flatten(f(e) for f in values(BAR_PARTS)))

# `add_commands!` is in additions.jl, with `add_command!`.

# Reset Module gives the page's code a new module: see `reset_module!`
add_commands!("The text", [Command(:reset_module, "Run the page's Julia code in a new, empty module, without what it made before", :window, "",
                                   (e, w, _) -> reset_module!(e))])

# ⌘⇧V pastes a block that was copied from another page as its lines: see "a block that's copied pastes as a part of its page"
add_commands!("The text", [Command(:paste_copy, "Paste a block from another page as a copy of its lines, not as a part of that page", :edit, "cmd+shift+v",
                                   (e, w, _) -> paste_copy!(e))])

# ⌘⌥M puts a comment on the words that are selected: see "comments in the margin"
add_commands!("The text", [Command(:add_comment, "Put a comment on the words that are selected", :edit, "cmd+opt+m", (e, w, _) -> add_comment!(e))])

# ⌘T opens a new tab, and ⌘1 to ⌘9 show the tabs: see "the files that are open, as tabs"
const TAB_ORDINALS = ("first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth")
add_commands!("Files and windows", [
  Command(:new_tab, "Open a new tab, and find a file to show in it", :window, "cmd+t", (e, w, _) -> new_tab!(e)),
  (Command(Symbol(:tab_, n), "Show the $(TAB_ORDINALS[n]) tab", :window, "cmd+$n", (e, w, _) -> show_tab!(e, n)) for n in 1:9)...])

"The commands that show a tab, from ⌘1 to ⌘9"
const TabCommand = Union{(Val{Symbol(:tab_, n)} for n in 1:9)...}
"The palette lists the command that shows a tab only while the window has that tab"
works_here(e, ::V) where V<:TabCommand = length(tabs(top_editor(e))) >= parse(Int, String(V.parameters[1])[5:end])
works_here(e, ::Val{:new_tab}) = !issettings(top_editor(e))

# --- commands that are functions ----------------------------------------------------------
#
# `add_command!` makes a Julia function a command of the command palette: see
# additions.jl. Each file has the commands of its own functions. The ones
# here are the commands of the settings that a command changes, and of the
# Insert menu.

"What the docstring of `f` starts with: its first sentence, without the marks round code and the full stop. With no docstring, it's \"\"."
first_words(f) = String(rstrip(replace(doc_sentence(parentmodule(f), nameof(f)), "`" => ""), '.'))

"The colours of a page, for a command to take: Sepia, Paper or Night"
struct Colours
  name::Symbol
end
choices_for(::Type{Colours}, e) = [Colours(name) for name in THEME_ORDER]
chip_kind(::Type{Colours}) = :choice
worded(c::Colours) = uppercasefirst(String(c.name))
theme!(e, colours::Colours) = theme!(e, colours.name)
add_command!(theme!, title="Use other colours for the page")

"A bundle of key bindings, for a command to take: Ladder's own keys, or the keys of another editor"
struct Bundle
  name::String
end
choices_for(::Type{Bundle}, e) = [Bundle(first(b)) for b in BUNDLES]
chip_kind(::Type{Bundle}) = :choice
worded(b::Bundle) = b.name
"Use the keys of a bundle"
key_bindings!(e, bundle::Bundle) = bundle!(e, bundle.name)
add_command!(key_bindings!, title="Use the keys of another editor")

"An agent that Ladder can start, for a command to take: Claude, Antigravity, Codex or Grok. See \"the agents that Ladder can start\"."
struct AgentChoice
  name::String
end
choices_for(::Type{AgentChoice}, e) = AgentChoice.(listed_agents(e))
chip_kind(::Type{AgentChoice}) = :choice
worded(a::AgentChoice) = a.name
sidenote(a::AgentChoice) = try agent_path(agent_kind(a.name)); "" catch; "not installed" end
"""
Make `agent` the one that Ladder asks for a change or a question, as Settings
does. A page that an agent shares still asks that agent.
"""
switch_agent!(e, agent::AgentChoice) = preferred_agent!(e, agent.name)
runs_at_once(::Val{:switch_agent}) = true
add_command!(switch_agent!, title="Choose the agent that Ladder asks for a change or a question: Claude, Antigravity, Codex or Grok")

"A kind of block that the Insert menu adds, for a command to take"
struct InsertKind
  name::String
end
choices_for(::Type{InsertKind}, e) = [InsertKind(x[1]) for x in INSERTS if x isa Tuple]
worded(k::InsertKind) = k.name
"Add a block of a kind to the page, where the caret is"
insert_block!(e, block::InsertKind) = begin
  e.buf.view == :markdown || error("Only a page of Markdown takes a block.")
  i = findfirst(x -> x isa Pair && first(x) == "Insert", PAGE_MENU)
  j = findfirst(x -> x isa Tuple && x[1] == block.name, INSERTS)
  j === nothing && error("The Insert menu has no $(block.name).")
  page_act!(e, i, j)
end
add_command!(insert_block!, name=:insert, title="Add a block to the page: a table, a sheet, a chart and so on", kind=:edit)













# The command palette asks whether it's on or off. See "the start of a page in a link's card".
