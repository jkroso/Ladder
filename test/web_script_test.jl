# Tests for the scripts of a page: web/jsc.jl, which runs JavaScript with
# JavaScriptCore, web/script.jl and web/window.jl, which give a script the
# page, and web/live.jl, which lays the page out again after a script changes
# it. Run them with `julia -O0 --project=. test/web_script_test.jl`. They use
# the fonts of this Mac and no web.

@use Test: @test, @testset, @test_throws
@use "../web/jsc" => JS
@use "../web/dom" => Dom
@use "../web/script" => Script
@use "../web/live" => Live

"The page that `html` writes, with its scripts run"
running(html; kw...) = Live.live(html; wide=400, kw...)
"What `code` gives in the page of `l`"
js(l, code) = Live.evaluate(l, code)
"The lines that the scripts of `l` printed at `level`"
lines(l, level=:log) = [text for (lv, text) in l.scripts.log if lv == level]

@testset "JavaScript" begin
  c = JS.Context()
  @test JS.evaluate(c, "1 + 2") == 3
  @test JS.evaluate(c, "[1, 'two', null, undefined, true, [3]]") == Any[1.0, "two", nothing, nothing, true, Any[3.0]]
  @test JS.evaluate(c, "'héllo 😀 \\0 end'") == "héllo 😀 \0 end"
  c["double"] = x -> 2x
  @test JS.evaluate(c, "double(4)") == 8
  @test JS.call(c, "double", 5) == 10
  c["things"] = Dict("list" => [1, "a", nothing], "join" => (a, b) -> a * b, "none" => missing)
  @test JS.evaluate(c, "things.join('a', 'b') + things.list.length + (things.list[2] === null) + (things.none === undefined)") == "ab3truetrue"
  @test c["things"]["list"] == Any[1.0, "a", nothing]
  # What a script throws is thrown in Julia, with where it was
  e = try JS.evaluate(c, "\nnull.x"; name="page.js") catch e; e end
  @test e isa JS.ScriptError && occursin("TypeError", e.message) && e.line == 2 && e.file == "page.js"
  # What Julia throws while a script calls it, the script can catch
  c["fail"] = () -> error("no good")
  @test JS.evaluate(c, "try { fail() } catch (e) { 'caught ' + e.message }") == "caught no good"
  # A promise is settled before `evaluate` gives its value back
  JS.evaluate(c, "var settled = 0; Promise.resolve(7).then(v => { settled = v })")
  @test c["settled"] == 7
  # A script that never ends is stopped, and the context goes on
  quick = JS.Context(limit=0.3)
  t = time()
  @test_throws JS.ScriptError JS.evaluate(quick, "while (true) {}")
  @test time() - t < 5
  @test JS.evaluate(quick, "'alive'") == "alive"
  # Each context has memory of its own, which closing it frees. In one shared group, each closed page kept about 1 MB for ever.
  group(x) = ccall((:JSContextGetGroup, JS.LIB), Ptr{Cvoid}, (Ptr{Cvoid},), x.ref)
  @test group(c) != group(quick)
  close(quick)
  # A context that's dropped is closed by the next call from the main task, after Julia frees it
  # The test looks for its own context, by its number. A count of the open contexts would be wrong when tests share a
  # process, since the same call closes the contexts of the pages that earlier tests dropped.
  drop() = (dropped = JS.Context(); JS.evaluate(dropped, "({a: 1})")["a"]; dropped.ref)
  ref = drop()
  @test haskey(JS.CONTEXTS, ref)
  GC.gc(); GC.gc()
  JS.evaluate(c, "1")
  @test !haskey(JS.CONTEXTS, ref) && isempty(JS.DROPPED)
  # In a task with a stack of its own, JavaScriptCore would end the program: it's an error there
  @test_throws TaskFailedException fetch(@async JS.evaluate(c, "1"))
  close(c)
  @test !isopen(c)
  @test_throws ErrorException JS.evaluate(c, "1")
end

