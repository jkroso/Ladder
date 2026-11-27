# The Editor: what a window of Ladder holds, from its pages and its settings to
# the parts of the window that it keeps between frames. The parts of the window
# and of the page are here too, as types, so a file of its own can give them
# methods.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI Theme light
@use "./markdown" Cell
@use "./spreadsheet" Value
@use "github.com/jkroso/URI.jl/FS" => FS FSObject
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./folder_page" exports...

export Item, Live, Grid, isspread, Glide, Editor, TopBar, Sidebar, Page, Document, Backdrop, FinderInput,
       ToolButton, TableButton, Mode, Levels, Stop, JuliaCode, Title, CheckCount, ReadOnly, SendButton,
       Paragraph, Heading, List, Quote, CodeBlock, Table, Rule, LiveBlock, SheetBlock, Trouble, Block,
       FileRow, FileLabel, Entry, EntryLabel, Shown, docdir, item, hosted, top_editor, button, FileView

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

# --- what the parts of a window ask of it ------------------------------------------------

"The folder of the document that's showing. The sidebar can show another folder."
docdir(e) = isempty(e.buf.path) ? e.folder : dirname(e.buf.path)

"The item that shows line `i`"
item(e, i::Int) = e.layout[something(findfirst(it -> it.first <= i <= it.last, e.layout), length(e.layout))]

"The editor of the page that shows the part of a page that `e` edits, or nothing when `e` is the window's own"
hosted(e) = get(e.nodes, :host, nothing)

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
