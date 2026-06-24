## GameConfig.gd
## Autoload singleton — centralized game constants and feature flags.
##
## All magic numbers live here. Tune gameplay feel by editing this file only,
## without touching any game logic scripts.
##
## Feature flags let you enable v2 features incrementally without dead code removal.
extends Node

# ─── Stat Limits ──────────────────────────────────────────────────────────────

const STAT_MAX: float = 100.0
const STAT_MIN: float = 0.0

## Below this threshold the stat enters "critical" state. UI should show urgency.
const CRITICAL_THRESHOLD: float = 20.0

## Below this threshold the stat shows a gentle "low" warning.
const LOW_THRESHOLD: float = 40.0

# ─── Decay Rates (units per real-time second) ─────────────────────────────────
## At default rates, a full stat takes roughly:
##   hunger → ~27 min   happiness → ~41 min   energy → ~33 min   affection → ~55 min
##
## Multiply by DECAY_MULTIPLIER for testing (e.g. set it to 10.0).

const HUNGER_DECAY_RATE:    float = 0.06
const HAPPINESS_DECAY_RATE: float = 0.04
const ENERGY_DECAY_RATE:    float = 0.05
const AFFECTION_DECAY_RATE: float = 0.03

## Global multiplier applied to all decay rates.
const DECAY_MULTIPLIER: float = 1.0

# ─── Interaction Gains ────────────────────────────────────────────────────────

const FEED_HUNGER_GAIN:       float = 30.0
const PLAY_HAPPINESS_GAIN:    float = 25.0
const PLAY_ENERGY_COST:   float = 10.0  # Playing costs energy
const SLEEP_ENERGY_GAIN:  float = 50.0
const PET_AFFECTION_GAIN: float = 20.0

## Seconds between allowed interactions. Prevents button spam.
const INTERACTION_COOLDOWN: float = 2.0

## How long the pet naps before it auto-wakes when put to sleep.
const SLEEP_DURATION: float = 8.0

## Idle "thought" bubbles — the pet voices its neediest stat now and then.
const THOUGHT_INTERVAL_MIN: float = 6.0
const THOUGHT_INTERVAL_MAX: float = 12.0

# ─── Notification Delays (seconds) ───────────────────────────────────────────

const NOTIF_HUNGER_DELAY: float = 1800.0  # 30 min
const NOTIF_LONELY_DELAY: float = 3600.0  # 60 min
const NOTIF_TIRED_DELAY:  float = 2700.0  # 45 min

# ─── Save System ──────────────────────────────────────────────────────────────

const SAVE_FILE_PATH: String = "user://save_data.json"

## Seconds between auto-saves. Set to 0.0 to disable.
const AUTO_SAVE_INTERVAL: float = 60.0

# ─── Cosmetic IDs ─────────────────────────────────────────────────────────────
# TODO v2: populate dynamically from server / store catalog.

const COSMETIC_IDS: Dictionary = {
	"skin_default": "skin_default",
	# "skin_bunny": "skin_bunny",  # example future entry
}

# ─── Feature Flags ────────────────────────────────────────────────────────────

## Enable when Supabase integration is ready. SaveSystem checks this flag.
const FEATURE_CLOUD_SAVE:  bool = false  # TODO v2

## Enable when social / multiplayer screens are implemented.
const FEATURE_MULTIPLAYER: bool = false  # TODO v2

## Enable when the cosmetics shop is implemented.
const FEATURE_SHOP:        bool = false  # TODO v2

# ─── Feedback Colors ──────────────────────────────────────────────────────────
# Shared hues for floating text + particle effects, so each stat reads
# consistently across the UI. Tweak here to recolor all juice at once.

const COLOR_HUNGER:    Color = Color(1.0, 0.7, 0.35)   # warm orange
const COLOR_HAPPINESS: Color = Color(1.0, 0.85, 0.3)   # sunny yellow
const COLOR_ENERGY:    Color = Color(0.6, 0.8, 1.0)    # soft blue
const COLOR_AFFECTION: Color = Color(1.0, 0.45, 0.6)   # pink
const COLOR_NEUTRAL:   Color = Color(0.9, 0.9, 0.95)   # near-white

# ─── Localization ─────────────────────────────────────────────────────────────

const SUPPORTED_LOCALES: Array[String] = ["en", "es"]
const DEFAULT_LOCALE:    String        = "en"
