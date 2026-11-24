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
# top. Each thing keeps its corners on the graphics card under its `key`, so a
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
flat out float of;
void main() {
  gl_Position = mvp * vec4(p, 1.0);
  facing = look * n;
  world = p;
  of = face;
}
"""

const SOLID_F = """
#version 410 core
in vec3 facing;
in vec3 world;
flat in float of;
uniform vec4 tint;
uniform float only;
uniform float plain;
uniform vec4 cut;
out vec4 colour;
void main() {
  if (only >= 0.0 && abs(of - only) > 0.5) discard;
  // What's on the eye's side of the plane that cuts the picture doesn't show. With no cut, the plane is (0, 0, 0, -1).
  if (dot(world, cut.xyz) + cut.w > 0.0) discard;
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
void main() {
  vec4 ca = mvp * vec4(a, 1.0), cb = mvp * vec4(b, 1.0);
  float eps = 1e-4;
  if (ca.w < eps && cb.w < eps) { gl_Position = vec4(2.0, 2.0, 2.0, 1.0); world = a; return; }
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
  world = corner.x < 0.5 ? a : b;
}
"""

const LINES_F = """
#version 410 core
in vec3 world;
uniform vec4 tint;
uniform vec3 fade_at;
uniform vec2 fade;
uniform vec4 cut;
out vec4 colour;
void main() {
  if (dot(world, cut.xyz) + cut.w > 0.0) discard;
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

"A place to draw designs, or nothing when macOS can't make an OpenGL context"
Stage() = begin
  attrs = Int32[99, 0x4100, 73, 96, 0]   # OpenGL 4.1, on the graphics card, which can be one that shows no screen
  pix, n = Ref{Ptr{Cvoid}}(C_NULL), Ref{Int32}(0)
  ccall((:CGLChoosePixelFormat, GL), Int32, (Ptr{Int32}, Ref{Ptr{Cvoid}}, Ref{Int32}), attrs, pix, n) == 0 && pix[] != C_NULL || return nothing
  ctx = Ref{Ptr{Cvoid}}(C_NULL)
  failed = ccall((:CGLCreateContext, GL), Int32, (Ptr{Cvoid}, Ptr{Cvoid}, Ref{Ptr{Cvoid}}), pix[], C_NULL, ctx)
  ccall((:CGLReleasePixelFormat, GL), Cvoid, (Ptr{Cvoid},), pix[])
  (failed == 0 && ctx[] != C_NULL) || return nothing
  s = Stage(ctx[], 0, 0, 0, 0, 0, 0, 0, 0, 0, Dict{Any,Kept}(), 0, UInt8[])
  was = current()
  setcurrent(s.cgl)
  try
    s.solid = program(SOLID_V, SOLID_F)
    s.lines = program(LINES_V, LINES_F)
  finally
    setcurrent(was)
  end
  finalizer(s -> (s.cgl == C_NULL || ccall((:CGLDestroyContext, GL), Int32, (Ptr{Cvoid},), s.cgl); s.cgl = C_NULL), s)
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
  glRenderbufferStorageMultisample(GL_RENDERBUFFER, 4, GL_DEPTH_COMPONENT32F, w, h)
  glBindFramebuffer(GL_FRAMEBUFFER, s.msfbo)
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, s.mscolour)
  glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, s.msdepth)
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
    near = max(e.distance - reach, e.distance * 0.02, far * 1e-4)
    f = 1 / tand(e.wide / 2)
    proj = [f/aspect 0 0 0; 0 -f 0 0; 0 0 (far+near)/(near-far) 2far*near/(near-far); 0 0 -1 0]
  else
    near = e.distance - reach
    proj = [2/(e.distance*aspect) 0 0 0; 0 -2/e.distance 0 0; 0 0 -2/(far-near) -(far+near)/(far-near); 0 0 0 1.0]
  end
  (Float32.(vec(proj * view)), Float32[right[1], up[1], back[1], right[2], up[2], back[2], right[3], up[3], back[3]],
   (LIFT, e.wide > 0 ? 1f0 : 0f0, Float32(proj[3, 4])))
end

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

uniform(p, name) = glGetUniformLocation(p, name)

const NO_CUT = (0f0, 0f0, 0f0, -1f0)

