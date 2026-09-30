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

## Emitted by Pet when Mochi finishes a meal from her bowl.
signal pet_fed

## The food tray dropped a food at a screen point; the bowl takes it if it landed on it.
signal food_dropped(food: String, screen_pos: Vector2)

## The bowl accepted a food (the tray closes).
signal food_served(food: String)

## What's in the bowl now: a food id ("" when empty) and how much is left, 0..1.
signal bowl_changed(food: String, amount: float)

## Mochi took a mouthful from the bowl.
signal bowl_bite

## Mochi pawed at her bowl, asking for food; it wobbles.
signal bowl_nudged

## First time the player learns what Mochi thinks of a food ("love"|"like"|"dislike").
signal taste_discovered(food: String, taste: String)

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

## While the wand is out: whether the feather is somewhere she'd hunt it, and how
## close she is to pouncing (0..1). The wand draws it as a stitched ring.
signal hunt_changed(huntable: bool, progress: float)

## Bored, Mochi brings the wand in her mouth: where her mouth is (viewport
## coordinates), every frame while she carries it.
signal toy_carried(mouth_pos: Vector2)

## She drops the wand she brought on the floor in front of you.
signal toy_dropped

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

## How Mochi is doing, as a soft doodle in her thought bubble (she never talks):
## a state, never the exact thing she wants.
## @param kind  FeltPicto kind: "hambre" | "jugar" | "mimos" | "sueno"
signal pet_thought(kind: String)

## How Mochi feels: a pictogram that pops at a point over her and fades.
## @param kind        FeltPicto kind: "enojo" | "asco" | "encanta" | "casi" | "maulla"
## @param screen_pos  viewport position of the symbol's center
signal reaction_requested(kind: String, screen_pos: Vector2)

## Show the player a gesture with the ghost hand (viewport positions):
## "drag" from → to, "hold" still at from, "stroke" from → to along her back.
signal hint_requested(kind: String, from: Vector2, to: Vector2)

## The food tray opened for the first time: the bowl answers with a drag hint
## from this tray slot (viewport position) to itself.
signal food_hint_wanted(slot_pos: Vector2)

## A room object was tapped: the bowl asks for the food tray ("food"), the toy
## basket for the toys ("toys").
signal tray_requested(which: String)

## The feather wand went back into the toy basket (true) or came out (false).
signal wand_stored(stored: bool)

## Something new was noted in the Libreta de Mochi (already-translated line).
signal journal_noted(text: String)

## Whether the Libreta has something you haven't read (the header button's dot).
signal journal_unread(unread: bool)

## The Libreta opened and asks for what to show; Pet answers with journal_snapshot.
signal journal_requested

## Everything the Libreta shows (see Pet._journal_snapshot).
signal journal_snapshot(data: Dictionary)
