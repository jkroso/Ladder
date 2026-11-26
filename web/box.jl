# Makes the boxes of a page from its elements and their styles. layout.jl
# gives each box its size and its place.
#
#     root = boxes(doc, look)     # the box of the <html> element
#     root.kind                   # :block
#     root.children               # the boxes in it
#
# A box is one of these kinds:
#
#   :block    a box that's laid out down the page, with boxes or lines of text in it. A flex box and a grid are blocks too:
#             their style's `display` says how what's in them is laid out.
#   :inline   a part of a line of text that has a style of its own, like a link
#   :text     a run of text
#   :break    a <br>
#   :image    a picture, or anything else that's drawn as one piece with a size of its own: an SVG drawing, a tick box,
#             a video. Its `widget` says which.
#   :table, :group, :row, :cell, :caption, :column    the parts of a table
#
# A box that's `atomic` goes in a line of text as one piece: an inline-block, or
# a picture.
#
# The boxes are made whole here, as CSS asks: text beside a block gets a block
# of its own, a cell that's in no row gets a row and a table, a link that has a
# block in it is a block, and text right in a flex box gets a block.
#
# What a page makes with CSS alone is made here too: the text of `::before`
# and `::after`, the numbers of its counters, and the bullet or the number of
# each list item. A form's parts get the text that they show.

@use "./dom" Element Text Document Node attr text
@use "./css" media
@use "./style" Style Look Context Len ZERO sides child len px isauto alpha colour
@use "./text" font width
@use "./video" frame play spot untouched

"The top and the bottom margin of a box that can join with the margins next to them: the biggest, and the most negative"
struct Gap
  pos::Float64
  neg::Float64
end
Gap(m::Real) = m >= 0 ? Gap(m, 0.0) : Gap(0.0, m)
const NO_GAP = Gap(0.0, 0.0)
Base.join(a::Gap, b::Gap) = Gap(max(a.pos, b.pos), min(a.neg, b.neg))
Base.size(g::Gap) = g.pos + g.neg

"Something in a line of text: a word, a space, a box that's one piece, or the start or the end of an inline box"
mutable struct Piece{B}
  kind::Symbol               # :text, :atom, :open or :close
  box::B                     # the text's box, the box that's one piece, or the inline box
  chars::Vector{Char}
  widths::Vector{Float64}    # how wide each letter is
  width::Float64
  x::Float64                 # its left edge, from the left of the content of the block that the line is in
  y::Float64                 # of text: the line that its letters stand on. Of a box: its top. From the top of the block's content.
  space::Bool                # it's a space that a line can end with, and then it takes no room
  from::Int                  # of text: how many letters of its box's text come before it
end

"The part of an inline box that's in one line: where its background and its border go"
struct Span{B}
  box::B
  left::Float64
  right::Float64
  top::Float64
  bottom::Float64
  first::Bool      # the box starts in this line
  last::Bool       # and ends in it
end

mutable struct Line{B}
  y::Float64                 # its top, from the top of the block's content
  height::Float64
  baseline::Float64          # how far under its top its text stands
  pieces::Vector{Piece{B}}
  spans::Vector{Span{B}}
  hard::Bool                 # a <br> or a new line in the text ended it
  free::Float64              # how much room it left in the block
end

Base.@kwdef mutable struct Box
  kind::Symbol
  style::Style
  element::Union{Element,Nothing} = nothing
  children::Vector{Box} = Box[]
  text::String = ""
  advances::Vector{Float64} = Float64[]   # of text: how wide each of its letters is
  atomic::Bool = false
  item::Bool = false                   # it's right in a flex box or a grid
  # Where it is, once it's laid out: its border, in px from the top left corner of the border of the box that it's in
  x::Float64 = 0.0
  y::Float64 = 0.0
  width::Float64 = 0.0
  height::Float64 = 0.0
  margin::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)
  padding::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)
  border::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)
  lines::Vector{Line{Box}} = Line{Box}[]
  over::Vector{Box} = Box[]            # the boxes with a place of their own that are placed from this box
  below::Gap = NO_GAP                  # the margin under it, joined with the margins of what ends where it ends
  baseline::Float64 = NaN              # how far under its top its last line of text stands
  first::Float64 = NaN                 # how far under its top its first line of text stands, for a thing in a flex box or a grid
  extent::Tuple{Float64,Float64} = (NaN, NaN)   # how narrow it can be, and how wide it is with no line broken
  row::Int = 0                         # of a cell: its row and its column in the table, and how many of each it spans
  col::Int = 0
  rowspan::Int = 1
  colspan::Int = 1
  link::String = ""                    # where the link that it's in goes, or ""
  marker::String = ""                  # of a list item: its bullet or its number
  markerstyle::Union{Style,Nothing} = nothing   # what the page's `::marker` says of how that looks
  markerimage::Any = nothing           # the picture that stands for the bullet: its width, its height and Skia's picture
  natural::Tuple{Float64,Float64} = (0.0, 0.0)   # of a picture: how big the picture itself is, or zeros when it isn't known
  shape::Float64 = NaN                 # of a picture that isn't there: its width over its height, as its tag's `width` and `height` say
  picture::Any = nothing               # of a picture: what the page's pictures have for it
  keeps::Any = nothing                 # of a picture of an SVG file: how it keeps its shape in a box of another shape, as `kept` of svg.jl gives it. Nothing for a picture that's stretched to its box.
  fills::Bool = false                  # of a drawing with a shape and no size: it's as wide as the box that it's in
  widget::Symbol = :none               # of an :image that's no picture: :svg, :checkbox, :radio, :range, :color, :progress, :meter, :video, :audio, :frame, :canvas, :poster for a frame that shows a video of another site, or :select for the arrows of a <select>. A video's `picture` is the `Frame` that it shows, and the `picture` of a picture file that moves is its `Reel`. A poster's `picture` is its picture's width, its height and Skia's picture, and its `text` is the video's name.
  value::Float64 = NaN                 # of a tick box: 1 when it's ticked. Of a slider or a bar: how much of it is full, from 0 to 1.
  grid::Any = nothing                  # of a table: its rows and its columns
  cbh::Float64 = NaN                   # how tall the content of the box that it's in is, when that's known before its content is laid out: a height in percent is of this
  sure::Float64 = NaN                  # how tall its own content is, when that's known before its content is laid out
  forced::Float64 = NaN                # how tall its border has to be, when the box that it's in says: a thing that's stretched in a flex box
  still::Tuple{Bool,Bool} = (false, false)   # of a box with a place of its own: it stays across, and down, where it would be in the text
  anchor::Any = nothing                # of a box with a place of its own: the box that it's placed from
  lone::Any = nothing                  # of a box with a place of its own right in a flex box or a grid: that box, and how far across and down the room in its content the box's place in the text is, from 0 at the start to 1 at the end
  cols::Any = nothing                  # of a block in columns: where each column of it is cut from
  notch::NTuple{3,Float64} = (0.0, 0.0, 0.0)   # of a <fieldset> with a <legend>: how far down its border starts, and where the legend cuts the border, from and to
