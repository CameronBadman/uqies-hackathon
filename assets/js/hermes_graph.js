import * as THREE from "three"

const STATUS_COLORS = {
  idle: 0x8fa19a,
  running: 0x5ff0c3,
  waiting_for_approval: 0xffc857,
  completed: 0x91ee67,
  failed: 0xe86b6b,
  rejected: 0xbe8aff,
  unavailable: 0xa4adb9
}

const STATUS_ACCENTS = {
  idle: 0xc4d3cc,
  running: 0xe5fff4,
  waiting_for_approval: 0xfff0bd,
  completed: 0xe8ffd8,
  failed: 0xffd0d0,
  rejected: 0xead8ff,
  unavailable: 0xe1e7ef
}

const NODE_LAYOUT = {
  root: [0, 0, 3],
  browser: [-24, 12, -2],
  research: [-8, 18, 2],
  analyst: [12, 13, -3],
  calendar: [28, 4, 2],
  scheduler: [20, -14, -1],
  synthesizer: [-8, -18, 3],
  "browser.playwright": [-35, 0, 0],
  "search.serper": [-13, 31, -1],
  "calendar.google": [38, -8, 2],
  "scheduler.local": [31, -25, -2],
  "llm.openai": [-22, -31, 1]
}

export class HermesGraph {
  constructor(container) {
    this.container = container
    this.nodes = new Map()
    this.edges = []
    this.particles = []
    this.raycaster = new THREE.Raycaster()
    this.pointer = new THREE.Vector2()
    this.dragPlane = new THREE.Plane(new THREE.Vector3(0, 0, 1), 0)
    this.dragOffset = new THREE.Vector3()
    this.dragIntersection = new THREE.Vector3()
    this.draggedNode = null
    this.hoveredNode = null
    this.isPanning = false
    this.panStart = new THREE.Vector2()
    this.cameraStart = new THREE.Vector3()
    this.scene = new THREE.Scene()
    this.scene.background = new THREE.Color(0x070a0b)

    this.defaultCamera = new THREE.Vector3(0, 0, 92)
    this.camera = new THREE.PerspectiveCamera(50, 1, 0.1, 1000)
    this.camera.position.copy(this.defaultCamera)

    this.renderer = new THREE.WebGLRenderer({antialias: true, powerPreference: "high-performance"})
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 3))
    this.renderer.outputColorSpace = THREE.SRGBColorSpace
    this.renderer.toneMapping = THREE.ACESFilmicToneMapping
    this.renderer.toneMappingExposure = 1.16
    this.container.appendChild(this.renderer.domElement)

    this.clock = new THREE.Clock()
    this.edgeMaterial = new THREE.LineBasicMaterial({color: 0x65bda6, transparent: true, opacity: 0.5})
    this.grid = this.createGrid()
    this.nebula = this.createNebula()
    this.scene.add(this.nebula, this.grid)
    this.scene.add(this.createStarField())

    const ambient = new THREE.AmbientLight(0xffffff, 0.42)
    const key = new THREE.PointLight(0x6af1c7, 6.5, 150)
    const warm = new THREE.PointLight(0xffc857, 2.6, 120)
    const rim = new THREE.DirectionalLight(0xbbe7ff, 1.7)
    key.position.set(-25, 26, 38)
    warm.position.set(34, -18, 32)
    rim.position.set(0, 0, 60)
    this.scene.add(ambient, key, warm, rim)

    window.addEventListener("resize", () => this.resize())
    this.renderer.domElement.addEventListener("pointerdown", event => this.onPointerDown(event))
    this.renderer.domElement.addEventListener("pointermove", event => this.onPointerMove(event))
    this.renderer.domElement.addEventListener("pointerup", event => this.onPointerUp(event))
    this.renderer.domElement.addEventListener("pointercancel", event => this.onPointerUp(event))
    this.renderer.domElement.addEventListener("wheel", event => this.onWheel(event), {passive: false})
    this.resize()
    this.animate()
  }

  reset() {
    for (const node of this.nodes.values()) {
      this.scene.remove(node.group)
    }
    for (const edge of this.edges) this.scene.remove(edge.line)
    for (const particle of this.particles) this.scene.remove(particle.mesh)
    this.nodes.clear()
    this.edges = []
    this.particles = []
  }

  applyEvent(event) {
    switch (event.type) {
      case "job_started":
        this.addNode("root", "User task", "running", 1.25)
        break
      case "agent_spawned":
        this.addNode(event.agent_id, event.label || event.agent_id, event.status || "idle", 1)
        this.addEdge(event.parent_id || "root", event.agent_id, true)
        break
      case "agent_status_changed":
        this.updateNode(event.agent_id, event.status)
        break
      case "tool_started":
      case "tool_observation":
      case "tool_completed":
        this.addNode(event.tool_id, event.tool_id, event.status || "running", 0.72)
        if (event.agent_id) this.addEdge(event.agent_id, event.tool_id, true)
        if (event.status) this.updateNode(event.tool_id, event.status)
        break
      case "approval_required":
        this.addNode(event.approval_id, "approval", "waiting_for_approval", 0.62)
        this.addEdge(event.agent_id, event.approval_id, true)
        this.updateNode(event.agent_id, "waiting_for_approval")
        break
      case "message_sent":
        this.addEdge(event.from_agent_id, event.to_agent_id, true)
        break
      case "job_completed":
        this.updateNode("synthesizer", "completed")
        this.updateNode("root", "completed")
        break
      case "job_failed":
        this.updateNode(event.agent_id || "root", "failed")
        break
    }
  }

  addNode(id, label, status = "idle", scale = 1) {
    if (!id || this.nodes.has(id)) return

    const group = new THREE.Group()
    const position = this.positionFor(id)
    group.position.set(position[0], position[1], position[2])

    const color = STATUS_COLORS[status] || STATUS_COLORS.idle
    const accent = STATUS_ACCENTS[status] || STATUS_ACCENTS.idle
    const coreGeometry = new THREE.DodecahedronGeometry(2.45 * scale, 1)
    const core = new THREE.Mesh(
      coreGeometry,
      new THREE.MeshPhysicalMaterial({
        color,
        clearcoat: 0.85,
        clearcoatRoughness: 0.18,
        emissive: color,
        emissiveIntensity: 0.22,
        roughness: 0.18,
        metalness: 0.5
      })
    )

    const edgeOutline = new THREE.LineSegments(
      new THREE.EdgesGeometry(coreGeometry, 18),
      new THREE.LineBasicMaterial({color: accent, transparent: true, opacity: 0.85})
    )

    const halo = new THREE.Mesh(
      new THREE.TorusGeometry(3.25 * scale, 0.035, 8, 128),
      new THREE.MeshBasicMaterial({color: accent, transparent: true, opacity: 0.86})
    )
    halo.rotation.x = Math.PI / 2

    const outerHalo = new THREE.Mesh(
      new THREE.TorusGeometry(4.08 * scale, 0.018, 8, 160),
      new THREE.MeshBasicMaterial({color, transparent: true, opacity: 0.42})
    )
    outerHalo.rotation.x = Math.PI / 2
    outerHalo.rotation.y = Math.PI / 5

    const verticalRing = new THREE.Mesh(
      new THREE.TorusGeometry(3.64 * scale, 0.018, 8, 128),
      new THREE.MeshBasicMaterial({color: accent, transparent: true, opacity: 0.38})
    )
    verticalRing.rotation.y = Math.PI / 2.35

    const labelSprite = this.createLabel(label)
    labelSprite.position.set(0, -5.15 * scale, 0)

    group.add(core, edgeOutline, halo, outerHalo, verticalRing, labelSprite)
    this.scene.add(group)
    core.userData.nodeId = id
    halo.userData.nodeId = id
    this.nodes.set(id, {
      id,
      label,
      status,
      group,
      core,
      edgeOutline,
      halo,
      outerHalo,
      verticalRing,
      labelSprite,
      baseY: position[1],
      scale,
      grabbed: false
    })
  }

  updateNode(id, status) {
    const node = this.nodes.get(id)
    if (!node) return
    node.status = status
    const color = STATUS_COLORS[status] || STATUS_COLORS.idle
    const accent = STATUS_ACCENTS[status] || STATUS_ACCENTS.idle
    node.core.material.color.setHex(color)
    node.core.material.emissive.setHex(color)
    node.edgeOutline.material.color.setHex(accent)
    node.halo.material.color.setHex(accent)
    node.outerHalo.material.color.setHex(color)
    node.verticalRing.material.color.setHex(accent)
    node.halo.material.opacity = status === "running" ? 1 : 0.78
  }

  addEdge(from, to, pulse = false) {
    const source = this.nodes.get(from)
    const target = this.nodes.get(to)
    if (!source || !target) return

    const key = `${from}->${to}`
    if (this.edges.some(edge => edge.key === key)) {
      if (pulse) this.addParticle(source, target)
      return
    }

    const curve = this.curveBetween(source.group.position, target.group.position)
    const line = new THREE.Line(
      new THREE.BufferGeometry().setFromPoints(curve.getPoints(28)),
      this.edgeMaterial.clone()
    )
    this.scene.add(line)
    this.edges.push({key, from, to, source, target, line})
    if (pulse) this.addParticle(source, target)
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
      node.core.rotation.x += 0.008
      node.core.rotation.y += 0.012
      node.edgeOutline.rotation.copy(node.core.rotation)
      node.halo.rotation.z -= 0.01 + index * 0.0007
      node.outerHalo.rotation.z += 0.006
      node.verticalRing.rotation.x += 0.004
      if (!node.grabbed) node.group.position.y = node.baseY + Math.sin(t * 1.2 + index) * 0.38
      const pulse = node.status === "running" || node.status === "waiting_for_approval"
      if (!node.grabbed && node !== this.hoveredNode) {
        node.halo.scale.setScalar(pulse ? 1 + Math.sin(t * 4 + index) * 0.08 : 1)
        node.outerHalo.scale.setScalar(pulse ? 1 + Math.cos(t * 3.2 + index) * 0.04 : 1)
      }
    }

    for (const edge of this.edges) {
      const curve = this.curveBetween(edge.source.group.position, edge.target.group.position)
      edge.line.geometry.setFromPoints(curve.getPoints(28))
    }

    this.animateParticles(0.012)
    this.grid.rotation.z = Math.sin(t * 0.12) * 0.02
    this.nebula.rotation.z = Math.sin(t * 0.04) * 0.035
    this.scene.rotation.y = Math.sin(t * 0.18) * 0.08
    this.renderer.render(this.scene, this.camera)
  }

  onPointerDown(event) {
    const node = this.pickNode(event)
    event.preventDefault()
    if (!node) {
      this.isPanning = true
      this.panStart.set(event.clientX, event.clientY)
      this.cameraStart.copy(this.camera.position)
      this.renderer.domElement.setPointerCapture(event.pointerId)
      this.renderer.domElement.style.cursor = "move"
      return
    }

    this.draggedNode = node
    node.grabbed = true
    node.halo.material.opacity = 1
    node.halo.scale.setScalar(1.18)
    node.outerHalo.scale.setScalar(1.12)
    this.dragPlane.setFromNormalAndCoplanarPoint(new THREE.Vector3(0, 0, 1), node.group.position)
    this.setPointer(event)
    this.raycaster.setFromCamera(this.pointer, this.camera)
    this.raycaster.ray.intersectPlane(this.dragPlane, this.dragIntersection)
    this.dragOffset.copy(node.group.position).sub(this.dragIntersection)
    this.renderer.domElement.setPointerCapture(event.pointerId)
    this.renderer.domElement.style.cursor = "grabbing"
  }

  onPointerMove(event) {
    if (this.draggedNode) {
      this.setPointer(event)
      this.raycaster.setFromCamera(this.pointer, this.camera)
      if (this.raycaster.ray.intersectPlane(this.dragPlane, this.dragIntersection)) {
        this.draggedNode.group.position.copy(this.dragIntersection.add(this.dragOffset))
        this.draggedNode.baseY = this.draggedNode.group.position.y
      }
      return
    }

    if (this.isPanning) {
      const rect = this.renderer.domElement.getBoundingClientRect()
      const visibleHeight = 2 * this.camera.position.z * Math.tan(THREE.MathUtils.degToRad(this.camera.fov / 2))
      const worldPerPixel = visibleHeight / Math.max(rect.height, 1)
      const dx = event.clientX - this.panStart.x
      const dy = event.clientY - this.panStart.y
      this.camera.position.x = this.cameraStart.x - dx * worldPerPixel
      this.camera.position.y = this.cameraStart.y + dy * worldPerPixel
      return
    }

    const node = this.pickNode(event)
    if (node !== this.hoveredNode) {
      if (this.hoveredNode && !this.hoveredNode.grabbed) {
        this.hoveredNode.halo.scale.setScalar(1)
        this.hoveredNode.outerHalo.scale.setScalar(1)
      }
      this.hoveredNode = node
      if (node) {
        node.halo.scale.setScalar(1.14)
        node.outerHalo.scale.setScalar(1.08)
      }
    }
    this.renderer.domElement.style.cursor = node ? "grab" : "default"
  }

  onPointerUp(event) {
    if (this.isPanning) {
      this.isPanning = false
      if (this.renderer.domElement.hasPointerCapture(event.pointerId)) {
        this.renderer.domElement.releasePointerCapture(event.pointerId)
      }
      this.renderer.domElement.style.cursor = this.hoveredNode ? "grab" : "default"
      return
    }

    if (!this.draggedNode) return
    this.draggedNode.grabbed = false
    this.draggedNode.halo.scale.setScalar(1)
    this.draggedNode.outerHalo.scale.setScalar(1)
    this.draggedNode.halo.material.opacity = this.draggedNode.status === "running" ? 0.95 : 0.7
    this.draggedNode = null
    if (this.renderer.domElement.hasPointerCapture(event.pointerId)) {
      this.renderer.domElement.releasePointerCapture(event.pointerId)
    }
    this.renderer.domElement.style.cursor = this.hoveredNode ? "grab" : "default"
  }

  onWheel(event) {
    event.preventDefault()
    const direction = Math.sign(event.deltaY)
    const factor = direction > 0 ? 1.12 : 0.88
    this.setZoom(this.camera.position.z * factor)
  }

  zoomIn() {
    this.setZoom(this.camera.position.z * 0.82)
  }

  zoomOut() {
    this.setZoom(this.camera.position.z * 1.22)
  }

  resetView() {
    this.camera.position.copy(this.defaultCamera)
  }

  setZoom(distance) {
    this.camera.position.z = THREE.MathUtils.clamp(distance, 34, 150)
  }

  pickNode(event) {
    this.setPointer(event)
    this.raycaster.setFromCamera(this.pointer, this.camera)
    const meshes = Array.from(this.nodes.values()).map(node => node.core)
    const [hit] = this.raycaster.intersectObjects(meshes, false)
    return hit ? this.nodes.get(hit.object.userData.nodeId) : null
  }

  setPointer(event) {
    const rect = this.renderer.domElement.getBoundingClientRect()
    this.pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1
    this.pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1
  }

  animateParticles(speed) {
    for (const particle of [...this.particles]) {
      particle.progress += speed
      if (particle.progress >= 1) {
        this.scene.remove(particle.mesh)
        this.particles = this.particles.filter(item => item !== particle)
        continue
      }
      const curve = this.curveBetween(particle.source.group.position, particle.target.group.position)
      particle.mesh.position.copy(curve.getPoint(particle.progress))
      particle.mesh.material.opacity = 1 - Math.max(0, particle.progress - 0.72) / 0.28
    }
  }

  addParticle(source, target) {
    const mesh = new THREE.Mesh(
      new THREE.SphereGeometry(0.45, 16, 8),
      new THREE.MeshBasicMaterial({color: 0xe8fff5, transparent: true, opacity: 0.95})
    )
    this.scene.add(mesh)
    this.particles.push({source, target, mesh, progress: 0})
  }

  curveBetween(source, target) {
    const mid = source.clone().add(target).multiplyScalar(0.5)
    mid.z += 10 + source.distanceTo(target) * 0.08
    return new THREE.QuadraticBezierCurve3(source.clone(), mid, target.clone())
  }

  positionFor(id) {
    if (NODE_LAYOUT[id]) return NODE_LAYOUT[id]
    const index = this.nodes.size
    const angle = index * 1.91
    const radius = 18 + (index % 5) * 5
    return [Math.cos(angle) * radius, Math.sin(angle) * radius, (index % 5) * 3 - 6]
  }

  createGrid() {
    const group = new THREE.Group()
    const material = new THREE.LineBasicMaterial({color: 0x1d4f47, transparent: true, opacity: 0.24})
    for (let i = -60; i <= 60; i += 10) {
      const horizontal = new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(-70, i, -18),
        new THREE.Vector3(70, i, -18)
      ])
      const vertical = new THREE.BufferGeometry().setFromPoints([
        new THREE.Vector3(i, -44, -18),
        new THREE.Vector3(i, 44, -18)
      ])
      group.add(new THREE.Line(horizontal, material), new THREE.Line(vertical, material))
    }
    return group
  }

  createNebula() {
    const canvas = document.createElement("canvas")
    canvas.width = 1024
    canvas.height = 1024
    const ctx = canvas.getContext("2d")
    const gradient = ctx.createRadialGradient(512, 512, 40, 512, 512, 520)
    gradient.addColorStop(0, "rgba(95, 240, 195, 0.20)")
    gradient.addColorStop(0.35, "rgba(68, 118, 160, 0.08)")
    gradient.addColorStop(0.72, "rgba(255, 200, 87, 0.035)")
    gradient.addColorStop(1, "rgba(0, 0, 0, 0)")
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, 1024, 1024)

    const texture = new THREE.CanvasTexture(canvas)
    texture.colorSpace = THREE.SRGBColorSpace
    const material = new THREE.SpriteMaterial({map: texture, transparent: true, depthWrite: false})
    const sprite = new THREE.Sprite(material)
    sprite.position.set(0, 0, -55)
    sprite.scale.set(132, 132, 1)
    return sprite
  }

  createStarField() {
    const geometry = new THREE.BufferGeometry()
    const positions = []
    for (let i = 0; i < 550; i++) {
      positions.push((Math.random() - 0.5) * 150, (Math.random() - 0.5) * 95, -35 - Math.random() * 80)
    }
    geometry.setAttribute("position", new THREE.Float32BufferAttribute(positions, 3))
    return new THREE.Points(
      geometry,
      new THREE.PointsMaterial({color: 0xbefdea, size: 0.13, transparent: true, opacity: 0.58})
    )
  }

  createLabel(text) {
    const canvas = document.createElement("canvas")
    canvas.width = 1024
    canvas.height = 256
    const ctx = canvas.getContext("2d")
    ctx.imageSmoothingEnabled = true
    ctx.fillStyle = "rgba(7, 10, 11, 0.88)"
    ctx.strokeStyle = "rgba(190, 253, 234, 0.42)"
    ctx.lineWidth = 3
    ctx.roundRect(48, 58, 928, 116, 24)
    ctx.fill()
    ctx.stroke()
    ctx.font = "700 58px system-ui, -apple-system, Segoe UI, sans-serif"
    ctx.fillStyle = "#edf3ef"
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    ctx.fillText(text, 512, 116, 850)
    const texture = new THREE.CanvasTexture(canvas)
    texture.colorSpace = THREE.SRGBColorSpace
    texture.anisotropy = Math.min(this.renderer.capabilities.getMaxAnisotropy(), 8)
    const sprite = new THREE.Sprite(new THREE.SpriteMaterial({map: texture, transparent: true}))
    sprite.scale.set(18, 4.5, 1)
    return sprite
  }
}
