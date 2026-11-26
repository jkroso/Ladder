# A little XML reader: tags, attributes, text, comments, CDATA, and the
# entities that a DOCTYPE declares. It doesn't check that the XML is right.
# kate.jl reads Kate's syntax files with it, and feeds.jl RSS and Atom feeds.
#
#     root = parse_xml(text)        # the elements of the text, in an element with no name
#     element(root, "rss")          # the first element in `root` with that name, or nothing
#     elements(e, "item")           # all of them
#     text(e), e.attrs, e.children  # what's in an element

"An element of an XML file: its name, its attributes, and the elements and the text in it"
struct Element
  name::String
  attrs::Dict{String,String}
  children::Vector{Union{Element,String}}
end

"The elements in `e` named `name`"
elements(e::Element, name) = Element[c for c in e.children if c isa Element && c.name == name]

"The first element in `e` named `name`, or nothing"
element(e::Element, name) = (es = elements(e, name); isempty(es) ? nothing : es[1])

"The text in `e`"
text(e::Element) = join(c for c in e.children if c isa String)

"""
`s` with its references replaced: &amp; and the others of XML, &#37; and
&#x25;, and the entities that the file's DOCTYPE declares, which can refer to
other entities in turn.
"""
unescape(s::AbstractString, entities, depth=0) = begin
  occursin('&', s) || return String(s)
  io = IOBuffer()
  i = firstindex(s)
  while i <= lastindex(s)
    c = s[i]
    k = c == '&' ? findnext(';', s, i) : nothing
    name = k === nothing ? "" : s[nextind(s, i):prevind(s, k)]
    if k !== nothing && occursin(r"^#?[\w.-]+$", name)
      if startswith(name, "#x") || startswith(name, "#X")
        print(io, Char(parse(UInt32, name[3:end], base=16)))
      elseif startswith(name, "#")
        print(io, Char(parse(UInt32, name[2:end])))
      elseif haskey(XML_NAMED, name)
        print(io, XML_NAMED[name])
      elseif haskey(entities, name) && depth < 20
        print(io, unescape(entities[name], entities, depth + 1))
      else
        print(io, s[i:k])
      end
      i = nextind(s, k)
    else
      print(io, c)
      i = nextind(s, i)
    end
  end
  String(take!(io))
end

const XML_NAMED = Dict("amp" => '&', "lt" => '<', "gt" => '>', "quot" => '"', "apos" => '\'')

"""
The elements of the XML text `s`, in an element with no name: tags,
attributes, text, comments, CDATA, and the entities that a DOCTYPE declares.
It doesn't check that the XML is right.
"""
parse_xml(s::AbstractString) = begin
  b = Vector{UInt8}(codeunits(String(s)))
  n = length(b)
  str(a, z) = String(b[a:z])
  starts(i, t) = i + ncodeunits(t) - 1 <= n && view(b, i:i+ncodeunits(t)-1) == codeunits(t)
  find(i, t) = (k = i; while k + ncodeunits(t) - 1 <= n; starts(k, t) && return k; k += 1 end; n + 1)
  space(c) = c in (0x20, 0x09, 0x0a, 0x0d)
  entities = Dict{String,String}()
  root = Element("", Dict{String,String}(), [])
  stack = Element[root]
  i = 1
  while i <= n
    if starts(i, "<!--")
      i = find(i, "-->") + 3
    elseif starts(i, "<?")
      i = find(i, "?>") + 2
    elseif starts(i, "<![CDATA[")
      k = find(i, "]]>")
      push!(last(stack).children, str(i + 9, k - 1))
      i = k + 3
    elseif starts(i, "<!DOCTYPE")
      i += 9
      while i <= n && b[i] != UInt8('[') && b[i] != UInt8('>') i += 1 end
      if i <= n && b[i] == UInt8('[')
        # The declarations, up to ]: an entity is <!ENTITY name "value">
        i += 1
        while i <= n && b[i] != UInt8(']')
          if starts(i, "<!--")
            i = find(i, "-->") + 3
          elseif starts(i, "<!ENTITY")
            i += 8
            while i <= n && space(b[i]) i += 1 end
            a = i
            while i <= n && !space(b[i]) i += 1 end
            name = str(a, i - 1)
            while i <= n && b[i] != UInt8('"') && b[i] != UInt8('\'') i += 1 end
            q = i <= n ? b[i] : UInt8('"')
            z = i + 1
            while z <= n && b[z] != q z += 1 end
            entities[name] = str(i + 1, z - 1)
            i = find(z, ">") + 1
          else
            i += 1
          end
        end
      end
      i = find(i, ">") + 1
    elseif b[i] == UInt8('<') && i < n && b[i+1] == UInt8('/')
      length(stack) > 1 && pop!(stack)
      i = find(i, ">") + 1
    elseif b[i] == UInt8('<')
      k = i + 1
      while k <= n && !space(b[k]) && b[k] != UInt8('>') && b[k] != UInt8('/') k += 1 end
      el = Element(str(i + 1, k - 1), Dict{String,String}(), [])
      closed = false
      while k <= n
        while k <= n && space(b[k]) k += 1 end
        k > n && break
        if b[k] == UInt8('>')
          k += 1
          break
        elseif b[k] == UInt8('/')
          k = find(k, ">") + 1
          closed = true
          break
        end
        # An attribute: its name, = and a value in quotes, with spaces round the = in some files
        a = k
        while k <= n && b[k] != UInt8('=') && !space(b[k]) k += 1 end
        key = str(a, k - 1)
        while k <= n && (space(b[k]) || b[k] == UInt8('=')) k += 1 end
        k > n && break
        q = b[k]
        z = k + 1
        while z <= n && b[z] != q z += 1 end
        el.attrs[key] = unescape(str(k + 1, z - 1), entities)
        k = z + 1
      end
      push!(last(stack).children, el)
      closed || push!(stack, el)
      i = k
    else
      k = find(i, "<")
      t = str(i, k - 1)
      all(isspace, t) || push!(last(stack).children, unescape(t, entities))
      i = k
    end
  end
  root
end
