# Tests for guard.jl, the sandbox that the code of a page from a web server
# runs in. Run them with `julia -O0 --project=. test/guard_test.jl`.
#
# Each piece of code runs in a module of its own, as a page's code would, in a
# folder that stands in for the site's own folder of the browser folder.

@use Test: @test, @testset
@use "../guard" => Guard

const dir = mktempdir()
const site_dir = mkpath(joinpath(dir, "Browser", "example.com"))
write(joinpath(site_dir, "data.txt"), "hello")
const victim = joinpath(dir, "victim.txt")   # a file that harmful code would change or delete

"The keys of the actions that you said yes to"
const yes = Set{String}()
const site = Guard.Site("https://example.com", site_dir, k -> k in yes ? true : nothing)

"A module for a page's code, with the `eval` and `include` that Ladder gives each one"
page_module() = begin
  m = Module(:Page)
  Core.eval(m, :(eval(x) = Core.eval($m, x)))
  Core.eval(m, :(include(f) = Base.include($m, f)))
  m
end

"Run `code` in the sandbox, as the code of a page of example.com, and give its value or its error"
run(code) = try
  cd(() -> Guard.run_code(Guard.Context(site, page_module()), code, joinpath(site_dir, "page.md")), site_dir)
catch err
  err
end

"True when `code` stops in the sandbox, and the victim is as it was"
stops(code) = begin
  write(victim, "keep")
  got = run(code)
  got isa Guard.Stopped && isfile(victim) && read(victim, String) == "keep"
end

@testset "code that can't harm the Mac runs" begin
  @test run("x = 3; x + 1") == 4
  @test run("f(x) = x[end] + 1; f([1, 2])") == 3
  @test run("sum(i^2 for i in 1:10)") == 385
  @test run("struct P; a::Int; end; P(2).a") == 2
  @test run("map(x -> x * 2, 1:3)") == [2, 4, 6]
  @test run("uppercase(join([\"a\", \"b\"], \",\"))") == "A,B"
  @test run("sort([3, 1, 2]; by=-)") == [3, 2, 1]
  @test run("k(x; y=1) = x + y; k(1; y=5)") == 6
  @test run("d = Dict(:a => 1); d[:b] = 2; length(d)") == 2
  @test run("\"doc\"\ng(x) = x\ng(7)") == 7
  @test run("try; error(\"x\"); catch e; 5; end") == 5
  @test run("[1, 2] .+ 1") == [2, 3]
  @test run("abstract type A end; struct B <: A end; B() isa A")
  @test run("Base.@kwdef struct Q; a::Int = 3; end; Q().a") == 3
  # A method of Julia's own function is fine for a type that the page made
  @test run("struct R end; Base.show(io::IO, ::R) = print(io, \"r\"); repr(R())") == "r"
  @test run("using Statistics; mean([1, 2, 3])") == 2.0
  @test run("using Dates; Date(2026, 11, 27) + Day(1) == Date(2026, 11, 28)")
  @test run("let s = 0; @simd for i in 1:4; s += i; end; s; end") == 10
  @test run("@enum Colour red blue; Int(blue)") == 1
  @test run("a, b = (1, 2); a + b") == 3
  @test run("f(xs...) = sum(xs); f(1, 2, 3)") == 6
  @test run("Base.@kwdef mutable struct M; a::Int = 1; end; m = M(); m.a = 5; m.a") == 5
  @test run("r = Ref(1); r[] += 1; r[]") == 2
  @test run("t = time(); t > 0")
  @test run("`ls -la`.exec") == ["ls", "-la"]   # a command can be made, though not run
  # A closure that holds a name of its own: Julia makes a type for it in steps, which the sandbox mustn't look into too soon
  @test run("() -> let h = 3.0; xs = [1.0, 2.0, 4.0]; h2 = min(xs[end], max(xs[1], h)); findfirst(x -> x >= h2, xs) end") |> Base.invokelatest == 3
  # A file of the site's own folder can be read
  @test run("read(\"data.txt\", String)") == "hello" && run("isfile(\"data.txt\")")
  # A check of each index stays on, whatever the code says
  @test run("@inbounds [1, 2][100000]") isa BoundsError
