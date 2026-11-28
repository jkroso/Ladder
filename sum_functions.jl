# A sum that makes a function, like a generator, becomes a function with no arguments, so Julia compiles it only once

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe handled carry!
@use "github.com/jkroso/UI.jl/Interface/draw" cursor redraw_in! Changed onchanged
@use "./markdown" words
@use "./sheet" units shown
@use "./guard" => Guard
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./takeoff_view" exports...
@use "./julia_levels" exports...
@use "./live_view" exports...
@use "./run_code" exports...
@use "./page_extras" exports...
@use "./agent/ask" exports...
@use "./sandbox" exports...
@use "./file_blocks" exports...

export ALLOWED, BROKEN, LOADED, SUM_FUNCTIONS, allow!, allowed, allowed_file, defined_names!,
       fault!, file_block, file_block_item, file_blocks, here, in_function, lines_now, make!,
       makes_function, page_run, reload!, repository, repository_file, source_file, source_found,
       source_module, sum_function, unit_of, write!

# --- a sum that makes a function --------------------------------------------------------------
#
# Julia compiles code that makes a function each time the code runs, like
# the generator of !`years = sum(exp(-fade * t) for t in 0:0.05:2000)` or the
# `t -> …` of a findfirst. That takes far longer than the sum itself, and a
# drag on a number that the sum reads runs it again on each step. So such a
# sum is made into a function with no arguments the first time, and that
# function runs each time after. It reads the page's names as it runs, so it
# follows them, and Julia compiles it only once.
#
# Only code that means the same in a function does this: code that gives no
# name a value, except inside a `let`, a function or a generator, where the
# name is the code's own. Any other sum runs as the code of a file does.

"""
Run the code of a sum in a line of text in the module `m`, as `run_in` does.
A sum that makes a function runs as a function that's made once: see "a sum
that makes a function".
"""
run_sum(m::Module, code::AbstractString, path::AbstractString) = begin
  f = sum_function(m, code, sandbox_of(m, path))
  f === nothing && return run_in(m, code, path)
  value = Base.invokelatest(f)
  name = sum_name(code)
  name === nothing || Core.eval(m, Expr(:(=), name, QuoteNode(value)))
  value
end

const SUM_FUNCTIONS = Dict{Tuple{Module,String},Any}()   # by the module and the code of a sum

"The function that the code of a sum in the module `m` runs as, or nothing when the code runs as code. With a `sandbox`, the function is made in it."
sum_function(m::Module, code::AbstractString, sandbox=nothing) = begin
  key = (m, String(code))
  haskey(SUM_FUNCTIONS, key) && return SUM_FUNCTIONS[key]
  ex = try Meta.parse(code, raise=false) catch; nothing end
  sum_name(code) === nothing || (ex = ex.args[2])
  made = Expr(:->, Expr(:tuple), Expr(:block, ex))
  f = makes_function(ex) && in_function(ex, true) ? (sandbox === nothing ? Core.eval(m, made) : Guard.run(sandbox, made)) : nothing
  # Typing makes a new sum with each key, so the functions of old sums are forgotten now and then
  length(SUM_FUNCTIONS) >= 500 && empty!(SUM_FUNCTIONS)
  SUM_FUNCTIONS[key] = f
end

"True when the code `ex` makes a function as it runs, or has a loop, which Julia compiles too"
makes_function(ex) = ex isa Expr && (ex.head in (:generator, :comprehension, :typed_comprehension, :->, :do, :function, :for, :while) || any(makes_function, ex.args))

"""
True when the code `ex` means the same in a function as it does on its own.
`top` is true outside a `let`, a function or a generator: there, code that gives
a name a value would give the page's name a value, and in a function it
wouldn't. Code that declares or loads anything, or has a macro, doesn't either.
"""
in_function(ex, top::Bool) = begin
  ex isa Expr || return true
  h = ex.head
  h in (:global, :const, :local, :using, :import, :export, :module, :struct, :abstract, :primitive, :toplevel, :macrocall, :quote) && return false
  # The names in a let, a function or a generator are their own
  h in (:let, :->, :do, :generator, :comprehension, :typed_comprehension) && return all(x -> in_function(x, false), ex.args)
  if h == :function
    # A function with a name gives that name a value
    sig = ex.args[1]
    top && !(sig isa Expr && sig.head == :tuple) && return false
    return all(x -> in_function(x, false), ex.args)
  end
  # The names of a named tuple, and of the keywords of a call, aren't names that get a value
  h in (:tuple, :parameters) && return all(x -> Meta.isexpr(x, :(=)) ? in_function(x.args[2], top) : in_function(x, top), ex.args)
  h == :kw && return in_function(ex.args[2], top)
  top && (h == :(=) || (endswith(string(h), "=") && !(h in (:(==), :(!=), :(<=), :(>=), :(===), :(!==))))) && return false
  all(x -> in_function(x, top), ex.args)
