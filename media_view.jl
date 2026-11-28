# Pictures, HTML, video and sound in the text of a page, a table from a CSV file, and what was said in a video
#
# A line that holds only a picture, like ![plan](plan.png), shows the picture.
# The line's own text shows again while the caret is on it. The picture can be
# a file, named from the document's folder, or an address on the web. One from
# the web is fetched once, and kept in a folder of the Mac's caches. The
# picture's path can have spaces in it, like ![Costs](../images/air cost.png),
# or be between < and >.

@use "github.com/jkroso/Prospects.jl" @def
@use "github.com/jkroso/MiniFB.jl"... onfiledrop onscroll
@use "github.com/jkroso/UI.jl/Interface/Geometric"...
@use "github.com/jkroso/UI.jl/Interface/Specific"...
@use "github.com/jkroso/UI.jl/Interface/abstract" SemanticUI with_theme describe reuse! window_of handled
@use "github.com/jkroso/UI.jl/Interface/draw" ui draw ishovered cursor show_tooltip! hide_tooltip! redraw_in! rect popup! Pinch onpinch clipboard!
@use "github.com/jkroso/UI.jl/Interface/fonts" weight_of
@use "github.com/jkroso/UI.jl/Interface/image" image_source
@use "github.com/jkroso/UI.jl/Interface/Semantic/Icon" Icon
@use "github.com/jkroso/UI.jl/Interface/Semantic/Player" VideoPlayer card_bottom
@use "github.com/jkroso/UI.jl/Interface/Semantic/Recorder" AudioRecorder record! stop! plays
@use "github.com/jkroso/UI.jl/Interface/media" recording
@use "./pictures" natural
@use "./transcribe" Transcription check! finished phrases words_between
@use "./html" escape
@use "./markdown" Kind words
@use "./sheet" parts shown
@use "./spreadsheet" moved
@use "./chart" => Charts
@use "./csv" => Csvs
@use "./eml" => Eml
@use "./web" => Web
@use "./web/fetch" => Webfetch
@use "./remote" => Remote
@use "./look" exports...
@use "./flow" exports...
@use "./buffer" exports...
@use "./editor_type" exports...
@use "./faces" exports...
@use "./rich" exports...
@use "./blocks" exports...
@use "./shared" exports...
@use "./host" exports...
@use "./folder_page" exports...
@use "./linkcard_view" exports...
@use "./sketch_view" exports...
@use "./takeoff_view" exports...
@use "./fill_view" exports...
@use "./file_view" exports...
@use "./live_view" exports...
@use "./email_view" exports...
@use "./csv_view" celltext

export Picture, pictures_dir, picture_item, HTML_BLOCK_TAGS, HTML_RAW_TAGS, HTML_OPENS,
       HTML_ATTRIBUTE, HTML_LONE, HTML_CLOSES, HTML_RUNS, html_end, html_runs, html_typed,
       HTMLBlock, html_base, html_file, html_bytes, html_arrivals!, LADDER_FONT_FILES, LADDER_FACES,
       font_faces, html_css, html_item, html_link, html_follow!, RETRY, downloads, MediaNote,
       web_file, web_media, media_file, local_media, download!, media_note, TABLE_ROWS, table_files,
       TableLine, TableMore, FileGrid, file_grid, row_flows, caption_high, has_more, rows_shown,
       chart_files, media_part, clock_time, video_item, TRANSCRIPT_W, TRANSCRIPT_HIGH,
       TRANSCRIPT_PAD, COPIED_FOR, Transcript, CopyButton, video_words, transcribe_video!,
       transcript_of, transcript_w, said_text, SoundLine, TranscribeButton, TRANSCRIBE_H,
       TRANSCRIBE_GAP, recorders, transcriptions, transcribed, recorder, sound_file, sound_line,
       sound_item, sound_over, transcribing, add_recording!, new_recording, add_words!, sound_tick!,
       chart_file, file_table, istable, table_rows, chart_path, table_file, table_html

"A picture that a line of the document shows"
@def mutable struct Picture <: SemanticUI
  line::Int = 0
  key::String = ""   # of the picture, for an Image
  w::px = 0px
  h::px = 0px
end

describe(p::Picture) = Box(width(grow=grow), Alignment.Start, fillable(p, (:picture, p.key), Image(p.key, fixed(p.w), height(p.h), radius(4px))))
cursor(::Picture) = :arrow
onpinch(p::Picture, ev::Pinch) = pinch_open(p, ev)
onkey(p::Picture, ev::KeyPress{Keys.mouse_left}) = click_page!(p, ev)

pictures_dir() = joinpath(homedir(), "Library", "Caches", "Ladder", "pictures")

"""
The file that holds the picture at the web address `url`. It's nothing while
the picture is fetched, and if it can't be. The picture goes in the browser
folder, at its place on its site: see "the browser folder". One that no file
of that folder can keep goes in Ladder's own folder of pictures.
"""
fetched(e, url) = begin
  file = something(browser_path(url), joinpath(pictures_dir(), string(hash(url), base=16)))
  state = get(fetches, url, :none)
  if state === :none
    # A picture that an earlier window fetched is still there
    isfile(file) && filesize(file) > 0 && return (fetches[url] = file)
    state = fetches[url] = try
      mkpath(dirname(file))
      Webfetch.start(url, file * ".part"; seconds=30)
    catch
      nothing
    end
  end
  state isa Base.Process || return state
  if process_exited(state)
    part = file * ".part"
    (success(state) && isfile(part)) || return (fetches[url] = nothing)
    mv(part, file, force=true)
    in_browser(file) && keep_got!(file, url, read(file))
    return fetches[url] = file
  end
  redraw_in!(e, 0.2)   # look again soon
  nothing
end

"What line `i` shows when it holds only a picture that can be shown, or nothing"
picture_item(e, i) = begin
  m = match(PICTURE_LINE, e.buf.lines[i])
  m === nothing && return nothing
  src = unescaped(String(m[2]))
  # A page from a web server names its pictures from its own address, and shows no file of the Mac
  far = in_browser(e.buf.path)
  far && (src = something(remote_src(e, String(m[2])), ""); isempty(src) && return nothing)
  (note = media_note(e, i, src)) === nothing || return note   # a video or a sound that's on its way from the web
  if !far
    (made = table_item(e, i)) === nothing || return made        # a CSV file shows as a table
    # A sound file shows a player, and so does a video file
    sound = sound_file(docdir(e), e.buf.lines[i])
    sound === nothing || return sound_item(e, sound)
  end
  video = video_item(e, src)
  video === nothing || return video
  # The address of a web page shows a card
  card = card_item(e, i, src, unescaped(String(m[1])))
  card === nothing || return card
  path = startswith(src, r"https?://") ? fetched(e, src) : abspath(docdir(e), expanduser(src))
  key = path === nothing ? nothing : picture_key(path)
  key === nothing && return nothing
  source = image_source(key)
  # A picture shows at its own size, and no wider than the text. A picture of pixels is a pixel to the
  # px. One that macOS read, like an SVG, is the size that macOS says it is.
  size = natural(key)
  w = min(e.width, px(size === nothing ? source.width : size[1]))
  h = w * source.height / source.width
  node = node!(Picture, e, (:picture, i))
  node.line, node.key, node.w, node.h = i, key, w, h
  own!(node!(Document, e, :document), node)
  Live(node, h + 2LIVE_GAP)
