# What a function and a module have to show, and the headings of a module's table of names
#
# The open box of a function shows the function's documentation as it reads,
# and under it a table of the function's methods: what each one takes, and the
# module, the file and the line that it's in.
#
# The box of a type says what the type is a kind of, as in `Meter <:
# SemanticUI`. Open, it shows the type as code declares it, with its fields,
# and under that its documentation. A UI node's type has no fields there that
# join it to the nodes around it, as a node's list of parts has none.
#
# The open box of a module shows the module's readme, from the folder of its
# code or a folder above that. A module with no readme shows its documentation.
# Under that is a table of the names that the module defines, with what kind of
# thing each one is. A field over the table searches the names. While it has
# words in it, the box shows only the names that have them.
#
# The table of a module's names has a heading over each column: Name, Kind and
# About. A click on a heading opens a menu, as a heading of a takeoff's table
# does. The menu has the column's two orders, and a way to show fewer rows: a
# field that keeps the rows that have its words in that column, or for Kind a
# list of the kinds to show. Return keeps what the field holds, and esc puts
# back what it held before. A heading whose column shows fewer rows is in the
# accent colour.
#
# A click on a name in that table shows the name's value under its row, and a
# second click hides it: the documentation and the methods of a function, a
# type as code declares it, with its fields inside, and its documentation, the
# names of a module, and any other value as Julia writes it. One name shows its
# value at a time.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor popup! close_popup! MouseScroll
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./markdown" classify words
@use "./highlight" tokens
@use "./sheet" parts
@use Colors: RGBA
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...
@use "./gallery_view" exports...
@use "./timelog_view" exports...
@use "./run_code" exports...
@use "./code_thing" code_place

export DETAIL_W, DETAIL_H, DETAIL_ROW, DETAIL_HEAD, DETAIL_PAD, SEARCH_H, Detail, NameRow, doc_table,
       doc_lines, readme_lines, method_row, method_rows, kind_of, documents, documented, doc_sentence, about,
       name_rows, type_text, declaration, detail_of, open_row!, sort_words, sought!, detail_row, MethodRow,
       method_row!, table_row, page_part, rows_part, count_words, doc_tall, inner_tall, INNER_X, NAMES_KEY,
       NAME_COLUMNS, NameHead, NameMenu, NameSort, KindRow, kinds_of, head_part!, names_head, close_menu!,
       inner_view

const DETAIL_W = 660px      # the widest that the open box of a function or a module is
const DETAIL_H = 430px      # the tallest that its documentation and table are. The wheel moves through the rest.
const DETAIL_ROW = 24px     # the height of a row of its table
const DETAIL_HEAD = 34px    # the height of the words over the table
const DETAIL_PAD = 14px     # on each side of what it shows
const SEARCH_H = 34px       # the height of the field that searches a module's names

"What the open box of a function or a module shows: its documentation as it reads, and a table under that"
mutable struct Detail
  of::Any                           # the function, the module or the other value that it's about
  lines::Vector{String}             # the documentation, as Markdown
  page::Any                         # those lines laid out, as a FilePage, or nothing when there are none
  key::Any                          # what they were laid out for: a width, and the size, colours and font of the page's text
  rows::Vector{NTuple{3,String}}    # the table. A method: what it takes, "", and where it is. A name: the name, its kind, and more about it.
  what::String                      # what a row is: "method", "name" or "field", or "" for no table
  scroll::Scroll
  search::Any                       # the text field that searches the table of a module, or nothing
  sought::Any                       # what the rows were last found for: the field's words, the order, and what each column keeps
  found::Vector{Int}                # the rows that the table shows, in the order that it shows them
  sort::Any                         # the column that the rows are in order of and :asc or :desc, or nothing for the order of the names
  filters::Dict{Int,String}         # the words that a column's rows must have, for each column that has some
  only::Set{String}                 # the kinds of name that show. Every kind shows while it's empty.
  asking::Int                       # the column whose menu is open, or 0
  was::String                       # what that column's field held when the menu opened, which esc puts back
  field::Any                        # the text field of the menu
  heads::Dict{Any,Any}              # the nodes of the headings and of the menu's lines
  open::Int                         # the row of a module's table whose value shows under it, or 0
  inner::Any                        # the Detail of that value
  parts::Dict{Int,Any}              # the node of each row of a module's table that has been in view. It takes the row's clicks.
  wide::px                          # how wide the rows were last drawn
  methods::Vector{Method}           # the method of each row of a function's table. A click on the row shows its code.
end

Detail(of, lines, rows, what; search=nothing) =
  Detail(of, lines, nothing, nothing, rows, what, Scroll(width(grow=grow), height(grow=grow)), search, nothing, Int[],
         nothing, Dict{Int,String}(), Set{String}(), 0, "", nothing, Dict{Any,Any}(), 0, nothing, Dict{Int,Any}(), 0px, Method[])

"A row of a module's table of names. A click on it shows the name's value under it, or hides it."
@def mutable struct NameRow <: SemanticUI
  of::Any = nothing   # the OutcomeBody that the table is in
  i::Int = 0          # which row of the table
