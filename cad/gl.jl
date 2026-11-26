# The picture of a design, drawn by the graphics card.
#
# A `Stage` is an OpenGL context of macOS that draws off the screen, as
# web/gl.jl has one for each WebGL canvas. The editor gives it the eye and a
# list of things to draw, and gets back the pixels:
#
#     stage = Stage()
#     pixels = picture!(stage, 1600, 1000, eye, [Solid(...), Lines(...), Sheet(...)], background)
#
# A `Solid` is a body's triangles with light on them. `Lines` are the edges of
# bodies, the grid and the axes: each line is drawn as a thin rectangle that
# faces the eye, because OpenGL on a Mac draws no line wider than a pixel. A
# `Sheet` is flat triangles of one colour that show what's behind them: a
# plane, or a closed region of a sketch. A body in front hides it.
#
# The pixels come as red, green, blue and alpha bytes, a row at a time from the
# top. A stage that shares the context of the window it's shown in, as
# `Stage(share)` does, can leave them on the graphics card instead
# (`picture!(...; read=false)`), and the window's context shows them from
# there: see `over!`. Each thing keeps its corners on the graphics card under its `key`, so a
# body that didn't change costs nothing to draw again. Give a thing a new key
# when its corners change.
#
# The context that was current, like the window's, is current again when
# `picture!` returns, because the editor calls it in the middle of drawing
# the window.

@use ModernGL...
@use "./scene" Eye axes place Vec3 dot

const GL = "/System/Library/Frameworks/OpenGL.framework/OpenGL"

current() = ccall((:CGLGetCurrentContext, GL), Ptr{Cvoid}, ())
setcurrent(c) = ccall((:CGLSetCurrentContext, GL), Int32, (Ptr{Cvoid},), c)

# The OpenGL contexts of stages that Julia has freed. Julia can run a finalizer
# in the middle of drawing the window, or on another thread, so the finalizer
# only lists the context. `destroy_gone!` destroys it later, as web/gl.jl does.
const GONE = Ptr{Cvoid}[]
const GOING = Threads.SpinLock()

"Destroy the contexts of the stages that Julia has freed, except one that's current"
destroy_gone!() = begin
  isempty(GONE) && return
  lock(GOING)
  gone = copy(GONE)
  empty!(GONE)
  unlock(GOING)
  now = current()
  for c in gone
    if c == now
      lock(GOING)
      push!(GONE, c)
      unlock(GOING)
    else
      ccall((:CGLDestroyContext, GL), Int32, (Ptr{Cvoid},), c)
    end
  end
  nothing
end

const Colour = NTuple{4,Float32}

"Triangles with light on them. `data` has 7 numbers for each corner: where it is, the way the surface faces there, and the number of its face."
struct Solid
  key::Any
  data::Vector{Float32}
  colour::Colour
  painted::Vector{Pair{Int,Colour}}   # the faces that have a colour of their own in place of the body's
  lit::Vector{Pair{Int,Colour}}       # the faces that have a colour over their own, like the face under the mouse
  through::Bool                       # is it drawn so that what's behind it shows through?
  bare::Bool                          # only its `lit` faces are drawn: the body itself doesn't show
end
Solid(key, data, colour; painted=Pair{Int,Colour}[], lit=Pair{Int,Colour}[], through=colour[4] < 1, bare=false) = Solid(key, data, colour, painted, lit, through, bare)

"Flat triangles of one colour, with no light on them. `data` has 3 numbers for each corner: where it is."
struct Sheet
  key::Any
  data::Vector{Float32}
  colour::Colour
end

"Lines. `data` has 6 numbers for each: where it starts and where it ends."
struct Lines
  key::Any
  data::Vector{Float32}
  colour::Colour
  width::Float32                  # in pixels of the picture
  hidden::Bool                    # false: it shows through the bodies in front of it
  fade::NTuple{5,Float32}         # it fades out between two distances from a point: the point, then the distances. (0, 0, 0, 0, 0) for none.
  cut::Bool                       # the picture's cut takes away the part of it that's on the eye's side, as it does of every solid
end
Lines(key, data, colour, width; hidden=true, fade=(0f0, 0f0, 0f0, 0f0, 0f0), cut=false) = Lines(key, data, colour, Float32(width), hidden, fade, cut)

mutable struct Kept
  vao::UInt32
  buffer::UInt32
  count::Int32
  used::Int
end

