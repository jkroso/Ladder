# What kind a folder is: its own page on the Mac and on a web server, the kinds that Ladder finds by itself, and Show Folder As
#
# A folder's kind changes how the folder and its files show. A kind that code
# gave the folder's path comes first, then the kind that the folder's own page
# gives it, and then the kind that Ladder finds by itself. Each section below
# says more. Their commands are in main.jl.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "github.com/jkroso/UI.jl/Interface/objc" libobjc cls sel msg nsstring with_pool
@use "./notes_page" => NotesPages NotesDirectory
@use "./macfolders_page" => MacPages DownloadsDirectory TrashDirectory PicturesDirectory ScreenshotsDirectory mac_kind
@use "./git" => Git
@use "./remote" => Remote
@use "./guard" => Guard
@use "github.com/jkroso/URI.jl/FSPath" FSPath
@use "github.com/jkroso/URI.jl/FS" => FS AbstractDirectory
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
@use "./desktop_page" exports...
@use "./blog_page" exports...
@use "./git_page" exports...
@use "./news_page" exports...

export ask_web_folders!, FOLDER_PAGE_KINDS, folder_page_lines, FOLDER_PAGE_STOPPED,
       FOLDER_PAGES_DUE, FOLDER_PAGES_RAN, folder_pages_tick!, FOLDER_PAGES_WORLD, folder_pages!,
       folder_shown!, found_kind, kind_from, kind_name, kind_page, kind_page_written, KindChoice,
       OWN_KINDS, page_kind, pages_callable, PLACE_KINDS, run_folder_pages!, run_web_folder_pages!,
       show_folder_as!, site_answers, SITE_ANSWERS, SITE_ASKER, site_runs!, sites_file,
       stop_trusting_site!, trust_bar, trust_panel, trust_site!, typed_as, WEB_FOLDER_PAGES,
       web_folders_tick!, web_page, WEB_PAGES_DUE, WebFolderPage

# --- a folder's own page ----------------------------------------------------------------
#
# A folder says what kind of folder it is with a page of its own: a file
# called `.ladder`, in the folder. The page is Markdown, as the startup page
# is, and Ladder runs its `julia` blocks the same way: from the top, in one
# module, where `Ladder` is this module. The value of the last block is the
# folder's kind, a type under `AbstractDirectory`.
#
#     This disk is a media library.
#
#     ```julia
#     @use "github.com/jkroso/Media.lad" => Media
#     Media.library(Ladder)
#     ```
#
# The startup page is for code that works all the time that Ladder is open,
# like a look for new email. A folder's page is for code that only its folder
# needs. Ladder runs it when it first meets the folder: when the sidebar lists
# the folder, or a link leads to it. So the code isn't loaded when Ladder
# starts, and the folder is the same kind of folder on each Mac that opens it.
#
# A page that's saved again runs again, in a new module, and a folder that
# loses its page is plain. Code that fails leaves the folder plain, and a
# toast says which line of the page failed: see "toasts". A kind that
# code gave the folder by its path, in `FS.kinds`, comes before the page's. A
# folder of a kind doesn't ask the pages of the folders in it: the kind says
# what they are, with its method of `FS.kind`.
#
# A page loads code, and that code is newer than the frame or the click that
# met the folder, which can't call it. So the page doesn't run where the
# folder is met. It waits, the folder is plain until the frame is made, and
# then the page runs: see `describe(e::Editor)`. Each window lists its folder
# again in the next frame. A link to a folder can't wait, because what it does
# is the kind's to say, so `follow!` runs the page first and goes on with
# `Base.invokelatest`.

"What each folder's page gave when it last ran, by the folder's path: when the page was saved, and the folder's kind, or nothing"
const FOLDER_PAGE_KINDS = Dict{String,Tuple{Float64,Any}}()
"The paths of the folders whose page waits to run, because it's new or it was saved again"
const FOLDER_PAGES_DUE = String[]
"How many times the kind of a folder with a page can have changed. A window lists its folder again when this has grown."
const FOLDER_PAGES_RAN = Ref(0)
"What failed in a folder's page when it last ran, or \"\", and when"
const FOLDER_PAGE_STOPPED = Ref(("", 0.0))
"The age of Julia's code when the last page had run. Code that started before then can't call what a page loaded."
const FOLDER_PAGES_WORLD = Ref{UInt}(0)

