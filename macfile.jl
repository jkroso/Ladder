# Asks macOS what it knows of a file: its NSURL resource values and dates,
# like when it was made and when it was added to its folder, the kind that
# the Finder calls it, and the site that it was downloaded from. desktop.jl,
# blog.jl and main.jl's folder pages use it.
#
#     date_of(path, "NSURLCreationDateKey")   # seconds since 1970, or nothing
#     made(path)                              # when the file was made, or mtime
#     added(path)                             # when the file came into its folder, or mtime
#     finder_kind(path)                       # "PNG image", as the Finder's Kind column says
#     site(path)                              # "github.com", the site that a downloaded file came from, or ""

@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg get_value nsstring jstring with_pool
@use "./web/url" site_name

const Object = Ptr{Cvoid}

"What macOS says of the file at `path` under `key`, one of the keys of an NSURL: an object, or C_NULL. Run inside `with_pool`."
resource(path, key) = begin
  Sys.isapple() || return C_NULL
  url = msg(cls("NSURL"), "fileURLWithPath:", nsstring(path))
  out = Ref{Object}(C_NULL)
  ok = ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Ref{Object}, Object, Object),
             url, sel("getResourceValue:forKey:error:"), out, nsstring(key), C_NULL)
  ok ? out[] : C_NULL
end

"What macOS says of the file at `path` under `key`, a key of an NSURL that names a date: the date in seconds, or nothing"
date_of(path, key) = begin
  Sys.isapple() || return nothing
  try
    with_pool() do
      val = resource(path, key)
      val != C_NULL ? get_value(Float64, val, "timeIntervalSince1970") : nothing
    end
  catch
    nothing
  end
end

"When the folder or the file at `path` came into the folder that it's in, as the Finder's Date Added. It's when it last changed where macOS doesn't say."
added(path::AbstractString) = something(date_of(path, "NSURLAddedToDirectoryDateKey"), Some(mtime(path)))

"When the folder or the file at `path` was made. It's when it last changed where macOS doesn't say."
made(path::AbstractString) = something(date_of(path, "NSURLCreationDateKey"), Some(mtime(path)))

"""
What the Finder calls the kind of the folder or the file at `path`, as its Kind
column says it: `Folder`, `PNG image`, `Markdown`, or the app that opens it, like
`Zed.app Document`. It's `Document` where macOS doesn't say. macOS answers in
about 0.1 ms.
"""
finder_kind(path::AbstractString) = begin
  Sys.isapple() || return isdir(path) ? "Folder" : "Document"
  try
    with_pool() do
      said = resource(path, "NSURLLocalizedTypeDescriptionKey")
      said != C_NULL ? jstring(said) : "Document"
    end
  catch
    "Document"
  end
end

# --- where a file came from ---------------------------------------------------------------

"The bytes that macOS keeps with the file at `path` under `name`, or nothing when it keeps none"
extra(path::AbstractString, name::AbstractString) = begin
  Sys.isapple() || return nothing
  n = ccall(:getxattr, Cssize_t, (Cstring, Cstring, Ptr{Cvoid}, Csize_t, UInt32, Cint), path, name, C_NULL, 0, 0, 0)
  n > 0 || return nothing
  data = Vector{UInt8}(undef, n)
  got = ccall(:getxattr, Cssize_t, (Cstring, Cstring, Ptr{UInt8}, Csize_t, UInt32, Cint), path, name, data, n, 0, 0)
  got == n ? data : nothing
end

"The texts of a list that macOS wrote as a property list in `data`"
texts(data::Vector{UInt8}) = begin
  found = String[]
  try
    with_pool() do
      d = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Ptr{UInt8}, UInt), cls("NSData"), sel("dataWithBytes:length:"), data, length(data))
      list = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Object, UInt, Object, Object),
                   cls("NSPropertyListSerialization"), sel("propertyListWithData:options:format:error:"), d, 0, C_NULL, C_NULL)
      (list != C_NULL && ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Object), list, sel("isKindOfClass:"), cls("NSArray"))) || return
      for i in 0:get_value(UInt, list, "count")-1
        item = ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), list, sel("objectAtIndex:"), i)
        ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Object), item, sel("isKindOfClass:"), cls("NSString")) && push!(found, jstring(item))
      end
    end
  catch
  end
  found
end

"The addresses that the file at `path` was downloaded from, as the browser wrote them: the file's own address, and the page that had the link"
sources(path::AbstractString) = (data = extra(path, "com.apple.metadata:kMDItemWhereFroms"); data === nothing ? String[] : texts(data))

"The site that the file at `path` was downloaded from: the site of the page that had the link, or else of the file's own address. It's \"\" for a file that wasn't downloaded."
site(path::AbstractString) = begin
  found = filter(!isempty, map(site_name, sources(path)))
  isempty(found) ? "" : last(found)
end
