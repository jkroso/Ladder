# Tests for the `gallery` block of main.jl: the files of a folder as a grid of
# small squares. Run them with `julia -O0 --project=. test/gallery_view_test.jl`.
# They click and press keys in a window that isn't on the screen. The pictures
# are small PNG files that the tests write into a temporary folder, with a PDF
# file, a video, a 3D model, a page, code and a folder. Set `LADDER_SHOTS` to a
# folder, and they save a picture of each step there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/testing" pixels
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
const px = K.px
const G = K.Galleries

# --- a PNG file from its colours ---------------------------------------------------------

const CRC = [foldl((c, _) -> isodd(c) ? 0xedb88320 ⊻ (c >> 1) : c >> 1, 1:8, init=UInt32(n)) for n in 0:255]
crc(bytes) = ~foldl((c, b) -> CRC[(c ⊻ b) & 0xff + 1] ⊻ (c >> 8), bytes, init=0xffffffff)
adler(bytes) = begin
  a, b = 1, 0
  for x in bytes
    a = (a + x) % 65521
    b = (b + a) % 65521
  end
  UInt32(b) << 16 | UInt32(a)
end
be(n) = reverse(reinterpret(UInt8, [UInt32(n)]))
chunk(kind, data) = UInt8[be(length(data)); codeunits(kind); data; be(crc(UInt8[codeunits(kind); data]))]

"Write a PNG file that's `w` pixels wide and `h` tall. `colour(x, y)` gives the red, green and blue of each pixel."
write_png(path, w, h, colour) = begin
  raw = UInt8[]
  for y in 1:h
    push!(raw, 0x00)
    for x in 1:w
      append!(raw, UInt8.(colour(x, y)))
    end
  end
  # The pixels go in as they are, in parts of no more than 65535 bytes
  packed = UInt8[0x78, 0x01]
  parts = collect(Iterators.partition(raw, 65535))
  for (k, part) in enumerate(parts)
    n = UInt16(length(part))
    append!(packed, UInt8[k == length(parts), n & 0xff, n >> 8, ~n & 0xff, ~n >> 8])
    append!(packed, part)
  end
  append!(packed, be(adler(raw)))
  mkpath(dirname(path))
  write(path, UInt8[0x89; codeunits("PNG\r\n"); 0x1a; 0x0a; chunk("IHDR", UInt8[be(w); be(h); 8; 2; 0; 0; 0]);
                    chunk("IDAT", packed); chunk("IEND", UInt8[])])
  path
end

"Write a PDF file with `n` empty pages, each 200 by 300 points"
write_pdf(path, n) = begin
  objects = ["<< /Type /Catalog /Pages 2 0 R >>", "<< /Type /Pages /Kids [$(join(("$(2 + k) 0 R" for k in 1:n), " "))] /Count $n >>"]
  # Every page draws the one empty stream of drawing, which is the last object
  append!(objects, fill("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 200 300] /Contents $(n + 3) 0 R >>", n))
  push!(objects, "<< /Length 0 >>\nstream\n\nendstream")
  io = IOBuffer()
  print(io, "%PDF-1.4\n")
  places = Int[]
  for (k, o) in enumerate(objects)
    push!(places, position(io))
    print(io, "$k 0 obj\n$o\nendobj\n")
  end
  table = position(io)
  print(io, "xref\n0 $(length(objects) + 1)\n0000000000 65535 f \n")
  foreach(at -> print(io, lpad(at, 10, '0'), " 00000 n \n"), places)
  print(io, "trailer\n<< /Size $(length(objects) + 1) /Root 1 0 R >>\nstartxref\n$table\n%%EOF\n")
  mkpath(dirname(path))
  write(path, take!(io))
  path
end

const RED, GREEN, BLUE, SAND = (200, 40, 40), (40, 160, 70), (50, 90, 200), (210, 180, 120)
plain(c) = (x, y) -> c

# --- the page ----------------------------------------------------------------------------

