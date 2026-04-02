# character_ai.gd
# GameAI + Game Character Integration
# AI-powered NPCs, companions, and game characters

class_name CharacterAI

## CharacterAI - AI-Powered Game Characters
##
## Create intelligent NPCs, companions, and game characters with AI.
## Characters have personality, memory, goals, and can interact naturally.
##
## Usage:
## var char_ai = CharacterAI.new()
## char_ai.set_ai(GameAI)
## char_ai.create_character("companion", "A wise dragon who speaks in riddles")
## var response = await char_ai.talk_to("companion", "Hello, wise one")

var _ai: Node = null
var _characters: Dictionary = {}


func set_ai(ai_node: Node) -> void:
	_ai = ai_node


# === Character Management ===

func create_character(character_id: String, personality: String, lore: String = "") -> void:
	# Create a new AI character
	# character_id: Unique identifier
	# personality: Core personality description
	# lore: Background/backstory
	_characters[character_id] = {
		"personality": personality,
		"lore": lore,
		"memory": [],
		"goals": [],
		"relationships": {},
		"mood": "neutral",
		"state": "idle"
	}


func remove_character(character_id: String) -> void:
	_characters.erase(character_id)


func get_character(character_id: String) -> Dictionary:
	return _characters.get(character_id, {})


func set_character_mood(character_id: String, mood: String) -> void:
	if _characters.has(character_id):
		_characters[character_id].mood = mood


func set_character_state(character_id: String, state: String) -> void:
	if _characters.has(character_id):
		_characters[character_id].state = state


func add_memory(character_id: String, memory: String, importance: int = 5) -> void:
	# Add a memory to character's memory
	# importance: 1-10, higher = more important
	if _characters.has(character_id):
		_characters[character_id].memory.append({
			"text": memory,
			"importance": importance,
			"timestamp": Time.get_unix_time()
		})


func set_goal(character_id: String, goal: String, priority: int = 5) -> void:
	# Set a goal for character
	# priority: 1-10, higher = more urgent
	if _characters.has(character_id):
		_characters[character_id].goals.append({
			"text": goal,
			"priority": priority,
			"completed": false
		})


# === Conversation ===

func talk_to(character_id: String, player_message: String) -> Result:
	# Have a conversation with a character
	if not _characters.has(character_id):
		return Result.err({"code": -1, "message": "Character not found: " + character_id})

	var char = _characters[character_id]

	# Build system prompt with personality and memory
	var system_prompt = _build_character_prompt(char)

	# Add recent conversation to context
	var context = _build_conversation_context(character_id)

	var full_prompt = context + "\n\nPlayer says: " + player_message

	if _ai:
		var result = await _ai.chat_system(system_prompt, full_prompt)
		if result.is_ok():
			# Save to conversation history
			_add_to_history(character_id, "player", player_message)
			_add_to_history(character_id, "character", result.ok_value().content)
		return result

	return Result.err({"code": -1, "message": "AI not configured"})


func _build_character_prompt(char: Dictionary) -> String:
	var prompt = "You are a game character.\n\n"
	prompt += "PERSONALITY: " + char.personality + "\n\n"

	if char.lore != "":
		prompt += "BACKGROUND: " + char.lore + "\n\n"

	prompt += "CURRENT MOOD: " + char.get("mood", "neutral") + "\n"
	prompt += "CURRENT STATE: " + char.get("state", "idle") + "\n\n"

	# Add important memories
	var important_memories = char.get("memory", []).filter(func(m): return m.importance >= 7)
	if important_memories.size() > 0:
		prompt += "IMPORTANT MEMORIES:\n"
		for m in important_memories:
			prompt += "- " + m.text + "\n"
		prompt += "\n"

	# Add current goals
	var active_goals = char.get("goals", []).filter(func(g): return not g.completed)
	if active_goals.size() > 0:
		prompt += "CURRENT GOALS:\n"
		for g in active_goals:
			prompt += "- " + g.text + " (priority: " + str(g.priority) + ")\n"
		prompt += "\n"

	prompt += "Respond as your character would. Stay in character. Be natural and engaging."
	return prompt


func _build_conversation_context(character_id: String) -> String:
	var char = _characters[character_id]
	var history = char.get("history", [])
	if history.size() == 0:
		return ""

	var context = "CONVERSATION HISTORY:\n"
	var recent = history.slice(-6, history.size())  # Last 3 exchanges
	for msg in recent:
		if msg.role == "player":
			context += "Player: " + msg.content + "\n"
		else:
			context += "You: " + msg.content + "\n"
	return context