"True when the code that asks started after the last page ran, so it can call what the pages loaded"
pages_callable() = Base.tls_world_age() >= FOLDER_PAGES_WORLD[]

"""
The kind that the page of the folder at `path` gives the folder, or nothing
when the folder has no page, or its page gave none. A page that hasn't run
since it was saved waits to run, and the folder keeps the kind that it had.
Code that started before a page ran can't make a folder of a kind from a
page, so to that code the folder is plain.
"""
page_kind(path::AbstractString) = begin
  # A folder that macOS doesn't let Ladder look in, like the Trash without Full Disk Access, has no page
  st = try stat(joinpath(path, FOLDER_PAGE)) catch; nothing end
  kept = get(FOLDER_PAGE_KINDS, path, nothing)
  if st === nothing || !isfile(st)
    # The folder lost its page, so it's plain from now on, and a toast about the page goes
    kept === nothing || (delete!(FOLDER_PAGE_KINDS, path); FOLDER_PAGES_RAN[] += 1; untoast!(path))
    return nothing
  end
  if (kept === nothing || kept[1] != mtime(st)) && !(path in FOLDER_PAGES_DUE)
    push!(FOLDER_PAGES_DUE, path)
    foreach(e -> redraw_in!(e, 0), editors)   # the page runs when a frame is made
  end
  kept !== nothing && pages_callable() ? kept[2] : nothing
end

"""
The kind of the folder at `path`, when the folder that it's in doesn't say: the
kind that code gave it by its path, or else the kind that its own page gives
it, or else the kind that Ladder finds for it by itself (see `found_kind`).
"""
folder_kind(path::FSPath) = begin
  k = get(FS.kinds, path, nothing)
  k === nothing || return k
  k = page_kind(string(path))
  k === nothing || return k
  found_kind(string(path))
end

# A folder of no kind asks the page of each folder in it
FS.kind(d::FS.Directory, path::FSPath) = folder_kind(path)

"""
Run the page of each folder that waits. The kind that a page gives is its
folder's from now on. Code that was running before this can't call what the
pages loaded, so it goes on with `Base.invokelatest`, or leaves the folder to
the next frame.
"""
run_folder_pages!() = begin
  while !isempty(FOLDER_PAGES_DUE)
    path = popfirst!(FOLDER_PAGES_DUE)
    file = joinpath(path, FOLDER_PAGE)
    isfile(file) || continue
    at = mtime(file)
    kind = try
      value = Base.invokelatest(page_value, code_module!(file), file)
      value === nothing || (value isa Type && value <: AbstractDirectory) ||
        error("The last `julia` block of the page gave $(Base.invokelatest(repr, value)), which isn't a kind of folder.")
      untoast!(path)
      value
    catch err
      FOLDER_PAGE_STOPPED[] = ("The $FOLDER_PAGE page of $(basename(path)) stopped. " * trouble(err), time())
      toast!(path, "The $FOLDER_PAGE page of $(basename(path)) stopped", trouble(err))
      nothing
    end
    FOLDER_PAGE_KINDS[path] = (at, kind)
  end
  FOLDER_PAGES_RAN[] += 1
  FOLDER_PAGES_WORLD[] = Base.get_world_counter()
  foreach(e -> redraw_in!(e, 0), editors)
  nothing
end

"""
Run the page of the folder at `path`, and of each folder that it's in, when
it waits. Code that calls this goes on with `Base.invokelatest`, because what
the pages loaded is newer than the call.
"""
folder_pages!(path::AbstractString) = begin
  # A folder is met only when the folders that it's in have their kinds, so each look can find one more page
  for _ in 1:length(splitpath(path))
    try FS.get(FSPath(path)) catch end
    isempty(FOLDER_PAGES_DUE) && break
    run_folder_pages!()
  end
  nothing
