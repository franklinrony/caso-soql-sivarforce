"""Lee los logs de las corridas (scripts/medir.sh, scripts/query_plan.sh) y genera
resultados/metricas.json, resultados/resumen.md y las graficas en resultados/img/.

Uso:  python3 scripts/generar_resultados.py [alias-org]   (o ORG=mi-org ...)
El alias solo se usa como etiqueta en los resultados; este script no se conecta a la org.
Requiere: matplotlib (pip install matplotlib).
"""
import json, re, glob, statistics, os, sys, datetime
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "resultados")
ORG = sys.argv[1] if len(sys.argv) > 1 else os.environ.get("ORG", "mi-org")
API = os.environ.get("API_VERSION", "67.0")
if not glob.glob(f"{BASE}/logs/anon_*.log"):
    sys.exit("No hay logs en resultados/logs/. Corre primero scripts/medir.sh (ver README).")
runs = []
for f in sorted(glob.glob(f"{BASE}/logs/anon_*.log")):
    txt = open(f).read()
    m = re.search(r"METRICAS (\{.*\})", txt.replace("METRICAS ' + JSON", ""))
    name = os.path.basename(f)
    if m:
        d = json.loads(m.group(1)); d["archivo"] = name; d["ok"] = True; runs.append(d)
    else:
        err = re.search(r"System\.LimitException[^\n|]*", txt)
        mm = re.match(r"anon_(\w+?)_(\d+)_", name)
        if not mm: continue
        v, n = mm.groups()
        runs.append({"version": v, "registros": int(n), "ok": False, "error": err.group(0) if err else None, "archivo": name})

def limit_usage(path):
    t = open(path).read()
    blk = t[t.rfind("LIMIT_USAGE_FOR_NS|(default)|"):]
    g = lambda k: int(re.search(k + r": (\d+) out of", blk).group(1))
    return {"soql_consultas": g("Number of SOQL queries"), "filas": g("Number of query rows"),
            "dml": g("Number of DML statements"), "cpu_ms": g("Maximum CPU time"),
            "fatal_error": (re.search(r"FATAL_ERROR\|([^\n]*)", t) or [None, None])[1],
            "soql_execute_begin": t.count("SOQL_EXECUTE_BEGIN")}

def limit_usage_seguro(path):
    try: return limit_usage(path)
    except (AttributeError, TypeError): return None  # el log no trae LIMIT_USAGE_FOR_NS

# Si existen logs en resultados/logs/debug/debug_<Version>_<N>.log se usan esos; si no,
# se toma el bloque LIMIT_USAGE de la primera corrida de cada tamano (sf apex run ya incluye el log).
debug = {os.path.basename(p)[6:-4]: limit_usage_seguro(p) for p in sorted(glob.glob(f"{BASE}/logs/debug/debug_*.log"))}
if not debug:
    for p in sorted(glob.glob(f"{BASE}/logs/anon_*_r1.log")):
        debug[os.path.basename(p)[5:-7]] = limit_usage_seguro(p)
debug = {k: v for k, v in debug.items() if v}

def agg(v, n):
    rs = [r for r in runs if r["version"] == v and r["registros"] == n and r["ok"]]
    if not rs: return None
    med = lambda k: statistics.median(r[k] for r in rs)
    return {"corridas": len(rs), "soql_consultas": med("soql_consultas"), "soql_filas": med("soql_filas"),
            "cpu_ms_mediana": med("cpu_ms"), "cpu_ms_valores": [r["cpu_ms"] for r in rs],
            "tiempo_ms_mediana": med("tiempo_ms"), "tiempo_ms_valores": [r["tiempo_ms"] for r in rs],
            "heap_bytes_delta": med("heap_bytes_delta"), "heap_bytes_fin": med("heap_bytes_fin"),
            "dml": med("dml"), "asignadas": med("asignadas")}

resumen = {f"{v}_{n}": agg(v, n) for v in ("Bad", "Good") for n in (50, 99, 200, 250)}
err200 = next((r["error"] for r in runs if r["version"] == "Bad" and r["registros"] == 200 and not r["ok"]), None)
if err200:
    resumen["Bad_200"] = {"error": err200, "limit_usage_log": debug.get("Bad_200")}

plans = {}
for p in sorted(glob.glob(f"{BASE}/query_plan/*.json")):
    d = json.load(open(p)); k = os.path.basename(p)[:-5]
    plans[k] = {"soql": open(p[:-5] + ".soql").read().strip()[:300],
                "planes": [{k2: pl[k2] for k2 in ("leadingOperationType", "fields", "cardinality", "sobjectCardinality", "relativeCost")}
                           | {"notes": [x["description"] + " " + str(x["fields"]) for x in pl["notes"]]} for pl in d["plans"]]}

