# Mongodb cluster deployment using terraform


This HOWTO covers automated creation of AWS instances for 3-node MongoDB clusters such as security groups, instances creation and Route53 records. 


# Requirements for setup
  - Tools used terraform, docker and docker-compose.
  - AWS VPC with tree private subnets, access via bastion SSH server.
  - Domain Name under Route53 Hosted Zone.
  - Key Pair "{your iam user}.pem" if you don't have please create.
  - Access rights to create EC2 instances, Security Groups, Route53 Records, EBS Volumes etc.


### Preparation 


Terraform installation for linux machine 

```sh
$ git clone https://github.com/rayman-g/mongo-aws.git
$ cd mongo-aws
$ curl -O https://releases.hashicorp.com/terraform/0.11.6/terraform_0.11.6_linux_amd64.zip
$ unzip terraform_0.11.6_linux_amd64.zip 
$ ./terraform  --version
Terraform v0.11.6

Your version of Terraform is out of date! The latest version
is 0.11.8. You can update by downloading from www.terraform.io/downloads.html
```


Initialize Terraform plugin used in deployment

```sh
$ ./terraform init

Initializing provider plugins...
- Checking for available provider plugins on https://releases.hashicorp.com...
- Downloading plugin for provider "aws" (1.36.0)...
- Downloading plugin for provider "template" (1.0.0)...
* provider.aws: version = "~> 1.36"
* provider.template: version = "~> 1.0"
Terraform has been successfully initialized!
```

### Configure AWS variables 


terraform.tfvars - holds sensitive information such as AWS access keys, VPC id's

```sh
cat terraform.tfvars
access_key="XXXXXXXXXXXXXXXXXXXX"
secret_key="XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
vpc_id="vpc-XXXXXXX"
key_name="XXXXXXXX"
key_file="/home/user/key_name.pem"
tag_owner="user"
domain_name="test.net"
# Zone ID of domain "test.net"
hosted_zoneid="Z3ANYTDAKQQQS"
# Number of instances to create
count_instances=3
```


variables.tf - holds general information such as types of instances, tag names, AMI's etc

```sh
cat variables.tf
variable "access_key" {}
variable "secret_key" {}
variable "key_file" {}
variable "key_name" {}
variable "vpc_subnet_id" {}
variable "vpc_id" {}
variable "tag_owner" {}
variable "hosted_zoneid" {}
variable "domain_name" {}
variable "count_instances" {}

variable "vpc_subnets" {
  default = ["subnet-123", "subnet-456", "subnet-789"]
}
variable "zones" {
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
variable "tag_app" {
  default = "mongodb"
}
variable "tag_env" {
  default = "development"
}
variable "region" {
  default = "us-east-1"
}
variable "instance_types" {
  default = {
    mongodb = "t2.small"
  }
}
variable "os_versions" {
  default = {
    default = "centos-7"
  }
}
variable "security_group" { 
  default = "mongodb-group"
}
variable "amis" {
  # for us-east-1 region
  default = {
    centos-7 = "ami-9887c6e7" # CentOS Linux 7 x86_64 HVM EBS ENA 1805_01
  }
}
variable "users" {
  default = {
    ami-9887c6e7 = "centos"
  }
}
```

# Repository folder sturcture 


prepareenv - copied to ec2 instances to provision them intall docker, docker-compose and build and start mongodb containers
files - used for docker build 
templates - user-data script to format fs on a additional EBS volume


```sh
├── main.tf
├── prepareenv
│   ├── bootstrap.sh
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── files
│     └── mongodb-org-3.4.repo
├── templates
│   └── user-data.sh
├── terraform
├── terraform.tfvars
└── variables.tf
```

### To change Mongodb Version


You can adjust version in files/mongodb-org-3.4.repo 

```sh
files/mongodb-org-3.4.repo 
[mongodb-org-3.4]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/3.4/x86_64/
gpgcheck=0
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-3.4.asc
```

### Mongodb Dockerfile and Compose


Dockerfile

```sh
prepareenv/Dockerfile 
FROM centos:centos7
COPY files/mongodb-org-3.4.repo /etc/yum.repos.d/mongodb-org-3.4.repo
RUN yum -y update; yum clean all
RUN yum install mongodb-org -y; yum clean all
EXPOSE 27017
```


Docker compose

```sh
prepareenv/docker-compose.yml 
version: '2'
services:
  mongodb:
    build: .
    ports:
      - "27017:27017"
    volumes:
       - /data/db:/data/db
       - /data/log:/data/log
    command: mongod --replSet rs01 --logpath "/data/log/mongodb.log" --dbpath /data/db --port 27017
    restart: always
```


