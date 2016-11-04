<#
.SYNOPSIS
    DNS-resolve the supplied IP addresses or hostnames.
.DESCRIPTION
    This script calls the .NET System.Net.Dns.GetHostEntry() method
	to resolve the IP addresses or hostname supplied.
.PARAMETER Addresses
    The IP addresses or hostnames to resolve (comma-separated list).
.PARAMETER Format
    Permitted values: text, csv, json, list
.NOTES
	Output is sent to Write-Host to simplify consumption of output
	when run as a SCOM agent task.

	Copyright 2016 Squared Up Limited, All Rights Reserved.
#>
[CmdletBinding()]
Param(
    [string]$Addresses,

    [ValidateSet("text","csv","json","list")]
    [string] $Format = "csv"
)

#Requires -Version 2.0
Set-StrictMode -Version 2.0

# Create a dictionary and start asynchronously requesting records.
$requests = @{}
foreach ($target in $Addresses.split(@(',',' '), [System.StringSplitOptions]::RemoveEmptyEntries)) 
{
    $target = $target.trim()
    if (!$requests.ContainsKey($target))
    {
        $requests[$target] = [System.Net.Dns]::BeginGetHostEntry($target, $null, $null)    
    }
}

# parse output of any completed requests, and wait for others.
$output = @()
do 
{
    $keys = @() + $requests.Keys
    foreach ($target in $keys)
    {
        $request = $requests[$target]
        if ($request.IsCompleted)
        {
            try 
            {
                $ip = $null
                $result = [System.Net.Dns]::EndGetHostEntry($request)
                if ($result)
                {
                    $isIPAddress = [System.Net.IPAddress]::TryParse($target, [ref]$ip)
                    if ($isIPAddress -and $result.Hostname -ne $result.AddressList[0].tostring())
                    {
                        $output += New-Object PSObject -Property @{ IpAddress = $ip.tostring();HostName = $result.HostName }
                    }
                    elseif (!$isIpAddress -and $result.AddressList.count -gt 0)
                    {
                        $output += New-Object PSObject -Property @{ IpAddress = $result.AddressList[0].ToString();HostName = $target } 
                    }
                }

            } 
            catch 
            {
                Write-Verbose "$target not found in DNS or stale records present" -Verbose:$VerbosePreference
            }
            finally
            {
                $requests.Remove($target)
            }
        }
        else
        {
            Write-Verbose -Message "Waiting for $($target)" -Verbose:$VerbosePreference
            Start-Sleep -Milliseconds 500            
        }  
    }
} while ($keys.count -gt 0)

# Produce output in requested format
if ($Format -eq 'text')
{
	$output `
        | Format-Table -AutoSize `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'csv')
{
	$output `
        | ConvertTo-Csv -NoTypeInformation `
        | Out-String -Width 4096 `
        | Write-Host
}
elseif ($Format -eq 'json')
{
	$output `
        | ConvertTo-Json `
        | Write-Host
}
elseif ($format -eq 'list')
{
    $output `
        | Format-List `
        | Out-String -Width 4096 `
        | Write-Host `
}

# Done. (do not remove blank line following this comment as it can cause problems when script is sent to SCOM agent!)
