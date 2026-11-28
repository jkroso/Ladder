# Wiki links, like [[Ideas]], which name a page and not its file

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "./markdown" Kind
@use "./sheet" shown
@use "./folders" => Folders
@use "./base" exports...
@use "./find_view" exports...
@use "./code_names" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...
@use "./sheet_view" LinkNotes

export PROJECT_MARKS, find_named, project_root, wiki_file, wiki_names, WikiOffer

# --- wiki links ---------------------------------------------------------------------------
#
# A wiki link, like [[Ideas]], names a page and not its file, as in Obsidian. The
# page can be anywhere in the project, so a link stays good when a page moves to
# another folder. See markdown.jl for how one is written.

"The folder names that mark the top folder of a project"
const PROJECT_MARKS = (".git", ".obsidian")

"""
The top folder of the project that the folder `dir` is in: the nearest folder,
from `dir` up, that has a `.git` or an `.obsidian` folder in it. It's `dir`
when there's none below the home folder.
"""
project_root(dir) = begin
  d = dir
  while d != homedir() && d != dirname(d)
    any(m -> ispath(joinpath(d, m)), PROJECT_MARKS) && return d
    d = dirname(d)
  end
  dir
end

"""
The file under `root` whose path ends with one of `names`, like `Ideas.md` or
`notes/Ideas.md`, in any case, or nothing. A file in a folder near the top
comes before one in a folder deeper down. Hidden folders, the ones that you
ignore and `node_modules` are left out, and the look stops after a part of a
second, as the `find` block's does.
"""
find_named(root, names; budget=FIND_BUDGET) = begin
  ends = ["/" * lowercase(n) for n in names]
  started = time()
  level = [root]
  ignored = Folders.ignored()
  while !isempty(level) && time() - started < budget
    deeper = String[]
    for dir in level
      found = try sort!(readdir(dir), by=lowercase) catch; String[] end
      for name in found
        path = joinpath(dir, name)
        left_out(path, ignored) && continue
        if isdir(path)
          name == "node_modules" || push!(deeper, path)
        elseif any(t -> endswith(lowercase(path), t), ends)
          return path
        end
      end
    end
    level = deeper
  end
  nothing
end

"The file that the wiki link to `name`, in a page in the folder `dir`, names, as `wiki_path` finds it, or nothing when no file has the name"
wiki_file(dir, name) = begin
  names = ismarkdown(name) ? [name] : [name * ".md", name]
  root = project_root(dir)
  for top in unique([dir, root]), n in names
    path = abspath(top, expanduser(n))
    isfile(path) && return path
  end
  find_named(root, names)
end

"""
The file that the wiki link to `name` names. `name` is a page's name, like
`Ideas`, and its file is `Ideas.md`. A name with a file's extension, like
`plan.pdf`, can be that file too. A name can have folders in it, like
`notes/Ideas`. Ladder looks in the page's own folder, then from the top of its
project (see `project_root`), then through the whole project. When no file
has the name, it's the path of a new page in the page's own folder.
"""
wiki_path(e, name) = begin
  dir = docdir(e)
  found = wiki_file(dir, name)
  found === nothing || return found
  names = ismarkdown(name) ? [name] : [name * ".md", name]
  new = abspath(dir, names[1])
  # A name with folders that aren't there yet makes its page in the page's own folder
  isdir(dirname(new)) ? new : joinpath(dir, basename(new))
end

"""
Follow a wiki link to `target`: show the page that it names. `Ideas#Plans` goes
to the heading Plans of the page Ideas, and `#Plans` to a heading of the page
that shows. A page that isn't anywhere opens as a new page with no text, in the
page's own folder. Its file is made when you write in it.
"""
follow_wiki!(e, target) = begin
  name, heading = occursin('#', target) ? String.(split(target, '#', limit=2)) : (target, "")
  name = String(strip(name))
  isempty(name) && return (go_heading!(e, e.buf.path, heading); e)
  path = wiki_path(e, name)
  if !isempty(heading) && ismarkdown(path) && isfile(path)
    go_heading!(e, path, heading)
    return e
  end
  isfile(path) ? show_path!(e, path) : open!(e, path)
