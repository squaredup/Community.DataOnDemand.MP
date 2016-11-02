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
    [ValidateSet("text","csv","json")]
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

if ($Format -eq 'text')
{
    $EventLogs `
        | Sort-Object -Property TimeGenerated -Descending `
        | Format-Table -AutoSize `
		| Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csv')
{
    $EventLogs `
        | Sort-Object -Property TimeGenerated -Descending `
        | ConvertTo-Csv -NoTypeInformation `
		| Out-String -Width 4096 `
		| Write-Host
}
elseif ($Format -eq 'json')
{
    $EventLogs `
        | Sort-Object -Property TimeGenerated -Descending `
        | ConvertTo-Json `
		| Out-String -Width 4096 `
		| Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