const dir = mktempdir()
const photos = joinpath(dir, "photos")
write_png(joinpath(photos, "photo 1.png"), 120, 90, plain(BLUE))
write_png(joinpath(photos, "photo 2.png"), 90, 120, plain(SAND))
# A wide picture that's red at both ends and green in the middle. Its square shows only the green.
write_png(joinpath(photos, "photo 3 wide.png"), 300, 100, (x, y) -> 100 < x <= 200 ? GREEN : RED)
write_png(joinpath(photos, "photo 10.png"), 64, 64, (x, y) -> (4x - 1, 4y - 1, 120))
write(joinpath(photos, "photo 4 broken.png"), "This file isn't a picture.")
mkpath(joinpath(dir, "empty"))
# A folder with every kind of file
const mixed = joinpath(dir, "mixed")
write_png(joinpath(mixed, "a shot.png"), 80, 60, plain(BLUE))
write_pdf(joinpath(mixed, "b plan.pdf"), 3)
cp(joinpath(K.pages_dir[], "knot.mp4"), joinpath(mixed, "c knot.mp4"))
cp(joinpath(K.pages_dir[], "knot.stl"), joinpath(mixed, "d knot.stl"))
write(joinpath(mixed, "e notes.md"), "# Notes\n\nNot a picture.\n")
write(joinpath(mixed, "f code.jl"), "f(x) = x + 1\n")
mkpath(joinpath(mixed, "inner"))
write_png(joinpath(dir, "plans", "front.png"), 80, 60, plain(RED))
for k in 1:300
  write_png(joinpath(dir, "many", "shot $k.png"), 8, 8, plain((k % 256, 120, 200)))
end
const page = joinpath(dir, "job.md")
write(page, """
# A job

```gallery
in: photos
```

```gallery
in: nowhere
```

```gallery
in: empty
```

```gallery
plans/front.png
photos/photo 2.png
plans/gone.png
```

```gallery
in: mixed
```

The end.
""")
const long = joinpath(dir, "long.md")
write(long, "# Many\n\n```gallery\nin: many\nsize: small\n```\n\nThe end.\n")

const e = K.build_editor(page)
const w = Window(e, size=(1000px, 900px))
frames(n=2) = foreach(_ -> frame(w), 1:n)
"Draw frames until the galleries of the page have the small pictures that they show"
settle() = for _ in 1:400
  frames(1)
  any(n -> n isa K.GalleryView && !isempty(n.wanted), values(e.nodes)) || return frames()
end
settle()
gallery(n, path=page) = e.nodes[(:block, K.GALLERY, path, n)]
const v = gallery(1)
const shots = get(ENV, "LADDER_SHOTS", "")
shot(name) = isempty(shots) || save_png(joinpath(shots, name), w)

at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)); frames(1))
press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
click(place) = (press(place); release())
key(k) = (onkey(w, KeyPress{k}(0, w)); frames())
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
block(n=1) = (s = K.block_lines(e.buf, K.GALLERY, n); e.buf.lines[s[1]+1:s[2]-1])
thumb(i, of=v) = of.parts[(:thumb, i)]
names(of=v) = [p.name for p in K.found!(of).items]
"The colour of the window's picture at a place in the window, as red, green and blue"
colour_at((x, y)) = begin
  file = joinpath(dir, "window.png")
  save_png(file, w)
  ps = pixels(file)
  k = size(ps, 2) / K.num(K.window_size(e)[1])   # the picture's pixels to a px of the window
  p = ps[round(Int, y * k), round(Int, x * k)]
  (Int(p >> 16 & 0xff), Int(p >> 8 & 0xff), Int(p & 0xff))
end
near(a, b) = all(abs.(a .- b) .< 30)
"The words that `r` shows: a part of the window as it was last drawn"
said(r) = r === nothing ? String[] : hasproperty(r, :lines) ? [join(r.lines, " ")] : reduce(vcat, (said(c) for c in r.children), init=String[])

