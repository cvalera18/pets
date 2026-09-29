## Palette.gd
## Design tokens for the "Fieltro" (felt & stitches) look. Single source of truth
## for colors; the felt Theme (theme/felt_theme.tres) and the felt components
## read from here. Reference via preload:
##   const P := preload("res://theme/Palette.gd")
class_name Palette
extends RefCounted

# ─── Surfaces ─────────────────────────────────────────────────────────────────
const WALL          := Color("e6d6be")
const FLOOR         := Color("dcc7a8")
const FLOOR_SEAM    := Color("c2a782")
const PANEL         := Color("f7eddd")   # felt panels
const PANEL_STITCH  := Color("bda27e")
const CARD          := Color("fbf4e6")   # inner cards, bubbles, fields
const CARD_STITCH   := Color("d5be9c")
const BUBBLE_STITCH := Color("c9b08e")
const TRACK         := Color("e9dac4")   # bar tracks, secondary buttons
const TRACK_STITCH  := Color("b89a74")
const SEAM_SOFT     := Color("e2d2bb")   # dividers inside cards
const GRABBER       := Color("dcc8ac")
const LIP           := Color(0.47, 0.35, 0.24, 0.25)
const SHADOW        := Color(0.43, 0.31, 0.2, 0.16)
const DIM           := Color(0.23, 0.15, 0.09, 0.42)

# ─── Text ─────────────────────────────────────────────────────────────────────
const INK       := Color("4a3426")
const INK_SOFT  := Color("6e5644")
const MUTED     := Color("7e6652")
const SECTION   := Color("9c8269")
const FAINT     := Color("a8917a")
const ON_ACCENT := Color("fff7ec")
const WORDMARK  := Color("b85f38")

# ─── Accents / stats ──────────────────────────────────────────────────────────
const TERRACOTTA     := Color("d27449")   # hunger + primary actions
const TERRACOTTA_LIP := Color("a9552c")
const TERRACOTTA_DOWN := Color("c0653e")
const MUSTARD        := Color("dda843")   # happiness
const DENIM          := Color("6f93b0")   # energy
const ROSE           := Color("cf8290")   # affection + bond
const SAGE           := Color("7f9a70")   # switches on
const SAGE_LIGHT     := Color("8fa67f")
const RING           := Color(1.0, 0.97, 0.925, 0.75)   # stitched ring on colored felt

const HUNGER    := TERRACOTTA
const HAPPY     := MUSTARD
const ENERGY    := DENIM
const AFFECTION := ROSE

# Darker twins for text drawn in a stat's color (floating texts, level label).
const HUNGER_TEXT    := Color("c0653e")
const HAPPY_TEXT     := Color("b8871f")
const ENERGY_TEXT    := Color("587c99")
const AFFECTION_TEXT := Color("b85e72")
const LEVEL_TEXT     := Color("9a4f63")
const TRAIT_TEXT     := Color("a4532f")
const KICKER_TEXT    := Color("9a6a14")

# ─── States ───────────────────────────────────────────────────────────────────
const CRIT          := Color("c4453a")
const CRIT_TEXT     := Color("b23a2f")
const CRIT_ROW      := Color("f4d9ce")
const CRIT_LIP      := Color("93302a")
const DANGER_BG     := Color("fbede8")
const DANGER_STITCH := Color("de9a8e")
const DISABLED      := Color("d9c8b0")
const DISABLED_LIP  := Color("c2ae92")
const TOAST_ROSE    := Color("f6e3e6")
const TOAST_ROSE_STITCH := Color("dda9b3")

# ─── Room props ───────────────────────────────────────────────────────────────
const HOOP_WOOD    := Color("c8996a")
const HOOP_INNER   := Color("b08257")
const HOOP_FABRIC  := Color("f4ede2")
const HOOP_STRING  := Color("a97e55")
const HOOP_NAIL    := Color("8e6744")
const SUN          := Color("e7b04a")
const SUN_RING     := Color("e1a640")
const CLOUD_STITCH := Color("9bb3c6")
const MOON         := Color("f1dc9e")
const CUSHION      := Color("c98c9a")
const CUSHION_STITCH := Color("f2d3da")

# ─── Time-of-day tint overlays ────────────────────────────────────────────────
# Multiply-blend tints over the room and pet: values near white = subtle, lower =
# deeper. Day = white (identity).
const TINT_DUSK_MUL  := Color(1.0, 0.88, 0.78)
const TINT_NIGHT_MUL := Color(0.60, 0.65, 0.86)
