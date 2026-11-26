# Tests for the app's own updates: update.jl, and the part of the settings page
# that shows them. Run them with `julia -O0 --project=. test/update_test.jl`.
#
# They make small apps in a temporary folder, each signed for this Mac with a
# name of its own, and a release of each as a zip file with a latest.txt. The
# updater reads the release from that folder, so the tests use no network. The
# rule that a new version must pass is that its signature has the name
# "test.ladder.update". The app of a real release must have the signature of
# Ladder's developer.

@use Test: @test, @testset
@use "../update" => Update
@use "../main" => K
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const NAME = "test.ladder.update"
const RULE = "identifier \"$NAME\""
const root = mktempdir()

"Make an app at `at` that says it's `version`, signed for this Mac with the name `id`"
make_app(at, version; id=NAME) = begin
  mkpath(joinpath(at, "Contents", "MacOS"))
  write(joinpath(at, "Contents", "Info.plist"), """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0"><dict>
      <key>CFBundleIdentifier</key><string>$id</string>
      <key>CFBundleExecutable</key><string>fixture</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleShortVersionString</key><string>$version</string>
    </dict></plist>
    """)
  program = joinpath(at, "Contents", "MacOS", "fixture")
  # A test that opens the app sees which version opened from the file that it writes beside itself
  write(program, "#!/bin/sh\necho $version > \"\$(dirname \"\$0\")/../../../opened\"\n")
  chmod(program, 0o755)
  run(pipeline(`codesign --force --sign - --identifier $id $at`, stderr=devnull))
  at
end

"The version that the app at `app` says it is"
version_of(app) = readchomp(`plutil -extract CFBundleShortVersionString raw $(joinpath(app, "Contents", "Info.plist"))`)

"""
A folder with a release of `version`: the zip file of an app and latest.txt.
Returns the address of latest.txt. `spoil` changes the app after it's signed
and before it's zipped.
"""
release(version; id=NAME, macos="12.0", spoil=app -> nothing) = begin
  dir = mktempdir(root)
  app = make_app(joinpath(dir, "Fixture.app"), version; id)
  spoil(app)
  zip = joinpath(dir, "Fixture-$version.zip")
  run(`ditto -c -k --keepParent $app $zip`)
  rm(app, recursive=true)
  "file://" * Update.announce(dir, version, zip; macos)
end

"An app of `version` that's installed, and its updater, which reads the release at `feed`"
installed(version, feed) = begin
  dir = mktempdir(root)
  app = make_app(joinpath(dir, "Applications", "Fixture.app"), version)
  Update.Updater(app, VersionNumber(version); feed, dir=joinpath(dir, "update"), rule=RULE, register="/usr/bin/true")
end

"The number of a process that has ended"
ended() = (p = run(`sleep 0.3`, wait=false); pid = getpid(p); wait(p); pid)

"Put the version that waits in the app's place, as happens once Ladder has quit"
install!(u) = success(run(ignorestatus(Update.install(u, ended()))))

@testset "what latest.txt names" begin
  sum = repeat("ab", 32)
  @test Update.parse_feed("version=0.2.0\nfile=Ladder-0.2.0.zip\nsha256=$sum\nmacos=13.0\n") == (v"0.2.0", "Ladder-0.2.0.zip", sum, v"13")
  @test Update.parse_feed("version=0.2.0\r\nfile=Ladder-0.2.0.zip\r\nsha256=$(uppercase(sum))\r\n") == (v"0.2.0", "Ladder-0.2.0.zip", sum, v"0")
  @test Update.parse_feed("") === nothing
  @test Update.parse_feed("<html>Not Found</html>") === nothing
  @test Update.parse_feed("version=0.2.0\nfile=Ladder-0.2.0.zip\n") === nothing               # no sum
  @test Update.parse_feed("version=two\nfile=Ladder.zip\nsha256=$sum\n") === nothing           # not a version
  @test Update.parse_feed("version=0.2\nfile=Ladder.zip\nsha256=$sum\n") === nothing           # not written as the app writes it
  # The file is a name beside latest.txt: not a path, and not an address
  @test Update.parse_feed("version=0.2.0\nfile=../Ladder.zip\nsha256=$sum\n") === nothing
  @test Update.parse_feed("version=0.2.0\nfile=https://example.com/Ladder.zip\nsha256=$sum\n") === nothing