@testset "a script reads the page" begin
  l = running("""<!DOCTYPE html><html><head><title>The  title</title></head><body class="a b">
    <div id="main" data-user-name="Jo"><p class="x">One <b>two</b></p><p>Three</p></div><!-- gone --><a href="/next?q=1#top">next</a></body></html>""";
    base="https://example.com/dir/page.html")
  @test js(l, "document.title") == "The title"
  @test js(l, "document.documentElement.tagName + document.body.tagName + document.head.tagName") == "HTMLBODYHEAD"
  @test js(l, "document.getElementById('main').children.length") == 2
  @test js(l, "document.querySelector('#main > p.x b').textContent") == "two"
  @test js(l, "[...document.querySelectorAll('p')].map(p => p.textContent).join('|')") == "One two|Three"
  @test js(l, "document.querySelector('nothing')") === nothing
  @test js(l, "document.getElementsByTagName('p').length + document.getElementsByClassName('x').length") == 3
  @test js(l, "document.querySelector('b').closest('div').id") == "main"
  @test js(l, "document.querySelector('b').matches('p > b')") == true
  @test js(l, "document.querySelector('p').innerHTML") == "One <b>two</b>"
  @test js(l, "document.querySelector('p').outerHTML") == "<p class=\"x\">One <b>two</b></p>"
  @test js(l, "document.getElementById('main').dataset.userName") == "Jo"
  @test js(l, "document.body.classList.contains('b') && !document.body.classList.contains('c')") == true
  # The same node is always the same object, so what a script puts on it stays
  @test js(l, "document.querySelector('p') === document.getElementById('main').firstChild") == true
  @test js(l, "document.querySelector('p').mine = 5; document.getElementById('main').firstElementChild.mine") == 5
  @test js(l, "document.querySelector('b').parentNode.parentNode.parentNode === document.body") == true
  @test js(l, "document.documentElement.parentNode === document && document.parentNode === null") == true
  @test js(l, "var p = document.querySelector('p'); p.nextSibling === p.nextElementSibling && p.previousSibling === null") == true
  @test js(l, "p instanceof HTMLParagraphElement && p instanceof HTMLElement && p instanceof Element && p instanceof Node && p instanceof EventTarget") == true
  @test js(l, "p.nodeType === Node.ELEMENT_NODE && p.firstChild.nodeType === 3 && p.firstChild.data === 'One '") == true
  @test js(l, "document.body.contains(p) && !p.contains(document.body) && p.isConnected") == true
  # Addresses are from the page's own
  @test js(l, "document.querySelector('a').href") == "https://example.com/next?q=1#top"
  @test js(l, "var a = document.querySelector('a'); a.pathname + ' ' + a.search + ' ' + a.hash + ' ' + a.host") == "/next ?q=1 #top example.com"
  @test js(l, "location.href + ' ' + location.origin + ' ' + location.pathname") == "https://example.com/dir/page.html https://example.com /dir/page.html"
  @test js(l, "new URL('../x?a=1&b=two', location.href).searchParams.get('b')") == "two"
  @test js(l, "document.compatMode") == "CSS1Compat"
  close(l)
end

