# The view of a `load` block: rows loaded from a server or a file
#
# A code block in the language `load` shows the rows of a file or of a server
# as a table. It's a filter, so it reads the same lines, and its headings
# have the same menus. It shows no field for conditions until it has some.
#
#     ```load
#     from: https://example.com/api/orders
#     key: orders-api
#     at: data.orders
#     ```
#
# `from` is a CSV, TSV or JSON file, as a filter's is, or a web address. A
# file loads again by itself when it changes. A server is asked for its rows
# when the page opens, and again when you click Refresh. When the address
# changes, it's asked once the address has stayed the same for a second.
#
# `key` names a password in the Keychain, as a save block's does. `as` says
# what kind of file the server sends: csv, tsv or json. Without it, the server
# says, or else its first character does: { or [ is JSON.
#
# Ladder keeps a copy of the last rows that each address gave, in the Mac's
# caches. The block shows the copy while it waits, and when the server can't
# be reached. The line under the top of the block says when the rows came,
# or why they didn't.

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" WrapMode
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./markdown" words
@use "./filter" => Filters
@use "./save" => Saves
@use "./eml" => Eml
@use "./base" exports...
@use "./json_view" exports...
@use "./schedule_view" exports...

export LOAD_CACHE, LOAD_WAIT, load_dir, load_stem, load_copy, isload_copy, load_url, load_key,
       load_problem, LOAD_SCRIPT, get_rows, LOAD_GETTER, load_online, load_rows!, when_words,
       kept_words, load_ext, sentence, loaded!, load_tick!, load_note, load_line, ask_load_key!,
       picks_file, load_start, load_picker, picker_words, picker_section, toggle_picker!,
       pick_tick!, LoadBlock, error_words, file_start

push!(BLOCK_ICONS, "cloud-arrow-down", "file-earmark-arrow-down", "arrow-clockwise")

const LOAD_CACHE = Ref("")   # the folder a test keeps the copies in, in place of the one in the Mac's caches
const LOAD_WAIT = 1.0        # seconds that a new address has to stay the same before the server is asked

"The folder that keeps a copy of the rows that each address last gave"
load_dir() = isempty(LOAD_CACHE[]) ? joinpath(homedir(), "Library", "Caches", "Ladder", "loads") : LOAD_CACHE[]

"The start of the path of the copy of what `url` gave. One address always has the same one."
load_stem(url) = joinpath(load_dir(), string(hash(String(strip(url))), base=16))

"The copy of the rows that `url` last gave, or \"\" when there's none. It's a JSON, CSV or TSV file, as the server sent it."
load_copy(url) = begin
  stem = load_stem(url)
  copies = [stem * ext for ext in (".json", ".csv", ".tsv") if isfile(stem * ext)]
  isempty(copies) ? "" : copies[argmax(mtime.(copies))]
end

"True when `path` is a copy of what a server gave, and not a file of yours"
isload_copy(path) = !isempty(path) && startswith(path, load_dir() * "/")

"The web address that the load block `v` asks, or \"\" when it reads a file or a table"
load_url(v::FilterView) = v.lang == LOAD && Saves.isurl(v.spec.from) ? String(strip(v.spec.from)) : ""

"The name of the Keychain's key that the load block `v` sends, or \"\""
load_key(v::FilterView) = String(strip(Saves.query(v.lines).key))

"Why the load block `v` can't ask its server, or \"\""
load_problem(v::FilterView) = begin
  url, key = load_url(v), load_key(v)
  !isempty(key) && !startswith(lowercase(url), "https://") && !Saves.islocal(url) &&
    return "Ladder sends a key only to an address that starts with https://, so that no one on the way can read it."
  as = lowercase(strip(Saves.query(v.lines).as))
  isempty(as) || as in ("csv", "tsv", "json") || return "Ladder reads rows as csv, tsv or json, so “as: $(as)” has to be one of those."
  ""
end

