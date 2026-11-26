# Ladder updates itself. The app asks GitHub which version of Ladder is the
# newest. It gets a newer version while you work, checks that Ladder's
# developer signed it, and puts it in the app's place when you quit. The
# settings page has a box that turns this off, and says how far an update has
# got.
#
#     u = own()               # the updater of the app that's running
#     tick!(u)                # call it in each frame. It gives the seconds until it wants the next call.
#     says(u), action(u)      # what the settings page shows, and what its button does
#     act!(u)                 # what happens when you click that button
#     quit!(u)                # call it when the last window has closed
#
# A release has two files. latest.txt names the newest version:
#
#     version=0.2.0
#     file=Ladder-0.2.0.zip
#     sha256=<the SHA-256 sum of the zip file>
#     macos=12.0
#
# `macos` is the oldest macOS that the version runs on. The zip file holds
# Ladder.app. release.jl makes both files, and publishes them in `REPO`.
#
# Only the Ladder app updates itself, and only a copy that release.jl made.
# Ladder run from its source doesn't, and nor does an app that app/build.jl
# built on this Mac. That one has `LadderBuiltHere` in its Info.plist, or is
# signed for one Mac.
#
# A new version must pass the designated requirement of the app that's
# running. That is the rule that macOS reads from an app's signature, and it
# says who signed the app. So an app that someone else made can't take
# Ladder's place, wherever it came from.
#
# The new version waits in Ladder's folder in ~/Library/Application Support,
# in `update`. It takes the app's place after Ladder has quit, because a
# program that's running reads its own files as it goes.
#
# LADDER_UPDATE_FEED gives the app another address for latest.txt, to try an
# update without a release. The new version must still pass the rule above.
#
# The app gets the new code of its extensions too, like Mail.lad: see "the
# extensions' updates", at the end of this file.

@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool
@use LibGit2: LibGit2
@use "./app/facts" => Facts

"The GitHub repo whose releases the app looks at. release.jl publishes to it."
const REPO = Facts.REPO
"The file of a release that names the newest version"
const LATEST = "latest.txt"
"The Ladder app's name for macOS, as app/build.jl gives it"
const ID = Facts.APP_ID
const EVERY = 24 * 60 * 60.0   # seconds from one look for a newer version to the next
const RETRY = 60 * 60.0        # seconds until it looks again after it couldn't
const POLL = 1.0               # seconds between two looks at a download that's running
const LSREGISTER = Facts.LSREGISTER

"The address of latest.txt"
feed() = get(ENV, "LADDER_UPDATE_FEED", "https://github.com/$REPO/releases/latest/download/$LATEST")

mutable struct Updater
  app::String                             # the app that's running, or "" when Ladder runs from its source
  version::VersionNumber                  # the version that's running
  feed::String                            # the address of latest.txt
  dir::String                             # the folder where a new version waits
  rule::Union{Nothing,String}             # what a new version's signature must pass. "" when the app has no such rule. Nothing until it's asked for.
  register::String                        # the program that tells macOS about the new app
  auto::Bool                              # look for a newer version, and get it, without being asked
  stage::Symbol                           # :idle, :checking while it asks which version is the newest, or :fetching while it gets one
  process::Any                            # the program that's checking or fetching
  newest::Union{Nothing,VersionNumber}    # the newest version there is, once it has asked
  file::String                            # the name of that version's zip file
  sum::String                             # the SHA-256 sum of the zip file
  needs::VersionNumber                    # the oldest macOS that the newest version runs on
  staged::Union{Nothing,VersionNumber}    # the version that waits in `dir` to take the app's place
  looked::Bool                            # `dir` has been read for a version that waited there from the last run
  problem::String                         # why the last check or download failed, or ""
  next::Float64                           # the time of the next look, for `auto`
  again::Bool                             # open the app again once the new version is in its place
  changed::Int                            # goes up whenever what `says` and `action` give may have changed
end

