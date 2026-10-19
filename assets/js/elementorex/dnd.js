// Drag and drop for the editor.
//
// Sources: palette tiles (new blocks), rows of the structure tree and the grip
// of the selected block on the canvas. Targets: the canvas (an iframe) and the
// tree. The drag is driven by pointer events: once it starts, a transparent
// shield covers the page so the pointer keeps reporting to this document even
// over the iframe, and the drop position is computed with elementFromPoint in
// the iframe's coordinates. Pointer events still delivered to the iframe (the
// frame keeps the mouse while the button is held) are handled too.

const THRESHOLD = 5
const EDGE = 40

export class Dragger {
  constructor(editor) {
    this.editor = editor
    this.armed = null
    this.drag = null
    this.justDragged = false
    this.onMove = (e) => this.move(e, false)
    this.onUp = (e) => this.up(e, false)
    this.onFrameMove = (e) => this.move(e, true)
    this.onFrameUp = (e) => this.up(e, true)
    this.onKey = (e) => {
      if (e.key === "Escape" && (this.drag || this.armed)) {
        e.preventDefault()
        this.cleanup()
      }
    }
  }

  // `source`: {kind: "new", type} or {kind: "move", id, type}
  arm(source, event, fromFrame = false) {
    if (event.button !== 0) return
    const point = this.toParent(event, fromFrame)
    this.armed = { source, x: point.x, y: point.y, el: source.el }
    this.listen(true)
  }

  listen(on) {
    const method = on ? "addEventListener" : "removeEventListener"
    window[method]("pointermove", this.onMove, true)
    window[method]("pointerup", this.onUp, true)
    window[method]("keydown", this.onKey, true)
    const frameWin = this.editor.frameWin
    if (frameWin) {
      frameWin[method]("pointermove", this.onFrameMove, true)
      frameWin[method]("pointerup", this.onFrameUp, true)
      frameWin[method]("keydown", this.onKey, true)
    }
  }

  toParent(event, fromFrame) {
    if (!fromFrame) return { x: event.clientX, y: event.clientY }
    const rect = this.editor.iframe.getBoundingClientRect()
    const scale = this.editor.scale || 1
    return { x: rect.left + event.clientX * scale, y: rect.top + event.clientY * scale }
  }

  move(event, fromFrame) {
    if (!this.armed && !this.drag) return
    const point = this.toParent(event, fromFrame)

    if (!this.drag) {
      if (Math.hypot(point.x - this.armed.x, point.y - this.armed.y) < THRESHOLD) return
      this.start()
    }

    event.preventDefault()
    this.drag.point = point
    this.ghost.style.transform = `translate(${point.x + 14}px, ${point.y + 12}px)`
    this.target = this.findTarget(point)
    this.paint()
  }

  up(event, fromFrame) {
    if (!this.drag) {
      this.cleanup()
      return
    }

    event.preventDefault()
    const { source } = this.drag
    const target = this.target

    if (target) {
      if (source.kind === "new") {
        this.editor.push("insert", { type: source.type, parent: target.parent, index: target.index })
      } else {
        this.editor.push("move", { id: source.id, parent: target.parent, index: target.index })
      }
    }

    this.justDragged = true
    setTimeout(() => (this.justDragged = false), 60)
    this.cleanup()
  }

  start() {
    const { source } = this.armed
    this.drag = { source, point: null }
    this.armed = null

    const doc = document
    this.shield = doc.createElement("div")
    this.shield.className = "exr-drag-shield"
    this.ghost = doc.createElement("div")
    this.ghost.className = "exr-drag-ghost"
    const block = this.editor.blocks[source.type] || {}
    this.ghost.innerHTML = `${block.icon || ""}<span></span>`
    this.ghost.querySelector("span").textContent = block.label || source.type
    doc.body.append(this.shield, this.ghost)
    doc.body.classList.add("exr-dragging")
    source.el && source.el.classList.add("is-dragging")

    // While moving a block, its element (and its children) cannot be a target.
    this.dragged = source.kind === "move" ? this.editor.canvasElement(source.id) : null
    this.draggedRow = source.kind === "move" ? this.editor.treeRow(source.id)?.closest(".exr-tree-item") : null
  }