end

# While you type the name in a wiki link, the list of names under the caret
# shows the pages of the project whose names fit what's typed. Right after the
# [[, it shows them all, the pages beside this one first. Each page's folder,
# from the top of the project, is at the right of its row. Return or Tab types
# the rest of the name and the ]] that ends the link. Two pages with the same
# name are each written with their folders, like notes/Ideas.

"What a window keeps of the wiki link that's being typed"
@def mutable struct WikiOffer
  offered::Union{Nothing,Tuple} = nothing   # the text and the place of the caret that pages were last looked for at, and what was found
end

"""
The pages that the name being typed in a wiki link could be: the line, the
column where the name starts, and the names. Nothing when the caret isn't in
the name of a wiki link just after a character was typed, or no page fits.
"""
wiki_offered(e) = begin
  b = e.buf
  i, col = b.caret
  key = (b.path, b.version, b.caret)
  just_typed(e) || return nothing
  s = state_of(e, WikiOffer)
  kept = s.offered
  kept !== nothing && kept[1] == key && return kept[2]
  found = wiki_names(e, i, col)
  s.offered = (key, found)
  found
end

"The name being typed in a wiki link at column `col` of line `i`, and the pages that fit it, as `wiki_offered` gives them"
wiki_names(e, i, col) = begin
  b = e.buf
  kinds(b)[i].kind in (Kind.code, Kind.fence, Kind.table) && return nothing
  chars = collect(b.lines[i])
  # The name starts after the [[ before the caret. A | or a # ends it, and a bracket isn't part of one.
  start = col
  while start > 0 && !(chars[start] in ('[', ']', '|', '#')); start -= 1 end
  (start >= 2 && chars[start] == '[' && chars[start-1] == '[') || return nothing
  col - start <= 80 || return nothing
  typed = lowercase(String(chars[start+1:col]))
  dir = docdir(e)
  root = project_root(dir)
  pages = [p for (p, _) in folder_pages(root).pages if p != b.path]
  name(p) = splitext(basename(p))[1]
  many = Dict{String,Int}()
  foreach(p -> many[lowercase(name(p))] = get(many, lowercase(name(p)), 0) + 1, pages)
  notes = Dict{String,String}()
  found = Tuple{Int,Bool,Int,String,String}[]   # how well it fits, whether it's in another folder, how deep it is, its name in lower case, and its name
  for p in pages
    folder = relpath(dirname(p), root)
    folder == "." && (folder = "")
    # Two pages with the same name are told apart by their folders
    shown = many[lowercase(name(p))] > 1 && !isempty(folder) ? joinpath(folder, name(p)) : name(p)
    low = lowercase(shown)
    fit = low == typed ? 0 : startswith(low, typed) ? 1 : any(w -> startswith(w, typed), split(low, r"[\s_/-]+", keepempty=false)) ? 2 : occursin(typed, low) ? 3 : 4
    fit < 4 || continue
    shown == name(p) && (notes[shown] = folder)
    push!(found, (fit, dirname(p) != dir, count(==('/'), folder), low, shown))
  end
  isempty(found) && return nothing
  state_of(e, LinkNotes).notes = notes
  (i, start, unique([n for (_, _, _, _, n) in first(sort!(found), NAMES_SHOWN)]))
end

"""
Type `name` in place of the text from column `start` of line `i` to the caret,
as the list of names does. In a wiki link, the ]] that ends the link comes too,
unless the link has its end already. The caret goes past a ]] that's just after the name.
"""
complete!(e, i, start, name) = begin
  b = e.buf
  edit!(b, (i, start), b.caret, name)
  kinds(b)[i].kind == Kind.code && return
  after = rest(b.lines[i], b.caret[2])
  ends, opens = findfirst("]]", after), findfirst("[[", after)
  if ends === nothing || (opens !== nothing && first(opens) < first(ends))
    edit!(b, b.caret, b.caret, "]]")
  elseif startswith(after, "]]")
    b.caret = b.anchor = (i, b.caret[2] + 2)
  end
end
