# Where a name is defined, giving a name another name, and where a name is used
#
# In Julia code, a click on a name with ⌘ held goes to where the name is
# defined, and so does the command Go To Definition, for the name at the caret.
#
#   - A name that the page's own code makes is on the page. A name of the
#     function that the click is in comes before a name of the whole file. A
#     function with several methods has several places: the click goes to the
#     first, and a click on a place that it went to goes to the next.
#   - A name from another file that Ladder loaded, like a function of UI.jl,
#     or of Julia's own code, like `length`, shows in a window beside this
#     one, as the code of a thing does: see "the code of a thing". A method of
#     the module that made the function comes first. A name after a dot, like
#     `arrange` in `Boards.arrange`, is looked for in the module before the dot.
#
# The command Go To lists the places of a file of code, as it lists the
# headings of a page: each section that a comment like `# --- name ---` starts,
# and each name that the code makes at its top, with what its line says of it.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" focus
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "./markdown" Kind spans words front_matter
@use "./markdown" COMMENT
@use "./highlight" tokens
@use "./sheet" uses shown
@use "./changes" => Diffs
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./additions" exports...
@use "./folder_page" exports...
@use "./sketch_view" exports...
@use "./sheet_view" exports...
@use "./live_view" exports...
@use "./code_names" exports...
@use "./showed_before" note_place!
@use "./code_thing" code_place settled_line

export SECTION, signature, code_places, definition, definition!, go_to_place!, go_to_definition!,
       NameAt, own_name, name_uses, rename_in_code!, rename_elsewhere!, rename_tick!, Use,
       row_words, name_columns, uses_elsewhere, uses_of, whole_name, find_uses!, HeadingLine,
       go_to!, word_count, CodeNavState, text_lines

"The comment that starts a section of a file of code: three dashes or more, the section's name, and more dashes"
const SECTION = r"^#+ -{3,}\s+(.+?)\s+-{3,}\s*$"

"""
What the line `text`, which makes the name of `made`, says of it for Go To: a
function with the values that it takes, like `tall(f::Flow)`, or only the name.
"""
signature(text::AbstractString, made::Bound) = begin
  chars = collect(text)
  from = made.at[2] + 1
  stop = from + length(made.name) - 1
  (stop < length(chars) && chars[stop+1] == '(') || return made.name
  depth = 0
  for k in stop+1:length(chars)
    chars[k] == '(' && (depth += 1)
    chars[k] == ')' && (depth -= 1; depth == 0 && return String(chars[from:k]))
  end
  String(chars[from:end])   # the values go on to the next line
end

"The places in a file of code that Go To offers, from the first line to the last: see \"where a name is defined\""
code_places(e) = begin
  b = e.buf
  out = HeadingLine[]
  for (i, line) in enumerate(b.lines)
    startswith(line, '#') || continue
    m = match(SECTION, line)
    m === nothing || push!(out, HeadingLine(i, String(m[1]), "section"))
  end
  for made in page_bounds(e)
    (made.span === nothing && 1 <= made.at[1] <= length(b.lines)) || continue
    push!(out, HeadingLine(made.at[1], signature(b.lines[made.at[1]], made), made.call ? "" : made.words))
  end
  sort!(unique(h -> (h.line, h.words), out), by=h -> h.line)
end

"""
The name that's written at the place `at` of the page's Julia code: the name,
the column where it starts, and the names before it that dots join it to, like
`Boards` for `arrange` in `Boards.arrange`. Nothing when the place has no
name: it's not in Julia code, or it's in a string, a comment or a word of the
language.
"""
name_at(b::Buffer, at::Pos) = begin
  i, col = at
  1 <= i <= length(b.lines) || return nothing
  line = kinds(b)[i]
  (line.kind == Kind.code && !no_names(line.lang) && shared_lang(line.lang) == "julia") || return nothing
  chars = collect(b.lines[i])
  part(c) = isnamechar(c) || c == '!'
  start = stop = clamp(col, 0, length(chars))
  while start > 0 && part(chars[start]); start -= 1 end
  while stop < length(chars) && part(chars[stop+1]); stop += 1 end
  (stop > start && (isletter(chars[start+1]) || chars[start+1] == '_')) || return nothing
  for t in tokens(b.lines[i], "julia")
    t.col <= start < t.col + length(t.text) && t.kind in (:string, :comment, :keyword, :number) && return nothing
  end
  name = String(chars[start+1:stop])
  # The names before it, each with a dot after it
  owners, k = String[], start
  while k > 1 && chars[k] == '.'
    j = k - 1
    while j > 0 && isnamechar(chars[j]); j -= 1 end
    j == k - 1 && break
    pushfirst!(owners, String(chars[j+1:k-1]))
    k = j
  end
  # The @ of a macro is part of its name
  isempty(owners) && start > 0 && chars[start] == '@' && ((name, start) = ("@" * name, start - 1))
  (name=name, col=start, owners=owners)
