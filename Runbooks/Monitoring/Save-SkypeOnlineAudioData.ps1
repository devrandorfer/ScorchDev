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

$DelayCycle = 300
$MonitorRefreshTime = ( Get-Date ).AddMinutes(60)
$MonitorActive      = ( Get-Date ) -lt $MonitorRefreshTime
Write-Debug -Message "`$MonitorRefreshTime [$MonitorRefreshTime]"

Try
{
    $DataToSave = @()

    Import-Module 'C:\Program Files\Common Files\Skype for Business Online\Modules\SkypeOnlineConnector'
    New-CsOnlineSession -Credential $Credential | % { Import-PSSession -Session $_ -AllowClobber } | Out-Null
    
    Do
    {
        $Sessions = Get-CsOnlineUser | % { Get-CsUserSession -User $_.UserPrincipalName -StartTime (Get-Date).AddSeconds(-1*$DelayCycle) | ? { $_.MediaTypesDescription -eq '[Audio]' } }
    
        $DataToSave = @()
        Foreach($Session in $Sessions)
        {
            $AudioStreams = $Session.QoEReport.AudioStreams

            Foreach($AudioStream in $AudioStreams)
            {
                $AudioStreamHT = $audiostream | ConvertTo-Json | ConvertFrom-Json | ConvertFrom-PSCustomObject
                $AudioStreamHT.Add('StartTime', $Session.StartTime) | Out-Null
                $AudioStreamHT.Add('EndTime', $Session.StartTime) | Out-Null
                $AudioStreamHT.Add('FromUri', $Session.FromUri) | Out-Null
                $AudioStreamHT.Add('ToUri', $Session.ToUri) | Out-Null
                $DataToSave += $AudioStreamHT
            }
        }
    
        if($DataToSave -as [bool])
        {    
            Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $DataToSave -LogType 'SkypeOnlineAudioStream_CL' -TimeStampField 'StartTime'
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
