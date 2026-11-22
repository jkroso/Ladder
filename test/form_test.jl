# Tests for forms.jl and main.jl's "a form that adds a row to a table": a
# `form` block shows a field for each column of a table, and adds a row. Run
# them with `julia -O0 --project=. test/form_test.jl`. Set `LADDER_SHOTS` to a
# folder, and they save a picture of the form there.

@use Test: @test, @testset
@use "../forms" => F
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect scene draw draw_tool window_tool focus
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

@testset "what a form's block says, and what each field takes" begin
  @test F.query(["title: New job", "to: Jobs 2", "colour: red"]) == F.Form(title="New job", to="Jobs 2")
  @test F.query(String[]) == F.Form()
  rows = [["Client", "Due", "Status", "Price", ""], ["Smith", "2026-11-25", "Quote", "\$4,200", ""],
          ["Jones", "2026-12-02", "Booked", "950", "x"], ["Brown", "2026-12-09", "Quote", "1,300.50", ""]]
  fs = F.fields(rows)
  @test [f.name for f in fs] == ["Client", "Due", "Status", "Price", "Column 5"]
  @test [f.kind for f in fs] == [:words, :day, :words, :number, :words]
  # Words that come again are the field's choices. Words that don't, aren't.
  @test fs[3].choices == ["Quote", "Booked"] && isempty(fs[1].choices) && isempty(fs[5].choices)
  @test F.row_line(["a | b", " c\nd ", ""]) == "| a \\| b | c d |  |"
end

const dir = joinpath(tempdir(), "ladder-form-test")
rm(dir, recursive=true, force=true)
mkpath(dir)
@eval K settings_file() = $(joinpath(dir, "settings"))
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
```

The end."""
write(page, start)

const e = K.build_editor(page)
const w = Window(e, size=(900px, 800px))
frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames(4)
e.buf.anchor = e.buf.caret = (13, 3); K.touch!(e); frames(3)
form() = K.block_view(e, "form", 1)
field(k) = K.form_field(form(), k)
key(k) = (onkey(w, KeyPress{k}(0, w)); frames(1))

@testset "a form has a field for each column of the table above it" begin
  v = form()
  t = K.form_table(v)
  @test !(t isa String) && (t.first, t.last) == (3, 7)
  @test K.form_width(v) == 4
  frames(2)
  @test all(k -> rect(field(k)) !== nothing, 1:4)
  # A field for a day and one for a number say so while they're empty
  @test field(2).placeholder == "A day, like $(K.calendar_today())" && field(4).placeholder == "A number"
  # Status has a button for each of its words
  @test haskey(v.parts, (:button, (:choice, 3, 1))) && v.parts[(:button, (:choice, 3, 2))].words == "Booked"
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
  # A button of the field puts its word in it
  K.act!(v, (:choice, 3, "Booked"), w); frames(1)
  @test field(3).text == "Booked" && w.focus === field(3)
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
  @test all(k -> isempty(field(k).text), 1:4) && w.focus === field(1)
  @test v.said == "Added “Lee” to Jobs."
  # The caret stays with its text, a line further down
  @test e.buf.caret == (14, 3)
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

@testset "the Insert menu has a form" begin
  @test any(x -> x isa Tuple && x[1] == "Form" && x[2][1] == "```form", K.INSERTS)
end

close(w)
