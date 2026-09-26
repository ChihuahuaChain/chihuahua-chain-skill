#!/usr/bin/env bash
# Source this file to load Chihuahua (chihuahua-1) network context into your shell:
#   source scripts/chihuahua-env.sh
# It exports the standard env vars and defines a `huahua` wrapper around chihuahuad
# that injects --node/--chain-id so you don't repeat them on every command.
#
# Public endpoints rotate. To use a different node:  export RPC=https://<other-rpc>
# (See references/network.md for the full endpoint list.)

export CHAIN_ID="${CHAIN_ID:-chihuahua-1}"
export DENOM="${DENOM:-uhuahua}"
# not DISPLAY: that name belongs to X11, and overriding it breaks GUI apps
export DISPLAY_DENOM="${DISPLAY_DENOM:-HUAHUA}"
export DECIMALS="${DECIMALS:-6}"

export RPC="${RPC:-https://rpc.chihuahua.wtf}"
export WS="${WS:-wss://rpc.chihuahua.wtf/websocket}"
export REST="${REST:-https://api.chihuahua.wtf}"
export GRPC="${GRPC:-grpc.chihuahua.validatus.com:443}"

export GAS_PRICES="${GAS_PRICES:-1250uhuahua}"
export GAS_ADJUSTMENT="${GAS_ADJUSTMENT:-1.4}"

# Standard tx flags for state-changing commands.
export TXFLAGS="--chain-id $CHAIN_ID --node $RPC --gas auto --gas-adjustment $GAS_ADJUSTMENT --gas-prices $GAS_PRICES -y -b sync"
# Standard flags for read-only queries.
export QFLAGS="--node $RPC --output json"

# `huahua ...` == `chihuahuad ... --node $RPC` for queries; pass full TXFLAGS yourself
# for txs. This is a convenience for interactive use, not a substitute for being
# explicit in scripts.
huahua() {
  chihuahuad "$@" --node "$RPC"
}

# Quick sanity check that $RPC is a live chihuahua-1 node and how far it's synced.
huahua_health() {
  curl -s "$RPC/status" | jq '{network: .result.node_info.network, height: .result.sync_info.latest_block_height, catching_up: .result.sync_info.catching_up}'
}

# 🐕 woof: opt-in only (never runs unless you call `huahua woof`), so it never
# pollutes command output or scripts. Prints a chihuahua + a rotating dev tip.
huahua() {
  if [ "${1:-}" = "woof" ]; then
    local tips=(
      "Amounts are in uhuahua. 1 HUAHUA = 1000000 uhuahua. Don't drop a zero."
      "insufficient fee? Bump --gas-prices toward 2000uhuahua. The chain default is NOT 0.025."
      "Test contracts on a local devnet first. Mainnet HUAHUA is real money."
      "Public RPCs rotate. If a node times out, it's dead, not your code. Use a fallback."
      "Check 'chihuahuad query wasm params' before store-code. Upload may be permissioned."
      "A cross-chain transfer isn't done until the destination balance shows up. Track it."
    )
    local tip="${tips[$((RANDOM % ${#tips[@]}))]}"
    printf '%s\n' \
      '         / \__' \
      '        (    @\___    w o o f !' \
      '        /         O   chihuahua-1' \
      '       /   (_____/' \
      '      /_____/   U      🐕  HUAHUA' \
      "" \
      "  tip: $tip"
    return 0
  fi
  chihuahuad "$@" --node "$RPC"
}

echo "Chihuahua env loaded: CHAIN_ID=$CHAIN_ID RPC=$RPC"
echo "  helpers: huahua <cmd>   |   huahua_health   |   huahua woof  🐕"
