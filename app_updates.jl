# The app's own updates, and its extensions' new code: what a window does about them in each frame, and what the settings page shows and does

@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "./update" => Update
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
@use "./live_view" reads!
@use "./design_view" unsaved_designs

export updates!, unsaved, extensions_tick!, extensions_news, extensions_act!, update_act!

# --- the app's own updates ------------------------------------------------------------------
#
# The Ladder app gets a newer version of itself while you work, and the new
# version takes the app's place when you quit. update.jl does the work, and
# says how. The settings page has a box that turns it off, a line that says how
# far an update has got, and a button to look for one now.
#
# The app gets the new code of its extensions from GitHub the same way, and the
# same box turns that off. The new code loads the next time that Ladder opens.
# The settings page has a line that says which extensions have new code, and a
# button that looks for it now or restarts Ladder to load it.

"Turn on or off whether the app gets a newer version, and its extensions' new code, without being asked"
updates!(e, on::Bool) = begin
  e.updates = on
  Update.own().auto = on
  Update.extensions().auto = on
  save_settings!(e)
  rerun!(e, :updates)
  e
end

"True when a page that's open in a window has changes that aren't in its file"
unsaved() = any(o -> dirty(o.buf) || any(dirty, values(o.buffers)) || !isempty(unsaved_designs(o)), editors)

"""
What happens to the app's update in each frame. Only a window of the app looks
for one: a window that a test makes doesn't. When an update gets further, the
blocks of the settings page that show it run again.
"""
update_tick!(e) = begin
  e.remember || return
  u = Update.own()
  u.auto = e.updates
  wait = Update.tick!(u)
  if get(e.nodes, :update_seen, -1) != u.changed
    e.nodes[:update_seen] = u.changed
    delete!(e.nodes, :update_held)
    rerun!(e, :update)
  end
  isfinite(wait) && redraw_in!(e, wait)   # while it checks or downloads, the window looks again soon
  extensions_tick!(e)
  nothing
end

"""
What happens to the extensions' new code in each frame, as `update_tick!` does
for the app. When it gets further, the block of the settings page that shows
it runs again.
"""
extensions_tick!(e) = begin
  x = Update.extensions()
  x.auto = e.updates
  wait = Update.tick!(x)
  if get(e.nodes, :extensions_seen, -1) != x.changed
    e.nodes[:extensions_seen] = x.changed
    delete!(e.nodes, :extensions_held)
    rerun!(e, :extensions)
  end
  isfinite(wait) && redraw_in!(e, wait)   # while it fetches, the window looks again soon
  nothing
end

"A sentence or two on the extensions' new code, for the settings page"
extensions_news(e) = begin
  reads!(e, :updates)
  reads!(e, :extensions)
  get(e.nodes, :extensions_held, false) && return "Save your changes first. A page has changes that aren't in its file, and a restart would lose them."
  Update.says(Update.extensions())
end

"""
Do what the settings page's button for the extensions offers: look for new
code, or restart Ladder to load it. A restart closes every window, each
extension moves up to its new code, and Ladder opens again. It doesn't happen
while a page has changes that aren't saved.
"""
extensions_act!(e) = begin
  x = Update.extensions()
  if Update.action(x) === :restart && unsaved()
    e.nodes[:extensions_held] = true
    return rerun!(e, :extensions)
  end
  Update.act!(x)
  rerun!(e, :extensions)
  x.again && foreach(o -> (w = window_of(o); w === nothing || close(w)), copy(editors))
  nothing
end

"A sentence or two on how far the app's update has got, for the settings page"
update_news(e) = begin
  reads!(e, :updates)
  reads!(e, :update)
  get(e.nodes, :update_held, false) && return "Save your changes first. A page has changes that aren't in its file, and a restart would lose them."
  Update.says(Update.own())
end

"""
Do what the button on the settings page offers: look for a newer version, get
it, or restart to use it. A restart closes every window, and the new version
opens once it's in the app's place. It doesn't happen while a page has changes
that aren't saved.
"""
update_act!(e) = begin
  u = Update.own()
  if Update.action(u) === :restart && unsaved()
    e.nodes[:update_held] = true
    return rerun!(e, :update)
  end
  Update.act!(u)
  rerun!(e, :update)
  u.again && foreach(o -> (w = window_of(o); w === nothing || close(w)), copy(editors))
  nothing
end
