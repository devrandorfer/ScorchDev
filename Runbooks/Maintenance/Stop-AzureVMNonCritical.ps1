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
$CompletedParameters = Write-StartingMessage -CommandName Stop-AzureVMNonCritial

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant'

$Vars = Get-BatchAutomationVariable -Prefix 'AzureVMMaintenance' `
                                    -Name 'CriticalResourceGroupName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
    Get-AzureRmVM | ? {$_.ResourceGroupName -notin ($Vars.CriticalResourceGroupName | ConvertFrom-Json)} | % {
        $VM = $_
        Start-Job -Name $VM.Name -ScriptBlock {
            $VerbosePreference = $Using:VerbosePreference
            $SubscriptionAccessCredential = $Using:SubscriptionAccessCredential
            $GlobalVars = $Using:GlobalVars
            $VM = $Using:VM
            Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                                   -SubscriptionName $GlobalVars.SubscriptionName `
                                   -Tenant $GlobalVars.SubscriptionAccessTenant
            $VM | Stop-AzureRmVM -Force -ErrorAction SilentlyContinue
        }
    }

    Get-Job | Receive-Job -Wait -AutoRemoveJob
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
