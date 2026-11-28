# Tests for ⌃↑ and ⌃↓, which make the number or the word at the caret a step
# bigger or smaller. See `step_value!` in commands.jl. Run them with
# `julia -O0 --project=. test/value_step_test.jl`. They use windows that aren't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "./drive" drive
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

"A window that isn't on the screen, on a file with `text` in it"
window(text; name="page.md") = begin
  path = joinpath(dir, name)
  write(path, text)
  e = K.build_editor(path)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  K.focus(e)
  e, w
end

const (; key) = drive()
up(w) = key(w, Keys.up, Keys.ctrl)
down(w) = key(w, Keys.down, Keys.ctrl)
caret!(e, w, line, col) = (e.buf.caret = e.buf.anchor = (line, col); K.touch!(e); frame(w))

"The text of `line` with the number that the caret is at in brackets, or nothing"
marked(line, col) = (at = K.caret_number(line, col); at === nothing ? nothing : K.head(line, at[1]) * "[" * K.rest(K.head(line, at[2]), at[1]) * "]" * K.rest(line, at[2]))

@testset "the number at the caret" begin
  @test marked("width 16m", 6) == "width [16]m"     # at its start
  @test marked("width 16m", 7) == "width [16]m"     # inside it
  @test marked("width 16m", 8) == "width [16]m"     # at its end
  @test marked("width 16m", 5) === nothing          # a space away
  @test marked("no number", 3) === nothing
  @test marked("2.40", 4) == "[2.40]"               # digits, a dot and digits are one number
  @test marked("2.40", 1) == "[2.40]"
  @test marked("v1.2.3", 3) == "v1.[2].3"           # a list of numbers with dots
  @test marked("v1.2.3", 6) == "v1.2.[3]"
  @test marked("192.168.0.1", 5) == "192.[168].0.1"
  @test marked("x = -5", 6) == "x = [-5]"           # a - is a sign after a space
  @test marked("x = -5", 4) == "x = [-5]"           # and the caret can be before it
  @test marked("x-1", 3) == "x-[1]"                 # but not after a letter
  @test marked("x-1", 1) === nothing                # so the caret before it isn't at the number
  @test marked("f(2)-1", 6) == "f(2)-[1]"
  @test marked("2026-11-21", 6) == "2026-[11]-21"   # nor after a digit
  @test marked("|-0.5|", 3) == "|[-0.5]|"
  @test marked("h1", 2) == "h[1]"
  @test marked("ünï 42", 5) == "ünï [42]"           # columns are characters, not bytes
end

@testset "a number a step on" begin
  @test K.number_plus("16", 1) == "17"
  @test K.number_plus("16", -1) == "15"
  @test K.number_plus("9", 1) == "10"
  @test K.number_plus("10", -1) == "9"
  @test K.number_plus("0", -1) == "-1"
  @test K.number_plus("-1", 1) == "0"
  @test K.number_plus("-5", -1) == "-6"
  @test K.number_plus("2.40", 1) == "2.41"          # a step is one of the last digit
  @test K.number_plus("2.4", 1) == "2.5"
  @test K.number_plus("2.99", 1) == "3.00"
  @test K.number_plus("0.05", -10) == "-0.05"
  @test K.number_plus("-0.01", 1) == "0.00"
  @test K.number_plus("-2.5", 1) == "-2.4"
  @test K.number_plus("09", 1) == "10"              # a 0 at the front keeps the width
  @test K.number_plus("007", 1) == "008"
  @test K.number_plus("00", -1) == "-01"
  @test K.number_plus("99999999999999999999", 1) == "100000000000000000000"
end

@testset "a word a step up or down" begin
  @test K.word_step("true", true) == "false"        # true and false swap with either key
  @test K.word_step("false", true) == "true"
  @test K.word_step("true", false) == "false"
  @test K.word_step("True", true) == "False"
  @test K.word_step("FALSE", false) == "TRUE"
  @test K.word_step("word", true) == "Word"         # small letters, a capital, all capitals
  @test K.word_step("Word", true) == "WORD"
  @test K.word_step("WORD", true) == "WORD"         # it can't go further
  @test K.word_step("WORD", false) == "Word"
  @test K.word_step("Word", false) == "word"
  @test K.word_step("word", false) == "word"
  @test K.word_step("camelCase", true) == "CamelCase"
  @test K.word_step("CamelCase", true) == "CAMELCASE"
  @test K.word_step("CamelCase", false) == "camelCase"
  @test K.word_step("a", true) == "A"
  @test K.word_step("A", false) == "a"
  @test K.word_step("_private", true) == "_Private"
  @test K.word_step("école", true) == "École"
  @test K.word_step("日本", true) == "日本"            # letters with no capitals stay
end

