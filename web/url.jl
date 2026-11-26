# Web addresses: turning a link into a whole address from a page's address,
# telling whether text is a web address, and reading the name of its server
# and of its site.
# Used by web/, remote.jl, linkcard.jl, save.jl, sites.jl and macfolders.jl.
#
#     resolve("https://example.com/a/b.html", "../c.png")   # "https://example.com/c.png"
#     isurl("https://example.com/api")                      # true
#     host("https://api.example.com:8443/v1")               # "api.example.com"
#     site_name("https://www.GitHub.com/jkroso")            # "github.com"

"The path `p` with each `.` and `..` of it worked out"
normal(p) = begin
  cut = findfirst(in("?#"), p)
  path, rest = cut === nothing ? (p, "") : (p[1:prevind(p, cut)], p[cut:end])
  out = String[]
  parts = split(path, '/')
  for (i, part) in enumerate(parts)
    part == "." ? (i == length(parts) && push!(out, "")) : part == ".." ? (length(out) > 1 && pop!(out); i == length(parts) && push!(out, "")) : push!(out, part)
  end
  join(out, '/') * rest
end

"The whole address that `url` means in a page or a sheet at the address `base`"
resolve(base::AbstractString, url::AbstractString) = begin
  url = String(strip(url))
  (isempty(base) || isempty(url) || occursin(r"^[a-zA-Z][a-zA-Z0-9+.-]*:", url)) && return url
  m = match(r"^([a-zA-Z][a-zA-Z0-9+.-]*:)(//[^/?#]*)?([^?#]*)(\?[^#]*)?", base)
  m === nothing && return url
  scheme, server, path, query = m[1], something(m[2], ""), m[3], something(m[4], "")
  startswith(url, "//") && return scheme * url
  startswith(url, '#') && return scheme * server * path * query * url
  startswith(url, '?') && return scheme * server * path * url
  startswith(url, '/') && return scheme * server * normal(url)
  dir = (i = findlast('/', path)) === nothing ? "/" : path[1:i]
  scheme * server * normal(dir * url)
end

"True when `to` is a web address"
isurl(to) = occursin(r"^https?://"i, strip(to))

"The name of the server in the web address `url`, like example.com"
host(url) = (m = match(r"^https?://(?:[^@/?#]*@)?([^/?#:]+|\[[^\]]*\])"i, strip(url)); m === nothing ? String(strip(url)) : String(m[1]))

"The name of the site of the address `url`, in small letters and with no www. at its start, like github.com, or \"\" when it has none"
site_name(url::AbstractString) = begin
  m = match(r"^[a-z][a-z0-9+.-]*://(?:[^/?#@]*@)?([^/?#:@]+)"i, url)
  m === nothing ? "" : String(replace(lowercase(m[1]), r"^www\." => ""))
end
