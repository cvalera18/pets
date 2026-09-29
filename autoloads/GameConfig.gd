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
## At rate × NORMAL multiplier (0.2), a full stat empties in roughly:
##   hunger → ~2.3 h   happiness → ~3.5 h   energy → ~2.8 h   affection → ~4.6 h
## Test mode (×8) is 40× faster, for development: hunger empties in ~3.5 min and
## affection, the slowest, in ~7 min.

const HUNGER_DECAY_RATE:    float = 0.06
const HAPPINESS_DECAY_RATE: float = 0.04
const ENERGY_DECAY_RATE:    float = 0.05
const AFFECTION_DECAY_RATE: float = 0.03

## Decay-speed presets, selected at runtime via GameState.decay_test_mode
## (toggled in Settings). Normal = logical pace; Test = fast, to watch her needs
## and body language come up within a couple of minutes.
const DECAY_MULTIPLIER_NORMAL: float = 0.2
const DECAY_MULTIPLIER_TEST:   float = 8.0

# ─── Interaction Gains ────────────────────────────────────────────────────────

# ─── Food (bowl) ──────────────────────────────────────────────────────────────

## Hunger a full bowl restores, per food; she eats it in three mouthfuls.
const FOOD_HUNGER: Dictionary = {"tuna": 35.0, "chicken": 30.0, "kibble": 25.0, "carrot": 15.0}
## She goes to eat food she likes when her hunger is below this; her favorite
## tempts her almost always. A food she dislikes she only eats when starving.
const EAT_BELOW:       float = 75.0
const EAT_LOVED_BELOW: float = 95.0
## Extra happiness from a meal of her favorite food.
const LOVED_FOOD_HAPPINESS: float = 10.0
## Where the bowl sits on the floor, from Mochi's feet (left of her front paws).
const BOWL_OFFSET := Vector2(-128.0, 4.0)

# ─── Play (feather wand) ──────────────────────────────────────────────────────

## Each pounce that catches the feather: happiness gained and energy spent, so a
## long play session tires her out and she dozes off on her own.
const PLAY_CATCH_HAPPINESS: float = 12.0
const PLAY_CATCH_ENERGY:    float = 5.0
## A miss (you whisked the feather away mid-leap) still counts a little.
const PLAY_MISS_HAPPINESS:  float = 4.0
const PLAY_MISS_ENERGY:     float = 3.0

## Let go of the wand and it swings back beside Mochi; untouched this long, it's put away.
const WAND_IDLE_TIMEOUT: float = 5.0

# ─── Body language ────────────────────────────────────────────────────────────

## Bored, she brings you the wand at most this often.
const FETCH_COOLDOWN: float = 90.0
## The wand she brought lies on the floor this long before it's put away.
const TOY_LYING_TIMEOUT: float = 30.0

# ─── Sleep (Mochi decides) ────────────────────────────────────────────────────

## She falls asleep on her own below this energy; she's sleepier at night.
const SLEEPY_ENERGY:       float = 25.0
const SLEEPY_ENERGY_NIGHT: float = 50.0
const NIGHT_START_HOUR:    int   = 22
const NIGHT_END_HOUR:      int   = 7

## Energy regained per second asleep: 25→100 takes ~15 min, or ~30 s in test mode.
const SLEEP_REGEN_NORMAL: float = 0.08
const SLEEP_REGEN_TEST:   float = 2.5

## After being woken she sulks a while (half the joy from caresses) and won't
## doze off again right away.
const WAKE_SULK:  float = 20.0
const WAKE_GRACE: float = 45.0

## Seconds after opening the game before she may doze off, so she greets you first.
const OPEN_GRACE: float = 30.0

# ─── Absence (offline) ────────────────────────────────────────────────────────

## While you're away stats settle at a calm floor instead of emptying, so coming
## back never finds her sad; only days of neglect lower that floor.
const OFFLINE_FLOOR: float = 45.0
const NEGLECT_AFTER: float = 172800.0  # 48 h away before the floor starts to sink…
const NEGLECT_SPAN:  float = 86400.0   # …over one more day…
const NEGLECT_FLOOR: float = 15.0      # …down to here

# ─── Caresses (touch) ─────────────────────────────────────────────────────────

## Affection per second of good stroking, before the zone and trait factors.
const STROKE_AFFECTION_RATE: float = 8.0

## Seconds of good stroking that earn one award (bond XP, hearts, "+N").
const STROKE_AWARD_TIME: float = 2.5

## How much each part of Mochi enjoys being stroked (see PetTouch zones); "rub"
## is her rubbing against a finger resting on her head.
const STROKE_ZONE_FACTOR: Dictionary = {
	"cheeks": 1.4, "rub": 1.2, "head": 1.15, "back": 1.0, "body": 0.6, "belly": 0.6,
}

## Seconds for the purr to swell to full while stroking, and to fade once you stop.
const PURR_RISE: float = 2.5
const PURR_FALL: float = 1.2


## Idle "thought" bubbles — the pet voices its neediest stat now and then.
const THOUGHT_INTERVAL_MIN: float = 6.0
const THOUGHT_INTERVAL_MAX: float = 12.0

## Bond / relationship progression — XP earned per positive interaction and how
## much XP each level costs. Bond level = 1 + bond_xp / BOND_XP_PER_LEVEL.
const BOND_XP_PER_LEVEL: int = 100
const BOND_XP_FEED:      int = 10
const BOND_XP_PLAY:      int = 15
const BOND_XP_PET:       int = 12

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

const COLOR_HUNGER:    Color = Color("c0653e")   # terracotta
const COLOR_HAPPINESS: Color = Color("b8871f")   # mustard
const COLOR_ENERGY:    Color = Color("587c99")   # denim
const COLOR_AFFECTION: Color = Color("b85e72")   # rose
const COLOR_NEUTRAL:   Color = Color("7e6652")   # muted brown

# ─── Localization ─────────────────────────────────────────────────────────────

const SUPPORTED_LOCALES: Array[String] = ["en", "es"]
const DEFAULT_LOCALE:    String        = "en"
