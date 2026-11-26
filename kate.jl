# Colours code with the syntax definitions of KDE's editor Kate. Each is an XML
# file in the folder syntax/, from https://invent.kde.org/frameworks/syntax-highlighting,
# which has about 300 more. syntax/README.md says where each came from and its
# licence. To add a language, put its file, and the files that it includes, in
# that folder.
#
# A definition has contexts, and each context has a list of rules. Ladder reads
# a line from its start. At each character it tries the rules of the context
# it's in, in order. The first rule that matches colours the characters that it
# matched, and can open another context or go back to the one before (#pop).
# The contexts that are open at the end of a line are where the next line
# starts. highlight.jl gets them as one character: see `state_char`.
#
# Kate's styles become the kinds of token that highlight.jl has: see `KINDS`.
#
# The definitions are read when this file is compiled, so a built app has them
# without the folder. Kip doesn't see a change to an XML file, so change this
# file too after one.

@use "./xml" Element element elements text parse_xml

# --- the definitions ---------------------------------------------------------------------------

"A move between contexts: how many to close (#pop), then the context to open, or 0 for none"
struct Switch
  pops::Int
  push::Int
end

"True when `s` moves nowhere (#stay)"
stays(s::Switch) = s.pops == 0 && s.push == 0

"A rule of a context. `kind` is its element's name in Kate's files, like :DetectChar or :RegExpr."
struct Rule
  id::Int                  # a number of its own, which its regular expression is kept by
  kind::Symbol
  text::String             # its String, or its char
  chars::Vector{Char}      # the characters of `text`
  char1::Char              # the second char of a Detect2Chars or a RangeDetect
  colour::Symbol           # a kind of token, or :context for the colour of the context it's tried in
  switch::Switch
  lookahead::Bool          # true when it matches without taking the characters
  first_non_space::Bool    # true when it matches only at the line's first character that isn't a space
  column::Int              # the column it matches only at, from 0, or -1
  insensitive::Bool
  dynamic::Bool            # true when %1 and the others in `text` are the groups of the match that opened the context
  minimal::Bool
  words::Set{String}       # a keyword rule's words, in small letters when it's insensitive
  delimiters::Set{Char}    # what ends a word, in its definition
  children::Vector{Rule}   # rules that go on from where it ends, like a suffix after a number
  include::Int             # the context that an IncludeRules includes
end

"A context of a definition"
mutable struct Context
  name::String
  language::String
  colour::Symbol                       # the kind of token of the text that no rule matches
  line_end::Switch                     # where the end of a line moves
  line_empty::Switch                   # where a line with nothing on it moves
  fallthrough::Union{Nothing,Switch}   # where it moves when no rule matches
  dynamic::Bool
  rules::Vector{Rule}                  # with the rules of each IncludeRules in their place
end

"How each of Kate's styles is coloured: a kind of token of highlight.jl"
const KINDS = Dict(
  "dsNormal" => :plain, "dsOperator" => :plain, "dsError" => :plain,
  "dsKeyword" => :keyword, "dsControlFlow" => :keyword, "dsImport" => :keyword, "dsPreprocessor" => :keyword,
  "dsFunction" => :call, "dsBuiltIn" => :call,
  "dsDataType" => :type, "dsExtension" => :type, "dsOthers" => :type,
  "dsAttribute" => :type,   # an attribute, an annotation or a modifier, mostly
  "dsVariable" => :plain,   # Lua marks every name as a variable
  "dsDecVal" => :number, "dsBaseN" => :number, "dsFloat" => :number, "dsConstant" => :number,
  "dsChar" => :string, "dsSpecialChar" => :string, "dsString" => :string, "dsVerbatimString" => :string,
  "dsSpecialString" => :string,
  "dsComment" => :comment, "dsDocumentation" => :comment, "dsAnnotation" => :comment, "dsCommentVar" => :comment,
  "dsRegionMarker" => :comment, "dsInformation" => :comment, "dsWarning" => :comment, "dsAlert" => :comment)

"""
Items of a definition that are coloured as another kind than their style says,
by the definition's name and the item's. Some definitions pick a style for how
it looks in Kate, not for what the item is: Ruby gives a here-document the
style of a document's comment, and Nim gives its operators the style of a
comment, in bold.
"""
const OVERRIDES = Dict(
  ("Ruby", "Here Document") => :string, ("Ruby", "Symbol") => :number, ("Ruby", "Message") => :call,
  ("Ruby", "Access Control") => :keyword, ("Ruby", "Member") => :plain,
  ("Nim", "Operators") => :plain, ("Nim", "Symbols") => :plain, ("Nim", "Brackets") => :plain, ("Nim", "ProcDefs") => :call,
  ("Erlang", "Separator") => :plain, ("PHP/PHP", "Other") => :plain, ("Perl", "Operator") => :plain,
  ("Dart", "Modifiers") => :keyword)

