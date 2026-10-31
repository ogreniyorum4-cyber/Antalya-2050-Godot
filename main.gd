extends Node3D
## Antalya 2050 - 3D iklim dirençli şehir oyunu (Godot 4).
## Tüm dünya, karakter ve arayüz bu betikte kodla kurulur; dışarıdan varlık (asset) kullanılmaz.

const D := preload("res://data.gd")

# ---------- renkler ----------
const C_INK := Color("#13261F")
const C_INK2 := Color("#1E3A31")
const C_LINE := Color("#3A5A4E")
const C_TEXT := Color("#F2F4EF")
const C_MUTED := Color("#B9C7BF")
const C_GOLD := Color("#E8A417")
const C_SEA := Color("#127A99")
const C_RISK := Color("#E0634A")
const C_OK := Color("#3E9A62")
const STAT_COL := {"w": Color("#4FB6D6"), "h": Color("#F07A5F"), "e": Color("#E8B53A"), "n": Color("#6BC48A")}

# ---------- oyun durumu ----------
var lang := "tr"
var phase := "intro"   # intro, play, decide, feedback, event_anim, event, end
var round_i := 0
var stats := {}
var budget := 10
var tags: Array = []
var flags: Array = []
var pending: Array = []
var log_list: Array = []
var evlog: Array = []
var done: Array = []
var choices := {}
var last_paid := 0
var ev := {}
var votes: Array = []
var saved := false
var tally: Array = []
var near_di := -1
var autoplay := false
var auto_t := 0.0
var t_clock := 0.0

# ---------- dünya düğümleri ----------
var player: CharacterBody3D
var player_vis: Node3D
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment
var sky_mat: ProceduralSkyMaterial
var ground_mat: StandardMaterial3D
var sea_mat: StandardMaterial3D
var reservoir_water: MeshInstance3D
var forest_trees: Array = []
var roofs: Array = []
var stations: Array = []
var arrow: MeshInstance3D
var target_marker: MeshInstance3D
var visuals: Node3D
var fx: Node3D
var flood_plane: MeshInstance3D
var seagrass: Node3D
var siren_light: MeshInstance3D
var click_target = null
var path_pts: Array = []
var solids: Array = []
var astar := AStarGrid2D.new()
var cam_mode := "orbit"
var mat_cache := {}
var rng := RandomNumberGenerator.new()

# ---------- arayüz düğümleri ----------
var ui: Control
var hud: Control
var overlay: Control
var stat_bars := {}
var stat_vals := {}
var stat_names := {}
var budget_lbl: Label
var period_lbl: Label
var title_lbl: Label
var year_chips: Array = []
var lang_btn: Button
var tasks_rt: RichTextLabel
var controls_lbl: Label
var prompt_btn: Button
var toast_lbl: Label


func _ready() -> void:
	rng.seed = 2050
	var args := OS.get_cmdline_user_args()
	if "--autoplay" in args:
		autoplay = true
	if "--fast" in args:
		Engine.time_scale = 6.0
	if OS.has_feature("web"):
		var q = JavaScriptBridge.eval("window.location.search", true)
		if typeof(q) == TYPE_STRING and "autoplay" in q:
			autoplay = true
		if typeof(q) == TYPE_STRING and "fast" in q:
			Engine.time_scale = 4.0
		if typeof(q) == TYPE_STRING and "lang=en" in q:
			lang = "en"
		if typeof(q) == TYPE_STRING and "endtest" in q:
			call_deferred("_endtest")
	if "--endtest" in args:
		call_deferred("_endtest")
	reset_state()
	build_world()
	build_ui()
	refresh_world()
	show_intro()


# Test: tüm kararları hızlıca verip sonuç ekranını açar (?endtest)
func _endtest() -> void:
	_on_start()
	for r in 3:
		round_i = r
		for di in range(r * 3, r * 3 + 3):
			var opts: Array = D.DEC[di]["opts"]
			var pick := 2
			for i in opts.size():
				if cost_of(opts[i]) <= budget:
					pick = i
					break
			_on_choose(di, pick)
		var id: String = D.POOLS[r][0]
		evlog.append({"round": r, "id": id, "prepared": r != 1})
		if r < 2:
			budget += 10
	clear_overlay()
	votes = [0, 3, 8]
	_on_save()
	print("ENDTEST ", stats)


func reset_state() -> void:
	phase = "intro"
	round_i = 0
	stats = {"w": 50, "h": 60, "e": 60, "n": 55}
	budget = 10
	tags = []
	flags = []
	pending = []
	log_list = []
	evlog = []
	done = []
	for i in D.DEC.size():
		done.append(false)
	choices = {}
	ev = {}
	votes = []
	saved = false
	near_di = -1
	click_target = null


func t(k: String):
	return D.UI[lang][k]


func tx(d: Dictionary) -> String:
	return d[lang]


func has_tag(tg: String) -> bool:
	return tg in tags


func cost_of(o: Dictionary) -> int:
	var c: int = o["cost"]
	if o.has("disc") and has_tag(o["disc"]["tag"]):
		c = max(0, c - int(o["disc"]["amt"]))
	return c


func apply_eff(eff: Dictionary) -> void:
	for k in D.KEYS:
		if eff.has(k):
			stats[k] = clampi(stats[k] + int(eff[k]), 0, 100)


