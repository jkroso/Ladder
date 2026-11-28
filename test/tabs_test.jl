# Tests for the tabs at the top of the sidebar: each file that shows stays open
# as a tab until ⌘W closes it. See "the files that are open, as tabs" and
# "closing a file" in windows.jl. Run them with `julia -O0 --project=. test/tabs_test.jl`.
# They click and press keys in windows that aren't on the screen.

@use "../main" => K
@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" KeyPress MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2

const px = K.px
const cmd, opt = Keys.cmd, Keys.opt

const dir = mktempdir()
# The settings and the place that these tests keep go to files of their own, not to the ones that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "settings")
K.PLACE_FILE[] = joinpath(dir, "place")
# A file that goes to the Trash here is only deleted
K.trasher[] = p -> (rm(p, recursive=true); true)

frames(w, n=2) = foreach(_ -> frame(w), 1:n)
shot(w, name) = haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], name), w)

"A folder of its own with the pages `names` in it"
folder(names...) = begin
  f = mktempdir(dir)
  foreach(name -> write(joinpath(f, name), "# $name\n\nThe text of $name.\n"), names)
  f
end
"A window that isn't on the screen on the first of the pages `names`, in a folder of its own, with the sidebar open"
window(names...; size=(900px, 700px)) = begin
  f = folder(names...)
  e = K.build_editor(joinpath(f, first(names)))
  w = K.window!(e, size=size)
  frames(w)
  sidebar!(e, w)
  e, w, f
end
"Open the sidebar and draw the window until it has finished its slide"
sidebar!(e, w) = begin
  e.panel || K.toggle_panel!(e)
  while K.opened(e) != 1
    frame(w)
  end
  frames(w)
end
"Show the files `names` of the folder `f`, one after another"
show!(e, w, f, names...) = foreach(n -> (K.open!(e, joinpath(f, n)); frames(w)), names)
"The names of the files of the tabs"
names(e) = basename.(K.tabs(e))
"Press the key `k` in window `w` with the keys `held` down"
press(w, k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames(w)
end
"Move the mouse to `x`, `y`"
hover(w, x, y) = (w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(Vec2{px}(x, y), w)); frames(w))
"Click the window at `x`, `y` with the mouse's button `button`"
click(w, x, y, button=Keys.mouse_left) = begin
  hover(w, x, y)
  w.keys |= button
  onkey(w, KeyPress{button}(0, w))
  w.keys ⊻= button
  frames(w)
end
middle(r) = (r.left + r.width / 2, r.top + r.height / 2)
"The key of the number `n` at the top of the keyboard"
digit(n) = getproperty(Keys, Symbol(n))
"The item of the tab of the file `name`"
tab(e, name) = only(item for item in K.tab_tree(e).children if basename(item.firstchild.path) == name)
"Every piece of text that a node shows"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.SemanticUI ? texts(K.describe(node), out) :
  node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end

@testset "each file that shows stays open as a tab, in the order that it opened" begin
  e, w, f = window("a.md", "b.md", "c.md")
  @test names(e) == ["a.md"]
  show!(e, w, f, "c.md", "b.md", "a.md")
  # A file that's open already keeps its place
  @test names(e) == ["a.md", "c.md", "b.md"]
  # A folder that shows in the page has no tab
  K.open_folder!(e, f); frames(w)
  @test e.buf.path == f && names(e) == ["a.md", "c.md", "b.md"]
  show!(e, w, f, "b.md")
  shot(w, "tabs.png")
  # The tabs are at the top of the sidebar, over the folder's files, one under another
  rows = [rect(tab(e, n)) for n in ("a.md", "c.md", "b.md")]
  @test all(r -> r !== nothing, rows)
  @test rows[1].top < rows[2].top < rows[3].top
  @test rows[3].top < rect(K.file_tree(e)).top
  @test rows[1].left < K.panel_w(e)
  # The tab of the file that shows is the one that's shaded
  @test K.tab_tree(e).focused === tab(e, "b.md")
  close(w)
end

