param location string = 'switzerlandnorth'
param vnetName string = 'sap-vnet'
param addressPrefix string = '10.10.0.0/16'
param subnetAppPrefix string = '10.10.1.0/24'
param subnetDbPrefix string = '10.10.2.0/24'
param visName string = 'sap-vis'
param hanaVmName string = 'hana-vm'
param hanaVmSize string = 'Standard_E32ds_v5'
param adminUsername string = 'brian'
param adminPassword string = 'P@ssw0rd1234'



resource Microsoft.Network/virtualNetworks
  apiVersion: 2023-05-01
  name: vnetName
  location: location
  properties:
    addressSpace:
      addressPrefixes:
        [ addressPrefix ]
    subnets:
      - name: app-subnet
        properties:
          addressPrefix: subnetAppPrefix
      - name: db-subnet
        properties:
          addressPrefix: subnetDbPrefix
