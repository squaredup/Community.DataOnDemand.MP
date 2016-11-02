<#
.SYNOPSIS
    Community.DataOnDemand windows service enumeration script
.DESCRIPTION
    This script enumerates windows services and outputs formatted text
.PARAMETER Format
    Permitted values: text, csv, json
.NOTES
    Copyright 2016 Squared Up Limited, All Rights Reserved.
#>
Param(
    [ValidateSet("text","csv","json","list")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0
$ErrorActionPreference = "stop"

if ($Format -eq 'text')
{
    Get-Service `
        | Sort-Object -Property Name `
        | Select-Object DisplayName, Status, Name  `
        | Format-Table -AutoSize `
		| Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csv')
{
    Get-Service `
        | Sort-Object -Property Name `
        | ConvertTo-Csv -NoTypeInformation `
		| Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'json')
{
    Get-Service `
        | Sort-Object -Property Name `
        | ConvertTo-Json `
		| Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'list')
{
    Get-Service `
        | Sort-Object -Property Name `
        | Select-Object DisplayName, Status, Name  `
        | Format-List `
		| Out-String -Width 4096 `
        | Write-Host
}
# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