end

"True for a float or a box with a place of its own: it isn't part of the flow of the box that it's in"
floats(b::Box) = b.kind != :text && b.style.float != :none
placed(b::Box) = b.kind != :text && b.style.position in (:absolute, :fixed)
"True for a box that goes in a line of text"
inline(b::Box) = b.kind in (:text, :inline, :break) || b.atomic
"True for a box whose content is laid out as a flex box or as a grid"
flexes(b::Box) = b.kind == :block && b.style.display in (:flex, :inline_flex)
grids(b::Box) = b.kind == :block && b.style.display in (:grid, :inline_grid)
"True for a block whose content is in columns"
columned(b::Box) = b.kind == :block && (b.style.colcount > 0 || !isauto(b.style.colwidth)) && !flexes(b) && !grids(b)
"True for a box that starts its own flow: its floats and margins stay in it"
contained(b::Box) = b.atomic || b.item || b.kind in (:cell, :caption, :table) || floats(b) || placed(b) || b.style.overflow != :visible ||
                    b.style.display in (:flow_root, :flex, :inline_flex, :grid, :inline_grid, :inline_block) || columned(b) ||
                    b.element !== nothing && b.element.parent === nothing

"A box that no element made, which looks like what's in `b`"
anonymous(kind, b::Box, children=Box[]) = begin
  s = child(b.style)
  s.display = kind == :block ? :block : :inline
  Box(kind=kind, style=s, children=children)
end

# Text that's only white space is nothing between two blocks, unless a space that doesn't break is in it
blank(b::Box) = b.kind == :text && b.style.whitespace in (:normal, :nowrap, :pre_line) && all(isspace, b.text) && !occursin('\u00a0', b.text)

# --- the numbers and bullets of a list ----------------------------------------------------

const ROMAN = [1000 => "m", 900 => "cm", 500 => "d", 400 => "cd", 100 => "c", 90 => "xc", 50 => "l", 40 => "xl", 10 => "x", 9 => "ix", 5 => "v", 4 => "iv", 1 => "i"]
roman(n) = begin
  out = ""
  for (v, s) in ROMAN
    while n >= v
      out *= s
      n -= v
    end
  end
  out
end
letters(n, first='a', count=26) = (out = ""; while n > 0; n -= 1; out = string(first + n % count) * out; n ÷= count; end; out)

"The number `n` as a counter of the kind `kind` writes it: 3, iii, c or 03"
numeral(kind::Symbol, n) =
  kind == :decimal || n < 1 ? string(n) : kind == :decimal_leading_zero ? lpad(n, 2, '0') : kind == :lower_alpha ? letters(n) :
  kind == :upper_alpha ? uppercase(letters(n)) : kind == :lower_roman ? roman(n) : kind == :upper_roman ? uppercase(roman(n)) :
  kind == :lower_greek ? letters(n, 'α', 24) : kind == :disc ? "•" : kind == :circle ? "◦" : kind == :square ? "▪" : kind == :none ? "" : string(n)

"What a list item shows before its text: a bullet, or its number `n`"
marker(kind::Symbol, n) =
  kind == :disc ? "•" : kind == :circle ? "◦" : kind == :square ? "▪" : kind == :none ? "" : kind == :disclosure_closed ? "▶" :
  kind == :disclosure_open ? "▼" : numeral(kind, n) * "."

