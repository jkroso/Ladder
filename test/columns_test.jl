# Tests for columns.jl: what a `columns` block says, which blocks of the page
# it puts in columns, and how wide each column is. Run them with
# `julia -O0 --project=. test/columns_test.jl`.

@use Test: @test, @testset
@use "../blocks/columns" => C
@use "../markdown" Kind classify

page(text) = String.(split(text, '\n'))
groups(text; alone=i -> false) = (lines = page(text); C.groups(lines, classify(lines); alone))
"The lines of each column of the first group of a page, as text"
columns(text; alone=i -> false) = (lines = page(text); g = first(C.groups(lines, classify(lines); alone)); [lines[span] for span in g.spans])

@testset "what the block says" begin
  # One number is how many columns there are
  @test C.shares(["3"]) == [1.0, 1.0, 1.0] && C.shares(["", "  2 ", ""]) == [1.0, 1.0] && C.shares(["1"]) == [1.0]
  # Several numbers are the share of each column, with spaces or commas between them, on one line or more
  @test C.shares(["2 1"]) == [2.0, 1.0] && C.shares(["2, 1,1"]) == [2.0, 1.0, 1.0] && C.shares(["1.5", "1"]) == [1.5, 1.0]
  @test C.shares(["3 3"]) == [3.0, 3.0]   # two numbers are two shares, not a count
  # Lines that say nothing, or something wrong
  @test C.shares(String[]) === nothing && C.shares([""]) === nothing && C.shares(["three"]) === nothing
  @test C.shares(["0"]) === nothing && C.shares(["-2"]) === nothing && C.shares(["2 0"]) === nothing && C.shares(["2.5"]) === nothing
  @test C.shares(["widths: 2, 1"]) === nothing && C.shares(["Inf"]) === nothing && C.shares(["NaN 1"]) === nothing
  # No more columns than a page has room for
  @test C.shares(["12"]) == fill(1.0, 12) && C.shares(["13"]) === nothing && C.shares([join(fill("1", 13), ' ')]) === nothing
end

const THREE = """
Before.

```columns
3
```

First block of the page,
on two lines.

- Second block,
- a list.

| Third | block |
|---|---|
| a | table |

After."""

@testset "the blocks after it are the columns" begin
  g = only(groups(THREE))
  @test (g.first, g.last) == (3, 5) && g.shares == [1.0, 1.0, 1.0] && g.spans == [7:8, 10:11, 13:15]
  # A column shows the empty lines between its block and the next column. The last column ends with its block.
  @test [C.reach(g, k) for k in 1:3] == [7:9, 10:12, 13:15]
  # The language `column` means the same
  @test only(groups(replace(THREE, "```columns" => "```column"))).spans == g.spans
  # Each kind of block is one column
  @test columns("```columns\n6\n```\n> a quote\n> goes on\n1. one\n- [ ] two\n```julia\nx = 1\n\ny = 2\n```\n| a |\n|---|\ntext\n# Heading") ==
        [["> a quote", "> goes on"], ["1. one", "- [ ] two"], ["```julia", "x = 1", "", "y = 2", "```"], ["| a |", "|---|"], ["text"], ["# Heading"]]
  # An empty line ends a paragraph and a list, so each part is a column
  @test columns("```columns\n3\n```\none\n\ntwo\n\n- three") == [["one"], ["two"], ["- three"]]
  # A line that's a block by itself, like a picture, is a column, and splits the text round it
  lines = page("```columns\n3\n```\nabove\n![a](a.png)\nbelow")
  @test columns(join(lines, '\n'), alone=i -> startswith(lines[i], "![")) == [["above"], ["![a](a.png)"], ["below"]]
  @test columns(join(lines, '\n')) == [["above", "![a](a.png)", "below"]]
  # A code block that nothing closes runs to the end of the page
  @test columns("```columns\n2\n```\na\n\n```julia\nx = 1\n\n# not a heading") == [["a"], ["```julia", "x = 1", "", "# not a heading"]]
end

