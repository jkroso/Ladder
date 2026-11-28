# The file finder and the project picker

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" describe focus
@use "github.com/jkroso/UI.jl/Interface/draw" cursor redraw_in!
@use "./markdown" words
@use "./remote" => Remote
@use "./folders" => Folders
@use Colors: RGBA
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
@use "./file_view" exports...
@use "./page_extras" exports...
@use "./palette" exports...

export FINDER_MOST, FINDER_TOP, FINDER_WIDE, finder, finder_address, finder_place, finder_shown,
       letter_runs, matches, open_picker!, picker_none, picker_open!, project_list, project_place

# --- the file finder and the project picker ------------------------------------------------
#
# ⌘O opens the file finder: a bar near the top of the window, with a list of
# the folder's pages under it. ⌘P opens the project picker, which looks the
# same and lists projects: the folders that you made favourites, in your
# order, then the git repositories in your home folder, the one that git last
# wrote in first. See "the projects" in folders.jl. Type some letters of a
# name, in order, and the list keeps the rows that have them. ↑ and ↓ choose a
# row, Return opens it and Esc closes the list. A project opens in the window,
# as a click on a folder in the top bar's path opens it. `e.popup` is
# `:finder` or `:projects` while one shows.
#
# Both have the command palette's colours, its font and its rows. The list is
# in the same box as the field, so the two are as wide as each other.

"Open the file finder"
open_finder!(e) = (list_files!(e); open_picker!(e, :finder, "Find a file, or type a web address"))

"Open the project picker. A search for the projects starts on a second thread."
open_projects!(e) = (project_list(e); open_picker!(e, :projects, "Find a project"))

open_picker!(e, kind, words) = begin
  e.popup = kind
  e.picked = 1
  i = input(e)
  i.text = ""
  i.cursor = i.anchor = 0
  # The command palette has the same field, with other words in it and smaller text beside a chip
  i.placeholder, i.font_size, i.font_family = words, 15px, omni_font()
  focus(i)
end

"The projects that the picker lists: the favourites that are there, then the git repositories of the home folder that aren't favourites"
project_list(e) = begin
  favourites = filter(isdir, Folders.favourites())
  [favourites; filter(!in(favourites), Folders.projects(home_folder()))]
end

"Where the project at `path` is, as its row says: the folder that it's in, with ~ for the home folder"
project_place(path) = (d = dirname(path); inside_path(d, homedir()) ? "~" * d[ncodeunits(homedir())+1:end] : d)

"Open the row for `path`: a page of the folder, or a project in the window"
picker_open!(e, path) =
  if e.popup == :projects
    e.popup = :none
    focus(e)
    open_folder!(e, path)
  else
    open!(e, path)
  end

"The pages, or the projects, whose names have the letters typed, in order"
matches(e) = begin
  q = lowercase(input(e).text)
  filter(e.popup == :projects ? project_list(e) : e.files) do path
    name = lowercase(basename(path))
    at = firstindex(name)
    all(q) do c
      found = findnext(c, name, at)
      found === nothing ? false : (at = nextind(name, found); true)
    end
  end
end

"""
The parts of `name`, each with true when its letters are ones that `typed`
has. They're the letters that `matches` finds: the first of each, in order.
"""
letter_runs(name::AbstractString, typed::AbstractString) = begin
  want = collect(lowercase(typed))
  runs = Tuple{String,Bool}[]
  j = 1
  for c in name
    hit = j <= length(want) && lowercase(c) == want[j]
    hit && (j += 1)
    !isempty(runs) && last(runs)[2] == hit ? (runs[end] = (last(runs)[1] * c, hit)) : push!(runs, (string(c), hit))
  end
  runs
end

const FINDER_TOP = 90.0     # how far the finder's bar is from the top of the window
const FINDER_WIDE = 600.0   # how wide its bar is, when the window has room for it
const FINDER_MOST = 9       # the most rows that its list shows

"The rows that the list shows: as many as fit in the window, up to `FINDER_MOST`"
finder_shown(e) = begin
  # Besides the rows, the box has the field, 4 lines and 6px under the card. The window keeps 24px under the box.
  room = num(window_size(e)[2]) - FINDER_TOP - OMNI_FIELD_H - 4 - 6 - 24
  first(matches(e), clamp(floor(Int, room / OMNI_ROW_ONE), 1, FINDER_MOST))
