# Tests for the setting that saves a page when you leave its window, in
# main.jl. Run them with `julia -O0 --project=. test/autosave_test.jl`. The
# window isn't on the screen, so the tests say that it stopped being the front
# window, as macOS does for a real one.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const page = joinpath(dir, "notes.md")
const other = joinpath(dir, "other.md")
write(page, "# Notes\n\nSome text.\n")
write(other, "# Other\n")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 800px))
const (; frames) = drive(w)
frames()
"Type `text` at the end of the page that shows"
add!(text) = (K.edit!(e.buf, K.line_end(e.buf, length(e.buf.lines)), K.line_end(e.buf, length(e.buf.lines)), text); frames())

@testset "the setting is off until you turn it on" begin
  @test !e.autosave
  add!("More.")
  K.left!(e)
  @test K.dirty(e.buf) && read(page, String) == "# Notes\n\nSome text.\n"
end

@testset "a window that's left saves its pages" begin
  e.autosave = true
  K.left!(e)
  @test !K.dirty(e.buf) && endswith(read(page, String), "More.")
  # A page of the window that doesn't show now is saved too
  add!(" And more.")
  K.open!(e, other); frames()
  add!("Second page.")
  @test K.dirty(e.buffers[page]) && K.dirty(e.buf)
  K.left!(e)
  @test !K.dirty(e.buffers[page]) && !K.dirty(e.buf)
  @test endswith(read(page, String), "More. And more.") && endswith(read(other, String), "Second page.")
  # A page with no changes isn't written again
  at = mtime(other)
  K.left!(e)
  @test mtime(other) == at
end

@testset "what a block of the page holds is saved with it" begin
  write(joinpath(dir, "tally.jl"), """
  mutable struct Tally; n::Int end
  tally(lines) = Tally(something(tryparse(Int, strip(get(lines, 1, ""))), 0))
  written(t::Tally) = [string(t.n)]
  """)
  job = joinpath(dir, "job.md")
  write(job, "# A job\n\n```tally\n3\n```\n\nThe end.\n")
  K.open!(e, job); frames()
  v = e.nodes[(:block, "tally", job, 1)]
  v.value.n = 4; frames()
  # The block hasn't asked for a write, so the page doesn't know of the change yet
  @test !K.dirty(e.buf)
  K.left!(e)
  @test occursin("```tally\n4\n```", read(job, String)) && !K.dirty(e.buf)
end

@testset "a page with no file stays as it is" begin
  o = K.build_editor(dir)
  o.autosave = true
  K.left!(o)
  @test true
end

@testset "the setting goes to the settings file, and back" begin
  home = mktempdir()
  withenv("HOME" => home) do
    e.remember = true
    K.autosave!(e, true)
    @test occursin("autosave=true", read(K.settings_file(), String))
    @test K.load_settings!(K.Editor()).autosave
    K.autosave!(e, false)
    @test !K.load_settings!(K.Editor()).autosave
    e.remember = false
  end
  # The settings page has a box for it
  @test occursin("page_autosave!", read(K.settings_page(), String))
end

close(w)
