# The menu of the page, which a right-click on the page opens

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered
@use "github.com/jkroso/UI.jl/Interface/window" system_menu
@use "./spelling" guesses
@use "./markdown" Kind Line Cell tablecells front_matter
@use "./sheet" SHEET
@use "./spreadsheet" SPREADSHEET
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
@use "./sketch_view" exports...
@use "./math_view" exports...
@use "./takeoff_view" exports...
@use "./map_view" exports...
@use "./sheet_view" exports...
@use "./columns_view" exports...
@use "./board_view" exports...
@use "./calendar_view" exports...
@use "./gallery_view" exports...
@use "./check_view" exports...
@use "./canvas_view" exports...
@use "./find_view" exports...
@use "./contact_view" exports...
@use "./signature_view" exports...
@use "./result_block" exports...
@use "./slides_view" exports...
@use "./email_view" exports...
@use "./media_view" exports...
@use "./page_extras" exports...
@use "./form_view" exports...
@use "./code_thing" exports...
@use "./agent/ask" exports...
@use "./day_view" exports...
@use "./copied_blocks" exports...
@use "./editing" exports...

export INSERTS, PAGE_MENU, add_front_matter!, context_menu!, cut!, page_act!, page_menu!

# --- the menu of the page ------------------------------------------------------------------
#
# A right-click on the page opens a menu at the mouse: cut, copy, paste, select
# all, find, export, Insert and Show as Slides. On a word that's spelt wrong, the menu starts
# with the words it may have been meant to be. Insert opens a menu of the kinds of block that a page can
# hold. A right-click on the selection keeps it. Anywhere else, it puts the
# caret there first.

"""
What the Insert menu adds. Each one has its name, the lines of the block, and
the line and the column of the block that the caret goes to. "-" is a line
between two groups.
"""
const INSERTS = [
  ("Paragraph",     [""],                           (1, 0)),
  ("Heading 1",     ["# "],                         (1, 2)),
  ("Heading 2",     ["## "],                        (1, 3)),
  ("Heading 3",     ["### "],                       (1, 4)),
  "-",
  ("Bulleted List", ["- "],                         (1, 2)),
  ("Numbered List", ["1. "],                        (1, 3)),
  ("To-do",         ["- [ ] "],                     (1, 6)),
  ("Quote",         ["> "],                         (1, 2)),
  ("Callout",       ["> [!NOTE]", "> "],            (2, 2)),
  "-",
  ("Table",         ["|  |  |  |", "|---|---|---|", "|  |  |  |", "|  |  |  |"], (1, 2)),
  block_insert(SHEET),
  block_insert(SPREADSHEET),
  ("Code",          ["```julia", "", "```"],        (2, 0)),
  block_insert(LIVE),
  block_insert(DIAGRAM),
  ("Formula",       ["\$\$", "", "\$\$"],           (2, 0)),
  # An agent writes a question and a set of changes, so the menu has neither
  (block_insert(lang) for lang in (TAKEOFF, SCHEDULE, CHART, BOARD, CALENDAR, DAY_BLOCK, COLUMN_BLOCK, FIND,
                                   CHECK, FILTER, SAVE, LOAD, FORM, SKETCH, CANVAS, VIEW_BLOCK, RESULT,
                                   SIGNATURE, CONTACT, GALLERY, MAP, TIMELOG))...,
  # A card is the address of a page, written as a picture's is. The caret goes after the https://.
  ("Link Card",     ["![](https://)"],              (1, 12)),
  # This one records from the microphone into a new file, and the line shows the recorder. The caret goes
  # to an empty line under it, so that you can type while it records.
  ("Recording",     ["![Recording]()", "", ""],     (3, 0)),
  "-",
  # The caret goes to an empty line under the divider
  ("Divider",       ["---", "", ""],                (3, 0)),
  "-",
  # This one goes at the top of the document, wherever the caret is
  ("Front Matter",  ["---", "title: ", "---"],      (2, 7)),
]

# Ask Agent… shows with the name of the agent that it asks, like "Ask Claude…": see `page_menu!`
const PAGE_MENU = ["Ask Agent…", "-", "Cut", "Copy", "Paste", "-", "Select All", "-", "Find…", "Export as HTML…", "-",
                   "Insert" => [x isa String ? x : x[1] for x in INSERTS], "-", "Show as Slides"]

