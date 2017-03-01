<#
.Synopsis
    Stops processes that are spawned from a executable path
#>

Param(
    $ExecutablePath
)
[Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null
$Path = [System.Web.HttpUtility]::UrlDecode($ExecutablePath)

$Null = $(
    Get-WmiObject -Class Win32_Process `
                  | ? { $_.ExecutablePath -eq $Path } `
                  | % { Stop-Process -Id $_.ProcessId -Force }
    
)