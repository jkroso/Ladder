# Tests for what code from the startup page can add to Ladder: the tables that
# Ladder calls at its own times, a command with its key, and an item of the
# Insert menu. A folder has no table: test/folder_kind_test.jl has the tests
# for a kind of folder. See "what code from the startup page adds to" in commands.jl. Run
# them with `julia -O0 --project=. test/extend_test.jl`. They add a small
# extension of their own, called `:notes`, and click in a window that isn't on
# the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

const dir = mktempdir()
const notes = joinpath(dir, "notes")
mkpath(joinpath(notes, "old"))
write(joinpath(notes, "one.md"), "---\nkind: note\n---\n\nThe first note.\n")
write(joinpath(notes, "two.md"), "# Two\n")
write(joinpath(dir, "page.md"), "# A page\n\n```ui\nnotes_count()\n```\n")

const e = K.build_editor(joinpath(notes, "one.md"))
const w = Window(e, size=(1000px, 700px))
const (; frames, at, click, key) = drive(w)
frames()
K.focus(e)

"Each Text in the layout `node`, in the order they read"
texts(node, out=String[]) = begin
  node isa K.Text ? push!(out, node.content) : node isa K.GeometricUI && foreach(n -> texts(n, out), node.children)
  out
end
bar() = texts(K.describe(e.nodes[:topbar]))
"True when the page that shows is in the folder of notes"
innotes(e) = startswith(e.buf.path, notes * "/")
"""
Take the test's extension out of every table, and take away its command and
its item of the Insert menu. The tests that run after this one in the same
process then have Ladder's own commands and menu.
"""
forget() = begin
  foreach(t -> delete!(t, :notes), (K.EACH_FRAME, K.AT_QUIT, K.BAR_PARTS, K.BUTTONS, K.PAGE_TITLES, K.MATTER_TITLES, K.MATTER_CARDS,
                                    K.PAGE_NAMES, K.FIELD_KEYS, K.SETTINGS_FOLDERS))
  delete!(K.COMMANDS, :note_file)
  filter!(g -> first(g) != "Notes", K.COMMAND_GROUPS)
  filter!(a -> last(a).name != :note_file, K.ADDED_COMMANDS)
  menu = last(K.PAGE_MENU[findfirst(x -> x isa Pair && first(x) == "Insert", K.PAGE_MENU)])
  was = findfirst(x -> x isa Tuple && x[1] == "Note", K.INSERTS)
  was === nothing || (deleteat!(K.INSERTS, was); deleteat!(menu, was))
  nothing
end

@testset "with nothing added, Ladder is as it was" begin
  forget()
  @test K.bar_parts(e) == ()
  @test K.page_title(e) === nothing && K.first_answer(K.MATTER_TITLES, e) === nothing
  @test "one.md" in bar() || "one" in bar()
end

@testset "a turn in each frame" begin
  seen = Any[]
  K.EACH_FRAME[:notes] = o -> push!(seen, o)
  frames(3)
  @test length(seen) == 3 && all(o -> o === e, seen)
  # The same name again takes the place of the function that was there
  K.EACH_FRAME[:notes] = o -> nothing
  frames(2)
  @test length(seen) == 3 && haskey(K.EACH_FRAME, :notes)
end

@testset "a button in the top bar, with what it does and says" begin
  done = Ref(0)
  busy = Ref(false)
  K.BUTTONS[:notes] = (run=o -> (done[] += 1), tip=o -> "File the note", off=o -> busy[], strong=true)
  K.BAR_PARTS[:notes] = o -> innotes(o) ? (K.button(o, :notes, "archive"),) : ()
  frames()
  b = e.nodes[:notes]
  @test b isa K.ToolButton && b.rect[3] > 0px && K.tip(b) == "File the note" && !K.off(b)
  click(middle(b.rect))
  @test done[] == 1
  # A page that the function has no buttons for gets none
  K.open!(e, joinpath(dir, "page.md")); frames()
  @test K.bar_parts(e) == ()
  K.open!(e, joinpath(notes, "one.md")); frames()
  @test length(K.bar_parts(e)) == 1
  # While the code says the button is off, it shows that
  busy[] = true
  @test K.off(e.nodes[:notes]) && K.cursor(e.nodes[:notes]) == :arrow
  busy[] = false
end

@testset "the name of the page in the top bar, and of its card" begin
  K.PAGE_TITLES[:notes] = o -> innotes(o) ? "A note of mine" : nothing
  K.MATTER_TITLES[:notes] = o -> innotes(o) ? "NOTE" : nothing
  frames()
  @test K.page_title(e) == "A note of mine" && "A note of mine" in bar()
  card = texts(K.describe(e.nodes[:matter]))
  @test "NOTE" in card && !("FRONTMATTER" in card)
  K.open!(e, joinpath(dir, "page.md")); frames()
  @test K.page_title(e) === nothing && any(t -> startswith(t, "page"), bar())
  K.open!(e, joinpath(notes, "one.md")); frames()
end

