extends CharacterBody3D

#onready
@onready var standupcheck: ShapeCast3D = $ShapeCast3D
@onready var head: Node3D = $head
@onready var camera: Camera3D = $head/Camera3D
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var footsteps: AudioStreamPlayer = $AudioStreamPlayer
@onready var land_sound: AudioStreamPlayer = $AudioStreamPlayer2

#bools
var crouching := false
var can_step := true
var just_jumped := false 

#movemnt
var input_dir := Vector2.ZERO
var speed
var direction := Vector3.ZERO
const walk_speed := 3.5
const sprint_speed := 4.5
const crouch_speed := 2.5
var jump_velo := 4.0
var gravity := 9.8

#fov
var fov
var base_fov := 75.0

#camera
var bob_amount := 0.1
var bob_freq := 8.0
var bob_timer := 0.0
var tilt_amount := 0.5
var fall_time := 0.3
var fall_value := 0.0
var fall_timer := 0.0
var sens := 0.04

enum states{
	IDLE,
	WALKING,
	RUNNING,
	AIR,
	CROUCHING,
}
var state := states.IDLE

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(deg_to_rad(-event.relative.x) * sens)
		head.rotate_x(deg_to_rad(-event.relative.y) * sens)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-60), deg_to_rad(60))
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		state = states.AIR
		just_jumped = true
		if velocity.y >= 0.0:
			velocity.y -= gravity * delta
		else:
			velocity.y -= gravity * delta * 2.0
	else:
		if Input.is_action_just_pressed("jump"):
			if crouching and not standupcheck.is_colliding():
				velocity.y = jump_velo * 0.7
			else:
				velocity.y = jump_velo
	if Input.is_action_pressed("sprint"):
		if crouching:
			return
		speed = sprint_speed
		state = states.RUNNING
	elif Input.is_action_just_pressed("crouch"):
		speed = crouch_speed
		state = states.CROUCHING
		start_crouch()
	else:
		if not crouching:
			speed = walk_speed
			state = states.WALKING
	if Input.is_action_just_released("crouch") and not standupcheck.is_colliding():
		end_crouch()
	input_dir = Input.get_vector("left","right","up","down")
	direction = lerp(direction , (transform.basis * Vector3(input_dir.x,0,input_dir.y)).normalized(), delta * 10.0)
	if is_on_floor():
		if just_jumped:
			just_jumped = false
			land_sound.volume_db = randf_range(-27.0,-33.0)
			land_sound.pitch_scale = randf_range(0.65,0.7)
			land_sound.play()
			add_fall_kick(1.4)
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.x, 0, speed)
	move_and_slide()
	update_camera_effects(delta)
	update_camera_fov(delta)
	fall_kick(delta)
	footstep()

func start_crouch():
	crouching = true
	anim.play("crouch")

func end_crouch():
	crouching = false
	anim.play("uncrouch")

func update_camera_fov(delta):
	fov = camera.fov
	if state == states.AIR:
		fov = lerp(fov, base_fov * 1.8, delta * 10.0)
	elif state == states.CROUCHING:
		fov = lerp(fov, base_fov / 4.0, delta * 10.0)
		bob_amount = 0.2
		footsteps.pitch_scale = randf_range(0.95, 1.05)
		footsteps.volume_db = randf_range(-35.0,-37.0)
	elif state == states.RUNNING:
		bob_amount = 0.25
		fov = lerp(fov, base_fov * 2.0, delta * 10.0)
		footsteps.pitch_scale = randf_range(0.95, 1.05)
		footsteps.volume_db = randf_range(-30.0,-33.0)
	elif state == states.WALKING:
		bob_amount = 0.15
		fov = lerp(fov, base_fov, delta * 10.0)
		footsteps.pitch_scale = randf_range(0.95, 1.05)
		footsteps.volume_db = randf_range(-33.0,-35.0)

func update_camera_effects(delta): #improve headbob
	var speed = Vector2(velocity.x, velocity.z).length()
	var bob_offset_y = 0.0
	var bob_offset_x = 0.0
	if speed > 0.1 and is_on_floor():
		bob_timer += delta * bob_freq
		bob_offset_y = sin(bob_timer) * bob_amount
		bob_offset_x = cos(bob_timer * 0.5) * (bob_amount * 0.5)
	else:
		bob_timer = 0.0
	camera.position.y = lerp(camera.position.y, bob_offset_y, delta * 10.0)
	camera.position.x = lerp(camera.position.x, bob_offset_x, delta * 6.0)
	var target_tilt = -input_dir.x * deg_to_rad(tilt_amount)
	camera.rotation.z = lerp_angle(camera.rotation.z, target_tilt, delta * 10.0)

func footstep():
	if not is_on_floor():
		return
	if can_step:
		if velocity.length() >= 0.1:
			can_step = false
			footsteps.play()
		if velocity.length() == 0.0 and footsteps.playing:
			footsteps.stop()
			await get_tree().create_timer(0.2).timeout
			can_step = true

func _on_audio_stream_player_finished() -> void:
	await get_tree().create_timer(0.2).timeout
	can_step = true

func fall_kick(delta):
	if fall_timer > 0.0:
		fall_timer -= delta
		var fall_ratio = fall_timer / 0.2
		var kick = fall_value * fall_ratio
		camera.rotation.x = clamp(head.rotation.x - kick, deg_to_rad(-60), deg_to_rad(60))
		camera.position.y = lerp(camera.position.y, -kick, delta * 10.0)
	else:
		camera.position.y = lerp(camera.position.y, 0.0, delta * 10.0)

func add_fall_kick(strength: float):
	fall_value = deg_to_rad(strength)
	fall_timer = fall_time
