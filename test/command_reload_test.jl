# Tests that a hot reload keeps the commands that `add_command!` added, in
# commands.jl. When a name in the list of commands changes, the hot reload makes
# `COMMAND_GROUPS` and `COMMANDS` again, and doesn't call `add_command!` again
# further down the file. Before, Run All and Go To were gone from the palette
# after that. Run them with `julia -O0 --project=. test/command_reload_test.jl`.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const source = joinpath(dir, "sums.jl")
write(source, "area(w, h=2) = w * h\n\narea(3)\n")
const e = K.build_editor(source)
const w = Window(e, size=(900px, 400px))
foreach(_ -> Base.invokelatest(frame, w), 1:3)
K.focus(e)

"The module of commands.jl, which has the list of commands"
const C = parentmodule(K.with_added)   # not add_commands!, which additions.jl has

"""
A module with every name of commands.jl's module but its two lists. The test
makes the lists again here, as the hot reload does in the module itself. The
module's own lists stay as they are: each file that uses commands.jl took them
when it loaded, and only the hot reload gives those files the new ones.
"""
const R = Module(:Reloaded)
for name in names(C, all=true, imported=true, usings=true)
  (name in (:COMMAND_GROUPS, :COMMANDS, :eval, :include, nameof(C)) || startswith(String(name), '#') || !isdefined(C, name) || isdefined(R, name)) && continue
  Core.eval(R, :(const $name = $(QuoteNode(getglobal(C, name)))))
end

"The top-level expression of commands.jl that makes the constant `name`, with its docstring"
definition(name) = begin
  for ex in Meta.parseall(read(normpath(joinpath(@__DIR__, "..", "window", "commands.jl")), String)).args
    Meta.isexpr(ex, :macrocall) || continue
    inner = last(ex.args)
    Meta.isexpr(inner, :const) && Meta.isexpr(inner.args[1], :(=)) && inner.args[1].args[1] == name && return ex
  end
  error("commands.jl has no constant called $name")
end

now(name) = Base.invokelatest(getglobal, R, name)
"The names of the commands that the palette lists from the groups `groups`"
listed(groups=K.COMMAND_GROUPS) = [c.name for (_, cs) in groups for c in cs if Base.invokelatest(K.in_palette, e, c)]

@testset "a hot reload of the list of commands keeps the ones that add_command! added" begin
  count_before = length(K.COMMANDS)
  @test haskey(K.COMMANDS, :run_all) && :run_all in listed() && :go_to in listed()
  # What the hot reload does after an edit to a name that the list uses
  Core.eval(R, definition(:COMMAND_GROUPS))
  Core.eval(R, definition(:COMMANDS))
  @test now(:COMMANDS) !== K.COMMANDS && length(now(:COMMANDS)) == count_before
  @test haskey(now(:COMMANDS), :run_all) && haskey(now(:COMMANDS), :go_to)
  @test :run_all in listed(now(:COMMAND_GROUPS)) && :go_to in listed(now(:COMMAND_GROUPS))
  # Each is in its group once, where it was
  @test count(g -> any(c -> c.name == :run_all, last(g)), now(:COMMAND_GROUPS)) == 1
  # A command that's added again, by a hot reload of its own line, takes its own place and makes no copy
  was = K.COMMANDS[:run_all]
  group = first(K.COMMAND_GROUPS[findfirst(g -> was in last(g), K.COMMAND_GROUPS)])
  K.add_command!(K.run_all!, title="Run all the code of the file", kind=:edit)
  Core.eval(R, definition(:COMMAND_GROUPS))
  Core.eval(R, definition(:COMMANDS))
  @test length(now(:COMMANDS)) == count_before
  @test count(c -> c.name == :run_all, (c for (_, cs) in now(:COMMAND_GROUPS) for c in cs)) == 1
  @test now(:COMMANDS)[:run_all].title == "Run all the code of the file"
  # Run All is as it was for the tests that run after this one in the same process
  K.add_commands!(group, [was])
  @test K.COMMANDS[:run_all] === was && length(K.COMMANDS) == count_before
end
