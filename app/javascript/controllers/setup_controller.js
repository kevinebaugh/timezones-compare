import { Controller } from "@hotwired/stimulus"

// Starts setup as soon as the screen appears, and walks through what's
// happening while the server does the work.
export default class extends Controller {
  static targets = ["form", "step"]
  static values = { steps: Array, interval: { type: Number, default: 1400 } }

  connect() {
    this.index = 0
    this.timer = setInterval(() => this.advance(), this.intervalValue)
    requestAnimationFrame(() => this.formTarget.requestSubmit())
  }

  disconnect() {
    clearInterval(this.timer)
  }

  advance() {
    if (this.index >= this.stepsValue.length - 1) return clearInterval(this.timer)
    this.index += 1
    this.stepTarget.classList.add("is-leaving")
    setTimeout(() => {
      this.stepTarget.textContent = this.stepsValue[this.index]
      this.stepTarget.classList.remove("is-leaving")
    }, 180)
  }
}