end

"""
Where the name at the place `at` of the page is defined: a place `(line,
column)` of the page, or a method of a function that another file defines, or
nothing. See "where a name is defined".
"""
definition(e, at::Pos) = begin
  b = e.buf
  found = name_at(b, at)
  found === nothing && return nothing
  i = at[1]
  if isempty(found.owners)
    # A line that brings a name in from another file, like `@use "./walls" Wall`, doesn't define it
    brings(m) = m.span === nothing && occursin(r"^\s*(@use|using|import)\b", b.lines[m.at[1]])
    made = sort!([m for m in page_bounds(e) if m.name == found.name && inreach(m, i) && !brings(m)], by=m -> m.at)
    near = filter(m -> m.span !== nothing, made)
    # A name of the function that the click is in: where it was last made, at the click or before it
    if !isempty(near)
      k = findlast(m -> m.at <= (i, found.col), near)
      return near[something(k, 1)].at
    end
    if !isempty(made)
      # A click on one of a function's methods goes to the next of them
      k = findfirst(m -> m.at == (i, found.col), made)
      return made[k === nothing ? 1 : mod1(k + 1, length(made))].at
    end
  end
  home = something(loaded_module(page_key(b.path)), scope(e))
  value = named_value(home, join([found.owners; found.name], '.'))
  (value isa Function || value isa Type) || return nothing
  ms = try collect(Base.invokelatest(methods, value)) catch; return nothing end
  placed = [(m, p) for m in ms for p in (code_place(m),) if p !== nothing]
  isempty(placed) && return nothing
  # A method of the module that made the function comes first, so `length` goes to Base's own and not to a package's.
  # Then a method in a file that Ladder loaded comes before a method of Julia's own.
  own = try parentmodule(value) catch; nothing end
  first(first(sort(placed, by=((m, p),) -> (m.module !== own, !haskey(Kip.modules, p[1]), p[1], m.line))))
end

"""
Go to where the name at the place `at` of the page is defined. At a place
where the page's code makes the name, it lists the places that use it: see
"where a name is used". True when it has a place to go to.
"""
definition!(e, at::Pos) = begin
  n = own_name(e, at)
  if n !== nothing && any(m -> m.name == n.name && m.at == (n.line, n.col), page_bounds(e))
    e.buf.caret = e.buf.anchor = (n.line, n.col)
    open_palette!(e, :find_uses)
    return true
  end
  place = definition(e, at)
  place === nothing && return false
  place isa Method && return show_method!(e, place)
  place == at || go_to_place!(e, place)
  true
end

"""
Put the caret at `place` of the page, and the place near the top of the
window, with a few lines over it. ⌘⌥← comes back to where the caret was.
"""
go_to_place!(e, place) = begin
  note_place!(e)
  e.buf.caret = e.buf.anchor = place
  focus(e)
  touch!(e)
  hold!(e, max(place[1] - 3, 1), 24px - PAGE_TOP)
  true
end

"""
Show the code of the method `m`: its file in a window beside the window of
`e`, or its line of this window when the page that shows has it. False when
this Mac doesn't have its file.
"""
show_method!(e, m::Method) = begin
  here = code_place(m)
  here === nothing && return false
  here[1] == page_key(e.buf.path) || return (show_code!(e, m); true)
  place = (settled_line(m, e.buf.lines, here[2]), 0)
  place == e.buf.caret || go_to_place!(e, place)
  true
end

"Go to where the name at the caret is defined: a function, a type or a value of the page's Julia code, or of a file that Ladder loaded"
go_to_definition!(e) = definition!(e, e.buf.caret) || error("Nothing here says where the name at the caret is defined.")
add_command!(go_to_definition!, title="Go to where the name at the caret is defined", kind=:look)

