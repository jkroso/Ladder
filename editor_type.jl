# The Editor: what a window of Ladder holds, from its pages and its settings to
# the parts of the window that it keeps between frames. The parts of the window
# and of the page are here too, as types, so a file of its own can give them
# methods.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI Theme light
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "./markdown" Cell Line words
@use "./spreadsheet" Value
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./folder_page" exports...
@use "github.com/jkroso/UI.jl/Interface/draw" rect
@use "github.com/jkroso/UI.jl/Interface/Semantic/Mermaid" problem
@use "./sheet" Result parts shown folded
@use "./chart" => Charts
@use "./filter" => Filters
@use "./save" => Saves
@use "./gallery" => Galleries
@use "./find" => Searches

export Item, Live, Grid, isspread, Glide, Editor, TopBar, Sidebar, Page, Document, Backdrop, FinderInput,
       ToolButton, TableButton, Mode, Levels, Stop, JuliaCode, Title, CheckCount, ReadOnly, SendButton,
       Paragraph, Heading, List, Quote, CodeBlock, Table, Rule, LiveBlock, SheetBlock, Trouble, Block,
       FileRow, FileLabel, Entry, EntryLabel, Shown, small_editor, owner_of, owner_key!, state_of, docdir, item, hosted, top_editor, button, FileView,
       Sheet, FileEntry, Crumb, Breadcrumb, FileText, Pages, ChartView, FilterRows, FilterView, SaveView,
       GalleryView, TermSettings, TERM_SETTINGS, ViewBlock, ItemClock, PlainLine, Rect, TranscriptButton,
       FileCheck, DesignSheet, FolderPage, SourceChooser, SearchView, SearchChoice, ChoiceMenu, ChoiceRow,
       editors, EmailHead, EACH_FRAME, AT_QUIT, BAR_PARTS, BUTTONS, AgentKind, WebFolder, WebPage,
       PAGE_WINDOWS, OutcomeBody, Bound, AgentPane, FileBlock, Things, each_thing, CodePicker,
       Ties, ties, host!, shown_span, span!, WindowParts, window_parts,
       NextFrame, next_frame, one_more_frame!

# --- what a window holds ---------------------------------------------------------

"One block of the page: a line of the document, or a table drawn as a table"
struct Item
  first::Int     # the lines of the document it shows
  last::Int
  top::px        # from the top of the page's text
  tall::px
  content::Any   # a Flow, a Grid or a Live
end

"What a `ui` code block made when its code ran, and how tall that is on the page"
struct Live
  node::Any      # a SemanticUI or a GeometricUI
  tall::px
end
tall(l::Live) = l.tall

"A table laid out"
struct Grid
  rows::Vector{Int}            # the line of the document each row comes from
  widths::Vector{px}
  heights::Vector{px}
  cells::Vector{Vector{Cell}}  # where each cell's text is in its line
  flows::Vector{Vector{Flow}}  # one for each column, even where a row has no cell
  # A spreadsheet is laid out as a table is, with a row of letters over it and a column of numbers on its left
  head::px                     # how tall the row of letters is, with the line under it. A table has none.
  left::px                     # how wide the column of numbers is, with the line beside it
  values::Vector{Vector{Value}}   # what each cell of a spreadsheet comes to
end

Grid(rows, widths, heights, cells, flows) = Grid(rows, widths, heights, cells, flows, 0px, 0px, Vector{Value}[])

"True when `g` is a spreadsheet, not a table"
isspread(g::Grid) = g.head > 0px

"""
Where one caret is drawn while it moves to a new place. A place is how far the
caret's left and top are from the top left of the page's text, and its height,
so it stays the same while the page scrolls.
"""
mutable struct Glide
  from::NTuple{3,Float64}   # the place it left
  to::NTuple{3,Float64}     # the place it's going to
  left_at::Float64          # when it left
  buf::UInt                 # the page it's on
  key::Tuple{Pos,Int}       # where the caret was in the text when it left, and the version of the text
end

