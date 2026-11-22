# Builds Ladder as a standalone Mac app with JuliaC. build.jl includes this
# file and calls `build_app`:
#
#     julia --project=. app/build.jl
#     julia --project=. app/build.jl --install
#
# It writes the app into build/, checks it with the app's self-test, and prints
# how much space each part takes. The app runs without Julia installed.
# `--install` then copies it into /Applications, in place of any copy already
# there. JuliaC must be in your global environment (`] add JuliaC`), and you need
# a C compiler, such as the one in Xcode's command line tools.
#
# These environment variables change how it's built:
#
#   APP_SIGN=...         who signs the app: the name of a certificate in your keychain, like
#                        "Developer ID Application". It's your Developer ID certificate if
#                        your keychain has one. `-` signs it for this Mac only, and each
#                        build is then a new app to macOS, so the Keychain asks for your
#                        password again before the app can read its email passwords.
#   APP_RELEASE=0        1 signs each program and library with a time stamp and the hardened
#                        runtime, as Apple needs before it notarises the app. release.jl sets
#                        this. Without it, the app is marked as built on this Mac, and it
#                        doesn't update itself. See update.jl.
#   APP_CPU=apple-m1     the CPUs to compile for. apple-m1 runs on every Apple Silicon Mac.
#   APP_STRIP=           what to leave out: `metadata` leaves out docstrings and line numbers,
#                        and `ir` the code Julia would need to compile anything new while
#                        the app runs. Ladder keeps both. The open box of a function or a
#                        module shows its documentation, and an error says where it happened.
#   APP_TRIM=no          JuliaC's trimming: no, safe, unsafe or unsafe-warn. Trimming leaves out
#                        the code the app doesn't use. The app is first run with
#                        `--record`, and opens its window for a few seconds. See record.jl.
#   APP_PRUNE=1          delete the native libraries the self-test didn't load.
#   APP_PROJECT=path     the Julia project to build from, if not Ladder's own.
#
# The app's entry point is app.jl, which starts with start.jl.

using JuliaC, Kip

const root = normpath(joinpath(@__DIR__, ".."))
const out = joinpath(root, "build")

option(name, default) = get(ENV, "APP_$name", default)
const cpu = option("CPU", "apple-m1")
const strips = split(option("STRIP", ""), ',', keepempty=false)
const trim = option("TRIM", "no")
const prune = option("PRUNE", "1") == "1"

"The name of the Developer ID certificate in your keychain, or `-` when there's none"
developer_id() = try
  m = match(r"\"(Developer ID Application: [^\"]+)\"", read(`security find-identity -v -p codesigning`, String))
  m === nothing ? "-" : String(m[1])
catch
  "-"
end
const signer = option("SIGN", developer_id())
const releasing = option("RELEASE", "0") == "1"

"""
A new folder with a copy of `dir`'s project files and nothing else. JuliaC
copies all of the project folder it's given, and Ladder's holds build/, where
the app is.
"""
project_files(dir) = begin
  copy = mktempdir()
  for f in readdir(dir)
    occursin(r"^(Julia)?(Project|Manifest|LocalPreferences).*\.toml$", f) && cp(joinpath(dir, f), joinpath(copy, f))
  end
  copy
end

const project = project_files(option("PROJECT", root))

# --- the packages Kip gets from GitHub ------------------------------------------
#
# Ladder names UI.jl and other packages by their GitHub paths. When Ladder
# runs from its source, Kip loads a linked package from its folder if the
# folder has changes that aren't committed, and from a copy of its last commit
# if not. While Julia builds an app, Kip can't ask Git which of those to use,
# and it loads the newest copy it has of any commit. That copy can be older than
# what you've been running. So the build first asks Kip where each package is,
# and gives the build a folder of links to those places to use as Kip's own.