# --- give a name another name ---------------------------------------------------------------
#
# The command Rename In Code takes a name of the page's own Julia code and a
# new name, and writes the new one wherever the old one means the same thing:
# for a name made in a function, in that function, and for a name of the whole
# page or file, in all of its Julia code, but not in a function that makes a
# name of its own with those letters. A name after a dot, and words in a
# string or a comment, stay as they are. It's one change, which ⌘Z takes back.
# The name starts as the one at the caret, and a click on another chooses it,
# as the node of Ask Agent does.

"A name of the page's own Julia code where it's written: its line, and the column where it starts"
struct NameAt
  name::String
  line::Int
  col::Int
end
worded(n::NameAt) = n.name
sidenote(n::NameAt) = "line $(n.line)"

"The name at the place `at` of the page, when the page's own code makes it, or nothing"
own_name(e, at) = begin
  found = name_at(e.buf, at)
  (found === nothing || !isempty(found.owners)) && return nothing
  Base.invokelatest(definition, e, (at[1], found.col)) isa Tuple || return nothing
  NameAt(found.name, at[1], found.col)
end

"The names that the page's Julia code makes, for the palette's list: the one at the caret, and each that all of the code can use, where it's made"
choices_for(::Type{NameAt}, e) = begin
  out = NameAt[]
  here = own_name(e, e.buf.caret)
  here === nothing || push!(out, here)
  for m in page_bounds(e)
    m.span === nothing && !any(n -> n.name == m.name, out) && push!(out, NameAt(m.name, m.at[1], m.at[2]))
  end
  out
end
chip_start(::Type{NameAt}, e) = own_name(e, e.buf.caret)
chip_click(::Type{NameAt}, e, w) = own_name(e, locate(e, w.mouse))

"Where the name `n` is in the window of `e`, for a line round it"
shown_at(e, n::NameAt) = begin
  1 <= n.line <= length(e.layout) || return nothing
  it = item(e, n.line)
  it.content isa Flow || return nothing
  f = it.content
  k, x1 = spot(f, n.col)
  _, x2 = spot(f, n.col + length(n.name))
  (left=e.origin[1] + x1 - 2px, top=e.origin[2] + it.top + line_top(f, k), width=x2 - x1 + 4px, height=f.lines[k].high)
end

"""
The places where the name `n` means what it means where it's written: each as
its line and the column where it starts. A name that a function makes is
looked for in that function. A name of the whole page is looked for in all of
its Julia code, but not in a function that makes a name of its own with
those letters.
"""
name_uses(e, n::NameAt) = begin
  b = e.buf
  place = Base.invokelatest(definition, e, (n.line, n.col))
  place isa Tuple || return Tuple{Int,Int}[]
  made = filter(m -> m.name == n.name, page_bounds(e))
  k = findfirst(m -> m.at == place, made)
  span = k === nothing ? nothing : made[k].span
  # A function with a name of its own with those letters keeps it
  others = [m.span for m in made if m.span !== nothing && m.span != span]
  rows = span === nothing ? (1:length(b.lines)) : span
  ks = kinds(b)
  pattern = Regex("(?<![\\w!@.])\\Q$(n.name)\\E(?![\\w!])")
  out = Tuple{Int,Int}[]
  for i in rows
    (1 <= i <= length(ks) && ks[i].kind == Kind.code && !no_names(ks[i].lang) && shared_lang(ks[i].lang) == "julia") || continue
    span === nothing && any(s -> i in s, others) && continue
    line = b.lines[i]
    for m in eachmatch(pattern, line)
      col = length(line, 1, prevind(line, m.offset))
      # The name there is the same name, and not part of a string, a comment or a name after a dot
      found = name_at(b, (i, col + 1))
      found !== nothing && found.name == n.name && found.col == col && isempty(found.owners) && push!(out, (i, col))
    end
  end
  out
end

"""
Give the name `name` of the page's Julia code the name `new_name`, wherever it
means the same thing. ⌘Z takes it back. See "give a name another name".
"""
rename_in_code!(e, name::NameAt, new_name::String) = begin
  new_name = String(strip(new_name))
  Base.isidentifier(new_name) || error("Julia doesn't take $(repr(new_name)) as a name.")
  uses = name_uses(e, name)
  isempty(uses) && error("$(name.name) isn't a name that this page's code makes.")
  b = e.buf
  lines = copy(b.lines)
  # From the end of each line, so that the columns before a change stay where they are
  for (i, col) in sort(uses, rev=true)
    chars = collect(lines[i])
    lines[i] = String([chars[1:col]; collect(new_name); chars[col+length(name.name)+1:end]])
  end
  lo, hi = extrema(first.(uses))
  v = b.version
  whole = whole_name(e, name)
  edit!(b, (lo, 0), (hi, length(b.lines[hi])), join(lines[lo:hi], "\n"))
  # A name of a whole file of Julia code changes in the other Julia files of its git folder too. ⌘Z takes those back as well.
  was = whole ? rename_elsewhere!(e, name, new_name) : Dict{String,String}()
  isempty(was) || (state_of(e, CodeNavState).renamed = (before=v, after=b.version, was=was, now=Dict{String,String}(f => read(f, String) for f in keys(was)), seen=b.version))
  nothing
