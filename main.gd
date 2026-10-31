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
const STAT_COL := {"w": Color("#4FB6D6"), "h": Color("#F07A5F"), "e": Color("#E8B53A"), "n": Color("#6BC48A"), "r": Color("#C79BEA")}
const C_XP := Color("#9FD8F0")

# ---------- oyun durumu ----------
var lang := "tr"
var phase := "intro"   # intro, play, decide, feedback, event_anim, event, end
var round_i := 0
var stats := {}
var budget := 10
var xp := 0
var techs: Array = []
var turbines: Array = []
var shown_budget := 10
var shown_xp := 4
var coins_flying := 0
var coin_layer: Control
var sfx := {}
var coin_tick := 0
var music := {}
var music_now := ""
const MUSIC := {"main": "res://music/ana_tema.mp3", "event": "res://music/olay.mp3", "final": "res://music/final.mp3"}
const MUSIC_DB := -9.0
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
var income_lbl: Label
var xp_lbl: Label
var tech_btn: Button
var period_lbl: Label
var title_lbl: Label
var year_chips: Array = []
var lang_btn: Button
var menu_btn: Button
var prev_phase := ""
var confirm_restart := false
var muted := false
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
	if "--menutest" in args:
		call_deferred("_menutest")
	reset_state()
	build_world()
	build_ui()
	refresh_world()
	show_intro()
	play_music("main")


# Test: menü akışını dener (--menutest)
func _menutest() -> void:
	_on_start()
	open_menu()
	assert(phase == "menu")
	show_menu(true)
	show_menu()
	_on_menu_restart()
	assert(confirm_restart)
	_on_menu_restart()
	assert(phase == "play")
	near_di = 0
	cur_di = 0
	open_decision(0)
	open_menu()
	_on_lang()
	resume_game()
	assert(phase == "decide")
	_on_choose(0, 0)
	open_menu()
	resume_game()
	assert(phase == "feedback")
	_on_feedback_next(false)
	open_menu()
	_on_menu_sound()
	_on_menu_main()
	assert(phase == "intro")
	print("MENUTEST OK phase=", phase, " xp=", xp, " budget=", budget)


# Test: tüm kararları hızlıca verip sonuç ekranını açar (?endtest)
func _endtest() -> void:
	_on_start()
	for r in D.POOLS.size():
		round_i = r
		for di in range(r * 3, r * 3 + 3):
			var opts: Array = D.DEC[di]["opts"]
			var pick := 2
			for i in opts.size():
				if option_cost(di, i) <= budget:
					pick = i
					break
			_on_choose(di, pick)
		phase = "play"
		while any_buyable():
			for td in D.TECH:
				if can_buy(td):
					buy_tech(td["id"])
					break
		phase = "play"
		var id: String = D.POOLS[r][0]
		evlog.append({"round": r, "id": id, "prepared": r != 1})
		xp += 3
		if r < D.POOLS.size() - 1:
			budget += income()
	clear_overlay()
	votes = [0, 3, 8]
	_on_save()
	print("ENDTEST ", stats, " techs=", techs, " xp=", xp, " income=", income())


func reset_state() -> void:
	phase = "intro"
	round_i = 0
	stats = {"w": 50, "h": 60, "e": 60, "n": 55, "r": 55}
	budget = 10
	xp = 4
	techs = []
	shown_budget = budget
	shown_xp = xp
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
	for td in D.TECH:
		if td["id"] in techs and td.has("cheap"):
			for tg in o.get("tags", []):
				if tg in td["cheap"]:
					c = max(0, c - 1)
					break
	return c


# Bütçe hiçbir seçeneğe yetmiyorsa en ucuz seçenek eldeki bütçeyle yapılabilir (oyun kilitlenmez)
func option_cost(di: int, oi: int) -> int:
	var opts: Array = D.DEC[di]["opts"]
	var c := cost_of(opts[oi])
	var m := 999
	var mi := -1
	for i in opts.size():
		var ci := cost_of(opts[i])
		if ci < m:
			m = ci
			mi = i
	if m > budget and oi == mi:
		return budget
	return c


func is_emergency(di: int) -> bool:
	for o in D.DEC[di]["opts"]:
		if cost_of(o) <= budget:
			return false
	return true


func has_tech(id: String) -> bool:
	return id in techs


func tech_def(id: String) -> Dictionary:
	for td in D.TECH:
		if td["id"] == id:
			return td
	return {}


func income() -> int:
	var inc := 6
	for di in choices:
		inc += int(D.DEC[di]["opts"][choices[di]].get("inc", 0))
	for id in techs:
		inc += int(tech_def(id).get("inc", 0))
	return inc


func xp_for(o: Dictionary) -> int:
	var g := 2
	if o.get("tags", []).size() > 0:
		g += 2
	if o.get("risk", false):
		g -= 1
	return g


func can_buy(td: Dictionary) -> bool:
	return not has_tech(td["id"]) and (td["req"] == "" or has_tech(td["req"])) and xp >= int(td["cost"])


