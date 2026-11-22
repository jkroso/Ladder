# Tests for the startup page of main.jl: the page that Ladder writes the first
# time, the Julia code of the page that runs when Ladder starts, and what the
# window says when that code fails. Run them with
# `julia -O0 --project=. test/startup_test.jl`. The page is in a folder of the
# test's own, not in the folder of the settings, and the window isn't on the
# screen.

@use Test: @test, @testset
@use "../main" => K
K.RUN_WAIT[] = Inf   # the code runs in a thread of its own, and each result is there when the key's handler ends
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
const px = K.px

K.STARTUP_FOLDER[] = joinpath(mktempdir(), "startup")
const page = K.startup_page()

@testset "the page is among the pages of the settings" begin
  folder = K.STARTUP_FOLDER[]
  K.STARTUP_FOLDER[] = ""
  @test K.startup_page() == K.settings_page("startup.md") && dirname(K.startup_page()) == K.settings_dir()
  # The Settings page has a link to it
  @test occursin("](startup.md)", read(K.settings_page(), String))
  K.STARTUP_FOLDER[] = folder
end

@testset "the first time, Ladder writes the page, and then the page is yours" begin
  @test page == joinpath(K.STARTUP_FOLDER[], "startup.md") && !isfile(page)
  @test K.startup_page!() == page && isfile(page)
  lines = split(read(page, String), '\n')
  @test lines[1] == "# Home" && any(l -> occursin("```julia", l), lines)
  # Its links go to Ladder's own pages, by the way there from the folder of the settings, where the page is
  links = [m[1] for m in eachmatch(r"\]\(([^)]+)\)", read(page, String))]
  @test length(links) == 2 && all(l -> isfile(abspath(K.settings_dir(), l)), links)
  @test abspath(K.settings_dir(), links[1]) == joinpath(K.pages_dir[], "welcome.md") && links[2] == "settings.md"
  # A page that's there is never written again
  write(page, "# Mine\n")
  @test K.startup_page!() == page && read(page, String) == "# Mine\n"
end

@testset "the page shows as any page does, and its code as code" begin
  rm(page)
  K.startup_page!()
  e = K.build_editor(page)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  @test e.buf.lines[1] == "# Home" && !e.buf.fixed && isempty(K.problems)
end

@testset "the code of the page runs when Ladder starts, from the top, in one module" begin
  write(page, """
    # Home

    Words between the blocks are only words.

    ```julia
    const made = [1]
    add(x) = push!(made, x)
    ```

    ```text
    this isn't Julia, so it doesn't run: error("no")
    ```

    ```julia
    add(2)
    const ladder = Ladder
    @use Dates: Date
    const day = Date(2026, 11, 18)
    ```
    """)
  m = K.run_startup!()
  @test m.made == [1, 2] && K.STARTUP[][1] == ""
  # `Ladder` is Ladder itself, so the code can call its functions and add to its tables
  @test m.ladder === K && m.Ladder.startup_page() == page
  @test string(m.day) == "2026-11-18"
  # Each start has a module of its own
  @test K.run_startup!() !== m
  # A page that's gone, and a page with no code, run nothing and fail nothing
  write(page, "# Home\n")
  K.run_startup!()
  @test K.STARTUP[][1] == ""
  @test (K.run_startup!(joinpath(K.STARTUP_FOLDER[], "none.md")); K.STARTUP[][1] == "")
end

@testset "code that fails stops what's after it, and the window says which line failed" begin
  write(page, """
    # Home

    ```julia
    const before = 1
    ```

    ```julia
    const here = 2
    nothing_called_this()
    const after = 3
    ```

    ```julia
    const later = 4
    ```
    """)
  m = K.run_startup!()
  words, since = K.STARTUP[]
  @test isdefined(m, :before) && isdefined(m, :here) && !isdefined(m, :after) && !isdefined(m, :later)
  @test startswith(words, "Line 9 of startup.md: ") && occursin("nothing_called_this", words) && time() - since < 5
  e = K.build_editor(page)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  @test any(p -> p.key == :startup, popups(w))
  # The words go after a while, and don't come back
  K.STARTUP[] = (words, since - K.STARTUP_SHOWS - 1)
  frame(w); frame(w)
  @test !any(p -> p.key == :startup, popups(w))
  # A start with nothing wrong says nothing
  write(page, "# Home\n")
  K.run_startup!()
  frame(w); frame(w)
  @test !any(p -> p.key == :startup, popups(w))
end

@testset "code of the page that runs in the window runs where Ladder ran it, with the name Ladder" begin
  write(page, """
    # Home

    ```julia
    const loaded = 7
    ```

    ```julia
    Ladder.startup_page()
    loaded + 1
    ```
    """)
  m = K.run_startup!()
  e = K.build_editor(page)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  shown(line) = (e.buf.caret = e.buf.anchor = (line, 0); K.run_here!(e); only(filter(o -> o.last == line, K.outcomes(e))))
  o = shown(8)
  @test !o.failed && o.brief == repr(page)
  # What the code loaded when Ladder started is there, since it's the same module
  o = shown(9)
  @test !o.failed && o.brief == "8"
  @test K.workspace(e) === m
  # A folder's own page has the name too, in a module like the one that Ladder runs it in
  folder = mkpath(joinpath(mktempdir(), "notes"))
  file = joinpath(folder, K.FOLDER_PAGE)
  write(file, "```julia\nLadder.FOLDER_PAGE\n```\n")
  e = K.build_editor(file)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  o = shown(2)
  @test !o.failed && o.brief == repr(K.FOLDER_PAGE)
  # Its name is its path, as a module that Kip makes for a file is named by the file
  @test nameof(K.workspace(e)) == Symbol("⭒", Base.Filesystem.contractuser(realpath(file)))
  # Any other page has no such name
  other = joinpath(folder, "other.md")
  write(other, "```julia\nLadder\n```\n")
  e = K.build_editor(other)
  w = Window(e, size=(900px, 700px))
  frame(w); frame(w)
  @test shown(2).failed
end
