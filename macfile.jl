# Asks macOS for a file's NSURL resource values and dates: when a file was
# made, when it was added to its folder, and any other resource value by its
# NSURL key. desktop.jl, macfolders.jl and blog.jl use it.
#
#     date_of(path, "NSURLCreationDateKey")   # seconds since 1970, or nothing
#     made(path)                              # when the file was made, or mtime
#     added(path)                             # when the file came into its folder, or mtime

@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg get_value nsstring with_pool

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
