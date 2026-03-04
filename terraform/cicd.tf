resource "aws_ecr_repository" "wp_repo" {
  name                 = "wp-app-repo"
  image_tag_mutability = "MUTABLE"
  force_delete         = true
}

resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "wp-devsecops-pipeline-artifacts-${random_id.id.hex}"
}

resource "random_id" "id" {
  byte_length = 4
}


resource "aws_iam_role" "codebuild_role" {
  name = "wp-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
    }]
  })
}


resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name
  name = "wp-codebuild-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = ["*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ecr:*"]
        Resource = [aws_ecr_repository.wp_repo.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:PutObject"]
        Resource = ["${aws_s3_bucket.pipeline_artifacts.arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        # On donne accès au secret créé dans sm.tf
        Resource = [aws_secretsmanager_secret.wp_secrets.arn]
      }
    ]
  })
}


resource "aws_codebuild_project" "wp_build" {
  name          = "wp-build-project"
  service_role  = aws_iam_role.codebuild_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0" 
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true 
    
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}


resource "aws_codepipeline" "wp_pipeline" {
  name     = "wordpress-devsecops-pipeline"
  role_arn = aws_iam_role.pipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.pipeline_artifacts.bucket
    type     = "S3"
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
        FullRepositoryId = "antoninmpro-wq/wordpress-devsecops"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build_and_Security_Scan"
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


resource "aws_iam_role" "pipeline_role" {
  name = "wp-pipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "codepipeline.amazonaws.com" }
    }]
  })
}

data "aws_caller_identity" "current" {}
