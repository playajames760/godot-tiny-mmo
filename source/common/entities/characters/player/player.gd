class_name Player
extends Character


var character_class: String:
	set = _set_character_class
var character_resource: CharacterResource
# Unused
var player_resource: PlayerResource

var display_name: String = "Unknown":
	set = _set_display_name

var is_in_pvp_zone: bool = false
var just_teleported: bool = false:
	set(value):
		just_teleported = value
		if not is_inside_tree():
			await tree_entered
		if just_teleported:
			await get_tree().create_timer(0.5).timeout
			just_teleported = false

@onready var display_name_label: Label = $DisplayNameLabel


func _init() -> void:
	sync_state = {"T" = 0.0}
	add_to_group("PLAYER")


func _ready() -> void:
	super()
	# Check if character sprite frames have directional animations
	if animated_sprite.sprite_frames:
		var has_directional = false
		for anim_name in ["idle_up", "idle_down", "idle_left", "idle_right", "run_up", "run_down", "run_left", "run_right"]:
			if animated_sprite.sprite_frames.has_animation(anim_name):
				has_directional = true
				break
		
		use_directional_animations = has_directional


func _set_character_class(new_class: String):
	character_resource = ResourceLoader.load(
		"res://source/common/resources/custom/character/character_collection/" + new_class + ".tres")
	animated_sprite.sprite_frames = character_resource.character_sprite
	character_class = new_class
	
	# Check if new sprite frames have directional animations
	if animated_sprite.sprite_frames:
		var has_directional = false
		for anim_name in ["idle_up", "idle_down", "idle_left", "idle_right", "run_up", "run_down", "run_left", "run_right"]:
			if animated_sprite.sprite_frames.has_animation(anim_name):
				has_directional = true
				break
		
		use_directional_animations = has_directional


func _set_display_name(new_name: String) -> void:
	display_name_label.text = new_name
	display_name = new_name


func _set_sync_state(new_state: Dictionary) -> void:
	sync_state = new_state
	for property: String in new_state:
		set(property, new_state[property])