end

"The expression `ex` of a page's code, with `function bar end` before it for each unit, like `bar`, that it defines a function of. See `run_in`."
own_units(m::Module, ex) = begin
  found = filter(n -> unit_of(m, n), defined_names!(Symbol[], ex))
  isempty(found) ? ex : Expr(:toplevel, (Expr(:function, n) for n in unique(found))..., ex)
end

"The names of the functions that the expression `ex` defines, like `f` for `f(x) = x`, added to `out`. A definition can be inside a `begin` block, and have documentation or a macro before it."
defined_names!(out::Vector{Symbol}, ex) = begin
  if Meta.isexpr(ex, (:block, :toplevel))
    foreach(x -> defined_names!(out, x), ex.args)
  elseif Meta.isexpr(ex, :macrocall) && length(ex.args) > 2
    defined_names!(out, last(ex.args))
  elseif is_definition(ex)
    lhs = ex.args[1]
    while Meta.isexpr(lhs, (:where, :(::))) && !isempty(lhs.args)
      lhs = lhs.args[1]
    end
    Meta.isexpr(lhs, :call) && lhs.args[1] isa Symbol && push!(out, lhs.args[1])
  end
  out
end

"True when the name `n` in the module `m` is a unit of a sheet that `m` has with `using`, and not a name of its own or one that it loaded"
unit_of(m::Module, n::Symbol) = begin
  sheet = units()
  Base.invokelatest(isdefined, sheet, n) && Base.invokelatest(isdefined, m, n) || return false
  # The names that `m` has made, and the ones that it loaded by name, like `@use "…/Units.jl" bar`
  n in Base.invokelatest(names, m; all=true, imported=true) && return false
  Base.invokelatest(getglobal, m, n) === Base.invokelatest(getglobal, sheet, n)
end

"""
The module of the page at `path`, which the window `e` asks for. A file of
code that Ladder loaded has the module that Kip made from it, so code that
runs in its window changes what's loaded: see "the code of a thing". The
module of any other page is made the first time, and kept by the page's real
path. It has what a Julia file that Kip loads has, like `@use`, and more
names by the kind of page:

  - The startup page and a folder's page have `Ladder`, as they have when
    Ladder runs their code. Each time Ladder runs one, the page has a new
    module: see `code_module!`.
  - Any other page has the names that its window gives a page's code, like
    UI.jl's components, and each unit of a sheet: see `usual_module`.

The module's name is the page's path. So a page called `stars` can define a
function called `stars`, and two pages with the same name have two modules.
"""
page_module(e, path::AbstractString) = begin
  key = page_key(path)
  # A file of code that Ladder loaded has the module that the file made, so code that runs there changes what's loaded
  loaded = loaded_module(key)
  loaded === nothing || return loaded
  get!(PAGE_WINDOWS, key, e)
  m = get!(() -> ladder_runs(key) ? code_module(key) : usual_module(e, page_module_name(key), key), PAGE_MODULES, key)
  # A window that's newer than the module can give a page's code more names. It gives them once.
  get!(() -> Base.invokelatest(isdefined, m, :Usual) && window_names!(m, e, key), e.nodes, (:page_names, key))
  m
end

"The module of the page at `path`, as `page_module` gives it, with all of the page's code run in it, as a kind of block that the page defines needs"
page_run(e, path::AbstractString) = begin
  m = page_module(e, path)
  key = page_key(path)
  key in PAGES_RUN || (run_page!(m, path); push!(PAGES_RUN, key))
  m
end

