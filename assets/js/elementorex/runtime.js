// Runtime of the public site: what some blocks need in the browser.
//
//   - the countdown ticks every second (the server renders its first value)
//   - the loop grid's "Load more" button and infinite scroll fetch the next
//     page of the loop and append its items (without JavaScript they are
//     plain links to that page)
//   - filter forms apply on change (or with their button) and replace only
//     their loop grid with the filtered one (without JavaScript they are plain
//     GET forms that reload the page)
//
//   import {initElementorex} from "elementorex_cms/runtime"
//   initElementorex()            // the whole page
//
// or, inside LiveViews, the `ElementorexRuntime` hook on the element that holds
// the document.

const timers = new WeakMap()
const loops = new WeakMap()
const forms = new WeakMap()

export function initElementorex(root = document) {
  if (!root || !root.querySelectorAll) return
  for (const el of root.querySelectorAll("[data-ex-countdown]")) startCountdown(el)
  for (const el of root.querySelectorAll("[data-ex-loop-more]")) startLoopMore(el)
  for (const form of root.querySelectorAll("form[data-ex-filters]")) startFilters(form)
}

export function stopElementorex(root = document) {
  if (!root || !root.querySelectorAll) return
  for (const el of root.querySelectorAll("[data-ex-countdown]")) {
    clearInterval(timers.get(el))
    timers.delete(el)
  }
  for (const el of root.querySelectorAll("[data-ex-loop-more]")) stopLoopMore(el)
  for (const form of root.querySelectorAll("form[data-ex-filters]")) stopFilters(form)
}

function startCountdown(el) {
  if (timers.has(el)) return
  const target = Date.parse(el.dataset.exCountdown)
  if (Number.isNaN(target)) return

  const tick = () => {
    const seconds = Math.max(0, Math.floor((target - Date.now()) / 1000))
    const parts = {
      days: Math.floor(seconds / 86400),
      hours: Math.floor(seconds / 3600) % 24,
      minutes: Math.floor(seconds / 60) % 60,
      seconds: seconds % 60
    }

    for (const unit of el.querySelectorAll("[data-ex-unit]")) {
      const value = parts[unit.dataset.exUnit]
      const wrapper = unit.firstElementChild
      const span = wrapper && wrapper.firstElementChild
      if (!span || value === undefined) continue
      wrapper.classList.toggle("countdown", value <= 99)
      if (value <= 99) span.style.setProperty("--value", value)
      else span.style.removeProperty("--value")
      span.setAttribute("aria-label", value)
      span.textContent = value
    }

    if (seconds === 0) {
      clearInterval(timers.get(el))
      const text = el.dataset.exExpired
      if (text && !el.querySelector("[data-ex-expired-text]")) {
        const done = document.createElement("p")
        done.setAttribute("data-ex-expired-text", "")
        done.className = "w-full text-center font-semibold"
        done.textContent = text
        el.appendChild(done)
      }
    }
  }

  tick()
  timers.set(el, setInterval(tick, 1000))
}

// ---- Loop grid: load more and infinite scroll ----
//
// `el` is the last cell of the loop's grid: `data-ex-loop-more` ("click" or
// "scroll") and `data-ex-next` (the query string of the next page). The next
// page is fetched like any page of the site; the loop is found in it by its
// node id and its items are added before `el`.

function startLoopMore(el) {
  if (loops.has(el)) return
  const state = { loading: false, observer: null }
  loops.set(el, state)

  const button = el.querySelector("[data-ex-loop-button]")
  state.onClick = (e) => {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.button > 0) return
    e.preventDefault()
    loadMore(el)
  }
  button && button.addEventListener("click", state.onClick)

  if (el.dataset.exLoopMore === "scroll" && "IntersectionObserver" in window) {
    // The button stays as the way to the next page without JavaScript.
    button && (button.hidden = true)
    state.observer = new IntersectionObserver(
      (entries) => entries.some((entry) => entry.isIntersecting) && loadMore(el),
      { rootMargin: "0px 0px 400px 0px" }
    )
    state.observer.observe(el)
  }
}

function stopLoopMore(el) {
  const state = loops.get(el)
  if (!state) return
  state.observer && state.observer.disconnect()
  const button = el.querySelector("[data-ex-loop-button]")
  button && button.removeEventListener("click", state.onClick)
  loops.delete(el)
}

async function loadMore(el) {
  const state = loops.get(el)
  const next = el.dataset.exNext
  const loop = el.parentElement
  const id = loop && loop.getAttribute("data-ex-id")
  if (!state || state.loading || !next || !id) return

  const url = new URL(next, window.location.href)
  state.loading = true
  setLoading(el, true)

  try {
    const response = await fetch(url, { credentials: "same-origin", headers: { Accept: "text/html" } })
    if (!response.ok) throw new Error(`HTTP ${response.status}`)

    const page = new DOMParser().parseFromString(await response.text(), "text/html")
    const fresh = page.querySelector(`[data-ex-id="${CSS.escape(id)}"]`)
    if (!fresh) throw new Error("the loop is not in the next page")

    const added = []
    for (const item of fresh.querySelectorAll(":scope > [data-ex-loop-item]")) {
      const copy = document.importNode(item, true)
      loop.insertBefore(copy, el)
      added.push(copy)
    }

    const more = fresh.querySelector(":scope > [data-ex-loop-more]")
    if (more && more.dataset.exNext) {
      el.dataset.exNext = more.dataset.exNext
      const button = el.querySelector("[data-ex-loop-button]")
      const href = more.querySelector("[data-ex-loop-button]")?.getAttribute("href")
      button && href && button.setAttribute("href", href)
    } else {
      stopLoopMore(el)
      el.remove()
    }

    for (const item of added) initElementorex(item)
    loop.dispatchEvent(new CustomEvent("elementorex:loaded", { bubbles: true, detail: { items: added, url: url.href } }))
  } catch (_error) {
    // Whatever went wrong, the next page is still a page: go there.
    stopLoopMore(el)
    window.location.assign(url)
    return
  } finally {
    state.loading = false
    if (el.isConnected) setLoading(el, false)
  }

  // Infinite scroll: if the end of the grid is still in view, keep going.
  if (el.isConnected && state.observer) {
    state.observer.unobserve(el)
    state.observer.observe(el)
  }
}

