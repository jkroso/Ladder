# Reads an email as a server sends it, and writes one to send. An email is
# lines of headers, an empty line, and a body. The body can hold parts: the
# text as plain text and again as HTML, the pictures that the HTML shows, and
# the files that are attached. This file takes an email apart, turns it into
# the lines of a Markdown page, and builds an email from a page. It draws
# nothing, and it talks to no server.
#
#     m = message(bytes)              # the email, as a Part that holds its parts
#     header(m, "subject")            # a header as text, whatever it was written in
#     addresses(m, "to")              # ["Sam Lee" => "sam@example.com", ...]
#     sent(m)                         # when it was sent, in Unix seconds
#     page(m, keep=save)              # the lines of its Markdown page
#     markdown("<p>Hi <b>Sam</b></p>")   # "Hi **Sam**"
#     compose(from="me@example.com", to="Sam Lee <sam@example.com>", subject="Roof quote",
#             text="Hi Sam", id="<1@example.com>")   # the bytes of an email to send
#
# The page of an email starts with front matter, then has the email's text:
#
#     ---
#     from: Sam Lee <sam@example.com>
#     to: you@example.com
#     date: 14 Nov 2026, 9:32 am
#     subject: Roof quote
#     ---
#
#     Hi Jake,
#
#     The quote is attached.
#
#     [Roof quote.pdf](files/x/Roof%20quote.pdf)
#
# The text is the email's HTML part as Markdown, or its plain text when it has
# no HTML. `page` doesn't write files. It calls `keep(name, bytes, picture)`
# for each attachment and each picture, and `keep` gives the path that the page
# links to, or nothing to leave the file out. A path is written the way
# Ladder writes the path of a file that's dropped on a page: a space is %20,
# and ( and ) are %28 and %29.
#
# An email that breaks the rules is read as well as it can be. Nothing here
# throws because of what an email holds.

@use Base64: base64encode
@use Dates: Dates, DateTime
@use "../web/entities" entities latin LATIN_NAMES
@use "../web/dom" Token RAW tokens

"One part of an email, or a whole email"
struct Part
  type::String                           # like "text/plain", in lower case. "multipart/..." for a part that holds parts
  params::Dict{String,String}            # of its Content-Type: charset, name, boundary. The keys are in lower case.
  headers::Vector{Pair{String,String}}   # each header as it was sent, on one line, name => value
  name::String                           # the file name of an attachment, or ""
  id::String                             # its Content-ID without < >, or ""
  inline::Bool                           # its Content-Disposition is inline
  body::Vector{UInt8}                    # its bytes, after base64 or quoted-printable is undone. A part that holds parts has none.
  parts::Vector{Part}
end

const CR, LF, SPACE, TAB = UInt8('\r'), UInt8('\n'), UInt8(' '), UInt8('\t')

# --- character sets ---------------------------------------------------------------

"Bytes of UTF-8 as text. A byte that isn't UTF-8 becomes \ufffd."
utf8(bytes) = (s = String(Vector{UInt8}(bytes)); isvalid(s) ? s : String(Char[isvalid(c) ? c : '\ufffd' for c in s]))

const UTF8_NAMES = ("utf-8", "utf8", "unicode-1-1-utf-8")
const ASCII_NAMES = ("", "us-ascii", "ascii", "ansi_x3.4-1968", "unknown-8bit", "x-unknown", "default")
const ICONV = "/usr/lib/libiconv.dylib"   # the Mac's own library for every other character set

"""
Bytes in the character set `charset` as text, by the Mac's iconv. It's nothing
when iconv doesn't know the character set. A byte that the character set
doesn't have is left out.
"""
converted(bytes::Vector{UInt8}, charset) = begin
  occursin(r"^[\w.:+()-]+$", charset) || return nothing
  try
    cd = ccall((:iconv_open, ICONV), Ptr{Cvoid}, (Cstring, Cstring), "UTF-8", charset)
    cd == Ptr{Cvoid}(typemax(UInt)) && return nothing
    out = Vector{UInt8}(undef, 4 * length(bytes) + 64)
    n = GC.@preserve bytes out begin
      from, to = Ref(pointer(bytes)), Ref(pointer(out))
      left, room = Ref(Csize_t(length(bytes))), Ref(Csize_t(length(out)))
      step() = ccall((:iconv, ICONV), Csize_t, (Ptr{Cvoid}, Ptr{Ptr{UInt8}}, Ptr{Csize_t}, Ptr{Ptr{UInt8}}, Ptr{Csize_t}), cd, from, left, to, room)
      while left[] > 0 && step() == typemax(Csize_t) && left[] > 0 && room[] > 8
        from[] += 1
        left[] -= 1
      end
      # A character set that changes mode, like ISO-2022-JP, may have something left to write
      ccall((:iconv, ICONV), Csize_t, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Ptr{UInt8}}, Ptr{Csize_t}), cd, C_NULL, C_NULL, to, room)
      length(out) - Int(room[])
    end
    ccall((:iconv_close, ICONV), Cint, (Ptr{Cvoid},), cd)
    utf8(resize!(out, n))
  catch
    nothing
  end
end

"Bytes in the character set `charset` as text. Bytes in a character set that nothing here knows read as UTF-8 if they are UTF-8."
decode(bytes, charset) = begin
  name = lowercase(strip(charset))
  name in UTF8_NAMES && return utf8(bytes)
  if !(name in ASCII_NAMES || name in LATIN_NAMES)
    found = converted(Vector{UInt8}(bytes), name)
    found === nothing || return found
  end
  # Plain ASCII is UTF-8 too. An email that names no character set, or the wrong one, is most often UTF-8.
  s = String(Vector{UInt8}(bytes))
  isvalid(s) && !(name in LATIN_NAMES && !isascii(s)) ? s : latin(bytes)
end

# --- base64 and quoted-printable --------------------------------------------------

const B64 = let table = fill(0xff, 256)
  for (i, c) in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")
    table[UInt8(c)+1] = i - 1
  end
  table[UInt8('-')+1], table[UInt8('_')+1] = 62, 63   # the alphabet that's safe in a web address
  table
end

"The bytes that base64 text stands for. A character that isn't base64 is left out, and so is half a byte at the end."
unbase64(data) = begin
  out = sizehint!(UInt8[], length(data) * 3 ÷ 4)
  acc, bits = UInt32(0), 0
  for b in data
    if b == UInt8('=')   # the end of a piece. Another piece can follow it.
      acc, bits = UInt32(0), 0
      continue
    end
    v = B64[b+1]
    v == 0xff && continue
    acc = (acc << 6 | v) & 0xffffff
    bits += 6
    bits >= 8 && (bits -= 8; push!(out, (acc >> bits) % UInt8))
  end
  out
end

hexvalue(b) = UInt8('0') <= b <= UInt8('9') ? b - UInt8('0') : UInt8('a') <= (b | 0x20) <= UInt8('f') ? (b | 0x20) - UInt8('a') + 0x0a : 0xff

"The bytes that quoted-printable text stands for. `underscore` reads _ as a space, as a header's words do."
unquoted(data; underscore=false) = begin
  out = sizehint!(UInt8[], length(data))
  i, n = 1, length(data)
  while i <= n
    b = data[i]
    if b == UInt8('=')
      if i + 2 <= n && hexvalue(data[i+1]) != 0xff && hexvalue(data[i+2]) != 0xff
        push!(out, hexvalue(data[i+1]) << 4 | hexvalue(data[i+2]))
        i += 3
        continue
      end
      # An = at the end of a line joins the line to the next. Spaces can follow it.
      j = i + 1
      while j <= n && (data[j] == SPACE || data[j] == TAB)
        j += 1
      end
      if j > n || data[j] == LF || data[j] == CR
        i = j <= n && data[j] == CR && j < n && data[j+1] == LF ? j + 2 : j + 1
        continue
      end
    end
    push!(out, underscore && b == UInt8('_') ? SPACE : b)
    i += 1
  end
  out
