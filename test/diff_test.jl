# Tests for what changed in the file that shows, shown in the file itself, in
# main.jl: while the window shows a file that git keeps and that has changes,
# the top bar has a button beside the Commit button. A click on it gives the
# new lines a green background, and shows the lines that went in red under the
# line before them. A button on each change puts the last commit's lines back.
# The chevrons beside the button go to the change before the caret and the next one.
# Run them with `julia -O0 --project=. test/diff_test.jl`. They make a
# repository in a temporary folder with the Mac's own git, and click in a
# window that isn't on the screen. With `LADDER_SHOTS` set to a folder, they
# save pictures there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive

const px = K.px
const G = K.Git

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const repo = joinpath(dir, "work")
mkpath(repo)
merge!(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null", "GIT_AUTHOR_NAME" => "Test", "GIT_AUTHOR_EMAIL" => "test@example.com",
                 "GIT_COMMITTER_NAME" => "Test", "GIT_COMMITTER_EMAIL" => "test@example.com"))
git(args...) = read(`git -C $repo -c commit.gpgsign=false $args`, String)
git("init", "-q", "-b", "main")
const page = joinpath(repo, "Readme.md")
const code = joinpath(repo, "work.jl")
const COMMITTED = "# Work\n\nWhat this is.\n\nWho it's for.\n\nOne.\n\nTwo.\n\nThree.\n\nFour.\n"
const CODE = "add(a, b) = a + b\n\nsub(a, b) = a - b\n\nmul(a, b) = a * b\n"
write(page, COMMITTED)
write(code, CODE)
git("add", "-A")
git("commit", "-q", "-m", "The first commit")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 760px))
const (; frames, click, typed, shot) = drive(w, frames=3, pressed=1, latest=true)
"Draw until git has answered, and then what it said is on the screen"
again() = (G.forget!(); frames(2); G.wait!(); frames(2))
"The diff button of the top bar, or nothing"
button() = (b = get(e.nodes, :diff, nothing); b !== nothing && !isempty(K.diff_part(e)) ? b : nothing)
"The words of every Text that the last frame drew in the rectangle `r`, one after another"
drawn(r) = (out = String[]; walk(x) = (x.from isa K.Text ? push!(out, String(x.from.content)) : foreach(walk, x.children)); walk(r); join(out))
"Each line that went from the file, as the last frame drew it in the rectangle `r`"
gone_lines(r) = (out = String[]; walk(x) = (x.from isa K.Column && x.from.name == "Gone" ? append!(out, map(drawn, x.children)) :
                                             x.from isa K.Text || foreach(walk, x.children)); walk(r); out)
"The top of the item that shows line `i`"
top(i) = K.num(K.item(e, i).top)
"The plain layout of the page: where each line would be with no room for the lines that went"
plain_tops() = (items = K.layout!(e); Dict(it.first => K.num(it.top) for it in items))
again()

@testset "a file with no change has no diff button" begin
  @test button() === nothing
  @test !K.works_here(e, Val(:show_changes_in_place))
  @test K.gone_now(e) === nothing
end

# Line 3 changes, the lines "Two." and "" after line 8 go, and a line comes at the end
const CHANGED = replace(COMMITTED, "What this is." => "What this is, and what it's for.", "Two.\n\n" => "") * "\nWhen to use it.\n"

@testset "a changed file has the diff button beside the Commit button" begin
  write(page, CHANGED)
  K.refresh!(e.buf)
  again()
  b = button()
  @test b !== nothing
  # While what changed doesn't show, there are no chevrons between the two
  c = K.state_of(e, K.CommitState).button
  @test K.num(rect(b).left) < K.num(rect(c).left) <= K.num(rect(b).left + rect(b).width) + 4   # just before it
  @test K.tip(b) == "Show what changed in Readme.md since the last commit"
  @test !K.BUTTONS[:diff].on(e)
  @test K.works_here(e, Val(:show_changes_in_place))
end

