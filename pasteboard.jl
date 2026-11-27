# What the Mac's clipboard holds: text, files that were copied in the Finder,
# and a picture or other media that was copied as data, like a screenshot.
#
#     files()   # ["/Users/sam/Desktop/plan.png"]: the files that ⌘C copied in the Finder
#     media()   # ("png", bytes) for a picture that was copied, or nothing
#     text()    # the text that was copied, or ""
#     vcard()   # the text of a contact that was copied in the Contacts app, or ""
#
# Each takes a clipboard to read, which is the Mac's own unless you give
# another. This file only works on macOS.
#
# A paste reads the clipboard some time after the key is pressed, and the
# clipboard can change in that time. An app that takes dictation puts its
# words on the clipboard, presses ⌘V, and half a second later puts back what
# the clipboard held before. The first paste in Ladder waits longer than that
# while Julia compiles the code that pastes, so it got the old thing, like a
# screenshot, and not the words. So the key that pastes reads the clipboard at
# once, with `hold!`, and what it read is what's pasted:
#
#     hold!()      # read the clipboard now
#     text()       # the text that it held then, whatever it holds by now
#     release!()   # read the clipboard as it is again

@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool

const AppKit = "/System/Library/Frameworks/AppKit.framework/AppKit"
const Object = Ptr{Cvoid}

"A test puts a clipboard of its own here, to leave the Mac's clipboard as it is"
const other = Ref{Object}(C_NULL)

"The clipboard to read: the Mac's own, or the one that a test named"
board() = begin
  other[] == C_NULL || return other[]
  Base.Libc.Libdl.dlopen(AppKit)
  msg(cls("NSPasteboard"), "generalPasteboard")
end

"A new clipboard that nothing else uses, for a test"
private_board() = (Base.Libc.Libdl.dlopen(AppKit); msg(cls("NSPasteboard"), "pasteboardWithUniqueName"))

"How many bytes or items `x` holds"
howmany(x::Object, name) = ccall((:objc_msgSend, libobjc), UInt, (Object, Object), x, sel(name))

"The text that the clipboard holds, or \"\""
text() = (h = HELD[]; h === nothing ? text(board()) : h.text)
text(pb::Object) = begin
  Sys.isapple() || return ""
  with_pool(() -> jstring(msg(pb, "stringForType:", nsstring("public.utf8-plain-text"))))
end

"The files and folders that the clipboard holds, as paths: what ⌘C in the Finder copies"
files() = (h = HELD[]; h === nothing ? files(board()) : copy(h.files))
files(pb::Object) = begin
  out = String[]
  Sys.isapple() || return out
  with_pool() do
    items = msg(pb, "pasteboardItems")
    items == C_NULL && return out
    for i in 0:Int(howmany(items, "count"))-1
      item = ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), items, sel("objectAtIndex:"), i)
      address = msg(item, "stringForType:", nsstring("public.file-url"))
      address == C_NULL && continue
      url = msg(cls("NSURL"), "URLWithString:", address)
      url == C_NULL && continue
      # The Finder can name a file by its number on the disk. This gives its path.
      url = msg(url, "filePathURL")
      url == C_NULL && continue
      path = jstring(msg(url, "path"))
      ispath(path) && push!(out, path)
    end
    out
  end
end

"The text of the vCard that the clipboard holds, or \"\": what ⌘C copies in the Contacts app"
vcard() = changed_since_held() ? "" : vcard(board())
vcard(pb::Object) = begin
  Sys.isapple() || return ""
  with_pool() do
    data = msg(pb, "dataForType:", nsstring("public.vcard"))
    data == C_NULL ? "" : String(bytes(data))
  end
end

# The kinds of media that a clipboard can hold as data, by macOS's name for each, and the end
# of the name of a file of that kind. The first kind that the clipboard has is the one taken,
# so a picture that's there as a PNG and as a PDF is taken as a PNG.
const KINDS = ["public.png" => "png", "public.jpeg" => "jpg", "com.compuserve.gif" => "gif", "org.webmproject.webp" => "webp",
               "public.tiff" => "tiff", "com.adobe.pdf" => "pdf", "public.mpeg-4" => "mp4", "com.apple.quicktime-movie" => "mov",
               "public.mp3" => "mp3", "com.apple.m4a-audio" => "m4a", "com.microsoft.waveform-audio" => "wav"]