"Each `.jl` and `.md` file under `dir`, apart from those in hidden folders and build folders"
source_files(dir) = begin
  found = String[]
  for (folder, folders, files) in walkdir(dir)
    filter!(f -> !startswith(f, ".") && f != "build", folders)
    append!(found, joinpath(folder, f) for f in files if endswith(f, ".jl") || endswith(f, ".md"))
  end
  found
end

"""
Where a normal run finds each GitHub package that Ladder's code names, or that
one of those packages names. Each key is a `(user, repo)`.
"""
find_packages() = begin
  places = Dict{Tuple{String,String},String}()
  waiting = [root]
  while !isempty(waiting)
    for file in source_files(pop!(waiting)), m in eachmatch(r"\"github\.com/([\w\-.]+)/([\w\-.]+)", read(file, String))
      key = (String(m[1]), String(m[2]))
      (haskey(places, key) || !isdir(joinpath(Kip.repos, key...))) && continue
      places[key] = try
        rstrip(Kip.checkout_repo(Kip.getrepo(key...), key..., nothing), '/')
      catch
        # Kip can't tell which commit to use, so use the folder as it is
        realpath(joinpath(Kip.repos, key...))
      end
      push!(waiting, places[key])
    end
  end
  places
end

const packages = find_packages()

"The packages that the app would be built from a folder with changes that aren't committed"
uncommitted() = sort!(["$user/$repo" for ((user, repo), place) in packages
                       if isdir(joinpath(place, ".git")) && Kip.LibGit2.isdirty(Kip.LibGit2.GitRepo(place))])

"A folder to be Kip's own while the app is built. It holds a link to where each package is."
package_links() = begin
  dir = mktempdir()
  for ((user, repo), place) in packages
    mkpath(joinpath(dir, "repos", user))
    symlink(place, joinpath(dir, "repos", user, repo))
  end
  dir
end

"""
Build `entry` into build/`name`.app, with the program in Contents/MacOS/`program`.
`id` is its bundle identifier and `version` its version, like "1.2.0". `threads` sets how many threads the app runs
with, in the form of Julia's `--threads` option. `icon` is a PNG 1024 pixels
square to show for the app. `plist` holds more keys for its Info.plist. `helpers`
are the paths of other programs to put in Contents/MacOS beside the app's own.
Returns the path to the app.
"""
build_app(; name, program, id, entry, version="1.0", threads=nothing, icon=nothing, plist="", helpers=String[]) = begin
  bundle = joinpath(out, program)
  app = joinpath(out, name * ".app")
  contents = joinpath(app, "Contents")
  rm(bundle, recursive=true, force=true)
  rm(app, recursive=true, force=true)

  # Kip normally keeps a compiled cache of each file it loads. Julia can't make
  # those while it builds an app, so Kip includes the files directly instead.
  ENV["KIP_FROZEN"] = "1"
  ENV["KIP_DIR"] = package_links()
  changed = uncommitted()
  isempty(changed) || println("Building with the changes that aren't committed in ", join(changed, ", ", " and "))

  options = threads === nothing ? Dict{String,String}() : Dict("threads" => threads)
  build_time = @elapsed begin
    trim == "no" || (ENV["APP_CALLS"] = record_calls(entry, threads))
    image = ImageRecipe(output_type="--output-exe", file=entry, project=project, cpu_target=cpu,
                        trim_mode=trim, julia_args=["--strip-$s" for s in strips], jl_options=options)
    link = LinkRecipe(image_recipe=image, outname=joinpath(bundle, program), rpath="@bundle")
    compile_products(image)
    link_products(link)
    bundle_products(BundleRecipe(link_recipe=link, output_dir=bundle))
  end

  # A Mac app is a folder with the program in Contents/MacOS. The program looks
  # for its libraries in ../lib, so they move into Contents beside it.
  mkpath(contents)
  for part in readdir(bundle)
    mv(joinpath(bundle, part), joinpath(contents, part == "bin" ? "MacOS" : part))
  end
  rm(bundle)
  foreach(h -> cp(h, joinpath(contents, "MacOS", basename(h))), helpers)
  if icon !== nothing
    mkpath(joinpath(contents, "Resources"))
    make_icns(icon, joinpath(contents, "Resources", "AppIcon.icns"))
    plist = "  <key>CFBundleIconFile</key><string>AppIcon</string>\n" * plist
  end
  write(joinpath(contents, "Info.plist"), """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>CFBundleName</key><string>$name</string>
      <key>CFBundleDisplayName</key><string>$name</string>
      <key>CFBundleIdentifier</key><string>$id</string>
      <key>CFBundleVersion</key><string>$version</string>
      <key>CFBundleShortVersionString</key><string>$version</string>
      <key>CFBundlePackageType</key><string>APPL</string>
      <key>CFBundleExecutable</key><string>$program</string>
      <key>LSMinimumSystemVersion</key><string>12.0</string>
      <key>NSHighResolutionCapable</key><true/>
    $(plist)</dict>
    </plist>
    """)

  executable = joinpath(contents, "MacOS", program)
  loaded = self_test(contents, executable)
  if prune
    println("Pruning removed ", mb(prune_libraries(contents, loaded)))
    println("Stand-ins for unused libraries saved ", mb(stub_unused_libraries(contents)))
    self_test(contents, executable)
  end

  sign(app)

  println("\nBuilt in ", round(build_time / 60, digits=1), " minutes with cpu=$cpu strip=$(join(strips, ',')) trim=$trim",
          prune ? " pruned" : "")
  println(app, ": ", mb(disk_size(app)))
  for part in ("MacOS/$program", "lib", "share")
    println("  ", rpad(part, 18), lpad(mb(disk_size(joinpath(contents, part))), 10))
  end
  "--install" in ARGS && install(app)
  app
