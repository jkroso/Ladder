# Tests for the page's text on its day, in main.jl: on a day before today, a
# page that git keeps shows what its last commit of that day had. The box of
# a to-do item has the tick of that day, a line that came later is fainter,
# and a board puts each card where its item was. Run them with
# `julia -O0 --project=. test/page_then_test.jl`. They make a repository in a
# temporary folder with the Mac's own git, and draw a window that isn't on
# the screen. Set `LADDER_SHOTS` to a folder, and they save pictures there.

@use Test: @test, @testset
@use Dates: Dates, Date, Day
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive
const px = K.px

# Wednesday 18 November 2026 counts as today
K.calendar_day[] = Date(2026, 11, 18)
nov(d) = Date(2026, 11, d)

const repo = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(repo, ".settings")
const page = joinpath(repo, "job.md")
git(args...; day=nothing) = begin
  env = copy(ENV)
  day === nothing || (env["GIT_AUTHOR_DATE"] = env["GIT_COMMITTER_DATE"] = "$(day)T12:00:00")
  run(pipeline(setenv(`git -C $repo -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`, env), stdout=devnull, stderr=devnull))
end
commit(text, day) = (write(page, text); git("add", "-A"); git("commit", "-m", "A commit"; day))

const BLOCKS = "\n```day\n```\n\n```board\n```\n"
git("init", "-b", "main")
commit("# A job\n\n- [ ] Dig the trench\n- [ ] Lay the pipe\n", nov(10))
commit("# A job\n\n- [x] Dig the trench\n- [ ] Lay the pipe\n\nThe pipe came on Friday.\n", nov(14))
# The page as it is now has a tick, a new item, a line that reads another way, and the two blocks. None of it is in a commit.
write(page, "# A job\n\n- [x] Dig the trench\n- [x] Lay the pipe\n- [ ] Fill the trench\n\nThe pipe came on Thursday.\n" * BLOCKS)

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
const (; frames, shot) = drive(w, frames=3)
frames()
const day = e.nodes[(:block, K.DAY_BLOCK, page, 1)]
const board = e.nodes[(:block, K.BOARD, page, 1)]
"Show the page on the day `d`, as the slider does"
on(d) = (K.set_day!(day, d); frames())
line(words) = findfirst(l -> occursin(words, l), e.buf.lines)
"What the box of the item with `words` shows: true for a tick"
box(words) = (i = line(words); K.pieces(e, e.buf.lines[i], K.kinds(e.buf)[i], false, i)[1].text == K.TODO_DONE)
names(c) = [t.name for t in K.columns!(board)[c]]

@testset "what git has of a page" begin
  h = K.page_history(K.page_key(page))
  @test h.root == repo && h.rel == "job.md" && [c[2] for c in h.commits] == [nov(14), nov(10)]
  @test K.commit_lines(h.root, h.commits[end][1], h.rel) == ["# A job", "", "- [ ] Dig the trench", "- [ ] Lay the pipe"]
  @test K.unticked("  - [x] Done") == "  - [ ] Done" && K.unticked("- [ ] Open") == "- [ ] Open" && K.unticked("Words [x]") == "Words [x]"
  # A page that no repository holds has no past
  other = joinpath(mktempdir(), "loose.md")
  write(other, "# Loose\n")
  @test K.page_history(K.page_key(other)) === nothing
end

@testset "today, the page shows as it is" begin
  @test K.page_then(e) === nothing && K.ticked_then(e, line("Lay the pipe")) === nothing
  @test box("Dig the trench") && box("Lay the pipe") && !box("Fill the trench")
  @test names(1) == ["Fill the trench"] && names(3) == ["Dig the trench", "Lay the pipe"]
  # The slider reaches back to the day of the first commit
  @test nov(10) in K.page_days(e)
  shot("then-today.png")
end

@testset "a day before today shows the ticks of that day" begin
  on(nov(15))
  then = K.page_then(e)
  @test then.lines[end] == "The pipe came on Friday."
  # Dig was ticked by then, Lay wasn't, and Fill wasn't on the page
  @test box("Dig the trench") && !box("Lay the pipe") && !box("Fill the trench")
  # The lines that came later, or read another way: the new item, the line about Thursday and the two blocks. A tick alone is no change.
  @test !then.later[line("Lay the pipe")] && then.later[line("Fill the trench")] && then.later[line("Thursday")] && !then.later[1]
  @test K.then_words(e) == "7 lines came later"   # the item, the line about Thursday, the three lines of the day's block and the two of the board's
  @test names(1) == ["Lay the pipe", "Fill the trench"] && names(3) == ["Dig the trench"] && K.past(board)
  shot("then-15.png")
  # A click on a box changes nothing while the page shows the past
  K.tick!(e, line("Lay the pipe"))
  @test e.buf.lines[line("Lay the pipe")] == "- [x] Lay the pipe"
  # The day of the first commit, and the days between two commits
  on(nov(12))
  @test !box("Dig the trench") && K.page_then(e).lines == ["# A job", "", "- [ ] Dig the trench", "- [ ] Lay the pipe"]
  @test names(3) == String[]
  # Before the first commit, every line came later
  on(nov(9))
  @test isempty(K.page_then(e).lines) && K.then_words(e) == "before this page's first commit"
  shot("then-9.png")
end

@testset "today again" begin
  on(nov(18))
  @test K.page_then(e) === nothing && box("Lay the pipe") && !K.past(board)
  K.tick!(e, line("Fill the trench"))
  @test e.buf.lines[line("Fill the trench")] == "- [x] Fill the trench"
end

K.calendar_day[] = nothing
close(w)
