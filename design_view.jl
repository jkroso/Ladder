# A SolidCraft design in the page: its fields and the sheet of its parameters
#
# A file whose name ends in .sc is a design of SolidCraft, a program for
# drawing solid parts. It opens in an editor that's laid out as SolidCraft's
# own window is: the design in 3D, a toolbar of commands, a browser of its
# bodies and sketches, and the history of its steps. cad/view.jl is the
# editor, and says how it's used.
#
# Ladder has no code of its own that works out a solid shape. SolidCraft.app
# has a program inside it that does that with no window, and Ladder starts it
# for each design that's open: see cad/engine.jl. On a Mac without SolidCraft,
# the page shows the picture that SolidCraft saved in the file.
#
# A change is in that program only, until ⌘S writes the file. A design with
# changes that aren't saved keeps its program while the window shows other
# files, as a page keeps its changes. A design with no changes gives its
# program up when the window leaves it.
#
# A window that closes ends the programs of its designs, and what they didn't
# save is lost. So a window with a design that has changes asks before it
# closes: Save, Don't Save or Cancel. It asks when its red button is clicked,
# when ⌘W closes it, and when Ladder quits.

@use "github.com/jkroso/Prospects.jl" @def
@use GLFW
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" tabstop tabbed! USUAL_PX
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode Theme with_theme describe window_of focus handled version
@use "github.com/jkroso/UI.jl/Interface/draw" cursor hittest redraw_in! rect popup! close_popup!
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" problem
@use "./markdown" words
@use "./sheet" SHEET Given sheetcells parts
@use "./cad/view" => Designs
@use "github.com/jkroso/UI.jl/Interface/draw" tab!
@use "github.com/jkroso/URI.jl/FS" => FS
@use Colors: @colorant_str, RGBA
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./sketch_view" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./run_code" exports...

export DesignFile, design_part, DesignField, FIELD_PAD, FIELD_ROOM, FIELD_BOX_COLS, follow_page!,
       field_outcome!, box_room, FIELD_H, design_key!, field_key, SHEET_OPEN, mend!, sheet_key, leave_design!,
       designs, unsaved_designs, close_designs!, closes!, CloseAsk, close_now!, save_and_close!, watch_close!

const DesignFile = Union{FS.File{:sc},FS.File{:SC},FS.File{:solidcraft}}
push!(BLOCK_ICONS, "arrow-counterclockwise", "arrow-clockwise", "save", "x-lg", "x", "check-lg", "chevron-down", "chevron-right", "eye", "eye-slash",
      "house", "skip-start-fill", "caret-left-fill", "caret-right-fill", "skip-end-fill")

"""
What shows the SolidCraft design at `path` in the window of `e`. Its fields are
Ladder's editor of text, and its parameters are a sheet: see "the fields of a
SolidCraft design" and "the sheet of a SolidCraft design's parameters".
"""
design_part(e, path) = node!(() -> Designs.DesignView(path=path), e, (:design, path))

"How code looks in a field of a SolidCraft design: the colours of the page's code blocks, and its font of code"
Designs.code_look(v::Designs.DesignView) = (colours, codefont())

# --- the fields of a SolidCraft design --------------------------------------------------
#
# A field to type in, in the editor of a SolidCraft design, is Ladder's own
# editor of text, as the field of a request in place is (see `ask_editor`).
# Its text selects, and its keys work, as they do on a page.
#
# A field of a length, an angle or a count holds Julia code. It's a file of
# Julia code with no file, so its code has the colours of code, and ⌘Return
# runs it, or the part of it that's selected, as it runs code in a Julia
# file. The code runs in the design's module, which has the units and the
# design's parameters: see cad/expressions.jl. What it comes to shows in the
# box that a Julia file shows, after the code, in the field. A click on a box
# that has more opens it, and the rest shows under the field. The box goes
# when the code changes.
#
# Return is the form's: it gives the form to SolidCraft, as OK does. Tab goes
# to the next field, and ⇧Tab to the one before. Esc, ⌘S and the window's own
# keys go to the design, then to the window. ⌘Z takes back what was typed in
# the field, and when nothing was, the design's last change.
#
# A field is as wide as its text and its box need. The panel at the right is
# as wide as its widest field needs, up to half the design: see
# `side_width!` in cad/view.jl. Text that's longer than that goes on to the
# next line, and the field gets taller.

