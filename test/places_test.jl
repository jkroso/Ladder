# Tests for the places that a map has from the rest of its page, in main.jl:
# a pin for the address of each contact, a map with no place of its own, and
# the marks between a contact's card and its pin. Run them with
# `julia -O0 --project=. test/places_test.jl`. They use neither the network
# nor the program that asks Apple's maps: map_fake.jl takes the place of both.
# Set `LADDER_SHOTS` to a folder, and they save pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "../map" => M0
@use "./map_fake" => Fake
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px
const M = K.Maps

@testset "a map round some places" begin
  a = M0.around([(-37.7701, 144.9610), (-37.7690, 144.9405)], 15, 800, 280)
  @test a.zoom == 15 && isapprox(a.centre[2], 144.95075, atol=1e-4) && -37.7701 < a.centre[1] < -37.7680
  # Places that are far apart show from further away
  far = M0.around([(-37.77, 144.96), (-33.86, 151.21)], 15, 800, 280)
  @test far.zoom < 8 && all(p -> 0 <= p[1] <= 800 && 0 <= p[2] <= 280, [M0.point(at, far.centre, far.zoom, 800, 280) for at in [(-37.77, 144.96), (-33.86, 151.21)]])
  @test M0.around([(-37.77, 144.96)], 12, 800, 280).zoom == 12
end

const was = (M.HELPER[], M.FINDER[], M.OPENER[], K.MEDIA_CACHE[])
M.HELPER[], M.FINDER[], M.OPENER[] = Fake.helper, Fake.finder, Fake.opener
K.MEDIA_CACHE[] = mktempdir()
try
  dir = mktempdir()
  page = joinpath(dir, "job.md")
  write(page, """
  ---
  title: The job
  address: -37.7655, 144.9500
  ---

  # The job at Wattle Street

  ```map
  -37.7694, 144.9405
  ```

  ```contact
  Mei Tanaka
  role: Site manager
  address: -37.7701, 144.9610

  Harbour Builders
  kind: company
  phone: (02) 5550 0100

  Sam Okoro
  address: 12 Somewhere Road, Brunswick
  ```

  ```map
  ```

  The end.
  """)
  e = K.build_editor(page)
  w = Window(e, size=(1000px, 1300px))
  (; frames, at, press, release, shot) = drive(w, moved=2, pressed=1)
  frames()
  view(n) = e.nodes[(:block, K.MAP, page, n)]
  # Draw frames until both maps have their pictures and their places, for 10 seconds at most
  t = time()
  while time() - t < 10 && !(K.map_shows(view(1)) && K.map_shows(view(2)) && length(K.map_others(view(2))) == 3)
    sleep(0.02); frames(1)
  end
  frames()
  contacts = e.nodes[(:block, K.CONTACT, page, 1)]
  "The head of the pin of the place called `name` on map `n`, in the window"
  pin(n, name) = (v = view(n); o = only(o for o in K.map_others(v) if o.name == name); p = K.other_point(v, o); (v.box[1] + p[1], v.box[2] + p[2] - 26))

  @testset "what the page gives its maps" begin
    @test K.block_places(K.CONTACT, ["Mei", "address: 4 Wharf Road", "", "Co", "", "", "Sam", "role: Boss", "address: 9 High Street"]) ==
          [(name="Mei", place="4 Wharf Road", line=2), (name="Sam", place="9 High Street", line=9)]
    @test K.block_places(K.BOARD, ["address: 1 Road"]) == []
    places = K.page_places(e)
    @test [p.name for p in places] == ["The job", "Mei Tanaka", "Sam Okoro"]
    @test all(p -> occursin(p.place, e.buf.lines[p.line]), places)
  end

  @testset "a map shows the other places of its page" begin
    others = K.map_others(view(1))
    @test [o.name for o in others] == ["The job", "Mei Tanaka", "Sam Okoro"] && others[2].at == (-37.7701, 144.9610) && others[3].at == Fake.ADDRESS
    # The pin of a place that's in the map is in the map's box
    p = pin(1, "The job")
    @test view(1).box[1] < p[1] < view(1).box[1] + view(1).box[3]
    shot("places.png")
  end

  @testset "a map with no place of its own shows them all" begin
    v = view(2)
    @test isempty(v.data.place) && K.map_shows(v) && K.map_around(v) !== nothing && !K.map_moves(v)
    @test all(o -> K.other_point(v, o) !== nothing, K.map_others(v)) && length(K.map_others(v)) == 3
    @test !haskey(v.parts, (:button, :open)) || rect(v.parts[(:button, :open)]) === nothing
  end

  @testset "the mouse on a pin, and on a contact's card" begin
    at(pin(2, "Mei Tanaka"))
    @test K.other_at(view(2)).name == "Mei Tanaka" && K.pointed(view(2)) == "Mei Tanaka" && K.pointed(e) == "mei tanaka"
    @test K.marked(contacts, "Mei Tanaka")
    card = only(c for c in values(contacts.parts) if c isa K.ContactCard && c.k == 3)
    at(middle(rect(card)) .+ (0, 10))
    @test K.pointed(contacts) == "Sam Okoro" && K.marked(view(1), "Sam Okoro")
    shot("places-card.png")
    # A click on a pin goes to the place's line of the page
    press(pin(2, "Mei Tanaka")); release()
    @test e.buf.caret[1] == findfirst(==("address: -37.7701, 144.9610"), e.buf.lines)
    @test view(2).data.place == "" && view(1).data.place == "-37.7694, 144.9405"   # no click moved a place
  end

  @testset "a map on a page with no place says what to write" begin
    other = joinpath(dir, "empty.md")
    write(other, "# Nothing\n\n```map\n```\n")
    e2 = K.build_editor(other)
    w2 = Window(e2, size=(800px, 400px))
    frame(w2); frame(w2)
    @test isempty(K.page_places(e2)) && isempty(K.map_others(e2.nodes[(:block, K.MAP, other, 1)]))
    close(w2)
  end
  close(w)
finally
  M.HELPER[], M.FINDER[], M.OPENER[], K.MEDIA_CACHE[] = was
  # The pretend program notes what it's asked. Another test that uses it starts with nothing noted.
  foreach(empty!, (Fake.calls, Fake.finds, Fake.opened))
end