end

"List the sidebar's folder again when the kind of a folder with a page can have changed since the window last listed it"
folder_pages_tick!(e) = begin
  (get(e.nodes, :folder_pages, 0) == FOLDER_PAGES_RAN[] || !pages_callable()) && return
  e.nodes[:folder_pages] = FOLDER_PAGES_RAN[]
  list_files!(e)
  delete!(e.nodes, :page_object)   # the folder that the page shows is found again too
  show_opened!(e)   # a window that was opened on a folder shows it in the page, if its page said that its kind does
  nothing
end

# --- a web folder's own page ------------------------------------------------------------
#
# A folder on a web server gives itself a kind as a folder on the Mac does:
# with a page called `.ladder`, in the folder. A folder's address ends in a /,
# like https://example.com/notes/, so its page is at
# https://example.com/notes/.ladder. The kind changes how the pages in the
# folder show, as it does on the Mac: the pages of a blog look as the blog's
# site does, wherever the blog is.
#
# When Ladder asks a server for a page, it asks for the .ladder page of each
# folder that the page is in too, from the top of the site down, and at the
# same time. It asks once for each folder while Ladder is open. Reload Page
# asks again. A folder with no such page, or one that sends HTML for it, has
# no kind of its own.
#
# The page's code comes from whoever runs the site, so Ladder runs it only
# for a site that you trust: the shield in the top bar of a page of the site,
# and Trust Site and Stop Trusting Site in the command palette. The sandbox
# can't check such a page, since its code adds to Ladder's own functions. A
# site that you don't trust has no kinds, and its pages show plain. Ladder
# keeps whether you trust each site in the file "sites that run code" beside
# the settings file. Code that ran stays loaded until Ladder quits, but a site
# that you stop trusting has no kinds from then on.
#
# A page that's allowed runs as a folder's page on the Mac does: from the
# top, after the frame, in a module named by its address. The value of its
# last `julia` block is the folder's kind. A web folder of no kind takes the
# kind of its own .ladder page. A folder in a folder of a kind takes what
# that kind says, with its method of `web_kind`: a folder in a blog is a
# section of the blog, unless its own page says otherwise.
#
# A page from a web server is a `WebPage`, in a `WebFolder` of the folder's
# kind, so a kind has methods for the pages on the web that it holds, as it
# has for its files on the Mac:
#
#     page_foot(e, d::WebFolder{Notes}, o::WebPage) = ...
#     matter_view(e, d::WebFolder{<:BlogFolder}, o::WebPage, rows) = ...
#
# The page itself still runs no code: see "a page from a web server".

"What Ladder has of the .ladder page of a web folder"
mutable struct WebFolderPage
  coming::Any               # the Remote.Coming while the page is on its way, or nothing
  lines::Vector{String}     # the page's lines, or none when the folder has no such page
  code::Bool                # the page has a `julia` block
  ran::Bool                 # its code has run since these lines came
  kind::Any                 # the kind that its code gave, or nothing
end

"The .ladder page of each web folder that Ladder asked for, by the folder's address"
const WEB_FOLDER_PAGES = Dict{String,WebFolderPage}()
"The addresses of the web folders whose page waits to run"
const WEB_PAGES_DUE = String[]

"The site of `address`: how it's asked for and the computer that it's on, like https://example.com"
web_site(address::AbstractString) = (m = match(r"^https?://[^/?#]*"i, address); m === nothing ? "" : lowercase(m.match))

"""
Ask the server of the page at `address` for the .ladder page of each folder
that the page is in, unless Ladder has it or is getting it. With `again`,
Ladder asks again for each page that it has.
"""
ask_web_folders!(address::AbstractString; again=false) = begin
  for f in Remote.folders(address)
    kept = get(WEB_FOLDER_PAGES, f, nothing)
    (kept === nothing || (again && kept.coming === nothing)) || continue
    c = Remote.ask(f * FOLDER_PAGE, getter=(args...) -> PAGE_GETTER[](args...))
    kept === nothing ? (WEB_FOLDER_PAGES[f] = WebFolderPage(c, String[], false, false, nothing)) : (kept.coming = c)
  end
  nothing
