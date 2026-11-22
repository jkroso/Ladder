# Tests for what changed in the file that shows, shown in the file itself, in
# main.jl: while the window shows a file that git keeps and that has changes,
# the top bar has a button beside the Commit button. A click on it gives the
# new lines a green background, and shows the lines that went in red under the
# line before them. A button on each change puts the last commit's lines back.
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

const px = K.px
const G = K.Git

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
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
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
"Draw until git has answered, and then what it said is on the screen"
again() = (G.forget!(); frames(2); G.wait!(); frames(2))
"The diff button of the top bar, or nothing"
button() = (b = get(e.nodes, :diff, nothing); b !== nothing && !isempty(K.diff_part(e)) ? b : nothing)
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
click(r) = begin
  x, y = r.left + r.width / 2, r.top + r.height / 2
  w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(Vec2{px}(x, y), w)); frames(1)
  w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(1)
  w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(2)
end
"The words of every Text that the last frame drew in the rectangle `r`, one after another"
drawn(r) = (out = String[]; walk(x) = (x.from isa K.Text ? push!(out, String(x.from.content)) : foreach(walk, x.children)); walk(r); join(out))
"Each line that went from the file, as the last frame drew it in the rectangle `r`"
gone_lines(r) = (out = String[]; walk(x) = (x.from isa K.Column && x.from.name == "Gone" ? append!(out, map(drawn, x.children)) :
                                             x.from isa K.Text || foreach(walk, x.children)); walk(r); out)
"The top of the item that shows line `i`"
top(i) = K.num(K.item(e, i).top)
"The plain layout of the page: where each line would be with no room for the lines that went"
plain_tops() = (items = K.layout!(e); Dict(it.first => K.num(it.top) for it in items))
shot(name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "diff-$name.png"), w)
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
  c = e.nodes[:commit]
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
  shot("page")
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
  plain = plain_tops()
  frames()
  @test all(it -> K.num(it.top) ≈ plain[it.first], e.layout)
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
  shot("code")
end

close(w)
