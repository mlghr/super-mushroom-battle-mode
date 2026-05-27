extends CharacterBody2D

@onready var combo_timer = $ComboTimer
@onready var dash_timer = $DashTimer
@onready var combo_label = $ComboLabel
@onready var health_bar = $"../Player1Health"
@onready var coin_bar = $"../Player1Coins"


var speed = 80
var jump_velocity = -375
var jump_cut_multiplier = 0.6
const GRAVITY = 600
const NORMAL_CONTROL = 0.2
const SLIDE_CONTROL = 0.04
const PLAYER_BUMP_FORCE = 120.0
const PLAYER_BUMP_COOLDOWN = 0.15
const PLAYER_BUMP_SLIDE_TIME = 0.25

var bump_combo = 0
var standing_on_body = false
var death_played = false
var health = 3
var is_dead = false


var is_stunned = false
var is_crouching = false
var is_invincible = false
var has_dashed = false
var dash_cooldown = false
var bump_slide_time_left = 0.0
var last_player_bump_time = -10.0
var carried_velocity = Vector2.ZERO
var coin_count = 0
var color = "_Blue"

signal player_dead
signal coin_victory



func _physics_process(delta):
	if is_dead:
		handle_death()
		return

	# Apply carry from a player underneath us from the previous frame
	if carried_velocity != Vector2.ZERO:
		global_position += carried_velocity * delta
	carried_velocity = Vector2.ZERO
	standing_on_body = false

	apply_gravity(delta)
	if bump_slide_time_left > 0.0:
		bump_slide_time_left = max(0.0, bump_slide_time_left - delta)
	handle_input()
	handle_jump()
	handle_dash()
	check_has_dashed()
	handle_crouch()
	move_and_slide()
	handle_collisions()
	handle_screen_wrap()
	update_animation()

func _process(_delta):
	use_invincibility_flash()
	# keep wrap sprite in sync
	$WrapSprite.animation = $AnimatedSprite2D.animation
	$WrapSprite.frame = $AnimatedSprite2D.frame
	$WrapSprite.flip_h = $AnimatedSprite2D.flip_h


# -------------------------
# core systems, inputs, etc.
# -------------------------


func apply_gravity(delta):
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		#if velocity.y > 0:
			#velocity.y = (velocity.y * velocity.y) / (velocity.y * 1.03)
			#pass

	if is_on_floor() and velocity.y > 0:
		velocity.y = 0


func handle_input():
	var direction = Input.get_axis("move_left", "move_right")
	var control = NORMAL_CONTROL
	if bump_slide_time_left > 0.0:
		control = SLIDE_CONTROL

	if not is_stunned and not is_crouching:
		velocity.x = lerp(velocity.x, direction * speed, control)

		if direction < 0:
			$AnimatedSprite2D.flip_h = false
		elif direction > 0:
			$AnimatedSprite2D.flip_h = true
	elif is_stunned:
		#This block is causing stunned player to be able to DI, testing to see if its super coola
		velocity.x = lerp(velocity.x, direction * (speed/5), control)
	elif is_crouching and is_on_floor():
		velocity.x = lerp(velocity.x, 0.0, 0.05)


func handle_crouch():

	if (Input.is_action_just_pressed("crouch")) and is_on_floor() and not is_stunned:
		is_crouching = true
		$CollisionStanding.disabled = true
		$AnimatedSprite2D.play("Crouch")

	if (Input.is_action_just_released("crouch") or Input.is_action_just_released("Joystick_down")):
		is_crouching = false
		$CollisionStanding.disabled = false
		$AnimatedSprite2D.play("Stand")


func handle_jump():
	if (Input.is_action_just_pressed("jump")) and is_on_floor() and not is_stunned:
		velocity.y = jump_velocity
		$AudioStreamPlayer2D.play()

	if (Input.is_action_just_released("jump") and velocity.y < 0):
		velocity.y *= jump_cut_multiplier


func handle_dash():
	if ((Input.is_action_just_pressed("dash")) and not is_stunned and not has_dashed and not dash_cooldown) and not is_crouching or (bump_combo % 5 == 0 and bump_combo != 0 and Input.is_action_just_pressed("dash") and not dash_cooldown) :
		if velocity.x > 0:
			velocity.x = velocity.x + 125
		elif velocity.x < 0:
			velocity.x = velocity.x - 125
		has_dashed = true
		dash_cooldown = true
		dash_timer.start()
		$AudioStreamPlayer2D.play()

# -------------------------
# animation
# -------------------------

func use_invincibility_flash():
	if not is_invincible:
		modulate = Color.WHITE
		return

	if (Engine.get_process_frames() / 5) % 2 == 0:
		modulate = Color.DARK_GRAY
	else:
		modulate = Color.WHITE

func set_animation(animation_name: String, color: String):
	if $AnimatedSprite2D.animation != animation_name:
		$AnimatedSprite2D.play(animation_name + color)


func update_animation():
	#---------------------------------------------
	# Health updates
	if health > 2:
		health_bar.play("Player_One_Full")
	elif health > 1:
		health_bar.play("Player_One_Two_HP")
	elif health > 0:
		health_bar.play("Player_One_HP")
	else:
		health_bar.play("Player_One_Empty")
	
	#---------------------------------------------
	# Coin updates
	if coin_count > 4:
		coin_bar.play("Coins_Five")
	elif coin_count > 3:
		coin_bar.play("Coins_Four")
	elif coin_count > 2:
		coin_bar.play("Coins_Three")
	elif coin_count > 1:
		coin_bar.play("Coins_Two")
	elif coin_count > 0:
		coin_bar.play("Coins_One")
	else:
		coin_bar.play("Coins_Empty")
	
	
	
	if is_stunned:
		set_animation("Stun", color)
		return

	if is_crouching:
		set_animation("Crouch_Idle", color)
		return

	if abs(velocity.x) > speed - 15 and is_on_floor():
		set_animation("Run", color)
		return
	if not is_on_floor():
		set_animation("Airborn", color)
		return
	set_animation("Idle", color)


