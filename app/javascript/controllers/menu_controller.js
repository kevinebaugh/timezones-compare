import { Controller } from "@hotwired/stimulus"

// A <details> dropdown that closes on an outside click or Escape. With a
// panel target, the panel opens on whichever side of its trigger has more
// room, and is kept on screen.
export default class extends Controller {
  static targets = ["panel"]
  static MARGIN = 8

  toggled() {
    if (this.element.open) {
      this.outside = (event) => { if (!this.element.contains(event.target)) this.close() }
      this.escape = (event) => { if (event.key === "Escape") this.close() }
      this.refit = () => this.fit()
      document.addEventListener("click", this.outside)
      document.addEventListener("keydown", this.escape)
      window.addEventListener("resize", this.refit)
      window.addEventListener("scroll", this.refit, { passive: true })
      this.fit()
    } else {
      this.unlisten()
    }
  }

  close() {
    this.element.open = false
    this.unlisten()
  }

  disconnect() {
    this.unlisten()
  }

  unlisten() {
    document.removeEventListener("click", this.outside)
    document.removeEventListener("keydown", this.escape)
    window.removeEventListener("resize", this.refit)
    window.removeEventListener("scroll", this.refit)
  }

  // Pin the open panel to the screen beside its trigger: above or below,
  // whichever has more room, sized to fit and slid sideways to stay visible.
  // Fixed positioning never widens the page, in left-to-right or right-to-left.
  fit() {
    if (!this.hasPanelTarget) return
    const panel = this.panelTarget
    const margin = this.constructor.MARGIN
    const gap = 6
    const view = { width: document.documentElement.clientWidth, height: document.documentElement.clientHeight }
    const trigger = this.element.querySelector("summary").getBoundingClientRect()

    panel.classList.add("is-pinned")
    panel.style.maxHeight = "none"
    const width = Math.min(panel.offsetWidth, view.width - margin * 2)
    const needed = panel.scrollHeight
    const above = trigger.top - gap - margin
    const below = view.height - trigger.bottom - gap - margin
    const downward = below >= needed || below >= above
    const height = Math.max(160, Math.min(needed, Math.floor(downward ? below : above)))

    const rtl = getComputedStyle(this.element).direction === "rtl"
    const start = rtl ? trigger.right - width : trigger.left
    const left = Math.min(Math.max(margin, start), view.width - margin - width)

    panel.style.maxHeight = `${height}px`
    panel.style.width = `${width}px`
    panel.style.left = `${Math.round(left)}px`
    panel.style.top = `${Math.round(downward ? trigger.bottom + gap : trigger.top - gap - height)}px`
  }
}
