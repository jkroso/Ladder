# Tests for a <canvas> that a page's scripts draw on: web/canvas.jl, which is
# the surface and the drawing, and web/context.jl, which gives a script
# `getContext('2d')`. Then a page with scripts that moves: an animation of its
# CSS, a style that takes time to change, and a video that a script starts.
# Run them with
# `julia -O0 --project=. test/web_canvas_test.jl`. They use the fonts of this
# Mac and no web. They run in the main task: see web/jsc.jl.

@use Test: @test, @testset
@use "../web/canvas" => Canvas
@use "../web/live" => Live
@use "../web" => Web
@use "../web/paint" => Paint

"The pixel at `(x, y)` of a surface: how red, how green, how blue and how solid"
at(b, x, y) = Int.(Canvas.pixels(b, x, y, 1, 1))
near(a, b; by=3) = all(abs.(a .- b) .<= by)

@testset "a surface to draw on" begin
  b = Canvas.Board(100, 60)
  @test at(b, 5, 5) == [0, 0, 0, 0] && length(b.pixels) == 4 * 100 * 60
  # A rectangle, filled, and then part of it taken away
  b.state.fill = Canvas.ink("rgb(255 0 0)")
  Canvas.rect!(b, 10, 10, 30, 20)
  Canvas.rect!(b, 20, 15, 5, 5; how=:clear)
  @test at(b, 12, 12) == [255, 0, 0, 255] && at(b, 22, 17) == [0, 0, 0, 0] && at(b, 50, 12) == [0, 0, 0, 0]
  # A colour that's half see-through is read back as it was written
  b.state.fill = Canvas.ink("rgba(0, 0, 255, 0.5)")
  Canvas.rect!(b, 60, 10, 10, 10)
  @test near(at(b, 65, 15), [0, 0, 255, 128]) && Canvas.written(0x800000ff) == "rgba(0, 0, 255, 0.5)" && Canvas.written(0x81000000) == "rgba(0, 0, 0, 0.506)" && Canvas.written(0xff00ff00) == "#00ff00" && Canvas.ink("nonsense") === nothing
  # A path is kept where it was made, when the context is moved after
  Canvas.clear!(b)
  Canvas.save!(b)
  Canvas.turn!(b, (1.0, 0.0, 0.0, 1.0, 50.0, 30.0))
  Canvas.add!(b.shape, b.state.m, "R", (0, 0, 10, 10))
  Canvas.turn!(b, (1.0, 0.0, 0.0, 1.0, 100.0, 100.0))
  b.state.fill = 0xff00ff00
  Canvas.paint!(b, :fill)
  Canvas.restore!(b)
  @test at(b, 55, 35) == [0, 255, 0, 255] && at(b, 45, 35)[4] == 0 && b.state.m == Canvas.SAME && Canvas.inside(b.shape, 55, 35) && !Canvas.inside(b.shape, 5, 5)
  # A path that crosses itself: what's inside it both ways
  empty!(b.shape)
  Canvas.add!(b.shape, Canvas.SAME, "R", (0, 0, 40, 40))
  Canvas.add!(b.shape, Canvas.SAME, "R", (10, 10, 20, 20))
  @test Canvas.inside(b.shape, 20, 20) && !Canvas.inside(b.shape, 20, 20; rule="evenodd") && Canvas.inside(b.shape, 5, 5; rule="evenodd")
  # An arc, a line that's stroked, and a cut
  Canvas.clear!(b)
  Canvas.add!(b.shape, Canvas.SAME, "A", (30, 30, 20, 0, 2π))
  Canvas.clip!(b)
  b.state.fill = 0xff0000ff
  Canvas.rect!(b, 0, 0, 100, 60)
  @test at(b, 30, 30) == [0, 0, 255, 255] && at(b, 55, 30)[4] == 0 && at(b, 12, 12)[4] == 0
  Canvas.clear!(b)
  b.state.stroke, b.state.wide = 0xff000000, 6.0
  Canvas.add!(b.shape, Canvas.SAME, "M", (10, 30))
  Canvas.add!(b.shape, Canvas.SAME, "L", (90, 30))
  Canvas.paint!(b, :stroke)
  @test at(b, 50, 30)[4] == 255 && at(b, 50, 28)[4] == 255 && at(b, 50, 36)[4] == 0 && Canvas.sweep(0, 3π, false) == 2π && Canvas.sweep(0, -π / 2, false) ≈ 3π / 2
  # Colours that run into each other
  Canvas.clear!(b)
  b.state.fill = Canvas.Gradient(:linear, (0.0, 0.0, 100.0, 0.0, 0.0, 0.0), [(0.0, 0xffff0000), (1.0, 0xff0000ff)])
  Canvas.rect!(b, 0, 0, 100, 60)
  @test at(b, 2, 30)[1] > 240 && at(b, 97, 30)[3] > 240 && near(at(b, 50, 30), [127, 0, 127, 255]; by=6)
  # Text draws, and is as wide as its font says
  Canvas.clear!(b)
  b.state.font = Canvas.lettering("bold 20px Helvetica")
  Canvas.write!(b, "Hi", 10, 30)
  @test any(!=(0), b.pixels) && b.state.font.size == 20 && Canvas.measure(b, "Hi there") > 2 * Canvas.measure(b, "Hi") && Canvas.lettering("nonsense") === nothing
  # Pixels are written and read, and the surface is a picture file
  Canvas.clear!(b)
  Canvas.pixels!(b, UInt8[1, 2, 3, 255, 200, 100, 50, 128], 98, 0, 2, 1)
  @test at(b, 98, 0) == [1, 2, 3, 255] && near(at(b, 99, 0), [200, 100, 50, 128]) && Canvas.pixels(b, 99, 0, 2, 1)[5:8] == [0, 0, 0, 0]
  @test Canvas.encoded(b)[1:4] == UInt8[0x89, 0x50, 0x4e, 0x47] && startswith(Canvas.address(b, "image/jpeg"), "data:image/jpeg;base64,") && Canvas.image!(b) != C_NULL
