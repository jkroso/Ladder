# Pictures that macOS makes, for the files that Skia can't read itself.
#
# - `picture(path)` reads a picture of a kind that macOS knows and Skia doesn't,
#   like HEIC, TIFF and SVG.
# - `thumbnail(path)` is the picture that the Finder shows for a file: the first
#   page of a Word file, the letters of a font and so on.
# - `pdf_page(path, n, wide)` draws one page of a PDF file.
#
# Each gives the key of a picture, to draw with `Image(key)`, or nothing when
# macOS has no picture for the file. A picture is made once and kept, so it
# costs nothing to ask for it in every frame. This file only works on macOS.

@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool
@use "github.com/jkroso/UI.jl/Interface/image" register_image has_image

const AppKit = "/System/Library/Frameworks/AppKit.framework/AppKit"
const QuickLook = "/System/Library/Frameworks/QuickLook.framework/QuickLook"
const ImageIO = "/System/Library/Frameworks/ImageIO.framework/ImageIO"
const CoreGraphics = "/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"
const CoreFoundation = "/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"

const Object = Ptr{Cvoid}
const Rect = NTuple{4,Float64}   # where it starts, how wide it is and how tall

release(object) = object == C_NULL || ccall((:CFRelease, CoreFoundation), Cvoid, (Object,), object)
fileurl(path) = msg(cls("NSURL"), "fileURLWithPath:", nsstring(abspath(path)))

"The bytes of a PNG file of `image`, one of macOS's CGImages"
png(image::Object) = begin
  data = msg(cls("NSMutableData"), "data")
  to = ccall((:CGImageDestinationCreateWithData, ImageIO), Object, (Object, Object, Csize_t, Object), data, nsstring("public.png"), 1, C_NULL)
  to == C_NULL && return UInt8[]
  ccall((:CGImageDestinationAddImage, ImageIO), Cvoid, (Object, Object, Object), to, image, C_NULL)
  done = ccall((:CGImageDestinationFinalize, ImageIO), Bool, (Object,), to)
  release(to)
  done || return UInt8[]
  n = ccall((:objc_msgSend, libobjc), UInt, (Object, Object), data, sel("length"))
  copy(unsafe_wrap(Array, Ptr{UInt8}(msg(data, "bytes")), n))
end

# The keys of the files that macOS had no picture for, so that it's asked once
const none = Set{String}()

"""
The key of the picture that `make()` gives: one of macOS's CGImages, which is
released here, or C_NULL. The picture is kept under `key`.
"""
keep(make, key::String) = begin
  has_image(key) && return key
  (key in none || !Sys.isapple()) && return nothing
  bytes = try
    with_pool() do
      image = make()
      image == C_NULL && return UInt8[]
      out = png(image)
      release(image)
      out
    end
  catch
    UInt8[]
  end
  isempty(bytes) && (push!(none, key); return nothing)
  try
    register_image(key, bytes)
  catch
    push!(none, key)
    nothing
  end
end

"A key for the file at `path` that changes when the file does"
stamp(kind, path, more...) = join((kind, abspath(path), mtime(path), more...), ':')

"""
The picture in the file at `path`, of any kind that macOS reads. A picture
that's made of shapes, like an SVG, is drawn `side` pixels along its longer side.
"""
picture(path::AbstractString, side::Integer=1600) = begin
  key = stamp("picture", path, side)
  keep(() -> read_picture(path, side, key), key)
end

# How big macOS says each picture of `picture` is, in px. A picture that's made of shapes has more pixels than that.
const sizes = Dict{String,NTuple{2,Float64}}()

"How wide and how tall the picture that `picture` kept under `key` is on a page, in px, or nothing for any other picture"
natural(key::AbstractString) = get(sizes, key, nothing)

