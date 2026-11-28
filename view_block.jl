# The view of a `view` block: a view of another file
#
# A code block in the language `view` shows another file in the document, as
# the file is. Its line names the file:
#
#     ```view
#     plan.pdf
#     ```
#
# The name can be of a file or a folder beside the document, a path like
# ~/Desktop/plan.pdf, or the address of a page of the web. What shows depends
# on the kind of file:
#
#   - An HTML file and a page of the web show the page that their HTML makes,
#     and so does a block whose first line starts with a tag, like `<h1>`,
#     which holds the HTML itself. The page is yours to use where it is: see
#     "a page of the web". Its scripts read the document's sums.
#   - A Markdown page shows as it reads, a little smaller than the document.
#   - A picture, a model, a sound, a video, a PDF file, a CSV file, a zip, a
#     Word file, a font and a file of text show as they do under a path.
#   - A SolidCraft design shows alone, with none of its editor: you turn it,
#     and nothing changes it. The button that goes to the file shows the editor.
#   - A Julia file shows its code. A `result` block shows what the code comes
#     to: see "what code comes to".
#   - A folder shows the files and the folders in it. A click on one goes to it.
#
# While the mouse is over the block, two buttons show beside its top right
# corner. The first makes what the block shows fill the window, over the
# document: a page, a model, a video, a picture or a PDF file. The window goes
# to no other file, and Esc puts the document back. A view that would show no
# more that way, like a table, has only the second button. That one goes to the
# file: the window shows it, as a click on a link to it does, and ⌘⌥← comes
# back. A click on the block with ⌘ held does the same, and one with ⌥ held
# shows the block's line. An HTML file that you go to keeps the sums that
# the block gave its page, so the page there looks as it did in the document.
#
# A line like `aspect: 16:9` under the name sets the shape of a page, a model
# or a video: its width to its height. The view is as wide as the document's
# text, so it keeps that shape at any width of the window. `aspect: 2` is the
# same as `aspect: 2:1`. With no such line, a page is as tall as what it shows
# and a model is 260 pixels tall.

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" cursor redraw_in! MouseScroll
@use "github.com/jkroso/UI.jl/Interface/Semantic/STLViewer" STLViewer
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" VideoPlayer
@use "./html" html
@use "./markdown" words
@use "./sheet" shown
@use "./web/browser" => Browsers
@use "./remote" => Remote
@use "./cad/view" => Designs
@use "./look" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./blocks" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./linkcard_view" exports...
@use "./fill_view" exports...
@use "./file_view" exports...
@use "./live_view" exports...
@use "./webpage_view" exports...

export view_setting, view_parts, aspect_of, view_high, has_scheme, view_target, view_named, VIEW_COPIES,
       trail_steps, view_copy, view_coming, view_web, page_takes, view_crumb, view_fills, in_page,
       view_content, bare_view, how_many, design_sums, view_html, WebBlock

push!(BLOCK_ICONS, "eye", "arrow-up-right")

"A line of settings of a `view` block, like `aspect: 16:9`, or nothing for any other line"
view_setting(line) = match(r"^\s*(aspect)\s*:\s*(.*?)\s*$"i, line)

"""
The lines of a `view` block, `lines`, in two parts: those that name what it
shows, or hold its HTML, and its lines of settings. A line of HTML is no
setting, so the settings of a page that the block holds are above its first tag.
"""
view_parts(lines) = begin
  html = findfirst(l -> startswith(strip(l), '<'), lines)
  upto = html === nothing ? length(lines) : html - 1
  set = [i for i in 1:upto if view_setting(lines[i]) !== nothing]
  (source=String.(lines[setdiff(eachindex(lines), set)]), settings=String.(lines[set]))
end

"""
The width over the height that `text` says, like 16:9, 16/9, 2 or 1.5, or 0
when it says none.
"""
aspect_of(text) = begin
  m = match(r"^(\d+(?:\.\d+)?)\s*(?:[:/x×]\s*(\d+(?:\.\d+)?))?$", strip(text))
  m === nothing && return 0.0
  wide = parse(Float64, m[1])
  high = m[2] === nothing ? 1.0 : parse(Float64, m[2])
  wide > 0 && high > 0 ? wide / high : 0.0
end