end

@testset "a newer version comes, waits, and takes the app's place" begin
  u = installed("1.0.0", release("1.1.0"))
  @test Update.says(u) == "This is Ladder 1.0.0."
  @test Update.action(u) === :check
  @test Update.tick!(u) == Update.POLL    # the first frame starts to look
  @test u.stage === :checking
  @test Update.action(u) === :none
  Update.finish!(u)
  @test u.newest == v"1.1.0"
  @test u.staged == v"1.1.0"
  @test Update.says(u) == "Ladder 1.1.0 is ready. It takes the place of version 1.0.0 when you quit Ladder."
  @test Update.label(u) == "Restart to update"
  @test version_of(u.app) == "1.0.0"      # nothing has changed in the app yet
  @test Update.tick!(u) == Inf            # and it doesn't look again for a day
  @test install!(u)
  @test version_of(u.app) == "1.1.0"
  @test success(`codesign --verify --deep --strict $(u.app)`)
  @test !ispath(Update.staged_app(u)) && !ispath(Update.ready_file(u))
  @test readdir(dirname(u.app)) == ["Fixture.app"]   # the old app is gone, with nothing left beside the new one
end

@testset "the newest version is the one that's running" begin
  u = installed("1.1.0", release("1.1.0"))
  Update.tick!(u)
  Update.finish!(u)
  @test u.staged === nothing
  @test Update.says(u) == "This is Ladder 1.1.0, the newest version."
  @test Update.label(u) == "Check now"
  @test !Update.quit!(u)
  # An older release doesn't take the app back
  u = installed("1.2.0", release("1.1.0"))
  Update.tick!(u)
  Update.finish!(u)
  @test u.staged === nothing
  @test Update.says(u) == "This is Ladder 1.2.0, the newest version."
end

@testset "an app that someone else signed is left alone" begin
  u = installed("1.0.0", release("1.1.0", id="test.someone.else"))
  Update.tick!(u)
  Update.finish!(u)
  @test u.staged === nothing
  @test Update.says(u) == "Ladder's developer didn't sign the app that came, so Ladder left it alone. Ladder tries again in an hour."
  @test !ispath(Update.staged_app(u)) && !ispath(joinpath(u.dir, "new"))
  @test Update.tick!(u) == Inf            # not before the hour is up
  @test 0 < u.next - time() <= Update.RETRY
  @test !Update.quit!(u)
  @test version_of(u.app) == "1.0.0"
end

@testset "an app that changed after it was signed is left alone" begin
  u = installed("1.0.0", release("1.1.0", spoil=app -> write(joinpath(app, "Contents", "MacOS", "fixture"), "#!/bin/sh\necho changed\n")))
  Update.tick!(u)
  Update.finish!(u)
  @test u.staged === nothing
  @test startswith(Update.says(u), "Ladder's developer didn't sign the app that came")
end

@testset "a zip file that isn't the one that was released is left alone" begin
  feed = release("1.1.0")
  dir = dirname(feed[8:end])
  other = make_app(joinpath(mktempdir(root), "Fixture.app"), "1.1.0")
  write(joinpath(other, "Contents", "extra"), "more")
  rm(joinpath(dir, "Fixture-1.1.0.zip"))
  run(`ditto -c -k --keepParent $other $(joinpath(dir, "Fixture-1.1.0.zip"))`)
  u = installed("1.0.0", feed)
  Update.tick!(u)
  Update.finish!(u)
  @test u.staged === nothing
  @test startswith(Update.says(u), "The file that came isn't the one that was released.")
end

@testset "an app that isn't the version that latest.txt names is left alone" begin
  feed = release("1.1.0")
  file = feed[8:end]
  write(file, replace(read(file, String), "version=1.1.0" => "version=1.3.0"))
  u = installed("1.0.0", feed)
  Update.tick!(u)
  Update.finish!(u)
  @test u.staged === nothing
  @test startswith(Update.says(u), "The app that came isn't version 1.3.0.")
end

