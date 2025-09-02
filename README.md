# Infrastructure Automation with Terraform and Ansible

This is an example of provisioning infrastructure on Proxmox server using Terraform and automating software installation using Ansible.

---

## Terraform

### Overview

Terraform is used to provision infrastructure (VMs, containers) on which applications can be deployed. As an Infrastructure as Code tool, it allows versioning of both the environment and its resources.

### Functionality

Terraform connects to Proxmox and, based on the `.tf` configuration files, creates, modifies, or deletes machines and containers. It tracks the current state via a `.tfstate` file stored in a Minio bucket (`terraform-state`). Terraform can be executed from any location, such as a local machine or GitHub Actions workflow.

### Example Configuration

To connect Terraform to Proxmox, credentials must be provided according to the documentation: <https://registry.terraform.io/providers/Telmate/proxmox/latest/docs>. Ensure `pm_user` and `pm_password` variables are properly configured.

**Sample `main.tf`:**

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "http://192.168.1.125:9000"
    }
    bucket = "terraform-state"
    key    = "proxmox/terraform.tfstate"
    region = "us-east-1"

    use_path_style                = true
    skip_credentials_validation   = true
    skip_metadata_api_check       = true
    skip_region_validation        = true
    skip_requesting_account_id    = true
  }
}

provider "proxmox" {
  pm_api_url      = "https://192.168.1.2:8006/api2/json"
  pm_user         = "terraform-prov@pve"
  pm_password     = var.proxmox_password
  pm_tls_insecure = true
}

resource "proxmox_lxc" "container" {
  target_node = "malwina"
  hostname    = var.container_name
  ostemplate  = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
  password    = var.container_root_password
  unprivileged = true
  cores       = 2
  memory      = var.ram_memory
  swap        = 512
  start       = true

  rootfs {
    storage = "local-lvm"
    size    = var.disk_size
  }

  network {
    name      = "eth0"
    bridge    = "vmbr1"
    ip        = var.container_ip
    gw        = "192.168.1.1"
    firewall  = true
  }

  ssh_public_keys = <<-EOT
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILyZYnWLkHsYCRPARgzd6tpiNjDlv5CEZYJET9lJ02Hk github-actions
  EOT
}

variable "proxmox_password" {
  type      = string
  sensitive = true
}

variable "container_name" {
  type    = string
  default = "tf-container"
}

variable "container_ip" {
  type = string
}

variable "container_root_password" {
  type      = string
  sensitive = true
}

variable "ram_memory" {
  type    = number
  default = 2048
}

variable "disk_size" {
  type    = string
  default = "8G"
}

output "container_ip" {
  value = trimsuffix(proxmox_lxc.container.network[0].ip, "/24")
}
```

### Running Terraform

#### Local Execution

1. **Create a `.env` file:**

```env
AWS_ACCESS_KEY_ID=minioadmin
AWS_SECRET_ACCESS_KEY=supersekret
```

1. **Load environment variables:**

   **Linux:**

   ```sh
   if [ -f ".env" ]; then
       export $(grep -v '^#' .env | grep -v '^$' | xargs)
   fi
   ```

   **Windows (PowerShell):**

   ```powershell
   Get-Content .env | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { [Environment]::SetEnvironmentVariable($matches[1], $matches[2], 'Process') } }
   ```

1. **Create terraform.tfvars:**

```tfvars
proxmox_password        = "tfPass25"
container_ip            = "192.168.1.125/24"
container_root_password = "malwinapass"
```

1. **Run Terraform commands:**

```bash
terraform init
terraform plan
terraform apply
```

#### GitHub Actions Example

```yaml
jobs:
  terraform:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.5.0"
      - run: terraform init
        working-directory: ./terraform
      - run: terraform plan -input=false
        working-directory: ./terraform
      - run: terraform apply -auto-approve -input=false
        working-directory: ./terraform
```

---

## Ansible

### Ansible Overview

Ansible automates software installation and configuration on infrastructure provisioned by Terraform. It is typically executed after Terraform completes.

### Ansible Functionality

Terraform provides the container IP, and Ansible connects via SSH using the public key defined in Terraform. An inventory file is generated dynamically in the workflow, while the playbook defines the actions to perform.

### Ansible Configuration

#### GitHub Actions Workflow

```yaml
jobs:
  ansible:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - name: Get container IP from Terraform
        id: get_ip
        run: |
          CONTAINER_IP=$(terraform output -raw container_ip)
          echo "container_ip=$CONTAINER_IP" >> $GITHUB_OUTPUT
      - run: |
          mkdir -p ~/.ssh
          echo "${{ secrets.CONTAINER_SSH_PRIVATE_KEY }}" > ~/.ssh/id_ed25519
          chmod 600 ~/.ssh/id_ed25519
      - run: |
          echo "web ansible_host=${{ steps.get_ip.outputs.container_ip }} ansible_user=root ansible_ssh_private_key_file=~/.ssh/id_ed25519 ansible_ssh_common_args='-o StrictHostKeyChecking=no'" > inventory
        working-directory: ./ansible
      - run: python3 -m pip install --upgrade pip
      - run: pip install ansible
      - run: python3 -m ansible.cli.playbook playbook.yml -i inventory
        working-directory: ./ansible
```

#### Sample `./ansible/playbook.yml`

```yaml
- name: Install NGINX
  hosts: web
  become: true
  tasks:
    - name: Update apt cache
      apt:
        update_cache: yes
    - name: Install nginx
      apt:
        name: nginx
        state: present
```

### Required Secrets

- `CONTAINER_SSH_PRIVATE_KEY` — private key for the container SSH access
- Terraform secrets for Proxmox and Minio (as described in Terraform section)
