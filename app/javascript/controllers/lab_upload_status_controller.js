import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    uploadId: String
  }

  connect() {
    if (!this.hasUploadIdValue || this.uploadIdValue.length === 0) {
      return
    }

    this.lastStatus = null
    this.pollStatus()
    this.pollHandle = setInterval(() => this.pollStatus(), 2500)
  }

  disconnect() {
    if (this.pollHandle) {
      clearInterval(this.pollHandle)
    }
  }

  async pollStatus() {
    try {
      const response = await fetch(`/lab_uploads/${this.uploadIdValue}/status`, {
        headers: { Accept: "application/json" }
      })

      if (!response.ok) {
        return
      }

      const payload = await response.json()
      this.renderStatus(payload)

      if (payload.status === "completed" || payload.status === "failed") {
        clearInterval(this.pollHandle)
      }
    } catch (_error) {
      // No-op: polling can fail transiently while the app reloads.
    }
  }

  renderStatus(payload) {
    const activeStatus = this.element.querySelector("[data-status-target='activeStatus']")
    const activeError = this.element.querySelector("[data-status-target='activeError']")
    const tableStatus = this.element.querySelector(`[data-upload-status='${payload.id}']`)
    const completedAtCell = this.element.querySelector(`[data-upload-completed-at='${payload.id}']`)

    if (activeStatus) {
      activeStatus.textContent = this.capitalize(payload.status)
      activeStatus.className = `status-pill status-${payload.status}`
    }

    if (activeError) {
      activeError.textContent = payload.error_message || ""
    }

    if (tableStatus) {
      tableStatus.textContent = this.capitalize(payload.status)
      tableStatus.className = `status-pill status-${payload.status}`
    }

    if (completedAtCell && payload.completed_at) {
      completedAtCell.textContent = this.formatDate(payload.completed_at)
    }

    if (this.lastStatus !== payload.status && (payload.status === "completed" || payload.status === "failed")) {
      this.notify(payload)
    }

    this.lastStatus = payload.status
  }

  notify(payload) {
    if (!("Notification" in window)) {
      return
    }

    const title = payload.status === "completed" ? "Lab Upload Completed" : "Lab Upload Failed"
    const body = payload.status === "completed"
      ? `${payload.file} has finished processing.`
      : payload.error_message || `${payload.file} failed to process.`

    if (Notification.permission === "granted") {
      new Notification(title, { body })
      return
    }

    if (Notification.permission === "default") {
      Notification.requestPermission().then((permission) => {
        if (permission === "granted") {
          new Notification(title, { body })
        }
      })
    }
  }

  capitalize(value) {
    return value.charAt(0).toUpperCase() + value.slice(1)
  }

  formatDate(dateString) {
    const date = new Date(dateString)
    const pad = (value) => String(value).padStart(2, "0")

    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`
  }
}