"What ends a word, unless a definition says otherwise"
const DELIMITERS = "\t !%&()*+,-./:;<=>?[\\]^{|}~"

const CONTEXTS = Context[]
"The first context of each definition, by its name"
const FIRSTS = Dict{String,Int}()
"The first context of each definition that a code block or a file can name: by its name and its files' ends, in small letters"
const NAMES = Dict{String,Int}()
"The priority of the definition that each name in NAMES is for. Of two that claim a name, the one with the higher priority gets it."
const PRIORITIES = Dict{String,Int}()

"Which definition gets a name that two claim with the same priority, like s, which GNU Assembler and R both claim"
const PREFER = Dict("s" => "GNU Assembler", "asm" => "Intel x86 (NASM)", "m" => "Objective-C", "sql" => "SQL", "ddl" => "SQL",
                    "sh" => "Bash", ".profile" => "Bash")

"""
Names that code blocks use that aren't in the definitions, and the name, the
definition or the context##definition that each stands for. PHP's own
definition is only for others to include, since KDE makes the ones that a file
can name from it with a script. A code block of PHP often has no <?php, so it
starts in the context of PHP's code.
"""
const ALIASES = Dict("php" => "phpsource##PHP/PHP", "make" => "makefile", "objc" => "m", "objectivec" => "m", "ocaml" => "ml", "elisp" => "el", "emacs-lisp" => "el",
                     "fortran" => "f90", "gas" => "s", "nasm" => "asm", "coffeescript" => "coffee", "gdscript" => "gd",
                     "hcl" => "tf", "jinja2" => "jinja", "handlebars" => "mustache", "hbs" => "mustache", "bazel" => "bzl",
                     "restructuredtext" => "rst", "graphviz" => "dot", "devicetree" => "dts", "pwsh" => "ps1", "docker" => "dockerfile",
                     "rscript" => "r", "tex" => "latex", "man" => "roff", "troff" => "roff", "groff" => "roff")