# What a load runs: it reads the key from the Keychain, and gives it to curl on curl's input, so the key is never
# in a command's words. It ends with 90 when the Keychain has no such key. curl writes the server's answer and
# what kind of file it sent.
const LOAD_SCRIPT = raw"""
key=""
if [ -n "$1" ]; then key=$(security find-generic-password -s "$1" -w 2>/dev/null) || exit 90; fi
{ if [ -n "$key" ]; then printf 'Authorization: Bearer %s\n' "$key"; fi; } |
  curl --silent --show-error --location --max-redirs 5 --compressed --connect-timeout 15 --max-time 120 --max-filesize 104857600 --proto =http,https --proto-redir =http,https -H "Accept: application/json, text/csv;q=0.9, */*;q=0.5" -H @- --output "$2" --write-out '%{http_code} %{content_type}' -- "$3"
"""

"""
Ask the server at `url` for its rows, and write what it sends to the file
`out`. With `key`, the Keychain's password of that name goes with the asking,
as `Authorization: Bearer`. It runs in a process of its own, and gives a
function that's nothing until that has ended. Then it gives what happened:
`nokey` is true when the Keychain had no such key, `code` is the server's
answer, or 0 when it couldn't be reached, `type` is what the server said the
file is, `body` is `out`, and `error` is why it couldn't be reached.
"""
get_rows(url, key, out) = begin
  answer, err = tempname(), tempname()
  job = run(pipeline(`sh -c $LOAD_SCRIPT sh $key $out $url`, stdout=answer, stderr=err), wait=false)
  () -> process_exited(job) ? begin
    words = split(strip(file_start(answer)), ' ', limit=2)
    heard = (nokey=job.exitcode == 90, code=something(tryparse(Int, isempty(words) ? "" : words[1]), 0),
             type=length(words) > 1 ? String(words[2]) : "", body=out, error=file_start(err))
    rm.((answer, err), force=true)
    heard
  end : nothing
end

"What asks a server for a load block's rows. A test puts its own function here, so that it uses no network and no Keychain."
const LOAD_GETTER = Ref{Function}(get_rows)

"True when the load block `v` may ask the web: its window is on the screen, or a test stands in for curl"
load_online(v::FilterView) = (e = editor(v); !Eml.isemail(e.buf.path) && (LOAD_GETTER[] !== get_rows || on_screen(e)))

"Ask the server of the load block `v` for its rows. The window goes on while they come."
load_rows!(v::FilterView) = begin
  url = load_url(v)
  (v.job === nothing && !isempty(url) && isempty(load_problem(v))) || return v
  key = load_key(v)
  v.asked = (url, key)
  v.said, v.failed, v.nokey = "Loading the rows from $(Saves.host(url))…", false, false
  v.job = LOAD_GETTER[](url, key, tempname())
  v
end

"A time, as the block says it: 10:41, or 10:41 on 20 Nov when it isn't today"
when_words(t) = Libc.strftime(Libc.strftime("%F", t) == Libc.strftime("%F", time()) ? "%H:%M" : "%H:%M on %-d %b", t)

"What the block says about the copy of what `url` gave, after a load that failed: when those rows came"
kept_words(url) = (c = load_copy(url); isempty(c) ? "" : " These are the rows that came at $(when_words(mtime(c))).")

"The kind of file that a server sent: what the `as` line says, or what the server says, or what its first character looks like"
load_ext(v::FilterView, type, body) = begin
  as = lowercase(strip(Saves.query(v.lines).as))
  isempty(as) || return "." * as
  t = lowercase(type)
  occursin("json", t) && return ".json"
  occursin("tab-separated", t) && return ".tsv"
  occursin("csv", t) && return ".csv"
  start = lstrip(file_start(body, 64))
  startswith(start, '{') || startswith(start, '[') ? ".json" : ".csv"
end

"`words` with a full stop at the end, unless they end with one already, or with ! or ?"
sentence(words) = occursin(r"[.!?…]$", words) ? words : words * "."

