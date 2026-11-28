# Tests for the sandbox of a page from a web server, whose site you don't
# trust: its code runs, but each call that could harm the Mac stops and asks
# you. See "the sandbox" in sandbox.jl and guard.jl. Run them with
# `julia -O0 --project=. test/sandbox_page_test.jl`. A function of the tests
# stands in for `curl`, so they use no network, and the window isn't on the
# screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window
@use "github.com/jkroso/UI.jl/Interface/draw" frame
@use "./drive" drive
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
K.BROWSER_FOLDER[] = joinpath(dir, "Browser")
const ran = joinpath(dir, "ran")   # a file that harmful code would make

const SITE = Dict{String,String}()
const was_getter, was_asker, was_trust = K.PAGE_GETTER[], K.SANDBOX_ASKER[], K.SITE_ASKER[]
K.PAGE_GETTER[] = (address, file, about) -> begin
  text = get(SITE, address, nothing)
  text === nothing ? (write(file, "Not found"); write(about, "$address\ntext/plain\n404\n")) :
                     (write(file, text); write(about, "$address\ntext/markdown; charset=utf-8\n200\n"))
  () -> true
end
"Each action that the sandbox asked about, with its site, and the answer that the stand-in for the panel gives"
const asks = Tuple{String,String}[]
const answer = Ref(false)
K.SANDBOX_ASKER[] = (site, a) -> (push!(asks, (site, a.words)); answer[])
const trusts = String[]
const trust = Ref(true)
K.SITE_ASKER[] = site -> (push!(trusts, site); trust[])

const problems_before = length(K.problems)
const e = K.blank_editor()
const w = Window(e, size=(1000px, 800px))
const (; frames) = drive(w, frames=3)
frames()

const site = "https://sums.example.com"
SITE["$site/page.md"] = """
  # Sums

  Say !`n = 6` and so !`twice = 2n`.

  ```sheet
  A = 1 to 3
  B = A * n
  ```

  ```ui
  touch($(repr(ran)))
  ```

  ```load
  from: /etc/hosts
  ```
  """
sheets() = count(it -> it.content isa K.Sheet, e.layout)

@testset "a page of a site that you don't trust runs its code in the sandbox" begin
  K.navigate!(e, "sums.example.com/page.md"); frames(6)
  b = e.buf
  @test K.web_address(b.path) == "$site/page.md"
  @test K.sandboxed(b.path) && !K.foreign(b.path) && K.site_runs(site) !== true
  # Its sums and its sheet run, as they would on a page of the Mac
  @test K.made(e, "twice", 3) == ("12", false)
  @test sheets() == 1
  lang(open) = K.kinds(b)[findfirst(==(open), b.lines)].lang
  @test lang("```sheet") == "sheet" && lang("```ui") == K.LIVE
  # A block that Ladder would read a file of the Mac for shows as its code
  @test lang("```load") == ""
  # The `ui` block wanted to make a file: the sandbox stopped it, and Ladder asked you once
  @test !ispath(ran)
  @test asks == [(site, "make $(basename(ran)) in $(basename(dir))")] || asks == [(site, "change $(basename(ran)) in $(basename(dir))")]
  frames(4)
  @test length(asks) == 1
  # Code that you run by hand on the page runs in the sandbox too
  out = K.run_code(e, "rm($(repr(K.settings_file())))")
  @test out[3] && out[1] isa K.Guard.Stopped
end

@testset "a no lasts while Ladder is open, and a yes lets the site's code do it" begin
  # You said no, so the page doesn't ask again each time its code runs
  empty!(asks)
  K.reset_module!(e); frames(6)
  @test isempty(asks) && !ispath(ran)
  # Ladder forgets a no when it quits
  K.SANDBOX_NO[] = Set{Tuple{String,String}}()
  answer[] = true
  K.reset_module!(e); frames(6)
  @test length(asks) == 1 && isfile(ran)
  @test occursin("sums.example.com", read(K.sandbox_file(), String))
  # The yes is kept, so the code goes on with no question from then on
  rm(ran)
  K.reset_module!(e); frames(6)
  @test length(asks) == 1 && isfile(ran)
  rm(ran)
  answer[] = false
end

