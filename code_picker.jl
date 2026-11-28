# The picker of a window: what a click does while ⌘ and ⌥ are down, the
# buttons of the thing that it chose, and the labels of requests over the
# window. The picker is the window's tool (see `code_tick!`), so it has the
# mouse before the page does. Its type, `CodePicker`, is in editor_type.jl,
# and what it shows the code of is in code_thing.jl.

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in! rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" load_icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/SVG" render_svg
@use "github.com/jkroso/UI.jl/Interface/draw" popup_at
@use "github.com/jkroso/UI.jl/Interface/draw" draw_tool draw_tool_under tool_input tool_cursor
@use Colors: @colorant_str, RGBA
@use "./base" exports...
@use "./run_code" exports...
@use "./agent/kinds" exports...
@use "./agent/page" exports...
@use "./code_thing" exports...
@use "./agent/ask" exports...
@use "./check_fails" exports...

export CODE_BUTTONS, unchoose!, code_act!, CODE_BUTTON_FILL, draw_chosen

tool_input(t::CodePicker, w, ::KeyPress{Keys.mouse_left}) = begin
  # The palette's chip that a click chooses for takes the click first
  palette_click!(t.editor, w) && (t.swallow = true; return true)
  # A click on a button of the thing that a click with ⌘ and ⌥ down chose does what the button says.
  # A click on its label does nothing. A click anywhere else takes its line away, and goes on to the window.
  if t.chosen !== nothing
    x, y = num(w.mouse[1]), num(w.mouse[2])
    # A press on the handle of a block starts a drag of the block: see "move a block by its handle"
    grab_block!(t, x, y) && (t.swallow = true; return true)
    k = findfirst(((_, (left, top, wide, tall)),) -> left <= x <= left + wide && top <= y <= top + tall, t.buttons)
    if k !== nothing
      t.swallow = true
      action = t.buttons[k][1]
      action == :label && return true
      node, m = t.chosen
      unchoose!(t)
      code_act!(t.editor, action, node, m)
      return true
    end
    unchoose!(t)
  end
  # A click on the card of an agent's answer takes it away, and does nothing else. A click anywhere else leaves
  # it, so that an answer stays until you've read it.
  q = t.about
  if q !== nothing && q.card !== nothing
    x, y = num(w.mouse[1]), num(w.mouse[2])
    left, top, wide, tall = q.card
    if left <= x <= left + wide && top <= y <= top + tall
      t.about = nothing
      t.swallow = true
      redraw_in!(t.editor, 0)
      # Its button Ask More asks again about the same things
      if q.button !== nothing
        left, top, wide, tall = q.button
        left <= x <= left + wide && top <= y <= top + tall && follow_up_on!(t.editor, q)
      end
      return true
    end
  end
  # The labels of requests and the buttons of checks are under the window's popups, as the field of a request in
  # place is. A click on a popup goes to the popup, and never to a label that it covers.
  picks(t, w) || popup_at(w, w.mouse) === nothing || return false
  # The × at the end of the label of a request takes it away, with the field of its words. A click on the rest of the
  # label of one that an agent works on opens the field, with the questions and answers about its words. One on the
  # label of a request that waits opens a field to change it, and one on the label of a change that ended shows it.
  x, y = num(w.mouse[1]), num(w.mouse[2])
  on(r) = r !== nothing && r[1] <= x <= r[1] + r[3] && r[2] <= y <= r[2] + r[4]
  for a in labelled_requests(t)
    on(a.label) || continue
    t.swallow = true
    on(close_spot(a.label)) ? drop_request!(t.editor, a, w) :
      waiting(t.editor, a) ? edit_request!(t.editor, a) : a.ended > 0 && a.changed ? show_change!(t.editor) : open_about!(t.editor, a)
    return true
  end
  # So does the label of the box round the words of a field: the × takes the field away, and the rest opens it
  for o in ask_boxes(t.editor)
    on(o.label) || continue
    t.swallow = true
    on(close_spot(o.label)) ? close_ask!(o, w) : reopen_ask!(o)
    return true
  end
  # A button of a check of a file of Julia code, like Fix It: see "a check that fails"
  check_button!(t.editor, w) && (t.swallow = true; return true)
  picks(t, w) || return false
  found = code_under(w)
  t.swallow = true   # the window's parts see neither the press nor the release
  # The thing keeps its line after the keys go up, with a button on its top edge for each thing to do with it
  found === nothing || (t.chosen = found; redraw_in!(t.editor, 0))
  true
end

"""
The buttons on the top edge of the line round a thing that a click with ⌘ and
⌥ down chose: what each does, and its words. Ask Agent's button has no words.
It's the logo of the agent that it asks: see `asks_whom`.
"""
const CODE_BUTTONS = ((:show_code, "Show Code"), (:ask_agent, ""))