"""
The updater of the app at `app`, which is version `version`. `rule` is the
requirement that a new version's signature must pass. Without one, it's the
designated requirement of `app`.
"""
Updater(app, version; feed=feed(), dir=waiting_room(), rule=nothing, register=LSREGISTER) =
  Updater(app, version, feed, dir, rule, register, true, :idle, nothing, nothing, "", "", v"0", nothing, false, "", 0.0, false, 0)

"The folder where a new version waits"
waiting_room() = joinpath(Facts.support_dir(), "update")

"The updater of the app that's running"
const mine = Ref{Union{Nothing,Updater}}(nothing)
own() = begin
  mine[] === nothing || return mine[]
  u = Updater(running()...)
  # While the app is built, this code runs in Julia's own program. The app must look again when it opens.
  ccall(:jl_generating_output, Cint, ()) == 1 || (mine[] = u)
  u
end

"Where the Ladder app that's running is, and its version. The place is an empty string when Ladder runs from its source."
running() = begin
  Sys.isapple() || return ("", v"0")
  with_pool() do
    bundle = msg(cls("NSBundle"), "mainBundle")
    jstring(msg(bundle, "bundleIdentifier")) == ID || return ("", v"0")
    version = jstring(msg(bundle, "objectForInfoDictionaryKey:", nsstring("CFBundleShortVersionString")))
    (jstring(msg(bundle, "bundlePath")), something(tryparse(VersionNumber, version), v"0"))
  end
end

"""
The rule that a new version's signature must pass: the designated requirement
of the app that's running. It's an empty string for an app that app/build.jl
built on this Mac, so that a release doesn't take the place of the newer code
in it. It's an empty string for an app that's signed for one Mac too. The rule
of such an app names that one build, so no other build passes it.
"""
rule(u::Updater) = begin
  u.rule === nothing || return u.rule
  u.rule = try
    m = match(r"^designated => (.+)$"m, read(pipeline(`/usr/bin/codesign -d -r- $(u.app)`, stderr=devnull), String))
    (m === nothing || startswith(m[1], "cdhash") || built_here(u.app)) ? "" : String(m[1])
  catch
    ""
  end
end

"True when app/build.jl built the app at `app` on this Mac, and not for a release"
built_here(app) = success(pipeline(`plutil -extract $(Facts.BUILT_HERE_KEY) raw $(joinpath(app, "Contents", "Info.plist"))`, stdout=devnull, stderr=devnull))

"True when Ladder can change the file or folder at `path`"
writable(path) = ccall(:access, Cint, (Cstring, Cint), path, 2) == 0

"Why the app can't update itself, or an empty string when it can"
blocked(u::Updater) = begin
  isempty(u.app) && return "Ladder runs from its source here. Only the Ladder app updates itself."
  isempty(rule(u)) && return "This copy of Ladder was built on this Mac. Only a copy from Ladder's releases updates itself."
  # macOS runs an app that's still in the folder it was downloaded to from a place that nothing can change
  (writable(u.app) && writable(dirname(u.app))) ||
    return "Ladder can't change its own files where it is. Move it to your Applications folder, then open it again."
  ""
end

"The version of macOS on this Mac, or nothing when Ladder can't tell"
macos() = try
  m = match(r"<key>ProductVersion</key>\s*<string>([\d.]+)</string>", read("/System/Library/CoreServices/SystemVersion.plist", String))
  m === nothing ? nothing : tryparse(VersionNumber, m[1])
catch
  nothing
end

"True when this Mac has the macOS that the newest version needs"
fits(u::Updater) = (has = macos(); has === nothing || has >= u.needs)