mutable struct Stage
  cgl::Ptr{Cvoid}
  wide::Int
  high::Int
  fbo::UInt32            # what's read
  colour::UInt32
  msfbo::UInt32          # what's drawn into, with 4 samples for each pixel
  mscolour::UInt32
  msdepth::UInt32
  solid::UInt32          # the two programs
  lines::UInt32
  kept::Dict{Any,Kept}
  frame::Int
  pixels::Vector{UInt8}
end

const SOLID_V = """
#version 410 core
layout(location = 0) in vec3 p;
layout(location = 1) in vec3 n;
layout(location = 2) in float face;
uniform mat4 mvp;
uniform mat3 look;
out vec3 facing;
out vec3 world;
out float away;
flat out float of;
void main() {
  gl_Position = mvp * vec4(p, 1.0);
  facing = look * n;
  world = p;
  away = gl_Position.w;
  of = face;
}
"""

# How far a point is in the depth buffer. When far things look smaller, it's the logarithm of the point's distance from the eye:
# the usual depth is fine just in front of the eye and coarse far away, so faces 2 mm apart (the satellite's cells and the
# film behind them) took turns to show once the eye came close to part of a big design. `away` is the distance, along the
# eye's line of sight, and `depth.x` is 1 / log2(1 + the farthest distance), or 0 for the usual depth.
# `depth.yz` moves the depth back as `glPolygonOffset` does, which has no effect on a depth that a shader writes:
# by `depth.y` times how fast the depth changes across the pixel, and by `depth.z` of the smallest step.
const DEPTH = """
float depth_of(float away, vec3 depth) {
  float d = depth.x > 0.0 ? log2(1.0 + max(away, 0.0)) * depth.x : gl_FragCoord.z;
  return d + depth.y * max(abs(dFdx(d)), abs(dFdy(d))) + depth.z * 1.2e-7;
}
"""

const SOLID_F = """
#version 410 core
in vec3 facing;
in vec3 world;
in float away;
flat in float of;
uniform vec4 tint;
uniform float only;
uniform float plain;
uniform vec4 cuts[2];
uniform vec2 cap;
uniform vec3 depth;
out vec4 colour;
$DEPTH
void main() {
  // Before any discard, since the slope needs the pixels round this one
  gl_FragDepth = depth_of(away, depth);
  if (only >= 0.0 && abs(of - only) > 0.5) discard;
  // What's on the side that a plane that cuts the picture faces doesn't show. A plane that cuts nothing is (0, 0, 0, -1).
  for (int i = 0; i < 2; i++) if (dot(world, cuts[i].xyz) + cuts[i].w > 0.0) discard;
  // The face of a cut (see `cap!`) is flat, in the body's colour, with hatch lines `cap.y` pixels apart, or none for 0
  if (cap.x > 0.5) {
    float hatch = cap.y > 0.0 && mod(gl_FragCoord.x + gl_FragCoord.y, cap.y) < max(cap.y * 0.2, 1.0) ? 0.62 : 1.0;
    colour = vec4(tint.rgb * hatch, tint.a);
    return;
  }
  vec3 n = normalize(facing);
  if (n.z < 0.0) n = -n;
  // A lamp over the eye, and a weaker one to its left, so that the top of a block is brighter than its sides and the sides differ
  float light = 0.58 + 0.27 * max(dot(n, vec3(0.0, 0.898, 0.44)), 0.0) + 0.12 * max(dot(n, vec3(-0.6, 0.0, 0.8)), 0.0);
  colour = vec4(tint.rgb * mix(light, 1.0, plain), tint.a);
}
"""

const LINES_V = """
#version 410 core
layout(location = 0) in vec3 a;
layout(location = 1) in vec3 b;
layout(location = 2) in vec2 corner;
uniform mat4 mvp;
uniform vec2 view;
uniform float width;
uniform vec3 lift;
out vec3 world;
out float away;
void main() {
  vec4 ca = mvp * vec4(a, 1.0), cb = mvp * vec4(b, 1.0);
  float eps = 1e-4;
  if (ca.w < eps && cb.w < eps) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); world = a; away = 1.0; return; }
  if (ca.w < eps) ca = mix(cb, ca, (cb.w - eps) / (cb.w - ca.w));
  if (cb.w < eps) cb = mix(ca, cb, (ca.w - eps) / (ca.w - cb.w));
  vec2 sa = ca.xy / ca.w * view * 0.5, sb = cb.xy / cb.w * view * 0.5;
  vec2 d = sb - sa;
  float l = length(d);
  d = l > 0.0 ? d / l : vec2(1.0, 0.0);
  vec2 across = vec2(-d.y, d.x);
  vec4 c = corner.x < 0.5 ? ca : cb;
  c.xy += across * corner.y * width * 0.5 / (view * 0.5) * c.w;
  // A line on a face is drawn a little nearer than it is, so that the face doesn't hide it: lift.x of its distance
  // from the eye. lift.y says whether far things look smaller, and lift.z is what the depth has that doesn't follow distance.
  if (lift.y > 0.5) { c.z = (c.z - lift.z) * (1.0 - lift.x) + lift.z; c.xyw *= 1.0 - lift.x; }
  else c.z -= lift.x * 2.0;
  gl_Position = c;
  away = c.w;
  world = corner.x < 0.5 ? a : b;
}
"""

