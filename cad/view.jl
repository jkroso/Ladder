# The editor of a SolidCraft design: what the page shows of a `.sc` file.
#
#     DesignView(path="bracket.sc")
#
# It's laid out as SolidCraft's own window is. The design fills the page, in
# 3D. Over it are a toolbar with tabs, a browser at the left, the history of
# the design's steps along the bottom, and at the right the form of the
# command that's being filled in.
#
# The browser lists the origin, the bodies, the sketches and the construction
# planes. The eye at the end of a line shows or hides what the line names, and
# the eye of a folder does that for everything in it. The origin's point,
# axes and planes are hidden in a new design, as in SolidCraft.
#
# The view takes Fusion 360's mouse:
#   - Drag with the middle button to move the design, and with ⇧ held too to
#     turn it. ⌃⇧ and a drag of the middle button up brings it nearer.
#   - The wheel brings the design nearer, towards the mouse. So does a pinch.
#     ⇧ and the wheel, or ⇧ and two fingers on the trackpad, turn it.
#   - ⇧ and a click of the middle button put the point that a turn goes round
#     where the click was. A click on nothing takes the point away, and a
#     turn then goes round the point that the mouse is over as it starts.
#   - Two clicks of the middle button show all of the design.
#   - Ladder's own ways work too: drag to turn the design, with ⇧ held to
#     move it, and drag with the right button to turn it.
#   - The mouse lights the face or the edge that it's over. A click selects
#     it, and ⇧ with a click selects one more.
#   - The three balls at the top right show the design's axes. A click on one
#     looks along that axis.
#
# A command, like Extrude or Fillet, opens its form. A length is typed in the
# form. A face, an edge or a region of a sketch is clicked in the design
# while its line of the form is lit. As soon as the form has what the command
# needs, the design shows what the command would make, tinted. OK runs the
# command, and SolidCraft's hidden program works out the new shape: see
# engine.jl.
#
# A length, an angle or a count is Julia code, like `4.5cm + 2mm*1.5`, in the
# colours of a code block. It has the units of Units.jl, `deg` for a degree,
# and each parameter of the design by its name, like `d1`. ⌘Return runs the
# code of the field that has the keyboard, or the part of it that's selected,
# and shows what it comes to, as it does in a Julia file.
# expressions.jl says what SolidCraft gets for the code.
#
# In Ladder, each field to type in is Ladder's own editor of text, as a page
# is: its selection, its caret and its keys are a page's, and what ⌘Return
# shows is the box that a Julia file shows, after the code. Ladder gives the
# fields through `FIELD`. Without it, a field is a TextInput, and what
# ⌘Return shows is under the field. The panel at the right is wider while
# the text of one of its fields needs the room, up to half the design. A
# longer text goes on to another line in the field.
#
# Two clicks on a sketch, in the browser or the history, open it. The toolbar
# then has the sketch's tools. A tool takes clicks in the sketch, and snaps to
# the points and curves that are near. With no tool, a drag moves a point or a
# curve as far as its constraints allow, and two clicks on a dimension change
# its length. The sketch that's open is drawn over the bodies. Slice, in the
# panel at the right, takes away the part of each body that's in front of it.
# A sketch that isn't open is hidden by a body in front of it.
#
# ⌘Z takes back the last change and ⇧⌘Z does it again. ⌘S writes the file.
# Until then, every change is only in the hidden program.
#
# A design can also be only shown, as it is in a `view` block of a page:
#
#     DesignView(path="bracket.sc", readonly=true, fill=false, height=260px)
#
# That one is the picture alone, with no panels, and nothing changes the
# design. A drag turns it, and with ⇧ held moves it. The middle button works
# as it does in the editor. A pinch, or two fingers with ⌘ held, bring it
# nearer, and two clicks show all of it again. The
# hidden program ends as soon as it has given the bodies. When the file
# changes, the design is read again.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl" Keys KeyPress KeyRelease MouseMove Typed onkey onmouse ontype onscroll flt
@use "github.com/jkroso/MiniFB.jl/skia" gpus
@use "github.com/jkroso/Font.jl" ["units" px]
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe focus theme handled window_of scale reuse!
@use "github.com/jkroso/UI.jl/Interface/draw" draw cursor rect redraw_in! MouseScroll Pinch onpinch ishovered popup! close_popup! show_tooltip! hide_tooltip! hittest
@use "github.com/jkroso/UI.jl/Interface/image" register_image has_image
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" => TextInputs
@use Colors: Colorant, RGBA, RGB, @colorant_str, red, green, blue
@use Skia
@use "./json" => JSON
@use "./design" => Designs
@use "./scene" => Scenes
@use "./gl" => GLs
@use "./sketch" => Sketching
@use "./ink" => Ink
@use "./ink" Glyph
@use "./commands" => Commands
@use "./preview" => Previews
@use "./pieces" => Pieces
@use "./expressions" => Expressions
@use "../zip" => Zips
@use "github.com/jkroso/UI.jl/Interface/Specific" text_width

const grow = GrowType.Grow
const clear = RGBA(0.0, 0.0, 0.0, 0.0)
const Spot = NTuple{2,Float64}

num(x) = Float64(hasproperty(x, :value) ? x.value : x)

# --- small parts ---------------------------------------------------------------------

"Something to click. `look(hovered)` gives how it shows."
@def mutable struct Press <: SemanticUI
  look::Any = nothing
  act::Any = nothing      # what a click does, a function of the click
  twice::Any = nothing    # what two clicks do
  other::Any = nothing    # what a click with the right button does
  tip::String = ""
  clicked::Float64 = 0.0
  quiet::Bool = false     # it was clicked, so its tip stays away until the mouse leaves
end

describe(p::Press) = (ishovered(p) || (p.quiet = false); p.look(ishovered(p)))
cursor(::Press) = :hand

onkey(p::Press, e::KeyPress{Keys.mouse_left}) = begin
  now = time()
  twice = p.twice !== nothing && now - p.clicked < 0.4
  p.clicked = twice ? 0.0 : now
  p.quiet = true
  hide_tooltip!(e.window)
  twice ? p.twice(e) : p.act === nothing || p.act(e)
  handled
end
onkey(p::Press, e::KeyPress{Keys.mouse_right}) = (p.other === nothing || (hide_tooltip!(e.window); p.other(e)); handled)
onkey(::Press, ::KeyRelease{Keys.mouse_left}) = handled

const TIP_INK = colorant"rgb(236,236,238)"
# A tip is made when the mouse moves, where no theme is set, so it takes the font of the button's
# theme. With none it gets UI.jl's Helvetica, which has no ⌘ or ⇧ and draws a box for each.
tip_label(words, t=theme()) = Box(padding(10px, 7px), Text(words, size=12px, family=t.family, color=TIP_INK, wrap=WrapMode.none))

onmouse(p::Press, e::MouseMove) = begin
  (p.quiet || isempty(p.tip) || rect(p) === nothing) || show_tooltip!(e.window, tip_label(p.tip, theme(p)), p, placement=:bottom, gap=6px)
  handled
end

"A panel over the design. A click on it, or the wheel over it, isn't the design's."
@def mutable struct Card <: SemanticUI
  look::Any = nothing
end
describe(c::Card) = c.look()
onkey(::Card, ::KeyPress{Keys.mouse_left}) = handled
onkey(::Card, ::KeyPress{Keys.mouse_right}) = handled
onkey(::Card, ::KeyRelease{Keys.mouse_left}) = handled
onmouse(::Card, ::MouseMove) = handled

# --- menus ---------------------------------------------------------------------------

# A menu of the editor looks as the menu of a column's heading in a page's
# table does (SheetMenu and found_colours in main.jl): a cream card with round
# corners, a line for each item that lights under the mouse, and small
# capitals over the lines. In a dark page it has the page's own colours.

"The colours of a menu: those of the menu of a table's column"
menu_colours(t) = dark(t) ?
  (frame=t.surface, pick=t.select, ink=t.text, dim=t.dim, line=colorant"rgb(86,86,94)", rule=t.line) :
  (frame=colorant"rgb(233,224,202)", pick=colorant"rgb(224,212,185)", ink=colorant"rgb(27,23,16)", dim=colorant"rgb(110,104,88)",
   line=colorant"rgb(176,164,136)", rule=colorant"rgb(221,212,192)")

"""
A menu that floats over the editor. Each of `items` is a line, `icon => words`
with "" for no icon, or "-" for a rule between two groups. `title` goes over
the lines in small capitals, and the line of `now` shows as chosen. A click on
a line gives its number to `pick` and closes the menu. The up and down arrows
light a line, and Return picks it.
"""
@def mutable struct Menu <: SemanticUI
  items::Vector{Any} = Any[]
  title::String = ""
  now::Int = 0
  pick::Any = nothing
  active::Int = 0          # the line that the arrows lit, or 0
  lines::Vector{Any} = Any[]
end

"A line of a `Menu`"
@def mutable struct MenuLine <: SemanticUI
  of::Any = nothing
  i::Int = 0
end

const MENU_KEY = :design_menu

"""
Show a menu of `items` beside `anchor`, a node or a place in the window. It
hangs under the anchor, or with `placement=:top` goes over it. See `Menu`.
"""
menu!(window, items, pick; anchor=window.mouse, placement=:below, gap=4px, width=210px, title="", now=0, t=theme()) = begin
  m = Menu(items=collect(Any, items), pick=pick, title=title, now=now)
  m.lines = Any[it isa Pair ? MenuLine(of=m, i=i) : nothing for (i, it) in enumerate(m.items)]
  hide_tooltip!(window)
  popup!(window, m; anchor, placement, gap, width, key=MENU_KEY, theme=t)
  nothing
end

"How wide `node` is on the screen, and at least `least`: a menu under a field is as wide as the field"
menu_width(node, least) = (r = rect(node); r === nothing ? least : max(least, r.width))

describe(m::Menu) = begin
  c = menu_colours(theme(m))
  title = isempty(m.title) ? () :
    (Row(width(grow=grow), height(22px), padding(8px, 0px), Alignment.Center, Box(words(m.title, 10px, color=c.dim, weight="Semibold"))),)
  # A new box for each rule: one box in two places of a layout never finishes its layout
  rule() = Box(width(grow=grow), height(13px), Alignment.Center, Box(width(grow=grow), height(1px), background(c.rule)))
  Box(width(grow=grow), padding(6px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)),
    Column(width(grow=grow), Alignment.Start, title..., (l === nothing ? rule() : l for l in m.lines)...))
end

describe(l::MenuLine) = begin
  m = l.of
  c = menu_colours(theme(m))
  icon, text = m.items[l.i]
  on = l.i == m.now
  Row(width(grow=grow), height(28px), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(on || l.i == m.active || ishovered(l) ? c.pick : c.frame),
    (isempty(icon) ? () : (Glyph(icon, size=13px, color=on ? c.ink : c.dim, accent=c.dim),))...,
    Box(width(grow=grow), Alignment.Start, clip_x=true, words(text, 13px, color=c.ink, weight=on ? "Semibold" : "")))
end

cursor(::MenuLine) = :hand
onmouse(l::MenuLine, ::MouseMove) = (l.of.active = 0; handled)
onkey(l::MenuLine, e::KeyPress{Keys.mouse_left}) = (choose!(l.of, l.i, e.window); handled)
onkey(::MenuLine, ::KeyPress{Keys.mouse_right}) = handled

"Close the menu, then tell it which item was picked"
choose!(m::Menu, i, window) = (close_popup!(window, MENU_KEY); m.pick(i); nothing)

"True when no key of ⌃, ⌘, ⌥ and ⇧ is down"
plain(e) = !any(k -> k in e.window.keys, (Keys.ctrl, Keys.cmd, Keys.opt, Keys.shft))

"Light the next line of `m` that isn't a rule, `by` one down or up, round from the last to the first"
step!(m::Menu, by) = begin
  lines = findall(l -> l !== nothing, m.lines)
  isempty(lines) && return handled
  at = findfirst(==(m.active), lines)
  m.active = lines[at === nothing ? (by > 0 ? 1 : length(lines)) : mod1(at + by, length(lines))]
  handled
end
onkey(m::Menu, e::KeyPress{Keys.down}) = plain(e) ? step!(m, 1) : handled
onkey(m::Menu, e::KeyPress{Keys.up}) = plain(e) ? step!(m, -1) : handled
onkey(m::Menu, e::KeyPress{Keys.enter}) = (plain(e) && m.active > 0 && choose!(m, m.active, e.window); handled)

"The picture of the design, which fills the editor under its panels"
@def mutable struct Scene <: SemanticUI
  of::Any = nothing
end
describe(::Scene) = Box(width(grow=grow), height(grow=grow))

"A command's form while it's filled in"
mutable struct Form
  spec::Commands.Spec
  values::Dict{String,Any}           # each field's choice or flag, and for a field that's clicked, what each click sends
  shows::Dict{String,Vector{Any}}    # for a field that's clicked: what each click lights in the design
  active::String                     # the field that the next click in the design fills
  step::Any                          # the number of the step that's being changed, or nothing for a new one
  inputs::Vector{Any}                # for a step that's being changed: its named lengths and angles
  problem::String
  extra::JSON.Object                 # parameters that go with the form's own, like what's selected in a sketch
  key::Any                           # what the form asks for now, as text: the design shows what a command with that key makes
  since::Float64                     # when the form last changed
  closed::Set{String}                # the parts of the form that are closed: Options, Advanced
end
Form(spec, step=nothing, inputs=Any[]) = Form(spec, Dict{String,Any}(), Dict{String,Vector{Any}}(), "", step, inputs, "", JSON.Object(), nothing, 0.0, Set(["Advanced"]))

"What the page shows of a SolidCraft design"
@def mutable struct DesignView <: SemanticUI
  path::String = ""
  model::Any = nothing
  parts::Dict{Any,Any} = Dict{Any,Any}()
  eye::Scenes.Eye = Scenes.Eye()
  fitted::Bool = false
  area::NTuple{4,Float64} = (0.0, 0.0, 1.0, 1.0)   # where the picture is in the window: left, top, width and height in px
  tab::String = "Model"
  hover::Any = nothing                # what the mouse is over in the design
  picked::Vector{Any} = Any[]         # what's selected
  form::Any = nothing                 # the Form that's being filled in
  tool::Any = nothing                 # the sketch tool in use: a Commands.Tool, or :dimension, :trim, :extend, :project
  clicks::Vector{Any} = Any[]         # the places that the tool was clicked at
  drag::Any = nothing                 # what a held button is doing
  mouse::Spot = (0.0, 0.0)            # where the mouse is in the picture
  panel::Symbol = :none               # :params while the parameters show
  stage::Any = nothing                # the OpenGL place the design is drawn at, or false when macOS gives none
  image::Any = nothing                # the last picture, and what it's a picture of
  data::IdDict{Any,Any} = IdDict{Any,Any}()        # each body's triangles and edges, as the graphics card takes them
  regions::Dict{Int,Any} = Dict{Int,Any}()         # the closed regions of each sketch that shows
  faces::Dict{Any,Int} = Dict{Any,Int}()           # the face of a body that a point is on, for the faces with a colour of their own
  described::Dict{String,Any} = Dict{String,Any}() # what SolidCraft says of the parameters of a command
  spots::Vector{Any} = Any[]          # where the last frame drew things to click in the picture: each a box and what it is
  closed::Set{String} = Set{String}(["Document Settings", "Named Views", "Origin"]) # the folders of the browser that are closed
  clicked::Float64 = 0.0              # when the picture was last clicked, to tell two clicks
  marks::Bool = true                  # the marks of a sketch's constraints show
  sizes::Bool = true                  # and its dimensions
  points::Bool = true                 # and its points
  snap::Bool = true                   # a click of a sketch tool goes to the point that's near, and level or upright with the last click
  building::Bool = false              # what a sketch tool draws is construction geometry
  slice::Bool = false                 # while a sketch is edited, the part of each body between its plane and the eye doesn't show
  previews::Bool = true               # the design shows what the command of the open form would make
  along::Float64 = 0.0                # how far the history has moved left
  readonly::Bool = false              # it only shows the design: it has no panels, and nothing changes the design
  fill::Bool = true                   # it takes all the room that it's given. A design that's shown in a page has `height` instead.
  height::Any = nothing               # how tall it is in a page
  seen::Int = -1                      # the model's version when it was last drawn
end

"The node of `v` with `key`, made by `make` when it's first asked for. It stays the same node from frame to frame."
part!(make, v::DesignView, key) = get!(v.parts, key) do
  n = make()
  n.parent === nothing && setfield!(n, :parent, v)
  n
end

"Something to click, kept under `key`. `look(hovered)` gives how it shows now."
press!(look, v::DesignView, key; act=nothing, twice=nothing, other=nothing, tip="") = begin
  p = part!(Press, v, key)
  p.look, p.act, p.twice, p.other, p.tip = look, act, twice, other, tip
  p
end

card!(look, v::DesignView, key) = (c = part!(Card, v, key); c.look = look; c)

"""
What makes a field to type in, when Ladder gives one: `FIELD[](v, text,
placeholder, code)` gives a node whose text Ladder edits as it does a page's,
and with `code`, as a file of Julia code. It has methods of `text_of`,
`set_text!`, `select_all!`, `iscode`, `run_field!`, `wants` and `room!`.
Without one, a field is a TextInput.
"""
const FIELD = Ref{Any}(nothing)

"How big the text of a field is, before the theme makes it bigger or smaller"
const FIELD_TEXT = 12px

"How big the text of the field `box` is, in its theme"
field_size(box) = FIELD_TEXT * scale(theme(box))

"How big the text of the sheet of parameters is, before the theme makes it bigger or smaller. Its thin code font looks smaller than a field's at the same size."
const SHEET_TEXT = 14px

"How big the text of the sheet `box` is, in its theme"
sheet_size(box) = SHEET_TEXT * scale(theme(box))

"A field to type in, kept under `key`. `text` is what it holds when it's first shown."
input!(v::DesignView, key; text="", placeholder="") = part!(() -> new_field(v, text, placeholder, false), v, key)

new_field(v, text, placeholder, code) =
  FIELD[] !== nothing ? FIELD[](v, String(text), String(placeholder), code) :
  TextInput(text=String(text), cursor=length(text), anchor=length(text), placeholder=placeholder, font_size=FIELD_TEXT)

"The text that the field `box` holds"
text_of(box::TextInput) = box.text

"Make the field `box` hold `text`, with the caret after it"
set_text!(box::TextInput, text) = (box.text = String(text); box.cursor = box.anchor = length(box.text); box)

"The text of the field `box` before its caret, on the caret's line, or nothing while text is selected"
before_caret(box::TextInput) = box.anchor == box.cursor ? first(box.text, box.cursor) : nothing

"Put `name` in place of the `n` characters before the caret of the field `box`, with the caret after it"
complete!(box::TextInput, n, name) = begin
  chars, at = collect(box.text), box.cursor
  box.text = String(vcat(chars[1:at-n], collect(String(name)), chars[at+1:end]))
  box.cursor = box.anchor = at - n + length(name)
  box
end

"Select all the text of the field `box`"
select_all!(box::TextInput) = ((box.anchor, box.cursor) = (0, length(box.text)); box)

"The field that `node` is part of, for a node that has the keyboard. Ladder's editor of a field's text is part of the field."
keyed(node) = node

"True when the field `box` has the keyboard of the window `w`"
has_keys(w, box) = w !== nothing && keyed(w.focus) === box

"How wide the field `box` needs to be to show its whole text, with its padding and border"
wants(box::TextInput) = num(TextInputs.width_to(box, length(box.text))) + 2 * 8 * scale(theme(box)) + 2 + 3

"Tell the field `box` how wide it is in the panel, before it's laid out"
room!(box, wide) = box

"What shows under the field `box` besides what `outcome` shows, or nothing"
under(box) = nothing

"Forget the fields to type in whose key starts with `kind`, so that they show their first text again"
forget!(v::DesignView, kind) = filter!(p -> !(p.first isa Tuple && !isempty(p.first) && p.first[1] == kind), v.parts)

# --- fields of Julia code -------------------------------------------------------------

"""
How code looks in a field: the colours of a code block, and the font of code,
as `(colours, family)`. Ladder sets this to a function that gives the page's.
Without one, a field has the colours here and the page's font.
"""
const CODE_LOOK = Ref{Any}(nothing)
const LIGHT_CODE = (comment=colorant"rgb(140,140,140)", string=colorant"rgb(30,120,60)", number=colorant"rgb(180,95,0)",
                    keyword=colorant"rgb(170,40,130)", call=colorant"rgb(30,90,180)", type=colorant"rgb(0,120,130)")
const DARK_CODE = (comment=colorant"rgb(112,112,118)", string=colorant"rgb(160,200,120)", number=colorant"rgb(230,170,100)",
                   keyword=colorant"rgb(200,130,220)", call=colorant"rgb(120,170,250)", type=colorant"rgb(110,200,200)")
const WRONG = colorant"rgb(226,96,84)"
"How solid a body shows that a piece of the open form is cut from, so that the piece shows in it"
const GHOST = 0.28
code_look(v) = CODE_LOOK[] !== nothing ? CODE_LOOK[]() : (dark(theme(v)) ? DARK_CODE : LIGHT_CODE, theme(v).family)

"A field of Julia code, kept under `key`, in the colours of code. `text` is what it holds when it's first shown."
code!(v::DesignView, key; text="", placeholder="") = begin
  box = part!(() -> new_field(v, text, placeholder, true), v, key)
  box isa TextInput || return box
  colours, family = code_look(v)
  box.colours = code -> Expressions.pieces(code, colours)
  box.font_family = family
  box
end

"Is `box` a field of Julia code?"
iscode(box) = box isa TextInput && box.colours !== nothing

"The kind of value that a parameter with the unit `unit` takes. A parameter of text takes no code."
unit_kind(unit) = unit in ("deg", "rad") ? :angle : unit in ("", "unitless", nothing) ? :number : unit == "text" ? :text : :length

"The design's parameters, as `parameters.list` gives them: the user's, and the lengths of the steps, like d1"
every_param(v::DesignView) = (m = v.model; m === nothing ? Any[] : isempty(m.parameters) ? Designs.params(m) : m.parameters)

"The parameter of the design called `name`, or nothing"
param_named(v::DesignView, name) = (list = every_param(v); i = findfirst(p -> get(p, "name", nothing) == name, list); i === nothing ? nothing : list[i])

"The comment of the parameter called `name`, or \"\""
param_note(v::DesignView, name) = (p = param_named(v, name); p === nothing ? "" : string(something(get(p, "comment", ""), "")))

"The module that the code of the fields runs in, with each parameter of the design as it is now"
workspace!(v::DesignView) = Expressions.parameters!(get!(Expressions.workspace, v.parts, :julia), every_param(v))

"""
What the code of a field comes to: `(value, failed)`. The form asks for the
values of its fields in each frame, so the same code with the same parameters
isn't run again.
"""
ran(v::DesignView, code) = begin
  memo = get!(() -> Dict{String,Any}(), v.parts, :ran)
  stamp = hash([(get(p, "name", ""), get(p, "value", nothing)) for p in every_param(v)])
  get(v.parts, :ran_with, nothing) == stamp || (empty!(memo); v.parts[:ran_with] = stamp)
  get!(() -> Expressions.evaluate(workspace!(v), code), memo, String(code))
end

"""
What a field of code holds, for a value of the kind `kind`: what SolidCraft
gets, the code, the code as SolidCraft reads it (`solid`), the kind of value
and what it comes to (see `Expressions.reading`). Words say what's wrong, with
the field's `label` first. It's nothing for a field with nothing in it.
`got` is what the code came to, as `(value, failed)`, when that's known
already. Without it, the code runs with the design's parameters.
"""
read_code(v::DesignView, text, kind, label; got=nothing) = begin
  code = String(strip(text))
  isempty(code) && return nothing
  value, failed = got === nothing ? ran(v, code) : got
  failed && return "$label: $(Expressions.shown(value, true))"
  r = Expressions.reading(value, kind)
  r isa String ? "$label $r" : (; r..., code, solid=Expressions.solidcraft_code(code))
end

"What ⌘Return showed under each field, and what each field said was wrong with its code"
outcomes(v::DesignView) = get!(IdDict{Any,Any}, v.parts, :outcomes)

"Show `words` under the field `box` in red, till its text changes"
wrong!(v::DesignView, box, words) = (outcomes(v)[box] = (text=text_of(box), shown=String(words), failed=true); v)

