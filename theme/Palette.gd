## Palette.gd
## Design tokens for the "Fieltro" (felt & stitches) look. Single source of truth
## for colors; the felt Theme (theme/felt_theme.tres), the felt components and the
## PetBond · Fieltro design system (via tools/export_design_tokens.gd) read from
## here. The trailing comment on each color is its usage note in the design system.
## Reference via preload:
##   const P := preload("res://theme/Palette.gd")
class_name Palette
extends RefCounted

# ─── Surfaces ─────────────────────────────────────────────────────────────────
const WALL          := Color("e6d6be")   # Room wall and screen background behind every panel.
const FLOOR         := Color("dcc7a8")   # Floor band at the bottom of the room.
const FLOOR_SEAM    := Color("c2a782")   # Stitched line where the wall meets the floor.
const PANEL         := Color("f7eddd")   # Felt panels: header, stats, action bar, cards, sheets.
const PANEL_STITCH  := Color("bda27e")   # Stitched seam inset inside PANEL.
const CARD          := Color("fbf4e6")   # Inner cards, thought bubbles, toasts, dialogs and text fields.
const CARD_STITCH   := Color("d5be9c")   # Fine stitched seam inside CARD.
const BUBBLE_STITCH := Color("c9b08e")   # Seam of thought bubbles and resting text fields.
const TRACK         := Color("e9dac4")   # Sunken bar tracks, segmented-control track, secondary buttons.
const TRACK_STITCH  := Color("b89a74")   # Ring stitched on TRACK-colored buttons.
const SEAM_SOFT     := Color("e2d2bb")   # Stitched dividers between rows inside a CARD.
const GRABBER       := Color("dcc8ac")   # Drag handle on top of bottom sheets.
const LIP           := Color(0.47, 0.35, 0.24, 0.25)   # Hard 2 px lip under felt panels.
const SHADOW        := Color(0.43, 0.31, 0.2, 0.16)    # Soft drop shadow under felt panels and bubbles.
const DIM           := Color(0.23, 0.15, 0.09, 0.42)   # Scrim behind bottom sheets and dialogs.

# ─── Text ─────────────────────────────────────────────────────────────────────
const INK       := Color("4a3426")   # Primary text and titles on PANEL, CARD and WALL.
const INK_SOFT  := Color("6e5644")   # Secondary text, unselected segments, icons on TRACK buttons.
const MUTED     := Color("7e6652")   # Taglines, quotes and helper copy on PANEL and CARD.
const SECTION   := Color("9c8269")   # Uppercase section labels and setting values (12–14 px bold).
const FAINT     := Color("a8917a")   # Placeholder text in fields; disabled labels.
const ON_ACCENT := Color("fff7ec")   # Text and icons on TERRACOTTA, stat colors and CRIT fills.
const WORDMARK  := Color("b85f38")   # The PetBond wordmark on the welcome screen.

# ─── Accents / stats ──────────────────────────────────────────────────────────
const TERRACOTTA      := Color("d27449")   # Primary actions (CTA, selected segment) and the hunger stat.
const TERRACOTTA_LIP  := Color("a9552c")   # Lip under TERRACOTTA buttons.
const TERRACOTTA_DOWN := Color("c0653e")   # TERRACOTTA while pressed.
const MUSTARD         := Color("dda843")   # Happiness stat; achievement medal.
const DENIM           := Color("6f93b0")   # Energy stat.
const ROSE            := Color("cf8290")   # Affection stat, bond level and bond bar.
const SAGE            := Color("7f9a70")   # Switches in the on state.
const SAGE_LIGHT      := Color("8fa67f")   # Garland flags and decorative felt only.
const RING            := Color(1.0, 0.97, 0.925, 0.75)   # Stitched ring on colored felt (sewing buttons, badges).

const HUNGER    := TERRACOTTA   # Hunger stat: badge, bar, feed button.
const HAPPY     := MUSTARD      # Happiness stat: badge, bar, play button.
const ENERGY    := DENIM        # Energy stat: badge, bar, sleep button.
const AFFECTION := ROSE         # Affection stat: badge, bar, pet button.

# Darker twins for text drawn in a stat's color (floating texts, level label).
const HUNGER_TEXT    := Color("c0653e")   # Floating "+N" for hunger, over the room.
const HAPPY_TEXT     := Color("b8871f")   # Floating "+N" for happiness, over the room.
const ENERGY_TEXT    := Color("587c99")   # Floating "+N" and "Zzz" for energy, over the room.
const AFFECTION_TEXT := Color("b85e72")   # Floating "+N" for affection, over the room.
const LEVEL_TEXT     := Color("9a4f63")   # "Nivel N" label and bond copy on PANEL and rose toasts.
const TRAIT_TEXT     := Color("a4532f")   # Trait tag label on CARD.
const KICKER_TEXT    := Color("9a6a14")   # Uppercase kicker of achievement toasts on CARD.

# ─── States ───────────────────────────────────────────────────────────────────
const CRIT              := Color("c4453a")   # Critical stat bar fill, alert ring, destructive confirm button.
const CRIT_TEXT         := Color("b23a2f")   # Critical stat values and destructive button labels.
const CRIT_ROW          := Color("f4d9ce")   # Background of a stat row while critical.
const CRIT_LIP          := Color("93302a")   # Lip under the CRIT button.
const DANGER_BG         := Color("fbede8")   # Destructive secondary button ("Borrar partida").
const DANGER_STITCH     := Color("de9a8e")   # Seam of the destructive secondary button.
const DISABLED          := Color("d9c8b0")   # Disabled buttons; switches in the off state.
const DISABLED_LIP      := Color("c2ae92")   # Lip under disabled buttons.
const TOAST_ROSE        := Color("f6e3e6")   # Level-up toast.
const TOAST_ROSE_STITCH := Color("dda9b3")   # Seam of the level-up toast.

# ─── Room props ───────────────────────────────────────────────────────────────
const HOOP_WOOD      := Color("c8996a")   # Embroidery hoop frame.
const HOOP_INNER     := Color("b08257")   # Inner ring and clamp of the hoop.
const HOOP_FABRIC    := Color("f4ede2")   # Fabric stretched in the hoop.
const HOOP_STRING    := Color("a97e55")   # String the hoop hangs from.
const HOOP_NAIL      := Color("8e6744")   # Nail above the hoop.
const SUN            := Color("e7b04a")   # Embroidered sun (day).
const SUN_RING       := Color("e1a640")   # Stitched sun rays and night stars.
const CLOUD_STITCH   := Color("9bb3c6")   # Seam of the embroidered cloud.
const MOON           := Color("f1dc9e")   # Embroidered moon (night).
const CUSHION        := Color("c98c9a")   # Knitted cushion Mochi sits on.
const CUSHION_STITCH := Color("f2d3da")   # Stitched ring on the cushion.

# ─── Time-of-day tint overlays ────────────────────────────────────────────────
# Multiply-blend tints over the room and pet: values near white = subtle, lower =
# deeper. Day = white (identity).
const TINT_DUSK_MUL  := Color(1.0, 0.88, 0.78)    # Multiply tint over room and Mochi from 17:00 to 20:00.
const TINT_NIGHT_MUL := Color(0.60, 0.65, 0.86)   # Multiply tint over room and Mochi from 20:00 to 05:00.
