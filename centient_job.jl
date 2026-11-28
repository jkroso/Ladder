# A job in Centient from the page: a project page asks the walkthrough service for its tasks

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" describe window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in! popup! close_popup!
@use "./markdown" words front_matter
@use "./blocks/sheet" shown
@use "./centient" => Centient
@use "github.com/jkroso/UI.jl/Interface/draw" Bubble
@use "github.com/jkroso/UI.jl/Interface/draw" popups
@use "./base" exports...
@use "./blocks/takeoff_view" exports...
@use "./window/fill_view" exports...
@use "./files/file_view" exports...
@use "./blocks/check_view" exports...
@use "./page/slides_view" exports...
@use "./page/cover_view" exports...
@use "./folders/blog_page" exports...
@use "./folders/git_page" exports...
@use "./code/levels_view" exports...
@use "./agent/window" exports...
@use "./agent/page" exports...
@use "./agent/pane" exports...
@use "./folders/news_page" exports...
@use "./window/showed_before" exports...
@use "./window/markdown_app" exports...
@use "./window/top_bar" exports...
@use "./page/editing" exports...
@use "./window/right_panel" exports...
@use "./term/terminal_view" term_shown
@use "./window/tabs" files_listed menu_w side_button side_least

export JOB_SHOWS, JobAsk, bar_row, bread_crumb, crumb_centred, hidden_button, history_buttons, job,
       job_args, job_part, job_tick!, job_words, making, matter_value, progress_address, said_face,
       said_part, JobState

# --- a job in Centient from the page ------------------------------------------------------
#
# A project page is one whose front matter has a `progress` line with a web
# address. The walkthrough service keeps the page's tasks at that address. For
# a project page, the top bar has a button that makes the page's job in
# Centient: Centient reads the tasks from the address and gives each trade a
# task. Centient needn't be open, and nothing waits for it. Words under the
# button say that Centient works, and then what it made or why it couldn't.
# They stay for a few seconds, and they're the button's tooltip after that.

const JOB_SHOWS = 8   # seconds that Centient's answer stays under the button

"What Ladder asked Centient to make from a page, and what the button says of it"
mutable struct JobAsk
  path::String      # the page's file
  request::Any      # what Centient was asked, or nothing once it has answered
  said::String      # what the button says
  wrong::Bool       # true when `said` is why Centient couldn't
  at::Float64       # when Centient was asked, and then when it answered
  shows::Bool       # true while the words are under the button
end

"What the front matter of `lines` sets `key` to, without quotes around it, or nothing if it has no such key"
matter_value(lines, key) = begin
  t = front_matter(lines)
  t == 0 && return nothing
  for (_, k, v) in matter_rows(lines, t)
    k == key && return String(strip(strip(v), ['"', '\'']))
  end
  nothing
end

"The web address of the page's tasks, from the `progress` line of its front matter, or nothing if the page isn't a project page"
progress_address(e) = begin
  url = matter_value(e.buf.lines, "progress")
  url !== nothing && startswith(url, r"https?://") ? url : nothing
end

"What Centient needs to make the page's job: the progress address, the page's first # heading, the property and the purpose from the front matter, and where the page's file is, which the job keeps as its PRD"
job_args(e) = begin
  b = e.buf
  args = Dict{String,Any}("progress" => progress_address(e))
  isempty(b.path) || (args["page"] = abspath(b.path))
  headings = outline(b)
  i = findfirst(h -> h.level == 1, headings)
  i === nothing || isempty(headings[i].title) || (args["title"] = headings[i].title)
  for key in ("property", "purpose")
    value = matter_value(b.lines, key)
    value === nothing || isempty(value) || (args[key] = value)
  end
  args
end

"What a window keeps of the job that Centient makes from a page"
@def mutable struct JobState
  ask::Union{Nothing,JobAsk} = nothing   # what Ladder last asked Centient to make, or nothing
end

"What Ladder asked Centient to make from the page that shows, or nothing"
job(e) = (j = state_of(e, JobState).ask; j !== nothing && j.path == e.buf.path ? j : nothing)

