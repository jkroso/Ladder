# Where the value of a name comes from, and the names that one part of the page has from another

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" ui hide_tooltip! redraw_in!
@use "./markdown" Kind
@use "./sheet" Given name_values ident
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
@use "./sheet_view" exports...
@use "./slides_view" exports...
@use "./code_names" exports...
@use "./code_nav" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...

export NO_GIVERS, block_givers!, cmd_words, follows, giver, giver_at, givers, go_to_giver!,
       inline_given!, mark_clickable, name_givers, named_sums, place_span, sum_names, value_name,
       value_name_at, CmdCard, cmd_card

# --- where the value of a name comes from ---------------------------------------------------------------
#
# A sum in a line of text that is only a name, like !`energy`, shows the value
# of that name. Another part of the page gives the name its value: a sum like
# !`energy = convert(TWh, …)`, a row of a sheet like "Energy = …", or the code
# of a `julia` block. Over that value the mouse is a hand. A click on it goes
# to the part that gives the name its value, and selects it there. A cell of a
# table works the same way. ⌘⌥← comes back to where the click was.
#
# A name can get a value in more than one place. The sums run from the top of
# the page down, so the click goes to the last place over the value. When no
# place is over it, the click goes to the first place under it.

"""
The sum in a line of text whose value is drawn at the point `pos` of the
window, when the sum's code is only a name, like !`energy`: the name, and the
line and the column where the sum's code starts. It's nothing anywhere else,
and where the line shows its code.
"""
value_name_at(e, pos) = begin
  b = e.buf
  (isempty(e.layout) || b.view != :markdown || !runs_sums(e) || slideshow(e) !== nothing) && return nothing
  dx, dy = pos[1] - e.origin[1], pos[2] - e.origin[2]
  (dy >= 0px && pos[2] >= above_page(e)) || return nothing
  it = e.layout[item_under(e, dx, dy)]
  # Until the next frame, the layout is of the page that showed before, which can have more lines than this one
  it.last <= length(b.lines) || return nothing
  dx -= item_room(e, it)[1]   # a column of a group starts at its own left edge
  dy -= it.top
  c = it.content
  c isa Flow && return value_name(b, it.first, c, dx, dy)
  c isa Grid || return nothing
  # Each cell of a table has its own lines of text. Their columns are the columns of the row's line.
  for r in eachindex(c.rows), k in eachindex(c.flows[r])
    cx, cy = cell_origin(c, r, k)
    found = value_name(b, c.rows[r], c.flows[r][k], dx - cx, dy - cy)
    found === nothing || return found
  end
  nothing
end

"`value_name_at` for the text `f` of line `i`, at `dx` across and `dy` down from its top left"
value_name(b::Buffer, i::Int, f::Flow, dx::px, dy::px) = begin
  f.raw && return nothing
  k = findfirst(vl -> f.above + vl.top <= dy < f.above + vl.top + vl.high, f.lines)
  k === nothing && return nothing
  hit = findfirst(seg -> seg.x <= dx < seg.x + seg.w, f.lines[k].segs)
  hit === nothing && return nothing
  seg = f.lines[k].segs[hit]
  (seg.atomic && seg.node === nothing && 1 <= i <= length(b.lines)) || return nothing
  line = b.lines[i]
  for m in eachmatch(r"!`([^`]+)`", line)
    from = length(line, 1, m.offset) + 1   # the column where the code starts, after the ! and the `
    n = length(m[1])
    # The first word of a value stands for all of its code. The words after it are at the code's end: see `wrap`.
    (later_word(seg) ? seg.col == from + n : seg.col == from && seg.n == n) || continue
    name = strip(m[1])
    return Base.isidentifier(name) ? (name=String(name), line=i, col=from) : nothing
  end
  nothing
end

"""
The places of the page that give the name `name` a value, from the top of the
page down. Each is the first and the last place of the part that gives it: a
sum in a line of text, like !`energy = …`, a row of a block, like a sheet's
"Energy = …", or a name that a `julia` block makes outside of a function.
"""
givers(e, name::AbstractString) = get(name_givers(e), name, NO_GIVERS)

