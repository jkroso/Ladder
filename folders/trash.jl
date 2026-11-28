# Where each thing in the Trash came from, and putting it back there. main.jl
# shows the Trash as a folder, with Put Back in the right-click menu.
#
#     origins(trash())            # "plan.pdf" => Origin("/Users/jake/Desktop", "plan.pdf"), for each thing in the Trash
#     put_back!(path, origin)     # move it from the Trash to where it was
#
# The Finder writes where each thing in the Trash came from in the Trash's
# `.DS_Store` file. `records` reads that file's format: a tree of records, each
# with a file's name, four letters that say what the record is, and a value.
# The record `ptbL` has the folder that the file was in, from the top of its
# disk, and `ptbN` has the name that it had there.

@use "github.com/jkroso/Prospects.jl" @def

"The folder of the Trash of the disk that the home folder is on"
trash() = joinpath(homedir(), ".Trash")

"Where something in the Trash came from: the folder that it was in, and the name that it had there"
@def struct Origin
  folder::String = ""
  name::String = ""
end

be32(b, i) = Int(b[i]) << 24 | Int(b[i+1]) << 16 | Int(b[i+2]) << 8 | Int(b[i+3])
utf16(b, i, n) = transcode(String, [UInt16(b[i+2k]) << 8 | UInt16(b[i+2k+1]) for k in 0:n-1])

"""
The records of a `.DS_Store` file whose bytes are `b`: the file that each is
about, the four letters that say what it is, and its value. A value is text, a
number, or bytes. It throws when the bytes aren't such a file.
"""
records(b::Vector{UInt8}) = begin
  (length(b) > 36 && be32(b, 1) == 1 && b[5:8] == codeunits("Bud1")) || error("Not a .DS_Store file")
  # Every place in the file is counted from its fifth byte
  info = be32(b, 9) + 4
  count = be32(b, info + 1)
  addresses = [be32(b, info + 9 + 4k) for k in 0:count-1]
  # A block's address has its size in its last five bits
  block(id) = (addresses[id+1] & ~31) + 4
  at = info + 9 + 4 * 256 * cld(max(count, 1), 256)
  tree = -1
  for _ in 1:be32(b, at)
    n = Int(b[at+4])
    name = String(b[at+5:at+4+n])
    id = be32(b, at + 5 + n)
    name == "DSDB" && (tree = id)
    at += 5 + n
  end
  tree >= 0 || error("The .DS_Store file has no tree")
  found = Tuple{String,String,Any}[]
  # A record, at `i`: it gives where the next thing starts
  record(i) = begin
    n = be32(b, i)
    file = utf16(b, i + 4, n)
    i += 4 + 2n
    id, kind = String(b[i:i+3]), String(b[i+4:i+7])
    i += 8
    value, i = kind in ("long", "shor") ? (be32(b, i), i + 4) :
               kind == "bool" ? (b[i] != 0, i + 1) :
               kind == "blob" ? (len = be32(b, i); (b[i+4:i+3+len], i + 4 + len)) :
               kind == "type" ? (String(b[i:i+3]), i + 4) :
               kind == "ustr" ? (len = be32(b, i); (utf16(b, i + 4, len), i + 4 + 2len)) :
               kind in ("comp", "dutc") ? (b[i:i+7], i + 8) : error("A record of the kind $kind")
    push!(found, (file, id, value))
    i
  end
  # A node of the tree: its records, with the nodes under it between them
  node(id, deep) = begin
    deep > 32 && error("The .DS_Store file's tree is too deep")
    i = block(id) + 1
    last, n = be32(b, i), be32(b, i + 4)
    i += 8
    for _ in 1:n
      last == 0 || (node(be32(b, i), deep + 1); i += 4)
      i = record(i)
    end
    last == 0 || node(last, deep + 1)
  end
  node(be32(b, block(tree) + 1), 0)
  found
end

"""
Where each thing in the Trash folder `dir` came from, by its name in the
Trash, as the Finder wrote it in the folder's `.DS_Store` file. A thing that
the Finder wrote nothing about isn't there. `disk` is the top folder of the
disk that the Trash is on.
"""
origins(dir::AbstractString=trash(); disk::AbstractString="/") = begin
  found = Dict{String,Origin}()
  recs = try records(read(joinpath(dir, ".DS_Store"))) catch; return found end
  folders, names = Dict{String,String}(), Dict{String,String}()
  for (file, id, value) in recs
    value isa String || continue
    id == "ptbL" && (folders[file] = value)
    id == "ptbN" && (names[file] = value)
  end
  for (file, folder) in folders
    found[file] = Origin(folder=plain(String(rstrip(joinpath(disk, folder), '/'))), name=get(names, file, file))
  end
  found
end

# The Finder can write a folder of the Mac's own disk from the place that macOS keeps the disk's data at
const DATA = "/System/Volumes/Data"

"The path `path` without the place that macOS keeps the data of its own disk at, which the Finder can write before a folder"
plain(path::AbstractString) = startswith(path, DATA * "/") ? String(path[length(DATA)+1:end]) : String(path)

"A path in the folder `dir` for something called `name` that nothing has yet: `name`, or else `name` with 2, 3 and so on before its ending"
free(dir::AbstractString, name::AbstractString) = begin
  path = joinpath(dir, name)
  base, ending = splitext(name)
  n = 2
  while ispath(path)
    path = joinpath(dir, "$base $n$ending")
    n += 1
  end
  path
end

"""
Move the folder or the file at `path` out of the Trash, back to where
`origin` says it was, and give its new path. When something else has its
name there now, it gets a number after its name. It throws when the folder
that it was in is gone.
"""
put_back!(path::AbstractString, origin::Origin) = begin
  isdir(origin.folder) || error("The folder that it was in, $(origin.folder), isn't there any more.")
  to = free(origin.folder, origin.name)
  mv(path, to)
  to
end
