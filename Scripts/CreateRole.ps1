#Login-AzureRMAccount

$Subscriptions = Get-AzureRmSubscription -SubscriptionName 'Microsoft Azure Internal Consumption'
$AssignableScopes = $Subscriptions | % { "`"/Subscriptions/$($_.SubscriptionId)`"" }
$AssignableScopes = $AssignableScopes -join ','

$RoleName = 'LimitedReader'

$RoleDefinition = @"
{
    "DisplayName":  "Limited Reader",
    "Name": "$($RoleName)",
    "Description":  "Gives access to base level read operations in Resource Providers.",
    "Actions":  [
                    "Microsoft.Compute/locations/*/read"
                ],
    "NotActions":  [

                   ],
    "AssignableScopes":  [
                             $AssignableScopes
                         ]
}
"@

$tempDir = New-TempDirectory
Try
{
    $RoleFile = "$($tempDir)\role.json"
    
    $Role = Get-AzureRmRoleDefinition -Name $RoleName
    if($Role -as [bool])
    {
        $_RoleDefinition = ($RoleDefinition | ConvertFrom-Json)
        $_RoleDefinition | Add-Member -Name 'Id' -Value $Role.Id -MemberType NoteProperty
        $_RoleDefinition | ConvertTo-JSON > $RoleFile
        Set-AzureRmRoleDefinition -InputFile $RoleFile | Out-Null
    }
    else
    {
        $RoleDefinition > $RoleFile
        New-AzureRmRoleDefinition -InputFile $RoleFile | Out-Null
    } 
}
Finally
{
    Remove-Item $tempDir -Recurse -Force
}