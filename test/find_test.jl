# Tests for find.jl. Run them with `julia -O0 --project=. test/find_test.jl`.

@use Test: @test, @testset
@use "../blocks/find" => F

const PAGE = ["---", "title: Call the plumber", "---",
              "# The **Kitchen** job", "",
              "- [x] Call the plumber",
              "- [ ] Call the *plumber* again",
              "  - [ ] Order the tap",
              "The plumber is Sam.",
              "```",
              "- [ ] plumber in code",
              "```",
              "| Trade | Who |",
              "## Later"]

texts(ms) = [m.text for m in ms]

@testset "reading and writing" begin
  q = F.query(["what: done items", "with: Plumber  tap", "in: jobs/2026", "sort: newest"])
  @test q.what == :done && q.with == ["Plumber", "tap"] && q.folder == "jobs/2026" && q.other == ["sort: newest"]
  @test F.written(q) == ["what: done items", "with: Plumber tap", "in: jobs/2026", "sort: newest"]
  # An empty block lists the to-do items, and words by themselves are the words to find
  @test F.kind(F.query(String[])) == :todo && isempty(F.written(F.query(String[])))
  bare = F.query(["plumber"])
  @test bare.with == ["plumber"] && F.kind(bare) == :line && F.written(bare) == ["with: plumber"]
  @test F.query(["headings"]).what == :heading && F.query(["what: todos"]).what == :todo && F.query(["what: lines"]).what == :line
end

@testset "what matches" begin
  find(lines...) = F.matches(F.query(collect(lines)), "/notes/job.md", PAGE)
  @test texts(find()) == ["Call the plumber again", "Order the tap"]
  @test [m.line for m in find()] == [7, 8] && all(m -> m.kind == :todo && m.path == "/notes/job.md", find())
  @test texts(find("what: done items")) == ["Call the plumber"]
  @test texts(find("headings")) == ["The Kitchen job", "Later"]
  # Every word has to be in the line, in any case. Code and front matter aren't the page's text.
  @test texts(find("PLUMBER")) == ["Call the plumber", "Call the plumber again", "The plumber is Sam."]
  @test texts(find("plumber sam")) == ["The plumber is Sam."] && isempty(find("plumber electrician"))
  @test texts(find("what: to-do items", "with: plumber")) == ["Call the plumber again"]
  @test texts(find("trade")) == ["| Trade | Who |"]
end

@testset "a line that moved, and its tick" begin
  m = F.matches(F.Query(), "job.md", PAGE)[2]
  @test F.locate(m, PAGE) == 8
  @test F.locate(m, ["A new line"; PAGE]) == 9 && F.locate(m, PAGE[4:end]) == 5
  @test F.locate(m, replace(PAGE, "  - [ ] Order the tap" => "  - [x] Order the tap")) === nothing
  @test F.locate(m, ["# Nothing"]) === nothing
  @test F.ticked("  - [ ] Order the tap", true) == "  - [x] Order the tap" && F.ticked("- [x] Ça va [here]", false) == "- [ ] Ça va [here]"
  @test F.ticked("no box", true) == "no box"
end

@testset "what the list is of, in words" begin
  @test F.summary(F.Query(), 3, 2) == "3 to-do items in 2 pages of this folder" && F.summary(F.Query(), 1, 1) == "1 to-do item in 1 page of this folder"
  @test F.summary(F.query(["plumber sam"]), 2, 1) == "2 lines with “plumber sam” in 1 page of this folder"
  @test F.summary(F.query(["headings"]), 0, 0) == "No headings in this folder"
  @test F.summary(F.query(["in: jobs"]), 2, 1) == "2 to-do items in 1 page of the folder jobs" && F.summary(F.query(["done", "in: jobs"]), 0, 0) == "No items that are done in the folder jobs"
end

const MIXED = ["# Plans",
               "A paragraph with a [link](https://example.com).",
               "- A bullet",
               "1. A numbered item",
               "> A quote",
               "| Trade | Who |",
               "|---|---|",
               "| Plumber | Sam |",
               "![The ground floor](plans/ground.png)",
               "![](plans/roof.png)",
               "See https://example.com/roof today[^1]",
               "## Ground floor",
               "```takeoff",
               "plan: ground.pdf",
               "```",
               "```julia",
               "",
               "area = 3 * 4",
               "```",
               "```mermaid",
               "```",
               "## Timing",
               "```schedule",
               "start: 2026-11-17",
               "```"]

