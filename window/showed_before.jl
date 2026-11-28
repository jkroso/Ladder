# The files that a window showed before, which ⌘⌥← and ⌘⌥→ go back and forward through, and the files that you ignore

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of focus
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "../folders/folders" => Folders
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use "../base" exports...
@use "../additions" exports...
@use "../blocks/takeoff_view" exports...

export __init__, full_takeoff, go_back!, go_forward!, go_place!, hidden!, ignore!, ignored_changed!,
       ignored_tick!, jump_list, last_shown, place_back, place_now, showable, step_back!,
       step_words, takeoff_over, Unpreviewed, unpreviewed!, Jumps, IgnoredSeen, note_place!,
       ignored_shown, input

# --- the files that showed before --------------------------------------------------------
#
# Each window keeps the files that it showed, in the order that it showed them.
# ⌘⌥← goes back to the file that showed before the one that shows now, as the
# back button of a web browser does. ⌘⌥→ goes forward again, to the file that
# going back left. While the sidebar is open, two arrows at its top do the
# same. They are in the top bar, at the right of the part that's over the
# sidebar, and they aren't there while the sidebar is closed, or while
# something fills the window (see `filled`). An arrow is
# faint when it has no file to go to, and its tooltip names the file that it
# goes to. The two buttons at the side of a mouse go back and forward as well,
# if the mouse has them. Any way of showing a file adds to the list: a link, the
# list of files, the file finder, a line of a `find` block. A file shows from
# the place that it was scrolled to, because its buffer keeps that. A link to
# a heading of the page that shows adds nothing, because the file is the same.

"True when the window can show the file at `path` again: it's on the disk, or it's a new page that has no file yet, or a folder that showed in the page"
showable(e, path) = haskey(e.buffers, path) || isfile(path)

"""
The file that `go_back!` would show, or nothing when no file showed before the
one that shows now. With `e.ahead` as the `list`, it's the file that
`go_forward!` would show.
"""
last_shown(e, list=e.back) = (i = findlast(p -> p != e.buf.path && showable(e, p), list); i === nothing ? nothing : list[i])

"What the arrow that goes back (or forward, with `e.ahead` as `list`) goes to, in words: a line of the file that shows, or a file. It's nothing when there's neither."
step_words(e, list=e.back) = begin
  j = jump_list(e)
  p = place_back(e, list === e.back ? j.back : j.ahead, list)
  p !== nothing && return "line $(p.caret[1])"
  to = last_shown(e, list)
  to === nothing ? nothing : basename(to)
end

# A jump to another line of the same file, as Go To, Go To Definition, Find
# Uses and Show Steps make, is a step too. ⌘⌥← goes back to the line that the
# jump left, with the caret and the scroll as they were, before it goes back
# to another file. ⌘⌥→ goes to the jump's line again.

"The places that a window jumped from: see `jump_list`"
@def mutable struct Jumps
  back::Vector{Any} = Any[]    # the places that ⌘⌥← goes back to, the last one last
  ahead::Vector{Any} = Any[]   # the places that ⌘⌥→ goes forward to again
end

"""
The places of the files that showed that the window of `e` jumped from: `back`
for ⌘⌥←, and `ahead` for ⌘⌥→. Each has the file's path, where the caret and
the scroll were, and how many files the list of files to go back to (or
forward to) had then: a place comes before the files that the list got
after it.
"""
jump_list(e) = state_of(e, Jumps)

"How far the page was scrolled before the command palette showed a row of its list in the window, which the window keeps while the palette's command runs: see `place_now`"
@def mutable struct Unpreviewed
  offset::Any = nothing   # nothing when the palette showed no row
end

"Note that the page of `e` was scrolled to `offset` before the command palette showed a row in it. With nothing, the palette showed no row."
unpreviewed!(e, offset) = (state_of(e, Unpreviewed).offset = offset; e)

"Where the window of `e` is: its file, its caret, its anchor and how far it's scrolled"
place_now(e) = begin
  # While the palette showed a row of its list, the window scrolled to it. The place is where it was before that.
  was = state_of(e, Unpreviewed).offset
  (path=e.buf.path, caret=e.buf.caret, anchor=e.buf.anchor, offset=was isa typeof(e.scroll.offset) ? was : e.scroll.offset)
end

"Note where the window of `e` is, before it jumps to another line of the file, so ⌘⌥← comes back to it. A new jump ends what ⌘⌥→ would go to."
note_place!(e) = begin
  isempty(e.buf.path) && return nothing
  j = jump_list(e)
  push!(j.back, (; place_now(e)..., depth=length(e.back)))
  empty!(j.ahead)
  empty!(e.ahead)
  nothing
end

"The place of the file that shows that a step from the list of files `files` goes to first, from the places `places`, or nothing"
place_back(e, places, files) = !isempty(places) && last(places).depth == length(files) && last(places).path == e.buf.path ? last(places) : nothing

