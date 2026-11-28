// Holds pages of a web site in WebKit with nothing on the screen, signed in as
// you, and tells Ladder what the site sends them. WebKit is the part of macOS
// that draws web pages, and macOS only offers it to Swift and Objective-C, so
// this is a program of its own, and Ladder runs it. See hiddenpage.jl.
//
// A site like x.com gives its posts only to its own pages, in a browser that's
// signed in. So a viewer of Ladder's for such a site opens the site's real
// page here, where nobody sees it, and reads what the site sends that page.
//
//     hiddenpage x.com ~/Library/Caches/Ladder/hidden/x.com
//
// The arguments are the name of the store that keeps what the site keeps in a
// browser, like the cookie that says who you are, and a folder for the files
// that the program writes. One store is one browser: each site's viewer has a
// store of its own, so a site sees nothing of another's. A store's name that
// starts with `-` keeps nothing after the program ends, for a test.
//
// The program stays open. Ladder writes it one command on each line of its
// input, as JSON, and it ends when its input ends:
//
//     {"do": "open", "page": "home", "url": "https://x.com/home", "capture": "/i/api/"}
//     {"do": "run", "page": "home", "id": 7, "js": "return document.title"}
//     {"do": "close", "page": "home"}
//     {"do": "signin", "url": "https://x.com/i/flow/login", "cookie": "auth_token", "title": "Sign in to X"}
//     {"do": "signin", "url": "https://x.com/account/access", "cookie": "auth_token", "title": "X's check", "until": "^https://x\\.com/home"}
//     {"do": "signout"}
//     {"do": "signed", "cookie": "auth_token"}
//
// - `open` shows the address in the page of that name. A name that's new
//   makes a page. `capture` is a regular expression, in JavaScript's form:
//   each answer that the site sends the page's own code, from an address that
//   matches it, is passed on to Ladder. A page keeps the `capture` that it was
//   made with.
// - `run` runs JavaScript in the page, as the body of a function that can
//   `await`, and passes on what it returns.
// - `close` ends the page.
// - `signin` opens a window on the screen at the address, for you to sign in.
//   The window closes by itself when the store has the cookie of that name.
//   With `until`, a regular expression, it closes when its page's address
//   matches that instead: a site that's signed in can still put a page in
//   the way that only a person passes, like a check that you aren't a robot.
// - `signout` empties the store, so the site no longer knows you.
// - `signed` asks whether the store has the cookie.
//
// The program writes what happens on each line of its output, as JSON:
//
//     {"event": "loaded", "page": "home", "url": "https://x.com/home"}
//     {"event": "failed", "page": "home", "why": "The Internet connection appears to be offline."}
//     {"event": "data", "page": "home", "url": "https://x.com/i/api/…", "status": 200, "file": "…/hidden/x.com/12.json"}
//     {"event": "value", "page": "home", "id": 7, "value": "Home / X"}
//     {"event": "value", "page": "home", "id": 8, "error": "…"}
//     {"event": "signed", "in": true}
//     {"event": "signin", "open": false}
//
// `data` is an answer that matched `capture`. Its text is in the file, which
// Ladder deletes once it's read. `value` is what a `run` returned: text, a
// number, true or false, or what JSON.stringify makes of anything else.
//
// A page plays no sound and no video by itself. The site sees a browser like
// Safari. If the program can't start, it prints "error: " and why on stderr,
// and exits with 1.

import AppKit
import CryptoKit
import Foundation
import WebKit

func say(_ line: String) { FileHandle.standardError.write((line + "\n").data(using: .utf8)!) }
func fail(_ why: String) -> Never { say("error: " + why); exit(1) }

let output = FileHandle.standardOutput
let writing = NSLock()

/// Write what happened as one line of JSON
func emit(_ event: [String: Any]) {
  guard let data = try? JSONSerialization.data(withJSONObject: event) else { return }
  writing.lock()
  output.write(data)
  output.write(Data([0x0a]))
  writing.unlock()
}

/// How wide and how tall a page that's not on the screen is, in px: the room of a browser's window
let room = NSRect(x: 0, y: 0, width: 1100, height: 1400)