end

# --- headers ----------------------------------------------------------------------

"Where the line that starts at `i` ends, and where the next line starts. `hi` is the last byte there is."
lineend(raw, i, hi) = begin
  j = findnext(==(LF), raw, i)
  (j === nothing || j > hi) && return (hi, hi + 1)
  (j > i && raw[j-1] == CR ? j - 2 : j - 1, j + 1)
end

const FIELD = r"^([!-9;-~]+)[ \t]*:[ \t]?(.*)$"s

"""
The headers that start at `lo`, and where the body starts. A header that goes
on over several lines is put on one. The headers end at an empty line, or at
the first line that can't be a header.
"""
headers(raw, lo, hi) = begin
  out = Pair{String,String}[]
  i = lo
  while i <= hi
    stop, next = lineend(raw, i, hi)
    stop < i && return (out, next)
    line = (s = String(raw[i:stop]); isvalid(s) ? s : latin(raw[i:stop]))
    if (raw[i] == SPACE || raw[i] == TAB) && !isempty(out)
      out[end] = out[end][1] => out[end][2] * " " * strip(line)
    elseif (m = match(FIELD, line)) !== nothing
      push!(out, String(m[1]) => String(m[2]))
    elseif !(isempty(out) && startswith(line, "From "))   # a file of many emails starts each one with such a line
      break
    end
    i = next
  end
  (out, i)
end

"The first header of `p` called `name`, as it was sent, or \"\""
field(p::Part, name) = field(p.headers, name)
field(headers::Vector{Pair{String,String}}, name) = begin
  name = lowercase(name)
  i = findfirst(h -> lowercase(h[1]) == name, headers)
  i === nothing ? "" : headers[i][2]
end

const WORD = r"=\?([^?\s]+)\?([bBqQ])\?([^?\s]*)\?="

"`s` with each word like =?UTF-8?B?...?= as the text it stands for"
unworded(s::AbstractString) = begin
  occursin("=?", s) || return String(s)
  out = IOBuffer()
  at = firstindex(s)
  charset, bytes = "", UInt8[]
  write!() = (isempty(charset) || print(out, decode(bytes, charset)); charset = ""; bytes = UInt8[])
  for m in eachmatch(WORD, s)
    between = SubString(s, at, prevind(s, m.offset))
    name = lowercase(first(split(m[1], '*')))
    # Words with only spaces between them are one piece of text, which can be cut in the middle of a character.
    # The spaces aren't part of the text.
    adjacent = !isempty(charset) && all(isspace, between)
    (adjacent && name == charset) || write!()
    adjacent || print(out, between)
    charset = name
    append!(bytes, lowercase(m[2]) == "b" ? unbase64(codeunits(m[3])) : unquoted(codeunits(m[3]), underscore=true))
    at = m.offset + ncodeunits(m.match)
  end
  write!()
  print(out, SubString(s, at))
  String(take!(out))
end

"`s` on one line, with one space where it had several, or a line break"
oneline(s::AbstractString) = String(strip(replace(s, r"\s+" => " ")))

"The first header of `p` called `name`, as text, or \"\" when it has none. The name can be in any case."
header(p::Part, name) = oneline(unworded(field(p, name)))

"The value in quotes that starts at `v`, without its quotes"
unquote(v::AbstractString) = begin
  startswith(v, '"') || return String(v)
  out = IOBuffer()
  escaped = false
  for c in SubString(v, 2)
    if escaped
      print(out, c)
      escaped = false
    elseif c == '\\'
      escaped = true
    elseif c == '"'
      break
    else
      print(out, c)
    end
  end
  String(take!(out))
end

"The bytes that a value like `%E2%82%AC5` stands for"
unpercent(v::AbstractString) = begin
  data = codeunits(v)
  out = UInt8[]
  i = 1
  while i <= length(data)
    if data[i] == UInt8('%') && i + 2 <= length(data) && hexvalue(data[i+1]) != 0xff && hexvalue(data[i+2]) != 0xff
      push!(out, hexvalue(data[i+1]) << 4 | hexvalue(data[i+2]))
      i += 3
    else
      push!(out, data[i])
      i += 1
    end
  end
  out
end

"""
The first word of a header like Content-Type, in lower case, and what follows
it: each `name=value`, with the names in lower case. A value can be in quotes,
in words like =?UTF-8?B?...?=, or in pieces like `name*0*=UTF-8''%E2%82%AC`.
"""
params(value::AbstractString) = begin
  pieces = String[]
  piece = IOBuffer()
  quoted = escaped = false
  for c in value
    if escaped
      escaped = false
    elseif quoted && c == '\\'
      escaped = true
    elseif c == '"'
      quoted = !quoted
    elseif c == ';' && !quoted
      push!(pieces, String(take!(piece)))
      continue
    end
    print(piece, c)
  end
  push!(pieces, String(take!(piece)))
  kind = lowercase(first(split(strip(pieces[1]), r"[\s(]", limit=2)))
  out = Dict{String,String}()
  split_up = Dict{String,Vector{Tuple{Int,Bool,String}}}()   # the pieces of each value that came in pieces
  for p in pieces[2:end]
    eq = findfirst('=', p)
    eq === nothing && continue
    key, v = lowercase(strip(p[1:prevind(p, eq)])), strip(p[nextind(p, eq):end])
    m = match(r"^([^*]+)\*(\d+)?(\*)?$", key)
    if m === nothing
      haskey(out, key) || (out[key] = unworded(unquote(v)))
    else
      push!(get!(() -> Tuple{Int,Bool,String}[], split_up, m[1]), (m[2] === nothing ? 0 : parse(Int, m[2]), m[3] !== nothing || m[2] === nothing, unquote(v)))
    end
  end
  for (key, found) in split_up
    sort!(found, by=first)
    charset, bytes = "", UInt8[]
    for (k, (_, coded, v)) in enumerate(found)
      if coded && k == 1 && count(==('\''), v) >= 2
        charset, _, v = split(v, '\'', limit=3)
      end
      append!(bytes, coded ? unpercent(v) : codeunits(v))
    end
    out[key] = decode(bytes, charset)
  end
  (String(kind), out)
end

# --- the parts of an email --------------------------------------------------------

const DEEPEST = 40   # parts in parts. An email with more is read as text from there down.

"The part in bytes `lo` to `hi` of `raw`. `usual` is its type when it names none."
part(raw, lo, hi, usual, depth) = begin
  hs, at = headers(raw, lo, hi)
  kind, ps = params(field(hs, "content-type"))
  occursin('/', kind) || ((kind, ps) = (usual, isempty(kind) ? ps : Dict{String,String}()))
  way, named = params(field(hs, "content-disposition"))
  name = get(named, "filename", get(ps, "name", ""))
  id = String(strip(field(hs, "content-id"), ['<', '>', ' ', '\t']))
  if startswith(kind, "multipart/")
    kids = haskey(ps, "boundary") && depth < DEEPEST ?
      pieces(raw, at, hi, ps["boundary"], kind == "multipart/digest" ? "message/rfc822" : "text/plain", depth) : nothing
    kids === nothing || return Part(kind, ps, hs, name, id, way == "inline", UInt8[], kids)
    kind = "text/plain"   # nothing divides it into parts, so it reads as text
  end
  coding = lowercase(strip(field(hs, "content-transfer-encoding")))
  data = @view raw[at:hi]
  body = startswith(coding, "base64") ? unbase64(data) : startswith(coding, "quoted-printable") ? unquoted(data) : Vector{UInt8}(data)
  Part(kind, ps, hs, name, id, way == "inline", body, Part[])
