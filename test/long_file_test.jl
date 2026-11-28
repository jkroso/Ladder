# Tests for a long file, in main.jl: a file of code of any length opens whole,
# as code to change. Its lines are laid out with no measuring, and the layout
# is kept from one frame to the next. After a change, only the lines that
# changed are laid out again, and only the code that the change touches is read
# again for its names. Run them with
# `julia -O0 --project=. test/long_file_test.jl`. They draw a window that isn't
# on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window Typed Keys ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

# The folder is the test's own each time, so that two test processes that run at once don't write the same files
const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

# A file of Julia code that's longer than a preview shows: 9,000 functions, with some lines that
# are too long for the window, a word that's too long for it, and characters that a keyboard doesn't type
const odd = [
  "",
  "# A comment that goes on and on, with many words in it, so that it's too long for one line of a window that's a thousand pixels wide, and has to go on under itself",
  "      deep(x) = x + 1   # a line that starts far in, and then goes on for long enough to break at the edge of the window, well past its first words",
  "const address = \"https://example.com/a/path/that/has/no/space/in/it/and/so/can/not/break/at/a/space/however/wide/the/window/is/made/to/be/for/it/and/more/and/more/of/it\"",
  "const sum_ΣΔ = \"naïve café — 日本語\"   # characters of other widths",
  "\tindented(with) = :a_tab",
  "x = 1    ",
]
const code = join(["\"Number $i\"\nfunction step$i(wall, count=$i)\n  total = wall * count\n  total + $i\nend\n" * (i % 400 == 0 ? join(odd, "\n") * "\n" : "") for i in 1:9000], "\n")
const long = joinpath(dir, "steps.jl")
write(long, code)

const start = joinpath(dir, "start.md")
write(start, "# Start\n")
const e = K.build_editor(start)
const w = Window(e, size=(1000px, 700px))
frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames()
K.open!(e, long)
frames()
const b = e.buf
const code_line = K.kinds(b)[1]

"True when the two layouts of a line put each character at the same place"
alike(a, c) = length(a.lines) == length(c.lines) && K.tall(a) == K.tall(c) && all(eachindex(a.lines)) do k
  x, y = a.lines[k], c.lines[k]
  wide(vl) = isempty(vl.segs) ? 0.0 : K.num(last(vl.segs).x + last(vl.segs).w)
  (x.from, x.to) == (y.from, y.to) && abs(K.num(x.x - y.x)) < 0.01 && abs(K.num(x.top - y.top)) < 0.01 && x.high == y.high && abs(wide(x) - wide(y)) < 0.05
end
"Line `i` as the layout of the whole file has it, and as it's laid out in full"
both(i) = (f = K.face(e, code_line); (K.quick_line(e, b.lines[i], code_line, i, f, K.code_size(e) * 1.5 / K.CODE_SCALE, K.pitch(f)), K.file_line(e, b.lines[i], code_line, i)))

@testset "a long file opens whole, as code to change" begin
  @test filesize(long) > K.MOST_TEXT && K.iscode(long)
  @test b.view == :code && b.lines == K.text(long) && length(b.lines) > 50_000 && isempty(b.about)
  @test length(e.layout) == length(b.lines) && e.layout[end].last == length(b.lines)
  # Each line starts where the line before it ends
  @test all(k -> e.layout[k].top == e.layout[k-1].top + e.layout[k-1].tall, 2:length(e.layout))
  # A file that isn't code shows whole too, and isn't changed
  notes = joinpath(dir, "notes.txt")
  write(notes, join(["A line of notes, number $i, with a few more words." for i in 1:12_000], "\n"))
  @test filesize(notes) > K.MOST_TEXT
  shown = K.text_look(notes)
  @test shown.view == :text && length(shown.lines) == 12_000 && isempty(shown.about)
  # A preview still stops, and says so
  @test K.reading(notes)[2] && length(K.reading(notes)[1]) < 12_000
end

@testset "a line is laid out with no measuring, as it is in full" begin
  f = K.face(e, code_line)
  @test K.pitch(f) !== nothing   # code's own font has characters of one width
  @test K.typeable("f(x) = 1 ~ 2") && !K.typeable("café") && !K.typeable("\tx")
  # Words that fit, words that break at the edge, and a word that's too long to count
  @test K.quick_rows("ab cd ef", 10.0, 55.0, 20.0) == [(0, 6), (6, 8)]
  @test K.quick_rows("    ab cd", 10.0, 62.0, 30.0) == [(0, 7), (7, 9)]
  @test K.quick_rows("ab", 10.0, 100.0, 20.0) == [(0, 2)]
  @test K.quick_rows("abcdefghijkl mn", 10.0, 100.0, 20.0) === nothing
  # The spaces after a word hang past the edge, and a word that ends at the edge could go either way
  @test K.quick_rows("abcde     fg", 10.0, 70.0, 0.0) == [(0, 10), (10, 12)]
  @test K.quick_rows("abc defg", 10.0, 80.2, 0.0) === nothing
  # Every kind of line of the file, at three widths of the window, wrapped and not
  sample = unique([1:40; findall(l -> any(o -> !isempty(o) && l == o, odd), b.lines)[1:min(end, 21)]; length(b.lines)-5:length(b.lines)])
  for wrapped in (true, false), wide in (1000px, 640px, 380px)
    e.wrap = wrapped
    e.width = wide
    @test all(i -> alike(both(i)...), sample)
  end
  e.wrap = true
  e.width = K.text_width(e)
  # A line that fits is one run of text, and a line that breaks is one run for each line on screen
  long_comment = findfirst(==(odd[2]), b.lines)
  @test length(both(1)[1].lines[1].segs) == 1 && length(both(long_comment)[1].lines) > 1 && all(vl -> length(vl.segs) == 1, both(long_comment)[1].lines)
