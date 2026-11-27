# Tests for the settings of code: wrapping long lines, the numbers of the lines,
# the shade of the caret's line, the line-length guide, the indent, and the font
# and size of code. See "A line of a file of code or of text that's too long for the
# window" in main.jl. Run them with `julia -O0 --project=. test/code_settings_test.jl`.
# They use a window that isn't on the screen. With CODE_SHOTS set to a folder,
# they save pictures of it there.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey onscroll Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect draw scene
@use Skia
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const file = joinpath(dir, "long.jl")
const LONG = "  Box(padding(16px, 8px), radius(6px), background(ishovered(c) ? colorant\"rgb(150,84,40)\" : colorant\"rgb(176,100,48)\"), Text(\"a label that makes this line much too long for the window\"))"
const TEXT = """
describe(c::Counter) =
$LONG

cursor(::Counter) = :hand
"""
write(file, TEXT)
const notes = joinpath(dir, "notes.md")
write(notes, "# Notes\n\n```julia\n$LONG\n```\n")

const e = K.build_editor(file)
const w = Window(e, size=(1000px, 700px))
const Vec2 = typeof(w.mouse)   # a place in the window, or a move of two fingers
const (; frames, typed, key) = drive(w)
frames()
K.focus(e)

caret!(line, col=0) = (e.buf.caret = e.buf.anchor = (line, col); K.touch!(e); frames())
long() = K.item(e, 2).content
mouse!(x, y) = (w.mouse = Vec2(px(x), px(y)); frames(1))
# The part of the window that the page's text is drawn in: the box that cuts off what's past its left and right
clipper(r=rect(e.nodes[:page])) = r.from isa K.Container && r.from.clip_x ? r : (for c in r.children; (c isa K.ConcreteRect && (f = clipper(c)) !== nothing) && return f end; nothing)
swipe(dx, dy=0) = (onscroll(w, Vec2(px(dx), px(dy))); frames())

"The colour of each pixel of the window, as it draws, one pixel for each point. `pixels[x, y]` is the one at (x, y)."
pixels() = begin
  frames()
  W, H = round.(Int, K.num.(w.size))
  info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_OPAQUE, W, H))
  out = Matrix{UInt32}(undef, W, H)
  GC.@preserve info out begin
    surface = Skia.sk_surface_make_raster_n32_premul(pointer_from_objref(info), C_NULL)
    draw(Skia.sk_surface_get_canvas(surface), w.size, scene(w))
    image = Skia.sk_surface_make_image_snapshot(surface)
    Skia.sk_image_read_pixels(image, pointer_from_objref(info), pointer(out), Csize_t(4W), Cint(0), Cint(0), Skia.SK_IMAGE_CACHING_HINT_ALLOW)
    Skia.sk_image_unref(image)
    Skia.sk_surface_unref(surface)
  end
  out
end
"How far down the window the middle of line `i` is"
middle(i) = round(Int, K.num(e.origin[2] + K.item(e, i).top + K.item(e, i).tall / 2))

