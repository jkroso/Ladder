# Live blocks: a `ui` code block shows what its code made, and the files that it shows
#
# A code block in the language `ui` holds Julia code. The page runs it once and
# shows its value where the block is: a UI node from any module, or any other
# value as text. The node is kept, so a node with state keeps it between frames.
# The code runs in the page's module, as the page's `julia` blocks do, so the
# two kinds of block share their names: see `page_module`.
#
# The code can use the names that pages use most with no line that loads them:
# UI.jl's components, like Slider and STLViewer, the parts of a layout, like
# Column and px, a file path as fs"notes.md" and a colour as colorant"tomato".

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI GeometricUI with_theme adopt_theme! describe reuse! detach! window_of handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! rect popup! close_popup!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/STLViewer" STLViewer Mesh load!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" AudioPlayer VideoPlayer pause!
@use "../code/highlight" tokens left_open
@use "./sheet" parts shown
@use "../term/view" => Terms
@use "../cad/view" => Designs
@use "../folders/folders" => Folders
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "../base" exports...
@use "../additions" exports...
@use "./sketch_view" exports...
@use "../files/file_view" exports...
@use "../term/terminal_view" term_look!
@use "../window/fill_view" fill_what fill_wide zoomed_node held_room square_button

export USUAL, share!, reads!, default_app!, text_size!, NARROWEST, WIDEST, page_width!, font!, weight!,
       problems, present, present_inline, note, redescribe!, swap!, OpenButton, Listing, list!, MOST_FILES,
       entry, steps, listing, contents, CRUMB_GAP, ARROW_W, DOTS_W, LONGEST_NAME, short, fitting,
       MODEL_HEIGHT, TEXT_OPENS, codeline, DefaultAsked, RunningBlock

"The modules whose names a live block can use with no line that loads them"
const USUAL = ("github.com/jkroso/UI.jl/Interface/Semantic", "github.com/jkroso/UI.jl/Interface/Geometric")

"Give the module `m` each name that the module at `path` exports"
share!(m, path) = begin
  from = include_string(m, "@use $(repr(path))")
  # The module can be new, so its names are asked for as they are now
  for name in Base.invokelatest(names, from)
    # A menu and a tree each have an Item, so a block loads the one it means
    (name == nameof(from) || name == :Item) && continue
    Core.eval(m, :(const $name = $(Base.invokelatest(getglobal, from, name))))
  end
end

"The live block of a window's page that runs now"
@def mutable struct RunningBlock
  key::Any = nothing   # the key of what the block makes in the window's nodes, or nothing while no block runs
end

"""
Note that the live block that's running now asked for a setting of the page:
`:theme`, `:zoom` or `:font`. Such a block is run again when the setting changes, so
what it shows stays true.
"""
reads!(e, setting::Symbol) = begin
  key = state_of(e, RunningBlock).key
  key === nothing || push!(get!(() -> Set{Any}(), e.nodes, (:readers, setting)), key)
  nothing
end

"The answer that the window waits for, after it asked macOS to make Ladder the app that opens Markdown files: see `default_app!` and `await_default!`"
@def mutable struct DefaultAsked
  asked::Union{Nothing,Tuple{Float64,Any,Float64}} = nothing   # when it asked, the app that opened them then, and when the window last looked
end

"""
Ask macOS to make Ladder the app that opens Markdown files, for the button on
the settings page. macOS asks you to confirm, so the window then looks for
your answer. It's false when the Ladder app isn't installed.
"""
default_app!(e) = begin
  before = markdown_app()
  make_default!() || return false
  state_of(e, DefaultAsked).asked = (time(), before, time())
  true
end

"Run again the live blocks that asked for `setting`"
rerun!(e, setting::Symbol) = foreach(pop!(e.nodes, (:readers, setting), ())) do key
  # What the block made before is kept until it runs again, so that what it makes then can
  # carry on from it, like a chooser whose choice was clicked sliding to it
  old = pop!(e.nodes, key, nothing)
  old === nothing || (e.nodes[(:replaced, key)] = old)
end

"""
Wrap the page's text again, for a live block that changed a setting. The block
under the mouse stays where it is in the window, so a slider that's being
dragged doesn't move up or down, away from the mouse.
"""
rewrap!(e) = begin
  save_settings!(e)
  empty!(e.flows)
  win = window_of(e)
  if win !== nothing && !isempty(e.layout)
    y = win.mouse[2] - above_page(e) - PAGE_TOP + e.scroll.offset
    i = findfirst(it -> it.top <= y < it.top + it.tall, e.layout)
    i === nothing || hold!(e, e.layout[i].first, e.layout[i].top - e.scroll.offset)
  end
  e
