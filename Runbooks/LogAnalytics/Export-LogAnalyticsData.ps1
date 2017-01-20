<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(
    $Type
)

Import-Module SCOrchDev-Utility -Verbose:$False
Import-Module SCOrchDev-Exception -Verbose:$False
Import-Module SCOrchDev-File -Verbose:$False
Import-Module SCOrchDev-GitIntegration -Verbose:$False
Import-Module AzureRM.Profile -Verbose:$False

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Export-LogAnalyticsData.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'SubscriptionName',
                                                'SubscriptionAccessCredentialName',
                                                'SubscriptionAccessTenant'

$LogAnalyticsVars = Get-BatchAutomationVariable -Prefix 'LogAnalytics' `
                                                -Name 'WorkspaceId',
                                                      'ResourceGroupName'

$SubscriptionAccessCredential = Get-AutomationPSCredential -Name $GlobalVars.SubscriptionAccessCredentialName

Function QueryOMS
{
    Param(
        $Query,
        $Start,
        $End
    )
    $QueryParameters = @{
        'ResourceGroupName' = $LogAnalyticsVars.ResourceGroupName
        'WorkspaceName' = $LogAnalyticsVars.WorkspaceId
        'Query' = $Query
        'Top' = 5000
    }
    $Continue = $true
    if($Start) { $QueryParameters.Add('Start',$Start) | Out-Null }
    if($End) { $QueryParameters.Add('End',$End) | Out-Null }
    While($Continue)
    {
        Do
        {
            $Response = Get-AzureRmOperationalInsightsSearchResults @QueryParameters
            if($Response.Metadata.Status -eq 'Pending')
            { 
                if(-not $QueryParameters.ContainsKey('Id')) { $QueryParameters.Add('Id',$Response.Id.Split('/')[-1]) | Out-Null  }
                Start-Sleep -Seconds 5
            }
        } while($Response.Metadata.Status -eq 'Pending')
        $Result = $Response.Value
        $ResultCount = $Result.Count

        $Result

        if($ResultCount -eq 5000) { $QueryParameters.Start = (($Result[0] | ConvertFrom-Json).TimeGenerated -as [datetime]) }
        else { $Continue = $False }
    }
}

Try
{
    Add-AzureRmAccount -Credential $SubscriptionAccessCredential `
                       -SubscriptionName $GlobalVars.SubscriptionName `
                       -TenantId $GlobalVars.SubscriptionAccessTenant `
                       -ServicePrincipal | Out-Null

    # Start query for a 5 minute block of data
    $Start = (Get-Date).AddMinutes(-15)
    $End = (Get-Date)

    $Results = QueryOMS -Query "Type=$Type" -Start $Start -End $End
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
