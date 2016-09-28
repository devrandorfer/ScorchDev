<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Get-AnomalousLogin

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName'

$OMSVars = Get-BatchAutomationVariable -Prefix 'LogAnalytics' `
                                       -Name 'WorkspaceId',
                                             'ResourceGroupName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$OMSCred = Get-AutomationPSCredential -Name $OMSVars.WorkspaceId
Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName
    
    $LastSaveDate = Get-AutomationVariable -Name 'WindowsLoginGrouping-LastSaveDate'
    $CurrentDate = Get-Date
    $SearchResult = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $OMSVars.ResourceGroupName `
                                                                -WorkspaceName $OMSVars.WorkspaceId `
                                                                -Query 'Type=SecurityEvent (EventID=4625 OR EventID=4625)  Account!="NT AUTHORITY\\SYSTEM" | measure count() by Computer,Account,EventID INTERVAL 1Minute' `
                                                                -Start (Get-date).AddDays(-7) -End $CurrentDate -Top 5000
    if($SearchResult.Value.Count -gt 0)
    {
        Write-LogAnalyticsLogEntry -WorkspaceId $OMSVars.WorkspaceId `
                                   -Key $OMSCred.GetNetworkCredential().Password `
                                   -Data ($SearchResult.Value | ConvertFrom-Json) `
                                   -LogType 'WindowsLogin_CL' `
                                   -TimeStampField 'TimeGenerated'
    }

    Set-AutomationVariable -Name 'WindowsLoginGrouping-LastSaveDate' -Value $CurrentDate 
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
