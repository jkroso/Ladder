# Tests for term/screen.jl and term/pty.jl: a terminal's screen, and a program
# on a pseudo-terminal. Run them with `julia -O0 --project=. test/terminal_test.jl`.
# They draw no window. The last set starts the Mac's own /bin/sh.

@use Test: @test, @testset
@use "../term/screen" => T
@use "../term/pty" => P

"The text of line `r` of the screen, without the blanks at its end"
row(t, r) = rstrip(T.words(t, t.lines[r]))
"The terminal of `rows` by `cols` after it reads `words`"
fed(words; rows=5, cols=20) = T.feed!(T.Terminal(rows, cols), words)

@testset "text goes where the cursor is" begin
  t = fed("one\r\ntwo")
  @test row(t, 1) == "one"
  @test row(t, 2) == "two"
  @test (t.row, t.col) == (2, 4)
  # A line feed alone goes down and stays in its column
  t = fed("ab\ncd")
  @test row(t, 2) == "  cd"
  # Backspace and a tab move the cursor and erase nothing
  t = fed("abc\b\bX\tY")
  @test row(t, 1) == "aXc     Y"
  # Bytes can stop inside a character and inside a code
  t = T.Terminal(5, 20)
  bytes = Vector{UInt8}(codeunits("é\e[31mr"))
  foreach(b -> T.feed!(t, [b]), bytes)
  @test row(t, 1) == "ér"
  @test t.lines[1].cells[2].fg == T.numbered(1)
  # Bytes that are no character show as �
  t = T.feed!(T.Terminal(5, 20), UInt8[0x61, 0xff, 0x62])
  @test row(t, 1) == "a�b"
end

@testset "a line that's too long goes on in the next" begin
  t = fed("abcdefgh", cols=5)
  @test row(t, 1) == "abcde"
  @test row(t, 2) == "fgh"
  @test t.lines[1].wrapped
  # A line that fills the width exactly doesn't start the next one until more comes
  t = fed("abcde", cols=5)
  @test (t.row, t.col, t.pending) == (1, 5, true)
  T.feed!(t, "\r\nx")
  @test row(t, 2) == "x"
  @test !t.lines[1].wrapped
  # A program can turn the wrapping off
  t = fed("\e[?7labcdefgh", cols=5)
  @test row(t, 1) == "abcdh"
  @test row(t, 2) == ""
end

@testset "lines that leave the top are kept" begin
  t = fed(join(("line $i" for i in 1:8), "\r\n"), rows=3)
  @test [row(t, r) for r in 1:3] == ["line 6", "line 7", "line 8"]
  @test length(t.past) == 5
  @test T.words(t, t.past[1]) |> rstrip == "line 1"
  @test T.words(t) == join(("line $i" for i in 1:8), "\n")
  # Only the last `most` are kept, and the ones that go are counted
  t = T.Terminal(3, 20, most=4)
  T.feed!(t, join(("line $i" for i in 1:20), "\r\n"))
  @test length(t.past) == 4
  @test t.gone == 13
  # The code that clears the past
  T.feed!(t, "\e[3J")
  @test isempty(t.past)
end

@testset "codes that move the cursor and erase" begin
  t = fed("\e[3;5Hx\e[Hy\e[2;2Hz")
  @test row(t, 3) == "    x"
  @test row(t, 1) == "y"
  @test row(t, 2) == " z"
  t = fed("abcdef\e[3D\e[K")
  @test row(t, 1) == "abc"
  t = fed("abcdef\e[1;3H\e[1K")
  @test row(t, 1) == "   def"
  t = fed("one\r\ntwo\r\nthree\e[2;2H\e[J")
  @test [row(t, r) for r in 1:3] == ["one", "t", ""]
  t = fed("one\r\ntwo\e[2J")
  @test T.words(t) == ""
  # Up, down, on and back stop at the edges
  t = fed("\e[99B\e[99Cx\e[99A\e[99Dy", cols=8)
  @test row(t, 5) == "       x"
  @test row(t, 1) == "y"
  # Cells and lines can be put in and taken out
  t = fed("abcdef\e[1;3H\e[2@")
  @test row(t, 1) == "ab  cdef"
  t = fed("abcdef\e[1;3H\e[2P")
  @test row(t, 1) == "abef"
  t = fed("abcdef\e[1;3H\e[2X")
  @test row(t, 1) == "ab  ef"
  t = fed("one\r\ntwo\r\nthree\e[2;1H\e[L")
  @test [row(t, r) for r in 1:4] == ["one", "", "two", "three"]
  t = fed("one\r\ntwo\r\nthree\e[2;1H\e[M")
  @test [row(t, r) for r in 1:3] == ["one", "three", ""]
  # The code that writes the last character again
  @test row(fed("ab\e[3b"), 1) == "abbbb"