end

mb(n) = string(round(n / 1e6, digits=1), " MB")

"True when the file at `path` holds compiled code: a program or a library"
compiled(path) = begin
  magic = open(io -> read(io, 4), path)
  magic in ([0xcf, 0xfa, 0xed, 0xfe], [0xca, 0xfe, 0xba, 0xbe])
end

"""
Sign `app` as `signer`. `-` signs it for this Mac only, so macOS will open it
here. With a Developer ID certificate, other Macs open it too, once Apple has
notarised it. Apple only notarises an app if each program and library in it is
signed, with a time stamp and the hardened runtime. entitlements.plist lists
what the hardened runtime must still allow: Julia compiles code while the app
runs, and the app records from the microphone.

A build that isn't for a release gets no time stamp or hardened runtime, as only
Apple checks those. Its certificate still matters here: the Keychain and macOS's
privacy settings know an app by its signature. A certificate's signature names
the app and its developer, so each new build is the same app to them. A build
signed with `-` is known only by its own contents, so each one is a new app.
"""
sign(app) = begin
  # Every build has the entitlements, not only a release. JavaScriptCore compiles a page's scripts only in an app
  # that has com.apple.security.cs.allow-jit. Without it, it only interprets them, many times slower, and the
  # first run of a big page's scripts, like a three.js city, runs out of time.
  entitlements = joinpath(@__DIR__, "entitlements.plist")
  signer == "-" && return run(`codesign --force --deep --entitlements $entitlements --sign - $app`)
  # Pruning deletes libraries and leaves the links that pointed to them. codesign refuses an app with a link to nothing.
  for (dir, _, names) in walkdir(app), name in names
    link = joinpath(dir, name)
    islink(link) && !ispath(link) && rm(link)
  end
  how = releasing ? `--force --timestamp --options runtime --entitlements $entitlements --sign $signer` :
                    `--force --timestamp=none --entitlements $entitlements --sign $signer`
  parts = filter(compiled, files_in(joinpath(app, "Contents")))
  println("Signing ", length(parts), " programs and libraries as ", signer)
  # The deepest first, since a folder's signature covers what's in it
  for part in sort(parts, by=p -> -count('/', p))
    run(pipeline(`codesign $how $part`, stderr=devnull))
  end
  run(`codesign $how $app`)
  run(`codesign --verify --deep --strict $app`)
