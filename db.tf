data "aws_route53_zone" "zone" {
  name = var.domain
}

data "aws_db_snapshot" "latest" {
  db_instance_identifier = var.parent
  most_recent            = true
}

data "aws_db_instance" "current" {
  db_instance_identifier = var.parent
}

resource "aws_db_instance" "snapshot" {
  identifier              = var.name
  snapshot_identifier     = data.aws_db_snapshot.latest.id
  apply_immediately       = true
  skip_final_snapshot     = true
  publicly_accessible     = true
  storage_encrypted       = data.aws_db_instance.current.storage_encrypted
  allocated_storage       = data.aws_db_instance.current.allocated_storage
  instance_class          = data.aws_db_instance.current.db_instance_class
  db_subnet_group_name    = aws_db_subnet_group.snapshot.name
  vpc_security_group_ids  = [aws_vpc.snapshot.default_security_group_id]
  backup_retention_period = 0
  maintenance_window      = "mon:18:00-mon:20:00"
}

resource "aws_db_subnet_group" "snapshot" {
  name       = var.name
  subnet_ids = aws_subnet.routed.*.id
}

resource "aws_route53_record" "record" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = format("%s.%s", var.name, var.domain)
  type    = "CNAME"
  ttl     = 600
  records = [aws_db_instance.snapshot.address]
}