end

"How wide the open box of a function or a module is: as wide as the window has room for, up to `DETAIL_W`"
detail_wide(e) = (w = window_size(e)[1]; clamp(w - side_w(e) - 2OUTCOME_EDGE - 16px, 280px, DETAIL_W))

"""
The documentation that the module `mod` wrote, by the name that it's for. An app
built with APP_STRIP=metadata (see app/bundle.jl) leaves out the documentation
of the code that was built into it, like Base's. Julia then throws when it's
asked for it, so such a module has none here.
"""
doc_table(mod::Module) = try Base.invokelatest(Base.Docs.meta, mod) catch; IdDict{Any,Any}() end

"""
The documentation that Julia has for the name `name` of the module `m`, as
Markdown: each piece that a module that's loaded wrote for it. Julia writes
what a function takes on lines that start with four spaces. They become a
block of Julia code, so they have its colours. A note's words, which start with
four spaces too, stay words.
"""
doc_lines(m::Module, name::Symbol) = begin
  binding = Base.Docs.Binding(m, name)
  lines = String[]
  for mod in Base.Docs.modules
    multi = get(doc_table(mod), binding, nothing)
    multi === nothing && continue
    for sig in multi.order
      doc = multi.docs[sig]
      text = isempty(doc.text) ? string(doc.object) : join(doc.text)
      isempty(strip(text)) && continue
      isempty(lines) || append!(lines, ["", "---", ""])
      incode = fenced = noting = false
      for line in split(rstrip(text), '\n')
        startswith(line, "```") && (fenced = !fenced; line = fenced ? "```julia" : "```")
        # A note starts with a line like `!!! note`, and its words are on lines that start with four spaces
        note = fenced ? nothing : match(r"^!!! +(\w+)", line)
        note === nothing || (noting = true; line = "**" * titlecase(note[1]) * "**")
        noting && note === nothing && !isempty(strip(line)) && !startswith(line, "    ") && (noting = false)
        noting && note === nothing && (line = lstrip(line))
        indented = !fenced && !noting && startswith(line, "    ")
        indented && !incode && push!(lines, "```julia")
        !indented && incode && !isempty(strip(line)) && (push!(lines, "```"); incode = false)
        incode |= indented
        (incode && isempty(strip(line))) || push!(lines, indented ? String(chopprefix(line, "    ")) : String(line))
      end
      incode && push!(lines, "```")
    end
  end
  lines
end

"The lines of the readme of the module `m`, or nothing when it has none: a file called readme in the folder of its code, or in a folder above that"
readme_lines(m::Module) = begin
  # Kip knows the file of a module that it loaded. Julia knows the file of a package.
  file = something(findfirst(mod -> mod === m, Kip.modules), pathof(m), Some(nothing))
  file === nothing && return nothing
  dir = dirname(file)
  # A package keeps its code in a folder of its own, so its readme can be a folder or two up
  for _ in 1:3
    isdir(dir) || break
    k = findfirst(name -> occursin(r"^readme(\.md|\.markdown|\.txt)?$"i, name), readdir(dir))
    if k !== nothing
      found = try reading(joinpath(dir, readdir(dir)[k]), tidy=false) catch; nothing end
      return found === nothing ? nothing : found[1]
    end
    # The folder that holds a package or a repository is as far up as its readme can be
    (ispath(joinpath(dir, ".git")) || isfile(joinpath(dir, "Project.toml"))) && break
    dir = dirname(dir)
  end
  nothing
end

"The row of a table of methods for the method `m`: what it takes, and the module, the file and the line that it's in"
method_row(m::Method) = begin
  # A package's own way to write a type in the method can fail. The method's name and the names of its arguments can't.
  takes = try
    String(first(split(Base.invokelatest(sprint, show, m), " @ ")))
  catch
    string(m.name, "(", join(Base.method_argnames(m)[2:end], ", "), ")")
  end
  (takes, "", string(m.module, " · ", basename(string(m.file)), ":", m.line))
end

"One row of the table for each method of `f`: what it takes, and the module, the file and the line that it's in"
method_rows(f) = map(method_row, collect(Base.invokelatest(methods, f)))

"What kind of thing the value `v` is, which a module calls `name`"
kind_of(name::String, v) =
  startswith(name, '@') ? "macro" : v isa Module ? "module" : v isa Function ? "function" :
  v isa Type ? (isabstracttype(v) ? "abstract type" : "type") : "value"

const documents = Ref{Any}((0, Dict{Any,Vector{Any}}()))

"""
The documentation that each module that's loaded has, by the name that it's
for. It's read once and kept until something makes a new name or a new
method, so that the table of a big module like Base is made in a moment.
"""
documented() = begin
  world = Base.get_world_counter()
  documents[][1] == world && return documents[][2]
  found = Dict{Any,Vector{Any}}()
  for mod in Base.Docs.modules, (binding, multi) in doc_table(mod)
    push!(get!(() -> Any[], found, binding), multi)
  end
  documents[] = (world, found)
  found
