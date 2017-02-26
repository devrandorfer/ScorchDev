<#
.Synopsis
    Get Hash of running processes
#>

# Should be escaped
[Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null
$Algorithm = [System.Web.HttpUtility]::UrlDecode('||Algorithm||')

Function Get-FileHash
{
    param(
        $Path,
        [ValidateSet(
            'SHA1',
            'SHA256',
            'SHA384',
            'SHA512',
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
        'SHA384'
        {
            $operator = New-Object System.Security.Cryptography.SHA384Managed
        }
        'SHA512'
        {
            $operator = New-Object System.Security.Cryptography.SHA512Managed
        }
        'MD5'
        {
            $operator = New-Object System.Security.Cryptography.MD5
        }
        default
        {
            $operator = New-Object System.Security.Cryptography.SHA1Managed
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
    $Process = Get-WmiObject -Class Win32_Process

    $SB = New-Object System.Text.StringBuilder
    $ErrorProcesses = New-Object System.Collections.ArrayList
    Foreach($_Process in $Process)
    {
        Try
        {
            if($_Process.ExecutablePath)
            {
                $SB.AppendLine(("$($env:COMPUTERNAME)|$($_Process.Caption)|$($_Process.ExecutablePath)|$($_Process.ProcessId)|$(Get-FileHash -Path $_Process.ExecutablePath -Algorithm $Algorithm)")) | Out-Null
            }
        }
        Catch
        {
            $ErrorProcesses.Add($_Process) | Out-Null
        }
    }
)

$SB.ToString()