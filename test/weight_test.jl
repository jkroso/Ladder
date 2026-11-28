# Tests for the weights of the page's text and of code: the weights that a
# font has, how bold text and headings are heavier than the rest, the settings
# pages that choose the weights, and the settings file. See "the weights of the
# page's text and of code" in main.jl. Run them with `julia -O0
# --project=. test/weight_test.jl`. They use windows that aren't on the screen, and they don't
# write the settings file. With LADDER_SHOTS set to a folder, they save
# pictures of the page there.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame draw scene
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use Skia
@use "./drive" drive
const px = K.px

const dir = mktempdir()
const file = joinpath(dir, "notes.md")
write(file, """
# A heading with **bold** in it

Plain words, **bold words**, *slanted words* and ***both***.

> A quote, and **bold** in it.

- An item of a list
""")
const code_page = joinpath(dir, "code.md")
write(code_page, """
Some `inline` code.

```julia
x = 1   # a comment
```
""")

const e = K.build_editor(file)
const w = Window(e, size=(900px, 600px))
const (; frames, shot) = drive(w)
# The caret goes on the last line, which is empty, so the other lines hide their markup
e.buf.caret = e.buf.anchor = (length(e.buf.lines), 0)
frames()

"The style of each run of text in line `i` of the page, as it was laid out"
styles(i) = [seg.face.style for vl in K.item(e, i).content.lines for seg in vl.segs if !isempty(strip(seg.text))]
"The style of the first run of text in line `i` that has the word `word`"
style_of(i, word) = first(seg.face.style for vl in K.item(e, i).content.lines for seg in vl.segs if occursin(word, seg.text))

"How much ink the window's text has: the sum, over its pixels, of how much darker each is than the page"
ink() = begin
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
  green(p) = Int((p >> 8) & 0xff)
  page = green(out[W - 5, H - 5])   # a corner of the window has no text
  sum(p -> max(0, page - green(p)), out[:, 150:end])   # under the heading, which is bold in every weight
end

"The names of the weights of `family` that text can be in"
labels(family) = [w.label for w in K.text_weights(family)]

@testset "a font's weights for text are the ones that it has, up to Semibold, by its own names" begin
  # Helvetica Neue's UltraLight is lighter than its Thin
  @test labels("Helvetica Neue") == ["UltraLight", "Thin", "Light", "Regular", "Medium"]
  @test [w.weight for w in K.text_weights("Helvetica Neue")] == [100, 200, 300, 400, 500]
  @test labels("Charter") == ["Roman"]
  @test K.text_weights("Charter")[1].style == ""   # the usual face draws as it did before there were weights
  # The Mac hides the faces of its own font, so it has the weights that it draws for 100, 200 and so on
  K.SANS == ".SF NS" && @test labels(K.SANS) == ["Thin", "Extra light", "Light", "Regular", "Medium", "Semibold"]
  # A font without the weight draws its nearest one. Of two as near, it's the one nearer to Regular.
  @test K.nearest_weight("Charter", 300).weight == 400
  @test K.nearest_weight("Charter", 500).weight == 400
  @test K.nearest_weight("Charter", 600).weight == 400   # not its bold weight, which is nearer
  @test K.nearest_weight("Helvetica Neue", 600).label == "Medium"
  @test K.nearest_weight("No Such Font", 300).weight == 300
  @test K.text_weights("No Such Font") == []
  # The Mac says that Fira Code's Light weighs 342, and it's in the list by its name
  "Fira Code" in K.code_fonts() && @test labels("Fira Code") == ["Light", "Regular", "Retina", "Medium", "SemiBold"]
end

@testset "the usual weight draws the page as it was before there was a setting" begin
  @test e.weight == 400
  @test K.body(e).style == ""
  @test all(==("Bold"), styles(1))   # a heading, and bold in it
  @test style_of(3, "Plain") == ""
  @test style_of(3, "bold") == "Bold"
  @test style_of(3, "slanted") == "Italic"
  @test style_of(3, "both") == "Bold Italic"
  @test style_of(5, "quote") == "Italic"
  @test style_of(5, "bold") == "Bold Italic"
end

@testset "light text has bold words and headings in bold, and takes less ink" begin
  K.font!(e, "Helvetica Neue"); frames()
  regular = ink()
  shot("regular")
  K.weight!(e, "Light"); frames()
  @test e.weight == 300
  @test K.body(e).style == "Light"
  @test style_of(3, "Plain") == "Light"
  @test style_of(3, "bold") == "Bold"
  @test style_of(3, "slanted") == "Light Italic"
  @test style_of(3, "both") == "Bold Italic"
  @test all(==("Bold"), styles(1))
  @test style_of(5, "quote") == "Light Italic"
  @test style_of(5, "bold") == "Bold Italic"
  light = ink()
  shot("light")
  @test light < 0.9regular
  # Helvetica Neue has no Semibold. Medium and Bold are as near, and Medium is nearer to Regular.
  K.weight!(e, 600); frames()
  @test style_of(3, "Plain") == "Medium"
  @test style_of(3, "bold") == "Bold"
  # Semibold text has its bold words in Extra bold, so that they still stand out
  if K.SANS == ".SF NS"
    K.font!(e, K.SANS); frames()
    @test style_of(3, "Plain") == "SemiBold"
    @test style_of(3, "bold") == "ExtraBold"
    @test all(==("ExtraBold"), styles(1))
    K.font!(e, "Helvetica Neue")
  end
  K.weight!(e, 400); frames()
  @test ink() ≈ regular rtol=0.001
