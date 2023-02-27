variable "ec2_key" {
  description = "Worker nodes key pair"
  type = string
}

variable "region" {
  description = "AWS Region for provisioning resources"
  type = string
}