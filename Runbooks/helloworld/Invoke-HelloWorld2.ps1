﻿<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld2

$LocalVars = Get-BatchAutomationVariable -Prefix 'HelloWorld2' `
                                         -Name @(
                                            'Audience'
                                            'Message'
                                         )

Try
{
    Write-Verbose -Message "Hello $($LocalVars.Audience) $($LocalVars.Message)"
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