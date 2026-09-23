extends Node3D

var player: CharacterBody3D
var cam: Camera3D
var status: Label
var swing_anchor: Vector3
var swinging := false
var web_line: MeshInstance3D
var attack_cooldown := 0.0
var swing_length := 22.0
var gravity := 24.0
var speed := 10.0

func _ready():
    player = $Player
    cam = $Player/Camera3D
    status = $HUD/Status
    _make_player()
    _make_city()
    _make_ground()
    _make_web_line()

func _process(delta):
    attack_cooldown = max(0.0, attack_cooldown - delta)
    if swinging:
        _update_swing(delta)
    _update_web_visual()
    if not swinging:
        status.text = "Web: READY  |  Speed: %d" % int(player.velocity.length())
    else:
        status.text = "WEB SWINGING  |  Release LMB to launch"

func _physics_process(delta):
    var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
    var basis = cam.global_transform.basis
    var dir = (basis.x * input_vec.x + -basis.z * input_vec.y)
    dir.y = 0
    dir = dir.normalized()

    if not swinging:
        var target = dir * speed
        player.velocity.x = move_toward(player.velocity.x, target.x, 35.0 * delta)
        player.velocity.z = move_toward(player.velocity.z, target.z, 35.0 * delta)
        if not player.is_on_floor():
            player.velocity.y -= gravity * delta
        else:
            if Input.is_action_just_pressed("jump"):
                player.velocity.y = 11.5
        player.move_and_slide()

    if Input.is_action_just_pressed("web_swing"):
        _try_attach_web()
    if Input.is_action_just_released("web_swing") and swinging:
        _release_web()
    if Input.is_action_just_pressed("web_attack"):
        _web_attack()

func _try_attach_web():
    var center = get_viewport().get_camera_3d().global_position
    var forward = -get_viewport().get_camera_3d().global_transform.basis.z
    var query = PhysicsRayQueryParameters3D.create(center, center + forward * 80.0)
    query.collision_mask = 1
    var hit = get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        swing_anchor = hit.position
    else:
        # Convenient high anchor if the ray misses the buildings.
        swing_anchor = player.global_position + Vector3(0, 24, -12)
    swing_length = clamp(player.global_position.distance_to(swing_anchor), 8.0, 30.0)
    swinging = true
    player.set_collision_layer_value(1, false)

func _update_swing(delta):
    var to_anchor = swing_anchor - player.global_position
    var dist = to_anchor.length()
    if dist < 0.1:
        return
    var radial = to_anchor / dist

    player.velocity.y -= gravity * delta
    var radial_speed = player.velocity.dot(radial)
    player.velocity -= radial * radial_speed

    var tangent = player.velocity
    tangent.y += 5.0 * delta
    player.velocity = tangent

    player.move_and_slide()

    var new_dist = player.global_position.distance_to(swing_anchor)
    var correction = (new_dist - swing_length)
    if correction > 0:
        player.global_position += radial * correction

func _release_web():
    swinging = false
    player.set_collision_layer_value(1, true)
    player.velocity += (-cam.global_transform.basis.z * 8.0) + Vector3.UP * 3.0

func _web_attack():
    if attack_cooldown > 0:
        return
    attack_cooldown = 0.35
    var origin = cam.global_position
    var forward = -cam.global_transform.basis.z
    var query = PhysicsRayQueryParameters3D.create(origin, origin + forward * 25.0)
    query.collision_mask = 2
    var hit = get_world_3d().direct_space_state.intersect_ray(query)
    if hit:
        var body = hit.collider
        if body.has_method("webbed"):
            body.webbed()
    _flash_web(origin, origin + forward * 25.0)

func _make_web_line():
    web_line = MeshInstance3D.new()
    web_line.mesh = ImmediateMesh.new()
    web_line.visible = false
    add_child(web_line)

func _update_web_visual():
    if not swinging:
        web_line.visible = false
        return
    web_line.visible = true
    var mesh := web_line.mesh as ImmediateMesh
    mesh.clear_surfaces()
    mesh.surface_begin(Mesh.PRIMITIVE_LINES)
    mesh.surface_set_color(Color(0.92, 0.95, 1.0))
    mesh.surface_add_vertex(player.global_position + Vector3(0, 1.2, 0))
    mesh.surface_add_vertex(swing_anchor)
    mesh.surface_end()

