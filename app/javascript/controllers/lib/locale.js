// The page's language, set on <html lang>, for every Intl call.
export function locale() {
  return document.documentElement.lang || "en"
}

// Slack names time zones in English ("Pacific Time"). In other languages,
// use the browser's own name for the zone ("heure du Pacifique"). In English
// too when all the page has is an abbreviation or offset ("JST", "UTC+4"),
// which happens for zones nobody in the workspace is in: "Japan Time".
const ABBREVIATION = /^([A-Z]{2,5}|UTC[+−-][\d:]+)$/

export function zoneName(tz, fallback) {
  if (!tz) return fallback
  const english = locale().startsWith("en")
  if (english && !ABBREVIATION.test(fallback ?? "")) return fallback
  try {
    const parts = new Intl.DateTimeFormat(locale(), { timeZone: tz, timeZoneName: "longGeneric" }).formatToParts(new Date())
    let name = parts.find((part) => part.type === "timeZoneName")?.value
    if (!name || /^(GMT|UTC)/.test(name)) return fallback
    // Season-neutral, like Slack's labels here: "Japan Standard Time" -> "Japan Time".
    if (english) name = name.replace(/\s+(Standard|Daylight|Summer)(?=\s+Time\b)/, "")
    return name
  } catch {
    return fallback
  }
}

// "Created via %{url}" -> "Created via https://…"
export function translate(strings, key, vars = {}) {
  return (strings[key] ?? key).replace(/%\{(\w+)\}/g, (_, name) => vars[name] ?? "")
}
