#!/usr/bin/env bash
# Build and install the chihuahuad CLI from source.
#
#   ./install-chihuahuad.sh [VERSION]
#
# VERSION defaults to the latest known release (v9.0.7, builds with Go 1.23.9).
# ALWAYS confirm the current consensus version against the network before running a
# node: https://github.com/ChihuahuaChain/chihuahua/releases
# A node on the wrong version can halt at an upgrade height. For CLI-only use
# (querying, signing, deploying contracts via a public node), exact version is less
# critical, but staying current avoids proto/format drift.
set -euo pipefail

VERSION="${1:-v9.0.7}"
REPO="https://github.com/ChihuahuaChain/chihuahua"
SRC_DIR="${SRC_DIR:-$HOME/chihuahua-src}"

command -v go >/dev/null 2>&1 || {
  echo "Go is required (v9.0.7 needs Go 1.23.9). Install from https://go.dev/dl/ and re-run." >&2
  exit 1
}
command -v git >/dev/null 2>&1 || { echo "git is required." >&2; exit 1; }

echo ">> Go version: $(go version)"
echo ">> Building chihuahuad $VERSION into $SRC_DIR"

if [ -d "$SRC_DIR/.git" ]; then
  git -C "$SRC_DIR" fetch --tags --quiet
else
  git clone --quiet "$REPO" "$SRC_DIR"
fi

git -C "$SRC_DIR" checkout --quiet "$VERSION"
make -C "$SRC_DIR" install

GOBIN="$(go env GOBIN)"; GOBIN="${GOBIN:-$(go env GOPATH)/bin}"
echo
echo ">> Installed to $GOBIN/chihuahuad"
case ":$PATH:" in
  *":$GOBIN:"*) ;;
  *) echo ">> NOTE: add \$GOPATH/bin to PATH:  export PATH=\"\$PATH:$GOBIN\"" ;;
esac

"$GOBIN/chihuahuad" version 2>/dev/null || true
echo ">> Done. Next: source scripts/chihuahua-env.sh"
