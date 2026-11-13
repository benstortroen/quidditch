extends CharacterBody3D

enum State { UNMOUNTED, MOUNTED, STEERING }

# Variables
var state := State.UNMOUNTED
var grab_origin : Vector3
var head_offset : Vector3   # head position relative to XROrigin (origin-local, horizontal) captured on mount

# Stats
var speed = 0
var max_speed = 50
var max_pitch = deg_to_rad(60)
var pitch_rate = 10
var yaw_rate = 5

# Compmemts
@onready var XROrigin : XROrigin3D = get_tree().get_first_node_in_group("player")
@onready var PlayerBody : XRToolsPlayerBody = XROrigin.get_node("PlayerBody")
@onready var LeftHand : XRController3D = XROrigin.get_node("LeftHand")
@onready var RightHand : XRController3D = XROrigin.get_node("RightHand")
@onready var XRCamera : XRCamera3D = XROrigin.get_node("XRCamera3D")
@onready var GroundRay : RayCast3D = $GroundRay
@onready var WindSFX : AudioStreamPlayer3D = $WindSFX

# ==============================================================================
# Read input from VR Controllers to control broom's state
func _ready():
	process_physics_priority = -100   # move broom + player before XRToolsHand (-70) copies the controllers
	LeftHand.button_pressed.connect(_on_button_pressed)
	LeftHand.button_released.connect(_on_button_released)
	
func _on_button_pressed(action: String) -> void:
	print("pressed ", action)
	# XR SIMULATOR
	# 1: "by_button"
	# 2: "ax_button"
	
	match action:
		"ax_button":
			PlayerBody.enabled = false
			_calibrate_head()
			state = State.MOUNTED
		"by_button":
			PlayerBody.enabled = true
			state = State.UNMOUNTED
		"grip_click":
				if state == State.MOUNTED:
					grab_origin = to_local(LeftHand.global_position)
					state = State.STEERING
		
	# TODO: check if player is grabbing 
	
func _on_button_released(action: String) -> void:
	if action == "grip_click" and state == State.STEERING:
		state = State.MOUNTED

# ==============================================================================
func _physics_process(delta: float) -> void:
	match state:
		State.UNMOUNTED:
			_hover(delta)
		State.MOUNTED, State.STEERING:
			_fly(delta)
			
	# scale wind sfx based on velocity (max speed ~ 25)
	var audio_weight = velocity.length() / 25
	WindSFX.pitch_scale = lerp(1.0, 2.0, audio_weight)
	WindSFX.volume_linear = lerp(0.1, 0.5, audio_weight)

func _hover(delta: float) -> void:
	# slowly fall to ground until ray hits
	# rise if dist to ground is < 1.5m
	# visual: bob up and down
	
	# Check if broom is close to the ground
	if GroundRay.is_colliding():
		# ascend slowly
		velocity = velocity.move_toward(Vector3(0, 1.5, 0), delta)
	else:
		# descend slowly
		velocity = velocity.move_toward(Vector3(0, -1.5, 0), delta)
		
	move_and_slide()
		
	
func _fly(delta: float) -> void:
	# move broomstick forward on trigger click
	var trigger : float = LeftHand.get_float("trigger")
	speed = trigger * abs(trigger) * max_speed
	
	# speed climbs when moving down
	speed -= sin(rotation.x) * 200 * delta
	print(-sin(rotation.x) * 9.8 * 20 * delta)
	
	# coasting: slow deceleration
	var rate = 1.0
	if speed > 0: 
		rate = 20
	elif speed < 0:
		rate = 30
	
	# Get joystick input as Vector2
	var stick : Vector2 = LeftHand.get_vector2("primary")
	
	# TODO: rotate broom (yaw) with joystick x axis input
	rotation.y -= stick.x * yaw_rate * 0.5 * delta
	XROrigin.rotate_y(-stick.x * yaw_rate * 0.5 * delta)
	
	# TODO: rotate broom (pitch) with joystick y axis input
	rotation.x += stick.y * pitch_rate * 0.5 * delta
	
	# TODO: rotate broom to steering hand
	if state == State.STEERING:
		
		var offset := to_local(LeftHand.global_position) - grab_origin
		rotation.x += offset.y * pitch_rate * delta
		rotation.y += -offset.x * yaw_rate * delta
		rotation.z = 0.0 # prevent roll from happening
	 	# rotate player's body along with broom
		XROrigin.rotate_y(-offset.x * yaw_rate * delta)
		
	rotation.x = clampf(rotation.x, -max_pitch, max_pitch)
	velocity = velocity.move_toward(speed * -global_transform.basis.z, delta * rate)
	move_and_slide()
	
	# TODO: bind player head to broomstick seat 
	# offset by where the head sits in the play space so the HEAD (not the play-space center) lands on the seat
	var seat_offset : Vector3 = Vector3(0, -0.5, 0)
	XROrigin.global_position = global_position + seat_offset - XROrigin.global_basis * head_offset
	
# ==============================================================================

	
# Record where the player's head is relative to the XROrigin (play-space center).
# Done once on mount so the player can still lean/look around afterwards.
func _calibrate_head() -> void:
	head_offset = XRCamera.position
	head_offset.y = 0.0

# ==============================================================================
# Debug timer to show relevant info
func _on_timer_timeout() -> void:
	print("Velocity: " + str(velocity.length()))
