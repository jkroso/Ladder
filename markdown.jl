# Reads Markdown one line at a time, the way a live-preview editor needs it.
# `classify` says what each line of a document is: a heading, a list item, a
# line of a code block and so on. `spans` splits the text of a line into runs
# of bold, italic, code and link text, and the markup characters around them.
# Columns count characters from 0, so column 0 is before the first character.
#
# Maths is written as TeX between dollar signs: $x^2$ in a line of text, and
# on lines of its own between a line of $$ and another. Those lines are read
# as a code block in the language `math`, and so is a ```math code block.
#
# A callout is a quote whose first line names a kind of note, as GitHub writes
# one: `> [!NOTE]`, with the lines of the note under it, each after a `>`. The
# kinds are note, tip, important, warning and caution, in any case. Words after
# the `]` are the callout's title. Without them, its title is its kind's name.
#
# Two more marks come from Obsidian. ==Words== between two = have a
# highlighter's colour behind them. %%A note%% between two % is a comment: rich
# text hides it, and the line shows it while its markup shows. A comment can
# be on lines of its own: a line that starts with %%, the lines under it, and a
# line that ends with %%. Those lines are read as a code block in the language
# %%, so nothing in them is part of the text. Neither mark counts in code.
#
# A wiki link names a page and not its file, as Obsidian writes one: [[Ideas]]
# links to the page Ideas.md. [[Ideas|my ideas]] shows the words "my ideas",
# and [[Ideas#Plans]] goes to the heading Plans of that page. [[#Plans]] goes to
# a heading of the page that it's in. In a table, write the | as \|. The link
# of each span of its text is the name between the brackets, in brackets: see
# `wikilink`. The editor finds the page, wherever it is: see `wiki_path` in wiki_links.jl.

@use "github.com/jkroso/Prospects.jl" ["Enum" @Enum]

@Enum Kind blank paragraph heading bullet ordered blockquote fence code rule table todo

"What one line of a document is"
struct Line
  kind::Kind
  level::Int   # a heading's level, how many spaces indent the line, or 1 on the line that closes a code block or opens a callout
  prefix::Int  # how many characters of indent and markup start the line
  lang::String # the language of the code block that a line of code is in, or the kind of callout that a line of a quote is in
end

Line(kind::Kind, level::Int, prefix::Int) = Line(kind, level, prefix, "")

const HEADING = r"^(#{1,6})\s+"
const BULLET  = r"^(\s*)[-*+]\s+"
const TODO    = r"^(\s*)[-*+]\s+\[([ xX])\]\s+"   # a list item with a box: - [ ] to do, or - [x] done
const ORDERED = r"^(\s*)\d+[.)]\s+"
const QUOTE   = r"^\s*>\s?"
const CALLOUTS = ("note", "tip", "important", "warning", "caution")   # the kinds of callout
const CALLOUT = Regex("^\\s*>\\s?\\[!(" * join(CALLOUTS, '|') * ")\\][ \\t]*", "i")   # what starts the first line of one
const FENCE   = r"^\s*(`{3,}|~{3,})\s*([^\s`]*)"
const RULE    = r"^\s*([-*_])(\s*\1){2,}\s*$"
const DIVIDER = r"^\s*\|?\s*:?-+:?\s*(\|\s*:?-+:?\s*)*\|?\s*$"

"What `text` is. `lang` is the language of the code block it's inside, or nothing outside one."
Line(text::AbstractString, lang::Union{Nothing,AbstractString}=nothing) = begin
  m = match(FENCE, text)
  m === nothing || return Line(Kind.fence, 0, 0, m[2])
  lang === nothing || return Line(Kind.code, 0, 0, lang)
  isempty(strip(text)) && return Line(Kind.blank, 0, 0)
  m = match(HEADING, text)
  m === nothing || return Line(Kind.heading, length(m[1]), length(m.match))
  occursin(RULE, text) && return Line(Kind.rule, 0, 0)
  m = match(TODO, text)
  m === nothing || return Line(Kind.todo, length(m[1]), length(m.match))
  m = match(BULLET, text)
  m === nothing || return Line(Kind.bullet, length(m[1]), length(m.match))
  m = match(ORDERED, text)
  m === nothing || return Line(Kind.ordered, length(m[1]), length(m.match))
  m = match(QUOTE, text)
  m === nothing || return Line(Kind.blockquote, 0, length(m.match))
  startswith(lstrip(text), '|') && return Line(Kind.table, 0, 0)
  indent = length(text) - length(lstrip(text))
  Line(Kind.paragraph, indent, indent)
