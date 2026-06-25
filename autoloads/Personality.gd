## Personality.gd
## Autoload — emergent personality (roadmap v0.2).
##
## Tracks four recency-weighted (EWMA) care-action weights (feed/play/sleep/pet).
## When one action dominates the player's care history a TRAIT emerges
## (glotona / juguetona / dormilona / mimosa); while care is varied or still
## "budding" the pet is "equilibrada" (neutral, never punitive).
##
## Traits modulate decay/gain factors and procedural visuals (fur/cheek tint,
## breathe/bob/react motion) — 100% code, zero art. Cozy guarantee: every decay
## penalty is paired with a LARGER gain in that trait's favourite action, so a
## trait can never starve the pet (which never dies anyway).
##
## Recording is push-based: Pet.gd calls record(kind) inside each interaction
## handler AFTER its guards pass, so refused actions (e.g. too tired to play) are
## never counted and sleep — which emits no burst — is still tracked.
##
## State persists in the save "personality" block (schema v4); Room orchestrates
## load_from()/to_dict() exactly like Achievements.
extends Node

# ─── Tuning (feel lives here) ─────────────────────────────────────────────────
const RHO: float = 0.985            # recency: every other weight decays per record
const DOMINANCE: float = 0.42       # share needed to activate a trait
const HYSTERESIS: float = 0.08      # lose the trait below DOMINANCE - HYSTERESIS (0.34)
const SWITCH_MARGIN: float = 0.02   # margin a rival needs to steal an active trait
const MIN_VOLUME: int = 25          # recorded actions before any trait can show

# care action kind -> trait id
const TRAIT_FOR := {"feed": "glotona", "play": "juguetona", "sleep": "dormilona", "pet": "mimosa"}

# Per-trait effect table. Missing decay/gain/bond keys default to 1.0; motion and
# tint default to neutral. Each trait pairs its decay penalty with a bigger gain
# in its own action (cozy: it can never dig a hole).
const _TABLE := {
	"glotona": {
		"decay": {"hunger": 1.12}, "gain": {"feed": 1.15}, "bond": {"feed": 1.15},
		"breathe": 1.0, "bob": 1.0, "react": 1.0,
		"fur_mul": Color(1.05, 0.99, 0.90), "cheek_mul": Color(1, 1, 1),
		"cheek_scale": 1.0, "cheek_alpha_add": 0.0,
	},
	"juguetona": {
		"decay": {"energy": 1.08}, "gain": {"play": 1.2}, "bond": {"play": 1.15},
		"play_energy_cost": 0.8,
		"breathe": 1.25, "bob": 1.3, "react": 1.2,
		"fur_mul": Color(1, 1, 1), "cheek_mul": Color(1.08, 0.95, 0.96),
		"cheek_scale": 1.05, "cheek_alpha_add": 0.0,
	},
	"dormilona": {
		"decay": {"energy": 0.82, "happiness": 1.05}, "gain": {"sleep": 1.2}, "bond": {},
		"breathe": 0.8, "bob": 0.8, "react": 1.0,
		"fur_mul": Color(0.97, 1.0, 1.06), "cheek_mul": Color(1, 1, 1),
		"cheek_scale": 1.0, "cheek_alpha_add": 0.0,
	},
	"mimosa": {
		"decay": {"affection": 0.8}, "gain": {"pet": 1.2}, "bond": {"pet": 1.2},
		"breathe": 1.0, "bob": 1.0, "react": 1.15,
		"fur_mul": Color(1, 1, 1), "cheek_mul": Color(1.04, 0.96, 0.97),
		"cheek_scale": 1.2, "cheek_alpha_add": 0.1,
	},
}

# ─── State ────────────────────────────────────────────────────────────────────
var w := {"feed": 0.0, "play": 0.0, "sleep": 0.0, "pet": 0.0}
var eff_total: int = 0
var dominant: String = ""
var _revealed := {}   # trait id -> true (set of already-celebrated traits)


# ─── Public API ───────────────────────────────────────────────────────────────

## Records a successful care action and recomputes the active trait.
## stat_before (the target stat just before its gain) is stored for a future
## "preventive" flavor; unused in v1.
func record(kind: String, _stat_before: float = 0.0) -> void:
	if not w.has(kind):
		return
	for k in w:
		w[k] *= RHO
	w[kind] += 1.0
	eff_total += 1
	_recompute_and_emit()


