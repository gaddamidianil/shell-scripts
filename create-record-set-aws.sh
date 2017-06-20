#!/bin/bash
############################################################################################################################################################### Description: This Script creates the record set using alias type as LoadBalancer, user inputs required to process this script.
#		
# Prequisites: To execute this script AWS credentials need to be exported to the terminal.
#              This scripts uses kubectl command and need to have its credentials.
# 
# Author: Anil Gaddamidi
# Date: 10/17/2016
# Usage: ./create-record-set.sh
#	 Prompts fro user input for Hosted_Zone_ID, ELB and Canonical ID for Loadbalancer.
##############################################################################################################################################################


echo "Below are the available Hosted Zone Id and Names. Please use it to create a record set(domain name for ELB)"

aws route53 list-hosted-zones-by-name | grep -E 'Id|Name' | sed 's/\/hostedzone//g' | tr -d '/,"'  2>&1

if [[ $? -ne 0 ]] ; then
	echo "Not able to list the hosted zones, pls check aws cli access"
	exit 1
fi

echo " "

echo -e "Please enter the Hosted_Zone_Id below to create a record set: \t"
read HOSTED_ZONE_ID
 
  if [[ -z $HOSTED_ZONE_ID ]] ; then

    echo "Error: Hosted Zone cannot be empty" 
    exit
  fi

EXISTING_LBS=()
for i in $( aws route53 list-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID  | grep 'DNSName' | awk '{print $2}' | tr -d '"' 1>/dev/null 2>&1)
do
  EXISTING_LBS+=( ${i#*.} )
done


for i in $(kubectl --kubeconfig=kubeconfig get services|awk '{print $1}'| grep -v "NAME"); do
  if kubectl --kubeconfig=kubeconfig describe  services $i | grep "LoadBalancer Ingress:" 1>/dev/null 2>&1
  then
     echo -e "The service $i has following loadbalancer:"
  kubectl --kubeconfig=kubeconfig describe  services $i | grep "LoadBalancer Ingress:" | sed 's/$/./' 
     echo " "
  fi
done

echo "==========================================="
echo -e "Please Enter the Load Balancer Name: \t "
read USER_LB
  if [[ -z $USER_LB ]] ; then

    echo "Error: Service Loadalancer cannot be empty, try again"
    exit
  fi
found=false
for LB in ${EXISTING_LBS[@]}; do
  if [[ "${USER_LB}" == "${LB}" ]] ; then
	
    #echo "Existing LB: $EXISTING_LBS"
    echo "ERROR : The Load Balancer $USER_LB is used already.. Pls Try Again"
    found=true
  fi
done

if ! $found ; then
echo "=============================="
echo -e "Enter the Domain Name only (Example: domainname.recordset.com.i -- default recordset will be qcl2net.com.\t"

read RECORD_SET_NAME
echo "FYI: Record would be created as below:"
rset=$RECORD_SET_NAME
echo $rset.qcl2net.com.

echo "=============================="
aws elb describe-load-balancers | grep -E 'CanonicalHosted' | tr -d '",' 
echo "Select the Canonical Hosted Zone ID from above list to corresponding loadbalancer given above"
read CANONICAL_ZONE_ID
#echo "Preparing json file.. Pls wait"

cat > alias-record-set.json <<EOF
{
  "Comment": "optional comment about the changes in this change batch request",
  "Changes": [
    {
      "Action": "CREATE",
      "ResourceRecordSet": {
        "Name": ${RECORD_SET_NAME},
        "Type": "A",
        "AliasTarget": {
          "HostedZoneId": ${CANONICAL_ZONE_ID},
          "DNSName": ${USER_LB},
          "EvaluateTargetHealth": false
        }
      }
    }

  ]
}
~
EOF


echo "Creating record set...pls wait !! "
sleep 3
aws route53 change-resource-record-sets --hosted-zone-id $HOSTED_ZONE_ID --change-batch file:./alias-record-set.json

  if [[ $? -eq 0 ]] ; then
	echo "Record set successfully created !!"
  fi

fi