@testset "a click on a tab shows its file" begin
  e, w, f = window("a.md", "b.md")
  show!(e, w, f, "b.md")
  K.type!(e, "words"); frames(w)
  click(w, middle(rect(tab(e, "a.md")))...)
  @test basename(e.buf.path) == "a.md"
  # The text has the keyboard again
  @test K.window_of(e).focus === e
  # A file's changes stay while another file shows, and its tab has a dot
  @test K.dirty(e.buffers[joinpath(f, "b.md")])
  @test K.tab_tree(e).focused === tab(e, "a.md")
  click(w, middle(rect(tab(e, "b.md")))...)
  @test basename(e.buf.path) == "b.md" && K.dirty(e.buf)
  close(w)
end

@testset "⌘W closes the tab and shows the one under it" begin
  e, w, f = window("a.md", "b.md", "c.md")
  show!(e, w, f, "b.md", "c.md", "b.md")
  press(w, Keys.w, cmd)
  @test names(e) == ["a.md", "c.md"] && basename(e.buf.path) == "c.md"
  # The last tab shows the one above it
  press(w, Keys.w, cmd)
  @test names(e) == ["a.md"] && basename(e.buf.path) == "a.md"
  # The last tab of all shows its folder, as ⌘W did before there were tabs
  press(w, Keys.w, cmd)
  @test isempty(K.tabs(e)) && e.buf.path == f && !K.nofile(e)
  # Then the folder closes, and then the window
  press(w, Keys.w, cmd)
  @test K.nofile(e) && e in K.editors
  press(w, Keys.w, cmd)
  @test !(e in K.editors)
end

@testset "⌘W on a folder's page shows the tab that showed last" begin
  e, w, f = window("a.md", "b.md")
  show!(e, w, f, "b.md", "a.md")
  K.open_folder!(e, f); frames(w)
  @test e.buf.path == f
  press(w, Keys.w, cmd)
  @test basename(e.buf.path) == "a.md" && names(e) == ["a.md", "b.md"]
  close(w)
end

@testset "⌘⌥← after ⌘W opens the file again, in a new tab" begin
  e, w, f = window("a.md", "b.md")
  show!(e, w, f, "b.md")
  press(w, Keys.w, cmd)
  @test names(e) == ["a.md"]
  press(w, Keys.left, cmd, opt)
  @test basename(e.buf.path) == "b.md" && names(e) == ["a.md", "b.md"]
  close(w)
end

@testset "the × of a tab closes it" begin
  e, w, f = window("a.md", "b.md", "c.md")
  show!(e, w, f, "b.md", "c.md")
  # The × shows only while the mouse is over the tab
  @test tab(e, "b.md").firstchild.close === nothing || rect(tab(e, "b.md").firstchild.close) === nothing
  hover(w, middle(rect(tab(e, "b.md")))...)
  x = tab(e, "b.md").firstchild.close
  @test x isa K.TabClose && rect(x) !== nothing
  shot(w, "tab-close.png")
  click(w, middle(rect(x))...)
  # The file that shows stays
  @test names(e) == ["a.md", "c.md"] && basename(e.buf.path) == "c.md"
  # The × of the tab of the file that shows closes it as ⌘W does
  hover(w, middle(rect(tab(e, "c.md")))...)
  click(w, middle(rect(tab(e, "c.md").firstchild.close))...)
  @test names(e) == ["a.md"] && basename(e.buf.path) == "a.md"
  close(w)
end

"The rectangles of the boxes called `called` that the last frame drew in the rectangle `r` of a node"
drawn_at(r, called, out=Any[]) = begin
  hasproperty(r.from, :name) && r.from.name == called && push!(out, r)
  hasproperty(r, :children) && foreach(c -> drawn_at(c, called, out), r.children)
  out
end
"The dots that the last frame drew in the tab of the file `name`"
dots(e, name) = drawn_at(rect(tab(e, name)), "Dot")