func _add_to_history(character_id: String, role: String, content: String) -> void:
	if _characters.has(character_id):
		if not _characters[character_id].has("history"):
			_characters[character_id].history = []
		_characters[character_id].history.append({
			"role": role,
			"content": content,
			"timestamp": Time.get_unix_time()
		})


# === Character Types ===

func create_companion(character_id: String, name: String, personality: String, expertise: Array) -> void:
	# Create an AI companion character
	var full_personality = "%s. You are a helpful companion who specializes in: %s. You provide advice, hints, and assistance to the player." % [personality, ", ".join(expertise)]
	create_character(character_id, full_personality)
	_characters[character_id].type = "companion"
	_characters[character_id].name = name
	_characters[character_id].expertise = expertise


func create_enemy(character_id: String, name: String, personality: String, difficulty: String) -> void:
	# Create an enemy character
	var full_personality = "%s. You are an enemy in combat. Difficulty: %s. Be challenging but fair." % [personality, difficulty]
	create_character(character_id, full_personality)
	_characters[character_id].type = "enemy"
	_characters[character_id].name = name
	_characters[character_id].difficulty = difficulty


func create_merchant(character_id: String, name: String, inventory: Array, specialties: Array) -> void:
	# Create a merchant/vendor character
	var full_personality = "You are a merchant named %s. You sell: %s. Your specialties are: %s. Be friendly but shrewd in negotiations." % [name, ", ".join(inventory), ", ".join(specialties)]
	create_character(character_id, full_personality)
	_characters[character_id].type = "merchant"
	_characters[character_id].name = name


func create_guard(character_id: String, faction: String, personality: String) -> void:
	# Create a guard/npc character
	var full_personality = "You are a guard from the %s faction. %s. You are vigilant and take your duties seriously. You interact with those who approach your post." % [faction, personality]
	create_character(character_id, full_personality)
	_characters[character_id].type = "guard"
	_characters[character_id].faction = faction


# === Combat Dialogue ===

func combat_dialogue(character_id: String, player_action: String) -> Result:
	# Get character response during combat
	if not _characters.has(character_id):
		return Result.err({"code": -1, "message": "Character not found"})

	var char = _characters[character_id]

	var prompt = """You are in COMBAT!

Your character: %s
Personality: %s
Player's action: %s

Generate a combat response:
- A taunt, battle cry, or combat quip
- Something your character would say during fight
- Keep it short (1-3 sentences)

Return ONLY the dialogue text.""" % [char.get("name", "Enemy"), char.personality, player_action]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


func generate_attack_description(character_id: String, attack_name: String) -> Result:
	# Generate flavor text for an attack
	var prompt = """Generate a dramatic description of a combat attack.

Attacker: %s
Attack Name: %s

Write 1-2 exciting sentences describing the attack visually. Be vivid but concise.

Return ONLY the description.""" % [character_id, attack_name]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Quest Generation ===

func generate_quest_dialogue(quest_giver_id: String, quest_type: String) -> Result:
	# Generate quest-offering dialogue
	if not _characters.has(quest_giver_id):
		return Result.err({"code": -1, "message": "Character not found"})

	var char = _characters[quest_giver_id]

	var prompt = """You are a quest giver in a game.

Your character info:
Name: %s
Personality: %s

Quest Type: %s

Write dialogue that:
1. Sets up the situation/need
2. Explains what you want the player to do
3. Explains the reward
4. Fits your character's personality

Keep it to 3-5 sentences total.

Return ONLY the dialogue.""" % [char.get("name", "Quest Giver"), char.personality, quest_type]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


func evaluate_quest_result(quest_giver_id: String, player_result: String) -> Result:
	# Evaluate how quest completion went
	var prompt = """A player has completed a quest for you. Evaluate their result:

Quest result: %s

Respond as the quest giver would:
1. React to the result (positive, negative, mixed)
2. Provide appropriate reward or consequences
3. Set up future hooks if applicable

Keep it to 2-4 sentences.

Return ONLY your response.""" % player_result

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Event Reactions ===

