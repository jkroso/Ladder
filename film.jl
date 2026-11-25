# Make a short film of Ladder, for the Readme and for each release.
#
#     julia --project=. film.jl                  writes build/film/ladder.mp4
#     julia --project=. film.jl ~/Desktop/l.mp4  writes it there
#
# Nobody films the screen. The script opens a page in a window that isn't on
# the screen, as the tests do, and moves the mouse and presses the keys of
# that window through the same code that a real mouse and keyboard reach. It
# saves a picture of the window for each frame, with a pointer drawn where the
# mouse is and a line of words at the foot, and ffmpeg joins the pictures. So
# the film shows the Ladder that's in this folder, and a new version gets a
# new film from the same script.
#
# The page that it films is written here, into a temporary folder, with a copy
# of pages/progress.jl beside it. Nothing in this folder changes but the film.
# It needs ffmpeg: `brew install ffmpeg`.
#
# The Readme shows docs/ladder.gif, since GitHub doesn't play a video file of
# the repo in a Readme. Nothing makes it by itself. After a new film, this
# makes it again, 1280 pixels wide at 12 frames a second (about 5 MB):
#
#     ffmpeg -i build/film/ladder.mp4 -vf "fps=12,scale=1280:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=5:diff_mode=rectangle" docs/ladder.gif
#
# `SCENES` is the film: each scene is a function that takes the film. To add
# one, write a function like the others and put it in the list.

@use "./main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect draw scene popups window_tool draw_tool
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use Colors: @colorant_str, RGBA
@use Dates: Date
const px = K.px

const FPS = 20            # frames in each second of the film
const WIDE, TALL = 1280, 800
const SCALE = 1.5         # pixels of a picture for each point of the window

const PAGE = """
# The bathroom

This page is a **Markdown** file. Ladder draws each line the way that it [reads](https://github.com/jkroso/Ladder), and the blocks under the `list` are plain lines of text too.

- [x] Strip the old tiles
- [ ] Lay the new pipe
- [ ] Tile the walls

```board
Lay the new pipe | Doing
```

```schedule
start: 2026-11-16

Strip the old tiles | 2 days
Lay the new pipe | 3 days | after Strip the old tiles
Tile the walls | 4 days | after Lay the new pipe
```

```day
```

## What it costs

```sheet
Wall area = 14
Tiles each = 11
Price = 6.5
Tiles = wall area * tiles each
Cost = tiles * price
```

```progress
done: 0.4
label: The bathroom
```
"""

"A film that's being made: the window, the folder of its pictures, how many there are, and the words at the foot of the next ones"
mutable struct Film
  e::Any
  w::Any
  page::String
  frames::String
  n::Int
  caption::String
end

# --- a picture for each frame ------------------------------------------------------

"Draw what the window of `f` shows, the layout tool's marks, the words at the foot and the mouse's pointer"
paint(ctx, size, f::Film) = begin
  w = f.w
  draw(ctx, size, scene(w))
  foreach(p -> draw(ctx, size, p.scene), popups(w))
  t = window_tool(w)
  t === nothing || draw_tool(ctx, w, t, scene(w))
  isempty(f.caption) || caption(ctx, f.caption)
  pointer(ctx, K.num(w.mouse[1]), K.num(w.mouse[2]))
end

"The words at the foot of the picture, in a dark box"
caption(ctx, words) = begin
  face = K.Face(K.SANS, "Medium", 17px, colorant"white", false)
  wide = K.num(K.measure(face, words)) + 44
  x, y = (WIDE - wide) / 2, TALL - 78.0
  K.round_box(ctx, x, y, wide, 44, 22; fill=RGBA(0.13, 0.11, 0.09, 0.88))
  K.write_ink(ctx, words, x + 22, y + 28, face)
end

"The mouse's pointer, with its tip at `(x, y)`"
pointer(ctx, x, y) = begin
  shape = [(0.0, 0.0), (0.0, 17.0), (4.6, 13.2), (7.6, 19.8), (10.2, 18.6), (7.3, 12.2), (12.6, 12.2)]
  at = [(x + a, y + b) for (a, b) in shape]
  K.trace(ctx, [(a + 1, b + 2) for (a, b) in at], RGBA(0, 0, 0, 0.18), 0.0; fill=RGBA(0, 0, 0, 0.18), closed=true)
  K.trace(ctx, at, colorant"white", 1.6; fill=colorant"rgb(24,22,20)", closed=true)
