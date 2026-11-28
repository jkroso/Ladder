# Tests for the table of the settings: SETTINGS in settings.jl. Each setting is a row
# of it, and five things come from the rows: what reads the settings file, what
# writes it, SHARED, the settings that a part of another page takes from the page
# that shows it, and each setting's two names for the code of a page, like
# `page_glide` and `page_glide!`.
#
# Before the table, each of those was written out by hand. What these tests expect
# is what that code did, at commit a47c77c: its settings file for two editors, what
# it read from each line here, and what its names for a page's code gave and set.
# So the table reads and writes the file as before, byte for byte.
#
# Run them with `KIP_FROZEN=1 julia -O0 --project=. test/settings_table_test.jl`.
# They open no window, and they keep their settings file in a folder of their own.

@use Test: @test, @testset
@use "../main" => K
const px = K.px

const dir = mktempdir()
K.SETTINGS_FILE[] = joinpath(dir, "settings")
const folder = joinpath(dir, "folder")
mkpath(folder)
write(joinpath(folder, "a.md"), "# A\n")
write(joinpath(folder, ".dot.md"), "# Dot\n")

# The fields of the editor that are settings, in the order that SHARED had them
const FIELDS = (:theme, :font, :weight, :zoom, :widest, :plain, :spelling, :updates, :autosave, :peeks, :ai, :glide,
  :wrap, :numbers, :shade, :beside, :indent, :code_scale, :code_font, :code_weight, :guide, :bundle, :rebound, :side,
  :hidden, :right, :own, :pinned, :hide_bar)
# What `follow_host!` gave the editor of a part of another page: 15 settings, the look of a blog's page and the window's size
const FOLLOWS = (:theme, :look, :font, :weight, :zoom, :code_scale, :code_font, :code_weight, :indent, :wrap, :spelling,
  :glide, :bundle, :rebound, :widest, :size, :autosave)
const TERM_FIELDS = fieldnames(K.TermSettings)
const TERM_USUAL = (:block, false, false, false, :flash, 10_000, true)
const TERM_OTHER = (:underline, true, true, true, :none, 50_000, false)

"A value as these tests write it: a width as a number of pixels, and what's in a Dict or a Set in order"
simple(v) = v isa Dict ? sort!([string(k) => simple(x) for (k, x) in v]) : v isa Set ? sort!(collect(v)) : v isa Union{Real,Symbol,AbstractString,Nothing} ? v : v.value

"Every setting that the settings file keeps, with what the sidebar of `e` lists"
state(e) = Pair{Symbol,Any}[[f => simple(getfield(e, f)) for f in FIELDS]...,
  :listed => basename.(e.listed),
  :agentshidden => simple(K.AGENTS_HIDDEN[]), :models => simple(K.MODELS_CHOSEN[]), :pagecard => simple(K.PAGE_CARD_CHOSEN[]),
  (Symbol("term.", f) => getfield(K.TERM_SETTINGS, f) for f in TERM_FIELDS)...]

"An editor with every setting as it is when Ladder first starts"
usual() = begin
  K.AGENTS_HIDDEN[] = Set{String}()
  K.MODELS_CHOSEN[] = Dict{String,String}()
  K.PAGE_CARD_CHOSEN[] = nothing
  foreach((f, v) -> setfield!(K.TERM_SETTINGS, f, v), TERM_FIELDS, TERM_USUAL)
  e = K.Editor()
  e.folder = folder
  e
end

"An editor with every setting changed to something else that it can be"
other() = begin
  e = usual()
  K.AGENTS_HIDDEN[] = Set(["Grok"])
  K.MODELS_CHOSEN[] = Dict("Claude" => "opus", "Codex" => "gpt-5", "Grok" => "")
  K.PAGE_CARD_CHOSEN[] = 600px
  foreach((f, v) -> setfield!(K.TERM_SETTINGS, f, v), TERM_FIELDS, TERM_OTHER)
  e.theme = :night; e.font = "Helvetica"; e.weight = 300; e.zoom = 1.5; e.widest = 800px; e.plain = true
  e.spelling = false; e.updates = false; e.autosave = true; e.peeks = false; e.ai = "Codex"; e.glide = false
  e.wrap = false; e.numbers = false; e.shade = true; e.beside = true; e.indent = 4; e.code_scale = 1.2
  e.code_font = "Menlo"; e.code_weight = 500; e.guide = 100; e.bundle = "VS Code"
  e.rebound = Dict(:save => "ctrl+s", :bold => "cmd+shift+b, ctrl+b")
  e.side = 300px; e.hidden = true; e.right = false; e.own = true; e.pinned = true; e.hide_bar = :full_screen
  e
end

"What's different in `now` from `was`, two lists that `state` made"
changes(now, was) = Pair{Symbol,Any}[k => v for ((k, v), (_, old)) in zip(now, was) if !isequal(v, old)]