end
add_command!(rename_in_code!, title="Give a name of the page's Julia code another name, wherever it means the same thing", kind=:edit)

"""
Give the name `n` the name `new_name` in the other Julia files of the git
folder of the window's file, a name of the whole file, at each place that
`uses_elsewhere` finds. It gives the text that each file that changed had
before.
"""
rename_elsewhere!(e, n::NameAt, new_name::AbstractString) = begin
  was = Dict{String,String}()
  file = isempty(e.buf.path) ? "" : page_key(e.buf.path)
  endswith(file, ".jl") || return was
  found = uses_elsewhere(n.name, file; most=typemax(Int))
  for path in unique(u.file for u in found)
    text = read(path, String)
    lines = text_lines(text)
    for u in sort(filter(u -> u.file == path, found), by=u -> (u.line, u.col), rev=true)
      chars = collect(lines[u.line])
      lines[u.line] = String([chars[1:u.col]; collect(new_name); chars[u.col+length(n.name)+1:end]])
    end
    new = join(lines, "\n")
    new == text && continue
    was[path] = text
    write(path, new)
  end
  was
end

"""
In each frame: when ⌘Z took back a rename that changed other files too, put
those files back as they were, and when ⌘⇧Z made it again, change them again.
A file that changed since stays as it is.
"""
rename_tick!(e) = begin
  r = state_of(e, CodeNavState).renamed
  (r === nothing || r.seen == e.buf.version) && return nothing
  v = e.buf.version
  state_of(e, CodeNavState).renamed = (; r..., seen=v)
  from, to = v == r.before ? (r.now, r.was) : v == r.after ? (r.was, r.now) : (nothing, nothing)
  from === nothing && return nothing
  for (f, t) in to
    isfile(f) && read(f, String) == from[f] && write(f, t)
  end
  nothing
end
each_frame!(rename_tick!)

works_here(e, ::Val{:rename_in_code}) = !isempty(code_blocks(e))

# --- where a name is used ---
#
# The command Find Uses lists each place that uses the name at the caret, a
# name that the page's own Julia code makes. A name of a whole file of Julia
# code is looked for in the other Julia files of its git repository too, by
# itself or after the name of a module and a dot, as `K.share` is. ⌘-click on
# a name where the code makes it shows the same list. As the arrows go down
# the list, the window shows each place of its own file, with a line round
# the name, and Esc puts the window back. Return goes to the place, in a
# window beside for another file.

"A place that uses a name: the file, the line and the column where the name starts, the line's words, and where it is in words"
struct Use
  name::String
  file::String
  line::Int
  col::Int
  words::String
  note::String
end
worded(u::Use) = u.words

"What a window keeps of the names of its page's code, between frames: a rename that changed other files too, and the uses that were last found"
@def mutable struct CodeNavState
  # The page's version before the rename and after it, the text that each other file had before and has now, and
  # the version that `rename_tick!` last saw. Nothing when no rename changed another file.
  renamed::Union{Nothing,@NamedTuple{before::Int, after::Int, was::Dict{String,String}, now::Dict{String,String}, seen::Int}} = nothing
  found::Union{Nothing,Tuple{Tuple{Int,NameAt},Vector}} = nothing   # the page's version and the name that the uses were last found for, and the uses
end
sidenote(u::Use) = u.note

"A line of code as a row of a list shows it: without the spaces at its ends, and at most 90 characters"
row_words(line) = (s = strip(line); length(s) > 90 ? first(s, 89) * "…" : String(s))

