# The command palette (⌘⇧P): how it asks for what a command takes, what's in focus, its lists, its keys, a look before you choose, and how it looks

@use "github.com/jkroso/Prospects.jl" @def
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/draw" scene
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode with_theme describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect with_clip
@use "github.com/jkroso/UI.jl/Interface/fonts" register_font weight_of weight_name
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/TextInput" TextInput
@use "github.com/jkroso/UI.jl/Interface/Semantic/ListTree" => Tree
@use "./markdown" Kind words
@use "./sheet" parts shown
@use "./spreadsheet" letters moved
@use "github.com/jkroso/URI.jl/FS" => FS FSObject
@use Colors: @colorant_str, RGBA
@use Dates: Dates, Date, Day
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./strokes" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./additions" exports...
@use "./folder_page" exports...
@use "./views" exports...
@use "./sketch_view" exports...
@use "./julia_levels" exports...
@use "./file_view" exports...
@use "./live_view" exports...
@use "./schedule_view" exports...
@use "./email_head" exports...
@use "./page_extras" exports...
@use "./levels_view" exports...
@use "./code_thing" exports...
@use "./folder_kinds" exports...
@use "./remote_page" exports...
@use "./showed_before" exports...
@use "./sum_functions" exports...
@use "./editing" exports...
@use "./commands" exports...
@use "./startup_page" exports...

export Argument, CommandPalette, OMNI_BAR_X, OMNI_BAR_Y, OMNI_BLUR, OMNI_BOTTOM, OMNI_CHIP_H,
       OMNI_CHOICES_MOST, OMNI_DARK, OMNI_FADE, OMNI_FIELD_H, OMNI_FONT_FILES, OMNI_GAP, OMNI_GO,
       OMNI_GO_INK, OMNI_GO_LINE, OMNI_KNOB, OMNI_LEFT, OMNI_LIGHT, OMNI_LIST_MOST, OMNI_MATCH,
       OMNI_NAME, OMNI_POP_GAP, OMNI_RIGHT, OMNI_RISE, OMNI_ROW, OMNI_ROW_ONE, OMNI_SWITCH_OFF,
       OMNI_SWITCH_ON, OMNI_TAG, OMNI_TAG_INK, OMNI_TOP, OMNI_WORDS_LEAST, OMNI_WORDS_MOST,
       OMNI_WRONG, PaletteBar, PaletteCatch, PaletteChip, PaletteFrost, PaletteLens, PaletteMore,
       PaletteRow, PaletteRun, SITE_FONT_FILES, UNSAID, Unsaid, Wanted, adds_things, askable,
       askable_types, best_fits, blur_under, chip_choices, chip_letters, chip_name, chip_points,
       chip_tip, chip_typed, chip_value, chip_wide, chooses, chosen_path, click_chip,
       clicked_thing, close_palette!, command_fit, counts_from, drawn_for, focus_taken, font_from,
       hit_past, in_palette, key_signs, load_omni_font, load_site_font, match_parts,
       method_keywords, next_mark, omni, omni_at, omni_family, omni_field, omni_font, omni_key,
       omni_weight, omni_wide, on_palette, paler, palette_address, palette_advanced!, palette_args,
       palette_bar_lines, palette_browse!, palette_clear!, palette_commands, palette_fit,
       palette_fits, palette_focus!, palette_ghost, palette_items, palette_lines, palette_moving,
       palette_name, palette_next!, palette_risen, palette_room, palette_rows, palette_run!,
       palette_said, palette_say!, palette_shows, palette_sync!, palette_tab!, palette_take!,
       palette_target, palette_text!, preview!, reads, ready_method, resize_thing!,
       run_when_ready!, segment_state, segment_step!, start_chips!, strip_text, switch!,
       take_command!, thing_chip, type_words, unpreview!

# --- the command palette --------------------------------------------------------------------
#
# ⌘⇧P opens the command palette. It's Ladder's command line, and it's a copy of
# the omnibar of Centient: how it looks, where it is and what each key does.
# The sizes and the colours here are from Centient's style sheets, and the
# rules are from its code (src/omnibar in Centient). Where Ladder has no use
# for a part of the omnibar, this section says so.
#
# A bar slides up from the bottom of the window, beside the sidebar. Type some
# letters of a command's name, or of what it does. A list over the bar keeps
# the commands that have them, with the nearest first. With no letters, it has
# every command in the order of the alphabet. ↑ and ↓ choose a row, Tab types
# the rest of the first name, Return takes the row, and esc clears the bar.
# Esc in an empty bar closes it. A row has the command's keys at its right.
#
# The list has only the commands that have a use where the keyboard was when
# the palette opened. What's in focus there says which: the part of the page
# that the caret is on, the page, its file and its folder. See "what's in
# focus". A command that works on one of those has its name after its own in
# the row, as Move To Trash has the name of the file. Centient's omnibar has
# no such rule: this is Ladder's own.
#
# A command that takes nothing runs when it's taken. A command that is a Julia
# function asks for each thing that the function takes. Its name stays in the
# bar as a tag, with a chip after it for each argument and a Run button after
# those. A chip is made from an argument's name and its type. The type says
# what kind of chip it is:
#
#   - a switch, for a `Bool`. Space turns it on or off. Return does too, and
#     goes on to the next chip.
#   - a choice of two, for a type with two fixed things to choose from. Both
#     show in the chip. ← and → choose, and so do Space and Return.
#   - a list of three or four fixed things. It hangs over the chip. ↑ and ↓
#     choose, and Return or Tab takes the row and goes on.
#   - a list that's searched, for five or more things, or things that change,
#     like the headings of the page. What you type keeps the rows that have
#     those letters. ↑ and ↓ choose a row, and Return or Tab takes it.
#   - a number or words, which you type. The chip has them as you type, and
#     Return goes on. ↑ and ↓ add one to a number, or take one away.
#
# Tab and ⇧Tab go from chip to chip, round through the Run button. Return on
# Run calls the function. A function's keyword arguments are chips too, which
# show when you press ⌥ and hide when you press it again. Chips that don't fit
# in the bar end in a … button: a click on it, or Tab past the last chip that
# shows, puts them on more lines.
#
# A type says how it's asked for with methods:
#
#   - `choices_for(::Type{T}, e)` gives the things of type `T` to choose
#     from, for the editor `e`
#   - `typed_as(::Type{T}, text)` gives the thing of type `T` that `text`
#     writes, or nothing when it writes none
#   - `chip_kind(::Type{T})` is `:choice` for a type whose things to choose
#     from are few and fixed, like the colours of a page
#   - `worded(x)` gives the words that a row and a chip show for `x`, and
#     `sidenote(x)` the fainter words at the right of its row
#
# An argument of type `Editor`, or one called `e` with no type, isn't asked
# for: it's the window's editor. A `Window`, or a `w` with no type, is its
# window. An argument of a type with neither of the first two methods can't be
# asked for. It's the nearest thing in focus of that type, like the file that
# shows for a `File`. The palette leaves out a method when nothing in focus is
# of that type, and a command when it has no method left.
#
# A function can have several methods, as in Centient. Where they take the
# same type, there's one chip. Where they take a type itself, like
# `f(::Type{Page})` and `f(::Type{Folder})`, the chip chooses between them and
# the chips after it wait for that. Where they take values of different types,
# the chip takes any of them and the chips of the first method show. What's
# said then chooses the methods that go on, so Julia's own dispatch chooses
# what runs. A method that stops where another goes on makes the chips after
# that place ones that can be left out.
#
# What Centient's omnibar has that this doesn't: the bar isn't in the window
# all the time, and the strip that it's in has no colour of its own, so the
# page shows through it, blurred. It takes no message for an agent, so there's no `/` before a
# command. A click outside the list closes the palette. A date is typed, with
# no calendar. A command runs at once, so the Run button never shows that it's
# running. `add_command!` makes a function a command: see "commands that are functions".

# The strip that the bar is in: the room round the bar. It has no colour and no line: the page under it is blurred, and the blur fades out above the bar.
const OMNI_TOP, OMNI_RIGHT, OMNI_BOTTOM, OMNI_LEFT = 14.0, 16.0, 16.0, 14.0
const OMNI_FIELD_H = 44.0      # how tall the bar is with only its field in it, without its border
const OMNI_BAR_X, OMNI_BAR_Y = 14.0, 10.0   # the room inside the bar
const OMNI_GAP = 6.0           # between the tag, the chips and the Run button
const OMNI_CHIP_H = 32.0
const OMNI_ROW = 70.0          # a row of a list with a name and what it does under it
const OMNI_ROW_ONE = 50.0      # a row with a name only
# The weight of a name in a list, and of the letters typed that it has. Centient's Medium looked fuzzy in the Mac's font.
const OMNI_NAME, OMNI_MATCH = "SemiBold", "Heavy"
# The palette's text is in Manrope, as Centient's omnibar is. fonts/ has a file for each weight,
# cut from Centient's variable font. A Ladder without those files uses the Mac's font.
# The keys beside a command stay in the Mac's font, because Manrope has no ⌘, ⇧, ⌥ or ⌃.
const OMNI_FONT_FILES = [joinpath(@__DIR__, "fonts", "Manrope-$w.ttf") for w in ("Regular", "Medium", "SemiBold", "Bold", "ExtraBold")]
const omni_family = Ref(SANS)
"The family of the palette's text: Manrope once its files are read, and the Mac's font before that or without them"
omni_font() = omni_family[]
"""
`family`, after the font files `files` are read, or else `fallback`: when a
file isn't there, or can't be read. The app's self-test runs where it can see
Ladder's folder but can't read what's in it.
"""
font_from(files, family, fallback) = all(isfile, files) && (try foreach(register_font, files); true catch; false end) ? family : fallback
"""
Read the palette's font from its files. As with the sheet's font, a built app
forgets them when it starts. The files are looked for each time, not when the
app is built, because a built app can run on a Mac that doesn't have them.
"""
load_omni_font() = omni_family[] = font_from(OMNI_FONT_FILES, "Manrope", SANS)

# The text of a page of a blog is in Literata, the typeface of the blog's site. fonts/ has its upright and
# italic faces in three weights, with the font's licence (Literata-OFL.txt). Without them it's in Charter.
const SITE_FONT_FILES = [joinpath(@__DIR__, "fonts", "Literata-$s.ttf") for s in ("Regular", "Italic", "SemiBold", "SemiBoldItalic", "Bold", "BoldItalic")]
"Read the typeface of a blog's pages from its files, as `load_omni_font` reads the palette's"
load_site_font() = SITE_FONT[] = font_from(SITE_FONT_FILES, "Literata", SERIF)
"""
The name of the face of the palette's font for `weight`. A font from a file is
found only by the name of its weight, spelled as UI.jl spells it: \"SemiBold\",
not \"Semibold\", and \"ExtraBold\" for \"Heavy\". The Mac's font takes any of them.
"""
omni_weight(weight::AbstractString) = omni_font() == SANS ? weight : weight_name(weight_of(weight))
const OMNI_LIST_MOST = 464.0   # the most of the commands' rows that show before the list scrolls
const OMNI_CHOICES_MOST = 200.0   # and of the rows of a chip's list that's searched
const OMNI_POP_GAP = 10.0      # between a list and what it hangs over
const OMNI_RISE = 0.18         # seconds for the bar to slide up or down
const OMNI_BLUR = 10.0         # how far the page under the strip is blurred, in pixels
const OMNI_FADE = 48.0         # how far above the bar's top line the blur fades out

"The colours of the palette on a light page and on a dark one, which are those of Centient's omnibar"
const OMNI_LIGHT = (
  bar=colorant"#f2ebda", bar_line=colorant"#c4b89c",
  chip=colorant"#faf6ec", chip_line=colorant"#ddd4c0", hover=colorant"#e8dfc8", complete=colorant"#e8f5e9",
  drop=colorant"#f2ebda", drop_line=colorant"#b0a488", selected=colorant"#e8dfc8", rule=colorant"#ddd4c0",
  ink=colorant"#1b1710", ink2=colorant"#454034", muted=colorant"#6e6858", placeholder=colorant"#9c9482",
  run=colorant"#e0d4b9", run_hover=colorant"#d5c8ab", run_ink=colorant"#454034",
  key=colorant"#eae1cb", key_line=colorant"#c4b89c", key_ink=colorant"#454034",
  key_on=colorant"#dacead", key_on_line=colorant"#b0a488", key_on_ink=colorant"#1b1710",
  tip=colorant"#1b1710", tip_ink=colorant"#f7f1e3", toast=colorant"#fffaf5")
const OMNI_DARK = (
  bar=colorant"#18181b", bar_line=clear,
  chip=colorant"#27272a", chip_line=clear, hover=colorant"#3f3f46", complete=colorant"#1a3d2e",
  drop=colorant"#18181b", drop_line=colorant"#3f3f46", selected=colorant"#3f3f46", rule=RGBA(1, 1, 1, 0.06),
  ink=colorant"#f0f0f2", ink2=colorant"#a1a1aa", muted=colorant"#52525b", placeholder=colorant"#cbd5e1",
  run=colorant"#374151", run_hover=colorant"#4b5563", run_ink=colorant"#9ca3af",
  key=colorant"#424242", key_line=colorant"#2a2a2a", key_ink=colorant"#aaaaaa",
  key_on=RGBA(1, 1, 1, 0.15), key_on_line=RGBA(0, 0, 0, 0.3), key_on_ink=RGBA(1, 1, 1, 0.85),
  tip=colorant"#18181b", tip_ink=colorant"#fafafa", toast=colorant"#27272a")
