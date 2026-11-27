# Programs that start again when the terminal opens again: the Program Resume
# Protocol, https://www.superlogical.com/rex/docs/build/program-resume
#
# A program that runs in a terminal can tell the terminal which command starts
# it again, as an agent does with the name of its session, or an editor with
# the file that keeps its windows. When the terminal's app closes and opens
# again, the terminal runs that command in the person's shell, and the program
# is back where it was.
#
# The program says it with a code, ESC ] 7577 ; body, and the body is pairs:
#
#     pid=74877:time=1795543200:argv=bnZpbQ,LVM:cwd=L1VzZXJz:mac=9f…
#
#   pid    the program that the command starts again
#   time   when the program said this, in seconds
#   argv   the command: each of its words in base64, with commas between them
#   cwd    the folder to run it in, in base64
#   clear  `clear=1` in place of argv: the program has no command any more
#   need   the keys that the terminal must know, or it takes none of the report
#   mac    the SHA-256 sum of the body before it, a colon, and the token
#
# The token is a secret that the terminal makes for each shell that it starts.
# It's in that shell's environment as OSC7577_TOKEN, and nowhere else. Text that
# only shows in the terminal doesn't know it: a file that `cat` prints, or what
# a server sends over ssh. So such text can't make the terminal run a command.
#
#     read_report(body, token)    # a Report, a Rejected, or nothing
#     hear!(records, heard, body, token; tty, top)   # what a report does to a terminal's records
#     keep!(path, records)        # write the records of the terminal whose file is at `path`
#     waiting(path)               # the record to start again when that terminal next opens
#     prepare(record)             # what to type at the shell's first prompt to start it
#     quiet(shell, words)         # what a shell's environment needs to keep that out of its history
#
# What a report says is one of three things. It's nothing when the terminal
# can't believe it: the sum is wrong, or it was said at another time than now.
# Nothing changes then. It's a `Rejected` when the sum is right and the report
# is still no good. The program's command has changed to one that can't be
# said, so what the terminal knew of that program is out of date and goes. And
# it's a `Report`, which makes a `Record` or takes one away.
#
# The records of a terminal are in a file of their own, in a folder that only
# the person can read: a record is a command that runs later, as a line of a
# shell's settings is. They're never in the terminal's own file, which can be
# in a project that other people write to.

const CODE = "7577"
const TOKEN_NAME = "OSC7577_TOKEN"
const NEAR = 60            # seconds that a report's time can be from now
const GRACE = 2.0          # seconds that a program that ended still counts as running: the terminal may be closing too
const KNOWN = ("pid", "time", "mac", "argv", "cwd", "clear", "need")
const MOST_PID = Int(typemax(Int32))
const OLD_RUN = 86_400.0   # seconds after which a file of a command that never ran is taken away

"A folder to keep the records in, in place of the app's own. A test puts one here."
const STORE = Ref("")

"The folder that keeps the records: with the app's own files, unless `STORE` names another"
place() = isempty(STORE[]) ? joinpath(homedir(), "Library", "Application Support", "Ladder", "resume") : STORE[]

# A built app starts with what this held while it was built
__init__() = (tidied[] = false; nothing)

const TOKEN_LETTERS = collect("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")

# macOS itself works out the sum and gives the bytes that nothing can guess, so this file needs no library

"The SHA-256 sum of `text`, as 64 digits in hexadecimal"
sum256(text::String) = begin
  out = zeros(UInt8, 32)
  ccall(:CC_SHA256, Ptr{UInt8}, (Ptr{UInt8}, UInt32, Ptr{UInt8}), text, sizeof(text), out)
  bytes2hex(out)
end

"`n` bytes that nothing can guess"
unguessed(n) = (out = zeros(UInt8, n); ccall(:arc4random_buf, Cvoid, (Ptr{UInt8}, Csize_t), out, n); out)

"A new token: 32 characters that nothing can guess"
token() = String([TOKEN_LETTERS[b & 0x3f + 1] for b in unguessed(32)])

"The person that this app runs as"
me() = ccall(:getuid, UInt32, ())

