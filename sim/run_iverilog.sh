#!/bin/bash
# Icarus Verilog 로 테스트벤치를 돌린다.  사용: sim/run_iverilog.sh [tb 이름 ...]  (없으면 전부)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/sim/work"
mkdir -p "$WORK"
cp "$ROOT"/rtl/*.mem "$ROOT"/sim/*.mem "$WORK"/
TBS="${@:-tb_trig tb_packet tb_periph tb_ext tb_physics tb_collision tb_play tb_top}"
cd "$WORK"
for tb in $TBS; do
    echo "== $tb"
    iverilog -g2005 -I "$ROOT/rtl" -I "$ROOT/sim" -s "$tb" -o "$tb.vvp" "$ROOT/sim/$tb.v" "$ROOT/sim/ad7908_model.v" "$ROOT"/rtl/*.v
    vvp "$tb.vvp" | grep -v '\$finish'
done