const OMNI_TAG, OMNI_TAG_INK = colorant"#4c1d95", colorant"#e9d5ff"       # the command's name
const OMNI_GO, OMNI_GO_INK, OMNI_GO_LINE = colorant"#22c55e", colorant"#052e16", colorant"#86efac"   # the Run button while Return runs the command
const OMNI_SWITCH_ON, OMNI_SWITCH_OFF, OMNI_KNOB = colorant"#8b5cf6", colorant"#374151", colorant"#e2e8f0"
const OMNI_WRONG = colorant"#b42318"

omni(e) = e.theme == :night ? OMNI_DARK : OMNI_LIGHT

"What a chip holds before anything is said for it"
struct Unsaid end
const UNSAID = Unsaid()

"""
One thing that a method takes: its name, the type that it has to be, true
when it's a keyword argument, and what gives it. `from` is nothing for an
argument that the palette asks for, `:editor` or `:window` for the window's
own, and otherwise the thing in focus that the argument is: see `in_focus`.
"""
struct Argument
  name::Symbol
  type::Any
  keyword::Bool
  from::Any
end
Argument(name, type) = Argument(name, type, false, nothing)
Argument(name, type, keyword::Bool) = Argument(name, type, keyword, nothing)

"""
A chip of the palette: the names and the types of the argument in the methods
that are still in the running, true when it can be left out, and true when
it's a keyword argument, which shows only after ⌥.
"""
struct Wanted
  names::Vector{Symbol}
  types::Vector{Any}
  optional::Bool
  keyword::Bool
end
Wanted(names, types, optional) = Wanted(names, types, optional, false)

"What the command palette holds. It's kept from one frame to the next, and starts again each time the palette opens."
@def mutable struct CommandPalette <: SemanticUI
  command::Union{Nothing,Command} = nothing              # the command whose arguments it asks for, or nothing while it lists the commands
  methods::Vector{Vector{Argument}} = Vector{Argument}[]   # the methods of that command's function that it can call
  values::Vector{Any} = Any[]                            # what's said for each chip that isn't a keyword argument, or `UNSAID`
  keywords::Dict{Symbol,Any} = Dict{Symbol,Any}()        # what's said for each keyword argument that has something
  advanced::Bool = false                                 # ⌥ showed the chips of the keyword arguments
  wrap::Bool = false                                     # the chips are on as many lines as they need
  at::Int = 1                                            # the chip that the keyboard is in. One more than the last chip is the Run button.
  pick::Int = 1                                          # the row of the list that Return takes
  shown::Int = 0                                         # the row that the list last scrolled to
  typed::String = ""                                     # what the field held when the palette last looked
  query::String = ""                                     # the letters that keep the rows of a chip's list
  browsed::Bool = false                                  # an arrow chose the row, so the field has its words and the rows stay as they were
  fault::String = ""                                     # what went wrong, to say over the bar
  rows::Vector{Any} = Any[]                              # the rows of the list in the last frame
  scroll::Scroll = Scroll(width(grow=grow))
  moved::Float64 = 0.0                                   # when the bar last started to slide up or down
  from::Float64 = 0.0                                    # how far up it was then, from 0 to 1
  plan::Any = nothing                                    # where each part is in the window in this frame: see `palette_plan`
  focus::Vector{Any} = Any[]                             # what was in focus when the palette opened, from the nearest: see `in_focus`
  listed::Vector{Command} = Command[]                    # the commands that it lists: the ones that what's in focus takes
  had::Any = nothing                                     # what had the keyboard when the palette opened. It gets the keyboard back.
  inner::Vector{Any} = Any[]                             # what ⌥↑ made a chip bigger from, the last last, for ⌥↓ to go back to
  before::Any = nothing                                  # how the window looked before it showed a row of the list, for Esc to put back: see `preview!`
  pointed::Bool = false                                  # true once the mouse chose a row of the chip's list, for Return and Tab to take: see `palette_say!`
end
"What takes a click outside the palette"
@def mutable struct PaletteCatch <: SemanticUI end
"The outline round a list and what it hangs over, drawn as one shape"
@def mutable struct PaletteLens <: SemanticUI end
"What blurs the page under the strip that the bar is in, as frosted glass does. The blur fades out above the bar."
@def mutable struct PaletteFrost <: SemanticUI end
"The bar: its field, or the command's name with its chips and the Run button"
@def mutable struct PaletteBar <: SemanticUI end
"A row of a list: a command, or something that a chip can be"
@def mutable struct PaletteRow <: SemanticUI
  k::Int = 0
end
"A chip of the palette: one thing that the command takes"
@def mutable struct PaletteChip <: SemanticUI
  k::Int = 0
  over::Float64 = 0.0   # when the mouse came over it, or 0 while it isn't over it
end
"The button after the chips, which runs the command"
@def mutable struct PaletteRun <: SemanticUI end
"The … at the end of the chips that fit, which puts the chips on more lines"
@def mutable struct PaletteMore <: SemanticUI end

palette(e) = node!(CommandPalette, e, :palette)

"What's in focus in the window of `e` for a command. While the palette is open, its own field has the keyboard, so it's what was in focus when the palette opened."
command_focus(e) = begin
  p = get(e.nodes, :palette, nothing)
  e.popup == :commands && p isa CommandPalette && !isempty(p.focus) ? p.focus : in_focus(e)
end

# --- how a type is asked for ---

function choices_for end
function typed_as end

"""
`chip_start(::Type{T}, e)` gives the thing of type `T` that a chip starts with
when its command is taken: the one that the window means, like what the caret
is on. A chip of a type with no method of it starts with nothing.
"""
function chip_start end

"""
`chip_click(::Type{T}, e, w)` gives the thing of type `T` under the mouse of
the window `w`, or nothing. While the palette shows a chip of a type with a
method of it, a click on the window outside the palette chooses that thing
for the chip. See `palette_click!`.
"""
function chip_click end

"Where the thing `x` that a chip has shows in the window of `e`, for a line round it, or nothing"
shown_at(e, x) = x isa SemanticUI ? (try rect(x) catch; nothing end) : nothing

choices_for(::Type{Bool}, e) = [true, false]
choices_for(::Type{T}, e) where T<:Enum = collect(instances(T))
# A method that takes a type itself, like `f(::Type{Page})`, takes that one type. Several such methods make a chip that chooses between them.
choices_for(::Type{Type{T}}, e) where T = Any[T]

typed_as(::Type{<:AbstractString}, text) = isempty(text) ? nothing : String(text)
typed_as(::Type{T}, text) where T<:Integer = tryparse(isconcretetype(T) ? T : Int, text)
typed_as(::Type{T}, text) where T<:AbstractFloat = tryparse(isconcretetype(T) ? T : Float64, text)
# A number of any kind is a whole number where the text writes one
typed_as(::Union{Type{Real},Type{Number}}, text) = something(tryparse(Int, text), tryparse(Float64, text), Some(nothing))
typed_as(::Type{Date}, text) = begin
  word = lowercase(text)
  word == "today" ? Dates.today() : word == "tomorrow" ? Dates.today() + Day(1) : word == "yesterday" ? Dates.today() - Day(1) : tryparse(Date, text)
end

"""
`:choice` for a type whose things to choose from are few and fixed. The chip
of such a type shows two as a choice of two and three or four as a list, as a
select does in Centient. The things of any other type are in a list that's searched.
"""
chip_kind(::Type) = :search
chip_kind(::Type{T}) where T<:Enum = :choice
chip_kind(::Type{Type{T}}) where T = :choice

"The words that the palette shows for `x`, in a row and in a chip"
worded(x) = string(x)
worded(on::Bool) = on ? "On" : "Off"
worded(x::Enum) = uppercasefirst(replace(string(x), '_' => ' '))
worded(T::Type) = replace(string(nameof(T)), r"(?<=[a-z0-9])(?=[A-Z])" => " ")
# A file or a folder has its name. A part of the window has no words, unless its type has a method that gives it some.
worded(o::FSObject) = entry_name(o)
worded(::SemanticUI) = ""

"Fainter words at the right of the row of `x`, or none"
sidenote(x) = ""

"True when the palette can ask for a thing of type `T`"
askable(T) = T isa Union ? any(askable, Base.uniontypes(T)) :
             T isa Type && T !== Any && (hasmethod(choices_for, Tuple{Type{T},Any}) || hasmethod(typed_as, Tuple{Type{T},String}))

"The types among those of a chip that the palette can ask for. A union gives each of its own."
askable_types(types) = Any[U for T in types for U in (T isa Union ? Base.uniontypes(T) : (T,)) if askable(U)]

chooses(T) = hasmethod(choices_for, Tuple{Type{T},Any})
reads(T) = T !== Bool && hasmethod(typed_as, Tuple{Type{T},String})

"What the chip `c` can be, for the editor `e`"
chip_choices(e, c::Wanted) = begin
  out = Any[]
  for T in askable_types(c.types)
    chooses(T) || continue
    for x in Base.invokelatest(choices_for, T, e)
      any(o -> o === x || isequal(o, x), out) || push!(out, x)
    end
  end
  out
end

"What `text` writes for the chip `c`: the thing of the first of its types that can read it, or nothing"
chip_typed(c::Wanted, text::AbstractString) = begin
  for T in askable_types(c.types)
    hasmethod(typed_as, Tuple{Type{T},String}) || continue
    x = Base.invokelatest(typed_as, T, String(text))
    x === nothing || return x
  end
  nothing
end

"""
The kind of chip that `c` is: `:switch`, `:segment` for a choice of two,
`:pick` for a list of three or four, `:search` for a list that's searched,
`:number` or `:text`.
"""
chip_kind(e, c::Wanted) = begin
  types = askable_types(c.types)
  all(T -> T === Bool, types) && return :switch
  if any(chooses, types)
    # Things that are few and fixed, with nothing typed among them, show by how many they are
    (all(T -> chooses(T) && chip_kind(T) == :choice, types) && !any(reads, types)) || return :search
    n = length(chip_choices(e, c))
    return n <= 2 ? :segment : n <= 4 ? :pick : :search
  end
  all(T -> T isa Type && T <: Number, types) ? :number : :text
end

"What a chip says while it has nothing: the argument's name as words, like Due date"
chip_name(c::Wanted) = uppercasefirst(join((lowercase(replace(String(n), '_' => ' ')) for n in c.names), " or "))

"The name of the type `T` as a tooltip writes it"
type_words(T) = T isa Union ? join(map(type_words, Base.uniontypes(T)), " | ") :
                T isa DataType && T.name.name === :Type ? "Type{$(type_words(T.parameters[1]))}" :
                T isa DataType ? String(nameof(T)) : string(T)

"What a chip's tooltip says: the argument's name and its type, as in Centient"
chip_tip(c::Wanted) = string(join(c.names, " or "), " (", join(map(type_words, c.types), " | "), ")")

# --- what's in focus ---
#
# The palette lists the commands that have a use where the keyboard is. What's
# in focus says which: the part of the page that the caret is on, the page,
# its file, and the folder. A command that's a function shows when a method of
# it takes one of those things, by the type of an argument:
#
#     "Give the file or the folder another name"
#     rename!(e, o::FSObject) = ...
#     add_command!(rename!)
#
# Rename shows while a file or a folder is in focus, and its function gets the
# nearest one. A method for a kind of folder, like `f(d::GitDirectory)`, makes
# a command that shows only in such a folder. A command that takes only the
# editor shows everywhere.

"""
The path of the one file or folder that's chosen in `node`, a part of the
window that has the keyboard, or nothing: the row of the sidebar that the
arrows are on, or the one icon or line that's chosen on the page of a folder.
A part that holds files in another way has a method of this.
"""
chosen_path(node) = begin
  T = typeof(node)
  (hasfield(T, :chosen) && hasfield(T, :path) && node.chosen isa AbstractSet && length(node.chosen) == 1) || return nothing
  path = joinpath(node.path, only(node.chosen))
  ispath(path) ? path : nothing
end
chosen_path(t::Tree.ListTree) = (row = t.focused; row !== nothing && row.firstchild isa FileLabel ? row.firstchild.path : nothing)