func handle_death():
	velocity = Vector2.ZERO
	move_and_slide()

	if not is_dead:
		is_dead = true
		$CollisionShape2D.disabled = true
		$AnimatedSprite2D.play("Die")
	health_bar.play("Player_One_Empty")
	player_dead.emit()

# -------------------------
# collisions
# -------------------------


func handle_collisions():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var other = collision.get_collider()
		var normal = collision.get_normal()

		# hit block from below
		if normal.y > 0.9:
			if other.has_method("bump"):
				other.bump(self)

		# enemy hit
		if other.is_in_group("enemy"):
			handle_damage()
			return

		# player interactions
		if other.is_in_group("player"):
			handle_push(collision, other)
			
func handle_damage():
	if is_dead or is_invincible:
		return
	health = health - 1
	print("Player 1 current health: ", health)
	handle_invincibility()
	#slowdown
	if health <= 0:
		is_dead = true

func handle_invincibility():
	set_collision_mask_value(2, false)
	print("inv started")
	is_invincible = true
	await get_tree().create_timer(2).timeout
	set_collision_mask_value(2, true)
	print("inv ended")
	is_invincible = false
	#flashing"

func handle_push(collision, other):
	var normal = collision.get_normal()
	var y_bounce_factor = -400
	var x_bounce_factor = 100

	# vertical stacking (standing on another player)
	if normal.y < -0.9:
		standing_on_body = true

		# Ride the player underneath like a moving platform.
		if abs(self.global_position.x - other.global_position.x) < 24:
			pass
			#carried_velocity.x = other.velocity.x
			if not other.is_on_floor:
				other.velocity.y = 100
				velocity.y = y_bounce_factor
			
			else :
				other.velocity.y = 100
				velocity.y = y_bounce_factor / 2
			if self.global_position.x > other.global_position.x:
				velocity.x = x_bounce_factor
			else: 
				velocity.x = x_bounce_factor * -1
			

		# If the bottom player jumps up into us, keep us attached so we don't "pin" them.
		if other.velocity.y < 0 and velocity.y >= 0:
			velocity.y = other.velocity.y
		return

	# Someone is standing on us: explicitly pass our motion up to them.
	if normal.y > 0.9:
		if other.has_method("receive_carrier_motion"):
			other.receive_carrier_motion(velocity, get_physics_process_delta_time())
		return

	# side push
	if abs(normal.x) > 0.9:
		if abs(global_position.y - other.global_position.y) < 10:
			var now = Time.get_ticks_msec() / 1000.0
			if now - last_player_bump_time < PLAYER_BUMP_COOLDOWN:
				return

			var push_dir = sign(global_position.x - other.global_position.x)
			if push_dir == 0:
				push_dir = sign(-normal.x)

			apply_player_bump(push_dir)
			if other.has_method("apply_player_bump"):
				other.apply_player_bump(-push_dir)


func apply_player_bump(push_dir):
	last_player_bump_time = Time.get_ticks_msec() / 1000.0
	bump_slide_time_left = PLAYER_BUMP_SLIDE_TIME
	velocity.x = push_dir * PLAYER_BUMP_FORCE

func check_has_dashed():
	if is_on_floor():
		has_dashed = false

func handle_bump_stun(bump_direction):
	
	if is_stunned:
		print("stunned, continuing combo")
		bump_combo += 1
		# keep combo going, reset timer
		combo_timer.start()
		
	else:
		print("stunned, starting combo")
		is_stunned = true
		bump_combo = 1
		# 1.5 sec
		combo_timer.start()
		
		
	velocity.y = -180
	velocity.x = 0
	print(bump_combo)
	if bump_direction == "left":
		velocity.x = -1 * (randi_range(100, 150))
	else:
		velocity.x = randi_range(100, 150)
	
	if bump_combo % 5 == 0:
		combo_label.add_theme_color_override("font_color", Color.RED)
		has_dashed = false
	else:
		combo_label.add_theme_color_override("font_color", Color.WHITE)
		
	combo_label.text = "Combo: " + str(bump_combo)
	$AnimatedSprite2D.play("Stun")


# -------------------------
# screen wrap, allows peeking
# -------------------------
func handle_screen_wrap():
	var left_bound = -128
	var right_bound = 128
	var width = right_bound - left_bound

	var sprite_width = 16

	# hide ghost by default
	$WrapSprite.visible = false

	# approaching left edge
	if global_position.x < left_bound + sprite_width:
		$WrapSprite.visible = true
		$WrapSprite.global_position = global_position
		$WrapSprite.global_position.x += width

	# approaching right edge
	elif global_position.x > right_bound - sprite_width:
		$WrapSprite.visible = true
		$WrapSprite.global_position = global_position
		$WrapSprite.global_position.x -= width

	# actual teleport (off-screen)
	if global_position.x < left_bound - sprite_width:
		global_position.x += width
	elif global_position.x > right_bound + sprite_width:
		global_position.x -= width


func increment_coin_count():
	coin_count += 1
	$AudioStreamCoin2D.play()
	if coin_count >= 5:
		update_animation()
		$AudioStreamCoin2D.play()
		await get_tree().create_timer(.4).timeout
		coin_victory.emit()


func get_coin_count() -> int:
	return coin_count


func _on_combo_timer_timeout() -> void:
	is_stunned = false
	bump_combo = 0
	combo_label.text = ""


func _on_dash_timer_timeout() -> void:
	dash_cooldown = false
