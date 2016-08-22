<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName New-AzureRMLogAlertToAA

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

    $RG = new-azurermresourcegroup -location 'east us 2' -Name myrg1
    $actionWebhook = New-AzureRmAlertRuleWebhook -ServiceUri 'https://s1events.azure-automation.net/webhooks?token=5Zi8An8CVuj2CXQ3HcX2u0KFRYZ2KjR1PnZYBq6E7Hs%3d'
    Add-AzureRmLogAlertRule -Name superalert1 -Location "East US 2" -ResourceGroup myrg1 -Actions $actionWebhook -OperationName *
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
