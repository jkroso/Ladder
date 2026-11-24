# JSON, as the hidden SolidCraft program speaks it. engine.jl sends each
# request as one line of JSON and gets each answer as one line.
#
#     parse("{\"a\": [1, 2.5, null]}")   # Dict("a" => Any[1.0, 2.5, nothing])
#     json(Dict("a" => [1, "x"]))         # "{\"a\":[1,\"x\"]}"
#
# An object is a `Dict{String,Any}`, a list a `Vector{Any}`, and every number
# a `Float64`: SolidCraft's numbers are lengths, and its counts are small.

const Object = Dict{String,Any}

"Thrown when text isn't JSON, with where it stops being JSON"
struct NotJSON <: Exception
  at::Int
  why::String
end
Base.showerror(io::IO, e::NotJSON) = print(io, "This isn't JSON at byte $(e.at): $(e.why)")

"What the JSON in `text` holds"
parse(text::AbstractString) = begin
  d = codeunits(text)
  value, i = read_value(d, blank(d, 1))
  blank(d, i) > length(d) || throw(NotJSON(i, "there's more after the value"))
  value
end

blank(d, i) = begin
  while i <= length(d) && d[i] in (0x20, 0x0a, 0x0d, 0x09)
    i += 1
  end
  i
end

byte(d, i) = i <= length(d) ? d[i] : throw(NotJSON(i, "it stops early"))

read_value(d, i) = begin
  c = byte(d, i)
  c == UInt8('{') ? read_object(d, i + 1) :
  c == UInt8('[') ? read_list(d, i + 1) :
  c == UInt8('"') ? read_string(d, i + 1) :
  c == UInt8('t') ? word(d, i, "true", true) :
  c == UInt8('f') ? word(d, i, "false", false) :
  c == UInt8('n') ? word(d, i, "null", nothing) : read_number(d, i)
end

word(d, i, name, value) = begin
  n = ncodeunits(name)
  (i + n - 1 <= length(d) && view(d, i:i+n-1) == codeunits(name)) || throw(NotJSON(i, "an unknown word"))
  value, i + n
end

read_number(d, i) = begin
  j = i
  while j <= length(d) && (d[j] in UInt8('0'):UInt8('9') || d[j] in (UInt8('-'), UInt8('+'), UInt8('.'), UInt8('e'), UInt8('E')))
    j += 1
  end
  x = tryparse(Float64, String(d[i:j-1]))
  x === nothing && throw(NotJSON(i, "a number is expected"))
  x, j
end

read_object(d, i) = begin
  o = Object()
  i = blank(d, i)
  byte(d, i) == UInt8('}') && return o, i + 1
  while true
    byte(d, i) == UInt8('"') || throw(NotJSON(i, "a key is expected"))
    key, i = read_string(d, i + 1)
    i = blank(d, i)
    byte(d, i) == UInt8(':') || throw(NotJSON(i, "a key has no value"))
    o[key], i = read_value(d, blank(d, i + 1))
    i = blank(d, i)
    c = byte(d, i)
    c == UInt8('}') && return o, i + 1
    c == UInt8(',') || throw(NotJSON(i, "a comma is expected"))
    i = blank(d, i + 1)
  end
end

read_list(d, i) = begin
  l = Any[]
  i = blank(d, i)
  byte(d, i) == UInt8(']') && return l, i + 1
  while true
    v, i = read_value(d, i)
    push!(l, v)
    i = blank(d, i)
    c = byte(d, i)
    c == UInt8(']') && return l, i + 1
    c == UInt8(',') || throw(NotJSON(i, "a comma is expected"))
    i = blank(d, i + 1)
  end
end

hex(d, i) = Base.parse(UInt16, String(d[i:i+3]), base=16)

read_string(d, i) = begin
  from = i
  # Most strings have no \, and are the bytes as they are
  while byte(d, i) != UInt8('"') && d[i] != UInt8('\\')
    i += 1
  end
  d[i] == UInt8('"') && return String(d[from:i-1]), i + 1
  io = IOBuffer()
  write(io, view(d, from:i-1))
  while true
    c = byte(d, i)
    if c == UInt8('"')
      return String(take!(io)), i + 1
    elseif c == UInt8('\\')
      e = byte(d, i + 1)
      i += 2
      if e == UInt8('u')
        byte(d, i + 3)
        u = UInt32(hex(d, i))
        i += 4
        # Two \u in a row can be the two halves of one character
        if 0xd800 <= u <= 0xdbff && i + 5 <= length(d) && d[i] == UInt8('\\') && d[i+1] == UInt8('u')
          low = UInt32(hex(d, i + 2))
          0xdc00 <= low <= 0xdfff && (u = 0x10000 + ((u - 0xd800) << 10) + (low - 0xdc00); i += 6)
        end
        print(io, Char(u))
      else
        write(io, e == UInt8('n') ? '\n' : e == UInt8('t') ? '\t' : e == UInt8('r') ? '\r' : e == UInt8('b') ? '\b' : e == UInt8('f') ? '\f' : Char(e))
      end
    else
      write(io, c)
      i += 1
    end
  end
end

"`value` as JSON on one line"
json(value) = sprint(write_json, value)

write_json(io::IO, ::Nothing) = print(io, "null")
write_json(io::IO, b::Bool) = print(io, b)
write_json(io::IO, n::Integer) = print(io, n)
write_json(io::IO, x::AbstractFloat) = isfinite(x) ? (x == round(x) && abs(x) < 1e15 ? print(io, Int64(x)) : print(io, Float64(x))) : print(io, "null")
write_json(io::IO, s::Symbol) = write_json(io, String(s))
write_json(io::IO, s::AbstractString) = begin
  print(io, '"')
  for c in s
    c == '"' ? print(io, "\\\"") : c == '\\' ? print(io, "\\\\") : c == '\n' ? print(io, "\\n") : c == '\r' ? print(io, "\\r") :
    c == '\t' ? print(io, "\\t") : c < ' ' ? print(io, "\\u", string(UInt16(c), base=16, pad=4)) : print(io, c)
  end
  print(io, '"')
end
write_json(io::IO, l::Union{AbstractVector,Tuple}) = begin
  print(io, '[')
  for (i, v) in enumerate(l)
    i > 1 && print(io, ',')
    write_json(io, v)
  end
  print(io, ']')
end
write_json(io::IO, o::Union{AbstractDict,NamedTuple}) = begin
  print(io, '{')
  first = true
  for (k, v) in pairs(o)
    first || print(io, ',')
    first = false
    write_json(io, String(k))
    print(io, ':')
    write_json(io, v)
  end
  print(io, '}')
end