"True where the terminal takes reports: on a Mac, and never as root, whose commands nothing should start by itself"
supported() = Sys.isapple() && ccall(:geteuid, UInt32, ()) != 0

# --- what a report says ---------------------------------------------------------------------

"What a program said: the command that starts it again, or that it has none any more"
struct Report
  pid::Int
  time::Int
  argv::Vector{String}   # empty when `clear`
  cwd::String            # "" when the program named no folder
  clear::Bool
end

"A report that had the right sum and still can't be taken. `pid` is the program that it was for, or nothing."
struct Rejected
  pid::Union{Int,Nothing}
end

const LETTERS = Dict{Char,UInt32}(c => UInt32(k - 1) for (k, c) in enumerate("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"))

"The bytes that base64 text stands for, or nothing when it isn't base64. The = signs at its end can be left out, but not be wrong."
unbase64(text::AbstractString) = begin
  body = rstrip(text, '=')
  pad = ncodeunits(text) - ncodeunits(body)
  (pad > 2 || (pad > 0 && ncodeunits(text) % 4 != 0) || ncodeunits(body) % 4 == 1) && return nothing
  out = UInt8[]
  held, bits = UInt32(0), 0
  for c in body
    v = get(LETTERS, c, nothing)
    v === nothing && return nothing
    held = (held << 6 | v) & 0x00ffffff
    bits += 6
    bits >= 8 && (bits -= 8; push!(out, UInt8((held >> bits) & 0xff)))
  end
  out
end

"True for a character that says what a terminal does and isn't text, like a new line or Escape"
control(c::Char) = c <= '\u1f' || '\u7f' <= c <= '\u9f'

"The text that base64 stands for, or nothing: it must be text, with no character that controls a terminal"
words(text::AbstractString) = begin
  bytes = unbase64(text)
  bytes === nothing && return nothing
  s = String(bytes)
  isvalid(s) && !any(control, s) ? s : nothing
end

"The number that `text` writes, or nothing: digits with no 0 first, and no more than `most`"
number(text, most=typemax(Int)) = begin
  (text === nothing || match(r"^[1-9][0-9]*\z", text) === nothing) && return nothing
  n = tryparse(Int, text)
  n === nothing || n > most ? nothing : n
end

"The value of the first of the `pairs` whose key is `key`, or nothing"
value(pairs, key) = begin
  for p in pairs
    startswith(p, key * "=") && return SubString(p, ncodeunits(key) + 2)
  end
  nothing
end

"""
The words of a command, from the value of `argv`, or nothing when it can't be
one. The first word is the program: a bare name, which the shell finds on its
path, or a whole path from `/`. A name can't start with `-`, which a shell
would read as an option.
"""
command(text::AbstractString) = begin
  isempty(text) && return nothing
  out = String[]
  for part in split(text, ',')
    word = words(part)
    word === nothing && return nothing
    push!(out, word)
  end
  first = out[1]
  (isempty(first) || (startswith(first, '/') ? false : occursin('/', first) || startswith(first, '-'))) && return nothing
  out
end

"""
Read the body of a report that a program wrote, with the `token` of the
terminal that got it. `now` is the time, and `heard` has the time of the last
report that was taken from each program. The answer is nothing for a report
to take no notice of, a `Rejected`, or a `Report`.
"""
read_report(body::AbstractString, token::AbstractString; now=time(), heard=Dict{Int,Int}()) = begin
  # The sum and the time are looked at before all else. A report that fails them changes nothing: its text may be cut
  # short, or come from something that only shows in the terminal.
  m = match(r"^(.*):mac=([0-9a-f]{64})\z"s, body)
  (m === nothing || isempty(token)) && return nothing
  said = m[1]
  sum256(said * ":" * token) == m[2] || return nothing
  pairs = split(said, ':')
  at = number(value(pairs, "time"))
  (at === nothing || abs(at - now) > NEAR) && return nothing
  pid = number(value(pairs, "pid"), MOST_PID)
  pid !== nothing && at < get(heard, pid, 0) && return nothing
  no = Rejected(pid)
  # From here the report is the program's own, so one that's wrong says that its command has changed
  has = Dict{String,String}()
  for p in pairs
    pair = match(r"^([a-z]+)=([A-Za-z0-9_.,+/=-]*)\z", p)
    (pair === nothing || pair[1] == "mac" || haskey(has, pair[1])) && return no
    has[pair[1]] = pair[2]
  end
  pid === nothing && return no
  number(has["time"]) == at || return no
  if haskey(has, "need")
    match(r"^[a-z]+(,[a-z]+)*\z", has["need"]) === nothing && return no
    all(in(KNOWN), split(has["need"], ',')) || return no
  end
  clear = haskey(has, "clear")
  (clear && has["clear"] != "1") && return no
  clear == haskey(has, "argv") && return no   # a report has one of the two
  argv = clear ? String[] : command(has["argv"])
  argv === nothing && return no
  cwd = ""
  if haskey(has, "cwd")
    dir = words(has["cwd"])
    (dir === nothing || !startswith(dir, '/')) && return no
    cwd = dir
  end
  Report(pid, at, argv, cwd, clear)
