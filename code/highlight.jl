# Splits a line of code into the parts a code block draws in different colours:
# comments, strings, numbers, keywords, the names of functions being called and
# the names of types. It reads one line at a time and knows a little about each
# language, so it's quick. Of the things that run over several lines, it knows
# only a string in three quotes, like a docstring: `left_open` says when a line
# leaves one open, and `tokens` reads the next line from inside it.
#
# Code in a string, like the $(c.count) in "Clicked $(c.count) times", has the
# colours of code. Its $( and ) have the colour of a keyword.
#
# HTML, CSS, Less and SCSS are read a line at a time too: see "HTML" and
# "CSS, Less and SCSS" below. What a line of them leaves open, like a <script>
# or a comment, is a character, as the quote of a string in three quotes is for
# the other languages.
#
# A language that has no reader here, like Ruby, Lua or a Makefile, gets the
# colours that the syntax definitions of KDE's editor Kate give it: see kate.jl.

@use "./kate" kate_line iskate

"True when kate.jl colours the language `name`: when it has a definition there and no reader here"
bykate(name) = !haskey(LANGUAGES, lowercase(name)) && iskate(name)

"""
True when a line of the language `name` can leave something open whatever its
text, so `left_open` reads each line. It's worked out once for each name, since
`left_open` is asked about each line of a file.
"""
stateful(name) = get!(() -> ishtml(name) || iscss(name) || isrepl(name) || isshell(name) || bykate(name), STATEFUL, name)
const STATEFUL = Dict{String,Bool}()

"What a language's code looks like"
struct Language
  keywords::Set{String}
  literals::Set{String}      # words like true and nothing
  comment::String            # what starts a comment that runs to the end of the line
  quotes::String             # the characters that open and close a string
  chars::Bool                # true when 'x' is one character, not a string
  bang::Bool                 # true when a name can end in !
  code::Symbol               # how a string holds code: :julia, :python, :javascript, :shell or :none
end

Language(keywords, literals; comment="//", quotes="\"'", chars=false, bang=false, code=:none) =
  Language(Set(split(keywords)), Set(split(literals)), comment, quotes, chars, bang, code)

const JULIA = Language("""abstract baremodule begin break catch const continue do else elseif end export finally for
                          function global if import in isa let local macro module mutable primitive quote return
                          struct try type using where while""",
                       "true false nothing missing Inf NaN pi", comment="#", quotes="\"`", chars=true, bang=true,
                       code=:julia)

const PYTHON = Language("""and as assert async await break class continue def del elif else except finally for from
                           global if import in is lambda nonlocal not or pass raise return try while with yield""",
                        "True False None self", comment="#", code=:python)

const JAVASCRIPT = Language("""as async await break case catch class const continue default delete do else enum export
                               extends finally for from function if implements import in instanceof interface let new
                               of return static switch throw try type typeof var void while yield""",
                            "true false null undefined this super NaN Infinity", quotes="\"'`", code=:javascript)

const RUST = Language("""as async await break const continue crate dyn else enum extern fn for if impl in let loop match
                         mod move mut pub ref return static struct trait type unsafe use where while""",
                      "true false self Self None Some Ok Err", quotes="\"", chars=true, bang=true)

const C = Language("""auto break case catch class const continue default defer delete do else enum extern final for
                      func go goto if import inline interface map namespace new package private protected public
                      range return sizeof static struct switch template throw try typedef union using var virtual
                      void volatile while""",
                   "true false null nil nullptr NULL this self", chars=true)

const SHELL = Language("break case continue do done elif else esac export fi for function if in local return select then until while",
                       "true false", comment="#", code=:shell)

const SQL = Language("""select from where and or not null insert into values update set delete create table drop alter
                        add join left right inner outer on as group by order having limit distinct union index
                        primary key references default is in like between exists""",
                     "true false", comment="--", quotes="'\"")

const DATA = Language("", "true false null yes no", comment="#")

const JSONC = Language("", "true false null Infinity NaN")   # JSON with comments, as JSONC and JSON5 have them

const LANGUAGES = Dict{String,Language}()
for (names, language) in ("julia jl ui" => JULIA, "python py" => PYTHON,
                          "javascript js jsx mjs cjs typescript ts tsx" => JAVASCRIPT, "rust rs" => RUST,
                          "c cpp c++ cc h hpp go java swift kotlin kt csharp cs zig" => C,
                          "bash sh zsh shell fish" => SHELL, "sql" => SQL, "json jsonl ndjson yaml yml toml" => DATA,
                          "jsonc json5" => JSONC)
  for name in split(names)
    LANGUAGES[name] = language
  end
end

"One part of a line of code. `kind` is :plain, :comment, :string, :number, :keyword, :call, :type, or in a diff :added or :removed."
struct Token
  col::Int       # the column of its first character
  text::String
  kind::Symbol
end

isname(c::Char) = isletter(c) || isdigit(c) || c == '_'

"True when the characters of `s` are at `chars[i]`"
starts(chars, s, i) = !isempty(s) && i + length(s) - 1 <= length(chars) && all(chars[i+k-1] == c for (k, c) in enumerate(s))

"Where the name that starts at `chars[i]` ends"
namend(chars, lang, i) = begin
  n = length(chars)
  j = i
  while j < n && (isname(chars[j+1]) || (lang.bang && chars[j+1] == '!' && !(j + 1 < n && chars[j+2] == '=')))
    j += 1
  end
  j
end

"True when the string that opens at `chars[i]` is a Python f-string, like f\"{x}\" or rf'{x}'"
fstring(chars, i) = begin
  k = i - 1
  while k >= 1 && isletter(chars[k]); k -= 1 end
  (k < 1 || !isname(chars[k])) && lowercase(String(chars[k+1:i-1])) in ("f", "rf", "fr")
end

"""
How the string that opens at `chars[i]` holds code: :julia, :python, :javascript,
:shell or :none. A Julia string with a name in front, like raw"..." or r"...", has
no code in it. In JavaScript only a string in backticks has code, and in a shell
only a string in double quotes.
"""
holds(lang, chars, i) = begin
  q = chars[i]
  lang.code == :julia ? (i > 1 && isname(chars[i-1]) ? :none : :julia) :
  lang.code == :python ? (fstring(chars, i) ? :python : :none) :
  lang.code == :javascript ? (q == '`' ? :javascript : :none) :
  lang.code == :shell ? (q == '"' ? :shell : :none) : :none
end

const NUMBER = r"^(0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*(\.\d+)?([eE][+-]?\d+)?)"