"The counters of a page while its boxes are made, and how many quotes are open"
mutable struct Counters
  values::Dict{String,Vector{Int}}     # the values of each counter: one for each element round here that started it again
  made::Vector{Vector{String}}         # for each element that's open, the counters that the elements in it started
  quotes::Int
end
Counters() = Counters(Dict{String,Vector{Int}}(), [String[]], 0)

"The names of `v`, like `section 1 item`, each with its number, or `default`"
counts(v, default) = begin
  out = Pair{String,Int}[]
  ws = split(v)
  i = 1
  while i <= length(ws)
    n = i < length(ws) ? tryparse(Int, ws[i+1]) : nothing
    startswith(ws[i], "reversed(") || push!(out, String(ws[i]) => something(n, default))
    i += n === nothing ? 1 : 2
  end
  out
end

"Start the counter `name` at `n`, for the elements after this one and the ones in them"
reset!(c::Counters, name, n) = begin
  values = get!(() -> Int[], c.values, name)
  # One that an element before this one started here is the same counter
  name in c.made[end] && !isempty(values) ? (values[end] = n) : (push!(values, n); push!(c.made[end], name))
  nothing
end
"Add `by` to the counter `name`. One that nothing started starts here."
add!(c::Counters, name, by) = begin
  values = get!(() -> Int[], c.values, name)
  isempty(values) && (push!(values, 0); push!(c.made[end], name))
  values[end] += by
  nothing
end
set!(c::Counters, name, n) = begin
  values = get!(() -> Int[], c.values, name)
  isempty(values) ? (push!(values, n); push!(c.made[end], name)) : (values[end] = n)
  nothing
end
"Do what the style `s` says of the counters, for the element `e` or for a part of one"
count!(c::Counters, s::Style, e=nothing) = begin
  if e !== nothing && e.tag in ("ol", "ul", "menu", "dir")
    # A list counts its items from 1, or from where its tag says. One that counts down starts at how many it has.
    down = e.tag == "ol" && haskey(e.attrs, "reversed")
    start = tryparse(Int, strip(attr(e, "start")))
    reset!(c, "list-item", down ? something(start, count(k -> k isa Element && k.tag == "li", e.children)) + 1 : something(start, 1) - 1)
  end
  if !isempty(s.counterreset)
    for (name, n) in counts(s.counterreset, 0)
      reset!(c, name, n)
    end
  end
  stepped = false
  if !isempty(s.counterincrement)
    for (name, n) in counts(s.counterincrement, 1)
      add!(c, name, n)
      stepped |= name == "list-item"
    end
  end
  if s.display == :list_item && !stepped
    down = e !== nothing && e.parent !== nothing && e.parent.tag == "ol" && haskey(e.parent.attrs, "reversed")
    add!(c, "list-item", down ? -1 : 1)
  end
  e !== nothing && e.tag == "li" && haskey(e.attrs, "value") && (n = tryparse(Int, strip(attr(e, "value")))) !== nothing && set!(c, "list-item", n)
  if !isempty(s.counterset)
    for (name, n) in counts(s.counterset, 0)
      set!(c, name, n)
    end
  end
end

# --- what `content` makes ------------------------------------------------------------------

"The words that CSS writes in quotes: `\\201C` is the letter with that number, and `\\A` a new line"
unquote(t) = begin
  t = strip(t)
  length(t) >= 2 && t[1] in ('"', '\'') && t[end] == t[1] && (t = t[nextind(t, 1):prevind(t, lastindex(t))])
  replace(t, r"\\([0-9a-fA-F]{1,6})\s?" => (x -> string(Char(Base.parse(UInt32, strip(x[2:end]), base=16)))), "\\\n" => "", r"\\(.)" => s"\1")
end

const KINDS_OF_COUNT = Dict("decimal" => :decimal, "decimal-leading-zero" => :decimal_leading_zero, "lower-alpha" => :lower_alpha, "lower-latin" => :lower_alpha,
                            "upper-alpha" => :upper_alpha, "upper-latin" => :upper_alpha, "lower-roman" => :lower_roman, "upper-roman" => :upper_roman,
                            "lower-greek" => :lower_greek, "disc" => :disc, "circle" => :circle, "square" => :square, "none" => :none)

"The pairs of quotes that the style `s` asks for: the outer pair, then the ones in them"
quotes(s::Style) = begin
  v = lowercase(strip(s.quotes))
  v == "none" && return ["", ""]
  found = [unquote(m.match) for m in eachmatch(r"\"[^\"]*\"|'[^']*'", s.quotes)]
  length(found) >= 2 ? found : ["“", "”", "‘", "’"]
end

"What's in the brackets of the function at the start of `t`, like `counter(n, upper-roman)`: each thing between two commas"
inside(t) = begin
  open = findfirst('(', t)
  close = findlast(')', t)
  (open === nothing || close === nothing) && return String[]
  [String(strip(a)) for a in split(SubString(t, nextind(t, open), prevind(t, close)), ',')]
end

