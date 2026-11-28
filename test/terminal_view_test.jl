# Tests for a terminal's file, which shows as a terminal: see "a terminal's
# file" in main.jl, and term/view.jl. Run them with
# `julia -O0 --project=. test/terminal_view_test.jl`. They write .vt files into
# a temporary folder and show them in a window that isn't on the screen. The
# shell is the Mac's /bin/sh, which reads none of your settings. Set
# `LADDER_SHOTS` to a folder, and they save pictures of the window there.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Typed Keys onkey onmouse onscroll ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect clipboard clipboard!
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive
const px = K.px
const Terms = K.Terms
const Screens = Terms.Screens

Terms.USUAL[] = ["/bin/sh"]
# Your shell's settings can name a file for its history, and /bin/sh would add what these tests type to it
ENV["HISTFILE"] = joinpath(mktempdir(), "history")
# What programs say of how to start them again is kept here, and not with your own Ladder's files
Terms.Resumes.STORE[] = joinpath(realpath(mktempdir()), "resume")

const dir = realpath(mktempdir())
const fresh = joinpath(dir, "fresh.vt")
const kept = joinpath(dir, "kept.vt")
const notes = joinpath(dir, "notes.md")
write(fresh, "")
write(kept, "\e[1;31mred\e[0m and plain\r\nthe last line of the file")
write(notes, "# Notes\n\nSome words.\n\n```view\nkept.vt\n```\n")

const e = K.build_editor(fresh)
const w = Window(e, size=(900px, 560px))
const (; frames, at, press, release, click, typed, key, shot) = drive(w, frames=3, pressed=1)
frames()

"The terminal of the file at `path`, and the text that it shows"
view(path=e.buf.path) = e.nodes[(:term, path)]
words(path=e.buf.path) = Screens.words(view(path).term)
"Draw frames until `done()` is true, for no more than `seconds`. The shell's output comes on another thread."
until(done; seconds=10) = (t = time(); while !done() && time() - t < seconds; sleep(0.02); frames(1); end; frames(1); done())
"Type a line into the shell and wait until the terminal shows `expect`"
run(line, expect) = (typed(line); key(Keys.enter); until(() -> occursin(expect, words())))
"The middle of the cell in line `row` and cell `col` of the terminal that shows, in the window"
cell(row, col) = begin
  v = view()
  r = rect(v)
  cw, ch, _ = Terms.cell(v)
  (K.num(r.left) + Terms.PAD + (col - 0.5) * cw, K.num(r.top) + Terms.PAD + (row - 0.5) * ch)
end

@testset "a file with nothing in it opens as a terminal with a shell" begin
  v = view()
  @test e.buf.view == :file && K.term_shown(e)
  @test Terms.running(v) && w.focus === v
  @test Terms.hint(v) === nothing
  ok = until(() -> occursin("\$", words()))
  @test ok
  # The terminal covers the page's whole space, and its shell knows how many lines and cells fit
  r, (wide, high) = rect(v), K.page_room(e)
  @test r.width == wide && r.height == high
  t = v.term
  ok = run("stty size", "$(t.rows) $(t.cols)")
  @test ok
  # The shell is in the folder that the file is in
  ok = run("pwd", dir)
  @test ok
  # It has four levels, and shows at the highest. The bar has no lock: the terminal is yours to type in.
  @test K.levels(e) == (K.FILE_LEVELS..., "the terminal that the file keeps") && K.level(e) == 4
  @test K.file_icon(fresh) == "terminal" && "terminal" in K.FILE_ICONS
  shot("terminal.png")
end

"The text that the window draws under `node`, each piece in the font it's drawn in"
texts(node=rect(e), out=[]) = (node isa K.ConcreteText ? push!(out, node) : foreach(n -> texts(n, out), node.children); out)

@testset "the top bar shows the program's title, each character in a font that has it" begin
  # Claude Code starts its title with ✳, which the system font lacks. Zapf Dingbats has it.
  ok = run("printf '\\033]0;\\342\\234\\263 Claude Code\\007'; echo titled", "\ntitled")
  @test ok
  ok = until(() -> e.buf.about == "✳ Claude Code")
  @test ok
  star = [t for t in texts() if t.from.content == "✳"]
  @test length(star) == 1
  f = only(star).from
  @test f.family != K.SANS && K.has(K.Face(f.family, f.subfamily, f.size, f.color, false), '✳')
  @test any(t -> t.from.content == " Claude Code" && t.from.family == K.SANS, texts())
  shot("terminal-title.png")