func any_buyable() -> bool:
	for td in D.TECH:
		if can_buy(td):
			return true
	return false


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
		cyl(0.36, 0.46, 0.9, Vector3(0, 0.45, -1.15), Color("#2A4038"), n, 12)
		cyl(0.42, 0.42, 0.06, Vector3(0, 0.92, -1.15), C_GOLD, n, 16)
		var cap := cyl(0.3, 0.3, 0.18, Vector3(0, 1.02, -1.15), Color("#E0453A"), n, 16, mat(Color("#E0453A"), 0.35, false, 1.0, 0.9))
		n.visible = false
		stations.append({"node": n, "ring": ring, "label": lb, "cap": cap})

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
	match String(D.DEC[di]["id"]):
		"water":
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
		"heat":
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
		"fire":
			if oi == 0:
				for x in [-22.0, 2.0, 22.0]:
					box(Vector3(3, 0.06, 14), Vector3(x, 0.04, -21), Color("#A9875B"), v)
			elif oi == 1:
				for p in [Vector3(-14, 0, -15), Vector3(12, 0, -15)]:
					box(Vector3(0.35, 6, 0.35), p + Vector3(0, 3, 0), Color("#6B4E2E"), v)
					box(Vector3(1.6, 0.9, 1.6), p + Vector3(0, 6.3, 0), Color("#C2412A"), v)
		"flood":
			if oi == 0:
				for x in [-22.0, -14.0, -6.0, 6.0, 14.0, 22.0, 28.0]:
					box(Vector3(5, 0.1, 1.2), Vector3(x, 0.06, 14.3), Color("#5FA05A"), v)
					tree(Vector3(x + 1.5, 0, 14.3), 0.5, v, true)
			elif oi == 1:
				box(Vector3(64, 0.9, 0.5), Vector3(0, 0.45, 14.9), Color("#9A9A94"), v)
		"food":
			if oi == 0:
				for gz in [-8.5, -4.5, -0.5]:
					box(Vector3(5.2, 0.08, 0.15), Vector3(26, 2.3, gz), Color("#2E8FB5"), v)
					cyl(0.06, 0.06, 0.8, Vector3(23.3, 0.4, gz + 1.2), Color("#2E8FB5"), v)
			elif oi == 1:
				box(Vector3(3, 2, 3), Vector3(29.5, 1, 4), Color("#F1EDE4"), v)
				box(Vector3(3.2, 0.25, 3.2), Vector3(29.5, 2.1, 4), Color("#5FA05A"), v)
			else:
				box(Vector3(8, 0.05, 12), Vector3(26, 0.03, -4.5), Color("#3E88B0"), v, false, mat(Color("#3E88B0"), 0.1, false, 0.6))
		"energy":
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
		"sea":
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
		"waste":
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
		"warn":
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
		"transit":
			if oi == 0:
				box(Vector3(64, 0.08, 0.15), Vector3(0, 0.08, 12.1), Color("#8A8F8C"), v)
				box(Vector3(64, 0.08, 0.15), Vector3(0, 0.08, 13.1), Color("#8A8F8C"), v)
				box(Vector3(6, 1.6, 1.4), Vector3(-6, 0.9, 12.6), Color("#3E9A62"), v)
				box(Vector3(6.05, 0.5, 1.45), Vector3(-6, 1.2, 12.6), Color("#F2F4EF"), v)
				box(Vector3(64, 0.07, 0.8), Vector3(0, 0.07, 11.0), Color("#5FA05A"), v)
			elif oi == 1:
				for x in [-14.0, 2.0, 18.0]:
					box(Vector3(4, 1.6, 1.4), Vector3(x, 0.9, 12.6), Color("#127A99"), v)
					box(Vector3(4.05, 0.4, 1.45), Vector3(x, 1.3, 12.6), Color("#F2F4EF"), v)
			else:
				box(Vector3(64, 0.07, 3.0), Vector3(0, 0.05, -15.0), Color("#3A3E3C"), v)
				for x in [-20.0, -6.0, 9.0, 22.0]:
					box(Vector3(1.8, 0.8, 1.0), Vector3(x, 0.45, -15.4), Color("#B4553C"), v)
		"market":
			if oi == 0:
				for q in 5:
					var c2: Color = [C_GOLD, C_OK, Color("#C79BEA"), C_RISK, C_SEA][q]
					box(Vector3(1.4, 0.9, 1.0), Vector3(9.5 + q * 1.5, 0.45, 4.6), Color("#C9A36A"), v)
					cyl(0.0, 0.95, 0.7, Vector3(9.5 + q * 1.5, 1.25, 4.6), c2, v, 4)
			elif oi == 1:
				for q in 3:
					box(Vector3(0.1, 1.6, 0.1), Vector3(10 + q * 2.5, 0.8, 4.5), Color("#8A6A45"), v)
					box(Vector3(1.6, 1.0, 0.08), Vector3(10 + q * 2.5, 1.9, 4.5), C_OK, v)
			else:
				box(Vector3(6, 3.4, 3.2), Vector3(12.5, 1.7, -0.6), Color("#C8CCD0"), v)
				box(Vector3(6.1, 0.6, 3.3), Vector3(12.5, 3.1, -0.6), Color("#C2412A"), v)
		"agrivolt":
			if oi == 0:
				for q in 4:
					var pn2 := box(Vector3(2.4, 0.08, 1.4), Vector3(19 + q * 2.7, 0.7, 3.2), Color("#24456B"), v, false, mat(Color("#24456B"), 0.2))
					pn2.rotation_degrees.x = -20
			elif oi == 1:
				for q in 6:
					var px := 19.0 + (q % 3) * 2.2
					var pz := -15.0 + int(q / 3) * 2.4
					tree(Vector3(px, 0, pz), 0.55, v, true)
					sphere(0.12, Vector3(px + 0.3, 0.9, pz + 0.3), Color("#F08A1F"), v)
					var pn3 := box(Vector3(1.8, 0.06, 1.2), Vector3(px, 2.2, pz), Color("#24456B"), v, false, mat(Color("#24456B"), 0.2))
					pn3.rotation_degrees.x = -15
			else:
				box(Vector3(4, 3, 3), Vector3(28, 1.5, -14.5), Color("#9AA3A6"), v)
				for q in 2:
					cyl(0.4, 0.5, 7, Vector3(26.8 + q * 1.4, 3.5, -15.3), Color("#7A7F80"), v)
					sphere(0.9, Vector3(26.8 + q * 1.4, 7.6, -15.3), Color("#8F9496"), v, mat(Color("#8F9496"), 0.9, false, 0.6))
		"care":
			if oi == 0:
				box(Vector3(2.4, 1.6, 1.6), Vector3(-13.2, 0.8, -4.6), Color("#F1EDE4"), v)
				box(Vector3(2.5, 0.2, 1.7), Vector3(-13.2, 1.7, -4.6), C_OK, v)
			elif oi == 1:
				for q in 4:
					box(Vector3(0.12, 1.8, 0.12), Vector3(-7 + (q % 2) * 2, 0.9, -3.8 + int(q / 2) * 1.6), Color("#8A6A45"), v)
				box(Vector3(2.6, 0.1, 2.2), Vector3(-6, 1.85, -3.0), Color("#F7F7F2"), v)
		"watershed":
			if oi == 0:
				for q in 12:
					tree(Vector3(-20 + (q % 6) * 1.6, 0, -14.6 + int(q / 6) * 1.1), 0.45, v)
				for q in 3:
					box(Vector3(10, 0.12, 0.35), Vector3(-16, 0.06, -12.9 - q * 0.9), Color("#9A7B52"), v)
			elif oi == 1:
				box(Vector3(9, 2.6, 0.8), Vector3(-19, 1.3, -15.6), Color("#B9B3A3"), v)
				box(Vector3(9, 0.1, 3), Vector3(-19, 1.9, -17.4), Color("#2E8FB5"), v)
			else:
				box(Vector3(7, 0.12, 4), Vector3(-12, 0.07, -15.0), Color("#8C8578"), v)
				box(Vector3(0.3, 4, 0.3), Vector3(-10, 2, -15.5), C_GOLD, v)
				box(Vector3(3, 0.3, 0.3), Vector3(-11.2, 3.9, -15.5), C_GOLD, v)
		"plan":
			if oi == 0:
				box(Vector3(5, 2.6, 3), Vector3(12.0, 1.3, -12.6), Color("#F1EDE4"), v)
				box(Vector3(3.2, 1.6, 0.1), Vector3(12.0, 1.6, -11.05), Color("#127A99"), v, false, mat(Color("#127A99"), 0.3, true))
				var pl := label3d("2050", Vector3(12.0, 1.6, -10.95), v, 60)
				pl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			elif oi == 1:
				for q in 3:
					var rr := cyl(2.4 - q * 0.6, 2.4 - q * 0.6, 0.3, Vector3(12.0, 0.15 + q * 0.3, -12.6), Color("#D9D2C1"), v, 24)
					rr.name = "seat%d" % q
				for q in 3:
					box(Vector3(0.08, 2.4, 0.08), Vector3(10.5 + q * 1.5, 1.2, -14.8), Color("#8A6A45"), v)
					box(Vector3(0.7, 0.45, 0.04), Vector3(10.85 + q * 1.5, 2.1, -14.8), [C_SEA, C_GOLD, C_OK][q], v)


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
	income_lbl = lbl("", 14, C_MUTED)
	v.add_child(income_lbl)
	xp_lbl = lbl("", 17, C_XP)
	v.add_child(xp_lbl)

	# Sağ üst: yıllar ve dil
	var tr_box := HBoxContainer.new()
	tr_box.add_theme_constant_override("separation", 6)
	pin(tr_box, 1, 0, -16, 16, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	hud.add_child(tr_box)
	for y in D.YEARS:
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

	tech_btn = btn("", false, 17)
	tech_btn.pressed.connect(open_tech)
	pin(tech_btn, 1, 1, -16, -16, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_BEGIN)
	hud.add_child(tech_btn)

	toast_lbl = lbl("", 20, C_TEXT)
	toast_lbl.add_theme_constant_override("outline_size", 8)
	toast_lbl.add_theme_color_override("font_outline_color", C_INK)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin(toast_lbl, 0.5, 0, 0, 24, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	ui.add_child(toast_lbl)

	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(overlay)
	menu_btn = btn("", false, 15)
	menu_btn.pressed.connect(open_menu)
	ui.add_child(menu_btn)
	pin(menu_btn, 1, 0, -16, 108, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	ui.move_child(lang_btn, ui.get_child_count() - 1)
	coin_layer = Control.new()
	coin_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	coin_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(coin_layer)
	for k in ["press", "stamp", "coin"]:
		var ap := AudioStreamPlayer.new()
		ap.stream = make_sfx(k)
		ap.max_polyphony = 6
		ap.volume_db = -6.0 if k != "coin" else -10.0
		add_child(ap)
		sfx[k] = ap
	for mk in MUSIC:
		var st = load(MUSIC[mk])
		if st is AudioStreamMP3:
			st.loop = mk != "event"
			var mp := AudioStreamPlayer.new()
			mp.stream = st
			mp.volume_db = -60.0
			add_child(mp)
			music[mk] = mp
	refresh_hud()


func refresh_hud() -> void:
	for k in D.KEYS:
		stat_names[k].text = t(k)
		stat_bars[k].value = stats[k]
		stat_vals[k].text = str(stats[k])
		stat_vals[k].add_theme_color_override("font_color", C_RISK if stats[k] < 25 else C_TEXT)
	if coins_flying == 0:
		shown_budget = budget
		shown_xp = xp
	else:
		shown_budget = mini(shown_budget, budget)
		shown_xp = mini(shown_xp, xp)
	budget_lbl.text = "%s: %d %s" % [t("budget"), shown_budget, t("unit")]
	income_lbl.text = "%s: +%d %s %s" % [t("income"), income(), t("unit"), t("perDecade")]
	xp_lbl.text = "%s: %d" % [t("xp"), shown_xp]
	tech_btn.text = "%s   (%d XP)" % [t("techBtn"), shown_xp]
	tech_btn.add_theme_stylebox_override("normal", sb(Color("#1F5A72") if any_buyable() else C_INK2, 10, 12, C_XP if any_buyable() else C_LINE))
	tech_btn.visible = phase in ["play", "tech"]
	period_lbl.text = t("period")[round_i] if phase != "end" else "2050"
	for i in year_chips.size():
		var col := C_INK2
		if phase == "end" or i < round_i:
			col = C_OK
		elif i == round_i and phase != "intro":
			col = C_SEA
		year_chips[i].add_theme_stylebox_override("panel", sb(col, 8, 6))
	lang_btn.text = t("lang")
	if menu_btn:
		menu_btn.text = "%s  (Esc)" % t("menu")
		menu_btn.visible = phase in ["play", "decide", "feedback", "event", "tech"]
	controls_lbl.text = t("controls")
	var s := "[color=#%s]%s[/color]\n" % [C_GOLD.to_html(false), t("tasks")]
	for i in range(round_i * 3, round_i * 3 + 3):
		var d: Dictionary = D.DEC[i]
		if done[i]:
			s += "[color=#%s]  • %s: %s (%s)[/color]\n" % [C_MUTED.to_html(false), tx(d["place"]), tx(d["title"]), t("done")]
		else:
			s += "  • [b]%s[/b]: %s\n" % [tx(d["place"]), tx(d["title"])]
	tasks_rt.text = s.strip_edges()
	hud.visible = phase in ["play", "pressing", "decide", "feedback", "event_anim", "event", "tech"]


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
	if is_emergency(di):
		v.add_child(lbl(t("emergency"), 16, C_GOLD, true))
	var vp := get_viewport().get_visible_rect().size
	var grid := GridContainer.new()
	grid.columns = 3 if vp.x > 820 else 1
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	v.add_child(grid)
	var first_btn: Button = null
	for oi in d["opts"].size():
		var o: Dictionary = d["opts"][oi]
		var c := option_cost(di, oi)
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
		if o.has("inc"):
			extra.append("[color=#%s]%s +%d %s[/color]" % [C_GOLD.to_html(false), t("income"), o["inc"], t("perDecade")])
		extra.append("[color=#%s]+%d %s[/color]" % [C_XP.to_html(false), xp_for(o), t("xpGain")])
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
	var top := HBoxContainer.new()
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(lbl(t("yourChoice").to_upper(), 15, C_GOLD))
	tv.add_child(lbl(tx(o["label"]), 30, C_TEXT, true))
	top.add_child(tv)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(230, 80)
	top.add_child(holder)
	v.add_child(top)
	var stamp := PanelContainer.new()
	var ss := sb(Color(0, 0, 0, 0), 8, 10, C_RISK)
	ss.set_border_width_all(4)
	stamp.add_theme_stylebox_override("panel", ss)
	var sl := lbl(t("approved"), 30, C_RISK)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stamp.add_child(sl)
	stamp.custom_minimum_size = Vector2(220, 64)
	stamp.position = Vector2(5, 8)
	stamp.pivot_offset = Vector2(110, 32)
	stamp.rotation_degrees = -9.0
	stamp.scale = Vector2(2.4, 2.4)
	stamp.modulate.a = 0.0
	holder.add_child(stamp)
	var stw := create_tween()
	stw.tween_interval(0.15)
	stw.tween_property(stamp, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stw.parallel().tween_property(stamp, "modulate:a", 1.0, 0.12)
	stw.tween_callback(play_sfx.bind("stamp"))
	v.add_child(rt(eff_bb(o["eff"], true) + "   [color=#%s]%s -%d[/color]   [color=#%s]+%d %s[/color]" % [C_GOLD.to_html(false), t("budget"), last_paid, C_XP.to_html(false), xp_for(o), t("xpGain")], 17))
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
	if ev["tech"]:
		v.add_child(lbl(t("dmgLess"), 16, C_XP, true))
	if ev["fair"]:
		v.add_child(lbl(t("fairOk"), 16, STAT_COL["r"], true))
	v.add_child(rt(eff_bb(ev["dmg"], true) + "   [color=#%s]+%d %s[/color]" % [C_XP.to_html(false), ev["xp"], t("xpGain")], 18))
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
	play_music("final")
	cam_mode = "orbit"
	refresh_stations()
	refresh_hud()
	var avg := 0
	for k in D.KEYS:
		avg += stats[k]
	avg = int(round(avg / float(D.KEYS.size())))
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
	v.add_child(lbl(t("techs").to_upper(), 14, C_MUTED))
	var tn := []
	for id in techs:
		tn.append(tx(tech_def(id)["name"]))
	v.add_child(lbl(", ".join(tn) if tn.size() > 0 else t("noTech"), 16, C_XP, true))
	v.add_child(lbl(t("journey").to_upper(), 14, C_MUTED))
	var g1 := GridContainer.new()
	g1.columns = 3
	g1.add_theme_constant_override("h_separation", 16)
	v.add_child(g1)
	for r in log_list:
		g1.add_child(lbl(D.YEARS[r["round"]], 15, C_MUTED))
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
		g2.add_child(lbl(D.YEARS[e["round"]], 15, C_MUTED))
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
	var mult := 1.0
	for id2 in techs:
		var md: Dictionary = tech_def(id2).get("mult", {})
		if md.has(id):
			mult *= float(md[id])
	if warn:
		mult *= 0.5
	var fair := has_tech("fair")
	var dmg := {}
	for k in D.KEYS:
		if base.has(k):
			var m2 := mult * (0.5 if (k == "r" and fair) else 1.0)
			dmg[k] = int(round(float(base[k]) * m2))
	var gain := 3 if prepared else 1
	var later := []
	var keep := []
	for p in pending:
		if p["due"] == round_i:
			later.append(p)
		else:
			keep.append(p)
	pending = keep
	ev = {"id": id, "prepared": prepared, "warn": warn, "dmg": dmg, "later": later, "tech": mult < (0.5 if warn else 1.0) - 0.001, "fair": fair and base.has("r"), "xp": gain}
	xp += gain
	evlog.append({"round": round_i, "id": id, "prepared": prepared})
	toast(tx(E["title"]))
	play_music("event")
	await play_event_fx(id, prepared)
	apply_eff(dmg)
	for p in later:
		apply_eff(p["eff"])
	refresh_world()
	fly(gain, "xp", get_viewport().get_visible_rect().size / 2.0)
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
#  SES VE ANİMASYON YARDIMCILARI
# =====================================================================
func make_sfx(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.18
	match kind:
		"stamp":
			dur = 0.28
		"coin":
			dur = 0.14
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 7
	for i in n:
		var tt := float(i) / rate
		var k := tt / dur
		var v := 0.0
		match kind:
			"press":
				var f := 420.0 + 600.0 * k
				ph += TAU * f / rate
				v = (0.6 * sign(sin(ph)) * 0.35 + 0.65 * sin(ph)) * pow(1.0 - k, 2.0)
				if i < 220:
					v += rng2.randf_range(-0.8, 0.8) * (1.0 - i / 220.0)
			"stamp":
				var f2 := 140.0 - 80.0 * k
				ph += TAU * f2 / rate
				v = sin(ph) * exp(-k * 7.0) * 1.1
				if i < 700:
					v += rng2.randf_range(-1.0, 1.0) * 0.6 * (1.0 - i / 700.0)
			"coin":
				var f3 := 1320.0 if k < 0.35 else 1980.0
				ph += TAU * f3 / rate
				v = sin(ph) * exp(-k * 4.0) * 0.7
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


# Müzik: parçalar arasında yumuşak geçiş
func play_music(kind: String) -> void:
	if kind == music_now or not music.has(kind):
		return
	music_now = kind
	for mk in music:
		var mp: AudioStreamPlayer = music[mk]
		if mk == kind:
			if not mp.playing:
				mp.volume_db = -40.0
				mp.play()
			create_tween().tween_property(mp, "volume_db", MUSIC_DB, 1.2)
		elif mp.playing:
			var tw := create_tween()
			tw.tween_property(mp, "volume_db", -60.0, 1.2)
			tw.tween_callback(mp.stop)


func play_sfx(kind: String) -> void:
	if sfx.has(kind):
		sfx[kind].play()


# Kazanılan altın (bütçe) ve kristallerin (Eko-XP) ekrandaki sayaçlara uçması
func fly(amount: int, kind: String, from: Vector2) -> void:
	if amount <= 0 or coin_layer == null:
		return
	var target_ctrl: Control = budget_lbl if kind == "gold" else xp_lbl
	var target := target_ctrl.get_global_rect().get_center()
	var count := mini(amount, 14)
	var per := int(ceil(float(amount) / count))
	var left := amount
	for i in count:
		var step := mini(per, left)
		left -= step
		var c := Panel.new()
		var st := StyleBoxFlat.new()
		if kind == "gold":
			st.bg_color = Color("#F2C14E")
			st.border_color = Color("#A8740C")
			st.set_corner_radius_all(11)
		else:
			st.bg_color = C_XP
			st.border_color = Color("#2E8FB5")
			st.set_corner_radius_all(3)
		st.set_border_width_all(2)
		c.add_theme_stylebox_override("panel", st)
		c.size = Vector2(22, 22)
		c.pivot_offset = Vector2(11, 11)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if kind != "gold":
			c.rotation_degrees = 45.0
		var start := from + Vector2(randf_range(-70, 70), randf_range(-50, 40))
		c.position = start - c.size / 2.0
		c.scale = Vector2.ZERO
		coin_layer.add_child(c)
		coins_flying += 1
		var tw := create_tween()
		tw.tween_interval(i * 0.07)
		tw.tween_property(c, "scale", Vector2(1.2, 1.2), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var mid := start.lerp(target, 0.5) + Vector2(0, -90)
		tw.tween_method(func(tv: float): c.position = start.lerp(mid, tv).lerp(mid.lerp(target, tv), tv) - c.size / 2.0, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(c, "scale", Vector2(0.6, 0.6), 0.6)
		tw.tween_callback(_coin_arrived.bind(c, kind, step))


func _coin_arrived(c: Control, kind: String, step: int) -> void:
	c.queue_free()
	coins_flying = maxi(0, coins_flying - 1)
	if kind == "gold":
		shown_budget = mini(shown_budget + step, budget)
		budget_lbl.text = "%s: %d %s" % [t("budget"), shown_budget, t("unit")]
		budget_lbl.modulate = Color(1.6, 1.4, 0.8)
		create_tween().tween_property(budget_lbl, "modulate", Color.WHITE, 0.25)
	else:
		shown_xp = mini(shown_xp + step, xp)
		xp_lbl.text = "%s: %d" % [t("xp"), shown_xp]
		tech_btn.text = "%s   (%d XP)" % [t("techBtn"), shown_xp]
		xp_lbl.modulate = Color(1.5, 1.6, 1.8)
		create_tween().tween_property(xp_lbl, "modulate", Color.WHITE, 0.25)
	coin_tick += 1
	if coin_tick % 2 == 0:
		play_sfx("coin")
	if coins_flying == 0:
		refresh_hud()


# =====================================================================
#  DURAKLATMA MENÜSÜ
# =====================================================================
func open_menu() -> void:
	if phase == "menu":
		return
	if not phase in ["play", "decide", "feedback", "event", "tech"]:
		return
	prev_phase = phase
	phase = "menu"
	confirm_restart = false
	click_target = null
	target_marker.visible = false
	prompt_btn.visible = false
	show_menu()


func show_menu(howto := false) -> void:
	var v := open_panel(520, 0.6)
	v.add_child(lbl(t("paused").to_upper(), 15, C_GOLD))
	v.add_child(lbl("Antalya 2050", 34, C_TEXT))
	v.add_child(lbl("%s  ·  %s %d  ·  %s %d" % [t("period")[round_i], t("budget"), budget, t("xp"), xp], 15, C_MUTED, true))
	if howto:
		var hs := ""
		for i in t("how").size():
			hs += "[color=#%s]%d.[/color]  %s\n" % [C_GOLD.to_html(false), i + 1, t("how")[i]]
		v.add_child(rt(hs.strip_edges(), 16))
		v.add_child(lbl(t("controls"), 14, C_MUTED, true))
		var bk := btn(t("back"), false, 17)
		bk.pressed.connect(show_menu)
		v.add_child(bk)
		bk.grab_focus()
		return
	var items := [
		[t("resume"), resume_game, true],
		[t("howto"), show_menu.bind(true), false],
		[t("sure") if confirm_restart else t("restart"), _on_menu_restart, false],
		[t("mainMenu"), _on_menu_main, false],
		[t("soundOff") if muted else t("soundOn"), _on_menu_sound, false],
		[t("fullscreen"), _on_menu_fullscreen, false],
	]
	if not OS.has_feature("web"):
		items.append([t("quit"), _on_menu_quit, false])
	var first: Button = null
	for it in items:
		var b := btn(it[0], it[2], 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(it[1])
		if it[1] == _on_menu_restart and confirm_restart:
			b.add_theme_stylebox_override("normal", sb(C_RISK, 10, 12))
			b.add_theme_color_override("font_color", Color.WHITE)
		v.add_child(b)
		if first == null:
			first = b
	first.grab_focus()
	refresh_hud()


func resume_game() -> void:
	if phase != "menu":
		return
	phase = prev_phase
	clear_overlay()
	match phase:
		"decide": open_decision(cur_di)
		"feedback": show_feedback(cur_di, choices[cur_di])
		"event": show_event_panel()
		"tech":
			phase = "play"
			open_tech()
		_:
			phase = "play"
	refresh_hud()


func _on_menu_restart() -> void:
	if not confirm_restart:
		confirm_restart = true
		show_menu()
		return
	confirm_restart = false
	clear_event_fx()
	_on_start()


func _on_menu_main() -> void:
	clear_event_fx()
	reset_world_state()
	show_intro()
	play_music("main")


func _on_menu_sound() -> void:
	muted = not muted
	AudioServer.set_bus_mute(0, muted)
	show_menu()


func _on_menu_fullscreen() -> void:
	var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _on_menu_quit() -> void:
	get_tree().quit()


# =====================================================================
#  TEKNOLOJİ AĞACI
# =====================================================================
func open_tech() -> void:
	if phase != "play" and phase != "tech":
		return
	phase = "tech"
	click_target = null
	target_marker.visible = false
	prompt_btn.visible = false
	var v := open_panel(1080, 0.5, true)
	v.add_child(lbl(("%s · %d XP" % [t("xp"), xp]).to_upper(), 15, C_XP))
	var hrow := HBoxContainer.new()
	var ttl := lbl(t("tech"), 30, C_TEXT)
	ttl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(ttl)
	var cb0 := btn(t("close"), false, 16)
	cb0.pressed.connect(close_tech)
	hrow.add_child(cb0)
	v.add_child(hrow)
	v.add_child(lbl(t("techP"), 15, C_MUTED, true))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for b in 3:
		var hl := lbl(t("branches")[b].to_upper(), 14, C_GOLD)
		grid.add_child(hl)
	for tier in 3:
		for b in 3:
			var td: Dictionary = {}
			for x in D.TECH:
				if int(x["branch"]) == b and int(x["tier"]) == tier:
					td = x
			var card := PanelContainer.new()
			var owned := has_tech(td["id"])
			var unlocked: bool = td["req"] == "" or has_tech(td["req"])
			var border := C_OK if owned else (C_XP if can_buy(td) else C_LINE)
			card.add_theme_stylebox_override("panel", sb(Color("#183A33") if owned else C_INK2, 12, 12, border))
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.modulate.a = 1.0 if (owned or unlocked) else 0.55
			grid.add_child(card)
			var cv := VBoxContainer.new()
			cv.add_theme_constant_override("separation", 6)
			card.add_child(cv)
			var nl := lbl(tx(td["name"]), 18, C_TEXT, true)
			nl.custom_minimum_size.x = 290
			cv.add_child(nl)
			cv.add_child(lbl(tx(td["desc"]), 13, C_MUTED, true))
			var sp := Control.new()
			sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
			cv.add_child(sp)
			if owned:
				cv.add_child(lbl(t("learned"), 16, C_OK.lightened(0.3)))
			elif not unlocked:
				cv.add_child(lbl("%s: %s" % [t("needs"), tx(tech_def(td["req"])["name"])], 14, C_MUTED, true))
			else:
				var bb := btn("%s · %d XP" % [t("learn"), td["cost"]], true, 16)
				bb.disabled = xp < int(td["cost"])
				bb.pressed.connect(buy_tech.bind(td["id"]))
				cv.add_child(bb)
	var cb := btn(t("close"), false, 16)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cb.pressed.connect(close_tech)
	v.add_child(cb)
	refresh_hud()


func close_tech() -> void:
	clear_overlay()
	phase = "play"
	refresh_hud()


func buy_tech(id: String) -> void:
	var td := tech_def(id)
	if td.is_empty() or not can_buy(td):
		return
	xp -= int(td["cost"])
	techs.append(id)
	apply_eff(td.get("eff", {}))
	spawn_tech_visual(id)
	refresh_world()
	toast(tx(td["name"]))
	open_tech()


func spawn_tech_visual(id: String) -> void:
	var v := visuals
	match id:
		"cistern":
			box(Vector3(3.2, 1.6, 2.2), Vector3(-29.5, 0.8, 3), Color("#C8B58E"), v)
			box(Vector3(1.2, 1.0, 0.1), Vector3(-29.5, 0.6, 4.12), Color("#3B3326"), v)
			box(Vector3(3.6, 0.3, 2.6), Vector3(-29.5, 1.75, 3), Color("#B09E78"), v)
		"smartgrid":
			for q in 4:
				cyl(0.12, 0.12, 3.0, Vector3(-21.5 + (q % 2) * 1.4, 1.5, -6.5 + int(q / 2) * 1.4), Color("#7A7F80"), v, 6)
			cyl(1.3, 1.3, 1.6, Vector3(-20.8, 3.6, -5.8), Color("#2E8FB5"), v)
		"vertical":
			box(Vector3(3, 9, 3), Vector3(30, 4.5, -12.5), Color("#D9F0E6"), v, false, mat(Color("#BFE8D2"), 0.2, false, 0.75))
			for fy in range(1, 9):
				box(Vector3(2.6, 0.18, 2.6), Vector3(30, fy, -12.5), Color("#4FA35A"), v)
		"wind":
			for p in [Vector3(-18, 0, -15.5), Vector3(-2, 0, -15.8), Vector3(18, 0, -15.5)]:
				cyl(0.18, 0.28, 8.0, p + Vector3(0, 4, 0), Color("#F2F4EF"), v, 8)
				var hub := Node3D.new()
				hub.position = p + Vector3(0, 8.1, 0.4)
				v.add_child(hub)
				sphere(0.3, Vector3.ZERO, Color("#F2F4EF"), hub)
				for k in 3:
					var arm := Node3D.new()
					arm.rotation.z = k * TAU / 3.0
					hub.add_child(arm)
					box(Vector3(0.25, 2.8, 0.08), Vector3(0, 1.4, 0), Color("#F2F4EF"), arm)
				turbines.append(hub)
		"firescape":
			for i in 14:
				var x := -30.0 + i * 4.6
				tree(Vector3(x, 0, -13.8), 0.75, v, true)
		"seagrass":
			seagrass.visible = true
			for i in 22:
				box(Vector3(rng.randf_range(1.5, 3.0), 0.05, rng.randf_range(1, 2)), Vector3(rng.randf_range(-32, 32), -0.05, rng.randf_range(19, 27)), Color("#3E8A55"), seagrass)
		"fund":
			box(Vector3(2.2, 0.1, 1.4), Vector3(-3.6, 0.1, 6.3), Color("#24456B"), v, false, mat(Color("#24456B"), 0.2))
			box(Vector3(2.2, 0.1, 1.4), Vector3(3.6, 0.1, 6.3), Color("#24456B"), v, false, mat(Color("#24456B"), 0.2))
		"fair":
			for q in 3:
				var tent := cyl(0.0, 1.0, 1.4, Vector3(-3 + q * 3, 0.7, -0.6), [C_GOLD, Color("#C79BEA"), C_OK][q], v, 6)
				tent.name = "tent%d" % q
		"solarcoop":
			for r in roofs:
				var b3: MeshInstance3D = r.get_parent()
				if b3.position.x < 15.0:
					var sz3: Vector3 = (b3.mesh as BoxMesh).size
					var pn := box(Vector3(sz3.x * 0.7, 0.06, sz3.z * 0.5), Vector3.ZERO, Color("#2B4E7A"), v, false, mat(Color("#2B4E7A"), 0.2))
					pn.global_position = b3.global_position + Vector3(0, sz3.y / 2.0 + 0.3, -0.4)

# =====================================================================
#  GİRDİ VE DÖNGÜ
# =====================================================================
func reset_world_state() -> void:
	reset_state()
	for c in visuals.get_children():
		c.queue_free()
	for c in seagrass.get_children():
		c.queue_free()
	seagrass.visible = false
	siren_light = null
	turbines = []
	for r in roofs:
		r.material_override = mat(Color("#B4553C")) if r.get_parent().position.y < 4.0 or r.get_parent().position.x < 15.0 else mat(Color("#C9C2B0"))
	(get_node("Mound") as Node3D).scale = Vector3(1.3, 0.5, 1.0)
	player.position = Vector3(0, 0.1, 8)
	player_vis.rotation.y = 0.0
	clear_overlay()
	refresh_world()


func _on_start() -> void:
	reset_world_state()
	play_music("main")
	clear_overlay()
	phase = "play"
	cam_mode = "follow"
	refresh_world()
	refresh_stations()
	refresh_hud()
	toast(t("follow") + "\n" + t("xpHint"))


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
		"tech": open_tech()
		"menu": open_menu()


var cur_di := -1


func _on_prompt() -> void:
	if phase == "play" and near_di >= 0:
		cur_di = near_di
		phase = "pressing"
		prompt_btn.visible = false
		var st: Dictionary = stations[cur_di]
		var cap: MeshInstance3D = st["cap"]
		play_sfx("press")
		var lt := OmniLight3D.new()
		lt.light_color = C_GOLD
		lt.omni_range = 7.0
		lt.light_energy = 0.0
		st["node"].add_child(lt)
		lt.position = Vector3(0, 1.8, -1.0)
		var tw := create_tween()
		tw.tween_property(cap, "position:y", 0.9, 0.08)
		tw.parallel().tween_property(lt, "light_energy", 5.0, 0.08)
		tw.tween_property(cap, "position:y", 1.02, 0.18)
		tw.parallel().tween_property(lt, "light_energy", 0.0, 0.35)
		tw.tween_callback(lt.queue_free)
		await get_tree().create_timer(0.45).timeout
		if phase == "pressing":
			open_decision(cur_di)


func _on_back() -> void:
	clear_overlay()
	phase = "play"
	refresh_hud()


func _on_choose(di: int, oi: int) -> void:
	var o: Dictionary = D.DEC[di]["opts"][oi]
	var c := option_cost(di, oi)
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
	var g := xp_for(o)
	xp += g
	fly(g, "xp", cam.unproject_position(player.position + Vector3(0, 2.0, 0)))
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
	if round_i < D.POOLS.size() - 1:
		round_i += 1
		play_music("main")
		var inc_now := income()
		budget += inc_now
		fly(inc_now, "gold", cam.unproject_position(Vector3(7, 4, -8)))
		phase = "play"
		cam_mode = "follow"
		refresh_stations()
		refresh_hud()
		toast("%s   ·   %s +%d" % [t("period")[round_i], t("budget"), income()] + ("\n" + t("xpHint") if any_buyable() else ""))
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


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		autoplay = not autoplay
		auto_t = 0.0
		toast(t("autoOn") if autoplay else t("autoOff"))
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if phase == "menu":
			resume_game()
			return
		if phase in ["play", "decide", "feedback", "event"]:
			open_menu()
			return
	if phase == "tech" and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_T, KEY_ESCAPE]:
		close_tech()
		return
	if phase != "play":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
			_on_prompt()
		elif event.keycode == KEY_T:
			open_tech()
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
	for si in stations.size():
		var s: Dictionary = stations[si]
		if s["node"].visible:
			s["ring"].rotation.y += delta * 1.2
			s["ring"].position.y = 0.15 + sin(t_clock * 3.0) * 0.08
			if phase == "play":
				var pulse: float = 1.0 + (0.18 * absf(sin(t_clock * 6.0)) if si == near_di else 0.0)
				s["cap"].scale = Vector3(pulse, 1.0, pulse)
	if siren_light:
		siren_light.visible = fmod(t_clock, 1.0) < 0.5
	for rot in turbines:
		rot.rotation.z += delta * 2.5
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
		"tech":
			if auto_t > 1.5:
				auto_t = 0
				var bought := false
				for td in D.TECH:
					if can_buy(td):
						buy_tech(td["id"])
						bought = true
						break
				if not bought:
					close_tech()
		"play":
			if any_buyable() and auto_t > 0.4:
				auto_t = 0
				open_tech()
				return
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
					if option_cost(cur_di, i) <= budget:
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
				print("AUTOPLAY_END ", stats, " budget=", budget, " xp=", xp, " techs=", techs, " events=", evlog)
				if "--fast" in OS.get_cmdline_user_args() and not OS.has_feature("web"):
					get_tree().quit()
		_:
			auto_t = 0