"True when three of the quote `q` open a string in `lang` that can run over several lines, like a docstring"
triples(lang, q) = (lang.code == :julia && q == '"') || (lang.code == :python && q in "\"'")

"True when the string that opens at `chars[i]` opens with three quotes"
triple_at(lang, chars, i) = triples(lang, chars[i]) && i + 2 <= length(chars) && chars[i+1] == chars[i] && chars[i+2] == chars[i]

"""
Marks the parts of the code that starts at `chars[i]`. A mark is the first and
last character of a part and its kind. It stops at the end of the line, or at a
`close` that has no partner, like the ) at the end of \$(x). It gives the place it
stopped. `left` gets the quote of a string in three quotes that's still open at
the end of the line.
"""
code!(marks, chars, lang, i, close=nothing, left=Ref('\0')) = begin
  n = length(chars)
  open = close == ')' ? '(' : close == '}' ? '{' : nothing
  depth = 0
  while i <= n
    c = chars[i]
    if c == close
      depth == 0 && return i
      depth -= 1
      i += 1
    elseif c == open
      depth += 1
      i += 1
    elseif starts(chars, lang.comment, i)
      push!(marks, (i, n, :comment))
      return n + 1
    elseif c in lang.quotes
      k = string!(marks, chars, lang, i)
      close === nothing && k > n && triple_at(lang, chars, i) && (left[] = c)
      i = k + 1
    elseif c == '\'' && lang.chars
      # 'x' and '\n' are characters. A lone ' is something else, like a transpose.
      j = i + 2 <= n && chars[i+1] != '\\' && chars[i+2] == '\'' ? i + 2 :
          i + 3 <= n && chars[i+1] == '\\' && chars[i+3] == '\'' ? i + 3 : 0
      j == 0 || push!(marks, (i, j, :string))
      i = max(i, j) + 1
    elseif isdigit(c) && (i == 1 || !isname(chars[i-1]))
      j = i + length(match(NUMBER, String(chars[i:end])).match) - 1
      push!(marks, (i, j, :number))
      i = j + 1
    elseif isletter(c) || c == '_' || (c == '@' && i < n && isletter(chars[i+1]))
      j = namend(chars, lang, i)
      word = String(chars[i:j])
      kind = word in lang.keywords ? :keyword :
             word in lang.literals ? :number :
             c == '@' || (j < n && chars[j+1] == '(') ? :call :
             isuppercase(c) && any(islowercase, word) ? :type : :plain
      kind == :plain || push!(marks, (i, j, kind))
      i = j + 1
    else
      i += 1
    end
  end
  n + 1
end

"""
Marks the string that opens at `chars[i]` and gives the place it closes. A string
that doesn't close runs to the end of the line, and gives the place after it.
Three quotes, like \"\"\", open a string that only three quotes close. `open` is
the quote of a string in three quotes that a line above opened: the string then
starts at `chars[i]`, which isn't a quote of its own. Code in the string, like \$(x) in
Julia, gets the marks that code gets, and the \$( and ) get the colour of a keyword.
A name like \$x has the colour of a name.
"""
string!(marks, chars, lang, i, open=nothing) = begin
  n = length(chars)
  q = open === nothing ? chars[i] : open
  triple = open !== nothing || triple_at(lang, chars, i)
  # A string that a line above opened can't be raw"..." or a Python f-string, as far as this line knows
  how = open === nothing ? holds(lang, chars, i) : lang.code == :julia ? :julia : :none
  from = i                          # the first character of the string that has no mark yet
  text!(j) = from < j && push!(marks, (from, j - 1, :string))
  j = open !== nothing ? i : triple ? i + 3 : i + 1
  while j <= n
    c = chars[j]
    d = j < n ? chars[j+1] : '\0'
    if c == '\\'
      j += 2
    elseif c == q && (!triple || (j + 2 <= n && chars[j+1] == q && chars[j+2] == q))
      k = triple ? j + 2 : j
      push!(marks, (from, k, :string))
      return k
    elseif how == :python && c == '{' && d == '{'
      j += 2                        # {{ is a {
    elseif (how in (:julia, :shell) && c == '$' && d == '(') || (how == :javascript && c == '$' && d == '{') ||
           (how == :python && c == '{')
      # Code: $(x) in Julia or a shell, ${x} in JavaScript, {x} in Python
      text!(j)
      w = how == :python ? 1 : 2
      push!(marks, (j, j + w - 1, :keyword))
      k = how == :shell ? shell!(marks, chars, j + w, ')') : code!(marks, chars, lang, j + w, chars[j+w-1] == '(' ? ')' : '}')
      k <= n && push!(marks, (k, k, :keyword))
      from = j = k + 1
    elseif how == :shell && c == '$' && d == '{'
      # ${name} and ${name:-word} in a shell are a name, not code
      text!(j)
      k = something(findnext(==('}'), chars, j + 2), n)
      push!(marks, (j, j + 1, :keyword))
      k > j + 1 && chars[k] == '}' && push!(marks, (k, k, :keyword))
      from = j = k + 1
    elseif how in (:julia, :shell) && c == '$' && (isletter(d) || d == '_' || (how == :shell && (isdigit(d) || d in "@*#?\$!-")))
      # A name, like $x, or $1 and $? in a shell
      text!(j)
      push!(marks, (j, j, :keyword))
      from = j = (isletter(d) || d == '_' ? namend(chars, lang, j + 1) : j + 1) + 1
    else
      j += 1
    end
  end
  text!(n + 1)
  n + 1
end

"""
The parts of one line of code written in the language named `name`. `open` is
the quote of a string in three quotes that a line above left open, like the
middle of a docstring, or '\\0' when there's none: see `left_open`.
"""
tokens(text::AbstractString, name::AbstractString, open::Char='\0') = first(read_line(text, name, open))

"""
The quote of the string in three quotes that's still open at the end of the
line `text`, or '\\0' when there's none. `open` is the quote of the one that's
open at its start. A line with no three quotes leaves things as they were, so
for most lines this is quick. For HTML, CSS, Less and SCSS it's what the line
leaves open: see "HTML" and "CSS, Less and SCSS".
So it is for a session of Julia's REPL and for a shell: see "what Julia's REPL
shows" and "shells".
"""
left_open(text::AbstractString, name::AbstractString, open::Char='\0') =
  stateful(name) || occursin("\"\"\"", text) || occursin("'''", text) ? last(read_line(text, name, open)) : open

