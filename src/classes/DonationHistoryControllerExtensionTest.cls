@isTest public class DonationHistoryControllerExtensionTest {
    @testSetup public static void createAccountWithOpps() {
        Account acc = new Account(Name='Sohn Household');
        insert acc;
        Contact con = new Contact(FirstName='Judi',LastName='Sohn',AccountId=acc.Id);
        insert con;
       	Account acc2 = new Account(Name='Superorg');
        insert acc2;
       
        Schema.DescribeSObjectResult oppSchema = Schema.SObjectType.Opportunity; 
		Map<String,Schema.RecordTypeInfo> OppRecordTypeInfo = oppSchema.getRecordTypeInfosByName(); 
		Id rtId = OppRecordTypeInfo.get('Donation').getRecordTypeId();
		Id rtId2 = OppRecordTypeInfo.get('Major Gift').getRecordTypeId();

        List<Opportunity> oppsToInsert = new List<Opportunity>();
        oppsToInsert.add(new Opportunity(Name='1', StageName='Posted',Amount=100,CloseDate = Date.newInstance(2015,04,01), AccountId = acc.Id, RecordTypeId=rtId));
        oppsToInsert.add(new Opportunity(Name='2', StageName='Posted',Amount=100,CloseDate = Date.newInstance(2015,04,01), AccountId = acc.Id, RecordTypeId=rtId2));
        oppsToInsert.add(new Opportunity(Name='3', StageName='Posted',Amount=200,CloseDate = Date.newInstance(2013,04,01), AccountId = acc.Id, RecordTypeId=rtId));
        oppsToInsert.add(new Opportunity(Name='4', StageName='Posted',Amount=200,CloseDate = Date.newInstance(2013,04,01), AccountId = acc2.Id, RecordTypeId=rtId));
		insert oppsToInsert;
        
        insert new OpportunityContactRole(OpportunityId=oppsToInsert[3].Id,ContactId=con.Id,Role='Influencer');
    }
    @isTest public static void test_controller(){
        Account acc = [SELECT Id FROM Account LIMIT 1][0];
        ApexPages.StandardController sc = new ApexPages.StandardController(acc);
        Test.startTest();
        DonationHistoryControllerExtension ext = new DonationHistoryControllerExtension(sc);
        Test.stopTest();
        
        System.assertEquals(400, ext.AllTime);
    }
}