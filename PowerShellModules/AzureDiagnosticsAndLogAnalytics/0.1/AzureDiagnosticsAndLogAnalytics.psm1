<#
    Enable Log Analytics to collect logs from Azure Diagnostics

#>

#Requires -Modules @{ModuleName = "AzureRM.OperationalInsights"; ModuleVersion = "1.0.8";}

<# 

Constants
    
#>

$ContainerFormat = "insights-logs-{0}/resourceId={1}"

# Supported "Resource Provider / Provider / Category"
$MonitorableResourcesAndCategories = [ordered]@{
    "Microsoft.Automation/AutomationAccounts" = @("JobLogs", "JobStreams")
    "Microsoft.KeyVault/Vaults" = @("AuditEvent")
    "Microsoft.Network/NetworkSecurityGroups" = @("NetworkSecurityGroupEvent", "NetworkSecurityGroupRuleCounter")
    "Microsoft.Network/ApplicationGateways" = @("ApplicationGatewayAccessLog", "ApplicationGatewayPerformanceLog")
}

# Solution to enable for the configuration for the "Resource Provider / Provider"
$MonitorableResourcesToOMSSolutions = [ordered]@{
    "Microsoft.Automation/AutomationAccounts" = "AzureAutomation"
    "Microsoft.KeyVault/Vaults" = "KeyVault"
    "Microsoft.Network/NetworkSecurityGroups" = "AzureNetworking"
    "Microsoft.Network/ApplicationGateways" = "AzureNetworking"
}

function Update-StorageInsightWithResource
{
    param([psobject] $ExistingInsight,
          [string[]] $FeatureContainers,
          [psobject] $WorkspaceObject)

    Write-Verbose "Logs already being collected from storage account. Checking if additional resource logs need to be collected."

    # Check which of the current set of logs are not being monitored
    [boolean]$dirty = $false;
    
	[array]$Containers = $ExistingInsight.Containers
    foreach($feature in $FeatureContainers) {
        if($Containers -notcontains $feature) {
            $Containers += $feature
            $dirty = $true;
            Write-Verbose "Adding container: $feature";
        }else{
            Write-Verbose "Already configured: $feature";
        }
    }

    # If any of the logs from the available log list are not already monitored , then we add them
    if($dirty -eq $true) {			                    
		Set-AzureRmOperationalInsightsStorageInsight -Workspace $WorkspaceObject -Name $ExistingInsight.name  -Containers $Containers
        Write-Verbose "Updated Log Analytics configuration for storage account."
    } 
    else {
        Write-Output "`nResource already configured. No configuration change made."
    }
    
}

function Get-AzureStorageKeyForResource
{
    param(
            [psobject] $StorageAccountResource            
         )
    if($StorageAccountResource.ResourceType -like "Microsoft.ClassicStorage/storageAccounts")
    {
        try {
            Select-AzureSubscription -SubscriptionId $StorageAccountResource.SubscriptionId -ErrorAction “Stop” | Write-Verbose
        } catch {
            Write-Error $_
            Write-Error "You most likely need to run Add-AzureAccount to login."
            return $false
        }
        $keys = Get-AzureStorageKey -StorageAccountName $StorageAccountResource.Name
        $AccountKey = $Keys.Primary
    }
    else
    {
        Select-AzureRmSubscription -SubscriptionId $StorageAccountResource.SubscriptionId  | Write-Verbose
	    $Keys = Get-AzureRmStorageAccountKey -ResourceGroupName $StorageAccountResource.ResourceGroupName -Name $StorageAccountResource.Name
        $AccountKey = $Keys[0].Value
    }        

    return $AccountKey
}

<# 

.SYNOPSIS
 Configure Log Analytics to read from the storage account used by Azure Diagnostics

.DESCRIPTION 
 This function associates the resource passed in with the Log Analytics workspace to enable collection of diagnostics logs for the resource.
 It is required that Azure Diagnostic Logs have already been enabled for the resource and that the Log Analytics workspace exists.

