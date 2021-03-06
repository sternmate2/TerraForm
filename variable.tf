#############################################################################
# VARIABLES
#############################################################################

variable "resource_group_name" {
  type = string
}

variable "location" {
  type    = string
  default = "eastus"
}


variable "vnet_cidr_range" {
  type    = string
  default = "80.0.0.0/16"
}

variable "subnet_prefixes" {
  type    = list(string)
  default = ["80.0.0.0/24", "80.0.1.0/24"]
}

variable "subnet_names" {
  type    = list(string)
  default = ["Sub1", "Sub2"]
}

variable "env" {
  type    = string
}

variable "script"{
    type = string
    default = "script.sh"
}

# resource "azurerm_key_vault_key" "ShaharMyKeyVault" {
#   # (resource arguments)
# }