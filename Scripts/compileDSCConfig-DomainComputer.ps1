Login-AzureRmAccount

$resourcegroupname = 'automationtest'
$automationaccountname = 'scoautotest'
$configurationname = 'DomainComputer'

$ConfigData = @{
    AllNodes = @(
        @{
            NodeName = "*"
            PSDscAllowPlainTextPassword = $True
        },
        @{
            NodeName = "MemberServerDev"
        },
        @{
            NodeName = "MemberServerQA"
        },
        @{
            NodeName = "MemberServerProd"
        }
    )
}

Start-AzureRmAutomationDscCompilationJob -ResourceGroupName $resourcegroupname `
                                         -AutomationAccountName $automationaccountname `
                                         -ConfigurationName $configurationname `
                                         -ConfigurationData $ConfigData