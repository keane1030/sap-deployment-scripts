parameters:
  location:
    type: string
    defaultValue: switzerlandnorth
  vnetName:
    type: string
    defaultValue: sap-vnet
  addressPrefix:
    type: string
    defaultValue: 10.10.0.0/16
  subnetAppPrefix:
    type: string
    defaultValue: 10.10.1.0/24
  subnetDbPrefix:
    type: string
    defaultValue: 10.10.2.0/24
  visName:
    type: string
    defaultValue: sap-vis
  hanaVmName:
    type: string
    defaultValue: hana-vm
  hanaVmSize:
    type: string
    defaultValue: Standard_E32ds_v5
  adminUsername:
    type: string
    defaultValue: brian
  adminPassword:
    type: secureString
    defaultValue: "P@ssw0rd1234"

resources:

# -----------------------------
# Virtual Network + Subnets
# -----------------------------
- type: Microsoft.Network/virtualNetworks
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
- type: Microsoft.Workloads/sapVirtualInstances
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
- type: Microsoft.Compute/virtualMachines
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
- type: Microsoft.Network/networkInterfaces
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

