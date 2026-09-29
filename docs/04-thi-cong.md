# 04 — Giai đoạn thi công

Code: `scripts/core/construction_project.gd`, `stage_graph.gd`.

## Đồ thị giai đoạn (DAG)

```
đào móng → đổ móng → xây tường ─┬─► lắp cửa ──────────┐
                                ├─► lợp mái ──────────┤
                                ├─► trát ──► sơn ─────┼─► nội thất
                                └─► lát nền ──────────┘
```

`StageGraph.topological_order()` dùng **thuật toán Kahn**: lặp lại việc lấy giai đoạn
không còn phụ thuộc nào chưa xong. Nếu dữ liệu có chu trình, hàm trả về mảng rỗng (có test kiểm tra).
Checklist trên HUD hiển thị theo thứ tự này.

Trạng thái mỗi giai đoạn: **LOCKED** (phụ thuộc chưa xong), **AVAILABLE**, **DONE**.
Công trình hoàn thành khi mọi giai đoạn đều DONE.

## Điều kiện cho từng thao tác

Điều kiện ở mức **từng phần tử** thoáng hơn điều kiện mở khoá giai đoạn, nên người chơi làm linh hoạt hơn:

| Thao tác | Điều kiện | Vật tư |
|---|---|---|
| Xây 1 viên gạch | Đổ xong toàn bộ móng | 1 gạch |
| Lắp cửa | Bức tường chứa cửa đã xây xong | 1 bộ cửa tương ứng |
| Trát 1 mặt tường | Bức tường đó đã xây xong | ⌈diện tích / 6⌉ bao xi măng, trả khi bắt đầu |
| Sơn 1 mặt tường | Mặt đó đã trát xong | ⌈diện tích / 12⌉ thùng sơn màu đã chọn; đổi màu là sơn lại từ đầu |
| Đặt nội thất | Giai đoạn "Nội thất" đã mở; không vướng tường, cửa, đồ khác, **không chắn cửa đi** | 1 món đồ; nhặt lại thì trả về kho |

**Không chắn cửa đi:** mỗi cửa đi có một hộp "khoảng trống" (lớp va chạm 6 — clearance) gồm vùng
cánh cửa quét qua (sâu bằng bề rộng cửa, phía cửa mở vào) và lối đi 0,6 m ở phía bên kia.
`PlacementController` kiểm tra chồng lấn với lớp này (thảm thì được đặt, vì cánh cửa quét phía trên).
Nhân vật và tia nhắm không va vào lớp này.

## Kết quả thao tác

Mọi thao tác trả về `Result`: `OK`, `LOCKED` (chưa đủ điều kiện), `DONE` (đã làm rồi),
`NO_MATERIAL` (thiếu vật tư, **không** trừ gì), `INVALID` (sai chỉ số).
Controller dựa vào kết quả này để hiện thông báo.

## Vật tư còn thiếu

`remaining_materials()` tính chính xác vật tư cần cho **phần việc còn lại**. Có test đối chiếu:
xây xong cả căn nhà thì lượng vật tư tiêu thụ đúng bằng con số dự toán lúc đầu.
Nút "Mua đủ cho công trình" trong cửa hàng dùng hàm này.

## Lưu game

`to_dict()` / `from_dict()` chỉ lưu tiến độ: số nguyên cho gạch và mái, danh sách ô, tiến độ trát/sơn, nội thất.
Khi đọc, mọi giá trị đều bị **kẹp** vào khoảng hợp lệ, nên file lưu bị sửa tay cũng không làm hỏng game.
