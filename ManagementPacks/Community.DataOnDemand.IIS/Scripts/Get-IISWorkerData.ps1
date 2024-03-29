﻿<#
.SYNOPSIS
    Get CSV formatted information about IIS worker processes.
.DESCRIPTION
    This script calls netsh and appcmd to obtain information about
    IIS worker processes and formats the output in a CSV form
	friendly to automated consumption.
.PARAMETER Format
    Permitted values: text, csv, json, list
.EXAMPLE
	PS > .\Get-IisWorkerData.ps1 -format csv

	Returns IIS worker process information.
.NOTES
    Output is sent to Write-Host to simplify consumption of output
    when run as a SCOM agent task.

    Copyright 2018 Squared Up Limited, All Rights Reserved.
.LINK
	https://www.squaredup.com
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
Param(
    [ValidateSet("text","csv","csvEx","json","list")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0
$ErrorActionPreference = "stop"

# Emit CSV header
$output = @()
$output += 'Port,Pid,AppPool,App%EOL%'
$column = '{0},{1},"{2}","{3}"%EOL%'

# =============================================================================
#
# Constants
#
$netsh = "netsh.exe"
$appcmd = "$Env:WinDir\system32\inetsrv\appCmd.exe"

# =============================================================================
#
# Custom parsing for netsh output
#

# https://regex101.com/r/qZ9PBy/2
$netshPidRe = New-Object Regex ('^\s*(?:Process IDs:\n(?:\s+(?<PID>\d+)\s*$)+|Processes:\n(?:\s+ID: (?<PID>\d+),.*)+)',[System.Text.RegularExpressions.RegexOptions]::Multiline)
$netshUrlRe = New-Object Regex ('^\s+https?://[^:]+:(?<PORT>\d+)',([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Multiline))

function GetNetshInfo {
    [CmdletBinding()]
    param(
    )

    $results = @()

    $netshData = @(&$netsh http show servicestate view=requestq)

    $requestQueues = @()
    $currentQueue = $null

    foreach ($line in $netshData) {
        if($line -like "Request queue name:*")
        {
            if ($null -ne $currentQueue) {
                $requestQueues += $currentQueue -join "`n"
            }

            $currentQueue = @($line)
        } elseif ($null -ne $currentQueue) {
            $currentQueue += $line
        }
    }

    if($null -ne $currentQueue) {
        $requestQueues += $currentQueue -join "`n"
    }

    foreach ($requestQueue in $requestQueues)
    {
        $pidMatch = $netshPidRe.Match($requestQueue)
        if ($pidMatch.Success) {
            $pids = $pidMatch.Groups['PID'].Captures.Value | ForEach-Object { [int]$_ }
        } else {
            $pids = $null
        }
        $urlMatches = $netshUrlRe.Matches($requestQueue)
        $ports = $urlMatches | Select-Object -ExpandProperty Groups | Where-Object { $_.Name -eq 'PORT' } | ForEach-Object { [int]$_.Value }
        
        foreach ($port in $ports) {
            foreach ($pidItem in $pids) {
                $results += New-Object PSObject -Property @{ Port = $port; Pid = $pidItem };
            }
        }
    }

    return ,$results
}

# =============================================================================
#
# AppCmd.exe handling
#

function GetWorkerInfo {
    [CmdletBinding()]
    param(
    )

    $results = @()

    if (Test-Path $appcmd) {
        $workerInfo = [xml](&$appcmd /xml /config:* list wp)

        if ($workerInfo.appcmd | gm -Name WP) {
            foreach ($wi in $workerInfo.appcmd.WP) {
                $results += New-Object PSObject -Property @{ Pid = $wi.'WP.NAME'; AppPool = $wi.'APPPOOL.NAME' };
            }
        }
    }

    return ,$results
}

function GetAppInfo {
    [CmdletBinding()]
    param(
    )

    $results = @()

    if (Test-Path $appcmd) {
        $appInfo = [xml](&$appcmd /xml /config:* list app)

        if ($appInfo.appcmd | gm -Name APP) {
            foreach ($ai in $appInfo.appcmd.APP) {
                $results += New-Object PSObject -Property @{ AppPool = $ai.'APPPOOL.NAME'; App = $ai.'APP.NAME';  };
            }
        }
    }

    return ,$results
}

# =============================================================================
#
# Main routine
#

$netshData = GetNetshInfo
$wpData = GetWorkerInfo
$appData = GetAppInfo

$pidByPool = @{}
if ($wpData) {
    foreach ($worker in $wpData) {
        if (-not $pidByPool.ContainsKey($worker.AppPool)) {
            $pidByPool[$worker.AppPool] = @()
        }
        $pidByPool[$worker.AppPool] += [int]$worker.Pid
    }
}

$portsByProcId = @{}
if ($netshData) {
    foreach ($entry in $netshData) {
        if (-not $portsByProcId.ContainsKey($entry.Pid)) {
            $portsByProcId[$entry.Pid] = @()
        }
        $portsByProcId[$entry.Pid] += $entry.Port
    }
}

if ($appData) {
    foreach ($app in $appData) {

        $pool = $app.AppPool

        # If no workers are currently awake for this pool, still need to output an entry with null pid and port
        if (-not $pidByPool.ContainsKey($pool)) {
            $output += $column -f `
            $null, # port
            $null, # pid
            ([string]$pool).Replace('"','""'),
            ([string]$app.App).Replace('"','""')

            continue;
        }
        
        $pids = $pidByPool[$pool]

        foreach ($procId in $pids) {

            foreach ($port in $portsByProcId[$procId]) {
                $output += $column -f `
                $port,
                $procId,
                ([string]$pool).Replace('"','""'),
                ([string]$app.App).Replace('"','""')
            }
        }
    }
}

# Produce output in requested format
if ($Format -eq 'text')
{
    ConvertFrom-Csv ($output -replace '%EOL%','') `
        | Format-Table -AutoSize `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csv')
{
    $output -replace '%EOL%','' `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csvEx')
{
    $output `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'json')
{
    ConvertFrom-Csv ($output -replace '%EOL%','') `
        | ConvertTo-Json `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'list')
{
    ConvertFrom-Csv ($output -replace '%EOL%','') `
        | Format-List `
        | Out-String -Width 4096 `
        | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