read_picture(path, side, key) = begin
  Base.Libc.Libdl.dlopen(AppKit)
  # macOS finds the kind of picture from the bytes, so the end of the file's name doesn't matter
  data = msg(cls("NSData"), "dataWithContentsOfFile:", nsstring(abspath(path)))
  data == C_NULL && return C_NULL
  image = msg(msg(msg(cls("NSImage"), "alloc"), "initWithData:", data), "autorelease")
  image == C_NULL && return C_NULL
  w, h = ccall((:objc_msgSend, libobjc), NTuple{2,Float64}, (Object, Object), image, sel("size"))
  (w > 0 && h > 0) || return C_NULL
  sizes[key] = (w, h)
  # A picture made of pixels comes at its own size. One made of shapes comes at the size that's asked for.
  k = side / max(w, h)
  room = Ref{Rect}((0.0, 0.0, w * k, h * k))
  made = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Ptr{Cvoid}, Object, Object), image,
               sel("CGImageForProposedRect:context:hints:"), room, C_NULL, C_NULL)
  # The picture belongs to the NSImage, which goes when this is done, so take a share in it
  made == C_NULL || ccall((:CFRetain, CoreFoundation), Object, (Object,), made)
  made
end

"The picture that the Finder shows for the file at `path`, no more than `side` pixels wide or tall"
thumbnail(path::AbstractString, side::Integer=1000) = keep(stamp("thumbnail", path, side)) do
  ccall((:QLThumbnailImageCreate, QuickLook), Object, (Object, Object, NTuple{2,Float64}, Object),
        C_NULL, fileurl(path), (Float64(side), Float64(side)), C_NULL)
end

"""
The icon that the Finder shows for the folder or the file at `path`, `side`
pixels wide and tall: a folder's own icon, or the icon of the app that opens
the file. It's kept by the path, since an icon seldom changes.
"""
finder_icon(path::AbstractString, side::Integer=128) = keep(join(("icon", abspath(path), side), ':')) do
  Base.Libc.Libdl.dlopen(AppKit)
  image = msg(msg(cls("NSWorkspace"), "sharedWorkspace"), "iconForFile:", nsstring(abspath(path)))
  image == C_NULL && return C_NULL
  room = Ref{Rect}((0.0, 0.0, Float64(side), Float64(side)))
  made = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Ptr{Cvoid}, Object, Object), image,
               sel("CGImageForProposedRect:context:hints:"), room, C_NULL, C_NULL)
  # The picture belongs to the NSImage, which goes when this is done, so take a share in it
  made == C_NULL || ccall((:CFRetain, CoreFoundation), Object, (Object,), made)
  made
end

"How many pages the PDF file at `path` has, or 0 if it isn't a PDF file that macOS can read"
pdf_pages(path::AbstractString) = Sys.isapple() ? with_pool() do
  pdf = ccall((:CGPDFDocumentCreateWithURL, CoreGraphics), Object, (Object,), fileurl(path))
  pdf == C_NULL && return 0
  n = Int(ccall((:CGPDFDocumentGetNumberOfPages, CoreGraphics), Csize_t, (Object,), pdf))
  release(pdf)
  n
end : 0

