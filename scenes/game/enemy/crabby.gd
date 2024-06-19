extends CharacterBody2D

# Acciones del Enemigo
@export_enum("idle", "run")
var animation: String

# Dirección de movimiento del Enemigo
@export_enum("left", "right", "active")
var moving_direction: String

# Variables para referencias y configuraciones
@onready var _animation := $EnemyAnimation
@onready var _animation_effect := $EnemyEffect
@onready var _raycast_terrain := $Area2D/RayCastTerrain
@onready var _raycast_wall := $Area2D/RayCastWall
@onready var _raycast_vision_left := $Area2D/RayCastVisionLeft
@onready var _raycast_vision_right := $Area2D/RayCastVisionRight
@onready var _audio_player = $AudioStreamPlayer2D

# Sonidos pre-cargados
var _punch_sound = preload("res://assets/sounds/punch.mp3")
var _male_hurt_sound = preload("res://assets/sounds/male_hurt.mp3")

# Parámetros físicos
var _gravity = 10
var _speed = 25
var _moving_left = true
var _body: Node2D
var _is_persecuted = false
var _stop_detection = false
var _stop_attack = false
var _hit_to_die = 3
var _has_hits = 0
var die = false

func _ready():
	print("Enemigo listo")
	print("Nodo _animation:", _animation)
	if moving_direction == 'right':
		_moving_left = false
		scale.x = -scale.x
	
	if not animation:
		animation = "idle"
	
	_init_state()

func _physics_process(delta):
	if die:
		return
	
	if animation == "run":
		_move_character(delta)
		_turn()
	elif animation == "idle":
		_move_idle()
	
	if moving_direction == "active" and !_stop_detection:
		_detection()

func _move_character(delta):
	velocity.y += _gravity
	
	if _moving_left:
		velocity.x = -_speed
	else:
		velocity.x = _speed
	
	move_and_slide()

func _move_idle():
	velocity.y += _gravity
	velocity.x = 0
	move_and_slide()

func _on_area_2d_body_entered(body):
	if body.is_in_group("player"):
		_stop_detection = true
		_attack()
		_body = body

func _on_area_2d_body_exited(body):
	if not die:
		_init_state()

func _turn():
	if not _raycast_terrain.is_colliding() or _raycast_wall.is_colliding():
		var _object = _raycast_wall.get_collider()
		if not _object or (_object and not _object.is_in_group("player")):
			_moving_left = not _moving_left
			scale.x = -scale.x

func _attack():
	if _stop_attack:
		return
	
	if not _body:
		await get_tree().create_timer(1.0).timeout
		_attack()
		return
	
	_animation.play("attack")

func _init_state():
	if _stop_attack:
		return
	
	velocity.x = 0
	print("Reproduciendo animación:", animation)
	_animation.play(animation)
	_animation_effect.play("idle")
	_body = null
	_stop_detection = false

func _on_enemy_animation_frame_changed():
	if _stop_attack:
		return
	
	if _animation.frame == 0 and _animation.get_animation() == "attack":
		_animation_effect.play("attack_effect")
		
		if HealthDashboard.life > 0:
			_audio_player.stream = _male_hurt_sound
			_audio_player.play()
		else:
			_animation.play("idle")
			_animation_effect.play("idle")
		
		if _body:
			var _move_script = _body.get_node("MainCharacterMovement")
			_move_script.hit(2)

func _detection():
	if not _raycast_terrain.is_colliding():
		_init_state()
		return
	
	var _object1 = _raycast_vision_left.get_collider()
	var _object2 = _raycast_vision_right.get_collider()
	
	if _object1 and _object1.is_in_group("player") and _raycast_vision_left.is_colliding():
		_move(true)
	
	if _object2 and _object2.is_in_group("player") and _raycast_vision_right.is_colliding():
		_move(false)
	
	if not _object1 and not _object2 and _animation.get_animation() != "attack":
		_is_persecuted = false

func _move(direction):
	if _is_persecuted or _animation.get_animation() == "attack":
		return
	
	velocity.y += _gravity
	
	if not direction:
		_moving_left = not _moving_left
		scale.x = -scale.x
	else:
		if _moving_left:
			velocity.x = -_speed * 5
		else:
			velocity.x = _speed * 5
	
	move_and_slide()

func _on_area_2d_area_entered(area):
	if area.is_in_group("hit") or area.is_in_group("die"):
		die = true
		_damage()

func _damage():
	_has_hits += 1
	_audio_player.stream = _punch_sound
	_audio_player.play()
	_animation.play("hit")
	_animation_effect.play("idle")
	
	if Global.number_attack > 0:
		die = true
		Global.number_attack -= 1
	
	if Global.number_attack == 0:
		Global.attack_effect = "normal"
	
	if die or _hit_to_die <= _has_hits:
		_stop_attack = true
		die = true
		velocity.x = 0
		
		if _animation.animation != "dead_ground":
			_animation.play("dead_ground")

func _on_enemy_animation_animation_finished():
	if _animation.animation == "dead_ground":
		queue_free()
	elif _animation.animation == "hit":
		if not _stop_attack:
			_animation.play("idle")
			_animation_effect.play("idle")
			_attack()