end

@testset "a part of the screen can scroll by itself" begin
  t = fed("top\r\na\r\nb\r\nc\r\nfoot\e[2;4r\e[4;1H\r\nd")
  @test [row(t, r) for r in 1:5] == ["top", "b", "c", "d", "foot"]
  @test isempty(t.past)   # a line that leaves the middle of the screen isn't kept
  # The code that goes up a line moves the part down at its top
  t = fed("top\r\na\r\nb\r\nc\r\nfoot\e[2;4r\e[2;1H\eMnew")
  @test [row(t, r) for r in 1:5] == ["top", "new", "a", "b", "foot"]
end

@testset "colours and styles" begin
  t = fed("\e[1;4;31;42mA\e[0mB\e[38;5;200mC\e[38;2;10;20;30mD\e[48:2::1:2:3mE\e[0;38:5:6mF\e[91;107mG\e[7mH")
  cells = t.lines[1].cells
  @test cells[1].fg == T.numbered(1) && cells[1].bg == T.numbered(2)
  @test cells[1].flags == T.BOLD | T.UNDERLINE
  @test cells[2] == T.Cell('B', 0, 0, 0, 0)
  @test cells[3].fg == T.numbered(200)
  @test cells[4].fg == T.direct(10, 20, 30)
  @test cells[5].bg == T.direct(1, 2, 3)
  @test cells[6].fg == T.numbered(6) && cells[6].bg == 0
  @test cells[7].fg == T.numbered(9) && cells[7].bg == T.numbered(15)
  @test cells[8].flags & T.INVERSE != 0
  # An erased cell has the colour that the cursor writes on
  t = fed("\e[44m\e[K")
  @test t.lines[1].cells[20].bg == T.numbered(4)
  # A code for the keyboard that looks like a style isn't one
  t = fed("\e[>4;2mx")
  @test t.lines[1].cells[1].flags == 0
  @test T.colour256(16) == 0x000000 && T.colour256(231) == 0xffffff && T.colour256(196) == 0xff0000 && T.colour256(232) == 0x080808
end

@testset "wide characters and accents" begin
  t = fed("a界b")
  cells = t.lines[1].cells
  @test cells[2].flags & T.WIDE != 0 && cells[3].flags & T.TAIL != 0
  @test cells[4].ch == 'b'
  @test row(t, 1) == "a界b"
  # A wide character with one cell left starts the next line
  t = fed("abcd界", cols=5)
  @test row(t, 1) == "abcd" && row(t, 2) == "界"
  # One that's written over in half is gone whole
  t = fed("界\rx")
  @test row(t, 1) == "x"
  # An accent goes on the character before it
  t = fed("éx")
  @test T.shown(t, t.lines[1].cells[1]) == "é"
  @test t.lines[1].cells[2].ch == 'x'
  @test row(t, 1) == "éx"
end

@testset "the second screen" begin
  t = fed("shell\r\n\e[?1049h\e[Hvim\e[2;1Htext")
  @test t.second
  @test row(t, 1) == "vim"
  @test isempty(t.past)
  T.feed!(t, "\e[?1049l")
  @test !t.second
  @test row(t, 1) == "shell"
  @test (t.row, t.col) == (2, 1)   # the cursor is back where it was
end