end

# --- the programs of this Mac ---------------------------------------------------------------

"A program that runs: its number, its parent's, the person who runs it, the terminal that controls it, and when it started"
struct Process
  pid::Int
  parent::Int
  user::UInt32
  tty::UInt32
  began::Int
end

const ABOUT_SIZE = 136     # bytes of what macOS says of a program: struct proc_bsdinfo
const PATHS_SIZE = 2352    # bytes of the folders of a program: struct proc_vnodepathinfo
const ZOMBIE = 5           # a program that ended and whose parent hasn't asked how

"The program with the number `pid`, or nothing when none runs with it"
process(pid::Integer) = begin
  (Sys.isapple() && 0 < pid <= MOST_PID) || return nothing
  buf = zeros(UInt8, ABOUT_SIZE)
  n = ccall(:proc_pidinfo, Cint, (Cint, Cint, UInt64, Ptr{UInt8}, Cint), pid, 3, 0, buf, ABOUT_SIZE)
  n == ABOUT_SIZE || return nothing
  at(T, offset) = reinterpret(T, buf[offset+1:offset+sizeof(T)])[1]
  at(UInt32, 4) == ZOMBIE && return nothing
  Process(Int(at(UInt32, 12)), Int(at(UInt32, 16)), at(UInt32, 20), at(UInt32, 108), Int(at(UInt64, 120)))
end

"The folder that the program `pid` is in, or nothing"
folder(pid::Integer) = begin
  (Sys.isapple() && 0 < pid <= MOST_PID) || return nothing
  buf = zeros(UInt8, PATHS_SIZE)
  n = ccall(:proc_pidinfo, Cint, (Cint, Cint, UInt64, Ptr{UInt8}, Cint), pid, 9, 0, buf, PATHS_SIZE)
  n == PATHS_SIZE || return nothing
  path = GC.@preserve buf unsafe_string(pointer(buf, 153))
  isvalid(path) && startswith(path, '/') && !any(control, path) ? path : nothing
end

"The programs that started `p`, from its parent up to `top`, the first program of the terminal"
above(p::Process, top::Integer) = begin
  out = Int[]
  at = p
  while at !== nothing && at.pid != top && at.parent > 1 && length(out) < 32
    push!(out, at.parent)
    at = process(at.parent)
  end
  out
end

# --- the records of a terminal --------------------------------------------------------------

"What a terminal keeps of a program: the command that starts it again"
mutable struct Record
  pid::Int
  began::Int            # when that program started, which tells it from a later one with the same number
  time::Int             # of the report
  argv::Vector{String}
  cwd::String           # the folder to run the command in, or ""
  named::Bool           # the program named that folder itself. Otherwise it's the folder that the program was in.
  above::Vector{Int}    # the programs that started it
  gone::Float64         # when the program was found to have ended, or 0 while it runs
end

"True while the program of the record runs"
runs(r::Record) = (p = process(r.pid); p !== nothing && p.began == r.began)

"Take the records of the program `pid` out of `records`: true when there was one"
drop!(records, pid) = (n = length(records); filter!(r -> r.pid != pid, records); length(records) < n)