end

"Make the page's text `size` pixels tall, for a live block or the command palette. Sizes are from 11 to 42."
text_size!(e, size::Real) = (e.zoom = zoom_for(size); rewrap!(e))
add_command!(text_size!, title="Make the page's text a number of pixels tall")

const NARROWEST, WIDEST = 400, 1200   # the page widths that the settings page offers

"""
Make the page `width` pixels wide, to the nearest ten, for a live block. That's
its width while the text is its usual size: bigger text gets a wider page, so
a line holds as many words as before. A window that's too narrow for the page
shows it as wide as it can.
"""
page_width!(e, width) = (e.widest = px(clamp(10round(Int, width / 10), NARROWEST, WIDEST)); rewrap!(e))

"Draw the page's text in the font called `name`"
font!(e, name::String) = (e.font = name; save_settings!(e); rerun!(e, :font); restyle!(e))

"Draw the page's text in the weight called `w`, like \"Light\", or in the weight `w`, like 300"
weight!(e, w::Union{Integer,AbstractString}) = begin
  e.weight = w isa Integer ? text_weight(w) : weight_called(e.font, w)
  save_settings!(e)
  rerun!(e, :weight)
  restyle!(e)
end

"Use the colours called `name` for the page"
theme!(e, name::Symbol) = begin
  name in THEME_ORDER || error("The page's colours are Sepia, Paper and Night. $name isn't one of them.")
  e.theme = name
  save_settings!(e)
  rerun!(e, :theme)
  restyle!(e)
end

# The errors of the live blocks that failed. The app's self-test reads it, to check its own pages.
const problems = String[]

"""
Run the code of a live block and return a UI node that shows its value, or its
error. `key` is where the editor keeps what the code made. With `inline`, the
code is in a line of text: a value that isn't a node comes back as its text,
with true if the text says what went wrong.
"""
evaluate(e, code::String; key=(:live, e.buf.path, code), inline=false) = begin
  path = e.buf.path
  # The code can load the drawing methods of a node, and the frame that runs it
  # can't call them yet. So the window draws one more frame soon after.
  one_more_frame!(e)
  state_of(e, RunningBlock).key = key
  try
    # Kip finds a path like "./widgets.jl" from the folder of the document, and so does a relative FSPath
    cd(isdir(docdir(e)) ? docdir(e) : pwd()) do
      # The code runs in the page's module, with the page's other code
      value = running_code(m -> (inline ? run_sum : run_in)(m, code, isempty(path) ? joinpath(e.folder, "untitled.md") : path), e)
      node = inline ? present_inline(value) : present(value)
      # Keep the amount, with its unit, so a chart can read that and not the words around it
      inline && node === nothing && length(key) == 4 && (e.nodes[(:amount, key[2], key[3], key[4])] = value)
      node !== nothing ? node : inline ? (said(value), false) : note(repr("text/plain", value), colours.ink)
    end
  catch err
    err = err isa LoadError ? err.error : err
    inline && length(key) == 4 && delete!(e.nodes, (:amount, key[2], key[3], key[4]))
    push!(problems, sprint(showerror, err))
    # A line of text has room for the first line of what went wrong
    inline ? (said(first(split(sprint(showerror, err), '\n'))), true) : note(sprint(showerror, err), colours.accent)
  finally
    state_of(e, RunningBlock).key = nothing
    CODE_RUNS[] += 1   # the page's `check` blocks run again
  end
end

"""
The node that shows `value` in a live block, or nothing to show it as text. Add
a method to show a type of your own as a node.
"""
present(value) = nothing
present(node::Union{SemanticUI,GeometricUI}) = node
# Text on its own goes in a box as wide as the page, so that it wraps and takes the page's colours
present(text::Text) = Box(width(grow=grow), Alignment.Start, text)
present(p::FSPath) = begin
  path = abspath(string(p))
  path = ispath(path) ? realpath(path) : path
  Breadcrumb(at=length(path) > 1 ? String(rstrip(path, '/')) : path)
end

