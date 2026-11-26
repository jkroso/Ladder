# JSON: reading it and writing it, so that Ladder needs no package for it.
#
#     json_value(bytes)          # what the JSON holds, as it's written
#     parse(text)                # what the JSON holds, as plain values
#     json(value)                # `value` as JSON on one line
#     write_json(io, value, 0)   # `value` as JSON, each key or item on a line of its own
#
# The two readers read the same grammar. They differ only in what they give
# for an object and a number. `json_value` keeps an object's keys in the order
# that the JSON has them, in a JSONObject, and a number's text, in a
# JSONNumber: so 1.50 stays 1.50, and a long number keeps its digits. main.jl
# shows a JSON file as it is with them. `parse` gives an `Object`, which is a
# Dict, for each object, and a Float64 for each number. The design editor
# (cad/), Centient's server and YouTube's answers use that.
#
# Text that isn't JSON throws a NotJSON, which says where it stops being JSON.
# Some programs start a file with a mark that says it's UTF-8. It isn't part of
# the JSON, and both readers pass over it.

"An object of JSON, as `parse` gives it"
const Object = Dict{String,Any}

"An object of JSON, as `json_value` gives it: its keys and their values, in the order that the JSON has them"
struct JSONObject
  keys::Vector{String}
  values::Vector{Any}
end

"A number of JSON, as the JSON writes it. So 3 is 3, 1.50 is 1.50, and a long number loses no digits."
struct JSONNumber
  text::String
end

"Thrown when text isn't JSON, with the byte where it stops being JSON"
struct NotJSON <: Exception
  at::Int
  why::String
end
Base.showerror(io::IO, e::NotJSON) = print(io, "This isn't JSON at byte $(e.at): $(e.why)")

"""
What the JSON in `data`, its bytes or its text, holds: a JSONObject, a list,
a string, a JSONNumber, true, false or nothing.
"""
json_value(data::AbstractVector{UInt8}) = read_all(data, false)
json_value(text::AbstractString) = json_value(codeunits(text))

"""
What the JSON in `text`, or its bytes, holds as plain values: an `Object` for
each object, a `Vector{Any}` for each list, and a Float64 for each number.
"""
parse(text::AbstractString) = read_all(codeunits(text), true)
parse(data::AbstractVector{UInt8}) = read_all(data, true)

"The one value of JSON in the bytes `d`, as `plain` values or as they're written"
read_all(d, plain) = begin
  i = length(d) >= 3 && d[1] == 0xef && d[2] == 0xbb && d[3] == 0xbf ? 4 : 1
  value, i = read_value(d, blank(d, i), plain)
  blank(d, i) > length(d) || throw(NotJSON(i, "there's more after the value"))
  value
end

"The place of the first byte at or after `i` that isn't a space or a line break"
blank(d, i) = begin
  while i <= length(d) && d[i] in (0x20, 0x0a, 0x0d, 0x09)
    i += 1
  end
  i
end

"Byte `i` of `d`. It's a NotJSON if the JSON stops before it."
byte(d, i) = i <= length(d) ? d[i] : throw(NotJSON(i, "it stops early"))

"The value that starts at byte `i` of `d`, and the place of the byte after it"
read_value(d, i, plain) = begin
  c = byte(d, i)
  c == UInt8('{') ? read_object(d, i + 1, plain) :
  c == UInt8('[') ? read_list(d, i + 1, plain) :
  c == UInt8('"') ? read_string(d, i + 1) : read_word(d, i, plain)
end

"The object whose keys start at byte `i` of `d`, after its {, and the place of the byte after its }"
read_object(d, i, plain) = begin
  o = plain ? Object() : JSONObject(String[], Any[])
  i = blank(d, i)
  if byte(d, i) != UInt8('}')
    while true
      byte(d, i) == UInt8('"') || throw(NotJSON(i, "a key is expected"))
      key, i = read_string(d, i + 1)
      i = blank(d, i)
      byte(d, i) == UInt8(':') || throw(NotJSON(i, "a key has no value"))
      value, i = read_value(d, blank(d, i + 1), plain)
      add!(o, key, value)
      i = blank(d, i)
      c = byte(d, i)
      c == UInt8('}') && break
      c == UInt8(',') || throw(NotJSON(i, "a comma or a } is expected"))
      i = blank(d, i + 1)
    end
  end
  o, i + 1
end

"Give the object `o` the key `key` with `value`. A key that a Dict has already gets the new value."
add!(o::JSONObject, key, value) = (push!(o.keys, key); push!(o.values, value))
add!(o::Object, key, value) = (o[key] = value)

"The list whose items start at byte `i` of `d`, after its [, and the place of the byte after its ]"
read_list(d, i, plain) = begin
  list = Any[]
  i = blank(d, i)
  byte(d, i) == UInt8(']') && return list, i + 1
  while true
    value, i = read_value(d, i, plain)
    push!(list, value)
    i = blank(d, i)
    c = byte(d, i)
    c == UInt8(']') && return list, i + 1
    c == UInt8(',') || throw(NotJSON(i, "a comma or a ] is expected"))
    i = blank(d, i + 1)
  end
end

"A number as JSON writes it"
const NUMBER = r"^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$"

