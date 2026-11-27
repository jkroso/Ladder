# The page of a zip file: what it holds, without being unpacked, as a list of
# its folders and files, each file with its size and when it changed. A click
# on a file unpacks it to show it. zip.jl reads the list from the zip file.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"...
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe
@use "github.com/jkroso/UI.jl/Interface/draw" cursor redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/URI.jl/FS" => FS
@use "./zip" => Zips
@use "./look" SANS SERIF MONO CODE_FONT CODE_STYLE CODE_SLANT CODE_SCALE code_type codefont codestyle codeslant SYMBOL_FONT Palette SEPIA PAPER NIGHT THEMES colours SITE SITE_MEASURE SITE_RULE SITE_STARS SITE_INK2 LABEL use! TOPBAR_H PANEL_W PANEL_MIN PANEL_MAX PROSE_W PAGE_X PAGE_TOP PAGE_BOTTOM CODE_END CHIP_X BLOCK_X QUOTE_X CELL_X CELL_Y grow clear lifted fixed spacer num label Face measured measure width_in drawable has stand_ins font_with one_wide one_width stand_in_from runs hasall spared_width spared LIVE_GAP BLOCK_ICONS
@use "./folder_page" own! node! MARKDOWN window_size PICTURES MODELS TERMINALS CHATS SOUNDS VIDEOS ZIPS TABLES MAC_PICTURES DOCUMENTS FONTS CODE file_icon dark_page SERIES_LIGHT SERIES_DARK series_colours trouble held_keys only_held unmodified HELD commas file_menu ignore_item menu_theme drawn_menu! workspace url_path opener app_name PAGE_TITLES first_answer email_title page_title DESIGNS PageRow PAGE_ROW_H page_row! page_heading page_note PageButton page_button! git_colour favourite_item ishidden left_out on_screen whole_picture MEDIA_CACHE media_dir tilde  title
@use "./host" editor page_object object list_files! go_folder! open! open_folder! show_path! folder_kind page_top trash! file_act! show_in_finder free_path show_beside!
@use "./views" entries entry_icon entry_name entry_marks folder_view page_view page_fills page_first

# --- a zip file ---------------------------------------------------------------------------------
#
# A zip file shows what it holds, without being unpacked: its folders and
# files as a list, each file with its size and when it changed. zip.jl reads
# the list from the end of the zip file.
#
#   - A click on a folder of the list opens or closes it.
#   - A click on a file shows that one file in the page. Ladder unpacks it into
#     a folder of its own, beside the Mac's other caches, and the file can't
#     be changed there, since a change wouldn't go into the zip file. The
#     arrow that goes back shows the zip file again.
#   - The Unpack button unpacks the whole file beside itself, as two clicks in
#     the Finder do: one thing at the top of the zip file comes out as it is,
#     and more than one go into a folder with the zip file's name. The sidebar
#     then shows what came out.

push!(BLOCK_ICONS, "file-zip", "box-arrow-up", "folder", "chevron-down", "chevron-right")

"What the page shows of a zip file: the folders and files that it holds"
@def mutable struct ZipView <: SemanticUI
  path::String = ""
  read::Float64 = -1.0                         # when the file had changed, as its list was read
  zip::Any = nothing                           # what it holds, a `Zips.Zip`, or the words of why it can't be read
  kids::Dict{String,Vector{Zips.Entry}} = Dict{String,Vector{Zips.Entry}}()   # what each of its folders holds, by the folder's name
  open::Set{String} = Set{String}()            # the folders that are open
  rows::Dict{Any,PageRow} = Dict{Any,PageRow}()
  buttons::Dict{Any,PageButton} = Dict{Any,PageButton}()
  job::Any = nothing                           # the program that unpacks the file, and the folder that it writes to
  said::String = ""                            # what went wrong with the last click, or ""
end

# A file whose name ends as a zip file's does, in small letters or in capitals
page_view(e, o::FS.File) = begin
  path = string(o.path)
  lowercase(splitext(path)[2]) in ZIPS ? node!(() -> ZipView(path=path), e, (:zip, path)) : nothing
end

"A folder for the files that Ladder unpacks to show them, in place of the one beside the Mac's caches. A test names one of its own."
const ZIP_ROOM = Ref("")

"The folder that the files of the zip file at `path` are unpacked into, one at a time, to show them. A zip file that changes gets a new one."
zip_room(path) = joinpath(isempty(ZIP_ROOM[]) ? joinpath(homedir(), "Library", "Caches", "Ladder", "zips") : ZIP_ROOM[],
                          string(hash((path, mtime(path))), base=16))

"Read the list of the zip file of `v` again when the file has changed. A zip file with one folder at its top shows that folder open."
zip_read!(v::ZipView) = begin
  at = mtime(v.path)
  at == v.read && return
  v.read = at
  empty!(v.kids)
  v.zip = try Zips.contents(v.path) catch err; trouble(err) end
  v.zip isa Zips.Zip || return
  for en in v.zip.entries
    inner = rstrip(en.name, '/')
    push!(get!(() -> Zips.Entry[], v.kids, occursin('/', inner) ? dirname(inner) * "/" : ""), en)
  end
  # Each folder's folders come before its files
  foreach(list -> sort!(list, by=!Zips.isfolder, alg=MergeSort), values(v.kids))
  top = get(v.kids, "", Zips.Entry[])
  isempty(v.open) && length(top) == 1 && Zips.isfolder(top[1]) && push!(v.open, top[1].name)
  nothing
