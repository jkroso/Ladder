# Reads CSS, and says which of its rules are for an element.
#
#     rules = sheet("p.note > b { color: red; margin: 0 !important }")
#     r = rules[1]
#     matches(r.selector, element)     # true when the rule is for the element
#     r.selector.weight                # how specific it is: (ids, classes, tags)
#     r.selector.pseudo                # :none, or the part of the element that it's for: :before, :after, :marker
#     r.declarations                   # each with its name, its value and whether it's !important
#     r.media                          # what each @media round the rule asks of the page
#     media("screen and (max-width: 600px)", 500)   # true on a page 500 px wide
#     with(() -> media("(prefers-color-scheme: dark)", 500), DARK => true)   # true on a screen in dark mode
#     declarations("color: red; margin: 0")         # what a style attribute says
#
# A selector can have tags, classes, ids, what an attribute says, the words
# between two parts (a space, `>`, `+`, `~`), and these: :first-child,
# :last-child, :only-child, :nth-child (with `of`), :nth-last-child, the same
# for a type (:first-of-type, :nth-of-type and so on), :not, :is, :where, :has,
# :link, :root, :empty, :checked, :disabled, :enabled, :required, :optional,
# :read-only, :read-write, :placeholder-shown, :open, :lang and :dir. A rule
# for the mouse or the keyboard (:hover, :focus) is for nothing, since a page
# that's drawn has neither. A rule whose selector can't be read is left out,
# as a browser leaves it out.
#
# A rule can be in another rule (`.card { color: red; &:first-child { ... } .title { ... } }`).
#
# `Stylesheet` holds all that a page's CSS says: its rules, its fonts
# (@font-face), its animations (@keyframes), the first values of its
# variables (@property) and the order of its layers (@layer). `read!(s, text)`
# adds the CSS of `text` to it. An @import is read through `s.load(address)`,
# which gives the text of the sheet at an address, or nothing.

@use "./dom" Element Text attr
@use "./url" resolve
using Base.ScopedValues: ScopedValue, with

struct Declaration
  name::String
  value::String
  important::Bool
end

"A part of a selector that's about one element, like `td.wide[align=left]`"
struct Compound
  tag::String                                       # "" for any
  id::String
  classes::Vector{String}
  attrs::Vector{Tuple{String,String,String,Bool}}   # the name, how it's compared ("" for there at all, "=", "~=", "|=", "^=", "\$=", "*="), the value, and whether capitals count
  pseudos::Vector{Tuple{Symbol,Any}}
end

struct Selector
  parts::Vector{Compound}   # from the element that the rule is for, back to the left
  links::Vector{Char}       # what's between each part and the next: ' ', '>', '+' or '~'
  weight::NTuple{3,Int}
  pseudo::Symbol            # the part of the element that the rule is for (:before, :after, :marker ...), or :none for the element
end

struct Rule
  selector::Selector
  declarations::Vector{Declaration}
  media::Vector{String}
  order::Int
  layer::Int                # which of the sheet's layers it's in, or 0 for none
  container::Vector{String} # what each @container round the rule asks of the box that the element is in
end

"All that a page's CSS says"
mutable struct Stylesheet
  rules::Vector{Rule}
  faces::Vector{Dict{String,String}}                                  # what each @font-face says
  frames::Dict{String,Vector{Tuple{Float64,Vector{Declaration}}}}     # the steps of each @keyframes, by how far through each is
  props::Dict{String,String}                                          # the first value of each variable that an @property gives one
  layers::Vector{String}                                              # the names of the layers, in the order that the page names them
  load::Function                                                      # the text of the sheet at an address, or nothing
  supports::Function                                                  # true when `name: value` is a declaration that's understood
  count::Int                                                          # how many rules have been read
  wide::Float64                                                       # how big the page's window is, or NaN: a sheet that's for no such window isn't fetched
  high::Float64
end
Stylesheet(; load=address -> nothing, supports=(name, value) -> true) =
  Stylesheet(Rule[], Dict{String,String}[], Dict{String,Vector{Tuple{Float64,Vector{Declaration}}}}(), Dict{String,String}(), String[], load, supports, 0, NaN, NaN)

"Where a piece of CSS is: what's round it"
struct Scope
  media::Vector{String}
  container::Vector{String}
  layer::String       # the name of the layer that it's in, or ""
  parent::String      # the selector of the rule that it's in, or ""
  base::String        # the address of its sheet, which its addresses are from
  depth::Int          # how many sheets deep in @import it is
end

# --- addresses ----------------------------------------------------------------------------

const URL = r"url\(\s*(?:\"([^\"]*)\"|'([^']*)'|([^)\"']*?))\s*\)"i

"The value `v` with each address in a `url(...)` made whole, for a sheet at the address `base`"
absolute(v, base) = replace(v, URL => s -> begin
  m = match(URL, s)
  address = something(m[1], m[2], m[3])
  startswith(lowercase(address), "data:") || startswith(address, '#') ? s : "url(\"" * replace(resolve(base, address), '"' => "%22") * "\")"
end)

# --- reading ------------------------------------------------------------------------------

"Where the quote at `i` of `s` closes, or the end of `s`: a quote after a backslash is part of the words"
quoted(s, i) = begin
  n = lastindex(s)
  j = nextind(s, i)
  while j <= n
    s[j] == '\\' ? (j = nextind(s, j)) : s[j] == s[i] && return j
    j = nextind(s, j)
  end
  n
end

