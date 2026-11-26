# A map shows the place that its block names, with a pin on the place. In a
# document it's a code block in the language `map`:
#
#     ```map
#     8 Wattle Street, Brunswick VIC 3056
#     zoom: 15
#     centre: -37.76810, 144.94260
#     ```
#
# The first line that isn't a setting is the place: an address, or a latitude
# and a longitude like `-37.7701, 144.9610`. The pin is on the place. `zoom`
# says how much the map shows, as maps on the web count it: each step up shows
# half as much from side to side. Without it, the zoom is 15, which shows a
# few streets. `centre` is the latitude and the longitude in the middle of the
# map. Without it, the place is in the middle. `center` is read as the same
# word.
#
# This file reads and writes those lines, writes the place as a link to Apple
# Maps, finds where the place is, and gets the picture of the map. It also
# works out which latitude and longitude is at each point of the picture, so
# that Ladder can draw the pin on the place, a drag can move the map and a
# click can move the place. It draws nothing.
#
# map.swift does the two things that need Apple's maps, as a program of its
# own, because macOS only offers its maps to Swift. Both need the network the
# first time, and what comes back is kept in a folder, so a map shows at once
# the next time, with no network:
#
# - It finds a place: the latitude and the longitude of an address, and the
#   address that Apple has for a place. That's kept in a text file, named by
#   the place.
# - It makes the picture of the map round a point. The picture has no pin, so
#   it doesn't change when the place does. It's kept as a PNG file, named by
#   its middle, the zoom, the size and whether the page is dark.
#
#     f = found!(folder, "8 Wattle Street, Brunswick")
#     f.state         # :there, :coming, :failed, :lost or :none. Ask again while it's :coming.
#     facts(f.file)   # the latitude, the longitude and the address, once the state is :there
#     p = picture!(folder, (-37.7694, 144.9405), 15, 720, 280, false)
#     p.file          # the PNG file, once its state is :there
#
# The Ladder app has the program in it, beside its own program. When Ladder
# runs from its source, it compiles map.swift the first time it's needed,
# which takes a few seconds, and keeps the program in a folder of the Mac's
# caches. That needs Swift, which comes with Xcode and its command line tools.

@use "./swift" target programs kept! settle! jobs RETRY Kept
@use "./swift" => Swift
@use Base64: base64encode
@use Printf: @sprintf

"The language of a code block that is a map"
const MAP = "map"
const ZOOM = 15       # the zoom of a block that names none
const ZOOMS = 3:19    # the least and the most that a block can ask for: a continent, and one building
const TALL = 280      # how tall the picture of a map is, in px
const SCALE = 2       # how many pixels of the picture's file go to a px, as map.swift has it

"A latitude and a longitude, in degrees"
const LatLon = NTuple{2,Float64}

mutable struct Site
  place::String                   # the address, or the latitude and the longitude, as the block has it
  zoom::Int
  centre::Union{Nothing,LatLon}   # what's in the middle of the map, or nothing when the place is
  other::Vector{String}           # the lines after the place that this file doesn't know, kept as they are
end

Site() = Site("", ZOOM, nothing, String[])

"Read a map from the lines of its block"
site(lines) = begin
  s = Site()
  for line in lines
    text = strip(line)
    isempty(text) && continue
    m = match(r"^zoom\s*:\s*(.*)$"i, text)
    if m !== nothing
      z = tryparse(Float64, strip(m[1]))
      z === nothing || !isfinite(z) || (s.zoom = clamp(round(Int, z), ZOOMS))
    elseif (m = match(r"^cent(?:re|er)\s*:\s*(.*)$"i, text)) !== nothing
      # A middle that's no latitude and longitude is left out, and the place is in the middle
      c = coordinates(m[1])
      c === nothing || (s.centre = c)
    elseif isempty(s.place)
      s.place = String(text)
    else
      push!(s.other, String(text))
    end
  end
  s
end

"The lines of a map's block. A map with no place has no lines."
written(s::Site) = isempty(s.place) ? copy(s.other) :
  String[s.place, "zoom: $(s.zoom)", (s.centre === nothing ? () : ("centre: " * text(s.centre),))..., s.other...]