"""
The node that shows `value` in a line of text, for inline code, or nothing to
show it as text. It's what a live block shows, unless a type has a method here.
"""
present_inline(value) = present(value)
present_inline(text::Text) = Box(Alignment.Start, text)
# A file path in a line of text is as wide as its names. Its list floats under it.
present_inline(p::FSPath) = (l = present(p); l.inline = true; l)

note(text, colour) = Box(width(grow=grow), padding(BLOCK_X, 10px), background(colours.block),
  Text(String(text), size=13px, family=codefont(), subfamily=codestyle(), color=colour))

cursor(::Shown) = :arrow

# A drag that starts in a live block is the block's. The page's text doesn't select as the mouse moves.
onmouse(s::Shown, ::MouseMove) = held(s, Keys.mouse_left) ? handled : nothing

# The components in the block get the page's colours
describe(s::Shown) = begin
  e = editor(s)
  t = component_theme(e.zoom)
  was, s.was = s.was, t
  with_theme(t) do
    # A diagram, a model and a video have a button that makes them fill the window. One that fills it leaves its room here empty.
    what = s.inline ? nothing : fill_what(s.value)
    what !== nothing && what[1] == :node && zoomed_node(e, s.value) && return Column(width(grow=grow), Alignment.Start, held_room(e))
    inner = s.value isa SemanticUI ? Base.invokelatest(convert, GeometricUI, s.value) : redescribe!(detach!(s.value), t, was)
    what === nothing || (inner = fillable(s, what, inner, wide=fill_wide(s.value)))
    s.inline ? Row(width(grow=grow), Alignment.Center, inner) : Column(width(grow=grow), Alignment.Start, inner)
  end
end

# What inline code made can float a list over the page, as a file path does. A
# click in that list is the list's, so it stops here, before the page's text sees it.
onkey(s::Shown, ev::KeyPress{Keys.mouse_left}) = begin
  s.inline || return nothing
  r = rect(s)
  x, y = ev.window.mouse
  r !== nothing && r.left <= x < r.left + r.width && r.top <= y < r.top + r.height ? nothing : handled
end

"""
Describe again each semantic node in `geo`, and put the new geometry where the
old geometry was. Text that has the colours of the theme `was` gets the colours of `t`.
"""
redescribe!(geo, t, was) = begin
  child = geo.firstchild
  while child !== nothing
    next = child.nextsibling
    if child isa GeometricUI && child.from isa SemanticUI
      new = Base.invokelatest(convert, GeometricUI, child.from)
      new === child || swap!(child, new)
    elseif child isa GeometricUI
      redescribe!(child, t, was)
    elseif child isa Text
      adopt_theme!(child, t, was)
    end
    child = next
  end
  geo
end

"Put `new` in the place of `old` among its siblings"
swap!(old, new) = begin
  parent, prev, next = old.parent, old.prevsibling, old.nextsibling
  detach!(new)
  setfield!(new, :parent, parent)
  setfield!(new, :prevsibling, prev)
  setfield!(new, :nextsibling, next)
  prev === nothing ? setfield!(parent, :firstchild, new) : setfield!(prev, :nextsibling, new)
  next === nothing || setfield!(next, :prevsibling, new)
  setfield!(old, :parent, nothing)
  setfield!(old, :prevsibling, nothing)
  setfield!(old, :nextsibling, nothing)
  new
end

# --- files in a live block ---------------------------------------------------------------
#
# An FSPath shows as a breadcrumb: the name of each folder on the way to it,
# in a row. Click the last name to list what's in that folder under the
# breadcrumb, and click an earlier name to go to that folder. A click on a
# line of the list makes that file or folder the path, so its name joins the
# breadcrumb. The Open button, a square at the right end of the names, shows the file in
# the window, or the folder in the sidebar, as a link to it does. A click with ⌘
# held on a name or on a line of the list does the same for that file or folder.
# A breadcrumb in a line of text has no Open button, but a click with ⌘ held works.
# Under a path to a file is a preview of the file:
#
#   - a picture, of any kind that Skia or macOS reads
#   - the model in an STL or 3MF file
#   - a player for a sound or a video file
#   - the pages of a PDF file, one at a time
#   - a CSV file as a table, and the list of the files in a zip
#   - a Markdown file as it reads
#   - the text of any other text file, which the wheel scrolls through. The lines
#     of a file of code have the colours that a code block gives them.
#   - the picture that the Finder shows, for a file like a Word file or a font
#
# A sound or a video plays on while you scroll the page and type in it. It stops
# when the path goes to another file, when the preview closes and when the window
# shows another page.