"""
The columns where the name `name` starts in the line of Julia `line`, and not
in a string or a comment: by itself, or after the name of a module and a dot,
like `K.share`. After a name that starts with a small letter, like `t.share`,
it's a part of a value, and doesn't count.
"""
name_columns(line::AbstractString, name::AbstractString) = begin
  cols = Int[]
  chars = collect(line)
  skip = [(t.col, t.col + length(t.text)) for t in tokens(line, "julia") if t.kind in (:string, :comment)]
  for m in eachmatch(Regex("(?<![\\w!@])\\Q$name\\E(?![\\w!])"), line)
    col = length(line, 1, prevind(line, m.offset))
    any(((a, z),) -> a <= col < z, skip) && continue
    if col > 0 && chars[col] == '.'
      j = col - 1
      while j > 0 && isnamechar(chars[j]); j -= 1 end
      (j < col - 1 && isuppercase(chars[j+1])) || continue
    end
    push!(cols, col)
  end
  cols
end

"""
The places in the other Julia files of the git repository that holds `file`
that use the name `name`, at most `most` of them. `git grep` finds them, so a
file that git ignores isn't looked in.
"""
uses_elsewhere(name::AbstractString, file::AbstractString; most=500) = begin
  top = Diffs.repository(dirname(file))
  top === nothing && return Use[]
  out = IOBuffer()
  try
    run(pipeline(ignorestatus(`git -C $top grep -n -I --untracked -F -e $name -- '*.jl'`), stdout=out, stderr=devnull))
  catch
    return Use[]
  end
  found = Use[]
  for l in eachline(IOBuffer(take!(out)))
    m = match(r"^(.*?):(\d+):(.*)$", l)
    m === nothing && continue
    path = joinpath(top, m[1])
    page_key(path) == file && continue
    i = parse(Int, m[2])
    for col in name_columns(m[3], name)
      push!(found, Use(name, path, i, col, row_words(m[3]), "$(m[1]):$i"))
    end
    length(found) >= most && break
  end
  found
end

"""
Each place that uses the name `n`: in the page's own code, where it means
what it means where it's written, and for a name of the whole of a file of
Julia code, in the other Julia files of its repository.
"""
uses_of(e, n::NameAt) = begin
  b = e.buf
  file = isempty(b.path) ? "" : page_key(b.path)
  out = [Use(n.name, file, i, col, row_words(b.lines[i]), "line $i") for (i, col) in name_uses(e, n)]
  whole_name(e, n) && endswith(file, ".jl") && append!(out, uses_elsewhere(n.name, file))
  out
end

"True when the name `n` is a name of the whole page or file, and not one that a function makes"
whole_name(e, n::NameAt) = (place = Base.invokelatest(definition, e, (n.line, n.col)); place isa Tuple && !any(m -> m.at == place && m.span !== nothing, page_bounds(e)))

"The places that use the name at the caret, for the palette's list. They're found again only when the page or the name changed."
choices_for(::Type{Use}, e) = begin
  n = own_name(e, e.buf.caret)
  n === nothing && return Use[]
  key = (e.buf.version, n)
  was = state_of(e, CodeNavState).found
  was !== nothing && was[1] == key && return was[2]
  found = uses_of(e, n)
  state_of(e, CodeNavState).found = (key, found)
  found
end

"Where the name at the place `u` is in the window of `e`, while the window shows its file"
shown_at(e, u::Use) = !isempty(e.buf.path) && page_key(e.buf.path) == u.file ? shown_at(e, NameAt(u.name, u.line, u.col)) : nothing

"Find each place that uses the name at the caret, and go to the one that you choose: in this window, or in a window beside for another file"
find_uses!(e, place::Use) = begin
  if !isempty(e.buf.path) && page_key(e.buf.path) == place.file
    note_place!(e)   # ⌘⌥← comes back here
    show_line!(e, place.line)
    e.buf.caret = e.buf.anchor = (place.line, place.col)
    hold!(e, max(place.line - 3, 1), 24px - PAGE_TOP)
  else
    shown = show_place!(e, place.file, place.line)
    shown.buf.caret = shown.buf.anchor = (place.line, place.col)
  end
  nothing
end
add_command!(find_uses!, title="List each place that uses the name at the caret, and go to one", kind=:look)

works_here(e, ::Val{:find_uses}) = own_name(e, e.buf.caret) !== nothing

# As the arrows go down the list, the window scrolls to each place of its own file. The caret stays where it is.
look_of(e, ::Val{:find_uses}) = e.scroll.offset
put_look!(e, ::Val{:find_uses}, was) = (e.scroll.offset = was; hold!(e, nothing); nothing)
look!(e, ::Val{:find_uses}, f, _, u::Use) = (!isempty(e.buf.path) && page_key(e.buf.path) == u.file && hold!(e, max(u.line - 3, 1), 24px - PAGE_TOP); nothing)

