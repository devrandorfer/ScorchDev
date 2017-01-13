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
        $IndividualCompleted = Write-StartingMessage -CommandName 'Checking Machine for DSC Extension' -String $VM.Name
        if(($VM | ConvertTo-Json) -notlike '*Microsoft.Powershell.DSC*')
        {
            $Status = 'No DSC Extension Found.'
            Foreach($Nic in $VM.NetworkInterfaceIDs)
            {
                $_Nic = Get-AzureRmResource -ResourceId $Nic
                Foreach($_Vnet in $Vnet)
                {
                    if(($_Nic.Properties.ipConfigurations | ConvertTo-Json) -like "*$_Vnet*")
                    {
                        Invoke-AutomationWatcherAction -CustomProperties @{
                            'VMName' = $VM.Name
                            'VMResourceGroup' = $VM.ResourceGroupName
                        }
                    }
                    else
                    {
                        $Status = "$Status - No nic on $_Vnet"
                    }
                }
            }
        }
        else { $Status = 'DSC Enabled' }
        Write-CompletedMessage @IndividualCompleted -Status $Status
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
