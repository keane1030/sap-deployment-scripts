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
  name: "[parameters('vnetName')]"
  location: "[parameters('location')]"
  properties:
    addressSpace:
      addressPrefixes:
        - "[parameters('addressPrefix')]"
    subnets:
      - name: app-subnet
        properties:
          addressPrefix: "[parameters('subnetAppPrefix')]"
      - name: db-subnet
        properties:
          addressPrefix: "[parameters('subnetDbPrefix')]"

# -----------------------------
# VIS (Virtual Instance for SAP)
# -----------------------------
 resource Microsoft.Workloads/sapVirtualInstances
  apiVersion: 2023-04-01
  name: "[parameters('visName')]"
  location: "[parameters('location')]"
  properties:
    environment: NonProd
    sapProduct: S4HANA
    configuration:
      infrastructureConfiguration:
        appResourceGroup: "[resourceGroup().name]"
        databaseResourceGroup: "[resourceGroup().name]"
        networkConfiguration:
          isSecondaryIpEnabled: false
          virtualNetworkId: "[resourceId('Microsoft.Network/virtualNetworks', parameters('vnetName'))]"
          appSubnetId: "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('vnetName'), 'app-subnet')]"
          dbSubnetId: "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('vnetName'), 'db-subnet')]"
      osConfiguration:
        osType: Linux
        sshKeyPairName: ""
    deploymentType: SingleServer

# -----------------------------
# HANA Database VM
# -----------------------------
 resource Microsoft.Compute/virtualMachines
  apiVersion: 2023-03-01
  name: "[parameters('hanaVmName')]"
  location: "[parameters('location')]"
  dependsOn:
    - "[resourceId('Microsoft.Network/virtualNetworks', parameters('vnetName'))]"
  properties:
    hardwareProfile:
      vmSize: "[parameters('hanaVmSize')]"
    osProfile:
      computerName: "[parameters('hanaVmName')]"
      adminUsername: "[parameters('adminUsername')]"
      adminPassword: "[parameters('adminPassword')]"
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
        - id: "[resourceId('Microsoft.Network/networkInterfaces', concat(parameters('hanaVmName'), '-nic'))]"

# -----------------------------
# NIC for HANA VM
# -----------------------------
 resource Microsoft.Network/networkInterfaces
  apiVersion: 2023-05-01
  name: "[concat(parameters('hanaVmName'), '-nic')]"
  location: "[parameters('location')]"
  dependsOn:
    - "[resourceId('Microsoft.Network/virtualNetworks', parameters('vnetName'))]"
  properties:
    ipConfigurations:
      - name: ipconfig1
        properties:
          privateIPAllocationMethod: Dynamic
          subnet:
            id: "[resourceId('Microsoft.Network/virtualNetworks/subnets', parameters('vnetName'), 'db-subnet')]"