@testset "the set of characters that draws lines" begin
  t = fed("\e(0lqk\e(Blqk")
  @test row(t, 1) == "┌─┐lqk"
end

@testset "what the terminal answers" begin
  t = fed("\e[3;4H\e[6n")
  @test T.answers!(t) == "\e[3;4R"
  @test T.answers!(t) == ""
  @test T.answers!(fed("\e[c")) == "\e[?62;22c"
  @test T.answers!(fed("\e[5n")) == "\e[0n"
  @test T.answers!(fed("\e[?2004h\e[?2004\$p")) == "\e[?2004;1\$y"
  @test T.answers!(fed("\e[?9999\$p")) == "\e[?9999;0\$y"
  @test T.answers!(fed("\e[?u")) == "\e[?0u"
  t = T.Terminal(5, 20, ink=0x00102030, paper=0x00f0e0d0)
  T.feed!(t, "\e]11;?\a\e]10;?\e\\")
  @test T.answers!(t) == "\e]11;rgb:f0f0/e0e0/d0d0\a\e]10;rgb:1010/2020/3030\e\\"
end

@testset "the window's title and the shell's folder" begin
  t = fed("\e]0;my title\aafter\e]7;file://mac.local/Users/sam/My%20Files\e\\")
  @test t.title == "my title"
  @test row(t, 1) == "after"
  @test t.folder == "/Users/sam/My Files"
  # Words for the terminal that it doesn't read show nothing
  @test row(fed("a\eP1\$r0m\e\\b\e_hidden\e\\c"), 1) == "abc"
end

@testset "another size" begin
  # Text that was wrapped is laid out again
  t = fed("abcdefghij\r\nkl", rows=4, cols=5)
  @test [row(t, r) for r in 1:3] == ["abcde", "fghij", "kl"]
  resize!(t, 4, 10)
  @test [row(t, r) for r in 1:2] == ["abcdefghij", "kl"]
  @test (t.row, t.col) == (2, 3)
  resize!(t, 4, 4)
  @test T.words(t) == "abcdefghij\nkl"
  @test row(t, t.row) == "kl"
  @test t.col == 3
  # With fewer lines, the top ones go to the past, and the cursor stays on the screen
  t = fed("1\r\n2\r\n3\r\n4", rows=4, cols=10)
  resize!(t, 2, 10)
  @test [row(t, r) for r in 1:2] == ["3", "4"]
  @test length(t.past) == 2
  @test (t.row, t.col) == (2, 2)
  # With more lines, blank ones come under the text
  resize!(t, 6, 10)
  @test T.words(t) == "1\n2\n3\n4"
  @test length(t.lines) == 6
  @test all(l -> length(l.cells) == 10, t.lines)
  # The first screen is laid out again while the second shows
  t = fed("abcdefgh\e[?1049h\e[Hvim", rows=4, cols=4)
  resize!(t, 4, 8)
  @test row(t, 1) == "vim"
  T.feed!(t, "\e[?1049l")
  @test row(t, 1) == "abcdefgh"
  @test (t.row, t.col) == (1, 8)
end

@testset "saved text makes the same lines again" begin
  t = fed("\e[1;31mred\e[0m plain \e[44mblue\e[0m\r\nabcdefghijklmnopqrstuvwxyz\r\n\r\nlast 界", rows=3, cols=10)
  text = T.saved(t)
  @test !occursin("\e[?", text)
  @test count("\r\n", text) == 3   # a line that was wrapped is one line of the file
  again = T.restore!(T.Terminal(3, 10), Vector{UInt8}(codeunits(text)))
  @test T.words(again) == T.words(t)
  @test again.past[1].cells[1] == t.past[1].cells[1]
  @test again.col == 1   # the cursor is at the start of a new line
  # A file whose line ends lost their carriage returns, as git can do to it, reads the same
  bare = T.restore!(T.Terminal(3, 10), Vector{UInt8}(codeunits(replace(text, "\r\n" => "\n"))))
  @test T.words(bare) == T.words(t) && bare.col == 1
  # At another width the text wraps there
  wide = T.restore!(T.Terminal(6, 40), Vector{UInt8}(codeunits(text)))
  @test row(wide, 2) == "abcdefghijklmnopqrstuvwxyz"
  @test T.saved(wide) == text
  # A file that asks for things, as what a program wrote does, leaves nothing on and gets no answer
  t = T.restore!(T.Terminal(3, 10), Vector{UInt8}(codeunits("\e[?1000h\e[?2004h\e[6nhi\e[?1049h")))
  @test t.tracks == :none && !t.bracketed && !t.second
  @test T.answers!(t) == ""
  @test T.words(t) == "hi"