const LINES_F = """
#version 410 core
in vec3 world;
in float away;
uniform vec4 tint;
uniform vec3 fade_at;
uniform vec2 fade;
uniform vec4 cuts[2];
uniform vec3 depth;
out vec4 colour;
$DEPTH
void main() {
  gl_FragDepth = depth_of(away, depth);
  for (int i = 0; i < 2; i++) if (dot(world, cuts[i].xyz) + cuts[i].w > 0.0) discard;
  colour = tint;
  if (fade.y > 0.0) colour.a *= 1.0 - smoothstep(fade.x, fade.y, distance(world, fade_at));
}
"""

shader(kind, source) = begin
  s = glCreateShader(kind)
  glShaderSource(s, 1, [pointer(source)], C_NULL)
  glCompileShader(s)
  ok = Ref{GLint}(0)
  glGetShaderiv(s, GL_COMPILE_STATUS, ok)
  if ok[] == 0
    log = Vector{UInt8}(undef, 2048)
    n = Ref{GLsizei}(0)
    glGetShaderInfoLog(s, 2048, n, log)
    error("A shader of the design's picture didn't compile: " * String(log[1:n[]]))
  end
  s
end

program(vertex, fragment) = begin
  p = glCreateProgram()
  glAttachShader(p, shader(GL_VERTEX_SHADER, vertex))
  glAttachShader(p, shader(GL_FRAGMENT_SHADER, fragment))
  glLinkProgram(p)
  ok = Ref{GLint}(0)
  glGetProgramiv(p, GL_LINK_STATUS, ok)
  ok[] == 0 && error("The shaders of the design's picture didn't link.")
  p
end

made(f) = (n = Ref{GLuint}(0); f(1, n); n[])

"""
A place to draw designs, or nothing when macOS can't make an OpenGL context.

`share` is another context, like the one that a window is drawn with. The
stage then uses that context's own kind of pixels, and the two have the
same renderbuffers: the window can show the stage's picture with no copy
through the CPU. See `over!`.
"""
Stage(share::Ptr{Cvoid}=C_NULL) = begin
  destroy_gone!()
  ctx = Ref{Ptr{Cvoid}}(C_NULL)
  if share == C_NULL
    attrs = Int32[99, 0x4100, 73, 96, 0]   # OpenGL 4.1, on the graphics card, which can be one that shows no screen
    pix, n = Ref{Ptr{Cvoid}}(C_NULL), Ref{Int32}(0)
    ccall((:CGLChoosePixelFormat, GL), Int32, (Ptr{Int32}, Ref{Ptr{Cvoid}}, Ref{Int32}), attrs, pix, n) == 0 && pix[] != C_NULL || return nothing
    failed = ccall((:CGLCreateContext, GL), Int32, (Ptr{Cvoid}, Ptr{Cvoid}, Ref{Ptr{Cvoid}}), pix[], C_NULL, ctx)
    ccall((:CGLReleasePixelFormat, GL), Cvoid, (Ptr{Cvoid},), pix[])
  else
    # The other context keeps its kind of pixels, so it isn't released here
    pix = ccall((:CGLGetPixelFormat, GL), Ptr{Cvoid}, (Ptr{Cvoid},), share)
    pix == C_NULL && return nothing
    failed = ccall((:CGLCreateContext, GL), Int32, (Ptr{Cvoid}, Ptr{Cvoid}, Ref{Ptr{Cvoid}}), pix, share, ctx)
  end
  (failed == 0 && ctx[] != C_NULL) || return nothing
  # A context that was destroyed can leave its address to this one, with places of uniforms that aren't this one's
  filter!(p -> p.first[1] != ctx[], PLACES)
  s = Stage(ctx[], 0, 0, 0, 0, 0, 0, 0, 0, 0, Dict{Any,Kept}(), 0, UInt8[])
  was = current()
  setcurrent(s.cgl)
  try
    s.solid = program(SOLID_V, SOLID_F)
    s.lines = program(LINES_V, LINES_F)
  finally
    setcurrent(was)
  end
  finalizer(s) do s
    s.cgl == C_NULL && return
    lock(GOING)
    push!(GONE, s.cgl)
    unlock(GOING)
    s.cgl = C_NULL
  end