const NO_GIVERS = Tuple{Pos,Pos}[]

"`givers` for each name of the page. They're found again when the page has changed."
name_givers(e) = begin
  b = e.buf
  get!(e.flows, (:name_givers, b.path, b.version)) do
    out = Dict{String,Vector{Tuple{Pos,Pos}}}()
    give!(name, from, to) = push!(get!(() -> Tuple{Pos,Pos}[], out, name), (from, to))
    ks = kinds(b)
    i = 1
    while i <= length(ks)
      k = ks[i]
      if k.kind == Kind.fence && k.level == 0
        t = codeblock(b, i)[2]
        if t > i && ks[t].kind == Kind.fence && ks[t].level == 1
          haskey(BLOCKS, k.lang) && block_givers!(give!, e, k.lang, i, t)
          i = t
        end
      elseif !(k.kind in (Kind.fence, Kind.code))
        # From the ! to the ` that ends the sum
        for (_, _, code, col) in get!(() -> named_sums(b.lines[i]), e.flows, (:named_sums, b.lines[i]))
          give!(String(sum_name(code)), (i, col - 2), (i, col + length(code) + 1))
        end
      end
      i += 1
    end
    for m in page_bounds(e)
      # A line that brings a name in from another file, like `using Dates`, doesn't give it a value here
      (m.span === nothing && !occursin(r"^\s*(@use|using|import)\b", b.lines[m.at[1]])) || continue
      give!(m.name, m.at, (m.at[1], m.at[2] + length(m.name)))
    end
    foreach(sort!, values(out))
    out
  end
end

"""
Give `give!` the place of each name that the block in the language `lang`, from
line `i` to line `t`, gives. A sum uses the name of a row as Julia knows it:
\"Wall length\" is `wall_length`. The place is the start of the first line
of the block that starts with the name, or else has it, or else the block's first line.
"""
block_givers!(give!, e, lang, i::Int, t::Int) = begin
  lines = e.buf.lines[i+1:t-1]
  isempty(lines) && return
  for (name, _) in get!(() -> block_names(BLOCKS[lang], lines), e.flows, (:block_names, lang, lines))
    id = ident(name)
    isempty(id) && continue
    low = lowercase(strip(name))
    j = something(findfirst(l -> startswith(lowercase(lstrip(l)), low), lines), findfirst(l -> occursin(low, lowercase(l)), lines), 1)
    at = (i + j, length(lines[j]) - length(lstrip(lines[j])))
    give!(id, at, at)
  end
end

"""
Where the value that the name `name` has at the column `col` of line `i` comes
from, as a place that `givers` gives: the last place over it, or else the
first place under it. Nothing when no part of the page gives the name a value.
"""
giver(e, name::AbstractString, i::Int, col::Int) = begin
  places = givers(e, name)
  isempty(places) && return nothing
  places[something(findlast(p -> p[1] < (i, col), places), 1)]
end

"The place that gives a value to the name whose value is at the point `pos` of the window, as `giver` gives it, or nothing"
giver_at(e, pos) = begin
  found = value_name_at(e, pos)
  found === nothing ? nothing : giver(e, found.name, found.line, found.col)
end

"How far the place `p` of the page is under the page's top, and how far the end of its line on screen is"
place_span(e, p::Pos) = begin
  it = item(e, p[1])
  c = it.content
  if c isa Flow
    k = spot(c, p[2])[1]
    top = it.top + line_top(c, k)
    return (top, top + c.lines[k].high)
  elseif c isa Sheet && !isempty(c.rows)
    r = clamp(p[1] - it.first, 1, length(c.rows))
    top = it.top + row_top(c, r)
    return (top, top + c.heights[r])
  end
  (it.top, it.top + it.tall)
end

