"""
Protagonista del juego, el defensor de la fórmula secreta.
Puede golpear a enemigos con los puños, moverse en 3D y XR.

@author: Tomás Daniel Expósito Torre.
"""
extends CharacterBody3D

# 3D variables
@onready var camera: Camera3D = $head/Camera3D
@onready var armature: Node3D = $Armature
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var damage_range: Area3D = $"Damage Range"
@onready var sounds: Node3D = $Sounds

const WALK_SPEED = 5.0
const SPRINT_SPEED = 5.0 * 1.25
const JUMP_VELOCITY = 5
const ATK_DAMAGE = 5
var health = 15

const SENSITIVITY = 0.01
const BFREQ = 2 
const BAMP = 0.03
var btime = 0
var attacking = false
var dying = false

# XR variables
@onready var xr_camera = $xr_origin/XRCamera3D
@onready var xr_origin = $xr_origin
@onready var left_controller = %Left
@onready var right_controller = %Right

var use_xr = false

func _ready():
	if not use_xr:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-40), deg_to_rad(60))

func _physics_process(delta: float) -> void:
	if dying:
		return
	health = clamp(health+delta, 0, 15) # Player regeneration (1 HP/s)
	if use_xr:
		physics_xr(delta)
	else:
		physics_3d(delta)

func physics_3d(delta):
	var sprinting = Input.is_action_pressed("sprint")
	var direction := Input.get_vector("left", "right", "up", "down")
	var movement := (transform.basis * Vector3(direction.x, 0, direction.y)).normalized()
	
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	# Movement and attack
	if attacking:
		velocity.x = 0
		velocity.z = 0
	else:
		if movement:
			animation.play("Walking")
			animation.speed_scale = 2 if sprinting else 1
			velocity.x = movement.x * (SPRINT_SPEED if sprinting else WALK_SPEED)
			velocity.z = movement.z * (SPRINT_SPEED if sprinting else WALK_SPEED)
		else:
			animation.play("Idle")
			velocity.x = 0
			velocity.z = 0
		
		if Input.is_action_just_pressed("lclick"):
			animation.play("Attacking")
			animation.speed_scale = 4
			attacking = true
	
	# Camera bobbing
	btime += delta * velocity.length() * float(is_on_floor())
	camera.transform.origin = Vector3(cos(btime * BFREQ / 2) * BAMP, sin(btime*BFREQ) * BAMP, 0)
	move_and_slide()

func physics_xr(delta):
	var dir = XRToolsUserSettings.get_adjusted_vector2(left_controller, "primary")
	dir.y = -dir.y
	var camdir = XRToolsUserSettings.get_adjusted_vector2(right_controller, "primary")
	var sprinting = left_controller.is_button_pressed("primary_click")
	var jumping = left_controller.is_button_pressed("ax_button") or right_controller.is_button_pressed("ax_button")
	var attack = left_controller.is_button_pressed("trigger_click") or right_controller.is_button_pressed("trigger_click")

	var direction := (transform.basis * Vector3(dir.x, 0, dir.y)).normalized()
	
	# Handle jumping
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif jumping:
		velocity.y = JUMP_VELOCITY

	if attacking:
		velocity.x = 0
		velocity.z = 0
	else:
		if direction:
			animation.play("Walking")
			animation.speed_scale = 2 if sprinting else 1
			velocity.x = direction.x * (SPRINT_SPEED if sprinting else WALK_SPEED)
			velocity.z = direction.z * (SPRINT_SPEED if sprinting else WALK_SPEED)
		else:
			animation.play("Idle")
			velocity.x = 0
			velocity.z = 0
		
		if attack:
			animation.play("Attacking")
			animation.speed_scale = 4
			attacking = true
	
	# Handle camera
	if camdir:
		rotate_y(-camdir.x * SENSITIVITY * 8)
	move_and_slide()
	

func _on_animation_finished(anim: StringName) -> void:
	if anim == "Attacking":
		sounds.get_node("Attack").play(0.09)
		for body in damage_range.get_overlapping_bodies():
			if body.has_method("take_damage") and body.name != "Safe":
				body.take_damage(ATK_DAMAGE)
		attacking = false

func take_damage(n: int):
	if dying:
		return
	health = clamp(health-n,0,15)
	if health <= 0:
		var death_sound = sounds.get_node("Death")
		death_sound.play()
		dying = true
	else:
		sounds.get_node("Damaged").play(0.09)
	


func _on_death_finished():
	get_viewport().use_xr = false
	get_tree().change_scene_to_file("res://scenes/final-screen.tscn")
