provider "azurerm" {}
  features {}
  }

locals {
    nsg_inbound_rules = { for idx, security_rule in var.nsg_inbound_rules : security_rule.name => {
        idx : idx,
        security_rule : security_rule,
        }
    }
}

data "azurerm_resource_group" "rg" {
    name = var.environment.resource_group_name
}

data "azurerm_resource_group" "hub_rg" {
    count                       = var.use_hub_vnet ? 1 : 0
    name                        = var.hub_vnet_rg

}

data "azurerm_virtual_network" "vnet" {
    count                       = var.use_hub_vnet ? 1 : 0
    name                        = var.vmss[var.environment].hub_vnet_name
    resource_group_name         = (var.hub_vnet == true ? data.azurerm_resource_group.hub_rg : data.azurerm_resource_group.rg)
}

resource "azurerm_virtual_network" "vnet" {
    count                       = var.use_hub_vnet ? 0 : 1
    name                        = var.vnet_name
}

data "azurerm_subnet" "subnet" {
    count                       = var.use_hub_vnet ? 1 : 0 
    name                        = var.use_hub_vnet ? var.vmss[var.environment].hub_subnet_name : var.vmss[var.environment].subnet_name
    resource_group_name         = (var.use_hub_vnet ? data.azurerm_resource_group.hub_rg : data.azurerm_resource_group.rg)
    virtual_network_name        = (var.use_hub_vnet ? data.azurerm_virtual_network.vnet.name : azurerm_virtual_network.vnet.name)
}

resource "azurerm_subnet" "subnet" {
    count                       = var.use_hub_vnet ? 0 : 1
    name                        = var.vmss[var.environment].subnet_name
    resource_group_name         = = (var.use_hub_vnet ? data.azurerm_resource_group.hub_rg : data.azurerm_resource_group.rg)

}

data "azurerm_network_security_group" "hub_vnet" {
    count                       = var.use_hub_vnet ? 1 : 0
    name                        = var.hub_vnet_nsg
    resource_group_name         = data.azurerm_resource_group.hub_rg
}


resource "random_password" "passwd" {
    count                       = (var.os_flavor == "linux" && var.disable_password_authentication == false && var.admin_password == null ? 1: (var.os_flavor == "windows" && var.admin_password == null ? 1 : 0))
    length                      = var.random_password_length
    min_upper                   = 4
    min_lower                   = 2
    min_numeric                 = 4
    special                     = true

    keepers {
        admin_password = var.vmscaleset_name
    }
}

resource "azurerm_network_security_group" "nsg" {
    count                       = var.use_hub_vnet ? 0 : 1
    name                        = lower("nsg_${var.vmscaleset_name}_${data.azurerm_resource_group.rg.location}_${var.vmss[var.environment].loc_code}")
    resource_group_name         = data.azurerm-resource_group.rg.name
    location                    = data.azurerm_resource_group.rg.location

    lifecycle {
        ignore_changes = [
            tags,
        ]
    }
}