### Deployment


Verify your deployment plan 
```sh
$ ./terraform plan
Plan: 7 to add, 0 to change, 0 to destroy.
------------------------------------------------------------------------
```


Execute deployment, this will create EC2 intances, install docker, build and start Mongodb containers


```sh
$ ./terraform apply -auto-approve
...
Omitting output
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

private_ip_mongodb = 10.124.43.61, 10.124.43.98, 10.124.43.108
route53_records_mongodb = mongodb0.us-east-1.test.net, mongodb1.us-east-1.test.net, mongodb2.us-east-1.test.net
```


You can check on a instance that docker compose build image and started mongodb container for three EC2 instances

```sh
[centos@ip-10-124-43-61 ~]$ docker ps
CONTAINER ID        IMAGE                COMMAND                  CREATED             STATUS              PORTS                                  NAMES
49e1377eb486        prepareenv_mongodb   "mongod --replSet ..."   4 minutes ago       Up 4 minutes        0.0.0.0:27017-27019->27017-27019/tcp   prepareenv_mongodb_1
```
Mongodb Data and Logs are stored on a attached EBS Volume

```sh
Filesystem      Size  Used Avail Use% Mounted on
/dev/xvdh        1024G  333M   1024G   1% /data

[centos@ip-10-124-43-61 ~]$ ls -R /data/
/data/db:
collection-0-7308211805043965240.wt  index-3-7308211805043965240.wt  sizeStorer.wt   
/data/db/journal:
WiredTigerLog.0000000001  WiredTigerPreplog.0000000001  WiredTigerPreplog.0000000002
/data/log:
mongodb.log 
```


### Verify your Mongdb Cluster


Enale replicaset 

```sh
$ mongo --host mongodb1.us-east-1.test.net --port 27017
rs.initiate(
  {
    _id: "rs01",
    configsvr: false,
    members: [
      { _id : 0, host : "mongodb0.us-east-1.test.net:27017" },
      { _id : 1, host : "mongodb1.us-east-1.test.net:27017" },
      { _id : 2, host : "mongodb2.us-east-1.test.net:27017" }
    ]
  }
)
{ "ok" : 1 }
```


Verify configuration 

```sh
rs01:SECONDARY> rs.conf()
{
	"_id" : "rs01",
	"version" : 1,
	"protocolVersion" : NumberLong(1),
	"members" : [
		{
			"_id" : 0,
			"host" : "mongodb0.us-east-1.test.net:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 1,
			"host" : "mongodb1.us-east-1.test.net:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		},
		{
			"_id" : 2,
			"host" : "mongodb2.us-east-1.test.net:27017",
			"arbiterOnly" : false,
			"buildIndexes" : true,
			"hidden" : false,
			"priority" : 1,
			"tags" : {
				
			},
			"slaveDelay" : NumberLong(0),
			"votes" : 1
		}
	],
	"settings" : {
		"chainingAllowed" : true,
		"heartbeatIntervalMillis" : 2000,
		"heartbeatTimeoutSecs" : 10,
		"electionTimeoutMillis" : 10000,
		"catchUpTimeoutMillis" : 60000,
		"getLastErrorModes" : {
			
		},
		"getLastErrorDefaults" : {
			"w" : 1,
			"wtimeout" : 0
		},
		"replicaSetId" : ObjectId("5b9d09985a86384ec3486c79")
	}
}
```

### Connect to Mongodb ReplicaSet 

```sh
mongo --host rs01/mongodb0.us-east-1.test.net,mongodb1.us-east-1.test.net,mongodb2.us-east-1.test.net --port 27017 
MongoDB shell version v3.4.17
s01:PRIMARY> show dbs
admin  0.000GB
local  0.000GB
port   0.000GB
```

### Destroy Cluster

If you don't need Mongodb cluster anymore, destroy it

```sh
$ ./terraform destroy -auto-approve
aws_instance.mongodb.1: Still destroying... (ID: i-01e7bb5eea23edfe3, 1m10s elapsed)
aws_instance.mongodb[1]: Destruction complete after 1m18s
aws_instance.mongodb[2]: Destruction complete after 1m18s
aws_security_group.security_group: Destroying... (ID: sg-08aa0eea8846dc4de)
aws_security_group.security_group: Destruction complete after 2s

Destroy complete! Resources: 7 destroyed.
```