"A latitude and a longitude as a block has them, with five decimal places, which is to the nearest metre: -33.85930, 151.21320"
text(at::LatLon) = @sprintf("%.5f, %.5f", at[1], at[2])

"`at` to the five decimal places that a block keeps"
rounded(at::LatLon) = (round(at[1], digits=5), round(at[2], digits=5))

"Show `by` steps more of the place, or less with a `by` under 0. It's true when the zoom changed."
zoom!(s::Site, by::Int) = (z = clamp(s.zoom + by, ZOOMS); z == s.zoom ? false : (s.zoom = z; true))

const COORDINATES = r"^([-+]?\d+(?:\.\d+)?)\s*(?:,|\s)\s*([-+]?\d+(?:\.\d+)?)$"

"The latitude and the longitude that `place` holds, like \"-37.7701, 144.9610\", or nothing when it's an address"
coordinates(place::AbstractString) = begin
  m = match(COORDINATES, strip(place))
  m === nothing && return nothing
  lat, lon = parse(Float64, m[1]), parse(Float64, m[2])
  abs(lat) <= 90 && abs(lon) <= 180 ? (lat, lon) : nothing
end

"""
`place` as Apple's maps are asked for it: an address with one space between
its words, and a latitude and a longitude with a comma between them.
"""
query(place::AbstractString) = begin
  m = coordinates(place) === nothing ? nothing : match(COORDINATES, strip(place))
  m === nothing ? replace(strip(place), r"\s+" => " ") : "$(m[1]),$(m[2])"
end

"`text` as part of a web address: each byte that isn't a letter, a digit or one of -._~ is written as % and its number"
escaped(text::AbstractString) = join(b in UInt8('a'):UInt8('z') || b in UInt8('A'):UInt8('Z') || b in UInt8('0'):UInt8('9') || b in b"-._~" ?
                                     string(Char(b)) : "%" * uppercase(string(b, base=16, pad=2)) for b in codeunits(text))

"The web address that shows `place` in Apple Maps. A browser opens it on any computer."
link(place::AbstractString) = "https://maps.apple.com/?q=" * escaped(query(place))

"The address that opens the Maps app of the Mac at `place`"
app_link(place::AbstractString) = "maps://?q=" * escaped(query(place))

"""
The name of the file that keeps the picture whose middle is `centre`, without
what it ends in. The middle counts to the five decimal places that a block
keeps. The name starts with what the picture holds: a map with no pin. A
picture that an older map.swift made with a pin in it has another name, and
isn't taken for this one.
"""
name(centre, zoom, wide, tall, dark) = "map-" * string(hash(join(("plain", text(centre), zoom, wide, tall, dark ? "dark" : "light"), '|')), base=16)

"The PNG file in `folder` that keeps the picture whose middle is `centre`"
file(folder, centre, zoom, wide, tall, dark) = joinpath(folder, name(centre, zoom, wide, tall, dark) * ".png")

"""
The text file in `folder` that keeps what Apple has for `place`. Two blocks
that name one place with other capitals or other spaces have the same file.
"""
place_file(folder, place) = joinpath(folder, "place-" * string(hash(lowercase(query(place))), base=16) * ".txt")

"""
What the text file `path` holds of a place: its latitude, its longitude and
the address that Apple has for it, which is "" when Apple has none. It's
nothing when the file is gone, or holds something else.
"""
facts(path) = begin
  isfile(path) || return nothing
  parts = split(strip(read(path, String), ['\n', '\r']), '\t', limit=3)
  length(parts) == 3 || return nothing
  lat, lon = tryparse(Float64, parts[1]), tryparse(Float64, parts[2])
  (lat === nothing || lon === nothing) ? nothing : (lat=lat, lon=lon, address=String(strip(parts[3])))
end

"How wide the picture in the file `png` is, in px, or nothing when the file is no PNG file"
wide(png) = begin
  bytes = open(io -> read(io, 24), png)
  length(bytes) == 24 && bytes[13:16] == b"IHDR" ? Int(ntoh(reinterpret(UInt32, bytes[17:20])[1])) ÷ SCALE : nothing
