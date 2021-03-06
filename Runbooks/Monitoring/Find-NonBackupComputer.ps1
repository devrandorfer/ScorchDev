﻿<#
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

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Find-NonBackupComputer.ps1

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

    $ProtectedVM = @()
    $Vault = Get-AzureRmRecoveryServicesVault
    Foreach($_Vault in $Vault)
    {
        $_Vault | Set-AzureRmRecoveryServicesVaultContext
        $Container = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVM
        Foreach($_Container in $Container)
        {
            $ProtectedVM += "$($_Container.FriendlyName.ToLower());$($_Container.ResourceGroupName.ToLower())"
        }
    }
    
    $VM = Get-AzureRmVM
    Foreach($_VM in $VM)
    {
        if($ProtectedVM -notcontains "$($_VM.Name.ToLower());$($_VM.ResourceGroupName.ToLower())")
        {
            Invoke-AutomationWatcherAction -CustomProperties @{
                'VMName' = $_VM.Name
                'VMResourceGroup' = $_VM.ResourceGroupName
                'Location' = $_VM.Location
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
