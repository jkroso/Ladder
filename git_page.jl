# A folder with a git repository in it: git's panel, push and pull, a commit's page, the Commit button, and what changed in the file that shows
#
# A folder with a `.git` in it is the top folder of a repository, and Ladder
# asks git about it (see git.jl). Ladder only reads from it, apart from the
# commit of the file that shows (see "a commit of the file that shows"), and
# the Pull and Push buttons of git's panel (see "push and pull").
#
#   - In the sidebar, each file that has changes since the last commit has a
#     letter after its name: M for changed lines, A for a file that the next
#     commit adds, U for a file that git doesn't keep yet, R for a new name,
#     and ! for a file that a merge left in two forms. A folder with such a
#     file in it has a dot.
#   - A click on the repository's name in the trail at the top of the
#     sidebar shows the repository's page.
#   - The repository's page has the table of the folders and the files in
#     its top folder, as any folder's page has, each with its mark. Git's
#     panel at the right of the window has the branch, the files that have
#     changes, and the last commits. A click on a folder opens it in the page,
#     and a click on a file shows it. The button at the right end of the top
#     bar hides git's panel, and shows it again.
#   - In the list of a folder that holds repositories, each one has its
#     branch after its name, and how many of its files have changes.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl/skia" rectangle
@use Skia
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/Specific" skia_cap_height
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI WrapMode describe reuse! window_of focus handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor redraw_in! rect popup! close_popup! placed! with_clip clipboard!
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "./markdown" words
@use "./highlight" tokens left_open
@use "./sheet" parts shown
@use "./spreadsheet" moved
@use "./merge" changes
@use "./changes" => Diffs
@use "./git" => Git
@use "./zip" => Zips
@use "github.com/jkroso/UI.jl/Interface/draw" popups
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS FSObject AbstractDirectory
@use Colors: @colorant_str, RGBA
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
@use "./git_marks" exports...
@use "./changes_view" exports...
@use "./sketch_view" exports...
@use "./julia_levels" exports...
@use "./file_view" exports...
@use "./sheet_view" exports...
@use "./live_view" exports...
@use "./slides_view" exports...
@use "./folder_table" exports...
@use "./blog_page" exports...

export GitDirectory, RepoView, GitPanel, follow_words, GIT_RUNS, send_command, SENDING_WORDS, push_or_pull!,
       diverged, commits_words, git_reason, clashing_files, git_said, git_run_tick!, send_buttons, PULL_LIST,
       PULL_LIST_W, PULL_WAYS, PullMore, PullList, PullWay, PullEnvelope, pull_list_open, pull_target,
       open_pull_list!, apart_words, pull_way_words, sending_words, keep_saying!, send_from_palette!,
       push_branch!, pull_branch!, merge_branch!, rebase_branch!, FileTick, committing, file_tick, tick_file!,
       commit_button, LOG_LEAST, tree_of_commits, OPEN_MOST, OPEN_ALL, CommitView, shown_commit, show_commit!,
       close_commit!, CommitLine, LANE_W, TREE_X, COMMIT_PAD, REF_H, dot_y, tree_colour, ref_boxes, bent_line,
       commit_line, file_tally, open_first!, file_changes, message_by, message_lines, commit_when, touched_words,
       commit_file, commit_change, unsaved_in, with_windows, commit_file!, commit_part, MESSAGE_COMMAND,
       MOST_DIFF, message_command, recent_messages, message_prompt, talk_prompt, read_message, clean_message, text_diff, committed_text,
       with_changes, commit_now!, repo_of, save_for_commit!, ticked_text, commit_scope!, commit_all_files!,
       commit_staged_files!, commit_ticked!, commit_tick!, commit_staged!, commit_all!, commit_text!,
       choosing, choose_changes!, tick_key, ticked, TickChange, CommitMore, COMMIT_LIST, COMMIT_WAYS,
       COMMIT_LIST_W, COMMIT_GAP, COMMIT_ROUND, CommitList, CommitWay, OwnMessage, commit_list_open,
       commit_target, open_commit_list!, CommitEnvelope, commit_envelope, draw_envelope, way_words,
       switch_look, diffing, toggle_diff!, show_changes!, change_span, go_change!, change_after, step_change!,
       next_change!, previous_change!, step_tip, COMMITTED, committed_lines, diff_now, gone_h, inline_diff!,
       gone_now, gone_rows, gone_under, gone_over, is_new, tint_new, draw_diff_bars, put_change_back!,
       PutBack, put_back_over, diff_part

"A folder that git keeps: the top folder of a repository, or a folder in one"
@def struct GitDirectory <: AbstractDirectory end

# A folder in a repository is in the repository too, unless it has a kind of its own
FS.kind(::GitDirectory, path::FSPath) = (k = folder_kind(path); k === FS.Directory ? GitDirectory : k)

push!(BLOCK_ICONS, "git", "arrow-up", "arrow-down")

entry_marks(e, o::GitDirectory) = git_marks(e, o)
entry_marks(e, ::GitDirectory, o::FSObject) = git_marks(e, o)

"Show the folder or the file at `path` in the page, like the page of a repository. The sidebar goes on with the folder that it lists."
show_beside!(e, path) = begin
  folder = e.folder
  open!(e, path)
  e.folder == folder || go_folder!(e, folder)
  e
end

"""
What the page shows of the top folder of a repository: the table of the
folders and the files in it, as a folder's page has it, each with git's mark.
What git says of the repository is in git's panel at the right of the window:
see `GitPanel`.
"""
@def mutable struct RepoView <: SemanticUI
  path::String = ""
  scroll::Scroll = Scroll(width(grow=grow), height(grow=grow), scrollbar_inset=0px)   # its scrollbar is at the page's right edge, as the editor's is
end

"The top folder of the repository that `d` is in: `d` itself, or a folder over it. \"\" when git no longer keeps it."
repo_top(d::GitDirectory) = (path = string(d.path); Git.istop(path) ? path : git_top(path))

"True when the page of `d` is the page of its repository's top folder, or shows a commit of its repository"
own_git_page(e, d::GitDirectory) = (root = repo_top(d); !isempty(root) && (root == string(d.path) || !isempty(shown_commit(e, root))))

page_view(e, d::GitDirectory) = begin
  path, root = string(d.path), repo_top(d)
  isempty(root) && return nothing
  # A click on a commit in git's panel shows the commit in place of the files: see "a commit's page".
  # A folder in the repository shows it too, since it has the same panel.
  isempty(shown_commit(e, root)) || return e.nodes[(:commit, root)]
  # A folder in the repository has the page of any folder, with git's marks in its table
  path == root ? node!(() -> RepoView(path=path), e, (:repo, path)) : nothing
end
# The page of a repository covers the page's space, so git's panel has the room at its right
page_fills(e, d::GitDirectory) = own_git_page(e, d)
page_covers(e, d::GitDirectory) = own_git_page(e, d)
# A folder in the repository has the panel of its repository, as its top folder has
page_side(e, d::GitDirectory) = (root = repo_top(d); isempty(root) ? nothing : node!(() -> GitPanel(path=root), e, (:git_panel, root)))
side_name(e, ::GitDirectory) = "git's panel"
# A window that's opened on a repository shows its first page of text, which is often its Readme
page_first(e, ::GitDirectory) = false

push!(BLOCK_ICONS, "layout-sidebar-reverse")
works_here(e, ::Val{:right_panel}) = right_view(e) !== nothing

"""
How many folders and files the table `t`, a `FolderTable`, lists, in words,
and what the folder holds, once that's known. The type is defined further on,
with the table.
"""
holds_words(t) = begin
  folders = count(it -> it.folder, t.items)
  files = length(t.items) - folders
  parts = String[]
  folders > 0 && push!(parts, folders == 1 ? "1 folder" : "$(commas(folders)) folders")
  files > 0 && push!(parts, files == 1 ? "1 file" : "$(commas(files)) files")
  isempty(parts) && return "Empty"
  t.bytes >= 0 && push!(parts, Zips.size_words(t.bytes))
  join(parts, "  ·  ")
end

# The page has its own scroll, since it covers the page's space to leave git's panel the room at its right
describe(v::RepoView) = begin
  e = editor(v)
  t = folder_table!(e, v, v.path)
  folder_items!(e, t)   # the line under the name says what the table holds
  reuse!(v.scroll, Row(width(grow=grow), Alignment.Start, justify=Alignment.Center, padding(PAGE_TOP, PAGE_X, PAGE_BOTTOM, PAGE_X),
    Column(width(grow=grow, max=e.widest * e.zoom), Alignment.Start, name="Repository",
      page_title("git", basename(v.path), holds_words(t)),
      t)))
end

cursor(::RepoView) = :arrow

# --- git's panel ---------------------------------------------------------------------------
#
# Beside the page of a repository, the panel at the right of the window has
# what git says: the branch and the branch that it follows, the files that
# have changes, and the last commits. A click on a file shows it, with what
# changed in it marked as the diff button marks it, from its first change. The button
# at the right end of the top bar hides the panel: see "the panel at the right".

"What git's panel beside the page of a repository shows: the branch, the files that have changes, and the last commits"
@def mutable struct GitPanel <: SemanticUI
  path::String = ""
  rows::Dict{Any,PageRow} = Dict{Any,PageRow}()
  scroll::Scroll = Scroll(width(grow=grow), height(grow=grow))
end

"What git's panel says under the branch's name, in words: the branch that it follows. The Pull and Push buttons say how many commits there are to pull and to push."
follow_words(s) = !s.known ? "Asking git…" : isempty(s.follows) ? "Follows no other branch" : "Follows $(s.follows)"

# --- push and pull -------------------------------------------------------------------------
#
# The Pull and Push buttons at the right of the branch's name in git's panel.
# Push sends the branch's new commits to the branch that it follows, like
# origin/main. A branch that follows none goes to origin as a branch of the
# same name, and follows it from then on. Pull brings the new commits of the
# branch that it follows, and moves the branch on to them. Each button has the
# number of commits that it would bring or send after its word.
#
# When each of the two branches has commits that the other hasn't, Pull can't
# just move the branch on. An arrow at its right then shows a list of the ways
# to join them, and a click on Pull shows it too:
#
#   - Merge: a new commit joins the other branch's commits to this one's.
#   - Rebase: git makes this branch's commits again, after the other's.
#
# When the two change the same lines of a file, git can't join them by itself.
# Ladder then undoes what git started, so nothing changes, and says which files
# those are. git doesn't rebase while a file has changes that aren't committed,
# and Ladder doesn't put them away for it, since another program can be
# writing to those files.
#
# git runs while the window draws, and the button says "Pushing…" or
# "Pulling…" until it ends. Then Ladder says what came of it under the top bar.
# git never asks for a password here (see `Git.start`): with none to hand, it fails.

"The push, the pull, the merge or the rebase that runs in each repository, by the repository's top folder"
const GIT_RUNS = Dict{String,Any}()

"What git runs for each of them, given what git says `s` of the repository"
send_command(what, s) =
  what == :pull ? `pull --ff-only` :
  what == :merge ? `pull --no-rebase --no-edit` :
  what == :rebase ? `pull --rebase` :
  isempty(s.follows) ? `push -u origin HEAD` : `push`

"What the Pull or the Push button says while git does `what`"
const SENDING_WORDS = Dict(:pull => "Pulling…", :merge => "Merging…", :rebase => "Rebasing…", :push => "Pushing…")

"""
Start git's push (`what` is :push), pull (:pull), merge (:merge) or rebase
(:rebase) in the repository at `root`, for the window `e`. One runs at a time
in a repository.
"""
push_or_pull!(e, root, what) = begin
  haskey(GIT_RUNS, root) && return e
  s = Git.state(root)
  job = try Git.start(root, send_command(what, s)) catch; return say_result!(e, "git didn't start.") end
  GIT_RUNS[root] = (what=what, run=job, e=e, since=time(), branch=s.branch, follows=s.follows)
  redraw_in!(e, 0)
  e
end

"True when the branch and the branch that it follows each have commits that the other hasn't, as git last heard"
diverged(s) = s.known && !isempty(s.follows) && s.ahead > 0 && s.behind > 0

"`n` commits, in words"
commits_words(n) = n == 1 ? "1 commit" : "$n commits"

"Why git didn't do it, from what it printed `said`: its first error, or its last line"
git_reason(said) = begin
  lines = filter(l -> !isempty(l), strip.(split(said, '\n')))
  k = findfirst(l -> startswith(l, "fatal:") || startswith(l, "error:"), lines)
  k === nothing ? (isempty(lines) ? "it gave no reason" : String(last(lines))) : String(strip(split(lines[k], ':', limit=2)[2]))
end

"The files that a merge or a rebase found changed in both branches, from what git printed `said`"
clashing_files(said) = unique([String(m[1]) for m in eachmatch(r"CONFLICT \([^)]*\): (?:Merge conflict in )?(\S+)", said)])

