<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script!!!!!!

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-AzureRMLog

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'SubscriptionAccessTenant',
                                                'WorkspaceId'

$Vars = Get-BatchAutomationVariable -Prefix 'AzureRMLog' `
                                    -Name @(
                                        'LastSaveDateTime'
                                    )

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName
$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
    
    $LastSaveTime = ($Vars.LastSaveDateTime | ConvertFrom-Json).DateTime -as [datetime]
    $CurrentSaveTime = Get-Date
    if(($CurrentSaveTime - $LastSaveTime).Days -gt 15) { $LastSaveTime = $CurrentSaveTime.AddDays(-15) }
    $Log = Get-AzureRmLog -StartTime $LastSaveTime -EndTime $CurrentSaveTime -DetailedOutput `
        | ForEach-Object -Process { 
            Select-Object -InputObject $_ -Property * -ExcludeProperty Claims 
        }
    

    Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $Log -LogType 'AzureRMAudit_CL' -TimeStampField 'EventTimestamp'

    Set-AutomationVariable -Name 'AzureRMLog-LastSaveDateTime' -Value (($CurrentSaveTime | ConvertTo-JSON -Compress) -as [string])
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
