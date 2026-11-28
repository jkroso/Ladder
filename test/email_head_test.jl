# Tests for the top of an email, which has levels of its own: a click gives it
# the keyboard, and ⌘E, the ladder or the slider then shows every field of
# the email's header. See "the top of an email" in email_head.jl. Run them with
# `julia -O0 --project=. test/email_head_test.jl`. They click in a window
# that isn't on the screen. Set `LADDER_SHOTS` to a folder, and they save
# pictures of the page there.

@use Test: @test, @testset
@use "../main" => K
@use "./webpage_fake" => Fake
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse
@use "github.com/jkroso/UI.jl/Interface/draw" frame rect popups
@use "github.com/jkroso/UI.jl/Interface/save" save_png
@use GeometryBasics: Vec2
@use "./drive" drive middle
const px = K.px

K.Webpages.HELPER[] = Fake.helper   # no program draws an email, and the web isn't asked
K.Webpages.OPENER[] = Fake.opener
K.MEDIA_CACHE[] = mktempdir()
K.Eml.CACHE[] = mktempdir()

const dir = mktempdir()
const SIGNATURE = "v=1; a=rsa-sha256; c=relaxed/relaxed; d=example.com; s=selector1; bh=" * "Qx7"^40 * "; b=" * "AbCdEfGh0123456789+/"^20
const LONG_NAME = "X-MS-Exchange-CrossTenant-OriginalAttributedTenantConnectingIp"
const email = joinpath(dir, "RE Centient production.eml")
write(email, join(["Delivered-To: jake@example.com",
                   "Received: from mail.example.com (mail.example.com. [203.0.113.7])",
                   "        by mx.example.com with ESMTPS id 42; Wed, 18 Nov 2026 06:24:03 +0000",
                   "DKIM-Signature: $SIGNATURE",
                   "$LONG_NAME: 203.0.113.7",
                   "From: Sam Lee <sam@example.com>",
                   "To: Jake Rosoman <jake@example.com>",
                   "Subject: RE: Centient production",
                   "Message-ID: <abc123@example.com>",
                   "Date: Wed, 18 Nov 2026 17:24:00 +1100",
                   "MIME-Version: 1.0",
                   "Content-Type: text/plain; charset=utf-8",
                   "", "Hi Jake,", "", "I hope that you're well.", ""], "\r\n"))
# A page that's an email and not an .eml file: one that was sent, which can be changed
const sent = joinpath(dir, "Sent.md")
write(sent, "---\nfrom: Jake Rosoman <jake@example.com>\nto: Sam Lee <sam@example.com>\ndate: 18 Nov 2026, 5:30 pm\nsubject: The quote\n---\n\nHi Sam,\n")

const e = K.build_editor(email)
const w = Window(e, size=(1000px, 900px))
const (; frames, at, press, release, click, key, shot) = drive(w)
e.plain && K.level!(e)   # the page starts at the high level, whatever a test before this one left
frames(3)
K.focus(e)

"Press ⌘E"
cmd_e() = (w.keys |= Keys.cmd; onkey(w, KeyPress{Keys.e}(0, w)); w.keys ⊻= Keys.cmd; frames())
"The slider, or nothing while it's closed"
slider() = (l = get(e.nodes, K.LEVELS_KEY, nothing); l !== nothing && l.open ? l : nothing)
"Put the mouse over the picture in the top bar, and wait until the slider has opened all the way"
hover() = (at(middle(rect(e.nodes[:mode]))); sleep(2K.OPENS_IN); frames(); slider())

head() = e.nodes[:email_head]
"The words that the top of the email shows"
words(node=rect(head()), out=String[]) = (node isa K.ConcreteText ? push!(out, node.from.content) : foreach(n -> words(n, out), node.children); out)
"The texts that the top of the email shows, each where it was drawn"
texts(node=rect(head()), out=[]) = (node isa K.ConcreteText ? push!(out, node) : foreach(n -> texts(n, out), node.children); out)
has(word) = any(t -> occursin(word, t), words())

@testset "the top of an email is a part with levels of its own" begin
  @test parentmodule(K.fold) === parentmodule(K.whole_header)   # the email's own fold: no function of another module has the name
  @test head() isa K.EmailHead && has("RE: Centient production") && has("Sam Lee")
  # Until the top has the keyboard, the ladder is the page's
  @test K.level_part(e) isa K.Document && K.levels(e) != K.HEAD_LEVELS
  low = rect(head()).height
  click(middle(rect(head())))
  @test w.focus === head() && K.level_part(e) === head()
  @test K.levels(e) == K.HEAD_LEVELS && K.level(e) == 2
  @test occursin("every field of the email's header", K.stop_tip(e, 1))
  shot("head_focused.png")
