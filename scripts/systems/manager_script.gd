extends Node2D

@onready var skeleton_scene = preload("res://scenes/actors/enemy/skeleton.tscn")
@onready var slime_scene = preload("res://scenes/actors/enemy/slime.tscn")
@onready var sandbag_scene = preload("res://scenes/actors/enemy/sandbag.tscn")
@onready var coin_scene = preload("res://scenes/props/coin.tscn")
@onready var switcheroo_scene = preload("res://scenes/items/switcheroo.tscn")
@onready var win_screen = $WinScreen
@onready var pause_screen = $PauseScreen
@onready var spawn_points = $SpawnPoints.get_children()
@onready var transfer_points = $TransferPoints.get_children()
@onready var blocks = get_tree().get_nodes_in_group("blocks")


# settings
var spawn_on_start: bool = false
var spawn_interval: float = 7.0
var spawn_active: bool = true # press escape to toggle skeletons spawning for debug purposes

var skeleton_count: int = 0
var skeleton_group: Array[CharacterBody2D] = []

var slime_count: int = 0
var slime_group: Array[CharacterBody2D] = []

var sandbag_count: int = 0
var sandbag_group: Array[CharacterBody2D] = []

var block_count = 0
var total_enemy_count = 0

# game state
var game_over: bool = false


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

	connect_signals()

	# grumpy bumpy start of game
	block_count = blocks.size()

	if blocks.size() > 0:
		var index: int = randi_range(0, blocks.size() - 1)
		if blocks[index].has_method("set_grumpy"):
			blocks[index].set_grumpy(blocks)

	if spawn_on_start:
		spawn_skeleton()
		spawn_slime()
		spawn_coin()
		spawn_switcheroo()

	if has_node("SpawnTimer"):
		var timer: Timer = $SpawnTimer
		timer.wait_time = spawn_interval
		timer.start()
	for s in spawn_points:
		if s.name != "SpawnPointRight" and s.name != "SpawnPointLeft":
			spawn_points.erase(s)

# -------------------------
# signal handling
# -------------------------


func _on_node_added(node: Node) -> void:
	if node.is_in_group("players") and node.has_signal("player_dead"):
		node.player_dead.connect(_on_player_dead)
	if node.is_in_group("item") and node.has_signal("item_picked_up"):
		print("item with item_picked_up added")
		node.item_picked_up.connect(_on_item_picked_up)


func connect_signals() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	var items: Array[Node] = get_tree().get_nodes_in_group("item")

#	PLAYERS
	for p: Node in players:
		if p.has_signal("player_dead"):
			if not p.player_dead.is_connected(_on_player_dead):
				p.player_dead.connect(_on_player_dead)
		if p.has_signal("coin_victory"):
			if not p.coin_victory.is_connected(_on_coin_victory):
				p.coin_victory.connect(_on_coin_victory)
#	ITEMS
	for i: RigidBody2D in items:
		if i.has_signal("item_picked_up"):
			i.item_picked_up.connect(_on_item_picked_up)
		

# -------------------------
# win conditions
# -------------------------


func _on_player_dead() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("coin")
	var alive_count: int = 0

	for p: Node in players:
		if is_instance_valid(p) and not p.is_dead:
			alive_count += 1
		if p.get_coin_count() >= 5 and not game_over:
			handle_game_over()
			#HEY THIS DOESNT TELL WHO WON YET YE YUPPIE

	if alive_count <= 1 and not game_over:
		handle_game_over()


func _on_coin_victory() -> void:
	handle_game_over()
	
func _on_item_picked_up(item_object: Node2D, player: Node2D) -> void:
	if item_object.name == "switcheroo":
		handle_switcheroo_picked_up()

# -------------------------
# spawn logic
# -------------------------


func spawn_skeleton() -> void:
	if spawn_points.is_empty() or not spawn_active or skeleton_count >= 3:
		return

	
	var point: Node2D = spawn_points.pick_random()
	var skeleton: CharacterBody2D = skeleton_scene.instantiate()

	skeleton.global_position = point.global_position

	add_child(skeleton)
	skeleton_count += 1
	total_enemy_count += 1
	skeleton_group.append(skeleton)

	# turn the sprite if going through the right transfer since default faces right
	if point.name == "SpawnPointRight":
		skeleton.direction = -1
		var sprite: AnimatedSprite2D = skeleton.get_node("AnimatedSprite2D")
		sprite.flip_h = true