end

"The kind of callout that `line` is a line of, like \"note\", or \"\" for any other line"
callout(line::Line) = line.kind == Kind.blockquote ? line.lang : ""

"True when `line` is the first line of a callout: the line that names its kind"
opens_callout(line::Line) = line.kind == Kind.blockquote && line.level == 1

"True when `text` is a to-do item that's done: its box has an x in it"
isdone(text::AbstractString) = (m = match(TODO, text); m !== nothing && m[2] != " ")

const MATH = "math"                      # the language of the lines of a formula that's on lines of its own
const DOLLARS = r"^\s*\$\$\s*$"          # a line that opens or closes one

const MATTER = "front matter"            # the language of the lines of a document's YAML front matter
const TOML_MATTER = "toml front matter"  # and of its TOML front matter, between lines of +++
const KEY = r"^\w[\w .-]*:(\s|$)"
const TOML_KEY = r"^\s*[\w\"'.-]+\s*="   # like `title = "Notes"`, or `site.title = ` with a dot

"True when `text` is the line that closes a document's front matter"
closes(text::AbstractString) = rstrip(text) in ("---", "...")

"True when `text` can be a line of front matter: a key, a list item, a comment, a line that's indented or an empty line"
isyaml(text::AbstractString) =
  isempty(strip(text)) || startswith(text, ' ') || startswith(text, '#') || occursin(r"^-(\s|$)", text) || occursin(KEY, text)

"""
The line that closes a document's front matter, or 0 when it has none. Front
matter is at the very top of a file, and says things about the document. It
isn't part of its text. There are two kinds:

- lines of YAML between a line of --- and another, like `title: Notes`
- lines of TOML between a line of +++ and another, like `title = "Notes"`

One of the lines between has to be a key. Each line of YAML has to be one that
YAML can have, so a page that starts with a divider and a paragraph stays as it is.
"""
front_matter(lines) = begin
  length(lines) >= 2 || return 0
  fence = rstrip(lines[1])
  fence == "+++" && return toml_matter(lines)
  fence == "---" || return 0
  keys = 0
  for i in 2:length(lines)
    closes(lines[i]) && return keys > 0 || i == 2 ? i : 0
    isyaml(lines[i]) || return 0
    keys += occursin(KEY, lines[i])
  end
  0
end

"`s` without the quotes round it that YAML and TOML can have"
unquote(s::AbstractString) = (t = strip(s); length(t) >= 2 && t[1] == t[end] && t[1] in ('"', '\'') ? String(t[2:end-1]) : String(t))

"""
What the front matter of `lines` sets each of its keys to, by the key in small
letters, with no quotes round a value: `title: Notes` in YAML, or
`title = "Notes"` in TOML. A line that sets no key, like an item of a list,
says nothing. Lines with no front matter say nothing.

    matter_keys(["---", "title: Notes", "---", "Hello"])   # Dict("title" => "Notes")
"""
matter_keys(lines) = begin
  said = Dict{String,String}()
  stop = front_matter(lines)
  stop == 0 && return said
  pattern = rstrip(lines[1]) == "+++" ? r"^\s*([\w.-]+)\s*=\s*(.*?)\s*$" : r"^(\w[\w .-]*):\s*(.*?)\s*$"
  for line in @view lines[2:stop-1]
    m = match(pattern, line)
    m === nothing || (said[lowercase(strip(m[1]))] = unquote(m[2]))
  end
  said
end

"`lines` after their front matter, or all of them when they have none"
after_matter(lines) = @view lines[front_matter(lines)+1:end]

"The line of +++ that closes TOML front matter, or 0. A line of TOML can be anything, like the `]` that ends a list."
toml_matter(lines) = begin
  keys = 0
  for i in 2:length(lines)
    rstrip(lines[i]) == "+++" && return keys > 0 || i == 2 ? i : 0
    keys += occursin(TOML_KEY, lines[i])
  end
  0
end

const COMMENT = "%%"   # the language of the lines of a comment that's on lines of its own

"True when `text` can open a comment of several lines: it starts with %%, and no other %% closes it on the same line"
opens_comment(text::AbstractString) = (s = strip(text); startswith(s, "%%") && !occursin("%%", chop(s, head=2, tail=0)))

"True when `text` can close a comment of several lines: it ends with %%"
closes_comment(text::AbstractString) = endswith(rstrip(text), "%%")