@def mutable struct Editor <: SemanticUI
  buf::Buffer = Buffer()
  buffers::Dict{String,Buffer} = Dict{String,Buffer}()
  back::Vector{String} = String[]       # the files that showed before this one, with the one just before it last. See `go_back!`.
  ahead::Vector{String} = String[]      # the files that going back left, with the one that was left last at the end
  folder::String = ""
  files::Vector{String} = String[]      # the Markdown files in the folder
  listed::Vector{String} = String[]     # the folders and files in the folder, as the sidebar lists them
  entries::Dict{String,FSObject} = Dict{String,FSObject}()   # the object in the file system of the folder and of each one listed, by its path
  panel::Bool = false                   # is the sidebar showing?
  slid::Float64 = 0.0                   # when the sidebar last started to slide in or out
  slid_from::Float64 = 0.0              # how far open it was then, from 0 to 1
  full_screen::Bool = false             # does the window fill a screen of its own? macOS hides its close, minimise and zoom buttons then.
  screened::Float64 = 0.0               # when the window last started or stopped filling its screen
  screened_from::Float64 = 0.0          # how far the top bar's buttons had slid into the room of the close, minimise and zoom buttons then, from 0 to 1
  side::px = PANEL_W                    # how wide the sidebar is. Drag its right edge to change it.
  hidden::Bool = false                  # the sidebar lists the hidden files and folders too: the ones whose names start with a dot, and the ones that you ignore
  right::Bool = true                    # a page that has a panel at the right shows it, as a repository's page has git's panel. See `page_side`.
  own::Bool = false                     # you write the message of each commit, and the agent doesn't. See "an agent writes the commit's message".
  pinned::Bool = false                  # a click on the file's name pinned the path in the top bar open. See "the path in the top bar".
  hide_bar::Symbol = :never             # when the top bar hides until the mouse is at the top of the window: :always, :full_screen or :never. See "a top bar that hides".
  theme::Symbol = :sepia
  look::Symbol = :own                   # :site on a page of a blog, which looks as the blog's site does. See `page_look`.
  applied::Symbol = :none               # the theme the window was last told about
  font::String = SERIF                  # of the page's text
  weight::Int = 400                     # how heavy the page's text is: the Mac's number for a weight, like 300 for Light. 400 is Regular.
  zoom::Float64 = 1.0
  remember::Bool = false                # write the settings to a file when they change
  settings::Bool = false                # this window opened to show the settings page
  plain::Bool = false                   # the part of the page with the caret shows its markup: plain text, and not rich text
  spelling::Bool = true                 # put a line of dots under each word that's spelt wrong
  updates::Bool = true                  # the app looks for a newer version of itself, and gets it, without being asked
  autosave::Bool = false                # a page is written to its file when its window stops being the front window
  peeks::Bool = true                    # the card of a link to a page, while ⌘ is held, shows the start of the page. See "the start of a page in a link's card".
  ai::String = "Claude"                 # the agent that Ladder starts for a change or a question, by its name in AGENT_KINDS. See "the agents that Ladder can start".
  glide::Bool = true                    # the caret moves to a new place in a short time, and doesn't jump there
  wrap::Bool = true                     # a line of a file of code that's too long for the window goes on under itself
  numbers::Bool = true                  # a file of code shows the number of each line beside it
  shade::Bool = false                   # the line of a file of code that the caret is on is shaded
  beside::Bool = false                  # a block of changes shows the old lines at the left and the new lines at the right
  indent::Int = 2                       # how many spaces one step of indentation is, in code
  code_scale::Float64 = CODE_SCALE      # how big code is, as a part of the size of the page's text
  code_font::String = CODE_FONT         # the font of code, by the name of its family
  code_weight::Int = 300                # how heavy code is, like `weight`. A font without Light draws its nearest weight.
  guide::Int = 0                        # a faint line goes down a file of code after this many characters. 0 is no line.
  bundle::String = "Ladder"            # the bundle of key bindings: the shortcuts of every command
  rebound::Dict{Symbol,String} = Dict{Symbol,String}()   # the shortcuts of each command that has other keys than the bundle's, as the settings file writes them
  popup::Symbol = :none                # :finder while the file finder is open, and :commands while the command palette is
  picked::Int = 1                       # the file the finder will open
  scroll::Scroll = Scroll(width(grow=grow), height(grow=grow), scrollbar_inset=0px)   # the page's scrollbar is at the window's edge
  files_scroll::Scroll = Scroll(width(grow=grow), height(grow=grow))
  nodes::Dict{Any,Any} = Dict{Any,Any}()   # the parts of the window, kept between frames
  flows::Dict{Any,Any} = Dict{Any,Any}()
  layout::Vector{Item} = Item[]
  shown::UnitRange{Int} = 1:0           # the items that were built for the last frame
  width::px = PROSE_W                   # how wide the text is
  widest::px = PROSE_W                  # the widest the text gets, before zooming. The settings page sets it.
  reach::px = 0px                       # how far the longest line goes, in a file of code whose long lines don't wrap
  origin::Tuple{px,px} = (0px, 0px)     # where the page's text was last drawn in the window
  goal::Union{Nothing,px} = nothing     # where ↑ and ↓ try to keep the caret
  reveal::Bool = false                  # scroll to the caret before the next frame
  blink::Float64 = time()
  glides::Dict{Int,Glide} = Dict{Int,Glide}()   # where each caret is drawn while it moves: 1 is the main one. See `glide_to!`.
  gliding::Int = 1                      # the number of the caret that's being drawn
  by_step::Bool = false                 # a key has just taken the caret a step, so it moves to its new place in a short time
  carets::Int = 1                       # how many carets the last frame had
  clicked::Tuple{Float64,Pos,Int} = (0.0, (0, 0), 0)
  size::Tuple{px,px} = (1100px, 800px)  # the window's size, until there is a window to ask
end

@def mutable struct TopBar <: SemanticUI end
@def mutable struct Sidebar <: SemanticUI end    # the list of files down the left of the window

@def mutable struct Page <: SemanticUI end       # the scrolling area around the text
@def mutable struct Document <: SemanticUI end   # the text itself
@def mutable struct Backdrop <: SemanticUI end   # catches clicks outside a popup
@def mutable struct FinderInput <: SemanticUI end
@def mutable struct ToolButton <: SemanticUI
  icon::String = ""
  action::Symbol = :none
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip under it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
end
"A button of the bar that shows over the table the caret is in"
@def mutable struct TableButton <: SemanticUI
  action::Symbol = :none
  label::String = ""
end
"The picture in the top bar of the level that the window shows at: a ladder at the highest level and a snake under it. While the mouse is over it, it opens into the slider of the levels."
@def mutable struct Mode <: SemanticUI
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
  quiet::Bool = false
