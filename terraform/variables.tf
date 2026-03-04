variable "aws_region" {
  default = "eu-west-3"
}

variable "instance_type" {
  default = "t3.small"
}

variable "my_ip" {
  description = "Mon IP publique pour le SSH"
  type        = string
}

variable "key_name" {
  description = "Le nom de ma clé SSH sur AWS"
  type        = string
}

variable "docker_compose_path" {
  default = "../docker-compose.yml"
}


variable "db_password" {
  description = "Mot de passe de la base de données"
  type        = string
  sensitive   = true
}

variable "db_root_password" {
  description = "Mot de passe root de MariaDB"
  type        = string
  sensitive   = true
}

variable "db_user" {
  description = "Utilisateur de la base de données"
  type        = string
}

variable "db_name" {
  description = "Nom de la base de données"
  type        = string
}

variable "id_instance" {
  description = "ID de mon instance"
  type        = string
}

variable "iam_instance_profile" {
  description = "Role AWS"
  type        = string
}

variable "iam_role_arn" {
  description = "Role VPC Logs"
  type        = string
}

variable "ght_role_arn" {
  description = "Role GitHub Actions"
  type        = string
}

variable "ebs_kms_key_arn" {
  description = "ARN de la CMK EBS"
  type        = string
}

variable "mount_point" {
  description = "Chemin EBS volume"
  type = string
}

variable "github_connection_arn" {
  description = "ARN de la connection GitHub"
  type        = string
}

variable "wpscan_api_token" {
  description = "Clé API WPSCAN"
  type        = string
}