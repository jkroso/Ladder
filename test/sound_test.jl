# Tests for a line that holds only a sound file, and the Transcribe button
# under its player. See "sound in the text" in media_view.jl. Run them with
# `julia -O0 --project=. test/sound_test.jl`. They move the mouse in a window that isn't
# on the screen, and they don't transcribe anything. Set the environment
# variable LADDER_SHOTS to a folder to keep a picture of each step.

@use Test: @test, @testset
@use "github.com/jkroso/MiniFB.jl" Window MouseMove onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" parts
@use GeometryBasics: Vec2

@use "../main" => K
@use "./drive" drive
const px, num = K.px, K.num

const dir = mktempdir()
cp(joinpath(@__DIR__, "..", "pages", "hello.m4a"), joinpath(dir, "hello.m4a"))
cp(joinpath(@__DIR__, "..", "pages", "hello.m4a"), joinpath(dir, "again.m4a"))
const page = joinpath(dir, "sound.md")
write(page, """
# A sound

Some words over the player.

![A recording](hello.m4a)

Some words under the player.

![Another](again.m4a)
These words are right under the second player.
""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
const (; frames, at, shot) = drive(w, moved=2)
line(words) = findfirst(startswith(words), e.buf.lines)
# The caret is on no line, so each line shows as it reads
e.buf.reading = true
frames()

const sound = K.item(e, line("![A recording]")).content.node
const sound_path = joinpath(dir, "hello.m4a")
button() = get(e.nodes, (:transcribe, sound_path), nothing)
"Where the Transcribe button is in the window, or nothing while it doesn't show"
button_rect() = isempty(K.sound_over(e)) || button() === nothing ? nothing : rect(button())

@testset "a sound's line is only as tall as its player" begin
  @test sound isa K.SoundLine
  r = rect(sound)
  it = K.item(e, line("![A recording]"))
  # The player, and the gap that every live block has over it and under it. No room for the button.
  @test it.tall ≈ r.height + 2K.LIVE_GAP
  @test button_rect() === nothing
  shot("1-away.png")
end

@testset "the Transcribe button shows under the player while the mouse is over it, and takes no room" begin
  r = rect(sound)
  under = K.item(e, line("Some words under")).top
  at((num(r.left) + 200, num(r.top) + num(r.height) / 2))
  b = button_rect()
  @test b !== nothing
  # It's under the player's card. The speed button hangs off the card's bottom edge, at the right, so the player reaches lower.
  edge = K.card_bottom(K.recorder(sound.path).player)
  speeds = parts(K.recorder(sound.path).player)[5]
  @test edge < r.top + r.height
  @test b.left ≈ r.left && b.top ≈ edge + K.TRANSCRIBE_GAP
  @test b.left + b.width < speeds.left
  @test b.height ≈ K.TRANSCRIBE_H
  # The text under the player is where it was
  @test K.item(e, line("Some words under")).top == under
  @test K.item(e, line("![A recording]")).tall ≈ r.height + 2K.LIVE_GAP
  shot("2-over-the-player.png")
  # The mouse goes down from the player to the button, through the gap between them, and the button stays
  at((num(b.left) + 20, num(edge) + num(K.TRANSCRIBE_GAP) / 2))
  @test button_rect() !== nothing
  at((num(b.left) + 20, num(b.top) + num(b.height) / 2))
  @test button_rect() !== nothing
  @test K.ishovered(button())
  shot("3-over-the-button.png")
  # The button is over the gap, and doesn't reach the words under the player
  words = K.item(e, line("Some words under"))
  page_top = num(r.top) - num(K.item(e, line("![A recording]")).top) - num(K.LIVE_GAP)   # where the page's text starts in the window
  @test num(b.top + b.height) <= page_top + num(words.top) + 2
  # Away from the player, it goes
  at((num(r.left) + 200, num(r.top) - 60))
  @test button_rect() === nothing
end

@testset "the button of one player doesn't show for another" begin
  other = K.item(e, line("![Another]")).content.node
  @test other isa K.SoundLine && other !== sound
  r = rect(other)
  at((num(r.left) + 200, num(r.top) + num(r.height) / 2))
  @test !isempty(K.sound_over(e))
  b = rect(e.nodes[(:transcribe, other.path)])
  @test b.top ≈ K.card_bottom(K.recorder(other.path).player) + K.TRANSCRIBE_GAP
  shot("4-words-right-under.png")
  at((10, 10))
end

@testset "the button shows while macOS works, wherever the mouse is" begin
  work = mktempdir()
  # A program that stands in for the one that transcribes, and never finishes by itself
  t = K.Transcription(sound_path, run(`sleep 60`, wait=false), joinpath(work, "text"), joinpath(work, "progress"), 0.4, false, nothing, "")
  K.transcriptions[sound_path] = t
  at((10, 10))
  @test K.transcribing(sound_path)
  @test button_rect() !== nothing
  shot("5-working.png")
  kill(t.process)
  delete!(K.transcriptions, sound_path)
  frames()
  @test button_rect() === nothing
end

rm(dir, recursive=true)
