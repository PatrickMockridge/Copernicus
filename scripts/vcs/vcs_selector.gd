# vcs_selector.gd
# UI for selecting which version-control backend to use.

class_name VcsSelector
extends BaseSelector

signal backend_selected(backend_id: String)

# Preload backends so their _static_init registers them with ModuleRegistry.
const GitVcs = preload("res://scripts/vcs/git_vcs.gd")
const AriadneVcs = preload("res://scripts/vcs/ariadne_vcs.gd")


func _get_title() -> String:
	return "Select Version Control"


func _get_info_text() -> String:
	return "Git works with GitHub, GitLab, or any git remote. Ariadne is decentralized git on Arweave."


func _get_button_group_name() -> String:
	return "vcs_backend"


func _get_apply_text() -> String:
	return "Use Backend"


func _get_category() -> String:
	return "vcs"


func _on_apply_pressed() -> void:
	backend_selected.emit(_selected_id)
	queue_free()


static func create_backend(backend_id: String, config: Dictionary = {}) -> VcsBackend:
	return ModuleRegistry.create("vcs", backend_id, config)
