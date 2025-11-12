import boto3
import json
import os
import logging
from botocore.exceptions import ClientError
from ipaddress import ip_network

# Logger Configuration
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize clients outside the handler.
try:
    ec2_client = boto3.client('ec2')
    dynamodb_client = boto3.client('dynamodb')

    DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']
    PROJECT_TAG = os.environ.get('PROJECT_NAME', 'VpcApiDemo')
except KeyError as e:
    logger.error(f"Environment variable not defined: {e}")


def lambda_handler(event, context):
    """
    Main entry point. Receives the payload from the Step Function.
    Creates VPC with public and private subnets (with ONE NAT Gateway)
    spread across all Availability Zones.

    Cost Savings Logic:
    1. Creates 1 NAT Gateway in the first public subnet.
    2. Creates 1 Private Routing Table.
    3. Associates all private subnets with this 1 table.
    """
    logger.info(f"Event received: {json.dumps(event)}")
    job_id = event['job_id']
    vpc_cidr = event['cidr']

    try:
        # 1. Mark with RUNNING
        update_status(job_id, 'RUNNING')

        # 2. Discovery AZs available
        az_response = ec2_client.describe_availability_zones(
            Filters=[{'Name': 'state', 'Values': ['available']}]
        )
        availability_zones = [az['ZoneName'] for az in az_response['AvailabilityZones']]
        az_count = len(availability_zones)

        if az_count == 0:
            raise ValueError("No 'available' Availability Zone found.")

        logger.info(f"Found {az_count} AZs: {availability_zones}")

        # 3. CIDR block calculations
        vpc_network = ip_network(vpc_cidr)
        try:
            allocated_blocks = list(vpc_network.subnets(prefixlen_diff=1))
            public_cidr_block = allocated_blocks[0]
            private_cidr_block = allocated_blocks[1]
        except Exception as e:
            msg = (f"CIDR of VPC {vpc_cidr} is too small to be divided in two. "
                   f"Error: {e}")
            raise ValueError(msg)

        logger.info(f"Public subnet block: {public_cidr_block}")
        logger.info(f"Private subnet block: {private_cidr_block}")

        subnet_prefix_diff = (az_count - 1).bit_length()
        public_subnet_prefix = public_cidr_block.prefixlen + subnet_prefix_diff
        private_subnet_prefix = private_cidr_block.prefixlen + subnet_prefix_diff

        if public_subnet_prefix > 28:
            msg = (f"Many AZs ({az_count}) to divide the block "
                   f"{public_cidr_block}. The subnets would be smaller than /28."
                   )
            raise ValueError(msg)

        public_subnets_iter = public_cidr_block.subnets(
            new_prefix=public_subnet_prefix)
        private_subnets_iter = private_cidr_block.subnets(new_prefix=private_subnet_prefix)

        # 4. Create a VPC
        vpc_response = ec2_client.create_vpc(CidrBlock=vpc_cidr)
        vpc_id = vpc_response['Vpc']['VpcId']
        add_tags(vpc_id, f"{PROJECT_TAG}-{job_id}-VPC")
        ec2_client.get_waiter('vpc_available').wait(VpcIds=[vpc_id])
        logger.info(f"VPC {vpc_id} created.")

        # 5. Create Internet Gateway
        igw_response = ec2_client.create_internet_gateway()
        igw_id = igw_response['InternetGateway']['InternetGatewayId']
        add_tags(igw_id, f"{PROJECT_TAG}-{job_id}-IGW")
        ec2_client.attach_internet_gateway(InternetGatewayId=igw_id, VpcId=vpc_id)
        logger.info(f"IGW {igw_id} created and attached.")

        # 6. Create a PUBLIC Routing Table (Only one)
        public_rt_response = ec2_client.create_route_table(VpcId=vpc_id)
        public_rt_id = public_rt_response['RouteTable']['RouteTableId']
        add_tags(public_rt_id, f"{PROJECT_TAG}-{job_id}-Public-RT")

        # Add route to IGW
        ec2_client.create_route(
            RouteTableId=public_rt_id,
            DestinationCidrBlock='0.0.0.0/0',
            GatewayId=igw_id
        )
        logger.info(f"Public route table {public_rt_id} created with route "
                    f"to IGW.")

        # 7. Loop 1: Create all Subnets
        public_subnet_ids = []
        private_subnet_ids = []
        first_public_subnet_id = None

        for i, az_name in enumerate(availability_zones):

            # --- Public Subnet ---
            public_subnet_cidr = str(next(public_subnets_iter))
            pub_subnet_response = ec2_client.create_subnet(
                VpcId=vpc_id,
                CidrBlock=public_subnet_cidr,
                AvailabilityZone=az_name
            )
            pub_subnet_id = pub_subnet_response['Subnet']['SubnetId']
            add_tags(pub_subnet_id,
                     f"{PROJECT_TAG}-{job_id}-Public-Subnet-{i+1}-{az_name}")

            ec2_client.associate_route_table(RouteTableId=public_rt_id,
                                             SubnetId=pub_subnet_id)
            ec2_client.modify_subnet_attribute(
                SubnetId=pub_subnet_id,
                MapPublicIpOnLaunch={'Value': True})
            public_subnet_ids.append(pub_subnet_id)
            logger.info(f"Public Subnet {pub_subnet_id} ({public_subnet_cidr}) "
                        f"on {az_name} created.")

            # Store the ID of the first public subnet for the NAT Gateway.
            if i == 0:
                first_public_subnet_id = pub_subnet_id

            # --- Private Subnet ---
            private_subnet_cidr = str(next(private_subnets_iter))
            priv_subnet_response = ec2_client.create_subnet(
                VpcId=vpc_id,
                CidrBlock=private_subnet_cidr,
                AvailabilityZone=az_name
            )
            priv_subnet_id = priv_subnet_response['Subnet']['SubnetId']
            add_tags(
                priv_subnet_id,
                f"{PROJECT_TAG}-{job_id}-Private-Subnet-{i+1}-{az_name}")
            private_subnet_ids.append(priv_subnet_id)
            logger.info(f"Private Subnet {priv_subnet_id} ({private_subnet_cidr}) "
                        f"on {az_name} created.")

        # --- 8. Create the SINGLE NAT Gateway ---
        if not first_public_subnet_id:
            raise ValueError("No public subnet was created to host the NAT " +
                             "Gateway.")
        eip_response = ec2_client.allocate_address(Domain='vpc')
        eip_alloc_id = eip_response['AllocationId']
        logger.info(f"EIP {eip_alloc_id} allocated to the single NAT Gateway.")

        nat_gw_response = ec2_client.create_nat_gateway(
            SubnetId=first_public_subnet_id,
            AllocationId=eip_alloc_id
        )
        nat_gw_id = nat_gw_response['NatGateway']['NatGatewayId']
        add_tags(nat_gw_id, f"{PROJECT_TAG}-{job_id}-NAT-GW-Single")
        logger.info(f"Single NAT Gateway {nat_gw_id} creating on subnet "
                    f"{first_public_subnet_id}...")

        # --- 9. Create a PRIVATE Routing Table (Only one) ---
        private_rt_response = ec2_client.create_route_table(VpcId=vpc_id)
        private_rt_id = private_rt_response['RouteTable']['RouteTableId']
        add_tags(private_rt_id, f"{PROJECT_TAG}-{job_id}-Private-RT")

        # Loop 2: Associate all private subnets with a single private routing table.
        for priv_subnet_id in private_subnet_ids:
            ec2_client.associate_route_table(
                RouteTableId=private_rt_id,
                SubnetId=priv_subnet_id
            )
        logger.info(f"All {len(private_subnet_ids)} private subnets associated "
                    f"on private RT {private_rt_id}.")

        # --- 10. Wait for NAT Gateway and Add Single Private Route ---
        try:
            logger.info(f"Waiting NAT Gateway {nat_gw_id} to become "
                        f"'available'...")
            ec2_client.get_waiter('nat_gateway_available').wait(
                NatGatewayIds=[nat_gw_id])
            logger.info(f"NAT Gateway {nat_gw_id} is 'available'.")
        except ClientError as e:
            logger.error(f"Failed to wait for NAT Gateway {nat_gw_id}. {e}")
            raise Exception(f"NAT Gateway {nat_gw_id} failed to become "
                            "'available'.")

        ec2_client.create_route(
            RouteTableId=private_rt_id,
            DestinationCidrBlock='0.0.0.0/0',
            NatGatewayId=nat_gw_id
        )
        logger.info(f"Route for NAT GW {nat_gw_id} added on private RT {private_rt_id}.")

        # 11. Sucess! Update DynamoDB
        results = {
            'vpc_id': vpc_id,
            'internet_gateway_id': igw_id,
            'public_route_table_id': public_rt_id,
            'public_subnet_ids': public_subnet_ids,
            'private_subnet_ids': private_subnet_ids,
            'private_route_table_id': private_rt_id,
            'nat_gateway_id': nat_gw_id,
            'availability_zones_used': availability_zones
        }
        update_status(job_id, 'COMPLETE', results=results)

        return results

    except Exception as e:
        logger.error(f"VPC creation failed for the job {job_id}: {e}")
        # Failed! Update DynamoDB
        update_status(job_id, 'FAILED', error_message=str(e))
        # Propagate the error to cause the Step Function to fail.
        raise e