"The bytes of an NSData"
bytes(data::Object) = copy(unsafe_wrap(Array, Ptr{UInt8}(msg(data, "bytes")), Int(howmany(data, "length"))))

"A TIFF picture as the data of a PNG file, which is smaller and shows anywhere"
png(tiff::Object) = begin
  picture = msg(cls("NSBitmapImageRep"), "imageRepWithData:", tiff)
  picture == C_NULL && return C_NULL
  # 4 is NSBitmapImageFileTypePNG
  ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt, Object), picture, sel("representationUsingType:properties:"),
        4, msg(cls("NSDictionary"), "dictionary"))
end

"""
The picture, sound, video or PDF that the clipboard holds as data: the end of
the name of a file of its kind, like "png", and its bytes. Nothing if it holds
none. A screenshot that's copied is one of these.
"""
media() = (h = HELD[]; h === nothing ? media(board()) : h.read ? h.media : changed_since_held() ? nothing : media(board()))
media(pb::Object) = begin
  Sys.isapple() || return nothing
  with_pool() do
    for (kind, ext) in KINDS
      data = msg(pb, "dataForType:", nsstring(kind))
      data == C_NULL && continue
      if ext == "tiff"
        data = png(data)
        data == C_NULL && continue
        ext = "png"
      end
      howmany(data, "length") == 0 && continue
      return (ext, bytes(data))
    end
    nothing
  end
end

# --- what the clipboard held when a key was pressed ---------------------------------

"""
What the clipboard held at one moment: its files, its text, and its picture
or other media. `count` is the number that macOS gives the clipboard, which
goes up each time the clipboard changes. The media is read only when the
clipboard has no file and no text but an address, since that's when a paste
takes it, and `read` says whether it was.
"""
struct Held
  count::Int
  files::Vector{String}
  text::String
  read::Bool
  media::Union{Nothing,Tuple{String,Vector{UInt8}}}
end

"What the clipboard held when `hold!` read it, until `release!`. Nothing at any other time."
const HELD = Ref{Union{Nothing,Held}}(nothing)

"The number that macOS gives the clipboard `pb`, which goes up each time the clipboard changes"
changes(pb::Object=board()) = Sys.isapple() ? ccall((:objc_msgSend, libobjc), Int, (Object, Object), pb, sel("changeCount")) : 0

"True when the clipboard has changed since `hold!` read it"
changed_since_held() = (h = HELD[]; h !== nothing && changes() != h.count)

"What the clipboard `pb` holds now"
now(pb::Object=board()) = begin
  count, paths, words = changes(pb), files(pb), text(pb)
  # A picture that's copied from a web page comes with its address as text, and the picture is what a paste takes
  read = isempty(paths) && (isempty(strip(words)) || occursin(r"^\s*\w+://\S+\s*$", words))
  Held(count, paths, words, read, read ? media(pb) : nothing)
end

"""
Read the clipboard now, and keep what it holds until `release!`. Until then,
`files`, `text` and `media` give what the clipboard held at this moment,
whatever another app has put on it since. The key that pastes calls this as
soon as it's pressed, before any code that Julia has yet to compile. True
when this call read the clipboard, and false when an earlier one still keeps
what it read: only the call that got true calls `release!`.
"""
hold!() = begin
  HELD[] === nothing || return false
  HELD[] = now()
  true
end

"Stop keeping what `hold!` read, so the clipboard is read as it is again"
release!() = (HELD[] = nothing)

"Call `f` between a `hold!` and its `release!`"
held(f) = begin
  mine = hold!()
  try
    f()
  finally
    mine && release!()
  end
end

# Julia compiles these now, not at the first paste, when the clipboard has little time before it changes
precompile(hold!, ())
precompile(release!, ())
precompile(now, (Object,))