"""
What the text of latest.txt names: the version, its zip file, the file's
SHA-256 sum and the oldest macOS the version runs on. It's nothing when the
text doesn't name the first three. The file is a name beside latest.txt, never
a path or an address.
"""
parse_feed(text) = begin
  named = Dict{String,String}()
  for line in split(text, '\n')
    parts = split(strip(line), '=', limit=2)
    length(parts) == 2 && (named[parts[1]] = parts[2])
  end
  version = tryparse(VersionNumber, get(named, "version", ""))
  file, sum = get(named, "file", ""), lowercase(get(named, "sha256", ""))
  # The version is written the way Julia writes it, since the new app's own version is compared with these words
  (version === nothing || string(version) != named["version"]) && return nothing
  (occursin(r"^[\w\-][\w.\-]*$", file) && occursin(r"^[0-9a-f]{64}$", sum)) || return nothing
  (version, String(file), String(sum), something(tryparse(VersionNumber, get(named, "macos", "")), v"0"))
end

changed!(u::Updater) = (u.changed += 1; u)
feed_file(u::Updater) = joinpath(u.dir, LATEST)
problem_file(u::Updater) = joinpath(u.dir, "problem")
"Where the new version waits"
staged_app(u::Updater) = joinpath(u.dir, "staged.app")
ready_file(u::Updater) = joinpath(u.dir, "ready")

"""
Read `dir` for a new version that has waited there since the last run. What's
left of an update that stopped half way, or of one that's now the app, goes.
"""
look!(u::Updater) = begin
  u.looked = true
  version = isfile(ready_file(u)) ? tryparse(VersionNumber, strip(read(ready_file(u), String))) : nothing
  if version !== nothing && version > u.version && isdir(staged_app(u))
    u.staged = version
    return changed!(u)
  end
  rm(u.dir, recursive=true, force=true)
  u
end

"Ask which version is the newest. `tick!` takes the answer."
check!(u::Updater) = begin
  u.stage == :idle || return u
  u.looked || look!(u)   # before anything new goes into the folder
  u.problem = ""
  try
    mkpath(u.dir)
    rm(feed_file(u), force=true)
    u.process = run(pipeline(`/usr/bin/curl -fsSL --max-time 30 -o $(feed_file(u)) $(u.feed)`, stdout=devnull, stderr=devnull), wait=false)
    u.stage = :checking
  catch
    failed!(u, "Ladder couldn't look for a newer version.")
  end
  changed!(u)
end

"Note that a check or a download failed, and why. Ladder tries again in an hour."
failed!(u::Updater, why) = (u.stage = :idle; u.problem = why; u.next = time() + RETRY; changed!(u))

"Take the answer to `check!`. With `auto`, start to get the version it names if that one is newer."
checked!(u::Updater) = begin
  named = success(u.process) && isfile(feed_file(u)) ? parse_feed(read(feed_file(u), String)) : nothing
  rm(feed_file(u), force=true)
  named === nothing && return failed!(u, "Ladder couldn't look for a newer version.")
  u.stage = :idle
  u.newest, u.file, u.sum, u.needs = named
  u.next = time() + EVERY
  u.auto && wanted(u) && fetch!(u)
  changed!(u)
end

"""
Write latest.txt into `dir` for the release of `version`, whose zip file is
`zip`. `macos` is the oldest macOS that the version runs on. It returns the
path of latest.txt. release.jl calls this.
"""
announce(dir, version, zip; macos=Facts.MIN_MACOS) = begin
  sum = first(split(readchomp(`/usr/bin/shasum -a 256 $zip`)))
  text = "version=$version\nfile=$(basename(zip))\nsha256=$sum\nmacos=$macos\n"
  parse_feed(text) === nothing && error("Ladder can't read a latest.txt for version $version and the file $(basename(zip)). ",
                                        "Write the version like 1.2.0, and give the file a name of letters, digits, dots and dashes.")
  file = joinpath(dir, LATEST)
  write(file, text)
  file
end

"True when the newest version is newer than the app, runs on this Mac and doesn't wait in `dir` already"
wanted(u::Updater) = u.newest !== nothing && u.newest > u.version && u.staged != u.newest && fits(u)

