extends Control

const MAP_SCENE := "res://scenes/map.tscn"
# Point this at the next scene once it exists; until then the button shows a notice.
const FUTURE_SCENE := "res://scenes/explorer_chart.tscn"

@onready var set_sail_button: Button = %SetSailButton
@onready var future_button: Button = %FutureButton
@onready var notice: Label = %Notice

func _ready() -> void:
	set_sail_button.pressed.connect(_open_scene.bind(MAP_SCENE))
	future_button.pressed.connect(_open_scene.bind(FUTURE_SCENE))
	set_sail_button.grab_focus()

func _open_scene(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		notice.text = "Those waters are not yet charted."
		return
	get_tree().change_scene_to_file(path)