end

"""
The parts between the lines `--boundary`, from byte `at` on. It's nothing when
no such line is there. Without the line that closes the last part, that part
goes on to the end.
"""
pieces(raw, at, hi, boundary, usual, depth) = begin
  mark = codeunits("--" * boundary)
  out = Part[]
  start, i = 0, at
  while i <= hi
    stop, next = lineend(raw, i, hi)
    n = stop - i + 1
    if n >= length(mark) && view(raw, i:i+length(mark)-1) == mark
      rest = String(raw[i+length(mark):stop])
      if isempty(strip(rest)) || startswith(rest, "--")
        # The line break before the line belongs to the line
        last = i - 1
        last >= max(start, at) && raw[last] == LF && (last -= 1)
        last >= max(start, at) && raw[last] == CR && (last -= 1)
        start > 0 && push!(out, part(raw, start, last, usual, depth + 1))
        start = next
        startswith(rest, "--") && return out
      end
    end
    i = next
  end
  start == 0 && return nothing
  start <= hi && push!(out, part(raw, start, hi, usual, depth + 1))
  out
end

"Read a whole email. A broken email is read as well as it can be."
message(raw::AbstractVector{UInt8}) = begin
  bytes = raw isa Vector{UInt8} ? raw : Vector{UInt8}(raw)
  part(bytes, 1, length(bytes), "text/plain", 0)
end
message(raw::AbstractString) = message(Vector{UInt8}(codeunits(raw)))

"The body of a part of text, as text, by the character set that the part names"
text(p::Part) = begin
  charset = get(p.params, "charset", "")
  if isempty(charset) && p.type == "text/html"
    # A page of HTML can name its own character set
    m = match(r"<meta[^>]+charset\s*=\s*[\"']?([\w.:-]+)"i, latin(@view p.body[1:min(end, 2048)]))
    m === nothing || (charset = m[1])
  end
  String(chopprefix(decode(p.body, charset), "\ufeff"))
end

# --- addresses and dates ----------------------------------------------------------

"""
The people in a header like To: each one's name, or \"\", and address.
`addresses("Sam Lee <sam@x.com>, b@y.com")` gives `["Sam Lee" => "sam@x.com", "" => "b@y.com"]`.
A name in quotes can hold a comma. The people of a group, like `Team: a@x.com, b@y.com;`, are
given without the group's name. `addresses(p, "to")` reads a header of `p`: use it rather than
`addresses(header(p, "to"))`, since a name in words like =?UTF-8?Q?Lee=2C_Sam?= can hold a comma too.
"""
addresses(value::AbstractString) = begin
  out = Pair{String,String}[]
  name, address, note = IOBuffer(), IOBuffer(), IOBuffer()
  quoted = angle = escaped = false
  depth = 0   # of the brackets of a comment
  write!() = begin
    n, a, c = oneline(unworded(String(take!(name)))), String(strip(String(take!(address)))), oneline(unworded(String(take!(note))))
    if isempty(a)
      # An address with no < > round it. A comment after it is the name: sam@x.com (Sam Lee)
      m = match(r"[^\s<>]+@[^\s<>]+", n)
      m === nothing && return
      a, n = String(m.match), oneline(replace(n, m.match => " ", count=1))
    end
    isempty(n) && (n = c)
    push!(out, (n == a ? "" : n) => a)
  end
  for c in value
    if escaped
      print(depth > 0 ? note : angle ? address : name, c)
      escaped = false
    elseif (quoted || depth > 0) && c == '\\'
      escaped = true
    elseif quoted
      c == '"' ? (quoted = false) : print(angle ? address : name, c)
    elseif depth > 0
      c == '(' ? (depth += 1) : c == ')' ? (depth -= 1) : nothing
      depth > 0 && print(note, c)
    elseif c == '"'
      quoted = true
    elseif c == '('
      depth = 1
    elseif c == '<'
      angle = true
    elseif c == '>'
      angle = false
    elseif c == ',' || c == ';'
      write!()
      angle = false
    elseif c == ':' && !angle
      take!(name)   # the name of a group, or the mailto: of a link
    else
      print(angle ? address : name, c)
    end
  end
  write!()
  out
end
addresses(p::Part, name) = addresses(field(p, name))

isplain(s) = all(c -> ' ' <= c <= '~', s)

"A name and an address as a header writes them: `Sam Lee <sam@x.com>`. With `worded`, a name that isn't ASCII is in words like =?UTF-8?B?...?=."
mailbox(name, address; worded=false) = begin
  isempty(name) && return String(address)
  shown = worded && !isplain(name) ? words(name) :
          occursin(r"[,;:<>@()\[\]\\\"]", name) ? "\"" * replace(name, '\\' => "\\\\", '"' => "\\\"") * "\"" : name
  "$shown <$address>"
end

"The people of a header as text, like `Sam Lee <sam@x.com>, b@y.com`"
listed(people; worded=false) = join((mailbox(n, a; worded) for (n, a) in people), ", ")

const MONTHS = ("jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec")
const ZONES = Dict("est" => -500, "edt" => -400, "cst" => -600, "cdt" => -500, "mst" => -700, "mdt" => -600, "pst" => -800, "pdt" => -700)
const DATE = r"(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\.?,?\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(?:([+-]\d{4})|([A-Za-z]+))?"

"The time that a Date header gives, like `Sat, 14 Nov 2026 09:32:00 +1100`, in Unix seconds, or nothing"
moment(value::AbstractString) = begin
  m = match(DATE, replace(value, r"\([^()]*\)" => " "))
  m === nothing && return nothing
  month = findfirst(==(lowercase(m[2])), MONTHS)
  month === nothing && return nothing
  year = parse(Int, m[3])
  length(m[3]) == 2 && (year += year < 50 ? 2000 : 1900)
  length(m[3]) == 3 && (year += 1900)
  # A zone by a name that isn't known, like GMT or UT, is no hours from UTC
  zone = m[7] !== nothing ? parse(Int, m[7]) : get(ZONES, lowercase(something(m[8], "")), 0)
  offset = sign(zone) * (abs(zone) ÷ 100 * 3600 + abs(zone) % 100 * 60)
  second = m[6] === nothing ? 0 : min(parse(Int, m[6]), 59)
  try
    Dates.datetime2unix(DateTime(year, month, parse(Int, m[1]), parse(Int, m[4]), parse(Int, m[5]), second)) - offset
  catch
    nothing
  end
end

"When the email was sent, by its Date header, in Unix seconds. It's nothing when the email has no date that reads."
sent(p::Part) = moment(header(p, "date"))

"A time as a page shows it, in this Mac's time zone: `14 Nov 2026, 9:32 am`"
stamp(seconds::Real) = replace(Libc.strftime("%-d %b %Y, %-I:%M %p", seconds), "AM" => "am", "PM" => "pm")

# --- HTML as Markdown -------------------------------------------------------------
#
# The HTML of an email is read as a row of tags and text, and written as lines
# of Markdown. Ladder shows each line of a file as a line of its own, so a
# paragraph is one line, and an empty line is between two blocks. Most tables
# in email only put things beside each other, so a table becomes its cells, one
# after another. A table with headings becomes a Markdown table.
#
# No picture on the web loads by itself: one with words for those who can't
# see it becomes a link with those words, and one without is left out. So a
# picture that tells the sender you opened the email never loads.