# Gets the zip file, and leaves the app that's in it in `dir` as staged.app, with its version in the file
# `ready`. The app stays only if it's the version that latest.txt named, and its signature passes the rule.
# The last line it prints says what went wrong.
const FETCH = raw"""
url="$1"; sum="$2"; dir="$3"; version="$4"; rule="$5"
new="$dir/new"
fail() { echo "$1" >&2; rm -rf "$new"; exit 1; }
rm -rf "$new" "$dir/ready" "$dir/staged.app"
mkdir -p "$new" || fail "Ladder couldn't make a folder for version $version."
/usr/bin/curl -fsSL --retry 2 -o "$new/app.zip" "$url" || fail "The download of Ladder $version stopped."
[ "$(/usr/bin/shasum -a 256 "$new/app.zip" | /usr/bin/cut -d' ' -f1)" = "$sum" ] || fail "The file that came isn't the one that was released."
/usr/bin/ditto -x -k "$new/app.zip" "$new/open" || fail "Ladder couldn't open the file of version $version."
set -- "$new/open"/*.app
{ [ $# = 1 ] && [ -d "$1" ]; } || fail "The file of version $version doesn't hold an app."
[ "$(/usr/bin/plutil -extract CFBundleShortVersionString raw "$1/Contents/Info.plist" 2>/dev/null)" = "$version" ] || fail "The app that came isn't version $version."
/usr/bin/codesign --verify --deep --strict -R="$rule" "$1" 2>/dev/null || fail "Ladder's developer didn't sign the app that came, so Ladder left it alone."
/bin/mv "$1" "$dir/staged.app" || fail "Ladder couldn't keep version $version."
echo "$version" > "$dir/ready"
rm -rf "$new"
"""

"Start to get the newest version. `tick!` sees when it has come."
fetch!(u::Updater) = begin
  (u.stage == :idle && u.newest !== nothing) || return u
  u.looked || look!(u)
  u.problem = ""
  u.staged = nothing   # the download takes the place of a version that waits
  try
    mkpath(u.dir)
    url = u.feed[1:findlast('/', u.feed)] * u.file
    cmd = `/bin/sh -c $FETCH sh $url $(u.sum) $(u.dir) $(string(u.newest)) $(rule(u))`
    u.process = run(pipeline(cmd, stdout=devnull, stderr=problem_file(u)), wait=false)
    u.stage = :fetching
  catch
    failed!(u, "Ladder couldn't get version $(u.newest).")
  end
  changed!(u)
end

"Note how the download ended"
fetched!(u::Updater) = begin
  said = isfile(problem_file(u)) ? split(strip(read(problem_file(u), String)), '\n', keepempty=false) : SubString{String}[]
  rm(problem_file(u), force=true)
  success(u.process) || return failed!(u, isempty(said) ? "Ladder couldn't get version $(u.newest)." : String(last(said)))
  u.stage = :idle
  u.staged = u.newest
  changed!(u)
end

"""
Do what's due now: take the answer of a check or the end of a download, and
with `auto`, look for a newer version when it's time. Each window calls this in
each frame. It returns the seconds until it wants the next call. That is
`Inf` when it only needs one after something else happens.
"""
tick!(u::Updater) = begin
  isempty(blocked(u)) || return Inf
  u.looked || look!(u)
  if u.stage == :checking
    process_exited(u.process) && checked!(u)
  elseif u.stage == :fetching
    process_exited(u.process) && fetched!(u)
  elseif u.auto && time() >= u.next
    check!(u)
  end
  u.stage == :idle ? Inf : POLL
end

"""
Take the end of a download that no frame has seen yet. A quit can come in the
second after the download ends, and the new version is ready then.
"""
settle!(u::Updater) = (u.stage == :fetching && process_exited(u.process) && fetched!(u); u)

"Wait until the check or the download that's running has ended, and take its answer. For a script or a test."
finish!(u::Updater) = begin
  while u.stage != :idle
    wait(u.process)
    tick!(u)
  end
  u
