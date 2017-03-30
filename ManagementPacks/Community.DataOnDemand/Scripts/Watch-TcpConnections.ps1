<#
.SYNOPSIS
    Get information about TCP connections over the specified number
    of minutes.
.DESCRIPTION
    This script repeatably obtains information about network connections
	at the host and filters and formats the output in a CSV form friendly
	to automated consumption.
.PARAMETER Interval
    The number of seconds to monitor for
.PARAMETER SourceFilePath
	The path to our C# source code
.PARAMETER Format
    Permitted values: text, csv, json
.EXAMPLE
	PS > .\Watch-TcpConnections.ps1 -format csv
	Returns netstat information in the default CSV format.
.NOTES
    Copyright 2017 Squared Up Limited, All Rights Reserved.
.LINK
	https://www.squaredup.com
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
Param(

    [int]$Interval = 60,
	[string]$SourceFilePath,
    [ValidateSet("text","csv","csvEx","json","list")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0

# Load up our C# class
if (! (Test-Path $SourceFilePath)) {
	throw ("Embedded C# source missing: {0}" -f $SourceFilePath)
}
$source = gc $SourceFilePath | Out-String
Add-Type -Language CSharp -TypeDefinition $source

# See which port numbers are being listened to by HttpSys
$uriRe = [Regex]'^\s+\w+://[^:]+:(?<PORT>\d+)/'
$trueByHttpSysPort = @{}

# Emit CSV header

$output = @()
$output += 'Computername,PID,ProcessName,ProcessDescription,Protocol,LocalAddress,LocalPort,RemoteAddress,RemotePort,State,RemoteAddressIP%EOL%'

$results = [SquaredUp.SqupTcpStatsV01]::MonitorTcp($Interval)
foreach ($line in $results) {

    # CSV escape procDesc and shorten, appending ... if not already present
    $procDesc = $line.ProcessDescription
    $maxlength = 128
    if ($procDesc.length -gt $maxlength) {
        $procDesc = $procDesc.Substring(0, $maxlength) -replace '(?<!\.{3})$','...'
    }
    $procDesc = '"' + $procDesc.Replace('"','""') + '"'

    # Check if this is via HttpSys
    $procId = $line.PID
    if ($pid -eq 4) {
        if ($trueByHttpSysPort.ContainsKey($line.LocalPort)) {
            $procId = 5          # We use invalid PID 5 to indicate that this port is used by HTTP.SYS
        }
    }

    # Emit a CSV line for our consumer...
    $output += '{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10}%EOL%' -f `
        $line.Computername,
        $procId,
        $line.ProcessName,
        $procDesc,
        $line.Protocol,
        $line.LocalAddress,
        $line.LocalPort,
        $line.RemoteAddress,
        $line.RemotePort,
        $line.State,
        $line.RemoteAddressIP
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