"Take the line and the buttons of the thing that a click with ⌘ and ⌥ down chose away"
unchoose!(t::CodePicker) = (t.chosen = nothing; empty!(t.buttons); redraw_in!(t.editor, 0); nothing)

"""
Do what the button `action` on the line round the part `node` of the window
of `e` says. The method `m` draws the part. Show Code shows the method in a
window beside this one. Ask Agent opens the palette with that command, with
the part as its A and the keyboard in the words.
"""
code_act!(e, action::Symbol, node, m) = action == :show_code ? show_code!(e, m) : ask_with!(e, action, node)

tool_input(t::CodePicker, w, ::KeyRelease{Keys.mouse_left}) = (dropped = drop_block!(t, w); was = t.swallow; t.swallow = false; was || dropped)

# ⌘C copies the block that a click with ⌘ and ⌥ down chose, as a whole block
tool_input(t::CodePicker, w, ::KeyPress{Keys.c}) = begin
  (t.chosen !== nothing && only_held(w, Keys.cmd)) || return false
  e = t.editor
  b = e.buf
  b.view == :markdown || return false
  # A block of the page's lines, or a view that's all that a block shows, like a board
  x = first(t.chosen)
  at = x isa Block ? nothing : findfirst(it -> it.content isa Live && it.content.node === x, e.layout)
  lines = x isa Block ? (x.first, x.last) : at === nothing ? nothing : (e.layout[at].first, e.layout[at].last)
  lines === nothing && return false
  span = ((lines[1], 0), line_end(b, lines[2]))
  text = excerpt(b, span...)
  copied!(e, span, text)
  copy_text!(e, text)
  true
end

# While a block is dragged by its handle, the mouse selects no text, and the line where the block would go follows it.
# Over the × of a label, a tooltip says what a click on it does.
tool_input(t::CodePicker, w, ::MouseMove) = dragging(t) ? (redraw_in!(t.editor, 0); true) : close_tip!(t, w)

# Esc stops the drag of a block, and takes the line of a thing that a click with ⌘ and ⌥ down chose away, while no
# popup and no search shows. It does nothing to an agent or to its answer, as it's easy to press by mistake: the ×
# on the label stops an agent, and a click on the card takes an answer away. The field of a request in place takes
# its own Esc: see "a request in place".
tool_input(t::CodePicker, w, ::KeyPress{Keys.escape}) = begin
  (unmodified(w) && t.editor.popup == :none && !finding(t.editor) && !typing_ask(t.editor, w)) || return false
  dragging(t) && (block_drag(t.editor).lines = nothing; redraw_in!(t.editor, 0); return true)
  t.chosen === nothing || (unchoose!(t); return true)
  # The values of Show Steps go: see "the steps of a check"
  shown_steps(t.editor) === nothing || (hide_steps!(t.editor); redraw_in!(t.editor, 0); return true)
  false
end

# A thing or a block of code that an agent is changing keeps its line, with what was asked, and then what the agent said.
# These lines and labels are under the window's popups, so that the field of a request and its answers cover them.
draw_tool_under(ctx, w, t::CodePicker, scene) = begin
  mark_chips(ctx, w, t.editor)
  mark_preview(ctx, w, t.editor)
  # The words that each request in place is about, while you type it and while its answers show. A label that would
  # cover one drawn before it goes a row higher.
  placed = NTuple{4,Float64}[]
  for k in copy(ask_boxes(t.editor))
    ask_box_tick!(ctx, w, t.editor, k, placed)
  end
  a = t.asked
  if a !== nothing
    # Each thing has its letter, and the first has what was asked, then what the agent said
    for (n, c) in enumerate(a.places)
      n == 1 && continue
      r = asked_rect(t.editor, c)
      r === nothing || pick_mark(ctx, w, r, string('A' + n - 1); colour=CHIP_MARKS[mod1(n, length(CHIP_MARKS))])
    end
  end
  # The request that an agent works on, those that wait, with their places in the queue, and those that ended while
  # others waited: see "a queue of requests". Each label has an × at its end, that takes the request away.
  shown = Any[]
  # The request that an agent works on has a ring that turns, and a colour that pulses. One that waits for the page's agent to wait again has neither.
  busy = a !== nothing && a.ended == 0 && (isempty(a.by) || a.sent)
  a === nothing || push!(shown, (a, asked_label(a, open=!box_shows(t.editor, w, a)), a.failed ? PICK_FAILED : PICK_LINE, busy))
  for (n, (q, _)) in enumerate(ask_queue(t.editor))
    push!(shown, (q, queued_label(n, q.words), QUEUED_LINE, false))
  end
  foreach(d -> push!(shown, (d, asked_label(d), d.failed ? PICK_FAILED : PICK_LINE, false)), asks_ended(t.editor))
  for (x, words, colour, turns) in shown
    r = asked_rect(t.editor, isempty(x.places) ? nothing : first(x.places))
    x.label = pick_mark(ctx, w, r, label_words(words); colour, busy=turns, avoid=placed, close=true)
  end
  busy && redraw_in!(t.editor, SPIN_FRAME)   # the ring turns, and the colour pulses
  nothing