end

@testset "the keys are the shell's" begin
  v = view()
  # Colours come as the program asks for them
  ok = run("printf '\\033[31mcrimson\\033[0m\\n'", "\ncrimson")
  @test ok
  t = v.term
  k = findlast(l -> startswith(Screens.words(t, l), "crimson"), Screens.everything(t))
  @test Screens.everything(t)[k].cells[1].fg == Screens.numbered(1)
  # The arrows and Control with a letter send what a terminal sends
  typed("cat -v")
  key(Keys.enter)
  key(Keys.up)
  key(Keys.left, Keys.opt)
  key(Keys.escape)   # Esc is the shell's too: the terminal keeps the keyboard
  ok = until(() -> occursin("^[[A^[b^[", words()))
  @test ok
  @test w.focus === v
  key(Keys.c, Keys.ctrl)
  ok = run("echo back-\$((1+1))", "back-2")
  @test ok
  # ⌘V pastes, and ⌘C copies what's selected
  clipboard!(w, "echo pasted-\$((2+2))")
  key(Keys.v, Keys.cmd)
  key(Keys.enter)
  ok = until(() -> occursin("pasted-4", words()))
  @test ok
  row = findlast(l -> startswith(Screens.words(t, l), "pasted-4"), t.lines)
  click(cell(row, 2))
  v.clicked = (time(), v.clicked[2:4]...)   # a slow frame mustn't part the two clicks
  click(cell(row, 2))   # two clicks select the word
  @test Terms.selected(v) == "pasted-4"
  shot("terminal-selected.png")
  key(Keys.c, Keys.cmd)
  @test clipboard(w) == "pasted-4"
  # A drag selects by cells
  press(cell(row, 1))
  at(cell(row, 6))
  at(cell(row, 7) .- (Terms.cell(v)[1] / 2 - 1, 0))
  release()
  @test Terms.selected(v) == "pasted"
  # Typing takes the selection away
  typed("x")
  @test Terms.selected(v) == ""
  key(Keys.backspace)
end

@testset "the wheel goes back through the lines that scrolled away" begin
  v = view()
  ok = run("seq 1 200", "\n200\n")
  @test ok
  t = v.term
  @test length(t.past) > 150
  @test v.back == 0
  onscroll(w, Vec2{px}(0px, 6px), true)
  frames(1)
  @test v.back > 0
  was = v.back
  shot("terminal-back.png")
  # New lines don't move a view that's back in the past
  first_shown() = Screens.words(t, Screens.line(t, length(t.past) - v.back + 1))
  top = first_shown()
  typed("echo more")
  @test v.back == 0   # but typing shows the newest lines again
  key(Keys.enter)
  until(() -> occursin("\nmore\n", words()))
  onscroll(w, Vec2{px}(0px, 6px), true)
  frames(1)
  top = first_shown()
  Terms.Ptys.send!(v.shell, "echo again\r")
  ok = until(() -> occursin("\nagain\n", words()))
  @test ok
  @test first_shown() == top && v.back > was
  # ⇧PageDown and ⇧End come back
  key(Keys._end, Keys.shft)
  @test v.back == 0
  key(Keys.pageup, Keys.shft)
  @test v.back == t.rows - 1
  # A lot of output is read a part in each frame, and all of it comes. The past keeps its last lines.
  ok = run("seq 1 40000", "\n40000\n")
  @test ok
  @test length(t.past) == t.most && t.gone > 20000
  @test isempty(v.unread)
  # ⌘K forgets the lines above the cursor's
  key(Keys.k, Keys.cmd)
  @test isempty(t.past) && t.row == 1 && v.back == 0
end

@testset "a program on the second screen has the mouse and the keys" begin
  v = view()
  t = v.term
  # A program that draws on the second screen and asks for the mouse, as vim does
  ok = run("printf '\\033[?1049h\\033[?1000h\\033[?1006h\\033[Hsecond'; cat -v", "second")
  @test ok
  @test t.second && t.tracks == :press
  click(cell(3, 5))
  ok = until(() -> occursin("^[[<0;5;3M^[[<0;5;3m", replace(words(), "\n" => "")))
  @test ok
  @test Terms.selected(v) == ""   # the click selected nothing
  key(Keys.c, Keys.ctrl)
  ok = run("printf '\\033[?1000l\\033[?1049l'; echo first-\$((3+3))", "first-6")
  @test ok
  @test !t.second && t.tracks == :none