end

# --- HTML in a page ------------------------------------------------------------------------
#
# Markdown can have HTML on lines of its own, and Ladder draws those lines as
# a browser does, with its own HTML engine (web/), in the page's font and
# colours. So <h2 style="text-align: center">Plans</h2> is a heading in the
# middle of the page, and <img src="plan.png" width="300"> is a picture 300 px
# wide. Which lines are HTML is as CommonMark says:
#
#   - A line that starts with the tag of a block, like <div, <h2, <p or
#     <table, or with its closing tag, like </div>. The HTML goes on to the
#     line before the next empty line.
#   - A line that holds only one tag of another kind, like <img src="a.png">
#     or <span>, and doesn't come straight after a line of text. Its HTML goes
#     on to the line before the next empty line too.
#   - A line that starts with <pre, <script, <style or <textarea. Its HTML
#     goes on to the line that closes it, over empty lines too.
#
# HTML in a line of text, like <b>bold</b> or <br>, shows as it's written.
# The lines of the HTML show as they're written while the caret is in them,
# as the code of a diagram does. Each run of lines is a page of its own: a
# <style> in it styles only those lines, and no script runs. A picture is
# named from the page's folder, or from the page's address in a page from a
# web server, which shows no file of the Mac. Ladder fetches a picture from
# the web once, as it does a picture on a line of Markdown. A click on a link
# of the HTML follows it as a click on a link of the text does. An email's
# lines are never HTML: its text was typed as text.

"The tags that start HTML wherever they start a line, as CommonMark lists them"
const HTML_BLOCK_TAGS = Set(split("""address article aside base basefont blockquote body caption center col colgroup dd details
  dialog dir div dl dt fieldset figcaption figure footer form frame frameset h1 h2 h3 h4 h5 h6 head header hr html iframe
  legend li link main menu menuitem nav noframes ol optgroup option p param search section summary table tbody td tfoot th
  thead title tr track ul"""))
"The tags whose HTML goes on to the line that closes them, over empty lines too"
const HTML_RAW_TAGS = ("pre", "script", "style", "textarea")
const HTML_OPENS = r"^ {0,3}<(/?)([A-Za-z][A-Za-z0-9-]*)(?=[ \t>]|/>|$)"   # a tag at the start of a line, and its name
const HTML_ATTRIBUTE = "\\s+[A-Za-z_:][A-Za-z0-9_.:-]*(?:\\s*=\\s*(?:[^\\s\"'=<>`]+|'[^']*'|\"[^\"]*\"))?"
const HTML_LONE = Regex("^ {0,3}(?:<[A-Za-z][A-Za-z0-9-]*(?:" * HTML_ATTRIBUTE * ")*\\s*/?>|</[A-Za-z][A-Za-z0-9-]*\\s*>)\\s*\$")   # a line with one tag and nothing else
const HTML_CLOSES = r"</(?:pre|script|style|textarea)>"i
# The lines of HTML of each page, with the kinds of line that they were found from
const HTML_RUNS = WeakKeyDict{Any,Tuple{Any,Vector{Tuple{Int,Int}}}}()

"The last line of the HTML that starts at line `i`, or 0 when no HTML starts there"
html_end(b::Buffer, ks, i::Int) = begin
  ks[i].kind == Kind.paragraph || return 0
  text = b.lines[i]
  startswith(lstrip(text), '<') || return 0
  m = match(HTML_OPENS, text)
  name = m === nothing ? "" : lowercase(m[2])
  if m !== nothing && isempty(m[1]) && name in HTML_RAW_TAGS
    # It goes on to the line that closes it. With none, or with a code block first, it's no HTML.
    for j in i:length(ks)
      j > i && ks[j].kind in (Kind.fence, Kind.code) && return 0
      occursin(HTML_CLOSES, b.lines[j]) && return j
    end
    return 0
  end
  (name in HTML_BLOCK_TAGS || (occursin(HTML_LONE, text) && !(name in HTML_RAW_TAGS) && (i == 1 || ks[i-1].kind != Kind.paragraph))) || return 0
  # A code block ends it, as an empty line does, since its lines aren't the page's text
  j = i
  while j < length(ks) && !(ks[j+1].kind in (Kind.blank, Kind.fence, Kind.code))
    j += 1
  end
  j
end

"Where each line of the page is HTML: the first and the last line of the HTML that it's in, or (0, 0) for a line that isn't"
html_runs(b::Buffer) = begin
  ks = kinds(b)
  kept = get(HTML_RUNS, b, nothing)
  kept !== nothing && kept[1] === ks && return kept[2]
  runs = fill((0, 0), length(ks))
  if b.view == :markdown && !Eml.isemail(b.path)
    i = 1
    while i <= length(ks)
      t = html_end(b, ks, i)
      t == 0 ? (i += 1) : (fill!(view(runs, i:t), (i, t)); i = t + 1)
    end
  end
  HTML_RUNS[b] = (ks, runs)
  runs
end

"The first and the last line of the HTML that line `i` is in, or nothing when it isn't HTML"
html_block(b::Buffer, i::Int) = (runs = html_runs(b); 1 <= i <= length(runs) && runs[i][1] > 0 ? runs[i] : nothing)

"True when the caret is in the HTML of lines `s` to `t`, as it is while they're typed. They show as they're written then."
html_typed(b::Buffer, s::Int, t::Int) = !caretless(b) && s <= b.caret[1] <= t && s <= b.anchor[1] <= t && picked(b) === nothing

"HTML on lines of the page, as web/ draws it"
@def mutable struct HTMLBlock <: SemanticUI
  page::Any = nothing                    # what web/ made of the HTML, or nothing when it couldn't
  want::Any = nothing                    # what it was laid out for: the HTML, the CSS, the width, the page and the pictures that had come
  store::Any = nothing                   # its pictures that are read already
  waiting::Set{String} = Set{String}()   # the addresses of its pictures that are on their way from the web
  arrived::Int = 0                       # how many of them have come, or couldn't be fetched
  said::Bool = false                     # its tooltip shows, with where a link goes
end

describe(v::HTMLBlock) = Box(width(grow=grow), height(v.page === nothing ? 0px : px(v.page.tall)))

draw(ctx, size, ui::ConcreteRect, v::HTMLBlock) = (v.page === nothing || Web.draw(ctx, v.page; x=num(ui.left), y=num(ui.top)); nothing)

"The address that the HTML of the page names its pictures and links from: the page's own"
html_base(e) = begin
  path = e.buf.path
  (at = web_address(path); isempty(at)) || return at
  path = isempty(path) ? joinpath(docdir(e), "page.md") : abspath(path)
  "file://" * replace(path, '%' => "%25", ' ' => "%20", '#' => "%23", '?' => "%3F")
end

"The file of Ladder's own at the address `src`, or nothing. A page from a web server reads no other file."
html_file(e, src) = begin
  path = Remote.unescaped(replace(src, r"^file://"i => ""))
  (path in LADDER_FONT_FILES || isempty(web_address(e.buf.path))) ? path : nothing
end

