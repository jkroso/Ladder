// Makes pictures of a page of HTML, as WebKit draws it. WebKit is the part of
// macOS that draws web pages, and macOS only offers it to Swift and
// Objective-C, so this is a program of its own, and Ladder runs it. Ladder
// shows an email as it was sent with it. See webpage.jl.
//
//     webpage 700 email.html shots/ab12 shots/ab12.txt
//     webpage --pictures --zoom 1.25 700 email.html shots/ab12 shots/ab12.txt
//
// The arguments are how wide the page is in px, the file of HTML, the start of
// the name of each picture, and the text file to write last. The page is as
// tall as its content. When the content is wider than the page, a width that
// the HTML gives a table or a cell, wider than the page, is taken away, and a
// picture or a block of code shrinks to the page. A page whose content still
// can't be as narrow as that is as wide as its content, up to 2000 px, and
// Ladder shows it smaller.
//
// A tall page makes a picture that's too big to draw in one piece, so the
// program writes it as strips, each 1024 px tall or less, from the top down:
// shots/ab12-1.png, shots/ab12-2.png and so on. Each file has two pixels to
// the px, so the picture is sharp on a Retina screen.
//
// The text file says what was made, with a tab between each two things of a
// line:
//
//     page   700  1310                       how wide and how tall the whole page is, in px
//     strip  1024 ab12-1.png                 how tall each strip is, and its file
//     strip  286  ab12-2.png
//     link   158  493  384  33  https://…    a rectangle of the page that's a link: left, top, wide, tall, and where it goes
//     text   line 493  18   158,166.2,…  Hi  a line of the page's words: see below
//
// The page's words come last, in the order that the HTML has them, so that
// Ladder can let you select them and copy them. Each `text` line is a piece of
// text that's drawn in one line of the page. Its things are:
//
// - what goes between it and the text before it when it's copied: `line` for
//   a new line, `tab` between two cells of a row of a table, or `-` for
//   nothing, as between two lines of a paragraph that wraps
// - how far down the page its top is, and how tall it is
// - where each of its letters starts, and after them where the last one ends,
//   in px from the left of the page, with a comma between each two
// - its letters
//
// The page runs no JavaScript, and it goes nowhere: a page that asks to show
// another page in its place is refused. Without --pictures, the program asks
// the web for nothing at all, so a picture that the page has from a web site
// is an empty box, and the sender of an email can't tell that it was opened.
// With --pictures, it asks the web for the page's pictures, fonts and style
// sheets, and for nothing else.
//
// --zoom makes everything in the page that much bigger, as a browser's zoom
// does. The page is still as wide as it was asked to be.
//
// If it can't make the pictures, it prints "error: " and why on stderr, and
// exits with 1.

import AppKit
import Foundation
import WebKit

/// How many px tall a strip is at most
let stripTall = 1024.0
/// How many px wide and tall a page is at most
let widest = 2000.0, tallest = 60000.0
/// How many pixels of a file go to a px of the page
let scale = 2.0
/// How many seconds the page gets to load before the pictures are made of what's there
let patience = 15.0

func say(_ line: String) { FileHandle.standardError.write((line + "\n").data(using: .utf8)!) }
func fail(_ why: String) -> Never { say("error: " + why); exit(1) }

/// What the page asks the web for is stopped here: everything, or with pictures everything but pictures, fonts and style sheets
func rules(pictures: Bool) -> String {
  let kinds = ["document", "script", "raw", "svg-document", "media", "popup", "ping", "fetch", "websocket", "other"]
  let only = pictures ? ", \"resource-type\": [" + kinds.map { "\"\($0)\"" }.joined(separator: ", ") + "]" : ""
  return ["^https?:", "^wss?:", "^ftp:"].map { "{\"trigger\": {\"url-filter\": \"\($0)\"\(only)}, \"action\": {\"type\": \"block\"}}" }
    .joined(separator: ", ").withBrackets
}
extension String { var withBrackets: String { "[" + self + "]" } }

/// The size of the page's content, and each rectangle of each link, in the px of the page before it's zoomed
let measure = """
(() => {
  const d = document.documentElement, b = document.body || d
  const links = []
  for (const a of document.links) {
    if (!/^(https?|mailto|tel):/i.test(a.href)) continue
    for (const r of a.getClientRects()) if (r.width > 0 && r.height > 0) links.push([r.left + scrollX, r.top + scrollY, r.width, r.height, a.href])
  }
  return JSON.stringify({wide: Math.max(d.scrollWidth, b.scrollWidth), tall: Math.max(d.scrollHeight, b.scrollHeight), links: links})
})()
"""

