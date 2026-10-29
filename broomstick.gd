extends CharacterBody3D

enum State { UNMOUNTED, MOUNTED, STEERING }

# Variables
var state := State.UNMOUNTED
var grab_origin : Vector3

# Stats
var speed = 0
var max_speed = 20 
var max_pitch = deg_to_rad(60)
var pitch_rate = 5
var yaw_rate = 5

# Compmemts
@onready var XROrigin : XROrigin3D = get_tree().get_first_node_in_group("player")
@onready var PlayerBody : XRToolsPlayerBody = XROrigin.get_node("PlayerBody")
@onready var LeftHand : XRController3D = XROrigin.get_node("LeftHand")
@onready var RightHand : XRController3D = XROrigin.get_node("RightHand")
@onready var GroundRay : RayCast3D = $GroundRay

# ==============================================================================
# Read input from VR Controllers to control broom's state
func _ready():
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
	# slowly decelerate if idle
	velocity = velocity.move_toward(Vector3(0, 0, 0), delta * 5)
	
	# TODO: move broomstick forward in joystick's y direction
	var stick : Vector2 = LeftHand.get_vector2("primary")
	if stick.y != 0:
		var forward = -global_transform.basis.z 
		velocity = forward * stick.y * max_speed
	
	# TODO: rotate broom with joystick x axis input
	if stick.x != 0:
		rotation.y -= stick.x * yaw_rate * 0.5 * delta
		XROrigin.rotate_y(-stick.x * yaw_rate * 0.5 * delta)
	
	# TODO: rotate broom to steering hand
	if state == State.STEERING:
		#XROrigin.rotation.y = rotation.y
		#look_at(LeftHand.global_position, Vector3.UP)
		
		var offset := to_local(LeftHand.global_position) - grab_origin
		rotation.x += offset.y * pitch_rate * delta
		rotation.x = clampf(rotation.x, -max_pitch, max_pitch)
		rotation.y += -offset.x * yaw_rate * delta
		rotation.z = 0.0 # prevent roll from happening
	 	# rotate player's body along with broom
		XROrigin.rotate_y(-offset.x * yaw_rate * delta)
		
		
	move_and_slide()
	
	# TODO: bind player head to broomstick seat 
	var seat_offset : Vector3 = Vector3(0, -0.5, 0)
	XROrigin.global_position = global_position + seat_offset
	
# ==============================================================================

	
# ==============================================================================
# Debug timer to show relevant info
func _on_timer_timeout() -> void:
	print("Velocity: " + str(velocity))