"The button at the right end of a breadcrumb's names that shows its file or its folder in the window. It shows while the mouse is over the breadcrumb."
@def mutable struct OpenButton <: SemanticUI
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
end

"The list or the preview under a breadcrumb that's in a line of text. It floats over the page."
@def mutable struct Listing <: SemanticUI
  of::Any = nothing   # the Breadcrumb
end

describe(f::Listing) =
  Column(width(grow=grow), Alignment.Start, padding(6px), radius(8px), background(colours.block), border(1px, :solid, colours.line),
         lifted, child_gap=1px, contents(f.of)...)

"Show the list of a breadcrumb that's in a line of text when it's open, and take the list away when it isn't"
list!(l::Breadcrumb, w) = begin
  w === nothing && return
  l.open || return close_popup!(w, :listing)
  e = editor(l)
  popup!(w, Listing(of=l), anchor=l, gap=4px, width=min(LISTING_W, e.width), key=:listing, onclose=() -> (l.open = false),
         theme=component_theme(e.zoom))
end

const MOST_FILES = 100

entry(l::Breadcrumb, path) = get!(() -> own!(l, FileEntry(path=path)), l.entries, path)

"The name and the path of each step on the way to `path`. The home folder `home` is one step, named ~."
steps(path, home=homedir()) = begin
  inside = path == home || startswith(path, home * "/")
  at = inside ? home : "/"
  out = [(inside ? "~" : "/", at)]
  for name in splitpath(relpath(path, at))
    name == "." && continue
    at = joinpath(at, name)
    push!(out, (name, at))
  end
  out
end

"The files and folders in `dir` that aren't hidden or ignored, folders first"
listing(dir) = begin
  ignored = Folders.ignored()
  names = try filter(n -> !left_out(joinpath(dir, n), ignored), readdir(dir)) catch; String[] end
  sort!(names, by=n -> (!isdir(joinpath(dir, n)), lowercase(n)))
end

describe(l::Breadcrumb) = begin
  l.open || hush!(l)
  names = [get!(() -> own!(l, Crumb(path=path, name=name)), l.crumbs, path) for (name, path) in steps(l.at)]
  arrow() = Icon("chevron-right", size=9px, color=colours.faint)
  # The first name and as many of the last names as fit. An … stands for the names left out.
  # An open breadcrumb that isn't in a line of text is in a panel with what's under it, so it has less room
  panel = l.open && !l.inline
  # A path to a file or a folder has a button at the right end of its names that shows it in the window.
  # The button shows only while the mouse is over the breadcrumb. Its room is kept, so the names don't move.
  # A breadcrumb in a line of text has no room for it: a click with ⌘ held does the same.
  opens = !l.inline && !l.folders && l.files === nothing && ispath(l.at)
  opens && l.button === nothing && (l.button = own!(l, OpenButton()))
  n = fitting(map(wide, names), something(l.room, editor(l).width) - (panel ? 2PANEL_PAD : 0px) - (opens ? FILL_SIDE + 2CRUMB_GAP : 0px))
  kept = n < length(names) - 1 ? Any[names[1], Box(width(DOTS_W), label("…", color=colours.dim)), names[end-n+1:end]...] : names
  parts = Iterators.flatten(i == 1 ? (c,) : (arrow(), c) for (i, c) in enumerate(kept))
  l.inline && return Row(height(24px), child_gap=CRUMB_GAP, clip=true, parts...)
  trail = Row(width(grow=grow), height(30px), child_gap=CRUMB_GAP, clip=true, parts...,
              (opens ? (Box(width(grow=grow)), ishovered(l) ? l.button : Box(width(FILL_SIDE), height(FILL_SIDE))) : ())...)
  panel || return Column(width(grow=grow), Alignment.Start, trail)
  # One background goes round the names and what's under them, to show that they're one thing
  Column(width(grow=grow), Alignment.Start, padding(PANEL_PAD), radius(8px), background(colours.block), child_gap=1px,
    trail, contents(l)...)
end