"""
What `content: raw` makes for the element `e` or a part of it with the style
`s`: each piece is a string, or a picture as `(width, height, picture)`.
"""
generated(raw, e::Element, s::Style, env) = begin
  out = Any[]
  c = env.counters
  for t in filter(!isempty, strip.(split_terms(raw)))
    lt = lowercase(t)
    if startswith(t, '"') || startswith(t, '\'')
      push!(out, unquote(t))
    elseif startswith(lt, "attr(")
      args = inside(t)
      isempty(args) || push!(out, attr(e, lowercase(first(split(args[1]))), length(args) > 1 ? unquote(args[2]) : ""))
    elseif startswith(lt, "counter(")
      args = inside(t)
      isempty(args) && continue
      values = get(c.values, args[1], Int[])
      push!(out, numeral(get(KINDS_OF_COUNT, length(args) > 1 ? lowercase(args[2]) : "decimal", :decimal), isempty(values) ? 0 : values[end]))
    elseif startswith(lt, "counters(")
      args = inside(t)
      length(args) >= 2 || continue
      values = get(c.values, args[1], Int[])
      kind = get(KINDS_OF_COUNT, length(args) > 2 ? lowercase(args[3]) : "decimal", :decimal)
      push!(out, join((numeral(kind, v) for v in (isempty(values) ? [0] : values)), unquote(args[2])))
    elseif lt in ("open-quote", "close-quote", "no-open-quote", "no-close-quote")
      qs = quotes(s)
      pairs = length(qs) ÷ 2
      if lt in ("open-quote", "no-open-quote")
        lt == "open-quote" && push!(out, qs[2min(c.quotes, pairs - 1)+1])
        c.quotes += 1
      else
        c.quotes = max(0, c.quotes - 1)
        lt == "close-quote" && push!(out, qs[2min(c.quotes, pairs - 1)+2])
      end
    elseif startswith(lt, "url(")
      m = match(r"^url\(\s*(?:\"([^\"]*)\"|'([^']*)'|([^)]*?))\s*\)"i, t)
      found = m === nothing ? nothing : env.pictures(String(strip(something(m[1], m[2], m[3]))))
      found === nothing || push!(out, found)
    elseif t == "/"
      break   # the words after it are for a screen reader
    end
  end
  out
end

"`v` cut at its spaces, with what's in brackets or quotes kept whole"
split_terms(v) = begin
  out = String[]
  buf = IOBuffer()
  depth = 0
  quote_ = '\0'
  prev = '\0'
  for ch in v
    if quote_ != '\0'
      print(buf, ch)
      ch == quote_ && prev != '\\' && (quote_ = '\0')
    elseif ch == '"' || ch == '\''
      quote_ = ch
      print(buf, ch)
    elseif ch == '('
      depth += 1
      print(buf, ch)
    elseif ch == ')'
      depth -= 1
      print(buf, ch)
    elseif isspace(ch) && depth <= 0
      push!(out, String(take!(buf)))
    else
      print(buf, ch)
    end
    prev = prev == '\\' && ch == '\\' ? '\0' : ch
  end
  push!(out, String(take!(buf)))
  out
end

# --- the boxes ----------------------------------------------------------------------------

const KINDS = Dict(:inline => :inline, :block => :block, :list_item => :block, :flow_root => :block, :flex => :block, :inline_block => :block,
                   :inline_flex => :block, :grid => :block, :inline_grid => :block, :table => :table, :inline_table => :table,
                   :table_row_group => :group, :table_header_group => :group, :table_footer_group => :group, :table_row => :row,
                   :table_cell => :cell, :table_caption => :caption, :table_column => :column, :table_column_group => :column)
# A style's `display` that makes a box that goes in a line of text as one piece
const ATOMS = (:inline_block, :inline_table, :inline_flex, :inline_grid)

capitalised(s) = replace(s, r"(?<![\p{L}\p{N}'’])\p{L}" => uppercase)
shown(text, s::Style) = s.textcase == :uppercase ? uppercase(text) : s.textcase == :lowercase ? lowercase(text) :
                        s.textcase == :capitalize ? capitalised(text) : text

# `pictures(address)` gives the size of the picture that an <img> names, and what to draw it with, as
# `(width, height, picture)`, or nothing for a picture that there isn't
no_pictures(src) = nothing

"What's known while the boxes of a page are made"
struct Env
  look::Any                          # the style of each element, and of its parts
  pictures::Function
  films::Function                    # the video at an address, as video.jl reads it, or nothing
  reels::Function                    # the pictures of a picture file that moves, like a GIF, as video.jl reads it, or nothing for any other picture
  embeds::Function                   # what stands for the page at an address in an <iframe>, as `embed` of main.jl gives it, or nothing
  at::Union{Float64,Nothing}         # how many seconds ago the page was first shown, or nothing for the page as it comes to rest
  counters::Counters
  wide::Float64                      # how wide and how high the window is, for a picture that has a file for each size of window
  high::Float64
  small::IdDict{Style,Style}         # for each style that asks for small capitals, the style of its small letters
end

"A copy of the style `s`"
clone(s::Style) = Style((getfield(s, f) for f in fieldnames(Style))...)

"The text `words` as boxes: one box, or one for each run of small and big letters where the style asks for small capitals"
texts!(out, words, s::Style, env, link) = begin
  isempty(words) && return
  words = shown(words, s)
  if !s.smallcaps || !any(islowercase, words)
    push!(out, Box(kind=:text, style=s, text=words, link=link))
    return
  end
  small = get!(env.small, s) do
    t = clone(s)
    t.size = round(s.size * 0.7, digits=2)
    t
  end
  run = Char[]
  low = false
  flush() = (isempty(run) || push!(out, Box(kind=:text, style=low ? small : s, text=low ? uppercase(String(run)) : String(run), link=link)); empty!(run))
  for ch in words
    is = islowercase(ch)
    is != low && (flush(); low = is)
    push!(run, ch)
  end
  flush()