"A field to type in, in the editor of a SolidCraft design: see \"the fields of a SolidCraft design\""
@def mutable struct DesignField <: SemanticUI
  sub::Any = nothing          # the editor of its text
  code::Bool = false          # it holds Julia code
  placeholder::String = ""    # what it says while it has no text
  room::Any = nothing         # how wide the panel has room for it to be, or nothing before the panel says
  took::Bool = false          # the editor of its text took the last key, which goes no further: see `design_key!`
end

const FIELD_PAD = 9px        # between the edge of a field of a design and its text
const FIELD_ROOM = 160px     # how wide a field of a design is before the panel says
const FIELD_BOX_COLS = 32    # the most characters that the box of what a field's code came to shows

"""
A field of the design `v` that holds `text`, with `placeholder` while it's
empty, and that holds Julia code when `code`. Its editor's keys that the
field has no use for go to the design.
"""
Designs.new_field(v::Designs.DesignView, text, placeholder, code::Bool) = begin
  f = DesignField(code=code, placeholder=String(placeholder))
  sub = Editor()
  lines = String.(split(text, '\n'))
  sub.buf = code ? Buffer(lines=lines, view=:code, lang="julia") : Buffer(lines=lines)
  sub.buf.caret = sub.buf.anchor = line_end(sub.buf, length(lines))
  sub.nodes[:input] = own!(sub, TextInput())
  sub.nodes[:design_field] = f
  setfield!(sub, :parent, f)
  f.sub = sub
  f
end

"The field of a SolidCraft design that the editor `e` is the text of, or nothing for any other editor"
design_field_of(e) = get(e.nodes, :design_field, nothing)

"""
Give the editor of the field `f` the colours and the keys of the page that
shows the design, and the size of a field's text. Its lines wrap at the
field's edge, and it has no numbers of lines.
"""
follow_page!(f::DesignField) = begin
  sub = f.sub
  follow_host!(sub, editor(f.parent))
  size = num(Designs.field_size(f.parent))
  sub.numbers = sub.shade = false
  sub.guide = 0
  sub.wrap = true
  sub.font, sub.look = SANS, :own
  sub.zoom = f.code ? size / (num(TEXT_SIZE) * sub.code_scale) : size / num(TEXT_SIZE)
  # Text that was laid out at another size is laid out again
  key = (sub.zoom, sub.font)
  get(sub.nodes, :field_style, nothing) == key || (sub.nodes[:field_style] = key; empty!(sub.flows))
  f
end

"""
The box of what the code of the field `f` came to when ⌘Return last ran it,
with what it shows set for a field, or nothing when its code hasn't run or
has changed since.
"""
field_outcome!(f::DesignField) = begin
  f.code || return nothing
  sub = f.sub
  list = follow_outcomes!(sub)
  isempty(list) && return nothing
  o = last(list)
  size = body(sub).size * 0.8   # as a page's box is beside its text
  o.size, o.high = size, px(round(num(size * 1.7)))
  o.low = nothing   # a field has no levels
  o.shown = length(o.brief) > FIELD_BOX_COLS ? first(o.brief, FIELD_BOX_COLS - 1) * "…" : o.brief
  o.rest = o.shown == o.brief ? String(chopprefix(chopprefix(o.full, o.brief), "\n")) : o.full
  o.from = o.shown == o.brief ? 2 : 1
  o.more = o.node !== nothing || o.subject !== nothing || o.whole !== nothing || !isempty(o.rest)
  o.across = 0px   # the rest is under the field, and not under the box
  o
end

"How wide the box `o` of a field is, with the gap before it, or 0px for no box"
box_room(o) = o === nothing ? 0px : OUTCOME_GAP + outcome_wide(o, measure(outcome_face(o.size), "0"))

"""
The theme `t` at the usual size, in which a length in pixels is that many
pixels, as it is on a page. The design's theme is smaller, and a page's text
and the box of what code came to are laid out in pixels that aren't scaled.
"""
unscaled(t::Theme) = Theme(; (n => getfield(t, n) for n in fieldnames(Theme) if n != :size)..., size=px(USUAL_PX))

