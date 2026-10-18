# Caso SOQL: 101 de 100

Este es el proyecto que acompaña al artículo de SivarForce **«101 de 100: el código SOQL que pasó con 99 registros y se cayó con 200»** (enlace al artículo).

Con él podés armar el mismo escenario en tu propia org, ver cómo falla, arreglarlo y medir la diferencia con tus propios números.

## De qué se trata

Cada oportunidad (Opportunity) trae un código de cliente (`Codigo_Cliente__c`). El código Apex busca el contacto que tiene ese mismo código y lo pone como contacto principal (`Contacto_Principal__c`).

Hay dos versiones de la misma lógica:

| Clase | Qué hace | Resultado |
|---|---|---|
| `ContactoPrincipalBad` | Una consulta SOQL **por cada** oportunidad, dentro del `for`, con `LIKE '%código%'` y un filtro negativo (`!=`). | Con 99 registros usa 99 consultas. Con 200 se cae con `System.LimitException: Too many SOQL queries: 101`. |
| `ContactoPrincipalGood` | Junta los códigos en un `Set`, hace **una sola** consulta con `IN` sobre un campo indexado (External ID) y usa un `Map`. | Siempre usa 1 consulta, con 200, 250 o más registros. |

Qué trae el proyecto:

- `force-app/`: los 4 campos personalizados, las 2 clases, sus pruebas y el permission set `Caso_SOQL`.
- `scripts/apex/cargar_datos.apex`: crea 100 cuentas, 1,900 contactos y 250 oportunidades de prueba.
- `scripts/apex/medir.apex.tpl` y `scripts/medir.sh`: corren una versión con N registros y guardan las métricas (consultas, filas, CPU, heap y tiempo). Al final hacen rollback, así que tus datos no cambian entre corridas.
- `scripts/query_plan.sh` y `scripts/soql/query_plan/*.soql`: piden el Query Plan de las consultas por la API REST (`?explain=`).
- `scripts/generar_resultados.py`: junta todo en `resultados/metricas.json` y `resultados/resumen.md`, y crea las gráficas en `resultados/img/`.
- `scripts/apex/borrar_datos.apex`: borra solo los datos de prueba cuando termines.

## Qué necesitás

- Una **org Developer Edition**, que es gratis: https://developer.salesforce.com/signup. Mejor que no sea una org de trabajo.
- **Salesforce CLI** (`sf`): https://developer.salesforce.com/tools/salesforcecli
- **bash**, para los scripts `.sh`. En Windows sirve Git Bash o WSL.
- **Python 3** con **matplotlib**, solo si querés las gráficas: `pip install matplotlib`. `query_plan.sh` también usa Python 3, pero sin librerías extra.

### Si usás Windows

- Los scripts `.sh` (`medir.sh`, `query_plan.sh`) son de bash: corrélos con **Git Bash** o **WSL**.
- Los comandos `sf` (deploy, carga de datos, pruebas, `sf apex run`) funcionan igual en Windows, Mac y Linux, así que también los podés correr desde PowerShell o CMD.

En los ejemplos el alias de la org es `mi-org`. Podés usar el que querás.

## Paso a paso

Todos los comandos se corren desde la carpeta del proyecto.

### 1. Conectar tu org

```bash
sf org login web --alias mi-org
```

Se abre el navegador, iniciás sesión y le das permitir.

### 2. Subir los metadatos y darte permisos

```bash
sf project deploy start -o mi-org
sf org assign permset -n Caso_SOQL -o mi-org
```

El permission set te da acceso a los campos nuevos y a las clases.

### 3. Cargar los datos de prueba

```bash
sf apex run -f scripts/apex/cargar_datos.apex -o mi-org
```

Al final tiene que salir `CARGA OK cuentas=100 contactos=1900 oportunidades=250`. Corrélo **una sola vez**: el código de cliente del contacto es único, así que una segunda carga falla. Si querés volver a cargar, primero corré el paso 9.

### 4. Correr las pruebas

```bash
sf apex run test -n ContactoPrincipalBadTest -n ContactoPrincipalGoodTest -c -r human -w 10 -o mi-org
```

Las pruebas no usan los datos del paso 3: crean los suyos. Fijate que **verifican cuántas consultas se usan** (`Limits.getQueries()`). La mala con 50 registros gasta 50 consultas, y la buena con 200 gasta 1. Ese tipo de prueba es la que atrapa el problema antes de que llegue a producción.

### 5. Ver la falla y la corrección

```bash
# Version mala: con 99 pasa justito, con 200 se cae
scripts/medir.sh Bad 99 1 mi-org
scripts/medir.sh Bad 200 1 mi-org      # -> System.LimitException: Too many SOQL queries: 101

# Version corregida: con 200 y 250 sigue usando 1 consulta
scripts/medir.sh Good 200 1 mi-org
scripts/medir.sh Good 250 1 mi-org
```