@testset "no answer" begin
  u = installed("1.0.0", "file://" * joinpath(root, "nowhere", "latest.txt"))
  Update.tick!(u)
  Update.finish!(u)
  @test Update.says(u) == "Ladder couldn't look for a newer version. Ladder tries again in an hour."
  @test Update.label(u) == "Check now"
  @test Update.tick!(u) == Inf
  # A click on Check now looks at once
  Update.act!(u)
  @test u.stage === :checking
  Update.finish!(u)
end

@testset "a version that needs a newer macOS stays where it is" begin
  u = installed("1.0.0", release("1.1.0", macos="999.0"))
  Update.tick!(u)
  Update.finish!(u)
  @test u.staged === nothing && u.stage === :idle
  @test Update.says(u) == "Ladder 1.1.0 needs macOS 999.0 or later. This is Ladder 1.0.0."
  @test Update.label(u) == "Check now"
  @test !ispath(joinpath(u.dir, "new"))
end

@testset "with the setting off, nothing happens until you ask" begin
  u = installed("1.0.0", release("1.1.0"))
  u.auto = false
  @test Update.tick!(u) == Inf
  @test u.stage === :idle && u.newest === nothing
  @test Update.label(u) == "Check now"
  Update.act!(u)
  Update.finish!(u)
  @test u.staged === nothing              # it looked, and didn't get it
  @test Update.says(u) == "Ladder 1.1.0 is out. This is Ladder 1.0.0."
  @test Update.label(u) == "Get Ladder 1.1.0"
  Update.act!(u)
  @test Update.says(u) == "Ladder is getting version 1.1.0…"
  Update.finish!(u)
  @test u.staged == v"1.1.0"
  @test Update.says(u) == "Ladder 1.1.0 is ready."
  @test Update.label(u) == "Restart to update"
  @test !Update.quit!(u)                  # a quit leaves the app as it is
  @test version_of(u.app) == "1.0.0"
  Update.act!(u)                          # Restart to update
  @test u.again
end

@testset "a version that waited since the last run" begin
  u = installed("1.0.0", release("1.1.0"))
  Update.tick!(u)
  Update.finish!(u)
  @test u.staged == v"1.1.0"
  # Ladder opens again before the new version took the app's place
  again = Update.Updater(u.app, v"1.0.0"; feed=u.feed, dir=u.dir, rule=RULE, register="/usr/bin/true")
  again.auto = false
  Update.tick!(again)
  @test again.staged == v"1.1.0"
  @test install!(again)
  # ... and after it did. What's left in the folder goes.
  mkpath(joinpath(u.dir, "new"))
  after = Update.Updater(u.app, v"1.1.0"; feed=u.feed, dir=u.dir, rule=RULE, register="/usr/bin/true")
  after.auto = false
  Update.tick!(after)
  @test after.staged === nothing
  @test !ispath(u.dir)
end

@testset "a version that lost a file while it waited doesn't take the app's place" begin
  u = installed("1.0.0", release("1.1.0"))
  Update.tick!(u)
  Update.finish!(u)
  rm(joinpath(Update.staged_app(u), "Contents", "MacOS", "fixture"))
  @test !install!(u)
  @test version_of(u.app) == "1.0.0"
  @test success(`codesign --verify --deep --strict $(u.app)`)
  @test !ispath(Update.staged_app(u))     # so the next run gets it again
end

@testset "the app stays while another Ladder from it is open" begin
  u = installed("1.0.0", release("1.1.0"))
  Update.tick!(u)
  Update.finish!(u)
  # A program that runs from inside the app, as a second Ladder would. The app's signature doesn't cover it,
  # so the app that's installed is no longer whole, which the swap doesn't mind.
  program = joinpath(u.app, "Contents", "MacOS", "second")
  if success(pipeline(`clang -x c - -o $program`, stdin=IOBuffer("#include <unistd.h>\nint main(){sleep(60);return 0;}\n"), stderr=devnull))
    second = run(`$program`, wait=false)
    sleep(0.5)
    @test !install!(u)
    @test version_of(u.app) == "1.0.0"
    @test isdir(Update.staged_app(u)) && isfile(Update.ready_file(u))   # it waits for the next quit
    kill(second)
    wait(second)
    @test install!(u)
    @test version_of(u.app) == "1.1.0"
  else
    @info "No C compiler, so this test didn't run"
  end
end

