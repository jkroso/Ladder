# Tests for where Ladder opens: where the front window was when Ladder last
# quit, with the caret and the scroll where they were. See "where Ladder opens"
# in main.jl. Run them with `julia -O0 --project=. test/reopen_test.jl`. The
# windows aren't on the screen, and the place is kept in a file of the test's own.

@use "../main" => K
@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" KeyPress Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame

const px = K.px
const dir = mktempdir()
# The settings and the place that these tests keep go to files of their own, not to the ones that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "settings")
K.PLACE_FILE[] = joinpath(dir, "place")

const top = joinpath(dir, "Work")
const sub = joinpath(top, "Plans")
mkpath(sub)
const long = joinpath(top, "long.md")
write(long, "# Long\n\n" * join(["Line $i of a page that's longer than the window." for i in 1:200], "\n\n") * "\n")
write(joinpath(sub, "plan.md"), "# Plan\n\nThe plan.\n")

frames(w, n=3) = foreach(_ -> frame(w), 1:n)
"A window that isn't on the screen, for the editor `e`"
window(e) = (w = K.window!(e, size=(900px, 700px)); frames(w); w)
"What the place file says, by name"
kept() = Dict(split(l, '=', limit=2)[1] => split(l, '=', limit=2)[2] for l in eachline(K.PLACE_FILE[]))
"Open Ladder again on the place that it kept, as `open_editor` does with no file named"
reopen() = begin
  p = K.take_place!()
  p === nothing && return nothing
  e = K.place_editor(p)
  w = window(e)
  K.put_place!(e, p)
  frames(w)
  e
end

@testset "a file opens again with the caret and the scroll where they were" begin
  e = K.build_editor(long)
  w = window(e)
  e.buf.caret = e.buf.anchor = (81, 5)
  e.scroll.offset = 1200px
  frames(w)
  K.keep_place!(e)
  close(w)
  @test kept()["path"] == long && kept()["caret"] == "81,5" && kept()["folder"] == top
  @test parse(Float64, kept()["offset"]) == 1200
  again = reopen()
  # Ladder reads the place and deletes it, so a page that stops Ladder isn't where it opens the next time
  @test !isfile(K.PLACE_FILE[])
  @test again.buf.path == long && again.buf.caret == (81, 5) && again.buf.anchor == (81, 5)
  @test again.scroll.offset == 1200px && again.folder == top
  close(K.window_of(again))
end

@testset "a folder that showed in the page shows there again" begin
  e = K.blank_editor()
  K.open_folder!(e, sub)
  w = window(e)
  @test e.buf.path == sub
  K.keep_place!(e)
  close(w)
  @test kept()["path"] == sub
  again = reopen()
  @test again.buf.path == sub && again.folder == sub
  close(K.window_of(again))
end

@testset "a window whose file and folder ⌘W closed opens on its folder" begin
  e = K.build_editor(joinpath(sub, "plan.md"))
  w = window(e)
  K.close_file!(e)
  K.close_file!(e)
  @test K.nofile(e) && e.folder == sub
  K.keep_place!(e)
  close(w)
  again = reopen()
  @test again.buf.path == sub
  close(K.window_of(again))
end

@testset "the sidebar lists the folder that it listed" begin
  e = K.build_editor(long)
  w = window(e)
  K.go_folder!(e, sub)
  K.keep_place!(e)
  close(w)
  again = reopen()
  @test again.buf.path == long && again.folder == sub
  close(K.window_of(again))
end

@testset "a place that's gone opens nothing" begin
  gone = joinpath(top, "gone.md")
  write(gone, "# Gone\n")
  e = K.build_editor(gone)
  K.keep_place!(e)
  rm(gone)
  @test K.take_place!() === nothing && !isfile(K.PLACE_FILE[])
  # A folder that the Finder shows as one file, like an app, would open in its own app, so it's nowhere too
  app = joinpath(dir, "Thing.app")
  mkpath(joinpath(app, "Contents"))
  write(K.PLACE_FILE[], "path=$app\nfolder=$dir\n")
  @test K.take_place!() === nothing
  # No file is no place
  @test K.take_place!() === nothing
  # A window that shows no file and lists no folder that's there leaves the file as it was
  write(K.PLACE_FILE[], "path=$long\n")
  e = K.Editor()
  K.keep_place!(e)
  @test kept()["path"] == long
  rm(K.PLACE_FILE[])
end

@testset "Ladder keeps the place of the last window that was in front" begin
  first, other = K.build_editor(long), K.build_editor(joinpath(sub, "plan.md"))
  was = K.LAST_FRONT[]
  K.LAST_FRONT[] = nothing
  @test K.quit_editor(first) === first
  K.LAST_FRONT[] = other
  @test K.quit_editor(first) === other
  K.LAST_FRONT[] = was
end

@testset "the startup page says when it opens" begin
  @test occursin("the first time it starts", K.startup_text())
end