"The parts of the line `text`, and what `left_open` says of it"
read_line(text, name, open) = begin
  if ishtml(name)
    chars = collect(text)
    marks = Tuple{Int,Int,Symbol}[]
    left = html!(marks, chars, open)
    return (marked(chars, marks), left)
  end
  isrepl(name) && return repl_line(text, name, open)
  isdiff(name) && return (diff_line(text), '\0')
  isshell(name) && return shell_line(text, name, open)
  if iscss(name)
    chars = collect(text)
    marks = Tuple{Int,Int,Symbol}[]
    # Nothing open, '\0', is the same as being among the rules
    left = css!(marks, chars, 1, length(chars), open in CSS_OPENS ? open : IN_STYLE, Symbol(lowercase(name)))
    return (marked(chars, marks), left == IN_STYLE ? '\0' : left)
  end
  if bykate(name)
    marks, left = kate_line(text, name, open)
    return (marked(collect(text), marks), left)
  end
  lang = get(LANGUAGES, lowercase(name), nothing)
  lang === nothing && return ([Token(0, String(text), :plain)], '\0')
  chars = collect(text)
  marks = Tuple{Int,Int,Symbol}[]
  left = Ref('\0')
  i = 1
  if open != '\0' && triples(lang, open)
    i = string!(marks, chars, lang, 1, open) + 1
    # A line that doesn't close the string is all string
    i > length(chars) + 1 && (left[] = open)
  end
  i <= length(chars) && code!(marks, chars, lang, i, nothing, left)
  (marked(chars, marks), left[])
end

# --- HTML ---------------------------------------------------------------------------------
#
# A tag's name and its < and > have the colour of a keyword, the names of its
# attributes the colour of a type, and their values the colour of a string. A
# comment is a comment, and a character like &amp; has the colour of a number.
# The CSS in a <style> and the JavaScript in a <script> have their own colours.
#
# What a line leaves open, for the next line to start in:

const IN_TEXT = '\0'             # the page's text
const IN_TAG = '<'               # a tag, among its attributes
const IN_SCRIPT_TAG = 'S'        # the tag that starts a <script>
const IN_STYLE_TAG = 'T'         # the tag that starts a <style>
const IN_COMMENT = '!'           # a comment, which --> ends
const IN_SCRIPT = 'j'            # the JavaScript of a <script>
const IN_SCRIPT_COMMENT = 'J'    # a comment in it, which */ ends
const IN_TEMPLATE = 'b'          # a string in it between two `, which can run over several lines
# and the CSS of a <style>, which leaves open what a line of CSS does: see "CSS, Less and SCSS"

"True when `name` is a language that's read as HTML"
ishtml(name) = lowercase(name) in ("html", "htm", "xhtml", "svg", "xml")

"Where `s` starts in `chars`, from `i` up to `upto`, or nothing. With `anycase`, capitals are the same as small letters."
found(chars, s, i, upto=length(chars); anycase=false) = begin
  n = length(s)
  for k in i:upto-n+1
    all(j -> anycase ? lowercase(chars[k+j-1]) == s[j] : chars[k+j-1] == s[j], 1:n) && return k
  end
  nothing
end

"""
Marks the parts of a line of HTML, `chars`, which starts in `state`: one of
the characters above. Gives what the line leaves open.
"""
html!(marks, chars, state::Char) = begin
  n = length(chars)
  i = 1
  while i <= n
    if state == IN_COMMENT
      k = found(chars, "-->", i)
      k === nothing && (push!(marks, (i, n, :comment)); return state)
      push!(marks, (i, k + 2, :comment))
      i, state = k + 3, IN_TEXT
    elseif state in (IN_TAG, IN_SCRIPT_TAG, IN_STYLE_TAG)
      i, state = attributes!(marks, chars, i, state)
    elseif state in (IN_SCRIPT, IN_SCRIPT_COMMENT, IN_TEMPLATE) || state in CSS_OPENS
      script = state in (IN_SCRIPT, IN_SCRIPT_COMMENT, IN_TEMPLATE)
      stop = found(chars, script ? "</script" : "</style", i; anycase=true)
      upto = stop === nothing ? n : stop - 1
      state = script ? script!(marks, chars, i, upto, state) : css!(marks, chars, i, upto, state)
      stop === nothing && return state
      i, state = stop, IN_TEXT   # the tag that ends it is read as a tag
    elseif chars[i] == '<' && starts(chars, "<!--", i)
      push!(marks, (i, i + 3, :comment))
      i, state = i + 4, IN_COMMENT
    elseif chars[i] == '<' && i < n && (isletter(chars[i+1]) || chars[i+1] in "/!?")
      j = chars[i+1] in "/!?" ? i + 2 : i + 1
      k = j
      while k <= n && (isname(chars[k]) || chars[k] in "-:.") k += 1 end
      push!(marks, (i, k - 1, :keyword))
      name = lowercase(String(chars[j:k-1]))
      state = chars[i+1] == '/' ? IN_TAG : name == "script" ? IN_SCRIPT_TAG : name == "style" ? IN_STYLE_TAG : IN_TAG
      i = k
    elseif chars[i] == '&'
      k = something(findnext(==(';'), chars, i), 0)
      if i + 1 < k <= i + 32 && all(c -> isname(c) || c == '#', chars[i+1:k-1])
        push!(marks, (i, k, :number))
        i = k + 1
      else
        i += 1
      end
    else
      i += 1
    end
  end
  state
end

"Marks the attributes of a tag, from `chars[i]` to its >. Gives where it stopped, and what's open there."
attributes!(marks, chars, i, state) = begin
  n = length(chars)
  while i <= n
    c = chars[i]
    if c == '>' || (c == '/' && i < n && chars[i+1] == '>')
      k = c == '>' ? i : i + 1
      push!(marks, (i, k, :keyword))
      return k + 1, state == IN_SCRIPT_TAG && c == '>' ? IN_SCRIPT : state == IN_STYLE_TAG && c == '>' ? IN_STYLE : IN_TEXT
    elseif c == '"' || c == '\''
      k = something(findnext(==(c), chars, i + 1), n)
      push!(marks, (i, k, :string))
      i = k + 1
    elseif isletter(c) || c in "_:@"
      k = i
      while k <= n && !(isspace(chars[k]) || chars[k] in "=>/\"'") k += 1 end
      push!(marks, (i, k - 1, :type))
      i = k
    else
      i += 1
    end
  end
  n + 1, state
end

