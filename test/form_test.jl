# Tests for forms.jl and form_view.jl, "a form that adds a row to a table": a
# `form` block shows a field for each column of a table, and adds a row. Run
# them with `julia -O0 --project=. test/form_test.jl`. Set `LADDER_SHOTS` to a
# folder, and they save a picture of the form there.

@use Test: @test, @testset
@use Dates: Date, Day
@use "../forms" => F
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys Typed onkey ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect scene draw draw_tool window_tool focus popups
@use "github.com/jkroso/UI.jl/Interface/testing" click!
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive
const px = K.px

@testset "what a form's block says, and what each field takes" begin
  @test F.query(["title: New job", "to: Jobs 2", "Due: day", "no colon"]) == F.Form(title="New job", to="Jobs 2", says=["Due" => "day"])
  @test F.query(String[]) == F.Form()
  rows = [["Client", "Due", "Status", "Price", "", "Paid", "Start", "Length", "Seen"],
          ["Smith", "2026-11-25", "Quote", "\$4,200", "", "No", "9:00", "12 m", "25 Nov 2026"],
          ["Jones", "2026-12-02", "Booked", "\$950", "x", "Yes", "14:30", "340 m", "1 Dec 2026"],
          ["Brown", "2026-12-09", "Quote", "\$1,300.50", "", "No", "8:15", "3 m", "2/12/2026"],
          ["Smith", "2026-12-16", "Booked", "\$80", "", "No", "8:15", "3 m", "2/12/2026"]]
  fs = F.fields(rows)
  @test [f.name for f in fs] == ["Client", "Due", "Status", "Price", "Column 5", "Paid", "Start", "Length", "Seen"]
  @test [f.kind for f in fs] == [:words, :day, :words, :number, :tick, :tick, :time, :number, :day]
  # A few words with two cells or more for each are the words of a chooser. A name that comes twice among others isn't.
  @test fs[3].choices == ["Quote", "Booked"] && isempty(fs[1].choices) && isempty(fs[5].choices)
  @test isempty(F.fields(rows[1:4])[3].choices)
  # A column says how it writes its kind: what's round its numbers, the form of most of its days, its words for yes and no
  @test (fs[4].before, fs[4].after, fs[4].commas) == ("\$", "", true) && (fs[8].before, fs[8].after) == ("", " m")
  @test fs[2].style == :iso && fs[9].style == :words && fs[7].style == :h24
  @test (fs[6].yes, fs[6].no) == ("Yes", "No") && (fs[5].yes, fs[5].no) == ("x", "")
  @test F.tick_words(["YES"], false) == ("YES", "NO") && F.tick_words(["✓", "✓"], true) == ("✓", "") && F.tick_words(["Yes", "Maybe"], false) === nothing
  # One cell of another kind, and the column takes words
  @test F.fields([["Due"], ["2026-11-25"], ["soon"]])[1].kind == :words
end

@testset "what's typed goes in the row the way that its column writes it" begin
  rows = [["Due", "Price", "Start", "Seen", "Length"], ["2026-11-25", "\$4,200", "2:30 pm", "25 Nov 2026", "12 m"]]
  due, price, start, seen, long = F.fields(rows)
  today = Date(2026, 11, 24)   # a Tuesday
  day(words) = F.value(due, words; today)
  @test day("25 nov") == "2026-11-25" && day("25/11/2027") == "2027-11-25" && day("tomorrow") == "2026-11-25" && day("today") == "2026-11-24"
  # A day of the week is the next one after today, a number is the next day of the month with it, and +3 is three days on
  @test day("fri") == "2026-11-27" && day("tuesday") == "2026-12-01" && day("3") == "2026-12-03" && day("24") == "2026-11-24" && day("+3") == "2026-11-27"
  @test day("soon") === nothing && day("31/2") === nothing && day("  ") == ""
  @test F.value(seen, "fri"; today) == "27 Nov 2026" && F.written(Date(2026, 12, 2), :slashes) == "2/12/2026"
  @test F.value(price, "700") == "\$700" && F.value(price, "4200.5") == "\$4,200.5" && F.value(price, "-4200") == "-\$4,200"
  # A number that's typed with its own unit keeps it
  @test F.value(price, "€12") == "€12" && F.value(long, "3") == "3 m" && F.value(long, "3 km") == "3 km" && F.value(price, "lots") === nothing
  @test F.shown(long, "3 m") == "3" && F.shown(long, "3 km") == "3 km" && F.marked("€12") && !F.marked("12")
  @test F.value(start, "14:30") == "2:30 pm" && F.value(start, "9") == "9:00 am" && F.value(start, "1215") == "12:15 pm" && F.value(start, "25:00") === nothing
  @test F.written(9, 5, :padded) == "09:05" && F.written(0, 0, :h24) == "0:00" && F.clock("12am") == (0, 0)