"""
Do what the report `body` says to the `records` of a terminal: true when they
changed. `token` is the terminal's, `tty` is the number of its device, and
`top` is its first program, the shell. `heard` keeps the time of the last
report that was taken from each program.

A report is taken only for a program that runs, as the same person, in this
terminal. So a program can't speak for one in another terminal.
"""
hear!(records, heard, body, token; tty, top, now=time()) = begin
  r = read_report(body, token; now, heard)
  r === nothing && return false
  if r isa Report
    p = process(r.pid)
    if p !== nothing && p.user == me() && p.tty == tty
      heard[r.pid] = r.time
      changed = drop!(records, r.pid)
      r.clear && return changed
      named = !isempty(r.cwd)
      push!(records, Record(r.pid, p.began, r.time, r.argv, named ? r.cwd : something(folder(r.pid), ""), named, above(p, top), 0.0))
      return true
    end
  end
  r.pid === nothing ? false : drop!(records, r.pid)
end

"""
Look at whether the programs of the `records` still run: true when a record
went. A program that ended counts as running for a moment more. When the Mac
shuts down, a program can end just before the terminal does, and it must
start again all the same.
"""
ended!(records; now=time()) = begin
  for r in records
    r.gone == 0 && !runs(r) && (r.gone = now)
  end
  n = length(records)
  filter!(r -> r.gone == 0 || now - r.gone < GRACE, records)
  length(records) < n
end

"""
The record to start again, of those that a terminal kept. A program that
another of them started stands back for that one, since the first starts the
second when it wants it. Of the rest it's the one that spoke last.
"""
choose(records) = begin
  pids = Set(r.pid for r in records)
  first = filter(r -> !any(in(pids), r.above), records)
  isempty(first) ? nothing : argmax(r -> r.time, first)
end

# --- the files that keep them ---------------------------------------------------------------

"The folder of the records, which only the person can read. It's made when it isn't there."
store() = begin
  dir = place()
  isdir(dir) || mkpath(dir, mode=0o700)
  dir
end

"The file that keeps the records of the terminal whose own file is at `path`"
record_file(path) = joinpath(place(), sum256(abspath(path))[1:32])

base64(text) = begin
  letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
  bytes = codeunits(text)
  out = IOBuffer()
  for k in 1:3:length(bytes)
    n = min(3, length(bytes) - k + 1)
    held = UInt32(bytes[k]) << 16 | (n > 1 ? UInt32(bytes[k+1]) << 8 : UInt32(0)) | (n > 2 ? UInt32(bytes[k+2]) : UInt32(0))
    for j in 0:n
      write(out, letters[(held >> (18 - 6j)) & 0x3f + 1])
    end
  end
  String(take!(out))
end

"Write `text` to `file` so that nobody else can read it, and so that the file is never half written"
write_private(file, text) = begin
  tmp, io = mktemp(dirname(file))   # a file that only the person can read
  write(io, text)
  close(io)
  mv(tmp, file, force=true)
  nothing
end

"""
Write the `records` of the terminal whose file is at `path`, as they are now.
With none, their file goes. A folder that can't be written keeps nothing, and
then no program starts again.
"""
keep!(path, records) = begin
  isempty(path) && return nothing
  isempty(records) && return forget!(path)
  lines = ["path=$(base64(abspath(path)))", "user=$(me())"]
  for r in records
    push!(lines, "pid=$(r.pid) began=$(r.began) time=$(r.time) named=$(Int(r.named)) above=$(join(r.above, ',')) " *
                 "cwd=$(base64(r.cwd)) argv=$(join(map(base64, r.argv), ','))")
  end
  try
    store()
    write_private(record_file(path), join(lines, "\n") * "\n")
  catch
  end
  nothing
end

"Take away what's kept for the terminal whose file is at `path`"
forget!(path) = begin
  isempty(path) || (try rm(record_file(path), force=true) catch end)
  nothing
end