end

@testset "the text between two places" begin
  t = fed("abcdefgh\r\nxy z", rows=3, cols=5)
  @test T.words(t, (1, 2), (1, 4)) == "bc"
  @test T.words(t, (1, 4), (2, 3)) == "defg"       # a wrapped line has no line end
  @test T.words(t, (2, 2), (3, 3)) == "gh\nxy"
  @test T.words(t, (3, 3), (2, 2)) == "gh\nxy"     # the two places in either order
  @test T.word_at(t, 3, 1) == (1, 2)
  @test T.word_at(t, 3, 3) == (3, 3)
  t = fed("see ~/Desktop/a-file.md now", cols=40)
  @test T.word_at(t, 1, 8) == (5, 23)
end

@testset "what the keys send" begin
  t = T.Terminal(5, 20)
  @test T.key(t, :up) == "\e[A"
  @test T.key(t, :enter) == "\r"
  @test T.key(t, :enter, T.SHIFT) == "\n"
  @test T.key(t, :enter, T.ALT) == "\e\r"
  @test T.key(t, :tab, T.SHIFT) == "\e[Z"
  @test T.key(t, :backspace) == "\x7f"
  @test T.key(t, :backspace, T.ALT) == "\e\x7f"
  @test T.key(t, :left, T.ALT) == "\eb"
  @test T.key(t, :right, T.CTRL) == "\e[1;5C"
  @test T.key(t, :delete) == "\e[3~"
  @test T.key(t, :pageup, T.SHIFT) == "\e[5;2~"
  @test T.key(t, :f1) == "\eOP" && T.key(t, :f5) == "\e[15~"
  T.feed!(t, "\e[?1h")
  @test T.key(t, :up) == "\eOA" && T.key(t, :home) == "\eOH"
  @test T.control('c') == '\x03' && T.control('C') == '\x03' && T.control('[') == '\e' && T.control(' ') == '\0'
  @test T.control('!') === nothing
end

@testset "what the mouse and a paste send" begin
  t = T.Terminal(5, 20)
  @test T.mouse(t, :press, 0, 2, 3) == ""
  T.feed!(t, "\e[?1000h")
  @test T.mouse(t, :press, 0, 2, 3) == "\e[M" * Char(32) * Char(35) * Char(34)
  @test T.mouse(t, :release, 0, 2, 3) == "\e[M" * Char(35) * Char(35) * Char(34)
  @test T.mouse(t, :move, 0, 2, 3) == ""
  T.feed!(t, "\e[?1002h\e[?1006h")
  @test T.mouse(t, :press, 0, 2, 3) == "\e[<0;3;2M"
  @test T.mouse(t, :release, 0, 2, 3) == "\e[<0;3;2m"
  @test T.mouse(t, :move, 0, 2, 3) == "\e[<32;3;2M"
  @test T.mouse(t, :move, 3, 2, 3) == ""
  @test T.mouse(t, :press, 64, 1, 1, T.CTRL) == "\e[<80;1;1M"
  @test T.paste(t, "a\nb\r\nc") == "a\rb\rc"
  T.feed!(t, "\e[?2004h")
  @test T.paste(t, "x\e[201~y") == "\e[200~xy\e[201~"
  @test T.focus(t, true) == ""
  T.feed!(t, "\e[?1004h")
  @test T.focus(t, true) == "\e[I" && T.focus(t, false) == "\e[O"
end