end

"Give the stage a picture of `w` by `h` pixels"
size!(s::Stage, w, h) = begin
  (s.wide, s.high) == (w, h) && return
  s.wide, s.high = w, h
  s.fbo == 0 && (s.fbo = made(glGenFramebuffers); s.colour = made(glGenRenderbuffers);
                 s.msfbo = made(glGenFramebuffers); s.mscolour = made(glGenRenderbuffers); s.msdepth = made(glGenRenderbuffers))
  glBindRenderbuffer(GL_RENDERBUFFER, s.colour)
  glRenderbufferStorage(GL_RENDERBUFFER, GL_RGBA8, w, h)
  glBindFramebuffer(GL_FRAMEBUFFER, s.fbo)
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, s.colour)
  glBindRenderbuffer(GL_RENDERBUFFER, s.mscolour)
  glRenderbufferStorageMultisample(GL_RENDERBUFFER, 4, GL_RGBA8, w, h)
  glBindRenderbuffer(GL_RENDERBUFFER, s.msdepth)
  # With a stencil, which counts the faces of a body in front of each pixel: see `cap!`
  glRenderbufferStorageMultisample(GL_RENDERBUFFER, 4, GL_DEPTH32F_STENCIL8, w, h)
  glBindFramebuffer(GL_FRAMEBUFFER, s.msfbo)
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, s.mscolour)
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_STENCIL_ATTACHMENT, GL_RENDERBUFFER, s.msdepth)
  resize!(s.pixels, 4w * h)
  nothing
end

"""
The 16 numbers that take a point of the design to its place in a picture of
`w` by `h` pixels, as OpenGL reads them, the 9 that turn a way of facing
to the eye's own axes, and what the lines' shader needs to draw a line a little nearer. `reach` is how far from the eye's target things can be
and still show. The picture's rows come out from the top.
"""
matrices(e::Eye, w, h, reach) = begin
  right, up, back = axes(e)
  eye = place(e)
  view = [right[1] right[2] right[3] -dot(right, eye);
          up[1] up[2] up[3] -dot(up, eye);
          back[1] back[2] back[3] -dot(back, eye);
          0 0 0 1.0]
  aspect = w / h
  far = e.distance + reach
  if e.wide > 0
    # The depth is a logarithm (see DEPTH), so a near plane close to the eye costs nothing far away
    near = max(e.distance - reach, e.distance * 0.02, far * 1e-7)
    f = 1 / tand(e.wide / 2)
    proj = [f/aspect 0 0 0; 0 -f 0 0; 0 0 (far+near)/(near-far) 2far*near/(near-far); 0 0 -1 0]
  else
    near = e.distance - reach
    proj = [2/(e.distance*aspect) 0 0 0; 0 -2/e.distance 0 0; 0 0 -2/(far-near) -(far+near)/(far-near); 0 0 0 1.0]
  end
  # A loop of its own multiplies the two. `*` would call BLAS, which isn't there while the app is built, so
  # the build crashed as it drew the welcome page's design.
  both = [sum(proj[i, k] * view[k, j] for k in 1:4) for i in 1:4, j in 1:4]
  (Float32.(vec(both)), Float32[right[1], up[1], back[1], right[2], up[2], back[2], right[3], up[3], back[3]],
   (LIFT, e.wide > 0 ? 1f0 : 0f0, Float32(proj[3, 4]), e.wide > 0 ? Float32(1 / log2(1 + far)) : 0f0))
end

"Give the program `p` its depth: `lift[4]` from `matrices`, then how far back it goes, as `glPolygonOffset` takes it"
depth!(p, lift, slope=0f0, steps=0f0) = glUniform3f(uniform(p, "depth"), lift[4], slope, steps)

const LIFT = 4f-4   # how much nearer than it is a line is drawn, as a part of its distance from the eye

