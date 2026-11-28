# The words that you gave an agent before, which ↑ and ↓ bring back to the
# field of the agent's pane, as they do in a terminal. A file keeps them, one
# line of JSON for each message, with the folder that the agent worked in:
#
#     {"dir":"/Users/me/notes","words":"Rotate the bus 90 degrees"}
#
#     keep_said!(file, dir, words)   # add words to the end of the file
#     said_before(file, dir)         # the words given in `dir`, the newest first

@use "github.com/jkroso/JSON.jl" json parse_json

export keep_said!, said_before, SAID_MOST

"How many messages the file keeps. When it has twice as many, the oldest go."
const SAID_MOST = 1000

"Add `words`, which you gave an agent that works in the folder `dir`, to the end of `file`"
keep_said!(file, dir, words) = try
  mkpath(dirname(file))
  open(io -> println(io, json(Dict("dir" => String(dir), "words" => String(words)))), file, "a")
  lines = readlines(file)
  length(lines) > 2SAID_MOST && write(file, join(lines[end-SAID_MOST+1:end], "\n") * "\n")
  nothing
catch
  nothing   # words that can't be kept don't stop them from going to the agent
end

"The words in `file` that you gave an agent that works in the folder `dir`, the newest first. The same words twice in a row show once."
said_before(file, dir) = begin
  found = String[]
  isfile(file) || return found
  for line in Iterators.reverse(readlines(file))
    o = try parse_json(line) catch; continue end
    (o isa AbstractDict && get(o, "dir", nothing) == dir) || continue
    words = get(o, "words", nothing)
    (words isa AbstractString && !isempty(words)) || continue
    !isempty(found) && last(found) == words && continue
    push!(found, String(words))
  end
  found
end
