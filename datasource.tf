data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_route53_zone" "mydomain" {
  name         = var.public_domain
  private_zone = false
}
