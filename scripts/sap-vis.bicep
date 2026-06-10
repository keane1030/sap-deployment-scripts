param location string = resourceGroup().location
param vnetName string = 'my-vnet'
param addressSpace string = '10.0.0.0/16'

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