@testset "the gallery shows the pictures of its folder in a grid" begin
  @test names() == ["photo 1.png", "photo 2.png", "photo 3 wide.png", "photo 4 broken.png", "photo 10.png"]
  rs = [rect(thumb(i)) for i in 1:5]
  @test all(r -> r !== nothing, rs)
  # Squares in a row, each as big as the next, with the same gap between them
  @test all(r -> r.width ≈ v.side && r.height ≈ v.side, rs) && K.num(v.side) >= G.SIDES.medium
  @test all(r -> r.top == rs[1].top, rs)
  @test all(k -> K.num(rs[k+1].left - rs[k].left - rs[k].width) ≈ G.GAP, 1:4)
  # The grid takes all the room that the block has
  g = G.grid(5, K.num(e.width) - 2 - 2K.num(K.GALLERY_PAD), :medium)
  @test K.num(v.side) ≈ g.side && g.columns == 5
  # Each picture that can be read has a small picture that fills its square. The file that can't has the Finder's icon.
  smalls = [K.small(v, p) for p in K.found!(v).items]
  @test all(s -> s isa NamedTuple, smalls) && [s.fills for s in smalls] == [true, true, true, false, true]
  # macOS made them, as it does for the Finder
  @test startswith(smalls[1].key, "thumbnail:") && startswith(smalls[4].key, "icon:")
  # Only the square whose picture doesn't fill it has its name
  @test said(rect(thumb(4))) == ["photo 4 broken.png"] && isempty(said(rect(thumb(1))))
  shot("gallery.png")
  # A square shows the middle of its picture: the wide one shows no red, from edge to edge
  r = rs[3]
  @test near(colour_at(middle(r)), GREEN)
  @test near(colour_at((K.num(r.left) + 3, K.num(r.top + r.height / 2))), GREEN)
  @test near(colour_at((K.num(r.left + r.width) - 3, K.num(r.top + r.height / 2))), GREEN)
  @test near(colour_at(middle(rs[1])), BLUE) && near(colour_at(middle(rs[2])), SAND)
  @test any(en -> en.title == "Gallery", K.outline(e.buf)) && any(x -> x isa Tuple && x[1] == "Gallery", K.INSERTS)
  @test !K.dirty(e.buf)
end

@testset "the mouse over a picture shows its file's name" begin
  at(middle(rect(thumb(2))))
  @test any(p -> p.key == :tooltip, popups(w))
  shot("gallery-tooltip.png")
  at((5, 5))
end

@testset "the button at the top changes the size" begin
  b = v.parts[(:button, :size)]
  @test b.words == "Medium" && b.tip == "Make the squares large"
  click(middle(rect(b))); settle()
  @test block() == ["in: photos", "size: large"] && b.words == "Large" && K.num(v.side) >= G.SIDES.large
  @test rect(thumb(4)).top > rect(thumb(1)).top   # fewer squares fit in a row
  shot("gallery-large.png")
  click(middle(rect(b))); settle()
  @test block() == ["in: photos", "size: small"] && K.num(v.side) < G.SIDES.medium
  # ⌘Z takes each change back
  K.undo!(e.buf); settle()
  @test block() == ["in: photos", "size: large"] && v.data.size == :large
  K.undo!(e.buf); settle()
  @test block() == ["in: photos"] && v.data.size == :medium && !K.dirty(e.buf)
end

@testset "a click makes a picture fill the window, and the arrows go to the others" begin
  shows() = (z = K.zooming(e); z === nothing ? nothing : basename(z.what[2]))
  click(middle(rect(thumb(2))))
  @test shows() == "photo 2.png" && K.zooming(e).from === v
  shot("gallery-zoom.png")
  key(Keys.right)
  @test shows() == "photo 3 wide.png"
  # The file that can't be read as a picture is passed over
  key(Keys.right)
  @test shows() == "photo 10.png"
  # The last picture stays
  key(Keys.right)
  @test shows() == "photo 10.png"
  key(Keys.left); key(Keys.left); key(Keys.left); key(Keys.left)
  @test shows() == "photo 1.png"
  # Esc puts the gallery back, and the text has the keyboard
  key(Keys.escape)
  @test K.zooming(e) === nothing && w.focus === e && rect(thumb(1)) !== nothing
  # A click on the file that can't be read as a picture opens it, as a link to it does
  click(middle(rect(thumb(4))))
  @test K.zooming(e) === nothing && e.buf.path == joinpath(photos, "photo 4 broken.png") && !K.dirty(e.buf)
  K.open!(e, page); settle()
  @test e.buf.path == page
end