"""
The things in focus in the window of `e`, from the nearest: what has the
keyboard and each part that it's in, the file or the folder that's chosen
there, the part of the page that the caret is on, the block of Julia code
that it's in, the text of the page, the file that shows, the folder that
holds it, and the sidebar's folder. A file is a `File`, and a folder is of
its kind, a type under `AbstractDirectory`. The editor and the window aren't
in the list: every command can have them.
"""
in_focus(e) = begin
  out = Any[]
  add(x) = (x === nothing || x === e || any(o -> o === x, out) || push!(out, x); nothing)
  thing(path) = try object(e, path) catch; nothing end   # macOS doesn't let Ladder read some folders
  # A part that holds files has the one that's chosen in it nearer than itself
  hold(node) = (path = chosen_path(node); path === nothing || add(thing(path)); add(node))
  w = window_of(e)
  b = e.buf
  field = window_parts(e).input
  node = w === nothing ? nothing : w.focus
  while node isa SemanticUI && node !== e
    node === field || node isa CommandPalette || hold(node)
    node = node.parent
  end
  full = full_block(e)
  full === nothing || hold(full)
  if full === nothing
    line = b.caret[1]
    # A file that shows in a viewer has the viewer as its one part
    if !caretless(b) || b.view == :file
      k = findfirst(it -> it.first <= line <= it.last && it.content isa Live && it.content.node isa SemanticUI, e.layout)
      k === nothing || hold(e.layout[k].content.node)
    end
    (julia_file(b) || !caretless(b)) && add(julia_part(e, line))
  end
  # The page of a folder, or of a file of a kind that has a page of its own
  shown = page_object(e)
  if shown !== nothing
    view = with_theme(() -> page_view(e, shown), component_theme(e.zoom))
    view isa SemanticUI && hold(view)
  end
  b.view == :file || add(node!(Document, e, :document))
  # A page that isn't saved yet has a file all the same: the one that it will be written to
  o = isempty(b.path) ? nothing : thing(b.path)
  o === nothing && !isempty(b.path) && (o = try FS.File(b.path) catch; nothing end)
  o isa FSObject && (add(o); add(o.parent))
  add(directory(e))
  out
end

"""
True when the command called `name` has something to work on in the window of
`e`, where the type of what's in focus can't say so. A command has a method
of this when it has a use only on some pages, as Bold has on a page of
Markdown. The palette leaves out a command that has none.
"""
works_here(e, ::Val) = true
works_here(e, ::Union{Val{:bold},Val{:italic},Val{:print},Val{:export},Val{:slides},Val{:insert}}) = e.buf.view == :markdown
works_here(e, ::Val{:save}) = writes(e.buf)
works_here(e, ::Val{:back}) = !isempty(e.back) || step_words(e) !== nothing
works_here(e, ::Val{:forward}) = !isempty(e.ahead) || step_words(e, e.ahead) !== nothing
works_here(e, ::Union{Val{:find_next},Val{:find_last}}) = !isempty(found(e))
# A comment is made of a line of code: a file of code, or a line in a code block of a page
works_here(e, ::Val{:comment}) = begin
  b = e.buf
  ks = kinds(b)
  s, t = touched(b)
  any(i -> ks[i].kind == Kind.code && haskey(COMMENT_MARKS, lowercase(ks[i].lang)), s:min(t, length(ks)))
end

# --- the methods of a command's function ---

"""
What gives a method its argument called `name`, of the type `T`, when the
things in `focus` are in focus. `:editor` and `:window` are the window's own:
an `Editor` or a `Window`, or an argument called `e` or `w` with no type. The
nearest thing in focus that's a `T` is the argument of any other type that
the palette can't ask for. Nothing is for an argument that the palette asks
for, and for one that nothing gives. An argument with no type is never a
thing in focus, since everything would do for it.
"""
given(name::Symbol, T, focus) = begin
  (T === Editor || (T === Any && name === :e)) && return :editor
  (T === Window || (T === Any && name === :w)) && return :window
  (T === Any || !(T isa Type) || askable(T)) && return nothing
  k = findfirst(x -> x isa T, focus)
  k === nothing ? nothing : focus[k]
end

"The arguments of the method `sig` that the palette asks for by their place, in their order"
asks(sig::Vector{Argument}) = filter(a -> !a.keyword && a.from === nothing, sig)

"The things in focus that the method `sig` takes, in the order of its arguments"
focus_taken(sig::Vector{Argument}) = Any[a.from for a in sig if !(a.from === nothing || a.from === :editor || a.from === :window)]

"The keyword arguments of the method `m` that have a name, each with its type"
method_keywords(m::Method) = begin
  names = try Base.kwarg_decl(m) catch; Symbol[] end
  body = isempty(names) ? nothing : (try Base.bodyfunction(m) catch; nothing end)
  body === nothing && return Argument[]
  for inner in methods(body)
    # Julia's own method for the body takes the keyword arguments first, in the order of their names
    types = Base.unwrap_unionall(inner.sig).parameters
    length(types) >= 1 + length(names) || continue
    return Argument[Argument(n, (T = types[1+i]; T isa TypeVar ? T.ub : T), true) for (i, n) in enumerate(names) if !endswith(String(n), "...")]
  end
  Argument[]
end

"""
The methods of `f` that the palette can call when the things in `focus` are
in focus, each as its arguments, in the order that they're written in. A
method's argument is the window's own, a thing in focus, or something that
the palette asks for: see `given`. It leaves out a method that takes
something else, or any number of things. So a function is a command only
where a method of it takes what's in focus. A keyword argument that the
palette can't ask for is left out by itself, and keeps the value that the
method gives it.
"""
callable_methods(f, focus=Any[]) = begin
  out = Vector{Argument}[]
  for m in sort!(collect(methods(f)), by=m -> (string(m.file), m.line))
    types = Base.unwrap_unionall(m.sig).parameters[2:end]
    any(Base.isvarargtype, types) && continue
    names = Base.method_argnames(m)[2:end]
    sig = Argument[]
    for (k, T) in enumerate(types)
      T = T isa TypeVar ? T.ub : Base.rewrap_unionall(T, m.sig)
      name = k <= length(names) ? names[k] : Symbol("")
      # An argument with no name, like the one of `f(::Type{Page})`, is called by what it chooses
      (name === Symbol("") || startswith(String(name), '#')) && (name = :kind)
      push!(sig, Argument(name, T, false, given(name, T, focus)))
    end
    all(a -> a.from !== nothing || askable(a.type), sig) || continue
    append!(sig, filter(a -> askable(a.type), method_keywords(m)))
    sig in out || push!(out, sig)
  end
  out
end

fits(x, c::Wanted) = any(T -> x isa T, c.types)

"""
The chips of a command whose function has the methods `sigs`, when `values`
are what's said so far. Each chip is for one place in the arguments. The
methods that take what's said stay in the running, and the chips are theirs.
Where they part and nothing is said yet, there are two cases, as in Centient.
Methods that take a type itself there, like `f(::Type{Page})`, have nothing in
common after it, so the chips stop. Methods that take values of different
types show the chips of the method that's written first. The chips of the
keyword arguments of the methods that are left come last.
"""
palette_chips(sigs::Vector{Vector{Argument}}, values) = begin
  alive = [(asks(s), s) for s in sigs]
  chips = Wanted[]
  k = 1
  waits = false
  while true
    here = filter(s -> length(s[1]) >= k, alive)
    isempty(here) && break
    chip = Wanted(unique(Symbol[s[1][k].name for s in here]), unique(Any[s[1][k].type for s in here]), length(here) < length(alive))
    push!(chips, chip)
    x = k <= length(values) ? values[k] : UNSAID
    if x !== UNSAID && fits(x, chip)
      alive = filter(s -> x isa s[1][k].type, here)
    elseif length(chip.types) > 1
      all(T -> T isa Type && T <: Type, chip.types) && (waits = true; break)
      first_type = here[1][1][k].type
      alive = filter(s -> s[1][k].type == first_type, here)
    else
      alive = here
    end
    k += 1
  end
  waits && return chips
  seen = Symbol[]
  for (_, sig) in alive, a in sig
    (a.keyword && !(a.name in seen)) || continue
    push!(seen, a.name)
    push!(chips, Wanted([a.name], Any[a.type], true, true))
  end
  chips
end

"The chips that show: all of them after ⌥, and without the keyword arguments before"
palette_chips(p::CommandPalette) = begin
  chips = palette_chips(p.methods, p.values)
  p.advanced ? chips : filter(c -> !c.keyword, chips)
end

"What's said for chip `k` of `chips`, or `UNSAID`"
chip_value(p::CommandPalette, chips, k::Int) = begin
  k <= length(chips) || return UNSAID
  c = chips[k]
  c.keyword ? get(p.keywords, only(c.names), UNSAID) : k <= length(p.values) ? p.values[k] : UNSAID
end

"Make `p.values` as long as the chips are, and take away what no longer fits its chip"
settle!(p::CommandPalette) = begin
  for _ in 1:2
    chips = palette_chips(p.methods, p.values)
    n = count(c -> !c.keyword, chips)
    length(p.values) > n && resize!(p.values, n)
    while length(p.values) < n
      push!(p.values, UNSAID)
    end
    for k in 1:n
      p.values[k] === UNSAID || fits(p.values[k], chips[k]) || (p.values[k] = UNSAID)
    end
    named = Dict{Symbol,Wanted}(only(c.names) => c for c in chips if c.keyword)
    filter!(kv -> haskey(named, kv.first) && fits(kv.second, named[kv.first]), p.keywords)
  end
  p
end

"Say `x` for chip `k` of `chips`. `UNSAID` takes away what it had."
say!(p::CommandPalette, chips, k::Int, x) = begin
  c = chips[k]
  if c.keyword
    x === UNSAID ? delete!(p.keywords, only(c.names)) : (p.keywords[only(c.names)] = x)
  else
    p.values[k] = x
  end
  settle!(p)
end

"""
The method that takes what's said: the one whose arguments are the chips from
the first up to the last one that has something. It's nothing while a chip
before that one has nothing, or when no method stops there.
"""
ready_method(sigs::Vector{Vector{Argument}}, values) = begin
  n = something(findfirst(x -> x === UNSAID, values), length(values) + 1) - 1
  all(x -> x === UNSAID, values[n+1:end]) || return nothing
  for sig in sigs
    a = asks(sig)
    length(a) == n && all(k -> values[k] isa a[k].type, 1:n) && return sig
  end
  nothing
end

# --- the lists ---

"A command's name as the palette shows it: `:select_all` reads Select All"
palette_name(name::Symbol) = join(uppercasefirst.(split(String(name), '_', keepempty=false)), ' ')

"""
How well `text` fits the letters `q`, both in small letters. 0 is not at all.
Text that has the letters together fits best, and better the nearer its start
they are. Text that has them in order with others between them fits a little.
"""
palette_fit(text::AbstractString, q::AbstractString) = begin
  at = findfirst(q, text)
  if at !== nothing
    before = length(text, 1, first(at)) - 1
    return max(1, 100 - before) + (before == 0 ? 50 : 0)
  end
  want = collect(q)
  score, k = 0, 1
  for (n, c) in enumerate(text)
    k > length(want) && break
    c == want[k] && (score += n == k ? 2 : 1; k += 1)
  end
  k > length(want) ? score : 0
end

"""
How well the command `c` fits the letters `q`: the best of its name, as it's
written and as it shows, and what it does. A name that fits comes before
words that fit as well, so that "go to" finds Go To before a command whose
words start with "Go to".
"""
command_fit(c::Command, q::AbstractString) = begin
  name = max(palette_fit(lowercase(String(c.name)), q), palette_fit(lowercase(palette_name(c.name)), q))
  max(name == 0 ? 0 : name + 10, palette_fit(lowercase(c.title), q))
end

"""
True when the palette lists the command `c` while the things in `focus` are
in focus. It leaves out the commands that only a key makes sense for, like
the ones that move the caret, the ones that the page can't take, as a key
leaves them out, the ones with nothing to work on here, and a function that
has no method for what's in focus.
"""
in_palette(e, c::Command, focus=in_focus(e)) = begin
  (c.name == :commands || c.kind in (:move, :type)) && return false
  b = e.buf
  (!readonly(b) || c.kind in (:window, :page) || (c.kind == :look && b.view != :file)) || return false
  works_here(e, Val(c.name)) || return false
  c.call === nothing || !isempty(callable_methods(c.call, focus))
end

"The commands that the palette lists while the things in `focus` are in focus, in the order of their names. The page's own functions are among them: see `page_commands`."
palette_commands(e, focus=in_focus(e)) =
  sort!(Command[[c for (_, cs) in COMMAND_GROUPS for c in cs if in_palette(e, c, focus)]; [c for c in page_commands(e) if in_palette(e, c, focus)]],
        by=c -> String(c.name))

"""
The web address or the path of the Mac that's typed in the palette's list of
commands, when the list has Navigate to go there, or nothing. Navigate is then
the list's first row, and Return goes there at once. A path here starts with
/, ~ or file://, so that the name of a command is never one.
"""
palette_address(e, p::CommandPalette) = begin
  p.command === nothing || return nothing
  to = navigate_place(e, input(e).text, near=false)
  to !== nothing && any(c -> c.name == :navigate, p.listed) ? to : nothing
end

"""
The name of the thing in focus that the command `c` works on, to show in its
row, or "" for a command that works on the window or the page as a whole. It
says which file Move To Trash takes before Return is pressed.
"""
palette_target(c::Command, focus) = begin
  c.call === nothing && return ""
  for sig in callable_methods(c.call, focus), x in focus_taken(sig)
    words = worded(x)
    isempty(words) || return words
  end
  ""
end

"The things in `found` whose words fit the letters `q`, with the best fit first. `fit` gives how well one fits."
best_fits(fit, found, q) = begin
  isempty(q) && return found
  scored = [(fit(x), x) for x in found]
  last.(sort!(filter!(s -> first(s) > 0, scored), by=s -> -first(s)))
end

