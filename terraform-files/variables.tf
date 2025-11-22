variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "Primary region (e.g., asia-south1)"
  type        = string
  default     = "asia-south1"
}

variable "prefix" {
  description = "Naming prefix for resources"
  type        = string
  default     = "app-dev"
}

variable "public_subnet_cidr" {
  description = "CIDR for public subnet"
  type        = string
  default     = "10.0.0.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR for private subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "master_cidr" {
  description = "Control-plane CIDR (for private GKE master)"
  type        = string
  default     = "172.16.0.0/28"
}

variable "admin_cidr" {
  description = "Admin IP CIDR allowed to access GKE API"
  type        = string
  default     = "0.0.0.0/0" # Replace with your office/home IP range (e.g., 49.37.x.x/32)
}

variable "node_count" {
  description = "GKE node count"
  type        = number
  default     = 1
}

variable "node_machine" {
  description = "GKE node machine type"
  type        = string
  default     = "e2-standard-4"
}
