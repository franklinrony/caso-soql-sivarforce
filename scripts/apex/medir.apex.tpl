// Arnes de medicion: procesa N oportunidades con la version indicada y mide limites.
Integer N = __N__;
List<Opportunity> opps = [SELECT Id, Codigo_Cliente__c, Contacto_Principal__c FROM Opportunity ORDER BY Name LIMIT :N];
Savepoint sp = Database.setSavepoint();

Integer q0 = Limits.getQueries();
Integer rows0 = Limits.getQueryRows();
Integer cpu0 = Limits.getCpuTime();
Integer heap0 = Limits.getHeapSize();
Integer dml0 = Limits.getDmlStatements();
Long t0 = System.currentTimeMillis();

ContactoPrincipal__V__.asignar(opps);

Long t1 = System.currentTimeMillis();
Map<String, Object> m = new Map<String, Object>{
    'version' => '__V__',
    'registros' => N,
    'soql_consultas' => Limits.getQueries() - q0,
    'soql_filas' => Limits.getQueryRows() - rows0,
    'cpu_ms' => Limits.getCpuTime() - cpu0,
    'heap_bytes_fin' => Limits.getHeapSize(),
    'heap_bytes_delta' => Limits.getHeapSize() - heap0,
    'dml' => Limits.getDmlStatements() - dml0,
    'tiempo_ms' => t1 - t0,
    'limite_soql' => Limits.getLimitQueries()
};
Integer asignadas = 0;
for (Opportunity o : opps) { if (o.Contacto_Principal__c != null) asignadas++; }
m.put('asignadas', asignadas);
Database.rollback(sp); // dejamos los datos igual para que cada corrida sea comparable
System.debug('METRICAS ' + JSON.serialize(m));
