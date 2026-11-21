# Runs the scripts of a page, and gives them the page: `document`, its
# elements, events and timers.
#
#     doc = document(html)
#     s = Scripts(doc; load, base)     # a JavaScript world for the page, with `window` and `document` in it
#     start!(s)                        # run each <script> of the page in its order, then say that the page is read
#     s.changed                        # a script has changed the tree of `doc` since this was last set to false
#     step!(s)                         # run the timers that are due. Gives how many seconds until the next, or nothing.
#     click!(s, element, x, y)         # tell the scripts of a click. False when a script said to do no more.
#     fire!(s, element, "input")       # tell them of any other event
#     s.log                            # what the scripts printed, and the errors that they threw
#     evaluate(s, "document.title")    # run more JavaScript in the page
#     close(s)
#
# The tree stays what dom.jl made: the same `Element` and `Text` objects that
# the styles and the layout read. A script holds a node as a number, and the
# functions under "what a script can ask" read and change the node of a number.
# window.jl, which is JavaScript, makes the objects that a script sees from
# those functions.
#
# A script that throws stops, and the page goes on: what it threw is in
# `s.log` as an `:error`. `say(level, text)` is called with each line too.
#
# `load(address)` gives the bytes or the text of a file that the page names, or
# nothing: a script with a `src`, and what a script asks for with `fetch` or
# XMLHttpRequest. Nothing is asked of the web here. For a file that's on its
# way, `load` gives `:waiting`: `step!` asks again, and the script that waits
# for it goes on when it has come.
#
# What the scripts see of the window, they ask of four functions that the
# caller can set: `s.window()` is its size, `s.scroll()` is how far down the
# page its top is, and `s.scroll(y)` moves it there. `s.go(address)` goes to
# another page, as when a script sets `location.href` or sends a form. With
# none, the page stays and the log says so. `s.focused(element)` is told which
# element a script gave the keyboard. `allowed(address)` says whether a
# script may read the file at an address with `fetch` or XMLHttpRequest: a
# browser lets a script read another site's file only when that site agrees.
# With none, a script reads whatever `load` gives.
#
# A `<script type="module">` runs too, with the modules that it imports, and
# so does `import()`. The page's `<script type="importmap">` says where a
# name like `three` is. Modules wait for their files, and run after the
# page's other scripts, in the page's order: see "modules" below and
# module.jl. The page is ready (`DOMContentLoaded`) once they've run. A
# module may take 30 seconds when it first runs, since that's often where it
# builds what the page shows.
#
# What a script can't do here:
#
# - `document.write`. The page is read before its first script runs, so a
#   script in the <head> sees the whole page.
# - Send anything: `fetch` and XMLHttpRequest only get, through `load`, and a
#   form that sends with "post" goes nowhere.
# - Workers, WebSocket, shadow trees and custom elements. A <canvas> draws in 2D
#   (context.jl) and with WebGL (gl.jl), but not with WebGPU.
# - `getComputedStyle` knows only what `computed` gives: see live.jl.
#
# A list like `childNodes` or `children` is the nodes as they were when it was
# asked for. It doesn't change when the page does.
#
# The page that the scripts changed is laid out by live.jl, which gives this
# file the three things that need a layout: `place`, `at` and `computed`.

@use Random: RandomDevice
@use "./jsc" => JS
@use "./jsc" Context Object ScriptError
@use "./dom" Node Element Text Document document attr text VOID RAW
@use "./css" selectors matches resolve media
@use "./form" sent
@use "./window" WINDOW
@use "./context" => Drawing
@use "./module" Converted script_of wrapped LOADER
@use "./gl" giveback!

"The modules of a page: where its import map says each name is, and each module that was asked for"
mutable struct Modules
  imports::Vector{Pair{String,String}}                           # a name, or the start of an address, and the address that it's at
  scopes::Vector{Pair{String,Vector{Pair{String,String}}}}       # the same for the modules whose address starts with the first
  made::Dict{String,Any}         # each module by its address: (its Converted, the addresses that it imports, its own address), or the error that stopped it
  defined::Set{String}           # the modules that the page has the function of
  named::IdDict{Element,String}  # the address that each <script type="module"> with no file is known by
  limit::Any                     # how many seconds the page's other scripts may run, or nothing for no limit