@testset "the bar under a picture says where it is, and has a button to each side" begin
  z() = K.zooming(e)
  button(k) = z().parts[(:button, k)]
  bar() = said(rect(z()))
  shows() = basename(z().what[2])
  click(middle(rect(thumb(1))))
  # The first picture: its place and its name. The button for the picture before is faint and does nothing.
  @test "1 of 5" in bar() && "photo 1.png" in bar()
  @test button(:before).off && !button(:next).off
  @test button(:before).tip == "The file before  ←" && button(:next).tip == "The next file  →"
  # The two buttons are at the start of the bar, before the buttons that make the picture bigger and smaller
  @test rect(button(:before)).left < rect(button(:next)).left < rect(button(:smaller)).left
  click(middle(rect(button(:before))))
  @test shows() == "photo 1.png"
  shot("gallery-bar-first.png")
  click(middle(rect(button(:next))))
  @test shows() == "photo 2.png" && "2 of 5" in bar() && "photo 2.png" in bar() && !button(:before).off && !button(:next).off
  shot("gallery-bar.png")
  # The new picture is fitted to the window, however big the last one was
  K.zoom_by!(z(), 3.0, K.view_middle(z())...); frames()
  @test !z().fits
  click(middle(rect(button(:next))))
  @test shows() == "photo 3 wide.png" && z().fits && z().zoom ≈ K.fit_zoom(z(), K.subject_size(z()))
  # The file that isn't a picture is passed over. At the last picture, the button for the next one is faint.
  click(middle(rect(button(:next))))
  @test shows() == "photo 10.png" && "5 of 5" in bar() && "photo 10.png" in bar() && button(:next).off && !button(:before).off
  shot("gallery-bar-last.png")
  click(middle(rect(button(:next))))
  @test shows() == "photo 10.png"
  click(middle(rect(button(:before))))
  @test shows() == "photo 3 wide.png" && "3 of 5" in bar()
  # The keys still work
  key(Keys.left)
  @test shows() == "photo 2.png" && "2 of 5" in bar()
  key(Keys.right)
  @test shows() == "photo 3 wide.png"
  # A large arrow shows at an edge of the window while the mouse is near that edge
  arrow(by) = get(z().parts, (:edge, by), nothing)
  shown(by) = (a = arrow(by); a !== nothing && rect(a) !== nothing)
  W, H = K.num.(K.window_size(e))
  at((W / 2, H / 2))
  @test !shown(-1) && !shown(1)
  at((W - 40, H / 2))
  @test shown(1) && !shown(-1)
  r = rect(arrow(1))
  @test K.num(r.left + r.width) < W && abs(middle(r)[2] - K.view_middle(z())[2]) < 2
  shot("gallery-edge.png")
  # A click on it goes to the next picture. The last picture has no arrow at the right.
  click(middle(r))
  @test shows() == "photo 10.png" && !shown(1)
  at((40, H / 2))
  @test shown(-1) && !shown(1)
  click(middle(rect(arrow(-1))))
  @test shows() == "photo 3 wide.png"
  # A drag still moves a picture that's bigger than the window
  K.zoom_by!(z(), 3.0, K.view_middle(z())...); frames()
  was, m = z().at, K.view_middle(z())
  press(m); at((m[1] - 60, m[2] - 20)); release()
  @test z().at[1] > was[1] && shows() == "photo 3 wide.png"
  key(Keys.escape)
  @test K.zooming(e) === nothing
end

@testset "a picture that isn't in a gallery has no place and no arrows" begin
  plain = joinpath(dir, "plain.md")
  write(plain, "# Plain\n\n![front](plans/front.png)\n\nThe end.\n")
  K.open!(e, plain); frames()
  p = only(n for n in values(e.nodes) if n isa K.Picture)
  K.fill_window!(e, (:picture, p.key), p); frames()
  z = K.zooming(e)
  @test z !== nothing && z.from === p && K.gallery_place(z) === nothing
  @test isempty(K.gallery_buttons(z)) && isempty(K.gallery_edges(z))
  @test !any(t -> occursin(r"^\d+ of \d+$", t), said(rect(z))) && !("front.png" in said(rect(z)))
  @test all(k -> rect(z.parts[(:button, k)]) === nothing, (:before, :next)) && rect(z.parts[(:button, :smaller)]) !== nothing
  at((K.num(K.window_size(e)[1]) - 40, 400))
  @test all(by -> rect(z.parts[(:edge, by)]) === nothing, (-1, 1))
  # ← and → do nothing to it
  key(Keys.right); key(Keys.left)
  @test K.zooming(e).what == (:picture, p.key)
  shot("gallery-plain.png")
  key(Keys.escape)
  K.open!(e, page); settle()
  at((5, 5))
end

