// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/better_hermes"
import topbar from "../vendor/topbar"
import {HermesGraph} from "./hermes_graph"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

const graphContainer = document.querySelector("[data-three-graph]")

if (graphContainer) {
  const graph = new HermesGraph(graphContainer)
  const socket = new Socket("/socket")
  const traceLog = document.getElementById("trace-log")
  const approvalPanel = document.getElementById("approval-panel")
  const finalOutline = document.getElementById("final-outline")
  const connectionState = document.getElementById("connection-state")
  const sessionLabel = document.getElementById("session-label")
  let traceChannel = null

  socket.connect()
  socket.onOpen(() => connectionState.textContent = "connected")
  socket.onError(() => connectionState.textContent = "socket error")
  socket.onClose(() => connectionState.textContent = "disconnected")

  const lobby = socket.channel("hermes:lobby", {})
  lobby.join()
    .receive("ok", () => connectionState.textContent = "ready")
    .receive("error", () => connectionState.textContent = "join failed")

  document.getElementById("task-form").addEventListener("submit", event => {
    event.preventDefault()
    graph.reset()
    traceLog.innerHTML = ""
    approvalPanel.innerHTML = "<p class=\"text-[#7d8984]\">Waiting for write actions.</p>"
    finalOutline.innerHTML = "<p class=\"text-[#7d8984]\">The synthesizer will write the pitch outline here.</p>"

    lobby.push("start_research", {
      topic: document.getElementById("topic").value,
      audience: document.getElementById("audience").value,
      constraints: document.getElementById("constraints").value
    }).receive("ok", ({session_id}) => {
      sessionLabel.textContent = session_id
      joinTrace(session_id)
    }).receive("error", response => {
      appendTrace({type: "job_failed", summary: response.reason || "Unable to start session"})
    })
  })

  function joinTrace(sessionId) {
    if (traceChannel) traceChannel.leave()
    traceChannel = socket.channel(`trace:${sessionId}`, {})
    traceChannel.join()
      .receive("ok", () => connectionState.textContent = "streaming")
      .receive("error", () => connectionState.textContent = "trace failed")

    traceChannel.on("trace_event", event => {
      graph.applyEvent(event)
      appendTrace(event)
      if (event.type === "approval_required") appendApproval(event)
      if (event.type === "job_completed") renderOutline(event.payload?.outline || [])
    })
  }

  function appendTrace(event) {
    const item = document.createElement("div")
    item.className = "rounded-md border border-white/10 bg-[#0e1112] p-2"
    item.textContent = `${event.type}: ${event.summary || event.agent_id || event.tool_id || event.id || ""}`
    traceLog.prepend(item)
  }

  function appendApproval(event) {
    if (approvalPanel.querySelector("p")) approvalPanel.innerHTML = ""
    const card = document.createElement("div")
    card.className = "rounded-md border border-[#f2c45b]/40 bg-[#211d11] p-3"
    const title = document.createElement("div")
    title.className = "font-medium text-[#ffe0a1]"
    title.textContent = event.summary
    const payload = document.createElement("pre")
    payload.className = "mt-2 max-h-32 overflow-auto whitespace-pre-wrap text-xs text-[#d7c9a6]"
    payload.textContent = JSON.stringify(event.payload || {}, null, 2)
    const actions = document.createElement("div")
    actions.className = "mt-3 flex gap-2"
    const approve = document.createElement("button")
    approve.className = "rounded-md bg-[#79d6b5] px-3 py-2 text-xs font-semibold text-[#07110d]"
    approve.textContent = "Approve"
    const reject = document.createElement("button")
    reject.className = "rounded-md border border-white/15 px-3 py-2 text-xs font-semibold text-white"
    reject.textContent = "Reject"

    approve.addEventListener("click", () => {
      traceChannel.push("approve", {approval_id: event.approval_id})
      card.remove()
    })
    reject.addEventListener("click", () => {
      traceChannel.push("reject", {approval_id: event.approval_id})
      card.remove()
    })

    actions.append(approve, reject)
    card.append(title, payload, actions)
    approvalPanel.prepend(card)
  }

  function renderOutline(outline) {
    finalOutline.innerHTML = ""
    for (const slide of outline) {
      const section = document.createElement("section")
      section.className = "mb-4 rounded-md border border-white/10 bg-[#0e1112] p-3"
      const heading = document.createElement("h3")
      heading.className = "font-semibold text-white"
      heading.textContent = slide.slide
      const list = document.createElement("ul")
      list.className = "mt-2 list-disc space-y-1 pl-5"
      for (const point of slide.points || []) {
        const li = document.createElement("li")
        li.textContent = point
        list.appendChild(li)
      }
      section.append(heading, list)
      finalOutline.appendChild(section)
    }
  }
}

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
