﻿#
# Module manifest for module 'ScorchDev-Exception'
#
# Generated by: Ryan Andorfer
#
# Generated on: 2014-12-20
#

@{

# Script module or binary module file associated with this manifest.
RootModule = '.\SCOrchDev-Demo.psm1'

# Version number of this module.
ModuleVersion = '2.2.1'

# ID used to uniquely identify this module
GUID = 'c987f3c3-647c-4aa2-8ef2-01090b00fc7f'

# Author of this module
Author = 'Ryan Andorfer'

# Company or vendor of this module
CompanyName = 'SCOrchDev'

# Copyright statement for this module
Copyright = '(c) SCOrchDev. All rights reserved.'

# Description of the functionality provided by this module
Description = @'
Used for wrapping and handling custom exceptions.

This is designed to make good error handling routines for enterprise automation like what is written for SMA.
Using this library you can make routines (like below) that behave consistantly in PowerShell and PowerShell worfklow.
The module also has functions for throwing meaningful errors to any PowerShell stream or converting an exception to a
string for usage in other functions.

Example:

Function Test-Throw-Function
{
    try
    {
        Throw-Exception -Type 'CustomTypeA' `
                        -Message 'MessageA' `
                        -Property @{
                            'a' = 'b'
                        }
    }
    catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch -CaseSensitive ($ExceptionInfo.Type)
        {
            'CustomTypeA'
            {
                Write-Exception -Exception $Exception -Stream Verbose
                $a = $_
            }
            Default
            {
                Write-Warning -Message 'unhandled' -WarningAction Continue
            }
        }
    }
}


Workflow Test-Throw-Workflow
{
    try
    {
        Throw-Exception -Type 'CustomTypeA' `
                        -Message 'MessageA' `
                        -Property @{
                            'a' = 'b'
                        }
    }
    catch
    {
        $Exception = $_
        $ExceptionInfo = Get-ExceptionInfo -Exception $Exception
        Switch -CaseSensitive ($ExceptionInfo.Type)
        {
            'CustomTypeA'
            {
                Write-Exception -Exception $Exception -Stream Verbose
                $a = $_
            }
            Default
            {
                Write-Warning -Message 'unhandled' -WarningAction Continue
            }
        }
    }
}
'@

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
#RequiredModules = @('SCOrchDev-Utility')

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module
FunctionsToExport = '*'

# Cmdlets to export from this module
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module
AliasesToExport = '*'

# List of all modules packaged with this module
ModuleList = @('SCOrchDev-Demo')

# List of all files packaged with this module
FileList = @('SCOrchDev-Demo.psd1', 'SCOrchDev-Demo.psm1', 'LICENSE', 'README.md')

# Private data to pass to the module specified in RootModule/ModuleToProcess
# PrivateData = ''

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}
