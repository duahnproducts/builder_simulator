# 00 — Tổng quan kiến trúc

## Mục tiêu

Game giả lập xây nhà góc nhìn thứ nhất, thế giới mở, lấy cảm hứng từ *Builder Simulator*:
nhận hợp đồng → mua vật liệu → đào móng, đổ móng → xây tường từng viên gạch → lắp cửa →
lợp mái → trát, sơn → lát nền → bày nội thất → nghiệm thu nhận tiền.

**Phân công:** phần **nhân vật** do bạn tự làm (xem `08-nhan-vat.md`). Mọi phần khác đã có trong dự án.

## Công nghệ đã chốt

| Hạng mục | Lựa chọn | Lý do |
|---|---|---|
| Engine | Godot 4.7 (bản thường, không .NET) | Chạy được headless nên test tự động được; nhẹ trên RTX 4050 6 GB; miễn phí (MIT) |
| Ngôn ngữ | GDScript | Cú pháp gần Python |
| Renderer | Compatibility (OpenGL 3.3) | Là renderer duy nhất kiểm thử được trong môi trường cloud; chạy trên mọi máy |
| Đồ họa | Low-poly, mesh sinh bằng code | Không phụ thuộc asset ngoài; nhẹ |
| Dữ liệu | JSON trong `data/` | Dễ đọc, dễ sửa để cân bằng game |

Muốn đồ họa đẹp hơn trên máy bạn: *Project Settings → Rendering → Renderer* chọn `Forward+`.
Chế độ này chưa được kiểm thử trong môi trường cloud.

## Kiến trúc theo lớp

```
data/*.json ──► core/ (logic thuần, không cần scene) ──► building/ (hiển thị 3D)
                  ▲                                         ▲
                  │                                         │
autoload/ (GameState, Catalog, SaveSystem) ◄── player/ (điều khiển, raycast) ◄── ui/
```

- **core/**: toàn bộ luật chơi (bản vẽ, bố cục gạch, giai đoạn thi công, kho, tiền). Chỉ dùng `RefCounted`,
  không đụng tới scene, nên unit test chạy nhanh và chính xác.
- **building/**: đọc trạng thái từ core và vẽ ra 3D (MultiMesh cho gạch, ngói, ô móng).
- **player/**: `BuildController` bắn tia (raycast) từ camera đang dùng, rồi gọi API của core.
  Nó **không phụ thuộc** vào nhân vật cụ thể, chỉ cần có một `Camera3D` đang active.
- **ui/**: HUD, cửa hàng, hợp đồng, bàn vẽ, menu. Giao tiếp với game qua `GameState`.
- **autoload/**: trạng thái toàn cục và các dịch vụ dùng chung.

## Quy ước

| Quy ước | Giá trị |
|---|---|
| Đơn vị | mét; trục Y hướng lên |
| Lưới bản vẽ | ô 1 m × 1 m; tường nằm trên đường lưới |
| Viên gạch | dài 0,4 m, cao 0,2 m, dày 0,2 m (= độ dày tường) |
| Mặt móng | cao 0,3 m so với mặt đất |
| Tường | cao 3,0 m (15 hàng gạch) |
| Lớp va chạm | 1 world · 2 blueprint (hình mờ để nhắm) · 3 furniture · 4 interactable · 5 player |
| Code | Tên biến/hàm tiếng Anh; chú thích và chữ trong game tiếng Việt |

## Cấu trúc thư mục

```
data/            item, hợp đồng, bản vẽ mẫu, lô đất (JSON)
docs/            phương án kỹ thuật từng tính năng (đọc trước khi sửa code)
scenes/          scene gốc (main.tscn)
scripts/
  autoload/      InputActions, Catalog, GameState, SaveSystem
  core/          logic thuần + test được
  building/      hiển thị công trình 3D
  player/        BuildController, PlacementController, nhân vật tạm
  world/         sinh thị trấn, lô đất, cửa hàng, bảng hợp đồng, ngày đêm
  ui/            giao diện
tests/
  framework/     bộ chạy test tự viết (bắt cả lỗi runtime)
  unit/          test logic thuần
  integration/   test có scene tree, vật lý, raycast
  acceptance/    kịch bản chơi trọn một hợp đồng
tools/           script cài Godot, chạy test, chụp ảnh
```

## Chạy test

- Linux/cloud: `tools/run_tests.sh` (thêm `--filter=ten` để lọc).
- Windows (PowerShell, đứng ở thư mục dự án):
  `& "C:\duong\dan\Godot_v4.7.2-stable_win64_console.exe" --headless --path . res://tests/runner.tscn`
  Mã thoát 0 là đạt hết.

## Danh sách tài liệu

| File | Nội dung |
|---|---|
| `01-ban-ve.md` | Bản vẽ, kiểm tra hợp lệ, tìm phòng bằng BFS |
| `02-xay-tuong.md` | Bố cục gạch, mối nối góc, lỗ cửa, gộp va chạm |
| `03-mong-mai-nen.md` | Móng, mái ngói/mái bằng, tường hồi, lát nền |
| `04-thi-cong.md` | Giai đoạn thi công (DAG), vật tư, trát/sơn |
| `05-kinh-te-hop-dong.md` | Tiền, kho, cửa hàng, hợp đồng |
| `06-luu-game.md` | Lưu/tải JSON, phiên bản, an toàn |
| `07-the-gioi.md` | Thị trấn, lô đất, ngày đêm |
| `08-nhan-vat.md` | Giao kèo cho nhân vật — phần của bạn |
| `09-giao-dien.md` | HUD, cửa hàng, bàn vẽ, phím điều khiển |