"A run of text of a line, and how it's drawn"
struct Seg
  text::String
  bold::Bool
  italic::Bool
  strike::Bool
  code::Bool
  href::String   # where it goes when it's the text of a link
  alt::Bool      # the words that stand for a picture on the web, which the page doesn't show
end

"A tag that's open"
mutable struct Open
  name::String
  href::String     # of a link
  bold::Bool
  italic::Bool
  marker::String   # what the first line of a list item starts with: "- " or "3. "
  used::Bool       # a line of the list item has been written
  count::Int       # the number of the next item of a numbered list
  tight::Bool      # a paragraph that Outlook wrote for one line: no empty line goes round it
  cells::Vector{Int}   # of a row of a table: how many lines were written when the row started, and when each of its cells did
end

Open(name, href, bold, italic, marker, used, count, tight) = Open(name, href, bold, italic, marker, used, count, tight, Int[])

"What writes the lines of Markdown"
mutable struct Writer
  lines::Vector{String}
  segs::Vector{Seg}                # the line that's being written
  open::Vector{Open}
  gap::Bool                        # an empty line goes before the next line
  nbsp::Bool                       # the line so far holds only a space that doesn't break
  depth::Int                       # how many quotes the last line was in
  pre::Union{Nothing,IOBuffer}     # the text of a block of code that's open
  picture::Function                # the path of the picture that the email holds under a name, or nothing
  alts::Bool                       # a line that holds only the words of pictures on the web is written, and not left out
end

Writer(picture, alts=false) = Writer(String[], Seg[], Open[], false, false, 0, nothing, picture, alts)

const VOID = Set(["area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"])
# What's in these isn't the text of an email
const SKIPPED = Set(["head", "noscript", "template", "svg", "math", "select", "object", "audio", "video", "canvas", "map", "datalist", RAW...])
# A line ends before and after each of these
const LINES = Set(["div", "section", "article", "header", "footer", "main", "aside", "nav", "center", "form", "fieldset", "figure",
                   "figcaption", "address", "dl", "dt", "dd", "tbody", "thead", "tfoot", "caption", "details", "summary", "tr", "li"])
# ... and an empty line goes before and after each of these
const BLOCKS = Set(["p", "ul", "ol", "blockquote", "pre", "table", "h1", "h2", "h3", "h4", "h5", "h6"])
# A paragraph that's open ends where a block starts, unless the paragraph is outside one of these
const HOLDERS = ("div", "td", "th", "li", "blockquote", "table", "ul", "ol", "center", "section", "article")
const GONE = r"[\u200b\u200c\ufeff\u00ad\u2060\u034f]"   # characters that show nothing. Senders pad the first line of an email with them.
const HIDDEN = r"display\s*:\s*none|visibility\s*:\s*hidden|mso-hide\s*:\s*all"

level(name) = length(name) == 2 && name[1] == 'h' && '1' <= name[2] <= '6' ? name[2] - '0' : 0

"True when the tag's own style keeps what's in it from showing, like the first line that a sender writes for the list of emails"
hidden(t::Token) = begin
  haskey(t.attrs, "hidden") && return true
  occursin("preheader", lowercase(get(t.attrs, "class", ""))) && return true
  style = lowercase(get(t.attrs, "style", ""))
  isempty(style) && return false
  occursin(HIDDEN, style) || (occursin(r"max-height\s*:\s*0(px)?\s*(;|$)", style) && occursin(r"overflow\s*:\s*hidden", style))
end

"The tag that closes the tag at `i`, or 0"
matching(toks, i) = begin
  name, depth = toks[i].name, 1
  for j in i+1:length(toks)
    toks[j].name == name || continue
    depth += toks[j].kind == :open ? !toks[j].closed : toks[j].kind == :close ? -1 : 0
    depth == 0 && return j
  end
  0
end

inlist(w::Writer) = any(o -> o.name == "ul" || o.name == "ol", w.open)

"Ask for an empty line before the next line. The items of a list have none between them."
gap!(w::Writer) = (inlist(w) || (w.gap = true); nothing)

"Write a line, after what the quotes and the list items that it's in start a line with"
line!(w::Writer, body) = begin
  io, depth = IOBuffer(), 0
  for o in w.open
    if o.name == "blockquote"
      print(io, "> ")
      depth += 1
    elseif o.name == "li"
      print(io, o.used ? " "^length(o.marker) : o.marker)
      o.used = true
    end
  end
  w.gap && !isempty(w.lines) && push!(w.lines, rstrip("> "^min(depth, w.depth)))
  w.gap, w.depth = false, depth
  push!(w.lines, rstrip(String(take!(io)) * body))
  nothing
end

same(a::Seg, b::Seg) = a.bold == b.bold && a.italic == b.italic && a.strike == b.strike && a.code == b.code

"The Markdown of runs of text that are all in one link, or in none. The text of a heading is bold already."
styled(segs, heading) = begin
  out = IOBuffer()
  i = 1
  while i <= length(segs)
    s, j = segs[i], i
    text = s.text
    while j < length(segs) && same(segs[j+1], s)
      j += 1
      text *= segs[j].text
    end
    core = strip(text)
    mark = s.code ? "`" : (s.bold && !heading ? "**" : "") * (s.italic ? "*" : "")
    front, back = mark, reverse(mark)
    s.strike && !s.code && ((front, back) = ("~~" * front, back * "~~"))
    # The spaces round the text go outside the marks, or the marks don't read
    isempty(core) || isempty(front) ? print(out, text) :
      print(out, startswith(text, ' ') ? " " : "", front, core, back, endswith(text, ' ') ? " " : "")
    i = j + 1
  end
  String(take!(out))
end

"The Markdown of the runs of text of a line"
render(segs, heading) = begin
  out = IOBuffer()
  i = 1
  while i <= length(segs)
    j = i
    while j < length(segs) && segs[j+1].href == segs[i].href
      j += 1
    end
    inner = styled(view(segs, i:j), heading)
    label = strip(inner)
    if isempty(segs[i].href)
      print(out, inner)
    elseif isempty(label)
      print(out, isempty(inner) ? "" : " ")
    else
      # A ] in the text would end the text early
      print(out, startswith(inner, ' ') ? " " : "", "[", replace(label, '[' => '(', ']' => ')'), "](", segs[i].href, ")",
            endswith(inner, ' ') ? " " : "")
    end
    i = j + 1
  end
  String(take!(out))
end

"End the line that's being written"
flush!(w::Writer) = begin
  segs, nbsp = w.segs, w.nbsp
  isempty(segs) && !nbsp && return
  w.segs, w.nbsp = Seg[], false
  if any(s -> s.alt, segs)
    # A line that holds only the words of pictures on the web, like a logo or a drawing, is left out
    !w.alts && all(s -> s.alt || isempty(strip(s.text)), segs) && return
    # ... and so are a picture's words beside the same words as text, like the sign of a card beside its name
    said = Set(lowercase(strip(s.text)) for s in segs if !s.alt)
    segs = filter(s -> !(s.alt && lowercase(strip(s.text)) in said), segs)
  end
  k = findlast(o -> level(o.name) > 0, w.open)
  body = strip(render(segs, k !== nothing))
  # A line with only a space that doesn't break is how many senders write an empty line
  isempty(body) && return nbsp ? gap!(w) : nothing
  if k !== nothing
    body = "#"^level(w.open[k].name) * " " * body
  elseif startswith(body, "```") || startswith(body, "~~~")
    body = "\u200b" * body   # or the rest of the page would read as code
  end
  line!(w, body)