"""
Marks the JavaScript of a <script>, from `chars[i]` to `chars[upto]`, which
starts in `state`. A comment between /* and */ and a string between two ` can
run over several lines. Gives what's open at `upto`.
"""
script!(marks, chars, i, upto, state) = begin
  part = chars[1:upto]
  while i <= upto
    if state == IN_SCRIPT_COMMENT
      k = found(part, "*/", i)
      k === nothing && (push!(marks, (i, upto, :comment)); return state)
      push!(marks, (i, k + 1, :comment))
      i, state = k + 2, IN_SCRIPT
    elseif state == IN_TEMPLATE
      k = i
      while k <= upto && part[k] != '`'
        part[k] == '\\' && (k += 1)
        k += 1
      end
      k > upto && (push!(marks, (i, upto, :string)); return state)
      push!(marks, (i, k, :string))
      i, state = k + 1, IN_SCRIPT
    else
      # The code up to the next /* or `, which isn't in a string, has the colours of JavaScript
      j, q = i, '\0'
      while j <= upto
        c = part[j]
        if q != '\0'
          c == '\\' ? (j += 1) : c == q && (q = '\0')
        elseif c in "'\""
          q = c
        elseif c == '/' && j < upto && part[j+1] == '/'
          j = upto + 1
          break
        elseif (c == '/' && j < upto && part[j+1] == '*') || c == '`'
          break
        end
        j += 1
      end
      i < min(j, upto + 1) && code!(marks, part[1:min(j - 1, upto)], JAVASCRIPT, i)
      j > upto && return state
      if part[j] == '/'
        i, state = j, IN_SCRIPT_COMMENT
      else
        push!(marks, (j, j, :string))
        i, state = j + 1, IN_TEMPLATE
      end
    end
  end
  state
end

# --- CSS, Less and SCSS -----------------------------------------------------------------------
#
# A selector, like `.note p` or `a:hover`, has the colour of a keyword, and so
# has the name of a rule like @media. A property, like the color of `color: red`,
# has the colour of a type. In its value a number, like 2px or #a6c8e8, has the
# colour of a number, and a function, like the var of var(--ink), of a call.
#
# Less has more. A comment can start with // and run to the end of the line. A
# variable that's set, like @gap in `@gap: 4px;`, has the colour of a property,
# and a mixin that's used, like `.rounded(4px);`, the colour of a call. The @{
# and } of @{name}, which puts a variable's value in a selector or a string,
# have the colour of a keyword.
#
# SCSS, the main form of Sass, has comments that start with // too. A variable,
# like $gap, is set as a property is, and the name of a mixin or a function
# after @mixin, @include or @function has the colour of a call. A selector like
# %name, which only @extend uses, has the colour of a selector, and the #{ and }
# of #{...} have the colour of a keyword.
#
# The CSS of a <style> in HTML is read the same way. What a line leaves open:

const IN_STYLE = 'c'               # nothing: the line starts among the rules
const IN_STYLE_COMMENT = 'C'       # a comment among them, which */ ends
const IN_STYLE_VALUE = 'v'         # a property's value, which ; ends, as in a list of fonts on several lines
const IN_STYLE_VALUE_COMMENT = 'V' # a comment in a value
const CSS_OPENS = (IN_STYLE, IN_STYLE_COMMENT, IN_STYLE_VALUE, IN_STYLE_VALUE_COMMENT)

"The rules of CSS, Less and SCSS that a ( can follow, like @media(min-width: 600px)"
const AT_RULES = Set(["media", "import", "supports", "container", "layer", "document", "plugin", "scope"])

"The words that have the colour of a keyword after the name of a rule of SCSS, like the in of @each \$x in \$list"
const SCSS_WORDS = ("in", "from", "through", "to", "as", "with", "if", "hide", "show")

"True when `name` is a language that's read as CSS"
iscss(name) = lowercase(name) in ("css", "less", "scss")

"The place of the first character from `chars[i]` that isn't a space, or `upto + 1`"
unspaced(chars, i, upto) = begin
  while i <= upto && isspace(chars[i]) i += 1 end
  i
end

"The place after the name of letters, digits, _ and - that goes on at `chars[i]`"
cssname(chars, i, upto) = begin
  while i <= upto && (isname(chars[i]) || chars[i] == '-') i += 1 end
  i
end

"""
Marks the comment that opens with /* at `chars[i]`, or at `from` when a line
above opened it. Gives the place after its */, or nothing when it doesn't close
by `upto`.
"""
comment!(marks, chars, i, upto, from=i + 2) = begin
  k = found(chars, "*/", from, upto)
  k === nothing && (push!(marks, (i, upto, :comment)); return nothing)
  push!(marks, (i, k + 1, :comment))
  k + 2
end

"""
Marks the CSS from `chars[i]` to `chars[upto]`, which starts in `state`: one of
the characters above. `dialect` is :css, :less or :scss. Gives what's open at
`upto`.
"""
css!(marks, chars, i, upto, state, dialect=:css) = begin
  # A line that starts a rule or sets a property isn't more of the value above it, which lacked its ;
  state == IN_STYLE_VALUE && fresh(chars, i, upto) && (state = IN_STYLE)
  while i <= upto
    c = chars[i]
    if state in (IN_STYLE_COMMENT, IN_STYLE_VALUE_COMMENT)
      k = comment!(marks, chars, i, upto, i)
      k === nothing && return state
      i, state = k, state == IN_STYLE_COMMENT ? IN_STYLE : IN_STYLE_VALUE
    elseif state == IN_STYLE_VALUE
      i, state = part!(marks, chars, i, upto, :value, dialect)
    elseif isspace(c) || c in ";{}"
      i += 1
    elseif c == '/' && i < upto && chars[i+1] == '*'
      k = comment!(marks, chars, i, upto)
      k === nothing && return IN_STYLE_COMMENT
      i = k
    elseif dialect != :css && c == '/' && i < upto && chars[i+1] == '/'
      push!(marks, (i, upto, :comment))
      return state
    else
      i, state = statement!(marks, chars, i, upto, dialect)
    end
  end
  state
end

"""
Where the rule or the property that starts at `chars[i]` ends: the place of the
;, { or } that ends it, or `upto + 1` when it goes on past the end of the line.
One in a string or between brackets doesn't end it.
"""
css_end(chars, i, upto) = begin
  depth, q = 0, '\0'
  while i <= upto
    c = chars[i]
    if q != '\0'
      c == '\\' ? (i += 1) : c == q && (q = '\0')
    elseif c == '"' || c == '\''
      q = c
    elseif c in "@#" && i < upto && chars[i+1] == '{'
      i = something(findnext(==('}'), view(chars, 1:upto), i), upto)   # the @{name} of Less, or the #{...} of SCSS
    elseif c == '(' || c == '['
      depth += 1
    elseif c == ')' || c == ']'
      depth = max(depth - 1, 0)
    elseif depth == 0 && c in ";{}"
      return i
    end
    i += 1
  end
  upto + 1