@testset "a script changes the page" begin
  l = running("<!DOCTYPE html><body><ul id=list><li>one</li></ul><p id=p style='color: red'>text</p></body>")
  doc = l.doc
  list = Dom.attr.(filter(c -> c isa Dom.Element, doc.body.children), "id")
  @test list == ["list", "p"]
  ul = doc.body.children[1]
  js(l, "var ul = document.getElementById('list'); var li = document.createElement('li'); li.textContent = 'two'; ul.appendChild(li)")
  @test Dom.text(ul) == "onetwo"
  @test l.scripts.changed
  js(l, "ul.insertBefore(document.createElement('li'), ul.firstChild).innerHTML = '<b>zero</b> &amp; more'")
  @test Dom.text(ul) == "zero & moreonetwo"
  @test ul.children[1].children[1].tag == "b" && ul.children[1].parent === ul
  # A node that's put somewhere else leaves where it was
  js(l, "ul.appendChild(ul.firstChild)")
  @test Dom.text(ul) == "onetwozero & more"
  js(l, "ul.removeChild(ul.lastChild); ul.children[0].remove()")
  @test Dom.text(ul) == "two"
  js(l, "ul.append('a', document.createElement('li'), 'b'); ul.prepend('start')")
  @test js(l, "ul.childNodes.length") == 5 && Dom.text(ul) == "starttwoab"
  js(l, "var f = document.createDocumentFragment(); f.append(document.createElement('li'), document.createElement('li')); ul.replaceChildren(f)")
  @test length(ul.children) == 2 && js(l, "f.childNodes.length") == 0
  js(l, "ul.innerHTML = '<li class=a>1</li><li>2</li>'; ul.lastChild.insertAdjacentHTML('beforebegin', '<li>1.5</li>')")
  @test Dom.text(ul) == "11.52"
  js(l, "ul.firstChild.replaceWith(document.createTextNode('x')); ul.lastChild.before('y'); ul.lastChild.after('z')")
  @test Dom.text(ul) == "x1.5y2z"
  @test js(l, "var copy = ul.cloneNode(true); copy.textContent + (copy.parentNode === null) + (copy !== ul)") == "x1.5y2ztruetrue"
  # The parts of a table are read as in a table
  js(l, "var t = document.createElement('table'); t.innerHTML = '<tr><td>a</td><td>b</td></tr>'; document.body.appendChild(t)")
  @test js(l, "t.querySelectorAll('td').length + t.firstChild.tagName + t.rows.length") == "2TBODY1"
  js(l, "t.rows[0].innerHTML = '<td>only</td>'")
  @test js(l, "t.rows[0].cells.length + t.rows[0].cells[0].textContent") == "1only"
  js(l, "t.remove()")
  # What the tag says
  p = doc.body.children[2]
  js(l, "var p = document.getElementById('p'); p.setAttribute('title', 'T'); p.id = 'q'; p.className = 'one two'; p.classList.add('three'); p.classList.remove('one'); p.classList.toggle('four')")
  @test p.attrs["title"] == "T" && p.attrs["id"] == "q" && p.attrs["class"] == "two three four"
  @test js(l, "p.getAttribute('TITLE') + p.hasAttribute('nope') + p.getAttribute('nope') + p.getAttributeNames().sort().join()") == "Tfalsenullclass,id,style,title"
  js(l, "p.removeAttribute('title'); p.dataset.kind = 'note'; p.hidden = true")
  @test !haskey(p.attrs, "title") && p.attrs["data-kind"] == "note" && haskey(p.attrs, "hidden")
  # The style that its tag writes
  @test js(l, "p.style.color + p.style.length + p.style.backgroundColor") == "red1"
  js(l, "p.style.backgroundColor = 'blue'; p.style.setProperty('margin-top', '4px', 'important'); p.style.color = ''; p.style.setProperty('--gap', '2px')")
  @test p.attrs["style"] == "background-color: blue; margin-top: 4px !important; --gap: 2px;"
  @test js(l, "p.style.marginTop + p.style.getPropertyPriority('margin-top') + p.style.getPropertyValue('--gap') + p.style.cssText.length") == "4pximportant2px63"
  js(l, "p.style.cssText = 'width: 10px'")
  @test p.attrs["style"] == "width: 10px"
  # Text
  js(l, "p.firstChild.data = 'new'; p.firstChild.appendData(' text')")
  @test Dom.text(p) == "new text"
  @test js(l, "var c = document.createComment('note'); p.appendChild(c); p.innerHTML") == "new text<!--note-->"
  @test js(l, "c.nodeType + c.data + p.textContent") == "8notenew text"
  # What the page can't hold is an error that the script can catch
  @test js(l, "try { p.appendChild(document.body) } catch (e) { e.name }") == "HierarchyRequestError"
  @test js(l, "try { p.removeChild(ul) } catch (e) { e.name }") == "NotFoundError"
  @test js(l, "try { document.querySelector('p[') } catch (e) { 'bad selector' }") == "bad selector"
  close(l)
end