"""
The bytes of the file at the address `src` that the HTML names, like a
picture, or nothing while it's on its way from the web. A window that isn't on
the screen fetches nothing.
"""
html_bytes(e, v::HTMLBlock, src) = begin
  if startswith(src, r"https?://"i)
    url = replace(src, ' ' => "%20")
    (on_screen(e) || haskey(fetches, url)) || return nothing
    file = fetched(e, url)
    if file === nothing
      get(fetches, url, nothing) isa Base.Process && push!(v.waiting, url)
      return nothing
    end
    return try read(file) catch; nothing end
  end
  startswith(src, r"file:"i) || return nothing
  path = html_file(e, src)
  path !== nothing && isfile(path) ? (try read(path) catch; nothing end) : nothing
end

"Note which of the pictures of the HTML have come from the web, so that it's laid out again with them"
html_arrivals!(e, v::HTMLBlock) = begin
  for url in collect(v.waiting)
    fetched(e, url)   # this looks whether the picture has come, and asks for another frame while it hasn't
    get(fetches, url, nothing) isa Base.Process && continue
    delete!(v.waiting, url)
    v.arrived += 1
  end
end

# Each family of a font whose files are in Ladder's fonts folder, like Literata, with its files. web/ finds no font that
# Ladder reads from a file, so the HTML's CSS names these files.
const LADDER_FONT_FILES = Set{String}()
const LADDER_FACES = Dict{String,String}()

"The @font-face rules of `family` when its files are in Ladder's fonts folder, or \"\" for a font of the Mac"
font_faces(family::AbstractString) = get!(LADDER_FACES, family) do
  dir = joinpath(@__DIR__, "fonts")
  rules = String[]
  for name in (isdir(dir) ? readdir(dir) : String[])
    m = match(r"^(.+)-([A-Za-z]+)\.(?:ttf|otf)$", name)
    (m === nothing || m[1] != family) && continue
    style = String(m[2])
    italic = endswith(style, "Italic")
    w = replace(style, "Italic" => "")
    weight = isempty(w) || w == "Regular" ? 400 : weight_of(w)
    path = joinpath(dir, name)
    push!(LADDER_FONT_FILES, path)
    push!(rules, "@font-face { font-family: \"$family\"; font-weight: $weight; font-style: $(italic ? "italic" : "normal"); " *
                 "src: url(\"file://$(replace(path, ' ' => "%20"))\") }")
  end
  join(rules, "\n")
end

"The CSS that gives HTML the look of the page's text: its font, its colours and its headings"
html_css(e) = begin
  f = body(e)
  site = e.look == :site
  sizes = site ? SITE_HEADINGS : HEADINGS
  # The weights of the page's text and of its headings, as the settings choose them. A blog's site has its headings a little lighter than bold.
  w = site ? 400 : nearest_weight(e.font, e.weight).weight
  heavy = site ? 600 : w >= 700 ? w : bolder(w)
  """
  $(font_faces(f.family))
  html, body { margin: 0; padding: 0; background: transparent }
  body { display: flow-root; font-family: "$(f.family)"; font-size: $(num(f.size))px; font-weight: $w; line-height: 1.65; color: $(css_colour(f.color)) }
  h1, h2, h3, h4, h5, h6, b, strong, th { font-weight: $heavy }
  h1, h2, h3, h4, h5, h6 { line-height: 1.35; margin: 0.4em 0 0.2em }
  $(join(("h$k { font-size: $(sizes[k])em }" for k in 1:6), "\n"))
  a { color: $(css_colour(colours.accent)); text-decoration: none }
  img, video, svg { max-width: 100% }
  code, pre, kbd, samp { font-family: "$(codefont())"; font-size: $(CODE_SCALE)em }
  body > :first-child { margin-top: 0 }
  body > :last-child { margin-bottom: 0 }
  """
end

"What the HTML on lines `s` to `t` of the page shows, or nothing when web/ can't draw it"
html_item(e, s::Int, t::Int) = begin
  b = e.buf
  source = join(view(b.lines, s:t), '\n')
  v = node!(HTMLBlock, e, (:html_lines, source))
  own!(node!(Document, e, :document), v)
  html_arrivals!(e, v)
  want = (round(Int, num(e.width)), html_css(e), b.path, v.arrived)
  if v.want != want
    if v.store === nothing
      v.store = Web.Pictures(src -> html_bytes(e, v, src))
    elseif v.want !== nothing && v.want[4] != v.arrived
      Web.retry!(v.store)   # a picture that wasn't here may be now
    end
    v.page = try
      Web.page(source; wide=want[1], css=want[2], pictures=v.store, base=html_base(e))
    catch err
      @debug "Ladder couldn't draw the HTML of a page" exception=err
      nothing
    end
    v.want = want
  end
  v.page === nothing ? nothing : Live(v, px(v.page.tall) + 2LIVE_GAP)
end

"The link of the HTML that the mouse is over, as `Web.link` gives it, and its rectangle in the window, or nothing"
html_link(v::HTMLBlock) = begin
  w = window_of(v)
  (w === nothing || v.page === nothing) && return nothing
  r = rect(v)
  l = Web.link(v.page, num(w.mouse[1] - r.left), num(w.mouse[2] - r.top))
  l === nothing ? nothing : (url=l.url, box=(r.left + px(l.left), r.top + px(l.top), px(l.wide), px(l.tall)))
end

"Follow the link `url` of the HTML of the page, as a link of the page's text goes"
html_follow!(e, url) = startswith(url, r"file:"i) ? (path = html_file(e, url); path === nothing ? e : follow!(e, path)) : follow!(e, url)

cursor(v::HTMLBlock) = html_link(v) === nothing ? :arrow : :hand

# The mouse over a link says where the link goes
onmouse(v::HTMLBlock, ev::MouseMove) = begin
  l = html_link(v)
  if l !== nothing
    show_tooltip!(ev.window, tip_label(sent_address(l.url)), l.box..., placement=:bottom, gap=6px)
  elseif v.said
    hide_tooltip!(ev.window)
  end
  v.said = l !== nothing
  nothing
end

# A click on a link with ⌘ held follows it, as a click on a link of the text does. In a page that's never changed, a
# click with no key held follows it too. Any other click goes to the page, which selects the HTML as a whole.
onkey(v::HTMLBlock, ev::KeyPress{Keys.mouse_left}) = begin
  e, l = editor(v), html_link(v)
  (l !== nothing && (only_held(e, Keys.cmd) || (e.buf.fixed && only_held(e, Keys(0))))) || return click_page!(v, ev)
  html_follow!(e, l.url)
  handled
end

# --- video and sound from the web --------------------------------------------------------
#
# A line can name a video or a sound by its address on the web, as it can a
# picture. Ladder downloads the file once, into a folder of the Mac's caches,
# and the line's player plays that copy. The copy's name ends as the file's
# does, like .mov, because macOS goes by that. What follows a ? or a # in the
# address isn't part of the name, so each part of one video, like
# walk.mov#t=61,86, plays from the same copy.
#
# While Ladder downloads the file, the line says so. If Ladder can't get it,
# the line says that, and Ladder tries again a minute later. A new try goes on
# from what the last one got.

const RETRY = 60              # seconds after a download fails before Ladder tries again
# What's known of each copy that isn't whole yet: the `curl` that downloads it, or when the last one failed
const downloads = Dict{String,Any}()

