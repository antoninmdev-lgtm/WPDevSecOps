resource "aws_secretsmanager_secret" "wp_secrets" {
  name        = "prod/wordpress/infra"
  description = "Secrets pour l'application WordPress (DB, API, etc.)" 
  kms_key_id  = var.infra_kms_key_arn
  # checkov:skip=CKV2_AWS_57
}

resource "aws_secretsmanager_secret_version" "wp_secrets_val" {
  secret_id     = aws_secretsmanager_secret.wp_secrets.id
  
  secret_string = jsonencode({
    DB_NAME      = var.db_name
    DB_PASSWORD          = var.db_password
    DB_PASSWORD_ROOT          = var.db_root_password
    DB_USER          = var.db_user
    ARN_EBS_KMS_KEY   = var.ebs_kms_key_arn
    ARN_INFRA_KMS_KEY = var.infra_kms_key_arn
    IAM_INSTANCE_PROFILE = var.iam_instance_profile
    IAM_ROLE_ARN = var.iam_role_arn
    IAM_WP_PIPELINE = var.iam_wp_pipeline
    IAM_WP_CODEBUILD = var.iam_wp_codebuild
    ID_INSTANCE = var.id_instance
    KEY_NAME = var.key_name
    MY_IP = var.my_ip
    TF_VAR_MOUNT_PATH = var.mount_point
    GITHUB_CONNECTION_ARN = var.github_connection_arn
    WPSCAN_API_TOKEN = var.wpscan_api_token
  })
}
