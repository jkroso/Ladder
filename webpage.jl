# Makes pictures of a page of HTML, as a browser draws it, and finds the link
# and the words at a point of a page.
#
# Ladder shows an email as it was sent with web/, which lays the email's HTML
# out itself. The email view uses only `remote` and `open_link` of this file.
#
# The pictures are how Ladder showed an email before it had web/. They stay
# as a way to check web/ against a browser: the text file that comes with
# them says how big WebKit makes a page, and where it puts each letter.
#
# webpage.swift does the drawing, as a program of its own, because macOS only
# offers WebKit, its part that draws web pages, to Swift. The pictures are
# kept in a folder, so a page shows at once the next time:
#
#     p = picture!(folder, html, 700)
#     p.state         # :there, :coming, :failed or :none. Ask again while it's :coming.
#     s = shot(p.file)
#     s.wide, s.tall  # how big the whole page is, in px
#     s.strips        # the page from the top down, as PNG files: each file, and how tall it is
#     link(s, x, y)   # the link at a point of the page, with where it goes, or nothing
#
# The program says where each letter of the page's words is drawn. `s.words`
# has them as web/select.jl has a page's words, so its functions select them.
#
# A page can be very tall, so its picture is in strips, which a window draws
# one under the other. The page is drawn without JavaScript. The program asks
# the web for nothing, so that the sender of an email can't tell when it's
# opened. Then a picture that the page has from a web site shows as an empty
# box. `remote(html)` is true for a page with such pictures, and
# `picture!(...; pictures=true)` fetches them.
#
# The Ladder app doesn't have the program in it. Run from its source, Ladder
# compiles webpage.swift the first time it's needed, which takes a few
# seconds, and keeps the program in a folder of the Mac's caches. That needs
# Swift, which comes with Xcode and its command line tools.

@use "./swift" target programs kept!
@use "./swift" => Swift
@use "./web/select" => Select

const SOURCE = joinpath(@__DIR__, "webpage.swift")

"What to say when the pictures can't be made"
const FAILED = "Ladder can't draw this email as it was sent."
const NO_SWIFT = "Ladder needs Swift to draw an email as it was sent. It comes with Xcode's command line tools."

"""
The command that runs the program with `args`. The program is compiled from
the source, and kept in the folder `dir`. If it isn't compiled yet, the
command compiles it first.
"""
command(args; dir=programs()) = Swift.command(SOURCE, "webpage-program-", args; dir)

"""
Start the program that draws the HTML in the file `source` on a page `wide`
px wide. It writes each strip of the picture to a file whose name starts with
`stem`, then what it made to the file `out`, and why it failed to the file
`err`. This gives the program as it runs.
"""
run_program(source, wide, zoom, pictures, stem, out, err) =
  run(pipeline(command([(pictures ? ["--pictures"] : String[])..., "--zoom", string(zoom), string(wide), source, stem, out]),
               stdout=devnull, stderr=err), wait=false)

"""
The function that makes the pictures. It takes what `run_program` takes. It
gives a program that runs, or the number that a program which has finished
already ended with: 0 when the pictures are made, and 1 when they aren't. A
test puts a function of its own here, so that it uses neither the program nor
the web.
"""
const HELPER = Ref{Any}(run_program)

"Open the address `url` with the app that the Mac uses for it: a web page in the browser, and mailto: in the email app"
open_app(url) = (run(pipeline(`open $url`, stdout=devnull, stderr=devnull), wait=false); nothing)

"The function that opens a link of a page, given its address. A test puts a function of its own here."
const OPENER = Ref{Any}(open_app)

"Open the link of a page that goes to `url`"
open_link(url::AbstractString) = try OPENER[](url) catch; nothing end

"A rectangle of a page that's a link, in px from the page's top left corner, and where it goes"
const Link = @NamedTuple{left::Float64, top::Float64, wide::Float64, tall::Float64, url::String}

"""
A piece of the page's words that's drawn in one line, as web/select.jl has
it. WebKit's text file doesn't say what cuts the words, so each can be seen
anywhere on the page.
"""
const Words = Select.Words

"""
The pictures of a page: how wide and how tall the page is in px, each strip's
file with how tall it is, the page's links, and its words in the order that
the HTML has them.
"""
struct Shot
  wide::Int
  tall::Int
  strips::Vector{Pair{String,Int}}
  links::Vector{Link}
  words::Vector{Words}
