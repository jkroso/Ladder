# The view of a `form` block: a field for each column of a table, and a button that adds a row with them
#
# A code block in the language `form` shows a field for each column of the
# table above it, and a button, Add, that adds a row to the table with what's
# in the fields. forms.jl says how the block is written, and what each field
# takes. A line `to: Jobs` in the block adds to the first table under the
# heading Jobs.
#
# A field is what its column takes:
#
# - A day: a narrow field, and a month that floats under it while it has the
#   keyboard. A click on a day of the month puts that day in the field. ↓ and
#   ↑ go to the next day and the one before, and with ⌥ they go a week. Words
#   like `fri`, `25 nov` and `tomorrow` name a day too, and the words beside
#   the field say which day that is.
# - A time or a number: a narrow field. A number's field shows what the
#   column's numbers have before them and after them, like $ or m.
# - Yes or no: a box to tick, with a click or with Space.
# - A few words that come again and again, like Quote and Booked: a chooser,
#   which is a bar with those words side by side. A click picks a word, and so
#   do ← and →, and the first letter of a word. The first word is picked until
#   you pick another.
#
# Return in a field adds the row too. Tab goes to the next field, ⇧Tab to the
# one before, and Esc closes the month, and then gives the keyboard back to
# the page. After an add, the fields are empty again, the first has the
# keyboard, and the line under them says what was added. One ⌘Z takes the row
# away.
#
# A day, a time or a number goes in the row the way that its column writes it.
# What's typed is changed to that when the keyboard leaves the field. Add
# doesn't add a row while a field holds something that it doesn't take: the
# field gets a red edge, and the line under the fields says what it takes.
#
# What's typed in the fields isn't in the file until it's added. Only a table
# of the page's text takes rows: not a sheet, a spreadsheet or a filter.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor redraw_in! rect popup! close_popup! placed!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/RadioGroup" RadioGroup
@use "../html" escape
@use "../markdown" Kind words
@use "./sheet" parts
@use "./spreadsheet" moved
@use "./forms" => Forms
@use "./calendar" => Calendars
@use "./day" => Days
@use Colors: @colorant_str, RGBA
@use Dates: Dates, Date, Day
@use "../base" exports...
@use "./rows_from" exports...

export FORM, FORM_NARROW, FormChoice, FormMonth, FormState, FormTick, FormView, MONTH_CELL,
       MONTH_KEY, MONTH_W, MonthDay, day_said, field_day, field_day!, form_cell, form_choice,
       form_empty, form_field, form_fields, form_focus!, form_focused, form_hint, form_html,
       form_part, form_state, form_table, form_takes, form_target, form_tick, form_width,
       pick_choice!, show_month!, shut_month!, step_day!, stray_words

const FORM = Forms.FORM
push!(BLOCK_ICONS, "input-cursor-text", "plus-lg", "calendar-event", "chevron-left", "chevron-right", "check", "check2", "exclamation-circle")

const FORM_NARROW = 210px     # how wide the field for a day, a time or a number is
const MONTH_KEY = :form_month
const MONTH_CELL = 30px       # how wide a day of the month that floats is
const MONTH_W = 7 * MONTH_CELL + 18px

"What a `form` block shows: a field for each column of a table, and a button that adds a row"
@def mutable struct FormView <: SemanticUI
  n::Int = 0                               # its place among the page's forms
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  spec::Forms.Form = Forms.Form()
  lines::Vector{String} = String[]         # the lines that `spec` was read from
  said::String = ""                        # what the last add did, or ""
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its fields and its buttons, kept between frames
end

"What a form keeps between frames about its fields"
@def mutable struct FormState <: SemanticUI
  rows::Any = nothing                      # the rows and the lines that `fields` were worked out from
  spec::Any = nothing
  fields::Vector{Forms.Field} = Forms.Field[]
  had::Int = 0                             # the column whose field had the keyboard in the last frame, or 0
  refused::Int = 0                         # the column whose field stopped the last Add, or 0
  month::Int = 0                           # the column whose field the month floats under, or 0
  shut::Int = 0                            # the column whose field has the keyboard after its month was closed, or 0
  shows::Date = Date(1)                    # the first day of the month that floats
  seen::Any = nothing                      # the day that the field named when the month last went to its month
end