@testset "the × of a tab shows in the place of its dot" begin
  e, w, f = window("a.md", "b.md")
  show!(e, w, f, "b.md")
  # An agent waits for each page, so each tab has a dot
  K.page_agents(e).waiters = (time() + 1e6, [K.Agent.Waiter("", K.truepath(joinpath(f, n)), "Claude") for n in ("a.md", "b.md")])
  frames(w)
  dot = only(dots(e, "a.md"))
  hover(w, middle(rect(tab(e, "a.md")))...)
  x = rect(tab(e, "a.md").firstchild.close)
  shot(w, "tab-close-dot.png")
  # The dot hides, and the × has its middle where the dot had its middle
  @test isempty(dots(e, "a.md"))
  @test K.num(middle(x)[1]) ≈ K.num(middle(dot)[1]) atol=0.5
  @test K.num(middle(x)[2]) ≈ K.num(middle(dot)[2]) atol=0.5
  # The × is all inside the tab's row
  row = rect(tab(e, "a.md"))
  @test K.num(x.left + x.width) <= K.num(row.left + row.width)
  # The tab that the mouse isn't over keeps its dot
  @test length(dots(e, "b.md")) == 1
  # A tab with no dot has its × in the same place
  K.page_agents(e).waiters = (time() + 1e6, K.Agent.Waiter[])
  hover(w, middle(rect(tab(e, "b.md")))...)
  @test K.num(middle(rect(tab(e, "b.md").firstchild.close))[1]) ≈ K.num(middle(x)[1]) atol=0.5
  close(w)
end

@testset "a click with the middle button closes a tab" begin
  e, w, f = window("a.md", "b.md")
  show!(e, w, f, "b.md")
  click(w, middle(rect(tab(e, "a.md")))..., Keys.mouse_middle)
  @test names(e) == ["b.md"] && basename(e.buf.path) == "b.md"
  close(w)
end

@testset "two tabs with one name show their folders" begin
  e, w, f = window("a.md")
  other = joinpath(f, "Other")
  mkdir(other)
  write(joinpath(other, "a.md"), "# Another a\n")
  K.open!(e, joinpath(other, "a.md")); frames(w)
  said = texts(K.tab_tree(e))
  @test count(==("a.md"), said) == 2
  @test "Other" in said && basename(f) in said
  shot(w, "tabs-twins.png")
  # A name that only one tab has shows no folder
  close(w)
  e, w, f = window("a.md", "b.md")
  show!(e, w, f, "b.md")
  @test !(basename(f) in texts(K.tab_tree(e)))
  close(w)
end

@testset "a renamed file keeps its tab, and one that goes to the Trash loses it" begin
  e, w, f = window("a.md", "b.md", "c.md")
  show!(e, w, f, "b.md", "c.md", "b.md")
  K.move!(e, joinpath(f, "c.md"), joinpath(f, "see.md")); frames(w)
  @test names(e) == ["a.md", "b.md", "see.md"]
  # The file that shows goes, and the tab under it shows
  K.trash!(e, joinpath(f, "b.md")); frames(w)
  @test names(e) == ["a.md", "see.md"] && basename(e.buf.path) == "see.md"
  # Another file goes, and the file that shows stays
  K.trash!(e, joinpath(f, "a.md")); frames(w)
  @test names(e) == ["see.md"] && basename(e.buf.path) == "see.md"
  close(w)
end

@testset "a tab whose file has gone closes" begin
  e, w, f = window("a.md", "b.md")
  show!(e, w, f, "b.md", "a.md")
  delete!(e.buffers, joinpath(f, "b.md"))
  rm(joinpath(f, "b.md"))
  K.choose_tab!(e, joinpath(f, "b.md")); frames(w)
  @test names(e) == ["a.md"] && basename(e.buf.path) == "a.md"
  close(w)
end

@testset "many tabs scroll, and the tab of the file that shows is in sight" begin
  many = ["page $i.md" for i in 1:30]
  e, w, f = window(many...)
  show!(e, w, f, many[2:end]...)
  frames(w, 3)
  shot(w, "tabs-many.png")
  @test length(K.tabs(e)) == 30
  # The tabs take a third of the window under the top bar, and the folder's files are under them
  third = K.TOPBAR_H + (700px - K.TOPBAR_H) / 3
  last_row = rect(tab(e, "page 30.md"))
  @test last_row !== nothing
  @test rect(K.file_tree(e)).top < third + 60px
  # The last tab, which shows, is in the part of the list that's in sight
  scroll = e.nodes[:tabs_scroll]
  @test scroll.offset > 0px
  @test last_row.top + last_row.height <= third + 1px
  # The first one shows, and the list scrolls back to it
  K.open!(e, joinpath(f, "page 1.md")); frames(w, 3)
  @test scroll.offset == 0px
  close(w)
