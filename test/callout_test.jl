# Tests for callouts in markdown.jl and html.jl: a quote whose first line names
# a kind of note, like `> [!NOTE]`. Run them with
# `julia -O0 --project=. test/callout_test.jl`. They open no window.

@use Test: @test, @testset
@use "../markdown" Kind classify callout opens_callout CALLOUTS
@use "../html" html

@testset "the lines of a callout" begin
  lines = ["text", "> [!NOTE]", "> First line.", "> Second line.", "", "> A plain quote.", "> [!TIP]", "", "> [!warning] Mind the step", ">", "> Still the warning."]
  ks = classify(lines)
  @test all(k -> k.kind == Kind.blockquote, ks[[2, 3, 4, 6, 7, 9, 10, 11]])
  # A line that names a kind in the middle of a quote, like the [!TIP] here, is a line of that quote
  @test [callout(k) for k in ks] == ["", "note", "note", "note", "", "", "", "", "warning", "warning", "warning"]
  @test [opens_callout(k) for k in ks] == [false, true, false, false, false, false, false, false, true, false, false]
  # The first line's markup takes in the kind, and the spaces before a title
  @test ks[2].prefix == length("> [!NOTE]") && ks[9].prefix == length("> [!warning] ") && ks[3].prefix == 2
end

@testset "what makes a callout" begin
  kind(text) = callout(classify([text])[1])
  @test [kind("> [!$(uppercase(k))]") for k in CALLOUTS] == collect(CALLOUTS)
  @test kind(">[!Tip]") == "tip" && kind("  > [!caution]   ") == "caution"
  # Any other word in the brackets, and a line that isn't a quote, is no callout
  @test kind("> [!SHOUT]") == "" && kind("> [NOTE]") == "" && kind("[!NOTE]") == "" && kind("> text [!NOTE]") == ""
  # In a code block the line is code
  @test classify(["```", "> [!NOTE]", "```"])[2].kind == Kind.code
  # A callout ends where its quote ends
  ks = classify(["> [!NOTE]", "> a", "text", "> b"])
  @test callout(ks[2]) == "note" && callout(ks[4]) == ""
end

@testset "a callout as HTML" begin
  page = html(["> [!NOTE]", "> Mind the **gap**.", "", "> [!WARNING] Wet paint", "> Keep off.", "", "> A plain quote."])
  @test occursin("<blockquote class=\"callout note\">\n<p class=\"callout-title\">Note</p>\n<p>Mind the <strong>gap</strong>.</p>\n</blockquote>", page)
  @test occursin("<blockquote class=\"callout warning\">\n<p class=\"callout-title\">Wet paint</p>\n<p>Keep off.</p>\n</blockquote>", page)
  @test occursin("<blockquote>\n<p>A plain quote.</p>\n</blockquote>", page)
  @test !occursin("[!", page)
end