end
"The slider that the picture of the level opens into while the mouse is over it: a stop for each level, with the snake at its low end and the ladder at its high end"
@def mutable struct Levels <: SemanticUI
  stops::Vector{Any} = Any[]   # the Stop of each level, from the lowest
  open::Bool = false           # true from when the mouse comes over the picture until it leaves the slider
  since::Float64 = 0.0         # when it started to open or to close
  from::Float64 = 0.0          # how far open it was then, from 0 to 1
  pressed::Int = -1            # the level of the stop that the mouse went down on, 0 once a drag has left it, or -1 for none
end
"A stop of the slider of the levels. A click on it goes to its level."
@def mutable struct Stop <: SemanticUI
  level::Int = 1
  quiet::Bool = false          # clicked, so no tooltip until the mouse leaves it
end
"""
The Julia code of a `julia` code block of a page, or of a whole file of Julia
code. It's the part of the page that answers for the levels of what its code
comes to. See "what Julia code ran, down a level".
"""
@def mutable struct JuliaCode <: SemanticUI
  n::Int = 0       # its place among the `julia` code blocks of its page, or 0 for a file of Julia code
  depth::Int = 0   # how many levels down it shows what its code comes to: 0 for the value, 1 for inferred code, 2 for LLVM code, 3 for assembly
end
"The file's name in the middle of the top bar. A right-click on it shows the file's menu."
@def mutable struct Title <: SemanticUI end
"How many of the checks of a file of Julia code pass, in the top bar. A click goes to the next check that fails."
@def mutable struct CheckCount <: SemanticUI
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
  quiet::Bool = false
end
"""
The lock in the top bar of a page that you can't change: a file that's only
shown, a page from a web server, or a file that your Mac marks as read-only.
It's no button. While the mouse is over it, its tooltip says "Read only".
"""
@def mutable struct ReadOnly <: SemanticUI
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
  quiet::Bool = false
end
"The button in the top bar that sends the page to the agent that's waiting for it"
@def mutable struct SendButton <: SemanticUI
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
  quiet::Bool = false
end

# The parts of the document. Each one holds the items that show its lines.
@def mutable struct Paragraph <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct Heading <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct List <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct Quote <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct CodeBlock <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct Table <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
@def mutable struct Rule <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
"A code block in the language `ui`, showing what its code made"
@def mutable struct LiveBlock <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
"A code block in the language `sheet`, drawn as rows that work things out"
@def mutable struct SheetBlock <: SemanticUI; first::Int = 0; last::Int = 0; items::Vector{Item} = Item[] end
"The ! of a row of a sheet that went wrong. It says what went wrong while the mouse is over it."
@def mutable struct Trouble <: SemanticUI
  message::String = ""
  size::px = 14px
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)
end
const Block = Union{Paragraph,Heading,List,Quote,CodeBlock,Table,Rule,LiveBlock,SheetBlock}
"A row of the file finder's list, or of the project picker's: a page or a project"
@def mutable struct FileRow <: SemanticUI
  path::String = ""
  finder::Int = 0    # its place in the list
end
"The name of a file in the sidebar's tree"
@def mutable struct FileLabel <: SemanticUI
  path::String = ""
end
"A heading or a component of a file, as the sidebar lists it"
struct Entry
  line::Int       # where it starts
  level::Int      # a heading's level. A component has level 7, so it goes in the heading above it. A run of text in a line, in the top bar's path, has 8.
  title::String
  icon::String
  caret::Int      # the line the caret goes to: the heading's own, or the line after a component
end
"""
A heading or a component of a file, under that file in the sidebar's tree
"""
@def mutable struct EntryLabel <: SemanticUI
  path::String = ""
  line::Int = 0
  level::Int = 1
  title::String = ""
  icon::String = ""
  caret::Int = 0
end

"""
What a live block shows: the node that its code made. The code can make a
layout with nodes in it, like `Column(Checkbox(), Checkbox())`. Making the
Column describes each Checkbox once, so each frame describes them again, and
a click on a checkbox shows.
"""
@def mutable struct Shown <: SemanticUI
  value::Any = nothing   # a SemanticUI or a GeometricUI
  was::Theme = light     # the theme that the text in a GeometricUI value has now
  inline::Bool = false   # made by inline code, so it's in a line of text and only as wide as what it shows
end

# --- a small editor ----------------------------------------------------------------------
#
# A part of the window that has text of its own makes an Editor for that text:
# a small editor. The field of a cell of a table has one, and so have a field
# of a SolidCraft design, the words that you type to an agent, and a part of
# another page. That part is the small editor's owner. `small_editor` makes
# one, and `owner_of` gives its owner.
#
# A key that's pressed in a small editor goes to its owner first, as
# `owner_key!`. A kind of owner is a type, and what a key does in its text is
# its method of `owner_key!`, in the owner's own file. So a new kind of field
# changes nothing here, and nothing in `key_does!`.

"""
An editor for the text of `owner`, a part of the window that has text of its
own, like the field of a cell of a table. It holds `buf`. A key that's
pressed in it goes to `owner` first: see `owner_key!`. In the window it's a
child of `parent`: the owner, when the owner is a part of the window itself.
"""
small_editor(owner, buf::Buffer=Buffer(); parent=owner) = begin
  sub = Editor()
  sub.buf = buf
  window_parts(sub).input = own!(sub, TextInput())
  ties(sub).owner = owner
  setfield!(sub, :parent, parent)
  sub