end

"""
The first sentence of the documentation that Julia has for the name `name` of
the module `m`, or "" when it has none. The lines that say what a function
takes, and blocks of code, aren't sentences.
"""
doc_sentence(m::Module, name::Symbol) = begin
  for multi in get(documented(), Base.Docs.Binding(m, name), ())
    for sig in multi.order
      doc = multi.docs[sig]
      words, fenced = "", false
      for line in split(isempty(doc.text) ? string(doc.object) : join(doc.text), '\n')
        startswith(line, "```") && (fenced = !fenced; continue)
        plain = strip(line)
        # A sentence can run over two or three lines, and stops at a blank line
        (fenced || startswith(line, "    ") || startswith(plain, '#') || startswith(plain, "!!!")) && (isempty(words) ? continue : break)
        isempty(plain) && (isempty(words) ? continue : break)
        words = isempty(words) ? String(plain) : words * " " * plain
        (occursin(". ", words) || endswith(words, '.') || length(words) > 160) && break
      end
      isempty(words) && continue
      stop = findfirst(". ", words)
      words = stop === nothing ? words : words[1:first(stop)]
      return length(words) > 120 ? first(words, 119) * "…" : words
    end
  end
  ""
end

"""
A few words about the value `v`, which the module `m` calls `name`, for the
About column of the table of the module's names. They're the first sentence of
its documentation. A name with no documentation has what can be said without
it: how many methods a function has, what a type is a kind of, and any other
value as Julia writes it, or its type and size when it's big.
"""
about(m::Module, name::Symbol, v) = begin
  if v isa Union{Function,Module,Type}
    # A name that a module borrows has its documentation where the thing was made
    words = try doc_sentence(parentmodule(v), nameof(v)) catch; "" end
    isempty(words) && (words = try doc_sentence(m, name) catch; "" end)
    isempty(words) || return words
    v isa Function && return (n = length(Base.invokelatest(methods, v)); n == 1 ? "1 method" : "$n methods")
    # A package's own way to write a type can fail, as Prospects.jl's does for ScopedEnum{UInt8}. Its name alone can't.
    v isa DataType && supertype(v) !== Any && return "a kind of " * (try string(supertype(v)) catch; string(nameof(supertype(v))) end)
    return ""
  end
  # A small value is written out. A big one is named by its type and its size: its row shows all of it when it's open.
  text = try
    v isa Union{Number,Symbol,Char,Nothing,Missing} ? repr(v) :
    v isa AbstractString ? repr(length(v) > 60 ? first(v, 60) * "…" : v) :
    v isa Union{AbstractArray,AbstractDict,AbstractSet} ? Base.invokelatest(summary, v) : string(typeof(v))
  catch
    string(typeof(v))
  end
  text = replace(text, r"\s*\n\s*" => " ")
  length(text) > 80 ? first(text, 79) * "…" : text
end

"One row of the table for each name that the module `m` defines: the name, its kind, and more about it"
name_rows(m::Module) = begin
  rows = NTuple{3,String}[]
  for name in sort!(Base.invokelatest(names, m, all=true), by=n -> lowercase(lstrip(string(n), ('@', '_'))))
    s = string(name)
    (startswith(s, '#') || name in (:eval, :include, nameof(m))) && continue
    (Base.invokelatest(isdefined, m, name) && !Base.isdeprecated(m, name)) || continue
    v = Base.invokelatest(getglobal, m, name)
    push!(rows, (s, kind_of(s, v), about(m, name, v)))
  end
  rows
end

"What the open box of the function `f` shows"
Detail(f::Function) = begin
  ms = collect(Method, Base.invokelatest(methods, f))
  t = Detail(f, doc_lines(parentmodule(f), nameof(f)), map(method_row, ms), "method")
  t.methods = ms
  t
end

