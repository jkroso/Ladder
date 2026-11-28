# What Julia code ran, down a level: its inferred code, its LLVM code and its assembly
#
# Julia code has four levels, and they're levels of what the code comes to
# when it runs. At the highest, the box after a piece of code shows the value
# that the code came to. "code that runs where it is" says how. A level
# down, the box shows the code as Julia infers it: each step, with the type
# that Julia worked out for it. Under that it shows the LLVM code that Julia
# makes of those steps, and under that the assembly that LLVM compiles them
# to, with the machine code of each instruction beside it.
#
# The levels belong to a block of code, not to the window. Each `julia` code
# block of a page has a level of its own, and a file of Julia code, which is
# one block, has one. While the caret is in a block, the slider in the top bar
# is that block's: the top bar asks the part of the page that the caret is in
# for its levels, and the block answers. See "the slider of the levels". The
# slider goes to each level, and ⌘E goes between the value and the inferred
# code. With the caret in the page's text, the slider is the page's again.
#
# The code shows as it's written at every level, and you type in it as
# always. The boxes of the block change with its level, so you can take one
# piece of code from its value down to its machine code. Code that runs while
# its block is down a level has its box open.
#
# What a box shows is the code of what ran. For the definition of a function,
# that's the function's code for the types that it has been called with since,
# or for the types that it's written for when it hasn't been called. When the
# function has more than one method or set of types, a line at the top of the
# open box says so, and a click on it shows the next. For any other code, it's
# that code itself, compiled as a function that takes nothing. Code that can't
# be in a function has no lower level, like `using` or the definition of a
# struct. Neither has code that failed. Their boxes show what they show at the
# highest level.
#
# A closed box shows a little: the type that the code gives at the level of
# inferred code, and how many bytes of machine code there are at the level of
# assembly. Only the lines of an open box that are in sight are made.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe reuse! handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor MouseScroll
@use "../markdown" Kind Line words
@use "./highlight" tokens
@use "../blocks/sheet" parts
@use InteractiveUtils: code_native, code_llvm
@use "../base" exports...
@use "../blocks/changes_view" exports...

export CODE_LEVELS, MOST_LOWERED, MOST_FORMS, julia_place, julia_part, code_depth, calls, is_definition,
       Defined, Thunk, Lowered, bare_code, source_of, thunk!, forms, call_words, tinted, inferred, LLVM_WORDS,
       llvm_row, llvm, assembly, code_view, FormPick, lowered_view, NUMBER_GAP, numbered, number_face,
       numbers, gutter, draw_numbers, INDENTS, GUIDES, CODE_SCALES, SIDE_ROOM, wraps, sideways, sideways_room,
       scroll_sideways!, swipe!, wrap!, numbers!, shade!, indent_width!, guide!, code_font!, code_weight!,
       code_size!, indentation

const CODE_LEVELS = ("the assembly of what you run", "the LLVM code of what you run", "the inferred code of what you run", "the value of what you run")
const MOST_LOWERED = 4000    # lines. The inferred code, the LLVM code or the assembly of longer code stops there.
const MOST_FORMS = 12        # the most methods and sets of types that a function offers

"True when the page shows a file of Julia code that you change. The whole file is one block of Julia code."
julia_file(b::Buffer) = b.view == :code && lowercase(splitext(b.path)[2]) == ".jl"

"The place of the `julia` code block that opens on line `s` among the `julia` code blocks of `b`"
julia_place(b::Buffer, s::Int) = (ks = kinds(b); count(i -> ks[i].kind == Kind.fence && ks[i].level == 0 && lowercase(ks[i].lang) in JULIA, 1:s))

"""
The Julia code that line `i` is in, as the part of the page that has levels: a
`julia` code block of a page, or the whole of a file of Julia code. It's
nothing when the line isn't in Julia code. With `make` false, it's also
nothing for code that was never asked for, which is at its highest level.
"""
julia_part(e, i::Int; make=true) = begin
  b = e.buf
  n = 0   # a file of Julia code is one block
  if !julia_file(b)
    (b.view == :markdown && 1 <= i <= length(b.lines)) || return nothing
    found = julia_code(b, i)
    found === nothing && return nothing
    n = julia_place(b, found[1] - 1)
  end
  key = (:julia, b.path, n)
  make || return get(e.nodes, key, nothing)
  get!(e.nodes, key) do
    c = JuliaCode(n=n)
    # It's a part of the document, so the document answers what it doesn't
    setfield!(c, :parent, node!(Document, e, :document))
    c
  end
