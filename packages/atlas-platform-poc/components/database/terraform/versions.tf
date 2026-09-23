terraform {
  required_version = ">= 1.16"

  required_providers {
    external = {
      source  = "hashicorp/external"
      version = "= 2.4.2"
    }
    local = {
      source  = "hashicorp/local"
      version = "= 2.9.1"
    }
    null = {
      source  = "hashicorp/null"
      version = "= 3.3.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.65.0"
    }
  }
}