@testset "fewer blocks, more blocks, and what's wrong" begin
  # The columns hold the blocks that there are, and the block still asks for three
  g = only(groups("```columns\n3\n```\n\none\n\ntwo\n"))
  @test g.spans == [5:5, 7:7] && length(g.shares) == 3
  @test isempty(only(groups("```columns\n3\n```\n")).spans)
  # The blocks after the last column are no part of the group
  @test only(groups("```columns\n2\n```\na\n\nb\n\nc")).spans == [4:4, 6:6]
  # One column, an empty block and a wrong one put nothing in columns. The block is still found.
  for inner in ("1", "", "lots", "2 x")
    g = only(groups("```columns\n$inner\n```\n\na\n\nb"))
    @test isempty(g.spans) && (g.first, g.last) == (1, 3)
  end
  @test only(groups("```columns\nlots\n```\na")).shares == Float64[] && only(groups("```columns\n1\n```\na")).shares == [1.0]
  # A block that nothing closes is no block of columns, and a page without one has no groups
  @test isempty(groups("```columns\n2\n\na\n\nb")) && isempty(groups("# A page\n\nwith text")) && isempty(groups(""))
  # A `columns` line in another block's code is code
  @test isempty(groups("```julia\n```columns\n2\n```"))
  # Another `columns` block ends the group, and starts its own
  gs = groups("```columns\n3\n```\na\n\n```columns\n2 1\n```\nb\n\nc\n\nd")
  @test length(gs) == 2 && gs[1].spans == [4:4] && gs[2].spans == [9:9, 11:11] && gs[2].shares == [2.0, 1.0]
  # A line across the page ends the group too. It's in no column.
  @test only(groups("```columns\n3\n```\na\n\n---\n\nb")).spans == [4:4]
  @test isempty(only(groups("```columns\n3\n```\n***\n\na\n\nb")).spans)
end

const OPTIONS = """
```columns
3
```

### Option A

Cheapest.

- Two days

### Option B

Lasts longer.

- Three days

### Option C

Both.

---

This paragraph is under the columns."""

@testset "a heading takes the blocks under it into its column" begin
  g = only(groups(OPTIONS))
  @test g.spans == [5:9, 11:15, 17:19]
  @test columns(OPTIONS)[1] == ["### Option A", "", "Cheapest.", "", "- Two days"]
  # The line across the page ends the last column, and is in none
  @test columns(OPTIONS)[3] == ["### Option C", "", "Both."] && [C.reach(g, k) for k in 1:3] == [5:10, 11:16, 17:19]
  # A lower heading stays in the column
  @test columns("```columns\n2\n```\n## A\ntext\n### Lower\n#### Lower still\nmore\n## B\ntext") ==
        [["## A", "text", "### Lower", "#### Lower still", "more"], ["## B", "text"]]
  # A higher heading ends the column, as one of the same level does, and takes the lower ones after it
  @test columns("```columns\n3\n```\n### A\na\n# Top\nb\n### C") == [["### A", "a"], ["# Top", "b", "### C"]]
  # A heading of the same level that's past the count ends the group
  g = only(groups("```columns\n2\n```\n### A\na\n### B\nb\n\n- item\n### C\nc"))
  @test g.spans == [4:5, 6:9]
  # The end of the page, and another `columns` block, end a heading's column
  @test columns("```columns\n2\n```\n# A\na\n\nb") == [["# A", "a", "", "b"]]
  @test columns("```columns\n2\n```\n# A\na\n```columns\n2\n```\nb") == [["# A", "a"]]
  # A code block under a heading is in the column whole, with the # and the --- in its code
  @test columns("```columns\n2\n```\n# A\n```\n# code\n---\n```\ntext\n# B") == [["# A", "```", "# code", "---", "```", "text"], ["# B"]]
  # A heading column and a column of one block
  @test columns("```columns\n3\n```\n### A\ntext\n\n- item\n### B\n\nA paragraph.") == [["### A", "text", "", "- item"], ["### B", "", "A paragraph."]]
  @test columns("```columns\n3\n```\nA paragraph.\n\n### A\ntext\n\n- item\n\n### B") == [["A paragraph."], ["### A", "text", "", "- item"], ["### B"]]
  @test columns("```columns\n3\n```\n- a list\n\nA paragraph.\n\n### A\ntext\n\nmore") == [["- a list"], ["A paragraph."], ["### A", "text", "", "more"]]
end

@testset "the room of each column" begin
  @test C.rooms([1.0, 1.0], 700, 20) == [340.0, 340.0] && C.rooms([2.0, 1.0], 620, 20) == [400.0, 200.0]
  @test C.rooms([1.0, 2.0, 1.0], 440, 20) == [100.0, 200.0, 100.0] && sum(C.rooms([1.0, 2.0, 1.0], 440, 20)) + 40 == 440
  # A width that's less than the gaps leaves no room, and never less than none
  @test C.rooms([1.0, 1.0, 1.0], 10, 20) == [0.0, 0.0, 0.0] && isempty(C.rooms(Float64[], 100, 20))
  # A narrow page shows the blocks one under another. Bigger text needs a wider page.
  @test C.stacked(519) && !C.stacked(520) && !C.stacked(780) && C.stacked(600, 1.2) && !C.stacked(600, 1.1)
end
