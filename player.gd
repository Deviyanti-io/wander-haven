extends CharacterBody3D

@export_group("Movement")
@export var speed: float = 6.0
@export var acceleration: float = 25.0    # Kecepatan menambah laju (responsif tapi halus)
@export var friction: float = 20.0        # Kecepatan melambat saat tombol dilepas
@export var jump_velocity: float = 5.5
@export var turn_speed: float = 12.0      # Kehalusan putaran badan karakter

@export_group("Camera")
@export var mouse_sensitivity: float = 0.003

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var spring_arm: SpringArm3D = $SpringArm3D
# Otomatis mencari model karakter apa pun namanya (Sketchfab_Scene atau Node0)
@onready var mesh = get_node_or_null("Sketchfab_Scene") if has_node("Sketchfab_Scene") else get_node_or_null("Node0")
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Kunci kursor mouse di tengah layar saat bermain
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	spring_arm.add_excluded_object(get_rid())
	
	# Fallback jika model menggunakan nama lain
	if not mesh:
		for child in get_children():
			if child is Node3D and child != spring_arm and not child is CollisionShape3D and not child is MeshInstance3D:
				mesh = child
				break

func _unhandled_input(event: InputEvent) -> void:
	# Tekan ESC untuk memunculkan kursor mouse
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Klik kiri pada layar untuk mengunci kursor kembali
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	# Putar kamera orbit dengan mouse
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		spring_arm.rotate_y(-event.relative.x * mouse_sensitivity)
		spring_arm.rotation.x = clamp(spring_arm.rotation.x - event.relative.y * mouse_sensitivity, deg_to_rad(-60), deg_to_rad(30))

func _physics_process(delta: float) -> void:
	# Terapkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Lompat dengan SPASI
	var is_jumping := Input.is_key_pressed(KEY_SPACE) or (Input.is_action_just_pressed("jump") if InputMap.has_action("jump") else false)
	if is_jumping and is_on_floor():
		velocity.y = jump_velocity

	# Deteksi input WASD / Panah
	var input_dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()

	# Sesuaikan arah jalan dengan arah hadap kamera
	var cam_forward := -spring_arm.global_transform.basis.z
	var cam_right := spring_arm.global_transform.basis.x
	cam_forward.y = 0
	cam_right.y = 0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	var direction := (cam_forward * (-input_dir.y) + cam_right * input_dir.x).normalized()

	# Akselerasi & Perlambatan Halus (Tahan Shift untuk lari)
	var current_speed := speed * 1.6 if Input.is_key_pressed(KEY_SHIFT) else speed
	if direction != Vector3.ZERO:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, acceleration * delta)
		
		# Putaran badan menghadap ke arah jalan (selalu menghadap ke depan arah jalan)
		if mesh:
			var target_angle := atan2(direction.x, direction.z)
			mesh.rotation.y = lerp_angle(mesh.rotation.y, target_angle, turn_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# Putar animasi sesuai status gerakan
	_update_animation(direction)

	move_and_slide()

func _update_animation(direction: Vector3) -> void:
	if not anim_player:
		return

	if not is_on_floor():
		for anim in ["jump", "Jump/mixamo_com", "jump/mixamo_com"]:
			if anim_player.has_animation(anim):
				anim_player.play(anim)
				return
	elif direction != Vector3.ZERO:
		var is_running := Input.is_key_pressed(KEY_SHIFT)
		var desired_anim := "run" if is_running else "walk"
		if anim_player.has_animation(desired_anim):
			anim_player.play(desired_anim)
			return
		for anim in ["walk", "run", "Female Walk/mixamo_com", "Running/mixamo_com"]:
			if anim_player.has_animation(anim):
				anim_player.play(anim)
				return
	else:
		for anim in ["idle", "Idle/mixamo_com", "idle/mixamo_com"]:
			if anim_player.has_animation(anim):
				anim_player.play(anim)
				return
