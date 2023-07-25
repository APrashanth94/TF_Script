
provider "azurerm" {
subscription_id = "6d66f145-f638-4b06-97ef-73907ded2f53"
client_id = "e9548e42-9279-4d50-abb0-7621fce93121"
client_secret = "xaf8Q~GQYgwqlactQQ5UutBCjEDWRoW2pIHUfc~R"
tenant_id = "774b1806-c3a6-41d9-acaf-71930b06b2e4"
features {}
}

resource "azurerm_resource_group" "resourcegroup" {
  name     = "CUR-TEST-SYSLOG-WE-RG-TEST"
  location = "West Europe"
}

resource "azurerm_virtual_network" "Vnet" {
  name                = "CUR-TEST-SYSLOG-WE-VNET-TEST"
  address_space       = ["10.0.0.0/18"]
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
}

resource "azurerm_subnet" "Az-Subnet" {
  name                 = "CUR-TEST-SYSLOG-WE-SNET-TEST"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.Vnet.name
  address_prefixes     = ["10.0.3.0/28"]
}
resource "azurerm_public_ip" "publicip" {
  name                = "CUR-TEST-PublicIP"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "networkInterface" {
  name                = "CUR-TEST-SYSLOG-WE-NIC-TEST"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.Az-Subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

output "public_ip_address" {
  value = azurerm_public_ip.publicip.ip_address
  }

resource "tls_private_key" "CUR_ssh" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "azurerm_network_security_group" "Az-NSG" {
  name                = "CUR-TEST-SYSLOG-WE-NSG-TEST"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  security_rule {
    name                       = "CUR-TEST-AllowBastionRDP-WE-NSG-TEST"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range    =  "22-5557"
    source_address_prefixes      = ["10.80.32.64/26"] 
    destination_address_prefix = "10.0.0.0/18"
  }
   security_rule {
    name                       = "CUR-TEST-AllowSyslog-WE-NSG-TEST"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     =  "22-5557"
    source_address_prefixes    = ["10.0.0.0/8"] 
    destination_address_prefix = "10.0.0.0/18"
  }
   security_rule {
    name                       = "CUR-TEST-DenyAll-WE-NSG-TEST"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     =  "22-5557"
    source_address_prefix    = "*" 
    destination_address_prefix = "10.0.0.0/18"
  }

  

   tags = {
    environment = "Production"
  }
}

resource "azurerm_linux_virtual_machine" "Az-VM" {
  name                = "AZWE-SYSLOG-TEST"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  size                = "Standard_B2ms"
  admin_username      = "rootadmin"
 disable_password_authentication = true
  network_interface_ids = [
    azurerm_network_interface.networkInterface.id,
  ]

   admin_ssh_key {
    username   = "rootadmin"
    public_key = tls_private_key.CUR_ssh.public_key_openssh 
    // path     = "/home/rootadmin/.ssh/authorized_keys"
  }
    os_disk {
    name = "CUR-TEST-SYSLOG-WE-OSDISK-TEST"
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "9_2"
    version   = "latest"
  }
}