"true, false, null or the number at byte `i` of `d`, and the place of the byte after it"
read_word(d, i, plain) = begin
  j = i
  while j <= length(d) && !(d[j] in (UInt8(','), UInt8('}'), UInt8(']'), 0x20, 0x0a, 0x0d, 0x09))
    j += 1
  end
  j == i && throw(NotJSON(i, "a value is expected"))
  word = String(d[i:j-1])
  word == "true" ? (true, j) : word == "false" ? (false, j) : word == "null" ? (nothing, j) :
    occursin(NUMBER, word) ? ((plain ? Base.parse(Float64, word) : JSONNumber(word)), j) :
    throw(NotJSON(i, "$(repr(first(word, 20))) is where a value should be"))
end

"The string whose text starts at byte `i` of `d`, after its \", and the place of the byte after its closing \""
read_string(d, i) = begin
  j = i
  # Most strings have no \ in them, and are their bytes as they are
  while (c = byte(d, j)) != UInt8('"') && c != UInt8('\\')
    j += 1
  end
  d[j] == UInt8('"') && return String(d[i:j-1]), j + 1
  out = IOBuffer()
  write(out, view(d, i:j-1))
  while (c = byte(d, j)) != UInt8('"')
    if c == UInt8('\\')
      x = byte(d, j + 1)
      j += 2
      if x == UInt8('u')
        n, j = read_hex(d, j)
        # A character past U+FFFF is written as two halves
        if 0xd800 <= n < 0xdc00 && j + 1 <= length(d) && d[j] == UInt8('\\') && d[j+1] == UInt8('u')
          low, k = read_hex(d, j + 2)
          0xdc00 <= low < 0xe000 && ((n, j) = (0x10000 + ((n - 0xd800) << 10) + (low - 0xdc00), k))
        end
        # Half of one on its own is no character
        print(out, 0xd800 <= n < 0xe000 ? '�' : Char(n))
      else
        write(out, x == UInt8('n') ? UInt8('\n') : x == UInt8('t') ? UInt8('\t') : x == UInt8('r') ? UInt8('\r') :
                   x == UInt8('b') ? UInt8('\b') : x == UInt8('f') ? UInt8('\f') : x)
      end
    else
      write(out, c)
      j += 1
    end
  end
  String(take!(out)), j + 1
end

"The number that the four hexadecimal digits at byte `i` of `d` write, and the place of the byte after them"
read_hex(d, i) = begin
  i + 3 <= length(d) || throw(NotJSON(i, "it stops early"))
  n = tryparse(UInt32, String(d[i:i+3]), base=16)
  n === nothing && throw(NotJSON(i, "\\u needs four hexadecimal digits"))
  n, i + 4
end

"`value` as JSON on one line"
json(value) = sprint(write_json, value)

"""
Write `value` as JSON. With no `depth` it's on one line. With a `depth`, an
object or a list has each key or item on a line of its own, `depth + 1` steps
of two spaces in, and a key has a space after its colon: `write_json(io, x, 0)`.

A whole Float64 is written as a whole number, so 3.0 is 3. A number that isn't
finite is null, since JSON has no way to write it. A JSONNumber is its text.
"""
write_json(io::IO, ::Nothing, depth=nothing) = print(io, "null")
write_json(io::IO, b::Bool, depth=nothing) = print(io, b)
write_json(io::IO, n::Integer, depth=nothing) = print(io, n)
write_json(io::IO, x::Real, depth=nothing) = begin
  x = Float64(x)
  !isfinite(x) ? print(io, "null") : x == round(x) && abs(x) < 1e15 ? print(io, Int64(x)) : print(io, x)
end
write_json(io::IO, n::JSONNumber, depth=nothing) = print(io, n.text)
write_json(io::IO, s::Symbol, depth=nothing) = write_json(io, String(s))
write_json(io::IO, s::AbstractString, depth=nothing) = begin
  print(io, '"')
  for c in s
    c == '"' ? print(io, "\\\"") : c == '\\' ? print(io, "\\\\") : c == '\n' ? print(io, "\\n") :
    c == '\r' ? print(io, "\\r") : c == '\t' ? print(io, "\\t") :
    isvalid(c) && c < ' ' ? print(io, "\\u", string(UInt32(c), base=16, pad=4)) : print(io, c)
  end
  print(io, '"')
end
write_json(io::IO, l::Union{AbstractVector,Tuple}, depth=nothing) =
  write_items(io, '[', ']', ((nothing, x) for x in l), depth)
write_json(io::IO, o::Union{JSONObject,AbstractDict,NamedTuple}, depth=nothing) =
  write_items(io, '{', '}', ((string(k), x) for (k, x) in entries(o)), depth)

"The keys and the values of an object, in its order"
entries(o::JSONObject) = zip(o.keys, o.values)
entries(o) = pairs(o)

"Write the items of a list, whose keys are nothing, or the keys and values of an object, between `open` and `close`"
write_items(io, open, close, items, depth) = begin
  print(io, open)
  n = 0
  for (key, x) in items
    n += 1
    n > 1 && print(io, ',')
    depth === nothing || print(io, '\n', "  "^(depth + 1))
    key === nothing || (write_json(io, key); print(io, depth === nothing ? ":" : ": "))
    write_json(io, x, depth === nothing ? nothing : depth + 1)
  end
  n > 0 && depth !== nothing && print(io, '\n', "  "^depth)
  print(io, close)
end
