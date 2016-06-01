<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName New-BackupVault

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

    $ResourceGroupName = 'AUtomationDemo'
    $VaultName = 'scorchDemoVault'
    $PolicyName = 'Weekly'
    New-AzureRmResourcegroup -Name $ResourceGroupName `
                             -Location 'EastUS' `
                             -Verbose `
                             -Force

    New-AzureRmResourceGroupDeployment -Name CreateVault `
                                       -TemplateFile 'C:\git\ScorchDev\ARM\101-recovery-services-vault-create\azuredeploy.json' `
                                       -vaultName $VaultName `
                                       -ResourceGroupName $ResourceGroupName `
                                       -Verbose

    New-AzureRmResourceGroupDeployment -Name CreateBackupPolicy `
                                       -TemplateFile 'C:\git\ScorchDev\ARM\101-recovery-services-weekly-backup-policy-create\azuredeploy.json' `
                                       -vaultName $VaultName `
                                       -TemplateParameterFile 'C:\git\ScorchDev\ARM\101-recovery-services-weekly-backup-policy-create\azuredeploy.parameters.json' `
                                       -ResourceGroupName $ResourceGroupName `
                                       -Verbose
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
