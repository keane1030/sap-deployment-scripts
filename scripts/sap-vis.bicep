param location string = resourceGroup().location
param vnetName string = 'my-vnet'
param addressSpace string = '10.0.0.0/16'
param adminUsername string = 'azureuser'
@secure()
param adminPassword string = ''
param nicName string = 'hana-vm-nic'
param subnetId string = '/subscriptions/4a671263-c67b-4057-a573-3d2a1113b12e/resourceGroups/SAP_RG/providers/Microsoft.Network/virtualNetworks/my-vnet/subnets/default'
param privateIp string = '10.0.1.4'

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

resource nic 'Microsoft.Network/networkInterfaces@2025-05-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'Ipv4config'
        properties: {
          privateIPAddress: privateIp
          privateIPAllocationMethod: 'Static'
          privateIPAddressVersion: 'IPv4'
          primary: true
          subnet: {
            id: subnetId
          }
        }
      }
    ]
    dnsSettings: {
      dnsServers: []
    }
    enableAcceleratedNetworking: false
    enableIPForwarding: false
    disableTcpStateTracking: false
    nicType: 'Standard'
    auxiliaryMode: 'None'
    auxiliarySku: 'None'
  }
}


resource hanaVm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'hana-vm'
  location: location
  dependsOn: [
    vnet, nic
  ]
  properties: {
    hardwareProfile: {
      vmSize: 'Standard_E4s_v3'
    }
    storageProfile: {
      imageReference: {
        publisher: 'suse'
        offer: 'sles-15-sp7-basic'
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

resource sapVirtualInstance 'Microsoft.Workloads/sapVirtualInstances@2023-04-01' = {
  name: 'mySapInstance'
  location: 'switzerlandnorth'
  dependsOn: [
    hanaVm
  ]
  properties: {
    environment: 'NonProd'        // or 'Prod'
    sapProduct: 'S4HANA'          // or 'ECC', 'BW4HANA', etc.
    configuration: {
      configurationType: 'Deployment'
      appLocation: 'switzerlandnorth'
      infrastructureConfiguration: {
        appResourceGroup: 'SAP_RG'
        deploymentType: 'SingleServer'
        subnetId: subnetId
        networkConfiguration: {
          isSecondaryIpEnabled: false
          networkInterfaceConfigurations: [
            {
              name: 'hana-vm-nic'
              properties: {
                ipConfigurations: [
                  {
                    name: 'Ipv4config'
                    properties: {
                      privateIPAddress: privateIp
                      privateIPAllocationMethod: 'Static'
                      privateIPAddressVersion: 'IPv4'
                      primary: true
                    }
                  }
                ]
              }
            }
          ] 
      }
    }
  }
}