end

@testset "a line of the block says what a column's field takes" begin
  rows = [["Client", "Due", "Status", "Paid"]]
  form = F.query(["Due: date", "status: Quote, Booked , Done", "Paid: yes/no", "Client: mumble", "Price: number"])
  fs = F.fields(rows, form)
  @test [f.kind for f in fs] == [:words, :day, :words, :tick]
  @test fs[3].choices == ["Quote", "Booked", "Done"] && (fs[4].yes, fs[4].no) == ("Yes", "No")
  # A line whose words name no kind, and one whose column the table hasn't got
  @test F.stray(form, rows[1]) == [("Client", "mumble", :kind), ("Price", "number", :column)]
  # The line counts for more than the cells
  @test F.fields([["Ref"], ["12"], ["13"]], F.query(["Ref: words"]))[1].kind == :words
  @test F.row_line(["a | b", " c\nd ", ""]) == "| a \\| b | c d |  |"
end

# The folder is the test's own each time, so that two test processes that run at once don't write the same files
const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "jobs.md")
const start = """
# Jobs

| Client | Due | Status | Price |
|---|---|---|---|
| Smith | 2026-11-25 | Quote | \$4,200 |
| Jones | 2026-12-02 | Booked | \$950 |
| Brown | 2026-12-09 | Quote | \$1,300 |

```form
title: New job
Status: Quote, Booked
```

The end."""
write(page, start)

K.calendar_day[] = Date(2026, 11, 24)   # a Tuesday
const e = K.build_editor(page)
const w = Window(e, size=(900px, 800px))
const (; frames, key, shot) = drive(w, latest=true)
frames(4)
e.buf.anchor = e.buf.caret = (14, 3); K.touch!(e); frames(3)
form() = K.block_view(e, "form", 1)
field(k) = K.form_field(form(), k)

@testset "a form has a field for each column of the table above it" begin
  v = form()
  t = K.form_table(v)
  @test !(t isa String) && (t.first, t.last) == (3, 7)
  @test K.form_width(v) == 4
  frames(2)
  @test all(k -> rect(field(k)) !== nothing, (1, 2, 4))
  # A field for a day and one for a number say so while they're empty
  @test field(2).placeholder == "A day, like $(K.calendar_today())" && field(4).placeholder == "A number"
  # Status is a chooser with its words, and the first is picked
  choice = K.form_choice(v, 3)
  @test choice.group.labels == ["Quote", "Booked"] && choice.group.selected == 1 && rect(choice) !== nothing
  @test !haskey(v.parts, (:field, 3)) || rect(field(3)) === nothing
  # Add does nothing while every field is empty
  @test v.parts[(:button, :add)].off
end

