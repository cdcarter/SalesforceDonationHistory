/*
    Copyright (c)2015 Christian Carter (@cdcarter)
    Inspired by Contact Giving Totals, Evan Callahan, copyright (c) 2010 Groundwire 
    https://github.com/Groundwire/GWBase/blob/master/src/pages/ContactTotalsByRT.page

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/

/* @author cdcarter
 * @date October, 2015
 * @group DonationHistory
 * @description DonationHistoryControllerExtension is an extension of the
 * standard Account and Contact controllers, to show Donation History for 
 * a constituent, summarized by both RecordType and Fiscal Year.
 */
public with sharing class DonationHistoryGridController {
    // the Id of the Account we are working with
    private Id accountId;
    // true if this extension was invoked with a Contact instead of an Account
    private Boolean contactSummary;
    // the rows of the datatable, key is FiscalYear, value is a compound
    // object showing the totals for each recordtype
    public Map<Integer,DonationRow> donationRows {get;set;}
    // the recordtypes that exist for this HH
    public List<String> types {get;set;}
    // the contact roles that exist for this HH
    public List<String> contactRoles {get;set;}
    // the summary of each recordtype amount
    public Map<String,Decimal> typeTotals {get;set;}
    // the summart of each role amount
    public Map<String,Decimal> roleTotals {get;set;}
    // the all time giving number for this constituent
    public Decimal AllTime {get;set;}
    // the all time giving in soft credits for this constituent
    public Decimal RolesAllTime {get; set;}
    // the fiscal years in DESC order for displaying the donationRowsMap
    public List<Integer> FiscalYears {get;set;}


    // NOW ALL THE SETTINGS
    public Id objectId {get;set;}
    public Boolean IsCalendarYear {get;set;}
    public String Opp_Types_to_Exclude {get;set;}
    public String Opportunity_Type_Field {get;set;}
    public String Roles_to_Exclude {get;set;}
    public Boolean DisplayRecordCounts {get;set;}

    public DonationHistoryGridController() {
        this.IsCalendarYear = false;
        this.Opp_Types_to_Exclude = null;
        this.Opportunity_Type_Field = 'RecordType.Name';
        this.Roles_to_Exclude = 'Donor;Household Member';
        this.DisplayRecordCounts = false;

    }
    // this is a horrific hacky way to solve the problem.
    public void getDoEverything() {
		this.donationRows = new Map<Integer,DonationRow>();
        this.typeTotals = new Map<String,Decimal>();
        this.roleTotals = new Map<String,Decimal>();
        if(objectId.getSObjectType() == Account.sObjectType) {
            this.accountId = this.objectId;
            this.contactSummary = false;
        } else if(objectId.getSObjectType() == Contact.sObjectType) {
            this.accountId = [SELECT AccountId FROM Contact WHERE Id = :objectId].AccountId;
            this.contactSummary = true;
        }

        // if account level, get all the accounts contacts for soft credits.
        List<Id> contactIds = new List<Id>();
        if(contactSummary) {
            contactIds.add(objectId);
        } else {
            for(Contact c : [SELECT Id FROM Contact WHERE AccountId = :this.accountId]){
                contactIds.add(c.Id);
            } 
        }
        List<String> types_to_exclude = new List<String>();
        if(Opp_Types_to_Exclude!= null) {
            types_to_exclude = Opp_Types_to_Exclude.split(';');
        }
        
        List<String> list_roles_to_exclude = Roles_to_Exclude.split(';');
        // right now, we're grabbing the full account's donations even for a contact level request.
        // question out to caroline whether or not that's appropriate
        // TODO: possibly limit RT summary to just primary contact donations
        String cubedSummaryQuery = 'SELECT FISCAL_YEAR(CloseDate) fy, '+Opportunity_Type_Field+' typeName, ';
        if (DisplayRecordCounts){
            cubedSummaryQuery += 'COUNT(id) TotalAmount, ';
        } else {
            cubedSummaryQuery += 'SUM(Amount) TotalAmount, ';
        }
        cubedSummaryQuery +=       'GROUPING('+Opportunity_Type_Field+') grpType ' +
                                   'FROM Opportunity ' +
                                   'WHERE IsWon = True AND (Amount > 0 OR Amount < 0) AND AccountId = :accountId ' +
                                   'AND '+Opportunity_Type_Field+' NOT IN : types_to_exclude '+
                                   'GROUP BY CUBE(FISCAL_YEAR(CloseDate), '+Opportunity_Type_Field+') ' +
                                   'ORDER BY FISCAL_YEAR(CloseDate) DESC';

		String cubedContactRolesQuery = 'SELECT FISCAL_YEAR(Opportunity.CloseDate) fy, ';
        if (DisplayRecordCounts){
            cubedContactRolesQuery += 'COUNT(id) TotalAmount, Role role ';
        } else {
            cubedContactRolesQuery += 'SUM(Opportunity.Amount) TotalAmount, Role role ';
        }

        cubedContactRolesQuery +=       'FROM OpportunityContactRole ' + 
                                        'WHERE Opportunity.IsWon = True '+
                                        'AND (Opportunity.Amount > 0 OR Opportunity.Amount < 0) '+
                                        'AND ContactId IN : contactIds '+
                                        'AND Role NOT IN : list_roles_to_exclude '+
                                        'GROUP BY CUBE(FISCAL_YEAR(Opportunity.CloseDate), Role) '+
                                        'ORDER BY FISCAL_YEAR(Opportunity.CloseDate) DESC';       

        if(IsCalendarYear) {
            cubedSummaryQuery = cubedSummaryQuery.replace('FISCAL_YEAR', 'CALENDAR_YEAR');
            cubedContactRolesQuery = cubedContactRolesQuery.replace('FISCAL_YEAR', 'CALENDAR_YEAR');
        }

        List<AggregateResult> cubedSummary = Database.query(cubedSummaryQuery);
        List<AggregateResult> cubedContactRoles = Database.query(cubedContactRolesQuery);
        
        // Get all represeted RTs and OCRs.
        // if we allow arbitrary field name to group by, how do we get all the possible values
        // even ones not in this set?
        String typesSummaryQuery = 'SELECT Count(Id), '+Opportunity_Type_Field+' name ' +
                                         'FROM Opportunity '+
                                         'WHERE IsWon = True  AND (Amount > 0 OR Amount < 0 ) '+
                                         'AND AccountId = :accountId '+
                                         'AND '+Opportunity_Type_Field+' NOT IN : types_to_exclude ' +
                                         'GROUP BY '+Opportunity_Type_Field;

        List<AggregateResult> typesSummary = Database.query(typesSummaryQuery);
       	List<AggregateResult> contactRolesSummary = [SELECT Count(Id), Role role 
                                                     FROM OpportunityContactRole 
                                                     WHERE Opportunity.IsWon = True 
                                                       AND (Opportunity.Amount > 0 OR Opportunity.Amount < 0)  
                                                       AND ContactId IN: contactIds 
                                                       AND Role NOT IN :list_roles_to_exclude 
                                                     GROUP BY Role];
        
        // create the list of typeNames 
        this.types = new List<String>();
       	for(AggregateResult agg : typesSummary) {
            types.add((string)agg.get('name'));
        }
        // and create the list of contactRoleNames
        this.contactRoles = new List<String>();
        for(AggregateResult agg : contactRolesSummary) {
            contactRoles.add((string)agg.get('role'));
        }
        
        for(AggregateResult agg : cubedSummary) {
            // a row can contain FY, RTName, Both, or neither
            if(agg.get('fy')!= null && agg.get('grpType') == 0) {
                // in the case of a fiscal year and grpType 0 (indicating this is a real type)
                // we want to set the RT total for that fiscal year
                if(!donationRows.containsKey(Integer.valueOf(agg.get('fy')))) {
                    donationRows.put(
                        Integer.valueOf(agg.get('fy')),
                        new DonationRow(Integer.valueOf(agg.get('fy')),types,contactRoles)
                    );
                }
                String typeName;
                if( (String)agg.get('typeName')!=null ) {
                    typeName = (String)agg.get('typeName');
                } else {
                    typeName = '--';
                    if(!(new Set<String>(types)).contains('--')) {
                        types.add('--');
                    }
                }
                if(agg.get('TotalAmount') != null) {
                    donationRows.get(Integer.valueOf(agg.get('fy'))).typeToTotal.put(
                        typeName,
                        (Decimal)agg.get('TotalAmount')
                    );
                }
            } else if(agg.get('fy') == null && agg.get('grpType') == 0) {
                // in the case of just RTName, we want to set the all time RT total
                String typeName;
                system.debug((String)agg.get('typeName'));
                if( (String)agg.get('typeName')!=null ) {
                    typeName = (String)agg.get('typeName');
                } else {
                    typeName = '--';
                    if(!(new Set<String>(types)).contains('--')) {
                        types.add('--');
                    }
                }
                typeTotals.put(typeName,(Decimal)agg.get('TotalAmount'));
            } else if(agg.get('fy') != null && agg.get('grpType') == 1) {
                // in the case of just FY, we want to set the fiscal year total
                // the order we parse the results may cause this code path to never execute
                if(!donationRows.containsKey(Integer.valueOf(agg.get('fy')))) {
                    donationRows.put(
                        Integer.valueOf(agg.get('fy')),
                        new DonationRow(Integer.valueOf(agg.get('fy')),types,contactRoles)
                    );
                }
				donationRows.get(Integer.valueOf(agg.get('fy'))).TypesTotal = (Decimal)agg.get('TotalAmount');
            } else if(agg.get('fy') == null && agg.get('grpType') == 1) {
                // in the case of neither, we set the AllTime total
                this.AllTime = (Decimal)agg.get('TotalAmount');
            }
        }
        
        // now that we've figured out the record types, let's do soft credits. exact same logic here.
        for(AggregateResult agg : cubedContactRoles) {
            if(agg.get('fy')!= null && agg.get('role') != null) {
                if(!donationRows.containsKey(Integer.valueOf(agg.get('fy')))) {
                    donationRows.put(
                        Integer.valueOf(agg.get('fy')),
                        new DonationRow(Integer.valueOf(agg.get('fy')),types,contactRoles)
                    );
                }
                if(agg.get('TotalAmount') != null) {
                    donationRows.get(Integer.valueOf(agg.get('fy'))).roleToTotal.put(
                        (String)agg.get('role'),
                        (Decimal)agg.get('TotalAmount')
                    );
                }
            } else if(agg.get('fy') == null && agg.get('role') != null) {
                roleTotals.put((String)agg.get('role'),(Decimal)agg.get('TotalAmount'));
            } else if(agg.get('fy') != null && agg.get('role') == null) {
                // the order we parse the results may cause this code path to never execute
                if(!donationRows.containsKey(Integer.valueOf(agg.get('fy')))) {
                    donationRows.put(
                        Integer.valueOf(agg.get('fy')),
                        new DonationRow(Integer.valueOf(agg.get('fy')),types,contactRoles)
                    );
                }
				donationRows.get(Integer.valueOf(agg.get('fy'))).RoleTotal = (Decimal)agg.get('TotalAmount');
            } else if(agg.get('fy') == null && agg.get('role') == null) {
                this.RolesAllTime = (Decimal)agg.get('TotalAmount');
            }
        }

        // the following is a big of voodoo for determing any missing fys and adding them to the sequence
        // it's a complicated set of loops, so i'm leaving in the debug statements in case anyone
        // has to figure out what is going on. They're really great and explain the algorithm.

        // donationRows.keySet is a DESC sorted list of years
		List<Integer> temp = new List<Integer>(donationRows.keySet()); 
       	this.FiscalYears = new List<Integer>();
        for(Integer i=0; i < temp.size(); i++) {
            //if(i>0)
            //	system.debug(String.format('temp[i] = {0}, fy[size-1] = {1}',
            //    new List<String>{String.valueOf(temp[i]+1),
            //    String.valueOf(this.FiscalYears[this.FiscalYears.size()-1])}));
            
            if(i>0 && temp[i]+1 != this.FiscalYears[this.FiscalYears.size()-1]) {
               // system.debug('missing yrs detected');
                Integer currentYear = this.FiscalYears[this.FiscalYears.size()-1];
                Integer yearsToAdd = currentYear-temp[i]-1;
                //system.debug(String.format('{0} yrs missing',new list<String>{String.valueof(yearsToAdd)}));
                for(integer j = 1; j<= yearsToAdd; j++) {
                    //system.debug(String.format('adding {0}',new List<String>{String.valueOf(currentYear-j)}));
                	this.FiscalYears.add(currentYear-j);
                    this.donationRows.put(currentYear-j, new DonationRow(currentYear-j,types,contactRoles));
                }
            }
            //system.debug(String.format('adding year with donations {0}',new List<String>{String.valueOf(temp[i])}));
            this.FiscalYears.add(temp[i]);
        }

        System.debug(this.donationRows);
    }
    
    public class DonationRow {
        public Map<String,Decimal> typeToTotal {get;set;}
        public Map<String,Decimal> roleToTotal {get;set;}
        public Integer fiscalYear {get;set;}
        // total for this FY
        public Decimal TypesTotal {
            get {
            	if(this.TypesTotal == null){this.TypesTotal = 0;}
                return this.TypesTotal;
      		}
            set;
        }
        
        public Decimal RoleTotal {
            get {
                if(this.RoleTotal == null) { this.RoleTotal = 0;}
                return this.RoleTotal;
            }
            set;
        }
        public DonationRow(Integer fy,List<String> types, List<String> contactRoles) {
            this.typeToTotal = new Map<String,Decimal>();
            this.roleToTotal = new Map<String,Decimal>();
            this.fiscalYear = fy;
            for(String t : types) {
                this.typeToTotal.put(t,0);
            }
            for(String role : contactRoles) {
                this.roleToTotal.put(role,0);
            }
        }        
    }
}