end

"Draw the next frame of the window, and save its picture"
shoot!(f::Film) = begin
  started = time()
  Base.invokelatest(frame, f.w)
  f.n += 1
  save_png((ctx, size) -> paint(ctx, size, f), joinpath(f.frames, lpad(f.n, 5, '0') * ".png"), f.w.size; scale=(SCALE, SCALE))
  # What moves by the clock, like the caret, moves at its own speed when a frame takes no less time than it has in the film
  sleep(max(0.0, 1 / FPS - (time() - started)))
  f
end

"Film the window as it is for `seconds`"
hold!(f::Film, seconds) = (foreach(_ -> shoot!(f), 1:max(1, round(Int, seconds * FPS))); f)

"Say `words` at the foot of the film from now on. \"\" takes them away."
say!(f::Film, words) = (f.caption = words; f)

# --- the mouse and the keys --------------------------------------------------------

"Put the mouse at `(x, y)` of the window"
at!(f::Film, x, y) = begin
  w = f.w
  w.mouse = typeof(w.mouse)(px(x), px(y))
  onmouse(w, MouseMove(Vec2{px}(px(x), px(y)), w))
end

"A share of the way that starts slow and ends slow"
ease(t) = t < 0.5 ? 2t^2 : 1 - (-2t + 2)^2 / 2

"Move the mouse to `(x, y)` in `seconds`, and film it"
glide!(f::Film, (x, y); seconds=0.7) = begin
  x0, y0 = K.num(f.w.mouse[1]), K.num(f.w.mouse[2])
  n = max(1, round(Int, seconds * FPS))
  for k in 1:n
    t = ease(k / n)
    at!(f, x0 + (x - x0) * t, y0 + (y - y0) * t)
    shoot!(f)
  end
  f
end

press!(f::Film) = (f.w.keys |= Keys.mouse_left; onkey(f.w, KeyPress{Keys.mouse_left}(0, f.w)); shoot!(f))
release!(f::Film) = (f.w.keys ⊻= Keys.mouse_left; onkey(f.w, KeyRelease{Keys.mouse_left}(0, f.w)); shoot!(f))
click!(f::Film) = (press!(f); release!(f); hold!(f, 0.15))
click!(f::Film, place; seconds=0.7) = (glide!(f, place; seconds); click!(f))
"Press at one place, move to another, and let go"
drag!(f::Film, from, to; seconds=1.0) = (glide!(f, from); press!(f); hold!(f, 0.15); glide!(f, to; seconds); hold!(f, 0.2); release!(f); hold!(f, 0.2))

"Press the key `k` with the keys `held` down"
key!(f::Film, k, held...) = begin
  w = f.w
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  shoot!(f)
end

"Type `text`, a letter in each frame or two"
type!(f::Film, text; each=0.07) = begin
  for c in text
    ontype(f.w, Typed(c, f.w))
    hold!(f, each)
  end
  f
end

# --- where things are --------------------------------------------------------------

line(f::Film, words) = findfirst(l -> occursin(words, l), f.e.buf.lines)
block(f::Film, lang, n=1) = f.e.nodes[(:block, lang, f.page, n)]
middle(r) = (K.num(r.left + r.width / 2), K.num(r.top + r.height / 2))

"The middle of the box of the to-do item with `words`"
box(f::Film, words) = begin
  e = f.e
  it = K.item(e, line(f, words))
  flow = it.content
  seg = first(s for s in first(flow.lines).segs if K.isbox(s))
  (K.num(e.origin[1] + seg.x + seg.w / 2), K.num(e.origin[2] + it.top + flow.above + first(flow.lines).high / 2))
end

"A place in the words of the line with `words`, `along` px from where the line starts"
words_at(f::Film, words; along=160) = begin
  e = f.e
  it = K.item(e, line(f, words))
  (K.num(e.origin[1]) + along, K.num(e.origin[2] + it.top) + 16)
end

