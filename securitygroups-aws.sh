#!/bin/bash
#
# Description: This Script revoke the security group ingress ICMP rule with CIDR range: 0.0.0.0/0
#	        created by Kubernetes cluster stack services. 
# 	       GroupId is extracted from Pod Services LoadBalancer Security Group. 
# Prequisites: To execute this script AWS credentials need to be exported to the terminal. 
#	       This scripts uses kubectl command and need to have its credentials.
#
# Author: Anil Gaddamidi
# Date: 10/14/2016
#############################################################################################################################################################  


#Will fetch only application services, not the infra. Services can be ignored based on requirement
kubectl --kubeconfig=kubeconfig get services | awk '{print $1}' | egrep -v 'redis|mongo|kubernetes|node-exporter|prometheus|rabbitmq' > /tmp/services.txt
sed 1d /tmp/services.txt > /tmp/services1.txt 

while read SERVICE 
do

GROUP_ID=$(aws ec2 describe-security-groups | grep -A5 `kubectl --kubeconfig=kubeconfig describe service $SERVICE | grep "Ingress" | cut -d ':' -f2 |cut -c1-33` | grep "GroupId" | awk '{print $2}' | tr -d '"') 1>/dev/null 2>&1
echo $SERVICE
echo $GROUP_ID 

aws ec2 revoke-security-group-ingress --group-id $GROUP_ID --ip-permissions '[{"IpProtocol": "icmp", "FromPort": 3, "ToPort": 4, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]' 1>/dev/null 2>&1

if [[ $? -eq 0 ]] ; then
  echo "Removed the ICMP rule from the service sucessfully"
else 
  echo "Warning!: Services does not have ICMP rule in its security group $?"
fi

done < /tmp/services1.txt

exit 0


