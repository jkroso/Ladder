# The settings: the table of them, the file that keeps them, and the window and the pages that show them

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "./sheet" parts
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
@use "./folder_page" exports...
@use "./views" exports...
@use "./terminal_view" exports...
@use "./slides_view" exports...
@use "./agent/kinds" exports...
@use "./agent/window" exports...
@use "./commands" exports...
@use "./live_view" theme! text_size! font! weight! page_width! NARROWEST WIDEST
@use "./julia_levels" INDENTS GUIDES CODE_SCALES wrap! numbers! shade! indent_width! guide! code_font! code_weight! code_size!
@use "./page_extras" spelling!
@use "./autosave" autosave!
@use "./caret_glide" glide!
@use "./peek_cards" peeks!
@use "./app_updates" updates!

export SETTINGS_DROP, SETTINGS_SIZE, adopt_settings!, pages_dir, settings_dir, settings_editor,
       share_settings!, Setting, SETTINGS, SHARED, FOLLOWED, HIDINGS, on_unless_false, off_unless_true,
       one_of, number_within, weight_read, width_text, setting_named, read_setting!, read_kept!, kept_text,
       settings_text

# --- settings -----------------------------------------------------------------------------
#
# The settings are the page's colours, its font and the font's weight, the size
# of its text, its width, how code
# shows, the key bindings and how wide the sidebar is. ⌘, opens the settings in
# a window of their own.
# They're on the pages of one folder, each a Markdown file whose live blocks
# change them. ⌘, shows the folder's main page, and that page has a link to
# each of the others. These are pages like any other: the settings window
# shows them as any window shows a page, and any window can show them. A
# setting that changes in one window changes in every window. They are kept in
# a file, so the next window opens with them.

"The folder of Ladder's own pages. The built app changes it to the copies it writes out."
const pages_dir = Ref(joinpath(@__DIR__, "pages"))

"The folder of the pages that have the settings"
settings_dir() = joinpath(pages_dir[], "settings")

"Where the page of the settings is whose file is called `name`. Without a name, it's the main page, which ⌘, shows."
settings_page(name="settings.md") = joinpath(settings_dir(), name)

const SETTINGS_SIZE = (720px, 820px)   # of the settings window, when the window that asked for it is big enough
const SETTINGS_DROP = 48px             # how far the settings window's top is below the top of the window that asked for it

"""
True when `e` is the editor of the settings window: the one that ⌘, opened,
while it shows a page of the settings' folder. ⌘, closes that window, and a
file that macOS asks for goes to another window. In every other way it's a
window like any other.
"""
issettings(e) = e.settings && (dirname(e.buf.path) == settings_dir() || dirname(e.buf.path) in values(SETTINGS_FOLDERS))

"The editor of the settings window, or nothing while that window isn't open"
settings_editor() = (i = findfirst(issettings, editors); i === nothing ? nothing : editors[i])

"""
Show the settings page in a window of its own. With that window open already,
bring it to the front. In the settings window itself, close it.
"""
toggle_settings!(e) = begin
  by = window_of(e)
  by === nothing && return e
  issettings(e) && return (close(by); e)
  s = settings_editor()
  s === nothing || return (front!(window_of(s)); e)
  s = build_editor(settings_page())
  s.settings = true
  empty!(tabs(s))   # the settings window has no tabs, and its first page got one before it was the settings window
  same_settings!(s, e)
  s.remember = e.remember
  s.panel = false
  # The window goes over the middle of the one that asked for it, a little below its top
  wide, tall = SETTINGS_SIZE
  tall = min(tall, max(400px, by.size[2] - 2SETTINGS_DROP))
  at = (max(0px, by.position[1] + (by.size[1] - wide) / 2), by.position[2] + SETTINGS_DROP)
  s.size = (wide, tall)
  show_window!(window!(s, title="Settings", size=s.size, position=at), by)
  e
end