"What the open box of the module `m` shows"
Detail(m::Module) = begin
  lines = something(readme_lines(m), doc_lines(parentmodule(m), nameof(m)))
  search = TextInput(placeholder="Search the names", font_family=SANS, font_size=13px,
                     look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
  Detail(m, lines, name_rows(m), "name"; search)
end

"True when the box of the value `v` opens to show the type that `v` is: a struct, an abstract type or a primitive type, with or without its parameters"
declared(v) = v isa Type && Base.unwrap_unionall(v) isa DataType

"""
`T`, a type or a parameter of one, as Julia writes it. With the module `home`,
a type that code in `home` can name has no module's name in front of its own. A
type that its package can't write, like Prospects.jl's ScopedEnum{UInt8}, is
its name.
"""
type_text(T, home=nothing) = try
  io = IOBuffer()
  Base.invokelatest(show, home === nothing ? io : IOContext(io, :module => home), T)
  String(take!(io))
catch
  T isa Union{DataType,UnionAll} ? string(nameof(T)) : string(typeof(T))
end

"What the box of the type `T` says: the type, and what it's a kind of when that isn't `Any`, as in `Meter <: SemanticUI`. `home` is as it is for `type_text`."
type_brief(T::Type, home=nothing) = begin
  up = supertype(Base.unwrap_unionall(T)) === Any ? nothing : try supertype(T) catch; nothing end
  up === nothing ? type_text(T, home) : type_text(T, home) * " <: " * type_text(up, home)
end

"""
The type `T` as Julia code declares it: `struct`, `mutable struct`, `abstract
type` or `primitive type`, its name with its parameters, what it's a kind of
when that isn't `Any`, and a line for each field with the field's type. The
fields that join a UI node to the nodes around it aren't the node's own, so
they're left out. `home` is as it is for `type_text`.
"""
declaration(T::Type; home=nothing) = begin
  inside = Base.unwrap_unionall(T)
  inside isa DataType || return [type_text(T, home)]
  words(x) = type_text(x, home)
  name = string(nameof(inside)) * (isempty(inside.parameters) ? "" : "{" * join(map(words, inside.parameters), ", ") * "}")
  supertype(inside) === Any || (name *= " <: " * words(supertype(inside)))
  isabstracttype(inside) && return ["abstract type $name end"]
  isprimitivetype(inside) && return ["primitive type $name $(8sizeof(inside)) end"]
  node = inside <: Union{SemanticUI,GeometricUI}
  fields = ["  " * (isconst(inside, i) && ismutabletype(inside) ? "const " : "") * "$(fieldname(inside, i))::" * words(fieldtype(inside, i))
            for i in 1:fieldcount(inside) if !(node && fieldname(inside, i) in NODE_LINKS)]
  [(ismutabletype(inside) ? "mutable struct " : "struct ") * name, fields..., "end"]
end

"""
What shows of the type `T` in the open box of an outcome, and under its name
in a module's table: the type as code declares it, with its fields, and its
documentation. `home` is the module of the code that has the type, as it is
for `type_text`.
"""
Detail(T::Type; home=(try parentmodule(T) catch; nothing end)) = begin
  lines = ["```julia", declaration(T; home)..., "```"]
  doc = try doc_lines(parentmodule(T), nameof(T)) catch; String[] end
  isempty(doc) || append!(lines, ["", doc...])
  Detail(T, lines, NTuple{3,String}[], "")
end

"What the open box of `v` shows, or what shows under its row in a module's table. `home` is the module that the value is in, which a type is written for."
detail_of(v, home) = v isa Type ? Detail(v; home) : Detail(v)

"What shows of any other value under its name in a module's table: its type, and the value as Julia writes it"
Detail(v) = begin
  text = try clipped(value_text(v)) catch; "" end
  Detail(v, ["`$(typeof(v))`", "", "```julia", String.(split(text, '\n'))..., "```"], NTuple{3,String}[], "")
end

"Show the value of row `i` of the table of the module's box `d` under the row, or hide it when it shows already"
open_row!(d::OutcomeBody, i::Int) = begin
  t = d.detail
  if t.open == i
    t.open, t.inner = 0, nothing
    return
  end
  inner = try
    Base.invokelatest(detail_of, Base.invokelatest(getglobal, t.of, Symbol(t.rows[i][1])), t.of)
  catch err
    Detail(nothing, [sprint(showerror, err)], NTuple{3,String}[], "")
  end
  inner.search = nothing   # the table under a row has no search of its own
  t.open, t.inner = i, inner
end

"Lay out the documentation of `t` for a box that's `wide`, if it isn't laid out for that yet. Its text is a little smaller than the page's."
page!(e, t::Detail, wide) = begin
  key = (wide, e.zoom, look_key(e), e.font, e.weight)
  (t.key == key || isempty(t.lines)) && return t
  kinds = classify(t.lines)
  zoom = e.zoom
  e.zoom = zoom * PAGE_ZOOM
  # -1 says that a line isn't one of the document's, so its inline code isn't run
  flows = try
    [laid(e, t.lines[i], kinds[i], false, -1, wide) for i in eachindex(t.lines)]
  finally
    e.zoom = zoom
  end
  tops = accumulate(+, map(tall, flows)) .- map(tall, flows)
  t.page = FilePage(flows, tops, sum(tall, flows, init=0px), false, t.scroll)
  t.key = key
  t
end

"A name as the table puts it in order: without its capitals, and without the @ or the _ that it starts with"
sort_words(text) = lowercase(lstrip(text, ('@', '_')))

"True while the table of `t` shows fewer rows than it has: the search field has words, or a column keeps only some rows"
narrowed(t::Detail) = t.sought !== nothing && (!isempty(t.sought[1]) || !isempty(t.sought[3]) || !isempty(t.sought[4]))

"""
The rows that the table of `t` shows, in the order that it shows them. They
are the rows whose names have the search field's words, that have each
column's words in that column, and whose kind is one that shows. They're in
the order of the column that's chosen. With none chosen, they're in the order
of the names, and while the search field has words, the names that start with
the words come first.
"""
sought!(t::Detail) = begin
  words = t.search === nothing ? "" : String(lowercase(strip(t.search.text)))
  key = (words, t.sort, copy(t.filters), copy(t.only))
  key == t.sought && return t.found
  # A new search starts at the top of what it finds
  t.sought === nothing || (t.scroll.offset = 0px)
  keep = [i for (i, row) in enumerate(t.rows) if
            occursin(words, sort_words(row[1])) &&
            all(((column, has),) -> occursin(lowercase(has), lowercase(row[column])), t.filters) &&
            (isempty(t.only) || row[2] in t.only)]
  if t.sort !== nothing
    column, way = t.sort
    sort!(keep, by=i -> sort_words(t.rows[i][column]), rev=way == :desc)
  elseif !isempty(words)
    starts(i) = startswith(sort_words(t.rows[i][1]), words)
    keep = [filter(starts, keep); filter(!starts, keep)]
  end
  t.sought, t.found = key, keep
  keep
end

"""
One row of the table of `t`, in a box that's `wide`. `open` says whether the
row's value shows under it, for a row that a click opens: such a row starts
with an arrow. `lit` is true while the mouse is over it.
"""
detail_row(e, t::Detail, row::NTuple{3,String}, wide; open=nothing, lit=false) = begin
  code = Face(codefont(), codestyle(), body(e).size * 0.72, colours.ink, false)
  cell = measure(code, "0")
  small = 11px
  short(text, room) = (n = max(1, floor(Int, num(room) / num(cell))); length(text) > n ? first(text, n - 1) * "…" : text)
  plain = Face(SANS, "", small, colours.dim, false)
  # Words that are too long for their column stop with an …
  fit(text, room) = begin
    while measure(plain, text) > room && length(text) > 1
      text = first(text, max(1, floor(Int, (length(text) - 1) * num(room) / num(measure(plain, text))) - 1)) * "…"
    end
    text
  end
  words(text, room) = Row(fixed(room), height(DETAIL_ROW), Alignment.Center, clip=true, spared(fit(text, room), plain)...)
  # As tall as the row, so that the tails of letters like g and y aren't cut off
  parts(text, room) = Row(fixed(room), height(DETAIL_ROW), Alignment.Center, clip=true,
    [part for tok in tokens(short(text, room), "julia") for part in coloured(tok, code)]...)
  if isempty(row[2])
    # What a method takes, or the name of a field, has most of the row. Where the method is, or the field's type, has the rest.
    place = min(measure(plain, row[3]) + 4px, wide * 0.4)
    # The space at each end keeps the words in from the edge of the colour that the row has under the mouse
    return Row(width(grow=grow), height(DETAIL_ROW), Alignment.Center, child_gap=10px, padding(6px, 0px), radius(4px),
               background(lit ? colours.hover : clear), parts(row[1], wide - place - 22px), words(row[3], place))
  end
  arrow = open === nothing ? 0px : 16px
  name, kind = wide * 0.4, 96px
  Row(width(grow=grow), height(DETAIL_ROW), Alignment.Center, child_gap=10px, radius(4px), background(lit ? colours.hover : clear),
      (open === nothing ? () : (Box(fixed(arrow - 10px), Icon(open ? "chevron-down" : "chevron-right", size=9px, color=colours.dim)),))...,
      parts(row[1], name - arrow), words(row[2], kind),
      # A value is code, and the words about anything else are a sentence
      (row[2] == "value" ? parts : words)(row[3], wide - name - kind - 20px))
end

"The node of row `i` of the table of the module's box `d`"
name_row!(d::OutcomeBody, i::Int) = get!(() -> own!(d, NameRow(of=d, i=i)), d.detail.parts, i)

describe(r::NameRow) = (t = r.of.detail; detail_row(editor(r), t, t.rows[r.i], t.wide; open=t.open == r.i, lit=ishovered(r)))
cursor(::NameRow) = :hand
onkey(r::NameRow, ::KeyPress{Keys.mouse_left}) = (open_row!(r.of, r.i); handled)
onmouse(::NameRow, ::MouseMove) = handled
onscroll(r::NameRow, ev::MouseScroll) = onscroll(r.of, ev)

"""
A row of a function's table of methods. A click on it shows the method's code:
its file in a window beside this one, as ⌘⌥ shows the code of a part. A method
that the page itself makes is a line of this page, so the caret goes there.
A method of Julia's own shows the file of Julia's code that has it. A method
whose file isn't on this Mac has no code to show, so the mouse over it doesn't
light it.
"""
@def mutable struct MethodRow <: SemanticUI
  of::Any = nothing       # the OutcomeBody that the table is in
  detail::Any = nothing   # the Detail of the function, which can be the Detail under a row of a module's table
  i::Int = 0              # which row of the table
  place::Any = nothing    # the method's file on this Mac and its line, or nothing
end

"The node of row `i` of the table of methods `t`, which is in the box `d`"
method_row!(d::OutcomeBody, t::Detail, i::Int) =
  get!(() -> own!(d, MethodRow(of=d, detail=t, i=i, place=code_place(t.methods[i]))), t.parts, i)

"The row `i` of the table of `t`, in the box `d`: a node that takes clicks for a module's name or a function's method, or else the row as it looks"
table_row(e, d::OutcomeBody, t::Detail, i::Int, wide) =
  t.what == "name" && t === d.detail ? name_row!(d, i) :
  t.what == "method" && i <= length(t.methods) ? method_row!(d, t, i) : detail_row(e, t, t.rows[i], wide)

describe(r::MethodRow) = (t = r.detail; detail_row(editor(r), t, t.rows[r.i], t.wide; lit=r.place !== nothing && ishovered(r)))
cursor(r::MethodRow) = r.place === nothing ? :arrow : :hand
onkey(r::MethodRow, ::KeyPress{Keys.mouse_left}) = (r.place === nothing || show_method!(editor(r), r.detail.methods[r.i]); handled)
onmouse(::MethodRow, ::MouseMove) = handled
onscroll(r::MethodRow, ev::MouseScroll) = onscroll(r.of, ev)

"""
The lines of `page` that are between `from` and `to` under its top, with room
for the lines that aren't: the part of some documentation that's in view.
"""
page_part(e, page, from, to) = begin
  (to <= 0px || from >= page.tall) && return (spacer(page.tall),)
  lo = something(findlast(<=(from), page.tops), 1)
  hi = something(findfirst(>(to), page.tops), length(page.tops) + 1) - 1
  (spacer(page.tops[lo]), [describe(e, Item(0, 0, 0px, tall(f), f), f) for f in page.flows[lo:hi]]...,
   spacer(page.tall - page.tops[hi] - tall(page.flows[hi])))
end

"""
The rows of a table of `n` rows that are between `from` and `to` under its
top, with room for the rows that aren't. `row(k)` makes row `k`.
"""
rows_part(row, n::Int, from, to) = begin
  lo = clamp(floor(Int, num(from) / num(DETAIL_ROW)) + 1, 1, n + 1)
  hi = clamp(ceil(Int, num(to) / num(DETAIL_ROW)), lo - 1, n)
  (spacer(DETAIL_ROW * (lo - 1)), [row(k) for k in lo:hi]..., spacer(DETAIL_ROW * (n - hi)))
end

"The words over the table of `t`: how many rows it has, or how many of them `n` rows are"
count_words(t::Detail, n::Int=length(t.rows)) =
  n < length(t.rows) || narrowed(t) ? "$n of $(length(t.rows)) $(t.what)s" : n == 1 ? "1 $(t.what)" : "$n $(t.what)s"

"The words over a table, in a row of their own"
table_head(words) = Row(width(grow=grow), height(DETAIL_HEAD), Alignment.Center, label(words, 12px, color=colours.dim, weight="Semibold"))

"How tall the documentation of `t` is, with the space under it"
doc_tall(t::Detail) = t.page === nothing ? 0px : t.page.tall + TEXT_PAD

"How tall what shows under an open row is: the documentation of the row's value, and the table of its methods or its fields"
inner_tall(t::Detail) = TEXT_PAD + doc_tall(t) + (isempty(t.rows) ? 0px : DETAIL_HEAD + DETAIL_ROW * length(t.rows))

const INNER_X = 22px   # how far in from the table what shows under an open row is

# --- the headings of a module's table of names ---------------------------------------------

const NAMES_KEY = :names_column
const NAME_COLUMNS = ("Name", "Kind", "About")

"The heading of a column of a module's table of names. A click on it opens the column's menu."
@def mutable struct NameHead <: SemanticUI
  of::Any = nothing   # the OutcomeBody that the table is in
  column::Int = 1
end
"The menu of a column of a module's table: its two orders, and what narrows it"
@def mutable struct NameMenu <: SemanticUI
  of::Any = nothing
  column::Int = 1
end
"One of the two orders in the menu of a column"
@def mutable struct NameSort <: SemanticUI
  of::Any = nothing
  way::Symbol = :asc
end
"A kind of name in the menu of the Kind column. A click on it shows that kind, or stops showing it."
@def mutable struct KindRow <: SemanticUI
  of::Any = nothing
  kind::String = ""
end

"Keep only the rows that have `words` in the column `column`. No words takes that away."
keep!(t::Detail, column::Int, words) = begin
  words = String(strip(words))
  isempty(words) ? delete!(t.filters, column) : (t.filters[column] = words)
  t
end

"The kinds of name that the table of `t` has, in the order of the alphabet"
kinds_of(t::Detail) = sort!(unique(row[2] for row in t.rows))

"A node of the headings or of the menu of the table that's in the box `d`, kept between frames"
head_part!(make, d::OutcomeBody, key) = get!(() -> own!(d, make()), d.detail.heads, key)

"The headings over a module's table of names, in a row that's `wide`, with `count` at its right end"
names_head(d::OutcomeBody, wide, count) = begin
  name, kind = wide * 0.4, 96px
  head(column) = head_part!(() -> NameHead(of=d, column=column), d, (:head, column))
  # Each heading is over its column of the rows under it, which start with an arrow
  Row(width(grow=grow), height(DETAIL_HEAD), Alignment.Center, child_gap=10px,
      Box(fixed(6px)), Row(fixed(name - 16px), Alignment.Center, head(1)), Row(fixed(kind), Alignment.Center, head(2)),
      Row(fixed(wide - name - kind - 20px), Alignment.Center, head(3), Box(width(grow=grow)), Box(label(count, 11px, color=colours.dim))))
end

describe(h::NameHead) = begin
  t = h.of.detail
  way = t.sort !== nothing && t.sort[1] == h.column ? t.sort[2] : nothing
  lit = ishovered(h) || t.asking == h.column
  fewer = haskey(t.filters, h.column) || (h.column == 2 && !isempty(t.only))
  colour = fewer ? colours.accent : lit || way !== nothing ? colours.ink : colours.dim
  # The arrow of the order that the column has. With none, the mouse over the heading shows that it opens.
  mark = way !== nothing ? (Icon(way == :asc ? "chevron-up" : "chevron-down", size=9px, color=colours.ink),) :
         lit ? (Icon("chevron-down", size=9px, color=colours.faint),) : ()
  Row(height(20px), child_gap=4px, Alignment.Center, Box(label(NAME_COLUMNS[h.column], 11px, color=colour, weight="Semibold")), mark...)
end

cursor(::NameHead) = :hand
onmouse(::NameHead, ::MouseMove) = handled
onscroll(h::NameHead, ev::MouseScroll) = onscroll(h.of, ev)

onkey(h::NameHead, ev::KeyPress{Keys.mouse_left}) = begin
  d = h.of
  t = d.detail
  t.asking, t.was = h.column, get(t.filters, h.column, "")
  # The menu's field starts with what the column keeps, which esc puts back
  t.field === nothing && (t.field = own!(d, TextInput(placeholder="Contains…", font_family=SANS, font_size=13px,
                                                      look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))))
  t.field.text = t.was
  t.field.cursor = t.field.anchor = length(t.was)
  menu = head_part!(() -> NameMenu(of=d), d, :menu)
  menu.column = h.column
  # A click outside the menu closes it and keeps what's typed
  popup!(ev.window, menu, anchor=h, placement=:bottom, gap=6px, width=210px, key=NAMES_KEY,
         onclose=() -> (t.asking = 0; focus(editor(d))), theme=component_theme(editor(d).zoom))
  h.column == 2 || focus(t.field)
  handled
