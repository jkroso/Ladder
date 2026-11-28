# A save block writes the rows of a table of the page into a file, or sends
# them to a server. In a document it's a code block in the language `save`:
#
#     ```save
#     to: big orders.csv
#     ```
#
#     ```save
#     to: https://example.com/api/orders
#     key: example-api
#     ```
#
# The rows are those of the table that's nearest above the block: a table, a
# spreadsheet, a sheet, a filter, or a line that shows a CSV file. `from` names
# the heading of a table instead, as a chart's `from` does.
#
# `to` is a file beside the page, or a web address. Nothing is written or sent
# until you click the block's button, and each click writes the file again.
#
# `as` says how the rows are written: `csv`, `tsv` or `json`. Without it, the
# file's name says, and a server gets JSON: a list with an object for each
# row, whose keys are the names of the columns.
#
# `method` is how a server is asked: POST, PUT or PATCH. Without it, POST.
#
# `key` names a password in the Mac's Keychain. Ladder sends it to the server
# as `Authorization: Bearer` and the key. The page holds only the name, so the
# key stays out of the file. Ladder sends a key only over https, or to this Mac.

@use "../web/url" isurl host

const SAVE = "save"

"What a save block says: where the rows go, and how"
Base.@kwdef mutable struct Save
  to::String = ""       # a file beside the page, or a web address. "" until you choose one.
  from::String = ""     # the heading of the table to save, or "" for the table above the block
  as::String = ""       # csv, tsv or json, or "" to go by `to`
  method::String = ""   # POST, PUT or PATCH, or "" for POST
  key::String = ""      # the name of a password in the Keychain, or ""
end

# The names that each line can start with, and the field that each one sets
const NAMES = Dict("to" => :to, "into" => :to, "from" => :from, "as" => :as, "format" => :as,
                   "method" => :method, "key" => :key, "password" => :key)

"The name and the value of a line like `to: orders.csv`, or nothing when it isn't one"
named(line) = begin
  m = match(r"^\s*([A-Za-z]+)\s*:\s*(.*?)\s*$", line)
  m === nothing ? nothing : (lowercase(m[1]), String(m[2]))
end

"Read the lines of a save block. A line that it doesn't know is left alone."
query(lines) = begin
  s = Save()
  for line in lines
    x = named(line)
    x === nothing && continue
    field = get(NAMES, x[1], nothing)
    field === nothing || setfield!(s, field, x[2])
  end
  s
end

"""
`lines` with the line that `field` says set to `value`. The first line that
says it changes, and the other lines stay as they are. Without one, the line
goes first.
"""
with_line(lines, field::Symbol, value) = begin
  k = findfirst(l -> (x = named(l); x !== nothing && get(NAMES, x[1], nothing) == field), lines)
  line = "$field: $value"
  k === nothing ? [line; lines] : [lines[1:k-1]; line; lines[k+1:end]]
end

"True when the web address `url` is this Mac"
islocal(url) = lowercase(host(url)) in ("localhost", "127.0.0.1", "[::1]")

"How the rows are written: csv, tsv or json, or nothing when `as` names another way"
format(s::Save) = begin
  as = lowercase(strip(s.as))
  isempty(as) || return as in ("csv", "tsv", "json") ? as : nothing
  isurl(s.to) && return "json"
  ext = lowercase(splitext(strip(s.to))[2])
  ext == ".json" ? "json" : ext in (".tsv", ".tab") ? "tsv" : "csv"
end

"How a server is asked, in capitals, or nothing when `method` names another way"
method(s::Save) = (m = uppercase(strip(s.method)); isempty(m) ? "POST" : m in ("POST", "PUT", "PATCH") ? m : nothing)

"What the server is told that the rows are"
content_type(format) = format == "json" ? "application/json" : format == "tsv" ? "text/tab-separated-values" : "text/csv"

"Why the block can't save as it's written, or \"\""
problem(s::Save) = begin
  format(s) === nothing && return "Ladder writes rows as csv, tsv or json, so “as: $(strip(s.as))” has to be one of those."
  url = isurl(s.to)
  url && method(s) === nothing && return "A server is asked with POST, PUT or PATCH, so “method: $(strip(s.method))” has to be one of those."
  url && !isempty(strip(s.key)) && !startswith(lowercase(strip(s.to)), "https://") && !islocal(s.to) &&
    return "Ladder sends a key only to an address that starts with https://, so that no one on the way can read it."
  ""
end

"The rows as CSV, or as TSV when `mark` is a tab. A cell with the mark, a quote or a new line in it goes in quotes."
delimited(rows, mark=',') = begin
  quoted(cell) = occursin(mark, cell) || occursin('"', cell) || occursin('\n', cell) || occursin('\r', cell) ?
                 "\"" * replace(cell, "\"" => "\"\"") * "\"" : cell
  join((join(quoted.(row), mark) for row in rows), "\n") * "\n"
end

"A cell that is a plain number, like 12, -3.5 or 1e6. A number in JSON can be written this way."
const PLAIN_NUMBER = r"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][-+]?[0-9]+)?$"

"How `n` rows are said"
rows_words(n) = "$(n == 1 ? "1 row" : replace(string(n), r"(?<=\d)(?=(\d{3})+$)" => ",") * " rows")"

# What a server's answer means, for the answers that servers give most
const ANSWERS = Dict(200 => "OK", 201 => "Created", 202 => "Accepted", 204 => "No Content",
                     301 => "Moved Permanently", 302 => "Found", 303 => "See Other", 307 => "Temporary Redirect", 308 => "Permanent Redirect",
                     400 => "Bad Request", 401 => "Unauthorized", 403 => "Forbidden", 404 => "Not Found",
                     405 => "Method Not Allowed", 409 => "Conflict", 411 => "Length Required", 413 => "Content Too Large",
                     415 => "Unsupported Media Type", 422 => "Unprocessable Content", 429 => "Too Many Requests",
                     500 => "Internal Server Error", 502 => "Bad Gateway", 503 => "Service Unavailable", 504 => "Gateway Timeout")

"The server's answer `code`, with what it means: 201 Created"
answer(code) = (words = get(ANSWERS, code, ""); isempty(words) ? string(code) : "$code $words")

"""
What a server said with its answer, when it said no: the first line of its
text, unless that's a web page, cut to `most` characters.
"""
said(body; most=200) = begin
  text = strip(body)
  (isempty(text) || startswith(text, '<')) && return ""
  line = String(strip(first(split(text, '\n'))))
  length(line) > most ? first(line, most - 1) * "…" : line
end

"What curl said when it couldn't reach the server, without its number: Could not resolve host: example.com"
curl_words(err) = (line = strip(first(split(strip(err) * "\n", '\n'))); String(replace(line, r"^curl: \(\d+\)\s*" => "")))