end

@testset "the layout is kept, and only the lines on screen are laid out in full" begin
  empty!(e.flows)
  frames()
  kept = e.layout
  frames()
  @test e.layout === kept
  full = count(k -> k isa Tuple && k[1] === :file, keys(e.flows))
  @test 0 < full < 200
  # A line on screen is drawn with the colours of its code: more runs of text than the one that the layout has
  it = e.layout[first(e.shown)+1]
  @test length(it.content.lines[1].segs) == 1 && length(K.in_colour(e, it, it.content).lines[1].segs) > 1
  # Many lines laid out in full make room for more, and the file's layout stays, with where its docstrings are. A long file keeps three for each of its lines.
  foreach(k -> e.flows[(:file, "line $k", code_line)] = it.content, 1:3length(b.lines)+100)
  K.spare_flows!(e)
  @test length(e.flows) == 2 && all(p -> p.second isa K.Laid || p.second isa K.Opens, e.flows) && K.file_lines(e, b) === kept
end

@testset "after a change, only the lines that changed are laid out again" begin
  before = copy(e.layout)
  n = length(b.lines)
  K.edit!(b, (3000, 0), (3000, 0), "  extra = 1\n  more = 2\n")
  frames()
  @test length(e.layout) == n + 2 && e.layout !== before
  # The lines before the change and after it keep what was laid out for them
  @test all(k -> e.layout[k] === before[k], 1:2999)
  @test all(k -> e.layout[k+2].content === before[k].content && e.layout[k+2].first == k + 2, 3001:20:n)
  @test all(k -> e.layout[k].top == e.layout[k-1].top + e.layout[k-1].tall, 2:length(e.layout))
  # It's what a new layout of the whole file gives
  tops = [it.top for it in e.layout]
  empty!(e.flows)
  frames()
  @test [it.top for it in e.layout] == tops
  K.undo!(b)
  frames()
  @test length(e.layout) == n && [it.top for it in e.layout] == [it.top for it in before]
end

"The names as they're kept, and as a new read of the whole file gives them"
names_match() = sort(K.page_bounds(e), by=x -> (x.at, x.name)) == sort(K.read_names(b.lines, 1), by=x -> (x.at, x.name))

@testset "after a change, only the code that it touches is read again for its names" begin
  @test names_match()
  kept = e.nodes[:file_names]
  @test length(kept.parts) >= 9000 && kept.parts[1].first == 1
  at = findfirst(==("function step4500(wall, count=4500)"), b.lines)
  # A new name in a function
  K.edit!(b, (at + 1, 0), (at + 1, 0), "  height = wall / 2\n")
  @test names_match() && any(x -> x.name == "height" && x.at[1] == at + 1, K.page_bounds(e))
  now = e.nodes[:file_names]
  # The parts before the function are the ones that were read before, and so are the names of the parts after it
  k = findfirst(p -> p.first > at, now.parts)
  @test now.parts[1] === kept.parts[1] && now.parts[k-3].names === kept.parts[k-3].names
  @test now.parts[end].names === kept.parts[end].names && now.parts[end].first == kept.parts[end].first + 1
  # A new function between two others, lines that go, and two lines that join
  K.edit!(b, (at - 1, 0), (at - 1, 0), "between(a, b) = a + b\n")
  @test names_match() && any(x -> x.name == "between", K.page_bounds(e))
  K.edit!(b, (at + 20, 0), (at + 27, 0), "")
  @test names_match()
  K.edit!(b, (1, length(b.lines[1])), (2, 0), " ")
  @test names_match()
  K.edit!(b, (length(b.lines), 0), (length(b.lines), 0), "last_one = 3")
  @test names_match() && any(x -> x.name == "last_one", K.page_bounds(e))
  # Code that's half typed leaves the names of the other parts as they were
  after = count(x -> x.at[1] > at + 40, K.page_bounds(e))
  K.edit!(b, (at + 40, 0), (at + 40, 0), "function half(a,\n")
  @test count(x -> x.at[1] > at + 41, K.page_bounds(e)) == after
  K.undo!(b)
  @test names_match()
  foreach(_ -> K.undo!(b), 1:5)
  @test b.lines == K.text(long) && names_match()
end

@testset "a typed letter and a save" begin
  K.focus(e)
  b.caret = b.anchor = (4, 2)
  ontype(e, Typed('z', w))
  frames()
  @test b.lines[4] == "  ztotal + 1" && length(e.layout) == length(b.lines)
  K.save!(b)
  @test read(long, String) == replace(code, "  total + 1\nend\n\n\"Number 2\"" => "  ztotal + 1\nend\n\n\"Number 2\"")
end

close(w)
