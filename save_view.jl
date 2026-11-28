# The view of a `save` block: the rows of the table above it, written to a file or sent to a server
#
# A code block in the language `save` writes the rows of the table above it
# into a file, or sends them to a server. save.jl says how the block is
# written. The top of the block says which rows it has and where they go, and
# its button does it: Save or Replace for a file, Send for a server. Nothing
# is written or sent until you click.
#
# The line under the top says what a click will do, and then what happened:
# when the rows went, and what the server said. A send runs in a process of its
# own, so the window never waits for the server. When the Keychain has no key
# with the name that the block gives, a button on that line asks for the key
# and keeps it in the Keychain.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor redraw_in! popup! close_popup!
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring jstring with_pool
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" problem
@use "./html" escape
@use "./markdown" Kind words
@use "./csv" => Csvs
@use "./save" => Saves
@use "github.com/jkroso/JSON.jl" JSONObject JSONNumber json_value write_json
@use Colors: @colorant_str, RGBA
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./load_view" exports...
@use "./rows_from" exports...
@use "./filter_view" exports...
@use "./media_view" table_file

export SAVE_SENDER, SEND_SCRIPT, asks_where, heard!, json_cell_of, same_file, save_chosen,
       save_data, save_folder, save_here!, save_html, save_name_field, save_picker,
       save_picker_section, save_plan, save_problem, save_start, save_target, save_text, send_rows,
       send_save!, toggle_save_picker!, write_rows!

push!(BLOCK_ICONS, "save", "cloud-arrow-up", "arrow-right", "key", "check2", "exclamation-circle")