end

"One or two sentences on where the update has got to, for the settings page"
says(u::Updater) = begin
  no = blocked(u)
  isempty(no) || return no
  u.stage == :checking && return "Ladder is looking for a newer version…"
  u.stage == :fetching && return "Ladder is getting version $(u.newest)…"
  u.staged !== nothing &&
    return "Ladder $(u.staged) is ready." * (u.auto ? " It takes the place of version $(u.version) when you quit Ladder." : "")
  isempty(u.problem) || return u.problem * (u.auto ? " Ladder tries again in an hour." : "")
  u.newest === nothing && return "This is Ladder $(u.version)."
  u.newest <= u.version && return "This is Ladder $(u.version), the newest version."
  fits(u) || return "Ladder $(u.newest) needs macOS $(u.needs.major).$(u.needs.minor) or later. This is Ladder $(u.version)."
  "Ladder $(u.newest) is out. This is Ladder $(u.version)."
end

"""
What the button on the settings page does now: `:check` looks for a newer
version, `:get` gets the one that's out, and `:restart` puts the one that's
ready in the app's place and opens it. It's `:none` when there's nothing to do.
"""
action(u::Updater) = begin
  (isempty(blocked(u)) && u.stage == :idle) || return :none
  u.staged !== nothing && return :restart
  wanted(u) ? :get : :check
end

"What the button says for each `action`"
label(u::Updater) = begin
  a = action(u)
  a === :restart ? "Restart to update" : a === :get ? "Get Ladder $(u.newest)" : a === :check ? "Check now" : ""
end

"""
Do the `action`. After `:restart`, `u.again` is true: close every window, and
`quit!` then opens the new version.
"""
act!(u::Updater) = begin
  a = action(u)
  a === :check && check!(u)
  a === :get && fetch!(u)
  a === :restart && (u.again = true)
  u
end

# Puts staged.app in the app's place, once the Ladder that asked has quit. It leaves the app alone while
# another Ladder from the same app is open, since that one still reads the app's files. The new app must
# pass the rule again, in case a file of it was lost while it waited. `again` opens the app at the end,
# whichever version is there then.
const INSTALL = raw"""
pid="$1"; dir="$2"; app="$3"; rule="$4"; again="$5"; register="$6"
new="$dir/staged.app"
finish() { [ -n "$again" ] && /usr/bin/open "$app"; exit "$1"; }
n=0
while kill -0 "$pid" 2>/dev/null && [ $n -lt 300 ]; do sleep 0.1; n=$((n+1)); done
{ [ -d "$app" ] && [ -f "$dir/ready" ] && [ -d "$new" ]; } || finish 1
if /bin/ps -axo comm= | /usr/bin/grep -qF "$app/Contents/MacOS/"; then finish 1; fi
rm -f "$dir/ready"
/usr/bin/codesign --verify --deep --strict -R="$rule" "$new" 2>/dev/null || { rm -rf "$new"; finish 1; }
place="$(/usr/bin/dirname "$app")"
beside="$place/.ladder-new-$$.app"
old="$place/.ladder-old-$$.app"
# First onto the app's disk, which can be another one. Then the two swap places, so the app is never half there.
/bin/mv "$new" "$beside" || { rm -rf "$beside" "$new"; finish 1; }
/bin/mv "$app" "$old" || { rm -rf "$beside"; finish 1; }
/bin/mv "$beside" "$app" || { /bin/mv "$old" "$app"; rm -rf "$beside"; finish 1; }
rm -rf "$old"
/usr/bin/touch "$app"
"$register" -f "$app" >/dev/null 2>&1
finish 0
"""

"""
The command that puts the new version in the app's place once the process
`pid` has ended
"""
install(u::Updater, pid) =
  `/bin/sh -c $INSTALL sh $pid $(u.dir) $(u.app) $(rule(u)) $(u.again ? "again" : "") $(u.register)`