"What loading `text` as the settings file changes, in the editor that `start` makes"
loaded(start, text) = begin
  e = start()
  was = state(e)
  write(K.settings_file(), text)
  K.load_settings!(e)
  changes(state(e), was)
end

"The text of the settings file that the editor `e` writes"
written(e) = begin
  rm(K.settings_file(), force=true)
  e.remember = true
  K.save_settings!(e)
  read(K.settings_file(), String)
end

"The editor of a page, with the settings that `start` gives. It keeps its settings to itself."
windowed(start) = begin
  from = start()
  e = K.build_editor(joinpath(folder, "a.md"))
  foreach(f -> setfield!(e, f, getfield(from, f)), FIELDS)
  e.remember = false
  e
end

"What the name `n` gives the code of a page of `e`, and the settings that it noted the running live block read"
got(e, n) = begin
  e.nodes[:running] = :probe
  v = Base.invokelatest(Base.invokelatest(getglobal, K.sandbox(e), n))
  delete!(e.nodes, :running)
  read = sort!(Symbol[k[2] for (k, s) in e.nodes if k isa Tuple && length(k) == 2 && k[1] === :readers && :probe in s])
  foreach(s -> delete!(e.nodes, (:readers, s)), read)
  v => read
end

# --- what the code did before the table --------------------------------------------------

const USUAL_STATE = [:theme => :sepia, :font => "Charter", :weight => 400, :zoom => 1.0, :widest => 780.0, :plain => false,
  :spelling => true, :updates => true, :autosave => false, :peeks => true, :ai => "Claude", :glide => true,
  :wrap => true, :numbers => true, :shade => false, :beside => false, :indent => 2, :code_scale => 0.86,
  :code_font => ".SF NS Mono", :code_weight => 300, :guide => 0, :bundle => "Ladder", :rebound => [],
  :side => 230.0, :hidden => false, :right => true, :own => false, :pinned => false, :hide_bar => :never,
  :listed => [], :agentshidden => [], :models => [], :pagecard => nothing, Symbol("term.caret") => :block,
  Symbol("term.blink") => false, Symbol("term.copies") => false, Symbol("term.meta") => false,
  Symbol("term.bell") => :flash, Symbol("term.most") => 10000, Symbol("term.again") => true]

const OTHER_STATE = [:theme => :night, :font => "Helvetica", :weight => 300, :zoom => 1.5, :widest => 800.0, :plain => true,
  :spelling => false, :updates => false, :autosave => true, :peeks => false, :ai => "Codex", :glide => false,
  :wrap => false, :numbers => false, :shade => true, :beside => true, :indent => 4, :code_scale => 1.2,
  :code_font => "Menlo", :code_weight => 500, :guide => 100, :bundle => "VS Code",
  :rebound => ["bold" => "cmd+shift+b, ctrl+b", "save" => "ctrl+s"], :side => 300.0, :hidden => true,
  :right => false, :own => true, :pinned => true, :hide_bar => :full_screen, :listed => [],
  :agentshidden => ["Grok"], :models => ["Claude" => "opus", "Codex" => "gpt-5", "Grok" => ""], :pagecard => 600.0,
  Symbol("term.caret") => :underline, Symbol("term.blink") => true, Symbol("term.copies") => true,
  Symbol("term.meta") => true, Symbol("term.bell") => :none, Symbol("term.most") => 50000,
  Symbol("term.again") => false]

# The settings file of an editor with every setting as it first is
const USUAL_TEXT =
  "theme=sepia\nfont=Charter\nweight=400\nzoom=1.0\nwidth=780.0\nplain=false\nspelling=true\nupdates=true\n" *
  "autosave=false\npeeks=true\nagent=Claude\nglide=true\nwrap=true\nnumbers=true\nshade=false\nbeside=false\n" *
  "indent=2\ncode=0.86\ncodefont=.SF NS Mono\ncodeweight=300\nguide=0\nsidebar=230.0\nhidden=false\nright=true\n" *
  "ownmessage=false\npinned=false\nhidebar=never\npagecard=\nagentshidden=\nmodels=\nterm.caret=block\n" *
  "term.blink=false\nterm.copies=false\nterm.meta=false\nterm.bell=flash\nterm.most=10000\nterm.again=true\n" *
  "keys=Ladder\n"

# ... and of one with every setting changed
const OTHER_TEXT =
  "theme=night\nfont=Helvetica\nweight=300\nzoom=1.5\nwidth=800.0\nplain=true\nspelling=false\nupdates=false\n" *
  "autosave=true\npeeks=false\nagent=Codex\nglide=false\nwrap=false\nnumbers=false\nshade=true\nbeside=true\n" *
  "indent=4\ncode=1.2\ncodefont=Menlo\ncodeweight=500\nguide=100\nsidebar=300.0\nhidden=true\nright=false\n" *
  "ownmessage=true\npinned=true\nhidebar=full_screen\npagecard=600.0\nagentshidden=Grok\n" *
  "models=Claude:opus,Codex:gpt-5\nterm.caret=underline\nterm.blink=true\nterm.copies=true\nterm.meta=true\n" *
  "term.bell=none\nterm.most=50000\nterm.again=false\nkeys=VS Code\nkey.bold=cmd+shift+b, ctrl+b\nkey.save=ctrl+s\n"

