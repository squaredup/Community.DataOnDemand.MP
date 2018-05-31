<#
.SYNOPSIS
Community.DataOnDemand windows update enumeration script
.DESCRIPTION
This script enumerates windows updates and outputs formatted text
.PARAMETER Format
Permitted values: text, csv, json
.NOTES
Copyright
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
Param(
	[ValidateSet("text","csv","csvEx","json","list")]
	[string] $Format = "csv",
	[int]$ShowTop,
	[string]$ExcludedKB
)

# define a variable to hold the output
$output = @()

# put the header in
$output += 'KB Article,KB Name,Installation Date,Installation Status'

# get the name of the current time zone
$currentTimeZoneName = (Get-WmiObject Win32_TimeZone).StandardName
$timeZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($currentTimeZoneName)

# create a new instance of the Update Session COM object
$Session = New-Object -ComObject Microsoft.Update.Session

# create a searcher object
$Searcher = $Session.CreateUpdateSearcher()

# get the count of elements in the history
$HistoryCount = $Searcher.GetTotalHistoryCount()

# query for the updates
$queryResult = $Searcher.QueryHistory(0,$HistoryCount)

# create a collection to hold the items we are about to create
[System.Collections.ArrayList]$WindowsUpdates = New-Object -Type System.Collections.ArrayList

# loop through the query results
foreach ($item in $queryResult)
{
	# make sure the title variable is empty
	$Title = $null

	# if the title contains a KB article number then...
	if($item.Title -match "\(KB\d{6,7}\)"){

		# split the title apart and put the actual title, minus the KB ref, into the title variable
		$Title = ($item.Title -split '.*\((KB\d{6,7})\)')[1]
	}
	else
	{
	# the title is just pulled from the query
	$Title = $item.Title
	}

	# make sure the result is empty
	$Result = $null

	# load the result based on the value of the result code
	Switch ($item.ResultCode)
	{
		0 { $Result = 'NotStarted'}
		1 { $Result = 'InProgress' }
		2 { $Result = 'Succeeded' }
		3 { $Result = 'SucceededWithErrors' }
		4 { $Result = 'Failed' }
		5 { $Result = 'Aborted' }
		default { $Result = $item.ResultCode }
	}

	# create a new object and populate it with values; note that the InstallOn value is converted to the local Server time
	$newObject = New-Object -TypeName PSObject -Property @{
		InstalledOn = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date -Date $item.Date), $timeZone);
		KBArticle = $Title;
		Name = $item.Title;
		Status = $Result
	}

	# add to the collection
	$WindowsUpdates.Add($newObject) | Out-Null
}

# sort by installedOn value
$WindowsUpdates = ($WindowsUpdates | Sort-Object InstalledOn -Descending:$true)

# next remove any that are being filtered out
# if any exclusions are specified
if ($ExcludedKB -ne "")
{
	# split the string out
	$arrExclusionList = $ExcludedKB.Split(",")

	# and then do the filter for each element
	foreach ($item in $arrExclusionList)
	{
		$WindowsUpdates = ($WindowsUpdates | Where-Object { $_.KBArticle -inotlike ('*KB' + $item + "*") })
	}
}

# create a counter variable
[int]$loopCounter = 1

# loop through the elements to build the output string
foreach ($item in $WindowsUpdates)
{
	# create a new line in the output file
	$output += '"{0}","{1}","{2}","{3}"%EOL%' -f `
		$item.KBArticle,
		$item.Name,
		$item.InstalledOn.ToString("g"),
		$item.Status

	# if the parameter for 'top' n was specified then....
	if ($ShowTop -gt -1)
	{
		if ($loopCounter -ge $ShowTop) { break } else { $loopCounter++ }
	}
}

# output to the required format
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