  cleanup() {
    this.listen(false)
    this.shield && this.shield.remove()
    this.ghost && this.ghost.remove()
    document.body.classList.remove("exr-dragging")
    const el = this.drag?.source.el || this.armed?.el
    el && el.classList.remove("is-dragging")
    this.clearTree()
    this.editor.overlay && this.editor.overlay.hideDrop()
    this.shield = this.ghost = this.drag = this.armed = this.target = this.dragged = this.draggedRow = null
  }

  // ---- Targets ----

  findTarget(point) {
    const frameRect = this.editor.iframe?.getBoundingClientRect()
    if (frameRect && inside(point, frameRect)) {
      const scale = this.editor.scale || 1
      const x = (point.x - frameRect.left) / scale
      const y = (point.y - frameRect.top) / scale
      this.autoScroll(y, frameRect.height / scale)
      return this.canvasTarget(x, y)
    }

    const tree = this.editor.el.querySelector("[data-exr-tree]")
    if (tree && inside(point, tree.getBoundingClientRect())) return this.treeTarget(point, tree)

    return null
  }

  autoScroll(y, height) {
    const win = this.editor.frameWin
    if (!win) return
    if (y < EDGE) win.scrollBy(0, -14)
    else if (y > height - EDGE) win.scrollBy(0, 14)
  }

  canvasTarget(x, y) {
    const doc = this.editor.frameDoc
    const hit = doc.elementFromPoint(x, y)
    const root = doc.querySelector("[data-ex-doc]")
    if (!root) return null

    let node = hit && hit.closest("[data-ex-id]")
    if (!node) return this.insideTarget(root, x, y)

    if (this.dragged && this.dragged.contains(node)) node = this.dragged

    if (node.hasAttribute("data-ex-container") && node !== this.dragged) {
      const rect = node.getBoundingClientRect()
      const edge = Math.min(12, rect.height / 4)
      const nearEdge = y - rect.top < edge || rect.bottom - y < edge
      if (node !== root && nearEdge && parentContainer(node)) return this.aroundTarget(node, x, y)
      return this.insideTarget(node, x, y)
    }

    return this.aroundTarget(node, x, y)
  }

  insideTarget(container, x, y) {
    const children = childBlocks(container)
    const id = container.getAttribute("data-ex-id")

    if (children.length === 0) return { canvas: true, parent: id, index: 0, inside: container }

    const axis = flowAxis(children)
    let index = children.length

    for (let i = 0; i < children.length; i++) {
      const rect = children[i].getBoundingClientRect()
      if (axis === "x" && y > rect.bottom) continue
      const mid = axis === "x" ? rect.left + rect.width / 2 : rect.top + rect.height / 2
      if ((axis === "x" ? x : y) < mid) {
        index = i
        break
      }
    }

    return { canvas: true, parent: id, index, axis, children, container }
  }

  aroundTarget(node, x, y) {
    const parent = parentContainer(node)
    if (!parent) return null

    const children = childBlocks(parent)
    const axis = flowAxis(children)
    const rect = node.getBoundingClientRect()
    const before = axis === "x" ? x < rect.left + rect.width / 2 : y < rect.top + rect.height / 2
    const index = children.indexOf(node) + (before ? 0 : 1)

    return { canvas: true, parent: parent.getAttribute("data-ex-id"), index, axis, children, container: parent }
  }

