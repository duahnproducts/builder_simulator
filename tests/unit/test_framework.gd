extends TestCase
## Kiểm tra chính bộ test: assert hoạt động đúng và input actions đã đăng ký.


func test_assert_eq_so_sanh_int_voi_float() -> void:
	# JSON trả về số dạng float — assert_eq phải coi 3 và 3.0 là bằng nhau.
	assert_eq(3, 3.0)
	assert_eq("abc", "abc")
	assert_eq([1, 2], [1, 2])


func test_assert_that_bai_ghi_nhan_loi() -> void:
	var probe := TestCase.new()
	probe.assert_eq(1, 2)
	probe.assert_true(false)
	assert_eq(probe.get_failures().size(), 2, "phải ghi nhận đủ 2 lỗi")


func test_input_actions_da_dang_ky() -> void:
	for action in ["move_forward", "primary", "interact", "open_shop", "tool_1", "cycle_next"]:
		assert_true(InputMap.has_action(action), "thiếu action " + action)


func test_input_actions_idempotent() -> void:
	var before := InputMap.action_get_events("interact").size()
	InputActions.register_all()
	assert_eq(InputMap.action_get_events("interact").size(), before)