"The middle of what row `r` of the page's sheet comes to"
chip(f::Film, r) = begin
  e = f.e
  it = K.item(e, findfirst(==("```sheet"), e.buf.lines) + 1)
  s = it.content
  wide = K.chip_w(K.Face(K.SHEET_FONT, K.SHEET_WEIGHT, s.size, K.colours.ink, false), s.results[r])
  (K.num(e.origin[1] + e.width - K.SHEET_X - wide / 2), K.num(e.origin[2] + it.top + K.row_top(s, r) + s.heights[r] / 2))
end

"Scroll the page in `seconds`, so that the line with `words` is `top` px under the top of the page's part of the window"
scroll!(f::Film, words; top=40, seconds=0.9) = begin
  e = f.e
  from = K.num(e.scroll.offset)
  most = max(0.0, K.num(e.scroll.content_height) - (TALL - K.num(K.above_page(e))))
  to = clamp(K.num(K.item(e, line(f, words)).top) - top, 0.0, most)
  n = max(1, round(Int, seconds * FPS))
  for k in 1:n
    e.scroll.offset = px(from + (to - from) * ease(k / n))
    shoot!(f)
  end
  f
end

# --- the scenes --------------------------------------------------------------------

"The page, and the level under it: the lines of Markdown that it's made of"
opening(f::Film) = begin
  e = f.e
  say!(f, "This page is a Markdown file.")
  at!(f, 900, 520)
  hold!(f, 2.2)
  click!(f, words_at(f, "This page is a"))
  say!(f, "⌘E goes down a level: the same lines, as plain text.")
  key!(f, Keys.e, Keys.cmd)
  hold!(f, 2.6)
  key!(f, Keys.e, Keys.cmd)
  hold!(f, 0.8)
end

"One to-do item is a line, a card and a bar"
one_thing(f::Film) = begin
  say!(f, "One thing shows in many blocks. Tick it once.")
  glide!(f, box(f, "Lay the new pipe"))
  hold!(f, 0.5)
  click!(f)
  hold!(f, 2.0)
  v = block(f, K.BOARD)
  say!(f, "Drag a card. Ladder writes the change into the page's text.")
  drag!(f, middle(rect(v.parts[(:card, "Tile the walls")])), middle(rect(v.parts[(:column, 2)])))
  hold!(f, 1.6)
end

"The page on another day"
another_day(f::Film) = begin
  scroll!(f, "```schedule"; top=30)
  v = block(f, K.DAY_BLOCK)
  hold!(f, 0.3)
  say!(f, "Drag the day. Each block shows the plan for that day.")
  y = v.box[2] + 30
  today = findfirst(==(K.calendar_today()), v.days)
  drag!(f, (K.day_spot(v, today), y), (K.day_spot(v, min(today + 7, length(v.days))), y); seconds=2.4)
  hold!(f, 1.6)
  click!(f, middle(rect(v.parts[(:button, :today)])))
  hold!(f, 0.6)
end

"A number that a drag changes"
sums(f::Film) = begin
  scroll!(f, "## What it costs"; top=30)
  say!(f, "Drag a number. Each row under it follows.")
  from = chip(f, 1)
  drag!(f, from, (from[1] + 60, from[2]); seconds=2.0)
  hold!(f, 1.4)
end

"Where the code of a thing is, and a change to it"
its_code(f::Film) = begin
  e, w = f.e, f.w
  bar = block(f, "progress").value
  say!(f, "Hold ⌘ and ⌥. Each thing says where its code is.")
  w.keys |= Keys.cmd; w.keys |= Keys.opt
  glide!(f, chip(f, 4))
  hold!(f, 0.9)
  glide!(f, middle(rect(bar)); seconds=0.9)
  hold!(f, 1.4)
  w.keys ⊻= Keys.cmd; w.keys ⊻= Keys.opt
  # A click there opens the code in a second window. The film has one window, so it shows the file in this one.
  method = K.drawn_by(bar)
  file, at = K.code_place(method)
  say!(f, "Click, and you're in that code. Change it, and press ⌘Return.")
  K.open!(e, file)
  K.show_line!(e, at)
  e.nodes[:hold] = (at, 150px)
  at!(f, 980, 300)
  hold!(f, 1.8)
  b = e.buf
  # The bar gets thick: each `10px` of the method becomes `22px`, and each `5px` becomes `11px`
  for i in at:at+4, (old, new) in ("height(10px)" => "height(22px)", "radius(5px)" => "radius(11px)")
    while (r = findfirst(old, b.lines[i])) !== nothing
      from = length(b.lines[i], 1, prevind(b.lines[i], first(r)))
      K.edit!(b, (i, from), (i, from + length(old)), new)
      hold!(f, 0.35)
    end
  end
  b.caret = b.anchor = (at, 0)
  hold!(f, 0.5)
  K.run_here!(e)
  hold!(f, 0.9)
  say!(f, "The bar is drawn the new way at once.")
  K.open!(e, f.page)
  # The caret goes to a heading: in the block's own lines, it would show those lines and not the bar
  K.show_line!(e, line(f, "## What it costs"))
  e.nodes[:hold] = (line(f, "## What it costs"), 30px)
  at!(f, 900, 300)
  hold!(f, 2.6)