end

# The card of an agent's answer, and a line round the thing that a click would show the code of, with a label over
# its top left corner. These are over the window's popups.
draw_tool(ctx, w, t::CodePicker, scene) = begin
  draw_answer(ctx, w, t)
  draw_chosen(ctx, w, t)
  draw_drag(ctx, w, t)
  picks(t, w) || return nothing
  redraw_in!(t.editor, 1/30)   # the line follows the mouse
  found = code_under(w)
  found === nothing && return nothing
  node, m = found
  # The thing that a click chose has its line already, with its buttons
  t.chosen !== nothing && same_thing(t.chosen[1], node) && return nothing
  r = try rect(node) catch; nothing end
  r === nothing && return nothing
  pick_mark(ctx, w, r, "$(pick_name(node))  ·  $(code_label(m))")
end

const CODE_BUTTON_FILL = colorant"white"

"""
Draw the line round the thing that a click with ⌘ and ⌥ down chose, with its
label, and a button after the label on the line's top edge for each of
`CODE_BUTTONS`. The button under the mouse is tinted. A thing that no longer
shows loses its line.
"""
draw_chosen(ctx, w, t::CodePicker) = begin
  empty!(t.buttons)
  block_drag(t.editor).at = nothing
  t.chosen === nothing && return nothing
  node, m = t.chosen
  # A paragraph or a heading that the click chose was made by the frame before this one
  node = shown_now(node)
  r = node === nothing ? nothing : try rect(node) catch; nothing end
  r === nothing && (t.chosen = nothing; return nothing)
  t.chosen = (node, m)
  face = Face(SANS, "Medium", 11px, PICK_LINE, false)
  # A button with no words is as wide as it's tall, with the agent's logo in it
  wides = [isempty(words) ? 18.0 : num(measure(face, words)) + 12 for (_, words) in CODE_BUTTONS]
  logo = something(agent_logo(asks_whom(t.editor)), ("bell-fill", PICK_LINE))
  left, top, across, tall = pick_mark(ctx, w, r, "$(pick_name(node))  ·  $(code_label(m))"; room=sum(wides) + 4 * length(wides))
  push!(t.buttons, (:label, (left, top, across, tall)))
  x, y = num(w.mouse[1]), num(w.mouse[2])
  left += across + 4
  for ((action, words), wide) in zip(CODE_BUTTONS, wides)
    over = left <= x <= left + wide && top <= y <= top + tall
    round_box(ctx, left + 0.5, top + 0.5, wide - 1, tall - 1, 3; fill=over ? RGBA(0.86, 0.92, 1.0, 1.0) : CODE_BUTTON_FILL, line=PICK_LINE, wide=1.0)
    if isempty(words)
      shape = load_icon(logo[1])
      render_svg(ctx, px(left + 3), px(top + 3), px(12), px(12), shape.paths, shape.viewbox, logo[2])
    else
      write_ink(ctx, words, left + 6, top + 13, face)
    end
    push!(t.buttons, (action, (left, top, wide, tall)))
    left += wide + 4
  end
  # A whole block of the page has a handle at the top left of its line, to drag it by: see "move a block by its handle"
  whole_block(t.editor, node) === nothing || (block_drag(t.editor).at = draw_handle(ctx, w, r, dragging(t)))
  nothing
end

"""
A hand over a button on the line round the thing that a click with ⌘ and ⌥
down chose, over the handle of a block, and while a block is dragged by its
handle. The label of that thing does nothing, so it has the arrow. The label
of a request, and of the box round the words of a field, has the hand where
no popup covers it: a click on it does something.
"""
tool_cursor(t::CodePicker, w, pos) = begin
  x, y = num(pos[1]), num(pos[2])
  on(left, top, wide, tall) = left <= x <= left + wide && top <= y <= top + tall
  over = any(((action, place),) -> action != :label && on(place...), t.buttons)
  d = block_drag(t.editor)
  handle = d.lines !== nothing || (d.at !== nothing && on(d.at...))
  label = popup_at(w, pos) === nothing && any(r -> r !== nothing && on(r...), mark_labels(t))
  over || handle || label ? :hand : nothing
end