end

"The lines of the .ladder page that a server sent, or none. A page of HTML, like one that says the server has no such page, isn't one."
folder_page_lines(got) =
  Remote.ok(got) && (got.type in Remote.MARKDOWN_TYPES || got.type in Remote.VAGUE_TYPES) ? Remote.lines(got) : String[]

"""
Look whether a .ladder page that Ladder asked a web server for has come.
Each frame of `e` calls this. A page whose lines changed runs again.
"""
web_folders_tick!(e) = begin
  waits = false
  for (f, p) in WEB_FOLDER_PAGES
    p.coming === nothing && continue
    got = Remote.landed(p.coming)
    got === nothing && (waits = true; continue)
    p.coming = nothing
    lines = folder_page_lines(got)
    lines == p.lines && continue
    p.lines, p.ran, p.kind = lines, false, nothing
    p.code = !isempty(page_code(f * FOLDER_PAGE, lines))
    foreach(e -> redraw_in!(e, 0), editors)
  end
  waits && redraw_in!(e, 0.05)
  nothing
end

"The file in Ladder's own folder that keeps whether you trust each site: whether Ladder runs the code of its pages with no sandbox"
sites_file() = joinpath(dirname(settings_file()), "sites that run code")

"Your answers from `sites_file()`, as the file was when it was last read: the file, when it was saved, and the answer for each site"
const SITE_ANSWERS = Ref(("", 0.0, Dict{String,Bool}()))

"Your answer for each site: true when Ladder runs the code of its pages, and false when it doesn't"
site_answers() = begin
  file = sites_file()
  at = mtime(file)   # 0 when there's no file
  kept = SITE_ANSWERS[]
  kept[1] == file && kept[2] == at && return kept[3]
  said = Dict{String,Bool}()
  for line in (isfile(file) ? readlines(file) : String[])
    parts = split(line, '\t', limit=2)
    length(parts) == 2 && (said[String(parts[2])] = parts[1] == "yes")
  end
  SITE_ANSWERS[] = (file, at, said)
  said
end

"True when you trust `site`: Ladder runs the code of its pages with no sandbox, and its .ladder pages. False or nothing when you don't, and the code runs in the sandbox."
site_runs(site::AbstractString) = get(site_answers(), site, nothing)

"Keep whether you trust `site`. `also` are editors that aren't in `editors`, like one of a test."
site_runs!(site::AbstractString, yes::Bool, also=()) = begin
  said = copy(site_answers())
  said[site] = yes
  mkpath(dirname(sites_file()))
  write(sites_file(), join(("$(said[s] ? "yes" : "no")\t$s" for s in sort!(collect(keys(said)))), "\n") * "\n")
  SITE_ANSWERS[] = ("", 0.0, said)   # the file is read again
  # Each page of the site that a window holds runs its code again, with no sandbox or in it
  site_code_changed!(site, also)
  foreach(e -> redraw_in!(e, 0), editors)
  nothing
end

"""
The kind that the .ladder page of the web folder at `f` gives the folder, or
nothing: the folder has no page, its page gave no kind, or its site doesn't
run code. A page whose site you haven't answered for waits for your answer,
and a page that hasn't run waits to run after the frame. Code that started
before a page ran can't make a folder of its kind, as on the Mac.
"""
web_page_kind(f::AbstractString) = begin
  p = get(WEB_FOLDER_PAGES, f, nothing)
  (p === nothing || !p.code) && return nothing
  runs = site_runs(web_site(f))
  if !p.ran
    runs === true && !(f in WEB_PAGES_DUE) && push!(WEB_PAGES_DUE, f)
    return nothing
  end
  runs === true && pages_callable() ? p.kind : nothing
end

