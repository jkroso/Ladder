# The words that a picture shows, like the text of a screenshot, which a
# search of main.jl's folders of pictures finds. macOS reads them.
# It takes a part of a second for each picture, and half a minute the first
# time after the Mac starts. So a second thread does the reading, one picture
# after another, and the window never waits: `words` gives what's known now,
# and asks for the rest. What was read is kept in a file beside the Mac's
# caches, so each picture is read once.
#
#     words(path)      # "ladder read only main 18 changes ...", or nothing while it isn't read yet
#     reading()        # how many pictures still wait
#     version[]        # grows each time a picture has been read

@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg get_value nsstring jstring with_pool

const Object = Ptr{Cvoid}

const Vision = "/System/Library/Frameworks/Vision.framework/Vision"

"The words that macOS reads in the picture at `path`, one line of the picture to a line. It waits for macOS."
read_words(path::AbstractString) = begin
  Sys.isapple() || return ""
  Base.Libc.Libdl.dlopen(Vision)
  with_pool() do
    url = msg(cls("NSURL"), "fileURLWithPath:", nsstring(path))
    handler = msg(ccall((:objc_msgSend, libobjc), Object, (Object, Object, Object, Object),
                        msg(cls("VNImageRequestHandler"), "alloc"), sel("initWithURL:options:"), url, msg(cls("NSDictionary"), "dictionary")), "autorelease")
    request = msg(msg(msg(cls("VNRecognizeTextRequest"), "alloc"), "init"), "autorelease")
    requests = msg(cls("NSArray"), "arrayWithObject:", request)
    # Julia's other threads go on while macOS reads, and can free memory
    ok = @ccall gc_safe=true libobjc.objc_msgSend(handler::Object, sel("performRequests:error:")::Object, requests::Object, C_NULL::Object)::Bool
    ok || return ""
    results = msg(request, "results")
    results == C_NULL && return ""
    lines = String[]
    for i in 0:get_value(UInt, results, "count")-1
      seen = ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), results, sel("objectAtIndex:"), i)
      best = msg(ccall((:objc_msgSend, libobjc), Object, (Object, Object, UInt), seen, sel("topCandidates:"), 1), "firstObject")
      best == C_NULL || push!(lines, jstring(msg(best, "string")))
    end
    join(lines, '\n')
  end
end

# What reads a picture's words. A test puts a function of its own here.
const reader = Ref{Function}(read_words)
"The file that keeps the words of each picture, in the home folder of whoever runs Ladder. A test names one of its own."
const words_file = Ref("")
"The file that keeps the words of each picture when nothing else is named"
usual_words_file() = joinpath(homedir(), "Library", "Caches", "Ladder", "picture-words.tsv")

const words_lock = ReentrantLock()
"The words of each picture that was read, in small letters, by its path, with when its file had changed"
const WORDS = Dict{String,Tuple{Float64,String}}()
"The paths of the pictures that wait to be read, the first to read first"
const waiting = String[]
"Grows each time a picture has been read, so that a view knows to look again"
const version = Ref(0)
const working = Ref(false)   # the thread that reads is running
const loaded = Ref("")       # the file that `WORDS` was last read from
const unsaved = Ref(0)       # how many pictures were read since the file was written

# The app that's built keeps what these hold when it's made, on the Mac that made it. So the app starts
# with nothing read, no thread at work, and the file in the home folder of whoever runs it.
__init__() = begin
  empty!(WORDS); empty!(waiting)
  working[], loaded[], unsaved[] = false, "", 0
  words_file[] = usual_words_file()
  nothing
end

"Read the file of the words, once for each file that `words_file` names"
load_words!() = begin
  loaded[] == words_file[] && return
  loaded[] = words_file[]
  empty!(WORDS)
  isfile(words_file[]) || return
  for line in eachline(words_file[])
    f = split(line, '\t', limit=3)
    length(f) == 3 || continue
    at = tryparse(Float64, f[1])
    at === nothing || (WORDS[String(f[2])] = (at, String(f[3])))
  end
  nothing
end

"Write the words of each picture that's still there to the file"
save_words!() = begin
  unsaved[] = 0
  try
    mkpath(dirname(words_file[]))
    open(words_file[] * ".part", "w") do io
      for (path, (at, text)) in WORDS
        isfile(path) && println(io, at, '\t', path, '\t', text)
      end
    end
    mv(words_file[] * ".part", words_file[], force=true)
  catch
  end
  nothing
end

"Read the pictures that wait, one after another, until none waits"
work!() = begin
  while true
    path = lock(words_lock) do
      isempty(waiting) ? nothing : first(waiting)
    end
    path === nothing && break
    at = mtime(path)
    text = try lowercase(replace(reader[](path), r"\s+" => " ")) catch; "" end
    lock(words_lock) do
      WORDS[path] = (at, text)
      filter!(!=(path), waiting)
      version[] += 1
      unsaved[] += 1
      (isempty(waiting) || unsaved[] >= 25) && save_words!()
    end
  end
  lock(() -> (working[] = false), words_lock)
  nothing
end

"""
The words in the picture at `path`, in small letters with one space between
them, or nothing while the picture isn't read yet. A picture that isn't read
is put with the ones that wait, and a second thread reads them. `at` is when
the picture's file last changed, for a caller that knows it already.
"""
words(path::AbstractString, at::Real=mtime(path)) = lock(words_lock) do
  load_words!()
  kept = get(WORDS, path, nothing)
  kept !== nothing && kept[1] == at && return kept[2]
  path in waiting || push!(waiting, path)
  if !working[]
    working[] = true
    Threads.@spawn work!()
  end
  nothing
end

"How many pictures wait to be read"
reading() = lock(() -> length(waiting), words_lock)

"Leave the pictures that wait unread, when nobody asks for their words any more. The one that's being read is finished."
stop_reading!() = lock(words_lock) do
  length(waiting) > 1 && resize!(waiting, 1)
  nothing
end
