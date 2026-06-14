@description('Deployment location')
param location string = 'switzerlandnorth'

@description('Name of the SAP HANA VM')
param vmName string = 'sap-hana-sles-01'

@description('Admin username for the VM')
param adminUsername string = 'azureuser'

@secure()
@description('Admin password for the VM')
param adminPassword string = ''
param hanaStorageAccountName string = 'hanamedia${uniqueString(resourceGroup().id)}'
param containerName string = 'hana'
param imagePublisher string = 'SUSE'
@description('URI of the custom script for OS prep + HANA install')
param customScriptFileUri string = 'https://${hanaStorageAccountName}.blob.core.windows.net/${containerName}/install-hana-sles.sh'


//
// Custom Script Extension for SLES OS prep + HANA install
//

resource vmCustomScript 'Microsoft.Compute/virtualMachines/extensions@2023-03-01' = {
  name: '${vmName}/customScriptForLinux'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        customScriptFileUri
      ]
      commandToExecute: 'bash install-hana-sles.sh'
    }
  }
}

