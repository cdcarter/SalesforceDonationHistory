/*
    Copyright (c)2015 Christian Carter (@cdcarter)
    Inspired by Contact Giving Totals, Evan Callahan, copyright (c) 2010 Groundwire https://github.com/Groundwire/GWBase/blob/master/src/pages/ContactTotalsByRT.page

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
public with sharing class DonationHistoryControllerExtension {
    // the Id of the SObject passed in by the Standard Controller
    private final Id objectId;
    // the rows of the datatable, key is FiscalYear, value is a compound
    // object showing the totals for each recordtype
    public Map<Integer,DonationRow> donationRows {get;set;}
    // the recordtypes that exist for this HH
    public List<String> recordTypes {get;set;}
    // the contact roles that exist for this HH
    public List<String> contactRoles {get;set;}
    // the summary of each recordtype amount
    public Map<String,Decimal> rtTotals {get;set;}
    // the summart of each role amount
    public Map<String,Decimal> roleTotals {get;set;}
    // the all time giving number for this constituent
    public Decimal AllTime {get;set;}
    // the all time giving in soft credits for this constituent
    public Decimal RolesAllTime {get; set;}
    // the fiscal years in DESC order for displaying the donationRowsMap
    public List<Integer> FiscalYears {get;set;}
    
    public DonationHistoryControllerExtension(ApexPages.StandardController stdController) {
		this.donationRows = new Map<Integer,DonationRow>();
        this.rtTotals = new Map<String,Decimal>();
        this.roleTotals = new Map<String,Decimal>();
        this.objectId = stdController.getId();
        Donation_History_Settings__c settings = Donation_History_Settings__c.getInstance();
        
        // TODO: custom setting for FY vs CY
        // TODO: custom setting for name of field to group by (dynamic apex)
        // TODO: custom setting for record types to withhold
        List<AggregateResult> cubedSummary = [SELECT FISCAL_YEAR(CloseDate) fy, RecordType.Name rtName, SUM(Amount) TotalAmount FROM Opportunity WHERE IsWon = True AND Amount != 0 AND AccountId = :this.objectId GROUP BY CUBE(FISCAL_YEAR(CloseDate), RecordType.Name) ORDER BY FISCAL_YEAR(CloseDate) DESC];
    	List<Id> contactIds = new List<Id>();
        for(Contact c : [SELECT Id FROM Contact WHERE AccountId = :this.objectId]){
            contactIds.add(c.Id);
        }
		List<AggregateResult> cubedContactRoles = [SELECT FISCAL_YEAR(Opportunity.CloseDate) fy, SUM(Opportunity.Amount) TotalAmount, Role role FROM OpportunityContactRole WHERE Opportunity.IsWon = True AND Opportunity.Amount != 0 AND ContactId IN: contactIds AND Role !='Donor' GROUP BY CUBE(FISCAL_YEAR(Opportunity.CloseDate), Role) ORDER BY FISCAL_YEAR(Opportunity.CloseDate) DESC];       

        // should this get ALL opp RTs?
        // if we allow arbitrary field name to group by, how do we get all the possible values, even ones not in this set?
        List<AggregateResult> recordTypesSummary = [SELECT Count(Id), RecordType.Name name FROM Opportunity WHERE IsWon = True AND Amount != 0 AND AccountId = :objectId GROUP BY RecordType.Name];
       	List<AggregateResult> contactRolesSummary = [SELECT Count(Id), Role role FROM OpportunityContactRole WHERE Opportunity.IsWon = True AND Opportunity.Amount != 0 AND ContactId IN: contactIds AND Role !='Donor' GROUP BY Role];
        // create the list of RT Names 
        this.recordTypes = new List<String>();
       	for(AggregateResult agg : recordTypesSummary) {
            recordTypes.add((string)agg.get('name'));
        }
        this.contactRoles = new List<String>();
        for(AggregateResult agg : contactRolesSummary) {
            contactRoles.add((string)agg.get('role'));
        }
        
        for(AggregateResult agg : cubedSummary) {
			// initial pass only looking at the rows with both FY and RT
            if(agg.get('fy')!= null && agg.get('rtName') != null) {
                if(!donationRows.containsKey(Integer.valueOf(agg.get('fy')))) {
                    donationRows.put(Integer.valueOf(agg.get('fy')),new DonationRow(Integer.valueOf(agg.get('fy')),recordTypes,contactRoles));
                }
                donationRows.get(Integer.valueOf(agg.get('fy'))).rtToTotal.put((String)agg.get('rtName'),(Decimal)agg.get('TotalAmount'));
            } else if(agg.get('fy') == null && agg.get('rtName') != null) {
                rtTotals.put((String)agg.get('rtName'),(Decimal)agg.get('TotalAmount'));
            } else if(agg.get('fy') != null && agg.get('rtName') == null) {
                if(!donationRows.containsKey(Integer.valueOf(agg.get('fy')))) {
                    donationRows.put(Integer.valueOf(agg.get('fy')),new DonationRow(Integer.valueOf(agg.get('fy')),recordTypes,contactRoles));
                }
				donationRows.get(Integer.valueOf(agg.get('fy'))).TypeTotal = (Decimal)agg.get('TotalAmount');
            } else if(agg.get('fy') == null && agg.get('rtName') == null) {
                this.AllTime = (Decimal)agg.get('TotalAmount');
            }
        }
        
        // now that we've figured out the record types, let's do soft credits
        for(AggregateResult agg : cubedContactRoles) {
			// initial pass only looking at the rows with both FY and RT
            if(agg.get('fy')!= null && agg.get('role') != null) {
                if(!donationRows.containsKey(Integer.valueOf(agg.get('fy')))) {
                    donationRows.put(Integer.valueOf(agg.get('fy')),new DonationRow(Integer.valueOf(agg.get('fy')),recordTypes,contactRoles));
                }
                donationRows.get(Integer.valueOf(agg.get('fy'))).roleToTotal.put((String)agg.get('role'),(Decimal)agg.get('TotalAmount'));
            } else if(agg.get('fy') == null && agg.get('role') != null) {
                roleTotals.put((String)agg.get('role'),(Decimal)agg.get('TotalAmount'));
            } else if(agg.get('fy') != null && agg.get('role') == null) {
                if(!donationRows.containsKey(Integer.valueOf(agg.get('fy')))) {
                    donationRows.put(Integer.valueOf(agg.get('fy')),new DonationRow(Integer.valueOf(agg.get('fy')),recordTypes,contactRoles));
                }
				donationRows.get(Integer.valueOf(agg.get('fy'))).RoleTotal = (Decimal)agg.get('TotalAmount');
            } else if(agg.get('fy') == null && agg.get('role') == null) {
                this.RolesAllTime = (Decimal)agg.get('TotalAmount');
            }
        }

        // the following is a big of voodoo for determing any missing fys and adding them to the sequence
        // it's a complicated set of loops, so i'm leaving in the debug statements in case anyone
        // has to figure out what is going on. They're really great and explain the algorithm.
		List<Integer> temp = new List<Integer>(donationRows.keySet());
       	this.FiscalYears = new List<Integer>();
        for(Integer i=0; i < temp.size(); i++) {
            //if(i>0)
            //	system.debug(String.format('temp[i] = {0}, fy[size-1] = {1}',new List<String>{String.valueOf(temp[i]+1),String.valueOf(this.FiscalYears[this.FiscalYears.size()-1])}));
            
            if(i>0 && temp[i]+1 != this.FiscalYears[this.FiscalYears.size()-1]) {
               // system.debug('missing yrs detected');
                Integer currentYear = this.FiscalYears[this.FiscalYears.size()-1];
                Integer yearsToAdd = currentYear-temp[i]-1;
                //system.debug(String.format('{0} yrs missing',new list<String>{String.valueof(yearsToAdd)}));
                for(integer j = 1; j<= yearsToAdd; j++) {
                    //system.debug(String.format('adding {0}',new List<String>{String.valueOf(currentYear-j)}));
                	this.FiscalYears.add(currentYear-j);
                    this.donationRows.put(currentYear-j, new DonationRow(currentYear-j,recordTypes,contactRoles));
                }
            }
            //system.debug(String.format('adding year with donations {0}',new List<String>{String.valueOf(temp[i])}));
            this.FiscalYears.add(temp[i]);
        }
    }
    
    public class DonationRow {
        public Map<String,Decimal> rtToTotal {get;set;}
        public Map<String,Decimal> roleToTotal {get;set;}
        public Integer fiscalYear {get;set;}
        // total for this FY
        public Decimal TypeTotal {
            get {
            	if(this.TypeTotal == null){this.TypeTotal = 0;}
                return this.TypeTotal;
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
        public DonationRow(Integer fy,List<String> recordTypes, List<String> contactRoles) {
            this.rtToTotal = new Map<String,Decimal>();
            this.roleToTotal = new Map<String,Decimal>();
            this.fiscalYear = fy;
            for(String rt : recordTypes) {
                this.rtToTotal.put(rt,0);
            }
            for(String role :contactRoles) {
                this.roleToTotal.put(role,0);
            }
        }        
    }
}