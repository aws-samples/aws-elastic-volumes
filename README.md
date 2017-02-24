# aws-elastic-volumes
Sample code to help with Elastic Block Store automation with Elastic Volumes feature

##Installation
refer to the [SETUP.md](Docs/SETUP.md) document in the Docs/ folder for the setup instructions

## Lambda Function
### tag_instance.py
The function which will be invoked through a Cloudwatch Event on the EBS modifyVolume API.

####Sample Event

```javascript
{
  "source": [
    "aws.ec2"
  ],
  "detail-type": [
    "EBS Volume Notification"
  ],
  "detail": {
    "event": [
      "modifyVolume"
    ]
  }
}
```

The function parses the volume ID from the resource ARN recorded in the request, gather the Instance Id and performs the following checks on it before tagging it for maintenance.
#### Checks currently performed
1. The volume is attached to an EC2 instance
2. The instance can be managed by EC2 Systems Manager
3. The Tags provided are defined as viable targets by at least one maintenance window.
4. Tag the instance only if "result": "completed" is provided in the triggering event (no action will be done otherwise) 

The maintenance tag and its value are configurable through Lambda Environment variables.

The Function will succeed with an empty return and an entry in the Cloudwatch Log, succeed with warning if [3] or it will raise an Exception if [1] or [2].

### lambda_role.json
IAM policy to attach to the Lambda execution role to grant the minimum viable permissions to perform the checks and tag the instance.

```javascript
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents"
            ],
            "Resource": "arn:aws:logs:*:*:*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVolumes",
                "ec2:CreateTags",
                "ssm:DescribeInstanceInformation",
                "ssm:DescribeMaintenanceWindows",
                "ssm:DescribeMaintenanceWindowTargets"
            ],
            "Resource": "*"
        }
    ]
}
```
### test_event.json
Sample event to test the lambda setup (replace ACCOUNT\_ID and VOLUME\_ID with the proper values)

```javascript
{
    "version": "0",
    "id": "16553020-c85a-44f2-a3bb-0baab6854e22",
    "detail-type": "EBS Volume Notification",
    "source": "aws.ec2",
    "account": "ACCOUNT_ID",
    "time": "2017-02-20T09:00:00Z",
    "region": "us-east-1",
    "resources": [
    "arn:aws:ec2:us-east-1:ACCOUNT_ID:volume/VOLUME_ID"
    ],
    "detail": {
    "result": "completed",
    "cause": "",
    "event": "modifyVolume",
    "request-id": "35636c36-8126-435d-b891-78a8471a4c3d"
    }
}
```

## EC2 Systems Manager Document
To set up as Task for the maintenance window targeting the EC2 instances with the maintenance tags 

### Set-MaximumPartitionSize.ps1
PowerShell script that checks for online volumes, partitions, and assigned drive letter. Then checks for max size achievable (if the volume has been resized) and extend all the drives if possible.

### Set-MaximumPartitionSize.ps1_encoded.json
Script encoded as a Systems Manager Document (schema Version 2.0).