@testset "the page's own scripts" begin
  files = Dict("https://example.com/app.js" => "window.fromFile = document.currentScript.src; order.push('file')",
               "https://example.com/data.json" => "{\"n\": 42}")
  l = running("""<!DOCTYPE html><html><head>
    <script>var order = ['head']; var bodyThere = document.body !== null</script>
    <script src="app.js"></script>
    <script type="application/json" id="data">{"kept": true}</script>
    <script type="module">order.push('module')</script>
    <script>this is not JavaScript</script>
    <script>order.push('after the broken one')</script>
    </head><body><p id=out>before</p><noscript><p id=none>No scripts</p></noscript>
    <script>
      document.getElementById('out').textContent = 'written by a script'
      document.addEventListener('DOMContentLoaded', () => order.push('ready ' + document.readyState))
      window.addEventListener('load', () => order.push('load ' + document.readyState))
      window.onload = () => order.push('onload')
      order.push('body ' + document.readyState)
      console.log('hello', 1, [2, 'x'], {a: null})
      fetch('data.json').then(r => r.json()).then(d => { window.fetched = d.n })
      fetch('missing.json').catch(e => { window.failed = e.message })
      var s = document.createElement('script'); s.textContent = "order.push('added')"; document.head.appendChild(s)
    </script></body></html>"""; load=address -> get(files, address, nothing), base="https://example.com/index.html")
  # A module runs after the page's other scripts, and before the page is ready
  @test js(l, "order.join(', ')") == "head, file, after the broken one, body loading, added, module, ready interactive, onload, load complete"
  @test js(l, "bodyThere && fromFile === 'https://example.com/app.js'") == true
  @test js(l, "JSON.parse(document.getElementById('data').textContent).kept") == true
  @test js(l, "fetched + ' ' + failed") == "42 Load failed"
  @test lines(l) == ["hello 1 [2, \"x\"] {a: null}"]
  # The script that couldn't be read is in the log, with its line, and the scripts after it ran
  @test length(lines(l, :error)) == 1 && occursin("SyntaxError", lines(l, :error)[1])
  # The page is laid out as the scripts left it, and what's for a reader with no scripts isn't in it
  p = Live.page!(l)
  words = join(String(w.letters) for w in p.words)
  @test occursin("written by a script", words) && !occursin("before", words) && !occursin("No scripts", words)
  close(l)
end

@testset "timers" begin
  l = running("""<body><p id=out>0</p><script>
    var out = document.getElementById('out'), ran = []
    setTimeout(() => { out.textContent = '1'; ran.push('first') }, 20)
    setTimeout(x => ran.push('with ' + x), 0, 'an argument')
    var again = setInterval(() => { ran.push('again'); if (ran.filter(r => r === 'again').length === 3) clearInterval(again) }, 10)
    var never = setTimeout(() => ran.push('never'), 5); clearTimeout(never)
    requestAnimationFrame(t => ran.push('frame ' + (t >= 0)))
    Promise.resolve().then(() => ran.push('promise'))
    setTimeout(() => { throw new Error('thrown in a timer') }, 0)
  </script></body>""")
  @test js(l, "ran.join()") == "promise"
  @test Live.waiting(l) == 0   # a script waits for the next frame
  p = Live.page!(l)
  @test !l.scripts.changed
  wait = 0.0
  for _ in 1:200
    wait = Live.step!(l)
    wait === nothing && break
    sleep(0.005)
  end
  @test wait === nothing
  @test js(l, "ran.join()") == "promise,frame true,with an argument,again,first,again,again"
  @test any(t -> occursin("thrown in a timer", t), lines(l, :error))
  # A promise that fails, with no script to take the failure, is in the log too
  js(l, "Promise.reject(new Error('lost in a promise')); Promise.reject(new Error('taken')).catch(() => {})")
  @test any(t -> occursin("lost in a promise", t), lines(l, :error)) && !any(t -> occursin("taken", t), lines(l, :error))
  # The timer changed the page, so it's laid out again
  @test l.scripts.changed
  @test Live.page!(l) !== p && join(String(w.letters) for w in Live.page!(l).words) == "1"
  @test Live.page!(l) === Live.page!(l)
  close(l)
end