"""
Give the file that the window `e` shows a new, empty module for its code, in
place of the one it had. The names, the methods and the files that its code
made or loaded are gone. The new module is made when code next runs on the
file, as it is the first time: see `page_module`. Each window that shows the
file runs its live blocks and its inline code again, in the new module. What
⌘Return showed under the code stays as it was.
"""
reset_module!(e) = begin
  path = e.buf.path
  isempty(path) && delete!(e.nodes, :workspace)
  key = isempty(path) ? "" : page_key(path)
  isempty(key) || (delete!(PAGE_MODULES, key); delete!(PAGES_RUN, key))
  for w in unique!(Any[e; editors])
    w === e || (!isempty(w.buf.path) && page_key(w.buf.path) == key) || continue
    delete!(w.nodes, (:page_names, key))
    # What the page's code made goes, so that it runs again in the new module
    p = w.buf.path
    gone(k) = k isa Tuple && length(k) >= 2 &&
              ((k[1] in (:live, :inline, :given_names, :inline_seen) && k[2] == p) ||
               (k[1] == :replaced && k[2] isa Tuple && k[2][1] == :live && k[2][2] == p))
    foreach(k -> delete!(w.nodes, k), filter(gone, collect(keys(w.nodes))))
    empty!(w.flows)
  end
  nothing
end

"""
The file on this Mac that the source `source` names inside a repository, like
`github.com/sam/blocks/progress.md`. Kip gets the repository if it isn't here.
"""
repository_file(source::AbstractString) = begin
  user, repo, tag, inside = match(Kip.gh_shorthand, source).captures
  folder = Base.invokelatest(Kip.checkout, Base.invokelatest(Kip.getrepo, user, repo), user, repo, tag)
  joinpath(folder, something(inside, ""))
end

"Where the function of the block that opens on line `s` of `b` comes from, or nothing when no file defines its language"
block_source(b::Buffer, s::Int) = foreign(b.path) || sandboxed(b.path) ? nothing : block_source(b.lines[s], kinds(b)[s].lang, isempty(b.path) ? "" : dirname(b.path))

"The `user/repo` of a source that's a GitHub repository, or nothing for a file on this Mac"
repository(source::AbstractString) = (m = match(r"^github\.com/([\w\-.]+)/([\w\-.]+)", source); m === nothing ? nothing : "$(m[1])/$(m[2])")

"The GitHub repositories whose code you let a block run, since Ladder opened"
const ALLOWED = Set{String}()

"The file that keeps the repositories you allowed, one on each line"
allowed_file() = joinpath(dirname(settings_file()), "repositories")

"True when you have let a block run the code of the GitHub repository `repo`"
allowed(e, repo::AbstractString) = repo in ALLOWED || (e.remember && isfile(allowed_file()) && repo in eachline(allowed_file()))

"Let a block run the code of the GitHub repository `repo`, now and when Ladder next opens"
allow!(e, repo::AbstractString) = begin
  allowed(e, repo) && return
  push!(ALLOWED, repo)
  e.remember || return
  try
    mkpath(dirname(allowed_file()))
    open(io -> println(io, repo), allowed_file(), "a")
  catch
    # A file that can't be written only means Ladder asks again the next time it opens
  end
  nothing
end

cursor(::FileBlock) = :arrow

"The view of the `n`th block of the page in the language `lang`, which the file or the repository `source` defines"
file_block(e, lang, source, n) = begin
  v = get!(() -> FileBlock(n=n, lang=lang), e.nodes, (:block, lang, e.buf.path, n))
  own!(node!(Document, e, :document), v)
  v.source == source || (v.source = source; v.from = nothing; v.file = ""; v.state = :new)
  v
end

"What the block in the language `lang` from line `i` to line `t` shows. A file or a repository, `source`, defines the language."
file_block_item(e, lang, source, i, t, n) = begin
  v = file_block(e, lang, source, n)
  v.first, v.last = i, t
  reread!(v, e.buf.lines[i+1:t-1])
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(v)), (e.width, 9999px))
  Live(v, concrete.height + 2LIVE_GAP)
end

reread!(v::FileBlock, lines) = begin
  (lines == v.lines && v.state != :new) && return v
  v.lines = lines
  make!(v)
end

"True when Kip has the GitHub repository `repo` on this Mac, so that nothing has to come from GitHub"
here(repo::AbstractString) = isdir(joinpath(Kip.repos, repo))