"""
Run the code of the field `box`, or the part of it that's selected, as
⌘Return does in a Julia file. What it comes to shows under the field. A
field that Ladder gives shows it after the code, as a Julia file does.
"""
run_field!(v::DesignView, box::TextInput) = begin
  lo, hi = minmax(box.anchor, box.cursor)
  code = lo == hi ? box.text : String(collect(box.text)[lo+1:hi])
  value, failed = Expressions.evaluate(workspace!(v), code)
  # The code can give a name a value, which the code of the other fields can use
  empty!(get!(() -> Dict{String,Any}(), v.parts, :ran))
  outcomes(v)[box] = (text=box.text, shown=Expressions.shown(value, failed), failed=failed)
  v
end

"""
What ⌘Return showed for the field `box`, while the field still holds what it
held then: a box with the value in the colours of code, or what went wrong in
red. It's nothing when there's none.
"""
outcome(v::DesignView, box) = begin
  o = get(outcomes(v), box, nothing)
  (o === nothing || o.text != text_of(box)) && return nothing
  t = theme(v)
  colours, family = code_look(v)
  look = (radius(5px), border(1px, :solid, o.failed ? Ink.faded(WRONG, 0.45) : t.line), background(Ink.mixed(t.surface, colorant"black", dark(t) ? 0.2 : 0.03)))
  o.failed && return Box(width(grow=grow), padding(7px, 4px), Alignment.Start, look..., Text(o.shown, size=11.5px, color=WRONG))
  piece(s, colour) = (w = Text(s, size=11.5px, family=family, color=colour, wrap=WrapMode.none); Box(width(text_width(w, s)), w))
  Row(height(22px), padding(7px, 0px), Alignment.Center, clip_x=true, look..., [piece(s, something(c, t.text)) for (s, c) in Expressions.parts(o.shown, colours)]...)
end

"A row of a form for a field of code: what it asks for, the field, and what ⌘Return showed under the field"
code_row(v::DesignView, label, box) = begin
  row = labelled(v, label, box)
  shown = something(outcome(v, box), Some(under(box)))
  shown === nothing && return row
  Column(width(grow=grow), child_gap=4px, Alignment.Start, row,
    Row(width(grow=grow), child_gap=8px, justify=Alignment.Start, Box(width(LABEL_W)), Row(width(grow=grow), justify=Alignment.Start, clip_x=true, shown)))
end

"""
Ask SolidCraft what the code of each of `readings` comes to, as SolidCraft reads
it. Then `then(agreed)` gets the keys of those that come to what Julia got:
SolidCraft can have the code itself for those, and follow the parameters that
it names. The others get the number that Julia got.
"""
agree!(then, v::DesignView, readings) = begin
  asked = [(k, r) for (k, r) in readings if r.number !== nothing && !isempty(r.kind)]
  agreed = Set{Any}()
  isempty(asked) && return then(agreed)
  left = Ref(length(asked))
  for (k, r) in asked
    Designs.ask!(v.model, "expr.evaluate", JSON.Object("expression" => r.solid, "kind" => r.kind)) do answer, problem
      answer isa AbstractDict && get(answer, "ok", false) === true && get(answer, "value", nothing) isa Real &&
        isapprox(Float64(answer["value"]), r.number, rtol=1e-9, atol=1e-9) && push!(agreed, k)
      (left[] -= 1) == 0 && then(agreed)
    end
  end
  nothing
end

"What SolidCraft gets for the code of `r`: the code as SolidCraft reads it when that comes to what Julia got, else the number"
given(r, agreed) = agreed ? r.solid : r.sent

"""
The comment that a parameter with the comment `old` gets for the code of `r`:
with a line that keeps the code, when SolidCraft got a number for it or wrote
it another way (π as pi), or without one when SolidCraft got the code itself.
Nothing when the comment stays the same.
"""
noted(r, agreed, old) = begin
  got = given(r, agreed)
  new = Expressions.with_code(old, got == r.code ? nothing : Expressions.comment(r.code, got))
  new == old ? nothing : new
end

"""
Set the parameter `name` to the code `text`. It gives words that say what's
wrong with the code, or nothing.
"""
set_param!(v::DesignView, name, text) = begin
  p = param_named(v, name)
  kind = p === nothing ? :number : unit_kind(get(p, "unit", ""))
  kind == :text && return (Designs.change!(v.model, "parameters.change", JSON.Object("name" => name, "expression" => String(strip(text)))); nothing)
  r = read_code(v, text, kind, name)
  r isa String && return r
  r === nothing && return nothing
  old = param_note(v, name)
  agree!(v, Dict(name => r)) do agreed
    params = JSON.Object("name" => name, "expression" => given(r, name in agreed))
    note = noted(r, name in agreed, old)
    note === nothing || (params["comment"] = note)
    Designs.change!(v.model, "parameters.change", params)
  end
  nothing
end

"""
Keep the code of each field that SolidCraft got a number for in the comment of
its parameter, so that the field shows the code again: see expressions.jl.
`answer` is what the command of a new step said, or nothing for a step that
was changed, whose `readings` are by the names of its parameters. `before` is
how many steps could be taken back before the change: ⌘Z takes back the change
and its comments together.
"""
note!(v::DesignView, answer, readings, agreed, before) = begin
  m = v.model
  write!(notes) = begin
    isempty(notes) && return
    for (name, note) in notes
      Designs.change!(m, "parameters.comment", JSON.Object("name" => name, "comment" => note))
    end
    Designs.refresh!(m; then=() -> Designs.together!(m, before))
  end
  if answer === nothing
    write!([name => note for (name, r) in readings for note in (noted(r, name in agreed, param_note(v, name)),) if note !== nothing])
    return v
  end
  # The parameters of a new step are found by what they were set to
  kept = [(r, given(r, k in agreed)) for (k, r) in readings if r.number !== nothing && given(r, k in agreed) != r.code]
  feature = answer isa AbstractDict ? get(answer, "feature", nothing) : nothing
  (isempty(kept) || !(feature isa Real)) && return v
  Designs.ask!(m, "timeline.inspect", JSON.Object("feature" => Int(feature))) do step, _
    step isa AbstractDict || return
    notes = Pair{String,String}[]
    for input in get(step, "inputs", Any[])
      i = findfirst(k -> k[2] == get(input, "expression", nothing), kept)
      i === nothing || push!(notes, String(input["param"]) => Expressions.comment(kept[i][1].code, kept[i][2]))
    end
    write!(notes)
  end
  v
end

words(s, size=12px; color=theme().text, weight="") = Text(String(s), size=size, subfamily=weight, color=color, wrap=WrapMode.none)

"Is the page dark?"
dark(t) = Ink.bright(t.surface) < 0.5

# --- the design ----------------------------------------------------------------------

"Open the design of `v`, if it isn't open, with the numbers that its page gives it"
load!(v::DesignView) = begin
  v.model === nothing || return v.model
  m = v.model = Designs.open_design(v.path; changes=given!(v))
  isempty(v.parts[:given]) ? m : keep!(v, m)
end

"End SolidCraft's program for `v`. What wasn't saved is lost."
close!(v::DesignView) = (v.model === nothing || Designs.close!(v.model); v.model = nothing; nothing)

"True when the design has changes that aren't in its file"
edited(v::DesignView) = v.model !== nothing && Designs.edited(v.model)

"Write the design to its file"
save!(v::DesignView) = (v.model === nothing || Designs.save!(v.model); v)
undo!(v::DesignView) = (v.model === nothing || (leave!(v); Designs.undo!(v.model)); v)
redo!(v::DesignView) = (v.model === nothing || (leave!(v); Designs.redo!(v.model)); v)

"Stop the tool and the form that are in use"
leave!(v::DesignView) = begin
  v.tool = nothing
  empty!(v.clicks)
  v.form = nothing
  v.drag = nothing
  v.model === nothing || Designs.forget!(v.model)
  v
end

"The sketch that's being edited, as SolidCraft describes it, or nothing"
sketch(v::DesignView) = begin
  m = v.model
  m === nothing && return nothing
  id = Designs.editing(m)
  id === nothing ? nothing : get(m.sketches, id, nothing)
end

"The saved picture of the design, from inside its file, as something to draw: the key of an image, or nothing"
saved_picture(v::DesignView) = begin
  key = "design-picture:" * v.path
  has_image(key) && return key
  try
    z = Zips.contents(v.path)
    i = findfirst(en -> en.name == "cache/thumbnail.png", z.entries)
    i === nothing ? nothing : register_image(key, Zips.bytes(v.path, z.entries[i]))
  catch
    nothing
  end
end

"""
The design of `v`, which is only shown, read again when its file has changed,
or when its page gives it other numbers. The design that showed stays until
SolidCraft's program has given the new one.
"""
follow!(v::DesignView) = begin
  m = load!(v)
  next = get(v.parts, :next, nothing)
  if next === nothing
    # While SolidCraft's program is still open, it only changes the numbers
    running = m.engine !== nothing && !isempty(m.doc) && isfile(v.path) && mtime(v.path) == m.read
    running && get(v.parts, :given, NO_CHANGES) != from_page(v) && return (Designs.busy(m) || vary!(v, m); m)
    changed = isfile(v.path) && mtime(v.path) != m.read || get(v.parts, :given, NO_CHANGES) != from_page(v)
    # A design that's still opening, with nothing to show yet, opens again at once
    changed && Designs.busy(m) && isempty(m.doc) && (Designs.close!(m); v.model = nothing; return load!(v))
    (changed && !Designs.busy(m) && time() >= get(v.parts, :again, 0.0)) || return m
    next = v.parts[:next] = Designs.open_design(v.path; changes=given!(v))
    isempty(v.parts[:given]) || keep!(v, next)
  end
  Designs.tick!(next)
  if !isempty(next.problem)
    # The file can be half written. The design that shows stays, and the file is read again soon.
    Designs.close!(next)
    delete!(v.parts, :next)
    v.parts[:again] = time() + 2
    redraw_in!(v, 2)
  elseif isempty(next.doc) || Designs.busy(next)
    redraw_in!(v, 0.016)
  else
    Designs.close!(m)
    delete!(v.parts, :next)
    v.model = m = next
    v.image === nothing || (v.image.of = nothing)
  end
  m
end

# A design in a `view` block takes the numbers of its page: each parameter of
# the design that has the name of a sum on the page gets the sum's value, as
# `Designs.changes` says. The file is never changed.
#
# SolidCraft's program stays open for a while after the numbers change, since
# a number that's dragged changes again soon. Then it only changes the numbers
# and makes the parts again: about a second for the satellite. When it has
# ended, the design is opened again with the new numbers, which takes about
# three, and the one that shows stays until the new one is made.

"No change to a design's parameters"
const NO_CHANGES = Dict{String,String}()

"Seconds that SolidCraft's program stays open after the numbers of a page last changed the design. It holds hundreds of MB."
const KEEP_OPEN = Ref(30.0)

"Does SolidCraft's program stay open for the numbers of the page?"
kept_open(v::DesignView) = !isempty(get(v.parts, :given, NO_CHANGES)) && time() - get(v.parts, :changed, 0.0) < KEEP_OPEN[]

"Keep the program of `m` open for `KEEP_OPEN[]` seconds more, and end it then, even when the design isn't drawn again"
keep!(v::DesignView, m) = begin
  at = v.parts[:changed] = time()
  Timer(KEEP_OPEN[] + 0.5) do _
    get(v.parts, :changed, 0.0) == at && v.model === m && !Designs.busy(m) && Designs.close!(m)
  end
  m
end

"""
Give the design that's open in SolidCraft's program the numbers that the page
has now, and ask for its parts again. A parameter that the page no longer
gives gets its own value back.
"""
vary!(v::DesignView, m) = begin
  had, now = get(v.parts, :given, NO_CHANGES), from_page(v)
  change = Dict{String,String}(name => text for (name, text) in now if get(had, name, nothing) != text)
  for p in file_params(v)
    haskey(had, p.name) && !haskey(now, p.name) && (change[p.name] = p.expr)
  end
  v.parts[:given] = now
  Designs.vary!(m, change)
  Designs.refresh!(m)
  keep!(v, m)
end

"Give the design that `v` shows the numbers of its page: each name with its value in SI units, as the scripts of a page get them"
give!(v::DesignView, sums) = (v.parts[:sums] = sums; v)

"What the numbers that the page gave `v` change in its design's parameters, as `Designs.changes` gives it"
from_page(v::DesignView) = begin
  sums = get(v.parts, :sums, nothing)
  sums === nothing || isempty(sums) ? NO_CHANGES : Designs.changes(file_params(v), sums)
end

"What the page changes in the design now, kept as what the design that opens next is given"
given!(v::DesignView) = (v.parts[:given] = from_page(v))

"The parameters that the design's file names, read again only when the file has changed"
file_params(v::DesignView) = begin
  at = isfile(v.path) ? mtime(v.path) : 0.0
  had = get(v.parts, :params, nothing)
  had !== nothing && had[1] == at && return had[2]
  list = Designs.file_params(v.path)
  v.parts[:params] = (at, list)
  list
end

"""
What shows of a design that's only shown: its picture, with no panels. In a
page it has a line round it, as a model has. SolidCraft's program ends when it
has given everything, since nothing more is asked of it.
"""
shown_only(v::DesignView) = begin
  m = follow!(v)
  t = theme(v)
  frame = v.fill ? (height(grow=grow),) : (height(v.height), radius(8px), border(1px, :solid, t.line))
  if !isempty(m.problem)
    picture = saved_picture(v)
    return Column(width(grow=grow), frame..., padding(16px), child_gap=10px, Alignment.Center, justify=Alignment.Center, background(t.surface), clip=true,
      (picture === nothing ? () : (Image(picture, height(max=v.fill ? 420px : max(v.height - 70px, 40px))),))...,
      Box(width(max=460px), Text(m.problem, size=12px, color=t.dim)))
  end
  Designs.tick!(m)
  if Designs.busy(m)
    redraw_in!(v, 0.016)
  elseif !isempty(m.doc) && m.engine !== nothing && !kept_open(v)
    Designs.close!(m)
  end
  if !v.fitted && !isempty(m.shapes)
    home!(v)
    v.fitted = true
  end
  # Which steps SolidCraft couldn't make with the numbers that the page gave
  note = isempty(m.said) ? () : (Box(padding(8px, 12px), Text(m.said, size=11px, color=t.dim)),)
  Stack(width(grow=grow), frame..., Alignment.Start, background(t.surface), clip=true, part!(() -> Scene(of=v), v, :scene), note...)
end

"Show all of the design, turned as it is when it's first shown. No panels lie over it, so it has little room round it."
home!(v::DesignView) = (delete!(v.parts, :pivot); v.eye = Scenes.fit(Scenes.Eye(), Scenes.box(v.model.shapes), (max(v.area[3], 100.0), max(v.area[4], 100.0)); room=1.05); v)

describe(v::DesignView) = begin
  v.readonly && return shown_only(v)
  m = load!(v)
  t = theme(v)
  if !isempty(m.problem)
    picture = saved_picture(v)
    return Column(width(grow=grow), height(grow=grow), padding(40px), child_gap=18px, background(t.surface),
      (picture === nothing ? () : (Image(picture, width(max=420px)),))...,
      Box(width(max=460px), Text(m.problem, size=13px, color=t.dim)))
  end
  Designs.tick!(m)
  # An answer can close the design: Save in the question that a window asks before it closes
  v.model === m || return Box(width(grow=grow), height(grow=grow))
  # While SolidCraft works, the editor looks for its answer in each frame
  Designs.busy(m) && redraw_in!(v, 0.016)
  # A design shows whole when its bodies first come
  if !v.fitted && (!isempty(m.shapes) || (!isempty(m.doc) && isempty(Designs.bodies(m))))
    v.eye = Scenes.fit(Scenes.Eye(), Scenes.box(m.shapes), (max(v.area[3], 100.0), max(v.area[4], 100.0)))
    v.fitted = true
  end
  # A sketch that was just opened is seen flat
  wait, now = get(v.parts, :look_at, nothing), Designs.editing(m)
  if wait !== nothing && now !== nothing && (wait === :new || wait == now) && haskey(m.sketches, now)
    delete!(v.parts, :look_at)
    look_at!(v, m.sketches[now])
  end
  # A design that's first shown takes the keyboard, so that ⌘S and ⌘Z are its own
  if !haskey(v.parts, :met) && window_of(v) !== nothing
    v.parts[:met] = true
    focus(v)
  end
  # A dimension that was just made asks for its length, once it has been drawn
  new = get(v.parts, :new_size, nothing)
  if new !== nothing
    i = findfirst(s -> s.what.kind == :size && s.what.of == new, v.spots)
    w = window_of(v)
    i === nothing || w === nothing || (delete!(v.parts, :new_size); edit_size!(v, w, v.spots[i].what))
  end
  editing = Designs.editing(m) !== nothing
  editing ? (v.tab = "Sketch") : v.tab == "Sketch" && (v.tab = "Model"; v.tool = nothing; empty!(v.clicks))
  preview!(v)
  offers!(v)
  left_row!(v)
  scene = part!(() -> Scene(of=v), v, :scene)
  Stack(width(grow=grow), height(grow=grow), Alignment.Start,
    scene,
    Column(width(grow=grow), height(grow=grow), padding(8px), child_gap=8px, Alignment.Start,
      ribbon(v),
      said(v)...,
      Row(width(grow=grow), height(grow=grow), Alignment.Start, child_gap=8px,
        browser(v),
        Box(width(grow=grow)),
        side(v)...),
      Row(width(grow=grow), justify=Alignment.Center, views(v)),
      history(v)))
end

# --- the look of the panels ----------------------------------------------------------

panel_look(t) = (background(Ink.faded(t.surface, 0.97)), radius(9px), border(1px, :solid, t.line), shadow(0, 3, 14, RGBA(0, 0, 0, dark(t) ? 0.35 : 0.12)))

"A small button with only an icon"
icon_button(v, key, icon, tip; act, on=false, size=16px, off=false) = begin
  t = theme(v)
  press!(v, key; act=off ? nothing : act, tip) do hovered
    Box(width(28px), height(28px), radius(6px), background(on ? t.select : hovered && !off ? t.hover : clear),
      Glyph(icon, size=size, color=off ? Ink.faded(t.dim, 0.5) : on ? t.accent : t.dim))
  end
end

"A button with words"
word_button(v, key, label; act, strong=false, tip="", wide=false, on=false, faint=false) = begin
  t = theme(v)
  press!(v, key; act, tip) do hovered
    Row((wide ? (width(grow=grow),) : ())..., height(28px), padding(14px, 0px), radius(6px), justify=Alignment.Center,
        (strong ? () : (border(1px, :solid, on ? t.accent : Ink.faded(t.line, 0.9)),))...,
        background(strong ? Ink.faded(hovered ? Ink.mixed(t.accent, t.text, 0.12) : t.accent, faint ? 0.4 : 1.0) : on ? Ink.faded(t.accent, 0.2) : hovered ? t.select : t.hover),
      Box(words(label, 12px, color=strong ? Ink.faded(t.on_accent, faint ? 0.6 : 1.0) : t.text, weight="Medium")))
  end
end

# --- the toolbar ---------------------------------------------------------------------

"What the toolbar calls the command `id`"
command_label(v::DesignView, id) = begin
  haskey(Commands.SHORT, id) && return Commands.SHORT[id]
  c = get(v.model.commands, id, nothing)
  c === nothing ? Commands.words(String(last(split(id, '.')))) : String(c["label"])
end

"The icon of the command `id`"
command_icon(v::DesignView, id) = begin
  haskey(Commands.BUTTON_ICONS, id) && return Commands.BUTTON_ICONS[id]
  haskey(Commands.SPECS, id) && return Commands.SPECS[id].icon
  c = get(v.model.commands, id, nothing)
  icon = c === nothing ? nothing : get(c, "icon", nothing)
  icon isa String && Ink.own(icon) !== nothing ? icon : "feature"
end

"What a command's tip says: its name, and the key that starts it"
command_tip(v::DesignView, id) = begin
  c = get(v.model.commands, id, nothing)
  name = c === nothing ? command_label(v, id) : String(c["label"])
  key = get(KEYS_OF, id, "")
  isempty(key) ? name : "$name ($key)"
end

"Is the command `id` the one in use?"
in_use(v::DesignView, id) =
  (v.form !== nothing && v.form.spec.command == id) || (v.tool isa Commands.Tool && v.tool.command == id) ||
  (v.tool isa Symbol && id == "sketch." * String(v.tool)) || (id == "parameters" && v.panel == :params)

tool_button(v::DesignView, id) = begin
  t = theme(v)
  on = in_use(v, id)
  green = id == "sketch.finish"
  press!(v, (:tool, id); act=e -> start!(v, id, e.window), tip=command_tip(v, id)) do hovered
    Column(width(min=56px), height(60px), padding(7px, 5px), radius(7px), child_gap=5px, background(on ? t.select : hovered ? t.hover : clear),
      Glyph(command_icon(v, id), size=25px, color=green ? colorant"rgb(60,180,90)" : t.text),
      Box(words(command_label(v, id), 11.5px, color=t.text)))
  end
end

"The buttons of the constraints, which go on what's selected in the sketch"
constraint_grid(v::DesignView) = begin
  t = theme(v)
  cell(id) = begin
    c = get(v.model.commands, id, nothing)
    icon = c === nothing ? "feature" : String(c["icon"])
    press!(v, (:tool, id); act=e -> start!(v, id, e.window), tip=c === nothing ? id : String(c["label"])) do hovered
      Box(width(26px), height(26px), radius(5px), background(hovered ? t.hover : clear), border(1px, :solid, Ink.faded(t.line, 0.8)),
        Glyph(icon, size=17px, color=colorant"rgb(226,138,96)"))
    end
  end
  ids = first.(Commands.CONSTRAINTS)
  Column(height(60px), child_gap=4px, padding(4px, 2px),
    Row(child_gap=4px, cell.(ids[1:6])...),
    Row(child_gap=4px, cell.(ids[7:end])...))
end

group(v::DesignView, g::Commands.Group) = begin
  t = theme(v)
  known(id) = id in ("parameters", "constraints") || haskey(v.model.commands, id)
  main = filter(known, g.main)
  more = filter(known, g.more)
  name = isempty(more) ? Box(height(18px), words(g.name, 11px, color=t.dim)) :
    press!(v, (:group, v.tab, g.name); act=e -> more_menu(v, g, more, e.window)) do hovered
      Row(height(18px), padding(6px, 0px), radius(4px), child_gap=4px, background(hovered ? t.hover : clear),
        Box(words(g.name, 11px, color=t.dim)), Glyph("chevron-down", size=9px, color=t.dim))
    end
  Column(padding(4px, 0px), child_gap=2px,
    Row(child_gap=2px, (id == "constraints" ? constraint_grid(v) : tool_button(v, id) for id in main)...),
    name)
end

"The menu of the commands of a group that have no button"
more_menu(v::DesignView, g::Commands.Group, more, window) = begin
  under = get(v.parts, (:group, v.tab, g.name), nothing)
  menu!(window, [command_icon(v, id) => command_label(v, id) for id in more], i -> start!(v, more[i], window);
        anchor=something(under, window.mouse), width=230px, t=theme(v))
end

ribbon(v::DesignView) = begin
  t = theme(v)
  m = v.model
  editing = Designs.editing(m) !== nothing
  tabs = [name for (name, _) in Commands.TABS if editing || name != "Sketch"]
  tab(name) = begin
    on = v.tab == name
    live = name == "Sketch"
    press!(v, (:tab, name); act=e -> editing && !live ? nothing : (v.tab = name)) do hovered
      Box(height(26px), padding(11px, 0px), radius(6px),
          background(on ? (live ? colorant"rgb(42,150,80)" : t.select) : hovered && !editing ? t.hover : clear),
        words(name, 12.5px, color=on && live ? colorant"white" : editing && !live ? Ink.faded(t.dim, 0.6) : t.text, weight=on ? "Semibold" : ""))
    end
  end
  groups = last(Commands.TABS[findfirst(p -> p.first == v.tab, Commands.TABS)])
  shown = Any[]
  for (i, g) in enumerate(groups)
    # A line between each two groups. Each is a box of its own: a box can be in a layout only once.
    i > 1 && push!(shown, Box(width(1px), height(66px), background(Ink.faded(t.line, 0.8))))
    push!(shown, group(v, g))
  end
  name = String(get(m.doc, "name", splitext(basename(v.path))[1]))
  doc = get(m.doc, "undo", 0) isa Number ? m.doc : JSON.Object()
  card!(v, :ribbon) do
    Column(width(grow=grow), panel_look(t)..., padding(8px, 6px), child_gap=6px, Alignment.Start,
      Row(width(grow=grow), child_gap=2px,
        tab.(tabs)...,
        Box(width(grow=grow)),
        (Designs.busy(m) && !m.trying ? (Box(padding(8px, 0px), words("Working…", 11.5px, color=t.dim)),) : ())...,
        Box(padding(8px, 0px), words(Designs.edited(m) ? name * " — edited" : name, 12px, color=t.dim)),
        icon_button(v, :undo, "arrow-counterclockwise", "Undo (⌘Z)"; act=e -> undo!(v), off=get(doc, "undo", 0) == 0),
        icon_button(v, :redo, "arrow-clockwise", "Redo (⇧⌘Z)"; act=e -> redo!(v), off=Designs.redoable(m) == 0),
        icon_button(v, :save, "save", "Save (⌘S)"; act=e -> save!(v), off=!Designs.edited(m))),
      Row(width(grow=grow), Alignment.Start, child_gap=8px, clip_x=true, shown...))
  end
