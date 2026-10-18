// Borra SOLO los datos de prueba que crea scripts/apex/cargar_datos.apex y vacia la papelera
// para liberar el almacenamiento de datos de la org.
// Uso: sf apex run -f scripts/apex/borrar_datos.apex -o mi-org
// Criterios (los mismos patrones que usa la carga):
//   Opportunity: Name 'Oportunidad web ...' + Codigo_Cliente__c 'CLI-...'
//   Contact:     Codigo_Cliente__c 'CLI-...' + Email '@ejemplo.com.sv'
//   Account:     Name 'Empresa ...', BillingCountry 'El Salvador', y solo si ya no le quedan
//                otros contactos ni oportunidades (asi no se borra nada que sea tuyo).

List<Opportunity> opps = [
    SELECT Id FROM Opportunity
    WHERE Codigo_Cliente__c LIKE 'CLI-%' AND Name LIKE 'Oportunidad web %'
];
List<Contact> contactos = [
    SELECT Id, AccountId FROM Contact
    WHERE Codigo_Cliente__c LIKE 'CLI-%' AND Email LIKE '%@ejemplo.com.sv'
];
Set<Id> cuentaIds = new Set<Id>();
for (Contact c : contactos) { if (c.AccountId != null) cuentaIds.add(c.AccountId); }

delete opps;
delete contactos;

List<Account> cuentas = new List<Account>();
for (Account a : [
    SELECT Id, (SELECT Id FROM Contacts LIMIT 1), (SELECT Id FROM Opportunities LIMIT 1)
    FROM Account
    WHERE Id IN :cuentaIds AND Name LIKE 'Empresa %' AND BillingCountry = 'El Salvador'
]) {
    if (a.Contacts.isEmpty() && a.Opportunities.isEmpty()) cuentas.add(a);
}
delete cuentas;

// Vaciar la papelera de estos registros para recuperar el espacio de inmediato.
List<SObject> borrados = new List<SObject>();
borrados.addAll((List<SObject>) opps);
borrados.addAll((List<SObject>) contactos);
borrados.addAll((List<SObject>) cuentas);
if (!borrados.isEmpty()) Database.emptyRecycleBin(borrados);

System.debug('BORRADO OK oportunidades=' + opps.size() + ' contactos=' + contactos.size() + ' cuentas=' + cuentas.size());
