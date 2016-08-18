<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-SkypeOnlineAudioData

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'WorkspaceId'

$SharePointVars = Get-BatchAutomationVariable -Prefix 'SharePoint' `
                                              -Name 'CredentialName'

$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

$Credential = Get-AutomationPSCredential -Name $SharePointVars.CredentialName
Try
{
    $DataToSave = @()
    Connect-MsolService -Credential $Credential
    
    $Sku = Get-MsolAccountSku
    Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $Sku -LogType 'Office365License_CL'
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
