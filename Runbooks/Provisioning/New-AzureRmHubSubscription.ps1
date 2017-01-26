﻿<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

    $SubscriptionId = 'cf514085-da15-4bc6-9a3d-11b32ef4f33b'
    $Location = 'EastUS2'
    $VnetAddressPrefix = '10.0.0.0/16'
    $GatewaySubnetPrefix = '10.0.0.0/24'
    $PublicSubnetPrefix = '10.0.1.0/24'
    $PrivateSubnetPrefix = '10.0.2.0/24'
    $CompanyPrefix = 'sco'

#>
Param(
    $SubscriptionId,
    $Location = 'EastUS2',
    $VnetAddressPrefix = '10.0.0.0/16',
    $GatewaySubnetPrefix  = '10.0.0.0/24',
    $PublicSubnetPrefix  = '10.0.1.0/24',
    $PrivateSubnetPrefix = '10.0.2.0/24',
    $CompanyPrefix = 'sco'
)

Import-Module SCOrchDev-Utility -Verbose:$False
Import-Module SCOrchDev-Exception -Verbose:$False
Import-Module SCOrchDev-File -Verbose:$False
Import-Module SCOrchDev-GitIntegration -Verbose:$False
Import-Module AzureRM.Profile -Verbose:$False

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName New-AzureRmHubSubscription.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'altGlobal' `
                                          -Name 'SubscriptionAccessCredentialName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName

$ManagementResourceGroupName = 'Management'
Try
{
    Add-AzureRmAccount -Credential $SubscriptionAccessCredential `
                       -SubscriptionId $SubscriptionId

    Register-AzureRmProviderFeature -FeatureName AllowVnetPeering -ProviderNamespace Microsoft.Network | Out-Null
    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Network | Out-Null
    
    $MgmtGroup = Find-AzureRmResourceGroup | Where-Object { $_.ResourceGroupName -eq $ManagementResourceGroupName }
    if(-not $MgmtGroup)
    {
        New-AzureRmResourceGroup -Name 'Management' -Location $Location -Force
        New-AzureRmOperationalInsightsWorkspace -ResourceGroupName $ManagementResourceGroupName `
                                                -Name "$($CompanyPrefix)LogAnalytics" `
                                                -Location EastUS `
                                                -Sku standard `
                                                -Force
    
        New-AzureRmAutomationAccount -ResourceGroupName $ManagementResourceGroupName `
                                     -Name "$($CompanyPrefix)-automation" `
                                     -Location eastus2 `
                                     -Plan Basic
    
        New-AzureRmRecoveryServicesVault -ResourceGroupName $ManagementResourceGroupName `
                                         -Name "$($CompanyPrefix)-$($Location)-vault" `
                                         -Location $Location
    }

    New-AzureRmResourceGroup -Name 'Networking' -Location $Location -Force
    New-AzureRmResourceGroupDeployment -Name 'InitialDeployment' `
                                       -ResourceGroupName 'Networking' `
                                       -Mode Incremental `
                                       -TemplateFile 'C:\git\ScorchDev\ARM\SubscriptionVNetGateway\azuredeploy.json' `
                                       -Force `
                                       -companyPrefix $CompanyPrefix `
                                       -vnetAddressPrefix $VnetAddressPrefix `
                                       -gatewaySubnetPrefix $GatewaySubnetPrefix `
                                       -publicSubnetPrefix $PublicSubnetPrefix `
                                       -privateSubnetPrefix $PrivateSubnetPrefix

    Foreach($RoleFile in (Get-ChildItem -Path C:\git\SCOrchDev\Roles))
    {
        Try
        {
            $Role = (Get-Content -Path $RoleFile.FullName) | ConvertFrom-Json
            $Role.AssignableScopes += "/subscriptions/$SubscriptionId"
            New-AzureRmRoleDefinition -Role $Role
        }
        Catch 
        { 
            $CurrentRole = Get-AzureRmRoleDefinition -Name $Role.Name
            $CurrentScopes = $CurrentRole.AssignableScopes
            $Role.AssignableScopes = $CurrentScopes
            Set-AzureRmRoleDefinition -Role $Role
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