end
Modules(limit=nothing) = Modules(Pair{String,String}[], Pair{String,Vector{Pair{String,String}}}[], Dict{String,Any}(), Set{String}(), IdDict{Element,String}(), limit)

# How many seconds a module may take when it first runs. A module often builds what the page shows then, like a scene
# of three.js, which can take longer than the page's other scripts may.
const MODULE_LIMIT = 30

"The scripts of a page, and what they need of it"
mutable struct Scripts
  js::Context
  doc::Document
  nodes::Dict{Int,Node}          # the nodes that a script may hold, by number
  numbers::IdDict{Node,Int}
  last::Int                      # the last number that was given
  kept::Int                      # how many nodes had a number after the last sweep
  changed::Bool                  # a script changed the tree since the page was laid out
  log::Vector{Tuple{Symbol,String}}
  say::Function                  # called with the level and the text of each line of the log
  load::Function
  base::String                   # the address of the page
  place::Function                # the rectangles of an element's box on the page: (left, top, wide, tall) each
  at::Function                   # the element at a point of the page, or nothing
  computed::Function             # what the page's CSS gives an element for a property, as CSS writes it, or nothing
  window::Function               # how wide and how high the window that the page is seen through is
  hooks::Dict{String,Object}     # the functions of window.jl that Julia calls
  ran::IdDict{Element,Bool}      # the <script> elements that have run
  contents::IdDict{Element,Element}   # what's in each <template>: a fragment that's kept apart from the page
  selectors::Dict{String,Any}    # each selector that a script has used, read
  started::Float64
  scroll::Function               # `scroll()` is how far down the page the top of the window is, and `scroll(y)` moves it there
  go::Any                        # `go(address)` goes to another page, or nothing when the page can go nowhere
  focused::Function              # told the element that has the keyboard now, or nothing
  allowed::Function              # true when a script may read what's at an address, with `fetch` or XMLHttpRequest
  pending::Vector{Element}       # the <script> elements whose file is on its way
  modules::Modules
  unready::Bool                  # the page waits for its modules before it says that it's ready
end

# No more lines than this are kept in the log: a script in a loop can print for ever
const LINES = 1000
# How many ms pass before a file that's on its way is asked for again
const PATIENCE = 50.0

"""
A JavaScript world for the page of `doc`. `load(address)` gives the bytes or
the text of a file, or nothing. `base` is the address of the page. `limit` is
how many seconds a script may run before it's stopped.
"""
Scripts(doc::Document; load=address -> nothing, base="", say=(level, text) -> nothing, limit=10,
        place=e -> NTuple{4,Float64}[], at=(x, y) -> nothing, computed=(e, name) -> nothing, window=() -> (1024.0, 768.0),
        scroll=(y...) -> 0.0, go=nothing, focused=e -> nothing, allowed=address -> true) = begin
  s = Scripts(Context(; limit), doc, Dict{Int,Node}(), IdDict{Node,Int}(), 0, 0, false, Tuple{Symbol,String}[], say, load, String(base),
              place, at, computed, window, Dict{String,Object}(), IdDict{Element,Bool}(), IdDict{Element,Element}(), Dict{String,Any}(), time(),
              scroll, go, focused, allowed, Element[], Modules(limit), false)
  apart!(s, doc.root)
  made = JS.evaluate(s.js, WINDOW; name="window.js")(natives(s))
  JS.evaluate(s.js, LOADER; name="modules.js")(Dict{String,Any}(
    # What `import()` asks: the address of the module, once it's there with what it imports, false while a file is on its way
    "gather" => (name, from) -> begin
      address = module_address(s, name, from)
      address === nothing && error("No module is named $name")
      got = gather!(s, address)
      got === :waiting ? false : got === true ? address : error(got)
    end,
    "resolve" => (name, from) -> something(module_address(s, name, from), name)))
  for name in ("tick", "waiting", "click", "fire", "script", "ready", "alive", "rejected", "focus", "input", "submit", "locked", "unlock")
    s.hooks[name] = made[name]
  end
  JS.unhandled!(s.js, s.hooks["rejected"])
  # A <canvas> that a script can draw on: see context.jl
  s.hooks["ending"] = Drawing.start!(s.js; node=id -> element(s, id), load=address -> s.load(resolve(home(s), address)), now=() -> time() - s.started, changed=() -> (s.changed = true))
  s
end

Base.close(s::Scripts) = (empty!(s.hooks); close(s.js))
Base.isopen(s::Scripts) = isopen(s.js)

