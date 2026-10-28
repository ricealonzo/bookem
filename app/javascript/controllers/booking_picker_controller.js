import { Controller } from "@hotwired/stimulus"

// Availability on the location page.
// - Choosing a day on the calendar shows that day's time slots.
// - Guests select one open slot, or a run of back-to-back open slots, and the
//   hidden start and end fields of the request form are filled in.
export default class extends Controller {
  static targets = ["day", "placeholder", "slot", "startInput", "endInput", "summary", "submit"]
  static values = { selectedDate: String }

  connect() {
    this.selection = null
    const initial =
      this.findDay(this.selectedDateValue) ||
      this.dayTargets.find((day) => Number(day.dataset.openCount) > 0)
    if (initial) this.show(initial, { scroll: false })
  }

  showDay(event) {
    const day = this.findDay(event.params.date)
    if (day) this.show(day, { scroll: true })
  }

  toggleSlot(event) {
    const button = event.currentTarget
    const day = button.closest("[data-booking-picker-target='day']")
    const index = Number(button.dataset.index)
    const current = this.selection

    if (!current || current.day !== day) {
      this.select(day, index, index)
    } else if (index === current.from && index === current.to) {
      this.clearSelection()
    } else if (index > current.to && this.allOpen(day, current.from, index)) {
      this.select(day, current.from, index)
    } else if (index < current.from && this.allOpen(day, index, current.to)) {
      this.select(day, index, current.to)
    } else {
      this.select(day, index, index)
    }
  }

  // ---- helpers ----

  findDay(date) {
    if (!date) return null
    return this.dayTargets.find((day) => day.dataset.date === date)
  }

  show(day, { scroll }) {
    this.dayTargets.forEach((d) => { d.hidden = d !== day })
    if (this.hasPlaceholderTarget) this.placeholderTarget.hidden = true
    if (this.selection && this.selection.day !== day) this.clearSelection()

    this.element.querySelectorAll("td.is-selected").forEach((td) => td.classList.remove("is-selected"))
    const button = this.element.querySelector(`.day-pick[data-booking-picker-date-param="${day.dataset.date}"]`)
    if (button) button.closest("td")?.classList.add("is-selected")

    if (scroll && window.matchMedia("(max-width: 860px)").matches) {
      const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches
      day.scrollIntoView({ behavior: reduceMotion ? "auto" : "smooth", block: "start" })
    }
  }

  slotAt(day, index) {
    return day.querySelector(`[data-index="${index}"]`)
  }

  allOpen(day, from, to) {
    for (let i = from; i <= to; i++) {
      const slot = this.slotAt(day, i)
      if (!slot || slot.tagName !== "BUTTON") return false
    }
    return true
  }

  select(day, from, to) {
    this.selection = { day, from, to }
    this.slotTargets.forEach((slot) => {
      const index = Number(slot.dataset.index)
      const chosen = slot.closest("[data-booking-picker-target='day']") === day && index >= from && index <= to
      this.mark(slot, chosen)
    })

    const first = this.slotAt(day, from)
    const last = this.slotAt(day, to)
    if (this.hasStartInputTarget) this.startInputTarget.value = first.dataset.starts
    if (this.hasEndInputTarget) this.endInputTarget.value = last.dataset.ends

    const count = to - from + 1
    if (this.hasSummaryTarget) {
      this.summaryTarget.textContent =
        `${day.dataset.label}, ${first.dataset.startsLabel} to ${last.dataset.endsLabel}` +
        (count > 1 ? ` (${count} slots)` : "")
      this.summaryTarget.classList.add("has-selection")
    }
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  mark(slot, chosen) {
    slot.classList.toggle("is-selected", chosen)
    slot.setAttribute("aria-pressed", String(chosen))
    const state = slot.querySelector(".slot-state")
    if (state) state.textContent = chosen ? "Selected" : "Open"
  }

  clearSelection() {
    this.selection = null
    this.slotTargets.forEach((slot) => this.mark(slot, false))
    if (this.hasStartInputTarget) this.startInputTarget.value = ""
    if (this.hasEndInputTarget) this.endInputTarget.value = ""
    if (this.hasSummaryTarget) {
      this.summaryTarget.textContent = "No time selected yet."
      this.summaryTarget.classList.remove("has-selection")
    }
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
  }
}