@testset "events" begin
  l = running("""<!DOCTYPE html><body style="margin: 0">
    <div id=outer style="height: 50px"><a id=link href="https://example.com/" style="display: block; width: 100px; height: 20px">go</a></div>
    <button id=b onclick="heard.push('tag ' + event.type + ' ' + (this === event.target))" style="display: block; height: 30px">press</button>
    <label id=label style="display: block; height: 20px"><input type=checkbox id=tick> tick</label>
    <script>
      var heard = []
      var outer = document.getElementById('outer'), link = document.getElementById('link'), b = document.getElementById('b')
      outer.addEventListener('click', e => heard.push('outer ' + e.target.id + ' ' + e.eventPhase))
      outer.addEventListener('click', e => heard.push('capture ' + e.eventPhase), true)
      link.addEventListener('click', e => { heard.push('link ' + e.clientX + ',' + e.clientY); if (window.stay) e.preventDefault() })
      document.addEventListener('click', e => heard.push('document'))
      window.addEventListener('click', e => heard.push('window ' + (e.currentTarget === window)))
      document.getElementById('tick').addEventListener('change', e => heard.push('ticked ' + e.target.checked))
    </script></body>""")
  # A click goes down to the element under the point and back up
  @test Live.click!(l, 10, 10) == true
  @test js(l, "heard.join('|')") == "capture 1|link 10,10|outer link 3|document|window true"
  # A script can say that the click does no more
  js(l, "heard = []; stay = true")
  @test Live.click!(l, 10, 10) == false
  # Beside the link, only the box round it hears
  js(l, "heard = []")
  @test Live.click!(l, 300, 40) == true
  @test js(l, "heard.join('|')") == "capture 2|outer outer 2|document|window true"
  # A handler in the tag
  js(l, "heard = []")
  Live.click!(l, 10, 60)
  @test js(l, "heard[0]") == "tag click true"
  # A click on a tick box, or on its label, ticks it
  js(l, "heard = []")
  Live.click!(l, 100, 90)
  @test js(l, "heard.join('|') + ' ' + document.getElementById('tick').checked") == "document|window true|ticked true true"
  @test haskey(l.doc.body.children[findfirst(c -> c isa Dom.Element && Dom.attr(c, "id") == "label", l.doc.body.children)].children[1].attrs, "checked")
  # Events that a script makes
  @test js(l, """var got = []
    b.addEventListener('ping', e => got.push(e.detail.n + ' ' + e.bubbles), {once: true})
    b.dispatchEvent(new CustomEvent('ping', {detail: {n: 1}})); b.dispatchEvent(new CustomEvent('ping', {detail: {n: 2}}))
    var f = () => got.push('removed'); b.addEventListener('x', f); b.removeEventListener('x', f); b.dispatchEvent(new Event('x'))
    b.addEventListener('stop', e => { e.stopPropagation(); got.push('stopped') }); document.body.addEventListener('stop', () => got.push('too far'))
    b.dispatchEvent(new Event('stop', {bubbles: true}))
    b.onclick = () => got.push('property'); b.click()
    got.join()""") == "1 false,stopped,property"
  # A script that throws in a listener doesn't stop the others
  js(l, "got = []; b.addEventListener('y', () => { throw new Error('bad listener') }); b.addEventListener('y', () => got.push('second')); b.dispatchEvent(new Event('y'))")
  @test js(l, "got.join()") == "second" && any(t -> occursin("bad listener", t), lines(l, :error))
  close(l)
end