reread!(v::SaveView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.spec = Saves.query(lines)
  # What happened at the last click was about the block as it was
  v.job === nothing && (v.said = ""; v.failed = false; v.nokey = false)
  v
end

"""
The rows that the save block `v` writes, as a FilterRows: those of the table
that's nearest above it, or of the first one under the heading that `from`
names. A filter's rows are those that it shows. When they came from a JSON
file and the filter hides no column, `things` holds the thing that each one
came from, so a JSON file or a server gets each thing whole.
"""
save_data(v::SaveView) = begin
  e = editor(v)
  tables = page_tables(e)
  from = String(strip(v.spec.from))
  # `from` can name a file of rows
  isfilterable(from) && return filter_file(abspath(docdir(e), expanduser(from)), "")
  k = isempty(from) ? something(findlast(t -> t.last < v.first, tables), 0) : something(named_table(e, tables, from), 0)
  k == 0 && return no_rows(isempty(from) ?
    "Put a table, a filter or a CSV file's table over this block, and the block saves its rows." :
    "This page has no table called “$(from)”, and no file of that name beside it.")
  t = tables[k]
  name = isempty(t.under) ? "the table above" : t.under
  top = kinds(e.buf)[t.first]
  if top.kind == Kind.fence && top.lang in (FILTER, LOAD)
    x = filter_subset(e, e.buf.lines[t.first+1:t.last-1], tables, t.first; load=top.lang == LOAD)
    d, s = x.data, x.subset
    s === nothing && return no_rows(d.problem)
    whole = !isempty(d.things) && s.columns == collect(1:length(d.rows[1]))
    return FilterRows(filter_table(d, s), [get(d.numbers, c, false) for c in s.columns],
                      whole ? Any[d.things[r-1] for r in s.rows] : Any[], isempty(d.path) ? name : d.name, d.path, d.more, "")
  end
  # A line that shows a CSV file: the rows come from that file
  file = t.first == t.last ? table_file(docdir(e), e.buf.lines[t.first]) : nothing
  rows = t.headed ? t.rows : [[["Name", "Value"]]; t.rows]   # a sheet's rows have no names
  wide = maximum(length, rows)
  rows = [[r; fill("", wide - length(r))] for r in rows]
  file === nothing ? FilterRows(rows, Csvs.numbers(rows), Any[], name, "", false, "") :
                     FilterRows(rows, Csvs.numbers(rows), Any[], basename(file[1]), file[1], false, "")
end

"The file that the save block `v` writes, as a whole path, or \"\" when it sends to a server or has no `to`"
save_target(v::SaveView) = (to = String(strip(v.spec.to)); isempty(to) || Saves.isurl(to) ? "" : abspath(docdir(editor(v)), expanduser(to)))

"True when `a` and `b` are one file"
same_file(a, b) = !isempty(a) && !isempty(b) && (a == b || (ispath(a) && ispath(b) && samefile(a, b)))

"Why the save block `v` can't write `d`, its rows, now, or \"\". `path` is the file that it would write."
save_problem(v::SaveView, d; path=save_target(v)) = begin
  isempty(d.problem) || return d.problem
  length(d.rows) < 2 && return "The table above has no rows to save."
  p = Saves.problem(v.spec)
  isempty(p) || return p
  isempty(path) && return ""
  name = basename(path)
  isdir(path) && return "$name is a folder. Name a file in it, like “$name/rows.csv”."
  isdir(dirname(path)) || return "There's no folder called $(basename(dirname(path))) for $name to go in."
  same_file(path, editor(v).buf.path) && return "$name is this page. Name another file."
  same_file(path, d.path) && return "The rows come from $name, so Ladder won't write over it. Name another file."
  isfile(path) && !(lowercase(splitext(path)[2]) in (".csv", ".tsv", ".tab", ".json", ".txt")) &&
    return "Ladder replaces only a CSV, TSV, JSON or text file, and $name is another kind. Name a new file, or one of those."
  ""
end

"A cell of a column of numbers that JSON can hold as a number, like 12 or -3.5, is a number. Any other cell is text."
json_cell_of(cell, number) = number && occursin(Saves.PLAIN_NUMBER, cell) ? JSONNumber(cell) : cell

"""
The text of `d`, the rows of a save block, as CSV, TSV or JSON. JSON is a list
with an object for each row, whose keys are the names of the columns, or the
things that the rows came from when `d` has them.
"""
save_text(d::FilterRows, format) = begin
  format == "json" || return Saves.delimited(d.rows, format == "tsv" ? '\t' : ',')
  isempty(d.things) || return sprint(write_json, d.things, 0) * "\n"
  names = [isempty(name) ? "column $c" : name for (c, name) in enumerate(d.rows[1])]
  things = Any[JSONObject(copy(names), Any[json_cell_of(cell, get(d.numbers, c, false)) for (c, cell) in enumerate(row)]) for row in d.rows[2:end]]
  sprint(write_json, things, 0) * "\n"
end

"What the button of `v` will do, before it's clicked. `to` is where the rows would go."
save_plan(v::SaveView, d; to=String(strip(v.spec.to))) = begin
  rows = "the " * Saves.rows_words(length(d.rows) - 1)
  as = uppercase(Saves.format(Saves.Save(to=to, as=v.spec.as)))
  more = d.more ? " $(d.name) has more rows than Ladder reads, so only these go." : ""
  words = if isempty(to)
    "A click asks where to save $rows, as a file."
  elseif Saves.isurl(to)
    key = String(strip(v.spec.key))
    "A click sends $rows to $to as $as, with $(Saves.method(v.spec))$(isempty(key) ? "" : ", and the key “$(key)” from your Keychain")."
  elseif isfile(abspath(docdir(editor(v)), expanduser(to)))
    "A click replaces $(basename(to)) with $rows, as $as."
  else
    "A click writes $rows into a new file, $(basename(to)), as $as."
  end
  words * more
end

"The name that the Save panel starts with, when the block has no `to` yet"
save_start(d::FilterRows) = begin
  ext = isempty(d.things) ? ".csv" : ".json"
  isempty(d.path) || isload_copy(d.path) || return splitext(basename(d.path))[1] * " (saved)" * ext
  (startswith(d.name, "the table") ? "Rows" : d.name) * ext
end

"What went wrong, in words, for an error that Julia gives"
error_words(err) = err isa SystemError ? Libc.strerror(err.errnum) : String(strip(first(split(sprint(showerror, err), '\n'))))

"Write `d`, the rows of `v`, into the file that `v` names. It's written beside it first, so the file is never half there."
write_rows!(v::SaveView, d) = begin
  path = save_target(v)
  part = path * ".part"
  try
    write(part, save_text(d, Saves.format(v.spec)))
    mv(part, path, force=true)
    v.said, v.failed = "Saved $(Saves.rows_words(length(d.rows) - 1)) to $(basename(path)) at $(Libc.strftime("%H:%M", time())).", false
  catch err
    rm(part, force=true)
    v.said, v.failed = "Ladder couldn't write $(basename(path)): $(error_words(err)).", true
  end
  v
end

# What a send runs: it reads the key from the Keychain, and gives it to curl on curl's input, so the key is never
# in a command's words, where any program could see it. It ends with 90 when the Keychain has no such key.
const SEND_SCRIPT = raw"""
key=""
if [ -n "$1" ]; then key=$(security find-generic-password -s "$1" -w 2>/dev/null) || exit 90; fi
{ if [ -n "$key" ]; then printf 'Authorization: Bearer %s\n' "$key"; fi; } |
  curl --silent --show-error --connect-timeout 15 --max-time 120 --proto =http,https -X "$2" -H "Content-Type: $3" -H "Expect:" -H @- --data-binary @"$4" --output "$5" --write-out '%{http_code}' -- "$6"
"""

"The first `most` bytes of the file at `path`, as text, or \"\" when it isn't there"
file_start(path, most=20_000) = isfile(path) ? String(open(io -> read(io, most), path)) : ""

"""
Send the file `body` to the web address `url`, asking with `method`, and tell
the server that it's `type`. With `key`, the Keychain's password of that name
goes with it, as `Authorization: Bearer`. It runs in a process of its own,
and gives a function that's nothing until that has ended. Then it gives what
happened: `nokey` is true when the Keychain had no such key, `code` is the
server's answer, or 0 when it couldn't be reached, `body` is what the server
said, and `error` is why it couldn't be reached. The file `body` goes then.
"""
send_rows(url, method, type, body, key) = begin
  out, code, err = tempname(), tempname(), tempname()
  job = run(pipeline(`sh -c $SEND_SCRIPT sh $key $method $type $body $out $url`, stdout=code, stderr=err), wait=false)
  () -> process_exited(job) ? begin
    heard = (nokey=job.exitcode == 90, code=something(tryparse(Int, strip(file_start(code))), 0), body=file_start(out), error=file_start(err))
    rm.((out, code, err, body), force=true)
    heard
  end : nothing
end

"What sends a save block's rows to a server. A test puts its own function here, so that it uses no network and no Keychain."
const SAVE_SENDER = Ref{Function}(send_rows)

"Send `d`, the rows of `v`, to the server that `v` names. The window goes on while they go."
send_save!(v::SaveView, d) = begin
  as = Saves.format(v.spec)
  body = tempname()
  write(body, save_text(d, as))
  to, key = String(strip(v.spec.to)), String(strip(v.spec.key))
  v.sending = (n=length(d.rows) - 1, to=to, key=key)
  v.said, v.failed, v.nokey = "Sending $(Saves.rows_words(v.sending.n)) to $(Saves.host(to))…", false, false
  v.job = SAVE_SENDER[](to, Saves.method(v.spec), Saves.content_type(as), body, key)
  v
end

"What a server said with an answer that says no: its message when it sent JSON with one, or else the first line of its text"
server_said(body) = begin
  x = try json_value(Vector{UInt8}(body)) catch; nothing end
  if x isa JSONObject
    for name in ("message", "error_description", "error", "detail", "title")
      k = findfirst(==(name), x.keys)
      k === nothing && continue
      y = x.values[k]
      y isa AbstractString && return Saves.said(y)
      if y isa JSONObject
        j = findfirst(==("message"), y.keys)
        j !== nothing && y.values[j] isa AbstractString && return Saves.said(y.values[j])
      end
    end
  end
  Saves.said(body)
end

"Note what happened to the send of `v`: `heard` is what the function that SAVE_SENDER gave says when the send has ended"
heard!(v::SaveView, heard) = begin
  n, to, key = v.sending
  server = Saves.host(to)
  if heard.nokey
    v.said, v.failed, v.nokey = "Your Keychain has no key called “$(key)”. Add it, and click Send again.", true, true
  elseif heard.code == 0
    words = Saves.curl_words(heard.error)
    v.said, v.failed = "Ladder couldn't reach $server$(isempty(words) ? "." : ": " * words)", true
  elseif 200 <= heard.code < 300
    v.said, v.failed = "Sent $(Saves.rows_words(n)) to $server at $(Libc.strftime("%H:%M", time())). The server said $(Saves.answer(heard.code)).", false
  else
    words = server_said(heard.body)
    v.said, v.failed = "The server at $server said $(Saves.answer(heard.code))$(isempty(words) ? "." : ": " * words)", true
  end
  v
end

"In each frame while rows are on their way, a save block looks to see if they have gone"
block_tick!(v::SaveView) = begin
  sources_tick!(v)
  from_pick_tick!(v)
  v.job === nothing && return v
  heard = v.job()
  heard === nothing && return v
  v.job = nothing
  heard!(v, heard)
end

"""
Keep `key` in the login Keychain as the password called `name`, in place of
one that's there. It goes to `security` on its input, as hex, so it's never
in a command's words. True when the Keychain has it after that.
"""
keep_key(name, key) = begin
  any(c -> c in "\"\\\n", name) && return false
  try
    open(pipeline(`security -i`, stdout=devnull, stderr=devnull), "w") do io
      write(io, "add-generic-password -U -a ladder -s \"$name\" -l \"$name\" -X $(bytes2hex(codeunits(key)))\n")
    end
  catch
    return false
  end
  success(pipeline(`security find-generic-password -s $name`, stdout=devnull, stderr=devnull))
end

"Ask for the key called `name`, in a panel that hides what you type. It gives the key, or nothing if you cancel."
key_panel(name) = with_pool() do
  alert = msg(msg(cls("NSAlert"), "alloc"), "init")
  msg(alert, "setMessageText:", nsstring("The key for $name"))
  msg(alert, "setInformativeText:", nsstring("Ladder keeps it in your Keychain, as the password called “$(name)”. The page holds only the name."))
  msg(alert, "addButtonWithTitle:", nsstring("Keep"))
  msg(alert, "addButtonWithTitle:", nsstring("Cancel"))
  field = ccall((:objc_msgSend, libobjc), Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, NTuple{4,Float64}),
                msg(cls("NSSecureTextField"), "alloc"), sel("initWithFrame:"), (0.0, 0.0, 280.0, 24.0))
  msg(alert, "setAccessoryView:", field)
  msg(msg(alert, "window"), "setInitialFirstResponder:", field)
  # 1000 is the first button, Keep
  kept = ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), alert, sel("runModal")) == 1000
  key = kept ? jstring(msg(field, "stringValue")) : nothing
  msg(field, "release")
  msg(alert, "release")
  key
