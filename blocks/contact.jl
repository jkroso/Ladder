# A contact is a card for a person or a company. In a document it's a code
# block in the language `contact`:
#
#     ```contact
#     Ada Lovelace
#     role: Engineer
#     company: Analytical Engines
#     email: ada@example.com
#     mobile: 0400 123 456
#     address: 12 Example St, Sydney NSW 2000
#     web: example.com
#     photo: ada.jpg
#     note: Met at the 2026 conference.
#     ABN: 12 345 678 901
#
#     Analytical Engines
#     kind: company
#     email: hello@example.com
#     ```
#
# A block can hold several contacts. An empty line ends one contact, and the
# next line that isn't empty starts the next one.
#
# The first line of a contact that has no label is its name. Each other line
# is a label, a colon and a value. A label is one to three words, and its
# capitals don't matter. The labels that a contact knows:
#
# - `kind`: `kind: company` says that the contact is a company. Any other
#   value, and no `kind` line, is a person.
# - `role` and `company`: they show under a person's name
# - `email`
# - `phone`, and `mobile`, `work`, `home` and `fax`, which are phone numbers
#   that keep their own word
# - `address`
# - `web`, `website` or `url`
# - `photo`: a picture file, named from the page's folder, or a web address
# - `note`
# - `name`: the name, for a name that would be read as a line with a label
#
# A label can be there more than once: two `email` lines are two emails. Any
# other label, like `ABN`, is a detail that shows its label and its value.
#
# A line with no label, after the name, is read by its shape. One that starts
# with http://, https:// or www. is a web address. One with an @ and no
# spaces is an email address. One with only digits, spaces and + ( ) -, and
# six digits or more, is a phone number. Any other is a note.
#
# This file reads and writes those lines. It draws nothing in a window.
# `vcard` writes a contact as a vCard for the Contacts app, `from_vcard`
# reads the contacts of a vCard file, and `markup` writes a contact as a card
# for a page of HTML.

"The language of a code block that holds contacts"
const CONTACT = "contact"

"The kind of detail that each label is. A label that isn't here is a detail of the kind `:other`."
const KINDS = Dict("name" => :name, "kind" => :kind, "role" => :role, "company" => :company, "email" => :email,
                   "phone" => :phone, "mobile" => :phone, "work" => :phone, "home" => :phone, "fax" => :phone,
                   "address" => :address, "web" => :web, "website" => :web, "url" => :web, "photo" => :photo, "note" => :note)

"The label that a new line of each kind is written with"
const WORDS = Dict(:name => "name", :kind => "kind", :role => "role", :company => "company", :email => "email", :phone => "phone",
                   :address => "address", :web => "web", :photo => "photo", :note => "note")

"A line of a contact: one detail of it"
mutable struct Detail
  kind::Symbol     # :name, :kind, :role, :company, :email, :phone, :address, :web, :photo, :note or :other
  label::String    # the label as the line has it, like "mobile" or "ABN", or "" for a line with no label
  value::String
  text::String     # the line as it's written
end

"The line that says `value` under `label`, or `value` alone when there's no label"
Detail(kind::Symbol, label::AbstractString, value::AbstractString) =
  Detail(kind, label, value, isempty(label) ? String(value) : "$label: $value")

"One contact of a block: a person or a company"
mutable struct Contact
  lines::Vector{Detail}   # each line of the contact, in the order of the block
  before::Int             # how many empty lines the block has before the contact
end

Contact() = Contact(Detail[], 0)

const LABELLED = r"^(\p{L}[\p{L}\p{N} _.\-]{0,29}?)\s*:\s*(.*)$"

"""
The label and the value of a line like `email: ada@example.com`, or nothing
for a line with no label. A web address like https://example.com has no
label, and nor does a time like 12:30.
"""
labelled(text::AbstractString) = begin
  m = match(LABELLED, text)
  m === nothing && return nothing
  label, value = String(m[1]), String(m[2])
  startswith(value, "//") && return nothing
  length(split(label)) <= 3 || return nothing
  # A colon with a digit on each side of it is part of a time
  isdigit(last(label)) && !isempty(value) && isdigit(first(value)) && endswith(text, label * ":" * value) && return nothing
  (label, value)
