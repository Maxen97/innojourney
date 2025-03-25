extends Node

# Game state
var story_data = {}
var current_phase = 1
var current_step = 1
var resources = {
	"money": 1000,
	"time": 100,
	"mental_health": 100,
	"reputation": 50
}
var trl_level = 1

# UI node references
@onready var dialog_panel = $"../UI/DialogContainer/DialogPanel"
@onready var dialog_title = $"../UI/DialogContainer/DialogPanel/TitleLabel"
@onready var dialog_description = $"../UI/DialogContainer/DialogPanel/DescriptionLabel"
@onready var choice_panel = $"../UI/ChoiceContainer/ChoicePanel"
@onready var choice_buttons = $"../UI/ChoiceContainer/ChoicePanel/ChoiceButtons"
@onready var feedback_panel = $"../UI/FeedbackPanel"
@onready var feedback_label = $"../UI/FeedbackPanel/FeedbackLabel"

# Header UI references
@onready var trl_label = $"../UI/HeaderPanel/TRLLabel"
@onready var phase_label = $"../UI/HeaderPanel/PhaseLabel"

# Resource UI references
@onready var money_label = $"../UI/ResourcePanel/ResourceContainer/MoneyContainer/MoneyLabel"
@onready var time_label = $"../UI/ResourcePanel/ResourceContainer/TimeContainer/TimeLabel"
@onready var mental_label = $"../UI/ResourcePanel/ResourceContainer/MentalContainer/MentalLabel"
@onready var reputation_label = $"../UI/ResourcePanel/ResourceContainer/ReputationContainer/ReputationLabel"

# Character display
@onready var character_sprite = $"../UI/CharacterDisplay/CharacterSprite"

func _ready():
	# Load story data from JSON file
	load_story_data()
	
	# Initialize resource display
	update_resource_display()
	
	# Initialize TRL and phase display
	update_trl_display()
	
	# Create close button for feedback panel
	setup_feedback_panel()
	
	# Start the first phase
	start_phase(1)

func setup_feedback_panel():
	# Create close button for feedback panel
	var close_button = Button.new()
	
	# Set button properties
	close_button.text = "X"
	close_button.size = Vector2(30, 30)
	close_button.position = Vector2(feedback_panel.size.x - 35, 5)  # Position in top-right corner
	close_button.focus_mode = Control.FOCUS_NONE  # Don't focus button automatically
	
	# Style the button
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.7, 0.2, 0.2)  # Red background
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	close_button.add_theme_stylebox_override("normal", button_style)
	
	# Connect signal
	close_button.pressed.connect(Callable(self, "_on_feedback_close_button_pressed"))
	
	# Add to feedback panel
	feedback_panel.add_child(close_button)
	
	# Ensure feedback panel is hidden initially
	feedback_panel.visible = false

func _on_feedback_close_button_pressed():
	# Hide the feedback panel when the close button is pressed
	feedback_panel.visible = false

func load_story_data():
	var file = FileAccess.open("res://data/story_data.json", FileAccess.READ)
	
	if file:
		var file_text = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(file_text)

		if parse_result == OK:
			story_data = json.data
		else:
			print("Error parsing story data: ", json.get_error_message())
	else:
		print("Error opening story data file.")


func start_phase(phase_id):
	current_phase = phase_id
	current_step = 1
	
	# Update phase display
	var phase_data = story_data["phases"][str(phase_id)]
	phase_label.text = "Phase " + str(phase_id) + ": " + phase_data["name"]
	
	# Show the first step in this phase
	show_dialog_step()

func show_dialog_step():
	# Get the current step data
	var step_data = story_data["phases"][str(current_phase)]["steps"][str(current_step)]
	
	# Update dialog content
	dialog_title.text = step_data["title"]
	dialog_description.text = step_data["description"]
	
	# Update character sprite if available
	if step_data.has("character_image"):
		var character_texture = load(step_data["character_image"])
		if character_texture:
			character_sprite.texture = character_texture
			character_sprite.scale = Vector2(1, 1)
	
	# Clear previous choices
	for child in choice_buttons.get_children():
		child.queue_free()
	
	# Add new choices
	for i in range(step_data["choices"].size()):
		var choice = step_data["choices"][i]
		var button = Button.new()
		button.text = choice["text"]
		button.pressed.connect(Callable(self, "_on_choice_made").bind(i))
		choice_buttons.add_child(button)
	
	# Make sure panels are visible
	dialog_panel.position.x = 0
	choice_panel.position.x = 0
	dialog_panel.visible = true
	choice_panel.visible = true

func _on_choice_made(choice_index):
	# Get the current step data and choice
	var step_data = story_data["phases"][str(current_phase)]["steps"][str(current_step)]
	var choice = step_data["choices"][choice_index]
	
	if choice["is_correct"]:
		# Apply resource changes if any
		if choice.has("resource_changes"):
			for resource in choice["resource_changes"]:
				if resources.has(resource):
					resources[resource] += choice["resource_changes"][resource]
			update_resource_display()
		
		# Progress to next step or phase
		progress_story(choice)
	else:
		# Show feedback for incorrect choice
		show_feedback(choice["feedback"])

func progress_story(choice):
	# Progress to next step or phase
	if choice.has("next_step"):
		if choice["next_step"] == "milestone":
			show_milestone_complete()
		else:
			current_step = int(choice["next_step"])
			show_dialog_step()
	else:
		# Default to next sequential step
		current_step += 1
		show_dialog_step()

func show_feedback(text):
	feedback_label.text = text
	feedback_panel.visible = true


func show_milestone_complete():
	# Simple milestone completion for MVP
	var phase_data = story_data["phases"][str(current_phase)]
	
	# Update TRL level if needed
	if phase_data["trl_level"] > trl_level:
		trl_level = phase_data["trl_level"]
		update_trl_display()
	
	# Show completion message
	var dialog = AcceptDialog.new()
	dialog.title = "Milestone Complete!"
	dialog.dialog_text = "You've completed Phase " + str(current_phase) + ": " + phase_data["name"] + "\n\n" + phase_data["ending_milestone"]
	add_child(dialog)
	dialog.popup_centered()
	
	# Connect to close event
	dialog.confirmed.connect(Callable(self, "_on_milestone_dialog_closed"))


func _on_milestone_dialog_closed():
	# Move to next phase or end game
	if story_data["phases"].has(str(current_phase + 1)):
		start_phase(current_phase + 1)
	else:
		show_game_complete()

func show_game_complete():
	# Simple game completion for MVP
	var dialog = AcceptDialog.new()
	dialog.title = "Game Complete!"
	dialog.dialog_text = "Congratulations! You've successfully developed the " + story_data["invention"]["name"] + " and made a significant contribution to " + story_data["invention"]["sdg"] + "!"
	add_child(dialog)
	dialog.popup_centered()
	
	# Connect to close event
	dialog.confirmed.connect(Callable(self, "_on_game_complete_dialog_closed"))


func _on_game_complete_dialog_closed():
	# Restart game
	get_tree().reload_current_scene()

func update_resource_display():
	money_label.text = str(resources["money"])
	time_label.text = str(resources["time"])
	mental_label.text = str(resources["mental_health"]) + "%"
	reputation_label.text = str(resources["reputation"])

func update_trl_display():
	trl_label.text = "TRL Level: " + str(trl_level)
