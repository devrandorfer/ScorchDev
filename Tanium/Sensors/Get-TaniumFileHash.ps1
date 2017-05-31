<#
.Synopsis
    Returns the hash of the target file
#>

# Should be escaped
[Reflection.Assembly]::LoadWithPartialName("System.Web") | out-null
$Path = [System.Web.HttpUtility]::UrlDecode('||Path||')
$Algorithm = [System.Web.HttpUtility]::UrlDecode('||Algorithm||')

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
    
    $file = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
    $SB = New-Object System.Text.StringBuilder
        $operator.ComputeHash($file) | ForEach-Object {
        $SB.Append($_.ToString("x2")) | Out-Null
    }
    $file.Dispose()
)
$SB.ToString()