end

"What went wrong with the last change, in a bar under the toolbar"
said(v::DesignView) = begin
  m = v.model
  words_ = Designs.stopped(m) ? "SolidCraft's program stopped. Close the design and open it again." : m.said
  isempty(words_) && return ()
  t = theme(v)
  bar = card!(v, :said) do
    Row(width(grow=grow), padding(12px, 8px), child_gap=10px, radius(8px), background(dark(t) ? colorant"rgb(92,44,44)" : colorant"rgb(253,232,230)"),
        border(1px, :solid, dark(t) ? colorant"rgb(140,66,66)" : colorant"rgb(240,170,160)"), Alignment.Start,
      Box(width(grow=grow), Alignment.Start, Text(words_, size=12px, color=t.text)),
      icon_button(v, :said_close, "x-lg", "Close"; act=e -> (m.said = ""), size=12px))
  end
  (Row(width(grow=grow), justify=Alignment.Center, Box(width(max=720px), bar)),)
end

# --- the browser ---------------------------------------------------------------------

const ROW_H = 26px

"A line of the browser"
browser_row(v::DesignView, key, depth, icon, name; on=false, dim=false, eye=nothing, act=nothing, twice=nothing, other=nothing, note="", tint=nothing) = begin
  t = theme(v)
  press!(v, key; act, twice, other) do hovered
    Row(width(grow=grow), height(ROW_H), padding(0px, 6px, 0px, 8px + 14px * depth), radius(5px), child_gap=7px,
        background(on ? t.select : hovered ? t.hover : clear),
      Glyph(icon, size=15px, color=dim ? Ink.faded(t.dim, 0.7) : t.dim, accent=tint),
      Box(words(name, 12.5px, color=dim ? t.dim : t.text)),
      (isempty(note) ? () : (Box(words(note, 11.5px, color=colorant"rgb(60,180,90)")),))...,
      Box(width(grow=grow)),
      (eye === nothing ? () : (eye,))...)
  end
end

"The eye at the end of a line of the browser, which shows and hides what the line names: a click calls `act`"
eye(v::DesignView, key, visible, act) = begin
  t = theme(v)
  press!(v, key; act=e -> act(), tip=visible ? "Hide" : "Show") do hovered
    Box(width(22px), height(22px), radius(5px), background(hovered ? t.select : clear),
      Glyph(visible ? "eye" : "eye-slash", size=14px, color=visible ? t.text : Ink.faded(t.dim, 0.7)))
  end
end

"A folder of the browser, with how many things it has. `shown` and `show` give it an eye for all of them."
folder(v::DesignView, name, count=nothing; icon=nothing, shown=nothing, show=nothing) = begin
  open = !(name in v.closed)
  t = theme(v)
  press!(v, (:folder, name); act=e -> (open ? push!(v.closed, name) : delete!(v.closed, name))) do hovered
    Row(width(grow=grow), height(ROW_H), padding(0px, 6px, 0px, 8px), radius(5px), child_gap=7px, background(hovered ? t.hover : clear),
      Glyph(open ? "chevron-down" : "chevron-right", size=10px, color=t.dim),
      (icon === nothing ? () : (Glyph(icon, size=15px, color=t.dim),))...,
      Box(words(count === nothing ? name : "$name ($count)", 12.5px, color=shown === false ? t.dim : t.text)),
      Box(width(grow=grow)),
      (show === nothing ? () : (eye(v, (:eye, :folder, name), shown, show),))...)
  end
end

"What the browser lists of the origin: the name that SolidCraft has for each thing, and its icon"
const ORIGIN_ROWS = (("O", "point"), ("X", "axis"), ("Y", "axis"), ("Z", "axis"), ("XY", "plane"), ("XZ", "plane"), ("YZ", "plane"))

"Show or hide one thing of the origin. While all of the origin is hidden, showing one thing shows only that one."
show_origin!(v::DesignView, name, visible) = begin
  m = v.model
  (visible && m.origin_hidden) || return Designs.show!(m, visible; items=Any[name])
  Designs.show!(m, true; folder="origin")
  Designs.show!(m, false; items=Any[n for (n, _) in ORIGIN_ROWS if n != name])
end

browser(v::DesignView) = begin
  t = theme(v)
  m = v.model
  active = Designs.editing(m)
  rows = Any[]
  look(turn, tilt) = e -> (v.eye = Scenes.fit(Scenes.Eye(v.eye.target, turn, tilt, v.eye.distance, v.eye.wide), Scenes.box(showing(v)), (v.area[3], v.area[4])))
  # The design's settings, and the views with names
  push!(rows, folder(v, "Document Settings"; icon="feature"))
  if !("Document Settings" in v.closed)
    push!(rows, browser_row(v, (:setting, :units), 1, "measure", "Units: " * String(get(m.doc, "units", "mm"))))
    push!(rows, browser_row(v, (:setting, :params), 1, "params", "Parameters ($(length(Designs.params(m))))"; on=v.panel == :params, act=e -> start!(v, "parameters")))
  end
  push!(rows, folder(v, "Named Views"; icon="perspective"))
  "Named Views" in v.closed || for (name, turn, tilt) in (("Top", -90.0, 90.0), ("Front", -90.0, 0.0), ("Right", 0.0, 0.0), ("Home", -35.0, 28.0))
    push!(rows, browser_row(v, (:named, name), 1, "orbit", name; act=look(turn, tilt)))
  end
  # The origin: its point, its three axes and its three planes
  whole = any(row -> Designs.origin_shown(m, row[1]), ORIGIN_ROWS)
  push!(rows, folder(v, "Origin"; icon="axis", shown=whole, show=() -> Designs.show!(m, !whole; folder="origin")))
  "Origin" in v.closed || for (name, icon) in ORIGIN_ROWS
    shown = Designs.origin_shown(m, name)
    push!(rows, browser_row(v, (:origin, name), 1, icon, name; dim=!shown, on=any(p -> p.kind == :plane && p.of == name, v.picked),
      eye=eye(v, (:eye, :origin, name), shown, () -> show_origin!(v, name, !shown)),
      act=icon == "plane" ? (e -> pick!(v, (kind=:plane, of=name, n=0, at=(0.0, 0.0, 0.0)), Keys.shft in e.window.keys)) : nothing))
  end
  bodies = Designs.bodies(m)
  if !isempty(bodies)
    any_shown = any(b -> get(b, "visible", true) === true, bodies)
    push!(rows, folder(v, "Bodies", length(bodies); shown=any_shown, show=() -> Designs.show!(m, !any_shown; folder="bodies")))
    "Bodies" in v.closed || for b in bodies
      name = String(b["name"])
      shown = get(b, "visible", true) === true
      push!(rows, browser_row(v, (:body, name), 1, "body", name; dim=!shown, on=any(p -> p.kind == :body && p.of == name, v.picked),
        tint=(own = get(m.colours, name, nothing); own === nothing ? nothing : RGB(own...)),
        eye=eye(v, (:eye, :body, name), shown, () -> Designs.show!(m, !shown; items=Any[name])),
        act=e -> pick!(v, (kind=:body, of=name, n=0, at=(0.0, 0.0, 0.0)), Keys.shft in e.window.keys),
        twice=e -> rename!(v, e.window, (:body, name), name, new -> Designs.change!(m, "body.rename", JSON.Object("body" => name, "name" => new)))))
    end
  end
  sketches = Designs.sketch_list(m)
  if !isempty(sketches)
    any_shown = any(s -> get(s, "visible", false) === true, sketches)
    push!(rows, folder(v, "Sketches", length(sketches); shown=any_shown, show=() -> Designs.show!(m, !any_shown; folder="sketches")))
    "Sketches" in v.closed || for s in sketches
      id, name = Int(s["id"]), String(s["name"])
      shown = get(s, "visible", false) === true
      push!(rows, browser_row(v, (:sketch, id), 1, "sketch", name; dim=!shown && id != active, on=id == active, note=id == active ? "(editing)" : "",
        eye=eye(v, (:eye, :sketch, id), shown, () -> Designs.show!(m, !shown; items=Any[id])),
        act=e -> nothing, twice=e -> edit_step!(v, id, e.window)))
    end
  end
  # The construction planes, axes and points
  made = [f for f in Designs.timeline(m) if f isa AbstractDict && startswith(String(get(f, "type", "")), "Construction") && get(f, "rolled_back", false) !== true]
  if !isempty(made)
    any_shown = any(f -> Designs.plane_shown(m, String(f["name"])), made)
    push!(rows, folder(v, "Construction", length(made); shown=any_shown, show=() -> Designs.show!(m, !any_shown; folder="construction")))
    "Construction" in v.closed || for f in made
      id, name = Int(f["id"]), String(f["name"])
      shown = Designs.plane_shown(m, name)
      flat = f["type"] == "ConstructionPlane"
      push!(rows, browser_row(v, (:made, id), 1, Ink.step_icon(String(f["type"])), name; dim=!shown, on=any(p -> p.kind == :plane && p.of == name, v.picked),
        eye=eye(v, (:eye, :made, id), shown, () -> Designs.show!(m, !shown; items=Any[name])),
        act=flat ? (e -> pick!(v, (kind=:plane, of=name, n=0, at=(0.0, 0.0, 0.0)), Keys.shft in e.window.keys)) : nothing,
        twice=e -> edit_step!(v, id, e.window)))
    end
  end
  isempty(bodies) && isempty(sketches) &&
    push!(rows, Box(padding(10px, 8px), Alignment.Start, Text("This design is empty. Start with New Sketch, or with a box from Create.", size=12px, color=t.dim)))
  room = max(120.0, v.area[4] - 300)
  tall = min(room, length(rows) * num(ROW_H) + 8 + (isempty(bodies) && isempty(sketches) ? 30 : 0))
  scroll = get!(() -> Scroll(width(grow=grow), height(grow=grow)), v.parts, :browser_scroll)
  card!(v, :browser) do
    Column(width(244px), panel_look(t)..., Alignment.Start,
      Row(width(grow=grow), height(36px), padding(12px, 0px), border(1px, :solid, Ink.faded(t.line, 0.7))[:bottom],
        Box(words("Browser", 13px, weight="Semibold")), Box(width(grow=grow))),
      Box(width(grow=grow), height(px(tall)), Alignment.Start,
        reuse!(scroll, Column(width(grow=grow), padding(4px), Alignment.Start, in_sight(rows, num(scroll.offset), tall)...))))
  end
end

"""
The lines of the browser that show when it has scrolled `top` px in a room
`tall` px high, and a few more, with room as high as the others in their
place. A design with 80 bodies has 100 lines, and laying all of them out on
each frame took as long as drawing the design.
"""
in_sight(rows, top, tall) = begin
  # Every line is ROW_H high, but for the one that says the design is empty
  all(r -> r isa Press, rows) || return rows
  line, pad, n = num(ROW_H), 4.0, length(rows)
  above = clamp(floor(Int, (top - pad) / line) - 2, 0, n)
  upto = clamp(ceil(Int, (top + tall - pad) / line) + 2, above, n)
  room(k) = k == 0 ? () : (Box(width(grow=grow), height(px(k * line))),)
  (room(above)..., rows[above+1:upto]..., room(n - upto)...)
end

"Ask for a new name of something, in a field over its line of the browser or its step of the history"
rename!(v::DesignView, window, key, name, done) = ask!(v, window, get(v.parts, key, nothing), name, done)

"""
Show a field to type in under the node `under`, or at the place `under` of the
window. Return gives `done` what was typed, and Escape or a click elsewhere
gives it nothing. With `code`, the field takes Julia code, and ⌘Return runs
it. When `done` gives words, they say what's wrong, and the field stays.
"""
ask!(v::DesignView, window, under, text, done; width=200px, code=false) = begin
  forget!(v, :ask)
  field = code ? code!(v, (:ask, time()); text) : input!(v, (:ask, time()); text)
  select_all!(field)
  room!(field, width - 12px)   # inside the popup's padding
  t = theme(v)
  asker = Asker(field=field, done=done, of=v)
  popup!(window, asker, anchor=under === nothing ? window.mouse : under, gap=4px, width=width, key=:ask, theme=t)
  focus(field)
  nothing
end

"The field that `ask!` shows"
@def mutable struct Asker <: SemanticUI
  field::Any = nothing
  done::Any = nothing
  of::Any = nothing
end
describe(a::Asker) = begin
  t = theme(a)
  shown = a.of isa DesignView ? something(outcome(a.of, a.field), Some(under(a.field))) : nothing
  Box(width(grow=grow), padding(6px), radius(8px), background(t.surface), border(1px, :solid, t.accent), shadow(0, 4, 14, RGBA(0, 0, 0, 0.3)),
      shown === nothing ? a.field : Column(width(grow=grow), child_gap=5px, Alignment.Start, a.field, shown))
end
onkey(a::Asker, e::KeyPress{Keys.enter}) = begin
  # With the list of parameters under the field, Return puts the lit one in
  plain(e) && names_key!(a.field, e.window, Keys.enter) && return handled
  # ⌘Return runs the code, and the field stays
  iscode(a.field) && held_keys(e.window) == (true, false, false, false) && return (run_field!(a.of, a.field); handled)
  text = strip(text_of(a.field))
  said = isempty(text) ? nothing : a.done(String(text))
  said isa String && return (wrong!(a.of, a.field, said); handled)
  close_popup!(e.window, :ask)
  focus(a.of)
  handled
end
onkey(::Asker, ::KeyPress{Keys.mouse_left}) = handled
# Esc hides the list of parameters under the field, and with no list it closes the field
onkey(a::Asker, e::KeyPress{Keys.escape}) = plain(e) && names_key!(a.field, e.window, Keys.escape) ? handled : nothing

# --- parameters offered in a field of code ---------------------------------------------
#
# While a name is typed in a field of Julia code, a list under the field
# offers the design's parameters whose names start with what's typed, or have
# a word that does: `thic` offers thickness, and `wall` offers inner_wall. The
# user's own parameters come first, then the lengths of the steps and of the
# sketches' dimensions, like d1. A field of a parameter doesn't offer that
# parameter. Each name has its value at its right, as the panel of parameters
# writes it, and a length of a step has its step's name too.
#
# The list shows only while a name is typed: a caret that moves, a selection,
# or a field that loses the keyboard takes it away. A name just after a number
# is a unit, like the mm of 10mm, so it gets no list. ↑ and ↓ light another
# name, Return or Tab puts the lit one in place of what's typed, and Esc hides
# the list until another name is typed. A click on a name puts it in too. The
# keys come here from the field: see `names_key!`.

const NAMES_KEY = :design_names
const NAMES_SHOWN = 8          # the most names in the list

"The list of parameters under a field of code: see \"parameters offered in a field of code\""
@def mutable struct Offers <: SemanticUI
  of::Any = nothing              # the design
  box::Any = nothing             # the field
  typed::Int = 0                 # how many characters of the name are typed
  names::Vector{Any} = Any[]     # each name with what's at its right
  lit::Int = 1
  rows::Vector{Any} = Any[]
end

"A name in the list of an `Offers`"
@def mutable struct Offer <: SemanticUI
  of::Any = nothing
  i::Int = 0
end

"The list of parameters that shows in each window, by the window's objectid"
const SHOWN_NAMES = Dict{UInt,Any}()

"""
The parameters of the design `v` that the text `before` the caret of a field
could be the start of the name of: how many characters of the name are typed,
and the names, each with the words at its right, the best first. A field of
the parameter `own` doesn't offer it. Nothing when no name is being typed, a
whole name is typed, or no name fits.
"""
offered(v::DesignView, before::AbstractString, own=nothing) = begin
  chars = collect(before)
  start = length(chars)
  while start > 0 && (isletter(chars[start]) || isdigit(chars[start]) || chars[start] in ('_', '!')); start -= 1 end
  # 2n is two times n, so a name starts after the digits
  while start < length(chars) && !(isletter(chars[start+1]) || chars[start+1] == '_'); start += 1 end
  start < length(chars) || return nothing
  # Just after a number, a name is its unit. After a dot it's a part of a value.
  start > 0 && (isdigit(chars[start]) || chars[start] == '.') && return nothing
  # Not in a comment or a string
  pieces = Expressions.parts(before, (comment=:comment, string=:string))
  !isempty(pieces) && last(pieces).second in (:comment, :string) && return nothing
  typed = lowercase(String(chars[start+1:end]))
  found = Any[]
  for p in every_param(v)
    name = String(something(get(p, "name", ""), ""))
    (isempty(name) || name == own) && continue
    low = lowercase(name)
    low == typed && return nothing
    fit = startswith(low, typed) ? 0 : any(w -> startswith(w, typed), split(low, '_', keepempty=false)) ? 1 : 2
    fit < 2 || continue
    # A length of a step or of a sketch's dimension, like d1, comes after the user's own parameters
    step = something(get(p, "source", "user"), "user") != "user"
    value = get(p, "value", nothing) isa Real ? Sketching.fixed(p["value"]) * " " * String(something(get(p, "unit", ""), "")) : ""
    note = step && get(p, "feature", nothing) isa String ? strip(string(p["feature"], "  ", value)) : strip(value)
    # d2 before d10
    push!(found, (fit, step, length(name), low, name => String(note)))
  end
  isempty(found) && return nothing
  (length(chars) - start, Any[last(f) for f in first(sort!(found, by=f -> f[1:4]), NAMES_SHOWN)])
end

"The parameter that the field `box` of the design `v` is the code of, or nothing. In the sheet of parameters, it's the caret's row."
own_param(v::DesignView, box) = begin
  box === get(v.parts, :param_sheet, nothing) && return caret_name(box)
  for (k, b) in v.parts
    b === box || continue
    k isa Tuple && length(k) == 3 && k[1] == :field && k[2] == "step" && return String(k[3])
    return nothing
  end
  nothing
end

"""
Where the list of parameters for the field `box` shows, when the name that's
typed is the last `n` characters before the caret: the place to show it under,
and how wide it is. It's under the field, and as wide.
"""
names_place(box, n) = (box, menu_width(box, 180px))

"The list of parameters that shows now in the window `w` for the field `box`, or nothing"
names_for(w, box) = (o = get(SHOWN_NAMES, objectid(w), nothing); o !== nothing && o.box === box ? o : nothing)

"Take the list of parameters away from the window `w`"
close_names!(w) = (delete!(SHOWN_NAMES, objectid(w)); close_popup!(w, NAMES_KEY); nothing)

"""
Keep the list of parameters under the field that has the keyboard up to date:
the list shows just after the text of the field changes, while a name is typed.
"""
offers!(v::DesignView) = begin
  w = part_window(v)
  w === nothing && return
  box = keyed(w.focus)
  ours = isfield(box) && iscode(box) && (box === get(v.parts, :named_box, nothing) || own_box(v, box))
  ours && (v.parts[:named_box] = box)
  now = ours ? (box, text_of(box), before_caret(box)) : nothing
  seen = get(v.parts, :named_seen, nothing)
  same = seen === now || (seen !== nothing && now !== nothing && seen[1] === now[1] && seen[2] == now[2] && seen[3] == now[3])
  same && return
  v.parts[:named_seen] = now
  shown = get(SHOWN_NAMES, objectid(w), nothing)
  # Only a change to the text shows the list. A caret that moves, a selection, or another field takes it away.
  found = now === nothing || now[3] === nothing || seen === nothing || seen[1] !== box || seen[2] == now[2] ? nothing : offered(v, now[3], own_param(v, box))
  hidden = get(v.parts, :named_hidden, nothing)
  if found !== nothing && hidden == (box, length(now[3]) - found[1])
    found = nothing   # Esc hid the list of this name
  elseif found !== nothing || now === nothing || seen === nothing || seen[1] !== box
    delete!(v.parts, :named_hidden)
  end
  if found === nothing
    shown !== nothing && shown.of === v && close_names!(w)
    return
  end
  n, names = found
  if shown !== nothing && shown.box === box
    shown.lit = names == shown.names ? clamp(shown.lit, 1, length(names)) : 1
    shown.typed, shown.names = n, names
    return
  end
  o = Offers(of=v, box=box, typed=n, names=names)
  SHOWN_NAMES[objectid(w)] = o
  # The keys stay with the field, and a click outside the list is the design's, as it is with no list
  under, wide = names_place(box, n)
  popup!(w, o, anchor=under, placement=:below, gap=4px, width=wide, key=NAMES_KEY, modal=false,
         onclose=() -> get(SHOWN_NAMES, objectid(w), nothing) === o && delete!(SHOWN_NAMES, objectid(w)), theme=theme(v))
  nothing
end

"True when `box` is one of the fields of the design `v`"
own_box(v::DesignView, box) = any(b -> b === box, values(v.parts))

"""
What a key does in the field `box` of the window `w` while its list of
parameters shows: ↑ and ↓ light another name, Return and Tab put the lit one
in, and Esc hides the list. True when the key was for the list.
"""
names_key!(box, w, K) = begin
  o = names_for(w, box)
  o === nothing && return false
  if K == Keys.down || K == Keys.up
    o.lit = mod1(o.lit + (K == Keys.down ? 1 : -1), length(o.names))
  elseif K == Keys.enter || K == Keys.tab
    take_name!(o, o.lit, w)
  elseif K == Keys.escape
    o.of.parts[:named_hidden] = (box, length(something(before_caret(box), "")) - o.typed)
    close_names!(w)
  else
    return false
  end
  redraw_in!(o.of, 0.0)
  true
end

"Put the name at row `i` of the list `o` in place of what's typed of it, and take the list away"
take_name!(o::Offers, i, w) = begin
  i in eachindex(o.names) && complete!(o.box, o.typed, first(o.names[i]))
  close_names!(w)
  focus(o.box)
  nothing
end

describe(o::Offers) = begin
  c = menu_colours(theme(o))
  length(o.rows) == length(o.names) || (o.rows = Any[Offer(of=o, i=i) for i in eachindex(o.names)])
  Box(width(grow=grow), padding(5px), radius(8px), background(c.frame), border(1px, :solid, c.line),
      shadow(0, 6, 16, RGBA(60 / 255, 45 / 255, 20 / 255, 0.2)), name="Parameters",
    Column(width(grow=grow), Alignment.Start, o.rows...))
end

describe(l::Offer) = begin
  o = l.of
  l.i <= length(o.names) || return Box(height(0px))
  c = menu_colours(theme(o))
  name, note = o.names[l.i]
  _, family = code_look(o.of)
  Row(width(grow=grow), height(24px), padding(7px, 0px), radius(5px), child_gap=10px, Alignment.Center,
      background(l.i == o.lit ? c.pick : c.frame),
    Box(Text(name, size=12px, family=family, color=c.ink, wrap=WrapMode.none)),
    Box(width(grow=grow)),
    Row(justify=Alignment.End, clip_x=true, words(note, 11px, color=c.dim)))
end

cursor(::Offer) = :hand
onmouse(l::Offer, ::MouseMove) = (l.of.lit = l.i; handled)
onkey(l::Offer, e::KeyPress{Keys.mouse_left}) = (take_name!(l.of, l.i, e.window); handled)
onkey(::Offer, ::KeyPress{Keys.mouse_right}) = handled

# --- the history ---------------------------------------------------------------------

const STEP_W = 30.0

"The menu of a step of the history"
step_menu(v::DesignView, f, window) = begin
  m = v.model
  id, name = Int(f["id"]), String(f["name"])
  off = get(f, "suppressed", false) === true
  items = ["pencil" => "Edit", "cursor-text" => "Rename", off ? "eye" => "Unsuppress" : "eye-slash" => "Suppress",
           "skip-backward" => "Roll the history to here", "-", "trash3" => "Delete"]
  # The history is at the foot of the editor, so the menu goes over the step
  step = get(v.parts, (:step, id), nothing)
  menu!(window, items, i -> begin
    i == 1 ? edit_step!(v, id, window) :
    i == 2 ? rename!(v, window, (:step, id), name, new -> Designs.change!(m, "timeline.rename", JSON.Object("feature" => id, "name" => new))) :
    i == 3 ? Designs.change!(m, "timeline.suppress", JSON.Object("feature" => id)) :
    i == 4 ? Designs.change!(m, "timeline.roll_to", JSON.Object("feature" => id)) :
    i == 6 ? Designs.change!(m, "timeline.delete", JSON.Object("feature" => id)) : nothing
  end; anchor=something(step, window.mouse), placement=:top, gap=6px, width=220px, title=uppercase(name), t=theme(v))