"True while Centient makes a job"
making(e) = (j = state_of(e, JobState).ask; j !== nothing && j.request !== nothing)

"""
True for a button of the top bar that does nothing now: the one that makes the
job, when the Mac has no Centient or Centient makes a job, the ones that
go back and forward, when they have no file to go to, and one that code from
the startup page added, when that code says so
"""
off(b::ToolButton) = (b.action == :job && (!Centient.available() || making(editor(b)))) ||
                     (b.action == :back && step_words(editor(b)) === nothing) ||
                     (b.action == :forward && step_words(editor(b), editor(b).ahead) === nothing) ||
                     (b.action in BLOG_ACTIONS && blog_off(editor(b), b.action)) ||
                     # A button that code from the startup page added says so itself
                     (haskey(BUTTONS, b.action) && BUTTONS[b.action].off(editor(b)))

"What the top bar shows for a project page: the button that makes the page's job in Centient"
job_part(e) = progress_address(e) === nothing ? () : (button(e, :job, "hammer"), Box(width(4px)))

"What the tooltip of the button that makes the job says: what the button does, or what happened when it did it"
job_tip(e) = begin
  Centient.available() || return "Centient isn't on this Mac"
  j = job(e)
  j === nothing ? "Make job in Centient" : j.said
end

"Ask Centient to make the page's job. Centient answers later, and `job_tick!` takes the answer."
make_job!(e) = begin
  (progress_address(e) === nothing || !Centient.available() || making(e)) && return
  state_of(e, JobState).ask = JobAsk(e.buf.path, Centient.ask("make_job_from_page", job_args(e)), "Making the job in Centient…", false, time(), false)
  nothing
end

"What to say of the job that Centient made, or that it had. `made` is Centient's answer."
job_words(made) = begin
  n(key) = (x = get(made, key, 0); x isa Real ? round(Int, x) : 0)
  some(k, thing) = "$k $thing$(k == 1 ? "" : "s")"
  title = string(something(get(made, "title", nothing), ""))
  if get(made, "existed", false) === true
    return n("added") > 0 ? "Centient added $(some(n("added"), "new task")) to the job $title." : "Centient has this job already: $title."
  end
  company = Centient.server.company
  "Centient has the job $title$(isempty(company) ? "" : " in $company"), with $(some(n("steps"), "task")) for $(some(n("tasks"), "trade"))."
end

"""
What happens to the page's job in each frame: Centient's answer is taken, and
the words about it show under the button while Centient works and for a few
seconds after it answers.
"""
job_tick!(e) = begin
  j = state_of(e, JobState).ask
  j === nothing && return
  r = j.request
  if r !== nothing
    Centient.check!()
    if Centient.finished(r)
      j.request, j.at = nothing, time()
      j.wrong = Centient.failed(r) || !(r.value isa AbstractDict)
      j.said = Centient.failed(r) ? r.problem : j.wrong ? "Centient gave an answer that Ladder can't read" : job_words(r.value)
    else
      redraw_in!(e, 0.1)   # while Centient works, the window looks again soon
    end
  end
  win, b = window_of(e), get(e.nodes, :job, nothing)
  (win === nothing || b === nothing) && return
  left = j.request === nothing ? JOB_SHOWS - (time() - j.at) : Inf
  if left > 0 && j.path == e.buf.path && progress_address(e) !== nothing
    # The words look as a tooltip does. They stay while the mouse moves, which a tooltip doesn't.
    popup!(win, Bubble(content=Box(padding(8px, 5px), label(j.said, 12px, color=TIP_INK)), target=b.rect),
           anchor=b.rect, placement=:bottom, gap=6px, key=:job, input=false)
    j.shows = true
    isfinite(left) && redraw_in!(e, left)   # to take them away
  elseif j.shows
    close_popup!(win, :job)
    j.shows = false
  end
  nothing
end

"""
The button beside the one that shows the sidebar. A click makes the sidebar
list the hidden files and folders too, the ones whose names start with a dot,
and another click leaves them out. Its eye has a line through it while they're
left out. It shows only while the sidebar lists files: a closed sidebar has none to
show, and nor has a list or a menu that code from the startup page shows in their place.
"""
hidden_button(e) = begin
  (e.panel && files_listed(e)) || return ()
  b = button(e, :hidden, "eye-slash")
  b.icon = e.hidden ? "eye" : "eye-slash"
  (b,)