end

"The most lines of a zip file that show at once"
const ZIP_MOST = 3000

"The entries of the zip file of `v` that show: what's at its top, and what's in each open folder, under the folder"
zip_lines(v::ZipView) = begin
  lines = Zips.Entry[]
  walk(dir) = for en in get(v.kids, dir, Zips.Entry[])
    length(lines) >= ZIP_MOST && return
    push!(lines, en)
    Zips.isfolder(en) && en.name in v.open && walk(en.name)
  end
  walk("")
  lines
end

"Show the file `en` of the zip file of `v` in the page. Ladder unpacks that one file to show it."
zip_show!(v::ZipView, en::Zips.Entry) = begin
  e = editor(v)
  v.said = ""
  path = try
    Zips.keep(v.path, en, zip_room(v.path))
  catch err
    v.said = trouble(err)
    return
  end
  show_beside!(e, path)
  nothing
end

"""
Unpack the whole zip file of `v` beside itself. A program of the Mac does it
while the window goes on, into a folder with a name of its own, and
`zip_unpacked!` gives what came out its name when the program is done.
"""
zip_unpack!(v::ZipView) = begin
  v.job === nothing || return
  v.said = ""
  into = joinpath(dirname(v.path), ".unpacking-" * string(hash((v.path, time())), base=16))
  v.job = try
    (run(pipeline(`ditto -x -k $(v.path) $into`, stdout=devnull, stderr=devnull), wait=false), into)
  catch err
    v.said = trouble(err)
    nothing
  end
  nothing
end

"When the program that unpacks the zip file of `v` is done, give what came out its name and show it in the sidebar"
zip_unpacked!(v::ZipView) = begin
  v.job === nothing && return
  yield()   # the program's end is noticed by a task, which gets its turn here
  proc, into = v.job
  process_exited(proc) || return
  v.job = nothing
  e = editor(v)
  dir = dirname(v.path)
  found = try filter(n -> n != "__MACOSX" && n != ".DS_Store", readdir(into)) catch; String[] end
  if proc.exitcode != 0 || isempty(found)
    v.said = "The Mac couldn't unpack this file."
    rm(into, recursive=true, force=true)
    return
  end
  out = try
    if length(found) == 1
      # One thing at the top comes out as it is, as the Finder unpacks it
      name = only(found)
      to = isdir(joinpath(into, name)) ? free_path(e, dir, name) : free_path(e, dir, splitext(name)...)
      mv(joinpath(into, name), to)
      rm(into, recursive=true, force=true)
      to
    else
      to = free_path(e, dir, title(v.path))
      mv(into, to)
      to
    end
  catch err
    v.said = trouble(err)
    return
  end
  list_files!(e)
  isdir(out) ? go_folder!(e, out) : (e.folder == dir || go_folder!(e, dir))
  nothing
end

"A line of the list of a zip file: a folder that a click opens or closes, or a file that a click shows"
zip_row!(v::ZipView, en::Zips.Entry) = begin
  folder = Zips.isfolder(en)
  opened = folder && en.name in v.open
  act = folder ? (_ -> (opened ? delete!(v.open, en.name) : push!(v.open, en.name); nothing)) : (_ -> zip_show!(v, en))
  page_row!(v, en.name, act,
    Box(width(px(16 * Zips.depth(en)))),
    Box(width(10px), (folder ? (Icon(opened ? "chevron-down" : "chevron-right", size=9px, color=colours.dim),) : ())...),
    Icon(folder ? "folder" : file_icon(en.name), size=13px, color=colours.dim),
    Box(label(Zips.short(en), 13px)),
    Box(width(grow=grow)),
    (folder ? () : (Box(label(Zips.size_words(en.size), 12px, color=colours.dim)),
                    Box(width(96px), Alignment.End, label(en.changed > 0 ? Libc.strftime("%-d %b %Y", en.changed) : "", 12px, color=colours.faint))))...)
end

describe(v::ZipView) = begin
  e = editor(v)
  zip_read!(v)
  zip_unpacked!(v)
  v.job === nothing || redraw_in!(e, 0.05)
  z = v.zip
  z isa Zips.Zip || return Column(width(grow=grow), Alignment.Start, name="Zip",
    page_title("file-zip", basename(v.path), "Ladder can't read what this file holds."), page_note(string(z)))
  n = Zips.files(z)
  about = (n == 1 ? "1 file" : "$n files") * "  ·  " * Zips.size_words(z.size) * "  ·  " * Zips.size_words(filesize(v.path)) * " as a zip file"
  lines = zip_lines(v)
  Column(width(grow=grow), Alignment.Start, name="Zip",
    page_title("file-zip", basename(v.path), about),
    Row(padding(8px, 0px, 14px, 8px), child_gap=10px,
      page_button!(v, :unpack, _ -> zip_unpack!(v), icon="box-arrow-up", words=v.job === nothing ? "Unpack" : "Unpacking…", off=v.job !== nothing),
      (isempty(v.said) ? () : (Box(label(v.said, 12px, color=git_colour(:deleted))),))...),
    (isempty(lines) ? (page_note("This zip file is empty."),) : [zip_row!(v, en) for en in lines])...,
    (length(lines) >= ZIP_MOST ? (page_note("The list stops here. Unpack the file to see the rest."),) : ())...)
end

cursor(::ZipView) = :arrow
