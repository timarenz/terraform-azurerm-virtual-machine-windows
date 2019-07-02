locals {
  common_tags = {
    environment = var.environment_name
    owner       = var.owner_name
    ttl         = var.ttl
  }
  all_tags = merge(local.common_tags, var.tags == null ? {} : var.tags)
}

resource "random_string" "admin_password" {
  length      = 16
  special     = false
  min_upper   = 1
  min_lower   = 1
  min_numeric = 1
}

data "azurerm_platform_image" "windows" {
  location  = var.region
  publisher = "MicrosoftWindowsServer"
  offer     = "WindowsServer"
  sku       = "2016-Datacenter"
}

resource "azurerm_public_ip" "main" {
  count               = var.public_ip ? 1 : 0
  name                = "${var.environment_name}-${var.vm_name}-public-ip"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"

  tags = local.all_tags
}

# resource "azurerm_network_security_group" "main" {
#   name                = "${var.environment_name}-${var.vm_name}-nsg"
#   location            = var.region
#   resource_group_name = var.resource_group_name

#   tags = local.all_tags
# }

# resource "azurerm_network_security_rule" "winrm" {
#   name                        = "${var.environment_name}-${var.vm_name}-nsr-winrm"
#   priority                    = 100
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_address_prefix       = "*"
#   source_port_range           = "*"
#   destination_address_prefix  = "*"
#   destination_port_range      = "5985"
#   resource_group_name         = var.resource_group_name
#   network_security_group_name = azurerm_network_security_group.main.name
# }

# resource "azurerm_network_security_rule" "rdp" {
#   name                        = "${var.environment_name}-${var.vm_name}-nsr-rdp"
#   priority                    = 101
#   direction                   = "Inbound"
#   access                      = "Allow"
#   protocol                    = "Tcp"
#   source_address_prefix       = "*"
#   source_port_range           = "*"
#   destination_address_prefix  = "*"
#   destination_port_range      = "3389"
#   resource_group_name         = var.resource_group_name
#   network_security_group_name = azurerm_network_security_group.main.name
# }

resource "azurerm_network_interface" "main" {
  name                = "${var.environment_name}-${var.vm_name}-interface"
  location            = var.region
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "${var.environment_name}-${var.vm_name}-private-ip"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip ? azurerm_public_ip.main[0].id : null
  }

  # network_security_group_id = azurerm_network_security_group.main.id
  network_security_group_id = var.network_security_group_id != null ? var.network_security_group_id : null

  tags = local.all_tags
}

resource "azurerm_virtual_machine" "main" {
  name                  = "${var.environment_name}-${var.vm_name}"
  location              = var.region
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.main.id]
  vm_size               = var.vm_size

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = data.azurerm_platform_image.windows.publisher
    offer     = data.azurerm_platform_image.windows.offer
    sku       = data.azurerm_platform_image.windows.sku
    version   = data.azurerm_platform_image.windows.version
  }

  storage_os_disk {
    name          = "${var.environment_name}-${var.vm_name}-osdisk"
    create_option = "FromImage"
  }

  os_profile {
    computer_name  = var.vm_name
    admin_username = var.admin_username
    admin_password = var.admin_password == null ? random_string.admin_password.result : var.admin_password
  }

  os_profile_windows_config {
    provision_vm_agent = true
    winrm {
      protocol = "HTTP"
    }
    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "AutoLogon"
      content      = "<AutoLogon><Password><Value>${var.admin_password == null ? random_string.admin_password.result : var.admin_password}</Value></Password><Enabled>true</Enabled><LogonCount>1</LogonCount><Username>${var.admin_username}</Username></AutoLogon>"
    }

    additional_unattend_config {
      pass         = "oobeSystem"
      component    = "Microsoft-Windows-Shell-Setup"
      setting_name = "FirstLogonCommands"
      content      = "<FirstLogonCommands><SynchronousCommand><CommandLine>powershell.exe -sta -ExecutionPolicy Unrestricted -Command Enable-PSRemoting -Force; Set-Item WSMan:\\localhost\\Service\\AllowUnencrypted -value $true -force; Set-Item WSMan:\\localhost\\Service\\Auth\\Basic -Value $true -force</CommandLine><Description>Enable WinRM</Description><Order>1</Order></SynchronousCommand></FirstLogonCommands>"
    }
  }
  #; Set-NetFirewallRule -Name WINRM-HTTP-In-TCP -RemoteAddress Any
  tags = local.all_tags
}

# resource "azurerm_virtual_machine_extension" "winrm" {
#   name                 = "${azurerm_virtual_machine.main.name}-winrm"
#   location             = var.region
#   resource_group_name  = var.resource_group_name
#   virtual_machine_name = "${azurerm_virtual_machine.main.name}"
#   publisher            = "Microsoft.Azure.Extensions"
#   type                 = "CustomScript"
#   type_handler_version = "2.0"

#   settings = <<SETTINGS
#     {
#         "commandToExecute": "powershell -ExecutionPolicy Unrestricted -Command Enable-PSRemoting -Force"
#     }
# SETTINGS

#   tags = local.all_tags
# }