"What Ladder says when the run `r` ends: `done` is whether git did it, and `said` is what git printed"
git_said(r, done, said) = begin
  there = isempty(r.follows) ? "origin" : r.follows
  if r.what == :push
    done && occursin("Everything up-to-date", said) && return "$there already has every commit of $(r.branch)."
    done && return "Pushed $(r.branch) to $there."
    occursin("does not appear to be a git repository", said) && return "This repository has no remote called origin, so Ladder has nowhere to push."
    occursin("[rejected]", said) && return "$there has commits that $(r.branch) hasn't got, so git didn't push. Pull them first."
    return "git couldn't push: " * git_reason(said)
  end
  done && occursin(r"Already up.to.date", said) && return "$(r.branch) already has every commit of $there."
  done && r.what == :merge && return "Merged $there into $(r.branch)."
  done && r.what == :rebase && return "Rebased $(r.branch) onto $there."
  done && return "Pulled the new commits of $there into $(r.branch)."
  occursin("Not possible to fast-forward", said) &&
    return "$(r.branch) and $there each have commits that the other hasn't, so git didn't pull. To join them, click the arrow at the right of Pull, or run Merge or Rebase in the command palette."
  occursin("would be overwritten", said) &&
    return "The new commits change files that have changes you haven't committed, so git didn't pull. Commit those changes first."
  occursin("cannot pull with rebase", said) &&
    return "git doesn't rebase while files have changes that aren't committed, so nothing changed. Commit them, or merge."
  if occursin("CONFLICT", said)
    files = clashing_files(said)
    which = isempty(files) ? "the same files" : length(files) == 1 ? only(files) : join(files[1:end-1], ", ") * " and " * files[end]
    return "$(r.branch) and $there change the same lines of $which, so Ladder undid the $(r.what). Nothing changed."
  end
  "git couldn't $(r.what): " * git_reason(said)
end

"Say what came of each run of git that has ended. Each window does this in each frame, and draws again while git runs."
git_run_tick!(e) = for (root, r) in collect(GIT_RUNS)
  p, out = r.run
  late = time() - r.since > PUSH_LIMIT
  if process_running(p) && !late
    # A run from the palette says what it does under the top bar until it ends, since git's panel may not show
    words = get(r, :words, "")
    isempty(words) || keep_saying!(r.e, words)
    redraw_in!(e, 0.1)
    continue
  end
  process_running(p) && kill(p)
  wait(p)   # the last of what git printed can still be on its way
  said = String(take!(out))
  # A merge or a rebase that stopped at lines that both branches change goes back to where it started
  !late && !success(p) && r.what in (:merge, :rebase) && occursin("CONFLICT", said) &&
    Git.act(root, r.what == :merge ? `merge --abort` : `rebase --abort`)
  delete!(GIT_RUNS, root)
  Git.forget!()   # git's panel asks git again, for the commits to push and to pull
  words = late ? "git didn't finish in $(round(Int, PUSH_LIMIT)) seconds, so Ladder stopped it." : git_said(r, success(p), said)
  say_result!(r.e, words)
  r.e === e || redraw_in!(e, 0)
end

each_frame!(git_run_tick!)

"""
The Pull and Push buttons of git's panel for the repository at `root`, where
git says `s` of it. Each has the number of commits that it would bring or send
after its word, when there are any. The commits to pull are the ones that git
saw when it last fetched: Pull fetches before it pulls. While the two branches
have gone apart, Pull has an arrow at its right, and the two are one tab of
the list of the ways to join them while it shows.
"""
send_buttons(e, root, s) = begin
  r = get(GIT_RUNS, root, nothing)
  apart = diverged(s)
  button(what, icon, words; act=_ -> push_or_pull!(e, root, what), off=false) = begin
    b = node!(PageButton, e, (:git_button, root, what))
    b.act, b.icon = act, icon
    running = r !== nothing && (r.what == what || (what == :pull && r.what in (:merge, :rebase)))
    b.words = running ? SENDING_WORDS[r.what] : words
    b.off = off || r !== nothing || !s.known
    b
  end
  counted(word, n) = n > 0 ? "$word $n" : word
  # With no branch to follow, there's nothing to pull from
  pull = button(:pull, "arrow-down", counted("Pull", s.behind), off=isempty(s.follows),
                act=apart ? (w -> open_pull_list!(e, w, root)) : (_ -> push_or_pull!(e, root, :pull)))
  showing = apart && pull_list_open(e)
  tab = !apart ? pull :
    Row(Alignment.Center, child_gap=2px, radius(px(COMMIT_ROUND), px(COMMIT_ROUND), 0px, 0px),
        background(showing ? found_colours().frame : clear),
      pull, node!(() -> PullMore(root=root), e, (:pull_more, root)))
  Row(child_gap=6px, tab, button(:push, "arrow-up", counted("Push", s.ahead)))
end

const PULL_LIST = :pull_list   # the key of the popup with the ways to join the two branches
const PULL_LIST_W = 360px       # how wide it is
const PULL_WAYS = (:merge, :rebase)

"The arrow at the right of the Pull button while the two branches have gone apart: a click shows the ways to join them"
@def mutable struct PullMore <: SemanticUI
  root::String = ""
end

"The list of the ways to join the two branches, under the Pull button"
@def mutable struct PullList <: SemanticUI
  root::String = ""
end

"A row of that list, that joins the two branches one way"
@def mutable struct PullWay <: SemanticUI
  root::String = ""
  way::Symbol = :merge
end

"What draws the envelope of that list, under its rows. It's as big as the list."
@def mutable struct PullEnvelope <: SemanticUI
  root::String = ""
end

describe(m::PullMore) =
  Box(width(20px), height(28px), radius(6px), Alignment.Center, name="PullMore",
      background(haskey(GIT_RUNS, m.root) ? clear : ishovered(m) ? colours.active : colours.hover),
    Icon("chevron-down", size=10px, color=colours.dim))

cursor(m::PullMore) = haskey(GIT_RUNS, m.root) ? :arrow : :hand
onkey(m::PullMore, ev::KeyPress{Keys.mouse_left}) = (haskey(GIT_RUNS, m.root) || open_pull_list!(editor(m), ev.window, m.root); handled)

"True while the list of the ways to join the two branches shows"
pull_list_open(e) = (w = window_of(e); w !== nothing && any(p -> p.key == PULL_LIST, popups(w)))

"Where the Pull button and its arrow are in the window, as one rectangle in px, or nothing before both are drawn"
pull_target(e, root) = begin
  b, m = get(e.nodes, (:git_button, root, :pull), nothing), get(e.nodes, (:pull_more, root), nothing)
  (b === nothing || m === nothing) && return nothing
  rb, rm = rect(b), rect(m)
  (rb === nothing || rm === nothing) && return nothing
  (x=num(rb.left), y=num(rb.top), w=num(rm.left + rm.width - rb.left), h=num(rb.height))
end

"Show the ways to join the two branches of the repository at `root` under the Pull button, or take them away when they show"
open_pull_list!(e, w, root) = begin
  pull_list_open(e) && return (close_popup!(w, PULL_LIST); redraw_in!(e, 0); handled)
  t = pull_target(e, root)
  t === nothing && return handled
  list = node!(PullList, e, :pull_list)
  list.root = root
  # The list's right edge is in line with the arrow's, so the outline goes straight down that side
  anchor = (px(t.x + t.w) - PULL_LIST_W, px(t.y), PULL_LIST_W, px(t.h))
  popup!(w, list, anchor=anchor, placement=:below, gap=px(COMMIT_GAP), width=PULL_LIST_W, key=PULL_LIST, theme=component_theme(e.zoom))
  redraw_in!(e, 0)   # the buttons take the list's colour
  handled
end

"What the list says over its rows: the commits that each branch has and the other hasn't"
apart_words(s) = "$(s.branch) has $(commits_words(s.ahead)) that $(s.follows) hasn't got, and $(s.follows) has $(s.behind) that $(s.branch) hasn't got."

describe(l::PullList) = begin
  e = editor(l)
  s = Git.state(l.root)
  ways = [node!(() -> PullWay(root=l.root, way=w), e, (:pull_way, l.root, w)) for w in PULL_WAYS]
  # The envelope is under the rows, with its colour, its line and its shadow
  Stack(width(grow=grow), Alignment.Start, name="PullList",
    node!(() -> PullEnvelope(root=l.root), e, (:pull_envelope, l.root)),
    Box(width(grow=grow), padding(6px),
      Column(width(grow=grow), Alignment.Start, child_gap=2px,
        Box(width(grow=grow), Alignment.Start, padding(8px, 6px, 8px, 8px),
          Text(apart_words(s), size=12px, family=SANS, color=found_colours().dim, wrap=WrapMode.words)),
        ways...)))
end

describe(::PullEnvelope) = Box(width(grow=grow), height(grow=grow), name="Envelope")
draw(ctx, size, ui::ConcreteRect, l::PullEnvelope) = (t = pull_target(editor(l), l.root); t === nothing || draw_envelope(ctx, ui, t); nothing)

"What the row of the way `r` says, and the words at its right, which say what it does to the commits"
pull_way_words(r::PullWay) = begin
  s = Git.state(r.root)
  r.way == :merge ? ("Merge $(s.follows) into $(s.branch)", "adds a commit") :
                    ("Rebase $(s.branch) onto $(s.follows)", "rewrites $(commits_words(s.ahead))")
end

describe(r::PullWay) = begin
  words, note = pull_way_words(r)
  float_row(words, note, picked=ishovered(r))
end
cursor(::PullWay) = :hand