"""
Call this when the last window has closed. It starts a program that outlives
Ladder, and puts the new version in the app's place once Ladder has quit. It
does that when a version is ready, and `auto` is on or you clicked Restart to
update. It's true when it started the program.
"""
quit!(u::Updater) = begin
  settle!(u)
  (u.staged !== nothing && (u.auto || u.again) && isempty(blocked(u))) || return false
  try
    run(pipeline(detach(install(u, getpid())), stdin=devnull, stdout=devnull, stderr=devnull), wait=false)
    true
  catch
    false
  end
end

# --- the extensions' updates ----------------------------------------------------------------
#
# An extension is code that Ladder got from GitHub: a kind of folder, like
# github.com/jkroso/Media.lad, a kind of block, or code that the startup page
# uses. Kip clones each one into its folder of repositories, at `user/repo`,
# the first time that Ladder needs it. Kip never looks for new commits after
# that. So the app looks for them, as it looks for a newer version of itself:
# when it opens, and once a day after that, while the box on the settings page
# is on.
#
# A task on a thread that isn't the window's fetches each clone's new commits
# from GitHub. They wait in the clone's `.git` folder while Ladder runs, and
# each clone moves up to them when you quit Ladder. Kip loads an extension from
# a copy of the commit that its clone was at, so the code that's loaded now
# stays as it is. The new code loads the next time that Ladder opens. Ladder
# can't load it while it runs, since the new code's types aren't the old
# code's types, and the old code's values use them.
#
# Ladder leaves these clones as they are:
#
# - a link to a folder on this Mac, as `Kip.link` makes for an extension that
#   you write. Ladder uses that folder as it is.
# - a clone with changes of its own, which a move to the new commits would lose
# - a clone that isn't on a branch, like one that a `@use` with a version holds at a tag
# - a clone with commits that GitHub doesn't have
#
#     x = extensions()      # the extensions' updater of the app that's running
#     tick!(x)              # call it in each frame, as for the app's updater
#     says(x), action(x)    # what the settings page shows, and what its button does
#     act!(x)               # what happens when you click that button
#     quit!(x)              # call it when the last window has closed
#     reopen!(x)            # and this after it, to open Ladder again after Restart Ladder

mutable struct Extensions
  app::String                  # the app that's running, or "" when Ladder runs from its source
  repos::String                # Kip's folder of repositories, which has a clone of each extension at `user/repo`
  auto::Bool                   # look for new code, and get it, without being asked
  task::Union{Nothing,Task}    # the task that fetches the new commits, while it runs
  ready::Vector{String}        # the name of each extension whose new code waits, like "Mail.lad"
  looked::Bool                 # the clones have been read for new code that waited from the last run
  checked::Bool                # Ladder has looked on GitHub since it opened
  problem::String              # why the last look failed, or ""
  next::Float64                # the time of the next look, for `auto`
  again::Bool                  # open the app again once Ladder has quit
  changed::Int                 # goes up whenever what `says` and `action` give may have changed
end

"The extensions' updater of the app at `app`, whose clones are in `repos`"
Extensions(app, repos) = Extensions(app, repos, true, nothing, String[], false, false, "", 0.0, false, 0)

"The extensions' updater of the app that's running"
const extensions_updater = Ref{Union{Nothing,Extensions}}(nothing)
extensions() = begin
  extensions_updater[] === nothing || return extensions_updater[]
  x = Extensions(own().app, Kip.repos)
  # While the app is built, this code runs in Julia's own program. The app must look again when it opens.
  ccall(:jl_generating_output, Cint, ()) == 1 || (extensions_updater[] = x)
  x
end

changed!(x::Extensions) = (x.changed += 1; x)

"Why the app can't update its extensions, or an empty string when it can"
blocked(x::Extensions) = isempty(x.app) ? "Ladder runs from its source here. Only the Ladder app gets new code for its extensions." : ""

