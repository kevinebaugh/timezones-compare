// Sends uncaught errors to /client_errors so they show up next to server
// errors. A few per page at most, and only from our own scripts.
const MAX_PER_PAGE = 5
let sent = 0

function report(kind, message, source, line, column) {
  if (sent >= MAX_PER_PAGE) return
  if (source && !source.startsWith(location.origin)) return
  sent++
  const body = new URLSearchParams({
    kind, message: String(message || "").slice(0, 300),
    source: String(source || "").replace(location.origin, ""),
    line: line || 0, column: column || 0, path: location.pathname
  })
  navigator.sendBeacon?.("/client_errors", body)
}

addEventListener("error", (event) => {
  report("error", event.message, event.filename, event.lineno, event.colno)
})

addEventListener("unhandledrejection", (event) => {
  const reason = event.reason
  report("unhandledrejection", reason?.message || reason, location.href, 0, 0)
})

document.addEventListener("turbo:load", () => { sent = 0 })
