# Reads numbers from the text of table cells, with any mark before them or
# unit after them, like `$1,200`, `45%`, `2.4 m`, `1%/yr` or `22.4 billion USD`.
# chart.jl, csv.jl, filter.jl and forms.jl use it to tell which cells hold
# numbers and what those numbers are.
#
#     number("\$1,200")           # (1200.0, "\$", "")
#     number("22.4 billion USD")  # (2.24e10, "", " USD")
#     isnumber("45%")             # true

"Words that say how many thousands a number is, from the largest"
const SCALES = (("trillion", 1e12), ("billion", 1e9), ("million", 1e6), ("thousand", 1e3))

"Whether a unit goes right after its number, as % and %/yr and /yr do, with no space between them"
tight(unit::AbstractString) = startswith(unit, '%') || startswith(unit, '/')

"`x` times the thousand, million, billion or trillion at the front of `after`. That word comes off `after`."
scaled(x, after) = begin
  rest, low = lstrip(after), lowercase(lstrip(after))
  for (word, scale) in SCALES
    n = ncodeunits(word)
    (startswith(low, word) && (n == ncodeunits(low) || !isletter(low[n + 1]))) || continue
    tail = strip(rest[nextind(rest, n):end])
    return x * scale, isempty(tail) ? "" : startswith(tail, "%") ? tail : " " * tail
  end
  x, String(after)
end

"""
The number that a cell holds, with what's written before it and after it, or
nothing when the cell isn't a number. `\$1,200` is 1200 with a \$ before it,
`45%` is 45 with a % after it, `1%/yr` is 1 with %/yr after it, and `2.4 m`
is 2.4 with ` m` after it.
`22.4 billion USD` is 22.4 billion, and `100 million USD` is 100 million.
`2.6e-8%` is 2.6 × 10⁻⁸ with a % after it, as Julia writes a very small number.
"""
number(text::AbstractString) = begin
  s = replace(strip(text), r"^\*\*(.*)\*\*$" => s"\1", r"^`(.*)`$" => s"\1")
  m = match(r"^([-−–+]?)\s*([$€£¥]?)\s*((?:\d[\d,]*(?:\.\d+)?|\.\d+)(?:[eE][-+]?\d+)?)\s*(%|[^\d\s,.][^\d]{0,11})?$", s)
  m === nothing && return nothing
  x = parse(Float64, replace(m[3], "," => ""))
  after = m[4] === nothing ? "" : tight(m[4]) ? String(m[4]) : " " * m[4]
  x, after = scaled(x, after)
  (m[1] in ("-", "−", "–") ? -x : x, String(m[2]), after)
end

"True when the cell `text` is a number, like 12, -4.5, \$4,200, 15% or 12 L"
isnumber(text::AbstractString) = number(text) !== nothing