@testset "a folder that isn't there, and one with nothing in it" begin
  @test K.found!(gallery(2)).problem == "There's no folder called “nowhere” beside this page."
  @test K.found!(gallery(3)).problem == "Nothing in empty"
  @test rect(gallery(2)) !== nothing && rect(gallery(3)) !== nothing
  @test isempty(gallery(2).parts) && isempty(gallery(3).parts)
end

@testset "a gallery that lists its files" begin
  l = gallery(4)
  @test names(l) == ["front.png", "photo 2.png"] && K.found!(l).lost == ["plans/gone.png"]
  @test rect(thumb(1, l)) !== nothing && rect(thumb(2, l)) !== nothing
  @test G.summary(l.data, K.found!(l)) == "2 pictures"
end

@testset "a gallery of every kind of file" begin
  x = gallery(5)
  z() = K.zooming(e)
  bar() = said(rect(z()))
  @test names(x) == ["a shot.png", "b plan.pdf", "c knot.mp4", "d knot.stl", "e notes.md", "f code.jl", "inner"]
  @test [p.kind for p in K.found!(x).items] == [:picture, :file, :file, :file, :file, :file, :folder]
  @test G.summary(x.data, K.found!(x)) == "6 files and 1 folder in mixed"
  # Both rows of its squares in the window
  show_gallery() = (e.scroll.offset = K.item(e, findall(==("```gallery"), e.buf.lines)[5]).top + 300px; frames(); settle())
  show_gallery()
  @test all(i -> K.num(rect(thumb(i, x)).top + rect(thumb(i, x)).height) < 900, 1:7)
  # A picture and a video fill their squares. The rest show the whole of their picture, with their name under it.
  smalls = [K.small(x, p) for p in K.found!(x).items]
  @test all(s -> s isa NamedTuple, smalls)
  @test [s.fills for s in smalls] == [true, false, true, false, false, false, false]
  @test isempty(said(rect(thumb(1, x)))) && isempty(said(rect(thumb(3, x))))
  @test said(rect(thumb(2, x))) == ["b plan.pdf"] && said(rect(thumb(6, x))) == ["f code.jl"] && said(rect(thumb(7, x))) == ["inner"]
  # The picture is in the square, above the name
  r = rect(thumb(2, x))
  inner = only(c for c in rect(thumb(2, x)).children[1].children)
  @test r.left < inner.left && inner.left + inner.width < r.left + r.width && r.top < inner.top && inner.top + inner.height < r.top + r.height - K.GALLERY_LABEL
  shot("gallery-kinds.png")
  # A click on the PDF file makes its first page fill the window. ↓ and ↑ turn its pages.
  click(middle(rect(thumb(2, x))))
  @test z().what == (:pdf, joinpath(mixed, "b plan.pdf"), 1) && z().from === x
  @test "2 of 7" in bar() && "b plan.pdf" in bar() && "Page 1 of 3" in bar()
  @test z().parts[(:button, :back)].tip == "The page before  ↑" && z().parts[(:button, :on)].tip == "The next page  ↓"
  key(Keys.down)
  @test z().page == 2 && "Page 2 of 3" in bar()
  key(Keys.up)
  @test z().page == 1
  shot("gallery-pdf.png")
  # → goes to the video, with its player. Its bar says where it is in the gallery.
  key(Keys.right)
  @test z().what[1] == :node && z().what[2] isa K.VideoPlayer && z().what[2].path == joinpath(mixed, "c knot.mp4")
  @test "3 of 7" in bar() && "c knot.mp4" in bar() && rect(z().parts[(:button, :before)]) !== nothing
  shot("gallery-video.png")
  player = z().what[2]
  # → goes to the 3D model, and the video's player has its own height again
  key(Keys.right)
  @test z().what[1] == :node && z().what[2] isa K.STLViewer && "4 of 7" in bar() && player.height == K.MODEL_HEIGHT
  # The page, the code and the folder don't fill the window, so the model is the last file that does
  @test z().parts[(:button, :next)].off
  key(Keys.right)
  @test z().what[2] isa K.STLViewer
  shot("gallery-model.png")
  # The arrow at the left edge goes back to the video, with the same player
  W, H = K.num.(K.window_size(e))
  at((40, H / 2))
  click(middle(rect(z().parts[(:edge, -1)])))
  @test z().what[2] === player
  key(Keys.left); key(Keys.left)
  @test z().what[1] == :picture && "1 of 7" in bar()
  key(Keys.escape)
  @test K.zooming(e) === nothing
  # A click on a page opens it, as a link to it does
  click(middle(rect(thumb(5, x))))
  @test e.buf.path == joinpath(mixed, "e notes.md") && K.zooming(e) === nothing
  K.open!(e, page); show_gallery()
  # A click on a folder shows it in the page, and the sidebar stays closed
  e.panel && K.toggle_panel!(e)
  click(middle(rect(thumb(7, x))))
  @test realpath(e.folder) == realpath(joinpath(mixed, "inner")) && realpath(e.buf.path) == realpath(joinpath(mixed, "inner"))
  @test !e.panel
  K.open!(e, page); K.go_folder!(e, dir)
  e.scroll.offset = 0px; settle()
