# Tests for the start of a page in a link's card, in main.jl: while ⌘ is held,
# the card of a link to a page shows the start of that page, as it reads. A
# link to a heading shows the part under that heading. A setting turns it off,
# and the card then says where the link goes. Run them with
# `julia -O0 --project=. test/page_peek_test.jl`. They use a window that isn't
# on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window Keys
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use "./drive" drive
"The words of each Text in the layout `x`, from the top"
texts(x) = begin
  hasfield(typeof(x), :content) && getfield(x, :content) isa AbstractString && return Any[x]
  out, c = Any[], hasfield(typeof(x), :firstchild) ? x.firstchild : nothing
  while c !== nothing
    append!(out, texts(c))
    c = c.nextsibling
  end
  out
end
const px = K.px

# The folder is the test's own each time, so that two test processes that run at once don't write the same files
const dir = mktempdir()
mkpath(joinpath(dir, ".git"))   # the top of the project
mkpath(joinpath(dir, "notes"))
K.SETTINGS_FILE[] = joinpath(dir, "settings")

# A page in another folder, with front matter and headings
const ideas = joinpath(dir, "notes", "Ideas.md")
write(ideas, """
---
title: Ideas
---

# Ideas

The first words of the page.

## Plans

Plan words.

### Detail

Detail words.

## Later

Later words.
""")

# A page that's longer than a card
const long = joinpath(dir, "Long.md")
write(long, join(["Line $n of a long page." for n in 1:200], "\n\n") * "\n")

const home = joinpath(dir, "home.md")
write(home, """
# Home

See [[Ideas]] for the page.

See [[Ideas#Plans|the plans]] for a part.

See [the file](notes/Ideas.md#later) by its path.

See [[Missing]], [the web](https://example.com) and [[Long]].

## Second

Words of the second part.

Back to [[#Second]].
""")

const e = K.build_editor(home)
const w = Window(e, size=(1000px, 800px))
const (; frames) = drive(w, frames=3, latest=true)
frames()
const b = e.buf
line(words) = findfirst(l -> occursin(words, l), b.lines)
"The place of `words` on the line that has `on`, a character into them"
at(on, words) = (i = line(on); (i, length(b.lines[i], 1, first(findfirst(words, b.lines[i])) - 1) + 1))
"The point of the window over the place `p` of the page"
point(p) = (it = K.item(e, p[1]); (e.origin[1] + K.spot(it.content, p[2])[2] + 1px, e.origin[2] + it.top + it.tall / 2))
"The link under the place `p`"
link(p) = (f = K.cmd_words(e, point(p)); f === nothing ? nothing : K.link_at(e, point(p)))
"The words of each line that the card shows"
words(card::K.PagePeek) = [join(s.text for vl in f.lines for s in vl.segs) for f in card.flows]
"The card of the link at the place `p`, as ⌘ and a rest of the mouse show it"
card(p) = K.peek_card(e, K.cmd_words(e, point(p)))

@testset "the page that a link goes to" begin
  @test K.linked_page(e, "[[Ideas]]") == (ideas, "")
  @test K.linked_page(e, "[[Ideas#Plans]]") == (ideas, "Plans")
  @test K.linked_page(e, "notes/Ideas.md#later") == (ideas, "later")
  @test K.linked_page(e, "[[#Second]]") == (home, "Second")
  # A page that isn't made yet, a web address, a footnote and a file of another kind go to no page
  @test K.linked_page(e, "[[Missing]]") === nothing
  @test K.linked_page(e, "https://example.com") === nothing
  @test K.linked_page(e, "^note") === nothing
  write(joinpath(dir, "plan.pdf"), "%PDF")
  @test K.linked_page(e, "[[plan.pdf]]") === nothing
end

@testset "the lines of the page that the card shows" begin
  lines, ks, shown = K.peek_page_lines(e, ideas, "")
  # From the top, after the front matter and the empty line
  @test lines[first(shown)] == "# Ideas" && lines[last(shown)] == "Later words."
  # A heading: to the next heading that's as big, with the smaller ones in it
  lines, ks, shown = K.peek_page_lines(e, ideas, "Plans")
  @test lines[shown] == ["## Plans", "", "Plan words.", "", "### Detail", "", "Detail words."]
  # A link names a heading as its words, or by its slug, in any case
  @test K.peek_page_lines(e, ideas, "later")[1][K.peek_page_lines(e, ideas, "later")[3]] == ["## Later", "", "Later words."]
  # A heading that isn't there shows the page from the top
  @test first(K.peek_page_lines(e, ideas, "Nowhere")[3]) == first(K.peek_page_lines(e, ideas, "")[3])
