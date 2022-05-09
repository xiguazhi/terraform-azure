variable "module_depends_on" {
    type = any
    description = "(optional) A list of external resources the module depends_on"
    default = []
}

variable "module_enabled" {
    type = bool
    description = "(optional) Whether to create resources within the module or not. Default is true"
    default = true
}

variable "use_hub_vnet" {
    type = bool
    description = "whether or not we create the VM on hub vnet or its own vnet."
    default = false
}

variable "hub_vnet_rg" {
    description = "The Resource Group linked to the Hub VNET, this should never change"
    default = null 
}

variable "environment" {
    type = list
    default = ["dev","qa","stage","prod"]
}

variable "vnet_name" {
    type = string
    description = "VNET name if not using Hub vnet"
    default = join("-", [var.vmss[var.environment].loc_code, var.vmss[var.environment].env_code, var.vmscale_set_name], "VNET")
}

variable "subnet_name" {
    type = string
    description = "subnet name if not using Hub subnet"
    default = join("-", [var.vmss[var.environment].loc_code, var.vmss[var.environment].env_code, var.vmscale_set_name], "SUBN")
}


variable "hub_vnet_name" {
    type = string
    description = "Name of VNET inside of Hub, this should never change"
    default = "NA26-P-Hub-VNET"
}

variable "hub_subnet_name" {
    type = string
    description = "Name of Subnet inside of Hub, this should never change"
    default = "NA26-P-HUB-SUBN"
}


variable "vmss" {
    type = map(object({
             loc_code        = string
             env_code        = string
             sku             = list
             instances       = string
           }))
    default = {
        dev = {
            loc_code = "NA26"
            env_code = "D"
            sku      = ["Standard_D1_v2","Standard_D2_v2", "Standard_D3_v2", "Standard_D2_v3", "Standard_D4_v3", "Standard_D8_v3"]
        }
        QA = {
            loc_code = "NA26"
            env_code = "Q"
            sku      = ["Standard_D1_v2","Standard_D2_v2", "Standard_D3_v2", "Standard_D2_v3", "Standard_D4_v3", "Standard_D8_v3"]
        }
        Stage = {
            loc_code = "NA26"
            env_code = "S"
            sku      = ["Standard_D1_v2","Standard_D2_v2", "Standard_D3_v2", "Standard_D2_v3", "Standard_D4_v3", "Standard_D8_v3"]
        }
        Prod = {
            loc_code = "NA26"
            env_code = "D"
            sku      = ["Standard_D1_v2","Standard_D2_v2", "Standard_D3_v2", "Standard_D2_v3", "Standard_D4_v3", "Standard_D8_v3"]
        }
    }
}


variable "os_flavor" {
    type = string
    desscription   = "Operating System for scaleset"
    default = "linux"
}

variable "vmscale_set_name" {
    type = string
    description =  "Name of Azure VM Scale Set"
}

variable "nsg_inbound_rules" {
    type = list(string)
    default = []
}

variable "disable_password_authentication" {
    type = bool
    description = "Linux VM Disable password authentication for key auth."
    default = true
}

variable "admin_password" {
    type = string
    description = "Password for admin account on VMSS."
}

variable "source_image_Id" {
    description = "Image ID of the image being used to stand up VMs in VMSS"
    default = null
}

variable "custom_data" {
  description = "The Base64-Encoded Custom Data which should be used for this Virtual Machine Scale Set."
  default     = null
}

variable "enable_encryption" {
  description = "Enable disk encryption on VMSS"
  default     = true
}

variable "overprovision" {
    description = "Should Azure over-rpovision Virtual Machines in this Scale Set? This means that multiple Virtual Machines will be provisioned and Azure will keep the instance which become available first - which improves provisioning success rates and improves deployment time.  You're not billeed for these over-provisioned VM's and they don't count towards your Subscription Quota "
}

variable "enable_windows_vm_automatic_updates" {
  description = "Are automatic updates enabled for Windows Virtual Machine in this scale set?"
  default     = true
}

variable "license_type" {
  description = "Specifies the type of on-premise license which should be used for this Virtual Machine. Possible values are None, Windows_Client and Windows_Server."
  default     = "None"
}

variable "custom_image" {
  description = "Proive the custom image to this module if the default variants are not sufficient"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = null
}

