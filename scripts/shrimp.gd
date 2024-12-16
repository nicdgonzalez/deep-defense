"""
Un camarón muy simpático. Tiene un area de detección moderada,
se mueve por el suelo y ataca cuerpo a cuerpo con un hacha.

@author: Tomás Daniel Expósito Torre.
"""
extends PathFinderEnemy

@onready var nav: NavigationAgent3D = $Navigation
@onready var safe: Node3D = %Safe
@onready var animation: AnimationPlayer = $AnimationPlayer
@onready var damage_range: Area3D = $DamageRange
@onready var attack_range: Area3D = $AttackRange
@onready var axe_swing: AudioStreamPlayer3D = $Axe

# ------------------------------------------------------------------------------
# ----------------------------- FUNCIONES NORMALES -----------------------------
# ------------------------------------------------------------------------------
func _ready():
	super._ready()
	# Parámetros normales
	health = 5
	damage = 3
	speed = 1
	
	# Parámetros para el estado enfurecido
	ex_speed = 2
	ex_damage = 7
	ex_atk_speed = 2

func _physics_process(delta: float) -> void:
	if attacking:
		return
	
	nav.target_position = target.global_position		
	look_at(nav.target_position)
		
	if target in attack_range.get_overlapping_bodies():
		attack(target)
	else:
		animation.play("Walking")
		
		var direction = (nav.get_next_path_position() - global_position).normalized()
		direction.y = 0
		
		velocity = direction * (speed if not enraged else ex_speed)
	
		move_and_slide()


# ------------------------------------------------------------------------------
# ----------------------------------- ATAQUE -----------------------------------
# ------------------------------------------------------------------------------
func melee_entered(body: Node3D) -> void:
	if not attacking and body.name in ["Player", "Safe"]:
		attack(body)
			
func animation_finished(anim_name: StringName) -> void:
	if anim_name == "Attack":
		attacking = false

func attack(body: Node3D):
	attacking = true
	animation.play("Attack")
	animation.speed_scale = atk_speed if not enraged else ex_atk_speed
	await get_tree().create_timer(1.66 / animation.speed_scale).timeout
	
	axe_swing.pitch_scale = randf_range(0.8,1.2)
	axe_swing.play()
	if body in damage_range.get_overlapping_bodies() and body.has_method("take_damage"):
		body.take_damage(damage if not enraged else ex_damage)

# ------------------------------------------------------------------------------
# --------------------------------- DETECCION ----------------------------------
# ------------------------------------------------------------------------------
func detection_entered(body: Node3D) -> void:
	if body.name == "Player":
		target = body

func detection_exited(body: Node3D) -> void:
	if not enraged and body.name == target.name:
		target = safe

# ------------------------------------------------------------------------------
# ------------------------------------ VIDA ------------------------------------
# ------------------------------------------------------------------------------
func take_damage(n: int):
	health -= n
	animation.play("Damaged")
	if health <= 0:
		queue_free()