end

@testset "the settings: the caret, copying what's selected, ⌥ as Meta, the bell and the lines kept" begin
  v = view()
  t = v.term
  s = K.TERM_SETTINGS
  was = [getfield(s, f) for f in fieldnames(K.TermSettings)]
  sounds = Ref(0)
  Terms.ALERT[] = () -> (sounds[] += 1; nothing)
  # The Terminal page of the settings calls these. Each changes every terminal.
  page = K.sandbox(e)
  page.term_caret!("Bar")
  page.term_blink!(true)
  page.term_copies!(true)
  page.term_meta!(true)
  frames(1)
  @test (v.caret, v.blink, v.copies, v.meta) == (:bar, true, true, true)
  @test page.term_caret() == "bar" && page.term_blink() && page.term_lines() == 10_000
  @test_throws ErrorException page.term_caret!("triangle")
  @test_throws ErrorException page.term_lines!(7)
  # A program's own caret shows until it asks for the terminal's again
  @test Terms.caret_look(v, t) == (:bar, true)
  ok = run("printf '\\033[2 q'; echo shaped", "\nshaped")
  @test ok
  @test Terms.caret_look(v, t) == (:block, false)
  ok = run("printf '\\033[0 q'; echo unshaped", "\nunshaped")
  @test ok
  @test Terms.caret_look(v, t) == (:bar, true)
  shot("terminal-bar-caret.png")
  # A caret that blinks is lit just after a key, dark half a second later, and lit again after that
  @test Terms.lit(v, v.stirred + 0.2) && !Terms.lit(v, v.stirred + 0.75) && Terms.lit(v, v.stirred + 1.25)
  # What the mouse selects is copied as the button goes up. A click that selects nothing copies nothing.
  ok = run("echo copy-me", "\ncopy-me")
  @test ok
  clipboard!(w, "before")
  row = findlast(l -> startswith(Screens.words(t, l), "copy-me"), t.lines)
  click(cell(row, 2))
  @test clipboard(w) == "before"
  v.clicked = (time(), v.clicked[2:4]...)   # a slow frame mustn't part the two clicks
  click(cell(row, 2))
  @test clipboard(w) == "copy-me"
  # ⌥ as a Meta key sends ESC and the key, with ⇧ too, and the Mac's character doesn't come
  typed("cat -v")
  key(Keys.enter)
  meta(k, char, held=Keys(0)) = begin
    w.keys |= Keys.opt | held
    onkey(w, KeyPress{k}(0, w))
    ontype(w, Typed(char, w))
    onkey(w, KeyRelease{k}(0, w))
    w.keys = Keys(0)
    frames(1)
  end
  meta(Keys.b, '∫')
  meta(Keys.f, 'Ï', Keys.shft)
  meta(Keys.period, '≥')
  key(Keys.enter)
  ok = until(() -> occursin("^[b^[F^[.", words()))
  @test ok
  @test !occursin("∫", words()) && !occursin("M-", words())
  # With the setting off, ⌥ types the Mac's character
  page.term_meta!(false)
  frames(1)
  meta(Keys.b, '∫')
  key(Keys.enter)
  ok = until(() -> occursin("M-bM-^HM-+", words()))
  @test ok
  key(Keys.c, Keys.ctrl)
  # The bell plays the Mac's alert sound, or flashes the terminal, or does nothing
  page.term_bell!("sound")
  frames(1)
  ok = run("printf '\\a'; echo rang", "\nrang")
  @test ok
  @test sounds[] == 1
  page.term_bell!("flash")
  frames(1)
  sleep(0.15)   # bells that come within a tenth of a second are one
  before = v.rung
  ok = run("printf '\\a'; echo rang-again", "\nrang-again")
  @test ok
  @test sounds[] == 1
  @test v.rung > before
  page.term_bell!("none")
  frames(1)
  before = v.rung
  ok = run("printf '\\a'; echo quiet", "\nquiet")
  @test ok
  @test sounds[] == 1 && v.rung == before && v.rang == t.bells
  # Fewer lines to keep forgets the oldest at once
  ok = run("seq 1 3000", "\n3000\n")
  @test ok
  @test length(t.past) > 1000
  page.term_lines!(1000)
  frames(1)
  @test t.most == 1000 && length(t.past) == 1000
  # The file of the settings keeps them, and a value that a setting can't be changes nothing
  text = K.term_settings_text()
  @test occursin("term.caret=bar\n", text) && occursin("term.copies=true\n", text) && occursin("term.most=1000\n", text)
  K.read_term_setting!("caret", "underline")
  K.read_term_setting!("bell", "siren")
  K.read_term_setting!("most", "7")
  @test (s.caret, s.bell, s.most) == (:underline, :none, 1000)
  foreach((f, x) -> setfield!(s, f, x), fieldnames(K.TermSettings), was)
  Terms.ALERT[] = () -> nothing
  frames(1)