"""
Give the other windows the settings of `e`, after one of them changed. A window
that isn't in `editors`, like one a test makes, keeps its settings to itself.
"""
share_settings!(e) = begin
  any(o -> o === e, editors) || return
  for o in editors
    o === e || adopt_settings!(o, e)
  end
end

"Give `o` the settings of `e` that are different. The line at the top of `o`'s window stays there."
adopt_settings!(o, e) = begin
  changed = filter(name -> getfield(o, name) != getfield(e, name), SHARED)
  isempty(changed) && return o
  for name in changed
    setfield!(o, name, getfield(e, name))
    rerun!(o, name)   # a live block that reads the setting shows the new one
  end
  if :hidden in changed
    list_files!(o)
    # When the list of files is all that changed, the page's lines stay where they are
    changed == (:hidden,) && return (w = window_of(o); w === nothing || stale!(w); o)
  end
  # The width of a sidebar that's hidden changes nothing that the window shows, and the path in the top bar moves no lines
  o.panel || changed != (:side,) || return o
  changed == (:pinned,) && return (w = window_of(o); w === nothing || stale!(w); o)
  # Text of another size or width wraps again, and that moves the lines
  y = o.scroll.offset
  i = findfirst(it -> it.top + it.tall > y, o.layout)
  i === nothing || hold!(o, o.layout[i].first, o.layout[i].top - y)
  empty!(o.flows)
  w = window_of(o)
  w === nothing || stale!(w)
  o
end

# --- one table for the settings ---------------------------------------------------------
#
# Each setting that every window has the same is a row of SETTINGS. A row says
# which field of the editor holds the setting, what its line in the settings
# file is called, how the text of that line becomes a value, and how a value
# becomes text. It says whether the editor of a part of another page takes
# the setting from the page that shows it. And it says what the code of a page
# calls the setting, like `page_glide()` and `page_glide!(false)`.
#
# What reads the settings file and what writes it, SHARED, FOLLOWED and those
# names for a page's code all come from the rows. A new setting is a field of
# the Editor and a row here.

"""
A setting of the app that every window has the same. `field` is the field of
the editor that holds it.

`name` is what its line in the settings file is called, like glide in
`glide=true`. A setting with no name there is kept by `kept_text` and
`read_kept!`. `read` gives the value that the text after the = means, or
nothing for text that means none: the setting then stays as it is. `write`
gives the text of a value. `loaded` is what a window does when the file gave
it another value than it had.

`followed` is true when the editor of a part of another page takes the
setting from the page that shows it: see `follow_host!`.

`page` is what the code of a page calls the setting. That name gives
`shown(e)`, and notes that the live block that's running read each setting in
`reads`, so that the block runs again when one changes. The name with a ! after
it calls `set(e, takes(x))` with what the code gives it. See `sandbox`.
"""
struct Setting
  field::Symbol
  name::String
  read::Any
  write::Any
  loaded::Any
  followed::Bool
  page::Symbol
  reads::Tuple
  shown::Any
  set::Any
  takes::Any
end

Setting(field::Symbol, name="", read=nothing; write=string, loaded=nothing, followed=false, page=:none,
        reads=(field,), shown=e -> getfield(e, field), set=nothing, takes=identity) =
  Setting(field, name, read, write, loaded, followed, page, reads, shown, set, takes)

"True unless `text` says false: how the settings file is read for a setting that's on until you turn it off"
on_unless_false(text) = text != "false"

"True when `text` says true: how the settings file is read for a setting that's off until you turn it on"
off_unless_true(text) = text == "true"

"`x` when it's one of `choices`, or nothing"
one_of(x, choices) = x in choices ? x : nothing

"The number that `text` says, or the nearest of `least` and `most` when it's past one of them. It's nothing for text that's no number."
number_within(text, least, most) = (x = tryparse(Float64, text); x === nothing ? nothing : clamp(x, least, most))

"The weight of text that `text` says, like 300, or nothing for a weight that the page's text and code can't have"
weight_read(text) = (w = tryparse(Int, text); w !== nothing && 0 < w <= HEAVIEST ? w : nothing)