end

"How many levels down the Julia code that line `i` is in shows what it comes to: 0 for the value, 1 for inferred code, 2 for LLVM code and 3 for assembly"
code_depth(e, i::Int) = (c = julia_part(e, i, make=false); c === nothing ? 0 : c.depth)

levels(::JuliaCode) = CODE_LEVELS
level(c::JuliaCode) = length(CODE_LEVELS) - c.depth
level!(c::JuliaCode, i::Int) = (c.depth = clamp(length(CODE_LEVELS) - i, 0, length(CODE_LEVELS) - 1); c)

"True when the code `lhs` is what a function's definition starts with, like `f(x)` or `f(x::T) where T`"
calls(lhs) = Meta.isexpr(lhs, :call) || (Meta.isexpr(lhs, (:where, :(::))) && !isempty(lhs.args) && calls(lhs.args[1]))

"True when the expression `ex` defines a function. Its documentation can be above it, and a macro like `@inline` can be before it."
is_definition(ex) = Meta.isexpr(ex, :function, 2) || (Meta.isexpr(ex, :(=), 2) && calls(ex.args[1])) ||
                    (Meta.isexpr(ex, :macrocall) && length(ex.args) > 2 && is_definition(last(ex.args)))

"The definition of a function that ran: the function, and the types that each method it got then is written for"
struct Defined
  value::Any
  sigs::Vector{Any}
end

"Code that ran and defined no function. The levels under its value show it compiled as a function that takes nothing."
mutable struct Thunk
  code::String
  made::Any   # that function, false when the code can't be in a function, or nothing until a lower level asks for it
end

"A line of code that a box shows a level down: its pieces, each with the name of its colour"
const CodeRow = Vector{Tuple{String,Symbol}}

"What a box shows while its code is down a level: its top line, the lines under it, how wide the widest is, and how many methods and sets of types its function offers"
struct Lowered
  key::Any
  title::String
  rows::Vector{CodeRow}
  cols::Int
  forms::Int
end

"The code without the comments and the empty lines above it"
bare_code(code::AbstractString) = begin
  lines = split(code, '\n')
  k = something(findfirst(l -> !isempty(strip(l)) && !startswith(lstrip(l), '#'), lines), 1)
  String(rstrip(join(lines[k:end], "\n")))
end

"""
What the levels under the value show the code of, for `code` that ran and
came to `value`. A definition gives its function, with the methods that the
function got after `world`. Other code gives itself.
"""
source_of(code::AbstractString, value, world) = begin
  ex = try Meta.parse(bare_code(code), raise=false) catch; nothing end
  (is_definition(ex) && value isa Union{Function,Type}) || return Thunk(String(code), nothing)
  Defined(value, Any[x.sig for x in Base.invokelatest(methods, value) if x.primary_world > world])
end

"The function that the code of `t` makes when it's the body of a function that takes nothing, in the module `m`, or false when it can't be one"
thunk!(t::Thunk, m::Module) = begin
  t.made === nothing || return t.made
  t.made = try
    Core.eval(m, Expr(:->, Expr(:tuple), Expr(:block, Meta.parseall(t.code).args...)))
  catch
    false
  end
end

"""
The types that the function of `d` shows its code for: for each of its
methods, each set of types that it has been called with, or the types that it's
written for when it hasn't been called. The method with the most arguments is first.
"""
forms(d::Defined) = begin
  out = Any[]
  now = try collect(Base.invokelatest(methods, d.value)) catch; return out end
  for sig in sort(d.sigs, by=sig -> -length(Base.unwrap_unionall(sig).parameters))
    k = findfirst(x -> x.sig == sig, now)
    called = k === nothing ? Any[] : Any[mi.specTypes for mi in Base.specializations(now[k]) if Base.isdispatchtuple(mi.specTypes)]
    isempty(called) ? push!(out, sig) : append!(out, called)
  end
  length(out) > MOST_FORMS ? out[1:MOST_FORMS] : out
end
forms(t::Thunk, m::Module) = (f = thunk!(t, m); f === false ? Any[] : Any[Tuple{typeof(f)}])
forms(d::Defined, ::Module) = forms(d)

"A type as Julia writes it, with no module's name in front of a type of the module `m`"
type_name(m::Module, T) = replace(sprint(show, T, context=:module => m), string(m) * "." => "")