end

"The part of the window that the small editor `e` is the text of, or nothing for a window's own editor"
owner_of(e) = ties(e).owner

"""
What the key `K` does in the small editor `e` of `owner`, in the window `w`,
before the editor does what it does with a key. `command` is the command that
the key runs, or nothing, and `select` is true when ⇧ is held to grow the
selection: see `command!`. It gives :text when the key is the text's, and the
editor then does what it does with it. Anything else is what the key press
comes to, and the editor does no more: `handled` when the key is done with,
or nothing when it goes on to the part of the window that the owner is in.

Each kind of owner has its own method. This one is for a window's own editor,
which has no owner, and for an owner that takes no key.
"""
owner_key!(owner, e, w, K, command, select) = :text

# --- what a feature keeps for a window ----------------------------------------------------
#
# A feature that keeps something for a window between frames, like the tabs
# that are open or the place of a drag, keeps it in a struct of its own, with a
# field for each thing and a default for each field. The window holds one of
# each such struct, in `nodes` under the struct's type, and `state_of` gives
# it. So the fields have types, a name that's spelt wrong is an error, and two
# features can't take each other's place as they could with a key like :drag.
#
#     @def mutable struct TabsState
#       waiting::Union{Nothing,Float64} = nothing   # when the first key of two was pressed
#     end
#     state_of(e, TabsState).waiting = time()

"""
What the window of the editor `e` keeps of the kind `T`: the one that it has,
or a new `T()` the first time that it's asked for. `T` is a struct with a
default for each field.
"""
state_of(e, ::Type{T}) where T = get!(T, e.nodes, T)::T

# --- what a window keeps for more than one file --------------------------------------------
#
# Most of what a window keeps is one file's own, and its struct is in that
# file. These are the window's own: files that load before and after one
# another set them and read them. So their structs are here, where each file
# finds them. A field takes a value of its own type only, since `@def` doesn't
# convert what it's given.

"""
What ties a small editor to the window that it's in: the part of the window
that it's the text of, and for one that shows lines of a page, the editor of
the page that shows them. A window's own editor has neither.
"""
@def mutable struct Ties
  owner::Any = nothing                            # the part of the window that it's the text of: see `owner_of`
  host::Union{Nothing,Editor} = nothing           # the editor of the page that shows it: see `hosted`
  span::Union{Nothing,Tuple{Int,Int}} = nothing   # the first and the last of the lines of its page that it shows: see `shown_span`
  end_room::px = 0px                              # the room that its last line leaves free at its right end: see `end_room`
  # The names that the part that shows it gives a sheet in it, each with its value: see `sheet_given`
  given::Union{Nothing,Vector{Tuple{String,Any}}} = nothing
end

"What ties the editor `e` to the window that it's in: see `Ties`"
ties(e) = state_of(e, Ties)

"Note that the page of the editor `e` shows the lines that the small editor `sub` edits"
host!(sub, e) = (ties(sub).host = e; sub)

"The first and the last of the lines of its page that `e` shows: the editor of a part of another page, or of a reply of an agent"
shown_span(e) = ties(e).span::Tuple{Int,Int}

"Note that `sub` shows the lines `span` of its page: the first and the last"
span!(sub, span) = (ties(sub).span = span; sub)

"The parts of a window that its editor keeps for more than one file"
@def mutable struct WindowParts
  input::Union{Nothing,TextInput} = nothing   # the text field of the file finder. A small editor has one too, which nothing shows.
  side_menu::Any = nothing                    # what's at the left of the window in this frame: Ladder's sidebar, or the side menu of a kind of folder. See `side_tick!`.
end

"The parts of the window of `e` that more than one file asks for: see `WindowParts`"
window_parts(e) = state_of(e, WindowParts)

"What the parts of a window ask of its next frame. The frame takes each thing once."
@def mutable struct NextFrame
  hold::Union{Nothing,Tuple{Int,px}} = nothing   # a line of the page, and how far under the top of the page's space it goes once the page is laid out: see `hold!`
  soon::Bool = false                             # one more frame is drawn soon after: see `one_more_frame!`
end

"What the next frame of the window of `e` is asked for: see `NextFrame`"
next_frame(e) = state_of(e, NextFrame)

"""
Draw one more frame of the window of `e` soon after the next one. Code that
has just run can load the drawing methods of a node, and the frame that ran
it can't call them yet.
"""
one_more_frame!(e) = (next_frame(e).soon = true; e)

# --- what the parts of a window ask of it ------------------------------------------------

"The folder of the document that's showing. The sidebar can show another folder."
docdir(e) = isempty(e.buf.path) ? e.folder : dirname(e.buf.path)

"The item that shows line `i`"
item(e, i::Int) = e.layout[something(findfirst(it -> it.first <= i <= it.last, e.layout), length(e.layout))]

"The editor of the page that shows the part of a page that `e` edits, or nothing when `e` is the window's own"
hosted(e) = ties(e).host

"The editor of the window that `e` is in: `e`, or the editor of the page that shows the part that `e` edits, and so on up"
top_editor(e) = (h = hosted(e); h === nothing ? e : top_editor(h))

button(e, action, icon) = node!(() -> ToolButton(icon=icon, action=action), e, action)

