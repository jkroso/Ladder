# Tests for slides.jl. Run them with `julia -O0 --project=. test/slides_test.jl`.

@use Test: @test, @testset
@use "../page/slides" => S

"The lines that each slide of `page` shows, as text"
shown(page) = (lines = String.(split(page, '\n')); [join(lines[s.first:s.last], "\n") for s in S.slides(lines)])
"The slides of `page`: where each starts, and its first and last line"
spans(page) = [(s.start, s.first, s.last) for s in S.slides(String.(split(page, '\n')))]

@testset "a slide starts at each heading of level 1 or 2" begin
  page = "# The job\n\nA plan.\n\n## The site\n\n- Dig\n- Lay\n\n### Notes\n\nMore.\n\n## The cost\n"
  @test shown(page) == ["# The job\n\nA plan.", "## The site\n\n- Dig\n- Lay\n\n### Notes\n\nMore.", "## The cost"]
  @test spans(page) == [(1, 1, 3), (5, 5, 12), (14, 14, 14)]
  # A heading of level 3 or lower stays in its slide
  @test shown("### Small\n\nText.\n\n#### Smaller") == ["### Small\n\nText.\n\n#### Smaller"]
  # Two headings with nothing between them are two slides
  @test shown("# One\n## Two") == ["# One", "## Two"]
end

@testset "a line across the page starts a slide, and doesn't show" begin
  @test shown("# One\n\nText.\n\n---\n\nMore text.\n\n***\n\nThe end.") == ["# One\n\nText.", "More text.", "The end."]
  # The line and the empty lines after it belong to the slide that it starts
  @test spans("# One\n\n---\n\nTwo.") == [(1, 1, 1), (3, 5, 5)]
  # A line across the page with a heading after it starts one slide, not two
  @test shown("# One\n\n---\n\n## Two\n\nText.") == ["# One", "## Two\n\nText."]
  @test spans("# One\n\n---\n\n## Two\n\nText.") == [(1, 1, 1), (3, 5, 7)]
  # Two lines with nothing between them, and a line at the end, start no slide
  @test shown("One.\n\n---\n---\n\nTwo.\n\n---\n") == ["One.", "Two."]
  @test shown("---\n\n---") == String[]
end

@testset "what's before the first heading is the first slide" begin
  @test shown("Some words.\n\n# One") == ["Some words.", "# One"]
  @test shown("\n\n# One\n\nText.") == ["# One\n\nText."]
  @test shown("Only words.\nAnd more.") == ["Only words.\nAnd more."]
  @test shown("") == String[] && shown("\n \n") == String[]
end

@testset "front matter is never part of a slide" begin
  @test shown("---\ntitle: The job\n---\n\n# One\n\nText.") == ["# One\n\nText."]
  @test spans("---\ntitle: The job\n---\n\nWords.\n\n# One") == [(4, 5, 5), (7, 7, 7)]
  @test shown("+++\ntitle = \"The job\"\n+++\nWords.") == ["Words."]
  @test shown("---\ntitle: The job\n---\n") == String[]
end

@testset "a heading or a line in a code block starts no slide" begin
  page = "# Code\n\n```julia\n# A comment\n---\n```\n\n## After"
  @test shown(page) == ["# Code\n\n```julia\n# A comment\n---\n```", "## After"]
  # Nor does the line of dashes of a table
  @test shown("| a | b |\n|---|---|\n| 1 | 2 |") == ["| a | b |\n|---|---|\n| 1 | 2 |"]
end

@testset "the slide that a line is in" begin
  list = S.slides(String.(split("---\ntitle: x\n---\n\n# One\n\nText.\n\n---\n\nTwo.\n\n## Three", '\n')))
  @test [(s.start, s.first, s.last) for s in list] == [(4, 5, 7), (9, 11, 11), (13, 13, 13)]
  @test [S.number(list, i) for i in 1:13] == [1, 1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 3]
  @test S.number(list, 99) == 3
end

@testset "how much bigger a slide's text is" begin
  asked = Float64[]
  "A slide whose height is `high(scale)`, and a note of each scale that's measured"
  fit(high, room) = (empty!(asked); S.fit(s -> (push!(asked, s); high(s)), high(1.0), room))
  # Text alone is twice as tall when it's twice as big, so one guess is right
  @test fit(s -> 200s, 500) == 2.0 && asked == [2.0]
  @test fit(s -> 200s, 300) == 1.5 && asked == [1.5]
  # A slide that's too tall at the page's own size stays that size, and nothing is measured
  @test fit(s -> 700s, 600) == 1.0 && isempty(asked)
  @test fit(s -> 600s, 600) == 1.0
  # A picture stays the size it was, so the text beside it can be bigger than the first guess
  @test 1.9 <= fit(s -> 300 + 100s, 500) <= 2.0 && length(asked) <= 3
  @test fit(s -> 300 + 100s, 440) ≈ 1.4 atol=0.02
  # In a narrow window the words wrap again, so the slide is taller than the first guess makes it
  wrapped = fit(s -> 200s^1.5, 500)
  @test 200wrapped^1.5 <= 500 && wrapped > 1.6 && length(asked) <= 3
  # However its height grows, the slide fits the room it has
  for high in (s -> 100 + 250s^2, s -> 380 + 5s, s -> 390s, s -> 50s), room in (400, 500, 900)
    scale = fit(high, room)
    @test 1.0 <= scale <= 2.0 && (high(scale) <= room || scale == 1.0) && length(asked) <= 3
  end
  # A slide with nothing in it, and a window with no room, don't throw
  @test S.fit(s -> 0.0, 0.0, 500) == 1.0 && S.fit(s -> 100s, 100.0, 0) == 1.0
end

@testset "a line that's held starts no slide, so a group of columns stays on one slide" begin
  lines = ["# Plan", "", "```columns", "2", "```", "", "## A", "", "One.", "", "## B", "", "Two.", "", "---", "", "## After"]
  @test [(s.first, s.last) for s in S.slides(lines)] == [(1, 5), (7, 9), (11, 13), (17, 17)]
  # The two headings of the columns are held, and the line across the page still ends the slide
  list = S.slides(lines, held=i -> 7 <= i <= 13)
  @test [(s.first, s.last) for s in list] == [(1, 13), (17, 17)]
  @test S.number(list, 11) == 1 && S.number(list, 17) == 2
end
