# Tests for what each file adds to Ladder for itself: its commands, with
# `add_command!`, and what it does in each frame, with `each_frame!`. See
# additions.jl, and `ADDED_ORDER` and `with_added` in commands.jl. A file that
# loads before commands.jl adds its commands before the list of every command
# is made, and the key bindings page lists them in the same places anyway. Run
# them with `julia -O0 --project=. test/additions_test.jl`.

@use Test: @test, @testset
@use "../main" => K

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

# The lists are read from commands.jl's own module, which is where `add_command!` puts a command. In a process that
# other tests share, the test of a hot reload gives main.jl's module lists of its own, and those don't change after.
const C = parentmodule(K.with_added)
groups_now() = Base.invokelatest(getglobal, C, :COMMAND_GROUPS)
commands_now() = Base.invokelatest(getglobal, C, :COMMANDS)
names_of(group) = [c.name for c in last(groups_now()[findfirst(g -> first(g) == group, groups_now())])]
const ASKING = "Commands that ask for something"
const IN_FOCUS = "The file or the folder in focus"

"Take the command called `name` away again, so that the next test finds the lists as they were"
forget!(name) = begin
  delete!(commands_now(), name)
  foreach(g -> filter!(c -> c.name != name, last(g)), groups_now())
  filter!(p -> last(p).name != name, K.ADDED_COMMANDS)
end

@testset "the key bindings page lists the commands of functions in their own order, whatever order the files load in" begin
  groups = first.(groups_now())
  @test groups[1:7] == ["Files and windows", "The text", "Lines", "The caret", "Deleting", IN_FOCUS, ASKING]
  for (group, names) in K.ADDED_ORDER
    listed = names_of(group)
    # Each command that the order names is there, once, and they come first, in that order
    @test listed[1:length(names)] == names
    @test allunique(listed)
  end
  # A file that loads before commands.jl, like git_page.jl, and one that loads after it, like file_menu.jl, both have their commands
  @test commands_now()[:push].call === K.push_branch! && commands_now()[:rename].call === K.rename!
  @test Set(c.name for (_, cs) in groups_now() for c in cs) == Set(keys(commands_now()))
end

@testset "a name that two groups have stands for the command that was added last" begin
  @test :add_to_favourites in names_of(IN_FOCUS) && :add_to_favourites in names_of(ASKING)
  # The folder's command was added after the one for a page from the web, as it was when main.jl added both
  @test commands_now()[:add_to_favourites].title == "Make the folder a favourite, so Go To Favourite goes to it"
  @test commands_now()[:remove_from_favourites].kind == :window
end

@testset "the lists made again, as a hot reload makes them, are the same lists" begin
  added(c) = any(p -> last(p) === c, K.ADDED_COMMANDS)
  base = [group => filter(!added, cs) for (group, cs) in groups_now() if !all(added, cs) || isempty(cs)]
  # Ladder's own groups are the first seven. In a process that other tests ran in, groups of theirs can come after.
  again, now = K.with_added(base)[1:7], groups_now()[1:7]
  @test [group => [c.name for c in cs] for (group, cs) in again] == [group => [c.name for c in cs] for (group, cs) in now]
  @test all(((a, b),) -> all(splat(===), zip(last(a), last(b))), zip(again, now))
end

"Do a thing that the test asks for"
do_a_thing(e, count::Int) = count

@testset "a new command comes last in its group, and added twice it shows once" begin
  before = names_of(ASKING)
  K.add_command!(do_a_thing)
  @test names_of(ASKING) == [before; :do_a_thing]
  @test commands_now()[:do_a_thing].title == "Do a thing that the test asks for" && commands_now()[:do_a_thing].call === do_a_thing
  K.add_command!(do_a_thing, title="Do it")
  @test names_of(ASKING) == [before; :do_a_thing] && commands_now()[:do_a_thing].title == "Do it"
  @test count(p -> last(p).name == :do_a_thing, K.ADDED_COMMANDS) == 1
  forget!(:do_a_thing)
  @test names_of(ASKING) == before
end

@testset "main.jl adds no command: each is added by the file that has its function" begin
  main = read(joinpath(@__DIR__, "..", "main.jl"), String)
  @test !occursin(r"^\s*add_commands?!\("m, main)
end

const seen = Symbol[]
first_tick!(e) = push!(seen, :first)
second_tick!(e) = push!(seen, :second)

@testset "what a file does in each frame is done once, in the order that it was added" begin
  before = first.(K.FRAME_TICKS)
  @test allunique(before)
  K.each_frame!(first_tick!)
  K.each_frame!(second_tick!)
  K.each_frame!(first_tick!)   # a file that loads twice adds its work once, and it keeps its place
  @test first.(K.FRAME_TICKS) == [before; :first_tick!; :second_tick!]
  path = joinpath(dir, "page.md")
  write(path, "# A page\n")
  K.frame_ticks!(K.build_editor(path))
  @test seen == [:first, :second]
  filter!(((name, _),) -> !(name in (:first_tick!, :second_tick!)), K.FRAME_TICKS)
  @test first.(K.FRAME_TICKS) == before
end
