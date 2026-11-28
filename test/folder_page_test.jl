# Tests for a folder's own page: the file `.ladder` in a folder, whose `julia`
# blocks Ladder runs when it first meets the folder, and whose last value is
# the folder's kind. See "a folder's own page" in folder_kinds.jl. Run
# them with `julia -O0 --project=. test/folder_page_test.jl`. They draw a
# window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame popups
@use "github.com/jkroso/URI.jl/FSPath" FSPath
const px = K.px
const FS = K.FS

const dir = mktempdir()
# The settings that these tests keep go to a file of their own, not to the one that Ladder uses
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const notes = joinpath(dir, "notes")
const films = joinpath(dir, "films")
mkpath(joinpath(notes, "old"))
mkpath(films)
mkpath(joinpath(dir, "plain"))
write(joinpath(notes, "one.md"), "# One\n")
write(joinpath(dir, "page.md"), "# A page\n")

# The pages' code names these two as Main's, since a page's code runs in a module of its own. They get names of
# their own there, for when the test runs in a module that isn't Main, as it does in test/hot.
const RUNS = Core.eval(Main, :(folder_page_test_runs = Ref(0)))          # how many times the page of the notes ran
const CLICKS = Core.eval(Main, :(folder_page_test_clicks = String[]))    # the folders of films that a click or a link opened

"Write `text` as the page of `folder`, with a time of its own, as a page that's saved again has"
const saved = Ref(time() - 100)
page!(folder, text) = begin
  file = joinpath(folder, ".ladder")
  write(file, text)
  saved[] += 1
  run(`touch -t $(Libc.strftime("%Y%m%d%H%M.%S", saved[])) $file`)
  file
end

"The page of a folder of notes, whose folders have the icon `icon`"
notes_page(icon) = """
  These are my notes.

  ```julia
  Main.folder_page_test_runs[] += 1
  Ladder.@def struct NotesDirectory <: Ladder.AbstractDirectory end
  Ladder.entry_icon(::NotesDirectory) = "$icon"
  ```

  The last block's value is the kind of the folder.

  ```julia
  NotesDirectory
  ```
  """
page!(notes, notes_page("box"))

const e = K.build_editor(joinpath(dir, "page.md"))
const w = Window(e, size=(1000px, 700px))
# Each frame is drawn with the newest code, as the window's loop draws it: a page that ran in one frame loaded code for the next
frames(n=3) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
e.panel || K.toggle_panel!(e)

"The name of the kind of the folder at `path`"
kind(path) = nameof(typeof(K.object(e, path)))
"The name of the icon of the folder or file `name` in the sidebar's folder"
icon(name) = K.entry_icon(K.object(e, joinpath(e.folder, name)))
"What the window's toast about the page of the notes says, its title and then why, or \"\" when it shows none"
said() = begin
  i = findfirst(it -> it.key == notes, K.TOASTS)
  i === nothing || !any(p -> p.key == :toasts, popups(w)) ? "" : K.TOASTS[i].title * ". " * K.TOASTS[i].words
end

@testset "a folder's page runs after Ladder first meets the folder, and gives the folder its kind" begin
  # The sidebar listed the folder, and its page waits for the frame
  @test RUNS[] == 0 && notes in K.FOLDER_PAGES_DUE && kind(notes) == :Directory
  frames()
  @test RUNS[] == 1 && isempty(K.FOLDER_PAGES_DUE)
  @test kind(notes) == :NotesDirectory && icon("notes") == "box" && icon("plain") == "folder"
  @test K.object(e, notes).parent === K.directory(e)
  # The page ran once, however many times the folder is met
  K.list_files!(e); frames(); K.object(e, joinpath(notes, "one.md"))
  @test RUNS[] == 1
  # A folder in it is what the kind says, and this kind says nothing
  @test kind(joinpath(notes, "old")) == :Directory
end

@testset "a page that's saved again runs again" begin
  was = typeof(K.object(e, notes))
  page!(notes, notes_page("archive"))
  K.list_files!(e)
  # Until the frame is made, the folder keeps the kind that it had
  @test RUNS[] == 1 && typeof(K.object(e, notes)) === was
  frames()
  @test RUNS[] == 2 && icon("notes") == "archive" && typeof(K.object(e, notes)) !== was