"Page `n` of the PDF file at `path`, drawn `wide` pixels wide on white paper"
pdf_page(path::AbstractString, n::Integer, wide::Integer) = keep(stamp("pdf", path, n, wide)) do
  pdf = ccall((:CGPDFDocumentCreateWithURL, CoreGraphics), Object, (Object,), fileurl(path))
  pdf == C_NULL && return C_NULL
  page = ccall((:CGPDFDocumentGetPage, CoreGraphics), Object, (Object, Csize_t), pdf, n)
  page == C_NULL && (release(pdf); return C_NULL)
  # 1 is the part of the page that shows: its crop box
  _, _, w, h = ccall((:CGPDFPageGetBoxRect, CoreGraphics), Rect, (Object, Int32), page, 1)
  # A page can say that it's turned on its side
  ccall((:CGPDFPageGetRotationAngle, CoreGraphics), Int32, (Object,), page) % 180 == 0 || ((w, h) = (h, w))
  (w > 0 && h > 0) || (release(pdf); return C_NULL)
  tall = max(1, round(Int, wide * h / w))
  colours = ccall((:CGColorSpaceCreateDeviceRGB, CoreGraphics), Object, ())
  # 8 bits for each of red, green, blue and alpha. The 1 says that alpha comes last.
  paper = ccall((:CGBitmapContextCreate, CoreGraphics), Object, (Object, Csize_t, Csize_t, Csize_t, Csize_t, Object, UInt32),
                C_NULL, wide, tall, 8, 0, colours, 1)
  release(colours)
  paper == C_NULL && (release(pdf); return C_NULL)
  ccall((:CGContextSetRGBFillColor, CoreGraphics), Cvoid, (Object, Float64, Float64, Float64, Float64), paper, 1.0, 1.0, 1.0, 1.0)
  ccall((:CGContextFillRect, CoreGraphics), Cvoid, (Object, Rect), paper, (0.0, 0.0, Float64(wide), Float64(tall)))
  ccall((:CGContextScaleCTM, CoreGraphics), Cvoid, (Object, Float64, Float64), paper, wide / w, wide / w)
  # This puts the page in a box of its own size, the right way up
  place = ccall((:CGPDFPageGetDrawingTransform, CoreGraphics), NTuple{6,Float64}, (Object, Int32, Rect, Int32, Bool),
                page, 1, (0.0, 0.0, w, h), 0, true)
  ccall((:CGContextConcatCTM, CoreGraphics), Cvoid, (Object, NTuple{6,Float64}), paper, place)
  ccall((:CGContextDrawPDFPage, CoreGraphics), Cvoid, (Object, Object), paper, page)
  image = ccall((:CGBitmapContextCreateImage, CoreGraphics), Object, (Object,), paper)
  release(paper)
  release(pdf)
  image
end

# The PDF files that a takeoff shows, kept open while they don't change, so that a part of a page is quick to draw.
# Each has when its file last changed and macOS's document.
const open_pdfs = Dict{String,Tuple{Float64,Object}}()

# The build draws the welcome page, which has a takeoff of plan.pdf, so the app's image holds a document of the
# process that built it. In the app that pointer points at nothing, and the first takeoff of that file crashed.
# They aren't released: they were never this process's.
__init__() = (empty!(open_pdfs); nothing)

