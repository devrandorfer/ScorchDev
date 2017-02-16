#
# Module manifest for module 'PSGet_AzureRM.AzureStackStorage'
#
# Generated by: Microsoft Corporation
#
# Generated on: 12/17/2016
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'AzureRM.AzureStackStorage.psm1'

# Version number of this module.
ModuleVersion = '0.10.2'

# ID used to uniquely identify this module
GUID = 'da5816b5-97a6-4301-9aa0-72cc68c79f20'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = 'Microsoft Corporation. All rights reserved.'

# Description of the functionality provided by this module
Description = 'Microsoft Azure PowerShell - Storage management cmdlets for Azure Stack'

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
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('.\Microsoft.AzureStack.AzureConsistentStorage.Commands.dll')

# Functions to export from this module
# FunctionsToExport = @()

# Cmdlets to export from this module
CmdletsToExport = 'Remove-ACSAcquisition', 'Get-ACSAcquisition', 'Add-ACSFarm', 
               'Clear-ACSStorageAccount', 'Get-ACSEvent', 'Get-ACSEventQuery', 
               'Get-ACSFarm', 'Get-ACSFarmMetricDefinition', 'Get-ACSFarmMetric', 
               'Set-ACSFarm', 'Get-ACSFault', 'Get-ACSFaultHistory', 
               'Resolve-ACSFault', 'Disable-ACSNode', 'Enable-ACSNode', 'Get-ACSNode', 
               'Get-ACSNodeMetricDefinition', 'Get-ACSNodeMetric', 'Get-ACSQuota', 
               'New-ACSQuota', 'Remove-ACSQuota', 'Set-ACSQuota', 
               'Get-ACSRoleInstance', 'Get-ACSRoleInstanceMetricDefinition', 
               'Get-ACSRoleInstanceMetric', 'Restart-ACSRoleInstance', 
               'Update-ACSRoleInstance', 'Start-ACSBlobServerRoleInstance', 
               'Stop-ACSBlobServerRoleInstance', 'Get-ACSBlobService', 
               'Get-ACSBlobServiceMetricDefinition', 'Get-ACSBlobServiceMetric', 
               'Get-ACSManagementService', 
               'Get-ACSManagementServiceMetricDefinition', 
               'Get-ACSManagementServiceMetric', 'Get-ACSQueueService', 
               'Get-ACSQueueServiceMetricDefinition', 'Get-ACSQueueServiceMetric', 
               'Get-ACSTableService', 'Get-ACSTableServiceMetricDefinition', 
               'Get-ACSTableServiceMetric', 'Set-ACSBlobService', 
               'Set-ACSManagementService', 'Set-ACSQueueService', 
               'Set-ACSTableService', 'Get-ACSShare', 'Get-ACSShareMetricDefinition', 
               'Get-ACSShareMetric', 'Get-ACSStorageAccount', 
               'Sync-ACSStorageAccount', 'Undo-ACSStorageAccountDeletion'

# Variables to export from this module
# VariablesToExport = @()

# Aliases to export from this module
# AliasesToExport = @()

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
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # External dependent modules of this module
        # ExternalModuleDependencies = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