"Where the bracket at `i` of `s` closes, past strings and brackets in it, or the end of `s`"
closing(s, i, open, close) = begin
  depth = 0
  n = lastindex(s)
  while i <= n
    c = s[i]
    if c == '"' || c == '\''
      i = quoted(s, i)
    elseif c == '\\'
      i = nextind(s, i)
    elseif c == open
      depth += 1
    elseif c == close
      depth -= 1
      depth == 0 && return i
    end
    i = nextind(s, i)
  end
  n + 1
end

"`s` cut at each `at` that's in no string and no brackets"
pieces(s::AbstractString, at::Char) = begin
  out = SubString{String}[]
  s = String(s)
  from = i = firstindex(s)
  n = lastindex(s)
  while i <= n
    c = s[i]
    if c == '"' || c == '\''
      i = quoted(s, i)
    elseif c == '\\'
      i = nextind(s, i)
    elseif c == '('
      i = min(closing(s, i, '(', ')'), n)
    elseif c == '['
      i = min(closing(s, i, '[', ']'), n)
    elseif c == '{'
      i = min(closing(s, i, '{', '}'), n)
    elseif c == at
      push!(out, SubString(s, from, prevind(s, i)))
      from = nextind(s, i)
    end
    i = nextind(s, i)
  end
  from <= n && push!(out, SubString(s, from, n))
  out
end

const IMPORTANT = r"!\s*important\s*$"i

"Add to `out` what `name: value` declares. The name of a variable (`--x`) keeps its capitals."
declare!(out, piece, base="") = begin
  colon = findfirst(':', piece)
  colon === nothing && return
  name = strip(SubString(piece, firstindex(piece), prevind(piece, colon)))
  value = strip(SubString(piece, nextind(piece, colon)))
  custom = startswith(name, "--")
  custom || (name = lowercase(name))
  (isempty(name) || (!custom && (isempty(value) || occursin(r"[^a-z0-9_-]", name)))) && return
  important = occursin(IMPORTANT, value)
  important && (value = strip(replace(value, IMPORTANT => "")))
  (isempty(value) && !custom) && return
  isempty(base) || occursin("url(", value) && (value = absolute(value, base))
  push!(out, Declaration(String(name), String(value), important))
end

"What a block of CSS, or a style attribute, declares"
declarations(block::AbstractString; base="") = begin
  out = Declaration[]
  for piece in pieces(block, ';')
    declare!(out, piece, base)
  end
  out
end

"The text of a sheet with its comments taken out"
clean(text) = replace(String(text), r"/\*.*?(\*/|$)"s => " ", "<!--" => " ", "-->" => " ")

"""
The rules of a sheet of CSS, in its order. `order` is how many rules the page
had before it. For all that a sheet says, see `Stylesheet` and `read!`.
"""
sheet(text::AbstractString; media=String[], order=0) = begin
  s = Stylesheet()
  s.count = order
  read!(s, text; media)
  s.rules
end

"Add the CSS of `text` to the sheet `s`. `base` is the address that the text is from."
read!(s::Stylesheet, text::AbstractString; media=String[], base="", layer="") =
  (read!(s, clean(text), Scope(Vector{String}(media), String[], layer, "", base, 0)); s)

"Which of the layers of `s` the layer `name` is: a new one, when the page hasn't named it yet"
layer!(s::Stylesheet, name) = begin
  isempty(name) && return 0
  i = findfirst(==(name), s.layers)
  i === nothing ? (push!(s.layers, name); length(s.layers)) : i
end

"""
Read the CSS of `text`, which is at `at`. `inrule` is true for what's in the
block of a rule: its declarations are given back, and the rules in it are
added to the sheet.
"""
read!(sheet::Stylesheet, text::String, at::Scope; inrule=false) = begin
  found = Declaration[]
  i, n = firstindex(text), lastindex(text)
  while i <= n
    (isspace(text[i]) || text[i] == ';' || text[i] == '}') && (i = nextind(text, i); continue)
    # What's before the block: a selector, or an @ rule's name and what it asks. With no block, it's a declaration.
    j = i
    while j <= n && text[j] != '{' && text[j] != ';' && text[j] != '}'
      c = text[j]
      j = c == '"' || c == '\'' ? quoted(text, j) : c == '(' ? min(closing(text, j, '(', ')'), n) :
          c == '[' ? min(closing(text, j, '[', ']'), n) : c == '\\' ? min(nextind(text, j), n) : j
      j = nextind(text, j)
    end
    before = strip(SubString(text, i, prevind(text, j)))
    if j > n || text[j] != '{'
      startswith(before, '@') ? statement!(sheet, before, at) : inrule && declare!(found, before, at.base)
      i = j > n ? j : nextind(text, j)
      continue
    end
    stop = closing(text, j, '{', '}')
    block = String(SubString(text, nextind(text, j), prevind(text, min(stop, n + 1))))
    i = stop > n ? stop : nextind(text, stop)
    # A variable can hold a block: `--x: { ... }`
    if inrule && occursin(r"^--[^:{]*:\s*$", before)
      declare!(found, before * "{" * block * "}", at.base)
    elseif startswith(before, '@')
      block!(sheet, before, block, at)
    else
      rule!(sheet, before, block, at)
    end
  end
  found
end

"The selector `inner`, which is written in a rule for `parent`, as it would be written alone"
nest(inner, parent) = begin
  wrap = length(pieces(parent, ',')) > 1 ? ":is($parent)" : String(strip(parent))
  join((occursin('&', s) || occursin(":scope", s) ? replace(s, '&' => wrap, ":scope" => wrap) : wrap * " " * strip(s) for s in pieces(inner, ',')), ", ")
end

