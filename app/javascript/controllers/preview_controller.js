import { Controller } from "@hotwired/stimulus"

// Drives the home page's live board, which is the real board: redraws it for
// the visitor's own time zone, then drifts a pointer slowly across the hours
// until the visitor touches it. Calm for anyone who prefers reduced motion.
export default class extends Controller {
  static values = { tz: String, url: String }
  static STEP_MS = 1600

  connect() {
    const frame = this.element.closest("turbo-frame")
    const visitorTz = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (frame && !frame.src && visitorTz && visitorTz !== this.tzValue) {
      frame.src = `${this.urlValue}?tz=${encodeURIComponent(visitorTz)}`
      return
    }
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.table = this.element.querySelector(".tz-table")
    this.strip = this.element.querySelector(".tz-strip")
    if (!this.table || !this.strip) return
    this.columns = this.strip.children.length
    this.col = this.nowColumn()
    this.handOff = (event) => { if (event.isTrusted) this.stop() }
    for (const type of ["pointerdown", "pointermove", "keydown", "wheel", "touchstart"]) {
      this.element.addEventListener(type, this.handOff, { passive: true })
    }
    this.timer = setInterval(() => this.step(), this.constructor.STEP_MS)
    this.step()
  }

  disconnect() {
    this.stop()
  }

  stop() {
    clearInterval(this.timer)
    for (const type of ["pointerdown", "pointermove", "keydown", "wheel", "touchstart"]) {
      this.element.removeEventListener(type, this.handOff)
    }
  }

  // Point at the next hour exactly as a visitor would.
  step() {
    const { left, width, top } = this.strip.getBoundingClientRect()
    const clientX = left + (this.col + 0.05) * (width / this.columns) // the top of each hour
    this.table.dispatchEvent(new PointerEvent("pointermove", { bubbles: true, clientX, clientY: top + 4 }))
    this.follow(clientX - left)
    this.col = (this.col + 1) % this.columns
  }

  // On narrow screens, keep the drifting hour in view.
  follow(x) {
    const scroller = this.element.querySelector(".tz-scroll")
    if (!scroller || scroller.scrollWidth <= scroller.clientWidth) return
    const label = this.strip.getBoundingClientRect().left - this.table.getBoundingClientRect().left
    const visible = scroller.clientWidth - label
    if (x < scroller.scrollLeft + visible * 0.15 || x > scroller.scrollLeft + visible * 0.85) {
      scroller.scrollTo({ left: Math.round(Math.max(0, x - visible / 3)), behavior: "smooth" })
    }
  }

  nowColumn() {
    const starts = Number(this.element.querySelector("[data-grid-starts-at-value]")?.dataset.gridStartsAtValue)
    const col = Math.floor((Date.now() / 1000 - starts) / 3600)
    return col >= 0 && col < this.columns ? col : 0
  }
}
