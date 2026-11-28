# The names that code offers: in a code block, in reach of the caret and in a long file, what a name is, and what a function takes
#
# While you type a name in a code block, a list under the caret shows the names
# that start the same way, as a sheet does. In Julia code they are the names
# that code at the caret can use. First come the names that the page's code
# makes, the nearest first: see "the names in reach of the caret". Then comes
# every other name that's in scope: the names that the page's code made when
# it ran, the names of Julia's own functions and types, like `length`, its
# macros, like `@show`, and the names that a live block has, like Slider. Code
# in any other language gets each name in the page's other code of that
# language, the nearest first. ↑ and ↓ choose a
# name, Return or Tab types the rest of it, and esc hides the list. In Julia
# code the list also says what each name is: see "what a name is" below.
#
# In a call, the list also has the names that the function gives its values,
# like `topdown=` of `walkdir`, and they come first. After the ; of a call they
# are the only names, and the list shows from the name's first character. See
# `call_names`. Each has the type of its value at its right, and the value
# that it has when a call leaves it out, like `Bool = true`: see `key_notes`.
#
# The list shows just after you type a character of a name, from the name's
# second character. It doesn't show in a string or a comment, after a dot, for
# a word of the language like `end`, or when what's typed is a whole name.

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "./markdown" Kind words MATTER TOML_MATTER MATH
@use "./highlight" tokens
@use "./sheet" parts shown
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...
@use "./gallery_view" exports...
@use "./timelog_view" exports...

export NAMES_SHOWN, NAME, NO_NAMES, no_names, page_names, scope_names, Syntax, NOWHERE, Scan, inreach, kids,
       iskind, span_of, bind!, type_code, value_words, target!, method!, used!, scan!, read_names, NamesPart,
       FileNames, read_parts, part_names, file_bounds, page_bounds, NOTE_COLS, bare_names, clip_note,
       how_made, value_note, CALL_SHOWN, CALL_LINES, Bracket, given_name, next_value!, open_brackets,
       caret_brackets, scope, named_value, method_parts, key_notes, call_lines, method_lines, takes_more,
       takes, caret_part, call_names, calling, call_typed!, call_shown, call_key!, call_pieces, call_fit,
       callbox

const NAMES_SHOWN = 8                         # the most names in the list
const NAME = r"[\p{L}_][\p{L}\p{N}_!]*"       # a name in code
# The blocks that aren't code, and a block with no language. Blocks with `block_is_code(T)` (ui, check, result) are Julia.
const NO_NAMES = (MATTER, TOML_MATTER, HEX, BITS, MATH, (l for (l, T) in BLOCKS if !block_is_code(T))..., "")
no_names(lang) = isempty(lang) || lang in (MATTER, TOML_MATTER, HEX, BITS, MATH) || (haskey(BLOCKS, lang) && !block_is_code(BLOCKS[lang]))

"The language that code in `lang` shares its names with. `jl` and Julia-backed blocks (`ui`, `check`, `result`) are Julia."
shared_lang(lang) = (l = lowercase(lang); l in JULIA || (haskey(BLOCKS, l) && block_is_code(BLOCKS[l])) ? "julia" : l)

"Each name in the page's code of the language `lang`, with the places it's written: a line and a column"
page_names(e, lang) = get!(e.flows, (:names, e.buf.path, e.buf.version, lang)) do
  b = e.buf
  found = Dict{String,Vector{Pos}}()
  for (i, line) in enumerate(kinds(b))
    (line.kind == Kind.code && !no_names(line.lang) && shared_lang(line.lang) == lang) || continue
    for t in tokens(b.lines[i], lang)
      t.kind in (:plain, :call, :type) || continue
      for m in eachmatch(NAME, t.text)
        # A column counts characters, and a match counts bytes
        col = t.col + length(SubString(t.text, 1, prevind(t.text, m.offset)))
        push!(get!(() -> Pos[], found, String(m.match)), (i, col))
      end
    end
  end
  found
end

"""
The names in scope in Julia code on the page, as two lists: the ones that the
page's code made when it ran, and the rest, like `length`, `@show` and Slider.
A page whose code hasn't run has Julia's own names. The lists are kept until
something makes a new name.
"""
scope_names(e) = begin
  m = something(made_workspace(e), window_modules(e).sandbox, Some(nothing))
  world = Base.get_world_counter()
  kept = get(e.nodes, :scope, nothing)
  kept !== nothing && kept[1] === m && kept[2] == world && return kept[3]
  named(list) = String[s for s in (string(n) for n in list) if occursin(r"^[\p{L}_@]", s)]
  mine(n) = !(n in (nameof(m), :eval, :include, :Kip, :Usual, :SheetUnits))
  lists = m === nothing ? (String[], named([names(Base); names(Core)])) :
          (named(filter(mine, Base.invokelatest(names, m, all=true, imported=true))), named(Base.invokelatest(names, m, usings=true)))
  e.nodes[:scope] = (m, world, lists)
  lists
end