end

@testset "⌘E shows the file's text, and the shell runs on" begin
  v = view()
  key(Keys.e, Keys.cmd)
  @test e.buf.view == :text && !K.term_shown(e)
  @test w.focus !== v              # the keys aren't the hidden terminal's
  @test Terms.running(v)
  @test !isempty(e.buf.lines)      # what the shell wrote is in the file by now, or will be: the file has its first lines
  key(Keys.e, Keys.cmd)
  @test K.term_shown(e) && view() === v
  frames()
  @test w.focus === v
  # What floats over the page has the keys while it shows
  key(Keys.p, Keys.cmd | Keys.shft)
  @test e.popup == :commands && w.focus !== v
  key(Keys.escape)
  frames()
  @test e.popup == :none && w.focus === v
end

@testset "the shell runs on while the window shows another file" begin
  v = view()
  Terms.Ptys.send!(v.shell, "sleep 0.3; echo late-\$((5+5))\r")
  K.open!(e, notes)
  frames()
  @test e.buf.path == notes && w.focus !== v && Terms.running(v)
  ok = until(() -> occursin("late-10", Screens.words(v.term)))
  @test ok
  # A view block shows a terminal's file as its last lines, and starts nothing
  shown = [n for n in values(e.nodes) if n isa K.ViewBlock]
  @test length(shown) == 1
  crumb = shown[1].crumb
  @test crumb !== nothing && crumb.viewer isa Terms.TerminalView
  @test crumb.viewer.shown && !Terms.running(crumb.viewer)
  @test occursin("the last line of the file", Screens.words(crumb.viewer.term))
  shot("terminal-view-block.png")
  K.open!(e, fresh)
  frames()
  @test view() === v && w.focus === v
end

@testset "what the shell wrote is in the file" begin
  v = view()
  ok = run("echo keep-\$((6+6))", "keep-12")
  @test ok
  ok = until(() -> !v.dirty, seconds=6)
  @test ok
  text = read(fresh, String)
  @test occursin("keep-12", text) && occursin("\r\n", text)
  # A shell that ends says so, and Return starts another
  typed("exit 3")
  key(Keys.enter)
  ok = until(() -> !Terms.running(v))
  @test ok
  @test v.status == 3 && occursin("ended with status 3", Terms.hint(v))
  shot("terminal-ended.png")
  key(Keys.enter)
  @test Terms.running(v)
  ok = run("echo anew", "\nanew")
  @test ok
end

@testset "a file with text shows it, and starts a shell at Return" begin
  K.open!(e, kept)
  frames()
  v = view()
  @test K.term_shown(e) && w.focus === v
  @test !Terms.running(v)
  @test words() == "red and plain\nthe last line of the file"
  @test v.term.past == [] && v.term.lines[1].cells[1].flags & Screens.BOLD != 0
  @test occursin("Press Return to start a shell in", Terms.hint(v))
  shot("terminal-kept.png")
  # Keys do nothing to it, and the file is as it was
  typed("ls")
  key(Keys.up)
  @test words() == "red and plain\nthe last line of the file"
  @test read(kept, String) == "\e[1;31mred\e[0m and plain\r\nthe last line of the file"
  key(Keys.enter)
  @test Terms.running(v) && Terms.hint(v) === nothing
  ok = run("echo more-\$((7+7))", "more-14")
  @test ok
  @test startswith(words(), "red and plain\nthe last line of the file\n")
