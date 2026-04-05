# roblox_ai.gd
# GameAI + Roblox-Style In-Game Coding Integration
# AI-powered code generation for game development directly in-game

class_name RobloxAI

## RobloxAI - In-Game Code Generation
##
## Like Roblox's scripting system, but with AI assistance.
## Players can write code for their game objects, NPCs, tools, and mechanics.
## AI helps generate, explain, and debug code in real-time.
##
## Usage:
## var rb_ai = RobloxAI.new()
## rb_ai.set_ai(GameAI)
## var code = await rb_ai.generate_game_script("a sword that glows when enemies are near")

var _ai: Node = null
var _current_project: Dictionary = {}


func set_ai(ai_node: Node) -> void:
	_ai = ai_node


func set_game_project(project_data: Dictionary) -> void:
	# Set the current game project context
	# project_data: { "name": "...", "objects": [...], "scripts": [...] }
	_current_project = project_data


# === Script Generation for Game Objects ===

async func generate_object_script(object_type: String, behavior: String, params: Dictionary = {}) -> Result:
	# Generate a script for a specific game object type
	# object_type: "part", "npc", "tool", "gui", "vehicle", "building"
	# behavior: What the object should do

	var system_prompt = """You are an expert Roblox Studio / GDScript game developer.

Generate a script for a game object that will be added to a Godot 4 project.

Object Type: %s
Desired Behavior: %s

The script should:
1. Be a GDScript class extending the appropriate Godot node (Node, Node3D, Area3D, CharacterBody3D, etc.)
2. Handle the object's lifecycle (_ready, _process, etc.)
3. Respond to relevant signals (body_entered, input, etc.)
4. Implement the desired behavior

Consider:
- Use @export for editor-exposed properties
- Use signals for communication between objects
- Handle cleanup in _exit_tree
- Be mindful of performance

Return ONLY GDScript code, no explanations.""" % [object_type, behavior]

	var prompt = "Generate %s script for: %s" % [object_type, behavior]
	if params.size() > 0:
		prompt += "\nParameters: %s" % str(params)

	if _ai:
		return await _ai.chat_system(system_prompt, prompt)
	return Result.err({"code": -1, "message": "AI not configured"})


async func generate_npc_script(npc_type: String, personality: String) -> Result:
	# Generate NPC behavior script
	var prompt = """Create a GDScript NPC (Non-Player Character) for Godot 4.

NPC Type: %s
Personality: %s

The script should:
1. Extend CharacterBody3D or a custom NPC class
2. Have state machine for behaviors (idle, walk, talk, attack, flee, etc.)
3. React to player proximity
4. Use NavigationServer3D for pathfinding
5. Have dialogue system if applicable

Include:
- State transitions
- Animation handling
- Player interaction (dialogue, quest giving, trading)
- Basic AI decision making

Return ONLY GDScript code.""" % [npc_type, personality]

	if _ai:
		return await _ai.chat_system("You are an expert GDScript NPC programmer.", prompt)
	return Result.err({"code": -1, "message": "AI not configured"})


async func generate_tool_script(tool_name: String, tool_type: String) -> Result:
	# Generate equippable tool/weapon script
	var prompt = """Create a GDScript tool/weapon for Godot 4.

Tool Name: %s
Tool Type: %s

Tool types:
- sword: Melee weapon with slash attack
- bow: Ranged weapon with projectiles
- staff: Magic weapon with spells
- shield: Defensive equipment
- potion: Consumable with effect
- key: Opens doors/chests
- flashlight: Illumination tool

The script should:
1. Extend the appropriate class (Area3D for sword hitbox, Node3D for projectiles, etc.)
2. Handle equip/unequip states
3. Process input for activation
4. Create visual/audio effects
5. Apply damage or buffs to targets

Return ONLY GDScript code.""" % [tool_name, tool_type]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


async func generate_gui_script(gui_type: String, purpose: String) -> Result:
	# Generate UI/GUI script
	var prompt = """Create a GDScript for a Godot 4 UI element.

GUI Type: %s
Purpose: %s

GUI types include:
- health_bar: Shows player/enemy health
- inventory_grid: Item grid with drag-drop
- dialogue_box: NPC conversation interface
- shop_ui: Buy/sell interface
- quest_log: Track objectives
- minimap: World navigation
- pause_menu: Game pause overlay
- chat_box: Multiplayer text chat

The script should:
1. Use Control nodes properly (anchor, margin, size_flags)
2. Handle user interaction (button press, drag, scroll)
3. Update visuals based on game state
4. Emit signals for game events
5. Handle showing/hiding

Return ONLY GDScript code.""" % [gui_type, purpose]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


async func generate_vehicle_script(vehicle_type: String) -> Result:
	# Generate vehicle controller script
	var prompt = """Create a GDScript vehicle controller for Godot 4.

Vehicle Type: %s

Vehicle types:
- car: 4-wheel ground vehicle
- motorcycle: 2-wheel vehicle
- boat: Water vehicle
- plane: Flying vehicle
- helicopter: VTOL aircraft
- submarine: Underwater vehicle

The script should:
1. Extend VehicleBody3D or CharacterBody3D
2. Handle acceleration, braking, steering
3. Use physics for realistic movement
4. Include camera follow system
5. Handle damage/crashing
6. Support multiple control schemes

Return ONLY GDScript code.""" % vehicle_type

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