"""
The names that the text before the caret could be the start of, in a code
block: the line, the column where the name starts, and the names, the best
first. Nothing when the caret isn't in code, or no name fits. A name fits when
it starts with what's typed, or when one of its words does, like `length` in
`wall_length`. The names that start with what's typed come first, and among
them the page's own.
"""
code_offered(e) = begin
  b = e.buf
  i, col = b.caret
  # Only just after a character was typed here. The caret can move through code with no list in
  # its way, and a caret that comes back to where it was has no list either.
  get(e.nodes, :typed_at, nothing) == (b.path, b.version, b.caret) || (delete!(e.nodes, :typed_at); return nothing)
  line = kinds(b)[i]
  (line.kind == Kind.code && !no_names(line.lang)) || return nothing
  chars = collect(b.lines[i])
  # In the middle of a word, nothing is offered
  col < length(chars) && isnamechar(chars[col+1]) && return nothing
  start = col
  while start > 0 && (isnamechar(chars[start]) || chars[start] == '!'); start -= 1 end
  # 2n is two times n, so a name starts after the digits
  while start < col && !(isletter(chars[start+1]) || chars[start+1] == '_'); start += 1 end
  # The @ of a macro is part of its name
  start > 0 && start < col && chars[start] == '@' && (start -= 1)
  lang = shared_lang(line.lang)
  # In a call, the names that the function gives its values are offered too. After the ; of the call
  # they're the only names, and the first character is enough.
  keys, only, said = lang == "julia" && col > start ? call_names(e, String(chars[start+1:col])) : (String[], false, Dict{String,String}())
  col - start >= (only ? 1 : 2) || return nothing
  # What's after a dot is a part of a value, and the page doesn't know the parts of a value
  start > 0 && chars[start] == '.' && return nothing
  # Not in a string or a comment, and not for a word of the language
  for t in tokens(b.lines[i], lang)
    t.col < col <= t.col + length(t.text) && t.kind in (:string, :comment, :keyword, :number) && return nothing
  end
  typed = lowercase(String(chars[start+1:col]))
  found = Tuple{Int,Int,Int,String}[]   # how well it fits, where it's from, how far away it is, and the name
  seen = Set{String}()
  # False when the name is what's typed, so nothing is offered. A name that fits is noted.
  note!(name, from, far) = begin
    low = lowercase(name)
    low == typed && return false
    name in seen && return true
    fit = startswith(low, typed) ? 0 : any(w -> startswith(w, typed), split(low, '_', keepempty=false)) ? 1 : 2
    fit < 2 && (push!(seen, name); push!(found, (fit, from, far, name)))
    true
  end
  # A name of a value is written with its =, unless one is there already
  given = col < length(chars) && chars[col+1] == '=' ? "" : "="
  for (k, key) in enumerate(keys)
    lowercase(key) == typed || note!(key * given, -1, k)
  end
  # The list says the type of each of them at its right: see `name_notes`
  e.nodes[:key_notes] = Dict{String,String}(key * given => get(said, key, "") for key in keys)
  if only
    isempty(found) && return nothing
    return (i, start, [name for (_, _, _, name) in first(sort!(found), NAMES_SHOWN)])
  end
  if lang == "julia"
    # Only the names that code at the caret can use: see "the names in reach of the caret"
    near = Dict{String,Int}()
    for made in page_bounds(e)
      # The name that's being typed can be one that the code makes, where the caret is
      (inreach(made, i) && made.at != (i, start)) || continue
      near[made.name] = min(get(near, made.name, typemax(Int)), abs(made.at[1] - i))
    end
    for (name, far) in near
      note!(name, 0, far) || return nothing
    end
    # The shortest name first, so `len` offers `length` before `lengthof`
    for (from, list) in enumerate(scope_names(e)), name in list
      note!(name, from, length(name)) || return nothing
    end
  else
    for (name, places) in page_names(e, lang)
      # The name that's being typed is in the page's code too, where the caret is
      others = [abs(p[1] - i) for p in places if p != (i, start)]
      isempty(others) || note!(name, 0, minimum(others)) || return nothing
    end
  end
  isempty(found) && return nothing
  (i, start, [name for (_, _, _, name) in first(sort!(found), NAMES_SHOWN)])
end

# --- the names in reach of the caret -----------------------------------------------------
#
# Julia code can use a name only where the name is in reach. A name that the
# code makes at its top is in reach in all of the page's Julia code. A name
# that's made inside a function, a loop or a `let` is in reach only there, and
# so is each value that a function takes. A field of a struct isn't a name
# that code can use. Neither is a name after a dot, or the name that a call
# gives a value, like `value` in Slider(value=0.4). The list offers only the
# names in reach of the caret.
#
# Julia's own parser reads the code. It reads code that's half typed too, and
# gives what it could make of it.

const Syntax = Base.JuliaSyntax
const NOWHERE = 1:0   # the lines where a field of a struct is in reach: none

"One block of Julia code as it's read: its lines, the line of the page that it starts on, and the names found so far"
struct Scan
  lines::Vector{String}
  first::Int
  starts::Vector{Int}   # the byte that each line starts at, in the text of the block
  found::Vector{Bound}
end

"True when code on line `i` of the page can use the name"
inreach(made::Bound, i::Int) = made.span === nothing || i in made.span

kids(n) = something(Syntax.children(n), ())
iskind(n, kinds...) = Syntax.kind(n) in kinds

"The lines of the page that the code `n` is on"
span_of(r::Scan, n) =
  (r.first + searchsortedlast(r.starts, Syntax.first_byte(n)) - 1):(r.first + searchsortedlast(r.starts, Syntax.last_byte(n)) - 1)

"Note that the code makes the name written at `n`, for code in the lines `span` to use"
bind!(r::Scan, n, span, words="", call=false; name=String(Syntax.sourcetext(n))) = begin
  (span === nothing || !isempty(span)) || return nothing
  occursin(r"^@?[\p{L}_][\p{L}\p{N}_!]*$", name) || return nothing
  byte = Syntax.first_byte(n)
  l = searchsortedlast(r.starts, byte)
  # A column counts characters, and the parser counts bytes
  push!(r.found, Bound(name, (r.first + l - 1, length(r.lines[l], 1, byte - r.starts[l])), words, call, span))
  nothing
end

"The code of a type, as the list shows it. Not `type_text`, which gives the text of a type that's a value."
type_code(n) = (text = Syntax.sourcetext(n); occursin('\n', text) ? "" : clip_note(bare_names(text)))

"The name in the first line of a type: Room in `Room{T} <: Shape`"
type_name(n) = iskind(n, Syntax.K"<:", Syntax.K"curly") && !isempty(kids(n)) ? type_name(kids(n)[1]) : n

"""
What the code `n` of a value says that the value is: the type of a plain
value, like Float64 for 4.2, or what the code calls, like Wall for Wall(0.9).
The second part is true for a call.
"""
value_words(n) = begin
  Syntax.is_leaf(n) && return (n.val isa Union{Number,Char} ? string(typeof(n.val)) : "", false)
  iskind(n, Syntax.K"string") && return ("String", false)
  iskind(n, Syntax.K"char") && return ("Char", false)
  c = kids(n)
  (iskind(n, Syntax.K"call") && !isempty(c) && iskind(c[1], Syntax.K"Identifier", Syntax.K".", Syntax.K"curly")) || return ("", false)
  called = Syntax.sourcetext(c[1])
  # a * (b) is a call to Julia, with `a` first. Only a name with its bracket straight after it is what's called.
  (startswith(Syntax.sourcetext(n), called * "(") && !occursin('\n', called)) || return ("", false)
  (String(called), true)
end

"""
Note each name that the code `n` gives a value: a name, a name with a type, or
several in brackets. A function's values and a loop's names are read here too,
where a name can come with code: `coats=2` and `w in walls`.
"""
target!(r::Scan, n, span, top, words="") = begin
  c = kids(n)
  if iskind(n, Syntax.K"Identifier")
    bind!(r, n, span, words)
  elseif iskind(n, Syntax.K"::")
    length(c) == 2 && target!(r, c[1], span, top, type_code(c[2]))
  elseif iskind(n, Syntax.K"=", Syntax.K"in") && length(c) == 2
    target!(r, c[1], span, top)
    scan!(r, c[2], span, top)
  elseif iskind(n, Syntax.K"filter") && !isempty(c)
    target!(r, c[1], span, top)
    foreach(x -> scan!(r, x, span, top), c[2:end])
  elseif iskind(n, Syntax.K"<:") && !isempty(c)
    target!(r, c[1], span, top)   # T in `where T<:Real`
  elseif iskind(n, Syntax.K"tuple", Syntax.K"parens", Syntax.K"...", Syntax.K"parameters", Syntax.K"iteration", Syntax.K"braces")
    foreach(x -> target!(r, x, span, top), c)
  end
  nothing