function setLoading(el, loading) {
  el.toggleAttribute("aria-busy", loading)
  const spinner = el.querySelector("[data-ex-loop-loading]")
  spinner && spinner.classList.toggle("hidden", !loading)
  const button = el.querySelector("[data-ex-loop-button]")
  if (button) button.classList.toggle("btn-disabled", loading)
}

// ---- Filter forms ----
//
// `form[data-ex-filters]` carries the key of its loop (`data-ex-filters`), the
// loop's node id (`data-ex-loop`) and when it applies (`data-ex-filters-submit`:
// "change" or "button"). Applying fetches the page with the form's params and
// swaps the loop grid for the one in it.

function startFilters(form) {
  if (forms.has(form)) return
  const state = { timer: null, controller: null }
  const auto = form.dataset.exFiltersSubmit === "change"
  forms.set(form, state)

  state.onSubmit = (e) => {
    e.preventDefault()
    applyFilters(form)
  }

  // Choices apply at once; typed text waits for a pause.
  state.onChange = (e) => {
    if (!auto || !e.target.name || e.target.matches("[data-ex-filter-input=text]")) return
    applyFilters(form)
  }

  state.onInput = (e) => {
    if (!auto || !e.target.matches("[data-ex-filter-input=text]")) return
    clearTimeout(state.timer)
    state.timer = setTimeout(() => applyFilters(form), 400)
  }

  state.onReset = (e) => {
    if (e.metaKey || e.ctrlKey || e.shiftKey || e.button > 0) return
    e.preventDefault()
    for (const el of form.elements) {
      if (!el.name || el.type === "hidden") continue
      if (el.type === "checkbox" || el.type === "radio") el.checked = el.value === "" && el.type === "radio"
      else el.value = ""
    }
    applyFilters(form)
  }

  form.addEventListener("submit", state.onSubmit)
  form.addEventListener("change", state.onChange)
  form.addEventListener("input", state.onInput)
  const reset = form.querySelector("[data-ex-filters-reset]")
  reset && reset.addEventListener("click", state.onReset)
}

function stopFilters(form) {
  const state = forms.get(form)
  if (!state) return
  clearTimeout(state.timer)
  state.controller && state.controller.abort()
  form.removeEventListener("submit", state.onSubmit)
  form.removeEventListener("change", state.onChange)
  form.removeEventListener("input", state.onInput)
  const reset = form.querySelector("[data-ex-filters-reset]")
  reset && reset.removeEventListener("click", state.onReset)
  forms.delete(form)
}

// The address of the filtered page: the form's params without empty values.
function filtersUrl(form) {
  const url = new URL(window.location.href)
  const params = new URLSearchParams()
  for (const [name, value] of new FormData(form)) {
    if (typeof value === "string" && value.trim() !== "") params.append(name, value)
  }
  url.search = params.toString()
  url.hash = ""
  return url
}

async function applyFilters(form) {
  const state = forms.get(form)
  if (!state) return
  clearTimeout(state.timer)

  const url = filtersUrl(form)
  const id = form.dataset.exLoop
  const loop = id && document.querySelector(`[data-ex-id="${CSS.escape(id)}"]`)
  if (!loop) return window.location.assign(url)

  // A newer change wins over a request still on its way.
  state.controller && state.controller.abort()
  const controller = new AbortController()
  state.controller = controller
  loop.setAttribute("aria-busy", "true")
  loop.style.transition = "opacity .15s"
  loop.style.opacity = "0.55"

  try {
    const response = await fetch(url, {
      credentials: "same-origin",
      headers: { Accept: "text/html" },
      signal: controller.signal
    })
    if (!response.ok) throw new Error(`HTTP ${response.status}`)

    const page = new DOMParser().parseFromString(await response.text(), "text/html")
    const fresh = page.querySelector(`[data-ex-id="${CSS.escape(id)}"]`)
    if (!fresh) throw new Error("the loop is not in the filtered page")

    stopElementorex(loop)
    const copy = document.importNode(fresh, true)
    loop.replaceWith(copy)
    initElementorex(copy)
    window.history.replaceState(window.history.state, "", url)
    updateReset(form)
    copy.dispatchEvent(new CustomEvent("elementorex:filtered", { bubbles: true, detail: { url: url.href } }))
  } catch (error) {
    if (error.name === "AbortError") return
    // Whatever went wrong, the filtered page is still a page: go there.
    window.location.assign(url)
  } finally {
    if (state.controller === controller) state.controller = null
    loop.removeAttribute("aria-busy")
    loop.style.opacity = ""
  }
}

// The clear button shows while something is filtered.
function updateReset(form) {
  const reset = form.querySelector("[data-ex-filters-reset]")
  if (!reset) return
  const prefix = `${form.dataset.exFilters}[`

  reset.hidden = !Array.from(new FormData(form)).some(
    ([name, value]) =>
      name.startsWith(prefix) && !name.startsWith(`${prefix}sort]`) && String(value).trim() !== ""
  )
}

export const ElementorexRuntime = {
  mounted() {
    initElementorex(this.el)
  },
  updated() {
    initElementorex(this.el)
  },
  destroyed() {
    stopElementorex(this.el)
  }
}

export default ElementorexRuntime
