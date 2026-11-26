# Tests for agent mode, in main.jl: the command Agent Mode puts an agent's
# session at the left of the page and the page's outline at its right, in a
# wider window, with the page between them on a card. Run them with
# `julia -O0 --project=. test/agent_mode_test.jl`. No real agent runs: the
# agent here is a small script that reads and prints the lines of JSON that
# Claude Code does. They draw a window that isn't on the screen.

@use Test: @test, @testset
@use "../main" => K
@use "github.com/jkroso/MiniFB.jl" Window KeyPress KeyRelease MouseMove Keys onkey onmouse Typed ontype
@use "github.com/jkroso/UI.jl/Interface/draw" frame
const px = K.px

const dir = realpath(mktempdir())
@eval K settings_file() = $(joinpath(dir, "settings"))
const page = joinpath(dir, "plan.md")
write(page, """
# The plan

Words before the first section.

## Paint

Buy paint.

### Colours

Red and blue.

## Brushes

$(join(("Line $i of the brushes." for i in 1:60), "\n\n"))

## Done

The end.
""")

# The agent writes down each line that Ladder gives it, and answers by what your words hold
const heard = joinpath(dir, "heard.txt")
const agent = joinpath(dir, "test-agent")
write(agent, replace(raw"""
#!/bin/sh
say() { printf '%s\n' "$1"; }
done_() { say '{"type":"result","subtype":"success","is_error":false,"result":""}'; }
say '{"type":"system","subtype":"init","session_id":"test-session"}'
while IFS= read -r line; do
  printf '%s\n' "$line" >> "HEARD"
  case "$line" in
  *'"interrupt"'*)
    say '{"type":"result","subtype":"error_during_execution","is_error":true}' ;;
  *'"control_response"'*)
    case "$line" in
    *'"allow"'*)
      say '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t2","is_error":false}]}}'
      say '{"type":"assistant","message":{"content":[{"type":"text","text":"It ran."}]}}' ;;
    *)
      say '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t2","is_error":true}]}}'
      say '{"type":"assistant","message":{"content":[{"type":"text","text":"I left it."}]}}' ;;
    esac
    done_ ;;
  *'a table'*)
    say '{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"text","text":""}}}'
    say '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"## Paint\n\n| Colour | Litres |\n"}}}'
    say '{"type":"stream_event","event":{"type":"content_block_delta","index":0,"delta":{"type":"text_delta","text":"|---|---|\n| Red | 2 |\n"}}}'
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"## Paint\n\n| Colour | Litres |\n|---|---|\n| Red | 2 |\n\n```ui\nerror(1)\n```\n\nSee `!1+1` too."}]}}'
    done_ ;;
  *'run it'*)
    say '{"type":"stream_event","event":{"type":"content_block_start","index":0,"content_block":{"type":"tool_use","id":"t2","name":"Bash","input":{}}}}'
    say '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t2","name":"Bash","input":{"command":"make paint","description":"Make the paint"}}]}}'
    say '{"type":"control_request","request_id":"r1","request":{"subtype":"can_use_tool","tool_name":"Bash","input":{"command":"make paint","description":"Make the paint"},"tool_use_id":"t2"}}' ;;
  *'go slow'*)
    say '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t3","name":"Read","input":{"file_path":"/tmp/notes.md"}}]}}' ;;
  *'many steps'*)
    for n in 4 5 6 7 8; do
      say '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"t'$n'","name":"Grep","input":{"pattern":"paint'$n'"}}]}}'
      say '{"type":"user","message":{"content":[{"type":"tool_result","tool_use_id":"t'$n'","is_error":false}]}}'
    done
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"Five looks."}]}}'
    done_ ;;
  *)
    say '{"type":"assistant","message":{"content":[{"type":"text","text":"Plain **words**."}]}}'
    done_ ;;
  esac
done
""", "HEARD" => heard))
chmod(agent, 0o755)
K.SESSION_COMMAND[] = Cmd([agent])