"""
The kind of the web folder at `f`, which is in the web folder `d`: a type
under `AbstractDirectory`, as `FS.kind` gives one to a folder on the Mac. A
folder in a folder of no kind takes the kind of its own .ladder page. A kind
of folder has a method of this when the folders in it have a kind too.
"""
web_kind(d::WebFolder, f::AbstractString) = FS.Directory
web_kind(d::WebFolder{FS.Directory}, f::AbstractString) = something(web_page_kind(f), FS.Directory)

"The page at `address` on a web server, in the web folders that it's in, each of its kind"
web_page(address::AbstractString) = begin
  d = nothing
  for f in Remote.folders(address)
    k = d === nothing ? something(web_page_kind(f), FS.Directory) : web_kind(d, f)
    d = WebFolder{k}(f, d)
  end
  d === nothing ? nothing : WebPage(address, d)
end

"""
Run the .ladder page of each web folder that waits, as `run_folder_pages!`
runs the page of a folder on the Mac. The kind that a page gives is its
folder's until the page changes. Code that fails leaves the folder plain,
and the window says which line failed.
"""
run_web_folder_pages!() = begin
  while !isempty(WEB_PAGES_DUE)
    f = popfirst!(WEB_PAGES_DUE)
    p = get(WEB_FOLDER_PAGES, f, nothing)
    (p === nothing || p.ran || site_runs(web_site(f)) !== true) && continue
    address = f * FOLDER_PAGE
    p.kind = try
      value = Base.invokelatest(page_value, code_module!(address), address, p.lines)
      value === nothing || (value isa Type && value <: AbstractDirectory) ||
        error("The last `julia` block of the page gave $(Base.invokelatest(repr, value)), which isn't a kind of folder.")
      untoast!(f)
      value
    catch err
      FOLDER_PAGE_STOPPED[] = ("The $FOLDER_PAGE page of $(Remote.label(f)) stopped. " * trouble(err), time())
      toast!(f, "The $FOLDER_PAGE page of $(Remote.label(f)) stopped", trouble(err))
      nothing
    end
    p.ran = true
  end
  FOLDER_PAGES_WORLD[] = Base.get_world_counter()
  foreach(e -> redraw_in!(e, 0), editors)
  nothing
end

"""
Ask whether you trust `site`, in a panel: whether its pages' code runs with
no sandbox. True when you say that you do. The button that Return presses is
Cancel.
"""
trust_panel(site::AbstractString) = with_pool() do
  alert = msg(msg(cls("NSAlert"), "alloc"), "init")
  msg(alert, "setMessageText:", nsstring("Trust $(Remote.host(site))?"))
  msg(alert, "setInformativeText:", nsstring(
    "The code of its pages will run with no sandbox, so nothing will stop it. " *
    "It can do anything that a program on your Mac can do, like delete your files or send them away.\n\n" *
    "A .ladder page of the site can change how its pages show too."))
  msg(alert, "addButtonWithTitle:", nsstring("Cancel"))
  msg(alert, "addButtonWithTitle:", nsstring("Trust"))
  # 1000 is the first button, Cancel
  yes = ccall((:objc_msgSend, libobjc), Int, (Ptr{Cvoid}, Ptr{Cvoid}), alert, sel("runModal")) == 1001
  msg(alert, "release")
  yes
end

"What asks whether you trust a site, before the trust toggle turns on. A test puts its own function here."
const SITE_ASKER = Ref{Function}(trust_panel)

"Trust Site: let the site of the page from the web that shows run the code of its pages with no sandbox"
trust_site!(e) = begin
  in_browser(e.buf.path) || return e
  site = page_site(e.buf.path)
  yes = SITE_ASKER[](site)
  # The panel took the keyboard, so the window never heard the keys that answered it come up
  w = window_of(e)
  w === nothing || (w.keys = Keys(0))
  yes && site_runs!(site, true, (e,))
  e
end

"Stop Trusting Site: put the code of the pages of the site of the page from the web that shows back in the sandbox"
stop_trusting_site!(e) = (in_browser(e.buf.path) && site_runs!(page_site(e.buf.path), false, (e,)); e)

