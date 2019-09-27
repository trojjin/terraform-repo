resource "azurerm_resource_group" "vmss" {
  name     = "${var.resource_group_name}"
  location = "${var.location}"
  tags     = "${var.tags}"
}

resource "random_string" "fqdn" {
  length  = 6
  special = false
  upper   = false
  number  = false
}

resource "azurerm_virtual_network" "vmss" {
  name                = "vmss-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.vmss.name}"
  tags                = "${var.tags}"
}

resource "azurerm_subnet" "vmss" {
  name                 = "vmss-subnet"
  resource_group_name  = "${azurerm_resource_group.vmss.name}"
  virtual_network_name = "${azurerm_virtual_network.vmss.name}"
  address_prefix       = "10.0.2.0/24"
}
resource "azurerm_network_security_group" "vmss" {
  name                = "vmss_securitygroup"
  location            = "${azurerm_resource_group.vmss.location}"
  resource_group_name = "${azurerm_resource_group.vmss.name}"

  security_rule {
    name                       = "HTTP-IN"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "${var.application_port}"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "${azurerm_subnet.vmss.address_prefix}"
  }
  tags = "${var.tags}"
}
resource "azurerm_public_ip" "vmss" {
  name                = "vmss-public-ip"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.vmss.name}"
  allocation_method   = "Static"
  domain_name_label   = "${random_string.fqdn.result}"
  tags                = "${var.tags}"
}
resource "azurerm_lb" "vmss" {
  name                = "vmss-lb"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.vmss.name}"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = "${azurerm_public_ip.vmss.id}"
  }

  tags = "${var.tags}"
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
  resource_group_name = "${azurerm_resource_group.vmss.name}"
  loadbalancer_id     = "${azurerm_lb.vmss.id}"
  name                = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "vmss" {
  resource_group_name = "${azurerm_resource_group.vmss.name}"
  loadbalancer_id     = "${azurerm_lb.vmss.id}"
  name                = "http-running-probe"
  port                = "${var.application_port}"
}

resource "azurerm_lb_rule" "lbnatrule" {
  resource_group_name            = "${azurerm_resource_group.vmss.name}"
  loadbalancer_id                = "${azurerm_lb.vmss.id}"
  name                           = "http"
  protocol                       = "Tcp"
  frontend_port                  = "${var.application_port}"
  backend_port                   = "${var.application_port}"
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bpepool.id}"
  frontend_ip_configuration_name = "PublicIPAddress"
  probe_id                       = "${azurerm_lb_probe.vmss.id}"
}
resource "azurerm_virtual_machine_scale_set" "vmss" {
  name                = "vmscaleset"
  location            = "${var.location}"
  resource_group_name = "${azurerm_resource_group.vmss.name}"
  upgrade_policy_mode = "Manual"

  sku {
    name     = "Standard_DS1_v2"
    tier     = "Standard"
    capacity = 2
  }

  storage_profile_os_disk {
    name              = ""
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_profile_data_disk {
    lun           = 0
    caching       = "ReadWrite"
    create_option = "Empty"
    disk_size_gb  = 10
  }

  os_profile {
    computer_name_prefix = "vmlab"
    admin_username       = "${var.admin_username}"
    admin_password       = "${var.admin_password}"
  }


  storage_profile_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2012-R2-Datacenter-smalldisk"
    version   = "latest"
  }

  os_profile_windows_config {
    provision_vm_agent = true
    winrm {
      protocol = "http"
    }
  }
  extension {
    name                 = "CustomScriptExtension"
    publisher            = "Microsoft.Compute"
    type                 = "CustomScriptExtension"
    type_handler_version = "1.9"
    settings             = "{\"commandToExecute\" : \"powershell.exe Install-WindowsFeature Web-Server\"}"
  }

  network_profile {
    name    = "terraformnetworkprofile"
    primary = true

    ip_configuration {
      name                                   = "IPConfiguration"
      subnet_id                              = "${azurerm_subnet.vmss.id}"
      load_balancer_backend_address_pool_ids = ["${azurerm_lb_backend_address_pool.bpepool.id}"]
      primary                                = true
    }
  }
  tags = "${var.tags}"
}

locals {
  instance_count = 2
}
resource "azurerm_autoscale_setting" "vmss" {
  name                = "autoscale-cpu"
  target_resource_id  = "${azurerm_virtual_machine_scale_set.vmss.id}"
  location            = "${azurerm_resource_group.vmss.location}"
  resource_group_name = "${azurerm_resource_group.vmss.name}"

  profile {
    name = "autoscale-cpu"

    capacity {
      default = "${local.instance_count}"
      minimum = 0
      maximum = 100
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = "${azurerm_virtual_machine_scale_set.vmss.id}"
        time_grain         = "PT1M"   # Set to 1min interval for demo purposes.
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 60       # Add node if CPU above 60%
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = "${azurerm_virtual_machine_scale_set.vmss.id}"
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT1M"   # Set to 1min interval for demo purposes.
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 15       # Decrease when CPU less than 15%
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}