end

"""
Read a function or a macro. Its name is in reach of the lines `span`, where
it's made. The values that it takes are in reach inside it.
"""
method!(r::Scan, n, span, top) = begin
  c = kids(n)
  inner = span_of(r, n)
  sig = c[1]
  # f(x::T)::Int where T: the types after `where` are names inside the function
  while iskind(sig, Syntax.K"where", Syntax.K"::") && !isempty(kids(sig)) && iskind(kids(sig)[1], Syntax.K"call", Syntax.K"where", Syntax.K"::")
    iskind(sig, Syntax.K"where") && foreach(x -> target!(r, x, inner, top), kids(sig)[2:end])
    sig = kids(sig)[1]
  end
  s = kids(sig)
  if iskind(sig, Syntax.K"call") && !isempty(s)
    name = s[1]
    if iskind(name, Syntax.K"Identifier") && startswith(Syntax.sourcetext(sig), Syntax.sourcetext(name) * "(")
      iskind(n, Syntax.K"macro") ? bind!(r, name, span, "macro", name="@" * Syntax.sourcetext(name)) : bind!(r, name, span, "function")
    elseif !iskind(name, Syntax.K".", Syntax.K"curly")
      target!(r, name, inner, top)   # a in `a + b = ...`, and p in `(p::Paint)(area) = ...`
    end
    foreach(x -> target!(r, x, inner, top), s[2:end])
  elseif iskind(sig, Syntax.K"tuple")
    foreach(x -> target!(r, x, inner, top), s)   # function (x, y) ... end has no name
  elseif iskind(sig, Syntax.K"Identifier")
    bind!(r, sig, span, "function")   # function paint end
  end
  foreach(x -> scan!(r, x, inner, top), c[2:end])
end

"Note each name that a line of `@use` loads: a name, a macro like @def, and K in \"./main\" => K"
used!(r::Scan, n, span) =
  iskind(n, Syntax.K"Identifier", Syntax.K"macro_name") ? bind!(r, n, span) :
  iskind(n, Syntax.K"string") ? nothing : foreach(x -> used!(r, x, span), kids(n))

"""
Read the code `n` and note the names that it makes. A name that it makes here
is in reach of the lines `span`: nothing for the whole page. `top` is the same
for a name that's made with `global`: the lines of the module that the code is
in.
"""
scan!(r::Scan, n, span, top) = begin
  c = kids(n)
  isempty(c) && return nothing
  inner = span_of(r, n)
  if iskind(n, Syntax.K"=") && length(c) == 2
    if iskind(c[1], Syntax.K"Identifier")
      bind!(r, c[1], span, value_words(c[2])...)
    elseif iskind(c[1], Syntax.K"::", Syntax.K"tuple", Syntax.K"parens")
      target!(r, c[1], span, top)
    else
      scan!(r, c[1], span, top)   # room.door = ... and walls[1] = ... make no name
    end
    scan!(r, c[2], span, top)
  elseif iskind(n, Syntax.K"function", Syntax.K"macro")
    method!(r, n, span, top)
  elseif iskind(n, Syntax.K"->", Syntax.K"do")
    target!(r, c[1], inner, top)
    foreach(x -> scan!(r, x, inner, top), c[2:end])
  elseif iskind(n, Syntax.K"for", Syntax.K"let")
    foreach(x -> target!(r, x, inner, top), iskind(c[1], Syntax.K"block") ? kids(c[1]) : (c[1],))
    foreach(x -> scan!(r, x, inner, top), c[2:end])
  elseif iskind(n, Syntax.K"generator")
    foreach(x -> target!(r, x, inner, top), c[2:end])
    scan!(r, c[1], inner, top)
  elseif iskind(n, Syntax.K"while", Syntax.K"try")
    foreach(x -> scan!(r, x, inner, top), c)
  elseif iskind(n, Syntax.K"catch")
    iskind(c[1], Syntax.K"Identifier") && bind!(r, c[1], span)
    foreach(x -> scan!(r, x, span, top), c[2:end])
  elseif iskind(n, Syntax.K"struct")
    bind!(r, type_name(c[1]), span, Syntax.has_flags(n, Syntax.MUTABLE_FLAG) ? "mutable struct" : "struct")
    # A field isn't a name that code can use. A function in the struct still has names of its own.
    foreach(x -> scan!(r, x, NOWHERE, top), c[2:end])
  elseif iskind(n, Syntax.K"abstract", Syntax.K"primitive")
    bind!(r, type_name(c[1]), span, iskind(n, Syntax.K"abstract") ? "abstract type" : "primitive type")
  elseif iskind(n, Syntax.K"module")
    bind!(r, c[1], span, "module")
    foreach(x -> scan!(r, x, inner, inner), c[2:end])
  elseif iskind(n, Syntax.K"global")
    foreach(x -> iskind(x, Syntax.K"Identifier") ? bind!(r, x, top) : scan!(r, x, top, top), c)
  elseif iskind(n, Syntax.K"local", Syntax.K"const")
    foreach(x -> iskind(x, Syntax.K"Identifier", Syntax.K"::") ? target!(r, x, span, top) : scan!(r, x, span, top), c)
  elseif iskind(n, Syntax.K"using", Syntax.K"import")
    # using Dates: now, Day makes now and Day. import Foo.bar as baz makes baz.
    for x in c, y in (iskind(x, Syntax.K":") ? kids(x)[2:end] : (x,))
      iskind(y, Syntax.K"as", Syntax.K"importpath") && !isempty(kids(y)) && bind!(r, last(kids(y)), span)
    end
  elseif iskind(n, Syntax.K"macrocall")
    endswith(Syntax.sourcetext(c[1]), "@use") ? foreach(x -> used!(r, x, span), c[2:end]) : foreach(x -> scan!(r, x, span, top), c[2:end])
  elseif iskind(n, Syntax.K"call", Syntax.K"dotcall", Syntax.K"tuple", Syntax.K"parameters")
    # `value=0.4` in a call gives a value its name. It makes no name that code can use.
    foreach(x -> scan!(r, iskind(x, Syntax.K"=") && length(kids(x)) == 2 ? kids(x)[2] : x, span, top), c)
  elseif iskind(n, Syntax.K".")
    scan!(r, c[1], span, top)   # the name after a dot is a part of a value
  elseif iskind(n, Syntax.K"quote")
    # Code that's a value, like :(x = 1), makes no name
  else
    foreach(x -> scan!(r, x, span, top), c)
  end
  nothing
