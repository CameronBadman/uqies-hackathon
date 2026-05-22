import * as THREE from "three"

const STATUS_COLORS = {
  idle: 0x6f7d78,
  running: 0x79d6b5,
  waiting_for_approval: 0xf2c45b,
  completed: 0x8bd45d,
  failed: 0xe86b6b,
  rejected: 0xa775d6
}

export class HermesGraph {
  constructor(container) {
    this.container = container
    this.nodes = new Map()
    this.edges = []
    this.scene = new THREE.Scene()
    this.scene.background = new THREE.Color(0x0c0f10)

    this.camera = new THREE.PerspectiveCamera(55, 1, 0.1, 1000)
    this.camera.position.set(0, 0, 70)

    this.renderer = new THREE.WebGLRenderer({antialias: true})
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2))
    this.container.appendChild(this.renderer.domElement)

    const ambient = new THREE.AmbientLight(0xffffff, 0.7)
    const point = new THREE.PointLight(0x79d6b5, 3, 120)
    point.position.set(20, 20, 45)
    this.scene.add(ambient, point)

    this.edgeMaterial = new THREE.LineBasicMaterial({color: 0x2f6254, transparent: true, opacity: 0.7})
    this.clock = new THREE.Clock()

    window.addEventListener("resize", () => this.resize())
    this.resize()
    this.animate()
  }

  reset() {
    for (const node of this.nodes.values()) this.scene.remove(node.mesh)
    for (const edge of this.edges) this.scene.remove(edge)
    this.nodes.clear()
    this.edges = []
  }

  applyEvent(event) {
    switch (event.type) {
      case "job_started":
        this.addNode("root", "User task", "running", 0)
        break
      case "agent_spawned":
        this.addNode(event.agent_id, event.label || event.agent_id, event.status || "idle")
        this.addEdge(event.parent_id || "root", event.agent_id)
        break
      case "agent_status_changed":
        this.updateNode(event.agent_id, event.status)
        break
      case "tool_started":
      case "tool_observation":
      case "tool_completed":
        this.addNode(event.tool_id, event.tool_id, event.status || "running", 0.75)
        if (event.agent_id) this.addEdge(event.agent_id, event.tool_id)
        if (event.status) this.updateNode(event.tool_id, event.status)
        break
      case "approval_required":
        this.addNode(event.approval_id, "approval", "waiting_for_approval", 0.65)
        this.addEdge(event.agent_id, event.approval_id)
        this.updateNode(event.agent_id, "waiting_for_approval")
        break
      case "message_sent":
        this.addEdge(event.from_agent_id, event.to_agent_id)
        break
      case "job_completed":
        this.updateNode("synthesizer", "completed")
        break
      case "job_failed":
        this.updateNode(event.agent_id || "root", "failed")
        break
    }
  }

  addNode(id, label, status = "idle", scale = 1) {
    if (!id || this.nodes.has(id)) return
    const index = this.nodes.size
    const angle = index === 0 ? 0 : (index / 10) * Math.PI * 2
    const radius = index === 0 ? 0 : 16 + (index % 3) * 7
    const geometry = new THREE.SphereGeometry(1.8 * scale, 32, 16)
    const material = new THREE.MeshStandardMaterial({
      color: STATUS_COLORS[status] || STATUS_COLORS.idle,
      emissive: STATUS_COLORS[status] || STATUS_COLORS.idle,
      emissiveIntensity: 0.28,
      roughness: 0.38,
      metalness: 0.15
    })
    const mesh = new THREE.Mesh(geometry, material)
    mesh.position.set(Math.cos(angle) * radius, Math.sin(angle) * radius, (index % 4) * 4 - 6)
    this.scene.add(mesh)
    this.nodes.set(id, {id, label, status, mesh, baseY: mesh.position.y})
  }

  updateNode(id, status) {
    const node = this.nodes.get(id)
    if (!node) return
    node.status = status
    const color = STATUS_COLORS[status] || STATUS_COLORS.idle
    node.mesh.material.color.setHex(color)
    node.mesh.material.emissive.setHex(color)
  }

  addEdge(from, to) {
    const source = this.nodes.get(from)
    const target = this.nodes.get(to)
    if (!source || !target) return

    const geometry = new THREE.BufferGeometry().setFromPoints([
      source.mesh.position.clone(),
      target.mesh.position.clone()
    ])
    const line = new THREE.Line(geometry, this.edgeMaterial.clone())
    this.scene.add(line)
    this.edges.push(line)
  }

  resize() {
    const rect = this.container.getBoundingClientRect()
    const width = Math.max(rect.width, 1)
    const height = Math.max(rect.height, 1)
    this.camera.aspect = width / height
    this.camera.updateProjectionMatrix()
    this.renderer.setSize(width, height, false)
  }

  animate() {
    requestAnimationFrame(() => this.animate())
    const t = this.clock.getElapsedTime()

    for (const [index, node] of Array.from(this.nodes.values()).entries()) {
      node.mesh.rotation.x += 0.006
      node.mesh.rotation.y += 0.01
      node.mesh.position.y = node.baseY + Math.sin(t * 1.4 + index) * 0.45
    }

    this.scene.rotation.y = Math.sin(t * 0.25) * 0.12
    this.renderer.render(this.scene, this.camera)
  }
}
