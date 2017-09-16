# Install Tectonic on Azure with Terraform

This module deploys a [Tectonic][tectonic] [Kubernetes][k8s] cluster on Azure using [Terraform][terraform]. Tectonic is an enterprise-ready distribution of Kubernetes including automatic updates, monitoring and alerting, integration with common authentication regimes, and a graphical console for managing clusters in a web browser.

This module can deploy either a complete Tectonic cluster, requiring a Tectonic license, or a "stock" Kubernetes cluster without Tectonic features.

The Azure platform templates generally adhere to the standards defined by the project [conventions][conventions] and [generic platform requirements][generic]. This document clarifies the implementation details specific to the Azure platform.

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

The next step in preparing the environment for installation is to add the key to be used for logging in to each cluster node during initialization to the local `ssh-agent`.

#### Adding a key to ssh-agent

Ensure `ssh-agent` is running by listing the known keys:

```bash
$ ssh-add -L
```

Add the SSH private key that will be used for the deployment to `ssh-agent`:

```bash
$ ssh-add ~/.ssh/id_rsa
```

Verify that the SSH key identity is available to the ssh-agent:

```bash
$ ssh-add -L
```

Reference the absolute path of the *public* component of the SSH key in the `tectonic_azure_ssh_key` variable.

Without this, terraform is not able to SSH copy the assets and start bootkube.
Also, ensure the SSH known_hosts file doesn't have old records for the API DNS name, because key fingerprints will not match.

## Configuring the deployment

### Get Terraform's Azure modules and providers

Get the modules and providers for the Azure platform that Terraform will use to create cluster resources:

```sh
$ terraform init
Downloading modules...
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
Get: git::https://github.com/coreos/tectonic-installer.git?ref=1d75718d96c7bdec04d5ffb8a72fa059b1fcb79a
...


Initializing provider plugins...
- Downloading plugin for provider "template"...
- Downloading plugin for provider "azurerm"...
- Downloading plugin for provider "null"...
- Downloading plugin for provider "ignition"...
...
```

### Generate credentials with Azure CLI

Execute `az login` to obtain an authentication token. See the [Azure CLI docs][login] for more information. Once logged in, note the `id` field of the output from the `az login` command. This is a simple way to retrieve the Subscription ID for the Azure account.

#### Add Active Directory Service Principal role assignment

Next, add a new Active Directory (AD) Service Principal (SP) role assignment to grant Terraform access to Azure:

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

### Customize the deployment

Customizations to the base installation are made to the Terraform variables for each deployment. Examples of the this module's variables are provided in the file `examples/kubernetes.tf`.

Edit the variables with the Azure account details, domain name, and [Tectonic license][register]. To install a basic Kubernetes cluster without Tectonic features, set the `tectonic_vanilla_k8s` key to `true` and omit the Tectonic license.

[View all of the Azure specific options and the common Tectonic variables][vars].

#### Key values for basic Azure deployment

These are the basic values that must be adjusted for each deployment on Azure. See the details of each value in the comments in the `examples/kubernetes.tf` file.

* `tectonic_admin_email` - For the initial Console login
* `tectonic_admin_password_hash` - Use [`bcrypt-tool`][bcrypt-tool] to encrypt password
* `tectonic_azure_client_secret` - As in `ARM_CLIENT_SECRET` above
* `tectonic_azure_ssh_key` - Full path to the public key part of the key added to `ssh-agent` above
* `tectonic_azure_location` - e.g., `centralus`
* `tectonic_base_domain` - The DNS domain or subdomain delegated to an Azure DNS zone above
* `tectonic_azure_external_dns_zone_id` - Value of `id` in `az network dns zone list` output
* `tectonic_cluster_name` - The name to give the cluster
* `tectonic_license_path` - Full path to `tectonic-license.txt` file downloaded from Tectonic account
* `tectonic_pull_secret_path` - Full path to `config.json` container pull secret file downloaded from Tectonic account

### Deploy the cluster

Check the plan before deploying:

```sh
$ terraform plan
```

Next, deploy the cluster:

```sh
$ terraform apply
```

This should run for a short time.

### Access the cluster

When `terraform apply` is complete, access Tectonic Console in a web browser at the URL formed by concatenating the cluster name and the domain name configured in the Terraform variables.

### CLI cluster operations with kubectl

Cluster credentials are written beneath the `generated/` directory, including any generated CA certificate and a `kubeconfig`. Use the kubeconfig file to access the cluster with the `kubectl` CLI tool. This is the only method of access for a Kubernetes cluster installed without Tectonic features:

```sh
$ export KUBECONFIG=generated/auth/kubeconfig
$ kubectl cluster-info
```

## Delete the cluster

Deleting a cluster will remove only the infrastructure elements created by Terraform. For example, an existing DNS resource group is not removed.

To delete the cluster, run the `terraform destroy` command:

```
$ terraform destroy
```


[azure-cli]: https://docs.microsoft.com/en-us/cli/azure/install-azure-cli
[azure-dns]: https://docs.microsoft.com/en-us/azure/dns/dns-overview
[bcrypt]: https://github.com/coreos/bcrypt-tool/releases/tag/v1.0.0
[conventions]: https://github.com/coreos/tectonic-docs/blob/master/Documentation/conventions.md
[copy-docs]: https://www.terraform.io/docs/commands/apply.html
[domain-delegation]: https://docs.microsoft.com/en-us/azure/dns/dns-delegate-domain-azure-dns
[generic]: https://github.com/coreos/tectonic-docs/blob/master/Documentation/generic-platform.md
[install-go]: https://golang.org/doc/install
[k8s]: https://kubernetes.io
[login]: https://docs.microsoft.com/en-us/cli/azure/get-started-with-azure-cli
[plan-docs]: https://www.terraform.io/docs/commands/plan.html
[register]: https://account.coreos.com/signup/summary/tectonic-2016-12
[release-notes]: https://coreos.com/tectonic/releases/
[tectonic]: https://coreos.com/tectonic/
[terraform]: https://www.terraform.io/downloads.html
[troubleshooting]: https://github.com/coreos/tectonic-docs/blob/master/Documentation/troubleshooting/installer-terraform.md
[vars]: https://github.com/coreos/terraform-azurerm-kubernetes/blob/master/variables.md
[verification-key]: https://coreos.com/security/app-signing-key/