cut!(e) = begin
  run = picked(e.buf)
  copied = copy_selection!(e)
  COPIED_BLOCK[] = nothing   # a block that's cut leaves its page, so it pastes as its lines
  copied === false && return false
  # The part that the caret was on as a whole goes, as ⌫ takes it
  run === nothing ? each_selection!(() -> type!(e, ""), e) : delete_lines!(e)
end
select_all!(e) = begin
  b = e.buf
  b.reading = false   # a selection shows the caret's end of it
  # In a part of another page, it's all of the part
  s, t = hosted(e) === nothing ? (1, length(b.lines)) : shown_span(e)
  b.anchor, b.caret = (s, 0), line_end(b, t)
  e
end

"The last line of the block that line `i` is in: the end of its table or of its code block, or the line itself"
block_end(b::Buffer, i::Int) = begin
  k = kinds(b)[i].kind
  k == Kind.table ? table(b, i)[2] : k in (Kind.fence, Kind.code) ? codeblock(b, i)[2] : i
end

"""
Add a block of `lines` to the document, and put the caret at `at`: a line and
a column of the block. On an empty line, the block takes that line's place.
From any other line, it goes after the block that the caret is in. An empty
line goes between the new block and the text on each side of it. A list item
that's added to a list of its own kind goes straight after the item before it.
"""
add_block!(e, lines::Vector{String}, at::Pos) = begin
  b = e.buf
  ks = kinds(b)
  i = b.caret[1]
  onblank = ks[i].kind == Kind.blank
  t = onblank ? i : block_end(b, i)
  before, after = (onblank ? i - 1 : t), t + 1   # the lines that the block will sit between
  blank(j) = !(1 <= j <= length(ks)) || ks[j].kind == Kind.blank
  kind = Line(lines[1]).kind
  item = kind in (Kind.bullet, Kind.ordered, Kind.todo)
  joins = item && !blank(before) && ks[before].kind == kind
  if joins
    # It's the next item of that list: the next number, and as far in as the item before
    lead = carry(head(b.lines[before], ks[before].prefix), kind)
    lines, at = [lead], (1, length(lead))
  end
  pre = !joins && !blank(before)
  post = !blank(after) && !(item && ks[after].kind == kind)
  new = join([pre ? [""] : String[]; lines; post ? [""] : String[]], "\n")
  onblank ? edit!(b, (i, 0), line_end(b, i), new) : edit!(b, line_end(b, t), line_end(b, t), "\n" * new)
  row = (onblank ? i : t + 1) + pre + at[1] - 1
  b.caret = b.anchor = (row, at[2])
  # In a new table, the first cell is selected, as Tab would leave it
  cells = kinds(b)[row].kind == Kind.table ? tablecells(b.lines[row]) : Cell[]
  isempty(cells) || (b.anchor = (row, cells[1].lo); b.caret = (row, cells[1].hi))
  focus(e)
  touch!(e)
end

"""
Add front matter to the top of the document, and put the caret after its first
key. A document has front matter only once, so if it's there already the caret
just goes to it.
"""
add_front_matter!(e) = begin
  b = e.buf
  if front_matter(b.lines) == 0
    _, lines, _ = last(INSERTS)
    # An empty line goes between the front matter and the text
    edit!(b, (1, 0), (1, 0), join(lines, "\n") * "\n" * (isempty(strip(b.lines[1])) ? "" : "\n"))
  end
  b.caret = b.anchor = line_end(b, 2)
  focus(e)
  touch!(e)
end

