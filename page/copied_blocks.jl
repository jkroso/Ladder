# A block that's copied pastes into another page as a part of its page, like ![[costs#^prices]]

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" open_url redraw_in! clipboard!
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring with_pool
@use "../markdown" wikitarget
@use "../files/eml" => Eml
@use "github.com/jkroso/URI.jl/FS" => FS AbstractDirectory
@use InteractiveUtils: clipboard
@use "../base" exports...
@use "../blocks/schedule_view" exports...
@use "../blocks/check_view" exports...
@use "../blocks/canvas_view" exports...
@use "./page_extras" exports...
@use "../agent/pane" exports...
@use "../folders/folder_kinds" exports...
@use "../files/remote_page" exports...
@use "./page_mouse" exports...
@use "./peek_cards" exports...

export COPIED_BLOCK, follow_folder!, ispackage, paste_copy!, paste_part!, pasted_part

# --- a block that's copied pastes as a part of its page --------------------------------------
#
# Copy a whole block of a page and paste it into another page, and the other
# page gets a line like ![[costs#^prices]]: a part of the first page, which
# you type in, and not a copy of its lines. The block gets a name if it has
# none. A block is copied whole while the caret is on it as a whole, after a
# click with ⌘ and ⌥ down chose it, or when the selection runs from its start
# to its end. A heading with the lines under it is one block, and so is an
# item of a list with the lines indented under it. ⌘⇧V pastes the lines
# instead. A paste in the page that the block came from pastes its lines too,
# and so does a block that's cut, since a cut block leaves its page.

"The block that Ladder last copied whole: the text that it put on the clipboard, the lines of the page that the block is in, the block's lines and its first and last line"
const COPIED_BLOCK = Ref{Any}(nothing)

"Put `text` on the clipboard. A window that isn't on the screen keeps it to itself, so a test leaves the Mac's clipboard alone."
copy_text!(e, text) = (w = window_of(e); w === nothing ? clipboard(text) : clipboard!(w, text); text)

"Note what was just copied: `text`, from the selection `span` of the page of `e`. A whole block is kept, for a paste in another page."
copied!(e, span, text) = begin
  COPIED_BLOCK[] = nothing
  b = e.buf
  (span === nothing || b.view != :markdown || !isfile(b.path) || Eml.isemail(b.path)) && return nothing
  lo, hi = span
  s, t = lo[1], hi[1]
  hi[2] == 0 && t > s && (t -= 1)   # a selection that ends at the start of the next line
  # It starts no later than the first line's words start, and goes to the end of its last line
  (lo[2] <= kinds(b)[s].prefix && (hi[1] > t || hi[2] >= length(b.lines[t]))) || return nothing
  whole_node(b, s, t) === nothing && return nothing
  COPIED_BLOCK[] = (text=String(text), buf=b, lines=b.lines[s:t], first=s, last=t)
end

"""
The line that shows the block that Ladder last copied whole, when `text` is
what it copied and the page of `e` is another page, or nothing. The block
gets a name in its own page if it has none. Its page is saved then if it had
no other changes, so that a window that reads the page from its file finds the name.
"""
pasted_part(e, text) = begin
  c = COPIED_BLOCK[]
  (c !== nothing && c.text == text) || return nothing
  b, src = e.buf, c.buf
  (b.view == :markdown && !readonly(b) && !b.fixed && b.path != src.path && isfile(src.path)) || return nothing
  # The block is on the lines that it was copied from, or it's found again in its page
  s, t = c.first, c.last
  n = t - s
  if !(t <= length(src.lines) && src.lines[s:t] == c.lines)
    k = findfirst(i -> i + n <= length(src.lines) && src.lines[i:i+n] == c.lines, eachindex(src.lines))
    k === nothing && return nothing
    s, t = k, k + n
  end
  whole_node(src, s, t) === nothing && return nothing
  clean = !dirty(src)
  name = node_name!(src, s, t)
  clean && dirty(src) && save!(src)
  "![[$(page_name_for(e, src.path))#^$name]]"
end

"Put `link`, a line that shows a part of another page, on a line of its own: on the empty line that the caret is on, or under the block that it's in. The caret goes onto the part as a whole."
paste_part!(e, link) = begin
  b = e.buf
  selecting(b) && type!(e, "")
  i = b.caret[1]
  if isempty(strip(b.lines[i]))
    edit!(b, (i, 0), line_end(b, i), link)
  else
    under = block_end(b, i)
    after = under < length(b.lines) && !isempty(strip(b.lines[under+1])) ? "\n" : ""
    edit!(b, line_end(b, under), line_end(b, under), "\n\n" * link * after)
    i = under + 2
  end
  b.caret = b.anchor = (i, 0)
  focus(e)
  touch!(e)