end

"""
When the text from `chars[i]` sets a property, like `color: red`, the place of
the property's last character and of its colon. Else nothing. The text ends at
`k`, the place of `stop`: its ;, { or }, or '\\0' at the end of the line.
"""
declared(chars, i, k, upto, stop) = begin
  stop == '{' && return nothing                # a selector, like a:hover {
  j = i
  j < k && chars[j] in "*_" && (j += 1)        # an old trick for Internet Explorer, like *zoom: 1
  (j < k && (isletter(chars[j]) || chars[j] == '-')) || return nothing
  j = cssname(chars, j, k - 1)
  last = j - 1
  while j < k && chars[j] in " \t" j += 1 end
  (j < k && chars[j] == ':') || return nothing
  # At the end of a line, a:hover is more likely a selector that goes on below than a property set to hover
  stop == '\0' && j < upto && !isspace(chars[j+1]) && return nothing
  (last, j)
end

"""
True when the line from `chars[i]`, which starts in the value of a property,
starts a rule or sets a property of its own: the value above lacked its ;
"""
fresh(chars, i, upto) = begin
  i = unspaced(chars, i, upto)
  i > upto && return false
  k = css_end(chars, i, upto)
  stop = k <= upto ? chars[k] : '\0'
  declared(chars, i, k, upto, stop) !== nothing || (stop == '{' && !(chars[i] in "{("))
end

"""
Marks the rule or the property that starts at `chars[i]`: a selector, like
`.note p {`, a rule like `@media print {`, or a property and its value, like
`color: red;`. It can be a variable that's set, like `@gap: 4px;` in Less or
`\$gap: 4px;` in SCSS, or in Less a mixin that's used, like `.rounded(4px);`.
`dialect` is :css, :less or :scss. Gives where it stopped, and what's open
there.
"""
statement!(marks, chars, i, upto, dialect) = begin
  k = css_end(chars, i, upto)
  stop = k <= upto ? chars[k] : '\0'
  less, scss = dialect == :less, dialect == :scss
  if (chars[i] == '@' && i < upto && chars[i+1] != '{') || (scss && chars[i] == '$')
    j = i + 1
    while j <= upto && (isname(chars[j]) || chars[j] in "-@") j += 1 end
    after = unspaced(chars, j, upto)
    next = after <= upto ? chars[after] : '\0'
    if (less || chars[i] == '$') && next == ':'
      push!(marks, (i, j - 1, :type))          # a variable that's set
      return part!(marks, chars, after + 1, upto, :value, dialect)
    end
    chars[i] == '$' && return part!(marks, chars, i, upto, :value, dialect)
    word = String(chars[i+1:j-1])
    # A rule, like @media, or in Less a set of rules that a variable holds, which is used, like @rules();
    called = less && j <= upto && chars[j] == '(' && !(word in AT_RULES)
    push!(marks, (i, j - 1, called ? :call : :keyword))
    scss && word == "extend" && return part!(marks, chars, j, upto, :selector, dialect)
    if scss && word in ("mixin", "include", "function")
      # The name of the mixin or the function that's made or used, like the rounded of @include rounded(4px)
      from = unspaced(chars, j, upto)
      j = from
      while j <= upto && (isname(chars[j]) || chars[j] in "-.") j += 1 end
      j > from && push!(marks, (from, j - 1, :call))
    end
    return part!(marks, chars, j, upto, :prelude, dialect)
  end
  property = declared(chars, i, k, upto, stop)
  if property !== nothing
    push!(marks, (i, property[1], :type))
    return part!(marks, chars, property[2] + 1, upto, :value, dialect)
  end
  part!(marks, chars, i, upto, less && stop in (';', '}') && chars[i] in ".#" ? :mixin : :selector, dialect)
end

"True when the ( at `chars[i]` follows a pseudo-class, like :not( or :nth-child("
pseudo_before(chars, i) = begin
  k = i - 1
  while k >= 1 && (isname(chars[k]) || chars[k] == '-') k -= 1 end
  k >= 1 && k < i - 1 && chars[k] == ':'
end

