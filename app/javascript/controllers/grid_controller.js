import { Controller } from "@hotwired/stimulus"
import { locale, zoneName, translate } from "controllers/lib/locale"

// Compare times across the grid at quarter-hour precision: hovering previews a
// 30-minute slot starting at the nearest :00, :15, :30 or :45; clicking pins
// it; pressing and dragging sets the meeting's length in 15-minute steps.
// Also keeps the "now" line and row clocks live, and remembers 12/24-hour.
// Day of the week (0 = Sunday) at that moment in a time zone.
const WEEKDAYS = { Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6 }
function weekday(at, tz) {
  return WEEKDAYS[new Intl.DateTimeFormat("en-US", { weekday: "short", timeZone: tz }).format(at)]
}

export default class extends Controller {
  static targets = ["band", "summary", "summaryText", "actions", "copyButton", "linkButton", "googleLink", "now", "clock", "clockButton", "scroller"]
  static values = {
    startsAt: Number, endsAt: Number, summaries: Array, clock: String, weekends: Object,
    guests: Array, referenceName: String, referenceTz: String,
    zones: Array, boardKey: String, pinAt: Number, pinMinutes: Number, i18n: Object,
  }
  static STEP = 15          // minutes: the grid snaps to quarter hours
  static MEETING = 30       // minutes: a click picks a half-hour slot
  static NAMES_PER_ZONE = 8
  static HOME = "https://timezones.compare"

  t(key, vars) {
    return translate(this.i18nValue, key, vars)
  }

  get referenceName() {
    return zoneName(this.referenceTzValue, this.referenceNameValue)
  }