const CORNERS = Float32[0 -1; 1 -1; 1 1; 0 -1; 1 1; 0 1]

"The corners of `t` on the graphics card, made when its key is first seen"
kept!(s::Stage, t) = begin
  k = get(s.kept, t.key, nothing)
  if k === nothing
    vao, buffer = made(glGenVertexArrays), made(glGenBuffers)
    glBindVertexArray(vao)
    glBindBuffer(GL_ARRAY_BUFFER, buffer)
    if t isa Solid
      glBufferData(GL_ARRAY_BUFFER, sizeof(t.data), t.data, GL_STATIC_DRAW)
      for (i, (n, from)) in enumerate(((3, 0), (3, 12), (1, 24)))
        glEnableVertexAttribArray(i - 1)
        glVertexAttribPointer(i - 1, n, GL_FLOAT, GL_FALSE, 28, Ptr{Cvoid}(from))
      end
      k = Kept(vao, buffer, length(t.data) ÷ 7, s.frame)
    elseif t isa Sheet
      # As a solid's corners are, each with a way of facing and a face that the shader makes no use of
      n = length(t.data) ÷ 3
      data = zeros(Float32, 7n)
      for i in 0:n-1
        copyto!(data, 7i + 1, t.data, 3i + 1, 3)
        data[7i+6] = 1f0
      end
      glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW)
      for (i, (m, from)) in enumerate(((3, 0), (3, 12), (1, 24)))
        glEnableVertexAttribArray(i - 1)
        glVertexAttribPointer(i - 1, m, GL_FLOAT, GL_FALSE, 28, Ptr{Cvoid}(from))
      end
      k = Kept(vao, buffer, n, s.frame)
    else
      # Each line is two triangles, whose six corners each know both ends of the line
      n = length(t.data) ÷ 6
      data = Vector{Float32}(undef, 48n)
      for i in 0:n-1, c in 1:6
        at = 48i + 8(c - 1)
        copyto!(data, at + 1, t.data, 6i + 1, 6)
        data[at+7], data[at+8] = CORNERS[c, 1], CORNERS[c, 2]
      end
      glBufferData(GL_ARRAY_BUFFER, sizeof(data), data, GL_STATIC_DRAW)
      for (i, (m, from)) in enumerate(((3, 0), (3, 12), (2, 24)))
        glEnableVertexAttribArray(i - 1)
        glVertexAttribPointer(i - 1, m, GL_FLOAT, GL_FALSE, 32, Ptr{Cvoid}(from))
      end
      k = Kept(vao, buffer, 6n, s.frame)
    end
    s.kept[t.key] = k
  end
  k.used = s.frame
  k
end

"Where each uniform of each program is, by the context, the program and the uniform's name. OpenGL took a third of a µs to find one, and a design with 80 bodies asked 1,300 times a picture."
const PLACES = Dict{Tuple{Ptr{Cvoid},UInt32,String},GLint}()

uniform(p, name) = get!(() -> glGetUniformLocation(p, name), PLACES, (current(), UInt32(p), name))

const NO_CUT = (0f0, 0f0, 0f0, -1f0)

"""
How the picture is cut: the planes that cut it, two at most (the plane of a
sketch's Slice, and a Section's), and the one whose cut shows a face where it
opens a body. A plane is `(a, b, c, d)`, and what has `a x + b y + c z + d > 0`
doesn't show.
"""
struct Cutting
  planes::Vector{Float32}       # two planes, four numbers each
  list::Vector{Any}             # the same planes, each as a point on it and the way it faces
  capped::Any                   # the one of them whose cut has a face, or nothing
  hatch::Float32                # how far apart the hatch lines of that face are, in pixels, or 0 for none
end
const UNCUT = Cutting(Float32[NO_CUT..., NO_CUT...], Any[], nothing, 0f0)

"The planes of `planes`, four numbers each, as the shaders take two of them"
plane_numbers(planes) = begin
  out = Float32[]
  for c in planes
    length(out) < 8 && append!(out, (Float32.(c[2])..., Float32(-dot(c[1], c[2]))))
  end
  while length(out) < 8
    append!(out, NO_CUT)
  end
  out
end

"Give the program `p` the planes that cut the picture"
cuts!(p, c::Cutting) = glUniform4fv(uniform(p, "cuts"), 2, c.planes)

