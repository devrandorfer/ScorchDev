﻿<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-AzureRMLog

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'SubscriptionAccessTenant'

$Vars = Get-BatchAutomationVariable -Prefix 'AzureRMLog' `
                                    -Name @(
                                        'LastSaveDateTime'
                                        'LogPath'
                                    )

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
    
    $LastSaveTime = ($Vars.LastSaveDateTime | ConvertFrom-Json).DateTime -as [datetime]
    $CurrentSaveTime = Get-Date
    if(($CurrentSaveTime - $LastSaveTime).Days -gt 15) { $LastSaveTime = $CurrentSaveTime.AddDays(-15) }
    $Log = Get-AzureRmLog -StartTime $LastSaveTime -EndTime $CurrentSaveTime -DetailedOutput `
        | ForEach-Object -Process { 
            Select-Object -InputObject $_ -Property * -ExcludeProperty Claims 
        }
    

    if(-not (Test-Path -Path $Vars.LogPath)) { $Null = New-Item -ItemType Directory -Path $Vars.LogPath }
    Get-ChildItem -Path $Vars.LogPath | ForEach-Object { if($_.CreationTime -lt (Get-Date).AddDays(-1)) { Remove-Item -Path $_.FullName } }
    
    $LogName = "$($Vars.LogPath)\AzureRMLog.$(Get-Date -f 'yyyy-MM-dd-hh-mm-ss').txt"
    foreach($Event in $Log)
    {
        Add-Content -Value "$((Get-Date $Event.EventTimestamp -Format 'yyyy-MM-dd HH:mm:ss')) : $($Event | ConvertTo-JSON -Compress)" -Path $LogName
    }

    Set-AutomationVariable -Name 'AzureRMLog-LastSaveDateTime' -Value (($CurrentSaveTime | ConvertTo-JSON -Compress) -as [string])
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
