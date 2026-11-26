# Tests for the key bindings: the commands, the bundles of shortcuts, the key
# bindings page that changes them, and the links between the pages of the settings. See
# "key bindings" in main.jl. Run them with `julia -O0 --project=. test/keys_test.jl`.
# They use windows that aren't on the screen.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
const px = K.px

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
const kept = joinpath(dir, "settings")
K.SETTINGS_FILE[] = kept

"A window that isn't on the screen, on a file with `text` in it"
window(text; name="page.md", size=(900px, 700px)) = begin
  path = joinpath(dir, name)
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=size)
  frame(w); frame(w)
  K.focus(e)
  e, w
end

"Press the key `k` in window `w` with the keys `held` down"
press(w, k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frame(w)
end
caret!(e, w, line, col=0) = (e.buf.caret = e.buf.anchor = (line, col); K.touch!(e); frame(w))
click(w, x, y) = begin
  w.mouse = typeof(w.mouse)(px(x), px(y))
  frame(w)
  w.keys |= Keys.mouse_left
  onkey(w, KeyPress{Keys.mouse_left}(0, w))
  w.keys ⊻= Keys.mouse_left
  frame(w); frame(w)
end
"Click the middle of the part of the window that `node` is drawn in, or a point `dx` from its right edge"
click(w, node; dx=nothing) = (r = rect(node); click(w, K.num(dx === nothing ? r.left + r.width / 2 : r.left + r.width - dx), K.num(r.top + r.height / 2)))
const cmd, ctrl, opt, shift = Keys.cmd, Keys.ctrl, Keys.opt, Keys.shft

@testset "a shortcut reads back from the text that the settings file has for it" begin
  for text in ("cmd+s", "cmd+shift+z", "ctrl+x ctrl+s", "opt+left", "cmd+left, home", "ctrl+cmd+up", "shift+tab", "cmd+0", "cmd+opt+left_bracket")
    @test K.written(K.read_shortcuts(text)) == text
  end
  @test K.caps(only(K.read_shortcuts("cmd+shift+z"))) == "⌘⇧Z"
  @test K.caps(only(K.read_shortcuts("ctrl+x ctrl+s"))) == "⌃X ⌃S"
  @test K.caps(only(K.read_shortcuts("cmd+opt+i"))) == "⌘⌥I"
  @test K.caps(only(K.read_shortcuts("opt+shift+down"))) == "⌥⇧↓"
  @test K.caps(only(K.read_shortcuts("cmd+backslash"))) == "⌘\\"
  @test K.caps(only(K.read_shortcuts("pageup"))) == "Page Up"
  # Text that names no key gives no shortcut
  @test isempty(K.read_shortcuts("cmd+nothing"))
  @test isempty(K.read_shortcuts("hyper+s"))
  @test isempty(K.read_shortcuts(""))
  @test K.read_shortcuts("cmd+s, bad+key, cmd+o") == K.read_shortcuts("cmd+s, cmd+o")
end

@testset "in each bundle, every shortcut runs one command" begin
  @test first.(K.BUNDLES) == ["Ladder", "VS Code", "Sublime Text", "Emacs"]
  for (bundle, theirs) in K.BUNDLES
    of = K.bundle_keys(bundle)
    @test Set(keys(of)) == Set(keys(K.COMMANDS))
    # Each shortcut that the bundle writes can be read, and is for a command that there is: `of` has only those
    for (name, text) in theirs
      @test K.written(of[name]) == text
    end
    all = [(s, name) for (name, list) in of for s in list]
    clash = [(K.caps(a[1]), a[2], b[2]) for (i, a) in enumerate(all) for b in all[i+1:end] if K.clashes(a[1], b[1])]
    @test isempty(clash)
  end
  # The keys that Ladder has always had
  of = K.bundle_keys("Ladder")
  for (name, keys) in (:save => "⌘S", :open => "⌘O", :open_project => "⌘P", :print => "⌘⌥P", :export => "⌘⇧E", :close => "⌘W", :settings => "⌘,", :sidebar => "⌘\\",
                       :undo => "⌘Z", :redo => "⌘⇧Z", :bold => "⌘B", :italic => "⌘I", :find => "⌘F", :run => "⌘Return", :run_step => "⇧Return")
    @test K.caps(first(of[name])) == keys
  end
end

@testset "the keys of the bundle called Ladder do what they always did" begin
  e, w = window("one two three\nfour five six\nseven")
  b = e.buf
  caret!(e, w, 1, 0)
  press(w, Keys.right); press(w, Keys.right)
  @test b.caret == (1, 2) && b.anchor == (1, 2)
  press(w, Keys.right, opt)
  @test b.caret == (1, 3)
  press(w, Keys.right, cmd)
  @test b.caret == (1, 13)
  press(w, Keys.left, cmd, shift)                 # ⇧ grows the selection
  @test b.caret == (1, 0) && b.anchor == (1, 13)
  press(w, Keys.right)                            # with no ⇧, → goes to that end of the selection
  @test b.caret == (1, 13) && b.anchor == (1, 13)
  press(w, Keys.down); press(w, Keys.home)
  @test b.caret == (2, 0)
  press(w, Keys.right, opt, shift)
  @test K.excerpt(b, K.selection(b)...) == "four"
  press(w, Keys.b, cmd)
  @test b.lines[2] == "**four** five six"
  press(w, Keys.z, cmd)
  @test b.lines[2] == "four five six"
  press(w, Keys.z, cmd, shift)
  @test b.lines[2] == "**four** five six"
  press(w, Keys.down, cmd)
  @test b.caret == (3, 5)
  press(w, Keys.backspace, opt)
  @test b.lines[3] == ""
  press(w, Keys.a, cmd)
  @test K.selection(b) == ((1, 0), (3, 0))
  press(w, Keys.up, cmd)
  @test b.caret == (1, 0)
  # ⇧ with ⌫ is still ⌫, and a key with ⇧ that has no command of its own does nothing
  caret!(e, w, 1, 3)
  press(w, Keys.backspace, shift)
  @test b.lines[1] == "on two three"
  before = copy(b.lines)
  press(w, Keys.s, cmd, shift, opt)
  @test b.lines == before && K.dirty(b)
  press(w, Keys.s, cmd)
  @test !K.dirty(b)
  # Return, Tab and ⌘\ still work
  caret!(e, w, 1, 2)
  press(w, Keys.enter)
  @test b.lines[1:2] == ["on", " two three"]
  @test !e.panel
  press(w, Keys.backslash, cmd)
  @test e.panel
  press(w, Keys.backslash, cmd)
  @test !e.panel
end

@testset "⌘[ and ⌘] move the line out and in, wherever the caret is in it" begin
  e, w = window("```python\nfoo()\n  bar()\n```\n\n- a\n  - b\n\nSome words")
  b = e.buf
  tab = K.indentation(e, K.CodeBlock)
  # In code, from the middle of a word, as in the startup page's `  Books.start(Ladder)`
  caret!(e, w, 3, 4)
  press(w, Keys.left_bracket, cmd)
  @test b.lines[3] == "bar()" && b.caret == (3, 2)
  press(w, Keys.left_bracket, cmd)                 # a line with no indent stays
  @test b.lines[3] == "bar()" && b.caret == (3, 2)
  press(w, Keys.right_bracket, cmd)
  @test b.lines[3] == tab * "bar()" && b.caret == (3, 2 + length(tab))
  # Each line of a selection moves, and the fence doesn't
  b.anchor, b.caret = (1, 2), (3, 1); K.touch!(e); frame(w)
  press(w, Keys.right_bracket, cmd)
  @test b.lines[1:3] == ["```python", tab * "foo()", tab * tab * "bar()"]
  press(w, Keys.left_bracket, cmd)
  press(w, Keys.left_bracket, cmd)
  @test b.lines[1:3] == ["```python", "foo()", "bar()"]
  # In a list, the item moves a level
  caret!(e, w, 7, 4)
  press(w, Keys.left_bracket, cmd)
  @test b.lines[7] == "- b" && b.caret == (7, 2)
  press(w, Keys.right_bracket, cmd)
  @test b.lines[7] == "  - b" && b.caret == (7, 4)
  # A paragraph has no steps, and the keys type nothing in it
  caret!(e, w, 9, 4)
  press(w, Keys.right_bracket, cmd)
  press(w, Keys.left_bracket, cmd)
  @test b.lines[9] == "Some words"
end

@testset "a shortcut that two commands have runs the first one that has a use on the page" begin
  # Code from the startup page gives ⌘] a command too, like one that shows the next email
  went = Ref(0)
  K.add_commands!("Tests", [K.Command(:test_next, "Go to the next one", :window, "cmd+right_bracket", (e, w, _) -> (went[] += 1))])
  e, w = window("- a\n  - b\n", name="two.md")
  b = e.buf
  @test K.keys_now(e).also[first(K.read_shortcuts("cmd+right_bracket"))] == [:test_next]
  # On a page that you can change, Ladder's ⌘] has a use, and it moves the line in
  caret!(e, w, 2, 4)
  press(w, Keys.right_bracket, cmd)
  @test b.lines[2] != "  - b" && went[] == 0
  press(w, Keys.left_bracket, cmd)
  @test b.lines[2] == "  - b"
  # On a page that you can't change, like an email or a file that the Mac marks as read-only, Ladder's ⌘] has
  # none, so the other command runs
  path = joinpath(dir, "fixed.md")
  write(path, "- a\n  - b\n")
  chmod(path, 0o444)
  o = K.build_editor(path)
  ow = Window(o, size=(900px, 700px))
  frame(ow); frame(ow)
  K.focus(o)
  @test o.buf.fixed
  press(ow, Keys.right_bracket, cmd)
  @test went[] == 1 && o.buf.lines[2] == "  - b"
  # A key that only one command has goes to it, as it always did, though it has no use here
  ks = K.keys_now(o)
  @test K.command_here(o, ks, first(K.read_shortcuts("cmd+left_bracket"))) == :outdent_line
  @test K.command_here(o, ks, first(K.read_shortcuts("cmd+right_bracket"))) == :test_next
  chmod(path, 0o644)
  delete!(K.COMMANDS, :test_next)
  filter!(g -> first(g) != "Tests", K.COMMAND_GROUPS)
  filter!(p -> last(p).name != :test_next, K.ADDED_COMMANDS)
end

@testset "the commands for whole lines" begin
  e, w = window("a\nb\nc\nd")
  b = e.buf
  caret!(e, w, 2, 1)
  press(w, Keys.right_bracket, cmd, opt)          # the line goes down, and the caret goes with it
  @test b.lines == ["a", "c", "b", "d"] && b.caret == (3, 1)
  press(w, Keys.left_bracket, cmd, opt)
  press(w, Keys.left_bracket, cmd, opt)
  @test b.lines == ["b", "a", "c", "d"] && b.caret == (1, 1)
  press(w, Keys.left_bracket, cmd, opt)           # the first line has nowhere to go
  @test b.lines == ["b", "a", "c", "d"]
  press(w, Keys.d, cmd, shift)
  @test b.lines == ["b", "b", "a", "c", "d"] && b.caret == (2, 1)
  press(w, Keys.k, cmd, shift)
  @test b.lines == ["b", "a", "c", "d"] && b.caret == (2, 1)
  # ⌘⇧L selects the line, and again takes the next line too. The lines that are selected move together.
  caret!(e, w, 2, 0)
  press(w, Keys.l, cmd, shift)
  @test (b.anchor, b.caret) == ((2, 0), (3, 0))
  @test K.touched(b) == (2, 2)
  press(w, Keys.l, cmd, shift)
  @test (b.anchor, b.caret) == ((2, 0), (4, 0))
  press(w, Keys.left_bracket, cmd, opt)
  @test b.lines == ["a", "c", "b", "d"]
  @test K.touched(b) == (1, 2)
  press(w, Keys.k, cmd, shift)
  @test b.lines == ["b", "d"]
  # The last line of the page goes too, and one ⌘Z brings a deleted line back
  caret!(e, w, 2, 1)
  press(w, Keys.k, cmd, shift)
  @test b.lines == ["b"] && b.caret == (1, 1)
  press(w, Keys.z, cmd)
  @test b.lines == ["b", "d"]
  # ⌃K takes away the rest of the line, and at the end of a line it joins the next line to it
  e, w = window("alpha beta\ngamma")
  b = e.buf
  caret!(e, w, 1, 5)
  press(w, Keys.k, ctrl)
  @test b.lines == ["alpha", "gamma"]
  press(w, Keys.k, ctrl)
  @test b.lines == ["alphagamma"]
end

@testset "⌘D selects the word at the caret" begin
  e, w = window("one two_3 three\n  don't stop\n\n+ -")
  b = e.buf
  picked() = K.excerpt(b, K.selection(b)...)
  caret!(e, w, 1, 6)                              # in the middle of a word
  press(w, Keys.d, cmd)
  @test (b.anchor, b.caret) == ((1, 4), (1, 9)) && picked() == "two_3"
  for col in (0, 3)                               # at the start of a word, and at its end
    caret!(e, w, 1, col)
    press(w, Keys.d, cmd)
    @test picked() == "one"
  end
  caret!(e, w, 2, 4)
  press(w, Keys.d, cmd)
  @test picked() == "don't"
  # With part of a word selected, each end goes out to the edge of its word
  b.anchor, b.caret = (1, 5), (2, 3)
  press(w, Keys.d, cmd)
  @test (b.anchor, b.caret) == ((1, 4), (2, 7))
  # With no word at the caret, nothing changes. The text of the last line starts after its "+ ", which doesn't show.
  for at in ((3, 0), (4, 2))
    caret!(e, w, at...)
    press(w, Keys.d, cmd)
    @test b.anchor == b.caret == at
  end
  # Every bundle has it on ⌘D. Emacs has it on ⌥⇧2 as well.
  for (bundle, _) in K.BUNDLES
    e.bundle = bundle
    caret!(e, w, 1, 12)
    press(w, Keys.d, cmd)
    @test picked() == "three" && b.lines[1] == "one two_3 three"
  end
  # ⌘⇧D copies the line now, in the bundles of Ladder and Sublime Text
  @test K.caps.(K.bundle_keys("Ladder")[:duplicate_line]) == K.caps.(K.bundle_keys("Sublime Text")[:duplicate_line]) == ["⌘⇧D"]
  e.bundle = "Emacs"
  caret!(e, w, 1, 1)
  press(w, K.read_shortcuts("opt+shift+2")[1][1].key, opt, shift)
  @test picked() == "one"
end

@testset "⌘D again selects the next place that has the word as well" begin
  e, w = window("cat dog cat\ncatalog cat\n\nCat cat.")
  b = e.buf
  spans() = sort([K.selection(b); [minmax(s...) for s in K.others(b)]])
  caret!(e, w, 1, 1)
  press(w, Keys.d, cmd)
  @test spans() == [((1, 0), (1, 3))]
  press(w, Keys.d, cmd)                           # the next one is selected too, and the caret goes to it
  @test spans() == [((1, 0), (1, 3)), ((1, 8), (1, 11))] && b.caret == (1, 11)
  press(w, Keys.d, cmd)                           # "catalog" has the letters, and isn't the word
  @test b.caret == (2, 11)
  press(w, Keys.d, cmd)                           # nor is "Cat"
  @test b.caret == (4, 7)
  all4 = [((1, 0), (1, 3)), ((1, 8), (1, 11)), ((2, 8), (2, 11)), ((4, 4), (4, 7))]
  @test spans() == all4
  press(w, Keys.d, cmd)                           # every place is selected, so nothing changes
  @test spans() == all4
  # What's typed goes in at each of them
  ontype(w, Typed('o', w)); ontype(w, Typed('x', w)); frame(w)
  @test b.lines == ["ox dog ox", "catalog ox", "", "Cat ox."]
  @test spans() == [((1, 2), (1, 2)), ((1, 9), (1, 9)), ((2, 10), (2, 10)), ((4, 6), (4, 6))]
  # ⌫ and the keys that go along the line work at each of them too
  press(w, Keys.backspace)
  @test b.lines == ["o dog o", "catalog o", "", "Cat o."]
  press(w, Keys.left)
  ontype(w, Typed('b', w)); frame(w)
  @test b.lines == ["bo dog bo", "catalog bo", "", "Cat bo."]
  press(w, Keys.right, shift)
  @test spans() == [((1, 1), (1, 2)), ((1, 8), (1, 9)), ((2, 9), (2, 10)), ((4, 5), (4, 6))]
  # One ⌘Z takes back what was done at all of them, and they're all still selected
  press(w, Keys.backspace)
  @test b.lines == ["b dog b", "catalog b", "", "Cat b."]
  press(w, Keys.z, cmd)
  @test b.lines == ["bo dog bo", "catalog bo", "", "Cat bo."] && length(K.others(b)) == 3
  # Escape leaves the selection that was there first, and the caret still shows
  press(w, Keys.escape)
  @test isempty(K.others(b)) && !b.reading
  @test (b.anchor, b.caret) == ((1, 1), (1, 2))
  ontype(w, Typed('!', w)); frame(w)
  @test b.lines == ["b! dog bo", "catalog bo", "", "Cat bo."]
  # That's so with the words still selected, too
  e, w = window("cat dog cat\ncat")
  b = e.buf
  caret!(e, w, 1, 9)
  press(w, Keys.d, cmd); press(w, Keys.d, cmd); press(w, Keys.d, cmd)
  @test b.caret == (1, 3) && length(K.others(b)) == 2
  press(w, Keys.escape)
  @test isempty(K.others(b)) && (b.anchor, b.caret) == ((1, 8), (1, 11))
  # A key that isn't done at each of them leaves the one caret
  e, w = window("a b a\nb")
  b = e.buf
  caret!(e, w, 1, 0)
  press(w, Keys.d, cmd); press(w, Keys.d, cmd)
  @test length(K.others(b)) == 1
  press(w, Keys.down)
  @test isempty(K.others(b))
  # Return starts a new line at each of them, and the ones after it move down
  caret!(e, w, 1, 0)
  press(w, Keys.d, cmd); press(w, Keys.d, cmd)
  press(w, Keys.right)
  press(w, Keys.enter)
  @test b.lines == ["a", " b a", "", "b"]
  @test spans() == [((2, 0), (2, 0)), ((3, 0), (3, 0))]
  # Text that isn't one word is found wherever it is, and the search goes round to the top of the page
  e, w = window("x a+b\na+b a+b.")
  b = e.buf
  b.anchor, b.caret = (2, 4), (2, 7)
  press(w, Keys.d, cmd)
  @test spans() == [((1, 2), (1, 5)), ((2, 4), (2, 7))] && b.caret == (1, 5)
  press(w, Keys.d, cmd)
  @test spans() == [((1, 2), (1, 5)), ((2, 0), (2, 3)), ((2, 4), (2, 7))]
  # ⌘B makes each of them bold
  press(w, Keys.b, cmd)
  @test b.lines == ["x **a+b**", "**a+b** **a+b**."]
end

@testset "⌘/ makes a comment of a line of code, and code of it again" begin
  e, w = window("f(x) = begin\n  a = 1\n\n    b = 2\nend\n", name="code.jl")
  b = e.buf
  @test b.view == :code
  caret!(e, w, 2, 4)
  press(w, Keys.slash, cmd)
  @test b.lines[2] == "  # a = 1" && b.caret == (2, 6)
  press(w, Keys.slash, cmd)
  @test b.lines[2] == "  a = 1" && b.caret == (2, 4)
  # Each line that's selected gets its mark at the indent of the one that's furthest out. An empty line stays empty.
  b.anchor, b.caret = (2, 0), (4, 3)
  press(w, Keys.slash, cmd)
  @test b.lines[2:4] == ["  # a = 1", "", "  #   b = 2"]
  press(w, Keys.z, cmd)                           # one ⌘Z puts every line back
  @test b.lines[2:4] == ["  a = 1", "", "    b = 2"]
  # A mark with no space after it comes off too
  b.lines[2] = "  #a = 1"
  b.version += 1
  caret!(e, w, 2, 0)
  press(w, Keys.slash, cmd)
  @test b.lines[2] == "  a = 1"
  # On a page, code has comments and text has none
  e, w = window("Some text\n\n```julia\nx = 1\n```\n\n```js\nlet y = 2\n```\n")
  b = e.buf
  caret!(e, w, 4, 0)
  press(w, Keys.slash, cmd)
  @test b.lines[4] == "# x = 1"
  caret!(e, w, 8, 0)
  press(w, Keys.slash, cmd)
  @test b.lines[8] == "// let y = 2"
  caret!(e, w, 1, 0)
  press(w, Keys.slash, cmd)
  @test b.lines[1] == "Some text"
end

@testset "the VS Code bundle" begin
  e, w = window("a\nb\nc")
  b = e.buf
  K.bundle!(e, "VS Code")
  @test e.bundle == "VS Code"
  caret!(e, w, 1, 0)
  press(w, Keys.down, opt)
  @test b.lines == ["b", "a", "c"] && b.caret == (2, 0)
  press(w, Keys.up, opt)
  @test b.lines == ["a", "b", "c"]
  press(w, Keys.down, opt, shift)                 # this has a command of its own, so it selects nothing
  @test b.lines == ["a", "a", "b", "c"] && b.caret == b.anchor
  press(w, Keys.p, cmd)                           # ⌘P finds a project, as in every bundle
  @test e.popup == :projects
  press(w, Keys.escape)
  @test e.popup == :none
  @test_throws ErrorException K.bundle!(e, "Notepad")
  # The keys of the bundle called Ladder for a line don't move one here
  K.bundle!(e, "VS Code")
  caret!(e, w, 1, 0)
  press(w, Keys.right_bracket, cmd, opt)
  @test b.lines == ["a", "a", "b", "c"]
end

@testset "a shortcut of two keys, in the Sublime Text bundle" begin
  e, w = window("word")
  b = e.buf
  K.bundle!(e, "Sublime Text")
  caret!(e, w, 1, 4)
  @test !e.panel
  press(w, Keys.k, cmd)                           # the first key only waits
  @test !e.panel && b.lines == ["word"]
  press(w, Keys.b, cmd)
  @test e.panel && b.lines == ["word"]            # ⌘B after ⌘K isn't bold
  K.focus(e)
  b.anchor, b.caret = (1, 0), (1, 4)
  press(w, Keys.b, cmd)                           # by itself it still is
  @test b.lines == ["**word**"]
  # A second key that ends no shortcut does nothing, and types nothing
  press(w, Keys.z, cmd)
  @test b.lines == ["word"]
  caret!(e, w, 1, 4)
  press(w, Keys.k, cmd)
  press(w, Keys.x)
  @test b.lines == ["word"]
  press(w, Keys.x)                                # the key after that types as usual
  @test b.lines == ["wordx"]
  press(w, Keys.k, cmd); press(w, Keys.k, cmd)    # ⌘K ⌘K deletes to the end of the line
  caret!(e, w, 1, 2)
  press(w, Keys.k, cmd); press(w, Keys.k, cmd)
  @test b.lines == ["wo"]
end

@testset "the Emacs bundle" begin
  e, w = window("one two\nthree")
  b = e.buf
  K.bundle!(e, "Emacs")
  caret!(e, w, 1, 0)
  press(w, Keys.f, ctrl)
  @test b.caret == (1, 1)
  press(w, Keys.f, opt)                           # ⌥F goes to the end of the word, and types no letter
  @test b.caret == (1, 3) && b.lines[1] == "one two"
  press(w, Keys.e, ctrl)
  @test b.caret == (1, 7)
  press(w, Keys.a, ctrl, shift)                   # ⇧ grows the selection with these keys too
  @test (b.anchor, b.caret) == ((1, 7), (1, 0))
  press(w, Keys.n, ctrl)
  @test b.caret[1] == 2
  press(w, Keys.p, ctrl)
  @test b.caret[1] == 1
  caret!(e, w, 1, 0)
  press(w, Keys.d, ctrl)
  @test b.lines[1] == "ne two"
  press(w, Keys.x, ctrl); press(w, Keys.u)        # ⌃X then U undoes, and the U isn't typed
  @test b.lines[1] == "one two"
  press(w, Keys.z, cmd, shift)                    # the Mac's keys still work
  @test b.lines[1] == "ne two"
  @test K.dirty(b)
  press(w, Keys.x, ctrl); press(w, Keys.s, ctrl)
  @test !K.dirty(b)
  press(w, Keys.s, ctrl)                          # ⌃S by itself finds: on a page, with the search in the top bar
  frame(w); frame(w)
  searching() = any(p -> p.key == K.TS_KEY, K.popups(w))
  @test searching()
  press(w, Keys.escape)
  @test !searching()
  # A letter with no key held still types
  K.focus(e)
  caret!(e, w, 1, 0)
  press(w, Keys.f)
  @test b.lines[1] == "fne two"
end

@testset "while the page is read, the keys that move the caret scroll the page" begin
  e, w = window(join(["line $i" for i in 1:200], "\n\n"))
  b = e.buf
  press(w, Keys.escape)
  @test b.reading
  press(w, Keys.down)
  @test e.scroll.offset == 50px
  press(w, Keys.down, cmd)
  @test e.scroll.offset > 1000px
  press(w, Keys.home)
  @test e.scroll.offset == 0px
  press(w, Keys.backspace); press(w, Keys.tab); press(w, Keys.enter)
  @test b.reading && !K.dirty(b)
  # With the Emacs bundle, its keys scroll the page too
  K.bundle!(e, "Emacs")
  press(w, Keys.n, ctrl)
  @test e.scroll.offset == 50px
  press(w, Keys.period, opt, shift)
  @test e.scroll.offset > 1000px
end

@testset "the key bindings page changes the keys of a command" begin
  empty!(K.problems)
  e = K.build_editor(K.settings_page("key-bindings.md"))
  w = Window(e, size=(720px, 2600px))
  frame(w); frame(w); frame(w)
  @test isempty(K.problems)
  row(name) = e.nodes[(:key_row, name)]
  keys(name) = K.caps.(K.keys_now(e).of[name])
  text = copy(e.buf.lines)
  # A click on a command's row waits for its new keys, and the next key with the keys held with it is the command's shortcut
  click(w, row(:save))
  @test K.key_asking(e) == :save && w.focus === row(:save)
  press(w, Keys.s, ctrl)
  @test keys(:save) == ["⌃S"]
  @test K.key_asking(e) === nothing && w.focus === e
  @test e.rebound == Dict(:save => "ctrl+s")
  # A letter by itself types, so it can't be a shortcut. The row goes on waiting, and esc leaves the keys as they were.
  click(w, row(:save))
  press(w, Keys.a)
  @test K.key_asking(e) == :save && keys(:save) == ["⌃S"]
  @test occursin("types a character", e.nodes[:key_refused])
  press(w, Keys.escape)
  @test K.key_asking(e) === nothing && keys(:save) == ["⌃S"]
  # The keys of another command go to this one, and a line under the row says so
  click(w, row(:save))
  press(w, Keys.o, cmd)
  @test keys(:save) == ["⌘O"] && isempty(keys(:open))
  @test e.nodes[:key_note][1] == :save && occursin("Find a file by name", e.nodes[:key_note][2])
  # A key with ⌥ would type a character. The page's own text never gets it.
  click(w, row(:print))
  press(w, Keys.p, opt)
  @test keys(:print) == ["⌥P"]
  @test e.buf.lines == text
  # "Put back" gives a command the bundle's keys again, and takes them from the command that has them now
  click(w, e.nodes[(:key_reset, :open)])
  @test keys(:open) == ["⌘O"] && isempty(keys(:save))
  click(w, e.nodes[(:key_reset, :save)])
  @test keys(:save) == ["⌘S"]
  @test e.rebound == Dict(:print => "opt+p")
  # A shortcut of one key takes the keys of a shortcut of two that starts with it
  K.bundle!(e, "Emacs")
  @test isempty(e.rebound)
  K.rebind!(e, :bold, (K.read_stroke("ctrl+x"),))
  @test keys(:save) == ["⌘S"] && keys(:undo) == ["⌃/", "⌘Z"] && keys(:bold) == ["⌃X"]
  # Choosing a bundle gives every command the bundle's keys
  K.bundle!(e, "Ladder")
  @test isempty(e.rebound) && keys(:bold) == ["⌘B"]
  close(w)
end

@testset "every window has the same keys, and Ladder keeps them" begin
  rm(kept, force=true)
  a = K.build_editor(joinpath(dir, "page.md"))
  b = K.build_editor(joinpath(dir, "code.jl"))
  a.remember = true
  wa, wb = K.window!(a, size=(900px, 700px)), K.window!(b, size=(900px, 700px))
  frame(wa); frame(wb)
  K.bundle!(a, "Sublime Text")
  K.rebind!(a, :save, (K.read_stroke("ctrl+s"),))
  K.rebind!(a, :italic, (K.read_stroke("cmd+p"),))   # this takes the shortcut that finds a project
  @test b.bundle == "Sublime Text" && b.rebound == a.rebound
  @test K.command_of(b, wb, Keys.k) === nothing
  wb.keys |= ctrl
  @test K.command_of(b, wb, Keys.s) == :save
  wb.keys ⊻= ctrl
  @test occursin("keys=Sublime Text\n", read(kept, String))
  @test occursin("key.save=ctrl+s\n", read(kept, String))
  @test occursin("key.open_project=\n", read(kept, String))
  # The next window that opens has them
  c = K.build_editor(joinpath(dir, "page.md"))
  K.load_settings!(c)
  @test c.bundle == "Sublime Text" && c.rebound == a.rebound
  @test K.caps.(K.keys_now(c).of[:italic]) == ["⌘P"]
  # A line of the file that names no command or no key is left out
  write(kept, "keys=Wordstar\nkey.nothing=cmd+s\nkey.save=hyper+s\nkey.bold=cmd+y\n")
  d = K.build_editor(joinpath(dir, "page.md"))
  K.load_settings!(d)
  @test d.bundle == "Ladder" && d.rebound == Dict(:save => "", :bold => "cmd+y")
  close(wa); close(wb)
  @test isempty(K.editors)
  rm(kept, force=true)
end

@testset "the main page of the settings has a link to each of the other pages" begin
  e = K.build_editor(joinpath(dir, "page.md"))
  w = K.window!(e, size=(1100px, 800px))
  frame(w)
  press(w, Keys.comma, cmd)
  s = K.settings_editor()
  sw = K.window_of(s)
  frame(sw); frame(sw)
  @test s.buf.path == K.settings_page("settings.md")
  # The top bar has the file's name, as any window's does, and no tabs
  @test s.nodes[:title] isa K.Title && !any(key -> key isa Tuple && first(key) == :settings_tab, keys(s.nodes))
  # Each other page of the settings' folder has a link on the main page, and a link back to it
  others = filter(name -> endswith(name, ".md") && name != "settings.md", readdir(K.settings_dir()))
  # The startup page is there once Ladder has started, since Ladder writes it then
  @test sort(filter(!=("startup.md"), others)) == ["code-editor.md", "key-bindings.md"]
  for name in others
    @test any(line -> occursin("]($name)", line), s.buf.lines)
    @test occursin("](settings.md)", read(K.settings_page(name), String))
  end
  # A click with ⌘ held on a link shows its page, in the same window
  link(name) = begin
    frame(sw); frame(sw)
    line = findfirst(l -> occursin("]($name)", l), s.buf.lines)
    it = K.item(s, line)
    (K.num(s.origin[1] + 40px), K.num(s.origin[2] + it.top + it.tall / 2))
  end
  @test !any(line -> occursin("code_wrap", line), s.buf.lines)
  @test K.link_at(s, px.(link("code-editor.md"))) == "code-editor.md"
  sw.keys |= cmd
  click(sw, link("code-editor.md")...)
  sw.keys ⊻= cmd
  @test s.buf.path == K.settings_page("code-editor.md")
  @test any(line -> occursin("code_wrap", line), s.buf.lines)
  @test K.issettings(s) && K.settings_editor() === s
  # The link at the top of that page goes back to the main page, and so does ⌘⌥←
  K.follow!(s, "settings.md")
  @test s.buf.path == K.settings_page("settings.md")
  @test K.go_back!(s) && s.buf.path == K.settings_page("code-editor.md")
  K.follow!(s, "settings.md"); K.follow!(s, "key-bindings.md")
  @test s.buf.path == K.settings_page("key-bindings.md")
  @test K.issettings(s)
  # A choice on that page changes the keys of the other window
  K.bundle!(s, "Emacs")
  @test e.bundle == "Emacs"
  K.bundle!(s, "Ladder")
  # ⌘, closes the settings window from any of its pages
  press(sw, Keys.comma, cmd)
  @test K.settings_editor() === nothing
  @test K.editors == [e]
  close(w)
  @test isempty(K.editors)
end