draw!(s::Stage, t::Solid, mvp, look, lift, cut=UNCUT) = begin
  k = kept!(s, t)
  k.count == 0 && return
  p = s.solid
  glUseProgram(p)
  cuts!(p, cut)
  glUniform2f(uniform(p, "cap"), 0f0, 0f0)
  glUniformMatrix4fv(uniform(p, "mvp"), 1, GL_FALSE, mvp)
  glUniformMatrix3fv(uniform(p, "look"), 1, GL_FALSE, look)
  glBindVertexArray(k.vao)
  glEnable(GL_DEPTH_TEST)
  glDepthFunc(GL_LEQUAL)
  # A body that shows through goes a little further back, so that a solid on its surface, like a piece that a fillet takes away, shows in front of it
  depth!(p, lift, t.through ? 3f0 : 1f0, t.through ? 4f0 : 1f0)
  glDepthMask(t.through ? GL_FALSE : GL_TRUE)
  glUniform1f(uniform(p, "plain"), 0f0)
  if !t.bare
    glUniform4f(uniform(p, "tint"), t.colour...)
    glUniform1f(uniform(p, "only"), -1f0)
    glDrawArrays(GL_TRIANGLES, 0, k.count)
    # A face with a colour of its own is drawn again in that colour, just in front of the body's
    depth!(p, lift, 0.5f0, 0.5f0)
    for (face, colour) in t.painted
      glUniform4f(uniform(p, "tint"), colour...)
      glUniform1f(uniform(p, "only"), Float32(face))
      glDrawArrays(GL_TRIANGLES, 0, k.count)
    end
  end
  # A face with a colour over its own is drawn once more, in front of both
  glDepthMask(GL_FALSE)
  depth!(p, lift)
  for (face, colour) in t.lit
    glUniform4f(uniform(p, "tint"), colour...)
    glUniform1f(uniform(p, "only"), Float32(face))
    glUniform1f(uniform(p, "plain"), 0.55f0)
    glDrawArrays(GL_TRIANGLES, 0, k.count)
  end
  glDepthMask(GL_TRUE)
end

draw!(s::Stage, t::Sheet, mvp, look, lift, cut=UNCUT) = begin
  k = kept!(s, t)
  k.count == 0 && return
  p = s.solid
  glUseProgram(p)
  cuts!(p, UNCUT)
  glUniform2f(uniform(p, "cap"), 0f0, 0f0)
  glUniformMatrix4fv(uniform(p, "mvp"), 1, GL_FALSE, mvp)
  glUniformMatrix3fv(uniform(p, "look"), 1, GL_FALSE, look)
  depth!(p, lift)
  glBindVertexArray(k.vao)
  glEnable(GL_DEPTH_TEST)
  glDepthFunc(GL_LEQUAL)
  glDepthMask(GL_FALSE)
  glUniform4f(uniform(p, "tint"), t.colour...)
  glUniform1f(uniform(p, "only"), -1f0)
  glUniform1f(uniform(p, "plain"), 1f0)
  glDrawArrays(GL_TRIANGLES, 0, k.count)
  glDepthMask(GL_TRUE)
end

draw!(s::Stage, t::Lines, mvp, look, lift, cut=UNCUT) = begin
  k = kept!(s, t)
  k.count == 0 && return
  p = s.lines
  glUseProgram(p)
  cuts!(p, t.cut ? cut : UNCUT)
  glUniformMatrix4fv(uniform(p, "mvp"), 1, GL_FALSE, mvp)
  glUniform2f(uniform(p, "view"), Float32(s.wide), Float32(s.high))
  glUniform1f(uniform(p, "width"), t.width)
  glUniform3f(uniform(p, "lift"), lift[1], lift[2], lift[3])
  depth!(p, lift)
  glUniform4f(uniform(p, "tint"), t.colour...)
  glUniform3f(uniform(p, "fade_at"), t.fade[1], t.fade[2], t.fade[3])
  glUniform2f(uniform(p, "fade"), t.fade[4], t.fade[5])
  glBindVertexArray(k.vao)
  t.hidden ? glEnable(GL_DEPTH_TEST) : glDisable(GL_DEPTH_TEST)
  glDepthFunc(GL_LEQUAL)
  glDepthMask(GL_FALSE)
  glDrawArrays(GL_TRIANGLES, 0, k.count)
  glDepthMask(GL_TRUE)
end

