<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Set-FirewallRemediation

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
    
    $VMName = 'pezud'    
    $VMObj = Find-AzureRmResource -ResourceNameContains $VMName -ResourceType 'Microsoft.Compute/virtualMachines'
    $VirtualMachine = Get-AzureRmVM -ResourceGroupName $VMObj.ResourceGroupName -Name $VMObj.Name

    Foreach($NetworkInterfaceId in $VirtualMachine.NetworkInterfaceIDs)
    {
        $NetworkInterface = Get-AzureRmResource -ResourceId $NetworkInterfaceId
        Foreach($NetworkSecurityGroupId in $NetworkInterface.Properties.networkSecurityGroup)
        {
            $NetworkSecurityGroup = Get-AzureRMResource -ResourceId $NetworkSecurityGroupId.id
            Add-AzureRmNetworkSecurityRuleConfig -Name "BlockIPAddress" -NetworkSecurityGroup $NetworkSecurityGroup -Protocol *
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
