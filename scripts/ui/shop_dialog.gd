class_name ShopDialog
extends AcceptDialog
# The upgrade shop: each upgrade with its level, effect, next price, and Buy,
# which is off when the pilot cannot afford it or it is maxed.

signal purchased

## Upgrade id -> its row.
var rows := {}
var _box: VBoxContainer

func _ready() -> void:
	title = "Shop"
	ok_button_text = "Done"
	min_size = Vector2i(560, 0)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	# Deferred: the Buy button that caused it is still emitting.
	Garage.bought.connect(func(_u, _l): refresh(), CONNECT_DEFERRED)
	refresh()

func open() -> void:
	refresh()
	popup_centered()

func buy_button(id: StringName) -> Button:
	return rows[id].get_node("Buy") if rows.has(id) else null

func refresh() -> void:
	for c in _box.get_children():
		c.free()
	rows.clear()
	var wallet := Label.new()
	wallet.name = "Wallet"
	wallet.text = "Wallet  %d" % Wallet.balance
	_box.add_child(wallet)
	for u in Garage.upgrades.upgrades:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var text := Label.new()
		text.name = "Text"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.text = "%s   Lv %d/%d\n%s each" % [u.name, Garage.level(u.id), u.max_level(), u.effect_text()]
		text.add_theme_font_size_override("font_size", 15)
		row.add_child(text)
		var b := Button.new()
		b.name = "Buy"
		var p := Garage.price(u.id)
		b.text = "Buy  %d" % p if p >= 0 else "Maxed"
		b.disabled = not Garage.can_buy(u.id)
		b.custom_minimum_size.x = 130
		b.pressed.connect(func():
			if Garage.buy(u.id):
				purchased.emit())
		row.add_child(b)
		rows[u.id] = row
		_box.add_child(row)