func _flash_web(a, b):
    var m := MeshInstance3D.new()
    var im := ImmediateMesh.new()
    im.surface_begin(Mesh.PRIMITIVE_LINES)
    im.surface_set_color(Color(0.95,0.97,1))
    im.surface_add_vertex(a)
    im.surface_add_vertex(b)
    im.surface_end()
    m.mesh = im
    add_child(m)
    var timer := get_tree().create_timer(0.12)
    timer.timeout.connect(m.queue_free)

func _make_player():
    var body = MeshInstance3D.new()
    var capsule = CapsuleMesh.new()
    capsule.height = 1.8
    capsule.radius = 0.42
    body.mesh = capsule
    body.position = Vector3(0, 0.95, 0)
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.16, 0.025, 0.03)
    mat.metallic = 0.15
    mat.roughness = 0.45
    body.material_override = mat
    player.add_child(body)

    var shape = CollisionShape3D.new()
    var capsule_shape = CapsuleShape3D.new()
    capsule_shape.height = 1.8
    capsule_shape.radius = 0.42
    shape.shape = capsule_shape
    shape.position.y = 0.95
    player.add_child(shape)

    var head = MeshInstance3D.new()
    var sphere = SphereMesh.new()
    sphere.radius = 0.34
    sphere.height = 0.68
    head.mesh = sphere
    head.position = Vector3(0, 2.0, 0)
    var headmat = StandardMaterial3D.new()
    headmat.albedo_color = Color(0.72,0.03,0.04)
    headmat.roughness = 0.5
    head.material_override = headmat
    player.add_child(head)

func _make_ground():
    var floor = StaticBody3D.new()
    floor.collision_layer = 1
    add_child(floor)
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = Vector3(180, 1, 180)
    mesh.mesh = box
    mesh.position.y = -0.5
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.055,0.065,0.08)
    mat.roughness = 0.9
    mesh.material_override = mat
    floor.add_child(mesh)
    var shape = CollisionShape3D.new()
    var bs = BoxShape3D.new()
    bs.size = Vector3(180,1,180)
    shape.shape = bs
    shape.position.y = -0.5
    floor.add_child(shape)

func _make_city():
    var rng = RandomNumberGenerator.new()
    rng.seed = 73421
    for x in range(-7, 8):
        for z in range(-7, 8):
            if abs(x) < 2 and abs(z) < 2:
                continue
            var h = rng.randf_range(5.0, 24.0)
            var w = rng.randf_range(4.0, 8.0)
            var b = StaticBody3D.new()
            b.collision_layer = 1
            add_child(b)
            b.position = Vector3(x * 11.0, h/2.0, z * 11.0)
            var mi = MeshInstance3D.new()
            var bm = BoxMesh.new()
            bm.size = Vector3(w, h, w)
            mi.mesh = bm
            var mat = StandardMaterial3D.new()
            mat.albedo_color = Color(0.11 + rng.randf()*0.06, 0.12 + rng.randf()*0.06, 0.16 + rng.randf()*0.08)
            mat.roughness = 0.75
            mi.material_override = mat
            b.add_child(mi)
            var cs = CollisionShape3D.new()
            var bs = BoxShape3D.new()
            bs.size = Vector3(w, h, w)
            cs.shape = bs
            b.add_child(cs)
            _add_windows(b, w, h, rng)

func _add_windows(parent, w, h, rng):
    for y in range(2, int(h), 3):
        for side in [-1, 1]:
            var win = MeshInstance3D.new()
            var wm = BoxMesh.new()
            wm.size = Vector3(0.9, 0.8, 0.08)
            win.mesh = wm
            win.position = Vector3(rng.randf_range(-w*0.32,w*0.32), y-h/2.0, side*w/2.0+side*0.05)
            var mat = StandardMaterial3D.new()
            mat.albedo_color = Color(0.55,0.65,0.78)
            mat.emission_enabled = true
            mat.emission = Color(0.2,0.3,0.5)
            mat.emission_energy_multiplier = 1.4
            win.material_override = mat
            parent.add_child(win)
