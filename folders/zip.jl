# What a zip file holds, apart from the window that shows it. A zip file ends
# with a list of its files: each one's name, its size, when it changed and
# where its bytes start. This file reads that list, so Ladder shows what's
# inside without unpacking the file, and it unpacks one file when you ask for it.
#
#     z = contents("plans.zip")          # Zip(entries=[Entry(name="plans/house.pdf", size=48213, ...), ...])
#     under(z, "plans/")                 # the folders and files of the folder plans/
#     bytes(z.path, z.entries[1])        # the bytes of plans/house.pdf
#     keep(z.path, z.entries[1], dir)    # write it under the folder `dir`, and give its path
#
# The Finder puts files of its own in a zip file that it makes: a folder
# called `__MACOSX`, and `.DS_Store` files. They're left out, as the Finder
# leaves them out when it unpacks the file.
#
# A file's bytes are packed with the method "deflate", which the Mac's own
# zlib unpacks, or they aren't packed. A file that's locked with a password,
# or packed another way, is listed, and `bytes` throws for it.

@use "github.com/jkroso/Prospects.jl" @def

"A file or a folder of a zip file"
@def struct Entry
  name::String = ""        # its path in the zip file, with / between folders. A folder's ends with /.
  size::Int = 0            # how many bytes it has when it's unpacked
  packed::Int = 0          # and how many it takes in the zip file
  changed::Float64 = 0.0   # when it last changed
  method::Int = 0          # how it's packed: 0 for not at all, 8 for deflate
  locked::Bool = false     # it needs a password
  at::Int = 0              # where its part of the zip file starts
end

"What a zip file holds: its entries, in the order of their names with each folder before what's in it"
@def struct Zip
  path::String = ""
  entries::Vector{Entry} = Entry[]
  size::Int = 0     # the bytes of its files when they're unpacked
end

isfolder(en::Entry) = endswith(en.name, '/')

"Thrown when a file isn't a zip file that this reads, with the reason in words"
struct NotZip <: Exception
  why::String
end
Base.showerror(io::IO, e::NotZip) = print(io, e.why)

u16(b, i) = Int(b[i]) | Int(b[i+1]) << 8
u32(b, i) = u16(b, i) | u16(b, i + 2) << 16
u64(b, i) = u32(b, i) | u32(b, i + 4) << 32

"The time that a zip file writes as two numbers, a date and a time of day, in the Mac's own time zone"
dos_time(date, time) = begin
  tm = Libc.TmStruct((time & 0x1f) * 2, (time >> 5) & 0x3f, (time >> 11) & 0x1f,
                     max(date & 0x1f, 1), max((date >> 5) & 0x0f, 1) - 1, ((date >> 9) & 0x7f) + 80, 0, 0, -1)
  Float64(ccall(:mktime, Int, (Ref{Libc.TmStruct},), tm))
end

"A name of a zip file as text. An old zip file writes it in a set of 256 characters, which is read as Latin-1 when it isn't UTF-8."
name_text(bytes) = (s = String(copy(bytes)); isvalid(s) ? s : String(Char.(bytes)))

"True for an entry that the Finder adds to a zip file for itself"
finders(name) = startswith(name, "__MACOSX/") || basename(rstrip(name, '/')) == ".DS_Store"

"The most entries that are read. A zip file with more gives its first ones."
const MOST = 100_000

