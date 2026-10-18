@IsTest
public class CasoSoqlTestData {
    /** Crea cuentas, contactos con codigo y oportunidades que apuntan a esos codigos. */
    public static List<Opportunity> crear(Integer numOportunidades) {
        Account cuenta = new Account(Name = 'Cuenta Test SOQL');
        insert cuenta;

        List<Contact> contactos = new List<Contact>();
        for (Integer i = 0; i < numOportunidades; i++) {
            contactos.add(new Contact(
                LastName = 'Contacto ' + i,
                AccountId = cuenta.Id,
                Codigo_Cliente__c = 'TST-' + String.valueOf(i).leftPad(5, '0'),
                Segmento__c = (Math.mod(i, 10) == 0) ? 'Inactivo' : 'Pyme'
            ));
        }
        insert contactos;

        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < numOportunidades; i++) {
            opps.add(new Opportunity(
                Name = 'Opp Test ' + i,
                AccountId = cuenta.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(30),
                Codigo_Cliente__c = 'TST-' + String.valueOf(i).leftPad(5, '0')
            ));
        }
        insert opps;
        return [SELECT Id, Codigo_Cliente__c FROM Opportunity WHERE Id IN :opps];
    }
}