"Add a line to the log of `s`"
note!(s::Scripts, level::Symbol, text::AbstractString) = begin
  length(s.log) >= LINES && popfirst!(s.log)
  push!(s.log, (level, String(text)))
  s.say(level, String(text))
  nothing
end

"""
Do `f`, which runs a script. What the script throws goes in the log, and
`default` is given. A script that used WebGL made its OpenGL context current,
and the one that was current before comes back.
"""
guarded(f, s::Scripts, default=nothing) =
  try
    f()
  catch e
    e isa ScriptError || rethrow()
    note!(s, :error, sprint(showerror, e))
    default
  finally
    giveback!()
  end

# --- nodes and their numbers --------------------------------------------------------------

number(s::Scripts, ::Nothing) = 0
number(s::Scripts, n::Node) = get!(s.numbers, n) do
  s.nodes[s.last += 1] = n
  s.last
end

node(s::Scripts, id) = get(() -> error("the node is gone"), s.nodes, Int(id))
element(s::Scripts, id) = (n = node(s, id); n isa Element ? n : error("the node is not an element"))

iscomment(n::Node) = n isa Element && n.tag == "#comment"
isfragment(n::Node) = n isa Element && n.tag == "#fragment"
kind(n::Node) = n isa Text ? 3 : iscomment(n) ? 8 : isfragment(n) ? 11 : 1

"The address of the page, which the addresses in it are from"
home(s::Scripts) = isempty(s.doc.base) ? s.base : resolve(s.base, s.doc.base)

"True when `n` is in the page, and not in a tree that only a script holds"
connected(s::Scripts, n::Node) = begin
  while n.parent !== nothing
    n = n.parent
  end
  n === s.doc.root
end

"Where `n` is among the children of its parent"
index(n::Node) = findfirst(c -> c === n, n.parent.children)

"Take `n` out of its parent"
detach!(n::Node) = begin
  n.parent === nothing && return n
  deleteat!(n.parent.children, index(n))
  n.parent = nothing
  n
end

"A copy of `n`, and of what's in it when `deep`"
clone(s::Scripts, n::Text, deep) = Text(n.text, nothing)
clone(s::Scripts, e::Element, deep) = begin
  made = Element(e.tag, copy(e.attrs))
  deep && for c in e.children
    k = clone(s, c, true)
    k.parent = made
    push!(made.children, k)
  end
  deep && haskey(s.contents, e) && (s.contents[made] = clone(s, s.contents[e], true))
  made
end

"""
Take what's in each <template> under `n` out of the tree, into a fragment of
its own. As in a browser, it's no part of the page: a script gets it from the
template's `content`, and no search of the page finds it.
"""
apart!(s::Scripts, n::Node) = begin
  n isa Element || return n
  if n.tag == "template" && !isempty(n.children)
    refill!(get!(() -> Element("#fragment"), s.contents, n), copy(n.children))
    empty!(n.children)
    apart!(s, s.contents[n])
  else
    foreach(c -> apart!(s, c), n.children)
  end
  n
end

"-1 when `a` is before `b` in the page, 1 when it's after, and 0 when they aren't in one tree"
order(a::Node, b::Node) = begin
  trail(n) = begin
    steps = Int[]
    while n.parent !== nothing
      pushfirst!(steps, index(n))
      n = n.parent
    end
    (n, steps)
  end
  (ra, ta), (rb, tb) = trail(a), trail(b)
  ra === rb ? cmp(ta, tb) : 0
end

# --- HTML from a tree, and a tree from HTML -----------------------------------------------

escaped(s, quotes) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", (quotes ? ('"' => "&quot;",) : ())...)

"Write the HTML of `n`. What's in a <template> is written from its fragment."
html(io::IO, s::Scripts, n::Text) = print(io, n.parent !== nothing && n.parent.tag in RAW ? n.text : escaped(n.text, false))
html(io::IO, s::Scripts, e::Element) = begin
  iscomment(e) && return print(io, "<!--", attr(e, "data"), "-->")
  isfragment(e) && return inner(io, s, e)
  print(io, '<', e.tag)
  for (name, value) in e.attrs
    print(io, ' ', name, "=\"", escaped(value, true), '"')
  end
  print(io, '>')
  e.tag in VOID && return
  inner(io, s, e)
  print(io, "</", e.tag, '>')