"""
Go to the part of the page from `from` to `to`, which gives a name its value,
and select it. A part that's on screen stays where it is. Another comes a
third of the way down the window. ⌘⌥← comes back.
"""
go_to_giver!(e, (from, to)) = begin
  note_place!(e)
  b = e.buf
  b.anchor, b.caret = from, to
  e.popup = :none
  # The mouse is still down. A move must not select from here to the mouse: see `drag!`.
  e.clicked = (time(), (from[1], 0), 0)
  focus(e)
  s = e.scroll
  top, bottom = place_span(e, from)[1], place_span(e, to)[2]
  (s.offset <= PAGE_TOP + top - 30px && PAGE_TOP + bottom + 40px <= s.offset + s.viewport) ||
    (s.offset = max(0px, PAGE_TOP + top - s.viewport / 3))
  touch!(e)
  e
end

"""
The words that a click with ⌘ at the point `pos` acts on, as the line and the
columns where they start and end: a link, or a name of Julia code that has a
place where it's defined. It's nothing where a click with ⌘ does neither.
`cursor(::Document)` and `press!` find the same.
"""
cmd_words(e, pos) = begin
  line, col = locate(e, pos)
  it = item(e, line)
  it.content isa Flow || return nothing
  segs = [seg for vl in it.content.lines for seg in vl.segs]
  k = findfirst(s -> s.col <= col < s.col + s.n && !isempty(s.link), segs)
  if k !== nothing
    # A link's words can be in several runs of text, as where part of them is bold
    a = z = k
    while a > 1 && segs[a-1].link == segs[k].link; a -= 1 end
    while z < length(segs) && segs[z+1].link == segs[k].link; z += 1 end
    return (line, segs[a].col, segs[z].col + segs[z].n)
  end
  found = name_at(e.buf, (line, col))
  (found === nothing || Base.invokelatest(definition, e, (line, col)) === nothing) && return nothing
  (line, found.col, found.col + length(found.name))
end

"""
The card that shows while ⌘ is held and the mouse rests on words, which the
window keeps: see `peek!`. It's here, and not with `peek!`, since the mark of
the words under the mouse takes the card away when ⌘ comes up.
"""
@def mutable struct CmdCard
  peek::Union{Nothing,NamedTuple{(:words, :since, :shown)}} = nothing   # the words that the mouse is on, since when, and whether their card shows
  mouse::Any = nothing   # where the mouse was when ⌘ went down, :moved once it has moved from there, and nothing while ⌘ is up
end

"What the window of `e` keeps of the card that shows while ⌘ is held: see `CmdCard`"
cmd_card(e) = state_of(e, CmdCard)

"""
While ⌘ is held by itself, mark the words under the mouse that a click would
act on: a soft box behind them and a line under them, as the mouse is a hand
there. The page's text is at `ui`.
"""
mark_clickable(ctx, e, ui) = begin
  w = window_of(e)
  if !(w !== nothing && only_held(w, Keys.cmd) && e.popup == :none && e.buf.view != :file && slideshow(e) === nothing)
    # The card of a name goes when ⌘ comes up
    card = cmd_card(e)
    w === nothing || (was = card.peek; card.peek = nothing; was === nothing) || hide_tooltip!(w)
    card.mouse = nothing
    return
  end
  redraw_in!(e, 1/30)   # the mark follows the mouse, and goes when ⌘ comes up
  found = cmd_words(e, w.mouse)
  peek!(e, w, found)
  found === nothing && return
  line, lo, hi = found
  it = item(e, line)
  f = it.content::Flow
  k1, x1 = spot(f, lo)
  k2, x2 = spot(f, hi)
  # Words that wrap onto a second line are marked on each line that they're on
  for k in k1:k2
    vl = f.lines[k]
    isempty(vl.segs) && continue
    left = k == k1 ? x1 : first(vl.segs).x
    right = k == k2 ? x2 : last(vl.segs).x + last(vl.segs).w
    right > left || continue
    top = ui.top + it.top + line_top(f, k)
    round_box(ctx, num(ui.left + left) - 1, num(top), num(right - left) + 2, num(vl.high), 3; fill=tint(colours.accent, MARK_FILL))
    y = num(top + vl.high / 2) + num(f.size) * 0.62
    trace(ctx, [(num(ui.left + left), y), (num(ui.left + right), y)], colours.accent, 1.0)
  end
