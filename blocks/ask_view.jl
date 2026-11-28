# The view of an `ask` block: a question with answers to choose
#
# A code block in the language `ask` shows a question, the answers to choose
# from, and a field to type in. ask.jl says how the block is written. A click
# on an answer chooses it, and what you type in the field goes under the
# answers. A line like `Size: 48px (16px to 96px)` shows a slider, and a line
# like `Colour: #e8632b` a colour picker. All of these are written into the
# block's lines. So an agent that waits for the page reads your answer in the
# lines that you changed. The block has no button that sends them: the bell in
# the top bar sends the page, and so does ⌘Return. In what an agent said in a
# session, your next words send them: see "what you change in a reply".

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/Specific" skia_cap_height
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ishovered cursor
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/Slider" Slider
@use "github.com/jkroso/UI.jl/Interface/Semantic/ColorPicker" ColorPicker
@use "./html" escape
@use "./sheet" parts
@use "./ask" => Asks
@use Colors: @colorant_str, RGB, HSV, Colorant
@use "./base" exports...

export ASK, AskView, AskOption, ask_input, colour_of, colour_hex, ask_field, beside_mark, ASK_NAME_W,
       ask_field_row, ask_html

const ASK = Asks.ASK
push!(BLOCK_ICONS, "question-circle", "check")

"What an `ask` block shows: a question, its answers and a field to type in"
@def mutable struct AskView <: SemanticUI
  n::Int = 0                               # its place among the page's questions
  first::Int = 0                           # the lines of its block, when the page was last laid out
  last::Int = 0
  data::Asks.Question = Asks.Question()
  lines::Vector{String} = String[]         # the lines that `data` was read from
  parts::Dict{Any,Any} = Dict{Any,Any}()   # its answers, its field and its button, kept between frames
end

"An answer of a question. A click chooses it."
@def mutable struct AskOption <: SemanticUI
  of::Any = nothing
  i::Int = 0
end

"The text field of a question"
ask_input(v::AskView) = block_part!(v, :input) do
  TextInput(placeholder="", font_family=SANS, font_size=13px,
            look=(_, text) -> Row(width(grow=grow), height(grow=grow), clip=true, text))
end

"The colour that a line of a question names, like #e8632b"
colour_of(f::Asks.Field) = try parse(Colorant, f.colour) catch; colorant"black" end

"A colour as a line writes it: # and its red, green and blue in hexadecimal, like #e8632b"
colour_hex(c) = (rgb = convert(RGB, c); "#" * join(string(round(Int, 255 * clamp(x, 0, 1)), base=16, pad=2) for x in (rgb.r, rgb.g, rgb.b)))

"The slider or the colour picker of the `i`th value that the question of `v` asks for"
ask_field(v::AskView, i::Int) = begin
  f = v.data.fields[i]
  part = get(v.parts, (:field, i), nothing)
  (f.kind == :slider ? part isa Slider : part isa ColorPicker) && return part
  delete!(v.parts, (:field, i))
  block_part!(v, (:field, i)) do
    f.kind == :colour ? ColorPicker(color=convert(HSV, colour_of(f))) :
      Slider(value=f.number, min=f.low, max=f.high, step=Asks.step(f),
             format=x -> i <= length(v.data.fields) ? Asks.said(v.data.fields[i], x) : "")
  end
end

reread!(v::AskView, lines) = begin
  lines == v.lines && return v
  v.lines = lines
  v.data = Asks.question(lines)
  # The field shows what the block says was typed, as it does after ⌘Z takes some of it back
  i = ask_input(v)
  i.text == v.data.note || (i.text = v.data.note; i.anchor = i.cursor = length(i.text))
  # So does each slider and colour picker
  for (k, f) in enumerate(v.data.fields)
    part = ask_field(v, k)
    if f.kind == :slider
      part.min, part.max, part.step = f.low, f.high, Asks.step(f)
      part.value == f.number || (part.value = f.number)
    else
      colour_hex(part.color) == colour_hex(colour_of(f)) || (part.color = convert(HSV, colour_of(f)))
    end
  end
  v
end

"""
What happens to a question in each frame, before the page is laid out: what
was typed in its field, where its sliders are set and the colours that were
picked are written into its block
"""
block_tick!(v::AskView) = begin
  q = v.data
  changed = false
  text = ask_input(v).text
  text == q.note || (q.note = text; changed = true)
  for (i, f) in enumerate(q.fields)
    part = ask_field(v, i)
    if f.kind == :slider
      was = f.number
      Asks.set!(f, part.value)
      changed |= f.number != was
    else
      picked = colour_hex(part.color)
      picked == colour_hex(colour_of(f)) || (f.colour = picked; changed = true)
    end
  end
  changed ? write_block!(v, ASK, Asks.written(q), typing=true) : v
end

"""
A text beside a mark that is `tall`, such as an icon or a tick box. The text
starts lower than the mark, so the middle of its capitals is level with the
middle of the mark. A text that wraps keeps its first line there.
"""
beside_mark(tall, t::Text) = Box(width(grow=grow), padding(max(0px, (tall - skia_cap_height(t)) / 2), 0px, 0px, 0px), t)

