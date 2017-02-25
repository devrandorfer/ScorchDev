<#
.Synopsis
    Returns the hash of the target file
#>

# Should be escaped
$Path = '||Path||'
$Algorithm = '||Algorithm||'

#Tanium doesn't use param blocks
<#
param(
    $Path,
    [ValidateSet(
        'SHA1',
        'SHA256',
        'MD5'
    )][string] $Algorithm = 'SHA1'
)
#>
$Null = $(
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
)
$SB.ToString()