"What shows under an open breadcrumb: the lines of a folder, or the preview of a file"
contents(l::Breadcrumb) = begin
  l.folders && !isdir(l.at) &&
    return (Row(width(grow=grow), height(26px), padding(10px, 0px), label("This folder isn't made yet", 12px, color=colours.dim)),)
  isdir(l.at) || return (preview(l, l.at),)
  hush!(l)
  l.viewer = l.text = nothing
  names = listing(l.at)
  l.folders && filter!(n -> isdir(joinpath(l.at, n)), names)
  l.files === nothing || filter!(n -> isdir(joinpath(l.at, n)) || l.files(n), names)
  shown = first(names, MOST_FILES)
  isempty(names) && return (Row(width(grow=grow), height(26px), padding(10px, 0px),
                                label(l.files === nothing ? "This folder is empty" : "This folder has no file of the kind to choose", 12px, color=colours.dim)),)
  ((entry(l, joinpath(l.at, n)) for n in shown)...,
   (length(names) > length(shown) ? (Row(width(grow=grow), height(26px), padding(10px, 0px),
      label("and $(length(names) - length(shown)) more", 12px, color=colours.dim)),) : ())...)
end

const CRUMB_GAP = 2px
const ARROW_W = 9px
const DOTS_W = 18px
const LONGEST_NAME = 28   # characters. A longer name loses its middle.

"A name with its middle left out if it's long, like 8ebf6aee-d8a…e60dbee0e511"
short(name) = length(name) <= LONGEST_NAME ? name :
  first(name, LONGEST_NAME ÷ 2 - 1) * "…" * last(name, LONGEST_NAME ÷ 2)

"How wide a name of a breadcrumb is. The last name is bold and has an icon."
wide(c::Crumb) = begin
  last = c.path == (c.parent::Breadcrumb).at
  measure(Face(SANS, last ? "Semibold" : "", 13px, colours.ink, false), short(c.name)) + 12px + (last ? 19px : 0px)
end

"How many of the last names fit in `room` after the first name, when an … stands for the rest"
fitting(widths, room) = begin
  step = ARROW_W + 2CRUMB_GAP
  sum(widths) + step * (length(widths) - 1) <= room && return length(widths) - 1
  used = widths[1] + step + DOTS_W
  n = 0
  for w in Iterators.reverse(widths[2:end])
    used += step + w
    used > room && n > 0 && break
    n += 1
  end
  min(n, length(widths) - 2)
end

describe(c::Crumb) = begin
  l = c.parent::Breadcrumb
  last = c.path == l.at
  Row(height(24px), padding(6px, 0px), radius(5px), child_gap=6px,
      background(last && l.open ? colours.active : ishovered(c) ? colours.hover : clear),
    (last ? (Icon(l.folders || isdir(c.path) ? "folder" : file_icon(c.path), size=13px, color=colours.dim),) : ())...,
    Box(label(short(c.name), color=last ? colours.ink : colours.dim, weight=last ? "Semibold" : "")))
end

cursor(::Crumb) = :hand

# The last name shows and hides the list. An earlier name goes to its folder.
onkey(c::Crumb, ev::KeyPress{Keys.mouse_left}) = begin
  l = c.parent::Breadcrumb
  # In a line of text, a click with ⌥ held shows the code and leaves the path as it is
  l.inline && only_held(c, Keys.opt) && return nothing
  only_held(c, Keys.cmd) && !l.folders && return show_crumb!(l, c.path, ev.window)
  c.path == l.at ? (l.open = !l.open) : (l.at = c.path; l.open = true)
  l.inline && list!(l, ev.window)
  nothing
end

# It looks like the button that makes a picture fill the window, as it also shows one thing in the whole window
describe(b::OpenButton) = begin
  ishovered(b) || (b.quiet = false)
  square_button("arrows-fullscreen", ishovered(b))
end

cursor(::OpenButton) = :hand
draw(ctx, size, ui::ConcreteRect, b::OpenButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::OpenButton, ev::MouseMove) = begin
  b.quiet && return handled
  tip = isdir((b.parent::Breadcrumb).at) ? "Show this folder in the window" : "Show this file in the window"
  show_tooltip!(ev.window, tip_label(tip), b.rect..., placement=:bottom, gap=6px)
  handled
end

onkey(b::OpenButton, ev::KeyPress{Keys.mouse_left}) = begin
  b.quiet = true
  hide_tooltip!(ev.window)
  l = b.parent::Breadcrumb
  show_crumb!(l, l.at, ev.window)
end

