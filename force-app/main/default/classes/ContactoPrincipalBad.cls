/**
 * VERSION CON PROBLEMAS (antes).
 * Asigna a cada oportunidad su contacto principal buscando por Codigo_Cliente__c.
 * Problemas:
 *  1) SOQL dentro del for: 1 consulta por oportunidad -> con 200 registros
 *     revienta el limite de 100 consultas (System.LimitException: Too many SOQL queries: 101).
 *  2) Filtro no selectivo: LIKE con comodin al inicio ('%...%') y filtro negativo (!=)
 *     -> el optimizador no puede usar el indice y hace TableScan.
 */
public with sharing class ContactoPrincipalBad {

    public static void asignar(List<Opportunity> oportunidades) {
        for (Opportunity opp : oportunidades) {
            String patron = '%' + opp.Codigo_Cliente__c + '%';
            // Consulta dentro del bucle + filtro con comodin inicial
            List<Contact> encontrados = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Codigo_Cliente__c LIKE :patron
                  AND Segmento__c != 'Inactivo'
                LIMIT 1
            ];
            if (!encontrados.isEmpty()) {
                opp.Contacto_Principal__c = encontrados[0].Id;
            }
        }
        update oportunidades;
    }
}
