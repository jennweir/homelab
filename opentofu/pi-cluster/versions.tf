terraform { 
  backend "gcs" {
    bucket = "jennweir-terraform-backend"
    prefix = "terraform/state/pi-cluster"
  }
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "5.42.0"
    }
  }
  required_version = ">= 1.1.2"
}
