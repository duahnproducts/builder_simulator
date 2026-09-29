class_name Money
extends RefCounted
## Định dạng tiền Việt Nam đồng.


## 1234567 → "1.234.567 ₫"
static func format(amount: int) -> String:
	var digits := str(absi(amount))
	var groups := PackedStringArray()
	while digits.length() > 3:
		groups.insert(0, digits.substr(digits.length() - 3))
		digits = digits.substr(0, digits.length() - 3)
	groups.insert(0, digits)
	var text := ".".join(groups) + " ₫"
	return "-" + text if amount < 0 else text


## Dạng rút gọn cho HUD: 150000000 → "150 triệu ₫", 1500000000 → "1,5 tỷ ₫".
static func format_short(amount: int) -> String:
	var value := absi(amount)
	var text: String
	if value >= 1_000_000_000:
		text = _one_decimal(value / 1_000_000_000.0) + " tỷ ₫"
	elif value >= 1_000_000:
		text = _one_decimal(value / 1_000_000.0) + " triệu ₫"
	else:
		return format(amount)
	return "-" + text if amount < 0 else text


## 1.5 → "1,5"; 150.0 → "150" (tiếng Việt dùng dấu phẩy thập phân).
static func _one_decimal(value: float) -> String:
	var rounded := snappedf(value, 0.1)
	if is_equal_approx(rounded, roundf(rounded)):
		return str(int(roundf(rounded)))
	return ("%.1f" % rounded).replace(".", ",")