@testset "a click shows what changed in the file itself" begin
  plain = plain_tops()
  click(rect(button()))
  frames()
  @test K.diffing(e) && K.BUTTONS[:diff].on(e)
  @test K.tip(button()) == "Hide what changed in Readme.md since the last commit"
  @test e.buf.path == page && !K.dirty(e.buf)   # the file shows, as it was
  gone = K.gone_now(e)
  @test gone !== nothing
  lh = K.num(gone.lh)
  # The old line 3 goes under line 2, and the two lines that went go under line 8
  @test gone.after[2] == ["What this is."] && gone.after[8] == ["Two.", ""]
  # Each line moves down by the height of the old lines over it
  @test top(2) ≈ plain[2]
  @test top(3) ≈ plain[3] + lh
  @test top(9) ≈ plain[9] + 3lh
  # The old lines are drawn, in their room
  @test gone_lines(rect(e.nodes[:document])) == ["What this is.", "Two.", ""]
  # The new lines are marked, and a line that's the same isn't
  @test K.is_new(gone, K.item(e, 3)) && K.is_new(gone, K.item(e, length(e.buf.lines) - 1))
  @test !K.is_new(gone, K.item(e, 1)) && !K.is_new(gone, K.item(e, 7))
  # Each change has a button that puts it back, at the right end of its first line
  @test length(gone.diff.changes) == 3
  p = e.nodes[(:put_back, 1)]
  @test rect(p) !== nothing
  @test K.num(rect(p).left + rect(p).width) > 800
  shot("diff-page")
end

@testset "while what changed shows, two chevrons are beside the diff button, one over the other" begin
  b = button()
  up, down, c = rect(e.nodes[:previous_change]), rect(e.nodes[:next_change]), rect(K.state_of(e, K.CommitState).button)
  right(r) = K.num(r.left + r.width)
  @test right(rect(b)) <= K.num(up.left) <= right(rect(b)) + 4
  @test K.num(up.left) == K.num(down.left) && K.num(up.top + up.height) <= K.num(down.top)
  @test right(up) <= K.num(c.left) <= right(up) + 4
  # The two together are as tall as the diff button, and in line with it
  @test K.num(up.top) ≈ K.num(rect(b).top) && K.num(down.top + down.height) ≈ K.num(rect(b).top + rect(b).height)
  # The upper one's tooltip goes under both, so it doesn't cover the lower one
  @test K.num(K.tip_rect(e.nodes[:previous_change])[4]) ≈ 2K.num(up.height) &&
        K.num(K.tip_rect(e.nodes[:next_change])[4]) ≈ K.num(down.height)
end

@testset "the chevrons beside the diff button go from change to change, and round again" begin
  starts = [K.change_span(e.buf, c)[1] for c in K.gone_now(e).diff.changes]
  # The lines that went from after line 8 show over line 9, so that change is at line 9
  @test starts[1:2] == [3, 9] && starts[3] > 9
  up, down = e.nodes[:previous_change], e.nodes[:next_change]
  e.buf.caret = e.buf.anchor = (1, 0)
  frames()
  @test K.tip(down) == "Next change (1 of 3)" && K.tip(up) == "Previous change (3 of 3)"
  for i in (1, 2, 3, 1)   # after the last change comes the first
    click(rect(down))
    @test e.buf.caret == e.buf.anchor == (starts[i], 0)
  end
  @test K.tip(down) == "Next change (2 of 3)"
  click(rect(up))   # before the first comes the last
  @test e.buf.caret == (starts[3], 0)
  click(rect(up))
  @test e.buf.caret == (starts[2], 0)
  # From inside a change, the one before is the one over it
  e.buf.caret = e.buf.anchor = (starts[3], 3)
  click(rect(up))
  @test e.buf.caret == (starts[2], 0)
  @test K.works_here(e, Val(:next_change)) && K.works_here(e, Val(:previous_change))
  @test K.diffing(e)
end