/// The code that passes on what the site sends the page's own code. It wraps the two ways that a page asks a
/// server, XMLHttpRequest and fetch, before any code of the page runs.
func capturing(_ pattern: String) -> String {
  let quoted = String(data: try! JSONSerialization.data(withJSONObject: [pattern]), encoding: .utf8)!
  return """
  (() => {
    const want = new RegExp(\(quoted)[0])
    const pass = (url, status, body) => { try { webkit.messageHandlers.ladder.postMessage({url: String(url), status: status, body: body}) } catch (e) {} }
    const open = XMLHttpRequest.prototype.open
    XMLHttpRequest.prototype.open = function (method, url) { this.__ladder = String(url); return open.apply(this, arguments) }
    const send = XMLHttpRequest.prototype.send
    XMLHttpRequest.prototype.send = function () {
      if (want.test(this.__ladder || '')) this.addEventListener('load', () => {
        try {
          const text = this.responseType == '' || this.responseType == 'text' ? this.responseText :
                       this.responseType == 'json' ? JSON.stringify(this.response) : null
          if (text != null) pass(this.__ladder, this.status, text)
        } catch (e) {}
      })
      return send.apply(this, arguments)
    }
    const get = window.fetch
    if (get) window.fetch = function (input, init) {
      const asked = get.apply(this, arguments)
      try {
        const url = typeof input == 'string' ? input : (input && input.url) || String(input)
        if (want.test(url)) asked.then(r => r.clone().text().then(t => pass(url, r.status, t))).catch(() => {})
      } catch (e) {}
      return asked
    }
  })()
  """
}

/// A page of the site: a web view in a window that's never on the screen
final class Page: NSObject, WKNavigationDelegate, WKScriptMessageHandler, WKUIDelegate {
  let name: String
  let web: WKWebView
  let window: NSWindow
  unowned let host: Host

  init(name: String, capture: String?, host: Host) {
    self.name = name
    self.host = host
    let config = host.configuration()
    let content = WKUserContentController()
    config.userContentController = content
    if let capture, !capture.isEmpty {
      content.addUserScript(WKUserScript(source: capturing(capture), injectionTime: .atDocumentStart, forMainFrameOnly: true))
    }
    web = WKWebView(frame: room, configuration: config)
    // The page is in a window, so that it's laid out and its timers run as they do in a browser. The window
    // shows nothing, and it never takes the mouse or the keyboard.
    window = NSWindow(contentRect: room, styleMask: [.borderless], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.ignoresMouseEvents = true
    window.hasShadow = false
    window.alphaValue = 0
    window.contentView = web
    super.init()
    content.add(self, name: "ladder")
    web.navigationDelegate = self
    web.uiDelegate = self
    window.collectionBehavior = [.stationary, .ignoresCycle, .canJoinAllSpaces]
    // WebKit stops the timers and the drawing of a page in a window that it finds nobody can see. Where it can be
    // told not to look, the window is past the edge of every screen. Else the window is on the screen, at the back,
    // and it shows nothing there.
    let looking = NSSelectorFromString("_setWindowOcclusionDetectionEnabled:")
    if web.responds(to: looking) {
      web.perform(looking, with: nil)
      window.setFrameOrigin(NSPoint(x: -20000, y: -20000))
    } else {
      window.setFrameOrigin(.zero)
    }
    window.orderBack(nil)
  }

  func open(_ address: String) {
    guard let url = URL(string: address), url.scheme == "https" || url.scheme == "http" else {
      return emit(["event": "failed", "page": name, "why": "\(address) isn't a web address."])
    }
    web.load(URLRequest(url: url))
  }

  func run(_ js: String, id: Any) {
    web.callAsyncJavaScript(js, arguments: [:], in: nil, in: .page) { result in
      switch result {
      case .success(let value):
        var event: [String: Any] = ["event": "value", "page": self.name, "id": id]
        if value is String || value is NSNumber { event["value"] = value }
        else if JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value) {
          event["value"] = String(data: data, encoding: .utf8)
        }
        emit(event)
      case .failure(let error):
        emit(["event": "value", "page": self.name, "id": id, "error": error.localizedDescription])
      }
    }
  }

  func close() {
    web.stopLoading()
    web.configuration.userContentController.removeAllScriptMessageHandlers()
    window.close()
  }

