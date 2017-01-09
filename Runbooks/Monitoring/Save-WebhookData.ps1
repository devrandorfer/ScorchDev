<#
    .SYNOPSIS
       Saves data passed in from a webhook to Log Analytics

    .Description
        Designed to be run inside of Azure Automation. Each webhook that is created on the runbook will be given
        its own unqiue type inside of log analytics in the form webhooname_CL. All header properties are added
        as unique properties to the type schema. The request body is converted from JSON and injected into Log
        Analytics.

        An example usecase: Inserting push information from a github repository into a log analytics workspace.

#>
Param(
    [object] $WebhookData,
    [string] $TimeStampField,
    [string] $LogType
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-WebhookData.ps1 -String $LogType

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
                                # Try converting value to int
                                Try
                                {
                                    $Value = $InnerObject.$InnerKey -as [double]
                                    if($Value -eq $null) { $Value = $InnerObject.$InnerKey }
                                }
                                Catch
                                {
                                    $Value = $InnerObject.$InnerKey
                                }
                                $Item.Add("$($key)_$($InnerKey)",$Value) | Out-Null
                            }
                        }
                        Catch
                        {
                            $Item.Add($key,$Entry.$Key) | Out-Null
                        }
                    }
                    else
                    {
                        Try
                        {
                            $Value = $Entry.$Key -as [double]
                            if($Value -eq $null) { $Value = $Entry.$Key }
                        }
                        Catch
                        {
                            $Value = $Entry.$Key
                        }
                        $Item.Add($key,$Value) | Out-Null
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

    if($LogType) { if($LogType -notlike '*_CL') { $LogType = "$($LogType)_CL" } }
    else { $LogType = "$($WebhookData.WebhookName)_CL" }

    $Params = @{
        'WorkspaceId' = $OMSVars.WorkspaceId
        'Key' = $WorkspaceCredential.GetNetworkCredential().Password
        'Data' = $Data
        'LogType' = $LogType
    }

    if($TimeStampField) { $Params.Add('TimeStampField',$TimeStampField) | Out-Null }

    Write-LogAnalyticsLogEntry @Params
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
