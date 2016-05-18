<#
    .SYNOPSIS
       Add a synopsis here to explain the PSScript. 

    .Description
        Give a description of the Script.

#>
Param(

)
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$CompletedParameters = Write-StartingMessage -CommandName Invoke-HelloWorld

$GlobalVars = Get-BatchAutomationVariable -Name  'DomainCredentialName' `
                                          -Prefix 'Global'

$Vars = Get-BatchAutomationVariable -Prefix 'HelloWOrld' `
                                    -Name @(
                                        'Audience'
                                        'Message'
                                    )

$Credential = Get-AutomationPSCredential -Name $GlobalVars.DomainCredentialName

Try
{
    Write-Verbose -Message "Hello $($Vars.Audience) $($Vars.Message)"
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
