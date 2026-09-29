# 09 — Giao diện và phím điều khiển

Code: `scripts/ui/`. Toàn bộ giao diện dựng bằng code (không cần kéo thả), theme ở `ui_theme.gd`.

## Phím điều khiển

| Phím | Tác dụng |
|---|---|
| W A S D / mũi tên | Đi lại (Shift: chạy, Space: nhảy) |
| Chuột | Nhìn |
| Chuột trái | Thao tác: đào, đổ, xây, lắp, lợp, trát, lát, sơn, đặt đồ, nhặt đồ. **Giữ** để làm liên tục (xem dưới) |
| 1 · 2 · 3 · 4 | Chế độ: Xây dựng · Sơn tường · Nội thất · Nhặt đồ |
| Lăn chuột / Q · Z | Đổi màu sơn / món nội thất |
| R | Xoay món nội thất 90° |
| E | Tương tác: cửa, cửa hàng, bảng hợp đồng, bàn vẽ |
| B | Cửa hàng · J: Hợp đồng · P: Bàn vẽ |
| Esc | Đóng bảng đang mở / Menu tạm dừng |
| F5 / F9 | Lưu nhanh / Tải nhanh |
| F1 | Bật/tắt bảng hướng dẫn |

### Giữ chuột trái

Giữ chuột thì thao tác lặp lại theo nhịp (`BuildController.REPEAT`, vd. 0,1 giây/viên gạch), nhưng
**chỉ lặp đúng loại việc lúc bắt đầu giữ**. Ví dụ: giữ chuột lia qua các ô móng thì chỉ đào, không
tự đổ bê tông ngay sau khi đào; xây xong bức tường thì dừng, không tự trát (tránh tốn xi măng ngoài
ý muốn). Muốn sang việc khác thì thả chuột rồi bấm lại. Đặt và nhặt nội thất: mỗi lần bấm một món.

## Thành phần

| Thành phần | Nội dung |
|---|---|
| HUD | Tiền, uy tín, giờ; checklist giai đoạn của công trình đang đứng (hoặc hợp đồng đang làm); tâm ngắm + gợi ý thao tác; thanh công cụ 4 chế độ; thông báo (toast) |
| Cửa hàng | Tab theo nhóm vật tư; mua theo số lượng; bán lại 70%; **"Mua đủ cho công trình"** tính từ `remaining_materials()` trừ phần đã có trong kho |
| Hợp đồng | Danh sách + trạng thái; chi tiết (khách, mô tả, tiền công, dự toán, nội thất yêu cầu); xem trước bản vẽ; nhận / nghiệm thu / huỷ |
| Bàn vẽ | Vẽ tường bằng cách kéo chuột trên lưới; đặt cửa đi, cửa sổ; tẩy; **hoàn tác** (ngăn xếp các bản chụp); chọn mái; nạp mẫu; kiểm tra hợp lệ trực tiếp; dự toán; bắt đầu xây |
| Menu tạm dừng | Tiếp tục, lưu/tải 3 ô, ván mới, hướng dẫn, thoát. Game dừng hẳn (`get_tree().paused`) |

## Quy tắc mở/đóng bảng

- Mỗi bảng kế thừa `PanelBase`. `open()` gọi `GameState.block_input(id, true)`, `close()` gỡ ra;
  `main.gd` tự hiện/ẩn chuột theo trạng thái chặn.
- `UIRoot` chỉ cho mở **một** bảng tại một thời điểm. Esc đóng bảng đang mở; nếu không có bảng nào thì mở menu tạm dừng.
- `UIRoot` chạy cả khi game tạm dừng (`process_mode = ALWAYS`).

## Hoàn tác ở bàn vẽ (cấu trúc dữ liệu: stack)

Trước mỗi lần sửa, bàn vẽ đẩy **bản chụp** `blueprint.to_dict()` vào một mảng dùng như ngăn xếp.
"Hoàn tác" lấy bản chụp trên cùng ra (`pop_back()`) và dựng lại bản vẽ. Giới hạn 50 bản để không tốn bộ nhớ.
