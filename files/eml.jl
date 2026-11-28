# What Ladder shows of an email file. An .eml file holds one email as a server
# sends it, with what was attached to it inside. mime.jl takes the email apart.
# This file says what a window needs of that: the lines of the page that shows
# the email, the email's HTML, and where the files that came with it are kept.
# It also reads the front matter of a page, which is where an email's page has
# who it's from and its subject. It draws nothing, and it talks to no server.
#
#     isemail(path)            # true for a file whose name ends in .eml
#     render(path)             # the email in the file at `path`, as the lines of a page
#     webpage(path)            # the email's HTML, as its sender wrote it, or ""
#     header_fields(path)      # every field of the email's header, as name => value
#     attached(path, lines)    # the first of the lines of that page that link to the email's files
#     fields(lines)            # what the front matter of a page says, by its keys
#     sender(lines)            # the address of who sent the email of that page
#     isdraft(lines)           # true for a page that's an email to send
#
# Ladder only reads email. Getting it from a server, and sending it, is the
# work of code that the startup page loads.

@use "./mime" message page addresses webpage headers oneline unworded
@use "../markdown" front_matter

"True for the name of a file that holds an email as a server sends one"
isemail(name) = endswith(lowercase(name), ".eml")

"`s` on one line: each tab and each end of a line is a space"
flat(s) = replace(s, r"[\t\r\n]+" => " ")

"`s` as part of a file's name: no more than `most` characters and `room` bytes, with nothing that a name can't hold"
clean(s, most, room) = begin
  s = strip(replace(replace(s, r"[/:\\\x00-\x1f\x7f]" => " "), r"\s+" => " "))
  s = String(lstrip(first(s, most), '.'))
  while sizeof(s) > room
    s = String(chop(s))
  end
  String(strip(s))
end

"`path` as a link writes it: a space, and a bracket that would end the link, are written as codes"
escaped(path) = replace(path, ' ' => "%20", '(' => "%28", ')' => "%29")
"The path that a link wrote with `escaped`"
unescaped(path) = replace(path, "%20" => ' ', "%28" => '(', "%29" => ')')

"`people` as the front matter writes them: Sam Lee <sam@example.com>, with a comma between two"
written(people) = join((isempty(strip(name)) ? address : occursin(r"[,<>\"]", name) ? "\"$(replace(name, '"' => "'"))\" <$address>" : "$name <$address>"
                        for (name, address) in people), ", ")

"The folder that holds the files of the emails that were opened, like a PDF that came with one. A test names a folder of its own in `CACHE`."
const CACHE = Ref("")
cache() = isempty(CACHE[]) ? joinpath(homedir(), "Library", "Caches", "Ladder", "email") : CACHE[]

"The folder of Ladder's cache that keeps the files that came with the email at `path`"
attachments(path) = joinpath(cache(), string(hash(abspath(path)), base=16))

"""
The email in the file at `path` as the lines of a page, for a window to show:
front matter that says who it's from and so on, then its text as Markdown,
then a link to each file that came with it. Those files are inside the email,
so a copy of each goes in Ladder's cache for the links to open. The email's
file isn't changed.
"""
render(path) = begin
  part = message(read(path))
  dir = attachments(path)
  keep(name, bytes, picture) = begin
    mkpath(dir)
    base, ext = splitext(clean(name, 80, 150))
    file = joinpath(dir, (isempty(base) ? "file" : base) * ext)
    # The same file of the same email is written once
    (isfile(file) && filesize(file) == length(bytes)) || write(file, bytes)
    file
  end
  lines = page(part, keep=keep, at=mtime(path))
  # The address that an answer goes to, when it isn't the sender's
  from, answer = addresses(part, "from"), addresses(part, "reply-to")
  at = findfirst(startswith("from:"), lines)
  !isempty(answer) && at !== nothing && answer != from && insert!(lines, at + 1, "reply-to: " * flat(written(answer)))
  lines
end

"""
The HTML of the email in the file at `path`, as its sender wrote it, for a
browser to draw. It's "" for an email with no HTML, and for a file that
can't be read. See `webpage` in mime.jl.
"""
webpage(path::AbstractString) = try webpage(message(read(path))) catch; "" end

"""
Every field of the header of the email in the file at `path`, in the order
that the email has them, like Received, DKIM-Signature and Subject: each
field's name, and its value as text on one line. A field can come more than
once. It's empty for a file that can't be read.
"""
header_fields(path) = try
  raw = read(path)
  [String(name) => oneline(unworded(value)) for (name, value) in first(headers(raw, 1, length(raw)))]
catch
  Pair{String,String}[]
end

"""
The first of the lines at the end of `lines` that link to the files that came
with the email at `path`, where `lines` are what `render` gives for it. With
no such line, it's one more than the number of lines.
"""
attached(path, lines) = begin
  dir = escaped(attachments(path)) * "/"
  i = length(lines) + 1
  while i > 1 && occursin("](" * dir, lines[i-1]); i -= 1 end
  i
end

"What the front matter of the page `lines` says, by its keys in lower case, and the line that the page's text starts on"
fields(lines) = begin
  out = Dict{String,String}()
  stop = front_matter(lines)
  key = ""
  for i in 2:stop-1
    f = match(r"^([\w][\w .-]*):\s*(.*)$", lines[i])
    if f !== nothing
      key = lowercase(strip(f[1]))
      out[key] = String(strip(f[2]))
    elseif !isempty(key) && startswith(lines[i], r"\s") && !isempty(strip(lines[i]))
      # A long list of people can go on in the next line
      out[key] = String(strip(out[key] * " " * strip(lines[i])))
    end
  end
  (out, stop + 1)
end

"""
The address of who sent the email whose page is `lines`, as `render` makes
it, in lower case and without the sender's name. It's "" when the front
matter names nobody it's from.
"""
sender(lines) = begin
  said, _ = fields(lines)
  people = addresses(get(said, "from", ""))
  isempty(people) ? "" : lowercase(strip(last(first(people))))
end

"True when the page `lines` is an email that isn't sent yet: its front matter names who it's to, and has no date"
isdraft(lines) = begin
  front_matter(lines) > 0 || return false
  said, _ = fields(lines)
  haskey(said, "to") && haskey(said, "subject") && !haskey(said, "date") && !haskey(said, "from")
end
