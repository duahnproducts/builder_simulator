#!/usr/bin/env bash
# Chạy toàn bộ test ở chế độ headless (không cần màn hình).
#
#   tools/run_tests.sh                  # chạy tất cả
#   tools/run_tests.sh --filter=wall    # chỉ chạy test có tên chứa "wall"
set -uo pipefail
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
if ! command -v "$GODOT" >/dev/null 2>&1; then
	echo "Không tìm thấy Godot. Chạy tools/install_godot.sh trước." >&2
	exit 2
fi

# Import để Godot cập nhật cache class_name (cần khi thêm script mới).
import_log="$(mktemp)"
if ! timeout 300 "$GODOT" --headless --import --path . >"$import_log" 2>&1; then
	cat "$import_log"
	echo "Import thất bại." >&2
	rm -f "$import_log"
	exit 2
fi
if grep -qE "SCRIPT ERROR|Parse Error" "$import_log"; then
	grep -E -A2 "SCRIPT ERROR|Parse Error" "$import_log"
	echo "Có lỗi script khi import." >&2
	rm -f "$import_log"
	exit 1
fi
rm -f "$import_log"

log="$(mktemp)"
timeout 900 "$GODOT" --headless --path . res://tests/runner.tscn -- "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}

# Lưới an toàn: lỗi parse của script không phải test cũng làm hỏng lần chạy.
if grep -qE "Parse Error|Failed to load script" "$log"; then
	echo "Phát hiện lỗi parse/load script trong log." >&2
	status=1
fi
# Rò bộ nhớ lúc thoát (thường do hai class tham chiếu kiểu của nhau thành vòng) cũng là lỗi.
if grep -qE "leaked at exit|still in use at exit" "$log"; then
	grep -E "leaked at exit|still in use at exit" "$log" >&2
	echo "Phát hiện rò bộ nhớ lúc thoát — chạy lại với --verbose để xem chi tiết." >&2
	status=1
fi
rm -f "$log"
exit "$status"