end

@testset "a file that's dropped on a gallery goes into its folder" begin
  new = write_png(joinpath(dir, "elsewhere", "photo 5.png"), 60, 60, plain(GREEN))
  at(middle(rect(v)))
  K.onfiledrop(e, w, [new]); settle()
  @test isfile(joinpath(photos, "photo 5.png")) && isfile(new)
  @test names() == ["photo 1.png", "photo 2.png", "photo 3 wide.png", "photo 4 broken.png", "photo 5.png", "photo 10.png"]
  @test rect(thumb(6)) !== nothing && K.small(v, K.found!(v).items[5]).fills
  @test block() == ["in: photos"] && !K.dirty(e.buf)   # the page's text stays as it was
  # A drop on a gallery that lists its pictures adds a line, and the file stays where it is
  l = gallery(4)
  at(middle(rect(l)))
  K.onfiledrop(e, w, [new]); settle()
  @test block(4) == ["plans/front.png", "photos/photo 2.png", "plans/gone.png", "elsewhere/photo 5.png"]
  @test names(l) == ["front.png", "photo 2.png", "photo 5.png"] && !isfile(joinpath(dir, "plans", "photo 5.png"))
  K.undo!(e.buf); settle()
  @test length(block(4)) == 3
  # A file that isn't a picture goes into the gallery too, and so does a folder, with what's in it
  at(middle(rect(v)))
  K.onfiledrop(e, w, [joinpath(mixed, "e notes.md"), joinpath(mixed, "inner")]); settle()
  @test isfile(joinpath(photos, "e notes.md")) && isdir(joinpath(photos, "inner")) && isfile(joinpath(mixed, "e notes.md"))
  @test names()[1:2] == ["e notes.md", "inner"] && !any(l -> occursin("notes.md", l), e.buf.lines) && !K.dirty(e.buf)
  shot("gallery-dropped.png")
  rm(joinpath(photos, "e notes.md")); rm(joinpath(photos, "inner")); v.shown = nothing; settle()
  @test length(names()) == 6
end

@testset "the page as HTML, and on paper" begin
  html = K.page_html(e)
  @test occursin("<img src=\"photos/photo%201.png\" alt=\"photo 1\"", html) && occursin("<img src=\"plans/front.png\"", html)
  @test occursin("grid-template-columns", html) && count("<img ", html) == 9
  # A file that isn't a picture, and a folder, is a link with its name
  @test occursin(r"<a href=\"mixed/b%20plan.pdf\" style=\"[^\"]*\">b plan.pdf</a>", html) && occursin(">inner</a>", html)
  @test occursin("<p>Nothing in empty</p>", html)
  @test occursin("There's no folder called “nowhere” beside this page.", html)
  bytes = K.print_pdf(e)
  @test String(bytes[1:5]) == "%PDF-" && e.buf.caret[1] > 0
  frames()
end

