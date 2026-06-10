param location string = switzerlandnorth
param vnetName string = sap-vnet
param addressPrefix string = 10.10.0.0/16
param subnetAppPrefix string = 10.10.1.0/24
param subnetDbPrefix string = 10.10.2.0/24
param visName string = sap-vis
param hanaVmName string = hana-vm
param hanaVmSize string = Standard_E32ds_v5
param adminUsername string = brian
param adminPassword secureString = "P@ssw0rd1234"



# -----------------------------
# Virtual Network + Subnets
# -----------------------------
 resource Microsoft.Network/virtualNetworks
  apiVersion: 2023-05-01
  name: '${vnetName}'
  location: '${location}'
  properties:
    addressSpace:
      addressPrefixes:
        - '${addressPrefix}'
    subnets:
      - name: app-subnet
        properties:
          addressPrefix: '${subnetAppPrefix}'
      - name: db-subnet
        properties:
          addressPrefix: '${subnetDbPrefix}'

# -----------------------------
# VIS (Virtual Instance for SAP)
# -----------------------------
 resource Microsoft.Workloads/sapVirtualInstances
  apiVersion: 2023-04-01
  name: '${visName}'
  location: '${location}'
  properties:
    environment: NonProd
    sapProduct: S4HANA
    configuration:
      infrastructureConfiguration:
        appResourceGroup: 'SAP_RG'
        databaseResourceGroup: 'SAP_RG'
        networkConfiguration:
          isSecondaryIpEnabled: false
          virtualNetworkId: 'resourceId('Microsoft.Network/virtualNetworks', ${vnetName})'
          appSubnetId: 'resourceId('Microsoft.Network/virtualNetworks/subnets', ${vnetName}, 'app-subnet}'
          dbSubnetId: 'resourceId('Microsoft.Network/virtualNetworks/subnets', ${vnetName}, 'db-subnet}'
      osConfiguration:
        osType: Linux
        sshKeyPairName: ""
    deploymentType: SingleServer

# -----------------------------
# HANA Database VM
# -----------------------------
 resource Microsoft.Compute/virtualMachines
  apiVersion: 2023-03-01
  name: '${hanaVmName}'
  location: '${location}'
  dependsOn:
    - 'resourceId('Microsoft.Network/virtualNetworks', ${vnetName})'
  properties:
    hardwareProfile:
      vmSize: '${hanaVmSize}'
    osProfile:
      computerName: '${hanaVmName}'
      adminUsername: '${adminUsername}'
      adminPassword: '${adminPassword}'
      linuxConfiguration:
        disablePasswordAuthentication: false
    storageProfile:
      imageReference:
        publisher: suse
        offer: sles-sap-15-sp5
        sku: gen2
        version: latest
    networkProfile:
      networkInterfaces:
        - id: 'resourceId('Microsoft.Network/networkInterfaces', concat(${hanaVmName}, '-nic'))'

# -----------------------------
# NIC for HANA VM
# -----------------------------
 resource Microsoft.Network/networkInterfaces
  apiVersion: 2023-05-01
  name: 'concat(${hanaVmName}, '-nic}'
  location: '${location}'
  dependsOn:
    - 'resourceId('Microsoft.Network/virtualNetworks', ${vnetName})'
  properties:
    ipConfigurations:
      - name: ipconfig1
        properties:
          privateIPAllocationMethod: Dynamic
          subnet:
            id: 'resourceId('Microsoft.Network/virtualNetworks/subnets', ${vnetName}, 'db-subnet}'