"The language of the lines of a document's front matter: `MATTER` for YAML or `TOML_MATTER` for TOML"
matter_lang(lines) = rstrip(lines[1]) == "+++" ? TOML_MATTER : MATTER

"What each line of a document is"
classify(lines) = begin
  lang = nothing
  opened = ""   # the backticks or tildes of the fence that opened the code block being read
  dollars = 0   # the line of $$ that closes the formula whose lines are being read, or 0 outside one
  hush = 0      # the line of %% that closes the comment whose lines are being read, or 0 outside one
  noted, quoted = "", -1   # the kind of callout that the quote being read is, and the last line of a quote that was read
  matter = front_matter(lines)
  map(enumerate(lines)) do (i, text)
    # Front matter is a block of its own, like a code block: its first and last lines open and close it
    i <= matter && return Line(i == 1 || i == matter ? Kind.fence : Kind.code, i == matter ? 1 : 0, 0, matter_lang(lines))
    # A comment on lines of its own is read as a code block in the language %%, so its lines are no part of the text
    if hush != 0
      i < hush && return Line(Kind.code, 0, 0, COMMENT)
      hush = 0
      return Line(Kind.fence, 1, 0, COMMENT)
    elseif lang === nothing && dollars == 0 && opens_comment(text)
      # A line that starts with %% opens a comment when a line under it ends with %%. Without that one, it's a line of text.
      close = findnext(closes_comment, lines, i + 1)
      if close !== nothing
        hush = close
        return Line(Kind.fence, 0, 0, COMMENT)
      end
    end
    if dollars != 0
      # Only a line of $$ closes a formula, so a line of ``` in it is one of its lines
      i < dollars && return Line(Kind.code, 0, 0, MATH)
      dollars = 0
      return Line(Kind.fence, 1, 0, MATH)
    elseif lang === nothing && occursin(DOLLARS, text)
      # A line of $$ opens a formula when another one closes it. Without that one, it's a line of text.
      close = findnext(t -> occursin(DOLLARS, t), lines, i + 1)
      if close !== nothing
        dollars = close
        return Line(Kind.fence, 0, 0, MATH)
      end
    end
    line = Line(text, lang)
    if line.kind == Kind.blockquote
      # The first line of a quote can make it a callout. Each line of the quote is then a line of that callout.
      opens = quoted != i - 1
      quoted = i
      m = opens ? match(CALLOUT, text) : nothing
      opens && (noted = m === nothing ? "" : lowercase(m[1]))
      isempty(noted) && return line
      return m === nothing ? Line(Kind.blockquote, 0, line.prefix, noted) : Line(Kind.blockquote, 1, length(m.match), noted)
    end
    # The line that opens a code block names its language
    line.kind == Kind.fence || return line
    run, after = fence_parts(text)
    if lang !== nothing
      # Only a fence like the one that opened the block closes it, as on GitHub: the same character, at least
      # as many of them, and no language. So a block that opens with ```` can show a block that opens with ```.
      (run[1] == opened[1] && length(run) >= length(opened) && isempty(strip(after))) || return Line(Kind.code, 0, 0, lang)
      lang = nothing
      return Line(Kind.fence, 1, 0, line.lang)
    end
    opened, lang = run, line.lang
    Line(Kind.fence, 0, 0, line.lang)
  end
end

"The backticks or tildes that start a line of a fence, and the text after them"
fence_parts(text) = (m = match(r"^\s*(`+|~+)(.*)$", text); (String(m[1]), String(m[2])))

"A run of a line's text that is all drawn one way"
struct Span
  col::Int       # the column of its first character
  text::String
  bold::Bool
  italic::Bool
  code::Bool
  strike::Bool
  link::String   # where it goes when it's the text of a link
  markup::Bool   # true for characters like ** that only say how to draw others
  live::Bool     # true for inline code that runs: the code of !`code`
  math::Bool     # true for the TeX of a formula: the x^2 of $x^2$
  highlit::Bool  # true for words between == and ==, which have a highlighter's colour behind them
  comment::Bool  # true for the words of a comment: the note of %%note%%, which rich text hides
end

Span(col, text, bold, italic, code, strike, link, markup, live, math=false) = Span(col, text, bold, italic, code, strike, link, markup, live, math, false, false)

struct Style
  bold::Bool
  italic::Bool
  strike::Bool
  link::String
  highlit::Bool
end

Style() = Style(false, false, false, "", false)

"The link of the text of a wiki link: `[[Ideas#Plans]]` for the link [[Ideas#Plans|my plans]]"
wikilink(target::AbstractString) = "[[" * target * "]]"

