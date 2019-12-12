/* Note: This configuration of the firewall is expected to be 
 *       used along with a bootstrap configuration which configures
 *       the network interfaces by associating them with the correct zones,
 *       once the zones have been created. The bootstrap process also 
 *       configures the username and password which will be used to 
 *       configure the firewall.
 */

resource "panos_service_object" "service_tcp_222" {
  name             = "service-tcp-222"
  vsys             = "vsys1"
  protocol         = "tcp"
  description      = "Service object to map port 22 to 222"
  destination_port = "222"
}

resource "panos_service_object" "http-81" {
  name             = "http-81"
  vsys             = "vsys1"
  protocol         = "tcp"
  description      = "Service object to map port 22 to 222"
  destination_port = "81"
}

resource "panos_nat_policy" "nat_rule_for_web_ssh" {
  name                  = "web_ssh2"
  source_zones          = ["external"]
  destination_zone      = "external"
  source_addresses      = ["any"]
  destination_addresses = ["10.0.0.100"]
  service               = "service-tcp-222"
  sat_type              = "dynamic-ip-and-port"
  sat_address_type      = "interface-address"
  sat_interface         = "ethernet1/2"
  dat_address           = "10.0.1.102"
  dat_port              = "22"

  depends_on = ["panos_service_object.service_tcp_222"]
}

resource "panos_nat_policy" "nat_rule_for_web_http" {
  name                  = "web_http2"
  source_zones          = ["external"]
  destination_zone      = "external"
  source_addresses      = ["any"]
  destination_addresses = ["10.0.0.100"]
  service               = "http-81"
  sat_type              = "dynamic-ip-and-port"
  sat_address_type      = "interface-address"
  sat_interface         = "ethernet1/2"
  dat_address           = "10.0.1.102"
  dat_port              = "80"

  depends_on = ["panos_service_object.http-81"]
}

resource "panos_security_policies" "security_rules" {
  rule {
    name                  = "web traffic 2"
    source_zones          = ["external"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["web"]
    destination_addresses = ["any"]
    applications          = ["web-browsing"]
    services              = ["http-81"]
    categories            = ["any"]
    action                = "allow"
  }

  rule {
    name                  = "ssh traffic"
    source_zones          = ["external"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["web"]
    destination_addresses = ["any"]
    applications          = ["any"]
    services              = ["service-tcp-222"]
    categories            = ["any"]
    action                = "allow"
  }

  depends_on = ["panos_nat_policy.nat_rule_for_web_http",
    "panos_nat_policy.nat_rule_for_web_ssh",
  ]
}

resource "null_resource" "commit_fw" {
  triggers {
    key = "${panos_security_policies.security_rules.id}"
  }

  provisioner "local-exec" {
    command = "./commit.sh ${var.fw_ip}"
  }
}
