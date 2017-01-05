<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

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
        
        $Item = @{}
        foreach($Key in $RequestBody.Keys)
        {
            Try
            {
                $TypeName = $RequestBody.$Key.GetType().Name 
                if($TypeName -eq 'PSCustomObject')
                {
                    Try
                    {
                        $InnerObject = $RequestBody.$Key | ConvertFrom-PSCustomObject
                        Foreach($InnerKey in $InnerObject.Keys)
                        {
                            $Item.Add("$($key)_$($InnerKey)",$InnerObject.$InnerKey) | Out-Null
                        }
                    }
                    Catch
                    {
                        $Item.Add($key,$RequestBody.$Key) | Out-Null
                    }
                }
                else
                {
                    $Item.Add($key,$RequestBody.$Key) | Out-Null
                }
            }
            Catch
            {
                $Item.Add($Key,$RequestBody.$Key)
            }
        }
        $RequestBody += $RequestHeader
        $Data += $RequestBody
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