end

@testset "⌘E shows every field of the header, and goes back up" begin
  page = e.plain
  cmd_e()
  @test head().full && K.level(e) == 1 && e.plain == page   # the page stays at its own level
  @test w.focus === head()   # and the top keeps the keyboard
  @test has("Received") && has("Message-ID") && has("<abc123@example.com>") && has("DKIM-Signature")
  @test has("from mail.example.com (mail.example.com. [203.0.113.7]) by mx.example.com")   # a field on two lines is one
  # The page's layout has room for every field
  item = e.layout[1]
  @test item.content.node === head() && item.tall >= rect(head()).height
  shot("head_full.png")
  cmd_e()
  @test !head().full && K.level(e) == 2 && w.focus === head()
end

@testset "a long signature and a long name break onto more lines and stay in the card" begin
  cmd_e()
  card = rect(head())
  right = card.left + card.width
  @test all(t -> t.left + t.width <= right + 1px, texts())
  signature = only(filter(t -> startswith(t.from.content, "v=1;"), texts()))
  @test count('\n', signature.from.content) >= 3
  @test replace(signature.from.content, '\n' => "", ' ' => "") == replace(SIGNATURE, ' ' => "")   # no character is lost
  name = only(filter(t -> startswith(t.from.content, "X-MS-"), texts()))
  @test occursin('\n', name.from.content) && replace(name.from.content, '\n' => "") == LONG_NAME
  @test all(endswith('-'), split(name.from.content, '\n')[1:end-1])   # it breaks after a hyphen
  # The name of each field is beside the first line of its value
  value = only(filter(t -> t.from.content == "203.0.113.7", texts()))
  @test abs(K.num(value.top - name.top)) < 1
  cmd_e()
end

@testset "a click on the ladder, or on a stop of the slider, keeps the top's keyboard" begin
  # The slider opens out from the picture with the ladder where the picture was, so a click there is on the ladder
  picture = middle(rect(e.nodes[:mode]))
  click(picture)
  @test head().full && w.focus === head() && K.level_part(e) === head()
  click(picture)
  @test !head().full && w.focus === head()
  l = hover()
  @test length(l.stops) == 2
  click(middle(rect(l.stops[1])))
  @test head().full && w.focus === head()
  at((500, 600))
  K.level!(head(), 2); frames()
end

@testset "esc, a click on the page and a key that scrolls give the keyboard back to the page" begin
  cmd_e()
  key(Keys.escape)
  @test w.focus === e && K.level_part(e) isa K.Document
  @test head().full   # the top stays at its level
  click(middle(rect(head())))
  @test w.focus === head()
  key(Keys.space)
  @test w.focus === e
  click(middle(rect(head())))
  r = rect(head())
  click((K.num(r.left + r.width / 2), K.num(r.top + r.height) + 60))
  @test w.focus === e
  K.level!(head(), 2); frames()
end

@testset "at the page's lower level, the top of the email still shows and has its levels" begin
  K.focus(e)
  cmd_e()
  @test e.plain && K.level_part(e) isa K.Document
  @test head() isa K.EmailHead && has("Sam Lee")
  click(middle(rect(head())))
  @test w.focus === head()
  cmd_e()
  @test head().full && e.plain && has("Message-ID")
  cmd_e()
  key(Keys.escape)
  cmd_e()
  @test !e.plain && !head().full
end

@testset "a page that's an email but not an .eml file shows its front matter as its header" begin
  K.open!(e, sent); frames(3)
  @test head() isa K.EmailHead && !head().full   # another file shows the top at its highest level
  @test has("The quote") && has("Jake Rosoman")
  click(middle(rect(head())))
  @test w.focus === head()
  cmd_e()
  @test has("from") && has("Sam Lee <sam@example.com>") && has("18 Nov 2026, 5:30 pm")
  # Return shows the front matter as it's written, with the caret in it
  key(Keys.enter)
  @test w.focus === e && e.buf.caret[1] == 2 && K.incode(e.buf, 1)
end

@testset "a page that can change: the caret on the top as a whole makes the ladder the top's" begin
  b = e.buf
  b.caret = b.anchor = (8, 0); K.touch!(e); frames()
  K.level!(head(), 2)   # the test before left it a level down
  @test K.level_part(e) isa K.Document
  b.caret = b.anchor = (1, 0); K.touch!(e); frames()
  @test K.picked(b) !== nothing && K.level_part(e) === head()
  cmd_e()
  @test head().full
  cmd_e()
  K.open!(e, email); frames(3)
  @test !head().full
end