end

"Close the menu of the table that's in the box `d`, and give the keyboard back to the page"
close_menu!(d::OutcomeBody) = begin
  d.detail.asking = 0
  w = window_of(d)
  w === nothing || close_popup!(w, NAMES_KEY)
  focus(editor(d))
  handled
end

describe(m::NameMenu) = begin
  d, c = m.of, found_colours()
  t = d.detail
  section(words) = Row(width(grow=grow), height(22px), padding(8px, 0px), Alignment.Center, label(words, 10px, color=c.dim, weight="Semibold"))
  order(way) = head_part!(() -> NameSort(of=d, way=way), d, (:sort, way))
  fewer = m.column == 2 ?
    (section("SHOW"), [head_part!(() -> KindRow(of=d, kind=kind), d, (:kind, kind)) for kind in kinds_of(t)]...) :
    (section("FILTER FOR"),
     Box(width(grow=grow), padding(4px, 2px),
       Box(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), border(1px, :solid, c.line), background(c.frame), t.field)))
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Names menu",
    Column(width(grow=grow), Alignment.Start,
      section("SORT"), order(:asc), order(:desc),
      Box(width(grow=grow), height(13px), Alignment.Center, Box(width(grow=grow), height(1px), background(c.rule))),
      fewer...))
end

# The menu sees a key before its text field does. Return keeps what the field holds, and esc puts back what it held before.
onkey(m::NameMenu, ev::KeyPress{Keys.enter}) = unmodified(ev) ? close_menu!(m.of) : nothing
onkey(m::NameMenu, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  t = m.of.detail
  m.column == 2 || keep!(t, m.column, t.was)
  close_menu!(m.of)
end

describe(r::NameSort) = begin
  t, c = r.of.detail, found_colours()
  on = t.sort == (t.asking, r.way)
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(on || ishovered(r) ? c.pick : c.frame),
    Icon(r.way == :asc ? "chevron-up" : "chevron-down", size=10px, color=on ? c.ink : c.dim),
    label(r.way == :asc ? "A–Z" : "Z–A", 13px, color=on ? c.ink : c.dim, weight=on ? "Semibold" : ""))