/// Let a part of the page that has a width of its own, wider than the page, be as narrow as the page: a table, a cell
/// of one, a picture or a block of code. Outlook gives the table round an email the width of its sender's window,
/// which can be 2000 px. The JavaScript is the program's own. The page's own JavaScript doesn't run.
let fit = """
(() => {
  const page = innerWidth
  const s = document.createElement('style')
  s.textContent = `
    table { max-width: 100% !important; }
    img, video { max-width: 100% !important; }
    img[width][height] { height: auto !important; }
    pre { white-space: pre-wrap !important; }
    body { overflow-wrap: break-word !important; }`
  ;(document.head || document.documentElement).appendChild(s)
  // A cell's width holds its table wide, so a width that the HTML gives, wider than the page, is taken away. Pictures keep theirs, for their shape.
  const wide = []
  for (const el of document.querySelectorAll('[width], [style*="width" i]')) {
    if (el.tagName == 'IMG' || el.tagName == 'VIDEO') continue
    const said = el.getAttribute('width') || ''
    if ((!said.includes('%') && parseFloat(said) > page) ||
        (/(^|[^-])width/i.test(el.getAttribute('style') || '') && el.getBoundingClientRect().width > page + 1)) wide.push(el)
  }
  for (const el of wide) {
    el.removeAttribute('width')
    el.style.setProperty('width', el.tagName == 'TABLE' ? '100%' : 'auto', 'important')
    el.style.setProperty('min-width', '0', 'important')
  }
  return wide.length
})()
"""

/// The words of the page, in the order that the HTML has them, with where each letter is, so that Ladder can let
/// you select them. Each piece of text, in each line that it's drawn in, is a `text` line of the text file: see the
/// top of this file. Where each letter is, is in the px of the page after it's zoomed, so the script is given the zoom.
/// Text that doesn't show isn't there: text that's hidden, see-through, or cut off by a box round it, as the line
/// of an email that only shows in a list of emails often is.
func reading(zoom: Double) -> String { """
(() => {
  const z = \(zoom), most = 300000
  const root = document.body || document.documentElement
  const styles = new Map(), clips = new Map(), seen = new Map()
  const css = el => { let s = styles.get(el); if (!s) styles.set(el, s = getComputedStyle(el)); return s }
  // The part of the page that an element's text shows in: inside each box round it that cuts off what overflows
  const clip = el => {
    if (!el || el === document.documentElement) return null
    if (clips.has(el)) return clips.get(el)
    let c = clip(el.parentElement)
    const s = css(el)
    if (s.overflowX != 'visible' || s.overflowY != 'visible') {
      const r = el.getBoundingClientRect()
      c = c ? {l: Math.max(c.l, r.left), t: Math.max(c.t, r.top), r: Math.min(c.r, r.right), b: Math.min(c.b, r.bottom)}
            : {l: r.left, t: r.top, r: r.right, b: r.bottom}
    }
    clips.set(el, c)
    return c
  }
  const shows = el => {
    if (!seen.has(el)) seen.set(el, !el.checkVisibility || el.checkVisibility({opacityProperty: true, visibilityProperty: true}))
    return seen.get(el)
  }
  const inline = d => d.startsWith('inline') || d == 'contents' || d.startsWith('ruby')
  const block = el => { while (el && el !== root && inline(css(el).display)) el = el.parentElement; return el || root }
  const cell = el => el && el.closest ? el.closest('td, th') : null
  // What keeps its spaces: 'preserve', 'preserve-breaks' for new lines only, or 'collapse' for neither
  const keeps = s => s.whiteSpaceCollapse ||
    ({pre: 'preserve', 'pre-wrap': 'preserve', 'break-spaces': 'preserve', 'pre-line': 'preserve-breaks'}[s.whiteSpace] || 'collapse')
  const n = x => String(Math.round(x * z * 10) / 10)
  const lines = []
  // The line of text that's being read, the last letter read, and where it was
  let run = null, last = '', lastText = null, lastBlock = null, broke = false, count = 0
  const end = () => {
    if (run) lines.push(['text', run.before, n(run.top + scrollY), n(run.bottom - run.top), run.edges.map(x => n(x + scrollX)).join(','), run.text].join('\\t'))
    run = null
  }
  const range = document.createRange()
  const walk = document.createTreeWalker(root, NodeFilter.SHOW_TEXT | NodeFilter.SHOW_ELEMENT)
  for (let node = walk.currentNode; node && count < most; node = walk.nextNode()) {
    if (node.nodeType == 1) { if (node.tagName == 'BR') broke = true; continue }
    const el = node.parentElement
    if (!el || !node.data || !shows(el)) continue
    const keep = keeps(css(el)), box = clip(el), b = block(el)
    // What goes before the next letter that shows: a new line, a tab between two cells of a row, or nothing ('-')
    let next = '-'
    if (lastText && (broke || b !== lastBlock)) {
      const c1 = cell(lastText.parentElement), c2 = cell(el)
      next = !broke && c1 && c2 && c1 !== c2 && c1.parentElement === c2.parentElement ? 'tab' : 'line'
    }
    let at = 0
    for (const ch of node.data) {
      const i = at
      at += ch.length
      // A new line that the HTML keeps starts a line of text
      if (ch == '\\n' && keep != 'collapse') { if (lastText) { broke = true; next = 'line' } continue }
      const space = /[ \\t\\n\\r\\f]/.test(ch)
      // Spaces that HTML draws as one are one, and there are none at the start of a line
      if (space && keep != 'preserve' && (last == '' || last == ' ' || next != '-')) continue
      range.setStart(node, i)
      range.setEnd(node, at)
      const r = range.getBoundingClientRect()
      const drawn = r.width > 0 || r.height > 0
      if (!drawn) {
        // A space where a line wraps isn't drawn. It goes at the end of the line before, as wide as nothing.
        if (space && run && next == '-') { run.edges.push(run.edges[run.edges.length - 1]); run.text += ' '; last = ' '; count++ }
        continue
      }
      const x = (r.left + r.right) / 2, y = (r.top + r.bottom) / 2
      if (!space && box && (x < box.l || x > box.r || y < box.t || y > box.b)) continue
      const right = run ? run.edges[run.edges.length - 1] : 0
      if (run && (next != '-' || r.top >= run.bottom - 1 || r.bottom <= run.top + 1 || r.left < right - 1)) end()
      if (run) run.edges[run.edges.length - 1] = Math.min(right, r.left)
      else run = {before: next, top: r.top, bottom: r.bottom, edges: [r.left], text: ''}
      run.top = Math.min(run.top, r.top)
      run.bottom = Math.max(run.bottom, r.bottom)
      run.edges.push(r.right)
      run.text += space ? ' ' : ch.replace(/[\\t\\r]/g, ' ')
      last = space ? ' ' : ch
      lastText = node, lastBlock = b, broke = false, next = '-'
      count++
    }
  }
  end()
  return lines.join('\\n')
})()
"""
}