"Add the rules of the selectors `before` with the declarations of `block`, and the rules that are in the block"
rule!(sheet::Stylesheet, before, block, at::Scope) = begin
  text = isempty(at.parent) ? String(before) : nest(before, at.parent)
  # The rule's own declarations come before the rules that are in it
  order = (sheet.count += 1)
  found = read!(sheet, block, Scope(at.media, at.container, at.layer, text, at.base, at.depth); inrule=true)
  add!(sheet, text, found, at, order)
end

add!(sheet::Stylesheet, text, found, at::Scope, order=(sheet.count += 1)) = begin
  isempty(found) && return
  all = selectors(text)
  # One selector that can't be read spoils the rule
  all === nothing && return
  layer = layer!(sheet, at.layer)
  for s in all
    push!(sheet.rules, Rule(s, found, at.media, order, layer, at.container))
  end
end

"Read the block of an @ rule: `before` is its name and what it asks"
block!(sheet::Stylesheet, before, block, at::Scope) = begin
  m = match(r"^@([a-zA-Z-]+)\s*(.*)$"s, before)
  m === nothing && return
  name, asks = lowercase(m[1]), String(strip(m[2]))
  inner(; media=at.media, container=at.container, layer=at.layer, parent=at.parent) = begin
    scope = Scope(media, container, layer, parent, at.base, at.depth)
    found = read!(sheet, block, scope; inrule=!isempty(parent))
    # Declarations right in an @ rule that's in a rule are for the rule's element
    isempty(parent) || add!(sheet, parent, found, scope)
  end
  if name == "media"
    inner(media=[at.media; asks])
  elseif name == "supports"
    supports(asks, sheet.supports) && inner()
  elseif name == "layer"
    # A layer with no name is one of its own
    names = isempty(asks) ? ["#" * string(length(sheet.layers) + 1)] : [String(strip(x)) for x in split(asks, ',')]
    full = isempty(at.layer) ? names[1] : at.layer * "." * names[1]
    layer!(sheet, full)
    inner(layer=full)
  elseif name == "container"
    inner(container=[at.container; asks])
  elseif name == "scope"
    start = match(r"^\((.*?)\)(?:\s*to\s*\(.*\))?\s*$"s, asks)
    start === nothing ? inner() : inner(parent=isempty(at.parent) ? String(strip(start[1])) : nest(strip(start[1]), at.parent))
  elseif name == "font-face"
    face = Dict{String,String}(d.name => d.value for d in declarations(block; base=at.base))
    isempty(face) || push!(sheet.faces, face)
  elseif name in ("keyframes", "-webkit-keyframes", "-moz-keyframes")
    steps = Tuple{Float64,Vector{Declaration}}[]
    text = String(block)
    i, n = firstindex(text), lastindex(text)
    while i <= n
      j = findnext('{', text, i)
      j === nothing && break
      stop = closing(text, j, '{', '}')
      found = declarations(SubString(text, nextind(text, j), prevind(text, min(stop, n + 1))); base=at.base)
      for key in split(SubString(text, i, prevind(text, j)), ',')
        key = lowercase(strip(key))
        at_ = key == "from" ? 0.0 : key == "to" ? 1.0 : endswith(key, '%') ? something(tryparse(Float64, chop(key)), NaN) / 100 : NaN
        isnan(at_) || push!(steps, (at_, found))
      end
      i = stop > n ? stop : nextind(text, stop)
    end
    sort!(steps; by=first, alg=MergeSort)
    key = String(strip(strip(asks), ['"', '\'']))
    isempty(steps) || (sheet.frames[key] = steps)
  elseif name == "property"
    for d in declarations(block)
      d.name == "initial-value" && (sheet.props[asks] = d.value)
    end
  end
  nothing
end

"Read an @ rule that has no block: an @import, or the order of the layers"
statement!(sheet::Stylesheet, before, at::Scope) = begin
  m = match(r"^@([a-zA-Z-]+)\s*(.*)$"s, before)
  m === nothing && return
  name, asks = lowercase(m[1]), String(strip(m[2]))
  if name == "layer"
    for x in split(asks, ',')
      layer!(sheet, isempty(at.layer) ? String(strip(x)) : at.layer * "." * strip(x))
    end
  elseif name == "import" && at.depth < 8
    m = match(r"^(?:url\(\s*(?:\"([^\"]*)\"|'([^']*)'|([^)]*?))\s*\)|\"([^\"]*)\"|'([^']*)')\s*(.*)$"is, asks)
    m === nothing && return
    address = resolve(at.base, something(m[1], m[2], m[3], m[4], m[5]))
    rest = String(strip(m[6]))
    layer = at.layer
    if (l = match(r"^layer(?:\(\s*([^)]*?)\s*\))?(?=\s|$)\s*"i, rest)) !== nothing
      own = l[1] === nothing ? "#" * string(length(sheet.layers) + 1) : String(l[1])
      layer = isempty(layer) ? own : layer * "." * own
      layer!(sheet, layer)
      rest = rest[nextind(rest, 0, length(l.match) + 1):end]
    end
    if startswith(lowercase(rest), "supports(")
      stop = closing(rest, findfirst('(', rest), '(', ')')
      supports(rest[10:prevind(rest, min(stop, lastindex(rest) + 1))], sheet.supports) || return
      rest = stop >= lastindex(rest) ? "" : String(strip(rest[nextind(rest, stop):end]))
    end
    # A sheet for a printer, or for a window of another size, isn't asked for
    isnan(sheet.wide) || all(q -> media(q, sheet.wide, sheet.high), isempty(rest) ? at.media : [at.media; rest]) || return
    text = try sheet.load(address) catch; nothing end
    text === nothing && return
    read!(sheet, clean(text isa AbstractString ? text : String(copy(text))), Scope(isempty(rest) ? at.media : [at.media; rest], at.container, layer, "", address, at.depth + 1))
  end
  nothing
