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
    [ValidateSet("text","csv","json", "list")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0
$ErrorActionPreference = "stop"

function Get-DNSRecordType
{
    Param([uint16]$type)
    switch ($type)
    {
        1 { return "A" }
        2 { return "NS" }
        5 { return "CNAME" }
        6 { return "SOA" }
        12 { return "PTR" }
        15 { return "MX" }
        28 { return "AAAA" }
        33 { return "SRV" }
        default { return "$type" }
    }
}

#Execute the underlying PS
$OutputObjects = @(Get-DnsClientCache)

if ($Format -eq 'text')
{
    $OutputObjects `
        | Select-Object Entry, Name, @{N='RecordType';E={Get-DNSRecordType $_.Type}}, Data `
        | Format-Table -AutoSize `
        | Out-String -Width 4096
}
elseif ($Format -eq 'csv')
{
    $OutputObjects `
        | convertto-csv -NoTypeInformation
}
elseif ($Format -eq 'json')
{
    $OutputObjects `
        | convertto-json
}
elseif ($format -eq 'list')
{
    $OutputObjects `
        | Select-Object Entry, Name, @{N='RecordType';E={Get-DNSRecordType $_.Type}}, Data `
        | Format-List
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