describe(f::DesignField) = begin
  sub = f.sub
  follow_page!(f)
  run_tick!(sub)   # what code that runs in a thread of its own came to
  w = window_of(f)
  on = w !== nothing && w.focus === sub
  b = sub.buf
  # The selection shows only while the field has the keyboard
  on || (b.anchor = b.caret)
  # The design's theme. UI.jl can describe the field in more than one theme in a frame, and each must lay it out the same.
  t = Designs.theme(f.parent)
  o = field_outcome!(f)
  # A field that the panel hasn't told how wide it is is as wide as it was in the last frame
  r = f.room === nothing ? rect(f) : nothing
  wide = f.room !== nothing ? f.room : r !== nothing ? r.width : FIELD_ROOM
  # The text wraps at the field's edge, before the box of what its code came to
  room = max(wide - 2FIELD_PAD - 2px - box_room(o), 24px)
  layout!(sub, room)
  tall = isempty(sub.layout) ? FIELD_H : lowest(sub, sub.layout)
  one = length(sub.layout) == 1 && sub.layout[1].content isa Flow && length(sub.layout[1].content.lines) == 1
  # On one line, the box is just after the text, as it is after a line of a Julia file
  across = o !== nothing && one ? min(extent(sub.layout[1].content) + 2px, room) : room
  # The text and the box are made in the theme at its usual size, so they're as big as they were laid out
  with_theme(unscaled(t)) do
    doc = Row(fixed(across), height(tall), Alignment.Start, clip_x=true, node!(Document, sub, :document))
    # With nothing typed, the field says what it's for, under where the text goes
    empty = b.lines == [""]
    text = empty && !isempty(f.placeholder) ?
      Stack(fixed(across), height(tall), Alignment.Start,
            Row(width(grow=grow), height(tall), Alignment.Center, label(f.placeholder, Designs.field_size(f.parent), color=t.dim)), doc) : doc
    Row(width(grow=grow), height(max(FIELD_H, tall + 6px)), padding(FIELD_PAD, 0px), child_gap=OUTCOME_GAP, one ? Alignment.Center : Alignment.End,
        Designs.field_look(t)[2:end]..., name="Field", text, (o === nothing ? () : (o,))...)
  end
end

const FIELD_H = Designs.FIELD_H

# A click on the field, past its text, puts the caret in the text. A click on the text was the text's, and comes here after.
onkey(f::DesignField, ev::KeyPress{Keys.mouse_left}) = (hittest(ev.window) === f && press!(f.sub, ev.window.mouse); handled)
cursor(::DesignField) = :ibeam

# A key that the editor of its text took goes no further. The editor gives no `handled`, and the design would take it too, as ⌘Z.
onkey(f::DesignField, ::KeyPress) = f.took ? (f.took = false; handled) : nothing

# The keyboard goes to the editor of its text. Tab stops at the field, and selects all of its text.
focus(f::DesignField) = focus(f.sub)
tabstop(::DesignField) = true
tabbed!(f::DesignField) = (Designs.select_all!(f); nothing)

"""
What a key does in a field of a SolidCraft design, before its editor does
what it does with a key: `handled`, nothing when the key goes on to the
design and then the window, or :text when the editor does what it does with
the key. See "the fields of a SolidCraft design".
"""
design_key!(f::DesignField, e, w, K, command) = begin
  done = field_key(f, e, w, K, command)
  f.took = done === :text
  done
end
field_key(f::DesignField, e, w, K, command) = begin
  # While the list of parameters shows under the field, ↑ ↓ Return Tab and Esc are the list's: see cad/view.jl
  K in (Keys.up, Keys.down, Keys.enter, Keys.tab, Keys.escape) && unmodified(w) && Designs.names_key!(f, w, K) && return handled
  K in (Keys.enter, Keys.escape) && return nothing
  if K == Keys.tab
    # The field is the tab stop, and not its editor. A form with no other field keeps the keyboard in this one.
    w.focus = f
    tab!(w, only_held(w, Keys.shft) ? -1 : 1) === handled || (w.focus = e)
    return handled
  end
  command === nothing && return :text
  b = e.buf
  # ⌘Z takes back the design's last change when the field has nothing of its own to take back
  command == :undo && isempty(b.undo) && return nothing
  command == :redo && isempty(b.redo) && return nothing
  command_kind(command) == :window || command in (:commands, :find, :find_next, :find_last, :plain, :slides, :forward) ? nothing : :text
