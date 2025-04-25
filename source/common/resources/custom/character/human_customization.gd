class_name HumanCustomization
extends Resource

enum Gender { MALE, FEMALE }
enum Age { CHILD, TEEN, ADULT }

@export var gender: Gender = Gender.MALE
@export var age: Age = Age.TEEN

# Generate a unique path for sprite loading based on customization
func get_sprite_path(animation_name: String) -> String:
    var gender_str = "male" if gender == Gender.MALE else "female"
    var age_str = "adult"
    
    match age:
        Age.CHILD: age_str = "child"
        Age.TEEN: age_str = "teen"
        Age.ADULT: age_str = "adult"
    
    # This would be the base path for finding sprites
    # You would need to organize your sprites accordingly
    return "res://assets/sprites/characters/human/%s_%s/%s.png" % [gender_str, age_str, animation_name]

# Get a custom SpriteFrames resource based on the customization options
func get_sprite_frames() -> SpriteFrames:
    # For now, just return the base human sprite frames
    # In a full implementation, you would dynamically create sprite frames based on customization
    return load("res://source/common/resources/builtin/sprite_frames/human.tres") 