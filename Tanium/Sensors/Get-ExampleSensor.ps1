<#
.Synopsis
    Example Sensor format
#>

# escaped input parameters
$argument_1 = [System.Uri]::UnescapeDataString('||argument_1||')
$argument_2 = [System.Uri]::UnescapeDataString('||argument_2||')

Function Format-ObjectOutput
{
<#
.SYNOPSIS
    Converts an object into a text-based represenation that can easily be written to logs.

.DESCRIPTION
    Format-ObjectDump takes any object as input and converts it to a text string with the 
    values of the target properties delimited by the delimiter

.PARAMETER InputObject
    The object to convert to a textual representation.

.PARAMETER Property
    An optional list of property names that should be displayed in the output

.PARAMETER Delimiter
    The delimiter character to use
#>
    [CmdletBinding()]
    [OutputType([string])]
    Param(
        [Parameter(Position = 0, Mandatory = $True,ValueFromPipeline = $True)]
        [Object]$InputObject,
        [Parameter(Position = 1, Mandatory = $False)] [string[]] $Property = @('*'),
        [Parameter(Position = 2, Mandatory = $False)] [string] $Delimiter = '|'
    )
    $Null = $(
        $PropertyName = ($InputObject | Get-Member -MemberType Property,NoteProperty).Name
        $StringBuilder = New-Object -TypeName System.Text.StringBuilder

        $PropertyName | ForEach-Object {
            if($Property -eq '*' -or $Property -icontains $_)
            {
                $StringBuilder.Append("$($InputObject.$_)$($Delimiter)")
            }
        }
    )
    Return $StringBuilder.ToString(0, $StringBuilder.Length-1)
}

# Catch all unexptected output and redirect it to the null buffer
$Null = $(
    $SB = New-Object System.Text.StringBuilder

    # Make PowerShell Errors behave how they do in other languages
    $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
    try
    {
        Get-ChildItem | ForEach-Object { $SB.AppendLine((
            $_ | Format-ObjectOutput
        ))}
    }
    catch
    {
        $Exception = $_
        $SB.AppendLine($Exception.exception.message)
    }
)
$SB.ToString()