draw!(s::Stage, t::Solid, mvp, look, lift, cut=NO_CUT) = begin
  k = kept!(s, t)
  k.count == 0 && return
  p = s.solid
  glUseProgram(p)
  glUniform4f(uniform(p, "cut"), cut...)
  glUniformMatrix4fv(uniform(p, "mvp"), 1, GL_FALSE, mvp)
  glUniformMatrix3fv(uniform(p, "look"), 1, GL_FALSE, look)
  glBindVertexArray(k.vao)
  glEnable(GL_DEPTH_TEST)
  glDepthFunc(GL_LEQUAL)
  glEnable(GL_POLYGON_OFFSET_FILL)
  glPolygonOffset(1f0, 1f0)
  glDepthMask(t.through ? GL_FALSE : GL_TRUE)
  glUniform1f(uniform(p, "plain"), 0f0)
  if !t.bare
    glUniform4f(uniform(p, "tint"), t.colour...)
    glUniform1f(uniform(p, "only"), -1f0)
    glDrawArrays(GL_TRIANGLES, 0, k.count)
    # A face with a colour of its own is drawn again in that colour, just in front of the body's
    glPolygonOffset(0.5f0, 0.5f0)
    for (face, colour) in t.painted
      glUniform4f(uniform(p, "tint"), colour...)
      glUniform1f(uniform(p, "only"), Float32(face))
      glDrawArrays(GL_TRIANGLES, 0, k.count)
    end
  end
  # A face with a colour over its own is drawn once more, in front of both
  glDepthMask(GL_FALSE)
  glPolygonOffset(0f0, 0f0)
  for (face, colour) in t.lit
    glUniform4f(uniform(p, "tint"), colour...)
    glUniform1f(uniform(p, "only"), Float32(face))
    glUniform1f(uniform(p, "plain"), 0.55f0)
    glDrawArrays(GL_TRIANGLES, 0, k.count)
  end
  glDepthMask(GL_TRUE)
  glDisable(GL_POLYGON_OFFSET_FILL)
end

draw!(s::Stage, t::Sheet, mvp, look, lift, cut=NO_CUT) = begin
  k = kept!(s, t)
  k.count == 0 && return
  p = s.solid
  glUseProgram(p)
  glUniform4f(uniform(p, "cut"), NO_CUT...)
  glUniformMatrix4fv(uniform(p, "mvp"), 1, GL_FALSE, mvp)
  glUniformMatrix3fv(uniform(p, "look"), 1, GL_FALSE, look)
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

draw!(s::Stage, t::Lines, mvp, look, lift, cut=NO_CUT) = begin
  k = kept!(s, t)
  k.count == 0 && return
  p = s.lines
  glUseProgram(p)
  glUniform4f(uniform(p, "cut"), (t.cut ? cut : NO_CUT)...)
  glUniformMatrix4fv(uniform(p, "mvp"), 1, GL_FALSE, mvp)
  glUniform2f(uniform(p, "view"), Float32(s.wide), Float32(s.high))
  glUniform1f(uniform(p, "width"), t.width)
  glUniform3f(uniform(p, "lift"), lift...)
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
Draw `things` as the eye `e` sees them, in a picture of `w` by `h` pixels on
the colour `background`, and give its pixels: red, green, blue and alpha
bytes, a row at a time from the top. `reach` is how far from the eye's target
the things go. `cut` is a plane, as a point on it and the way it faces:
the part of each body that's on the side that it faces doesn't show.
"""
picture!(s::Stage, w::Int, h::Int, e::Eye, things, background; reach=1000.0, cut=nothing) = begin
  was = current()
  setcurrent(s.cgl)
  try
    size!(s, w, h)
    s.frame += 1
    mvp, look, lift = matrices(e, w, h, reach)
    plane = cut === nothing ? NO_CUT : (Float32.(cut[2])..., Float32(-dot(cut[1], cut[2])))
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
    glBindFramebuffer(GL_READ_FRAMEBUFFER, s.msfbo)
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, s.fbo)
    glBlitFramebuffer(0, 0, w, h, 0, 0, w, h, GL_COLOR_BUFFER_BIT, GL_NEAREST)
    glBindFramebuffer(GL_READ_FRAMEBUFFER, s.fbo)
    glPixelStorei(GL_PACK_ALIGNMENT, 4)
    glReadPixels(0, 0, w, h, GL_RGBA, GL_UNSIGNED_BYTE, s.pixels)
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
  s.pixels
end