end

"A command by its name"
command(f::Film) = begin
  e = f.e
  K.focus(e)
  say!(f, "⌘⇧P runs a command by its name.")
  key!(f, Keys.p, Keys.cmd, Keys.shft)
  hold!(f, 0.7)
  type!(f, "theme")
  hold!(f, 0.5)
  key!(f, Keys.enter)
  hold!(f, 0.6)
  type!(f, "night")
  hold!(f, 0.4)
  key!(f, Keys.enter)
  hold!(f, 0.3)
  e.theme == :night || key!(f, Keys.enter)
  # The keys choose the colours. If this version's palette asks another way, the film still ends at night.
  e.theme == :night || (e.popup = :none; K.theme!(e, :night))
  hold!(f, 1.2)
  scroll!(f, "# The bathroom"; top=0, seconds=1.2)
  say!(f, "Ladder  ·  github.com/jkroso/Ladder")
  hold!(f, 2.6)
end

const SCENES = [opening, one_thing, another_day, sums, its_code, command]

# --- the film ----------------------------------------------------------------------

"""
Make the film at `out`, an .mp4 file, with the scenes `scenes`. It gives the
path of the film. `keep` leaves the folder of the pictures where it is, and
gives that folder too.
"""
make(out::AbstractString; scenes=SCENES, keep=false) = begin
  Sys.which("ffmpeg") === nothing && error("The film needs ffmpeg. Homebrew gets it: brew install ffmpeg")
  dir = realpath(mktempdir(cleanup=!keep))
  frames = mkpath(joinpath(dir, "frames"))
  # The settings of the film's window go to a file of their own, not to the one that Ladder uses
  settings = joinpath(dir, "settings")
  Core.eval(K, :(settings_file() = $settings))
  page = joinpath(dir, "bathroom.md")
  write(page, PAGE)
  cp(joinpath(K.pages_dir[], "progress.jl"), joinpath(dir, "progress.jl"))
  # Wednesday 18 November 2026 is today in the film, so that each film has the same days
  was = K.calendar_day[]
  K.calendar_day[] = Date(2026, 11, 18)
  e = Base.invokelatest(K.build_editor, page)
  e.remember = false
  w = Window(e, size=(px(WIDE), px(TALL)))
  f = Film(e, w, page, frames, 0, "")
  try
    foreach(_ -> Base.invokelatest(frame, w), 1:4)
    K.focus(e)
    for scene in scenes
      Base.invokelatest(scene, f)
    end
  finally
    K.calendar_day[] = was
    close(w)
  end
  mkpath(dirname(abspath(out)))
  # Each side of the picture has to be an even number of pixels for the film's kind of video
  run(pipeline(`ffmpeg -y -loglevel error -framerate $FPS -i $(joinpath(frames, "%05d.png")) -vf "scale=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -pix_fmt yuv420p -crf 20 -movflags +faststart $out`))
  keep ? (out, frames) : out
end

if abspath(PROGRAM_FILE) == @__FILE__
  out = isempty(ARGS) ? joinpath(@__DIR__, "build", "film", "ladder.mp4") : abspath(expanduser(ARGS[1]))
  println("Made ", make(out), " with ", FPS, " frames a second.")
  exit()
end
