## GameState.gd
## Autoload singleton — mutable, in-memory session state that must survive scene
## changes but is not itself the persistence layer.
##
## Use it for hand-offs between screens (e.g. the chosen pet name flowing from
## onboarding into the Room) and for live settings several systems read (e.g. the
## notifications opt-out). Persistent values are still written to / read from the
## save file via SaveSystem; GameState just mirrors the live value at runtime.
extends Node

## Pet name chosen on the onboarding screen, consumed by Room when it creates a
## fresh pet. Empty means "not chosen yet" (Room falls back to a default).
var pending_pet_name: String = ""

## Live notifications opt-out, toggled in Settings and respected by
## NotificationManager. Loaded from the save on launch.
var notifications_enabled: bool = true

## Live sound-effects toggle, set in Settings and respected by AudioManager.
var sfx_enabled: bool = true

## SFX volume [0..1], set in Settings, applied by AudioManager per play.
var sfx_volume: float = 0.8

## When true, stats decay at the fast "test" rate; otherwise the normal pace.
## Read by PetStats; toggled in Settings.
var decay_test_mode: bool = false
