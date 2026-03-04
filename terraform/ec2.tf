data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] 

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_instance" "wp_server" {
  availability_zone           = "${var.aws_region}a"
  ami                         = data.aws_ami.ubuntu.id
  iam_instance_profile        = var.iam_instance_profile
  instance_type               = var.instance_type
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.wp_sg.id]
  associate_public_ip_address = true
  user_data_replace_on_change = true
  
  monitoring                  = true
  ebs_optimized               = true

  user_data = templatefile("${path.module}/scripts/user_data.sh", {
    mount_point            = var.mount_point
    db_user                = var.db_user
    db_password            = var.db_password
    db_name                = var.db_name
    db_root_password       = var.db_root_password

    docker_compose_content     = file("${path.module}/../docker-compose-wordpress.yml")
    monitoring_compose_content = file("${path.module}/../docker-compose-monitoring.yml") 
  })


  tags = {
    Name = "WordPress-DevSecOps"
  }

  root_block_device {
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = false
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}


resource "aws_eip" "wp_eip" {
  domain = "vpc"
  tags = {
    Name = "wp-server-eip"
  }
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = aws_instance.wp_server.id
  allocation_id = aws_eip.wp_eip.id
}

output "wordpress_public_ip" {
  value       = aws_eip.wp_eip.public_ip
}