"The call that the types `tt` are of, like `area(w::Int64, h::Int64)`, with the names that the method of `d` gives its arguments. Code that defined no function has none."
call_words(::Thunk, m::Module, tt) = ""
call_words(d::Defined, m::Module, tt) = begin
  types = Base.unwrap_unionall(tt).parameters[2:end]
  now = try collect(Base.invokelatest(methods, d.value)) catch; Method[] end
  k = findfirst(x -> tt <: x.sig, now)
  names = k === nothing ? String[] : String[string(n) for n in Base.method_argnames(now[k])[2:end]]
  args = [(length(names) == length(types) ? names[i] : "") * "::" * type_name(m, T) for (i, T) in enumerate(types)]
  string(d.value isa Function ? nameof(d.value) : type_name(m, d.value)) * "(" * join(args, ", ") * ")"
end

"`text` as the pieces of a line of Julia code, each with the name of its colour. Pieces of one colour that touch are one piece."
tinted(text::AbstractString) = begin
  out = Tuple{String,Symbol}[]
  for t in tokens(text, "julia")
    # Julia writes the place that a step jumps to as #4, which isn't a comment
    kind = t.kind in (:plain, :comment) ? :ink : t.kind
    !isempty(out) && last(out)[2] == kind ? (out[end] = (last(out)[1] * t.text, kind)) : push!(out, (String(t.text), kind))
  end
  out
end

"""
The code of the types `tt` as Julia infers it, with the type that it gives. The
local variables come first, each with its type, then each step.
"""
inferred(m::Module, tt) = begin
  found = Base.code_typed_by_type(tt; optimize=false, debuginfo=:none)
  isempty(found) && error("Julia has no method for these types.")
  ci, gives = first(found)
  inside = string(m) * "."
  body = split(replace(sprint(show, ci, context=:module => m), inside => ""), '\n')
  # Julia writes the steps between a line that says CodeInfo( and a line with a )
  length(body) > 2 && startswith(first(body), "CodeInfo(") && (body = body[2:end-1])
  n = length(Base.unwrap_unionall(tt).parameters)
  locals = ci.slottypes isa Vector ?
    ["  " * string(name) * "::" * type_name(m, T) for (name, T) in zip(ci.slotnames[n+1:end], ci.slottypes[n+1:end])
     if !startswith(string(name), '#') && !isempty(string(name))] : String[]
  rows = CodeRow[tinted(l) for l in body]
  # The two headings are words of Ladder's, so they're dim
  isempty(locals) || (rows = [[[("Locals", :dim)]]; [tinted(l) for l in locals]; [[("Body", :dim)]]; rows])
  (rows, gives)
end

"The function that the types `tt` call, and the types of its arguments, as `code_llvm` and `code_native` take them"
callee(tt) = begin
  inner = Base.unwrap_unionall(tt)
  F = inner.parameters[1]
  f = isdefined(F, :instance) ? F.instance : F isa DataType && F.name === Type.body.name ? F.parameters[1] :
      error("Ladder can't compile a thing that's called like a function. It has no name to compile.")
  (f, Base.rewrap_unionall(Tuple{inner.parameters[2:end]...}, tt))
end

const LLVM_WORDS = r"%[\w.\"#-]+|@\"[^\"]*\"|@[\w.]+|\b(?:define|declare|ret|br|call|load|store|alloca|getelementptr|icmp|fcmp|phi|select|switch|unreachable|invoke|bitcast|trunc|zext|sext|add|sub|mul|sdiv|udiv|srem|urem|fadd|fsub|fmul|fdiv|and|or|xor|shl|lshr|ashr)\b|(?<![\w.])-?\d+(?:\.\d+)?(?![\w.])"

"A line of LLVM code as pieces, each with the name of its colour: the names of values, the names of functions, the instructions and the numbers"
llvm_row(line::AbstractString) = begin
  startswith(lstrip(line), ';') && return [(String(line), :comment)]
  out = Tuple{String,Symbol}[]
  at = 1
  for found in eachmatch(LLVM_WORDS, line)
    found.offset > at && push!(out, (String(line[at:prevind(line, found.offset)]), :ink))
    word = found.match
    push!(out, (String(word), startswith(word, '%') ? :call : startswith(word, '@') ? :type : isletter(first(word)) ? :keyword : :number))
    at = found.offset + ncodeunits(word)
  end
  at <= ncodeunits(line) && push!(out, (String(line[at:end]), :ink))
  out
end

