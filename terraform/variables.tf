# Definimos las variables para no hardcodear todo si es posible
variable "vpc_id" {}

variable "subnet_id" {}

variable "subnet_id_2" {}

variable "key_name" {}

variable "ami_id" {
  default = "ami-02dfbd4ff395f2a1b" # Amazon Linux 2023
}

variable "instance_type" {
  default = "t3.micro"
}