end

# --- selectors ----------------------------------------------------------------------------

const NAME = r"^(?:[-_a-zA-Z0-9]|[^\x00-\x7f]|\\[0-9a-fA-F]{1,6}\s?|\\.)+"
unescape(s) = replace(s, r"\\([0-9a-fA-F]{1,6})\s?" => (x -> string(Char(Base.parse(UInt32, strip(x[2:end]), base=16)))), r"\\(.)" => s"\1")
const ATTR = r"^\[\s*(?:[-_a-zA-Z0-9*]*\|)?((?:[-_a-zA-Z0-9:]|\\.)+)\s*(?:([~|^$*]?=)\s*(?:\"([^\"]*)\"|'([^']*)'|([^\]\s]*))\s*(?:([iIsS])\s*)?)?\]"
# These are true of no element of a page that's drawn: there's no mouse, no keyboard, and nothing has been visited
const NEVER = Set(["hover", "active", "focus", "focus-visible", "focus-within", "visited", "target", "target-within", "indeterminate", "default",
                   "selection", "backdrop", "fullscreen", "modal", "popover-open", "picture-in-picture", "playing", "paused", "seeking",
                   "buffering", "stalled", "muted", "volume-locked", "current", "past", "future", "user-valid", "user-invalid", "valid", "invalid",
                   "in-range", "out-of-range", "autofill", "host", "host-context", "state", "local-link", "target-current", "blank",
                   "active-view-transition", "active-view-transition-type", "has-slotted", "drop", "placeholder"])
# The parts of an element that a rule can be for. `:other` is a part that's never drawn.
const ELEMENTS = Dict("before" => :before, "after" => :after, "marker" => :marker, "placeholder" => :placeholder, "first-letter" => :first_letter,
                      "first-line" => :first_line)
const PLAIN = Set(["first-child", "last-child", "only-child", "root", "empty", "first-of-type", "last-of-type", "only-of-type", "checked", "disabled",
                   "enabled", "required", "optional", "read-only", "read-write", "placeholder-shown", "open"])

"`a` and `b` of an+b, as :nth-child writes them, or nothing"
nth(s) = begin
  s = replace(lowercase(strip(s)), " " => "")
  s == "odd" && return (2, 1)
  s == "even" && return (2, 0)
  m = match(r"^([+-]?\d*)n([+-]\d+)?$", s)
  m === nothing && return (b = tryparse(Int, s)) === nothing ? nothing : (0, b)
  a = m[1] in ("", "+") ? 1 : m[1] == "-" ? -1 : Base.parse(Int, m[1])
  (a, m[2] === nothing ? 0 : Base.parse(Int, m[2]))
end

"""
The part of a selector at the start of `s`, the rest of `s`, and the part of
the element that it names (`::before`), or nothing when it can't be read
"""
compound(s::AbstractString) = begin
  tag, id = "", ""
  classes, attrs, pseudos = String[], Tuple{String,String,String,Bool}[], Tuple{Symbol,Any}[]
  any = false
  element = :none
  # A name before a | says which kind of tag: all kinds are one here
  (m = match(r"^(?:[-_a-zA-Z0-9]+|\*)?\|(?!=)", s)) !== nothing && (s = SubString(s, 1 + ncodeunits(m.match)))
  while !isempty(s)
    c = s[1]
    if c == '*'
      s = SubString(s, 2)
    elseif c == '#' || c == '.'
      m = match(NAME, SubString(s, 2))
      m === nothing && return nothing
      c == '#' ? (id = unescape(m.match)) : push!(classes, unescape(m.match))
      s = SubString(s, 2 + ncodeunits(m.match))
    elseif c == '['
      m = match(ATTR, s)
      m === nothing && return nothing
      push!(attrs, (lowercase(unescape(m[1])), something(m[2], ""), String(something(m[3], m[4], m[5], "")), m[6] === nothing || lowercase(m[6]) != "i"))
      s = SubString(s, 1 + ncodeunits(m.match))
    elseif c == ':'
      m = match(r"^(::?)([-a-zA-Z]+)", s)
      m === nothing && return nothing
      name = lowercase(m[2])
      s = SubString(s, 1 + ncodeunits(m.match))
      inside = nothing
      if startswith(s, '(')
        stop = closing(s, 1, '(', ')')
        stop > lastindex(s) && return nothing
        inside = strip(SubString(s, 2, prevind(s, stop)))
        s = SubString(s, nextind(s, stop))
      end
      if m[1] == "::" || (haskey(ELEMENTS, name) && name != "placeholder" && inside === nothing && name in ("before", "after", "first-letter", "first-line"))
        # A part of the element. What comes after it (`::before:hover`) is for nothing.
        element == :none || return nothing
        element = get(ELEMENTS, name, :other)
      elseif element != :none
        push!(pseudos, (:never, nothing))
      elseif name in ("is", "where", "matches", "-webkit-any", "-moz-any", "not") && inside !== nothing
        inner = selectors(inside)
        # What can't be read in :is() is for nothing, and spoils nothing else
        inner === nothing && name == "not" && return nothing
        inner = inner === nothing ? Selector[] : inner
        Base.any(x -> x.pseudo != :none, inner) && return nothing
        push!(pseudos, (name == "not" ? :not : name == "where" ? :where : :is, inner))
      elseif name == "has" && inside !== nothing
        inner = Tuple{Char,Selector}[]
        for piece in pieces(inside, ',')
          piece = strip(piece)
          lead = match(r"^([>+~])\s*", piece)
          one = selector(lead === nothing ? piece : SubString(piece, 1 + ncodeunits(lead.match)))
          one === nothing && return nothing
          push!(inner, (lead === nothing ? ' ' : lead[1][1], one))
        end
        push!(pseudos, (:has, inner))
      elseif name in ("nth-child", "nth-last-child", "nth-of-type", "nth-last-of-type") && inside !== nothing
        of = match(r"^(.*?)\sof\s(.*)$"is, inside)
        ab = nth(of === nothing ? inside : of[1])
        ab === nothing && return nothing
        among = of === nothing ? nothing : selectors(of[2])
        of === nothing || among !== nothing || return nothing
        push!(pseudos, (Symbol(replace(name, '-' => '_')), (ab[1], ab[2], among)))
      elseif name in ("lang", "dir") && inside !== nothing
        push!(pseudos, (Symbol(name), lowercase(strip(strip(inside), ['"', '\'']))))
      elseif name in ("link", "any-link", "-webkit-any-link", "-moz-any-link")
        push!(pseudos, (:link, nothing))
      elseif name in PLAIN && inside === nothing
        push!(pseudos, (Symbol(replace(name, '-' => '_')), nothing))
      elseif name in ("defined", "scope") && inside === nothing
        name == "scope" && push!(pseudos, (:root, nothing))
      elseif name in NEVER || startswith(name, "-")
        push!(pseudos, (:never, nothing))
      else
        return nothing
      end
    elseif (m = match(NAME, s)) !== nothing && !any && isempty(id) && isempty(classes) && isempty(attrs) && isempty(pseudos) && isempty(tag)
      tag = lowercase(unescape(m.match))
      s = SubString(s, 1 + ncodeunits(m.match))
    else
      break
    end
    any = true
  end
  any ? (Compound(tag, id, classes, attrs, pseudos), s, element) : nothing
