# A page of the web in the page, and an HTML file as its page
#
# A `view` block shows a page of the web, or the page of an HTML file, with
# Ladder's own engine: see web/browser.jl and "a view of another file". Its
# line is the page's address, like https://julialang.org, or the name of an
# HTML file beside the document. A block whose first line starts with a tag,
# like `<h1>`, holds the HTML of the page itself.
#
# The page's scripts run, and the page is yours to use where it is, as a
# model in the page is:
#
#   - A click follows a link or presses a button, and a drag goes to the
#     page's scripts, as a drag turns a model that a script draws. After a
#     click the page has the keyboard, so you type in its fields. Esc gives
#     the keyboard back to the document.
#   - The wheel scrolls the document, so the page doesn't stop it as it goes
#     past. With ⌘ held the wheel is the page's, and so is a pinch: a script
#     hears it as a browser sends it, as the wheel with Ctrl held.
#   - A click with ⌘ held goes to the page, as the button beside the block's
#     top right corner does. With ⌥ held the document shows the block's line.
#
# The block's line always says the page that shows. When a link goes to
# another page, the line becomes that page's address, and ⌘Z in the document
# takes it back, and the page with it. A page that the block held goes back
# into the block as its HTML.
#
# A block in the language `web` is a `view` block too: `web` is the name that
# it had before.
#
# A page of an email asks the web for nothing, so a `view` block there shows
# no page of the web. A window that isn't on the screen asks for nothing
# either, unless a test put its own function in `WEB_GETTER`.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI describe
@use "github.com/jkroso/UI.jl/Interface/draw" redraw_in!
@use "github.com/jkroso/UI.jl/Interface/window" dark_mode
@use "./html" html
@use "./sheet" shown
@use "github.com/jkroso/Units.jl" => Units
@use "github.com/jkroso/Units.jl/Money" => Cash
@use "./eml" => Eml
@use "./web/browser" => Browsers
@use "./web/files" => Webfiles
@use "./base" exports...
@use "./linkcard_view" exports...

export WEBVIEW, WEB_HIGH, WEB_LEAST, WEB_GETTER, web_online, web_files, web_source, web_lines,
       web_says, SI_UNITS, script_value, script_sums, send_sums!, HTMLPage, html_part, WEB_DARK,
       html_browser, html_shown, html_page, carry_sums!

"The name that a `view` block of a page of the web had before, which still works"
const WEBVIEW = "web"
const WEB_HIGH = 420px     # how tall the page is in the document at the most, before the zoom
const WEB_LEAST = 60px     # and at the least
push!(BLOCK_ICONS, "globe", "arrow-left", "arrow-right", "arrow-clockwise", "box-arrow-up-right", "fullscreen-exit")

"What gets a file from the web for the page of a `view` block. A test puts its own function here, so that it uses no network."
const WEB_GETTER = Ref{Function}(Webfiles.curl)

"True when a `view` block of `e` may ask the web for its page: the document isn't an email, and its window is on the screen or a test stands in for `curl`"
web_online(e) = !Eml.isemail(e.buf.path) && (WEB_GETTER[] !== Webfiles.curl || on_screen(e))

"""
What gets the files of a page that `e` shows. With `curl`, a file that its
site says may be kept is kept on the disk for the next page that names it. A
test's own getter keeps nothing there.
"""
web_files(e) = Webfiles.Files(getter=(a...; k...) -> WEB_GETTER[](a...; k...), online=() -> web_online(e),
                              cache=WEB_GETTER[] === Webfiles.curl ? Webfiles.CACHE[] : "")

"""
What the lines of a `view` block of a page ask for: its address, or the HTML
of one with the address that the addresses in it are from. The name of a
file beside the document is that file.
"""
web_source(e, lines) = begin
  i = findfirst(l -> !isempty(strip(l)), lines)
  i === nothing && return (address="", html="", base="")
  dir = docdir(e)
  first = String(strip(lines[i]))
  # A block that starts with a tag holds the page itself. Its addresses are from the document's folder.
  startswith(first, '<') && return (address="", html=join(lines, "\n"), base="file://" * joinpath(abspath(dir), "page.html"))
  if !occursin(r"^[a-z][a-z0-9+.-]*:"i, first)
    file = startswith(first, '~') ? expanduser(first) : joinpath(dir, first)
    isfile(file) && return (address=abspath(file), html="", base="")
  end
  (address=first, html="", base="")
end

