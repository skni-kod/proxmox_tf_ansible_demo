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
    key    = "proxmox/testapp-terraform.tfstate"
    region = "us-east-1"

    use_path_style            = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
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
    hostname   = var.container_name
    ostemplate = "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
    password = var.container_root_password
    unprivileged = true
    cores = 2
    memory = var.ram_memory
    swap = 512
    start = true

    rootfs {
        storage = "local-lvm"
        size    = var.disk_size
    }

    network {
        name   = "eth0"
        bridge = "vmbr1"
        ip     = var.container_ip
        gw = "192.168.1.1"
        firewall = true
    }
}