"A width in pixels as the settings file has it"
width_text(w) = string(w.value)

"When the top bar can hide. main.jl's BAR_HIDINGS has the settings page's name for each. It loads after this file, so the three are here too."
const HIDINGS = (:always, :full_screen, :never)

"Each setting that every window has the same, in the order of the settings file's lines"
const SETTINGS = Setting[
  # The page's colours. A page's code calls them "Sepia", "Paper" and "Night".
  Setting(:theme, "theme", text -> one_of(Symbol(text), THEME_ORDER), followed=true,
          page=:page_theme, shown=e -> titlecase(string(e.theme)), set=theme!, takes=name -> Symbol(lowercase(string(name)))),
  # The font of the page's text, by name
  Setting(:font, "font", text -> isempty(text) ? nothing : String(text), followed=true,
          page=:page_font, set=font!, takes=String),
  # How heavy the page's text is. A page's code calls a weight by its name in the font, like "Light".
  Setting(:weight, "weight", weight_read, followed=true,
          page=:page_weight, reads=(:font, :weight), shown=e -> nearest_weight(e.font, e.weight).label, set=weight!, takes=String),
  # The size of the page's text. A page's code has it in pixels.
  Setting(:zoom, "zoom", text -> number_within(text, 0.6, 2.5), followed=true,
          page=:page_text_size, shown=e -> TEXT_SIZE.value * e.zoom, set=text_size!),
  # The width of the page, in pixels. A live block that shows it isn't run again when it changes.
  Setting(:widest, "width", text -> (w = number_within(text, NARROWEST, WIDEST); w === nothing ? nothing : px(w)), write=width_text, followed=true,
          page=:page_width, reads=(), shown=e -> e.widest.value, set=page_width!),
  # The part of the page with the caret shows its markup
  Setting(:plain, "plain", off_unless_true),
  # The page checks its spelling
  Setting(:spelling, "spelling", on_unless_false, followed=true, page=:page_spelling, set=spelling!, takes=Bool),
  # The app gets a newer version of itself without being asked
  Setting(:updates, "updates", on_unless_false, page=:app_updates, set=updates!, takes=Bool),
  # A page is written to its file when its window stops being the front window
  Setting(:autosave, "autosave", off_unless_true, followed=true, page=:page_autosave, set=autosave!, takes=Bool),
  # The card of a link to a page shows the start of the page, while ⌘ is held
  Setting(:peeks, "peeks", on_unless_false, page=:page_peeks, set=peeks!, takes=Bool),
  # The agent that Ladder starts for a change or a question, by its name. A file that has an agent's old name means the agent.
  Setting(:ai, "agent", text -> (name = agent_renamed(text); k = findfirst(k -> k.name == name, AGENT_KINDS); k === nothing ? nothing : AGENT_KINDS[k].name),
          page=:page_agent, set=preferred_agent!, takes=String),
  # The caret moves to a new place in a short time, and doesn't jump there
  Setting(:glide, "glide", on_unless_false, followed=true, page=:page_glide, set=glide!, takes=Bool),
  # A line of a file of code that's too long for the window goes on under itself
  Setting(:wrap, "wrap", on_unless_false, followed=true, page=:code_wrap, set=wrap!, takes=Bool),
  # A file of code shows the number of each line
  Setting(:numbers, "numbers", on_unless_false, page=:code_numbers, set=numbers!, takes=Bool),
  # The line of a file of code that the caret is on is shaded
  Setting(:shade, "shade", off_unless_true, page=:code_shade, set=shade!, takes=Bool),
  # A block of changes shows the old lines at the left and the new lines at the right
  Setting(:beside, "beside", off_unless_true),
  # How many spaces one step of indentation is in code: 2 or 4
  Setting(:indent, "indent", text -> one_of(tryparse(Int, text), INDENTS), followed=true, page=:code_indent, set=indent_width!, takes=Int),
  # How big code is beside the page's text. A page's code has it in pixels: it grows and shrinks with the page's text.
  Setting(:code_scale, "code", text -> number_within(text, CODE_SCALES...), followed=true,
          page=:code_text_size, reads=(:code_scale, :zoom), shown=e -> code_size(e).value, set=code_size!),
  # The font of code. A font that's no longer on the Mac leaves code in the usual one. A page's code calls it by the name in the list of `code_fonts()`.
  Setting(:code_font, "codefont", text -> installed_weight(text, 400) > 0 ? String(text) : nothing, followed=true,
          page=:code_font, shown=e -> font_label(e.code_font), set=code_font!, takes=name -> font_family(String(name))),
  # How heavy code is, as the page's text has a weight
  Setting(:code_weight, "codeweight", weight_read, followed=true,
          page=:code_weight, reads=(:code_font, :code_weight), shown=e -> nearest_weight(e.code_font, e.code_weight).label, set=code_weight!, takes=String),
  # After how many characters a faint line goes down a file of code. 0 is no line.
  Setting(:guide, "guide", text -> one_of(tryparse(Int, text), GUIDES), page=:code_guide, set=guide!, takes=Int),
  # The bundle of key bindings, and the keys of each command that has other keys than the bundle's.
  # `kept_text` writes both at the end of the file, with a line for each command.
  Setting(:bundle, followed=true, page=:key_bundle, set=bundle!, takes=String),
  Setting(:rebound, followed=true),
  # How wide the sidebar is
  Setting(:side, "sidebar", text -> (w = number_within(text, num(PANEL_MIN), num(PANEL_MAX)); w === nothing ? nothing : px(round(w))), write=width_text),
  # The sidebar lists the hidden files too. It listed its folder before the settings were read, so it lists it again.
  Setting(:hidden, "hidden", off_unless_true, loaded=list_files!),
  # A page that has a panel at the right shows it
  Setting(:right, "right", on_unless_false),
  # You write the message of each commit, and the agent doesn't
  Setting(:own, "ownmessage", off_unless_true),
  # The path in the top bar is pinned open
  Setting(:pinned, "pinned", off_unless_true),
  # When the top bar hides until the mouse is at the top of the window. It was true or false before the bar could hide in full screen only.
  # A page's code calls each choice by its name on the settings page.
  Setting(:hide_bar, "hidebar", text -> one_of(text == "true" ? :always : text == "false" ? :never : Symbol(text), HIDINGS),
          page=:page_bar_hides, shown=e -> hiding_name(e.hide_bar), set=hide_bar!, takes=name -> hiding_named(String(name))),
]