# What reading OTHER_TEXT changes in an editor with every setting as it first is. The model of Grok was "", which the file leaves out.
const OTHER_INTO_USUAL = [:theme => :night, :font => "Helvetica", :weight => 300, :zoom => 1.5, :widest => 800.0, :plain => true,
  :spelling => false, :updates => false, :autosave => true, :peeks => false, :ai => "Codex", :glide => false,
  :wrap => false, :numbers => false, :shade => true, :beside => true, :indent => 4, :code_scale => 1.2,
  :code_font => "Menlo", :code_weight => 500, :guide => 100, :bundle => "VS Code",
  :rebound => ["bold" => "cmd+shift+b, ctrl+b", "save" => "ctrl+s"], :side => 300.0, :hidden => true,
  :right => false, :own => true, :pinned => true, :hide_bar => :full_screen, :listed => [".dot.md", "a.md"],
  :agentshidden => ["Grok"], :models => ["Claude" => "opus", "Codex" => "gpt-5"], :pagecard => 600.0,
  Symbol("term.caret") => :underline, Symbol("term.blink") => true, Symbol("term.copies") => true,
  Symbol("term.meta") => true, Symbol("term.bell") => :none, Symbol("term.most") => 50000,
  Symbol("term.again") => false]

# What reading USUAL_TEXT changes in an editor with every setting changed. It has no line for a command's keys, so those stay.
const USUAL_INTO_OTHER = [:theme => :sepia, :font => "Charter", :weight => 400, :zoom => 1.0, :widest => 780.0, :plain => false,
  :spelling => true, :updates => true, :autosave => false, :peeks => true, :ai => "Claude", :glide => true,
  :wrap => true, :numbers => true, :shade => false, :beside => false, :indent => 2, :code_scale => 0.86,
  :code_font => ".SF NS Mono", :code_weight => 300, :guide => 0, :bundle => "Ladder", :side => 230.0,
  :hidden => false, :right => true, :own => false, :pinned => false, :hide_bar => :never, :listed => ["a.md"],
  :agentshidden => [], :models => [], :pagecard => nothing, Symbol("term.caret") => :block,
  Symbol("term.blink") => false, Symbol("term.copies") => false, Symbol("term.meta") => false,
  Symbol("term.bell") => :flash, Symbol("term.most") => 10000, Symbol("term.again") => true]

# A file with lines twice, lines that mean nothing, and its lines in another order
const MIXED = """
theme=paper
theme=bogus
zoom=1.1
zoom=2.0
nonsense
keys=Emacs
key.save=ctrl+s
key.bold=ctrl+b
key.save=ctrl+x ctrl+s
hidden=true
hidden=false
hidden=true
agent=Gemini
models=Claude:sonnet
models=Codex:gpt-5
term.caret=bar
hidebar=true
width=640
weight=200
codeweight=9000
font=Georgia
sidebar=333.3
pagecard=321.7
agentshidden=Gemini
"""
const MIXED_INTO_USUAL = [:theme => :paper, :font => "Georgia", :weight => 200, :zoom => 2.0, :widest => 640.0, :ai => "Antigravity",
  :bundle => "Emacs", :rebound => ["bold" => "ctrl+b", "save" => "ctrl+x ctrl+s"], :side => 333.0, :hidden => true,
  :hide_bar => :always, :listed => [".dot.md", "a.md"], :agentshidden => ["Antigravity"],
  :models => ["Codex" => "gpt-5"], :pagecard => 322.0, Symbol("term.caret") => :bar]
const MIXED_INTO_OTHER = [:theme => :paper, :font => "Georgia", :weight => 200, :zoom => 2.0, :widest => 640.0, :ai => "Antigravity",
  :bundle => "Emacs", :rebound => ["bold" => "ctrl+b", "save" => "ctrl+x ctrl+s"], :side => 333.0,
  :hide_bar => :always, :listed => [".dot.md", "a.md"], :agentshidden => ["Antigravity"],
  :models => ["Codex" => "gpt-5"], :pagecard => 322.0, Symbol("term.caret") => :bar]