@testset "Return adds a row with what's in the fields, and one ⌘Z takes it away" begin
  v = form()
  focus(field(1))
  field(1).text = "Lee"
  # Tab goes to the next field, and ⇧Tab to the one before. The page's text doesn't change.
  key(Keys.tab)
  @test w.focus === field(2)
  field(2).text = "2026-12-15"
  key(Keys.tab)
  # Tab gives the chooser the keyboard. → picks the next word, ← the one before, and a letter the word that starts with it.
  choice = K.form_choice(v, 3)
  @test w.focus === choice
  key(Keys.right)
  @test choice.group.selected == 2
  key(Keys.right); key(Keys.left)
  @test choice.group.selected == 1
  ontype(w, Typed('b', w)); frames(1)
  @test choice.group.selected == 2 && join(e.buf.lines, "\n") == start
  # A click on a word picks it, and gives the chooser the keyboard
  focus(field(1)); frames(1)
  r = rect(choice)
  click!(w, (r.left + 20px, r.top + r.height / 2)); frames(1)
  @test choice.group.selected == 1 && w.focus === choice
  key(Keys.right)
  # The raised part of the bar slides to the word for a quarter of a second, a step in each frame
  haskey(ENV, "LADDER_SHOTS") && (foreach(_ -> (sleep(0.04); frames(1)), 1:12); shot("form-choice.png"))
  w.keys |= Keys.shft; key(Keys.tab); w.keys ⊻= Keys.shft
  @test w.focus === field(2)
  key(Keys.tab); key(Keys.tab)
  field(4).text = "\$700"
  key(Keys.tab)
  @test w.focus === field(1)
  @test join(e.buf.lines, "\n") == start
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "form.png"), w.size) do ctx, size
    draw(ctx, size, scene(w))
  end
  key(Keys.enter)
  @test e.buf.lines[3:9] == ["| Client | Due | Status | Price |", "|---|---|---|---|", "| Smith | 2026-11-25 | Quote | \$4,200 |",
                             "| Jones | 2026-12-02 | Booked | \$950 |", "| Brown | 2026-12-09 | Quote | \$1,300 |", "| Lee | 2026-12-15 | Booked | \$700 |", ""]
  # The fields are empty again, the first has the keyboard, and the form says what it added
  @test all(k -> isempty(field(k).text), (1, 2, 4)) && w.focus === field(1) && choice.group.selected == 1
  @test v.said == "Added “Lee” to Jobs."
  # The caret stays with its text, a line further down
  @test e.buf.caret == (15, 3)
  K.undo!(e.buf); frames(2)
  @test join(e.buf.lines, "\n") == start
  # Esc gives the keyboard back to the page
  key(Keys.escape)
  @test w.focus === e
end

"Write `text` as the page, with the caret on line `i`, out of the form: a block with the caret in it shows its lines"
page_is(text, i) = (write(page, text); K.refresh!(e.buf); e.buf.caret = e.buf.anchor = (i, 0); frames(3))

@testset "`to` names the heading of the table that a form adds to" begin
  page_is("```form\nto: Prices\n```\n\n# Prices\n\n| Item | Cost |\n|---|---|\n| Pipe | 4 |\n\n# Other\n\nWords.", 13)
  t = K.form_table(form())
  @test !(t isa String) && t.first == 7
  # A heading that has no table, and a page with no table over the form
  page_is("```form\nto: Nothing\n```\n\nWords.", 5)
  @test K.form_table(form()) == "This page has no table called “Nothing”."
  page_is("Words.\n\n```form\n```", 1)
  @test K.form_table(form()) == "Put a table over this form, and the form adds rows to it."
  @test occursin("A form that adds rows to a table", K.page_html(e))
end

const jobs = """
# Jobs

| Client | Due | Price | Paid |
|---|---|---|---|
| Smith | 2026-11-25 | \$4,200 | No |
| Jones | 2026-12-02 | \$950 | Yes |

```form
```

The end."""
month() = (k = findfirst(p -> p.key == K.MONTH_KEY, collect(popups(w))); k === nothing ? nothing : collect(popups(w))[k])
state() = K.form_state(form())

