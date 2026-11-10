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
export GRPC="${GRPC:-grpc.chihuahua.wtf:443}"

# 500uhuahua is the consensus minimum since v10.0.1; simulations underestimate, so pad by 1.6.
export GAS_PRICES="${GAS_PRICES:-500uhuahua}"
export GAS_ADJUSTMENT="${GAS_ADJUSTMENT:-1.6}"

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
      "insufficient fee? The floor is 500uhuahua per gas, in consensus. NOT 0.025, NOT 100."
      "Out of gas still costs the fee. Keep --gas-adjustment 1.6."
      "Test on woofnet-6 first: free HUAHUA at testnet-faucet.chihuahua.wtf."
      "Burn HUAHUA by sending it to chihuahua1d99pujdz48wkmn3uesfxnrctn44uuf5cuw5xuu."
      "Public RPCs rotate. If a node times out, it's dead, not your code. Use a fallback."
      "Only the Osmosis IBC channel is live: channel-7 <-> channel-113."
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
