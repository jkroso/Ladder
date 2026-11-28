# Tests for canvas.jl. Run them with `julia -O0 --project=. test/canvas_test.jl`.

@use Test: @test, @testset
@use "../blocks/canvas" => C

const BLOCK = ["text size 28 60,20 Kitchen",
               "note 60,80 Buy the tiles  before Friday",
               "note width 260 340,80 Ring the plumber",
               "  about the sink",
               "",
               "picture width 240 60,240 .media/pasted one.png",
               "page 340,240 [[Kitchen plan]]",
               "link 620,240 https://www.bunnings.com.au/tiles",
               "pen blue 12,30 14,32 18,40 25,44",
               "join 2 3",
               "join 3 9",
               "star 1,1",
               "picture 5,5"]

"Every card is 100 wide and 50 tall"
same(_) = (100.0, 50.0)

@testset "reading and writing" begin
  c = C.canvas(BLOCK)
  @test [k.kind for k in c.cards] == [:text, :note, :note, :picture, :page, :link]
  @test c.cards[1].size == 28 && c.cards[1].width == 0 && c.cards[1].at == (60.0, 20.0)
  # The words of a note keep the spaces inside them, and a line that starts with two spaces goes on with them
  @test c.cards[2].content == "Buy the tiles  before Friday" && c.cards[3].content == "Ring the plumber\nabout the sink"
  @test c.cards[3].width == 260 && c.cards[2].width == C.WIDTHS.note
  @test c.cards[4].content == ".media/pasted one.png" && c.cards[5].content == "Kitchen plan"
  @test length(c.strokes) == 1 && c.strokes[1].colour == :blue
  @test length(c.joins) == 1 && c.joins[1][1] === c.cards[2] && c.joins[1][2] === c.cards[3]
  # A join to a card that isn't there, a kind that isn't known and a picture with no file are kept as they are
  @test c.other == ["join 3 9", "star 1,1", "picture 5,5"]
  @test C.written(c) == ["text size 28 60,20 Kitchen", "note 60,80 Buy the tiles  before Friday",
                         "note width 260 340,80 Ring the plumber", "  about the sink",
                         "picture 60,240 .media/pasted one.png", "page 340,240 Kitchen plan",
                         "link 620,240 https://www.bunnings.com.au/tiles", "pen blue 12,30 14,32 18,40 25,44",
                         "join 2 3", "join 3 9", "star 1,1", "picture 5,5"]
  @test C.written(C.canvas(C.written(c))) == C.written(c)
  # A colour comes after the kind. Anywhere else it's one of the words.
  d = C.canvas(["text red 5,5 Hello", "note 5,5 red alert", "note 1,2"])
  @test d.cards[1].colour == :red && d.cards[2].colour == :ink && d.cards[2].content == "red alert"
  # A note can be empty, and its words can start on its second line
  @test d.cards[3].content == "" && C.written(d)[3] == "note 1,2"
  e = C.Canvas(); push!(e.cards, C.Card(:note, (0, 0), "\nsecond"))
  @test C.written(e) == ["note 0,0", "  second"] && C.canvas(C.written(e)).cards[1].content == "\nsecond"
  # A line of words that would start a fence gets more spaces, so it never ends the block
  push!(e.cards, C.Card(:note, (0, 0), "first\n```julia"))
  @test C.written(e)[4] == "    ```julia"
  # Numbers that are too big or too small become the nearest that they can be
  @test C.read_card("note width 5 1,1 x").width == 40 && C.read_card("text size 999 1,1 x").size == 200
  @test C.read_card("text width 0 1,1 x").width == 0 && C.read_card("note width -3 1,1 x").width == 40
end

@testset "joins after a card goes" begin
  c = C.canvas(["note 0,0 a", "note 200,0 b", "note 400,0 c", "join 1 2", "join 2 3", "join 1 3"])
  a, b, k = c.cards
  C.remove!(c, b)
  @test c.cards == [a, k] && length(c.joins) == 1 && C.written(c)[end] == "join 1 2"
  @test !C.join!(c, a, k) && !C.join!(c, k, a) && !C.join!(c, a, a)
  @test C.unjoin!(c, k, a) && isempty(c.joins)
  @test C.join!(c, k, a) && C.written(c)[end] == "join 2 1"
end

@testset "where things are" begin
  c = C.canvas(["note 0,0 a", "note 300,0 b", "note 300,200 c", "join 1 2", "join 1 3", "pen 10,300 50,340"])
  a, b, k = c.cards
  @test C.extent(c, same) == (0.0, 0.0, 400.0, 340.0)
  @test C.card_at(c, (50, 25), same) === a && C.card_at(c, (150, 25), same) === nothing
  # A line between cards side by side leaves the middle of the right side and comes to the middle of the left
  curve = C.join_curve(C.edges(a, same(a)), C.edges(b, same(b)))
  @test curve[1] == (100.0, 25.0) && curve[4] == (300.0, 25.0)
  # One card under another: the line goes from the bottom to the top
  low = C.Card(:note, (0, 200)); up = C.join_curve(C.edges(a, same(a)), C.edges(low, same(low)))
  @test up[1] == (50.0, 50.0) && up[4] == (50.0, 200.0)
  @test C.join_at(c, (200, 25), same) === c.joins[1] && C.join_at(c, (200, 100), same) === nothing
  @test C.stroke_at(c, (30, 320)) === c.strokes[1]
  @test C.parent_of(c, b) === a && C.parent_of(c, a) === nothing && C.children_of(c, a) == [b, k]
  # A new card joined from `a` goes right of it, under the cards that it joins to, where no card is
  p = C.child_place(c, a, (100.0, 50.0), same)
  @test p == (156.0, 270.0) && !C.covers(c, p, (100.0, 50.0), same)
  # Under a card, as near as no card covers
  @test C.sibling_place(c, b, (100.0, 50.0), same) == (300.0, 70.0)
  q = C.free_place(c, (300.0, 10.0), (100.0, 50.0), same)
  @test q[1] == 300 && !C.covers(c, q, (100.0, 50.0), same)
end

@testset "a picture for a page of HTML" begin
  c = C.canvas(["text 0,0 Title & more", "note 0,40 a", "picture 200,0 p.png", "join 2 3", "pen red 0,100 50,150"])
  colours = (ink="#222", red="#c00", blue="#00c", green="#0c0", orange="#f80", card="#fff", edge="#ddd", join="#999", dim="#777")
  out = C.svg(c; size=same, lines=k -> split(k.content, '\n'), source=k -> k.content, colours)
  @test startswith(out, "<svg") && endswith(out, "</svg>")
  @test occursin("Title &amp; more", out) && occursin("<image href=\"p.png\"", out) && occursin("<path d=\"M", out)
  @test occursin("stroke=\"#c00\"", out)
end