end

"A picture as an address that holds the picture itself, for a page of HTML that needs no other file. `png` is a PNG file, or the bytes of one."
data_uri(png::AbstractString) = data_uri(read(png))
data_uri(png::Vector{UInt8}) = "data:image/png;base64," * base64encode(png)

# --- where each point of the picture is in the world ------------------------------------
#
# A map on the web is the world as Mercator drew it: a square, 256 px wide at
# zoom 0 and twice as wide at each step. A picture of a map is a rectangle of
# that square, with the map's `centre` in its middle. map.swift asks MapKit
# for that same rectangle, so these sums say exactly where a latitude and a
# longitude is in the picture. A point of the picture is in px from its top
# left corner, across and then down.

"How many px wide the map of the whole world is at `zoom`"
world(zoom) = 256.0 * 2.0^zoom

"Where a latitude and a longitude is on the map of the whole world at `zoom`, in px from its top left corner"
spot(at, zoom) = (w = world(zoom); ((at[2] + 180) / 360 * w, (1 - asinh(tan(deg2rad(at[1]))) / π) / 2 * w))

"The latitude and the longitude at a point of the map of the whole world at `zoom`. A point past the map's side edge is on its other side."
unspot(p, zoom) = (w = world(zoom); (rad2deg(atan(sinh(π * (1 - 2p[2] / w)))), mod(p[1], w) / w * 360 - 180))

"""
The zoom that a picture `wide` px by `tall` px is made at for a block that
asks for `zoom`. MapKit frames a picture exactly only when the picture is no
more than half as wide as the map of the world. So a picture that's too wide
for a low zoom is made at the lowest zoom that it fits.
"""
fit(zoom, wide, tall) = max(zoom, ceil(Int, log2(max(wide, tall, 1) / 128)))

"""
The point of a picture where the latitude and the longitude `at` is. The
picture is `wide` px by `tall` px, and `centre` is in its middle. The point
is outside the picture when `at` isn't in it.
"""
point(at, centre, zoom, wide, tall) = begin
  w = world(zoom)
  a, c = spot(at, zoom), spot(centre, zoom)
  # Across the line where east meets west, the short way round is the way that the picture shows
  (wide / 2 + mod(a[1] - c[1] + w / 2, w) - w / 2, tall / 2 + a[2] - c[2])
end

"The latitude and the longitude at the point `p` of a picture. What `point` gives for them is `p` again."
latlon(p, centre, zoom, wide, tall) = (c = spot(centre, zoom); unspot((c[1] + p[1] - wide / 2, c[2] + p[2] - tall / 2), zoom))

"The middle of a picture whose middle was `centre`, after a drag moved the map `dx` px across and `dy` px down"
moved(centre, dx, dy, zoom) = (c = spot(centre, zoom); unspot((c[1] - dx, c[2] - dy), zoom))

"`centre`, or the nearest middle that keeps a picture `tall` px tall on the map of the world, which has a top and a bottom"
held(centre, zoom, tall) = begin
  w = world(zoom)
  c = spot(centre, zoom)
  unspot((c[1], clamp(c[2], tall / 2, w - tall / 2)), zoom)
end

"""
The middle and the zoom of a map that shows every one of the places `ats`: a
latitude and a longitude each. The map is `wide` px by `tall` px. The zoom is
the highest one, no higher than `most`, that leaves room round the places for
their pins. One place alone is in the middle, at `most`.
"""
around(ats, most, wide, tall) = begin
  spots = [spot(at, 0) for at in ats]
  (x1, x2), (y1, y2) = extrema(first, spots), extrema(last, spots)
  zoom = first(ZOOMS)
  for z in clamp(most, ZOOMS):-1:first(ZOOMS)
    k = 2.0^z
    ((x2 - x1) * k <= max(wide - 120, 40) && (y2 - y1) * k <= max(tall - 110, 40)) && (zoom = z; break)
  end
  # The pins stand over their places, so the places are a little under the middle
  (centre=rounded(unspot(((x1 + x2) / 2, (y1 + y2) / 2 - 14 / 2.0^zoom), 0)), zoom=zoom)