@testset "a quit in the second after the download ends still finds the new version" begin
  u = installed("1.0.0", release("1.1.0"))
  Update.tick!(u)
  wait(u.process)
  Update.tick!(u)                         # the check has its answer, and the download starts
  @test u.stage === :fetching
  wait(u.process)                         # the download has ended, and no frame has seen that
  @test u.staged === nothing
  Update.settle!(u)                       # as a quit does
  @test u.stage === :idle && u.staged == v"1.1.0"
end

@testset "Restart to update opens the new version once it's in the app's place" begin
  u = installed("1.0.0", release("1.1.0"))
  Update.tick!(u)
  Update.finish!(u)
  Update.act!(u)
  @test u.again
  @test install!(u)
  # The app of these tests writes its version into a file beside itself when it opens
  opened = joinpath(dirname(u.app), "opened")
  for _ in 1:100
    isfile(opened) && break
    sleep(0.1)
  end
  @test isfile(opened) && strip(read(opened, String)) == "1.1.0"
end

@testset "a quit starts the swap, and the swap outlives the program that quit" begin
  u = installed("1.0.0", release("1.1.0"))
  Update.tick!(u)
  Update.finish!(u)
  # Another Julia stands in for the Ladder that quits: it finds the version that waits, and ends
  script = """
    @use "$(joinpath(@__DIR__, "..", "update"))" => Update
    u = Update.Updater("$(u.app)", v"1.0.0"; feed="$(u.feed)", dir="$(u.dir)", rule="$(escape_string(RULE))", register="/usr/bin/true")
    u.next = Inf
    Update.tick!(u)
    Update.quit!(u) || exit(1)
    """
  @test success(run(ignorestatus(`$(Base.julia_cmd()) --project=$(dirname(@__DIR__)) -e $script`)))
  for _ in 1:100
    version_of(u.app) == "1.1.0" && break
    sleep(0.1)
  end
  @test version_of(u.app) == "1.1.0"
end

@testset "why a copy of Ladder can't update itself" begin
  feed = release("1.1.0")
  source = Update.Updater("", v"0"; feed, dir=joinpath(mktempdir(root), "update"))
  @test Update.says(source) == "Ladder runs from its source here. Only the Ladder app updates itself."
  @test Update.label(source) == ""
  @test Update.tick!(source) == Inf
  @test source.stage === :idle && !ispath(source.dir)
  @test !Update.quit!(source)
  # An app that's signed for one Mac: its own rule names that one build
  local_build = installed("1.0.0", feed)
  local_build.rule = nothing
  @test Update.rule(local_build) == ""
  @test startswith(Update.says(local_build), "This copy of Ladder was built on this Mac.")
  @test Update.tick!(local_build) == Inf
  # An app that app/build.jl built here with a certificate: its rule names the developer, but the mark in its Info.plist keeps a release out
  marked = installed("1.0.0", feed)
  plist = joinpath(marked.app, "Contents", "Info.plist")
  signed_by_name() = run(pipeline(`codesign --force --sign - --identifier $NAME -r=$("designated => $RULE") $(marked.app)`, stderr=devnull))
  signed_by_name()
  marked.rule = nothing
  @test Update.rule(marked) == RULE
  run(`plutil -insert LadderBuiltHere -bool true $plist`)
  signed_by_name()
  marked.rule = nothing
  @test Update.rule(marked) == ""
  @test startswith(Update.says(marked), "This copy of Ladder was built on this Mac.")
  @test Update.tick!(marked) == Inf
  # An app whose developer signed it has a rule that says who that is
  @test Update.rule(Update.Updater("/System/Applications/Calculator.app", v"1")) == "identifier \"com.apple.calculator\" and anchor apple"
  # An app in a folder that Ladder can't change
  fixed = installed("1.0.0", feed)
  chmod(dirname(fixed.app), 0o555)
  @test startswith(Update.says(fixed), "Ladder can't change its own files where it is.")
  @test Update.tick!(fixed) == Inf
  chmod(dirname(fixed.app), 0o755)
  @test Update.says(fixed) == "This is Ladder 1.0.0."
end

@testset "this run is Ladder from its source" begin
  @test Update.running() == ("", v"0")
  @test Update.own().app == ""
end

# --- the settings page ------------------------------------------------------------------

@testset "every window has the same setting" begin
  @test :updates in K.SHARED
end