"""
Each extension in `repos` that has a clone, as `user/repo`, and whether it's a
link to a folder on this Mac. A folder of code that the app wrote there, which
isn't a clone, isn't an extension.
"""
clones(repos) = begin
  found = Tuple{String,Bool}[]
  isdir(repos) || return found
  for user in sort!(readdir(repos))
    folder = joinpath(repos, user)
    (isdir(folder) && !islink(folder)) || continue
    for name in sort!(readdir(folder))
      dir = joinpath(folder, name)
      isdir(joinpath(dir, ".git")) && push!(found, (joinpath(user, name), islink(dir)))
    end
  end
  found
end

"The name that the settings page gives an extension: its repository's, like Mail.lad"
named(clone) = basename(clone)

"""
The commit that the clone at `dir` can move up to: the newest commit of its
branch that Ladder has fetched from GitHub. It's nothing when the clone has
that commit already, has changes of its own, isn't on a branch, or has commits
that GitHub doesn't.
"""
newer(dir) = try
  LibGit2.with(LibGit2.GitRepo(dir)) do repo
    (LibGit2.isattached(repo) && !LibGit2.isdirty(repo)) || return nothing
    branch = LibGit2.lookup_branch(repo, "origin/" * LibGit2.headname(repo), true)
    branch === nothing && return nothing
    got, at = LibGit2.GitHash(branch), LibGit2.head_oid(repo)
    got != at && LibGit2.is_ancestor_of(string(at), string(got), repo) ? got : nothing
  end
catch
  nothing
end

"The name of each extension in `repos` whose new code waits"
waiting(repos) = [named(c) for (c, linked) in clones(repos) if !linked && newer(joinpath(repos, c)) !== nothing]

"""
Fetch the new commits of each clone in `repos` that isn't a link. It gives the
name of each extension whose commits Ladder couldn't get. It runs in a task,
so it changes nothing that the window reads.
"""
fetch_all(repos) = begin
  failed = String[]
  for (c, linked) in clones(repos)
    linked && continue
    try
      LibGit2.with(LibGit2.fetch, LibGit2.GitRepo(joinpath(repos, c)))
    catch
      push!(failed, named(c))
    end
  end
  failed
end

"""
Move each clone in `repos` up to the new commits that wait in it. It gives the
name of each extension that moved. Kip loads each one's new code the next
time that a program needs it.
"""
apply!(repos) = begin
  moved = String[]
  for (c, linked) in clones(repos)
    linked && continue
    dir = joinpath(repos, c)
    to = newer(dir)
    to === nothing && continue
    try
      LibGit2.with(repo -> LibGit2.reset!(repo, to, LibGit2.Consts.RESET_HARD), LibGit2.GitRepo(dir))
      push!(moved, named(c))
    catch
    end
  end
  moved
end

"Read the clones for new code that waits in them since the last run, like one that a crash didn't let Ladder move up"
look!(x::Extensions) = (x.looked = true; x.ready = waiting(x.repos); changed!(x))

"Start to fetch the new commits of every extension. `tick!` takes the end of it."
check!(x::Extensions) = begin
  (isempty(blocked(x)) && x.task === nothing) || return x
  x.looked || look!(x)
  x.problem = ""
  repos = x.repos
  x.task = Threads.@spawn fetch_all(repos)
  changed!(x)
end

"Take the end of a fetch: which extensions have new code now, and which Ladder couldn't reach"
fetched!(x::Extensions) = begin
  failed = try
    fetch(x.task)
  catch
    [named(c) for (c, linked) in clones(x.repos) if !linked]
  end
  x.task = nothing
  x.checked = true
  look!(x)
  x.problem = isempty(failed) ? "" : "Ladder couldn't get the new code of $(join(failed, ", ", " and ")) from GitHub."
  x.next = time() + (isempty(failed) ? EVERY : RETRY)
  changed!(x)
end

