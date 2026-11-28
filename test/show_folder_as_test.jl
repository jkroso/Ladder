# Tests for Show Folder As, in folder_kinds.jl: the command that gives the folder in
# focus a kind, by writing the folder's own page, the file `.ladder`. The kind
# is one of Ladder's own, or one that a repository on GitHub has. See "a kind
# for a folder, in one step". Run them with
# `julia -O0 --project=. test/show_folder_as_test.jl`. They draw a window
# that isn't on the screen, and use no network: a file stands in for a
# repository.

@use Test: @test, @testset, @test_throws
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "./drive" drive
const px = K.px

const dir = realpath(mktempdir())
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const jobs = joinpath(dir, "jobs")
mkpath(jobs)
write(joinpath(jobs, "one.md"), "# One\n\nSee [[Two]].\n")
write(joinpath(jobs, "two.md"), "# Two\n")
write(joinpath(dir, "page.md"), "# A page\n")
# A file that has a kind of folder, as the main file of a repository has
const lad = joinpath(dir, "films.jl")
write(lad, """
kind(Ladder::Module) = Ladder.PicturesDirectory
""")
const bare = joinpath(dir, "bare.jl")
write(bare, "x = 1\n")

const e = K.build_editor(joinpath(jobs, "one.md"))
const w = Window(e, size=(1000px, 700px))
# Each frame is drawn with the newest code, as the window's loop draws it
const (; frames) = drive(w, frames=3, latest=true)
frames()

const page = joinpath(jobs, ".ladder")
folder() = K.FS.get(FSPath(jobs))
kind() = nameof(typeof(folder()))
choice(name) = only(filter(k -> k.name == name, K.choices_for(K.KindChoice, e)))
as!(k) = (Base.invokelatest(K.show_folder_as!, e, folder(), k); frames())

@testset "the kinds that the command offers" begin
  @test [k.name for k in K.choices_for(K.KindChoice, e)] == ["Desktop", "Notes", "Blog", "Downloads", "Pictures", "Screenshots", "News", "Plain"]
  @test choice("Notes").from === K.NotesDirectory && choice("Plain").from === nothing
  # The address of a repository is typed, as it is or as a browser shows it
  for text in ("github.com/jkroso/Media.lad", "https://github.com/jkroso/Media.lad", " github.com/jkroso/Media.lad/ ", "https://github.com/jkroso/Media.lad.git")
    k = K.typed_as(K.KindChoice, text)
    @test k !== nothing && k.from == "github.com/jkroso/Media.lad" && K.worded(k) == "jkroso/Media.lad"
  end
  @test K.typed_as(K.KindChoice, "media") === nothing && K.typed_as(K.KindChoice, "github.com/jkroso") === nothing
  @test K.sidenote(K.typed_as(K.KindChoice, "github.com/a/b")) == "from GitHub"
  # The command shows where a folder is in focus, and asks for the kind alone
  sigs = K.callable_methods(K.show_folder_as!, K.in_focus(e))
  @test length(sigs) == 1 && [a.type for a in K.asks(sigs[1])] == [K.KindChoice]
  @test haskey(K.COMMANDS, :show_folder_as)
end

@testset "the page that the command writes" begin
  own = K.kind_page(choice("Desktop"))
  @test occursin("```julia\nLadder.DesktopDirectory\n```", own) && K.kind_page_written(own)
  from = K.kind_page(K.KindChoice("github.com/a/b", "github.com/a/b"))
  @test occursin("```julia\nLadder.kind_from(\"github.com/a/b\")\n```", from) && K.kind_page_written(from)
  @test !K.kind_page_written("My films.\n\n```julia\nLadder.DesktopDirectory\n```\n")
  @test !K.kind_page_written(own * "\nMore.\n")
end

@testset "the folder gets the kind, and the window shows it" begin
  @test kind() == :Directory && !isfile(page)
  as!(choice("Notes"))
  @test read(page, String) == K.kind_page(choice("Notes")) && kind() == :NotesDirectory
  # Another kind takes the first one's place
  as!(choice("Desktop"))
  @test kind() == :DesktopDirectory && K.page_object(e) isa K.DesktopDirectory
  # The same kind again writes nothing
  at = mtime(page)
  as!(choice("Desktop"))
  @test mtime(page) == at
  # Plain takes the page away
  as!(choice("Plain"))
  @test !isfile(page) && kind() == :Directory
  as!(choice("Plain"))
  @test !isfile(page)
end

@testset "a kind from a repository" begin
  @test K.kind_from(lad) === K.PicturesDirectory
  @test_throws "has no function called kind" K.kind_from(bare)
  as!(K.KindChoice("films", lad))
  @test kind() == :PicturesDirectory && K.kind_page_written(read(page, String))
  as!(choice("Plain"))
end

@testset "a page that somebody wrote stays" begin
  mine = "My jobs.\n\n```julia\nLadder.NotesDirectory\n```\n"
  write(page, mine)
  @test_throws "somebody wrote" K.show_folder_as!(e, folder(), choice("Desktop"))
  @test_throws "somebody wrote" K.show_folder_as!(e, folder(), choice("Plain"))
  @test read(page, String) == mine
  rm(page)
end

close(w)
