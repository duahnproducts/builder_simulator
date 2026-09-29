class_name BuildConst
extends RefCounted
## Hằng số kích thước và định mức dùng chung (đơn vị: mét). Xem docs/00-tong-quan.md.

const CELL := 1.0
const WALL_THICKNESS := 0.2
const HALF_WALL := WALL_THICKNESS / 2.0
const BRICK_LENGTH := 0.4
const BRICK_HEIGHT := 0.2
const MIN_BRICK_PIECE := 0.05

const FOUNDATION_TOP := 0.3
const DEFAULT_WALL_HEIGHT := 3.0
const FLOOR_TILE_THICKNESS := 0.03
const ROOF_SLAB_THICKNESS := 0.15

const ROOF_PITCH_DEG := 30.0
const ROOF_OVERHANG := 0.4
const ROOF_LIFT := 0.15
const ROOF_TILE_ROW := 0.4
const ROOF_TILE_SEGMENT := 1.0
const ROOF_TILE_THICKNESS := 0.05
const TRUSS_SPACING := 1.2

## Khoảng cách tối thiểu từ lỗ mở đến đầu tường.
const OPENING_MARGIN := 0.2

## Loại lỗ mở trên tường. "item" là vật tư cần để lắp.
const OPENING_TYPES := {
	"door": {"name": "Cửa đi", "width": 1.0, "height": 2.2, "sill": 0.0, "item": "door_wood"},
	"window": {"name": "Cửa sổ", "width": 1.2, "height": 1.2, "sill": 0.8, "item": "window_glass"},
}

## Định mức vật tư.
const CEMENT_PER_FOUNDATION_CELL := 2
const CEMENT_PER_ROOF_CELL := 2
const PLASTER_M2_PER_CEMENT := 6.0
const PAINT_M2_PER_CAN := 12.0