variable "linux_distribution_list" {
  type = map(object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  }))

  default = {
    ubuntu2004 = {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "20.04-LTS"
      version   = "latest"
    }

    ubuntu1804 = {
      publisher = "Canonical"
      offer     = "UbuntuServer"
      sku       = "18.04-LTS"
      version   = "latest"
    }

    RHEL8 = {
      publisher = "RedHat"
      offer     = "RHEL"
      sku       = "8"
      version   = "latest"
    }

    RHEL8-v2 = {
      publisher = "RedHat"
      offer     = "RHEL"
      sku       = "8-gen2"
      version   = "latest"
    }
  }
}

variable "linux_distribution_name" {
  type        = string
  default     = "ubuntu1804"
  description = "Variable to pick an OS flavour for Linux based VMSS possible values include: centos8, ubuntu1804"
}

variable "windows_distribution_list" {
  type = map(object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  }))

  default = {
    windows2016dc = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2016-Datacenter"
      version   = "latest"
    }

    windows2019dc = {
      publisher = "MicrosoftWindowsServer"
      offer     = "WindowsServer"
      sku       = "2019-Datacenter"
      version   = "latest"
    }

    mssql2017exp = {
      publisher = "MicrosoftSQLServer"
      offer     = "SQL2017-WS2016"
      sku       = "Express"
      version   = "latest"
    }
  }
}

variable "windows_distribution_name" {
  type        = string
  default     = "windows2019dc"
  description = "Variable to pick an OS flavour for Windows based VMSS possible values include: winserver, wincore, winsql"
}

variable "os_upgrade_mode" {
  description = "Specifies how Upgrades (e.g. changing the Image/SKU) should be performed to Virtual Machine Instances. Possible values are Automatic, Manual and Rolling. Defaults to Automatic"
  default     = "Automatic"
}

variable "vm_time_zone" {
  description = "Specifies the Time Zone which should be used by the Virtual Machine"
  default     = null
}


variable "os_disk_storage_account_type" {
  description = "The Type of Storage Account which should back this the Internal OS Disk. Possible values include `Standard_LRS`, `StandardSSD_LRS` and `Premium_LRS`."
  default     = "StandardSSD_LRS"
}

variable "os_disk_caching" {
  description = "The Type of Caching which should be used for the Internal OS Disk. Possible values are `None`, `ReadOnly` and `ReadWrite`"
  default     = "ReadWrite"
}

variable "disk_encryption_set_id" {
  description = "The ID of the Disk Encryption Set which should be used to Encrypt this OS Disk. The Disk Encryption Set must have the `Reader` Role Assignment scoped on the Key Vault - in addition to an Access Policy to the Key Vault"
  default     = null
}

variable "disk_size_gb" {
  description = "The Size of the Internal OS Disk in GB, if you wish to vary from the size used in the image this Virtual Scale Set is sourced from."
  default     = null
}

variable "enable_os_disk_write_accelerator" {
  description = "Should Write Accelerator be Enabled for this OS Disk? This requires that the `storage_account_type` is set to `Premium_LRS` and that `caching` is set to `None`."
  default     = false
}


variable "additional_data_disks" {
  description = "Adding additional disks capacity to add each instance (GB)"
  type        = list(number)
  default     = []
}

variable "additional_data_disks_storage_account_type" {
  description = "The Type of Storage Account which should back this Data Disk. Possible values include Standard_LRS, StandardSSD_LRS, Premium_LRS and UltraSSD_LRS."
  default     = "Standard_LRS"
}

variable "dns_servers" {
  description = "List of dns servers to use for network interface"
  default     = []
}

variable "enable_ip_forwarding" {
  description = "Should IP Forwarding be enabled? Defaults to false"
  default     = false
}

variable "enable_autoscale_for_vmss" {
    type = bool
    description = "Enable autoscaling for VMSS"
    default = true
}

variable "minimum_instances_count" {
    description = "Minimum number of instances other than initial instance count of VMSS"
    default = null
}

variable "maximum_instances_count" {
    description = "Maximum number of instances autoscaling can expand to, this will be mostly limited by the subnet the VMSS is stood up in."
    default = "5"
}

variable "scale_out_cpu_percentage_threshold" {
    description = "CPU percentage that autoscaling adds another instance"
    default = "90"
}

variable "scale_in_cpu_percentage_threshold" {
    description = "CPU percentage that autoscaling removes instance"
    default = "20"
}

variable "scaling_action_instances_number" {
    description = "The number of instances that will be added or removed in a scaling action"
    default = "1"
}