end

"The names that the Julia code of `lines` makes. The first of the lines is line `first` of the page."
read_names(lines::Vector{String}, first::Int) = begin
  r = Scan(lines, first, cumsum([1; [ncodeunits(l) + 1 for l in lines[1:end-1]]]), Bound[])
  try
    scan!(r, Syntax.parseall(Syntax.SyntaxNode, join(lines, '\n'), ignore_errors=true), nothing, nothing)
  catch err
    # The parser can give half typed code a shape that this doesn't expect. The names found so far still stand.
    @debug "The names of some Julia code couldn't all be read" err
  end
  r.found
end

# Julia takes some seconds to compile the reader the first time it runs, and the window would stop for
# them at the first list of names. So the reader runs once while this file is compiled, on code that
# has each kind of thing that it reads, and what Julia compiles for it is kept with this file.
# Kip looks for the files that this file loads in its text, so the line that loads one is written as @load here.
ccall(:jl_generating_output, Cint, ()) == 1 && read_names(String.(split(replace("""
  @load "./walls" Wall @def => K
  using Dates: now
  import Base: show
  const width::Float64 = 0.09
  struct Room{T} <: Shape
    walls::Vector{Wall}
    Room(walls) = new{Any}(walls)
  end
  abstract type Shape end
  module Paint
    global tins = 2
  end
  macro twice(code) :(\$code; \$code) end
  paint(area::T, coats=2; thin=false, more...) where T<:Real = area * coats
  function trim(room::Room, edges...)::Float64
    total, count = 0.0, 0
    for (i, wall) in enumerate(room.walls), side in 1:2
      total += wall.long
    end
    longs = [wall.long for wall in room.walls if wall.long > 1]
    map(longs) do long
      local half = long / 2
      let third = long / 3, name = "a \$long"
        while third > 1
          third -= 1
        end
      end
    end
    try
      Wall(long=total, name='w')
    catch err
      sort(longs, by=x -> -x)
    end
  end
  function unfinished(a, b
    c = a.
  """, "@load" => "@use"), '\n')), 1)

# --- the names of a long file --------------------------------------------------------------
#
# A file of Julia code can be tens of thousands of lines long, and the parser
# takes a moment to read that much. So the file's code is read in parts. A part
# is the code that starts on a line of its own at the top of the file, like one
# function, with the lines after it up to the next. After a change, only the
# parts that the change touches are read again, and the other parts keep their
# names. Code that's half typed can't close or open what's in another part, as
# it could if the whole file were read again: the names of the other parts stay
# as they were, which is what the list of names is best with.

"""
A part of a file's Julia code and the names that it makes. `first` is the line
that it starts on now. The lines in `names` are as they were when it started
on the line `read`.
"""
struct NamesPart
  first::Int
  read::Int
  names::Vector{Bound}
end

"The names of a file of Julia code, kept from one version of the file to the next, with the lines that they're of"
struct FileNames
  key::Tuple{String,Int}
  lines::Vector{String}
  parts::Vector{NamesPart}
  found::Vector{Bound}
end

"""
The Julia code of `lines` in parts, each with the names that it makes. The
first of the lines is line `start` of the page. The parts cover all the lines:
the first starts on line `start`.
"""
read_parts(lines::Vector{String}, start::Int) = begin
  r = Scan(lines, start, cumsum([1; [ncodeunits(l) + 1 for l in lines[1:end-1]]]), Bound[])
  parts = NamesPart[]
  from, taken, ended = start, 0, 0
  tree = try Syntax.parseall(Syntax.SyntaxNode, join(lines, '\n'), ignore_errors=true) catch; nothing end
  for n in (tree === nothing ? () : kids(tree))
    at = span_of(r, n)
    # Code that starts on the line where other code ends is in one part with it
    if ended > 0 && first(at) > ended
      push!(parts, NamesPart(from, from, r.found[taken+1:end]))
      from, taken = first(at), length(r.found)
    end
    ended = max(ended, last(at))
    try
      scan!(r, n, nothing, nothing)
    catch err
      # The parser can give half typed code a shape that this doesn't expect. The names found so far still stand.
      @debug "The names of some Julia code couldn't all be read" err
    end
  end
  push!(parts, NamesPart(from, from, r.found[taken+1:end]))
end

"The names of the parts, each with the lines that it has now"
part_names(parts::Vector{NamesPart}) = begin
  found = Bound[]
  sizehint!(found, sum(p -> length(p.names), parts, init=0))
  for p in parts
    by = p.first - p.read
    by == 0 && (append!(found, p.names); continue)
    for x in p.names
      push!(found, Bound(x.name, (x.at[1] + by, x.at[2]), x.words, x.call, x.span === nothing ? nothing : x.span .+ by))
    end
  end
  found
end

"The names that the file of Julia code in `b` makes. See \"the names of a long file\"."
file_bounds(e, b::Buffer) = begin
  old = get(e.nodes, :file_names, nothing)
  lines, n = b.lines, length(b.lines)
  parts = if old isa FileNames && old.key[1] == b.path
    m, ps = length(old.lines), old.parts
    head, tail = unchanged(lines, old.lines)
    # The parts that the change touches, with the line before the change and the line after it:
    # what's typed at the start or the end of a part can join the code of the part beside it
    starts = [p.first for p in ps]
    a = searchsortedlast(starts, max(head, 1))
    z = searchsortedlast(starts, min(m - tail + 1, m))
    from = ps[a].first
    to = z == length(ps) ? n : ps[z+1].first - 1 + n - m
    [ps[1:a-1]; read_parts(lines[from:to], from); [NamesPart(p.first + n - m, p.read, p.names) for p in ps[z+1:end]]]
  else
    read_parts(lines, 1)
  end
  found = part_names(parts)
  e.nodes[:file_names] = FileNames((b.path, b.version), copy(lines), parts, found)
  found
end

"The names that the page's Julia code makes, from every block of it. They're kept until the text changes."
page_bounds(e) = begin
  b = e.buf
  kept = get(e.nodes, :bounds, nothing)
  kept !== nothing && kept[1] == (b.path, b.version) && return kept[2]
  ks = kinds(b)
  julia(i) = ks[i].kind == Kind.code && !no_names(ks[i].lang) && shared_lang(ks[i].lang) == "julia"
  found = Bound[]
  # A file of code is one language from its first line to its last
  whole = b.view == :code && !isempty(ks) && julia(1)
  whole && (found = file_bounds(e, b))
  i = whole ? length(ks) + 1 : 1
  while i <= length(ks)
    j = i
    while j <= length(ks) && julia(j); j += 1 end
    j > i && append!(found, read_names(b.lines[i:j-1], i))
    i = max(j, i + 1)
  end
  e.nodes[:bounds] = ((b.path, b.version), found)
  found