end

history(v::DesignView) = begin
  t = theme(v)
  m = v.model
  steps = Designs.timeline(m)
  marker = Designs.marker(m)
  roll(to) = Designs.change!(m, "timeline.roll_to", JSON.Object("position" => to isa Number ? clamp(to, 0, length(steps)) : to))
  item(i, f) = begin
    id, name = Int(f["id"]), String(f["name"])
    back = i > marker || get(f, "rolled_back", false) === true
    off = get(f, "suppressed", false) === true
    bad = get(f, "error", nothing) isa String
    warned = get(f, "warning", nothing) isa String
    on = any(p -> p.kind == :step && p.n == id, v.picked)
    tip = bad ? name * ": " * String(f["error"]) : off ? name * " (suppressed)" : name
    press!(v, (:step, id); tip, act=e -> pick!(v, (kind=:step, of=name, n=id, at=(0.0, 0.0, 0.0)), false),
           twice=e -> edit_step!(v, id, e.window), other=e -> step_menu(v, f, e.window)) do hovered
      # As wide as STEP_W says, however many steps there are: a history that's wider than the room moves with the wheel
      Box(width(min=26px, preferred=26px), height(26px), radius(5px),
          background(on ? t.select : hovered ? t.hover : Ink.faded(t.hover, 0.6)),
          border(1px, :solid, bad ? colorant"rgb(220,80,70)" : warned ? colorant"rgb(220,160,50)" : on ? t.accent : Ink.faded(t.line, 0.9)),
        Glyph(Ink.step_icon(String(f["type"])), size=17px, color=Ink.faded(t.text, back || off ? 0.35 : 1.0),
              accent=Ink.faded(t.accent, back || off ? 0.3 : 1.0)))
    end
  end
  mark = Box(width(min=3px, preferred=3px), height(30px), radius(2px), background(t.accent))
  shown = Any[]
  for (i, f) in enumerate(steps)
    i == marker + 1 && push!(shown, mark)
    push!(shown, item(i, f))
  end
  marker >= length(steps) && push!(shown, mark)
  # A history that's wider than the window moves left with the wheel
  room = max(100.0, v.area[3] - 290)
  v.along = clamp(v.along, 0.0, max(0.0, length(steps) * STEP_W + 20 - room))
  # Only the steps that can show are laid out. Those to their left are room of the same width.
  x, xs = 0.0, Float64[]
  for item in shown
    push!(xs, x)
    x += (item === mark ? 3.0 : STEP_W - 4) + 4
  end
  from = something(findfirst(i -> xs[i] + STEP_W >= v.along - 2STEP_W, eachindex(xs)), length(shown) + 1)
  upto = something(findlast(<=(v.along + v.area[3]), xs), 0)
  shown = from > upto ? Any[] : Any[(from > 1 ? (Box(width(min=px(xs[from] - 4), preferred=px(xs[from] - 4))),) : ())..., shown[from:upto]...]
  card!(v, :history) do
    Row(width(grow=grow), height(44px), panel_look(t)..., padding(12px, 0px), child_gap=10px,
      Box(words("History", 13px, weight="Semibold")),
      Row(child_gap=0px,
        icon_button(v, :first, "skip-start-fill", "Roll back to the start"; act=e -> roll(0), size=13px),
        icon_button(v, :back, "caret-left-fill", "Roll back one step"; act=e -> roll(marker - 1), size=12px),
        icon_button(v, :on, "caret-right-fill", "Roll on one step"; act=e -> roll(marker + 1), size=12px),
        icon_button(v, :last, "skip-end-fill", "Roll on to the end"; act=e -> roll("end"), size=13px)),
      Row(width(grow=grow), height(44px), Alignment.Center, justify=Alignment.Start, clip=true,
        Row(child_gap=4px, offset_x=px(-v.along), shown...)))
  end
end

"The buttons under the design that choose how it's seen"
views(v::DesignView) = begin
  t = theme(v)
  look(turn, tilt) = e -> (v.eye = Scenes.fit(Scenes.Eye(v.eye.target, turn, tilt, v.eye.distance, v.eye.wide), Scenes.box(showing(v)), (v.area[3], v.area[4])))
  card!(v, :views) do
    Row(height(38px), panel_look(t)..., padding(6px, 0px), child_gap=2px,
      icon_button(v, :fit, "fit", "Show all of the design"; act=e -> fit!(v)),
      icon_button(v, :home, "house", "The first view"; act=look(-35.0, 28.0)),
      Box(width(1px), height(20px), background(t.line)),
      word_view(v, "Front", look(-90.0, 0.0)), word_view(v, "Top", look(-90.0, 90.0)), word_view(v, "Right", look(0.0, 0.0)),
      Box(width(1px), height(20px), background(t.line)),
      icon_button(v, :wide, "perspective", v.eye.wide > 0 ? "Draw far things as big as near ones" : "Draw far things smaller"; on=v.eye.wide > 0,
                  act=e -> (v.eye = flat_or_deep(v.eye, (v.area[3], v.area[4])))))
  end
end

word_view(v, name, act) = begin
  t = theme(v)
  press!(v, (:view, name); act, tip="Look from the " * lowercase(name)) do hovered
    Box(height(28px), padding(8px, 0px), radius(6px), background(hovered ? t.hover : clear), words(name, 11.5px, color=t.dim))
  end
end

"The same view with far things as big as near ones, or the other way round"
flat_or_deep(e::Scenes.Eye, size) = begin
  # What's at the target stays as big as it was
  e.wide > 0 ? Scenes.Eye(e.target, e.turn, e.tilt, 2e.distance * tand(e.wide / 2), 0.0) :
               Scenes.Eye(e.target, e.turn, e.tilt, e.distance / (2tand(16.0)), 32.0)
end

"The bodies that show"
showing(v::DesignView) = filter(Designs.shows(v.model), v.model.shapes)

"Show all of the design, as it's turned now. A turn goes round the point under the mouse again."
fit!(v::DesignView) = begin
  delete!(v.parts, :pivot)
  s = sketch(v)
  if s !== nothing && isempty(showing(v))
    b = Sketching.bounds(s)
    f = Sketching.Frame(s["plane"])
    b === nothing || (v.eye = Scenes.fit(v.eye, (min.(Sketching.world(f, b[1]), Sketching.world(f, b[2])), max.(Sketching.world(f, b[1]), Sketching.world(f, b[2]))), (v.area[3], v.area[4])))
  else
    v.eye = Scenes.fit(v.eye, Scenes.box(showing(v)), (v.area[3], v.area[4]))
  end
  v
end

# --- commands ------------------------------------------------------------------------

"The letter that starts a command, while the design has the keyboard: in a sketch, and out of one"
const SKETCH_KEYS = Dict('l' => "sketch.line", 'r' => "sketch.rectangle.two_point", 'c' => "sketch.circle.center", 'd' => "sketch.dimension",
                         't' => "sketch.trim", 'x' => "sketch.construction", 'p' => "sketch.project", 'o' => "sketch.offset")
const MODEL_KEYS = Dict('e' => "solid.extrude", 'f' => "solid.fillet", 'h' => "solid.hole", 'q' => "solid.press_pull", 'm' => "solid.move")
const KEYS_OF = Dict{String,String}(id => uppercase(string(k)) for (k, id) in merge(SKETCH_KEYS, MODEL_KEYS))

same(a, b) = a.kind == b.kind && a.of == b.of && a.n == b.n

"Select `what`. With `more`, it's selected with what's selected already, or no longer selected if it was."
pick!(v::DesignView, what, more=false) = begin
  i = findfirst(p -> same(p, what), v.picked)
  if more
    i === nothing ? push!(v.picked, what) : deleteat!(v.picked, i)
  else
    only = length(v.picked) == 1 && i !== nothing
    empty!(v.picked)
    only || push!(v.picked, what)
  end
  v
end

"The ids of the points and curves of the sketch that are selected, in the order they were clicked"
chosen(v::DesignView, kinds=(:point, :curve)) = String[p.of for p in v.picked if p.kind in kinds]

"Start the command `id`: a button of the toolbar or a key does"
start!(v::DesignView, id, window=nothing) = begin
  m = v.model
  id == "parameters" && return (v.panel = v.panel == :params ? :none : :params; v)
  if id in ("sketch.finish", "sketch.cancel")
    leave!(v)
    empty!(v.picked)
    # The design is seen again as it was before the sketch was opened
    haskey(v.parts, :eye_before) && (v.eye = pop!(v.parts, :eye_before))
    return Designs.change!(m, id)
  end
  if haskey(Commands.TOOLS, id)
    leave!(v)
    forget!(v, :toolfield)
    v.tool = Commands.TOOLS[id]
    return v
  end
  if id == "sketch.dimension"
    leave!(v)
    # What's selected gets its dimension at once. With nothing selected, the next clicks choose what to measure.
    isempty(chosen(v)) ? (v.tool = :dimension) : dimension!(v, nothing)
    return v
  end
  id in ("sketch.trim", "sketch.extend", "sketch.project") && return (leave!(v); empty!(v.picked); v.tool = Symbol(last(split(id, '.'))); v)
  if id == "sketch.construction"
    # What's selected changes between normal and construction. With nothing selected, what's drawn next does.
    curves = chosen(v, (:curve,))
    isempty(curves) ? (v.building = !v.building) : Designs.change!(m, id, JSON.Object("curves" => curves))
    return v
  end
  startswith(id, "sketch.constraint.") && return constrain!(v, id)
  id == "sketch.auto_constrain" && return Designs.change!(m, id)
  open_form!(v, id)
end

"Put the constraint of the command `id` on what's selected in the sketch"
constrain!(v::DesignView, id) = begin
  m = v.model
  ids = chosen(v)
  kind = last(split(id, '.'))
  need = something(get(Dict(Commands.CONSTRAINTS), id, nothing), 2)
  if length(ids) < need
    m.said = need == 1 ? "Select a line or a point of the sketch first, then click the constraint." :
             "Select $(need == 2 ? "two" : "three") things of the sketch first, then click the constraint. Hold ⇧ to select one more."
    return v
  end
  lines = chosen(v, (:curve,))
  params = kind == "horizontal_vertical" ? (length(lines) >= 1 ? nothing : JSON.Object("points" => ids[1:2])) :
           kind == "fix" ? JSON.Object("entities" => ids) :
           kind == "symmetry" ? JSON.Object("a" => ids[1], "b" => ids[2], "line" => ids[3]) :
           kind == "equal" && length(ids) > 2 ? JSON.Object("curves" => ids) : JSON.Object("a" => ids[1], "b" => ids[2])
  if params === nothing
    # Each selected line is made level or upright, whichever it's nearer to
    Designs.batch!(m, [id => JSON.Object("line" => l) for l in lines])
  else
    Designs.change!(m, id, params)
  end
  empty!(v.picked)
  v
end

"""
Give what's selected in the sketch a dimension. `at` is where its words go in
the sketch, or nothing for where SolidCraft puts them. A field to type its
length in opens when it's made.
"""
dimension!(v::DesignView, at) = begin
  m = v.model
  ids = chosen(v)
  isempty(ids) && return v
  params = JSON.Object("entities" => ids[1:min(2, end)])
  at === nothing || (params["text_at"] = Any[at[1], at[2]])
  Designs.change!(m, "sketch.dimension", params; then=(answer, problem) -> begin
    made = answer isa AbstractDict ? get(get(answer, "created", JSON.Object()), "dimensions", Any[]) : Any[]
    isempty(made) || (v.parts[:new_size] = String(made[1]))
  end)
  empty!(v.picked)
  v
end

"Open the form of the command `id`"
open_form!(v::DesignView, id) = begin
  m = v.model
  c = get(m.commands, id, nothing)
  c === nothing && !haskey(Commands.SPECS, id) && return v
  # A command with no form of its own gets one from what SolidCraft says of its parameters
  if !haskey(Commands.SPECS, id) && !haskey(v.described, id)
    v.described[id] = nothing
    Designs.Engines.call!(m.engine, "describe_command", JSON.Object("id" => id)) do answer, problem
      v.described[id] = answer isa AbstractDict ? answer : false
      v.form !== nothing && v.form.spec.command == id && isempty(v.form.shows) && open_form!(v, id)
    end
  end
  spec = c === nothing ? Commands.SPECS[id] : Commands.spec(c, get(v.described, id, nothing))
  keep = v.picked
  leave!(v)
  forget!(v, :field)
  f = Form(spec)
  for field in spec.fields
    Commands.picks(field) || (f.values[field.key] = field.default; continue)
    f.values[field.key] = field.kind == :plane ? field.default : Any[]
    f.shows[field.key] = field.kind == :plane && field.default isa String ? Any[(kind=:plane, of=field.default, n=0, at=(0.0, 0.0, 0.0))] : Any[]
  end
  # What's selected fills the fields that it suits
  for p in keep, field in spec.fields
    suits = (field.kind == :edges && p.kind == :edge) || (field.kind in (:faces, :face) && p.kind == :face) || (field.kind in (:bodies, :body) && p.kind == :body) ||
            (field.kind == :plane && p.kind == :plane) || (field.kind == :profiles && flat_face(v.model, p))
    suits || continue
    (Commands.many(field) || field.kind == :plane || isempty(f.values[field.key])) && take!(f, field, p)
    break
  end
  # In a sketch, a command like Fillet goes on what's selected there
  if startswith(id, "sketch.")
    points, curves = chosen(v, (:point,)), chosen(v, (:curve,))
    id == "sketch.offset" ? (f.extra["curves"] = curves) :
    !isempty(points) ? (f.extra[length(points) == 1 ? "point" : "points"] = length(points) == 1 ? points[1] : points) :
    length(curves) >= 2 && (f.extra["a"] = curves[1]; f.extra["b"] = curves[2])
  end
  i = findfirst(field -> Commands.picks(field) && field.kind != :plane && !field.optional && isempty(f.values[field.key]), spec.fields)
  i === nothing && (i = findfirst(Commands.picks, spec.fields))
  f.active = i === nothing ? "" : spec.fields[i].key
  empty!(v.picked)
  v.form = f
  v
end

"What a click on `p` sends for the field `field`"
sent(field::Commands.Field, p) =
  field.kind in (:bodies, :body) ? p.of :
  field.kind == :profiles ? (p.kind == :face ? Any[p.at...] : JSON.Object("point" => Any[p.at[1], p.at[2]])) :
  field.kind == :plane ? (p.kind == :plane ? p.of : JSON.Object("face" => Any[p.at...])) : Any[p.at...]

"True when `p` is a flat face of a body, which Extrude and Revolve take in place of a sketch's profile"
flat_face(m, p) = p.kind == :face && any(s -> s.name == p.of && 1 <= p.n <= length(s.flat) && s.flat[p.n], m.shapes)

"True when the profiles `p` and `q` go in one command: regions of one sketch, or flat faces of one body"
together(p, q) = p.kind == q.kind && (p.kind == :face ? p.of == q.of : p.n == q.n)

"Put the click on `p` in the field `field` of the form `f`. A second click on the same thing takes it out again."
take!(f::Form, field::Commands.Field, p) = begin
  shows = f.shows[field.key]
  i = findfirst(q -> same(q, p), shows)
  if field.kind == :plane
    f.values[field.key] = sent(field, p)
    empty!(shows)
    push!(shows, p)
  elseif i !== nothing && Commands.many(field)
    deleteat!(shows, i)
    deleteat!(f.values[field.key], i)
  else
    alone = !Commands.many(field) || (field.kind == :profiles && (!all(q -> together(q, p), shows) || (p.kind == :face && f.spec.command == "solid.revolve")))
    alone && (empty!(shows); empty!(f.values[field.key]))
    push!(shows, p)
    push!(f.values[field.key], sent(field, p))
  end
  f.problem = ""
  f
end

"What the form `f` holds now: its choices, its clicks, and what's typed in its fields"
held(v::DesignView, f::Form) = begin
  values = copy(f.values)
  for field in f.spec.fields
    (Commands.picks(field) || field.kind in (:flag, :choice)) && continue
    box = get(v.parts, (:field, f.spec.command, field.key), nothing)
    values[field.key] = box === nothing ? field.default : text_of(box)
  end
  values
end

"""
What the form `f` asks for now: `(command, parameters, readings)` as
SolidCraft takes them, or words that say what's still missing or wrong, or
nothing when the form of a step has no change. The parameters have the
numbers that the code of the fields came to. `readings` has what
`read_code` said of each field of code, by the parameter that it's for.
"""
request(v::DesignView, f::Form) = begin
  readings = Dict{String,Any}()
  if f.step !== nothing
    # A step that's changed gets each of its lengths and angles that was changed, as it's typed now
    changes = JSON.Object()
    for input in f.inputs
      param = String(input["param"])
      box = get(v.parts, (:field, "step", param), nothing)
      (box === nothing || isempty(strip(text_of(box))) || strip(text_of(box)) == strip(String(get(input, "code", input["expression"])))) && continue
      kind = unit_kind(get(input, "unit", ""))
      kind == :text && (changes[param] = String(strip(text_of(box))); continue)
      r = read_code(v, text_of(box), kind, String(get(input, "label", param)))
      r isa String && return r
      changes[param] = r.sent
      readings[param] = r
    end
    return isempty(changes) ? nothing : ("parameters.change", JSON.Object("changes" => changes), readings)
  end
  read(field, text) = (r = read_code(v, text, field.kind, field.label); r isa String ? r : (readings[field.key] = r; Some(r.sent)))
  params = Commands.params(f.spec, held(v, f); read)
  params isa String && return params
  merge!(params, f.extra)
  # SolidCraft finds each region of a sketch from a place inside it, and needs to know which sketch.
  # Flat faces of a body go in place of a sketch's regions, each by a point on it: Extrude takes several, Revolve one.
  regions = get(f.shows, "profiles", Any[])
  if !isempty(regions) && regions[1].kind == :face
    delete!(params, "profiles")
    points = Any[Any[p.at...] for p in regions]
    f.spec.command == "solid.revolve" ? (params["face"] = points[1]) : (params["faces"] = points)
    params["face_body"] = regions[1].of
  elseif !isempty(regions)
    params["sketch"] = regions[1].n
  end
  (f.spec.command, params, readings)
end

"Run the command of the form that's open"
apply!(v::DesignView) = begin
  f, m = v.form, v.model
  f === nothing && return v
  want = request(v, f)
  want === nothing && return (v.form = nothing; v)
  want isa String && return (f.problem = want; v)
  command, params, readings = want
  before = Designs.undos(m)
  agree!(v, readings) do agreed
    # SolidCraft keeps the code itself where it comes to what Julia got, and then follows the parameters that it names
    into = command == "parameters.change" ? params["changes"] : params
    for (k, r) in readings
      k in agreed && haskey(into, k) && (into[k] = r.solid)
    end
    # A new sketch is opened to draw in, and seen flat
    command == "sketch.create" && (v.parts[:eye_before] = v.eye; v.parts[:look_at] = :new)
    Designs.change!(m, command, params; quiet=true, then=(answer, problem) -> begin
      problem === nothing || command != "sketch.create" || (delete!(v.parts, :look_at); delete!(v.parts, :eye_before))
      problem === nothing ? (v.form === f && (v.form = nothing); empty!(v.picked)) : (f.problem = problem)
      problem === nothing && note!(v, f.step === nothing ? answer : nothing, readings, agreed, before)
    end)
  end
  v
end

"""
Keep what the design shows of the open form's command up to date. Ladder
works out what most commands make itself, at once, as the form changes: see
preview.jl. For any other command, when the form has what the command needs
and has stayed the same for a quarter of a second, SolidCraft's program tries
it: see `Designs.try!`. The picture then shows the bodies as the command would
leave them.
"""
preview!(v::DesignView) = begin
  f, m = v.form, v.model
  m === nothing && return
  (f === nothing || !v.previews) && return Designs.forget!(m)
  want = Designs.editing(m) === nothing ? request(v, f) : nothing
  want = want isa Tuple && Commands.tried(want[1]) ? want : nothing
  key = want === nothing ? nothing : want[1] * " " * JSON.json(want[2])
  key == f.key || (f.key = key; f.since = time())
  key === nothing && return Designs.forget!(m)
  trial = m.trial
  trial !== nothing && trial.key == key && return
  made = Previews.made(want[1], want[2], want[3], f.shows, showing(v), m.sketches; arrangement=s -> arrangement(v, s))
  made === nothing || return (Designs.made!(m, key, made); nothing)
  # A command that's tried takes away what could be redone, so none is tried while there's a step to redo
  (m.trying || Designs.busy(m) || Designs.redoable(m) > 0) && return
  wait = 0.25 - (time() - f.since)
  wait > 0 && return redraw_in!(v, wait)
  Designs.try!(m, key, want[1], want[2])
  redraw_in!(v, 0.016)
  nothing
end

"Open the step `id` of the history to change it: a sketch to draw in, and any other step as a form of its lengths"
edit_step!(v::DesignView, id, window=nothing) = begin
  m = v.model
  i = findfirst(f -> Int(f["id"]) == id, Designs.timeline(m))
  i === nothing && return v
  step = Designs.timeline(m)[i]
  leave!(v)
  empty!(v.picked)
  if step["type"] == "Sketch"
    Designs.editing(m) === nothing ? (v.parts[:eye_before] = v.eye) : Designs.change!(m, "sketch.finish")
    v.parts[:look_at] = id
    return Designs.change!(m, "sketch.edit", JSON.Object("sketch" => id))
  end
  Designs.ask!(m, "timeline.inspect", JSON.Object("feature" => id)) do answer, problem
    answer isa AbstractDict || return (m.said = something(problem, "SolidCraft said nothing of that step."))
    inputs = Any[i for i in get(answer, "inputs", Any[]) if i isa AbstractDict && get(i, "param", nothing) isa String]
    # Its field shows its text as Julia code, or the code that its comment keeps
    foreach(i -> i["code"] = Expressions.field_code(i["expression"], param_note(v, i["param"])), inputs)
    forget!(v, :field)
    spec = Commands.Spec("", String(step["name"]), Ink.step_icon(String(step["type"])), Commands.Field[], "")
    v.form = Form(spec, id, inputs)
  end
  v
end

"Turn the eye to look straight at the plane of the sketch `s`, with all of the sketch in view"
look_at!(v::DesignView, s) = begin
  f = Sketching.Frame(s["plane"])
  n = Sketching.normal(f)
  tilt = asind(clamp(n[3], -1.0, 1.0))
  turn = abs(n[3]) > 0.999 ? atand(-f.x[1] * sign(n[3]), f.x[2] * sign(n[3])) : atand(n[2], n[1])
  size = (v.area[3], v.area[4])
  b = Sketching.bounds(s)
  low, high = b === nothing ? ((-30.0, -30.0), (30.0, 30.0)) : b
  corners = [Sketching.world(f, p) for p in ((low[1], low[2]), (high[1], low[2]), (low[1], high[2]), (high[1], high[2]))]
  box = (reduce((a, b) -> min.(a, b), corners), reduce((a, b) -> max.(a, b), corners))
  shapes = showing(v)
  isempty(shapes) || (box = (min.(box[1], Scenes.box(shapes)[1]), max.(box[2], Scenes.box(shapes)[2])))
  v.eye = Scenes.fit(Scenes.Eye(v.eye.target, turn, tilt, v.eye.distance, v.eye.wide), box, size)
  v
end

# --- the panel at the right ----------------------------------------------------------

const SIDE_W = 272px     # how wide the panel is, unless the text of a field in it needs more room
const LABEL_W = 98px
const FIELD_H = 28px
const SIDE_PAD = 24px    # of the panel's width, what's beside its rows: their padding at the left and the right
const LABELLED = SIDE_PAD + LABEL_W + 8px   # of the panel's width, what's beside a field in a row that `labelled` makes

side(v::DesignView) = v.panel == :params ? (params_card(v),) : v.form !== nothing ? (form_card(v),) : sketch(v) !== nothing ? (sketch_card(v),) : ()

"Is `x` a field to type in?"
isfield(x) = x isa TextInput