end

# --- names that one part of the page has from another -------------------------------------------
#
# A row of a sheet can use a name from a part of the page over it, the way
# it uses the name of a row above it: a measure of a takeoff, a task of a
# time log, and a row of another sheet. So "Tiles = kitchen floor tiles /
# 0.36m^2" follows the outline that's drawn on the plan. A sum in a line of
# text can use the same names, and the names of every sheet of the page, as
# Julia knows them: !`wall_length` for the row "Wall length". The code of the
# page's `julia` blocks can use them too.
#
# No part sends its values anywhere. `block_names(lang, lines)` says what the
# block of one kind gives: each name with an expression for its value, as a
# row of a sheet has. A sheet asks for the names of the blocks over it with
# `page_given`, and works them out as rows over its first row.

"""
What a block in the language `lang` gives the rest of its page: names, each
with an expression for its value, as a row of a sheet has. `lines` are the
lines of the block. A sheet gives its rows, a takeoff gives each measure with
its amount, and a time log gives each task with its hours.
"""
block_names(lang::AbstractString, lines) =
  haskey(BLOCKS, lang) ? block_names(BLOCKS[lang], lines) : Tuple{String,String}[]

"""
The names that the sums in a line of text give, each with the code of its
value: !`farm = 2GW` gives ("farm", "2GW"). A sum that gives no name, like
!`farm * 2`, gives nothing. A `_` of a name is a space, so a row of a sheet
can use !`farm_cost = …` as "farm cost", the way a sum uses the row "Farm
cost" as `farm_cost`.
"""
sum_names(text::AbstractString) = [(name, expr) for (name, expr, _, _) in named_sums(text)]

"What `sum_names` gives, with the code of each sum and the column where its code starts in `text`"
named_sums(text::AbstractString) = begin
  out = Tuple{String,String,String,Int}[]
  occursin(INLINE, text) || return out
  for m in eachmatch(r"!`([^`]+)`", text)
    code = String(m[1])
    name = sum_name(code)
    name === nothing && continue
    # The name has no =, so the first = is the one after it
    push!(out, (replace(String(name), '_' => ' '), String(strip(code[nextind(code, findfirst('=', code)):end])), code, length(text, 1, m.offset) + 1))
  end
  out
end

"The name that the code of a sum gives, like `:farm` for `farm = 2GW`, or nothing"
sum_name(code::AbstractString) = begin
  ex = try Meta.parse(code, raise=false) catch; nothing end
  ex isa Expr && ex.head == :(=) && length(ex.args) == 2 && ex.args[1] isa Symbol ? ex.args[1] : nothing
end

"""
True when the code of a sum uses one of `names` for its value. The name that
the sum gives doesn't count, nor does the name of a keyword: in
`p = ProgressBar(value=x)` only `x` counts.
"""
follows(code::AbstractString, names) = begin
  ex = try Meta.parse(code, raise=false) catch; return false end
  sum_name(code) === nothing || (ex = ex.args[2])
  found = false
  look(x) = if x isa Symbol
    x in names && (found = true)
  elseif x isa Expr
    foreach(look, x.head in (:kw, :(=)) && x.args[1] isa Symbol ? x.args[2:end] : x.args)
  end
  look(ex)
  found
end

"""
The names that the parts of the page over line `upto` give, each with an
expression for its value. With no line, it's the names of the whole page.
With `sums`, the sums in the lines of text give their names too, so a sheet
can use !`farm = 2GW` as `farm`. They're found again when the page has changed.
"""
page_given(e, upto::Int=typemax(Int); sums::Bool=false) = given_and_sums(e, upto, sums)[1]

