# Tests for a project page: a page whose videos and sounds are at web addresses,
# and whose front matter has a `progress` line. See "video and sound from the
# web" in media_view.jl and "a job in Centient from the page" in centient_job.jl.
# Run them with
# `julia -O0 --project=. test/project_page_test.jl`. They use no network: `curl` is a
# program of the test's own, and Centient is centient_fake.jl. They need ffmpeg
# to make a video and a sound, and macOS to play them.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use GeometryBasics: Vec2

const dir = mktempdir()

# Centient's server is looked for in this folder, and the one there is the fake
cp(joinpath(@__DIR__, "centient_fake.jl"), joinpath(dir, "mcp_server.jl"))
ENV["CENTIENT_SIDECAR"] = dir

# This `curl` is found before the Mac's own. It copies the file that an address names from the
# folder `web`, and fails as `curl` does if the folder hasn't got it. It waits while the folder
# has a file called hold, and it writes down what it was asked.
const web = mkpath(joinpath(dir, "web"))
const bin = mkpath(joinpath(dir, "bin"))
write(joinpath(bin, "curl"), raw"""
#!/bin/sh
echo "$@" >> "$FAKE_WEB/calls"
while [ -e "$FAKE_WEB/hold" ]; do sleep 0.05; done
while [ $# -gt 1 ]; do
  [ "$1" = "--output" ] && out="$2"
  shift
done
name=$(basename "${1%%\?*}")
[ -f "$FAKE_WEB/$name" ] || exit 22
cp "$FAKE_WEB/$name" "$out"
""")
chmod(joinpath(bin, "curl"), 0o755)
ENV["FAKE_WEB"] = web
ENV["PATH"] = bin * ":" * ENV["PATH"]

@use "../main" => K
const px = K.px
K.MEDIA_CACHE[] = joinpath(dir, "cache")

const site = "http://host:9330/walkthrough/projects/3f9c"

@testset "the copy of a video or a sound on the web" begin
  copy = K.media_file("$site/media/walkthrough.mov")
  # It's in the folder of copies, and its name ends as the file's does
  @test dirname(copy) == joinpath(dir, "cache") && endswith(copy, ".mov")
  @test endswith(K.media_file("$site/media/Walk.MOV?key=ab12"), ".mov")
  # Each part of one video has the same copy, whatever follows the ? or the #
  @test K.media_file("$site/media/walkthrough.mov#t=48,112") == copy
  @test K.media_file("$site/media/walkthrough.mov?key=ab12#t=0,20") == copy
  @test K.media_file("$site/media/kitchen.mov") != copy
  @test K.web_media("$site/media/note.m4a?key=ab12") && K.web_media("https://host/walk.mp4#t=1")
  @test !K.web_media("$site/media/kitchen-0135.jpg") && !K.web_media("walk.mov") && !K.web_media("$site/tasks?key=ab12")
  # A file on the Mac, and a picture on the web, are named as they were
  @test K.local_media("$site/media/walkthrough.mov?key=ab12") == copy
  @test K.local_media("walk.mov") == "walk.mov" && K.local_media("$site/media/kitchen-0135.jpg") == "$site/media/kitchen-0135.jpg"
end

@testset "what the front matter sets a key to" begin
  yaml = ["---", "property: 12/40 Wattle Street, Dickson ACT 2602", "progress: \"$site/tasks?key=ab12\"", "---", "", "# A page", "purpose: not this"]
  @test K.matter_value(yaml, "property") == "12/40 Wattle Street, Dickson ACT 2602"
  @test K.matter_value(yaml, "progress") == "$site/tasks?key=ab12"
  @test K.matter_value(yaml, "purpose") === nothing
  @test K.matter_value(["+++", "progress = '$site/tasks'", "+++"], "progress") == "$site/tasks"
  @test K.matter_value(["# A page", "", "progress: $site/tasks"], "progress") === nothing
end

@testset "what the button says of Centient's answer" begin
  # No program of Centient's has opened a company's books yet, so the words name no company. A test
  # that ran before this one in the same process can have left the name of the last company.
  K.Centient.stop!()
  K.Centient.server.company = ""
  made = Dict{String,Any}("job" => 12.0, "title" => "12/40 Wattle Street", "tasks" => 1.0, "steps" => 1.0, "added" => 1.0, "existed" => false)
  @test K.job_words(made) == "Centient has the job 12/40 Wattle Street, with 1 task for 1 trade."
  @test K.job_words(merge(made, Dict("existed" => true))) == "Centient added 1 new task to the job 12/40 Wattle Street."
  @test K.job_words(merge(made, Dict("existed" => true, "added" => 0.0))) == "Centient has this job already: 12/40 Wattle Street."
end

