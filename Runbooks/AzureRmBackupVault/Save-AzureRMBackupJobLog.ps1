<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-AzureRMLog

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'ResourceGroupName',
                                                'SubscriptionAccessTenant'

$Vars = Get-BatchAutomationVariable -Prefix 'AzureRMBackupLog' `
                                    -Name @(
                                        'LastSaveDateTime'
                                        'LogPath'
                                    )

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName


Try
{
    Connect-AzureRmAccount -Credential $SubscriptionAccessCredential `
                           -SubscriptionName $GlobalVars.SubscriptionName `
                           -Tenant $GlobalVars.SubscriptionAccessTenant
    
    $Vault = Get-AzureRmBackupVault

    $LastSaveTime = ($Vars.LastSaveDateTime | ConvertFrom-Json).DateTime -as [datetime]
    $CurrentSaveTime = Get-Date
    $JobDetails = @()
    Foreach($_Vault in $Vault)
    {
        $Job = Get-AzureRmBackupJob -Vault $_Vault -Operation Backup -From $LastSaveTime
        Foreach($_Job in $Job)
        {
            $JobDetails += Get-AzureRmBackupJobDetails -Vault $_Vault -JobId $_Job.InstanceId
        }
    }

    $NewVault = Get-AzureRmRecoveryServicesVault
    Foreach($_NewVault in $NewVault)
    {
        $VContext = Set-AzureRmRecoveryServicesVaultContext -Vault $_NewVault
        $Job = Get-AzureRmRecoveryServicesBackupJob -Operation Backup
        Foreach($_Job in $Job)
        {
            $JobDetails += Get-AzureRmRecoveryServicesBackupJobDetails -JobId $_Job.JobId
        }
    }

    if(-not (Test-Path -Path $Vars.LogPath)) { $Null = New-Item -ItemType Directory -Path $Vars.LogPath }
    Get-ChildItem -Path $Vars.LogPath | ForEach-Object { if($_.CreationTime -lt (Get-Date).AddDays(-1)) { Remove-Item -Path $_.FullName } }
    
    $LogName = "$($Vars.LogPath)\AzureRMBackupLog.$(Get-Date -f 'yyyy-MM-dd-hh-mm-ss').txt"
    foreach($_JobDetails in $JobDetails)
    {
        Add-Content -Value "$((Get-Date $_JobDetails.StartTime -Format 'yyyy-MM-dd HH:mm:ss')) : $($_JobDetails | ConvertTo-JSON -Compress -Depth 10)" -Path $LogName
    }

    Set-AutomationVariable -Name 'AzureRMBackupLog-LastSaveDateTime' -Value (($CurrentSaveTime | ConvertTo-JSON -Compress) -as [string])
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