"What the page shows for a file that doesn't show as text: a viewer of its kind, or words that say it's a binary file"
@def mutable struct FileView <: SemanticUI
  path::String = ""
  viewer::Any = nothing   # the STLViewer, the player or the Pages of the file, kept from one frame to the next
  table::Any = nothing    # the FileSheet of a CSV file: its table, and what's chosen for it
  button::Any = nothing   # the HexButton of a binary file
end

"A sheet laid out"
struct Sheet
  rows::Vector{Int}             # the line of the document each row comes from
  cells::Vector{Vector{Cell}}   # each row's name and expression, or only its expression
  names::Vector{Flow}
  exprs::Vector{Flow}
  results::Vector{Result}       # what each row comes to
  heights::Vector{px}
  name_w::px                    # how wide the column of names is
  size::px                      # of the text
end

"One line of the list under a Breadcrumb: a file or a folder"
@def mutable struct FileEntry <: SemanticUI
  path::String = ""
end

"One name in a Breadcrumb"
@def mutable struct Crumb <: SemanticUI
  path::String = ""
  name::String = ""
end

"The path `at`, as the names of the folders on the way to it"
@def mutable struct Breadcrumb <: SemanticUI
  at::String = ""
  open::Bool = false     # is the list of what's in the folder showing?
  # Kept so each name and each line knows when the mouse is over it
  crumbs::Dict{String,Crumb} = Dict{String,Crumb}()
  entries::Dict{String,FileEntry} = Dict{String,FileEntry}()
  # The STLViewer of the model at `at`, the player of the sound or the video there, or the Pages
  # of the PDF file there. It's kept so that the model stays as it was turned, the file plays on
  # from one frame to the next, and the page stays the one you turned to.
  viewer::Any = nothing
  text::Any = nothing    # what `kept!` keeps of the file at `at`, like its text, or false if it has none
  read::Any = nothing    # what `text` is: its kind, the path of its file and when the file last changed
  inline::Bool = false   # in a line of text, so its list floats under it and takes no room on the page
  folders::Bool = false  # only a folder can be the path, as when you choose where something is kept. The folder needn't be made yet.
  room::Union{Nothing,px} = nothing   # how wide it can be, when it has less room than the page is wide
  button::Any = nothing  # its OpenButton, once it has shown
  files::Any = nothing   # a function of a file's name that's true for the files the list shows, when it picks a file of some kinds. Folders always show.
end

"""
The text of the file that a breadcrumb previews. It's kept so that the file
is read once, and so that the text stays where you scrolled it to.
"""
mutable struct FileText
  lines::Vector{String}
  more::Bool        # the file is longer than what was read
  scroll::Scroll
end

FileText(lines, more) = FileText(lines, more, Scroll(width(grow=grow), height(LINE_H * min(length(lines), PREVIEW_LINES) + 2TEXT_PAD)))

"The pages of a PDF file, one at a time. A click on the left half goes back a page, and one on the right half goes on."
@def mutable struct Pages <: SemanticUI
  path::String = ""
  page::Int = 1
  count::Int = 0
  wide::px = PAGE_W   # how wide a page shows
end

"What a `chart` block shows: the numbers of a table, drawn"
@def mutable struct ChartView <: SemanticUI
  n::Int = 0                               # its place among the page's charts
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  spec::Charts.Chart = Charts.Chart()
  lines::Vector{String} = String[]         # the lines that `spec` was read from
  shown::Any = nothing                     # the version of the page, and what the chart shows of that page
  marks::Vector{Charts.Mark} = Charts.Mark[]   # the parts of the chart, where they were last drawn
  box::NTuple{4,Float64} = (0.0, 0.0, 0.0, 0.0)   # where the chart was last drawn in the window
  sourcing::Bool = false                   # the list of files to draw is open, after Choose a file…
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons, kept between frames
end

"The rows that a filter reads, and where they came from"
struct FilterRows
  rows::Vector{Vector{String}}   # the first row has the names of the columns
  numbers::Vector{Bool}          # true for each column that holds numbers
  things::Vector{Any}            # for a JSON file, the thing that each row came from: row k + 1 came from thing k
  name::String                   # what the top of the block calls where they came from
  path::String                   # the file, or "" for a table of the page
  more::Bool                     # the file has rows after these
  problem::String                # why there are no rows, or ""
end

"What a `filter` block shows: the rows of a table that meet its conditions"
@def mutable struct FilterView <: SemanticUI
  n::Int = 0                               # its place among the page's filters
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  spec::Filters.Filter = Filters.Filter()
  lines::Vector{String} = String[]         # the lines that `spec` was read from
  shown::Any = nothing                     # what the rows were last worked out for, and what they are
  whole::Bool = false                      # every row shows, and not only the first FILTER_ROWS
  widths::Any = nothing                    # what the widths of the columns were worked out for, and the widths
  values::Dict{Int,Any} = Dict{Int,Any}()  # each column's values, for its menu, or nothing for a column with too many
  cut::Dict{Any,String} = Dict{Any,String}()   # the text of a cell as it shows, cut short for its column
  across::px = 0px                         # how far the table is scrolled to the right
  top::px = 0px                            # where the top of the table was last drawn in the window
  asking::Int = 0                          # the column whose menu is open, or 0
  was::Vector{String} = String[]           # the block's lines when that menu opened, which esc puts back
  saved::String = ""                       # what Save last did, in words
  lang::String = FILTER                    # filter, or load for a block that loads its rows from a server or a file
  job::Any = nothing                       # a load from a server that hasn't ended: a function that gives nothing until it has, then how it went
  asked::Any = nothing                     # the address and the key that the block last asked its server with
  changed::Float64 = 0.0                   # when the block's lines last changed
  said::String = ""                        # what came of the last load, in words
  failed::Bool = false                     # true when that went wrong
  nokey::Bool = false                      # the Keychain had no key with the name that `key` gives
  choosing::Bool = false                   # the file picker of a load block is open, after a click on Choose
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its chips, headings and buttons, kept between frames
end

