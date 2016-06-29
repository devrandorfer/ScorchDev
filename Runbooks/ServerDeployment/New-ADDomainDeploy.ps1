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

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant'

$ADDomainDeployVars = Get-BatchAutomationVariable -Prefix 'ADDomainDeploy' `
                                                  -Name 'ResourceGroupName',
                                                        'ResourceGroupLocation',
                                                        'StorageAccountName',
                                                        'VirtualNetworkResourceGroup',
                                                        'VirtualNetworkName',
                                                        'subnetName'

$DefaultDomainVars = Get-BatchAutomationVariable -Prefix 'Global' `
                                                 -Name 'LocalCredentialName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$DomainCredential = Get-AutomationPSCredential -Name $DefaultDomainVars.DomainCredentialName

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

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
                                       -adminUsername $DomainCredential.UserName `
                                       -adminPassword $DomainCredential.Password `
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