end

@testset "the card of a link to a page shows the start of the page" begin
  c = card(at("See [[Ideas]]", "Ideas"))
  @test c isa K.PagePeek
  @test "Ideas" in [t.content for t in texts(c.layout)]    # the page's name is over it
  shown = words(c)
  @test "The first words of the page." in shown && !any(l -> occursin("title:", l), shown)
  # A link to a heading: the heading's name after the page's, and only its part
  c = card(at("See [[Ideas#Plans", "the plans"))
  @test any(t -> occursin("Plans", t.content), texts(c.layout))
  @test "Plan words." in words(c) && "Detail words." in words(c) && !("Later words." in words(c))
  # A Markdown link by its path, and a link to a heading of this page
  @test "Later words." in words(card(at("See [the file]", "the file")))
  @test "Words of the second part." in words(card(at("Back to", "Second")))
  # A long page is cut: only as many lines as the card shows are laid out
  c = card(at("and [[Long]]", "Long"))
  @test 3 < length(c.flows) < 40 && sum(K.tall, c.flows) > K.PEEK_PAGE_HIGH
  # A page that's open shows as it is now, with what isn't saved
  K.edit!(b, (line("Words of the second"), 0), (line("Words of the second"), 0), "New ")
  @test "New Words of the second part." in words(card(at("Back to", "Second")))
  K.undo!(b)
  # A link that goes to no page says where it goes, in a dark box, as before
  said(c) = [t.content for t in texts(c)]
  @test said(card(at("See [[Missing]]", "Missing"))) == ["[[Missing]]"]
  @test said(card(at("[the web]", "the web"))) == ["https://example.com"]
end

@testset "the setting turns the start of the page off" begin
  K.peeks!(e, false)
  c = card(at("See [[Ideas]]", "Ideas"))
  @test !(c isa K.PagePeek) && [t.content for t in texts(c)] == ["[[Ideas]]"]
  # It's kept in the settings file, and read from it again
  e.remember = true
  K.peeks!(e, false)
  @test occursin("\npeeks=false\n", read(K.settings_file(), String))
  other = K.build_editor(home)
  K.load_settings!(other)
  @test other.peeks == false
  K.peeks!(e, true)
  e.remember = false
  @test card(at("See [[Ideas]]", "Ideas")) isa K.PagePeek
end

@testset "the card shows when the mouse rests on a link with ⌘ held, under the link, and goes when ⌘ comes up" begin
  p = at("See [[Ideas]]", "Ideas")
  w.mouse = typeof(w.mouse)(point(p)...)
  w.keys |= Keys.cmd
  frames(1)
  @test !K.cmd_card(e).peek.shown && !any(x -> x.key == :tooltip, popups(w))
  # The card waits for the mouse to move after ⌘ goes down
  w.mouse = typeof(w.mouse)(point(p)[1] + 1px, point(p)[2])
  frames(1)
  K.cmd_card(e).peek = (words=K.cmd_card(e).peek.words, since=time() - 1, shown=false)
  frames(1)
  tip = only(filter(x -> x.key == :tooltip, popups(w)))
  # The card is the page's own colours, not the dark box of a tooltip, and it's under the link
  @test !(tip.content isa K.Bubble) && tip.placement == :below
  frames(1)
  # It's beside the words of the link, and under them
  left, top, wide, high = tip.anchor
  @test left <= point(p)[1] <= left + wide && top <= point(p)[2] <= top + high
  haskey(ENV, "LADDER_SHOTS") && save_png(joinpath(ENV["LADDER_SHOTS"], "page-peek.png"), w)
  w.keys ⊻= Keys.cmd
  frames(1)
  @test K.cmd_card(e).peek === nothing && !any(x -> x.key == :tooltip, popups(w))
end

# The settings page has the box that turns it on and off
@testset "the settings page has the setting" begin
  text = read(joinpath(@__DIR__, "..", "pages", "settings", "settings.md"), String)
  @test occursin("page_peeks()", text) && occursin("page_peeks!(box.checked)", text)
end