end

# --- what a name is ----------------------------------------------------------------------
#
# In Julia code, each name of the list has a few paler words at its right that
# say what the name is. A name that has a value says the type of that value,
# like Float64 or Vector{Wall}. A function says `function`, a macro `macro` and
# a module `module`. A type says how it's made: `struct`, `mutable struct`,
# `abstract type` or `primitive type`.
#
# A name of the function, the loop or the `let` that the caret is in says what
# the code there says: the type after `name::`, or the type of a plain value,
# like `total = 0.0`. A name that the page's code made when it ran says what
# it is now. For any other name that the page's code makes, the words come
# from the code: `struct`, `function`, the type after `name::`, and the type
# of a plain value, like `width = 0.09` or `door = Wall(0.9)`. Then come
# Julia's own names. A name that nothing is known about has no words.

const NOTE_COLS = 32     # the most characters of what a name is
"`text` with each type written by its own name, with no module in front: `Main.Page.Wall` is `Wall`"
bare_names(text) = replace(text, r"(?<![\p{L}\p{N}_.])([\p{L}_][\p{L}\p{N}_]*\.)+(?=[\p{L}_])" => "")

"No more of what a name is than the list has room for"
clip_note(text) = length(text) > NOTE_COLS ? first(text, NOTE_COLS - 1) * "…" : String(text)

"How the type `T` is made: struct, mutable struct, abstract type or primitive type"
how_made(T::Type) = begin
  T = Base.unwrap_unionall(T)
  T isa DataType || return "type"
  isabstracttype(T) ? "abstract type" : isprimitivetype(T) ? "primitive type" : ismutabletype(T) ? "mutable struct" : "struct"
end

"What the value `v` is, in a few words. The type of a plain value is as code in the module `home` writes it."
value_note(v, home) = begin
  v isa Module && return "module"
  v isa Type && return how_made(v)
  v isa Function && return "function"
  io = IOBuffer()
  Base.invokelatest(show, IOContext(io, :module => home), typeof(v))
  clip_note(bare_names(String(take!(io))))
end

"""
What each of `names` is, for the list of names that shows at line `i`: a few
words, or "" when nothing is known. Only Julia code has them.
"""
name_notes(e, i::Int, names) = begin
  line = kinds(e.buf)[i]
  (line.kind == Kind.code && !no_names(line.lang) && shared_lang(line.lang) == "julia") || return fill("", length(names))
  m = scope(e)
  mine = scope_names(e)[1]
  reach = filter(made -> inreach(made, i), page_bounds(e))
  isbound(name) = Base.invokelatest(isdefined, m, Symbol(name))
  # The words for a name that has a value. Asking for a name's value runs none of the page's code.
  value(name) = try value_note(Base.invokelatest(getglobal, m, Symbol(name)), m) catch; "" end
  struct_of_page(name) = any(made -> made.name == name && made.words in ("struct", "mutable struct"), reach)
  # What one line of the code says. A call says the type of its value only when it calls a type.
  words(made) = begin
    made.call || return made.words
    head = first(split(made.words, '{'))
    struct_of_page(last(split(head, '.'))) || named_value(m, head) isa Type ? clip_note(bare_names(made.words)) : ""
  end
  # What the code says, from the nearest line to the list that says something
  written(lines) = begin
    for made in sort(lines, by=made -> abs(made.at[1] - i))
      said = words(made)
      isempty(said) || return said
    end
    ""
  end
  # A name that the function of a call gives a value says the type of that value: see `key_notes`
  keys = get(e.nodes, :key_notes, Dict{String,String}())
  map(names) do name
    haskey(keys, name) && return keys[name]
    startswith(name, '@') && return "macro"
    lines = filter(made -> made.name == name, reach)
    # A name of the function, the loop or the `let` that the caret is in comes before one of the whole page
    inside = filter(made -> made.span !== nothing, lines)
    if !isempty(inside)
      small = minimum(made -> length(made.span), inside)
      return written(filter(made -> length(made.span) == small, inside))
    end
    name in mine && isbound(name) && return value(name)
    said = written(lines)
    isempty(said) || return said
    isbound(name) ? value(name) : ""
  end
end

# --- what a function takes ---------------------------------------------------------------
#
# When you type the ( of a call in Julia code, a box under the line lists what
# the function takes: one line for each of its methods, as Julia writes them.
# A , or a ; that's typed in a call opens the box too, so a call that the caret
# came back to has a box for its next value.
# The page's own methods come first, and then the shortest. The value that the
# caret is at has a thin line under it. A value in square brackets can be left out.
# Each method has one line: the values that the window has no room for are
# left out, with an … in their place.
#
# The box shows while the caret's value has nothing typed in it. It goes when
# you start to type a value, and comes back after the , or the ; that ends that
# value, for the next one. So it's never in the way of the list of names. A
# call that's typed inside the call has a box of its own. The box closes when
# the caret leaves the brackets of the call, and esc hides it.
#
# The box is under the line that the caret is on, or over the line that the
# call starts on when the window has no room under the caret.
#
# The methods are the ones that the function has now, in the module that the
# page's code runs in. So a function that the page makes has a box once its
# code has run. After the first value, only the methods that can take the
# values before the caret, and one more, show.

const CALL_SHOWN = 6     # the most methods in the box
const CALL_LINES = 30    # how many lines above the caret a call can start

"A bracket that's open at the caret"
mutable struct Bracket
  open::Pos              # where it is
  name::String           # the function that it calls, or "" when it isn't the bracket of a call
  given::Int             # how many values before the caret's have no name
  keys::Vector{String}   # the names of the values before the caret's that have one
  named::Bool            # true after a ; where every value has a name
  spread::Bool           # true when a value before the caret's is many, like xs...
  words::String          # the text of the value that the caret is in
end

"The name that the value written as `words` is given, like size in size=12px, or nothing"
given_name(words) = (m = match(r"^\s*([\p{L}_][\p{L}\p{N}_!]*)\s*=(?![=>])", words); m === nothing ? nothing : String(m[1]))

"The value that the caret was in is done, and the next one starts"
next_value!(t::Bracket) = begin
  key = given_name(t.words)
  words = strip(t.words)
  if key !== nothing
    push!(t.keys, key)
  elseif !isempty(words)
    occursin("...", words) && (t.spread = true)
    # After a ; a bare name is a value with that name
    t.named ? push!(t.keys, String(words)) : (t.given += 1)
  end
  t.words = ""
end

