extends "res://tests/angel_policy.gd"
## Walks the short road and uses Michael, Raphael, and Uriel.
## Never casts Azrael or Gabriel. That run has to lose.


const BLOCKED := {
	"strike": true,
	"burst": true,
	"disarm": true,
	"escape_dash": true,
	"detect_pulse": true,
	"detect": true,
	"cleanse": true,
	"self_shield": true,
	"emergency_res": true,
	"aegis": true,
	"rescue": true,
	"dash": true,
}


func _cast_ability(sim, ability: String, gap: int) -> void:
	if BLOCKED.has(str(ability)):
		return
	super._cast_ability(sim, ability, gap)


func _cast_cmd(sim, cmd: String, gap: int) -> void:
	if BLOCKED.has(str(cmd)):
		return
	var ability := str(sim.preview(cmd).get("ability", ""))
	if BLOCKED.has(ability):
		return
	super._cast_cmd(sim, cmd, gap)