"""
How wide the panel at the right is, for the fields in `fields`: pairs of a
field and how much of the panel's width is beside it. It's as wide as the
field that needs the most room needs, but never narrower than `SIDE_W` or
wider than half the design. Each field is told how wide it is, so a field
whose text is longer than that goes on to another line. A field is laid out
as soon as it's put in a row, so a panel calls this before it makes its rows,
and again after, for the fields that it made.
"""
side_width!(v::DesignView, fields) = begin
  most = max(num(SIDE_W), v.area[3] / 2)
  # A little more, for the scrollbar of a form that's taller than its room
  wide = clamp(maximum((wants(box) + num(beside) + 4 for (box, beside) in fields); init=0.0), num(SIDE_W), most)
  for (box, beside) in fields
    room!(box, px(wide - num(beside) - 4))
  end
  v.parts[:side_w] = wide
  px(wide)
end

"How wide the panel at the right was when it was last shown"
side_w(v::DesignView) = px(get(v.parts, :side_w, num(SIDE_W)))

"The panel at the right, as SolidCraft's forms are: a line with its name, its rows, and under them a band with its buttons. It's `wide` across."
side_card(v::DesignView, key, icon, title, close, rows...; foot=(), wide=SIDE_W) = begin
  t = theme(v)
  card!(v, key) do
    Column(width(wide), panel_look(t)..., clip=true, Alignment.Start,
      Row(width(grow=grow), height(40px), padding(0px, 6px, 0px, 12px), child_gap=8px, border(1px, :solid, Ink.faded(t.line, 0.7))[:bottom],
        Glyph(icon, size=17px), Box(words(title, 13.5px, weight="Semibold")), Box(width(grow=grow)),
        (close === nothing ? () : (icon_button(v, (key, :close), "x-lg", "Close"; act=close, size=12px),))...),
      # A form that's taller than the room under the toolbar scrolls
      Scroll(width(grow=grow), height(max=px(max(160.0, v.area[4] - 250))), key=(key, :rows),
        Column(width(grow=grow), padding(12px, 10px), child_gap=7px, Alignment.Start, rows...)),
      # What's under the rows stays in sight while they scroll: the buttons of a form
      (isempty(foot) ? () : (Column(width(grow=grow), padding(12px, 10px), child_gap=8px, Alignment.Start,
                                    background(Ink.mixed(t.surface, colorant"black", dark(t) ? 0.16 : 0.035)), border(1px, :solid, Ink.faded(t.line, 0.7))[:top], foot...),))...)
  end
end

"A row of a form: what it asks for at the left, and the field at the right"
labelled(v, label, thing) = begin
  t = theme(v)
  Row(width(grow=grow), child_gap=8px, Row(width(LABEL_W), justify=Alignment.Start, clip_x=true, words(label, 12px)), Box(width(grow=grow), Alignment.Start, thing))
end

"How a field of a form looks: `on` while it takes the clicks in the design"
field_look(t, on=false, hovered=false) =
  (height(FIELD_H), radius(5px), border(1px, :solid, on ? t.accent : hovered ? Ink.mixed(t.line, t.text, 0.25) : t.line),
   background(on ? Ink.faded(t.accent, 0.13) : Ink.mixed(t.surface, colorant"black", dark(t) ? 0.2 : 0.03)))

"A field that shows one of `options`, and lists them all in a menu when it's clicked"
choice(v::DesignView, key, options, now, set) = begin
  t = theme(v)
  i = findfirst(o -> o.first == now, options)
  press!(v, (key, :menu); act=e -> menu!(e.window, ["" => o.second for o in options], n -> set(options[n].first);
                                         anchor=v.parts[(key, :menu)], width=menu_width(v.parts[(key, :menu)], 120px), now=something(i, 0), t)) do hovered
    Row(width(grow=grow), field_look(t, false, hovered)..., padding(9px, 0px),
      Box(words(i === nothing ? "" : options[i].second, 12px)), Box(width(grow=grow)), Glyph("chevron-down", size=10px, color=t.dim))
  end
end

"A box to tick. The box is at the left of its words, or at the right of the row when `right`."
tick(v::DesignView, key, label, on, set; right=false) = begin
  t = theme(v)
  press!(v, key; act=e -> set(!on)) do hovered
    box = Box(width(15px), height(15px), radius(3.5px), background(on ? t.accent : clear), border(1.5px, :solid, on ? t.accent : hovered ? t.text : t.dim),
      (on ? (Glyph("check-lg", size=10px, color=t.on_accent),) : ())...)
    right ? Row(width(grow=grow), height(26px), justify=Alignment.Start, Box(words(label, 12px)), Box(width(grow=grow)), box) :
            Row(width(grow=grow), height(26px), child_gap=9px, justify=Alignment.Start, box, Box(words(label, 12px)))
  end
end

"The line that starts a part of a form, like Options. A click closes the part, or opens it."
section_head(v::DesignView, f::Form, name) = begin
  t = theme(v)
  open = !(name in f.closed)
  press!(v, (:section, name); act=e -> (open ? push!(f.closed, name) : delete!(f.closed, name))) do hovered
    Row(width(grow=grow), height(24px), child_gap=7px,
      Glyph(open ? "chevron-down" : "chevron-right", size=9px, color=t.dim),
      Box(words(uppercase(name), 10.5px, color=hovered ? t.text : t.dim, weight="Semibold")),
      Box(width(grow=grow), height(1px), background(Ink.faded(t.line, 0.8))))
  end
end

"What a field that's clicked says of its clicks"
count_words(field::Commands.Field, shows) = begin
  n = length(shows)
  n == 0 && return "Select"
  field.kind == :plane && return shows[1].kind == :plane ? String(shows[1].of) : "1 face"
  one = field.kind in (:faces, :face) ? "face" : field.kind == :edges ? "edge" : field.kind in (:bodies, :body) ? "body" :
        field.kind == :profiles ? (shows[1].kind == :face ? "face" : "profile") : "place"
  n == 1 ? "1 $one" : "$n $(one == "body" ? "bodies" : one * "s")"
end

"The planes that a form can name: the three of the origin, and the construction planes"
plane_names(v::DesignView) = vcat(Commands.PLANES, Pair{Any,String}[p.name => p.name for p in v.model.planes])

field_row(v::DesignView, f::Form, field::Commands.Field) = begin
  t = theme(v)
  key = (:field, f.spec.command, field.key)
  if field.kind == :flag
    return tick(v, key, field.label, f.values[field.key] === true, on -> (f.values[field.key] = on))
  elseif field.kind == :choice
    return labelled(v, field.label, choice(v, key, field.options, f.values[field.key], value -> (f.values[field.key] = value)))
  elseif Commands.picks(field)
    active = f.active == field.key
    shows = f.shows[field.key]
    n = length(shows)
    flat = field.kind == :plane
    # A plane has a menu of the planes with names too. What's chosen there shows in the design as a click on it would.
    menu = flat ? (press!(v, (key, :planes); tip="Choose a plane by its name", act=e -> begin
      names = plane_names(v)
      now = something(findfirst(o -> o.first == f.values[field.key], names), 0)
      menu!(e.window, ["" => o.second for o in names], i -> begin
        f.values[field.key] = names[i].first
        empty!(shows)
        push!(shows, (kind=:plane, of=String(names[i].first), n=0, at=(0.0, 0.0, 0.0)))
        f.problem = ""
      end; anchor=v.parts[key], width=menu_width(v.parts[key], 120px), now, t)
    end) do hovered
      Box(width(22px), height(22px), radius(4px), background(hovered ? t.select : clear), Glyph("chevron-down", size=10px, color=t.dim))
    end,) : ()
    clicked = press!(v, key; act=e -> (f.active = field.key)) do hovered
      Row(width(grow=grow), field_look(t, active, hovered)..., padding(0px, 3px, 0px, 9px),
        Box(words(count_words(field, shows), 12px, color=n == 0 ? t.dim : t.text)), Box(width(grow=grow)),
        (n == 0 || flat ? () : (icon_button(v, (key, :clear), "x", "Clear"; size=12px, act=e -> begin
          empty!(shows)
          f.values[field.key] = Any[]
          f.active = field.key
        end),))...,
        menu...)
    end
    return labelled(v, field.label, clicked)
  end
  if Commands.iscode(field)
    # SolidCraft's way of writing a length, like 10 mm, is Julia's in the field: 10mm
    box = code!(v, key; text=field.default isa AbstractString ? Expressions.julia_code(field.default) : "", placeholder=field.optional ? "optional" : "")
    return code_row(v, field.label, box)
  end
  box = input!(v, key; text=field.default isa AbstractString ? field.default : "", placeholder=field.optional ? "optional" : "")
  field.kind == :json ? Column(width(grow=grow), child_gap=4px, Alignment.Start, Box(words(field.label, 12px)), Box(width(grow=grow), box)) : labelled(v, field.label, box)
end

form_card(v::DesignView) = begin
  t = theme(v)
  f = v.form
  m = v.model
  # Each field is laid out as it's put in its row, so it's told how wide it is first. A field that's new is told at the end.
  side_width!(v, form_fields(v, f))
  rows = Any[]
  parts = Dict{String,Vector{Any}}()
  if f.step === nothing
    for field in f.spec.fields
      push!(get!(() -> Any[], parts, Commands.section(field)), field_row(v, f, field))
    end
    append!(rows, get(parts, "", Any[]))
    any(field -> field.kind == :profiles, f.spec.fields) && isempty(m.sketches) &&
      push!(rows, Box(width(grow=grow), Alignment.Start, Text("Click a flat face of a body. To use a sketch, click the eye beside it in the browser, then click a profile of it.", size=11.5px, color=t.dim)))
  else
    isempty(f.inputs) && push!(rows, Box(width(grow=grow), Alignment.Start, Text("This step has no lengths or angles to change.", size=12px, color=t.dim)))
    for input in f.inputs
      param = String(input["param"])
      label = String(get(input, "label", param))
      text = String(get(input, "code", input["expression"]))
      push!(rows, unit_kind(get(input, "unit", "")) == :text ? labelled(v, label, input!(v, (:field, "step", param); text)) :
                  code_row(v, label, code!(v, (:field, "step", param); text)))
    end
  end
  # The design shows what the command would make, unless Preview is off
  shows = f.step === nothing ? Commands.tried(f.spec.command) : !isempty(f.inputs)
  shows && push!(get!(() -> Any[], parts, "Options"), tick(v, (:form, :preview), "Preview", v.previews, on -> (v.previews = on)))
  for name in ("Options", "Advanced")
    list = get(parts, name, Any[])
    isempty(list) && continue
    push!(rows, section_head(v, f, name))
    name in f.closed || append!(rows, list)
  end
  f.step === nothing && !isempty(f.spec.help) && !isempty(f.spec.fields) && !haskey(Commands.SPECS, f.spec.command) &&
    push!(rows, Box(width(grow=grow), height(max=110px), clip=true, Alignment.Start, Text(first(f.spec.help, 420), size=10.5px, color=t.dim)))
  foot = Any[]
  trial = m.trial
  if !isempty(f.problem)
    push!(foot, Box(width(grow=grow), Alignment.Start, Text(f.problem, size=11.5px, color=colorant"rgb(226,96,84)")))
  elseif trial !== nothing && trial.key == f.key && !isempty(trial.problem)
    # What SolidCraft says of the command as the form has it now, before OK is clicked
    push!(foot, Box(width(grow=grow), Alignment.Start, Text(trial.problem, size=11.5px, color=t.dim)))
  end
  ready = !(request(v, f) isa String)
  push!(foot, Row(width(grow=grow), justify=Alignment.End, child_gap=8px,
    word_button(v, (:form, :cancel), "Cancel"; act=e -> (v.form = nothing)),
    word_button(v, (:form, :ok), "OK"; act=e -> apply!(v), strong=true, faint=!ready, tip="Return")))
  side_card(v, :form, f.spec.icon, f.spec.title, e -> (v.form = nothing), rows...; foot, wide=side_width!(v, form_fields(v, f)))
end

"The fields to type in that the form `f` shows, each with how much of the panel's width is beside it"
form_fields(v::DesignView, f::Form) = begin
  out = Pair{Any,Any}[]
  if f.step === nothing
    for field in f.spec.fields
      Commands.section(field) in f.closed && continue
      box = get(v.parts, (:field, f.spec.command, field.key), nothing)
      isfield(box) && push!(out, box => (field.kind == :json ? SIDE_PAD : LABELLED))
    end
  else
    for input in f.inputs
      box = get(v.parts, (:field, "step", String(input["param"])), nothing)
      isfield(box) && push!(out, box => LABELLED)
    end
  end
  out
end

"What the panel says of how far the sketch is held by its constraints, and how much of it is: from 0 to 1"
held_words(s) = begin
  get(s, "status", "") in ("solved", "") || return ("The constraints can't all hold", colorant"rgb(226,96,84)", 1.0)
  dof = Int(get(s, "dof", 0))
  dof == 0 && return ("Fully constrained", colorant"rgb(60,160,230)", 1.0)
  # Each point that isn't fixed can move two ways, and each circle or arc can grow
  free = 2count(q -> get(q, "fixed", false) !== true, get(s, "points", Any[])) + count(c -> get(c, "type", "") in ("circle", "arc"), get(s, "curves", Any[]))
  ("$dof $(dof == 1 ? "degree" : "degrees") of freedom left", colorant"rgb(60,160,230)", clamp(1 - dof / max(free, dof, 1), 0.0, 1.0))
end

sketch_card(v::DesignView) = begin
  t = theme(v)
  s = sketch(v)
  says, colour, share = held_words(s)
  tool = v.tool
  side_width!(v, tool_fields(v, tool))   # before the fields are laid out in their rows
  rows = Any[]
  if tool isa Commands.Tool
    push!(rows, Box(width(grow=grow), Alignment.Start, Text(command_label(v, tool.command) * ": " * tool_hint(v, tool), size=11.5px, color=t.dim)))
    for field in tool.fields
      key = (:toolfield, tool.command, field.key)
      box = Commands.iscode(field) ? code!(v, key; text=Expressions.julia_code(String(field.default))) : input!(v, key; text=String(field.default))
      push!(rows, Commands.iscode(field) ? code_row(v, field.label, box) : labelled(v, field.label, box))
    end
  elseif tool isa Symbol
    hint = tool == :dimension ? "click what to measure, then where its length goes" : tool == :trim ? "click the piece of a line to cut away" :
           tool == :extend ? "click the end of a line to make it longer" : "click an edge or a face of a body"
    push!(rows, Box(width(grow=grow), Alignment.Start, Text(uppercasefirst(String(tool)) * ": " * hint, size=11.5px, color=t.dim)))
  end
  push!(rows, tick(v, (:show, :marks), "Constraints", v.marks, on -> (v.marks = on); right=true))
  push!(rows, tick(v, (:show, :sizes), "Dimensions", v.sizes, on -> (v.sizes = on); right=true))
  push!(rows, tick(v, (:show, :points), "Points", v.points, on -> (v.points = on); right=true))
  push!(rows, tick(v, (:show, :snap), "Snap", v.snap, on -> (v.snap = on); right=true))
  push!(rows, tick(v, (:show, :building), "Construction mode (X)", v.building, on -> (v.building = on); right=true))
  push!(rows, Box(height(2px)))
  push!(rows, word_button(v, (:sketch, :finish), "Finish Sketch"; act=e -> start!(v, "sketch.finish"), strong=true, wide=true))
  push!(rows, Row(width(grow=grow), child_gap=8px,
    word_button(v, (:sketch, :look), "Look At"; act=e -> look_at!(v, s), wide=true, tip="Look straight at the sketch"),
    word_button(v, (:sketch, :slice), "Slice"; act=e -> (v.slice = !v.slice), wide=true, on=v.slice, tip="Hide the part of each body that's in front of the sketch")))
  # The bar under the words is as long as the panel's room, and its colour is as long as the share of the sketch that's held
  wide = side_width!(v, tool_fields(v, tool))
  room = num(wide - SIDE_PAD)
  pushfirst!(rows, Column(width(grow=grow), child_gap=6px, Alignment.Start, Box(words(says, 12px)),
    Row(width(grow=grow), height(4px), radius(2px), background(Ink.faded(t.line, 0.9)), justify=Alignment.Start,
      Box(width(px(max(room * share, 4.0))), height(4px), radius(2px), background(colour)))))
  side_card(v, :sketch_card, "sketch", String(get(s, "name", "Sketch")), nothing, rows...; wide)
end

"The fields of the sketch's tool `tool` that the panel has made, each with how much of the panel's width is beside it"
tool_fields(v::DesignView, tool) = begin
  tool isa Commands.Tool || return Pair{Any,Any}[]
  boxes = (get(v.parts, (:toolfield, tool.command, field.key), nothing) for field in tool.fields)
  Pair{Any,Any}[box => LABELLED for box in boxes if isfield(box)]
end

"What a tool asks for next"
tool_hint(v::DesignView, tool::Commands.Tool) = begin
  n = length(v.clicks)
  tool.clicks == ["points"] && return n == 0 ? "click its first point" : "click the next point. Return ends it"
  n >= length(tool.clicks) ? "" : "click " * (n == 0 ? "its first point" : n == length(tool.clicks) - 1 ? "its last point" : "its next point")
end

# --- the sheet of parameters -----------------------------------------------------------
#
# The panel of parameters is a sheet, the same one as a `sheet` block of a
# page: a row for each parameter, with its name at the left, its code in the
# middle, and what that comes to at the right. Ladder gives it (see `SHEET`),
# so the names of other rows are chips, and each row works itself out while
# it's typed. It has the design's units, and every parameter of the design,
# so a row can use one that's under it. The user's parameters come first,
# then the lengths of the steps and of the sketches' dimensions, like d1.
#
# What's typed goes to SolidCraft when the caret leaves its row, and when the
# sheet gives up the keyboard, as when the panel closes:
#   - A row whose code changed sets its parameter, as a field of code does: see `agree!`.
#   - A row whose name changed renames its parameter. SolidCraft changes the
#     code that uses the old name.
#   - A new row adds a parameter, just under the row over it.
#   - A row that's taken away deletes its parameter. SolidCraft won't delete
#     one that something uses, and says what uses it. A length of a step stays.
# What goes wrong shows at the top of the design, as a step's problem does.
#
# The sheet shows the design's parameters again once SolidCraft has them. A row
# that isn't a parameter yet, like the one that Return just made, stays where
# it is. While a row holds typing that hasn't gone to SolidCraft, the sheet
# waits. ⌘Z takes back what was typed in the caret's row, and when nothing
# was, the design's last change, which the sheet then shows.

"""
What makes the sheet of parameters, when Ladder gives one: `SHEET[](v)` gives
a node that Ladder edits as a `sheet` block of a page. It has methods of
`text_of`, `sheet_rows`, `set_rows!`, `caret_row`, `sent!`, `before_caret`,
`complete!`, `names_place`, `wants` and `room!`. Without one, the panel only
lists the parameters.
"""
const SHEET = Ref{Any}(nothing)

"Each row of the sheet `s`, as its name and its code"
function sheet_rows end
"Make the sheet `s` hold `rows`, each a name and its code. The caret stays in the row with the same name."
function set_rows! end
"The number of the row of the sheet `s` that the caret is in"
function caret_row end
"Forget what was typed in the sheet `s`, for ⌘Z: it's gone to SolidCraft"
function sent! end

"The name of the row of the sheet `s` that the caret is in, or nothing"
caret_name(s) = (rows = sheet_rows(s); r = caret_row(s); 1 <= r <= length(rows) && !isempty(strip(rows[r][1])) ? String(strip(rows[r][1])) : nothing)

"The parameters that the panel shows: the user's, then the lengths of the steps"
panel_params(v::DesignView) = sort(Designs.params(v.model), by=p -> get(p, "model", false) === true)

"True for a length of a step or of a sketch's dimension, like d1, which isn't one of the user's parameters"
model_param(p) = p !== nothing && get(p, "model", false) === true

"""
The code of the row of the parameter `p`. A parameter that SolidCraft got a
number for has its code in its comment. One of text is in quotes.
"""
param_code(v::DesignView, p) =
  unit_kind(get(p, "unit", "")) == :text ? repr(String(something(get(p, "expression", ""), ""))) :
    Expressions.field_code(p["expression"], something(get(p, "comment", nothing), param_note(v, String(p["name"]))))

"The rows of the sheet for the parameters of `v`, each as its name and its code"
param_rows(v::DesignView) = Tuple{String,String}[(String(p["name"]), param_code(v, p)) for p in panel_params(v)]

"The sheet of parameters of `v`"
param_sheet(v::DesignView) = part!(() -> SHEET[](v), v, :param_sheet)

"The parameters of the design, in a sheet: see \"the sheet of parameters\""
params_card(v::DesignView) = begin
  t = theme(v)
  close(e) = (v.panel = :none)
  SHEET[] === nothing && return side_card(v, :params, "params", "Parameters", close,
    (Row(width(grow=grow), child_gap=8px, words(n, 12px), Box(width(grow=grow)), words(c, 12px, color=t.dim)) for (n, c) in param_rows(v))...)
  s = param_sheet(v)
  follow_sheet!(v, s)
  wide = side_width!(v, Pair{Any,Any}[s => SIDE_PAD])
  side_card(v, :params, "params", "Parameters", close, s; wide)
end

"""
Show the design's parameters in the sheet `s` when they've changed since it
last showed them, or when SolidCraft refused what the sheet gave it. It waits
while a row holds typing that hasn't gone to SolidCraft.
"""
follow_sheet!(v::DesignView, s) = begin
  rows = param_rows(v)
  given = get(v.parts, :sheet_given, nothing)
  (rows == given && !get(v.parts, :sheet_refused, false)) && return
  text_of(s) == get(v.parts, :sheet_sent, text_of(s)) || return
  # A row that isn't a parameter, and never was, stays where it is: one with no name yet, or one that SolidCraft
  # wouldn't add. A row that was a parameter, and isn't now, goes: ⌘Z took it away. So does an empty row that
  # the caret isn't in.
  shown = copy(rows)
  if given !== nothing
    had = Set(n for (n, _) in given)
    names = Set(n for (n, _) in rows)
    typing = has_keys(part_window(v), s) ? caret_row(s) : 0
    for (i, (n, c)) in enumerate(sheet_rows(s))
      name = String(strip(n))
      (name in names || name in had || (isempty(name) && isempty(strip(c)) && i != typing)) && continue
      insert!(shown, min(i, length(shown) + 1), (n, c))
    end
  end
  set_rows!(s, shown)
  v.parts[:sheet_given] = v.parts[:sheet_base] = rows
  v.parts[:sheet_sent] = text_of(s)
  v.parts[:sheet_refused] = false
  s
end

"SolidCraft refused what the sheet of parameters gave it: the sheet shows the design's parameters, as SolidCraft has them"
refused!(v::DesignView) = (v.parts[:sheet_refused] = true; v.parts[:sheet_base] = nothing; v)

"""
The rows of the sheet whose names were changed, as pairs of the old name and
the new one, which it takes out of `gone` and `added`. A row of `now` that
`base` doesn't have takes the name of a row of `base` that `now` doesn't have,
when both are in the same gap between the rows that both have. In a gap, the
first that went goes with the first that came, and so on.
"""
renames!(gone, added, base, now) = begin
  both = Set(n for (n, _) in base) ∩ Set(n for (n, _) in now)
  # The gap of each name that only `rows` has: how many of the rows over it both have
  gaps(rows) = begin
    k, out = 0, Dict{String,Int}()
    for (n, _) in rows
      isempty(n) && continue
      n in both ? (k += 1) : (out[n] = k)
    end
    out
  end
  went, came = gaps(base), gaps(now)
  pairs = Tuple{String,String}[]
  for g in unique(went[n] for n in gone)
    append!(pairs, zip(filter(n -> went[n] == g, gone), filter(n -> get(came, n, -1) == g, added)))
  end
  filter!(n -> !any(p -> p[1] == n, pairs), gone)
  filter!(n -> !any(p -> p[2] == n, pairs), added)
  pairs
end

"""
What the code of each row of `now` comes to, as `(value, failed)` by the row's
name, for the rows named in `wanted` and the rows over them. The rows run from
the top down, as the sheet works them out, with the design's parameters. So a
row has the new value of a row over it, which SolidCraft may not have yet.
"""
row_values(v::DesignView, now, wanted) = begin
  out = Dict{String,Any}()
  last = findlast(r -> r[1] in wanted, now)
  last === nothing && return out
  mod = Expressions.parameters!(Expressions.workspace(), every_param(v))
  for (n, c) in now[1:last]
    (isempty(n) || isempty(c)) && continue
    value, failed = out[n] = Expressions.evaluate(mod, c)
    failed || !Base.isidentifier(n) || try Core.eval(mod, :($(Symbol(n)) = $(QuoteNode(value)))) catch end
  end
  out
