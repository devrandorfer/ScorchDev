<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Save-WeatherData

$GlobalVars = Get-BatchAutomationVariable -Prefix 'zzGlobal' `
                                          -Name 'WorkspaceId'

$WeatherVars = Get-BatchAutomationVariable -Prefix 'Weather' `
                                           -Name 'APIKey',
                                                 'LocationsToMonitor'

$WorkspaceCredential = Get-AutomationPSCredential -Name $GlobalVars.WorkspaceID
$Key = $WorkspaceCredential.GetNetworkCredential().Password

Try
{
    $DataToSave = @()
    Foreach($_City in ($WeatherVars.LocationsToMonitor | ConvertFrom-JSON))
    {
        $Weather = Get-WeatherCurrentRaw -City $_City -ApiKey $weathervars.APIKey -Units imperial
        $WeatherData = @{
            'Longitude_s' = $Weather.coord.lon
            'Latitude_s' = $Weather.coord.lat
            'Description_s' = $Weather.weather.main
            'Description_Detail_s' = $Weather.weather.description
            'Temperature_d' = $Weather.main.temp
            'Pressure_d' = $Weather.main.pressure
            'Humidity_d' = $Weather.main.humidity
            'Wind_Speed_d' = $Weather.wind.speed
            'Wind_Degree_d' = $Weather.wind.deg
            'Location_s' = $Weather.name
        }
        $DataToSave += $WeatherData
    }

    Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $DataToSave -LogType 'Weather_CL'
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
