instances = [
  {
    instance_type = "t2.micro"
    ami_id        = "ami-04a81a99f5ec58529"
    tags = {
      Name = "Instance1"
    }
  },
  {
    instance_type = "t2.micro"
    ami_id        = "ami-04a81a99f5ec58529"
    tags = {
      Name = "Instance2"
    }
  },
  {
    instance_type = "t2.micro"
    ami_id        = "ami-04a81a99f5ec58529"
    tags = {
      Name = "Instance3"
    }
  },
  {
    instance_type = "t2.micro"
    ami_id        = "ami-04a81a99f5ec58529"
    tags = {
      Name = "Instance4"
    }
  }
]

vpc_cidr             = "10.10.0.0/16"
public_subnet_cidrs  = ["10.10.1.0/24"]
private_subnet_cidrs = ["10.10.2.0/24", "10.10.3.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
public_key_path      = "~/.ssh/id_rsa.pub"
