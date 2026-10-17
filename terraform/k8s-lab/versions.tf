terraform { 
  backend "gcs" {
    bucket = "jennweir-terraform-backend"
    prefix = "terraform/state/k8s-lab"
  }
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.42.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.8.0"
    }
  }
  required_version = ">= 1.1.2"
}
