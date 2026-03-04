resource "aws_ebs_volume" "volume_supp" {
  availability_zone = aws_instance.wp_server.availability_zone
  size              = 20
  type              = "gp3"
  encrypted         = true
  kms_key_id        = var.ebs_kms_key_arn

  tags = {
    Name = "Volume-Extra-T3"
  }
}

resource "aws_volume_attachment" "ebs_att" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.volume_supp.id
  instance_id = aws_instance.wp_server.id
}
