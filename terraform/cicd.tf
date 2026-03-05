# --- 1. RÉCUPÉRATION DYNAMIQUE DE L'ID DE COMPTE ---
data "aws_caller_identity" "current" {}

# --- 2. LE BUCKET S3 ---
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "wordpress-pipeline-artifacts-${data.aws_caller_identity.current.account_id}"
}

# --- CONFIGURATION CODEBUILD ---
resource "aws_codebuild_project" "wp_build" {
  name          = "wordpress-build"
  service_role  = "arn:aws:iam::823717189474:role/WP-CodeBuild-Role"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# --- CONFIGURATION CODEPIPELINE ---
resource "aws_codepipeline" "wp_pipeline" {
  name     = "wordpress-pipeline"
  role_arn = "arn:aws:iam::823717189474:role/WP-Pipeline-Role"

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
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
        ConnectionArn    = "arn:aws:codeconnections:eu-west-3:823717189474:connection/7cbdcc3d-983f-4fa2-a072-a43f6aca1523"
        FullRepositoryId = "antoninmdev-lgtm/WPDevSecOps"
        BranchName       = "main"
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