"""
The rows of the palette's list: the commands, or what the chip that the
keyboard is in can be. Each has its name, the fainter words with it, its keys
or nothing, and what Return takes. A list of a few fixed things has them all.
A list that's searched has the ones whose words have the letters typed, in
their own order, and then what the letters write, when they write something.
"""
palette_rows(e, p::CommandPalette) = begin
  if p.command === nothing
    q = lowercase(String(strip(input(e).text)))
    of = keys_now(e).of
    rows = Any[(name=palette_name(c.name), note=c.title, on=palette_target(c, p.focus),
                keys=(list = get(of, c.name, Shortcut[]); isempty(list) ? nothing : first(list)), value=c)
               for c in best_fits(c -> command_fit(c, q), p.listed, q)]
    # A web address or a path that's typed here has Navigate first, with where Return goes: see "a page from a web server"
    to = palette_address(e, p)
    if to !== nothing
      filter!(r -> r.value.name != :navigate, rows)
      c = p.listed[findfirst(c -> c.name == :navigate, p.listed)]
      pushfirst!(rows, (name=palette_name(c.name), note="Go to " * place_label(to), on="", keys=nothing, value=c))
    end
    return rows
  end
  chips = palette_chips(p)
  p.at <= length(chips) || return Any[]
  chip = chips[p.at]
  kind = chip_kind(e, chip)
  kind in (:pick, :search) || return Any[]
  found = collect(Any, chip_choices(e, chip))
  if kind == :search
    q = lowercase(p.query)
    isempty(q) || filter!(x -> occursin(q, lowercase(worded(x))), found)
    typed = chip_typed(chip, p.query)
    typed === nothing || any(x -> isequal(x, typed), found) || push!(found, typed)
  end
  Any[(name=worded(x), note=sidenote(x), on="", keys=nothing, value=x) for x in found]
end

"The rest of the first row's name, when its name starts with what's typed. It shows after the text. In the list of commands, Tab types it."
palette_ghost(e, p::CommandPalette) = begin
  text = input(e).text
  isempty(text) && return ""
  rows = palette_rows(e, p)
  isempty(rows) && return ""
  if p.command !== nothing
    # In a chip, it's the rest of the row that's chosen, and not after an arrow put that row's words in the field
    p.browsed && return ""
    chips = palette_chips(p)
    (p.at <= length(chips) && chip_kind(e, chips[p.at]) == :search) || return ""
  end
  name = rows[p.command === nothing ? 1 : clamp(p.pick, 1, length(rows))].name
  startswith(lowercase(name), lowercase(text)) && length(name) > length(text) ? rest(name, length(text)) : ""
end

"The parts of `name` before, in and after the first place that has the letters `q`, whatever their case"
match_parts(name::AbstractString, q::AbstractString) = begin
  low = lowercase(name)
  at = isempty(q) || length(low) != length(name) ? nothing : findfirst(q, low)
  at === nothing && return (String(name), "", "")
  n = length(low, 1, first(at)) - 1
  (head(name, n), head(rest(name, n), length(q)), rest(name, n + length(q)))
end

# --- opening, closing and the keys ---

"How far up the bar is, from 0 to 1. It slides for `OMNI_RISE` seconds, fast at first."
palette_risen(e, p::CommandPalette) = begin
  to = e.popup == :commands ? 1.0 : 0.0
  t = (time() - p.moved) / OMNI_RISE
  t < 1 ? p.from + (to - p.from) * (1 - (1 - t)^2) : to
end

"True while the palette is in the window: while it's open, and while it slides down after it closes"
palette_shows(e) = e.popup == :commands || (e.popup == :none && haskey(e.nodes, :palette) && palette_risen(e, e.nodes[:palette]) > 0)

"True while the bar slides, so that each frame is drawn as soon as it can be"
palette_moving(e) = haskey(e.nodes, :palette) && time() - e.nodes[:palette].moved < OMNI_RISE

"Put `text` in the palette's field, with the caret after it. With `select`, all of it is selected, so that typing takes its place."
palette_text!(e, p::CommandPalette, text::AbstractString; select=false) = begin
  i = input(e)
  i.text = String(text)
  i.cursor = length(i.text)
  i.anchor = select ? 0 : i.cursor
  p.typed = i.text
  p
end

"Give the keyboard to the field when the palette has something to type in, and to the palette itself for a switch, a choice, a list of a few or the Run button"
palette_focus!(e, p::CommandPalette) = begin
  typing = p.command === nothing
  if !typing
    chips = palette_chips(p)
    typing = p.at <= length(chips) && chip_kind(e, chips[p.at]) in (:text, :number, :search)
  end
  focus(typing ? input(e) : p)
  nothing
end

"Empty the bar: no command, no chips and no text, with the list of commands at its first row. A row that the window showed goes."
palette_clear!(e, p::CommandPalette) = begin
  unpreview!(e, p)
  p.command, p.at, p.pick, p.shown = nothing, 1, 1, 0
  p.advanced = p.wrap = p.browsed = false
  p.query = p.fault = ""
  empty!(p.methods); empty!(p.values); empty!(p.keywords); empty!(p.rows); empty!(p.inner)
  p.scroll.offset = 0px
  palette_text!(e, p, "")
  palette_focus!(e, p)
end

"""
Show the command palette with the list of the commands. With `command`, it
shows that command with its chips, as it does after the command is taken
from the list: the keys of a command that asks for something do that.
"""
open_palette!(e, command::Union{Nothing,Command}=nothing) = begin
  p = palette(e)
  if e.popup != :commands
    from = palette_risen(e, p)
    # What's in focus is read before the palette takes the keyboard, and stays as it is while the palette is open
    w = window_of(e)
    p.had = w === nothing ? nothing : w.focus
    p.focus = in_focus(e)
    p.listed = palette_commands(e, p.focus)
    # The bar starts to slide when the list is ready, so that none of the slide is lost to making it
    p.from, p.moved = from, time()
    e.popup = :commands
  end
  palette_clear!(e, p)
  command === nothing || take_command!(e, window_of(e), p, command)
  nothing
end

# The page under it stays as it was: the caret doesn't show again, and the page doesn't scroll to it
close_palette!(e) = begin
  p = palette(e)
  unpreview!(e, p)
  e.popup == :commands && ((p.from, p.moved) = (palette_risen(e, p), time()); e.popup = :none)
  w = window_of(e)
  w === nothing || hide_tooltip!(w)
  # The part of the page that had the keyboard gets it back, if it still shows, so that it's still the one in focus
  had = p.had
  p.had = nothing
  focus(had isa SemanticUI && had !== window_parts(e).input && part_of(had, e) && rect(had) !== nothing ? had : e)
  nothing
end

"Show the command palette, or close it when it shows"
toggle_palette!(e) = e.popup == :commands ? close_palette!(e) : open_palette!(e)

"Take the command `c` from the list: run it, or show its chips when it asks for something"
take_command!(e, w, p::CommandPalette, c::Command) = begin
  if c.call === nothing
    close_palette!(e)
    return run!(e, w, c.name)
  end
  sigs = callable_methods(c.call, p.focus)
  isempty(sigs) && return (p.fault = "$(palette_name(c.name)) has nothing to work on here"; nothing)
  palette_clear!(e, p)
  p.command, p.methods = c, sigs
  settle!(p)
  # A function that takes nothing but the editor runs at once
  isempty(p.values) && return palette_run!(e, w, p)
  start_chips!(e, p)
  # A command that runs at once still waits here: what the window gave its chips is shown first, and Return or a click runs it
  # The keyboard goes to the first chip that has nothing yet. When each has something, it goes to the first chip
  # for a thing in the window, so the mouse picks out what a click would choose instead, or else to the Run button.
  chips = palette_chips(p)
  go_chip!(e, p, something(findfirst(x -> x === UNSAID, p.values), findfirst(chip_points, chips), length(chips) + 1))
end

"Give each chip that has nothing the thing that its type starts with: see `chip_start`"
start_chips!(e, p::CommandPalette) = begin
  k = 1
  while k <= length(p.values)
    if p.values[k] === UNSAID
      chips = palette_chips(p.methods, p.values)
      for T in askable_types(chips[k].types)
        hasmethod(chip_start, Tuple{Type{T},Any}) || continue
        x = Base.invokelatest(chip_start, T, e)
        x === nothing || (say!(p, chips, k, x); break)
      end
    end
    k += 1
  end
  p
end

"True when the chip `c` is for a thing that shows in the window, which a click there chooses: its type has a method of `chip_click`"
chip_points(c::Wanted) = !c.keyword && any(T -> hasmethod(chip_click, Tuple{Type{T},Any,Any}), askable_types(c.types))

Base.:(==)(a::Things, b::Things) = a.all == b.all
Base.hash(t::Things, h::UInt) = hash(t.all, hash(:Things, h))
worded(t::Things) = join(map(worded, t.all), ", ")

"""
The letter and the colour of each thing that the palette's chips for things
in the window have, in the order of the chips: A in blue for the first, B in
orange for the next. A chip shows them in place of the things' words, and
the line round each thing in the window has them too. Each is the chip's
number, the thing, its letter and its colour.
"""
chip_letters(p::CommandPalette, chips) = begin
  out = NamedTuple[]
  for k in eachindex(chips)
    chip_points(chips[k]) || continue
    x = chip_value(p, chips, k)
    x === UNSAID && continue
    for y in each_thing(x)
      n = length(out) + 1
      push!(out, (k=k, thing=y, letter=string('A' + n - 1), colour=CHIP_MARKS[mod1(n, length(CHIP_MARKS))]))
    end
  end
  out
end

"The colour that the next thing that a chip for things in the window takes would have"
next_mark(p::CommandPalette, chips) = CHIP_MARKS[mod1(length(chip_letters(p, chips)) + 1, length(CHIP_MARKS))]

"The colour `c` made paler, for the line round what a click would choose"
paler(c) = RGBA(0.6c.r + 0.4, 0.6c.g + 0.4, 0.6c.b + 0.4, 1.0)

"""
The chip that a click on the window chooses a thing for: the one that the
keyboard is in, when it's for a thing in the window. It's nothing while the
keyboard is in another chip, like the words of Ask Agent, so the mouse then
picks nothing out on the page and a click there chooses nothing.
"""
click_chip(e, p::CommandPalette) = begin
  (e.popup == :commands && p.command !== nothing) || return nothing
  chips = palette_chips(p)
  p.at <= length(chips) && chip_points(chips[p.at]) ? p.at : nothing
end

"""
The chip for a thing in the window that ⌥↑ and ⌥↓ make bigger or smaller: the
one that the keyboard is in, or else the first. It's nothing while the
palette shows no such chip.
"""
thing_chip(e, p::CommandPalette) = begin
  k = click_chip(e, p)
  k === nothing || return k
  (e.popup == :commands && p.command !== nothing) || return nothing
  chips = palette_chips(p)
  findfirst(k -> chip_points(chips[k]), eachindex(chips))
end

"True when the chip `c` can have several things, which ⇧ and a click add: its function takes `Things` there"
adds_things(c::Wanted) = any(T -> T isa Type && Things <: T, c.types)

"True when the point `(x, y)` of the window is on the palette: the strip along the bottom, or the list over it"
on_palette(p::CommandPalette, x, y) = begin
  plan = p.plan
  plan === nothing && return false
  within(r) = r.x <= x <= r.x + r.w && r.y <= y <= r.y + r.h
  within(plan.band) || (plan.list !== nothing && within(plan.list.frame))
end

"The part of the window that a concrete box `ui` of its layout is drawn for: the nearest that made it"
drawn_for(ui) = begin
  from = ui.from
  while from !== nothing
    from isa SemanticUI && return from
    from = hasproperty(from, :from) ? from.from : nothing
  end
  nothing
end

"""
The deepest part of the window `w` under its mouse, leaving out what the
palette `p` draws. The palette's layers cover the window while it shows, so
this is what a click outside the palette is on.
"""
under_palette(w, p::CommandPalette) = (s = scene(w); s === nothing ? nothing : hit_past(s, (w.mouse[1], w.mouse[2]), p))
hit_past(ui, (x, y), p) = begin
  ui isa ConcreteRect || return nothing
  (ui.left <= x <= ui.left + ui.width && ui.top <= y <= ui.top + ui.height) || return nothing
  made = drawn_for(ui)
  made === p && return nothing
  # Later children draw on top, so they're found first
  for child in Iterators.reverse(ui.children)
    found = hit_past(child, (x, y), p)
    found === nothing || return found
  end
  made
end

"""
`chip_wider(x, e)` gives the thing of the same type as `x` that holds it in the
window of `e`, like the block that a paragraph is in, or nothing. ⌥↑ in the
palette makes a chip for a thing in the window take it: see `resize_thing!`.
"""
chip_wider(x, e) = nothing

"""
What ⌥↑ and ⌥↓ do while the palette shows a chip for a thing in the window:
↑ (`by` 1) gives the chip the part that holds its thing, and ↓ (`by` -1)
goes back to the thing that it was before.
"""
resize_thing!(e, p::CommandPalette, by::Int) = begin
  k = thing_chip(e, p)
  k === nothing && return nothing
  chips = palette_chips(p)
  x = chip_value(p, chips, k)
  x === UNSAID && return nothing
  if by > 0
    bigger = Base.invokelatest(chip_wider, x, e)
    bigger === nothing && return nothing
    push!(p.inner, x)
    say!(p, chips, k, bigger)
  else
    isempty(p.inner) && return nothing
    say!(p, chips, k, pop!(p.inner))
  end
  redraw_in!(e, 0)
  nothing