  func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let said = message.body as? [String: Any], let url = said["url"] as? String, let body = said["body"] as? String else { return }
    let whole = URL(string: url, relativeTo: web.url)?.absoluteString ?? url
    guard let file = host.keep(body) else { return }
    emit(["event": "data", "page": name, "url": whole, "status": (said["status"] as? Int) ?? 0, "file": file])
  }

  func webView(_ w: WKWebView, didFinish n: WKNavigation!) {
    w.setAllMediaPlaybackSuspended(true, completionHandler: nil)   // a page that nobody sees plays nothing
    emit(["event": "loaded", "page": name, "url": w.url?.absoluteString ?? ""])
  }
  func webView(_ w: WKWebView, didFail n: WKNavigation!, withError e: Error) { failed(e) }
  func webView(_ w: WKWebView, didFailProvisionalNavigation n: WKNavigation!, withError e: Error) { failed(e) }
  func webViewWebContentProcessDidTerminate(_ w: WKWebView) { emit(["event": "failed", "page": name, "why": "WebKit stopped."]) }
  func failed(_ e: Error) {
    // A page that's asked for while another loads cancels the first, which isn't a failure
    if (e as NSError).code != NSURLErrorCancelled { emit(["event": "failed", "page": name, "why": e.localizedDescription]) }
  }

  // A page that nobody sees opens no window of its own, and asks for nothing that needs an answer
  func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures f: WKWindowFeatures) -> WKWebView? { nil }
  func webView(_ w: WKWebView, runJavaScriptAlertPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler done: @escaping () -> Void) { done() }
  func webView(_ w: WKWebView, runJavaScriptConfirmPanelWithMessage m: String, initiatedByFrame f: WKFrameInfo, completionHandler done: @escaping (Bool) -> Void) { done(false) }
}

/// The window that you sign in to the site in. It closes when the store has the cookie that says who you are.
final class SignIn: NSObject, NSWindowDelegate, WKUIDelegate, WKNavigationDelegate {
  let window: NSWindow
  let web: WKWebView
  let cookie: String
  let until: NSRegularExpression?   // the window closes when its page's address matches this, and not when the cookie is there
  unowned let host: Host
  var popups: [NSWindow] = []
  var watch: Timer?

  init(url: URL, cookie: String, title: String, until: String?, host: Host) {
    self.cookie = cookie
    self.until = until.flatMap { try? NSRegularExpression(pattern: $0) }
    self.host = host
    let size = NSRect(x: 0, y: 0, width: 520, height: 760)
    web = WKWebView(frame: size, configuration: host.configuration())
    window = NSWindow(contentRect: size, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.title = title
    window.contentView = web
    super.init()
    window.delegate = self
    web.uiDelegate = self
    web.navigationDelegate = self
    window.center()
    web.load(URLRequest(url: url))
    NSApp.setActivationPolicy(.regular)   // a window that takes the keyboard needs the program to be a real app for now
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    emit(["event": "signin", "open": true])
    watch = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.look() }
  }

  /// Close the window once the store has the cookie, or once its page is at the address that it waits for
  func look() {
    if let until {
      let at = web.url?.absoluteString ?? ""
      guard until.firstMatch(in: at, range: NSRange(at.startIndex..., in: at)) != nil, watch != nil else { return }
      watch?.invalidate(); watch = nil
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.window.close() }
      return
    }
    host.has(cookie) { [weak self] yes in
      guard let self, yes, self.watch != nil else { return }
      // The site sets the cookie a moment before its page has all that it keeps of you
      self.watch?.invalidate(); self.watch = nil
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { self.window.close() }
    }
  }

  func windowWillClose(_ n: Notification) {
    guard (n.object as? NSWindow) === window else { return }
    watch?.invalidate(); watch = nil
    popups.forEach { $0.close() }
    web.stopLoading()
    NSApp.setActivationPolicy(.accessory)
    host.signedIn(cookie)
  }

  // A site can sign you in through another site's window, as "Sign in with Apple" does
  func webView(_ w: WKWebView, createWebViewWith c: WKWebViewConfiguration, for a: WKNavigationAction, windowFeatures f: WKWindowFeatures) -> WKWebView? {
    let size = NSRect(x: 0, y: 0, width: 520, height: 700)
    let more = WKWebView(frame: size, configuration: c)
    more.uiDelegate = self
    let pop = NSWindow(contentRect: size, styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
    pop.isReleasedWhenClosed = false
    pop.contentView = more
    pop.center()
    pop.makeKeyAndOrderFront(nil)
    popups.append(pop)
    return more
  }
  func webViewDidClose(_ w: WKWebView) { w.window?.close() }
}