async func generate_building_script(building_type: String) -> Result:
	# Generate building/structure script
	var prompt = """Create a GDScript for a placeable building/structure in Godot 4.

Building Type: %s

The script should:
1. Handle placement mode (snapping, rotation)
2. Validate placement (not intersecting, on ground)
3. Support building progression/upgrading
4. Provide functionality (storage, production, defense)
5. Handle destruction if applicable

Return ONLY GDScript code.""" % building_type

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Game Mechanics ===

async func generate_mechanic(mechanic_type: String, description: String) -> Result:
	# Generate a complete game mechanic
	var prompt = """Create a complete game mechanic in GDScript for Godot 4.

Mechanic: %s
Description: %s

Examples of mechanics:
- grapple_hook: Swing between points
- double_jump: Extra jump mid-air
- time_slow: Bullet-time ability
- stealth_kill: Silent takedown
- crafting: Combine materials
- permadeath: One-life mode

The script should:
1. Be a self-contained module
2. Handle all states of the mechanic
3. Include player input
4. Provide visual/audio feedback
5. Be reusable and configurable

Return ONLY GDScript code.""" % [mechanic_type, description]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


async func generate_puzzle(puzzle_type: String) -> Result:
	# Generate puzzle logic
	var prompt = """Create a GDScript puzzle for Godot 4.

Puzzle Type: %s

Puzzle types:
- pressure_plate: Step on plates in sequence
- laser_grid: Redirect lasers to target
- color_match: Match colors in sequence
- slide_puzzle: Slide tiles to complete image
- riddle_door: Answer question to proceed
- statue_rotation: Rotate statues to pattern

The script should:
1. Detect player interaction
2. Track puzzle state
3. Check win condition
4. Handle hints or reveals
5. Emit signal when solved

Return ONLY GDScript code.""" % puzzle_type

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Multiplayer Scripts ===

async func generate_multiplayer_script(feature: String) -> Result:
	# Generate multiplayer-related script
	var prompt = """Create a GDScript for multiplayer functionality in Godot 4.

Feature: %s

Multiplayer features:
- player_spawn: Spawn player at join
- chat_system: In-game text chat
- trade_system: Player-to-player trading
- party_system: Group up players
- leaderboard: Score tracking
- sync_state: Synchronize game state
- respawn_system: Handle player death/respawn

The script should:
1. Use Godot's multiplayer API (ENet, WebRTC)
2. Handle peer connections
3. Sync necessary state across clients
4. Validate actions server-side when needed
5. Handle player join/leave gracefully

Return ONLY GDScript code.""" % feature

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Code Modification ===

async func modify_script(existing_code: String, change_request: String) -> Result:
	# Modify existing script based on request
	var prompt = """Modify this GDScript code:

```
%s
```

Change Request: %s

Apply ONLY the requested change. Keep everything else the same.

Return the complete modified code.""" % [existing_code, change_request]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


async func add_feature_to_script(existing_code: String, new_feature: String) -> Result:
	# Add a feature to existing script
	var prompt = """Add this feature to the GDScript code:

Feature: %s

Original Code:
```
%s
```

Add the feature cleanly without breaking existing functionality.

Return the complete modified code.""" % [new_feature, existing_code]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Code Explanation & Debugging ===

async func explain_script(code: String) -> Result:
	# Explain what a script does
	var prompt = """Explain this GDScript code in simple terms:

```
%s
```

What does it do? How does it work? Is there anything that could be improved?""" % code

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


async func debug_script(code: String, error: String) -> Result:
	# Debug a script with error
	var prompt = """Debug this GDScript code. There's an error: %s

Code:
```
%s
```

What's wrong and how do you fix it?

Return the corrected code.""" % [error, code]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


async func optimize_script(code: String) -> Result:
	# Optimize script performance
	var prompt = """Optimize this GDScript code for better performance:

```
%s
```

Common optimizations:
- Use setget instead of _get/_set when possible
- Cache node references in _ready
- Use对象池 for frequently created/destroyed objects
- Avoid unnecessary allocations in _process
- Use int/bool literals instead of functions calls
- Prefer local variables over repeated property access

Return the optimized code with comments explaining changes.""" % code

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Complete Game Templates ===

async func generate_game_template(game_type: String) -> Dictionary:
	# Generate a complete mini-game template
	var result = {
		"success": false,
		"main_scene": "",
		"player": "",
		"objects": [],
		"ui": "",
		"errors": []
	}

	var prompt = """Generate a complete %s mini-game in GDScript for Godot 4.

The game should include:
1. Main scene script (game loop, win/lose conditions)
2. Player controller
3. Game objects (enemies, obstacles, items, etc.)
4. UI (score, health, menus)

Make it fully playable with clear instructions.

Return a JSON-like structure:
{
  "main_scene": "<!-- code for main scene -->",
  "player": "<!-- code for player -->",
  "objects": ["<!-- code for object1 -->", "<!-- code for object2 -->"],
  "ui": "<!-- code for UI -->"
}

Return ONLY the JSON structure, no markdown code blocks.""" % game_type

	if _ai:
		var response = await _ai.chat([{"role": "user", "content": prompt}])
		if response.is_ok():
			result.success = true
			# Parse the response and populate result
			# For now, just return the raw content
			result.main_scene = response.ok_value().content
		else:
			result.errors.append(response.err_value())
	return result


# === Tutorial Generation ===

async func generate_tutorial(tutorial_topic: String) -> Result:
	# Generate an interactive tutorial
	var prompt = """Create a tutorial for learning GDScript game development in Godot 4.

Topic: %s

The tutorial should:
1. Be suitable for beginners
2. Have clear step-by-step instructions
3. Include code examples
4. Explain concepts simply
5. Provide exercises to practice

Format as structured markdown with code blocks.""" % tutorial_topic

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})
