# Printing the page: Ladder draws it into a PDF the way it reads

@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" scene
@use "github.com/jkroso/UI.jl/Interface/abstract" WrapMode describe
@use "github.com/jkroso/UI.jl/Interface/draw" draw rect
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring with_pool send
@use "github.com/jkroso/UI.jl/Interface/window" nswindow
@use "./markdown" Kind spans
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./columns_view" exports...
@use "./module_view" exports...
@use "./caret_glide" exports...
@use "./toasts" exports...

export A4, NSSize, PRINT_TEXT, PRINT_X, PRINT_Y, breaks, clip!, listener, paper_size, print!,
       print_listener, print_panel!, print_pdf, printed, PrintedPDF

# --- printing ------------------------------------------------------------------------------
#
# ⌘P prints the page. The page is drawn into a PDF the way it reads, with no
# caret and no markup characters, in the Paper colours whatever colours the
# window has. The text is PRINT_TEXT points tall on paper, whatever size it
# has on screen, and the lines are as long as the paper allows. A page ends
# under a line of text or a row of a table or a sheet, never through one, and
# never right under a heading. Then the Mac's print panel slides down over the
# window with the PDF in it. The panel can save the PDF as a file too.

const PRINT_TEXT = 11.0   # the size of the page's text on paper, in points (1/72 of an inch)
const PRINT_X = 60.0      # the margin left and right of the text, in points
const PRINT_Y = 64.0      # the margin above and below it. The page's number is in the one below.
const A4 = (595.0, 842.0)

struct NSSize
  width::Float64
  height::Float64
end

"The size of the paper that the Mac prints on unless you choose another, in points"
paper_size() = begin
  Sys.isapple() || return A4
  s = with_pool() do
    ccall((:objc_msgSend, libobjc), NSSize, (Ptr{Cvoid}, Ptr{Cvoid}), msg(cls("NSPrintInfo"), "sharedPrintInfo"), sel("paperSize"))
  end
  s.width > 0 && s.height > 0 ? (s.width, s.height) : A4
end

"True when item `it` is a line with nothing on it"
blank(e, it::Item) = it.content isa Flow && isempty(strip(e.buf.lines[it.first]))

"""
The places down the page's text where a printed page can end: under each line
of text, and under each row of a table or a sheet. A page doesn't end under a
heading, or under the blank lines after one, so a heading goes onto the next
page with the text under it. For the same reason a page doesn't end under the
heading row of a table.
"""
breaks(e) = begin
  out = px[]
  held = false   # under a heading, with only blank lines since
  for it in e.layout
    c = it.content
    if c isa Flow
      for k in 1:length(c.lines)-1
        push!(out, it.top + line_top(c, k + 1))
      end
    elseif c isa Grid
      # Under the line under each row, after the second
      y = it.top + TABLE_GAP + c.head + 1px
      for (r, h) in enumerate(c.heights[1:end-1])
        y += h + 1px
        r > 1 && push!(out, y)
      end
    elseif c isa Sheet
      for r in 2:length(c.rows)
        push!(out, it.top + row_top(c, r))
      end
    end
    held = c isa Flow && (c.kind == Kind.heading || (held && blank(e, it)))
    held || push!(out, it.top + it.tall)
  end
  # A page doesn't end part of the way down a group of columns: the place would be between two lines of one column only
  columns = laid_columns(e)
  columns === nothing || filter!(y -> !any(g -> g.top < y < g.top + g.tall, columns.groups), out)
  sort!(out)
end

"""
The part of the page's text that each printed page shows, from its top to its
bottom. A page holds `room` of text. A blank line at the top of a page, or at
the end of the text, isn't printed.
"""
pages(e, room) = begin
  items = filter(it -> !blank(e, it), e.layout)
  isempty(items) && return [(0px, 0px)]
  total = lowest(e, items)
  ends = breaks(e)
  out = Tuple{px,px}[]
  top = first(items).top
  while true
    if total - top <= room
      push!(out, (top, total))
      return out
    end
    i = findlast(y -> y <= top + room, ends)
    # A block that's taller than a page, like a big live block, is cut where the page ends
    bottom = i === nothing || ends[i] <= top ? top + room : ends[i]
    push!(out, (top, bottom))
    # The next page starts with the next thing that isn't a blank line
    next = findfirst(it -> it.top + it.tall > bottom, items)
    top = max(bottom, items[next].top)
  end