@testset "the changes follow what you type" begin
  K.focus(e)
  e.buf.caret = e.buf.anchor = (7, 0)
  typed("Now ")
  frames()
  gone = K.gone_now(e)
  @test e.buf.lines[7] == "Now One."
  @test length(gone.diff.changes) == 4 && K.is_new(gone, K.item(e, 7))
  @test gone.after[6] == ["One."]
end

@testset "Put back puts the last commit's lines in place of a change, and ⌘Z takes it back" begin
  click(rect(e.nodes[(:put_back, 1)]))
  @test e.buf.lines[3] == "What this is."
  @test length(K.gone_now(e).diff.changes) == 3
  K.undo!(e.buf)
  frames()
  @test e.buf.lines[3] == "What this is, and what it's for."
  # The lines that went come back
  k = findfirst(((o, n),) -> isempty(n), K.gone_now(e).diff.changes)
  K.put_change_back!(e, k)
  frames()
  @test e.buf.lines[9:10] == ["Two.", ""]
  # The lines that came go
  k = findfirst(((o, n),) -> isempty(o), K.gone_now(e).diff.changes)
  K.put_change_back!(e, k)
  frames()
  @test !any(==("When to use it."), e.buf.lines)
  # With the other two put back, the page is as the last commit has it
  K.put_change_back!(e, 1); frames()
  K.put_change_back!(e, 1); frames()
  @test e.buf.lines == String.(split(COMMITTED, '\n'))
  @test isempty(K.gone_now(e).diff.changes)
end

@testset "a second click hides what changed, and the layout is plain again" begin
  K.undo!(e.buf); K.undo!(e.buf); frames()
  @test !isempty(K.gone_now(e).diff.changes)
  click(rect(button()))
  frames()
  @test !K.diffing(e) && K.gone_now(e) === nothing
  # The chevrons go too, and the Commit button is just after the diff button again
  @test K.num(rect(K.state_of(e, K.CommitState).button).left) <= K.num(rect(button()).left + rect(button()).width) + 4
  plain = plain_tops()
  frames()
  @test all(it -> K.num(it.top) ≈ plain[it.first], e.layout)
end

"The button with an eye that shows the agent's changes, while the top bar shows it, or nothing"
eye() = (b = get(e.nodes, :marks, nothing); b === nothing || rect(b) === nothing ? nothing : b)

@testset "the button that shows the agent's changes is there only while what changed shows" begin
  # The file changed on the disk earlier, as if an agent changed it
  @test !isempty(K.theirs(e))
  @test eye() === nothing
  click(rect(button()))
  frames()
  b = eye()
  @test b !== nothing
  # It's just before the diff button
  @test K.num(rect(b).left + rect(b).width) <= K.num(rect(button()).left) <= K.num(rect(b).left + rect(b).width) + 6
  click(rect(b))
  @test K.marking(e)
  # Hiding what changed hides the button, and the bars beside the agent's changes
  click(rect(button()))
  frames()
  @test eye() === nothing && !K.marking(e)
end

@testset "lines that went from over the first line show over it" begin
  over = joinpath(repo, "over.md")
  write(over, COMMITTED)
  git("add", "over.md")
  git("commit", "-q", "-m", "Add a page")
  write(over, replace(COMMITTED, "# Work\n\n" => ""))
  K.open!(e, over)
  again()
  click(rect(button()))
  frames()
  gone = K.gone_now(e)
  @test gone.above == ["# Work", ""]
  @test top(1) ≈ 2K.num(gone.lh)
  @test gone_lines(rect(e.nodes[:document])) == ["# Work", ""]
  click(rect(button()))
end

@testset "a file that git doesn't keep yet shows each of its lines as new" begin
  fresh = joinpath(repo, "fresh.md")
  write(fresh, "# Fresh\n\nA new page.\n")
  K.open!(e, fresh)
  again()
  @test button() !== nothing
  click(rect(button()))
  frames()
  gone = K.gone_now(e)
  @test gone !== nothing && isempty(gone.after) && isempty(gone.above)
  @test all(it -> K.is_new(gone, it), e.layout)
end