"A heading of the page that shows, or a place of a file of code, for a command to take"
struct HeadingLine
  line::Int
  words::String
  what::String   # what a place of a file of code is: "section", "function", "struct". It's "" for a heading of a page.
end
HeadingLine(line, words) = HeadingLine(line, words, "")
choices_for(::Type{HeadingLine}, e) = begin
  b = e.buf
  b.view == :code && return code_places(e)
  ks = kinds(b)
  [HeadingLine(i, String(strip(rest(b.lines[i], ks[i].prefix)))) for i in eachindex(ks) if ks[i].kind == Kind.heading]
end
worded(h::HeadingLine) = h.words
sidenote(h::HeadingLine) = isempty(h.what) ? "line $(h.line)" : "$(h.what) · line $(h.line)"

# Two methods, so the chip takes a heading or a number, and the type of what's said chooses the method
"Put the caret on a heading of the page, or on a place of a file of code, and bring it in sight"
go_to!(e, heading::HeadingLine) = begin
  note_place!(e)   # ⌘⌥← comes back here
  show_line!(e, heading.line)
  # A place of a file of code goes near the top of the window, with a few lines over it
  e.buf.view == :code && hold!(e, max(heading.line - 3, 1), 24px - PAGE_TOP)
  nothing
end
"Put the caret on the line with the number `line`, and bring it in sight"
go_to!(e, line::Integer) = begin
  n = length(e.buf.lines)
  1 <= line <= n || error("The page has $n line$(n == 1 ? "" : "s").")
  note_place!(e)   # ⌘⌥← comes back here
  show_line!(e, Int(line))
  nothing
end
add_command!(go_to!, title="Go to a heading of the page, to a function or a section of a file of code, or to a line by its number", kind=:look)

# As the arrows go down Go To's list, the window scrolls to each place, with a line round it. The caret stays where it is.
look_of(e, ::Val{:go_to}) = e.scroll.offset
put_look!(e, ::Val{:go_to}, was) = (e.scroll.offset = was; hold!(e, nothing); nothing)
look!(e, ::Val{:go_to}, f, _, h::HeadingLine) = (hold!(e, max(h.line - 3, 1), 24px - PAGE_TOP); nothing)
look!(e, ::Val{:go_to}, f, _, n::Integer) = nothing

"Where line `i` of the page is in the window of `e`, across the whole page"
line_rect(e, i::Int) = begin
  (isempty(e.layout) || !(1 <= i <= length(e.buf.lines))) && return nothing
  it = item(e, i)
  (left=e.origin[1] - 8px, top=e.origin[2] + it.top, width=e.width + 16px, height=it.tall)
end
shown_at(e, h::HeadingLine) = line_rect(e, h.line)

"""
Say how many words the page has, how many characters, and how long it takes
to read, under the top bar for a while. Front matter says things about a
document, so the count leaves it out.
"""
word_count(e) = begin
  b = e.buf
  lines = view(b.lines, (b.view == :markdown ? front_matter(b.lines) : 0)+1:length(b.lines))
  if b.view == :markdown
    # A comment isn't part of the page's text: neither one on lines of its own, nor a %%note%% in a line
    ks, skip = kinds(b), length(b.lines) - length(lines)
    uncommented(text) = join(s.text for s in spans(text) if !s.comment && !(s.markup && s.text == "%%"))
    lines = [ks[skip+k].kind == Kind.code || !occursin("%%", text) ? text : uncommented(text) for (k, text) in enumerate(lines) if ks[skip+k].lang != COMMENT]
  end
  n, chars = words(lines), sum(length, lines, init=0)
  said = "$(commas(n)) word$(n == 1 ? "" : "s")  ·  $(commas(chars)) character$(chars == 1 ? "" : "s")  ·  $(max(1, round(Int, n / 230))) min read"
  say_result!(e, said)
  said
end
add_command!(word_count, title="Say how many words the page has, how many characters, and how long it takes to read", kind=:look)
works_here(e, ::Val{:word_count}) = e.buf.view in (:markdown, :code)

"The lines of the file text `s`, as `text` reads them from a file"
text_lines(s::AbstractString) = String.(split(replace(s, "\r\n" => "\n"), '\n'))
