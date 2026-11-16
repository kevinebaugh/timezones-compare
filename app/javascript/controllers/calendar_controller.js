import { Controller } from "@hotwired/stimulus"
import { locale } from "controllers/lib/locale"

// The language's first day of the week and weekend (0 = Sunday), from Intl.
function weekInfo() {
  try {
    const l = new Intl.Locale(locale())
    const info = l.getWeekInfo?.() ?? l.weekInfo
    if (info) return { first: info.firstDay % 7, weekend: info.weekend.map((d) => d % 7) }
  } catch {}
  return { first: 0, weekend: [ 0, 6 ] }
}

// A small month calendar under the date. Every day is a plain link to that
// date (same board, same time zone), so it works like the arrows next to it.
export default class extends Controller {
  static targets = ["title", "grid"]
  static values = { selected: String, today: String, url: String }

  connect() {
    const [year, month] = this.selectedValue.split("-").map(Number)
    this.year = year
    this.month = month - 1
    this.render()
  }

  previous() { this.shift(-1) }
  next() { this.shift(1) }

  shift(by) {
    const d = new Date(Date.UTC(this.year, this.month + by, 1))
    this.year = d.getUTCFullYear()
    this.month = d.getUTCMonth()
    this.render()
  }

  render() {
    const utc = { timeZone: "UTC" }
    this.titleTarget.textContent = new Intl.DateTimeFormat(locale(), { ...utc, month: "long", year: "numeric" })
      .format(new Date(Date.UTC(this.year, this.month, 1)))

    const nodes = []
    const week = weekInfo()
    const weekday = new Intl.DateTimeFormat(locale(), { ...utc, weekday: "narrow" })
    for (let i = 0; i < 7; i++) {
      nodes.push(this.el("span", "cal-dow", weekday.format(new Date(Date.UTC(2023, 0, 1 + week.first + i))))) // Jan 1 2023 was a Sunday
    }

    const first = new Date(Date.UTC(this.year, this.month, 1))
    const start = new Date(first)
    start.setUTCDate(1 - ((first.getUTCDay() - week.first + 7) % 7))
    const label = new Intl.DateTimeFormat(locale(), { ...utc, weekday: "long", month: "long", day: "numeric", year: "numeric" })

    for (let i = 0; i < 42; i++) {
      const d = new Date(start)
      d.setUTCDate(start.getUTCDate() + i)
      const iso = d.toISOString().slice(0, 10)
      const day = this.el("a", "cal-day", String(d.getUTCDate()))
      day.href = this.urlValue.replace("2000-01-01", iso)
      day.setAttribute("aria-label", label.format(d))
      if (d.getUTCMonth() !== this.month) day.classList.add("is-out")
      if (week.weekend.includes(d.getUTCDay())) day.classList.add("is-weekend")
      if (iso === this.todayValue) day.classList.add("is-today")
      if (iso === this.selectedValue) {
        day.classList.add("is-selected")
        day.setAttribute("aria-current", "date")
      }
      nodes.push(day)
    }
    this.gridTarget.replaceChildren(...nodes)
  }

  el(tag, className, text) {
    const node = document.createElement(tag)
    node.className = className
    node.textContent = text
    return node
  }
}