"How tall a model or a video of the `view` or `result` block `v` is in the document `e`: as its line `aspect:` says, or `MODEL_HEIGHT`"
view_high(v, e) = v.aspect > 0 ? px(round(num(e.width) / v.aspect)) : MODEL_HEIGHT

"True when `name` is the address of a page of the web, or of anything with a scheme, and not a path on the Mac"
has_scheme(name::AbstractString) = occursin(r"^[a-z][a-z0-9+.-]*:"i, name)

"""
What the lines of a `view` block name: the whole path of a file or a folder,
or the address of a page of the web. A name with no / at its start is beside
the document, and one with ~ at its start is in the home folder. It's "" when
the block names nothing. A page from a web server names a file beside its own
address, and the block shows a copy of it: see `view_copy`.
"""
view_target(e, lines) = begin
  name = view_named(lines)
  isempty(name) && return ""
  in_browser(e.buf.path) && return view_copy(e, name)
  has_scheme(name) && return name
  path = abspath(docdir(e), expanduser(name))
  length(path) > 1 ? String(rstrip(path, '/')) : path
end

"The name that the lines of a `view` block give, as it's written, or \"\" when they give none"
view_named(lines) = (i = findfirst(l -> !isempty(strip(l)), lines); i === nothing ? "" : String(strip(lines[i])))

"""
Each file that a `view` block of a page from a web server names, by its
address: the `Remote.Coming` while it's on its way, then the path of its copy
on this Mac, or the `Remote.Answer` of a server that sent none. Ladder asks
for each file once while it's open, and again when you reload its page.
"""
const VIEW_COPIES = Dict{String,Any}()

"The names in the path to `path` in the top bar, each with where it goes, from the home folder or from a server's name"
trail_steps(path::AbstractString) = (at = web_address(path); isempty(at) ? steps(path, home_folder()) : Remote.trail(at))

"""
What a `view` block of a page of the browser folder that `e` shows names, when
the block names `name`: the file of the browser folder that keeps the file
`name` beside the page's web address. Until the file has come, `view_coming`
says why it isn't there. A page of HTML and a folder are the address itself,
which the block shows as a page of the web. It's "" for a name that's no
address on the web, like a path of the Mac, and for a page that runs no code.
"""
view_copy(e, name::AbstractString) = begin
  (foreign(e.buf.path) || sandboxed(e.buf.path)) && return ""
  url = remote_src(e, name)
  url === nothing && return ""
  named = basename(Remote.unescaped(Remote.path(url)))
  (isempty(named) || lowercase(splitext(named)[2]) in HTMLS) && return url
  file = browser_path(url)
  file === nothing && return ""
  view_coming(e, url, file)
  file
end

"""
Why the file at `file` of the browser folder, which keeps the file at the
address `url`, isn't there for the window of `e`, or nothing when it is. The
first time while Ladder is open, this asks the server for the file, when the
window may ask the web. A file that the browser folder has already shows while
it comes. What comes takes its place, unless you changed it.
"""
view_coming(e, url::AbstractString, file::AbstractString) = begin
  state = get(VIEW_COPIES, url, nothing)
  if state === nothing
    page_online(e) || return isfile(file) ? nothing : "Ladder gets $(basename(file)) when the window shows."
    state = VIEW_COPIES[url] = Remote.ask(url, getter=(a...) -> PAGE_GETTER[](a...))
  end
  if state isa Remote.Coming
    a = Remote.landed(state)
    a === nothing && (redraw_in!(e, 0.1); return isfile(file) ? nothing : "Getting $(basename(file)) from $(Remote.host(url))…")
    if Remote.ok(a)
      changed_here(file) || keep_got!(file, url, a.bytes) === nothing || redraw_in!(e, 0)
      state = VIEW_COPIES[url] = file
    else
      state = VIEW_COPIES[url] = a
    end
  end
  (state == file || isfile(file)) && return nothing
  state isa Remote.Answer && state.status == 404 && return "$(Remote.host(url)) has no $(basename(file))."
  "$(Remote.host(url)) didn't send $(basename(file))."
end

"What a tooltip calls the file or the page at `target`: its name, or the address of a page of the web"
view_name(target) = has_scheme(target) ? target : basename(target)

