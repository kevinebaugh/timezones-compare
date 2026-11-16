import { Controller } from "@hotwired/stimulus"

// Filters the groups-and-channels menu as you type (a leading @ or # is
// ignored); Enter opens the first match. Empty sections hide their heading.
export default class extends Controller {
  static targets = ["input", "item", "empty", "heading"]

  // After the click that opened the menu has finished focusing its button.
  focus() {
    if (this.element.open) setTimeout(() => this.inputTarget.focus(), 30)
  }

  filter() {
    const query = this.inputTarget.value.trim().toLowerCase().replace(/^[@#]/, "")
    let shown = 0
    this.itemTargets.forEach((item) => {
      // "Your tabs" entries still showing as tabs stay out of the list, and
      // people (search-only) appear only once something's typed.
      const match = item.dataset.overflow !== "false" &&
        (query ? item.dataset.name.includes(query) : item.dataset.searchOnly !== "true")
      item.hidden = !match
      if (match) shown++
    })
    this.emptyTarget.hidden = shown > 0
    this.headingTargets.forEach((heading) => {
      heading.hidden = !this.itemTargets.some((item) => !item.hidden && item.dataset.section === heading.dataset.section)
    })
  }

  open(event) {
    const first = this.itemTargets.find((item) => !item.hidden)
    if (!first) return
    event.preventDefault()
    first.click()
  }
}