"""
The name of the function that the ( after `chars[n]` calls, like `Base.length`,
or "" when the bracket isn't a call: one that groups, the bracket of a macro,
or the one that follows `function name`, which makes a method.
"""
callee(chars, n::Int) = begin
  j = n
  # Vector{Int}( calls Vector
  if j > 0 && chars[j] == '}'
    depth = 0
    while j > 0
      depth += chars[j] == '}' ? 1 : chars[j] == '{' ? -1 : 0
      j -= 1
      depth == 0 && break
    end
    depth == 0 || return ""
  end
  # sin.(xs) calls sin for each x
  j > 1 && j == n && chars[j] == '.' && (j -= 1)
  stop = j
  while j > 0 && (isnamechar(chars[j]) || chars[j] in ('!', '.')); j -= 1 end
  name = String(chars[j+1:stop])
  occursin(r"^[\p{L}_][\p{L}\p{N}_!]*(\.[\p{L}_][\p{L}\p{N}_!]*)*$", name) || return ""
  j > 0 && chars[j] == '@' && return ""
  occursin(r"(^|[^\p{L}\p{N}_!.])function\s+$", String(chars[1:j])) && return ""
  name
end

"""
The brackets that are open at the place `at` in the Julia code of the buffer,
the outermost first. The code is read from line `from`. A bracket in a string
or a comment isn't one.
"""
open_brackets(b::Buffer, from::Int, at::Pos) = begin
  i, col = at
  stack = Bracket[]
  for l in from:i
    chars = collect(b.lines[l])
    for t in tokens(b.lines[l], "julia")
      t.kind == :comment && continue
      for (k, c) in enumerate(t.text)
        here = t.col + k - 1
        l == i && here >= col && return stack
        top = isempty(stack) ? nothing : stack[end]
        if t.kind == :string
          top === nothing || (top.words *= '"')
        elseif c in ('(', '[', '{')
          top === nothing || (top.words *= c)
          push!(stack, Bracket((l, here), c == '(' ? callee(chars, here) : "", 0, String[], false, false, ""))
        elseif c in (')', ']', '}')
          isempty(stack) || pop!(stack)
        elseif top === nothing
        elseif c == ',' || c == ';'
          next_value!(top)
          c == ';' && (top.named = true)
        else
          top.words *= c
        end
      end
    end
    isempty(stack) || (stack[end].words *= ' ')
  end
  stack
end

"The brackets that are open at the caret, when the caret is in Julia code. Nothing when it isn't."
caret_brackets(e) = begin
  b = e.buf
  i = b.caret[1]
  ks = kinds(b)
  julia(l) = ks[l].kind == Kind.code && !no_names(ks[l].lang) && shared_lang(ks[l].lang) == "julia"
  julia(i) || return nothing
  from = i
  while from > 1 && i - from < CALL_LINES && julia(from - 1); from -= 1 end
  open_brackets(b, from, b.caret)
end

"The module whose names the page's Julia code can use: the one that the code runs in, or Julia's own before any code ran"
scope(e) = something(made_workspace(e), window_modules(e).sandbox, Base)

"The value that code in the module `m` calls `name`, like `length` or `Base.length`. Nothing when it has no such name."
named_value(m::Module, name::AbstractString) = begin
  v = m
  for part in split(name, '.')
    # Only a module is asked for a part. Any other value could run code of its own to answer.
    (v isa Module && Base.invokelatest(isdefined, v, Symbol(part))) || return nothing
    v = Base.invokelatest(getglobal, v, Symbol(part))
  end
  v
end

"""
What the method `m` takes: `params`, the values that have no name, each as
Julia writes it, `keys`, the names of those that have one, and `rest`, what
follows the brackets. A type is written by its own name, with no module in
front: Julia would write `Main.Page.Wall` and `Geometric_fb9.Padding`.
(`bare_names` does that for the notes of the list of names too.)
"""
method_parts(m::Method) = begin
  # A module whose name isn't a plain word is written as var"p/abstract"
  own(s) = bare_names(replace(s, r"var\"[^\"]*\"\." => ""))
  try
    tv, decls, _, _ = Base.arg_decl_parts(m)
    # A function that's a part of Julia itself, like getfield, doesn't say what it takes
    Base.unwrap_unionall(m.sig) === Tuple && return (params=["..."], keys=String[], rest="")
    params = String[own(isempty(type) ? name : name * "::" * type) for (name, type) in decls[2:end]]
    rest = isempty(tv) ? "" : " where " * (length(tv) == 1 ? string(tv[1]) : "{" * join(tv, ", ") * "}")
    (params=params, keys=String[string(k) for k in Base.kwarg_decl(m)], rest=own(rest))
  catch
    # Julia's own line for the method, when it won't give the parts
    inside = match(r"\((.*)\)", String(first(split(sprint(show, m), " @ "))))
    (params=inside === nothing ? String[] : [own(String(inside[1]))], keys=String[], rest="")
  end
end

"""
A few words for each of `keys`, the values of the method `m` that have a
name: the type that the method says the value is, and the value that it has
when a call leaves it out, like `Bool = true`. A value that the method gives
no type has the type of that other value, when it's a plain one like `true`
or `0.5`. In a method that makes the type `f`, it has the type of the field
with its name. A value with no type and no plain value says `Any`. When the
type and the value are too long for the list together, the type shows alone.

Julia keeps the types in the function that holds the method's code, and the
values that a call can leave out in the code that reads the names of a call.
"""
key_notes(m::Method, f, keys) = begin
  notes = Dict{String,String}()
  all(k -> endswith(k, "..."), keys) && return notes
  types = Dict{Symbol,Any}()
  try
    for held in Base.invokelatest(methods, Base.bodyfunction(m))
      for (name, T) in zip(Base.method_argnames(held), Base.unwrap_unionall(held.sig).parameters)
        get!(types, name, T)
      end
    end
  catch
  end
  usual = Dict{Symbol,Any}()
  try
    sig = Base.rewrap_unionall(Tuple{typeof(Core.kwcall),NamedTuple,(Base.unwrap_unionall(m.sig)::DataType).parameters...}, m.sig)
    reader = ccall(:jl_methtable_lookup, Any, (Any, UInt), sig, Base.get_world_counter())
    code = Base.uncompressed_ast(reader).code
    for (j, st) in enumerate(code)
      # `Core.isdefined(names, :name)`, and then a jump to `slot = value` for a call that leaves the name out
      (st isa Expr && st.head == :call && length(st.args) == 3 && st.args[1] == GlobalRef(Core, :isdefined) && st.args[3] isa QuoteNode) || continue
      jump = get(code, j + 1, nothing)
      jump isa Core.GotoIfNot || continue
      to = get(code, jump.dest, nothing)
      to isa Expr && to.head == :(=) && (usual[st.args[3].value] = to.args[2])
    end
  catch
  end
  for k in keys
    endswith(k, "...") && continue
    name = Symbol(k)
    T = get(types, name, Any)
    T === Any && f isa DataType && (T = try fieldtype(f, name) catch; Any end)
    v = get(usual, name, missing)
    plain = v isa Union{Number,AbstractString,Char}
    said = v isa GlobalRef ? string(v.name) : v isa QuoteNode ? repr(v.value) : plain ? repr(v) : ""
    type = T !== Any ? bare_names(string(T)) : plain ? string(typeof(v)) : ""
    # With no room for both, the type shows alone
    both = isempty(type) || isempty(said) ? "" : type * " = " * said
    notes[k] = clip_note(isempty(type) ? (isempty(said) ? "Any" : "= " * said) : isempty(both) || length(both) > NOTE_COLS ? type : both)
  end
  notes
