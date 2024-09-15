provider "aws" {
    region="us-west-2"
    access_key=""
    secret_key=""
}

#vars
variable "vpc_cidr_block" {
        description="vpc cidr block"    

}

variable "subnet_cidr_block"{}
variable "env" {}
variable "avail_zone" {}
variable "my-ip" {}
variable "instance_type" {}

resource "aws_vpc" "vpc" {
    cidr_block=var.vpc_cidr_block  #"10.0.0.0/16"
    tags={

      Name="${var.env}-vpc"
    }
}

resource "aws_subnet" "subnet" {
    vpc_id= aws_vpc.vpc.id
    cidr_block=var.subnet_cidr_block  #"10.0.0.0/24"
    availability_zone=var.avail_zone   #"us-west-2a"

    tags={

      Name="${var.env}-subnet"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id= aws_vpc.vpc.id
    tags={
       Name="${var.env}-igw"
    }

}

resource "aws_route_table" "route-table" {  
    vpc_id= aws_vpc.vpc.id
    route{
        cidr_block="0.0.0.0/0" #anyone can enter this vpc through the igw using rt
        gateway_id=aws_internet_gateway.igw.id
    }
    tags={
        Name="${var.env}-rt"

    }

}

#to map the dev-subnet to the new route table
resource "aws_route_table_association" "subnet-rt" {  #the subnet is mapping to the rt and the rt is mapping to gw
    subnet_id=aws_subnet.subnet.id
    route_table_id=aws_route_table.route-table.id
}

#creating sec group in vpc to attcavh it in ec2
#creating sec group in vpc to attcavh it in ec2
resource "aws_security_group" "sec-grp" {
    name = "${var.env}-sec-grp"
    vpc_id = aws_vpc.vpc.id
    ingress {
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.my-ip]
    protocol    = "tcp"
    }
    ingress {
    from_port   = 8080
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
    protocol    = "tcp"
    }
    tags = {
        Name = "${var.env}-sec-grp"
    } 
    egress{
        from_port=0
        to_port=0
        cidr_blocks=["0.0.0.0/0"] #anyone from ec2 can access the outside the nw (allow all outpound traffic)
        protocol= "-1"
        prefix_list_ids=[]   #anyone from ec2 can access any endpoint
    }
}
# we need to fetch the ami of ec2 using data to be compatible with any region
data "aws_ami" "amazon-machine-image"{
    most_recent= true #to fetch the newest image 
    owners=["amazon"]
    filter {
        name="name"
        values=["amzn2-ami-*-x86_64-gp2"]
    }
    filter {
        name="virtualization-type"
        values=["hvm"]
    }

}
output "aws_ami_id" {
    value=data.aws_ami.amazon-machine-image.id
}

#creating th ec2
resource "aws_instance" "ec2" {
    ami=data.aws_ami.amazon-machine-image.id
    instance_type=var.instance_type   #"t2.micro"
    subnet_id=aws_subnet.subnet.id
    vpc_security_group_ids=[aws_security_group.sec-grp.id]
    availability_zone=var.avail_zone   #"us-west-2a"
    associate_public_ip_address= true
    key_name=aws_key_pair.ssh-key.key_name        #"tfkey"
    user_data = <<-EOF
        #!/bin/bash
        sudo yum update -y
        sudo yum install docker -y
        sleep 30
        sudo systemctl start docker
        sudo systemctl enable docker
        sleep 10
        sudo chmod 666 /var/run/docker.sock
        sudo usermod -aG docker ec2-user
        sudo chown $USER /var/run/docker.sock
        sudo docker run -d --name my-nginx -p 8080:80  nginx
        sudo docker start my-nginx


    EOF
    tags={
        Name="${var.env}-server"   
    }

}

#generate key manual
resource "aws_key_pair" "ssh-key" {
    key_name="tfkey2"
    public_key=file("/home/nour/.ssh/id_rsa.pub")
}

output "ec2-public-ip" {
    value=aws_instance.ec2.public_ip
}