#!/bin/bash
# SessionStart hook cho Claude Code trên web: cài Godot để chạy được test và lint ngay khi mở phiên.
# Chạy đồng bộ (phiên bắt đầu sau khi cài xong), idempotent (đã cài thì chỉ kiểm tra lại),
# và KHÔNG làm gì trên máy cá nhân (Windows của bạn tự cài Godot theo README.md).
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

cd "${CLAUDE_PROJECT_DIR:-$(dirname "$0")/../..}"

# Tải Godot 4.7.2 bản Linux từ GitHub, kiểm tra SHA-512, tạo lệnh "godot" (in ra đường dẫn file chạy).
godot_bin="$(tools/install_godot.sh)"

# Cho các lệnh trong phiên dùng đúng file chạy này (tools/run_tests.sh đọc biến GODOT),
# kể cả khi thư mục chứa lệnh "godot" không nằm trong PATH.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export GODOT=\"$godot_bin\"" >> "$CLAUDE_ENV_FILE"
fi

# Import trước để dựng cache class_name (.godot/) — lần chạy test đầu tiên sẽ nhanh hơn.
timeout 300 "$godot_bin" --headless --import --path . >/dev/null 2>&1 || true

echo "Godot $("$godot_bin" --version) sẵn sàng. Chạy test: tools/run_tests.sh — lint: tools/lint.sh"