resource "azurerm_network_security_rule" "nsg_rule" {
    for_each                                            = {for k, v in local.nsg_inbound_rules : k => v if k!= null }
    name                                                = each.key
    priority                                            = 100 * (each.value.idx + 1)
    direction                                           = "Inbound"
    access                                              = "Allow"
    protocol                                            = each.value.security_rule.protocol
    source_port_range                                   = "*"
    destination_port_range                              = each.value.security_rule.destination_port_range
    source_address_prefix                               = each.value.security_rule.source_address_prefix
    destination_address_prefix                          = var.use_hub_vnet ? element(concat(data.azurerm_subnet.subnet.address_prefixes, [""], 0) : element(concat(azurerm_subnet.subnet.address_prefixes, [""]), 0)
    description                                         = "Inbound_Port_${each.value.security_rule.destination_port_range}"
    resource_group_name                                 = var.use_hub_vnet ? data.azurerm_resource_group.rg.name : data.azurerm_resource_group.hub_rg.name
    network_security_group_name                         = var.use_hub_vnet ? data.azurerm_network_security_group.hub_vnet.name : azurerm_network_security_group.nsg.name

}

#---------------------------------------
# Linux Virutal machine scale set
#---------------------------------------

resource "azurerm_linux_virtual_machine_scale_set" "linux_vmss" {
    count                                              = var.os_flavor == "linux" ? 1 : 0
    name                                               = lower("${data.azurerm_resource_group.rg.location}_${var.vmss[var.environment].code}_${var.vmscaleset_name}_${count.index + 1}")
    resource_group_name                                = data.azurerm_resource_group.rg.name
    location                                           = data.azurerm_resource_group.rg.location
    sku                                                = var.vmss[var.environment].sku[0] # SKU's 0-5 SKU 0 or SKU 1 is recommended for Linux (Standard_D1_v2 or Standard_D2_v2)
    instances                                          = var.vmss[var.environment].instances
    admin_username                                     = var.admin_username
    admin_password                                     = var.disable_password_authentication == false && var.admin_password == null ? element(concat(random_password.passwd.*.result, [""]), 0) : var.admin_password
    custom_data                                        = var.custom_data
    disable_password_authentication                    = var.disable_password_authentication
    overprovision                                      = var.overprovision
    encryption_at_host_enabled                         = var.enable_encryption
    provision_vm_agent                                 = true
    scale_in_policy                                    = "OldestVM"
    single_placement_group                             = true
    source_image_id                                    = var.source_image_id != null ? var.source_image_id : null
    tags                                               = merge({ "resourcename" = format("vm%s%s", lower(replace(var.vmscaleset_name, "/[[:^alnum:]]/", "")), count.index + 1) }, var.tags, )

    dynamic "admin_ssh_key" {
        for_each = var.disable_password_authentication ? [1] : []
        content {
            username    = var.admin_username
            public_key  = var.admin_ssh_key_data == null ? tls_private_key.rsa[0].public_key_openssh : file(var.admin-ssh_key_data)
        }
    }


    dynamic "source_image_reference" {
        for_each = var.source_image_id != null ? [] : [1]
        content {
            publisher       = var.custom_image != null ? var.custom_image["publisher"] : var.linux_distribution_list[lower(var.linux_distribution_name)]["publisher"]
            offer           = var.custom_image != null ? var.custom_image["offer"] : var.linux_distribution_list[lower(var.linux_distribution_name)]["offer"]
            sku             = var.custom_image != null ? var.custom_image["sku"] : var.linux_distribution_list[lower(var.linux_distribution_name)]["sku"]
            version         = var.custom_image != null ? var.custom_image["version"] : var.linux_distribution_list[lower(var.linux_distribution_name)]["version"]
        }
    }

    os_disk {
    storage_account_type      = var.os_disk_storage_account_type
    caching                   = var.os_disk_caching
    disk_encryption_set_id    = var.disk_encryption_set_id
    disk_size_gb              = var.disk_size_gb
    write_accelerator_enabled = var.enable_os_disk_write_accelerator
  }

    dynamic "data_disk" {
      for_each = var.additional_data_disks
      content {
        lun                  = data_disk.key
        disk_size_gb         = data_disk.value
        caching              = "ReadWrite"
        create_option        = "Empty"
        storage_account_type = var.additional_data_disks_storage_account_type
    }


  network_interface {
    name                          = lower("nic-${format("vm%s%s", lower(replace(var.vmscaleset_name, "/[[:^alnum:]]/", "")), count.index + 1)}")
    primary                       = true
    dns_servers                   = var.dns_servers
    enable_ip_forwarding          = var.enable_ip_forwarding
    enable_accelerated_networking = var.enable_accelerated_networking
    network_security_group_id     = var.existing_network_security_group_id == null ? azurerm_network_security_group.nsg.0.id : var.existing_network_security_group_id
  
    ip_configuration {
        name                     = lower("ipconfig-${join("_", [data.azurerm_resource_group.rg.location, var.vmss[var.environment].code_var, var.vmscaleset_name, count.index + 1])}")
        primary                  = true
        subnet_id                = var.hub_vnet ? data.azurerm_subnet.subnet.id : azurerm_subnet.subnet.id

    }
  }
}

#---------------------------------------
# Windows Virutal machine scale set
#---------------------------------------
resource "azurerm_windows_virtual_machine-scale_set" "winsrv_vmss" {
    count                                              = var.os_flavor == "windows" ? 1 : 0
    name                                               = lower("${var.location_code}_${var.vmss[var.environment].code_var}_${var.vmscaleset_name}_${count.index + 1}")
    resource_group_name                                = data.azurerm_resource_group.rg.name
    location                                           = data.azurerm_resource_group.rg.location
    sku                                                = var.vmss[var.environment].sku[3] #Recommend SKU 3, 4 or 5 for Windows (Standard_D3_v3, Standard_D4_v3, Standard_D8_v3)
    instances                                          = var.vmss[var.environment].instances
    admin_username                                     = var.admin_username
    admin_password                                     = var.admin_password == null ? element(concat(random_password.passwd.*.result, [""]), 0) : var.admin_password
    custom_data                                        = var.custom_data
    overprovision                                      = var.overprovision
    encryption_at_host_enabled                         = var.enable_encryption
    provision_vm_agent                                 = true
    scale_in_policy                                    = "OldestVM"
    single_placement_group                             = true
    source_image_id                                    = var.source_image_id != null ? var.source_image_id : null
    upgrade_mode                                       = var.os_upgrade_mode
    timezone                                           = var.vm_time_zone
    tags                                               = merge({ "resourcename" = format("vm%s%s", lower(replace(var.vmscaleset_name, "/[[:^alnum:]]/", "")), count.index + 1) }, var.tags, )

  dynamic "source_image_reference" {
    for_each = var.source_image_id != null ? [] : [1]
    content {
      publisher = var.custom_image != null ? var.custom_image["publisher"] : var.windows_distribution_list[lower(var.windows_distribution_name)]["publisher"]
      offer     = var.custom_image != null ? var.custom_image["offer"] : var.windows_distribution_list[lower(var.windows_distribution_name)]["offer"]
      sku       = var.custom_image != null ? var.custom_image["sku"] : var.windows_distribution_list[lower(var.windows_distribution_name)]["sku"]
      version   = var.custom_image != null ? var.custom_image["version"] : var.windows_distribution_list[lower(var.windows_distribution_name)]["version"]
    }
  }
    
  os_disk {
    storage_account_type      = var.os_disk_storage_account_type
    caching                   = var.os_disk_caching
    disk_encryption_set_id    = var.disk_encryption_set_id
    disk_size_gb              = var.disk_size_gb
    write_accelerator_enabled = var.enable_os_disk_write_accelerator
  }

  dynamic "data_disk" {
    for_each = var.additional_data_disks
    content {
      lun                  = data_disk.key
      disk_size_gb         = data_disk.value
      caching              = "ReadWrite"
      create_option        = "Empty"
      storage_account_type = var.additional_data_disks_storage_account_type
    }
  }

  network_interface {
    name                          = lower("nic-${format("vm%s%s", lower(replace(var.vmscaleset_name, "/[[:^alnum:]]/", "")), count.index + 1)}")
    primary                       = true
    dns_servers                   = var.dns_servers
    enable_ip_forwarding          = var.enable_ip_forwarding
    enable_accelerated_networking = var.enable_accelerated_networking
    network_security_group_id     = var.existing_network_security_group_id == null ? azurerm_network_security_group.nsg.0.id : var.existing_network_security_group_id
  
    ip_configuration {
        name                     = lower("ipconfig-${join("_", [data.azurerm_resource_group.rg.location, var.vmss[var.environment].code_var, var.vmscaleset_name, count.index + 1])}")
        primary                  = true
        subnet_id                = var.hub_vnet ? data.azurerm_subnet.subnet.0.id : azurerm_subnet.subnet.0.id

    }
  }
}

#-----------------------------------------------
# Auto Scaling for Virtual machine scale set
#-----------------------------------------------
resource "azurerm_monitor_autoscale_setting" "auto" {
  count               = var.enable_autoscale_for_vmss ? 1 : 0
  name                = lower("auto-scale-set-${var.vmscaleset_name}")
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  target_resource_id  = var.os_flavor == "windows" ? azurerm_windows_virtual_machine_scale_set.winsrv_vmss.0.id : azurerm_linux_virtual_machine_scale_set.linux_vmss.0.id

  profile {
    name = "default"
    capacity {
      default = var.vmss[var.environment].instances
      minimum = var.minimum_instances_count == null ? var.vmss[var.environment].instances : var.minimum_instances_count
      maximum = var.maximum_instances_count
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = var.os_flavor == "windows" ? azurerm_windows_virtual_machine_scale_set.winsrv_vmss.0.id : azurerm_linux_virtual_machine_scale_set.linux_vmss.0.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = var.scale_out_cpu_percentage_threshold
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = var.scaling_action_instances_number
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = var.os_flavor == "windows" ? azurerm_windows_virtual_machine_scale_set.winsrv_vmss.0.id : azurerm_linux_virtual_machine_scale_set.linux_vmss.0.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = var.scale_in_cpu_percentage_threshold
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = var.scaling_action_instances_number
        cooldown  = "PT1M"
      }
    }
  }
}