if Sys.isapple() && Sys.which("ffmpeg") !== nothing
  run(pipeline(`ffmpeg -loglevel error -y -f lavfi -i testsrc=duration=2:size=90x160:rate=10 -pix_fmt yuv420p $(joinpath(dir, "walk.mov"))`, devnull))
  run(pipeline(`ffmpeg -loglevel error -y -f lavfi -i sine=frequency=440:duration=1 $(joinpath(dir, "note.m4a"))`, devnull))
  # One video and one sound are on the Mac already. The web has another video, and it waits before it sends it.
  mkpath(K.media_dir())
  cp(joinpath(dir, "walk.mov"), K.media_file("$site/media/walkthrough.mov"))
  cp(joinpath(dir, "note.m4a"), K.media_file("$site/media/note-1.m4a"))
  cp(joinpath(dir, "walk.mov"), joinpath(web, "later.mov"))
  touch(joinpath(web, "hold"))

  const page = joinpath(dir, "wattle.md")
  write(page, """
  ---
  property: 12/40 Wattle Street, Dickson ACT 2602
  purpose: Ready for a new tenant
  progress: $site/tasks?key=ab12
  ---

  # 12/40 Wattle Street

  ## Kitchen

  ![Kitchen]($site/media/walkthrough.mov?key=ab12#t=0.5,1.2)

  - [ ] **Plumber.** Stop the kitchen tap from dripping.

  ![A note]($site/media/note-1.m4a?key=ab12)

  ## Bathroom

  ![Bathroom]($site/media/later.mov?key=ab12#t=0,1)

  ![The rest of it]($site/media/later.mov?key=ab12#t=1)

  ![Another note]($site/media/lost.m4a?key=ab12)

  The end.
  """)
  # A page with no `progress` line, one whose `progress` isn't a web address, and one whose address can't be reached
  const plain = joinpath(dir, "plain.md")
  write(plain, "---\nproperty: 1 Short Street\n---\n\n# Notes\n")
  const partly = joinpath(dir, "partly.md")
  write(partly, "---\nprogress: half done\n---\n\n# Notes\n")
  const far = joinpath(dir, "far.md")
  write(far, "---\nprogress: http://unreachable:9330/walkthrough/projects/7/tasks?key=cd34\n---\n\n# 3 Far Road\n")

  const e = K.build_editor(page)
  const w = Window(e, size=(1000px, 1200px))
  frames(n=2) = foreach(_ -> frame(w), 1:n)
  frames()

  at((x, y)) = (w.mouse = typeof(w.mouse)(px(x), px(y)); onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w)))
  press(place) = (at(place); w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)))
  release() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames())
  click(place) = (press(place); release())
  "Draw frames until `done()`, as the window would while it waits for something"
  settle(done, most=30) = (t = time(); while !done() && time() - t < most; frames(1); sleep(0.02); end; done())

  "The line of the page that starts with `words`"
  line(words) = findfirst(startswith(words), e.buf.lines)
  "What the line that starts with `words` shows in place of its text, or nothing"
  shown(words) = (i = line(words); it = K.item(e, i); it.first == i && it.content isa K.Live ? it.content.node : nothing)
  "The video player that the line that starts with `words` shows, or nothing"
  player(words) = (node = shown(words); node isa K.Shown && node.value isa K.VideoPlayer ? node.value : nothing)
  "What `curl` was asked for the file `name`, once for each time"
  calls(name) = (file = joinpath(web, "calls"); isfile(file) ? filter(contains(name), readlines(file)) : String[])
  "Wait until `curl` has written down that it was asked for each of `names`. It does that a moment after Ladder starts it."
  started(names...) = timedwait(() -> all(name -> !isempty(calls(name)), names), 10) == :ok

  @testset "a video and a sound whose copies are on the Mac show their players" begin
    kitchen = player("![Kitchen]")
    @test kitchen !== nothing && kitchen.path == K.media_file("$site/media/walkthrough.mov")
    @test (kitchen.from, kitchen.to) == (0.5, 1.2)
    note = shown("![A note]")
    @test note isa K.SoundLine && note.path == K.media_file("$site/media/note-1.m4a")
    # What's said in the sound goes under the line that names it. This transcription has finished, so no program runs.
    @test K.sound_line(e, note.path) == line("![A note]")
    K.transcriptions[note.path] = K.Transcription(note.path, nothing, "", "", 1.0, false, "Stop the tap.", "")
    frames()
    @test note.path in K.transcribed && e.buf.lines[line("![A note]") + 2] == "Stop the tap."
    # Ladder asked for the two files that it lacks, and for neither of the two that it has
    @test started("later.mov", "lost.m4a")
    @test isempty(calls("walkthrough.mov")) && isempty(calls("note-1.m4a"))
  end

  @testset "a line whose file is on its way says so" begin
    first, rest, lost = shown("![Bathroom]"), shown("![The rest of it]"), shown("![Another note]")
    @test first isa K.MediaNote && first.words == "Downloading the video…" && !first.failed
    @test rest isa K.MediaNote && rest.words == "Downloading the video…"
    @test lost isa K.MediaNote && lost.words == "Downloading the sound…"
    # The two parts of the video share one download. It asks for the address with its ? and without its #.
    @test length(calls("later.mov")) == 1
    @test endswith(only(calls("later.mov")), "--continue-at - --output $(K.media_file("$site/media/later.mov")).part -- $site/media/later.mov?key=ab12")
    # What `curl` has got so far isn't played
    write(K.media_file("$site/media/later.mov") * ".part", "half")
    frames()
    @test shown("![Bathroom]") isa K.MediaNote
  end

  @testset "the players show once the file is there, and a file that can't be got is tried again" begin
    rm(joinpath(web, "hold"))
    @test settle(() -> player("![Bathroom]") !== nothing && shown("![Another note]").failed)
    first, rest = player("![Bathroom]"), player("![The rest of it]")
    @test first.path == rest.path == K.media_file("$site/media/later.mov")
    @test read(first.path) == read(joinpath(dir, "walk.mov")) && !isfile(first.path * ".part")
    @test (first.from, first.to) == (0.0, 1.0) && (rest.from, rest.to) == (1.0, Inf)
    @test shown("![Another note]").words == "Ladder couldn't get the sound. It tries again in a minute."
    # The web has the sound now. Ladder asks for it again when a minute has gone, and not before.
    cp(joinpath(dir, "note.m4a"), joinpath(web, "lost.m4a"))
    frames()
    @test shown("![Another note]") isa K.MediaNote && length(calls("lost.m4a")) == 1
    K.downloads[K.media_file("$site/media/lost.m4a")] -= K.RETRY
    @test settle(() -> shown("![Another note]") isa K.SoundLine)
    @test length(calls("lost.m4a")) == 2 && length(calls("later.mov")) == 1
  end

  "The button of the top bar that makes the page's job"
  maker() = e.nodes[:job]
  "Click the button that makes the page's job"
  make() = (r = rect(maker()); click((K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))))
  bubble() = any(p -> p.key == :job, popups(w))

  @testset "the top bar has the button for a page that has a progress address" begin
    @test K.progress_address(e) == "$site/tasks?key=ab12"
    @test length(K.job_part(e)) == 2 && K.job_part(e)[1] === maker()
    @test K.tip(maker()) == "Make job in Centient" && !K.off(maker())
    for other in (plain, partly)
      K.open!(e, other); frames()
      @test K.progress_address(e) === nothing && isempty(K.job_part(e))
    end
    K.open!(e, page); frames()
  end

  @testset "a click asks Centient for the job and says what it made" begin
    make()
    asked = e.nodes[:job_ask]
    r = asked.request
    @test r.tool == "make_job_from_page" && !K.Centient.finished(r)
    # While Centient works, the words are under the button, and the button does nothing
    @test asked.said == "Making the job in Centient…" && bubble() && K.off(maker())
    @test K.tip(maker()) == "Making the job in Centient…"
    @test settle(() -> asked.request === nothing)
    @test r.value["asked"] == Dict("progress" => "$site/tasks?key=ab12", "title" => "12/40 Wattle Street", "page" => page,
                                   "property" => "12/40 Wattle Street, Dickson ACT 2602", "purpose" => "Ready for a new tenant")
    @test !asked.wrong && asked.said == "Centient has the job 12/40 Wattle Street in sample-co, with 10 tasks for 5 trades."
    # The words stay under the button for a few seconds, and they're its tooltip after that
    @test bubble() && !K.off(maker())
    asked.at -= K.JOB_SHOWS
    frames()
    @test !bubble() && K.tip(maker()) == asked.said
    # Centient has the job the next time. It says what it added, and then that there was nothing to add.
    make()
    @test settle(() -> !K.making(e))
    @test e.nodes[:job_ask].said == "Centient added 2 new tasks to the job 12/40 Wattle Street."
    make()
    @test settle(() -> !K.making(e))
    @test e.nodes[:job_ask].said == "Centient has this job already: 12/40 Wattle Street." && !e.nodes[:job_ask].wrong
    # The words are about the page that Centient was asked for, and no other
    K.open!(e, partly); frames()
    @test !bubble() && K.tip(maker()) == "Make job in Centient"
  end

  @testset "what Centient says went wrong shows under the button" begin
    K.open!(e, far); frames()
    @test K.job_args(e) == Dict("progress" => "http://unreachable:9330/walkthrough/projects/7/tasks?key=cd34", "title" => "3 Far Road", "page" => far)
    make()
    @test settle(() -> !K.making(e))
    asked = e.nodes[:job_ask]
    @test asked.wrong && asked.said == "Couldn't reach the walkthrough service. Check the internet connection."
    @test bubble() && K.tip(maker()) == asked.said
  end

  @testset "on a Mac that has no Centient the button does nothing, and says why" begin
    K.Centient.stop!()
    Core.eval(K.Centient, :(available() = false))
    asked = e.nodes[:job_ask]
    frames()
    @test K.off(maker()) && K.tip(maker()) == "Centient isn't on this Mac"
    make()
    @test e.nodes[:job_ask] === asked && !K.making(e)
    # Centient is looked for again, for the tests that share this process
    Core.eval(K.Centient, :(available() = sidecar() !== nothing))
  end
end
