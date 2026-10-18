#!/usr/bin/env bash
# Corre UNA medicion del caso y guarda el log en resultados/logs/.
# Uso:   scripts/medir.sh Bad|Good N [corrida] [alias-org]
# Ej.:   scripts/medir.sh Bad 99 1 mi-org
#        ORG=mi-org scripts/medir.sh Good 200 1
# Bad = version con problemas, Good = version corregida, N = cuantas oportunidades procesar.
set -u
cd "$(dirname "$0")/.."            # raiz del proyecto
V=${1:?Falta la version: Bad o Good}
N=${2:?Falta N (numero de oportunidades, p.ej. 50, 99, 200)}
R=${3:-1}
ORG=${4:-${ORG:-mi-org}}
case "$V" in Bad|Good) ;; *) echo "La version debe ser Bad o Good" >&2; exit 2;; esac
case "$N" in ''|*[!0-9]*) echo "N debe ser un numero" >&2; exit 2;; esac
export SF_DISABLE_TELEMETRY=true
mkdir -p resultados/logs
TMPD=$(mktemp -d "${TMPDIR:-/tmp}/medir.XXXXXX")
TMP="$TMPD/medir_${V}_${N}.apex"
sed -e "s/__N__/$N/" -e "s/__V__/$V/g" scripts/apex/medir.apex.tpl > "$TMP"
LOG="resultados/logs/anon_${V}_${N}_r${R}.log"
sf apex run -f "$TMP" -o "$ORG" > "$LOG" 2>&1
echo "exit=$? (log: $LOG)"
rm -rf "$TMPD"
# Opcional: GUARDAR_DEBUG=1 baja el debug log completo de la org (necesita un trace flag activo
# para tu usuario: Setup > Debug Logs > New). Sirve sobre todo para la corrida que falla (Bad 200),
# porque sf apex run no imprime el log cuando hay excepcion.
if [ "${GUARDAR_DEBUG:-0}" = "1" ]; then
  mkdir -p resultados/logs/debug
  sf apex get log --number 1 -o "$ORG" > "resultados/logs/debug/debug_${V}_${N}.log" 2>&1 \
    && echo "debug log: resultados/logs/debug/debug_${V}_${N}.log"
fi
grep -oE "METRICAS .*|System.LimitException[^|]*" "$LOG" | head -3