@testset "the kinds of line" begin
  find(what, words...) = texts(F.matches(F.query(["what: $what", words...]), "job.md", MIXED))
  @test find("paragraphs") == ["A paragraph with a link.", "See https://example.com/roof today1"]
  @test find("bullet points") == ["A bullet"] && find("numbered items") == ["A numbered item"] && find("quotes") == ["A quote"]
  # The line of dashes under a table's headings isn't a row
  @test find("table rows") == ["| Trade | Who |", "| Plumber | Sam |"]
  # A picture isn't a link, and neither is a footnote. A picture reads as its words, or as the name of its file.
  @test find("links") == ["A paragraph with a link.", "See https://example.com/roof today1"]
  @test find("pictures") == ["The ground floor", "roof.png"] && find("images", "with: roof") == ["roof.png"]
  @test find("lines", "with: ground") == ["The ground floor", "Ground floor"]
  # Each kind has a name of its own, and a block that names a kind by any of its names is read as that kind
  names = [n for k in keys(F.WHATS) for n in F.WHATS[k].names]
  @test allunique(names) && all(k -> F.query(["what: " * F.WHATS[k].names[1]]).what == k, keys(F.WHATS))
  @test F.title(:todo) == "To-do items" && F.title(:blockquote) == "Quotes" && F.what("Images") == :picture
end

@testset "the kinds of block" begin
  find(lines...) = F.matches(F.query(collect(lines)), "job.md", MIXED)
  # A block is listed by the heading that it's under, at the line that opens it
  @test [(m.line, m.text, m.kind) for m in find("takeoffs")] == [(13, "Ground floor", :takeoff)]
  @test [(m.line, m.text, m.kind) for m in find("what: schedules")] == [(23, "Timing", :schedule)]
  # Code is listed by its own first line, and a block that's a component isn't code
  @test [(m.line, m.text, m.kind) for m in find("code blocks")] == [(16, "area = 3 * 4", :code)]
  @test texts(find("diagrams")) == ["Ground floor"] && isempty(find("boards"))
  # The words can be in the heading, or in the lines of the block
  @test texts(find("takeoffs", "with: ground.pdf")) == ["Ground floor"] && texts(find("takeoffs", "with: floor")) == ["Ground floor"]
  @test isempty(find("takeoffs", "with: roof")) && isempty(find("schedules", "with: ground"))
  # A block with no heading over it shows its first line, and an empty one shows what it is. Front matter is no block.
  @test texts(F.matches(F.query(["charts"]), "a.md", ["```chart", "", "kind: bar", "```"])) == ["kind: bar"]
  @test texts(F.matches(F.query(["charts"]), "a.md", ["```chart", "```"])) == ["Chart"]
  @test isempty(F.matches(F.query(["code blocks"]), "a.md", ["---", "title: A", "---", "Text"]))
  # A block that moved is found where it is now, and a list of lines has no blocks
  m = find("takeoffs")[1]
  @test F.locate(m, ["New"; MIXED]) == 14 && F.locate(m, MIXED[1:11]) === nothing
  @test F.locate(find("what: lines", "with: bullet")[1], ["New"; MIXED]) == 4
  @test !any(m -> F.isblock(m.kind), find("what: lines"))
end

@testset "what a list counts, and what it calls its kinds" begin
  todo, done = F.Match("a.md", 1, "Ring Sam", :todo), F.Match("a.md", 1, "Ring Sam", :done)
  @test F.counted(F.Query(), todo) && !F.counted(F.Query(), done) && F.counted(F.query(["links"]), done) && F.counted(F.query(["lines"]), done)
  @test F.summary(F.query(["takeoffs"]), 3, 2) == "3 takeoffs in 2 pages of this folder"
  @test F.summary(F.query(["links", "with: roof"]), 1, 1) == "1 line with a link with “roof” in 1 page of this folder"
  @test F.summary(F.query(["changes"]), 0, 0) == "No sets of changes in this folder"
end
