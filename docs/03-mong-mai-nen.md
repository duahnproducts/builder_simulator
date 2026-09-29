# 03 — Móng, mái, nền

Code: `scripts/core/cell_progress.gd`, `roof_layout.gd`, `blueprint_analysis.gd` (`slab_rect`).

## Móng và nền theo ô (`CellProgress`)

Đào móng, đổ móng, lát nền và đổ mái bằng đều làm **theo từng ô 1 m²** của phần trong nhà.
Người chơi chọn ô nào làm trước cũng được. `CellProgress` giữ:

- `cells`: tất cả ô cần làm;
- `order`: các ô đã làm **theo thứ tự làm**. View vẽ `order` bằng MultiMesh, nên số ô hiển thị = `order.size()`.

**Tấm sàn (`slab_rect`)**: mỗi ô được nới thêm 0,1 m ở cạnh có tường, để móng/mái bằng phủ kín
cả phần dưới chân tường và các góc nhà.

| Hạng mục | Điều kiện | Vật tư mỗi ô |
|---|---|---|
| Đào móng | — | — |
| Đổ móng | Ô đó đã đào | 2 bao xi măng |
| Lát nền | Xây xong toàn bộ tường | 1 m² gạch lát |
| Đổ mái bằng | Xây xong toàn bộ tường | 2 bao xi măng |

## Mái ngói hai mái (`RoofLayout`)

Chỉ dùng cho nhà hình chữ nhật. Nóc chạy dọc theo **cạnh dài**; độ dốc 30°; mái đua ra 0,4 m.

```
            nóc (ridge)
             /\
    ngói    /  \   ngói            rise = (bề rộng / 2) · tan 30°
           /____\                  mặt mái nâng cao hơn tường hồi 0,15 m
  tường hồi (tam giác)             để gạch tường hồi không lòi lên mái
```

Thứ tự lợp là một dãy cố định, nên cũng chỉ cần lưu **một số nguyên** `roof_laid`:

1. **Tường hồi**: 2 tam giác gạch ở hai đầu nóc. Phải xây xong mới được lợp.
2. **Vì kèo**: chia đều giữa hai tường hồi, cách nhau ≤ 1,2 m.
3. **Ngói**: theo hàng từ mép mái lên nóc; mỗi hàng lợp bên này rồi bên kia.
4. **Ngói nóc**: phủ dọc đường nóc.

Số hàng = ⌈chiều dài mái dốc / 0,4⌉. Chiều dài thực của mỗi hàng được chia đều, để hàng cuối vừa khít nóc.

## Mái bằng

Mái bằng dùng lại cơ chế ô của móng, đặt ở đỉnh tường, dày 0,15 m. Loại mái này dùng được cho mọi hình dạng nhà
(chữ L, nhà ống...).
