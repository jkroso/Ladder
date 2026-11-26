# Tests for macfolders.jl: what macOS knows about the files of Downloads, of the
# folder of the screenshots and of the Trash. Run them with
# `julia -O0 --project=. test/macfolders_test.jl`. They use a temporary folder,
# never the Mac's own Downloads or Trash, and draw no window.

@use Test: @test, @testset, @test_throws
@use "../macfolders" => M
@use Dates: Dates, DateTime

const dir = mktempdir()

include(joinpath(@__DIR__, "dsstore_fake.jl"))   # `store` makes the bytes of a .DS_Store file

@testset "the groups of days, as the Finder names them" begin
  now = Dates.datetime2unix(DateTime(2026, 11, 20, 3)) + 12 * 3600   # the middle of a day, in any time zone
  day = 86400
  @test M.day_name(now, now) == "Today"
  @test M.day_name(now - day, now) == "Yesterday"
  @test M.day_name(now - 3day, now) == "Previous 7 Days"
  @test M.day_name(now - 7day, now) == "Previous 7 Days"
  @test M.day_name(now - 8day, now) == "Previous 30 Days"
  @test M.day_name(now - 30day, now) == "Previous 30 Days"
  @test M.day_name(now - 40day, now) == "October 2026"
  @test M.day_name(now - 400day, now) == "October 2025"
  @test M.date_name(now, now) == "Today" && M.date_name(now - day, now) == "Yesterday"
  # The day's own name is in the Mac's time zone, so the test asks for it the same way
  @test M.date_name(now - 5day, now) == Libc.strftime("%A %-d %B %Y", now - 5day)
  @test occursin(r"^\w+day \d+ November 2026$", M.date_name(now - 5day, now))
  @test occursin(':', M.when(now, now)) && occursin(r"^\d+ Nov 2026$", M.when(now - 5day, now))
end

@testset "the site of an address" begin
  @test M.site_name("https://www.github.com/jkroso/Ladder/releases/Ladder.zip") == "github.com"
  @test M.site_name("http://user@Example.org:8080/a?b=1") == "example.org"
  @test M.site_name("file:///Users/jake/a.pdf") == ""
  @test M.site_name("not an address") == ""
end

@testset "when a file came into its folder" begin
  f = joinpath(dir, "a.txt")
  write(f, "a")
  @test abs(M.added(f) - time()) < 60
  @test abs(M.made(f) - time()) < 60
end

if Sys.isapple()
  @testset "the site that a downloaded file came from" begin
    f = joinpath(dir, "download.pdf")
    write(f, "pdf")
    @test M.site(f) == "" && M.sources(f) == []
    list = joinpath(dir, "from.plist")
    write(list, """<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><array>
      <string>https://files.example.net/get/download.pdf</string><string>https://www.council.example.org/forms</string></array></plist>""")
    run(`plutil -convert binary1 $list`)
    run(`xattr -wx com.apple.metadata:kMDItemWhereFroms $(bytes2hex(read(list))) $f`)
    @test M.sources(f) == ["https://files.example.net/get/download.pdf", "https://www.council.example.org/forms"]
    @test M.site(f) == "council.example.org"   # the page that had the link
    # A file that was saved with no page has the site of its own address
    write(list, """<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><array>
      <string>https://files.example.net/get/download.pdf</string><string></string></array></plist>""")
    run(`plutil -convert binary1 $list`)
    run(`xattr -wx com.apple.metadata:kMDItemWhereFroms $(bytes2hex(read(list))) $f`)
    @test M.site(f) == "files.example.net"
  end
end

@testset "where each thing in the Trash came from" begin
  trash = mkpath(joinpath(dir, "Trash"))
  home = mkpath(joinpath(dir, "disk", "Users", "sam", "Desktop"))
  write(joinpath(trash, ".DS_Store"), store([
    ("plan.pdf", "ptbL", "Users/sam/Desktop/"), ("plan.pdf", "ptbN", "plan.pdf"),
    ("notes 10.42.07 am.md", "ptbL", "Users/sam/Desktop/"), ("notes 10.42.07 am.md", "ptbN", "notes.md"),
    ("Ünïcode ✓.txt", "ptbL", "Users/sam/"), ("Ünïcode ✓.txt", "ptbN", "Ünïcode ✓.txt")]))
  recs = M.records(read(joinpath(trash, ".DS_Store")))
  @test length(recs) == 6 && recs[1] == ("plan.pdf", "ptbL", "Users/sam/Desktop/")
  o = M.origins(trash, disk=joinpath(dir, "disk"))
  @test o["plan.pdf"] == M.Origin(folder=home, name="plan.pdf")
  @test o["notes 10.42.07 am.md"].name == "notes.md"   # the Trash had a notes.md already, so the Finder gave it another name there
  @test o["Ünïcode ✓.txt"].folder == dirname(home)
  # A Trash with no such file, or with a damaged one, says nothing
  @test isempty(M.origins(mkpath(joinpath(dir, "Empty"))))
  write(joinpath(dir, "Empty", ".DS_Store"), "not the Finder's file")
  @test isempty(M.origins(joinpath(dir, "Empty")))
  @test_throws ErrorException M.records(Vector{UInt8}("not the Finder's file, and long enough to look"))
  @test M.plain("/System/Volumes/Data/Users/sam/Desktop") == "/Users/sam/Desktop"
  @test M.plain("/Users/sam/Desktop") == "/Users/sam/Desktop"
end

@testset "a thing goes back to where it was" begin
  trash = mkpath(joinpath(dir, "Trash2"))
  was = mkpath(joinpath(dir, "was"))
  write(joinpath(trash, "plan 2.pdf"), "the plan")
  to = M.put_back!(joinpath(trash, "plan 2.pdf"), M.Origin(folder=was, name="plan.pdf"))
  @test to == joinpath(was, "plan.pdf") && read(to, String) == "the plan"
  @test !ispath(joinpath(trash, "plan 2.pdf"))
  # A file that has its name there now keeps it, and this one gets a number
  write(joinpath(trash, "plan.pdf"), "a newer plan")
  to = M.put_back!(joinpath(trash, "plan.pdf"), M.Origin(folder=was, name="plan.pdf"))
  @test to == joinpath(was, "plan 2.pdf") && read(joinpath(was, "plan.pdf"), String) == "the plan"
  # A folder goes back with what's in it
  mkpath(joinpath(trash, "box", "inner"))
  write(joinpath(trash, "box", "inner", "a.txt"), "a")
  @test isfile(joinpath(M.put_back!(joinpath(trash, "box"), M.Origin(folder=was, name="box")), "inner", "a.txt"))
  # The folder that it was in is gone
  write(joinpath(trash, "lost.txt"), "lost")
  @test_throws ErrorException M.put_back!(joinpath(trash, "lost.txt"), M.Origin(folder=joinpath(dir, "gone"), name="lost.txt"))
  @test isfile(joinpath(trash, "lost.txt"))
end

@testset "the folder of the screenshots is a folder that's there" begin
  @test isdir(M.screenshots())
end
