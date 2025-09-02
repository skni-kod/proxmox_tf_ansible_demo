variable "proxmox_password" {
    type        = string
    sensitive   = true
}

variable "container_name" {
    type        = string
    default     = "tf-container"
}

variable "container_ip" {
  type        = string
}

variable "container_root_password" {
  type        = string
  sensitive   = true
}

variable "ram_memory" {
  type        = number
  default     = 2048
}

variable "disk_size" {
  type        = string
  default     = "8G"
}