# One line of the settings file, and what reading it changes: first in an editor with every setting as it
# first is, then in one with every setting changed. [] means that the line changes nothing there.
const LINES = [
  "theme=night" => ([:theme => :night], []),
  "theme=paper" => ([:theme => :paper], [:theme => :paper]),
  "theme=sepia" => ([], [:theme => :sepia]),
  "theme=Night" => ([], []),
  "theme=" => ([], []),
  "theme" => ([], []),
  "font=Helvetica" => ([:font => "Helvetica"], []),
  "font=Avenir Next" => ([:font => "Avenir Next"], [:font => "Avenir Next"]),
  "font=A=B" => ([:font => "A=B"], [:font => "A=B"]),
  "font=" => ([], []),
  "font" => ([], []),
  "weight=300" => ([:weight => 300], []),
  "weight=650" => ([:weight => 650], [:weight => 650]),
  "weight=651" => ([], []),
  "weight=0" => ([], []),
  "weight=-100" => ([], []),
  "weight=3.5" => ([], []),
  "weight=bold" => ([], []),
  "weight=" => ([], []),
  "zoom=1.25" => ([:zoom => 1.25], [:zoom => 1.25]),
  "zoom=0.1" => ([:zoom => 0.6], [:zoom => 0.6]),
  "zoom=9" => ([:zoom => 2.5], [:zoom => 2.5]),
  "zoom=big" => ([], []),
  "zoom=" => ([], []),
  "zoom=NaN" => ([:zoom => NaN], [:zoom => NaN]),
  "zoom=Inf" => ([:zoom => 2.5], [:zoom => 2.5]),
  "width=700" => ([:widest => 700.0], [:widest => 700.0]),
  "width=100" => ([:widest => 400.0], [:widest => 400.0]),
  "width=5000" => ([:widest => 1200.0], [:widest => 1200.0]),
  "width=wide" => ([], []),
  "width=" => ([], []),
  "plain=true" => ([:plain => true], []),
  "plain=false" => ([], [:plain => false]),
  "plain=yes" => ([], [:plain => false]),
  "plain=" => ([], [:plain => false]),
  "plain" => ([], [:plain => false]),
  "spelling=true" => ([], [:spelling => true]),
  "spelling=false" => ([:spelling => false], []),
  "spelling=no" => ([], [:spelling => true]),
  "spelling=" => ([], [:spelling => true]),
  "spelling" => ([], [:spelling => true]),
  "updates=true" => ([], [:updates => true]),
  "updates=false" => ([:updates => false], []),
  "updates=0" => ([], [:updates => true]),
  "autosave=true" => ([:autosave => true], []),
  "autosave=false" => ([], [:autosave => false]),
  "autosave=1" => ([], [:autosave => false]),
  "glide=true" => ([], [:glide => true]),
  "glide=false" => ([:glide => false], []),
  "glide=off" => ([], [:glide => true]),
  "peeks=true" => ([], [:peeks => true]),
  "peeks=false" => ([:peeks => false], []),
  "peeks=" => ([], [:peeks => true]),
  "agent=Claude" => ([], [:ai => "Claude"]),
  "agent=Codex" => ([:ai => "Codex"], []),
  "agent=Grok" => ([:ai => "Grok"], [:ai => "Grok"]),
  "agent=Antigravity" => ([:ai => "Antigravity"], [:ai => "Antigravity"]),
  "agent=Gemini" => ([:ai => "Antigravity"], [:ai => "Antigravity"]),
  "agent=Nobody" => ([], []),
  "agent=" => ([], []),
  "agent=claude" => ([], []),
  "wrap=true" => ([], [:wrap => true]),
  "wrap=false" => ([:wrap => false], []),
  "wrap=x" => ([], [:wrap => true]),
  "numbers=true" => ([], [:numbers => true]),
  "numbers=false" => ([:numbers => false], []),
  "numbers=x" => ([], [:numbers => true]),
  "shade=true" => ([:shade => true], []),
  "shade=false" => ([], [:shade => false]),
  "shade=x" => ([], [:shade => false]),
  "beside=true" => ([:beside => true], []),
  "beside=false" => ([], [:beside => false]),
  "beside=x" => ([], [:beside => false]),
  "indent=2" => ([], [:indent => 2]),
  "indent=4" => ([:indent => 4], []),
  "indent=3" => ([], []),
  "indent=four" => ([], []),
  "indent=" => ([], []),
  "code=1.0" => ([:code_scale => 1.0], [:code_scale => 1.0]),
  "code=0.1" => ([:code_scale => 0.4], [:code_scale => 0.4]),
  "code=9" => ([:code_scale => 2.5], [:code_scale => 2.5]),
  "code=small" => ([], []),
  "code=" => ([], []),
  "codefont=Menlo" => ([:code_font => "Menlo"], []),
  "codefont=Courier" => ([:code_font => "Courier"], [:code_font => "Courier"]),
  "codefont=No Such Font 123" => ([], []),
  "codefont=" => ([], []),
  "codeweight=400" => ([:code_weight => 400], [:code_weight => 400]),
  "codeweight=650" => ([:code_weight => 650], [:code_weight => 650]),
  "codeweight=700" => ([], []),
  "codeweight=0" => ([], []),
  "codeweight=x" => ([], []),
  "guide=0" => ([], [:guide => 0]),
  "guide=80" => ([:guide => 80], [:guide => 80]),
  "guide=92" => ([:guide => 92], [:guide => 92]),
  "guide=100" => ([:guide => 100], []),
  "guide=120" => ([:guide => 120], [:guide => 120]),
  "guide=81" => ([], []),
  "guide=x" => ([], []),
  "guide=" => ([], []),
  "sidebar=260" => ([:side => 260.0], [:side => 260.0]),
  "sidebar=300.4" => ([:side => 300.0], []),
  "sidebar=10" => ([:side => 220.0], [:side => 220.0]),
  "sidebar=1000" => ([:side => 480.0], [:side => 480.0]),
  "sidebar=wide" => ([], []),
  "sidebar=" => ([], []),
  "hidden=true" => ([:hidden => true, :listed => [".dot.md", "a.md"]], []),
  "hidden=false" => ([], [:hidden => false, :listed => ["a.md"]]),
  "hidden=x" => ([], [:hidden => false, :listed => ["a.md"]]),
  "hidden=" => ([], [:hidden => false, :listed => ["a.md"]]),
  "right=true" => ([], [:right => true]),
  "right=false" => ([:right => false], []),
  "right=x" => ([], [:right => true]),
  "ownmessage=true" => ([:own => true], []),
  "ownmessage=false" => ([], [:own => false]),
  "ownmessage=x" => ([], [:own => false]),
  "pinned=true" => ([:pinned => true], []),
  "pinned=false" => ([], [:pinned => false]),
  "pinned=x" => ([], [:pinned => false]),
  "hidebar=always" => ([:hide_bar => :always], [:hide_bar => :always]),
  "hidebar=full_screen" => ([:hide_bar => :full_screen], []),
  "hidebar=never" => ([], [:hide_bar => :never]),
  "hidebar=true" => ([:hide_bar => :always], [:hide_bar => :always]),
  "hidebar=false" => ([], [:hide_bar => :never]),
  "hidebar=sometimes" => ([], []),
  "hidebar=" => ([], []),
  "agentshidden=Codex" => ([:agentshidden => ["Codex"]], [:agentshidden => ["Codex"]]),
  "agentshidden=Gemini,Codex,Nobody" => ([:agentshidden => ["Antigravity", "Codex"]], [:agentshidden => ["Antigravity", "Codex"]]),
  "agentshidden=" => ([], [:agentshidden => []]),
  "agentshidden=Claude,Antigravity,Codex,Grok" => ([:agentshidden => ["Antigravity", "Claude", "Codex", "Grok"]], [:agentshidden => ["Antigravity", "Claude", "Codex", "Grok"]]),
  "models=Claude:sonnet" => ([:models => ["Claude" => "sonnet"]], [:models => ["Claude" => "sonnet"]]),
  "models=Claude:sonnet,Codex:gpt-5" => ([:models => ["Claude" => "sonnet", "Codex" => "gpt-5"]], [:models => ["Claude" => "sonnet", "Codex" => "gpt-5"]]),
  "models=Gemini:pro,Grok:" => ([], [:models => []]),
  "models=nocolon" => ([], [:models => []]),
  "models=" => ([], [:models => []]),
  "models=Claude:a:b" => ([:models => ["Claude" => "a:b"]], [:models => ["Claude" => "a:b"]]),
  "pagecard=500" => ([:pagecard => 500.0], [:pagecard => 500.0]),
  "pagecard=500.6" => ([:pagecard => 501.0], [:pagecard => 501.0]),
  "pagecard=100" => ([:pagecard => 240.0], [:pagecard => 240.0]),
  "pagecard=" => ([], [:pagecard => nothing]),
  "pagecard=wide" => ([], [:pagecard => nothing]),
  "term.caret=bar" => ([Symbol("term.caret") => :bar], [Symbol("term.caret") => :bar]),
  "term.caret=block" => ([], [Symbol("term.caret") => :block]),
  "term.caret=underline" => ([Symbol("term.caret") => :underline], []),
  "term.caret=dot" => ([], []),
  "term.blink=true" => ([Symbol("term.blink") => true], []),
  "term.blink=false" => ([], [Symbol("term.blink") => false]),
  "term.blink=x" => ([], [Symbol("term.blink") => false]),
  "term.copies=true" => ([Symbol("term.copies") => true], []),
  "term.copies=false" => ([], [Symbol("term.copies") => false]),
  "term.meta=true" => ([Symbol("term.meta") => true], []),
  "term.meta=false" => ([], [Symbol("term.meta") => false]),
  "term.bell=sound" => ([Symbol("term.bell") => :sound], [Symbol("term.bell") => :sound]),
  "term.bell=flash" => ([], [Symbol("term.bell") => :flash]),
  "term.bell=none" => ([Symbol("term.bell") => :none], []),
  "term.bell=loud" => ([], []),
  "term.most=1000" => ([Symbol("term.most") => 1000], [Symbol("term.most") => 1000]),
  "term.most=10000" => ([], [Symbol("term.most") => 10000]),
  "term.most=50000" => ([Symbol("term.most") => 50000], []),
  "term.most=5" => ([], []),
  "term.most=x" => ([], []),
  "term.again=true" => ([], [Symbol("term.again") => true]),
  "term.again=false" => ([Symbol("term.again") => false], []),
  "term.nothing=1" => ([], []),
  "term.=1" => ([], []),
  "term=1" => ([], []),
  "keys=Ladder" => ([], [:bundle => "Ladder"]),
  "keys=VS Code" => ([:bundle => "VS Code"], []),
  "keys=Sublime Text" => ([:bundle => "Sublime Text"], [:bundle => "Sublime Text"]),
  "keys=Emacs" => ([:bundle => "Emacs"], [:bundle => "Emacs"]),
  "keys=Vim" => ([], []),
  "keys=" => ([], []),
  "key.save=ctrl+s" => ([:rebound => ["save" => "ctrl+s"]], []),
  "key.save=cmd+s, ctrl+s" => ([:rebound => ["save" => "cmd+s, ctrl+s"]], [:rebound => ["bold" => "cmd+shift+b, ctrl+b", "save" => "cmd+s, ctrl+s"]]),
  "key.bold=" => ([:rebound => ["bold" => ""]], [:rebound => ["bold" => "", "save" => "ctrl+s"]]),
  "key.nosuchcommand=cmd+k" => ([], []),
  "key.=cmd+k" => ([], []),
  "key=cmd+k" => ([], []),
  "" => ([], []),
  "=" => ([], []),
  "=true" => ([], []),
  "nonsense" => ([], []),
  "nonsense=1" => ([], []),
  "glide = false" => ([], []),
  " glide=false" => ([], []),
  "Glide=false" => ([], []),
  "glide=false " => ([], [:glide => true]),
  "glide=FALSE" => ([], [:glide => true]),
]

