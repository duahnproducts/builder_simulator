#!/usr/bin/env bash
# Tải Godot (bản Linux, không cần .NET) và kiểm tra SHA-512 với file checksum chính thức.
# Dùng cho môi trường Linux (cloud session, CI). Trên Windows hãy tải tay từ godotengine.org.
#
#   tools/install_godot.sh          # cài nếu chưa có, in ra đường dẫn file chạy
#   GODOT_VERSION=4.7.2 tools/install_godot.sh
set -euo pipefail

VERSION="${GODOT_VERSION:-4.7.2}"
NAME="Godot_v${VERSION}-stable_linux.x86_64"
DEST="${GODOT_HOME:-$HOME/.local/share/godot/$VERSION}"
BIN="$DEST/$NAME"
BASE_URL="https://github.com/godotengine/godot/releases/download/${VERSION}-stable"

link_binary() {
	# Tạo lệnh "godot" trong PATH (ưu tiên /usr/local/bin nếu ghi được).
	local target_dir="/usr/local/bin"
	[ -w "$target_dir" ] || target_dir="$HOME/.local/bin"
	mkdir -p "$target_dir"
	ln -sf "$BIN" "$target_dir/godot"
}

if [ -x "$BIN" ]; then
	link_binary
	echo "$BIN"
	exit 0
fi

mkdir -p "$DEST"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

curl -fsSL --retry 4 --retry-delay 2 -o "$tmp/$NAME.zip" "$BASE_URL/$NAME.zip"
curl -fsSL --retry 4 --retry-delay 2 -o "$tmp/SHA512-SUMS.txt" "$BASE_URL/SHA512-SUMS.txt"

expected="$(grep " $NAME.zip\$" "$tmp/SHA512-SUMS.txt" | awk '{print $1}')"
actual="$(sha512sum "$tmp/$NAME.zip" | awk '{print $1}')"
if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
	echo "LỖI: checksum SHA-512 không khớp — không cài file này." >&2
	exit 1
fi

unzip -q -o "$tmp/$NAME.zip" -d "$DEST"
chmod +x "$BIN"
link_binary
echo "$BIN"
