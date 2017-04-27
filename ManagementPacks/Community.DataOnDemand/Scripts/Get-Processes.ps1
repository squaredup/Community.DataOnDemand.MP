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
    [ValidateSet("Pid","Name","CpuPercent","PrivateBytes","Description","ParentPid","SessionId","Handles","Threads","Path")]
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

# The cmdlet doesn't report % cpu usage, parent process id
$PoshProcesses = @(Get-Process)

# Get Proc usage statstics
# Wmi doesn't report process description and other fields
Function Get-WmiProcPerfSample
{
    # Query Raw per process performance counters, excluding PID 0 as that will have Idle and _Total artificial processes listed.
    Get-WmiObject -Class Win32_PerfRawData_PerfProc_Process -Filter 'IDProcess != 0' -Property IDProcess,CreatingProcessID,PercentProcessorTime,TimeStamp_Sys100NS,ElapsedTime
}

# Sample activity over 1 second (same as Task manager)
$WmiPerfData = @{}
$sampleSet1 = @{}
Get-WmiProcPerfSample | ForEach-Object {$sampleSet1[$_.IDProcess] = $_}
Start-Sleep -Seconds 1

# Take a second sample, and populate the WmiPerf hashtable with the results
Foreach ($sample in Get-WmiProcPerfSample) {
    # If the process only appears in the second sample (started after the delay) you can use the lifetime values directly
    $procTime = $sample.PercentProcessorTime
    $timeWindow = ($sample.TimeStamp_Sys100NS - $sample.ElapsedTime)

    # If the process existed in the first sample, use deltas over the sample period
    If ($sampleSet1.ContainsKey($sample.IDProcess))
    {
        $procTime = $sample.PercentProcessorTime - $sampleSet1[$sample.IDProcess].PercentProcessorTime
        $timeWindow = $sample.TimeStamp_Sys100NS - $sampleSet1[$sample.IDProcess].TimeStamp_Sys100NS
    }
    # Percent Processor Time will be accross all LogicalProcessors and can exceed 100
    $WmiPerfData["$($sample.IDProcess)"] = New-Object -TypeName PSObject -Property @{
        "PID"=$sample.IDProcess;
        "CreatingProcessID"=$sample.CreatingProcessID;
        "PercentProcessorTime"=($procTime / $timeWindow) * 100 / [System.Environment]::ProcessorCount
    }
}

$OutputObjects= @();
foreach ($PoshProcess in $PoshProcesses)
{
    $WmiProcess = $WmiPerfData["$($PoshProcess.Id)"];
    if (-not $WmiProcess -or $PoshProcess.Id -eq 0) {
        continue;
    }

    # Create a set of output objects with properties from Wmi and posh with specific ordering of properties
    $OutputObject = New-Object -TypeName PSObject
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Pid -Value $PoshProcess.Id
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Name -Value $PoshProcess.Name
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name CpuPercent -Value ([Math]::Round($WmiProcess.PercentProcessorTime, 2))
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name PrivateBytes -Value $PoshProcess.PrivateMemorySize64
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Description -Value $PoshProcess.Description
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name ParentPid -Value $WmiProcess.CreatingProcessID
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name SessionId -Value $PoshProcess.SessionId
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Handles -Value $PoshProcess.Handles
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Threads -Value $PoshProcess.Threads.Count
    Add-Member -InputObject $OutputObject -MemberType NoteProperty -Name Path -Value $PoshProcess.Path

    $OutputObjects += $OutputObject
    $OutputObject = $Null
}


# Get properties of object to be displayed in output
# Get-Member can not be used here as it does not perserve the property order in the object
[System.Collections.ArrayList]$OutPutOrdering = $OutputObjects[0].psobject.Properties | Select-Object -ExpandProperty Name
# Add proprty being sorted, so it will be the first property to be displayed in output(will generate duplicate entry)
$OutPutOrdering.Insert(0,$OrderBy)
# Remove the duplicate from the list of properties (will preserve the first one in the list), and ensure they are strings to handle a PS v2 object wrapping issue with Select-Object
$OutPutOrdering = $OutPutOrdering | Select-Object -Unique | Foreach-Object {$_.ToString()}

if ($Format -eq 'text')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top -Property $OutPutOrdering -ExcludeProperty Path `
        | Format-Table -AutoSize `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csv')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top -Property $OutPutOrdering `
        | convertto-csv -NoTypeInformation `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'json')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top -Property $OutPutOrdering `
        | convertto-json `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'list')
{
    $OutputObjects `
        | Sort-Object -Property $OrderBy -Descending:$Desc `
        | Select-Object -First $Top -Property $OutPutOrdering -ExcludeProperty Path `
        | Format-List `
        | Out-String -Width 4096 `
        | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
