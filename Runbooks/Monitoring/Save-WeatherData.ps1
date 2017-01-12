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
        try
        {
            $Weather = Get-WeatherCurrentRaw -City $_City -ApiKey $weathervars.APIKey -Units imperial
            $WeatherData = @{
                'Longitude' = $Weather.coord.lon
                'Latitude' = $Weather.coord.lat
                'Description' = $Weather.weather.main
                'Description_Detail' = $Weather.weather.description
                'Temperature' = $Weather.main.temp
                'Pressure' = $Weather.main.pressure
                'Humidity' = $Weather.main.humidity
                'Wind_Speed' = $Weather.wind.speed
                'Wind_Degree' = $Weather.wind.deg
                'Location' = $Weather.name
            }
            $DataToSave += $WeatherData
        }
        catch
        {
            Write-Exception -Exception $_ -Stream Warning
        }
    }

    Write-LogAnalyticsLogEntry -WorkspaceId $GlobalVars.WorkspaceId -Key $Key -Data $DataToSave -LogType 'OpenWeather_CL'
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