@testset "a script asks where things are" begin
  l = running("""<!DOCTYPE html><body style="margin: 0"><div id=a style="width: 120px; height: 40px; padding: 5px; margin: 10px 0 0 20px; border: 1px solid">a</div>
    <p id=p style="margin: 0">Some <span id=s>words</span> here</p><div id=gone style="display: none">x</div></body>"""; high=300)
  @test js(l, "JSON.stringify(document.getElementById('a').getBoundingClientRect())") == "{\"x\":20,\"y\":10,\"width\":132,\"height\":52,\"left\":20,\"top\":10,\"right\":152,\"bottom\":62}"
  @test js(l, "var a = document.getElementById('a'); [a.offsetWidth, a.offsetHeight, a.offsetLeft, a.offsetTop, a.clientWidth].join()") == "132,52,20,10,132"
  @test js(l, "var r = document.getElementById('s').getBoundingClientRect(), p = document.getElementById('p').getBoundingClientRect(); r.left > 20 && r.width > 20 && r.top >= p.top && r.bottom <= p.bottom && p.top === 62 && p.width === 400") == true
  @test js(l, "document.getElementById('gone').offsetWidth + document.getElementById('gone').getClientRects().length") == 0
  @test js(l, "[innerWidth, innerHeight, document.documentElement.clientWidth].join()") == "400,300,400"
  @test js(l, "document.elementFromPoint(30, 20).id + document.elementFromPoint(5, 70).id") == "ap"
  # The answer is of the page as it is when the script asks
  @test js(l, "a.style.width = '200px'; a.offsetWidth") == 212
  @test js(l, "var n = document.createElement('div'); n.style.height = '30px'; document.body.insertBefore(n, a); a.getBoundingClientRect().top") == 40
  # What the page's CSS gives
  @test js(l, "var c = getComputedStyle(a); [c.display, c.width, c.paddingLeft, c.borderTopWidth, c.getPropertyValue('margin-left'), getComputedStyle(document.getElementById('gone')).display].join()") == "block,200px,5px,1px,20px,none"
  @test js(l, "matchMedia('(max-width: 500px)').matches && !matchMedia('(min-width: 500px)').matches") == true
  # A page that's narrower now
  resize!(l, 200)
  @test js(l, "innerWidth + ' ' + document.getElementById('p').getBoundingClientRect().width") == "200 200"
  @test Live.page!(l).wide == 200
  close(l)
end

@testset "a script watches the page" begin
  l = running("<body><div id=d><p>a</p></div></body>")
  js(l, """var seen = [], d = document.getElementById('d')
    var o = new MutationObserver(records => { for (const r of records) seen.push(r.type + ' ' + (r.attributeName || '') + r.addedNodes.length + r.removedNodes.length + ' ' + r.oldValue) })
    o.observe(d, {childList: true, attributes: true, attributeOldValue: true, characterData: true, subtree: true})
    d.setAttribute('title', 'one'); d.setAttribute('title', 'two'); d.appendChild(document.createElement('i')); d.firstChild.remove(); d.lastChild.textContent = 'x'""")
  @test js(l, "seen.join('|')") == "attributes title00 null|attributes title00 one|childList 10 null|childList 01 null|childList 10 null"
  js(l, "o.disconnect(); d.setAttribute('title', 'three')")
  @test js(l, "seen.length") == 5
  close(l)
end

@testset "elements that a page defines" begin
  l = running("<body><x-count id=a start=2>old</x-count><p id=p>para</p></body>")
  js(l, """var heard = []
    class Count extends HTMLElement {
      static observedAttributes = ['start']
      constructor() { super(); heard.push('made ' + this.id) }
      connectedCallback() { heard.push('in ' + this.id); this.textContent = 'count ' + this.getAttribute('start') }
      disconnectedCallback() { heard.push('out ' + this.id) }
      attributeChangedCallback(name, old, value) { heard.push(name + ' ' + old + '>' + value) }
      bump() { return 'bumped' }
    }
    var waited = ''; customElements.whenDefined('x-count').then(C => { waited = C.name })
    customElements.define('x-count', Count)""")
  # The element in the page becomes one of the class: it's made, told of its attributes, and told that it's in the page
  @test js(l, "heard.join('|')") == "made a|start null>2|in a"
  @test js(l, "(document.getElementById('a') instanceof Count) + document.getElementById('a').bump()") == "truebumped"
  @test js(l, "waited + (customElements.get('x-count') === Count) + customElements.getName(Count)") == "Counttruex-count"
  @test occursin("count 2", join(w.before * String(w.letters) for w in Live.page!(l).words))
  # Only an attribute that it watches is told of
  @test js(l, "heard = []; document.getElementById('a').setAttribute('start', '5'); document.getElementById('a').setAttribute('other', '1'); heard.join('|')") == "start 2>5"
  # One made by createElement, by `new` and by innerHTML, one taken out, and one moved
  @test js(l, """heard = []; var b = document.createElement('x-count'); b.id = 'b'; document.body.appendChild(b)
    var c = new Count(); c.id = 'c'; document.body.appendChild(c)
    document.getElementById('p').innerHTML = '<x-count id=d start=1></x-count>'
    b.remove(); document.body.appendChild(document.getElementById('a')); heard.join('|')""") == "made |in b|made |in c|made d|start null>1|in d|out b|out a|in a"
  @test js(l, "try { customElements.define('bad', class extends HTMLElement {}) } catch (e) { e.name }") == "SyntaxError"
  @test js(l, "try { new (class extends HTMLElement {})() } catch (e) { e.name + ': ' + e.message }") == "TypeError: Illegal constructor"
  # A shadow tree holds what a script puts in it, and isn't drawn
  @test js(l, "var s = document.body.attachShadow({mode: 'open'}); s.innerHTML = '<i>hidden</i>'; '' + (s.host === document.body) + (document.body.shadowRoot === s) + s.querySelector('i').textContent + document.querySelectorAll('i').length") == "truetruehidden0"
  @test !occursin("hidden", join(w.before * String(w.letters) for w in Live.page!(l).words))
  close(l)
