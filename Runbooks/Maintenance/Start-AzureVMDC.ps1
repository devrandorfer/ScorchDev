﻿<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Start-AzureVMDC

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName

    Get-AzureRmVM | ? {$_.ResourceGroupName -eq 'DomainController'} | % {
        $VM = $_
        Start-Job -Name $VM.Name -ScriptBlock {
            $VerbosePreference = $Using:VerbosePreference
            $SubscriptionAccessCredential = $Using:SubscriptionAccessCredential
            $GlobalVars = $Using:GlobalVars
            $VM = $Using:VM
            Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                                   -SubscriptionName $GlobalVars.SubscriptionName
            $VM | Start-AzureRmVM -ErrorAction SilentlyContinue
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
