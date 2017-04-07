<#
.SYNOPSIS
    Community.DataOnDemand process enumeration script
.DESCRIPTION
    This script enumerates processes and outputs formatted text
.PARAMETER LogName
    Log name. E.g. application, system, security.
.PARAMETER After
    (optional) Gets only the events that occur after the specified date/time
.PARAMETER Before
    (optional) Gets only the events that occur before the specified date/time
.PARAMETER Top
    (optional) Max number of results to output
.PARAMETER EntryType
    (optional) Valid values are Error, Information,FailureAudit, SuccessAudit, and Warning.
.PARAMETER Format
    Permitted values: text, csv, json
.NOTES
    Copyright 2016 Squared Up Limited, All Rights Reserved.
#>
Param(
    [string] $LogName = "system",
    [string] $After,
    [string] $Before,
    [nullable[int]] $Top,
    [string] $EntryType,
    [ValidateSet("text","csv","json", "list")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0
$ErrorActionPreference = "stop"

$Params = @{
    "LogName"=$LogName;
};
if ($After) {
    $Params.Add("After", [DateTime]::Parse($After));
}
if ($Before) {
    $Params.Add("Before", [DateTime]::Parse($Before));
}
if ($Top) {
    $Params.Add("Newest", $Top);
}
if ($EntryType) {
    $Params.Add("EntryType", $EntryType);
}

$EventLogs = Get-EventLog @Params

# Get properties of object to be displayed in output (Get-Memeber does not honor order of properties in object)
[System.Collections.ArrayList]$OutPutOrdering = $EventLogs | Get-Member -MemberType AliasProperty,Property | Select-Object -ExpandProperty Name
# Add proprty being sorted, so it will be the first property to be displayed in output(will generate duplicate entry)
$OutPutOrdering.Insert(0,"TimeGenerated") 
# Remove the duplicate from the list of properties (will preserve the first one in the list)
$OutPutOrdering = $OutPutOrdering | Select-Object -Unique

if ($Format -eq 'text')
{
    $EventLogs `
        | Sort-Object -Property TimeGenerated -Descending `
        | Select-Object -Property $OutPutOrdering `
        | Format-Table -AutoSize `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csv')
{
    $EventLogs `
        | Sort-Object -Property TimeGenerated -Descending `
        | Select-Object -Property $OutPutOrdering `
        | ConvertTo-Csv -NoTypeInformation `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'json')
{
    $EventLogs `
        | Sort-Object -Property TimeGenerated -Descending `
        | Select-Object -Property $OutPutOrdering `
        | ConvertTo-Json `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($format -eq 'list')
{
    $EventLogs `
        | Sort-Object -Property TimeGenerated -Descending `
        | Select-Object -Property $OutPutOrdering `
        | Format-List `
        | Out-String -Width 4096 `
        | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