end

const DOT = """data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' width='8' height='4'><rect width='8' height='4' fill='rgb(0,128,128)'/></svg>"""

@testset "a script draws on a canvas" begin
  l = Live.live("""<!DOCTYPE html><body style="margin:0"><canvas id=c width=100 height=60 style="display:block"></canvas><canvas id=d width=40 height=40 style="display:block;width:20px;height:20px"></canvas>
    <script>
      var c = document.getElementById('c'), x = c.getContext('2d'), d = document.getElementById('d').getContext('2d')
      var pixel = (ctx, px, py) => Array.from(ctx.getImageData(px, py, 1, 1).data).join(',')
      x.fillStyle = 'red'
      x.fillRect(0, 0, 10, 10)
    </script></body>"""; wide=200)
  js(code) = Live.evaluate(l, code)
  @test isempty(l.scripts.log) && js("pixel(x, 5, 5)") == "255,0,0,255" && js("pixel(x, 50, 5)") == "0,0,0,0"
  # The page draws what's on the canvas, where the canvas is
  p = Live.page!(l)
  @test p.tall == 80 && count(i -> i isa Paint.Sketch, p.list.items) == 2
  # What a script draws later shows with no new layout
  js("x.fillStyle = '#00f'; x.fillRect(50, 0, 10, 10)")
  @test Live.page!(l) === p && js("pixel(x, 55, 5)") == "0,0,255,255"
  # The context keeps what a script sets, in the words of a browser, and takes no nonsense
  @test js("x.fillStyle") == "#0000ff" && js("x.fillStyle = 'nonsense'; x.lineWidth = -1; x.globalAlpha = 2; [x.fillStyle, x.lineWidth, x.globalAlpha].join()") == "#0000ff,1,1"
  @test js("x.fillStyle = 'rgba(0, 0, 0, 0.5)'; x.fillStyle") == "rgba(0, 0, 0, 0.5)" && js("x.font = 'italic 14px Georgia'; x.font") == "italic 14px Georgia" && js("x.font = 'big'; x.font") == "italic 14px Georgia"
  @test js("x.save(); x.fillStyle = 'lime'; x.lineWidth = 5; x.restore(); [x.fillStyle, x.lineWidth].join()") == "rgba(0, 0, 0, 0.5),1"
  @test js("c.getContext('2d') === x") === true && js("c.getContext('webgl')") === nothing && js("x.canvas === c") === true
  # Moves, paths and cuts
  js("x.fillStyle = 'lime'; x.save(); x.translate(20, 20); x.scale(2, 2); x.beginPath(); x.rect(0, 0, 5, 5); x.fill(); x.restore()")
  @test js("pixel(x, 28, 28)") == "0,255,0,255" && js("pixel(x, 32, 32)") == "0,0,0,0" && js("x.getTransform().isIdentity") === true
  @test js("x.beginPath(); x.arc(80, 40, 10, 0, 2 * Math.PI); [x.isPointInPath(80, 40), x.isPointInPath(95, 40)].join()") == "true,false"
  js("var tri = new Path2D('M 60 30 l 20 0 l -10 20 z'); x.fill(tri); var both = new Path2D(); both.addPath(tri, {e: -50, f: 0}); x.fill(both)")
  @test js("pixel(x, 70, 35)") == "0,255,0,255" && js("pixel(x, 20, 35)") == "0,255,0,255" && js("[x.isPointInPath(tri, 70, 35), x.isPointInPath(tri, 62, 48)].join()") == "true,false"
  js("x.save(); x.beginPath(); x.rect(0, 50, 5, 5); x.clip(); x.fillStyle = 'red'; x.fillRect(0, 40, 20, 20); x.restore()")
  @test js("pixel(x, 2, 52)") == "255,0,0,255" && js("pixel(x, 10, 52)") == "0,0,0,0"
  # Colours that run into each other, and one that's added after the gradient is the fill
  js("var g = d.createLinearGradient(0, 0, 40, 0); g.addColorStop(0, 'red'); d.fillStyle = g; g.addColorStop(1, 'blue'); d.fillRect(0, 0, 40, 40)")
  @test parse(Int, split(js("pixel(d, 1, 20)"), ',')[1]) > 240 && parse(Int, split(js("pixel(d, 38, 20)"), ',')[3]) > 240
  @test js("try { g.addColorStop(2, 'red') } catch (e) { e.name }") == "IndexSizeError" && js("try { g.addColorStop(0.5, 'nonsense') } catch (e) { e.name }") == "SyntaxError"
  # One canvas is drawn on another, and laid side by side as a pattern
  js("d.fillStyle = 'purple'; d.fillRect(0, 0, 40, 40); x.clearRect(0, 0, 100, 60); x.drawImage(d.canvas, 10, 10, 4, 4); x.drawImage(d.canvas, 0, 0, 20, 20, 50, 50, 5, 5)")
  @test js("pixel(x, 12, 12)") == "128,0,128,255" && js("pixel(x, 52, 52)") == "128,0,128,255" && js("pixel(x, 20, 20)") == "0,0,0,0"
  js("x.fillStyle = x.createPattern(d.canvas, 'repeat-x'); x.fillRect(0, 0, 100, 60)")
  @test js("pixel(x, 90, 20)") == "128,0,128,255" && js("pixel(x, 90, 50)") == "0,0,0,0"
  # Pixels are read and written, and the size of text is told
  @test js("var im = x.createImageData(2, 1); im.data.set([10, 20, 30, 255, 0, 0, 0, 0]); x.putImageData(im, 98, 59); pixel(x, 98, 59)") == "10,20,30,255" && js("pixel(x, 99, 59)") == "0,0,0,0"
  @test js("x.font = '20px Helvetica'; var m = x.measureText('Hello'); m.width > 30 && m.width < 60 && m.fontBoundingBoxAscent > 10") === true
  js("x.fillStyle = 'black'; x.textBaseline = 'top'; x.clearRect(0, 0, 100, 60); x.fillText('Hello', 0, 0)")
  @test js("Array.from(x.getImageData(0, 0, 60, 20).data).some(v => v > 0)") === true
  @test startswith(js("c.toDataURL()"), "data:image/png;base64,iVBOR") && startswith(js("c.toDataURL('image/jpeg', 0.5)"), "data:image/jpeg;base64,")
  # A canvas whose size is set starts again, with nothing drawn
  @test js("c.width = 100; x.fillStyle") == "#000000" && js("pixel(x, 5, 5)") == "0,0,0,0" && js("c.height = 30; [c.width, c.height].join()") == "100,30" && Live.page!(l).tall == 50
  # A picture of the page tells its scripts when it's read, and then it's drawn. One that isn't there says so.
  js("""var seen = []; var img = new Image(); img.onload = () => { seen.push(img.naturalWidth); x.drawImage(img, 0, 0) }; img.src = "$DOT"
        var gone = new Image(); gone.onerror = () => seen.push('gone'); gone.src = 'missing.png'""")
  Live.step!(l)
  sleep(0.01)
  Live.step!(l)
  @test js("seen.join()") == "8,gone" && js("pixel(x, 3, 2)") == "0,128,128,255" && js("img.complete && !gone.complete") === true
  # A canvas that's in no page, and a picture made ready from a canvas
  @test js("var off = new OffscreenCanvas(10, 10), o = off.getContext('2d'); o.fillStyle = 'red'; o.fillRect(0, 0, 10, 10); x.drawImage(off, 90, 20); pixel(x, 95, 25)") == "255,0,0,255"
  js("var made = null; createImageBitmap(off, 0, 0, 5, 5).then(b => { made = b; x.drawImage(b, 70, 20) })")
  @test js("[made.width, made.height].join()") == "5,5" && js("pixel(x, 72, 22)") == "255,0,0,255" && js("pixel(x, 77, 22)") == "0,0,0,0"
  # A script that draws at each frame
  js("var n = 0; (function tick() { d.fillStyle = n % 2 ? 'red' : 'lime'; d.fillRect(0, 0, 40, 40); if (++n < 3) requestAnimationFrame(tick) })()")
  @test Live.step!(l) == 0 && js("pixel(d, 5, 5)") == "255,0,0,255"
  Live.step!(l)
  @test js("n") == 3 && js("pixel(d, 5, 5)") == "0,255,0,255" && isempty(l.scripts.log)
  close(l)
