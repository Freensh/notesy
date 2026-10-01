# Remote state. Uncomment and fill in once a state bucket exists, then run
# `terraform init -migrate-state`. Local state is used until then.
#
# terraform {
#   backend "s3" {
#     bucket       = "<your-terraform-state-bucket>"
#     key          = "scrib/prod/terraform.tfstate"
#     region       = "<your-region>"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
