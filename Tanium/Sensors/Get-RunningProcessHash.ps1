<#
.Synopsis
    
#>
Param(
    $ProcessName,
    [ValidateSet(
            'SHA1',
            'SHA256',
            'MD5'
    )][string] $Algorithm = 'SHA1'
)

Function Get-FileHash
{
    param(
        $Path,
        [ValidateSet(
            'SHA1',
            'SHA256',
            'MD5'
        )][string] $Algorithm = 'SHA1'
    )
 
    [Reflection.Assembly]::LoadWithPartialName("System.Security") | out-null
    Switch($Algorithm)
    {
        'SHA1'
        {
            $operator = New-Object System.Security.Cryptography.SHA1Managed
        }
        'SHA256'
        {
            $operator = New-Object System.Security.Cryptography.SHA256Managed
        }
        'MD5'
        {
            $operator = [System.Security.Cryptography.MD5]::Create()
        }
    }
    
    $file = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open , [System.IO.FileAccess]::Read)
    $SB = New-Object System.Text.StringBuilder
    $operator.ComputeHash($file) | %{
        $SB.Append($_.ToString("x2")) | Out-Null
    }
    $file.Dispose()

    $SB.ToString()
}

$Null = $(
    if($ProcessName) { $Process = Get-Process -Name $ProcessName }
    else { $Process = Get-Process }

    $SB = New-Object System.Text.StringBuilder
    $ErrorProcesses = New-Object System.Collections.ArrayList
    Foreach($_Process in $Process)
    {
        Try
        {
            if($_Process.Path)
            {
                $SB.AppendLine(("$($_Process.Name)|$($_Process.Path)|$($_Process.Id)|$(Get-FileHash -Path $_Process.Path -Algorithm $Algorithm)")) | Out-Null
            }
        }
        Catch
        {
            $ErrorProcesses.Add($_Process) | Out-Null
        }
    }
)

$SB.ToString()