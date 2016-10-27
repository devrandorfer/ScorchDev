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

$Key = $WorkspaceCredential.GetNetworkCredential().Password

$MonitorRefreshTime = ( Get-Date ).AddMinutes(60)
$MonitorActive      = ( Get-Date ) -lt $MonitorRefreshTime
Write-Debug -Message "`$MonitorRefreshTime [$MonitorRefreshTime]"

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant

    Import-Module 'C:\Program Files\Common Files\Skype for Business Online\Modules\SkypeOnlineConnector'
    New-CsOnlineSession -Credential $Office365Credential | % { Import-PSSession -Session $_ -AllowClobber } | Out-Null
    
    $StorageAccount = Get-AzureRmStorageAccount -StorageAccountName $SkypeForBusinessVars.StorageAccountName `
                                                -ResourceGroupName $SkypeForBusinessVars.StorageAccountResourceGroupName

    $Queue = Get-AzureStorageQueue -Name $SkypeForBusinessVars.QueueName `
                                   -Context $StorageAccount.Context
    Do
    {
        $Message = $Queue.CloudQueue.GetMessage()
        if($Message)
        {
            $User,$StartTime = $Message.AsString.Split(';')
        
            $StartTime = ($StartTime -as [datetime]).ToLocalTime()
            $EndTime = (Get-Date)

            $DataToSave = @{}
            $CompletedParams = Write-StartingMessage -Command 'Processing User' -String $User -Stream Debug
            Try
            {
                $Sessions = Get-CsUserSession -User $User `
                                              -StartTime $StartTime `
                                              -EndTime $EndTime `
                                              -WarningAction SilentlyContinue
            
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
                    if($SessionPropertyNames -contains 'ErrorReports')
                    {
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
                    }

                    #QoEReport
                    if($SessionPropertyNames -contains 'QoEReport')
                    {
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
                if($DataToSave -as [bool])
                {
                    Foreach($DataToSaveKey in $DataToSave.Keys)
                    {
                        Write-LogAnalyticsLogEntry -WorkspaceId $Vars.WorkspaceId -Key $Key -Data $DataToSave.$DataToSaveKey -LogType "SkypeOnline_$($DataToSaveKey)_CL" -TimeStampField 'StartTime'
                    }
                }
                $Queue.CloudQueue.DeleteMessage($Message)
            
                $QueueMessage = New-Object -TypeName Microsoft.WindowsAzure.Storage.Queue.CloudQueueMessage `
                                           -ArgumentList "$($User);$($EndTime.ToUniversalTime().ToString())"
                $Queue.CloudQueue.AddMessage($QueueMessage)
            }
            Catch { $_ | Format-List * }

            Write-CompletedMessage @CompletedParams
        }
        
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

