
/*
DMS RESOURCES (DISABLED AFTER MIGRATION)
--------------------------------------------------
These resources were used for database migration from EC2 to RDS.
To re-enable, set all count=0 parameters to count=1.
*/

# Security Group for DMS Replication Instance
resource "aws_security_group" "dms_sg" {
  count       = 0 # ← This prevents creation
  name        = "dms-sg"
  description = "Allow all outbound traffic for DMS Replication Instance"
  vpc_id      = var.vpc_id

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# DMS Replication Instance
resource "aws_dms_replication_instance" "dms_replication_instance" {
  count                        = 0 # ← This prevents creation
  replication_instance_id      = "dms-replication-instance"
  replication_instance_class   = "dms.t3.micro"
  allocated_storage            = 20 # Minimum storage for Free Tier
  publicly_accessible          = false
  multi_az                     = false # Single-AZ for Free Tier
  vpc_security_group_ids       = [aws_security_group.dms_sg[0].id]
  replication_subnet_group_id  = aws_dms_replication_subnet_group.dms_subnet_group[0].id

  tags = {
    Name = "dms-replication-instance"
  }
}

# Defined subnet in the specified VPC to create a replication instance
resource "aws_dms_replication_subnet_group" "dms_subnet_group" {
  count                                = 0 # ← This prevents creation
  replication_subnet_group_id          = "dms-subnet-group"
  replication_subnet_group_description = "DMS subnet group"
  subnet_ids                           = var.private_subnets
}

# Source Endpoint (EC2 Database)
# resource "aws_dms_endpoint" "source_endpoint" {
 #  count         = 0  
 #  endpoint_id   = "ec2"
 #  endpoint_type = "source"
 #  engine_name   = "postgres" # Specify the database engine (PostgreSQL)
 #  server_name   = aws_instance.ec2_instance.private_ip  # Use EC2 private IP directly
 #  port          = 5432
 #  username      = var.db_username
 #  password      = var.db_password
 # database_name = var.ec2_database_name # Replace with the EC2 database name
 #  ssl_mode      = "none"  # Explicitly set SSL mode
#}

# Target Endpoint (RDS Database)
resource "aws_dms_endpoint" "target_endpoint" {  
  count         = 0
  database_name = "mvp"
  endpoint_id   = "rds"
  endpoint_type = "target"
  engine_name   = "postgres"
  username      = var.db_username
  password      = var.db_password
  port          = 5432
  server_name   = aws_db_instance.mvp_db.address  
  ssl_mode      = "none"  
}

# DMS Replication Task
# resource "aws_dms_replication_task" "dms_replication_task" {
 # count                    = 0
 # replication_task_id      = "dms-replication-task"
 # migration_type           = "full-load" # Full-load replication
 # replication_instance_arn = aws_dms_replication_instance.dms_replication_instance[0].replication_instance_arn
 # source_endpoint_arn      = aws_dms_endpoint.source_endpoint[0].endpoint_arn
 # target_endpoint_arn      = aws_dms_endpoint.target_endpoint[0].endpoint_arn  # Updated reference
 # table_mappings           = <<EOF
 # {
  #  "rules": [
  #   {
  #      "rule-type": "selection",
  #     "rule-id": "1",
  #      "rule-name": "1",
  #      "object-locator": {
  #        "schema-name": "public",
  #        "table-name": "%"
  #      },
  #      "rule-action": "include"
  #    }
  # ]
 # }
 # EOF
# }
