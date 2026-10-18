@IsTest
private class ContactoPrincipalBadTest {

    @IsTest
    static void asignaContactoEnLotePequeno() {
        List<Opportunity> opps = CasoSoqlTestData.crear(50);

        Test.startTest();
        ContactoPrincipalBad.asignar(opps);
        Integer consultas = Limits.getQueries();
        Test.stopTest();

        // La version mala gasta 1 consulta por registro
        Assert.areEqual(50, consultas, 'Se esperaba 1 SOQL por oportunidad');

        Integer asignadas = [SELECT COUNT() FROM Opportunity WHERE Contacto_Principal__c != null];
        Assert.areEqual(45, asignadas, 'Los contactos Inactivo (1 de cada 10) no se asignan');
    }
}
