#    Copyright 2017 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#    Licensed under the Apache License, Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at
#
#        http://aws.amazon.com/apache2.0/
#
#    or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.


import boto3
import os
ec2 = boto3.client('ec2')
ssm = boto3.client('ssm')
tags ={'Key': os.environ['Tagname'], 'Value': os.environ['Tagvalue']}

def find_viable_window ():
    #checks if the Tag Key value pair matches with an existing Maintenance Window
    wins = ssm.describe_maintenance_windows()['WindowIdentities']
    for win in wins:
        tgts = ssm.describe_maintenance_window_targets(WindowId=win['WindowId'])['Targets']
        for tgt in tgts:
            t = tgt['Targets'][0]['Key'].split(':')
            v = tgt['Targets'][0]['Values'][0]
            if len(t) > 1 and t[0] == 'tag' and t[1] == tags['Key'] and v == tags['Value']:
                return True;
    return False;


def lambda_handler(event, context):
    volume =(event['resources'][0].split('/')[1])
    if event['detail']['result'] == 'completed':
        attach=ec2.describe_volumes(VolumeIds=[volume])['Volumes'][0]['Attachments']
        if attach: 
            instance = attach[0]['InstanceId']
            filter={'key': 'InstanceIds', 'valueSet': [instance]}
            info = ssm.describe_instance_information(InstanceInformationFilterList=[filter])['InstanceInformationList']
            if info:
                ec2.create_tags(Resources=[instance],Tags=[tags])
                if not find_viable_window():
                    print "WARNING: the proposed tags {0} : {1} are not a valid target in any maintenance window \n The changes will not be automatically applied".format(tags['Key'],tags['Value'])
                print "{0} Instance {1} has been tagged for maintenance".format(info[0]['PlatformName'], instance)
            else:
                raise Exception('Instance ' + instance + ' is not managed through SSM')
        else:
            raise Exception('Volume ' + volume + ' not currently attached to an instance')
    else:
        print "Change to the Volume {0} is not yet completed; instance will not be tagged for maintenance".format(volume)