end
inner(io::IO, s::Scripts, e::Element) = foreach(c -> html(io, s, c), get(s.contents, e, e).children)

# What the HTML of a part of a table has to be in, to be read as that part
const AROUND = Dict("table" => ("<table>", 1), "thead" => ("<table><thead>", 2), "tbody" => ("<table><tbody>", 2), "tfoot" => ("<table><tfoot>", 2),
                    "tr" => ("<table><tbody><tr>", 3), "colgroup" => ("<table><colgroup>", 2))

"The nodes that `html` writes, as it would be read in an element with the tag `inside`. They're in no tree."
parsed(s::Scripts, html::AbstractString, inside::AbstractString) = begin
  open, deep = get(AROUND, inside, ("", 0))
  doc = document((s.doc.mode == :quirks ? "" : "<!DOCTYPE html>") * "<body>" * open * html)
  from = doc.body
  for _ in 1:deep
    i = findfirst(c -> c isa Element, from.children)
    i === nothing && break
    from = from.children[i]
  end
  nodes = copy(from.children)
  empty!(from.children)
  foreach(n -> n.parent = nothing, nodes)
  foreach(n -> apart!(s, n), nodes)
  nodes
end

"Put the nodes `new` in `e`, in place of what's in it"
refill!(e::Element, new) = begin
  foreach(c -> c.parent = nothing, e.children)
  empty!(e.children)
  for n in new
    n.parent = e
    push!(e.children, n)
  end
  e
end

# --- selectors ----------------------------------------------------------------------------

"The selectors that `text` writes. A selector that can't be read is an error, which the script can catch."
selected(s::Scripts, text::AbstractString) = get!(s.selectors, text) do
  found = selectors(text)
  found === nothing && error("'$text' is not a valid selector")
  # A part of an element, like ::before, is no element
  filter(x -> x.pseudo == :none, found)
end

fits(sels, e::Element) = any(x -> matches(x, e), sels)

"The numbers of the elements under `top` that `ok` is true of, in the page's order: all of them, or only the first"
under(ok, s::Scripts, top::Element, all::Bool; self=false) = begin
  found = Int[]
  visit(e) = begin
    for c in e.children
      c isa Element || continue
      ok(c) && push!(found, number(s, c))
      (!all && !isempty(found)) && return
      visit(c)
      (!all && !isempty(found)) && return
    end
  end
  self && ok(top) && push!(found, number(s, top))
  (all || isempty(found)) && visit(top)
  found
end

"The element that the number `id` means for a search: the whole page when it's 0"
top(s::Scripts, id) = id == 0 ? (s.doc.root, true) : (element(s, id), false)

# --- what a script can ask ----------------------------------------------------------------

