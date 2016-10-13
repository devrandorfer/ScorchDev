<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script!!!!!!

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-AzureRMResourceProperties

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'WorkspaceId'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName
    
    Do
    {
        $ResourceArray = @()
        $Resource = Get-AzureRMResource -ExpandProperties
        foreach($_Resource in $Resource)
        {
            $obj = @{
                'Name' = $_Resource.Name
                'ResourceId' = $_Resource.ResourceId
                'ResourceName' = $_Resource.ResourceName
                'ResourceType' = $_Resource.ResourceType
                'ResourceGroupName' = $_Resource.ResourceGroupName
                'Location' = $_Resource.Location
                'SubscriptionId' = $_Resource.SubscriptionId
            }
            Foreach($PropertyName in ($_Resource.Properties | Get-Member -MemberType NoteProperty).Name)
            {
                $obj.Add("Property-$PropertyName", $_Resource.Properties.$PropertyName) | Out-Null
            }
            $ResourceArray += $obj
        }

        Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $ResourceArray -LogType 'AzureResourceProperty_CL'

        Start-Sleep -Seconds 30
    }
    While($True)
}
Catch
{
    $Exception = $_
    $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
    Switch ($ExceptionInfo.FullyQualifiedErrorId)
    {
        Default
        {
            Write-Exception $Exception -Stream Warning
        }
    }
}

Write-CompletedMessage @CompletedParameters