const shots = get(ENV, "CODE_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name * ".png"), w)

@testset "a long line of code wraps at the edge of the window, one indent further in than it starts" begin
  @test e.wrap && K.wraps(e)
  # A file of code takes all the room the window has, not the width of a page
  @test K.num(e.width) ≈ 1000 - 2K.num(K.PAGE_X) - K.num(K.gutter(e)) atol=1
  f = long()
  @test length(f.lines) >= 2
  space = K.measure(K.face(e, K.kinds(e.buf)[2]), " ")
  @test f.lines[1].x == 0px
  @test all(vl -> isapprox(K.num(vl.x), 4K.num(space), atol=0.01), f.lines[2:end])   # its own 2 spaces, and one indent more
  # Only the space after the last word of a line goes past the edge
  @test all(vl -> isempty(vl.segs) || last(vl.segs).x + K.measure(last(vl.segs).face, rstrip(last(vl.segs).text)) <= e.width, f.lines)
  @test K.sideways(e) == 0px
  shot("wrapped")
end

@testset "with wrap off, a long line goes on past the window and the page scrolls sideways to the caret" begin
  K.wrap!(e, false)
  frames()
  @test !K.wraps(e)
  @test length(long().lines) == 1
  @test e.reach > e.width && K.sideways_room(e) > 0px
  left = K.num(K.PAGE_X) + K.num(K.gutter(e))
  @test K.num(e.origin[1]) ≈ left atol=1
  shot("unwrapped")
  # The caret at the end of the line takes the page with it
  caret!(2, length(LONG))
  @test e.buf.across > 0px
  @test K.num(e.origin[1]) ≈ left - K.num(e.buf.across) atol=1
  @test K.num(K.text_left(e)) ≈ K.num(e.origin[1]) atol=1
  _, x = K.spot(long(), length(LONG))
  @test K.num(e.origin[1] + x) < 1000 - K.num(K.PAGE_X)   # the caret shows
  # The text is cut off at the edges of the page, not where the edges were before it scrolled
  c = clipper()
  @test c.left == 0px && c.left + c.width == 1000px
  shot("at the end")
  # The start of the line takes the page back
  caret!(2, 0)
  @test e.buf.across == 0px
end

@testset "two fingers that move sideways scroll the page sideways, as far as the longest line" begin
  caret!(1, 0)
  y = K.num(e.origin[2] + K.item(e, 2).top) + 10
  mouse!(500, y)
  swipe(-5)
  @test e.buf.across == 150px
  # Up and down at the same time scrolls up and down too
  offset = e.scroll.offset
  swipe(-1, -1)
  @test e.buf.across == 180px && e.scroll.offset == offset + 30px
  swipe(0, 1)
  swipe(1)
  @test e.buf.across == 150px
  swipe(-1000)
  @test e.buf.across == K.sideways_room(e)
  swipe(1000)
  @test e.buf.across == 0px
  @test e.scroll.offset == offset
  # Over the numbers of the lines too
  mouse!(20, y)
  swipe(-2)
  @test e.buf.across == 60px
  shot("swiped")
end

@testset "the numbers of the lines go over the text of a page that's scrolled sideways" begin
  @test e.buf.across > 0px
  y = K.num(e.origin[2] + K.item(e, 2).top) + 10
  # A click on the numbers puts the caret on the first part of the line that shows
  at = K.locate(e, (px(20), px(y)))
  @test at[1] == 2 && at[2] > 0
  _, x = K.spot(long(), at[2])
  @test x >= e.buf.across
end

@testset "a page's code blocks still wrap, and each file keeps how far it's scrolled sideways" begin
  K.open!(e, notes); frames()
  @test K.wraps(e) && K.sideways(e) == 0px
  i = findfirst(==(LONG), e.buf.lines)
  @test length(K.item(e, i).content.lines) >= 2
  K.open!(e, file); frames()
  @test e.buf.across == 60px   # each file keeps how far it's scrolled sideways
end

@testset "the setting goes to the settings file, and back" begin
  home = mktempdir()
  withenv("HOME" => home) do
    e.remember = true
    K.wrap!(e, false)
    @test occursin("wrap=false", read(K.settings_file(), String))
    o = K.load_settings!(K.Editor())
    @test o.wrap == false
    K.wrap!(e, true)
    @test K.load_settings!(K.Editor()).wrap
    e.remember = false
  end
  frames()
  @test length(long().lines) >= 2 && K.sideways(e) == 0px
  @test K.num(e.origin[1]) ≈ K.num(K.PAGE_X) + K.num(K.gutter(e)) atol=1
end

@testset "a printed file of code wraps its long lines, and the window keeps the setting" begin
  K.wrap!(e, false); frames()
  bytes = K.print_pdf(e)
  @test length(bytes) > 1000
  @test !e.wrap
  frames()
  @test length(long().lines) == 1
  K.wrap!(e, true); frames()
end

@testset "the numbers of the lines can be hidden" begin
  @test K.numbers(e) && K.gutter(e) > 0px
  K.numbers!(e, false); frames()
  @test !K.numbers(e) && K.gutter(e) == 0px
  # The code still starts at the left of the page, with only the page's margin beside it
  @test K.num(e.origin[1]) ≈ K.num(K.PAGE_X) atol=1
  @test K.num(e.width) ≈ 1000 - 2K.num(K.PAGE_X) atol=1
  shot("no numbers")
  K.numbers!(e, true); frames()
  @test K.num(e.origin[1]) ≈ K.num(K.PAGE_X) + K.num(K.gutter(e)) atol=1
end

@testset "the line the caret is on can be shaded" begin
  caret!(3, 0)   # an empty line, with an empty line under it
  p = pixels()
  @test p[950, middle(3)] == p[950, middle(5)]   # no shade yet
  K.shade!(e, true)
  p = pixels()
  @test p[950, middle(3)] != p[950, middle(5)]
  @test p[10, middle(3)] != p[10, middle(5)]   # it goes across the numbers too
  shot("shade")
  # There's none while text is selected
  e.buf.anchor = (4, 3); frames()
  p = pixels()
  @test p[950, middle(3)] == p[950, middle(5)]
  caret!(3, 0)
  K.shade!(e, false)
  p = pixels()
  @test p[950, middle(3)] == p[950, middle(5)]
end

@testset "a faint line down a file of code shows where a line gets too long" begin
  y = 600   # under the last line
  K.guide!(e, 80); frames()
  x = K.num(e.origin[1] + K.measure(K.face(e, K.kinds(e.buf)[1]), "0") * 80)
  p = pixels()
  @test any(i -> p[i, y] != p[i + 40, y], floor(Int, x):ceil(Int, x))
  @test any(i -> p[i, middle(5)] != p[i + 40, middle(5)], floor(Int, x):ceil(Int, x))   # beside the lines too
  shot("guide")
  K.guide!(e, 0); frames()
  p = pixels()
  @test all(i -> p[i, y] == p[i + 40, y], floor(Int, x):ceil(Int, x))
  @test_throws ErrorException K.guide!(e, 81)
end

@testset "code can be bigger or smaller, and its lines are further apart when it's bigger" begin
  before = K.item(e, 1).tall
  @test K.num(K.face(e, K.kinds(e.buf)[1]).size) ≈ 17 * K.CODE_SCALE
  K.code_size!(e, 22); frames()
  @test K.num(K.face(e, K.kinds(e.buf)[1]).size) ≈ 22
  @test K.item(e, 1).tall > before
  shot("big code")
  # It grows with the page's text
  K.zoom!(e, 2.0); frames()
  @test K.num(K.face(e, K.kinds(e.buf)[1]).size) ≈ 44
  K.zoom!(e, 1.0); K.code_size!(e, 17 * K.CODE_SCALE); frames()
  @test K.item(e, 1).tall ≈ before
  # A code block on a page is that size too, and the page's text isn't
  K.open!(e, notes); frames()
  i = findfirst(==(LONG), e.buf.lines)
  K.code_size!(e, 20); frames()
  @test K.num(K.face(e, K.kinds(e.buf)[i]).size) ≈ 20
  @test K.num(K.face(e, K.kinds(e.buf)[1]).size) ≈ 17 * K.HEADINGS[1]
  K.code_size!(e, 17 * K.CODE_SCALE)
  K.open!(e, file); frames()
end

@testset "one step of indentation in code is 2 or 4 spaces" begin
  b = e.buf
  caret!(5, 0)
  typed("function f(x)")
  key(Keys.enter)
  @test b.lines[6] == "  " && b.caret == (6, 2)
  key(Keys.backspace)   # takes away a step of spaces
  @test b.lines[6] == "" && b.caret == (6, 0)
  key(Keys.backspace)
  @test b.lines[5] == "function f(x)" && b.caret == (5, 13)
  K.indent_width!(e, 4); frames()
  key(Keys.enter)
  @test b.lines[6] == "    " && b.caret == (6, 4)
  key(Keys.tab)
  @test b.caret == (6, 8)
  key(Keys.backspace)
  @test b.caret == (6, 4)
  typed("x")
  key(Keys.tab, Keys.shft)
  @test b.lines[6] == "x"
  key(Keys.tab)   # with no selection, Tab goes to the next step
  @test b.lines[6] == "x   " && b.caret == (6, 4)
  # The rest of a long line starts one step further in
  f = long()
  space = K.measure(K.face(e, K.kinds(b)[2]), " ")
  @test all(vl -> isapprox(K.num(vl.x), 6K.num(space), atol=0.01), f.lines[2:end])
  @test_throws ErrorException K.indent_width!(e, 3)
  K.indent_width!(e, 2); frames()
end

@testset "the settings of code go to the settings file, and back" begin
  home = mktempdir()
  withenv("HOME" => home) do
    e.remember = true
    K.numbers!(e, false); K.shade!(e, true); K.indent_width!(e, 4); K.guide!(e, 92); K.code_size!(e, 20)
    saved = read(K.settings_file(), String)
    @test all(occursin(saved), ("numbers=false", "shade=true", "indent=4", "guide=92", "code="))
    o = K.load_settings!(K.Editor())
    @test !o.numbers && o.shade && o.indent == 4 && o.guide == 92 && o.code_scale ≈ 20 / 17
    K.numbers!(e, true); K.shade!(e, false); K.indent_width!(e, 2); K.guide!(e, 0); K.code_size!(e, 17 * K.CODE_SCALE)
    o = K.load_settings!(K.Editor())
    @test o.numbers && !o.shade && o.indent == 2 && o.guide == 0 && o.code_scale ≈ K.CODE_SCALE
    # A file with values that make no sense keeps the usual ones
    write(K.settings_file(), "indent=3\nguide=-5\ncode=nope\n")
    o = K.load_settings!(K.Editor())
    @test o.indent == 2 && o.guide == 0 && o.code_scale == K.CODE_SCALE
    e.remember = false
  end
end

@testset "code can be in any font whose letters are all one width" begin
  fonts = K.code_fonts()
  @test fonts[1] == K.CODE_FONT   # the usual one is first
  @test "Menlo" in fonts && "Courier New" in fonts
  @test !("Helvetica" in fonts) && !any(f -> startswith(f, '.'), fonts[2:end])
  @test K.installed_weight("No Such Font", 400) == 0
  @test_throws ErrorException K.code_font!(e, "No Such Font")
  # Menlo has no light weight, so code is in its usual one
  K.code_font!(e, "Menlo"); frames()
  f = K.face(e, K.kinds(e.buf)[1])
  @test (f.family, f.style) == ("Menlo", "")
  @test all(vl -> all(seg -> seg.face.family == "Menlo", vl.segs), long().lines)
  @test K.outcome_face(12px).family == "Menlo"
  @test K.codeslant() == "Italic"
  shot("menlo")
  # A font with a light weight is in that weight, as SF Mono is
  if K.CODE_FONT == ".SF NS Mono"
    K.code_font!(e, K.CODE_FONT); frames()
    @test (K.face(e, K.kinds(e.buf)[1]).family, K.codestyle()) == (".SF NS Mono", "Light")
    @test K.font_label(".SF NS Mono") == "SF Mono" && K.font_family("SF Mono") == ".SF NS Mono"
  end
  # A code block on a page is in the font too, and so is code in a sentence
  K.code_font!(e, "Courier New")
  K.open!(e, notes); frames()
  i = findfirst(==(LONG), e.buf.lines)
  @test K.face(e, K.kinds(e.buf)[i]).family == "Courier New"
  @test K.face(K.body(e), K.Span(0, "x", false, false, true, false, "", false, false)).family == "Courier New"
  K.open!(e, file); frames()
  # Another window keeps its own font as it draws
  o = K.build_editor(file)
  ow = Window(o, size=(600px, 400px))
  frame(ow)
  @test K.codefont() == K.CODE_FONT
  frames()
  @test K.codefont() == "Courier New"
  home = mktempdir()
  withenv("HOME" => home) do
    e.remember = true
    K.code_font!(e, "Menlo")
    @test occursin("codefont=Menlo", read(K.settings_file(), String))
    @test K.load_settings!(K.Editor()).code_font == "Menlo"
    write(K.settings_file(), "codefont=No Such Font\n")
    @test K.load_settings!(K.Editor()).code_font == K.CODE_FONT
    e.remember = false
  end
  K.code_font!(e, K.CODE_FONT); frames()
end

@testset "a font that comes in copies is in the list of fonts once, and a font of pictures isn't in it" begin
  # The Mac that runs this may have none of them, so the list is made from names here
  found = ["MesloLGS Nerd Font", "MesloLGS Nerd Font Mono", "MesloLGS Nerd Font Propo", "Hack Nerd Font Mono",
           "Monaspace Neon", "Monaspace Neon Var", "Recursive Var", "Menlo", "Mono"]
  @test K.once_each(found) == ["MesloLGS Nerd Font", "Hack Nerd Font Mono", "Monaspace Neon", "Recursive Var", "Menlo", "Mono"]
  @test K.once_each(K.code_fonts()) == K.code_fonts()
  @test !any(in(K.PICTURE_FONTS), K.code_fonts())
end