"""
Draw the face of the cut that the plane `cut.capped` makes in the body `t`,
as SolidCraft's Section does: flat, in the body's colour, a little darker,
and hatched. The stencil counts the faces of what's left of the body in
front of each pixel. Where that's odd, the plane is inside the body there, so
a square on the plane is drawn there, as wide as `reach` round the point of
the plane nearest `target`. The square is as far away as the plane is, so
what's behind it, like the edges inside the body, doesn't show through.

The stencil is 0 everywhere before the first body: the square puts it back
to 0 wherever it was odd, so the next body needs no clear of its own. (A
square that the plane can't reach is inside no body: everything is within
`reach` of `target`.) Only when another plane cuts the square too is the
stencil cleared for each body.
"""
cap!(s::Stage, t::Solid, mvp, look, lift, cut::Cutting, target, reach) = begin
  k = kept!(s, t)
  k.count == 0 && return
  origin, n = cut.capped
  p = s.solid
  glUseProgram(p)
  glUniformMatrix4fv(uniform(p, "mvp"), 1, GL_FALSE, mvp)
  glUniformMatrix3fv(uniform(p, "look"), 1, GL_FALSE, look)
  depth!(p, lift)
  glUniform1f(uniform(p, "only"), -1f0)
  # Count the faces: each one flips the stencil, so its lowest bit is 1 where there's an odd number
  glEnable(GL_STENCIL_TEST)
  glStencilMask(0xff)
  length(cut.list) > 1 && glClear(GL_STENCIL_BUFFER_BIT)
  glStencilFunc(GL_ALWAYS, 0, 0xff)
  glStencilOp(GL_KEEP, GL_KEEP, GL_INVERT)
  glColorMask(GL_FALSE, GL_FALSE, GL_FALSE, GL_FALSE)
  glDepthMask(GL_FALSE)
  glDisable(GL_DEPTH_TEST)
  cuts!(p, cut)
  glUniform2f(uniform(p, "cap"), 0f0, 0f0)
  glBindVertexArray(k.vao)
  glDrawArrays(GL_TRIANGLES, 0, k.count)
  # The square, where the count is odd. The other plane still cuts it, but not its own.
  glColorMask(GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE)
  glDepthMask(GL_TRUE)
  glEnable(GL_DEPTH_TEST)
  glDepthFunc(GL_LEQUAL)
  glStencilFunc(GL_EQUAL, 1, 1)
  glStencilOp(GL_KEEP, GL_ZERO, GL_ZERO)
  glUniform4fv(uniform(p, "cuts"), 2, plane_numbers([c for c in cut.list if c !== cut.capped]))
  glUniform2f(uniform(p, "cap"), 1f0, cut.hatch)
  glUniform4f(uniform(p, "tint"), (t.colour[1:3] .* 0.8f0)..., 1f0)
  square = square_on(origin, n, target, reach)
  q = kept!(s, Solid((:cap, square), square, (0f0, 0f0, 0f0, 1f0)))
  glBindVertexArray(q.vao)
  glDrawArrays(GL_TRIANGLES, 0, q.count)
  glDisable(GL_STENCIL_TEST)
end

"""
Two triangles that make a square on the plane through `origin` that faces
`n`, `reach` from its middle to each side, round the point of the plane
nearest `target`: corners as a `Solid` has them
"""
square_on(origin, n, target, reach) = begin
  middle = target .- n .* dot(target .- origin, n)
  # Two ways along the plane, at right angles
  other = abs(n[1]) < 0.9 ? (1.0, 0.0, 0.0) : (0.0, 1.0, 0.0)
  u = (n[2] * other[3] - n[3] * other[2], n[3] * other[1] - n[1] * other[3], n[1] * other[2] - n[2] * other[1])
  u = u ./ sqrt(dot(u, u))
  w = (n[2] * u[3] - n[3] * u[2], n[3] * u[1] - n[1] * u[3], n[1] * u[2] - n[2] * u[1])
  r = 1.05 * reach
  corner(a, b) = middle .+ u .* (a * r) .+ w .* (b * r)
  data = Float32[]
  for c in (corner(-1, -1), corner(1, -1), corner(1, 1), corner(-1, -1), corner(1, 1), corner(-1, 1))
    append!(data, Float32.(c)); append!(data, Float32.(n)); push!(data, 0f0)
  end
  data
end