"A record from a line of a file of records, or nothing when the line isn't one"
record(line) = begin
  has = Dict{String,String}()
  for part in split(line, ' ')
    cut = findfirst('=', part)
    cut === nothing && return nothing
    has[part[1:cut-1]] = part[cut+1:end]
  end
  all(k -> haskey(has, k), ("pid", "began", "time", "named", "above", "cwd", "argv")) || return nothing
  pid, time = number(has["pid"], MOST_PID), number(has["time"])
  began = tryparse(Int, has["began"])
  argv, cwd = command(has["argv"]), words(has["cwd"])
  up = isempty(has["above"]) ? Int[] : map(x -> tryparse(Int, x), split(has["above"], ','))
  (pid === nothing || time === nothing || began === nothing || argv === nothing || cwd === nothing || any(isnothing, up)) && return nothing
  (isempty(cwd) || startswith(cwd, '/')) || return nothing
  Record(pid, began, time, argv, cwd, has["named"] == "1", Vector{Int}(up), 0.0)
end

"""
The records that are kept for the terminal whose file is at `path`. A file of
records that isn't the person's own, that others can read or write, or that
has a line that can't be a record is taken away, and gives none: nothing in
it can be trusted then.
"""
kept(path) = begin
  file = record_file(path)
  isfile(file) || return Record[]
  out = try
    s = stat(file)
    lines = split(read(file, String), '\n', keepempty=false)
    good = s.uid == me() && s.mode & 0o077 == 0 && length(lines) >= 2 &&
           lines[1] == "path=$(base64(abspath(path)))" && lines[2] == "user=$(me())"
    records = good ? map(record, lines[3:end]) : [nothing]
    any(isnothing, records) ? nothing : Vector{Record}(records)
  catch
    nothing
  end
  out === nothing && (forget!(path); return Record[])
  out
end

const tidied = Ref(false)

"""
Take away, once, the records of terminals whose files are gone, and the files
of commands that never ran. A terminal's file can go while the app is closed.
"""
tidy!() = begin
  tidied[] && return
  tidied[] = true
  dir = place()
  isdir(dir) || return
  for name in readdir(dir)
    file = joinpath(dir, name)
    try
      if endswith(name, ".run")
        time() - mtime(file) > OLD_RUN && rm(file, force=true)
      elseif name != "again" && isfile(file)
        m = match(r"^path=(\S*)", read(file, String))
        path = m === nothing ? nothing : words(m[1])
        (path === nothing || !isfile(path)) && rm(file, force=true)
      end
    catch
    end
  end
  nothing
end

"""
The record to start again in the terminal whose file is at `path`, or nothing.
A program that named its folder doesn't start again when that folder is gone:
its command was for that place.
"""
waiting(path) = try
  (isempty(path) || !supported()) && return nothing
  tidy!()
  records = kept(path)
  isempty(records) && return nothing
  r = choose(records)
  (r === nothing || (r.named && !isdir(r.cwd))) && (forget!(path); return nothing)
  r
catch
  nothing   # the folder of the records can't be read, as in a place that hides the person's files
end

# --- starting a program again ---------------------------------------------------------------

# The shell runs this file when the terminal types its name. A shell runs a command from text, and text that had a
# program's words in it could do anything: a word like $(reboot) would run. So the words go in a file, a line each,
# and this starts the program with each line as one word, just as it is. `exec` finds only programs, so a function or
# an alias of the shell with the same name doesn't take the program's place.
const AGAIN = """
#!/bin/sh
# Ladder types this file's name in a terminal, to start again the program that ran there when Ladder last closed.
# The program told Ladder its command: see https://www.superlogical.com/rex/docs/build/program-resume
# \$1 names a file beside this one. Its first line is a folder, and each line after is one word of the command.
# \$2 is how many lines of the screen the line that Ladder typed took.
file="\${0%/*}/\$1.run"
[ -f "\$file" ] || exit 0
case "\$2" in '' | *[!0-9]*) lines=1 ;; *) lines=\$2 ;; esac
printf '\\033[%sA\\r\\033[J' "\$lines"   # take what Ladder typed off the screen
set --
{
  IFS= read -r dir
  while IFS= read -r word; do set -- "\$@" "\$word"; done
} < "\$file"
rm -f "\$file"
[ \$# -gt 0 ] || exit 0
[ -z "\$dir" ] || cd "\$dir" || exit 1
exec "\$@"
"""