out = {"org": {"alias": ORG, "api": "v" + API, "fecha": datetime.datetime.now().astimezone().isoformat(timespec="minutes")},
       "datos": {"Account": 100, "Contact": 1900, "Opportunity": 250},
       "nota_harness": "Cada corrida es una ejecucion anonima independiente. El arnes usa 1 SOQL extra para leer las oportunidades; las metricas son el delta solo de la llamada al servicio. Se hace rollback al final para que todas las corridas usen los mismos datos.",
       "resumen": resumen, "debug_logs_limit_usage": debug, "query_plan": plans, "corridas": runs}
json.dump(out, open(f"{BASE}/metricas.json", "w"), indent=2, ensure_ascii=False)

# ---------- graficas ----------
plt.rcParams.update({"font.family": "DejaVu Sans", "font.size": 12, "axes.spines.top": False, "axes.spines.right": False})
RED, GREEN, GRAY = "#d64545", "#2e9e5b", "#888888"
os.makedirs(f"{BASE}/img", exist_ok=True)

def barras(fname, titulo, ylabel, ns, bad, good, linea=None, nota=None):
    import numpy as np
    x = np.arange(len(ns)); w = 0.36
    fig, ax = plt.subplots(figsize=(9, 5.2), dpi=150)
    b1 = ax.bar(x - w/2, [b if b is not None else 0 for b in bad], w, color=RED, label="Antes (ContactoPrincipalBad)")
    good = [g if g is not None else 0 for g in good]
    b2 = ax.bar(x + w/2, good, w, color=GREEN, label="Después (ContactoPrincipalGood)")
    for rect, v in zip(b1, bad):
        ax.annotate("ERROR\n101 SOQL" if v is None else f"{v:g}", (rect.get_x() + rect.get_width()/2, rect.get_height()),
                    ha="center", va="bottom", fontsize=10, color=RED, fontweight="bold", xytext=(0, 3), textcoords="offset points")
    for rect, v in zip(b2, good):
        ax.annotate(f"{v:g}", (rect.get_x() + rect.get_width()/2, rect.get_height()), ha="center", va="bottom",
                    fontsize=10, color=GREEN, fontweight="bold", xytext=(0, 3), textcoords="offset points")
    if linea:
        ax.axhline(linea[0], color=GRAY, ls="--", lw=1.2); ax.text(len(ns) - 0.5, linea[0] + 2, linea[1], ha="right", color=GRAY, fontsize=10)
    ax.set_xticks(x, [f"{n} oportunidades" for n in ns]); ax.set_ylabel(ylabel); ax.set_title(titulo, fontweight="bold", pad=14)
    ax.legend(frameon=False, loc="upper left"); ax.set_ylim(0, max([v for v in bad if v] + good + [1]) * 1.28)
    if nota: fig.text(0.01, 0.01, nota, fontsize=8.5, color=GRAY)
    fig.tight_layout(rect=(0, 0.03, 1, 1)); fig.savefig(f"{BASE}/img/{fname}"); plt.close(fig)

ns = [50, 99, 200]
r = lambda v, n, k: (resumen[f"{v}_{n}"] or {}).get(k)
fuente = "Datos reales: Developer Edition org, 100 cuentas / 1.900 contactos / 250 oportunidades. Mediana de las corridas."
barras("01_consultas_soql.png", "Consultas SOQL usadas por transacción", "Consultas SOQL", ns,
       [r("Bad", n, "soql_consultas") for n in ns], [r("Good", n, "soql_consultas") for n in ns],
       linea=(100, "Límite: 100 SOQL síncronas"), nota=fuente)
barras("02_cpu_ms.png", "Tiempo de CPU de Apex (ms)", "CPU (ms)", ns,
       [r("Bad", n, "cpu_ms_mediana") for n in ns], [r("Good", n, "cpu_ms_mediana") for n in ns], nota=fuente)
barras("03_tiempo_ms.png", "Tiempo total de la llamada (ms, incluye DML)", "Tiempo (ms)", ns,
       [r("Bad", n, "tiempo_ms_mediana") for n in ns], [r("Good", n, "tiempo_ms_mediana") for n in ns], nota=fuente)

# Query plan: costo relativo por plan considerado (solo si ya corriste scripts/query_plan.sh)
CLAVES_QP = ("bad_like_negativo", "good_igualdad", "good_in_200")
if all(k in plans for k in CLAVES_QP):
  fig, ax = plt.subplots(figsize=(9, 5.2), dpi=150)
  labels, costs, colors = [], [], []
  for k in CLAVES_QP:
      for pl in plans[k]["planes"]:
          labels.append(f"{k}\n{pl['leadingOperationType']} {','.join(pl['fields'])}".strip())
          costs.append(pl["relativeCost"]); colors.append(RED if k.startswith("bad") else GREEN)
  ax.barh(range(len(labels)), costs, color=colors); ax.set_yticks(range(len(labels)), labels, fontsize=8.5); ax.invert_yaxis()
  for i, c in enumerate(costs): ax.text(c, i, f"  {c:g}", va="center", fontsize=9)
  ax.set_xscale("log"); ax.set_xlabel("relativeCost (escala log)"); ax.set_title("Query Plan (REST ?explain=) — planes considerados", fontweight="bold")
  sc = plans["bad_like_negativo"]["planes"][0]["sobjectCardinality"]
  fig.text(0.01, 0.01, f"Org {ORG}, sobjectCardinality = {sc:,} contactos. Costo > 1 = no selectivo. El plan ganador es el de menor costo (primera fila).".replace(",", "."), fontsize=8.5, color=GRAY)
  fig.tight_layout(rect=(0, 0.03, 1, 1)); fig.savefig(f"{BASE}/img/04_query_plan_costo.png"); plt.close(fig)

