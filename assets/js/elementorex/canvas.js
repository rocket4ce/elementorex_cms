// The canvas iframe: its document, the helper CSS of the editor and the
// overlay layer (hover and selection boxes, the selection toolbar and the drop
// indicator), which lives in the iframe but outside the document's content.

export const CANVAS_CSS = `
html, body { min-height: 100%; }
body { margin: 0; }
[data-exr-mount] { display: block; }
[data-exr-mount] a, [data-exr-mount] button { cursor: default; }
.exr-empty {
  display: flex; align-items: center; justify-content: center; min-height: 72px; width: 100%;
  padding: 14px; border: 1.5px dashed rgb(124 58 237 / .45); border-radius: 10px;
  background: rgb(124 58 237 / .04); color: rgb(91 33 182 / .8);
  font: 500 12.5px/1.3 ui-sans-serif, system-ui, sans-serif; text-align: center;
}
[data-ex-doc] > .exr-empty { min-height: 180px; }
.exr-image-placeholder {
  display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px;
  min-width: 220px; min-height: 140px; padding: 18px; border-radius: 10px;
  background: repeating-linear-gradient(135deg, rgb(0 0 0 / .035) 0 10px, rgb(0 0 0 / .06) 10px 20px);
  color: rgb(0 0 0 / .45); font: 500 12.5px ui-sans-serif, system-ui, sans-serif;
}
.exr-image-placeholder svg { width: 32px; height: 32px; }
.exr-unknown {
  padding: 10px 12px; border: 1px dashed #e5322d; border-radius: 8px; color: #b42318;
  font: 12px ui-sans-serif, system-ui, sans-serif; background: #fff5f5;
}
[data-exr-editing] { outline: 2px solid #7c3aed !important; outline-offset: 3px; cursor: text !important; }
[data-exr-editing]:focus { outline-color: #7c3aed; }
#exr-layer { position: absolute; left: 0; top: 0; width: 0; height: 0; z-index: 2147483000; pointer-events: none; }
.exr-box { position: absolute; display: none; pointer-events: none; border-radius: 2px; }
.exr-box.is-visible { display: block; }
.exr-box-hover { outline: 1px dashed rgb(22 123 255 / .85); outline-offset: 0; }
.exr-box-selected { outline: 2px solid var(--exr-primary, #167bff); outline-offset: 0; }
.exr-box-drop { outline: 2px dashed #7c3aed; background: rgb(124 58 237 / .06); }
.exr-chip {
  position: absolute; left: -2px; bottom: 100%; display: inline-flex; align-items: stretch; height: 22px;
  border-radius: 4px 4px 0 0; overflow: hidden; background: var(--exr-primary, #167bff); color: #fff;
  font: 500 11.5px/22px ui-sans-serif, system-ui, -apple-system, sans-serif; white-space: nowrap;
  box-shadow: 0 2px 6px rgb(0 0 0 / .15); pointer-events: auto; letter-spacing: 0; text-transform: none;
}
.exr-chip.is-inside { bottom: auto; top: 0; border-radius: 0 0 4px 0; }
.exr-box-hover .exr-chip { background: rgb(22 123 255 / .85); pointer-events: none; }
.exr-chip span, .exr-chip button {
  display: inline-flex; align-items: center; gap: 4px; padding: 0 7px; border: 0; margin: 0;
  background: transparent; color: inherit; font: inherit; cursor: pointer;
}
.exr-chip button + button, .exr-chip span + button { border-left: 1px solid rgb(255 255 255 / .25); padding: 0 6px; }
.exr-chip button:hover { background: rgb(255 255 255 / .16); }
.exr-chip [data-exr-grip] { cursor: grab; }
.exr-chip svg { width: 13px; height: 13px; }
.exr-drop-line {
  position: absolute; display: none; background: #7c3aed; border-radius: 3px; pointer-events: none;
  box-shadow: 0 0 0 2px rgb(255 255 255 / .8);
}
.exr-drop-line.is-visible { display: block; }
.exr-drop-label {
  position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); padding: 2px 8px;
  border-radius: 999px; background: #7c3aed; color: #fff; white-space: nowrap;
  font: 600 10.5px/1.4 ui-sans-serif, system-ui, sans-serif;
}
.exr-inline-bar {
  position: absolute; display: none; gap: 2px; padding: 4px; border-radius: 8px; background: #1e2328;
  box-shadow: 0 10px 24px rgb(0 0 0 / .25); pointer-events: auto;
}
.exr-inline-bar.is-visible { display: inline-flex; }
.exr-inline-bar button {
  display: inline-grid; place-items: center; width: 28px; height: 28px; border: 0; border-radius: 5px;
  background: transparent; color: rgb(255 255 255 / .85); cursor: pointer; font: 600 13px ui-sans-serif, system-ui, sans-serif;
}
.exr-inline-bar button:hover { background: rgb(255 255 255 / .14); color: #fff; }
.exr-inline-bar svg { width: 15px; height: 15px; }
.exr-preview-mode .exr-empty, .exr-preview-mode .exr-image-placeholder { display: none; }
`