def add_tags(resource_id, name):
    """Utility function for adding tags (Name and Project)"""
    ec2_client.create_tags(
        Resources=[resource_id],
        Tags=[
            {'Key': 'Name', 'Value': name},
            {'Key': 'Project', 'Value': PROJECT_TAG}
        ]
    )


def update_status(job_id, status, results=None, error_message=None):
    """
    Utility function to update the job status in DynamoDB.
    """
    logger.info(f"Updating job {job_id} for status {status}")

    update_expression = "SET #status = :status_val"
    expression_attr_names = {"#status": "status"}
    expression_attr_values = {":status_val": {"S": status}}

    if results:
        update_expression += ", #results = :results_val"
        expression_attr_names["#results"] = "results"
        expression_attr_values[":results_val"] = {"S": json.dumps(results)}

    if error_message:
        update_expression += ", #error = :error_val"
        expression_attr_names["#error"] = "error_message"
        expression_attr_values[":error_val"] = {"S": error_message}

    try:
        dynamodb_client.update_item(
            TableName=DYNAMODB_TABLE,
            Key={'job_id': {'S': job_id}},
            UpdateExpression=update_expression,
            ExpressionAttributeNames=expression_attr_names,
            ExpressionAttributeValues=expression_attr_values
        )
    except ClientError as e:
        logger.error(f"It was not possible to update the status in DynamoDB "
                     f"for the job {job_id}: {e}")
        