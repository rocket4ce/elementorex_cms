// Runtime of the public site: what some blocks need in the browser.
// Today: the countdown ticks every second (the server renders its first value).
//
//   import {initElementorex} from "elementorex_cms/runtime"
//   initElementorex()            // the whole page
//
// or, inside LiveViews, the `ElementorexRuntime` hook on the element that holds
// the document.

const timers = new WeakMap()

export function initElementorex(root = document) {
  if (!root || !root.querySelectorAll) return
  for (const el of root.querySelectorAll("[data-ex-countdown]")) startCountdown(el)
}

export function stopElementorex(root = document) {
  if (!root || !root.querySelectorAll) return
  for (const el of root.querySelectorAll("[data-ex-countdown]")) {
    clearInterval(timers.get(el))
    timers.delete(el)
  }
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
