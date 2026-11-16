import { Controller } from "@hotwired/stimulus"

// The "Compare people" button counts who's ticked and stays off until someone is.
// Recounts when a box changes and when the list (a lazy frame) arrives.
export default class extends Controller {
  static targets = ["submit"]

  connect() {
    this.label = this.submitTarget.textContent.trim()
  }

  // Back to a new comparison: just you (listed first) ticked.
  clear() {
    this.element.querySelectorAll("input[name='p[]']").forEach((box, i) => { box.checked = i === 0 })
    this.count()
  }

  count() {
    const ticked = this.element.querySelectorAll("input[name='p[]']:checked").length
    const text = ticked ? `${this.label} (${ticked})` : this.label
    this.submitTarget.disabled = ticked === 0
    if (this.submitTarget.textContent !== text) this.submitTarget.textContent = text
  }
}
