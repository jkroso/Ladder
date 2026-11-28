# Writes a Markdown document as a page of HTML, so that it can go on a website
# or be read in a browser.
#
#     html(lines, title="Notes")
#
# It reads the Markdown the way the editor does, with `classify` and `spans`,
# so the page has what the editor shows: each line of text is a paragraph, and
# a footnote's number is its place among the footnotes. `block(lang, first,
# last)` gives the HTML of a code block that the editor shows as something
# else, like a sheet, or nothing to show its code. `value(code)` gives the text
# that a piece of inline code made, or nothing to show its code. `file(text)`
# gives the HTML of a line that the editor shows as something else, like the
# table of a CSV file, or nothing for a line of text. A formula goes in as
# MathML, which a browser sets itself. `columns` says which lines show side by
# side: for each group of columns, the first line, the last line and the share
# of the width of each column. ==Words== are marked, as a highlighter marks
# them, and a comment, like %%note%%, is left out.

@use "./markdown" Kind Line Span classify spans tablecells isdivider front_matter isdone MATTER TOML_MATTER MATH COMMENT callout opens_callout wikitarget
@use "./blocks/math" mathml

"`s` with the characters that mean something in HTML written as their names"
escape(s::AbstractString) = replace(s, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")

# A picture's path can have spaces in it, like ../images/air transport.png, or be between < and >
const PICTURE = r"!\[([^\]]*)\]\(\s*(?|<([^>\n]+)>|([^)\s\"<](?:[^)\"\n]*[^)\s\"])?))(?:\s+\"[^\"]*\")?\s*\)"
const NOTE = r"^\[\^([^\]\s]+)\]:\s*"   # the start of the line that holds a footnote's text

"What turns Markdown into HTML needs to know of the document: its footnotes, and what its inline code made"
struct Document
  notes::Dict{String,Int}   # the number of each footnote, by its name
  value::Function
end

"The HTML of the text `text`, which is part of a line: its bold, its links and so on"
inline(d::Document, text::AbstractString) = begin
  out = IOBuffer()
  at = 1
  # A picture isn't one of the editor's spans, so the text between the pictures is read as spans
  for m in eachmatch(PICTURE, text)
    styled!(out, d, SubString(text, at, prevind(text, m.offset)))
    print(out, embed(m[2], m[1]))
    at = m.offset + ncodeunits(m.match)
  end
  styled!(out, d, SubString(text, at))
  String(take!(out))
end

const VIDEO_FILES = (".mp4", ".mov", ".m4v")
const SOUND_FILES = (".mp3", ".m4a", ".wav", ".aif", ".aiff", ".aac", ".flac", ".caf")

"""
The HTML of what a picture's Markdown names: a player for a video or a sound
file, and a picture for anything else. A browser plays only the part of the
file that a `#t=61,86` at the end of `src` names, as the editor does.
"""
embed(src, alt) = begin
  ext = lowercase(splitext(first(split(src, r"[?#]")))[2])
  # A space can't be in an address
  src = replace(src, " " => "%20")
  tag = ext in VIDEO_FILES ? "video" : ext in SOUND_FILES ? "audio" : nothing
  tag === nothing && return "<img src=\"" * escape(src) * "\" alt=\"" * escape(alt) * "\">"
  "<$tag controls preload=\"metadata\" src=\"$(escape(src))\" title=\"$(escape(alt))\"></$tag>"
end

styled!(out, d::Document, text::AbstractString) = begin
  mark = ""   # the markup that came last, which says whether a formula is between $ or $$
  for s in spans(text)
    s.markup && (mark = s.text)
    s.markup || styled!(out, d, s, mark)
  end
end

styled!(out, d::Document, s::Span, mark) = begin
  # A comment, like %%note%%, is for whoever writes the page, so the page of HTML leaves it out
  s.comment && return
  # A formula between $$ is on a line of its own
  s.math && return print(out, mathml(s.text, display=mark == "\$\$"))
  if startswith(s.link, '^')
    # A footnote's number, which goes to the footnote
    name = s.link[2:end]
    n = get(d.notes, name, 0)
    print(out, "<sup><a href=\"#fn-", escape(name), "\" id=\"fnref-", escape(name), "\">", n == 0 ? escape(name) : n, "</a></sup>")
    return
  end
  body = escape(s.text)
  if s.live
    made = d.value(s.text)
    body = made === nothing ? "<code>" * body * "</code>" : escape(made)
  elseif s.code
    body = "<code>" * body * "</code>"
  end
  s.highlit && (body = "<mark>" * body * "</mark>")
  s.strike && (body = "<del>" * body * "</del>")
  s.italic && (body = "<em>" * body * "</em>")
  s.bold && (body = "<strong>" * body * "</strong>")
  isempty(s.link) || (body = "<a href=\"" * escape(href(s.link)) * "\">" * body * "</a>")
  print(out, body)
end

"""
Where a link goes in a page of HTML. A wiki link goes to the file of its page,
beside this page: [[Ideas#My plans]] goes to `Ideas.md#my-plans`. A name that
ends with a file's extension, like [[plan.pdf]], is the name of that file.
"""
href(link) = begin
  target = wikitarget(link)
  target === nothing && return link
  name, heading = occursin('#', target) ? split(target, '#', limit=2) : (target, "")
  name = strip(name)
  file = isempty(name) || occursin(r"\.[A-Za-z][A-Za-z0-9]{0,4}$", name) ? name : name * ".md"
  slug = strip(replace(lowercase(heading), r"[^\p{L}\p{N}]+" => "-"), '-')
  replace(file, ' ' => "%20") * (isempty(slug) ? "" : "#" * slug)
end

"The number of each footnote of `lines`, by name: the footnotes that the text points to, in that order, then the rest"
footnotes(lines) = begin
  notes = Dict{String,Int}()
  add(name) = get!(notes, String(name), length(notes) + 1)
  for line in lines
    for m in eachmatch(r"\[\^([^\]\s]+)\]", replace(line, NOTE => ""))
      add(m[1])
    end
  end
  for line in lines
    m = match(NOTE, line)
    m === nothing || add(m[1])
  end
  notes
end

"The cells of a row of a table, as text"
cells(text) = [strip(String(collect(text)[c.lo+1:c.hi])) for c in tablecells(text)]

"Which side each column of a table puts its text on, from its line of dashes, like `:---:`"
sides(divider) = map(cells(divider)) do cell
  startswith(cell, ':') && endswith(cell, ':') ? "center" : endswith(cell, ':') ? "right" : ""
end

"The picture that the `cover` key of front matter, whose lines between its fences are `lines`, names, or nothing"
matter_cover(lines) = begin
  for l in lines
    m = match(r"^cover\s*[:=]\s*(.*?)\s*$"i, l)
    m === nothing && continue
    src = strip(m[1], ['"', '\'', ' '])
    return isempty(src) ? nothing : String(src)
  end
  nothing
end

const STYLE = """
img.cover { display: block; width: 100%; height: 16em; object-fit: cover; border-radius: 8px; margin: 0 0 1.5em; }
body { font: 17px/1.6 Charter, Georgia, serif; color: #2b2622; background: #fdfcf9; max-width: 44em; margin: 3em auto; padding: 0 1.5em; }
h1, h2, h3, h4, h5, h6 { line-height: 1.25; margin: 1.6em 0 0.5em; }
a { color: #9c5626; }
mark { background: #f6e3a0; color: inherit; border-radius: 2px; padding: 0 0.1em; }
code, pre { font: 0.86em/1.5 Menlo, Consolas, monospace; }
code { background: #f1ede2; border-radius: 4px; padding: 0.1em 0.35em; }
pre { background: #f1ede2; border-radius: 6px; padding: 0.9em 1.1em; overflow-x: auto; }
pre code { background: none; padding: 0; font-size: 1em; }
blockquote { margin: 1em 0; padding-left: 1em; border-left: 3px solid #d8d0bd; color: #6b6259; font-style: italic; }
blockquote.callout { --hue: #30628c; padding: 0.6em 1em; border-left-color: var(--hue); background: color-mix(in srgb, var(--hue) 8%, transparent); color: inherit; font-style: normal; }
blockquote.callout p { margin: 0.3em 0; }
blockquote.callout .callout-title { color: var(--hue); font-weight: bold; }
blockquote.tip { --hue: #54742c; }
blockquote.important { --hue: #963a6c; }
blockquote.warning { --hue: #aa6214; }
blockquote.caution { --hue: #ba3428; }
table { border-collapse: collapse; margin: 1em 0; }
caption { font-size: 0.85em; color: #6b6259; text-align: left; padding-bottom: 0.4em; }
th, td { border: 1px solid #d8d0bd; padding: 0.35em 0.8em; text-align: left; }
th { background: #f1ede2; }
img, video { max-width: 100%; }
video { display: block; max-height: 70vh; }
.diagram { margin: 1em 0; }
.diagram svg { display: block; max-width: 100%; height: auto; }
hr { border: 0; border-top: 1px solid #d8d0bd; margin: 2em 0; }
li.todo { list-style: none; margin-left: -1.4em; }
.footnotes { font-size: 0.88em; color: #6b6259; border-top: 1px solid #d8d0bd; margin-top: 3em; }
.columns { display: flex; gap: 2em; align-items: flex-start; margin: 1em 0; }
.columns > div { min-width: 0; }
.columns > div > :first-child { margin-top: 0; }
@media (max-width: 34em) { .columns { display: block; } }
"""

"""
The lines of a Markdown document as a page of HTML. `title` is what the
browser's tab says.
"""
html(lines::AbstractVector{<:AbstractString}; title="", block=(lang, first, last) -> nothing, value=code -> nothing, file=text -> nothing, columns=()) = begin
  kinds = classify(lines)
  d = Document(footnotes(lines), value)
  out = IOBuffer()
  lists = Tuple{Int,String}[]   # the lists that are open now: how far each is indented, and ul or ol
  notes = Tuple{String,String}[]
  quoted = false
  shut!(to=-1) = while !isempty(lists) && last(lists)[1] > to
    println(out, "</li></", pop!(lists)[2], ">")
  end
  unquote!() = quoted && (println(out, "</blockquote>"); quoted = false)
  # The tags that open and close each column, each with the line that it goes before, in the order of the lines
  edges = Tuple{Int,String}[]
  for group in columns, (k, (from, to, share)) in enumerate(group)
    push!(edges, (from, (k == 1 ? "<div class=\"columns\">\n" : "") * "<div style=\"flex: " * string(isinteger(share) ? Int(share) : share) * " 1 0\">"))
    push!(edges, (to + 1, "</div>" * (k == length(group) ? "\n</div>" : "")))
  end
  # Before a column starts and after it ends, the list and the quote that are open are closed
  edge!(i) = while !isempty(edges) && first(edges)[1] <= i
    shut!()
    unquote!()
    println(out, popfirst!(edges)[2])
  end
  i, n = 1, length(lines)
  while i <= n
    edge!(i)
    text, line = lines[i], kinds[i]
    k = line.kind
    k in (Kind.bullet, Kind.ordered, Kind.todo) || (k == Kind.blank && !isempty(lists)) || shut!()
    k == Kind.blockquote || unquote!()
    if k == Kind.fence && line.level == 0
      # A code block, as far as the line that closes it
      t = something(findnext(j -> kinds[j].kind == Kind.fence && kinds[j].level == 1, i+1:n, 1), n - i + 1) + i
      t = min(t, n)
      # Front matter says things about the page, and a comment is for whoever writes it. Neither is part of the page.
      # A cover that the front matter names is a picture at the top of the page.
      cover = line.lang in (MATTER, TOML_MATTER) ? matter_cover(lines[i+1:t-1]) : nothing
      cover === nothing || println(out, "<img class=\"cover\" src=\"", escape(replace(cover, " " => "%20")), "\" alt=\"\">")
      if !(line.lang in (MATTER, TOML_MATTER, COMMENT))
        tex = line.lang == MATH && kinds[t].kind == Kind.fence ? join(lines[i+1:t-1], "\n") : ""
        made = isempty(strip(tex)) ? block(line.lang, i, t) : mathml(tex, display=true)
        if made === nothing
          lang = isempty(line.lang) ? "" : " class=\"language-$(escape(line.lang))\""
          println(out, "<pre><code", lang, ">", escape(join(lines[i+1:(kinds[t].kind == Kind.fence ? t - 1 : t)], "\n")), "</code></pre>")
        else
          println(out, made)
        end
      end
      i = t + 1
      continue
    elseif k == Kind.heading
      println(out, "<h", line.level, ">", inline(d, chop(text, head=line.prefix, tail=0)), "</h", line.level, ">")
    elseif k == Kind.rule
      println(out, "<hr>")
    elseif k in (Kind.bullet, Kind.ordered, Kind.todo)
      tag = k == Kind.ordered ? "ol" : "ul"
      shut!(line.level)
      if !isempty(lists) && last(lists)[1] == line.level && last(lists)[2] == tag
        println(out, "</li>")
      else
        # A list of another kind at the same indent ends the one before it
        isempty(lists) || last(lists)[1] < line.level || shut!(line.level - 1)
        println(out, "<", tag, ">")
        push!(lists, (line.level, tag))
      end
      body = inline(d, chop(text, head=line.prefix, tail=0))
      k == Kind.todo ? print(out, "<li class=\"todo\"><input type=\"checkbox\" disabled", isdone(text) ? " checked" : "", "> ", body) :
                       print(out, "<li>", body)
    elseif k == Kind.blockquote
      # A callout is a quote with a class for its kind. Its first line is its title, or its kind's name when it has none.
      kind = callout(line)
      quoted || (println(out, isempty(kind) ? "<blockquote>" : "<blockquote class=\"callout $kind\">"); quoted = true)
      body = inline(d, chop(text, head=line.prefix, tail=0))
      opens_callout(line) ? println(out, "<p class=\"callout-title\">", isempty(strip(body)) ? uppercasefirst(kind) : body, "</p>") :
                            println(out, "<p>", body, "</p>")
    elseif k == Kind.table
      j = i
      while j < n && kinds[j+1].kind == Kind.table; j += 1 end
      if j > i && isdivider(lines[i+1])
        side = sides(lines[i+1])
        row(tag, text) = "<tr>" * join(["<$tag$(c <= length(side) && !isempty(side[c]) ? " style=\"text-align: $(side[c])\"" : "")>$(inline(d, cell))</$tag>"
                                        for (c, cell) in enumerate(cells(text))]) * "</tr>"
        println(out, "<table>\n<thead>", row("th", lines[i]), "</thead>\n<tbody>")
        foreach(r -> println(out, row("td", lines[r])), i+2:j)
        println(out, "</tbody>\n</table>")
      else
        foreach(r -> println(out, "<p>", inline(d, lines[r]), "</p>"), i:j)
      end
      i = j + 1
      continue
    elseif k == Kind.paragraph
      m = match(NOTE, text)
      made = m === nothing ? file(text) : nothing   # a line that holds only a file can show as something else
      made === nothing || (println(out, made); i += 1; continue)
      body = m === nothing ? inline(d, text) : ""
      # A line that holds only a comment makes no paragraph
      m === nothing && isempty(strip(body)) && (i += 1; continue)
      m === nothing ? println(out, "<p>", body, "</p>") :
                      push!(notes, (String(m[1]), inline(d, chop(text, head=length(m.match), tail=0))))
    end
    i += 1
  end
  edge!(n + 1)
  shut!()
  unquote!()
  if !isempty(notes)
    # The footnotes go at the foot of the page, in the order of their numbers
    println(out, "<section class=\"footnotes\">\n<ol>")
    for (name, body) in sort(notes, by=note -> get(d.notes, note[1], 0))
      println(out, "<li id=\"fn-", escape(name), "\" value=\"", get(d.notes, name, 0), "\">", body, " <a href=\"#fnref-", escape(name), "\">↩</a></li>")
    end
    println(out, "</ol>\n</section>")
  end
  """
  <!DOCTYPE html>
  <html>
  <head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(escape(title))</title>
  <style>
  $(STYLE)</style>
  </head>
  <body>
  $(String(take!(out)))</body>
  </html>
  """
end

export html, footnotes, NOTE
