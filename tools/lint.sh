#!/usr/bin/env bash
# Chạy test với các cảnh báo GDScript quan trọng bị nâng thành LỖI
# (biến không dùng, che tên, chia nguyên...). Giữ code sạch cảnh báo.
#
# Cách làm: tạo tạm file override.cfg (Godot tự đọc, ghi đè Project Settings),
# chạy test, rồi luôn xoá file đó — kể cả khi bị lỗi hoặc Ctrl+C.
set -uo pipefail
cd "$(dirname "$0")/.."

if [ -e override.cfg ]; then
	echo "Đã có override.cfg — không ghi đè. Hãy kiểm tra file đó trước." >&2
	exit 2
fi
trap 'rm -f override.cfg' EXIT

cat > override.cfg <<'EOF'
[debug]

gdscript/warnings/unused_variable=2
gdscript/warnings/unused_local_constant=2
gdscript/warnings/unused_private_class_variable=2
gdscript/warnings/unused_parameter=2
gdscript/warnings/unused_signal=2
gdscript/warnings/shadowed_variable=2
gdscript/warnings/shadowed_variable_base_class=2
gdscript/warnings/shadowed_global_identifier=2
gdscript/warnings/integer_division=2
gdscript/warnings/narrowing_conversion=2
gdscript/warnings/unreachable_code=2
gdscript/warnings/standalone_expression=2
gdscript/warnings/confusable_identifier=2
gdscript/warnings/incompatible_ternary=2
EOF

tools/run_tests.sh "$@"