"A path as a shell reads it for one word: `~` for the home folder, and a `\\` before each character that a shell gives a meaning. Nothing for a path that can't be typed."
shell_word(path) = begin
  any(control, path) && return nothing
  home = homedir()
  start, rest = startswith(path, home * "/") ? ("~", path[ncodeunits(home)+1:end]) : ("", path)
  start * join(isascii(c) && !(isletter(c) || isdigit(c) || c in "/._-+,:@%") ? "\\$c" : string(c) for c in rest)
end

"""
Make ready to start the program of a record again, and give the words to type
at the shell's first prompt, which start it: `typed` makes the line of them.
The command's words are in a file that the shell's side reads once and takes
away. The answer is "" when the files can't be written.
"""
prepare(r::Record) = try
  dir = store()
  helper = joinpath(dir, "again")
  (isfile(helper) && read(helper, String) == AGAIN) || write_private(helper, AGAIN)
  chmod(helper, 0o700)
  name = bytes2hex(unguessed(4))
  write_private(joinpath(dir, name * ".run"), join((isdir(r.cwd) ? r.cwd : "", r.argv...), "\n") * "\n")
  word = shell_word(helper)
  # The space before it keeps the line out of the history of a shell that's set to leave such lines out
  word === nothing ? "" : " $word $name"
catch
  ""
end

# zsh keeps each line that's typed in its history, so the line that the terminal types would be there at every start,
# and the ↑ key would bring it back. zsh has no setting for this that the terminal can give it from outside, so for
# this one start zsh reads the file below before its own settings. Other shells need nothing: fish leaves out a line
# that starts with a space, and so does a bash that's set to.
const ZSHENV = raw"""
# Ladder starts zsh with this file's folder as ZDOTDIR when it starts a program again in a terminal, so that zsh
# reads this file first. It gives zsh its own folder of settings back, reads your own .zshenv, and keeps one line
# out of the history: the line that Ladder types to start the program.
if [[ -n ${LADDER_ZDOTDIR+x} ]]; then
  export ZDOTDIR=$LADDER_ZDOTDIR
else
  unset ZDOTDIR
fi
unset LADDER_ZDOTDIR
if [[ -o interactive && -n $LADDER_AGAIN ]]; then
  _ladder_again=$LADDER_AGAIN
  _ladder_again_history() {
    [[ $1 == "$_ladder_again"* ]] || return 0
    zshaddhistory_functions=(${zshaddhistory_functions:#_ladder_again_history})
    unset _ladder_again
    return 1
  }
  zshaddhistory_functions+=(_ladder_again_history)
fi
unset LADDER_AGAIN
[[ -r ${ZDOTDIR:-$HOME}/.zshenv ]] && source "${ZDOTDIR:-$HOME}/.zshenv"
"""

"""
What to add to the environment of the shell `program` so that the words that
`prepare` gave stay out of its history when they're typed. It's nothing for a
shell that isn't zsh.
"""
quiet(program, words) = begin
  (basename(program) == "zsh" && !isempty(words)) || return Pair{String,String}[]
  try
    dir = joinpath(store(), "zsh")
    isdir(dir) || mkpath(dir, mode=0o700)
    file = joinpath(dir, ".zshenv")
    (isfile(file) && read(file, String) == ZSHENV) || write_private(file, ZSHENV)
    names = ["ZDOTDIR" => dir, "LADDER_AGAIN" => words]
    haskey(ENV, "ZDOTDIR") && push!(names, "LADDER_ZDOTDIR" => ENV["ZDOTDIR"])
    names
  catch
    Pair{String,String}[]
  end
end

"""
The line to type for the words that `prepare` gave, at a prompt that ends in
cell `col` of a screen of `cols` cells. The line's end says how many lines of
the screen it takes, so that all of it can be taken off the screen again,
even when it's too long for one line.
"""
typed(words, col, cols) = begin
  lines = clamp(cld(max(col, 1) - 1 + length(words) + 2, max(cols, 1)), 1, 9)
  "$words $lines\r"
end
