# Donation History Pagelet

This package includes pagelets to display donation history on the standard Account and Contact page layouts. Donation history is summarized by year, record type, and opportunity contact roles. There is a custom setting to help configure the pagelets and what donations are relevant to them.

This package is "base package agnostic" and should be suitable for any NPO using Opportunity to track donations. It has been tested with NPSP 3.0 and PatronTechnology's PatronManager.

It looks great in Aloha:
![Aloha Preview](http://cdcarter.github.io/SalesforceDonationHistory/aloha-demo.png)

and in the Lightning Experience!
![Lightning Experience Preview](http://cdcarter.github.io/SalesforceDonationHistory/lex-demo.png)

## Getting Started
To use this package, simply add the `AccountDonationHistory` or `ContactDonationHistory` pagelets to your respective page layouts. After you've added the VF page to the layout, hover over it and click the "wrench" icon to bring up the configuration for the pagelet itself. Leave the width at 100%, and make sure to check "Show scrollbars".

Visualforce pages in page layouts have a fixed height. The default height of 200px will show 6 rows of the table. Depending on how many years your average donor has been with your organization, you may want to increase or decrease the size of the box. By checking "show scrollbars", you'll be able to scroll within the IFrame, but if you consistently have donors with over 4 years of donation history, you might consider a larger height.

## Configuration

There is a custom setting named "Donation History Pagelet Settings" that allows further customization of the pagelets. Setting this custom setting is optional.

<table>
<thead>
<tr><th>Field</th><th>Default</th><th>Description</th></tr>
</thead>
<tbody>
<tr><td>Account Roles to Exclude</td><td>Donor;Household Member</td><td>A semicolon separated list of the Opportunity Contact Roles to not summarize on the Account donation history pagelet. Most users exclude "Donor" and "Household Member" so as to only see soft credits, but there are reasons you may want to exclude others or include those.</td></tr>
<tr><td>Contact Roles to Exclude</td><td>Donor;Household Member</td><td>A semicolon separated list of the Opportunity Contact Roles to not summarize on the Contact donation history pagelet. Most users exclude "Donor" and "Household Member" so as to only see soft credits, but there are reasons you may want to exclude others or include those.</td></tr>
<tr><td>Opportunity Type Field</td><td>RecordType.Name</td><td>This is the field that opportunities will be summarized by in the hard credit table. RecordType and Opportunity Type are both common choices.</td></tr>
<tr><td>Use Calendar Year?</td><td>False</td><td>When checked, the summaries on the pagelet will be by Calendar Year, even if your organization has a fiscal year configured. This is useful if you want to think of donors in terms of their annual giving.</td></tr>
</tbody>
</table>

The package runs "with sharing", so your users will NOT be able to see full donation totals for the record they are looking at if they do not have read access to the Opportunities being summarized.

## The Fine Print

The package was initially commissioned by Caroline Renard, after seeing the  giving totals pagelet from Groundwire Base.

Copyright (c) 2015 Christian Carter (@cdcarter)

Inspired by Contact Giving Totals, Evan Callahan, copyright (c) 2010 Groundwire -- http://github.com/Groundwire/GWBase/blob/master/src/pages/ContactTotalsByRT.page
