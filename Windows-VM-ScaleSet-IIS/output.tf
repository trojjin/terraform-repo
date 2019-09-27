output "endpoint" {
    value = "${azurerm_public_ip.vmss.fqdn}"
}
