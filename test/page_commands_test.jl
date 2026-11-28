# Tests for a page's own commands, in main.jl: a function that a page's Julia
# code makes is a command of the palette while the page shows, once the code
# has run. Its arguments are its chips, and what it gives back shows under the
# top bar. Run them with `julia -O0 --project=. test/page_commands_test.jl`.
# They draw a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
@use "./drive" drive
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "jobs.md")
write(page, """
# Jobs

```julia
"Work out what a job costs"
invoice(client::String, hours::Number) = "\$client owes \$(hours * 90)"
"Count the hours of a week"
week(days::Int) = days * 8
helper(x) = x
```
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
const (; frames, typed, key) = drive(w, latest=true, slide=false)
frames()
K.focus(e)
names() = [String(c.name) for c in K.palette_commands(e)]

@testset "a page's functions are commands once its code has run" begin
  @test !("invoice" in names())
  K.page_run(e, page)
  frames()
  cs = K.page_commands(e)
  # Each function with a type for each argument, with its documentation. One with no types isn't a command.
  @test [(c.name, c.title, c.kind) for c in cs] == [(:invoice, "Work out what a job costs", :page), (:week, "Count the hours of a week", :page)]
  @test "invoice" in names() && "week" in names() && !("helper" in names()) && "theme" in names()
end

@testset "its arguments are chips, and what it gives back shows under the top bar" begin
  key(Keys.p, Keys.cmd, Keys.shft)
  typed("invoice")
  key(Keys.enter)
  p = K.palette(e)
  @test p.command.name == :invoice && [K.chip_name(c) for c in K.palette_chips(p)] == ["Client", "Hours"]
  typed("Ada"); key(Keys.enter)
  typed("3"); key(Keys.enter)
  # It isn't one of the commands that run at once, so Run runs it
  @test p.at == 3 && e.popup == :commands
  key(Keys.enter)
  @test e.popup == :none && first(K.said_result(e)) == "Invoice: Ada owes 270"
  @test any(x -> x.key == :result, popups(w))
  # A value that isn't words shows as Julia shows it
  key(Keys.p, Keys.cmd, Keys.shft)
  typed("week"); key(Keys.enter)
  typed("5"); key(Keys.enter); key(Keys.enter)
  @test first(K.said_result(e)) == "Week: 40"
end

close(w)