end

"End the line, and ask for an empty line before the next"
block!(w::Writer) = (flush!(w); gap!(w))

"Add text to the line. Each run of white space is one space."
say!(w::Writer, text; alt=false) = begin
  w.pre === nothing || return (print(w.pre, text); nothing)
  t = replace(replace(text, GONE => ""), r"[\s\u00a0\u2007\u202f]+" => " ")
  (isempty(w.segs) || endswith(w.segs[end].text, ' ')) && (t = lstrip(t))
  if isempty(t)
    isempty(w.segs) && occursin('\u00a0', text) && (w.nbsp = true)
    return
  end
  bold = italic = strike = code = false
  href = ""
  for o in w.open
    bold |= o.bold
    italic |= o.italic
    strike |= o.name in ("del", "s", "strike")
    code |= o.name in ("code", "tt", "kbd", "samp")
    o.name == "a" && (href = o.href)
  end
  push!(w.segs, Seg(t, bold, italic, strike, code, href, alt))
  nothing
end

"A path or an address as a link writes it. A space or a bracket would end the link early."
escaped(path) = replace(path, ' ' => "%20", '(' => "%28", ')' => "%29")

"Where a link goes, as Markdown writes it, or \"\" for a link that goes nowhere"
target(href) = begin
  href = replace(strip(href), r"[\r\n\t]" => "")
  (isempty(href) || startswith(href, '#') || startswith(lowercase(href), "javascript:")) && return ""
  escaped(replace(href, r"\s" => " ", '<' => "%3C", '>' => "%3E"))
end

"The size that a tag gives its picture in `name`, as a number of pixels, or nothing"
pixels(t::Token, name) = begin
  m = match(r"^\s*(\d+)", get(t.attrs, name, ""))
  m === nothing && (m = match(Regex("(?:^|;)\\s*$name\\s*:\\s*(\\d+)px"), lowercase(get(t.attrs, "style", ""))))
  m === nothing ? nothing : parse(Int, m[1])
end

"""
A picture. One that the email holds goes on a line of its own. One on the web
isn't shown: Ladder gets nothing from the web for an email, so that a sender
can't tell when you read it. In a line of text, such a picture becomes the
words that it has for those who can't see it. In a link, those words are the
link's text. A line with nothing but such pictures is left out.
"""
picture!(w::Writer, t::Token) = begin
  src = strip(get(t.attrs, "src", ""))
  alt = oneline(replace(get(t.attrs, "alt", ""), GONE => ""))
  if startswith(lowercase(src), "cid:")
    path = w.picture(String(src[5:end]))
    path === nothing && return
    flush!(w)
    isempty(alt) && (alt = splitext(basename(path))[1])
    return line!(w, "![$(replace(alt, '[' => '(', ']' => ')'))]($(escaped(path)))")
  end
  isempty(alt) && return
  # A picture a pixel or two wide is there to tell the sender that the email was opened
  any(n -> something(pixels(t, n), 100) <= 2, ("width", "height")) && return
  # In a link, the words go to where the link goes
  any(o -> o.name == "a" && !isempty(o.href), w.open) ? say!(w, alt) : occursin(r"^https?://"i, src) ? say!(w, alt, alt=true) : nothing
  nothing
end

"End a tag that's open and is one of `names`, when a tag starts that can't be in it. A tag in `outside` keeps it open."
implied!(w::Writer, names, outside) = begin
  for k in length(w.open):-1:1
    w.open[k].name in outside && return
    w.open[k].name in names && return shut!(w, k)
  end
end

"End the paragraph that's open, when a tag starts that can't be in a paragraph. An empty line goes after it."
endparagraph!(w::Writer) = begin
  for k in length(w.open):-1:1
    o = w.open[k]
    o.name in HOLDERS && return
    o.name == "p" || continue
    flush!(w)
    shut!(w, k)
    return o.tight ? nothing : gap!(w)
  end
end

"Take the tag at place `k` of the open tags away, and each tag that's open in it"
shut!(w::Writer, k) = begin
  resize!(w.open, k - 1)
  w.pre !== nothing && !any(o -> o.name == "pre", w.open) && code!(w)
  nothing
end

"Write the block of code that just closed"
code!(w::Writer) = begin
  text = String(take!(w.pre))
  w.pre = nothing
  lines = split(replace(text, "\r\n" => "\n", '\r' => '\n'), '\n')
  while !isempty(lines) && isempty(strip(lines[1])); popfirst!(lines) end
  while !isempty(lines) && isempty(strip(lines[end])); pop!(lines) end
  isempty(lines) && return
  gap!(w)
  line!(w, "```")
  foreach(l -> line!(w, replace(rstrip(l), "```" => "'''")), lines)
  line!(w, "```")
  gap!(w)
end

"""
The rows of the table that starts at `i`, each a list of the Markdown of its
cells, and the tag that closes the table. It's nothing for a table that only
puts things beside each other: one with no headings, or with a table in it.
"""
datatable(w::Writer, toks, i) = begin
  stop = matching(toks, i)
  stop == 0 && return nothing
  inner = i+1:stop-1
  any(k -> toks[k].kind == :open && toks[k].name == "th", inner) || return nothing
  any(k -> toks[k].kind == :open && toks[k].name == "table", inner) && return nothing
  rows = Vector{Vector{Token}}[]
  cell = nothing
  for k in inner
    t = toks[k]
    if t.kind == :open && t.name == "tr"
      push!(rows, Vector{Token}[])
      cell = nothing
    elseif t.kind == :open && t.name in ("td", "th")
      isempty(rows) && push!(rows, Vector{Token}[])
      cell = Token[]
      push!(rows[end], cell)
    elseif t.kind == :close && t.name in ("td", "th", "tr")
      cell = nothing
    elseif cell !== nothing
      push!(cell, t)
    end
  end
  texts = [String[replace(join(filter(!isempty, written(c, w.picture)), " "), "|" => "\\|") for c in row] for row in rows if !isempty(row)]
  wide = maximum(length, texts, init=0)
  (length(texts) < 2 || wide < 2) && return nothing
  (stop, [vcat(row, fill("", wide - length(row))) for row in texts])
end