works_here(e, ::Val{:trust_site}) = in_browser(e.buf.path) && site_runs(page_site(e.buf.path)) !== true
works_here(e, ::Val{:stop_trusting_site}) = in_browser(e.buf.path) && site_runs(page_site(e.buf.path)) === true


"""
The shield in the top bar of a page from the web. It's locked while the code
of the site's pages runs in the sandbox, and a click asks whether you trust
the site. It has a line through it while you trust the site, and a click
puts the site's code back in the sandbox.
"""
trust_bar(e) = begin
  in_browser(e.buf.path) || return ()
  b = button(e, :trust, "shield-lock")
  b.icon = site_runs(page_site(e.buf.path)) === true ? "shield-slash" : "shield-lock"
  (b,)
end
BAR_PARTS[:trust] = trust_bar
BUTTONS[:trust] = (
  run=e -> site_runs(page_site(e.buf.path)) === true ? stop_trusting_site!(e) : trust_site!(e),
  tip=e -> (host = Remote.host(page_site(e.buf.path));
            site_runs(page_site(e.buf.path)) === true ?
              "You trust $host: its code runs with no sandbox. Click to put it back in the sandbox" :
              "The code of $host runs in a sandbox. Click to trust $host"),
  off=e -> false,
  strong=false)
push!(BLOCK_ICONS, "shield-lock", "shield-slash")

# --- the kinds of folder that Ladder finds by itself ----------------------------------------
#
# A folder needs no page of its own to be one of these kinds. Ladder knows it
# by what's in it, or by where it is on the Mac:
#
#   - a folder with a `.git` in it is the top folder of a repository, and it
#     and the folders in it are each a `GitDirectory`
#   - a folder with an `.obsidian` in it is a folder of notes, and it and the
#     folders in it are each a `NotesDirectory`
#   - the Mac's Downloads folder, its Pictures folder, the folder that it saves
#     screenshots to and its Trash each have a kind: see "the Mac's own folders"
#   - ~/News is a folder of news: see "a folder of news"
#   - ~/Browser is the browser folder, with a globe for its icon: see "the browser folder"
#
# A kind that code gave the folder by its path comes first, and then the kind
# that the folder's own page gives it. So a page still makes any of these
# folders another kind, and makes any other folder one of these kinds.

"The kind of each folder that Ladder knows by where it is, by the folder's path. A test adds a folder of its own."
const PLACE_KINDS = Dict{String,Any}()

"The kind that Ladder gives the folder at `path` by itself, from where it is or from what's in it. It's `FS.Directory` for a folder of no kind."
found_kind(path::AbstractString) = begin
  k = get(PLACE_KINDS, path, nothing)
  k === nothing || return k
  path == news_folder() && return NewsDirectory
  path == browser_folder() && return BrowserDirectory
  k = mac_kind(path)
  k === nothing || return k
  # Obsidian keeps its settings for a folder of notes in a folder of this name. A folder
  # that macOS doesn't let Ladder look in is plain.
  try
    isdir(joinpath(path, ".obsidian")) && return NotesDirectory
    Git.istop(path) && return GitDirectory
  catch
  end
  FS.Directory
end

# --- a kind for a folder, in one step ---------------------------------------------------
#
# Show Folder As, in the command palette, gives the folder in focus a kind. It
# asks for the kind: one of Ladder's own, like Desktop or Notes, or the
# address of a repository on GitHub that has one, like
# github.com/jkroso/Media.lad. Then it writes the folder's own page, the file
# `.ladder`, which says the kind: see "a folder's own page". Plain takes the
# page away again.
#
# A kind of Ladder's own is in the list when it's in `OWN_KINDS`, by the name
# that `kind_name` gives its type. A repository has a kind of folder when its
# main file has a function `kind` that takes Ladder's module and gives the
# type:
#
#     kind(Ladder::Module) = library(Ladder)
#
# The page that the command writes for a repository calls `kind_from`, which
# loads the repository and calls that function. The command writes only a
# page that it wrote before. A page that you wrote stays as it is.

