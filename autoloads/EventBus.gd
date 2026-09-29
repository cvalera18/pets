## EventBus.gd
## Autoload singleton — global decoupled communication via signals.
##
## All inter-system communication flows through here.
## Nodes emit/listen here instead of holding direct references to each other.
## This keeps systems independent and easy to test in isolation.
##
## Usage:
##   EventBus.pet_fed.emit()                    # emit a signal
##   EventBus.pet_fed.connect(_on_pet_fed)      # subscribe to a signal
extends Node

# ─── Pet Stat Events ──────────────────────────────────────────────────────────

## Emitted when any stat value changes.
## @param stat_name  "hunger" | "mood" | "energy" | "affection"
## @param new_value  float [0–100]
## @param old_value  float [0–100]
signal stat_changed(stat_name: String, new_value: float, old_value: float)

## Emitted when a stat reaches 0. Drives sad/critical animations.
signal stat_depleted(stat_name: String)

## Emitted when a stat drops below GameConfig.CRITICAL_THRESHOLD.
signal stat_critical(stat_name: String, value: float)

## Emitted when a stat climbs back above CRITICAL_THRESHOLD after being critical.
signal stat_recovered(stat_name: String, value: float)

# ─── Pet Interaction Events ───────────────────────────────────────────────────

## Player fed the pet.
signal pet_fed

## Emitted by Pet each time Mochi catches the feather wand (a play moment).
signal pet_played

## HUD's "Jugar" button: take the feather wand out, or put it away.
signal play_requested

## The feather wand appeared (true) or was put away (false).
signal play_mode_changed(active: bool)

## Where the wand's feather is (viewport coordinates) while the wand is out, and
## whether a finger is holding it.
signal wand_moved(screen_pos: Vector2, held: bool)

## Mochi caught the feather; the wand gives a little tug.
signal wand_caught

## Emitted by Pet when Mochi dozes off on her own (she's tired, or it's night).
signal pet_slept

## Emitted by Pet when Mochi wakes up, rested or woken by the player.
signal pet_woken

## Emitted by Pet each time a caress earns an award (a few seconds of good strokes).
signal pet_petted

## Mochi's purr intensity while being stroked: 0 = silent, 1 = full purr.
signal purr_changed(intensity: float)

## Emitted when the pet's sleeping state changes.
## HUD listens to this to toggle the Sleep/Wake button label.
signal sleeping_changed(is_sleeping: bool)

## Emitted with the pet's name for HUD display (on load and on name change).
signal pet_name_changed(pet_name: String)

# ─── Progression ──────────────────────────────────────────────────────────────

## Emitted when the bond level changes, and once on load for initial HUD sync.
signal bond_level_changed(level: int)

## Emitted with the bond progress within the current level, in [0, 1].
signal bond_progress_changed(ratio: float)

## Emitted when a milestone is newly unlocked.
## @param id         achievement id (a key of Achievements.CATALOG)
## @param title_key  i18n key for the display title
signal achievement_unlocked(id: String, title_key: String)

# ─── Personality ──────────────────────────────────────────────────────────────

## Emitted by Personality after every record() and once on load.
## @param profile  {"dominant": String, "breathe"/"bob"/"react": float,
##                  "fur_mul"/"cheek_mul": Color, "cheek_scale"/"cheek_alpha_add": float}
## Pet/Mochi apply procedural effects; HUD shows the trait badge.
signal personality_updated(profile: Dictionary)

## One-shot the first time a trait activates — drives a discovery celebration.
## @param trait_id  "glotona" | "juguetona" | "dormilona" | "mimosa"
signal trait_revealed(trait_id: String)

# ─── Navigation Events ────────────────────────────────────────────────────────

## Request to navigate to a named screen (keys defined in Main.SCREENS).
signal navigate_to(screen_name: String)

## Request to go back to the previous screen.
signal navigate_back

## Emitted after the UI locale changes at runtime, so live screens re-translate.
signal locale_changed

# ─── Save / Load Events ───────────────────────────────────────────────────────

## External systems (app pause, quit) request a save.
signal save_requested

## Fired after SaveSystem finishes a save attempt.
signal save_completed(success: bool)

## Fired after SaveSystem finishes a load attempt.
signal load_completed(success: bool)

# ─── Cosmetic Events ──────────────────────────────────────────────────────────
# TODO v2: expand when the shop system is implemented.

## Player equipped a cosmetic item.
## @param cosmetic_id  unique string ID from GameConfig.COSMETIC_IDS
## @param slot         "skin" | "background" | "accessory"
signal cosmetic_equipped(cosmetic_id: String, slot: String)

# ─── Notification Events ──────────────────────────────────────────────────────

## Request to schedule a local push notification.
## @param type            matches NotificationManager.Type enum keys (e.g. "HUNGRY")
## @param delay_seconds   seconds until the notification fires
signal notification_schedule_requested(type: String, delay_seconds: float)

## Request to cancel all pending notifications of a given type.
signal notification_cancel_requested(type: String)

# ─── Juice / Feedback Events ──────────────────────────────────────────────────

## Request a floating text label at a world position (e.g. "+20", "Zzz").
## @param text       the string to show
## @param color      font color (usually the related stat's hue)
## @param world_pos  global position to anchor the effect to
signal floating_text_requested(text: String, color: Color, world_pos: Vector2)

## Request a one-shot particle burst at a world position.
## @param kind       "love" | "play" | "eat" | "sleep" (see EffectsLayer.BURSTS)
## @param world_pos  global position to emit from
signal burst_requested(kind: String, world_pos: Vector2)

## A one-shot sound with no particles (see AudioManager): "mrrp" | "grumble".
signal sound_requested(key: String)

## The pet voices a need or a trait flavor line; the HUD shows it in a bubble.
## @param text  already-translated line (e.g. "¿Comidita?")
## @param kind  stat name ("hunger", …) or trait id ("glotona", …)
signal pet_thought(text: String, kind: String)
