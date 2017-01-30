<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

    $SubscriptionId = '324e6933-061b-4de1-acc8-a00229996cf3'
    $HubSubscriptionId = 'cf514085-da15-4bc6-9a3d-11b32ef4f33b'
    $Location = 'EastUS2'
    $VnetAddressPrefix = '10.1.0.0/16'
    $FrontendSubnetPrefix = '10.1.0.0/24'
    $BackendSubnetPrefix = '10.1.1.0/24'
    $SubscriptionPrefix = 'devops'
    $OwnerGroup = 'DevOpsTeam'
    $NetworkGroup = 'NetworkingTeam'

#>
Param(
    $SubscriptionId,
    $HubSubscriptionId,
    $Location = 'EastUS2',
    $VnetAddressPrefix = '10.0.0.0/16',
    $GatewaySubnetPrefix  = '10.0.0.0/24',
    $PublicSubnetPrefix  = '10.0.1.0/24',
    $PrivateSubnetPrefix = '10.0.2.0/24',
    $SubscriptionPrefix = 'sco',
    $Type,
    $OwnerGroup,
    $NetworkGroup
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

$Location = $Location.ToLower()
Try
{
    Add-AzureRmAccount -Credential $SubscriptionAccessCredential `
                       -SubscriptionId $HubSubscriptionId

    $Workspace = Get-AzureRmOperationalInsightsWorkspace
    # Configure audit logs to go to central Workspace
    New-AzureRmOperationalInsightsAzureAuditDataSource -WorkspaceName $Workspace.Name `
                                                       -ResourceGroupName $Workspace.ResourceGroupName `
                                                       -SubscriptionId $SubscriptionId `
                                                       -Name $SubscriptionId -Force

    Select-AzureRmSubscription -SubscriptionId $SubscriptionId

    Register-AzureRmProviderFeature -FeatureName AllowVnetPeering -ProviderNamespace Microsoft.Network | Out-Null
    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Network | Out-Null
    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.RecoveryServices | Out-Null

    $ManagementResourceGroupName = "$SubscriptionPrefix-management-rg"
    $ResourceGroup = Find-AzureRMResourceGroup
    $MgmtGroup = $ResourceGroup | Where-Object { $_.Name -eq $ManagementResourceGroupName }
    if(-not $MgmtGroup)
    {
        try
        {
            New-AzureRmResourceGroup -Name $ManagementResourceGroupName -Location $Location -Force
            $WorkspaceName = "$($SubscriptionPrefix)-loganalytics"
            New-AzureRmOperationalInsightsWorkspace -ResourceGroupName $ManagementResourceGroupName `
                                                    -Name $WorkspaceName `
                                                    -Location EastUS `
                                                    -Sku standard `
                                                    -Force

            $LogAnalyticsResouce = Get-AzureRmResource -ResourceName $WorkspaceName `
                                                       -ResourceGroupName $ManagementResourceGroupName `
                                                       -ResourceType "Microsoft.OperationalInsights/workspaces"

            $LogAnalyticsResouce.Properties.sku.name = 'pernode'
            $LogAnalyticsResouce.Properties.retentionInDays = 30
            $LogAnalyticsResouce | Set-AzureRmResource -Force

        
            New-AzureRmAutomationAccount -ResourceGroupName $ManagementResourceGroupName `
                                         -Name "$($SubscriptionPrefix)-automation" `
                                         -Location eastus2 `
                                         -Plan Basic
    
            New-AzureRmRecoveryServicesVault -ResourceGroupName $ManagementResourceGroupName `
                                             -Name "$($SubscriptionPrefix)-$($Location)-vault" `
                                             -Location $Location
        }
        Catch { Write-Exception -Exception $_ }
    }

    $NetworkingResourceGroupName = "$SubscriptionPrefix-$Location-networking-rg"
    New-AzureRmResourceGroup -Name $NetworkingResourceGroupName -Location $Location -Force
    New-AzureRmResourceGroupDeployment -Name "$([guid]::NewGuid())" `
                                       -ResourceGroupName $NetworkingResourceGroupName `
                                       -Mode Incremental `
                                       -TemplateFile 'C:\git\ScorchDev\ARM\SubscriptionVNet\azuredeploy.json' `
                                       -Force `
                                       -SubscriptionPrefix $SubscriptionPrefix `
                                       -VnetAddressPrefix $VnetAddressPrefix `
                                       -FrontendSubnetPrefix $FrontendSubnetPrefix `
                                       -BackendSubnetPrefix $BackendSubnetPrefix
    
    try
    {
        # Setup peering relationships
        $spokeVNet = Get-AzureRMVirtualNetwork -ResourceGroupName $NetworkingResourceGroupName -Name "$SubscriptionPrefix-$Location-vnet"
        Select-AzureRmSubscription -SubscriptionId $HubSubscriptionId
        $hubVNet = Get-AzureRMVirtualNetwork | Where-Object { $_.Location -eq $Location }
        Add-AzureRmVirtualNetworkPeering -Name "$($hubVNet.Name)-to-$($spokeVNet.Name)" -VirtualNetwork $hubVNet -RemoteVirtualNetworkId $spokeVNet.Id -AllowGatewayTransit

        Select-AzureRmSubscription -SubscriptionId $SubscriptionId
        Add-AzureRmVirtualNetworkPeering -Name "$($spokeVNet.Name)-to-$($hubVNet.Name)" -VirtualNetwork $spokeVNet -RemoteVirtualNetworkId $hubVNet.Id -UseRemoteGateways -AllowForwardedTraffic
    }
    catch { Write-Exception -Exception $_ }
    
    Select-AzureRmSubscription -SubscriptionId $HubSubscriptionId
    # Add this subscription to assignable scope for all custom roles in hub subscription
    $Roles = Get-AzureRmRoleDefinition -Custom
    Foreach($Role in $Roles)
    {
        try
        {
            if($Role.AssignableScopes -notcontains "/subscriptions/$SubscriptionId")
            {
                $Role.AssignableScopes += "/subscriptions/$SubscriptionId"
                Set-AzureRmRoleDefinition -Role $Role
            }
        }
        catch { Write-Exception -Exception $_ }
    }

    Select-AzureRmSubscription -SubscriptionId $SubscriptionId
    
    try
    {
        # Give owner group access to spoke-contributor role
        $SpokeOwnerRole = $Roles | ? { $_.Name -eq 'Spoke-Contributor'  }
        $SpokeOwnerGroup = Get-AzureRmADGroup -SearchString $OwnerGroup | Where-Object { $_.DisplayName -eq $OwnerGroup }
        New-AzureRmRoleAssignment -ObjectId $SpokeOwnerGroup.Id -RoleDefinitionId $SpokeOwnerRole.Id -Scope "/subscriptions/$SubscriptionId"
    }
    catch{ Write-Exception -Exception $_ }

    try
    {
        # Give network team access to networking resource group
        $ContributorRole = Get-AzureRmRoleDefinition -Name 'Owner'
        $SpokeNetworkGroup = Get-AzureRmADGroup -SearchString $NetworkGroup | Where-Object { $_.DisplayName -eq $NetworkGroup }
        New-AzureRmRoleAssignment -ObjectId $SpokeNetworkGroup.Id -RoleDefinitionId $ContributorRole.Id -Scope "/subscriptions/$SubscriptionId/ResourceGroups/$NetworkingResourceGroupName"
    }
    catch { Write-Exception -Exception $_ }

    try
    {
        # Lock deployed network resource group
        New-AzureRmResourceLock -LockName 'NetworkResourceGroupLock' `
                                -LockLevel ReadOnly `
                                -ResourceGroupName $NetworkingResourceGroupName `
                                -Force
    }
    catch { Write-Exception -Exception $_ }
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