"""
Marks a part of a rule, from `chars[i]`. `how` says what it is: :selector, like
`a:hover > .note`; :mixin, a mixin of Less that's used, like `.rounded(4px)`;
:value, the value of a property, like `0 2px var(--gap)`; or :prelude, what
follows the name of a rule, like the `screen and (min-width: 600px)` of @media.
`dialect` is :css, :less or :scss. It stops at the ;, { or } that ends the
part, or at `upto`. Gives where it stopped, and what's open there.
"""
part!(marks, chars, i, upto, how, dialect) = begin
  less, scss = dialect == :less, dialect == :scss
  start = how
  inside = Symbol[]          # for each ( or [ that's open, what the part is outside it
  while i <= upto
    c = chars[i]
    d = i < upto ? chars[i+1] : '\0'
    if c == '/' && d == '*'
      k = comment!(marks, chars, i, upto)
      k === nothing && return upto + 1, start in (:value, :prelude) ? IN_STYLE_VALUE_COMMENT : IN_STYLE_COMMENT
      i = k
    elseif dialect != :css && c == '/' && d == '/'
      push!(marks, (i, upto, :comment))
      return upto + 1, start in (:value, :prelude) ? IN_STYLE_VALUE : IN_STYLE
    elseif c == '"' || c == '\'' || (less && c == '~' && (d == '"' || d == '\''))
      i = quoted!(marks, chars, i, upto, dialect) + 1
    elseif ((less && c == '@') || (scss && c == '#')) && d == '{'
      i = interpolated!(marks, chars, i, upto, dialect) + 1
    elseif isempty(inside) && c in ";{}"
      return i, IN_STYLE
    elseif c == '(' || (c == '[' && how == :selector)
      push!(inside, how)
      how = c == '[' ? :attribute :
            how == :mixin || (how == :selector && less && !pseudo_before(chars, i)) ? :value :   # a mixin's parameters
            how
      i += 1
    elseif !isempty(inside) && (c == ']') == (how == :attribute) && c in ")]"
      how = pop!(inside)
      i += 1
    elseif c == '!' && isletter(d)
      k = cssname(chars, i + 1, upto)
      push!(marks, (i, k - 1, :keyword))       # !important, or in SCSS a flag like !default
      i = k
    elseif (c == '@' || (scss && c == '$')) && (isletter(d) || d in "@-_")
      # A variable, like @gap in Less or $gap in SCSS, which is set when a : follows it, as a mixin's parameter is
      k = cssname(chars, i + 1, upto)
      after = unspaced(chars, k, upto)
      next = after <= upto ? chars[after] : '\0'
      next in ":(" && push!(marks, (i, k - 1, next == ':' ? :type : :call))
      i = k
    elseif c == '#' && how in (:value, :prelude) && isname(d)
      k = cssname(chars, i + 1, upto)
      push!(marks, (i, k - 1, :number))        # a colour, like #a6c8e8
      i = k
    elseif ((c in ".#" && how in (:selector, :mixin)) || (scss && c == '%' && how == :selector)) && (isname(d) || d == '-')
      # A class, an id, or in SCSS a selector like %name, which only @extend uses
      k = cssname(chars, i + 1, upto)
      push!(marks, (i, k - 1, how == :mixin ? :call : :keyword))
      i = k
    elseif c == ':' && how == :selector && (isletter(d) || d in ":-")
      k = cssname(chars, d == ':' ? i + 2 : i + 1, upto)
      push!(marks, (i, k - 1, :keyword))       # a pseudo-class, like :hover, or ::before
      i = k
    elseif c == '&' && how == :selector
      push!(marks, (i, i, :keyword))           # the selector of the rule this one is in
      i += 1
    elseif (isdigit(c) || (c in ".-+" && isdigit(d))) && (i == 1 || !isname(chars[i-1]))
      k = i + 1
      while k <= upto && (isname(chars[k]) || chars[k] in ".%") k += 1 end
      push!(marks, (i, k - 1, :number))
      i = k
    elseif isletter(c) || c == '_' || (c == '-' && (isletter(d) || d in "-_")) || (less && c == '%' && d == '(')
      k = cssname(chars, i + 1, upto)
      word = lowercase(String(chars[i:k-1]))
      next = k <= upto ? chars[k] : '\0'
      if how == :selector
        push!(marks, (i, k - 1, :keyword))     # a tag, like p
        less && word == "when" && (how = :prelude)   # a guard, like .m(@a) when (@a > 0)
      elseif how == :attribute
        j = i - 1
        while j >= 1 && chars[j] == ' ' j -= 1 end
        push!(marks, (i, k - 1, j >= 1 && chars[j] == '=' ? :string : :type))
      elseif next == '('
        push!(marks, (i, k - 1, :call))
        j = unspaced(chars, k + 1, upto)
        if word == "url" && j <= upto && !(chars[j] in "\"'@")
          # The address in url(...) is a string, though it has no quotes, unless it's a variable of Less or holds #{...}
          close = something(findnext(==(')'), view(chars, 1:upto), j), upto + 1)
          if !(scss && found(chars, "#{", j, close - 1) !== nothing)
            close > j && push!(marks, (j, close - 1, :string))
            i = close + 1
            continue
          end
        end
      elseif (j = unspaced(chars, k, upto)) <= upto && chars[j] == ':'
        push!(marks, (i, k - 1, :type))        # a feature, like the min-width of (min-width: 600px)
      elseif (how == :prelude && (word in ("and", "or", "not", "only", "when") || (scss && word in SCSS_WORDS))) ||
             (scss && word in ("and", "or", "not"))   # in SCSS, as in if($a and $b, 1, 2)
        push!(marks, (i, k - 1, :keyword))
      end
      i = k
    else
      i += 1
    end
  end
  upto + 1, start in (:value, :prelude) ? IN_STYLE_VALUE : IN_STYLE
end

"""
Marks the string that opens at `chars[i]` and gives the place of the quote that
closes it, or `upto`. In Less a ~ can come before it, and @{name} in it puts a
variable's value there, as #{...} does in SCSS.
"""
quoted!(marks, chars, i, upto, dialect) = begin
  opener = dialect == :less ? '@' : dialect == :scss ? '#' : '\0'   # the @ of @{name}, or the # of #{...}
  from = i
  i += chars[i] == '~'
  q = chars[i]
  j = i + 1
  while j <= upto && chars[j] != q
    if chars[j] == '\\'
      j += 2
    elseif chars[j] == opener && j < upto && chars[j+1] == '{'
      from < j && push!(marks, (from, j - 1, :string))
      j = interpolated!(marks, chars, j, upto, dialect) + 1
      from = j
    else
      j += 1
    end
  end
  j = min(j, upto)
  from <= j && push!(marks, (from, j, :string))
  j
end

"""
Marks the @{name} of Less or the #{...} of SCSS that opens at `chars[i]`. Its @{
or #{ and its } have the colour of a keyword, and the code of SCSS between them
has the colours of a value. Gives the place of its }, or `upto`.
"""
interpolated!(marks, chars, i, upto, dialect) = begin
  push!(marks, (i, i + 1, :keyword))
  if dialect == :scss
    k = first(part!(marks, chars, i + 2, upto, :value, dialect))
  else
    k = i + 2
    while k <= upto && chars[k] != '}' k += 1 end
  end
  k <= upto && chars[k] == '}' && push!(marks, (k, k, :keyword))
  min(k, upto)
end

# --- what Julia's REPL shows ------------------------------------------------------------------
#
# A julia-repl or jldoctest block shows a session of Julia's REPL. Each line of
# code follows a prompt, like `julia>`, and what the code printed comes after
# it. A prompt has the colour of a keyword, the code after julia> the colours of
# Julia, and the code after shell> the colours of a shell. The words after
# help?> and pkg>, and what the code printed, are all one colour. The code after
# julia> goes on in the lines below it that start with 7 spaces, the width of
# `julia> `, as in the doctests of Documenter.
#
# A jldoctest block can be a script instead, with no prompts. Its code has the
# colours of Julia up to a line `# output`, and what follows that line is what
# the code printed. What a line leaves open:

const REPL_START = '\0'      # nothing: the block starts
const REPL_OUTPUT = 'o'      # what the code printed
const REPL_CODE = 'i'        # the code after julia>, which a line that starts with 7 spaces goes on
const REPL_CODE_DOC = 'I'    # the same, in a string in three quotes
const REPL_SCRIPT = 'k'      # the code of a jldoctest with no prompts
const REPL_SCRIPT_DOC = 'K'  # the same, in a string in three quotes
const REPL_OPENS = (REPL_OUTPUT, REPL_CODE, REPL_CODE_DOC, REPL_SCRIPT, REPL_SCRIPT_DOC)

