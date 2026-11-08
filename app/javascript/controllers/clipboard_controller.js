import { Controller } from "@hotwired/stimulus"

// Copies text (a booking link) and says so on the button for a moment.
export default class extends Controller {
  static values = { text: String }
  static targets = ["button"]

  async copy() {
    try {
      await navigator.clipboard.writeText(this.textValue)
      this.flash("Copied")
    } catch {
      this.flash("Press and hold to copy")
    }
  }

  flash(message) {
    if (!this.hasButtonTarget) return
    const original = this.buttonTarget.dataset.label || this.buttonTarget.textContent
    this.buttonTarget.dataset.label = original
    this.buttonTarget.textContent = message
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.buttonTarget.textContent = original }, 1800)
  }
}
