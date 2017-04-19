# Extract username from a Unix/Linux run as profile prior to passing to the Microsoft.SystemCenter.WSManagement.Invoker
Param(
	$user
)

$scomAPI = New-Object -ComObject "MOM.ScriptAPI"
$propertyBag = $scomAPI.CreatePropertyBag()

if ([string]::IsNullOrEmpty($user))
{
	$propertyBag.AddValue("User", "")	
}
elseif ($user -match '<UserId>.+</UserId>')
{
	$modifiedUser = $user -replace '.*<UserId>([^<]+)</UserId>.*','$1'
	$propertyBag.AddValue("User", "$modifiedUser")	 
}
else
{
	$propertyBag.AddValue("User", $user)
}

# Send output to SCOM    
$propertyBag
