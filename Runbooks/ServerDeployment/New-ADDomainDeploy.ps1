<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName New-ADDomainDeploy

$zzGlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant',
                                                'ResourceGroupName',
                                                'AutomationAccountName'

$ADDomainDeployVars = Get-BatchAutomationVariable -Prefix 'ADDomainDeploy' `
                                                  -Name 'ResourceGroupName',
                                                        'ResourceGroupLocation',
                                                        'StorageAccountName',
                                                        'VirtualNetworkResourceGroup',
                                                        'VirtualNetworkName',
                                                        'subnetName'

$DefaultDomainVars = Get-BatchAutomationVariable -Prefix 'Global' `
                                                 -Name 'LocalCredentialName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $zzGlobalVars.SubscriptionAccessCredentialName
$LocalCredential =  Get-AutomationPSCredential -Name $DefaultDomainVars.LocalCredentialName

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $zzGlobalVars.SubscriptionName `
                           -Tenant $zzGlobalVars.SubscriptionAccessTenant

    $RegistrationInfo = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName $zzGlobalVars.ResourceGroupName `
                                                              -AutomationAccountName $zzGlobalVars.AutomationAccountName

    New-AzureRmResourcegroup -Name $ADDomainDeployVars.ResourceGroupName `
                             -Location $ADDomainDeployVars.ResourceGroupLocation `
                             -Verbose `
                             -Force

    New-AzureRmResourceGroupDeployment -Name InitialDeployment `
                                       -TemplateFile 'C:\git\ScorchDev\ARM\active-directory-domain-2-dc\azuredeploy.json' `
                                       -ResourceGroupName $ADDomainDeployVars.ResourceGroupName `
                                       -newStorageAccountName $ADDomainDeployVars.StorageAccountName `
                                       -storageAccountType Standard_LRS `
                                       -virtualNetworkResourceGroup $ADDomainDeployVars.VirtualNetworkResourceGroup `
                                       -virtualNetworkName $ADDomainDeployVars.VirtualNetworkName `
                                       -subnetName $ADDomainDeployVars.subnetName `
                                       -adPDCNicIPAddress '10.0.0.5' `
                                       -adBDCNicIPAddress '10.0.0.6' `
                                       -adminUsername $LocalCredential.UserName `
                                       -adminPassword $LocalCredential.Password `
                                       -registrationKey ($RegistrationInfo.PrimaryKey | ConvertTo-SecureString -AsPlainText -Force) `
                                       -registrationUrl $RegistrationInfo.Endpoint `
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