"""
A prompt of Julia's REPL, like julia>, help?>, shell> or (@v1.12) pkg>, with
the space after it. Spaces can come before it, as in a block in a list.
"""
const PROMPT = r"^(\s*)(julia|help\?|shell|(?:\([^()]*\) )?pkg)> ?"

"""
True when `name` is a language that shows a session of Julia's REPL. A fence
like ```` ```jldoctest; setup = :(using X) ```` gives the name `jldoctest;`.
"""
isrepl(name) = lowercase(first(split(name, ';'))) in ("julia-repl", "jldoctest", "jlcon")

"The parts of `text` in the language `lang`, as `read_line` gives them, `by` columns to the right"
shifted(text, lang, open, by) = begin
  ts, left = read_line(text, lang, open)
  ([Token(t.col + by, t.text, t.kind) for t in ts if !isempty(t.text)], left)
end

"The parts of a line of a julia-repl or jldoctest block, and what it leaves open. `name` is the block's language."
repl_line(text, name, open) = begin
  state = open in REPL_OPENS ? open : REPL_START
  m = match(PROMPT, text)
  if m !== nothing
    chars = collect(text)
    s = length(m[1])                     # the spaces before the prompt
    p = length(m.match)                  # those, the prompt and the space after it
    q = length(rstrip(m.match))          # those and the prompt
    julia = m[2] == "julia"
    ts, left = shifted(String(chars[p+1:end]), julia ? "julia" : m[2] == "shell" ? "sh" : "", '\0', p)
    head = s > 0 ? [Token(0, String(chars[1:s]), :plain)] : Token[]
    push!(head, Token(s, String(chars[s+1:q]), :keyword))
    p > q && push!(head, Token(q, String(chars[q+1:p]), :plain))
    return ([head; ts], !julia ? REPL_OUTPUT : left == '\0' ? REPL_CODE : REPL_CODE_DOC)
  end
  if state in (REPL_CODE, REPL_CODE_DOC) && startswith(text, "       ")
    ts, left = shifted(text[8:end], "julia", state == REPL_CODE_DOC ? '"' : '\0', 7)
    return ([Token(0, "       ", :plain); ts], left == '\0' ? REPL_CODE : REPL_CODE_DOC)
  end
  doctest = startswith(lowercase(name), "jldoctest")
  if state in (REPL_SCRIPT, REPL_SCRIPT_DOC) || (doctest && state == REPL_START && !all(isspace, text))
    strip(text) == "# output" && return ([Token(0, String(text), :comment)], REPL_OUTPUT)
    ts, left = read_line(text, "julia", state == REPL_SCRIPT_DOC ? '"' : '\0')
    return (ts, left == '\0' ? REPL_SCRIPT : REPL_SCRIPT_DOC)
  end
  # What the code printed. Blank lines at the start don't yet say which kind of block it is.
  ([Token(0, String(text), :plain)], state == REPL_START && all(isspace, text) ? REPL_START : REPL_OUTPUT)
end

# --- diffs -------------------------------------------------------------------------------------
#
# A line that a diff adds, which starts with +, has the colour of an added line,
# and a line that it takes away, which starts with -, the colour of a removed
# line. They're the colours that Ladder shows a change in. A line that names a
# file, like `--- a/main.jl` or `diff --git a/main.jl b/main.jl`, has the colour
# of a keyword, and the @@ ... @@ that starts a part of a change the colour of a
# type. Git's other lines, like `index 1a2b..3c4d`, have the colour of a comment.

"True when `name` is a language that's read as a diff"
isdiff(name) = lowercase(name) in ("diff", "patch")

"A line that names a file: diff, or --- or +++ before a/, b/, /dev/null, or a name, a tab and a time"
const DIFF_FILE = r"^(diff |(---|\+\+\+) (a/|b/|/dev/null|[^\t]*\t))"

"The other lines that git writes about a file"
const DIFF_NOTE = r"^(index |new file mode|deleted file mode|old mode|new mode|similarity index|dissimilarity index|rename from|rename to|copy from|copy to|Binary files|\\ )"

"The parts of a line of a diff"
diff_line(text) = begin
  s = String(text)
  isempty(s) && return Token[]
  if startswith(s, "@@")
    k = findnext("@@", s, 3)
    k === nothing && return [Token(0, s, :type)]
    head = s[1:last(k)]
    last(k) == lastindex(s) && return [Token(0, head, :type)]
    return [Token(0, head, :type), Token(length(head), s[nextind(s, last(k)):end], :plain)]
  end
  [Token(0, s, occursin(DIFF_FILE, s) ? :keyword : s[1] == '+' ? :added : s[1] == '-' ? :removed :
               occursin(DIFF_NOTE, s) ? :comment : :plain)]
end

# --- shells ----------------------------------------------------------------------------------------
#
# The name of a command, like the git of `git add -A`, has the colour of a call,
# and a keyword like if or done the colour of a keyword. A word that's a number,
# like the 2 of 2>/dev/null, has the colour of a number, but a number inside a
# word, like the 05 of photo-05.png, doesn't. A variable, like $HOME or ${dir},
# and the code in $(...), have the colours they have in a string in double
# quotes. A comment starts with a # at the start of a word.
#
# A here-document, the lines that a command like `cat <<EOF` reads up to a line
# EOF, has the colour of a string. In a block of a session in a terminal, like
# ```console, a line that starts with a prompt like $ is a command, and the other
# lines are what the commands printed. In a bash block a $ and a space at the
# start of a line are a prompt too. What a line leaves open:

const SH_GOES_ON = '\\'   # the command of the line above, which ended with \, goes on
# or a here-document: a character from U+E001 that stands for the word that ends it. See `heredoc`.

"True when `name` is a language of a shell's commands"
isshell(name) = lowercase(name) in ("bash", "sh", "zsh", "shell", "fish") || issession(name)

"True when `name` is a language of a session in a terminal, whose lines with no prompt are what the commands printed"
issession(name) = lowercase(name) in ("console", "shell-session", "sh-session", "terminal")

"The words that end here-documents. The nth is the one that `Char(0xe000 + n)` stands for."
const HEREDOC_ENDS = String[]