const ICONS = {
  grip: '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M7 4a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm0 6a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm-1.5 7.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3ZM16 4a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Zm-1.5 7.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3Zm1.5 4.5a1.5 1.5 0 1 1-3 0 1.5 1.5 0 0 1 3 0Z"/></svg>',
  up: '<svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M10 17a.75.75 0 0 1-.75-.75V5.612L5.29 9.77a.75.75 0 0 1-1.08-1.04l5.25-5.5a.75.75 0 0 1 1.08 0l5.25 5.5a.75.75 0 1 1-1.08 1.04l-3.96-4.158V16.25A.75.75 0 0 1 10 17Z" clip-rule="evenodd"/></svg>',
  copy: '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M7 3.5A1.5 1.5 0 0 1 8.5 2h3.879a1.5 1.5 0 0 1 1.06.44l3.122 3.12A1.5 1.5 0 0 1 17 6.622V12.5a1.5 1.5 0 0 1-1.5 1.5h-1v-3.379a3 3 0 0 0-.879-2.121L10.5 5.379A3 3 0 0 0 8.379 4.5H7v-1Z"/><path d="M4.5 6A1.5 1.5 0 0 0 3 7.5v9A1.5 1.5 0 0 0 4.5 18h7a1.5 1.5 0 0 0 1.5-1.5v-5.879a1.5 1.5 0 0 0-.44-1.06L9.44 6.439A1.5 1.5 0 0 0 8.378 6H4.5Z"/></svg>',
  trash: '<svg viewBox="0 0 20 20" fill="currentColor"><path fill-rule="evenodd" d="M8.75 1A2.75 2.75 0 0 0 6 3.75v.443c-.795.077-1.584.176-2.365.298a.75.75 0 1 0 .23 1.482l.149-.022.841 10.518A2.75 2.75 0 0 0 7.596 19h4.807a2.75 2.75 0 0 0 2.742-2.53l.841-10.52.149.023a.75.75 0 0 0 .23-1.482A41.03 41.03 0 0 0 14 4.193V3.75A2.75 2.75 0 0 0 11.25 1h-2.5ZM10 4c.84 0 1.673.025 2.5.075V3.75c0-.69-.56-1.25-1.25-1.25h-2.5c-.69 0-1.25.56-1.25 1.25v.325C8.327 4.025 9.16 4 10 4ZM8.58 7.72a.75.75 0 0 0-1.5.06l.3 7.5a.75.75 0 1 0 1.5-.06l-.3-7.5Zm4.34.06a.75.75 0 1 0-1.5-.06l-.3 7.5a.75.75 0 1 0 1.5.06l.3-7.5Z" clip-rule="evenodd"/></svg>',
  link: '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M12.232 4.232a2.5 2.5 0 0 1 3.536 3.536l-1.225 1.224a.75.75 0 0 0 1.061 1.06l1.224-1.224a4 4 0 0 0-5.656-5.656l-3 3a4 4 0 0 0 .225 5.865.75.75 0 0 0 .977-1.138 2.5 2.5 0 0 1-.142-3.667l3-3Z"/><path d="M11.603 7.963a.75.75 0 0 0-.977 1.138 2.5 2.5 0 0 1 .142 3.667l-3 3a2.5 2.5 0 0 1-3.536-3.536l1.225-1.224a.75.75 0 0 0-1.061-1.06l-1.224 1.224a4 4 0 1 0 5.656 5.656l3-3a4 4 0 0 0-.225-5.865Z"/></svg>',
  clear: '<svg viewBox="0 0 20 20" fill="currentColor"><path d="M6.28 5.22a.75.75 0 0 0-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 1 0 1.06 1.06L10 11.06l3.72 3.72a.75.75 0 1 0 1.06-1.06L11.06 10l3.72-3.72a.75.75 0 0 0-1.06-1.06L10 8.94 6.28 5.22Z"/></svg>'
}

export function icon(name) {
  return ICONS[name] || ""
}

const escapeAttr = (value) =>
  String(value).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;")

// The iframe document: the host's stylesheets, the editor helpers and the
// frame with its mount point.
export function canvasDocument(config) {
  const attrs = Object.entries(config.htmlAttrs || {})
    .map(([name, value]) => ` ${name.replace(/[^\w:-]/g, "")}="${escapeAttr(value)}"`)
    .join("")

  const links = (config.stylesheets || [])
    .map((href) => `<link rel="stylesheet" href="${escapeAttr(href)}">`)
    .join("")

  return `<!doctype html><html${attrs}><head><meta charset="utf-8">` +
    `<meta name="viewport" content="width=device-width, initial-scale=1">${links}${config.head || ""}` +
    `<style id="exr-canvas-css">${CANVAS_CSS}</style><style id="exr-doc-css"></style></head>` +
    `<body class="${escapeAttr(config.bodyClass || "")}">${config.frame}</body></html>`
}