"The Julia functions that window.jl calls, by name. Each takes and gives numbers, strings and lists of them."
natives(s::Scripts) = begin
  touched() = (s.changed = true; nothing)
  Dict{String,Any}(
    "root" => () -> number(s, s.doc.root),
    "quirks" => () -> s.doc.mode == :quirks,
    "kind" => id -> kind(node(s, id)),
    "tag" => id -> element(s, id).tag,
    "parent" => id -> number(s, node(s, id).parent),
    "children" => id -> (n = node(s, id); n isa Element ? Int[number(s, c) for c in n.children] : Int[]),
    "child" => (id, i) -> begin
      n = node(s, id)
      (n isa Element && !isempty(n.children)) ? number(s, i < 0 ? n.children[end] : n.children[1]) : 0
    end,
    "sibling" => (id, step) -> begin
      n = node(s, id)
      n.parent === nothing && return 0
      i = index(n) + Int(step)
      checkbounds(Bool, n.parent.children, i) ? number(s, n.parent.children[i]) : 0
    end,
    "connected" => id -> connected(s, node(s, id)),
    "order" => (a, b) -> order(node(s, a), node(s, b)),

    "text" => id -> (n = node(s, id); iscomment(n) ? attr(n, "data") : text(n)),
    "setText" => (id, value) -> begin
      e = element(s, id)
      refill!(e, isempty(value) ? Node[] : Node[Text(value, nothing)])
      touched()
    end,
    "data" => id -> (n = node(s, id); n isa Text ? n.text : attr(n, "data")),
    "setData" => (id, value) -> begin
      n = node(s, id)
      n isa Text ? (n.text = value) : (n.attrs["data"] = value)
      touched()
    end,

    "attr" => (id, name) -> get(element(s, id).attrs, name, nothing),
    "setAttr" => (id, name, value) -> (element(s, id).attrs[name] = value; touched()),
    "removeAttr" => (id, name) -> (delete!(element(s, id).attrs, name); touched()),
    "attrs" => id -> (out = String[]; foreach(((k, v),) -> push!(out, k, v), element(s, id).attrs); out),

    "create" => tag -> number(s, Element(String(tag))),
    "createText" => value -> number(s, Text(String(value), nothing)),
    "createComment" => value -> number(s, Element("#comment", Dict("data" => String(value)))),
    "createFragment" => () -> number(s, Element("#fragment")),
    "clone" => (id, deep) -> number(s, clone(s, node(s, id), deep)),
    "content" => id -> number(s, get!(() -> Element("#fragment"), s.contents, element(s, id))),
    "insert" => (parent, child, before) -> begin
      p, c = element(s, parent), node(s, child)
      detach!(c)
      i = before == 0 ? length(p.children) + 1 : something(findfirst(k -> k === node(s, before), p.children), length(p.children) + 1)
      c.parent = p
      insert!(p.children, i, c)
      touched()
    end,
    "remove" => id -> (detach!(node(s, id)); touched()),

    "html" => id -> sprint(inner, s, element(s, id)),
    "outer" => id -> sprint(html, s, element(s, id)),
    "setHTML" => (id, value) -> begin
      e = element(s, id)
      refill!(e, parsed(s, value, e.tag))
      touched()
    end,
    "parse" => (inside, value) -> begin
      fragment = Element("#fragment")
      refill!(fragment, parsed(s, value, inside == 0 ? "body" : element(s, inside).tag))
      number(s, fragment)
    end,

    "query" => (id, selector, all) -> begin
      sels = selected(s, selector)
      from, self = top(s, id)
      under(e -> fits(sels, e), s, from, all; self)
    end,
    "matches" => (id, selector) -> fits(selected(s, selector), element(s, id)),
    "closest" => (id, selector) -> begin
      sels = selected(s, selector)
      e = element(s, id)
      while e !== nothing && !isfragment(e)
        fits(sels, e) && return number(s, e)
        e = e.parent
      end
      0
    end,
    "tagged" => (id, tag) -> begin
      from, self = top(s, id)
      under(e -> e.tag == tag, s, from, true; self)
    end,
    "byId" => id -> (found = under(e -> get(e.attrs, "id", nothing) == id, s, s.doc.root, false; self=true); isempty(found) ? 0 : found[1]),

    "rects" => id -> begin
      e = node(s, id)
      out = Float64[]
      e isa Element && connected(s, e) && foreach(r -> append!(out, r), s.place(e))
      out
    end,
    "hit" => (x, y) -> number(s, s.at(Float64(x), Float64(y))),
    "window" => () -> collect(s.window()),
    "computed" => (id, name) -> (e = element(s, id); connected(s, e) ? s.computed(e, String(name)) : nothing),
    "media" => query -> (w = s.window(); media(query, w[1], w[2])),
    "scroll" => () -> Float64(s.scroll()),
    "scrollTo" => y -> (s.scroll(Float64(y)); nothing),
    "go" => address -> (go!(s, resolve(home(s), address)); nothing),
    "send" => (form, by) -> (send!(s, element(s, form), by == 0 ? nothing : element(s, by)); nothing),
    "focused" => id -> (s.focused(id == 0 ? nothing : element(s, id)); nothing),

    "log" => (level, line) -> note!(s, Symbol(level), line),
    # A file that's on its way is false, and one that can't be had, or that a script of this page may not read, is nothing
    "load" => address -> begin
      found = loaded(s, address)
      found === :waiting ? false : found === nothing || s.allowed(resolve(home(s), address)) ? found : nothing
    end,
    "resolve" => address -> isempty(address) ? home(s) : resolve(home(s), address),
    "join" => (base, address) -> resolve(base, address),
    "now" => () -> 1000 * (time() - s.started),
    "run" => id -> (run!(s, element(s, id)); nothing),
    "random" => n -> Int.(rand(RandomDevice(), UInt8, Int(n))),
  )
end