"What the list of Show Folder As calls the kind of folder `T`"
kind_name(T::Type) = replace(replace(string(nameof(T)), r"Directory$" => ""), r"(?<=[a-z0-9])(?=[A-Z])" => " ")

"The kinds of folder of Ladder's own that Show Folder As offers. Code from the startup page can add a type of Ladder's."
const OWN_KINDS = Any[DesktopDirectory, NotesDirectory, BlogDirectory, DownloadsDirectory, PicturesDirectory, ScreenshotsDirectory, NewsDirectory]

"""
A kind of folder, for a command to take. `from` is one of Ladder's own types,
or the address of a repository on GitHub that has a kind, or nothing for a
plain folder.
"""
struct KindChoice
  name::String
  from::Any
end
choices_for(::Type{KindChoice}, e) = [[KindChoice(kind_name(T), T) for T in OWN_KINDS]; KindChoice("Plain", nothing)]
# An address can have https:// before it, as a browser shows it, and .git or a / after it
typed_as(::Type{KindChoice}, text) = begin
  m = match(r"^(?:https?://)?(github\.com/[\w\-.]+/[\w\-.]+?)(?:\.git)?/?$", strip(text))
  # The list calls it by its owner and its name, which fit in a row
  m === nothing ? nothing : KindChoice(String(split(m[1], '/', limit=2)[2]), String(m[1]))
end
worded(k::KindChoice) = k.name
sidenote(k::KindChoice) = k.from === nothing ? "as the Finder has it" : k.from isa AbstractString ? "from GitHub" : ""

"The text of the page that gives a folder the kind `k`"
kind_page(k::KindChoice) =
  k.from isa AbstractString ? "Ladder shows this folder with $(k.from).\n\n```julia\nLadder.kind_from(\"$(k.from)\")\n```\n" :
                              "Ladder shows this folder as a kind of its own: $(k.name).\n\n```julia\nLadder.$(nameof(k.from))\n```\n"

"True when `text` is a folder's page as `kind_page` writes it, and not one that somebody wrote"
kind_page_written(text::AbstractString) =
  occursin(r"^Ladder shows this folder [^\n]*\n\n```julia\nLadder\.\w+(\(\"[^\"\n]*\"\))?\n```\n$", text)

"""
The kind of folder that the repository `source` has, like
`github.com/jkroso/Media.lad`: what the function `kind` of its main file gives
for Ladder's module. Kip gets the repository if it isn't on this Mac. A
folder's own page calls this.
"""
kind_from(source::AbstractString) = begin
  m = Base.invokelatest(Kip.require, String(source), homedir())
  Base.invokelatest(isdefined, m, :kind) || error("$source has no function called kind, so it has no kind of folder.")
  Base.invokelatest(Base.invokelatest(getglobal, m, :kind), Guard.LADDER[])
end

"""
Show a folder as a kind of folder: one of Ladder's own, or one from a
repository on GitHub. It writes the folder's own page, and the window shows
the folder.
"""
show_folder_as!(e, folder::AbstractDirectory, kind::KindChoice) = begin
  path = path_of(folder)
  file = joinpath(path, FOLDER_PAGE)
  text = kind.from === nothing ? "" : kind_page(kind)
  was = isfile(file) ? read(file, String) : ""
  was == text && return nothing
  isempty(was) || kind_page_written(was) ||
    error("$(basename(path)) has a $FOLDER_PAGE page that somebody wrote. Change that page to change the folder's kind.")
  isempty(text) ? rm(file) : write(file, text)
  # The page runs now, and what it loaded is newer than this call
  folder_pages!(path)
  Base.invokelatest(folder_shown!, e, path)
  nothing
end

"Show the folder at `path` in the window of `e`, as its kind shows it, after its page ran"
folder_shown!(e, path) = begin
  list_files!(e)
  delete!(e.nodes, :page_object)
  d = try FS.get(FSPath(path)) catch; nothing end
  d isa AbstractDirectory && open!(e, d)
  nothing
end