final class Painter: NSObject, WKNavigationDelegate {
  let web: WKWebView
  let wide: Double, zoom: Double
  let stem: String, out: String
  var started = false, shooting = false
  var lines: [String] = []   // what the text file says, as far as it's known

  init(web: WKWebView, wide: Double, zoom: Double, stem: String, out: String) {
    self.web = web; self.wide = wide; self.zoom = zoom; self.stem = stem; self.out = out
  }

  // The page that the program loads is the only one. A link, a form or a page that asks for another goes nowhere.
  func webView(_ w: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    let first = !started && action.targetFrame?.isMainFrame == true
    if first { started = true }
    decisionHandler(first ? .allow : .cancel)
  }

  func webView(_ w: WKWebView, didFinish n: WKNavigation!) { shoot() }
  func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { fail(e.localizedDescription) }
  func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { fail(e.localizedDescription) }
  func webViewWebContentProcessDidTerminate(_ w: WKWebView) { fail("WebKit stopped.") }

  /// Ask the page a question in JavaScript, and get its answer as JSON
  func ask(_ then: @escaping ([String: Any]) -> Void) {
    web.evaluateJavaScript(measure) { value, error in
      guard let text = value as? String, let data = text.data(using: .utf8),
            let found = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        fail(error?.localizedDescription ?? "The page can't be measured.")
      }
      then(found)
    }
  }

  /// How wide the content is, in the px of the page after it's zoomed
  func needs(_ found: [String: Any]) -> Double { min(widest, ((found["wide"] as? Double) ?? wide) * zoom) }

  /// Make the pictures: give the page the room that its content needs, then take a picture of each strip of it
  func shoot() {
    guard !shooting else { return }
    shooting = true
    ask { first in
      guard self.needs(first) > self.wide + 1 else { return self.size(first) }
      // Content that's wider than the page is first let shrink to it, and then it's measured again
      self.web.evaluateJavaScript(fit) { _, _ in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.ask { self.size($0) } }
      }
    }
  }

  /// Give the page the room that its content needs, then take a picture of each strip of it
  func size(_ first: [String: Any]) {
    // Content that can't be as narrow as the page makes the page wider, and then it's measured again
    let needs = self.needs(first)
    let across = needs > self.wide + 1 ? needs.rounded(.up) : self.wide
    // A page is never shorter than its window, so it's measured in a window 1 px tall. A short page is then as tall as its content.
    self.web.frame = NSRect(x: 0, y: 0, width: across, height: 1)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
      self.ask { found in
        let tall = min(tallest, max(1, (((found["tall"] as? Double) ?? 600) * self.zoom).rounded(.up)))
        self.web.frame = NSRect(x: 0, y: 0, width: across, height: tall)
        self.lines = ["page\t\(Int(across))\t\(Int(tall))"]
        let links = (found["links"] as? [[Any]] ?? []).compactMap { link -> String? in
          guard link.count == 5, let url = link[4] as? String, !url.contains("\t"), !url.contains("\n") else { return nil }
          let box = link[0..<4].compactMap { ($0 as? Double).map { String(format: "%.1f", $0 * self.zoom) } }
          return box.count == 4 ? "link\t" + box.joined(separator: "\t") + "\t" + url : nil
        }
        // The page gets a moment to lay itself out in its new room. Then its words are read, where they are in it.
        // A page whose words can't be read is still drawn: its words can't be selected then.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          self.web.evaluateJavaScript(reading(zoom: self.zoom)) { value, _ in
            let words = ((value as? String) ?? "").split(separator: "\n").map(String.init)
            self.strip(1, from: 0, across: across, tall: tall, links: links + words)
          }
        }
      }
    }
  }

  /// Take the picture of the strip that starts `from` px down the page, then of the ones under it, then write the text file
  func strip(_ n: Int, from: Double, across: Double, tall: Double, links: [String]) {
    if from >= tall {
      let text = (lines + links).joined(separator: "\n") + "\n"
      do { try text.write(toFile: out, atomically: true, encoding: .utf8) } catch { fail(error.localizedDescription) }
      exit(0)
    }
    let high = min(stripTall, tall - from)
    let config = WKSnapshotConfiguration()
    config.rect = CGRect(x: 0, y: from, width: across, height: high)
    // The picture has `scale` pixels to the px, whatever screen the Mac has
    config.snapshotWidth = NSNumber(value: across * scale / (NSScreen.main?.backingScaleFactor ?? 1))
    web.takeSnapshot(with: config) { image, error in
      guard let image, let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
            let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else {
        fail(error?.localizedDescription ?? "The picture can't be made.")
      }
      let file = "\(self.stem)-\(n).png"
      do { try png.write(to: URL(fileURLWithPath: file)) } catch { fail(error.localizedDescription) }
      self.lines.append("strip\t\(Int(high))\t\((file as NSString).lastPathComponent)")
      self.strip(n + 1, from: from + high, across: across, tall: tall, links: links)
    }
  }
}