end

"""
Run the app with `--record`, while Julia writes down each call it makes through a
dynamic dispatch, and return the file it wrote. A trimmed build keeps those
calls. See record.jl. The app opens its window for a few seconds.
"""
record_calls(entry, threads) = begin
  calls = joinpath(mktempdir(), "calls.jl")
  # The menus' Show in Finder and Open run `open`. Here it does nothing.
  bin = mktempdir()
  write(joinpath(bin, "open"), "#!/bin/sh\n")
  chmod(joinpath(bin, "open"), 0o755)
  flags = threads === nothing ? `` : `--threads=$threads`
  cmd = `$(Base.julia_cmd()) --project=$(option("PROJECT", root)) $flags --trace-dispatch=$calls $entry --libraries --record`
  # Its output goes to a file, as a trimmed app's does, so it prints through the same methods
  log = joinpath(dirname(calls), "output.txt")
  env = addenv(cmd, "KIP_FROZEN" => "1", "PATH" => bin * ":" * ENV["PATH"])
  process = run(pipeline(env, stdout=log, stderr=log), wait=false)
  # A window that gets stuck would stop the build. A stuck Julia may not be able
  # to act on a polite request to stop, so this one can't be refused.
  timer = Timer(_ -> process_running(process) && kill(process, Base.SIGKILL), 600)
  wait(process)
  close(timer)
  success(process) || error("The app failed while its calls were recorded:\n", read(log, String))
  println("Recorded ", count(startswith("precompile("), eachline(calls)), " calls")
  calls
end

"Make the .icns file `icns` from `png`, with each of the sizes macOS shows icons at"
make_icns(png, icns) = begin
  set = joinpath(mktempdir(), "AppIcon.iconset")
  mkpath(set)
  for points in (16, 32, 128, 256, 512), scale in (1, 2)
    file = joinpath(set, "icon_$(points)x$(points)$(scale == 2 ? "@2x" : "").png")
    run(pipeline(`sips -z $(points * scale) $(points * scale) $png --out $file`, stdout=devnull))
  end
  run(`iconutil -c icns $set -o $icns`)
end

"""
Run the app's self-test, and return the libraries it loaded. The test runs in a
sandbox that can't read ~/.julia, ~/.kip, Ladder's own files or UI.jl's, as on a Mac
without them. Without that, the app would find the libraries it wraps in
~/.julia, or icons in UI.jl's folder, and a missing one inside the app would go
unnoticed.

Some packages look for their files when the app starts, even though the app
never uses them. Git is one: Kip uses it to fetch code while the app is built.
Each of those gets an empty folder of the name it looks for.
"""
self_test(contents, executable) = begin
  depot = joinpath(contents, "share", "julia")
  # The app can still look at Ladder's folders, since it sits inside one, but it
  # can't read what's in them, or in a copy of UI.jl beside Ladder
  sandbox = """(version 1)(allow default)
    (deny file-read* (subpath "$(joinpath(homedir(), ".julia"))") (subpath "$(joinpath(homedir(), ".kip"))"))
    (deny file-read-data (subpath "$(rstrip(root, '/'))") (subpath "$(joinpath(dirname(rstrip(root, '/')), "UI.jl"))"))
    (allow file-read-data (subpath "$out"))"""
  for _ in 1:20
    output, errors = IOBuffer(), IOBuffer()
    cmd = addenv(`sandbox-exec -p $sandbox $executable --self-test --libraries`, "JULIA_DEPOT_PATH" => depot)
    if success(pipeline(ignorestatus(cmd), stdout=output, stderr=errors))
      lines = split(String(take!(output)), '\n', keepempty=false)
      println(lines[1])
      return Set(realpath(l) for l in lines[2:end] if ispath(l))
    end
    problem = String(take!(errors))
    # The error quotes the name and path, with backslashes before the quotes
    m = match(r"Artifact \W*(\w+)\W* was not found by looking in the path \W*(/[^\"\\]+)", problem)
    m === nothing && error("The self-test failed:\n", first(problem, 2000))
    mkpath(m[2])
    println("Gave ", m[1], " an empty folder. The app doesn't use it.")
  end
  error("The self-test kept finding missing folders")
