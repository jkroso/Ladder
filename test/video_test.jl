# Tests for a line that holds only a video file. See "video in the text" and
# "what was said in a video" in media_view.jl. Run them with
# `julia -O0 --project=. test/video_test.jl`. They need ffmpeg to make the video, and
# macOS to play it. They click in a window that isn't on the screen.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups pasteboard
@use "github.com/jkroso/UI.jl/Interface/media" span ready playing
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" parts speed
@use GeometryBasics: Vec2

@use "../main" => K
const px = K.px

@testset "a link names part of a file" begin
  @test K.media_part("walk.mov") == ("walk.mov", 0.0, Inf)
  @test K.media_part("walk.mov#t=61,86") == ("walk.mov", 61.0, 86.0)
  @test K.media_part("walk.mov#t=104,135.9") == ("walk.mov", 104.0, 135.9)
  # With no end, the part goes on to the end of the file. With no start, it starts at the start.
  @test K.media_part("walk.mov#t=61") == ("walk.mov", 61.0, Inf)
  @test K.media_part("walk.mov#t=,20") == ("walk.mov", 0.0, 20.0)
  # A time can be written as a clock shows it
  @test K.media_part("walk.mov#t=npt:1:01,0:01:26.5") == ("walk.mov", 61.0, 86.5)
  # An end before the start, and words that aren't times, are left out
  @test K.media_part("walk.mov#t=30,10") == ("walk.mov", 30.0, Inf)
  @test K.media_part("walk.mov#t=soon,later") == ("walk.mov", 0.0, Inf)
end

@testset "the words said in part of a file" begin
  ps = [(0.5, 2.0, "One."), (2.5, 3.0, "Two."), (6.0, 7.0, "Three."), (9.0, 10.0, "Four.")]
  # A pause of two seconds or more starts a paragraph
  @test K.words_between(ps, 0, Inf) == "One. Two.\n\nThree.\n\nFour."
  @test K.words_between(ps, 0, 5) == "One. Two."
  # A phrase is in the part when its middle is
  @test K.words_between(ps, 5, 9.4) == "Three."
  @test K.words_between(ps, 9.4, Inf) == "Four."
  @test K.words_between(ps, 3.5, 5.5) == ""
  # The program's lines, with one that isn't a phrase
  t = K.Transcription("walk.mov", nothing, "", "", 1.0, false, "0.50\t2.00\tOne.\nnot a phrase\n2.50\t3.00\tTwo, three.", "")
  @test K.phrases(t) == [(0.5, 2.0, "One."), (2.5, 3.0, "Two, three.")]
end

