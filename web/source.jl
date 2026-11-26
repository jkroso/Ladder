# Where the words of a page are in its HTML: the line and the column of the
# file that a place in the page's words comes from, for an agent that reads
# the file.
#
#     s = seen(html)            # the letters of the HTML that a page can show, with where each one is
#     p = shown(ws)             # the letters of the page's words `ws`, with the place of each
#     start(s, p, place)        # the byte of the HTML where the first letter at or after `place` starts, or nothing
#     finish(s, p, place)       # the byte of the HTML after the last letter before `place`, or nothing
#     line_column(html, byte)   # the line and the column of that byte, both counted from 1
#
# The engine keeps no link from the page's words back to its HTML, so the two
# are matched by the letters round the place. Spaces are left out, since a
# page shows its spaces as its CSS says, and so is the case of letters, since
# CSS can show them in capitals. Tags, comments, entities, and the text of
# what a page never shows as words (a <script>, a <style>, a <title>) are
# read as a browser reads them. The letters round a place have to be in the
# HTML as many times as in the page, so a place gets the HTML's copy of the
# same rank. Words that a script wrote, or that the HTML has more times than
# the page shows them, have no place. So a place is never a wrong one.

@use "./entities" entities

"Elements whose text a page doesn't show as words"
const UNSHOWN = ("script", "style", "title", "textarea", "template", "noscript", "xmp", "noembed", "noframes", "iframe", "desc")

"Letters that neither side counts: spaces, and those that draw nothing"
blank(c::Char) = isspace(c) || c in ('­', '​', '‌', '‍', '⁠', '﻿')

"The letters of an HTML file that a page can show, in lower case and with no spaces, and the bytes of the file that each one is from"
struct Seen
  letters::Vector{Char}
  from::Vector{Int}   # the first byte of what the letter is written as, like the & of an entity
  upto::Vector{Int}   # the byte after it
end

"The letters of a page's words in lower case and with no spaces, and the place of each in the words"
struct Shown
  letters::Vector{Char}
  places::Vector{Int}
end

"The byte after the end of the tag whose name ends before byte `i` of `html`, with what quotes hold in its attributes skipped"
tag_end(html, i) = begin
  n = ncodeunits(html)
  while i <= n
    c = codeunit(html, i)
    if c == UInt8('"') || c == UInt8('\'')
      j = findnext(==(c), codeunits(html), i + 1)
      i = j === nothing ? n + 1 : j + 1
    elseif c == UInt8('>')
      return i + 1
    else
      i += 1
    end
  end
  n + 1
end

"The letters of `html` that a page can show"
seen(html::AbstractString) = begin
  html = String(html)
  s = Seen(Char[], Int[], Int[])
  add(c, a, b) = blank(c) || (push!(s.letters, lowercase(c)); push!(s.from, a); push!(s.upto, b); nothing)
  i, n = 1, ncodeunits(html)
  while i <= n
    c = html[i]
    if c == '<'
      rest = SubString(html, i)
      if startswith(rest, "<!--")
        close = findnext("-->", html, i + 4)
        i = close === nothing ? n + 1 : last(close) + 1
      elseif startswith(rest, "<![CDATA[")
        close = findnext("]]>", html, i + 9)
        i = close === nothing ? n + 1 : last(close) + 1
      elseif startswith(rest, "<!") || startswith(rest, "<?")
        gt = findnext('>', html, i)
        i = gt === nothing ? n + 1 : gt + 1
      elseif (m = match(r"^</?([A-Za-z][^\s/>]*)", rest)) !== nothing
        name = lowercase(m[1])
        j = tag_end(html, i + ncodeunits(m.match))
        opens = codeunit(html, i + 1) != UInt8('/') && !(j - 2 >= i && codeunit(html, j - 2) == UInt8('/'))
        i = j
        # What such an element holds is never the page's words: go on after its end tag
        if opens && name in UNSHOWN
          close = findnext(Regex("</$name\\b[^>]*>?", "i"), html, min(i, n + 1))
          i = close === nothing ? n + 1 : last(close) + 1
        end
      else
        add(c, i, i + 1)
        i += 1
      end
    elseif c == '&'
      m = match(r"^&(#[0-9]+;?|#[xX][0-9a-fA-F]+;?|[A-Za-z][A-Za-z0-9]*;?)", SubString(html, i))
      decoded = m === nothing ? "&" : entities(m.match)
      if m === nothing || decoded == m.match
        add('&', i, i + 1)
        i += 1
      else
        for d in decoded
          add(d, i, i + ncodeunits(m.match))
        end
        i += ncodeunits(m.match)
      end
    else
      j = nextind(html, i)
      add(c, i, j)
      i = j
    end
  end
  s
end

"The letters of the page's words `ws`, as `seen` has those of its HTML"
shown(ws) = begin
  p = Shown(Char[], Int[])
  for w in ws, (k, c) in enumerate(w.letters)
    blank(c) || (push!(p.letters, lowercase(c)); push!(p.places, w.from + k - 1))
  end
  p
end

"Where `needle` starts in `hay`, each time that it's there"
hits(hay, needle) = begin
  out = Int[]
  m = length(needle)
  m == 0 && return out
  for i in 1:length(hay)-m+1
    hay[i] == needle[1] || continue
    all(j -> hay[i+j-1] == needle[j], 2:m) && push!(out, i)
  end
  out
end

# How many letters before and after a letter are matched, in the order that they're tried: the most first, then fewer,
# then only those on one side, for a letter near something that the page shows and its HTML doesn't have
const TRIES = ((60, 60), (30, 30), (0, 40), (40, 0), (12, 12), (0, 16), (16, 0))

"The letter of `s` that the letter `k` of `p` is, or nothing"
letter_of(s::Seen, p::Shown, k) = begin
  1 <= k <= length(p.letters) || return nothing
  for (back, ahead) in TRIES
    lo, hi = max(1, k - back), min(length(p.letters), k + ahead)
    hi - lo + 1 < min(8, length(p.letters)) && continue
    needle = view(p.letters, lo:hi)
    here, there = hits(p.letters, needle), hits(s.letters, needle)
    # The HTML has these letters as many times as the page shows them, so this copy is the HTML's of the same rank
    length(here) == length(there) || continue
    return there[findfirst(==(lo), here)] + (k - lo)
  end
  nothing
end

"The byte of the HTML where the first letter of the page at or after `place` starts, or nothing"
start(s::Seen, p::Shown, place) = (i = letter_of(s, p, searchsortedfirst(p.places, place)); i === nothing ? nothing : s.from[i])

"The byte of the HTML after the last letter of the page before `place`, or nothing"
finish(s::Seen, p::Shown, place) = (i = letter_of(s, p, searchsortedlast(p.places, place - 1)); i === nothing ? nothing : s.upto[i])

"The line of `html` that byte `i` is in, and its column: how many characters are before it in its line, plus 1"
line_column(html::AbstractString, i) = begin
  i = clamp(i, 1, ncodeunits(html) + 1)
  before = SubString(html, 1, prevind(html, i))
  line = count(==('\n'), before) + 1
  edge = findlast('\n', before)
  (line, length(SubString(before, edge === nothing ? 1 : nextind(before, edge))) + 1)
end