onkey(r::PullWay, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(r)
  close_popup!(ev.window, PULL_LIST)
  push_or_pull!(e, r.root, r.way)
  handled
end

# --- push and pull in the command palette ----------------------------------------------------
#
# The command palette has Push and Pull while the file or the folder that the
# window shows is in a git repository. They do what the buttons of git's panel
# do, in that repository, so they work on a page where the panel doesn't show.
# While each branch has commits that the other hasn't, the palette has Merge
# and Rebase too: the ways to join them that the list under Pull has.
#
# Git's panel may not be in sight, so while git runs, the words under the top
# bar say what it does, like "Pushing main to origin/main…". When git ends,
# they say what came of it, as they do for the buttons.

"What the window says under the top bar while git does `what` in a repository where git says `s`"
sending_words(what, s) = begin
  s.known || return SENDING_WORDS[what]
  there = isempty(s.follows) ? "origin" : s.follows
  what == :push ? "Pushing $(s.branch) to $there…" :
  what == :merge ? "Merging $there into $(s.branch)…" :
  what == :rebase ? "Rebasing $(s.branch) onto $there…" :
  "Pulling the new commits of $there into $(s.branch)…"
end

"Say `words` under the top bar of `e` again when they're still there, so that they stay while something takes long"
keep_saying!(e, words) = begin
  said = get(e.nodes, :result, nothing)
  (said === nothing || said[1] != words || time() - said[2] > 2) && (e.nodes[:result] = (words, time()))
  nothing
end

"""
Start git's push (`what` is :push), pull (:pull), merge (:merge) or rebase
(:rebase) in the repository of what the window `e` shows, as the buttons of
git's panel do. The words under the top bar say what git does until it ends.
"""
send_from_palette!(e, what) = begin
  root = repo_of(e)
  isempty(root) && error("git doesn't keep $(basename(e.buf.path))")
  r = get(GIT_RUNS, root, nothing)
  r === nothing || error("git hasn't finished the $(r.what) that it's doing in this repository")
  s = Git.state(root)
  what != :push && s.known && isempty(s.follows) && error("$(s.branch) follows no branch, so there's nothing to pull")
  push_or_pull!(e, root, what)
  haskey(GIT_RUNS, root) || return nothing   # git didn't start, and Ladder said so
  words = sending_words(what, s)
  GIT_RUNS[root] = merge(GIT_RUNS[root], (words=words,))
  say_result!(e, words)
  nothing
end

"Send the branch's new commits to the branch that it follows, like origin/main"
push_branch!(e) = send_from_palette!(e, :push)
"Bring the new commits of the branch that this one follows, like origin/main"
pull_branch!(e) = send_from_palette!(e, :pull)
"Pull the commits of the branch that this one follows, and join the two with a new commit"
merge_branch!(e) = send_from_palette!(e, :merge)
"Pull the commits of the branch that this one follows, and make this branch's own commits again after them"
rebase_branch!(e) = send_from_palette!(e, :rebase)
add_command!(push_branch!, name=:push, title="Send the branch's new commits to the branch that it follows, like origin/main")
add_command!(pull_branch!, name=:pull, title="Bring the new commits of the branch that this one follows, like origin/main")
add_command!(merge_branch!, name=:merge, title="Pull the commits of the branch that this one follows, and join the two branches with a new commit")
add_command!(rebase_branch!, name=:rebase, title="Pull the commits of the branch that this one follows, and make this branch's own commits again after them")

# Push shows in any repository. Pull shows while the branch follows one, and Merge and Rebase while the two have gone apart.
works_here(e, ::Val{:push}) = !isempty(repo_of(e))
works_here(e, ::Val{:pull}) = (root = repo_of(e); !isempty(root) && (s = watch_git!(e, root); !s.known || !isempty(s.follows)))
works_here(e, ::Union{Val{:merge},Val{:rebase}}) = (root = repo_of(e); !isempty(root) && diverged(watch_git!(e, root)))
# --- commits from git's panel --------------------------------------------------------------
#
# Each file in the list of changes of git's panel has a tick box at its left.
# A tick puts the file's change in the next commit, as `git add` does, and a
# click on the box again takes it out. The ticks are git's own, so a file that
# `git add` put in the next commit somewhere else is ticked too.
#
# The Commit button at the right of the heading of the changes commits the
# ticked files: it says "Commit 2" for two of them. With no file ticked, it says
# "Commit all", and commits every changed file. The agent that Settings chose
# writes the message, or you do when the setting says so, as with the Commit
# button of the top bar.
# A file that a merge left in two forms has no tick box: a tick would tell git
# that you've chosen its lines.

"The tick box of a file in the list of changes of git's panel: ticked while the file's change is in the next commit"
@def mutable struct FileTick <: SemanticUI
  root::String = ""
  rel::String = ""   # the file's path from the repository's top folder
end

"True while the window is busy with a commit of the repository at `root`, or git runs there, so the ticks stay as they are"
committing(e, root) = (w = get(e.nodes, :writing, nothing); (w !== nothing && w.root == root) || haskey(GIT_RUNS, root))

describe(t::FileTick) = begin
  e = editor(t)
  on = t.rel in Git.state(t.root).staged
  still = committing(e, t.root)
  Box(width(18px), height(20px), radius(4px), Alignment.Center, name="Tick",
      background(!still && ishovered(t) ? colours.hover : clear),
    Icon(on ? "check2-square" : "square", size=13px, color=on ? colours.accent : colours.dim))
end

cursor(t::FileTick) = committing(editor(t), t.root) ? :arrow : :hand
onkey(t::FileTick, ::KeyPress{Keys.mouse_left}) = (tick_file!(editor(t), t.root, t.rel); handled)

"The tick box of the file at `rel` of the repository at `root`, whose change is `kind`, or a space as wide for a file that has none"
file_tick(e, root, rel, kind) = begin
  kind == :clash && return Box(width(18px))
  t = node!(FileTick, e, (:file_tick, root, rel))
  t.root, t.rel = root, rel
  t
end

"""
Put the change of the file at `rel` of the repository at `root` in the next
commit, or take it out when it's in. A window's changes to the file that
aren't saved are saved first, so the commit has them.
"""
tick_file!(e, root, rel) = begin
  committing(e, root) && return e
  s = Git.state(root)
  path = joinpath(root, rel)
  done, why = if rel in s.staged
    # Before the first commit there's nothing to put back, so git only forgets the file
    s.head == "(initial)" ? Git.act(root, `rm --cached -q -- $rel`) : Git.act(root, `restore --staged -- $rel`)
  else
    save_for_commit!(e, root, path, :file)
    Git.act(root, `add -- $rel`)
  end
  Git.forget!()
  done || say_result!(e, "git couldn't do it: " * git_reason(why))
  redraw_in!(e, 0)
  e
end

"""
The Commit button of git's panel for the repository at `root`, where git says
`s` of it. It commits the ticked files, or every changed file when none is
ticked, and its words say which.
"""
commit_button(e, root, s) = begin
  n = count(rel -> rel in s.staged, keys(s.changes))
  b = node!(PageButton, e, (:git_button, root, :commit))
  w = get(e.nodes, :writing, nothing)
  b.act = _ -> commit_scope!(e, n > 0 ? :staged : :all)
  b.icon = "check2"
  b.words = w !== nothing && w.root == root ? "Committing…" : n > 0 ? "Commit $n" : "Commit all"
  b.off = w !== nothing || haskey(GIT_RUNS, root) || !s.known
  b
end

describe(p::GitPanel) = begin
  e = editor(p)
  s = watch_git!(e, p.path)
  log = Git.commits(p.path, 30)
  changes = Git.changed(s)
  change(rel, kind) = begin
    path = joinpath(p.path, rel)
    dir = dirname(rel)
    # A file shows with what changed in it marked. A file that's gone has nothing to show.
    act = ispath(path) ? (_ -> (show_changes!(e, path); nothing)) : nothing
    page_row!(p, (:change, rel), act,
      file_tick(e, p.path, rel, kind),
      Box(width(14px), label(GIT_LETTERS[kind], 12px, color=git_colour(kind), weight="Semibold")),
      Row(width(grow=grow), height(grow=grow), clip=true, child_gap=6px,
        Box(label(basename(rel), 13px)), (isempty(dir) ? () : (Box(label(dir, 12px, color=colours.faint)),))...),
      Box(label(GIT_WORDS[kind], 12px, color=colours.faint)))
  end
  # Nothing in the panel makes it wider than its column: a name that's too long is cut off at its edge
  # The panel fills its height, and the last commits take what the parts over them leave, so most of the time
  # only they scroll. When the changes leave the commits less than `LOG_LEAST`, the whole panel scrolls too.
  reuse!(p.scroll, Column(width(grow=grow), height(grow=grow), Alignment.Start, padding(2px, 10px, 6px, 10px), clip_x=true, name="Git",
    Column(width(grow=grow), Alignment.Start, padding(8px, 4px, 12px, 8px), child_gap=4px,
      Row(width(grow=grow), child_gap=8px, Icon("git", size=15px, color=colours.dim),
        Row(width(grow=grow), clip=true, Box(label(s.known ? s.branch : "…", 15px, weight="Semibold"))),
        send_buttons(e, p.path, s)),
      Box(width(grow=grow), Alignment.Start, Text(follow_words(s), size=12px, family=SANS, color=colours.dim, wrap=WrapMode.words))),
    (isempty(changes) ? page_heading("Changes") :
     Row(width(grow=grow), Alignment.Center, child_gap=8px,
       page_heading("Changes  ·  $(length(changes))"), commit_button(e, p.path, s))),
    (!s.known ? (page_note("Asking git…"),) :
     isempty(changes) ? (page_note("No file has changed since the last commit."),) :
     [change(rel, kind) for (rel, kind) in changes])...,
    Box(height(14px)),
    page_heading("Last commits"),
    isempty(log) ? page_note(s.known ? "This repository has no commit yet." : "Asking git…") :
      Scroll(width(grow=grow), height(preferred=LOG_LEAST, grow=grow), key=:git_log, name="Log",
        Column(width(grow=grow), Alignment.Start, tree_of_commits(e, p.path, s, log)...))))
end

"How tall the last commits of git's panel are at the least, in their own scroll. The panel scrolls when its other parts leave them less."
const LOG_LEAST = 300px

"""
The lines of git's panel for the commits `log` of the repository at `root`,
with the tree that they make at their left: see `CommitLine`. `s` is what git
says of the repository, for the branch that's checked out.
"""
tree_of_commits(e, root, s, log) = begin
  rows = Git.tree(log)
  lanes = maximum(r -> r.lanes, rows)
  [commit_line(e, root, c, r, lanes, s.branch) for (c, r) in zip(log, rows)]
end

cursor(::GitPanel) = :arrow

# --- a commit's page -----------------------------------------------------------------------
#
# A click on a commit in git's panel shows what the commit holds, in the page
# beside the panel: its message, who made it and when, and the lines of each
# file that it changed, drawn as a block of changes draws them. The commit is
# lit in the panel. A click on it again, the arrow at the top of the page, or
# going back (⌘⌥←) shows the repository's files again. A click on a commit's
# file shows the file as it is now.
#
# A commit can change thousands of lines, so a file's lines start hidden when
# there are more than `OPEN_MOST` of them, or when the files over it already
# show `OPEN_ALL` lines. A click on the file's row shows them or hides them.

push!(BLOCK_ICONS, "arrow-left", "chevron-down", "chevron-right", "clipboard", "box-arrow-up-right")

"The most lines of a diff that a commit's file shows when its page opens. A file with more starts with its lines hidden."
const OPEN_MOST = 1500
"The most lines of a diff that all of a commit's files show together when its page opens"
const OPEN_ALL = 5000

"What the page of a repository shows in place of its files while a commit shows: see \"a commit's page\""
@def mutable struct CommitView <: SemanticUI
  root::String = ""
  hash::String = ""                          # the commit, as git's panel has it, or "" while the repository's files show
  at::String = ""                            # the folder whose page shows it: the repository's top folder, or a folder in it
  open::Dict{Int,Bool} = Dict{Int,Bool}()    # whether the lines of each file show, by the file's place in the commit
  views::Dict{Int,Any} = Dict{Int,Any}()     # the changes of each file whose lines have shown, by its place: a ChangesView
  tallies::Dict{Int,Tuple{Int,Int}} = Dict{Int,Tuple{Int,Int}}()   # how many lines each file gains and loses
  rows::Dict{Any,PageRow} = Dict{Any,PageRow}()
  parts::Dict{Any,Any} = Dict{Any,Any}()     # its buttons
  scroll::Scroll = Scroll(width(grow=grow), height(grow=grow), scrollbar_inset=0px)   # its scrollbar is at the page's right edge, as the editor's is
  wide::Float64 = 0.0                        # how wide the lines of the changes are, in this frame
end

"""
The commit of the repository at `root` that the page shows, or \"\" while it
shows the files. A commit shows only on the page of the folder where it was
clicked, the repository's top folder or a folder in it, so another folder's
page shows its files.
"""
shown_commit(e, root) = (v = get(e.nodes, (:commit, root), nothing); v === nothing || v.at != e.buf.path ? "" : v.hash)

"""
Show the commit `hash` of the repository at `root` in the page of the folder
that shows: the repository's top folder, or a folder in it. The commit that
shows already goes away again, and the folder's files show.
"""
show_commit!(e, root, hash) = begin
  v = node!(() -> CommitView(root=root), e, (:commit, root))
  v.hash = shown_commit(e, root) == hash ? "" : hash
  v.at = e.buf.path
  empty!(v.open); empty!(v.views); empty!(v.tallies); empty!(v.rows)
  v.scroll.offset = 0px
  redraw_in!(e, 0)
  e
end

"Show the repository's files in the page of the repository at `root` again, in place of a commit. It's true when a commit showed."
close_commit!(e, root) = isempty(shown_commit(e, root)) ? false : (show_commit!(e, root, shown_commit(e, root)); true)

"The page of a repository takes a step back of its own: from a commit to the repository's files"
page_back!(e, d::GitDirectory) = (root = repo_top(d); !isempty(root) && close_commit!(e, root))

"""
A commit in git's panel. A click shows what it holds in the page, and a click
on the commit that shows shows the repository's files again.

At its left is its part of the tree that the commits make, as `git log
--graph` draws it: a dot for the commit, in the lane of its branch, and the
lines that go down from it to the commits that it was made on. A merge has a
smaller dot, and the commit that's checked out has a ring round its dot. Each
branch has a colour of its own. The branches and the tags that are at the
commit are over its first line, in its colour: a branch here is filled in, and
a branch of another copy, like origin/main, has a line round it.
"""
@def mutable struct CommitLine <: SemanticUI
  root::String = ""
  commit::Git.Commit = Git.Commit()
  row::Git.TreeRow = Git.TreeRow()   # its row of the tree
  lanes::Int = 1                     # how many lanes the tree of the panel's commits has, so each commit's words start at one place
  branch::String = ""                # the branch that's checked out
end

"How far apart the lanes of the tree of commits are, in px"
const LANE_W = 14.0
"How far the middle of the first lane of the tree is from the left edge of a commit's line, in px"
const TREE_X = 12.0
"How much room a commit's line has over and under its words, in px. The lines of one commit's words are closer together than two commits are."
const COMMIT_PAD = 10.0
"How tall the box of a branch or a tag over a commit's first line is, in px"
const REF_H = 18.0

"""
How far down the line of `l` its dot is, in px: level with the middle of the
boxes of its branches, or with the middle of its first line of words
"""
dot_y(l::CommitLine) = COMMIT_PAD + (isempty(l.commit.refs) ? num(skia_cap_height(label("A", 13px))) / 2 : REF_H / 2)

"The colour of the branch `k` in the tree of commits: the colours of a chart's columns, in turn"
tree_colour(k) = (c = series_colours(); c[mod1(k, length(c))])

"The branches and the tags at the commit of `l`, as little boxes in a row"
ref_boxes(l::CommitLine) = begin
  colour = tree_colour(l.row.hue)
  box(r) = begin
    kind = Git.ref_kind(r)
    name = Git.ref_name(r)
    words = label(name, 11px, color=colour, weight=kind == :branch && name == l.branch ? "Bold" : "Semibold")
    kind == :branch ? Box(height(REF_H * px), padding(6px, 0px), radius(4px), background(tint(colour, 0.16)), words) :
    kind == :tag ? Row(height(REF_H * px), padding(6px, 0px), radius(4px), child_gap=3px, border(1px, :solid, tint(colour, 0.45)),
                       Icon("tag", size=10px, color=colour), words) :
    Box(height(REF_H * px), padding(6px, 0px), radius(4px), border(1px, :solid, tint(colour, 0.45)), words)
  end
  Row(width(grow=grow), clip=true, child_gap=4px, Alignment.Center, map(box, l.commit.refs)...)
end

describe(l::CommitLine) = begin
  c = l.commit
  on = shown_commit(editor(l), l.root) == c.hash
  # The words start right of the tree's last lane. The first line can be long, so it wraps in the panel's width.
  left = px(TREE_X + LANE_W * (l.lanes - 0.5) + 8)
  # A Text's box ends at the foot of its last line's capitals, so the line under the
  # words is 8px lower than that, or the tails of g and y would touch it
  Column(width(grow=grow), padding(COMMIT_PAD * px, 8px, COMMIT_PAD * px, left), radius(6px), child_gap=5px, Alignment.Start, name="Commit",
         background(on ? colours.active : ishovered(l) ? colours.hover : clear),
    (isempty(c.refs) ? () : (ref_boxes(l),))...,
    Box(width(grow=grow), Alignment.Start, Text(c.subject, size=13px, family=SANS, color=colours.ink, wrap=WrapMode.words)),
    Box(padding(3px, 0px, 0px, 0px), label(c.hash * "  ·  " * c.author * "  ·  " * Git.ago(c.time), 11px, color=colours.faint)))
end

"""
Draw a line through the corners `ps`, with each corner rounded by `r` px at
the most: the tree of commits draws a line that goes to another lane this way
"""
bent_line(ctx, ps, colour, wide; r=6.0) = begin
  shape = Skia.sk_path_new()
  Skia.sk_path_move_to(shape, Float32(ps[1][1]), Float32(ps[1][2]))
  for k in 2:length(ps)-1
    before, corner, after = ps[k-1], ps[k], ps[k+1]
    d1, d2 = hypot((corner .- before)...), hypot((after .- corner)...)
    round = min(r, d1, d2)
    a = corner .+ (before .- corner) .* (round / max(d1, 1e-6))
    b = corner .+ (after .- corner) .* (round / max(d2, 1e-6))
    Skia.sk_path_line_to(shape, Float32(a[1]), Float32(a[2]))
    # A conic with this weight is a quarter of a circle
    Skia.sk_path_conic_to(shape, Float32(corner[1]), Float32(corner[2]), Float32(b[1]), Float32(b[2]), Float32(sqrt(0.5)))
  end
  Skia.sk_path_line_to(shape, Float32(ps[end][1]), Float32(ps[end][2]))
  paint = ink(colour, wide)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_paint_delete(paint)
  Skia.sk_path_delete(shape)
end

# The commit's part of the tree, over its line's background. Each line of the tree
# meets the same line in the rows over and under it, at the rows' edges.
draw(ctx, size, ui::ConcreteRect, l::CommitLine) = begin
  r = l.row
  top, bottom = num(ui.top), num(ui.top) + num(ui.height)
  y = top + dot_y(l)
  x(lane) = num(ui.left) + TREE_X + LANE_W * (lane - 1)
  with_clip(ctx, ui.left, ui.top, ui.width, ui.height) do
    # A line from the top that goes to the dot comes down its lane, then turns to the dot
    for (a, b, k) in r.above
      bent_line(ctx, a == b ? [(x(a), top), (x(a), y)] : [(x(a), top), (x(a), y), (x(b), y)], tree_colour(k), 1.5)
    end
    # A line from the dot to another lane goes across, then turns down
    for (a, b, k) in r.below
      bent_line(ctx, a == b ? [(x(a), y), (x(a), bottom)] : [(x(a), y), (x(b), y), (x(b), bottom)], tree_colour(k), 1.5)
    end
    colour = tree_colour(r.hue)
    paint = ink(colour)
    Skia.sk_canvas_draw_circle(ctx, Float32(x(r.lane)), Float32(y), Float32(length(l.commit.parents) > 1 ? 2.5 : 4.0), paint)
    Skia.sk_paint_delete(paint)
    if l.commit.head
      paint = ink(colour, 1.5)
      Skia.sk_canvas_draw_circle(ctx, Float32(x(r.lane)), Float32(y), Float32(6.5), paint)
      Skia.sk_paint_delete(paint)
    end
  end
  nothing
end

cursor(::CommitLine) = :hand
onkey(l::CommitLine, ::KeyPress{Keys.mouse_left}) = (show_commit!(editor(l), l.root, l.commit.hash); handled)

"""
The line of git's panel for the commit `c` of the repository at `root`, with
its row `row` of the tree of `lanes` lanes. `branch` is the branch that's
checked out.
"""
commit_line(e, root, c, row=Git.TreeRow(), lanes=1, branch="") = begin
  l = node!(() -> CommitLine(root=root), e, (:commit_line, root, c.hash))
  l.commit, l.row, l.lanes, l.branch = c, row, lanes, branch
  l
end

"How wide the lines of the changes of `v` are, as the commit's page `p` lays them out: as wide as its column, less the line at each side"
diff_wide(p::CommitView, v::ChangesView) = p.wide - 2

"How many lines file `k` of the commit `s` gains and loses"
file_tally(v::CommitView, s, k) = get!(v.tallies, k) do
  added = removed = 0
  inside = false
  for l in view(s.diff, s.files[k].lines)
    inside |= startswith(l, "@@")
    inside || continue
    startswith(l, '+') && (added += 1)
    startswith(l, '-') && (removed += 1)
  end
  (added, removed)
end

"Which files of the commit `s` show their lines when its page opens: each one in order, until they would show too many"
open_first!(v::CommitView, s) = begin
  total = 0
  for (k, f) in enumerate(s.files)
    n = length(f.lines)
    # A file that isn't text has no lines, only words that say so
    v.open[k] = f.binary || (n <= OPEN_MOST && total + n <= OPEN_ALL)
    v.open[k] && (total += n)
  end
  v
end

"The changes of file `k` of the commit `s`, read once, as a block of changes that's only shown"
file_changes(v::CommitView, s, k) = get!(v.views, k) do
  lines = s.diff[s.files[k].lines]
  own!(v, ChangesView(data=Diffs.changes(lines), lines=lines))
end

"""
The message of a commit as lines to show: its paragraphs, each as one line,
since git wraps a message by hand. A line of a list, and a line like
`Co-Authored-By: …`, stays a line of its own.
"""
message_lines(message) = begin
  out = String[]
  for para in split(strip(message), r"\n\s*\n")
    for line in split(para, '\n')
      line = strip(line)
      isempty(line) && continue
      own = occursin(r"^([-*•]\s|\d+[.)]\s|[A-Za-z-]+:\s)", line)
      isempty(out) || own || out[end] == "" ? push!(out, String(line)) : (out[end] *= " " * line)
    end
    push!(out, "")   # an empty line ends a paragraph
  end
  isempty(out) || pop!(out)
  out
end

"When `t` was, as a date and a time, like `22 Nov 2026, 4:21 pm`"
commit_when(t) = replace(Libc.strftime("%-d %b %Y, %-I:%M %p", t), "AM" => "am", "PM" => "pm")

"What the commit's page says of file `f`, after its name: that it's new, deleted or moved"
touched_words(f) = f.kind == :new ? "New" : f.kind == :deleted ? "Deleted" : f.kind == :renamed ? "Moved from $(f.from)" : ""

"The part of the commit's page for file `k` of the commit `s`: a row with its name, then its lines"
commit_file(v::CommitView, e, s, k) = begin
  f = s.files[k]
  path = joinpath(v.root, f.path)
  open = get(v.open, k, false)
  dir = dirname(f.path)
  added, removed = file_tally(v, s, k)
  words = touched_words(f)
  head = page_row!(v, (:file, k), _ -> (v.open[k] = !open; redraw_in!(e, 0); nothing),
    Box(width(12px), Icon(open ? "chevron-down" : "chevron-right", size=10px, color=colours.dim)),
    Row(width(grow=grow), height(grow=grow), clip=true, child_gap=6px,
      Box(label(basename(f.path), 13px, weight="Semibold")),
      (isempty(dir) ? () : (Box(label(dir, 12px, color=colours.faint)),))...,
      (isempty(words) ? () : (Box(label(words, 12px, color=git_colour(f.kind))),))...),
    tally_words(added, removed)...,
    # The file as it is now. A file that's gone has nothing to show.
    (isfile(path) ? (block_button!(v, (:show, k), (:show, path), icon="box-arrow-up-right", tip="Show $(basename(f.path)) as it is now"),) : ())...)
  top = Box(width(grow=grow), padding(4px, 4px), background(colours.stripe), head)
  note(words) = Box(width(grow=grow), padding(12px, 10px), border(1px, :solid, colours.line)[:top], label(words, 12.5px, color=colours.dim))
  # A file whose lines have never shown says why they don't
  hidden = added + removed
  !open && !haskey(v.views, k) && hidden > 0 &&
    return Column(block_look()..., clip=true, name="File", top,
                  note("Its $(commas(hidden)) changed lines are hidden, as they're many. A click on its row shows them."))
  open || return Column(block_look()..., clip=true, name="File", top)
  c = file_changes(v, s, k)
  hunks = c.data.hunks
  # A file with no lines to show says why
  why = f.binary ? "Ladder can't show the lines of this file, because it isn't text." :
        !isempty(hunks) ? nothing :
        f.kind == :renamed ? "Its lines are the same as before." :
        f.kind == :new ? "It's an empty file." : "Its lines didn't change."
  why === nothing || return Column(block_look()..., clip=true, name="File", top, note(why))
  parts = Any[]
  for (j, h) in enumerate(hunks)
    place = lowercasefirst(Diffs.place(h))
    push!(parts, Row(width(grow=grow), height(26px), padding(12px, 0px), child_gap=8px, Alignment.Center, clip=true,
                     border(1px, :solid, colours.line)[:top], background(colours.block),
      Box(label(isempty(place) ? "" : uppercasefirst(place), 11.5px, color=colours.dim)),
      Row(width(grow=grow), height(grow=grow), clip=true,
          Box(Text(h.about, size=11.5px, family=codefont(), subfamily=codestyle(), color=colours.faint, wrap=WrapMode.none)))))
    push!(parts, block_part!(() -> HunkArea(of=c, k=j), c, (:hunk, j)))
  end
  Column(block_look()..., clip=true, name="File", top, parts...)
end

act!(v::CommitView, action, w) = begin
  e = editor(v)
  action[1] == :beside && return (beside!(e, action[2]); handled)
  action[1] == :copy && return (clipboard!(w, action[2]); handled)
  action[1] == :show && return (show_path!(e, action[2]); handled)
  action[1] == :close && return (close_commit!(e, v.root); handled)
  handled
end

describe(v::CommitView) = begin
  e = editor(v)
  s = Git.shown(v.root, v.hash)
  room, _ = page_room(e)
  # As wide as the room beside the sidebar and git's panel, since lines of code are long
  v.wide = max(num(room) - num(right_w(e)) * right_opened(e) - 2num(PAGE_X), 240.0)
  # It goes back to the folder where the commit was clicked
  back = block_button!(v, :close, (:close,), icon="arrow-left", words=basename(v.at),
                       tip=v.at == v.root ? "Show the repository's files again" : "Show the folder's files again")
  top = Row(width(grow=grow), back)
  body = if s === nothing
    (page_title("git", "No such commit", "git can't find the commit $(v.hash) in this repository."),)
  elseif !s.known
    redraw_in!(e, 0.1)   # git answers in a later frame
    (page_note("Asking git…"),)
  else
    isempty(v.open) && open_first!(v, s)
    lines = message_lines(s.message)
    added = sum(k -> file_tally(v, s, k)[1], eachindex(s.files), init=0)
    removed = sum(k -> file_tally(v, s, k)[2], eachindex(s.files), init=0)
    n = length(s.files)
    two = e.beside && v.wide - 2 >= BESIDE_LEAST
    narrow = v.wide - 2 < BESIDE_LEAST
    short = first(s.hash, 7)
    message = Column(width(grow=grow, max=e.widest * e.zoom), Alignment.Start, padding(8px, 0px, 18px, 8px), child_gap=8px,
      Box(width(grow=grow), Alignment.Start, Text(isempty(lines) ? "(No message)" : lines[1], size=22px, family=SANS, subfamily="Bold", color=colours.ink, wrap=WrapMode.words)),
      Row(child_gap=8px, Alignment.Center,
        Box(label(s.author * "  ·  " * commit_when(s.time), 13px, color=colours.dim)),
        block_button!(v, :copy, (:copy, s.hash), icon="clipboard", words=short, tip="Copy the commit's whole hash")),
      [isempty(l) ? Box(height(4px)) : Box(width(grow=grow), Alignment.Start, Text(l, size=14px, family=SANS, color=colours.ink, wrap=WrapMode.words))
       for l in lines[2:end]]...)
    bar = Row(width(grow=grow), height(34px), padding(0px, 0px, 0px, 8px), child_gap=8px, Alignment.Center,
      Box(label(n == 0 ? "No file changed" : n == 1 ? "1 file changed" : "$(commas(n)) files changed", 13px, color=colours.dim, weight="Semibold")),
      tally_words(added, removed)..., Box(width(grow=grow)),
      block_button!(v, :under, (:beside, false), icon="view-stacked", on=!two, tip="Show the new lines under the old lines"),
      block_button!(v, :beside, (:beside, true), icon="layout-split", on=two, off=narrow,
                    tip=narrow ? "The window is too narrow to show the old lines beside the new lines" : "Show the old lines beside the new lines"))
    (message, bar, [commit_file(v, e, s, k) for k in eachindex(s.files)]...)
  end
  reuse!(v.scroll, Row(width(grow=grow), Alignment.Start, justify=Alignment.Center, padding(PAGE_TOP, PAGE_X, PAGE_BOTTOM, PAGE_X),
    Column(width(px(v.wide)), Alignment.Start, child_gap=10px, name="Commit", top, body...)))
end

cursor(::CommitView) = :arrow

# --- a commit of the file that shows ---------------------------------------------------------
#
# While the window shows a file that git keeps, and the file has changes since
# the last commit, the top bar has a button with git's mark. A click commits
# the file with a message that the agent that Settings chose writes: see "an
# agent writes the commit's message". The palette's Commit takes words that you write. Run commits that
# file alone, as the window has it. The other files with changes stay as they
# are, and so does what git was given for the next commit of them.

"""
The change since the last commit of the file at `path`, as git said it last,
that a commit of the file alone can take: `:changed`, `:added` or `:new`. A
window with changes to the file that aren't saved makes it `:changed` too.
It's nothing for a file that git doesn't keep, one with no change, one with a
new name, and one that a merge left in two forms.
"""
commit_change(e, path::AbstractString) = begin
  (isempty(path) || !isfile(path)) && return nothing
  root = git_top(dirname(path))
  isempty(root) && return nothing
  kind = Git.mark(watch_git!(e, root), relpath(path, root))
  kind in (:changed, :added, :new) && return kind
  kind === nothing && any(o -> unsaved_in(o, path), with_windows(e)) ? :changed : nothing
end

"True when the window of `o` shows the file at `path`, with changes that aren't saved yet"
unsaved_in(o, path) = !isempty(o.buf.path) && dirty(o.buf) && writes(o.buf) && page_key(o.buf.path) == page_key(path)

"The editor `e` and the editor of each other window"
with_windows(e) = e in editors ? editors : Editor[e; editors]

"""
Commit the file `file` to its git repository, with the words `message`. The
commit holds that file alone, as its windows have it: changes that aren't
saved are saved first.
"""
commit_file!(e, file::FS.File, message::String) = begin
  path = path_of(file)
  words = strip(message)
  isempty(words) && error("Write what the commit changes")
  root = git_top(dirname(path))
  isempty(root) && error("git doesn't keep $(basename(path))")
  for o in with_windows(e)
    unsaved_in(o, path) && save!(o.buf)
  end
  # git is asked about the file now, not what it said some seconds ago, which can be from before a commit
  rel = relpath(path, root)
  kind = Git.mark(Git.read_status(something(Git.ask(root, `status --porcelain=v2 -z -- $rel`), "")), rel)
  kind in (:changed, :added, :new) || error("$(basename(path)) has no change to commit")
  # A file that git doesn't keep yet is added first. When the commit fails, git forgets it again.
  done, why = kind == :new ? Git.act(root, `add -- $rel`) : (true, "")
  done && ((done, why) = Git.act(root, `commit -m $words -- $rel`))
  !done && kind == :new && Git.act(root, `rm --cached -q -- $rel`)
  Git.forget!()
  redraw_in!(e, 0)
  done || error("git didn't commit it: " * String(first(split(isempty(strip(why)) ? "it gave no reason" : strip(why), '\n'))))
  nothing
end
add_command!(commit_file!, name=:commit, title="Commit the file to its git repository, with words that say what changed")

# The palette lists Commit only while the file in focus has a change to commit
works_here(e, ::Val{:commit}) = begin
  focus = in_focus(e)
  k = findfirst(x -> x isa FS.File, focus)
  k !== nothing && commit_change(e, path_of(focus[k])) !== nothing
end
wide_words(::Val{:commit}) = true

"""
The button of the top bar that commits the file that shows, while it has a
change to commit, and the chevron beside it: see `commit_change`. While the
list under the chevron shows, the two are on the list's colour, as one tab of
the list's envelope: see `commit_envelope`.
"""
commit_part(e) = begin
  !haskey(e.nodes, :writing) && commit_change(e, e.buf.path) === nothing && return ()
  open = commit_list_open(e)
  (Row(Alignment.Center, name="Commit", radius(px(COMMIT_ROUND), px(COMMIT_ROUND), 0px, 0px), background(open ? found_colours().frame : clear),
       button(e, :commit, "git"), node!(CommitMore, e, :commit_more)),)
end

# --- an agent writes the commit's message --------------------------------------------------------
#
# A click on the Commit button saves the window's changes to the file, and
# gives the file's diff since the last commit to the agent that Settings
# chose, Claude Code unless you changed it, which writes the message as the
# repository's last messages are written. Then Ladder commits the file, and
# says so under the top bar. The button spins while the agent writes. When it
# can't write it, the words under the top bar say why, and the palette opens
# with Commit, for a message that you write. The words of the button and of
# the list name the agent.
#
# In agent mode, once you have talked with the agent beside the page, that
# agent writes the message, as it knows why the page changed: see
# `commit_talk`. The Commit button asks it in the conversation, after the
# turn that's under way, and the pane shows the question and the message. The
# diff goes with the question, though the pane doesn't show it. If you stop
# the agent, or it fails, nothing is committed. Before you have talked with
# it, the agent of Settings writes the message in a run of its own, as above.
#
# The chevron beside the button opens a list of the three ways to commit:
#
#   - Commit this file, as the button does.
#   - Commit part of this file shows what changed in the file itself, with a
#     tick box on each change. The Commit button then commits only the ticked
#     changes. The file stays as it is, so the changes that weren't ticked are
#     still changes after the commit.
#   - Commit all changed files commits every file that git's panel lists.
#
# Under them, a switch says who writes the message of each way: the agent, or
# you. With it on, a commit opens the palette for your words. It's a setting,
# so it stays as you leave it.

"The command that writes a commit's message from the diff that it reads on its stdin. Nothing means the command of the agent that Settings chose. A test puts a command of its own here."
const MESSAGE_COMMAND = Ref{Any}(nothing)

"The most of a diff that the agent reads for a message. A longer diff is cut short, and says so."
const MOST_DIFF = 60_000

"""
The command that writes the message of a commit of the repository at `root`
for the window of `e`, and what the command reads on its stdin: the agent
that Settings chose, asked for a message of `diff`. Claude Code reads the
diff on its stdin. An agent that doesn't, like Grok, gets it in its words.
"""
message_command(e, root, diff) = begin
  MESSAGE_COMMAND[] === nothing || return (`$(MESSAGE_COMMAND[]) $(message_prompt(root))`, diff)
  k = agent_kind(e.ai)
  k.piped ? (`$(kind_command(k, k.message)) $(message_prompt(root))`, diff) :
            (`$(kind_command(k, k.message)) $(message_prompt(root, piped=false) * "\n\nThe diff:\n\n" * diff)`, "")
end

"The last commit messages of the repository at `root`, the newest first, with no lines that say who helped"
recent_messages(root, n=5) = begin
  log = something(Git.ask(root, `log -$n --format=%B%x1e`), "")
  messages = String[]
  for m in split(log, '\x1e')
    lines = filter(l -> !occursin(r"^(Co-Authored-By|Claude-Session|Signed-off-by):"i, l), split(strip(m), '\n'))
    text = strip(join(lines, "\n"))
    isempty(text) || push!(messages, text)
  end
  messages
end

"What the agent is asked, for the message of a commit of the repository at `root`. With `piped` false, the diff comes after these words."
message_prompt(root; piped=true) = begin
  examples = recent_messages(root)
  "Write the git commit message for the change in the diff that $(piped ? "you read on stdin" : "comes at the end of these words"). " *
  "Write it as the recent messages of this repository are written: a first line of less than 72 characters " *
  "that says what the change does, and then a blank line and a short body only when the change needs one. " *
  "Reply with the message alone, with no quotes and no code fence." *
  (isempty(examples) ? "" : "\n\nThe recent messages, newest first:\n\n" * join(examples, "\n\n---\n\n"))
end

"""
The words that Ladder gives the agent of a conversation for the message of a
commit of `what` (see `commit_now!`) in the repository at `root`, and the
diff `diff` of it: the words that the pane shows, and the rest, which it
doesn't. `name` is the file's name.
"""
talk_prompt(root, what, name, diff) = begin
  examples = recent_messages(root)
  of = what == :all ? "all the changed files" : what == :staged ? "the files that are ticked in git's panel" :
       what == :part ? "the ticked changes of $name" : name
  shown = "Write the commit message for $of."
  told = "The user clicked the Commit button in Ladder's top bar, and Ladder wrote these words for it. " *
    "Write the git commit message for the change in the diff at the end of these words: it's all that the commit holds. " *
    "You know from this conversation why some of it was made, so say what the change does, and why when that helps. " *
    "Write it as the recent messages of this repository are written: a first line of less than 72 characters " *
    "that says what the change does, and then a blank line and a short body only when the change needs one. " *
    "Reply with the message alone, with no words before or after it, no quotes and no code fence. " *
    "Don't run git and don't change a file: Ladder makes the commit with your reply." *
    (isempty(examples) ? "" : "\n\nThe recent messages, newest first:\n\n" * join(examples, "\n\n---\n\n")) *
    "\n\nThe diff:\n\n" * diff
  (shown, told)
end

"""
The message that the command `cmd` wrote from `input`, which it reads on its
stdin, with no code fence and no blank lines round it. It fails with what the
command said when it fails. `who` is the agent, by its name.
"""
read_message(cmd, input; who="Claude") = begin
  said = IOBuffer()
  out = try
    read(pipeline(cmd, stdin=IOBuffer(input), stderr=said), String)
  catch
    why = strip(String(take!(said)))
    error(isempty(why) ? "$who didn't write a message." : "$who didn't write a message: " * first(split(why, '\n')))
  end
  clean_message(out; who)
end

"The message in `out`, what the agent `who` wrote, with no code fence, no blank lines round it, no line that says who helped, and a blank line after its first line when more lines follow. It fails when that leaves nothing."
clean_message(out; who="Claude") = begin
  text = strip(replace(strip(out), r"^```[a-z]*\n" => "", r"\n```$" => ""))
  # Claude adds a line that says it wrote the commit with you. It wrote the message, not the change, so the line goes.
  lines = filter(l -> !occursin(r"^(Co-Authored-By|Claude-Session):"i, l), split(text, '\n'))
  # git takes the lines up to the first blank one as the first line, so the body starts after a blank line
  length(lines) > 1 && !isempty(strip(lines[2])) && insert!(lines, 2, "")
  text = strip(join(lines, "\n"))
  isempty(text) && error("$who wrote an empty message.")
  String(text)
end

"The diff of `rel` from the text `was` to the text `now`, as git writes it"
text_diff(rel, was, now) = join(change_diff(rel, was, now), "\n")

"The text of the file at `rel` in the last commit of the repository at `root`, or \"\" for a file that it hasn't got"
committed_text(root, rel) = something(Git.at_commit(root, "HEAD", rel), "")

"The lines `old` with the changes `chosen` made, each a run of old lines and the new lines that take their place"
with_changes(old, new, chosen) = begin
  out = copy(old)
  # From the bottom, so that the changes above keep their places
  for (o, n) in sort(chosen, by=c -> -first(c[1]))
    splice!(out, o, new[n])
  end
  out
end

"""
Start a commit of the window's file with a message that the agent writes: of the
whole file with `:file`, of every changed file of its repository with
`:all`, of the ticked changes of the file with `:part`, or of the files that
are ticked in git's panel with `:staged`. Changes that aren't saved are saved
first. The agent writes while the window goes on, and `commit_tick!` commits
when the message comes. The agent is the one of the conversation beside the
page, once you have talked with it, else the one that Settings chose.
"""
commit_now!(e, what::Symbol) = begin
  haskey(e.nodes, :writing) && return e   # one at a time
  try
    path = e.buf.path
    root = repo_of(e)
    isempty(root) && error("git doesn't keep $(basename(path))")
    save_for_commit!(e, root, path, what)
    rel = relpath(realpath(path), realpath(root))
    part = nothing
    diff = if what == :all
      tracked = something(Git.ask(root, `diff HEAD`), "")
      fresh = split(something(Git.ask(root, `ls-files --others --exclude-standard`), ""), '\n', keepempty=false)
      # A file that git doesn't keep yet has no diff of its own, so its lines are the diff
      join([tracked; [text_diff(f, "", try read(joinpath(root, f), String) catch; "" end) for f in first(fresh, 20)]], "\n")
    elseif what == :part
      part, diff = ticked_text(e, rel)
      diff
    elseif what == :staged
      something(Git.ask(root, `diff --cached`), "")
    else
      text_diff(rel, committed_text(root, rel), read(path, String))
    end
    what == :staged && isempty(strip(diff)) && error("Tick the files to commit.")
    isempty(strip(diff)) && error("$(what == :all ? basename(root) : basename(path)) has no change to commit.")
    length(diff) > MOST_DIFF && (diff = first(diff, MOST_DIFF) * "\n… (the diff goes on)")
    talk = commit_talk(e)
    who = talk === nothing ? e.ai : talk.session.agent
    task = if talk === nothing
      cmd, input = message_command(e, root, diff)
      Threads.@spawn read_message(cmd, input; who=who)
    else
      # The agent of the conversation writes it. Its session lives on this thread, so the task does too.
      shown, told = talk_prompt(root, what, basename(path), diff)
      @async clean_message(ask_talk!(talk, shown, told); who)
    end
    e.nodes[:writing] = (task=task, what=what, root=root, path=path, rel=rel, part=part, who=who)
    redraw_in!(e, 0.05)
  catch err
    say_result!(e, trouble(err))
  end
  e
end

"""
The top folder of the repository of what the window `e` shows: a file, or a
folder like a repository's page. It's "" when git keeps neither.
"""
repo_of(e) = (path = e.buf.path; isempty(path) ? "" : git_top(isdir(path) ? path : dirname(path)))

"Save the windows' changes that a commit of `what` takes: those of the file at `path`, or with `:all` those of every file of the repository at `root`"
save_for_commit!(e, root, path, what) = begin
  for o in with_windows(e)
    b = o.buf
    what == :all ? (startswith(b.path, root * "/") && dirty(b) && writes(b) && save!(b)) : (unsaved_in(o, path) && save!(b))
  end
  Git.forget!()   # git is asked again, since what it said can be from before the save
end

"The text of the window's file at `rel` with only its ticked changes, as a commit of them has it, and the diff of that from the last commit"
ticked_text(e, rel) = begin
  d = diff_now(e)
  chosen = d === nothing ? [] : [d.changes[k] for k in ticked(e)]
  isempty(chosen) && error("Tick the changes to commit.")
  part = join(with_changes(d.old, e.buf.lines, chosen), "\n")
  (part, text_diff(rel, join(d.old, "\n"), part))
end

"""
Commit the window's file with `:file`, its ticked changes with `:part`, every
changed file of its repository with `:all`, or the files that are ticked in
git's panel with `:staged`. The agent writes the message, unless the setting says
that you write it. Then the palette asks for it.
"""
commit_scope!(e, what::Symbol) = begin
  e.own || return commit_now!(e, what)
  # The keyboard goes to the page first, so the file that shows is the one in focus, not a row of the sidebar
  focus(e)
  open_palette!(e, what == :file ? :commit : what == :all ? :commit_all : what == :staged ? :commit_staged : :commit_ticked)
  e
end

# The Commit button of the top bar. In agent mode, once you have talked with
# the agent beside the page, the button asks that agent for the commit's
# message in the conversation, as it knows why the page changed. See "an agent
# writes the commit's message", and `commit_talk` and `ask_talk!` in agent/pane.jl.

"Who writes the message of a commit from the Commit button of `e`, in words that go after what it commits"
message_by(e) = e.own ? ", with a message that you write" :
  (p = commit_talk(e); p === nothing ? ", with a message that $(e.ai) writes" : ", with a message that $(p.session.agent) writes in the conversation")

# A click commits the file with a message that the agent of the conversation beside the page writes, or else the
# agent that Settings chose, or that you write when the setting says so. While ticked changes are chosen, it commits only those.
BUTTONS[:commit] = (run=e -> commit_scope!(e, choosing(e) ? :part : :file), off=e -> choosing(e) && isempty(ticked(e)), strong=false,
                    busy=e -> haskey(e.nodes, :writing),
                    tip=e -> haskey(e.nodes, :writing) ? "$(e.nodes[:writing].who) is writing the commit message…" :
                             (!choosing(e) ? "Commit $(basename(e.buf.path))" :
                              (n = length(ticked(e)); n == 0 ? "Tick the changes to commit" : n == 1 ? "Commit the ticked change" : "Commit the $n ticked changes")) *
                             (choosing(e) && isempty(ticked(e)) ? "" : message_by(e)))

"Commit every file of the repository that has a change, with words that say what changed"
commit_all_files!(e, message::String) = begin
  words = strip(message)
  isempty(words) && error("Write what the commit changes")
  root = repo_of(e)
  isempty(root) && error("git doesn't keep $(basename(e.buf.path))")
  save_for_commit!(e, root, e.buf.path, :all)
  commit_all!(e, root, String(words))
  say_result!(e, "Committed all changed files")
  nothing
end
add_command!(commit_all_files!, name=:commit_all, title="Commit every changed file of the repository, with words that say what changed")

"Commit the files that are ticked in git's panel, with words that say what changed"
commit_staged_files!(e, message::String) = begin
  words = strip(message)
  isempty(words) && error("Write what the commit changes")
  root = repo_of(e)
  isempty(root) && error("git doesn't keep $(basename(e.buf.path))")
  commit_staged!(e, root, String(words))
  say_result!(e, "Committed the ticked files")
  nothing
end
add_command!(commit_staged_files!, name=:commit_staged, title="Commit the files that are ticked in git's panel, with words that say what changed")

"Commit the ticked changes of the file, with words that say what they change. The file keeps the changes that aren't ticked."
commit_ticked!(e, message::String) = begin
  words = strip(message)
  isempty(words) && error("Write what the commit changes")
  path = e.buf.path
  root = git_top(dirname(path))
  isempty(root) && error("git doesn't keep $(basename(path))")
  save_for_commit!(e, root, path, :part)
  rel = relpath(realpath(path), realpath(root))
  part, _ = ticked_text(e, rel)
  commit_text!(e, root, rel, part, String(words))
  say_result!(e, "Committed the ticked changes of $(basename(path))")
  nothing
end
add_command!(commit_ticked!, name=:commit_ticked, title="Commit the ticked changes of the file, with words that say what they change")

# The palette lists these while they have something to commit
works_here(e, ::Val{:commit_all}) = (root = repo_of(e); !isempty(root) && !isempty(watch_git!(e, root).changes))
works_here(e, ::Val{:commit_ticked}) = choosing(e) && !isempty(ticked(e))
works_here(e, ::Val{:commit_staged}) = (root = repo_of(e); !isempty(root) && !isempty(watch_git!(e, root).staged))
wide_words(::Val{:commit_all}) = true
wide_words(::Val{:commit_ticked}) = true
wide_words(::Val{:commit_staged}) = true
"Say `words` under the top bar for a while"
say_result!(e, words) = (e.nodes[:result] = (String(words), time()); redraw_in!(e, 0); e)

"Commit what `commit_now!` started, once the agent has written its message. Each window does this in each frame."
commit_tick!(e) = begin
  w = get(e.nodes, :writing, nothing)
  w === nothing && return
  istaskdone(w.task) || return (yield(); redraw_in!(e, 0.05))   # the button spins, and the task that reads the agent gets its turn
  delete!(e.nodes, :writing)
  message = try
    fetch(w.task)
  catch err
    err = err isa TaskFailedException ? err.task.exception : err
    say_result!(e, trouble(err))
    # A message that you write commits the whole file, as the button did before
    w.what == :file && (focus(e); open_palette!(e, :commit))
    return
  end
  try
    w.what == :file ? commit_file!(e, FS.File(w.path), message) :
    w.what == :all ? commit_all!(e, w.root, message) :
    w.what == :staged ? commit_staged!(e, w.root, message) : commit_text!(e, w.root, w.rel, w.part, message)
    what = w.what == :all ? "all changed files" : w.what == :staged ? "the ticked files" : basename(w.path)
    say_result!(e, "Committed $what: $(first(split(message, '\n')))")
  catch err
    say_result!(e, trouble(err))
  end
  nothing
end

each_frame!(commit_tick!)

"Commit what git has for the next commit of the repository at `root`, the files that are ticked in git's panel, with the message `message`"
commit_staged!(e, root, message) = begin
  done, why = Git.act(root, `commit -m $message`)
  Git.forget!()
  redraw_in!(e, 0)
  done || error("git didn't commit them: " * String(first(split(isempty(strip(why)) ? "it gave no reason" : strip(why), '\n'))))
  nothing
end

"Commit every file of the repository at `root` that has a change, with the message `message`"
commit_all!(e, root, message) = begin
  done, why = Git.act(root, `add -A`)
  done && ((done, why) = Git.act(root, `commit -m $message`))
  Git.forget!()
  redraw_in!(e, 0)
  done || error("git didn't commit them: " * String(first(split(isempty(strip(why)) ? "it gave no reason" : strip(why), '\n'))))
  nothing
end

"Commit the text `text` as the file at `rel` of the repository at `root`, and leave the file as it is. The window stops choosing changes."
commit_text!(e, root, rel, text, message) = begin
  done, why = Git.commit_text(root, rel, text, message)
  Git.forget!()
  delete!(e.nodes, :choosing)
  redraw_in!(e, 0)
  done || error("git didn't commit it: " * why)
  nothing
end

# --- choosing the changes to commit ---

"True while the window shows a tick box on each change of its file, for a commit of the ticked ones"
choosing(e) = (c = get(e.nodes, :choosing, nothing); c !== nothing && c.path == e.buf.path && diffing(e))

"Show what changed in the file, with a tick box on each change, or stop"
choose_changes!(e) = begin
  if choosing(e)
    delete!(e.nodes, :choosing)
  else
    e.nodes[:diffing] = e.buf.path
    e.nodes[:choosing] = (path=e.buf.path, ticked=Set{Any}())
  end
  redraw_in!(e, 0)
  e
end

"What keeps the tick of change `k` of the file: its old lines and its new lines, so the tick stays with the change while the lines above it move"
tick_key(e, d, k) = ((o, n) = d.changes[k]; (d.old[o], e.buf.lines[n]))

"The numbers of the changes of the file that are ticked, from the top"
ticked(e) = begin
  choosing(e) || return Int[]
  d = diff_now(e)
  d === nothing && return Int[]
  set = e.nodes[:choosing].ticked
  [k for k in eachindex(d.changes) if tick_key(e, d, k) in set]
end

"A tick box over the page beside one change of the file, while the window chooses the changes to commit"
@def mutable struct TickChange <: SemanticUI
  k::Int = 0   # which change of the file, from the top
end

describe(t::TickChange) = begin
  e = editor(t)
  on = t.k in ticked(e)
  Box(height(20px), padding(7px, 0px), radius(5px), name="Tick", background(ishovered(t) ? colours.active : colours.hover),
    Row(child_gap=4px, Icon(on ? "check2-square" : "square", size=11px, color=on ? colours.accent : colours.dim),
        Box(label("Commit", 11px, color=colours.dim))))
end

cursor(::TickChange) = :hand
onkey(t::TickChange, ::KeyPress{Keys.mouse_left}) = begin
  e = editor(t)
  d = diff_now(e)
  (d === nothing || !choosing(e) || t.k > length(d.changes)) && return handled
  key = tick_key(e, d, t.k)
  set = e.nodes[:choosing].ticked
  key in set ? delete!(set, key) : push!(set, key)
  redraw_in!(e, 0)
  handled
end

# --- the list under the chevron beside the Commit button ---
#
# It has the colours of the other lists that float beside what they're for,
# like the list of a filter's tables: see `float_list`. One outline goes round
# the list, curves in at its top and goes round the Commit button and the
# chevron, so the buttons are a tab of the list, as Centient's lists wrap the
# button that opened them. A click on a way commits that way. Commit part of
# this file shows the tick boxes, and the Commit button commits the ticked
# changes. The switch under them stays open for another click.

"The chevron beside the Commit button: a click shows the list of the ways to commit"
@def mutable struct CommitMore <: SemanticUI end

describe(c::CommitMore) =
  Box(width(16px), height(28px), radius(6px), Alignment.Center, name="CommitMore", background(ishovered(c) ? colours.hover : clear),
    Icon("chevron-down", size=10px, color=colours.dim))

cursor(::CommitMore) = :hand

onkey(c::CommitMore, ev::KeyPress{Keys.mouse_left}) = (open_commit_list!(editor(c), ev.window); handled)

const COMMIT_LIST = :commit_list   # the key of the list's popup
const COMMIT_WAYS = (:file, :part, :all)
const COMMIT_LIST_W = 280px        # how wide the list is
const COMMIT_GAP = 6.0             # px between the buttons and the list, where the outline curves in to the buttons
const COMMIT_ROUND = 6.0           # px: how round the top corners of the buttons' tab are

"The list under the chevron: the three ways to commit, and the switch that says who writes the message"
@def mutable struct CommitList <: SemanticUI
  side::Symbol = :bottom   # where it is beside the chevron, for its caret
end

"A row of the list under the chevron, that commits one way"
@def mutable struct CommitWay <: SemanticUI
  way::Symbol = :file
end

"The row of the list with the switch. On, you write the message of each commit. Off, the agent that Settings chose does."
@def mutable struct OwnMessage <: SemanticUI end

"True while the list of the ways to commit shows under the chevron"
commit_list_open(e) = (w = window_of(e); w !== nothing && any(p -> p.key == COMMIT_LIST, popups(w)))

"Where the Commit button and its chevron are in the window, as one rectangle in px, or nothing before both are drawn"
commit_target(e) = begin
  b, c = get(e.nodes, :commit, nothing), get(e.nodes, :commit_more, nothing)
  (b === nothing || c === nothing) && return nothing
  rb, rc = rect(b), rect(c)
  (rb === nothing || rc === nothing) && return nothing
  (x=num(rb.left), y=num(rb.top), w=num(rc.left + rc.width - rb.left), h=num(rb.height))
end

"Show the list of the ways to commit under the chevron, or take it away when it shows"
open_commit_list!(e, w) = begin
  commit_list_open(e) && return (close_popup!(w, COMMIT_LIST); handled)
  t = commit_target(e)
  t === nothing && return handled
  list = node!(CommitList, e, :commit_list)
  # The list's right edge is in line with the chevron's, so the outline goes straight down that side
  anchor = (px(t.x + t.w) - COMMIT_LIST_W, px(t.y), COMMIT_LIST_W, px(t.h))
  popup!(w, list, anchor=anchor, placement=:below, gap=px(COMMIT_GAP), width=COMMIT_LIST_W, key=COMMIT_LIST, theme=component_theme(e.zoom))
  redraw_in!(e, 0)   # the buttons take the list's colour
  handled
end

describe(l::CommitList) = begin
  e = editor(l)
  c = found_colours()
  ways = [node!(() -> CommitWay(way=w), e, (:commit_way, w)) for w in COMMIT_WAYS]
  # The envelope is under the rows, with its colour, its line and its shadow
  Stack(width(grow=grow), Alignment.Start, name="CommitList",
    node!(CommitEnvelope, e, :commit_envelope),
    Box(width(grow=grow), padding(6px),
      Column(width(grow=grow), Alignment.Start, child_gap=2px,
        ways...,
        Box(width(grow=grow), padding(8px, 4px), Box(width(grow=grow), height(1px), background(c.rule))),
        node!(OwnMessage, e, :own_message))))
end

"What draws the envelope of the list under the chevron, under the list's rows. It's as big as the list."
@def mutable struct CommitEnvelope <: SemanticUI end
describe(::CommitEnvelope) = Box(width(grow=grow), height(grow=grow), name="Envelope")

placed!(l::CommitList, side) = (l.side = side; nothing)
# The list draws nothing itself: its envelope is drawn under its rows, by `CommitEnvelope`. A node's own `draw`
# comes after its rows, so an envelope drawn here would hide them. A window that loaded the code when the list drew
# its envelope itself still has that method until this one takes its place.
draw(ctx, size, ui::ConcreteRect, ::CommitList) = nothing

"""
The outline of the list `frame` under the buttons `target`, as the places
along it, and the outline of what has the list's colour. It goes round the
list, curves in to the buttons' sides and goes round their top, so the list
and the buttons are one shape. It's the shape of the palette's list over a
chip, upside down: see `lens_shapes`.
"""
commit_envelope(frame, target) = begin
  flip(p) = (p[1], -p[2])
  f = (x=frame.x, y=-(frame.y + frame.h), w=frame.w, h=frame.h)
  t = (x=target.x, y=-(target.y + target.h), w=target.w, h=target.h)
  outline, inside, closed = lens_shapes((frame=f, target=t, kind=:chip, round=COMMIT_ROUND))
  (map(flip, outline), map(flip, inside), closed)
end

draw(ctx, size, ui::ConcreteRect, l::CommitEnvelope) = (t = commit_target(editor(l)); t === nothing || draw_envelope(ctx, ui, t); nothing)

"""
Draw the envelope of a list as big as `ui` under the buttons at `t`, a
rectangle in px: the list's shadow, its colour, and its outline, which goes
round the buttons too, as `commit_envelope` says
"""
draw_envelope(ctx, ui, t) = begin
  c = found_colours()
  f = (x=num(ui.left), y=num(ui.top), w=num(ui.width), h=num(ui.height))
  outline, inside, closed = commit_envelope(f, t)
  # The list's shadow, which doesn't fall on the top bar
  with_clip(ctx, 0px, px(t.y + t.h), px(f.x + f.w + 40), px(f.y + f.h + 40)) do
    shade = ink(RGBA(0, 0, 0, dark_page() ? 0.5 : 0.14))
    blur = Skia.sk_maskfilter_new_blur_with_flags(Skia.SK_BLUR_STYLE_NORMAL, 9f0, true)
    Skia.sk_paint_set_maskfilter(shade, blur)
    shape = path_through([(f.x, f.y + 4); (f.x + f.w, f.y + 4); (f.x + f.w, f.y + f.h + 4); (f.x, f.y + f.h + 4)], true)
    Skia.sk_canvas_draw_path(ctx, shape, shade)
    Skia.sk_path_delete(shape)
    Skia.sk_maskfilter_unref(blur)
    Skia.sk_paint_delete(shade)
  end
  paint = ink(c.frame)
  shape = path_through(inside, true)
  Skia.sk_canvas_draw_path(ctx, shape, paint)
  Skia.sk_path_delete(shape)
  Skia.sk_paint_delete(paint)
  trace(ctx, outline, c.line, 1; closed)
end

"What the row of the way `way` says, and the word at its right"
way_words(e, way) = begin
  way == :file && return ("Commit this file", basename(e.buf.path))
  if way == :part
    choosing(e) || return ("Commit part of this file", "")
    n = length(ticked(e))
    return ("Stop choosing changes", n == 0 ? "none ticked" : "$n ticked")
  end
  root = git_top(dirname(e.buf.path))
  n = isempty(root) ? 0 : length(watch_git!(e, root).changes)
  ("Commit all changed files", n == 1 ? "1 file" : "$n files")
end

describe(r::CommitWay) = begin
  words, note = way_words(editor(r), r.way)
  float_row(words, note, picked=ishovered(r))
end
cursor(::CommitWay) = :hand

onkey(r::CommitWay, ev::KeyPress{Keys.mouse_left}) = begin
  e = editor(r)
  close_popup!(ev.window, COMMIT_LIST)
  haskey(e.nodes, :writing) && return handled   # the agent is writing a message
  r.way == :part ? choose_changes!(e) : commit_scope!(e, r.way)
  handled
end

"A switch, on or off, as a `Toggle` of UI.jl looks"
switch_look(on) =
  Row(width(30px), height(18px), radius(9px), padding(2px), Alignment.Center, justify=on ? Alignment.End : Alignment.Start,
      background(on ? colours.accent : found_colours().line),
    Box(width(14px), height(14px), radius(7px), background(colorant"white")))

describe(o::OwnMessage) = begin
  e = editor(o)
  c = found_colours()
  Row(width(grow=grow), height(FLOAT_ROW), padding(8px, 0px), radius(6px), child_gap=8px, Alignment.Center,
      background(ishovered(o) ? c.pick : c.frame),
    Row(width(grow=grow), height(grow=grow), Alignment.Center, clip=true, label("Write the message myself", 13px, color=c.ink)),
    switch_look(e.own))
end

cursor(::OwnMessage) = :hand
onkey(o::OwnMessage, ::KeyPress{Keys.mouse_left}) = (e = editor(o); e.own = !e.own; save_settings!(e); redraw_in!(e, 0); handled)

push!(BLOCK_ICONS, "chevron-down", "square", "check2-square")

# --- what changed in the file that shows ------------------------------------------------------
#
# Beside the Commit button, a button with a diff's mark shows what changed in
# the file since the last commit, in the file itself, as Zed shows it:
#
#   - The lines that are new or changed have a green background, and a green
#     bar in the margin.
#   - The lines that went show in red under the line before them, in the font
#     of code, with a red bar in the margin. They aren't part of the text. A
#     click on them puts the caret at the end of the line above.
#   - A button at the right end of the first line of each change puts the last
#     commit's lines back in its place, as one edit that ⌘Z takes back.
#
# The changes follow what you type. The button is shaded while they show, and
# a click on it hides them. They show for that file until then.
#
# While the changes show, two chevrons beside the button, one over the other,
# go from change to change: up to the change before the caret, down to the
# next one. After the last change comes the first again. Each puts the caret
# at the start of its change, near the top of the window.
#
# The lines that went take room on the page. After `layout!`, in each frame of
# the window, `inline_diff!` moves each item down by the height of the old
# lines over it, in a new list, since `file_lines` keeps the list that it gave.
# It keeps what it did in `e.nodes[:gone]`. The Document draws the old lines
# only for the layout that it made, so printing and slides, which lay the page
# out again, never have them.

"True while the window shows what changed in its file since the last commit, in the file itself"
diffing(e) = !isempty(e.buf.path) && get(e.nodes, :diffing, "") == e.buf.path

"""
Show what changed in the file since the last commit, in the file itself, or
hide it again. Hiding it hides the bars beside the agent's changes too, since
their button goes with it.
"""
toggle_diff!(e) = (diffing(e) ? (delete!(e.nodes, :diffing); delete!(e.nodes, :marking)) : (e.nodes[:diffing] = e.buf.path); redraw_in!(e, 0); e)
add_command!(toggle_diff!, name=:show_changes_in_place, title="Show or hide what changed in the file since the last commit, in the file itself")

BUTTONS[:diff] = (run=toggle_diff!, off=e -> false, strong=false, on=diffing,
                  tip=e -> (diffing(e) ? "Hide what changed in " : "Show what changed in ") * basename(e.buf.path) * " since the last commit")

"""
Show the file at `path` with what changed in it since the last commit marked
in it, as the diff button marks it, and put the caret at the start of its
first change, so the change is in sight. A click on a file in git's panel
does this. A folder, or a file that Ladder shows only in a viewer, just shows.
"""
show_changes!(e, path) = begin
  show_path!(e, path)
  e.buf.path == path || return e
  e.nodes[:diffing] = path
  d = diff_now(e)
  (d === nothing || isempty(d.changes)) && return e
  go_change!(e, 1)
end

"""
The first and the last line of the file that change `(o, n)` has: its new
lines. A change that only took lines away has none of the file's lines, so
the line after them is both: the lines that went show over it.
"""
change_span(b, (o, n)) = (i = clamp(first(n), 1, length(b.lines)); (i, isempty(n) ? i : last(n)))

"Put the caret at the start of change `k` of the file, from the top, near the top of the window"
go_change!(e, k) = begin
  b = e.buf
  i = change_span(b, diff_now(e).changes[k])[1]
  b.caret = b.anchor = (i, 0)
  touch!(e)
  # The change is near the top of the window, with a few lines over it, so the lines under it show too
  hold!(e, max(i - 3, 1), 24px - PAGE_TOP)
  redraw_in!(e, 0)
  e
end

"""
Which change of the file is the next one after the caret, or with `by` of -1
the one before it, from the top. After the last change comes the first, and
before the first comes the last. Nothing while the window shows no change.
"""
change_after(e, by=1) = begin
  d = diff_now(e)
  (d === nothing || isempty(d.changes)) && return nothing
  b = e.buf
  c = b.caret[1]
  # From inside a change, the next one is the one under it, and the one before is the one over it
  k = by > 0 ? findfirst(ch -> change_span(b, ch)[1] > c, d.changes) : findlast(ch -> change_span(b, ch)[2] < c, d.changes)
  something(k, by > 0 ? 1 : length(d.changes))
end

"""
Go to the next change of the file after the caret, or with `by` of -1 to the
one before it. The chevrons beside the diff button do this. From the palette,
the window shows what changed first, if it doesn't yet.
"""
step_change!(e, by=1) = begin
  diffing(e) || (e.nodes[:diffing] = e.buf.path)
  k = change_after(e, by)
  k === nothing ? (redraw_in!(e, 0); e) : go_change!(e, k)
end

"Go to the next change in the file since the last commit, after the caret"
next_change!(e) = step_change!(e, 1)
"Go to the change in the file since the last commit before the caret"
previous_change!(e) = step_change!(e, -1)
add_command!(next_change!, title="Go to the next change in the file since the last commit, after the caret")
add_command!(previous_change!, title="Go to the change in the file since the last commit before the caret")

"What the tooltip of a chevron beside the diff button says: which change it goes to, of how many, while they show"
step_tip(e, by) = begin
  words = by > 0 ? "Next change" : "Previous change"
  k = change_after(e, by)
  k === nothing ? words : "$words ($k of $(length(diff_now(e).changes)))"
end

"The lines of each file in a commit, by the repository's top folder, the file's place in it and the commit's hash. A file that the commit hasn't got has none."
const COMMITTED = Dict{Tuple{String,String,String},Vector{String}}()

"The lines of the file at `rel` in the commit `head` of the repository at `root`, split as a page splits a file's text"
committed_lines(root, rel, head) = begin
  length(COMMITTED) > 100 && empty!(COMMITTED)
  get!(COMMITTED, (root, rel, head)) do
    # Before its first commit a repository's head is "(initial)", which is no commit
    text = isempty(head) || startswith(head, "(") ? nothing : Git.at_commit(root, head, rel)
    text === nothing ? String[] : String.(split(replace(text, "\r\n" => "\n"), '\n'))
  end
end

"""
What changed in the file that shows since the last commit, while the window
shows it in the file: the changes, each a run of the old lines and the run of
the new lines that took its place, and the old lines. It's nothing while the
window doesn't show them, and on a page that's in columns, in slides or under
a block that fills the window. It's worked out again when the text changes,
and after a commit.
"""
diff_now(e) = begin
  diffing(e) || return nothing
  b = e.buf
  b.view in (:code, :markdown, :text) || return nothing
  (lowered(e) === nothing && slideshow(e) === nothing && !haskey(e.nodes, :columns)) || return nothing
  root = git_top(dirname(b.path))
  isempty(root) && return nothing
  s = watch_git!(e, root)
  s.known || return nothing
  key = (b.path, b.version, s.head)
  kept = get(e.nodes, :diff_now, nothing)
  kept !== nothing && kept[1] == key && return kept[2]
  rel = try relpath(realpath(b.path), realpath(root)) catch; return nothing end
  old = committed_lines(root, rel, s.head)
  found = (changes=changes(old, b.lines), old=old)
  e.nodes[:diff_now] = (key, found)
  found
end

"How tall a line that went from the file is: as tall as a line of a file of code"
gone_h(e) = code_size(e) * 1.5 / CODE_SCALE

"""
Make room in the layout for the lines that went from the file, while the
window shows what changed: each item moves down by the height of the old
lines over it. The old lines go under the item that has the line before them.
"""
inline_diff!(e) = begin
  d = diff_now(e)
  (d === nothing || isempty(e.layout)) && return (delete!(e.nodes, :gone); nothing)
  items = e.layout
  was = get(e.nodes, :gone, nothing)
  # A file of code keeps its layout while its text is the same, so the room is made once
  was !== nothing && was.from === items && was.diff === d && return (e.layout = was.layout; nothing)
  lh = gone_h(e)
  firsts = Int[it.first for it in items]
  shows(i) = clamp(searchsortedlast(firsts, i), 1, length(items))   # the item that shows line `i`
  after = Dict{Int,Vector{String}}()   # the old lines under each item, by the item's last line
  above = String[]                     # the old lines over the first line
  for (o, n) in d.changes
    isempty(o) && continue
    first(n) <= 1 ? append!(above, d.old[o]) : append!(get!(Vector{String}, after, items[shows(first(n) - 1)].last), d.old[o])
  end
  # Only new lines are marked where they are, and nothing moves
  out = isempty(above) && isempty(after) ? items : Vector{Item}(undef, length(items))
  if out !== items
    shift = lh * length(above)
    for (k, it) in enumerate(items)
      out[k] = shift == 0px ? it : Item(it.first, it.last, it.top + shift, it.tall, it.content)
      rows = get(after, it.last, nothing)
      rows === nothing || (shift += lh * length(rows))
    end
  end
  # Where each change starts on the page: at its first line that went, or else at its first new line
  tops = map(d.changes) do (o, n)
    isempty(o) ? out[shows(first(n))].top :
    first(n) <= 1 ? out[1].top - lh * length(above) : (it = out[shows(first(n) - 1)]; it.top + it.tall)
  end
  e.layout = out
  e.nodes[:gone] = (from=items, layout=out, diff=d, after=after, above=above, lh=lh, tops=tops)
  nothing
end

"What `inline_diff!` did to the layout that the window shows now, or nothing"
gone_now(e) = (g = get(e.nodes, :gone, nothing); g !== nothing && g.layout === e.layout ? g : nothing)

"The lines `lines` that went from the file: red rows each `lh` tall, with the colours of code in the file's language"
gone_rows(e, lines, lh) = begin
  lang, open, size = file_lang(e.buf.path), '\0', code_size(e)
  face(kind) = Face(codefont(), kind == :comment ? codeslant() : codestyle(), size, kind == :plain ? colours.ink : getfield(colours, kind), false)
  rows = Any[]
  for l in lines
    text = replace(l, '\t' => " "^e.indent)
    parts = [p for t in tokens(text, lang, open) if !isempty(t.text) for p in spared(t.text, face(t.kind))]
    open = left_open(text, lang, open)   # a docstring of several lines goes on in the next line
    push!(rows, Row(width(grow=grow), height(lh), clip=true, background(RGBA(git_colour(:deleted), 0.13)), parts...))
  end
  Column(width(grow=grow), Alignment.Start, name="Gone", rows...)
end

"The geometry `g` of the item `it`, with the lines that went from under it, while the window shows what changed"
gone_under(e, it, g) = begin
  gone = gone_now(e)
  rows = gone === nothing ? nothing : get(gone.after, it.last, nothing)
  rows === nothing ? g : Column(width(grow=grow), Alignment.Start, g, gone_rows(e, rows, gone.lh))
end

"The room over the first item that the Document builds, with the lines that went from over the first line when that item is the first"
gone_over(e, items, lo) = begin
  gone = gone_now(e)
  (lo == 1 && gone !== nothing && !isempty(gone.above)) || return (spacer(items[lo].top),)
  (spacer(items[1].top - gone.lh * length(gone.above)), gone_rows(e, gone.above, gone.lh))
end

"True when the item `it` shows a line that's new or changed since the last commit"
is_new(gone, it) = any(((_, n),) -> !isempty(n) && first(n) <= it.last && last(n) >= it.first, gone.diff.changes)

"Draw a green background behind each line on screen that's new or changed since the last commit. The Document is at `ui`."
tint_new(ctx, e, ui) = begin
  gone = gone_now(e)
  gone === nothing && return
  tint = RGBA(git_colour(:new), 0.12)
  for it in e.layout[e.shown]
    is_new(gone, it) && rectangle(ctx, ui.left, ui.top + it.top, ui.width, it.tall, background=tint, border=0px)
  end
end

"Draw a bar in the margin beside each line on screen that's new or changed, and beside the lines that went. The text starts at `left`, and its first line is at `top`."
draw_diff_bars(ctx, e, left, top) = begin
  gone = gone_now(e)
  gone === nothing && return
  green, red = RGBA(git_colour(:new), 0.8), RGBA(git_colour(:deleted), 0.8)
  shown = e.layout[e.shown]
  isempty(shown) && return
  # Beside numbered lines the bar is in the gap between the numbers and the text
  left = numbered(e.buf) ? left + 8px : left
  if first(e.shown) == 1 && !isempty(gone.above)
    h = gone.lh * length(gone.above)
    rectangle(ctx, left - 16px, top + e.layout[1].top - h, 3px, h, background=red, border=0px)
  end
  for it in shown
    is_new(gone, it) && rectangle(ctx, left - 16px, top + it.top, 3px, it.tall, background=green, border=0px)
    rows = get(gone.after, it.last, nothing)
    rows === nothing || rectangle(ctx, left - 16px, top + it.top + it.tall, 3px, gone.lh * length(rows), background=red, border=0px)
  end
end

"""
Put the last commit's lines back in place of change `k` of the file, from the
top, as one edit that ⌘Z takes back. A change that only added lines takes
them out, and one that only took lines away puts them back. The caret stays
with the text it was in: the button is clicked with the mouse, so the caret
doesn't go to the change. If it did, it could stop on a ``` line, and the
block would show its code.
"""
put_change_back!(e, k::Int) = begin
  d = diff_now(e)
  (d === nothing || !(1 <= k <= length(d.changes))) && return e
  o, n = d.changes[k]
  b = e.buf
  old, lines = d.old[o], b.lines
  if isempty(n)
    # The old lines go back over the line that's in their place now, or after the last line
    at = first(n)
    lo, hi, new = at <= length(lines) ? ((at, 0), (at, 0), join(old, "\n") * "\n") :
                  (line_end(b, length(lines)), line_end(b, length(lines)), "\n" * join(old, "\n"))
  elseif isempty(o)
    # The new lines go, with the line break after them, or the one before them at the end of the file
    lo, hi, new = (first(n), 0), line_end(b, last(n)), ""
    last(n) < length(lines) ? (hi = (last(n) + 1, 0)) : first(n) > 1 && (lo = line_end(b, first(n) - 1))
  else
    lo, hi, new = (first(n), 0), line_end(b, last(n)), join(old, "\n")
  end
  caret, anchor = b.caret, b.anchor
  edit!(b, lo, hi, new)
  b.caret, b.anchor = moved(caret, lo, hi, b.caret), moved(anchor, lo, hi, b.caret)
  redraw_in!(e, 0)
  e
end

"A button over the page that puts back one change of the file: the last commit's lines take its place"
@def mutable struct PutBack <: SemanticUI
  k::Int = 0   # which change of the file, from the top
end

describe(p::PutBack) =
  Box(height(20px), padding(7px, 0px), radius(5px), name="PutBack", background(ishovered(p) ? colours.active : colours.hover),
    Row(child_gap=4px, Icon("arrow-counterclockwise", size=11px, color=colours.dim), Box(label("Put back", 11px, color=colours.dim))))

cursor(::PutBack) = :hand
onkey(p::PutBack, ::KeyPress{Keys.mouse_left}) = (put_change_back!(editor(p), p.k); handled)

"""
The buttons that put back each change on screen, over the page at the right
end of each change's first line: the first line that went, or else the first
new line. A window that can't write its file has none.
"""
put_back_over(e) = begin
  gone = gone_now(e)
  (gone === nothing || !writes(e.buf)) && return ()
  w, h = window_size(e)
  right = text_left(e) + e.width
  out = Any[]
  for (k, y) in enumerate(gone.tops)
    y = above_page(e) + page_top(e) + y - e.scroll.offset + 1px
    above_page(e) <= y <= h - 20px || continue
    # While the window chooses the changes to commit, each has a tick box too
    tick = choosing(e) ? (node!(() -> TickChange(k=k), e, (:tick_change, k)),) : ()
    push!(out, Row(width(grow=grow), height(grow=grow), Alignment.Start, justify=Alignment.End, padding(y, max(w - right, 0px), 0px, 0px),
                   child_gap=6px, tick..., node!(() -> PutBack(k=k), e, (:put_back, k))))
  end
  out
end

"""
The button of the top bar that shows what changed in the file since the last
commit, while it has a change to commit. While what changed shows, the
chevrons beside it go to the change before the caret and the next one, and
if an agent changed the page, a button with an eye before it shows the
agent's changes.
"""
diff_part(e) = commit_change(e, e.buf.path) === nothing ? () : begin
  on = diffing(e)
  marks = on && !isempty(theirs(e)) ? (button(e, :marks, "eye"), Box(width(4px))) : ()
  (Row(Alignment.Center, name="Diff", marks..., button(e, :diff, "file-diff"),
       (on ? (Column(Alignment.Center, button(e, :previous_change, "chevron-up"), button(e, :next_change, "chevron-down")),) : ())...),)
end

# The chevrons are half buttons, one over the other. Each does nothing while what changed shows and there's no change
# to go to, as in slides.
for (action, by, half) in ((:previous_change, -1, :top), (:next_change, 1, :bottom))
  BUTTONS[action] = (run=e -> step_change!(e, by), off=e -> change_after(e) === nothing, strong=false, half=half,
                     tip=e -> step_tip(e, by))
end
push!(BLOCK_ICONS, "arrow-counterclockwise")

works_here(e, ::Val{:show_changes_in_place}) = diffing(e) || commit_change(e, e.buf.path) !== nothing
works_here(e, ::Val{:next_change}) = commit_change(e, e.buf.path) !== nothing
works_here(e, ::Val{:previous_change}) = commit_change(e, e.buf.path) !== nothing
