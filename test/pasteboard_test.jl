# Tests for pasteboard.jl. Run them with `julia -O0 --project=. test/pasteboard_test.jl`.
# They use a clipboard of their own, so the Mac's clipboard stays as it is.

@use Test: @test, @testset
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring
@use "../pasteboard" => P

const Object = Ptr{Cvoid}
const pb = P.private_board()
clear() = msg(pb, "clearContents")
put_text(kind, s) = ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Object, Object), pb, sel("setString:forType:"), nsstring(s), nsstring(kind))
put_data(kind, bytes) = begin
  data = ccall((:objc_msgSend, libobjc), Object, (Object, Object, Ptr{UInt8}, UInt), cls("NSData"), sel("dataWithBytes:length:"), bytes, length(bytes))
  ccall((:objc_msgSend, libobjc), Bool, (Object, Object, Object, Object), pb, sel("setData:forType:"), data, nsstring(kind))
end

const PNG = read(joinpath(@__DIR__, "..", "app", "icon.png"))
const PDF = Vector{UInt8}("%PDF-1.4")

@testset "what the clipboard holds" begin
  clear()
  @test P.text(pb) == "" && isempty(P.files(pb)) && P.media(pb) === nothing
  clear(); put_text("public.utf8-plain-text", "héllo\nworld")
  @test P.text(pb) == "héllo\nworld"
  @test P.media(pb) === nothing
  clear(); put_data("public.png", PNG)
  @test P.media(pb) == ("png", PNG)
  @test P.text(pb) == ""
  # A picture that's there as a PDF too is taken as a PNG
  clear(); put_data("com.adobe.pdf", PDF); put_data("public.png", PNG)
  @test P.media(pb)[1] == "png"
  clear(); put_data("com.adobe.pdf", PDF)
  @test P.media(pb) == ("pdf", PDF)
end

@testset "a TIFF picture comes out as a PNG" begin
  dir = mktempdir()
  tiff = joinpath(dir, "icon.tiff")
  run(pipeline(`sips -s format tiff $(joinpath(@__DIR__, "..", "app", "icon.png")) --out $tiff`, stdout=devnull, stderr=devnull))
  clear(); put_data("public.tiff", read(tiff))
  ext, bytes = P.media(pb)
  @test ext == "png"
  @test bytes[1:8] == PNG[1:8]
  rm(dir, recursive=true)
end

@testset "a contact that was copied in the Contacts app" begin
  card = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Émile Zola\r\nEND:VCARD\r\n"
  clear()
  @test P.vcard(pb) == ""
  # The Contacts app puts the vCard there as data, beside the name as text
  clear(); put_data("public.vcard", Vector{UInt8}(card)); put_text("public.utf8-plain-text", "Émile Zola")
  @test P.vcard(pb) == card && P.text(pb) == "Émile Zola"
end

@testset "what the clipboard held when a key was pressed" begin
  P.other[] = pb
  try
    # An app that takes dictation puts its words there, presses ⌘V, and puts a picture back before the paste reads
    clear(); put_text("public.utf8-plain-text", "dictated words")
    P.held() do
      clear(); put_data("public.png", PNG)
      @test P.text() == "dictated words" && isempty(P.files()) && P.media() === nothing && P.vcard() == ""
      # A second `held` inside the first reads nothing again
      P.held(() -> @test P.text() == "dictated words")
      @test P.HELD[] !== nothing
    end
    # After it, the clipboard is read as it is now
    @test P.HELD[] === nothing && P.text() == "" && P.media() == ("png", PNG)
    # A picture is kept too, and so is one that came with its address
    P.held() do
      clear(); put_text("public.utf8-plain-text", "later words")
      @test P.media() == ("png", PNG) && P.text() == ""
    end
    clear(); put_text("public.utf8-plain-text", "https://example.com/a.png"); put_data("public.png", PNG)
    P.held() do
      clear()
      @test P.media() == ("png", PNG) && P.text() == "https://example.com/a.png"
    end
    # While the clipboard stays as it was, what `held` didn't read is read from it
    card = "BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Alan Kay\r\nEND:VCARD\r\n"
    clear(); put_data("public.vcard", Vector{UInt8}(card)); put_text("public.utf8-plain-text", "Alan Kay"); put_data("public.png", PNG)
    P.held() do
      @test P.vcard() == card && P.text() == "Alan Kay" && P.media() == ("png", PNG)
      clear()
      @test P.vcard() == "" && P.text() == "Alan Kay" && P.media() === nothing
    end
    # An error in the function leaves nothing held
    clear(); put_text("public.utf8-plain-text", "words")
    @test try P.held(() -> error("stop")) catch; true end
    @test P.HELD[] === nothing
    # `hold!` says whether it read the clipboard, and only that call's `release!` is due
    @test P.hold!() && !P.hold!() && P.text() == "words"
    clear()
    @test P.text() == "words"
    P.release!()
    @test P.HELD[] === nothing && P.text() == ""
  finally
    P.other[] = C_NULL
  end
end

@testset "files that were copied in the Finder" begin
  dir = mktempdir()
  file = joinpath(dir, "clip one.mp4")
  write(file, "x")
  clear(); put_text("public.file-url", "file://" * replace(file, " " => "%20")); put_text("public.utf8-plain-text", "clip one.mp4")
  @test P.files(pb) == [realpath(file)] || P.files(pb) == [file]
  # A file that's gone isn't listed
  rm(dir, recursive=true)
  @test isempty(P.files(pb))
end