# An agent that works by turns: it's started for each thing that you say, with the agent's name, the session's name and your words.
# It prints the lines that Grok, Gemini and Codex print, as their real programs printed them on 26 November 2026 (Codex: as its source says).
const turns = joinpath(dir, "turns.txt")
const turner = joinpath(dir, "turn-agent")
write(turner, replace(raw"""
#!/bin/sh
agent="$1"; id="$2"; words="$3"
printf '%s|%s|%s\n' "$agent" "$id" "$(printf '%s' "$words" | tr '\n' ' ')" >> "TURNS"
say() { printf '%s\n' "$1"; }
case "$words" in
*'fail please'*) echo "warning: something small" >&2; echo "Error: no key for $agent" >&2; echo "at line 3" >&2; exit 1 ;;
*'go slow'*) exec sleep 30 ;;
esac
case "$agent" in
Grok)
  say '{"type":"available_commands","tools":["read_file"]}'
  say '{"type":"thought","data":"I will read it"}'
  say '{"type":"text","data":"I will read"}'
  say '{"type":"text","data":" it."}'
  say '{"type":"tool_call","toolCallId":"c1","title":"read_file","kind":"read","status":"pending","toolName":"read_file","rawInput":{"target_file":"/tmp/plan.md"},"content":[],"locations":[]}'
  say '{"type":"tool_call_update","toolCallId":"c1","status":null,"content":[],"rawOutput":null,"locations":[]}'
  say '{"type":"tool_call_update","toolCallId":"c1","status":"completed","content":[],"rawOutput":null,"locations":[]}'
  say '{"type":"text","data":"It has paint."}'
  say '{"type":"usage","usage":{"input_tokens":1}}'
  say '{"type":"end","stopReason":"end_turn","sessionId":"sess-Grok"}' ;;
Gemini)
  say 'MCP issues detected. Run /mcp list for status.{"type":"init","session_id":"sess-Gemini","model":"auto"}'
  say '{"type":"message","role":"user","content":"Read the plan"}'
  say '{"type":"message","role":"assistant","content":"I will read","delta":true}'
  say '{"type":"message","role":"assistant","content":" it.","delta":true}'
  say '{"type":"tool_use","tool_name":"read_file","tool_id":"c1","parameters":{"file_path":"plan.md"}}'
  say '{"type":"tool_result","tool_id":"c1","status":"success","output":""}'
  say '{"type":"message","role":"assistant","content":"It has paint.","delta":true}'
  say '{"type":"result","status":"success","stats":{}}' ;;
*)
  say '{"type":"thread.started","thread_id":"sess-Codex"}'
  say '{"type":"turn.started"}'
  say '{"type":"item.completed","item":{"id":"item_0","type":"agent_message","text":"I will read it."}}'
  say '{"type":"item.started","item":{"id":"item_1","type":"command_execution","command":"cat plan.md","aggregated_output":"","status":"in_progress"}}'
  say '{"type":"item.completed","item":{"id":"item_1","type":"command_execution","command":"cat plan.md","aggregated_output":"x","exit_code":0,"status":"completed"}}'
  say '{"type":"item.completed","item":{"id":"item_2","type":"agent_message","text":"It has paint."}}'
  say '{"type":"turn.completed","usage":{}}' ;;
esac
""", "TURNS" => turns))
chmod(turner, 0o755)

const e = K.build_editor(page)
const w = Window(e, size=(900px, 700px))
frames(win=w, n=2) = foreach(_ -> Base.invokelatest(frame, win), 1:n)
frames(w, 4)
K.focus(e)

"Draw frames until `f()` is true, for 5 seconds at the most. The agent's lines are read between frames."
until(f) = begin
  from = time()
  while time() - from < 5
    frames(w, 1)
    f() && return true
    sleep(0.02)
  end
  false
end

"Press the key `k` in the window with the keys `held` down"
press(k, held...) = begin
  foreach(h -> w.keys |= h, held)
  onkey(w, KeyPress{k}(0, w))
  foreach(h -> w.keys ⊻= h, held)
  frames()
end
typed(s) = (foreach(c -> ontype(w, Typed(c, w)), s); frames())
click(x, y) = (w.mouse = typeof(w.mouse)(x, y); onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames())
"Every rectangle in `r`, as it was last drawn"
flat(r, out=Any[]) = (push!(out, r); try foreach(c -> flat(c, out), r.children) catch end; out)
"The rectangle with the name `name` in the window, or nothing"
named(name) = (k = findfirst(r -> hasproperty(r.from, :name) && r.from.name == name, flat(K.rect(e))); k === nothing ? nothing : flat(K.rect(e))[k])
heard_lines() = isfile(heard) ? readlines(heard) : String[]
const pane = K.agent_pane(e)
items() = pane.session.items

