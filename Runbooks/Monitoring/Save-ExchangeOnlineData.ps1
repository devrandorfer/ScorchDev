<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-SharePointOnlineData

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'WorkspaceId'

$Exchange = Get-BatchAutomationVariable -Prefix 'Exchange' `
                                        -Name 'CredentialName',
                                              'WebserviceURL',
                                              'SendingCredentialName'

$MailboxPair = @(
    @{ 'ryan@microsoft.com' = 'ryan.andorfer@scorchdev.com' }
    #@{ 'ryan.andorfer@scorchdev.com' = 'ryan@microsoft.com' }
)

$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

$DelayCycle = 30
$MonitorRefreshTime = ( Get-Date ).AddMinutes(60)
$MonitorActive      = ( Get-Date ) -lt $MonitorRefreshTime
Write-Debug -Message "`$MonitorRefreshTime [$MonitorRefreshTime]"

Try
{
    Do
    {
        $DataToSave = @()

        Foreach($_MailboxPair in $MailboxPair)
        {
            $ExchangeCredentialName = ($_MailboxPair.Keys -as [array])[0]
            $SendingExchangeCredentialName = $_MailboxPair.$ExchangeCredentialName

            $ExchangeCredential = Get-AutomationPSCredential -Name $ExchangeCredentialName
            $SendingExchangeCredential = Get-AutomationPSCredential -Name $SendingExchangeCredentialName

            $SendingMailboxConnection = New-EWSMailboxConnection -Credential $SendingExchangeCredential `
                                                                 -webserviceURL $Exchange.WebserviceURL
            
            $MailboxConnection = New-EWSMailboxConnection -Credential $ExchangeCredential `
                                                          -webserviceURL $Exchange.WebserviceURL

            $TestTime = Measure-Command {
                Try
                {
                    $StartTime = Get-Date
                    $TimeoutTime = $StartTime.AddSeconds($DelayCycle)
                    $ReadMail = $false
                    $UniqueEmailSubject = ([guid]::NewGuid())
                    $SentMail = $SendingMailboxConnection | Send-EWSEmail -Recipients $ExchangeCredentialName -Subject $UniqueEmailSubject -Body 'test'
                    While(-not $ReadMail)
                    {
                        $ReadMail = $MailboxConnection | Read-EWSEmail -SearchField Subject -SearchString $UniqueEmailSubject -SearchAlgorithm Equals
                        if(($TimeoutTime - (Get-Date)).TotalSeconds -le 0) { $Success = $False ; break }
                    }
                    $ReadMail.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]::HardDelete)
                    $Success = $True
                }
                Catch
                {
                    $Success = $false
                }
            }
            if($Success)
            {
                $DataToSave += @{
                    'Subject' = $ReadMail.Subject
                    'Sender' = $ReadMail.Sender.Address
                    'ReceivedBy' = $ReadMail.ReceivedBy.Address
                    'DateTimeReceived' = $ReadMail.DateTimeReceived
                    'DateTimeSent' = $ReadMail.DateTimeSent
                    'isFromMe' = $ReadMail.isFromMe
                    'ElapsedSeconds' = ($ReadMail.DateTimeReceived - $ReadMail.DateTimeSent).TotalSeconds
                    'Success' = $True
                    'TestTimeTotalSeconds' = $TestTime.TotalSeconds
                }
            }
            else
            {
                $DataToSave += @{
                    'Subject' = [string]::Empty
                    'Sender' = [string]::Empty
                    'ReceivedBy' = [string]::Empty
                    'DateTimeReceived' = Get-Date
                    'DateTimeSent' = $StartTime
                    'isFromMe' = $ReadMail.isFromMe
                    'ElapsedSeconds' = $DelayCycle
                    'Success' = $false
                    'TestTimeTotalSeconds' = $TestTime.TotalSeconds
                }
            }
        }

        Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $DataToSave -LogType 'ExchangeOnlineTest_CL'
        
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
