# The startup page, which is yours from the start, and the commands that a page's own code makes

@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" window_of
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in! popup! close_popup!
@use "./markdown" words
@use "./guard" => Guard
@use "github.com/jkroso/UI.jl/Interface/draw" Bubble
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
@use "./code_names" exports...
@use "./file_blocks" exports...
@use "./toasts" exports...
@use "./commands" exports...

export STARTUP, STARTUP_FOLDER, STARTUP_SHOWS, page_commands, result_tick!, startup_text,
       startup_tick!, stopped_tick!

# --- the startup page ------------------------------------------------------------------
#
# Ladder has one page that's yours from the start: the startup page. It does
# two things.
#
#   - It's the page that shows the first time you open Ladder, and when
#     Ladder can't open where you were when you last quit it: see "where
#     Ladder opens". So it's the place for links to your pages and a list of
#     what's to do.
#   - Each time Ladder starts, it runs the Julia code of the page: each
#     `julia` block, from the top, in one module. Julia does the same with
#     its startup.jl. So the page is where you load code that adds to Ladder,
#     and it can say in words what each piece of code is for.
#
# The code has what a Julia file that Kip loads has, like `@use`, and one name
# more: `Ladder`, which is this module. Code that adds to Ladder calls
# Ladder's own functions and adds to its tables, as Ladder's own files do.
# There's no other layer between the two. The part before this one has the
# tables for what Ladder does at its own times.
#
# The page is `startup.md`, in the folder of the pages of the settings, since
# it's where you set what Ladder is. The Settings page has a link to it. The
# first time Ladder starts, it writes the page, with links to the welcome page
# and to the settings. From then on the page is yours, and Ladder never writes
# to it: it isn't one of the pages that a newer Ladder brings, and git leaves
# it out of Ladder's own repository. Only the command Keep This Change adds to
# it, when you run it: see "ask for a change to a thing".
#
# Code that fails stops the code after it, and Ladder opens all the same. The
# window then says which line of the page failed, in a toast that stays until
# you close it: see "toasts".

"A folder for the startup page that isn't the folder of the settings. A test names a folder of its own here."
const STARTUP_FOLDER = Ref("")

"The page that Ladder opens when no file is named and it has no place to open from the last time (see `take_place!`), and whose Julia code it runs when it starts"
startup_page() = isempty(STARTUP_FOLDER[]) ? settings_page("startup.md") : joinpath(STARTUP_FOLDER[], "startup.md")

"What the startup page says the first time, before you change it. Its links go from the folder of the settings."
startup_text() = """
  # Home

  Ladder opens this page the first time it starts, and when the place where you last were is gone. The page is yours, so change it as you like.

  - [Welcome](../welcome.md) shows what Ladder can do.
  - [Settings](settings.md) has the colours, the font and the keys. ⌘, opens it too.

  ## Code that runs when Ladder starts

  Each time Ladder starts, it runs the Julia code on this page, from the top. Code here can add to Ladder: the name `Ladder` is Ladder itself. The block below does nothing yet.

  ```julia
  # @use "github.com/you/something" => Something
  # Something.start(Ladder)
  ```
  """

"Write the startup page, if there's none. It gives the page's path."
startup_page!() = begin
  path = startup_page()
  if !isfile(path)
    mkpath(dirname(path))
    write(path, startup_text())
  end
  path
end

"What failed in the code of the startup page when Ladder started, or \"\", and when Ladder started"
const STARTUP = Ref(("", 0.0))
const STARTUP_SHOWS = 12.0   # seconds that the window says what a command of the page gave back

"""
A new module for the code of the startup page, or of a folder's page, at
`path`. It has what a Julia file that Kip loads has, like `@use`, and the
name `Ladder`, which is this module. Its name is the page's path.
"""
code_module(path::AbstractString) = begin
  m = Module(page_module_name(path))
  Core.eval(m, :(const Kip = $Kip))
  Core.eval(m, :(using .Kip))
  Core.eval(m, :(eval(x) = Core.eval($m, x)))
  Core.eval(m, :(include(file) = Base.include($m, file)))
  Core.eval(m, :(const Ladder = $(Guard.LADDER[])))
  m