"""
Draw `things` as the eye `e` sees them, in a picture of `w` by `h` pixels on
the colour `background`, and give its pixels: red, green, blue and alpha
bytes, a row at a time from the top. `reach` is how far from the eye's target
the things go. `cut` is a plane, as a point on it and the way it faces, or a
list of two at most: the part of each body that's on the side that a plane
faces doesn't show. `capped` is one of those planes, whose cut shows a face
where it opens a body, as SolidCraft's Section does, with hatch lines `hatch`
pixels apart (0 for none).

With `read=false` the pixels stay on the graphics card, in the stage's
renderbuffer, and this gives nothing. A context that shares with the stage
shows them: see `over!`. Reading them took longer than drawing them: the CPU
waited for the graphics card to finish, then for the bytes, and then sent
them back to the card to draw the window.
"""
picture!(s::Stage, w::Int, h::Int, e::Eye, things, background; reach=1000.0, cut=nothing, capped=nothing, hatch=0.0, read=true) = begin
  was = current()
  setcurrent(s.cgl)
  try
    size!(s, w, h)
    s.frame += 1
    mvp, look, lift = matrices(e, w, h, reach)
    planes = cut === nothing ? () : cut isa Tuple ? (cut,) : cut
    plane = Cutting(plane_numbers(planes), collect(Any, planes), capped, Float32(hatch))
    glBindFramebuffer(GL_FRAMEBUFFER, s.msfbo)
    glViewport(0, 0, w, h)
    glDisable(GL_SCISSOR_TEST)
    glDisable(GL_CULL_FACE)
    glEnable(GL_MULTISAMPLE)
    glDepthMask(GL_TRUE)
    glClearColor(background[1], background[2], background[3], 1f0)
    glClearDepth(1.0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glEnable(GL_BLEND)
    glBlendFuncSeparate(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, GL_ONE, GL_ONE_MINUS_SRC_ALPHA)
    # What's solid first, then the lines over it, then what shows through: the sheets, and the bodies that do
    for t in things
      t isa Solid && !t.through && !t.bare && draw!(s, t, mvp, look, lift, plane)
    end
    for t in things
      t isa Solid && !t.through && t.bare && draw!(s, t, mvp, look, lift, plane)
    end
    if capped !== nothing
      glStencilMask(0xff)
      glClearStencil(0)
      glClear(GL_STENCIL_BUFFER_BIT)
      for t in things
        t isa Solid && !t.through && !t.bare && cap!(s, t, mvp, look, lift, plane, e.target, reach)
      end
    end
    for t in things
      t isa Lines && draw!(s, t, mvp, look, lift, plane)
    end
    for t in things
      t isa Sheet && draw!(s, t, mvp, look, lift, plane)
    end
    for t in things
      t isa Solid && t.through && draw!(s, t, mvp, look, lift, plane)
    end
    glBindVertexArray(0)
    glDisable(GL_STENCIL_TEST)
    glBindFramebuffer(GL_READ_FRAMEBUFFER, s.msfbo)
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, s.fbo)
    glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, GL_COLOR_BUFFER_BIT, GL_NEAREST)
    if read
      glBindFramebuffer(GL_READ_FRAMEBUFFER, s.fbo)
      glPixelStorei(GL_PACK_ALIGNMENT, 4)
      glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, s.pixels)
    else
      # Another context sees what this one drew once it has gone to the graphics card
      glFlush()
    end
    # What wasn't drawn for a while leaves the graphics card
    for (key, k) in s.kept
      s.frame - k.used > 120 || continue
      glDeleteBuffers(1, Ref(k.buffer))
      glDeleteVertexArrays(1, Ref(k.vao))
      delete!(s.kept, key)
    end
  finally
    setcurrent(was)
  end
  destroy_gone!()
  read ? s.pixels : nothing
end

"""
A framebuffer of the current context that has the stage's last picture, for
a context that shares with the stage: see `Stage(share)`. `fbo` is the one
that `over!` gave before, or 0 for none. Call it again when the picture
changes size, since a context sees a change that another made to a
renderbuffer only when it's attached again. What's bound is bound again
after, so Skia, which draws with the context, finds it as it left it.
"""
over!(s::Stage, fbo=0) = begin
  draw, read = Ref{GLint}(0), Ref{GLint}(0)
  glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, draw)
  glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, read)
  fbo == 0 && (fbo = made(glGenFramebuffers))
  glBindFramebuffer(GL_FRAMEBUFFER, fbo)
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, s.colour)
  complete = glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE
  glBindFramebuffer(GL_DRAW_FRAMEBUFFER, draw[])
  glBindFramebuffer(GL_READ_FRAMEBUFFER, read[])
  complete ? fbo : (glDeleteFramebuffers(1, Ref(fbo)); UInt32(0))
end