@testset "the settings file keeps the setting" begin
  home = mktempdir(root)
  withenv("HOME" => home) do
    e = K.build_editor(K.settings_page())
    e.remember = true
    K.updates!(e, false)
    @test occursin("updates=false", read(K.settings_file(), String))
    o = K.build_editor(K.settings_page())
    @test o.updates
    K.load_settings!(o)
    @test !o.updates
    K.updates!(e, true)
    @test occursin("updates=true", read(K.settings_file(), String))
    # A settings file from before the setting leaves it on
    write(K.settings_file(), "theme=night\n")
    o = K.build_editor(K.settings_page())
    K.load_settings!(o)
    @test o.updates
  end
end

@testset "the settings page shows the update and offers the button" begin
  was = Update.mine[]
  try
    u = installed("1.0.0", release("1.1.0"))
    Update.mine[] = u
    e = K.build_editor(K.settings_page())
    e.remember = false
    w = K.window!(e, title="test", size=(720px, 2400px))
    frame(w)
    # What a live block of the page calls, like `update_news()`
    ask(name, args...) = Base.invokelatest(getglobal(K.sandbox(e), name), args...)
    @test ask(:app_updates)
    @test ask(:update_news) == "This is Ladder 1.0.0."
    @test ask(:update_offer) == "Check now"
    ask(:update!)                      # Check now
    Update.finish!(u)
    @test ask(:update_news) == "Ladder 1.1.0 is ready. It takes the place of version 1.0.0 when you quit Ladder."
    @test ask(:update_offer) == "Restart to update"
    ask(:app_updates!, false)
    @test !e.updates
    @test ask(:update_news) == "Ladder 1.1.0 is ready."
    # A page with changes that aren't saved stops the restart
    page = joinpath(mktempdir(root), "notes.md")
    write(page, "# Notes\n")
    o = K.build_editor(page)
    ow = K.window!(o, title="test", size=(800px, 600px))
    frame(ow)
    K.ontype(o, K.Typed('a', ow))
    @test K.unsaved()
    ask(:update!)
    @test !u.again
    @test startswith(ask(:update_news), "Save your changes first.")
    @test length(K.editors) == 2
    K.save!(o.buf)
    @test !K.unsaved()
    # With them saved, every window closes, and the quit that follows opens the new version
    delete!(e.nodes, :update_held)
    ask(:update!)
    @test u.again
    @test isempty(K.editors)
  finally
    Update.mine[] = was
    foreach(o -> close(K.window_of(o)), copy(K.editors))
  end
end

# --- the extensions' updates --------------------------------------------------------------
#
# Each test makes a folder of repositories as Kip has it, with clones of
# repositories that stand in for GitHub. They're folders in the test's own
# folder, so the tests use no network.

@use LibGit2: LibGit2

const SIGNER = LibGit2.Signature("Test", "test@example.com")

"Write `text` into `file` in the repository at `dir`, and commit it. It gives the commit."
commit!(dir, text; file="main.jl") = LibGit2.with(LibGit2.GitRepo(dir)) do repo
  write(joinpath(dir, file), text)
  LibGit2.add!(repo, file)
  LibGit2.commit(repo, "Write $text"; author=SIGNER, committer=SIGNER)
end

"A repository at `dir` that stands in for one on GitHub, with one commit"
origin(dir) = (LibGit2.close(LibGit2.init(dir)); commit!(dir, "one\n"); dir)

"The text of the extension's main file in the clone at `dir`"
code(dir) = read(joinpath(dir, "main.jl"), String)

"The commit that the repository at `dir` is at"
at(dir) = LibGit2.with(LibGit2.head_oid, LibGit2.GitRepo(dir))

"""
A folder of repositories, as Kip has it, with a clone of `Ext.lad` and of
`Other.lad`, a link to a folder of `Mine.lad`, and a folder that isn't a
clone. It gives the folder and the repository that each clone came from.
"""
repositories() = begin
  dir = mktempdir(root)
  hub = Dict(name => origin(joinpath(dir, "hub", name)) for name in ("Ext.lad", "Other.lad", "Mine.lad"))
  repos = joinpath(dir, "repos")
  for name in ("Ext.lad", "Other.lad")
    LibGit2.close(LibGit2.clone(hub[name], joinpath(repos, "sam", name)))
  end
  # An extension that you write, which Kip.link links to your own folder of it
  mine = joinpath(dir, "work", "Mine.lad")
  LibGit2.close(LibGit2.clone(hub["Mine.lad"], mine))
  symlink(mine, joinpath(repos, "sam", "Mine.lad"))
  # The app writes its own code here too, which isn't a clone
  mkpath(joinpath(repos, "jkroso", "UI.jl"))
  write(joinpath(repos, "jkroso", "UI.jl", "Project.toml"), "name = \"UI\"\n")
  (repos, hub)
