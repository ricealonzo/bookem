import { Controller } from "@hotwired/stimulus"

// Clicking a day on the availability calendar fills in the booking form with
// that day (9 AM to 10 AM, or the times already chosen) and brings the form
// into view so the guest can adjust the times.
export default class extends Controller {
  static targets = ["panel", "start", "end"]

  pick(event) {
    if (!this.hasStartTarget || !this.hasEndTarget) return

    const date = event.params.date
    const startTime = this.timePart(this.startTarget.value) || "09:00"
    const endTime = this.timePart(this.endTarget.value) || "10:00"

    this.startTarget.value = `${date}T${startTime}`
    this.endTarget.value = `${date}T${endTime > startTime ? endTime : this.oneHourAfter(startTime)}`

    this.markSelected(event.currentTarget.closest("td"))
    this.showPanel()
  }

  timePart(value) {
    return value && value.includes("T") ? value.split("T")[1].slice(0, 5) : null
  }

  oneHourAfter(time) {
    const [hours, minutes] = time.split(":").map(Number)
    const next = Math.min(hours + 1, 23)
    return `${String(next).padStart(2, "0")}:${String(minutes).padStart(2, "0")}`
  }

  markSelected(cell) {
    this.element.querySelectorAll("td.is-selected").forEach((td) => td.classList.remove("is-selected"))
    if (cell) cell.classList.add("is-selected")
  }

  showPanel() {
    const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
    if (this.hasPanelTarget) {
      this.panelTarget.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "nearest" })
      this.panelTarget.classList.remove("is-updated")
      // Restart the highlight so repeated picks still show it.
      void this.panelTarget.offsetWidth
      this.panelTarget.classList.add("is-updated")
    }
    this.startTarget.focus({ preventScroll: true })
  }
}
