extends "res://tests/angel_policy.gd"
## A slower angel player. Same commands as the scripted policy, later reactions,
## heals only once someone is actually hurt, and does not pre-shield every tell.
## Still claims the stakes and answers Lucifer's four blows.


func _init() -> void:
	act_every = 10
	react_remain = 24
	heal_below = 64
	burst_at = 6000
	burst_loose = true
	pre_shield = false