"The module of the file or the repository `source`. A path like `./progress.jl` starts from the folder of the page."
source_module(e, source::AbstractString) = begin
  folder = isdir(docdir(e)) ? docdir(e) : pwd()
  # A Markdown page isn't Julia code, so Kip doesn't load it: the page's `julia` blocks make its module
  if ismarkdown(source)
    file = repository(source) === nothing ? source_file(e, source) : repository_file(source)
    isfile(file) || error("Ladder can't find the page $source.")
    return cd(() -> Base.invokelatest(page_run, e, realpath(file)), folder)
  end
  cd(() -> Base.invokelatest(Kip.require, source, folder), folder)
end

"True when `source` names a file or a folder that's on this Mac, as Kip looks for it: the path as it is, or with `.jl` after it"
source_found(e, source::AbstractString) = begin
  path = startswith(source, "~/") ? homedir() * source[2:end] : normpath(joinpath(docdir(e), source))
  ispath(path) || isfile(path * ".jl")
end

"The file on this Mac that `source` names, or \"\" when it names a folder, or a file that isn't there"
source_file(e, source::AbstractString) = begin
  path = startswith(source, "~/") ? homedir() * source[2:end] : normpath(joinpath(docdir(e), source))
  isfile(path) || (path *= ".jl")
  isfile(path) ? realpath(path) : ""
end

"When each file that defines a kind of block was last loaded: the time that the disk gave for it then"
const LOADED = Dict{String,Float64}()

"The files that define a kind of block and didn't load, with what went wrong"
const BROKEN = Dict{String,String}()

"""
Load the file of the block of `v` again if it was saved since it was loaded,
so that a kind of block changes as you write it. Each block that the file
defines is then made again from its lines.
"""
reload!(v::FileBlock) = begin
  isempty(v.file) && return v
  at = mtime(v.file)
  at == 0 && return v   # the file is gone, so the block stays as it is
  if at != get(LOADED, v.file, at)
    write_blocks!(editor(v))   # what the blocks hold goes into their lines first, since they're made again from those
    LOADED[v.file] = at
    delete!(BROKEN, v.file)
    m = get(Kip.modules, v.file, get(PAGE_MODULES, page_key(v.file), nothing))
    try
      # The file's new code goes into the module that it has. A file that didn't load the first time has none yet.
      m === nothing || (ismarkdown(v.file) ? Base.invokelatest(run_page!, m, v.file) : Base.include(m, v.file))
    catch err
      BROKEN[v.file] = trouble(err)
    end
  end
  v.read == get(LOADED, v.file, v.read) || (v.state = :new)
  v
end

"""
The lines of the block of `v` as what the block made writes them now. It's
nothing when the file has no function `written` for what was made.
"""
lines_now(v::FileBlock) = begin
  w = named(v.from, :written)
  (w === nothing || !Base.invokelatest(applicable, w, v.value)) && return nothing
  out = Base.invokelatest(w, v.value)
  String[String(l) for l in (out isa AbstractString ? split(out, '\n') : out)]
end

"""
The Shown that draws what the block of `v` made: its node, or its words when
it has no node. Words show as they are, and any other value as Julia prints it.
"""
shown(v::FileBlock) = begin
  node = Base.invokelatest(present, v.value)
  words = node !== nothing ? "" : v.value isa AbstractString ? v.value : Base.invokelatest(repr, "text/plain", v.value)
  s = own!(v, Shown(value=node === nothing ? note(words, colours.ink) : node))
  s.value isa SemanticUI && own!(s, s.value)
  s
end

"Note that the block of `v` can't show, and why"
fault!(v::FileBlock, why) = begin
  v.state, v.fault = :fault, String(why)
  push!(problems, v.fault)
  v
end