"A line that says that Ladder is downloading its video or its sound, or that it couldn't"
@def mutable struct MediaNote <: SemanticUI
  line::Int = 0
  words::String = ""
  failed::Bool = false
  size::px = 13px   # of the text
end

"The web address `url` without what follows its ? or its #"
web_file(url) = String(first(split(url, r"[?#]", limit=2)))

"Is `src` the web address of a video or a sound file?"
web_media(src) = startswith(src, r"https?://") && (ext = lowercase(splitext(web_file(src))[2]); ext in VIDEOS || ext in SOUNDS)

"The file on the Mac that keeps the copy of the video or the sound at the web address `url`"
media_file(url) = (file = web_file(url); joinpath(media_dir(), string(hash(file), base=16) * lowercase(splitext(file)[2])))

"`src` as a file on the Mac: the copy of a video or a sound on the web, and `src` itself for anything else"
local_media(src) = web_media(src) ? media_file(src) : src

"""
Download the video or the sound at the web address `url`, unless its copy is on
the Mac or on its way. It's `:there` once the copy is whole, `:coming` while
`curl` downloads it, and `:failed` for a minute after `curl` couldn't get it.
"""
download!(e, url) = begin
  file = media_file(url)
  isfile(file) && return :there
  part = file * ".part"
  state = get(downloads, file, nothing)
  if state isa Base.Process
    if !process_exited(state)
      redraw_in!(e, 0.5)   # look again soon
      return :coming
    end
    if success(state) && isfile(part)
      delete!(downloads, file)
      mv(part, file, force=true)
      return :there
    end
    # A server that said no, or that can't send the rest of a file, leaves nothing for the next try to go on from
    state.exitcode in (22, 33) && rm(part, force=true)
    state = downloads[file] = time()
  end
  if state isa Float64 && time() - state < RETRY
    redraw_in!(e, RETRY - (time() - state))   # to try again
    return :failed
  end
  # The address is asked for as it's written, with its ? and without its #. `curl` gives up when nothing comes for a minute.
  address = replace(first(split(url, '#')), ' ' => "%20")
  state = downloads[file] = try
    mkpath(media_dir())
    Webfetch.start(address, part; connect=30, seconds=nothing, speed_limit=1, speed_time=60, resume=true, compressed=false)
  catch
    time()
  end
  redraw_in!(e, 0.5)
  state isa Base.Process ? :coming : :failed
end

"""
What line `i` shows while the video or the sound at the web address `src` isn't
on the Mac: that Ladder is downloading it, or that it couldn't. It's nothing
once the copy is there, and when `src` is anything else.
"""
media_note(e, i, src) = begin
  (Sys.isapple() && web_media(src)) || return nothing
  state = download!(e, src)
  state == :there && return nothing
  what = lowercase(splitext(web_file(src))[2]) in VIDEOS ? "video" : "sound"
  part = media_file(src) * ".part"
  got = isfile(part) ? filesize(part) >> 20 : 0
  node = node!(MediaNote, e, (:media_note, i))
  node.line, node.failed, node.size = i, state == :failed, body(e).size * 0.76
  node.words = state == :failed ? "Ladder couldn't get the $what. It tries again in a minute." :
               "Downloading the $what…" * (got > 0 ? " $got MB so far" : "")
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

describe(n::MediaNote) = begin
  s = n.size
  Row(width(grow=grow), Alignment.Center, padding(s, s * 0.7), child_gap=s * 0.6, radius(6px),
      border(1px, :solid, colours.line), background(colours.block), name="Media note",
    Icon(n.failed ? "exclamation-circle" : "cloud-arrow-down", size=s * 1.1, color=colours.dim),
    label(n.words, s, color=colours.dim))
end

cursor(::MediaNote) = :arrow
onkey(n::MediaNote, ev::KeyPress{Keys.mouse_left}) = click_page!(n, ev)

# --- a table from a CSV file -------------------------------------------------------------
#
# A line that holds only a CSV file, written as a picture is, like
# ![Prices](prices.csv), shows the file as a table. A .tsv file shows the same
# way. The first row of the file has the names of the columns, and a column of
# numbers has its text on the right. The table looks like a table of the page,
# but you can't type in it: the numbers are the file's. A small line over the
# table has the words of the link and the file's name.
#
# A long file shows its first `TABLE_ROWS` rows. A line under them says how
# many more there are, and a click on it shows them all. A click on the table
# puts the caret on it as a whole, and ⌥-click shows its line as it's written.
#
# Ladder reads the file once, and again when the file changes on the disk. A
# file that isn't there, or that isn't a table, shows a line that says so. A
# `chart` block draws the numbers of a line like this as it draws a table's.
# csv.jl reads the file.

const TABLE_ROWS = 30   # the rows under the names that a long file shows until you ask for the rest
push!(BLOCK_ICONS, "exclamation-circle")

"True when the file at `path` is one that holds a table: a CSV file or a TSV file"
istable(path) = lowercase(splitext(path)[2]) in TABLES

# What's known of each CSV file that a page shows: when the file last changed, how big it was then, and its table
const table_files = Dict{String,Tuple{Float64,Int,Csvs.Table}}()
"The table in the CSV file at `path`. The file is read once, and again when it changes on the disk."
file_table(path) = begin
  s = stat(path)
  at, size = Float64(s.mtime), Int(s.size)
  kept = get(table_files, path, nothing)
  kept !== nothing && kept[1] == at && kept[2] == size && return kept[3]
  table_reads[] += 1
  (table_files[path] = (at, size, Csvs.load(path)))[3]
end

"The CSV file that the line `text` holds, if it holds only that, and the words of its link. It's nothing for any other line. `dir` is the document's folder."
table_file(dir, text) = begin
  occursin("![", text) || return nothing
  m = match(PICTURE_LINE, text)
  m === nothing && return nothing
  src = unescaped(String(m[2]))
  (startswith(src, r"https?://") || !istable(src)) && return nothing
  (abspath(dir, expanduser(src)), String(m[1]))
end

"A line of the document that holds only a CSV file, shown as a table"
@def mutable struct TableLine <: SemanticUI
  line::Int = 0
  path::String = ""
  words::String = ""                       # of the link
  whole::Bool = false                      # every row shows, and not only the first `TABLE_ROWS`
  laid::Any = nothing                      # the table laid out: a FileGrid
  size::px = 13px                          # of the small text over and under the table
  parts::Dict{Any,Any} = Dict{Any,Any}()   # the line under the table, kept between frames
end

"The line under a file's table that says how many rows don't show. A click shows them, or hides them again."
@def mutable struct TableMore <: SemanticUI
  of::Any = nothing
end

"The table of a CSV file laid out for the page, as a table of the page is"
struct FileGrid
  table::Csvs.Table
  rows::Int                       # how many rows show, with the row of names
  widths::Vector{px}
  heights::Vector{px}
  tops::Vector{px}                # how far the top of each row is under the top of the table
  flows::Dict{Int,Vector{Flow}}   # the text of each row that has been laid out: a Flow for each column
  base::Face                      # of a cell's text
  head::Face                      # and of a name of a column
  lh::px
end

tall(g::FileGrid) = isempty(g.heights) ? 0px : g.tops[end] + g.heights[end] + 1px



