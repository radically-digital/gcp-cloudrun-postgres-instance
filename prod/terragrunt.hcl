locals {
  common_vars = yamldecode(file(find_in_parent_folders("common-vars.yml")))
}

terraform {
  source = "..//modules"
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "google" {
  project = "${local.common_vars.project}"
  region  = "${local.common_vars.location}"
}

provider "google-beta" {
  project = "${local.common_vars.project}"
  region  = "${local.common_vars.location}"
}
EOF
}

remote_state {
  backend = "gcs"

  generate = {
    path      = "remote_state_backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    project  = local.common_vars.project
    location = local.common_vars.location
    bucket   = "${local.common_vars.project}-terraform-state"
    prefix   = "${path_relative_to_include()}/terraform.tfstate"

    gcs_bucket_labels = {
      "owner" = local.common_vars.team
    }
  }
}

inputs = merge(local.common_vars, {
})
