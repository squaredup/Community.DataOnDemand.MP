<#
.SYNOPSIS
    Community.DataOnDemand process enumeration script
.DESCRIPTION
    This script enumerates processes and outputs formatted text
.PARAMETER OrderBy
    Property to order by (e.g Pid, CpuPercent, PrivateBytes). Default: Pid.
.PARAMETER Descending
    Whether to sort descending. Default: ascending.
.PARAMETER Top
    Max number of results to output. Default: 99999.
.PARAMETER Format
    Permitted values: text, csv, json
.NOTES
    Copyright 2016 Squared Up Limited, All Rights Reserved.
#>
Param(
    [string] $OrderBy = "Pid",
    $Descending = $false,
    [int] $Top = "99999",
    [ValidateSet("text","csv","json","list")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0
$ErrorActionPreference = "stop"

# SCOM passes in the string "false" which won't bind to a [bool]
$Desc = [System.Convert]::ToBoolean($Descending);

# The cmdlet doesn't report % cpu usage, parent process id, ...
$PoshProcesses = @(Get-Process)

# WMI doesn't report process description, ...
$WmiProcesses = @(get-wmiobject Win32_PerfFormattedData_PerfProc_Process)

# Iterate through PoshProcesses doing lookups against WmiProcesses for extra info
# Normalize hash key datatype to string
# Filter out idle process 0. WMI also reports a bogus _Total process with ID 0.
$WmiProcessLookup = @{};
$WmiProcesses | Where-Object { $_.IDProcess -ne 0 } `
              | Where-Object { -not $WmiProcessLookup.ContainsKey("$($_.IDProcess)")} `
              | ForEach-Object { $WmiProcessLookup.Add("$($_.IDProcess)",$_) };

$OutputObjects= @();
foreach ($PoshProcess in $PoshProcesses)
{
    $WmiProcess = $WmiProcessLookup["$($PoshProcess.Id)"];
    if (-not $WmiProcess -or $PoshProcess.Id -eq 0) {
        continue;
    }

    # Create a set of output objects with properties from WMI and posh
    $OutputObject = New-Object -TypeName PSObject
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Pid -Value $PoshProcess.Id
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Name -Value $PoshProcess.Name
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name CpuPercent -Value $WmiProcess.PercentProcessorTime
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name PrivateBytes -Value $WmiProcess.PrivateBytes
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Description -Value $PoshProcess.Description
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name ParentPid -Value $WmiProcess.CreatingProcessID
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name SessionId -Value $PoshProcess.SessionId
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Handles -Value $WmiProcess.HandleCount
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Threads -Value $WmiProcess.ThreadCount
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Path -Value $PoshProcess.Path

    $OutputObjects += $OutputObject
    # Do not null object it is used further down to extract correct ordering of object properties
    #$OutputObject = $Null
}


# Get properties of object to be displayed in output, note OutputObject must by used as OutputObjects gives strange return
[System.Collections.ArrayList]$OutPutOrdering = $OutputObject.psobject.Properties.Name
# Add proprty being sorted on to list of properties (will generate duplicate entry)
$OutPutOrdering.Insert(0,$OrderBy) 
# Remove the duplicate from the list of properties (will preserve the first one in the list)
$OutPutOrdering = $OutPutOrdering | Select-Object -Unique

if ($Format -eq 'text')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top -Property $OutputOrdering -ExcludeProperty Path `
        | Format-Table -AutoSize `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csv')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top -Property $OutputOrdering `
        | convertto-csv -NoTypeInformation `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'json')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top -Property $OutputOrdering `
        | convertto-json `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'list')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top -Property $OutputOrdering -ExcludeProperty Path `
        | Format-List `
        | Out-String -Width 4096 `
        | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