"True when the `view` block `v` shows a page that its HTML makes: of an HTML file, of the web, or that its lines hold"
view_web(v::ViewBlock) = v.held || !isempty(v.target) && (has_scheme(v.target) || lowercase(splitext(v.target)[2]) in HTMLS && isfile(v.target))

"""
True when the page of the `view` block `v` gets `ev`, a click, a turn of the
wheel or a pinch. A click with ⌘ or ⌥ held is the block's, and the wheel
scrolls the document unless ⌘ is held, as over a model. A page that fills
the window gets them all.
"""
page_takes(v::ViewBlock, ev) = zoomed_node(editor(v), v.browser) ? true :
                               ev isa MouseScroll ? only_held(ev, Keys.cmd) :
                               ev isa KeyPress ? !(only_held(ev, Keys.cmd) || only_held(ev, Keys.opt)) : true

"The Browser of the `view` block `v`, for an HTML file or a page of the web"
web_browser(v::ViewBlock) = begin
  v.browser === nothing || return v.browser
  e = editor(v)
  files = web_files(e)
  v.browser = own!(v, Browsers.Browser(files=files, open=url -> BROWSER[](url), takes=ev -> page_takes(v, ev)))
end

"The Breadcrumb that keeps what shows the file of `v` when it's no page of HTML: its model, its player, its text"
view_crumb(v::ViewBlock) = v.crumb === nothing ? (v.crumb = own!(v, Breadcrumb())) : v.crumb

