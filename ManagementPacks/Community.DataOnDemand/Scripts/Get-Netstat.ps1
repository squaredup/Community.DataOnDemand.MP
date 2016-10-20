
<#
.SYNOPSIS
    Get CSV formatted netstat output for established TCP connections.
.DESCRIPTION
    This script calls netstat to obtain information about network
    connections at the host and filters and formats the output in a
    CSV form friendly to automated consumption.
.PARAMETER Format
    Permitted values: text, csv, json
.NOTES
    netsh is used to find out which ports are being listened to by
	http.sys.  Any TCP connections to such ports have their process
	information faked up to an imaginary process called "HTTP.SYS"
	with a PID of 5. (real PIDs are always a multiple of 4, so this
	will never clash with a real process PID).

	Output is sent to Write-Host to simplify consumption of output
	when run as a SCOM agent task.

	Copyright 2016 Squared Up Limited, All Rights Reserved.
#>
Param(
    [ValidateSet("text","csv","csvEx","json")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0
$ErrorActionPreference = "stop"

# Cache for DNS lookup
$dnsCache = @{}
IPConfig /DisplayDNS | Select-String -Pattern "Record Name" -Context 0,5 | ForEach-Object {
    if (($_.Context.PostContext[3] -Split ":")[1].Trim() -eq 'Answer') {
        $dnsCache[($_.Context.PostContext[4] -Split ":")[1].Trim()] = ($_.Line -Split ":")[1].Trim()
    }
}

# Emit CSV header
$output = @()
$output += 'Computername,PID,ProcessName,ProcessDescription,Protocol,LocalAddress,LocalPort,RemoteAddress,RemotePort,State,RemoteAddressIP%EOL%'

# Get current process and service info
$procsByPid = @{}
Get-Process | ForEach-Object {
    $procsByPid[$_.Id] = $_
}
$svcsByPid = @{}
Get-WmiObject win32_Service | ForEach-Object {
    if ($_.ProcessId) {
        $svcsByPid[$_.ProcessId] = $_
    }
}

# See which port numbers are being listened to by HttpSys
$uriRe = [Regex]'^\s+\w+://[^:]+:(?<PORT>\d+)/'
$trueByHttpSysPort = @{}

$data = @()
netsh http show servicestate verbose=yes view=requestq | ForEach-Object {
    $data += $_
}
for( $i = 0; $i -lt $data.Length; $i++) {

    if ($data[$i] -match '^\s+Registered URLs:') {
        $i++
        $m = $uriRe.Match($data[$i])
        while ($m.Success) {
            $trueByHttpSysPort[$m.Groups['PORT'].Value] = $true
            $i++
            $m = $uriRe.Match($data[$i])
        }
    }
}

# Run netstat.exe
$results = @(netstat -ano)

# Process the results...
foreach ($line in $results) {
    # Only interested in established TCP connections
    if ($line -notmatch '^\s*TCP\b') { continue }
    if ($line -match '^\s*TCP\s+\[::') { continue }
    $col = $line.split(' ',[System.StringSplitOptions]::RemoveEmptyEntries)
    if ($col[3] -ne 'ESTABLISHED') { continue }
    if ($col[1].StartsWith('127.0.0.1')) { continue }

    # Now process the local and remote addresses
    $addrs = New-Object string[] 3
    $ports = New-Object string[] 3
    for ($c = 1; $c -le 2; $c++) {
        # $c = 1 for local address and 2 for remote address column...
        if ($col[$c].StartsWith('[')) {
            # IPv6
            $toks = $col[$c].Split(']')
            $addrs[$c] = $toks[0] + ']'
            if ($toks.length -gt 1 -and $toks[1].Length -gt 1) { $ports[$c] = $toks[1].Substring(1) } else { $ports[$c] = "" }
        } else {
            $toks = $col[$c].Split(':')
            $addrs[$c] = $toks[0]
            if ($toks.length -gt 1) { $ports[$c] = $toks[1] } else { $ports[$c] = "" }
        }
    }

    # Check if this is via HttpSys
    if ($col[4] -eq 4) {
        if ($trueByHttpSysPort.ContainsKey($ports[1])) {
            $col[4] = 5          # We use invalid PID 5 to indicate that this port is used by HTTP.SYS
        }
    }

    # Work out the process name and description
    $procName = "Unknown"
    $procDesc = "Unknown"
    $procId = [int]$col[4]
    if ($procId -eq 4) {
        $procName = $procDesc = "SYSTEM"
    } elseif ($procId -eq 5) {
        $procName = $procDesc = "HTTP.SYS"
    } elseif ($procsByPid.ContainsKey($procId)) {
        $proc = $procsByPid[$procId]
        $procName = $proc.ProcessName
        if($procName -eq 'svchost'){
            $procIdUnsigned = [uint32]$col[4]
            if ($svcsByPid.ContainsKey($procIdUnsigned)) {
                $procDesc = $svcsByPid[$procIdUnsigned].DisplayName
            } else {
                $procDesc = 'svchost'
            }
        }
        else
        {
            if ($proc.MainModule -and $proc.MainModule.FileVersionInfo) {
                $procDesc = $proc.MainModule.FileVersionInfo.FileDescription
            }
        }
    }

    # Get the host name
    $dnsName = $addrs[2]
    if ($dnsCache.ContainsKey($addrs[2])) {
        $dnsName = $dnsCache[$addrs[2]]
    }

    # CSV escape procDesc
    $procDesc = '"' + ($procDesc -replace '"','""') + '"'

    # Emit a CSV line for our consumer...
    $output += '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}%EOL%' -f `
        $env:COMPUTERNAME,
        $col[4],
        $procName,
        $procDesc,
        $col[0],
        $addrs[1],
        $ports[1],
        $dnsName,
        $ports[2],
        $col[3],
        $addrs[2]

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
	($output -replace '%EOL%','') | Out-String -Width 4096 | Write-Host
}
elseif ($Format -eq 'csvEx')
{
	$output | Write-Host
}
elseif ($Format -eq 'json')
{
	ConvertFrom-Csv ($output -replace '%EOL%','') | ConvertTo-Json | Write-Host
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