end

"""
A new module for the code of the startup page, or of a folder's page, at
`path`, for Ladder to run the page in now. It's the page's module from now on,
so code that you run on the page in a window runs where Ladder ran it: what
the startup page loaded, like `Mail`, is there.
"""
code_module!(path::AbstractString) = (PAGE_MODULES[page_key(path)] = code_module(path))

"True when Ladder runs the code of the page at `path` itself: the startup page, and a folder's page"
ladder_runs(path::AbstractString) = basename(path) == FOLDER_PAGE || page_key(path) == page_key(startup_page())

"""
Run the code of the startup page: each of its `julia` blocks, from the top, in
one module, which this gives. In that module `Ladder` is this module. Code
that fails stops the code after it, and `STARTUP[]` then says what failed.
"""
run_startup!(path=startup_page()) = begin
  m = code_module!(path)
  STARTUP[] = try
    isfile(path) && Base.invokelatest(run_page!, m, path)
    ("", time())
  catch err
    (trouble(err), time())
  end
  # A window says so with a toast, which stays until it's closed: the code runs before the first window opens
  words = STARTUP[][1]
  isempty(words) ? untoast!(:startup) : toast!(:startup, "The startup page stopped", words)
  m
end

# --- a page's own commands ---
#
# A function that a page's own Julia code makes is a command of the palette
# while the page shows, once the page's code has run. Its arguments are its
# chips, as they are for a command of Ladder's own, so it needs a type for
# each that the palette can ask for, like `invoice(client::String,
# hours::Number)`. Its documentation says what it does. What it gives back
# shows under the top bar for a while.

"""
The functions that the Julia code of the page that `e` shows made, as
commands. The page's code must have run, so its module has them.
"""
page_commands(e) = begin
  b = e.buf
  (b.view == :markdown && !isempty(b.path)) || return Command[]
  m = get(PAGE_MODULES, page_key(b.path), nothing)
  m === nothing && return Command[]
  out = Command[]
  for made in page_bounds(e)
    made.span === nothing || continue
    name = Symbol(made.name)
    any(c -> c.name == name, out) && continue
    f = Base.invokelatest(isdefined, m, name) ? Base.invokelatest(getglobal, m, name) : nothing
    (f isa Function && parentmodule(f) === m) || continue
    # A function whose arguments the palette can't ask for, like one with no types, isn't a command
    isempty(callable_methods(f, in_focus(e))) && continue
    title = try first_words(f) catch; "" end
    c = Ref{Command}()
    c[] = Command(name, isempty(title) ? "A function of this page" : title, :page, "", (e, w, _) -> open_palette!(e, c[]), f)
    push!(out, c[])
  end
  out
end

"Say what a command of the page gave back, under the top bar, for a while"
result_tick!(e) = (r = get(e.nodes, :result, nothing); r === nothing || stopped_tick!(e, :result, r...))

"Show the toasts that say what failed in the code of the startup page or of a folder's page, and what a command of the page gave back"
startup_tick!(e) = (toasts_tick!(e); result_tick!(e))

"Say `words` under the top bar for a while after the time `since`. `key` names what failed, and \"\" says nothing."
stopped_tick!(e, key::Symbol, words, since) = begin
  win = window_of(e)
  (isempty(words) || win === nothing || get(e.nodes, (key, :told), 0.0) == since) && return
  left = STARTUP_SHOWS - (time() - since)
  if left <= 0
    close_popup!(win, key)
    e.nodes[(key, :told)] = since
  else
    # The words look as a tooltip does, under the middle of the top bar
    wide, _ = window_size(e)
    spot = (wide / 2, 0px, 1px, max(bar_bottom(e) - 8px, 0px))
    popup!(win, Bubble(content=Box(padding(8px, 5px), label(words, 12px, color=TIP_INK)), target=spot),
           anchor=spot, placement=:bottom, gap=6px, key=key, input=false)
    redraw_in!(e, left)
  end
  nothing
end
