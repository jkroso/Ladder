# Tests for main.jl's "a cover picture": a `cover` key in the front matter puts
# a picture across the top of the page. Run them with
# `julia -O0 --project=. test/cover_test.jl`. Set `LADDER_SHOTS` to a folder,
# and they save a picture of a page with a cover there.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect scene draw draw_tool window_tool
@use "github.com/jkroso/UI.jl/Interface/save" save_png
const px = K.px

# The folder is the test's own each time, so that two test processes that run at once don't write the same files
const dir = mktempdir()
mkpath(joinpath(dir, "photos"))
cp(joinpath(@__DIR__, "..", "pages", "photos", "3 roof.png"), joinpath(dir, "photos", "roof.png"))
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "kitchen.md")
write(page, """
---
title: Kitchen
cover: photos/roof.png
---

# Kitchen

The new bench goes in on Monday.""")

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames(4)
e.buf.anchor = e.buf.caret = (8, 0); K.touch!(e); frames(3)
top() = K.item(e, 1).content.node
again(text) = (write(page, text); K.refresh!(e.buf); frames(3); top())

@testset "a cover goes across the top of the page, over the card" begin
  c = top()
  @test c isa K.CoverPicture
  @test c.wide == e.width && c.tall == min(e.width / 3, K.COVER_MOST)
  @test endswith(c.key, "roof.png")
  # The card under it has the other keys, and not the cover
  @test c.card isa K.MatterCard && [k for (_, k, _) in c.card.rows] == ["title"]
  # The picture is as wide as the page's text, and the card is under it
  r, card = rect(c), rect(c.card)
  @test r !== nothing && card !== nothing && card.top > r.top + c.tall
  @test abs(K.num(r.width) - K.num(e.width)) < 1
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "cover.png"), w.size) do ctx, size
    draw(ctx, size, scene(w))
  end
end

@testset "front matter with only a cover shows only the picture" begin
  c = again("---\ncover: photos/roof.png\n---\n\nWords.")
  @test c isa K.CoverPicture && c.card === nothing
end

@testset "a cover that isn't there shows the card as it's written" begin
  c = again("---\ntitle: Kitchen\ncover: photos/gone.png\n---\n\nWords.")
  @test c isa K.MatterCard && [k for (_, k, _) in c.rows] == ["title", "cover"]
  # A quoted name is the same name
  c = again("---\ncover: \"photos/roof.png\"\n---\n\nWords.")
  @test c isa K.CoverPicture
end

@testset "a page as HTML has the cover at its top" begin
  again("---\ntitle: Kitchen\ncover: photos/roof.png\n---\n\n# Kitchen")
  html = K.page_html(e)
  @test occursin("<img class=\"cover\" src=\"photos/roof.png\" alt=\"\">", html)
  @test findfirst("class=\"cover\"", html)[1] < findfirst("<h1", html)[1]
  @test !occursin("title: Kitchen", html)
end

close(w)