describe(o::AskOption) = begin
  q = o.of.data
  o.i <= length(q.options) || return Box(height(0px))
  opt = q.options[o.i]
  # The tick is as big as its box. A smaller icon isn't put in the middle of the box.
  mark = opt.many ?
    (opt.chosen ? Box(fixed(16px), height(16px), radius(4px), background(colours.accent), Icon("check", size=16px, color=colours.bg)) :
                  Box(fixed(16px), height(16px), radius(4px), border(1.5px, :solid, colours.marker))) :
    Box(fixed(16px), height(16px), radius(8px), Alignment.Center, justify=Alignment.Center,
        border(1.5px, :solid, opt.chosen ? colours.accent : colours.marker),
        (opt.chosen ? (Box(fixed(8px), height(8px), radius(4px), background(colours.accent)),) : ())...)
  Row(width(grow=grow), padding(8px, 6px), radius(6px), child_gap=10px, Alignment.Start, name="Answer",
      background(opt.chosen ? colours.active : ishovered(o) ? colours.hover : clear),
    Box(mark),
    beside_mark(16px, Text(opt.text, size=13.5px, family=SANS, subfamily=opt.chosen ? "Medium" : "", color=colours.ink, wrap=WrapMode.words)))
end

cursor(::AskOption) = :hand
cursor(::AskView) = :arrow

onkey(o::AskOption, ::KeyPress{Keys.mouse_left}) = begin
  v = o.of
  o.i <= length(v.data.options) || return handled
  Asks.choose!(v.data, o.i)
  write_block!(v, ASK, Asks.written(v.data))
  handled
end

describe(v::AskView) = begin
  e = editor(v)
  q = v.data
  input = ask_input(v)
  input.color = colours.ink
  input.placeholder = isempty(q.options) && isempty(q.fields) ? "Type your answer" : "Add a note"
  w = window_of(v)
  typing = w !== nothing && w.focus === input
  with_theme(component_theme(e.zoom)) do
    Column(block_look()..., padding(16px, 14px), child_gap=10px, name="Question",
      Row(width(grow=grow), child_gap=10px, Alignment.Start,
        Box(padding(0px, 1px), Icon("question-circle", size=16px, color=Asks.answered(q) ? colours.string : colours.accent)),
        beside_mark(18px, Text(isempty(q.words) ? "A question with no words yet" : Asks.asked(q), size=15px, family=SANS,
                               subfamily="Semibold", color=isempty(q.words) ? colours.dim : colours.ink, wrap=WrapMode.words))),
      (ask_field_row(v, i) for i in eachindex(q.fields))...,
      (isempty(q.options) ? () : (Column(width(grow=grow), Alignment.Start, child_gap=2px,
        [block_part!(() -> AskOption(of=v, i=i), v, (:option, i)) for i in eachindex(q.options)]...),))...,
      Box(width(grow=grow), height(30px), padding(9px, 0px), radius(6px), border(1px, :solid, typing ? colours.accent : colours.line),
          background(colours.bg), input))
  end
end

const ASK_NAME_W = 110px   # of the name beside a slider

"A value that a question asks for: its name, with a slider beside it, or a colour picker under it"
ask_field_row(v::AskView, i::Int) = begin
  f = v.data.fields[i]
  name = Text(f.name, size=13.5px, family=SANS, color=colours.ink, wrap=WrapMode.words)
  f.kind == :slider ?
    Row(width(grow=grow), padding(4px, 6px), child_gap=12px, Alignment.Center, name="Slider",
      Box(fixed(ASK_NAME_W), name), Box(width(grow=grow), ask_field(v, i))) :
    Column(width(grow=grow), padding(4px, 6px), child_gap=8px, Alignment.Start, name="Colour", Box(name), ask_field(v, i))
end

# Return in the field gives the keyboard back to the page
onkey(v::AskView, ev::KeyPress{Keys.enter}) = unmodified(ev) ? (focus(editor(v)); handled) : nothing

"The question as HTML: its words, and each answer with a mark on the ones that are chosen"
ask_html(e, v::AskView) = begin
  q = v.data
  rows = ["<li>$(o.chosen ? "☑" : "☐") $(o.chosen ? "<strong>$(escape(o.text))</strong>" : escape(o.text))</li>" for o in q.options]
  values = [f.kind == :slider ? "<li>$(escape(f.name)): <strong>$(escape(Asks.said(f)))</strong></li>" :
            "<li>$(escape(f.name)): <span style=\"display: inline-block; width: 0.9em; height: 0.9em; vertical-align: middle; background: $(colour_hex(colour_of(f)))\"></span> <strong>$(escape(f.colour))</strong></li>"
            for f in q.fields]
  "<p><strong>$(escape(Asks.asked(q)))</strong></p>\n" * (isempty(values) ? "" : "<ul>\n" * join(values, "\n") * "\n</ul>\n") * (isempty(rows) ? "" : "<ul style=\"list-style: none; padding-left: 0.5em\">\n" * join(rows, "\n") * "\n</ul>\n") *
  (isempty(strip(q.note)) ? "" : "<blockquote>$(escape(q.note))</blockquote>")
end

BLOCKS[ASK] = AskView
block_name(::Type{AskView}) = "Question"
block_icon(::Type{AskView}) = "question-circle"
block_html(e, v::AskView) = ask_html(e, v)
