# Tests for the Reset Module command, which gives the file that a window shows
# a new, empty module for its code. See `reset_module!` in sum_functions.jl. Run them
# with `julia -O0 --project=. test/reset_module_test.jl`. They use windows that
# aren't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "./drive" drive
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")

# The live block shows the name of the module that it ran in, and how many times the page's code ran it
const PAGE = """
# Sums

```julia
x = 5
```

```ui
global runs = (isdefined(@__MODULE__, :runs) ? runs : 0) + 1
"ran \$runs"
```
"""

const path = joinpath(dir, "sums.md")
write(path, PAGE)
const key = K.page_key(path)
const live_key = (:live, path, "global runs = (isdefined(@__MODULE__, :runs) ? runs : 0) + 1\n\"ran \$runs\"")

window() = begin
  e = K.build_editor(path)
  w = Window(e, size=(900px, 700px))
  frames(w)
  K.focus(e)
  (e, w)
end
const (; frames) = drive(frames=3, latest=true)
ran(e, code) = (out = K.run_code(e, code); @test !out[3]; out[1])

@testset "the module loses what the code made" begin
  e, w = window()
  ran(e, "x = 5")
  old = K.PAGE_MODULES[key]
  @test ran(e, "x") == 5
  K.reset_module!(e)
  @test !haskey(K.PAGE_MODULES, key)
  @test ran(e, "isdefined(@__MODULE__, :x)") == false
  @test K.PAGE_MODULES[key] !== old
  # The new module is named by the file's path, as the first one was
  @test nameof(K.PAGE_MODULES[key]) == nameof(old)
  # It still has the names that a window gives a page's code
  @test ran(e, "page_theme()") isa String
end

@testset "the live blocks run again in the new module" begin
  e, w = window()
  K.reset_module!(e)
  frames(w)
  @test ran(e, "runs") == 1
  shown = e.nodes[live_key]
  frames(w)
  # A frame by itself doesn't run the block again
  @test e.nodes[live_key] === shown
  K.reset_module!(e)
  frames(w)
  @test e.nodes[live_key] !== shown
  # The new module had no `runs`, so the block counts from 1 again
  @test ran(e, "runs") == 1
end

@testset "another window on the file gets the new module too" begin
  e1, w1 = window()
  e2, w2 = window()
  ran(e1, "y = 7")
  @test ran(e2, "y") == 7
  push!(K.editors, e2)
  try
    shown = e2.nodes[live_key]
    K.reset_module!(e1)
    @test !haskey(e2.nodes, live_key)
    frames(w2)
    @test e2.nodes[live_key] !== shown
    @test ran(e2, "isdefined(@__MODULE__, :y)") == false
  finally
    filter!(x -> x !== e2, K.editors)
  end
end

@testset "a window on another file keeps its module" begin
  other = joinpath(dir, "other.md")
  write(other, "# Other\n")
  e, w = window()
  eo = K.build_editor(other)
  wo = Window(eo, size=(900px, 700px))
  frames(wo)
  K.run_code(eo, "z = 1")
  m = K.PAGE_MODULES[K.page_key(other)]
  push!(K.editors, eo)
  try
    K.reset_module!(e)
    @test K.PAGE_MODULES[K.page_key(other)] === m
    @test K.run_code(eo, "z")[1] == 1
  finally
    filter!(x -> x !== eo, K.editors)
  end
end

@testset "the command palette has it" begin
  e, w = window()
  ran(e, "x = 5")
  w.keys |= Keys.cmd | Keys.shft
  onkey(w, KeyPress{Keys.p}(0, w))
  w.keys ⊻= Keys.cmd | Keys.shft
  frames(w)
  @test e.popup == :commands
  foreach(c -> ontype(w, Typed(c, w)), "reset module")
  frames(w)
  rows = K.palette_rows(e, K.palette(e))
  @test first(rows).name == "Reset Module"
  onkey(w, KeyPress{Keys.enter}(0, w))
  frames(w)
  @test e.popup == :none
  @test ran(e, "isdefined(@__MODULE__, :x)") == false
end
