Login-AzureRmAccount

$AvailabilitySets = Find-AzureRmResource -ResourceType Microsoft.Compute/AvailabilitySets

Foreach($_AvailabilitySets in $AvailabilitySets)
{
    $avSet =  Get-AzureRmAvailabilitySet -ResourceGroupName $_AvailabilitySets.ResourceGroupName -Name $_AvailabilitySets.Name

    Update-AzureRmAvailabilitySet -AvailabilitySet $avSet -Managed

    foreach($vmInfo in $avSet.VirtualMachinesReferences)
    {
       $vm =  Get-AzureRmVM -ResourceGroupName $_AvailabilitySets.ResourceGroupName | Where-Object {$_.Id -eq $vmInfo.id}

       Stop-AzureRmVM -ResourceGroupName $_AvailabilitySets.ResourceGroupName -Name  $vm.Name -Force

       ConvertTo-AzureRmVMManagedDisk -ResourceGroupName $_AvailabilitySets.ResourceGroupName -VMName $vm.Name

    }
}