end

@testset "New Terminal makes a terminal in a folder" begin
  K.new_terminal!(e, dir)
  frames()
  made = joinpath(dir, "Terminal.vt")
  @test isfile(made) && e.buf.path == made && K.term_shown(e)
  @test Terms.running(view(made))
  @test "New Terminal" in K.file_menu(dir) && "New Terminal" in K.FOLDER_MENU
  K.new_terminal!(e, dir)
  frames()
  @test e.buf.path == joinpath(dir, "Terminal 2.vt")
end

@testset "⌘⇧T makes a terminal in the folder of the file that shows" begin
  # From a terminal, which has the keyboard
  @test w.focus === view()
  key(Keys.t, Keys.cmd | Keys.shft)
  frames()
  @test e.buf.path == joinpath(dir, "Terminal 3.vt") && K.term_shown(e) && e.popup == :none
  @test Terms.running(view())
  # From a page
  K.open!(e, notes)
  frames()
  key(Keys.t, Keys.cmd | Keys.shft)
  frames()
  @test e.buf.path == joinpath(dir, "Terminal 4.vt") && K.term_shown(e) && e.popup == :none
  @test Terms.running(view())
  @test K.COMMANDS[:new_terminal].keys == "cmd+shift+t"
end

@testset "a terminal whose file goes ends, and a window that closes ends them all" begin
  v2 = view(joinpath(dir, "Terminal 2.vt"))
  v1 = view(joinpath(dir, "Terminal.vt"))
  @test Terms.running(v1) && Terms.running(v2)
  K.open!(e, notes)
  rm(joinpath(dir, "Terminal.vt"))
  frames()
  @test !Terms.running(v1) && !(v1 in K.terminals(e))
  @test !isfile(joinpath(dir, "Terminal.vt"))   # and nothing wrote the file again
  @test Terms.running(v2)
  v = view(kept)
  shells = [x.shell for x in K.terminals(e) if Terms.running(x)]
  @test length(shells) >= 2
  K.onclose(e, w)
  @test !Terms.running(v) && !Terms.running(v2)
  ok = until(() -> !any(Terms.Ptys.alive, shells))
  @test ok
  @test occursin("more-14", read(kept, String))
end

