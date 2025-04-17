@tool
extends Node3D

@export
var boid_scene: PackedScene

@export 
var boid_count: int = 100

@export_tool_button("Initialize Boids", "Callable") 
var init_action = initialize_boids

@export 
var updates_enabled : bool = false:
	set(new_val):
		updates_enabled = new_val
		PhysicsServer3D.set_active(new_val)

@export 
var spawn_radius: float = 50.0

@export
var random_velocity_strength: float = 1.0

@export 
var separation_strength: float = 1.0

@export
var alignment_strength: float = 1.0

@export
var cohesion_strenth: float = 1.0

@export
var neighborhood_size: float = 20.0

var boids: Array[RigidBody3D] = []

var rng: RandomNumberGenerator

func _ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	if updates_enabled:
		update_boids_velocity(delta)

func initialize_boids():
	for boid in boids:
		boid.queue_free()
	boids.clear()
	
	rng = RandomNumberGenerator.new()
	assert(boid_scene != null, \
		"error in boid manager: boid scene is null!")
	for i in range(boid_count):
		var new_boid : RigidBody3D = boid_scene.instantiate()
		assert(new_boid != null, 
			"error in boid manager: the " + str(i) + "th boid is null!"
		)
		add_child(new_boid) # add to the scene tree
		boids.push_back(new_boid)
		var spawn_location = Vector3(
			rng.randf_range(-spawn_radius, spawn_radius),
			rng.randf_range(-spawn_radius, spawn_radius),
			rng.randf_range(-spawn_radius, spawn_radius)
		)
		new_boid.position = spawn_location
		new_boid.linear_velocity = Vector3(
			rng.randfn(),
			rng.randfn(),
			rng.randfn()
		).normalized() * random_velocity_strength
		
	

func update_boids_velocity(delta: float):
	# https://www.red3d.com/cwr/boids/
	var separation = Vector3.ZERO
	var alignment = Vector3.ZERO
	var cohesion = Vector3.ZERO
	
	for boid in boids:
		var neighbors = get_boids_in_neighborhood(boid)
		var CoM: Vector3 = get_center_of_mass(neighbors) # center of mass
		var to_CoM = (CoM - boid.position).normalized() # possible bug : local vs global coords
		var avg_direction: Vector3 = get_average_velocity(neighbors).normalized()
		# TODO: set separation: vector pointing away from CoM
		separation = -to_CoM
		# TODO: set alignment: vector pointing towards average orientation
		alignment = avg_direction
		# TODO: set cohesion: vector pointing towards CoM
		cohesion = to_CoM
		# TODO: set the velocity to the weighted sum of these vectors
		boid.linear_velocity = \
			separation * separation_strength \
			+ alignment * alignment_strength \
			+ cohesion * cohesion_strenth

func get_boids_in_neighborhood(original: Node3D) -> Array[RigidBody3D]:
	var neighbors: Array[RigidBody3D] = []
	for boid in boids:
		if boid == original: # skip itself
			continue 
		var distance = boid.position.distance_to(original.position)
		if distance <= neighborhood_size:
			neighbors.push_back(boid)
	return neighbors

func get_center_of_mass(neighborhood: Array[RigidBody3D]) -> Vector3:
	if neighborhood.size() == 0:
		return Vector3.ZERO
	var CoM = Vector3.ZERO
	for boid in neighborhood:
		CoM += boid.position # possible bug: global vs local coords
	CoM /= neighborhood.size()
	return CoM

func get_average_velocity(neighborhood: Array[RigidBody3D]) -> Vector3:
	if neighborhood.size() == 0:
		return Vector3.ZERO
	var average_velocity = Vector3.ZERO
	for boid in neighborhood:
		average_velocity += boid.linear_velocity
	average_velocity /= neighborhood.size()
	return average_velocity
