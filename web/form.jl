# What a form of a page sends, and what its fields hold.
#
#     form(e)                  # the <form> that the element `e` is in, or nothing
#     sent(f, by; base)        # how the form sends, "get" or "post", and the address that it goes to
#     typed(e)                 # true for a field that takes text from the keyboard
#     value(e), value!(e, v)   # the text that such a field holds
#     tick!(e)                 # what a click does to a tick box or to one of a set of round buttons
#
# A form that sends with "get" writes what its fields hold at the end of its
# address, as `?q=julia&page=2`, and so it's a link like any other. This file
# sends nothing itself.

@use "./dom" Node Element Text attr text
@use "./url" resolve

"The kinds of <input> that take text from the keyboard"
const TYPED = ("text", "search", "email", "url", "tel", "password", "number", "")

"What kind of <input> `e` is, in lower case. One with no `type` is for text."
kind(e::Element) = lowercase(strip(attr(e, "type", "text")))

"True for a field that takes text from the keyboard: a <textarea>, or an <input> for text, that isn't turned off"
typed(e::Element) = (e.tag == "textarea" || (e.tag == "input" && kind(e) in TYPED)) && !haskey(e.attrs, "disabled") && !haskey(e.attrs, "readonly")
typed(::Any) = false

"True for a button that sends its form: a <button> that doesn't say otherwise, or an <input> of the kind `submit` or `image`"
sends(e::Element) = !haskey(e.attrs, "disabled") && (e.tag == "button" ? lowercase(strip(attr(e, "type", "submit"))) == "submit" :
                                                    e.tag == "input" && kind(e) in ("submit", "image"))
sends(::Any) = false

"The text that the field `e` holds"
value(e::Element) = e.tag == "textarea" ? replace(text(e), r"^\r?\n" => "") : attr(e, "value")

"Put the text `v` in the field `e`"
value!(e::Element, v::AbstractString) = begin
  if e.tag == "textarea"
    foreach(c -> c.parent = nothing, e.children)
    empty!(e.children)
    isempty(v) || push!(e.children, Text(String(v), e))
  else
    e.attrs["value"] = String(v)
  end
  e
end

"The nearest element with the tag `tag` that `e` is in, or `e` itself, or nothing"
within(e::Union{Element,Nothing}, tag) = begin
  while e !== nothing && e.tag != tag
    e = e.parent
  end
  e
end

"The <form> that `e` is in, or nothing"
form(e::Element) = within(e, "form")

"Each element under `top` that `ok` is true of, in the page's order"
under(ok, top::Element, found=Element[]) = begin
  for c in top.children
    c isa Element || continue
    ok(c) && push!(found, c)
    under(ok, c, found)
  end
  found
end

"""
What a click does to the tick box or the round button `e`: a tick box
changes, and a round button is chosen in place of the others of its name in
its form. True when `e` is one of those and it changed.
"""
tick!(e::Element) = begin
  (e.tag == "input" && !haskey(e.attrs, "disabled")) || return false
  if kind(e) == "checkbox"
    haskey(e.attrs, "checked") ? delete!(e.attrs, "checked") : (e.attrs["checked"] = "")
    return true
  end
  (kind(e) == "radio" && !haskey(e.attrs, "checked")) || return false
  name, top = attr(e, "name"), something(form(e), root(e))
  isempty(name) || foreach(o -> delete!(o.attrs, "checked"), under(o -> o.tag == "input" && kind(o) == "radio" && attr(o, "name") == name, top))
  e.attrs["checked"] = ""
  true
end

"The element at the top of the tree that `e` is in"
root(e::Element) = (while e.parent !== nothing; e = e.parent end; e)

"`s` as the end of an address writes it: a space is a +, and a character that means something in an address is its bytes in hexadecimal"
encoded(s::AbstractString) = begin
  io = IOBuffer()
  for b in codeunits(s)
    c = Char(b)
    b < 0x80 && (isletter(c) || isdigit(c) || c in "-_.*") ? write(io, b) : c == ' ' ? write(io, '+') : print(io, '%', uppercase(string(b, base=16, pad=2)))
  end
  String(take!(io))
end

"The names and the values that the fields of the form `f` send. `by` is the button that sent it, or nothing: only that button sends its own name."
fields(f::Element, by=nothing) = begin
  out = Pair{String,String}[]
  for e in under(e -> e.tag in ("input", "textarea", "select", "button"), f)
    name = attr(e, "name")
    (isempty(name) || haskey(e.attrs, "disabled")) && continue
    if e.tag == "select"
      options = under(o -> o.tag == "option", e)
      isempty(options) && continue
      o = options[something(findfirst(o -> haskey(o.attrs, "selected"), options), 1)]
      push!(out, name => (haskey(o.attrs, "value") ? attr(o, "value") : String(strip(text(o)))))
    elseif e.tag == "textarea"
      push!(out, name => value(e))
    elseif e.tag == "button" || kind(e) in ("submit", "image", "button", "reset")
      e === by && push!(out, name => attr(e, "value"))
    elseif kind(e) in ("checkbox", "radio")
      haskey(e.attrs, "checked") && push!(out, name => attr(e, "value", "on"))
    elseif kind(e) != "file"
      push!(out, name => attr(e, "value"))
    end
  end
  out
end

"""
How the form `f` sends, "get" or "post", and the address that it goes to.
`base` is the address of the page. For "get", the address ends with what the
form's fields hold. `by` is the button that sent the form, or nothing.
"""
sent(f::Element, by=nothing; base="") = begin
  said(name) = by !== nothing && haskey(by.attrs, "form" * name) ? attr(by, "form" * name) : attr(f, name)
  method = lowercase(strip(said("method"))) == "post" ? "post" : "get"
  action = String(strip(said("action")))
  to = isempty(action) ? String(base) : resolve(base, action)   # a form with no address sends to its own page
  method == "post" && return (method, to)
  # What the form sends takes the place of what the address asked before, and nothing follows a #
  to = String(first(split(to, r"[?#]", limit=2)))
  asks = join((encoded(k) * "=" * encoded(v) for (k, v) in fields(f, by)), "&")
  (method, isempty(asks) ? to : to * "?" * asks)
end

export form, sent, typed, sends, value, value!, tick!
