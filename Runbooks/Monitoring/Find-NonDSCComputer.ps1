<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)

Import-Module SCOrchDev-Utility -Verbose:$False
Import-Module SCOrchDev-Exception -Verbose:$False
Import-Module SCOrchDev-File -Verbose:$False
Import-Module SCOrchDev-GitIntegration -Verbose:$False
Import-Module AzureRM.Profile -Verbose:$False
Import-Module AzureRM.Resources -Verbose:$False
Import-Module AzureRM.Automation -Verbose:$False

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Find-NonDSCComputer.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'AutomationAccountName',
                                                'SubscriptionAccessTenant'

$Vars = Get-BatchAutomationVariable -Prefix 'DSCComputer' `
                                    -Name @(
    'TargetVNet',
    'NodeConfigurationName'
)

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
    
    $Vnet = $vars.TargetVNet | ConvertFrom-Json

    $VirtualMachine = Get-AzureRmVM
    Foreach($VM in $VirtualMachine)
    {
        if(($VM | ConvertTo-Json) -notlike '*Microsoft.Powershell.DSC*')
        {
            Foreach($Nic in $VM.NetworkInterfaceIDs)
            {
                $_Nic = Get-AzureRmResource -ResourceId $Nic
                Foreach($_Vnet in $Vnet)
                {
                    if(($_Nic.Properties.ipConfigurations | ConvertTo-Json) -like "*$_Vnet*")
                    {
                        Register-AzureRmAutomationDscNode -AzureVMName $VirtualMachine.Name `
                                                          -AutomationAccountName $GlobalVars.AutomationAccountName `
                                                          -ResourceGroupName $GlobalVars.ResourceGroupName `
                                                          -NodeConfigurationName $Vars.NodeConfigurationName
                    }
                }
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
