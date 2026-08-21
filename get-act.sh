#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 DIR (installs 'act' binary to DIR)" >&2
	exit 1
fi

dest=$1
if [[ ! -d "$dest" ]]; then
	echo "not an existing directory: $dest" >&2
	exit 1
fi

os=$(uname -s)
arch=$(uname -m)
case "$os-$arch" in
	Linux-x86_64) asset=act_Linux_x86_64.tar.gz ;;
	Linux-aarch64) asset=act_Linux_arm64.tar.gz ;;
	Darwin-arm64) asset=act_Darwin_arm64.tar.gz ;;
	Darwin-x86_64) asset=act_Darwin_x86_64.tar.gz ;;
	*)
		echo "unsupported platform: $os $arch" >&2
		exit 1
		;;
esac

url="https://github.com/nektos/act/releases/latest/download/${asset}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "Downloading $url"
curl -fsSL -o "$tmp/act.tar.gz" "$url"
tar -xzf "$tmp/act.tar.gz" -C "$tmp" act
install -m 0755 "$tmp/act" "$dest/act"

echo "Installed $dest/act"
"$dest/act" --version