end

@testset "a font without the weight draws its nearest one, and keeps the weight for the next font" begin
  K.font!(e, "Helvetica Neue"); K.weight!(e, 300); frames()
  thin = K.measure(K.body(e), "Plain words")
  K.font!(e, "Charter"); frames()
  @test e.weight == 300
  @test K.measure(K.body(e), "Plain words") == K.measure(K.Face(K.body(e), style=""), "Plain words")   # Charter Regular
  K.font!(e, "Helvetica Neue"); frames()
  @test K.measure(K.body(e), "Plain words") == thin
  K.weight!(e, 400)
end

@testset "only the weights of the font up to Semibold can be chosen" begin
  @test_throws ErrorException K.weight!(e, 700)
  @test_throws ErrorException K.weight!(e, 0)
  @test_throws ErrorException K.weight!(e, "Heavy")
  @test_throws ErrorException K.weight!(e, "Bold")
  @test e.weight == 400
end

@testset "the weight goes to the settings file, and back" begin
  home = mktempdir()
  withenv("HOME" => home) do
    e.remember = true
    K.weight!(e, 200)
    @test occursin("weight=200", read(K.settings_file(), String))
    @test K.load_settings!(K.Editor()).weight == 200
    # A file with a weight that makes no sense keeps the usual one
    for bad in ("weight=700", "weight=0", "weight=light", "weight=")
      write(K.settings_file(), bad * "\n")
      @test K.load_settings!(K.Editor()).weight == 400
    end
    e.remember = false
    K.weight!(e, 400)
  end
end

"The first node of type `T` in `node`, or in the nodes it holds"
find(T, node, seen=IdDict()) = begin
  node isa T && return node
  (isbits(node) || node isa Union{AbstractString,Module,Function,Type} || haskey(seen, node)) && return nothing
  seen[node] = true
  if node isa Union{AbstractArray,Tuple,AbstractDict}
    for x in values(node)
      (f = find(T, x, seen)) === nothing || return f
    end
    return nothing
  end
  for name in fieldnames(typeof(node))
    isdefined(node, name) || continue
    (f = find(T, getfield(node, name), seen)) === nothing || return f
  end
  nothing
end

@testset "the settings page lists the font's weights, and shows a sentence for a font with one" begin
  page = K.settings_page()
  text = read(page, String)
  code = String(only(m[1] for m in eachmatch(r"## Font weight\n\n```ui\n(.*?)```"s, text)))
  s = K.build_editor(page)
  K.font!(s, "Helvetica Neue"); K.weight!(s, 300)
  sw = Window(s, size=(720px, 2600px))
  empty!(K.problems)
  foreach(_ -> frame(sw), 1:3)
  @test isempty(K.problems)
  run(code) = include_string(K.sandbox(s), code)
  @test run("page_weights()") == ["UltraLight", "Thin", "Light", "Regular", "Medium"]
  @test run("page_weight()") == "Light"
  Dropdown = run("Dropdown")
  d = find(Dropdown, K.evaluate(s, code))
  @test d.options == ["UltraLight", "Thin", "Light", "Regular", "Medium"] && d.selected == 3
  # The dropdown's choice changes the weight of the text
  run("page_weight!(\"Medium\")")
  @test s.weight == 500
  # Charter has one weight for text, so the page says so
  K.font!(s, "Charter")
  @test run("page_weights()") == ["Roman"]
  @test run("page_weight()") == "Roman"
  node = K.evaluate(s, code)
  @test find(Dropdown, node) === nothing
  @test occursin("Charter has one weight for text: Roman.", find(K.Text, node).content)
  foreach(_ -> frame(sw), 1:3)
  @test isempty(K.problems)
  K.font!(s, K.SERIF); K.weight!(s, 400)
  close(sw)
end

