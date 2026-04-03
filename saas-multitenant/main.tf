module "shared" {
  source = "./modules/shared"
  app_name = "multitenant-app"
  environment = "dev"
}

