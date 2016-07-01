#  PowerShell deployment example
#  v0.1
#  This script can be used to test the ARM template deployment, or as a reference for building your own deployment script.

Login-AzureRmAccount

$resourcegroupname = 'automationtest'
$location = 'eastus2'
$automationaccountname = 'scoautotest'

New-AzureRmResourcegroup -Name $resourcegroupname -Location $location -Verbose -Force

New-AzureRmResourceGroupDeployment -Name TestDeployment `
                                    -TemplateFile .\azuredeploy.json `
                                    -automationAccountName $automationaccountname `
                                    -ResourceGroupName $resourcegroupname `
                                    -Verbose