end

"Paste what the clipboard holds as text: a block that was copied whole from another page goes in as a copy of its lines, not as a part of that page"
paste_copy!(e) = begin
  copied = COPIED_BLOCK[]
  COPIED_BLOCK[] = nothing
  try paste!(e) finally COPIED_BLOCK[] = copied end
end

"True when the Finder shows the folder at `path` as one file, as it shows an app"
ispackage(path) = with_pool() do
  ccall((:objc_msgSend, libobjc), Bool, (Ptr{Cvoid}, Ptr{Cvoid}, Ptr{Cvoid}),
        msg(cls("NSWorkspace"), "sharedWorkspace"), sel("isFilePackageAtPath:"), nsstring(path))
end

"""
Open a link. A file on the Mac shows in this editor, like a page, or a file
that came with an email. A folder on the Mac shows in the page, and the
sidebar lists it. Anything else opens in the app that the Mac uses for it. A path can start at the home folder, like `~/Mail`.
"""
follow!(e, url) = begin
  startswith(url, '^') && return follow_note!(e, url[2:end])
  in_browser(e.buf.path) && return follow_remote!(e, url)   # a link of a page from a web server is from the page's address
  target = wikitarget(url)
  target === nothing || return follow_wiki!(e, target)   # a wiki link, like [[Ideas]]
  go_lines!(e, url) && return e   # lines of a file, like main.jl#L12-L20
  occursin('#', url) && follow_heading!(e, url) && return e   # a heading of a page, like welcome.md#tables
  to = linked_file(e, url)
  to !== nothing && ispath(to[1]) && return show_path!(e, to[1])
  # The address of a page of Markdown on a web server shows in the window: see "a page from a web server"
  reads_here(e, url) && return get_page!(e, url, else_browser=true)
  # A site with a viewer of its own shows in the window too: see "a site with a viewer of its own"
  site_shows!(e, url) ? e : open_url(url)
end

"""
Show the file or the folder at `path` in the window, as a link to it does.
The sidebar lists the folder, and it stays as it was: open or closed. Only
you open it. A folder that the Finder shows as one file, like an app, opens as
that file does.
"""
show_path!(e, path) = begin
  hosted(e) === nothing || return show_path!(top_editor(e), path)   # a link in a part of another page shows in the window
  isfile(path) && return open!(e, path)
  (isdir(path) && !ispackage(path)) || return open_url(path)
  path = String(rstrip(path, '/'))
  # The folder's own page says its kind, and loads the code of the kind. It runs now if it hasn't, and
  # the rest goes on with that code.
  folder_pages!(path)
  Base.invokelatest(follow_folder!, e, path)
  e
end

"""
Do what a click on the folder at `path` does in the sidebar. A kind of folder
can show a page of its own, like a blog's Readme. When the click only lists the
folder in the sidebar, the page shows the folder too, so you see it with the
sidebar closed.
"""
follow_folder!(e, path) = begin
  folder_pages_tick!(e)   # the sidebar can have listed the folder before its page ran
  was = e.buf.path
  o = try object(e, path) catch; nothing end
  o isa AbstractDirectory ? open!(e, o) : go_folder!(e, path)
  # A blog's Readme that already showed is the folder's own page, so it stays
  e.buf.path == was && !on_own_page(e, o) && show_beside!(e, path)
  e
end

"True when the page shows the folder `o`'s own page, when that's a file in it, like a blog's Readme"
on_own_page(e, o) = false

drag!(e, pos) = begin
  scrubbing(e) && held(e, Keys.mouse_left) && return scrub_to!(e, pos)
  held(e, Keys.mouse_left) && e.clicked[3] == 1 || return
  at = settle(e.buf, locate(e, pos))
  at == e.buf.caret && return
  e.buf.caret = at
  touch!(e)
end

onkey(d::Document, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(d)
  done = press!(e, ev.window.mouse)
  # In what an agent said, once it's all said, the click puts the caret there. The pane under it would give the keyboard to the words that you type.
  owner_of(e) isa PaneReply && !e.buf.fixed ? handled : done
end
onkey(p::Page, ev::KeyPress{Keys.mouse_left}) = press!(editor(p), ev.window.mouse)
onmouse(d::Document, ev::MouseMove) = begin
  e = editor(d)
  Base.invokelatest(hover_check!, e, ev.position)
  # The window draws again as the mouse goes on to a footnote's number or off it, for its card: see `note_peek!`
  (note_peeked(e) || Base.invokelatest(note_at, e, ev.position) !== nothing) && redraw_in!(e, 0)
  drag!(e, ev.position)
end
onmouse(p::Page, ev::MouseMove) = drag!(editor(p), ev.position)