# The names that `sandbox` itself gives the code of a page, apart from those of UI.jl, the units and the startup page
const NAMES = [:agent_listed, :agent_listed!, :agent_names, :app_installed, :app_updates, :app_updates!, :bar_hidings,
  :code_family, :code_font, :code_font!, :code_fonts, :code_guide, :code_guide!, :code_indent, :code_indent!,
  :code_numbers, :code_numbers!, :code_shade, :code_shade!, :code_text_size, :code_text_size!, :code_weight,
  :code_weight!, :code_weights, :code_wrap, :code_wrap!, :default_app!, :every_agent, :extension_news,
  :extension_offer, :key_bundle, :key_bundle!, :key_bundles, :key_list, :key_reset!, :keys_changed, :markdown_app,
  :news_agents, :news_agents!, :news_companion, :news_companion!, :news_days, :news_days!, :page_agent, :page_agent!,
  :page_autosave, :page_autosave!, :page_bar_hides, :page_bar_hides!, :page_font, :page_font!, :page_glide,
  :page_glide!, :page_peeks, :page_peeks!, :page_spelling, :page_spelling!, :page_text_size, :page_text_size!,
  :page_theme, :page_theme!, :page_weight, :page_weight!, :page_weights, :page_width, :page_width!, :term_again,
  :term_again!, :term_bell, :term_bell!, :term_blink, :term_blink!, :term_caret, :term_caret!, :term_copies,
  :term_copies!, :term_lines, :term_lines!, :term_meta, :term_meta!, :update!, :update_extensions!, :update_news,
  :update_offer]
