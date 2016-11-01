
<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-TargetExample.ps1

$GlobalVars = Get-BatchAutomationVariable -Prefix 'TargetExample' `
                                          -Name 'HelloMessage',
                                                'Audience'

Try
{
    
    Write-Verbose -Message "$($GlobalVars.HelloMessage)$($GlobalVars.Audience) 1"
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