end

"""
Give SolidCraft what was typed in the sheet of parameters, when the caret has
left the row it was in, or the sheet has given up the keyboard. A sheet that
doesn't show gives the keyboard to the design.
"""
left_row!(v::DesignView) = begin
  s = get(v.parts, :param_sheet, nothing)
  s === nothing && return
  w = part_window(v)
  on = has_keys(w, s)
  on && v.panel != :params && (focus(v); on = false)
  row = on ? caret_row(s) : 0
  was = get(v.parts, :sheet_row, 0)
  v.parts[:sheet_row] = row
  row != was && was != 0 && send_sheet!(v, s)
  nothing
end

"""
Give SolidCraft what was typed in the sheet `s` since it last showed the
design's parameters, or last gave SolidCraft its rows: see "the sheet of
parameters". The changes that it makes are one step for ⌘Z.
"""
send_sheet!(v::DesignView, s) = begin
  # Nothing was typed since the sheet last showed the design's parameters, or last gave SolidCraft its rows
  text_of(s) == get(v.parts, :sheet_sent, nothing) && return v
  m = v.model
  base = something(get(v.parts, :sheet_base, nothing), param_rows(v))
  now = Tuple{String,String}[(String(strip(n)), String(strip(c))) for (n, c) in sheet_rows(s)]
  v.parts[:sheet_sent] = text_of(s)
  # The parameters that the design has now are older than what was typed, which the sheet shows till SolidCraft has it
  v.parts[:sheet_given] = param_rows(v)
  was = Dict(base)
  is = Dict((n, c) for (n, c) in now if !isempty(n))
  problems = String[]
  nameless = any(((n, c),) -> isempty(n) && !isempty(c), now)
  nameless && push!(problems, "Give each row a name, at its left.")
  twice = [n for n in keys(is) if count(r -> r[1] == n, now) > 1]
  isempty(twice) || push!(problems, "Two rows are called $(first(twice)).")
  # A row whose name was taken away is still being written, and so is one with a name and no code
  gone = nameless ? String[] : String[n for (n, _) in base if !haskey(is, n)]
  added = String[n for (n, c) in now if !isempty(n) && !haskey(was, n) && !isempty(c) && !(n in twice)]
  renamed = renames!(gone, added, base, now)
  old = Dict(b => a for (a, b) in renamed)   # the name that a renamed row had
  changed = String[n for (n, c) in now if !isempty(c) && haskey(was, get(old, n, n)) && was[get(old, n, n)] != c]
  # What SolidCraft gets for each row: Julia's reading of its code, or the text of a parameter of text
  readings, texts = Dict{String,Any}(), Dict{String,String}()
  values = row_values(v, now, changed ∪ added)
  for n in unique(vcat(changed, added))
    p = param_named(v, get(old, n, n))
    kind = p === nothing ? :number : unit_kind(get(p, "unit", ""))
    if kind == :text
      x = try Meta.parse(is[n]) catch; nothing end
      x isa String ? (texts[n] = x) : push!(problems, "$n is text: write it in quotes, like \"steel\".")
      continue
    end
    r = read_code(v, is[n], kind, n; got=get(values, n, nothing))
    r isa String ? push!(problems, r) : r === nothing || (readings[n] = r)
  end
  notes = Dict(n => param_note(v, get(old, n, n)) for n in changed)
  users = Set{String}(String(p["name"]) for p in panel_params(v) if !model_param(p))
  # A length of a step can't be deleted, so its row comes back
  deleted = filter(n -> !model_param(param_named(v, n)), gone)
  length(deleted) < length(gone) && refused!(v)
  # What the design will have, as far as the sheet knows. A row that doesn't go to SolidCraft stays as it was.
  will = Dict(base)
  for (a, b) in renamed
    will[b] = pop!(will, a)
    a in users && push!(users, b)
  end
  foreach(n -> will[n] = is[n], keys(readings) ∪ keys(texts))
  foreach(n -> delete!(will, n), deleted)
  v.parts[:sheet_base] = Tuple{String,String}[(n, will[n]) for n in unique(vcat([n for (n, _) in now if haskey(will, n)], collect(keys(will))))]
  # What went to SolidCraft is ⌘Z's to take back from now on, and not the sheet's. Typing that didn't go stays the sheet's.
  isempty(renamed) && isempty(readings) && isempty(texts) && isempty(deleted) || sent!(s)
  before = Designs.undos(m)
  agree!(v, readings) do agreed
    steps = 0
    send(command, params) = (steps += 1; Designs.change!(m, command, params; then=(_, problem) -> problem === nothing || refused!(v)))
    for (a, b) in renamed
      send("parameters.rename", JSON.Object("name" => a, "new_name" => b))
    end
    for n in changed
      if haskey(texts, n)
        send("parameters.change", JSON.Object("name" => n, "expression" => texts[n]))
      elseif haskey(readings, n)
        r = readings[n]
        params = JSON.Object("name" => n, "expression" => given(r, n in agreed))
        note = noted(r, n in agreed, notes[n])
        note === nothing || (params["comment"] = note)
        send("parameters.change", params)
      end
    end
    for n in added
      r = get(readings, n, nothing)
      r === nothing && continue
      got = given(r, n in agreed)
      params = JSON.Object("name" => n, "expression" => got)
      got == r.code || (params["comment"] = Expressions.comment(r.code, got))
      send("parameters.add", params)
      # SolidCraft puts a new parameter last. It goes under the row over it, when one of the user's comes after it.
      k = findfirst(x -> x[1] == n, now)
      over = findlast(x -> x[1] in users, now[1:k-1])
      next = findfirst(x -> x[1] in users, now[k+1:end])
      next === nothing || send("parameters.move", over === nothing ? JSON.Object("name" => n, "before" => now[k+next][1]) :
                                                                       JSON.Object("name" => n, "after" => now[over][1]))
      push!(users, n)
    end
    foreach(n -> send("parameters.delete", JSON.Object("name" => n)), deleted)
    steps > 1 && Designs.refresh!(m; then=() -> Designs.together!(m, before))
    isempty(problems) || (m.said = join(problems, " "))
  end
  v
end

"The window that `v` is in, or nothing"
part_window(v::DesignView) = window_of(v)

"""
What Return does in the field `box`. In a form's field, it gives the form to
SolidCraft, and it gives nothing for a field that Return does nothing in.
"""
commit!(v::DesignView, box) = begin
  for (key, node) in v.parts
    node === box || continue
    key isa Tuple && key[1] == :field && return apply!(v)
  end
  nothing
end

# --- the picture ---------------------------------------------------------------------

"The last picture of the design, kept so that a frame in which nothing changed draws it again"
mutable struct Shot
  image::Ptr{Skia.sk_image_t}
  of::Any
  Shot() = finalizer(s -> (s.image == C_NULL || Skia.sk_image_unref(s.image); s.image = C_NULL), new(C_NULL, nothing))
end

"How many of the screen's pixels a px is wide on the canvas `ctx`"
density(ctx) = begin
  m = Ref(Skia.sk_matrix_t(1f0, 0f0, 0f0, 0f0, 1f0, 0f0, 0f0, 0f0, 1f0))
  Skia.sk_canvas_get_total_matrix(ctx, m)
  sqrt(abs(m[].scaleX * m[].scaleY - m[].skewX * m[].skewY))
end

"The triangles and the edges of a body, as the graphics card takes them"
arrays(v::DesignView, s::Scenes.Shape) = get!(v.data, s) do
  solid = Vector{Float32}(undef, 21 * length(s.triangles))
  for (i, t) in enumerate(s.triangles), k in 1:3
    p, n = s.points[t[k]], s.normals[3i-3+k]
    at = 21(i - 1) + 7(k - 1)
    solid[at+1], solid[at+2], solid[at+3] = p
    solid[at+4], solid[at+5], solid[at+6] = n
    solid[at+7] = s.face[i]
  end
  lines = Float32[]
  for e in s.edges, i in 1:length(e.points)-1
    append!(lines, e.points[i])
    append!(lines, e.points[i+1])
  end
  (solid=solid, lines=lines)
end

rgba(c::Colorant, a=1.0) = (Float32(red(c)), Float32(green(c)), Float32(blue(c)), Float32(a))

"""
The colours of the picture, from the theme. Behind the design is the colour of
the panels, a little darker, so the panels show over it as SolidCraft's do. The
grid is in the colour of text. A body with no colour of its own is grey: on a
dark page, a lighter grey with darker edges.
"""
palette(t) = begin
  back = rgba(Ink.mixed(t.surface, colorant"black", dark(t) ? 0.3 : 0.035))[1:3]
  grid = rgba(t.text)[1:3]
  dark(t) ? (; back, body=(0.72f0, 0.74f0, 0.78f0, 1f0), edge=(0.06f0, 0.07f0, 0.09f0, 1f0), grid) :
            (; back, body=(0.80f0, 0.82f0, 0.85f0, 1f0), edge=(0.15f0, 0.17f0, 0.21f0, 1f0), grid)
end

"The plane that the grid is on: the sketch's while one is edited, and the ground if not"
ground(v::DesignView) = (s = sketch(v); s === nothing ? Sketching.Frame((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)) : Sketching.Frame(s["plane"]))

"The lines of the grid: the thin ones, and each tenth one, which is stronger. Its squares are at least 7 px wide."
grid(v::DesignView, frame, size) = begin
  mm = 1 / Scenes.scale(v.eye, size)
  minor = 10.0^ceil(log10(max(7mm, 1e-6)))
  reach = max(v.eye.distance * 1.8, 20minor)
  n = clamp(ceil(Int, reach / minor), 10, 160)
  at = Sketching.flat(frame, v.eye.target)
  centre = (round(at[1] / 10minor) * 10minor, round(at[2] / 10minor) * 10minor)
  key = (minor, centre, n, frame)
  kept = get(v.parts, :grid, nothing)
  kept !== nothing && kept.key == key && return kept
  thin, strong = Float32[], Float32[]
  far = n * minor
  for i in -n:n
    to = i % 10 == 0 ? strong : thin
    for (a, b) in (((centre[1] + i * minor, centre[2] - far), (centre[1] + i * minor, centre[2] + far)),
                   ((centre[1] - far, centre[2] + i * minor), (centre[1] + far, centre[2] + i * minor)))
      append!(to, Sketching.world(frame, a))
      append!(to, Sketching.world(frame, b))
    end
  end
  v.parts[:grid] = (key=key, thin=thin, strong=strong, centre=Sketching.world(frame, centre), far=far)
end

"Is `p` one of `list`?"
among(list, p) = any(q -> same(q, p), list)

"What the form that's open has in the fields that were clicked"
form_picks(v::DesignView) = v.form === nothing ? Any[] : reduce(vcat, values(v.form.shows), init=Any[])

"The command that was tried for the form that's open, when it made bodies to show: see `preview!`"
shown_trial(v::DesignView) = begin
  f, trial = v.form, v.model.trial
  # What was tried for the form as it was a moment ago shows until the new trial comes, so that the picture doesn't blink
  (f === nothing || trial === nothing || f.key === nothing || !v.previews || !isempty(trial.problem)) && return nothing
  # What Ladder makes can be only lines, or faces that a command takes away
  made = trial.made
  isempty(trial.changed) && (made === nothing || (isempty(made.lines) && isempty(made.faces))) ? nothing : trial
end

"The edges of the body `s`, or one of them, as the numbers of lines"
edge_lines(e::Scenes.Edge) = begin
  data = Float32[]
  for i in 1:length(e.points)-1
    append!(data, e.points[i])
    append!(data, e.points[i+1])
  end
  data
end

"How many mm one px is at the point `p` of the design"
mm_per_px(v::DesignView, p) = begin
  size = (v.area[3], v.area[4])
  v.eye.wide > 0 || return 1 / Scenes.scale(v.eye, size)
  depth = Scenes.at(v.eye, size, p)[3]
  max(depth, 1e-6) * tand(v.eye.wide / 2) / (size[2] / 2)
end

"`x` with three figures, so that a number that barely changes gives the same key"
figures(x) = x == 0 ? 0.0 : round(x, sigdigits=3)

"The line from `a` to `b` as dashes: each `on` mm long with `off` mm between"
dashes(a, b, on, off) = begin
  data = Float32[]
  way = b .- a
  long = Scenes.len(way)
  (long < 1e-9 || on <= 0) && return data
  way = way ./ long
  at = 0.0
  while at < long && length(data) < 6000
    append!(data, a .+ way .* at)
    append!(data, a .+ way .* min(at + on, long))
    at += on + off
  end
  data
end

"Two triangles for the flat piece with the corners `a`, `b`, `c` and `d`, in order round it"
quad!(data, a, b, c, d) = (foreach(p -> append!(data, p), (a, b, c, a, c, d)); data)

const ORIGIN_PLANES = (("XY", (1.0, 0.0, 0.0), (0.0, 1.0, 0.0)), ("XZ", (1.0, 0.0, 0.0), (0.0, 0.0, 1.0)), ("YZ", (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)))
const ORIGIN_AXES = (("X", (1.0, 0.0, 0.0), (0.886f0, 0.282f0, 0.282f0)), ("Y", (0.0, 1.0, 0.0), (0.275f0, 0.69f0, 0.33f0)), ("Z", (0.0, 0.0, 1.0), (0.282f0, 0.455f0, 0.91f0)))
const PLANE_PX = 87.0    # how wide a plane of the origin shows, whatever the zoom: as SolidCraft shows it
const AXIS_PX = 130.0    # and how long an axis of the origin shows
const PLANE_TINT = (0.91f0, 0.59f0, 0.28f0)

"""
The planes that show, each as a flat square: those of the origin, which go
from the origin along two axes, and the construction planes, each round the
point that SolidCraft gives for it. A square is as big on the screen at any
zoom, as in SolidCraft. Each has its name, a corner, and its two sides.
"""
squares(v::DesignView) = begin
  m = v.model
  out = Any[]
  zero = (0.0, 0.0, 0.0)
  side = figures(PLANE_PX * mm_per_px(v, zero))
  # While a form asks for a plane, the three of the origin show, so that one can be clicked
  field = wanted(v)
  asked = field !== nothing && field.kind == :plane
  for (name, x, y) in ORIGIN_PLANES
    (asked || Designs.origin_shown(m, name)) && push!(out, (name=name, corner=zero, x=x .* side, y=y .* side))
  end
  for p in m.planes
    Designs.plane_shown(m, p.name) || continue
    n = Scenes.unit(p.normal)
    # Its sides run along the design's axes where they can
    k = argmin(abs.(n))
    x = Scenes.unit(ntuple(i -> (i == k ? 1.0 : 0.0), 3) .- n .* n[k])
    y = Scenes.cross(n, x)
    half = figures(PLANE_PX * mm_per_px(v, p.point))
    push!(out, (name=p.name, corner=p.point .- x .* half .- y .* half, x=x .* 2half, y=y .* 2half))
  end
  out
end

"The plane that shows at the place `at` of the picture, and how far along the line of sight it is, or nothing"
square_under(v::DesignView, at) = begin
  o, d = Scenes.ray(v.eye, (v.area[3], v.area[4]), at)
  best, found = Inf, nothing
  for q in squares(v)
    n = Scenes.cross(q.x, q.y)
    down = Scenes.dot(d, n)
    abs(down) < 1e-12 && continue
    far = Scenes.dot(q.corner .- o, n) / down
    (far > 1e-9 && far < best) || continue
    p = o .+ d .* far .- q.corner
    a, b = Scenes.dot(p, q.x) / Scenes.dot(q.x, q.x), Scenes.dot(p, q.y) / Scenes.dot(q.y, q.y)
    (0 <= a <= 1 && 0 <= b <= 1) || continue
    best, found = far, (kind=:plane, of=q.name, n=0, at=o .+ d .* far)
  end
  found === nothing ? nothing : (found, best)
end

"The lines of the sketch `s`, which isn't being edited, as the graphics card takes them: the whole lines, and the dashes of its construction lines"
sketch_lines(v::DesignView, s) = begin
  kept = get!(() -> Dict{Any,Any}(), v.parts, :sketch_lines)
  step = figures(mm_per_px(v, Sketching.Frame(s["plane"]).origin))
  length(kept) > 60 && empty!(kept)
  get!(kept, (objectid(s), step)) do
    f = Sketching.Frame(s["plane"])
    whole, dashed = Float32[], Float32[]
    for c in get(s, "curves", Any[])
      line = Sketching.outline(c)
      built = get(c, "construction", false) === true
      for i in 1:length(line)-1
        a, b = Sketching.world(f, line[i]), Sketching.world(f, line[i+1])
        built ? append!(dashed, dashes(a, b, 5step, 4step)) : (append!(whole, a); append!(whole, b))
      end
    end
    (whole=whole, dashed=dashed, step=step)
  end
end

"The closed region `n` of the sketch `s` as triangles"
region_sheet(v::DesignView, s, n) = begin
  kept = get!(() -> Dict{Any,Any}(), v.parts, :sheets)
  length(kept) > 300 && empty!(kept)
  get!(kept, (objectid(s), n)) do
    f = Sketching.Frame(s["plane"])
    data = Float32[]
    for (x1, x2, y1, y2) in Sketching.strips(regions(v, s), n)
      quad!(data, Sketching.world(f, (x1, y1)), Sketching.world(f, (x2, y1)), Sketching.world(f, (x2, y2)), Sketching.world(f, (x1, y2)))
    end
    data
  end
end

"Everything that the graphics card draws: the grid, the bodies and their edges, the sketches that aren't edited, the planes, and what's lit"
things(v::DesignView, size, dense, t) = begin
  m = v.model
  c = palette(t)
  out = Any[]
  g = grid(v, ground(v), size)
  fade = (Float32.(g.centre)..., Float32(0.35g.far), Float32(0.95g.far))
  push!(out, GLs.Lines((:thin, g.key), g.thin, (c.grid..., 0.10f0), dense; fade))
  push!(out, GLs.Lines((:strong, g.key), g.strong, (c.grid..., 0.22f0), dense; fade))
  lit = rgba(t.accent, 0.42)
  chosen_ = rgba(t.accent, 0.78)
  marked = vcat(v.picked, form_picks(v))
  trial = shown_trial(v)
  # What's kept of the bodies that a change replaced is let go
  length(v.data) > length(m.shapes) + 8 && filter!(p -> any(s -> s === p.first, m.shapes) || (trial !== nothing && any(s -> s === p.first, trial.shapes)), v.data)
  length(v.faces) > 4000 && empty!(v.faces)
  h = v.hover
  visible = Designs.shows(m)
  # What Ladder made itself for the form, when it did: see preview.jl
  made = trial === nothing ? nothing : trial.made
  for s in m.shapes
    visible(s) || continue
    # A piece shows in the place of a body that the command takes away or replaces
    made !== nothing && s.name in made.hide && continue
    a = arrays(v, s)
    faces = Pair{Int,GLs.Colour}[]
    whole = among(marked, (kind=:body, of=s.name, n=0))
    for p in marked
      p.kind == :face && p.of == s.name && push!(faces, p.n => chosen_)
    end
    h !== nothing && h.kind == :face && h.of == s.name && !any(f -> f.first == h.n, faces) && push!(faces, h.n => lit)
    # The faces that the command takes away are red
    if made !== nothing
      for (name, n) in made.faces
        name == s.name && push!(faces, n => rgba(WRONG, 0.85))
      end
    end
    over = h !== nothing && h.kind == :body && h.of == s.name
    # A body with a colour of its own in the design shows in it. Any other is the grey that suits the page.
    own = get(m.colours, s.name, nothing)
    base = own === nothing ? RGB(c.body[1:3]...) : RGB(own...)
    # A body that a piece is cut from shows faintly, so that the piece shows in it
    solid = get(m.opacity, s.name, 1.0) * (made !== nothing && s.name in made.ghost ? GHOST : 1.0)
    body = rgba(whole ? Ink.mixed(base, t.accent, 0.45) : over ? Ink.mixed(base, t.accent, 0.2) : base, solid)
    painted = Pair{Int,GLs.Colour}[]
    for f in m.painted
      f.body == s.name || continue
      n = get!(() -> Scenes.face_at(s, f.point), v.faces, (objectid(s), f.point))
      n > 0 && push!(painted, n => rgba(RGB(f.colour...), f.opacity * solid))
    end
    # While a command's result shows, a body that it changes shows as the command leaves it: see below.
    # Of the body as it is now, only what's lit and what's selected shows.
    # What Ladder makes is only pieces, so every body shows as it is.
    replaced = trial !== nothing && made === nothing && (s.name in trial.changed || !any(b -> b.name == s.name, trial.shapes))
    push!(out, GLs.Solid((:solid, objectid(s)), a.solid, body; painted, lit=faces, bare=replaced, through=replaced ? false : body[4] < 1))
    replaced || push!(out, GLs.Lines((:edges, objectid(s)), a.lines, c.edge, 1.5dense; cut=true))
    edge(p, wide, hidden) = begin
      (p !== nothing && p.kind == :edge && p.of == s.name && 1 <= p.n <= length(s.edges)) || return
      push!(out, GLs.Lines((:edge, objectid(s), p.n), edge_lines(s.edges[p.n]), rgba(t.accent), wide * dense; hidden))
    end
    foreach(p -> edge(p, 4.0, false), marked)
    h === nothing || among(marked, h) || edge(h, 3.5, true)
  end
  # What the command of the open form would make
  if trial !== nothing && made !== nothing
    # The pieces that Ladder made: what's added in the accent colour, what's taken away in red
    for s in trial.shapes
      a = arrays(v, s)
      tint = get(made.tints, s.name, :add)
      colour = tint == :cut ? WRONG : t.accent
      push!(out, GLs.Solid((:solid, objectid(s)), a.solid, rgba(Ink.mixed(RGB(c.body[1:3]...), colour, 0.55), tint == :around ? GHOST : 1.0)))
      push!(out, GLs.Lines((:edges, objectid(s)), a.lines, rgba(Ink.mixed(RGB(c.edge[1:3]...), colour, 0.55)), 1.5dense))
    end
    isempty(made.lines) || push!(out, GLs.Lines((:made_lines, objectid(made)), made.lines, rgba(t.accent), 2.5dense; hidden=false))
  elseif trial !== nothing
    for s in trial.shapes
      (s.name in trial.changed && visible(s)) || continue
      a = arrays(v, s)
      own = get(trial.colours, s.name, nothing)
      base = own === nothing ? RGB(c.body[1:3]...) : RGB(own...)
      push!(out, GLs.Solid((:solid, objectid(s)), a.solid, rgba(Ink.mixed(base, t.accent, 0.18), get(m.opacity, s.name, 1.0))))
      push!(out, GLs.Lines((:edges, objectid(s)), a.lines, rgba(Ink.mixed(RGB(c.edge[1:3]...), t.accent, 0.55)), 1.5dense))
    end
  end
  # The sketches that aren't being edited. A body in front of one hides it.
  active = Designs.editing(m)
  ink = dark(t) ? (0.96f0, 0.96f0, 0.97f0, 0.92f0) : (0.09f0, 0.1f0, 0.13f0, 0.92f0)
  for (id, s) in m.sketches
    id == active && continue
    lines = sketch_lines(v, s)
    push!(out, GLs.Lines((:sketch, objectid(s)), lines.whole, ink, 1.2dense))
    push!(out, GLs.Lines((:sketch_dashes, objectid(s), lines.step), lines.dashed, ink, 1.2dense))
  end
  # The closed regions of sketches. They all show faintly while a sketch is edited, and while a form asks for regions.
  field = wanted(v)
  picks = form_picks(v)
  asked = field !== nothing && field.kind == :profiles && active === nothing
  for (id, s) in m.sketches
    (asked || id == active) || any(p -> p.kind == :region && p.n == id, picks) || (h !== nothing && h.kind == :region && h.n == id) || continue
    r = regions(v, s)
    for n in 2:r.count+1
      p = (kind=:region, of=n, n=id)
      strong = among(picks, p) ? 0.5 : h !== nothing && h.kind == :region && same(h, p) ? 0.3 : asked || id == active ? 0.13 : 0.0
      strong > 0 && push!(out, GLs.Sheet((:region, objectid(s), n), region_sheet(v, s, n), rgba(id == active && !among(picks, p) ? SKETCH_BLUE : t.accent, strong)))
    end
  end
  # The origin's axes, and the planes
  zero = (0.0, 0.0, 0.0)
  long = figures(AXIS_PX * mm_per_px(v, zero))
  for (name, way, colour) in ORIGIN_AXES
    Designs.origin_shown(m, name) || continue
    tip = way .* long
    push!(out, GLs.Lines((:axis, name, long), Float32[zero..., tip...], (colour..., 1f0), 1.6dense))
    # Where a body hides it, it shows as dashes
    push!(out, GLs.Lines((:axis_dashes, name, long), dashes(zero, tip, long * 5 / AXIS_PX, long * 4 / AXIS_PX), (colour..., 0.75f0), 1.2dense; hidden=false))
  end
  for q in squares(v)
    a, b, d, e = q.corner, q.corner .+ q.x, q.corner .+ q.x .+ q.y, q.corner .+ q.y
    on = among(picks, (kind=:plane, of=q.name, n=0)) ? 0.62f0 : h !== nothing && h.kind == :plane && h.of == q.name ? 0.5f0 : 0.3f0
    push!(out, GLs.Sheet((:plane, q.name, a, q.x, q.y), quad!(Float32[], a, b, d, e), (PLANE_TINT..., on)))
    push!(out, GLs.Lines((:plane_edge, q.name, a, q.x, q.y), Float32[a..., b..., b..., d..., d..., e..., e..., a...], (PLANE_TINT..., 0.85f0), dense))
  end
  out