@testset "a file of code shows what changed beside its numbered lines" begin
  write(code, replace(CODE, "sub(a, b) = a - b" => "sub(a, b) = a - b - 0", "mul(a, b) = a * b\n" => ""))
  K.open!(e, code)
  again()
  click(rect(button()))
  frames()
  gone = K.gone_now(e)
  @test gone.after[2] == ["sub(a, b) = a - b"]
  @test gone_lines(rect(e.nodes[:document])) == ["sub(a, b) = a - b", "mul(a, b) = a * b"]
  @test K.is_new(gone, K.item(e, 3))
  shot("diff-code")
end

@testset "the chevrons scroll to each change, and the palette's command shows what changed first" begin
  long = joinpath(repo, "long.jl")
  lines = ["f$i() = $i" for i in 1:300]
  write(long, join(lines, "\n") * "\n")
  git("add", "long.jl")
  git("commit", "-q", "-m", "Add a long file")
  # Line 40 changes, line 150 goes, and a line comes after line 280
  lines[40] = "f40() = 40 + 0"
  deleteat!(lines, 150)
  insert!(lines, 280, "extra() = 0")
  write(long, join(lines, "\n") * "\n")
  K.open!(e, long)
  again()
  @test !K.diffing(e) && e.buf.caret[1] == 1
  shows(i) = (y = top(i) - K.num(e.scroll.offset); 0 < y < 760 - 100)
  # The palette's command goes to the next change while what changed doesn't show, and shows it
  K.next_change!(e)
  frames()
  @test K.diffing(e) && e.buf.caret == (40, 0) && shows(40)
  click(rect(e.nodes[:previous_change]))   # before the first comes the last
  @test e.buf.caret == (280, 0) && shows(280) && !shows(40)
  click(rect(e.nodes[:next_change]))
  @test e.buf.caret == (40, 0) && shows(40)
  click(rect(e.nodes[:next_change]))
  @test e.buf.caret == (150, 0) && shows(150)   # the line after the line that went
  @test K.gone_now(e).after[149] == ["f150() = 150"]
  click(rect(e.nodes[:next_change]))
  @test e.buf.caret == (280, 0) && shows(280) && !shows(40)
  click(rect(e.nodes[:previous_change]))
  @test e.buf.caret == (150, 0) && shows(150)
  # With no change to go to, a chevron does nothing: here the file is as the last commit has it
  write(long, read(`git -C $repo show HEAD:long.jl`, String))
  K.refresh!(e.buf)
  frames()
  @test K.change_after(e) === nothing && K.BUTTONS[:next_change].off(e)
  was = e.buf.caret
  K.next_change!(e)
  @test e.buf.caret == was
end

@testset "Put back leaves the caret where it was, so a block that a change was in shows as the block" begin
  job = joinpath(repo, "job.md")
  JOB = "# A job\n\nSome words.\n\n```day\n```\n\nThe end.\n"
  write(job, JOB)
  git("add", "job.md")
  git("commit", "-q", "-m", "Add a job")
  # The day picker wrote a day into its block
  write(job, replace(JOB, "```day\n```" => "```day\n2026-11-25\n```"))
  K.open!(e, job)
  again()
  click(rect(button()))
  frames()
  @test K.gone_now(e).diff.changes == [(6:5, 6:6)]
  e.buf.caret = e.buf.anchor = (3, 4)
  click(rect(e.nodes[(:put_back, 1)]))
  @test e.buf.lines[5:6] == ["```day", "```"]
  @test e.buf.caret == e.buf.anchor == (3, 4)
  # The block shows as the day picker, and not as its ``` lines
  @test !K.incode(e.buf, 5) && !occursin("```", drawn(rect(e.nodes[:document])))
  shot("diff-put-back-block")
  # A caret after the change moves with its line
  K.undo!(e.buf); frames()
  e.buf.caret = e.buf.anchor = (9, 2)
  K.put_change_back!(e, 1); frames()
  @test e.buf.lines[8] == "The end." && e.buf.caret == e.buf.anchor == (8, 2)
  click(rect(button()))
end

close(w)
