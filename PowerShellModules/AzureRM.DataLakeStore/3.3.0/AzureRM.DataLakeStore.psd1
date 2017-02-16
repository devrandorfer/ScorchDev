#
# Module manifest for module 'PSGet_AzureRM.DataLakeStore'
#
# Generated by: Microsoft Corporation
#
# Generated on: 1/17/2017
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'AzureRM.DataLakeStore.psm1'

# Version number of this module.
ModuleVersion = '3.3.0'

# ID used to uniquely identify this module
GUID = '90dfd814-abce-4e1f-99b6-fe16760c079a'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '© Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Microsoft Azure PowerShell - Data Lake Store'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '3.0'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
DotNetFrameworkVersion = '4.0'

# Minimum version of the common language runtime (CLR) required by this module
CLRVersion = '4.0'

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = 
               '.\Microsoft.Azure.Commands.DataLakeStoreFileSystem.format.ps1xml'

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('.\Microsoft.Azure.Commands.DataLakeStore.dll')

# Functions to export from this module
# FunctionsToExport = @()

# Cmdlets to export from this module
CmdletsToExport = 'Get-AzureRmDataLakeStoreTrustedIdProvider', 
               'Remove-AzureRmDataLakeStoreTrustedIdProvider', 
               'Remove-AzureRmDataLakeStoreFirewallRule', 
               'Set-AzureRmDataLakeStoreTrustedIdProvider', 
               'Add-AzureRmDataLakeStoreTrustedIdProvider', 
               'Get-AzureRmDataLakeStoreFirewallRule', 
               'Set-AzureRmDataLakeStoreFirewallRule', 
               'Add-AzureRmDataLakeStoreFirewallRule', 
               'Add-AzureRmDataLakeStoreItemContent', 
               'Export-AzureRmDataLakeStoreItem', 
               'Get-AzureRmDataLakeStoreChildItem', 'Get-AzureRmDataLakeStoreItem', 
               'Get-AzureRmDataLakeStoreItemAclEntry', 
               'Get-AzureRmDataLakeStoreItemContent', 
               'Get-AzureRmDataLakeStoreItemOwner', 
               'Get-AzureRmDataLakeStoreItemPermission', 
               'Import-AzureRmDataLakeStoreItem', 
               'Get-AzureRmDataLakeStoreAccount', 'Join-AzureRmDataLakeStoreItem', 
               'Move-AzureRmDataLakeStoreItem', 'New-AzureRmDataLakeStoreAccount', 
               'New-AzureRmDataLakeStoreItem', 
               'Remove-AzureRmDataLakeStoreAccount', 
               'Remove-AzureRmDataLakeStoreItem', 
               'Remove-AzureRmDataLakeStoreItemAcl', 
               'Remove-AzureRmDataLakeStoreItemAclEntry', 
               'Set-AzureRmDataLakeStoreItemAclEntry', 
               'Set-AzureRmDataLakeStoreAccount', 
               'Set-AzureRmDataLakeStoreItemAcl', 
               'Set-AzureRmDataLakeStoreItemExpiry', 
               'Set-AzureRmDataLakeStoreItemOwner', 
               'Set-AzureRmDataLakeStoreItemPermission', 
               'Test-AzureRmDataLakeStoreAccount', 'Test-AzureRmDataLakeStoreItem'

# Variables to export from this module
# VariablesToExport = @()

# Aliases to export from this module
AliasesToExport = 'Get-AdlStoreTrustedIdProvider', 'Remove-AdlStoreTrustedIdProvider', 
               'Remove-AdlStoreFirewallRule', 'Set-AdlStoreTrustedIdProvider', 
               'Add-AdlStoreTrustedIdProvider', 'Get-AdlStoreFirewallRule', 
               'Set-AdlStoreFirewallRule', 'Add-AdlStoreFirewallRule', 
               'Add-AdlStoreItemContent', 'Export-AdlStoreItem', 
               'Get-AdlStoreChildItem', 'Get-AdlStoreItem', 
               'Get-AdlStoreItemAclEntry', 'Get-AdlStoreItemContent', 
               'Get-AdlStoreItemOwner', 'Get-AdlStoreItemPermission', 
               'Import-AdlStoreItem', 'Get-AdlStore', 'Join-AdlStoreItem', 
               'Move-AdlStoreItem', 'New-AdlStore', 'New-AdlStoreItem', 
               'Remove-AdlStore', 'Remove-AdlStoreItem', 'Remove-AdlStoreItemAcl', 
               'Remove-AdlStoreItemAclEntry', 'Set-AdlStoreItemAclEntry', 
               'Set-AdlStore', 'Set-AdlStoreItemAcl', 'Set-AdlStoreItemExpiry', 
               'Set-AdlStoreItemOwner', 'Set-AdlStoreItemPermission', 
               'Test-AdlStore', 'Test-AdlStoreItem'

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'Azure','ResourceManager','ARM','DataLake','Store'

        # A URL to the license for this module.
        LicenseUri = 'https://raw.githubusercontent.com/Azure/azure-powershell/dev/LICENSE.txt'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/Azure/azure-powershell'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '* Updated help for all cmdlets to include output as well as more descriptions of parameters and the inclusion of aliases.
* Update New-AdlStore and Set-AdlStore to support commitment tier options for the service.
* Added OutputType mismatch warnings to all cmdlets with incorrect OutputType attributes. These will be fixed in a future breaking change release.
* Add Diagnostic logging support to Import-AdlStoreItem and Export-AdlStoreItem. This can be enabled through the following parameters:
    * -Debug, enables full diagnostic logging as well as debug logging to the PowerShell console. Most verbose options
    * -DiagnosticLogLevel, allows finer control of the output than debug. If used with debug, this is ignored and debug logging is used.
    * -DiagnosticLogPath, optionally specify the file to write diagnostic logs to. By default it is written to a file under %LOCALAPPDATA%\AdlDataTransfer
* Added support to New-AdlStore to explicitly opt-out of account encryption. To do so, create the account with the -DisableEncryption flag.
'

        # External dependent modules of this module
        # ExternalModuleDependencies = ''

    } # End of PSData hashtable
    
 } # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