end

@testset "Ladder opens again with the tabs that were open" begin
  e, w, f = window("a.md", "b.md", "c.md")
  show!(e, w, f, "c.md", "b.md")
  K.keep_place!(e)
  close(w)
  # A file that has gone since has no tab
  rm(joinpath(f, "c.md"))
  p = K.take_place!()
  again = K.place_editor(p)
  @test basename(again.buf.path) == "b.md"
  @test names(again) == ["a.md", "b.md"]
  aw = K.window!(again, size=(900px, 700px)); frames(aw)
  close(aw)
end

@testset "the pages of the settings have no tabs" begin
  e, w, f = window("a.md")
  press(w, Keys.comma, cmd)
  s = K.settings_editor()
  @test isempty(K.tabs(s))
  close(K.window_of(s))
  close(w)
end

@testset "⌘T opens a new tab with the file finder" begin
  e, w, f = window("a.md", "b.md", "c.md")
  show!(e, w, f, "b.md")
  press(w, Keys.t, cmd)
  # The window shows no file, the finder is open, and New Tab is at the bottom of the tabs, shaded
  @test K.nofile(e) && K.new_tab(e) && e.popup == :finder
  @test K.tab_rows(e) == [joinpath(f, "a.md"), joinpath(f, "b.md"), ""]
  @test K.tab_tree(e).focused === tab(e, "")
  @test "New Tab" in texts(K.tab_tree(e))
  shot(w, "new-tab.png")
  # The file that the finder opens shows in the new tab's place
  K.open!(e, joinpath(f, "c.md")); frames(w)
  @test !K.new_tab(e) && names(e) == ["a.md", "b.md", "c.md"]
  @test !("New Tab" in texts(K.tab_tree(e)))
  close(w)
end

@testset "⌘W on a new tab shows the tab that showed last" begin
  e, w, f = window("a.md", "b.md")
  show!(e, w, f, "b.md", "a.md")
  press(w, Keys.t, cmd)
  e.popup = :none; frames(w)
  # The empty page says that ⌘W closes the tab, not the window
  @test texts(e.nodes[:page])[end] == "⌘W closes the tab"
  press(w, Keys.w, cmd)
  @test basename(e.buf.path) == "a.md" && names(e) == ["a.md", "b.md"] && !K.new_tab(e)
  @test e in K.editors
  close(w)
end

@testset "⌘T in a window with no tabs, and ⌘W twice closes it" begin
  e, w, f = window("a.md")
  press(w, Keys.w, cmd)   # the last tab closes, and the folder shows
  @test isempty(K.tabs(e)) && e.buf.path == f
  press(w, Keys.t, cmd)
  @test K.new_tab(e) && K.tab_rows(e) == [""]
  e.popup = :none
  press(w, Keys.w, cmd)   # the new tab closes, and the window shows no file
  @test K.nofile(e) && !K.new_tab(e) && e in K.editors
  @test texts(e.nodes[:page])[end] == "⌘W closes the window"
  press(w, Keys.w, cmd)
  @test !(e in K.editors)
end

@testset "⌘1 to ⌘9 show the tabs" begin
  e, w, f = window("a.md", "b.md", "c.md")
  show!(e, w, f, "b.md", "c.md")
  press(w, digit(1), cmd)
  @test basename(e.buf.path) == "a.md"
  press(w, digit(3), cmd)
  @test basename(e.buf.path) == "c.md"
  press(w, digit(2), cmd)
  @test basename(e.buf.path) == "b.md"
  # A tab that isn't there does nothing
  press(w, digit(9), cmd)
  @test basename(e.buf.path) == "b.md" && names(e) == ["a.md", "b.md", "c.md"]
  # A plain number is typed, and shows no tab
  press(w, digit(1))
  @test basename(e.buf.path) == "b.md"
  # They show from a new tab too
  press(w, Keys.t, cmd)
  e.popup = :none
  press(w, digit(1), cmd)
  @test basename(e.buf.path) == "a.md" && !K.new_tab(e)
  # The palette lists a tab's command only while the window has that tab
  @test K.works_here(e, Val(:tab_3)) && !K.works_here(e, Val(:tab_4))
  close(w)
end