end

finder_key!(e, K) = begin
  found = finder_shown(e)
  # Esc, Return, ↓ and ↑ do what they do here only by themselves
  stepping = K in (Keys.escape, Keys.enter, Keys.down, Keys.up)
  stepping && !unmodified(e) && return nothing
  if K == Keys.escape
    e.popup = :none
    focus(e)
  elseif K == Keys.enter
    # An address on the web that's typed in the file finder is asked for: see "a page from a web server"
    address = finder_address(e)
    address !== nothing ? (e.popup = :none; focus(e); get_page!(e, address)) :
    isempty(found) ? (e.popup = :none; focus(e)) : picker_open!(e, found[clamp(e.picked, 1, length(found))])
  elseif K == Keys.down
    e.picked = min(e.picked + 1, max(1, length(found)))
  elseif K == Keys.up
    e.picked = max(e.picked - 1, 1)
  else
    e.picked = 1
  end
  nothing
end

"Where the finder's box is in the window: its left side, its top and its width. It's centred beside the sidebar."
finder_place(e) = begin
  left, room = num.(page_span(e))
  wide = min(FINDER_WIDE, room - OMNI_LEFT - OMNI_RIGHT)
  (x=left + round((room - wide) / 2), y=FINDER_TOP, w=wide)
end

# The text typed starts where the names of the files under it do: 6px to the card, its line, and 14px in the row
describe(f::FinderInput) = Row(width(grow=grow), height(grow=grow), padding(0px, px(OMNI_BAR_X), 0px, 21px), name="File field", input(editor(f)))
onkey(f::FinderInput, ::KeyPress{Keys.mouse_left}) = focus(input(editor(f)))
cursor(::FinderInput) = :ibeam

"The web address that's typed in the file finder, or nothing when what's typed isn't one. No file's name has a / in it, so an address fits no file."
finder_address(e) = e.popup == :finder ? Remote.typed(input(e).text) : nothing

"What the list says when it has no row"
picker_none(e) =
  finder_address(e) !== nothing ? "Press Return to open $(Remote.label(finder_address(e)))" :
  e.popup == :finder ? "No file has that name" :
  Folders.searching() !== nothing && isempty(project_list(e)) ? "Looking for projects…" :
  isempty(strip(input(e).text)) ? "Your home folder has no git repository" : "No project has that name"

finder(e) = begin
  c = omni(e)
  i = input(e)
  i.color, i.placeholder_color, i.font_size, i.font_family = c.ink, c.muted, 15px, omni_font()
  # While the projects are searched for, the window looks again soon for what the search found
  e.popup == :projects && Folders.searching() !== nothing && redraw_in!(e, 0.1)
  found = finder_shown(e)
  rows = isempty(found) ?
    Row(width(grow=grow), height(px(OMNI_ROW_ONE)), padding(14px, 0px), Box(omni_label(picker_none(e), 14, c.ink, weight=OMNI_NAME))) :
    Column(width(grow=grow), Alignment.Start, [node!(() -> FileRow(path=p, finder=n), e, (:pick, n, p)) for (n, p) in enumerate(found)]...)
  at = finder_place(e)
  # The field is at the top of the box, and the rows are under it on a card with a line round it, 6px inside the box
  omni_at(at.x, at.y, Column(fixed(px(at.w)), Alignment.Start, radius(6px), background(c.drop), border(1px, :solid, c.drop_line),
                             shadow(0, 4, 18, RGBA(0, 0, 0, e.theme == :night ? 0.5 : 0.14)), name=e.popup == :projects ? "Project picker" : "File finder",
    Box(width(grow=grow), height(px(OMNI_FIELD_H)), node!(FinderInput, e, :finder_input)),
    Box(width(grow=grow), padding(0px, 6px, 6px, 6px),
      Column(width(grow=grow), Alignment.Start, radius(4px), clip=true, background(c.drop), border(1px, :solid, c.drop_line), rows))))
end