end

@testset "a page with scripts that moves" begin
  clip = read(joinpath(@__DIR__, "web_clip.mp4"))
  l = Live.live("""<!DOCTYPE html><style>@keyframes go { from { margin-left: 0 } to { margin-left: 100px } } p { margin: 0 } .on { animation: go 0.2s linear forwards }</style>
    <body style="margin:0"><p id=p>x</p><video id=v src="clip.mp4" style="display:block"></video><canvas id=c width=64 height=48></canvas>
    <script>var v = document.getElementById('v'), x = document.getElementById('c').getContext('2d')</script></body>"""; wide=300, load=src -> src == "clip.mp4" ? clip : nothing)
  js(code) = Live.evaluate(l, code)
  left() = Live.page!(l).words[1].edges[1]
  # The test sets the page's clock, so that a busy Mac changes nothing. The page's time is the time since its scripts
  # started, so the page is `t` seconds old when they started `t` seconds ago. A page that moves isn't laid out again
  # for a moment after a layout, and that moment ends here too.
  at!(t) = (l.scripts.started = time() - t; l.rest = 0.0)
  # Nothing moves, so the page is laid out once
  p = Live.page!(l)
  @test !Web.moving(p) && Live.page!(l) === p && left() == 0
  # An animation that a script starts runs from then, and the page is laid out again while it does
  js("document.getElementById('p').className = 'on'")
  at!(10)
  first = Live.page!(l)
  @test Web.moving(first) && first.words[1].edges[1] < 50
  at!(10.1)   # half of the animation's time has gone
  @test Live.page!(l) !== first && 20 < left() < 100
  at!(10.3)
  @test left() == 100 && !Web.moving(Live.page!(l)) && Live.page!(l) === Live.page!(l)
  # The scripts are told when the animation is over, by its name
  js("var ends = []; document.addEventListener('animationend', e => ends.push([e.target.id, e.animationName, e.elapsedTime, e instanceof Event].join()))")
  Live.step!(l)
  @test js("ends.join(';')") == "p,go,0.2,true"
  Live.step!(l)
  @test js("ends.length") == 1
  # A style that a script changes takes the time that its `transition` says, and then the scripts are told
  js("""var p = document.getElementById('p'); p.className = ''; p.style.transition = 'margin-left 0.2s linear'
        p.ontransitionend = e => ends.push([e.propertyName, e.elapsedTime, e.bubbles].join())""")
  at!(11)
  @test left() == 100   # the animation is gone, and the margin takes its time to go back from where the animation left it
  at!(11.3)
  @test left() == 0
  js("p.style.marginLeft = '60px'")
  at!(12)
  first = Live.page!(l)
  @test Web.moving(first) && first.words[1].edges[1] < 30
  at!(12.1)   # half of the transition's time has gone
  @test 10 < left() < 60
  at!(12.11)
  @test parse(Float64, replace(js("getComputedStyle(p).marginLeft"), "px" => "")) < 60
  at!(12.3)
  @test left() == 60 && !Web.moving(Live.page!(l))
  Live.step!(l)
  @test js("ends.slice(1).join(';')") == "margin-left,0.2,true;margin-left,0.2,true" && js("new TransitionEvent('transitionend', {propertyName: 'x'}).propertyName") == "x"
  # A script starts, moves and stops a video, and draws its picture on a canvas
  @test js("[v.paused, v.duration, v.videoWidth, v.videoHeight, v.currentTime, v.readyState].join()") == "true,2,64,48,0,4"
  js("x.drawImage(v, 0, 0)")
  @test js("Array.from(x.getImageData(10, 10, 1, 1).data).join()")[1:2] in ("24", "25") && js("var played = 0; v.addEventListener('play', () => played++); v.currentTime = 1.5; v.play(); [v.paused, played].join()") == "false,1"
  @test Web.moving(Live.page!(l)) && js("v.currentTime >= 1.5 && v.currentTime < 2") === true
  js("x.drawImage(v, 0, 0); v.pause()")
  @test js("Array.from(x.getImageData(10, 10, 1, 1).data)[2] > 200") === true && js("v.paused") === true && !Web.moving(Live.page!(l)) && isempty(l.scripts.log)
  close(l)
end
