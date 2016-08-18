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

$SharePointVars = Get-BatchAutomationVariable -Prefix 'SharePoint' `
                                              -Name 'SPFarm',
                                                    'SPSite',
                                                    'CredentialName',
                                                    'WebhookURI'

$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

$SharePointCredential = Get-AutomationPSCredential -Name $SharePointVars.CredentialName

$DelayCycle = 30
$MonitorRefreshTime = ( Get-Date ).AddMinutes(60)
$MonitorActive      = ( Get-Date ) -lt $MonitorRefreshTime
Write-Debug -Message "`$MonitorRefreshTime [$MonitorRefreshTime]"

Try
{
    $DataToSave = @()

    Do
    {
        $TestTime = Measure-Command {
            Try
            {
                $ListItem = Get-SPOListItem -SPFarm $SharePointVars.SPFarm `
                                            -SPSite $SharePointVars.SPSite `
                                            -SPList 'TestList' `
                                            -Credential $SharePointCredential `
                                            -TimeOut $DelayCycle
            }
            Catch
            {
                $ListItem = $false
            }
        }

        $DataToSave = @{
            'SPFarm' = $SharePointVars.SPFarm
            'SPSite' = $SharePointVars.SPSite
            'SPList' = 'TestList'
            'RequestTotalSeconds' = $TestTime.TotalSeconds
            'ClientMachine' = $env:ComputerName
            'Success' = $ListItem -as [bool]
        }

        Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $DataToSave -LogType 'SharePointOnlineTest_CL'
        
         # Sleep for the rest of the $DelayCycle, with a checkpoint every $DelayCheckpoint seconds
        [int]$RemainingDelay = $DelayCycle - (Get-Date).TimeOfDay.TotalSeconds % $DelayCycle
        If ( $RemainingDelay -eq 0 ) { $RemainingDelay = $DelayCycle }
        Write-Debug -Message "Sleeping for [$RemainingDelay] seconds."
        Start-Sleep -Seconds $RemainingDelay

        # Calculate if we should continue running or if we should start a new instance of this monitor
        $MonitorActive = ( Get-Date ) -lt $MonitorRefreshTime
    }
    While($MonitorActive)

   # Invoke-WebRequest -Method Post -Uri $SharePointVars.WebHookUri
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