"The lines of a `view` block that say `page`: its address, or the HTML of a page that was written in the block. A file in the document's folder is said by its name there."
web_lines(e, page) = begin
  page isa Browsers.Written && return String.(split(page.html, '\n'))
  file = Webfiles.path(page)
  dir = joinpath(abspath(docdir(e)), "")
  file !== nothing && startswith(file, dir) && isfile(file) && return [relpath(file, dir)]
  [String(page)]
end

"True when `lines`, the lines of a `view` block, say `page`"
web_says(e, lines, page) = begin
  src = web_source(e, lines)
  page isa Browsers.Written && return src.html == page.html && src.base == page.base
  isempty(src.html) || return false
  said = Browsers.whole(src.address)
  # A file can be said by its path or by a file:// address
  file = Webfiles.path(said)
  file === nothing ? said == page : file == Webfiles.path(page)
end

# The scripts of the page in a `view` block can read the sums of the document. `ladder.sums` has the value of each sum
# in a line of text that gives a name, like !`span = 70m`, and `ladder.shown` has the text that the document shows for
# it. The page hears the event `sums` when it's given them, and again each time they change, as while a number is
# dragged. A page whose scripts wait for a module can find them already there, so it reads them at its start too.

"The units that a page's script gets amounts in: SI units, with the kilogram for mass"
const SI_UNITS = ((Units.Length, Units.m), (Units.Mass, Units.kg), (Units.Time, Units.s), (Units.Current, Units.A),
                  (Units.Temperature, Units.K))

"""
What a script of a web page gets for the value `x` of a sum: a number, true
or false, or words. An amount is a number in SI units: 70m is 70, 150kW is
150000, 500g is 0.5 and 98% is 0.98. Money is a number of its currency, so
25USD/W is 25. A value that is none of these is nothing.
"""
script_value(x::Bool) = x
script_value(x::AbstractString) = String(x)
script_value(x::Real) = Float64(x)
script_value(x::Units.Unit) = try
  # Units.jl has no rates between currencies, so the currency comes out first
  bits, _ = Units.flatten_units(typeof(x))
  i = findfirst(u -> Units.unwrap(u) <: Cash.Money, bits)
  i === nothing || (x = x / Units.unwrap(bits[i])(1))
  x isa Units.Unit || return Float64(x)
  # Units.jl's own base for mass is the gram, so the amount is converted to SI units by name
  si = nothing
  for d in Units.dimensions(typeof(x))
    D = Units.unwrap(d)
    D <: Units.NullDimension && continue
    j = findfirst(((kind, _),) -> D <: kind, SI_UNITS)
    j === nothing && return nothing
    u = SI_UNITS[j][2]^Units.power(d)
    si = si === nothing ? u : si * u
  end
  si === nothing ? convert(Float64, x) : Float64(convert(si, x).value)
catch
  nothing
end
script_value(x) = nothing

"""
The sums of the document of `e` that give a name, for the scripts of a web
page: what each name came to as `script_value` gives it, and the text that
the document shows for it. A sum that went wrong, or that hasn't run, is
left out. When two sums give one name, the lower one counts.
"""
script_sums(e) = begin
  b = e.buf
  sums, shown = Dict{String,Any}(), Dict{String,Any}()
  values = get(e.nodes, (:sum_values, b.path), nothing)
  values === nothing && return sums, shown
  for (_, code, n) in given_and_sums(e, typemax(Int), true)[2]
    haskey(values, (code, n)) || continue
    out = get(e.nodes, (:inline, b.path, code, n), nothing)
    (out isa Tuple && !out[2]) || continue
    x = script_value(values[(code, n)])
    x === nothing && continue
    name = String(sum_name(code))
    sums[name], shown[name] = x, out[1]
  end
  sums, shown
end

"""
Give the scripts of the page of the `view` block `v` the sums of the document,
if they've changed since it was last given them, and tell the page with the
event `sums`.
"""
send_sums!(v) = begin
  b = web_browser(v)
  l = Browsers.live(b)
  # The page starts as the browser draws, which doesn't lay the block out again. So the block looks again soon.
  (l === nothing || Browsers.loading(b)) && (isempty(b.address) && isempty(b.html) || redraw_in!(v, 0.25))
  l === nothing && return v
  e = editor(v)
  # The sums run as their lines are laid out, so `sums_run` says when they may have changed
  (v.sent !== nothing && v.sent[1] === l && v.sent[2] == sums_run[]) && return v
  sums, shown = script_sums(e)
  if v.sent === nothing || v.sent[1] !== l || v.sent[3] != sums || v.sent[4] != shown
    l.scripts.js["ladder"] = Dict{String,Any}("sums" => sums, "shown" => shown)
    # A script that draws runs as the page's scripts do, so the window gets its own drawing back after it
    Browsers.Live.fire!(l, "sums")
    # The sums under the block run after it's laid out, so another frame gives the page those too
    redraw_in!(v, 0)
  end
  v.sent = (l, sums_run[], sums, shown)
  v