# The ones of them that hold no window. Each other one holds its window, so that a page's module calls it on the main thread: see `acts_on_window`.
const HOLD_NO_WINDOW = [:bar_hidings, :code_family, :every_agent, :key_bundles, :news_agents!, :news_companion!, :news_days!]

# What a name gives the code of a page, and the settings that it notes the running live block read: in a window
# with every setting as it first is ...
const GIVEN_USUAL = [
  :page_theme => "Sepia" => [:theme],
  :page_text_size => 17.0 => [:zoom],
  :page_font => "Charter" => [:font],
  :page_weight => "Roman" => [:font, :weight],
  :page_width => 780.0 => [],
  :page_spelling => true => [:spelling],
  :page_autosave => false => [:autosave],
  :page_glide => true => [:glide],
  :page_bar_hides => "Never" => [:hide_bar],
  :page_peeks => true => [:peeks],
  :page_agent => "Claude" => [:ai],
  :code_wrap => true => [:wrap],
  :code_numbers => true => [:numbers],
  :code_shade => false => [:shade],
  :code_indent => 2 => [:indent],
  :code_text_size => 14.62 => [:code_scale, :zoom],
  :code_font => "SF Mono" => [:code_font],
  :code_weight => "Light" => [:code_font, :code_weight],
  :code_guide => 0 => [:guide],
  :key_bundle => "Ladder" => [:bundle],
  :app_updates => true => [:updates],
  :bar_hidings => ["Always", "In full screen only", "Never"] => [],
  :key_bundles => ["Ladder", "VS Code", "Sublime Text", "Emacs"] => [],
  :every_agent => ["Claude", "Antigravity", "Codex", "Grok"] => [],
  :agent_names => ["Claude", "Antigravity", "Codex", "Grok"] => [:agents, :ai],
]
# ... and in one with every setting changed
const GIVEN_OTHER = [
  :page_theme => "Night" => [:theme],
  :page_text_size => 25.5 => [:zoom],
  :page_font => "Helvetica" => [:font],
  :page_weight => "Light" => [:font, :weight],
  :page_width => 800.0 => [],
  :page_spelling => false => [:spelling],
  :page_autosave => true => [:autosave],
  :page_glide => false => [:glide],
  :page_bar_hides => "In full screen only" => [:hide_bar],
  :page_peeks => false => [:peeks],
  :page_agent => "Codex" => [:ai],
  :code_wrap => false => [:wrap],
  :code_numbers => false => [:numbers],
  :code_shade => true => [:shade],
  :code_indent => 4 => [:indent],
  :code_text_size => 30.599999999999998 => [:code_scale, :zoom],
  :code_font => "Menlo" => [:code_font],
  :code_weight => "Regular" => [:code_font, :code_weight],
  :code_guide => 100 => [:guide],
  :key_bundle => "VS Code" => [:bundle],
  :app_updates => false => [:updates],
  :bar_hidings => ["Always", "In full screen only", "Never"] => [],
  :key_bundles => ["Ladder", "VS Code", "Sublime Text", "Emacs"] => [],
  :every_agent => ["Claude", "Antigravity", "Codex", "Grok"] => [],
  :agent_names => ["Claude", "Antigravity", "Codex"] => [:agents, :ai],
]