end

@testset "sheets that a script makes" begin
  l = running("<body><p id=p>para <b id=b>bold</b></p></body>")
  colour(id) = js(l, "getComputedStyle(document.getElementById('$id')).color")
  js(l, "var sheet = new CSSStyleSheet(); sheet.replaceSync('p { color: rgb(255, 0, 0) } /* a note */ @media (width > 1px) { b { color: rgb(0, 0, 255) } } @import url(x.css);'); document.adoptedStyleSheets = [sheet]")
  @test js(l, "sheet.cssRules.length + ' ' + sheet.cssRules[0].selectorText") == "2 p" && colour("p") == "rgb(255, 0, 0)" && colour("b") == "rgb(0, 0, 255)"
  # A sheet that's added to the list, and a rule that's taken out
  js(l, "var two = new CSSStyleSheet(); two.replaceSync('p { color: rgb(0, 128, 0) }'); document.adoptedStyleSheets.push(two)")
  @test colour("p") == "rgb(0, 128, 0)"
  js(l, "sheet.insertRule('i { color: green }', 1); sheet.deleteRule(0); two.replaceSync('')")
  @test js(l, "sheet.cssRules.map(r => r.cssText).join(' ; ')") == "i { color: green } ; @media (width > 1px) { b { color: rgb(0, 0, 255) } }" && colour("p") == "rgb(0, 0, 0)"
  @test js(l, "try { sheet.insertRule('not a rule') } catch (e) { e.name }") == "SyntaxError"
  close(l)
end

@testset "nodes that no script holds" begin
  l = running("<body><div id=keep></div></body>")
  s = l.scripts
  js(l, "var keep = document.getElementById('keep'); keep.mine = 'still here'; var held = document.createElement('b')")
  js(l, "for (let i = 0; i < 500; i++) { const e = document.createElement('i'); document.body.appendChild(e); e.remove() }")
  @test length(s.nodes) > 500
  # JavaScriptCore frees what no script can reach when it chooses. This asks it to do so now, which its public headers don't offer.
  now = Base.Libc.Libdl.dlsym(Base.Libc.Libdl.dlopen(JS.LIB), :JSSynchronousGarbageCollectForDebugging; throw_error=false)
  if now !== nothing
    ccall(now, Cvoid, (Ptr{Cvoid},), s.js.ref)
    Script.sweep!(s)
    @test length(s.nodes) < 50
    # What a script still holds, and what's in the page, is kept, with what the script put on it
    @test js(l, "held.tagName + keep.mine + document.getElementById('keep').mine + (document.getElementById('keep') === keep)") == "Bstill herestill heretrue"
    js(l, "keep = null")
    ccall(now, Cvoid, (Ptr{Cvoid},), s.js.ref)
    Script.sweep!(s)
    @test js(l, "document.getElementById('keep').mine") == "still here"
  end
  close(l)
end

