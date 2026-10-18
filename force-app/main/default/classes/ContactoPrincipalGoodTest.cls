@IsTest
private class ContactoPrincipalGoodTest {

    @IsTest
    static void asignaContactoEnLoteDe200ConUnaSolaConsulta() {
        List<Opportunity> opps = CasoSoqlTestData.crear(200);

        Test.startTest();
        ContactoPrincipalGood.asignar(opps);
        Integer consultas = Limits.getQueries();
        Test.stopTest();

        Assert.areEqual(1, consultas, 'La version bulkificada debe usar 1 sola consulta');

        Integer asignadas = [SELECT COUNT() FROM Opportunity WHERE Contacto_Principal__c != null];
        Assert.areEqual(180, asignadas, 'Los contactos Inactivo (1 de cada 10) no se asignan');
    }

    @IsTest
    static void ignoraOportunidadesSinCodigo() {
        List<Opportunity> opps = CasoSoqlTestData.crear(5);
        for (Opportunity o : opps) { o.Codigo_Cliente__c = null; }

        Test.startTest();
        ContactoPrincipalGood.asignar(opps);
        Test.stopTest();

        Assert.areEqual(0, [SELECT COUNT() FROM Opportunity WHERE Contacto_Principal__c != null]);
    }
}