func spawn_slime() -> void:
	if spawn_points.is_empty() or not spawn_active or slime_count >= 3:
		return
	
	total_enemy_count += 1
	var point: Node2D = spawn_points.pick_random()
	var slime: CharacterBody2D = slime_scene.instantiate()

	slime.global_position = point.global_position

	add_child(slime)
	slime_count += 1
	slime_group.append(slime)

	if point.name == "SpawnPointRight":
		slime.direction = -1
		var sprite: AnimatedSprite2D = slime.get_node("AnimatedSprite2D")
		sprite.flip_h = true


func spawn_coin() -> void:
	var point: Node2D = spawn_points.pick_random()
	var coin: RigidBody2D = coin_scene.instantiate()
	coin.global_position = point.global_position
	add_child(coin)

	if point.name == "SpawnPointRight":
		coin.flip_direction()
		
func spawn_switcheroo() -> void:
	var point: Node2D = spawn_points.pick_random()
	var switcheroo: RigidBody2D = switcheroo_scene.instantiate()
	switcheroo.global_position = switcheroo.global_position
	add_child(switcheroo)

	if point.name == "SpawnPointRight":
		switcheroo.flip_direction()

# -------------------------
# input
# -------------------------


func _input(event):
	#-----------------------------------------------------------------------
	#pause toggle
	#-----------------------------------------------------------------------
	if event.is_action_pressed("ui_cancel") and not game_over:
		get_tree().paused = !get_tree().paused
		pause_screen.visible = get_tree().paused
		get_viewport().set_input_as_handled()
		return
	#-----------------------------------------------------------------------
	#test spawn
	#-----------------------------------------------------------------------
	if event.is_action_pressed("test_spawn"): # press tab
		#spawn_skeleton()
		#spawn_slime()
		#spawn_coin()
		spawn_switcheroo()
	#-----------------------------------------------------------------------
	#spawn toggle
	#-----------------------------------------------------------------------
	if event.is_action_pressed("toggle_spawn"): # press escape
		spawn_active = !spawn_active
	#-----------------------------------------------------------------------
	#Kill all enemies
	#-----------------------------------------------------------------------
	if event.is_action_pressed("kill_all_enemies"): # press backspace
		for skeleton: CharacterBody2D in skeleton_group.duplicate():
			if is_instance_valid(skeleton):
				skeleton.queue_free()
		skeleton_group.clear()
		skeleton_count = 0
		for slime in slime_group.duplicate():
			if is_instance_valid(slime):
				slime.queue_free()
		slime_group.clear()
		slime_count = 0
	#-----------------------------------------------------------------------
	#Sandbag
	#-----------------------------------------------------------------------
	if event.is_action_pressed("sandbag"):
		if sandbag_count > 0:
			for bag in sandbag_group.duplicate():
				if is_instance_valid(bag):
					bag.queue_free()
					sandbag_group.clear()
					sandbag_count = 0
		print("sandbag")
		var sandbag = sandbag_scene.instantiate()
		var point = spawn_points.pick_random()
		sandbag.global_position = point.global_position
		add_child(sandbag)
		sandbag_count += 1
		sandbag_group.append(sandbag)
# -------------------------
# timer
# -------------------------


func _on_SpawnTimer_timeout() -> void:
	if total_enemy_count == 5:
		return
	else:
		pass
		#spawn_skeleton()
		#spawn_slime()
	
	print('total enemies: ', total_enemy_count)


func start_next_round() -> void:
	game_over = false
	get_tree().reload_current_scene()


func handle_game_over():
	game_over = true
	get_tree().paused = true
	win_screen.visible = true
	
func handle_switcheroo_picked_up():
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	var p1_position = players[0].global_position
	var p2_position = players[1].global_position
	players[0].global_position = p2_position
	players[1].global_position = p1_position