end

most(ws) = isempty(ws) ? (0, 0, 0) : maximum(ws)

"How specific a part of a selector is: how many ids, how many classes and the like, and how many tags"
weight(c::Compound) = begin
  w = (Int(!isempty(c.id)), length(c.classes) + length(c.attrs), Int(!isempty(c.tag)))
  for (kind, arg) in c.pseudos
    w = w .+ (kind in (:not, :is) ? most([x.weight for x in arg]) : kind == :has ? most([x[2].weight for x in arg]) : kind == :where ? (0, 0, 0) :
              kind in (:nth_child, :nth_last_child) && arg[3] !== nothing ? (0, 1, 0) .+ most([x.weight for x in arg[3]]) : (0, 1, 0))
  end
  w
end

"The selector that `s` writes, or nothing when it can't be read"
selector(s::AbstractString) = begin
  parts, links = Compound[], Char[]
  s = strip(s)
  isempty(s) && return nothing
  element = :none
  while true
    found = compound(s)
    found === nothing && return nothing
    part, rest, element = found
    push!(parts, part)
    isempty(strip(rest)) && break
    # A part of an element (`::before`) is the last thing in a selector
    element == :none || return nothing
    m = match(r"^\s*([>+~])\s*|^\s+", rest)
    m === nothing && return nothing
    push!(links, m[1] === nothing ? ' ' : m[1][1])
    s = SubString(rest, 1 + ncodeunits(m.match))
  end
  Selector(reverse(parts), reverse(links), reduce((a, b) -> a .+ b, weight.(parts)) .+ (0, 0, Int(element != :none)), element)
end

"The selectors that `s` writes with commas between them, or nothing when one of them can't be read"
selectors(s::AbstractString) = begin
  out = Selector[]
  for piece in pieces(s, ',')
    one = selector(piece)
    one === nothing && return nothing
    push!(out, one)
  end
  isempty(out) ? nothing : out
end

# --- which elements a selector is for -----------------------------------------------------

"The elements beside `e` in its parent, and which of them `e` is"
siblings(e::Element) = begin
  e.parent === nothing && return (Element[e], 1)
  all = Element[c for c in e.parent.children if c isa Element]
  (all, something(findfirst(c -> c === e, all), 1))
end

"The element before `e` in its parent, or nothing"
before(e::Element) = begin
  all, i = siblings(e)
  i > 1 ? all[i-1] : nothing
end

compare(how, has, wants, exact=true) = begin
  exact || ((has, wants) = (lowercase(has), lowercase(wants)))
  how == "" ? true : how == "=" ? has == wants : how == "~=" ? wants in split(has) : how == "|=" ? has == wants || startswith(has, wants * "-") :
  isempty(wants) ? false : how == "^=" ? startswith(has, wants) : how == "\$=" ? endswith(has, wants) : occursin(wants, has)
end

nth_ok(a, b, i) = a == 0 ? i == b : (i - b) % a == 0 && (i - b) ÷ a >= 0

"What `name` says in the tag of `e` or of the nearest element round it that says it, or \"\""
nearest(e::Element, name) = begin
  while e !== nothing
    haskey(e.attrs, name) && return e.attrs[name]
    e = e.parent
  end
  ""
end

const CONTROLS = ("input", "button", "select", "textarea", "option", "optgroup", "fieldset")

"True when some element in `e` is one that `ok` is true of"
within(ok, e::Element) = any(c -> c isa Element && (ok(c) || within(ok, c)), e.children)