end

"""
What the text file `path` says that the program made, as webpage.swift writes
it. It's nothing when the file says nothing that can be drawn, or one of its
strips is gone.
"""
shot(path) = begin
  isfile(path) || return nothing
  size, strips, links, pieces = nothing, Pair{String,Int}[], Link[], Words[]
  for line in eachline(path)
    parts = split(line, '\t')
    if parts[1] == "page" && length(parts) == 3
      size = (tryparse(Int, parts[2]), tryparse(Int, parts[3]))
    elseif parts[1] == "strip" && length(parts) == 3
      tall = tryparse(Int, parts[2])
      file = joinpath(dirname(path), parts[3])
      (tall === nothing || tall < 1 || !isfile(file)) && return nothing
      push!(strips, file => tall)
    elseif parts[1] == "link" && length(parts) == 6
      box = tryparse.(Float64, parts[2:5])
      any(isnothing, box) || push!(links, (left=box[1], top=box[2], wide=box[3], tall=box[4], url=String(parts[6])))
    elseif parts[1] == "text" && length(parts) == 6
      # A line that doesn't add up is left out, and the words go on without it
      top, tall = tryparse(Float64, parts[3]), tryparse(Float64, parts[4])
      edges = tryparse.(Float64, split(parts[5], ','))
      letters = collect(parts[6])
      (top === nothing || tall === nothing || any(isnothing, edges) || isempty(letters) || length(edges) != length(letters) + 1) && continue
      before = parts[2] == "line" ? "\n" : parts[2] == "tab" ? "\t" : ""
      push!(pieces, (before=before, top=top, tall=tall, edges=Float64.(edges), letters=letters, from=Select.letter_count(pieces), seen=Select.OPEN))
    end
  end
  (size === nothing || any(isnothing, size) || isempty(strips) || sum(last, strips) != size[2]) && return nothing
  Shot(size[1], size[2], strips, links, pieces)
end

"The link at the point `(x, y)` of the page, in px from the page's top left corner, or nothing"
link(s::Shot, x, y) = begin
  # A link that's written later is drawn over one that's written before it
  i = findlast(l -> l.left <= x <= l.left + l.wide && l.top <= y <= l.top + l.tall, s.links)
  i === nothing ? nothing : s.links[i]
end

"""
True when the HTML has a picture, a font or a style sheet from a web site, so
that it looks as its sender meant only with what the web has for it.
"""
remote(html) = occursin(r"<(img|link|input|video)\b[^>]*\b(src|href|poster)\s*=\s*[\"']?\s*https?://|\bbackground\s*=\s*[\"']?\s*https?://|url\(\s*[\"']?\s*https?://"i, html)

"""
How webpage.swift draws a page. Make it one more with a change to the program
that changes its pictures, so that the pictures it made before are made again.
2: a table that's wider than the page is let be as narrow as the page.
3: a short page is as tall as its content, not 600 px.
4: the program says where the page's words are.
"""
const DRAWS = 4

"The text file in `folder` that says what was made of `html` on a page `wide` px wide"
file(folder, html, wide, zoom, pictures) = joinpath(folder, string(hash((html, wide, zoom, pictures, DRAWS)), base=16) * ".txt")

"""
The pictures of `html` on a page `wide` px wide, kept in `folder`. `kept!` in
swift.jl says what the `state` is, and `shot(p.file)` reads what was made once
it's `:there`. `zoom` makes everything in the page that much bigger. With
`pictures`, the page gets its pictures from the web. Without `start`, nothing
is made that isn't kept already.
"""
picture!(folder, html, wide; zoom=1.0, pictures=false, start=true) = begin
  out = file(folder, html, wide, zoom, pictures)
  kept!(out; start, failed=FAILED, no_swift=NO_SWIFT) do part, err
    stem = chopsuffix(out, ".txt")
    source = stem * ".html"
    write(source, html)
    HELPER[](source, wide, zoom, pictures, stem, part, err)
  end
end

"""
Remove from `folder` each file that isn't part of the pictures whose text
file is `out`. A page's folder then keeps the pictures of the width that it
was last shown at, and no others.
"""
tidy!(folder, out) = begin
  stem = chopsuffix(basename(out), ".txt")
  foreach(f -> startswith(f, stem) || startswith(f, '.') || rm(joinpath(folder, f), force=true), readdir(folder))
end