"""
Lay out the table `t` of the file at `path` for the page of `e`, as `grid` lays
out a table of the page: the same font, the same room in a cell, and columns
that share the page's width. With `whole`, every row shows. When the columns
don't all fit, text wraps before a number is cut short, as in a spreadsheet.
Only the rows that the window shows are laid out as text.
"""
file_grid(e, path, t::Csvs.Table, whole::Bool) = get!(e.flows, (:file_grid, path, whole, table_reads[])) do
  base = Face(body(e), size=body(e).size * 0.94)
  head = emboldened(base)
  lh = base.size * 1.5
  n = whole ? length(t.rows) : min(length(t.rows), TABLE_ROWS + 1)
  ncols = length(t.numbers)
  face(r) = r == 1 ? head : base
  wide(r, c) = measure(face(r), celltext(t.rows[r][c]))
  natural = [clamp(maximum(r -> wide(r, c), 1:n) + 2CELL_X, 60px, e.width * 0.75) for c in 1:ncols]
  space = e.width - 1px * (ncols + 1)
  widths = if sum(natural) <= space
    share_widths(natural, natural, space)
  else
    # Each column keeps the room that its longest word or number needs, and the columns share what's left
    word(r, c) = maximum(w -> measure(face(r), w), split(t.rows[r][c]), init=0px)
    share_widths(natural, [min(natural[c], max(maximum(r -> word(r, c), 1:n) + 2CELL_X, 36px)) for c in 1:ncols], space)
  end
  g = FileGrid(t, n, widths, px[], px[], Dict{Int,Vector{Flow}}(), base, head, lh)
  top = 1px
  for r in 1:n
    # A row whose cells each fit on one line is as tall as that line. Any other row is laid out now, to learn how tall it is.
    fits = all(c -> wide(r, c) + 2px <= widths[c] - 2CELL_X, 1:ncols)
    h = (fits ? lh : maximum(tall, row_flows(g, r))) + 2CELL_Y
    push!(g.heights, h)
    push!(g.tops, top)
    top += h + 1px
  end
  g
end

"The text of row `r` of `g` laid out: a Flow for each column. A column of numbers has its text on the right."
row_flows(g::FileGrid, r::Int) = get!(g.flows, r) do
  face = r == 1 ? g.head : g.base
  [align(wrap(symbols!(Piece[], celltext(g.table.rows[r][c]), 0, face), w - CELL_X; lh=g.lh, size=g.base.size, left=CELL_X),
         w - 2CELL_X, g.table.numbers[c] ? :right : :left) for (c, w) in enumerate(g.widths)]
end

"How tall the line over a file's table is, and the line under it"
caption_high(t::TableLine) = t.size * 2.1

"What the line under the table of `t` says, and what it says after that in fainter words. Both are \"\" when every row shows and there's nothing to say."
more_words(t::TableLine) = begin
  g = t.laid::FileGrid
  rest = length(g.table.rows) - g.rows
  cut = g.table.more ? "The file has more rows than Ladder reads." : ""
  rest > 0 && return ("and $(g.table.more ? "more than " : "")$(Charts.commas(string(rest))) more row$(rest == 1 ? "" : "s")", "")
  t.whole && g.rows > TABLE_ROWS + 1 ? ("Show the first $TABLE_ROWS rows only", cut) : ("", cut)
end

"True when the table of `t` has a line under it"
has_more(t::TableLine) = any(!isempty, more_words(t))

tall(t::TableLine) = caption_high(t) + tall(t.laid) + (has_more(t) ? caption_high(t) : 0px)

"What line `i` shows when it holds only a CSV file: the file as a table, or a line that says why it has no table. It's nothing for any other line."
table_item(e, i) = begin
  b = e.buf
  found = table_file(docdir(e), b.lines[i])
  found === nothing && return nothing
  path, words = found
  t = file_table(path)
  size = body(e).size * 0.76
  if !isempty(t.problem)
    node = node!(MediaNote, e, (:media_note, i))
    node.line, node.failed, node.size, node.words = i, true, size, t.problem
    own!(node!(Document, e, :document), node)
    # Lay it out once to learn how tall it is
    concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
    return Live(node, concrete.height + 2LIVE_GAP)
  end
  # Each line has a table of its own, by its place among the lines that hold the file, so two lines can show one file
  n = count(j -> (other = table_file(docdir(e), b.lines[j]); other !== nothing && other[1] == path), 1:i)
  node = node!(TableLine, e, (:file_table, b.path, path, n))
  node.line, node.path, node.words, node.size = i, path, words, size
  node.laid = file_grid(e, path, t, node.whole)
  own!(node!(Document, e, :document), node)
  Live(node, tall(node) + 2LIVE_GAP)
end

"""
The first and the last row of the table of `t` that the window shows, with a
few each side. Only those are built, so a long file costs no more than a short
one. On paper, every row is built.
"""
rows_shown(e, t::TableLine, g::FileGrid) = begin
  k = e.buf.caret[1] < 1 ? nothing : findfirst(it -> it.first == t.line, e.layout)
  k === nothing && return (1, g.rows)
  _, h = window_size(e)
  top = e.layout[k].top + LIVE_GAP + caption_high(t)   # of the table, from the top of the page's text
  from, to = e.scroll.offset - PAGE_TOP - 200px - top, e.scroll.offset + h + 200px - top
  lo = something(findfirst(r -> g.tops[r] + g.heights[r] >= from, 1:g.rows), g.rows)
  (lo, max(lo, something(findlast(r -> g.tops[r] <= to, 1:g.rows), 1)))
end

describe(t::TableLine) = begin
  e = editor(t)
  g, s = t.laid::FileGrid, t.size
  line = border(1px, :solid, colours.line; between=true)
  lo, hi = rows_shown(e, t, g)
  # The room of the rows from `a` to `b`, which aren't built
  room(a, b) = spacer(g.tops[b] + g.heights[b] - g.tops[a])
  row(r) = Row(width(grow=grow), height(g.heights[r]), Alignment.Start, line[:between],
               background(r == 1 ? colours.head : iseven(r) ? colours.bg : colours.stripe),
             [Column(fixed(w), height(grow=grow), Alignment.Start, justify=Alignment.Center, rows(row_flows(g, r)[c])...)
              for (c, w) in enumerate(g.widths)]...)
  table = Column(width(grow=grow), Alignment.Start, line, name="Table",
    (lo > 1 ? (room(1, lo - 1),) : ())..., [row(r) for r in lo:hi]..., (hi < g.rows ? (room(hi + 1, g.rows),) : ())...)
  # The words of the link, and the name of the file that the numbers come from
  caption = Row(width(grow=grow), height(caption_high(t)), Alignment.Center, child_gap=s * 0.5, clip=true,
    Icon("file-earmark-spreadsheet", size=s * 1.1, color=colours.dim),
    (isempty(t.words) ? () : (Box(label(t.words, s, color=colours.dim, weight="Semibold")),))...,
    Box(label(basename(t.path), s, color=colours.dim)))
  Column(width(grow=grow), Alignment.Start, name="File table", caption, table,
    (has_more(t) ? (block_part!(() -> TableMore(of=t), t, :more),) : ())...)
end

cursor(::TableLine) = :arrow
onkey(t::TableLine, ev::KeyPress{Keys.mouse_left}) = click_page!(t, ev)