end

const call_lines = Ref{Any}((nothing, 0, nothing))

"""
One line for each method of `f`: its `params`, its `keys` and its `rest`, as
`method_parts` gives them, `needed`, how many of the params a call must
give, `mod`, the module that the method is in, and `notes`, what `key_notes`
says of each of the keys. A method with a value that
can be left out is several methods to Julia, and one line here. The lines of
the last function are kept until something makes a new method.
"""
method_lines(f) = begin
  world = Base.get_world_counter()
  kept = call_lines[]
  kept[1] === f && kept[2] == world && return kept[3]
  ms = collect(Base.invokelatest(methods, f))
  parts = map(method_parts, ms)
  needed = Int[length(p.params) for p in parts]
  keep = trues(length(ms))
  # The methods that one line of code made, by the place of that line
  places = Dict{Any,Vector{Int}}()
  foreach(k -> push!(get!(() -> Int[], places, (ms[k].module, ms[k].file, ms[k].line)), k), eachindex(ms))
  for same in values(places), a in same, c in same
    short, long = parts[a].params, parts[c].params
    # Julia makes a method that takes fewer values for each value with a default, and it passes them on to the whole method
    (length(short) < length(long) && short == long[1:length(short)] && (isempty(parts[a].keys) || parts[a].keys == ["..."])) || continue
    keep[a] = false
    needed[c] = min(needed[c], length(short))
  end
  lines = [(params=parts[k].params, keys=parts[k].keys, rest=parts[k].rest, needed=needed[k], mod=ms[k].module,
            notes=key_notes(ms[k], f, parts[k].keys)) for k in eachindex(ms) if keep[k]]
  call_lines[] = (f, world, lines)
  lines
end

"True when the last of `names` stands for any number of values, like xs... or kw..."
takes_more(names) = !isempty(names) && endswith(names[end], "...")

"True when the method of `line` can take the values that the call `t` gives before the caret, and one more at the caret"
takes(line, t::Bracket) = begin
  all(k -> takes_more(line.keys) || k in line.keys, t.keys) || return false
  # After a ; the value at the caret has a name
  t.named && return !isempty(line.keys)
  (t.spread || takes_more(line.params) || t.given < length(line.params)) && return true
  # A method that has all its values with no name can still take one with a name. A call with no values is any method's.
  t.given == length(line.params) && (t.given == 0 || !isempty(line.keys))
end

"Which of the params of `line` the caret's value of the call `t` is for, or nothing when it's for none of them"
caret_part(line, t::Bracket) = begin
  t.named && return nothing
  k = t.given + 1
  k <= length(line.params) ? k : takes_more(line.params) && line.params != ["..."] ? length(line.params) : nothing
end

"""
The names that the function of the call at the caret gives its values, like
`topdown` of `walkdir`, when the caret's value is `word` and no more: such a
name goes at the start of a value. The names that the call already gives are
left out. And true when the caret is after the ; of the call, where every
value has a name. And what `key_notes` says of each name. The list of names
offers them: see `code_offered`.
"""
call_names(e, word) = begin
  none = (String[], false, Dict{String,String}())
  stack = caret_brackets(e)
  (stack === nothing || isempty(stack) || isempty(stack[end].name)) && return none
  t = stack[end]
  strip(t.words) == word || return none
  f = named_value(scope(e), t.name)
  (f === nothing || f isa Module) && return none
  names = String[]
  notes = Dict{String,String}()
  for line in method_lines(f), k in line.keys
    (endswith(k, "...") || k in t.keys || k in names) && continue
    push!(names, k)
    notes[k] = get(line.notes, k, "")
  end
  (names, t.named && !isempty(names), notes)
end

"Where the box of the open call is, and whether esc hid it. Nothing when no call's box is open."
calling(e) = get(e.nodes, :calling, nothing)

"""
The character `c` was typed at the caret. The ( that starts a call opens the
call's box. So does a , or a ; that's typed in a call that has no box, like
one that the caret came back to: it starts the call's next value.
"""
call_typed!(e, c::Char) = begin
  b = e.buf
  stack = caret_brackets(e)
  stack === nothing && return
  # The bracket that was typed, or the call that the , or the ; is in
  k = c == '(' ? (isempty(stack) || isempty(stack[end].name) ? nothing : length(stack)) : findlast(t -> !isempty(t.name), stack)
  k === nothing && return
  state = calling(e)
  if state !== nothing && state.path == b.path && any(t -> t.open == state.open, stack)
    # A call that's typed in a call whose box shows uses that box. A box that esc hid stays hidden for the rest of its call.
    (!state.hidden || c != '(') && return
  end
  e.nodes[:calling] = (path=b.path, open=stack[k].open, hidden=false)
  nothing
end

"""
What the box of the open call shows: `name`, the function as the code writes
it, `call`, the bracket of the call, `lines`, the methods to list, and `more`,
how many more there are. Nothing when no box shows: no call is open, the caret
has left the call, the caret's value has some text, or the name isn't a
function that the page's code can call.
"""
call_shown(e) = begin
  state = calling(e)
  state === nothing && return nothing
  b = e.buf
  off() = (delete!(e.nodes, :calling); nothing)
  (state.path != b.path || caretless(b) || selecting(b)) && return off()
  key = (b.path, b.version, b.caret, Base.get_world_counter(), scope(e))
  kept = get(e.nodes, :call_shown, nothing)
  kept !== nothing && kept[1] == key && return state.hidden ? nothing : kept[2]
  stack = caret_brackets(e)
  # The box is for the call that was typed and the calls in it, so it closes when the caret leaves that call
  (stack === nothing || !any(t -> t.open == state.open, stack)) && return off()
  found = nothing
  k = findlast(t -> !isempty(t.name), stack)
  # Once some of the caret's value is typed, the box goes until the next value
  k === nothing || isempty(strip(stack[k].words)) || (k = nothing)
  f = k === nothing ? nothing : named_value(scope(e), stack[k].name)
  if f !== nothing && !(f isa Module)
    t = stack[k]
    lines = method_lines(f)
    fitting = filter(line -> takes(line, t), lines)
    isempty(fitting) && (fitting = lines)
    # The methods that the page's own code made come first, then the ones in the module that the function is from.
    # Among those, the shortest come first: they take the plainest values, like length(s::String).
    mine = made_workspace(e)
    home = f isa Union{Function,Type} ? parentmodule(f) : nothing
    long(line) = sum(length, line.params, init=0) + sum(length, line.keys, init=0)
    fitting = sort(fitting, by=line -> (line.mod !== mine, line.mod !== home, long(line)))
    isempty(fitting) || (found = (name=String(last(split(t.name, '.'))), call=t, lines=first(fitting, CALL_SHOWN),
                                  more=max(0, length(fitting) - CALL_SHOWN)))
  end
  e.nodes[:call_shown] = (key, found)
  state.hidden ? nothing : found
