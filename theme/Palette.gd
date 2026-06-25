## Palette.gd
## Design tokens for the "cozy pastel" visual redesign (Claude Design handoff).
## Single source of truth for colors. Reference via preload:
##   const P := preload("res://theme/Palette.gd")
##   stylebox.bg_color = P.CARD
class_name Palette
extends RefCounted

# ─── Surfaces / background ────────────────────────────────────────────────────
const BG_TOP    := Color("fcead6")
const BG_MID    := Color("f8dec2")
const BG_BOTTOM := Color("f5d6b6")
const CARD      := Color("fffdf8")   # panels use this at ~0.9 alpha
const SHEET     := Color("fbf2e6")

# ─── Text ─────────────────────────────────────────────────────────────────────
const TEXT       := Color("5a463e")
const TEXT_BODY  := Color("6b5b50")
const TEXT_MUTED := Color("8a7565")
const TEXT_FAINT := Color("a8917f")
const ON_ACCENT  := Color("fff8f0")

# ─── Accent (peach) ───────────────────────────────────────────────────────────
const ACCENT        := Color("efb186")
const ACCENT_DEEP   := Color("e2925e")
const ACCENT_SHADOW := Color("c4764a")

# ─── Stat colors (icon bg + bar gradient ends) ────────────────────────────────
const HUNGER      := Color("efb186")
const HUNGER_A    := Color("f0b583")
const HUNGER_B    := Color("e0935c")
const HAPPY       := Color("efc368")
const HAPPY_A     := Color("f2cd78")
const HAPPY_B     := Color("e8ae45")
const ENERGY      := Color("86b6d6")
const ENERGY_A    := Color("9cc6e0")
const ENERGY_B    := Color("6e9ccb")
const AFFECTION   := Color("e59bb0")
const AFFECTION_A := Color("ebaaba")
const AFFECTION_B := Color("d87e98")

# ─── Bar tiers (healthy / low / critical) ─────────────────────────────────────
const TIER_HEALTHY_A := Color("a7cf94")
const TIER_HEALTHY_B := Color("86b673")
const TIER_LOW_A     := Color("f0ce84")
const TIER_LOW_B     := Color("e6b45c")
const TIER_CRIT_A    := Color("ec8a7a")
const TIER_CRIT_B    := Color("de6553")

# ─── Bond ─────────────────────────────────────────────────────────────────────
const BOND_A        := Color("ce9aae")
const BOND_B        := Color("c38d9e")
const BOND_BADGE_BG := Color("ebd0db")
const BOND_BADGE_FG := Color("9a5e78")

# ─── Room props ───────────────────────────────────────────────────────────────
const FLOOR_A      := Color("eccba8")
const FLOOR_B      := Color("e2bc96")
const RUG_1        := Color("d6a2ac")
const RUG_2        := Color("e6c0c6")
const RUG_3        := Color("f1d8dc")
const WINDOW_FRAME := Color("f3e2cc")
const SKY_A        := Color("c7e8ec")
const SKY_B        := Color("e6f4f0")
const SUN_A        := Color("ffe9a8")
const SUN_B        := Color("fad06a")
const CLOUD        := Color("ffffff")
const PICTURE_A    := Color("f4cfa0")
const PICTURE_B    := Color("b8a87e")
const POT_A        := Color("d98a5a")
const POT_B        := Color("c5774a")
const LEAF_A       := Color("a9ce92")
const LEAF_B       := Color("7fa86c")

# ─── Time-of-day tint overlays ────────────────────────────────────────────────
# Multiply-blend tints (design uses mix-blend-mode:multiply): the room is
# multiplied by these, so values near white = subtle, lower = deeper. Day = white
# (identity). Tuned conservatively so night deepens without going muddy.
const TINT_DUSK_MUL  := Color(1.0, 0.88, 0.78)
const TINT_NIGHT_MUL := Color(0.60, 0.65, 0.86)
# Legacy alpha-blend tints (kept for reference; superseded by the *_MUL above).
const TINT_DUSK  := Color(0.96, 0.66, 0.45, 0.12)
const TINT_NIGHT := Color(0.30, 0.32, 0.52, 0.20)