end

Designs.text_of(f::DesignField) = join(f.sub.buf.lines, '\n')
Designs.set_text!(f::DesignField, text) = begin
  b = f.sub.buf
  edit!(b, (1, 0), line_end(b, length(b.lines)), String(text))
  # The design put it there, so ⌘Z in the field doesn't take it back
  empty!(b.undo)
  empty!(b.redo)
  f
end
Designs.select_all!(f::DesignField) = (select_all!(f.sub); f)
Designs.before_caret(f::DesignField) = (b = f.sub.buf; b.anchor == b.caret ? first(b.lines[b.caret[1]], b.caret[2]) : nothing)
Designs.complete!(f::DesignField, n, name) = (b = f.sub.buf; edit!(b, (b.caret[1], b.caret[2] - n), b.caret, String(name)); f)
Designs.keyed(e::Editor) = something(design_field_of(e), e)
Designs.isfield(::DesignField) = true
Designs.iscode(f::DesignField) = f.code
Designs.room!(f::DesignField, wide) = (f.room = wide; f)

"How wide the field `f` needs to be to show its whole text, and the box of what its code came to, on one line"
Designs.wants(f::DesignField) = begin
  follow_page!(f)
  sub = f.sub
  b = sub.buf
  ks = kinds(b)
  text = maximum(i -> measure(face(sub, ks[i]), b.lines[i]), eachindex(b.lines))
  b.lines == [""] && (text = measure(face(sub, ks[1]), f.placeholder))
  num(text + box_room(field_outcome!(f)) + 2FIELD_PAD + 2px + 3px)
end

"""
Run the code of the field `f`, or the part of it that's selected, as ⌘Return
does in a Julia file: in the design's module, with each parameter as it is
now. What it comes to shows after the code, in the field.
"""
Designs.run_field!(v::Designs.DesignView, f::DesignField) = begin
  sub = f.sub
  sub.nodes[:workspace] = Designs.workspace!(v)
  run_here!(sub)
  v
end

"The rest of what the field's code came to, under the field while its box is open, or nothing"
Designs.under(f::DesignField) = begin
  o = field_outcome!(f)
  (o === nothing || !(o.open && o.more)) && return nothing
  sub = f.sub
  o.body === nothing && (o.body = own!(sub, OutcomeBody(of=o)))
  d = o.body
  cell = measure(outcome_face(o.size), "0")
  most = something(f.room, FIELD_ROOM)
  if o.whole !== nothing
    d.members === nothing && (d.members = member_lines(d, o.whole, 0))
    cols = max(maximum(length, printed_rest(o), init=0), maximum(member_cols, unfolded(d.members), init=0))
    d.wide = min(cell * cols, most - 19px)
    d.tall = MEMBERS_H
  end
  across = o.subject !== nothing ? detail_wide(sub) : o.node !== nothing ? OUTCOME_NODE_W + 22px :
           (o.whole !== nothing ? d.wide : cell * maximum(length, split(o.rest, '\n'))) + 19px
  d.across = min(across, most)
  d.corners = radius(OUTCOME_ROUND)
  with_theme(() -> Box(Alignment.Start, d), unscaled(Designs.theme(f.parent)))
end

# --- the sheet of a SolidCraft design's parameters -----------------------------------------
#
# The panel of a design's parameters is a sheet, as a `sheet` block of a page
# is, and Ladder's editor of a page edits it: see "the sheet of parameters" in
# cad/view.jl. The editor holds a page with one sheet on it, a row for each
# parameter. The lines that open and close the block never show. The caret
# stays off them, and a key that would change them is taken back.
#
# Each row works itself out as a page's sheet does, with the design's units,
# like deg, and with the value of each parameter of the design as SolidCraft
# has it. So a row can use a parameter whose row is under it, and a row takes
# the name from the design's value.
#
# The list of names under a row's code is the design's, as in a field of code,
# with each parameter's value. The keys work as they do in a page's sheet: Tab
# goes to the next cell, and Return starts a row. Esc, ⌘S and the window's
# keys go to the design, then to the window. ⌘Z takes back what was typed, and
# when nothing was, the design's last change.