end

# --- an HTML file as its page ---------------------------------------------------------------------
#
# An HTML file has four levels. Over its bits, its bytes in hexadecimal and its
# text is the page that its HTML makes, which Ladder's own engine lays out and
# draws, as a `view` block does. That's its highest level, the ladder, so an
# HTML file opens as its page, and ⌘E shows its text.
#
# The page covers the page's whole space in the window, as it would a
# browser's window, and it's yours to use: the wheel scrolls it, a click
# follows a link or presses a button, its scripts run, and you type in its
# fields. After a click it has the keyboard, so the arrows and Space scroll
# it. When the file changes on the disk, the page shows it afresh.

"""
True when the page shows an HTML file at one of its levels: as its page, its
text, its bytes in hexadecimal or its bits. A page of HTML from a web server
counts too: see "a page from a web server".
"""
html_page(b::Buffer) = b.view in FILE_VIEWS && lowercase(splitext(b.path)[2]) in HTMLS && isfile(b.path) && text_file(b.path)

"True when the page shows an HTML file as the page that its HTML makes"
html_shown(e) = e.buf.view == :file && html_page(e.buf)

"What shows an HTML file as the page that its HTML makes"
@def mutable struct HTMLPage <: SemanticUI
  path::String = ""
  read::Float64 = 0.0      # when the file had last changed, as the page last read it
  browser::Any = nothing   # the Browser that lays the page out and shows it
end

"The HTMLPage of the HTML file that the page shows. A file that another file takes the window from loses its page, and its scripts end."
html_part(e) = node!(() -> HTMLPage(path=e.buf.path), e, (:html, e.buf.path))

"""
Whether a page of HTML that fills Ladder's page is laid out for a screen in
dark mode: a function that gives true or false. It follows the Mac, as a
browser does, and not Ladder's theme: with the Mac's appearance on Auto, a
site that can be dark is dark at night. A test puts its own function here.
"""
const WEB_DARK = Ref{Any}(() -> dark_mode())

"""
The Browser of `v`, which gets the file and the files that it names, and shows
the page. A page of the browser folder is from its web address: the Browser
gets the files that it names from there, and a link of the page goes where
Ladder goes, so ⌘⌥← comes back.
"""
html_browser(v::HTMLPage) = begin
  v.browser === nothing || return v.browser
  e = editor(v)
  files = web_files(e)
  v.read = mtime(v.path)
  in_browser(v.path) && return v.browser = own!(v, Browsers.Browser(html=read(v.path, String), base=web_address(v.path), files=files,
                                                                    open=url -> BROWSER[](url), leads=url -> follow_remote!(e, url)))
  v.browser = own!(v, Browsers.Browser(address=v.path, files=files, open=url -> BROWSER[](url)))
end

describe(v::HTMLPage) = begin
  e = editor(v)
  b = html_browser(v)
  # A file that changed on the disk shows afresh, as after a browser's reload. A page of the browser folder has its HTML
  # from the file, so it gets a new Browser.
  at = mtime(v.path)
  at == v.read || (v.read = at; in_browser(v.path) ? (v.browser = nothing; b = html_browser(v)) : Browsers.reload!(b))
  carry_sums!(v, b)
  b.zoom = round(Float64(e.zoom), digits=2)
  b.wide, b.high = page_room(e)
  b.dark = WEB_DARK[]()
  Box(width(grow=grow), height(grow=grow), Alignment.Start, name="Web page", b)
end

keyboard_part(v::HTMLPage) = html_browser(v)

"""
Give the page of the HTML file of `v` the sums that a `view` block gave it, when
the window went to the file from that block. A page of the file that opens
another way gets none.
"""
carry_sums!(v::HTMLPage, b) = begin
  e = editor(v)
  key = (:carried_sums, v.path)
  c = get(e.nodes, key, nothing)
  c === nothing && return v
  c.page === v || (delete!(e.nodes, key); return v)
  l = Browsers.live(b)
  # The page starts as the browser draws, which doesn't lay the page out again. So it looks again soon.
  (l === nothing || Browsers.loading(b)) && (redraw_in!(v, 0.25); return v)
  c.given === l && return v
  l.scripts.js["ladder"] = Dict{String,Any}("sums" => c.sums, "shown" => c.shown)
  Browsers.Live.fire!(l, "sums")
  e.nodes[key] = merge(c, (given=l,))
  v
end