if Sys.isapple() && Sys.which("ffmpeg") !== nothing
  const dir = mktempdir()
  run(pipeline(`ffmpeg -loglevel error -y -f lavfi -i testsrc=duration=2:size=90x160:rate=10 -pix_fmt yuv420p $(joinpath(dir, "walk.mp4"))`, devnull))
  const page = joinpath(dir, "walk.md")
  write(page, """
  # A walk through

  ![The lounge](walk.mp4#t=0.5,1.2)

  > The windows need new film.
  > The carpet has a burn mark.

  ![The rest](walk.mp4#t=1.2)

  ![Not there](gone.mp4#t=0,1)

  The end.
  """)
  const e = K.build_editor(page)
  const w = Window(e, size=(1000px, 1200px))
  frames(n=2) = foreach(_ -> frame(w), 1:n)
  frames()

  "Move the mouse of `win` to `(x, y)`"
  hover!(win, (x, y)) = (win.mouse = typeof(win.mouse)(px(x), px(y)); onmouse(win, MouseMove(Vec2{px}(px(x), px(y)), win)); foreach(_ -> frame(win), 1:2))
  "Click in `win` at `(x, y)`"
  press!(win, place) = begin
    hover!(win, place)
    win.keys |= Keys.mouse_left; onkey(win, KeyPress{Keys.mouse_left}(0, win))
    win.keys ⊻= Keys.mouse_left; onkey(win, KeyRelease{Keys.mouse_left}(0, win))
    foreach(_ -> frame(win), 1:2)
  end
  at(place) = hover!(w, place)
  click(place) = press!(w, place)
  middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))
  transcripts(win=w) = [p for p in popups(win) if p.key == :transcript]
  "The Fillable of the video that line `i` of `ed` shows. Its buttons show beside the video."
  fillable(ed, i) = K.fills(ed)[objectid(K.item(ed, i).content.node)]
  "Wait for macOS to transcribe what the drop-down `t` shows"
  settle(win, t) = begin
    stop = time() + 90   # the first time, Swift compiles the program that transcribes
    while time() < stop && K.transcript_of(t.player).busy
      frame(win); sleep(0.1)
    end
    frame(win)
    K.transcript_of(t.player)
  end

  # macOS reads a file while the app's event loop runs. A test has no window
  # open, so it runs the loop itself for a moment at a time.
  const CoreFoundation = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"
  loop(seconds) = ccall((:CFRunLoopRunInMode, CoreFoundation), Int32, (Ptr{Cvoid}, Float64, UInt8),
                        unsafe_load(cglobal((:kCFRunLoopDefaultMode, CoreFoundation), Ptr{Cvoid})), seconds, 0)

  "The video player that line `i` shows, or nothing"
  player(i) = begin
    it = K.item(e, i)
    it.first == i && it.content isa K.Live && it.content.node isa K.Shown && it.content.node.value isa K.VideoPlayer ? it.content.node.value : nothing
  end

  @testset "a line that holds only a video shows a player of the part that it names" begin
    lounge, rest = player(3), player(8)
    @test lounge !== nothing && rest !== nothing
    @test (lounge.from, lounge.to) == (0.5, 1.2) && (rest.from, rest.to) == (1.2, Inf)
    # Once macOS has read the file, each player is at the start of its part
    stop = time() + 5
    while time() < stop && !(ready(lounge.media) && abs(position(lounge.media) - 0.5) < 0.05)
      frames(1); loop(0.02)
    end
    @test span(lounge.media) == (0.5, 1.2)
    @test abs(position(lounge.media) - 0.5) < 0.05
    # A file that isn't there shows the line's text
    @test player(10) === nothing && K.item(e, 10).content isa K.Flow
  end

  "Press `key` in `w` and let it go, while holding the keys after it"
  key!(w, key, mods...) = begin
    foreach(m -> w.keys |= m, mods)
    onkey(w, KeyPress{key}(0, w)); onkey(w, KeyRelease{key}(0, w))
    foreach(m -> w.keys ⊻= m, mods)
    frames()
  end

  @testset "a click on the speed button of a video in a page gives it the keyboard, and its keys type nothing into the page" begin
    lounge = player(3)
    text, version = copy(e.buf.lines), e.buf.version
    speeds = parts(lounge)[5]
    click(middle(speeds))
    @test speed(lounge) == 1.5 && w.focus === lounge
    # Shift and the . key type >, and Shift and the , key type <
    key!(w, Keys.period, Keys.shft)
    @test speed(lounge) == 1.75
    key!(w, Keys.comma, Keys.shft); key!(w, Keys.comma, Keys.shft); key!(w, Keys.comma, Keys.shft)
    @test speed(lounge) == 1
    # The space bar plays and stops it
    key!(w, Keys.space)
    @test playing(lounge.media)
    key!(w, Keys.space)
    @test !playing(lounge.media)
    @test e.buf.lines == text && e.buf.version == version
  end

  @testset "while the mouse is over a video, a button under the fill button shows what was said" begin
    f = fillable(e, 3)
    at((5, 5))
    @test f.transcript === nothing || rect(f.transcript) === nothing
    at(middle(rect(f)))
    fill, b = rect(f.button), rect(f.transcript)
    @test fill !== nothing && b !== nothing
    @test b.left == fill.left && b.top == fill.top + fill.height + K.FILL_GAP
    # They stay while the mouse goes to the lower button, and go once it leaves the video
    at(middle(b))
    @test rect(f.transcript) !== nothing
    at((5, 5))
    @test rect(f.transcript) === nothing && rect(f.button) === nothing
    # The quote under the first video is text of the page, as it's written
    @test K.item(e, 5).content isa K.Flow && K.item(e, 6).content isa K.Flow
  end

  @testset "the drop-down of a video with no sound says why it has no words" begin
    f = fillable(e, 3)
    at(middle(rect(f)))
    button = f.transcript
    click(middle(rect(button)))
    @test length(transcripts()) == 1 && button.open
    t = transcripts()[1].content
    @test t isa K.Transcript && t.player === player(3)
    # The drop-down is under the button, lined up with it
    b, d = rect(button), transcripts()[1].scene
    @test d.top >= b.top + b.height && d.left == b.left
    # The buttons stay while it's open, though the mouse is away from the video
    at((K.num(d.left + d.width - 10), K.num(d.top + d.height - 10)))
    @test rect(button) !== nothing && length(transcripts()) == 1
    @test settle(w, t) == (words="", note="walk.mp4 has no sound that macOS can read", busy=false)
    # With no words, there's nothing to copy
    @test rect(t.copy) === nothing
    # A click on the button again closes the drop-down
    click(middle(rect(button)))
    @test isempty(transcripts()) && !button.open
  end

  # A video with two things said in it: one at its start, and one from about 4.4 seconds
  cd(dir) do
    run(`say -o a.aiff "The windows need new film."`)
    run(`say -o b.aiff "The carpet has a burn mark."`)
    run(pipeline(`ffmpeg -loglevel error -y -f lavfi -i testsrc=duration=9:size=90x160:rate=10 -i a.aiff -i b.aiff
                  -filter_complex "[1]apad=pad_dur=3[a];[a][2]concat=n=2:v=0:a=1[s]" -map 0:v -map "[s]"
                  -pix_fmt yuv420p -c:a aac talk.mp4`, devnull))
  end
  const talk = joinpath(dir, "talk.md")
  write(talk, """
  # Talk

  ![The first part](talk.mp4#t=0,3)

  ![The rest](talk.mp4#t=3)

  ![All of it](talk.mp4)
  """)
  const te = K.build_editor(talk)
  const tw = Window(te, size=(1000px, 2400px))
  foreach(_ -> frame(tw), 1:2)
  "Open the drop-down of the video on line `i` of the talk, and wait for its words"
  words_of(i) = begin
    # Esc closes the drop-down that's open
    isempty(transcripts(tw)) || (onkey(tw, KeyPress{Keys.escape}(0, tw)); frame(tw))
    @test isempty(transcripts(tw))
    hover!(tw, (5, 5))
    hover!(tw, middle(rect(fillable(te, i))))
    press!(tw, middle(rect(fillable(te, i).transcript)))
    t = transcripts(tw)[1].content
    t, settle(tw, t)
  end

  @testset "the drop-down shows what was said in the part of the video that the line names" begin
    t, first = words_of(3)
    @test !first.busy && occursin("windows", lowercase(first.words)) && !occursin("carpet", lowercase(first.words))
    # Its button copies the words to the clipboard, and says so for a moment
    pasteboard[] = ""
    r = rect(t.copy)
    @test r !== nothing
    press!(tw, middle(r))
    @test pasteboard[] == first.words
    @test time() - t.copy.copied < K.COPIED_FOR
    # The words fit in the drop-down without scrolling
    @test t.scroll.viewport == t.scroll.content_height
    # The other parts of the file use the same transcription
    made = K.video_words[joinpath(dir, "talk.mp4")][2]
    _, rest = words_of(5)
    @test occursin("carpet", lowercase(rest.words)) && !occursin("windows", lowercase(rest.words))
    _, whole = words_of(7)
    @test occursin("windows", lowercase(whole.words)) && occursin("carpet", lowercase(whole.words))
    @test K.video_words[joinpath(dir, "talk.mp4")][2] === made
  end

  @testset "the page of HTML has a player for each video" begin
    out = K.page_html(e)
    @test occursin("<video controls preload=\"metadata\" src=\"walk.mp4#t=0.5,1.2\" title=\"The lounge\"></video>", out)
    @test !occursin("<img src=\"walk.mp4", out)
  end
end