end

"True for a line that has the shape of a phone number: digits, spaces and + ( ) -, with six digits or more"
isphone(text::AbstractString) = occursin(r"^[\d\s+()\-]+$", text) && count(isdigit, text) >= 6

"What a line with no label is, by its shape: `:web`, `:email`, `:phone` or `:note`"
shape(text::AbstractString) =
  occursin(r"^(https?://|www\.)\S"i, text) ? :web : occursin(r"^\S+@\S+$", text) ? :email : isphone(text) ? :phone : :note

"The detail that a line of a block is. `named` says that the contact has its name already."
read_line(line::AbstractString, named::Bool) = begin
  text = String(strip(line))
  found = labelled(text)
  # The first line with no label is the name. A later one is read by its shape.
  found === nothing && return Detail(named ? shape(text) : :name, "", text, String(line))
  label, value = found
  kind = get(KINDS, lowercase(label), :other)
  # A contact has one name. A second `name:` line, and one with no value, is a detail like any other.
  kind == :name && (named || isempty(value)) && (kind = :other)
  Detail(kind, label, value, String(line))
end

"""
Read the contacts of a block from its lines. An empty line ends a contact.
Each line is kept as it's written, so `written` gives the same lines back.
"""
contacts(lines) = begin
  out, gap, current = Contact[], 0, nothing
  for line in lines
    if isempty(strip(line))
      gap += 1
      current = nothing
      continue
    end
    current === nothing && (current = Contact(Detail[], gap); push!(out, current))
    gap = 0
    push!(current.lines, read_line(line, any(d -> d.kind == :name, current.lines)))
  end
  out
end

"The first contact of the lines of a block, or a contact with nothing in it"
contact(lines) = (found = contacts(lines); isempty(found) ? Contact() : found[1])

"The lines of a contact"
written(c::Contact) = String[d.text for d in c.lines]

"The lines of a block that holds `list`, with the empty lines between its contacts"
written(list::Vector{Contact}) = begin
  out = String[]
  for c in list
    isempty(c.lines) && continue
    # An empty line must end the contact before
    append!(out, fill("", isempty(out) ? c.before : max(c.before, 1)))
    append!(out, written(c))
  end
  out
end

"The place among the lines of the first one of the kind `kind` that has a value, or nothing"
place(c::Contact, kind::Symbol) = findfirst(d -> d.kind == kind && !isempty(d.value), c.lines)

"What the first line of the kind `kind` says, or \"\""
said(c::Contact, kind::Symbol) = (i = place(c, kind); i === nothing ? "" : c.lines[i].value)

"True for a company: a contact with the line `kind: company`"
iscompany(c::Contact) = lowercase(said(c, :kind)) == "company"

"The contact's name, or \"\""
title(c::Contact) = said(c, :name)

"The places of the role and of the company that show under a person's name. Each is nothing when the contact has none, and both are for a company."
under(c::Contact) = iscompany(c) ? (nothing, nothing) : (place(c, :role), place(c, :company))

"The words under a person's name: Engineer, Analytical Engines. A company has none."
tagline(c::Contact) = join((c.lines[i].value for i in under(c) if i !== nothing), ", ")

"The picture that the contact names, as it's written, or \"\""
photo(c::Contact) = said(c, :photo)

"""
The places of the lines that show as a row of the card, in the order of the
block: every line but the name, the kind, the role and the company under the
name, and the photo.
"""
rows(c::Contact) = begin
  used = (place(c, :name), under(c)..., place(c, :photo))
  [i for (i, d) in enumerate(c.lines) if d.kind != :kind && !(i in used)]
end

"True for a contact with nothing to show: no name, and no row that has a value"
isblank(c::Contact) = isempty(title(c)) && all(i -> isempty(c.lines[i].value), rows(c))

