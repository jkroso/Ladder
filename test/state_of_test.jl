# What a feature keeps for a window, by its type: `state_of`
@use "../main" => K
using Test
@use "github.com/jkroso/Prospects.jl" @def

@def mutable struct Counted
  n::Int = 0
  note::Union{Nothing,String} = nothing
end

@def mutable struct Other
  n::Int = 7
end

@testset "a window keeps one state of each kind" begin
  e, o = K.Editor(), K.Editor()
  s = K.state_of(e, Counted)
  @test s isa Counted && s.n == 0 && s.note === nothing   # made with its defaults the first time
  s.n = 3
  @test K.state_of(e, Counted) === s                      # and the same one after that
  @test K.state_of(e, Other).n == 7                       # another kind is another thing
  @test K.state_of(e, Counted).n == 3
  @test K.state_of(o, Counted).n == 0                     # each window has its own
  @test e.nodes[Counted] === s                            # it's kept in the window's nodes, under its type
end