"The page and heading that a span's link names when it's the link of a wiki link, like \"Ideas#Plans\", or nothing for any other link"
wikitarget(link::AbstractString) = startswith(link, "[[") && endswith(link, "]]") && length(link) > 4 ? chop(link, head=2, tail=2) : nothing

"""
Where the wiki link that opens with [[ at `i` ends: the first of its two ]], and
its name, without the spaces around it. It's (0, \"\") when there's no wiki link
at `i`: the ]] isn't on the line, a bracket is between, or the name is empty.
"""
wiki_end(chars, i, to) = begin
  j = find(chars, "]]", i + 2, to)
  j == 0 && return (0, "")
  inner = @view chars[i+2:j-1]
  any(c -> c == '[' || c == ']', inner) && return (0, "")
  bar = findfirst(==('|'), inner)
  name = bar === nothing ? String(inner) : String(inner[1:bar-1])
  # In a table, the | is written \|, so the | doesn't end the cell
  bar !== nothing && endswith(name, '\\') && (name = chop(name))
  name = String(strip(name))
  (isempty(name) || name == "#") ? (0, "") : (j, name)
end

isword(c::Char) = isletter(c) || isdigit(c)

"The index where `delim` next starts in `chars[from:to]`, or 0"
find(chars, delim::String, from, to) = begin
  n = length(delim)
  for i in from:to-n+1
    all(chars[i+k-1] == delim[k] for k in 1:n) && return i
  end
  0
end

"""
Where the run that opens with `delim` at `i` closes, or 0 if it doesn't. The
text between can't start or end with a space, and an _ inside a word like
snake_case doesn't count.
"""
closer(chars, delim::String, i, to) = begin
  n = length(delim)
  start = i + n
  (start <= to && !isspace(chars[start])) || return 0
  delim[1] == '_' && i > 1 && isword(chars[i-1]) && return 0
  j = start + 1
  while (j = find(chars, delim, j, to)) != 0
    ok = !isspace(chars[j-1]) && !(delim[1] == '_' && j + n <= to && isword(chars[j+n]))
    # A lone * can't close on the first star of a **
    # In ***both***, the ** closes on the last two stars
    ok && n == 2 && j + 2 <= to && chars[j+2] == delim[1] && return j + 1
    ok && !(n == 1 && j < to && chars[j+1] == delim[1]) && return j
    j += 1
  end
  0
end

"""
Where the formula that opens with `n` dollar signs at `i` closes, or 0 if it
doesn't. The TeX can't start or end with a space, and a digit can't follow it,
so the dollar signs of "from \$5 to \$10" are dollar signs. Code comes before
a formula: one that would hold code doesn't open, so the dollar sign of
"costs \$!`price`" is a dollar sign, whatever the code holds.
"""
math_end(chars, i, n, to) = begin
  start = i + n
  (start <= to && !isspace(chars[start])) || return 0
  j = start
  while j <= to
    if chars[j] == '\\'
      j += 2   # \$ in TeX is a dollar sign
      continue
    end
    # A ` that some code starts with, and not one that TeX has by itself
    chars[j] == '`' && find(chars, "`", j + 1, to) > j + 1 && return 0
    if chars[j] == '$' && j > start && !isspace(chars[j-1]) && (n == 1 || (j < to && chars[j+1] == '$'))
      (j + n > to || !isdigit(chars[j+n])) && return j
    end
    j += 1
  end
  0
end