"""
What a row shows in grey before its value, or "": the word of a phone number
that has one of its own, like `mobile`, and the label of a line that the card
has no place for, like `ABN`.
"""
caption(d::Detail) = begin
  d.kind in (:email, :address, :web, :note) && return ""
  d.kind == :phone && lowercase(d.label) in ("phone", "") ? "" : d.label
end

"Up to two letters for a name: the first letter of its first word and of its last. Ada Lovelace is AL."
initials(name::AbstractString) = begin
  words = [w for w in split(name) if isletter(first(w)) || isdigit(first(w))]
  isempty(words) && return ""
  uppercase(length(words) == 1 ? string(first(words[1])) : string(first(words[1]), first(words[end])))
end

"`text` as part of a web address: each byte that isn't a letter, a digit or one of `keep` is written as % and its number"
escaped(text::AbstractString, keep="-._~") =
  join(b in UInt8('a'):UInt8('z') || b in UInt8('A'):UInt8('Z') || b in UInt8('0'):UInt8('9') || b in codeunits(keep) ?
       string(Char(b)) : "%" * uppercase(string(b, base=16, pad=2)) for b in codeunits(text))

"A web address as a browser takes it: with https:// before it when it names no scheme"
address(value::AbstractString) = occursin(r"^[a-z][a-z0-9+.\-]*://"i, value) ? String(value) : "https://" * value

"""
What a click on a detail opens, or nothing for a detail that opens nothing. An
email address opens a new email, a phone number a call, an address the Maps
app, and a web address the browser. `maps` is what comes before the address
of a place.
"""
link(d::Detail; maps="maps://?q=") = begin
  v = strip(d.value)
  isempty(v) && return nothing
  d.kind == :email ? "mailto:" * escaped(v, "-._~@+") :
  d.kind == :phone ? (n = filter(c -> isdigit(c) || c == '+', v); isempty(n) ? nothing : "tel:" * n) :
  d.kind == :address ? maps * escaped(replace(v, r"\s+" => " ")) :
  d.kind == :web ? address(v) : nothing
end

# --- changing a contact ------------------------------------------------------------------

"`value` as one line of a block holds it: on one line, with no space at its ends"
tidy(value::AbstractString) = String(strip(replace(value, r"\s+" => " ")))

"""
The line that says `value` as a detail of the kind `kind`. It keeps `label`.
A line with no label gets one when its value alone would be read as another
kind of line.
"""
detail(kind::Symbol, label::AbstractString, value::AbstractString) = begin
  alone = isempty(label) && labelled(value) === nothing && (kind == :name || shape(value) == kind)
  Detail(kind, alone || !isempty(label) ? label : get(WORDS, kind, "note"), value)
end

"""
Make `value` what line `i` of the contact says. An empty value takes the line
out of the contact. It's true when the contact changed.
"""
set!(c::Contact, i::Int, value::AbstractString) = begin
  i in eachindex(c.lines) || return false
  d, value = c.lines[i], tidy(value)
  value == d.value && return false
  if isempty(value)
    deleteat!(c.lines, i)
    # With the name gone, the next line with no label would be read as the name. So each one gets its label.
    d.kind == :name && foreach(eachindex(c.lines)) do k
      n = c.lines[k]
      isempty(n.label) && (c.lines[k] = Detail(n.kind, get(WORDS, n.kind, "note"), n.value))
    end
  else
    c.lines[i] = detail(d.kind, d.label, value)
  end
  true
end

"Make `name` the contact's name. A contact with no name gets it as its first line. It's true when the contact changed."
rename!(c::Contact, name::AbstractString) = begin
  i = place(c, :name)
  i === nothing || return set!(c, i, name)
  name = tidy(name)
  isempty(name) && return false
  pushfirst!(c.lines, detail(:name, "", name))
  true
end

"Add a detail of the kind `kind` at the end of the contact. It's true when the contact changed: a detail with no value is left out."
add!(c::Contact, kind::Symbol, value::AbstractString) = begin
  value = tidy(value)
  isempty(value) && return false
  push!(c.lines, Detail(kind, get(WORDS, kind, "note"), value))
  true
end