"""
Make what the block of `v` shows from its lines: load its file, and give the
lines to the function that has the language's name. A repository that you
haven't allowed isn't loaded: the block asks first. With `now`, a repository
that has to come from GitHub comes now. Without it, the block first says that
it's coming, because the window stops while it comes.
"""
make!(v::FileBlock; now=false) = begin
  e = editor(v)
  old = v.shown
  v.value = v.shown = v.said = nothing
  repo = repository(v.source)
  if v.from === nothing && repo !== nothing
    allowed(e, repo) || (v.state = :ask; return v)
    (now || here(repo)) || (v.state = :wait; return v)
  end
  v.from === nothing && repo === nothing && !source_found(e, v.source) &&
    return fault!(v, "Ladder can't find the file $(v.source). The line that opens this block names it.")
  repo === nothing && isempty(v.file) && (v.file = source_file(e, v.source))
  if !isempty(v.file)
    v.read = get!(() -> mtime(v.file), LOADED, v.file)
    haskey(BROKEN, v.file) && return fault!(v, BROKEN[v.file])
  end
  try
    v.from === nothing && (v.from = source_module(e, v.source))
    f = named(v.from, Symbol(v.lang))
    f === nothing && return fault!(v, "$(v.source) has no function called $(v.lang). A block in the language $(v.lang) shows what that function makes of the block's lines.")
    v.value = Base.invokelatest(f, copy(v.lines))
    v.shown = shown(v)
    # What a new value shows can carry on from what the last one showed, like a bar that slides to its new length
    old isa Shown && v.shown.value isa SemanticUI && typeof(old.value) === typeof(v.shown.value) && Base.invokelatest(carry!, v.shown.value, old.value)
    v.said = lines_now(v)
    v.state = :made
  catch err
    # A file that didn't load is tried again when it's saved
    v.from === nothing && !isempty(v.file) && (BROKEN[v.file] = trouble(err))
    fault!(v, trouble(err))
  end
  v
end

"""
Write the lines of what the block of `v` made into the block, if they aren't
the lines that it has. With `typing`, writes that come one soon after another
are one step for ⌘Z. Nothing is written when the block's lines in the page
aren't the ones that this was made from: then it's made again from those.
"""
write!(v::FileBlock; typing=false) = begin
  v.wants = false
  (v.state == :made && v.said !== nothing) || return v
  b = editor(v).buf
  span = block_lines(b, v.lang, v.n)
  (span !== nothing && b.lines[span[1]+1:span[2]-1] == v.lines) || return v
  now = try
    lines_now(v)
  catch err
    return fault!(v, trouble(err))
  end
  (now === nothing || now == v.said) && return v
  v.said = v.lines = now
  # A value that shows as words has new words now
  Base.invokelatest(present, v.value) === nothing && (v.shown = shown(v))
  write_block!(v, v.lang, now; typing)
end

"The views of the blocks of the page of `e` that a file defines"
file_blocks(e) = FileBlock[node for (key, node) in e.nodes if node isa FileBlock && key[3] == e.buf.path]

"""
Write the lines of every block of the page that a file defines. Whatever
reads the page's text calls this first: a save, a copy, a page of HTML,
another page that takes the window.
"""
write_blocks!(e) = (foreach(write!, file_blocks(e)); e)

# What was made asks for its lines to be written, with UI.jl's `changed!`
onchanged(v::FileBlock, ev::Changed) = begin
  ev.now ? write!(v) : (v.wants = true; redraw_in!(v, 0))
  handled
end

block_tick!(v::FileBlock) = begin
  v.state == :get && return make!(v, now=true)
  # A repository that another block of the page asked about, and that you allowed there
  v.state == :ask && repository(v.source) in ALLOWED && return make!(v)
  reload!(v)
  v.state == :made || return v
  # The page shows the block's lines while the caret is in them, so they're written as the caret goes in
  b = editor(v).buf
  span = block_lines(b, v.lang, v.n)
  inside = span !== nothing && incode(b, span[1])
  inside && !v.inside && write!(v)
  v.inside = inside
  # A write that was asked for waits until the mouse lets go, so that ⌘Z takes back a whole drag
  v.wants && !held(v, Keys.mouse_left) && write!(v, typing=true)
  v
end

act!(v::FileBlock, action, w) = begin
  allow!(editor(v), repository(v.source))
  v.state = :wait
  make!(v)
  handled
end

describe(v::FileBlock) = begin
  v.state == :made && return Column(width(grow=grow), Alignment.Start, v.shown)
  repo = something(repository(v.source), v.source)
  if v.state == :ask
    return Column(block_look()...,
      Row(width(grow=grow), padding(12px, 16px), child_gap=12px, Alignment.Center,
        Box(width(grow=grow), Alignment.Start,
          Text("This block runs code from github.com/$repo. Run it only if you trust who wrote it.", size=13px, family=SANS, color=colours.dim, wrap=WrapMode.words)),
        block_button!(v, :allow, :allow, words="Run the code", bold=true)))
  end
  if v.state in (:wait, :get)
    # The words are drawn in one frame, and the repository comes in the next
    v.state = :get
    redraw_in!(v, 0)
    return Column(block_look()..., block_note("Getting github.com/$repo…"))
  end
  note(v.fault, colours.accent)
end
