

variable "component_name" {
  description = "component name"
  type        = string
  default     = "sonarqube-server"
}

variable "container_port" {
  description = "sonarQube port"
  type        = number
  default     = 9000
}


variable "database_name" {
  description = "sonarQube database name"
  type        = string
  default     = "sonar"
}

variable "master_username" {
  description = "sonarQube database master user name"
  type        = string
  default     = "sonar"
}

variable "container_name" {
  description = "ecr sonarqube container name"
  type        = string
  default     = "sonnar-server-security-scan"
}

variable "container_version" {
  description = "sonarQube container version "
  type        = string
  default     = "1.1.0"
}

variable "dns_zone_name" {
  description = "dns name"
  type        = string
  default     = "coniliuscf.org"
}

variable "subject_alternative_names" {
  type    = list(any)
  default = ["*.coniliuscf.org"]
}

