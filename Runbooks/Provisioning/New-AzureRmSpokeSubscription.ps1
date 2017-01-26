<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

    $SubscriptionId = '324e6933-061b-4de1-acc8-a00229996cf3'
    $HubSubscriptionId = 'cf514085-da15-4bc6-9a3d-11b32ef4f33b'
    $Location = 'EastUS2'
    $VnetAddressPrefix = '10.1.0.0/16'
    $PublicSubnetPrefix = '10.1.0.0/24'
    $PrivateSubnetPrefix = '10.1.1.0/24'
    $CompanyPrefix = 'scoa'
    $OwnerGroup = 'DevOpsTeam'

#>
Param(
    $SubscriptionId,
    $HubSubscriptionId,
    $Location = 'EastUS2',
    $VnetAddressPrefix = '10.0.0.0/16',
    $GatewaySubnetPrefix  = '10.0.0.0/24',
    $PublicSubnetPrefix  = '10.0.1.0/24',
    $PrivateSubnetPrefix = '10.0.2.0/24',
    $CompanyPrefix = 'sco',
    $Type,
    $OwnerGroup
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
    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.RecoveryServices

    $MgmtGroup = Find-AzureRmResourceGroup | Where-Object { $_.ResourceGroupName -eq $ManagementResourceGroupName }
    if(-not $MgmtGroup)
    {
        New-AzureRmResourceGroup -Name 'Management' -Location $Location -Force
        New-AzureRmOperationalInsightsWorkspace -ResourceGroupName $ManagementResourceGroupName `
                                                -Name $WorkspaceName `
                                                -Location EastUS `
                                                -Sku standard `
                                                -Force

        $WorkspaceName = "$($CompanyPrefix)LogAnalytics"
        $LogAnalyticsResouce = Get-AzureRmResource -ResourceName $WorkspaceName `
                                                   -ResourceGroupName $ManagementResourceGroupName `
                                                   -ResourceType "Microsoft.OperationalInsights/workspaces"

        $LogAnalyticsResouce.Properties.sku.name = 'pernode'
        $LogAnalyticsResouce.Properties.retentionInDays = 31
        $LogAnalyticsResouce | Set-AzureRmResource -Force

        
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
                                       -TemplateFile 'C:\git\ScorchDev\ARM\SubscriptionVNet\azuredeploy.json' `
                                       -Force `
                                       -companyPrefix $CompanyPrefix `
                                       -vnetAddressPrefix $VnetAddressPrefix `
                                       -publicSubnetPrefix $PublicSubnetPrefix `
                                       -privateSubnetPrefix $PrivateSubnetPrefix
    
    # Setup peering relationships
    $spokeVNet = Get-AzureRMVirtualNetwork -ResourceGroupName 'Networking' -Name "$CompanyPrefix-$Location"
    Select-AzureRmSubscription -SubscriptionId $HubSubscriptionId
    $hubVNet = Get-AzureRMVirtualNetwork -ResourceGroupName 'Networking' | Where-Object { $_.Location -eq $Location }
    Add-AzureRmVirtualNetworkPeering -Name "$($hubVNet.Name)-to-$($spokeVNet.Name)" -VirtualNetwork $hubVNet -RemoteVirtualNetworkId $spokeVNet.Id -AllowGatewayTransit

    Select-AzureRmSubscription -SubscriptionId $SubscriptionId
    Add-AzureRmVirtualNetworkPeering -Name "$($spokeVNet.Name)-to-$($hubVNet.Name)" -VirtualNetwork $spokeVNet -RemoteVirtualNetworkId $hubVNet.Id -UseRemoteGateways -AllowForwardedTraffic
    
    # Setup public subnet next hop
    $route = New-AzureRmRouteConfig -Name TestNVA -AddressPrefix $PublicSubnetPrefix -NextHopType VirtualAppliance -NextHopIpAddress 10.0.0.4
    $routeTable = New-AzureRmRouteTable -ResourceGroupName 'Networking' -Location brazilsouth -Name TestRT -Route $route
    Set-AzureRmVirtualNetworkSubnetConfig -VirtualNetwork $spokeVNet -Name Public -AddressPrefix 10.1.1.0/24 -RouteTable $routeTable
    Set-AzureRmVirtualNetwork -VirtualNetwork $vnet1

    # Lock deployed network resource group
    New-AzureRmResourceLock -LockName 'NetworkResourceGroupLock' `
                            -LockLevel ReadOnly `
                            -ResourceGroupName 'Networking' `
                            -Force

    # Add this subscription to assignable scope for all custom roles
    $Roles = Get-AzureRmRoleDefinition -Custom
    Foreach($Role in $Roles)
    {
        if($Role.AssignableScopes -notcontains "/subscriptions/$SubscriptionId")
        {
            $Role.AssignableScopes += "/subscriptions/$SubscriptionId"
            Set-AzureRmRoleDefinition -Role $Role
        }
    }

    # Give owner group access to spoke-owner role
    $SpokeOwnerRole = $Roles | ? { $_.Name -eq 'Spoke Contributor'  }
    $SpokeOwnerGroup = Get-AzureRmADGroup -SearchString $OwnerGroup
    New-AzureRmRoleAssignment -ObjectId $SpokeOwnerGroup.Id -RoleDefinitionId $SpokeOwnerRole.Id -Scope "/subscriptions/$SubscriptionId"
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