"Take the tag at `i`, which opens. It gives the last tag that it took: itself, or the end of something that's left out or written whole."
open!(w::Writer, toks, i) = begin
  t = toks[i]
  name = t.name
  if name in SKIPPED || hidden(t)
    (name in VOID || (t.closed && name in RAW)) && return i
    j = matching(toks, i)
    return j == 0 ? i : j
  end
  if name == "br"
    w.pre === nothing ? (isempty(w.segs) ? gap!(w) : flush!(w)) : print(w.pre, '\n')
  elseif w.pre !== nothing
    name in ("p", "div", "li", "tr") && print(w.pre, '\n')
    name in VOID || push!(w.open, Open(name, "", false, false, "", false, 0, false))
  elseif name == "hr"
    block!(w)
    line!(w, "---")
    gap!(w)
  elseif name == "img"
    picture!(w, t)
  elseif !(name in VOID || (t.closed && occursin(':', name)))
    if name == "table"
      found = datatable(w, toks, i)
      if found !== nothing
        stop, rows = found
        block!(w)
        for (k, row) in enumerate(rows)
          line!(w, "| " * join(row, " | ") * " |")
          k == 1 && line!(w, "| " * join(fill("---", length(row)), " | ") * " |")
        end
        gap!(w)
        return stop
      end
    end
    o = Open(name, "", false, false, "", false, 1, false)
    style = lowercase(get(t.attrs, "style", ""))
    (name in LINES || name in BLOCKS) && endparagraph!(w)
    if name == "p"
      o.tight = occursin("MsoNormal", get(t.attrs, "class", ""))
      o.tight ? flush!(w) : block!(w)
    elseif name == "li"
      flush!(w)
      implied!(w, ("li",), ("ul", "ol"))
      k = findlast(l -> l.name == "ul" || l.name == "ol", w.open)
      o.marker = k === nothing || w.open[k].name == "ul" ? "- " : "$((w.open[k].count += 1) - 1). "
    elseif name == "td" || name == "th"
      implied!(w, ("td", "th"), ("table",))
      # Each cell starts a line. The end of the row puts short cells on one line: see `joinrow!`.
      flush!(w)
      k = findlast(x -> x.name == "tr" || x.name == "table", w.open)
      k !== nothing && w.open[k].name == "tr" && push!(w.open[k].cells, length(w.lines))
    elseif name == "tr"
      flush!(w)
      endrow!(w)   # a row that was never closed ends where the next starts
      implied!(w, ("tr",), ("table",))
      push!(o.cells, length(w.lines))
    elseif name in BLOCKS
      block!(w)
      name == "ol" && (o.count = something(tryparse(Int, get(t.attrs, "start", "")), 1))
    elseif name in LINES
      flush!(w)
    elseif name == "a"
      o.href = target(get(t.attrs, "href", ""))
    elseif name == "q"
      say!(w, "“")
    end
    o.bold = name in ("b", "strong") || (name in ("span", "font") && occursin(r"font-weight\s*:\s*(bold|[6-9]00)", style))
    o.italic = name in ("i", "em", "cite", "var") || (name in ("span", "font") && occursin(r"font-style\s*:\s*italic", style))
    push!(w.open, o)
    name == "pre" && (w.pre = IOBuffer())
  end
  i
end

"A line that's plain text and short: no heading, list, quote, table, picture, rule or code"
short(text) = length(replace(text, r"\]\([^)]*\)" => "]")) <= 70 && !occursin(r"^(#|[-*+] |>|\||```|~~~|!\[|\d+[.)] |([-*_])(\s*\2){2,}\s*$)", text)

"""
Put the cells of the table row that just ended on one line, when each cell is
a few short lines of text. Most tables in email only put things beside each
other, and a row like this is a line of an invoice or a row of links: what's
bought and its price, or Privacy and Terms. A — goes between two cells, and a
· between more. The lines of one cell have a comma between them.
"""
joinrow!(w::Writer, row::Open) = begin
  marks = row.cells
  (length(marks) >= 3 && marks[1] <= length(w.lines)) || return
  any(o -> o.name in ("blockquote", "li", "ul", "ol"), w.open) && return
  ends = [marks[2:end]; length(w.lines)]
  issorted(ends) || return
  cells = [filter!(!isempty, String.(strip.(w.lines[ends[i]+1:ends[i+1]]))) for i in 1:length(ends)-1]
  filter!(!isempty, cells)
  (length(cells) >= 2 && all(c -> length(c) <= 3 && all(short, c), cells)) || return
  spaced = marks[1] < length(w.lines) && isempty(w.lines[marks[1]+1])
  add(text) = (spaced && !isempty(w.lines) && push!(w.lines, ""); push!(w.lines, text))
  if cells[1] == ["•"] || cells[1] == ["·"] || cells[1] == ["-"] || cells[1] == ["*"]
    # A dot in a cell of its own, then the words: an item of a list
    resize!(w.lines, marks[1])
    add("- " * join((join(c, ", ") for c in cells[2:end]), " "))
  elseif all(c -> length(c) == 2, cells)
    # Each cell is a name over what it's set to, like Amount paid over the amount: a line for each
    resize!(w.lines, marks[1])
    for (i, c) in enumerate(cells)
      (i > 1 || spaced) && !isempty(w.lines) && push!(w.lines, "")
      push!(w.lines, c[1] * " — " * c[2])
    end
  elseif sum(c -> sum(l -> length(replace(l, r"\]\([^)]*\)" => "]")), c), cells) <= 140
    resize!(w.lines, marks[1])
    add(join((join(c, ", ") for c in cells), length(cells) == 2 ? " — " : " · "))
  end
  nothing
end

"Join the cells of the row that's open in the table that's open, or in the tag at place `from` of the open tags"
endrow!(w::Writer, from=something(findlast(o -> o.name == "table", w.open), 1)) = begin
  k = findlast(o -> o.name == "tr", w.open)
  k !== nothing && k >= from && joinrow!(w, w.open[k])
  nothing
end

"""
Put a short line that ends with a colon and the short line after it on one
line, like `Order ID:` and its number. Senders often write the two in boxes of
their own.
"""
joinlabels!(lines) = begin
  i = 1
  while i + 2 <= length(lines)
    a, b = lines[i], lines[i+2]
    if endswith(a, ':') && length(a) <= 40 && short(a) && isempty(lines[i+1]) && !isempty(b) && short(b) && !endswith(b, ':') &&
       (i == 1 || isempty(lines[i-1])) && (i + 3 > length(lines) || isempty(lines[i+3]))
      lines[i] = a * " " * b
      deleteat!(lines, i+1:i+2)
    end
    i += 1
  end
  lines
end

"Take a tag that closes"
close!(w::Writer, name) = begin
  name == "br" && return w.pre === nothing ? (isempty(w.segs) ? gap!(w) : flush!(w)) : print(w.pre, '\n')
  k = findlast(o -> o.name == name, w.open)
  if k === nothing
    name == "p" && w.pre === nothing && block!(w)   # a </p> alone is the end of a paragraph
    return
  end
  name == "q" && say!(w, "”")
  # The line ends while it's still in the tag, so it starts with what the tag gives it
  w.pre === nothing && any(o -> o.name in LINES || o.name in BLOCKS, @view w.open[k:end]) && flush!(w)
  # A paragraph that's open in the tag ends with it
  gap = any(o -> o.name in BLOCKS && !o.tight, @view w.open[k:end])
  name == "tr" && w.pre === nothing && joinrow!(w, w.open[k])
  name in ("table", "tbody", "thead", "tfoot") && w.pre === nothing && endrow!(w, k)
  shut!(w, k)
  gap && gap!(w)
  nothing
end

"The lines of Markdown of tags and text"
written(toks, picture; alts=false) = begin
  w = Writer(picture, alts)
  i = 1
  while i <= length(toks)
    t = toks[i]
    t.kind == :text ? say!(w, t.text) : t.kind == :open ? (i = open!(w, toks, i)) : t.kind == :close ? close!(w, t.name) : nothing
    i += 1
  end
  flush!(w)
  w.pre === nothing || code!(w)
  out = w.lines
  # A rule at the very top of a file would read as the start of front matter
  while !isempty(out) && (isempty(strip(out[1])) || occursin(r"^\s*([-*_])(\s*\1){2,}\s*$", out[1])); popfirst!(out) end
  while !isempty(out) && isempty(strip(out[end])); pop!(out) end
  joinlabels!(out)
end

"""
HTML as Markdown. Whatever the HTML holds, this gives text. `picture(name)`
gives the path of the picture that an email holds under `name`, for
`<img src="cid:name">`, or nothing when there's no such picture.
"""
markdown(html::AbstractString; picture=name -> nothing) = begin
  source = String(html)
  isvalid(source) || (source = utf8(codeunits(source)))
  # What `picture` throws, like a disk that's full, isn't the HTML's fault, so it goes on to the caller
  failed = Ref{Any}(nothing)
  safe(name) = try picture(name) catch err; failed[] = err; nothing end
  lines = try
    toks = tokens(source)
    made = written(toks, safe)
    # An email that's all pictures on the web has their words, at least
    isempty(made) ? written(toks, safe, alts=true) : made
  catch
    String[oneline(l) for l in split(entities(replace(source, r"<[^>]*>" => " ")), '\n') if !isempty(strip(l))]
  end
  failed[] === nothing || throw(failed[])
  join(lines, "\n")
