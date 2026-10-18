#!/usr/bin/env bash
# Corre el Query Plan (REST /query/?explain=) de las consultas en scripts/soql/query_plan/*.soql
# y guarda cada resultado en resultados/query_plan/<nombre>.json
# Uso:   scripts/query_plan.sh [alias-org]      (o ORG=mi-org scripts/query_plan.sh)
# Nota: en una org recien cargada las estadisticas del optimizador salen en 1 fila
# (sobjectCardinality: 1) hasta que Salesforce las recalcula (normalmente de un dia para otro).
set -u
cd "$(dirname "$0")/.."
ORG=${1:-${ORG:-mi-org}}
API=${API_VERSION:-67.0}
export SF_DISABLE_TELEMETRY=true
mkdir -p resultados/query_plan
for f in scripts/soql/query_plan/*.soql; do
  name=$(basename "$f" .soql); soql=$(cat "$f")
  enc=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote(sys.argv[1]))" "$soql")
  out="resultados/query_plan/$name.json"
  sf api request rest "/services/data/v$API/query/?explain=$enc" -o "$ORG" 2>/dev/null | sed -n "/^{/,\$p" > "$out"
  cp "$f" "resultados/query_plan/$name.soql"
  echo "$name: $(python3 -c "import json,sys;d=json.load(open(sys.argv[1]));print([(p['leadingOperationType'],p['fields'],p['cardinality'],p['sobjectCardinality'],p['relativeCost']) for p in d['plans']])" "$out" 2>/dev/null || echo 'ERROR: revisa el alias de la org y que estes logueado')"
done