"The character that a line leaves open when a here-document starts on it, which the word `word` ends"
heredoc(word) = begin
  k = something(findfirst(==(word), HEREDOC_ENDS), 0)
  k == 0 && length(HEREDOC_ENDS) < 6000 && (push!(HEREDOC_ENDS, word); k = length(HEREDOC_ENDS))
  Char(0xe000 + max(k, 1))
end

"The word that ends the here-document that `open` stands for, or nothing"
heredoc_end(open) = (k = Int(UInt32(open)) - 0xe000; 1 <= k <= length(HEREDOC_ENDS) ? HEREDOC_ENDS[k] : nothing)

"A word that's a number, like 2, 1.5, 127.0.0.1 or 9001:9001. An option like -1 isn't one."
const SH_NUMBER = r"^\d[\d.:]*$"

"The commands whose next word is the name of a command too, like the git of `sudo git pull`"
const SH_BEFORE = ("sudo", "exec", "time", "nohup", "env", "command", "builtin", "xargs", "nice")

"The parts of a line of a shell's commands, and what it leaves open. `name` is its language."
shell_line(text, name, open) = begin
  chars = collect(text)
  n = length(chars)
  ending = heredoc_end(open)
  if ending !== nothing
    # A line of a here-document, or the line with the word that ends it
    return (n == 0 ? Token[] : [Token(0, String(text), :string)], strip(text) == ending ? '\0' : open)
  end
  marks = Tuple{Int,Int,Symbol}[]
  goes_on = open == SH_GOES_ON
  i = 1
  m = goes_on ? nothing : match(issession(name) ? r"^(\s*)([$%❯>]) " : r"^(\s*)(\$) ", text)
  if m !== nothing
    s = length(m[1])
    push!(marks, (s + 1, s + 1, :keyword))
    i = length(m.match) + 1
  elseif issession(name) && !goes_on
    return ([Token(0, String(text), :plain)], '\0')   # what a command printed
  end
  shell!(marks, chars, i, nothing, !goes_on)
  # A here-document starts at a << that isn't in a string or a comment, like the one of cat <<'EOF'.
  # Three of <, as in <<<, give a command a word instead.
  left = '\0'
  for d in eachmatch(r"(?<!<)<<(?!<)-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", text)
    at = length(SubString(text, 1, d.offset))
    any(((a, b, kind),) -> a <= at <= b && kind in (:string, :comment), marks) || (left = heredoc(d[2]))
  end
  if left == '\0' && n > 0 && chars[n] == '\\' && !any(((a, b, kind),) -> a <= n <= b && kind == :comment, marks)
    left = SH_GOES_ON
  end
  (marked(chars, marks), left)
end

"""
Marks the commands from `chars[i]`. `command` is true when the first word is
the name of a command. It stops at the end of the line, or at a `close` that
has no partner, like the ) at the end of \$(x), and gives the place it stopped.
"""
shell!(marks, chars, i, close=nothing, command=true) = begin
  n = length(chars)
  depth = 0
  while i <= n
    c = chars[i]
    d = i < n ? chars[i+1] : '\0'
    if c == close && depth == 0
      return i
    elseif c == '('
      depth += 1
      command = true
      i += 1
    elseif c == ')'
      depth -= 1
      i += 1
    elseif isspace(c)
      i += 1
    elseif c == '#' && (i == 1 || isspace(chars[i-1]) || chars[i-1] in ";|&(")
      push!(marks, (i, n, :comment))
      return n + 1
    elseif c == '"' || c == '\''
      i = string!(marks, chars, SHELL, i) + 1
      command = false
    elseif c == '$'
      if d == '('
        push!(marks, (i, i + 1, :keyword))
        k = shell!(marks, chars, i + 2, ')')
        k <= n && push!(marks, (k, k, :keyword))
        i = k + 1
      elseif d == '{'
        k = something(findnext(==('}'), chars, i + 2), n)
        push!(marks, (i, i + 1, :keyword))
        k > i + 1 && chars[k] == '}' && push!(marks, (k, k, :keyword))
        i = k + 1
      elseif isletter(d) || d == '_'
        push!(marks, (i, i, :keyword))
        i = namend(chars, SHELL, i + 1) + 1
      else
        isdigit(d) || d in "@*#?\$!-" ? (push!(marks, (i, i, :keyword)); i += 2) : (i += 1)
      end
      command = false
    elseif c in "|&;"
      command = true
      i += 1
    elseif c in "<>`"
      i += 1
    else
      # A word, up to a space, a quote, a $ or a character like | or > that ends one
      k = i
      while k <= n && !isspace(chars[k]) && !(chars[k] in "|&;()<>\"'\$`")
        k += chars[k] == '\\' ? 2 : 1
      end
      k = min(k, n + 1)
      w = chars[i:k-1]
      word = String(w)
      e = findfirst(==('='), w)
      if word in SHELL.keywords
        push!(marks, (i, k - 1, :keyword))
        command = word in ("if", "then", "do", "else", "elif", "while", "until", "function")
      elseif word in SHELL.literals
        push!(marks, (i, k - 1, :number))
        command = false
      elseif word in ("{", "!")
        command = true
      elseif word in ("[", "[[", "]", "]]", "}")
        command = false
      elseif occursin(SH_NUMBER, word)
        push!(marks, (i, k - 1, :number))
        command = false
      elseif command && e !== nothing && e > 1 && all(isname, w[1:e-1])
        # A variable that's set for the command that follows, like the PORT of PORT=9101 julia server.jl
        e < length(w) && occursin(SH_NUMBER, String(w[e+1:end])) && push!(marks, (i + e, k - 1, :number))
      elseif command && w[1] != '-'
        push!(marks, (i, k - 1, :call))
        command = word in SH_BEFORE
      else
        # An argument. The value of an option, like the 2 of --threads=2, can be a number.
        e !== nothing && e < length(w) && occursin(SH_NUMBER, String(w[e+1:end])) && push!(marks, (i + e, k - 1, :number))
        command = command && w[1] == '-'
      end
      i = k
    end
  end
  n + 1
end

"The tokens of the characters `chars`, which have the marks `marks`"
marked(chars, marks) = begin
  out = Token[]
  plain = 1                         # the first character that isn't in a token yet
  for (i, j, kind) in marks
    plain < i && push!(out, Token(plain - 1, String(chars[plain:i-1]), :plain))
    push!(out, Token(i - 1, String(chars[i:j]), kind))
    plain = j + 1
  end
  plain <= length(chars) && push!(out, Token(plain - 1, String(chars[plain:end]), :plain))
  out
end

export Token, tokens, left_open