.PARAMETER ResourceForLogs
    Azure Resource Manager resource object for the resource to be monitored. Eg : Output from Get-AzureRmResource -Name "<NameOfResource>" 
    Types of supported resource are
        Microsoft.Automation/AutomationAccounts
        Microsoft.KeyVault/Vaults
        Microsoft.Network/NetworkSecurityGroups
        Microsoft.Network/ApplicationGateways

.PARAMETER WorkspaceResource
    Azure Resource Manager resource object for the Log Analytics workspace to be configured. Eg : Output from Get-AzureRmResource -Name "<NameOfWorkspace>" -ResourceType "Microsoft.OperationalInsights/workspaces"

.PARAMETER Categories
    An array of strings that lists the log categories that are expected to go to insights. Leave as null for enabling all categories.
    These correspond to the cateories that you have enabled for Azure diagnostics.

.EXAMPLE
    Add-AzureDiagnosticsToLogAnalytics $resource $workspace

.NOTES
    
#>

function Add-AzureDiagnosticsToLogAnalytics
{
Param(
    [Parameter(Mandatory=$true, ValueFromPipeline = $true, HelpMessage="Azure Resource Manager resource object for the resource to be monitored. Eg : Output from Get-AzureRmResource -Name <NameOfResource>")]
    [ValidateNotNull()]
    [ValidateScript({($_.ResourceId -ne $null) -and ($_.SubscriptionId -ne $null)})] 
    [psobject] $ResourceForLogs,

    [Parameter(Mandatory=$true, HelpMessage="Azure Resource Manager resource object for the Log Analytics workspace to be configured. Eg : Output from Get-AzureRmResource -Name <NameOfWorkspace> -ResourceType Microsoft.OperationalInsights/workspaces")]
    [ValidateNotNull()]
    [ValidateScript({($_.SubscriptionId -ne $null) -and ($_.ResourceGroupName -ne $null) -and ($_.ResourceName -ne $null)})] 
    [psobject] $WorkspaceResource,
    
    [Parameter(Mandatory=$false)] 
    [string[]]$Categories
    )

try
{
    Select-AzureRmSubscription -SubscriptionId $ResourceForLogs.SubscriptionId | Write-Verbose
    $ResourceDiagnosticSetting = Get-AzureRmDiagnosticSetting -ResourceId $ResourceForLogs.ResourceId 
    if($ResourceDiagnosticSetting.storageAccountId -eq $null)
    {
        Write-Error ("Logging is not enabled for this resource: " + $ResourceForLogs.ResourceName + ". Enable logging before running this script.")
        throw
    }

    # Get the storage account name and provider name    
    # Added assumption here is that we have access to the storage account in the current authenticated context.
    
    [string]$storageAccountId = $ResourceDiagnosticSetting.storageAccountId  	
    $StorageAccountResource = Get-AzureRmResource -ResourceId $storageAccountId       
    $storageAccountName = $StorageAccountResource.ResourceName

    [string]$AccountKey = ""
    $Accountkey = Get-AzureStorageKeyForResource $StorageAccountResource
			
    Write-Output ("Getting existing configuration for workspace: " + $WorkspaceResource.Name)
    Select-AzureRmSubscription -SubscriptionId $WorkspaceResource.SubscriptionId  | Write-Verbose
    [array]$ExistingInsights = Get-AzureRmOperationalInsightsStorageInsight -ResourceGroupName $WorkspaceResource.ResourceGroupName -WorkspaceName $WorkspaceResource.Name
    $WorkspaceObject = Get-AzureRmOperationalInsightsWorkspace -ResourceGroupName $WorkspaceResource.ResourceGroupName -Name $WorkspaceResource.Name 
    if ($ExistingInsights) {                     
	    $ExistingInsight = $ExistingInsights | Where-Object { $_.StorageAccountResourceId.Trim() -eq $storageAccountId.Trim() }
    }    
    
    $SupportedCategories = $MonitorableResourcesAndCategories[$ResourceForLogs[0].ResourceType]   

    if($Categories -ne $null)
    {
        $CategoriesToMonitor = @()
        $CategoriesToMonitor = $SupportedCategories | Where-Object {$Categories -contains $_ }
        if($Categories.Count -ne $CategoriesToMonitor.Count)
        {
            Write-Error "Unable to find all requested Categories"
            Write-Error "Supported Categories are : $SupportedCategories"
            Write-Error "Requested Categories are : $Categories"
            throw 
        }
    }
    else 
    {
        $CategoriesToMonitor = $SupportedCategories
    }

    $FeatureContainers = @()
    $enabledLogs = @()
    foreach($log in $ResourceDiagnosticSetting.logs) {
        if($log.enabled) 
        { 
            $enabledLogs += ,$log.category
            if($CategoriesToMonitor -contains $log.category)   
            {
                $FeatureContainers += $ContainerFormat -f $log.category.ToLower(),$ResourceForLogs.ResourceId.ToUpper()
            }
        }
    }

    if(($FeatureContainers.Count -eq 0) -or ($FeatureContainers.Count -ne $CategoriesToMonitor.Count))
    {
        Write-Error "Did not find all categories to monitor enabled"
        Write-Error "Categories reqested are : $CategoriesToMonitor"
        Write-Error "Enabled log categories are : $enabledLogs"
    }
    # If the storage account has already been added to Insights and we only need to add the logs to it
    if($ExistingInsight) {
        Write-Output "Checking container configuration: $FeatureContainers"
        Update-StorageInsightWithResource $ExistingInsight $FeatureContainers $WorkspaceObject        
    } 
    # If we need to add both the storage account and the logs.
    else {    
        $StorageInsightName = $storageAccountName + $WorkspaceObject.Name                
        Write-Output "Enabling Insights with name:`n $StorageInsightName"
        Write-Output "For storage account:`n $storageAccountId"                   
        Write-Output "Container Configuration: $FeatureContainers"
	    New-AzureRmOperationalInsightsStorageInsight -Workspace $WorkspaceObject -Name $StorageInsightName -StorageAccountResourceId $storageAccountId -StorageAccountKey $Accountkey -Containers $FeatureContainers
        Write-Output "Configured Log Analytics to read from new storage account. "
    }
}
Catch
{
    Write-Error "Error during configuration"
    throw
}
}

