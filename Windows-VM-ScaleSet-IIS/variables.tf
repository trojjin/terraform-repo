variable "location" {
}
variable "prefix" {
}
variable "computer_name" {
  default = "hostname"
}
variable "admin_username" {
}
variable "admin_password" {
}
variable "resource_group_name" {}
variable "tags" {
  description = "A map of the tags to use for the resources that are deployed"
  type        = "map"
  default = {
    environment = "UAT"
  }
}
variable "application_port" {
   description = "The port that you want to expose to the external load balancer"
   default     = 80
}