end

"What a click at the mouse of the window `w` would choose for chip `k` of the palette, or nothing"
clicked_thing(e, p::CommandPalette, w, k::Int) = begin
  for T in askable_types(palette_chips(p)[k].types)
    hasmethod(chip_click, Tuple{Type{T},Any,Any}) || continue
    x = Base.invokelatest(chip_click, T, e, w)
    x === nothing || return x
  end
  nothing
end

"""
A click on the window while the palette shows a chip that a click chooses
for: the chip gets the thing under the mouse, and the keyboard goes on from
it. True when the palette took the click. It takes a click on nothing that
the chip takes too, so the page under the palette doesn't change.
"""
palette_click!(e, w) = begin
  p = get(e.nodes, :palette, nothing)
  p isa CommandPalette || return false
  k = click_chip(e, p)
  (k === nothing || on_palette(p, num(w.mouse[1]), num(w.mouse[2]))) && return false
  x = clicked_thing(e, p, w, k)
  x === nothing && return true
  empty!(p.inner)
  chips = palette_chips(p)
  had = chip_value(p, chips, k)
  if only_held(w, Keys.shft) && adds_things(chips[k]) && had !== UNSAID
    # ⇧ and a click add the thing to what the chip has, or take it out when it has it. The keyboard stays where it is.
    now = each_thing(had)
    j = findfirst(y -> y == x, now)
    now = j === nothing ? Any[now; x] : deleteat!(copy(now), j)
    say!(p, chips, k, isempty(now) ? UNSAID : length(now) == 1 ? only(now) : Things(now))
    palette_focus!(e, p)
    redraw_in!(e, 0)
    return true
  end
  say!(p, chips, k, x)
  k == p.at ? palette_next!(e, p) : (run_when_ready!(e, p) || palette_focus!(e, p))
  redraw_in!(e, 0)
  true
end

"""
Draw a line round the thing of each chip that's for a thing in the window, in
the chip's colour, with the chip's letter, for as long as the command shows.
While the keyboard is in such a chip, a paler line goes round what a click
would choose, with its words. The window's tool draws them, over the rest of
the window.
"""
mark_chips(ctx, w, e) = begin
  p = get(e.nodes, :palette, nothing)
  (p isa CommandPalette && e.popup == :commands && p.command !== nothing) || return nothing
  chips = palette_chips(p)
  letters = chip_letters(p, chips)
  for l in letters
    r = shown_at(e, l.thing)
    r === nothing || pick_mark(ctx, w, r, l.letter; colour=l.colour)
  end
  k = click_chip(e, p)
  k === nothing && return nothing
  redraw_in!(e, 1/30)   # the line follows the mouse
  on_palette(p, num(w.mouse[1]), num(w.mouse[2])) && return nothing
  x = clicked_thing(e, p, w, k)
  (x === nothing || any(l -> l.thing == x, letters)) && return nothing
  r = shown_at(e, x)
  r === nothing && return nothing
  # With ⇧ held, a click adds the thing, in the colour that it would have
  adds = only_held(w, Keys.shft) && adds_things(chips[k]) && chip_value(p, chips, k) !== UNSAID
  colour = adds ? next_mark(p, chips) : (k2 = findfirst(l -> l.k == k, letters); k2 === nothing ? CHIP_MARKS[1] : letters[k2].colour)
  pick_mark(ctx, w, r, (adds ? "Click to add: " : "Click to choose: ") * worded(x); colour=paler(colour))
  nothing
end

"""
Put the keyboard in chip `k`. One more than the last chip is the Run button.
A chip that's typed in has what's said for it in the field, selected. A list
that's searched starts with an empty field, and its row is the one that's said.
"""
go_chip!(e, p::CommandPalette, k::Int) = begin
  chips = palette_chips(p)
  p.at = clamp(k, 1, length(chips) + 1)
  p.query, p.browsed, p.pointed, p.fault, p.shown = "", false, false, "", 0
  p.scroll.offset = 0px
  x = chip_value(p, chips, p.at)
  typed = p.at <= length(chips) && chip_kind(e, chips[p.at]) in (:text, :number)
  palette_text!(e, p, typed && x !== UNSAID ? worded(x) : "", select=true)
  # A chip on a line that doesn't show puts the chips on as many lines as they need
  p.wrap || palette_fits(e, p, p.at) || (p.wrap = true)
  p.pick = something(findfirst(r -> isequal(r.value, x), palette_rows(e, p)), 1)
  palette_focus!(e, p)
end

"""
True for a command that changes nothing that you'd want to look at before it
runs, like Go To or Theme. The palette runs it as soon as each of its chips
has something, with no press of Run. A command that changes a file, or that
starts something that takes a while, like Rename or Ask Agent, waits for
Run. A command that takes nothing runs at once anyway.
"""
runs_at_once(::Val) = false
runs_at_once(::Union{Val{:go_to},Val{:theme},Val{:text_size},Val{:key_bindings},Val{:spelling},Val{:autosave},Val{:peeks},Val{:insert},Val{:rename_in_code},Val{:show_code},Val{:find_uses}}) = true

"""
Run the palette's command when it runs at once and each of its chips has
something that was said for it. A switch that wasn't touched counts as
nothing here, so taking Spelling doesn't turn it off. True when it ran.
"""
run_when_ready!(e, p::CommandPalette) = begin
  (p.command !== nothing && runs_at_once(Val(p.command.name)) && !isempty(p.values)) || return false
  any(x -> x === UNSAID, p.values) && return false
  ready_method(p.methods, palette_said(e, p)) === nothing && return false
  palette_run!(e, window_of(e), p)
  true
end

"The number that ↑ and ↓ count from in chip `k` of the command `name` while the chip has nothing: 0, or for Text Size the size that the text is now"
counts_from(e, ::Val, k) = 0
counts_from(e, ::Val{:text_size}, k) = text_size(e)

"Go on from the chip that the keyboard is in to the next one, or to the Run button after the last. A command that runs at once runs when its last chip has something."
palette_next!(e, p::CommandPalette) = run_when_ready!(e, p) || go_chip!(e, p, p.at + 1)

# --- a look before you choose ---
#
# As the arrows go through the list of Theme, the window shows each colours,
# and Text Size shows each size. Go To and Find Uses show each place in the window. Esc,
# or a click outside the palette, puts the window back as it was. Return keeps
# the one that's chosen.

"""
`look_of(e, Val(name))` gives how the window of `e` looks now in the ways
that the command `name` changes it, for a command that shows each row of its
list in the window as the arrows reach it. `put_look!` puts that look back.
It's nothing for a command that doesn't show its rows so.
"""
look_of(e, ::Val) = nothing
look_of(e, ::Val{:theme}) = e.theme
look_of(e, ::Val{:text_size}) = e.zoom
put_look!(e, ::Val{:theme}, was) = theme!(e, was)
put_look!(e, ::Val{:text_size}, was) = (e.zoom = was; rewrap!(e))

"Show in the window what the command `name` does with `args`, for a row that the arrows reached: see `look_of`. Most commands just run."
look!(e, ::Val, f, args...) = Base.invokelatest(f, args...)

"What the command's function takes: what's said for each chip, and the editor or the window where it takes them"
palette_args(e, w, sig, said) = (said = copy(said); Any[a.from === nothing ? popfirst!(said) : a.from === :editor ? e : a.from === :window ? w : a.from for a in sig if !a.keyword])

"""
Show in the window the row of the list that the arrows reached, for a command
that does that, like Theme: see `look_of`. The palette keeps how the window
looked before the first, for Esc to put back.
"""
preview!(e, p::CommandPalette) = begin
  p.command === nothing && return nothing
  name = Val(p.command.name)
  was = look_of(e, name)
  was === nothing && return nothing
  said = palette_said(e, p)
  any(x -> x === UNSAID, said) && return nothing
  sig = ready_method(p.methods, said)
  sig === nothing && return nothing
  p.before === nothing && (p.before = was)
  try
    look!(e, name, p.command.call, palette_args(e, window_of(e), sig, said)...)
  catch err
    err isa InterruptException && rethrow()
  end
  nothing
end

"Put the window back as it looked before the palette showed a row of its list in it: see `preview!`"
unpreview!(e, p::CommandPalette) = begin
  was, p.before = p.before, nothing
  (was === nothing || p.command === nothing) || put_look!(e, Val(p.command.name), was)
  nothing
end

"While the window shows a row of the list, a line round the thing of that row, as for a place that Find Uses found"
mark_preview(ctx, w, e) = begin
  p = get(e.nodes, :palette, nothing)
  (p isa CommandPalette && p.before !== nothing && e.popup == :commands && p.command !== nothing) || return nothing
  chips = palette_chips(p)
  p.at <= length(chips) || return nothing
  x = chip_value(p, chips, p.at)
  x === UNSAID && return nothing
  r = shown_at(e, x)
  r === nothing || pick_mark(ctx, w, r, sidenote(x))
  nothing
end

"""
Take in what the field has, when it changed since the palette last looked.
In the list of commands, the first row is the one that's chosen again. A chip
of words or of a number has what the text writes, as it's typed. In a list
that's searched, typing takes away what the chip had and keeps the rows by
the new letters.
"""
palette_sync!(e, p::CommandPalette) = begin
  i = input(e)
  i.text == p.typed && return
  p.typed = i.text
  p.fault = ""
  p.pick, p.shown = 1, 0
  p.scroll.offset = 0px
  p.command === nothing && return
  chips = palette_chips(p)
  kind = p.at <= length(chips) ? chip_kind(e, chips[p.at]) : :run
  text = String(strip(i.text))
  if kind == :text
    say!(p, chips, p.at, isempty(text) ? UNSAID : something(chip_typed(chips[p.at], text), UNSAID))
  elseif kind == :number
    if isempty(text) || text in ("-", ".", "-.")
      say!(p, chips, p.at, UNSAID)
    else
      # Text that writes no number leaves the chip with the number that it had
      x = chip_typed(chips[p.at], text)
      x === nothing || say!(p, chips, p.at, x)
    end
  elseif kind == :search
    p.browsed = false
    p.query = text
    say!(p, chips, p.at, UNSAID)
  else
    # A switch, a choice, a list of a few and the Run button take no text
    palette_text!(e, p, "")
  end
  nothing
end

"""
Say the row that's chosen for the chip that the keyboard is in. With no rows,
the chip stays as it is. A chip that has something keeps it too, unless the
mouse chose a row: the arrows say their row at once, and typing takes away
what the chip had. So the things that clicks on the window chose stay.
"""
palette_say!(e, p::CommandPalette) = begin
  rows = palette_rows(e, p)
  isempty(rows) && return
  chips = palette_chips(p)
  chip_value(p, chips, p.at) === UNSAID || p.pointed || return
  empty!(p.inner)
  say!(p, chips, p.at, rows[clamp(p.pick, 1, length(rows))].value)
  nothing
end

"""
What ↑ and ↓ do in a chip with a list: choose the row before or after, and
say it at once. In a list that's searched, the field then has the row's words,
selected, and the rows stay as they were.
"""
palette_browse!(e, p::CommandPalette, by::Int) = begin
  rows = palette_rows(e, p)
  isempty(rows) && return
  p.pick = clamp(p.pick + by, 1, length(rows))
  row = rows[p.pick]
  chips = palette_chips(p)
  searched = chip_kind(e, chips[p.at]) == :search
  say!(p, chips, p.at, row.value)
  searched && (p.browsed = true; palette_text!(e, p, row.name, select=true))
  nothing
end

"The things that a choice of two chooses between, and the place of the one that's said, or 0"
segment_state(e, p::CommandPalette, chips, k::Int) = begin
  found = chip_choices(e, chips[k])
  x = chip_value(p, chips, k)
  (found, something(findfirst(o -> isequal(o, x), found), 0))
end

"Choose the next of a choice of two, or the one before. From nothing, the next is the first and the one before is the last."
segment_step!(e, p::CommandPalette, k::Int, by::Int) = begin
  chips = palette_chips(p)
  found, at = segment_state(e, p, chips, k)
  isempty(found) && return
  say!(p, chips, k, found[at == 0 ? (by > 0 ? 1 : length(found)) : mod1(at + by, length(found))])
  nothing
end

"Turn a switch on or off. One that has nothing yet is off."
switch!(p::CommandPalette, k::Int) = (chips = palette_chips(p); say!(p, chips, k, chip_value(p, chips, k) !== true); nothing)

"""
What Tab and ⇧Tab do among the chips: go to the next or the last one, round
through the Run button. Tab takes the row that's chosen in a list first, as
Return does, and gives a choice of two that has nothing its first thing.
"""
palette_tab!(e, p::CommandPalette, by::Int) = begin
  chips = palette_chips(p)
  if by > 0 && p.at <= length(chips)
    kind = chip_kind(e, chips[p.at])
    kind in (:pick, :search) && palette_say!(e, p)
    kind == :segment && chip_value(p, chips, p.at) === UNSAID && segment_step!(e, p, p.at, 1)
  end
  go_chip!(e, p, mod1(p.at + by, length(palette_chips(p)) + 1))
end