<#
.Synopsis
   Guide user through configuring Log Analytics to collect logs from Azure diagnostics storage
.DESCRIPTION
   Interactively prompt the user for which Azure resources to monitor and configure Log Analytics to collect logs to read from the diagnostic storage used by the resource.
   The user will be prompted to select from the supported resource types, select an instance of the resource type and also a Log Analytics workspace that should collect the logs.
   This function takes no arguments.
   Assumption is that Azure Diagnostics have already been enabled for the resource.
.EXAMPLE
   Add-AzureDiagnosticsToLogAnalyticsUI

#>
function Add-AzureDiagnosticsToLogAnalyticsUI
{

    #
    # Reference variable declarations
    #
    $UserChoiceInt = $null

    #
    # Allow user to pick the resource type to configure OMS to collect
    #
    Write-Output "`nResources Types and Categories supported for log collection:`n"
    $ChoiceNumber = 0

    foreach ($Resource in $MonitorableResourcesAndCategories.Keys) {
        $ChoiceNumber++
        Write-Output ("$ChoiceNumber. " + $Resource )
        Write-Output ("`t" + $MonitorableResourcesAndCategories[$Resource]) }

    do {
        $UserChoice = Read-Host "`nEnter the # corresponding to the resource to configure monitoring or 0 to quit."
        if ($UserChoice -eq 0) { return }
        $IsInt = [int32]::TryParse($UserChoice, [ref]$UserChoiceInt)  
    } while( $IsInt -eq $False -or $UserChoiceInt -gt $ChoiceNumber)

    $ResourceTypeToMonitor = @($MonitorableResourcesAndCategories.Keys)[$UserChoiceInt - 1]

    #
    # Get list of Azure subscriptions user has access to, allow to pick if more than one
    #
    $SubscriptionsAvailable = @(Get-AzureRmSubscription)

    if ($SubscriptionsAvailable.Count -gt 1)
    {
        Write-Output "`nYour Azure Subscriptions are:`n"    
        $ChoiceNumber = 0

        foreach($sub in $SubscriptionsAvailable)
        {
            $ChoiceNumber++;
            Write-Output ("$ChoiceNumber. " + $sub.subscriptionId + " (" + $sub.SubscriptionName + ")")
        }

        do {
            $UserChoice = Read-Host "`nEnter the number corresponding to the subscription the resources to congfigure are in. (Press 0 to cancel)"
            if($UserChoice -eq 0) { return }
            $IsInt = [int32]::TryParse($UserChoice, [ref]$UserChoiceInt) 
        } while( $IsInt -eq $False -or $UserChoiceInt -gt $ChoiceNumber)

        Select-AzureRmSubscription -SubscriptionId $SubscriptionsAvailable[$UserChoiceInt - 1].SubscriptionId
    }
    if ($SubscriptionsAvailable.Count -eq 0)
    {
        Write-Error "Get-AzureRmSubscription does not return any subscriptions."
        Write-Error "You may need to refresh credentials. Please run Login-AzureRmAccount and run this script again."
        return
    }

    #
    # Find the resources and show what does not have diagnostics enabled and what does
    #
    Write-Output "`nFinding resources of type $ResourceTypeToMonitor and verifying diagnostic logging is enabled...`n"

    $resources = @(Find-AzureRmResource -ResourceType $ResourceTypeToMonitor -WarningAction:SilentlyContinue)
    $ResourceHasDiagnosticsLoggingEnabled = @{}
    $ResourceHasNoDiagnosticsLoggingEnabled = @()

    foreach ($resource in $resources) {
        $diag = Get-AzureRmDiagnosticSetting -ResourceId $resource.ResourceId
        if ($diag.StorageAccountId) {
            $ResourceHasDiagnosticsLoggingEnabled.add($resource.ResourceId,@($resource,$diag.Logs))
        } else
        {
            $ResourceHasNoDiagnosticsLoggingEnabled += $resource.ResourceId
        }
    }

    if ($ResourceHasNoDiagnosticsLoggingEnabled.Count -gt 0) {
        Write-Output "These resources do not have diagnostics enabled. You must enable diagnostics on the resource before you configure Log Analytics to collect the logs.`n"
        $ResourceHasNoDiagnosticsLoggingEnabled | Write-Output }

    if ($ResourceHasDiagnosticsLoggingEnabled.Count -lt 1) {
        Write-Output "`nNo resources have diagnostics enabled. You must enable diagnostics on the resource before you configure Log Analytics to collect the logs.`n"
        return }

    Write-Output "`nThese resources have diagnostic logging enabled for categories listed:`n"
    $ChoiceNumber = 0

    foreach ($resourceId in $ResourceHasDiagnosticsLoggingEnabled.Keys) {
        $ChoiceNumber++;
        Write-Output ("$ChoiceNumber. " + $resourceId)
        foreach ($log in $ResourceHasDiagnosticsLoggingEnabled[$resourceId][1] ) {
            if ($log.Enabled -eq $true) { Write-Output ("`t " + $log.Category) }
        }
    }

    #
    # Allow user to pick the resources
    #
    $ResourcesToEnable = @()
    do
    {
        $UserChoice = Read-Host "`nEnter the number corresponding to the resource you want to Log Analytics to collect logs from. (Press 0 to cancel)"
        if($UserChoice -eq 0) { return }

        $IsInt = [int32]::TryParse($UserChoice, [ref]$UserChoiceInt)
        if ($IsInt -eq $true -and $UserChoiceInt -gt 0 -and $UserChoiceInt -le $ResourceHasDiagnosticsLoggingEnabled.Keys.Count) {
            $ResourcesToEnable += @($ResourceHasDiagnosticsLoggingEnabled.Keys)[$UserChoiceInt - 1]
        }
        else { Write-Output "Enter a number in the list" }

        if($ResourceHasDiagnosticsLoggingEnabled.Count -gt 1)
        {
            $addMore = Read-Host "Do you want to add more resources to the Log Analytics workspace (y/n)?"
            if ($addMore -ne 'y') { break }
        } else { break }

    } while( $true ) 

    #
    # Allow user to pick Azure Subscription workspace is in
    #
    if($SubscriptionsAvailable.Count -gt 1)
    {
        Write-Output "`nYour Azure Subscriptions are:`n"    
        $ChoiceNumber = 0

        foreach($sub in $SubscriptionsAvailable)
        {
            $ChoiceNumber++
            Write-Output ("$ChoiceNumber. " + $sub.subscriptionId + " (" + $sub.SubscriptionName + ")")
        }

        do {
            $UserChoice = Read-Host "`nEnter the number corresponding to the subscription the Log Analytics workspace is in. (Press 0 to cancel)"
            if($UserChoice -eq 0) { return }
            $IsInt = [int32]::TryParse($UserChoice, [ref]$UserChoiceInt) 
        } while( $IsInt -eq $False -or $UserChoiceInt -gt $ChoiceNumber)

        Select-AzureRmSubscription -SubscriptionId $SubscriptionsAvailable[$UserChoiceInt - 1].SubscriptionId | Write-Verbose
    }

    #
    # Allow user to pick the Log Analytics workspace
    #
    Write-Output "`nFinding your Log Analytics workspaces:`n"
    $OMSWorkspaces = Find-AzureRmResource -ResourceType "Microsoft.OperationalInsights/workspaces" -WarningAction:SilentlyContinue
    $ChoiceNumber = 0
    foreach ($workspace in $OMSWorkspaces) {
        $ChoiceNumber++
        Write-Output ("$ChoiceNumber. " + $workspace.Name)
    }

    do {
        $UserChoice = Read-Host "`nEnter the # corresponding to the Log Analytics workspace to configure or 0 to quit."
        if ($UserChoice -eq 0) { Write-Output $UserChoice; return }
        $IsInt = [int32]::TryParse($UserChoice, [ref]$UserChoiceInt) 
    } while( $IsInt -eq $False -or $UserChoiceInt -gt $ChoiceNumber)
    $OMSWorkspaceResource = $OMSWorkspaces[$UserChoiceInt - 1]

    #
    # For every resource, configure it
    #
    foreach ($resourceId in $ResourcesToEnable) {
        $resourceId | Write-Verbose
        $ResourceHasDiagnosticsLoggingEnabled[$resourceId][0] | Write-Verbose
        $OMSWorkspaceResource | Write-Verbose
        Add-AzureDiagnosticsToLogAnalytics -ResourceForLogs $ResourceHasDiagnosticsLoggingEnabled[$resourceId][0] -WorkspaceResource $OMSWorkspaceResource
    }

    #
    # Enable the Solution the resource is associated with
    #
    Write-Output ("`nEnabling Solution: " + $MonitorableResourcesToOMSSolutions[$ResourceTypeToMonitor] + " for Log Analytics workspace: " + $OMSWorkspaceResource.Name)
    Set-AzureRmOperationalInsightsIntelligencePack -ResourceGroupName $OMSWorkspaceResource.ResourceGroupName -WorkspaceName $OMSWorkspaceResource.Name -intelligencepackname $MonitorableResourcesToOMSSolutions[$ResourceTypeToMonitor] -Enabled $true 
}

Export-ModuleMember -Function Add-AzureDiagnosticsToLogAnalyticsUI, Add-AzureDiagnosticsToLogAnalytics   
Export-ModuleMember -Variable ContainerFormat, MonitorableResourcesAndCategories, MonitorableResourcesToOMSSolutions