@testset "what else a browser has" begin
  l = running("<body><form id=f><input name=q value=hi><select id=sel><option value=a>A<option value=b selected>B</select><textarea id=ta>text</textarea></form><template id=t><p>in a template</p></template></body>")
  @test js(l, "atob(btoa('héllo'.normalize('NFC').replace('é', 'e'))) + btoa('ab')") == "helloYWI="
  # Text as UTF-8 bytes and back. A byte that can't be read is U+FFFD, and a letter cut in two waits for its other bytes.
  @test js(l, "var bytes = new TextEncoder().encode('héllo 😀'); bytes.length + ' ' + new TextDecoder().decode(bytes) + ' ' + new TextDecoder().decode(new Uint8Array([0xff, 0x61]))") == "11 héllo 😀 �a"
  @test js(l, "var d = new TextDecoder(); d.decode(new Uint8Array([0xe2, 0x82]), {stream: true}) + d.decode(new Uint8Array([0xac])) + new TextDecoder('windows-1252').decode(new Uint8Array([0x80, 0x41])) + new TextDecoder().decode(new Uint8Array([0xef, 0xbb, 0xbf, 0x42]))") == "€€AB"
  @test js(l, "JSON.stringify(new TextEncoder().encodeInto('aé€', new Uint8Array(3))) + Array.from(new TextEncoder().encode('\\ud800x')).join(',')") == "{\"read\":2,\"written\":3}239,191,189,120"
  @test js(l, "new Request('https://a.org/x', {method: 'post'}).method + ' ' + new Request(new Request('https://a.org/y')).url") == "POST https://a.org/y"
  @test js(l, "localStorage.setItem('k', 5); localStorage.getItem('k') + localStorage.length + sessionStorage.getItem('k')") == "51null"
  @test js(l, "var u = new Uint8Array(8); crypto.getRandomValues(u); crypto.randomUUID().length + (u.some(x => x > 0) ? ' filled' : '')") == "36 filled"
  @test js(l, "var q = document.querySelector('input'); q.value + q.form.id + q.type + document.getElementById('sel').value + document.getElementById('sel').selectedIndex + document.getElementById('ta').value") == "hiftextb1text"
  @test js(l, "q.value = 'changed'; document.getElementById('sel').value = 'a'; document.forms[0].elements.length") == 3
  @test js(l, "q.getAttribute('value') + document.getElementById('sel').selectedOptions[0].text") == "changedA"
  @test js(l, "var t = document.getElementById('t'); var c = t.content.cloneNode(true); document.body.appendChild(c); document.body.lastChild.textContent + t.content.childNodes.length + t.content.isConnected") == "in a template1false"
  @test js(l, "var w = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT), n = 0; while (w.nextNode()) n++; n") == 4
  # What's in a <template> is no part of the page
  @test js(l, "document.querySelectorAll('p').length + ' ' + t.childNodes.length + ' ' + t.innerHTML + ' ' + t.content.firstChild.tagName + ' ' + t.cloneNode(true).content.textContent") == "1 0 <p>in a template</p> P in a template"
  @test js(l, "var d = document.createElement('div'); d.innerHTML = '<template><b>x</b></template>'; d.firstChild.content.childNodes.length + d.innerHTML + d.querySelectorAll('b').length") == "1<template><b>x</b></template>0"
  @test js(l, "var spare = document.implementation.createHTMLDocument('t'); spare.body.innerHTML = '<form></form><form></form>'; spare.body.childNodes.length + spare.title + (spare.body.ownerDocument === document)") == "2ttrue"
  @test js(l, "new URLSearchParams('a=1&b=two%20words').get('b') + new URLSearchParams({x: 1}).toString() + CSS.escape('a.b')") == "two wordsx=1a\\.b"
  @test js(l, "typeof XMLHttpRequest + typeof AbortController + typeof IntersectionObserver + navigator.userAgent.includes('AppleWebKit') + (window === self && window === globalThis)") == "functionfunctionfunctiontruetrue"
  @test js(l, "document.createRange().createContextualFragment('<i>x</i><b>y</b>').childNodes.length") == 2
  @test js(l, "var img = new Image(); img.src = 'a.png'; img.tagName + img.getAttribute('src')") == "IMGa.png"
  # A frame's address is its tag's `src`, and a frame has no window of its own here
  @test js(l, "var f = document.createElement('iframe'); f.src = 'https://example.com/a'; f.width = 300; f.getAttribute('src') + ' ' + f.getAttribute('width') + ' ' + f.contentWindow") == "https://example.com/a 300 null"
  close(l)
end