end

"""
The buttons that go back to the file that showed before, and forward again.
They show only while the sidebar is open, at the right of the part of the top
bar that's over the sidebar.
"""
history_buttons(e) = e.panel || agent_shows(e) ? (button(e, :back, "arrow-left"), button(e, :forward, "arrow-right")) : ()   # in agent mode they're at the end of the agent's heading



# In agent mode the two ends of the bar lie over the dark panes, so they have the panes' colours. The middle is over the page's card.
# Over a web page the bar has the page's colours. See `bar_inks`.
describe(t::TopBar) = (inks = bar_inks(editor(t)); with_colours(() -> bar_row(t, inks), inks[3]))

bar_row(t::TopBar, inks=(nothing, nothing, nothing)) = begin
  e = editor(t)
  # While the page shows as slides or as an app, the bar is empty. It's still what you drag to move the window.
  (slideshow(e) === nothing && !as_app(e)) || return Row(width(grow=grow), height(TOPBAR_H), name="TopBar", offset_y=bar_top(e))
  b = e.buf
  # The buttons that code from the startup page adds for the page that shows, like the ones that answer an email,
  # and the ones of a page of a blog, which publish it
  more = (bar_parts(e)..., blog_part(e)...)
  checks = check_part(e)
  mode = mode_part(e)
  # A CSV file's table has the bar of a file that's only shown, with no lock: see "changing a CSV file"
  shown = readonly(b) || table_text(b)
  outside = shown ? outside_button(e) : ()
  # What a file that's only shown says of itself, like how many rows a CSV file has, can need more room than that.
  # The words move aside as the slider of the levels opens, so then they need its room too.
  grown = isempty(mode) ? 0px : slider_grown(e)
  said = shown && !isempty(b.about) ? spared_width(b.about, said_face()) + LOCK_W + 70px + grown : 0px
  side = max(isempty(more) && isempty(checks) ? 250px : 330px, said) + (isempty(mode) ? 0px : MODE_W)
  # What the page itself puts at the right end, like its buttons, has the room that it needs there, with the bar's
  # own parts. So a page's buttons never lie over the middle of the bar, which would take their clicks.
  own_ends = shown ? page_actions(e, page_object(e)) : ()
  isempty(own_ends) || (side = max(side, describe(Row(Alignment.Start, own_ends...), (9999px, 9999px)).width + 10px + said + LOCK_W +
                                         (isempty(mode) ? 0px : MODE_W) + (isempty(outside) ? 0px : 40px)))
  ended_rename!(e)
  # The two ends of the bar are as wide as each other, so the file's name is in the middle of the space beside
  # the sidebar. A window can be too narrow for that, with a wide sidebar or more buttons at its right end. Then the
  # left end gives up its room, so the right end stays in the window and the name keeps some room. With the
  # sidebar hidden, the left end keeps the room of its own two buttons. It always keeps the room that its
  # buttons need past the sidebar: while the sidebar slides open, it's narrower than its buttons.
  wide, _ = window_size(e)
  # Beside a panel at the right, the name is in the middle of the space between the sidebar and the panel. The
  # right end's buttons lie over the panel, so the right end needs room past the panel only for what the panel
  # can't hold, and then as much as the left end has.
  beside = right_view(e) === nothing ? 0px : right_w(e) * right_opened(e)
  wide -= beside
  side = max(side - beside, 0px)
  # While something fills the window, the sidebar isn't there. The bar has none of the sidebar's buttons
  # then, not the one that shows it either, and the file's name is in the middle of the window.
  full = filled(e)
  dark = agent_shows(e)
  showing = full ? 0.0 : dark ? 1.0 : opened(e)   # how far the sidebar shows, from 0 to 1. The agent's pane is always there.
  room = full ? 0px : side_w(e)      # how wide it is now. A side menu's compact form keeps some width while it's closed.
  # A side menu with a compact form is always there, so the bar's own button that shows and hides the sidebar goes.
  # The menu can have a button of its own in that place: see `side_button`.
  toggles = !full && side_least(e) == 0px
  own_button = full || toggles ? nothing : side_button(window_parts(e).side_menu)
  buttons = full ? () : ((toggles ? (button(e, :panel, "layout-sidebar"),) : own_button === nothing ? () : (own_button,))..., hidden_button(e)...)
  # The two arrows are at the sidebar's right edge, as far in as the right end of a row of its list. They
  # ride on that edge while the sidebar slides open, once it has passed the other buttons.
  arrows = full ? () : history_buttons(e)
  # Each button is 30px wide with 2px after it. The arrows have 8px after them, and so has the last
  # button when there are no arrows. The dot beside the sidebar's button has room of its own.
  need = mac_buttons_room(e) + 32px * length(buttons) + (isempty(arrows) ? 8px : 72px) + (toggles && waiting_dot(e) ? DOT_GAP + DOT_W : 0px)
  over = max(need, room)
  # Ladder's own name is in the middle of the bar, so the left end is as wide as the right. So is anything else
  # that says it's centred, like a picker a page puts there. A kind of folder's own path has all the room from the
  # buttons over the sidebar, so it can start at the page's left edge.
  # A page that shows the path itself, as a SolidCraft design does in its toolbar, runs up to the window's top. The
  # bar then has only its left end, so that the page has the room of the bar's middle and its right end.
  inpage = crumb_in_page(e)
  crumb = inpage ? nothing : bread_crumb(e, window_object(e))
  own = !inpage && !crumb_centred(crumb)
  left = own || inpage ? max(need - room, 0px) :
                         max(150px * (1 - showing), need - room, min(side, wide - room - side - TITLE_ROOM))
  bar_space(e).past_side = left   # the page that shows the path leaves this room at its top left: see `bar_corner`
  # The slider never pushes the right end out of a narrow window, so the ladder stays under the mouse. The words
  # before the slider lose their start then: see `said_part`.
  side = min(side, max(side - grown, wide - room - left))
  beside > 0px && (side = max(side, min(left, wide - room - left)))
  inpage || (bar_space(e).title = wide - room - left - side)   # the name is cut short to fit in it. In the page, the page says how much room it has.
  # The path that the file's name opens into goes when the middle of the bar shows something else
  !inpage && !(crumb isa Title) && (w = window_of(e); w !== nothing && any(p -> p.key == :title_trail, popups(w)) && close_popup!(w, :title_trail))
  # The top bar lies over the top of the sidebar. The file's name is in the
  # middle of the space beside the sidebar, so it moves as the sidebar slides.
  # In agent mode the agent's heading is over the agent's pane. So it starts after the bar's buttons, or at the
  # sidebar's edge when that's further right, with its logo over the left edge of the talk.
  before_head = dark ? max(0px, menu_w(e) + PANE_LEFT - 7px - mac_buttons_room(e) - 32px * length(buttons)) : 0px
  # Each part is described and drawn with its own colours. With none but the page's, the bar needs no marks.
  marked = any(!isnothing, inks)
  mark(p) = marked ? (ColourMark(palette=p),) : ()
  start = with_colours(inks[1]) do
    Row(fixed(left + room), height(grow=grow),
      # The close, minimise and zoom buttons sit over the first 84px. In full screen they're hidden, and the buttons slide left.
      Row(fixed(over), height(grow=grow), padding(0px, 8px, 0px, mac_buttons_room(e)), child_gap=2px,
        buttons..., (dark ? (Box(fixed(before_head), height(grow=grow)), pane_head(agent_pane(e), e)...) : (Box(width(grow=grow)),))..., arrows...))   # in agent mode, the heading of the agent's pane
  end
  # Over a page that shows the path itself, the bar ends with its left end. The page under the rest takes the clicks there.
  inpage && return Row(fixed(left + room), height(TOPBAR_H), name="TopBar", offset_y=bar_top(e), mark(inks[1])..., start, mark(nothing)...)
  Row(width(grow=grow), height(TOPBAR_H), name="TopBar", offset_y=bar_top(e),
    mark(inks[1])...,
    start,
    mark(inks[2])...,
    with_colours(() -> Box(width(grow=grow), height(grow=grow), clip=true, crumb), inks[2]),
    mark(inks[3])...,
    Row(fixed(side + beside), height(grow=grow), justify=Alignment.End, padding(0px, 10px, 0px, 0px),
      # A file that's only shown has no words to count. The bar has a lock, after what the file says of itself. A file with levels
      # has the snake or the ladder too. It's after the words, which are longer at one level than at another,
      # so that it stays where it is, under the mouse, when a click on its slider changes the level. The
      # slider opens out to the left, and the parts before it move aside to make room.
      # The words have the room that the picture or the slider, the button after it and the edge leave them.
      # What covers the page's whole space, like a desktop, is no file that's only shown, so the bar says nothing of it.
      # Nor does it say anything when the window shows no file.
      # A folder of a blog that shows only its list has the blog's buttons in place of the words, and the
      # front page of a folder of news has its buttons: Interests and the one that gets the news
      # A page that has a panel at the right has the button that hides it, at the end
      (page_covered(e) || nofile(e) ? right_part(e) :
       readonly(b) && (page_object(e) isa BlogFolder || page_object(e) isa NewsFolder) ? (more..., mode..., outside...) :
       shown ? (own_ends..., (isempty(b.about) ? () : (said_part(b.about, side - LOCK_W - (isempty(outside) ? 0px : 40px) - (isempty(mode) ? 0px : MODE_W + grown)),))...,
                      (term_shown(e) || chat_shown(e) || !(readonly(b) || b.fixed) || !shows_lock(e, page_object(e)) ? () : (lock_part(e),))...,   # a terminal is yours to type in, and so are a session and a CSV file
                      mode...,
                      outside...,
                      right_part(e)...) :   # as a folder in a repository has git's panel
                     (more..., job_part(e)..., agent_part(e)..., checks..., diff_part(e)..., commit_part(e)..., mode...,
                      # A page that's never changed has a lock at the end
                      (b.fixed ? (lock_part(e),) : ())...,
                      # In agent mode, the button that hides the outline is at the end
                      (agent_shows(e) ? right_part(e) : ())...))...),
    mark(nothing)...)
