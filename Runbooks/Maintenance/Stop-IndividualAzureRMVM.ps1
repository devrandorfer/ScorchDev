<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(
    $WebhookData
)

Import-Module SCOrchDev-Utility -Verbose:$False
Import-Module SCOrchDev-Exception -Verbose:$False
Import-Module SCOrchDev-File -Verbose:$False
Import-Module SCOrchDev-GitIntegration -Verbose:$False
Import-Module AzureRM.Profile -Verbose:$False

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Stop-IndividualAzureRMVM.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'SubscriptionAccessTenant'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName

Try
{
    $Payload = $WebhookData.RequestBody | ConvertFrom-Json

    Add-AzureRmAccount -Credential $SubscriptionAccessCredential `
                       -SubscriptionId $Payload.SubscriptionId `
                       -TenantId $GlobalVars.SubscriptionAccessTenant `
                       -ServicePrincipal | Out-Null
    
    $VM = Find-AzureRmResource -ResourceNameEquals $Payload.Name -ResourceGroupNameEquals $Payload.ResourceGroupName
    if($VM.Tags.ContainsKey('ShutdownDate')) { $VM.Tags.ShutdownDate = (Get-Date) }
    else { $VM.Tags.Add('ShutdownDate',(Get-Date)) }

    $VM | Set-AzureRmResource -Force
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
