locals {
  "bootstrapping_host" = "${var.tectonic_azure_private_cluster ? 
    module.vnet.master_private_ip_addresses[0] : 
    module.vnet.api_fqdn}"
}

module "bootstrapper" {
  source = "github.com/coreos/tectonic-installer//modules/bootstrap-ssh?ref=da99443f9a0b62f473b21e26d7d29c90959d8538"

  _dependencies = [
    "${module.masters.master_vm_ids}",
    "${module.etcd.etcd_vm_ids}",
    "${module.etcd_certs.id}",
    "${module.bootkube.id}",
    "${module.tectonic.id}",
    "${module.flannel-vxlan.id}",
    "${module.calico-network-policy.id}",
  ]

  bootstrapping_host = "${local.bootstrapping_host}"
}