try
  @testset "Agent Mode widens the window, with the agent at the left, the page on a card and the outline at the right" begin
    @test haskey(K.COMMANDS, :agent_mode)
    @test !K.agent_mode(e) && named("Agent") === nothing
    K.agent_mode!(e)
    frames(w, 3)
    @test K.agent_mode(e) && K.agent_shows(e)
    @test w.size[1] > 900px && w.size[2] == 700px
    left, card, right = named("Agent"), named("Page card"), named("Outline")
    @test left !== nothing && card !== nothing && right !== nothing
    # The outline ends at the window's right edge, the card is beside it, and the pane has all the rest
    @test right.left + right.width == w.size[1]
    @test card.left + card.width + K.PAGE_CARD_GAP == right.left
    @test left.left == 0px && left.left + left.width + K.PAGE_CARD_GAP == card.left
    @test abs(left.width - K.AGENT_W) <= 8px
    @test card.top == K.PAGE_CARD_GAP && card.top + card.height == w.size[2] - K.PAGE_CARD_GAP
    # The card has the shape of a sheet of paper that stands up, and the page's text is on it
    @test isapprox(K.num(card.height) / K.num(card.width), √2, atol=0.01)
    @test e.origin[1] >= card.left + K.PAGE_X && e.origin[1] + e.width <= card.left + card.width - K.PAGE_X
    # The words that you type have the keyboard
    @test w.focus === pane.field
    # A wider window gives the agent's pane the new room. The card keeps its width, beside the outline.
    was = (left.width, card.width, right.width)
    w.size = typeof(w.size)(w.size[1] + 300px, w.size[2])
    frames(w, 3)
    left, card, right = named("Agent"), named("Page card"), named("Outline")
    @test left.width == was[1] + 300px - (right.width - was[3]) && card.width == was[2]
    @test card.left + card.width + K.PAGE_CARD_GAP == right.left && left.width + K.PAGE_CARD_GAP == card.left
    w.size = typeof(w.size)(w.size[1] - 300px, w.size[2])
    frames(w, 3)
  end

  @testset "The outline lists the page's headings, and a click goes to one" begin
    rows = [r.from.from for r in flat(K.rect(e)) if hasproperty(r.from, :from) && r.from.from isa K.OutlineRow]
    @test [r.title for r in rows] == ["Paint", "Colours", "Brushes", "Done"]
    @test [r.depth for r in rows] == [0, 1, 0, 0]
    @test rows[1].opens && !rows[2].opens
    # The page's one biggest heading is the pane's title, and its sections are the headings a level down
    words = [r.from.content for r in flat(named("Outline")) if hasproperty(r.from, :content)]
    @test "The plan" in words && "3 sections" in words
    # The page is at its top, so the first section is the one that shows
    brushes = rows[3]
    at = K.rect(brushes)
    click(at.left + at.width - 20px, at.top + at.height / 2)
    @test e.buf.caret[1] == findfirst(==("## Brushes"), e.buf.lines)
    frames(w, 3)
    @test brushes.now && e.scroll.offset > 0px
    # A click on a heading's arrow hides the headings under it
    paint = K.rect(rows[1])
    click(paint.left + 14px, paint.top + paint.height / 2)
    rows = [r.from.from for r in flat(K.rect(e)) if hasproperty(r.from, :from) && r.from.from isa K.OutlineRow]
    @test [r.title for r in rows] == ["Paint", "Brushes", "Done"] && rows[1].folded
  end

  @testset "The outline of an HTML file lists the headings of its page, and the agent is told the one in view" begin
    html = joinpath(dir, "shop.html")
    write(html, """<!DOCTYPE html><title>Our shop</title>
      <body style="margin:0;font:16px/20px Helvetica">
      <h2 style="position:absolute;left:-9999px;width:1px;height:1px;overflow:hidden">Skip to the words</h2>
      <h1 style="margin:0">The shop <a href="#">#</a></h1><p style="height:200px">Words.</p>
      <h2>Paint</h2><div style="height:900px"></div>
      <h3>Colours</h3><div style="height:900px"></div>
      <h2>Brushes</h2><p>Buy <b>soft</b> brushes for the walls.</p><div style="height:900px"></div>
      <h2> </h2>
      <h2>Done</h2><div style="height:900px"></div></body>""")
    eh = K.build_editor(html)
    wh = Window(eh, size=(900px, 700px))
    frames(wh, 3)
    K.agent_mode!(eh)
    frames(wh, 3)
    @test K.html_shown(eh) && K.agent_shows(eh)
    b = eh.nodes[(:html, html)].browser
    all_rects = flat(K.rect(eh))
    rows = [r.from.from for r in all_rects if hasproperty(r.from, :from) && r.from.from isa K.OutlineRow]
    # A heading as small as a dot and one with no words are left out, and so is the # that links to a heading
    @test [r.title for r in rows] == ["Paint", "Colours", "Brushes", "Done"]
    @test [r.depth for r in rows] == [0, 1, 0, 0] && rows[1].opens
    words = [r.from.content for r in all_rects if hasproperty(r.from, :content)]
    @test "The shop" in words && "3 sections" in words
    # At the top of the page, the section in view is the page's title. The agent hears no caret: the page has none.
    @test K.page_context(eh) == ("The shop", "<ladder>\nThe window shows the file $html.\nThe section in view is \"The shop\".\nNothing is selected.\n</ladder>")
    # A click on a heading puts it near the top of the window, and the outline marks it
    brushes = rows[3]
    at = K.rect(brushes)
    wh.mouse = typeof(wh.mouse)(at.left + at.width - 20px, at.top + at.height / 2)
    onkey(wh, KeyPress{Keys.mouse_left}(0, wh))
    frames(wh, 3)
    top = K.html_outline(eh)[2][brushes.line]   # the page's title is the first of its headings
    @test abs(K.Browsers.scrolled(b) - (top - 24)) < 1 && brushes.now && !rows[1].now
    @test K.page_context(eh) == ("Brushes", "<ladder>\nThe window shows the file $html.\nThe section in view is \"Brushes\".\nNothing is selected.\n</ladder>")
    # Two clicks on a word select it, and the agent gets its exact text and the paragraph that holds it, as the page shows them
    ws = K.Browsers.page_words(b)
    t = String(reduce(vcat, [w.letters for w in ws]))
    soft = length(SubString(t, 1, prevind(t, first(findfirst("soft", t)))))   # the place before "soft" in the page's words
    spot(place) = (w = ws[K.Browsers.Select.words_at(ws, place)]; r = K.rect(b);
                   (r.left + px(w.edges[place - w.from + 1] + 0.5), r.top + px(w.top + w.tall / 2 - K.Browsers.scrolled(b))))
    hit((x, y)) = begin
      wh.mouse = typeof(wh.mouse)(x, y)
      onmouse(wh, MouseMove(wh.mouse, wh))
      wh.keys |= Keys.mouse_left; onkey(wh, KeyPress{Keys.mouse_left}(0, wh))
      wh.keys ⊻= Keys.mouse_left; onkey(wh, KeyRelease{Keys.mouse_left}(0, wh))
    end
    hit(spot(soft + 2)); hit(spot(soft + 2))
    frames(wh, 2)
    @test K.Browsers.selected_words(b) == "soft"
    # It goes with where it is in the file, as the file's line and columns
    L = findfirst(l -> occursin("<b>soft", l), readlines(html))
    line = readlines(html)[L]
    C = length(SubString(line, 1, prevind(line, first(findfirst("soft", line))))) + 1
    @test K.page_context(eh) == ("Brushes · selection", "<ladder>\nThe window shows the file $html.\nThe section in view is \"Brushes\".\n" *
      "In the file, the selection goes from line $L, column $C to line $L, column $(C + 4). Its exact text, as the page shows it:\n" *
      "<selection>\nsoft\n</selection>\nIt's in this paragraph:\n<paragraph>\nBuy soft brushes for the walls.\n</paragraph>\n</ladder>")
    # One click puts the caret there: the agent gets the words before it, and its paragraph
    sleep(0.5)
    hit(spot(soft))
    frames(wh, 2)
    @test K.Browsers.selected_words(b) == ""
    @test endswith(K.page_context(eh)[2], "\nThe caret is where the user last clicked, at line $L, column $C of the file, after \"Buy\" in this paragraph:\n" *
      "<paragraph>\nBuy soft brushes for the walls.\n</paragraph>\nNothing is selected.\n</ladder>")
    # What the agent is told at the start says how to read these
    @test occursin("<paragraph>", K.session_brief()) && occursin("where the user last clicked", K.session_brief()) && occursin("lines and columns in the HTML file", K.session_brief())
    # The wheel moves the page on, and the outline follows it
    K.Browsers.scroll!(b, K.html_outline(eh)[2][rows[4].line] - 10)
    frames(wh, 3)
    @test rows[4].now && !brushes.now && first(K.page_context(eh)) == "Done"
    # A page with no headings says so, with the title that its HTML gives it
    write(html, "<title>Bare</title><p>Words.</p>")
    for _ in 1:250
      frames(wh, 1)
      isempty(K.html_outline(eh)[1]) && break
      sleep(0.02)
    end
    frames(wh, 2)
    words = [r.from.content for r in flat(K.rect(eh)) if hasproperty(r.from, :content)]
    @test "Bare" in words && "No headings" in words
    @test K.page_context(eh) == ("shop.html", "<ladder>\nThe window shows the file $html.\nNothing is selected.\n</ladder>")
    K.close_agent!(eh)
  end

  @testset "Return gives your words to the agent, with what the window shows, and its answer shows as a page" begin
    K.focus(pane.field)
    # The field is one line tall, with the round send button at its right
    foot, send = named("Agent foot"), named("Send")
    @test foot.height < 70px && send.width == 28px && named("About") === nothing
    typed("Make a table")
    @test pane.field.buf.lines == ["Make a table"]
    sleep(2K.SEND_GROWS); frames()
    @test named("About") === nothing && named("Agent foot").height == foot.height
    # With the mouse on the button, it opens to the left over the words, to show what goes with them. Nothing else moves.
    words = (pane.field.width, length(pane.field.layout))
    w.mouse = typeof(w.mouse)(send.left + 14px, send.top + 14px)
    onmouse(w, MouseMove(w.mouse, w)); frames(w, 3); sleep(2K.SEND_GROWS); frames()
    about, pill = named("About"), named("Send pill")
    @test about !== nothing && pill.width > 28px + about.width - 1px && pill.left < send.left && pill.left + pill.width == send.left + send.width
    @test (named("Send").left, named("Send").width, named("Agent foot").height) == (send.left, 28px, foot.height)
    @test (pane.field.width, length(pane.field.layout)) == words && pill.left < send.left - 40px
    # The tooltip says that the words go with what the button shows
    tip = only(p for p in K.popups(w) if p.key == :tooltip)
    @test any(r -> occursin("Send with context  ⏎", sprint(show, r.from)), flat(tip.scene))
    # It shuts when the mouse leaves
    w.mouse = typeof(w.mouse)(send.left - 200px, send.top - 300px)
    onmouse(w, MouseMove(w.mouse, w)); frames(w, 3); sleep(2K.SEND_GROWS); frames()
    @test named("About") === nothing && named("Send pill").width == 28px
    press(Keys.enter)
    @test pane.session !== nothing && pane.field.buf.lines == [""]
    @test w.focus === pane.field
    ok = until(() -> !pane.session.busy)
    @test ok
    said = heard_lines()
    @test length(said) == 1 && occursin("\"type\":\"user\"", said[1]) && occursin("Make a table", said[1])
    # The outline's click put the section Brushes at the top of the window
    @test occursin("<ladder>\\nThe window shows the file $page.\\nThe section in view is \\\"Brushes\\\".\\nThe caret is on line", said[1]) && occursin("under the heading \\\"Brushes\\\".\\nNothing is selected.\\n</ladder>\\n\\nMake a table", said[1])
    @test pane.session.id == "test-session"
    # The pane's heading is in the top bar, after the window's own buttons, so the talk starts right under the bar
    head, plus = named("Agent head"), named("New session")
    @test head !== nothing && head.top >= 0px && head.top + head.height <= K.TOPBAR_H && head.left >= 70px
    @test plus !== nothing && plus.top + plus.height <= K.TOPBAR_H && head.left + head.width <= plus.left < named("Agent").width
    @test items()[1] isa K.YouSaid && items()[1].words == "Make a table" && items()[1].about == "Brushes"
    # The words came in pieces, and they're one reply
    @test length(items()) == 2 && items()[2] isa K.AgentReply && items()[2].whole
    sub = pane.parts[(:reply, objectid(items()[2]))]
    @test sub.buf.lines[1] == "## Paint"
    # The table is a table, not its text
    @test any(it -> !(it.content isa K.Flow), sub.layout)
    @test named("Reply") !== nothing && named("You said") !== nothing
    # What the agent says runs no code: a `ui` block shows as code, and so does a sum in a line
    @test K.foreign(sub.buf.path)
    @test !any(l -> l.lang == K.LIVE, K.kinds(sub.buf))
    @test K.made(sub, "!1+1", 1) == ("!1+1", false)
  end

  @testset "The panes are dark whatever colours the page has, and the page keeps its own" begin
    sub = pane.parts[(:reply, objectid(items()[2]))]
    inks(ed) = unique(seg.face.color for it in ed.layout if it.content isa K.Flow for vl in it.content.lines for seg in vl.segs)
    @test e.theme == :sepia
    @test K.NIGHT.ink in inks(sub) && !(K.SEPIA.ink in inks(sub))
    @test K.SEPIA.ink in inks(e) && !(K.NIGHT.ink in inks(e))
    # After a frame, the page's colours are in use again
    @test K.colours.ink == K.SEPIA.ink && !K.pane_dark[]
    # Lines that were laid out in the page's colours, as before the pane was dark, are laid out again in the pane's
    empty!(sub.flows)
    K.layout!(sub, sub.width)
    @test K.SEPIA.ink in inks(sub)
    frames(w, 2)
    @test K.NIGHT.ink in inks(sub) && !(K.SEPIA.ink in inks(sub))
    # The agent's name and the outline's lines have the pane's colours, and the file's name in the top bar has the page's
    colour(words) = (k = findfirst(r -> hasproperty(r.from, :content) && r.from.content == words, flat(K.rect(e))); flat(K.rect(e))[k].from.color)
    @test colour("Claude") == K.NIGHT.ink
    @test colour("3 sections") == K.NIGHT.dim
    @test colour("plan.md") in (K.SEPIA.ink, K.SEPIA.dim)
  end

  @testset "The agent gets the caret's column, and the selection with where it starts and ends" begin
    b = e.buf
    i = findfirst(==("Buy paint."), b.lines)
    b.anchor, b.caret = (i, 4), (i, 9)
    pane.field.buf.lines = ["What is this?"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    said = last(heard_lines())
    @test ok && occursin("The caret is on line $i, column 10, under the heading \\\"Paint\\\".", said)
    @test occursin("The selection goes from line $i, column 5 to line $i, column 10. Its exact text:\\n<selection>\\npaint\\n</selection>\\n</ladder>\\n\\nWhat is this?", said)
    # A selection over several lines has each of its lines, and one that's very long has only where it is
    j = findfirst(==("Red and blue."), b.lines)
    b.anchor, b.caret = (i, 4), (j, 3)
    @test K.text_between(b, (i, 4), (j, 3)) == "paint.\n\n### Colours\n\nRed"
    # The lines of the selection are as they are in the file, with nothing before them
    @test endswith(K.page_context(e)[2], "to line $j, column 4. Its exact text:\n<selection>\npaint.\n\n### Colours\n\nRed\n</selection>\n</ladder>")
    b.anchor, b.caret = (1, 0), K.line_end(b, length(b.lines))
    @test length(join(b.lines, "\n")) < K.MOST_PICKED && occursin("Its exact text:", K.page_context(e)[2])
    # The agent is told when nothing is selected, so it knows that Ladder left nothing out
    b.anchor = b.caret = (i, 0)
    @test !occursin("<selection>", K.page_context(e)[2]) && occursin("line $i, column 1,", K.page_context(e)[2])
    @test endswith(K.page_context(e)[2], "\nNothing is selected.\n</ladder>")
    # Selected text that holds the closing tag would end the block early, so only its place goes
    was = b.lines[i]
    b.lines[i] = "Buy </selection> paint."
    b.anchor, b.caret = (i, 0), (i, 20)
    told = K.page_context(e)[2]
    @test !occursin("<selection>", told) && occursin("to line $i, column 21. Read its text in the file.\n</ladder>", told)
    # A page with changes that aren't in its file says so. Ladder saves before a message, so that's a page it couldn't save.
    @test !K.dirty(b) && !occursin("aren't in the file", told)
    b.version += 1
    @test K.dirty(b) && occursin("The window shows the file $page. The window has changes that aren't in the file yet.\n", K.page_context(e)[2])
    b.version -= 1
    b.lines[i] = was
    b.anchor = b.caret = (i, 0)
    # What the agent is told at the start says how to read the block
    @test occursin("<ladder>", K.session_brief()) && occursin("column 1 is before the first character", K.session_brief())
  end

  @testset "A reply in plain words needs no pieces" begin
    pane.field.buf.lines = ["Say hello"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    @test ok && last(items()) isa K.AgentReply && last(items()).text == "Plain **words**."
  end

  @testset "The agent asks before a command, and Allow lets it run" begin
    pane.field.buf.lines = ["Please run it"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentWants)
    @test ok
    wants = last(items())
    step = items()[end-1]
    @test step isa K.AgentStep && step.words == "Make the paint" && step.state == :going
    @test wants.tool == "Bash" && wants.detail == "make paint" && wants.answer == :none
    frames(w, 3)   # the pane scrolls to what's new
    @test named("Agent asks") !== nothing && named("Allow") !== nothing && named("Refuse") !== nothing
    allow = named("Allow")
    click(allow.left + allow.width / 2, allow.top + allow.height / 2)
    @test wants.answer == :allowed
    ok = until(() -> !pane.session.busy)
    @test ok && step.state == :done && last(items()).text == "It ran."
    answer = last(heard_lines())
    @test occursin("\"control_response\"", answer) && occursin("\"request_id\":\"r1\"", answer) && occursin("\"behavior\":\"allow\"", answer)
    # The agent gets back what it asked to run
    @test occursin("\"updatedInput\":{\"command\":\"make paint\",\"description\":\"Make the paint\"}", answer)
    # Refuse says no
    pane.field.buf.lines = ["Now run it again"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentWants)
    frames(w, 3)
    refuse = named("Refuse")
    click(refuse.left + refuse.width / 2, refuse.top + refuse.height / 2)
    ok = until(() -> !pane.session.busy)
    @test ok && occursin("\"behavior\":\"deny\"", last(heard_lines())) && last(items()).text == "I left it."
  end

  @testset "More than three steps in a row fold into one line, and the Stop button stops the agent" begin
    pane.field.buf.lines = ["Take many steps"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    @test ok && count(it -> it isa K.AgentStep && startswith(it.words, "Looking for paint"), items()) == 5
    frames(w, 2)
    fold = named("Steps")
    @test fold !== nothing && count(r -> hasproperty(r.from, :name) && r.from.name == "Step", flat(K.rect(e))) == 1   # the one step of the command before
    click(fold.left + 30px, fold.top + fold.height / 2)
    @test count(r -> hasproperty(r.from, :name) && r.from.name == "Step", flat(K.rect(e))) == 6
    # A step that's under way keeps the agent busy, and the button at the foot stops it
    pane.field.buf.lines = ["Now go slow"]
    K.send_words!(pane)
    ok = until(() -> last(items()) isa K.AgentStep)
    @test ok && pane.session.busy && last(items()).words == "Reading notes.md" && last(items()).state == :going
    frames(w, 3)
    stop = named("Stop")
    @test stop !== nothing && named("Send") === nothing
    click(stop.left + stop.width / 2, stop.top + stop.height / 2)
    ok = until(() -> !pane.session.busy)
    @test ok && occursin("\"interrupt\"", last(heard_lines()))
    @test last(items()) isa K.SessionNote && !last(items()).bad && items()[end-1].state == :done
  end

  @testset "A key for the window works from the agent's pane, and Esc leaves your words" begin
    K.focus(pane.field)
    typed("half a thought")
    press(Keys.escape)
    @test pane.field.buf.lines == ["half a thought"] && w.focus === pane.field && K.agent_mode(e)
    # The agent is what agent mode is for, so nothing hides its pane: the top bar has no sidebar button, and ⌘\ does nothing
    buttons = [r.from.from.action for r in flat(K.rect(e)) if hasproperty(r.from, :from) && r.from.from isa K.ToolButton]
    @test !(:panel in buttons) && :right_panel in buttons
    was = (named("Agent").width, named("Page card").left)
    press(Keys.backslash, Keys.cmd)
    frames(w, 2)
    @test named("Agent") !== nothing && (named("Agent").width, named("Page card").left) == was
    # The button at the right end of the top bar hides the outline. The card stays beside the window's edge, and the agent has the room.
    K.toggle_right!(e)
    e.nodes[:right_slid] = (0.0, 0.0)
    frames(w, 2)
    @test named("Outline") === nothing && named("Page card").left + named("Page card").width + K.PAGE_CARD_GAP == w.size[1]
    @test named("Agent").width > was[1]
    K.toggle_right!(e)
    e.nodes[:right_slid] = (1.0, 0.0)
    frames(w, 2)
    @test named("Outline") !== nothing && (named("Agent").width, named("Page card").left) == was
  end

  @testset "A drag of the strip beside the card gives the agent or the page more of the window" begin
    move(x, y) = (w.mouse = typeof(w.mouse)(x, y); onmouse(w, MouseMove(w.mouse, w)); frames(w, 2))
    hold() = (w.keys |= Keys.mouse_left; onkey(w, KeyPress{Keys.mouse_left}(0, w)); frames(w, 1))
    drop() = (w.keys ⊻= Keys.mouse_left; onkey(w, KeyRelease{Keys.mouse_left}(0, w)); frames(w, 2))
    edge, card, left = named("Card edge"), named("Page card"), named("Agent")
    # The strip fills the gap between the agent's pane and the card
    @test edge !== nothing && edge.left == left.left + left.width && edge.left + edge.width == card.left
    @test K.PAGE_CARD_CHOSEN[] === nothing
    was = (agent=left.width, card=card.width, right=card.left + card.width, text=e.width)
    x, y = edge.left + 4px, edge.top + 300px
    # A drag to the right gives the agent 100px of the card. The card's right edge stays, and the page's text wraps in the new width.
    move(x, y); hold(); move(x + 60px, y); move(x + 100px, y); drop()
    card, left = named("Page card"), named("Agent")
    @test left.width == was.agent + 100px && card.width == was.card - 100px
    @test card.left + card.width == was.right && left.width + K.PAGE_CARD_GAP == card.left
    @test e.width == was.text - 100px
    @test K.PAGE_CARD_CHOSEN[] == card.width
    # A mouse that moves with no button down changes nothing
    move(x + 300px, y)
    @test named("Page card").width == was.card - 100px
    # A wider window gives the agent the new room, as before
    w.size = typeof(w.size)(w.size[1] + 200px, w.size[2]); frames(w, 3)
    @test named("Page card").width == was.card - 100px
    @test named("Agent").width == w.size[1] - named("Outline").width - named("Page card").width - 2K.PAGE_CARD_GAP > was.agent + 100px
    w.size = typeof(w.size)(w.size[1] - 200px, w.size[2]); frames(w, 3)
    # A drag to the left gives the page more, and stops while the agent still has its least width
    edge = named("Card edge")
    x = edge.left + 4px
    move(x, y); hold(); move(x - 150px, y); drop()
    @test named("Page card").width == was.card + 50px && named("Agent").width == was.agent - 50px
    edge = named("Card edge"); x = edge.left + 4px
    move(x, y); hold(); move(x - 2000px, y); drop()
    @test named("Agent").width == K.AGENT_MIN && named("Page card").left == K.AGENT_MIN + K.PAGE_CARD_GAP
    # A drag far to the right leaves the card its least width
    edge = named("Card edge"); x = edge.left + 4px
    move(x, y); hold(); move(x + 3000px, y); drop()
    @test named("Page card").width == K.PAGE_CARD_NARROWEST && named("Page card").left + K.PAGE_CARD_NARROWEST == was.right
    # Two clicks on the strip give the card a page's shape again
    edge = named("Card edge"); x = edge.left + 4px
    move(x, y); hold(); drop(); hold(); drop()
    @test K.PAGE_CARD_CHOSEN[] === nothing
    @test named("Page card").width == was.card && named("Agent").width == was.agent && e.width == was.text
  end

  @testset "The card's width is kept in the settings file" begin
    e.remember = true
    K.page_card!(e, 500px)
    @test occursin("\npagecard=500.0\n", read(K.settings_file(), String))
    K.PAGE_CARD_CHOSEN[] = nothing
    K.load_settings!(e)
    @test K.PAGE_CARD_CHOSEN[] == 500px
    frames(w, 2)
    @test named("Page card").width == 500px
    K.page_card!(e, nothing)
    @test occursin("\npagecard=\n", read(K.settings_file(), String))
    K.PAGE_CARD_CHOSEN[] = 500px
    K.load_settings!(e)
    @test K.PAGE_CARD_CHOSEN[] === nothing
    e.remember = false
    frames(w, 2)
  end

  @testset "Agent Mode again puts the window back, and the session stays" begin
    s = pane.session
    K.agent_mode!(e)
    frames(w, 3)
    @test !K.agent_mode(e) && w.size[1] == 900px
    @test named("Agent") === nothing && named("Page card") === nothing && named("Outline") === nothing
    @test !e.panel
    @test pane.session === s && K.running(s)
    K.agent_mode!(e)
    frames(w, 3)
    @test named("Reply") !== nothing && pane.field.buf.lines == ["half a thought"]
    # End Agent Session ends the program, and the next words start another
    K.end_agent_session!(e)
    ok = until(() -> !K.running(s))
    @test ok && pane.session === nothing && named("Reply") === nothing
  end

  @testset "A click on the agent's name lists the agents, and Grok, Gemini and Codex work by turns" begin
    name = named("Agent name")
    @test name !== nothing && name.top + name.height <= K.TOPBAR_H
    click(name.left + 10px, name.top + 10px)
    frames()
    menus = [p for p in K.popups(w) if p.key == K.AGENT_MENU]
    @test length(menus) == 1
    # Each agent has a row with its logo, and the pane's agent has a tick
    rows() = [r for r in flat(only(p for p in K.popups(w) if p.key == K.AGENT_MENU).scene) if hasproperty(r.from, :name) && r.from.name == "Agent row"]
    icons(r) = [x.from.from.name for x in flat(r) if hasproperty(x.from, :from) && x.from.from isa K.Icon]
    @test [r.from.from.name for r in rows()] == ["Claude", "Codex", "Gemini", "Grok"]
    @test icons(rows()[1]) == ["agent-claude", "check"] && icons(rows()[4]) == ["agent-grok"]
    @test all(r -> r.top >= K.TOPBAR_H - 12px, rows())
    # A click on a row makes that agent the pane's, and shuts the menu
    grok = rows()[4]
    click(grok.left + 20px, grok.top + 10px)
    @test e.ai == "Grok" && K.pane_agent(pane, e) == "Grok" && !any(p -> p.key == K.AGENT_MENU, K.popups(w))
    K.pane_agent!(pane, "Claude")
    # Settings says which agents are listed. One that's taken out goes from the menu, and the one that's chosen stays whatever its box says.
    e.remember = true
    K.agent_listed!(e, "Codex", false)
    K.agent_listed!(e, "Claude", false)
    @test K.listed_agents(e) == ["Claude", "Gemini", "Grok"]
    @test [c.name for c in K.choices_for(K.AgentChoice, e)] == ["Claude", "Gemini", "Grok"]
    @test occursin("\nagentshidden=Claude,Codex\n", read(K.settings_file(), String))
    click(name.left + 10px, name.top + 10px)
    frames()
    @test [r.from.from.name for r in rows()] == ["Claude", "Gemini", "Grok"]
    K.close_popup!(w, K.AGENT_MENU)
    empty!(K.AGENTS_HIDDEN[])
    K.load_settings!(e)
    @test K.AGENTS_HIDDEN[] == Set(["Claude", "Codex"])
    K.agent_listed!(e, "Codex", true)
    K.agent_listed!(e, "Claude", true)
    @test K.listed_agents(e) == ["Claude", "Codex", "Gemini", "Grok"] && occursin("\nagentshidden=\n", read(K.settings_file(), String))
    e.remember = false
    frames()
    K.TURN_COMMAND[] = Cmd([turner])
    for (agent, step) in (("Grok", "Reading plan.md"), ("Gemini", "Reading plan.md"), ("Codex", "Running cat plan.md"))
      K.pane_agent!(pane, agent)
      frames()
      @test e.ai == agent && pane.session === nothing && K.pane_agent(pane, e) == agent
      pane.field.buf.lines = ["Read the plan"]
      K.send_words!(pane)
      s = pane.session
      @test s.turns && s.agent == agent && s.busy
      ok = until(() -> !s.busy && !K.running(s))
      its = items()
      @test ok && [typeof(i) for i in its] == [K.YouSaid, K.AgentReply, K.AgentStep, K.AgentReply]
      @test its[2].text == "I will read it." && its[2].whole && its[4].text == "It has paint." && its[4].whole
      @test its[3].words == step && its[3].state == :done
      @test s.id == "sess-$agent"
      # The second turn names the session, so the agent goes on with it. No program runs between turns, and the pane says so.
      frames()
      @test named("Reply") !== nothing
      pane.field.buf.lines = ["And then?"]
      K.send_words!(pane)
      ok = until(() -> !s.busy && !K.running(s))
      said = readlines(turns)
      @test ok && pane.session === s && length(items()) == 8
      # Grok takes what Ladder says of itself as rules. The others read it before the first words.
      @test startswith(said[end-1], agent == "Grok" ? "Grok||<ladder>" : "$agent||<ladder-brief> You are in Ladder") && endswith(said[end-1], "Read the plan")
      @test occursin("</ladder-brief>  <ladder>", said[end-1]) == (agent != "Grok")
      @test startswith(said[end], "$agent|sess-$agent|<ladder>") && endswith(said[end], "And then?")
    end
    s = pane.session
    # What you say while a turn is under way waits for the turn's end. Stop ends the turn and what waited.
    pane.field.buf.lines = ["go slow"]
    K.send_words!(pane)
    pane.field.buf.lines = ["Later words"]
    K.send_words!(pane)
    @test s.busy && K.running(s) && length(s.queue) == 1
    n = length(readlines(turns))
    K.stop!(s)
    ok = until(() -> !s.busy && !K.running(s))
    @test ok && isempty(s.queue) && length(readlines(turns)) == n
    @test last(items()) isa K.SessionNote && last(items()).words == "You stopped Codex." && !last(items()).bad
    # A turn whose program fails says the line of what it wrote that names the error
    pane.field.buf.lines = ["fail please"]
    K.send_words!(pane)
    ok = until(() -> !s.busy && !K.running(s))
    @test ok && last(items()) isa K.SessionNote && last(items()).bad && last(items()).words == "Codex stopped: Error: no key for Codex"
    # Claude again ends the session with Codex
    K.pane_agent!(pane, "Claude")
    frames()
    @test e.ai == "Claude" && pane.session === nothing
    K.TURN_COMMAND[] = nothing
  end

  @testset "Closing the window ends the agent's program" begin
    pane.field.buf.lines = ["One more"]
    K.send_words!(pane)
    ok = until(() -> !pane.session.busy)
    s = pane.session
    @test ok && K.running(s)
    K.close_agent!(e)
    ok = until(() -> !K.running(s))
    @test ok
  end
finally
  K.SESSION_COMMAND[] = nothing
  K.TURN_COMMAND[] = nothing
  pane.session === nothing || K.close!(pane.session)
end
