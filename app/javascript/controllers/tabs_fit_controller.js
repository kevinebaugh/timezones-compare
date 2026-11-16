import { Controller } from "@hotwired/stimulus"

// Keeps the board tabs on one line: tabs that don't fit are hidden from the
// end (never Everyone or the board you're on), the last pill becomes "+N more",
// and the menu it opens lists exactly those tabs under "Your tabs".
export default class extends Controller {
  static targets = ["tab", "more", "overflowItem", "overflowHeading"]
  static values = { more: String }

  connect() {
    this.label = this.moreTarget.textContent.trim()
    this.observer = new ResizeObserver(() => this.schedule())
    this.observer.observe(this.element.parentElement)
    this.fit()
  }

  disconnect() {
    this.observer?.disconnect()
    cancelAnimationFrame(this.frame)
  }

  schedule() {
    cancelAnimationFrame(this.frame)
    this.frame = requestAnimationFrame(() => this.fit())
  }

  fit() {
    this.tabTargets.forEach((tab) => {
      tab.hidden = false
      tab.style.maxWidth = ""
    })
    const folded = []
    const foldable = this.tabTargets.filter((tab) => tab.dataset.keep !== "true")
    while (this.overflowing() && foldable.length) {
      const tab = foldable.pop()
      tab.hidden = true
      folded.push(tab.dataset.key)
      this.setLabel(folded.length) // "+N more" grows as tabs fold; measure with it
    }
    this.setLabel(folded.length)
    this.squeeze()
    // Still too tight: "+5 more" becomes "+5", and the kept tabs shorten again.
    if (this.overflowing() && folded.length) {
      this.moreTarget.textContent = `+${folded.length}`
      this.squeeze()
    }

    this.overflowItemTargets.forEach((item) => {
      const show = folded.includes(item.dataset.key)
      item.dataset.overflow = String(show)
      item.hidden = !show
    })
    this.overflowHeadingTarget.hidden = folded.length === 0
  }

  // Folding wasn't enough (a narrow phone, long names): shorten the tabs that
  // must stay, longest first, down to a readable minimum, with an ellipsis.
  squeeze() {
    const MIN = 56
    const kept = this.tabTargets.filter((tab) => !tab.hidden).sort((a, b) => b.offsetWidth - a.offsetWidth)
    for (const tab of kept) {
      const over = this.element.scrollWidth - this.element.clientWidth
      if (over <= 1) return
      const width = tab.offsetWidth
      if (width <= MIN) continue
      tab.title ||= tab.textContent.trim() // the full name, on hover
      tab.style.maxWidth = `${Math.max(MIN, width - over - 1)}px`
    }
  }

  overflowing() {
    return this.element.scrollWidth > this.element.clientWidth + 1
  }

  setLabel(count) {
    this.moreTarget.textContent = count ? this.moreValue.replace("%{count}", count) : this.label
    this.moreTarget.classList.toggle("has-more", count > 0)
  }
}