end

"How far from the eye's target the things of the picture go"
far(v::DesignView) = begin
  low, high = Scenes.box(v.model.shapes)
  g = get(v.parts, :grid, nothing)
  max(Scenes.len(high .- v.eye.target), Scenes.len(low .- v.eye.target), g === nothing ? 0.0 : 1.5g.far, 1.0) * 1.05
end

"Where the point `p` of the design shows in the window, or nothing when it's behind the eye"
shown_at(v::DesignView, p) = begin
  x, y, depth = Scenes.at(v.eye, (v.area[3], v.area[4]), p)
  depth > 1e-6 ? (v.area[1] + x, v.area[2] + y) : nothing
end

const SKETCH_BLUE = colorant"rgb(96,160,236)"
const BUILT_ORANGE = colorant"rgb(232,150,72)"
const SIZE_PINK = colorant"rgb(226,160,222)"
const MARK_RED = colorant"rgb(226,138,96)"

draw(ctx, size, ui::ConcreteRect, scene::Scene) = begin
  v = scene.of
  m = v.model
  (m === nothing || !isempty(m.problem)) && return
  t = theme(scene)
  v.area = (num(ui.left), num(ui.top), max(num(ui.width), 1.0), max(num(ui.height), 1.0))
  empty!(v.spots)
  area = (v.area[3], v.area[4])
  # The picture has as many pixels as the screen shows it with, and no more than 9 million
  dense = clamp(density(ctx), 1.0, 3.0)
  dense = min(dense, sqrt(9e6 / (area[1] * area[2])))
  w, h = max(round(Int, area[1] * dense), 1), max(round(Int, area[2] * dense), 1)
  shot = v.image === nothing ? (v.image = Shot()) : v.image
  gpu = skia_gpu(v, ctx)
  direct = stage!(v, gpu === nothing ? C_NULL : GLs.current())
  c = palette(t)
  if v.stage !== false
    of = (m.version, v.eye, w, h, v.hover, hash(v.picked), v.form === nothing ? UInt(0) : hash((v.form.shows, v.form.active, v.form.key)), c, t.accent, Designs.editing(m), v.slice, v.stage)
    if shot.of != of
      list = things(v, area, dense, t)
      if direct
        GLs.picture!(v.stage, w, h, v.eye, list, c.back; reach=far(v), cut=cut(v), read=false)
        shot.image == C_NULL || (Skia.sk_image_unref(shot.image); shot.image = C_NULL)
      else
        pixels = GLs.picture!(v.stage, w, h, v.eye, list, c.back; reach=far(v), cut=cut(v))
        shot.image == C_NULL || Skia.sk_image_unref(shot.image)
        info = Ref(Skia.sk_image_info_t(C_NULL, Skia.SK_COLOR_TYPE_RGBA_8888, Skia.SK_ALPHA_TYPE_OPAQUE, w, h))
        GC.@preserve info pixels begin
          data = Skia.sk_data_new_with_copy(pointer(pixels), UInt64(4w * h))
          shot.image = Skia.sk_image_new_raster_data(info, data, Csize_t(4w))
          Skia.sk_data_unref(data)
        end
      end
      shot.of = of
    end
  end
  # The picture of a stage that shares the window's context is lent to Skia for this frame only
  image = direct && shot.of !== nothing ? lent_image(v, gpu, w, h) : direct ? C_NULL : shot.image
  # A design that's only shown in a page stops inside its line and its round corners
  framed = v.readonly && !v.fill
  clip = C_NULL
  if framed
    edge = Ref(Skia.sk_rect_t(Float32(v.area[1] + 1), Float32(v.area[2] + 1), Float32(v.area[1] + v.area[3] - 1), Float32(v.area[2] + v.area[4] - 1)))
    clip = Skia.sk_path_new()
    Skia.sk_path_add_rounded_rect(clip, edge, 7f0, 7f0, Skia.SK_PATH_DIRECTION_CW)
    Skia.sk_canvas_save(ctx)
    Skia.sk_canvas_clip_path_with_operation(ctx, clip, Skia.SK_CLIP_OP_INTERSECT, true)
  end
  if image == C_NULL
    Ink.box(ctx, v.area..., RGB(c.back...))
  else
    from = Ref(Skia.sk_rect_t(0f0, 0f0, Float32(w), Float32(h)))
    to = Ref(Skia.sk_rect_t(Float32(v.area[1]), Float32(v.area[2]), Float32(v.area[1] + v.area[3]), Float32(v.area[2] + v.area[4])))
    sampling = Ref(Skia.sk_sampling_options_t(0, false, Skia.sk_cubic_resampler_t(0f0, 0f0), Skia.SK_FILTER_MODE_LINEAR, Skia.SK_MIPMAP_MODE_NONE))
    Ink.painted(p -> Skia.sk_canvas_draw_image_rect(ctx, image, from, to, sampling, p, Skia.SRC_RECT_CONSTRAINT_FAST), colorant"white")
    # Skia holds on to what it draws until the frame is done, so the lent image can go now
    direct && Skia.sk_image_unref(image)
  end
  if v.readonly
    # Only the origin's point is drawn over the picture of a design that's only shown, and the point that a turn goes round
    draw_origin(ctx, v, t)
    draw_pivot(ctx, v)
    framed && (Skia.sk_canvas_restore(ctx); Skia.sk_path_delete(clip))
    return nothing
  end
  # The sketch that's being edited is drawn over the picture, so no body hides it. The graphics card draws the others.
  active = Designs.editing(m)
  active !== nothing && haskey(m.sketches, active) && draw_sketch(ctx, v, m.sketches[active], true, t)
  draw_tool(ctx, v, t)
  draw_origin(ctx, v, t)
  draw_pivot(ctx, v)
  draw_axes(ctx, v, t)
  nothing
end

"""
What Skia draws the window of `v` with on the graphics card, when `ctx` is
the canvas that it draws on. Nothing when the window is drawn by the CPU, as
a window that isn't on the screen is.
"""
skia_gpu(v::DesignView, ctx) = begin
  window = window_of(v)
  window === nothing && return nothing
  g = get(gpus, objectid(window), nothing)
  g !== nothing && g.surface != C_NULL && Skia.sk_surface_get_canvas(g.surface) == ctx ? g : nothing
end

"""
Give `v` a stage that shares `share`, the OpenGL context that the window is
drawn with, or C_NULL when the CPU draws the window. True when the stage
does share it, so that its picture can stay on the graphics card.
"""
stage!(v::DesignView, share) = begin
  had = get(v.parts, :stage_for, nothing)
  if v.stage === nothing || (v.stage !== false && had != share)
    stage = share == C_NULL ? nothing : GLs.Stage(share)
    v.parts[:direct] = stage !== nothing
    v.stage = stage !== nothing ? stage : something(GLs.Stage(), false)
    v.parts[:stage_for] = share
    delete!(v.parts, :over)
  end
  v.stage !== false && share != C_NULL && get(v.parts, :direct, false) === true
end

"""
The stage's last picture as an image of Skia's on the graphics card, or
C_NULL. Skia wraps a framebuffer of the window's context that has the
stage's renderbuffer, and copies it: a copy on the card, which is quick. The
caller lets go of the image when it has drawn it.
"""
lent_image(v::DesignView, g, w, h) = begin
  over = get(v.parts, :over, nothing)
  if over === nothing || over.size != (w, h)
    fbo = GLs.over!(v.stage, over === nothing ? 0 : over.fbo)
    fbo == 0 && return C_NULL
    v.parts[:over] = over = (size=(w, h), fbo=fbo)
  end
  info = Ref(Skia.gr_gl_framebufferinfo_t(over.fbo, 0x8058, false))   # 0x8058 is GL_RGBA8
  target = Skia.gr_backendrendertarget_new_gl(Cint(w), Cint(h), Cint(0), Cint(0), info)
  target == C_NULL && return C_NULL
  # The stage drew it with its rows from the top, so the first row of the framebuffer is the top
  surface = Skia.sk_surface_new_backend_render_target(g.context, target, Skia.GR_SURFACE_ORIGIN_TOP_LEFT, Skia.SK_COLOR_TYPE_RGBA_8888, C_NULL, C_NULL)
  image = surface == C_NULL ? C_NULL : Skia.sk_surface_make_image_snapshot(surface)
  surface == C_NULL || Skia.sk_surface_unref(surface)
  Skia.gr_backendrendertarget_delete(target)
  image
end

"""
The plane that cuts the picture, as a point on it and the way it faces, or
nothing. While Slice is on, it's the plane of the sketch that's edited, and
it takes away what's between that plane and the eye.
"""
cut(v::DesignView) = begin
  s = sketch(v)
  (v.slice && s !== nothing) || return nothing
  f = Sketching.Frame(s["plane"])
  n = Sketching.normal(f)
  toward = Scenes.dot(Scenes.place(v.eye) .- f.origin, n) >= 0 ? n : n .* -1.0
  # A hair nearer the eye than the plane, so that a face that's on the plane stays
  (f.origin .+ toward .* (1e-5 * max(v.eye.distance, 1.0)), toward)
end

"The point that the design goes round while it turns: a green dot, as in Fusion 360"
draw_pivot(ctx, v::DesignView) = begin
  d = v.drag
  d isa Drag && d.kind == :turn || return
  at = shown_at(v, d.pivot)
  at === nothing && return
  Ink.circle(ctx, at, 5.0, colorant"rgb(64,170,90)")
  Ink.circle(ctx, at, 5.0, colorant"white", 1.5)
end

"The point of the origin: a ball that shows over everything, as in SolidCraft"
draw_origin(ctx, v::DesignView, t) = begin
  Designs.origin_shown(v.model, "O") || return
  at = shown_at(v, (0.0, 0.0, 0.0))
  at === nothing && return
  Ink.circle(ctx, at, 4.5, t.surface)
  Ink.circle(ctx, at, 4.5, t.dim, 1.2)
end

"The closed regions of the sketch `s`, worked out when the sketch changes"
regions(v::DesignView, s) = begin
  id = Int(s["id"])
  kept = get(v.regions, id, nothing)
  kept !== nothing && kept[1] === s && return kept[2]
  r = Sketching.Regions(s)
  v.regions[id] = (s, r)
  r
end

"The closed regions of the sketch `s` along its curves, as Ladder's pieces take them, worked out when the sketch changes: see pieces.jl"
arrangement(v::DesignView, s) = begin
  kept = get!(() -> Dict{Int,Any}(), v.parts, :arrangements)
  id = Int(s["id"])
  k = get(kept, id, nothing)
  k !== nothing && k[1] === s && return k[2]
  a = Pieces.Arrangement(s)
  kept[id] = (s, a)
  a
end

const MARK_ICONS = Dict("Horizontal" => "c_hv", "Vertical" => "c_hv", "Tangent" => "c_tangent", "Equal" => "c_equal", "Parallel" => "c_parallel",
  "Perpendicular" => "c_perpendicular", "MidPoint" => "c_midpoint", "Concentric" => "c_concentric", "Collinear" => "c_collinear",
  "Symmetry" => "c_symmetry", "Fix" => "c_fix", "Fixed" => "c_fix", "PointOnCurve" => "c_coincident", "Coincident" => "c_coincident")

"Draw the sketch `s` over the picture. The one that's edited shows its points, its dimensions and the marks of its constraints."
draw_sketch(ctx, v::DesignView, s, active, t) = begin
  f = Sketching.Frame(s["plane"])
  id = Int(s["id"])
  to(p) = shown_at(v, Sketching.world(f, p))
  ink = dark(t) ? colorant"rgb(244,244,246)" : colorant"rgb(24,26,32)"
  lit(kind, of) = (h = v.hover; h !== nothing && h.kind == kind && h.of == of && h.n == id)
  chosen_(kind, of) = any(p -> p.kind == kind && p.of == of && p.n == id, v.picked)
  for c in get(s, "curves", Any[])
    line = Sketching.outline(c)
    places = [to(p) for p in line]
    (length(places) < 2 || any(isnothing, places)) && continue
    built = get(c, "construction", false) === true
    name = String(c["id"])
    colour = chosen_(:curve, name) ? t.accent : !active ? Ink.faded(SKETCH_BLUE, 0.85) : built ? BUILT_ORANGE :
             get(c, "fully_constrained", true) === true ? ink : SKETCH_BLUE
    Ink.through(ctx, places, colour, active ? (lit(:curve, name) || chosen_(:curve, name) ? 2.6 : 1.5) : 1.2; dash=built ? (5.0, 4.0) : nothing)
  end
  active || return
  for q in get(s, "points", Any[])
    at = to(Sketching.spot(q["at"]))
    at === nothing && continue
    name = String(q["id"])
    on = chosen_(:point, name) || lit(:point, name)
    v.points || on || continue
    r = on ? 4.0 : 2.6
    Ink.box(ctx, at[1] - r, at[2] - r, 2r, 2r, on ? t.accent : ink)
    Ink.box(ctx, at[1] - r, at[2] - r, 2r, 2r, dark(t) ? colorant"rgb(20,22,28)" : colorant"white"; width=1.0)
  end
  kinds = Dict{String,Any}(String(k["id"]) => k for k in get(s, "constraints", Any[]))
  around = Sketching.bounds(s)
  middle = around === nothing ? (0.0, 0.0) : ((around[1][1] + around[2][1]) / 2, (around[1][2] + around[2][2]) / 2)
  stacked = Dict{NTuple{2,Int},Int}()
  for g in v.model.glyphs
    g isa AbstractDict && haskey(kinds, get(g, "id", "")) && get(g, "at", nothing) isa Vector || continue
    name = String(g["id"])
    spot = Sketching.spot(g["at"])
    at = to(spot)
    at === nothing && continue
    if get(g, "dimension", false) === true
      v.sizes || continue
      d = Sketching.dimension(s, kinds[name], spot; placed=haskey(kinds[name], "text"), gap=30 / Scenes.scale(v.eye, (v.area[3], v.area[4])), middle)
      d === nothing && continue
      spot = d.at
      at = to(spot)
      at === nothing && continue
      colour = chosen_(:size, name) || lit(:size, name) ? t.accent : get(g, "failing", false) === true ? colorant"rgb(226,96,84)" : SIZE_PINK
      for (a, b) in d.lines
        pa, pb = to(a), to(b)
        pa === nothing || pb === nothing || Ink.line(ctx, pa, pb, Ink.faded(colour, 0.7), 1.0)
      end
      for (a, b) in d.arrows
        pa, pb = to(a), to(b)
        (pa === nothing || pb === nothing) && continue
        Ink.line(ctx, pa, pb, colour, 1.1)
        arrow(ctx, pa, pb, colour)
        arrow(ctx, pb, pa, colour)
      end
      wide = Ink.wide(d.words, 11.5; family=t.mono)
      Ink.box(ctx, at[1] - wide / 2 - 4, at[2] - 9, wide + 8, 18, Ink.faded(RGB(palette(t).back...), 0.86); radius=3.0)
      Ink.words(ctx, d.words, at[1], at[2], 11.5, colour; at=:middle, family=t.mono)
      push!(v.spots, (box=(at[1] - wide / 2 - 4 - v.area[1], at[2] - 9 - v.area[2], wide + 8, 18.0), what=(kind=:size, of=name, n=id, at=Sketching.world(f, spot))))
    else
      v.marks || continue
      kind = String(get(g, "name", ""))
      # A point that's on another point is marked by the point itself
      kind == "Coincident" && continue
      cell = (round(Int, at[1] / 6), round(Int, at[2] / 6))
      k = get(stacked, cell, 0)
      stacked[cell] = k + 1
      x, y = at[1] + 10 + 19k, at[2] - 20
      on = chosen_(:mark, name) || lit(:mark, name)
      colour = on ? t.accent : get(g, "failing", false) === true ? colorant"rgb(226,96,84)" : MARK_RED
      Ink.box(ctx, x, y, 16, 16, Ink.faded(RGB(palette(t).back...), 0.8); radius=3.5)
      Ink.box(ctx, x, y, 16, 16, colour; radius=3.5, width=1.0)
      Ink.icon(ctx, get(MARK_ICONS, kind, "point"), x + 2, y + 2, 12, colour, colour)
      push!(v.spots, (box=(x - v.area[1], y - v.area[2], 16.0, 16.0), what=(kind=:mark, of=name, n=id, at=Sketching.world(f, spot))))
    end
  end
end

"An arrow's head at `tip`, on a line that comes from `from`"
arrow(ctx, tip, from, colour) = begin
  dx, dy = from[1] - tip[1], from[2] - tip[2]
  l = hypot(dx, dy)
  l < 14 && return
  ux, uy = dx / l, dy / l
  Ink.through(ctx, [tip, (tip[1] + 9ux - 3.2uy, tip[2] + 9uy + 3.2ux), (tip[1] + 9ux + 3.2uy, tip[2] + 9uy - 3.2ux)], colour; fill=true)
end

"The circle through three places of a sketch: its middle and its radius, or nothing when they're in a line"
circle_through(a, b, c) = begin
  d = 2(a[1] * (b[2] - c[2]) + b[1] * (c[2] - a[2]) + c[1] * (a[2] - b[2]))
  abs(d) < 1e-9 && return nothing
  x = ((a[1]^2 + a[2]^2) * (b[2] - c[2]) + (b[1]^2 + b[2]^2) * (c[2] - a[2]) + (c[1]^2 + c[2]^2) * (a[2] - b[2])) / d
  y = ((a[1]^2 + a[2]^2) * (c[1] - b[1]) + (b[1]^2 + b[2]^2) * (a[1] - c[1]) + (c[1]^2 + c[2]^2) * (b[1] - a[1])) / d
  ((x, y), hypot(a[1] - x, a[2] - y))
end

"Draw what the tool in use would make if the mouse were clicked where it is"
draw_tool(ctx, v::DesignView, t) = begin
  s = sketch(v)
  tool = v.tool
  (s === nothing || !(tool isa Commands.Tool)) && return
  f = Sketching.Frame(s["plane"])
  to(p) = shown_at(v, Sketching.world(f, p))
  aimed = aim(v, s, v.mouse)
  spot = aimed.spot
  here = to(spot)
  here === nothing && return
  colour = t.accent
  path(points) = (places = [to(p) for p in points]; any(isnothing, places) || Ink.through(ctx, places, colour, 1.6))
  given = Spot[c.spot for c in v.clicks]
  if !isempty(given)
    first_ = given[1]
    if tool.shape == :box
      path([first_, (spot[1], first_[2]), spot, (first_[1], spot[2]), first_])
    elseif tool.shape == :centred
      dx, dy = spot[1] - first_[1], spot[2] - first_[2]
      path([(first_[1] - dx, first_[2] - dy), (first_[1] + dx, first_[2] - dy), (first_[1] + dx, first_[2] + dy), (first_[1] - dx, first_[2] + dy), (first_[1] - dx, first_[2] - dy)])
    elseif tool.shape == :circle
      path(Sketching.sweep(first_, hypot(spot[1] - first_[1], spot[2] - first_[2]), 0.0, 2π))
    elseif tool.shape == :arc && length(given) == 2
      found = circle_through(given[1], given[2], spot)
      if found === nothing
        path([given[1], given[2]])
      else
        o, r = found
        a, b, mid = Sketching.angle(o, given[1]), Sketching.angle(o, given[2]), Sketching.angle(o, spot)
        # The arc from the first click to the second that goes through the mouse
        path(mod(mid - a, 2π) <= mod(b - a, 2π) ? Sketching.sweep(o, r, a, b) : Sketching.sweep(o, r, b, a))
      end
    else
      path(vcat(given, [spot]))
    end
  end
  # A square shows the place that a click would take: bigger on a point that it snaps to
  r = aimed.ref === nothing ? 3.0 : 5.0
  Ink.box(ctx, here[1] - r, here[2] - r, 2r, 2r, colour; width=1.4)
  aimed.level && !isempty(given) && Ink.words(ctx, abs(spot[1] - given[end][1]) < 1e-9 ? "upright" : "level", here[1] + 12, here[2] - 12, 10.5, colour)
end

"The three balls that show which way the design's axes point. A click on one looks along it."
draw_axes(ctx, v::DesignView, t) = begin
  right, up, back = Scenes.axes(v.eye)
  # They go under the toolbar, left of the panel at the right
  bar = get(v.parts, :ribbon, nothing)
  r = bar === nothing ? nothing : rect(bar)
  top = r === nothing ? v.area[2] + 150 : num(r.top) + num(r.height) + 64
  beside = isempty(side(v)) ? 0.0 : num(side_w(v)) + 8
  cx, cy = v.area[1] + v.area[3] - 70 - beside, top
  reach = 34.0
  Ink.circle(ctx, (cx, cy), reach + 18, Ink.faded(t.surface, 0.35))
  ends = Any[]
  for (i, (axis, colour, name)) in enumerate((((1.0, 0.0, 0.0), colorant"rgb(226,72,72)", "X"), ((0.0, 1.0, 0.0), colorant"rgb(70,176,84)", "Y"), ((0.0, 0.0, 1.0), colorant"rgb(72,116,232)", "Z")))
    for way in (1, -1)
      a = axis .* way
      push!(ends, (x=cx + Scenes.dot(a, right) * reach, y=cy - Scenes.dot(a, up) * reach, near=Scenes.dot(a, back), colour=colour, name=name, i=i, way=way))
    end
  end
  for e in sort(ends, by=e -> e.near)
    if e.way == 1
      Ink.line(ctx, (cx, cy), (e.x, e.y), e.colour, 2.0)
      Ink.circle(ctx, (e.x, e.y), 9.5, e.colour)
      Ink.words(ctx, e.name, e.x, e.y, 11, colorant"white"; at=:middle, style="Bold")
    else
      Ink.circle(ctx, (e.x, e.y), 6.5, Ink.faded(t.surface, 0.9))
      Ink.circle(ctx, (e.x, e.y), 6.5, e.colour, 1.6)
    end
    push!(v.spots, (box=(e.x - 10 - v.area[1], e.y - 10 - v.area[2], 20.0, 20.0), what=(kind=:look, of=e.i, n=e.way, at=(0.0, 0.0, 0.0))))
  end
end

# --- the mouse -----------------------------------------------------------------------

"What a held button is doing"
mutable struct Drag
  kind::Symbol          # :press or :middle until the mouse moves, then :turn, :move, :zoom or :pull
  at::Spot              # where the mouse was on the last move
  what::Any             # what was pressed. For :middle, what the drag does once the mouse moves.
  more::Bool            # ⇧ was held
  pivot::Scenes.Vec3    # the point of the design that a turn goes round
  from::Spot            # for a pull: the place of the sketch that's held
  busy::Bool            # SolidCraft is still working on the last pull
end

"Where the place `pos` of the window is in the picture"
local_spot(v::DesignView, pos) = (num(pos[1]) - v.area[1], num(pos[2]) - v.area[2])

"The panel that the mouse is over, as its key, or nothing when it's over the design"
panel_at(v::DesignView, window, pos=window.mouse) = begin
  x, y = num(pos[1]), num(pos[2])
  for (key, node) in v.parts
    node isa Card || continue
    r = rect(node)
    r === nothing && continue
    num(r.left) <= x <= num(r.left + r.width) && num(r.top) <= y <= num(r.top + r.height) && return key
  end
  nothing
end

"The point of the design under the place `at` of the picture: on a body, on the sketch that's edited, or as far away as the eye's target"
point_at(v::DesignView, at) = begin
  size = (v.area[3], v.area[4])
  line = Scenes.ray(v.eye, size, at)
  hit = Scenes.hit(v.model.shapes, line; shown=Designs.shows(v.model))
  hit === nothing || return hit.point
  s = sketch(v)
  if s !== nothing
    f = Sketching.Frame(s["plane"])
    spot = Sketching.on_plane(f, line)
    spot === nothing || return Sketching.world(f, spot)
  end
  back = Scenes.axes(v.eye)[3]
  along = -Scenes.dot(line[2], back)
  line[1] .+ line[2] .* (v.eye.wide > 0 ? v.eye.distance / max(along, 1e-6) : v.eye.distance)
