module "label_vpc" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "vpc"
  attributes = ["main"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = module.label_vpc.tags
}

# =========================
# Create your subnets here
# =========================


# Get the available availability zones
data "aws_availability_zones" "available" {}

# Local variables for subnet CIDR calculations and availability zone
locals {
  # Select the availability zone, use provided AZ or default to the first available AZ
  az                    = var.availability_zone != "" ? var.availability_zone : data.aws_availability_zones.available.names[0]

  # Calculate /24 subnets within the given VPC CIDR block
  public_subnet_cidr    = cidrsubnet(var.vpc_cidr, 8, 0)  # First /24 subnet
  private_subnet_cidr   = cidrsubnet(var.vpc_cidr, 8, 1)  # Second /24 subnet
}

# Label module for public subnet
module "label_public_subnet" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "subnet"
  attributes = ["public"]
}

# Label module for private subnet
module "label_private_subnet" {
  source     = "cloudposse/label/null"
  version    = "0.25.0"
  context    = module.base_label.context
  name       = "subnet"
  attributes = ["private"]
}

# Define the public subnet resource
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = local.az
  tags                    = module.label_public_subnet.tags
}

# Define the private subnet resource
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidr
  availability_zone = local.az
  tags              = module.label_private_subnet.tags
}

# Define the Internet Gateway resource
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = module.label_vpc.tags
}

# Define the Route Table resource for the public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = module.label_public_subnet.tags
}

# Associate the public subnet with the Route Table
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