// Boxes drawn over the canvas content, positioned in document coordinates.
export class Overlay {
  constructor(doc, labels, blocks) {
    this.doc = doc
    this.labels = labels
    this.blocks = blocks
    this.layer = doc.createElement("div")
    this.layer.id = "exr-layer"
    this.hover = this.box("exr-box exr-box-hover")
    this.selected = this.box("exr-box exr-box-selected")
    this.dropBox = this.box("exr-box exr-box-drop")
    this.line = doc.createElement("div")
    this.line.className = "exr-drop-line"
    this.line.innerHTML = '<span class="exr-drop-label"></span>'
    this.layer.appendChild(this.line)
    doc.body.appendChild(this.layer)
    this.selectedId = null
    this.hoverId = null
  }

  box(className) {
    const el = this.doc.createElement("div")
    el.className = className
    this.layer.appendChild(el)
    return el
  }

  element(id) {
    return id ? this.doc.querySelector(`[data-ex-id="${CSS.escape(id)}"]`) : null
  }

  label(el) {
    const type = el.getAttribute("data-ex-type")
    return el.getAttribute("data-ex-label") || (this.blocks[type] && this.blocks[type].label) || type
  }

  place(box, el) {
    if (!el || !el.isConnected) {
      box.classList.remove("is-visible")
      return null
    }

    const rect = el.getBoundingClientRect()
    const win = this.doc.defaultView
    box.style.left = `${rect.left + win.scrollX}px`
    box.style.top = `${rect.top + win.scrollY}px`
    box.style.width = `${Math.max(rect.width, 2)}px`
    box.style.height = `${Math.max(rect.height, 2)}px`
    box.classList.add("is-visible")
    return rect
  }

  setHover(id) {
    this.hoverId = id
    if (!id || id === this.selectedId) {
      this.hover.classList.remove("is-visible")
      return
    }

    const el = this.element(id)
    const rect = this.place(this.hover, el)
    if (!rect) return

    this.hover.innerHTML = `<div class="exr-chip${rect.top < 24 ? " is-inside" : ""}"><span>${escapeAttr(this.label(el))}</span></div>`
  }

  setSelected(id, isRoot) {
    this.selectedId = id
    const el = this.element(id)
    const rect = this.place(this.selected, el)

    if (!rect) {
      this.selected.innerHTML = ""
      return
    }

    const chip = isRoot
      ? `<span>${escapeAttr(this.label(el))}</span>`
      : `<button type="button" data-exr-grip title="${escapeAttr(this.labels.move)}">${icon("grip")}${escapeAttr(this.label(el))}</button>` +
        `<button type="button" data-exr-chip="parent" title="${escapeAttr(this.labels.parent)}">${icon("up")}</button>` +
        `<button type="button" data-exr-chip="duplicate" title="${escapeAttr(this.labels.duplicate)}">${icon("copy")}</button>` +
        `<button type="button" data-exr-chip="delete" title="${escapeAttr(this.labels.delete)}">${icon("trash")}</button>`

    this.selected.innerHTML = `<div class="exr-chip${rect.top < 24 ? " is-inside" : ""}">${chip}</div>`
    if (this.hoverId === id) this.hover.classList.remove("is-visible")
  }

  refresh() {
    if (this.selectedId) {
      const isRoot = this.element(this.selectedId)?.hasAttribute("data-ex-doc")
      this.setSelected(this.selectedId, isRoot)
    }
    if (this.hoverId) this.setHover(this.hoverId)
  }

  showLine(rect, axis, text) {
    const win = this.doc.defaultView
    const style = this.line.style
    this.dropBox.classList.remove("is-visible")

    if (axis === "x") {
      style.left = `${rect.x + win.scrollX - 1.5}px`
      style.top = `${rect.y + win.scrollY}px`
      style.width = "3px"
      style.height = `${rect.size}px`
    } else {
      style.left = `${rect.x + win.scrollX}px`
      style.top = `${rect.y + win.scrollY - 1.5}px`
      style.width = `${rect.size}px`
      style.height = "3px"
    }

    this.line.querySelector(".exr-drop-label").textContent = text
    this.line.classList.add("is-visible")
  }

  showInside(el, text) {
    this.line.classList.remove("is-visible")
    this.place(this.dropBox, el)
    this.dropBox.innerHTML = `<div class="exr-chip is-inside" style="background:#7c3aed"><span>${escapeAttr(text)}</span></div>`
  }

  hideDrop() {
    this.line.classList.remove("is-visible")
    this.dropBox.classList.remove("is-visible")
  }

  destroy() {
    this.layer.remove()
  }
}