"The LLVM code that Julia makes for the types `tt`"
llvm(tt) = begin
  f, types = callee(tt)
  text = sprint(io -> Base.invokelatest(code_llvm, io, f, types; debuginfo=:none, dump_module=false, raw=false))
  CodeRow[llvm_row(l) for l in split(rstrip(text), '\n')]
end

"""
The assembly that Julia compiles the types `tt` to, and how many bytes of
machine code it is. Each instruction has its place in that machine code, then
its machine code in hexadecimal, then the instruction as assembly.
"""
assembly(tt) = begin
  f, types = callee(tt)
  text = sprint(io -> Base.invokelatest(code_native, io, f, types; debuginfo=:none, dump_module=false, binary=true))
  rows = CodeRow[]
  code = nothing   # the place and the machine code of the instruction on the next line
  bytes = 0
  wide = maximum(l -> (found = match(r"^; [0-9a-f]+: ([0-9a-f ]+)$", l); found === nothing ? 0 : length(found[1])), split(text, '\n'), init=8)
  for line in split(text, '\n')
    found = match(r"^; ([0-9a-f]+): ([0-9a-f ]+)$", line)
    if found !== nothing
      code = (String(found[1]), String(found[2]))
    elseif startswith(line, "; code origin")
      size = match(r"code size: (\d+)", line)
      size === nothing || (bytes = parse(Int, size[1]))
    elseif startswith(line, ';')
      push!(rows, [(String(strip(line[2:end])), :comment)])
    elseif startswith(line, '\t')
      parts = split(strip(line), '\t', limit=2)
      place, hex = something(code, ("", ""))
      push!(rows, [(rpad(place, 6), :faint), (rpad(hex, wide + 2), :dim), (rpad(parts[1], 8), :keyword),
                   (length(parts) > 1 ? replace(String(parts[2]), '\t' => ' ') : "", :ink)])
      code = nothing
    elseif !isempty(strip(line))
      push!(rows, [(String(line), :dim)])   # the name of a place that an instruction jumps to
    end
  end
  (rows, bytes)
end

"""
What the box of `o` shows while the Julia code that it's in is down a level:
the code of what ran, at the level of that block or file. It's nothing at the
level of the value, and for code that has no lower level. The lines of a level
are worked out once for each set of types.
"""
code_view(e, o) = begin
  (o.failed || o.source === nothing) && return nothing
  depth = code_depth(e, o.first)
  depth > 0 || return nothing
  m = workspace(e)
  found = forms(o.source, m)
  isempty(found) && return nothing
  o.form = clamp(o.form, 1, length(found))
  tt = found[o.form]
  key = (depth, tt)
  title, rows = get!(o.views, key) do
    name = call_words(o.source, m, tt)
    try
      if depth == 1
        rows, gives = inferred(m, tt)
        (name * "::" * type_name(m, gives), rows)
      elseif depth == 2
        (isempty(name) ? "LLVM code" : name, llvm(tt))
      else
        rows, bytes = assembly(tt)
        ((isempty(name) ? "" : name * "  ") * "$(commas(bytes)) bytes", rows)
      end
    catch err
      what = ("infer", "make LLVM code of", "compile")[depth]
      (isempty(name) ? "No code" : name, CodeRow[[("Julia couldn't $what this: " * Base.invokelatest(sprint, showerror, err), :dim)]])
    end
  end
  more = length(rows) - MOST_LOWERED
  more > 0 && (rows = [rows[1:MOST_LOWERED]; [[("… and $(commas(more)) more lines", :dim)]]])
  Lowered(key, title, rows, maximum(row -> sum(piece -> length(piece[1]), row, init=0), rows, init=0), length(found))
end

"The line at the top of the open box of a function that has more than one method or set of types. A click on it shows the next."
@def mutable struct FormPick <: SemanticUI
  of::Any = nothing   # the OutcomeBody
end

describe(p::FormPick) = begin
  o = p.of.of
  low = o.low
  words = low === nothing ? "" : "$(o.form) of $(low.forms)  ·  click for the next types"
  Row(width(grow=grow), height(o.size * 1.7), Alignment.Center, radius(4px), background(ishovered(p) ? colours.hover : clear), name="Form pick",
    Box(label(words, o.size * 0.92, color=colours.dim)), Box(width(grow=grow)))
end

cursor(::FormPick) = :hand
onmouse(::FormPick, ::MouseMove) = handled
onkey(p::FormPick, ::KeyPress{Keys.mouse_left}) = (o = p.of.of; o.low === nothing || (o.form = mod1(o.form + 1, o.low.forms)); handled)