"The text of the file at `address`, which is from the page's address, or nothing. It's `:waiting` for a file that's on its way."
loaded(s::Scripts, address::AbstractString) = begin
  found = s.load(resolve(home(s), address))
  found === nothing || found === :waiting ? found : found isa AbstractString ? String(found) : String(copy(found))
end

"Go to the page at `address`, as a link does. With nowhere to go, the page stays and the log says so."
go!(s::Scripts, address::AbstractString) =
  s.go === nothing ? note!(s, :warn, "The page asked to go to $address, which does nothing here") : (s.go(String(address)); nothing)

"""
Send the form `form`, as the button `by` does, or the Return key with nothing.
A form that sends with "get" is an address, and the page goes there. Nothing
can be sent any other way, so a form that sends with "post" goes nowhere.
"""
send!(s::Scripts, form::Element, by=nothing) = begin
  method, address = sent(form, by; base=home(s))
  method == "get" ? go!(s, address) : note!(s, :warn, "The page asked to send a form to $address, which this engine can't do")
end

# --- running the page's scripts -----------------------------------------------------------

# What a <script> says its type is, when it's JavaScript that runs here
const SCRIPT = ("", "text/javascript", "application/javascript", "text/ecmascript", "application/ecmascript", "application/x-javascript", "text/jscript",
                "text/javascript1.5", "text/livescript")

"Run the script of the <script> element `e`, once"
run!(s::Scripts, e::Element) = begin
  haskey(s.ran, e) && return
  s.ran[e] = true
  type = lowercase(strip(attr(e, "type")))
  type == "module" && return run_module!(s, e)
  type == "importmap" && return (mapped!(s, text(e)); nothing)
  type in SCRIPT || return   # data that the page keeps in a <script>, like JSON or a template
  haskey(e.attrs, "nomodule") && return   # it's for a browser that runs no modules
  src = strip(attr(e, "src"))
  code = isempty(src) ? text(e) : loaded(s, src)
  if code === :waiting
    # Its file is on its way. `step!` runs it when the file has come.
    delete!(s.ran, e)
    any(p -> p === e, s.pending) || push!(s.pending, e)
    return
  end
  id = number(s, e)
  if code === nothing
    note!(s, :error, "The script $src could not be loaded")
    guarded(() -> s.hooks["fire"](id, "error"), s)
    return
  end
  guarded(() -> s.hooks["script"](id), s)
  guarded(() -> JS.evaluate(s.js, code; name=isempty(src) ? "" : resolve(home(s), src)), s)
  guarded(() -> s.hooks["script"](0), s)
  isempty(src) || guarded(() -> s.hooks["fire"](id, "load"), s)
  nothing
end

"Run each <script> of the page, in the page's order, then tell the scripts that the page is read"
start!(s::Scripts) = begin
  found = Element[]
  visit(e) = for c in e.children
    c isa Element || continue
    c.tag == "script" ? push!(found, c) : visit(c)
  end
  visit(s.doc.root)
  # A script that an earlier script took out of the page doesn't run. Modules run after the rest.
  foreach(e -> connected(s, e) && !ismodule(e) && run!(s, e), found)
  foreach(e -> connected(s, e) && ismodule(e) && run!(s, e), found)
  # The page is ready once its modules have run
  any(ismodule, s.pending) ? (s.unready = true) : guarded(() -> s.hooks["ready"](), s)
  s
end

"""
Run the timers of the page that are due, and the scripts that wait for the
next frame. Gives how many seconds until the next timer is due, 0 when a
script waits for the next frame, or nothing when nothing waits.
"""
step!(s::Scripts) = begin
  # The scripts whose file was on its way run once it has come, in the order that the page asked for them
  if !isempty(s.pending)
    waited = copy(s.pending)
    empty!(s.pending)
    foreach(e -> connected(s, e) && run!(s, e), waited)
  end
  if s.unready && !any(ismodule, s.pending)
    s.unready = false
    guarded(() -> s.hooks["ready"](), s)
  end
  wait = guarded(() -> s.hooks["tick"](1000 * (time() - s.started)), s, -1.0)
  length(s.nodes) > 2 * s.kept + 2000 && sweep!(s)
  isempty(s.pending) || (wait = wait < 0 ? PATIENCE : min(wait, PATIENCE))
  wait < 0 ? nothing : wait / 1000
end

