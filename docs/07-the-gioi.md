# 07 — Thế giới mở

Code: `scripts/world/world.gd`, `plot_node.gd`, `day_night.gd`, `decor_factory.gd`.

## Bản đồ (nhìn từ trên xuống, bắc ở trên)

```
z = -60 ┌───────────────────────────────────────────────────────────────┐
        │   nhà dân          cây           nhà dân           cây        │
        │ ┌──┐ ┌──┐ ┌──┐  ┌────────┐ [bảng HĐ]  ┌──┐ ┌──┐ ┌──┐          │
        │ │A1│ │A2│ │A3│  │CỬA HÀNG│            │A4│ │A5│ │A6│          │
z = -6  │ └──┘ └──┘ └──┘  └────────┘            └──┘ └──┘ └──┘          │
        │═══════════════════════ ĐƯỜNG CHÍNH ═══════════════════════════│
z = +6  │ ┌──┐ ┌──┐ ┌──┐       ┌──────┐ [bàn vẽ] ┌──┐ ┌──┐ ┌──┐         │
        │ │  │ │  │ │  │       │ NHÀ  │          │  │ │  │ │  │ nhà dân  │
        │ └──┘ └──┘ └──┘       │ BẠN  │          └──┘ └──┘ └──┘         │
z = +60 └───────────────────────────────────────────────────────────────┘
      x = -100                                                      x = +100
```

- Lô đất lấy từ `data/plots.json`. Mặt trước lô (z lớn trong toạ độ lô) luôn hướng ra đường.
  Lô phía nam xoay 180°, nên cùng một bản vẽ vẫn có cửa chính quay ra đường.
- Nhân vật xuất hiện giữa đường, nhìn về phía cửa hàng và bảng hợp đồng.

## Sinh thế giới tất định

`World.build()` dùng `RandomNumberGenerator` với **seed cố định**, nên lần chạy nào cây và nhà trang trí cũng
ở đúng chỗ cũ. Nhờ đó test so sánh được, và file lưu không cần lưu vị trí cây.

Cây được rải bằng **lấy mẫu loại bỏ** (rejection sampling): chọn điểm ngẫu nhiên, bỏ điểm rơi vào vùng
cấm (đường, lô đất, cửa hàng, nhà) hoặc quá gần cây khác (< 3 m). Test kiểm tra không cây nào mọc trên lô đất
hay giữa đường.

## Hiệu năng

| Thứ | Cách vẽ |
|---|---|
| Cây (≈150), đèn đường, vạch kẻ đường | MultiMesh — mỗi loại một lần vẽ |
| Nhà trang trí | Mỗi căn một mesh gộp (MeshBuilder) + một hộp va chạm |
| Gạch, ngói, ô móng | MultiMesh (xem `02-xay-tuong.md`) |

## Ngày và đêm (`DayNight`)

- 1 ngày trong game = 20 phút ngoài đời. Giờ lưu ở `GameState.time_of_day`.
- Mặt trời mọc lúc 6h ở phía đông, lặn lúc 18h ở phía tây. Góc cao theo hàm sin; ánh sáng, màu trời và
  ánh sáng môi trường nội suy giữa ngày và đêm.
- Ban đêm đèn đường tự sáng (vật liệu phát sáng). Đêm được giữ đủ sáng để vẫn xây được.