# What a name with a ! changes when a page's code calls it with a value, in a window with every setting as it
# first is and the font Helvetica, which has more than one weight
const SETS = [
  (:page_theme!, "Night") => [:theme => :night],
  (:page_theme!, :paper) => [:theme => :paper],
  (:page_text_size!, 20) => [:zoom => 1.1764705882352942],
  (:page_font!, "Georgia") => [:font => "Georgia"],
  (:page_weight!, "Light") => [:weight => 300],
  (:page_width!, 713) => [:widest => 710.0],
  (:page_spelling!, false) => [:spelling => false],
  (:page_spelling!, 1) => [],
  (:page_autosave!, true) => [:autosave => true],
  (:page_glide!, false) => [:glide => false],
  (:page_glide!, 1.0) => [],
  (:page_bar_hides!, "Always") => [:hide_bar => :always],
  (:page_bar_hides!, "In full screen only") => [:hide_bar => :full_screen],
  (:page_bar_hides!, "Sometimes") => [],
  (:page_peeks!, false) => [:peeks => false],
  (:page_agent!, "Codex") => [:ai => "Codex"],
  (:code_wrap!, false) => [:wrap => false],
  (:code_numbers!, false) => [:numbers => false],
  (:code_shade!, true) => [:shade => true],
  (:code_indent!, 4) => [:indent => 4],
  (:code_indent!, 2.0) => [],
  (:code_text_size!, 12) => [:code_scale => 0.7058823529411765],
  (:code_font!, "Menlo") => [:code_font => "Menlo"],
  (:code_font!, "SF Mono") => [],
  (:code_weight!, "Regular") => [:code_weight => 400],
  (:code_guide!, 80) => [:guide => 80],
  (:code_guide!, 100.0) => [:guide => 100],
  (:key_bundle!, "VS Code") => [:bundle => "VS Code"],
  (:app_updates!, false) => [:updates => false],
  (:app_updates!, true) => [],
]

# --- the tests ---------------------------------------------------------------------------

const TERM_WAS = [getfield(K.TERM_SETTINGS, f) for f in TERM_FIELDS]
const AUTO_WAS = (K.Update.own().auto, K.Update.extensions().auto)

