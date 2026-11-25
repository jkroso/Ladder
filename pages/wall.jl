# A model that code makes. A `result` block that names this file shows a wall
# as a 3D model, as long and as high as the sums of its page say:
#
#     ```result
#     wall.jl
#     ```
#
# The file gets the names that the page's sums give, with their units. So a
# page with !`l = 16m` and !`h = 2.4m` gives it `l`, which is 16m, and `h`.
# The block shows what the last line comes to. Here that's the bytes of a .glb
# file, the kind of file that holds a 3D model with its colours, and Ladder
# shows them in its model viewer. It runs the file again each time the sums
# change, as while you drag a number. See welcome.md.

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

"A length in metres: 2.4m and 2.4 are both 2.4"
metres(x) = Float64(convert(Float64, x))

"""
The model of a wall that's `long` long and `high` high, with a person 1.75
metres tall beside it, so that you can see how big it is. A length has a unit,
like 16m, or is a number of metres. A model has y up.
"""
wall(long, high) = begin
  long, high = clamp(metres(long), 0.5, 500), clamp(metres(high), 0.2, 100)
  glb([(0.72, 0.36, 0.26) => box((0, 0, 0), (long, high, 0.2)),
       (0.2, 0.3, 0.5) => box((long / 2 - 0.2, 0, 0.9), (long / 2 + 0.2, 1.75, 1.15))])
end

# The wall of the page: l and h are its sums. While the app is built, this file
# is loaded with neither, so the call waits for a page.
ccall(:jl_generating_output, Cint, ()) == 1 || wall(l, h)