"Read the definitions in the folder `dir`"
load!(dir) = begin
  isdir(dir) || return
  roots = Element[]
  for f in sort(readdir(dir))
    endswith(f, ".xml") || continue
    root = element(parse_xml(read(joinpath(dir, f), String)), "language")
    root === nothing || push!(roots, root)
  end
  # Each context gets its number first, so that a rule can move to a context of a definition read after its own
  ids = Dict{Tuple{String,String},Int}()
  for root in roots
    language = root.attrs["name"]
    for c in elements(element(element(root, "highlighting"), "contexts"), "context")
      push!(CONTEXTS, Context(c.attrs["name"], language, :plain, Switch(0, 0), Switch(0, 0), nothing, false, Rule[]))
      ids[(language, c.attrs["name"])] = length(CONTEXTS)
      haskey(FIRSTS, language) || (FIRSTS[language] = length(CONTEXTS))
    end
  end
  raw = Dict{Int,Vector{Rule}}()
  for root in roots
    language = root.attrs["name"]
    highlighting = element(root, "highlighting")
    kinds = Dict(d.attrs["name"] => get(OVERRIDES, (language, d.attrs["name"]), get(KINDS, get(d.attrs, "defStyleNum", "dsNormal"), :plain))
                 for d in elements(element(highlighting, "itemDatas"), "itemData"))
    general = element(root, "general")
    keywords = general === nothing ? nothing : element(general, "keywords")
    word_ends = Set{Char}(DELIMITERS)
    sensitive = true
    if keywords !== nothing
      setdiff!(word_ends, get(keywords.attrs, "weakDeliminator", ""))
      union!(word_ends, get(keywords.attrs, "additionalDeliminator", ""))
      sensitive = !(lowercase(get(keywords.attrs, "casesensitive", "1")) in ("0", "false"))
    end
    lists = Dict(l.attrs["name"] => l for l in elements(highlighting, "list"))
    words(name, seen=Set{String}()) = begin
      out = Set{String}()
      (name in seen || !haskey(lists, name)) && return out
      push!(seen, name)
      for c in lists[name].children
        c isa Element || continue
        c.name == "item" && push!(out, strip(text(c)))
        c.name == "include" && union!(out, words(strip(text(c)), seen))
      end
      out
    end
    switch(s) = begin
      s = strip(s)
      pops = 0
      while startswith(s, "#pop") pops += 1; s = s[5:end] end
      startswith(s, "!") && (s = s[2:end])
      (isempty(s) || s == "#stay") && return Switch(pops, 0)
      Switch(pops, target(s))
    end
    # A context by its name: Name, ##Language for a definition's first, or Name##Language
    target(s) = begin
      parts = split(String(s), "##")
      length(parts) == 1 && return get(ids, (language, String(s)), 0)
      isempty(parts[1]) ? get(FIRSTS, String(parts[2]), 0) : get(ids, (String(parts[2]), String(parts[1])), 0)
    end
    yes(a, key) = lowercase(get(a, key, "")) in ("1", "true")
    rule(e::Element) = begin
      a = e.attrs
      children = Rule[rule(c) for c in e.children if c isa Element]   # numbered before their rule
      t = get(a, "String", get(a, "char", ""))
      kind = Symbol(e.name)
      insensitive = yes(a, "insensitive") || (kind == :keyword && !sensitive)
      list = kind == :keyword ? words(t) : Set{String}()
      insensitive && (list = Set(lowercase.(list)))
      c1 = get(a, "char1", "")
      r = Rule(length(RULES) + 1, kind, t, collect(t), isempty(c1) ? '\0' : first(c1),
               haskey(a, "attribute") ? get(kinds, a["attribute"], :plain) : :context, switch(get(a, "context", "#stay")),
               yes(a, "lookAhead"), yes(a, "firstNonSpace"), parse(Int, get(a, "column", "-1")), insensitive,
               yes(a, "dynamic"), yes(a, "minimal"), list, word_ends, children,
               kind == :IncludeRules ? target(get(a, "context", "")) : 0)
      push!(RULES, r)
      r
    end
    for c in elements(element(highlighting, "contexts"), "context")
      id = ids[(language, c.attrs["name"])]
      ctx = CONTEXTS[id]
      ctx.colour = get(kinds, get(c.attrs, "attribute", ""), :plain)
      ctx.line_end = switch(get(c.attrs, "lineEndContext", "#stay"))
      ctx.line_empty = switch(get(c.attrs, "lineEmptyContext", "#stay"))
      through = get(c.attrs, "fallthroughContext", "")
      ctx.fallthrough = isempty(through) ? nothing : switch(through)
      ctx.dynamic = yes(c.attrs, "dynamic")
      raw[id] = [rule(r) for r in c.children if r isa Element]
    end
    # The names that a code block or a file can give it, unless it's only for other definitions
    if !(lowercase(get(root.attrs, "hidden", "")) in ("1", "true"))
      first_id = FIRSTS[language]
      priority = something(tryparse(Int, get(root.attrs, "priority", "0")), 0)
      claim(n) = (n = lowercase(n); (!haskey(NAMES, n) || priority > PRIORITIES[n]) && (NAMES[n] = first_id; PRIORITIES[n] = priority))
      claim(language)
      for p in split(get(root.attrs, "extensions", ""), ';')
        p = strip(p)
        startswith(p, "*.") && !occursin('*', p[3:end]) ? claim(p[3:end]) : !isempty(p) && !occursin('*', p) && claim(p)
      end
    end
  end
  for (name, language) in PREFER
    haskey(NAMES, name) && haskey(FIRSTS, language) && (NAMES[name] = FIRSTS[language])
  end
  for (alias, name) in ALIASES
    parts = split(name, "##")
    to = length(parts) == 2 ? get(ids, (String(parts[2]), String(parts[1])), 0) :
         haskey(NAMES, name) ? NAMES[name] : get(FIRSTS, name, 0)
    to != 0 && !haskey(NAMES, alias) && (NAMES[alias] = to)
  end
  # Put each IncludeRules' rules in its place
  done = Dict{Int,Vector{Rule}}()
  flat(id, seen) = begin
    haskey(done, id) && return done[id]
    id in seen && return Rule[]
    push!(seen, id)
    out = Rule[]
    for r in get(raw, id, Rule[])
      r.kind == :IncludeRules ? (r.include == 0 || append!(out, flat(r.include, seen))) : push!(out, r)
    end
    done[id] = out
  end
  for id in keys(raw)
    CONTEXTS[id].rules = flat(id, Set{Int}())
    # A context keeps the groups of the match that opened it when a rule of it uses them, marked or not
    CONTEXTS[id].dynamic |= any(r -> r.dynamic, CONTEXTS[id].rules)
  end