"The settings that every window has the same: each is a field of the editor"
const SHARED = Tuple(s.field for s in SETTINGS)

"The settings that the editor of a part of another page takes from the page that shows it: see `follow_host!`"
const FOLLOWED = Tuple(s.field for s in SETTINGS if s.followed)

"Give `new`, the editor of a window that's about to open, each setting of `e` that every window has the same"
same_settings!(new, e) = (foreach(name -> setfield!(new, name, getfield(e, name)), SHARED); new)

"The setting whose line in the settings file is called `name`, or nothing when no row has that name"
setting_named(name) = (i = findfirst(s -> !isempty(s.name) && s.name == name, SETTINGS); i === nothing ? nothing : SETTINGS[i])

"Give `e` the value that `text` means for the setting `s`. Text that means none leaves the setting as it is."
read_setting!(e, s::Setting, text) = begin
  value = s.read(text)
  value === nothing && return e
  was = getfield(e, s.field)
  setproperty!(e, s.field, value)
  s.loaded === nothing || getfield(e, s.field) == was || s.loaded(e)
  e
end

# What the settings file keeps that's no row of SETTINGS: what isn't a field of
# the editor, and what takes more than one line. `kept_text` writes it and
# `read_kept!` reads it.

"""
The lines of the settings file that no row of SETTINGS makes: how wide the
page's card of agent mode is, the agents that you took out of the lists, the
model of each agent, the terminal's settings, the bundle of key bindings, and
a line for each command that has other keys than the bundle's, like
key.save=ctrl+s.
"""
kept_text(e) = begin
  changed = join(["key.$name=$(e.rebound[name])\n" for name in sort!(collect(keys(e.rebound)))])
  "pagecard=$(page_card_setting())\nagentshidden=$(join(sort!(collect(AGENTS_HIDDEN[])), ','))\nmodels=$(models_setting())\n$(term_settings_text())keys=$(e.bundle)\n$changed"