"""
`page_given`, and where each name that a sum gives is: its place in that
list, and the code and the ordinal that `made` keeps the sum by.
"""
given_and_sums(e, upto::Int, sums::Bool) = begin
  b = e.buf
  get!(e.flows, (:given_sums, b.path, b.version, upto, sums)) do
    out = Tuple{String,String}[]
    spots = Tuple{Int,String,Int}[]
    ks = kinds(b)
    i = 1
    while i <= length(ks) && i < upto
      k = ks[i]
      if k.kind == Kind.fence && k.level == 0
        t = codeblock(b, i)[2]
        if t > i && ks[t].kind == Kind.fence && ks[t].level == 1
          if t < upto && haskey(BLOCKS, k.lang)
            got = get!(() -> block_names(BLOCKS[k.lang], b.lines[i+1:t-1]), e.flows, (:block_names, k.lang, b.lines[i+1:t-1]))
            isempty(got) || append!(out, got)
          end
          i = t
        end
      elseif sums && !(k.kind in (Kind.fence, Kind.code))
        for (name, expr, code, col) in get!(() -> named_sums(b.lines[i]), e.flows, (:named_sums, b.lines[i]))
          push!(out, (name, expr))
          push!(spots, (length(out), code, ordinal(e, i, col, code)))
        end
      end
      i += 1
    end
    (out, spots)
  end
end

"""
What the sheet whose block opens on line `upto` has from the parts of the
page over it: what `page_given` gives with `sums`, but a sum that didn't go
wrong gives what it came to, as a `Given`, in place of its code. The sheet
takes that value as it is. So a sum that takes long, like one that adds up
thousands of numbers, runs once for its line, and not again for each sheet
under it.

A sum over the sheet that hasn't run since the page changed runs here, as it
would when its line is laid out, from the top down. A chart near the top of
the page asks for every table of the page before the sums under it are laid
out, and the sheet then has the same values for it as for the rest of the frame.

A sheet that's on no page has the names that the part that shows it gives:
the sheet of a SolidCraft design's parameters has the design's.
"""
sheet_given(e, upto::Int) = begin
  outside = ties(e).given
  outside === nothing || return outside
  b = e.buf
  given, spots = given_and_sums(e, upto, true)
  foreach(((_, code, n),) -> made(e, code, n), spots)
  get!(e.flows, (:sheet_given, b.path, b.version, upto, sums_run[])) do
    values = get(e.nodes, (:sum_values, b.path), nothing)
    out = Tuple{String,Any}[given...]
    values === nothing && return out
    for (k, code, n) in spots
      made = get(e.nodes, (:inline, b.path, code, n), nothing)
      (made isa Tuple && !made[2] && haskey(values, (code, n))) || continue
      out[k] = (given[k][1], Given(values[(code, n)]))
    end
    out
  end
end

"""
Keep what the `n`th sum `code` of the page came to, when it gives a name and
didn't go wrong, so that `sheet_given` can give it to the sheets under it.
"""
keep_value!(e, code::String, n::Int, failed::Bool) = begin
  values = get!(() -> Dict{Tuple{String,Int},Any}(), e.nodes, (:sum_values, e.buf.path))
  delete!(values, (code, n))
  name = sum_name(code)
  (failed || name === nothing) && return
  # A drag makes a new sum on each step, so the values of sums that the page no longer has are forgotten
  length(values) > 400 && filter!(((k, _),) -> haskey(e.nodes, (:inline, e.buf.path, k...)), values)
  try
    values[(code, n)] = Base.invokelatest(getglobal, workspace(e), name)
  catch
  end
end

"""
Give the page's code the names of the page's sheets, takeoffs and time logs,
with their values, and say what they came to. A sum in a line of text, and
the code of a `julia` block, can then use a row called "Wall length" as
`wall_length`. A name that the page's code already has, like `sum`, stays as
it is. `inline_tick!` runs the page's sums again when what this gives changes.
"""
inline_given!(e) = begin
  given = page_given(e)
  isempty(given) && return nothing
  values = get!(() -> name_values(given), e.flows, (:name_values, given))
  m = workspace(e)
  ours = get!(() -> Set{Symbol}(), e.nodes, (:given_names, e.buf.path))
  for (id, value) in values
    name = Symbol(id)
    (name in ours || !Base.invokelatest(isdefined, m, name)) || continue
    try
      Core.eval(m, Expr(:(=), name, QuoteNode(value)))
      push!(ours, name)
    catch
    end
  end
  hash(given)
end