"Note what came of the load of `v`. Rows that came take the place of the copy that the block shows."
loaded!(v::FilterView, heard) = begin
  url, key = v.asked
  server = Saves.host(url)
  if heard.nokey
    v.said, v.failed, v.nokey = "Your Keychain has no key called “$(key)”. Add it, and Ladder loads the rows.", true, true
  elseif heard.code == 0
    words = Saves.curl_words(heard.error)
    v.said, v.failed = sentence("Ladder couldn't reach $server$(isempty(words) ? "" : ": " * words)") * kept_words(url), true
  elseif 200 <= heard.code < 300
    ext = load_ext(v, heard.type, heard.body)
    stem = load_stem(url)
    v.said, v.failed = try
      mkpath(load_dir())
      for x in (".json", ".csv", ".tsv")
        x == ext || rm(stem * x, force=true)
      end
      mv(heard.body, stem * ext, force=true)
      # Read it now, so that the block and what uses its rows show them in this frame
      filter_file(stem * ext, v.spec.at; name=server)
      ("Loaded from $server at $(when_words(time())).", false)
    catch err
      ("Ladder couldn't keep the rows from $(server): $(error_words(err)).", true)
    end
  else
    words = server_said(file_start(heard.body))
    v.said, v.failed = sentence("The server at $server said $(Saves.answer(heard.code))$(isempty(words) ? "" : ": " * words)") * kept_words(url), true
  end
  rm(heard.body, force=true)
  v
end

"""
What a load block does in each frame. It looks at the copy of its rows, so a
new copy shows. When rows that it asked for have come, it keeps them. When it
hasn't asked its server since the page opened, it asks. When its address or
its key has changed, it asks once they have stayed the same for LOAD_WAIT.
"""
load_tick!(v::FilterView) = begin
  url = load_url(v)
  isempty(url) && return v
  copy = load_copy(url)
  isempty(copy) || filter_file(copy, v.spec.at; name=Saves.host(url))
  if v.job !== nothing
    heard = v.job()
    heard === nothing || (v.job = nothing; loaded!(v, heard))
    return v
  end
  v.asked == (url, load_key(v)) && return v
  v.asked !== nothing && time() - v.changed < LOAD_WAIT && return v
  load_online(v) && load_rows!(v)
  v
end

"The words of the line under the top of a load block from a server, or \"\""
load_note(v::FilterView) = begin
  url = load_url(v)
  isempty(url) && return ""
  p = load_problem(v)
  isempty(p) || return p
  isempty(v.said) || return v.said
  copy = load_copy(url)
  isempty(copy) ? "" : "Loaded from $(Saves.host(url)) at $(when_words(mtime(copy)))."
end

"The line under the top of a load block: when its rows came, or why they didn't, and a button that asks for a missing key"
load_line(v::FilterView) = begin
  words = load_note(v)
  isempty(words) && return ()
  bad = v.failed || !isempty(load_problem(v))
  icon = bad ? "exclamation-circle" : v.job === nothing ? "check2" : ""
  colour = bad ? colours.accent : colours.dim
  (Row(width(grow=grow), padding(9px, 12px, 9px, 12px), Alignment.Center, child_gap=6px, clip=true, name="Said",
     (isempty(icon) ? () : (Icon(icon, size=13px, color=colour),))...,
     Box(width(grow=grow), Text(words, size=12px, family=SANS, color=colour, wrap=WrapMode.words)),
     (v.nokey && Sys.isapple() ? (block_button!(v, :key, :key, icon="key", words="Add Key…", tip="Type the key, and Ladder keeps it in your Keychain"),) : ())...),)
end

"Ask for the key that the load block `v` names, and keep it in the Keychain"
ask_load_key!(v::FilterView, w) = begin
  name = load_key(v)
  (Sys.isapple() && !isempty(w.glfw) && !isempty(name)) || return v
  key = key_panel(name)
  # The panel took the keyboard, so the window never heard the keys that opened it come up
  w.keys = Keys(0)
  key === nothing || isempty(key) || key_given!(v, key)
  v
end

"Keep `key` as the key that the load block `v` names, and ask its server again"
key_given!(v::FilterView, key) = begin
  name = load_key(v)
  kept = KEY_KEEPER[](name, key)
  v.said, v.failed, v.nokey = kept ? "Ladder put the key “$(name)” in your Keychain." : "Ladder couldn't put the key “$(name)” in your Keychain.", !kept, !kept
  kept && load_rows!(v)
  v
end

# A load block with no `from` shows a breadcrumb of the page's folder, open, as
# a file in a live block does. Its list has folders, and CSV, TSV and JSON
# files. A click on a folder goes into it, and a click on a file makes that
# file the block's `from`. The Choose button at the top of a load block opens
# the picker again, in the folder of the block's file.