"What ⌥ does: show the chips of the keyword arguments, or hide them again. A command with none stays as it is."
palette_advanced!(e, p::CommandPalette) = begin
  (p.command !== nothing && any(c -> c.keyword, palette_chips(p.methods, p.values))) || return
  p.advanced = !p.advanced
  p.at > length(palette_chips(p)) && go_chip!(e, p, length(palette_chips(p)) + 1)
  nothing
end

"What's said for each chip that isn't a keyword argument, with off for a switch that wasn't touched"
palette_said(e, p::CommandPalette) = begin
  chips = palette_chips(p.methods, p.values)
  Any[x === UNSAID && chip_kind(e, chips[k]) == :switch ? false : x for (k, x) in enumerate(p.values)]
end

"""
Call the command's function with what's said, and close the palette. While a
chip that the function needs has nothing, the keyboard goes to it. An error
that the function throws shows over the bar, and the palette stays.
"""
palette_run!(e, w, p::CommandPalette) = begin
  said = palette_said(e, p)
  sig = ready_method(p.methods, said)
  if sig === nothing
    chips = palette_chips(p.methods, p.values)
    k = something(findfirst(k -> said[k] === UNSAID && !chips[k].optional, eachindex(said)), 1)
    go_chip!(e, p, k)
    p.fault = "$(chip_name(chips[k])) has nothing yet"
    return
  end
  args = palette_args(e, w, sig, said)
  named = Pair{Symbol,Any}[name => x for (name, x) in p.keywords]
  # The palette closes first, so that the function finds the page with the keyboard, and can show something of its own.
  # A row that the window showed stays, as the command runs with it. A jump notes the place from before that: see `place_now`.
  p.before === nothing || unpreviewed!(e, p.before)
  p.before = nothing
  close_palette!(e)
  try
    value = try
      Base.invokelatest(p.command.call, args...; named...)
    finally
      unpreviewed!(e, nothing)
    end
    # What a command of the page's own gave back shows under the top bar
    if p.command.kind == :page && value !== nothing
      said = first(split(value isa AbstractString ? value : value_text(value, parentmodule(p.command.call)), '\n'))
      say_result!(e, "$(palette_name(p.command.name)): " * (length(said) > 120 ? first(said, 119) * "…" : said))
    end
  catch err
    err isa InterruptException && rethrow()
    p.from, p.moved = palette_risen(e, p), time()
    e.popup = :commands
    go_chip!(e, p, length(palette_chips(p)) + 1)
    p.fault = "Command failed: " * String(first(split(sprint(showerror, err), '\n')))
  end
  nothing
end

"""
What Return does: it takes the command that's chosen, or does what the chip
that the keyboard is in does with it, or runs the command.
"""
palette_take!(e, w, p::CommandPalette) = begin
  if p.command === nothing
    rows = palette_rows(e, p)
    isempty(rows) && return
    c = rows[clamp(p.pick, 1, length(rows))].value
    # Navigate goes at once to a web address or a path that's typed in the list of commands
    to = c.name == :navigate ? palette_address(e, p) : nothing
    to === nothing ? take_command!(e, w, p, c) : (close_palette!(e); navigate!(e, to))
    return
  end
  chips = palette_chips(p)
  p.at > length(chips) && return palette_run!(e, w, p)
  kind = chip_kind(e, chips[p.at])
  if kind == :segment
    segment_step!(e, p, p.at, 1)   # it chooses the next, and stays
  elseif kind == :switch
    switch!(p, p.at)
    palette_next!(e, p)
  elseif kind == :number
    text = String(strip(input(e).text))
    if !isempty(text) && chip_typed(chips[p.at], text) === nothing
      # Text that writes no number goes back to the number that the chip has
      x = chip_value(p, chips, p.at)
      palette_text!(e, p, x === UNSAID ? "" : worded(x), select=true)
    else
      palette_next!(e, p)
    end
  else
    kind in (:pick, :search) && palette_say!(e, p)
    palette_next!(e, p)
  end
  nothing
end

"What a key does while the palette shows. `command` is the command that the key bindings give the key, or nothing."
palette_key!(e, w, K, command) = begin
  p = palette(e)
  palette_sync!(e, p)
  command == :commands && return close_palette!(e)
  # Esc, Return, ↑, ↓ and ⌫ do what they do here only by themselves. Tab can have ⇧ with it, to go back. ⌥ goes down by itself.
  # ⌥↑ makes the thing of a chip for a thing in the window bigger: the part that holds it. ⌥↓ goes back.
  K in (Keys.up, Keys.down) && only_held(w, Keys.opt) && return (resize_thing!(e, p, K == Keys.up ? 1 : -1); nothing)
  K in (Keys.escape, Keys.enter, Keys.up, Keys.down, Keys.backspace) && !unmodified(w) && return nothing
  K == Keys.tab && !(unmodified(w) || only_held(w, Keys.shft)) && return nothing
  K == Keys.opt && setdiff(held_keys(w), Keys.opt) != Keys(0) && return nothing
  if K == Keys.escape
    # Esc empties the bar. In an empty bar, it closes the palette.
    p.command === nothing && isempty(input(e).text) ? close_palette!(e) : palette_clear!(e, p)
  elseif K == Keys.enter
    palette_take!(e, w, p)
  elseif p.command === nothing
    if K == Keys.down || K == Keys.up
      p.pick = clamp(p.pick + (K == Keys.down ? 1 : -1), 1, max(1, length(palette_rows(e, p))))
    elseif K == Keys.tab
      isempty(palette_ghost(e, p)) || palette_text!(e, p, first(palette_rows(e, p)).name)
    end
  elseif K == Keys.tab
    palette_tab!(e, p, only_held(w, Keys.shft) ? -1 : 1)
  elseif K == Keys.opt
    palette_advanced!(e, p)
  else
    chips = palette_chips(p)
    p.at <= length(chips) || return nothing
    kind = chip_kind(e, chips[p.at])
    by = K == Keys.down ? 1 : K == Keys.up ? -1 : 0
    if kind in (:pick, :search) && by != 0
      palette_browse!(e, p, by)
    elseif kind == :search && K == Keys.backspace && isempty(input(e).text)
      # ⌫ in an empty field takes away what the chip has
      say!(p, chips, p.at, UNSAID)
    elseif kind == :number && by != 0
      x = chip_value(p, chips, p.at)
      x = (x isa Number ? x : counts_from(e, Val(p.command.name), p.at)) - by   # ↑ adds one
      fits(x, chips[p.at]) && (say!(p, chips, p.at, x); palette_text!(e, p, worded(x), select=true))
    elseif kind == :segment && K in (Keys.left, Keys.up)
      segment_step!(e, p, p.at, -1)
    elseif kind == :segment && K in (Keys.right, Keys.down, Keys.space)
      segment_step!(e, p, p.at, 1)
    elseif kind == :switch && K == Keys.space
      switch!(p, p.at)
    end
    # A command like Theme shows the row that the arrows reached
    by != 0 && preview!(e, p)
  end
  nothing
end

# --- where each part is ---

omni_wide(text::AbstractString, size::Real, weight="") = isempty(text) ? 0.0 : num(measure(Face(omni_font(), omni_weight(weight), px(size), colours.ink, false), text))

"What a chip shows while the keyboard isn't in it, or while it takes no text: what's said, or its name. The second is true for the name."
chip_words(p::CommandPalette, chips, k::Int) = (x = chip_value(p, chips, k); x === UNSAID ? (chip_name(chips[k]), true) : (worded(x), false))

"How wide chip `k` is. One that's typed in is as wide as its text. An open list that's searched is as wide as its longest row, as in Centient."
chip_wide(e, p::CommandPalette, chips, k::Int) = begin
  chip = chips[k]
  kind = chip_kind(e, chip)
  frame = 18.0   # the room at its two sides, and its border
  kind == :switch && return frame + 32
  if kind == :segment
    found = chip_choices(e, chip)
    return frame + 2 + sum(o -> 16 + ceil(omni_wide(worded(o), 13, "Semibold")), found, init=0.0) + max(0, length(found) - 1)
  end
  words, _ = chip_words(p, chips, k)
  on = p.at == k
  # A chip for things in the window shows only their letters, once it has them
  letters = filter(l -> l.k == k, chip_letters(p, chips))
  isempty(letters) || on || return sum(l -> ceil(omni_wide(l.letter, 13, "Semibold")) + 24, letters)
  wide = omni_wide(on && kind != :pick && !isempty(input(e).text) ? input(e).text : on && kind == :search ? chip_name(chip) : words, 13)
  on && kind == :search && (wide = max(wide, min(320.0, maximum(o -> omni_wide(worded(o), 13), chip_choices(e, chip), init=0.0))))
  # A chip that's typed in has room for one more letter and the caret, so the field holds a letter before the chip grows for it
  frame + max(kind == :number ? 60.0 : 40.0, ceil(wide) + (on && kind != :pick ? 20 : 6))
end

"""
True when the words that the command `name` asks for are what it's for, as the
words of Ask Agent are. Their chip is wide before anything is typed in it.
"""
wide_words(::Val) = false
wide_words(::Val{:ask_agent}) = true

const OMNI_WORDS_LEAST, OMNI_WORDS_MOST = 240.0, 560.0   # how wide the chip of such words is, when the bar has room

"The tag, the chips and the Run button, each with how wide it is, in their order, when a line of the bar has room for `room`"
palette_items(e, p::CommandPalette, chips, room) = begin
  items = Any[(what=:tag, k=0, w=20 + ceil(omni_wide(palette_name(p.command.name), 13, "Medium")))]
  for k in eachindex(chips)
    push!(items, (what=:chip, k=k, w=chip_wide(e, p, chips, k)))
  end
  push!(items, (what=:run, k=0, w=24 + ceil(omni_wide("Run", 13, "Semibold")) + 4 + 11))
  # Words that the command is for take the room that's left on the line, up to OMNI_WORDS_MOST. Long words
  # grow the chip only to the end of the line, and then scroll in it, so the chip and the Run button stay in sight.
  if wide_words(Val(p.command.name))
    at = findfirst(it -> it.what == :chip && chip_kind(e, chips[it.k]) == :text, items)
    if at !== nothing
      it = items[at]
      left = floor(room - (sum(i -> i.w, items) - it.w) - OMNI_GAP * (length(items) - 1))
      most = left >= OMNI_WORDS_LEAST ? left : room
      items[at] = (what=it.what, k=it.k, w=min(most, max(it.w, clamp(left, OMNI_WORDS_LEAST, OMNI_WORDS_MOST))))
    end
  end
  items
end

"`items` on as many lines as they need, when a line has room for `room`"
palette_lines(items, room) = begin
  lines, used = [Any[]], 0.0
  for it in items
    need = it.w + (isempty(last(lines)) ? 0 : OMNI_GAP)
    if used + need > room && !isempty(last(lines))
      push!(lines, Any[])
      used, need = 0.0, it.w
    end
    push!(last(lines), it)
    used += need
  end
  lines
end

"The lines of the bar: all of them when the chips are on as many lines as they need, and the first line with room for the … button when they aren't and don't fit. The second is true when the … shows."
palette_bar_lines(e, p::CommandPalette, chips, room) = begin
  items = palette_items(e, p, chips, room)
  lines = palette_lines(items, room)
  (p.wrap || length(lines) == 1) && return (lines, false)
  ([first(palette_lines(items, room - 42 - OMNI_GAP))], true)
end

"How wide the bar is inside, for the tag, the chips and the Run button"
palette_room(e) = num(page_span(e)[2]) - OMNI_LEFT - OMNI_RIGHT - 2 - 2OMNI_BAR_X

"True when chip `k` is on a line that shows. The Run button, one more than the last chip, always counts as in sight."
palette_fits(e, p::CommandPalette, k::Int) = begin
  chips = palette_chips(p)
  k <= length(chips) || return true
  lines, _ = palette_bar_lines(e, p, chips, palette_room(e))
  any(it -> it.what == :chip && it.k == k, Iterators.flatten(lines))
end

