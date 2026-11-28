# Tests for zip.jl: what a zip file holds. Run them with
# `julia -O0 --project=. test/zip_test.jl`. They make zip files in a temporary
# folder with the Mac's own `zip` and `ditto`, and draw no window.

@use Test: @test, @testset, @test_throws
@use "../folders/zip" => Z

const dir = mktempdir()
const src = joinpath(dir, "plans")
mkpath(joinpath(src, "house", "old"))
write(joinpath(src, "Readme.md"), "# Plans\n\nWhat's here.\n")
write(joinpath(src, "house", "notes.md"), "# Notes\n" * "A line of words that packs well.\n"^200)
write(joinpath(src, "house", "old", "first.txt"), "first\n")
write(joinpath(src, "house", "empty.txt"), "")
write(joinpath(src, "data.bin"), UInt8[i % 256 for i in 1:5000])
write(joinpath(src, ".DS_Store"), "the Finder's own")

const file = joinpath(dir, "plans.zip")
cd(() -> run(pipeline(`zip -r -q $file plans`, stdout=devnull, stderr=devnull)), dir)

@testset "the list of what a zip file holds" begin
  z = Z.contents(file)
  @test [en.name for en in z.entries] == ["plans/", "plans/data.bin", "plans/house/", "plans/house/empty.txt", "plans/house/notes.md",
                                          "plans/house/old/", "plans/house/old/first.txt", "plans/Readme.md"]
  @test Z.files(z) == 5
  notes = only(en for en in z.entries if en.name == "plans/house/notes.md")
  @test notes.size == filesize(joinpath(src, "house", "notes.md"))
  @test notes.packed < notes.size ÷ 10 && notes.method == 8
  @test abs(notes.changed - mtime(joinpath(src, "house", "notes.md"))) <= 2   # a zip file keeps the time to 2 seconds
  @test z.size == sum(filesize(joinpath(root, f)) for (root, _, fs) in walkdir(src) for f in fs if f != ".DS_Store")
end

@testset "what's in one folder: its folders, then its files" begin
  z = Z.contents(file)
  @test [en.name for en in Z.under(z)] == ["plans/"]
  @test [Z.short(en) for en in Z.under(z, "plans/")] == ["house", "data.bin", "Readme.md"]
  @test [Z.short(en) for en in Z.under(z, "plans/house/")] == ["old", "empty.txt", "notes.md"]
  @test Z.depth(z.entries[1]) == 0 && Z.depth(only(Z.under(z, "plans/house/old/"))) == 3
end

@testset "the bytes of one file" begin
  z = Z.contents(file)
  get(name) = Z.bytes(file, only(en for en in z.entries if en.name == name))
  @test String(get("plans/Readme.md")) == "# Plans\n\nWhat's here.\n"
  @test get("plans/house/notes.md") == read(joinpath(src, "house", "notes.md"))
  @test get("plans/data.bin") == read(joinpath(src, "data.bin"))
  @test get("plans/house/empty.txt") == UInt8[]
  @test_throws ErrorException Z.bytes(file, z.entries[1])   # a folder has no bytes
end

@testset "one file written out, where it can't be changed" begin
  z = Z.contents(file)
  out = joinpath(dir, "out")
  en = only(en for en in z.entries if en.name == "plans/house/old/first.txt")
  path = Z.keep(file, en, out)
  @test path == joinpath(out, "plans", "house", "old", "first.txt")
  @test read(path, String) == "first\n"
  @test !iswritable(path)
  at = mtime(path)
  @test Z.keep(file, en, out) == path && mtime(path) == at   # it's kept, and not written again
end

@testset "a zip file that the Finder would make has none of the Finder's own files" begin
  mac = joinpath(dir, "mac.zip")
  run(pipeline(`ditto -c -k --sequesterRsrc --keepParent $src $mac`, stdout=devnull, stderr=devnull))
  z = Z.contents(mac)
  @test !any(en -> occursin("__MACOSX", en.name) || occursin(".DS_Store", en.name), z.entries)
  @test Z.files(z) == 5
end

@testset "files that aren't packed, and a zip file with no folder entries" begin
  flat = joinpath(dir, "flat.zip")
  cd(() -> run(pipeline(`zip -0 -D -q $flat plans/Readme.md plans/house/notes.md`, stdout=devnull, stderr=devnull)), dir)
  z = Z.contents(flat)
  # The folders have entries all the same, so each file has its folders above it
  @test [en.name for en in z.entries] == ["plans/", "plans/house/", "plans/house/notes.md", "plans/Readme.md"]
  @test only(en for en in z.entries if en.name == "plans/Readme.md").method == 0
  @test String(Z.bytes(flat, z.entries[end])) == "# Plans\n\nWhat's here.\n"
end

@testset "a file that isn't a zip file says why" begin
  bad = joinpath(dir, "bad.zip")
  write(bad, "These are words, and not a zip file. " ^ 4)
  @test_throws Z.NotZip Z.contents(bad)
  write(bad, "short")
  @test_throws Z.NotZip Z.contents(bad)
  empty = joinpath(dir, "empty.zip")
  write(empty, UInt8[0x50, 0x4b, 0x05, 0x06, zeros(UInt8, 18)...])   # a zip file with nothing in it is only its end
  @test isempty(Z.contents(empty).entries)
end

@testset "a file that's locked with a password is listed, and its bytes aren't given" begin
  locked = joinpath(dir, "locked.zip")
  cd(() -> run(pipeline(`zip -q -P secret $locked plans/Readme.md`, stdout=devnull, stderr=devnull)), dir)
  z = Z.contents(locked)
  en = only(en for en in z.entries if !Z.isfolder(en))
  @test en.locked
  @test_throws ErrorException Z.bytes(locked, en)
end

@testset "sizes in words" begin
  @test Z.size_words(512) == "512 bytes"
  @test Z.size_words(48_213) == "48 KB"
  @test Z.size_words(3_400_000) == "3.4 MB"
end
