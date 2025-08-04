terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "~> 2022.12.0"
    }
    pass = {
      source  = "mecodia/pass"
      version = "~> 3.0.1"
    }
  }
}
