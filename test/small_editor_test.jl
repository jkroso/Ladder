# Tests for a small editor: an Editor that a part of the window makes for text of its
# own, like the field of a cell of a table. See "a small editor" in editor_type.jl. A
# key that's pressed in it goes to its owner first, as `owner_key!`, so a new kind of
# owner needs a method of that and no change to `key_does!`. Run them with
# `julia -O0 --project=. test/small_editor_test.jl`. They press keys in a window that
# isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress Keys onkey Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const page = joinpath(dir, "page.md")
write(page, "# A page\n\nSome words.\n")
const e = K.build_editor(page)
const w = Window(e, size=(700px, 500px))
frames(n=2) = foreach(_ -> Base.invokelatest(frame, w), 1:n)
frames(3)

"Press the key `k` with the keys `held` down"
press(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())

"A kind of owner that only these tests have. It notes each key that it's asked about. Return is its own, and esc goes on to the page."
struct Field
  keys::Vector{Any}
end
K.owner_key!(f::Field, sub, win, k, command, select) = begin
  push!(f.keys, (k, command))
  k == Keys.enter ? K.handled : k == Keys.escape ? nothing : :text
end

"A small editor of a new field, laid out as the part that shows it would lay it out"
field() = begin
  f = Field(Any[])
  sub = K.small_editor(f, parent=e)
  K.follow_host!(sub, e)
  K.layout!(sub, 300px)
  f, sub
end

@testset "a small editor knows its owner" begin
  f, sub = field()
  @test K.owner_of(sub) === f && getfield(sub, :parent) === e && sub.buf.lines == [""]
  @test K.owner_of(e) === nothing   # the window's own editor has none
  # An owner that's a part of the window itself is the editor's parent there. A `Field` isn't one, so `field` names the page.
  part = K.Shown()
  @test getfield(K.small_editor(part), :parent) === part && K.owner_of(K.small_editor(part)) === part
  b = K.Buffer(lines=["abc"])
  @test K.small_editor(f, b, parent=e).buf === b
  # With no owner, and with an owner that takes no key, every key is the text's
  @test K.owner_key!(nothing, e, w, Keys.enter, nothing, false) === :text
  @test K.owner_key!("some other owner", sub, w, Keys.enter, nothing, false) === :text
end

@testset "a key in a small editor goes to its owner first" begin
  f, sub = field()
  K.focus(sub)
  typed("ab")
  @test sub.buf.lines == ["ab"] && isempty(f.keys)   # a character is the text's, and no key press
  # The owner took Return, so the editor starts no new line
  press(Keys.enter)
  @test f.keys == Any[(Keys.enter, nothing)] && sub.buf.lines == ["ab"] && w.focus === sub
  # The owner says that ⌫ is the text's, and the editor does its command
  press(Keys.backspace)
  @test first(last(f.keys)) == Keys.backspace && last(last(f.keys)) isa Symbol && sub.buf.lines == ["a"]
  # Esc goes on to the page that the field is in, which takes the keyboard back. The field's editor does nothing with it.
  press(Keys.escape)
  @test first(last(f.keys)) == Keys.escape && w.focus === e && sub.buf.lines == ["a"] && !sub.buf.reading
  # The window's own editor has no owner: Return starts a new line in the page
  n = length(e.buf.lines)
  e.buf.reading = false
  e.buf.caret = e.buf.anchor = (3, 0)
  press(Keys.enter)
  @test length(e.buf.lines) == n + 1 && length(f.keys) == 3
end