end

# --- the program that asks Apple's maps -------------------------------------------------

const SOURCE = joinpath(@__DIR__, "map.swift")

"The program in the Ladder app, or nothing when Ladder runs from its source"
bundled() = Swift.bundled("map")

"Compile map.swift into the program at `out`. The app's build runs it."
compile(out) = Swift.compile(SOURCE, out)

"""
The command that runs the program with `args`: the program in the app, or the
one compiled from the source, which is kept in the folder `dir`. If that isn't
compiled yet, the command compiles it first.
"""
command(args; dir=programs()) = Swift.command(SOURCE, "map-program-", args; app="map", dir)

"""
Start the program that makes the picture of the map whose middle is `centre`.
It writes the picture to the file `png`, and why it failed to the file `err`.
This gives the program as it runs.
"""
run_program(centre, zoom, wide, tall, dark, png, err) =
  run(pipeline(command([(dark ? ["--dark"] : String[])..., string(zoom), string(wide), string(tall), png, query(text(centre))]),
               stdout=devnull, stderr=err), wait=false)

"""
Start the program that finds `place`. It writes one line to the file `out`:
the latitude, the longitude and the address that Apple has for the place,
with a tab between each two. It writes why it failed to the file `err`. This
gives the program as it runs.
"""
find_program(place, out, err) = run(pipeline(command(["--find", query(place)]), stdout=out, stderr=err), wait=false)

"""
The function that makes a picture. It takes what `run_program` takes. It gives
a program that runs, or the number that a program which has finished already
ended with: 0 when the picture is written, and 1 when it isn't. A test puts a
function of its own here, so that it uses neither the program nor the network.
"""
const HELPER = Ref{Any}(run_program)

"""
The function that finds a place. It takes what `find_program` takes. It gives
a program that runs, or the number that a program which has finished already
ended with: 0 when the line is written, 2 when there's no such place, and 1
for anything else. A test puts a function of its own here.
"""
const FINDER = Ref{Any}(find_program)

"Open the address `url` with the app that the Mac uses for it. An address that starts with maps: opens the Maps app."
open_app(url) = (run(pipeline(`open $url`, stdout=devnull, stderr=devnull), wait=false); nothing)

"The function that opens the Maps app at a place, given the place's `app_link`. A test puts a function of its own here."
const OPENER = Ref{Any}(open_app)

"Open the Maps app of the Mac at `place`"
open_place(place::AbstractString) = try OPENER[](app_link(place)) catch; nothing end

"What to say when Apple's maps have no such place"
const LOST = "Ladder can't find this place. Check the address."
"What to say when the picture can't be made for now"
const FAILED = "Ladder can't get this map now."
const NO_SWIFT = "Ladder needs Swift to make a map. It comes with Xcode's command line tools."

"""
The picture of the map whose middle is the latitude and the longitude
`centre`, `wide` px by `tall` px, kept in `folder`. It has no pin. `kept!`
says what its `state` is.
"""
picture!(folder, centre, zoom, wide, tall, dark; start=true) =
  kept!(file(folder, centre, zoom, wide, tall, dark); start, failed=FAILED, lost=LOST, no_swift=NO_SWIFT) do part, err
    HELPER[](rounded(centre), zoom, wide, tall, dark, part, err)
  end

"""
What Apple has for `place`, kept in `folder`: where an address is, and the
address of a latitude and a longitude. `kept!` says what its `state` is, and
`facts(f.file)` reads it once it's there. A place is asked for once, however
many pictures show it.
"""
found!(folder, place; start=true) =
  kept!((part, err) -> FINDER[](place, part, err), place_file(folder, place); start, failed=FAILED, lost=LOST, no_swift=NO_SWIFT)

"""
The file `target` turned out not to hold what it should, as a picture that
was cut short. Take it away, so that Ladder makes it again in a minute.
"""
spoiled!(target) = Swift.spoiled!(target; failed=FAILED)