const SHEET_OPEN = "```" * SHEET   # the line that opens the block of the sheet

"The sheet of the parameters of the design `v`, with one empty row"
Designs.new_sheet(v::Designs.DesignView) = begin
  s = DesignSheet()
  sub = Editor()
  sub.buf = Buffer(lines=[SHEET_OPEN, " = ", "```"])
  sub.buf.caret = sub.buf.anchor = (2, 0)
  sub.nodes[:input] = own!(sub, TextInput())
  sub.nodes[:design_field] = s
  setfield!(sub, :parent, s)
  s.sub = sub
  s
end

"""
Give the editor of the sheet `s` the colours and the keys of the page that
shows the design, with text of `Designs.sheet_size`. Its rows have the names of
the design's parameters, with their values.
"""
follow_page!(s::DesignSheet) = begin
  sub = s.sub
  follow_host!(sub, editor(s.parent))
  sub.wrap = true
  sub.font, sub.look = SANS, :own
  # `sheetgrid` makes a sheet's text 0.86 times as big as the page's
  sub.zoom = num(Designs.sheet_size(s.parent)) / (num(TEXT_SIZE) * 0.86)
  key = (sub.zoom, sub.font)
  get(sub.nodes, :field_style, nothing) == key || (sub.nodes[:field_style] = key; empty!(sub.flows))
  v = s.parent
  version = v.model === nothing ? -1 : v.model.version
  if s.names === nothing || s.names[1] != version
    s.names = (version, Tuple{String,Any}[(String(p["name"]), Given(x)) for p in Designs.every_param(v)
                                          for x in (Designs.Expressions.value_of(p),) if x !== nothing])
  end
  sub.nodes[:sheet_names] = s.names[2]
  s
end

"""
Keep the sheet `s` a sheet: a key that changed the lines that open and close
its block is taken back, and the caret stays in its rows.
"""
mend!(s::DesignSheet) = begin
  b = s.sub.buf
  whole(b) = (n = length(b.lines); n >= 3 && b.lines[1] == SHEET_OPEN && b.lines[n] == "```" && !any(l -> startswith(lstrip(l), "```"), view(b.lines, 2:n-1)))
  if !whole(b)
    isempty(b.undo) || (undo!(b); pop!(b.redo))
    whole(b) || Designs.set_rows!(s, [parts(l) for l in b.lines if !startswith(lstrip(l), "```")])
  end
  n = length(b.lines)
  inside(p) = p[1] <= 1 ? (2, 0) : p[1] >= n ? line_end(b, n - 1) : p
  b.caret, b.anchor = inside(b.caret), inside(b.anchor)
  s
end

describe(s::DesignSheet) = begin
  sub = s.sub
  follow_page!(s)
  mend!(s)
  w = window_of(s)
  b = sub.buf
  # The selection shows only while the sheet has the keyboard
  (w !== nothing && w.focus === sub) || (b.anchor = b.caret)
  t = Designs.theme(s.parent)
  # A sheet that the panel hasn't told how wide it is is as wide as it was in the last frame
  r = s.room === nothing ? rect(s) : nothing
  wide = s.room !== nothing ? s.room : r !== nothing ? r.width : FIELD_ROOM
  layout!(sub, wide)
  tall = isempty(sub.layout) ? FIELD_H : lowest(sub, sub.layout)
  # The sheet is made in the theme at its usual size, so it's as big as it was laid out: see `DesignField`
  with_theme(unscaled(t)) do
    Row(fixed(wide), height(tall), Alignment.Start, name="Parameters", node!(Document, sub, :document))
  end
end

# A click on the sheet gives it the keyboard, and goes no further: the design would take the keyboard back. A click on
# the text was the text's, and comes here after. One past the text puts the caret in the nearest row.
onkey(s::DesignSheet, ev::KeyPress{Keys.mouse_left}) = (hittest(ev.window) === s && press!(s.sub, ev.window.mouse); mend!(s); handled)
cursor(::DesignSheet) = :ibeam

