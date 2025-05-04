@icon("res://assets/node_icons/blue/icon_character.png")
class_name Character
extends Entity


enum Animations {
	IDLE,
	RUN,
	DEATH,
}

enum Direction {
	DOWN,
	RIGHT,
	UP,
	LEFT,
}

var hand_type: Hand.Types

var weapon_name_right: String:
	set = _set_right_weapon
var weapon_name_left: String:
	set = _set_left_weapon
var equiped_weapon_right: Weapon
var equiped_weapon_left: Weapon

var sprite_frames: String = "knight":
	set = _set_sprite_frames

var anim: Animations = Animations.IDLE:
	set = _set_anim

var flipped: bool = false:
	set = _set_flip

var direction: Direction = Direction.DOWN:
	set = _set_direction

var use_directional_animations: bool = false

var pivot: float = 0.0:
	set = _set_pivot

# Customization properties
var character_customization: Dictionary = {}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hand_offset: Node2D = $HandOffset
@onready var hand_pivot: Node2D = $HandOffset/HandPivot

@onready var right_hand_spot: Node2D = $HandOffset/HandPivot/RightHandSpot
@onready var left_hand_spot: Node2D = $HandOffset/HandPivot/LeftHandSpot


func _ready() -> void:
	if right_hand_spot.get_child_count():
		equiped_weapon_right = right_hand_spot.get_child(0)
		equiped_weapon_right.hand.type = hand_type
		equiped_weapon_right.hand.side = Hand.Sides.RIGHT
	if left_hand_spot.get_child_count():
		equiped_weapon_left = left_hand_spot.get_child(0)
		equiped_weapon_right.hand.type = hand_type
		equiped_weapon_right.hand.side = Hand.Sides.LEFT
	
	# Apply customization if this is a human character
	apply_customization()


func apply_customization() -> void:
	if sprite_frames == "human" and character_customization.size() > 0:
		# Apply gender and age customization
		var gender = character_customization.get("gender", 0) # Default to male
		var age = character_customization.get("age", 1) # Default to teen
		
		# Create sprite path identifier based on gender and age
		var gender_str = "male" if gender == 0 else "female"
		var age_str = "adult"
		
		match age:
			0: age_str = "child"
			1: age_str = "teen"
			2: age_str = "adult"
			
		# Try to load the appropriate sprite frames based on customization
		var custom_sprite_frames_path = "res://source/common/resources/builtin/sprite_frames/human_%s_%s.tres" % [gender_str, age_str]
		
		if ResourceLoader.exists(custom_sprite_frames_path):
			print("Loading custom sprite frames: %s" % custom_sprite_frames_path)
			animated_sprite.sprite_frames = ResourceLoader.load(custom_sprite_frames_path)
		else:
			# Fall back to default human sprite frames if specific ones don't exist
			print("Custom sprite frames not found for %s_%s, using default human sprites" % [gender_str, age_str])
			var default_path = "res://source/common/resources/builtin/sprite_frames/human.tres"
			if ResourceLoader.exists(default_path):
				animated_sprite.sprite_frames = ResourceLoader.load(default_path)


func change_weapon(weapon_path: String, _side: bool = true) -> void:
	if equiped_weapon_right:
		equiped_weapon_right.queue_free()
	var new_weapon: Weapon = load("res://source/common/items/weapons/" + 
		weapon_path + ".tscn").instantiate()
	new_weapon.character = self
	right_hand_spot.add_child(new_weapon)
	equiped_weapon_right = new_weapon


func update_weapon_animation(state: String) -> void:
	equiped_weapon_right.play_animation(state)
	equiped_weapon_left.play_animation(state)


func _set_left_weapon(weapon_name: String) -> void:
	weapon_name_left = weapon_name
	change_weapon(weapon_name, false)


func _set_right_weapon(weapon_name: String) -> void:
	weapon_name_right = weapon_name
	change_weapon(weapon_name, true)


func _set_sprite_frames(new_sprite_frames: String) -> void:
	animated_sprite.sprite_frames = ResourceLoader.load(
		"res://source/common/resources/builtin/sprite_frames/" + new_sprite_frames + ".tres"
	)


func _set_anim(new_anim: Animations) -> void:
	anim = new_anim
	
	var anim_name = ""
	match new_anim:
		Animations.IDLE:
			anim_name = "idle"
		Animations.RUN:
			anim_name = "run"
		Animations.DEATH:
			anim_name = "death"
	
	# Append direction suffix if directional animations are enabled
	if use_directional_animations and new_anim != Animations.DEATH:
		var direction_suffix = ""
		match direction:
			Direction.UP:
				direction_suffix = "_up"
			Direction.RIGHT:
				direction_suffix = "_right"
			Direction.DOWN:
				direction_suffix = "_down"
			Direction.LEFT:
				direction_suffix = "_left"
		
		# Check if the directional animation exists, otherwise fall back to the base animation
		var directional_anim = anim_name + direction_suffix
		if animated_sprite.sprite_frames.has_animation(directional_anim):
			animated_sprite.play(directional_anim)
		else:
			animated_sprite.play(anim_name)
	else:
		animated_sprite.play(anim_name)
	
	update_weapon_animation(anim_name)


func _set_flip(new_flip: bool) -> void:
	animated_sprite.flip_h = new_flip
	hand_offset.scale.x = -1 if new_flip else 1
	flipped = new_flip


func _set_direction(new_direction: Direction) -> void:
	direction = new_direction
	# If the character has direction-specific animations, update the current animation
	if use_directional_animations:
		_set_anim(anim)


func _set_pivot(new_pivot: float) -> void:
	pivot = new_pivot
	hand_pivot.rotation = new_pivot


func _set_sync_state(new_state: Dictionary) -> void:
	sync_state = new_state
	for property: String in new_state:
		set(property, new_state[property])


func _set_spawn_state(new_state: Dictionary) -> void:
	spawn_state = new_state
	if not is_node_ready():
		await ready
	for property: String in new_state:
		set(property, new_state[property])


func update_direction_from_velocity(vel: Vector2) -> void:
	if vel.length() > 0:
		if abs(vel.x) > abs(vel.y):
			# Horizontal movement dominates
			direction = Direction.RIGHT if vel.x < 0 else Direction.LEFT
		else:
			# Vertical movement dominates
			direction = Direction.DOWN if vel.y > 0 else Direction.UP
