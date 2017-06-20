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
# Usage: ./sg-revoke-rule.sh
#	 Prompts for user user input for service name
#############################################################################################################################################################  


#Will fetch only application services, not the infra. Services can be ignored based on requirement

aws ec2 describe-instances > /dev/null 2>&1
RESULT=$?

if [ $RESULT -eq 0 ]; then


kubectl --kubeconfig=kubeconfig get services | awk '{print $1}' | egrep -v 'redis|mongo|kubernetes|node-exporter|prometheus|rabbitmq' > /tmp/services.txt
sed 1d /tmp/services.txt > /tmp/services1.txt 

echo -e "Services available:\n`cat /tmp/services1.txt`"
echo "Please select the particular service from above list to revoke ICMP rule"
read SERVICE

if [[ -z "$SERVICE" ]]
then
  echo "Service cannot be empty, Input required"
  echo "Please enter the service"
  read SERVICE
elif [[ -z "$SERVICE" ]] 
then
  echo "Quitting !!"
fi

i=0

while read SERVICES 
do
  if [[ "$SERVICE" == "$SERVICES" ]] 
  then
GROUP_ID=$(aws ec2 describe-security-groups | grep -A5 `kubectl --kubeconfig=kubeconfig describe service $SERVICE | grep "Ingress" | cut -d ':' -f2 |cut -c1-33` | grep "GroupId" | awk '{print $2}' | tr -d '"') 2> /dev/null

echo "Service entered exists in the deployed services..executing revoke command"
sleep 1

aws ec2 revoke-security-group-ingress --group-id $GROUP_ID --ip-permissions '[{"IpProtocol": "icmp", "FromPort": 3, "ToPort": 4, "IpRanges": [{"CidrIp": "0.0.0.0/0"}]}]' > /dev/null 2>&1
  
  if [[ $? -eq 0 ]] ; then
    echo "Successfully revoked the rule from security-group: $GROUP_ID"
    else 
    echo "The specified rule(ICMP) does not exist in this security group. exit code $?"	
  fi

    exit 
  else
    let i++
  fi
done < /tmp/services1.txt

  if ! [[ "${i}" == "0" ]] ; then
  echo "Invalid input, pls try again"
  fi

else 
echo "Error: Problem with AWS login or related as above, export AWS cli credentials and try again."

fi 