# A key that the editor took goes no further. The design would take it too, as ⌘Z.
onkey(s::DesignSheet, ::KeyPress) = s.took ? (s.took = false; mend!(s); handled) : nothing
focus(s::DesignSheet) = focus(s.sub)

"""
What a key does in the sheet of a design's parameters, before its editor does
what it does with a key: `handled`, nothing when the key goes on to the
design and then the window, or :text when the editor does what it does with
the key. See "the sheet of a SolidCraft design's parameters".
"""
design_key!(s::DesignSheet, e, w, K, command) = begin
  done = sheet_key(s, e, w, K, command)
  s.took = done === :text
  done
end
sheet_key(s::DesignSheet, e, w, K, command) = begin
  # While the list of parameters shows under the row, ↑ ↓ Return Tab and Esc are the list's: see cad/view.jl
  K in (Keys.up, Keys.down, Keys.enter, Keys.tab, Keys.escape) && unmodified(w) && Designs.names_key!(s, w, K) && return handled
  K == Keys.escape && return nothing
  b = e.buf
  # ⌘A selects the rows, and not the lines of the block round them
  command == :select_all && ((b.anchor, b.caret) = ((2, 0), line_end(b, length(b.lines) - 1)); touch!(e); return handled)
  command === nothing && return :text
  # ⌘Z takes back the design's last change when the sheet has nothing of its own to take back
  command == :undo && isempty(b.undo) && return nothing
  command == :redo && isempty(b.redo) && return nothing
  command_kind(command) == :window || command in (:commands, :find, :find_next, :find_last, :plain, :slides, :forward) ? nothing : :text
end

Designs.text_of(s::DesignSheet) = join(s.sub.buf.lines, '\n')
Designs.sheet_rows(s::DesignSheet) = (b = s.sub.buf; Tuple{String,String}[parts(l) for l in view(b.lines, 2:length(b.lines)-1)])
Designs.caret_row(s::DesignSheet) = s.sub.buf.caret[1] - 1
Designs.sent!(s::DesignSheet) = (b = s.sub.buf; empty!(b.undo); empty!(b.redo); s)
Designs.isfield(::DesignSheet) = true
Designs.iscode(::DesignSheet) = true
Designs.room!(s::DesignSheet, wide) = (s.room = wide; s)

Designs.set_rows!(s::DesignSheet, rows) = begin
  b = s.sub.buf
  at, name = b.caret, Designs.caret_name(s)
  lines = isempty(rows) ? [" = "] : ["$n = $c" for (n, c) in rows]
  edit!(b, (1, 0), line_end(b, length(b.lines)), join([SHEET_OPEN; lines; "```"], '\n'))
  # The design put the rows there, so ⌘Z in the sheet doesn't take them back
  empty!(b.undo)
  empty!(b.redo)
  # The caret stays in the row with the same name, or else on the same row
  k = name === nothing ? nothing : findfirst(r -> r[1] == name, rows)
  i = clamp(k === nothing ? at[1] : k + 1, 2, length(b.lines) - 1)
  b.caret = b.anchor = (i, min(at[2], length(b.lines[i])))
  s
end

"The code of the row with the caret, before the caret, or nothing when the caret isn't in a row's code or text is selected"
Designs.before_caret(s::DesignSheet) = begin
  b = s.sub.buf
  b.anchor == b.caret || return nothing
  i, col = b.caret
  1 < i < length(b.lines) || return nothing
  cs = sheetcells(b.lines[i])
  (length(cs) == 2 && nearest(cs, col) == 2 && col >= cs[2].lo) || return nothing
  String(collect(b.lines[i])[cs[2].lo+1:col])
end
Designs.complete!(s::DesignSheet, n, name) = (b = s.sub.buf; edit!(b, (b.caret[1], b.caret[2] - n), b.caret, String(name)); s)

