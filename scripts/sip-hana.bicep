@description('Deployment location')
param location string = 'switzerlandnorth'

@description('Name of the SAP HANA VM')
param vmName string = 'sap-hana-sles-01'

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for the VM')
param adminPassword string = ''

@description('Virtual network name')
param vnetName string = 'sap-hana-vnet'

@description('Address prefix for the virtual network')
param vnetAddressPrefix string = '10.10.0.0/16'

@description('Subnet name')
param subnetName string = 'sap-hana-subnet'

@description('Address prefix for the subnet')
param subnetPrefix string = '10.10.1.0/24'

@description('Network security group name')
param nsgName string = 'sap-hana-nsg'

@description('Public IP name')
param publicIpName string = 'sap-hana-pip'

@description('NIC name')
param nicName string = 'sap-hana-nic'

@description('VM size (use SAP HANA certified size)')
param vmSize string = 'Standard_E16ds_v5'

@description('SLES for SAP image publisher')
param imagePublisher string = 'SUSE'

@description('SLES for SAP image offer')
param imageOffer string = 'sles-sap-15-sp5'

@description('SLES for SAP image SKU')
param imageSku string = 'gen2'

@description('OS image version')
param imageVersion string = 'latest'

@description('Managed disk SKU for HANA data/log/shared/usr-sap')
@allowed([
  'Premium_LRS'
  'PremiumV2_LRS'
  'Premium_ZRS'
  'StandardSSD_LRS'
])
param dataDiskSku string = 'Premium_LRS'

@description('Size in GB for HANA data disk')
param hanaDataDiskSizeGB int = 512

@description('Size in GB for HANA log disk')
param hanaLogDiskSizeGB int = 256

@description('Size in GB for HANA shared disk')
param hanaSharedDiskSizeGB int = 256

@description('Size in GB for /usr/sap disk')
param usrSapDiskSizeGB int = 128

var hanaStorageAccountName = ''
var containerName = ''

@description('URI of the custom script for OS prep + HANA install')
var customScriptFileUri = 'https://${hanaStorageAccountName}.blob.core.windows.net/${containerName}/install-hana-sles.sh'

@description('Tags to apply to all resources')
param tags object = {
  workload: 'SAP-HANA'
  environment: 'dev'
  os: 'SLES-for-SAP'
}

var vmComputerName = vmName
var nicIpConfigName = 'ipconfig1'
var osDiskName = '${vmName}-osdisk'
var hanaDataDiskName = '${vmName}-hana-data'
var hanaLogDiskName = '${vmName}-hana-log'
var hanaSharedDiskName = '${vmName}-hana-shared'
var usrSapDiskName = '${vmName}-usr-sap'

//
// Networking
//

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-04-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 1000
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
      // Add specific SAP HANA ports here (e.g. 3<sid>13, 3<sid>15, etc.) as needed
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-04-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 30
  }
}

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: nicIpConfigName
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

//
// Disks
//

resource hanaDataDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name: hanaDataDiskName
  location: location
  tags: tags
  sku: {
    name: dataDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: hanaDataDiskSizeGB
  }
}

resource hanaLogDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name: hanaLogDiskName
  location: location
  tags: tags
  sku: {
    name: dataDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: hanaLogDiskSizeGB
  }
}

resource hanaSharedDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name: hanaSharedDiskName
  location: location
  tags: tags
  sku: {
    name: dataDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: hanaSharedDiskSizeGB
  }
}

resource usrSapDisk 'Microsoft.Compute/disks@2023-04-02' = {
  name: usrSapDiskName
  location: location
  tags: tags
  sku: {
    name: dataDiskSku
  }
  properties: {
    creationData: {
      createOption: 'Empty'
    }
    diskSizeGB: usrSapDiskSizeGB
  }
}

//
// VM
//

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmComputerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration: {
        disablePasswordAuthentication: false
      }
    }
    storageProfile: {
      imageReference: {
        publisher: imagePublisher
        offer: imageOffer
        sku: imageSku
        version: imageVersion
      }
      osDisk: {
        name: osDiskName
        caching: 'ReadWrite'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      dataDisks: [
        {
          lun: 0
          name: hanaDataDisk.name
          createOption: 'Attach'
          managedDisk: {
            id: hanaDataDisk.id
          }
        }
        {
          lun: 1
          name: hanaLogDisk.name
          createOption: 'Attach'
          managedDisk: {
            id: hanaLogDisk.id
          }
        }
        {
          lun: 2
          name: hanaSharedDisk.name
          createOption: 'Attach'
          managedDisk: {
            id: hanaSharedDisk.id
          }
        }
        {
          lun: 3
          name: usrSapDisk.name
          createOption: 'Attach'
          managedDisk: {
            id: usrSapDisk.id
          }
        }
      ]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            primary: true
          }
        }
      ]
    }
  }
}

//
// Custom Script Extension for SLES OS prep + HANA install
//

resource vmCustomScript 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  parent: vm
  name: 'customScriptForLinux'
  location: location
  tags: tags
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        customScriptFileUri
      ]
      commandToExecute: 'bash install-hana-sles.sh ${hanaStorageAccountName}'
    }
  }
}

//
// Outputs
//

output vmPublicIp string = publicIp.properties.ipAddress
output vmId string = vm.id
output subnetId string = vnet.properties.subnets[0].id
