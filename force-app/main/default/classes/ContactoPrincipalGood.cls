/**
 * VERSION CORREGIDA (despues).
 *  1) Bulkificada: se juntan los codigos en un Set y se hace UNA sola consulta
 *     fuera del bucle; luego se resuelve en memoria con un Map.
 *  2) Filtro selectivo: igualdad / IN sobre Codigo_Cliente__c, que es
 *     External ID + Unique (Salesforce le crea indice) -> el plan usa Index.
 */
public with sharing class ContactoPrincipalGood {

    public static void asignar(List<Opportunity> oportunidades) {
        Set<String> codigos = new Set<String>();
        for (Opportunity opp : oportunidades) {
            if (String.isNotBlank(opp.Codigo_Cliente__c)) {
                codigos.add(opp.Codigo_Cliente__c);
            }
        }

        Map<String, Id> contactoPorCodigo = new Map<String, Id>();
        for (Contact c : [
            SELECT Id, Codigo_Cliente__c
            FROM Contact
            WHERE Codigo_Cliente__c IN :codigos
              AND Segmento__c != 'Inactivo'
        ]) {
            contactoPorCodigo.put(c.Codigo_Cliente__c.toUpperCase(), c.Id);
        }

        for (Opportunity opp : oportunidades) {
            if (String.isNotBlank(opp.Codigo_Cliente__c)) {
                Id contactoId = contactoPorCodigo.get(opp.Codigo_Cliente__c.toUpperCase());
                if (contactoId != null) {
                    opp.Contacto_Principal__c = contactoId;
                }
            }
        }
        update oportunidades;
    }
}
