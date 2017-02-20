<#
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
$CompletedParameters = Write-StartingMessage -CommandName Find-AzureRMVMToShutdown.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'SubscriptionAccessTenant'

$Vars = Get-BatchAutomationVariable -Prefix 'VMPowerMaintenance' `
                                    -Name 'ShutdownRunbookUri'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Add-AzureRmAccount -Credential $SubscriptionAccessCredential `
                       -SubscriptionName $GlobalVars.SubscriptionName `
                       -TenantId $GlobalVars.SubscriptionAccessTenant `
                       -ServicePrincipal | Out-Null

    # Find all Azure VMs with Autoshutdown tag

    $VirtualMachine = Find-AzureRmResource -Tag @{ 'Autoshutdown' = 'True' } | ? { $_.ResourceType -eq 'Microsoft.Compute/virtualMachines' }

    Foreach($_VirtualMachine in $VirtualMachine)
    {
        Invoke-RestMethod -Method Post -Uri $Vars.ShutdownRunbookUri -Body "{`"ResourceGroupName`":`"$($_VirtualMachine.ResourceGroupName)`",`"Name`":`"$($_VirtualMachine.Name)`",`"SubscriptionId`":`"$($_VirtualMachine.SubscriptionId)`"}"
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