end

"Every rule, by its number"
const RULES = Rule[]

load!(joinpath(@__DIR__, "syntax"))

# --- what's open at the end of a line -----------------------------------------------------------

"The contexts that are open, the last the one that's in use, each with the groups of the match that opened it"
const Stack = Vector{Tuple{Int,Vector{String}}}

"Each stack that a line has left open, and the number of each"
const STACKS = Stack[]
const STACK_NUMBERS = Dict{Stack,Int}()

"The character that stands for `stack`: '\\0' when it's `start`, else a character from U+F0001"
state_char(stack::Stack, start::Stack) = begin
  stack == start && return '\0'
  k = get(STACK_NUMBERS, stack, 0)
  if k == 0
    length(STACKS) >= 65000 && return '\0'
    push!(STACKS, copy(stack))
    k = STACK_NUMBERS[STACKS[end]] = length(STACKS)
  end
  Char(0xf0000 + k)
end

"The stack that `c` stands for, or nothing"
stack_of(c::Char) = (k = Int(UInt32(c)) - 0xf0000; 1 <= k <= length(STACKS) ? STACKS[k] : nothing)

"The regular expression of each rule, compiled when it's first used, by the rule's number and its pattern"
const REGEXES = Dict{Tuple{Int,String},Union{Regex,Nothing}}()

# A built app keeps what the module held when it was built. A Regex holds pointers, which mustn't be kept.
__init__() = (empty!(REGEXES); empty!(STACKS); empty!(STACK_NUMBERS))

# --- colouring a line --------------------------------------------------------------------------

"True when a definition has the name `name`, like ruby or rb"
iskate(name::AbstractString) = haskey(NAMES, lowercase(name))

"""
The marks of the line `text` in the language `name`, as highlight.jl makes
them, and what the line leaves open. Gives nothing when no definition has
that name. `open` is what the line above left open, or '\\0'.
"""
kate_line(text::AbstractString, name::AbstractString, open::Char) = begin
  first_id = get(NAMES, lowercase(name), 0)
  first_id == 0 && return nothing
  start = Stack([(first_id, String[])])
  found = open == '\0' ? nothing : stack_of(open)
  stack = found === nothing || found[1][1] != first_id ? copy(start) : copy(found)
  s = String(text)
  chars = collect(s)
  n = length(chars)
  marks = Tuple{Int,Int,Symbol}[]
  if n == 0
    for _ in 1:64
      sw = CONTEXTS[last(stack)[1]].line_empty
      stays(sw) && break
      switch!(stack, sw, String[]) || break
    end
    return (marks, state_char(stack, start))
  end
  # The byte that each character starts at, for the regular expressions
  offs = Vector{Int}(undef, n + 1)
  for (j, b) in enumerate(eachindex(s)) offs[j] = b end
  offs[n+1] = ncodeunits(s) + 1
  nonspace = something(findfirst(!isspace, chars), n + 1)
  seen = Dict{Int,Tuple{Int,Union{Nothing,RegexMatch}}}()   # for each regular expression: where it next matches, and the match
  i, still, continued = 1, 0, false
  while i <= n
    top = last(stack)
    ctx = CONTEXTS[top[1]]
    hit = nothing
    for r in ctx.rules
      m = attempt(r, s, chars, offs, i, n, nonspace, top[2], seen)
      m === nothing && continue
      # A rule that takes nothing and moves nowhere would match again and again
      m[1] == i && !r.lookahead && stays(r.switch) && continue
      hit = (r, m[1], m[2])
      break
    end
    if hit === nothing
      if ctx.fallthrough !== nothing && still < 64
        switch!(stack, ctx.fallthrough, String[])
        still += 1
      else
        mark!(marks, i, i, ctx.colour)
        i, still = i + 1, 0
      end
      continue
    end
    r, e, groups = hit
    !r.lookahead && e > i && mark!(marks, i, e - 1, r.colour == :context ? ctx.colour : r.colour)
    switch!(stack, r.switch, groups)
    continued = r.kind == :LineContinue
    if r.lookahead || e == i
      # A move that takes nothing. Too many of them at one place means a loop, so the character is passed over.
      still += 1
      still > 64 && (mark!(marks, i, i, ctx.colour); i += 1; still = 0)
    else
      i, still = e, 0
    end
  end
  if !continued
    for _ in 1:64
      sw = CONTEXTS[last(stack)[1]].line_end
      stays(sw) && break
      switch!(stack, sw, String[]) || break
    end
  end
  (marks, state_char(stack, start))
