# Tests that a hot reload keeps the commands that `add_command!` added, in
# main.jl. When a name in the list of commands changes, the hot reload makes
# `COMMAND_GROUPS` and `COMMANDS` again, and doesn't call `add_command!` again
# further down the file. Before, Run All and Go To were gone from the palette
# after that. Run them with `julia -O0 --project=. test/command_reload_test.jl`.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
@eval K settings_file() = $(joinpath(dir, "settings"))
const source = joinpath(dir, "sums.jl")
write(source, "area(w, h=2) = w * h\n\narea(3)\n")
const e = K.build_editor(source)
const w = Window(e, size=(900px, 400px))
foreach(_ -> Base.invokelatest(frame, w), 1:3)
K.focus(e)

"The top-level expression of main.jl that makes the constant `name`, with its docstring"
definition(name) = begin
  for ex in Meta.parseall(read(joinpath(@__DIR__, "..", "main.jl"), String)).args
    Meta.isexpr(ex, :macrocall) || continue
    inner = last(ex.args)
    Meta.isexpr(inner, :const) && Meta.isexpr(inner.args[1], :(=)) && inner.args[1].args[1] == name && return ex
  end
  error("main.jl has no constant called $name")
end

now(name) = Base.invokelatest(getglobal, K, name)
listed() = [c.name for c in Base.invokelatest(K.palette_commands, e)]

@testset "a hot reload of the list of commands keeps the ones that add_command! added" begin
  count_before = length(now(:COMMANDS))
  @test haskey(now(:COMMANDS), :run_all) && :run_all in listed() && :go_to in listed()
  # What the hot reload does after an edit to a name that the list uses
  Core.eval(K, definition(:COMMAND_GROUPS))
  Core.eval(K, definition(:COMMANDS))
  @test length(now(:COMMANDS)) == count_before
  @test haskey(now(:COMMANDS), :run_all) && haskey(now(:COMMANDS), :go_to)
  @test :run_all in listed() && :go_to in listed()
  # Each is in its group once, where it was
  @test count(g -> any(c -> c.name == :run_all, last(g)), now(:COMMAND_GROUPS)) == 1
  # A command that's added again, by a hot reload of its own line, takes its own place and makes no copy
  K.add_command!(K.run_all!, title="Run all the code of the file", kind=:edit)
  Core.eval(K, definition(:COMMAND_GROUPS))
  Core.eval(K, definition(:COMMANDS))
  @test length(now(:COMMANDS)) == count_before
  @test count(c -> c.name == :run_all, (c for (_, cs) in now(:COMMAND_GROUPS) for c in cs)) == 1
  @test now(:COMMANDS)[:run_all].title == "Run all the code of the file"
end