end

"The field of the open form that the next click in the design fills, or nothing"
wanted(v::DesignView) = begin
  f = v.form
  (f === nothing || isempty(f.active)) && return nothing
  i = findfirst(field -> field.key == f.active, f.spec.fields)
  i === nothing ? nothing : f.spec.fields[i]
end

"What of the sketch `s` shows at the place `at` of the picture: a point, or a curve, or nothing"
sketch_under(v::DesignView, s, at) = begin
  f = Sketching.Frame(s["plane"])
  id = Int(s["id"])
  size = (v.area[3], v.area[4])
  seen(p) = Scenes.at(v.eye, size, Sketching.world(f, p))
  best, found = 8.0, nothing
  for q in get(s, "points", Any[])
    spot = Sketching.spot(q["at"])
    x, y, depth = seen(spot)
    depth > 0 || continue
    d = hypot(x - at[1], y - at[2])
    d < best && ((best, found) = (d, (kind=:point, of=String(q["id"]), n=id, at=Sketching.world(f, spot))))
  end
  found === nothing || return found
  best = 6.0
  for c in get(s, "curves", Any[])
    line = [seen(p) for p in Sketching.outline(c)]
    any(p -> p[3] <= 0, line) && continue
    for i in 1:length(line)-1
      d, _ = Scenes.off(at, line[i], line[i+1])
      d < best && ((best, found) = (d, (kind=:curve, of=String(c["id"]), n=id, at=point_at(v, at))))
    end
  end
  found
end

"""
The region of a sketch that shows at the place `at` of the picture, or
nothing. A sketch farther along the line of sight than `before` is hidden by
what's there. A sketch drawn on a face still shows.
"""
region_under(v::DesignView, at; before=Inf) = begin
  line = Scenes.ray(v.eye, (v.area[3], v.area[4]), at)
  for (id, s) in v.model.sketches
    f = Sketching.Frame(s["plane"])
    spot = Sketching.on_plane(f, line)
    spot === nothing && continue
    Scenes.dot(Sketching.world(f, spot) .- line[1], line[2]) > before * (1 + 1e-4) + 1e-3 && continue
    r = regions(v, s)
    n = Sketching.region(r, spot)
    n >= 2 || continue
    inside = Sketching.inside(r, n)
    return (kind=:region, of=n, n=id, at=(inside[1], inside[2], 0.0))
  end
  nothing
end

"""
What a click at `at` gives a field of profiles: the region of a sketch that
shows there, or else a flat face of a body. A face in front of a sketch hides it.
"""
profile_under(v::DesignView, at) = begin
  m = v.model
  line = Scenes.ray(v.eye, (v.area[3], v.area[4]), at)
  hit = Scenes.hit(m.shapes, line; shown=Designs.shows(m))
  region = region_under(v, at; before=hit === nothing ? Inf : hit.far)
  region === nothing || return region
  hit === nothing && return nothing
  shape = m.shapes[hit.shape]
  shape.flat[hit.face] ? (kind=:face, of=shape.name, n=hit.face, at=hit.point) : nothing
end

"What shows at the place `at` of the picture, of the kinds that a click there would take"
under(v::DesignView, at) = begin
  m = v.model
  for s in Iterators.reverse(v.spots)
    x, y, w, h = s.box
    x <= at[1] <= x + w && y <= at[2] <= y + h && return s.what
  end
  s = sketch(v)
  if s !== nothing && v.tool !== :project
    return sketch_under(v, s, at)
  end
  field = wanted(v)
  kind = field === nothing ? :any : field.kind
  kind == :profiles && return profile_under(v, at)
  size = (v.area[3], v.area[4])
  shown = Designs.shows(m)
  hit = Scenes.hit(m.shapes, Scenes.ray(v.eye, size, at); shown)
  # A plane of the origin or a construction plane. A form that asks for a plane takes the nearest of it and a body's face.
  # With no form, a body in front or behind wins, so that a plane never gets in the way of a face.
  flat_one = square_under(v, at)
  if flat_one !== nothing && ((kind == :plane && (hit === nothing || flat_one[2] < hit.far)) || (kind == :any && hit === nothing))
    return flat_one[1]
  end
  if kind in (:any, :edges)
    e = Scenes.edge_at(m.shapes, v.eye, size, at, hit; shown)
    e === nothing || return (kind=:edge, of=m.shapes[e[1]].name, n=e[2], at=e[3])
    kind == :edges && return nothing
  end
  hit === nothing && return nothing
  shape = m.shapes[hit.shape]
  kind in (:bodies, :body) && return (kind=:body, of=shape.name, n=0, at=hit.point)
  kind == :plane && !shape.flat[hit.face] && return nothing
  (kind=:face, of=shape.name, n=hit.face, at=hit.point)
end

"""
The place of the sketch `s` that a click at `at` in the picture takes: `spot`.
It snaps to a point of the sketch that's near, whose id is then `ref`, and
after a first click to level or upright with that click (`level`).
"""
aim(v::DesignView, s, at) = begin
  f = Sketching.Frame(s["plane"])
  size = (v.area[3], v.area[4])
  spot = Sketching.on_plane(f, Scenes.ray(v.eye, size, at))
  spot === nothing && return (spot=(0.0, 0.0), ref=nothing, level=false)
  v.snap || return (spot=spot, ref=nothing, level=false)
  for q in get(s, "points", Any[])
    p = Sketching.spot(q["at"])
    x, y, depth = Scenes.at(v.eye, size, Sketching.world(f, p))
    depth > 0 && hypot(x - at[1], y - at[2]) <= 8 && return (spot=p, ref=String(q["id"]), level=false)
  end
  level = false
  if !isempty(v.clicks)
    last = v.clicks[end].spot
    near = 6 / Scenes.scale(v.eye, size)
    abs(spot[1] - last[1]) < near && ((spot, level) = ((last[1], spot[2]), true))
    abs(spot[2] - last[2]) < near && ((spot, level) = ((spot[1], last[2]), true))
  end
  (spot=spot, ref=nothing, level=level)
end

"How a click is sent to SolidCraft: the id of the point that it snapped to, or its place"
place(c) = c.ref === nothing ? Any[c.spot[1], c.spot[2]] : c.ref

"Run the tool's command with the clicks that it has"
finish_tool!(v::DesignView) = begin
  tool = v.tool
  tool isa Commands.Tool || return v
  clicks = v.clicks
  params = JSON.Object()
  if tool.clicks == ["points"]
    length(clicks) < 2 && return (empty!(v.clicks); v)
    params["points"] = Any[place(c) for c in clicks]
    tool.command == "sketch.line" && any(c -> c.level, clicks) && (params["infer"] = true)
  else
    length(clicks) < length(tool.clicks) && return v
    for (name, c) in zip(tool.clicks, clicks)
      isempty(name) || (params[name] = place(c))
    end
    isempty(tool.measure) || (params[tool.measure] = hypot((clicks[end].spot .- clicks[end-1].spot)...))
  end
  for field in tool.fields
    box = get(v.parts, (:toolfield, tool.command, field.key), nothing)
    text = box === nothing ? String(field.default) : text_of(box)
    Commands.iscode(field) || (params[field.key] = Commands.value(text); continue)
    r = read_code(v, box === nothing ? Expressions.julia_code(text) : text, field.kind, field.label)
    r === nothing && continue
    # What's wrong shows under the field, and the clicks start again
    r isa String && return (box === nothing || wrong!(v, box, r); empty!(v.clicks); v)
    params[field.key] = r.sent
  end
  v.building && (params["construction"] = true)
  # A line goes on from where it ended, until Return or Escape
  last = clicks[end]
  empty!(v.clicks)
  tool.command == "sketch.line" && push!(v.clicks, (spot=last.spot, ref=last.ref, level=false))
  Designs.change!(v.model, tool.command, params)
  v
end

"A click in the sketch `s` while a tool is in use"
tool_click!(v::DesignView, s, at, what, twice) = begin
  tool, m = v.tool, v.model
  f = Sketching.Frame(s["plane"])
  spot = Sketching.on_plane(f, Scenes.ray(v.eye, (v.area[3], v.area[4]), at))
  spot === nothing && return v
  here = Any[spot[1], spot[2]]
  if tool == :dimension
    # A click on a point or a curve chooses it. A click beside them puts the dimension there.
    what !== nothing && what.kind in (:point, :curve) ? pick!(v, what, true) : isempty(chosen(v)) || dimension!(v, spot)
  elseif tool in (:trim, :extend)
    what !== nothing && what.kind == :curve && Designs.change!(m, "sketch." * String(tool), JSON.Object("curve" => what.of, "at" => here))
  elseif tool == :project
    what === nothing || what.kind in (:edge, :face) && Designs.change!(m, "sketch.project", JSON.Object("refs" => Any[JSON.Object(String(what.kind) => Any[what.at...])]))
  elseif tool isa Commands.Tool
    # Two clicks at one place end a line or a curve through many points
    if twice && tool.clicks == ["points"]
      tool.command == "sketch.line" ? empty!(v.clicks) : finish_tool!(v)
      return v
    end
    push!(v.clicks, aim(v, s, at))
    (tool.clicks == ["points"] ? tool.command == "sketch.line" && length(v.clicks) >= 2 : length(v.clicks) >= length(tool.clicks)) && finish_tool!(v)
  end
  v
end

"Look along the axis of the ball that was clicked"
look_along!(v::DesignView, what) = begin
  turn, tilt = what.of == 1 ? (what.n == 1 ? 0.0 : 180.0, 0.0) : what.of == 2 ? (what.n == 1 ? 90.0 : -90.0, 0.0) : (-90.0, 90.0 * what.n)
  v.eye = Scenes.fit(Scenes.Eye(v.eye.target, turn, tilt, v.eye.distance, v.eye.wide), Scenes.box(showing(v)), (v.area[3], v.area[4]))
  v
end

"Open a field to type the length of the dimension `what` in"
edit_size!(v::DesignView, window, what) = begin
  s = sketch(v)
  s === nothing && return v
  i = findfirst(k -> get(k, "id", "") == what.of, get(s, "constraints", Any[]))
  i === nothing && return v
  k = s["constraints"][i]
  param = get(k, "param", nothing)
  param isa String || return v
  now = get(k, "expression", nothing)
  now isa String || (now = string(get(k, "value", "")))
  at = shown_at(v, what.at)
  at === nothing && return v
  ask!(v, window, (px(at[1] - 50), px(at[2] - 10), 100px, 20px), Expressions.field_code(now, param_note(v, param)), new -> set_param!(v, param, new); width=150px, code=true)
  v
end

"A click that didn't move: it selects, or fills the field of the form that's lit"
click!(v::DesignView, what, more) = begin
  field = wanted(v)
  if field !== nothing && sketch(v) === nothing
    what === nothing && return v
    suits = field.kind == :edges ? what.kind == :edge : field.kind == :profiles ? what.kind in (:region, :face) :
            field.kind in (:bodies, :body) ? what.kind == :body : field.kind == :plane ? what.kind in (:face, :plane) : what.kind == :face
    suits && take!(v.form, field, what)
    return v
  end
  what === nothing ? (more || empty!(v.picked)) : pick!(v, what, more)
  v
end

"""
The mouse was pressed on a design that's only shown. A drag from here turns
it, and with ⇧ held moves it. Two clicks show all of it again. In a page, a
click with ⌘ or ⌥ held is the page's.
"""
grab!(v::DesignView, e) = begin
  cmd, _, opt, _ = held_keys(e.window)
  !v.fill && (cmd || opt) && return nothing
  # The keyboard comes too, so that the button's release comes here
  focus(v)
  at = local_spot(v, e.window.mouse)
  v.mouse = at
  now = time()
  last = get(v.parts, :clicked_at, (-99.0, -99.0))
  twice = now - v.clicked < 0.4 && hypot(at[1] - last[1], at[2] - last[2]) < 5
  v.clicked = twice ? 0.0 : now
  v.parts[:clicked_at] = at
  twice && return (home!(v); handled)
  v.drag = Drag(:press, at, nothing, Keys.shft in e.window.keys, point_at(v, at), (0.0, 0.0), false)
  handled
end

onkey(v::DesignView, e::KeyPress{Keys.mouse_left}) = begin
  v.model === nothing && return
  v.readonly && return grab!(v, e)
  focus(v)
  hide_tooltip!(e.window)
  at = local_spot(v, e.window.mouse)
  v.mouse = at
  what = under(v, at)
  # Two clicks are one after the other at one place. Two quick clicks at two places are two points of a line.
  now = time()
  last = get(v.parts, :clicked_at, (-99.0, -99.0))
  twice = now - v.clicked < 0.4 && hypot(at[1] - last[1], at[2] - last[2]) < 5
  v.clicked = twice ? 0.0 : now
  v.parts[:clicked_at] = at
  what !== nothing && what.kind == :look && return (look_along!(v, what); handled)
  s = sketch(v)
  if s !== nothing
    v.tool === nothing || return (tool_click!(v, s, at, what, twice); handled)
    twice && what !== nothing && what.kind == :size && return (edit_size!(v, e.window, what); handled)
  end
  v.drag = Drag(:press, at, what, Keys.shft in e.window.keys, what === nothing ? point_at(v, at) : what.at, (0.0, 0.0), false)
  handled
end

onkey(v::DesignView, e::KeyRelease{Keys.mouse_left}) = begin
  d = v.drag
  v.drag = nothing
  d === nothing && return handled
  v.readonly && return handled
  d.kind == :press && click!(v, d.what, d.more)
  d.kind == :pull && v.model !== nothing && Designs.change!(v.model, "sketch.drag_end")
  handled
end

"The point that a turn goes round: the one that ⇧ and a click of the middle button put, or else `p`"
turns_round(v::DesignView, p) = get(v.parts, :pivot, p)

"""
⇧ and a click of the middle button at `at`, as in Fusion 360: a turn goes round
the point of the design that was clicked from now on. A click on nothing takes
that point away.
"""
place_pivot!(v::DesignView, at) = begin
  line = Scenes.ray(v.eye, (v.area[3], v.area[4]), at)
  hit = Scenes.hit(v.model.shapes, line; shown=Designs.shows(v.model))
  s = sketch(v)
  spot = hit === nothing && s !== nothing ? Sketching.on_plane(Sketching.Frame(s["plane"]), line) : nothing
  if hit !== nothing
    v.parts[:pivot] = hit.point
  elseif spot !== nothing
    v.parts[:pivot] = Sketching.world(Sketching.Frame(s["plane"]), spot)
  else
    delete!(v.parts, :pivot)
  end
  v
end

# The right button turns the design
onkey(v::DesignView, e::KeyPress{Keys.mouse_right}) = begin
  v.model === nothing && return
  at = local_spot(v, e.window.mouse)
  focus(v)
  v.drag = Drag(:turn, at, nothing, false, turns_round(v, point_at(v, at)), (0.0, 0.0), false)
  handled
end
onkey(v::DesignView, ::KeyRelease{Keys.mouse_right}) = (v.drag = nothing; handled)

# The middle button is Fusion 360's: a drag moves the design, with ⇧ it turns it, and with ⌃⇧ it brings it nearer.
# Two clicks show all of it, and ⇧ with a click puts the point that a turn goes round.
onkey(v::DesignView, e::KeyPress{Keys.mouse_middle}) = begin
  v.model === nothing && return
  focus(v)
  hide_tooltip!(e.window)
  at = local_spot(v, e.window.mouse)
  v.mouse = at
  # The second click is a press soon after a click at the same place
  last = get(v.parts, :middle_at, (-99.0, -99.0))
  twice = time() - get(v.parts, :middle_clicked, 0.0) < 0.4 && hypot(at[1] - last[1], at[2] - last[2]) < 5
  twice && (delete!(v.parts, :middle_clicked); v.drag = nothing; fit!(v); return handled)
  _, shift, _, ctrl = held_keys(e.window)
  does = shift && ctrl ? :zoom : shift ? :turn : :move
  about = point_at(v, at)
  v.drag = Drag(:middle, at, does, false, does == :turn ? turns_round(v, about) : about, (0.0, 0.0), false)
  handled
end

onkey(v::DesignView, ::KeyRelease{Keys.mouse_middle}) = begin
  d = v.drag
  v.drag = nothing
  # A click: the mouse didn't move while the button was down
  if d isa Drag && d.kind == :middle
    d.what == :turn && place_pivot!(v, d.at)
    v.parts[:middle_clicked] = time()
    v.parts[:middle_at] = d.at
  end
  handled
end

"Move what's held in the sketch towards the place `at` of the picture, as far as its constraints let it go"
pull!(v::DesignView, d::Drag, at) = begin
  s, m = sketch(v), v.model
  (s === nothing || d.busy) && return
  spot = Sketching.on_plane(Sketching.Frame(s["plane"]), Scenes.ray(v.eye, (v.area[3], v.area[4]), at))
  spot === nothing && return
  d.busy = true
  Designs.change!(m, "sketch.drag", JSON.Object("entity" => d.what.of, "from" => Any[d.from...], "to" => Any[spot...], "live" => true); quiet=true,
    then=(answer, problem) -> begin
      d.busy = false
      now = answer isa AbstractDict ? get(answer, "at", nothing) : nothing
      now isa Vector && length(now) == 2 && (d.from = Sketching.spot(now))
    end)
end

onmouse(v::DesignView, e::MouseMove) = begin
  v.model === nothing && return
  at = local_spot(v, e.position)
  d = v.drag
  size = (v.area[3], v.area[4])
  # A button that was let go outside the window ends what it was doing
  held_ = Keys.mouse_left in e.window.keys || Keys.mouse_right in e.window.keys || Keys.mouse_middle in e.window.keys
  d === nothing || held_ || (v.drag = d = nothing)
  if d === nothing
    v.mouse = at
    # Nothing lights in a design that's only shown, and the mouse's move goes on to the page
    v.readonly && return (v.hover = nothing)
    v.hover = panel_at(v, e.window, e.position) === nothing ? under(v, at) : nothing
    return handled
  end
  by = (at[1] - d.at[1], at[2] - d.at[2])
  if d.kind == :middle
    hypot(by...) < 4 && return handled
    d.kind = d.what
    v.hover = nothing
  elseif d.kind == :press
    hypot(by...) < 4 && return handled
    s = v.readonly ? nothing : sketch(v)
    if s !== nothing && d.what !== nothing && d.what.kind in (:point, :curve)
      d.kind = :pull
      spot = Sketching.on_plane(Sketching.Frame(s["plane"]), Scenes.ray(v.eye, size, d.at))
      d.from = spot === nothing ? (0.0, 0.0) : spot
    else
      # In a sketch a drag moves the view, since it's seen flat. Out of one it turns the design, and ⇧ moves it.
      d.kind = d.more || s !== nothing ? :move : :turn
      d.kind == :turn && (d.pivot = turns_round(v, d.pivot))
    end
    v.hover = nothing
  end
  d.kind == :turn && (v.eye = Scenes.turned(v.eye, size, -0.4by[1], 0.4by[2], d.pivot))
  d.kind == :move && (v.eye = Scenes.moved(v.eye, size, by, d.pivot))
  # Up brings the design nearer
  d.kind == :zoom && (v.eye = Scenes.nearer(v.eye, size, exp(-by[2] / 100), d.pivot))
  d.kind == :pull && pull!(v, d, at)
  d.at = at
  v.mouse = at
  handled
end

# The wheel brings the design nearer, as in Fusion 360, and with ⇧ held turns it. Two fingers on the trackpad do the same:
# Ladder can't tell them from the wheel of a mouse that scrolls smoothly.
onscroll(v::DesignView, e::MouseScroll) = begin
  v.model === nothing && return
  # In a page, the wheel and two fingers scroll the page, unless ⌘ is held
  v.readonly && !v.fill && !(Keys.cmd in e.window.keys) && return nothing
  over = panel_at(v, e.window)
  dx, dy = num(e.delta[1]), num(e.delta[2])
  if over == :history
    v.along -= (abs(dx) > abs(dy) ? dx : dy) * (e.wheel ? 30 : 1)
    return handled
  end
  over === nothing || return
  at = local_spot(v, e.window.mouse)
  size = (v.area[3], v.area[4])
  about = point_at(v, at)
  if Keys.shft in e.window.keys
    v.eye = Scenes.turned(v.eye, size, -0.4dx, 0.4dy, turns_round(v, about))
  else
    v.eye = Scenes.nearer(v.eye, size, exp(dy / (e.wheel ? 6 : 60)), about)
  end
  handled
end

onpinch(v::DesignView, e::Pinch) = begin
  (v.model === nothing || panel_at(v, e.window) !== nothing) && return
  at = local_spot(v, e.window.mouse)
  v.eye = Scenes.nearer(v.eye, (v.area[3], v.area[4]), e.scale, point_at(v, at))
  handled
end

cursor(v::DesignView) = v.tool !== nothing ? :crosshair : nothing

# --- the keys ------------------------------------------------------------------------

onkey(v::DesignView, e::KeyPress{Keys.escape}) = begin
  v.readonly && return nothing
  if !isempty(v.clicks)
    empty!(v.clicks)
  elseif v.tool !== nothing
    v.tool = nothing
  elseif v.form !== nothing
    v.form = nothing
  elseif v.panel != :none
    v.panel = :none
  else
    empty!(v.picked)
  end
  focus(v)
  handled
end

onkey(v::DesignView, e::KeyPress{Keys.enter}) = begin
  v.readonly && return nothing
  box = keyed(e.window.focus)
  # ⌘Return runs the code of a field, as it does in a Julia file
  iscode(box) && held_keys(e.window) == (true, false, false, false) && return (run_field!(v, box); handled)
  done = commit!(v, box)
  done === :wrong && return handled
  done === nothing || return (focus(v); handled)
  if v.tool isa Commands.Tool && v.tool.clicks == ["points"] && !isempty(v.clicks)
    v.tool.command == "sketch.line" ? empty!(v.clicks) : finish_tool!(v)
  elseif v.form !== nothing
    apply!(v)
  end
  handled
end

"Take what's selected out of the design: the points, curves and constraints of a sketch, or steps and bodies"
delete_picked!(v::DesignView) = begin
  m = v.model
  if sketch(v) !== nothing
    ids = String[p.of for p in v.picked if p.kind in (:point, :curve, :mark, :size)]
    isempty(ids) || Designs.change!(m, "sketch.delete", JSON.Object("entities" => ids))
  else
    steps = Int[p.n for p in v.picked if p.kind == :step]
    bodies = String[p.of for p in v.picked if p.kind == :body]
    isempty(steps) || Designs.change!(m, "timeline.delete", JSON.Object("features" => steps))
    isempty(bodies) || Designs.change!(m, "solid.remove", JSON.Object("bodies" => bodies))
  end
  empty!(v.picked)
  v
end

onkey(v::DesignView, e::KeyPress{Keys.backspace}) = e.window.focus === v && !v.readonly ? (delete_picked!(v); handled) : nothing
onkey(v::DesignView, e::KeyPress{Keys.delete}) = e.window.focus === v && !v.readonly ? (delete_picked!(v); handled) : nothing

"Which of ⌘, ⇧, ⌥ and ⌃ are held"
held_keys(w) = (Keys.cmd in w.keys, Keys.shft in w.keys, Keys.opt in w.keys, Keys.ctrl in w.keys)

# ⌘S writes the file. ⌘Z takes back the last change, and ⇧⌘Z does it again. A design that's only shown leaves them to the page.
onkey(v::DesignView, e::KeyPress{Keys.s}) = !v.readonly && held_keys(e.window) == (true, false, false, false) ? (save!(v); handled) : nothing
onkey(v::DesignView, e::KeyPress{Keys.z}) = begin
  v.readonly && return nothing
  keys = held_keys(e.window)
  keys == (true, false, false, false) ? (undo!(v); handled) : keys == (true, true, false, false) ? (redo!(v); handled) : nothing
end

# A letter starts a command while the design has the keyboard, and not while a field is typed in
ontype(v::DesignView, e::Typed) = begin
  (v.model === nothing || v.readonly || e.window.focus !== v) && return
  (Keys.cmd in e.window.keys || Keys.ctrl in e.window.keys) && return
  id = get(sketch(v) === nothing ? MODEL_KEYS : SKETCH_KEYS, lowercase(e.char), nothing)
  id === nothing && return
  start!(v, id, e.window)
  handled
end
