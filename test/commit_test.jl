# Tests for the commit of the file that shows, in main.jl: while the window
# shows a file that git keeps and that has changes, the top bar has a button
# that opens the palette with Commit taken. Run commits that file alone. Run
# them with `julia -O0 --project=. test/commit_test.jl`. They make a repository
# in a temporary folder with the Mac's own git, and click in a window that
# isn't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use GeometryBasics: Vec2

const px = K.px
const G = K.Git

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
const repo = joinpath(dir, "work")
mkpath(repo)
# The commits that Ladder makes here have a name and no signature, whatever the Mac's own settings of git say
merge!(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
                 "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"))
git(args...) = read(`git -C $repo -c commit.gpgsign=false $args`, String)
git("init", "-q", "-b", "main")
const page = joinpath(repo, "Readme.md")
const other = joinpath(repo, "notes.md")
write(page, "# Work\n\nWhat this is.\n")
write(other, "# Notes\n")
git("add", "-A")
git("commit", "-q", "-m", "The first commit")

# Nothing here asks the real Claude for a message
K.MESSAGE_COMMAND[] = `/usr/bin/false`

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 700px))
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
"Draw until git has answered, and then what it said is on the screen"
again() = (G.forget!(); frames(2); G.wait!(); frames(2))
"The button of the top bar that commits, or nothing"
button() = (b = get(e.nodes, :commit, nothing); b !== nothing && !isempty(K.commit_part(e)) ? b : nothing)
press(k, held...) = (foreach(h -> w.keys |= h, held); onkey(w, KeyPress{k}(0, w)); foreach(h -> w.keys ⊻= h, held);
                     haskey(e.nodes, :palette) && (e.nodes[:palette].moved = 0.0); frames())
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
click(r) = begin
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(Vec2{px}(x, y), w)); frames(1)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2)
end
subjects() = split(chomp(git("log", "--format=%s")), '\n')
status() = strip(git("status", "--porcelain"))
again()

@testset "a file with no change has no button, and Commit isn't in the palette" begin
  @test K.commit_change(e, page) === nothing && button() === nothing
  @test !K.works_here(e, Val(:commit))
end

@testset "a changed file has the button, and it commits that file alone" begin
  write(page, "# Work\n\nWhat this is, and what it's for.\n")
  write(other, "# Notes\n\nMore.\n")
  K.refresh!(e.buf)
  again()
  @test K.commit_change(e, page) == :changed && button() !== nothing
  # With the switch "Write the message myself" on, the click opens the palette with Commit taken, and the keyboard
  # in its words. With it off, Claude writes the message: see commit_menu_test.jl.
  e.own = true
  click(rect(button()))
  p = K.palette(e)
  @test e.popup == :commands && p.command.name == :commit && [K.chip_name(c) for c in K.palette_chips(p)] == ["Message"] && p.at == 1
  @test w.focus === K.input(e)
  typed("Say what it's for")
  press(Keys.enter)   # to the Run button
  press(Keys.enter)
  @test e.popup == :none && isempty(p.fault)
  @test subjects() == ["Say what it's for", "The first commit"]
  # The other file still has its change, and the page has none, so the button goes
  @test status() == "M notes.md"
  again()
  @test button() === nothing
end

@testset "changes that aren't saved are saved, and then committed" begin
  K.focus(e)
  e.buf.caret = e.buf.anchor = (3, 0)
  typed("Now: ")
  @test K.dirty(e.buf) && K.commit_change(e, page) == :changed && button() !== nothing
  K.commit_file!(e, K.FS.File(page), "Start with now")
  @test !K.dirty(e.buf) && first(subjects()) == "Start with now"
  @test occursin("Now: What this is", git("show", "HEAD:Readme.md"))
end

@testset "a file that git doesn't keep yet is added, and words are needed" begin
  fresh = joinpath(repo, "fresh.md")
  write(fresh, "# Fresh\n")
  again()
  @test K.commit_change(e, fresh) == :new
  @test_throws ErrorException K.commit_file!(e, K.FS.File(fresh), "  ")
  K.commit_file!(e, K.FS.File(fresh), "Add a fresh page")
  @test first(subjects()) == "Add a fresh page" && status() == "M notes.md"
  # A file with no change has nothing to commit. git is asked now, so what it said before the commit doesn't count,
  # and the file stays in git.
  @test_throws ErrorException K.commit_file!(e, K.FS.File(fresh), "Again")
  @test status() == "M notes.md" && first(subjects()) == "Add a fresh page"
end

@testset "a commit that git refuses says why, and leaves the file as it was" begin
  hook = joinpath(repo, ".git", "hooks", "pre-commit")
  write(hook, "#!/bin/sh\necho 'Not today.'\nexit 1\n")
  chmod(hook, 0o755)
  late = joinpath(repo, "late.md")
  write(late, "# Late\n")
  again()
  failed = try K.commit_file!(e, K.FS.File(late), "Add it late"); "" catch x; x.msg end
  @test failed == "git didn't commit it: Not today."
  # git forgot the file again, so it's still one that git doesn't keep
  @test occursin("?? late.md", status())
  rm(hook)
end