"Split `chars[from:to]` into spans, added to `out`. `offset` is the column of `chars[1]`."
function scan!(out, chars, from, to, style::Style, offset)
  plain = from
  emit(i, j; markup=false, code=false, live=false, math=false, comment=false, s=style) = i <= j &&
    push!(out, Span(offset + i - 1, String(chars[i:j]), s.bold, s.italic, code, s.strike, s.link, markup, live, math, s.highlit, comment))
  i = from
  while i <= to
    c = chars[i]
    next = i < to ? chars[i+1] : '\0'
    delim, inner = "", style
    if c == '\\' && i < to && ispunct(next)
      emit(plain, i - 1); emit(i, i, markup=true)
      plain = i + 1
      i += 2
      continue
    elseif c == '!' && next == '`'
      # !`code` is inline code that runs. The page shows what the code makes.
      j = find(chars, "`", i + 2, to)
      if j > i + 2
        emit(plain, i - 1); emit(i, i + 1, markup=true); emit(i + 2, j - 1, code=true, live=true); emit(j, j, markup=true)
        plain = i = j + 1
        continue
      end
    elseif c == '`'
      j = find(chars, "`", i + 1, to)
      if j > i + 1
        emit(plain, i - 1); emit(i, i, markup=true); emit(i + 1, j - 1, code=true); emit(j, j, markup=true)
        plain = i = j + 1
        continue
      end
    elseif c == '$'
      # $x^2$ is a formula, written in TeX. So is $$x^2$$.
      n = next == '$' ? 2 : 1
      j = math_end(chars, i, n, to)
      if j != 0
        emit(plain, i - 1); emit(i, i + n - 1, markup=true); emit(i + n, j - 1, math=true); emit(j, j + n - 1, markup=true)
        plain = i = j + n
        continue
      end
    elseif c == '{' && next == '=' && i + 2 <= to && chars[i+2] == '='
      # {==words==} are the words that a comment after them is about, as CriticMarkup writes them. They have a
      # highlighter's colour behind them, and their own markup is read.
      j = find(chars, "==}", i + 3, to)
      if j > i + 3
        emit(plain, i - 1); emit(i, i + 2, markup=true)
        scan!(out, chars, i + 3, j - 1, Style(style.bold, style.italic, style.strike, style.link, true), offset)
        emit(j, j + 2, markup=true)
        plain = i = j + 3
        continue
      end
    elseif c == '{' && next == '>' && i + 2 <= to && chars[i+2] == '>'
      # {>>note<<} is a comment, as CriticMarkup writes it. Rich text shows it in the margin, beside its line.
      # Its words are one span, with no markup read inside them.
      j = find(chars, "<<}", i + 3, to)
      if j != 0
        emit(plain, i - 1); emit(i, i + 2, markup=true); emit(i + 3, j - 1, comment=true); emit(j, j + 2, markup=true)
        plain = i = j + 3
        continue
      end
    elseif c == '%' && next == '%'
      # %%note%% is a comment, as in Obsidian. Its words are one span, with no markup read inside them.
      j = find(chars, "%%", i + 2, to)
      if j != 0
        emit(plain, i - 1); emit(i, i + 1, markup=true); emit(i + 2, j - 1, comment=true); emit(j, j + 1, markup=true)
        plain = i = j + 2
        continue
      end
    elseif c == '[' && next == '['
      # [[Ideas]] is a wiki link to the page Ideas, and its name shows. [[Ideas|my ideas]] shows the words after the |.
      j, name = wiki_end(chars, i, to)
      if j != 0
        link = Style(style.bold, style.italic, style.strike, wikilink(name), style.highlit)
        bar = findnext(==('|'), chars, i + 2)
        bar = bar !== nothing && bar < j ? bar : 0
        emit(plain, i - 1)
        if bar != 0 && any(!isspace, @view chars[bar+1:j-1])
          emit(i, bar, markup=true); emit(bar + 1, j - 1, s=link); emit(j, j + 1, markup=true)
        else
          # A | with no words after it is markup, and so is the \ before a | in a table
          stop = bar == 0 ? j - 1 : bar - 1 - (chars[bar-1] == '\\')
          emit(i, i + 1, markup=true); emit(i + 2, stop, s=link); emit(stop + 1, j + 1, markup=true)
        end
        plain = i = j + 2
        continue
      end
    elseif c == '[' && next == '^'
      # [^name] points to a footnote. The name is the text of a link to "^name", which the page shows as a number.
      j = find(chars, "]", i + 2, to)
      if j > i + 2 && !any(isspace, chars[i+2:j-1])
        name = String(chars[i+2:j-1])
        emit(plain, i - 1); emit(i, i + 1, markup=true)
        emit(i + 2, j - 1, s=Style(style.bold, style.italic, style.strike, "^" * name, style.highlit))
        emit(j, j, markup=true)
        plain = i = j + 1
        continue
      end
    elseif c == '['
      j = find(chars, "](", i + 1, to)
      k = j == 0 ? 0 : find(chars, ")", j + 2, to)
      if j > i + 1 && k != 0
        url = String(chars[j+2:k-1])
        emit(plain, i - 1); emit(i, i, markup=true)
        scan!(out, chars, i + 1, j - 1, Style(style.bold, style.italic, style.strike, url, style.highlit), offset)
        emit(j, k, markup=true)
        plain = i = k + 1
        continue
      end
    elseif (c == '*' || c == '_') && next == c
      delim, inner = string(c, c), Style(true, style.italic, style.strike, style.link, style.highlit)
    elseif c == '*' || c == '_'
      delim, inner = string(c), Style(style.bold, true, style.strike, style.link, style.highlit)
    elseif c == '~' && next == '~'
      delim, inner = "~~", Style(style.bold, style.italic, true, style.link, style.highlit)
    elseif c == '=' && next == '=' && (i + 2 > to || chars[i+2] != '=') && (i == from || chars[i-1] != '=')
      # ==words== have a highlighter's colour behind them, as in Obsidian. A row of three or more = is only text.
      delim, inner = "==", Style(style.bold, style.italic, style.strike, style.link, true)
    end
    j = isempty(delim) ? 0 : closer(chars, delim, i, to)
    if j == 0
      i += max(1, length(delim))
      continue
    end
    n = length(delim)
    emit(plain, i - 1); emit(i, i + n - 1, markup=true)
    scan!(out, chars, i + n, j - 1, inner, offset)
    emit(j, j + n - 1, markup=true)
    plain = i = j + n
  end
  emit(plain, to)
  out
