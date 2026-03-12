provider "aws" {
  region = "us-east-1"
}

module "webmin_cluster" {
  source = "terraform-aws-modules/eks/aws"
  
  cluster_name = "webmin-cluster"
  cluster_version = "1.22"
  
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.private_subnets
  
  worker_groups = [
    {
      name = "spot-group"
      spot_price = "0.05"
      instance_type = "m5.large"
      asg_min_size = 3
      asg_max_size = 1000
      asg_desired_capacity = 3
    }
  ]
}

module "global_load_balancer" {
  source = "terraform-aws-modules/alb/aws"
  
  name = "webmin-glb"
  
  vpc_id = module.vpc.vpc_id
  subnets = module.vpc.public_subnets
  
  http_tcp_listeners = [
    {
      port = 80
      protocol = "HTTP"
    }
  ]
  
  target_groups = [
    {
      name = "webmin-tg"
      backend_protocol = "HTTP"
      backend_port = 80
      target_type = "ip"
    }
  ]
}