@testset "the value at the caret" begin
  @test K.caret_value("Wall length = 12m", 17, 1) == (14, 16, "13")   # after the unit, the number changes
  @test K.caret_value("Area = 2.4m", 11, -1) == (7, 10, "2.3")
  @test K.caret_value("h1", 0, 1) == (1, 2, "2")
  @test K.caret_value("x = true", 8, 1) == (4, 8, "false")
  @test K.caret_value("x = true", 4, -1) == (4, 8, "false")
  @test K.caret_value("untrue", 6, 1) == (0, 6, "Untrue")             # true inside a word isn't true
  @test K.caret_value("don't stop", 2, 1) == (0, 5, "Don't")
  @test K.caret_value("'quoted'", 3, 1) == (1, 7, "Quoted")
  @test K.caret_value("a  b", 2, 1) === nothing
  @test K.caret_value("WORD", 4, 1) === nothing
end

@testset "⌃↑ and ⌃↓ change the number at the caret" begin
  e, w = window("# Sizes\n\nwidth 16m and 2.40 high\n")
  b = e.buf
  caret!(e, w, 3, 8)                                 # at the end of 16
  up(w)
  @test b.lines[3] == "width 17m and 2.40 high"
  @test b.caret == (3, 8)
  down(w); down(w)
  @test b.lines[3] == "width 15m and 2.40 high"
  # Presses one after another are taken back by one ⌘Z
  key(w, Keys.z, Keys.cmd)
  @test b.lines[3] == "width 16m and 2.40 high"
  # The caret at the end of 9 is at the end of 10
  caret!(e, w, 3, 18)                                # at the end of 2.40
  for _ in 1:60 up(w) end
  @test b.lines[3] == "width 16m and 3.00 high"
  @test b.caret == (3, 18)
  # A key that's typed after them is taken back by itself
  K.edit!(b, (3, 23), (3, 23), "!", typing=true)
  key(w, Keys.z, Keys.cmd)
  @test b.lines[3] == "width 16m and 3.00 high"
  key(w, Keys.z, Keys.cmd)
  @test b.lines[3] == "width 16m and 2.40 high"
  # With a word at the caret and no number, the word gets a capital
  caret!(e, w, 3, 2)
  up(w)
  @test b.lines[3] == "Width 16m and 2.40 high"
  key(w, Keys.z, Keys.cmd)
  # The number grows a digit, and the caret stays as far from its end
  K.edit!(b, (3, 0), K.line_end(b, 3), "count 99 apples")
  caret!(e, w, 3, 6)                                 # at the start of 99
  up(w)
  @test b.lines[3] == "count 100 apples" && b.caret == (3, 6)
  caret!(e, w, 3, 8)                                 # between the 0s
  down(w)
  @test b.lines[3] == "count 99 apples" && b.caret == (3, 7)
end

@testset "⌃↑ and ⌃↓ change the word at the caret" begin
  e, w = window("hello world
")
  b = e.buf
  caret!(e, w, 1, 2)
  up(w)
  @test b.lines[1] == "Hello world" && b.caret == (1, 2)
  up(w); up(w)
  @test b.lines[1] == "HELLO world"
  down(w)
  @test b.lines[1] == "Hello world"
  key(w, Keys.z, Keys.cmd)
  @test b.lines[1] == "hello world"
  # With no word at the caret, nothing changes
  K.edit!(b, (1, 0), K.line_end(b, 1), "a  b")
  caret!(e, w, 1, 2)
  v = b.version
  up(w)
  @test b.lines[1] == "a  b" && b.version == v
end

@testset "⌃↑ changes the number at each caret" begin
  e, w = window("a 1\nb 5\nc 9\n")
  b = e.buf
  b.caret = b.anchor = (1, 3)
  b.others = [((2, 3), (2, 3)), ((3, 3), (3, 3))]
  K.keep_others!(b)
  frame(w)
  up(w)
  @test b.lines[1:3] == ["a 2", "b 6", "c 10"]
  key(w, Keys.z, Keys.cmd)
  @test b.lines[1:3] == ["a 1", "b 5", "c 9"]
end

@testset "⌃↑ in a row of a sheet" begin
  e, w = window("# Paint\n\n```sheet\nWall length = 12m\nWall height = 2.4m\nArea = wall length * wall height\n```\n")
  b = e.buf
  caret!(e, w, 4, 16)                                # at the end of 12
  up(w); frame(w)
  @test b.lines[4] == "Wall length = 13m"
  @test any(r -> startswith(r.text, "31.2"), only(it.content for it in e.layout if it.content isa K.Sheet).results)
end

@testset "⌃↑ in a file of code" begin
  e, w = window("x = 41\nshow = true\n", name="code.jl")
  @test e.buf.view == :code
  caret!(e, w, 1, 6)
  up(w)
  @test e.buf.lines[1] == "x = 42"
  caret!(e, w, 2, 11)                                # at the end of true
  down(w)
  @test e.buf.lines[2] == "show = false" && e.buf.caret == (2, 12)
  down(w)
  @test e.buf.lines[2] == "show = true"
end
