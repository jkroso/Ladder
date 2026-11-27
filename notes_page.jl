# The page of a folder of notes: the notes that changed last, newest first,
# with the words that each one starts with, and git's bar when the folder is a
# repository. notes.jl finds the notes, and git_marks.jl says what git says.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"...
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI handled describe
@use "github.com/jkroso/UI.jl/Interface/draw" cursor ishovered redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use "./git" => Git
@use "./notes" => Notes
@use "./look" exports...
@use "./folder_page" exports...
@use "./host" exports...
@use "./views" exports...
@use "./git_marks" exports...

# --- a folder of notes -------------------------------------------------------------------------
#
# A folder of notes is a folder whose pages link to each other, with wiki
# links like [[Ideas]] or with Markdown links to their files. notes.jl reads
# the pages and says which link to which. A folder is one when it has an
# `.obsidian` folder in it, or when its own page, the file `.ladder`, ends with
# this block:
#
#     ```julia
#     Ladder.NotesDirectory
#     ```
#
#   - Under the text of each page, "Linked from" lists the pages that link to
#     it. A click on one shows it.
#   - A line over the sidebar's list says how many pages the folder has. A
#     click on it shows the folder's own page.
#   - The folder's own page lists the pages that changed last, the names that
#     pages link to and that no page has yet, and the pages that no page
#     links to. A click on a name with no page starts that page.
#
# A folder of notes that git keeps has the letters of git's changes in the
# sidebar too, and the line of its branch.

"A folder of notes, or a folder in one: its pages link to each other"
@def struct NotesDirectory <: AbstractDirectory end

# A folder in a folder of notes holds notes too, unless it has a kind of its own
FS.kind(::NotesDirectory, path::FSPath) = (k = folder_kind(path); k === FS.Directory ? NotesDirectory : k)

push!(BLOCK_ICONS, "journal-text", "file-earmark-plus", "link-45deg")

"The top folder of the notes that the folder `d` is in"
notes_top(d::NotesDirectory) = d.parent isa NotesDirectory ? notes_top(d.parent) : string(d.path)

"The pages and the links of each folder of notes, by its top folder, and when they were read"
const NOTE_WEBS = Dict{String,Tuple{Float64,Notes.Web}}()

"The pages of the notes whose top folder is `root`, and the links between them. They're read again after 2 seconds."
notes_web(root) = begin
  kept = get(NOTE_WEBS, root, nothing)
  kept !== nothing && time() - kept[1] < 2 && return kept[2]
  w = Notes.web(root)
  NOTE_WEBS[root] = (time(), w)
  w
end

"How many pages, in words"
pages_words(n) = n == 1 ? "1 page" : "$n pages"

entry_marks(e, o::NotesDirectory) = git_marks(e, o)
entry_marks(e, ::NotesDirectory, o::FSObject) = git_marks(e, o)

"The line over the sidebar's list, when the sidebar's folder holds notes"
@def mutable struct NotesBar <: SemanticUI
  root::String = ""
end

folder_view(e, d::NotesDirectory) = begin
  bar = node!(NotesBar, e, :notes_bar)
  bar.root = notes_top(d)
  # Notes that git keeps have the line of their branch too
  repo = git_top(string(d.path))
  isempty(repo) && return (list=nothing, bar=bar)
  git = node!(GitBar, e, :git_bar)
  git.root = repo
  (list=nothing, bar=Column(width(grow=grow), bar, git))
end

describe(b::NotesBar) = begin
  e = editor(b)
  n = length(notes_web(b.root).notes)
  Row(width(grow=grow), height(26px), padding(16px, 0px), child_gap=6px, clip=true, name="Notes",
      background(e.buf.path == b.root ? colours.active : ishovered(b) ? colours.hover : clear),
    Icon("journal-text", size=12px, color=colours.dim),
    Box(label("Notes", 12px, color=colours.ink, weight="Medium")),
    Box(width(grow=grow)),
    Box(label(pages_words(n), 11px, color=colours.dim)))
end

cursor(::NotesBar) = :hand
onkey(b::NotesBar, ::KeyPress{Keys.mouse_left}) = (show_beside!(editor(b), b.root); handled)

"What the page shows of the top folder of notes: the pages that changed last, the names with no page and the pages that nothing links to"
@def mutable struct NotesView <: SemanticUI
  path::String = ""
  rows::Dict{Any,PageRow} = Dict{Any,PageRow}()
end

page_view(e, d::NotesDirectory) = (path = string(d.path); notes_top(d) == path ? node!(() -> NotesView(path=path), e, (:notes, path)) : nothing)