"macOS's document for the PDF file at `path`, or C_NULL if it isn't a PDF file that macOS can read. It's kept, so don't release it."
pdf(path::AbstractString) = begin
  path = abspath(path)
  at = mtime(path)
  kept = get(open_pdfs, path, nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  kept === nothing || release(kept[2])
  doc = Sys.isapple() && isfile(path) ? with_pool(() -> ccall((:CGPDFDocumentCreateWithURL, CoreGraphics), Object, (Object,), fileurl(path))) : C_NULL
  open_pdfs[path] = (at, doc)
  doc
end

"Page `n` of a PDF document, how wide and how tall it shows in points, and whether it's turned on its side. It's nothing when there's no such page."
pdf_box(doc::Object, n::Integer) = begin
  doc == C_NULL && return nothing
  page = ccall((:CGPDFDocumentGetPage, CoreGraphics), Object, (Object, Csize_t), doc, n)
  page == C_NULL && return nothing
  _, _, w, h = ccall((:CGPDFPageGetBoxRect, CoreGraphics), Rect, (Object, Int32), page, 1)
  ccall((:CGPDFPageGetRotationAngle, CoreGraphics), Int32, (Object,), page) % 180 == 0 || ((w, h) = (h, w))
  (w > 0 && h > 0) ? (page, w, h) : nothing
end

"How wide and how tall page `n` of the PDF file at `path` is, in points: 72 to an inch of paper. It's nothing when there's no such page."
pdf_size(path::AbstractString, n::Integer) = begin
  found = pdf_box(pdf(path), n)
  found === nothing ? nothing : (found[2], found[3])
end

"""
A part of page `n` of the PDF file at `path`, as pixels. The page is drawn `k`
pixels to the point, on white paper. The part starts `x` pixels from the left
of that drawing and `y` from its top, and is `w` pixels wide and `h` tall. Each
pixel is a number with blue in its lowest byte, then green, red and alpha. It's
nothing when the page can't be drawn.
"""
pdf_part(path::AbstractString, n::Integer, k::Real, x::Real, y::Real, w::Integer, h::Integer) = begin
  (w > 0 && h > 0 && k > 0) || return nothing
  found = pdf_box(pdf(path), n)
  found === nothing && return nothing
  page, pw, ph = found
  with_pool() do
    colours = ccall((:CGColorSpaceCreateDeviceRGB, CoreGraphics), Object, ())
    # 8 bits for each of blue, green, red and alpha, in that order. 2 says that alpha is in the highest byte, and 8192 that the low byte comes first.
    paper = ccall((:CGBitmapContextCreate, CoreGraphics), Object, (Object, Csize_t, Csize_t, Csize_t, Csize_t, Object, UInt32),
                  C_NULL, w, h, 8, 0, colours, 2 | 8192)
    release(colours)
    paper == C_NULL && return nothing
    ccall((:CGContextSetRGBFillColor, CoreGraphics), Cvoid, (Object, Float64, Float64, Float64, Float64), paper, 1.0, 1.0, 1.0, 1.0)
    ccall((:CGContextFillRect, CoreGraphics), Cvoid, (Object, Rect), paper, (0.0, 0.0, Float64(w), Float64(h)))
    # macOS measures up from the bottom, so the part's bottom edge is what's put at the bottom of the pixels
    ccall((:CGContextTranslateCTM, CoreGraphics), Cvoid, (Object, Float64, Float64), paper, -Float64(x), h + Float64(y) - ph * k)
    ccall((:CGContextScaleCTM, CoreGraphics), Cvoid, (Object, Float64, Float64), paper, Float64(k), Float64(k))
    place = ccall((:CGPDFPageGetDrawingTransform, CoreGraphics), NTuple{6,Float64}, (Object, Int32, Rect, Int32, Bool),
                  page, 1, (0.0, 0.0, pw, ph), 0, true)
    ccall((:CGContextConcatCTM, CoreGraphics), Cvoid, (Object, NTuple{6,Float64}), paper, place)
    ccall((:CGContextDrawPDFPage, CoreGraphics), Cvoid, (Object, Object), paper, page)
    from = Ptr{UInt32}(ccall((:CGBitmapContextGetData, CoreGraphics), Ptr{Cvoid}, (Object,), paper))
    row = Int(ccall((:CGBitmapContextGetBytesPerRow, CoreGraphics), Csize_t, (Object,), paper)) ÷ 4
    out = Vector{UInt32}(undef, w * h)
    # A row of macOS's pixels can be longer than the part is wide
    for r in 0:h-1
      unsafe_copyto!(pointer(out, r * w + 1), from + 4r * row, w)
    end
    release(paper)
    out
  end
end

# --- the lines of a page of a PDF file ------------------------------------------------
#
# A page of a PDF file is a list of things to draw: move here, a line to there,
# stroke it. macOS reads the list and calls a function for each kind of step.
# The functions below follow the steps that make lines, and keep each line that
# the page paints. A takeoff snaps to those lines.

const Place = NTuple{6,Float64}   # how a step's points are moved, turned and scaled, as a PDF file writes it
const Line = NTuple{4,Float64}     # from one point to another

"What follows the steps of a page: where its points go, the path that's being made, and the lines so far"
mutable struct Reader
  place::Place
  kept::Vector{Place}           # the ones that `q` put by, for `Q` to put back
  path::Vector{Line}             # the lines of the path that's being made. A step that paints keeps them.
  path_ends::Vector{UInt8}
  start::NTuple{2,Float64}       # where the path's part began, for a step that closes it
  at::NTuple{2,Float64}
  lines::Vector{Line}
  ends::Vector{UInt8}            # the ends of each line that are corners: 1 is its start, 2 its end, 3 both
  table::Object                  # macOS's table of the functions
  depth::Int                     # how many drawings inside drawings it's in
end

const MOST_LINES = 1_500_000   # a page with more lines than this gives its first ones
const CURVE_PIECES = 8         # the straight lines that stand for a curve

"`m`, then `n`"
times(m::Place, n::Place) = (m[1] * n[1] + m[2] * n[3], m[1] * n[2] + m[2] * n[4], m[3] * n[1] + m[4] * n[3], m[3] * n[2] + m[4] * n[4],
                               m[5] * n[1] + m[6] * n[3] + n[5], m[5] * n[2] + m[6] * n[4] + n[6])
through(m::Place, x, y) = (x * m[1] + y * m[3] + m[5], x * m[2] + y * m[4] + m[6])

reader(info::Object) = unsafe_pointer_to_objref(info)::Reader

"The last number before the step. A step's numbers come off last first."
number(scanner::Object) = (x = Ref(0.0); ccall((:CGPDFScannerPopNumber, CoreGraphics), Bool, (Object, Ref{Float64}), scanner, x); x[])
"The point before the step, where the page shows it"
point(r::Reader, scanner::Object) = (y = number(scanner); x = number(scanner); through(r.place, x, y))

line!(r::Reader, to, ends=0x03) = (push!(r.path, (r.at..., to...)); push!(r.path_ends, ends); r.at = to; nothing)

"A curve from where the path is to `c`, pulled towards `a` and then `b`. Only its two ends are corners."
curve!(r::Reader, a, b, c) = begin
  p = r.at
  for k in 1:CURVE_PIECES
    t = k / CURVE_PIECES
    u = 1 - t
    line!(r, (u^3 * p[1] + 3u^2 * t * a[1] + 3u * t^2 * b[1] + t^3 * c[1], u^3 * p[2] + 3u^2 * t * a[2] + 3u * t^2 * b[2] + t^3 * c[2]),
          k == 1 ? 0x01 : k == CURVE_PIECES ? 0x02 : 0x00)
  end
end

"The path was painted, so its lines are on the page"
keep!(r::Reader) = begin
  length(r.lines) < MOST_LINES && (append!(r.lines, r.path); append!(r.ends, r.path_ends))
  drop!(r)
end
drop!(r::Reader) = (empty!(r.path); empty!(r.path_ends); nothing)
close!(r::Reader) = (r.at == r.start || isempty(r.path) || line!(r, r.start); nothing)

# The steps. Each is named for the letters that a PDF file writes for it.
step_q(::Object, info::Object)::Cvoid = (r = reader(info); push!(r.kept, r.place); nothing)
step_Q(::Object, info::Object)::Cvoid = (r = reader(info); isempty(r.kept) || (r.place = pop!(r.kept)); nothing)
step_cm(scanner::Object, info::Object)::Cvoid = begin
  r = reader(info)
  f, e, d, c, b, a = number(scanner), number(scanner), number(scanner), number(scanner), number(scanner), number(scanner)
  r.place = times((a, b, c, d, e, f), r.place)
  nothing
end
step_m(scanner::Object, info::Object)::Cvoid = (r = reader(info); r.start = r.at = point(r, scanner); nothing)
step_l(scanner::Object, info::Object)::Cvoid = (r = reader(info); line!(r, point(r, scanner)))
step_c(scanner::Object, info::Object)::Cvoid = (r = reader(info); c = point(r, scanner); b = point(r, scanner); a = point(r, scanner); curve!(r, a, b, c))
step_v(scanner::Object, info::Object)::Cvoid = (r = reader(info); c = point(r, scanner); b = point(r, scanner); curve!(r, r.at, b, c))
step_y(scanner::Object, info::Object)::Cvoid = (r = reader(info); c = point(r, scanner); a = point(r, scanner); curve!(r, a, c, c))
step_h(::Object, info::Object)::Cvoid = close!(reader(info))
step_re(scanner::Object, info::Object)::Cvoid = begin
  r = reader(info)
  h, w, y, x = number(scanner), number(scanner), number(scanner), number(scanner)
  r.start = r.at = through(r.place, x, y)
  line!(r, through(r.place, x + w, y))
  line!(r, through(r.place, x + w, y + h))
  line!(r, through(r.place, x, y + h))
  line!(r, r.start)
end
step_paint(::Object, info::Object)::Cvoid = keep!(reader(info))
step_close_paint(::Object, info::Object)::Cvoid = (r = reader(info); close!(r); keep!(r))
# A path that isn't painted only says where the next things may show
step_n(::Object, info::Object)::Cvoid = drop!(reader(info))

# A page can draw another drawing that the file holds, like a title block that every page has
step_Do(scanner::Object, info::Object)::Cvoid = begin
  r = reader(info)
  name = Ref{Cstring}(C_NULL)
  ccall((:CGPDFScannerPopName, CoreGraphics), Bool, (Object, Ref{Cstring}), scanner, name) || return nothing
  r.depth < 12 || return nothing
  stream = ccall((:CGPDFScannerGetContentStream, CoreGraphics), Object, (Object,), scanner)
  object = ccall((:CGPDFContentStreamGetResource, CoreGraphics), Object, (Object, Cstring, Cstring), stream, "XObject", name[])
  object == C_NULL && return nothing
  form = Ref{Object}(C_NULL)
  # 9 asks for the steps of a drawing
  ccall((:CGPDFObjectGetValue, CoreGraphics), Bool, (Object, Int32, Ref{Object}), object, 9, form) || return nothing
  about = ccall((:CGPDFStreamGetDictionary, CoreGraphics), Object, (Object,), form[])
  kind = Ref{Cstring}(C_NULL)
  # A picture is drawn this way too, and has no lines
  (ccall((:CGPDFDictionaryGetName, CoreGraphics), Bool, (Object, Cstring, Ref{Cstring}), about, "Subtype", kind) && unsafe_string(kind[]) == "Form") || return nothing
  place = (1.0, 0.0, 0.0, 1.0, 0.0, 0.0)
  array = Ref{Object}(C_NULL)
  if ccall((:CGPDFDictionaryGetArray, CoreGraphics), Bool, (Object, Cstring, Ref{Object}), about, "Matrix", array) &&
     ccall((:CGPDFArrayGetCount, CoreGraphics), Csize_t, (Object,), array[]) == 6
    x = Ref(0.0)
    place = ntuple(i -> (ccall((:CGPDFArrayGetNumber, CoreGraphics), Bool, (Object, Csize_t, Ref{Float64}), array[], i - 1, x); x[]), 6)
  end
  resources = Ref{Object}(C_NULL)
  ccall((:CGPDFDictionaryGetDictionary, CoreGraphics), Bool, (Object, Cstring, Ref{Object}), about, "Resources", resources)
  inner = ccall((:CGPDFContentStreamCreateWithStream, CoreGraphics), Object, (Object, Object, Object), form[], resources[], stream)
  inner == C_NULL && return nothing
  was, kept = r.place, r.kept
  r.place, r.kept = times(place, r.place), Place[]
  r.depth += 1
  follow!(r, inner)
  r.depth -= 1
  r.place, r.kept = was, kept
  ccall((:CGPDFContentStreamRelease, CoreGraphics), Cvoid, (Object,), inner)
  nothing
end

"Follow the steps of `stream`"
follow!(r::Reader, stream::Object) = begin
  scanner = ccall((:CGPDFScannerCreate, CoreGraphics), Object, (Object, Object, Any), stream, r.table, r)
  ccall((:CGPDFScannerScan, CoreGraphics), Bool, (Object,), scanner)
  ccall((:CGPDFScannerRelease, CoreGraphics), Cvoid, (Object,), scanner)
  nothing
end

"macOS's table of the function for each step"
steps() = begin
  table = ccall((:CGPDFOperatorTableCreate, CoreGraphics), Object, ())
  set(name, f) = ccall((:CGPDFOperatorTableSetCallback, CoreGraphics), Cvoid, (Object, Cstring, Ptr{Cvoid}), table, name, f)
  set("q", @cfunction(step_q, Cvoid, (Object, Object)))
  set("Q", @cfunction(step_Q, Cvoid, (Object, Object)))
  set("cm", @cfunction(step_cm, Cvoid, (Object, Object)))
  set("m", @cfunction(step_m, Cvoid, (Object, Object)))
  set("l", @cfunction(step_l, Cvoid, (Object, Object)))
  set("c", @cfunction(step_c, Cvoid, (Object, Object)))
  set("v", @cfunction(step_v, Cvoid, (Object, Object)))
  set("y", @cfunction(step_y, Cvoid, (Object, Object)))
  set("h", @cfunction(step_h, Cvoid, (Object, Object)))
  set("re", @cfunction(step_re, Cvoid, (Object, Object)))
  # The steps that stroke a path, fill it, or do both
  foreach(name -> set(name, @cfunction(step_paint, Cvoid, (Object, Object))), ("S", "f", "F", "f*", "B", "B*"))
  # The ones that close it first
  foreach(name -> set(name, @cfunction(step_close_paint, Cvoid, (Object, Object))), ("s", "b", "b*"))
  set("n", @cfunction(step_n, Cvoid, (Object, Object)))
  set("Do", @cfunction(step_Do, Cvoid, (Object, Object)))
  table
end

"""
The lines that page `n` of the PDF file at `path` draws, and which ends of each
are corners: 1 is its start, 2 its end and 3 both. A curve is a few straight
lines, and only its two ends are corners. A line goes from one point to
another, each measured in points from the top left of the page as it shows,
like the points of `pdf_size`. A page that's a scan of paper has none. It's
nothing when there's no such page.
"""
pdf_lines(path::AbstractString, n::Integer) = begin
  found = pdf_box(pdf(path), n)
  found === nothing && return nothing
  page, w, h = found
  with_pool() do
    # This puts the page in a box of its own size, the right way up. macOS measures up from the bottom, so the last part turns it over.
    place = ccall((:CGPDFPageGetDrawingTransform, CoreGraphics), Place, (Object, Int32, Rect, Int32, Bool), page, 1, (0.0, 0.0, w, h), 0, true)
    r = Reader(times(place, (1.0, 0.0, 0.0, -1.0, 0.0, h)), Place[], Line[], UInt8[], (0.0, 0.0), (0.0, 0.0), Line[], UInt8[], steps(), 0)
    stream = ccall((:CGPDFContentStreamCreateWithPage, CoreGraphics), Object, (Object,), page)
    stream == C_NULL || GC.@preserve r follow!(r, stream)
    stream == C_NULL || ccall((:CGPDFContentStreamRelease, CoreGraphics), Cvoid, (Object,), stream)
    ccall((:CGPDFOperatorTableRelease, CoreGraphics), Cvoid, (Object,), r.table)
    (r.lines, r.ends)
  end
end

export picture, natural, thumbnail, pdf_pages, pdf_page, pdf_size, pdf_part, pdf_lines

"""
Forget the picture that's kept under `key`, so that its memory is free. A
view that makes a picture for each of thousands of files, like a grid of
photos, forgets the ones that it hasn't shown for a while.
"""
forget_picture(key::AbstractString) = (delete!(parentmodule(register_image)._images, String(key)); nothing)

"""
Where the photo in the file at `path` was taken, as a latitude and a
longitude, or nothing when the file doesn't say. A camera or a phone writes
it into the file. macOS reads only the start of the file to find it.
"""
photo_place(path::AbstractString) = begin
  Sys.isapple() || return nothing
  try
    with_pool() do
      source = ccall((:CGImageSourceCreateWithURL, ImageIO), Object, (Object, Object), fileurl(path), C_NULL)
      source == C_NULL && return nothing
      facts = ccall((:CGImageSourceCopyPropertiesAtIndex, ImageIO), Object, (Object, Csize_t, Object), source, 0, C_NULL)
      release(source)
      facts == C_NULL && return nothing
      # macOS's dictionary is one of Objective-C's too
      gps = msg(facts, "objectForKey:", nsstring("{GPS}"))
      number(key) = (v = gps == C_NULL ? C_NULL : msg(gps, "objectForKey:", nsstring(key)); v == C_NULL ? nothing : ccall((:objc_msgSend, libobjc), Float64, (Object, Object), v, sel("doubleValue")))
      side(key) = (v = gps == C_NULL ? C_NULL : msg(gps, "objectForKey:", nsstring(key)); v == C_NULL ? "" : jstring(msg(v, "description")))
      lat, lon = number("Latitude"), number("Longitude")
      found = (lat === nothing || lon === nothing || (lat == 0 && lon == 0)) ? nothing :
              (side("LatitudeRef") == "S" ? -lat : lat, side("LongitudeRef") == "W" ? -lon : lon)
      release(facts)
      found
    end
  catch
    nothing
  end
end
