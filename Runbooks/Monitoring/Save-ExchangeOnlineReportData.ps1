<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript.

    .Description
        Give a description of the Script!

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-ExchangeOnlineReportData

$LogAnalyticsVars = Get-BatchAutomationVariable -Prefix 'LogAnalytics' `
                                                -Name 'WorkspaceId'

$Office365Vars = Get-BatchAutomationVariable -Prefix 'Office365' `
                                             -Name 'CredentialName'

$ExchangeOnlineVars = Get-BatchAutomationVariable -Prefix 'ExchangeOnline' `
                                                  -Name 'StorageAccountName',
                                                        'StorageAccountResourceGroupName',
                                                        'QueueName'

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant'

$Office365Credential = Get-AutomationPSCredential -Name $Office365Vars.CredentialName
$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$WorkspaceCredential = Get-AutomationPSCredential -Name $LogAnalyticsVars.WorkspaceID

$DelayCycle = 30
$MonitorRefreshTime = ( Get-Date ).AddMinutes(60)
$MonitorActive      = ( Get-Date ) -lt $MonitorRefreshTime
Write-Debug -Message "`$MonitorRefreshTime [$MonitorRefreshTime]"

Try
{
    $Session = New-PSSession -ConfigurationName Microsoft.Exchange `
                                 -ConnectionUri https://outlook.office365.com/powershell-liveid/ `
                                 -Credential $Office365Credential -Authentication Basic -AllowRedirection
    Import-PSSession $Session

    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

    $StorageAccount = Get-AzureRmStorageAccount -StorageAccountName $SkypeForBusinessVars.StorageAccountName `
                                                -ResourceGroupName $SkypeForBusinessVars.StorageAccountResourceGroupName

    $Queue = Get-AzureStorageQueue -Name $SkypeForBusinessVars.QueueName `
                                   -Context $StorageAccount.Context

    Do
    {
        $Message = $Queue.CloudQueue.GetMessage()
        if($Message)
        {
            $DataToSave = @{}

            $DataType,$StartTime = $Message.AsString.Split(';')
        
            $StartTime = ($StartTime -as [datetime]).ToLocalTime()
            if($StartTime.CompareTo((Get-Date).AddDays(-30)) -ge 0)
            {
                $StartTime = (Get-Date).AddDays(-30)
            }
            
            $DataToSave = @{}
            $CompletedParams = Write-StartingMessage -Command 'Processing Datatype' -String "$DataType from $($StartTime.ToString("MM/dd/yyyy h:mm:ss zzz"))" -Stream Debug

            $EndTime = Get-Date
            $Result = & "Get-$DataType" -StartDate $StartTime -EndDate $EndTime
            $DataToSave.Add($DataType, ($Result -as [array])) | Out-Null
        
            if($DataToSave -as [bool])
            {
                Foreach($DataToSaveKey in $DataToSave.Keys)
                {
                    if($DataToSaveKey -eq 'MessageTrace')
                    {
                        Write-LogAnalyticsLogEntry -WorkspaceId $LogAnalyticsVars.WorkspaceId `
                                                    -Key $Key `
                                                    -Data $DataToSave.$DataToSaveKey `
                                                    -LogType "ExchangeOnline_$($DataToSaveKey)_CL" `
                                                    -TimeStampField 'Received'
                    }
                    #More Code

                }
            }

            $Queue.CloudQueue.DeleteMessage($Message)
            
            $QueueMessage = New-Object -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage `
                                        -ArgumentList "$($User);$($EndTime.ToUniversalTime().ToString())"
            $Queue.CloudQueue.AddMessage($QueueMessage)
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

    #Invoke-WebRequest -Method Post -Uri $Exchange.WebHookUri
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