  connect() {
    this.idleNodes = this.hasSummaryTextTarget ? [...this.summaryTextTarget.childNodes].map((n) => n.cloneNode(true)) : []
    this.pinned = null   // { start, length } in minutes from the start of the grid
    this.hovered = null
    this.drag = null
    this.tick()
    this.timer = setInterval(() => this.tick(), 30_000)
    this.scrollToNow()
    if (this.pinAtValue) this.pinAt(this.pinAtValue, this.pinMinutesValue || this.constructor.MEETING)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  // ── pointer ────────────────────────────────────────────────────────────

  // Hover previews a slot; while dragging, the slot stretches to the pointer.
  move(event) {
    const minute = this.quarterAt(event.clientX)
    if (minute === null) return
    if (this.drag) {
      if (Math.abs(event.clientX - this.drag.x) > 3) this.drag.moved = true
      return this.show(this.span(this.drag.anchor, minute), { dragging: true })
    }
    if (this.pinned) return
    this.show(this.slot(minute))
  }

  leave() {
    if (this.pinned || this.drag) return
    this.hide()
  }

  // Mouse and pen: press to start a selection. Touch keeps scrolling the grid,
  // and a tap picks a slot (see tap).
  press(event) {
    if (event.pointerType === "touch" || event.button !== 0 || event.target.closest?.("a")) return
    const minute = this.quarterAt(event.clientX)
    if (minute === null) return
    event.preventDefault()
    this.element.querySelector(".tz-table")?.focus({ preventScroll: true })
    this.drag = { anchor: minute, x: event.clientX, moved: false }
    event.currentTarget.setPointerCapture?.(event.pointerId)
  }

  release(event) {
    if (!this.drag) return
    const { anchor, moved } = this.drag
    this.drag = null
    const minute = this.quarterAt(event.clientX) ?? anchor
    if (moved) return this.pinSelection(this.span(anchor, minute))
    // A plain click: inside the pinned slot unpins it, anywhere else pins a new one.
    if (this.pinned && minute >= this.pinned.start && minute < this.pinned.start + this.pinned.length) return this.unpin()
    this.pinSelection(this.slot(minute))
  }

  tap(event) {
    if (event.pointerType !== "touch" || event.target.closest?.("a")) return
    const minute = this.quarterAt(event.clientX)
    if (minute === null) return
    if (this.pinned && minute >= this.pinned.start && minute < this.pinned.start + this.pinned.length) return this.unpin()
    this.pinSelection(this.slot(minute))
  }

  // ── selection ──────────────────────────────────────────────────────────

  pinSelection(selection) {
    this.pinned = selection
    this.show(selection)
    this.setCalendarLinks(selection)
    this.actionsTarget.hidden = false
  }

  // Opened from a shared link: pin the time (and length) it points at.
  pinAt(epoch, minutes) {
    const start = Math.round((epoch - this.startsAtValue) / 60)
    if (start < 0 || start >= this.totalMinutes) return
    this.pinSelection(this.clamp({ start, length: minutes }))
    this.scrollToColumn(Math.floor(start / 60))
  }

  unpin() {
    this.pinned = null
    this.actionsTarget.hidden = true
    this.hide()
  }

  // A link to this moment. Teammates who can see this board open it pinned;
  // anyone else sees the same time zones, without names or working hours.
  async copyLink() {
    if (!this.pinned) return
    const url = new URL(`/t/${this.epochAt(this.pinned.start)}`, window.location.origin)
    url.searchParams.set("z", this.zonesValue.join(","))
    url.searchParams.set("tz", this.referenceTzValue)
    if (this.pinned.length !== this.constructor.MEETING) url.searchParams.set("d", this.pinned.length)
    if (this.boardKeyValue) url.searchParams.set("b", this.boardKeyValue)
    // When the link was made, so teammates can see if the board's zones have changed since.
    url.searchParams.set("g", Math.floor(Date.now() / 1000))
    this.linkButtonTarget.dataset.link = url.toString()
    try {
      await navigator.clipboard.writeText(url.toString())
      this.linkButtonTarget.textContent = this.t("copied")
    } catch {
      window.prompt(this.t("copy_prompt"), url.toString())
    }
    setTimeout(() => (this.linkButtonTarget.textContent = this.t("copy_link")), 1500)
  }

  // Arrows move the slot 15 minutes; Shift+arrows change its length.
  // Enter or Space pins it (or unpins); Escape lets go.
  key(event) {
    const step = { ArrowLeft: -1, ArrowRight: 1 }[event.key]
    const current = this.pinned ?? this.hovered ?? this.slot(this.nowQuarter() ?? 0)
    if (step) {
      event.preventDefault()
      const STEP = this.constructor.STEP
      const next = event.shiftKey
        ? this.clamp({ start: current.start, length: current.length + step * STEP })
        : this.clamp({ start: current.start + step * STEP, length: current.length })
      if (this.pinned) this.pinSelection(next)
      else this.show(next)
    } else if (event.key === "Enter" || event.key === " ") {
      event.preventDefault()
      if (this.pinned) return this.unpin()
      this.pinSelection(current)
    } else if (event.key === "Escape") {
      this.unpin()
    }
  }

  async copy() {
    const text = this.currentSummary || this.summaryTextTarget.textContent
    try {
      await navigator.clipboard.writeText(text)
      this.copyButtonTarget.textContent = this.t("copied")
      setTimeout(() => (this.copyButtonTarget.textContent = this.t("copy_times")), 1500)
    } catch {
      this.copyButtonTarget.textContent = this.t("select_and_copy")
    }
  }

  setClock(event) {
    const clock = event.currentTarget.dataset.clock
    this.clockValue = clock
    this.element.classList.remove("clock-12", "clock-24")
    this.element.classList.add(`clock-${clock}`)
    this.clockButtonTargets.forEach((b) => b.setAttribute("aria-pressed", String(b.dataset.clock === clock)))
    document.cookie = `clock=${clock}; path=/; max-age=31536000; samesite=lax`
    if (this.hovered) this.show(this.hovered)
    else this.tick()
  }

  // ── internals ──────────────────────────────────────────────────────────

  get columnCount() {
    return this.summariesValue.length
  }

  get totalMinutes() {
    return this.columnCount * 60
  }

  epochAt(minute) {
    return this.startsAtValue + minute * 60
  }

  // The quarter hour under the pointer, in minutes from the start of the grid.
  quarterAt(clientX) {
    if (clientX === null || clientX === undefined) return null
    const strip = this.element.querySelector(".tz-strip")
    if (!strip) return null
    const { left, width } = strip.getBoundingClientRect()
    const minute = ((clientX - left) / width) * this.totalMinutes
    if (minute < 0 || minute >= this.totalMinutes) return null
    return Math.floor(minute / this.constructor.STEP) * this.constructor.STEP
  }

  nowQuarter() {
    const minute = (Date.now() / 1000 - this.startsAtValue) / 60
    if (minute < 0 || minute >= this.totalMinutes) return null
    return Math.floor(minute / this.constructor.STEP) * this.constructor.STEP
  }

  // A half-hour slot starting at this quarter.
  slot(minute) {
    return this.clamp({ start: minute, length: this.constructor.MEETING })
  }

  // From one quarter to another, either direction, including both ends.
  span(a, b) {
    const start = Math.min(a, b)
    return this.clamp({ start, length: Math.max(a, b) - start + this.constructor.STEP })
  }

  clamp({ start, length }) {
    const STEP = this.constructor.STEP
    length = Math.max(STEP, Math.min(length, this.totalMinutes))
    start = Math.max(0, Math.min(start, this.totalMinutes - length))
    return { start, length }
  }

  show(selection, { dragging = false } = {}) {
    this.hovered = selection
    if (this.hasBandTarget) {
      this.bandTarget.style.setProperty("--start", selection.start / 60)
      this.bandTarget.style.setProperty("--span", selection.length / 60)
      this.bandTarget.hidden = false
      this.bandTarget.classList.toggle("is-pinned", !!this.pinned && !dragging)
      this.bandTarget.classList.toggle("is-dragging", dragging)
    }
    const first = Math.floor(selection.start / 60)
    const last = Math.ceil((selection.start + selection.length) / 60) - 1
    this.element.querySelectorAll(".tz-cell.is-col").forEach((el) => el.classList.remove("is-col"))
    for (let col = first; col <= last; col++) {
      this.element.querySelectorAll(`.tz-cell[data-col="${col}"]`).forEach((el) => el.classList.add("is-col"))
    }
    this.showSummary(selection)
    this.previewClocks(selection)
  }

  hide() {
    this.hovered = null
    if (this.hasBandTarget) this.bandTarget.hidden = true
    this.element.querySelectorAll(".tz-cell.is-col").forEach((el) => el.classList.remove("is-col"))
    this.showIdle()
    this.tick()
  }

  // Each row's label shows that row's time when the slot starts.
  previewClocks(selection) {
    const at = new Date(this.epochAt(selection.start) * 1000)
    const hour12 = this.clockValue === "12"
    this.clockTargets.forEach((el) => {
      el.textContent = new Intl.DateTimeFormat(locale(), {
        weekday: "short", hour: "numeric", minute: "2-digit", hour12, timeZone: el.dataset.tz,
      }).format(at)
      el.classList.add("is-preview")
    })
  }

  showSummary(selection) {
    this.summaryTarget.classList.remove("is-idle")
    this.summaryTextTarget.textContent = this.headline(selection)
    this.currentSummary = this.summaryText(selection)
  }

  showIdle() {
    this.currentSummary = null
    this.summaryTextTarget.replaceChildren(...this.idleNodes.map((n) => n.cloneNode(true)))
    this.summaryTarget.classList.add("is-idle")
  }

  // "10:15 – 11:00 AM", in the reference zone and the page's language.
  range(selection, hour12 = this.clockValue === "12") {
    const start = new Date(this.epochAt(selection.start) * 1000)
    const end = new Date(this.epochAt(selection.start + selection.length) * 1000)
    const format = new Intl.DateTimeFormat(locale(), { hour: "numeric", minute: "2-digit", hour12, timeZone: this.referenceTzValue })
    return format.formatRange ? format.formatRange(start, end) : `${format.format(start)} – ${format.format(end)}`
  }

  // "45 min", "1 hr 30 min", in the page's language.
  duration(minutes) {
    const hours = Math.floor(minutes / 60)
    const rest = minutes % 60
    try {
      if (Intl.DurationFormat) return new Intl.DurationFormat(locale(), { style: "short" }).format({ hours, minutes: rest })
    } catch {}
    return new Intl.NumberFormat(locale(), { style: "unit", unit: "minute", unitDisplay: "short" }).format(minutes)
  }

  // One quiet line, "Thu, Oct 15 · 10:15 – 11:00 AM Pacific Time · 45 min",
  // plus "· Weekend for India Time" when it lands on someone's day off.
  headline(selection) {
    const at = new Date(this.epochAt(selection.start) * 1000)
    const date = new Intl.DateTimeFormat(locale(), { weekday: "short", month: "short", day: "numeric", timeZone: this.referenceTzValue }).format(at)
    const line = `${date} · ${this.range(selection)} ${this.referenceName} · ${this.duration(selection.length)}`
    const off = this.zonesOnWeekend(at).map((zone) => zoneName(zone.tz, zone.zone))
    if (!off.length) return line
    const shown = off.slice(0, 2).join(", ") + (off.length > 2 ? ` ${this.t("more", { count: off.length - 2 })}` : "")
    return `${line} · ${this.t("weekend_for", { zones: shown })}`
  }

  // The board's zones where this moment falls on that zone's weekend.
  zonesOnWeekend(at) {
    const zones = this.summariesValue[0]?.zones ?? []
    return zones.filter((zone) => (this.weekendsValue[zone.tz] ?? [ 6, 0 ]).includes(weekday(at, zone.tz)))
  }

  // A heading for the reference time, then one line per zone with who's there:
  //
  //   Thu, Oct 15 at 10:15 – 11:00 AM Eastern Time
  //   Thu 7:15 AM · Pacific Time: Anna Pham, Dan Burns
  //   Thu 7:45 PM · India Time: Sidd
  summaryText(selection) {
    const at = new Date(this.epochAt(selection.start) * 1000)
    const hour12 = this.clockValue === "12"
    const date = new Intl.DateTimeFormat(locale(), { weekday: "short", month: "short", day: "numeric", timeZone: this.referenceTzValue }).format(at)
    const zones = this.summariesValue[0]?.zones ?? []
    const off = this.zonesOnWeekend(at).map((zone) => zone.tz)
    const lines = zones.map((zone) => {
      const local = new Intl.DateTimeFormat(locale(), { weekday: "short", hour: "numeric", minute: "2-digit", hour12, timeZone: zone.tz }).format(at)
      const shown = zone.names.slice(0, this.constructor.NAMES_PER_ZONE)
      const more = (zone.count ?? zone.names.length) - shown.length
      const names = shown.join(", ") + (more > 0 ? ` ${this.t("more", { count: more })}` : "")
      const weekend = off.includes(zone.tz) ? ` (${this.t("weekend")})` : ""
      return `${local} · ${zoneName(zone.tz, zone.zone)}${weekend}` + (names ? `: ${names}` : "")
    })
    return [ this.t("moment_heading", { date, time: this.range(selection, hour12), zone: this.referenceName }), ...lines ].join("\n")
  }

  // A Google Calendar event for the pinned slot, untitled, with the board's
  // people as guests and the times (plus a link home) as the description.
  setCalendarLinks(selection) {
    const start = new Date(this.epochAt(selection.start) * 1000)
    const end = new Date(this.epochAt(selection.start + selection.length) * 1000)
    const compact = (d) => d.toISOString().replace(/[-:]/g, "").replace(/\.\d{3}/, "")
    const details = `${this.summaryText(selection)}\n\n${this.t("created_via", { url: this.constructor.HOME })}`

    const params = new URLSearchParams({ action: "TEMPLATE", dates: `${compact(start)}/${compact(end)}`, details })
    if (this.guestsValue.length) params.set("add", this.guestsValue.join(","))
    this.googleLinkTarget.href = `https://calendar.google.com/calendar/render?${params}`
  }

  tick() {
    const now = Date.now() / 1000
    if (this.hasNowTarget) {
      const span = this.endsAtValue - this.startsAtValue
      const x = (now - this.startsAtValue) / span
      this.nowTarget.hidden = !(x >= 0 && x < 1)
      this.nowTarget.style.setProperty("--x", x)
    }
    if (this.hovered) return
    const hour12 = this.clockValue === "12"
    this.clockTargets.forEach((el) => {
      el.classList.remove("is-preview")
      el.textContent = new Intl.DateTimeFormat(locale(), {
        hour: "numeric", minute: "2-digit", hour12, timeZone: el.dataset.tz,
      }).format(new Date())
    })
  }

  scrollToColumn(col) {
    if (!this.hasScrollerTarget) return
    const scroller = this.scrollerTarget
    if (scroller.scrollWidth <= scroller.clientWidth) return
    const cell = this.element.querySelector(`.tz-cell[data-col="${col}"]`)
    if (!cell) return
    const x = cell.getBoundingClientRect().left - scroller.getBoundingClientRect().left + scroller.scrollLeft
    scroller.scrollLeft = Math.max(0, x - scroller.clientWidth / 2)
  }

  scrollToNow() {
    if (!this.hasScrollerTarget || !this.hasNowTarget || this.nowTarget.hidden) return
    const scroller = this.scrollerTarget
    if (scroller.scrollWidth <= scroller.clientWidth) return
    const line = this.nowTarget.getBoundingClientRect().left - scroller.getBoundingClientRect().left
    scroller.scrollLeft = Math.max(0, line - scroller.clientWidth / 2)
  }
}