@testset "a program that said how to start again does so when Ladder opens again" begin
  R = Terms.Resumes
  work = joinpath(dir, "again.vt")
  log = joinpath(dir, "ran.log")
  wrap = joinpath(dir, "wrap")   # it says how to start it again, and then becomes the program that it was asked for
  write(work, "")
  cp(joinpath(@__DIR__, "resume-wrap"), wrap)
  "A new window on the terminal's file, as when Ladder opens: the editor, the window, what drives it, and the terminal"
  opened() = begin
    e2 = K.build_editor(work)
    w2 = Window(e2, size=(900px, 560px))
    d = drive(w2, frames=3, pressed=1)
    d.frames()
    (e2, w2, d, e2.nodes[(:term, work)])
  end
  till(d, done; seconds=10) = (t = time(); while !done() && time() - t < seconds; sleep(0.02); d.frames(1); end; d.frames(1); done())
  enter(w2, d, line) = (foreach(c -> ontype(w2, Typed(c, w2)), line); d.key(Keys.enter))
  ran() = isfile(log) ? readlines(log) : String[]
  odd = "\$(echo no); a  b"   # a word that a shell would run, if the terminal made a command's text of it

  e2, w2, d, v = opened()
  @test Terms.running(v) && length(v.token) >= 22 && isempty(v.records)
  ok = till(d, () -> occursin("\$", Screens.words(v.term)))
  @test ok
  enter(w2, d, "$wrap sh -c 'echo \"\$1\" >> $log; exec sleep 30' x '$odd'")
  ok = till(d, () -> length(v.records) == 1 && length(ran()) == 1)
  @test ok
  @test ran() == [odd]
  kept_one = only(R.kept(work))
  @test kept_one.argv == [wrap, "sh", "-c", "echo \"\$1\" >> $log; exec sleep 30", "x", odd] && kept_one.cwd == dir
  first_pid = only(v.records).pid

  # Ladder closes while the program runs. What it said stays with Ladder's files, and isn't in the terminal's file.
  K.onclose(e2, w2)
  @test !Terms.running(v) && length(R.kept(work)) == 1
  @test !occursin("7577", read(work, String))
  ok = till(d, () -> !R.runs(kept_one))
  @test ok

  # Ladder opens again: the terminal starts a shell at once, and the program is back, with each word as it was
  e3, w3, d3, v3 = opened()
  @test Terms.running(v3) && v3.token != v.token
  ok = till(d3, () -> length(v3.records) == 1 && length(ran()) == 2)
  @test ok
  @test ran() == [odd, odd]
  @test only(v3.records).pid != first_pid && Terms.busy(v3)
  @test !occursin("again ", Screens.words(v3.term))                # the line that the terminal typed is off the screen
  @test !any(endswith(".run"), readdir(R.STORE[]))                 # and the file of the command's words is read and gone
  d3.shot("terminal-again.png")

  # You end the program yourself: a moment later nothing is kept, so it doesn't start again
  d3.key(Keys.c, Keys.ctrl)
  ok = till(d3, () -> isempty(v3.records) && isempty(R.kept(work)), seconds=R.GRACE + 8)
  @test ok
  K.onclose(e3, w3)
  e4, w4, d4, v4 = opened()
  @test !Terms.running(v4) && occursin("Press Return to start a shell", Terms.hint(v4))

  # The shell ends with `exit` while a program that spoke still runs: that program doesn't start again
  d4.key(Keys.enter)
  ok = till(d4, () -> Terms.running(v4) && Terms.Ptys.reading(v4.shell))
  @test ok
  enter(w4, d4, "$wrap sleep 4 &")
  ok = till(d4, () -> length(v4.records) == 1 && length(R.kept(work)) == 1)
  @test ok
  enter(w4, d4, "exit")
  ok = till(d4, () -> !Terms.running(v4))
  @test ok
  @test isempty(v4.records) && isempty(R.kept(work))

  # With the setting off, a shell gets no secret, so no program can speak
  K.TERM_SETTINGS.again = false
  d4.frames(1)
  d4.key(Keys.enter)
  @test Terms.running(v4) && v4.token == ""
  enter(w4, d4, "echo \"token:[\$OSC7577_TOKEN]\"")
  ok = till(d4, () -> occursin("token:[]", Screens.words(v4.term)))
  @test ok
  K.TERM_SETTINGS.again = true
  K.onclose(e4, w4)

  # zsh keeps the line that the terminal types out of its history, and still reads your own settings
  work = joinpath(dir, "zsh.vt")
  write(work, "")
  own = joinpath(dir, "zsh settings")
  mkpath(own)
  history = joinpath(own, "history")
  write(joinpath(own, ".zshenv"), "LADDER_TEST_OWN=read\n")
  write(joinpath(own, ".zshrc"), "HISTFILE='$history'\nHISTSIZE=100\nSAVEHIST=100\nsetopt inc_append_history\nPS1='zsh> '\n")
  Terms.USUAL[] = ["/bin/zsh"]
  withenv("ZDOTDIR" => own) do
    e5, w5, d5, v5 = opened()
    ok = till(d5, () -> Terms.Ptys.reading(v5.shell))
    @test ok
    enter(w5, d5, "$wrap sleep 30")
    ok = till(d5, () -> length(v5.records) == 1)
    @test ok
    K.onclose(e5, w5)
    e6, w6, d6, v6 = opened()
    ok = till(d6, () -> length(v6.records) == 1 && Terms.busy(v6))
    @test ok
    @test !occursin("again ", Screens.words(v6.term))
    d6.key(Keys.c, Keys.ctrl)
    ok = till(d6, () -> Terms.Ptys.reading(v6.shell))
    @test ok
    enter(w6, d6, "echo \"own:[\$ZDOTDIR] [\$LADDER_TEST_OWN] [\$LADDER_AGAIN\$LADDER_ZDOTDIR]\"")
    ok = till(d6, () -> occursin("own:[$own] [read] []", replace(Screens.words(v6.term), "\n" => "")))
    @test ok
    said = read(history, String)
    @test occursin("sleep 30", said) && occursin("echo", said) && !occursin("again", said)
    K.onclose(e6, w6)
  end
  Terms.USUAL[] = ["/bin/sh"]
end