"Put the window of `e` where it was at the place `p`: its caret, its anchor and its scroll"
go_place!(e, p) = begin
  b = e.buf
  fit(c) = (n = clamp(c[1], 1, length(b.lines)); (n, clamp(c[2], 0, length(b.lines[n]))))
  b.caret, b.anchor = fit(p.caret), fit(p.anchor)
  e.scroll.offset = p.offset
  hold!(e, nothing)
  focus(e)
  redraw_in!(e, 0)
  nothing
end

"""
Show the last file of `from` that's still there, and put the file that leaves
on `to`. A file that was renamed is there under its new name. One that went to
the Trash is passed over. It's true when there was a file to show. A jump in
the file that shows comes first: see `jump_list`.
"""
step_back!(e, from, to) = begin
  j = jump_list(e)
  mine, theirs = from === e.back ? (j.back, j.ahead) : (j.ahead, j.back)
  p = place_back(e, mine, from)
  if p !== nothing
    pop!(mine)
    push!(theirs, (; place_now(e)..., depth=length(to)))
    go_place!(e, p)
    return true
  end
  while !isempty(from)
    path = pop!(from)
    (path == e.buf.path || !showable(e, path)) && continue
    isempty(e.buf.path) || push!(to, e.buf.path)
    open!(e, path, record=false)
    return true
  end
  false
end

"""
Show the file that showed before the one that shows now. It's false when no
file showed before. A folder's own page can take a step back of its own first,
as the page of a repository goes from a commit back to its files: see `page_back!`.
"""
go_back!(e) = (o = page_object(e); o !== nothing && page_back!(e, o)) || step_back!(e, e.back, e.ahead)

"Show the file that `go_back!` left. It's false when there is none, or when another file was opened since."
go_forward!(e) = step_back!(e, e.ahead, e.back)

"""
True when a list shows the file or the folder at `path` only because it shows
the hidden files too: you chose to ignore it. Its row is faint, as a hidden
one's is.
"""
ignored_shown(e, path) = e.hidden && Folders.isignored(path)

"Make the sidebar list the hidden files and folders too, and the ones that you ignore, or leave them out again"
hidden!(e, on::Bool) = (e.hidden = on; list_files!(e); save_settings!(e); e)

"""
Leave the file or the folder at `path` out of Ladder's lists, as a hidden one
is, or with `on` false, show it again. Ladder remembers it. Every window lists
its folder again at once.
"""
ignore!(e, path, on::Bool=true) = begin
  on ? Folders.ignore!(path) : Folders.unignore!(path)
  ignored_changed!(e)
end

"The list of what you ignore, as a window last saw it"
@def mutable struct IgnoredSeen
  at::Union{Nothing,Float64} = nothing   # when the list had last changed, when the window last listed its folder, or nothing before its first frame
end

"List the folder of every window again, after the list of what you ignore changed"
ignored_changed!(e) = begin
  for o in unique([editors; e])
    list_files!(o)
    state_of(o, IgnoredSeen).at = Folders.changed()
    w = window_of(o)
    w === nothing || stale!(w)
  end
  nothing
end

"""
Notice a change to the list of what you ignore that came from its page: you
deleted a line and saved the page, or another app changed it. Every window
lists its folder again.
"""
ignored_tick!(e) = begin
  at = Folders.changed()
  seen = state_of(e, IgnoredSeen)
  seen.at === nothing && (seen.at = at)
  seen.at < at && ignored_changed!(e)
  nothing
end
each_frame!(ignored_tick!)

# The page that lists what you ignore is a page of the settings. Its path is
# asked for each time, since the built app moves the pages when it starts.
__init__() = (Folders.PAGE[] = () -> settings_page("ignored-files.md"); nothing)

"What a click on `o` in the sidebar does: a folder shows in the sidebar, and a file shows in the page"
open!(e, d::AbstractDirectory; record=true) = go_folder!(e, string(d.path))
open!(e, o::FSObject; record=true) = open!(e, string(o.path); record)

"Show the folders and files of `folder` in the sidebar. The document that's showing stays."
go_folder!(e, folder) = begin
  e.folder = folder
  list_files!(e)
  e.files_scroll.offset = 0px
  e
end
"The field of the window that you type in to find a file, a project or a command"
input(e) = window_parts(e).input::TextInput

"The takeoff of the page that fills the window, or nothing"
full_takeoff(e) = (v = full_block(e); v isa TakeoffView ? v : nothing)

"The block that fills the window, over the page and the sidebar and under the top bar"
takeoff_over(e) = begin
  v = full_block(e)
  v === nothing ? () : (Box(width(grow=grow), height(grow=grow), padding(above_page(e), 0px, 0px, 0px), background(colours.bg), geometry(v)),)
end
