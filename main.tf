
#############################################################################
# RESOURCES
#############################################################################

resource "azurerm_storage_account" "test" {
  name                     = "shahars"
  resource_group_name      = azurerm_resource_group.test.name
  location                 = azurerm_resource_group.test.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "test" {
  name                  = "tfstate"
  storage_account_name  = azurerm_storage_account.test.name
  container_access_type = "private"
}


#############################################################################
# RESOURCES

resource "azurerm_resource_group" "test" {
  name     = "${var.resource_group_name}"
  location = var.location
}

module "test" {
  source              = "Azure/vnet/azurerm"
  version             = "~> 2.0"
  resource_group_name = azurerm_resource_group.test.name
  vnet_name           = "var.resource_group_name-${terraform.workspace}"
  address_space       = [var.vnet_cidr_range]
  subnet_prefixes     = var.subnet_prefixes
  subnet_names        = var.subnet_names
  nsg_ids             = {}


  depends_on = [azurerm_resource_group.test]
}

#############################################################################
# NetWork 
#############################################################################


resource "azurerm_network_interface" "test" {
  count               = "${terraform.workspace == "prod" ? 2 : 1}"
  name                = "VM${count.index}-nic-${terraform.workspace}"
  location            = var.location
  resource_group_name = azurerm_resource_group.test.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = element(module.test.vnet_subnets, 0)
    private_ip_address_allocation = "Dynamic"
  }
}

  
#############################################################################
# Machines
#############################################################################

#############################################################################
resource "azurerm_virtual_machine" "test" {
  count = "${terraform.workspace == "prod" ? 2 : 1}"
  name                = "MYVM-${count.index}-${terraform.workspace}"
  resource_group_name = azurerm_resource_group.test.name
  location            = var.location
  vm_size               = "Standard_DS1_v2"
  network_interface_ids = [azurerm_network_interface.test[count.index].id]
  availability_set_id   = azurerm_availability_set.test.id
 
 os_profile {
    computer_name  = "hostname"
    admin_username = "shahars"
    admin_password = "ss310379"
  }

  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = data.azurerm_key_vault_secret.secret.value
       path     = "/home/shahars/.ssh/authorized_keys"
    }   
  }   

  storage_os_disk {
    name              = "myosdisk${count.index}-${terraform.workspace}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  
  # provisioner "file" {
  #   source      = "/home/shahars/ShaharTF/test.txt"
  #   destination = "/home/shahars/test.txt"
  # }
  # connection {
  #   type = "ssh"
  #   user = "shahars"
  #   host = azurerm_network_interface.test[count.index].private_ip_address
  #   private_key = file("~/.ssh/id_rsa.pub")
  #   agent    = false
  # }


}
 
 
 

   
  
#   admin_ssh_key {
#       username       = "azureuser"
#       public_key     = file("~/.ssh/id_rsa.pub")    
#   }
  
###########################################################################################################################


  
  # # provisioner "file" {
  #     connection {
  #       type = "ssh"
  #       user = "shahars"
  #       host = azurerm_lb.LB.id
  #       agent    = false
  #       timeout  = "10m"
  #     }
  #     source = "/home/shahars/.ssh/id_rsa"
  #     destination = "/home/shahars/.ssh/id_rsa"
  #   }




 resource "azurerm_virtual_machine_extension" "test" {
   count = "${terraform.workspace == "prod" ? 2 : 1}"
   name                = "hostname-${count.index}"
   virtual_machine_id   = [azurerm_virtual_machine.test[count.index].id]
   publisher            = "Microsoft.Azure.Extensions"
   type                 = "CustomScript"
   type_handler_version = "2.0"

   protected_settings = <<PROT
    {
        "script": "${base64encode(file(var.script))}"
    }
    PROT
 

#    settings = <<SETTINGS
# #      {
# # "commandToExecute": "bash script.sh"
# #      }
# #    SETTINGS  
}



# git clone git@github.com:eToro-bootcamp/BootcapProject.git

#############################################################################
# Peering
#############################################################################


data "azurerm_virtual_network" "shaharbastion" {
  name                = "bastion1"
  resource_group_name = "bastion1"
}

data "azurerm_resource_group" "shaharpeering" {
   name                = "bastion1"
}