@testset "the page in the dark, and in a narrow window" begin
  was = e.theme
  e.theme = :night; K.restyle!(e); settle()
  shot("gallery-night.png")
  @test rect(thumb(1)) !== nothing
  click(middle(rect(thumb(2))))
  @test "2 of 6" in said(rect(K.zooming(e)))
  at((40, 450))
  shot("gallery-bar-night.png")
  key(Keys.escape)
  e.theme = was; K.restyle!(e); settle()
  # A narrow window has fewer squares in a row, and they still take all the room
  narrow = K.build_editor(page)
  small = Window(narrow, size=(420px, 800px))
  for _ in 1:40
    frame(small)
  end
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(shots, "gallery-narrow.png"), small)
  n = narrow.nodes[(:block, K.GALLERY, page, 1)]
  g = G.grid(6, K.num(narrow.width) - 2 - 2K.num(K.GALLERY_PAD), :medium)
  @test g.columns < 5 && K.num(n.side) ≈ g.side && rect(n.parts[(:thumb, 6)]).top > rect(n.parts[(:thumb, 1)]).top
  # The bar under a picture still fits. It has the place and the name here.
  fits(z, wide) = K.num(rect(z.parts[(:button, :before)]).left) >= 8 && (c = rect(z.parts[(:button, :close)]); K.num(c.left + c.width) <= wide - 8)
  K.open_item!(n, 2); frame(small); frame(small)
  z = K.zooming(narrow)
  @test "2 of 6" in said(rect(z)) && "photo 2.png" in said(rect(z)) && fits(z, 420)
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(shots, "gallery-bar-narrow.png"), small)
  close(small)
  # In a window that's narrower still, the name goes first
  tight = K.build_editor(page)
  tiny = Window(tight, size=(340px, 700px))
  frame(tiny); frame(tiny)
  K.open_item!(tight.nodes[(:block, K.GALLERY, page, 1)], 2); frame(tiny); frame(tiny)
  z = K.zooming(tight)
  @test "2 of 6" in said(rect(z)) && !any(t -> startswith(t, "photo"), said(rect(z))) && fits(z, 340)
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(shots, "gallery-bar-tiny.png"), tiny)
  close(tiny)
end

@testset "a big folder: only the rows in the window are built" begin
  K.open!(e, long); settle()
  m = gallery(1, long)
  @test length(K.found!(m).items) == 300
  built() = count(k -> k isa Tuple && k[1] == :thumb, keys(m.parts))
  g = G.grid(300, K.num(e.width) - 2 - 2K.num(K.GALLERY_PAD), :small)
  @test built() < 300 && built() >= g.columns && length(m.small) <= built()
  @test rect(thumb(1, m)) !== nothing && !haskey(m.parts, (:thumb, 300))
  # The block is as tall as the whole grid
  @test K.num(rect(m).height) ≈ 2 + K.num(K.GALLERY_TOP) + G.tall(g.rows, g.side) + K.num(K.GALLERY_PAD) atol=1
  shot("gallery-many.png")
  # Further down the page, the last rows are built
  e.scroll.offset = 99999px; frames(); settle()
  @test rect(thumb(300, m)) !== nothing && K.small(m, K.found!(m).items[300]) isa NamedTuple && length(m.small) < 300
  shot("gallery-many-end.png")
  # A frame makes a few small pictures, not all that the window shows
  empty!(m.small); frames(1)
  @test length(m.wanted) > g.columns
  K.make_small!(m, budget=0)
  @test length(m.small) == 1 && isempty(m.wanted)
  settle()
  @test length(m.small) > g.columns
  # On paper every picture shows, so each one has its small picture
  @test String(K.print_pdf(e)[1:5]) == "%PDF-" && length(m.small) == 300
  frames()
end

@testset "the gallery of the welcome page" begin
  welcome = joinpath(K.pages_dir[], "welcome.md")
  K.open!(e, welcome); frames()
  i = findfirst(==("```gallery"), e.buf.lines)
  e.scroll.offset = K.item(e, i).top - 100px; frames(); settle()
  shot("gallery-welcome.png")
  @test names(gallery(1, welcome)) == ["1 footings.png", "2 frame.png", "3 roof.png", "4 bricks.png", "5 window.png", "6 finished.png"]
  @test all(p -> K.small(gallery(1, welcome), p) isa NamedTuple, K.found!(gallery(1, welcome)).items)
  # Its second gallery lists a file of each kind, and a folder
  @test names(gallery(2, welcome)) == ["plan.pdf", "knot.mp4", "knot.stl", "costs.csv", "photos"]
  @test G.summary(gallery(2, welcome).data, K.found!(gallery(2, welcome))) == "4 files and 1 folder"
  e.scroll.offset = K.item(e, findnext(==("```gallery"), e.buf.lines, i + 1)).top - 100px; frames(); settle()
  shot("gallery-welcome-kinds.png")
end

close(w)