@testset "the shield in the top bar trusts the site" begin
  empty!(asks); empty!(trusts)
  b = e.buf
  @test K.works_here(e, Val(:trust_site)) && !K.works_here(e, Val(:stop_trusting_site))
  @test K.trust_bar(e)[1].icon == "shield-lock"
  # A click asks whether you trust the site. Cancel leaves it in the sandbox.
  trust[] = false
  K.BUTTONS[:trust].run(e); frames(4)
  @test trusts == [site] && K.site_runs(site) !== true && K.sandboxed(b.path)
  trust[] = true
  K.BUTTONS[:trust].run(e); frames(6)
  @test K.site_runs(site) === true && !K.sandboxed(b.path)
  @test K.trust_bar(e)[1].icon == "shield-slash"
  # Its code runs as yours does, with no sandbox: the page's module is new
  @test K.sandbox_of(K.page_module(e, b.path), b.path) === nothing
  @test K.made(e, "twice", 3) == ("12", false) && sheets() == 1
  # A click puts it back in the sandbox, with no question
  n = length(trusts)
  K.BUTTONS[:trust].run(e); frames(6)
  @test length(trusts) == n && K.site_runs(site) === false && K.sandboxed(b.path)
  @test K.sandbox_of(K.page_module(e, b.path), b.path) isa K.Guard.Context
end

@testset "an agent reads a package that isn't on the Mac, and then Ladder asks again" begin
  pkg_site = "https://pkg.example.com"
  SITE["$pkg_site/page.md"] = """
    # A package

    ```ui
    @use "github.com/nobody-here/Blocks.jl" block
    block()
    ```
    """
  checks = Tuple{String,String,Bool,String}[]
  was = (K.SANDBOX_ASKER[], K.PACKAGE_ASKER[], K.PACKAGE_DOWNLOADER[], K.PACKAGE_READER[], K.PACKAGE_AGENT[])
  K.SANDBOX_ASKER[] = (site, a) -> (push!(asks, (site, a.words)); :check)
  # Ladder downloads the package with git: the stand-in makes a folder with a file in it
  K.PACKAGE_DOWNLOADER[] = (url, folder) -> `sh -c "mkdir -p \"\$1\" && echo 'block() = 1' > \"\$1/main.jl\"" sh $folder`
  # The agent reads it: the stand-in says what an agent would, after it looks at the folder that it starts in
  K.PACKAGE_READER[] = `sh -c "test -f main.jl && printf '**SAFE**\nIt only gives back a number.\n'"`
  K.PACKAGE_AGENT[] = "Claude"
  # You don't let the site load it, so no window asks GitHub for it
  K.PACKAGE_ASKER[] = (site, c) -> (push!(checks, (site, c.repo, c.safe, c.words)); false)
  try
    empty!(asks)
    K.navigate!(e, "pkg.example.com/page.md"); frames(6)
    @test asks == [(pkg_site, "load the package nobody-here/Blocks.jl from GitHub, which isn't on your Mac yet")]
    @test occursin("Claude is reading the package nobody-here/Blocks.jl", something(K.said_result(e), ("", 0.0))[1])
    for _ in 1:100
      isempty(checks) || break
      sleep(0.05); frames(1)
    end
    @test checks == [(pkg_site, "nobody-here/Blocks.jl", true, "It only gives back a number.")]
    @test isempty(K.PACKAGE_CHECKS) && K.sandbox_answer(pkg_site, "package github.com/nobody-here/Blocks.jl") === false
    # The downloaded package is gone once you've answered
    @test !ispath(joinpath(K.package_checks_dir(), "nobody-here Blocks.jl"))
    # What an agent says: the first line says whether it's safe, and an answer that isn't clear isn't
    @test K.package_verdict("UNSAFE\nIt deletes files.\n") == (false, "It deletes files.")
    @test K.package_verdict("## Safe.\nIt adds.") == (true, "It adds.")
    @test !K.package_verdict("I think it's fine.")[1] && !K.package_verdict("")[1]
  finally
    K.SANDBOX_ASKER[], K.PACKAGE_ASKER[], K.PACKAGE_DOWNLOADER[], K.PACKAGE_READER[], K.PACKAGE_AGENT[] = was
  end
end

@testset "an email still runs no code" begin
  @test K.foreign(joinpath(dir, "note.eml")) && !K.sandboxed(joinpath(dir, "mine.md"))
end

K.PAGE_GETTER[], K.SANDBOX_ASKER[], K.SITE_ASKER[] = was_getter, was_asker, was_trust
# The errors of the code that the sandbox stopped go, for the tests that share this process
resize!(K.problems, problems_before)
