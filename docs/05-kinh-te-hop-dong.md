# 05 — Kinh tế và hợp đồng

Code: `scripts/autoload/catalog.gd`, `scripts/autoload/game_state.gd`, `scripts/core/inventory.gd`, `wallet.gd`, `money.gd`.

## Dữ liệu (`data/`)

| File | Nội dung |
|---|---|
| `items.json` | Vật phẩm: giá (VND), đơn vị, màu; nội thất có thêm `size` và `parts` (mô hình dựng từ khối hộp/trụ/cầu) |
| `blueprints.json` | 5 bản vẽ mẫu (nhà cấp 4, nhà hai phòng, nhà chữ L, nhà ống, nhà vườn) |
| `plots.json` | Vị trí lô đất trong thế giới (`position`, `yaw`) |
| `contracts.json` | Tiền khởi đầu và 5 hợp đồng |

Muốn thêm món nội thất mới: thêm một mục vào `items.json` với `"category": "noi_that"`, `size` và `parts`,
không cần sửa code. Test `test_catalog.gd` kiểm tra tính nhất quán của dữ liệu (giá > 0, hợp đồng trỏ đúng
bản vẽ/lô đất, bản vẽ hợp lệ...).

## Tiền và kho

- Tiền là **số nguyên** VND (`Wallet`), không dùng số thực để tránh sai số làm tròn.
- `Inventory.remove()` là **tất cả hoặc không gì**: không đủ số lượng thì không lấy gì.
- `GameState.buy_many()` cũng vậy: đủ tiền cho cả danh sách thì mới mua.
- Bán lại vật tư thừa được 70% giá mua.

## Hợp đồng

```
locked ──(đủ uy tín)──► available ──nhận──► active ──nghiệm thu──► done
                            ▲                 │
                            └──── huỷ (−1 uy tín) ─┘
```

- Mỗi lúc chỉ làm **một** hợp đồng (các hợp đồng khác ở trạng thái `busy`).
- **Tiền công = dự toán vật tư × margin**, làm tròn 100.000 đ. Dự toán tính bằng chính
  `ConstructionProject.remaining_materials()`, nên đổi giá vật tư thì tiền công tự cân bằng lại.
- Nghiệm thu chỉ đạt khi **mọi giai đoạn DONE**, kể cả đủ nội thất bắt buộc đặt *trong* nhà.
- Nhà xây xong vẫn đứng trên lô đất sau khi nghiệm thu.

## Đất nhà mình (chế độ tự do)

Lô `HOME` dành cho người chơi. Vẽ bản vẽ riêng ở bàn vẽ (xem `09-giao-dien.md`), rồi `start_home_project()`
kiểm tra hợp lệ trước khi tạo công trình. Đang xây dở thì phải phá bỏ mới đổi được bản vẽ.

## Chặn điều khiển

Mỗi bảng giao diện đang mở gọi `GameState.block_input(nguồn, true)`. Còn ít nhất một nguồn thì
`is_input_blocked()` là true: nhân vật đứng yên và chuột hiện ra. Nhờ vậy mở chồng hai bảng rồi đóng một bảng
cũng không làm nhân vật chạy lung tung.