describe(m::TableMore) = begin
  t = m.of
  words, after = more_words(t)
  Row(width(grow=grow), height(caption_high(t)), Alignment.Center, child_gap=t.size * 0.8, clip=true,
    (isempty(words) ? () : (Box(label(words, t.size, color=ishovered(m) ? colours.accent : colours.dim)),))...,
    (isempty(after) ? () : (Box(label(after, t.size, color=colours.faint)),))...)
end

cursor(m::TableMore) = isempty(more_words(m.of)[1]) ? :arrow : :hand

# A click on the line under the table shows every row, or only the first ones again
onkey(m::TableMore, ::KeyPress{Keys.mouse_left}) = begin
  t = m.of
  isempty(more_words(t)[1]) && return nothing   # a line with nothing to show is part of the table
  e = editor(t)
  before = tall(t)
  t.whole = !t.whole
  t.laid = file_grid(e, t.path, t.laid.table, t.whole)
  # When rows go, the line stays under the mouse
  t.whole || (e.scroll.offset = max(0px, e.scroll.offset - (before - tall(t))))
  handled
end

"The rows of the table that line `i` shows when it holds only a CSV file, for a chart to draw. It's nothing for any other line, and for a file with no table."
table_rows(e, i) = begin
  found = table_file(docdir(e), e.buf.lines[i])
  found === nothing && return nothing
  t = file_table(found[1])
  isempty(t.problem) ? t.rows : nothing
end

"The CSV file that the `from` of a chart names, or nothing when it names a heading or several tables"
chart_path(e, c::Charts.Chart) = begin
  istable(c.from) || return nothing
  path = abspath(docdir(e), expanduser(c.from))
  length(chart_sources(c)) > 1 && !isfile(path) ? nothing : path   # a file's name can have a comma in it
end

"Each CSV file that the chart `c` draws"
chart_files(e, c::Charts.Chart) = begin
  path = chart_path(e, c)
  path !== nothing ? [path] : [abspath(docdir(e), expanduser(n)) for n in chart_sources(c) if istable(n)]
end

"What the chart `c` draws when its `from` names a CSV file: the file's numbers, or why it has none. It's nothing when `from` names a heading."
chart_file(e, c::Charts.Chart; most=Charts.MOST) = begin
  path = chart_path(e, c)
  path === nothing && return nothing
  t = file_table(path)
  isempty(t.problem) ? Charts.data(c, t.rows, headed=true, most=most) : Charts.nothing_to_draw(t.problem)
end

# A chart whose `from` names a CSV file looks at the file in each frame, so it draws the new numbers when the file changes
block_tick!(v::ChartView) = (foreach(file_table, chart_files(editor(v), v.spec)); sources_tick!(v); from_pick_tick!(v); v)

"The line `text` as HTML when it holds only a CSV file: the file's table, or the words that say why it has none. It's nothing for any other line."
table_html(e, text) = begin
  found = table_file(docdir(e), text)
  found === nothing && return nothing
  path, words = found
  t = file_table(path)
  isempty(t.problem) || return "<p><em>$(escape(t.problem))</em></p>"
  side(c) = t.numbers[c] ? " style=\"text-align: right\"" : ""
  row(tag, cells) = "<tr>" * join("<$tag$(side(c))>$(replace(escape(cell), "\n" => "<br>"))</$tag>" for (c, cell) in enumerate(cells)) * "</tr>"
  name = escape(basename(path))
  "<table>\n<caption>$(isempty(words) ? name : "$(escape(words)) ($name)")</caption>\n<thead>" * row("th", t.rows[1]) * "</thead>\n<tbody>\n" *
    join((row("td", cells) for cells in t.rows[2:end]), "\n") * "\n</tbody>\n</table>" *
    (t.more ? "\n<p><em>The file has more rows than these.</em></p>" : "")
end

# --- video in the text -------------------------------------------------------------------
#
# A line that holds only a video file, written as a picture is, like
# ![The kitchen](walk.mov), shows a player for the file. A link that ends like
# walk.mov#t=61,86 names part of the file: from 61 seconds after its start to
# 86. The player starts at 61 and stops at 86, and its track is that part of the
# file. walk.mov#t=61 goes on to the end of the file. A time can be written as a
# clock shows it too, like 1:01. A browser reads the link the same way.

"""
The file that a link names, and the part of the file that the link's `#t=`
names, in seconds from the file's start. `"walk.mov#t=61,86"` gives
`("walk.mov", 61.0, 86.0)`. With no `#t=` it's all of the file: 0 to Inf.
"""
media_part(src) = begin
  file, after = occursin('#', src) ? split(src, '#', limit=2) : (src, "")
  from, to = 0.0, Inf
  for pair in split(after, '&')
    startswith(pair, "t=") || continue
    times = split(replace(pair[3:end], r"^npt:" => ""), ',', limit=2)
    start = clock_time(times[1])
    start === nothing || (from = max(start, 0.0))
    stop = length(times) == 2 ? clock_time(times[2]) : nothing
    stop === nothing || stop <= from || (to = stop)
  end
  (String(file), from, to)
end

"A time written as seconds, like 61.5, or as a clock shows it, like 1:01.5 or 0:01:01, in seconds. It's nothing if the text isn't a time."
clock_time(text) = begin
  n = map(part -> tryparse(Float64, part), split(text, ':'))
  (length(n) > 3 || any(isnothing, n)) && return nothing
  foldl((total, x) -> total * 60 + x, n)
end

"What a line shows when it holds only the video file `src`: a player of the file, or of the part of it that `src` names. It's nothing if the file isn't there."
video_item(e, src) = begin
  Sys.isapple() || return nothing
  file, from, to = media_part(src)
  file = local_media(file)   # a video on the web plays from the copy of it on the Mac
  (startswith(file, r"https?://") || !(lowercase(splitext(file)[2]) in VIDEOS)) && return nothing
  path = abspath(docdir(e), expanduser(file))
  isfile(path) || return nothing
  # A Shown gives the player the page's colours, and the button that makes it fill the window, as it does for what a live block makes
  node = get!(e.nodes, (:video, path, from, to)) do
    shown = Shown(value=VideoPlayer(path=path, from=from, to=to))
    own!(shown, shown.value)
    shown
  end
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

# --- what was said in a video ------------------------------------------------------------
#
# While the mouse is over a video, a button under the one that makes it fill the
# window opens a drop-down of what was said in the video. The drop-down has a
# button that copies the words to the clipboard. The first time, macOS writes
# down what's said in the file, as it does for a sound file. See transcribe.jl.
# A few minutes of video take it a second or two, and the drop-down says how far
# it has got. A line that names part of a file, like walk.mov#t=61,86, shows what
# was said in that part. Each file is transcribed once while Ladder runs, so the
# parts of a file share it.

const TRANSCRIPT_W = 520px      # the widest the drop-down is
const TRANSCRIPT_HIGH = 320px   # the tallest that its words are before they scroll
const TRANSCRIPT_PAD = 14px     # inside its edge
const COPIED_FOR = 1.5          # how many seconds the copy button says "Copied"

"The drop-down of a TranscriptButton: what was said in the video, and a button that copies it"
@def mutable struct Transcript <: SemanticUI
  player::Any = nothing   # the VideoPlayer
  wide::px = TRANSCRIPT_W # how wide it is
  copy::Any = nothing     # its CopyButton
  scroll::Scroll = Scroll(width(grow=grow))
