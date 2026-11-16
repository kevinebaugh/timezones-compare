import { Controller } from "@hotwired/stimulus"
import { zoneName } from "controllers/lib/locale"

// Shows a time zone's name in the page's language.
export default class extends Controller {
  static values = { tz: String }

  connect() {
    this.element.textContent = zoneName(this.tzValue, this.element.textContent.trim())
  }
}
