terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "6.0.0"
      }
    }

    required_version = ">= 1.2.0"
}

provider "aws" {
    region = "ap-southeast-1"
}