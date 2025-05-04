class_name HumanCustomizationPanel
extends VBoxContainer

const HumanCustomizationClass = preload("res://source/common/resources/custom/character/human_customization.gd")

signal customization_changed(customization: HumanCustomizationClass)

var customization: HumanCustomizationClass = HumanCustomizationClass.new()

@onready var gender_buttons = {
	$GenderSection/GenderOptions/MaleButton: HumanCustomizationClass.Gender.MALE,
	$GenderSection/GenderOptions/FemaleButton: HumanCustomizationClass.Gender.FEMALE
}

@onready var age_buttons = {
	$AgeSection/AgeOptions/ChildButton: HumanCustomizationClass.Age.CHILD,
	$AgeSection/AgeOptions/TeenButton: HumanCustomizationClass.Age.TEEN,
	$AgeSection/AgeOptions/AdultButton: HumanCustomizationClass.Age.ADULT
}

func _ready() -> void:
	_connect_buttons(gender_buttons, _on_gender_button_toggled)
	_connect_buttons(age_buttons, _on_age_button_toggled)


func _connect_buttons(button_dict: Dictionary, callback: Callable) -> void:
	for button in button_dict.keys():
		button.toggled.connect(callback.bind(button))


func _unselect_buttons_except(button_dict: Dictionary, selected_button: Button) -> void:
	for button in button_dict.keys():
		if button != selected_button and button.button_pressed:
			button.button_pressed = false


func _on_gender_button_toggled(toggled_on: bool, button: Button) -> void:
	if toggled_on:
		_unselect_buttons_except(gender_buttons, button)
		customization.gender = gender_buttons[button]
		emit_signal("customization_changed", customization)


func _on_age_button_toggled(toggled_on: bool, button: Button) -> void:
	if toggled_on:
		_unselect_buttons_except(age_buttons, button)
		customization.age = age_buttons[button]
		emit_signal("customization_changed", customization)


func get_customization() -> HumanCustomizationClass:
	return customization 
