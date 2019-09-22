output "endpoint" {
    value = azurerm_public_ip.test.fqdn
}
output "environment" {
    value = azurerm_virtual_machine.test.tags.environment
}