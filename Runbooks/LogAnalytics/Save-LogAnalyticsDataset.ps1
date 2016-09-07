<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(
    $Query = 'Type=SecurityEvent'
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-LogAnalyticsDataset

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'SubscriptionAccessTenant'

$LogAnalyticsVars = Get-BatchAutomationVariable -Prefix 'LogAnalytics' `
                                                -Name 'WorkspaceName',
                                                      'ResourceGroupName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
    
    $DataSetSizeTarget = 20000

    $DataSet = @()

    $Result = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $LogAnalyticsVars.ResourceGroupName `
                                                          -WorkspaceName $LogAnalyticsVars.WorkspaceName `
                                                          -Query $Query `
                                                          -Top 5000

    $ResultData = $Result.Value | ConvertFrom-JSON
    $DataSet += $ResultData
    While($ResultData.Count -gt 0 -and $DataSet.Count -lt $DataSetSizeTarget)
    {
        $Result = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $LogAnalyticsVars.ResourceGroupName `
                                                              -WorkspaceName $LogAnalyticsVars.WorkspaceName `
                                                              -Query $Query `
                                                              -Top 5000 `
                                                              -End $ResultData[-1].TimeGenerated
        $ResultData = $Result.Value | ConvertFrom-JSON
        $DataSet += $ResultData                                                
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