# =====================================================================
#  DÜNYA
# =====================================================================
func mat(c: Color, rough := 0.9, unshaded := false, alpha := 1.0, emit := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [c.to_html(), rough, unshaded, alpha, emit]
	if mat_cache.has(key):
		return mat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	mat_cache[key] = m
	return m


func box(size: Vector3, pos: Vector3, c: Color, parent: Node = null, collide := false, m: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m if m != null else mat(c)
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	if collide:
		if size.x < 20.0 and size.y > 0.5:
			var gp := mi.position if parent == null or parent == self else (parent as Node3D).position + pos
			solids.append(Rect2(gp.x - size.x / 2.0, gp.z - size.z / 2.0, size.x, size.z))
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


func cyl(top_r: float, bot_r: float, h: float, pos: Vector3, c: Color, parent: Node = null, seg := 16, m: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = seg
	mi.mesh = cm
	mi.material_override = m if m != null else mat(c)
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func sphere(r: float, pos: Vector3, c: Color, parent: Node = null, m: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	mi.material_override = m if m != null else mat(c)
	mi.position = pos
	(parent if parent != null else self).add_child(mi)
	return mi


func tree(pos: Vector3, s := 1.0, parent: Node = null, palm := false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	(parent if parent != null else self).add_child(n)
	cyl(0.12 * s, 0.16 * s, 1.0 * s, Vector3(0, 0.5 * s, 0), Color("#6B4E2E"), n, 6)
	if palm:
		sphere(0.7 * s, Vector3(0, 1.3 * s, 0), Color("#3E8A55"), n)
	else:
		cyl(0.0, 0.85 * s, 2.2 * s, Vector3(0, 1.9 * s, 0), Color("#25563A"), n, 8)
	return n


func label3d(txt: String, pos: Vector3, parent: Node, size := 64) -> Label3D:
	var l := Label3D.new()
	l.text = txt
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = size
	l.pixel_size = 0.012
	l.outline_size = 16
	l.modulate = Color.WHITE
	l.outline_modulate = C_INK
	l.no_depth_test = true
	l.position = pos
	parent.add_child(l)
	return l


func build_world() -> void:
	# Işık ve gökyüzü
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.45
	env.ambient_light_sky_contribution = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.fog_enabled = false
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)

	# Zemin, kumsal, deniz
	ground_mat = StandardMaterial3D.new()
	ground_mat.albedo_color = Color("#8FA86A")
	ground_mat.roughness = 1.0
	box(Vector3(140, 1, 64), Vector3(0, -0.5, -14), Color.WHITE, self, true, ground_mat)
	box(Vector3(140, 0.12, 4.5), Vector3(0, 0.02, 16.2), Color("#E6D3A3"))
	sea_mat = StandardMaterial3D.new()
	sea_mat.albedo_color = Color("#127A99")
	sea_mat.roughness = 0.55
	sea_mat.metallic = 0.0
	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(240, 120)
	sea.mesh = pm
	sea.material_override = sea_mat
	sea.position = Vector3(0, -0.12, 78)
	add_child(sea)
	seagrass = Node3D.new()
	seagrass.visible = false
	add_child(seagrass)

	# Yollar ve meydan
	box(Vector3(70, 0.06, 2.6), Vector3(0, 0.03, 12.6), Color("#4A4F4C"))
	box(Vector3(2.4, 0.06, 22), Vector3(0, 0.03, 3), Color("#4A4F4C"))
	box(Vector3(56, 0.06, 2.2), Vector3(0, 0.03, -2.6), Color("#4A4F4C"))
	box(Vector3(8, 0.08, 8), Vector3(0, 0.04, 3), Color("#D9D2C1"))
	cyl(1.2, 1.4, 0.6, Vector3(0, 0.3, 3), Color("#CFC6B0"))
	cyl(0.9, 0.9, 0.1, Vector3(0, 0.62, 3), Color("#3FA0C6"))

	# Toros dağları
	var peaks := [[-46, -36, 14, 13], [-28, -38, 17, 19], [-8, -40, 18, 22], [12, -38, 16, 18], [30, -39, 17, 20], [48, -35, 14, 13]]
	for p in peaks:
		cyl(0.0, p[2], p[3], Vector3(p[0], p[3] / 2.0 - 0.5, p[1]), Color("#6F8A5A"), self, 7)
		if p[3] > 17:
			cyl(0.0, p[2] * 0.22, p[3] * 0.22, Vector3(p[0], p[3] * 0.89 - 0.5, p[1]), Color("#F2F0E8"), self, 7)
	# Orman
	for i in 90:
		var x := rng.randf_range(-36, 36)
		var z := rng.randf_range(-27, -14.5)
		if abs(x - (-6)) < 3.0 and z > -16.0:
			continue
		forest_trees.append(tree(Vector3(x, 0, z), rng.randf_range(0.9, 1.5)))

	# Şehir blokları
	var avoid := [Vector2(0, 3)]
	for d in D.DEC:
		avoid.append(d["pos"])
	var xs := [-14.0, -9.0, -4.5, 4.5, 9.0, 14.0]
	var zs := [-6.5, 1.0, 6.0, 9.5]
	for x in xs:
		for z in zs:
			var ok := true
			for a in avoid:
				if Vector2(x, z).distance_to(a) < 4.2:
					ok = false
			if not ok:
				continue
			var h := rng.randf_range(2.2, 6.5)
			var w := rng.randf_range(2.4, 3.2)
			var dpt := rng.randf_range(2.2, 2.8)
			var col: Color = [Color("#E7E1D3"), Color("#EDE8DC"), Color("#E2D7C3"), Color("#F1EDE4")][rng.randi() % 4]
			var b := box(Vector3(w, h, dpt), Vector3(x, h / 2.0, z), col, self, true)
			var roof := box(Vector3(w + 0.1, 0.18, dpt + 0.1), Vector3(0, h / 2.0 + 0.09, 0), Color("#B4553C"), b)
			roofs.append(roof)
			for wy in range(1, int(h)):
				box(Vector3(w * 0.8, 0.35, 0.05), Vector3(0, -h / 2.0 + wy + 0.2, dpt / 2.0 + 0.03), Color("#6F8796"), b)

	# Yer işaretleri: su deposu, belediye, seralar, oteller, iskele, atık sahası
	cyl(3.0, 3.2, 2.6, Vector3(-25, 1.3, -2), Color("#B9B3A3"))
	reservoir_water = cyl(2.75, 2.75, 1.0, Vector3(-25, 1.0, -2), Color("#2E8FB5"))
	box(Vector3(6.5, 4.2, 4.0), Vector3(7, 2.1, -8.2), Color("#F1EDE4"), self, true)
	sphere(1.4, Vector3(7, 4.4, -8.2), Color("#C9A24A"))
	label3d("BELEDİYE", Vector3(7, 3.3, -6.15), self, 40).billboard = BaseMaterial3D.BILLBOARD_DISABLED
	for gz in [-8.5, -4.5, -0.5]:
		box(Vector3(5, 2.2, 3), Vector3(26, 1.1, gz), Color("#E8F3F0"), self, true, mat(Color("#DDEFF0"), 0.2, false, 0.55))
	for hx in [16.0, 21.0, 26.0]:
		var hb := box(Vector3(3.6, 8.5, 3.0), Vector3(hx, 4.25, 6.5), Color("#FAFAF6"), self, true)
		for fy in range(1, 8):
			box(Vector3(3.7, 0.12, 0.4), Vector3(0, -4.25 + fy, 1.6), Color("#7FB3C9"), hb)
		roofs.append(box(Vector3(3.7, 0.18, 3.1), Vector3(0, 4.34, 0), Color("#C9C2B0"), hb))
	box(Vector3(2, 0.3, 9), Vector3(-10, 0.15, 20.5), Color("#8A6A45"))
	for pz in [17.0, 20.0, 23.0]:
		cyl(0.15, 0.15, 1.4, Vector3(-10.9, -0.4, pz), Color("#5C4630"))
		cyl(0.15, 0.15, 1.4, Vector3(-9.1, -0.4, pz), Color("#5C4630"))
	var mound := sphere(3.2, Vector3(-27, 0, -12), Color("#8C7355"))
	mound.scale = Vector3(1.3, 0.5, 1.0)
	mound.name = "Mound"
	for pt in [Vector2(-8, 8), Vector2(8, 8), Vector2(-16, 13.5), Vector2(-4, 13.6), Vector2(12, 13.6), Vector2(28, 13.6)]:
		tree(Vector3(pt.x, 0, pt.y), 1.0, self, true)

	# Sınır duvarları (görünmez)
	for wdef in [[Vector3(1, 6, 80), Vector3(-33, 3, -2)], [Vector3(1, 6, 80), Vector3(33, 3, -2)], [Vector3(80, 6, 1), Vector3(0, 3, -16.5)], [Vector3(80, 6, 1), Vector3(0, 3, 16.6)]]:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = wdef[0]
		cs.shape = sh
		sb.position = wdef[1]
		sb.add_child(cs)
		add_child(sb)

	visuals = Node3D.new()
	add_child(visuals)
	fx = Node3D.new()
	add_child(fx)

	# Sel düzlemi
	flood_plane = box(Vector3(70, 0.1, 30), Vector3(0, -0.4, 3), Color.WHITE, self, false, mat(Color("#3E88B0"), 0.1, false, 0.7))
	flood_plane.visible = false

	# İstasyonlar
	for i in D.DEC.size():
		var d: Dictionary = D.DEC[i]
		var p: Vector2 = d["pos"]
		var n := Node3D.new()
		n.position = Vector3(p.x, 0, p.y)
		add_child(n)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.5
		tm.outer_radius = 1.9
		ring.mesh = tm
		ring.material_override = mat(C_GOLD, 0.5, false, 1.0, 1.6)
		ring.position.y = 0.15
		n.add_child(ring)
		cyl(0.12, 0.12, 9.0, Vector3(0, 4.5, 0), C_GOLD, n, 8, mat(C_GOLD, 0.5, true, 0.35))
		var lb := label3d(tx(d["place"]), Vector3(0, 3.4, 0), n, 72)
		n.visible = false
		stations.append({"node": n, "ring": ring, "label": lb})

	# Oyuncu
	player = CharacterBody3D.new()
	player.position = Vector3(0, 0.1, 8)
	add_child(player)
	var pcs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.7
	pcs.shape = cap
	pcs.position.y = 0.85
	player.add_child(pcs)
	player_vis = Node3D.new()
	player.add_child(player_vis)
	var body := MeshInstance3D.new()
	var cmesh := CapsuleMesh.new()
	cmesh.radius = 0.38
	cmesh.height = 1.25
	body.mesh = cmesh
	body.material_override = mat(C_SEA, 0.6)
	body.position.y = 0.65
	player_vis.add_child(body)
	sphere(0.28, Vector3(0, 1.5, 0), Color("#E9C2A0"), player_vis)
	cyl(0.3, 0.33, 0.14, Vector3(0, 1.72, 0), C_GOLD, player_vis)
	box(Vector3(0.5, 0.08, 0.25), Vector3(0, 1.67, -0.28), C_GOLD, player_vis)
	box(Vector3(0.3, 0.4, 0.05), Vector3(0, 0.95, -0.37), Color("#F2F4EF"), player_vis)

	arrow = MeshInstance3D.new()
	var am := CylinderMesh.new()
	am.top_radius = 0.0
	am.bottom_radius = 0.32
	am.height = 0.8
	am.radial_segments = 4
	arrow.mesh = am
	arrow.material_override = mat(C_GOLD, 0.4, true)
	add_child(arrow)
	target_marker = MeshInstance3D.new()
	var tmk := TorusMesh.new()
	tmk.inner_radius = 0.3
	tmk.outer_radius = 0.45
	target_marker.mesh = tmk
	target_marker.material_override = mat(Color.WHITE, 0.5, true, 0.8)
	target_marker.visible = false
	add_child(target_marker)

	# Yol bulma ızgarası (1 m hücre): binaların çevresi dolu işaretlenir
	astar.region = Rect2i(-33, -17, 66, 34)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for r in solids:
		for gx in range(floori(r.position.x - 0.6), ceili(r.end.x + 0.6)):
			for gz in range(floori(r.position.y - 0.6), ceili(r.end.y + 0.6)):
				var id := Vector2i(gx, gz)
				if astar.is_in_boundsv(id):
					astar.set_point_solid(id, true)

	cam = Camera3D.new()
	cam.fov = 55
	cam.far = 400
	add_child(cam)
	cam.position = Vector3(0, 28, 40)
	cam.look_at(Vector3(0, 0, -2))


# Stat değerlerine bağlı kalıcı görünüm
func refresh_world() -> void:
	var heat: float = clampf((1.0 - stats["h"] / 100.0 - 0.35) * 1.6, 0.0, 1.0)
	sky_mat.sky_top_color = Color("#2F86C4").lerp(Color("#C9773A"), heat)
	sky_mat.sky_horizon_color = Color("#BFE3F0").lerp(Color("#F2C98E"), heat)
	sky_mat.ground_horizon_color = sky_mat.sky_horizon_color
	sky_mat.ground_bottom_color = Color("#6F8A5A")
	sun.light_color = Color("#FFF6E5").lerp(Color("#FFC27A"), heat)
	var nat: float = stats["n"] / 100.0
	ground_mat.albedo_color = Color("#B39B6B").lerp(Color("#6E9A55"), clampf(nat * 1.3, 0, 1))
	var lvl: float = 0.2 + 2.3 * stats["w"] / 100.0
	reservoir_water.scale = Vector3(1, lvl, 1)
	reservoir_water.position.y = lvl / 2.0 + 0.05
	var show := int(round(forest_trees.size() * clampf(nat * 1.15, 0.1, 1.0)))
	for i in forest_trees.size():
		forest_trees[i].visible = i < show
	sea_mat.albedo_color = Color("#5E8A86").lerp(Color("#127A99"), nat)


func refresh_stations() -> void:
	for i in stations.size():
		var active: bool = phase != "intro" and phase != "end" and int(i / 3) == round_i and not done[i]
		stations[i]["node"].visible = active
		stations[i]["label"].text = tx(D.DEC[i]["place"])


# Karar sonrası görünür değişiklikler
func spawn_visual(di: int, oi: int) -> void:
	var v := visuals
	match di:
		0:
			if oi == 0:
				for z in [-1.0, 5.0, 11.0]:
					box(Vector3(40, 0.12, 0.3), Vector3(-10, 0.08, z), Color("#2E8FB5"), v)
			elif oi == 1:
				for p in [Vector3(-12, 0, 0), Vector3(-7, 0, 4), Vector3(-12, 0, 8), Vector3(11, 0, 8), Vector3(6, 0, 4), Vector3(-16, 0, 6)]:
					cyl(0.45, 0.45, 1.1, p + Vector3(0, 0.55, 0), Color("#2E8FB5"), v)
			else:
				for p in [Vector3(-18, 0, 10), Vector3(-14, 0, 11)]:
					box(Vector3(0.5, 5, 0.5), p + Vector3(0, 2.5, 0), Color("#5A5A5A"), v)
					box(Vector3(2, 0.3, 2), p + Vector3(0, 0.15, 0), Color("#7A6A55"), v)
		1:
			if oi == 0:
				for a in 10:
					var ang := a * TAU / 10.0
					tree(Vector3(cos(ang) * 5.2, 0, 3 + sin(ang) * 5.2), 0.9, v, true)
			elif oi == 1:
				for r in roofs:
					r.material_override = mat(Color("#F7F7F2"), 0.4)
			else:
				for r in roofs.slice(0, 10):
					var b: Node3D = r.get_parent()
					box(Vector3(0.7, 0.5, 0.5), b.global_position + Vector3(0, 0, 1.6), Color("#9AA3A6"), v).global_position.y = 1.4
		2:
			if oi == 0:
				for x in [-22.0, 2.0, 22.0]:
					box(Vector3(3, 0.06, 14), Vector3(x, 0.04, -21), Color("#A9875B"), v)
			elif oi == 1:
				for p in [Vector3(-14, 0, -15), Vector3(12, 0, -15)]:
					box(Vector3(0.35, 6, 0.35), p + Vector3(0, 3, 0), Color("#6B4E2E"), v)
					box(Vector3(1.6, 0.9, 1.6), p + Vector3(0, 6.3, 0), Color("#C2412A"), v)
		3:
			if oi == 0:
				for x in [-22.0, -14.0, -6.0, 6.0, 14.0, 22.0, 28.0]:
					box(Vector3(5, 0.1, 1.2), Vector3(x, 0.06, 14.3), Color("#5FA05A"), v)
					tree(Vector3(x + 1.5, 0, 14.3), 0.5, v, true)
			elif oi == 1:
				box(Vector3(64, 0.9, 0.5), Vector3(0, 0.45, 14.9), Color("#9A9A94"), v)
		4:
			if oi == 0:
				for gz in [-8.5, -4.5, -0.5]:
					box(Vector3(5.2, 0.08, 0.15), Vector3(26, 2.3, gz), Color("#2E8FB5"), v)
					cyl(0.06, 0.06, 0.8, Vector3(23.3, 0.4, gz + 1.2), Color("#2E8FB5"), v)
			elif oi == 1:
				box(Vector3(3, 2, 3), Vector3(29.5, 1, 4), Color("#F1EDE4"), v)
				box(Vector3(3.2, 0.25, 3.2), Vector3(29.5, 2.1, 4), Color("#5FA05A"), v)
			else:
				box(Vector3(8, 0.05, 12), Vector3(26, 0.03, -4.5), Color("#3E88B0"), v, false, mat(Color("#3E88B0"), 0.1, false, 0.6))
		5:
			if oi == 0:
				for r in roofs:
					var b2: MeshInstance3D = r.get_parent()
					var sz: Vector3 = (b2.mesh as BoxMesh).size
					var pnl := box(Vector3(sz.x * 0.8, 0.08, sz.z * 0.6), Vector3.ZERO, Color("#24456B"), v, false, mat(Color("#24456B"), 0.2))
					pnl.global_position = b2.global_position + Vector3(0, sz.y / 2.0 + 0.4, 0)
					pnl.rotation_degrees.x = -18
			elif oi == 1:
				for p in [Vector3(-2, 0, 24), Vector3(8, 0, 28), Vector3(18, 0, 23)]:
					box(Vector3(1.2, 0.5, 3), p, Color("#F2F4EF"), v)
					box(Vector3(0.1, 2.2, 0.1), p + Vector3(0, 1.3, 0), Color("#8A6A45"), v)
			else:
				flags_hotels(v)
		6:
			if oi == 0:
				seagrass.visible = true
				for i in 26:
					var gx := rng.randf_range(-30, 30)
					var gz := rng.randf_range(20, 32)
					box(Vector3(rng.randf_range(1.5, 3.5), 0.05, rng.randf_range(1, 2.5)), Vector3(gx, -0.06, gz), Color("#2F6B45"), seagrass)
				for bx in [-24.0, -12.0, 0.0, 12.0, 24.0]:
					sphere(0.35, Vector3(bx, 0.05, 30), Color("#E8711A"), v)
			elif oi == 1:
				for x in [-26.0, -18.0, 4.0, 10.0, 24.0]:
					var dn := sphere(1.6, Vector3(x, -0.4, 16.3), Color("#D9C38E"), v)
					dn.scale = Vector3(1.6, 0.6, 0.8)
					tree(Vector3(x, 0.2, 16.3), 0.4, v, true)
			else:
				box(Vector3(60, 0.1, 3), Vector3(0, -0.02, 19.5), Color("#E6D3A3"), v)
		7:
			var mound: Node3D = get_node("Mound")
			if oi == 0:
				mound.scale = Vector3(0.9, 0.35, 0.7)
				for i in 5:
					box(Vector3(0.9, 0.9, 0.9), Vector3(-24 + i * 1.2, 0.45, -6.5), Color("#3E8A55"), v)
			elif oi == 1:
				box(Vector3(4, 3, 3), Vector3(-29, 1.5, -6), Color("#9AA3A6"), v)
				cyl(0.35, 0.45, 6, Vector3(-27.6, 3, -6), Color("#7A7F80"), v)
			else:
				mound.scale = Vector3(1.9, 0.8, 1.5)
		8:
			if oi == 0:
				box(Vector3(0.3, 7, 0.3), Vector3(10.6, 3.5, -6.5), Color("#9AA3A6"), v)
				box(Vector3(1, 0.6, 1), Vector3(10.6, 7.2, -6.5), Color("#F2F4EF"), v)
				siren_light = sphere(0.35, Vector3(10.6, 7.8, -6.5), Color("#FF3B2F"), v, mat(Color("#FF3B2F"), 0.3, true))
			elif oi == 1:
				box(Vector3(4, 2.4, 3), Vector3(-2, 1.2, -9), Color("#F1EDE4"), v)
				box(Vector3(4.2, 0.3, 3.2), Vector3(-2, 2.5, -9), Color("#E8A417"), v)
				for i in 4:
					box(Vector3(0.08, 2, 0.08), Vector3(-4 + i * 1.3, 1, -6.8), Color("#8A6A45"), v)
					box(Vector3(0.7, 0.45, 0.04), Vector3(-3.65 + i * 1.3, 1.75, -6.8), [C_SEA, C_GOLD, C_OK, C_RISK][i], v)


func flags_hotels(v: Node3D) -> void:
	for x in [-20.0, -26.0, 30.0]:
		box(Vector3(3.4, 9.5, 2.6), Vector3(x, 4.75, 15.6), Color("#FAFAF6"), v)
		box(Vector3(3.5, 0.15, 2.7), Vector3(x, 9.55, 15.6), Color("#C9C2B0"), v)


# =====================================================================
#  ARAYÜZ
# =====================================================================
func sb(bg: Color, radius := 12, margin := 16, border := Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	if border.a > 0.0:
		s.set_border_width_all(2)
		s.border_color = border
	return s


func lbl(txt: String, size := 18, col := C_TEXT, wrap := false) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func rt(bb: String, size := 16) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bb
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_color_override("default_color", C_TEXT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return r


func btn(txt: String, primary := true, size := 18) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", size)
	var base := C_GOLD if primary else C_INK2
	var fg := C_INK if primary else C_TEXT
	b.add_theme_stylebox_override("normal", sb(base, 10, 12, Color(0, 0, 0, 0) if primary else C_LINE))
	b.add_theme_stylebox_override("hover", sb(base.lightened(0.15), 10, 12, Color(0, 0, 0, 0) if primary else C_TEXT))
	b.add_theme_stylebox_override("pressed", sb(base.darkened(0.15), 10, 12))
	b.add_theme_stylebox_override("disabled", sb(Color("#2A4038"), 10, 12))
	b.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0), 10, 12, Color.WHITE))
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_disabled_color", Color("#7F938A"))
	return b


func pin(c: Control, ax: float, ay: float, ox: float, oy: float, gx: int, gy: int) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	c.grow_horizontal = gx
	c.grow_vertical = gy


func eff_bb(eff: Dictionary, numbers: bool) -> String:
	var parts := []
	for k in D.KEYS:
		if eff.has(k):
			var v: int = eff[k]
			var s := ""
			if numbers:
				s = ("+" if v > 0 else "") + str(v)
			else:
				s = ("++" if v >= 10 else "+") if v > 0 else ("--" if v <= -10 else "-")
			parts.append("[color=#%s]%s %s[/color]" % [STAT_COL[k].to_html(false), t(k), s])
	return "   ".join(parts)


func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 18
	ui.theme = th
	layer.add_child(ui)

	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)

	# Sol üst: göstergeler
	var sp := PanelContainer.new()
	sp.add_theme_stylebox_override("panel", sb(Color(C_INK.r, C_INK.g, C_INK.b, 0.9), 14, 14))
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin(sp, 0, 0, 16, 16, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	hud.add_child(sp)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	sp.add_child(v)
	title_lbl = lbl("Antalya 2050", 26, C_TEXT)
	v.add_child(title_lbl)
	period_lbl = lbl("", 15, C_GOLD)
	v.add_child(period_lbl)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for k in D.KEYS:
		var nl := lbl("", 15, C_MUTED)
		nl.custom_minimum_size.x = 76
		g.add_child(nl)
		stat_names[k] = nl
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(150, 12)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.show_percentage = false
		pb.max_value = 100
		pb.add_theme_stylebox_override("background", sb(Color("#2A4038"), 6, 0))
		pb.add_theme_stylebox_override("fill", sb(STAT_COL[k], 6, 0))
		pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(pb)
		stat_bars[k] = pb
		var vl := lbl("", 16, C_TEXT)
		vl.custom_minimum_size.x = 34
		vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		g.add_child(vl)
		stat_vals[k] = vl
	budget_lbl = lbl("", 18, C_GOLD)
	v.add_child(budget_lbl)

	# Sağ üst: yıllar ve dil
	var tr_box := HBoxContainer.new()
	tr_box.add_theme_constant_override("separation", 6)
	pin(tr_box, 1, 0, -16, 16, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	hud.add_child(tr_box)
	for y in ["2030", "2040", "2050"]:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cl := lbl(y, 15, C_TEXT)
		chip.add_child(cl)
		tr_box.add_child(chip)
		year_chips.append(chip)
	lang_btn = btn("EN", false, 15)
	lang_btn.pressed.connect(_on_lang)
	ui.add_child(lang_btn)
	pin(lang_btn, 1, 0, -16, 60, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)

	# Sol alt: görevler
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", sb(Color(C_INK.r, C_INK.g, C_INK.b, 0.88), 14, 14))
	tp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin(tp, 0, 1, 16, -16, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_BEGIN)
	hud.add_child(tp)
	var tv := VBoxContainer.new()
	tp.add_child(tv)
	tasks_rt = rt("", 16)
	tasks_rt.custom_minimum_size.x = 360
	tv.add_child(tasks_rt)
	controls_lbl = lbl("", 13, C_MUTED, true)
	controls_lbl.custom_minimum_size.x = 360
	tv.add_child(controls_lbl)

	# Alt orta: karar düğmesi
	prompt_btn = btn("", true, 22)
	prompt_btn.pressed.connect(_on_prompt)
	pin(prompt_btn, 0.5, 1, 0, -26, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	prompt_btn.visible = false
	hud.add_child(prompt_btn)

	toast_lbl = lbl("", 20, C_TEXT)
	toast_lbl.add_theme_constant_override("outline_size", 8)
	toast_lbl.add_theme_color_override("font_outline_color", C_INK)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin(toast_lbl, 0.5, 0, 0, 24, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	hud.add_child(toast_lbl)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	ui.move_child(lang_btn, ui.get_child_count() - 1)
	refresh_hud()


func refresh_hud() -> void:
	for k in D.KEYS:
		stat_names[k].text = t(k)
		stat_bars[k].value = stats[k]
		stat_vals[k].text = str(stats[k])
		stat_vals[k].add_theme_color_override("font_color", C_RISK if stats[k] < 25 else C_TEXT)
	budget_lbl.text = "%s: %d %s" % [t("budget"), budget, t("unit")]
	period_lbl.text = t("period")[round_i] if phase != "end" else "2050"
	for i in year_chips.size():
		var col := C_INK2
		if phase == "end" or i < round_i:
			col = C_OK
		elif i == round_i and phase != "intro":
			col = C_SEA
		year_chips[i].add_theme_stylebox_override("panel", sb(col, 8, 6))
	lang_btn.text = t("lang")
	controls_lbl.text = t("controls")
	var s := "[color=#%s]%s[/color]\n" % [C_GOLD.to_html(false), t("tasks")]
	for i in range(round_i * 3, round_i * 3 + 3):
		var d: Dictionary = D.DEC[i]
		if done[i]:
			s += "[color=#%s]  • %s: %s (%s)[/color]\n" % [C_MUTED.to_html(false), tx(d["place"]), tx(d["title"]), t("done")]
		else:
			s += "  • [b]%s[/b]: %s\n" % [tx(d["place"]), tx(d["title"])]
	tasks_rt.text = s.strip_edges()
	hud.visible = phase in ["play", "decide", "feedback", "event_anim", "event"]


func clear_overlay() -> void:
	for c in overlay.get_children():
		c.queue_free()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func open_panel(width := 920.0, dim := 0.45, scroll := false) -> VBoxContainer:
	clear_overlay()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, dim)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(cc)
	var vp := get_viewport().get_visible_rect().size
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(Color(C_INK.r, C_INK.g, C_INK.b, 0.97), 18, 26, C_LINE))
	p.custom_minimum_size.x = min(width, vp.x - 32)
	cc.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	if scroll:
		var sc := ScrollContainer.new()
		sc.custom_minimum_size = Vector2(min(width, vp.x - 32) - 52, vp.y - 110)
		sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		p.add_child(sc)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sc.add_child(v)
	else:
		p.add_child(v)
	return v


# ---------- ekranlar ----------
func show_intro() -> void:
	phase = "intro"
	cam_mode = "orbit"
	refresh_stations()
	refresh_hud()
	var v := open_panel(860, 0.35)
	v.add_child(lbl("COP31 · ANTALYA", 15, C_GOLD))
	v.add_child(lbl("Antalya 2050", 52, C_TEXT))
	v.add_child(lbl(t("introH"), 24, C_TEXT, true))
	v.add_child(lbl(t("introP"), 18, C_MUTED, true))
	var hs := ""
	for i in t("how").size():
		hs += "[color=#%s]%d.[/color]  %s\n" % [C_GOLD.to_html(false), i + 1, t("how")[i]]
	v.add_child(rt(hs.strip_edges(), 17))
	v.add_child(lbl(t("controls"), 15, C_MUTED, true))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var b := btn(t("start"), true, 22)
	b.pressed.connect(_on_start)
	row.add_child(b)
	var dl := lbl(t("dur"), 15, C_MUTED)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(dl)
	v.add_child(row)
	b.grab_focus()


func open_decision(di: int) -> void:
	phase = "decide"
	near_di = -1
	click_target = null
	target_marker.visible = false
	prompt_btn.visible = false
	var d: Dictionary = D.DEC[di]
	var v := open_panel(1000)
	v.add_child(lbl("%s · %s" % [t("period")[round_i], tx(d["place"]).to_upper()], 15, C_GOLD))
	v.add_child(lbl(tx(d["title"]), 32, C_TEXT, true))
	v.add_child(lbl(tx(d["ctx"]), 18, C_MUTED, true))
	var vp := get_viewport().get_visible_rect().size
	var grid := GridContainer.new()
	grid.columns = 3 if vp.x > 820 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var first_btn: Button = null
	for oi in d["opts"].size():
		var o: Dictionary = d["opts"][oi]
		var c := cost_of(o)
		var afford := c <= budget
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", sb(C_INK2, 12, 14, C_LINE))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.modulate.a = 1.0 if afford else 0.55
		grid.add_child(card)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		var tl := lbl(tx(o["label"]), 19, C_TEXT, true)
		tl.custom_minimum_size.x = 250 if grid.columns == 3 else 0
		cv.add_child(tl)
		var cost_s := "%s: [color=#%s][b]%d[/b][/color]" % [t("cost"), C_GOLD.to_html(false), c]
		if c != int(o["cost"]):
			cost_s += "  [color=#%s][s]%d[/s]  %s[/color]" % [C_MUTED.to_html(false), o["cost"], t("disc")]
		cv.add_child(rt(cost_s, 16))
		cv.add_child(lbl(tx(o["desc"]), 15, C_MUTED, true))
		cv.add_child(rt(eff_bb(o["eff"], false), 15))
		var extra := []
		for tg in o.get("tags", []):
			extra.append("[color=#%s]%s: %s[/color]" % [C_OK.lightened(0.25).to_html(false), t("prot"), tx(D.TAGS[tg])])
		if o.get("risk", false):
			extra.append("[color=#%s]%s[/color]" % [C_RISK.to_html(false), t("risk")])
		if o.has("later"):
			extra.append("[color=#%s]%s[/color]" % [C_RISK.to_html(false), t("later")])
		if extra.size() > 0:
			cv.add_child(rt("\n".join(extra), 14))
		var spacer := Control.new()
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cv.add_child(spacer)
		var cb := btn(("%s · %d %s" % [t("choose"), c, t("unit")]) if afford else t("notEnough"), afford, 17)
		cb.disabled = not afford
		cb.pressed.connect(_on_choose.bind(di, oi))
		cv.add_child(cb)
		if afford and first_btn == null:
			first_btn = cb
	var back := btn(t("walkOn"), false, 15)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_on_back)
	v.add_child(back)
	if first_btn:
		first_btn.grab_focus()
	refresh_hud()


func show_feedback(di: int, oi: int) -> void:
	phase = "feedback"
	var d: Dictionary = D.DEC[di]
	var o: Dictionary = d["opts"][oi]
	var v := open_panel(820, 0.25)
	v.add_child(lbl(t("yourChoice").to_upper(), 15, C_GOLD))
	v.add_child(lbl(tx(o["label"]), 30, C_TEXT, true))
	v.add_child(rt(eff_bb(o["eff"], true) + "   [color=#%s]%s -%d[/color]" % [C_GOLD.to_html(false), t("budget"), last_paid], 17))
	var fp := PanelContainer.new()
	fp.add_theme_stylebox_override("panel", sb(Color("#2B2A1A"), 10, 14, C_GOLD.darkened(0.3)))
	var fv := VBoxContainer.new()
	fp.add_child(fv)
	fv.add_child(lbl(t("dyk").to_upper(), 14, C_GOLD))
	fv.add_child(lbl(tx(d["fact"]), 17, C_TEXT, true))
	v.add_child(fp)
	var round_done := true
	for i in range(round_i * 3, round_i * 3 + 3):
		if not done[i]:
			round_done = false
	if round_done:
		v.add_child(lbl(t("allDone"), 16, C_MUTED, true))
	var b := btn(t("toEvent") if round_done else t("walkOn"), true, 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(_on_feedback_next.bind(round_done))
	v.add_child(b)
	b.grab_focus()
	refresh_hud()


func show_event_panel() -> void:
	phase = "event"
	var E: Dictionary = D.EVENTS[ev["id"]]
	var v := open_panel(780, 0.2)
	v.add_child(lbl(t("reach")[round_i].to_upper(), 15, C_GOLD))
	v.add_child(lbl(tx(E["title"]), 34, C_TEXT, true))
	v.add_child(lbl(tx(E["desc"]), 18, C_MUTED, true))
	var verdict := PanelContainer.new()
	verdict.add_theme_stylebox_override("panel", sb(C_OK if ev["prepared"] else C_RISK, 8, 10))
	verdict.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	verdict.add_child(lbl(t("ok") if ev["prepared"] else t("bad"), 18, Color.WHITE))
	v.add_child(verdict)
	if ev["warn"]:
		var wv := PanelContainer.new()
		wv.add_theme_stylebox_override("panel", sb(C_OK, 8, 10))
		wv.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		wv.add_child(lbl(t("warnOk"), 16, Color.WHITE))
		v.add_child(wv)
	v.add_child(rt(eff_bb(ev["dmg"], true), 18))
	if ev["later"].size() > 0:
		v.add_child(lbl(t("delayed").to_upper(), 14, C_GOLD))
		for p in ev["later"]:
			v.add_child(lbl(tx(p["msg"]), 16, C_TEXT, true))
			v.add_child(rt(eff_bb(p["eff"], true), 15))
	var b := btn(t("next"), true, 20)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.pressed.connect(_on_event_next)
	v.add_child(b)
	b.grab_focus()
	refresh_hud()


func show_end() -> void:
	phase = "end"
	cam_mode = "orbit"
	refresh_stations()
	refresh_hud()
	var avg := 0
	for k in D.KEYS:
		avg += stats[k]
	avg = int(round(avg / 4.0))
	var gr: Dictionary = D.GRADES[2]
	for g in D.GRADES:
		if avg >= int(g["min"]):
			gr = g
			break
	var weak: String = "w"
	for k in D.KEYS:
		if stats[k] < stats[weak]:
			weak = k
	var v := open_panel(900, 0.4, true)
	v.add_child(lbl("2050", 15, C_GOLD))
	v.add_child(lbl(gr[lang][0], 46, C_TEXT, true))
	v.add_child(lbl("%s: %d/100   ·   %s: %s" % [t("score"), avg, t("weakest"), t(weak)], 17, C_GOLD, true))
	v.add_child(lbl(gr[lang][1], 18, C_MUTED, true))
	var sline := ""
	for k in D.KEYS:
		sline += "[color=#%s]%s %d[/color]     " % [STAT_COL[k].to_html(false), t(k), stats[k]]
	v.add_child(rt(sline, 18))
	v.add_child(lbl(t("journey").to_upper(), 14, C_MUTED))
	var g1 := GridContainer.new()
	g1.columns = 3
	g1.add_theme_constant_override("h_separation", 16)
	v.add_child(g1)
	for r in log_list:
		g1.add_child(lbl(["2030", "2040", "2050"][r["round"]], 15, C_MUTED))
		var tl := lbl(tx(D.DEC[r["di"]]["title"]), 15, C_MUTED, true)
		tl.custom_minimum_size.x = 260
		g1.add_child(tl)
		var cl := lbl(tx(D.DEC[r["di"]]["opts"][r["oi"]]["label"]), 15, C_TEXT, true)
		cl.custom_minimum_size.x = 380
		g1.add_child(cl)
	v.add_child(lbl(t("events").to_upper(), 14, C_MUTED))
	var g2 := GridContainer.new()
	g2.columns = 3
	g2.add_theme_constant_override("h_separation", 16)
	v.add_child(g2)
	for e in evlog:
		g2.add_child(lbl(["2030", "2040", "2050"][e["round"]], 15, C_MUTED))
		g2.add_child(lbl(tx(D.EVENTS[e["id"]]["title"]), 15, C_TEXT))
		g2.add_child(lbl(t("ok") if e["prepared"] else t("bad"), 15, C_OK.lightened(0.3) if e["prepared"] else C_RISK))
	var vp := PanelContainer.new()
	vp.add_theme_stylebox_override("panel", sb(C_INK2, 12, 16, C_LINE))
	v.add_child(vp)
	var vv := VBoxContainer.new()
	vv.add_theme_constant_override("separation", 10)
	vp.add_child(vv)
	vv.add_child(lbl("COP31", 14, C_GOLD))
	vv.add_child(lbl(t("voteH"), 26, C_TEXT, true))
	vv.add_child(lbl(t("voteP"), 16, C_MUTED, true))
	var vg := GridContainer.new()
	vg.columns = 3 if get_viewport().get_visible_rect().size.x > 820 else 2
	vv.add_child(vg)
	for i in D.THEMES.size():
		var cb := CheckBox.new()
		cb.text = tx(D.THEMES[i])
		cb.button_pressed = i in votes
		cb.disabled = saved
		cb.add_theme_color_override("font_color", C_TEXT)
		cb.add_theme_color_override("font_hover_color", C_GOLD)
		cb.add_theme_color_override("font_pressed_color", C_GOLD)
		cb.toggled.connect(_on_vote.bind(i))
		vg.add_child(cb)
	if saved:
		vv.add_child(lbl(t("saved"), 15, C_MUTED, true))
		var mx := 1
		for x in tally:
			mx = max(mx, int(x))
		var order := range(D.THEMES.size())
		order.sort_custom(func(a, b): return tally[a] > tally[b])
		for i in order:
			var row := HBoxContainer.new()
			var nl := lbl(tx(D.THEMES[i]), 15, C_TEXT)
			nl.custom_minimum_size.x = 200
			row.add_child(nl)
			var pb := ProgressBar.new()
			pb.custom_minimum_size = Vector2(260, 12)
			pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pb.show_percentage = false
			pb.max_value = mx
			pb.value = tally[i]
			pb.add_theme_stylebox_override("background", sb(Color("#2A4038"), 6, 0))
			pb.add_theme_stylebox_override("fill", sb(STAT_COL["w"], 6, 0))
			row.add_child(pb)
			row.add_child(lbl("  " + str(tally[i]), 15, C_TEXT))
			vv.add_child(row)
	else:
		var sbtn := btn(t("save") if votes.size() == 3 else "%s (%d/3)" % [t("pick"), votes.size()], true, 18)
		sbtn.disabled = votes.size() != 3
		sbtn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		sbtn.pressed.connect(_on_save)
		vv.add_child(sbtn)
	var again := btn(t("again"), false, 18)
	again.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	again.pressed.connect(_on_again)
	v.add_child(again)
	v.add_child(lbl(t("footer"), 13, C_MUTED, true))


func toast(s: String) -> void:
	toast_lbl.text = s
	var tw := create_tween()
	toast_lbl.modulate.a = 1.0
	tw.tween_interval(3.0)
	tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.8)


# =====================================================================
#  OLAYLAR (mantık + görsel)
# =====================================================================
func pick_event() -> String:
	var pool: Array = D.POOLS[round_i]
	var ws := []
	var tot := 0.0
	for id in pool:
		var E: Dictionary = D.EVENTS[id]
		var prot := false
		for tg in E["tags"]:
			if has_tag(tg):
				prot = true
		var w := 1.0 + (0.0 if prot else 3.0)
		if id == "fire" and "fireRisk" in flags:
			w += 3.0
		ws.append(w)
		tot += w
	var r := randf() * tot
	for i in pool.size():
		r -= ws[i]
		if r <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]


func start_event() -> void:
	clear_overlay()
	phase = "event_anim"
	prompt_btn.visible = false
	arrow.visible = false
	cam_mode = "overview"
	refresh_hud()
	var id := pick_event()
	var E: Dictionary = D.EVENTS[id]
	var prepared := false
	for tg in E["tags"]:
		if has_tag(tg):
			prepared = true
	var base: Dictionary = E["prot"] if prepared else E["dmg"]
	var warn := has_tag("warn")
	var dmg := {}
	for k in D.KEYS:
		if base.has(k):
			dmg[k] = int(round(base[k] / 2.0)) if warn else int(base[k])
	var later := []
	var keep := []
	for p in pending:
		if p["due"] == round_i:
			later.append(p)
		else:
			keep.append(p)
	pending = keep
	ev = {"id": id, "prepared": prepared, "warn": warn, "dmg": dmg, "later": later}
	evlog.append({"round": round_i, "id": id, "prepared": prepared})
	toast(tx(E["title"]))
	await play_event_fx(id, prepared)
	apply_eff(dmg)
	for p in later:
		apply_eff(p["eff"])
	refresh_world()
	show_event_panel()


func make_particles(pos: Vector3, c: Color, amount: int, size: float, vel: float, ext: Vector3, life := 1.2, alpha := 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = ext
	p.direction = Vector3.UP
	p.spread = 18
	p.initial_velocity_min = vel * 0.6
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.radial_segments = 8
	m.rings = 4
	m.material = mat(c, 0.8, true, alpha)
	p.mesh = m
	p.position = pos
	fx.add_child(p)
	return p


func play_event_fx(id: String, prepared: bool) -> void:
	var tw := create_tween().set_parallel(true)
	match id:
		"fire":
			var spots := [Vector3(-20, 0, -20), Vector3(-8, 0, -22), Vector3(4, 0, -19), Vector3(16, 0, -23), Vector3(26, 0, -20)]
			var n := 2 if prepared else 5
			for i in n:
				make_particles(spots[i] + Vector3(0, 0.5, 0), Color("#FF8A1F"), 40, 0.45, 3.5, Vector3(2.2, 0.3, 2.2), 1.0)
				make_particles(spots[i] + Vector3(0, 0.8, 0), Color("#FFD23F"), 24, 0.3, 2.5, Vector3(1.6, 0.3, 1.6), 0.8)
				make_particles(spots[i] + Vector3(0, 3, 0), Color("#5A5A5A"), 20, 1.1, 3.0, Vector3(2.5, 0.5, 2.5), 2.6, 0.45)
			tw.tween_property(sun, "light_color", Color("#FF9A5A"), 1.5)
		"heat":
			tw.tween_property(sky_mat, "sky_top_color", Color("#C8642E"), 1.6)
			tw.tween_property(sky_mat, "sky_horizon_color", Color("#F0B983"), 1.6)
			tw.tween_property(sun, "light_color", Color("#FFB27A"), 1.6)
			tw.tween_property(sun, "light_energy", 1.1, 1.6)
		"drought":
			tw.tween_property(ground_mat, "albedo_color", Color("#C2A06A"), 1.8)
			tw.tween_property(reservoir_water, "scale:y", 0.25 if not prepared else 0.8, 1.8)
			tw.tween_property(sky_mat, "sky_horizon_color", Color("#EAD3A6"), 1.8)
		"flood":
			flood_plane.visible = true
			flood_plane.position.y = -0.4
			tw.tween_property(flood_plane, "position:y", 0.12 if prepared else 0.75, 2.2)
			tw.tween_property(sky_mat, "sky_top_color", Color("#4B5A66"), 1.5)
			tw.tween_property(sky_mat, "sky_horizon_color", Color("#8E9AA3"), 1.5)
			tw.tween_property(sun, "light_energy", 0.5, 1.5)
		"marine":
			tw.tween_property(sea_mat, "albedo_color", Color("#7CC4BF"), 1.8)
			if not prepared:
				for c in seagrass.get_children():
					c.material_override = mat(Color("#B9A98A"))
	await get_tree().create_timer(4.0).timeout


func clear_event_fx() -> void:
	for c in fx.get_children():
		c.queue_free()
	flood_plane.visible = false
	sun.light_energy = 1.0
	refresh_world()


# =====================================================================
#  GİRDİ VE DÖNGÜ
# =====================================================================
func _on_start() -> void:
	reset_state()
	for c in visuals.get_children():
		c.queue_free()
	for c in seagrass.get_children():
		c.queue_free()
	seagrass.visible = false
	siren_light = null
	for r in roofs:
		r.material_override = mat(Color("#B4553C")) if r.get_parent().position.y < 4.0 or r.get_parent().position.x < 15.0 else mat(Color("#C9C2B0"))
	(get_node("Mound") as Node3D).scale = Vector3(1.3, 0.5, 1.0)
	player.position = Vector3(0, 0.1, 8)
	clear_overlay()
	phase = "play"
	cam_mode = "follow"
	refresh_world()
	refresh_stations()
	refresh_hud()
	toast(t("follow"))


func _on_lang() -> void:
	lang = "en" if lang == "tr" else "tr"
	refresh_stations()
	refresh_hud()
	match phase:
		"intro": show_intro()
		"decide": open_decision(cur_di)
		"feedback": show_feedback(cur_di, choices[cur_di])
		"event": show_event_panel()
		"end": show_end()


var cur_di := -1


func _on_prompt() -> void:
	if phase == "play" and near_di >= 0:
		cur_di = near_di
		open_decision(near_di)


func _on_back() -> void:
	clear_overlay()
	phase = "play"
	refresh_hud()


func _on_choose(di: int, oi: int) -> void:
	var o: Dictionary = D.DEC[di]["opts"][oi]
	var c := cost_of(o)
	if c > budget:
		return
	budget -= c
	last_paid = c
	apply_eff(o["eff"])
	for tg in o.get("tags", []):
		if not has_tag(tg):
			tags.append(tg)
	for f in o.get("flags", []):
		if not f in flags:
			flags.append(f)
	if o.has("later"):
		pending.append({"due": round_i + int(o["later"]["due"]), "eff": o["later"]["eff"], "msg": o["later"]["msg"]})
	log_list.append({"round": round_i, "di": di, "oi": oi})
	done[di] = true
	choices[di] = oi
	cur_di = di
	spawn_visual(di, oi)
	refresh_world()
	refresh_stations()
	show_feedback(di, oi)


func _on_feedback_next(round_done: bool) -> void:
	if round_done:
		start_event()
	else:
		clear_overlay()
		phase = "play"
		refresh_hud()


func _on_event_next() -> void:
	clear_overlay()
	clear_event_fx()
	if round_i < 2:
		round_i += 1
		budget += 10
		phase = "play"
		cam_mode = "follow"
		refresh_stations()
		refresh_hud()
		toast(t("period")[round_i])
	else:
		show_end()


func _on_vote(on: bool, i: int) -> void:
	if on and not i in votes:
		if votes.size() >= 3:
			show_end()
			return
		votes.append(i)
	elif not on and i in votes:
		votes.erase(i)
	show_end()


func _on_save() -> void:
	tally = load_tally()
	for i in votes:
		tally[i] = int(tally[i]) + 1
	var f := FileAccess.open("user://antalya2050_votes.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(tally))
		f.close()
	saved = true
	show_end()


func load_tally() -> Array:
	var out := []
	for i in D.THEMES.size():
		out.append(0)
	if FileAccess.file_exists("user://antalya2050_votes.json"):
		var f := FileAccess.open("user://antalya2050_votes.json", FileAccess.READ)
		if f:
			var data = JSON.parse_string(f.get_as_text())
			if typeof(data) == TYPE_ARRAY and data.size() == out.size():
				for i in out.size():
					out[i] = int(data[i])
	return out


func _on_again() -> void:
	_on_start()


func _unhandled_input(event: InputEvent) -> void:
	if phase != "play":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
			_on_prompt()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var from := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
		if hit != null:
			go_to(Vector3(clampf(hit.x, -32, 32), 0, clampf(hit.z, -16, 16)))
			target_marker.position = click_target + Vector3(0, 0.08, 0)
			target_marker.visible = true


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x), floori(p.z))


func free_cell_near(c: Vector2i) -> Vector2i:
	if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
		return c
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var n := c + Vector2i(dx, dz)
				if astar.is_in_boundsv(n) and not astar.is_point_solid(n):
					return n
	return c


func go_to(target: Vector3) -> void:
	var from := free_cell_near(cell_of(player.position))
	var to := free_cell_near(cell_of(target))
	var target_free := to == cell_of(target)
	click_target = target if target_free else Vector3(to.x + 0.5, 0, to.y + 0.5)
	path_pts = []
	var ids := astar.get_id_path(from, to)
	for i in range(1, ids.size()):
		path_pts.append(Vector3(ids[i].x + 0.5, 0, ids[i].y + 0.5))
	if path_pts.size() > 0:
		path_pts[path_pts.size() - 1] = click_target
	else:
		path_pts = [click_target]


func nearest_open() -> int:
	var best := -1
	var bd := 1e9
	for i in range(round_i * 3, round_i * 3 + 3):
		if done[i]:
			continue
		var p: Vector2 = D.DEC[i]["pos"]
		var dd := Vector2(player.position.x, player.position.z).distance_to(p)
		if dd < bd:
			bd = dd
			best = i
	return best


func _physics_process(delta: float) -> void:
	if phase != "play":
		player.velocity = Vector3.ZERO
		return
	var dir := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		dir.z -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		dir.z += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir != Vector3.ZERO:
		click_target = null
		target_marker.visible = false
	elif click_target != null:
		if path_pts.is_empty():
			path_pts = [click_target]
		var wp: Vector3 = path_pts[0]
		var to: Vector3 = wp - player.position
		to.y = 0
		if to.length() < 0.4:
			path_pts.pop_front()
			if path_pts.is_empty():
				click_target = null
				target_marker.visible = false
		else:
			dir = to
	dir = dir.normalized()
	player.velocity.x = dir.x * 7.5
	player.velocity.z = dir.z * 7.5
	player.velocity.y = player.velocity.y - 25.0 * delta if not player.is_on_floor() else -0.5
	player.move_and_slide()
	if dir.length() > 0.1:
		var target_rot := atan2(dir.x, dir.z) + PI
		player_vis.rotation.y = lerp_angle(player_vis.rotation.y, target_rot, 12.0 * delta)
		player_vis.position.y = abs(sin(t_clock * 12.0)) * 0.08
	else:
		player_vis.position.y = 0.0


func _process(delta: float) -> void:
	t_clock += delta
	# İstasyon animasyonu
	for s in stations:
		if s["node"].visible:
			s["ring"].rotation.y += delta * 1.2
			s["ring"].position.y = 0.15 + sin(t_clock * 3.0) * 0.08
	if siren_light:
		siren_light.visible = fmod(t_clock, 1.0) < 0.5
	if target_marker.visible:
		target_marker.rotation.y += delta * 2.0
	# Yakın istasyon ve ok
	if phase == "play":
		near_di = -1
		var no := nearest_open()
		if no >= 0:
			var p: Vector2 = D.DEC[no]["pos"]
			var dd := Vector2(player.position.x, player.position.z).distance_to(p)
			if dd < 2.4:
				near_di = no
			arrow.visible = dd >= 2.4
			var head := player.position + Vector3(0, 2.7, 0)
			arrow.position = head
			var flat := Vector3(p.x, head.y, p.y) - head
			if flat.length() > 0.1:
				arrow.look_at(head + flat.normalized(), Vector3.UP)
				arrow.rotate_object_local(Vector3.RIGHT, -PI / 2.0)
		else:
			arrow.visible = false
		if near_di >= 0:
			prompt_btn.text = "E  ·  %s: %s" % [t("prompt"), tx(D.DEC[near_di]["place"])]
			prompt_btn.visible = true
		else:
			prompt_btn.visible = false
	else:
		arrow.visible = false
	# Kamera
	var want_pos: Vector3
	var look: Vector3
	match cam_mode:
		"orbit":
			var a := t_clock * 0.08
			want_pos = Vector3(sin(a) * 42.0, 26.0, cos(a) * 42.0 + 4.0)
			look = Vector3(0, 0, -4)
		"overview":
			want_pos = Vector3(0, 34, 30)
			look = Vector3(0, 0, -6)
		_:
			want_pos = player.position + Vector3(0, 17.0, 15.5)
			look = player.position + Vector3(0, 1.0, 0)
	cam.position = cam.position.lerp(want_pos, clampf(delta * 3.0, 0, 1))
	cam.look_at(look, Vector3.UP)
	if autoplay:
		run_autoplay(delta)


# Otomatik oynatma: test ve tanıtım videosu için (?autoplay veya --autoplay)
var _dbg_t := 0.0
func run_autoplay(delta: float) -> void:
	auto_t += delta
	_dbg_t += delta
	if _dbg_t > 3.0 and OS.has_environment("A2050_DEBUG"):
		_dbg_t = 0
		print("DBG phase=", phase, " round=", round_i, " pos=", player.position, " near=", near_di, " open=", nearest_open(), " budget=", budget, " done=", done)
	match phase:
		"intro":
			if auto_t > 2.0:
				auto_t = 0
				_on_start()
		"play":
			var no := nearest_open()
			if no >= 0:
				var p: Vector2 = D.DEC[no]["pos"]
				if click_target == null and near_di < 0:
					go_to(Vector3(p.x, 0, p.y))
				if near_di >= 0 and auto_t > 0.6:
					auto_t = 0
					_on_prompt()
		"decide":
			if auto_t > 2.5:
				auto_t = 0
				var opts: Array = D.DEC[cur_di]["opts"]
				var pick := -1
				var cands := []
				for i in opts.size():
					if cost_of(opts[i]) <= budget:
						cands.append(i)
				pick = cands[randi() % cands.size()] if cands.size() > 0 else 2
				_on_choose(cur_di, pick)
		"feedback":
			if auto_t > 2.5:
				auto_t = 0
				var rd := true
				for i in range(round_i * 3, round_i * 3 + 3):
					if not done[i]:
						rd = false
				_on_feedback_next(rd)
		"event":
			if auto_t > 3.0:
				auto_t = 0
				_on_event_next()
		"end":
			if auto_t > 2.0 and not saved:
				auto_t = 0
				for i in [0, 3, 8]:
					if not i in votes:
						votes.append(i)
				_on_save()
				print("AUTOPLAY_END ", stats, " budget=", budget, " tags=", tags, " events=", evlog)
				if "--autoplay" in OS.get_cmdline_user_args() and not OS.has_feature("web"):
					get_tree().quit()
		_:
			auto_t = 0
