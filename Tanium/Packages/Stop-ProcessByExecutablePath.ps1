<#
.Synopsis
    Stops processes that are spawned from a executable path
#>

Param(
    $ExecutablePath
)
$Null = $(
    Get-WmiObject -Class Win32_Process `
                  | ? { $_.ExecutablePath -eq $ExecutablePath } `
                  | % { Stop-Process -Id $_.ProcessId -Force }
    
)