"""
Where each part of the palette is in the window in this frame, in pixels: the
strip along the bottom, the bar in it, each thing in the bar, and the list
with what it hangs over. `down` is how far the whole of it is below its place
while the bar slides. The strip is `band` here.
"""
palette_plan(e, p::CommandPalette) = begin
  H = num(window_size(e)[2])
  # The bar is as wide as the page's space: beside the sidebar, or in agent mode under the page's card
  left = num(page_span(e)[1])
  W = left + num(page_span(e)[2])
  chips = p.command === nothing ? Wanted[] : palette_chips(p)
  room = palette_room(e)
  lines, more = p.command === nothing ? (Any[], false) : palette_bar_lines(e, p, chips, room)
  n = max(1, length(lines))
  bar_h = (p.command === nothing ? OMNI_FIELD_H : n * OMNI_CHIP_H + (n - 1) * OMNI_GAP + 2OMNI_BAR_Y) + 2
  band_h = 1 + OMNI_TOP + bar_h + OMNI_BOTTOM
  down = (1 - palette_risen(e, p)) * band_h
  band = (x=left, y=H - band_h + down, w=W - left, h=band_h)
  bar = (x=left + OMNI_LEFT, y=band.y + 1 + OMNI_TOP, w=W - left - OMNI_LEFT - OMNI_RIGHT, h=bar_h)
  # Each thing in the bar
  places = Any[]
  for (row, line) in enumerate(lines)
    x = bar.x + 1 + OMNI_BAR_X
    for it in line
      push!(places, (what=it.what, k=it.k, x=x, y=bar.y + 1 + OMNI_BAR_Y + (row - 1) * (OMNI_CHIP_H + OMNI_GAP), w=it.w, h=OMNI_CHIP_H))
      x += it.w + OMNI_GAP
    end
  end
  # The list, and what it hangs over
  rows = p.rows
  list = nothing
  if e.popup == :commands && p.command === nothing
    words = isempty(rows) && !isempty(strip_text(input(e))) ? "No command has that name" : ""
    many = isempty(words) ? length(rows) : 1
    if many > 0
      high = isempty(words) ? OMNI_ROW : OMNI_ROW_ONE
      # It's narrower than the bar by a tenth of the bar at each side, as in Centient
      inset = max(48.0, round(bar.w * 0.1))
      wide = min(max(320.0, bar.w - 2inset), bar.w - 2OMNI_FOOT)
      most = clamp(bar.y - 15 - 60, high, OMNI_LIST_MOST)
      tall = min(many * high, most)
      # The list comes down to the bar, so the card of rows is as near the bar's top line as it is to the list's other sides
      frame = (x=bar.x + (bar.w - wide) / 2, y=bar.y - tall - 15, w=wide, h=tall + 15)
      list = (kind=:attach, frame=frame, target=bar, row=high, tall=tall, words=words, round=6.0)
    end
  elseif e.popup == :commands && p.at <= length(chips)
    kind = chip_kind(e, chips[p.at])
    at = findfirst(c -> c.what == :chip && c.k == p.at, places)
    words = kind == :search && isempty(rows) && !isempty(p.query) ? "No matches found" : ""
    many = isempty(words) ? length(rows) : 1
    if kind in (:pick, :search) && at !== nothing && many > 0
      chip = places[at]
      longest = maximum(r -> length(r.name), rows, init=length(words))
      wide = 2ceil(max(max(200.0, ceil(longest * 8.5) + 40), chip.w + 36) / 2)
      # It's over the middle of its chip, and stays over the bar
      x = chip.x + chip.w / 2 - wide / 2
      x + wide > bar.x + bar.w && (x = chip.x + chip.w - wide)
      x < bar.x && (x = chip.x)
      x = clamp(x, 0.0, max(0.0, W - wide))
      top_room = chip.y - OMNI_POP_GAP - 14 - 60
      most = kind == :search ? min(OMNI_CHOICES_MOST, top_room) : min(480.0, top_room)
      tall = min(many * OMNI_ROW_ONE, max(OMNI_ROW_ONE, most))
      frame = (x=x, y=chip.y - OMNI_POP_GAP - tall - 15, w=wide, h=tall + 15)
      list = (kind=:envelope, frame=frame, target=chip, row=OMNI_ROW_ONE, tall=tall, words=words, round=4.0)
    end
  end
  (W=W, H=H, band=band, bar=bar, places=places, more=more, chips=chips, list=list)
end

strip_text(i::TextInput) = String(strip(i.text))

# --- how it looks ---

"Put `child` at `(x, y)` of the window, in a layer of its own"
omni_at(x, y, child) = Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(px(y), 0px, 0px, px(x)), child)

omni_label(text, size, colour; weight="", family=omni_font()) =
  Text(text, size=px(size), family=family, subfamily=family == omni_font() ? omni_weight(weight) : weight, color=colour, wrap=WrapMode.none)

describe(p::CommandPalette) = begin
  e = editor(p)
  c = omni(e)
  i = input(e)
  showing = e.popup == :commands
  showing && palette_sync!(e, p)
  p.rows = showing ? palette_rows(e, p) : Any[]
  p.pick = clamp(p.pick, 1, max(1, length(p.rows)))
  i.color, i.placeholder_color = c.ink, p.command === nothing ? c.muted : c.placeholder
  i.font_size = p.command === nothing ? 15px : 13px
  i.font_family = omni_font()
  was = p.plan
  plan = p.plan = palette_plan(e, p)
  # A text field scrolls by how wide it was in the frame before. When a chip grew or shrank, the next frame shows the field at its new width at once.
  was === nothing || was.places == plan.places || redraw_in!(e, 0)
  i.placeholder = p.command === nothing ? "Type a command" : p.at <= length(plan.chips) ? chip_name(plan.chips[p.at]) : ""
  palette_moving(e) && redraw_in!(p, 0.0)
  band, bar, list = plan.band, plan.bar, plan.list
  # While a list hangs over the bar, the bar has the list's colours, so the two are one shape
  joined = list !== nothing
  layers = Any[
    # The strip has no colour of its own and no line along its top: the page shows through it, blurred, and less so further up
    node!(PaletteFrost, e, :palette_frost),
    omni_at(bar.x, bar.y, Box(fixed(px(bar.w)), height(px(bar.h)), radius(6px), background(joined ? c.drop : c.bar),
                              border(1px, :solid, joined && list.kind == :attach ? c.drop_line : c.bar_line), node!(PaletteBar, e, :palette_bar)))]
  if list !== nothing
    f = list.frame
    push!(layers, node!(PaletteLens, e, :palette_lens))
    # The rows are on a card with a line round it, 6px inside the list's own outline
    card = if isempty(list.words)
      p.scroll.height = height(px(list.tall))
      p.shown == p.pick || (p.shown = p.pick; scroll_into_view!(p.scroll, px(list.row * (p.pick - 1)), px(list.row * p.pick)))
      reuse!(p.scroll, Column(width(grow=grow), Alignment.Start, [node!(() -> PaletteRow(k=k), e, (:palette_row, k)) for k in eachindex(p.rows)]...))
    else
      Row(width(grow=grow), height(px(list.row)), padding(14px, 0px), Box(omni_label(list.words, 14, c.ink, weight=OMNI_NAME)))
    end
    push!(layers, omni_at(f.x + 7, f.y + 7, Box(fixed(px(f.w - 14)), height(px(list.tall + 2)), radius(4px), clip=true, background(c.drop),
                                                border(1px, :solid, c.drop_line), card)))
  end
  if showing && !isempty(p.fault)
    # What went wrong shows where Centient's toast does: over the right end of the bar
    wide = min(bar.w, 24 + ceil(omni_wide(p.fault, 13)) + 2)
    push!(layers, omni_at(bar.x + bar.w - wide, band.y - 54, Box(fixed(px(wide)), height(40px), padding(12px, 0px), radius(8px), clip_x=true,
                                                                  background(c.toast), border(1px, :solid, OMNI_WRONG), lifted,
                                                                  omni_label(p.fault, 13, OMNI_WRONG))))
  end
  Stack(width(grow=grow), height(grow=grow), Alignment.Start, name="Command palette",
    # While a click on the window chooses for a chip, the window's parts are there for the click to find
    (showing && click_chip(e, p) === nothing ? (node!(PaletteCatch, e, :palette_catch),) : ())..., layers...)
end

describe(::PaletteCatch) = Box(width(grow=grow), height(grow=grow))
# A click outside the list of commands closes the palette. While a command has its chips, the palette stays.
onkey(c::PaletteCatch, ::KeyPress) = begin
  e = editor(c)
  palette(e).command === nothing && close_palette!(e)
  handled
end

# It's one pixel at the corner of the window, so the mouse goes through to the chips under what it draws,
# which is placed by the plan. With no size at all it wouldn't be drawn.
describe(::PaletteLens) = Box(fixed(1px), height(1px))

"The places along a quarter of a circle round `(cx, cy)`, from the angle `from` to the angle `to`. 0 is to the right, and a quarter turn on is down."
omni_arc(cx, cy, r, from, to) = [(cx + r * cos(a), cy + r * sin(a)) for a in range(from, to, length=7)]

"""
The outline of a list and what it hangs over, as the places along it, and the
outline of what's filled with the list's colour. Over a chip, the outline goes
round the list, curves in to the chip's sides and goes round the chip, so the
two are one shape. Over the bar, the list's sides go straight down and flare
out onto the bar's top line. Both are Centient's shapes. `q` is how round the
list's top corners are.
"""
lens_shapes(list; q=8.0) = begin
  f, t = list.frame, list.target
  l, top, r, bottom = f.x + 0.5, f.y + 0.5, f.x + f.w - 0.5, f.y + f.h
  quarter = pi / 2
  crown = [omni_arc(l + q, top + q, q, 2quarter, 3quarter); omni_arc(r - q, top + q, q, 3quarter, 4quarter)]
  if list.kind == :attach
    line = t.y + 0.5
    g = OMNI_FOOT
    outline = [omni_arc(l - g, line - g, g, quarter, 0.0); crown; omni_arc(r + g, line - g, g, 2quarter, quarter)]
    return (outline, [outline; (r + g, line + 1.0); (l - g, line + 1.0)], false)
  end
  # Over a chip: the gap between the two is as tall as the curve in to the chip is round
  cl, cr, ct, cb = t.x + 0.5, t.x + t.w - 0.5, t.y, t.y + t.h - 0.5
  g, rc = ct - bottom, list.round
  # A chip that's at an edge of the list has a straight side there
  wall_l, wall_r = cl - g - q < l, cr + g + q > r
  right = wall_r ? [(r, ct)] : [omni_arc(r - q, bottom - q, q, 0.0, quarter); omni_arc(cr + g, bottom + g, g, 3quarter, 2quarter)]
  left = wall_l ? [(l, ct)] : [omni_arc(cl - g, bottom + g, g, 0.0, -quarter); omni_arc(l + q, bottom - q, q, quarter, 2quarter)]
  cr2, cl2 = wall_r ? r : cr, wall_l ? l : cl
  under = [omni_arc(cr2 - rc, cb - rc, rc, 0.0, quarter); omni_arc(cl2 + rc, cb - rc, rc, quarter, 2quarter)]
  ([crown; right; under; left], [crown; right; (cr2, ct + 1.0); (cl2, ct + 1.0); left], true)
end

draw(ctx, size, ui::ConcreteRect, lens::PaletteLens) = begin
  e = editor(lens)
  plan = palette(e).plan
  (plan === nothing || plan.list === nothing) && return
  c = omni(e)
  outline, inside, closed = lens_shapes(plan.list)
  f = plan.list.frame
  # The list's shadow, which stops at the bar
  with_clip(ctx, 0px, 0px, px(plan.W), px(plan.bar.y)) do
    shade = ink(RGBA(0, 0, 0, e.theme == :night ? 0.5 : 0.14))
    blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 9f0, true)
    Skia.sk_paint_set_maskfilter(shade, blur)
    shape = path_through([(f.x, f.y + 4); (f.x + f.w, f.y + 4); (f.x + f.w, f.y + f.h + 4); (f.x, f.y + f.h + 4)], true)
    Skia.sk_canvas_draw_path(ctx, shape, shade)
    Skia.sk_path_delete(shape)
    Skia.sk_maskfilter_unref(blur)
    Skia.sk_paint_delete(shade)
  end
  paint = ink(c.drop)
  shape = path_through(inside, true)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_path_delete(shape)
  Skia.sk_paint_delete(paint)
  trace(ctx, outline, c.drop_line, 1; closed)
end

# One pixel at the corner of the window, as the lens is, so it takes no clicks. It draws where the plan says.
describe(::PaletteFrost) = Box(fixed(1px), height(1px))

draw(ctx, size, ui::ConcreteRect, f::PaletteFrost) = begin
  plan = palette(editor(f)).plan
  plan === nothing && return
  b, top = plan.band, plan.bar.y - OMNI_FADE
  blur_under(ctx, b.x, top, b.w, b.y + b.h - top, OMNI_BLUR, fade=OMNI_FADE)
end

