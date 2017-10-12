locals {
  "bootstrapping_host" = "${var.tectonic_azure_private_cluster ?
    module.vnet.master_private_ip_addresses[0] :
    module.vnet.api_fqdn}"
}

module "bootstrapper" {
  source = "github.com/coreos/tectonic-installer//modules/bootstrap-ssh?ref=5dd9b5f4b0e45cbd53cad66688bdc637ba9fe35d"

  _dependencies = [
    "${module.masters.master_vm_ids}",
    "${module.etcd.etcd_vm_ids}",
    "${module.etcd_certs.id}",
    "${module.bootkube.id}",
    "${module.tectonic.id}",
    "${module.flannel_vxlan.id}",
    "${module.calico.id}",
    "${module.canal.id}",
  ]

  bootstrapping_host = "${local.bootstrapping_host}"
}
