// Keyed DOM morphing for the canvas.
//
// The server renders the whole document on every change; instead of replacing
// the canvas HTML (which reloads images and loses the inline editor's caret),
// the new HTML is diffed into the live DOM. Elements with `data-ex-id` are
// matched by id, so moving a block moves its element; everything else is
// matched by position and tag.

const KEY = "data-ex-id"

export function morphHTML(target, html) {
  const template = target.ownerDocument.createElement("template")
  template.innerHTML = html
  morphChildren(target, template.content)
}

export function morphChildren(from, to) {
  const keyed = new Map()

  for (const child of from.childNodes) {
    const key = keyOf(child)
    if (key) keyed.set(key, child)
  }

  let cursor = from.firstChild

  for (const next of Array.from(to.childNodes)) {
    const key = keyOf(next)
    let match = null

    if (key) {
      const candidate = keyed.get(key)
      if (candidate && candidate.nodeName === next.nodeName) {
        match = candidate
        keyed.delete(key)
      }
    } else if (cursor && !keyOf(cursor) && sameKind(cursor, next)) {
      match = cursor
    }

    if (match) {
      if (match === cursor) {
        cursor = cursor.nextSibling
      } else {
        from.insertBefore(match, cursor)
      }
      patch(match, next)
    } else {
      from.insertBefore(next, cursor)
    }
  }

  while (cursor) {
    const following = cursor.nextSibling
    from.removeChild(cursor)
    cursor = following
  }
}

function patch(el, next) {
  if (el.nodeType === Node.TEXT_NODE || el.nodeType === Node.COMMENT_NODE) {
    if (el.nodeValue !== next.nodeValue) el.nodeValue = next.nodeValue
    return
  }

  if (el.nodeType !== Node.ELEMENT_NODE) return

  // The element being typed into keeps its DOM (and the caret) until the edit ends.
  if (el.hasAttribute("data-exr-editing")) return

  patchAttributes(el, next)

  if (el.nodeName === "TEXTAREA") {
    if (el.value !== next.value) el.value = next.value
    return
  }

  if (el.nodeName === "INPUT") {
    if (el.type === "checkbox" || el.type === "radio") el.checked = next.hasAttribute("checked")
    else if (el.value !== next.getAttribute("value")) el.value = next.getAttribute("value") || ""
  }

  morphChildren(el, next)
}

function patchAttributes(el, next) {
  for (const { name } of Array.from(el.attributes)) {
    if (!next.hasAttribute(name) && !name.startsWith("data-exr-")) el.removeAttribute(name)
  }

  for (const { name, value } of Array.from(next.attributes)) {
    if (el.getAttribute(name) !== value) el.setAttribute(name, value)
  }
}

function keyOf(node) {
  return node.nodeType === Node.ELEMENT_NODE ? node.getAttribute(KEY) : null
}

function sameKind(a, b) {
  return a.nodeType === b.nodeType && a.nodeName === b.nodeName
}
