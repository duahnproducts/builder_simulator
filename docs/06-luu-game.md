# 06 — Lưu và tải game

Code: `scripts/autoload/save_system.gd` (đọc/ghi file), `GameState.to_dict()` / `from_dict()`
(trạng thái ván chơi), `ConstructionProject.to_dict()` / `from_dict()` (tiến độ từng công trình),
`get_save_state()` / `apply_save_state()` của nhân vật (xem `08-nhan-vat.md`).
Test: `tests/integration/test_save_system.gd`, `tests/unit/test_construction_project.gd`,
và bước F5/F9 trong bài nghiệm thu `tests/acceptance/test_choi_tron_game.gd`.

## Ô lưu và nơi lưu

| Ô lưu | Dùng khi |
|---|---|
| `slot1`, `slot2`, `slot3` | Menu tạm dừng (Esc) → Lưu / Tải |
| `quick` | F5 lưu nhanh, F9 tải nhanh |
| `auto` | Tự lưu mỗi 5 phút (chỉ khi có nhân vật và game không tạm dừng) |

File nằm ở `user://saves/<ô lưu>.json`. Trên Windows, `user://` của dự án này là
`%APPDATA%\Godot\app_userdata\Builder Simulator\`. Mở thư mục bằng PowerShell:

```powershell
explorer "$env:APPDATA\Godot\app_userdata\Builder Simulator\saves"
```

## Định dạng file

Chỉ lưu **tiến độ**, không lưu hình học: số viên gạch đã xây của từng tường, danh sách ô đã đào/đổ/lát,
tiến độ trát/sơn… Hình dạng nhà được tính lại từ bản vẽ (cùng bản vẽ luôn cho cùng kết quả), nên một
căn nhà xây xong chỉ tốn khoảng 5 KB.

```json
{
  "format": "builder_simulator_save",
  "saved_at": "2026-09-29 16:30:00",
  "game": {
    "version": 1,
    "money": 153308000,
    "inventory": {},
    "reputation": 1,
    "contracts": {"hd01": "done"},
    "active_contract": "",
    "day": 1,
    "time": 9.5,
    "projects": {
      "A1": {
        "plot": "A1",
        "blueprint": {"size": [14, 14], "roof": "gable", "walls": [[4, 6, 10, 6], "…"], "openings": ["…"]},
        "dig": [[4, 6], [4, 7], [4, 8], "…"],
        "bricks": [233, 180, 196, 180],
        "plaster": [[1.0, 1.0], "…"],
        "furniture": [{"uid": 1, "id": "bed", "pos": [5.2, 0.33, 7.4], "yaw": 0.0}]
      }
    }
  },
  "player": {"pos": [-63.0, 0.1, -7.0], "yaw": 0.0, "pitch": 0.0}
}
```

(Ví dụ lấy từ ván chơi thật: vốn 120 triệu, mua vừa đủ vật tư hợp đồng hd01 hết 55.492.000 ₫,
nghiệm thu nhận 88.800.000 ₫; `"…"` là chỗ lược bớt.) `"format"` là dấu nhận biết file của game này. `"player"` do nhân vật tự quyết định có gì
(SaveSystem chỉ chuyển nguyên dictionary qua lại).

## Phiên bản

`GameState.SAVE_VERSION` (hiện là 1) ghi vào `game.version`. Khi tải:

- `version` < 1 hoặc > `SAVE_VERSION` → từ chối, báo "từ phiên bản mới hơn", **trạng thái đang chơi giữ nguyên**.
- Sau này đổi định dạng: tăng `SAVE_VERSION`, thêm bước chuyển đổi trong `from_dict()`
  (ví dụ `if version == 1: data = _migrate_1_to_2(data)`), để file cũ vẫn mở được.

## An toàn: coi file lưu là dữ liệu KHÔNG đáng tin

File lưu có thể bị người chơi sửa tay, hỏng do mất điện, hoặc là file ai đó gửi qua mạng.
Mỗi mối nguy dưới đây đều có test kiểm chứng.

| Mối nguy | Cách chặn | Test |
|---|---|---|
| **Chạy mã độc khi mở file** (insecure deserialization — OWASP A08) | Chỉ dùng `JSON.parse()`: kết quả chỉ là dữ liệu thuần (số, chuỗi, mảng, dictionary). **Không bao giờ** dùng `load()` / `ResourceLoader` (file `.tres`/`.res` có thể nhúng script chạy ngay khi tải) hay `str_to_var` / `bytes_to_var_with_objects` (tạo được Object) với file của người dùng. | (quy tắc code, xem đầu `save_system.gd`) |
| **Path traversal** (CWE-22): tên ô lưu kiểu `../../x` để ghi ra ngoài thư mục lưu | Tên ô lưu chỉ gồm `a-z 0-9 _`, tối đa 32 ký tự (danh sách cho phép, không phải danh sách cấm) | `test_chan_ten_o_luu_nguy_hiem` |
| **File khổng lồ** (từ chối dịch vụ, CWE-400) | Kiểm tra kích thước ≤ 8 MB **trước khi** đọc nội dung | `test_file_qua_lon` |
| **File hỏng / không phải của game** | Báo lỗi JSON kèm số dòng; kiểm tra dấu `"format"`; trạng thái đang chơi giữ nguyên | `test_file_hong_khong_lam_doi_trang_thai` |
| **Giá trị bị sửa tay**: tiền âm, số gạch vượt tường, vật phẩm lạ, màu sơn lạ, bản vẽ hỏng hoặc to hơn lô đất, lô đất không tồn tại | Mọi số bị **kẹp** vào khoảng hợp lệ; vật phẩm/màu không có trong danh mục bị bỏ; bản vẽ được `BlueprintValidator` kiểm tra lại, hỏng thì bỏ công trình đó và báo cho người chơi | `test_file_luu_bi_sua_tay_khong_lam_hong_game`, `test_tai_du_lieu_bi_sua_tay` |
| **Tắt game giữa lúc lưu** | Ghi ra `<ô>.json.tmp` rồi mới đổi tên thành `<ô>.json` (ghi nguyên tử). Nếu game tắt đúng lúc đã xoá file cũ mà chưa kịp đổi tên, lần tải sau đọc file `.tmp` (đã ghi đủ) | `test_khoi_phuc_khi_tat_game_giua_luc_luu` |
| **Chạy test làm mất file lưu thật** | Bộ chạy test chuyển `SaveSystem.save_dir` sang `user://test_saves`, tắt tự lưu, xoá thư mục đó khi chạy xong | `test_bo_test_khong_dung_file_luu_that` |

