<#
    .SYNOPSIS
       Script to collect Skype for Business log data and ingest it into Log Analytics

    .Description
       Script to collect Skype for Business log data and ingest it into Log Analytics

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-SkypeOnlineData

$LogAnalyticsVars = Get-BatchAutomationVariable -Prefix 'LogAnalytics' `
                                                -Name 'WorkspaceId'

$Office365Vars = Get-BatchAutomationVariable -Prefix 'Office365' `
                                             -Name 'CredentialName'

$SkypeForBusinessVars = Get-BatchAutomationVariable -Prefix 'SkypeForBusiness' `
                                                    -Name 'StorageAccountName'

$Queue = $SkypeForBusinessVars.Queue | ConvertFrom-Json | ConvertFrom-PSCustomObject
$JobId = (New-Guid) -as [string]
$StartTime = Get-Date

$Queue.Add($JobId,$StartTime) | Out-Null

Set-AutomationVariable -Name 'SkypeForBusiness-Queue' -Value ($Queue | ConvertTo-Json)

$WorkspaceCredential = Get-AutomationPSCredential -Name $LogAnalyticsVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

$Office365Credential = Get-AutomationPSCredential -Name $Office365Vars.CredentialName

$MonitorRefreshTime = ( Get-Date ).AddMinutes(60)
$MonitorActive      = ( Get-Date ) -lt $MonitorRefreshTime
Write-Debug -Message "`$MonitorRefreshTime [$MonitorRefreshTime]"

Try
{
    Import-Module 'C:\Program Files\Common Files\Skype for Business Online\Modules\SkypeOnlineConnector'
    New-CsOnlineSession -Credential $Office365Credential | % { Import-PSSession -Session $_ -AllowClobber } | Out-Null
    
    $StartTime = Invoke-SqlQuery -Query $SQLGetStartDate -ConnectionString $RBAConnection
    $Users = Get-CsOnlineUser -Filter {Enabled -eq $True} -WarningAction SilentlyContinue | Select-Object -Property UserPrincipalName
    
    Do
    {
        Set-RBAMonitorTimestamp -Environment $Vars.RBAEnvironment -ID $Vars.RBAMonitorID
        $PreBatchTime = Get-Date
        For($i = 0 ; $i -lt $Users.Count; $i += $BatchSize)
        {
            $EndPoint = $i + $BatchSize
            $BatchUsers = $Users[$i..$EndPoint]
            $CompletedParams = Write-StartingMessage -CommandName 'Processing' -String "$i..$EndPoint"
            
            $DataToSave = @{}
            Foreach($_User in $BatchUsers)
            {
                $CompletedUser = Write-StartingMessage -Command 'User' -String $_User.UserPrincipalName -Stream Debug
                Try
                {
                    $Sessions = Get-CsUserSession -User $_User.UserPrincipalName -StartTime $StartTime -EndTime $PreBatchTime -WarningAction SilentlyContinue | Where-Object { $_.QoEReport -ne $null }
                    Foreach($Session in $Sessions)
                    {
                        $SessionHeader = @{}
                        $SessionPropertyNames = ($Session | Get-Member -MemberType Property).Name
                        Foreach($SessionPropertyName in $SessionPropertyNames)
                        {
                            if(($SessionPropertyName -ne 'QoEReport') -and ($SessionPropertyName -ne 'ErrorReports'))
                            {
                                $SessionHeader.Add("$($SessionPropertyName)", $Session.$SessionPropertyName) | Out-Null
                            }
                        }

                        #ErrorReport
                        Foreach($ErrorReport in $Session.ErrorReports)
                        {
                            $ErrorReportObj = @{}
                            $ErrorReportObj += $SessionHeader
                            $ErrorReportPropertyNames = ($ErrorReport | Get-Member -MemberType Property).Name
                            Foreach($ErrorReportPropertyName in $ErrorReportPropertyNames)
                            {
                                if($ErrorReportPropertyName -eq 'DiagnosticHeader')
                                {
                                    Foreach($DiagKeyValue in $ErrorReport.$ErrorReportPropertyName.Split(';'))
                                    {
                                        if($DiagKeyValue.Contains('='))
                                        {
                                            $DiagObj = $DiagKeyValue.Split('=')
                                            $ErrorReportObj.Add("ErrorReport_$($DiagObj[0])",$DiagObj[1]) | Out-Null
                                        }
                                    }
                                }
                                else
                                {
                                    $ErrorReportObj.Add("ErrorReport_$ErrorReportPropertyName", $ErrorReport.$ErrorReportPropertyName)
                                }
                            }
                            if($DataToSave.ContainsKey('ErrorReport'))
                            {
                                $DataToSave.ErrorReport += $ErrorReportObj
                            }
                            else
                            {
                                $DataToSave.Add('ErrorReport', @($ErrorReportObj)) | Out-Null
                            }
                        }

                        #QoEReport
                        $QoEReport = $Session.QoEReport
                        $QoeReportType = ($QoeReport | Get-Member -MemberType Property).Name
                        Foreach($_QoeReportType in $QoeReportType)
                        {
                            $ObjToInsert = @{}
                            $ObjToInsert += $SessionHeader
                            $QoEReportProperties = $QoEReport.$_QoeReportType
                            if($QoEReportProperties -ne $Null)
                            {
                                $QoEReportPropertyNames = ($QoEReportProperties | Get-Member -MemberType Property).Name
                                Foreach($QoEReportPropertyName in $QoEReportPropertyNames)
                                {
                                    $ObjToInsert.Add("QoEReport_$($QoEReportPropertyName)", $QoEReportProperties.$QoEReportPropertyName) | Out-Null
                                }
                                if($DataToSave.ContainsKey("QoEReport_$_QoeReportType"))
                                {
                                    $DataToSave."QoEReport_$_QoeReportType" += $ObjToInsert
                                }
                                else
                                {
                                    $DataToSave.Add("QoEReport_$_QoeReportType", @($ObjToInsert)) | Out-Null
                                }
                            }
                        }
                    }
               }
                Catch { $_ | Format-List * }
                Write-CompletedMessage @CompletedUser
            }
            if($DataToSave -as [bool])
            {
                Foreach($DataToSaveKey in $DataToSave.Keys)
                {
                    Write-LogAnalyticsLogEntry -WorkspaceId $Vars.WorkspaceId -Key $Key -Data $DataToSave.$DataToSaveKey -LogType "SkypeOnline_$($DataToSaveKey)_CL" -TimeStampField 'StartTime'
                }
            }
            Write-CompletedMessage @CompletedParams
        }
        
        # Calculate if we should continue running or if we should start a new instance of this monitor
        $MonitorActive = ( Get-Date ) -lt $MonitorRefreshTime
        $StartTime = $PreBatchTime
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

