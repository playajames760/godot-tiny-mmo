extends GatewayUIComponent


@export var class_description: Label
@export var default_selection: CharacterClassButton

var selected_button: CharacterClassButton = null
var selected_character_class: CharacterResource = preload("res://source/common/resources/custom/character/character_collection/knight.tres")
var human_customization: HumanCustomization = null

@onready var class_selection_container: VBoxContainer = $CenterContainer/VBoxContainer/HBoxContainer/VBoxContainer
@onready var character_preview: AnimatedSprite2D = $CenterContainer/VBoxContainer/HBoxContainer/VBoxContainer2/CenterContainer/Control/AnimatedSprite2D
@onready var username_edit: LineEdit = $CenterContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HBoxContainer/LineEdit
@onready var create_character_button: Button = $CenterContainer/VBoxContainer/CreateCharacterButton
@onready var human_customization_panel: HumanCustomizationPanel = $CenterContainer/VBoxContainer/HBoxContainer/VBoxContainer2/HumanCustomizationPanel

@onready var result_message_label: Label = $CenterContainer/VBoxContainer/HBoxContainer/VBoxContainer2/ResultMessageLabel


func _ready() -> void:
	visibility_changed.connect(
		func():
			if visible:
				default_selection.grab_focus.call_deferred()
	)
	
	if default_selection:
		default_selection.apply_select_style()
		selected_button = default_selection
		selected_character_class = default_selection.character_class
	
	create_character_button.disabled = true
	update_character_preview()
	
	var buttons: Array[Button]
	buttons.assign(find_children("*", "CharacterClassButton", true))
	connect_character_class_buttons(buttons)
	ButtonUtils.set_focus_neighbors_for_buttons(buttons)
	
	# Connect human customization panel signals
	if human_customization_panel:
		human_customization_panel.customization_changed.connect(_on_human_customization_changed)
		human_customization_panel.hide()


func update_character_preview() -> void:
	character_preview.sprite_frames = selected_character_class.character_sprite
	character_preview.play(&"idle")
	class_description.text = "%s\n%s" % [
		selected_character_class.character_name,
		selected_character_class.description
	]
	
	# Show or hide customization panel based on character class
	if human_customization_panel:
		if selected_character_class.character_name == "Human":
			human_customization_panel.show()
			if not human_customization:
				human_customization = human_customization_panel.get_customization()
			update_human_preview()
		else:
			human_customization_panel.hide()
			human_customization = null


func connect_character_class_buttons(buttons: Array[Button]) -> void:
	for button: CharacterClassButton in buttons:
		button.pivot_offset = button.size / 2
		button.pressed.connect(_on_character_class_button_pressed.bind(button))
		button.mouse_entered.connect(button.grab_focus)
		button.focus_entered.connect(_animate_button.bind(button))
		button.focus_exited.connect(_reset_animation.bind(button))


func _on_character_class_button_pressed(button: CharacterClassButton) -> void:
	selected_character_class = button.character_class
	if selected_button:
		selected_button.remove_select_style()
	selected_button = button
	button.apply_select_style()
	update_character_preview()


func _on_human_customization_changed(customization: HumanCustomization) -> void:
	human_customization = customization
	
	# Update character preview based on customization
	if selected_character_class.character_name == "Human":
		update_human_preview()


func update_human_preview() -> void:
	if not human_customization:
		return
		
	# Create sprite path identifier based on gender and age
	var gender_str = "male" if human_customization.gender == 0 else "female"
	var age_str = "adult"
	
	match human_customization.age:
		0: age_str = "child"
		1: age_str = "teen"
		2: age_str = "adult"
	
	# Try to load the custom sprite frames
	var custom_sprite_frames_path = "res://source/common/resources/builtin/sprite_frames/human_%s_%s.tres" % [gender_str, age_str]
	
	if ResourceLoader.exists(custom_sprite_frames_path):
		character_preview.sprite_frames = ResourceLoader.load(custom_sprite_frames_path)
		character_preview.play(&"idle")
	else:
		# Fall back to default human sprites
		character_preview.sprite_frames = selected_character_class.character_sprite
		character_preview.play(&"idle")


func _animate_button(button: CharacterClassButton) -> void:
	var tween := create_tween()
	var target_scale := Vector2.ONE * 1.1
	
	tween.tween_property(button, "scale", target_scale, 0.15) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, 0.2) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	
	button.animated_sprite_2d.play(&"run")


func _reset_animation(button: CharacterClassButton) -> void:
	button.animated_sprite_2d.play(&"idle")


func generate_random_username() -> String:
	var characters := "abcdefghijklmnopqrstuvwxyz0123456789"
	var username := ""
	for i in range(8):
		username += characters[randi() % len(characters)]
	return username


func _on_rng_button_pressed() -> void:
	username_edit.text = generate_random_username()
	create_character_button.disabled = false


func _on_line_edit_text_changed(new_text: String) -> void:
	if (
		new_text.length() > 2
		and new_text.length() < 14
		#Banword check? (should be on server anyway)
		and not new_text.contains("guest")
	):
		create_character_button.disabled = false
	else:
		create_character_button.disabled = true


func _on_create_character_button_pressed() -> void:
	create_character_button.disabled = true
	gateway.player_character_creation_result_received.connect(
		func(result_code: int):
			var message := "Creation successful."
			if result_code < 0:
				message = GatewayClient.get_error_message(abs(result_code))
			result_message_label.text = message
			await get_tree().create_timer(0.5).timeout
			if result_code != OK:
				create_character_button.disabled = false,
		ConnectFlags.CONNECT_ONE_SHOT
	)
	
	var character_data = {
		"name": username_edit.text,
		"class": selected_character_class.character_name.to_lower()
	}
	
	# Add customization data for human characters
	if selected_character_class.character_name == "Human" and human_customization:
		character_data["customization"] = {
			"gender": human_customization.gender,
			"age": human_customization.age
		}
	
	gateway.create_player_character_request.rpc_id(
		1,
		character_data,
		gateway.world_id
	)