reread!(v::ViewBlock, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  e = editor(v)
  v.source, v.settings = view_parts(lines)
  said = filter(!isnothing, view_setting.(v.settings))
  v.aspect = isempty(said) ? 0.0 : aspect_of(last(said)[2])
  src = web_source(e, v.source)
  v.held = !isempty(src.html)
  v.target = v.held ? "" : view_target(e, v.source)
  if view_web(v)
    b = web_browser(v)
    b.address, b.html, b.base = src
  elseif v.browser !== nothing
    # It showed a page before, and its scripts end with it
    v.browser = nothing
    v.sent = nothing
  end
  v
end

describe(v::ViewBlock) = begin
  e = editor(v)
  isempty(v.target) && !v.held &&
    return Column(block_look()..., name="View", block_note("Write the name of a file in this block, like plan.pdf, or the address of a page of the web"))
  # A page from a web server shows a copy of the file, which may still be on its way
  if !v.held && in_browser(e.buf.path) && !has_scheme(v.target)
    url = remote_src(e, view_named(v.source))
    why = url === nothing ? nothing : view_coming(e, url, v.target)
    why === nothing || return Column(block_look()..., name="View", block_note(why))
  end
  v.held || has_scheme(v.target) || ispath(v.target) ||
    return Column(block_look()..., name="View", block_note("$(basename(v.target)) isn't there"))
  with_theme(component_theme(e.zoom)) do
    content = view_content(v, e)
    fills = view_fills(v, e)
    # A page that the block holds is in no file, so it has no button that goes to one: its one button makes it fill the window
    f = v.held ? fillable(v, fills, content, wide=:grow) : fillable(v, (:go, v.target), content, wide=:grow)
    v.held || (f.also = fills)
    Box(width(grow=grow), Alignment.Start, f)
  end
end

"""
What fills the window when you click the first button beside the `view` block
`v`: its page of the web, its model, its video, its picture or its PDF file.
The window shows it over the document, and goes to no other file, so Esc puts
the document back as it was. It's nothing for a view that would show no more
with the window to itself, like a table, a page of Markdown or a folder: the
button that goes to the file shows the whole of those.
"""
view_fills(v::ViewBlock, e) = begin
  view_web(v) && return (:node, web_browser(v))
  l = v.crumb
  l === nothing && return nothing
  # What the file shows under a path has a Fillable of its own, with no button while it's in a view
  for owner in (l, l.viewer)
    f = owner === nothing ? nothing : get(fills(e), objectid(owner), nothing)
    f === nothing || f.what === nothing || return f.what
  end
  nothing
end

"`node`, or the empty room that the page keeps for it while it fills the window"
in_page(e, node) = node isa SemanticUI && zoomed_node(e, node) ? held_room(e) : node

"What shows in the `view` block `v`: the page that an HTML file makes, the list of a folder, or what any other file shows under a path"
view_content(v::ViewBlock, e) = begin
  if view_web(v)
    b = web_browser(v)
    send_sums!(v)
    # A page in a block is dark in a dark page, as a frame in a browser takes the colour scheme of the page that it's in
    b.dark = dark_page()
    # While the page fills the window, the window says how big it is
    zoomed_node(e, b) && return held_room(e)
    b.zoom = round(Float64(e.zoom), digits=2)
    b.wide = e.width - 2px
    p = b.view.page
    # Until a page has come, the block is as tall as it's likely to be with one
    b.high = v.aspect > 0 ? px(round(num(b.wide) / v.aspect)) :
             p === nothing || isempty(b.view.html) ? WEB_HIGH * e.zoom : clamp(px(p.tall), WEB_LEAST * e.zoom, WEB_HIGH * e.zoom)
    return Column(block_look()..., clip=true, name="Web page", b)
  end
  l = view_crumb(v)
  path = v.target
  if isdir(path)
    l.at = path
    names = listing(path)
    folders = count(n -> isdir(joinpath(path, n)), names)
    held = filter(!isempty, [how_many(length(names) - folders, "file"), how_many(folders, "folder")])
    about = isempty(held) ? basename(path) : basename(path) * "  ·  " * join(held, " and ")
    return Column(block_look()..., padding(6px), child_gap=1px, name="View", contents(l)...,
                  Box(padding(10px, 6px, 0px, 10px), label(about, 12px, color=colours.dim)))
  end
  # A player that was made for another file stops when the block names another
  l.viewer !== nothing && l.viewer.path != path && (hush!(l); l.viewer = nothing)
  l.at = path
  # What could fill the window is found again in each frame, so that a file of another kind leaves none behind: see `view_fills`
  for owner in (l, l.viewer)
    inner = owner === nothing ? nothing : get(fills(e), objectid(owner), nothing)
    inner === nothing || (inner.what = nothing)
  end
  about = basename(path) * "  ·  Changed " * Libc.strftime("%-d %b %Y, %H:%M", mtime(path))
  # A SolidCraft design takes the page's numbers whose names its parameters have. It has them before it opens.
  lowercase(splitext(path)[2]) in DESIGNS && Designs.give!(design(l, path), design_sums(e))
  content = try
    peek(l, path, lowercase(splitext(path)[2]), words -> (about *= "  ·  " * words))
  catch
    nothing
  end
  content === nothing && (content = label("This file has no preview", 12px, color=colours.dim))
  # A model or a video is as tall as the block's line `aspect:` says, except while it fills the window
  (l.viewer isa STLViewer || l.viewer isa VideoPlayer || l.viewer isa Designs.DesignView) && !zoomed_node(e, l.viewer) && (l.viewer.height = view_high(v, e))
  # A model in a view has no line under it, as it has under a path: the model is all that shows
  l.viewer isa STLViewer && (l.viewer.foot = false; return bare_view(content))
  # A SolidCraft design is the same: the design is all that shows
  l.viewer isa Designs.DesignView && return bare_view(content)
  Column(block_look()..., padding(6px), child_gap=8px, name="View", content, Box(padding(4px, 0px), label(about, 12px, color=colours.dim)))
end

"""
A `view` block that shows only `content`, the viewer of a model. The viewer
has a frame of its own, so the block adds none round it. It names no file
either: the model is all that shows.
"""
bare_view(content) = Column(width(grow=grow), Alignment.Start, name="View", content)

"`n` things of a kind, like 3 files or 1 folder, or nothing when there are none"
how_many(n, thing) = n == 0 ? "" : "$n $thing$(n == 1 ? "" : "s")"

"""
The numbers of the document of `e` that a SolidCraft design in a `view` block
gets: those that the scripts of a page get, in SI units. They're read again
only when the sums may have changed.
"""
design_sums(e) = begin
  key = (:design_sums, e.buf.path)
  had = get(e.nodes, key, nothing)
  had !== nothing && had[1] == sums_run[] && return had[2]
  sums = script_sums(e)[1]
  e.nodes[key] = (sums_run[], sums)
  sums
end

own_button(::ViewBlock) = true

"""
Show the file of the `view` block `v` in the window, as a click on a link to
it does. ⌘⌥← comes back. An HTML file there keeps the sums that the block gave
its page: see `carry_sums!`.
"""
go_view!(v::ViewBlock) = begin
  e = top_editor(editor(v))
  to = v.target
  isempty(to) && return handled
  # A page of Markdown or of HTML on a web server shows in the window, and anything else in your browser
  has_scheme(to) && return (Remote.isaddress(to) && page_online(e) ? get_page!(e, to, else_browser=true) : BROWSER[](to); handled)
  ispath(to) || return handled
  sent = v.sent
  show_path!(e, to)
  if sent !== nothing && e.buf.path == to && html_shown(e)
    e.nodes[(:carried_sums, to)] = (sums=sent[3], shown=sent[4], page=html_part(e), given=nothing)
  end
  handled
end



# When a link goes to another page, the block's line changes to say it. It changes once the view has read the line:
# until then, the line is what the view goes by.
block_tick!(v::ViewBlock) = begin
  b = v.browser
  (b === nothing || v.lines === nothing || !view_web(v)) && return v
  page = Browsers.page_now(b)
  (page === nothing || b.asked != (b.address, b.html, b.base)) && return v
  e = editor(v)
  (readonly(e.buf) || e.buf.fixed || web_says(e, v.source, page)) && return v
  # The block's settings stay. Those of a page that the block holds stay above its HTML.
  said = web_lines(e, page)
  write_block!(v, v.lang, page isa Browsers.Written ? vcat(v.settings, said) : vcat(said, v.settings))
  # The view is at that page already, so it doesn't get it again
  view_web(v) && v.browser === b && Browsers.asked!(b)
  v
end

cursor(v::ViewBlock) = :arrow

# A click with ⌘ held goes to the file. The rest are the page's or the viewer's, or go on to the document, which picks
# the block, or shows its line with ⌥ held.
onkey(v::ViewBlock, ::KeyPress{Keys.mouse_left}) = only_held(v, Keys.cmd) ? go_view!(v) : nothing

# Esc gives the keyboard back to the document, once no field of the page has it. A page that fills the window goes
# back into the document.
onkey(v::ViewBlock, ev::KeyPress{Keys.escape}) = begin
  unmodified(ev) || return nothing
  (v.browser !== nothing && ev.window.focus === v.browser) || return nothing
  e = editor(v)
  zoomed_node(e, v.browser) && return zoom_out!(zooming(e))
  focus(e)
  handled
end

keyboard_part(v::ViewBlock) = view_web(v) ? web_browser(v) : v.crumb !== nothing && v.crumb.viewer isa Pages ? v.crumb.viewer : nothing

"The `view` block as HTML: the page that it holds, in a frame, the picture that it shows, or a link to its file or its page"
view_html(e, v::ViewBlock) = begin
  if v.held
    held = replace(join(v.source, "\n"), '&' => "&amp;", '"' => "&quot;")
    shape = v.aspect > 0 ? "aspect-ratio:$(v.aspect)" : "height:$(round(Int, num(WEB_HIGH)))px"
    return "<iframe srcdoc=\"$held\" style=\"width:100%;$shape;border:1px solid #d8d2c8;border-radius:8px\"></iframe>"
  end
  isempty(v.target) && return nothing
  name = has_scheme(v.target) ? Browsers.whole(v.target) : String(strip(v.source[findfirst(l -> !isempty(strip(l)), v.source)]))
  shown = replace(name, '&' => "&amp;", '<' => "&lt;", '>' => "&gt;", '"' => "&quot;")
  ispicture(v.target) && return "<p><img src=\"$shown\" style=\"max-width:100%\"></p>"
  "<p><a href=\"$shown\">$shown</a></p>"
end

BLOCKS[VIEW_BLOCK] = ViewBlock
block_name(::Type{ViewBlock}) = "View"
block_icon(::Type{ViewBlock}) = "eye"
block_insert(::Type{ViewBlock}) = ("View", ["```$VIEW_BLOCK", "", "```"], (2, 0))
block_html(e, v::ViewBlock) = view_html(e, v)
# A block in the language `web` is a view by the name that it had before. It writes its line back in its own language.
struct WebBlock end
BLOCKS[WEBVIEW] = WebBlock
block_name(::Type{WebBlock}) = "View"
block_icon(::Type{WebBlock}) = "eye"
block_make(::Type{WebBlock}, n::Int) = ViewBlock(n=n, lang=WEBVIEW)
