Clear-Host

# --- Settings
$Location = "uksouth"
$AzResourceGroupName = "rg-lab-dev-uksouth-001"
$AzStorageAccountName = "stlabdevuksouth001"
$AzNetworkWatcherName = "nw-lab-dev-uksouth-001"
$AzAvailabilitySetName = "avail-lab-dev-uksouth-001"
$AzVirtualNetworkName = "vnet-lab-dev-uksouth-001"
$AzNetworkSecurityGroupName = "nsg-lab-dev-uksouth-001"
$AzVirtualNetworkSubnetConfigName = "snet-lab-dev-uksouth-001"
$AzPublicIpAddressName = "pip-lab-dev-uksouth-001"
$AzNetworkInterfaceName = "nic-lab-dev-uksouth-001"
$AzVMConfigVMName = "vm-lab-dev-uksouth-001"
$AzVMOperatingSystemComputerName = "VM001"
 
# --- SuppressAzureRmModulesRetiringWarning
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# --- Connect-AzAccount
Connect-AzAccount -Credential (Get-Credential) | Out-Null

# --- LocalAdminCredential
$LocalAdminCredential = New-Object System.Management.Automation.PSCRedential ("LocalAdmin", (ConvertTo-SecureString "Password1!" -AsPlainText -Force))

try {
 
    # --- AzLocation
    "Setting AzLocation... " | Out-Host
    $AzLocation = Get-AzLocation | Where-Object {$_.Location -eq $Location}
    
    # --- AzResourceGroup
    "Checking AzResourceGroup... " | Out-Host
    $AzResourceGroup = Get-AzResourceGroup -Name $AzResourceGroupName -Location $AzLocation.Location -ErrorAction SilentlyContinue
    if ($AzResourceGroup) {
        "Removing exisitng AzResourceGroup... " | Out-Host
        Remove-AzResourceGroup -Name $AzResourceGroupName -Force | Out-Null
    }
    "Creating AzResourceGroup... " | Out-Host
    $AzResourceGroup = New-AzResourceGroup -Name $AzResourceGroupName -Location $AzLocation.Location

    # --- AzStorageAccount
    "Creating AzStorageAccount... " | Out-Host
    $AzStorageAccount = New-AzStorageAccount -Name $AzStorageAccountName -SkuName Standard_LRS -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location

    # --- AzNetworkWatcher
    "Checking AzNetworkWatcher... " | Out-Host
    $AzNetworkWatcher = Get-AzNetworkWatcher -Name $AzNetworkWatcherName -ErrorAction SilentlyContinue
    if (!$AzNetworkWatcher)
    {
        "Creating AzNetworkWatcher... " | Out-Host
        $AzNetworkWatcher = New-AzNetworkWatcher -Name $AzNetworkWatcherName -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location
    }
    
    # --- AzAvailabilitySet
    "Create AzAvailabilitySet... " | Out-Host
    $AzAvailabilitySet = New-AzAvailabilitySet -Name $AzAvailabilitySetName -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location -Sku Aligned -PlatformUpdateDomainCount 1 -PlatformFaultDomainCount 1
    
    # --- AzVirtualNetwork
    "Create AzVirtualNetwork... " | Out-Host
    $AzVirtualNetwork = New-AzVirtualNetwork -Name $AzVirtualNetworkName -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location -AddressPrefix 192.168.0.0/16
    
    # --- AzNetworkSecurityGroup
    "Create AzNetworkSecurityGroup... " | Out-Host
    $AzNetworkSecurityGroup = New-AzNetworkSecurityGroup -Name $AzNetworkSecurityGroupName -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location
    
    # --- AzNetworkWatcherFlowLog
    "Create AzNetworkWatcherFlowLog... " | Out-Host
    $AzNetworkWatcherFlowLog = New-AzNetworkWatcherFlowLog -Name "$($AzNetworkSecurityGroup.Name)_FlowLog" -NetworkWatcherName $AzNetworkWatcher.Name -ResourceGroupName $AzResourceGroup.ResourceGroupName -StorageId $AzStorageAccount.Id -TargetResourceId $AzNetworkSecurityGroup.Id -Enabled $true
    
        # --- Add the AzNetworkSecurityRuleConfig / RDP
        "Adding AzNetworkSecurityRuleConfig (RDP)... " | Out-Host
        $AzNetworkSecurityGroup | Add-AzNetworkSecurityRuleConfig -Name "$($AzNetworkSecurityGroup)-rdp"  -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389 | Out-Null
        $AzNetworkSecurityGroup | Set-AzNetworkSecurityGroup | Out-Null
    
    # --- AzVirtualNetworkSubnetConfig
    "Create AzVirtualNetworkSubnetConfig... " | Out-Host
    $AzVirtualNetworkSubnetConfig = Add-AzVirtualNetworkSubnetConfig -Name $AzVirtualNetworkSubnetConfigName -VirtualNetwork $AzVirtualNetwork -NetworkSecurityGroup $AzNetworkSecurityGroup -AddressPrefix 192.168.0.0/24
    $AzVirtualNetwork = Set-AzVirtualNetwork -VirtualNetwork $AzVirtualNetwork

    # --- AzVMConfig / AzVM

        # --- AzPublicIpAddress
        "Create AzPublicIpAddress... " | Out-Host
        $AzPublicIpAddress = New-AzPublicIpAddress -Name $AzPublicIpAddressName -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location -AllocationMethod Static

        # --- Create the AzNetworkInterface
        "Create AzNetworkInterface... " | Out-Host
        $AzNetworkInterface = New-AzNetworkInterface -Name $AzNetworkInterfaceName -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location -Subnet $AzVirtualNetwork.Subnets[0] -PublicIpAddress $AzPublicIpAddress
            
        # --- Get the AzVMSize
        "Setting AzVMSize... " | Out-Host
        $AzVMSize = Get-AzVMSize -Location $AzLocation.Location | Where-Object {$_.Name -eq "Standard_B2s"}
        
        # --- AzVMConfig
        "Setting AzVMConfig... " | Out-Host
        $AzVMConfig = New-AzVMConfig -VMName $AzVMConfigVMName -VMSize $AzVMSize.Name -AvailabilitySetId $AzAvailabilitySet.Id

            # --- AzVMOperatingSystem
            "Setting AzVMOperatingSystem... " | Out-Host
            $AzVMConfig = $AzVMConfig | Set-AzVMOperatingSystem -ComputerName $AzVMOperatingSystemComputerName -Credential $LocalAdminCredential -ProvisionVMAgent -Windows

            # --- AzVMSourceImage
            "Setting AzVMSourceImage... " | Out-Host
            $AzVMConfig = $AzVMConfig | Set-AzVMSourceImage -PublisherName "MicrosoftWindowsDesktop" -Offer "windows-11" -Skus "win11-21h2-pro" -Version "22000.613.220405"

            # --- Set the AzVMNetworkInterfact
            "Setting AzVMNetworkInterfact... " | Out-Host
            $AzVMConfig = $AzVMConfig | Add-AzVMNetworkInterface -Id $AzNetworkInterface.Id

            # --- AzVMOSDisk
            "Setting AzVMOSDisk... " | Out-Host
            $AzVMConfig = $AzVMConfig | Set-AzVMOSDisk -Name "$($AzVMConfigVMName)-osdisk" -DiskSizeInGB 127 -CreateOption FromImage -StorageAccountType Standard_LRS

            # --- AzVMDataDisk
            "Setting AzVMDataDisk... " | Out-Host
            $AzVMConfig = $AzVMConfig | Add-AzVMDataDisk -Name "$($AzVMConfigVMName)-datadisk-01" -DiskSizeInGB 80 -CreateOption Empty -StorageAccountType Standard_LRS -Lun 0

            # --- AzVMBootDiagnostic
            "Setting AzVMBootDiagnostic... " | Out-Host
            $AzVMConfig = $AzVMConfig | Set-AzVMBootDiagnostic -ResourceGroupName $AzResourceGroup.ResourceGroupName -StorageAccountName $AzStorageAccount.StorageAccountName -Enable

    # --- AzVM
    "Create AzVM... " | Out-Host
    New-AzVM -VM $AzVMConfig -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location | Out-Null

    # --- Configure
    
        # --- Get the AzVM
        "Setting AzVM... " | Out-Host
        $AzVM = Get-AzVM -Name $AzVMConfigVMName -ResourceGroupName $AzResourceGroup.ResourceGroupName

        # --- Enable EncryptionAtHost
        "Setting EncryptionAtHost... " | Out-Host
        
            # --- Stop AzVM
            "Stopping AzVM... " | Out-Host
            $AzVM | Stop-AzVM -Force | Out-Null

            # --- Enable EncryptionAtHost
            "Enable EncryptionAtHost... " | Out-Host
            $AzVM | Update-AzVM -EncryptionAtHost $true | Out-Null
            
            # --- Start AzVM
            "Starting AzVM... " | Out-Host
            $AzVM | Start-AzVM | Out-Null

        # --- Join AzureAD
        "Setting IdentityType (SystemAssigned)... " | Out-Host
        $AzVM | Update-AzVM -IdentityType SystemAssigned | Out-Null
        
            # --- AzVMExtension (AADLoginForWindows)
            "Setting AzVMExtension (AADLoginForWindows)... " | Out-Host
            Set-AzVMExtension -VMName $AzVMConfigVMName -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location -TypeHandlerVersion 1.0 -Publisher "Microsoft.Azure.ActiveDirectory" -ExtensionType "AADLoginForWindows" -Name "AADLogin" -NoWait | Out-Null

            # --- AzVMExtension (MicrosoftMonitoringAgent)
            "Setting AzVMExtension (MicrosoftMonitoringAgent)... " | Out-Host
            Set-AzVMExtension -VMName $AzVMConfigVMName -ResourceGroupName $AzResourceGroup.ResourceGroupName -Location $AzLocation.Location -TypeHandlerVersion 1.0 -Publisher "Microsoft.EnterpriseCloud.Monitoring" -ExtensionType "MicrosoftMonitoringAgent" -Name "MicrosoftMonitoringAgent" -NoWait | Out-Null

        # --- Enable RDP
        "Setting AzRoleAssignment (Virtual Machine User Login)... " | Out-Host
        $AzADGroup = Get-AzADGroup -DisplayName "All Users"
        $AzRoleDefinition = Get-AzRoleDefinition -Name "Virtual Machine User Login"
        New-AzRoleAssignment -ObjectId $AzADGroup.Id -RoleDefinitionName $AzRoleDefinition.Name -ResourceGroupName $AzResourceGroup.ResourceGroupName | Out-Null

        # --- Stop AzVM
        "Stopping AzVM... " | Out-Host
        $AzVM | Stop-AzVM -Force | Out-Null

} catch {

    $_

    Remove-AzResourceGroup -ResourceGroupName $AzResourceGroupName -Force

}
