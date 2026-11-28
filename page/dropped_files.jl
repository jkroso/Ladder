# Files that are dropped on the page from the Finder

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" focus
@use "../base" exports...
@use "../blocks/takeoff_view" exports...
@use "../blocks/schedule_view" exports...
@use "../blocks/gallery_view" exports...
@use "../blocks/canvas_view" exports...
@use "../blocks/contact_view" exports...
@use "./slides_view" exports...
@use "../agent/pane" exports...
@use "./page_mouse" exports...
@use "../files/media_view" istable

export markdown_for, put_files!

# --- files dropped on the page -----------------------------------------------------------
#
# A file that's dropped on the page from the Finder goes into the text. A
# picture goes on a line of its own under the line it's dropped on, written as
# ![name](path), so the page shows it. A CSV file goes in the same way, and
# the page shows it as a table. A Markdown file goes in where it's
# dropped as a link to it. Any other file, and a folder, goes in there as a
# path that shows as a breadcrumb: !`fs"path"`.

"`path` as a link writes it. A space or a bracket would end the link early, so each is written as its code."
escaped(path) = replace(path, ' ' => "%20", '(' => "%28", ')' => "%29")
ispicture(path) = (ext = lowercase(splitext(path)[2]); ext in PICTURES || ext in MAC_PICTURES)

"The Markdown that shows the file or the folder at `path`"
markdown_for(e, path) = begin
  name, at = splitext(basename(path))[1], named(e, path)
  ispicture(path) || istable(path) ? "![$name]($(escaped(at)))" : ismarkdown(path) ? "[$name]($(escaped(at)))" : "!`fs\"$(replace(at, '"' => "\\\""))\"`"
end

onfiledrop(e::Editor, w::Window, paths) = begin
  # What's dropped on an agent's pane goes to the agent with your words, as what's pasted there does
  pane = agent_pane_at(e, w)
  if pane !== nothing
    give_files!(pane, paths)
    focus(pane.field)
    return nothing
  end
  e.buf.view == :markdown || return nothing   # a file goes into a page as Markdown
  slideshow(e) === nothing || return nothing   # the text doesn't change while the page shows as slides
  # A PDF file or a picture that's dropped on a takeoff is its plan
  v = takeoff_at(e, w)
  plan = v === nothing ? nothing : findfirst(p -> isfile(p) && (ispdf(p) || ispicture(p)), paths)
  plan === nothing || return plan!(v, rstrip(String(paths[plan]), '/'))
  # A picture or a page that's dropped on a canvas goes on the board where it's dropped
  board = canvas_at(e, w)
  board === nothing || board.zoom <= 0 || return (put_on_board!(board, paths, board_place(board, num(w.mouse[1]), num(w.mouse[2]))); nothing)
  # A file or a folder that's dropped on a gallery goes into the gallery
  g = gallery_at(e, w)
  g !== nothing && add_files!(g, paths) && return nothing
  # A vCard file that's dropped on a block of contacts joins the block
  c = contacts_at(e, w)
  if c !== nothing
    list, paths = split_contacts(paths)
    add_contacts!(c, list)
    isempty(paths) && return nothing
  end
  put_files!(e, paths, settle(e.buf, locate(e, w.mouse)))
end

"Put the files and folders at `paths` into the text at `at`, the way a drop there does. ⌘V does this with files that were copied."
put_files!(e, paths, at::Pos) = begin
  paths = [rstrip(String(p), '/') for p in paths if ispath(p)]
  isempty(paths) && return
  b = e.buf
  b.view == :markdown || return   # only a page has text for the path to go into, as Markdown
  # A vCard file goes in as a block of its contacts
  list, paths = split_contacts(paths)
  at = put_contacts!(e, list, at)
  # A CSV file goes on a line of its own as a picture does, so the page shows it as a table
  pictures = [markdown_for(e, p) for p in paths if isfile(p) && (ispicture(p) || istable(p))]
  others = [markdown_for(e, p) for p in paths if !(isfile(p) && (ispicture(p) || istable(p)))]
  if !isempty(others)
    line = b.lines[at[1]]
    # What's dropped on a word goes after the word, not into it
    at = (at[1], word_at(line, at[2])[2])
    # A space goes between what's dropped and the words on each side of it, but not before a full stop or a comma
    before = at[2] > 0 && !isspace(line[nextind(line, 0, at[2])]) ? " " : ""
    next = at[2] < length(line) ? line[nextind(line, 0, at[2] + 1)] : ' '
    after = isspace(next) || next in ".,;:!?)]}" ? "" : " "
    new = before * join(others, " ") * after
    edit!(b, at, at, new)
    at = (at[1], at[2] + length(new))
  end
  if !isempty(pictures)
    # Under the block that it's dropped on, so that a picture doesn't go into the middle of a table
    under = block_end(b, at[1])
    empty = isempty(strip(b.lines[under]))
    edit!(b, empty ? (under, 0) : line_end(b, under), line_end(b, under), (empty ? "" : "\n\n") * join(pictures, "\n\n"))
    under += (empty ? 0 : 2) + 2(length(pictures) - 1)
    at = line_end(b, under)
  end
  b.caret = b.anchor = at
  focus(e)
  touch!(e)
end