"""
Do what's due now: take the end of a fetch, and with `auto`, start one when
it's time. Each window calls this in each frame. It gives the seconds until it
wants the next call, which is `Inf` while no fetch runs.
"""
tick!(x::Extensions) = begin
  isempty(blocked(x)) || return Inf
  x.looked || look!(x)
  if x.task !== nothing
    istaskdone(x.task) && fetched!(x)
  elseif x.auto && time() >= x.next
    check!(x)
  end
  x.task === nothing ? Inf : POLL
end

"Wait until the fetch that's running has ended, and take its end. For a script or a test."
finish!(x::Extensions) = (x.task === nothing || (wait(x.task); fetched!(x)); x)

"One or two sentences on the extensions' new code, for the settings page"
says(x::Extensions) = begin
  no = blocked(x)
  isempty(no) || return no
  found = clones(x.repos)
  cloned = [named(c) for (c, linked) in found if !linked]
  links = [named(c) for (c, linked) in found if linked]
  left = isempty(links) ? "" :
    " Ladder leaves $(join(links, ", ", " and ")) as $(length(links) == 1 ? "it is, since it's a link" : "they are, since each is a link") to a folder on this Mac."
  isempty(cloned) && return (isempty(links) ? "Ladder has no extensions from GitHub." : String(lstrip(left)))
  said = if x.task !== nothing
    "Ladder is looking for new code for $(join(cloned, ", ", " and "))…"
  elseif !isempty(x.ready)
    "New code for $(join(x.ready, ", ", " and ")) is ready." * (x.auto ? " It loads the next time that Ladder opens." : "")
  elseif !isempty(x.problem)
    x.problem * (x.auto ? " Ladder tries again in an hour." : "")
  elseif x.checked
    length(cloned) == 1 ? "$(cloned[1]) has the newest code from GitHub." : "$(join(cloned, ", ", " and ")) have the newest code from GitHub."
  else
    "Ladder hasn't looked for new code for $(join(cloned, ", ", " and ")) since it opened."
  end
  said * left
end

"""
What the button on the settings page does now: `:check` looks for new code,
and `:restart` closes Ladder and opens it again, with the new code. It's
`:none` when there's nothing to do.
"""
action(x::Extensions) = begin
  (isempty(blocked(x)) && x.task === nothing) || return :none
  any(c -> !last(c), clones(x.repos)) || return :none
  isempty(x.ready) ? :check : :restart
end

"What the button says for each `action`"
label(x::Extensions) = (a = action(x); a === :restart ? "Restart Ladder" : a === :check ? "Check now" : "")

"Do the `action`. After `:restart`, `x.again` is true: close every window, and `quit!` and `reopen!` do the rest."
act!(x::Extensions) = begin
  a = action(x)
  a === :check && check!(x)
  a === :restart && (x.again = true)
  x
end

"""
Call this when the last window has closed. With `auto` on, or after you
clicked Restart Ladder, each clone moves up to the new commits that wait in
it. It gives the name of each extension that moved.
"""
quit!(x::Extensions) = begin
  x.task !== nothing && istaskdone(x.task) && fetched!(x)
  (isempty(blocked(x)) && (x.auto || x.again)) || return String[]
  apply!(x.repos)
end

# Opens the app once the Ladder that asked has quit
const REOPEN = raw"""
pid="$1"; app="$2"; n=0
while kill -0 "$pid" 2>/dev/null && [ $n -lt 300 ]; do sleep 0.1; n=$((n+1)); done
/usr/bin/open "$app"
"""

"""
After Restart Ladder, start a program that outlives Ladder and opens the app
again once Ladder has quit. Call it when the app's own `quit!` didn't start a
program that does that. It's true when it started the program.
"""
reopen!(x::Extensions) = begin
  (x.again && isempty(blocked(x))) || return false
  try
    run(pipeline(detach(`/bin/sh -c $REOPEN sh $(getpid()) $(x.app)`), stdin=devnull, stdout=devnull, stderr=devnull), wait=false)
    true
  catch
    false
  end
end