try
  @testset "The two editors of these tests are as they were" begin
    @test isequal(state(usual()), USUAL_STATE)
    @test isequal(state(other()), OTHER_STATE)
  end

  @testset "The rows are the settings that every window has the same, in the same order" begin
    @test K.SHARED === FIELDS
    @test Tuple(s.field for s in K.SETTINGS) === FIELDS
    @test all(s -> s.field in fieldnames(K.Editor), K.SETTINGS)
    named = [s.name for s in K.SETTINGS if !isempty(s.name)]
    @test allunique(named) && length(named) == 27
    paged = [s.page for s in K.SETTINGS if s.page !== :none]
    @test allunique(paged) && length(paged) == 21
    @test all(s -> s.set !== nothing, filter(s -> s.page !== :none, K.SETTINGS))
    # The two that have no line of their own are the key bindings, which take a line for each command
    @test [s.field for s in K.SETTINGS if isempty(s.name)] == [:bundle, :rebound]
    @test K.setting_named("") === nothing && K.setting_named("glide").field == :glide
    # A new window takes each of them from the window that opens it, and nothing else
    e = other()
    e.panel = true; e.remember = true
    new = K.same_settings!(K.Editor(), e)
    @test all(f -> isequal(getfield(new, f), getfield(e, f)), FIELDS)
    @test !new.panel && !new.remember
  end

  @testset "The ways that the top bar hides are the ones that main.jl names" begin
    @test [K.hiding_named(K.hiding_name(how)) for how in K.HIDINGS] == collect(K.HIDINGS)
    @test [K.hiding_name(how) for how in K.HIDINGS] == ["Always", "In full screen only", "Never"]
    @test K.hiding_named("Sometimes") == :never   # a name that's none of them
  end

  @testset "A part of another page takes the same things from the page that shows it" begin
    @test Set(K.FOLLOWED) == setdiff(Set(FOLLOWS), (:look, :size)) && allunique(K.FOLLOWED)
    e = other()
    e.look = :site
    e.size = (640px, 480px)
    sub = K.Editor()
    differ = [f for f in fieldnames(K.Editor) if !isequal(getfield(sub, f), getfield(e, f))]
    @test issubset(FOLLOWS, differ)
    K.follow_host!(sub, e)
    @test Set(f for f in differ if isequal(getfield(sub, f), getfield(e, f))) == Set(FOLLOWS)
  end

  @testset "The settings file is written as before, byte for byte" begin
    @test written(usual()) == USUAL_TEXT
    @test written(other()) == OTHER_TEXT
    @test K.settings_text(usual()) == USUAL_TEXT
    # An editor that doesn't keep its settings writes no file
    rm(K.settings_file(), force=true)
    e = other()
    e.remember = false
    K.save_settings!(e)
    @test !isfile(K.settings_file())
  end

  @testset "A whole settings file is read as before" begin
    @test isequal(loaded(usual, OTHER_TEXT), OTHER_INTO_USUAL)
    @test isequal(loaded(other, USUAL_TEXT), USUAL_INTO_OTHER)
    @test isequal(loaded(usual, MIXED), MIXED_INTO_USUAL)
    @test isequal(loaded(other, MIXED), MIXED_INTO_OTHER)
    # No file leaves every setting as it is
    rm(K.settings_file(), force=true)
    e = other()
    @test K.load_settings!(e) === e && isequal(state(e), OTHER_STATE)
  end

  @testset "Each line of the settings file is read as before" begin
    wrong = [(line, :usual, now) for (line, (want, _)) in LINES for now in (loaded(usual, line),) if !isequal(now, want)]
    @test isempty(wrong)
    wrong = [(line, :other, now) for (line, (_, want)) in LINES for now in (loaded(other, line),) if !isequal(now, want)]
    @test isempty(wrong)
    # Every row that has a line in the file has a line here that changes it
    @test all(s -> isempty(s.name) || any(l -> startswith(first(l), s.name * "="), LINES), K.SETTINGS)
  end

  @testset "The code of a page has the same names" begin
    e = windowed(usual)
    m = K.sandbox(e)
    has(n) = Base.invokelatest(isdefined, m, n)
    @test filter(!has, NAMES) == []
    # Each name of a row is in the list
    @test issubset([s.page for s in K.SETTINGS if s.page !== :none], NAMES)
    @test issubset([Symbol(s.page, :!) for s in K.SETTINGS if s.page !== :none], NAMES)
    holds(n) = K.acts_on_window(Base.invokelatest(getglobal, m, n))
    @test filter(!holds, NAMES) == HOLD_NO_WINDOW
  end

  @testset "A name gives the code of a page what it gave, and notes what it read" begin
    e = windowed(usual)
    wrong = [(n, now) for (n, want) in GIVEN_USUAL for now in (got(e, n),) if !isequal(now, want)]
    @test isempty(wrong)
    e = windowed(other)
    wrong = [(n, now) for (n, want) in GIVEN_OTHER for now in (got(e, n),) if !isequal(now, want)]
    @test isempty(wrong)
  end

  @testset "A name with a ! changes what it changed" begin
    wrong = []
    for ((n, x), want) in SETS
      e = windowed(usual)
      e.font = "Helvetica"
      was = state(e)
      gave = Base.invokelatest(Base.invokelatest(getglobal, K.sandbox(e), n), x)
      now = changes(state(e), was)
      (gave === e && isequal(now, want)) || push!(wrong, (n, x, now))
    end
    @test isempty(wrong)
  end
finally
  foreach((f, v) -> setfield!(K.TERM_SETTINGS, f, v), TERM_FIELDS, TERM_WAS)
  K.Update.own().auto, K.Update.extensions().auto = AUTO_WAS
end