"The box to tick of a column of a form that takes yes or no"
@def mutable struct FormTick <: SemanticUI
  of::Any = nothing
  on::Bool = false
  yes::String = "Yes"   # what the row gets when it's ticked, and when it's not
  no::String = "No"
end

"The chooser of a column of a form that takes one of a few words: a RadioGroup, and a ring round it while it has the keyboard"
@def mutable struct FormChoice <: SemanticUI
  of::Any = nothing
  group::Any = nothing
end

"The month that floats under a form's field for a day. A click on one of its days puts the day in the field."
@def mutable struct FormMonth <: SemanticUI
  of::Any = nothing
  side::Symbol = :bottom   # the side of the field that it's on
end
"A day of that month"
@def mutable struct MonthDay <: SemanticUI
  of::Any = nothing
  day::Date = Date(1)
end

reread!(v::FormView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.spec = Forms.query(lines)
  v
end

"""
The table of the page that the form `v` adds rows to, as `page_tables` gives
it: the one under the heading that `to` names, or the one nearest above. It's
words that say why, when there's no table that it can add to.
"""
form_table(v::FormView) = begin
  e = editor(v)
  tables = page_tables(e)
  to = String(strip(v.spec.to))
  k = isempty(to) ? something(findlast(t -> t.last < v.first, tables), 0) : something(named_table(e, tables, to), 0)
  k == 0 && return isempty(to) ? "Put a table over this form, and the form adds rows to it." : "This page has no table called “$(to)”."
  t = tables[k]
  kinds(e.buf)[t.first].kind == Kind.table || return "A form adds rows only to a table of the page's text, and the one $(isempty(to) ? "above" : "called “$(to)”") is a $(table_kind(e, t))."
  t
end

"What the form calls the table `t`: its heading, or “the table above”"
form_target(t) = isempty(t.under) ? "the table above" : t.under

form_state(v::FormView) = block_part!(FormState, v, :state)

"What each field of the form `v` takes, as `Forms.fields` gives it for the table `t`. It's worked out once for each change of the table or of the block."
form_fields(v::FormView, t=form_table(v)) = begin
  t isa String && return Forms.Field[]
  st = form_state(v)
  (st.rows === t.rows && st.spec === v.spec) || (st.rows = t.rows; st.spec = v.spec; st.fields = Forms.fields(t.rows, v.spec))
  st.fields
end

"The text field of the form `v` for column `k`"
form_field(v::FormView, k::Int) = block_part!(v, (:field, k)) do
  TextInput(placeholder="", font_family=SANS, font_size=13px, look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"The box to tick of the form `v` for column `k`"
form_tick(v::FormView, k::Int) = block_part!(() -> FormTick(of=v), v, (:tick, k))

"The chooser of the form `v` for column `k`. A click on one of its words gives it the keyboard."
form_choice(v::FormView, k::Int) = block_part!(v, (:choice, k)) do
  c = FormChoice(of=v)
  c.group = RadioGroup(labels=String[], onchange=_ -> focus(c))
  setfield!(c.group, :parent, c)
  c
end

"What takes the keyboard for the field `f` of column `k`: its box to tick, its chooser, or its text field"
form_part(v::FormView, k::Int, f::Forms.Field) = f.kind == :tick ? form_tick(v, k) : !isempty(f.choices) ? form_choice(v, k) : form_field(v, k)

"The column whose field has the keyboard of the window `w`, or nothing"
form_focused(v::FormView, w) = begin
  for (key, part) in v.parts
    key isa Tuple && key[1] in (:field, :tick, :choice) && part === w.focus && return key[2]
  end
  nothing
end

"How many fields the form `v` has: one for each column of its table"
form_width(v::FormView) = (t = form_table(v); t isa String ? 0 : length(first(t.rows)))

"What the field `f` of column `k` puts in its cell now, or nothing when it holds something that it doesn't take"
form_cell(v::FormView, k::Int, f::Forms.Field) =
  f.kind == :tick ? (form_tick(v, k).on ? f.yes : f.no) :
  !isempty(f.choices) ? f.choices[clamp(form_choice(v, k).group.selected, 1, length(f.choices))] :
  Forms.value(f, form_field(v, k).text; today=calendar_today())

"True while the field `f` of column `k` has nothing in it: no words, and no tick. A chooser always has a word picked, so it doesn't count."
form_empty(v::FormView, k::Int, f::Forms.Field) =
  f.kind == :tick ? !form_tick(v, k).on : !isempty(f.choices) || isempty(strip(form_field(v, k).text))

"Give the keyboard to the field `f` of column `k`, with all its words selected"
form_focus!(v::FormView, k::Int, f::Forms.Field) = begin
  part = form_part(v, k, f)
  part isa TextInput && ((part.anchor, part.cursor) = (0, length(part.text)))
  focus(part)
end

"What the field `f` takes, in words that say why Add added no row"
form_takes(f::Forms.Field) = begin
  today = calendar_today()
  f.kind == :day ? "$(f.name) takes a day, like $(Forms.written(today, f.style)), $(Dates.day(today)) $(Dates.monthabbr(today)) or tomorrow." :
  f.kind == :time ? "$(f.name) takes a time, like $(Forms.written(14, 30, f.style))." :
  "$(f.name) takes a number, like $(Forms.amount(f, "1200"))."
end

"""
Add a row to the table of the form `v`, with what's in its fields, in one edit,
so one ⌘Z takes it away. The caret stays with its text. The fields are emptied
then, and the first gets the keyboard. Nothing happens while every field is
empty. A field that holds something that it doesn't take stops the add, and
gets the keyboard.
"""
add_row!(v::FormView) = begin
  t = form_table(v)
  t isa String && return v
  e = editor(v)
  b = e.buf
  readonly(b) && return v
  fields = form_fields(v, t)
  all(k -> form_empty(v, k, fields[k]), eachindex(fields)) && return v
  st = form_state(v)
  cells = [form_cell(v, k, f) for (k, f) in enumerate(fields)]
  bad = findfirst(isnothing, cells)
  if bad !== nothing
    st.refused, v.said = bad, ""
    # The month would cover the words that say why, so it goes until ↓ or its button shows it again
    st.month == 0 || shut_month!(v)
    fields[bad].kind == :day && (st.shut = bad)
    window_of(v) === nothing || form_focus!(v, bad, fields[bad])
    redraw_in!(v, 0)
    return v
  end
  at = line_end(b, t.last)
  line = Forms.row_line(cells)
  caret, anchor = b.caret, b.anchor
  edit!(b, at, at, "\n" * line)
  stop = (t.last + 1, length(line))
  b.caret, b.anchor = moved(caret, at, at, stop), moved(anchor, at, at, stop)
  for (k, f) in enumerate(fields)
    f.kind == :tick && (form_tick(v, k).on = false)
    isempty(f.choices) || (group = form_choice(v, k).group; group.selected = 1; group.slid = 1.0)
    field = form_field(v, k)
    field.text, field.cursor, field.anchor = "", 0, 0
  end
  st.refused = 0
  name = first(filter(!isempty, strip.(cells)))
  v.said = "Added “$(length(name) > 40 ? first(name, 39) * "…" : name)” to $(form_target(t))."
  window_of(v) === nothing || isempty(fields) || form_focus!(v, 1, fields[1])
  redraw_in!(v, 0)
  v
end

# --- the month under a field for a day ---

"The day that the field of column `k` names now, or nothing"
field_day(v::FormView, k::Int) = Forms.day(form_field(v, k).text; today=calendar_today())

"Put the day `d` in the field of column `k`, written as its column writes days, with all of it selected"
field_day!(v::FormView, k::Int, d::Date) = begin
  fields = form_fields(v)
  k in eachindex(fields) || return handled
  field = form_field(v, k)
  field.text = Forms.written(d, fields[k].style)
  field.anchor, field.cursor = 0, length(field.text)
  handled
end

"Show the month under the field of column `k`, at the month of the day that the field names, or at this month"
show_month!(v::FormView, k::Int, w) = begin
  st = form_state(v)
  st.month, st.shut = k, 0
  st.seen = field_day(v, k)
  st.shows = Dates.firstdayofmonth(something(st.seen, calendar_today()))
  month = FormMonth(of=v)
  v.parts[:month] = month
  # The keys stay with the field, and a click outside the month is the app's, as it is with no month
  popup!(w, month, anchor=form_field(v, k), placement=:bottom, gap=9px, width=MONTH_W, key=MONTH_KEY, modal=false,
         onclose=() -> (st.month = 0; st.shut = k), theme=component_theme(editor(v).zoom))
end

"Take the month away. It stays away while its field keeps the keyboard, until ↓ or its button shows it again."
shut_month!(v::FormView) = begin
  st = form_state(v)
  st.month == 0 || (st.shut = st.month)
  st.month = 0
  w = window_of(v)
  w === nothing || close_popup!(w, MONTH_KEY)
  handled
end

"""
What happens to a form in each frame, before the page is laid out. What's
typed in a field is written as its column writes it when the keyboard leaves
the field. The month shows under a field for a day while that field has the
keyboard, and goes to the month of the day that's typed there.
"""
block_tick!(v::FormView) = begin
  w = window_of(v)
  w === nothing && return v
  st = form_state(v)
  fields = form_fields(v)
  k = something(form_focused(v, w), 0)
  k in eachindex(fields) || (k = 0)
  if st.had != k
    if st.had in eachindex(fields) && form_part(v, st.had, fields[st.had]) isa TextInput
      left = form_field(v, st.had)
      cell = Forms.value(fields[st.had], left.text; today=calendar_today())
      cell === nothing || (cell = Forms.shown(fields[st.had], cell))
      cell === nothing || cell == left.text || (left.text = cell; left.anchor = left.cursor = length(cell))
    end
    st.had = k
  end
  st.refused in eachindex(fields) && form_cell(v, st.refused, fields[st.refused]) !== nothing && (st.refused = 0)
  if k == 0 || fields[k].kind != :day
    st.shut = 0
    st.month == 0 || (shut_month!(v); st.shut = 0)
  elseif st.month != k && st.shut != k
    # The month goes beside where its field was drawn. A field that's new in this frame has it in the next.
    rect(form_field(v, k)) === nothing ? redraw_in!(v, 0) : show_month!(v, k, w)
  end
  if st.month != 0
    d = field_day(v, st.month)
    d == st.seen || (st.seen = d; d === nothing || (st.shows = Dates.firstdayofmonth(d)))
  end
  v
end

describe(d::MonthDay) = begin
  v = d.of
  st = form_state(v)
  c = found_colours()
  on = st.month != 0 && field_day(v, st.month) == d.day
  today = d.day == calendar_today()
  ink = on ? colours.bg : today ? colours.accent : Dates.month(d.day) == Dates.month(st.shows) ? c.ink : RGBA(c.dim, 0.6)
  Row(fixed(MONTH_CELL), height(28px), Alignment.Center, justify=Alignment.Center, name="Day",
    Row(fixed(MONTH_CELL - 2px), height(26px), radius(6px), Alignment.Center, justify=Alignment.Center,
        background(on ? colours.accent : ishovered(d) ? c.pick : clear), border(1px, :solid, today && !on ? colours.accent : clear),
      Box(label(string(Dates.day(d.day)), 12px, color=ink, weight=on || today ? "Semibold" : ""))))
end

cursor(::MonthDay) = :hand
cursor(::FormMonth) = :arrow
onmouse(::MonthDay, ::MouseMove) = handled
# A click on a day puts it in the field, and the month goes
onkey(d::MonthDay, ::KeyPress{Keys.mouse_left}) = begin
  v = d.of
  k = form_state(v).month
  k == 0 && return handled
  field_day!(v, k, d.day)
  field = form_field(v, k)
  field.anchor = field.cursor
  focus(field)
  shut_month!(v)
end
# A click between the days does nothing, and the field keeps the keyboard
onkey(::FormMonth, ::KeyPress{Keys.mouse_left}) = handled

describe(m::FormMonth) = begin
  v = m.of
  st = form_state(v)
  c = found_colours()
  start = Calendars.monday(st.shows)
  head = Row(width(grow=grow), height(28px), Alignment.Center, child_gap=2px,
    Box(width(7px)), Box(label(Calendars.title(st.shows), 13px, color=c.ink, weight="Semibold")), Box(width(grow=grow)),
    block_button!(v, :month_today, (:month, 0), words="Today", tip="Show this month"),
    block_button!(v, :month_back, (:month, -1), icon="chevron-left", tip="The month before"),
    block_button!(v, :month_on, (:month, 1), icon="chevron-right", tip="The month after"))
  names = Row(width(grow=grow), height(22px), Alignment.Center,
    [Row(fixed(MONTH_CELL), Alignment.Center, justify=Alignment.Center, Box(label(name, 11px, color=c.dim))) for name in Calendars.DAYS]...)
  # Six weeks always, so that the box is as tall for every month
  day(n) = (d = block_part!(() -> MonthDay(of=v), v, (:month_day, n)); d.day = start + Day(n); d)
  weeks = [Row(width(grow=grow), Alignment.Center, [day(7week + n) for n in 0:6]...) for week in 0:5]
  Box(width(grow=grow), padding(8px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Month",
    Column(width(grow=grow), Alignment.Start, head, names, weeks...))
end

placed!(m::FormMonth, side) = (m.side = side; nothing)
draw(ctx, size, ui::ConcreteRect, m::FormMonth) = (k = form_state(m.of).month; k == 0 ? nothing : caret(ctx, ui, m.side, rect(form_field(m.of, k))))

# --- the box to tick ---

describe(t::FormTick) = begin
  w = window_of(t)
  typing = w !== nothing && w.focus === t
  word = t.on ? t.yes : t.no
  # A word like Yes shows beside the box. A mark like ✓ or x doesn't: the box says it.
  words = count(isletter, word) > 1 ? (Box(label(word, 13px, color=t.on ? colours.ink : colours.dim)),) : ()
  Row(height(28px), child_gap=8px, Alignment.Center, name="Tick",
    Box(fixed(16px), height(16px), radius(4px), Alignment.Center, justify=Alignment.Center,
        background(t.on ? colours.accent : colours.bg),
        border(1.5px, :solid, t.on || typing || ishovered(t) ? colours.accent : colours.marker),
        (t.on ? (Icon("check", size=13px, color=colours.bg),) : ())...),
    words...)
end

cursor(::FormTick) = :hand
onkey(t::FormTick, ::KeyPress{Keys.mouse_left}) = (focus(t); t.on = !t.on; handled)
# Return, Tab and Esc are the form's. Any other key alone does nothing here, so that it does nothing to the page's text.
onkey(::Union{FormTick,FormChoice}, ev::KeyPress{K}) where K = K in (Keys.enter, Keys.tab, Keys.escape) || !unmodified(ev) ? nothing : handled

# --- the chooser ---

describe(c::FormChoice) = begin
  w = window_of(c)
  typing = w !== nothing && w.focus === c
  # The chooser's words are 13px, as the words in the fields beside it are, and its bar is in keeping with them
  with_theme(component_theme(13 / 17)) do
    Box(padding(2px), radius(8px), border(1.5px, :solid, typing ? colours.accent : clear), name="Choice", c.group)
  end
end

"Pick word `to` of the chooser `c`. The raised part of its bar slides there."
pick_choice!(c::FormChoice, to::Int) = begin
  g = c.group
  to = clamp(to, 1, max(length(g.labels), 1))
  to == g.selected || ((g.was, g.slid, g.stepped) = (g.selected, 0.0, time()); g.selected = to)
  handled
end

# A click beside the words gives the chooser the keyboard. ← and → pick the word before and the word after, and a
# letter picks the first word that starts with it.
onkey(c::FormChoice, ::KeyPress{Keys.mouse_left}) = (focus(c); handled)
onkey(c::FormChoice, ev::KeyPress{Keys.left}) = unmodified(ev) ? pick_choice!(c, c.group.selected - 1) : nothing
onkey(c::FormChoice, ev::KeyPress{Keys.right}) = unmodified(ev) ? pick_choice!(c, c.group.selected + 1) : nothing
ontype(c::FormChoice, ev::Typed) = begin
  to = findfirst(word -> startswith(lowercase(word), lowercase(ev.char)), c.group.labels)
  to === nothing || pick_choice!(c, to)
  handled
end
# Space ticks the box that has the keyboard, and no other character does anything there
ontype(t::FormTick, ev::Typed) = (ev.char == ' ' && (t.on = !t.on); handled)

act!(v::FormView, action, w) = begin
  if action isa Tuple && action[1] == :month
    # The buttons at the top of the month show the month before, the month after, or this month
    st = form_state(v)
    st.shows = action[2] == 0 ? Dates.firstdayofmonth(calendar_today()) : st.shows + Dates.Month(action[2])
    return handled
  elseif action isa Tuple && action[1] == :pick
    # The button in a field for a day shows the month, or takes it away
    st = form_state(v)
    k = action[2]
    st.month == k && return shut_month!(v)
    st.shut = 0
    focus(form_field(v, k))
    return handled
  end
  action == :add && add_row!(v)
  handled
end

# Return in a field adds the row. Tab and ⇧Tab go from field to field, round to the first or the last. Esc closes the
# month of a field for a day, and then gives the page the keyboard.
onkey(v::FormView, ev::KeyPress{Keys.enter}) = begin
  (unmodified(ev) && form_focused(v, ev.window) !== nothing) || return nothing
  add_row!(v)
  handled
end
onkey(v::FormView, ev::KeyPress{Keys.tab}) = begin
  k = form_focused(v, ev.window)
  (k !== nothing && (unmodified(ev) || only_held(ev, Keys.shft))) || return nothing
  fields = form_fields(v)
  isempty(fields) && return nothing
  # The field that's left keeps no selection, and the next one has all its words selected
  left = ev.window.focus
  left isa TextInput && (left.anchor = left.cursor)
  to = mod1(k + (only_held(ev, Keys.shft) ? -1 : 1), length(fields))
  form_focus!(v, to, fields[to])
  handled
end
onkey(v::FormView, ev::KeyPress{Keys.escape}) = begin
  (unmodified(ev) && form_focused(v, ev.window) !== nothing) || return nothing
  form_state(v).month == 0 || return shut_month!(v)
  focus(editor(v))
  handled
end

"""
↓ or ↑ in a field for a day: go `by` days from the day that the field names,
and put that day in the field. From an empty field, the first press gives
today. While the month is closed, the first press only shows it.
"""
step_day!(v::FormView, ev, by::Int) = begin
  k = form_focused(v, ev.window)
  week = only_held(ev, Keys.opt)
  (k !== nothing && (unmodified(ev) || week)) || return nothing
  fields = form_fields(v)
  (k in eachindex(fields) && fields[k].kind == :day) || return nothing
  st = form_state(v)
  st.month == k || (st.shut = 0; show_month!(v, k, ev.window); return handled)
  d = field_day(v, k)
  field_day!(v, k, d === nothing ? calendar_today() : d + Day(week ? 7by : by))
end
onkey(v::FormView, ev::KeyPress{Keys.down}) = step_day!(v, ev, 1)
onkey(v::FormView, ev::KeyPress{Keys.up}) = step_day!(v, ev, -1)

"The words in a field of the form while it's empty, which say what it takes"
form_hint(f::Forms.Field) = f.kind == :number ? "A number" : f.kind == :day ? "A day, like $(Forms.written(calendar_today(), f.style))" :
                            f.kind == :time ? "A time, like $(Forms.written(14, 30, f.style))" : ""

"The day `d` in words, for beside the field that names it: its day of the week, and how far it is from today"
day_said(d::Date) = begin
  today = calendar_today()
  "$(Dates.dayname(d)) $(Dates.day(d)) $(Dates.monthname(d))$(Dates.year(d) == Dates.year(today) ? "" : " $(Dates.year(d))"), $(Days.away(d, today))"
end

"What a line of the form's block gets wrong, in words: `name` is before its colon, `words` are after it, and `why` is :column or :kind"
stray_words(name, words, why) = why == :column ? "The table has no column called “$(name)”, so the line “$(name): $(words)” does nothing." :
  "“$(words)” is no kind of field. After “$(name):”, write day, time, number, yes/no or words, or the words to choose from with commas between them."

describe(v::FormView) = begin
  e = editor(v)
  t = form_table(v)
  fields = form_fields(v, t)
  with_theme(component_theme(e.zoom)) do
    title = !isempty(v.spec.title) ? v.spec.title : t isa String ? "Form" : "Add a row to $(form_target(t))"
    bar = block_bar(Box(width(10px)), Icon("input-cursor-text", size=14px, color=colours.dim), Box(width(6px)),
                    Box(label(title, 13px, weight="Semibold")), Box(width(grow=grow)))
    t isa String && return Column(block_look()..., clip=true, name="Form", bar, block_note(t))
    w = window_of(v)
    st = form_state(v)
    keys = maximum(f -> measure(Face(SANS, "", 12px, colours.dim, false), f.name), fields, init=0px) + 4px
    # A field that holds something that it doesn't take says so once the keyboard has left it, or once Add was tried
    fault(k, f) = form_cell(v, k, f) === nothing && (st.refused == k || w === nothing || w.focus !== form_field(v, k))
    edge(wide, k, f, parts...; right=8px) = begin
      typing = w !== nothing && w.focus === form_field(v, k)
      Row(wide, height(28px), padding(0px, right, 0px, 8px), radius(6px), Alignment.Center, child_gap=5px, background(colours.bg),
          border(1px, :solid, fault(k, f) ? CHECK_BAD : typing ? colours.accent : colours.line), parts...)
    end
    rows = map(enumerate(fields)) do (k, f)
      name = Box(fixed(keys), Alignment.Start, label(f.name, 12px, color=colours.dim))
      if f.kind == :tick
        tick = form_tick(v, k)
        tick.yes, tick.no = f.yes, f.no
        return Row(width(grow=grow), child_gap=8px, Alignment.Center, name="Field", name, tick, Box(width(grow=grow)))
      end
      if !isempty(f.choices)
        choice = form_choice(v, k)
        # New words start with the first one picked
        choice.group.labels == f.choices || (choice.group.labels = copy(f.choices); choice.group.selected = 1; choice.group.slid = 1.0)
        return Row(width(grow=grow), child_gap=6px, Alignment.Center, name="Field", name, choice, Box(width(grow=grow)))
      end
      field = form_field(v, k)
      field.placeholder = form_hint(f)
      input = Box(width(grow=grow), height(grow=grow), field)
      if f.kind == :day
        d = field_day(v, k)
        open = st.month == k
        pick = block_button!(v, (:pick, k), (:pick, k), icon="calendar-event", on=open, tip=open ? "Close the month" : "Choose a day from a month")
        Row(width(grow=grow), child_gap=8px, Alignment.Center, name="Field", name,
          edge(fixed(FORM_NARROW), k, f, input, pick, right=0px),
          Row(width(grow=grow), height(28px), Alignment.Center, clip=true, Box(label(d === nothing ? "" : day_said(d), 12px, color=colours.dim)), Box(width(grow=grow))))
      elseif f.kind in (:number, :time)
        # A number's field shows what the column's numbers have round them, until a number is typed with its own
        own = f.kind != :number || Forms.marked(field.text)
        mark(words) = own || isempty(strip(words)) ? () : (Box(label(String(strip(words)), 13px, color=colours.dim)),)
        Row(width(grow=grow), child_gap=8px, Alignment.Center, name="Field", name,
          edge(fixed(FORM_NARROW), k, f, mark(f.before)..., input, mark(f.after)...),
          Box(width(grow=grow)))
      else
        Row(width(grow=grow), child_gap=8px, Alignment.Center, name="Field", name, edge(width(grow=grow), k, f, input))
      end
    end
    empty = all(k -> form_empty(v, k, fields[k]), eachindex(fields))
    bad = findfirst(k -> fields[k].kind != :tick && fault(k, fields[k]), eachindex(fields))
    stray = Forms.stray(v.spec, first(t.rows))
    words, icon, colour = bad !== nothing ? (form_takes(fields[bad]), "exclamation-circle", CHECK_BAD) :
                          !isempty(stray) ? (stray_words(stray[1]...), "exclamation-circle", colours.accent) :
                          !isempty(v.said) ? (v.said, "check2", colours.dim) :
                          ("Return or Add puts what's typed in a new row of $(form_target(t)).", "", colours.dim)
    foot = Row(width(grow=grow), child_gap=8px, Alignment.Center,
      (isempty(icon) ? () : (Icon(icon, size=13px, color=colour),))...,
      Box(width(grow=grow), Text(words, size=12px, family=SANS, color=colour, wrap=WrapMode.words)),
      block_button!(v, :add, :add, icon="plus-lg", words="Add", tip=empty ? "Type in a field first" : "Add a row to $(form_target(t))", off=empty, bold=true))
    Column(block_look()..., clip=true, name="Form", bar,
      Column(width(grow=grow), Alignment.Start, padding(12px, 12px, 10px, 12px), child_gap=8px, rows..., Box(height(2px)), foot))
  end
end

"The form block as HTML: which table it adds rows to"
form_html(e, v::FormView) = begin
  t = form_table(v)
  title = isempty(v.spec.title) ? "" : "<strong>$(escape(v.spec.title))</strong>: "
  "<p><em>$(title)A form that adds rows to $(t isa String ? "a table" : escape(form_target(t))).</em></p>"
end

BLOCKS[FORM] = FormView
block_name(::Type{FormView}) = "Form"
block_icon(::Type{FormView}) = "input-cursor-text"
block_insert(::Type{FormView}) = ("Form", ["```$FORM", "```", "", ""], (4, 0))
block_html(e, v::FormView) = form_html(e, v)