end

@testset "an extension is a clone in Kip's folder" begin
  repos, _ = repositories()
  @test Update.clones(repos) == [("sam/Ext.lad", false), ("sam/Mine.lad", true), ("sam/Other.lad", false)]
  @test Update.clones(joinpath(repos, "none")) == []
end

@testset "a clone moves up to the new commits that Ladder fetched" begin
  repos, hub = repositories()
  ext = joinpath(repos, "sam", "Ext.lad")
  was = at(ext)
  new = commit!(hub["Ext.lad"], "two\n")
  # Nothing waits until Ladder fetches
  @test Update.waiting(repos) == []
  @test Update.apply!(repos) == []
  @test Update.fetch_all(repos) == []
  @test Update.waiting(repos) == ["Ext.lad"]
  # The fetch changed nothing that a program loads
  @test at(ext) == was
  @test code(ext) == "one\n"
  @test Update.apply!(repos) == ["Ext.lad"]
  @test at(ext) == new
  @test code(ext) == "two\n"
  @test Update.waiting(repos) == []
  @test Update.apply!(repos) == []
end

@testset "Ladder leaves a link, a clone with changes, one at a tag and one with commits of its own" begin
  repos, hub = repositories()
  foreach(name -> commit!(hub[name], "two\n"), ("Ext.lad", "Other.lad", "Mine.lad"))
  # A link to your own folder isn't fetched
  mine = joinpath(repos, "sam", "Mine.lad")
  @test Update.fetch_all(repos) == []
  @test LibGit2.with(r -> LibGit2.GitHash(LibGit2.lookup_branch(r, "origin/main", true)), LibGit2.GitRepo(mine)) == at(mine)
  # A change of your own, which a move would lose
  ext = joinpath(repos, "sam", "Ext.lad")
  write(joinpath(ext, "main.jl"), "mine\n")
  @test Update.newer(ext) === nothing
  # A clone that isn't on a branch, as Kip leaves one that a `@use` holds at a tag
  other = joinpath(repos, "sam", "Other.lad")
  LibGit2.with(r -> LibGit2.checkout!(r, string(at(other))), LibGit2.GitRepo(other))
  @test Update.newer(other) === nothing
  @test Update.waiting(repos) == []
  @test Update.apply!(repos) == []
  @test code(ext) == "mine\n"
  # A clone with a commit that GitHub doesn't have
  write(joinpath(ext, "main.jl"), "one\n")
  commit!(ext, "local\n")
  @test Update.newer(ext) === nothing
end

"An updater of the extensions in `repos`, for an app that isn't there"
updater(repos) = Update.Extensions(joinpath(root, "Applications", "Fixture.app"), repos)

@testset "the updater looks, says what it found, and moves the clones when Ladder quits" begin
  repos, hub = repositories()
  x = updater(repos)
  # It looks when Ladder opens
  @test Update.tick!(x) == Update.POLL
  @test x.task !== nothing
  @test startswith(Update.says(x), "Ladder is looking for new code for Ext.lad and Other.lad…")
  @test Update.action(x) === :none
  Update.finish!(x)
  @test Update.says(x) == "Ext.lad and Other.lad have the newest code from GitHub. Ladder leaves Mine.lad as it is, since it's a link to a folder on this Mac."
  @test Update.label(x) == "Check now"
  # And again a day later
  @test Update.tick!(x) == Inf
  @test x.next > time() + Update.EVERY - 60
  new = commit!(hub["Ext.lad"], "two\n")
  Update.act!(x)                     # Check now
  Update.finish!(x)
  @test x.ready == ["Ext.lad"]
  @test startswith(Update.says(x), "New code for Ext.lad is ready. It loads the next time that Ladder opens.")
  @test Update.label(x) == "Restart Ladder"
  # Ladder quits, and the clone moves up
  ext = joinpath(repos, "sam", "Ext.lad")
  @test at(ext) != new
  @test Update.quit!(x) == ["Ext.lad"]
  @test at(ext) == new
  @test !Update.reopen!(x)            # Ladder doesn't open again after a plain quit
