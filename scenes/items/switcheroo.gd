extends RigidBody2D 

var utility = Utility.new()

var speed = 75
const GRAVITY = 600

signal item_picked_up

# Called when the node enters the scene tree for the first time.
func _process(delta: float) -> void:
	$AnimatedSprite2D.play("default")
	pass


func _physics_process(delta):
	apply_gravity(delta)
	handle_screen_wrap()
	move()


func move():
	linear_velocity.x = speed


func update_animation():
	pass


func apply_gravity(delta):
	linear_velocity.y += GRAVITY * delta


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


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		print("player entered switcheroo, sending signal")
		item_picked_up.emit(self, body)
		utility.handle_item_picked_up(self)
	

func flip_direction():
	speed = linear_velocity.x * -1
	