end

"Take the line of the settings file called `name`, when it's one of those that `kept_text` writes. Any other line is left out."
read_kept!(e, name, value) = begin
  if name == "pagecard"
    # How wide you made the page's card of agent mode. Nothing after the = means it has a page's shape.
    w = tryparse(Float64, value)
    PAGE_CARD_CHOSEN[] = w === nothing ? nothing : px(round(max(w, num(PAGE_CARD_NARROWEST))))
  elseif name == "agentshidden"
    # The agents that you took out of the lists, with commas between their names
    AGENTS_HIDDEN[] = Set(n for n in agent_renamed.(split(value, ',')) if any(k -> k.name == n, AGENT_KINDS))
  elseif name == "models"
    # The model of each agent that you chose last, like Claude:sonnet, with commas between them. An agent that has another name now has other models.
    MODELS_CHOSEN[] = Dict(String(a) => String(m) for (a, m) in (split(pair, ':', limit=2) for pair in split(value, ',') if occursin(':', pair)) if !isempty(m) && !haskey(AGENTS_RENAMED, a))
  elseif startswith(name, "term.")
    # A setting of the terminal, like term.caret=bar
    read_term_setting!(chopprefix(name, "term."), value)
  elseif name == "keys"
    any(b -> first(b) == value, BUNDLES) && (e.bundle = String(value))
  elseif startswith(name, "key.")
    # The shortcuts of one command. A window that has these already gets a new set, not a change to the one it shares.
    command = Symbol(chopprefix(name, "key."))
    haskey(COMMANDS, command) && (e.rebound = merge(e.rebound, Dict(command => written(read_shortcuts(value)))))
  end
  e
end

"The text of the settings file for the editor `e`: a line for each row of SETTINGS that has a name there, then the lines of `kept_text`"
settings_text(e) = join("$(s.name)=$(s.write(getfield(e, s.field)))\n" for s in SETTINGS if !isempty(s.name)) * kept_text(e)

"Give `e` the settings that were kept the last time one changed"
load_settings!(e) = begin
  isfile(settings_file()) || return e
  for line in eachline(settings_file())
    name, value = (split(line, '=', limit=2)..., "")[1:2]
    s = setting_named(name)
    s === nothing ? read_kept!(e, name, value) : read_setting!(e, s, value)
  end
  e
end

# The app was called Kaydown until 18 November 2026, and its folders in
# ~/Library had that name. The first time Ladder starts, it gives them its own
# name, so the settings and the Welcome pages stay. A folder that has the new
# name already stays as it is, and so does the old one.

"Give the app's folders in `home`'s Library the name Ladder, if they still have the old name Kaydown"
move_old_folders!(home=homedir()) =
  for parts in (("Application Support",), ("Caches",))
    old, new = joinpath(home, "Library", parts..., "Kaydown"), joinpath(home, "Library", parts..., "Ladder")
    (isdir(old) && !ispath(new)) || continue
    try
      mv(old, new)
    catch err
      @warn "Ladder couldn't give its folder its new name" old new exception=err
    end
  end

"""
Give the other windows the settings of `e`, and write them to their file if
this editor keeps them. An editor that's made for a test doesn't.
"""
save_settings!(e) = begin
  usual_zoom!(e)   # the bigger text of a slide is no setting
  share_settings!(e)
  e.remember || return
  try
    mkpath(dirname(settings_file()))
    write(settings_file(), settings_text(e))
  catch
    # A file that can't be written only means the settings last as long as the window
  end
  nothing
end
