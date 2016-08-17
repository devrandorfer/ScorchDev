<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-NestThermostatData

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'WorkspaceId'

$NestVars = Get-BatchAutomationVariable -Prefix 'Nest' `
                                        -Name 'ClientID',
                                              'ClientSecret'

$NestPinCodeCred = Get-AutomationPSCredential -Name Nest-PinCode
$PinCode = $NestPinCodeCred.GetNetworkCredential().Password

Try
{
    $accessToken = Invoke-RestMethod -Method Post -Uri "https://api.home.nest.com/oauth2/access_token?client_id=$($NestVars.ClientID)&code=$($PinCode)&client_secret=$($NestVars.ClientSecret)&grant_type=authorization_code"
    $Devices = Invoke-RestMethod -Uri "https://developer-api.nest.com/devices?auth=$($accessToken.access_token)"
    
    $DataToSave = @()
    Foreach($Thermostat in $Devices.thermostats)
    {
        $Thermostat = $Thermostat | ConvertFrom-PSCustomObject
        $DataToSave += $ThermoStat.Values[0]
    }

    Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $DataToSave -LogType 'NestThermostat_CL'
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