end

"How many pixels to the px the picture of one file of a `srcset` has: `2x` is 2, and `800w` is 800 over how wide the picture is shown"
candidates(srcset, shown) = begin
  out = Tuple{String,Float64}[]
  for part in split(srcset, r",\s+|,(?=\S+\s+[0-9.]+[wx])")
    ws = split(strip(part))
    isempty(ws) && continue
    how = length(ws) > 1 ? lowercase(ws[end]) : "1x"
    n = tryparse(Float64, how[1:end-1])
    n === nothing && continue
    push!(out, (String(ws[1]), endswith(how, 'w') ? n / max(shown, 1.0) : n))
  end
  out
end

"How wide a picture's `sizes` says it's shown, on a page `wide` px wide"
shown_width(sizes, wide, high) = begin
  for part in split(sizes, ',')
    part = strip(part)
    isempty(part) && continue
    cut = findlast(')', part)
    query, size = cut === nothing ? ("", part) : (part[1:cut], strip(part[nextind(part, cut):end]))
    (isempty(query) || media(query, wide, high)) || continue
    l = len(size, Context(wide, 16.0, false, high))
    l === nothing || l.auto || return px(l, wide)
  end
  Float64(wide)
end

"""
The address of the picture that the <img> `e` shows, and how many pixels of
it there are to the px. A <picture> round it, or its `srcset`, can name a file
for each kind of screen: the one for a screen like a Mac's is taken.
"""
source(e::Element, env) = begin
  sets = Tuple{String,String}[]
  if e.parent !== nothing && e.parent.tag == "picture"
    for k in e.parent.children
      k === e && break
      k isa Element && k.tag == "source" || continue
      kind = lowercase(attr(k, "type"))
      # Skia reads no picture of these kinds
      (occursin("avif", kind) || occursin("jxl", kind) || occursin("heic", kind)) && continue
      haskey(k.attrs, "media") && !media(attr(k, "media"), env.wide, env.high) && continue
      isempty(strip(attr(k, "srcset"))) || push!(sets, (attr(k, "srcset"), attr(k, "sizes")))
    end
  end
  isempty(strip(attr(e, "srcset"))) || push!(sets, (attr(e, "srcset"), attr(e, "sizes")))
  for (set, sizes) in sets
    found = candidates(set, shown_width(sizes, env.wide, env.high))
    isempty(found) && continue
    # The file with the fewest pixels that's enough for a screen with two pixels to the px, or the one with the most
    enough = filter(x -> x[2] >= 2, found)
    return isempty(enough) ? found[argmax(map(last, found))] : enough[argmin(map(last, enough))]
  end
  (String(strip(attr(e, "src"))), 1.0)
end

"The size that an SVG's tag gives it, with zeros for what it doesn't say, and its width over its height"
drawing_size(e::Element) = begin
  side(v) = (m = match(r"^\s*([0-9.]+)\s*(px)?\s*$", v); m === nothing ? 0.0 : something(tryparse(Float64, m[1]), 0.0))
  w, h = side(attr(e, "width")), side(attr(e, "height"))
  view = [tryparse(Float64, x) for x in split(attr(e, "viewbox"), r"[\s,]+"; keepempty=false)]
  ratio = length(view) == 4 && !any(isnothing, view) && view[3] > 0 && view[4] > 0 ? view[3] / view[4] : w > 0 && h > 0 ? w / h : NaN
  (w, h, ratio)
end

"The box of a thing that's drawn as one piece, like a picture: `natural` is how big it is when nothing says"
piece(e::Element, s::Style, link; natural=(0.0, 0.0), widget=:none, value=NaN, picture=nothing) = begin
  b = Box(kind=:image, style=s, element=e, link=link, natural=natural, widget=widget, value=value, picture=picture)
  b.atomic = !(s.display in (:block, :list_item, :table, :flex, :grid, :flow_root)) && !floats(b) && !placed(b)
  b
end

"The box of a part of a form that shows the text `words`, like a text field or a button"
field(e::Element, s::Style, words, link; dim=false, widget=:none) = begin
  look = s
  if dim
    look = clone(s)
    look.color = 0xffa9a9a9
  end
  # A field with nothing in it is still a line tall
  kid = Box(kind=:text, style=look, text=isempty(words) ? "\u200b" : words)
  b = Box(kind=:block, style=s, element=e, children=[kid], link=link, widget=widget)
  b.atomic = s.display in ATOMS
  b
end

const BUTTONS = Dict("submit" => "Submit", "reset" => "Reset", "button" => "")
const NO_VALUE = Dict("date" => "dd/mm/yyyy", "time" => "--:-- --", "datetime-local" => "dd/mm/yyyy, --:-- --", "month" => "---------- ----", "week" => "Week --, ----")

"A number that a tag says, or `default`"
amount(e::Element, name, default) = something(tryparse(Float64, strip(attr(e, name))), default)