end

@testset "code that fails leaves the folder plain, and a toast says which line failed" begin
  page!(notes, "Notes.\n\n```julia\nconst before = 1\nnothing_called_this()\n```\n")
  K.list_files!(e); frames()
  @test kind(notes) == :Directory && icon("notes") == "folder"
  @test startswith(said(), "The .ladder page of notes stopped. Line 5 of .ladder: ") && occursin("nothing_called_this", said())
  # A last value that isn't a kind of folder is said too
  page!(notes, "```julia\n1 + 1\n```\n")
  K.list_files!(e); frames()
  @test kind(notes) == :Directory && occursin("gave 2, which isn't a kind of folder", said())
  # The toast stays after a while, since it can say so before the window opens or while you look elsewhere
  K.FOLDER_PAGE_STOPPED[] = (K.FOLDER_PAGE_STOPPED[][1], time() - K.STARTUP_SHOWS - 1)
  frames()
  @test occursin("gave 2", said())
end

@testset "a page with no code, and a folder that loses its page, are plain" begin
  page!(notes, notes_page("box"))
  K.list_files!(e); frames()
  # A page that runs with nothing wrong takes its toast away
  @test kind(notes) == :NotesDirectory && said() == "" && !any(it -> it.key == notes, K.TOASTS)
  page!(notes, "Only words.\n")
  K.list_files!(e); frames()
  @test kind(notes) == :Directory && said() == ""
  page!(notes, notes_page("box"))
  K.list_files!(e); frames()
  @test kind(notes) == :NotesDirectory
  rm(joinpath(notes, ".ladder"))
  K.list_files!(e); frames()
  @test kind(notes) == :Directory && icon("notes") == "folder" && !haskey(K.FOLDER_PAGE_KINDS, notes)
  # A folder whose page failed and then went loses the page's toast
  page!(notes, "```julia\nnothing_called_this()\n```\n")
  K.list_files!(e); frames()
  @test occursin("nothing_called_this", said())
  rm(joinpath(notes, ".ladder"))
  K.list_files!(e); frames()
  @test said() == "" && !any(it -> it.key == notes, K.TOASTS)
end

@testset "a link to a folder runs the folder's page first, and does what the kind says" begin
  page!(films, """
    ```julia
    Ladder.@def struct FilmsDirectory <: Ladder.AbstractDirectory end
    Ladder.open!(e, d::FilmsDirectory; record=true) = (push!(Main.folder_page_test_clicks, d.path.name); Ladder.go_folder!(e, string(d.path)))
    FilmsDirectory
    ```
    """)
  # A sidebar that lists another folder hasn't met the folder of the films
  K.go_folder!(e, notes); frames()
  @test !haskey(K.FOLDER_PAGE_KINDS, films)
  K.follow!(e, films)
  @test CLICKS == ["films"] && e.folder == films
  frames()
  @test K.directory(e) isa K.AbstractDirectory && nameof(typeof(K.directory(e))) == :FilmsDirectory
  # The sidebar listed this one before its page ran, and the link still does what the kind says
  K.go_folder!(e, dir); frames()
  page!(films, replace(read(joinpath(films, ".ladder"), String), "d.path.name" => "\"again\""))
  K.list_files!(e)
  K.follow!(e, films)
  @test CLICKS == ["films", "again"]
  K.go_folder!(e, dir); frames()
end

@testset "a kind that code gave the folder by its path comes before the page's" begin
  K.@def struct OtherDirectory <: K.AbstractDirectory end
  FS.kinds[FSPath(films)] = OtherDirectory
  K.list_files!(e); frames()
  @test K.object(e, films) isa OtherDirectory
  delete!(FS.kinds, FSPath(films))
  K.list_files!(e); frames()
  @test kind(films) == :FilmsDirectory
end

@testset "the page of a folder shows as a page" begin
  file = page!(notes, notes_page("box"))
  @test K.ismarkdown(file) && !K.ismarkdown(joinpath(notes, ".other"))
  empty!(K.problems)   # what a live block of a test before this one said, when the tests share a process
  K.open!(e, file); frames()
  @test e.buf.path == file && e.buf.view != :file && e.buf.lines[1] == "These are my notes."
  @test isempty(K.problems)
end