end

@testset "code that could harm the Mac stops" begin
  empty!(yes)
  Guard.waiting!()
  @test stops("rm($(repr(victim)))")
  @test stops("f() = touch($(repr(victim))); f()")
  @test stops("map(touch, [$(repr(victim))])")
  @test stops("Base.Filesystem.unlink($(repr(victim)))")
  @test stops("write($(repr(victim)), \"x\")") && stops("open($(repr(victim)), \"w\")")
  @test stops("read(\"/etc/hosts\", String)")
  @test stops("run(`ls`)")
  @test stops("ENV[\"HOME\"]")
  @test stops("eval(:(1 + 1))") && stops("Core.eval(Main, :(x = 1))") && stops("@eval 1 + 1") && stops("include(\"x.jl\")")
  @test stops("ccall(:getpid, Cint, ())") && stops("@ccall getpid()::Cint")
  @test stops("Libc.malloc(10)") && stops("unsafe_load(Ptr{Int}(0))")
  @test stops("push!(LOAD_PATH, \"x\")")
  @test stops("Main.Base") && stops("cd(\"/\")") && stops("download(\"https://example.com\")")
  @test stops("@generated h(x) = :(x)") && stops("module X end")
  @test stops("using Sockets; connect(80)")
  @test stops("task_local_storage()")
  # A method that would change how a function of Julia's works for all of Ladder
  @test stops("Base.show(io::IO, x::Int) = print(io, 1)")
  @test stops("import Base: +; +(a::Int, b::Int) = 0")
  # A function that can change files is checked where it's called, so the code can't hand it to code that
  # the sandbox doesn't step through, which would call it unchecked
  @test stops("getfield(Base, :rm)($(repr(victim)))")
  @test stops("invokelatest(rm, $(repr(victim)))")
  @test stops("foldl(|>, vcat([$(repr(victim))], Any[rm]))")
  @test stops("foldl(|>, vcat([$(repr(victim))], collect(Iterators.map(_ -> rm, 1:1))))")
  @test stops("g = rm; foldl(|>, Any[$(repr(victim)), g])")
  @test stops("h() = Base.Filesystem.rm; foldl(|>, Any[$(repr(victim)), h()])")
  @test stops("struct W; f; end; foldl(|>, Any[$(repr(victim)), W(touch).f])")
  @test stops("typeof(rm).instance($(repr(victim)))")
  @test stops("sort([$(repr(victim))]; by=rm)")
  @test stops("foldl(|>, Any[$(repr(victim)), Base.Docs.resolve(Base.Docs.Binding(Base, :rm))])")
  # Found in a review by agy: C code and memory by other names, things of Julia's that reach outside, and macros
  @test stops("Base.llvmcall(\"ret i32 42\", Int32, Tuple{})") && stops("cglobal(:jl_uv_stdout)")
  @test stops("using Core.Intrinsics: pointerref; pointerref(Ptr{Int}(8), 1, 1)")
  @test stops("Ptr{Cvoid}(0)") && stops("finalizer(Ptr{Cvoid}(8), Ref(1))")
  @test stops("Base.EnvDict()[\"HOME\"]") && stops("Union{Base.EnvDict, Nothing}()")
  @test stops("pushdisplay(TextDisplay(IOBuffer()))") && stops("Base.CoreLogging.global_logger(Base.CoreLogging.NullLogger())")
  @test stops("mktemp($(repr(dir)))") && stops("mktempdir($(repr(dir)))")
  @test stops("withenv(\"PATH\" => \"/tmp\") do; 1; end") && stops("fdio(3)") && stops("GC.enable(false)")
  @test stops("Base.Sys.set_process_title(\"x\")") && stops("Base.MPFR.free") && stops("Meta.lower(Main, :(1 + 1))")
  @test stops("macroexpand(Main, :(@time 1))") && stops("@static if (rm($(repr(victim))); true) 1 end")
  @test stops("using LinearAlgebra; LinearAlgebra.BLAS.lbt_forward(\"/tmp/x.dylib\")")
  @test stops("fs = Base.materialize(Base.dotgetproperty([Base], :rm)); map(|>, [$(repr(victim))], fs)")
  @test stops("Base.stdout = IOBuffer()") && stops("current_task()") && stops("setfield!(IOBuffer(), :size, 100)")
  @test stops("struct MyDummy end; Base.show(io::IO, x::Union{Int, MyDummy}) = print(io, \"no\")")
  @test stops("macro u(); Expr(:macrocall, Symbol(\"@static\"), LineNumberNode(1), :(if (rm($(repr(victim))); true) 1 end)); end; @u")
  @test stops(":(\$(rm($(repr(victim)))))")
  @test stops("macro make_env(); Expr(:new, Base.EnvDict); end; @make_env()[\"HOME\"]")
  @test stops("macro read_env(); Expr(:call, GlobalRef(Base, :getindex), GlobalRef(Base, :ENV), \"HOME\"); end; @read_env()")
  @test stops("invokelatest(open, $(repr(victim)); write=true)")
  @test stops("""
    struct SneakyPath <: AbstractString; real::String; fake::String; end
    Base.ncodeunits(s::SneakyPath) = ncodeunits(s.real)
    Base.codeunit(s::SneakyPath) = UInt8
    Base.codeunit(s::SneakyPath, i::Integer) = codeunit(s.real, i)
    Base.isvalid(s::SneakyPath, i::Integer) = isvalid(s.real, i)
    Base.iterate(s::SneakyPath, i::Integer=1) = iterate(s.real, i)
    Base.string(s::SneakyPath) = s.fake
    read(SneakyPath("/etc/hosts", "data.txt"), String)
    """)
  @test stops("Base.Filesystem.open(\"data.txt\", 1)")
  @test stops("cd(() -> readdir(), \"/\")") || stops("readdir(\"/\")")
  @test stops("samefile(\"data.txt\", \"/etc/hosts\")")
  @test stops("run(pipeline(`echo hi`, $(repr(victim))))")
  # Code in a task of its own is checked too
  got = run("fetch(Threads.@spawn write($(repr(victim)), \"x\"))")
  @test got isa TaskFailedException && got.task.result isa Guard.Stopped
