// Carga de datos de prueba: 100 cuentas, 1900 contactos con codigo unico, 250 oportunidades.
String[] industrias = new String[]{'Retail','Banca','Salud','Educacion','Manufactura','Tecnologia','Turismo','Logistica'};
String[] ciudades = new String[]{'San Salvador','Santa Ana','San Miguel','La Libertad','Sonsonate','Usulutan','Ahuachapan','Chalatenango'};
String[] segmentos = new String[]{'Pyme','Corporativo','Gobierno','Inactivo','Pyme','Corporativo','Pyme','Startup','Pyme','Corporativo'};
String[] nombres = new String[]{'Ana','Carlos','Maria','Jose','Lucia','Miguel','Sofia','Diego','Valeria','Andres','Gabriela','Ricardo','Fernanda','Luis','Camila','Jorge'};
String[] apellidos = new String[]{'Hernandez','Martinez','Lopez','Garcia','Rodriguez','Ramirez','Flores','Cruz','Rivera','Alvarado','Mejia','Portillo','Gomez','Castillo'};

List<Account> cuentas = new List<Account>();
for (Integer i = 1; i <= 100; i++) {
    cuentas.add(new Account(
        Name = 'Empresa ' + industrias[Math.mod(i, industrias.size())] + ' ' + String.valueOf(i).leftPad(3, '0'),
        Industry = industrias[Math.mod(i, industrias.size())],
        BillingCity = ciudades[Math.mod(i, ciudades.size())],
        BillingCountry = 'El Salvador'
    ));
}
insert cuentas;

List<Contact> contactos = new List<Contact>();
for (Integer i = 1; i <= 1900; i++) {
    Account a = cuentas[Math.mod(i, cuentas.size())];
    String nom = nombres[Math.mod(i, nombres.size())];
    String ape = apellidos[Math.mod(i * 7, apellidos.size())];
    contactos.add(new Contact(
        FirstName = nom,
        LastName = ape,
        AccountId = a.Id,
        Email = (nom + '.' + ape + i + '@ejemplo.com.sv').toLowerCase(),
        Codigo_Cliente__c = 'CLI-' + String.valueOf(i).leftPad(5, '0'),
        Segmento__c = segmentos[Math.mod(i, segmentos.size())]
    ));
}
insert contactos;

List<Opportunity> opps = new List<Opportunity>();
for (Integer i = 1; i <= 250; i++) {
    Integer idx = Math.mod(i * 37, 1900) + 1; // codigo de cliente existente, repartido
    Contact c = contactos[idx - 1];
    opps.add(new Opportunity(
        Name = 'Oportunidad web ' + String.valueOf(i).leftPad(3, '0'),
        AccountId = c.AccountId,
        StageName = 'Prospecting',
        CloseDate = Date.today().addDays(Math.mod(i, 90) + 1),
        Amount = 500 + Math.mod(i * 113, 9500),
        Codigo_Cliente__c = c.Codigo_Cliente__c
    ));
}
insert opps;
System.debug('CARGA OK cuentas=' + cuentas.size() + ' contactos=' + contactos.size() + ' oportunidades=' + opps.size());