end

"The button in a Transcript that copies the words to the clipboard"
@def mutable struct CopyButton <: SemanticUI
  text::String = ""       # what it copies
  copied::Float64 = 0.0   # when it last copied, so that it says so for a moment
end

# The transcription of each video file that has had one, by the file's path,
# with when the file last changed before it started
const video_words = Dict{String,Tuple{Float64,Transcription}}()

"""
Start to transcribe the video file at `path`, unless it has been or it's being
done. A file that has changed since, and one that couldn't be done, start again.
"""
transcribe_video!(path) = begin
  stamp = mtime(path)
  had = get(video_words, path, nothing)
  had !== nothing && had[1] == stamp && !(finished(had[2]) && had[2].text === nothing) && return had[2]
  video_words[path] = (stamp, Transcription(path, times=true))
  video_words[path][2]
end

"""
What the drop-down of the video player `p` shows: the words said in the part of
the file that it plays, or no words and a note that says why there are none,
like how far macOS has got. `busy` is true while macOS works.
"""
transcript_of(p::VideoPlayer) = begin
  had = get(video_words, p.path, nothing)
  had === nothing && return (words="", note="", busy=false)
  t = had[2]
  if !check!(t)
    note = t.downloading ? "Downloading what macOS needs to transcribe…" : "Transcribing… $(round(Int, 100t.done))%"
    return (words="", note=note, busy=true)
  end
  t.text === nothing && return (words="", note=t.problem, busy=false)
  words = words_between(phrases(t), p.from, p.to)
  whole = p.from == 0 && p.to == Inf
  (words=words, note=isempty(words) ? "No words were heard in $(whole ? "the" : "this part of the") video." : "", busy=false)
end

"How wide the drop-down of what was said in a video is in the page of `e`"
transcript_w(e) = min(e.width, TRANSCRIPT_W)

describe(b::TranscriptButton) = begin
  ishovered(b) || (b.quiet = false)
  square_button("text-paragraph", b.open || ishovered(b))
end

cursor(::TranscriptButton) = :hand
draw(ctx, size, ui::ConcreteRect, b::TranscriptButton) = (b.rect = (ui.left, ui.top, ui.width, ui.height); nothing)

onmouse(b::TranscriptButton, ev::MouseMove) = begin
  (b.quiet || b.open) && return handled
  show_tooltip!(ev.window, tip_label("Show transcription"), b.rect...,
                placement=:right, gap=6px)
  handled
end

# While the drop-down is open, a click on the button is outside the drop-down, so it closes it
onkey(b::TranscriptButton, ev::KeyPress{Keys.mouse_left}) = begin
  b.quiet = true
  hide_tooltip!(ev.window)
  e, p = editor(b), video_of(b.parent)
  p === nothing && return handled
  transcribe_video!(p.path)
  b.open = true
  t = Transcript(player=p, wide=transcript_w(e))
  t.copy = own!(t, CopyButton())
  popup!(ev.window, t, anchor=b, gap=6px, width=t.wide, key=:transcript,
         onclose=() -> (b.open = false), theme=component_theme(e.zoom))
  handled
end

"""
`text` as a Text for each of its paragraphs, `wide` wide. A Text's box ends at
the foot of its last line's letters, so room under them keeps the tails of
letters like p and y from being cut off. For the same reason, the gap between
two paragraphs is a line's height and a little more.
"""
said_text(text, wide; color=colours.ink) =
  Column(fixed(wide), Alignment.Start, padding(0px, 0px, 6px, 0px), child_gap=20px,
    [Text(String(p), size=14px, family=SANS, color=color) for p in split(text, "\n\n")]...)

describe(t::Transcript) = begin
  words, note, busy = transcript_of(t.player)
  # Look again soon, to show how far it has got
  busy && redraw_in!(t, 0.25)
  t.copy.text = words
  wide = t.wide - 2TRANSCRIPT_PAD
  body = if isempty(words)
    said_text(note, wide, color=colours.dim)
  else
    # Words that are taller than TRANSCRIPT_HIGH scroll
    t.scroll.height = height(min(describe(said_text(words, wide), (wide, 9999px)).height, TRANSCRIPT_HIGH))
    reuse!(t.scroll, said_text(words, wide))
  end
  Column(width(grow=grow), Alignment.Start, padding(TRANSCRIPT_PAD), radius(8px), background(colours.block),
         border(1px, :solid, colours.line), lifted, child_gap=10px, name="Transcript",
    Row(width(grow=grow), height(24px), Alignment.Center,
      Box(width(grow=grow), label("Transcription", 12px, color=colours.dim, weight="Semibold")),
      (isempty(words) ? () : (t.copy,))...),
    body)
end

describe(c::CopyButton) = begin
  done = time() - c.copied < COPIED_FOR
  Box(height(24px), padding(8px, 0px), radius(6px), background(ishovered(c) ? colours.active : colours.hover),
    Row(Alignment.Center, child_gap=5px,
      Icon(done ? "check" : "copy", size=12px, color=colours.dim),
      label(done ? "Copied" : "Copy to clipboard", 12px)))
end

cursor(::CopyButton) = :hand

onkey(c::CopyButton, ev::KeyPress{Keys.mouse_left}) = begin
  clipboard!(ev.window, c.text)
  c.copied = time()
  # So that it goes back to saying "Copy to clipboard"
  redraw_in!(c, COPIED_FOR + 0.05)
  handled
end

# --- sound in the text -------------------------------------------------------------------
#
# A line that holds only a sound file, written as a picture is, like
# ![Recording](.media/recording-2026-11-14-1642.m4a), shows a player for the file. The
# line's own text shows again while the caret is on it.
#
# Insert › Recording records from the microphone into a new file in the media
# folder beside the document, and adds a line for the file. The line shows a recorder until you
# click its button to stop. The recording goes on while another file shows. If
# the line goes from the document, as it does when you undo the Insert, the
# recording stops.
#
# While the mouse is over the player, a button under it writes down what's said
# in the file. The button lies over the gap under the player, so it takes no
# room in the page. macOS does the work on the Mac, and the words go into a
# paragraph under the line. You can type while it works. See transcribe.jl.

"A line of the document that holds only a sound file"
@def mutable struct SoundLine <: SemanticUI
  path::String = ""
end

"The button under a sound file's player that writes down what's said in the file"
@def mutable struct TranscribeButton <: SemanticUI
  path::String = ""
end

const TRANSCRIBE_H = 26px   # how tall the Transcribe button is
const TRANSCRIBE_GAP = 6px  # between a sound's player and the Transcribe button under it

# The recorder of each sound file that a line has shown. They're kept while
# Ladder runs, so that a recording goes on while another file shows.
const recorders = Dict{String,AudioRecorder}()
# The transcription of each sound file that has had one, by the file's path
const transcriptions = Dict{String,Transcription}()
# The sound files whose words are in a document now
const transcribed = Set{String}()

"The recorder of the sound file at `path`. It plays the file while it isn't recording."
recorder(path) = get!(() -> AudioRecorder(path=path), recorders, path)