end

@testset "what a stop says, and what waits for your answer" begin
  Guard.waiting!()
  got = run("rm($(repr(victim)))")
  @test got isa Guard.Stopped && got.action.words == "delete victim.txt in $(basename(dir))"
  @test sprint(showerror, got) == "The sandbox stopped this code: it wants to delete victim.txt in $(basename(dir))."
  @test run("read(\"/etc/hosts\", String)").action.words == "read hosts in etc"
  @test run("run(`ls -la`)").action.words == "run the program ls"
  w = Guard.waiting!()
  @test length(w) == 3 && all(x -> x[1] == "https://example.com", w)
  # The same action waits once
  run("rm($(repr(victim)))"); run("rm($(repr(victim)))")
  @test length(Guard.waiting!()) == 1
end

@testset "an action that you said yes to goes on" begin
  write(victim, "keep")
  a = run("rm($(repr(victim)))").action
  push!(yes, a.key)
  try
    run("rm($(repr(victim)))")
    @test !isfile(victim)
  finally
    empty!(yes)
  end
  # The answer is kept by the folder, so a file in another folder asks again
  @test run("rm(\"/tmp/other.txt\")") isa Guard.Stopped
end

@testset "code in the sandbox runs at about its usual speed" begin
  code = "f(n) = (s = 0.0; for i in 1:n; s += sqrt(i); end; s); f(10^6)"
  run(code); include_string(Module(), code)   # compiled once
  t_guard = @elapsed run(code)
  t_plain = @elapsed include_string(Module(), code)
  @test t_guard < 10t_plain + 0.05
end