end

@testset "with the box off, a clone moves only after Restart Ladder" begin
  repos, hub = repositories()
  x = updater(repos)
  x.auto = false
  @test Update.tick!(x) == Inf
  @test x.task === nothing
  @test startswith(Update.says(x), "Ladder hasn't looked for new code for Ext.lad and Other.lad since it opened.")
  commit!(hub["Other.lad"], "two\n")
  Update.act!(x)                     # Check now
  Update.finish!(x)
  @test startswith(Update.says(x), "New code for Other.lad is ready. Ladder leaves")
  @test Update.quit!(x) == []
  @test Update.act!(x).again          # Restart Ladder
  @test Update.quit!(x) == ["Other.lad"]
end

@testset "new code that waited from the last run is ready when Ladder opens" begin
  repos, hub = repositories()
  commit!(hub["Ext.lad"], "two\n")
  Update.fetch_all(repos)
  x = updater(repos)
  x.auto = false
  Update.tick!(x)
  @test x.ready == ["Ext.lad"]
end

@testset "a fetch that fails" begin
  repos, hub = repositories()
  rm(hub["Other.lad"], recursive=true)
  x = updater(repos)
  Update.tick!(x)
  Update.finish!(x)
  @test startswith(Update.says(x), "Ladder couldn't get the new code of Other.lad from GitHub. Ladder tries again in an hour.")
  @test x.next < time() + Update.RETRY + 60
end

@testset "only the app updates its extensions" begin
  repos, _ = repositories()
  x = Update.Extensions("", repos)
  @test Update.tick!(x) == Inf
  @test x.task === nothing
  @test Update.says(x) == "Ladder runs from its source here. Only the Ladder app gets new code for its extensions."
  @test Update.action(x) === :none
  @test Update.quit!(x) == []
  @test Update.extensions().app == ""
end

@testset "with no extensions" begin
  x = updater(mktempdir(root))
  Update.tick!(x)
  @test Update.says(x) == "Ladder has no extensions from GitHub."
  @test Update.action(x) === :none
end

@testset "the settings page shows the extensions' new code and offers the button" begin
  was = Update.extensions_updater[]
  try
    repos, hub = repositories()
    x = updater(repos)
    x.auto = false
    Update.extensions_updater[] = x
    e = K.build_editor(K.settings_page())
    e.remember = false
    w = K.window!(e, title="test", size=(720px, 2400px))
    frame(w)
    ask(name, args...) = Base.invokelatest(getglobal(K.sandbox(e), name), args...)
    @test startswith(ask(:extension_news), "Ladder hasn't looked for new code for Ext.lad and Other.lad")
    @test ask(:extension_offer) == "Check now"
    commit!(hub["Ext.lad"], "two\n")
    ask(:update_extensions!)           # Check now
    Update.finish!(x)
    @test startswith(ask(:extension_news), "New code for Ext.lad is ready.")
    @test ask(:extension_offer) == "Restart Ladder"
    # The box turns the extensions' updates on and off too
    ask(:app_updates!, true)
    @test x.auto
    ask(:app_updates!, false)
    @test !x.auto
    # A page with changes that aren't saved stops the restart
    page = joinpath(mktempdir(root), "notes.md")
    write(page, "# Notes\n")
    o = K.build_editor(page)
    ow = K.window!(o, title="test", size=(800px, 600px))
    frame(ow)
    K.ontype(o, K.Typed('a', ow))
    ask(:update_extensions!)
    @test !x.again
    @test startswith(ask(:extension_news), "Save your changes first.")
    K.save!(o.buf)
    delete!(e.nodes, :extensions_held)
    # With them saved, every window closes, and the quit that follows moves the clone and opens Ladder again
    ask(:update_extensions!)
    @test x.again
    @test isempty(K.editors)
  finally
    Update.extensions_updater[] = was
    foreach(o -> close(K.window_of(o)), copy(K.editors))
  end
end

rm(root, recursive=true, force=true)
