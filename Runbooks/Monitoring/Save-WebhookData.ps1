﻿<#
    .SYNOPSIS
       Saves data passed in from a webhook to Log Analytics

    .Description
        Designed to be run inside of Azure Automation. Each webhook that is created on the runbook will be given
        its own unqiue type inside of log analytics in the form webhooname_CL. All header properties are added
        as unique properties to the type schema. The request body is converted from JSON and injected into Log
        Analytics.

#>
Param(
    [object] $WebhookData
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-WebhookData.ps1

$OMSVars = Get-BatchAutomationVariable -Prefix 'LogAnalytics' `
                                       -Name 'WorkspaceId'

$WorkspaceCredential = Get-AutomationPSCredential -Name $OMSVars.WorkspaceID

Try
{   
    $Data = @()

    $RequestHeader = $WebhookData.RequestHeader | ConvertFrom-PSCustomObject

    Try
    {
        $RequestBody = $WebhookData.RequestBody | ConvertFrom-Json | ConvertFrom-PSCustomObject
        
        Foreach($Entry in $RequestBody)
        {
            $Item = @{}
            foreach($Key in $Entry.Keys)
            {
                Try
                {
                    $TypeName = $Entry.$Key.GetType().Name 
                    if($TypeName -eq 'PSCustomObject')
                    {
                        Try
                        {
                            $InnerObject = $Entry.$Key | ConvertFrom-PSCustomObject
                            Foreach($InnerKey in $InnerObject.Keys)
                            {
                                $Item.Add("$($key)_$($InnerKey)",$InnerObject.$InnerKey) | Out-Null
                            }
                        }
                        Catch
                        {
                            $Item.Add($key,$Entry.$Key) | Out-Null
                        }
                    }
                    else
                    {
                        $Item.Add($key,$Entry.$Key) | Out-Null
                    }
                }
                Catch
                {
                    $Item.Add($Key,$Entry.$Key) | Out-Null
                }
            }
            $Item += $RequestHeader
            $Data += $Item
        }
    }
    Catch
    {
        $RequestHeader.Add('RequestBody',$WebhookData.RequestBody)  | Out-Null
        $Data += $RequestHeader
    }

    Write-LogAnalyticsLogEntry -WorkspaceId $OMSVars.WorkspaceId `
                            -Key $WorkspaceCredential.GetNetworkCredential().Password `
                            -Data $Data `
                            -LogType "$($WebhookData.WebhookName)_CL"
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