  treeTarget(point, tree) {
    const row = document
      .elementsFromPoint(point.x, point.y)
      .find((el) => el.matches && el.matches("[data-exr-tree-id]"))
    if (!row || !tree.contains(row)) return null
    if (this.draggedRow && this.draggedRow.contains(row)) return null

    const rect = row.getBoundingClientRect()
    const ratio = (point.y - rect.top) / rect.height
    const id = row.dataset.exrTreeId
    const parent = row.dataset.exrTreeParent
    const index = parseInt(row.dataset.exrTreeIndex || "0", 10)
    const container = row.dataset.exrTreeContainer === "true"

    if (!parent) return { row, mode: "inside", parent: id, index: 100000 }
    if (container && ratio > 0.25 && ratio < 0.75) return { row, mode: "inside", parent: id, index: 100000 }
    if (ratio <= 0.5) return { row, mode: "before", parent, index }
    if (container && row.dataset.exrTreeOpen === "true") return { row, mode: "inside", parent: id, index: 0 }
    return { row, mode: "after", parent, index: index + 1 }
  }

  // ---- Indicator ----

  paint() {
    const overlay = this.editor.overlay
    const target = this.target
    const block = this.editor.blocks[this.drag.source.type] || {}
    const text = (this.editor.labels.drop || "%{block}").replace("%{block}", block.label || this.drag.source.type)

    this.clearTree()
    overlay && overlay.hideDrop()
    this.ghost.classList.toggle("is-blocked", !target)

    if (!target) return

    if (target.row) {
      target.row.classList.add(`is-drop-${target.mode}`)
      return
    }

    if (target.inside) {
      overlay.showInside(target.inside, this.editor.labels.dropHere || text)
      return
    }

    overlay.showLine(lineRect(target), target.axis, text)
  }

  clearTree() {
    for (const row of this.editor.el.querySelectorAll(".is-drop-before, .is-drop-after, .is-drop-inside")) {
      row.classList.remove("is-drop-before", "is-drop-after", "is-drop-inside")
    }
  }
}

function inside(point, rect) {
  return point.x >= rect.left && point.x <= rect.right && point.y >= rect.top && point.y <= rect.bottom
}

export function parentContainer(node) {
  const parent = node.parentElement && node.parentElement.closest("[data-ex-id]")
  return parent && parent.hasAttribute("data-ex-container") ? parent : null
}

// Direct child blocks of a container (its children may sit inside wrappers).
export function childBlocks(container) {
  return Array.from(container.querySelectorAll("[data-ex-id]")).filter(
    (el) => el.parentElement.closest("[data-ex-id]") === container
  )
}

// "x" when the children sit side by side, "y" when they stack.
export function flowAxis(children) {
  if (children.length >= 2) {
    const a = children[0].getBoundingClientRect()
    const b = children[1].getBoundingClientRect()
    return b.top < a.bottom - 2 && b.left >= a.right - 2 ? "x" : "y"
  }

  if (children.length === 1) {
    const parent = children[0].parentElement
    const style = parent.ownerDocument.defaultView.getComputedStyle(parent)
    if (style.display.includes("flex") && style.flexDirection.startsWith("row")) return "x"
  }

  return "y"
}

// Where the line goes: between two children, before the first or after the last.
function lineRect({ axis, children, index, container }) {
  const rects = children.map((el) => el.getBoundingClientRect())
  const box = container.getBoundingClientRect()

  if (axis === "x") {
    const ref = rects[Math.min(index, rects.length - 1)]
    let x
    if (index === 0) x = ref.left - 4
    else if (index >= rects.length) x = rects[rects.length - 1].right + 4
    else x = (rects[index - 1].right + rects[index].left) / 2
    return { x, y: ref.top, size: ref.height }
  }

  let y
  if (index === 0) y = rects[0].top - 4
  else if (index >= rects.length) y = rects[rects.length - 1].bottom + 4
  else y = (rects[index - 1].bottom + rects[index].top) / 2

  const ref = rects[Math.min(index, rects.length - 1)]
  const left = Math.max(box.left, ref.left - 6)
  const right = Math.min(box.right, ref.right + 6)
  return { x: left, y, size: Math.max(right - left, 24) }
}
