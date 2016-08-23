<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-ServerPatching

$GlobalVars = Get-BatchAutomationVariable -Prefix 'Global' `
                                          -Name 'DomainCredentialName'

$LogAnalyticsVars = Get-BatchAutomationVariable -Prefix 'LogAnalytics' `
                                                -Name 'ResourceGroupName',
                                                      'WorkspaceId'

$zzGlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                            -Name 'SubscriptionName',
                                                  'SubscriptionAccessCredentialName'

$Credential = Get-AutomationPSCredential -Name $GlobalVars.DomainCredentialName
$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $zzGlobalVars.SubscriptionAccessCredentialName

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $zzGlobalVars.SubscriptionName

    $QueryResults = Get-AzureRmOperationalInsightsSearchResults -ResourceGroupName $LogAnalyticsVars.ResourceGroupName `
                                                                -WorkspaceName $LogAnalyticsVars.WorkspaceId `
                                                                -Query 'Type=Update UpdateState=Needed Optional=false Classification="Security Updates" Approved!=false | measure count() by Computer'
    
    Foreach($Result in $QueryResults)
    {
        $ResultValue = $Result.Value | ConvertFrom-JSON
        foreach($ComputerName in $ResultValue.Computer)
        {
            $CompletedMessage = Write-StartingMessage -CommandName 'PatchComputer' -String $ComputerName -Stream Verbose
            Try
            {
                Find-WindowsUpdate -ComputerName $ComputerName `
                        -Credential $Credential | `
                    Install-WindowsUpdate -ComputerName $ComputerName `
                                        -Credential $Credential -Force    
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
            Write-CompletedMessage @CompletedMessage
        }
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