end

"Keep `key` as the key that `v` names, and say how that went"
key_given!(v::SaveView, key) = begin
  name = String(strip(v.spec.key))
  kept = KEY_KEEPER[](name, key)
  v.said, v.failed, v.nokey = kept ? "Ladder put the key “$(name)” in your Keychain. Click Send to send the rows." :
                                     "Ladder couldn't put the key “$(name)” in your Keychain.", !kept, !kept
  v
end

# A save block with no `to` lists the folders beside the page, as a breadcrumb
# that's open, with a field for the name of the file under it. A click on a
# folder goes into it, and a click on a name of the path goes back up. Its
# button saves the rows in that folder, with that name, and makes that file
# the block's `to`. A save block that has a `to` has a Choose button, which
# opens the list in the folder of its file. When a file of that name is there,
# the button says Replace.

"True when the save block `v` shows where to save: it has no `to` yet, or Choose was clicked"
asks_where(v::SaveView) = v.choosing || isempty(strip(v.spec.to))

"The folder that the save block `v` lists first: the folder of its file, or the page's folder"
save_folder(v::SaveView) = begin
  path, dir = save_target(v), docdir(editor(v))
  !isempty(path) && isdir(dirname(path)) ? dirname(path) : isdir(dir) ? dir : homedir()
end