"True when the filter or the load block `v` shows its file picker: Choose a file… was clicked, or it's a load block with no `from` yet"
picks_file(v::FilterView) = v.choosing || v.lang == LOAD && isempty(strip(v.spec.from))

"The folder that the picker of the load block `v` starts in: the folder of its file, or the page's folder"
load_start(v::FilterView) = begin
  e = editor(v)
  from = String(strip(v.spec.from))
  path = isempty(from) || Saves.isurl(from) ? "" : abspath(docdir(e), expanduser(from))
  isfile(path) ? dirname(path) : isdir(docdir(e)) ? docdir(e) : homedir()
end

"The breadcrumb that picks the file of the load block `v`"
load_picker(v::FilterView) = block_part!(() -> Breadcrumb(at=load_start(v), open=true, files=isfilterable), v, :picker)

"What the line over the picker of the load block `v` says"
picker_words(v::FilterView) = begin
  from = String(strip(v.spec.from))
  isempty(from) ? "Choose a CSV, TSV or JSON file, or write a web address in a line like “from: https://example.com/orders”." :
                  "Choose a CSV, TSV or JSON file to $(v.lang == LOAD ? "load" : "filter") in place of $(Saves.isurl(from) ? Saves.host(from) : basename(from))."
end

"What a load block shows while it picks a file: a line that says what to do, and the breadcrumb"
picker_section(v::FilterView) = begin
  p = load_picker(v)
  p.room = editor(v).width - 24px
  words = Box(width(grow=grow), Text(picker_words(v), size=12px, family=SANS, color=colours.dim, wrap=WrapMode.words))
  # A block that has a `from` can close the list and keep it
  top = isempty(strip(v.spec.from)) ? words :
        Row(width(grow=grow), Alignment.Center, child_gap=8px, words,
            block_button!(v, :close_picker, :close_picker, icon="x-lg", words="Close", tip="Close the list of files"))
  (Column(width(grow=grow), Alignment.Start, padding(10px, 12px, 10px, 12px), child_gap=8px, name="Picker", top, p),)
end

"Open the picker of the load block `v`, in the folder of its file, or close it"
toggle_picker!(v::FilterView) = begin
  v.choosing = !v.choosing
  v.choosing || return v
  p = load_picker(v)
  p.at, p.open = load_start(v), true
  v
end

"""
What a load block's picker does in each frame: when a file has been clicked in
its list, that file becomes the block's `from`, and the picker closes. The
path goes in as the page's links have it: from the page's folder when the
file is in it.
"""
pick_tick!(v::FilterView) = begin
  picks_file(v) || return v
  p = load_picker(v)
  isfile(p.at) && isfilterable(p.at) || return v
  path = p.at
  # The next time the picker opens, it starts in a folder, not on this file
  p.at = dirname(path)
  v.choosing = false
  f = Filters.query(v.lines)
  f.from = tilde(named(editor(v), path))
  lowercase(splitext(path)[2]) in JSONS || (f.at = "")
  filter_write!(v, f)
  v
end

struct LoadBlock end
BLOCKS[LOAD] = LoadBlock
block_name(::Type{LoadBlock}) = "Load"
block_icon(::Type{LoadBlock}) = "cloud-arrow-down"
block_make(::Type{LoadBlock}, n::Int) = FilterView(n=n, lang=LOAD)
block_insert(::Type{LoadBlock}) = ("Load", ["```$LOAD", "```", "", ""], (4, 0))
block_table_kind(::Type{LoadBlock}) = "load block"
block_tables!(::Type{LoadBlock}, e, i::Int, t::Int, under::AbstractString, out) =
  block_tables!(FilterView, e, i, t, under, out; load=true)

"What went wrong, in words, for an error that Julia gives"
error_words(err) = err isa SystemError ? Libc.strerror(err.errnum) : String(strip(first(split(sprint(showerror, err), '\n'))))

"The first `most` bytes of the file at `path`, as text, or \"\" when it isn't there"
file_start(path, most=20_000) = isfile(path) ? String(open(io -> read(io, most), path)) : ""