end

"What esc does while the box of a call shows: it hides the box. It returns true when it did."
call_key!(e, K) = begin
  (K == Keys.escape && call_shown(e) !== nothing) || return false
  e.nodes[:calling] = (path=e.buf.path, open=calling(e).open, hidden=true)
  touch!(e)
  true
end

"""
The words of one line of the box, as pieces: the text of each, and true for
the piece that the caret's value is for.
"""
call_pieces(name, line, t::Bracket) = begin
  at = caret_part(line, t)
  pieces = Tuple{String,Bool}[(name * "(", false)]
  for (k, p) in enumerate(line.params)
    k > 1 && push!(pieces, (", ", false))
    optional = k > line.needed && !endswith(p, "...")
    push!(pieces, (optional ? "[" * p * "]" : p, at == k))
  end
  for (k, key) in enumerate(line.keys)
    push!(pieces, (k == 1 ? "; " : ", ", false))
    push!(pieces, (key, false))
  end
  push!(pieces, (")" * line.rest, false))
  pieces
end

"""
The pieces of one line of the box, cut down to fit in `room`, so that each
method has one line. The values that would make the line too wide are left
out, and an … is in their place. The value that the caret is at stays, with
the value before it when that fits. `wide` gives the width of a piece.
"""
call_fit(pieces, wide, room) = begin
  sum(p -> wide(p[1]), pieces) <= room && return pieces
  head, tail = pieces[1], pieces[end]
  # Each value, with the , or the ; that's before it
  items = Tuple{String,String,Bool}[]
  sep = ""
  for (text, here) in pieces[2:end-1]
    text in (", ", "; ") ? (sep = text) : (push!(items, (sep, text, here)); sep = "")
  end
  n = length(items)
  budget = room - wide(head[1]) - wide(tail[1])
  # The values from `from` on that fit, with room for the … of the values that are left out
  fitting(from) = begin
    used = from > 1 ? wide("…, ") : 0px
    to = from - 1
    for j in from:n
      w = (j == from && from > 1 ? 0px : wide(items[j][1])) + wide(items[j][2])
      used + w + (j < n ? wide(", …") : 0px) > budget && break
      used += w
      to = j
    end
    from:to
  end
  shown = fitting(1)
  at = findfirst(it -> it[3], items)
  if at !== nothing && !(at in shown)
    shown = fitting(max(1, at - 1))
    at in shown || (shown = fitting(at))
    at in shown || (shown = at:at)
  end
  out = Tuple{String,Bool}[head]
  for j in shown
    j == first(shown) && j > 1 && push!(out, ("…", false))
    isempty(items[j][1]) || push!(out, (items[j][1], false))
    push!(out, (items[j][2], items[j][3]))
  end
  if last(shown) < n
    next = items[last(shown)+1][1]
    isempty(next) || push!(out, (next, false))
    push!(out, ("…", false))
  end
  push!(out, tail)
end

"""
The box of the open call, placed in the window under the line that the caret
is on. When the window has no room there, the box is over the line that the
call starts on, so that it doesn't cover the call's own code. Nothing when
there's no box to show.
"""
callbox(e) = begin
  found = call_shown(e)
  found === nothing && return ()
  b = e.buf
  start = found.call.open
  it = item(e, start[1])
  f = it.content
  f isa Flow || return ()
  face = Face(codefont(), codestyle(), f.size, colours.ink, false)
  high = face.size * 1.8
  k, across = spot(f, start[2])
  w, _ = window_size(e)
  # The box stays beside the list of files, and each method has one line of it: see `call_fit`
  edge = (lowered(e) === nothing ? side_w(e) : 0px) + 8px
  room = w - 8px - edge - 22px
  listed = map(found.lines) do line
    pieces = call_fit(call_pieces(found.name, line, found.call), text -> measure(face, text), room)
    parts = map(pieces) do (text, here)
      words = [part for tok in tokens(text, "julia") for part in coloured(tok, face)]
      # The value that the caret is at has a thin line under it, with a slight glow on the line's underside.
      # The space over the words is as tall as the line, so the words stay level with the rest of the row.
      here ? Column(Alignment.Start, Box(height(1px)), Row(Alignment.Center, height(face.size * 1.3), words...),
                    Box(width(grow=grow), height(1px), background(tint(colours.accent, 0.75)), shadow(0px, 2.5px, 5px, tint(colours.accent, 0.75)))) :
             Row(Alignment.Center, words...)
    end
    (sum(p -> measure(face, p[1]), pieces), Row(width(grow=grow), height(high), Alignment.Center, clip=true, parts...))
  end
  said = found.more == 0 ? "" : found.more == 1 ? "and 1 more method" : "and $(found.more) more methods"
  note = Face(SANS, "", face.size * 0.92, colours.dim, false)
  under = isempty(said) ? () : (Row(width(grow=grow), height(high), Alignment.Center, spared(said, note)...),)
  wide = min(w - 8px - edge, max(maximum(first, listed), measure(note, said)) + 22px)
  tall = high * (length(listed) + length(under)) + 12px
  # The name in the box is in line with the name in the code, so each value in the box is near the place where it's typed
  left = clamp(text_left(e) + across - measure(face, found.name) - 11px, edge, max(edge, w - 8px - wide))
  page_y = above_page(e) + PAGE_TOP - e.scroll.offset
  over = page_y + it.top + line_top(f, k) - tall - 3px
  at = item(e, b.caret[1])
  g = at.content
  g isa Flow || return ()
  j, _ = spot(g, b.caret[2])
  below = page_y + at.top + line_top(g, j) + g.lines[j].high + 3px
  room_over = over >= above_page(e) + 4px
  room_below = below + tall <= window_size(e)[2] - 4px
  top = !room_below && room_over ? over : below
  box = Column(fixed(wide), Alignment.Start, padding(10px, 5px), radius(7px), background(colours.float), border(1px, :solid, colours.line), lifted,
    name="Call", map(last, listed)..., under...)
  (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, left), box),)
end
