<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

    $SubscriptionId = 'cf514085-da15-4bc6-9a3d-11b32ef4f33b'
    $Location = 'EastUS2'
    $VnetAddressPrefix = '10.0.0.0/16'
    $GatewaySubnetPrefix = '10.0.0.0/25'
    $SecuritySubnetPrefix = '10.0.0.128/25'
    $FrontendSubnetPrefix = '10.0.1.0/24'
    $BackendSubnetPrefix = '10.0.2.0/24'
    $SubscriptionPrefix = 'sco'
    $NetworkGroup = 'NetworkingTeam'
    $ExpressRoute = $False
#>
Param(
    $SubscriptionId,
    $Location = 'EastUS2',
    $VnetAddressPrefix = '10.0.0.0/16',
    $GatewaySubnetPrefix  = '10.0.0.0/25',
    $SecuritySubnetPrefix  = '10.0.0.128/25',
    $FrontendSubnetPrefix  = '10.0.1.0/24',
    $BackendSubnetPrefix = '10.0.2.0/24',
    $SubscriptionPrefix = 'sco',
    $NetworkGroup = 'NetworkingTeam',
    $ExpressRoute = $True
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
                       -SubscriptionId $SubscriptionId

    Register-AzureRmProviderFeature -FeatureName AllowVnetPeering -ProviderNamespace Microsoft.Network | Out-Null
    Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Network | Out-Null
    
    $ManagementResourceGroupName = "$SubscriptionPrefix-management-rg"
    $ResourceGroup = Find-AzureRmResourceGroup
    $MgmtGroup = $ResourceGroup | Where-Object { $_.Name -eq $ManagementResourceGroupName }
    if(-not $MgmtGroup)
    {
        $WorkspaceName = "$($SubscriptionPrefix)-loganalytics"
        New-AzureRmResourceGroup -Name $ManagementResourceGroupName -Location $Location -Force
        $Workspace = New-AzureRmOperationalInsightsWorkspace -ResourceGroupName $ManagementResourceGroupName `
                                                             -Name $WorkspaceName `
                                                             -Location EastUS `
                                                             -Sku standard `
                                                             -Force

        New-AzureRmOperationalInsightsAzureAuditDataSource -WorkspaceName $Workspace.Name `
                                                    -ResourceGroupName $Workspace.ResourceGroupName `
                                                    -SubscriptionId $SubscriptionId `
                                                    -Name $SubscriptionId -Force
    
        $LogAnalyticsResouce = Get-AzureRmResource -ResourceName $WorkspaceName `
                                                   -ResourceGroupName $ManagementResourceGroupName `
                                                   -ResourceType "Microsoft.OperationalInsights/workspaces"

        $LogAnalyticsResouce.Properties.sku.name = 'pernode'
        $LogAnalyticsResouce.Properties.retentionInDays = 720
        $LogAnalyticsResouce | Set-AzureRmResource -Force

        $AutomationAccountName = "$($SubscriptionPrefix)-automation"
        New-AzureRmAutomationAccount -ResourceGroupName $ManagementResourceGroupName `
                                     -Name $AutomationAccountName `
                                     -Location eastus2 `
                                     -Plan Basic
    }

    $NetworkingResourceGroupName = "$SubscriptionPrefix-$Location-networking-rg"
    New-AzureRmResourceGroup -Name $NetworkingResourceGroupName -Location $Location -Force
    if($ExpressRoute) { $TemplateFile = 'C:\git\ScorchDev\ARM\SubscriptionVNetExpressRouteGateway\azuredeploy.json' }
    else              { $TemplateFile = 'C:\git\ScorchDev\ARM\SubscriptionVNetGateway\azuredeploy.json' }
    New-AzureRmResourceGroupDeployment -Name "$([guid]::NewGuid())" `
                                        -ResourceGroupName $NetworkingResourceGroupName `
                                        -Mode Incremental `
                                        -TemplateFile $TemplateFile `
                                        -Force `
                                        -SubscriptionPrefix $SubscriptionPrefix `
                                        -VnetAddressPrefix $VnetAddressPrefix `
                                        -GatewaySubnetPrefix $GatewaySubnetPrefix `
                                        -SecuritySubnetPrefix $SecuritySubnetPrefix `
                                        -FrontendSubnetPrefix $FrontendSubnetPrefix `
                                        -BackendSubnetPrefix $BackendSubnetPrefix

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
            $E = $_
            if($E.Exception.Message -eq 'RoleDefinitionWithSameNameExists: A role definition cannot be updated with a name that already exists.')
            {
                Try
                {
                    $CurrentRole = Get-AzureRmRoleDefinition -Name $Role.Name
                    $CurrentRole.Actions = $Role.Actions
                    $CurrentRole.NotActions = $Role.NotActions
                    Set-AzureRmRoleDefinition -Role $CurrentRole
                }
                Catch
                {
                    Write-Exception -Exception $_
                }
            }
            else
            {
                Write-Exception -Exception $E -Stream Warning
            }
        }
    } 
    
    # Give network team access to networking resource group
    $ContributorRole = Get-AzureRmRoleDefinition -Name 'Contributor'
    $SpokeNetworkGroup = Get-AzureRmADGroup -SearchString $NetworkGroup | Where-Object { $_.DisplayName -eq $NetworkGroup }
    New-AzureRmRoleAssignment -ObjectId $SpokeNetworkGroup.Id -RoleDefinitionId $ContributorRole.Id -Scope "/subscriptions/$SubscriptionId/ResourceGroups/$NetworkingResourceGroupName"  
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
