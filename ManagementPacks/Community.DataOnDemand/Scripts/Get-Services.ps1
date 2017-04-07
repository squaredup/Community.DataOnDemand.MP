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

$Services = Get-Service

# Get properties of object to be displayed in output
[System.Collections.ArrayList]$OutPutOrdering = $Services | Get-Member -MemberType AliasProperty,Property | Select-Object -ExpandProperty Name
# Add proprty being sorted, so it will be the first property to be displayed in output(will generate duplicate entry)
$OutPutOrdering.Insert(0,"Name") 
# Remove the duplicate from the list of properties (will preserve the first one in the list)
$OutPutOrdering = $OutPutOrdering | Select-Object -Unique

if ($Format -eq 'text')
{
    $Services `
        | Sort-Object -Property Name `
        | Select-Object -Property Name, Status, DisplayName `
        | Format-Table -AutoSize `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csv')
{
    $Services `
        | Sort-Object -Property Name `
        | Select-Object -Property $OutputOrdering `
        | ConvertTo-Csv -NoTypeInformation `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'json')
{
    $Services `
        | Sort-Object -Property Name `
        | Select-Object -Property $OutputOrdering `
        | ConvertTo-Json `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'list')
{
    $Services `
        | Sort-Object -Property Name `
        | Select-Object -Property Name, Status, DisplayName `
        | Format-List `
        | Out-String -Width 4096 `
        | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