"Add the contact `c` at the end of the block that holds `list`, after an empty line"
add!(list::Vector{Contact}, c::Contact) = (c.before = isempty(list) ? 0 : max(c.before, 1); push!(list, c); list)

"""
Take the contact at `k` out of the block that holds `list`. The empty lines
before it go with it. The contact after the first one takes the first one's
place at the top of the block.
"""
remove!(list::Vector{Contact}, k::Int) = begin
  k in eachindex(list) || return list
  k == 1 && length(list) > 1 && (list[2].before = list[1].before)
  deleteat!(list, k)
  list
end

# --- a contact as a vCard ----------------------------------------------------------------

"`text` as a value of a vCard holds it: with a \\ before a comma, a semicolon and a \\, and \\n for a new line"
vtext(text::AbstractString) = replace(text, '\\' => "\\\\", ',' => "\\,", ';' => "\\;", r"\r?\n|\r" => "\\n")

"""
A line of a vCard in pieces of 75 bytes at the most, as the format asks. Each
piece after the first starts with a space. No character is cut in two.
"""
folded(line::AbstractString) = begin
  out, piece, room = String[], IOBuffer(), 75
  for ch in line
    if position(piece) + ncodeunits(ch) > room
      push!(out, String(take!(piece)))
      room = 74   # the space at the start of the piece counts too
    end
    print(piece, ch)
  end
  push!(out, String(take!(piece)))
  join(out, "\r\n ")
end

"The kinds of phone that a vCard names, and the label that a contact gives each"
const PHONES = ("CELL" => "mobile", "FAX" => "fax", "WORK" => "work", "HOME" => "home")

"The kind of phone that a label names, as a vCard writes it"
phone_type(label::AbstractString) = (i = findfirst(p -> last(p) == lowercase(label), PHONES); i === nothing ? "VOICE" : first(PHONES[i]))

"""
The contact as a vCard, version 3.0, which the Contacts app reads. A company
is marked as one. The photo is left out. A line that a vCard has no place
for, like `ABN: 12 345 678 901`, goes in the note.
"""
vcard(c::Contact) = begin
  out = ["BEGIN:VCARD", "VERSION:3.0"]
  name = title(c)
  if iscompany(c)
    # The Contacts app shows a company by its ORG line
    push!(out, "N:;;;;", "FN:" * vtext(name), "ORG:" * vtext(name), "X-ABShowAs:COMPANY")
  else
    words = split(name)
    # The family name is the last word, and the given names are the words before it
    family, given = length(words) > 1 ? (words[end], join(words[1:end-1], " ")) : ("", name)
    push!(out, "N:$(vtext(family));$(vtext(given));;;", "FN:" * vtext(name))
    role, firm = under(c)
    firm === nothing || push!(out, "ORG:" * vtext(c.lines[firm].value))
    role === nothing || push!(out, "TITLE:" * vtext(c.lines[role].value))
  end
  notes = String[]
  for i in rows(c)
    d = c.lines[i]
    v = d.value
    isempty(v) && continue
    if d.kind == :email
      push!(out, "EMAIL;TYPE=INTERNET:" * vtext(v))
    elseif d.kind == :phone
      push!(out, "TEL;TYPE=$(phone_type(d.label)):" * vtext(v))
    elseif d.kind == :address
      push!(out, "ADR;TYPE=WORK:;;$(vtext(v));;;;")
    elseif d.kind == :web
      push!(out, "URL:" * vtext(address(v)))
    else
      push!(notes, d.kind == :note ? v : "$(d.label): $v")
    end
  end
  isempty(notes) || push!(out, "NOTE:" * vtext(join(notes, "\n")))
  push!(out, "END:VCARD")
  join(folded.(out), "\r\n") * "\r\n"
end

"Every contact of a block as the text of one vCard file. A contact with nothing in it is left out."
vcards(list::Vector{Contact}) = join(vcard(c) for c in list if !isblank(c))

"A name for the vCard file of a contact: the contact's name with no character that a file name can't have"
filename(c::Contact) = begin
  name = strip(replace(title(c), r"[/\\:\x00-\x1f]" => " "))
  (isempty(name) ? "Contact" : first(name, 80)) * ".vcf"