"Where the list of parameters shows: under the name being typed, which is the last `n` characters before the caret"
Designs.names_place(s::DesignSheet, n) = begin
  sub = s.sub
  d = rect(node!(Document, sub, :document))
  it = isempty(sub.layout) ? nothing : sub.layout[1]
  (d === nothing || it === nothing || !(it.content isa Sheet)) && return (s, Designs.menu_width(s, 180px))
  g = it.content
  i, col = sub.buf.caret
  r = findfirst(==(i), g.rows)
  r === nothing && return (s, Designs.menu_width(s, 180px))
  f, dx = cellflow(g, r, length(g.cells[r]))
  k, x = spot(f, max(col - n, 0))
  ((d.left + dx + x - 9px, d.top + it.top + row_top(g, r) + f.lh * (k - 1), 1px, f.lh), 180px)
end

"How wide the sheet `s` needs to be to show each row on one line: its name, its code and what that comes to"
Designs.wants(s::DesignSheet) = begin
  sub = s.sub
  follow_page!(s)
  size = body(sub).size * 0.86
  ink = Face(SHEET_FONT, SHEET_WEIGHT, size, colours.ink, false)
  rows = Designs.sheet_rows(s)
  name = max(maximum(r -> measure(ink, r[1]), rows, init=0px) + 2px, 3size)
  code = maximum(r -> measure(ink, r[2]), rows, init=0px)
  g = isempty(sub.layout) ? nothing : sub.layout[1].content
  chip = g isa Sheet ? maximum(r -> chip_w(ink, r), g.results, init=0px) : 0px
  # As `sheetgrid` lays a row out, with a little more for the names in the code, which are chips
  num(name + code + chip + 7SHEET_X + 3px)
end

page_view(e, o::DesignFile) = design_part(e, string(o.path))
page_fills(e, ::DesignFile) = true
page_covers(e, ::DesignFile) = true
crumb_in_page(e, ::DesignFile) = true
page_edited(e, o::DesignFile) = (v = get(e.nodes, (:design, string(o.path)), nothing); v isa Designs.DesignView && Designs.edited(v))

# The design goes up to the top of the window, in the place of the top bar's middle. So its toolbar has the
# file's path that the bar would show, and leaves room at its left for the bar's buttons while the sidebar is closed.
Designs.file_part(v::Designs.DesignView, room, ground) = begin
  e = editor(v)
  crumb_in_page(e) ? page_crumb(e, room, ground) : invoke(Designs.file_part, Tuple{Any,Any,Any}, v, room, ground)
end
Designs.corner_room(v::Designs.DesignView) = (e = editor(v); crumb_in_page(e) ? bar_corner(e) : 0px)

"End SolidCraft's program for the design at `path` when the window leaves it, unless the design has changes that aren't saved"
leave_design!(e, path) = begin
  v = get(e.nodes, (:design, path), nothing)
  (v === nothing || Designs.edited(v)) && return
  Designs.close!(v)
  delete!(e.nodes, (:design, path))
  nothing
end

"The designs that are open in the window of `e`"
designs(e) = Any[v for (key, v) in e.nodes if key isa Tuple && length(key) == 2 && key[1] === :design && v isa Designs.DesignView]

"The designs of the window of `e` that have changes that aren't in their files"
unsaved_designs(e) = filter(Designs.edited, designs(e))

"End SolidCraft's program for every design of the window of `e`: the window has closed"
close_designs!(e) = begin
  for v in designs(e)
    Designs.close!(v)
    delete!(e.nodes, (:design, v.path))
  end
  nothing
end

"""
Can the window `w` of `e` close now? It can't while a design in it has changes
that aren't saved: this asks about them, and the window closes when the
answer is Save or Don't Save.
"""
closes!(e, w) = begin
  waiting = unsaved_designs(e)
  (isempty(waiting) || get(e.nodes, :close_anyway, false) === true) && return true
  ask = CloseAsk(of=e, window=w)
  wide = 380px
  popup!(w, ask, anchor=((w.size[1] - wide) / 2, 120px, 0px, 0px), placement=:below, width=wide, key=:close_ask, theme=component_theme(e.zoom))
  redraw_in!(e, 0)
  false
end

"The question that a window asks before it closes with designs that have changes"
@def mutable struct CloseAsk <: SemanticUI
  of::Any = nothing            # the window's editor
  window::Any = nothing
  parts::Dict{Symbol,Any} = Dict{Symbol,Any}()
  saving::Vector{Any} = Any[]  # the designs that are being written, when Save was clicked
  problem::String = ""
