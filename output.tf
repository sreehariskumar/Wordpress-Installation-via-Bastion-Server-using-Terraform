output "availability_zone" {
  value = length(data.aws_availability_zones.available.names)
}

output "subnet_count" {
  value = local.subnet_count
}

output "WordPress-URL" {
  value = "http://${aws_route53_record.public-dns.fqdn}"
}