end

# --- reading a vCard ---------------------------------------------------------------------
#
# The Contacts app writes vCards of version 3.0. Other apps write 2.1 and
# 4.0. A long line is folded: its next piece is on a line that starts with a
# space. A name can have a group before it, like `item1.EMAIL`. In version
# 2.1 a value can be quoted-printable: `=C3=A9` is the two bytes of é, and a
# line that ends in = goes on with the next line.

"The bytes that quoted-printable text stands for, as text. Bytes that aren't UTF-8 are read as Latin-1."
unquoted(text::AbstractString) = begin
  bytes, units, i = UInt8[], codeunits(text), 1
  while i <= length(units)
    code = units[i] == UInt8('=') && i + 2 <= length(units) ? tryparse(UInt8, String(units[i+1:i+2]), base=16) : nothing
    code === nothing ? (push!(bytes, units[i]); i += 1) : (push!(bytes, code); i += 3)
  end
  s = String(bytes)
  isvalid(s) ? s : String([Char(b) for b in codeunits(s)])
end

"`value` with the escapes of a vCard taken out: \\n is a new line, and \\, \\; \\: and \\\\ are the character itself"
plain(value::AbstractString) = replace(value, r"\\(.)"s => m -> m[2] in ('n', 'N') ? "\n" : string(m[2]))

"The parts of a value that has several, like a name or an address. A ; that has a \\ before it is part of a part."
pieces(value::AbstractString) = begin
  out, part, escaping = String[], IOBuffer(), false
  for ch in value
    ch == ';' && !escaping ? push!(out, plain(String(take!(part)))) : print(part, ch)
    escaping = ch == '\\' && !escaping
  end
  push!(out, plain(String(take!(part))))
end

"""
The lines of a vCard file as whole lines: each one with the pieces that it
was folded into, and a quoted-printable value with the lines that it goes on
with.
"""
unfolded(text::AbstractString) = begin
  out, parts = String[], SubString{String}[]
  soft = false   # the line before ended in the = of a quoted-printable value that goes on
  finish() = (isempty(parts) || push!(out, join(parts)); empty!(parts))
  for line in eachsplit(String(text), r"\r\n|\n|\r")
    if soft
      push!(parts, line)
    elseif !isempty(parts) && (startswith(line, ' ') || startswith(line, '\t'))
      push!(parts, SubString(line, 2))
    else
      finish()
      push!(parts, line)
    end
    soft = endswith(line, '=') && occursin(r"^[^:]*QUOTED-PRINTABLE[^:]*:"i, parts[1])
    soft && (parts[end] = chop(parts[end]))
  end
  finish()
  out
end

"""
A line of a vCard as its name, in capitals and with no group before it, the
words of its settings, in capitals, and its value. It's nothing for a line
that isn't `NAME:value`.
"""
vline(line::AbstractString) = begin
  quoted, at = false, 0
  for (i, ch) in pairs(line)
    ch == '"' && (quoted = !quoted)
    ch == ':' && !quoted && (at = i; break)
  end
  at == 0 && return nothing
  head, value = split(line[1:prevind(line, at)], ';'), line[nextind(line, at):end]
  name = uppercase(last(split(head[1], '.')))
  # A setting is `TYPE=WORK,VOICE`, or in version 2.1 a word alone, like `CELL`
  words = String[]
  for setting in head[2:end], word in split(last(split(setting, '=', limit=2)), ',')
    push!(words, uppercase(strip(word, [' ', '"'])))
  end
  "QUOTED-PRINTABLE" in words && (value = unquoted(value))
  (name, words, String(value))
end

