# 08 — Nhân vật (phần của bạn)

Mọi hệ thống xây dựng **không phụ thuộc** vào nhân vật cụ thể. Dự án có sẵn một **nhân vật tạm**
(`scripts/player/player_placeholder.gd`) chỉ để chơi thử. Nhiệm vụ của bạn là làm nhân vật thật để thay nó.

## Giao kèo: game cần gì ở nhân vật

| # | Yêu cầu | Vì sao |
|---|---|---|
| 1 | Nằm trong nhóm (group) `"player"` | SaveSystem tìm nhân vật qua nhóm này để lưu vị trí |
| 2 | Có một `Camera3D` đang active (`current = true`, đặt **một lần** trong `_ready()`, đừng đặt lại mỗi frame) | `BuildController` bắn tia từ **camera đang active** để biết bạn nhắm vào đâu. Bài nghiệm thu mượn camera riêng để "nhìn thay" người chơi; đặt lại `current` mỗi frame sẽ giành mất camera đó |
| 3 | Đứng yên khi `GameState.is_input_blocked()` là `true` | Lúc đó người chơi đang mở cửa hàng, menu... |
| 4 | Lớp va chạm: **layer 5** (player); **mask 1 + 3** (world, furniture) | Không va vào lớp 2 (blueprint), nên đi xuyên qua hình mờ của tường chưa xây |
| 5 | *(Tuỳ chọn)* `get_save_state() -> Dictionary` và `apply_save_state(data)` | Để lưu/tải vị trí và hướng nhìn |

Phím đã có sẵn trong Input Map (đăng ký ở `scripts/autoload/input_actions.gd`):
`move_forward`, `move_back`, `move_left`, `move_right`, `jump`, `sprint`.

## Cách thay nhân vật tạm

1. Tạo scene nhân vật của bạn, ví dụ `scenes/player/player.tscn`.
2. Mở `scenes/main.tscn`, chọn node gốc `Main`, rồi trong Inspector kéo scene của bạn vào ô **Player Scene**.
3. Nhấn F5 để chạy. Nếu xây được gạch là giao kèo đã đúng.

## Hướng dẫn tự làm (gợi ý, không phải lời giải)

Làm lần lượt; xong mỗi bước thì chạy thử rồi mới sang bước sau.

### Bước 1 — Khung scene
- Node gốc là `CharacterBody3D`. Con của nó: `CollisionShape3D` với `CapsuleShape3D` (cao khoảng 1,75 m),
  và một `Node3D` tên `Head` ở độ cao mắt (khoảng 1,6 m) chứa `Camera3D`.
- **Câu hỏi**: vì sao nên xoay *thân* quanh trục Y nhưng chỉ xoay *đầu* quanh trục X?
  Thử xoay cả thân quanh X xem chuyện gì xảy ra với hướng đi.

### Bước 2 — Di chuyển
- Trong `_physics_process(delta)`: cộng trọng lực vào `velocity.y` khi `not is_on_floor()`.
- Đọc phím bằng `Input.get_vector(...)`, rồi đổi sang hướng thế giới bằng `transform.basis`.
- Cuối hàm gọi `move_and_slide()`.
- **Kiểm tra**: đi xuyên được qua hình mờ xanh của tường chưa xây, nhưng không xuyên được tường gạch đã xây.
  Nếu sai, xem lại bước 4 của giao kèo.

### Bước 3 — Nhìn bằng chuột
- Bắt `InputEventMouseMotion` trong `_unhandled_input(event)`; dùng `event.relative`.
- Giới hạn góc ngẩng/cúi bằng `clampf` (khoảng ±80°) để không lộn đầu.
- Chuột được bắt/nhả tự động theo giao diện (xem `scripts/main.gd`), bạn không cần tự làm.

### Bước 4 — Tôn trọng giao diện
- Đầu `_physics_process` và `_unhandled_input`: nếu `GameState.is_input_blocked()` thì bỏ qua phím
  (nhưng vẫn áp trọng lực để không lơ lửng).

### Bước 5 — Lưu/tải
- Trả về `{"pos": [x, y, z], "yaw": ..., "pitch": ...}`. Khi đọc lại, dùng `DataUtil.to_float()`
  để không crash nếu file lưu bị sửa tay. **Vì sao cần cẩn thận vậy?** Xem `docs/06-luu-game.md`.

### Nâng cao (khi đã chạy tốt)
- Góc nhìn thứ ba: `SpringArm3D` + `Camera3D` (camera tự co lại khi sau lưng có tường).
- Mô hình và hoạt ảnh: `AnimationTree` với trạng thái đứng / đi / chạy / nhảy.
- Âm thanh bước chân (`AudioStreamPlayer3D`), ngồi xuống, thể lực khi chạy.

## Tự kiểm tra
- Viết test theo mẫu trong `tests/integration/test_build_controller.gd`: tạo nhân vật của bạn,
  đặt vào một căn nhà, rồi kiểm tra `BuildController` nhắm được vào tường qua camera của nhân vật.
- Chạy toàn bộ test (lệnh PowerShell trong `README.md`). Bài nghiệm thu
  `tests/acceptance/test_choi_tron_game.gd` dựng scene chính **với nhân vật của bạn** rồi chơi trọn
  một hợp đồng, kể cả lưu/tải vị trí nhân vật (F5/F9) — vẫn đạt là giao kèo đã đúng.
