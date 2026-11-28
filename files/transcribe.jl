# Writes down what's said in a sound file, or in the sound of a video file.
# transcribe.swift does the work, as a program of its own, because macOS only
# offers its speech recognition to Swift. It runs on the Mac, so the sound stays
# there.
#
#     t = Transcription("memo.m4a")   # starts it
#     check!(t)                       # call it now and then. It's true once it has finished.
#     t.done, t.downloading           # how far it has got
#     t.text, t.problem               # once it has finished
#
# With `times=true`, the text says when each phrase was said, so that you can
# take the words of part of the file:
#
#     t = Transcription("walk.mov", times=true)
#     check!(t) && words_between(phrases(t), 61, 86)   # what was said from 1:01 to 1:26
#
# The Ladder app has the program in it, beside its own program. When Ladder
# runs from its source, it compiles transcribe.swift the first time it's needed,
# which takes a few seconds, and keeps the program in a folder of the Mac's
# caches. That needs Swift, which comes with Xcode and its command line tools.

@use "../swift" target programs
@use "../swift" => Swift

const SOURCE = joinpath(@__DIR__, "transcribe.swift")

"The program in the Ladder app, or nothing when Ladder runs from its source"
bundled() = Swift.bundled("transcribe")

"Compile transcribe.swift into the program at `out`. The app's build runs it."
compile(out) = Swift.compile(SOURCE, out)

"""
The command that transcribes `file`: the program in the app, or the one compiled
from the source. If that isn't compiled yet, the command compiles it first.
`flags` go to the program before the file, like "--times".
"""
command(file, flags::String...) = Swift.command(SOURCE, "transcribe-", [flags..., file]; app="transcribe")

mutable struct Transcription
  file::String
  process::Any                   # the program, while it runs
  out::String                    # the file the program writes the text into
  err::String                    # the file it writes how far it has got into
  done::Float64                  # how much of the sound it has gone through, from 0 to 1
  downloading::Bool              # macOS is fetching what it needs for the language
  text::Union{Nothing,String}    # what's said in the file, once it has finished
  problem::String                # why it couldn't, if it couldn't
end

"Start to transcribe `file`. With `times=true`, the text says when each phrase was said: see `phrases`."
Transcription(file::AbstractString; times=false) = begin
  dir = mktempdir()
  t = Transcription(abspath(file), nothing, joinpath(dir, "text"), joinpath(dir, "progress"), 0.0, false, nothing, "")
  try
    t.process = run(pipeline(times ? command(t.file, "--times") : command(t.file), stdout=t.out, stderr=t.err), wait=false)
  catch
    t.problem = "Ladder couldn't start to transcribe the file"
  end
  t
end

"Has it finished, with the text or with a problem?"
finished(t::Transcription) = t.text !== nothing || !isempty(t.problem)

"Read how far it has got. It's true once it has finished."
check!(t::Transcription) = begin
  finished(t) && return true
  lines = isfile(t.err) ? readlines(t.err) : String[]
  for line in lines
    line == "downloading" && (t.downloading = true)
    startswith(line, "done ") && (t.done = something(tryparse(Float64, line[6:end]), t.done); t.downloading = false)
  end
  process_exited(t.process) || return false
  if success(t.process)
    t.text = strip(read(t.out, String))
  else
    why = findlast(l -> startswith(l, "error: "), lines)
    t.problem = why !== nothing ? lines[why][8:end] :
                t.process.exitcode == 127 ? "Ladder needs Swift to transcribe. It comes with Xcode's command line tools." :
                "The program that transcribes stopped before it finished"
  end
  rm(dirname(t.out), recursive=true, force=true)
  true
end

"Stop it before it finishes"
cancel!(t::Transcription) = (finished(t) || (kill(t.process); t.problem = "Stopped"); t)

"""
The phrases of a transcription that was started with `times=true`, once it has
finished: for each, the second of the file where it starts, the second where it
ends, and its words.
"""
phrases(t::Transcription) = begin
  out = Tuple{Float64,Float64,String}[]
  t.text === nothing && return out
  for line in split(t.text, '\n')
    parts = split(line, '\t', limit=3)
    length(parts) == 3 || continue
    from, to = tryparse(Float64, parts[1]), tryparse(Float64, parts[2])
    (from === nothing || to === nothing || isempty(strip(parts[3]))) && continue
    push!(out, (from, to, String(strip(parts[3]))))
  end
  out
end

"How many seconds without words start a new paragraph, as transcribe.swift has it"
const PAUSE = 2.0

"""
What was said between second `from` and second `to` of the file that
`phrases` come from: each phrase whose middle is in that time. A pause of
`PAUSE` seconds or more starts a new paragraph, with an empty line before it.
"""
words_between(phrases, from, to) = begin
  text, last = "", -Inf
  for (s, e, words) in phrases
    from <= (s + e) / 2 < to || continue
    text *= isempty(text) ? "" : s - last >= PAUSE ? "\n\n" : " "
    text *= words
    last = e
  end
  text
end