end

cursor(::NameSort) = :hand
onmouse(::NameSort, ::MouseMove) = handled
# A click on the order that the table has takes it away
onkey(r::NameSort, ::KeyPress{Keys.mouse_left}) = (t = r.of.detail; t.sort = t.sort == (t.asking, r.way) ? nothing : (t.asking, r.way); handled)

describe(r::KindRow) = begin
  t, c = r.of.detail, found_colours()
  on = r.kind in t.only
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(ishovered(r) ? c.pick : c.frame),
    Box(fixed(10px), (on ? (Icon("check", size=10px, color=c.ink),) : ())...),
    label(r.kind, 13px, color=on || isempty(t.only) ? c.ink : c.dim, weight=on ? "Semibold" : ""))
end

cursor(::KindRow) = :hand
onmouse(::KindRow, ::MouseMove) = handled
# A click shows that kind, or stops showing it. With every kind chosen, or none, every kind shows.
onkey(r::KindRow, ::KeyPress{Keys.mouse_left}) = begin
  t = r.of.detail
  r.kind in t.only ? delete!(t.only, r.kind) : push!(t.only, r.kind)
  length(t.only) == length(kinds_of(t)) && empty!(t.only)
  handled
end

"What shows under an open row of the box `d`, `wide` across: the part of it between `from` and `to` under its top, with room for the rest"
inner_view(e, d::OutcomeBody, t::Detail, wide, from, to) = begin
  y = TEXT_PAD
  doc = t.page === nothing ? () : (page_part(e, t.page, from - y, to - y)..., spacer(TEXT_PAD))
  y += doc_tall(t) + DETAIL_HEAD
  table = isempty(t.rows) ? () :
    (table_head(count_words(t)), rows_part(j -> table_row(e, d, t, j, wide), length(t.rows), from - y, to - y)...)
  # A line down its left side joins it to its row
  Column(width(grow=grow), Alignment.Start, padding(0px, 0px, 0px, INNER_X - 2px), border(2px, :solid, colours.line)[:left],
         spacer(TEXT_PAD), doc..., table...)