end

# --- the page of an email ---------------------------------------------------------

const PICTURES = ("png", "jpg", "jpeg", "gif", "webp", "heic")
# The end of the name that a file of each type gets when the email gives it no name, and the type of a file by the end of its name
const ENDINGS = ("application/pdf" => "pdf", "image/png" => "png", "image/jpeg" => "jpg", "image/gif" => "gif", "text/plain" => "txt",
                 "text/markdown" => "md", "text/csv" => "csv", "application/zip" => "zip",
                 "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "docx",
                 "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "xlsx",
                 "image/webp" => "webp", "image/heic" => "heic", "text/html" => "html", "text/calendar" => "ics", "message/rfc822" => "eml")
# A signature isn't a file that someone attached
const SIGNATURES = ("application/pgp-signature", "application/pkcs7-signature", "application/x-pkcs7-signature")

ending(name) = lowercase(lstrip(splitext(name)[2], '.'))
ispicture(name) = ending(name) in PICTURES

"The first word of the part's Content-Disposition: \"attachment\", \"inline\" or \"\""
disposition(p::Part) = first(params(field(p, "content-disposition")))

"True when the part is text of the email itself, not a file that's attached"
isbody(p::Part) = p.type in ("text/plain", "text/html") && disposition(p) != "attachment"

"The texts of an email, in their order, and its files"
struct Found
  texts::Vector{Part}
  files::Vector{Part}
end
Found() = Found(Part[], Part[])

gather!(found::Found, p::Part) = begin
  if p.type == "multipart/alternative"
    # The parts say the same thing in several ways. The one with HTML has the most, or else the last that has text.
    options = [gather!(Found(), kid) for kid in p.parts]
    pick = something(findlast(o -> any(t -> t.type == "text/html", o.texts), options), findlast(o -> !isempty(o.texts), options), 0)
    pick > 0 && append!(found.texts, options[pick].texts)
    foreach(o -> append!(found.files, o.files), options)
  elseif !isempty(p.parts)
    foreach(kid -> gather!(found, kid), p.parts)
  elseif isbody(p)
    push!(found.texts, p)
  elseif !(p.type in SIGNATURES) && !startswith(p.type, "multipart/") && !isempty(p.body)
    push!(found.files, p)
  end
  found
end

"""
The name of the file of a part, as a file on the Mac can have it and a link can
write it. A part with no name gets one from its type, like "attachment.pdf".
"""
filename(p::Part) = begin
  name = replace(p.name, r"[/\\:<>]|[\x00-\x1f\x7f]" => "-", r"\s" => " ", r"%(?=2[089])" => "-")
  name = String(strip(lstrip(strip(name), '.')))
  known = findfirst(e -> first(e) == p.type, ENDINGS)
  isempty(name) && (name = p.type == "message/rfc822" ? "message" : "attachment")
  # A picture shows on the page only when the end of its name says what it is
  isempty(ending(name)) && known !== nothing && (name *= "." * last(ENDINGS[known]))
  name
end

"Plain text that was sent as lines to be joined: a line that ends with a space goes on in the next line"
unflowed(text, delsp) = begin
  out = String[]
  open, last = false, -1
  for line in split(text, '\n')
    depth = something(findfirst(!=('>'), line), lastindex(line) + 1) - 1
    rest = SubString(line, depth + 1)
    startswith(rest, ' ') && (rest = SubString(rest, 2))
    flows = endswith(rest, ' ') && rest != "-- "
    piece = flows && delsp ? chop(rest) : rest
    open && depth == last && !isempty(out) ? (out[end] *= piece) : push!(out, (depth > 0 ? ">"^depth * " " : "") * piece)
    open, last = flows, depth
  end
  out
end

"The lines of plain text as a page holds them: no spaces at the end of a line, and no more than one empty line in a row"
plain(text::AbstractString; flowed=false, delsp=false) = begin
  text = replace(text, "\r\n" => "\n", '\r' => '\n')
  out = String[]
  for line in (flowed ? unflowed(text, delsp) : split(text, '\n'))
    line = rstrip(line)
    isempty(line) && (isempty(out) || isempty(out[end])) && continue
    push!(out, line)
  end
  while !isempty(out) && isempty(out[end]); pop!(out) end
  # A line that opens a block of code with none that closes it would make code of the rest of the page
  fences = findall(l -> occursin(r"^\s*(```|~~~)", l), out)
  isodd(length(fences)) && (out[fences[end]] = "\u200b" * out[fences[end]])
  out
end

"""
The lines of the Markdown page of an email: front matter with who it's from,
who it's to, when it was sent and its subject, then its text, then a line for
each file that's attached.

`keep(name, bytes, picture)` is called for each attachment, and for each picture
that the text shows. `name` is the file's name: no two files of one email get
the same name, and none has a character that a file's name can't have.
`picture` is true for a picture that a page can show. `keep` saves the file
and gives the path for the page to link to, or gives nothing to leave the file
out. `at` is the time to show, in Unix seconds, for an email with no date of its own.
"""
page(p::Part; keep=(name, bytes, picture) -> nothing, at=nothing) = begin
  # The people of a header, or the header's own words when no address is in them
  people(name) = (found = addresses(p, name); isempty(found) ? header(p, name) : listed(found))
  lines = String["---", rstrip("from: " * people("from"))]
  row(key, value) = isempty(value) || push!(lines, "$key: $value")
  row("to", people("to"))
  row("cc", people("cc"))
  when = something(sent(p), at, Some(nothing))
  when === nothing || row("date", stamp(when))
  push!(lines, rstrip("subject: " * header(p, "subject")), "---", "")

  found = gather!(Found(), p)
  names = Set{String}()
  # A name for the file of `f` that no other file of this email has
  fresh(f) = begin
    name = filename(f)
    stem, ext = splitext(name)
    k = 1
    while lowercase(name) in names
      name = "$stem $(k += 1)$ext"
    end
    push!(names, lowercase(name))
    name
  end
  saved = IdDict{Part,Any}()   # the path and the name of each file that `keep` was asked about, or nothing
  save(f) = get!(saved, f) do
    name = fresh(f)
    path = keep(name, f.body, ispicture(name))
    path === nothing ? nothing : (String(path), name)
  end
  shown = IdDict{Part,Bool}()   # the pictures that the text shows where the sender put them
  cids = Dict(lowercase(f.id) => f for f in reverse(found.files) if !isempty(f.id))
  picture(name) = begin
    f = get(cids, lowercase(strip(name, ['<', '>', ' '])), nothing)
    (f === nothing || !ispicture(filename(f))) && return nothing
    kept = save(f)
    kept === nothing && return nothing
    shown[f] = true
    kept[1]
  end
  for t in found.texts
    body = t.type == "text/html" ? split(markdown(text(t); picture), '\n') :
           plain(text(t), flowed=lowercase(get(t.params, "format", "")) == "flowed", delsp=lowercase(get(t.params, "delsp", "")) == "yes")
    while !isempty(body) && isempty(strip(body[1])); popfirst!(body) end
    isempty(body) && continue
    isempty(lines[end]) || push!(lines, "")
    append!(lines, body)
  end
  links = String[]
  for f in found.files
    haskey(shown, f) && continue
    kept = save(f)
    kept === nothing && continue
    path, name = kept
    push!(links, (ispicture(name) ? "!" : "") * "[$(replace(name, '[' => '(', ']' => ')'))]($(escaped(path)))")
  end
  isempty(links) || (isempty(lines[end]) || push!(lines, ""); append!(lines, links))
  while length(lines) > 1 && isempty(lines[end]) && isempty(lines[end-1]); pop!(lines) end
  lines