end

"Clip what `canvas` draws to a box"
clip!(canvas, left, top, right, bottom) = begin
  rect = Ref(Skia.sk_rect_t(Float32(left), Float32(top), Float32(right), Float32(bottom)))
  GC.@preserve rect Skia.sk_canvas_clip_rect_with_operation(canvas, Base.unsafe_convert(Ptr{Skia.sk_rect_t}, rect), Skia.SK_CLIP_OP_INTERSECT, true)
end

"""
Draw the page's text into a PDF for paper that's `paper` points wide and tall,
and return the bytes of the PDF. The editor is left as it was.
"""
print_pdf(e, paper=paper_size()) = begin
  pw, ph = paper
  b = e.buf
  caret, anchor, wrapped = b.caret, b.anchor, e.wrap
  stream = Skia.sk_dynamic_memory_wstream_new()
  try
    # With the caret on no line, each line hides its markup and each live block shows what it made
    b.caret = b.anchor = (0, 0)
    # Paper doesn't scroll sideways, so a long line of code goes on under itself
    e.wrap = true
    use!(PAPER)
    use_code_font!(e)
    empty!(e.flows)
    # From pixels on screen to points on paper. The text is as wide as the paper allows.
    scale = PRINT_TEXT / num(body(e).size)
    layout!(e, px((pw - 2PRINT_X) / scale))
    w = e.width
    spans = pages(e, px((ph - 2PRINT_Y) / scale))
    d = node!(Document, e, :document)
    whole = Column(fixed(w), Alignment.Start, page_parts(d, e, e.layout)...)
    total = isempty(e.layout) ? 0px : lowest(e, e.layout)
    # A live block's code can load the drawing methods of what it shows, so the newest methods are used
    scene = Base.invokelatest(describe, whole, (w, total))
    title, creator, none = splitext(name(b))[1], "Ladder", ""
    never = Skia.sk_date_time_t(0, 0, 0, 0, 0, 0, 0, 0)
    # Skia copies the text of the PDF's details as it makes the PDF
    doc = GC.@preserve title creator none begin
      about = Ref(Skia.sk_metadata_t(pointer(title), pointer(none), pointer(none), pointer(none), pointer(creator),
                                     pointer(creator), never, never, 72f0, 0f0, Cint(101)))
      GC.@preserve about Skia.sk_document_make_pdf(Skia.sk_dynamic_memory_wstream_as_wstream(stream),
                                                   Base.unsafe_convert(Ptr{Skia.sk_metadata_t}, about))
    end
    for (n, (top, bottom)) in enumerate(spans)
      canvas = Skia.sk_document_begin_page(doc, Float32(pw), Float32(ph))
      Skia.sk_canvas_save(canvas)
      Skia.sk_canvas_translate(canvas, Float32(PRINT_X), Float32(PRINT_Y))
      Skia.sk_canvas_scale(canvas, Float32(scale), Float32(scale))
      # Only this page's part of the text, though something wide can run into the margins
      margin = PRINT_X / scale
      clip!(canvas, -margin, 0, num(w) + margin, num(bottom - top))
      Skia.sk_canvas_translate(canvas, 0f0, Float32(-num(top)))
      Base.invokelatest(draw, canvas, (w, total), scene)
      Skia.sk_canvas_restore(canvas)
      # The page's number, under the middle of the text
      if length(spans) > 1
        Skia.sk_canvas_save(canvas)
        Skia.sk_canvas_translate(canvas, Float32(PRINT_X), Float32(ph - PRINT_Y / 2 - 6))
        Skia.sk_canvas_scale(canvas, Float32(scale), Float32(scale))
        number = describe(Row(fixed(w), height(20px),
                              Text(string(n), size=px(9 / scale), family=SANS, color=colours.dim, wrap=WrapMode.none,
                                   align=TextAlign.Center)), (w, 20px))
        draw(canvas, (w, 20px), number)
        Skia.sk_canvas_restore(canvas)
      end
      Skia.sk_document_end_page(doc)
    end
    Skia.sk_document_close(doc)
    bytes = Vector{UInt8}(undef, Skia.sk_dynamic_memory_wstream_bytes_written(stream))
    Skia.sk_dynamic_memory_wstream_read(stream, bytes, Csize_t(0), Csize_t(length(bytes)))
    bytes
  finally
    Skia.sk_dynamic_memory_wstream_delete(stream)
    b.caret, b.anchor, e.wrap = caret, anchor, wrapped
    use!(getproperty(THEMES, e.theme))
    empty!(e.flows)
    layout!(e)
  end
