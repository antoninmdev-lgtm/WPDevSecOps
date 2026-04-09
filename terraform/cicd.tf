# --- 1. RÉCUPÉRATION DYNAMIQUE DE L'ID DE COMPTE ---
data "aws_caller_identity" "current" {}


# --- 2. LE BUCKET S3 ---
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "wordpress-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"

  # Skips pour les options "Enterprise" inutiles ici :
  # checkov:skip=CKV_AWS_18
  # checkov:skip=CKV_AWS_144
  # checkov:skip=CKV2_AWS_62
  # checkov:skip=CKV2_AWS_61
}

resource "aws_s3_bucket_public_access_block" "codepipeline_bucket_pab" {
  bucket                  = aws_s3_bucket.codepipeline_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "codepipeline_bucket_versioning" {
  bucket = aws_s3_bucket.codepipeline_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_bucket_encryption" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.infra_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "codepipeline_bucket_lifecycle" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  rule {
    id     = "cleanup-old-artifacts"
    status = "Enabled"

    expiration {
      days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    filter { }
  }
}




# --- CONFIGURATION CODEBUILD ---
resource "aws_codebuild_project" "wp_build" {
  name          = "wordpress-build"
  service_role  = var.iam_wp_codebuild
  encryption_key  = var.infra_kms_key_arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    #checkov:skip=CKV_AWS_316
  }

  logs_config {
    cloudwatch_logs {
      status      = "ENABLED"
      group_name  = "/aws/codebuild/wordpress-build"
      stream_name = "build-stream"
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}


# --- CONFIGURATION CODEPIPELINE ---
resource "aws_codepipeline" "wp_pipeline" {
  name     = "wordpress-pipeline"
  role_arn = var.iam_wp_pipeline

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"

    encryption_key {
      id   = var.infra_kms_key_arn
      type = "KMS"
    }
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = "antoninmdev-lgtm/WPDevSecOps"
        BranchName       = "main"
        DetectChanges    = "true"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        ProjectName = aws_codebuild_project.wp_build.name
      }
    }
  }
}
