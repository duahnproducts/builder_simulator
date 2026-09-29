class_name Wallet
extends RefCounted
## Ví tiền (VND). Dùng số nguyên để không bị sai số làm tròn như số thực.

signal changed(balance: int)

var balance: int = 0:
	set(value):
		balance = value
		changed.emit(balance)


func can_afford(amount: int) -> bool:
	return amount >= 0 and amount <= balance


## Trừ tiền nếu đủ. Không đủ thì không trừ và trả về false.
func spend(amount: int) -> bool:
	if not can_afford(amount):
		return false
	balance -= amount
	return true


func earn(amount: int) -> void:
	if amount > 0:
		balance += amount