@testset "a node of its own in place of the card of the front matter" begin
  # The node gets the keys of the front matter, and the page makes room for it
  got = Ref{Any}(nothing)
  K.MATTER_CARDS[:notes] = (o, rows) -> innotes(o) ? (got[] = rows; K.node!(K.MatterCard, o, :note_top)) : nothing
  frames()
  @test got[] == [(2, "kind", "note")] && e.layout[1].content.node === e.nodes[:note_top] && e.layout[1].tall > 0px
  # The node has no levels of its own. While it has the keyboard, the top bar's ladder is still the page's: the page answers for it.
  K.focus(e.nodes[:note_top]); frames()
  @test w.focus === e.nodes[:note_top] && K.head_in_charge(e) === nothing
  @test K.levels(e) == K.PAGE_LEVELS && K.level(e) == K.level(K.node!(K.Document, e, :document))
  K.focus(e); frames()
  # A page that the function has no node for has the card
  write(joinpath(dir, "plain.md"), "---\nkind: page\n---\n\nText.\n")
  K.open!(e, joinpath(dir, "plain.md")); frames()
  @test e.layout[1].content.node === e.nodes[:matter]
  K.open!(e, joinpath(notes, "one.md")); frames()
  delete!(K.MATTER_CARDS, :notes)
  frames()
  @test e.layout[1].content.node === e.nodes[:matter]
end

@testset "a command with a key, in a group of the key bindings page" begin
  # What this test added when it ran before in the same process goes first
  delete!(K.COMMANDS, :note_file); filter!(g -> first(g) != "Notes", K.COMMAND_GROUPS)
  ran = Ref(0)
  n = length(K.COMMANDS)
  K.add_commands!("Notes", [K.Command(:note_file, "File the note", :window, "ctrl+cmd+n", (o, win, _) -> (ran[] += 1))])
  @test length(K.COMMANDS) == n + 1 && first(last(K.COMMAND_GROUPS)) == "Notes" && K.caps(first(K.keys_now(e).of[:note_file])) == "⌃⌘N"
  key(Keys.n, Keys.ctrl, Keys.cmd)
  @test ran[] == 1
  # The same command again takes the place of the one that was there, and its group isn't there twice
  K.add_commands!("Notes", [K.Command(:note_file, "File it", :window, "ctrl+cmd+n", (o, win, _) -> (ran[] += 10))])
  @test length(K.COMMANDS) == n + 1 && count(g -> first(g) == "Notes", K.COMMAND_GROUPS) == 1 && K.COMMANDS[:note_file].title == "File it"
  key(Keys.n, Keys.ctrl, Keys.cmd)
  @test ran[] == 11
end

@testset "an item of the Insert menu" begin
  menu = last(K.PAGE_MENU[findfirst(x -> x isa Pair && first(x) == "Insert", K.PAGE_MENU)])
  was = findfirst(x -> x isa Tuple && x[1] == "Note", K.INSERTS)
  was === nothing || (deleteat!(K.INSERTS, was); deleteat!(menu, was))
  n = length(K.INSERTS)
  K.add_insert!("Note", ["```note", "", "```"], (2, 0), before="Map")
  i = findfirst(x -> x isa Tuple && x[1] == "Note", K.INSERTS)
  @test length(K.INSERTS) == n + 1 && K.INSERTS[i+1][1] == "Map" && menu[i] == "Note" && menu[i+1] == "Map" && length(menu) == length(K.INSERTS)
  # Again, it takes the place of the item that was there
  K.add_insert!("Note", ["```note", "to: ", "```"], (2, 4))
  @test length(K.INSERTS) == n + 1 && K.INSERTS[i][2] == ["```note", "to: ", "```"] && length(menu) == length(K.INSERTS)
end

@testset "names for the code of a window's pages" begin
  K.PAGE_NAMES[:notes] = (m, o) -> Core.eval(m, :(const notes_count = $(() -> K.Text("2 notes in all", size=14px))))
  # A window that's made once the name is added has it
  empty!(K.problems)   # what a live block of a test before this one said, when the tests share a process
  other = K.build_editor(joinpath(dir, "page.md"))
  second = Window(other, size=(900px, 600px))
  foreach(_ -> frame(second), 1:3)
  @test isdefined(K.sandbox(other), :notes_count)
  # The page's live block calls it, and shows what it gives
  @test K.problems == String[]
end

@testset "a key that the code takes while a field has the keyboard" begin
  # A field of the code's own has the keyboard, as a field of a form in a live block has
  field = K.own!(e, K.TextInput())
  K.focus(field)
  took = Any[]
  K.FIELD_KEYS[:notes] = (o, win, key) -> win.focus === field && key == Keys.enter && (push!(took, key); true)
  @test w.focus === field
  key(Keys.enter)
  @test took == [Keys.enter] && e.buf.lines == K.text(e.buf.path)   # and the page's text didn't get the key
  # A key that the code doesn't take goes on as ever
  key(Keys.a)
  @test length(took) == 1
  K.focus(e); frames()
end

@testset "a folder whose pages are pages of the settings" begin
  mine = joinpath(dir, "mine")
  mkpath(mine)
  write(joinpath(mine, "notes-settings.md"), "# Notes\n")
  s = K.build_editor(joinpath(mine, "notes-settings.md"))
  s.settings = true
  @test !K.issettings(s)
  K.SETTINGS_FOLDERS[:notes] = mine
  @test K.issettings(s)
  K.open!(s, joinpath(dir, "page.md"))
  @test !K.issettings(s)
  forget()
end
