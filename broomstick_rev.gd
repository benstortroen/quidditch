extends CharacterBody3D

enum State { UNMOUNTED, MOUNTED, STEERING }

@export var player_origin: XROrigin3D
@export var steer_hand: XRController3D      # left hand
@export var hover_height := 1.5
@export var max_speed := 20.0
@export var accel := 8.0
@export var drag := 0.15                     # low = decelerates very slowly
@export var pitch_rate := 1.5                # rad/s per meter of hand offset
@export var yaw_rate := 1.5

var state := State.UNMOUNTED
var speed := 0.0
var grab_origin: Vector3                     # hand pos (broom-local) when the grip started
var seat_offset: Transform3D

func _ready() -> void:
	steer_hand.button_pressed.connect(_on_button_pressed)
	steer_hand.button_released.connect(_on_button_released)

func _physics_process(delta: float) -> void:
	match state:
		State.UNMOUNTED: _hover(delta)
		State.MOUNTED, State.STEERING: _fly(delta)

func _hover(delta: float) -> void:
	# hold 1.5 m above the ground, no movement
	global_position.y = lerp(global_position.y, hover_height, 5.0 * delta)
	velocity = Vector3.ZERO

func _fly(delta: float) -> void:
	var stick := steer_hand.get_vector2("primary")
	speed += stick.y * accel * delta
	speed *= exp(-drag * delta)              # slow, framerate-independent decay
	speed = clamp(speed, -max_speed * 0.3, max_speed)

	if state == State.STEERING:
		var offset := to_local(steer_hand.global_position) - grab_origin
		rotate_object_local(Vector3.RIGHT, offset.y * pitch_rate * delta)
		rotate_y(-offset.x * yaw_rate * delta)

	velocity = -global_basis.z * speed       # forward is -Z in Godot
	move_and_slide()
	player_origin.global_transform = global_transform * seat_offset
	
var cam := player_origin.get_node("XRCamera3D") as XRCamera3D
var head_local := cam.transform.origin                 # head relative to origin
var desired_origin := $Seat.global_transform.translated(-head_local)
seat_offset = global_transform.affine_inverse() * desired_origin

func _on_button_pressed(action: String) -> void:
	match action:
		"ax_button": if state == State.UNMOUNTED and _hand_in_grab_area(): mount()
		"by_button": if state != State.UNMOUNTED: dismount()
		"grip_click":
			if state == State.MOUNTED:
				grab_origin = to_local(steer_hand.global_position)
				state = State.STEERING

func _on_button_released(action: String) -> void:
	if action == "grip_click" and state == State.STEERING:
		state = State.MOUNTED                # keeps momentum, just stops steering
		
		
