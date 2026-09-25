# Run: Godot --headless --path . --script res://tests/sailing_test.gd
extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func settle(game: Node) -> void:
	for i in 600:
		game._physics_process(1.0 / 60.0)
		if not game.busy:
			return
	assert(false, "Movement did not settle")

func run_checks() -> void:
	var world = load("res://scenes/map.tscn").instantiate()
	root.add_child(world)
	var game = world.sailing
	game.set_physics_process(false)
	assert(game.hull == 3 and game.hand.size() == 5 and game.draw_pile.size() == 11)
	# Sixteen plays cycle the entire deck; card identities must be conserved.
	for i in 16:
		game.end_turn()
		if game.hand.is_empty(): game.draw_turn_card()
		game.ship.position = Vector3(0.9, 0.04, 3.5)
		game.heading = 0.0
		for target in game.targets: target.health = 60
		game.play_card(0)
		var total: int = game.hand.size() + game.draw_pile.size() + game.discard_pile.size()
		assert(total == 16)
		settle(game)
	assert(game.hand.size() + game.draw_pile.size() + game.discard_pile.size() == 16)
	var all_cards: Array = game.hand + game.draw_pile + game.discard_pile
	for id in 5:
		assert(all_cards.count(id) == 2, "Reshuffle must preserve card identities")
	for id in range(5, 11):
		assert(all_cards.count(id) == 1, "Each cannon card must remain unique")
	game.end_turn()
	game.hand.assign([0, 1])
	game.play_card(0)
	var discard_before_locked_play: int = game.discard_pile.size()
	game.play_card(0)
	assert(game.discard_pile.size() == discard_before_locked_play, "Cannot play twice during movement")
	settle(game)
	# Each ammunition type deals its declared damage once, at visual contact.
	for id in range(5, 11):
		game.restart()
		game.hand.assign([id, 0])
		var target = game.find_target(game.CARDS[id].range)
		assert(target != null)
		var cannon_position: Vector3 = game.ship.position
		game.play_card(0)
		assert(game.busy and target.health == 60)
		game.play_card(0)
		assert(game.hand.size() == 1, "Firing locks further plays")
		settle(game)
		assert(target.health == 60 - game.CARDS[id].damage)
		assert(game.ship.position == cannon_position)
	# Out-of-range and blocked shots retain their card.
	game.restart()
	game.ship.position = Vector3(8, 0.04, 5)
	game.hand.assign([7])
	game.play_card(0)
	assert(game.hand.size() == 1 and not game.busy)
	for target in game.targets: target.health = 0
	game.targets[0].health = 60
	game.targets[0].position = Vector3(-3.8, 0.04, -3.5)
	game.ship.position = Vector3(-3.8, 0.04, 2.5)
	assert(game.find_target(10) == null, "Land blocks cannon fire")
	game.restart()
	var victim = game.targets[0]
	victim.health = 20
	game.hand.assign([6, 0])
	game.play_card(0)
	settle(game)
	assert(victim.health == 0)
	assert(game.find_target(6) != victim, "Sunk rafts cannot be targeted")
	# Restart in flight must cancel the pending hit and restore practice targets.
	game.hand.assign([6, 0])
	game.play_card(0)
	game.restart()
	assert(game.shot_effect == null and not game.busy)
	for target in game.targets:
		assert(target.health == 60)
		assert(world.geography.navigable(Vector2(target.position.x, target.position.z)))
	# Port and starboard turn in opposite directions relative to the bow.
	for id in [2, 3]:
		game.hand.assign([id])
		game.ship.position = Vector3(0.9, 0.04, 3.5)
		game.heading = 0.0
		game.play_card(0)
		settle(game)
		assert(game.ship.position.x < 0.9 if id == 2 else game.ship.position.x > 0.9)
	# Three separate crashes each remove one hull; long steps cannot tunnel.
	game.restart()
	for hit in 3:
		game.end_turn()
		game.ship.position = Vector3(-3.8, 0.04, 2.5)
		game.heading = 0.0
		game.hand.assign([1, 4])
		game.play_card(0)
		game._physics_process(5.0)
		assert(game.hull == 2 - hit, "Exactly one damage per collision")
		assert(world.shake_remaining > 0.0)
		var impact_z: float = game.ship.position.z
		settle(game)
		assert(game.ship.position.z > impact_z, "Collision pushes back")
		assert(world.geography.navigable(Vector2(game.ship.position.x, game.ship.position.z)))
	var hand_before: int = game.hand.size()
	game.play_card(0)
	assert(game.hand.size() == hand_before and not game.busy, "Defeat locks cards")
	game.wake.advance(4.0)
	assert(game.wake.samples.is_empty(), "Wake fades completely")
	game.restart()
	assert(game.hull == 3 and game.hand.size() == 5 and game.discard_pile.is_empty())
	assert(game.wake.samples.is_empty())
	# Turn economy: spend only on legal plays; never auto-refill an empty hand.
	game.hand.assign([1])
	game.energy = 1
	game.play_card(0)
	assert(game.hand.size() == 1 and game.energy == 1 and not game.busy)
	game.energy = 2
	game.play_card(0)
	assert(game.energy == 0 and game.busy)
	var turn_before: int = game.turn_number
	game.end_turn()
	game.draw_turn_card()
	game.discard_for_energy(0)
	assert(game.turn_number == turn_before and game.energy == 0)
	settle(game)
	assert(game.hand.is_empty(), "Empty hands do not auto-draw")
	game.end_turn()
	assert(game.energy == 5 and game.turn_number == turn_before + 1)
	game.draw_turn_card()
	game.draw_turn_card()
	assert(game.hand.size() == 6 and game.draw_used, "Only one optional draw after refill")
	game.discard_for_energy(0)
	assert(game.energy == 6 and game.hand.size() == 5 and game.draw_blocked)
	game.draw_turn_card()
	assert(game.hand.size() == 5)
	game.end_turn()
	game.hand.assign([0, 1])
	game.discard_for_energy(0)
	game.draw_turn_card()
	assert(game.hand.size() == 1 and game.energy == 6 and not game.draw_used)
	game.discard_for_energy(0)
	assert(game.energy == 7, "Each discard grants one energy")
	game.end_turn()
	assert(game.energy == 5 and not game.draw_blocked, "Energy resets rather than carrying over")
	game.hand.clear()
	game.draw_pile.clear()
	game.discard_pile.assign([6])
	game.draw_turn_card()
	assert(game.hand == [6] and game.discard_pile.is_empty(), "Draw reshuffles when needed")
	game.hull = 0
	var defeated_energy: int = game.energy
	game.end_turn()
	game.discard_for_energy(0)
	assert(game.energy == defeated_energy and game.hand == [6])
	game.restart()
	assert(game.energy == 5 and game.turn_number == 1 and not game.draw_blocked and not game.draw_used)
	# Turn refill keeps existing cards, reshuffles as needed, and never trims a large hand.
	game.hand.assign([2, 3])
	game.draw_pile.assign([0])
	game.discard_pile.assign([6, 7])
	game.draw_blocked = true
	game.end_turn()
	assert(game.hand.size() == 5 and game.hand[0] == 2 and game.hand[1] == 3)
	assert(game.draw_pile.is_empty() and game.discard_pile.is_empty())
	game.hand.append(4)
	var kept: Array = game.hand.duplicate()
	game.end_turn()
	assert(game.hand == kept, "Hands above five are preserved")
	game.hand.assign([0])
	game.end_turn()
	assert(game.hand == [0], "Refill stops safely when no cards remain")
	print("PASS: start-of-turn refill, retained cards, refill reshuffle; energy costs, turn reset, draw limits, discard tradeoff, empty hands; mixed deck cycle, unique cannon cards, animated fire, range, occlusion, damage, sinking, reshuffle, movement, collision, wake and restart")
	quit()
