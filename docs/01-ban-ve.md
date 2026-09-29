# 01 — Bản vẽ mặt bằng

Code: `scripts/core/blueprint.gd`, `blueprint_analysis.gd`, `blueprint_validator.gd`.

## Mô hình dữ liệu

- Lô đất là lưới ô 1 m × 1 m, kích thước `size` (x, z). Điểm lưới đi từ `(0,0)` đến `size`.
- **Tường** nối hai điểm lưới `a → b`, luôn nằm ngang (cùng z) hoặc dọc (cùng x).
  Khi thêm tường, hai đầu được chuẩn hoá để `a < b`.
- **Lỗ mở** (`door` = cửa đi, `window` = cửa sổ) gắn vào một tường, cách điểm `a` một khoảng `offset` (mét).
  Kích thước lấy từ `BuildConst.OPENING_TYPES`.
- **Mái**: `gable` (mái ngói hai mái, chỉ cho nhà hình chữ nhật) hoặc `flat` (mái bằng bê tông).

JSON mẫu (`data/blueprints.json`):

```json
{"id": "nha_cap4_nho", "size": [12, 12], "roof": "gable",
 "walls": [[3, 3, 9, 3], [9, 3, 9, 8], [3, 8, 9, 8], [3, 3, 3, 8]],
 "openings": [{"wall": 2, "type": "door", "offset": 2.4}]}
```

## Phân tích bằng BFS (flood fill)

Tường chặn **cạnh** giữa hai ô kề nhau. Thuật toán:

1. Mở rộng lưới thêm 1 ô viền, rồi BFS từ góc `(-1, -1)`. Ô nào loang tới được là **ngoài trời**.
2. Ô trong lô đất mà không loang tới được là **trong nhà** (`interior_cells`).
3. BFS lần nữa trên các ô trong nhà để tách **phòng** (thành phần liên thông).
4. Đồ thị phòng: đỉnh = phòng và "ngoài trời", cạnh = cửa đi. BFS từ "ngoài trời" để tìm phòng không có lối vào.

Hàng đợi BFS dùng mảng + con trỏ `head` thay cho `pop_front()` (O(n) mỗi lần), nên cả thuật toán chạy O(số ô).

## Quy tắc hợp lệ (`BlueprintValidator`)

| Quy tắc | Thông báo |
|---|---|
| Có ít nhất 1 tường | "Chưa có bức tường nào." |
| Tường ngang/dọc, dài > 0, nằm trong lô | "Tường N ..." |
| Không chồng lên nhau, không cắt chéo nhau (chữ T và góc L thì được) | "... chồng lên ...", "... cắt ngang ..." |
| Tường khép kín thành ít nhất 1 phòng | "Các bức tường chưa khép kín ..." |
| Mỗi tường giáp ít nhất 1 ô trong nhà | "Tường N không bao quanh phòng nào ..." |
| Lỗ mở nằm gọn trong tường (cách đầu tường ≥ 0,2 m), không chồng nhau, không trùng chỗ tường khác nối vào | "Cửa N ..." |
| Phòng nào cũng có cửa đi thông ra ngoài | "Có N phòng không có cửa đi vào." |
| Mái ngói chỉ dùng cho nhà hình chữ nhật | "Mái ngói chỉ làm được ..." |

## Đọc dữ liệu an toàn

`Blueprint.from_dict()` không bao giờ crash khi JSON sai kiểu: giá trị sai kiểu được thay bằng mặc định
(`DataUtil`). Lỗi về ý nghĩa (tường cắt nhau...) do validator báo. Dữ liệu từ file lưu game cũng đi qua đường này.
