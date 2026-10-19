// Typing on the canvas. Elements marked `data-ex-inline="<prop>"` become
// editable on double-click; the value is sent to the server when the edit ends
// (blur, Escape, or Enter for one-line text) and comes back sanitized.
//
// Kinds (`data-ex-inline-kind`): "text" (plain text, one line), "inline"
// (formatting inside a line, e.g. headings) and "rich" (paragraphs and lists).

import { icon } from "./canvas"

export class InlineEditor {
  constructor(editor) {
    this.editor = editor
    this.current = null
  }

  get active() {
    return this.current !== null
  }

  start(el, point) {
    if (this.current && this.current.el === el) return
    this.finish()

    const node = el.closest("[data-ex-id]")
    if (!node) return

    const kind = el.getAttribute("data-ex-inline-kind") || "text"
    const doc = el.ownerDocument

    el.setAttribute("data-exr-editing", "")
    el.contentEditable = kind === "text" && supportsPlaintext(el) ? "plaintext-only" : "true"
    el.spellcheck = true

    this.current = {
      el,
      kind,
      id: node.getAttribute("data-ex-id"),
      prop: el.getAttribute("data-ex-inline"),
      original: kind === "text" ? el.textContent : el.innerHTML
    }

    el.focus({ preventScroll: true })
    if (point) placeCaret(doc, point)

    this.onKey = (e) => this.key(e)
    this.onBlur = () => setTimeout(() => this.finishIfLeft(), 0)
    this.onPaste = (e) => this.paste(e)
    el.addEventListener("keydown", this.onKey)
    el.addEventListener("blur", this.onBlur)
    el.addEventListener("paste", this.onPaste)

    if (kind !== "text") this.showToolbar()
  }

  // Clicks on the formatting bar blur the element; only finish when the focus
  // really left both.
  finishIfLeft() {
    if (!this.current) return
    const active = this.current.el.ownerDocument.activeElement
    if (active === this.current.el || (this.bar && this.bar.contains(active))) return
    this.finish()
  }

  finish() {
    if (!this.current) return
    const { el, kind, id, prop, original } = this.current
    this.current = null

    el.removeEventListener("keydown", this.onKey)
    el.removeEventListener("blur", this.onBlur)
    el.removeEventListener("paste", this.onPaste)
    el.removeAttribute("contenteditable")
    el.removeAttribute("data-exr-editing")
    this.hideToolbar()

    const value = kind === "text" ? el.innerText.replace(/\n+$/, "") : el.innerHTML
    if (value !== original) this.editor.push("inline", { id, prop, value })
  }

  cancel() {
    if (!this.current) return
    const { el, kind, original } = this.current
    if (kind === "text") el.textContent = original
    else el.innerHTML = original
    this.current.original = kind === "text" ? el.textContent : el.innerHTML
    this.finish()
  }

  key(e) {
    if (e.key === "Escape") {
      e.preventDefault()
      e.stopPropagation()
      this.finish()
      return
    }

    if (e.key === "Enter" && !e.shiftKey && this.current.kind !== "rich") {
      e.preventDefault()
      this.finish()
      return
    }

    const meta = e.metaKey || e.ctrlKey
    if (meta && this.current.kind !== "text") {
      const commands = { b: "bold", i: "italic", u: "underline" }
      if (commands[e.key]) {
        e.preventDefault()
        this.exec(commands[e.key])
      }
    }

    // Shortcuts of the editor (delete, undo...) must not act on the block while typing.
    e.stopPropagation()
  }

  paste(e) {
    e.preventDefault()
    const text = (e.clipboardData || window.clipboardData).getData("text/plain")
    this.current.el.ownerDocument.execCommand("insertText", false, text)
  }

  exec(command, value = null) {
    if (!this.current) return
    const doc = this.current.el.ownerDocument
    doc.execCommand(command, false, value)
    this.current.el.focus({ preventScroll: true })
  }

  showToolbar() {
    const labels = this.editor.labels
    const doc = this.current.el.ownerDocument
    const layer = doc.getElementById("exr-layer")
    if (!layer) return

    this.bar = doc.createElement("div")
    this.bar.className = "exr-inline-bar is-visible"
    const buttons = [
      ["bold", "<b>B</b>", labels.bold],
      ["italic", "<i>I</i>", labels.italic],
      ["underline", "<u>U</u>", labels.underline],
      ["strikeThrough", "<s>S</s>", labels.strike],
      ["link", icon("link"), labels.link],
      ["removeFormat", icon("clear"), labels.clear]
    ]

    for (const [command, html, title] of buttons) {
      const button = doc.createElement("button")
      button.type = "button"
      button.innerHTML = html
      button.title = title || command
      button.addEventListener("mousedown", (e) => e.preventDefault())
      button.addEventListener("click", (e) => {
        e.preventDefault()
        if (command === "link") {
          const url = window.prompt(labels.linkPrompt || "URL", "https://")
          if (url === null) return
          url.trim() === "" ? this.exec("unlink") : this.exec("createLink", url.trim())
        } else {
          this.exec(command)
        }
      })
      this.bar.appendChild(button)
    }

    layer.appendChild(this.bar)
    this.positionToolbar()
  }

  positionToolbar() {
    if (!this.bar || !this.current) return
    const rect = this.current.el.getBoundingClientRect()
    const win = this.current.el.ownerDocument.defaultView
    const top = rect.top + win.scrollY - 44
    this.bar.style.left = `${Math.max(4, rect.left + win.scrollX)}px`
    this.bar.style.top = `${Math.max(4, top)}px`
  }

  hideToolbar() {
    this.bar && this.bar.remove()
    this.bar = null
  }
}

function supportsPlaintext(el) {
  try {
    el.contentEditable = "plaintext-only"
    return el.contentEditable === "plaintext-only"
  } catch (_) {
    return false
  }
}

function placeCaret(doc, { x, y }) {
  let range = null
  if (doc.caretRangeFromPoint) range = doc.caretRangeFromPoint(x, y)
  else if (doc.caretPositionFromPoint) {
    const pos = doc.caretPositionFromPoint(x, y)
    if (pos) {
      range = doc.createRange()
      range.setStart(pos.offsetNode, pos.offset)
    }
  }
  if (!range) return
  const selection = doc.getSelection()
  selection.removeAllRanges()
  selection.addRange(range)
}