@testset "what a program finds in its environment" begin
  # A Ladder that was started where no colour shows, or by an agent, doesn't pass that on: this terminal has colour
  names = withenv("NO_COLOR" => "1", "FORCE_COLOR" => "0", "CLICOLOR" => "0", "CLICOLOR_FORCE" => "0", "TERM" => "dumb",
                  "TERM_PROGRAM" => "ghostty", "GHOSTTY_RESOURCES_DIR" => "/x", "CLAUDECODE" => "1", "AI_AGENT" => "one",
                  "LADDER_TEST_KEPT" => "yes") do
    P.surroundings(("EXTRA" => "1",))
  end
  @test !any(k -> haskey(names, k), ("NO_COLOR", "FORCE_COLOR", "CLICOLOR", "CLICOLOR_FORCE", "GHOSTTY_RESOURCES_DIR", "CLAUDECODE", "AI_AGENT"))
  @test names["TERM"] == "xterm-256color" && names["COLORTERM"] == "truecolor" && names["TERM_PROGRAM"] == "Ladder"
  @test names["LADDER_TEST_KEPT"] == "yes" && names["EXTRA"] == "1" && haskey(names, "HOME") && haskey(names, "PATH")
end

"Wait until `done()` is true, for no more than `seconds`"
until(done; seconds=10) = (t = time(); while !done() && time() - t < seconds; sleep(0.02); end; done())

@testset "a program on a pseudo-terminal" begin
  woke = Threads.Atomic{Int}(0)
  dir = realpath(mktempdir())
  s = P.start(["/bin/sh"], dir=dir, rows=7, cols=33, wake=() -> Threads.atomic_add!(woke, 1))
  t = T.Terminal(7, 33)
  read!() = (T.feed!(t, take!(s)); T.words(t))
  # Each check is worked out first: a failed `@test` prints what it was given, and a Shell's process holds the environment
  ok = until(() -> occursin("\$", read!()))
  @test ok
  @test woke[] > 0
  @test repr(s) == "Shell(running)"
  # It's in a terminal of the size that was asked for, in the folder that was asked for
  P.send!(s, "stty size; pwd; echo \$TERM \$TERM_PROGRAM\r")
  ok = until(() -> occursin("7 33", read!()) && occursin("xterm-256color Ladder", read!()))
  @test ok
  @test occursin(dir, replace(T.words(t), "\n" => ""))
  # It hears of a new size
  resize!(s, 9, 44)
  resize!(t, 9, 44)
  P.send!(s, "stty size\r")
  ok = until(() -> occursin("9 44", read!()))
  @test ok
  # Control-C stops what runs in it, since the terminal controls it: the next command runs long before the 30 seconds are up
  P.send!(s, "sleep 30\r")
  sleep(0.3)
  P.send!(s, "\x03")
  P.send!(s, "echo after-\$((6*7))\r")
  ok = until(() -> occursin("after-42", read!()))
  @test ok
  @test P.alive(s)
  P.send!(s, "exit 3\r")
  ok = until(() -> (read!(); P.done(s)))
  @test ok
  @test P.status(s) == 3
  @test repr(s) == "Shell(ended)"
  # What it writes is read while the main thread waits in C, as a window's loop does while it waits for input
  s = P.start(["/bin/sh"], dir=dir, wake=() -> Threads.atomic_add!(woke, 1))
  ok = until(() -> occursin("\$", String(copy(s.got))))
  @test ok
  take!(s)
  sleep(0.2)   # the thread that reads has had time to start
  was = woke[]
  P.send!(s, "echo while-waiting\r")
  @ccall gc_safe=true usleep(600_000::Cuint)::Cint
  @test woke[] > was
  @test occursin("while-waiting", String(copy(s.got)))
  P.stop!(s)
  # One that's stopped ends
  s = P.start(["/bin/sh"], dir=dir)
  ok = until(() -> occursin("\$ ", String(copy(s.got))))
  @test ok
  P.stop!(s)
  ok = until(() -> !P.alive(s))
  @test ok
end
