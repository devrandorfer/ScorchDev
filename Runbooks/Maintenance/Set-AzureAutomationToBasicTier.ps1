<#
    .SYNOPSIS
       Connects to Azure and enumerates all Azure Automation accounts. Any 'free tier' automation accounts are set to basic.
       Can be triggered by a schedule or through an event from OMS Log Analytics (on detection of new Automation Account Creation).
       Designed to be run inside of Azure Automation

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Set-AzureAutomationToBasicTier.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'SubscriptionAccessTenant'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

    $Subscription = Get-AzureRmSubscription

    Foreach($_Subscription in $Subscription)
    {
        Select-AzureRmSubscription -SubscriptionId $_Subscription.SubscriptionId | Write-Verbose
        $AutomationAccount = Find-AzureRmResource -ResourceType 'Microsoft.Automation/automationAccounts' -ExpandProperties | ? { $_.Properties.sku.name -eq 'Free' }

        Foreach($_AutomationAccount in $AutomationAccount)
        {
            $_AutomationAccount.Properties.sku.name = 'Basic'
            $_AutomationAccount | Set-AzureRmResource -Force | Write-Verbose
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