end

"Colour the characters from `a` to `z` as `kind`, joined to the mark before when it's the same kind"
mark!(marks, a, z, kind) = begin
  kind == :plain && return
  if !isempty(marks) && marks[end][3] == kind && marks[end][2] == a - 1
    marks[end] = (marks[end][1], z, kind)
  else
    push!(marks, (a, z, kind))
  end
end

"""
The most contexts that are kept open. Some definitions open a context at the end
of a line where they mean to go back to one, as Objective-C does after each line
like #pragma, so the stack would grow with each. Then the oldest go, but the first.
"""
const DEEPEST = 64

"Move `stack` as `sw` says. `groups` go with a context that's opened. Gives false when it would close the first context."
switch!(stack::Stack, sw::Switch, groups) = begin
  ok = true
  for _ in 1:sw.pops
    length(stack) > 1 ? pop!(stack) : (ok = false)
  end
  sw.push != 0 && push!(stack, (sw.push, CONTEXTS[sw.push].dynamic ? groups : String[]))
  length(stack) > DEEPEST && deleteat!(stack, 2)
  ok
end

"True when `c` ends a word in the definition of `r`"
isdelimiter(c::Char, r::Rule) = c in r.delimiters

"""
`t` with %1 and the others replaced by `groups`, written for a regular
expression when `regex` is true. As in Kate, %0 is the whole match, the first
of `groups`, and %1 its first group.
"""
substitute(t::String, groups, regex::Bool) = replace(t, r"%(\d)" => m -> begin
  k = parse(Int, m[2:end]) + 1
  g = k <= length(groups) ? groups[k] : ""
  regex ? replace(g, r"([\\^$.|?*+()\[\]{}/-])" => s"\\\1") : g
end)

"The place after the escape like \\n of C that starts at `chars[i]`, or 0"
cescape(chars, i, n) = begin
  (i < n && chars[i] == '\\') || return 0
  d = chars[i+1]
  d in "abefnrtv\"'?\\" && return i + 2
  if d in "xX"
    j = i + 2
    while j <= n && isxdigit(chars[j]) j += 1 end
    return j > i + 2 ? j : 0
  end
  if d in '0':'7'
    j = i + 1
    while j <= n && j < i + 4 && chars[j] in '0':'7' j += 1 end
    return j
  end
  0
end