"The contact that the lines between BEGIN:VCARD and END:VCARD say. Each line of it is written with its label, but the name."
from_card(lines) = begin
  name, formal, firm, role, company = "", "", "", "", false
  details = Detail[]
  put(kind, label, value) = (v = tidy(value); isempty(v) || push!(details, Detail(kind, label, v)))
  for (key, words, value) in lines
    if key == "FN"
      name = tidy(plain(value))
    elseif key == "N"
      # The family name, the given name, the other names, what goes before the name and what goes after it
      p = [pieces(value); fill("", 5)]
      formal = tidy(join((p[4], p[2], p[3], p[1], p[5]), " "))
    elseif key == "ORG"
      firm = tidy(first(pieces(value)))
    elseif key == "TITLE"
      role = tidy(plain(value))
    elseif key == "X-ABSHOWAS"
      company = uppercase(strip(value)) == "COMPANY"
    elseif key == "EMAIL"
      put(:email, "email", plain(value))
    elseif key == "TEL"
      k = findfirst(p -> first(p) in words, PHONES)
      put(:phone, k === nothing ? "phone" : last(PHONES[k]), replace(plain(value), r"^tel:"i => ""))
    elseif key == "ADR"
      put(:address, "address", join((tidy(replace(p, r"\s*\n\s*" => ", ")) for p in pieces(value) if !isempty(strip(p))), ", "))
    elseif key == "URL"
      put(:web, "web", plain(value))
    elseif key == "NOTE"
      foreach(line -> put(:note, "note", line), split(plain(value), '\n'))
    end
  end
  # A card with no FN uses N, and a company with no name uses ORG
  isempty(name) && (name = formal)
  company && isempty(name) && (name = firm)
  c = Contact()
  isempty(name) || push!(c.lines, detail(:name, "", name))
  company && push!(c.lines, Detail(:kind, "kind", "company"))
  isempty(role) || push!(c.lines, Detail(:role, "role", role))
  # A company's ORG line is its own name again
  isempty(firm) || (company && firm == name) || push!(c.lines, Detail(:company, "company", firm))
  append!(c.lines, details)
  c
end

"""
The contacts that the text of a vCard file holds, of version 2.1, 3.0 or 4.0.
The photo and each line that a contact has no place for are left out. Text
that isn't a vCard gives no contacts.
"""
from_vcard(text::AbstractString) = begin
  out, card = Contact[], nothing
  for line in unfolded(text)
    found = vline(line)
    found === nothing && continue
    key, _, value = found
    if key == "BEGIN" && uppercase(strip(value)) == "VCARD"
      card = Tuple{String,Vector{String},String}[]
    elseif key == "END" && card !== nothing
      c = from_card(card)
      isempty(c.lines) || add!(out, c)
      card = nothing
    elseif card !== nothing
      push!(card, found)
    end
  end
  out
end

"True for text that is a vCard: it starts with BEGIN:VCARD"
isvcard(text::AbstractString) = occursin(r"^\s*BEGIN:VCARD"i, text)

# --- a contact as a card for a page of HTML ----------------------------------------------

"`s` as HTML writes it"
escape(s::AbstractString) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")

const GREY = "color: #6b6259"
"The picture of a building that the card of a company shows, as SVG"
const BUILDING = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"1.3em\" height=\"1.3em\" fill=\"currentColor\" viewBox=\"0 0 16 16\">" *
  "<path d=\"M4 2.5a.5.5 0 0 1 .5-.5h1a.5.5 0 0 1 .5.5v1a.5.5 0 0 1-.5.5h-1a.5.5 0 0 1-.5-.5zm3 0a.5.5 0 0 1 .5-.5h1a.5.5 0 0 1 .5.5v1a.5.5 0 0 1-.5.5h-1a.5.5 0 0 1-.5-.5zm3.5-.5a.5.5 0 0 0-.5.5v1a.5.5 0 0 0 .5.5h1a.5.5 0 0 0 .5-.5v-1a.5.5 0 0 0-.5-.5z" *
  "M4 5.5a.5.5 0 0 1 .5-.5h1a.5.5 0 0 1 .5.5v1a.5.5 0 0 1-.5.5h-1a.5.5 0 0 1-.5-.5zM7.5 5a.5.5 0 0 0-.5.5v1a.5.5 0 0 0 .5.5h1a.5.5 0 0 0 .5-.5v-1a.5.5 0 0 0-.5-.5zm2.5.5a.5.5 0 0 1 .5-.5h1a.5.5 0 0 1 .5.5v1a.5.5 0 0 1-.5.5h-1a.5.5 0 0 1-.5-.5z" *
  "M4.5 8a.5.5 0 0 0-.5.5v1a.5.5 0 0 0 .5.5h1a.5.5 0 0 0 .5-.5v-1a.5.5 0 0 0-.5-.5zm2.5.5a.5.5 0 0 1 .5-.5h1a.5.5 0 0 1 .5.5v1a.5.5 0 0 1-.5.5h-1a.5.5 0 0 1-.5-.5zm3.5-.5a.5.5 0 0 0-.5.5v1a.5.5 0 0 0 .5.5h1a.5.5 0 0 0 .5-.5v-1a.5.5 0 0 0-.5-.5z\"/>" *
  "<path d=\"M2 1a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H3a1 1 0 0 1-1-1zm11 0H3v14h3v-2.5a.5.5 0 0 1 .5-.5h3a.5.5 0 0 1 .5.5V15h3z\"/></svg>"