end

"The spans of `text`, whose first character is at column `offset` of its line"
spans(text::AbstractString, offset::Int=0) = begin
  chars = collect(text)
  # A block's name at the end of the line is markup, with the spaces before it: it says which block this is
  named = block_id(text) === nothing ? 0 : findlast(==('^'), chars)
  named == 0 && return scan!(Span[], chars, 1, length(chars), Style(), offset)
  ends = named - 1
  while ends >= 1 && isspace(chars[ends]); ends -= 1 end
  out = scan!(Span[], chars, 1, ends, Style(), offset)
  push!(out, Span(offset + ends, String(chars[ends+1:end]), false, false, false, false, "", true, false))
end

# A block can have a name, as Obsidian gives one: ^prices at the end of its
# last line, after a space, or on a line of its own under the block, for a
# table or a code block. Another page shows that block with ![[Costs#^prices]].
# The name doesn't show in rich text. See "a part of another page" in transclusion.jl.

const BLOCK_ID = r"(?:^|\s)\^([\p{L}\p{N}][\p{L}\p{N}_-]*)\s*$"

"The name that `text` gives its block, like `prices` for a line that ends with ^prices, or nothing"
block_id(text::AbstractString) = (m = match(BLOCK_ID, text); m === nothing ? nothing : String(m[1]))

"True when `text` holds only the name of the block above it, like ^prices"
only_id(text::AbstractString) = block_id(text) !== nothing && startswith(lstrip(text), '^')

"True for the line of dashes under a table's headings"
isdivider(text::AbstractString) = occursin(DIVIDER, text) && occursin('-', text)

"""
One cell of a row of a table. Its text runs from column `lo` to column `hi`,
without the spaces around it. The caret can go as far as `limit`, which is
past `hi` when spaces have been typed after the text.
"""
struct Cell
  lo::Int
  hi::Int
  limit::Int
end

"The cells of one row of a table"
tablecells(text::AbstractString) = begin
  chars = collect(text)
  n = length(chars)
  pipes = [i for i in 1:n if chars[i] == '|' && (i == 1 || chars[i-1] != '\\')]
  out = Cell[]
  isempty(pipes) && return out
  ends = pipes[2:end]
  # Text after the last | is a cell too
  any(!isspace, chars[last(pipes)+1:end]) && push!(ends, n + 1)
  for (p, q) in zip(pipes, ends)
    # The cell is chars[p+1:q-1], and column p is just after the first |
    a = findnext(!isspace, chars, p + 1)
    if a === nothing || a >= q
      size = q - 1 - p
      lo = p + min(1, size)
      push!(out, Cell(lo, lo, max(lo, q - 1 - (size >= 2 ? 1 : 0))))
    else
      z = findprev(!isspace, chars, q - 1)
      # One space before the closing | is left alone
      push!(out, Cell(a - 1, z, q > n ? n : z + max(0, q - 2 - z)))
    end
  end
  out
end

"How many words are in a document"
words(lines) = sum(text -> count(_ -> true, eachmatch(r"[\p{L}\p{N}][\p{L}\p{N}'’-]*", text)), lines, init=0)

export Kind, Line, Span, Cell, classify, spans, tablecells, isdivider, words, isdone, front_matter, matter_keys, after_matter, MATTER, TOML_MATTER, MATH, CALLOUTS, callout, opens_callout, wikilink, wikitarget, block_id, only_id
export COMMENT, opens_comment, closes_comment