"What a `save` block shows: which rows it has, where they go, and what happened when they last went"
@def mutable struct SaveView <: SemanticUI
  n::Int = 0                               # its place among the page's save blocks
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  spec::Saves.Save = Saves.Save()
  lines::Vector{String} = String[]         # the lines that `spec` was read from
  job::Any = nothing                       # a send that hasn't ended: a function that gives nothing until it has, then how it went
  sending::Any = nothing                   # what that send has: how many rows, where to, and the name of the key
  said::String = ""                        # what happened at the last click, or ""
  failed::Bool = false                     # true when that went wrong
  nokey::Bool = false                      # the Keychain had no key with the name that `key` gives
  choosing::Bool = false                   # the list of folders is open, after a click on Choose
  sourcing::Bool = false                   # the list of files to save the rows of is open, after Choose a file…
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its buttons, kept between frames
end

"What a `gallery` block shows: the files and the folders of a folder as a grid of squares"
@def mutable struct GalleryView <: SemanticUI
  n::Int = 0                               # its place among the page's galleries
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Galleries.Gallery = Galleries.Gallery()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  shown::Any = nothing                     # what the gallery showed when its folder was last read, and when to read it again
  # The small picture of each file: its key and whether it fills its square. It's nothing for a file that has no picture.
  small::Dict{Any,Any} = Dict{Any,Any}()
  wanted::Vector{Galleries.Item} = Galleries.Item[]   # the files in the window whose small pictures aren't made yet
  side::px = 0px                           # how big each square was when the grid was last laid out
  showing::String = ""                     # the file that fills the window, or that last did
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its squares, its button, and the player of the video that fills the window, kept between frames
end

"""
The terminal's settings, which every window has the same. The Terminal page
of the settings changes them, and the file of the settings keeps them.
"""
@def mutable struct TermSettings
  caret::Symbol = :block   # the caret's shape while a program asks for none: one of TERM_CARETS
  blink::Bool = false      # that caret blinks
  copies::Bool = false     # what the mouse selects is copied as soon as the button goes up
  meta::Bool = false       # ⌥ with a key sends ESC and the key, and not the Mac's character
  bell::Symbol = :flash    # what a program's bell does: one of TERM_BELLS
  most::Int = 10_000       # how many lines of the past a terminal keeps: one of TERM_PASTS
  again::Bool = true       # a program that said how to start again does so when Ladder opens again: see term/resume.jl
end

const TERM_SETTINGS = TermSettings()

"What a `view` block shows: another file, a folder, or a page of the web"
@def mutable struct ViewBlock <: SemanticUI
  n::Int = 0                               # its place among the page's `view` blocks
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  lines::Any = nothing                     # the lines that it was last read from
  source::Vector{String} = String[]        # those lines without its settings: the name of what it shows, or its HTML
  settings::Vector{String} = String[]      # its lines of settings, like `aspect: 16:9`, as they're written
  aspect::Float64 = 0.0                    # its width over its height, from its line `aspect:`, or 0 when it has none
  lang::String = VIEW_BLOCK                # the language of its block: `view`, or `web` as it was called before
  target::String = ""                      # the path or the address that its line names, as `view_target` gives it
  held::Bool = false                       # its lines hold the HTML of a page, which starts with a tag
  browser::Any = nothing                   # the Browser that shows an HTML file or a page of the web
  crumb::Any = nothing                     # the Breadcrumb that keeps what shows any other file: its model, its player, its text
  parts::Dict{Any,Any} = Dict{Any,Any}()
  sent::Any = nothing                      # the page that was last given the sums, and what it was given: see `send_sums!`
end

"The button beside a to-do item that starts and stops the clock of the page's time log on the item"
@def mutable struct ItemClock <: SemanticUI
  key::String = ""                              # the to-do item, by what a schedule calls it
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)     # where it was last drawn, to put its tooltip over it
end

"A line of plain text as a frame laid it out: its text, what kind of line it was, whether its markup showed, and its layout with its height"
struct PlainLine
  text::String
  line::Line
  raw::Bool
  flow::Flow
  tall::px
end

const Rect = NTuple{4,Float64}   # left, top, right and bottom, in px

"The button beside a video, under its FillButton, that opens the drop-down of what was said in the video"
@def mutable struct TranscriptButton <: SemanticUI
  open::Bool = false                          # is its drop-down open?
  rect::NTuple{4,px} = (0px, 0px, 0px, 0px)   # where it was last drawn, to put its tooltip beside it
  quiet::Bool = false                         # clicked, so no tooltip until the mouse leaves it
end

"A check of a file of Julia code, for Fix Check and Show Steps: its line, its code, and how it went when it last ran"
struct FileCheck
  line::Int
  code::String
  went::Symbol
end