"""
The picture that the <video> element `e` shows now, and whether the video
plays, or nothing when its file can't be read. A video that plays shows its
picture of this moment of the page, and the page is noted to move until the
video ends. Its file is the first that macOS can read, of its `src` and of the
<source> elements in it. An address that ends with `#t=10` starts 10 seconds
in.
"""
playing(e::Element, env::Env) = begin
  for src in (attr(e, "src"), (attr(k, "src") for k in e.children if k isa Element && k.tag == "source")...)
    src = strip(src)
    isempty(src) && continue
    m = match(r"^(.*)#t=([0-9.]+)", src)
    v = env.films(m === nothing ? src : m[1])
    v === nothing && continue
    p = play(e)
    p.from, p.long = m === nothing ? 0.0 : min(something(tryparse(Float64, m[2]), 0.0), v.long), v.long
    again = haskey(e.attrs, "loop")
    at = something(env.at, 0.0)
    t, going = spot(p, at, again)
    going && (env.look.until = max(env.look.until, again ? Inf : at + p.long - t))
    shown = frame(v, t)
    shown === nothing || return (shown, going)
  end
  (nothing, false)
end

"The box of a part of a form, or nothing when the element is laid out like any other"
control(e::Element, s::Style, env, link) = begin
  tag = e.tag
  if tag == "input"
    kind = lowercase(strip(attr(e, "type", "text")))
    kind in ("checkbox", "radio") && return piece(e, s, link; natural=(12.0, 12.0), widget=Symbol(kind), value=haskey(e.attrs, "checked") ? 1.0 : 0.0)
    if kind == "range"
      lo, hi = amount(e, "min", 0.0), amount(e, "max", 100.0)
      return piece(e, s, link; natural=(129.0, 16.0), widget=:range, value=hi > lo ? clamp((amount(e, "value", (lo + hi) / 2) - lo) / (hi - lo), 0, 1) : 0.0)
    elseif kind == "color"
      b = piece(e, s, link; natural=(44.0, 23.0), widget=:color)
      b.text = attr(e, "value", "#000000")
      return b
    elseif kind == "image"
      return nothing
    elseif haskey(BUTTONS, kind)
      return field(e, s, attr(e, "value", BUTTONS[kind]), link)
    elseif kind == "file"
      # A button, and the name of the file that's chosen
      look = child(s)
      look.display, look.background = :inline_block, 0xffe9e9eb
      look.radius = look.radiusv = sides(Len(5))
      look.padding, look.margin = (Len(2), Len(8), Len(2), Len(8)), (ZERO, Len(6), ZERO, ZERO)
      button = Box(kind=:block, style=look, children=[Box(kind=:text, style=look, text="Choose File")], atomic=true)
      b = Box(kind=:block, style=s, element=e, children=[button, Box(kind=:text, style=s, text="no file selected")], link=link)
      b.atomic = s.display in ATOMS
      return b
    end
    value = attr(e, "value")
    isempty(value) || return field(e, s, kind == "password" ? repeat('•', length(value)) : value, link)
    hint = attr(e, "placeholder", get(NO_VALUE, kind, ""))
    return field(e, s, hint, link; dim=true)
  elseif tag == "textarea"
    value = replace(text(e), r"^\r?\n" => "")
    return isempty(value) ? field(e, s, attr(e, "placeholder"), link; dim=true) : field(e, s, value, link)
  elseif tag == "select"
    options = Element[]
    gather(x) = for k in x.children
      k isa Element && (k.tag == "option" ? push!(options, k) : k.tag == "optgroup" && gather(k))
    end
    gather(e)
    label(o) = strip(haskey(o.attrs, "label") ? attr(o, "label") : replace(text(o), r"\s+" => " "))
    rows = round(Int, amount(e, "size", haskey(e.attrs, "multiple") ? 4.0 : 1.0))
    if rows > 1
      # A list of choices: each is a line
      b = field(e, s, join((label(o) for o in options[1:min(rows, length(options))]), "\n"), link)
      return b
    end
    chosen = findfirst(o -> haskey(o.attrs, "selected"), options)
    return field(e, s, isempty(options) ? "" : label(options[something(chosen, 1)]), link; widget=:select)
  elseif tag == "progress"
    most = amount(e, "max", 1.0)
    return piece(e, s, link; natural=(160.0, 16.0), widget=:progress, value=haskey(e.attrs, "value") && most > 0 ? clamp(amount(e, "value", 0.0) / most, 0, 1) : NaN)
  elseif tag == "meter"
    lo, hi = amount(e, "min", 0.0), amount(e, "max", 1.0)
    return piece(e, s, link; natural=(160.0, 16.0), widget=:meter, value=hi > lo ? clamp((amount(e, "value", 0.0) - lo) / (hi - lo), 0, 1) : 0.0)
  elseif tag == "svg"
    w, h, ratio = drawing_size(e)
    b = piece(e, s, link; widget=:svg)
    # A drawing with a shape and no size is as wide as the box that it's in. One with neither is 300 by 150.
    b.fills = w == 0 && h == 0 && !isnan(ratio)
    b.natural = w > 0 && h > 0 ? (w, h) : isnan(ratio) ? (w > 0 ? w : 300.0, h > 0 ? h : 150.0) : w > 0 ? (w, w / ratio) : h > 0 ? (h * ratio, h) : (300.0, 300.0 / ratio)
    b.shape = ratio
    b.picture = env.look
    return b
  elseif tag == "canvas"
    return piece(e, s, link; natural=(amount(e, "width", 300.0), amount(e, "height", 150.0)), widget=:canvas)
  elseif tag == "video"
    found = isempty(strip(attr(e, "poster"))) ? nothing : env.pictures(attr(e, "poster"))
    # A video that was never started shows its poster. Any other shows its picture of this moment.
    shown, going = found !== nothing && untouched(play(e)) ? (nothing, false) : playing(e, env)
    shown === nothing || return piece(e, s, link; natural=(Float64(shown.wide), Float64(shown.high)), widget=:video, picture=shown, value=going ? 1.0 : 0.0)
    return piece(e, s, link; natural=found === nothing ? (300.0, 150.0) : (Float64(found[1]), Float64(found[2])), widget=:video, picture=found === nothing ? nothing : found[3])
  elseif tag == "audio"
    return piece(e, s, link; natural=(300.0, 54.0), widget=:audio)
  elseif tag in ("iframe", "embed")
    shown = tag == "iframe" ? env.embeds(attr(e, "src")) : nothing
    shown === nothing && return piece(e, s, link; natural=(300.0, 150.0), widget=:frame)
    # A video that plays on another site shows as its picture, with its name and an arrow. The frame is a link to the video's page.
    b = piece(e, s, shown.watch; natural=(300.0, 150.0), widget=:poster, picture=shown.picture)
    b.text = shown.title
    return b
  elseif tag == "object"
    found = isempty(strip(attr(e, "data"))) ? nothing : env.pictures(attr(e, "data"))
    # With no picture, what's in the <object> stands for it
    found === nothing && return nothing
    b = piece(e, s, link; natural=(Float64(found[1]), Float64(found[2])), picture=found[3])
    b.keeps = get(found, 4, nothing)
    return b
  end
  nothing