end

"""
What the middle of the top bar shows while the window is about `o`: a node.
Ladder's own is the name of the file, which opens into the file's path while
the mouse is over it. A kind of folder has a method of this to show its own
path there: `bread_crumb(e, d)` for the folder, and `bread_crumb(e, d, o)`
for each thing `o` that it holds. Its room starts where the buttons over the
sidebar end, which is the sidebar's edge while the sidebar is open, and ends
at the buttons of the bar's right end. `bar_space(e).title` is how wide
that was in the last frame. What a kind of folder shows there starts at the
page's left edge, unless `crumb_centred` says it stays in the middle.
"""
bread_crumb(e, o) = bread_crumb(e, o.parent, o)
bread_crumb(e, ::Nothing) = bread_crumb(e, nothing, nothing)
bread_crumb(e, d, o) = node!(Title, e, :title)

"True when `crumb` stays in the middle of the top bar, with the two ends as wide as each other. The file's name does."
crumb_centred(crumb) = crumb isa Title

"The face of what a file that's only shown says of itself, in the top bar"
said_face() = Face(SANS, "", 12px, colours.dim, false)

"""
What a file that's only shown says of itself, for the top bar, in `room` at
most. With less room than the words need, their start is cut off. That
happens in a narrow window, when the slider of the levels takes their room as
it opens.
"""
said_part(words, room) = begin
  # A character that the font lacks is in a font that has it, like the ✳ that starts Claude Code's title
  tag = Box(height(28px), padding(8px, 0px), Row(Alignment.Center, spared(words, said_face())...))
  wide = spared_width(words, said_face()) + 16px
  wide <= room && return tag
  room = max(room, 0px)
  Row(fixed(room), height(28px), Alignment.Start, clip=true, Box(Alignment.Start, offset_x=room - wide, Row(fixed(wide), height(28px), tag)))
end