"How many seconds until the next timer of the page is due, 0 when a script waits for the next frame, or nothing when nothing waits"
waiting(s::Scripts) = begin
  wait = guarded(() -> s.hooks["waiting"](), s, -1.0)
  isempty(s.pending) || (wait = wait < 0 ? PATIENCE : min(wait, PATIENCE))
  wait < 0 ? nothing : wait / 1000
end

"""
Tell the page's scripts of a click on `e`, at the point `(x, y)` of the page.
False when a script said that the click should do no more, as for a link that
the script follows itself.
"""
click!(s::Scripts, e::Union{Element,Nothing}, x=0.0, y=0.0) = guarded(() -> s.hooks["click"](number(s, e), x, y), s, true)::Bool

"""
Give the keyboard to the element `e`, or take it from the element that has
it, with nothing. The page's scripts hear `focus` and `blur`.
"""
focus!(s::Scripts, e::Union{Element,Nothing}) = guarded(() -> s.hooks["focus"](number(s, e)), s)

"Put the text `value` in the field `e`, as typing does. The page's scripts hear `input`."
input!(s::Scripts, e::Element, value::AbstractString) = guarded(() -> s.hooks["input"](number(s, e), String(value)), s)

"""
Send the form `form`, as the button `by` does, or the Return key with nothing.
The page's scripts hear `submit` first, and the form goes nowhere when one of
them says to do no more.
"""
submit!(s::Scripts, form::Element, by::Union{Element,Nothing}=nothing) = guarded(() -> s.hooks["submit"](number(s, form), number(s, by)), s)

"Tell the page's scripts of an event of the kind `type` on `e`, or on the window with nothing. `init` is what the event says, like `Dict(\"key\" => \"a\")`."
fire!(s::Scripts, e::Union{Element,Nothing}, type::AbstractString, init=Dict{String,Any}("bubbles" => true, "cancelable" => true)) =
  guarded(() -> s.hooks["fire"](number(s, e), type, init), s, true)::Bool

"""
True while a script of the page has the mouse to itself, since it asked with
`requestPointerLock`. Each event of the mouse goes to the element that asked
then, and the page hears of no element that the mouse is over.
"""
locked(s::Scripts) = guarded(() -> s.hooks["locked"](), s, 0) != 0

"Take the mouse back from the script that has it to itself, as Esc does. The page hears `pointerlockchange`."
unlock!(s::Scripts) = (guarded(() -> s.hooks["unlock"](), s); nothing)

"Run `code` in the page, and give the value of its last statement. What the script throws is thrown here, as a `ScriptError`."
evaluate(s::Scripts, code::AbstractString; kw...) = JS.evaluate(s.js, code; kw...)

# --- modules ------------------------------------------------------------------------------

ismodule(e::Element) = lowercase(strip(attr(e, "type"))) == "module"

"Add what the import map `json` says to the page's map. A map that can't be read is left out, and the log says so."
mapped!(s::Scripts, json::AbstractString) = begin
  m = s.modules
  got = guarded(s) do
    JS.evaluate(s.js, "(m => [Object.entries(m.imports || {}), Object.entries(m.scopes || {}).map(([k, v]) => [k, Object.entries(v)])])(\n" * json * "\n)"; name="importmap")
  end
  got isa AbstractVector || return
  whole(k) = occursin(r"^(\.{0,2}/|[a-zA-Z][a-zA-Z0-9+.-]*:)", k) ? resolve(home(s), k) : String(k)
  entries(list) = [whole(String(k)) => resolve(home(s), String(v)) for (k, v) in list if v isa AbstractString]
  append!(m.imports, entries(got[1]))
  append!(m.scopes, [resolve(home(s), String(k)) => entries(v) for (k, v) in got[2]])
  # The longest start of an address is tried first
  sort!(m.scopes, by=p -> -length(p.first))
end

"What `map` says that `name` is: its address, the address that the longest start of it is at with the rest added, or nothing"
mapped(map::Vector{Pair{String,String}}, name::AbstractString) = begin
  best = nothing
  for (k, v) in map
    k == name && return v
    endswith(k, '/') && startswith(name, k) && (best === nothing || length(k) > length(best[1])) && (best = (k, v))
  end
  best === nothing ? nothing : best[2] * name[ncodeunits(best[1])+1:end]
end

