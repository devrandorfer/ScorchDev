<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(
    [Parameter(
        Mandatory=$True
    )]
    [object] $WebhookData
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-WebhookData.ps1

$OMSVars = Get-BatchAutomationVariable -Prefix 'LogAnalytics' `
                                       -Name 'WorkspaceId'

$WorkspaceCredential = Get-AutomationPSCredential -Name $OMSVars.WorkspaceID

Try
{
    $WebhookObj = $WebhookData | ConvertFrom-Json
    
    $Data = @()

    $RequestHeader = $WebhookObj.RequestHeader | ConvertFrom-PSCustomObject

    Try
    {
           $RequestBody = $WebhookObj.RequestBody | ConvertFrom-Json | ConvertFrom-PSCustomObject
           $RequestBody += $RequestHeader
           $Data += $RequestBody
    }
    Catch
    {
        $RequestHeader.Add('RequestBody',$WebhookObj.RequestBody)
        $Data += $RequestHeader
    }

    Write-LogAnalyticsLogEntry -WorkspaceId $OMSVars.WorkspaceId `
                            -Key $WorkspaceCredential.GetNetworkCredential().Password `
                            -Data $Data `
                            -LogType "$($WebhookObj.WebhookName)_CL"
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
