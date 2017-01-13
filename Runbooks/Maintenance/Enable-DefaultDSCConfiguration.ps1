<#
    .SYNOPSIS
        Enrolls a machine into Azure Automation DSC with a default configuration.

    .Description
        Designed to be triggered from a watcher task. 

#>
Param(
    $EventData
)

Import-Module SCOrchDev-Utility -Verbose:$False
Import-Module SCOrchDev-Exception -Verbose:$False
Import-Module SCOrchDev-File -Verbose:$False
Import-Module SCOrchDev-GitIntegration -Verbose:$False
Import-Module AzureRM.Profile -Verbose:$False

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Enable-DefaultDSCConfiguration.ps1 -String ($EventData | ConvertTo-Json)

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'SubscriptionAccessTenant',
                                                'AutomationAccountName',

$Vars = Get-BatchAutomationVariable -Prefix 'DSCComputer' `
                                    -Name @(
    'NodeConfigurationName'
)

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

    Register-AzureRmAutomationDscNode -AzureVMName $EventData.EventProperties.PropertyBag.VMName `
                                      -AzureVMResourceGroup $EventData.EventProperties.PropertyBag.VMResourceGroup `
                                      -AutomationAccountName $GlobalVars.AutomationAccountName `
                                      -ResourceGroupName $GlobalVars.ResourceGroupName `
                                      -NodeConfigurationName $Vars.NodeConfigurationName
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