end

"The box of what the page's CSS puts before or after what's in the element `e`: `s` is the style of that part"
part!(out, e::Element, s::Style, env, link) = begin
  count!(env.counters, s)
  kids = Box[]
  for made in generated(s.content, e, s, env)
    if made isa AbstractString
      texts!(kids, made, s, env, link)
    else
      look = child(s)
      push!(kids, Box(kind=:image, style=look, link=link, natural=(Float64(made[1]), Float64(made[2])), picture=made[3], atomic=true))
    end
  end
  b = Box(kind=KINDS[s.display], style=s, children=kids, link=link)
  b.atomic = s.display in ATOMS
  complete!(b)
  push!(out, b)
end

"Add to `out` the boxes that the node makes. `link` is where the link that the node is in goes."
add!(out, n::Text, parent::Style, env::Env, link) = texts!(out, n.text, parent, env, link)
add!(out, e::Element, parent::Style, env::Env, link) = begin
  s = env.look[e]
  s.display == :none && return
  e.tag == "a" && haskey(e.attrs, "href") && (link = strip(e.attrs["href"]))
  count!(env.counters, s, e)
  if e.tag == "br"
    push!(out, Box(kind=:break, style=s, element=e))
    return
  elseif e.tag == "wbr"
    # A place where a line can break
    push!(out, Box(kind=:text, style=parent, text="\u200b"))
    return
  elseif e.tag == "img" || (e.tag == "input" && lowercase(strip(attr(e, "type"))) == "image")
    b = piece(e, s, link)
    src, dense = source(e, env)
    found = env.pictures(src)
    if found !== nothing
      b.natural = (Float64(found[1]) / dense, Float64(found[2]) / dense)
      # A picture that moves, like a GIF, is drawn as it is at the moment that the page is drawn
      moving = env.reels(src)
      b.picture = moving === nothing ? found[3] : moving
      b.keeps = get(found, 4, nothing)
    end
    if found === nothing
      # Until a picture is there, its tag's width and height say what shape it has
      w, h = tryparse(Float64, strip(attr(e, "width"))), tryparse(Float64, strip(attr(e, "height")))
      w !== nothing && h !== nothing && w > 0 && h > 0 && (b.shape = w / h)
    end
    if found === nothing && !isempty(strip(attr(e, "alt")))
      # A picture that there isn't is as big as the words that stand for it, with 2 px round them, as in a browser
      b.text = strip(attr(e, "alt"))
      f = font(s.family, s.size, s.weight, s.italic, s.stretch)
      b.natural = (4.0 + min(1024.0, ceil(width(f, b.text))), 4.0 + min(256.0, f.ascent + f.descent))
    end
    push!(out, b)
    return
  end
  made = control(e, s, env, link)
  if made !== nothing
    push!(out, made)
    return
  end
  kids = Box[]
  push!(env.counters.made, String[])
  # The bullet or the number of a list item, where it's in the item's text
  mark = ""
  look = get(env.look.marker, e, nothing)
  if s.display == :list_item
    values = get(env.counters.values, "list-item", Int[])
    said = look === nothing ? "" : lowercase(look.content)
    mark = !(said in ("", "normal", "none")) ? join(x for x in generated(look.content, e, look, env) if x isa AbstractString) : said == "none" ? "" :
           s.listtype == :text ? s.listtext : marker(s.listtype, isempty(values) ? 1 : values[end])
    if s.listinside && !isempty(mark)
      texts!(kids, mark * (s.listtype == :text ? "" : " "), something(look, s), env, link)
      mark = ""
    end
  end
  before, after = get(env.look.before, e, nothing), get(env.look.after, e, nothing)
  before === nothing || part!(kids, e, before, env, link)
  for c in e.children
    add!(kids, c, s, env, link)
  end
  after === nothing || part!(kids, e, after, env, link)
  for name in pop!(env.counters.made)
    values = get(env.counters.values, name, Int[])
    isempty(values) || pop!(values)
  end
  if s.display == :contents
    append!(out, kids)
    return
  end
  b = Box(kind=KINDS[s.display], style=s, element=e, children=kids, link=link)
  b.atomic = s.display in ATOMS
  if b.kind == :cell
    b.colspan = clamp(something(tryparse(Int, strip(attr(e, "colspan"))), 1), 1, 1000)
    b.rowspan = clamp(something(tryparse(Int, strip(attr(e, "rowspan"))), 1), 0, 65534)
  end
  b.marker = mark
  b.markerstyle = look
  if s.display == :list_item && !isempty(s.listimage) && !s.listinside
    m = match(r"^url\(\s*(?:\"([^\"]*)\"|'([^']*)'|([^)]*?))\s*\)"i, s.listimage)
    b.markerimage = m === nothing ? nothing : env.pictures(String(strip(something(m[1], m[2], m[3]))))
  end
  complete!(b)
  push!(out, b)
