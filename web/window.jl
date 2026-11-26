# What a script sees of a browser: `window`, `document`, the elements, events
# and timers. It's written in JavaScript, since most of it is what JavaScript
# says of an object: its class, its getters, what `instanceof` gives.
#
# script.jl runs `WINDOW` once in each page's context. It's one function, which
# takes `native`: the Julia functions of script.jl that read and change the
# page's tree. A node is a number there. Here, `wrap(number)` gives the object
# that a script holds for it, and always the same object for the same node.
#
# The function gives back what Julia calls later: `tick` runs the timers that
# are due, `click` and `fire` send an event, `ready` says that the page is
# read, `script` says which <script> is running, `rejected` logs a promise
# that failed with no script to take it, and `alive` lists the nodes that some
# script still holds.
#
# An object lives for as long as its node is in a tree that a script can reach:
# each object keeps the objects of its node's children. So what a script puts
# on an element (a listener, a property of its own) is there when the script
# finds the element again.

const WINDOW = raw"""
(function (native) {
'use strict'

const ID = Symbol('id'), KIDS = Symbol('kids'), LISTENERS = Symbol('listeners'), HANDLERS = Symbol('handlers')
const STOP = Symbol('stop'), PATH = Symbol('path'), NOTE = Symbol('note')
const ROOT = native.root()
const global = globalThis
const wrappers = new Map()      // the object of each node that a script has met, by the node's number
const classes = Object.create(null)   // the class of the objects of each tag
const observers = new Set()     // the MutationObservers that watch something
// The elements that the page defines with customElements.define: each name's class and the attributes that it watches
const defined = new Map(), NAMES = new Map()
const MADE = Symbol('made'), INSIDE = Symbol('inside'), SHADOW = Symbol('shadow')
let upgrading = null            // the element that a defined class is being made for, while it's made
let document = null

const microtask = typeof global.queueMicrotask === 'function' ? global.queueMicrotask.bind(global) : f => { Promise.resolve().then(f) }

function report(e) {
  let text
  try { text = e instanceof Error ? (e.stack ? `${e.name}: ${e.message}\n${e.stack}` : `${e.name}: ${e.message}`) : 'Uncaught ' + String(e) }
  catch (_) { text = 'Uncaught error' }
  native.log('error', text)
}

class DOMException extends Error {
  constructor(message = '', name = 'Error') { super(message); this.name = name }
}
const wrong = (name, message) => new DOMException(message, name)

// --- events -------------------------------------------------------------------------------

class Event {
  constructor(type, init = {}) {
    this.type = String(type)
    this.bubbles = !!init.bubbles
    this.cancelable = !!init.cancelable
    this.composed = !!init.composed
    this.defaultPrevented = false
    this.target = null
    this.currentTarget = null
    this.eventPhase = 0
    this.isTrusted = false
    this.timeStamp = native.now()
    this[STOP] = 0
  }
  preventDefault() { if (this.cancelable) this.defaultPrevented = true }
  stopPropagation() { this[STOP] |= 1 }
  stopImmediatePropagation() { this[STOP] |= 3 }
  composedPath() { return this[PATH] ? [...this[PATH]] : [] }
  initEvent(type, bubbles = false, cancelable = false) { this.type = String(type); this.bubbles = !!bubbles; this.cancelable = !!cancelable }
  get srcElement() { return this.target }
  get returnValue() { return !this.defaultPrevented }
  set returnValue(v) { if (v === false) this.preventDefault() }
  get cancelBubble() { return (this[STOP] & 1) !== 0 }
  set cancelBubble(v) { if (v) this.stopPropagation() }
}
Object.assign(Event, {NONE: 0, CAPTURING_PHASE: 1, AT_TARGET: 2, BUBBLING_PHASE: 3})

class CustomEvent extends Event {
  constructor(type, init = {}) { super(type, init); this.detail = init.detail ?? null }
  initCustomEvent(type, bubbles, cancelable, detail) { this.initEvent(type, bubbles, cancelable); this.detail = detail ?? null }
}
class UIEvent extends Event {
  constructor(type, init = {}) { super(type, init); this.view = init.view ?? global; this.detail = init.detail ?? 0 }
}
class MouseEvent extends UIEvent {
  constructor(type, init = {}) {
    super(type, init)
    for (const k of ['clientX', 'clientY', 'screenX', 'screenY', 'button', 'buttons', 'movementX', 'movementY']) this[k] = Number(init[k] ?? 0)
    for (const k of ['altKey', 'ctrlKey', 'metaKey', 'shiftKey']) this[k] = !!init[k]
    this.relatedTarget = init.relatedTarget ?? null
  }
  get pageX() { return this.clientX }
  get pageY() { return this.clientY + native.scroll() }
  get x() { return this.clientX }
  get y() { return this.clientY }
  get offsetX() { return this.target instanceof Element ? this.clientX - this.target.getBoundingClientRect().left : this.clientX }
  get offsetY() { return this.target instanceof Element ? this.clientY - this.target.getBoundingClientRect().top : this.clientY }
  getModifierState() { return false }
}
class PointerEvent extends MouseEvent {
  constructor(type, init = {}) { super(type, init); this.pointerId = init.pointerId ?? 1; this.pointerType = init.pointerType ?? 'mouse'; this.isPrimary = init.isPrimary ?? true }
}
class WheelEvent extends MouseEvent {
  constructor(type, init = {}) { super(type, init); for (const k of ['deltaX', 'deltaY', 'deltaZ', 'deltaMode']) this[k] = Number(init[k] ?? 0) }
}
Object.assign(WheelEvent, {DOM_DELTA_PIXEL: 0, DOM_DELTA_LINE: 1, DOM_DELTA_PAGE: 2})
class KeyboardEvent extends UIEvent {
  constructor(type, init = {}) {
    super(type, init)
    this.key = String(init.key ?? '')
    this.code = String(init.code ?? '')
    this.repeat = !!init.repeat
    this.keyCode = this.which = Number(init.keyCode ?? 0)
    for (const k of ['altKey', 'ctrlKey', 'metaKey', 'shiftKey']) this[k] = !!init[k]
  }
  getModifierState() { return false }
}
class FocusEvent extends UIEvent {
  constructor(type, init = {}) { super(type, init); this.relatedTarget = init.relatedTarget ?? null }
}
class InputEvent extends UIEvent {
  constructor(type, init = {}) { super(type, init); this.data = init.data ?? null; this.inputType = init.inputType ?? '' }
}
class ErrorEvent extends Event {
  constructor(type, init = {}) { super(type, init); this.message = init.message ?? ''; this.error = init.error ?? null; this.filename = init.filename ?? ''; this.lineno = init.lineno ?? 0; this.colno = init.colno ?? 0 }
}

// The names that a handler can have as a property (`el.onclick = f`) or in a tag (`<a onclick="...">`)
const HANDLED = ['abort', 'blur', 'change', 'click', 'contextmenu', 'dblclick', 'error', 'focus', 'focusin', 'focusout', 'input', 'keydown', 'keypress',
  'keyup', 'load', 'mousedown', 'mouseenter', 'mouseleave', 'mousemove', 'mouseout', 'mouseover', 'mouseup', 'pointerdown', 'pointermove', 'pointerup',
  'readystatechange', 'reset', 'resize', 'scroll', 'select', 'submit', 'toggle', 'touchend', 'touchmove', 'touchstart', 'transitionend', 'animationend',
  'wheel', 'DOMContentLoaded', 'hashchange', 'popstate', 'unload', 'beforeunload', 'message', 'visibilitychange', 'pointerlockchange', 'pointerlockerror']

class EventTarget {
  addEventListener(type, listener, options) {
    if (listener == null) return
    const capture = typeof options === 'boolean' ? options : !!(options && options.capture)
    const once = !!(options && options.once)
    const all = this[LISTENERS] || (this[LISTENERS] = new Map())
    type = String(type)
    let list = all.get(type)
    if (!list) all.set(type, list = [])
    if (list.some(l => l.listener === listener && l.capture === capture)) return
    list.push({listener, capture, once})
    const signal = options && options.signal
    if (signal) signal.addEventListener('abort', () => this.removeEventListener(type, listener, capture), {once: true})
  }
  removeEventListener(type, listener, options) {
    const capture = typeof options === 'boolean' ? options : !!(options && options.capture)
    const list = this[LISTENERS] && this[LISTENERS].get(String(type))
    if (!list) return
    const i = list.findIndex(l => l.listener === listener && l.capture === capture)
    if (i >= 0) { list[i].removed = true; list.splice(i, 1) }
  }
  dispatchEvent(event) {
    if (!(event instanceof Event)) throw new TypeError('Argument 1 of dispatchEvent must be an Event')
    return dispatch(this, event)
  }
}

// The handler that `on<type>` names for `target`: a function that a script set, or the code in the element's tag
function handler(target, type) {
  const set = target[HANDLERS]
  if (set && type in set) return set[type]
  if (!(target instanceof Element)) return null
  const code = native.attr(target[ID], 'on' + type.toLowerCase())
  if (code == null) return null
  let made = null
  try { made = new Function('event', code) } catch (e) { report(e) }
  ;(target[HANDLERS] || (target[HANDLERS] = {}))[type] = made
  return made
}

function handlers(proto, types = HANDLED) {
  for (const type of types) {
    Object.defineProperty(proto, 'on' + type.toLowerCase(), {
      configurable: true, enumerable: true,
      get() { return handler(this, type) },
      set(f) { (this[HANDLERS] || (this[HANDLERS] = {}))[type] = typeof f === 'function' ? f : null },
    })
  }
}

// What an event goes to after `target`: the node above it, then the document, then the window
function above(target, event) {
  if (target === global) return null
  if (target instanceof Document) return event.type === 'load' ? null : global
  if (target instanceof Node) return target.parentNode
  return null
}

// Call what listens on `target` for the event. On the way down (phase 1) that's the listeners that asked for the way down, and on
// the way up (phase 3) the others. On the element itself (phase 2) it's both, the ones for the way down first.
function invoke(target, event, phase) {
  event.currentTarget = target
  event.eventPhase = phase
  const list = target[LISTENERS] && target[LISTENERS].get(event.type)
  const call = capture => {
    if (!list) return
    for (const l of [...list]) {
      if (l.removed || l.capture !== capture) continue
      if (l.once) target.removeEventListener(event.type, l.listener, l.capture)
      try {
        if (typeof l.listener === 'function') l.listener.call(target, event)
        else if (l.listener && typeof l.listener.handleEvent === 'function') l.listener.handleEvent(event)
      } catch (e) { report(e) }
      if (event[STOP] & 2) return
    }
  }
  if (phase !== 3) call(true)
  if (phase === 1 || event[STOP] & 2) return
  const f = handler(target, event.type)
  if (f) {
    try { if (f.call(target, event) === false) event.preventDefault() } catch (e) { report(e) }
  }
  if (!(event[STOP] & 2)) call(false)
}

function dispatch(target, event) {
  event.target = target
  event[STOP] = 0
  const path = []
  for (let t = target; t; t = above(t, event)) path.push(t)
  event[PATH] = path
  for (let i = path.length - 1; i >= 1 && !(event[STOP] & 1); i--) invoke(path[i], event, 1)
  if (!(event[STOP] & 1)) invoke(target, event, 2)
  if (event.bubbles) for (let i = 1; i < path.length && !(event[STOP] & 1); i++) invoke(path[i], event, 3)
  event.currentTarget = null
  event.eventPhase = 0
  return !event.defaultPrevented
}

// --- the object of a node -----------------------------------------------------------------

const hold = (parent, child) => { (parent[KIDS] || (parent[KIDS] = new Set())).add(child) }

function adopt(w, id) {
  w[ID] = id
  wrappers.set(id, new WeakRef(w))
  const p = native.parent(id)
  if (p) hold(wrap(p), w)
  else if (id === ROOT) hold(document, w)
  return w
}

function wrap(id) {
  if (!id) return null
  const ref = wrappers.get(id)
  let w = ref && ref.deref()
  if (w) return w
  const kind = native.kind(id)
  const tag = kind === 1 ? native.tag(id) : ''
  const C = kind === 1 ? classes[tag] || HTMLElement : kind === 3 ? Text : kind === 8 ? Comment : DocumentFragment
  w = adopt(Object.create(C.prototype), id)
  if (defined.has(tag)) upgrade(w)
  return w
}

class NodeList extends Array {
  static get [Symbol.species]() { return Array }
  item(i) { return this[i] ?? null }
  namedItem(name) { return this.find(e => e.id === name || (e.getAttribute && e.getAttribute('name') === name)) ?? null }
}
const HTMLCollection = NodeList
const list = ids => NodeList.from(ids, wrap)
const scope = n => n instanceof Document ? 0 : n[ID]
const node = x => x instanceof Node ? x : document.createTextNode(String(x))

// What scripts that watch the page are told of a change
function record(target, type, details) {
  for (const o of observers) o[NOTE](target, type, details)
}

function place(parent, child, before) {
  if (!(child instanceof Node)) throw new TypeError('The node to add is not a Node')
  if (parent instanceof Document || child instanceof Document || (parent.nodeType !== 1 && parent.nodeType !== 11)) throw wrong('HierarchyRequestError', 'The operation would yield an incorrect node tree.')
  if (before && before.parentNode !== parent) throw wrong('NotFoundError', 'The object can not be found here.')
  if (child instanceof DocumentFragment) {
    for (const k of child.childNodes) place(parent, k, before)
    return child
  }
  if (child.contains(parent)) throw wrong('HierarchyRequestError', 'The operation would yield an incorrect node tree.')
  if (before === child) before = child.nextSibling
  const old = child.parentNode
  if (old) unplace(child)
  native.insert(parent[ID], child[ID], before ? before[ID] : 0)
  hold(parent, child)
  if (observers.size) record(parent, 'childList', {addedNodes: [child], previousSibling: child.previousSibling, nextSibling: child.nextSibling})
  if (defined.size && child.nodeType === 1 && native.connected(child[ID])) arrived(child)
  // A <script> that a script adds to the page runs
  if (child instanceof HTMLScriptElement && native.connected(child[ID])) native.run(child[ID])
  return child
}

function unplace(child) {
  const parent = child.parentNode
  if (!parent || parent === document) return child
  if (observers.size) record(parent, 'childList', {removedNodes: [child], previousSibling: child.previousSibling, nextSibling: child.nextSibling})
  const was = defined.size && child.nodeType === 1 && native.connected(child[ID])
  native.remove(child[ID])
  if (parent[KIDS]) parent[KIDS].delete(child)
  if (was) left(child)
  return child
}

// Put new things in `parent` in place of all that's in it, as `change` does
function refill(parent, change) {
  const removed = observers.size ? [...parent.childNodes] : null
  const gone = defined.size && native.connected(parent[ID]) ? sorts(parent) : null
  change()
  if (parent[KIDS]) parent[KIDS].clear()
  if (removed) record(parent, 'childList', {removedNodes: removed, addedNodes: [...parent.childNodes]})
  if (gone) {
    for (const e of gone) if (!e.isConnected) disconnect(e)
    arrived(parent, false)
  }
}

class Node extends EventTarget {
  get nodeName() { return '' }
  get nodeValue() { return null }
  set nodeValue(v) {}
  get parentNode() { const p = native.parent(this[ID]); return p ? wrap(p) : this[ID] === ROOT ? document : null }
  get parentElement() { return wrap(native.parent(this[ID])) }
  get childNodes() { return list(native.children(this[ID])) }
  get firstChild() { return wrap(native.child(this[ID], 0)) }
  get lastChild() { return wrap(native.child(this[ID], -1)) }
  get nextSibling() { return wrap(native.sibling(this[ID], 1)) }
  get previousSibling() { return wrap(native.sibling(this[ID], -1)) }
  get textContent() { return native.text(this[ID]) }
  set textContent(v) { refill(this, () => native.setText(this[ID], v == null ? '' : String(v))) }
  get ownerDocument() { return document }
  get isConnected() { return native.connected(this[ID]) }
  get baseURI() { return native.resolve('') }
  hasChildNodes() { return native.child(this[ID], 0) !== 0 }
  appendChild(child) { return place(this, child, null) }
  insertBefore(child, before) { return place(this, child, before ?? null) }
  removeChild(child) {
    if (!(child instanceof Node) || child.parentNode !== this) throw wrong('NotFoundError', 'The object can not be found here.')
    return unplace(child)
  }
  replaceChild(child, old) {
    if (!(old instanceof Node) || old.parentNode !== this) throw wrong('NotFoundError', 'The object can not be found here.')
    if (child === old) return old
    place(this, child, old)
    unplace(old)
    return old
  }
  cloneNode(deep = false) { return wrap(native.clone(this[ID], !!deep)) }
  contains(other) {
    for (let n = other; n instanceof Node; n = n.parentNode) if (n === this) return true
    return false
  }
  getRootNode() { let n = this; while (n.parentNode) n = n.parentNode; return n }
  isSameNode(other) { return other === this }
  isEqualNode(other) {
    if (other === this) return true
    if (!(other instanceof Node) || other.nodeType !== this.nodeType) return false
    return this.nodeType === 1 ? other.outerHTML === this.outerHTML : other.textContent === this.textContent
  }
  compareDocumentPosition(other) {
    if (other === this) return 0
    if (this.contains(other)) return 20
    if (other.contains(this)) return 10
    const order = other instanceof Document || this instanceof Document ? 0 : native.order(this[ID], other[ID])
    return order === 0 ? 35 : order < 0 ? 4 : 2
  }
  normalize() {}
  lookupNamespaceURI() { return null }
  isDefaultNamespace() { return true }
}
const KINDS = {ELEMENT_NODE: 1, ATTRIBUTE_NODE: 2, TEXT_NODE: 3, CDATA_SECTION_NODE: 4, PROCESSING_INSTRUCTION_NODE: 7, COMMENT_NODE: 8, DOCUMENT_NODE: 9,
  DOCUMENT_TYPE_NODE: 10, DOCUMENT_FRAGMENT_NODE: 11, DOCUMENT_POSITION_DISCONNECTED: 1, DOCUMENT_POSITION_PRECEDING: 2, DOCUMENT_POSITION_FOLLOWING: 4,
  DOCUMENT_POSITION_CONTAINS: 8, DOCUMENT_POSITION_CONTAINED_BY: 16, DOCUMENT_POSITION_IMPLEMENTATION_SPECIFIC: 32}
Object.assign(Node, KINDS)
Object.assign(Node.prototype, KINDS)

// What an element, a document and a fragment share: the elements in them
function parental(proto) {
  Object.defineProperties(proto, Object.getOwnPropertyDescriptors({
    get children() { return NodeList.from(this.childNodes.filter(n => n.nodeType === 1)) },
    get childElementCount() { return this.children.length },
    get firstElementChild() { return this.children[0] ?? null },
    get lastElementChild() { return this.children.at(-1) ?? null },
    querySelector(selector) { return wrap(native.query(scope(this), String(selector), false)[0]) },
    querySelectorAll(selector) { return list(native.query(scope(this), String(selector), true)) },
    append(...nodes) { for (const n of nodes) this.appendChild(node(n)) },
    prepend(...nodes) { const first = this.firstChild; for (const n of nodes) this.insertBefore(node(n), first) },
    replaceChildren(...nodes) { for (const n of this.childNodes) unplace(n); this.append(...nodes) },
  }))
}

// What an element and a run of text share: the nodes beside them
function sibling(proto) {
  Object.defineProperties(proto, Object.getOwnPropertyDescriptors({
    get nextElementSibling() { let n = this.nextSibling; while (n && n.nodeType !== 1) n = n.nextSibling; return n },
    get previousElementSibling() { let n = this.previousSibling; while (n && n.nodeType !== 1) n = n.previousSibling; return n },
    before(...nodes) { const p = this.parentNode; if (p) for (const n of nodes) p.insertBefore(node(n), this) },
    after(...nodes) { const p = this.parentNode; if (!p) return; const next = this.nextSibling; for (const n of nodes) p.insertBefore(node(n), next) },
    replaceWith(...nodes) { const p = this.parentNode; if (!p) return; const next = this.nextSibling; unplace(this); for (const n of nodes) p.insertBefore(node(n), next) },
    remove() { unplace(this) },
  }))
}

class CharacterData extends Node {
  get data() { return native.data(this[ID]) }
  set data(v) {
    const old = observers.size ? this.data : null
    native.setData(this[ID], v == null ? '' : String(v))
    if (observers.size) record(this, 'characterData', {oldValue: old})
  }
  get nodeValue() { return this.data }
  set nodeValue(v) { this.data = v }
  get textContent() { return this.data }
  set textContent(v) { this.data = v }
  get length() { return this.data.length }
  appendData(s) { this.data += String(s) }
  substringData(from, count) { return this.data.substr(from, count) }
  deleteData(from, count) { const d = this.data; this.data = d.slice(0, from) + d.slice(from + count) }
  insertData(at, s) { const d = this.data; this.data = d.slice(0, at) + String(s) + d.slice(at) }
  replaceData(from, count, s) { const d = this.data; this.data = d.slice(0, from) + String(s) + d.slice(from + count) }
}
sibling(CharacterData.prototype)

class Text extends CharacterData {
  constructor(data = '') { super(); adopt(this, native.createText(String(data))) }
  get nodeType() { return 3 }
  get nodeName() { return '#text' }
  get wholeText() { return this.data }
  splitText(at) {
    const d = this.data, rest = document.createTextNode(d.slice(at))
    this.data = d.slice(0, at)
    if (this.parentNode) this.parentNode.insertBefore(rest, this.nextSibling)
    return rest
  }
}

class Comment extends CharacterData {
  constructor(data = '') { super(); adopt(this, native.createComment(String(data))) }
  get nodeType() { return 8 }
  get nodeName() { return '#comment' }
}

class DocumentFragment extends Node {
  constructor() { super(); adopt(this, native.createFragment()) }
  get nodeType() { return 11 }
  get nodeName() { return '#document-fragment' }
  getElementById(id) { return this.querySelector('#' + CSS.escape(id)) }
}
parental(DocumentFragment.prototype)

// --- what an element's tag says -----------------------------------------------------------

// The words of an attribute, like the classes of `class="a b"`
class DOMTokenList {
  #element; #name
  constructor(element, name) { this.#element = element; this.#name = name }
  #words() { return (this.#element.getAttribute(this.#name) || '').split(/\s+/).filter(Boolean) }
  #write(words) { this.#element.setAttribute(this.#name, words.join(' ')) }
  get value() { return this.#element.getAttribute(this.#name) || '' }
  set value(v) { this.#element.setAttribute(this.#name, String(v)) }
  get length() { return this.#words().length }
  item(i) { return this.#words()[i] ?? null }
  contains(word) { return this.#words().includes(String(word)) }
  add(...words) { const all = this.#words(); for (const w of words) if (!all.includes(String(w))) all.push(String(w)); this.#write(all) }
  remove(...words) { const drop = words.map(String); this.#write(this.#words().filter(w => !drop.includes(w))) }
  toggle(word, force) {
    const has = this.contains(word), want = force === undefined ? !has : !!force
    if (want !== has) want ? this.add(word) : this.remove(word)
    return want
  }
  replace(old, word) {
    const all = this.#words(), i = all.indexOf(String(old))
    if (i < 0) return false
    all[i] = String(word)
    this.#write([...new Set(all)])
    return true
  }
  supports() { return true }
  forEach(f, self) { this.#words().forEach((w, i) => f.call(self, w, i, this)) }
  keys() { return this.#words().keys() }
  values() { return this.#words().values() }
  entries() { return this.#words().entries() }
  [Symbol.iterator]() { return this.#words().values() }
  toString() { return this.value }
}

// The declarations that `style="..."` writes, in order: each name with its value and whether it's !important
function declarations(text) {
  const found = new Map()
  let depth = 0, quote = '', from = 0
  const take = to => {
    const piece = text.slice(from, to), colon = piece.indexOf(':')
    if (colon < 0) return
    const name = piece.slice(0, colon).trim()
    let value = piece.slice(colon + 1).trim()
    const important = /!\s*important$/i.test(value)
    if (important) value = value.replace(/!\s*important$/i, '').trim()
    if (name && value) found.set(name.startsWith('--') ? name : name.toLowerCase(), [value, important])
  }
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (quote) { if (c === '\\') i++; else if (c === quote) quote = '' }
    else if (c === '"' || c === "'") quote = c
    else if (c === '(') depth++
    else if (c === ')') depth = Math.max(0, depth - 1)
    else if (c === ';' && depth === 0) { take(i); from = i + 1 }
  }
  take(text.length)
  return found
}

// `backgroundColor` as CSS writes it: `background-color`
const dashed = name => name.startsWith('--') ? name : name === 'cssFloat' ? 'float' :
  name.replace(/^(webkit|moz|ms|o)(?=[A-Z])/, '-$1').replace(/[A-Z]/g, c => '-' + c.toLowerCase())

// `element.style`: the declarations of the element's `style`, which a script reads and writes by name
function style(element) {
  const id = element[ID]
  const read = () => declarations(native.attr(id, 'style') || '')
  const write = found => {
    const text = [...found].map(([name, [value, important]]) => `${name}: ${value}${important ? ' !important' : ''}`).join('; ')
    text ? element.setAttribute('style', text + ';') : element.removeAttribute('style')
  }
  const lower = name => { name = String(name).trim(); return name.startsWith('--') ? name : name.toLowerCase() }
  const methods = {
    getPropertyValue(name) { const d = read().get(lower(name)); return d ? d[0] : '' },
    getPropertyPriority(name) { const d = read().get(lower(name)); return d && d[1] ? 'important' : '' },
    setProperty(name, value, priority = '') {
      const found = read()
      name = lower(name)
      if (value == null || String(value).trim() === '') found.delete(name)
      else found.set(name, [String(value).trim(), String(priority).toLowerCase() === 'important'])
      write(found)
    },
    removeProperty(name) {
      const found = read(), d = found.get(lower(name))
      if (d) { found.delete(lower(name)); write(found) }
      return d ? d[0] : ''
    },
    item(i) { return [...read().keys()][i] ?? '' },
  }
  return new Proxy(methods, {
    get(target, name) {
      if (typeof name === 'symbol' || name in target) return target[name]
      if (name === 'cssText') return native.attr(id, 'style') || ''
      if (name === 'length') return read().size
      if (/^\d+$/.test(name)) return target.item(Number(name))
      return target.getPropertyValue(dashed(name))
    },
    set(target, name, value) {
      if (typeof name === 'symbol') return false
      if (name === 'cssText') value ? element.setAttribute('style', String(value)) : element.removeAttribute('style')
      else target.setProperty(dashed(name), value)
      return true
    },
    has(target, name) { return typeof name === 'string' },
    deleteProperty(target, name) { if (typeof name === 'string') target.removeProperty(dashed(name)); return true },
  })
}

// `getComputedStyle(element)`: what the page's CSS gives the element. It knows the few things that script.jl says, and for the
// rest what the element's own `style` says.
function computed(element) {
  const own = style(element)
  const value = name => native.computed(element[ID], name) ?? own.getPropertyValue(name)
  return new Proxy({getPropertyValue: name => value(String(name).trim().toLowerCase()), getPropertyPriority: () => '', item: () => '', length: 0}, {
    get(target, name) { return typeof name === 'symbol' || name in target ? target[name] : name === 'cssText' ? '' : value(dashed(name)) },
    has(target, name) { return typeof name === 'string' },
  })
}

// The `data-*` of a tag, by names like `userName` for `data-user-name`
function dataset(element) {
  const attr = name => 'data-' + name.replace(/[A-Z]/g, c => '-' + c.toLowerCase())
  const names = () => element.getAttributeNames().filter(n => n.startsWith('data-')).map(n => n.slice(5).replace(/-([a-z])/g, (_, c) => c.toUpperCase()))
  return new Proxy({}, {
    get(target, name) { return typeof name === 'symbol' ? undefined : element.getAttribute(attr(name)) ?? undefined },
    set(target, name, value) { element.setAttribute(attr(name), String(value)); return true },
    has(target, name) { return typeof name === 'string' && element.hasAttribute(attr(name)) },
    deleteProperty(target, name) { element.removeAttribute(attr(name)); return true },
    ownKeys() { return names() },
    getOwnPropertyDescriptor(target, name) { return this.has(target, name) ? {value: this.get(target, name), writable: true, enumerable: true, configurable: true} : undefined },
  })
}

const rectangle = (x, y, width, height) => ({x, y, width, height, left: x, top: y, right: x + width, bottom: y + height,
  toJSON() { return {x, y, width, height, left: x, top: y, right: x + width, bottom: y + height} }})

// --- elements -----------------------------------------------------------------------------

const STYLE = Symbol('style'), CLASSES = Symbol('classes'), DATA = Symbol('data')

class Element extends Node {
  get nodeType() { return 1 }
  get localName() { return native.tag(this[ID]) }
  get tagName() { return this.localName.toUpperCase() }
  get nodeName() { return this.tagName }
  get namespaceURI() { return 'http://www.w3.org/1999/xhtml' }
  get prefix() { return null }

  getAttribute(name) { return native.attr(this[ID], String(name).toLowerCase()) }
  setAttribute(name, value) {
    name = String(name).toLowerCase()
    const old = observers.size || this[MADE] ? native.attr(this[ID], name) : null
    native.setAttr(this[ID], name, String(value))
    if (name.startsWith('on') && this[HANDLERS]) delete this[HANDLERS][name.slice(2)]
    if (observers.size) record(this, 'attributes', {attributeName: name, oldValue: old})
    if (this[MADE]) changed(this, name, old, String(value))
  }
  removeAttribute(name) {
    name = String(name).toLowerCase()
    const old = native.attr(this[ID], name)
    if (old == null) return
    native.removeAttr(this[ID], name)
    if (name.startsWith('on') && this[HANDLERS]) delete this[HANDLERS][name.slice(2)]
    if (observers.size) record(this, 'attributes', {attributeName: name, oldValue: old})
    if (this[MADE]) changed(this, name, old, null)
  }
  hasAttribute(name) { return native.attr(this[ID], String(name).toLowerCase()) != null }
  toggleAttribute(name, force) {
    const has = this.hasAttribute(name), want = force === undefined ? !has : !!force
    if (want !== has) want ? this.setAttribute(name, '') : this.removeAttribute(name)
    return want
  }
  getAttributeNames() { return native.attrs(this[ID]).filter((_, i) => i % 2 === 0) }
  hasAttributes() { return native.attrs(this[ID]).length > 0 }
  getAttributeNS(ns, name) { return this.getAttribute(name) }
  setAttributeNS(ns, name, value) { this.setAttribute(String(name).replace(/^.*:/, ''), value) }
  removeAttributeNS(ns, name) { this.removeAttribute(name) }
  hasAttributeNS(ns, name) { return this.hasAttribute(name) }
  getAttributeNode(name) { const value = this.getAttribute(name); return value == null ? null : {name: String(name).toLowerCase(), value, ownerElement: this, specified: true} }
  get attributes() {
    const flat = native.attrs(this[ID]), all = []
    for (let i = 0; i < flat.length; i += 2) {
      const a = {name: flat[i], localName: flat[i], nodeName: flat[i], value: flat[i + 1], nodeValue: flat[i + 1], ownerElement: this, specified: true}
      all.push(a)
      if (!(flat[i] in all)) all[flat[i]] = a
    }
    all.getNamedItem = name => all.find(a => a.name === String(name).toLowerCase()) ?? null
    all.item = i => all[i] ?? null
    return all
  }

  get id() { return this.getAttribute('id') ?? '' }
  set id(v) { this.setAttribute('id', v) }
  get className() { return this.getAttribute('class') ?? '' }
  set className(v) { this.setAttribute('class', v) }
  get classList() { return this[CLASSES] || (this[CLASSES] = new DOMTokenList(this, 'class')) }
  set classList(v) { this.setAttribute('class', v) }
  get slot() { return this.getAttribute('slot') ?? '' }

  get innerHTML() { return native.html(this[ID]) }
  set innerHTML(v) { refill(this, () => native.setHTML(this[ID], v == null ? '' : String(v))) }
  get outerHTML() { return native.outer(this[ID]) }
  set outerHTML(v) {
    const p = this.parentNode
    if (!p || p === document) throw wrong('NoModificationAllowedError', 'The object can not be modified.')
    p.insertBefore(wrap(native.parse(p[ID], String(v))), this)
    unplace(this)
  }
  insertAdjacentElement(where, element) {
    where = String(where).toLowerCase()
    const p = this.parentNode
    if (where === 'beforebegin') { if (!p) return null; p.insertBefore(element, this) }
    else if (where === 'afterbegin') this.insertBefore(element, this.firstChild)
    else if (where === 'beforeend') this.appendChild(element)
    else if (where === 'afterend') { if (!p) return null; p.insertBefore(element, this.nextSibling) }
    else throw wrong('SyntaxError', 'The string did not match the expected pattern.')
    return element
  }
  insertAdjacentHTML(where, html) {
    const inside = /^(afterbegin|beforeend)$/i.test(where) ? this : this.parentNode
    if (!inside || inside === document) throw wrong('NoModificationAllowedError', 'The object can not be modified.')
    this.insertAdjacentElement(where, wrap(native.parse(inside[ID], String(html))))
  }
  insertAdjacentText(where, text) { this.insertAdjacentElement(where, document.createTextNode(String(text))) }

  matches(selector) { return native.matches(this[ID], String(selector)) }
  closest(selector) { return wrap(native.closest(this[ID], String(selector))) }
  getElementsByTagName(tag) { tag = String(tag).toLowerCase(); return tag === '*' ? this.querySelectorAll('*') : list(native.tagged(scope(this), tag)) }
  getElementsByClassName(names) { const words = String(names).split(/\s+/).filter(Boolean); return words.length ? this.querySelectorAll(words.map(w => '.' + CSS.escape(w)).join('')) : new NodeList() }

  // An element's rectangle is from the corner of the window, so it's higher by as far as the page is scrolled
  getClientRects() {
    const flat = native.rects(this[ID]), all = [], scrolled = native.scroll()
    for (let i = 0; i < flat.length; i += 4) all.push(rectangle(flat[i], flat[i + 1] - scrolled, flat[i + 2], flat[i + 3]))
    return all
  }
  getBoundingClientRect() {
    const all = this.getClientRects()
    if (!all.length) return rectangle(0, 0, 0, 0)
    const left = Math.min(...all.map(r => r.left)), top = Math.min(...all.map(r => r.top))
    return rectangle(left, top, Math.max(...all.map(r => r.right)) - left, Math.max(...all.map(r => r.bottom)) - top)
  }
  get clientWidth() { return this[ID] === ROOT ? native.window()[0] : Math.round(this.getBoundingClientRect().width) }
  get clientHeight() { return this[ID] === ROOT ? native.window()[1] : Math.round(this.getBoundingClientRect().height) }
  get clientLeft() { return 0 }
  get clientTop() { return 0 }
  get scrollWidth() { return this.clientWidth }
  get scrollHeight() { return this[ID] === ROOT ? Math.round(this.getBoundingClientRect().height) : this.clientHeight }
  get scrollLeft() { return 0 }
  set scrollLeft(v) {}
  // Only the page scrolls, so only its <html> and its <body> say how far
  get scrollTop() { return this[ID] === ROOT || this === document.body ? native.scroll() : 0 }
  set scrollTop(v) { if (this[ID] === ROOT || this === document.body) native.scrollTo(Number(v) || 0) }
  scrollIntoView() { if (this.isConnected) native.scrollTo(native.scroll() + this.getBoundingClientRect().top) }
  scrollTo(x, y) { if (this[ID] === ROOT || this === document.body) scrollTo(x, y) }
  scroll(x, y) { this.scrollTo(x, y) }
  scrollBy(x, y) { if (this[ID] === ROOT || this === document.body) scrollBy(x, y) }
  getAnimations() { return [] }
  setPointerCapture() {}
  releasePointerCapture() {}
  hasPointerCapture() { return false }
  // The element has the mouse to itself: see "the mouse to itself" below
  requestPointerLock() {
    if (!this.isConnected) {
      microtask(() => dispatch(document, new Event('pointerlockerror', {bubbles: true})))
      return Promise.reject(wrong('WrongDocumentError', 'An element that is not in the page can not have the mouse.'))
    }
    lock(this)
    return Promise.resolve()
  }
  requestFullscreen() { return Promise.reject(new TypeError('Fullscreen is not supported')) }
}
parental(Element.prototype)
sibling(Element.prototype)

// Make a property of the objects of a class say what an attribute of the tag says
function reflect(C, names, kind = 'text') {
  for (const entry of names) {
    const [prop, attr] = Array.isArray(entry) ? entry : [entry, entry.toLowerCase()]
    Object.defineProperty(C.prototype, prop, kind === 'flag' ? {
      configurable: true, enumerable: true,
      get() { return this.hasAttribute(attr) },
      set(v) { v ? this.setAttribute(attr, '') : this.removeAttribute(attr) },
    } : kind === 'number' ? {
      configurable: true, enumerable: true,
      get() { return Number(this.getAttribute(attr)) || 0 },
      set(v) { this.setAttribute(attr, String(v)) },
    } : kind === 'address' ? {
      configurable: true, enumerable: true,
      get() { const v = this.getAttribute(attr); return v == null ? '' : native.resolve(v) },
      set(v) { this.setAttribute(attr, String(v)) },
    } : {
      configurable: true, enumerable: true,
      get() { return this.getAttribute(attr) ?? '' },
      set(v) { this.setAttribute(attr, String(v)) },
    })
  }
}

class HTMLElement extends Element {
  // Only a class that the page defined is made with `new`: `super()` in its constructor gives the element that it's
  // made for, an element of the page when one is upgraded, or else a new element of its name
  constructor() {
    if (upgrading) { const e = upgrading; upgrading = null; return e }
    const name = NAMES.get(new.target)
    if (name === undefined) throw new TypeError('Illegal constructor')
    const e = adopt(Object.create(new.target.prototype), native.create(name))
    e[MADE] = true
    return e
  }
  get style() { return this[STYLE] || (this[STYLE] = style(this)) }
  set style(v) { this.setAttribute('style', String(v)) }
  get dataset() { return this[DATA] || (this[DATA] = dataset(this)) }
  get innerText() { return this.textContent }
  set innerText(v) { this.textContent = v }
  get outerText() { return this.textContent }
  get offsetWidth() { return Math.round(this.getBoundingClientRect().width) }
  get offsetHeight() { return Math.round(this.getBoundingClientRect().height) }
  // An element's place is always given from the <body>, and so from the corner of the page, as WebKit gives it for a <body> with no place of its own
  get offsetParent() { return this === document.body || this[ID] === ROOT || !this.isConnected ? null : document.body }
  get offsetLeft() { return Math.round(this.getBoundingClientRect().left) }
  get offsetTop() { return Math.round(this.getBoundingClientRect().top + native.scroll()) }
  get isContentEditable() { return false }
  get tabIndex() { const v = this.getAttribute('tabindex'); return v == null ? (/^(a|button|input|select|textarea)$/.test(this.localName) ? 0 : -1) : Number(v) || 0 }
  set tabIndex(v) { this.setAttribute('tabindex', String(v)) }
  focus() {
    const old = document.activeElement
    if (old === this) return
    if (old && old !== document.body) old.blur()
    focused = this
    native.focused(this[ID])
    dispatch(this, new FocusEvent('focus', {relatedTarget: old}))
    dispatch(this, new FocusEvent('focusin', {bubbles: true, relatedTarget: old}))
  }
  blur() {
    if (focused !== this) return
    focused = null
    native.focused(0)
    dispatch(this, new FocusEvent('blur'))
    dispatch(this, new FocusEvent('focusout', {bubbles: true}))
  }
  click() { click(this, 0, 0) }
  // A shadow tree is kept, and the scripts can fill it and read it, but it isn't drawn: the element shows what's in its tag
  attachShadow(init = {}) {
    if (this[SHADOW]) throw wrong('NotSupportedError', 'The element already has a shadow tree.')
    const root = new DocumentFragment()
    Object.defineProperties(root, {
      host: {value: this}, mode: {value: init.mode === 'closed' ? 'closed' : 'open'}, delegatesFocus: {value: !!init.delegatesFocus},
      innerHTML: {get() { return native.html(root[ID]) }, set(v) { refill(root, () => native.setHTML(root[ID], v == null ? '' : String(v))) }},
      adoptedStyleSheets: {value: [], writable: true},
      activeElement: {get: () => null},
    })
    this[SHADOW] = root
    return root
  }
  get shadowRoot() { const root = this[SHADOW]; return root && root.mode === 'open' ? root : null }
}
reflect(HTMLElement, ['title', 'lang', 'dir', 'role', ['accessKey', 'accesskey']])
reflect(HTMLElement, ['hidden', 'draggable', 'inert'], 'flag')
handlers(HTMLElement.prototype)

class SVGElement extends Element {
  get namespaceURI() { return 'http://www.w3.org/2000/svg' }
  get tagName() { return this.localName }
  get style() { return this[STYLE] || (this[STYLE] = style(this)) }
  get dataset() { return this[DATA] || (this[DATA] = dataset(this)) }
  get ownerSVGElement() { return this.localName === 'svg' ? null : this.closest('svg') }
  focus() {}
  blur() {}
}
handlers(SVGElement.prototype)

// A class for the elements of some tags, with the name that a browser gives it
function tags(name, names, base = HTMLElement, members = null) {
  const C = {[name]: class extends base {}}[name]
  if (members) Object.defineProperties(C.prototype, Object.getOwnPropertyDescriptors(members))
  for (const tag of names) classes[tag] = C
  global[name] = C
  return C
}

for (const tag of ['svg', 'g', 'path', 'circle', 'rect', 'ellipse', 'line', 'polyline', 'polygon', 'defs', 'use', 'symbol', 'lineargradient', 'radialgradient',
                   'stop', 'clippath', 'mask', 'pattern', 'tspan', 'textpath', 'foreignobject', 'marker', 'filter']) classes[tag] = SVGElement

tags('HTMLHtmlElement', ['html'])
tags('HTMLHeadElement', ['head'])
tags('HTMLBodyElement', ['body'])
tags('HTMLTitleElement', ['title'], HTMLElement, {get text() { return this.textContent }, set text(v) { this.textContent = v }})
tags('HTMLMetaElement', ['meta'])
tags('HTMLDivElement', ['div'])
tags('HTMLSpanElement', ['span'])
tags('HTMLParagraphElement', ['p'])
tags('HTMLHeadingElement', ['h1', 'h2', 'h3', 'h4', 'h5', 'h6'])
tags('HTMLPreElement', ['pre'])
tags('HTMLBRElement', ['br'])
tags('HTMLHRElement', ['hr'])
tags('HTMLUListElement', ['ul'])
tags('HTMLOListElement', ['ol'])
tags('HTMLLIElement', ['li'])
tags('HTMLTableElement', ['table'], HTMLElement, {
  get rows() { return this.querySelectorAll('tr') },
  get tBodies() { return this.children.filter(e => e.localName === 'tbody') },
})
tags('HTMLTableSectionElement', ['tbody', 'thead', 'tfoot'], HTMLElement, {get rows() { return this.children.filter(e => e.localName === 'tr') }})
tags('HTMLTableRowElement', ['tr'], HTMLElement, {get cells() { return this.children.filter(e => e.localName === 'td' || e.localName === 'th') }})
reflect(tags('HTMLTableCellElement', ['td', 'th']), ['colSpan', 'rowSpan'], 'number')
tags('HTMLStyleElement', ['style'])
// No page is shown in a frame, so a frame has no window of its own
const HTMLIFrameElement = tags('HTMLIFrameElement', ['iframe'], HTMLElement, {get contentWindow() { return null }, get contentDocument() { return null }})
reflect(HTMLIFrameElement, ['name', 'width', 'height', 'allow', 'loading', 'srcdoc', ['referrerPolicy', 'referrerpolicy']])
reflect(HTMLIFrameElement, ['src'], 'address')
reflect(HTMLIFrameElement, [['allowFullscreen', 'allowfullscreen']], 'flag')
tags('HTMLVideoElement', ['video'])
tags('HTMLAudioElement', ['audio'])
tags('HTMLUnknownElement', [])

const HTMLAnchorElement = tags('HTMLAnchorElement', ['a', 'area'], HTMLElement, {
  get text() { return this.textContent },
  toString() { return this.href },
})
reflect(HTMLAnchorElement, ['target', 'rel', 'download', 'hreflang', 'type'])
reflect(HTMLAnchorElement, ['href'], 'address')
for (const part of ['protocol', 'host', 'hostname', 'port', 'pathname', 'search', 'hash', 'origin']) {
  Object.defineProperty(HTMLAnchorElement.prototype, part, {configurable: true, get() { return new URL(this.href)[part] }})
}

const HTMLImageElement = tags('HTMLImageElement', ['img'], HTMLElement, {
  get complete() { return true },
  get naturalWidth() { return this.width },
  get naturalHeight() { return this.height },
  get width() { return Number(this.getAttribute('width')) || Math.round(this.getBoundingClientRect().width) },
  set width(v) { this.setAttribute('width', String(v)) },
  get height() { return Number(this.getAttribute('height')) || Math.round(this.getBoundingClientRect().height) },
  set height(v) { this.setAttribute('height', String(v)) },
  decode() { return Promise.resolve() },
})
reflect(HTMLImageElement, ['alt', 'srcset', 'sizes', 'loading', 'decoding', ['crossOrigin', 'crossorigin']])
reflect(HTMLImageElement, ['src'], 'address')

const HTMLScriptElement = tags('HTMLScriptElement', ['script'], HTMLElement, {get text() { return this.textContent }, set text(v) { this.textContent = v }})
reflect(HTMLScriptElement, ['type', 'charset', ['crossOrigin', 'crossorigin'], 'integrity'])
reflect(HTMLScriptElement, ['src'], 'address')
reflect(HTMLScriptElement, ['async', 'defer', ['noModule', 'nomodule']], 'flag')

const HTMLLinkElement = tags('HTMLLinkElement', ['link'])
reflect(HTMLLinkElement, ['rel', 'media', 'type', 'as'])
reflect(HTMLLinkElement, ['href'], 'address')

const HTMLFormElement = tags('HTMLFormElement', ['form'], HTMLElement, {
  get elements() { return this.querySelectorAll('input, select, textarea, button') },
  get length() { return this.elements.length },
  submit() { native.send(this[ID], 0) },
  requestSubmit(by) { submit(this, by ?? null) },
  reset() { dispatch(this, new Event('reset', {bubbles: true, cancelable: true})) },
  checkValidity() { return true },
  reportValidity() { return true },
})
reflect(HTMLFormElement, ['action', 'method', 'name', 'target', 'enctype'])

// What the parts of a form share
const field = {
  get form() { return this.closest('form') },
  get labels() { return this.id ? document.querySelectorAll(`label[for="${CSS.escape(this.id)}"]`) : new NodeList() },
  get validity() { return {valid: true} },
  get validationMessage() { return '' },
  get willValidate() { return false },
  checkValidity() { return true },
  reportValidity() { return true },
  setCustomValidity() {},
  select() {},
  setSelectionRange() {},
}

const HTMLInputElement = tags('HTMLInputElement', ['input'], HTMLElement, field)
Object.defineProperties(HTMLInputElement.prototype, Object.getOwnPropertyDescriptors({
  get type() { return (this.getAttribute('type') || 'text').toLowerCase() },
  set type(v) { this.setAttribute('type', String(v)) },
  get value() { return this.getAttribute('value') ?? (/^(checkbox|radio)$/.test(this.type) ? 'on' : '') },
  set value(v) { this.setAttribute('value', v == null ? '' : String(v)) },
  get valueAsNumber() { return this.value === '' ? NaN : Number(this.value) },
  set valueAsNumber(v) { this.value = String(v) },
  get defaultValue() { return this.value },
  set defaultValue(v) { this.value = v },
  get defaultChecked() { return this.checked },
  set defaultChecked(v) { this.checked = v },
}))
reflect(HTMLInputElement, ['name', 'placeholder', 'min', 'max', 'step', 'pattern', 'accept', ['autocomplete', 'autocomplete']])
reflect(HTMLInputElement, ['checked', 'disabled', 'required', 'multiple', ['readOnly', 'readonly'], 'autofocus'], 'flag')
reflect(HTMLInputElement, [['maxLength', 'maxlength'], ['minLength', 'minlength'], 'size'], 'number')

const HTMLButtonElement = tags('HTMLButtonElement', ['button'], HTMLElement, field)
Object.defineProperty(HTMLButtonElement.prototype, 'type', {configurable: true, get() { return (this.getAttribute('type') || 'submit').toLowerCase() }, set(v) { this.setAttribute('type', String(v)) }})
reflect(HTMLButtonElement, ['name', 'value'])
reflect(HTMLButtonElement, ['disabled', 'autofocus'], 'flag')

const HTMLTextAreaElement = tags('HTMLTextAreaElement', ['textarea'], HTMLElement, field)
Object.defineProperties(HTMLTextAreaElement.prototype, Object.getOwnPropertyDescriptors({
  get type() { return 'textarea' },
  get value() { return this.textContent },
  set value(v) { this.textContent = v == null ? '' : String(v) },
  get defaultValue() { return this.textContent },
  set defaultValue(v) { this.value = v },
}))
reflect(HTMLTextAreaElement, ['name', 'placeholder'])
reflect(HTMLTextAreaElement, ['disabled', 'required', ['readOnly', 'readonly']], 'flag')
reflect(HTMLTextAreaElement, ['rows', 'cols'], 'number')

const HTMLOptionElement = tags('HTMLOptionElement', ['option'], HTMLElement, {
  get value() { return this.getAttribute('value') ?? this.textContent.trim() },
  set value(v) { this.setAttribute('value', String(v)) },
  get text() { return this.textContent.trim() },
  set text(v) { this.textContent = v },
  get index() { const s = this.closest('select'); return s ? s.options.indexOf(this) : 0 },
})
reflect(HTMLOptionElement, ['label'])
reflect(HTMLOptionElement, ['selected', 'disabled'], 'flag')
tags('HTMLOptGroupElement', ['optgroup'])

const HTMLSelectElement = tags('HTMLSelectElement', ['select'], HTMLElement, field)
Object.defineProperties(HTMLSelectElement.prototype, Object.getOwnPropertyDescriptors({
  get type() { return this.multiple ? 'select-multiple' : 'select-one' },
  get options() { return this.querySelectorAll('option') },
  get length() { return this.options.length },
  get selectedOptions() { const all = this.options, chosen = all.filter(o => o.selected); return chosen.length || this.multiple ? chosen : all.slice(0, 1) },
  get selectedIndex() { const all = this.options, i = all.findIndex(o => o.selected); return i >= 0 ? i : all.length && !this.multiple ? 0 : -1 },
  set selectedIndex(i) { this.options.forEach((o, j) => { o.selected = j === Number(i) }) },
  get value() { const o = this.selectedOptions[0]; return o ? o.value : '' },
  set value(v) { let done = false; for (const o of this.options) { o.selected = !done && o.value === String(v); done = done || o.selected } },
  add(option, before = null) { this.insertBefore(option, typeof before === 'number' ? this.options[before] ?? null : before) },
}))
reflect(HTMLSelectElement, ['name'])
reflect(HTMLSelectElement, ['disabled', 'required', 'multiple'], 'flag')

const HTMLLabelElement = tags('HTMLLabelElement', ['label'], HTMLElement, {
  get control() { const id = this.getAttribute('for'); return id ? document.getElementById(id) : this.querySelector('input, select, textarea, button') },
  get form() { return this.closest('form') },
})
reflect(HTMLLabelElement, [['htmlFor', 'for']])

tags('HTMLCanvasElement', ['canvas'], HTMLElement, {
  getContext() { return null },
  toDataURL() { return 'data:,' },
})
reflect(classes.canvas, ['width', 'height'], 'number')

tags('HTMLTemplateElement', ['template'], HTMLElement, {
  // What's in a <template> is a fragment that's kept apart from the page
  get content() { const f = wrap(native.content(this[ID])); hold(this, f); return f },
  get innerHTML() { return native.html(this.content[ID]) },
  set innerHTML(v) { const f = this.content; refill(f, () => native.setHTML(f[ID], v == null ? '' : String(v))) },
})

tags('HTMLDetailsElement', ['details'])
reflect(classes.details, ['open'], 'flag')
tags('HTMLDialogElement', ['dialog'], HTMLElement, {
  show() { this.open = true },
  showModal() { this.open = true },
  close() { if (this.open) { this.open = false; dispatch(this, new Event('close')) } },
})
reflect(classes.dialog, ['open'], 'flag')

// --- the document -------------------------------------------------------------------------

let focused = null
let state = 'loading'
let running = null

// The mouse to itself: a script asks for it with `requestPointerLock`, as a game asks to turn its view with the mouse.
// Until the script lets it go (`document.exitPointerLock`), or Julia takes it back (as Esc does), each event of the mouse
// goes to that element, and none is over any other. Julia hides the pointer, and a `mousemove` says only how far the
// mouse moved. The page hears `pointerlockchange` after each change, as a browser tells it.
let locked = null
const holder = () => locked && locked.isConnected ? locked : (locked = null)
function lock(target) {
  if (holder() === target) return
  locked = target
  microtask(() => dispatch(document, new Event('pointerlockchange', {bubbles: true})))
}
function unlock() {
  if (!locked) return
  locked = null
  microtask(() => dispatch(document, new Event('pointerlockchange', {bubbles: true})))
}
// The events that go to the element that has the mouse to itself, and the ones that it has none of then
const MOUSING = /^(mouse|wheel|click|dblclick|contextmenu)/, CROSSING = /^mouse(over|out|enter|leave)$/

class Document extends Node {
  get nodeType() { return 9 }
  get nodeName() { return '#document' }
  get parentNode() { return null }
  get parentElement() { return null }
  get childNodes() { return NodeList.of(this.documentElement) }
  get firstChild() { return this.documentElement }
  get lastChild() { return this.documentElement }
  get nextSibling() { return null }
  get previousSibling() { return null }
  get textContent() { return null }
  set textContent(v) {}
  get ownerDocument() { return null }
  get isConnected() { return true }
  hasChildNodes() { return true }
  contains(other) { return other === this || (other instanceof Node && other.isConnected) }
  cloneNode() { throw wrong('NotSupportedError', 'A document can not be copied here.') }
  removeChild() { throw wrong('NotSupportedError', 'The <html> element can not be taken out of the page.') }

  get documentElement() { return wrap(ROOT) }
  get head() { return this.documentElement.children.find(e => e.localName === 'head') ?? null }
  get body() { return this.documentElement.children.find(e => e.localName === 'body' || e.localName === 'frameset') ?? null }
  set body(v) { const old = this.body; old ? this.documentElement.replaceChild(v, old) : this.documentElement.appendChild(v) }
  get scrollingElement() { return this.documentElement }
  get title() { const t = this.querySelector('title'); return t ? t.textContent.trim().replace(/\s+/g, ' ') : '' }
  set title(v) {
    let t = this.querySelector('title')
    if (!t && this.head) t = this.head.appendChild(this.createElement('title'))
    if (t) t.textContent = String(v)
  }
  get readyState() { return state }
  get currentScript() { return running }
  get activeElement() { return focused && focused.isConnected ? focused : this.body }
  get defaultView() { return global }
  get location() { return location }
  set location(v) { location.href = v }
  get URL() { return location.href }
  get documentURI() { return location.href }
  get baseURI() { return native.resolve('') }
  get domain() { return location.hostname }
  get referrer() { return '' }
  get cookie() { return '' }
  set cookie(v) {}
  get characterSet() { return 'UTF-8' }
  get charset() { return 'UTF-8' }
  get contentType() { return 'text/html' }
  get compatMode() { return native.quirks() ? 'BackCompat' : 'CSS1Compat' }
  get doctype() { return null }
  get hidden() { return false }
  get visibilityState() { return 'visible' }
  get fullscreenElement() { return null }
  get pointerLockElement() { return holder() }
  get designMode() { return 'off' }
  get dir() { return this.documentElement.dir }
  get styleSheets() { return [] }
  get adoptedStyleSheets() { return adoptions }
  set adoptedStyleSheets(v) { adoptions = taking([...v]); adopted() }
  get fonts() { return fonts }
  get implementation() { return {hasFeature: () => true, createHTMLDocument: title => spare(title)} }
  get forms() { return this.querySelectorAll('form') }
  get images() { return this.querySelectorAll('img') }
  get links() { return this.querySelectorAll('a[href], area[href]') }
  get scripts() { return this.querySelectorAll('script') }
  get embeds() { return this.querySelectorAll('embed') }
  hasFocus() { return true }

  getElementById(id) { return wrap(native.byId(String(id))) }
  getElementsByTagName(tag) { tag = String(tag).toLowerCase(); return tag === '*' ? this.querySelectorAll('*') : list(native.tagged(0, tag)) }
  getElementsByClassName(names) { return Element.prototype.getElementsByClassName.call(this, names) }
  getElementsByName(name) { return this.querySelectorAll(`[name="${CSS.escape(String(name))}"]`) }
  elementFromPoint(x, y) { return wrap(native.hit(Number(x), Number(y) + native.scroll())) }
  elementsFromPoint(x, y) { const all = []; for (let e = this.elementFromPoint(x, y); e; e = e.parentElement) all.push(e); return all }

  createElement(tag) { return wrap(native.create(String(tag).toLowerCase())) }
  createElementNS(ns, tag) { return wrap(native.create(String(tag).replace(/^.*:/, '').toLowerCase())) }
  createTextNode(data) { return new Text(String(data)) }
  createComment(data) { return new Comment(String(data)) }
  createDocumentFragment() { return new DocumentFragment() }
  createEvent(kind) {
    const C = {customevent: CustomEvent, mouseevent: MouseEvent, mouseevents: MouseEvent, keyboardevent: KeyboardEvent, uievent: UIEvent, uievents: UIEvent}[String(kind).toLowerCase()] || Event
    return new C('')
  }
  createRange() { return new Range() }
  createTreeWalker(root, show = 0xffffffff, filter = null) { return new TreeWalker(root, show, filter) }
  createNodeIterator(root, show = 0xffffffff, filter = null) { return new TreeWalker(root, show, filter) }
  importNode(n, deep = false) { return n.cloneNode(deep) }
  adoptNode(n) { return n }
  getSelection() { return selection }
  execCommand() { return false }
  queryCommandSupported() { return false }
  write() { native.log('warn', 'document.write does nothing here: the page is read before its scripts run') }
  writeln() { this.write() }
  open() { return this }
  close() {}
  exitFullscreen() { return Promise.resolve() }
  exitPointerLock() { unlock() }
}
parental(Document.prototype)
handlers(Document.prototype)

// A document that's no page, which a script makes to read HTML in. Its elements are the page's own kind, in a tree apart.
function spare(title) {
  const html = document.createElement('html'), head = html.appendChild(document.createElement('head')), body = html.appendChild(document.createElement('body'))
  if (title !== undefined) head.appendChild(document.createElement('title')).textContent = String(title)
  const made = {
    nodeType: 9, nodeName: '#document', documentElement: html, head, body, defaultView: null, location: null, implementation: document.implementation,
    get title() { const t = head.querySelector('title'); return t ? t.textContent : '' },
    getElementById: id => html.querySelector('#' + CSS.escape(String(id))),
    addEventListener() {}, removeEventListener() {},
  }
  for (const name of ['createElement', 'createElementNS', 'createTextNode', 'createComment', 'createDocumentFragment', 'createEvent', 'createRange', 'importNode', 'adoptNode']) {
    made[name] = (...args) => document[name](...args)
  }
  for (const name of ['querySelector', 'querySelectorAll', 'getElementsByTagName', 'getElementsByClassName']) made[name] = (...args) => html[name](...args)
  return made
}

// The nodes under one node, one after the other
class TreeWalker {
  constructor(root, show, filter) { this.root = root; this.whatToShow = show >>> 0; this.filter = filter; this.currentNode = root }
  #shown(n) {
    if (!((this.whatToShow >>> (n.nodeType - 1)) & 1)) return false
    if (!this.filter) return true
    return (typeof this.filter === 'function' ? this.filter(n) : this.filter.acceptNode(n)) === 1
  }
  #after(n) {
    if (n.firstChild) return n.firstChild
    for (; n && n !== this.root; n = n.parentNode) if (n.nextSibling) return n.nextSibling
    return null
  }
  nextNode() {
    for (let n = this.#after(this.currentNode); n; n = this.#after(n)) if (this.#shown(n)) return this.currentNode = n
    return null
  }
  parentNode() {
    for (let n = this.currentNode; n && n !== this.root; ) { n = n.parentNode; if (n && this.#shown(n)) return this.currentNode = n }
    return null
  }
  firstChild() { for (let n = this.currentNode.firstChild; n; n = n.nextSibling) if (this.#shown(n)) return this.currentNode = n; return null }
  nextSibling() { for (let n = this.currentNode.nextSibling; n; n = n.nextSibling) if (this.#shown(n)) return this.currentNode = n; return null }
}
const NodeFilter = {FILTER_ACCEPT: 1, FILTER_REJECT: 2, FILTER_SKIP: 3, SHOW_ALL: 0xffffffff, SHOW_ELEMENT: 1, SHOW_TEXT: 4, SHOW_COMMENT: 128}

// A part of the page between two places. Scripts use it mostly to turn HTML into nodes.
class Range {
  constructor() { this.startContainer = this.endContainer = this.commonAncestorContainer = document; this.startOffset = this.endOffset = 0; this.collapsed = true }
  setStart(n, at) { this.startContainer = n; this.startOffset = at }
  setEnd(n, at) { this.endContainer = n; this.endOffset = at }
  selectNode(n) { this.startContainer = this.endContainer = n.parentNode }
  selectNodeContents(n) { this.startContainer = this.endContainer = n }
  collapse() {}
  createContextualFragment(html) {
    const inside = this.startContainer instanceof Element ? this.startContainer : document.body
    return wrap(native.parse(inside[ID], String(html)))
  }
  getBoundingClientRect() { return this.startContainer instanceof Element ? this.startContainer.getBoundingClientRect() : rectangle(0, 0, 0, 0) }
  getClientRects() { return [] }
  cloneRange() { return Object.assign(new Range(), this) }
  detach() {}
}

const selection = {rangeCount: 0, isCollapsed: true, anchorNode: null, focusNode: null, type: 'None', removeAllRanges() {}, addRange() {}, getRangeAt() { return new Range() },
  collapse() {}, toString() { return '' }}
const fonts = {ready: Promise.resolve(), status: 'loaded', load: () => Promise.resolve([]), check: () => true, addEventListener() {}, removeEventListener() {}, forEach() {}}

// --- scripts that watch the page ----------------------------------------------------------

class MutationObserver {
  #callback; #targets = []; #queue = []
  constructor(callback) { this.#callback = callback }
  observe(target, options = {}) {
    const attributes = options.attributes ?? (options.attributeFilter !== undefined || options.attributeOldValue !== undefined)
    const characterData = options.characterData ?? options.characterDataOldValue !== undefined
    this.#targets = this.#targets.filter(t => t.target !== target)
    this.#targets.push({target, childList: !!options.childList, attributes: !!attributes, characterData: !!characterData, subtree: !!options.subtree,
      attributeOldValue: !!options.attributeOldValue, characterDataOldValue: !!options.characterDataOldValue, attributeFilter: options.attributeFilter ?? null})
    observers.add(this)
  }
  disconnect() { this.#targets = []; this.#queue = []; observers.delete(this) }
  takeRecords() { const q = this.#queue; this.#queue = []; return q }
  [NOTE](target, type, details) {
    for (const t of this.#targets) {
      if (!t[type] || (t.target !== target && !(t.subtree && t.target.contains(target)))) continue
      if (type === 'attributes' && t.attributeFilter && !t.attributeFilter.includes(details.attributeName)) continue
      const old = type === 'attributes' ? t.attributeOldValue : type === 'characterData' ? t.characterDataOldValue : false
      if (!this.#queue.length) microtask(() => {
        const records = this.takeRecords()
        if (records.length) try { this.#callback.call(this, records, this) } catch (e) { report(e) }
      })
      this.#queue.push({type, target, addedNodes: NodeList.from(details.addedNodes ?? []), removedNodes: NodeList.from(details.removedNodes ?? []),
        previousSibling: details.previousSibling ?? null, nextSibling: details.nextSibling ?? null, attributeName: details.attributeName ?? null,
        attributeNamespace: null, oldValue: old ? details.oldValue ?? null : null})
      return
    }
  }
}

// The whole page is laid out, so each thing that's watched is in view: the script is told so once
class IntersectionObserver {
  #callback
  constructor(callback, options = {}) { this.#callback = callback; this.root = options.root ?? null; this.rootMargin = options.rootMargin ?? '0px'; this.thresholds = [].concat(options.threshold ?? 0) }
  observe(target) {
    setTimeout(() => {
      const r = target.getBoundingClientRect()
      this.#callback.call(this, [{target, isIntersecting: true, intersectionRatio: 1, boundingClientRect: r, intersectionRect: r, rootBounds: null, time: native.now()}], this)
    }, 0)
  }
  unobserve() {}
  disconnect() {}
  takeRecords() { return [] }
}

// A script is told the size of what it watches once. It isn't told when the size changes.
class ResizeObserver {
  #callback
  constructor(callback) { this.#callback = callback }
  observe(target) {
    setTimeout(() => {
      const r = target.getBoundingClientRect(), size = [{inlineSize: r.width, blockSize: r.height}]
      this.#callback.call(this, [{target, contentRect: r, borderBoxSize: size, contentBoxSize: size, devicePixelContentBoxSize: size}], this)
    }, 0)
  }
  unobserve() {}
  disconnect() {}
}

// --- timers -------------------------------------------------------------------------------

const timers = new Map()
let frames = []
let last = 0

function setTimeout(f, ms = 0, ...args) {
  timers.set(++last, {at: native.now() + Math.max(0, Number(ms) || 0), f, args, every: null})
  return last
}
function setInterval(f, ms = 0, ...args) {
  const every = Math.max(4, Number(ms) || 0)
  timers.set(++last, {at: native.now() + every, f, args, every})
  return last
}
function clearTimeout(id) { timers.delete(id); frames = frames.filter(fr => fr.id !== id) }
function requestAnimationFrame(f) { frames.push({id: ++last, f}); return last }

// A file that's on its way: `native.load` gives false for it. `ask` calls `then` with the file's text once it has come, or with
// null when it can't be had. Each tick asks again for the files that were on their way.
let asks = []
function ask(address, then) {
  const got = native.load(address)
  if (got === false) asks.push([address, then])
  else try { then(got) } catch (e) { report(e) }
}

// How many ms from `now` the next timer is due, 0 when a script waits for the next frame, or -1 when nothing waits
function waiting(now) {
  if (frames.length) return 0
  let soonest = asks.length ? now + 50 : Infinity
  for (const t of timers.values()) soonest = Math.min(soonest, t.at)
  return soonest === Infinity ? -1 : Math.max(0, soonest - now)
}

// Run what's due at `now`: the scripts that wait for a frame, then the timers, in the order that they're due
function tick(now) {
  const asked = asks
  asks = []
  for (const [address, then] of asked) ask(address, then)
  const waited = frames
  frames = []
  for (const {f} of waited) try { f(now) } catch (e) { report(e) }
  const due = [...timers].filter(([, t]) => t.at <= now).sort((a, b) => a[1].at - b[1].at || a[0] - b[0])
  for (const [id, t] of due) {
    if (!timers.has(id)) continue
    if (t.every == null) timers.delete(id)
    else t.at = Math.max(t.at + t.every, now)
    try { typeof t.f === 'function' ? t.f(...t.args) : (0, eval)(String(t.f)) } catch (e) { report(e) }
  }
  return waiting(native.now())
}

// --- addresses ----------------------------------------------------------------------------

class URLSearchParams {
  #pairs = []; #owner = null
  constructor(init = '', owner = null) {
    this.#owner = owner
    if (typeof init === 'string') {
      for (const piece of init.replace(/^\?/, '').split('&')) {
        if (!piece) continue
        const i = piece.indexOf('='), decode = s => { try { return decodeURIComponent(s.replace(/\+/g, ' ')) } catch (_) { return s } }
        this.#pairs.push(i < 0 ? [decode(piece), ''] : [decode(piece.slice(0, i)), decode(piece.slice(i + 1))])
      }
    } else if (init) {
      for (const [k, v] of typeof init[Symbol.iterator] === 'function' ? init : Object.entries(init)) this.#pairs.push([String(k), String(v)])
    }
  }
  #changed() { if (this.#owner) { const text = this.toString(); this.#owner.search = text ? '?' + text : '' } }
  get size() { return this.#pairs.length }
  get(name) { const p = this.#pairs.find(p => p[0] === name); return p ? p[1] : null }
  getAll(name) { return this.#pairs.filter(p => p[0] === name).map(p => p[1]) }
  has(name) { return this.#pairs.some(p => p[0] === name) }
  append(name, value) { this.#pairs.push([String(name), String(value)]); this.#changed() }
  set(name, value) {
    const i = this.#pairs.findIndex(p => p[0] === name)
    if (i < 0) this.#pairs.push([String(name), String(value)])
    else { this.#pairs[i][1] = String(value); this.#pairs = this.#pairs.filter((p, j) => j <= i || p[0] !== name) }
    this.#changed()
  }
  delete(name) { this.#pairs = this.#pairs.filter(p => p[0] !== name); this.#changed() }
  sort() { this.#pairs.sort((a, b) => a[0] < b[0] ? -1 : a[0] > b[0] ? 1 : 0); this.#changed() }
  forEach(f, self) { for (const [k, v] of this.#pairs) f.call(self, v, k, this) }
  keys() { return this.#pairs.map(p => p[0]).values() }
  values() { return this.#pairs.map(p => p[1]).values() }
  entries() { return this.#pairs.map(p => [...p]).values() }
  [Symbol.iterator]() { return this.entries() }
  toString() { return this.#pairs.map(([k, v]) => encodeURIComponent(k).replace(/%20/g, '+') + '=' + encodeURIComponent(v).replace(/%20/g, '+')).join('&') }
}

const PARTS = /^([a-z][a-z0-9+.-]*:)?(?:\/\/([^\/?#]*))?([^?#]*)(\?[^#]*)?(#.*)?$/i

class URL {
  #params = null
  constructor(address, base) {
    address = String(address)
    const whole = /^[a-z][a-z0-9+.-]*:/i.test(address) ? address : base !== undefined ? native.join(String(base), address) : null
    const m = whole && PARTS.exec(whole)
    if (!m || !m[1]) throw new TypeError(`"${address}" cannot be parsed as a URL.`)
    this.protocol = m[1].toLowerCase()
    const at = (m[2] ?? '').lastIndexOf('@'), server = (m[2] ?? '').slice(at + 1), login = at < 0 ? '' : m[2].slice(0, at)
    const colon = server.lastIndexOf(':'), ported = colon >= 0 && /^\d*$/.test(server.slice(colon + 1))
    this.hostname = (ported ? server.slice(0, colon) : server).toLowerCase()
    this.port = ported ? server.slice(colon + 1) : ''
    this.username = login.split(':')[0]
    this.password = login.split(':')[1] ?? ''
    this.pathname = m[3] || (m[2] !== undefined ? '/' : '')
    this.search = m[4] && m[4] !== '?' ? m[4] : ''
    this.hash = m[5] && m[5] !== '#' ? m[5] : ''
  }
  get host() { return this.port ? `${this.hostname}:${this.port}` : this.hostname }
  set host(v) { const [name, port = ''] = String(v).split(':'); this.hostname = name; this.port = port }
  get origin() { return /^(https?|ftp|wss?):$/.test(this.protocol) ? `${this.protocol}//${this.host}` : 'null' }
  get href() {
    const login = this.username ? this.username + (this.password ? ':' + this.password : '') + '@' : ''
    const server = this.host || this.protocol === 'file:' || login ? '//' + login + this.host : ''
    return this.protocol + server + this.pathname + this.search + this.hash
  }
  set href(v) { Object.assign(this, new URL(v)) }
  get searchParams() { return this.#params || (this.#params = new URLSearchParams(this.search, this)) }
  toString() { return this.href }
  toJSON() { return this.href }
  static canParse(address, base) { try { new URL(address, base); return true } catch (_) { return false } }
}

// Where the page is from. A script can read it. A script that sets it asks to go to another page: script.jl says where that leads.
const location = {
  get href() { return native.resolve('') || 'about:blank' },
  set href(v) { native.go(String(v)) },
  assign(v) { this.href = v },
  replace(v) { this.href = v },
  reload() { native.go(this.href) },
  toString() { return this.href },
}
for (const part of ['protocol', 'host', 'hostname', 'port', 'pathname', 'search', 'hash', 'origin']) {
  Object.defineProperty(location, part, {enumerable: true, get() { try { return new URL(this.href)[part] } catch (_) { return '' } }, set(v) {}})
}

// --- asking for a file --------------------------------------------------------------------

class Headers {
  #all = new Map()
  constructor(init = {}) { for (const [k, v] of init instanceof Headers ? init.entries() : Array.isArray(init) ? init : Object.entries(init)) this.set(k, v) }
  get(name) { return this.#all.get(String(name).toLowerCase()) ?? null }
  set(name, value) { this.#all.set(String(name).toLowerCase(), String(value)) }
  append(name, value) { const old = this.get(name); this.set(name, old == null ? value : `${old}, ${value}`) }
  has(name) { return this.#all.has(String(name).toLowerCase()) }
  delete(name) { this.#all.delete(String(name).toLowerCase()) }
  forEach(f, self) { for (const [k, v] of this.#all) f.call(self, v, k, this) }
  keys() { return this.#all.keys() }
  values() { return this.#all.values() }
  entries() { return this.#all.entries() }
  [Symbol.iterator]() { return this.#all.entries() }
}

class Response {
  #body
  constructor(body = '', init = {}) {
    this.#body = body == null ? '' : String(body)
    this.status = init.status ?? 200
    this.statusText = init.statusText ?? (this.status === 200 ? 'OK' : '')
    this.ok = this.status >= 200 && this.status < 300
    this.url = init.url ?? ''
    this.headers = new Headers(init.headers)
    this.redirected = false
    this.type = 'basic'
    this.bodyUsed = false
  }
  text() { return Promise.resolve(this.#body) }
  json() { return this.text().then(JSON.parse) }
  clone() { return new Response(this.#body, this) }
  arrayBuffer() { return Promise.reject(new TypeError('Only text() and json() can read what was fetched here')) }
  blob() { return this.arrayBuffer() }
}

// What `fetch` is asked for: the address, as a whole address, and how
class Request {
  constructor(input, init = {}) {
    const from = input instanceof Request ? input : null
    this.url = from ? from.url : native.resolve(String(input))
    this.method = String(init.method ?? from?.method ?? 'GET').toUpperCase()
    this.headers = new Headers(init.headers ?? from?.headers ?? {})
    for (const [k, d] of [['credentials', 'same-origin'], ['mode', 'cors'], ['cache', 'default'], ['redirect', 'follow'], ['referrer', 'about:client'],
                          ['referrerPolicy', ''], ['integrity', ''], ['keepalive', false], ['priority', 'auto']]) this[k] = init[k] ?? from?.[k] ?? d
    this.signal = init.signal ?? from?.signal ?? new AbortController().signal
    this.destination = ''
    this.bodyUsed = false
  }
  clone() { return new Request(this) }
}

// The page's `load` gives a file's text. Nothing can be sent.
function fetch(input, init = {}) {
  return new Promise((resolve, reject) => {
    const address = typeof input === 'string' ? input : input && input.url !== undefined ? input.url : String(input)
    const method = String(init.method ?? (input && input.method) ?? 'GET').toUpperCase()
    if (method !== 'GET' && method !== 'HEAD') return reject(new TypeError('Load failed'))
    ask(address, text => text == null ? reject(new TypeError('Load failed')) : resolve(new Response(method === 'HEAD' ? '' : text, {url: native.resolve(address)})))
  })
}

class XMLHttpRequest extends EventTarget {
  #method = 'GET'; #address = ''; #async = true
  constructor() { super(); this.readyState = 0; this.status = 0; this.statusText = ''; this.responseText = ''; this.responseType = ''; this.responseURL = ''; this.timeout = 0; this.withCredentials = false; this.upload = new EventTarget() }
  open(method, address, async = true) { this.#method = String(method).toUpperCase(); this.#address = String(address); this.#async = async !== false; this.#state(1) }
  setRequestHeader() {}
  getResponseHeader() { return null }
  getAllResponseHeaders() { return '' }
  overrideMimeType() {}
  abort() { this.#state(0) }
  get response() {
    if (this.responseType === 'json') { try { return JSON.parse(this.responseText) } catch (_) { return null } }
    return this.responseText
  }
  #state(n) { this.readyState = n; dispatch(this, new Event('readystatechange')) }
  send() {
    const gets = this.#method === 'GET' || this.#method === 'HEAD'
    const done = text => {
      if (text == null) {
        this.#state(4)
        dispatch(this, new Event('error'))
      } else {
        this.status = 200
        this.statusText = 'OK'
        this.responseURL = native.resolve(this.#address)
        this.responseText = text
        this.#state(4)
        dispatch(this, new Event('load'))
      }
      dispatch(this, new Event('loadend'))
    }
    // A script that doesn't wait can't have a file that's still on its way
    if (!this.#async) { const got = gets ? native.load(this.#address) : null; return done(got === false ? null : got) }
    setTimeout(() => gets ? ask(this.#address, done) : done(null), 0)
  }
}
Object.assign(XMLHttpRequest, {UNSENT: 0, OPENED: 1, HEADERS_RECEIVED: 2, LOADING: 3, DONE: 4})
handlers(XMLHttpRequest.prototype, ['readystatechange', 'load', 'error', 'loadend', 'abort', 'timeout', 'progress', 'loadstart'])

class AbortSignal extends EventTarget {
  constructor() { super(); this.aborted = false; this.reason = undefined }
  throwIfAborted() { if (this.aborted) throw this.reason }
  static abort(reason) { const s = new AbortSignal(); s.aborted = true; s.reason = reason ?? wrong('AbortError', 'The operation was aborted.'); return s }
  static timeout(ms) { const s = new AbortSignal(); setTimeout(() => stop(s, wrong('TimeoutError', 'The operation timed out.')), ms); return s }
}
handlers(AbortSignal.prototype, ['abort'])
function stop(signal, reason) {
  if (signal.aborted) return
  signal.aborted = true
  signal.reason = reason ?? wrong('AbortError', 'The operation was aborted.')
  dispatch(signal, new Event('abort'))
}
class AbortController {
  constructor() { this.signal = new AbortSignal() }
  abort(reason) { stop(this.signal, reason) }
}

// --- what a page keeps, for as long as it's open ------------------------------------------

class Storage {
  #all = new Map()
  get length() { return this.#all.size }
  key(i) { return [...this.#all.keys()][i] ?? null }
  getItem(name) { return this.#all.get(String(name)) ?? null }
  setItem(name, value) { this.#all.set(String(name), String(value)) }
  removeItem(name) { this.#all.delete(String(name)) }
  clear() { this.#all.clear() }
}

// --- the console --------------------------------------------------------------------------

function shown(x, depth = 0) {
  if (typeof x === 'string') return depth ? JSON.stringify(x) : x
  if (x === null || typeof x !== 'object') return typeof x === 'function' ? `function ${x.name}()` : String(x)
  if (x instanceof Error) return x.stack ? `${x.name}: ${x.message}\n${x.stack}` : `${x.name}: ${x.message}`
  if (x instanceof Element) return `<${x.localName}${x.id ? ' id="' + x.id + '"' : ''}${x.className ? ' class="' + x.className + '"' : ''}>`
  if (x instanceof Node) return x.nodeName
  if (depth > 2) return Array.isArray(x) ? '[…]' : '{…}'
  try {
    if (Array.isArray(x)) return '[' + x.map(v => shown(v, depth + 1)).join(', ') + ']'
    return '{' + Object.keys(x).map(k => `${k}: ${shown(x[k], depth + 1)}`).join(', ') + '}'
  } catch (_) { return String(x) }
}
const say = level => (...args) => native.log(level, args.map(a => shown(a)).join(' '))
const starts = new Map()
const console = {
  log: say('log'), info: say('info'), debug: say('debug'), warn: say('warn'), error: say('error'), trace: say('log'), dir: say('log'), table: say('log'),
  group: say('log'), groupCollapsed: say('log'), groupEnd() {}, clear() {}, count() {}, countReset() {},
  assert(ok, ...args) { if (!ok) say('error')('Assertion failed:', ...args) },
  time(name = 'default') { starts.set(name, native.now()) },
  timeEnd(name = 'default') { if (starts.has(name)) { say('log')(`${name}: ${(native.now() - starts.get(name)).toFixed(3)}ms`); starts.delete(name) } },
  timeLog(name = 'default') { if (starts.has(name)) say('log')(`${name}: ${(native.now() - starts.get(name)).toFixed(3)}ms`) },
}

// --- small things that a browser has ------------------------------------------------------

const LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function btoa(text) {
  text = String(text)
  let out = ''
  for (let i = 0; i < text.length; i += 3) {
    const a = text.charCodeAt(i), b = text.charCodeAt(i + 1), c = text.charCodeAt(i + 2)
    if (a > 255 || b > 255 || c > 255) throw wrong('InvalidCharacterError', 'The string contains invalid characters.')
    const n = (a << 16) | ((b || 0) << 8) | (c || 0)
    out += LETTERS[n >> 18] + LETTERS[(n >> 12) & 63] + (i + 1 < text.length ? LETTERS[(n >> 6) & 63] : '=') + (i + 2 < text.length ? LETTERS[n & 63] : '=')
  }
  return out
}
function atob(text) {
  text = String(text).replace(/[\t\n\f\r ]/g, '').replace(/=+$/, '')
  if (/[^A-Za-z0-9+\/]/.test(text) || text.length % 4 === 1) throw wrong('InvalidCharacterError', 'The string contains invalid characters.')
  let out = '', bits = 0, n = 0
  for (const c of text) {
    n = (n << 6) | LETTERS.indexOf(c)
    bits += 6
    if (bits >= 8) { bits -= 8; out += String.fromCharCode((n >> bits) & 255) }
  }
  return out
}

// --- sheets that a script makes ------------------------------------------------------------
//
// `new CSSStyleSheet()` holds rules. The sheets in `document.adoptedStyleSheets` are drawn: their rules are the text of a
// <style> at the end of the <head>, which this file keeps up to date. A shadow tree's sheets aren't drawn, as its tree isn't.

const RULES = Symbol('rules')

// The rules of a sheet's text, each with its braces: `a{color:red} @media x{b{c:d}}` is two
function rules_of(text) {
  const out = []
  const push = rule => { rule = rule.replace(/^(?:\s*\/\*[^]*?\*\/)+/, '').trim(); if (rule) out.push(rule) }
  let depth = 0, start = 0, quote = ''
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (quote) { if (c === '\\') i++; else if (c === quote) quote = ''; continue }
    if (c === '"' || c === "'") quote = c
    else if (c === '/' && text[i + 1] === '*') { const end = text.indexOf('*/', i + 2); i = end < 0 ? text.length : end + 1 }
    else if (c === '{') depth++
    else if (c === '}' && depth > 0 && --depth === 0) { push(text.slice(start, i + 1)); start = i + 1 }
    else if (c === ';' && depth === 0) { const rule = text.slice(start, i + 1); if (/^(?:\s*\/\*[^]*?\*\/)*\s*@/.test(rule)) push(rule); start = i + 1 }
  }
  return out
}

class CSSStyleSheet {
  constructor(options = {}) {
    this[RULES] = []
    this.disabled = !!options.disabled
    this.href = null
    this.ownerNode = null
    this.ownerRule = null
    this.parentStyleSheet = null
    this.title = null
    this.type = 'text/css'
    const media = [].concat(options.media ?? []).join(', ')
    this.media = {mediaText: media, length: media ? 1 : 0, item: i => i === 0 && media ? media : null, toString: () => media}
  }
  get cssRules() {
    return this[RULES].map(text => ({cssText: text, selectorText: text.startsWith('@') ? undefined : text.slice(0, text.indexOf('{')).trim(), parentStyleSheet: this}))
  }
  get rules() { return this.cssRules }
  insertRule(rule, index = 0) {
    rule = String(rule).trim()
    const one = rules_of(rule)
    if (one.length !== 1) throw wrong('SyntaxError', `Failed to parse the rule '${rule}'.`)
    if (index < 0 || index > this[RULES].length) throw wrong('IndexSizeError', 'The index is out of range.')
    this[RULES].splice(index, 0, one[0])
    adopted(this)
    return index
  }
  deleteRule(index) {
    if (index < 0 || index >= this[RULES].length) throw wrong('IndexSizeError', 'The index is out of range.')
    this[RULES].splice(index, 1)
    adopted(this)
  }
  addRule(selector = 'undefined', style = 'undefined', index = this[RULES].length) { this.insertRule(`${selector}{${style}}`, index); return -1 }
  removeRule(index = 0) { this.deleteRule(index) }
  replaceSync(text) { this[RULES] = rules_of(String(text)).filter(r => !/^@import\b/i.test(r)); adopted(this) }
  replace(text) { try { this.replaceSync(text); return Promise.resolve(this) } catch (e) { return Promise.reject(e) } }
}

let adoptions = []       // the document's adopted sheets
let adoptedStyle = null  // the <style> that draws them

// A list that draws the sheets again when a script changes what's in it: `document.adoptedStyleSheets.push(sheet)`
function taking(list) {
  return new Proxy(list, {set(target, key, value) { target[key] = value; adopted(); return true }, deleteProperty(target, key) { delete target[key]; adopted(); return true }})
}

// Draw the adopted sheets as they are now, or only when `changed` is one of them
function adopted(changed) {
  if (changed && !adoptions.includes(changed)) return
  const text = adoptions.filter(s => s instanceof CSSStyleSheet && !s.disabled).map(s => {
    const all = s[RULES].join('\n')
    return s.media.mediaText ? `@media ${s.media.mediaText} {\n${all}\n}` : all
  }).join('\n')
  if (!adoptedStyle) {
    if (!text) return
    adoptedStyle = document.createElement('style')
    adoptedStyle.setAttribute('data-adopted', '')
  }
  const head = document.head ?? document.documentElement
  if (adoptedStyle.parentNode !== head || adoptedStyle.nextSibling) head.appendChild(adoptedStyle)
  adoptedStyle.textContent = text
}

// Text as the bytes of UTF-8, and back. A half of a pair of UTF-16 units alone is written as U+FFFD.
class TextEncoder {
  get encoding() { return 'utf-8' }
  encode(text = '') {
    text = String(text)
    const out = new Uint8Array(text.length * 3)
    return out.slice(0, this.encodeInto(text, out).written)
  }
  encodeInto(text, into) {
    text = String(text)
    let read = 0, written = 0
    for (let i = 0; i < text.length; i++) {
      let c = text.charCodeAt(i), units = 1
      if (c >= 0xd800 && c <= 0xdbff && i + 1 < text.length) {
        const d = text.charCodeAt(i + 1)
        if (d >= 0xdc00 && d <= 0xdfff) { c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00); units = 2 }
      }
      if (c >= 0xd800 && c <= 0xdfff) c = 0xfffd
      const size = c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
      if (written + size > into.length) break
      if (size === 1) into[written++] = c
      else if (size === 2) { into[written++] = 0xc0 | (c >> 6); into[written++] = 0x80 | (c & 63) }
      else if (size === 3) { into[written++] = 0xe0 | (c >> 12); into[written++] = 0x80 | ((c >> 6) & 63); into[written++] = 0x80 | (c & 63) }
      else { into[written++] = 0xf0 | (c >> 18); into[written++] = 0x80 | ((c >> 12) & 63); into[written++] = 0x80 | ((c >> 6) & 63); into[written++] = 0x80 | (c & 63) }
      read += units
      i += units - 1
    }
    return {read, written}
  }
}

// What Windows-1252 has at 0x80 to 0x9f, where Latin-1 has codes that don't show
const WINDOWS_1252 = [0x20ac, 0x81, 0x201a, 0x192, 0x201e, 0x2026, 0x2020, 0x2021, 0x2c6, 0x2030, 0x160, 0x2039, 0x152, 0x8d, 0x17d, 0x8f,
                      0x90, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x2dc, 0x2122, 0x161, 0x203a, 0x153, 0x9d, 0x17e, 0x178]
const ENCODINGS = {'utf-8': 'utf-8', 'utf8': 'utf-8', 'unicode-1-1-utf-8': 'utf-8', 'utf-16le': 'utf-16le', 'utf-16': 'utf-16le', 'utf-16be': 'utf-16be',
                   'windows-1252': 'windows-1252', 'latin1': 'windows-1252', 'iso-8859-1': 'windows-1252', 'ascii': 'windows-1252', 'us-ascii': 'windows-1252',
                   'cp1252': 'windows-1252', 'x-user-defined': 'windows-1252'}

// Bytes as text: UTF-8, UTF-16 or Windows-1252. With `stream`, the bytes of a letter that's cut in two wait for the next call.
class TextDecoder {
  #left = []; #started = false
  constructor(label = 'utf-8', options = {}) {
    const encoding = ENCODINGS[String(label).trim().toLowerCase()]
    if (!encoding) throw new RangeError(`The encoding label provided ('${label}') is invalid.`)
    this.encoding = encoding
    this.fatal = !!options.fatal
    this.ignoreBOM = !!options.ignoreBOM
  }
  decode(input, options = {}) {
    let bytes = input === undefined ? new Uint8Array(0) : ArrayBuffer.isView(input) ? new Uint8Array(input.buffer, input.byteOffset, input.byteLength) : new Uint8Array(input)
    if (this.#left.length) { const joined = new Uint8Array(this.#left.length + bytes.length); joined.set(this.#left); joined.set(bytes, this.#left.length); bytes = joined }
    this.#left = []
    const stream = !!options.stream
    let out = '', i = 0
    const bad = () => { if (this.fatal) throw new TypeError('The encoded data was not valid.'); out += '�' }
    if (this.encoding === 'windows-1252') {
      for (; i < bytes.length; i++) out += String.fromCharCode(bytes[i] >= 0x80 && bytes[i] < 0xa0 ? WINDOWS_1252[bytes[i] - 0x80] : bytes[i])
    } else if (this.encoding !== 'utf-8') {
      const little = this.encoding === 'utf-16le'
      const end = bytes.length - (bytes.length % 2)
      const units = []
      for (; i < end; i += 2) units.push(little ? bytes[i] | (bytes[i + 1] << 8) : (bytes[i] << 8) | bytes[i + 1])
      if (stream && units.length && units[units.length - 1] >= 0xd800 && units[units.length - 1] <= 0xdbff) { units.pop(); i -= 2 }
      for (let k = 0; k < units.length; k += 4096) out += String.fromCharCode(...units.slice(k, k + 4096))
      if (i < bytes.length) stream ? (this.#left = [...bytes.slice(i)]) : bad()
      i = bytes.length
    } else {
      const codes = []
      while (i < bytes.length) {
        const b = bytes[i]
        if (b < 0x80) { codes.push(b); i++; continue }
        const size = b >= 0xc2 && b <= 0xdf ? 2 : b >= 0xe0 && b <= 0xef ? 3 : b >= 0xf0 && b <= 0xf4 ? 4 : 0
        if (!size) { flush(); bad(); i++; continue }
        if (i + size > bytes.length) {
          // A letter cut off at the end: it waits for the next call, or it's one that can't be read
          let ok = true
          for (let k = i + 1; k < bytes.length; k++) if ((bytes[k] & 0xc0) !== 0x80) ok = false
          if (ok && stream) { this.#left = [...bytes.slice(i)]; break }
          if (ok) { flush(); bad(); break }
        }
        let c = b & (size === 2 ? 0x1f : size === 3 ? 0x0f : 0x07), k = 1
        for (; k < size; k++) {
          const next = bytes[i + k]
          if (next === undefined || (next & 0xc0) !== 0x80) break
          c = (c << 6) | (next & 63)
        }
        if (k < size || (size === 3 && (c < 0x800 || (c >= 0xd800 && c <= 0xdfff))) || (size === 4 && (c < 0x10000 || c > 0x10ffff))) { flush(); bad(); i += Math.max(1, k); continue }
        if (c >= 0x10000) { c -= 0x10000; codes.push(0xd800 + (c >> 10), 0xdc00 + (c & 1023)) } else codes.push(c)
        i += size
        if (codes.length >= 4096) flush()
      }
      flush()
      function flush() { if (codes.length) { out += String.fromCharCode(...codes); codes.length = 0 } }
    }
    if (!this.#started && !this.ignoreBOM && out.charCodeAt(0) === 0xfeff) out = out.slice(1)
    this.#started = stream
    return out
  }
}

const CSS = {
  escape(text) { return String(text).replace(/[^a-zA-Z0-9_ -￿-]/g, c => '\\' + c).replace(/^(-?)(\d)/, (_, dash, d) => dash + '\\3' + d + ' ') },
  supports() { return false },
}

const crypto = {
  getRandomValues(array) {
    const bytes = native.random(array.byteLength), view = new Uint8Array(array.buffer, array.byteOffset, array.byteLength)
    view.set(bytes)
    return array
  },
  randomUUID() {
    const b = native.random(16)
    b[6] = (b[6] & 15) | 64
    b[8] = (b[8] & 63) | 128
    const hex = b.map(x => x.toString(16).padStart(2, '0')).join('')
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20)}`
  },
}

function matchMedia(query) {
  const list = new EventTarget()
  return Object.assign(list, {media: String(query), matches: native.media(String(query)), onchange: null, addListener() {}, removeListener() {}})
}

const navigator = {
  userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Ladder', appName: 'Netscape', appVersion: '5.0',
  vendor: 'Apple Computer, Inc.', platform: 'MacIntel', product: 'Gecko', language: 'en', languages: ['en'], onLine: true, cookieEnabled: false,
  hardwareConcurrency: 4, maxTouchPoints: 0, doNotTrack: null, javaEnabled: () => false, sendBeacon: () => false,
}

const performance = {timeOrigin: Date.now() - native.now(), now: () => native.now(), mark() {}, measure() {}, clearMarks() {}, clearMeasures() {},
  getEntries: () => [], getEntriesByType: () => [], getEntriesByName: () => []}

const history = {length: 1, state: null, scrollRestoration: 'auto', pushState(state) { this.state = state }, replaceState(state) { this.state = state }, back() {}, forward() {}, go() {}}

// --- elements that the page defines -------------------------------------------------------
//
// customElements.define gives a name its class. Each element of that name, in the page and made later, becomes an object of
// the class: its constructor runs, and its connectedCallback, disconnectedCallback and attributeChangedCallback are called
// as it goes into the page, comes out, and an attribute that it watches changes.

const promised = new Map()      // the names that a script waits for (whenDefined), with what ends each wait

// The elements of the defined names in `root`, with `root` itself when it's one and `self`, in the order of the page
function sorts(root, self = true) {
  if (!defined.size) return []
  const found = [...root.querySelectorAll([...defined.keys()].map(n => CSS.escape(n)).join(','))]
  return self && root.nodeType === 1 && defined.has(root.localName) ? [root, ...found] : found
}

// Make `e` an object of the class of its name: its constructor runs on it, and it's told of its attributes and that it's in the page
function upgrade(e) {
  const d = defined.get(e.localName)
  if (!d || e[MADE]) return
  e[MADE] = true
  Object.setPrototypeOf(e, d.C.prototype)
  upgrading = e
  try { new d.C() } catch (err) { report(err) } finally { upgrading = null }
  for (const name of d.watched) { const v = native.attr(e[ID], name); if (v != null) changed(e, name, null, v) }
  if (e.isConnected) connect(e)
}

function changed(e, name, old, value) {
  const d = defined.get(e.localName)
  if (d && d.watched.includes(name) && typeof e.attributeChangedCallback === 'function') {
    try { e.attributeChangedCallback(name, old, value, null) } catch (err) { report(err) }
  }
}

function connect(e) {
  if (e[INSIDE]) return
  e[INSIDE] = true
  if (typeof e.connectedCallback === 'function') try { e.connectedCallback() } catch (err) { report(err) }
}

function disconnect(e) {
  if (!e[INSIDE]) return
  e[INSIDE] = false
  if (typeof e.disconnectedCallback === 'function') try { e.disconnectedCallback() } catch (err) { report(err) }
}

// `root` went into the page: each defined element in it is made, or told that it's in the page again
function arrived(root, self = true) { for (const e of sorts(root, self)) e[MADE] ? connect(e) : upgrade(e) }
// `root` came out of the page
function left(root) { for (const e of sorts(root)) disconnect(e) }

const customElements = {
  define(name, C, options = {}) {
    name = String(name)
    if (!/^[a-z][^A-Z\s]*-[^A-Z\s]*$/.test(name)) throw wrong('SyntaxError', `"${name}" is not a valid custom element name`)
    if (defined.has(name)) throw wrong('NotSupportedError', `"${name}" has already been used with this registry`)
    if (typeof C !== 'function') throw new TypeError('The constructor of a custom element must be a function')
    if (NAMES.has(C)) throw wrong('NotSupportedError', 'This constructor has already been used with this registry')
    if (options && options.extends) {
      native.log('warn', `The page defined <${options.extends} is="${name}">, which this engine doesn't do, as Safari doesn't`)
      return
    }
    defined.set(name, {C, watched: [].concat(C.observedAttributes ?? []).map(n => String(n).toLowerCase())})
    NAMES.set(C, name)
    for (const e of document.querySelectorAll(CSS.escape(name))) upgrade(e)
    const wait = promised.get(name)
    if (wait) { promised.delete(name); wait.resolve(C) }
  },
  get(name) { const d = defined.get(String(name)); return d ? d.C : undefined },
  getName(C) { return NAMES.get(C) ?? null },
  whenDefined(name) {
    name = String(name)
    if (defined.has(name)) return Promise.resolve(defined.get(name).C)
    let wait = promised.get(name)
    if (!wait) {
      let resolve
      const promise = new Promise(r => { resolve = r })
      promised.set(name, wait = {promise, resolve})
    }
    return wait.promise
  },
  upgrade(root) { for (const e of sorts(root)) upgrade(e) },
}

// --- a click ------------------------------------------------------------------------------

// What a click on `target` does: the page's scripts hear it, then a tick box changes. True unless a script said to do no more.
function click(target, x, y) {
  const at = {bubbles: true, cancelable: true, clientX: x, clientY: y, screenX: x, screenY: y, detail: 1}
  if (!dispatch(target, new MouseEvent('click', at))) return false
  let field = target instanceof Element ? target.closest('input, label, button') : null
  if (field instanceof HTMLLabelElement) field = field.control
  if (field instanceof HTMLInputElement && !field.disabled && (field.type === 'checkbox' || field.type === 'radio')) {
    if (field.type === 'checkbox') field.checked = !field.checked
    else {
      const name = field.name
      if (name) for (const other of document.querySelectorAll(`input[type="radio"][name="${CSS.escape(name)}"]`)) if (other !== field && other.form === field.form) other.checked = false
      field.checked = true
    }
    dispatch(field, new Event('input', {bubbles: true}))
    dispatch(field, new Event('change', {bubbles: true}))
  } else if (field && !field.disabled && field.form && (field instanceof HTMLButtonElement ? field.type === 'submit' : /^(submit|image)$/.test(field.type))) {
    submit(field.form, field)
  }
  return true
}

// Send a form, as the button `by` does, or the Return key with null. The page's scripts hear of it first, and one of them can say to do no more.
function submit(form, by) {
  const event = new Event('submit', {bubbles: true, cancelable: true})
  event.submitter = by
  if (dispatch(form, event)) native.send(form[ID], by ? by[ID] : 0)
}

// How far down a script asks the page to be scrolled: `scrollTo(0, 400)` or `scrollTo({top: 400})`
const down = (x, y) => Number(x !== null && typeof x === 'object' ? x.top : y) || 0
function scrollTo(x, y) { native.scrollTo(down(x, y)) }
function scrollBy(x, y) { native.scrollTo(native.scroll() + down(x, y)) }

// --- the window ---------------------------------------------------------------------------

document = Object.create(Document.prototype)

const sized = i => ({configurable: true, enumerable: true, get: () => native.window()[i], set() {}})
const still = {configurable: true, enumerable: true, get: () => 0, set() {}}
const scrolled = {configurable: true, enumerable: true, get: () => native.scroll(), set() {}}
Object.defineProperties(global, {
  innerWidth: sized(0), innerHeight: sized(1), outerWidth: sized(0), outerHeight: sized(1),
  scrollX: still, scrollY: scrolled, pageXOffset: still, pageYOffset: scrolled, screenX: still, screenY: still, screenLeft: still, screenTop: still,
  location: {configurable: true, enumerable: true, get: () => location, set(v) { location.href = v }},
})

Object.assign(global, {
  window: global, self: global, top: global, parent: global, frames: global, document, navigator, history, console, performance, crypto, customElements, CSS,
  localStorage: new Storage(), sessionStorage: new Storage(), devicePixelRatio: 2, length: 0, closed: false, name: '', origin: location.origin, isSecureContext: true,
  screen: {get width() { return native.window()[0] }, get height() { return native.window()[1] }, get availWidth() { return native.window()[0] },
    get availHeight() { return native.window()[1] }, colorDepth: 24, pixelDepth: 24, orientation: {type: 'landscape-primary', angle: 0}},
  addEventListener: (...a) => EventTarget.prototype.addEventListener.apply(global, a),
  removeEventListener: (...a) => EventTarget.prototype.removeEventListener.apply(global, a),
  dispatchEvent: event => dispatch(global, event),
  setTimeout, setInterval, clearTimeout, clearInterval: clearTimeout, requestAnimationFrame, cancelAnimationFrame: clearTimeout,
  requestIdleCallback: f => setTimeout(() => f({didTimeout: false, timeRemaining: () => 50}), 1), cancelIdleCallback: clearTimeout,
  queueMicrotask: microtask, fetch, atob, btoa, matchMedia,
  getComputedStyle: element => computed(element),
  getSelection: () => selection,
  scrollTo, scroll: scrollTo, scrollBy, focus() {}, blur() {}, print() {}, stop() {}, close() {}, postMessage() {},
  open() { return null },
  alert(text) { native.log('info', 'alert: ' + String(text ?? '')) },
  confirm(text) { native.log('info', 'confirm: ' + String(text ?? '')); return false },
  prompt(text) { native.log('info', 'prompt: ' + String(text ?? '')); return null },
  reportError: report,
  Image: function Image(width, height) {
    const img = document.createElement('img')
    if (width !== undefined) img.width = width
    if (height !== undefined) img.height = height
    return img
  },
  Option: function Option(text = '', value) {
    const o = document.createElement('option')
    o.textContent = text
    if (value !== undefined) o.value = value
    return o
  },
  Event, CustomEvent, UIEvent, MouseEvent, PointerEvent, WheelEvent, KeyboardEvent, FocusEvent, InputEvent, ErrorEvent, EventTarget, DOMException,
  Node, CharacterData, Text, Comment, DocumentFragment, Element, HTMLElement, SVGElement, Document, HTMLDocument: Document, NodeList, HTMLCollection,
  DOMTokenList, NodeFilter, TreeWalker, Range, MutationObserver, IntersectionObserver, ResizeObserver, URL, URLSearchParams, Headers, Request, Response,
  XMLHttpRequest, AbortController, AbortSignal, Storage, TextEncoder, TextDecoder, CSSStyleSheet,
})
handlers(global)

// --- what Julia calls ---------------------------------------------------------------------

return {
  tick,
  waiting: () => waiting(native.now()),
  // A click at a point of the page, on the element with the number `id`, or on the element that has the mouse to itself
  click: (id, x, y) => click(holder() ?? wrap(id) ?? document.body ?? document, x, y),
  // Any other event, on the element with the number `id`, or on the window when it's 0. The page hears of a scroll on its document.
  fire(id, type, init) {
    const C = type === 'wheel' ? WheelEvent : /^(mouse|dblclick|contextmenu)/.test(type) ? MouseEvent : /^key/.test(type) ? KeyboardEvent : Event
    let target = id ? wrap(id) : type === 'scroll' ? document : global
    if (holder() && MOUSING.test(type)) {
      if (CROSSING.test(type)) return true
      target = locked
    }
    return dispatch(target, new C(type, init ?? (type === 'scroll' ? {bubbles: true} : {})))
  },
  // The number of the element that has the mouse to itself, or 0
  locked: () => holder() ? locked[ID] : 0,
  // Julia takes the mouse back, as Esc does
  unlock,
  // The element with the number `id` gets the keyboard, or with 0 the element that has it loses it
  focus(id) {
    const e = id ? wrap(id) : null
    if (e && typeof e.focus === 'function') e.focus()
    else if (focused) focused.blur()
  },
  // The text `value` was typed into the field with the number `id`
  input(id, value) {
    const field = wrap(id)
    field.value = value
    dispatch(field, new InputEvent('input', {bubbles: true}))
  },
  // The form with the number `id` is sent, by the button with the number `by`, or by the Return key with 0
  submit(id, by) { submit(wrap(id), by ? wrap(by) : null) },
  // The <script> with the number `id` starts to run, or with 0 none runs now
  script(id) { running = id ? wrap(id) : null },
  // The page is read and its scripts have run
  ready() {
    state = 'interactive'
    dispatch(document, new Event('readystatechange'))
    dispatch(document, new Event('DOMContentLoaded', {bubbles: true}))
    state = 'complete'
    dispatch(document, new Event('readystatechange'))
    dispatch(global, new Event('load'))
  },
  // A promise failed and no script took the failure
  rejected(promise, reason) { report(reason) },
  // The numbers of the nodes that a script can still reach
  alive() {
    const ids = []
    for (const [id, ref] of wrappers) ref.deref() ? ids.push(id) : wrappers.delete(id)
    return ids
  },
}
})
"""