"""
What the zip file at `path` holds. Each folder that a file is in is an entry,
whether the zip file lists it or not. It throws a `NotZip` when the file isn't
a zip file.
"""
contents(path::AbstractString) = begin
  total = filesize(path)
  total >= 22 || throw(NotZip("The file is too short to be a zip file."))
  entries = Entry[]
  open(path) do io
    # The list's end is the last thing in the file, before a comment of no more than 65535 bytes
    back = min(total, 22 + 65535)
    seek(io, total - back)
    tail = read(io, back)
    at = findlast(i -> tail[i] == 0x50 && tail[i+1] == 0x4b && tail[i+2] == 0x05 && tail[i+3] == 0x06, 1:length(tail)-21)
    at === nothing && throw(NotZip("The file has no list of what it holds, so it isn't a zip file."))
    count, bytes, start = u16(tail, at + 10), u32(tail, at + 12), u32(tail, at + 16)
    if count == 0xffff || bytes == 0xffffffff || start == 0xffffffff
      # A big zip file has a second end with wider numbers, and a note before the first end that says where it is
      at >= 21 && u32(tail, at - 20) == 0x07064b50 || throw(NotZip("The zip file's list is damaged."))
      seek(io, u64(tail, at - 12))
      big = read(io, 56)
      (length(big) == 56 && u32(big, 1) == 0x06064b50) || throw(NotZip("The zip file's list is damaged."))
      count, bytes, start = u64(big, 33), u64(big, 41), u64(big, 49)
    end
    (start + bytes <= total) || throw(NotZip("The zip file's list is damaged."))
    seek(io, start)
    list = read(io, bytes)
    i = 1
    for _ in 1:min(count, MOST)
      (i + 45 <= length(list) && u32(list, i) == 0x02014b50) || break
      flags, method = u16(list, i + 8), u16(list, i + 10)
      packed, size = u32(list, i + 20), u32(list, i + 24)
      n, m, k = u16(list, i + 28), u16(list, i + 30), u16(list, i + 32)
      offset = u32(list, i + 42)
      i + 45 + n + m + k <= length(list) || break
      name = name_text(@view list[i+46:i+45+n])
      # Wider numbers for a big file are in a part of the extra bytes, in this order, each only if its short form is full
      j, stop = i + 46 + n, i + 45 + n + m
      while j + 3 <= stop
        id, len = u16(list, j), u16(list, j + 2)
        if id == 0x0001
          q = j + 4
          size == 0xffffffff && q + 7 <= stop && (size = u64(list, q); q += 8)
          packed == 0xffffffff && q + 7 <= stop && (packed = u64(list, q); q += 8)
          offset == 0xffffffff && q + 7 <= stop && (offset = u64(list, q))
        end
        j += 4 + len
      end
      i += 46 + n + m + k
      name = replace(name, '\\' => '/')
      (isempty(name) || finders(name) || startswith(name, '/') || ".." in split(name, '/')) && continue
      push!(entries, Entry(name=name, size=size, packed=packed, changed=dos_time(u16(list, i - 46 - n - m - k + 14), u16(list, i - 46 - n - m - k + 12)),
                           method=method, locked=flags & 1 == 1, at=offset))
    end
  end
  # A folder that the zip file doesn't list has an entry too, so each file has its folders above it
  have = Set(en.name for en in entries)
  for en in copy(entries)
    parts = split(rstrip(en.name, '/'), '/')
    for d in 1:length(parts)-1
      dir = join(parts[1:d], '/') * "/"
      dir in have || (push!(have, dir); push!(entries, Entry(name=dir)))
    end
  end
  sort!(entries, by=en -> lowercase.(split(rstrip(en.name, '/'), '/')))
  unique!(en -> en.name, entries)
  Zip(path=String(path), entries=entries, size=sum(en.size for en in entries; init=0))
end

"The folders and then the files of the zip file `z` that are in the folder `dir`, like `plans/`, or at the top with \"\""
under(z::Zip, dir::AbstractString="") = begin
  inside(en) = startswith(en.name, dir) && en.name != dir && !occursin('/', rstrip(en.name[nextind(en.name, 0, length(dir) + 1):end], '/'))
  found = filter(inside, z.entries)
  [filter(isfolder, found); filter(!isfolder, found)]
end

"How many files the zip file `z` holds, without its folders"
files(z::Zip) = count(!isfolder, z.entries)

"How deep the entry is: 0 at the top of the zip file, 1 in a folder there"
depth(en::Entry) = count(==('/'), rstrip(en.name, '/'))

"The entry's own name, without the folders that it's in"
short(en::Entry) = String(basename(rstrip(en.name, '/')))

# --- the bytes of one file --------------------------------------------------------------