end

"""
The HTML of an email, as its sender wrote it, for a browser to draw. It's ""
for an email with no HTML. The page needs no other file: each picture that
came inside the email, which the HTML names like `cid:logo`, is written into
the page itself. A picture that the HTML has from a web site keeps its web
address. Text of the email that isn't HTML is in the page as it was typed.
"""
webpage(p::Part) = begin
  found = gather!(Found(), p)
  any(t -> t.type == "text/html", found.texts) || return ""
  cids = Dict(lowercase(f.id) => f for f in reverse(found.files) if !isempty(f.id))
  inside(m) = begin
    f = get(cids, lowercase(String(chopprefix(lowercase(m), "cid:"))), nothing)
    f === nothing ? String(m) : "data:$(f.type);base64,$(base64encode(f.body))"
  end
  typed(s) = "<pre style=\"white-space: pre-wrap; font: inherit\">" * replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;") * "</pre>"
  join((t.type == "text/html" ? replace(text(t), r"(?<=[\"'=(\s])cid:[^\s\"'<>)]+"i => inside) : typed(text(t)) for t in found.texts), "\n")
end

# --- an email to send -------------------------------------------------------------

"`s` in pieces of no more than `most` bytes, none cut in the middle of a character"
chunks(s::AbstractString, most) = begin
  out = String[]
  piece = IOBuffer()
  for c in s
    position(piece) + ncodeunits(c) > most && push!(out, String(take!(piece)))
    print(piece, c)
  end
  position(piece) > 0 && push!(out, String(take!(piece)))
  out
end

"""
Text for a header: as it is when it's ASCII, or as words like =?UTF-8?B?...?=.
Each word is short enough to go on a line after a header's name.
"""
words(s::AbstractString) = isplain(s) ? String(s) : join(("=?UTF-8?B?$(base64encode(c))?=" for c in chunks(s, 42)), " ")

"A header, on as many lines as it needs to keep each one to 78 characters. A line breaks at a space."
fold(name, value) = begin
  lines = String[]
  line = name * ":"
  for word in split(value, ' ', keepempty=false)
    if length(line) + 1 + length(word) > 78 && length(line) > length(name) + 1
      push!(lines, line)
      line = " " * word
    else
      line *= " " * word
    end
  end
  push!(lines, line)
  join(lines, "\r\n")
end

"The people in `value` as a header writes them, with each name that isn't ASCII in words"
mailboxes(value::AbstractString) = (people = addresses(value); isempty(people) ? words(oneline(value)) : listed(people, worded=true))

"""
Text as quoted-printable: each byte that isn't plain ASCII is written as = and
two digits, and no line is longer than 76 characters. It has no line break after its last line.
"""
quotedprintable(text::AbstractString) = begin
  out = IOBuffer()
  lines = split(replace(text, "\r\n" => "\n", '\r' => '\n'), '\n')
  for (k, line) in enumerate(lines)
    bytes = codeunits(line)
    col = 0
    for (i, b) in enumerate(bytes)
      coded = b == UInt8('=') || (b < 0x20 && b != TAB) || b > 0x7e || ((b == SPACE || b == TAB) && i == length(bytes))
      n = coded ? 3 : 1
      col + n > 75 && (print(out, "=\r\n"); col = 0)
      coded ? print(out, '=', uppercase(string(b, base=16, pad=2))) : print(out, Char(b))
      col += n
    end
    k < length(lines) && print(out, "\r\n")
  end
  String(take!(out))
end

"A part of an email: its headers, an empty line and its body"
entity(headers, body) = join(headers, "\r\n") * "\r\n\r\n" * body

"A part of text, in UTF-8"
textpart(kind, text) = entity(["Content-Type: $kind; charset=UTF-8", "Content-Transfer-Encoding: quoted-printable"], quotedprintable(text))

"A part that holds `parts`"
holder(kind, parts) = begin
  boundary = "=_" * string(rand(UInt128), base=36)
  entity(["Content-Type: multipart/$kind;", " boundary=\"$boundary\""],
         join(("--$boundary\r\n$p\r\n" for p in parts)) * "--$boundary--")
end

"The type of a file, by the end of its name"
filetype(path) = begin
  e = ending(path)
  e == "jpeg" && return "image/jpeg"
  k = findfirst(p -> last(p) == e, ENDINGS)
  k === nothing ? "application/octet-stream" : first(ENDINGS[k])
end

"The part that carries the file at `path`"
filepart(path) = begin
  name = basename(path)
  quoted = "\"" * replace(name, '\\' => "\\\\", '"' => "\\\"") * "\""
  # A name that isn't ASCII is written in two ways, since no one way is read by every app
  named = isplain(name) ? "name=$quoted" : "name=\"$(words(name))\""
  filed = isplain(name) ? "filename=$quoted" :
          "filename*=UTF-8''" * join(c in UInt8('a'):UInt8('z') || c in UInt8('A'):UInt8('Z') || c in UInt8('0'):UInt8('9') || c in codeunits("-._") ?
                                     Char(c) : "%" * uppercase(string(c, base=16, pad=2)) for c in codeunits(name))
  coded = base64encode(read(path))
  entity(["Content-Type: $(filetype(path));", " $named", "Content-Transfer-Encoding: base64", "Content-Disposition: attachment;", " $filed"],
         join((SubString(coded, i, min(i + 75, lastindex(coded))) for i in 1:76:lastindex(coded)), "\r\n"))
end

"""
The bytes of an email to send. `from`, `to` and `cc` are people as a header
lists them, like `Sam Lee <sam@x.com>, b@y.com`. `text` is the email as plain
text, and `html` is the same as HTML, or "". `files` are the paths of the files
to attach. `id` is the email's own Message-ID, with its < >. `reply` is the
Message-ID of the email that this one answers, and `references` the
Message-IDs of the emails before that one. `at` is when it's sent, in Unix
seconds. The people in `bcc` get the email from the server and aren't written
in it, so this leaves them out.
"""
compose(; from, to, cc="", bcc="", subject, text, html="", files=String[], reply="", references="", id, at=time()) = begin
  headers = [fold("From", mailboxes(from))]
  isempty(strip(to)) || push!(headers, fold("To", mailboxes(to)))
  isempty(strip(cc)) || push!(headers, fold("Cc", mailboxes(cc)))
  push!(headers, fold("Subject", words(oneline(subject))), "Date: " * Libc.strftime("%a, %d %b %Y %H:%M:%S %z", at), "Message-ID: $id")
  reply = oneline(reply)
  if !isempty(reply)
    before = oneline(references)
    push!(headers, "In-Reply-To: $reply", fold("References", occursin(reply, before) ? before : oneline("$before $reply")))
  end
  push!(headers, "MIME-Version: 1.0")
  body = isempty(html) ? textpart("text/plain", text) : holder("alternative", [textpart("text/plain", text), textpart("text/html", html)])
  isempty(files) || (body = holder("mixed", [body; filepart.(files)]))
  Vector{UInt8}(codeunits(join(headers, "\r\n") * "\r\n" * body * "\r\n"))
end

export Part, message, header, field, addresses, listed, sent, stamp, text, markdown, page, compose
