# Tests for notes.jl: the links between the pages of a folder of notes. Run
# them with `julia -O0 --project=. test/notes_test.jl`. They draw no window.

@use Test: @test, @testset
@use "../folders/notes" => N

const dir = mktempdir()
const root = joinpath(dir, "Notes")
mkpath(joinpath(root, "plans", "old"))
mkpath(joinpath(root, ".hidden"))
page(rel, text) = (path = joinpath(root, rel); write(path, text); path)

const home = page("Home.md", "# Home\n\nSee [[Ideas]], [[ideas|the same page]] and [[Garden#Beds|the beds]].\n\nAlso [[Missing page]] and [[plan.pdf]].\n")
const ideas = page("Ideas.md", "# Ideas\n\nBack to [[Home]]. A link to [a plan](plans/Garden.md) and to [the web](https://example.com/page.md).\n")
const garden = page("plans/Garden.md", "# Garden\n\n```\n[[Not a link]]\n```\n\nCode like `[[Nor this]]` is no link. [[Shed]] is beside this page. [Up](../Ideas.md#top).\n")
const shed = page("plans/Shed.md", "# Shed\n\n[[Missing page]] again, and [[#A heading of this page]].\n")
const shed2 = page("plans/old/Shed.md", "# The old shed\n\n[[Shed]] is this page itself, since it's beside it.\n")
const alone = page("Alone.md", "# Alone\n")
page(".hidden/Secret.md", "[[Home]]\n")
write(joinpath(root, "list.csv"), "a,b\n")

@testset "the links of a page" begin
  @test N.links("See [[Ideas]] and [[Ideas#Plans]] and [[ plans/Garden | the garden ]].") == ["Ideas", "plans/Garden"]
  @test N.links("[a](b.md) [c](<d e.md>) [web](https://x.org/y.md) [pic](z.png) [h](f.md#top \"Title\")") == ["b.md", "f.md"]
  @test N.links("```julia\n[[no]]\n```\n[[yes]]\n~~~\n[[no]]\n~~~\n") == ["yes"]
  @test N.links("`[[no]]` and [[#only a heading]] and [[]]") == []
end

@testset "the pages of a folder, without its hidden folders" begin
  @test N.pages(root) == [alone, home, ideas, garden, shed, shed2]
end

const w = N.web(root)

@testset "which pages link to which" begin
  @test [n.name for n in w.notes] == ["Alone", "Garden", "Home", "Ideas", "Shed", "Shed"]
  @test w.to[home] == [ideas, garden]
  @test w.to[ideas] == [home, garden]
  @test N.linked_from(w, garden) == [home, ideas]
  @test N.linked_from(w, home) == [ideas]
  @test N.linked_from(w, ideas) == [garden, home]
  # A name finds the page beside the page with the link, before one nearer the top
  @test N.linked_from(w, shed) == [garden]
  @test N.linked_from(w, shed2) == []   # a page's link to itself is no link
  @test N.linked_from(w, alone) == []
end

@testset "the pages that no page links to" begin
  @test [n.path for n in N.loose(w)] == [alone, shed2]
end

@testset "the names that no page has" begin
  @test w.wanted == ["Missing page" => [home, shed]]
end

@testset "the pages that changed last" begin
  sleep(1.1)
  write(alone, "# Alone\n\nNow with a link to [[Shed]].\n")
  later = N.web(root)
  @test N.latest(later, 1)[1].path == alone
  # The page was read again, since its file changed. Its name finds the shed nearest the top.
  @test N.linked_from(later, shed) == [alone, garden]
  @test N.folder(later, shed2) == "plans/old" && N.folder(later, alone) == ""
end