"""
The address of the module that a module at the address `from` names `name`:
with the import map, or from `from` for a name like `./a.js`. Nothing for a
name that the import map doesn't know, like `three` with no map.
"""
module_address(s::Scripts, name::AbstractString, from::AbstractString) = begin
  name = String(strip(name))
  url = occursin(r"^\.{0,2}/", name) ? resolve(from, name) : occursin(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", name) ? name : nothing
  key = something(url, name)
  for (scope, map) in s.modules.scopes
    startswith(from, scope) || continue
    found = mapped(map, key)
    found === nothing || return found
  end
  found = mapped(s.modules.imports, key)
  found === nothing ? url : found
end

"""
Get the module at `address` and each module that it imports, and give the
page the function of each. `code` is the module's code, for one that's
written in the page, and `from` the address that it imports from. Gives true
once all are there, :waiting while a file is on its way, or the words of the
error that stopped one.
"""
gather!(s::Scripts, address::AbstractString; code=nothing, from=address) = begin
  m = s.modules
  queue, seen, waiting = String[address], Set{String}(), false
  while !isempty(queue)
    a = popfirst!(queue)
    (a in seen || a in m.defined) && continue
    push!(seen, a)
    if !haskey(m.made, a)
      text = a == address && code !== nothing ? code : loaded(s, a)
      text === :waiting && (waiting = true; continue)
      text === nothing && return (m.made[a] = "The module $a could not be loaded")
      here = a == address ? from : a
      c = script_of(text)
      imports = String[]
      for name in c.imports
        found = module_address(s, name, here)
        found === nothing && return (m.made[a] = "The module $a imports \"$name\", which the page's import map doesn't name")
        push!(imports, found)
      end
      m.made[a] = (c, imports, here)
    end
    made = m.made[a]
    made isa AbstractString && return made
    append!(queue, made[2])
  end
  waiting && return :waiting
  # The page gets the function of each module that's new. One with an `await` outside a function is an async function.
  for a in seen
    a in m.defined && continue
    c, imports, here = m.made[a]
    try
      JS.evaluate(s.js, wrapped(c, a, here, imports); name=here)
    catch e
      e isa ScriptError || rethrow()
      try
        JS.evaluate(s.js, wrapped(c, a, here, imports; async=true); name=here)
      catch
        return (m.made[a] = sprint(showerror, e))
      end
    end
    push!(m.defined, a)
  end
  true
end

"Run the module of the <script type=\"module\"> element `e`, once it and the modules that it imports are there"
run_module!(s::Scripts, e::Element) = begin
  src = strip(attr(e, "src"))
  address = if isempty(src)
    # A module that's written in the page is named by its place among them, and imports from the page's address
    get!(() -> home(s) * "#module" * string(length(s.modules.named) + 1), s.modules.named, e)
  else
    resolve(home(s), src)
  end
  got = isempty(src) ? gather!(s, address; code=text(e), from=home(s)) : gather!(s, address)
  # Modules run in the page's order, so one waits for those before it. Its files are asked for meanwhile.
  if got === :waiting || any(p -> p !== e && ismodule(p) && !haskey(s.ran, p), s.pending)
    delete!(s.ran, e)
    any(p -> p === e, s.pending) || push!(s.pending, e)
    return
  end
  id = number(s, e)
  if got !== true
    note!(s, :error, got)
    guarded(() -> s.hooks["fire"](id, "error"), s)
    return
  end
  longer = s.modules.limit !== nothing && s.modules.limit < MODULE_LIMIT
  longer && JS.limit!(s.js, MODULE_LIMIT)
  try
    guarded(() -> JS.evaluate(s.js, "globalThis[Symbol.for('ladder.modules')].run(" * repr(address) * ")"; name=address), s)
  finally
    longer && JS.limit!(s.js, s.modules.limit)
  end
  isempty(src) || guarded(() -> s.hooks["fire"](id, "load"), s)
  nothing
end

"Forget the number of each node that no script holds any more, so that Julia can free the nodes that left the page"
sweep!(s::Scripts) = begin
  JS.collect!(s.js)
  alive = guarded(() -> s.hooks["alive"](), s)
  alive === nothing && return
  keep = Set{Int}(Int(id) for id in alive)
  for (id, n) in s.nodes
    id in keep && continue
    delete!(s.nodes, id)
    delete!(s.numbers, n)
  end
  s.kept = length(s.nodes)
  nothing
end

export Scripts, ScriptError, start!, step!, waiting, click!, fire!, focus!, input!, submit!, locked, unlock!, sweep!, evaluate
