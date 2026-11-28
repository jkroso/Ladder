# Tests for when a line last changed, in main.jl and git.jl: a click on the
# number of a line, in a file that git keeps, shows the commit that last
# changed the line, with the lines that were there before. Run them with
# `julia -O0 --project=. test/line_history_test.jl`. They make a repository in
# a temporary folder with the Mac's own git, and click in a window that isn't
# on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "../folders/git" => Git
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Typed Keys onkey onmouse ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
@use GeometryBasics: Vec2
@use "./drive" drive
const px = K.px

const repo = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(repo, ".settings")
const file = joinpath(repo, "walls.jl")
git(args...; day=nothing) = begin
  env = copy(ENV)
  day === nothing || (env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = "$(day)T12:00:00")
  run(pipeline(setenv(`git -C $repo -c user.name=Ada -c user.email=ada@example.com -c commit.gpgsign=false $args`, env), stdout=devnull, stderr=devnull))
end
commit(text, words, day) = (write(file, text); git("add", "-A"); git("commit", "-m", words; day))

git("init", "-b", "main")
commit("height = 2.4\nlong = 5.0\narea = height * long\n", "Start the walls", "2026-11-10")
commit("height = 2.7\ntall = true\nlong = 5.0\narea = height * long\n", "The walls are taller", "2026-11-14")
# The file as it is now has a line that's in no commit
write(file, "height = 2.7\ntall = true\nlong = 5.0\narea = height * long\npaint = area / 10\n")

@testset "what git says of a line" begin
  ask(line, text=read(file, String)) = (p = Git.blame(repo, "walls.jl", line, text); wait(p[1]); Git.read_blame(String(take!(p[2]))))
  c = ask(1)
  @test c.who == "Ada" && c.words == "The walls are taller" && c.line == 1 && c.file == "walls.jl" && length(c.hash) == 40
  @test K.day_words(c.at) == "14 Nov 2026"
  @test Git.before(repo, c) == ["height = 2.4"]
  # A line that the commit wrote with the line over it has what the two took the place of
  c = ask(2)
  @test c.words == "The walls are taller" && Git.before(repo, c) == ["height = 2.4"]
  # A line of the first commit is the third line now, and was the second then
  c = ask(3)
  @test c.words == "Start the walls" && c.line == 2 && isempty(Git.before(repo, c))
  # A line that's in no commit, in the file and in text that's newer than the file
  @test isempty(ask(5).hash)
  @test isempty(ask(1, "height = 3.0\ntall = true\nlong = 5.0\n").hash)
  @test Git.read_blame("") === nothing
end

const e = K.build_editor(file)
const w = Window(e, size=(900px, 600px))
const (; frames) = drive(w, latest=true)
frames(4)
"Click the number of line `i`"
click_number(i) = begin
  it = K.item(e, i)
  pos = Vec2{px}(e.origin[1] - K.gutter(e) + 6px, e.origin[2] + it.top + it.tall / 2)
  w.mouse = typeof(w.mouse)(pos...)
  onmouse(w, MouseMove(pos, w))
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  onkey(w, KeyRelease{Keys.mouse_left}(0, w))
  # git answers in a later frame
  from = time()
  while (a = K.state_of(e, K.LineHistory).asked) !== nothing && a.found === nothing && time() - from < 10
    frames(1)
    sleep(0.02)
  end
  frames()
  K.state_of(e, K.LineHistory).asked
end
shown() = any(p -> p.key == :line_asked, popups(w))
"Each Text in the layout `x`"
texts(x) = begin
  hasfield(typeof(x), :content) && getfield(x, :content) isa AbstractString && return Any[x]
  out, c = Any[], hasfield(typeof(x), :firstchild) ? x.firstchild : nothing
  while c !== nothing
    append!(out, texts(c))
    c = c.nextsibling
  end
  out
end

@testset "a click on a line's number shows its commit" begin
  @test K.number_at(e, (e.origin[1] - 20px, e.origin[2] + 5px)) == 1
  @test K.number_at(e, (e.origin[1] + 20px, e.origin[2] + 5px)) === nothing
  a = click_number(1)
  @test a.found.words == "The walls are taller" && a.before == ["height = 2.4"] && shown()
  @test e.buf.caret[1] == 1
  # The line as it was has the colours of code, as the file is Julia
  card = only(p for p in popups(w) if p.key == :line_asked).content.content
  @test any(x -> x.content == "2.4" && x.color == K.TIP_CODE.number, texts(card))
  # The words stay while the mouse moves, and go at the next key
  onmouse(w, MouseMove(Vec2{px}(300px, 300px), w))
  frames()
  @test shown()
  K.focus(e)
  ontype(e, Typed('x', w))
  frames()
  @test !shown() && K.state_of(e, K.LineHistory).asked === nothing
  # The line that was typed in is in no commit
  a = click_number(e.buf.caret[1])
  @test isempty(a.found.hash) && shown()
  K.undo!(e.buf)
  frames()
  @test !shown()
  a = click_number(3)
  @test a.found.words == "Start the walls" && isempty(a.before)
end

@testset "a file that git doesn't keep has nothing to show" begin
  loose = joinpath(mktempdir(), "loose.jl")
  write(loose, "x = 1\n")
  K.open!(e, loose)
  frames()
  @test click_number(1) === nothing && !shown()
end

close(w)
