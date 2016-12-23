<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-CitiBikeTripData

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'AutomationAccountName',
                                                'SubscriptionAccessTenant',
                                                'WorkspaceId'

$CitiBikeUri = 'https://s3.amazonaws.com/tripdata'


$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

$BatchSize = 1000

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
   

    $DataFeed = Invoke-RestMethod -Method Get -Uri $CitiBikeUri

    Foreach($_DataFeed in $DataFeed.ListBucketResult.Contents)
    {
        $TempDir = New-TempDirectory
        Try
        {
            if($_DataFeed.Key -like '*.zip')
            {
                (New-Object -TypeName System.Net.WebClient).DownloadFile("$($CitiBikeUri)/$($_DataFeed.Key)","$TempDir\$($_DataFeed.Key)")
                (New-Object -ComObject shell.application).namespace($TempDir.FullName).CopyHere((New-Object -ComObject shell.application).namespace("$TempDir\$($_DataFeed.Key)").Items(),16)
                Foreach($CSVFile in (Get-ChildItem -Path $TempDir -Filter *.csv))
                {
                    $FeedData = Import-Csv -Delimiter ',' -Path $CSVFile.FullName
                    For($i = 0 ; $i -lt $FeedData.Count ; $i+=$BatchSize)
                    {
                        Try
                        {
                            $comp = Write-StartingMessage -CommandName 'batch' -String $i -Stream Verbose
                            $Data = @()
                            if($i+$BatchSize -gt $FeedData.Count) { $size = $FeedData.Count - 1 }
                            else { $Size = $i+$BatchSize }
                            $FeedData[$i..$Size] | Foreach-Object {
                                $Data += @{
                                    'bikeid' = $_.bikeid
                                    'birth year' = $_.'birth year'
                                    'end station id' = $_.'end station id'
                                    'end station latitude' = $_.'end station latitude'
                                    'end station longitude' = $_.'end station longitude'
                                    'end station name' = $_.'end station name'
                                    'gender' = $_.gender
                                    'start station id' = $_.'start station id'
                                    'start station latitude' = $_.'start station latitude'
                                    'start station longitude' = $_.'start station longitude'
                                    'start station name' = $_.'start station name'
                                    'starttime' = ($_.starttime | Get-Date -Year ([datetime]::Now).Year -Month ([datetime]::Now).Month) -as [datetime]
                                    'stoptime' = ($_.stoptime | Get-Date -Year ([datetime]::Now).Year -Month ([datetime]::Now).Month) -as [datetime]
                                    'tripduration' = $_.tripduration
                                    'usertype' = $_.usertype
                                }
                            }
                            Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId `
                                                        -Key $Key `
                                                        -Data $Data `
                                                        -LogType "CitiBike_TripData_CL" `
                                                        -TimeStampField 'starttime'
                            Write-CompletedMessage @comp
                        }
                        Catch
                        {
                            Write-Exception -Exception $_
                        }
                    }
                        
                }
            }
            Remove-Item -Path $TempDir -Recurse -Force
        }
        Catch
        {
            Remove-Item -Path $TempDir -Recurse -Force
            Write-Exception -Exception $_ -Stream Warning
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