"The boxes called `called` that the last frame drew in the rectangle `r` of a node. A Spinner draws a box called Spinner."
drawn(r, called, out=Any[]) = begin
  hasproperty(r.from, :name) && r.from.name == called && push!(out, r.from)
  hasproperty(r, :children) && foreach(c -> drawn(c, called, out), r.children)
  out
end
"Every ring that the last frame drew in the tab of the file `name`"
spinners(e, name) = (r = rect(tab(e, name)); r === nothing ? Any[] : drawn(r, "Spinner"))

@testset "a tab shows git's letter for a file with changes" begin
  repo = mktempdir(dir)
  git(args...) = run(pipeline(setenv(`git -C $repo -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false $args`,
                                     merge(ENV, Dict("GIT_CONFIG_GLOBAL" => "/dev/null"))), stdout=devnull, stderr=devnull))
  git("init", "-b", "main")
  foreach(n -> write(joinpath(repo, n), "# $n\n"), ("kept.md", "changed.md"))
  git("add", "-A")
  git("commit", "-m", "First")
  write(joinpath(repo, "changed.md"), "# changed.md\n\nMore.\n")
  write(joinpath(repo, "new.md"), "# new.md\n")
  e = K.build_editor(joinpath(repo, "kept.md"))
  w = K.window!(e, size=(900px, 700px))
  sidebar!(e, w)
  show!(e, w, repo, "changed.md", "new.md")
  # git's answer comes on another task
  t = time()
  while time() - t < 10 && !("M" in texts(tab(e, "changed.md").firstchild))
    sleep(0.05); frame(w)
  end
  shot(w, "tab-git.png")
  @test "M" in texts(tab(e, "changed.md").firstchild)
  @test "U" in texts(tab(e, "new.md").firstchild)
  @test !any(in(("M", "U")), texts(tab(e, "kept.md").firstchild))
  close(w)
end

@testset "a terminal's tab has a ring that turns while a command runs" begin
  K.Terms.USUAL[] = ["/bin/sh"]
  e, w, f = window("a.md")
  term = joinpath(f, "Terminal.vt")
  write(term, "")
  K.open!(e, term); frames(w)
  v = e.nodes[(:term, term)]
  until(done; seconds=10) = (t = time(); while !done() && time() - t < seconds; sleep(0.02); frame(w); end; frame(w); done())
  started = until(() -> K.Terms.running(v) && occursin("\$", K.Terms.Screens.words(v.term)))
  @test started
  # The shell waits for a command
  @test isempty(spinners(e, "Terminal.vt"))
  K.Terms.Ptys.send!(v.shell, "sleep 4\r")
  busy = until(() -> K.Terms.busy(v), seconds=3)
  @test busy
  # The tab shows the ring while another file shows too
  K.open!(e, joinpath(f, "a.md")); frames(w)
  @test length(spinners(e, "Terminal.vt")) == 1
  shot(w, "tab-terminal.png")
  idle = until(() -> !K.Terms.busy(v), seconds=10)
  @test idle
  @test isempty(spinners(e, "Terminal.vt"))
  close(w)
end

@testset "while ⌘ is held, each tab shows its keys" begin
  e, w, f = window("a.md", "b.md", "c.md")
  show!(e, w, f, "b.md", "c.md")
  said(name) = texts(tab(e, name).firstchild)
  hold!(held) = (w.keys |= held; onkey(w, KeyPress{Keys.cmd}(0, w)); frames(w))
  hold!(cmd)
  # A quick shortcut doesn't flash them
  @test !("⌘1" in said("a.md"))
  sleep(K.TAB_KEYS_WAIT + 0.05); frames(w)
  @test "⌘1" in said("a.md") && "⌘2" in said("b.md") && "⌘3" in said("c.md")
  shot(w, "tab-keys.png")
  # They go when ⌘ comes up
  w.keys ⊻= cmd; frames(w)
  @test !any(n -> any(startswith("⌘"), said(n)), ("a.md", "b.md", "c.md"))
  # ⌘ with another key held shows none
  hold!(cmd | Keys.shft)
  sleep(K.TAB_KEYS_WAIT + 0.05); frames(w)
  @test !("⌘1" in said("a.md"))
  w.keys ⊻= cmd | Keys.shft; frames(w)
  close(w)
end
