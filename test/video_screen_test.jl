# Tests for a video that fills the screen: the F key and the button of a video
# that fills the window, the top bar that goes, and the video's controls over
# its picture. See `screen!` in fill_view.jl. Run them with
# `julia -O0 --project=. test/video_screen_test.jl`. They need ffmpeg to make
# the video, and macOS to play it. The window isn't on the screen, so it never
# fills a screen itself: the tests look at what the window would show.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease Keys onkey
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/media" ready playing
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" parts controls_show pause!
@use "github.com/jkroso/UI.jl/Interface/window" fills_screen
@use "../main" => K
const px = K.px

const ffmpeg = something(Sys.which("ffmpeg"), "/opt/homebrew/bin/ffmpeg")
if Sys.isapple() && isfile(ffmpeg)

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const video = joinpath(dir, "walk.mp4")
run(pipeline(`$ffmpeg -nostdin -v error -y -f lavfi -i testsrc=d=8:s=320x180:r=24 -f lavfi -i sine=d=8 -c:v libx264 -g 24 -pix_fmt yuv420p -c:a aac $video`, stdout=devnull))

const e = K.build_editor(video)
const w = Window(e, size=(1000px, 700px))
# macOS reads a file while the app's event loop runs, so each frame runs the loop for a moment
const CoreFoundation = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
loop(seconds) = ccall((:CFRunLoopRunInMode, CoreFoundation), Int32, (Ptr{Cvoid}, Float64, UInt8),
                      unsafe_load(cglobal((:kCFRunLoopDefaultMode, CoreFoundation), Ptr{Cvoid})), seconds, 0)
frames(n=3) = foreach(_ -> (frame(w); loop(0.02)), 1:n)
until(f, most=10) = (stop = time() + most; while !f() && time() < stop; frames(1); end; f())
key!(key) = (onkey(w, KeyPress{key}(0, w)); onkey(w, KeyRelease{key}(0, w)); frames())
frames()
const p = e.nodes[(:fileview, video)].viewer
"True when the window draws its top bar"
has_bar() = named(K.describe(e), "TopBar")
"True when the layout `node` has a part called `name` in it"
named(node, name) = node isa K.GeometricUI && ((hasproperty(node, :name) && node.name == name) || any(c -> named(c, name), node.children))
"The words of the tooltips of the buttons that the view that fills the window shows"
tips() = [b.tip for b in values(K.zooming(e).parts) if b isa K.PlanButton && rect(b) !== nothing]

@testset "a video that fills the window has a button that makes it fill the screen" begin
  @test p isa K.VideoPlayer && until(() -> ready(p.media))
  K.zoom_in!(e, (:node, p), nothing); frames()
  @test K.zooming(e) !== nothing && !K.screening(e) && !p.screen && has_bar()
  @test p.height < 700px
  @test sort(tips()) == ["Back to the page  esc", "Fill the screen  F"]
end

@testset "F makes the video all that the window shows" begin
  key!(Keys.f)
  @test K.screening(e) && p.screen && !has_bar()
  # The picture is as big as the window, and the controls lie over its foot
  button, track, strip, picture = parts(p)
  @test p.height == 700px && picture.height == 700px && picture.width == 1000px && picture.top == 0px
  @test strip.top + strip.height == 700px && track.width > 600px
  # A video that's stopped shows its controls, and the two buttons in the corner
  @test controls_show(p) && sort(tips()) == ["Back to the page  esc", "Back to the window  F"]
  # A window that isn't on the screen stays as it is
  @test !fills_screen(w)
end

@testset "the keys of the video work while it fills the screen, and its controls go while it plays" begin
  key!(Keys.space)
  @test until(() -> playing(p.media))
  # The controls stay for a moment after the mouse moved, and then only the picture shows
  @test controls_show(p)
  p.stirred = time() - 10; frames()
  @test !controls_show(p) && isempty(tips()) && K.screening(e)
  at = position(p.media)
  key!(Keys.right)
  @test until(() -> position(p.media) > at + 3)
  key!(Keys.space)
  @test until(() -> !playing(p.media)) && controls_show(p)
end

@testset "F puts the video back in the window, and esc puts it back in the page" begin
  key!(Keys.f)
  @test !K.screening(e) && !p.screen && K.zooming(e) !== nothing && has_bar() && p.height < 700px
  key!(Keys.f)
  @test K.screening(e) && p.screen
  key!(Keys.escape)
  @test K.zooming(e) === nothing && !p.screen && has_bar()
  frames()
  @test parts(p)[4].height < 700px
  # One call makes a video of the page fill the screen
  K.screen_video!(e, p); frames()
  @test K.screening(e) && p.screen && parts(p)[4].height == 700px
  K.zoom_out!(K.zooming(e)); frames()
  @test !p.screen
  pause!(p)
end

end