end

"Wrap each run of `b`'s children for which `ok` is true in a box that `wrap` makes of them"
wrap_runs!(wrap, b::Box, ok) = begin
  any(ok, b.children) || return
  out, run = Box[], Box[]
  flush() = (isempty(run) || push!(out, wrap(copy(run))); empty!(run))
  for c in b.children
    ok(c) ? push!(run, c) : (flush(); push!(out, c))
  end
  flush()
  b.children = out
end

"Make the boxes in `b` whole: see the top of this file"
complete!(b::Box) = begin
  kids = b.children
  # The parts of a table that are in no table get one
  if b.kind in (:table, :group, :row)
    filter!(c -> !blank(c), kids)
  end
  b.kind == :row || wrap_runs!(ks -> complete!(anonymous(:row, b, ks)), b, c -> c.kind == :cell)
  if b.kind == :table
    wrap_runs!(ks -> complete!(anonymous(:row, b, ks)), b, c -> !(c.kind in (:group, :row, :caption, :column)))
  elseif b.kind == :group
    wrap_runs!(ks -> complete!(anonymous(:row, b, ks)), b, c -> c.kind != :row)
  elseif b.kind == :row
    wrap_runs!(ks -> complete!(anonymous(:cell, b, ks)), b, c -> c.kind != :cell)
  else
    wrap_runs!(b, c -> c.kind in (:group, :row, :caption, :column)) do ks
      t = anonymous(:table, b, ks)
      t.style.display = :table
      t.atomic = b.kind == :inline
      t
    end
  end
  # An inline box with a block in it is a block
  if b.kind == :inline && any(c -> !inline(c) && !floats(c) && !placed(c), b.children)
    b.kind = :block
    s = child(b.style)
    s.display = :block
    s.position = b.style.position
    s.inset = b.style.inset
    s.zindex = b.style.zindex
    b.style = s
  end
  if flexes(b) || grids(b)
    # Each thing right in a flex box or a grid is a block. Text that's right in it gets a block, and spaces alone are nothing.
    out, run = Box[], Box[]
    flush() = begin
      all(c -> c.kind == :text && all(isspace, c.text), run) || push!(out, anonymous(:block, b, copy(run)))
      empty!(run)
    end
    for c in b.children
      if c.kind in (:text, :break)
        push!(run, c)
      else
        flush()
        c.kind == :inline && (c.kind = :block)
        c.atomic = false
        push!(out, c)
      end
    end
    flush()
    foreach(c -> placed(c) || (c.item = true), out)
    b.children = out
  elseif b.kind in (:block, :cell, :caption) && any(c -> !inline(c) && !floats(c) && !placed(c), b.children)
    # Text beside a block gets a block of its own
    out, run = Box[], Box[]
    wrap() = begin
      all(c -> blank(c) || floats(c) || placed(c), run) ? append!(out, filter(!blank, run)) : push!(out, anonymous(:block, b, copy(run)))
      empty!(run)
    end
    for c in b.children
      inline(c) || ((floats(c) || placed(c)) && !isempty(run)) ? push!(run, c) : (wrap(); push!(out, c))
    end
    wrap()
    b.children = out
  end
  b
end

"""
The box of the page's <html> element, with the boxes of all that's in it.
`wide` and `high` are how big the window is, for a picture that has a file
for each size of window.
"""
boxes(doc::Document, look; pictures=no_pictures, films=no_pictures, reels=no_pictures, embeds=no_pictures, at=nothing, wide=1024.0, high=800.0) = begin
  out = Box[]
  env = Env(look, pictures, films, reels, embeds, at, Counters(), Float64(wide), Float64(high), IdDict{Style,Style}())
  add!(out, doc.root, Style(), env, "")
  isempty(out) ? Box(kind=:block, style=Style(display=:block)) : (out[1].kind = :block; out[1])
end
