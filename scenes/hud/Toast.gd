## Toast.gd
## A felt notice that drops in under the header and fades away on its own:
## achievement unlocked, bond level up or a newly revealed trait.
## Call one show_* method right after adding it to the tree.
extends PanelContainer

const P := preload("res://theme/Palette.gd")
const HOLD := 2.6

## trait id → [badge color, icon]
const TRAITS := {
	"glotona": [P.TERRACOTTA, "res://assets/icons/bowl.svg"],
	"juguetona": [P.MUSTARD, "res://assets/icons/ball.svg"],
	"dormilona": [P.DENIM, "res://assets/icons/moon.svg"],
	"mimosa": [P.ROSE, "res://assets/icons/heart.svg"],
}


func show_achievement(title_key: String) -> void:
	_badge(P.MUSTARD, "res://assets/icons/star.svg")
	%Ribbons.show()
	%Kicker.show()
	%Title.text = title_key
	%Detail.hide()
	_play()


func show_level(level: int) -> void:
	theme_type_variation = "ToastRosePanel"
	_badge(P.ROSE, "res://assets/icons/heart.svg")
	%Title.text = tr("BOND_LEVEL_UP") % level
	%Body.text = tr("BOND_BADGE") % level
	%Body.theme_type_variation = "LevelLabel"
	%Bar.show()
	%Bar.value = 8.0
	_play()


func show_trait(trait_id: String) -> void:
	var t: Array = TRAITS.get(trait_id, TRAITS["glotona"])
	_badge(t[0], t[1])
	%Title.text = "TRAIT_REVEAL_" + trait_id
	%Body.text = "«%s»" % tr("TRAIT_" + trait_id.to_upper() + "_IDLE")
	%Body.theme_type_variation = "QuoteLabel"
	_play()


func _badge(color: Color, icon: String) -> void:
	%Badge.color = color
	%Badge.icon_path = icon


func _play() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	tween.tween_interval(HOLD)
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
