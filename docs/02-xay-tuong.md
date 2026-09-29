# 02 — Xây tường từng viên gạch

Code: `scripts/core/wall_layout.gd`, `wall_geometry.gd`, `rect_merge.gd`.

## Hệ toạ độ của tường

Mỗi mảng tường có hệ toạ độ riêng: **u** chạy dọc tường (tính từ điểm `a` của bản vẽ), **v** đi từ chân tường lên.
`WallGeometry` đổi (u, v) sang toạ độ lô đất bằng `origin + dir·u + UP·v`.

## Bố cục gạch (`WallLayout`)

- Gạch 0,4 × 0,2 m, xây **so le** (running bond): hàng lẻ lệch nửa viên.
- Mạch gạch neo tại u = 0, nên cửa đặt ở bội số 0,2 m sẽ trùng mạch gạch.
- Mỗi hàng: chia khoảng [u_min, u_max] theo bước 0,4, cắt đầu cuối, rồi **khoét** các lỗ cửa cắt ngang hàng đó.
  Mẩu gạch ngắn hơn 5 cm thì bỏ.
- Thứ tự xây (`slots`): từ hàng dưới lên, trái sang phải. Vì thứ tự cố định, "đã xây k viên"
  nghĩa là k slot đầu, nên chỉ cần lưu **một số nguyên** cho mỗi tường. Lưu game gọn và hiển thị
  bằng `MultiMesh.visible_instance_count = k`.
- **Tường hồi** (tam giác dưới mái ngói): cùng thuật toán, nhưng khoảng xây của mỗi hàng
  thu hẹp dần theo chiều cao (tính tại tâm hàng).

## Mối nối góc

Tường dày 0,2 m nằm giữa đường lưới. Nếu để nguyên, góc chữ L sẽ vừa **chồng** vừa **hở** một ô 0,1 × 0,1.
Mỗi đầu tường được kéo dài (+0,1), giữ nguyên (0) hoặc thu lại (−0,1):

| Tình huống tại đầu tường | Tường ngang | Tường dọc |
|---|---|---|
| Đầu tự do | 0 | 0 |
| Góc L (1 ngang + 1 dọc) | +0,1 (ngang "sở hữu" ô góc) | −0,1 |
| Hai tường cùng phương nối thẳng | 0 | 0 |
| Chữ T (đâm vào hông tường khác) | −0,1 | −0,1 |

Kết quả: góc kín, không viên nào chồng lên viên nào (có unit test kiểm tra).

## Gộp va chạm (`RectMerge`)

Mỗi viên một hình va chạm thì rất tốn (một nhà có vài nghìn viên). Thay vào đó:

1. Trong mỗi hàng, nối các viên liền nhau thành **đoạn**.
2. Đoạn nào trùng khớp đoạn ở hàng ngay dưới thì **kéo dài** hình chữ nhật cũ lên.

Một bức tường có một cửa đi chỉ còn 3 hình chữ nhật: trái cửa, phải cửa, trên cửa.
Các hình này dùng cho: va chạm (tường đã xây), hình mờ (tường chưa xây), mảng trát/sơn.

## Trát và sơn

Mảng trát lấy từ `face_rects()`, nới thêm 0,1 m ở đầu tường bị thu lại để che kín góc ngoài.
Diện tích một mặt = tổng diện tích các slot (đã trừ lỗ cửa).