El formato es `scripts/medir.sh <Bad|Good> <N registros> <número de corrida> [alias]`. En lugar del cuarto argumento también podés poner la variable `ORG=mi-org`. Cada corrida queda en `resultados/logs/anon_<Version>_<N>_r<corrida>.log`, y en pantalla sale la línea `METRICAS {...}` o el error.

Para sacar una mediana como en el artículo, repetí cada tamaño varias veces:

```bash
export ORG=mi-org
for r in 1 2 3; do
  for n in 50 99 200; do scripts/medir.sh Bad $n $r; scripts/medir.sh Good $n $r; done
  scripts/medir.sh Good 250 $r
done
```

**Opcional: el debug log completo de la corrida que falla.** Cuando hay una excepción, `sf apex run` no muestra el log. Para tenerlo, activá un trace flag para tu usuario en *Setup → Debug Logs → New* y corré:

```bash
GUARDAR_DEBUG=1 scripts/medir.sh Bad 200 log mi-org
```

El log queda en `resultados/logs/debug/debug_Bad_200.log`. Buscá `LIMIT_USAGE_FOR_NS`: ahí sale `Number of SOQL queries: 101 out of 100`.

### 6. Query Plan por la API

```bash
scripts/query_plan.sh mi-org
```

Guarda un JSON por consulta en `resultados/query_plan/` y muestra en pantalla el tipo de operación (`TableScan` o `Index`), la cardinalidad y el `relativeCost`. Un costo mayor que 1 quiere decir que la consulta no es selectiva.

> **Ojo:** Salesforce recalcula las estadísticas del optimizador más o menos **una vez al día**. Si cargaste los datos hoy, vas a ver `sobjectCardinality: 1` y costos que no sirven para nada. Volvé a correr este paso al día siguiente.

### 7. Gráficas y resumen

```bash
python3 scripts/generar_resultados.py mi-org
```

Genera `resultados/metricas.json`, `resultados/resumen.md` y las gráficas `resultados/img/01_consultas_soql.png`, `02_cpu_ms.png` y `03_tiempo_ms.png`. Si ya corriste el paso 6, también genera `04_query_plan_costo.png`. El alias es solo una etiqueta: este script no se conecta a la org.

### 8. Query Plan en la Developer Console

1. Abrí la Developer Console: el engranaje → *Developer Console*.
2. Activá el botón: *Help → Preferences → Enable Query Plan* = `true` → *Save*.
3. En la pestaña **Query Editor** pegá una consulta y dale al botón **Query Plan**, no a *Execute*.

Probá estas dos y compará:

```sql
-- Antes: comodin al inicio + filtro negativo
SELECT Id, AccountId FROM Contact
WHERE Codigo_Cliente__c LIKE '%CLI-00037%' AND Segmento__c != 'Inactivo' LIMIT 1

-- Despues: igualdad sobre el campo External ID (indexado)
SELECT Id, Codigo_Cliente__c FROM Contact
WHERE Codigo_Cliente__c = 'CLI-00037' AND Segmento__c != 'Inactivo'
```

En la segunda tiene que aparecer un plan `Index` sobre `Codigo_Cliente__c` con un costo muy por debajo del `TableScan`. En las notas vas a ver que `Segmento__c` e `IsDeleted` no se pueden optimizar. La misma advertencia del paso 6 aplica aquí: si los datos son de hoy, esperá un día.

### 9. Limpiar cuando termines

Los datos de prueba ocupan **unos 4.5 MB de los 5 MB** de almacenamiento de datos que trae una Developer Edition. Podés verlo en *Setup → Storage Usage*. Para liberarlo:

```bash
sf apex run -f scripts/apex/borrar_datos.apex -o mi-org
```

Este script borra **solo** lo que creó `cargar_datos.apex`:

- oportunidades «Oportunidad web …» con código `CLI-…`
- contactos con código `CLI-…` y correo `@ejemplo.com.sv`
- cuentas «Empresa …» de El Salvador que ya no tengan otros contactos ni oportunidades

Después vacía la papelera de esos registros. Los campos, las clases y el permission set se quedan. Si también querés quitarlos, borralos desde Setup.

## Problemas comunes

- **`No authorization information found for mi-org`**: repetí el paso 1 o revisá el alias con `sf org list`.
- **El deploy falla por la versión de la API**: bajá `sourceApiVersion` en `sfdx-project.json`, por ejemplo a `"62.0"`. Para `query_plan.sh` podés usar `API_VERSION=62.0 scripts/query_plan.sh mi-org`.
- **`sf api request rest` no existe**: actualizá el CLI con `sf update`. Si no, usá el Query Plan de la Developer Console del paso 8.
- **`DUPLICATE_VALUE` al cargar datos**: ya los habías cargado antes. Corré el paso 9 y volvé a cargar.

## Licencia

Licencia MIT (ver [LICENSE](LICENSE)). Podés usar, copiar y adaptar este proyecto como quieras: para aprender, en charlas o en tu trabajo. Si te sirvió, se agradece que menciones el artículo de SivarForce (enlace al artículo). Se entrega tal cual, sin garantías. Usalo en una org de pruebas, no en producción.