"True when what `:has(...)` asks is true of `e`: `link` is what's between `e` and the element that `s` is for"
holds(e::Element, link::Char, s::Selector) =
  link == '>' ? any(c -> c isa Element && matches(s, c), e.children) :
  link == ' ' ? within(c -> matches(s, c), e) :
  begin
    all, i = siblings(e)
    link == '+' ? i < length(all) && matches(s, all[i+1]) : any(c -> matches(s, c), @view all[i+1:end])
  end

"True when the part `c` of a selector is for the element `e`"
matches(c::Compound, e::Element) = begin
  isempty(c.tag) || c.tag == e.tag || return false
  isempty(c.id) || attr(e, "id") == c.id || return false
  if !isempty(c.classes)
    has = split(attr(e, "class"))
    all(k -> k in has, c.classes) || return false
  end
  for (name, how, wants, exact) in c.attrs
    haskey(e.attrs, name) && compare(how, e.attrs[name], wants, exact) || return false
  end
  for (kind, arg) in c.pseudos
    ok = if kind == :never
      false
    elseif kind == :link
      e.tag in ("a", "area") && haskey(e.attrs, "href")
    elseif kind == :root
      e.parent === nothing
    elseif kind == :empty
      !any(n -> n isa Element || !isempty(n.text), e.children)
    elseif kind == :not
      !any(x -> matches(x, e), arg)
    elseif kind == :is || kind == :where
      any(x -> matches(x, e), arg)
    elseif kind == :has
      any(x -> holds(e, x[1], x[2]), arg)
    elseif kind == :checked
      (e.tag == "input" && haskey(e.attrs, "checked")) || (e.tag == "option" && haskey(e.attrs, "selected"))
    elseif kind == :disabled
      e.tag in CONTROLS && haskey(e.attrs, "disabled")
    elseif kind == :enabled
      e.tag in CONTROLS && !haskey(e.attrs, "disabled")
    elseif kind == :required
      e.tag in ("input", "select", "textarea") && haskey(e.attrs, "required")
    elseif kind == :optional
      e.tag in ("input", "select", "textarea") && !haskey(e.attrs, "required")
    elseif kind == :read_write
      (e.tag in ("input", "textarea") && !haskey(e.attrs, "readonly") && !haskey(e.attrs, "disabled")) || haskey(e.attrs, "contenteditable")
    elseif kind == :read_only
      !((e.tag in ("input", "textarea") && !haskey(e.attrs, "readonly") && !haskey(e.attrs, "disabled")) || haskey(e.attrs, "contenteditable"))
    elseif kind == :placeholder_shown
      e.tag in ("input", "textarea") && haskey(e.attrs, "placeholder") && isempty(attr(e, "value"))
    elseif kind == :open
      e.tag in ("details", "dialog") && haskey(e.attrs, "open")
    elseif kind == :lang
      said = lowercase(nearest(e, "lang"))
      said == arg || startswith(said, arg * "-")
    elseif kind == :dir
      (lowercase(nearest(e, "dir")) == "rtl") == (arg == "rtl")
    else
      all, i = siblings(e)
      same() = filter(x -> x.tag == e.tag, all)
      among(xs, sels) = sels === nothing ? xs : filter(x -> any(s -> matches(s, x), sels), xs)
      at(xs) = something(findfirst(x -> x === e, xs), 0)
      kind == :first_child ? i == 1 : kind == :last_child ? i == length(all) : kind == :only_child ? length(all) == 1 :
      kind == :nth_child ? (xs = among(all, arg[3]); k = at(xs); k > 0 && nth_ok(arg[1], arg[2], k)) :
      kind == :nth_last_child ? (xs = among(all, arg[3]); k = at(xs); k > 0 && nth_ok(arg[1], arg[2], length(xs) - k + 1)) :
      kind == :first_of_type ? findfirst(x -> x.tag == e.tag, all) == i : kind == :last_of_type ? findlast(x -> x.tag == e.tag, all) == i :
      kind == :only_of_type ? count(x -> x.tag == e.tag, all) == 1 :
      kind == :nth_of_type ? nth_ok(arg[1], arg[2], at(same())) :
      kind == :nth_last_of_type ? (xs = same(); nth_ok(arg[1], arg[2], length(xs) - at(xs) + 1)) : false
    end
    ok || return false
  end
  true
end

"True when the selector `s` is for the element `e`, or for a part of it"
matches(s::Selector, e::Element) = begin
  # A rule for a child of some tag is for no element whose parent has another tag: this is quick to see
  if !isempty(s.links) && s.links[1] == '>'
    p = e.parent
    (p === nothing || (!isempty(s.parts[2].tag) && s.parts[2].tag != p.tag)) && return false
  end
  matches(s.parts[1], e) && rest(s, 1, e)
end

"True when the parts of `s` after part `i`, which is for `e`, are for the elements round `e`"
rest(s::Selector, i, e::Element) = begin
  i > length(s.links) && return true
  link, part = s.links[i], s.parts[i+1]
  if link == '>'
    p = e.parent
    p !== nothing && matches(part, p) && rest(s, i + 1, p)
  elseif link == ' '
    p = e.parent
    while p !== nothing
      matches(part, p) && rest(s, i + 1, p) && return true
      p = p.parent
    end
    false
  elseif link == '+'
    b = before(e)
    b !== nothing && matches(part, b) && rest(s, i + 1, b)
  else
    all, at = siblings(e)
    any(b -> matches(part, b) && rest(s, i + 1, b), @view all[1:at-1])
  end
end

# --- what a rule asks of the page: @media, @container and @supports -----------------------