"""
The contact as HTML: a card with the picture or the initials, the name, the
role and the company, and a line for each other detail. An email address, a
phone number, an address and a web address are links. The parts have the
class names of the h-card microformat. A contact with nothing in it is "".
"""
markup(c::Contact) = begin
  isblank(c) && return ""
  out = IOBuffer()
  println(out, "<div class=\"h-card\" style=\"display: flex; gap: 0.9em; max-width: 26em; margin: 1em 0; padding: 0.8em 1em; ",
          "border: 1px solid #d8d0bd; border-radius: 8px; font: 0.9em/1.5 -apple-system, system-ui, sans-serif;\">")
  round = "width: 2.9em; height: 2.9em; border-radius: 50%; flex: none;"
  if !isempty(photo(c))
    println(out, "<img class=\"u-photo\" src=\"$(escape(photo(c)))\" alt=\"\" style=\"$round object-fit: cover;\">")
  else
    println(out, "<span aria-hidden=\"true\" style=\"$round display: flex; align-items: center; justify-content: center; ",
            "background: #ebe2cf; color: #9c5626; font-weight: 600;\">$(iscompany(c) ? BUILDING : escape(initials(title(c))))</span>")
  end
  println(out, "<div style=\"flex: 1; min-width: 0; overflow-wrap: anywhere;\">")
  isempty(title(c)) || println(out, "<strong class=\"$(iscompany(c) ? "p-name p-org" : "p-name")\">$(escape(title(c)))</strong>")
  role, firm = under(c)
  parts = String[]
  role === nothing || push!(parts, "<span class=\"p-job-title\">$(escape(c.lines[role].value))</span>")
  firm === nothing || push!(parts, "<span class=\"p-org\">$(escape(c.lines[firm].value))</span>")
  isempty(parts) || println(out, "<div style=\"$GREY\">", join(parts, ", "), "</div>")
  for i in rows(c)
    d = c.lines[i]
    isempty(d.value) && continue
    v, to = escape(d.value), link(d, maps="https://maps.apple.com/?q=")
    href = to === nothing ? "" : " href=\"$(escape(to))\""
    lead = isempty(caption(d)) ? "" : "<span style=\"$GREY\">$(escape(caption(d)))</span> "
    println(out, d.kind == :email ? "<div>$lead<a class=\"u-email\"$href>$v</a></div>" :
                 d.kind == :phone && to !== nothing ? "<div>$lead<a class=\"p-tel\"$href>$v</a></div>" :
                 d.kind == :address ? "<div class=\"p-adr\">$lead<a$href>$v</a></div>" :
                 d.kind == :web ? "<div>$lead<a class=\"u-url\"$href>$v</a></div>" :
                 d.kind == :note ? "<div class=\"p-note\">$v</div>" : "<div>$lead$v</div>")
  end
  print(out, "</div>\n</div>")
  String(take!(out))
end

"Every contact of a block as HTML: one card for each. A block with nothing to show is \"\"."
markup(list::Vector{Contact}) = join((markup(c) for c in list if !isblank(c)), "\n")