"The sheet of a SolidCraft design's parameters: see \"the sheet of a SolidCraft design's parameters\""
@def mutable struct DesignSheet <: SemanticUI
  sub::Any = nothing          # the editor of its page
  room::Any = nothing         # how wide the panel has room for it to be, or nothing before the panel says
  took::Bool = false          # the editor took the last key, which goes no further: see its `owner_key!`
  names::Any = nothing        # the design's version, and each parameter's name and value then, for the rows to use
end

"What the page shows of a folder that has no page of its own: its name, and the table of what's in it"
@def mutable struct FolderPage <: SemanticUI
  path::String = ""
end

"The list of where a block's rows can come from, while it shows: its rows, the one picked, and the words typed in its field"
@def mutable struct SourceChooser <: SemanticUI
  of::Any = nothing          # the block's view
  asking::Any = nothing      # :source while the list shows
  rows::Vector{Any} = Any[]
  pick::Int = 1
  typed::String = ""
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its field and its rows, kept between frames
end

"What a `find` block shows: the lines of a folder's pages that match"
@def mutable struct SearchView <: SemanticUI
  n::Int = 0                               # its place among the page's lists
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Searches.Query = Searches.Query()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  shown::Any = nothing                     # what the list was last worked out for, and what it found
  kept::Vector{Searches.Match} = Searches.Match[]   # the items whose box was clicked here. They stay in the list.
  pages::Dict{String,Any} = Dict{String,Any}()      # what was found in each page, and the mark of the page's text then
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its rows, kept between frames
  asking::Any = nothing                    # what the list that floats under a button chooses: :kind or :folder, or nothing when none shows
  rows::Vector{Any} = Any[]                # the rows of that list that have the words in its field
  pick::Int = 1                            # the row of them that Return takes
  typed::String = ""                       # the words in its field when the rows were last worked out
  back::Bool = false                       # the field for the words to find had the keyboard when it opened, and gets it back
end

"""
A button at the top of a list that shows what the list asks for now. A click
opens a list of the others. One chooses the kind of thing that the list is
of, and one chooses the folder that it looks in.
"""
@def mutable struct SearchChoice <: SemanticUI
  of::Any = nothing     # the list
  what::Symbol = :kind  # :kind or :folder
end

"The list that floats under such a button, with a field that searches it. It's the takeoff's list of units, with other rows."
@def mutable struct ChoiceMenu <: SemanticUI
  of::Any = nothing        # the list that it changes
  button::Any = nothing    # the button that it's under
  side::Symbol = :bottom   # the side of the button that it's on
  pick::Int = 0            # the row that was picked when it was last drawn. A row that the keys pick is brought in sight.
end

"A row of that list: a kind of thing to list, or a folder"
@def mutable struct ChoiceRow <: SemanticUI
  of::Any = nothing
  k::Int = 0
end

"The editor of each window that's open, in the order they opened"
const editors = Editor[]

"""
The top of an email, in place of the card of its front matter. It's a part of
the page with levels of its own. See "the top of an email" in email_head.jl.
"""
@def mutable struct EmailHead <: SemanticUI
  rows::Vector{Tuple{Int,String,String}} = Tuple{Int,String,String}[]   # the keys of the front matter: the line, the key and what it's set to
  size::px = 13px      # of the text
  wide::px = 0px       # how wide the page's text is
  path::String = ""    # the page's file. The top goes back to its highest level when another file shows.
  full::Bool = false   # it shows every field of the email's header
  fields::Vector{Pair{String,String}} = Pair{String,String}[]   # those fields, as the email's file has them
  read_for::Tuple{String,Float64} = ("", 0.0)                   # the file that they were read from, and when it was last changed
  folded::Any = nothing   # the fields cut into lines for the width they were cut for, and that width
end

"What code does in each frame of each window: `f(e)`"
const EACH_FRAME = Dict{Symbol,Any}()

"What code does when Ladder quits, after its last window has closed: `f()`"
const AT_QUIT = Dict{Symbol,Any}()

"More buttons for the right end of the top bar, for the page that shows: `f(e)` gives the nodes, or `()`"
const BAR_PARTS = Dict{Symbol,Any}()

"""
What a button of the top bar does, when code from the startup page made it
with `button(e, action, icon)`, by its action: `(run=f(e), tip=f(e), off=f(e),
strong=true or false)`. `tip` gives the words of its tooltip. `off` is true
while the button does nothing. A `strong` button has the colour that says do this.
A button that turns something on and off can have `on=f(e)`, which is true
while that's on: the button is shaded then, as the sidebar's button is. A
button whose work takes a while can have `busy=f(e)`: it spins while that's true.
"""
const BUTTONS = Dict{Symbol,Any}()

"""
An agent that Ladder can start: the name that Settings shows, its command,
the folders where the command can be besides those of the PATH, and the
options that go before your words, for a change and for a question. For a
question, the agent reads files and changes none. `message` are the options
for a few words that it writes from what it's given, like a commit's
message, quickly and with no files. `piped` is true when it reads text that's
piped to it as part of your words. Without it, that text goes in the words.
"""
struct AgentKind
  name::String
  command::String
  places::Vector{String}
  change::Vector{String}
  look::Vector{String}
  message::Vector{String}
  piped::Bool
end

AgentKind(name, command, places, change, look) = AgentKind(name, command, places, change, look, look, false)

