<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(
    $SubscriptionId
)

Import-Module SCOrchDev-Utility -Verbose:$False
Import-Module SCOrchDev-Exception -Verbose:$False
Import-Module SCOrchDev-File -Verbose:$False
Import-Module SCOrchDev-GitIntegration -Verbose:$False
Import-Module AzureRM.Profile -Verbose:$False

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Clean-AzureRMSubscription.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'altGlobal' `
                                          -Name 'SubscriptionAccessCredentialName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Add-AzureRmAccount -Credential $SubscriptionAccessCredential

    $Subscription = Get-AzureRmSubscription
    Foreach($_Subscription in $Subscription)
    {
        Select-AzureRmSubscription -SubscriptionId $_Subscription.SubscriptionId
        $ResourceGroups = Get-AzureRmResourceGroup
        Try
        {
            $ResourceGroups.ResourceId | Foreach-Object { try { Remove-AzureRmResourceGroup -Id $_ -Force } catch {} }
        }
        Catch
        {
            Write-Exception -Exception $_
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
