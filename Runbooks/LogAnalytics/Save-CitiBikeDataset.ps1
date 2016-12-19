<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-CitiBikeDataset

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'AutomationAccountName',
                                                'SubscriptionAccessTenant',
                                                'WorkspaceId'

$CitiBikeUri = 'https://gbfs.citibikenyc.com/gbfs/gbfs.json'


$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

$DelayCycle = 30
$MonitorRefreshTime = (Get-Date).AddHours(1)

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
   

    $DataFeed = Invoke-RestMethod -Method Get -Uri $CitiBikeUri

    Do
    {
        Foreach($_DataFeed in $DataFeed.data.en.feeds)
        {
            Try
            {
                if($_DataFeed.Name -ne 'system_information')
                {
                    $FeedData = Invoke-RestMethod -Method Get -Uri $_DataFeed.url
                    $TypeName = ($FeedData.data | get-member -MemberType NoteProperty)[0].Name
                    $FeedItem = $FeedData.data.$TypeName

                    $Data = @()
                    Foreach($_Item in $FeedItem)
                    {
                        $DataItem = @{}
                        $FeedItemPropertyName = ($_Item | get-member -MemberType NoteProperty).Name
                        Foreach($_FeedItemPropertyName in $FeedItemPropertyName)
                        {
                            if($_FeedItemPropertyName -ne 'last_reported')
                            {
                                $DataItem.Add($_FeedItemPropertyName, $_Item.$_FeedItemPropertyName)
                            }
                            else
                            {
                                $DataItem.Add('EventTimestamp', (ConvertFrom-UnixDate -Date $_Item.$_FeedItemPropertyName)) | Out-Null
                            }
                        }
                        $Data += $DataItem
                    }

                    Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $Data -LogType "CitiBike_$($_DataFeed.Name)_CL" -TimeStampField 'EventTimestamp'
                }
            }
            Catch
            {
                Write-Exception -Exception $_ -Stream Warning
            }
        }

        # Sleep for the rest of the $DelayCycle, with a checkpoint every $DelayCheckpoint seconds
        [int]$RemainingDelay = $DelayCycle - (Get-Date).TimeOfDay.TotalSeconds % $DelayCycle
        If ( $RemainingDelay -eq 0 ) { $RemainingDelay = $DelayCycle }
        Write-Debug -Message "Sleeping for [$RemainingDelay] seconds."
        Start-Sleep -Seconds $RemainingDelay

        # Calculate if we should continue running or if we should start a new instance of this monitor
        $MonitorActive = ( Get-Date ) -lt $MonitorRefreshTime
    }
    While($MonitorActive)

    Start-AzureRmAutomationRunbook -Name Save-CitiBikeDataset `
                                   -RunOn 'Hybrid' `
                                   -ResourceGroupName $GlobalVars.ResourceGroupName `
                                   -AutomationAccountName $GlobalVars.AutomationAccountName
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
