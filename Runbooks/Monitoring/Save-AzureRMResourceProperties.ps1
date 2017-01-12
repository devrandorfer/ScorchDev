<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script!!!!!!

#>
Param(

)
Import-Module SCOrchDev-Utility -Verbose:$False
Import-Module SCOrchDev-Exception -Verbose:$False
Import-Module SCOrchDev-File -Verbose:$False
Import-Module SCOrchDev-GitIntegration -Verbose:$False
Import-Module AzureRM.Profile -Verbose:$False

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-AzureRMResourceProperties

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'WorkspaceId',
                                                'SubscriptionAccessTenant'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
    
   
    $ResourceArray = @()
    $Resource = Find-AzureRMResource
    foreach($_Resource in $Resource)
    {
        Try
        {
            $PopulatedResource = Get-AzureRMResource -ResourceId $_Resource.ResourceId -ExpandProperties
            $obj = @{
                'Name' = $PopulatedResource.Name
                'ResourceId' = $PopulatedResource.ResourceId
                'ResourceName' = $PopulatedResource.ResourceName
                'ResourceType' = $PopulatedResource.ResourceType
                'ResourceGroupName' = $PopulatedResource.ResourceGroupName
                'Location' = $PopulatedResource.Location
                'SubscriptionId' = $PopulatedResource.SubscriptionId
            }
            if(($_Resource | Get-Member -MemberType NoteProperty).Name -contains 'Tags')
            {
                $obj.Add('Tags', ($_Resource.Tags | ConvertTo-Json)) | Out-Null
            }
            Foreach($PropertyName in ($PopulatedResource.Properties | Get-Member -MemberType NoteProperty).Name)
            {
                $obj.Add("Property-$PropertyName", $PopulatedResource.Properties.$PropertyName) | Out-Null
            }
            $ResourceArray += $obj

            if($ResourceArray.Count -ge 20)
            {
                Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $ResourceArray -LogType 'AzureResourceProperty_CL'
                $ResourceArray.Clear()
            }
        }
        catch
        {
            Write-Exception -Exception $_ -Stream Warning
        }
    }
    if($ResourceArray.Count -gt 0)
    {
        Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $ResourceArray -LogType 'AzureResourceProperty_CL'
    }
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
