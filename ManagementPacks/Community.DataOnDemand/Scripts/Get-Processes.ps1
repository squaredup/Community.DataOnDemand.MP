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
    $OutputObjects += New-Object -TypeName PSObject -Property @{
        "Pid"=$PoshProcess.Id;
        "ParentPid"=$WmiProcess.CreatingProcessID;
        "SessionId"=$PoshProcess.SessionId;
        "Name"=$PoshProcess.Name;
        "Description"=$PoshProcess.Description;
        "Path"=$PoshProcess.Path;
        "CpuPercent"=$WmiProcess.PercentProcessorTime;
        "PrivateBytes"=$WmiProcess.PrivateBytes;
        "Handles"=$WmiProcess.HandleCount;
        "Threads"=$WmiProcess.ThreadCount;
    }
}

if ($Format -eq 'text')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top Pid, Name, CpuPercent, PrivateBytes, Description, ParentPid, SessionId, Handles, Threads `
        | Format-Table -AutoSize `
        | Out-String -Width 4096
}
elseif ($Format -eq 'csv')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top  `
        | convertto-csv -NoTypeInformation
}
elseif ($Format -eq 'json')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top `
        | convertto-json
}
elseif ($Format -eq 'list')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top Pid, Name, CpuPercent, PrivateBytes, Description, ParentPid, SessionId, Handles, Threads `
        | Format-List
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
