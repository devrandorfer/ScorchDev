<#
    .SYNOPSIS
       Finds machines connected to a list of VNets that currently have no DSC extension applied.

    .Description
        Designed to be run as a watcher task

#>
Param(

)

Import-Module SCOrchDev-Utility -Verbose:$False
Import-Module SCOrchDev-Exception -Verbose:$False
Import-Module SCOrchDev-File -Verbose:$False
Import-Module SCOrchDev-GitIntegration -Verbose:$False

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Find-FreeTierAzureAutomation.ps1

$SubscriptionAccessCredentialName = '6640d6a4-7a7c-45b9-b0a9-bbc055bf8684'
$SubscriptionAccessTenant = '72f988bf-86f1-41af-91ab-2d7cd011db47'
$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $SubscriptionAccessCredentialName

Try
{
    Add-AzureRmAccount -Credential $SubscriptionAccessCredential `
                       -TenantId $SubscriptionAccessTenant

    $Subscriptions = Get-AzureRmSubscription
    Foreach($Subscription in $Subscriptions)
    {
        Select-AzureRmSubscription -SubscriptionId $Subscription.SubscriptionId
        $Accounts = Find-AzureRmResource -ResourceType Microsoft.Automation/AutomationAccounts -ExpandProperties

        Foreach($Account in $Accounts)
        {
            if($Account.Properties.sku.name -eq 'Free')
            {
                $Account.Properties.sku.name = 'Basic'
                $Account | Set-AzureRmResource -Force
            }
        }
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
