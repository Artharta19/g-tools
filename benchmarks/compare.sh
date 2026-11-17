#!/usr/bin/env bash
# Воспроизводимое сравнение g-grep с GNU grep на одинаковых данных.
# Числа из README («grep 7.7x») должны пересчитываться этой командой, а не браться на веру.
#
#   ./benchmarks/compare.sh [records] [pattern]
#
# Требования: собранный build/ (cmake -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j).
set -euo pipefail

RECORDS="${1:-2000000}"
PATTERN="${2:-NEEDLE_RECORD_1}"
BUILD_DIR="${BUILD_DIR:-build}"
TMP="${TMPDIR:-/tmp}/g_bench.csv"

if [ ! -x "$BUILD_DIR/g-grep" ] || [ ! -x "$BUILD_DIR/gen_data" ]; then
    echo "нет $BUILD_DIR/g-grep или $BUILD_DIR/gen_data — сначала соберите проект" >&2
    exit 1
fi

echo "данные: $RECORDS записей -> $TMP"
"$BUILD_DIR/gen_data" "$RECORDS" "$TMP" >/dev/null

# прогрев page cache — иначе первым всегда проигрывает тот, кто читает с диска
"$BUILD_DIR/g-grep" -c "$PATTERN" "$TMP" >/dev/null
grep -c "$PATTERN" "$TMP" >/dev/null

time_it() {
    local label="$1"; shift
    local best=""
    for _ in 1 2 3; do
        local start end ms
        start=$(date +%s%N)
        "$@" >/dev/null
        end=$(date +%s%N)
        ms=$(( (end - start) / 1000000 ))
        if [ -z "$best" ] || [ "$ms" -lt "$best" ]; then best="$ms"; fi
    done
    echo "$label $best"
}

read -r _ GREP_MS <<<"$(time_it grep grep -c "$PATTERN" "$TMP")"
read -r _ GGREP_MS <<<"$(time_it g-grep "$BUILD_DIR/g-grep" -c "$PATTERN" "$TMP")"

echo
echo "инструмент   лучший из 3 прогонов, мс"
echo "grep         $GREP_MS"
echo "g-grep       $GGREP_MS"

if [ "$GGREP_MS" -gt 0 ]; then
    awk -v a="$GREP_MS" -v b="$GGREP_MS" 'BEGIN { printf "ускорение   %.2fx\n", a / b }'
else
    echo "ускорение   (g-grep быстрее разрешения таймера)"
fi

echo
echo "Оговорка: результат зависит от размера файла (page cache), паттерна и числа совпадений."
echo "Для README берите медиану из нескольких запусков и указывайте железо."