## Current active trait id, or "" for equilibrada/budding.
func trait_id() -> String:
	return dominant


## Per-stat decay multiplier from the active trait (1.0 if none).
func decay_factor(stat: String) -> float:
	if dominant == "" or not _TABLE.has(dominant):
		return 1.0
	return float(_TABLE[dominant]["decay"].get(stat, 1.0))


## Per-action gain multiplier from the active trait (1.0 if none).
func gain_factor(kind: String) -> float:
	if dominant == "" or not _TABLE.has(dominant):
		return 1.0
	return float(_TABLE[dominant]["gain"].get(kind, 1.0))


## Per-action bond-XP multiplier from the active trait (1.0 if none).
func bond_factor(kind: String) -> float:
	if dominant == "" or not _TABLE.has(dominant):
		return 1.0
	return float(_TABLE[dominant]["bond"].get(kind, 1.0))


## Multiplier on the energy COST of playing (juguetona tires less); 1.0 if none.
func play_energy_cost_factor() -> float:
	if dominant == "" or not _TABLE.has(dominant):
		return 1.0
	return float(_TABLE[dominant].get("play_energy_cost", 1.0))


## Re-emits the current profile so Mochi/HUD can sync (called by Room after load).
func emit_current() -> void:
	EventBus.personality_updated.emit(_profile())


# ─── Persistence (orchestrated by Room) ───────────────────────────────────────

func to_dict() -> Dictionary:
	return {"w": w.duplicate(), "eff_total": eff_total, "dominant": dominant, "revealed": _revealed.keys()}


func load_from(data: Dictionary) -> void:
	var sw: Dictionary = data.get("w", {})
	for k in w:
		w[k] = float(sw.get(k, 0.0))
	eff_total = int(data.get("eff_total", 0))
	dominant = str(data.get("dominant", ""))
	# Invariant: no trait below the minimum volume (guards old/tampered saves and
	# the lowered MIN_VOLUME used during dev demos).
	if eff_total < MIN_VOLUME:
		dominant = ""
	_revealed.clear()
	for id in data.get("revealed", []):
		_revealed[str(id)] = true


# ─── Private ──────────────────────────────────────────────────────────────────

func _recompute_and_emit() -> void:
	dominant = _compute_dominant()
	EventBus.personality_updated.emit(_profile())
	if dominant != "" and not _revealed.has(dominant):
		_revealed[dominant] = true
		EventBus.trait_revealed.emit(dominant)


func _compute_dominant() -> String:
	var total: float = w["feed"] + w["play"] + w["sleep"] + w["pet"]
	if total <= 0.0 or eff_total < MIN_VOLUME:
		return ""

	var top_kind := ""
	var top_share := 0.0
	for k in w:
		var s: float = w[k] / total
		if s > top_share:
			top_share = s
			top_kind = k
	var top_trait: String = TRAIT_FOR[top_kind]

	if dominant == "":
		return top_trait if top_share >= DOMINANCE else ""

	# Already have a trait — sticky (hysteresis) and slow to switch, so it matures.
	var cur_kind := _kind_for_trait(dominant)
	var cur_share: float = (w[cur_kind] / total) if cur_kind != "" else 0.0
	if cur_share < DOMINANCE - HYSTERESIS:
		return top_trait if top_share >= DOMINANCE else ""
	if top_trait != dominant and top_share >= DOMINANCE and top_share > cur_share + SWITCH_MARGIN:
		return top_trait
	return dominant


func _kind_for_trait(tid: String) -> String:
	for k in TRAIT_FOR:
		if TRAIT_FOR[k] == tid:
			return k
	return ""


func _profile() -> Dictionary:
	if dominant == "" or not _TABLE.has(dominant):
		return {"dominant": "", "breathe": 1.0, "bob": 1.0, "react": 1.0,
				"fur_mul": Color(1, 1, 1), "cheek_mul": Color(1, 1, 1),
				"cheek_scale": 1.0, "cheek_alpha_add": 0.0}
	var t: Dictionary = _TABLE[dominant]
	return {"dominant": dominant, "breathe": t["breathe"], "bob": t["bob"], "react": t["react"],
			"fur_mul": t["fur_mul"], "cheek_mul": t["cheek_mul"],
			"cheek_scale": t["cheek_scale"], "cheek_alpha_add": t["cheek_alpha_add"]}
