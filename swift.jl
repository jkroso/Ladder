# Compiles and runs Ladder's Swift helper programs, and keeps the files that
# they make.
#
# Several macOS features are offered only to Swift: speech recognition in
# transcribe.swift, Apple Maps in map.swift, and WebKit in webpage.swift.
# When Ladder runs as a built app, some helpers live inside the app bundle.
# When Ladder runs from its source, each helper is compiled the first time it's
# needed and kept in the Mac's caches under a name that changes when its source
# changes.

@use "github.com/jkroso/UI.jl/Interface/objc" cls msg nsstring jstring with_pool

const RETRY = 60   # seconds after a helper fails before Ladder runs it again

"What a Swift helper program is compiled for: this Mac's kind of processor, and macOS 26"
target() = "$(Sys.ARCH == :aarch64 ? "arm64" : "x86_64")-apple-macos26.0"

"The folder of the Mac's caches that keeps programs compiled from Swift source"
programs() = joinpath(homedir(), "Library", "Caches", "Ladder")

"The program called `name` in the Ladder app, or nothing when Ladder runs from its source"
bundled(name::AbstractString) = begin
  Sys.isapple() || return nothing
  path = with_pool() do
    jstring(msg(msg(cls("NSBundle"), "mainBundle"), "pathForAuxiliaryExecutable:", nsstring(name)))
  end
  isfile(path) ? path : nothing
end

"Compile the Swift file `source` into the program at `out`. The app's build runs it."
compile(source::AbstractString, out::AbstractString) =
  run(`swiftc -O -parse-as-library -target $(target()) $source -o $out`)

"""
The command that runs the Swift program built from `source` with `args`. When
`app` names an auxiliary executable in the Ladder app and it's there, that
program runs. Otherwise the compiled copy is kept in `dir` under `prefix` and a
hash of `source`; if it isn't compiled yet, the command compiles it first and
removes copies compiled from older source.
"""
command(source::AbstractString, prefix::AbstractString, args; app=nothing, dir=programs()) = begin
  if app !== nothing
    kept = bundled(app)
    kept === nothing || return `$kept $args`
  end
  # A change to the source makes a program of a new name
  program = joinpath(dir, prefix * string(hash(read(source)), base=16))
  isfile(program) && return `$program $args`
  mkpath(dir)
  # A program compiled from older source isn't needed. One that's being compiled from this source now is left alone.
  foreach(f -> startswith(f, prefix) && !startswith(f, basename(program)) && rm(joinpath(dir, f), force=true), readdir(dir))
  # It's compiled to a name of this run's own and renamed once it's whole, so a program that's there is always
  # whole even when two runs compile it at once.
  script = """swiftc -O -parse-as-library -target $(target()) "\$1" -o "\$2.\$\$" && mv "\$2.\$\$" "\$2" && p="\$2" && shift 2 && exec "\$p" "\$@" """
  `sh -c $script sh $source $program $args`
end

# What's known of each file that isn't kept yet, by the file: the program that makes it, the number that
# the program ended with, or the state that it ended in with when that was and what to say
const jobs = Dict{String,Any}()

# The words to show if a job fails, kept by target file while the job runs
const messages = Dict{String,NamedTuple{(:failed, :lost, :no_swift),Tuple{String,String,String}}}()

const LOST = "Ladder couldn't find it."
const FAILED = "Ladder couldn't make this file now."
const NO_SWIFT = "Ladder needs Swift to run this helper. It comes with Xcode's command line tools."

"What `kept!` gives: the state of a file, the file, what to say when it can't be made, and in how many seconds to ask again"
const Kept = @NamedTuple{state::Symbol, file::String, problem::String, wait::Float64}

"""
The state of the file `target`, which a program makes and Ladder keeps:

- `:there` when the file is kept.
- `:coming` while the program makes it. Ask again in `wait` seconds.
- `:failed` for a minute after the program couldn't make it, as with no
  network. Ladder tries again after that minute.
- `:lost` when the program ended with code 2 (not found). Ladder doesn't try again.
- `:none` when it isn't kept and, with `start=false`, it wasn't asked for.

`problem` is what to tell the person when the state is `:failed` or `:lost`.
`make(part, err)` starts the program, which writes the file to `part` and why
it failed to `err`.
"""
kept!(make, target; start=true, failed=FAILED, lost=LOST, no_swift=NO_SWIFT) = begin
  got(state, problem="", wait=Inf) = (state=state, file=target, problem=problem, wait=Float64(wait))
  settle!()
  isfile(target) && return got(:there)
  job = get(jobs, target, nothing)
  job isa Base.Process && return got(:coming, "", 0.2)
  if job isa Integer
    job = jobs[target] = finish!(target, job)
    isfile(target) && (delete!(jobs, target); return got(:there))
  end
  if job isa Tuple
    state, when, problem = job
    state == :lost && return got(:lost, problem)
    left = RETRY - (time() - when)
    (left > 0 || !start) && return got(:failed, problem, left > 0 ? left : Inf)
  end
  start || return got(:none)
  part, err = target * ".part", target * ".err"
  messages[target] = (failed=failed, lost=lost, no_swift=no_swift)
  jobs[target] = try
    mkpath(dirname(target))
    foreach(f -> rm(f, force=true), (part, err))
    make(part, err)
  catch
    1
  end
  # A function that has made the file already has it kept in the same call
  jobs[target] isa Base.Process ? got(:coming, "", 0.2) : kept!(make, target; start=false, failed, lost, no_swift)
end

"""
Keep the file of each program that has finished, whichever file is asked for
now. So a file is kept though its caller asks for another by then.
"""
settle!() = for (target, job) in collect(jobs)
  (job isa Base.Process && process_exited(job)) || continue
  # A program that was stopped didn't make the file, whatever number it ended with
  done = finish!(target, success(job) ? 0 : max(1, job.exitcode))
  done[1] == :there ? delete!(jobs, target) : (jobs[target] = done)
end

"""
The program that makes the file `target` ended with `code`. Keep the file, or
note why there's none. It gives the state, when that was, and what to say.
"""
finish!(target, code) = begin
  part, err = target * ".part", target * ".err"
  msg = pop!(messages, target, (failed=FAILED, lost=LOST, no_swift=NO_SWIFT))
  state = try
    if code == 0 && isfile(part) && filesize(part) > 0
      mv(part, target, force=true)
      (:there, time(), "")
    elseif code == 2
      (:lost, time(), msg.lost)
    else
      (:failed, time(), code == 127 ? msg.no_swift : msg.failed)
    end
  catch
    (:failed, time(), msg.failed)
  end
  foreach(f -> rm(f, force=true), (part, err))
  state
end

"""
The file `target` turned out not to hold what it should, as a picture that
was cut short. Take it away, so that Ladder makes it again in a minute.
"""
spoiled!(target; failed=FAILED) = begin
  rm(target, force=true)
  delete!(messages, target)
  jobs[target] = (:failed, time(), failed)
  nothing
end