"Do what the item at `i` of the page's menu does. `j` is the item's place in the Insert menu, when it's one of those."
page_act!(e, i::Int, j::Int=0) = begin
  name = PAGE_MENU[i] isa Pair ? first(PAGE_MENU[i]) : PAGE_MENU[i]
  if name == "Ask Agent…"
    ask_selected!(e)
  elseif name == "Cut"
    cut!(e)
  elseif name == "Copy"
    # While an email as it was sent has the keyboard, what's selected is its words
    a = sent_keys(e)
    a === nothing ? copy_selection!(e) : sent_copy!(a)
  elseif name == "Paste"
    paste!(e)
  elseif name == "Select All"
    a = sent_keys(e)
    a === nothing || a.of.shown === nothing ? select_all!(e) : sent_select_all!(a)
  elseif name == "Find…"
    find!(e)
  elseif name == "Export as HTML…"
    w = window_of(e)
    w === nothing || export_html!(e, w)
  elseif name == "Show as Slides"
    show_slides!(e)
  elseif name == "Insert" && j in eachindex(INSERTS) && INSERTS[j] isa Tuple
    block = INSERTS[j][1]
    block == "Front Matter" ? add_front_matter!(e) : block == "Recording" ? add_recording!(e) : add_block!(e, INSERTS[j][2], INSERTS[j][3])
  end
  nothing
end

"Show the page's menu at the mouse"
page_menu!(e, w) = begin
  b = e.buf
  b.view == :file && return nothing   # a viewer has no text to copy or to find
  e.popup = :none
  focus(e)
  at = settle(b, locate(e, w.mouse))
  # A right-click on a part that shows as one thing, like a formula or a diagram, puts the caret on it as a whole, as a click does
  it = isempty(e.layout) ? nothing : e.layout[item_under(e, w.mouse[1] - e.origin[1], w.mouse[2] - e.origin[2])]
  it !== nothing && it.content isa Live && rich(b) && !b.fixed && part(b, it.first) == (it.first, it.last) && (at = (it.first, 0))
  lo, hi = selection(b)
  # A right-click on the selection keeps it. Anywhere else, it puts the caret there.
  if !(selecting(b) && lo <= at <= hi)
    b.caret = b.anchor = at
    touch!(e)
  end
  # A right-click on a word that's spelt wrong puts the words it may have been meant to be at the top of the menu
  wrong = misspelling_at(e, at)
  fixes = wrong === nothing ? String[] : first(guesses(rest(head(b.lines[wrong[1]], wrong[3]), wrong[2])), 5)
  spell = wrong === nothing ? Any[] : Any[(isempty(fixes) ? ["No Guesses Found"] : fixes)..., "Learn Spelling", "-"]
  n = length(spell)
  act(i, place...) = i <= n ? spell_act!(e, wrong, fixes, i) : page_act!(e, i - n, place...)
  # Cut and Copy are grey with nothing selected, and Front Matter is grey in a document that has it
  off = Any[]
  wrong !== nothing && isempty(fixes) && push!(off, 1)
  selecting(b) || append!(off, n .+ findall(in(("Cut", "Copy")), PAGE_MENU))
  front_matter(b.lines) == 0 || push!(off, (n + findfirst(x -> x isa Pair, PAGE_MENU), length(INSERTS)))
  # Each item that would change the text is grey for a file that's only shown
  readonly(b) && append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Cut", "Paste", "Export as HTML…", "Insert", "Show as Slides"), PAGE_MENU))
  b.fixed && append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Cut", "Paste", "Insert"), PAGE_MENU))
  # A file of code is no page, and has no place for a table or a recording
  b.view == :code && append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Export as HTML…", "Insert", "Show as Slides"), PAGE_MENU))
  # A part of another page isn't the page that the window shows
  hosted(e) === nothing || append!(off, n .+ findall(x -> (x isa Pair ? first(x) : x) in ("Find…", "Export as HTML…", "Show as Slides"), PAGE_MENU))
  # Ask Agent… names the agent that it asks
  items = Any[spell..., (x == "Ask Agent…" ? "Ask $(asks_whom(e))…" : x for x in PAGE_MENU)...]
  system_menu(w, items, act; off) || drawn_menu!(w, items, act; off)
  nothing
end

"Show the menu for what the mouse is over: the page, or a file in the sidebar"
context_menu!(e, w) = begin
  # The text is the editor's own node, so the mouse can be over it and not over the area around it
  onpage = ishovered(node!(Document, e, :document)) || ishovered(node!(Page, e, :page))
  onpage ? page_menu!(e, w) : file_menu!(e, w)
end
