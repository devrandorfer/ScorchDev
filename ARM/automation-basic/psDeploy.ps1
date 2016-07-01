#  PowerShell deployment example
#  v0.1
#  This script can be used to test the ARM template deployment, or as a reference for building your own deployment script.

Login-AzureRmAccount

$DomainJoinCredential = Get-Credential

$resourcegroupname = 'automationtest'
$location = 'eastus2'
$automationaccountname = 'scoautotest'
$defaultDomainName = 'scorchdev.com'

New-AzureRmResourcegroup -Name $resourcegroupname -Location $location -Verbose -Force

New-AzureRmResourceGroupDeployment -Name TestDeployment `
                                    -TemplateFile .\azuredeploy.json `
                                    -automationAccountName $automationaccountname `
                                    -ResourceGroupName $resourcegroupname `
                                    -DomainJoinCredentialName $DomainJoinCredential.UserName `
                                    -DomainJoinCredentialPassword $DomainJoinCredential.Password `
                                    -DefaultDomainName $defaultDomainName `
                                    -Verbose