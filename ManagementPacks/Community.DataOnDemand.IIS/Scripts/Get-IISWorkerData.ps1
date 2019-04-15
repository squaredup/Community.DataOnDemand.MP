<#
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

# Useful REs - must avoid using localised strings in here
$netshRequestqBreakRe = New-Object Regex '^\S'
$netshPidRe = New-Object Regex '^\s*(?<PID>\d+)\s*$'
$netshUrlRe = New-Object Regex ('^\s+https?://[^:]+:(?<PORT>\d+)',[System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

function ProcessBatch {
    [CmdletBinding()]
    param(
        $thisTrueByPort,
        $thisTrueByPid
    )

    $results = @();
    foreach ($port in $thisTrueByPort.Keys) {
        foreach ($p in $thisTrueByPid.Keys) {
            $results += New-Object PSObject -Property @{ Port = $port; Pid = $p };
        }
    }
    $thisTrueByPort.Clear();
    $thisTrueByPid.Clear();

    return ,$results
}

function GetNetshInfo {
    [CmdletBinding()]
    param(
    )

    $results = @()

    $netshData = @(&$netsh http show servicestate view=requestq)

    $thisTrueByPort = @{}
    $thisTrueByPid = @{}

    foreach ($line in $netshData) {
        $breakMatch = $netshRequestqBreakRe.Match($line)
        if ($breakMatch.Success) {
            $results += ProcessBatch $thisTrueByPort $thisTrueByPid

        } else {
            $pidMatch = $netshPidRe.Match($line)
            if ($pidMatch.Success) {
                $thisPid = [int]$pidMatch.Groups['PID'].Value
                $thisTrueByPid[$thisPid] = $true
            } else {
                $urlMatch = $netshUrlRe.Match($line)
                if ($urlMatch.Success) {
                    $thisPort = [int]$urlMatch.Groups['PORT'].Value
                    $thisTrueByPort[$thisPort] = $true
                }
            }

        }
    }
    $results += ProcessBatch $thisTrueByPort $thisTrueByPid

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

$poolByPid = @{}
if ($wpData) {
	$wpData | %{ $poolByPid[[int]$_.Pid] = $_.AppPool }
}

$appsByPool = @{}
if ($appData) {
	foreach ($app in $appData) {
		if (-not $appsByPool.ContainsKey($app.AppPool)) {
			$appsByPool[$app.AppPool] = @{}
		}
		$appsByPool[$app.AppPool][$app.App] = $true
	}
}

if ($netshData) {
	foreach ($ns in $netshData) {
		if ($poolByPid.ContainsKey($ns.Pid)) {
			$pool = $poolByPid[$ns.Pid]
			if ($appsByPool.ContainsKey($pool)) {
				foreach($app in $appsByPool[$pool].Keys) {
					$output += $column -f `
					$ns.port,
					$ns.pid,
					([string]$pool).Replace('"','""'),
					([string]$app).Replace('"','""')
				}
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
