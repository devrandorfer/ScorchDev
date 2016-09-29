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
    $StdDevSearchResult = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $OMSVars.ResourceGroupName `
                                                                      -WorkspaceName $OMSVars.WorkspaceId `
                                                                      -Query 'Type=WindowsLoginAggregation_CL | measure stddev(Value_d), avg(Value_d) by Computer,Account_s,EventID_d' `
                                                                      -Start (Get-date).AddDays(-7) -End $CurrentDate -Top 5000
    
    $LastCount = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $OMSVars.ResourceGroupName `
                                                                      -WorkspaceName $OMSVars.WorkspaceId `
                                                                      -Query 'Type=SecurityEvent (EventID=4625) | measure count() by Computer,Account,EventID' `
                                                                      -Start (Get-date).AddMinutes(-15) -End $CurrentDate -Top 5000
    $HT = @{}
    Foreach($Result in ($StdDevSearchResult.Value | ConvertFrom-JSON))
    {
        $HT.Add("$($Result.Account_s):$($Result.Computer):$($Result.EventID_d -as [int])", ($Result.'avg(Value_d)' + $Result.'stddev(Value_d)'))
    }
    
    Foreach($Result in ($LastCount.Value | ConvertFrom-JSON))
    {
        $Key = "$($Result.Account):$($Result.Computer):$($Result.EventID)"
        if($HT.ContainsKey($Key))
        {
            $Upperbound = $HT.$Key
            if($Result.AggregatedValue -gt $Upperbound)
            {
                #Block Result
                $VMName = $Result.Computer
                $VMObj = Find-AzureRmResource -ResourceNameContains $VMName -ResourceType 'Microsoft.Compute/virtualMachines'
                if($VMObj)
                {
                    $VirtualMachine = Get-AzureRmVM -ResourceGroupName $VMObj.ResourceGroupName -Name $VMObj.Name

                    Foreach($NetworkInterfaceId in $VirtualMachine.NetworkInterfaceIDs)
                    {
                        $NetworkInterface = Get-AzureRmResource -ResourceId $NetworkInterfaceId
                        Foreach($NetworkSecurityGroupId in $NetworkInterface.Properties.networkSecurityGroup)
                        {
                            $NetworkSecurityGroup = Get-AzureRMResource -ResourceId $NetworkSecurityGroupId.id
                            #Add-AzureRmNetworkSecurityRuleConfig -Name "BlockIPAddress" -NetworkSecurityGroup $NetworkSecurityGroup -Protocol *
                        }
                    }#>
                }
            }
        }

    }
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
