# Tests for the spelling of the page: the red dots under a word that's spelt
# wrong, and what the page's menu does with it. See "spelling" in page_extras.jl. Run
# them with `julia -O0 --project=. test/spelling_test.jl`. They draw in a window that
# isn't on the screen. They teach the Mac's dictionary a made-up word, and they
# take it out again at the end.

@use Test: @test, @testset
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/UI.jl/Interface/objc" msg nsstring with_pool
@use "../spelling" => Spelling
@use "../main" => K
const px = K.px

const WORD = "Zorblatixen"   # a word that no dictionary has
const dir = mktempdir()
const page = joinpath(dir, "notes.md")
write(page, "# Notes\n\nA $WORD here, and a [$WORD](https://example.com) there.\n\nA sentance to fix.\n")

"A window that shows `path`"
window(path) = begin
  e = K.build_editor(path)
  w = K.window!(e, title="test", size=(1100px, 800px))
  frame(w)
  e, w
end

"The word at columns `lo` to `hi` of line `i`"
word(e, i, lo, hi) = K.rest(K.head(e.buf.lines[i], hi), lo)

@testset "Julia's filter! isn't hidden by one of Ladder's own" begin
  # A function of main.jl named filter! hid Julia's from all of main.jl, so Learn Spelling failed
  @test K.filter! === Base.filter!
end

@testset "Learn Spelling takes the dots away from the word, everywhere on the page" begin
  try
    e, w = window(page)
    @test e.spelling
    i = findfirst(l -> occursin(WORD, l), e.buf.lines)
    e.buf.caret = e.buf.anchor = (length(e.buf.lines), 0)   # the caret isn't in a word that's checked
    wrongs = K.misspellings(e, i)
    @test length(wrongs) == 2
    @test all(((lo, hi),) -> word(e, i, lo, hi) == WORD, wrongs)
    wrong = K.misspelling_at(e, (i, wrongs[1][1] + 1))
    @test wrong == (i, wrongs[1]...)
    fixes = first(K.guesses(WORD), 5)
    # Learn Spelling comes after the guesses, or after "No Guesses Found" when there are none
    K.spell_act!(e, wrong, fixes, max(1, length(fixes)) + 1)
    frame(w)
    @test isempty(K.misspellings(e, i))
    close(K.window_of(e))
  finally
    with_pool(() -> msg(Spelling.checker(), "unlearnWord:", nsstring(WORD)))
  end
  @test !isempty(Spelling.misspelt("A $WORD here."))   # the Mac's dictionary is as it was
end

@testset "a guess from the menu takes the place of the word" begin
  e, w = window(page)
  i = findfirst(l -> occursin("sentance", l), e.buf.lines)
  e.buf.caret = e.buf.anchor = (1, 0)
  (lo, hi) = only(K.misspellings(e, i))
  wrong = K.misspelling_at(e, (i, lo + 1))
  fixes = first(K.guesses("sentance"), 5)
  @test "sentence" in fixes
  K.spell_act!(e, wrong, fixes, findfirst(==("sentence"), fixes))
  frame(w)
  @test e.buf.lines[i] == "A sentence to fix."
  @test isempty(K.misspellings(e, i))
  close(K.window_of(e))
end