"""
The lines of code that the open box `d` shows while its code is down a level.
A list that's taller than the room under the box shows that much of itself,
and the wheel moves through the rest. Only the lines in sight are made.
"""
lowered_view(d) = begin
  o = d.of
  low = o.low::Lowered
  face = outcome_face(o.size)
  h = o.size * 1.45
  n = length(low.rows)
  # Other lines start at their top
  d.showed == low.key || (d.showed = low.key; d.scroll.offset = 0px)
  pick = low.forms > 1 ? (d.pick === nothing ? (d.pick = own!(d, FormPick(of=d))) : d.pick,) : ()
  tall = min(h * n, d.tall)
  lo = clamp(floor(Int, d.scroll.offset / h) - 2, 0, n)
  hi = min(n, lo + ceil(Int, tall / h) + 4)
  row(i) = Row(height(h), Alignment.Center,
    [Box(Text(text, size=o.size, family=face.family, subfamily=face.style, color=getfield(colours, kind), wrap=WrapMode.none)) for (text, kind) in low.rows[i]]...)
  inside = Column(width(grow=grow), Alignment.Start, spacer(h * lo), [row(i) for i in lo+1:hi]..., spacer(h * (n - hi)))
  Column(width(grow=grow), Alignment.Start, pick..., Box(width(grow=grow), height(tall), Alignment.Start, clip=true, reuse!(d.scroll, inside)))
end

# A whole file of code or of text starts at the left of the page, not in the
# middle of it as a page's text is, and has the number of each line beside it.
# The number of the line that the caret is in is a little darker. The list of
# the files in a zip has no numbers.

const NUMBER_GAP = 14px   # between the numbers of the lines and the text

"True when the page shows a whole file of code or of text, which can have the number of each line beside it"
numbered(b::Buffer) = b.view == :code || (b.view == :text && !(lowercase(splitext(b.path)[2]) in ZIPS))

"The font of the numbers of the lines: a little smaller and fainter than the code"
number_face(e) = (code = face(e, Line(Kind.code, 0, 0, "")); Face(code, size=code.size * 0.9, color=colours.faint))

"True when the page shows the number of each line beside it: a file of code or of text, unless the settings page hid them"
numbers(e) = numbered(e.buf) && e.numbers

"How much room the numbers of the page's lines take beside the text, with the gap between them. A page with no numbers takes none."
gutter(e) = numbers(e) ? measure(number_face(e), "0") * max(2, ndigits(length(e.buf.lines))) + NUMBER_GAP : 0px

"Write the number of each line on screen beside the line. The page's text starts at `left`, and its first line is at `top`."
draw_numbers(ctx, e, left, top) = begin
  b = e.buf
  numbers(e) || return
  f = number_face(e)
  # A number stands on the line that its line of code stands on
  rise = capital(face(e, Line(Kind.code, 0, 0, "")))
  for it in e.layout[e.shown]
    flow = it.content
    flow isa Flow || continue
    words = string(it.first)
    here = !caretless(b) && !readonly(b) && it.first == b.caret[1]
    x = left - NUMBER_GAP - measure(f, words)
    y = top + it.top + line_top(flow, 1) + (flow.lines[1].high + rise) / 2
    write_ink(ctx, words, num(x), num(y), here ? Face(f, color=colours.dim) : f)
  end
end

# A line of a file of code or of text that's too long for the window goes on
# under itself, at the window's right edge. The part under it starts one step of
# indentation further in than the line does, so it doesn't look like a line of
# its own. The settings page can turn that off. Then a long line goes on past
# the edge of the window, and the page scrolls sideways to show the rest of it,
# under the numbers of the lines. The caret stays in sight as it moves.
#
# The settings page has more for code. A file of code can show the numbers of
# its lines or not, shade the line that the caret is on, and have a faint line
# down it after a number of characters, to show where a line gets too long. In
# all code, in a file or in a page, it sets how big the code is and how many
# spaces one step of indentation is.

const INDENTS = (2, 4)                  # the steps of indentation that the settings page offers
const GUIDES = (0, 80, 92, 100, 120)    # the places for the line down a file of code. 0 is no line.
const CODE_SCALES = (0.4, 2.5)          # the least and most that code can be, beside the page's text
const SIDE_ROOM = 40px   # how near the caret gets to the left or right of the window before the page scrolls sideways