"""
A folder on a web server: its address, which ends in a /, and the web folder
that it's in, or nothing at the top of its site. `K` is its kind, a type
under `AbstractDirectory`, as a folder on the Mac has one. A folder of no
kind is a `WebFolder{FS.Directory}`.
"""
struct WebFolder{K<:AbstractDirectory}
  address::String
  parent::Union{WebFolder,Nothing}
end

"A page on a web server, in the web folder `parent`"
struct WebPage
  address::String
  parent::WebFolder
end

"The window whose code ran last in the module of each page, by the page's path. A name of the module that acts on a window, like `page_theme!`, acts on that one."
const PAGE_WINDOWS = Dict{String,Any}()

"What shows under the box of an outcome that's open: the rest of the value, the node that the value is, or the parts of the value"
@def mutable struct OutcomeBody <: SemanticUI
  of::Any = nothing
  detail::Any = nothing    # the Detail of a function or a module, made when the box first opens
  members::Any = nothing   # the Member of each part of a value that has parts, made when the box first opens
  pick::Any = nothing      # the FormPick of a function that offers more than one method or set of types
  showed::Any = nothing    # what the lines of a level were last shown for, so that new lines start at their top
  scroll::Scroll = Scroll(width(grow=grow), height(grow=grow))   # moves through a list of parts that's taller than `MEMBERS_H`
  wide::px = 0px           # how wide that list is. Each frame sets it.
  across::px = 0px         # how wide all of it is, with the space around what it shows. Each frame sets it.
  corners::Any = radius(OUTCOME_ROUND)   # how round each corner is. A corner that the box stands on is square. Each frame sets it.
  tall::px = MEMBERS_H     # the tallest that the list is in the room that the window has under the box. Each frame sets it.
end

"""
A name that Julia code makes: where it's written, what the code says it is,
and the lines of the page where code can use it. `span` is nothing for a name
that all of the page's code can use. `call` is true when `words` is what the
code calls to make the name's value, like Wall in `door = Wall(0.9)`. That's
the value's type only when it's the name of a type.
"""
struct Bound
  name::String
  at::Pos
  words::String
  call::Bool
  span::Union{Nothing,UnitRange{Int}}
end

"""
The agent's pane of a window: the session, the words that you type, and what
it keeps between frames. `follow` is true while the newest words stay in sight. `was` is how
the window was before agent mode, to put it back. `open` holds each run of
steps that a click opened, by the place of its first step.
"""
@def mutable struct AgentPane <: SemanticUI
  session::Any = nothing
  field::Any = nothing
  parts::Dict{Any,Any} = Dict{Any,Any}()
  scroll::Scroll = Scroll(width(grow=grow), height(grow=grow))
  follow::Bool = true
  put::px = 0px                # how far the pane was scrolled when it was last drawn
  seen::Int = -1               # the version of the session that the window last drew
  was::Any = nothing
  open::Set{Int} = Set{Int}()
  error::String = ""           # why the session couldn't start, or ""
  file::String = ""            # the file that keeps the session, when the pane is a session's file in the page: see "a session's file"
  kept::Int = 0                # the version of the session that the file has
  wrote::Float64 = 0.0         # when the file was last written
  stamp::Float64 = 0.0         # when the file last changed, as Ladder read it or wrote it
end

"A block that a file defines: what the file's function made of the lines of the block"
@def mutable struct FileBlock <: SemanticUI
  n::Int = 0                               # its place among the page's blocks in its language
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  lang::String = ""
  source::String = ""                      # where its function comes from, as the page names it
  lines::Vector{String} = String[]         # the lines that `value` was made from, or that it wrote last
  state::Symbol = :new                     # :new, :ask (you haven't allowed its repository), :wait and :get (its repository comes), :made or :fault
  from::Any = nothing                      # the module of the file
  file::String = ""                        # the file on this Mac that the module comes from, or "" for a repository or a folder
  read::Float64 = 0.0                      # when that file was last saved, as this block last knew it
  value::Any = nothing                     # what the function made
  shown::Any = nothing                     # the Shown that draws it
  said::Any = nothing                      # the lines that `written` last gave for it, or nothing
  wants::Bool = false                      # what was made asked for its lines to be written
  inside::Bool = false                     # the caret was in the block's lines in the last frame
  fault::String = ""                       # what went wrong
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its button, kept between frames
end

"""
Several things that one chip has. ⇧ and a click on the window add a thing to
a chip for things in the window, when its function takes them: an argument
of type `Union{T,Things}`, where `T` is the type of one thing.
"""
struct Things
  all::Vector{Any}
end

"The things that `x`, what a chip has, is: itself, or each of several"
each_thing(x) = x isa Things ? x.all : Any[x]

"""
The tool of a window of the editor `editor` that shows the code of a thing.
`swallow` is true from a click that it took until the button comes up. `asked` is the change
that an agent is making, or made a moment ago: see "ask for a change to a
thing". `about` is a question that an agent is answering, or answered: see
"ask about a thing". `chosen` is the thing that a click with ⌘ and ⌥ down
chose, with the method that draws it, while the buttons on its line show.
`buttons` is where each of those buttons was drawn in the last frame.
"""
@def mutable struct CodePicker
  editor::Any = nothing
  swallow::Bool = false
  asked::Any = nothing
  about::Any = nothing
  chosen::Any = nothing
  buttons::Vector{Any} = Any[]
end