@main
struct Webpage {
  static func main() {
    var args = Array(CommandLine.arguments.dropFirst())
    var pictures = false, zoom = 1.0
    while let flag = args.first, flag.hasPrefix("--") {
      args.removeFirst()
      if flag == "--pictures" { pictures = true }
      else if flag == "--zoom", let z = args.first.flatMap(Double.init), z > 0 { zoom = z; args.removeFirst() }
      else { fail("The program doesn't know \(flag).") }
    }
    guard args.count == 4, let wide = Double(args[0]), wide >= 1, wide <= widest else {
      fail("usage: webpage [--pictures] [--zoom 1.25] <wide> <html file> <start of each picture's name> <text file>")
    }
    guard let html = try? String(contentsOfFile: args[1], encoding: .utf8) else { fail("\(args[1]) can't be read.") }

    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)   // no icon in the Dock, and no window
    let config = WKWebViewConfiguration()
    config.websiteDataStore = .nonPersistent()   // no cookie is kept, and none is sent
    config.defaultWebpagePreferences.allowsContentJavaScript = false
    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: wide, height: 600), configuration: config)
    web.appearance = NSAppearance(named: .aqua)   // an email is written for a white page, so it's drawn on one
    web.pageZoom = zoom
    let painter = Painter(web: web, wide: wide, zoom: zoom, stem: args[2], out: args[3])
    web.navigationDelegate = painter
    WKContentRuleListStore.default().compileContentRuleList(forIdentifier: pictures ? "pictures" : "nothing",
                                                             encodedContentRuleList: rules(pictures: pictures)) { list, error in
      // Without the list, the page could ask the web for anything, so there's no picture then
      guard let list else { fail(error?.localizedDescription ?? "The web can't be shut out.") }
      config.userContentController.add(list)
      web.configuration.userContentController.add(list)
      web.loadHTMLString(html, baseURL: nil)
    }
    // A picture that a web site is slow to send doesn't hold the page up for ever
    DispatchQueue.main.asyncAfter(deadline: .now() + patience) { web.stopLoading(); painter.shoot() }
    DispatchQueue.main.asyncAfter(deadline: .now() + 2 * patience) { fail("The page took too long.") }
    withExtendedLifetime(painter) { app.run() }
  }
}
