<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

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
$CompletedParameters = Write-StartingMessage -CommandName Enable-IaaSBackup.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

    $Vault = (Get-AzureRmRecoveryServicesVault | Where-Object { $_.Location -eq $EventData.EventProperties.PropertyBag.Location })
    if(-not $Vault) 
    { 
        Throw-Exception -Type 'VaultNotFound' `
                        -Message 'No Vault found in region' `
                        -Property @{ 'region' = $EventData.EventProperties.PropertyBag.Region } 
    }
    if(($Vault -as [array]).Count -gt 1) { $Vault = $Vault[0] }
    $Vault | Set-AzureRmRecoveryServicesVaultContext
    $DefaultPolicy = Get-AzureRmRecoveryServicesBackupProtectionPolicy -Name DefaultPolicy
    Enable-AzureRmRecoveryServicesBackupProtection -Policy $DefaultPolicy `
                                                   -Name $EventData.EventProperties.PropertyBag.VMName `
                                                   -ResourceGroupName $EventData.EventProperties.PropertyBag.VMResourceGroup
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
