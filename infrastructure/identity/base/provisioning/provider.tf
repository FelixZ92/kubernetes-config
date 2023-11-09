terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2023.10.0"
    }
    pass = {
      source  = "mecodia/pass"
      version = "~> 3.0.1"
    }
  }
}
