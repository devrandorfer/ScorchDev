<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(
)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-LogAnalyticsDetectionStream

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
    
    $Query = 'Type=Perf ObjectName="Processor" CounterName="% Processor Time"'

    $Result = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $LogAnalyticsVars.ResourceGroupName `
                                                          -WorkspaceName $LogAnalyticsVars.WorkspaceName `
                                                          -Query $Query `
                                                          -Top 1000
    $Data = $TopLevelResult.Value | ConvertFrom-JSON
    $HT = ConvertTo-HashTable -InputObject $Data -KeyName 'Computer'
    $DataSetSizeTarget = 10000

    Foreach($Activity in $TopLevelData)
    {
        $Query = @"
Type=SecurityEvent Activity="$($Activity.Activity)"
"@
        $DataSet = @()
        $Result = $null
        $Result = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $LogAnalyticsVars.ResourceGroupName `
                                                              -WorkspaceName $LogAnalyticsVars.WorkspaceName `
                                                              -Query $Query `
                                                              -Top 1000

        $ResultData = $Result.Value | ConvertFrom-JSON
        $DataSet += $ResultData
        While($ResultData.Count -gt 0 -and $DataSet.Count -lt $DataSetSizeTarget)
        {
            $Result = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $LogAnalyticsVars.ResourceGroupName `
                                                                  -WorkspaceName $LogAnalyticsVars.WorkspaceName `
                                                                  -Query $Query `
                                                                  -Top 1000 `
                                                                  -End $ResultData[-1].TimeGenerated
            $ResultData = $Result.Value | ConvertFrom-JSON
            $DataSet += $ResultData                                                
        }
        $DataSet | Export-CSV -Path "~\Desktop\SecurityEvent-$($Activity.Activity)csv" -NoTypeInformation
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
