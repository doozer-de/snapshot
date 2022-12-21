data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "snapshot" {
  cidr_block           = "172.17.0.0/16"
  enable_dns_hostnames = true
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "postgres" {
  for_each          = var.ingress
  type              = "ingress"
  from_port         = 5432
  to_port           = 5432
  protocol          = "tcp"
  cidr_blocks       = [each.value]
  description       = each.key
  security_group_id = aws_vpc.snapshot.default_security_group_id
}

resource "aws_subnet" "routed" {
  count             = length(data.aws_availability_zones.available.names)
  vpc_id            = aws_vpc.snapshot.id
  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.snapshot.cidr_block, 8, count.index + 1 + length(data.aws_availability_zones.available.names))
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_internet_gateway" "egress" {
  vpc_id = aws_vpc.snapshot.id
}

resource "aws_route_table" "routed" {
  count  = length(aws_subnet.routed.*.id)
  vpc_id = aws_vpc.snapshot.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.egress.id
  }
}

resource "aws_route_table_association" "routed" {
  count          = length(aws_subnet.routed.*.id)
  subnet_id      = element(aws_subnet.routed.*.id, count.index)
  route_table_id = element(aws_route_table.routed.*.id, count.index)
}