"The breadcrumb that picks the folder of the save block `v`. It lists only folders."
save_picker(v::SaveView) = block_part!(() -> Breadcrumb(at=save_folder(v), open=true, folders=true), v, :picker)

"The field for the name of the file that the save block `v` makes"
save_name_field(v::SaveView) = block_part!(v, :name) do
  TextInput(text=save_start(save_data(v)), placeholder="The name of the file", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"""
The file that the save block `v` would save `d` in, from its list of folders
and its name field. A name that has no end, like .csv, gets the end of the
kind that the rows are written as. It's \"\" when the field is empty.
"""
save_chosen(v::SaveView, d) = begin
  name = String(strip(save_name_field(v).text))
  isempty(name) && return ""
  isempty(splitext(name)[2]) && (name *= isempty(d.things) ? ".csv" : ".json")
  joinpath(save_picker(v).at, name)
end

"What the save block `v` shows while it asks where to save: what to do, the breadcrumb, and the field for the name"
save_picker_section(v::SaveView) = begin
  e = editor(v)
  p, field = save_picker(v), save_name_field(v)
  p.room = e.width - 24px
  w = window_of(v)
  typing = w !== nothing && w.focus === field
  name = Row(width(grow=grow), height(30px), child_gap=8px, Alignment.Center,
    Box(label("Name", 12px, color=colours.dim)),
    Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), Alignment.Center,
        background(colours.bg), border(1px, :solid, typing ? colours.accent : colours.line),
        Box(width(grow=grow), height(grow=grow), field)))
  (Column(width(grow=grow), Alignment.Start, padding(10px, 12px, 4px, 12px), child_gap=8px, name="Picker",
     Box(width(grow=grow), Text("Choose a folder, and type the file's name. The end of the name says how the rows are written: .csv, .tsv or .json.",
                                size=12px, family=SANS, color=colours.dim, wrap=WrapMode.words)),
     p, name),)