"A click on the top folder of notes in the sidebar shows its own page, and the sidebar lists what it holds. A folder in it only shows in the sidebar."
open!(e, d::NotesDirectory; record=true) = begin
  path = string(d.path)
  notes_top(d) == path && open!(e, path; record)
  go_folder!(e, path)
end

"The most lines that one list of the page of a folder of notes has. A note under the list says how many more there are."
const NOTES_MOST = 60

"The names of the pages at `paths`, like `Home, Shed and 3 more`"
page_names(paths; most=3) = begin
  names = [title(p) for p in first(paths, most)]
  length(paths) > most ? join(names, ", ") * " and $(length(paths) - most) more" : join(names, ", ")
end

"A line for the page `n` of the web `w`: its name, its folder, and `note` at the right. A click shows the page."
note_row!(v, e, w, key, path, note="") =
  page_row!(v, (key, path), _ -> (show_path!(e, path); nothing),
    Icon("file-earmark-text", size=13px, color=colours.dim),
    Box(label(title(path), 13px)),
    (isempty(Notes.folder(w, path)) ? () : (Box(label(Notes.folder(w, path), 12px, color=colours.faint)),))...,
    Box(width(grow=grow)),
    (isempty(note) ? () : (Box(label(note, 12px, color=colours.dim)),))...)

"The lines of `list`, no more than `NOTES_MOST`, with a note under them that says how many more there are"
capped(row, list) = begin
  shown = [row(x) for x in first(list, NOTES_MOST)]
  length(list) > NOTES_MOST ? [shown; page_note("and $(length(list) - NOTES_MOST) more")] : shown
end

describe(v::NotesView) = begin
  e = editor(v)
  w = notes_web(v.path)
  redraw_in!(e, 2.1)   # a page that was saved shows here soon after
  loose, wanted = Notes.loose(w), w.wanted
  about = join([pages_words(length(w.notes));
                (isempty(wanted) ? String[] : [length(wanted) == 1 ? "1 name with no page" : "$(length(wanted)) names with no page"]);
                (isempty(loose) ? String[] : ["$(length(loose)) that no page links to"])], "  ·  ")
  # A name with no page starts its page at the top of the notes. Its file is made when you write in it.
  want((name, from)) = page_row!(v, (:wanted, name), _ -> (open!(e, joinpath(v.path, basename(name) * ".md")); nothing),
    Icon("file-earmark-plus", size=13px, color=colours.accent),
    Box(label(name, 13px, color=colours.accent)),
    Box(width(grow=grow)),
    Box(label("linked from " * page_names(from), 12px, color=colours.dim)))
  Column(width(grow=grow), Alignment.Start, name="Notes",
    page_title("journal-text", basename(v.path), about),
    page_heading("Changed last"),
    (isempty(w.notes) ? (page_note("This folder has no page yet."),) :
     [note_row!(v, e, w, :latest, n.path, Git.ago(n.changed)) for n in Notes.latest(w, 8)])...,
    (isempty(wanted) ? () : (Box(height(14px)), page_heading("Names with no page  ·  $(length(wanted))"), capped(want, wanted)...))...,
    (isempty(loose) ? () : (Box(height(14px)), page_heading("Pages that no page links to  ·  $(length(loose))"),
                            capped(n -> note_row!(v, e, w, :loose, n.path), loose)...))...)
end

cursor(::NotesView) = :arrow

"What's under the text of a page of a folder of notes: the pages that link to it"
@def mutable struct LinkedFrom <: SemanticUI
  root::String = ""
  path::String = ""
  rows::Dict{Any,PageRow} = Dict{Any,PageRow}()
end

page_foot(e, d::NotesDirectory, o::FS.File) = begin
  path = string(o.path)
  root = notes_top(d)
  isempty(Notes.linked_from(notes_web(root), path)) && return nothing
  f = node!(() -> LinkedFrom(root=root, path=path), e, (:linked_from, path))
  f.root = root
  f
end

describe(f::LinkedFrom) = begin
  e = editor(f)
  w = notes_web(f.root)
  from = Notes.linked_from(w, f.path)
  Column(fixed(e.width), Alignment.Start, padding(40px, 0px, 0px, 0px), name="Linked from",
    Box(width(grow=grow), height(1px), background(colours.line)),
    Box(height(10px)),
    page_heading("Linked from  ·  $(length(from))"),
    capped(p -> note_row!(f, e, w, :from, p), from)...)
end

cursor(::LinkedFrom) = :arrow
