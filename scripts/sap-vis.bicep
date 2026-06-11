param location string = resourceGroup().location
param vnetName string = 'my-vnet'
param addressSpace string = '10.0.0.0/16'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string = ''

param subnets array = [
  {
    name: 'default'
    prefix: '10.0.1.0/24'
  }
]

resource vnet 'Microsoft.Network/virtualNetworks@2023-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressSpace
      ]
    }
    subnets: [
      for subnet in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.prefix
        }
      }
    ]
  }
}
resource hanaVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'hana-vm'
  location: location
  dependsOn: [
    vnet
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_E4s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'suse'
        offer: 'opensuse-leap-15-4'
        sku: 'gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
    }
    osProfile: {
      computerName: 'hana-vm'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', 'hana-vm-nic')
        }
      ]
    }
  }
}