end

"Close the window of the question `a` with no more questions"
close_now!(a::CloseAsk) = begin
  close_popup!(a.window, :close_ask)
  a.of.nodes[:close_anyway] = true
  close(a.window)
  nothing
end

"Write each design that has changes, then close the window. A design that can't be written keeps the window open, and the question says why."
save_and_close!(a::CloseAsk) = begin
  isempty(a.saving) || return
  a.problem = ""
  a.saving = unsaved_designs(a.of)
  for v in a.saving
    Designs.Designs.save!(v.model; then=problem -> begin
      filter!(o -> o !== v, a.saving)
      problem === nothing || (a.problem = "$(basename(v.path)) wasn't saved: $problem")
      isempty(a.saving) && isempty(a.problem) && close_now!(a)
    end)
  end
  isempty(a.saving) && close_now!(a)
  nothing
end

describe(a::CloseAsk) = begin
  t = component_theme(a.of.zoom)
  waiting = unsaved_designs(a.of)
  # A design that the window doesn't show now gets SolidCraft's answers here
  if !isempty(a.saving)
    foreach(v -> v.model === nothing || Designs.Designs.tick!(v.model), a.saving)
    redraw_in!(a, 0.03)
  end
  names = join(("“" * basename(v.path) * "”" for v in waiting), " and ")
  button(key, words, act; strong=false) = begin
    b = get!(() -> (n = Designs.Press(); setfield!(n, :parent, a); n), a.parts, key)
    b.act = e -> act()
    b.look = hovered -> Box(height(30px), padding(14px, 0px), radius(6px),
      (strong ? () : (border(1px, :solid, t.line),))...,
      background(strong ? (hovered ? Designs.Ink.mixed(t.accent, t.text, 0.12) : t.accent) : hovered ? t.select : t.hover),
      Text(words, size=12.5px, subfamily="Medium", color=strong ? t.on_accent : t.text, wrap=WrapMode.none))
    b
  end
  says = isempty(waiting) ? "Nothing is left to save." :
         "$names $(length(waiting) == 1 ? "has" : "have") changes that aren't saved. If you don't save them, Ladder loses them when this window closes."
  Column(width(grow=GrowType.Grow), padding(18px), child_gap=14px, radius(10px), background(t.surface), border(1px, :solid, t.line),
         shadow(0, 8, 28, RGBA(0, 0, 0, 0.3)), Alignment.Start,
    Box(Alignment.Start, Text("Save the changes to $(length(waiting) == 1 ? "this design" : "these designs")?", size=14px, subfamily="Semibold", color=t.text)),
    Box(width(grow=GrowType.Grow), Alignment.Start, Text(says, size=12.5px, color=t.dim)),
    (isempty(a.problem) ? () : (Box(width(grow=GrowType.Grow), Alignment.Start, Text(a.problem, size=12px, color=colorant"rgb(226,96,84)")),))...,
    Row(width(grow=GrowType.Grow), child_gap=8px,
      button(:lose, "Don't Save", () -> close_now!(a)),
      Box(width(grow=GrowType.Grow)),
      button(:cancel, "Cancel", () -> close_popup!(a.window, :close_ask)),
      button(:save, isempty(a.saving) ? "Save" : "Saving…", () -> save_and_close!(a); strong=true)))
end
# Return saves, as the strong button does. Escape closes the question, as it closes any popup.
onkey(a::CloseAsk, e::KeyPress{Keys.enter}) = (save_and_close!(a); handled)
onkey(::CloseAsk, ::KeyPress{Keys.mouse_left}) = handled

"Have macOS ask `e` before its window `w` closes: by its red button, and when Ladder quits"
watch_close!(e, w) = begin
  isempty(w.glfw) && return w
  GLFW.SetWindowCloseCallback(w.glfw[1], _ -> begin
    stays = try
      !Base.invokelatest(closes!, e, w)
    catch
      false   # a window that can't ask closes
    end
    stays && GLFW.SetWindowShouldClose(w.glfw[1], false)
    nothing
  end)
  w
end
