terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2022.3.1"
    }
    pass = {
      source  = "mecodia/pass"
      version = "~> 3.0.1"
    }
  }
}