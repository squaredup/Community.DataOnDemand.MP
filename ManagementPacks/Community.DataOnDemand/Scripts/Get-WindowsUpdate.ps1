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
	[int]$ShowTop = [int]::MaxValue,
	[string]$ExcludedKB
)

# define a variable to hold the output, with header as the first item
$output = @('KB Article,KB Name,Installation Date,Installation Status')

# create a new instance of the Update Session COM object
$Session = New-Object -ComObject Microsoft.Update.Session

# create a searcher object
$Searcher = $Session.CreateUpdateSearcher()

# query for all events in the Update History
$queryResult = $Searcher.QueryHistory(0,$Searcher.GetTotalHistoryCount())

# create a collection to hold the items we are about to create
$WindowsUpdates = @()

# Populate Exclusion List (adding if specified)
$ExclusionList = @()
if ($ExcludedKB -ne "")
{
	# split the string out
    $ExclusionList = $ExcludedKB.Split(",") | ForEach-Object { $_ -replace '^(KB)?(\d{6,7})','KB$2'}
}

# loop through the query results
foreach ($item in $queryResult)
{
	# Default to title from query
    $KBArticle = $null
    $Title = $item.Title

	# if the title contains a KB article number then...
	if($item.Title -match "\(?KB\d{6,7}\)?"){

        # put the actual title, minus the KB ref, into the title variable
        #$split = ($item.Title -split '\s?\((KB\d{6,7})\)')
        $KBArticle = $Matches[0].Trim(' ','(',')')
        $Title = $item.title -replace "\s?\(?$KBArticle\)?",''
	}

    # Skip null entries or if the KBArticle is in the exclusion list
    if ([string]::IsNullOrEmpty($item.Title) -or $ExclusionList -contains "$KBArticle") {
        continue;
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
		InstalledOn =$item.Date;
		KBArticle = $KBArticle;
		Name = $Title;
		Status = $Result
	}

	# add to the collection
	$WindowsUpdates.Add($newObject) | Out-Null
}

# sort by installedOn value
$WindowsUpdates = @($WindowsUpdates | Sort-Object InstalledOn -Descending:$true)

# loop through the elements to build the output string, limited by ShowTop
$outputCount = [math]::Min($ShowTop, $WindowsUpdates.Count)

for ($i = 0; $i -lt $outputCount; $i++) {
    $item = $WindowsUpdates[$i]

    # create a new line in the output file
	$output += '"{0}","{1}","{2}","{3}"%EOL%' -f `
        $item.KBArticle,
        $item.Name,
        $item.InstalledOn.ToString("u"),
        $item.Status
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