func react_to_event(character_id: String, event: String) -> Result:
	# Character reacts to in-game event
	if not _characters.has(character_id):
		return Result.err({"code": -1, "message": "Character not found"})

	var char = _characters[character_id]

	var prompt = """Something happened in the game:

Event: %s

Your character: %s
Personality: %s
Current mood: %s

React naturally to this event. What would your character say or do?

Return a brief reaction (1-3 sentences).""" % [event, char.get("name", ""), char.personality, char.get("mood", "neutral")]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


func react_to_player_action(character_id: String, action: String) -> Result:
	# Character reacts to player's action
	if not _characters.has(character_id):
		return Result.err({"code": -1, "message": "Character not found"})

	var char = _characters[character_id]

	var prompt = """The player did something:

Action: %s

Your character: %s
Personality: %s

React to this action. Be in character. Positive actions might get gratitude, negative actions might get anger or disappointment.

Return a brief reaction (1-2 sentences).""" % [action, char.get("name", ""), char.personality]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === World Knowledge ===

func character_knows(character_id: String, topic: String) -> bool:
	# Check if character would know about a topic based on personality/lore
	if not _characters.has(character_id):
		return false

	var char = _characters[character_id]
	# Simple check - in a real system, this would be more sophisticated
	var expertise = char.get("expertise", [])
	for exp in expertise:
		if topic.to_lower() in exp.to_lower():
			return true

	# Check memory for related topics
	var memory = char.get("memory", [])
	for m in memory:
		if topic.to_lower() in m.text.to_lower():
			return true

	return false


func ask_about_lore(character_id: String, lore_topic: String) -> Result:
	# Character shares lore about a topic
	if not _characters.has(character_id):
		return Result.err({"code": -1, "message": "Character not found"})

	var char = _characters[character_id]

	var prompt = """Share some lore or knowledge about: %s

Your character: %s
Personality: %s

Tell a brief story or share knowledge as your character would. Be engaging and mysterious if it fits.

Keep it to 2-4 sentences.

Return ONLY the lore text.""" % [lore_topic, char.get("name", ""), char.personality]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Ambient Behavior ===

func generate_ambient_action(character_id: String) -> Result:
	# Generate what character does when idle
	if not _characters.has(character_id):
		return Result.err({"code": -1, "message": "Character not found"})

	var char = _characters[character_id]

	var prompt = """The player is not interacting with you right now.

Your character: %s
Personality: %s
Current state: %s
Current mood: %s

What are you doing while idle? Describe a brief ambient action or behavior.

Keep it to 1-2 sentences. Return ONLY the action description.""" % [char.get("name", ""), char.personality, char.get("state", "idle"), char.get("mood", "neutral")]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


func should_initiate_interaction(character_id: String, player_context: String) -> Result:
	# Decide if character should start a conversation
	if not _characters.has(character_id):
		return Result.err({"code": -1, "message": "Character not found"})

	var char = _characters[character_id]

	var prompt = """Should your character start a conversation with the player?

Player context: %s
Your character: %s
Your personality: %s
Your current mood: %s
Your goals: %s

Decide if you have something important to say. Only initiate if truly meaningful.

Respond with either:
- "Yes: [what you want to say]"
- "No"

Return ONLY your decision.""" % [player_context, char.get("name", ""), char.personality, char.get("mood", "neutral"), str(char.get("goals", []))]

	if _ai:
		return await _ai.chat([{"role": "user", "content": prompt}])
	return Result.err({"code": -1, "message": "AI not configured"})


# === Complete Character Generation ===

func generate_full_character(character_type: String, name: String, template: String = "") -> Dictionary:
	# Generate a complete character with backstory, personality, and behavior
	var result = {
		"success": false,
		"name": name,
		"type": character_type,
		"personality": "",
		"lore": "",
		"dialogue_style": "",
		"goals": [],
		"errors": []
	}

	var prompt = """Create a complete game character profile:

Character Type: %s
Name: %s
%s

Provide a JSON structure with:
- personality: Core personality traits
- lore: Backstory (2-3 sentences)
- dialogue_style: How they speak
- goals: Array of 3 possible goals
- secrets: Array of 2 hidden secrets

Return ONLY the JSON.""" % [character_type, name, template]

	if _ai:
		var response = await _ai.chat([{"role": "user", "content": prompt}])
		if response.is_ok():
			result.success = true
			# Parse and populate - simplified for now
			result.personality = "Generated personality"
			result.lore = "Generated lore"
		else:
			result.errors.append(response.err_value())

	return result
