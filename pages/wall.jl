# A view that code makes. A `view` block that names this file shows a wall as
# a 3D model, as long and as high as the sums of its page say:
#
#     ```view
#     wall.jl
#     ```
#
# Ladder calls the function `view` with the page's sums, and again each time
# they change, as while you drag a number. Each sum that gives a name is there
# under that name, as a number in SI units. So a page with !`l = 16m` gives
# `sums["l"] == 16.0`. What `view` gives back here is the bytes of a .glb
# file, the kind of file that holds a 3D model with its colours. Ladder shows
# them in its model viewer. See welcome.md.

"The corners of the triangles of a box from the corner `lo` to the corner `hi`, three for each triangle. Each triangle faces out."
box(lo, hi) = begin
  points = NTuple{3,Float32}[]
  for a in 1:3, far in (false, true)
    b, c = a % 3 + 1, (a + 1) % 3 + 1
    corner(u, v) = ntuple(k -> Float32(k == a ? (far ? hi[k] : lo[k]) : k == b ? (u ? hi[k] : lo[k]) : (v ? hi[k] : lo[k])), 3)
    square = [corner(false, false), corner(true, false), corner(true, true), corner(false, true)]
    far || reverse!(square)
    append!(points, square[[1, 2, 3, 1, 3, 4]])
  end
  points
end

"The bytes of a .glb file that holds `parts`: each is the red, green and blue of a part, from 0 to 1, and the corners of its triangles"
glb(parts) = begin
  bin, meshes, materials, accessors, views = UInt8[], String[], String[], String[], String[]
  for (n, (colour, points)) in enumerate(parts)
    bytes = reinterpret(UInt8, points)
    lo, hi = reduce((a, b) -> min.(a, b), points), reduce((a, b) -> max.(a, b), points)
    push!(views, """{"buffer":0,"byteOffset":$(length(bin)),"byteLength":$(length(bytes))}""")
    push!(accessors, """{"bufferView":$(n - 1),"componentType":5126,"count":$(length(points)),"type":"VEC3","min":[$(join(lo, ","))],"max":[$(join(hi, ","))]}""")
    push!(materials, """{"pbrMetallicRoughness":{"baseColorFactor":[$(join(colour, ",")),1],"metallicFactor":0,"roughnessFactor":0.8}}""")
    push!(meshes, """{"primitives":[{"attributes":{"POSITION":$(n - 1)},"material":$(n - 1)}]}""")
    append!(bin, bytes)
  end
  nodes = join(("""{"mesh":$(n - 1)}""" for n in eachindex(parts)), ",")
  text = """{"asset":{"version":"2.0"},"scene":0,"scenes":[{"nodes":[$(join(0:length(parts)-1, ","))]}],"nodes":[$nodes],""" *
         """"meshes":[$(join(meshes, ","))],"materials":[$(join(materials, ","))],"accessors":[$(join(accessors, ","))],""" *
         """"bufferViews":[$(join(views, ","))],"buffers":[{"byteLength":$(length(bin))}]}"""
  # Each part of the file is a whole number of 4 bytes long
  text *= " "^((4 - sizeof(text) % 4) % 4)
  io = IOBuffer()
  write(io, 0x46546c67, UInt32(2), UInt32(28 + sizeof(text) + length(bin)))   # "glTF", the version, and how long the file is
  write(io, UInt32(sizeof(text)), 0x4e4f534a, text)                           # the text, in JSON
  write(io, UInt32(length(bin)), 0x004e4942, bin)                             # the numbers
  take!(io)
end

"""
The model of a wall that's `sums["l"]` metres long and `sums["h"]` metres
high, with a person 1.75 metres tall beside it, so that you can see how big it
is. A model has y up.
"""
view(sums) = begin
  long, high = clamp(Float64(get(sums, "l", 16.0)), 0.5, 500), clamp(Float64(get(sums, "h", 2.4)), 0.2, 100)
  glb([(0.72, 0.36, 0.26) => box((0, 0, 0), (long, high, 0.2)),
       (0.2, 0.3, 0.5) => box((long / 2 - 0.2, 0, 0.9), (long / 2 + 0.2, 1.75, 1.15))])
end