"The sound file on the Mac that the line `text` holds, if it holds only that, or nothing. `dir` is the document's folder."
sound_file(dir, text) = begin
  occursin("![", text) || return nothing
  m = match(PICTURE_LINE, text)
  m === nothing && return nothing
  src = local_media(unescaped(String(m[2])))   # a sound on the web plays from the copy of it on the Mac
  (startswith(src, r"https?://") || !(lowercase(splitext(src)[2]) in SOUNDS)) && return nothing
  abspath(dir, expanduser(src))
end

"The line of the page that holds only the sound file at `path`, or nothing"
sound_line(e, path) = findfirst(text -> sound_file(docdir(e), text) == path, e.buf.lines)

"What a line that holds only the sound file at `path` shows, or nothing if there's no file and no recorder for it to show"
sound_item(e, path) = begin
  Sys.isapple() || return nothing
  r = recorder(path)
  (plays(r) || recording(r) || r.waiting || !isempty(r.problem)) || return nothing
  node = node!(() -> SoundLine(path=path), e, (:sound, path))
  own!(node!(Document, e, :document), node)
  # Lay it out once to learn how tall it is
  concrete = describe(Column(fixed(e.width), Alignment.Start, geometry(node)), (e.width, 9999px))
  Live(node, concrete.height + 2LIVE_GAP)
end

describe(s::SoundLine) = begin
  e = editor(s)
  r = recorder(s.path)
  # The recorder outlasts the line's node, which can be made again
  r.parent === s || setfield!(r, :parent, s)
  # It's a component, so it gets the colours and the text size that a live block gives one
  with_theme(component_theme(e.zoom)) do
    Column(width(grow=grow), Alignment.Start, r)
  end
end

"""
The Transcribe button of a sound's player, under the player. It lies over the
page, in the gap under the player, so the line is only as tall as its player
and the text under it never moves. The button shows while the mouse is over
the player or the button, or between them, and while macOS works.
"""
sound_over(e) = begin
  (zooming(e) === nothing && full_block(e) === nothing && e.popup == :none) || return ()
  win = window_of(e)
  win === nothing && return ()
  x, y = win.mouse
  for s in values(e.nodes)
    (s isa SoundLine && plays(recorder(s.path))) || continue
    r = rect(s)
    r === nothing && continue
    # Under the player's card. The speed button hangs off the card's bottom edge at the right, and this goes at the left.
    p = recorder(s.path).player
    edge = p === nothing ? nothing : card_bottom(p)
    top = something(edge, r.top + r.height) + TRANSCRIBE_GAP
    over = r.left <= x < r.left + r.width && r.top <= y < max(top + TRANSCRIBE_H, r.top + r.height)
    (over || transcribing(s.path)) || continue
    button = node!(() -> TranscribeButton(path=s.path), e, (:transcribe, s.path))
    button.parent === s || setfield!(button, :parent, s)
    t = get(transcriptions, s.path, nothing)
    # What went wrong the last time, or that there were no words
    note = t === nothing || !finished(t) ? "" : t.text == "" ? "No words were heard in it" : t.problem
    # The page's own colour is behind them, so that they read over a line of text that's right under the player
    return (Row(width(grow=grow), height(grow=grow), Alignment.Start, padding(top, 0px, 0px, r.left),
              Row(Alignment.Center, child_gap=10px, radius(6px), background(colours.bg),
                button, (isempty(note) ? () : (label(note, 12px, color=colours.dim),))...)),)
  end
  ()
end

# A click beside the player goes to the page, which puts the caret on the line as a whole
cursor(::SoundLine) = :arrow
onkey(s::SoundLine, ev::KeyPress{Keys.mouse_left}) = click_page!(s, ev)

"Is the file at `path` being transcribed now?"
transcribing(path) = (t = get(transcriptions, path, nothing); t !== nothing && !finished(t))

describe(b::TranscribeButton) = begin
  t = get(transcriptions, b.path, nothing)
  busy = transcribing(b.path)
  words = !busy ? (b.path in transcribed ? "Transcribe again" : "Transcribe") :
          t.downloading ? "Downloading what macOS needs to transcribe…" : "Transcribing… $(round(Int, 100t.done))%"
  Box(height(TRANSCRIBE_H), padding(10px, 0px), radius(6px), background(busy ? colours.hover : ishovered(b) ? colours.active : colours.hover),
    Row(Alignment.Center, child_gap=6px,
      Icon("text-paragraph", size=13px, color=colours.dim),
      label(words, 12px, color=busy ? colours.dim : colours.ink)))
end

cursor(b::TranscribeButton) = transcribing(b.path) ? :arrow : :hand

onkey(b::TranscribeButton, ::KeyPress{Keys.mouse_left}) = begin
  if !transcribing(b.path)
    transcriptions[b.path] = Transcription(b.path)
    delete!(transcribed, b.path)
  end
  handled
end

"Record from the microphone into a new file in the media folder beside the document, and add a line for the file under the caret"
add_recording!(e) = begin
  path = new_recording(e)
  record!(recorder(path))
  list_files!(e)
  # A document that has no file of its own names the recording by its whole path
  src = isempty(e.buf.path) ? replace(path, ' ' => "%20") : "$PAGE_MEDIA/$(basename(path))"
  add_block!(e, ["![Recording]($src)", "", ""], (3, 0))
end

"The path for a new recording: a file that isn't there yet, named by the time, in the media folder beside the document"
new_recording(e) = begin
  dir = docdir(e)
  isempty(dir) && (dir = joinpath(homedir(), "Documents"))
  dir = page_media(dir)
  when = Libc.strftime("%Y-%m-%d-%H%M", time())
  name(n) = "recording-$when$(n == 1 ? "" : "-$n").m4a"
  n = 1
  while ispath(joinpath(dir, name(n))) || haskey(recorders, joinpath(dir, name(n)))
    n += 1
  end
  joinpath(dir, name(n))
end

"Put `words` in a paragraph under line `i`, with an empty line on each side of it. The caret stays where it was in the text."
add_words!(e, i, words) = begin
  b = e.buf
  caret, anchor = b.caret, b.anchor
  below = i < length(b.lines) && !isempty(strip(b.lines[i+1]))
  text = "\n\n" * words * (below ? "\n" : "")
  edit!(b, line_end(b, i), line_end(b, i), text)
  n = count(==('\n'), text)
  moved(p) = p[1] > i ? (p[1] + n, p[2]) : p
  b.caret, b.anchor = moved(caret), moved(anchor)
  e
end

"""
What happens to sound in each frame. A recording whose line has gone from every
document stops. A transcription that has finished puts its words under its
file's line, once the page shows a document that has the line.
"""
sound_tick!(e) = begin
  for (path, r) in recorders
    (recording(r) || r.waiting) || continue
    docs = unique!(Buffer[e.buf; collect(values(e.buffers))])
    holds(b) = (dir = isempty(b.path) ? e.folder : dirname(b.path); any(text -> sound_file(dir, text) == path, b.lines))
    any(holds, docs) || stop!(r)
  end
  for (path, t) in transcriptions
    path in transcribed && continue
    if !check!(t)
      redraw_in!(e, 0.25)   # to show how far it has got
      continue
    end
    t.text === nothing && continue   # it failed, and the button says why
    readonly(e.buf) && continue      # a file that's only shown can't take the words
    i = sound_line(e, path)
    i === nothing && continue        # the document that shows now hasn't got the line
    isempty(t.text) || add_words!(e, i, t.text)
    push!(transcribed, path)
  end
end