**Không mã hoá, không ký số file lưu** — có chủ ý: đây là game chơi một mình, người chơi sửa file
thì chỉ ảnh hưởng chính họ. Nếu sau này có bảng xếp hạng online thì phải kiểm tra ở **máy chủ**,
vì mọi thứ nằm trên máy người chơi (kể cả khoá mã hoá giấu trong game) đều có thể bị đọc và sửa.

## Luồng tải

```
read_slot(ô)                       chỉ đọc + kiểm tra, chưa đụng vào game
  ├─ tên ô hợp lệ? file tồn tại (hoặc .tmp)? ≤ 8 MB? JSON đúng? đúng "format"?
  └─ lỗi → trả về {"error": ...}   (trạng thái game không đổi)
GameState.from_dict(game)
  ├─ version hợp lệ?               (sai → trả lỗi, trạng thái không đổi)
  ├─ tiền, uy tín, giờ: kẹp giá trị; kho: bỏ vật phẩm lạ
  ├─ mỗi công trình: ConstructionProject.from_dict()
  │     ├─ bản vẽ không hợp lệ → null (bỏ qua)
  │     └─ kẹp số gạch, ô, tiến độ; rồi drop_unknown_items()
  └─ phát signal → World dựng lại HouseView cho từng lô
apply_save_state(player)           nhân vật về đúng chỗ
```

## Tự luyện (gợi ý)

1. Mở một file lưu bằng VS Code, đổi `"money"` thành `-5` rồi tải lại: tiền là bao nhiêu? Tìm dòng code quyết định điều đó.
2. Thử đặt tên ô lưu `..\\..\\hack` trong `SaveSystem.save_slot()` (qua một test mới): hàm trả về gì? Vì sao dùng danh sách **cho phép** an toàn hơn danh sách **cấm** (ví dụ chỉ cấm `..`)?
3. Thêm trường `"weather"` vào file lưu với `SAVE_VERSION = 2`, viết bước chuyển đổi cho file version 1 và một test chứng minh file cũ vẫn mở được.