"`s` as its words and its bracketed parts: each is `(true, what's in the brackets)` or `(false, the word)`"
groups(s::AbstractString) = begin
  out = Tuple{Bool,String}[]
  s = String(s)
  i, n = firstindex(s), lastindex(s)
  while i <= n
    c = s[i]
    if isspace(c)
      i = nextind(s, i)
    elseif c == '('
      stop = closing(s, i, '(', ')')
      push!(out, (true, String(strip(SubString(s, nextind(s, i), prevind(s, min(stop, n + 1)))))))
      i = stop > n ? stop : nextind(s, stop)
    else
      j = i
      while j <= n && !isspace(s[j]) && s[j] != '('
        j = nextind(s, j)
      end
      push!(out, (false, String(SubString(s, i, prevind(s, j)))))
      i = j
    end
  end
  out
end

"""
Whether what `toks` asks is so: bracketed parts with `not`, `and` and `or`
between them. `test(inside)` says whether one bracketed part is so, and
`call(name, inside)` whether a part like `selector(...)` is.
"""
logic(toks, test, call=(name, inside) -> false) = begin
  value(i) = begin
    i > length(toks) && return (false, i)
    group, text = toks[i]
    group && return (test(text), i + 1)
    text == "not" && return ((v, j) = value(i + 1); (!v, j))
    # A word with brackets after it
    i < length(toks) && toks[i+1][1] ? (call(text, toks[i+1][2]), i + 2) : (false, i + 1)
  end
  acc, i = value(1)
  while i <= length(toks)
    op = toks[i][2]
    (toks[i][1] || !(op in ("and", "or"))) && return false
    v, i = value(i + 1)
    acc = op == "and" ? acc && v : acc || v
  end
  acc
end

const QUERY_UNITS = Dict("" => 1.0, "px" => 1.0, "em" => 16.0, "rem" => 16.0, "ch" => 8.0, "ex" => 8.0, "pt" => 4 / 3, "pc" => 16.0, "in" => 96.0, "cm" => 96 / 2.54,
                         "mm" => 96 / 25.4)

"How many px a length of a media query is: a number with a unit, or a sum like `calc(15rem + 2 * 1rem)`"
media_px(v) = begin
  v = strip(lowercase(v))
  m = match(r"^(-?[0-9.]+)\s*([a-z]*)$", v)
  if m !== nothing
    x = tryparse(Float64, m[1])
    return x === nothing || !haskey(QUERY_UNITS, m[2]) ? nothing : x * QUERY_UNITS[m[2]]
  end
  startswith(v, "calc(") || return nothing
  toks = [t.match for t in eachmatch(r"calc\(|\(|\)|[*/]|[+-](?=\s)|-?[0-9.]+[a-z]*", v)]
  i = Ref(1)
  peek() = i[] <= length(toks) ? toks[i[]] : ""
  take() = (t = peek(); i[] += 1; t)
  value() = begin
    t = take()
    if endswith(t, "(")
      x = total()
      take()
      return x
    end
    n = match(r"^(-?[0-9.]+)([a-z]*)$", t)
    n === nothing && return nothing
    x = tryparse(Float64, n[1])
    x === nothing || !haskey(QUERY_UNITS, n[2]) ? nothing : x * QUERY_UNITS[n[2]]
  end
  product() = begin
    a = value()
    while peek() in ("*", "/")
      op = take()
      b = value()
      (a === nothing || b === nothing) && return nothing
      a = op == "*" ? a * b : b == 0 ? nothing : a / b
    end
    a
  end
  total() = begin
    a = product()
    while peek() in ("+", "-")
      op = take()
      b = product()
      (a === nothing || b === nothing) && return nothing
      a = op == "+" ? a + b : a - b
    end
    a
  end
  total()
end

# How many pixels the screen has to the px. A page is drawn for a screen like a Mac's.
const DENSITY = 2.0

"How many pixels to the px a media query's `2`, `2dppx` or `192dpi` means"
density(v) = begin
  m = match(r"^([0-9.]+)\s*(dppx|x|dpi|dpcm)?$", strip(lowercase(v)))
  m === nothing && return nothing
  x = tryparse(Float64, m[1])
  x === nothing ? nothing : m[2] == "dpi" ? x / 96 : m[2] == "dpcm" ? x * 2.54 / 96 : x
end

"The number that `16/9` or `1.5` writes"
ratio(v) = begin
  parts = split(v, '/')
  a = tryparse(Float64, strip(parts[1]))
  b = length(parts) > 1 ? tryparse(Float64, strip(parts[2])) : 1.0
  a === nothing || b === nothing || b == 0 ? nothing : a / b
end

"""
True while a page is laid out for a screen in dark mode, as a Mac is at
night when its appearance is Auto: a media query's `prefers-color-scheme` is
`dark` then. Set it with `with(f, DARK => true)`.
"""
const DARK = ScopedValue(false)

# What a page that's drawn says of each thing that a media query can ask about, when it's a word
const WORDS = Dict("prefers-reduced-motion" => "no-preference", "prefers-contrast" => "no-preference",
                   "prefers-reduced-transparency" => "no-preference", "prefers-reduced-data" => "no-preference", "hover" => "hover", "any-hover" => "hover",
                   "pointer" => "fine", "any-pointer" => "fine", "scripting" => "none", "display-mode" => "browser", "color-gamut" => "srgb",
                   "forced-colors" => "none", "inverted-colors" => "none", "update" => "fast", "overflow-block" => "scroll", "overflow-inline" => "scroll",
                   "dynamic-range" => "standard", "video-dynamic-range" => "standard", "scan" => "progressive")