end

"Open the list of folders of the save block `v` at the folder of its file, with the file's name in the field, or close it"
toggle_save_picker!(v::SaveView) = begin
  v.choosing = !v.choosing
  v.choosing || return v
  p, field = save_picker(v), save_name_field(v)
  p.at, p.open = save_folder(v), true
  to = String(strip(v.spec.to))
  field.text = isempty(to) || Saves.isurl(to) ? save_start(save_data(v)) : basename(to)
  field.cursor = field.anchor = length(field.text)
  v
end

"Save `d`, the rows of `v`, in the file that its list of folders and its name field say, and make that file its `to`"
save_here!(v::SaveView, d) = begin
  path = save_chosen(v, d)
  (isempty(path) || !isempty(save_problem(v, d; path))) && return v
  v.choosing = false
  write_block!(v, SAVE, Saves.with_line(v.lines, :to, tilde(named(editor(v), path))))
  write_rows!(v, d)
end

# Return in the field for the file's name saves, as the button does. Esc closes the list that Choose opened.
onkey(v::SaveView, ev::KeyPress{Keys.enter}) = begin
  unmodified(ev) && ev.window.focus === get(v.parts, :name, nothing) || return nothing
  act!(v, :save, ev.window)
end
onkey(v::SaveView, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) && ev.window.focus === get(v.parts, :name, nothing) || return nothing
  v.choosing = false
  focus(editor(v))
  handled
end

act!(v::SaveView, action, w) = begin
  # A window that isn't on the screen, like one a test makes, has no panel to ask with
  asks = Sys.isapple() && !isempty(w.glfw)
  if action == :key
    asks && !isempty(strip(v.spec.key)) || return handled
    key = key_panel(String(strip(v.spec.key)))
    # The panel took the keyboard, so the window never heard the keys that opened it come up
    w.keys = Keys(0)
    key === nothing || isempty(key) || key_given!(v, key)
    return handled
  end
  action == :choose && return (toggle_save_picker!(v); handled)
  action == :close_picker && return (v.sourcing = false; handled)
  action == :save && v.job === nothing || return handled
  d = save_data(v)
  # Without a `to`, or after Choose, the rows go where the list of folders and the name field say
  asks_where(v) && return (save_here!(v, d); handled)
  isempty(save_problem(v, d)) || return handled
  Saves.isurl(v.spec.to) ? send_save!(v, d) : write_rows!(v, d)
  handled
end