const libz = "/usr/lib/libz.1.dylib"

# What zlib keeps of one run, as its C header lays it out
mutable struct Stream
  next_in::Ptr{UInt8}
  avail_in::Cuint
  total_in::Culong
  next_out::Ptr{UInt8}
  avail_out::Cuint
  total_out::Culong
  msg::Ptr{UInt8}
  state::Ptr{Cvoid}
  zalloc::Ptr{Cvoid}
  zfree::Ptr{Cvoid}
  opaque::Ptr{Cvoid}
  data_type::Cint
  adler::Culong
  reserved::Culong
end

"Unpack `packed`, bytes that deflate packed, into `size` bytes"
inflate(packed::Vector{UInt8}, size::Integer) = begin
  out = Vector{UInt8}(undef, size)
  s = Stream(C_NULL, 0, 0, C_NULL, 0, 0, C_NULL, C_NULL, C_NULL, C_NULL, C_NULL, 0, 0, 0)
  GC.@preserve packed out begin
    s.next_in, s.avail_in = pointer(packed), length(packed)
    s.next_out, s.avail_out = pointer(out), length(out)
    # -15 is for bytes with nothing of zlib's own before them, as a zip file has them
    ccall((:inflateInit2_, libz), Cint, (Ref{Stream}, Cint, Cstring, Cint), s, -15, "1.2.11", sizeof(Stream)) == 0 ||
      error("zlib didn't start.")
    code = ccall((:inflate, libz), Cint, (Ref{Stream}, Cint), s, 4)
    ccall((:inflateEnd, libz), Cint, (Ref{Stream},), s)
    # 1 is the end of the packed bytes. With no byte to write, zlib can say -5 at the end.
    (code == 1 || (size == 0 && code == -5)) || error("The file's bytes are damaged.")
  end
  resize!(out, s.total_out)
end

"The biggest file that `bytes` unpacks: half a gigabyte"
const BIGGEST = 500_000_000

"The bytes of the file `en` of the zip file at `path`. It throws when the file is locked, is packed in a way that this doesn't read, or is bigger than `BIGGEST`."
bytes(path::AbstractString, en::Entry) = begin
  isfolder(en) && error("$(en.name) is a folder.")
  en.locked && error("$(short(en)) is locked with a password.")
  en.method in (0, 8) || error("$(short(en)) is packed in a way that Ladder doesn't read.")
  en.size <= BIGGEST || error("$(short(en)) is too big to show from inside the zip file.")
  open(path) do io
    seek(io, en.at)
    head = read(io, 30)
    (length(head) == 30 && u32(head, 1) == 0x04034b50) || error("The zip file is damaged at $(short(en)).")
    skip(io, u16(head, 27) + u16(head, 29))
    packed = read(io, en.packed)
    length(packed) == en.packed || error("The zip file ends before $(short(en)) does.")
    en.method == 0 ? packed : inflate(packed, en.size)
  end
end

"""
Write the file `en` of the zip file at `path` under the folder `dir`, in the
folders that it has in the zip file, and give its path. The file can't be
changed there, since a change wouldn't go into the zip file. A file that's
there from an earlier time, and as new as the zip file, is kept.
"""
keep(path::AbstractString, en::Entry, dir::AbstractString) = begin
  to = joinpath(dir, split(en.name, '/')...)
  isfile(to) && mtime(to) >= mtime(path) && filesize(to) == en.size && return to
  data = bytes(path, en)
  mkpath(dirname(to))
  isfile(to) && (chmod(to, 0o644); rm(to))
  write(to, data)
  chmod(to, 0o444)
  to
end

"A size in bytes in a few characters, like `48 KB`, as the Finder writes it"
size_words(n::Integer) =
  n < 1000 ? "$n bytes" :
  n < 1_000_000 ? "$(round(Int, n / 1000)) KB" :
  n < 1_000_000_000 ? "$(round(n / 1_000_000, digits=1)) MB" : "$(round(n / 1_000_000_000, digits=2)) GB"