end

"""
What the open box of a function or a module shows: the search field of a
module, and under it the documentation and the table, which the wheel moves
through. Only the lines and the rows in view are made.
"""
detail_view(e, d::OutcomeBody) = begin
  d.detail === nothing && (d.detail = detail_of(d.of.subject, workspace(e)))
  t = d.detail
  # A type has no table, so it has no words over one
  table = !isempty(t.what)
  head_h = table ? DETAIL_HEAD : 0px
  t.search === nothing || own!(d, t.search)
  wide = t.wide = detail_wide(e) - 2DETAIL_PAD
  page!(e, t, wide)
  # What the field of a heading's menu holds is what its column keeps, as it's typed
  t.asking in (1, 3) && t.field !== nothing && keep!(t, t.asking, t.field.text)
  found = sought!(t)
  n = length(found)
  # While the table shows fewer names than it has, the box shows only the names
  page = narrowed(t) ? nothing : t.page
  above = page === nothing ? 0px : page.tall + TEXT_PAD
  # The open row, as its place among the rows that were found. Its value shows under it.
  k = t.inner === nothing ? nothing : findfirst(==(t.open), found)
  inner = k === nothing ? nothing : t.inner
  inner === nothing || (page!(e, inner, wide - INNER_X); inner.wide = wide - INNER_X)
  under = inner === nothing ? 0px : inner_tall(inner)
  k = something(k, n)
  total = TEXT_PAD + above + head_h + DETAIL_ROW * n + under + TEXT_PAD
  high = min(total, DETAIL_H)
  from, to = t.scroll.offset, t.scroll.offset + high
  # Each part starts `y` under the top of all that the wheel moves through
  y = TEXT_PAD
  doc = page === nothing ? () : (page_part(e, page, from - y, to - y)..., spacer(TEXT_PAD))
  y += above + head_h
  row(j) = table_row(e, d, t, found[j], wide)
  before = rows_part(row, k, from - y, to - y)
  y += DETAIL_ROW * k
  section = inner === nothing ? () : (inner_view(e, d, inner, wide - INNER_X, from - y, to - y),)
  y += under
  after = rows_part(j -> row(k + j), n - k, from - y, to - y)
  head = !table ? () : t.what == "name" ? (names_head(d, wide, count_words(t, n)),) : (table_head(count_words(t, n)),)
  inside = Column(width(grow=grow), Alignment.Start, padding(DETAIL_PAD, 0px),
    spacer(TEXT_PAD), doc..., head..., before..., section..., after..., spacer(TEXT_PAD))
  field = t.search === nothing ? () :
    (Row(width(grow=grow), height(SEARCH_H), Alignment.Center, padding(DETAIL_PAD, 0px), child_gap=8px,
         border(1px, :solid, colours.line)[:bottom],
         Icon("search", size=13px, color=colours.dim), Box(width(grow=grow), height(SEARCH_H - 12px), t.search)),)
  Column(fixed(detail_wide(e)), Alignment.Start, d.corners, background(colours.float), border(1px, :solid, colours.line), lifted,
         clip=true, name="Outcome detail",
         field..., Box(width(grow=grow), height(high), reuse!(t.scroll, inside)))
end
