# The settings, and the window and the pages that show them

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

export SETTINGS_DROP, SETTINGS_SIZE, adopt_settings!, pages_dir, settings_dir, settings_editor,
       share_settings!

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
  foreach(name -> setfield!(s, name, getfield(e, name)), SHARED)
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
  i === nothing || (o.nodes[:hold] = (o.layout[i].first, o.layout[i].top - y))
  empty!(o.flows)
  w = window_of(o)
  w === nothing || stale!(w)
  o
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
    # After the bundle of key bindings comes a line for each command that has other keys than the bundle's, like key.save=ctrl+s
    changed = join(["key.$name=$(e.rebound[name])\n" for name in sort!(collect(keys(e.rebound)))])
    write(settings_file(), "theme=$(e.theme)\nfont=$(e.font)\nweight=$(e.weight)\nzoom=$(e.zoom)\nwidth=$(e.widest.value)\nplain=$(e.plain)\nspelling=$(e.spelling)\nupdates=$(e.updates)\nautosave=$(e.autosave)\npeeks=$(e.peeks)\nagent=$(e.ai)\nglide=$(e.glide)\nwrap=$(e.wrap)\nnumbers=$(e.numbers)\nshade=$(e.shade)\nbeside=$(e.beside)\nindent=$(e.indent)\ncode=$(e.code_scale)\ncodefont=$(e.code_font)\ncodeweight=$(e.code_weight)\nguide=$(e.guide)\nsidebar=$(e.side.value)\nhidden=$(e.hidden)\nright=$(e.right)\nownmessage=$(e.own)\npinned=$(e.pinned)\nhidebar=$(e.hide_bar)\npagecard=$(page_card_setting())\nagentshidden=$(join(sort!(collect(AGENTS_HIDDEN[])), ','))\nmodels=$(models_setting())\n$(term_settings_text())keys=$(e.bundle)\n$changed")
  catch
    # A file that can't be written only means the settings last as long as the window
  end
  nothing
end
