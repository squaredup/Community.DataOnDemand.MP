<#
.SYNOPSIS
    Community.DataOnDemand DNS cache script
.DESCRIPTION
    This script enumerates the DNS cache and outputs formatted text
.PARAMETER Format
    Permitted values: text, csv, json
.NOTES
    Copyright 2016 Squared Up Limited, All Rights Reserved.
#>
Param(
    [ValidateSet("text","csv","json")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0
$ErrorActionPreference = "stop"

#Execute the underlying PS
$OutputObjects = @(Get-DnsClientCache)

if ($Format -eq 'text')
{
    $OutputObjects `
        | Select-Object Entry, RecordName, RecordType, Data `
        | Format-Table -AutoSize `
        | Out-String -Width 4096 `
        | write-host
}
elseif ($Format -eq 'csv')
{
    $OutputObjects `
        | convertto-csv `
        | Out-String `
        | write-host
}
elseif ($Format -eq 'json')
{
    $OutputObjects `
        | convertto-json `
        | write-host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
