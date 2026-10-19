// LiveView hook of ElementorexCms.Editor.
//
// It owns the canvas iframe: builds its document from `data-canvas`, morphs in
// the HTML the server pushes on every change, draws the hover/selection boxes,
// runs drag and drop and inline editing, and turns clicks and keys into events
// for the LiveComponent. The panels around it are regular LiveView markup.

import { canvasDocument, Overlay } from "./canvas"
import { morphHTML } from "./morph"
import { Dragger } from "./dnd"
import { InlineEditor } from "./inline"

const THEME_COLORS = [
  "primary", "secondary", "accent", "neutral", "base-100", "base-200", "base-300", "base-content",
  "info", "success", "warning", "error"
]

const isTyping = (el) =>
  el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName))

export const ElementorexEditor = {
  mounted() {
    this.config = JSON.parse(this.el.dataset.canvas)
    this.blocks = JSON.parse(this.el.dataset.blocks || "{}")
    this.labels = JSON.parse(this.el.dataset.labels || "{}")
    this.viewport = this.el.querySelector("[data-exr-viewport]")
    this.frameHost = this.el.querySelector("[data-exr-frame]")
    this.ready = false
    this.pending = null
    this.scale = 1

    this.dragger = new Dragger(this)
    this.inline = new InlineEditor(this)

    this.handleEvent(`exr:${this.el.id}:render`, (payload) => this.render(payload))

    this.createFrame()
    this.bindPanels()
    this.restorePanelSplit()

    this.resizeObserver = new ResizeObserver(() => this.layout())
    this.resizeObserver.observe(this.viewport)
    this.layout()
  },

  updated() {
    this.layout()
    this.applyPreview()
    this.applySelection()
  },

  destroyed() {
    this.resizeObserver && this.resizeObserver.disconnect()
    this.frameObserver && this.frameObserver.disconnect()
    window.removeEventListener("keydown", this.onKeyDown)
    window.removeEventListener("beforeunload", this.onBeforeUnload)
    this.dragger.cleanup()
  },

  push(event, payload = {}) {
    this.pushEventTo(this.el, event, payload)
  },

  // ---- Canvas ----

  createFrame() {
    const iframe = document.createElement("iframe")
    iframe.title = "Canvas"
    iframe.setAttribute("aria-label", "Canvas")
    iframe.addEventListener("load", () => this.frameLoaded(), { once: true })
    iframe.srcdoc = canvasDocument(this.config)
    this.frameHost.appendChild(iframe)
    this.iframe = iframe
  },

  frameLoaded() {
    this.frameWin = this.iframe.contentWindow
    this.frameDoc = this.iframe.contentDocument
    this.mount = this.frameDoc.querySelector("[data-exr-mount]") || this.frameDoc.body
    this.docStyle = this.frameDoc.getElementById("exr-doc-css")
    this.overlay = new Overlay(this.frameDoc, this.labels, this.blocks)

    this.bindFrame()
    this.readTheme()
    this.applyPreview()

    this.frameObserver = new ResizeObserver(() => this.overlay.refresh())
    this.frameObserver.observe(this.frameDoc.body)

    this.ready = true
    if (this.pending) this.render(this.pending)
    this.push("canvas_ready")
  },

  render({ html, css }) {
    if (!this.ready) {
      this.pending = { html, css }
      return
    }

    this.pending = null
    this.docStyle.textContent = css
    morphHTML(this.mount, html)
    this.applySelection(false)
    requestAnimationFrame(() => {
      this.overlay.refresh()
      this.inline.positionToolbar()
    })
  },

  canvasElement(id) {
    return this.frameDoc ? this.frameDoc.querySelector(`[data-ex-id="${CSS.escape(id)}"]`) : null
  },

  treeRow(id) {
    return this.el.querySelector(`[data-exr-tree-id="${CSS.escape(id)}"]`)
  },

  // Device width and zoom. "fit" shrinks the device to the available width.
  layout() {
    if (!this.viewport) return
    const width = parseInt(this.el.dataset.width || "1280", 10)
    const zoom = this.el.dataset.zoom || "fit"
    const preview = this.el.dataset.preview === "true"
    const gutter = preview ? 0 : 32
    const top = preview ? 0 : 16
    const availableWidth = Math.max(this.viewport.clientWidth - gutter, 200)
    const availableHeight = Math.max(this.viewport.clientHeight - top, 200)

    let scale = zoom === "fit" ? Math.min(1, availableWidth / width) : parseInt(zoom, 10) / 100
    if (!Number.isFinite(scale) || scale <= 0) scale = 1

    this.scale = scale
    const host = this.frameHost.style
    host.width = `${width}px`
    host.height = `${availableHeight / scale}px`

    if (width * scale > availableWidth) {
      host.left = `${gutter / 2}px`
      host.transform = `scale(${scale})`
      host.transformOrigin = "top left"
      this.viewport.style.overflowX = "auto"
    } else {
      host.left = "50%"
      host.transform = `translateX(-50%) scale(${scale})`
      host.transformOrigin = "top center"
      this.viewport.style.overflowX = "hidden"
    }

    this.overlay && requestAnimationFrame(() => this.overlay.refresh())
  },

  applyPreview() {
    if (!this.frameDoc) return
    this.preview = this.el.dataset.preview === "true"
    this.frameDoc.documentElement.classList.toggle("exr-preview-mode", this.preview)
    this.overlay.layer.style.display = this.preview ? "none" : ""
    if (this.preview) this.inline.finish()
  },

  applySelection(scroll = true) {
    if (!this.overlay) return
    const id = this.el.dataset.selected || null
    const changed = id !== this.lastSelected
    this.lastSelected = id
    const el = id && this.canvasElement(id)
    this.overlay.setSelected(id, el && el.hasAttribute("data-ex-doc"))

    if (changed && scroll && el && !el.hasAttribute("data-ex-doc")) {
      const rect = el.getBoundingClientRect()
      const height = this.frameWin.innerHeight
      if (rect.bottom < 0 || rect.top > height) el.scrollIntoView({ block: "center", behavior: "smooth" })
    }

    if (changed && id) {
      const row = this.treeRow(id)
      row && row.scrollIntoView({ block: "nearest" })
    }
  },

  // daisyUI theme colors of the canvas, for the swatches of the inspector (the
  // admin may have a different theme than the site).
  readTheme() {
    const style = this.frameWin.getComputedStyle(this.frameDoc.documentElement)
    for (const name of THEME_COLORS) {
      const value = style.getPropertyValue(`--color-${name}`).trim()
      if (value) this.el.style.setProperty(`--exr-theme-${name}`, value)
    }
  },

  // ---- Canvas events ----

  bindFrame() {
    const doc = this.frameDoc

    doc.addEventListener("mousemove", (e) => {
      if (this.dragger.drag || this.preview) return
      const node = e.target.closest && e.target.closest("[data-ex-id]")
      const id = node ? node.getAttribute("data-ex-id") : null
      if (id !== this.hoverId) this.setHover(id)
    })

    doc.addEventListener("mouseleave", () => this.setHover(null))

    doc.addEventListener("pointerdown", (e) => {
      const grip = e.target.closest && e.target.closest("[data-exr-grip]")
      if (!grip || !this.overlay.selectedId) return
      e.preventDefault()
      const el = this.canvasElement(this.overlay.selectedId)
      this.dragger.arm(
        { kind: "move", id: this.overlay.selectedId, type: el && el.getAttribute("data-ex-type"), el },
        e,
        true
      )
    })

    doc.addEventListener(
      "click",
      (e) => {
        const target = e.target
        const chip = target.closest && target.closest("[data-exr-chip]")

        if (chip) {
          e.preventDefault()
          const action = chip.getAttribute("data-exr-chip")
          this.push(action === "parent" ? "select_parent" : action, {})
          return
        }

        if (target.closest && target.closest("#exr-layer")) return
        if (target.closest && target.closest("[data-exr-editing]")) return

        // Links never navigate inside the canvas; tabs and accordions still work.
        if (target.closest && target.closest("a, button:not([data-exr-chip])")) e.preventDefault()

        if (this.preview || this.dragger.justDragged) return
        const node = target.closest && target.closest("[data-ex-id]")
        if (!node) return
        this.inline.finish()
        this.push("select", { id: node.getAttribute("data-ex-id") })
      },
      true
    )

    doc.addEventListener("dblclick", (e) => {
      if (this.preview) return
      const el = e.target.closest && e.target.closest("[data-ex-inline]")
      if (!el) return
      e.preventDefault()
      const node = el.closest("[data-ex-id]")
      if (node && node.getAttribute("data-ex-id") !== this.el.dataset.selected) {
        this.push("select", { id: node.getAttribute("data-ex-id") })
      }
      this.inline.start(el, { x: e.clientX, y: e.clientY })
    })

    doc.addEventListener("submit", (e) => e.preventDefault(), true)
    doc.addEventListener("keydown", (e) => this.keyDown(e))
    doc.addEventListener("load", () => this.overlay.refresh(), true)
    this.frameWin.addEventListener("resize", () => this.overlay.refresh())
  },

  setHover(id) {
    this.hoverId = id
    this.overlay && this.overlay.setHover(id)
    for (const row of this.el.querySelectorAll(".exr-tree-row.is-hover")) row.classList.remove("is-hover")
    const row = id && this.treeRow(id)
    row && row.classList.add("is-hover")
  },

  // ---- Panels ----

  bindPanels() {
    const el = this.el

    el.addEventListener("pointerdown", (e) => {
      const tile = e.target.closest("[data-exr-block]")
      if (tile) {
        this.dragger.arm({ kind: "new", type: tile.dataset.exrBlock, el: tile }, e)
        return
      }

      const row = e.target.closest("[data-exr-tree-id]")
      if (row && !e.target.closest("button") && row.dataset.exrTreeParent) {
        const id = row.dataset.exrTreeId
        const node = this.canvasElement(id)
        this.dragger.arm({ kind: "move", id, type: node && node.getAttribute("data-ex-type"), el: row }, e)
      }

      const resizer = e.target.closest("[data-exr-resizer]")
      if (resizer) this.resizePanels(e, resizer)
    })

    el.addEventListener("click", (e) => {
      if (this.dragger.justDragged) return

      const tile = e.target.closest("[data-exr-block]")
      if (tile) {
        this.push("add", { type: tile.dataset.exrBlock })
        return
      }

      const row = e.target.closest("[data-exr-tree-id]")
      if (row && !e.target.closest("button")) {
        this.push("select", { id: row.dataset.exrTreeId })
        return
      }

      const copy = e.target.closest("[data-exr-copy]")
      if (copy) this.copy(copy)

      const leave = e.target.closest("[data-exr-leave]")
      if (leave && this.el.dataset.dirty === "true" && !window.confirm(this.labels.unsaved)) {
        e.preventDefault()
        e.stopImmediatePropagation()
      }
    }, true)

    el.addEventListener("mouseover", (e) => {
      const row = e.target.closest("[data-exr-tree-id]")
      if (row) this.overlay && this.overlay.setHover(row.dataset.exrTreeId)
    })

    el.addEventListener("mouseleave", () => this.overlay && this.overlay.setHover(null))

    this.onKeyDown = (e) => this.keyDown(e)
    window.addEventListener("keydown", this.onKeyDown)

    this.onBeforeUnload = (e) => {
      if (this.el.dataset.dirty === "true") {
        e.preventDefault()
        e.returnValue = ""
      }
    }
    window.addEventListener("beforeunload", this.onBeforeUnload)
  },

  copy(button) {
    const target = document.getElementById(button.dataset.exrCopy)
    if (!target) return
    const lines = Array.from(target.querySelectorAll(".exr-code-line")).map((line) => line.textContent)
    const text = lines.length ? lines.join("\n") : target.textContent
    navigator.clipboard && navigator.clipboard.writeText(text).then(() => {
      const original = button.innerHTML
      button.textContent = this.labels.copied || "Copied"
      setTimeout(() => (button.innerHTML = original), 1200)
    })
  },

  // The divider between the palette and the tree.
  resizePanels(event, resizer) {
    const left = resizer.parentElement
    const palette = left.querySelector("[data-exr-palette]")
    if (!palette) return
    event.preventDefault()
    const startY = event.clientY
    const startHeight = palette.getBoundingClientRect().height
    const total = left.getBoundingClientRect().height

    const move = (e) => {
      const height = Math.min(Math.max(startHeight + e.clientY - startY, 120), total - 140)
      palette.style.flex = `0 0 ${height}px`
    }

    const up = () => {
      window.removeEventListener("pointermove", move)
      window.removeEventListener("pointerup", up)
      try { localStorage.setItem("exr-palette-height", palette.style.flex) } catch (_) {}
    }

    window.addEventListener("pointermove", move)
    window.addEventListener("pointerup", up)
  },

  restorePanelSplit() {
    try {
      const flex = localStorage.getItem("exr-palette-height")
      const palette = this.el.querySelector("[data-exr-palette]")
      if (flex && palette) palette.style.flex = flex
    } catch (_) {}
  },

  // ---- Keyboard ----

  keyDown(e) {
    if (e.defaultPrevented) return
    const meta = e.metaKey || e.ctrlKey
    const key = e.key.toLowerCase()

    if (meta && key === "s") {
      e.preventDefault()
      this.inline.finish()
      this.push("save")
      return
    }

    if (this.inline.active || isTyping(e.target) || isTyping(document.activeElement)) return
    if (!this.el.isConnected) return

    const selected = this.el.dataset.selected
    const isRoot = selected && selected === this.el.dataset.root

    if (meta && key === "z") {
      e.preventDefault()
      this.push(e.shiftKey ? "redo" : "undo")
    } else if (meta && key === "y") {
      e.preventDefault()
      this.push("redo")
    } else if (meta && key === "d" && selected && !isRoot) {
      e.preventDefault()
      this.push("duplicate")
    } else if (meta && key === "c" && selected && !isRoot && !hasTextSelection()) {
      this.push("copy")
    } else if (meta && key === "v") {
      this.push("paste")
    } else if ((key === "delete" || key === "backspace") && selected && !isRoot) {
      e.preventDefault()
      this.push("delete")
    } else if (key === "escape") {
      if (selected) this.push(isRoot ? "deselect" : "select_parent")
    } else if ((key === "arrowup" || key === "arrowdown") && selected && !isRoot) {
      e.preventDefault()
      const dir = key === "arrowup" ? "up" : "down"
      this.push(e.altKey ? "move_selected" : "select_sibling", { dir })
    } else if (key === "/") {
      const search = this.el.querySelector("[data-exr-palette-search]")
      if (search) {
        e.preventDefault()
        search.focus()
      }
    }
  }
}

function hasTextSelection() {
  const selection = window.getSelection()
  return selection && selection.toString().length > 0
}
