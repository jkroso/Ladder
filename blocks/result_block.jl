# The view of a `result` block: what code comes to
#
# A code block in the language `result` shows what Julia code comes to. It
# holds the code, or the name of a Julia file:
#
#     ```result
#     wall.jl
#     ```
#
# A name with no / at its start is beside the page, as in a `view` block. The
# code gets the names that the page's sums give, with their units: a page with
# !`l = 16m` gives the code `l`, which is 16m. Code in the block runs in the
# page's module, as the page's `julia` and `ui` blocks do, so it has the names
# that they make too. A file runs in a module of its own. Before each run,
# that module gets the sums whose names the file uses and doesn't make itself
# (see `used_names`). So a name that the file makes, like a constant N, never
# changes what the page's sums mean, where N is a newton, and a sum never
# clashes with the file's own constant of the same name. The block shows what
# the code's last line comes to:
#
#   - The bytes of a .glb file show as a model, in the model viewer.
#   - A node draws itself, as it does in a `ui` block.
#   - Any other value shows as text.
#
# The code runs again when a sum of the page that it can use changes, as
# while you drag a number, when the page's code runs with ⌘Return, and when you
# change the code or save the file. Only its first run, a run after a change, and a run after
# one that went wrong run all of it. Each other run leaves out the lines that
# make something that stays: a function, a type, a constant, or what `@use`
# loads (see `lasting`). So a drag doesn't make Julia compile the functions
# again, and a model keeps up with the number. A model stays turned as it was,
# and as big. The code runs in a thread of its own, as the code of a page does,
# so the window goes on drawing while slow code runs. What it came to last
# shows until it comes back.
#
# A line like `aspect: 16:9` sets the shape of a model, as in a `view` block.
# While the mouse is over a model, a button beside the block's top right
# corner makes the model fill the window. A block that names a file has a
# button that goes to the file too, as a click with ⌘ held does.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe handled carry!
@use "github.com/jkroso/UI.jl/Interface/draw" cursor redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/STLViewer" STLViewer show!
@use "../markdown" words
@use "./sheet" parts shown
@use "../base" exports...
@use "./takeoff_view" exports...
@use "../window/fill_view" exports...
@use "./live_view" exports...
@use "./view_block" exports...

export RESULT, ResultBlock, RESULT_WAIT, PAGE_RUNS, RESULT_MODULES, result_named, page_sums, lasting,
       made_name, used_names, ends_lasting, result_module, result_run, glb_bytes, finish!, result!,
       result_fills, result_content, result_html

const RESULT = "result"
push!(BLOCK_ICONS, "code-square")

"What a `result` block shows: what its code, or the Julia file that it names, comes to"
@def mutable struct ResultBlock <: SemanticUI
  n::Int = 0                               # its place among the page's `result` blocks
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  lines::Any = nothing                     # the lines that it was last read from
  source::Vector{String} = String[]        # those lines, with each line of settings left empty: its code, or the name of its file
  settings::Vector{String} = String[]      # its lines of settings, like `aspect: 16:9`, as they're written
  aspect::Float64 = 0.0                    # its width over its height, from its line `aspect:`, or 0 when it has none
  named::String = ""                       # the name of the file that it runs, as it's written, or "" when the block holds the code
  file::String = ""                        # that file's whole path, as `view_target` gives it
  code::String = ""                        # the code that ran last
  saved::Float64 = 0.0                     # when the file had been saved, as the last run found it
  seen::Int = -1                           # `sums_run` when the page's sums were last read
  sums::Any = nothing                      # the page's sums as they were then: see `page_sums`
  wanted::Set{Symbol} = Set{Symbol}()      # the names of sums that its file's code uses: see `used_names`
  given::Any = nothing                     # the sums, and how many times the page's code had run, when the code last ran
  task::Any = nothing                      # the run that hasn't come back yet
  whole::Bool = true                       # that run, or the last one, ran all of the code
  ready::Bool = false                      # a run has come back
  value::Any = nothing                     # what the code came to last
  text::String = ""                        # that value as text, when it shows as text
  node::Any = nothing                      # what shows it: the viewer of a model, a Shown for a node, or nothing for text
  fault::String = ""                       # what went wrong in the last run, or ""
  parts::Dict{Any,Any} = Dict{Any,Any}()
end

"How many seconds a `result` block waits for its code, before the window goes on drawing with what the code came to last"
const RESULT_WAIT = 0.03

"How many times the `julia` code of each page has run with ⌘Return, by the page's path as `page_key` gives it. A `result` block runs again when it's more."
const PAGE_RUNS = Dict{String,Int}()

"The module that the Julia file of a `result` block runs in, for each page and file: see `result_module`"
const RESULT_MODULES = Dict{Tuple{String,String},Module}()

