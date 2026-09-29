class_name GeomUtil
extends RefCounted
## Hàm hình học dùng chung.


## Biến đổi đưa hộp đơn vị (cạnh 1, tâm ở gốc) thành hộp kích thước `size`, tâm `center`,
## trục X theo `x_axis`, trục Y theo `y_axis`.
## Trục Z luôn là X × Y nên hệ trục luôn thuận: nếu hệ trục bị lật (định thức âm),
## mặt tam giác sẽ bị vẽ ngược và hộp trông như trong suốt.
static func box_transform(center: Vector3, x_axis: Vector3, y_axis: Vector3, size: Vector3) -> Transform3D:
	var x := x_axis.normalized()
	var y := (y_axis - x * y_axis.dot(x)).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x * size.x, y * size.y, z * size.z), center)