"""
Show the file or the folder at `path` in the window, as the path in the top
bar does. The breadcrumb `l` holds the path. When it's in a line of text, its
list closes first. A breadcrumb in a part of another page shows it in the window too.
"""
show_crumb!(l::Breadcrumb, path, window) = begin
  l.inline && l.open && (l.open = false; list!(l, window))
  open_folder!(top_editor(editor(l)), path)
  handled
end

describe(r::FileEntry) = begin
  folder = isdir(r.path)
  Row(width(grow=grow), height(26px), padding(10px, 0px), radius(5px), child_gap=8px, clip=true,
      background(ishovered(r) ? colours.hover : clear),
    Icon(folder ? "folder" : file_icon(r.path), size=13px, color=colours.dim),
    Box(width(grow=grow), Alignment.Start, label(basename(r.path))),
    (folder ? () : (Box(label(bytes(filesize(r.path)), 12px, color=colours.dim)),))...)
end



const MODEL_HEIGHT = 260px
"The viewer of the model in the STL, 3MF or glTF file at `path`, or nothing if the file can't be read as a model"
model(l::Breadcrumb, path) = begin
  v = l.viewer
  (v isa STLViewer && v.path == path) || (hush!(l); v = l.viewer = own!(l, STLViewer(path=path, height=MODEL_HEIGHT)))
  load!(v) isa Mesh ? v : nothing
end

"The player of the sound or the video file at `path`. `Player` is AudioPlayer or VideoPlayer."
player(l::Breadcrumb, path, Player) = begin
  v = l.viewer
  (v isa Player && v.path == path) && return v
  hush!(l)
  l.viewer = own!(l, Player === VideoPlayer ? VideoPlayer(path=path, height=MODEL_HEIGHT) : AudioPlayer(path=path))
end

"Stop the sound or the video that the breadcrumb's player is playing, and end the program of a SolidCraft design that it shows"
hush!(l::Breadcrumb) = (l.viewer isa Union{AudioPlayer,VideoPlayer} && pause!(l.viewer); l.viewer isa Designs.DesignView && Designs.close!(l.viewer); l)

"""
What shows the SolidCraft design at `path` under a path and in a `view` block:
the design alone, which you turn and nothing changes. The file's own page is
the editor: see "a SolidCraft design".
"""
design(l::Breadcrumb, path) = begin
  v = l.viewer
  (v isa Designs.DesignView && v.path == path) && return v
  hush!(l)
  l.viewer = own!(l, Designs.DesignView(path=path, readonly=true, fill=false, height=MODEL_HEIGHT))
end

"""
What shows the terminal's file at `path` under a path and in a `view` block:
the last lines that the file keeps, in their colours. No shell starts there.
The file's own page is the terminal: see "a terminal's file".
"""
terminal(l::Breadcrumb, path) = begin
  v = l.viewer
  (v isa Terms.TerminalView && v.path == path) || (hush!(l); v = l.viewer = own!(l, Terms.TerminalView(path=path, shown=true)))
  e = editor(l)
  term_look!(v, e)
  # As tall as its lines, and no taller than a model
  t = Terms.terminal(v)
  lines = something(findlast(!Terms.Screens.isblank, Terms.Screens.everything(t)), 1)
  v.wide = max(e.width - 12px, 120px)
  v.high = min(MODEL_HEIGHT, px(lines * Terms.cell(v)[2] + 2Terms.PAD))
  v
end







"For each line of a file's text, the quote of a docstring that's open at its start, or '\\0', worked out once for each FileText"
const TEXT_OPENS = WeakKeyDict{FileText,Vector{Char}}()

"The text of a file. `lang` is the end of the file's name, like jl."
textview(t::FileText, lang) = begin
  at = get!(() -> (q = '\0'; [(o = q; q = left_open(l, lang, q); o) for l in t.lines]), TEXT_OPENS, t)
  scrolled(i -> codeline(t.lines[i], lang, at[i]), t.scroll, length(t.lines))
end

"""
One line of a file's text. A file of code has the colours that a code block
has: `lang` is the end of the file's name, like jl, and a file that isn't code
is all one colour. `open` is the quote of a docstring that's open at the start
of the line, or '\\0'.
"""
codeline(line, lang, open='\0') = Row(height(LINE_H),
  [part for t in tokens(line, lang, open)
        for part in spared(t.text, Face(codefont(), t.kind == :comment ? codeslant() : codestyle(), 12px,
                                        t.kind == :plain ? colours.ink : getfield(colours, t.kind), false))]...)