"""
The name of the Julia file that the lines `source` of a `result` block give,
as it's written, or "" when they hold code. Such a block has one line, a name
or a path that ends in .jl, with no space in it.
"""
result_named(source) = begin
  lines = filter(l -> !isempty(strip(l)), source)
  length(lines) == 1 && occursin(r"^[^\s()\[\]{}\"'`=,;#]+\.jl$", strip(lines[1])) ? String(strip(lines[1])) : ""
end

reread!(v::ResultBlock, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  # A line of settings is no code. It's left empty, so each line of the code keeps its number in the page.
  set = [i for i in eachindex(lines) if view_setting(lines[i]) !== nothing]
  v.settings = String.(lines[set])
  said = filter(!isnothing, view_setting.(v.settings))
  v.aspect = isempty(said) ? 0.0 : aspect_of(last(said)[2])
  v.source = [i in set ? "" : String(l) for (i, l) in enumerate(lines)]
  v.named = result_named(v.source)
  v.file = isempty(v.named) ? "" : view_target(editor(v), [v.named])
  v
end

"""
The sums of the page of `e` that give a name, each with what it came to, as
the page's module has it: !`l = 16m` gives `:l => 16m`. A sum that went wrong,
or that hasn't run, is left out.
"""
page_sums(e) = begin
  b = e.buf
  out = Dict{Symbol,Any}()
  values = get(e.nodes, (:sum_values, b.path), nothing)
  values === nothing && return out
  for (_, code, n) in given_and_sums(e, typemax(Int), true)[2]
    haskey(values, (code, n)) || continue
    shown = get(e.nodes, (:inline, b.path, code, n), nothing)
    (shown isa Tuple && !shown[2]) || continue
    out[Symbol(sum_name(code))] = values[(code, n)]
  end
  out
end

"""
True when `ex`, an expression at the top of some code, makes or loads
something that stays: a function, a macro, a type, a constant, a module, or
the names that `using`, `import` or `@use` loads. A docstring or a macro round
one of those, like `@kwdef struct …`, is one too. A `result` block makes them
again only when its code changes: see `result_run`.
"""
lasting(ex) = begin
  ex isa Expr || return false
  ex.head in (:function, :macro, :struct, :abstract, :primitive, :const, :module, :using, :import, :export, :public) && return true
  if ex.head == :(=)
    # f(x) = …, with a type or a `where` after it, or not
    left = ex.args[1]
    while Meta.isexpr(left, (:where, :(::)))
      left = left.args[1]
    end
    return Meta.isexpr(left, :call)
  end
  ex.head == :macrocall || return false
  name = ex.args[1]
  name = name isa GlobalRef ? name.name : Meta.isexpr(name, :.) && name.args[end] isa QuoteNode ? name.args[end].value : name
  name == Symbol("@use") || lasting(ex.args[end])
end

"""
The name that `ex`, an expression at the top of some code, gives a value: the
name of a function, a constant, a type or a global, like `f` for `f(x) = 2x`.
It's nothing for any other expression.
"""
made_name(ex) = begin
  while Meta.isexpr(ex, :macrocall)
    ex = ex.args[end]
  end
  Meta.isexpr(ex, (:const, :global)) && (ex = ex.args[1])
  ex isa Expr || return nothing
  target = ex.head in (:(=), :function, :abstract) ? ex.args[1] : ex.head == :struct ? ex.args[2] : nothing
  # f(x)::T where T, and P{T} <: Q
  while target isa Expr && target.head in (:where, :(::), :call, :curly, :(<:))
    target = target.args[1]
  end
  target isa Symbol ? target : nothing
end

"""
The names that `code` uses and doesn't give a value at its top level. A file
of a `result` block gets the page's sums with these names, and no others: a
sum with the name of the file's own constant, like `tubes`, would clash with it.
"""
used_names(code) = begin
  all = try Meta.parseall(code) catch; return Set{Symbol}() end
  used = Set{Symbol}()
  walk(x) = x isa Symbol ? push!(used, x) : x isa Expr ? foreach(walk, x.args) : nothing
  walk(all)
  setdiff!(used, filter(!isnothing, made_name.(all.args)))
end

"True when the last expression of `code` makes something that stays, so a run that leaves out such lines doesn't change what the code comes to"
ends_lasting(code) = begin
  all = try Meta.parseall(code) catch; return false end
  i = findlast(x -> !(x isa LineNumberNode), all.args)
  i !== nothing && lasting(all.args[i])
end

"""
The module that the Julia file `file` of a `result` block of the page of `e`
runs in. It has the names that a page's code has (see `usual_module`), and
it's kept for the page and the file, so what the file made stays between runs.
"""
result_module(e, file::AbstractString) = begin
  key = isempty(e.buf.path) ? "" : page_key(e.buf.path)
  get!(RESULT_MODULES, (key, file)) do
    usual_module(e, Symbol("⭒", Base.Filesystem.contractuser(file)), isempty(key) ? nothing : key)
  end
end

"""
Run `code` in the module `m`, as the file at `path` and in the folder `dir`.
With `whole`, all of it runs. Without, the lines that make something that
stays are left out, since they were made when the code last ran whole. `sums`
is each name of the page's sums with its value, which the module gets first:
a file's module has none of the page's names but these. A name that the module
can't take, like one that the code already used as a unit's, keeps what it
had. It gives true and what
the code came to, or false and what went wrong. It runs in a thread of its
own: see `result!`.
"""
result_run(m, code, path, dir, whole, sums) = try
  for (name, value) in something(sums, ())
    try Core.eval(m, Expr(:(=), name, QuoteNode(value))) catch end
  end
  (true, cd(() -> include_string(ex -> whole || !lasting(ex) ? own_units(m, ex) : nothing, m, code, path), dir))
catch err
  # Julia says which line of the code it was. The long name that Julia has for the module says nothing more.
  said = replace(trouble(err), r" in `Main\.[^`]*`" => "")
  (false, err isa LoadError ? "Line $(err.line) of $(basename(err.file)): $said" : said)
end

"True when `x` is the bytes of a .glb file, which show as a model"
glb_bytes(x) = x isa Vector{UInt8} && length(x) >= 12 && x[1:4] == b"glTF"

"Take what the run of `v` came to, if the run has come back: a model goes to the block's viewer, which keeps how it's turned"
finish!(v::ResultBlock) = begin
  t = v.task
  (t === nothing || !istaskdone(t)) && return v
  v.task = nothing
  ok, value = try fetch(t) catch err; (false, trouble(err)) end
  v.ready = true
  v.fault = ok ? "" : String(value)
  # Code that ends with a function comes to what it came to when it last ran whole
  (ok && (v.whole || !ends_lasting(v.code))) || return v
  v.value = value
  if glb_bytes(value)
    v.node isa STLViewer || (v.node = own!(v, STLViewer(path=isempty(v.file) ? editor(v).buf.path : v.file, height=MODEL_HEIGHT, foot=false)))
    show!(v.node, value)
    return v
  end
  # A relative path, like fs"plan.pdf", is beside the page or the file, as it is for a live block
  node = cd(() -> Base.invokelatest(present, value), isempty(v.file) ? run_place(editor(v))[2] : dirname(v.file))
  if node === nothing
    v.node = nothing
    v.text = value isa AbstractString ? String(value) : try Base.invokelatest(value_text, value) catch err; trouble(err) end
  else
    shown = Shown(value=node)
    node isa SemanticUI && own!(shown, node)
    # A node that carries on from the one before, like a chooser that slides to its choice, gets what that one had
    v.node isa Shown && typeof(v.node.value) === typeof(node) && Base.invokelatest(carry!, node, v.node.value)
    v.node = own!(v, shown)
  end
  v
end

"""
Run the code of the `result` block `v` again, when the code changed, or the
file was saved, or the sums of the page of `e` changed, or the page's code ran,
since its last run. It runs in a thread of its own, after any code of a page
that runs now. The window waits `RESULT_WAIT` seconds for it, so quick code
shows what it came to in the same frame, and a model doesn't fall behind a
number that you drag.
"""
result!(v::ResultBlock, e) = begin
  finish!(v)
  # The sums run as their lines are laid out, so `sums_run` says when they may have changed
  v.seen == sums_run[] || (v.seen = sums_run[]; v.sums = page_sums(e))
  v.task === nothing || (redraw_in!(v, 0.05); return v)
  ours = isempty(v.file)
  saved = ours ? 0.0 : mtime(v.file)
  code = ours ? join(v.source, "\n") : saved == v.saved ? v.code : read(v.file, String)
  # A file gets the sums whose names its code uses, and runs again only when one of those changes
  ours || code == v.code && v.given !== nothing || (v.wanted = used_names(code))
  sums = ours ? v.sums : filter(((k, _),) -> k in v.wanted, v.sums)
  given = (sums, isempty(e.buf.path) ? 0 : get(PAGE_RUNS, page_key(e.buf.path), 0))
  new = v.given === nothing || code != v.code || saved != v.saved
  (new || given != v.given) || return v
  # The page's code made the names that the code uses. A page from somebody else runs none.
  m = try
    ours ? cd(() -> running_code(identity, e), run_place(e)[2]) : (running_code(identity, e); result_module(e, v.file))
  catch err
    v.fault, v.ready, v.given, v.code, v.saved = trouble(err), true, given, code, saved
    return v
  end
  # A run after one that went wrong runs all of the code, since what went wrong could be a line that stays
  v.whole = new || !isempty(v.fault)
  v.code, v.saved, v.given = code, saved, given
  # The code in the block runs as the page, with the number that each of its lines has in the page
  path, dir = ours ? run_place(e) : (v.file, dirname(v.file))
  text, whole, sums = ours ? "\n"^v.first * code : code, v.whole, ours ? nothing : sums
  before = LAST_RUN[]
  v.task = LAST_RUN[] = Threads.@spawn begin
    before === nothing || try wait(before) catch end
    Base.invokelatest(result_run, m, text, path, dir, whole, sums)
  end
  # A test waits for every run, as it does for the code of a page
  until = time() + (isfinite(RUN_WAIT[]) ? RESULT_WAIT : Inf)
  while !istaskdone(v.task) && time() < until
    sleep(0.001)
  end
  finish!(v)
  # The sums under the block run after it's laid out, so another frame reads those too
  redraw_in!(v, 0)
  v
end

"What fills the window when you click the button beside the `result` block `v`: its model, or the diagram or the video that its code made, or nothing"
result_fills(v::ResultBlock) = !(v.ready && isempty(v.fault)) ? nothing :
                               v.node isa STLViewer ? (:node, v.node) : v.node isa Shown ? fill_what(v.node.value) : nothing

"What the `result` block `v` shows: a model by itself, or what the code came to or what went wrong, in the block's frame"
result_content(v::ResultBlock, e) = begin
  if v.ready && isempty(v.fault) && v.node isa STLViewer
    zoomed_node(e, v.node) || (v.node.height = view_high(v, e))
    return bare_view(in_page(e, v.node))
  end
  content = !isempty(v.fault) ? note(v.fault, colours.accent) :
            !v.ready ? Box(padding(4px, 6px), label("Running $(isempty(v.named) ? "the code" : v.named)…", 12px, color=colours.dim)) :
            v.node !== nothing ? v.node : note(v.text, colours.ink)
  isempty(v.named) && return Column(block_look()..., padding(6px), name="Result", content)
  about = v.named * "  ·  Changed " * Libc.strftime("%-d %b %Y, %H:%M", mtime(v.file))
  Column(block_look()..., padding(6px), child_gap=8px, name="Result", content, Box(padding(4px, 0px), label(about, 12px, color=colours.dim)))
end

describe(v::ResultBlock) = begin
  e = editor(v)
  told(words) = Column(block_look()..., name="Result", block_note(words))
  all(l -> isempty(strip(l)), v.source) &&
    return told("Write Julia code in this block, or the name of a Julia file like model.jl, to show what it comes to")
  if !isempty(v.named) && !isfile(v.file)
    # A page from a web server runs a copy of the file, which may still be on its way
    url = in_browser(e.buf.path) && !isempty(v.file) ? remote_src(e, v.named) : nothing
    why = url === nothing ? nothing : view_coming(e, url, v.file)
    return told(something(why, "$(v.named) isn't there"))
  end
  result!(v, e)
  with_theme(component_theme(e.zoom)) do
    content = result_content(v, e)
    what = result_fills(v)
    # A block that names a file has a button that goes to it. A model has one that makes it fill the window.
    f = if !isempty(v.file)
      g = fillable(v, (:go, v.file), content, wide=:grow)
      g isa Fillable && (g.also = what)
      g
    elseif what !== nothing
      fillable(v, what, content, wide=:grow)
    else
      delete!(fills(e), objectid(v))
      content
    end
    Box(width(grow=grow), Alignment.Start, f)
  end
end

# The block's button stands for what it shows, so a model or a diagram in it has no button of its own
own_button(::ResultBlock) = true

"Show the file of the `result` block `v` in the window, as a click on a link to it does. ⌘⌥← comes back."
go_view!(v::ResultBlock) = (isfile(v.file) && show_path!(top_editor(editor(v)), v.file); handled)

cursor(::ResultBlock) = :arrow

# A click with ⌘ held goes to the file. The rest are the model's, or go on to the document, which picks the block.
onkey(v::ResultBlock, ::KeyPress{Keys.mouse_left}) = only_held(v, Keys.cmd) && !isempty(v.file) ? go_view!(v) : nothing

"The `result` block as HTML: what its code came to, as text, or a link to its file, or nothing to show its lines"
result_html(e, v::ResultBlock) = begin
  escaped(s) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")
  v.ready && isempty(v.fault) && v.node === nothing && return "<pre>" * escaped(v.text) * "</pre>"
  isempty(v.named) ? nothing : "<p><a href=\"$(escaped(v.named))\">$(escaped(v.named))</a></p>"
end

BLOCKS[RESULT] = ResultBlock
block_name(::Type{ResultBlock}) = "Result"
block_icon(::Type{ResultBlock}) = "code-square"
block_insert(::Type{ResultBlock}) = ("Result", ["```$RESULT", "", "```"], (2, 0))
block_is_code(::Type{ResultBlock}) = true
block_html(e, v::ResultBlock) = result_html(e, v)