"True when the long lines of the page go on under themselves. Only a file of code or of text can have them go on past the window, and the lines of a file's bytes always do."
wraps(e) = !bytes_page(e.buf) && (e.wrap || !numbered(e.buf))

"How far the page is scrolled to the right"
sideways(e) = wraps(e) ? 0px : e.buf.across

"How far the page can scroll to the right: as far as the longest line goes past the right of the window"
sideways_room(e) = max(0px, e.reach + SIDE_ROOM - e.width)

"Scroll the page `by` to the right, as far as it goes"
scroll_sideways!(e, by) = (e.buf.across = clamp(e.buf.across + by, 0px, sideways_room(e)); e)

"""
Two fingers that move sideways on the trackpad, or the wheel with ⇧ held,
scroll the page sideways. Their move up or down still scrolls the page up or down.
"""
swipe!(e, ev::MouseScroll) = begin
  (wraps(e) || ev.delta[1] == 0px) && return nothing
  scroll_sideways!(e, -30ev.delta[1])
  ev.delta[2] == 0px ? handled : nothing
end
onscroll(d::Document, ev::MouseScroll) = swipe!(editor(d), ev)
onscroll(p::Page, ev::MouseScroll) = swipe!(editor(p), ev)

"How far the lines of `f` go, from the left of the text"
extent(f::Flow) = maximum(vl -> isempty(vl.segs) ? vl.x : last(vl.segs).x + last(vl.segs).w, f.lines)

"Turn on or off the wrapping of a line of a file of code that's too long for the window"
wrap!(e, on::Bool) = (e.wrap = on; save_settings!(e); rerun!(e, :wrap); restyle!(e))

"Show or hide the numbers of the lines of a file of code"
numbers!(e, on::Bool) = (e.numbers = on; save_settings!(e); rerun!(e, :numbers); restyle!(e))

"Shade the line of a file of code that the caret is on, or don't"
shade!(e, on::Bool) = (e.shade = on; save_settings!(e); rerun!(e, :shade); e)

"Make one step of indentation in code `n` spaces: 2 or 4"
indent_width!(e, n::Int) = begin
  n in INDENTS || error("A step of indentation is 2 or 4 spaces. $n isn't one of them.")
  e.indent = n
  save_settings!(e)
  rerun!(e, :indent)
  restyle!(e)
end

"Put the faint line down a file of code after `n` characters. 0 takes the line away."
guide!(e, n::Int) = begin
  n in GUIDES || error("The line goes after 80, 92, 100 or 120 characters, or 0 for none. $n isn't one of them.")
  e.guide = n
  save_settings!(e)
  rerun!(e, :guide)
  e
end

"Draw code in the font called `family`, in the weight that the settings choose or the nearest one it has"
code_font!(e, family::String) = begin
  installed_weight(family, 400) > 0 || error("This Mac has no font called $family.")
  e.code_font = family
  use_code_font!(e)
  save_settings!(e)
  rerun!(e, :code_font)
  restyle!(e)
end

"Draw code in the weight called `w`, like \"Light\", or in the weight `w`, like 300"
code_weight!(e, w::Union{Integer,AbstractString}) = begin
  e.code_weight = w isa Integer ? text_weight(w) : weight_called(e.code_font, w)
  use_code_font!(e)
  save_settings!(e)
  rerun!(e, :code_weight)
  restyle!(e)
end

"Make code `size` pixels tall, for a live block. The text of the page stays the size it is."
code_size!(e, size) = (e.code_scale = clamp(size / num(body(e).size), CODE_SCALES...); rewrap!(e))

"The spaces of one step of indentation, in a block of the kind `block`. In code the settings page chooses how many."
indentation(e, block) = block === CodeBlock ? " "^e.indent : STEP

"Lay out `text`, line `i` of a file that shows as text. It has no background of its own and starts at the edge of the page."
file_line(e, text, line::Line, i::Int) = begin
  ps = spare(pieces(e, text, line, false, i))
  # Lines of bigger code are further apart
  lh, size = code_size(e) * 1.5 / CODE_SCALE, face(e, line).size
  wraps(e) || return wrap(ps, px(Inf); lh, size)
  # The spaces at the start of the line, and one step more, though half the page is always left for the text
  indent = match(r"^[ \t]*", text).match
  hang = min(measure(face(e, line), indent * " "^e.indent), e.width / 2)
  wrap(ps, e.width; lh, size, hang)
end