@testset "a field for a day has a month under it while it has the keyboard" begin
  page_is(jobs, 11)
  @test month() === nothing
  focus(field(2)); frames(2)
  @test month() !== nothing && state().month == 2 && state().shows == Date(2026, 11, 1)
  shot("form-month.png")
  # ↓ in an empty field gives today, then the next day. ↑ goes back, and with ⌥ they go a week.
  key(Keys.down)
  @test field(2).text == "2026-11-24"
  key(Keys.down); key(Keys.down)
  @test field(2).text == "2026-11-26"
  key(Keys.up)
  w.keys |= Keys.opt; key(Keys.down); w.keys ⊻= Keys.opt
  @test field(2).text == "2026-12-02" && state().shows == Date(2026, 12, 1)
  # The buttons at its top show another month, and the field keeps its day and the keyboard
  K.act!(form(), (:month, 1), w); frames(1)
  @test state().shows == Date(2027, 1, 1) && field(2).text == "2026-12-02" && w.focus === field(2)
  K.act!(form(), (:month, 0), w); frames(1)
  @test state().shows == Date(2026, 11, 1)
  # A click on a day puts it in the field, and the month goes. The field keeps the keyboard.
  day = only(p for p in values(form().parts) if p isa K.MonthDay && p.day == Date(2026, 11, 27))
  click!(w, day); frames(1)
  @test field(2).text == "2026-11-27" && month() === nothing && w.focus === field(2)
  # ↓ shows the month again and leaves the day. Esc closes the month, and then gives the keyboard to the page.
  key(Keys.down)
  @test month() !== nothing && field(2).text == "2026-11-27"
  key(Keys.escape)
  @test month() === nothing && w.focus === field(2)
  # The button in the field shows it, and takes it away
  K.act!(form(), (:pick, 2), w); frames(2)
  @test month() !== nothing
  K.act!(form(), (:pick, 2), w); frames(2)
  @test month() === nothing
  key(Keys.escape)
  @test w.focus === e
  # The month goes when the keyboard leaves the field
  focus(field(2)); frames(2)
  @test month() !== nothing
  key(Keys.tab)
  @test month() === nothing && w.focus === field(3)
  field(2).text = ""
end

@testset "what's typed is written as the column writes it, and a field refuses what it doesn't take" begin
  v = form()
  focus(field(1)); frames(1)
  field(1).text = "Lee"
  key(Keys.tab)
  # Words that name a day become that day when the keyboard leaves the field
  field(2).text = "fri"; frames(1)
  shot("form-typed.png")
  key(Keys.tab)
  @test field(2).text == "2026-11-27" && w.focus === field(3)
  field(3).text = "700"
  key(Keys.tab)
  # The field shows the column's \$ beside what's typed, so the number in it has none
  @test field(3).text == "700" && F.shown(F.fields([["P"], ["\$4,200"]])[1], "-\$4,200") == "-4,200"
  # Paid is a box to tick. Space ticks it, and a click does too.
  tick = K.form_tick(v, 4)
  @test w.focus === tick && !tick.on
  ontype(w, Typed(' ', w)); frames(1)
  @test tick.on
  click!(w, tick); frames(1)
  @test !tick.on && w.focus === tick
  click!(w, tick); frames(1)
  # A field with words that are no day stops the add, gets the keyboard, and says so
  field(2).text = "soon"
  key(Keys.enter)
  @test join(e.buf.lines, "\n") == jobs && state().refused == 2 && w.focus === field(2) && month() === nothing
  shot("form-refused.png")
  field(2).text = "1 dec"
  key(Keys.enter)
  @test e.buf.lines[7] == "| Lee | 2026-12-01 | \$700 | Yes |"
  @test state().refused == 0 && !tick.on && w.focus === field(1)
  # A box that isn't ticked writes the column's word for no
  field(1).text = "Kim"
  key(Keys.enter)
  @test e.buf.lines[8] == "| Kim |  |  | No |"
end

@testset "a line of the block says what a field takes" begin
  page_is("| Client | Due | Status |\n|---|---|---|\n\n```form\nDue: day\nStatus: Quote, Booked\nPaid: yes/no\n```\n\nEnd.", 10)
  v = form()
  fs = K.form_fields(v)
  @test [f.kind for f in fs] == [:words, :day, :words] && fs[3].choices == ["Quote", "Booked"]
  @test K.form_choice(v, 3).group.labels == ["Quote", "Booked"]
  # The form says which line does nothing
  @test F.stray(v.spec, ["Client", "Due", "Status"]) == [("Paid", "yes/no", :column)]
  shot("form-stray.png")
end

K.calendar_day[] = nothing

@testset "the Insert menu has a form" begin
  @test any(x -> x isa Tuple && x[1] == "Form" && x[2][1] == "```form", K.INSERTS)
end

close(w)