describe(v::SaveView) = begin
  e = editor(v)
  d = save_data(v)
  asks = asks_where(v)
  # While it asks where to save, the file is the one that the list of folders and the name field say
  chosen = asks ? save_chosen(v, d) : ""
  problem = !asks ? save_problem(v, d) : isempty(chosen) ? "Type a name for the file." : save_problem(v, d; path=chosen)
  to = asks ? chosen : String(strip(v.spec.to))
  url = Saves.isurl(to)
  key = String(strip(v.spec.key))
  v.job === nothing || redraw_in!(v, 0.2)   # so that a frame comes soon to see if the rows have gone
  with_theme(component_theme(e.zoom)) do
    what = isempty(d.problem) ? "$(Saves.rows_words(length(d.rows) - 1)) of" : "Save the rows of"
    path = asks ? chosen : save_target(v)
    go = v.job !== nothing ? "Sending…" : url ? "Send" : !isempty(path) && isfile(path) ? "Replace" : "Save"
    tip = url ? "Send the rows to $(Saves.host(to))" : isempty(to) ? "Type a name for the file first" :
          go == "Replace" ? "Write the rows over $(basename(to))" : "Save the rows in $(basename(to))"
    # A save block that has a `to` has a button that chooses another file. One without asks anyway.
    choose = isempty(strip(v.spec.to)) ? () :
      (block_button!(v, :choose, :choose, icon="folder2-open", words="Choose", tip=v.choosing ? "Close the list of folders" : "Choose another file to save in", on=v.choosing),)
    bar = block_bar(Box(width(6px)), Icon(url ? "cloud-arrow-up" : "save", size=14px, color=colours.dim), Box(width(4px)),
      Box(label(what, 13px, weight="Semibold")), Box(width(6px)), source_button(v),
      (isempty(to) ? () : (Box(width(6px)), Icon("arrow-right", size=12px, color=colours.dim), Box(width(6px)),
                           Box(label(url ? Saves.host(to) : basename(to), 13px))))...,
      (url && !isempty(key) ? (Box(width(10px)), Icon("key", size=12px, color=colours.dim), Box(width(4px)), Box(label(key, 12px, color=colours.dim))) : ())...,
      Box(width(grow=grow)),
      choose...,
      block_button!(v, :go, :save, icon=url ? "cloud-arrow-up" : "save", words=go, tip=tip, off=!isempty(problem) || v.job !== nothing, bold=true),
      Box(width(6px)))
    picker = asks ? save_picker_section(v) : ()
    words, icon, colour = !isempty(problem) ? (problem, "exclamation-circle", colours.accent) :
                          isempty(v.said) || asks ? (save_plan(v, d; to), "", colours.dim) :
                          (v.said, v.failed ? "exclamation-circle" : v.job === nothing ? "check2" : "", v.failed ? colours.accent : colours.dim)
    note = Row(width(grow=grow), padding(9px, 12px, 9px, 12px), Alignment.Center, child_gap=6px, clip=true, name="Said",
      (isempty(icon) ? () : (Icon(icon, size=13px, color=colour),))...,
      Box(width(grow=grow), Text(words, size=12px, family=SANS, color=colour, wrap=WrapMode.words)),
      (v.nokey && Sys.isapple() ? (block_button!(v, :key, :key, icon="key", words="Add Key…", tip="Type the key, and Ladder keeps it in your Keychain"),) : ())...)
    Column(block_look()..., clip=true, name="Save", bar, (v.sourcing ? from_picker_section(v) : ())..., picker..., note)
  end
end

"The save block as HTML: which rows it saves, and where to"
save_html(e, v::SaveView) = begin
  d = save_data(v)
  to = String(strip(v.spec.to))
  what = isempty(d.problem) ? "the $(Saves.rows_words(length(d.rows) - 1)) of $(d.name)" : "the rows of the table above"
  "<p><em>Saves $(escape(what)) $(isempty(to) ? "as a file" : "to " * escape(to)).</em></p>"
end

BLOCKS[SAVE] = SaveView
block_name(::Type{SaveView}) = "Save"
block_icon(::Type{SaveView}) = "save"
block_insert(::Type{SaveView}) = ("Save", ["```$SAVE", "to: ", "```", "", ""], (2, 4))
block_html(e, v::SaveView) = save_html(e, v)