end

@use "github.com/jkroso/Prospects.jl" @def

"What a window keeps of its printing"
@def mutable struct PrintedPDF
  pdf::Ptr{Cvoid} = C_NULL   # the PDFDocument that the print panel last showed, kept until the next one
end

"""
Show the Mac's print panel over window `w`, with the PDF in `bytes`. It slides
down from the top of the window, and the window waits until you print or cancel.
A window that isn't on the screen, like one a test makes, shows no panel.
"""
print_panel!(e, w, bytes, title) = begin
  (Sys.isapple() && !isempty(w.glfw)) || return
  # PDFKit draws a PDF for the Mac's printing. AppKit doesn't load it by itself.
  Base.Libc.Libdl.dlopen("/System/Library/Frameworks/PDFKit.framework/PDFKit")
  with_pool() do
    data = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{UInt8}, UInt),
                 cls("NSData"), sel("dataWithBytes:length:"), bytes, length(bytes))
    pdf = msg(msg(cls("PDFDocument"), "alloc"), "initWithData:", data)
    pdf == C_NULL && return
    # The panel may still need the last PDF until it closes, so it's kept until the next one
    s = state_of(e, PrintedPDF)
    s.pdf == C_NULL || msg(s.pdf, "release")
    s.pdf = pdf
    # The PDF has its own margins, so the panel adds none
    info = msg(msg(msg(cls("NSPrintInfo"), "sharedPrintInfo"), "copy"), "autorelease")
    foreach(side -> send(info, "set$(side)Margin:", 0.0), ("Top", "Bottom", "Left", "Right"))
    # Each page is made smaller if it's too big for the paper chosen in the panel (2 is kPDFPrintPageScaleDownToFit)
    op = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Int, Bool),
               pdf, sel("printOperationForPrintInfo:scalingMode:autoRotate:"), info, 2, true)
    op == C_NULL && return
    # The name that "Save as PDF" suggests
    msg(op, "setJobTitle:", nsstring(title))
    win = nswindow(w)
    ccall((:objc_msgSend, libobjc), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
          op, sel("runOperationModalForWindow:delegate:didRunSelector:contextInfo:"), win, print_listener(), sel("printed:success:window:"), win)
  end
  nothing
end

"""
AppKit calls this when the print panel closes, with the window it was over.
The window doesn't get the keyboard back by itself, so this gives it back.
"""
printed(self::Ptr{Cvoid}, cmd::Ptr{Cvoid}, op::Ptr{Cvoid}, ok::Bool, win::Ptr{Cvoid}) = (msg(win, "makeKeyWindow"); nothing)

# The object that AppKit tells when a print panel closes. It's made the first time a panel opens, and lasts as long as the app.
const listener = Ref(C_NULL)

"""
The object that AppKit tells when a print panel closes. Its class is made
here, in Objective-C's runtime, with `printed` as its one method.
"""
print_listener() = begin
  listener[] == C_NULL || return listener[]
  class = cls("LadderPrintListener")
  if class == C_NULL
    class = ccall((:objc_allocateClassPair, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Cstring, Csize_t), cls("NSObject"), "LadderPrintListener", 0)
    method = @cfunction(printed, Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Bool, Ptr{Cvoid}))
    ccall((:class_addMethod, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}, Cstring), class, sel("printed:success:window:"), method, "v@:@B^v")
    ccall((:objc_registerClassPair, libobjc), Cvoid, (Ptr{Cvoid},), class)
  end
  listener[] = msg(msg(class, "alloc"), "init")
end

"Print the page: show the Mac's print panel with the page drawn for paper"
print!(e, w) = e.buf.view != :markdown ? nothing : print_panel!(e, w, print_pdf(e), splitext(name(e.buf))[1])   # only a Markdown file is a page