@testset "code starts in Light, and can be in any weight that its font has" begin
  K.open!(e, code_page)
  e.buf.caret = e.buf.anchor = (length(e.buf.lines), 0)
  frames()
  i = findfirst(startswith("x = 1"), e.buf.lines)
  @test e.code_weight == 300
  K.code_font!(e, "Menlo"); frames()
  @test K.codestyle() == ""                       # Menlo has no light weight, so code is in its regular one
  @test labels("Menlo") == ["Regular"]
  if K.CODE_FONT == ".SF NS Mono"
    K.code_font!(e, K.CODE_FONT); frames()
    @test K.codestyle() == "Light"
    @test labels(K.CODE_FONT) == ["Light", "Regular", "Medium", "Semibold"]
    @test style_of(i, "x") == "Light"
    @test style_of(i, "comment") == "Light Italic"
    @test style_of(1, "inline") == "Light"
    shot("code light")
    K.code_weight!(e, "Medium"); frames()
    @test e.code_weight == 500
    @test K.codestyle() == "Medium" && K.codeslant() == "Medium Italic"
    @test style_of(i, "x") == "Medium"
    @test style_of(i, "comment") == "Medium Italic"
    @test style_of(1, "inline") == "Medium"
    @test style_of(1, "Some") == ""                # the page's text keeps its own weight
    shot("code medium")
    # SF Mono has no Thin, so code is in its lightest weight, Light
    K.code_weight!(e, 100); frames()
    @test K.codestyle() == "Light"
    # Another window keeps its own weight as it draws
    o = K.build_editor(code_page)
    ow = Window(o, size=(600px, 400px))
    K.code_weight!(e, 600)
    frame(ow)
    @test K.codestyle() == "Light"
    frames()
    @test K.codestyle() == "SemiBold"
    close(ow)
    # A font without the weight keeps it for the next font that has it
    K.code_font!(e, "Menlo"); frames()
    @test K.codestyle() == "" && e.code_weight == 600
    K.code_font!(e, K.CODE_FONT); frames()
    @test K.codestyle() == "SemiBold"
  end
  @test_throws ErrorException K.code_weight!(e, 700)
  @test_throws ErrorException K.code_weight!(e, "Black")
  K.code_weight!(e, 300); K.code_font!(e, K.CODE_FONT)
  K.open!(e, file); frames()
end

@testset "each weight of Source Code Pro draws its own face, though Ladder reads one of its files itself" begin
  if "Source Code Pro" in K.code_fonts()
    # The Mac says its ExtraLight weighs 300 and its Light 342, so asking for 300 by number would get ExtraLight
    @test labels("Source Code Pro") == ["ExtraLight", "Light", "Regular", "Medium", "Semibold"]
    K.open!(e, code_page)
    e.buf.caret = e.buf.anchor = (length(e.buf.lines), 0)
    K.code_font!(e, "Source Code Pro")
    used = map(["ExtraLight", "Light", "Regular", "Medium", "Semibold"]) do name
      K.code_weight!(e, name); frames()
      shot("source code pro " * name)
      (K.codestyle(), ink())
    end
    @test first.(used) == ["ExtraLight", "Light", "", "Medium", "Semibold"]
    @test issorted(last.(used)) && allunique(last.(used))   # each is heavier than the one before
    K.code_weight!(e, 300); K.code_font!(e, K.CODE_FONT)
    K.open!(e, file); frames()
  end
end

@testset "the weight of code goes to the settings file, and back" begin
  home = mktempdir()
  withenv("HOME" => home) do
    e.remember = true
    K.code_weight!(e, 500)
    @test occursin("codeweight=500", read(K.settings_file(), String))
    @test K.load_settings!(K.Editor()).code_weight == 500
    for bad in ("codeweight=800", "codeweight=x")
      write(K.settings_file(), bad * "\n")
      @test K.load_settings!(K.Editor()).code_weight == 300
    end
    e.remember = false
    K.code_weight!(e, 300)
  end
end

@testset "the code editor page lists the code font's weights" begin
  page = K.settings_page("code-editor.md")
  code = String(only(m[1] for m in eachmatch(r"## Code weight\n\n```ui\n(.*?)```"s, read(page, String))))
  s = K.build_editor(page)
  sw = Window(s, size=(720px, 2600px))
  empty!(K.problems)
  foreach(_ -> frame(sw), 1:3)
  @test isempty(K.problems)
  run(code) = include_string(K.sandbox(s), code)
  Dropdown = run("Dropdown")
  if K.CODE_FONT == ".SF NS Mono"
    @test run("code_weights()") == ["Light", "Regular", "Medium", "Semibold"]
    @test run("code_weight()") == "Light"
    d = find(Dropdown, K.evaluate(s, code))
    @test d.options == ["Light", "Regular", "Medium", "Semibold"] && d.selected == 1
    run("code_weight!(\"Regular\")")
    @test s.code_weight == 400
  end
  # Menlo has one weight for code, so the page says so
  K.code_font!(s, "Menlo")
  node = K.evaluate(s, code)
  @test find(Dropdown, node) === nothing
  @test occursin("Menlo has one weight for code: Regular.", find(K.Text, node).content)
  foreach(_ -> frame(sw), 1:3)
  @test isempty(K.problems)
  K.code_font!(s, K.CODE_FONT); K.code_weight!(s, 300)
  close(sw)
end