resource "azurerm_virtual_network_peering" "shaharbastion" {
  name                      = "peertobastion1"
  resource_group_name       = azurerm_resource_group.test.name
  virtual_network_name      = module.test.vnet_name
  remote_virtual_network_id = data.azurerm_virtual_network.shaharbastion.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit = false
}

resource "azurerm_virtual_network_peering" "shaharpeering" {
  name                      = "peertoShaharTF"
  resource_group_name       = data.azurerm_resource_group.shaharpeering.name
  virtual_network_name      = data.azurerm_virtual_network.shaharbastion.name
  remote_virtual_network_id = module.test.vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit = false
}

#############################################################################
# LoadBalncer + BackEndPool + LB rules
#############################################################################

resource "azurerm_public_ip" "LBIP" {
  name                = "PublicIPForLB"
  location            = var.location
  resource_group_name = azurerm_resource_group.test.name 
  allocation_method   = "Static"
}

resource "azurerm_lb" "LB" {
  name                = "TestLoadBalancer"
  location            = var.location
  resource_group_name = azurerm_resource_group.test.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.LBIP.id 
  }
}

resource "azurerm_lb_backend_address_pool" "test" {
  loadbalancer_id = azurerm_lb.LB.id
  name            = "BackEndAddressPool"
}

resource "azurerm_network_interface_backend_address_pool_association" "test" {
   count = "${terraform.workspace == "production" ? 2 : 1}"
   network_interface_id    = [azurerm_network_interface.test[count.index].id]
   ip_configuration_name   = "BackEnd"
   backend_address_pool_id = azurerm_lb_backend_address_pool.test.id 
   }

resource "azurerm_lb_probe" "test" {
  resource_group_name = azurerm_resource_group.test.name
  loadbalancer_id     = azurerm_lb.LB.id
  name                = "TCP-running-probe"
  port                = 8080
}

resource "azurerm_lb_rule" "test" {
  resource_group_name            = azurerm_resource_group.test.name
  loadbalancer_id                = azurerm_lb.LB.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  probe_id                       = azurerm_lb_probe.test.id
  backend_port                   = 8080
  backend_address_pool_id        = azurerm_lb_backend_address_pool.test.id
  frontend_ip_configuration_name = "PublicIPAddress"
}

resource "azurerm_availability_set" "test" {
  name                = "example-aset"
  location            = azurerm_resource_group.test.location
  resource_group_name = azurerm_resource_group.test.name

}

#############################################################################
# Security 
#############################################################################

# Create Network Security Group and rule
resource "azurerm_network_security_group" "test" {
    name                = "NSG"
    location            = azurerm_resource_group.test.location
    resource_group_name = azurerm_resource_group.test.name

    security_rule {
        name                       = "port80"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "34.99.159.243/32"
        destination_address_prefix = "*"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    count = "${terraform.workspace == "production" ? 2 : 1}"
    network_interface_id      = [azurerm_network_interface.test[count.index].id]
    network_security_group_id = azurerm_network_security_group.test.id
}


# data "azurerm_public_ip" "test" {
#   name                = azurerm_public_ip.LBIP.name
#   resource_group_name = var.resource_group_name
# }


# resource "null_resource" "readcontentfile" {
#   provisioner "local-exec" {
#    command = "cat ~/.ssh/id_rsa >> test2.txt"
#   }
# }


# resource "null_resource" remoteExecProvisionerWFolder {

#   provisioner "file" {
#     source      = "/home/shahars/ShaharTF/test2.txt"
#     destination = "/home/shahars/.ssh/test.txt"
#   }
#   connection {
#     bastion_host = "13.90.255.58" 
#     host         = "80.0.0.4"
#     user         = "shahars"
#     private_key  = "${file("~/.ssh/id_rsa")}"
#   }

# }
#############################################################################
# OutPut For Debug
#############################################################################


# output "secret_value" {
#   value = data.azurerm_key_vault_secret.test.value
# }

data "azurerm_key_vault" "kv" {
  name                = "SternMateKeyVault"
  resource_group_name = "ShaharTF"
}
data "azurerm_key_vault_secret" "secret" {
  name         = "PublicKey"
  key_vault_id = data.azurerm_key_vault.kv.id
}