"""
Blur what's drawn so far in the part `(x, y, w, h)` of the window, as frosted
glass blurs what's behind it. `sigma` is how far the blur spreads. It copies
the pixels drawn so far, and draws the copy back blurred, cut to that part. A
canvas with no pixels of its own, like one that records, stays as it is. With
`fade`, the blur is none at the top of the part, and comes in smoothly to the
whole of it `fade` pixels down.
"""
blur_under(ctx, x, y, w, h, sigma; fade=0.0) = begin
  (w > 0 && h > 0) || return
  surface = Skia.sk_canvas_get_surface(ctx)
  surface == C_NULL && return
  image = Skia.sk_surface_make_image_snapshot(surface)
  image == C_NULL && return
  m = Ref{Skia.sk_matrix_t}()
  Skia.sk_canvas_get_total_matrix(ctx, m)
  sx, sy, tx, ty = Float64(m[].scaleX), Float64(m[].scaleY), Float64(m[].transX), Float64(m[].transY)
  # The copy is in the screen's pixels. Only the part that the blur reads is drawn: the part, and as far round it as the blur spreads.
  reach = 3sigma
  iw, ih = Float64(Skia.sk_image_get_width(image)), Float64(Skia.sk_image_get_height(image))
  l, t = max(0.0, sx * (x - reach) + tx), max(0.0, sy * (y - reach) + ty)
  r, d = min(iw, sx * (x + w + reach) + tx), min(ih, sy * (y + h + reach) + ty)
  if r > l && d > t
    area = Ref(Skia.sk_rect_t(Float32(x), Float32(y), Float32(x + w), Float32(y + h)))
    # A fade needs a layer of its own, so that the mask takes away only some of the blur and none of what's under it
    fade > 0 && Skia.sk_canvas_save_layer(ctx, area, C_NULL)
    paint = Skia.sk_paint_new()
    blur = Skia.sk_imagefilter_new_blur(Float32(sigma), Float32(sigma), Skia.SK_TILE_MODE_CLAMP, C_NULL, C_NULL)
    Skia.sk_paint_set_imagefilter(paint, blur)
    with_clip(ctx, px(x), px(y), px(w), px(h)) do
      paint_picture(ctx, image, (l, t, r - l, d - t), ((l - tx) / sx, (t - ty) / sy, (r - l) / sx, (d - t) / sy), paint)
    end
    Skia.sk_imagefilter_unref(blur)
    Skia.sk_paint_delete(paint)
    if fade > 0
      # The mask is clear at the top and solid `fade` down, and eases in and out between
      at = range(0.0, 1.0, length=9)
      points = [Skia.sk_point_t(Float32(x), Float32(y)), Skia.sk_point_t(Float32(x), Float32(y + fade))]
      colours = UInt32[UInt32(round(255 * a^2 * (3 - 2a))) << 24 for a in at]
      shader = Skia.sk_shader_new_linear_gradient(points, colours, Float32.(at), Cint(length(at)), Skia.SK_TILE_MODE_CLAMP, C_NULL)
      mask = Skia.sk_paint_new()
      Skia.sk_paint_set_shader(mask, shader)
      Skia.sk_paint_set_blend_mode(mask, Skia.SK_BLEND_MODE_DSTIN)
      Skia.sk_canvas_draw_rect(ctx, area, mask)
      Skia.sk_shader_unref(shader)
      Skia.sk_paint_delete(mask)
      Skia.sk_canvas_restore(ctx)
    end
  end
  Skia.sk_image_unref(image)
end

"A key as a row shows it: its sign in a box"
omni_key(c, sign, on) = Box(height(22px), padding(8px, 0px), radius(4px), background(on ? c.key_on : c.key),
                            border(1px, :solid, on ? c.key_on_line : c.key_line), omni_label(sign, 11, on ? c.key_on_ink : c.key_ink, family=SANS))

"The signs of the keys of a shortcut, one for each key, as Centient shows them: ⌘, ⇧ and P for ⌘⇧P"
key_signs(s::Shortcut) = String[sign for stroke in s for sign in [[sign for (key, _, sign) in HOLDS if key in stroke.held]; get(() -> uppercase(KEY_OF[stroke.key]), KEY_SIGNS, stroke.key)]]

describe(r::PaletteRow) = begin
  e = editor(r)
  p = palette(e)
  r.k <= length(p.rows) || return Box(height(0px))
  c = omni(e)
  row = p.rows[r.k]
  on = p.pick == r.k
  # A line is between two rows, but not at an edge of the row that's chosen
  ruled = r.k > 1 && !on && p.pick != r.k - 1
  look = (width(grow=grow), padding(14px, 0px), background(on ? c.selected : c.drop), border(1px, :solid, ruled ? c.rule : clear)[:top])
  if p.command !== nothing
    return Row(look..., height(px(OMNI_ROW_ONE)), child_gap=10px, name="Choice",
      Box(width(grow=grow), Alignment.Start, clip_x=true, omni_label(row.name, 14, c.ink, weight=OMNI_NAME)),
      (isempty(row.note) ? () : (Box(omni_label(row.note, 12, on ? c.ink2 : c.muted)),))...)
  end
  # The letters that were typed are in bold where the name has them
  before, found, after = match_parts(row.name, lowercase(strip_text(input(e))))
  parts = [Box(omni_label(text, 14, c.ink, weight=weight)) for (text, weight) in ((before, OMNI_NAME), (found, OMNI_MATCH), (after, OMNI_NAME)) if !isempty(text)]
  Row(look..., height(px(OMNI_ROW)), child_gap=10px, name="Command",
    Column(width(grow=grow), Alignment.Start, child_gap=8px, clip_x=true,
      # What the command works on follows its name, fainter
      Row(child_gap=8px, Alignment.End, Row(parts...), (isempty(row.on) ? () : (Box(padding(0px, 0px, 1px, 0px), omni_label(row.on, 12, on ? c.ink2 : c.muted)),))...),
      Box(omni_label(row.note, 12, on ? c.ink2 : c.muted))),
    (row.keys === nothing ? () : (Row(child_gap=4px, [omni_key(c, sign, on) for sign in key_signs(row.keys)]...),))...)
end
cursor(::PaletteRow) = :hand
# The mouse over a row chooses it, and no more. The row is in sight already, so the list doesn't scroll to it.
onmouse(r::PaletteRow, ::MouseMove) = (p = palette(editor(r)); p.pick = p.shown = r.k; p.pointed = true; handled)
# A click on a row does what Return does on it
onkey(r::PaletteRow, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(r)
  p = palette(e)
  r.k <= length(p.rows) || return handled
  p.pick = p.shown = r.k
  p.pointed = true
  palette_take!(e, ev.window, p)
  handled
end

"The field with the rest of a name after its text, in a fainter colour. `size` is the size of the field's text."
omni_field(e, p::CommandPalette, size) = begin
  i = input(e)
  ghost = palette_ghost(e, p)
  isempty(ghost) && return i
  Stack(width(grow=grow), height(grow=grow),
    Row(width(grow=grow), height(grow=grow), Box(fixed(px(omni_wide(i.text, size)))), Box(omni_label(ghost, size, omni(e).placeholder)), Box(width(grow=grow))),
    i)
end

describe(b::PaletteBar) = begin
  e = editor(b)
  p = palette(e)
  c = omni(e)
  plan = p.plan
  p.command === nothing && return Row(width(grow=grow), height(grow=grow), padding(px(OMNI_BAR_X), 0px), name="Command field", omni_field(e, p, 15))
  lines = Any[]
  for y in unique(pl.y for pl in plan.places)
    parts = Any[]
    for pl in plan.places
      pl.y == y || continue
      push!(parts, pl.what == :tag ? Box(fixed(px(pl.w)), height(px(pl.h)), padding(10px, 0px), radius(4px), background(OMNI_TAG),
                                         Box(omni_label(palette_name(p.command.name), 13, OMNI_TAG_INK, weight="Medium"))) :
                   pl.what == :run ? node!(PaletteRun, e, :palette_run) : node!(() -> PaletteChip(k=pl.k), e, (:palette_chip, pl.k)))
    end
    push!(lines, Row(width(grow=grow), height(px(OMNI_CHIP_H)), child_gap=px(OMNI_GAP), parts...,
                     Box(width(grow=grow)), (plan.more && isempty(lines) ? (node!(PaletteMore, e, :palette_more),) : ())...))
  end
  Column(width(grow=grow), height(grow=grow), Alignment.Start, padding(px(OMNI_BAR_X), px(OMNI_BAR_Y)), child_gap=px(OMNI_GAP), clip=true, name="Command field", lines...)
end
cursor(b::PaletteBar) = palette(editor(b)).command === nothing ? :ibeam : :arrow
onkey(b::PaletteBar, ::KeyPress{Keys.mouse_left}) = (e = editor(b); palette_focus!(e, palette(e)); handled)

describe(m::PaletteMore) = begin
  c = omni(editor(m))
  Row(fixed(42px), height(px(OMNI_CHIP_H)), radius(4px), background(ishovered(m) ? c.hover : c.chip), justify=Alignment.Center,
      border(1px, :solid, c.chip_line), name="More", Box(omni_label("…", 13, c.ink2, weight="Medium")))
end
cursor(::PaletteMore) = :hand
onkey(m::PaletteMore, ::KeyPress{Keys.mouse_left}) = (palette(editor(m)).wrap = true; handled)

describe(chip::PaletteChip) = begin
  e = editor(chip)
  p = palette(e)
  c = omni(e)
  plan = p.plan
  at = plan === nothing ? nothing : findfirst(pl -> pl.what == :chip && pl.k == chip.k, plan.places)
  (at === nothing || chip.k > length(plan.chips)) && return Box()
  pl, wanted = plan.places[at], plan.chips[chip.k]
  kind = chip_kind(e, wanted)
  on = p.at == chip.k
  x = chip_value(p, plan.chips, chip.k)
  # The mouse over a chip for a moment shows what the chip is for
  hovered = ishovered(chip)
  hovered || (chip.over = 0.0)
  hovered && chip.over == 0.0 && (chip.over = time())
  hovered && time() - chip.over < 0.4 && redraw_in!(chip, 0.4 - (time() - chip.over))
  w = window_of(e)
  hovered && w !== nothing && 0.4 <= time() - chip.over < 0.6 &&
    show_tooltip!(w, Box(padding(10px, 6px), omni_label(chip_tip(wanted), 12, TIP_INK)), px(pl.x), px(pl.y), px(pl.w), px(pl.h), placement=:top, gap=6px)
  # While a list hangs over the chip, the two are one shape: the chip has the list's colour, and the outline is the list's
  joined = on && plan.list !== nothing && plan.list.kind == :envelope
  back = on ? c.drop : x !== UNSAID ? c.complete : hovered ? c.hover : c.chip
  look = (fixed(px(pl.w)), height(px(pl.h)), padding(8px, 0px), joined ? radius(0px, 0px, 4px, 4px) : radius(4px), background(back),
          border(1px, :solid, joined ? clear : c.chip_line))
  if kind == :switch
    is = x === true
    return Box(look..., name="Chip",
      Row(fixed(32px), height(18px), radius(9px), background(is ? OMNI_SWITCH_ON : OMNI_SWITCH_OFF), padding(0px, 0px, 0px, is ? 16px : 2px),
        Box(fixed(14px), height(14px), radius(7px), background(OMNI_KNOB)), Box(width(grow=grow))))
  elseif kind == :segment
    found, said = segment_state(e, p, plan.chips, chip.k)
    parts = Any[]
    for (n, o) in enumerate(found)
      n > 1 && push!(parts, Box(fixed(1px), height(grow=grow), background(c.chip_line)))
      push!(parts, Box(height(grow=grow), padding(8px, 0px), background(n == said ? c.hover : clear),
                       omni_label(worded(o), 13, n == said ? c.ink : c.muted, weight="Semibold")))
    end
    return Box(look..., name="Chip", Row(height(23px), radius(3px), clip=true, border(1px, :solid, c.chip_line), parts...))
  end
  if on && kind != :pick
    return Box(look..., name="Chip", omni_field(e, p, 13))
  end
  # A chip for things in the window has each thing's colour and letter, which the line round the thing has too
  letters = filter(l -> l.k == chip.k, chip_letters(p, plan.chips))
  if !isempty(letters)
    # Each letter is in a box of its own, as wide as it is, so its part of the chip can centre it
    cells = [Box(fixed(px(ceil(omni_wide(l.letter, 13, "Semibold")) + 24)), height(px(pl.h)), Alignment.Center, justify=Alignment.Center,
                 background(hovered ? paler(l.colour) : l.colour), Box(omni_label(l.letter, 13, colorant"white", weight="Semibold")))
             for l in letters]
    return Row(fixed(px(pl.w)), height(px(pl.h)), radius(4px), clip=true, name="Chip", cells...)
  end
  words, unsaid = chip_words(p, plan.chips, chip.k)
  Box(look..., clip_x=true, name="Chip", omni_label(words, 13, unsaid ? c.placeholder : c.ink))
end
cursor(chip::PaletteChip) = begin
  e = editor(chip)
  p = palette(e)
  chips = palette_chips(p)
  chip.k <= length(chips) && p.at == chip.k && chip_kind(e, chips[chip.k]) in (:text, :number, :search) ? :ibeam : :hand
end
# A click on a chip puts the keyboard in it. A click on a switch turns it too, and a click on a choice of two chooses the other.
onkey(chip::PaletteChip, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(chip)
  p = palette(e)
  hide_tooltip!(ev.window)
  chips = palette_chips(p)
  chip.k <= length(chips) || return handled
  kind = chip_kind(e, chips[chip.k])
  p.at == chip.k || go_chip!(e, p, chip.k)
  kind == :switch && switch!(p, chip.k)
  kind == :segment && segment_step!(e, p, chip.k, 1)
  palette_focus!(e, p)
  handled
end

describe(r::PaletteRun) = begin
  e = editor(r)
  p = palette(e)
  c = omni(e)
  on = p.at > length(palette_chips(p))
  words = on ? OMNI_GO_INK : c.run_ink
  # The arrow is the sign of the Return key, which the Mac's own font has no character for
  Row(height(px(OMNI_CHIP_H)), padding(10px, 0px), radius(4px), child_gap=4px, name="Run",
      background(on ? OMNI_GO : ishovered(r) ? c.run_hover : c.run), border(2px, :solid, on ? OMNI_GO_LINE : clear),
      (on ? (shadow(0, 0, 0, RGBA(34 / 255, 197 / 255, 94 / 255, 0.3), spread=3px),) : ())...,
      Box(omni_label("Run", 13, words, weight="Semibold")), Icon("arrow-return-left", size=11px, color=words))
end
cursor(::PaletteRun) = :hand
onkey(r::PaletteRun, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(r)
  palette_run!(e, ev.window, palette(e))
  handled
end