end

"Every file under `dir`, apart from links"
files_in(dir) = [joinpath(d, f) for (d, _, fs) in walkdir(dir) for f in fs if !islink(joinpath(d, f))]
"Bytes used by the files under `path`"
disk_size(path) = isfile(path) ? filesize(path) : sum(filesize, files_in(path), init=0)

"""
Delete each library in the app that the self-test didn't load, and the folders
of data that only belong to those libraries. Returns how many bytes it freed.
"""
prune_libraries(contents, loaded) = begin
  removed = 0
  for path in vcat(files_in(joinpath(contents, "lib")), files_in(joinpath(contents, "share")))
    endswith(path, ".dylib") || occursin(".dylib.", path) || continue
    realpath(path) in loaded && continue
    occursin("libjulia", basename(path)) && continue
    removed += filesize(path)
    rm(path)
  end
  for dir in readdir(joinpath(contents, "share", "julia", "artifacts"), join=true)
    isdir(dir) || continue
    any(endswith(".dylib"), files_in(dir)) && continue
    any(p -> startswith(p, dir), loaded) && continue
    # A folder with no library left holds data for one that's gone, like
    # keyboard layouts for Linux. Its package may still look for the folder when
    # the app starts, so the folder stays, empty.
    for f in readdir(dir, join=true)
      removed += isdir(f) ? sum(filesize, files_in(f), init=0) : filesize(f)
      rm(f, recursive=true)
    end
  end
  removed
end

# The libraries the app calls into. Each package that wraps a library loads all
# of that library's files when the app starts, so many more load than are used.
# ICU is one: Skia's package lists it, but Skia on macOS uses Apple's text APIs.
const called = ("libskia", "libglfw", "libfontconfig")

install_name(path) = String(strip(last(split(readchomp(`otool -D $path`), '\n'))))
links(path) = [String(first(split(strip(l)))) for l in split(readchomp(`otool -L $path`), '\n')[2:end]]

"""
Keep the libraries the app calls and everything they link to. Swap each other
library for an empty one with the same name, which still loads but holds no
code. Then delete what only command line tools and compilers use. Returns how
many bytes it freed.
"""
stub_unused_libraries(contents) = begin
  artifacts = joinpath(contents, "share", "julia", "artifacts")
  dylibs = filter(p -> endswith(p, ".dylib"), files_in(artifacts))
  by_name = Dict(install_name(p) => p for p in dylibs)
  keep = Set{String}()
  queue = filter(p -> any(c -> startswith(basename(p), c), called), dylibs)
  while !isempty(queue)
    p = pop!(queue)
    p in keep && continue
    push!(keep, p)
    append!(queue, (by_name[l] for l in links(p) if haskey(by_name, l)))
  end
  before = disk_size(artifacts)
  for p in dylibs
    p in keep && continue
    stub = p * ".stub"
    run(`clang -dynamiclib -x c /dev/null -install_name $(install_name(p)) -o $stub`)
    mv(stub, p, force=true)
  end
  for dir in readdir(artifacts, join=true)
    for part in ("bin", "include", "lib/pkgconfig", "lib/cmake", "share/man", "share/doc", "share/info", "logs")
      rm(joinpath(dir, part), recursive=true, force=true)
    end
    foreach(rm, filter(endswith(".a"), files_in(dir)))
  end
  before - disk_size(artifacts)
end

const lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

"""
Copy `app` into /Applications, in place of any copy already there. Then tell
macOS about it, so the Dock and Finder show its new icon.
"""
install(app) = begin
  target = joinpath("/Applications", basename(app))
  rm(target, recursive=true, force=true)
  run(`ditto $app $target`)
  run(`$lsregister -f $target`)
  println("Installed ", target)
end