"""
Whether the rule `r` matches at `chars[i]`: the place after what it matches,
and the groups of a regular expression, or nothing. `groups` are those of the
match that opened the context, for a dynamic rule.
"""
attempt(r::Rule, s, chars, offs, i, n, nonspace, groups, seen) = begin
  r.column >= 0 && r.column != i - 1 && return nothing
  r.first_non_space && i != nonspace && return nothing
  c = chars[i]
  k = r.kind
  starts_word = i == 1 || isdelimiter(chars[i-1], r)
  e = 0
  if k === :DetectChar
    # A dynamic char is the number of a group, like 1 for %1
    want = r.dynamic ? (g = tryparse(Int, r.text); g === nothing || g + 1 > length(groups) || isempty(groups[g+1]) ? '\0' : first(groups[g+1])) :
           isempty(r.chars) ? '\0' : r.chars[1]
    c == want && (e = i + 1)
  elseif k === :Detect2Chars
    i < n && !isempty(r.chars) && c == r.chars[1] && chars[i+1] == r.char1 && (e = i + 2)
  elseif k === :AnyChar
    c in r.chars && (e = i + 1)
  elseif k === :StringDetect || k === :WordDetect
    t = r.dynamic ? collect(substitute(r.text, groups, false)) : r.chars
    m = length(t)
    if m > 0 && i + m - 1 <= n &&
       all(j -> r.insensitive ? lowercase(chars[i+j-1]) == lowercase(t[j]) : chars[i+j-1] == t[j], 1:m)
      (k === :StringDetect || (starts_word && (i + m > n || isdelimiter(chars[i+m], r)))) && (e = i + m)
    end
  elseif k === :keyword
    if starts_word
      j = i
      while j <= n && !isdelimiter(chars[j], r) j += 1 end
      if j > i
        w = String(chars[i:j-1])
        (r.insensitive ? lowercase(w) : w) in r.words && (e = j)
      end
    end
  elseif k === :RegExpr
    return matched(r, s, offs, i, groups, seen)
  elseif k === :Int
    if starts_word && isdigit(c)
      j = i
      while j <= n && isdigit(chars[j]) j += 1 end
      e = j
    end
  elseif k === :Float
    if starts_word
      j = i
      while j <= n && isdigit(chars[j]) j += 1 end
      if j <= n && chars[j] == '.'
        f = j + 1
        while f <= n && isdigit(chars[f]) f += 1 end
        if f > i + 1
          e = f
          if f <= n && chars[f] in "eE"
            x = f + 1
            x <= n && chars[x] in "+-" && (x += 1)
            y = x
            while y <= n && isdigit(chars[y]) y += 1 end
            y > x && (e = y)
          end
        end
      end
    end
  elseif k === :HlCOct
    if starts_word && c == '0' && i < n && chars[i+1] in '0':'7'
      j = i + 1
      while j <= n && chars[j] in '0':'7' j += 1 end
      e = j
    end
  elseif k === :HlCHex
    if starts_word && c == '0' && i + 2 <= n && chars[i+1] in "xX" && isxdigit(chars[i+2])
      j = i + 2
      while j <= n && isxdigit(chars[j]) j += 1 end
      e = j
    end
  elseif k === :HlCStringChar
    e = cescape(chars, i, n)
  elseif k === :HlCChar
    if c == '\'' && i < n
      j = chars[i+1] == '\\' ? cescape(chars, i + 1, n) : (chars[i+1] != '\'' ? i + 2 : 0)
      j > 0 && j <= n && chars[j] == '\'' && (e = j + 1)
    end
  elseif k === :RangeDetect
    if !isempty(r.chars) && c == r.chars[1]
      j = findnext(==(r.char1), chars, i + 1)
      j === nothing || (e = j + 1)
    end
  elseif k === :LineContinue
    want = isempty(r.chars) ? '\\' : r.chars[1]
    c == want && i == n && (e = i + 1)
  elseif k === :DetectSpaces
    if isspace(c)
      j = i
      while j <= n && isspace(chars[j]) j += 1 end
      e = j
    end
  elseif k === :DetectIdentifier
    if isletter(c) || c == '_'
      j = i + 1
      while j <= n && (isletter(chars[j]) || isdigit(chars[j]) || chars[j] == '_') j += 1 end
      e = j
    end
  end
  e == 0 && return nothing
  # A rule's own rules go on from where it ended, like a suffix after a number
  if e <= n
    for child in r.children
      m = attempt(child, s, chars, offs, e, n, nonspace, groups, seen)
      m === nothing || (e = m[1]; break)
    end
  end
  (e, String[])
end

"""
Whether the regular expression of `r` matches at `chars[i]`, as `attempt`
says. A search from one place finds the next place it matches, and that's
kept in `seen`, so that the places before it aren't searched again.
"""
matched(r::Rule, s, offs, i, groups, seen) = begin
  pattern = r.dynamic ? substitute(r.text, groups, true) : r.text
  re = get!(REGEXES, (r.id, pattern)) do
    options = Base.DEFAULT_COMPILER_OPTS | (r.insensitive ? Base.PCRE.CASELESS : UInt32(0)) |
              (r.minimal ? Base.PCRE.UNGREEDY : UInt32(0))
    try Regex(pattern, options, Base.DEFAULT_MATCH_OPTS) catch; nothing end
  end
  re === nothing && return nothing
  b = offs[i]
  m = nothing
  # PCRE gives up on a pattern that tries too many ways to match, as some of Texinfo's do on a long line. That's no match.
  if r.dynamic
    m = try match(re, s, b, Base.PCRE.ANCHORED) catch; nothing end
  else
    at, found = get(seen, r.id, (0, nothing))
    if at > b
      return nothing
    elseif at == b
      m = found
    else
      m = try match(re, s, b) catch; nothing end
      seen[r.id] = m === nothing ? (typemax(Int), nothing) : (m.offset, m)
      (m === nothing || m.offset != b) && return nothing
    end
  end
  m === nothing && return nothing
  e = searchsortedfirst(offs, m.offset + ncodeunits(m.match))
  (e, String[String(m.match); [g === nothing ? "" : String(g) for g in m.captures]])
end