"What a box or a screen `wide` by `high` px has of the thing `name` that a query asks about: a number, a word, or nothing"
feature(name, wide, high) =
  name in ("width", "device-width", "inline-size") ? Float64(wide) : name in ("height", "device-height", "block-size") ? Float64(high) :
  name in ("aspect-ratio", "device-aspect-ratio") ? wide / max(high, 1e-9) : name == "orientation" ? (wide > high ? "landscape" : "portrait") :
  name in ("resolution", "-webkit-device-pixel-ratio", "device-pixel-ratio") ? DENSITY : name == "color" ? 8.0 :
  name in ("monochrome", "color-index", "grid") ? 0.0 : name == "-webkit-transform-3d" ? 1.0 :
  name == "prefers-color-scheme" ? (DARK[] ? "dark" : "light") : get(WORDS, name, nothing)

"The number that a query's value `v` is, for the thing `name`"
amount(name, v) = name in ("resolution", "-webkit-device-pixel-ratio", "device-pixel-ratio") ? density(v) :
                  name in ("aspect-ratio", "device-aspect-ratio") ? ratio(v) : media_px(v)

"True when one bracketed part of a query, like `min-width: 600px` or `400px <= width < 900px`, is so"
asks(inside, wide, high) = begin
  inside = strip(inside)
  (startswith(inside, '(') || startswith(inside, "not ") || startswith(inside, "not(")) && return logic(groups(inside), x -> asks(x, wide, high))
  if (m = match(r"^([a-z-]+)\s*:\s*(.+)$", inside)) !== nothing
    name, v = m[1], strip(m[2])
    old = startswith(name, "-webkit-")
    bare = old ? name[9:end] : name
    low, high_ = startswith(bare, "min-"), startswith(bare, "max-")
    (low || high_) && (bare = bare[5:end])
    name = old ? "-webkit-" * bare : bare
    has = feature(name, wide, high)
    has === nothing && return false
    has isa String && return has == v
    x = amount(name, v)
    x === nothing ? false : low ? has >= x - 1e-6 : high_ ? has <= x + 1e-6 : abs(has - x) < 0.01
  elseif (m = match(r"^(.+?)\s*(<=|>=|<|>|=)\s*(.+?)(?:\s*(<=|>=|<|>)\s*(.+))?$", inside)) !== nothing
    than(a, op, b) = op == "<=" ? a <= b + 1e-6 : op == ">=" ? a >= b - 1e-6 : op == "<" ? a < b : op == ">" ? a > b : abs(a - b) < 0.01
    if m[4] !== nothing
      has = feature(m[3], wide, high)
      a, b = amount(m[3], m[1]), amount(m[3], m[5])
      has isa Float64 && a !== nothing && b !== nothing && than(a, m[2], has) && than(has, m[4], b)
    elseif (has = feature(m[1], wide, high)) isa Float64
      (x = amount(m[1], m[3])) !== nothing && than(has, m[2], x)
    elseif (has = feature(m[3], wide, high)) isa Float64
      (x = amount(m[3], m[1])) !== nothing && than(x, m[2], has)
    else
      false
    end
  else
    has = feature(inside, wide, high)
    has isa String ? has != "none" : has !== nothing && has != 0
  end
end

"True when a page `wide` px wide and `high` px high, on a screen, is what the media query `q` asks for"
media(q::AbstractString, wide, high=800) = begin
  isempty(strip(q)) && return true
  any(pieces(lowercase(q), ',')) do one
    toks = groups(one)
    isempty(toks) && return true
    negate = false
    i = 1
    if !toks[1][1] && toks[1][2] == "only"
      i = 2
    elseif !toks[1][1] && toks[1][2] == "not" && length(toks) > 1 && !toks[2][1]
      negate = true
      i = 2
    end
    ok = true
    if i <= length(toks) && !toks[i][1] && toks[i][2] != "not"
      ok = toks[i][2] in ("all", "screen")
      i += 1
      i <= length(toks) && !toks[i][1] && toks[i][2] == "and" && (i += 1)
    end
    ok = ok && (i > length(toks) || logic(toks[i:end], x -> asks(x, wide, high)))
    negate ? !ok : ok
  end
end

"The name that the container query `q` asks for, or \"\" for any container"
container_name(q::AbstractString) = begin
  toks = groups(lowercase(q))
  !isempty(toks) && !toks[1][1] && toks[1][2] != "not" && !(length(toks) > 1 && toks[2][1] && toks[1][2] == "style") ? toks[1][2] : ""
end

"True when a box `wide` by `high` px is what the container query `q` asks for"
container(q::AbstractString, wide, high) = begin
  toks = groups(lowercase(q))
  isempty(container_name(q)) || popfirst!(toks)
  isempty(toks) || logic(toks, x -> asks(x, wide, high))
end

"True when what an @supports asks is so. `known(name, value)` says whether a declaration is understood."
supports(q::AbstractString, known) = begin
  test(inside) = begin
    inside = strip(inside)
    (startswith(inside, '(') || startswith(lowercase(inside), "not ") || startswith(lowercase(inside), "not(")) && return supports(inside, known)
    found = Declaration[]
    declare!(found, inside)
    !isempty(found) && known(found[1].name, found[1].value)
  end
  call(name, inside) = name == "selector" ? selectors(inside) !== nothing : name in ("font-tech", "font-format") && !occursin("color", lowercase(inside))
  toks = [(g, g ? t : lowercase(t)) for (g, t) in groups(q)]
  isempty(toks) || logic(toks, test, call)
end