/// The program: the store, the pages and the sign-in window
final class Host: NSObject {
  let store: WKWebsiteDataStore
  let folder: String
  var pages: [String: Page] = [:]
  var signin: SignIn?
  var count = 0

  init(store: WKWebsiteDataStore, folder: String) {
    self.store = store
    self.folder = folder
  }

  /// What every page of the store is made with
  func configuration() -> WKWebViewConfiguration {
    let config = WKWebViewConfiguration()
    config.websiteDataStore = store
    config.applicationNameForUserAgent = "Version/26.0 Safari/605.1.15"   // as Safari says it, so the site gives what it gives Safari
    config.mediaTypesRequiringUserActionForPlayback = .all
    config.suppressesIncrementalRendering = false
    return config
  }

  /// Keep `text` in a new file of the folder, and give the file
  func keep(_ text: String) -> String? {
    count += 1
    let file = (folder as NSString).appendingPathComponent("\(ProcessInfo.processInfo.processIdentifier)-\(count).json")
    do { try text.write(toFile: file, atomically: true, encoding: .utf8) } catch { return nil }
    return file
  }

  /// Whether the store has a cookie of that name
  func has(_ cookie: String, _ then: @escaping (Bool) -> Void) {
    store.httpCookieStore.getAllCookies { all in then(all.contains { $0.name == cookie && !$0.value.isEmpty }) }
  }

  func signedIn(_ cookie: String) {
    signin = nil
    emit(["event": "signin", "open": false])
    has(cookie) { emit(["event": "signed", "in": $0]) }
  }

  func handle(_ line: String) {
    guard let data = line.data(using: .utf8), let said = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let what = said["do"] as? String else { return }
    let name = (said["page"] as? String) ?? ""
    switch what {
    case "open":
      guard let url = said["url"] as? String, !name.isEmpty else { return }
      let page = pages[name] ?? Page(name: name, capture: said["capture"] as? String, host: self)
      pages[name] = page
      page.open(url)
    case "run":
      guard let js = said["js"] as? String, let id = said["id"] else { return }
      guard let page = pages[name] else { return emit(["event": "value", "page": name, "id": id, "error": "No page is called \(name)."]) }
      page.run(js, id: id)
    case "close":
      pages.removeValue(forKey: name)?.close()
    case "signin":
      guard let address = said["url"] as? String, let url = URL(string: address), let cookie = said["cookie"] as? String else { return }
      if let open = signin { open.window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
      signin = SignIn(url: url, cookie: cookie, title: (said["title"] as? String) ?? "Sign in", until: said["until"] as? String, host: self)
    case "signout":
      signin?.window.close()
      store.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) { emit(["event": "signed", "in": false]) }
    case "signed":
      guard let cookie = said["cookie"] as? String else { return }
      has(cookie) { emit(["event": "signed", "in": $0]) }
    default:
      break
    }
  }
}

/// The store of that name. One name is always the same store, in every run of the program.
func store(named name: String) -> WKWebsiteDataStore {
  if name.hasPrefix("-") { return .nonPersistent() }
  var bytes = Array(SHA256.hash(data: Data(("ladder hidden page " + name).utf8)).prefix(16))
  bytes[6] = (bytes[6] & 0x0f) | 0x50   // the form of a UUID that's made from a name
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  let id = UUID(uuid: (bytes[0], bytes[1], bytes[2], bytes[3], bytes[4], bytes[5], bytes[6], bytes[7],
                       bytes[8], bytes[9], bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]))
  return WKWebsiteDataStore(forIdentifier: id)
}

@main
struct HiddenPage {
  static func main() {
    let args = Array(CommandLine.arguments.dropFirst())
    guard args.count == 2, !args[0].isEmpty else { fail("usage: hiddenpage <store's name> <folder for its files>") }
    do { try FileManager.default.createDirectory(atPath: args[1], withIntermediateDirectories: true) } catch { fail(error.localizedDescription) }

    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)   // no icon in the Dock
    let host = Host(store: store(named: args[0]), folder: args[1])
    // The commands are read on a thread of their own, and each is done on the main thread, where WebKit works
    Thread.detachNewThread {
      while let line = readLine(strippingNewline: true) {
        DispatchQueue.main.async { host.handle(line) }
      }
      DispatchQueue.main.async { exit(0) }   // Ladder closed, or it ended the program
    }
    withExtendedLifetime(host) { app.run() }
  }
}
