provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_security_group" "security_group" {
  name   = "${var.security_group}"
  vpc_id = "${var.vpc_id}"

  # ssh
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # mongodb
  ingress {
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # mongodb_shardsrv
  ingress {
    from_port   = 27018
    to_port     = 27018
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # mongodb_configsrv
  ingress {
    from_port   = 27019
    to_port     = 27019
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.security_group}"
  }
}

data "template_file" "user_data" {
  template = "${file("${path.module}/templates/user-data.sh")}"

  vars {
    node_number = "${count.index}"
    region      = "${var.region}"
    domain      = "${var.domain_name}"
  }
}

resource "aws_instance" "mongodb" {
  ami                    = "${lookup(var.amis, lookup(var.os_versions, "default"))}"
  instance_type          = "${lookup(var.instance_types, "mongodb")}"
  vpc_security_group_ids = ["${aws_security_group.security_group.id}"]
  key_name               = "${var.key_name}"
  subnet_id              = "${var.vpc_subnets[count.index]}"
  availability_zone      = "${var.zones[count.index]}"
  user_data              = "${data.template_file.user_data.rendered}"

  ebs_block_device {
    device_name           = "/dev/sdh"
    volume_size           = 1024
    volume_type           = "gp2"
    delete_on_termination = true
  }

  tags = {
    Name  = "mongodb${count.index}"
    App   = "${var.tag_app}"
    Env   = "${var.tag_env}"
    Owner = "${var.tag_owner}"
  }

  connection {
    type        = "ssh"
    user        = "${lookup(var.users, lookup(var.amis, lookup(var.os_versions, "default")))}"
    private_key = "${file(var.key_file)}"
  }

  provisioner "file" {
    source      = "prepareenv"
    destination = "/tmp/prepareenv"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/prepareenv/bootstrap.sh",
      "sudo /tmp/prepareenv/bootstrap.sh",
    ]
  }

  count = "${var.count_instances}"
}

resource "aws_route53_record" "mongodb" {
  count   = "${var.count_instances}"
  zone_id = "${var.hosted_zoneid}"
  name    = "mongodb${count.index}.${var.region}"
  type    = "A"
  ttl     = 60
  records = ["${element(aws_instance.mongodb.*.private_ip, count.index)}"]
}

output "private_ip_mongodb" {
  value = "${join(",", aws_instance.mongodb.*.private_ip)}"
}

output "route53_records_mongodb" {
  value = "${join(",", aws_route53_record.mongodb.*.fqdn)}"
}
