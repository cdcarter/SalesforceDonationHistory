@isTest public class DonationHistoryGridTest {
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


        Integer orgFiscalMonth = [SELECT FiscalYearStartMonth FROM Organization].FiscalYearStartMonth;


        List<Opportunity> oppsToInsert = new List<Opportunity>();
        oppsToInsert.add(new Opportunity(Name='0', StageName='Closed Won',Amount=100,CloseDate = Date.newInstance(2015,orgFiscalMonth,01), AccountId = acc.Id, RecordTypeId=rtId, Type='Individual'));
        oppsToInsert.add(new Opportunity(Name='1', StageName='Closed Won',Amount=100,CloseDate = Date.newInstance(2015,orgFiscalMonth,01), AccountId = acc.Id, RecordTypeId=rtId2, Type='Individual'));
        oppsToInsert.add(new Opportunity(Name='2', StageName='Closed Won',Amount=200,CloseDate = Date.newInstance(2013,orgFiscalMonth,01), AccountId = acc.Id, RecordTypeId=rtId));
        // next one is special, is for acc2 but will have ocr to acc1
        oppsToInsert.add(new Opportunity(Name='3', StageName='Closed Won',Amount=200,CloseDate = Date.newInstance(2013,orgFiscalMonth,01), AccountId = acc2.Id, RecordTypeId=rtId));
        // include opp with no amount
        oppsToInsert.add(new Opportunity(Name='4', StageName='Closed Won',CloseDate = Date.newInstance(2015,orgFiscalMonth,01), AccountId = acc.Id, RecordTypeId=rtId2));
        // also special, ocr to our contact and in a FY they dont have a hard credit
        oppsToInsert.add(new Opportunity(Name='5', StageName='Closed Won',Amount=200,CloseDate = Date.newInstance(2001,orgFiscalMonth,01), AccountId = acc2.Id, RecordTypeId=rtId));
        // need more than one without a type to make sure we don't duplicate add '--'
        oppsToInsert.add(new Opportunity(Name='6', StageName='Closed Won',Amount=200,CloseDate = Date.newInstance(2002,orgFiscalMonth,01), AccountId = acc.Id, RecordTypeId=rtId));


        insert oppsToInsert;
        
        insert new OpportunityContactRole(OpportunityId=oppsToInsert[3].Id,ContactId=con.Id,Role='Influencer');
        insert new OpportunityContactRole(OpportunityId=oppsToInsert[5].Id,ContactId=con.Id,Role='Influencer');
    }
    @isTest public static void test_accountController(){
        Account acc = [SELECT Id FROM Account LIMIT 1][0];

        Test.startTest();
        DonationHistoryGridController ext = new DonationHistoryGridController();
        ext.objectId = acc.id;
        ext.getDoEverything();

        Test.stopTest();
        
        System.assertEquals(600, ext.AllTime);
    }

    @isTest public static void test_contactController() {
        Contact con = [SELECT Id,AccountId FROM Contact LIMIT 1][0];
        Test.startTest();
        DonationHistoryGridController ext = new DonationHistoryGridController();
        ext.objectId = con.id;
        ext.getDoEverything();
        Test.stopTest();

        System.assertEquals(200,ext.donationRows.get(2016).TypesTotal);
        System.assertEquals(0,ext.donationRows.get(2016).RoleTotal);
    }


    @isTest public static void test_withTypeField() {
        Account acc = [SELECT Id FROM Account LIMIT 1][0];

        Test.startTest();
        DonationHistoryGridController ext = new DonationHistoryGridController();
        ext.objectId = acc.id;
        ext.Opportunity_Type_Field = 'Type';
        ext.getDoEverything();
        Test.stopTest();
        
        System.assertEquals(200, ext.typeTotals.get('Individual'));
        System.assertEquals(400, ext.typeTotals.get('--'));
    }
}