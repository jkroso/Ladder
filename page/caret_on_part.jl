# The caret on a part of the page as a whole: the line round it, and what Return does there

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI window_of focus tabstop tabbed!
@use "github.com/jkroso/UI.jl/Interface/draw" scene
@use "./markdown" MATTER TOML_MATTER MATH
@use "./columns" => Columns
@use "./base" exports...
@use "./sketch_view" exports...
@use "./takeoff_view" exports...
@use "./fill_view" exports...
@use "./schedule_view" exports...
@use "./transclusion" exports...

export nodes_in

# --- the caret on a part of the page as a whole ------------------------------------------------
#
# In rich text the caret doesn't go into a part of the page that shows as one
# thing, like a form, a diagram or a picture. It goes onto the part, and a
# line goes round the part to show that. See `picked`. A click on a live block
# that no part of the block takes for itself puts the caret there too. See
# `pick_clicked!`. From there:
#
#   - Return gives the part the keyboard. A form's first field takes it, and
#     Tab goes to the next field. A plan, a schedule and a sketch take their
#     own keys. A picture, a diagram and a page of a PDF fill the window. The
#     front matter and a formula show as they're written. esc gives the
#     keyboard back to the page, with the caret still on the part.
#   - ↑ and ← go to the line before the part, and ↓ and → to the line after.
#   - ⌫ and ⌦ take the part away, and the commands that move, copy and delete
#     a line do that to all of its lines.
#   - ⌘E shows its code, with the caret in it.

"Draw a line round the part of the page that the caret is on as a whole. The page's text is at `ui`."
ring_part(ctx, e, ui) = begin
  b = e.buf
  w = window_of(e)
  # The top of an email that has the keyboard has the line round it too
  held = w !== nothing && w.focus isa SemanticUI && head_in_charge(e) === w.focus
  run = held ? (1, 1) : picked(b)
  (run === nothing || isempty(e.layout)) && return
  # While the part has the keyboard, the field in it that takes the keys shows that itself
  (w === nothing || w.focus === e || held) || return
  it = item(e, run[1])
  it.first <= run[1] <= it.last || return
  across, wide = item_room(e, it)   # a part in a column of the page is as wide as the column
  top, high = num(ui.top + it.top) + 1, max(4.0, num(it.tall) - 2)
  # What a live block shows is LIVE_GAP under the top of its room, so the line is as far from it there as at the sides
  it.content isa Live && ((top, high) = (num(ui.top + it.top + LIVE_GAP) - RING_OUT, num(it.tall - 2LIVE_GAP) + 2RING_OUT))
  round_box(ctx, num(ui.left + across) - RING_OUT, top, num(wide) + 2RING_OUT, high, 8.0,
            fill=tint(colours.accent, 0.06), line=tint(colours.accent, 0.75), wide=1.5)
end

"The part of a component that takes the keys when the component has the keyboard, or nothing for a node that has none"
keyboard_part(node) = nothing
keyboard_part(v::TakeoffView) = part!(() -> PlanArea(of=v), v, :area)
keyboard_part(v::ScheduleView) = chart(v)
keyboard_part(v::SketchView) = sketch_area(v)

"The nodes that `pick` is true for among those that the window last drew in the part of the page that `it` shows, in the order of the layout"
nodes_in(pick, e, it::Item) = begin
  out = SemanticUI[]
  w = window_of(e)
  drawn = w === nothing ? nothing : scene(w)
  drawn === nothing && return out
  page = node!(Document, e, :document)
  top, bottom = e.origin[2] + it.top, e.origin[2] + it.top + it.tall
  left = e.origin[1] + item_room(e, it)[1]   # a part in a column of the page has other parts beside it
  right = left + item_room(e, it)[2]
  walk(ui, inpage) = begin
    ui isa ConcreteRect || return
    node = ui.from isa GeometricUI ? ui.from.from : nothing
    inpage |= node === page
    inpage && node isa SemanticUI && node !== page && top <= ui.top + ui.height / 2 < bottom && left - 1px <= ui.left + ui.width / 2 <= right + 1px && pick(node) &&
      !any(n -> n === node, out) && push!(out, node)
    foreach(child -> walk(child, inpage), ui.children)
  end
  walk(drawn, false)
  out
end

"""
What Return does while the caret is on a part of the page as a whole: it gives
the part the keyboard, in the way that suits the part. A part with nothing to
give it to, like a line across the page, stays as it is.
"""
enter_part!(e) = begin
  b = e.buf
  run = picked(b)
  (run === nothing || isempty(e.layout)) && return e
  it = item(e, run[1])
  # A part of another page has an editor of its own, with the caret at its start
  it.content isa Live && it.content.node isa Transclusion && return (enter_shown!(it.content.node); e)
  # A plan, a schedule and a sketch have keys of their own
  views = nodes_in(n -> keyboard_part(n) !== nothing, e, it)
  isempty(views) || return (focus(keyboard_part(first(views))); e)
  # A field to type in takes the keyboard, with its text selected, as Tab gives it
  fields = nodes_in(tabstop, e, it)
  isempty(fields) || return (focus(first(fields)); tabbed!(first(fields)); e)
  # A picture, a diagram or a page of a PDF fills the window
  fills = nodes_in(n -> n isa Fillable, e, it)
  isempty(fills) || return (zoom_in!(e, first(fills).what, first(fills).parent); e)
  # Front matter shows as it's written, with the caret after its first key
  if run[1] == 1 && kinds(b)[1].lang in (MATTER, TOML_MATTER)
    b.caret = b.anchor = line_end(b, min(2, run[2]))
    touch!(e)
  elseif (kinds(b)[run[1]].lang == MATH || kinds(b)[run[1]].lang in Columns.LANGS) && run[2] > run[1]
    # A formula shows its TeX, and a `columns` block its number, with the caret at the end of its first line
    b.caret = b.anchor = line_end(b, run[1] + 1)
    touch!(e)
  elseif maths_line(b, run[1])
    # The caret goes to the end of the TeX, before the $$ that closes it
    b.caret = b.anchor = (run[1], length(rstrip(b.lines[run[1]])) - 2)
    touch!(e)
  end
  e
end