else:
  print("Sin Query Plan en resultados/query_plan/: se omite la grafica 04.")

# ---------- resumen markdown ----------
def fila(n):
    b, g = resumen[f"Bad_{n}"], resumen[f"Good_{n}"]
    if b and "error" in b:
        lu = b["limit_usage_log"]
        bt = f"**ERROR** `{b['error']}`" + (f" (log: {lu['soql_consultas']}/100 SOQL, CPU {lu['cpu_ms']} ms al fallar)" if lu else "")
        if not g: return f"| {n} | {bt} | — | — | — | — | (sin datos) | | | | |"
        return f"| {n} | {bt} | — | — | — | — | {g['soql_consultas']:g} | {g['cpu_ms_mediana']:g} | {g['heap_bytes_delta']:g} | {g['tiempo_ms_mediana']:g} | {g['asignadas']:g} |"
    if not b or not g: return f"| {n} | (faltan corridas Bad o Good con este tamaño) | | | | | | | | | |"
    return (f"| {n} | {b['soql_consultas']:g} | {b['cpu_ms_mediana']:g} | {b['heap_bytes_delta']:g} | {b['tiempo_ms_mediana']:g} | {b['asignadas']:g} | "
            f"{g['soql_consultas']:g} | {g['cpu_ms_mediana']:g} | {g['heap_bytes_delta']:g} | {g['tiempo_ms_mediana']:g} | {g['asignadas']:g} |")

md = [f"# Caso SOQL: antes vs después (org {ORG})", "",
      "Datos: 100 Account, 1.900 Contact (Codigo_Cliente__c único, External ID), 250 Opportunity. Mediana de las corridas por tamaño; cada corrida es una ejecución anónima independiente con rollback al final.", "",
      "| Lote | Antes: SOQL | Antes: CPU ms | Antes: heap Δ bytes | Antes: tiempo ms | Antes: asignadas | Después: SOQL | Después: CPU ms | Después: heap Δ bytes | Después: tiempo ms | Después: asignadas |",
      "|---|---|---|---|---|---|---|---|---|---|---|"]
md += [fila(n) for n in (50, 99, 200)]
g = resumen["Good_250"]
if g:
    md.append(f"| 250 | (no probado: revienta igual que 200) | | | | | {g['soql_consultas']:g} | {g['cpu_ms_mediana']:g} | {g['heap_bytes_delta']:g} | {g['tiempo_ms_mediana']:g} | {g['asignadas']:g} |")
md += ["",
       "Valores individuales de CPU / tiempo por corrida están en `metricas.json` (`resumen.*.cpu_ms_valores`, `tiempo_ms_valores`).", "",
       "## Query Plan (REST `/query/?explain=`)", "", "| Consulta | Plan | Campos | cardinality | sobjectCardinality | relativeCost | Notas |", "|---|---|---|---|---|---|---|"]
for k, v in plans.items():
    for pl in v["planes"]:
        md.append(f"| {k} | {pl['leadingOperationType']} | {', '.join(pl['fields']) or '—'} | {pl['cardinality']} | {pl['sobjectCardinality']} | {pl['relativeCost']} | {'; '.join(pl['notes'])} |")
md += ["", "> Si `sobjectCardinality` sale en 1, las estadísticas del optimizador aún no se recalculan: vuelve a correr `scripts/query_plan.sh` al día siguiente.", "",
       "## Debug logs (LIMIT_USAGE_FOR_NS)", "", "| Corrida | SOQL | Filas | DML | CPU ms | SOQL_EXECUTE_BEGIN en log | Fatal error |", "|---|---|---|---|---|---|---|"]
for k, v in debug.items():
    md.append(f"| {k} | {v['soql_consultas']} | {v['filas']} | {v['dml']} | {v['cpu_ms']} | {v['soql_execute_begin']} | {v['fatal_error'] or '—'} |")
md += ["", "Los números del log son de toda la transacción (incluyen la consulta del arnés y el rollback)."]
open(f"{BASE}/resumen.md", "w").write("\n".join(md) + "\n")
print(json.dumps({k: v for k, v in resumen.items()}, indent=1)[:3000])
