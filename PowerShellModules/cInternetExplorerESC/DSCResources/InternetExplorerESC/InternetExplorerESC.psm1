﻿Function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
    
        [Parameter()]
        [bool]$Enabled
    )

    $Enabled = Test-InternetExplorerESCEnabled

    return @{
        Name = $Name
        Enabled = $Enabled
    }
}

Function Set-TargetResource
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter()]
        [bool]$Enabled
    )

    if($Enabled) { Enable-InternetExplorerESC }
    else { Disable-InternetExplorerESC }
}

Function Test-TargetResource
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter()]
        [bool]$Enabled
    )

    $Status = (Test-InternetExplorerESCEnabled) -eq $Enabled
    Return $Status
}

$AdminKey = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}'
$UserKey = 'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}'

Function Test-InternetExplorerESCEnabled
{
    Param(
    )

    $ErrorActionPreference = 'stop'
    Try
    {
        (Get-ItemProperty -Path $AdminKey -Name 'IsInstalled').IsInstalled -as [bool]
    }
    Catch
    {
        return $false
    }
}

Function Disable-InternetExplorerESC
{
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Stop-Process -Name Explorer -Force
    Write-Verbose "IE Enhanced Security Configuration (ESC) has been disabled."
}

Function Enable-InternetExplorerESC
{
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1
    Stop-Process -Name Explorer
    Write-Verbose "IE Enhanced Security Configuration (ESC) has been enabled."
}

Export-ModuleMember -Function *-TargetResource
