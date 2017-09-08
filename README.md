# Install Tectonic on Azure with Terraform

This guide deploys a Tectonic cluster on an Azure account.

The Azure platform templates generally adhere to the standards defined by the project [conventions][conventions] and [generic platform requirements][generic]. This document aims to clarify the implementation details specific to the Azure platform.

## Prerequisites

### DNS

Two methods of providing DNS for the Tectonic installation are supported:

#### Azure-provided DNS

This is Azure's default DNS implementation. For more information, see the [Azure DNS overview][azure-dns].

To use Azure-provided DNS, `tectonic_base_domain` must be set to `""`(empty string).

#### DNS delegation and custom zones via Azure DNS

To configure a custom domain and the associated records in an Azure DNS zone (e.g., `${cluster_name}.foo.bar`):

* The custom domain must be specified using `tectonic_base_domain`
* The domain must be publicly discoverable. The Tectonic installer uses the created record to access the cluster and complete configuration. See the Microsoft Azure documentation for instructions on how to [delegate a domain to Azure DNS][domain-delegation].
* An Azure DNS zone matching the chosen `tectonic_base_domain` must be created prior to running the installer. The full resource ID of the DNS zone must then be referenced in `tectonic_azure_external_dns_zone_id`

### Tectonic Account

Register for a [Tectonic Account][register], free for up to 10 nodes. The cluster license and pull secret are required during installation.

### Azure CLI

The [Azure CLI][azure-cli] is required to generate Azure credentials.

### ssh-agent

Ensure `ssh-agent` is running:
```sh
$ eval $(ssh-agent)
```

Add the SSH key that will be used for the Tectonic installation to `ssh-agent`:
```sh
$ ssh-add <path-to-ssh-private-key>
```

Verify that the SSH key identity is available to the ssh-agent:
```sh
$ ssh-add -L
```

Reference the absolute path of the **_public_** component of the SSH key in `tectonic_azure_ssh_key`.

Without this, terraform is not able to SSH copy the assets and start bootkube.
Also ensure the SSH known_hosts file doesn't have old records for the API DNS name, because key fingerprints will not match.

## Getting Started

### Initialize and configure Terraform

#### Get Terraform's Azure modules and providers

Get the modules and providers for the Azure platform that Terraform will use to create cluster resources:

```sh
$ terraform init
Downloading modules...
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a

Initializing provider plugins...
- Downloading plugin for provider "template"...
- Downloading plugin for provider "azurerm"...
- Downloading plugin for provider "null"...
- Downloading plugin for provider "ignition"...
- Downloading plugin for provider "random"...
- Downloading plugin for provider "archive"...
- Downloading plugin for provider "local"...
- Downloading plugin for provider "tls"...
...
```

### Generate credentials with Azure CLI

Execute `az login` to obtain an authentication token. See the [Azure CLI docs][login] for more information. Once logged in, note the `id` field of the output from the `az login` command. This is a simple way to retrieve the Subscription ID for the Azure account.

Next, add a new role assignment for the Installer to use:

```sh
$ az ad sp create-for-rbac -n "http://tectonic" --role contributor
Retrying role assignment creation: 1/24
Retrying role assignment creation: 2/24
{
 "appId": "generated-app-id",
 "displayName": "azure-cli-2017-01-01",
 "name": "http://tectonic-coreos",
 "password": "generated-pass",
 "tenant": "generated-tenant"
}
```

Export the following environment variables with values obtained from the output of the role assignment. As noted above, `ARM_SUBSCRIPTION_ID` is the `id` of the Azure account returned by `az login`.

```sh
# id field in az login output
$ export ARM_SUBSCRIPTION_ID=abc-123-456
# appID field in az ad output
$ export ARM_CLIENT_ID=generated-app-id
# password field in az ad output
$ export ARM_CLIENT_SECRET=generated-pass
# tenant field in az ad output
$ export ARM_TENANT_ID=generated-tenant
```

With the environment set, it's time to specify the deployment details for the cluster.

## Customize the deployment

Possible customizations to the base installation are listed in `examples/terraform.tfvars`. 
Copy the example configuration:

```sh
$ cp examples/terraform.tfvars terraform.tfvars
```

Edit the parameters in `terraform.tfvars` with the deployment's Azure details, domain name, license, and pull secret. [View all of the Azure specific options and the common Tectonic variables][vars].

### Key values for basic Azure deployment

These are the basic values that must be adjusted for each Tectonic deployment on Azure. See the details of each value in the `terraform.tfvars` file.

* `tectonic_admin_email` - For the initial Console login
* `tectonic_admin_password_hash` - Bcrypted value
* `tectonic_azure_client_secret` - As in `ARM_CLIENT_SECRET` above
* `tectonic_azure_ssh_key` - Full path the the public key part of the key added to `ssh-agent` above
* `tectonic_base_domain` - The DNS domain or subdomain delegated to an Azure DNS zone above
* `tectonic_azure_external_dns_zone_id` - Get with `az network dns zone list`
* `tectonic_cluster_name` - Usually matches `$CLUSTER` as set above
* `tectonic_license_path` - Full path to `tectonic-license.txt` file downloaded from Tectonic account
* `tectonic_pull_secret_path` - Full path to `config.json` container pull secret file downloaded from Tectonic account

## Deploy the cluster

Check the plan before deploying:

```sh
$ terraform plan
```

Next, deploy the cluster:

```sh
$ terraform apply
```

This should run for a short time.

## Access the cluster

When `terraform apply` is complete, the Tectonic console will be available at `https://my-cluster.example.com`, as configured in the cluster build's variables file.

### CLI cluster operations with kubectl

Cluster credentials, including any generated CA, are written beneath the `generated/` directory. These credentials allow connections to the cluster with `kubectl`:

```sh
$ export KUBECONFIG=generated/auth/kubeconfig
$ kubectl cluster-info
```

## Delete the cluster

Deleting a cluster will remove only the infrastructure elements created by Terraform. For example, an existing DNS resource group is not removed.

To delete the Azure cluster specified in `terraform.tfvars`, run the following `terraform destroy` command:

```
$ terraform destroy
```

## Known issues and workarounds

See the [installer troubleshooting][troubleshooting] document for known problem points and workarounds.


[azure-cli]: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
[azure-dns]: https://docs.microsoft.com/en-us/azure/dns/dns-overview
[bcrypt]: https://github.com/coreos/bcrypt-tool/releases/tag/v1.0.0
[conventions]: https://github.com/coreos/tectonic-docs/blob/master/Documentation/conventions.md
[copy-docs]: https://www.terraform.io/docs/commands/apply.html
[domain-delegation]: https://docs.microsoft.com/en-us/azure/dns/dns-delegate-domain-azure-dns
[generic]: https://github.com/coreos/tectonic-docs/blob/master/Documentation/generic-platform.md
[install-go]: https://golang.org/doc/install
[login]: https://docs.microsoft.com/en-us/cli/azure/get-started-with-azure-cli
[plan-docs]: https://www.terraform.io/docs/commands/plan.html
[register]: https://account.coreos.com/signup/summary/tectonic-2016-12
[release-notes]: https://coreos.com/tectonic/releases/
[troubleshooting]: https://github.com/coreos/tectonic-docs/blob/master/Documentation/troubleshooting/installer-terraform.md
[vars]: https://github.com/coreos/terraform-azurerm-kubernetes/blob/master/variables.md
[verification-key]: https://coreos.com/security/app-signing-key/ 
