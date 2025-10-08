import boto3
from typing import List, Dict, Any
from ..unified_manager import CloudProvider
import logging

logger = logging.getLogger(__name__)

class AWSProvider(CloudProvider):
    """Proveedor para Amazon Web Services"""

    def __init__(self, config: Dict[str, Any]):
        self.config = config
        self.ec2_client = None
        self.s3_client = None
        self.elb_client = None
        self.cost_client = None
        self._initialize_clients()

    def _initialize_clients(self):
        """Inicializa clientes de AWS"""
        try:
            session = boto3.Session(
                aws_access_key_id=self.config.get('access_key_id'),
                aws_secret_access_key=self.config.get('secret_access_key'),
                region_name=self.config.get('region', 'us-east-1')
            )

            self.ec2_client = session.client('ec2')
            self.s3_client = session.client('s3')
            self.elb_client = session.client('elbv2')
            self.cost_client = session.client('ce', region_name='us-east-1')  # Cost Explorer

        except Exception as e:
            logger.error(f"Error inicializando clientes AWS: {e}")
            raise

    def create_vm(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea instancia EC2"""
        try:
            response = self.ec2_client.run_instances(
                ImageId=kwargs.get('image_id', 'ami-0c55b159cbfafe1d0'),  # Amazon Linux 2
                MinCount=1,
                MaxCount=1,
                InstanceType=kwargs.get('instance_type', 't2.micro'),
                KeyName=kwargs.get('key_name'),
                SecurityGroupIds=kwargs.get('security_groups', []),
                TagSpecifications=[{
                    'ResourceType': 'instance',
                    'Tags': [
                        {'Key': 'Name', 'Value': name},
                        {'Key': 'ManagedBy', 'Value': 'Webmin-MultiCloud'}
                    ]
                }]
            )

            instance = response['Instances'][0]
            return {
                'id': instance['InstanceId'],
                'name': name,
                'provider': 'aws',
                'status': 'creating',
                'instance_type': instance['InstanceType'],
                'region': self.config.get('region')
            }

        except Exception as e:
            logger.error(f"Error creando VM en AWS: {e}")
            raise

    def list_vms(self) -> List[Dict[str, Any]]:
        """Lista instancias EC2"""
        try:
            response = self.ec2_client.describe_instances()
            instances = []

            for reservation in response['Reservations']:
                for instance in reservation['Instances']:
                    name_tag = next((tag['Value'] for tag in instance.get('Tags', [])
                                   if tag['Key'] == 'Name'), 'Unnamed')

                    instances.append({
                        'id': instance['InstanceId'],
                        'name': name_tag,
                        'provider': 'aws',
                        'status': instance['State']['Name'],
                        'instance_type': instance['InstanceType'],
                        'region': self.config.get('region'),
                        'public_ip': instance.get('PublicIpAddress'),
                        'private_ip': instance.get('PrivateIpAddress')
                    })

            return instances

        except Exception as e:
            logger.error(f"Error listando VMs en AWS: {e}")
            return []

    def delete_vm(self, vm_id: str) -> bool:
        """Termina instancia EC2"""
        try:
            self.ec2_client.terminate_instances(InstanceIds=[vm_id])
            return True
        except Exception as e:
            logger.error(f"Error eliminando VM {vm_id} en AWS: {e}")
            return False

    def create_storage(self, name: str, size_gb: int, **kwargs) -> Dict[str, Any]:
        """Crea bucket S3 o volumen EBS"""
        storage_type = kwargs.get('storage_type', 's3')

        if storage_type == 's3':
            return self._create_s3_bucket(name, **kwargs)
        elif storage_type == 'ebs':
            return self._create_ebs_volume(name, size_gb, **kwargs)
        else:
            raise ValueError(f"Tipo de almacenamiento {storage_type} no soportado")

    def _create_s3_bucket(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea bucket S3"""
        try:
            # Crear bucket con nombre único
            bucket_name = f"{name.lower().replace('_', '-')}-{self.config.get('region', 'us-east-1')}"

            self.s3_client.create_bucket(
                Bucket=bucket_name,
                CreateBucketConfiguration={'LocationConstraint': self.config.get('region')}
            )

            return {
                'id': bucket_name,
                'name': name,
                'provider': 'aws',
                'type': 's3',
                'region': self.config.get('region'),
                'size_gb': None  # S3 no tiene límite fijo
            }

        except Exception as e:
            logger.error(f"Error creando bucket S3: {e}")
            raise

    def _create_ebs_volume(self, name: str, size_gb: int, **kwargs) -> Dict[str, Any]:
        """Crea volumen EBS"""
        try:
            response = self.ec2_client.create_volume(
                Size=size_gb,
                AvailabilityZone=f"{self.config.get('region')}a",
                VolumeType=kwargs.get('volume_type', 'gp3'),
                TagSpecifications=[{
                    'ResourceType': 'volume',
                    'Tags': [
                        {'Key': 'Name', 'Value': name},
                        {'Key': 'ManagedBy', 'Value': 'Webmin-MultiCloud'}
                    ]
                }]
            )

            return {
                'id': response['VolumeId'],
                'name': name,
                'provider': 'aws',
                'type': 'ebs',
                'size_gb': size_gb,
                'status': 'creating'
            }

        except Exception as e:
            logger.error(f"Error creando volumen EBS: {e}")
            raise

    def list_storage(self) -> List[Dict[str, Any]]:
        """Lista buckets S3 y volúmenes EBS"""
        storage = []

        # Listar buckets S3
        try:
            buckets = self.s3_client.list_buckets()
            for bucket in buckets['Buckets']:
                storage.append({
                    'id': bucket['Name'],
                    'name': bucket['Name'],
                    'provider': 'aws',
                    'type': 's3',
                    'region': self.config.get('region'),
                    'created': bucket['CreationDate'].isoformat()
                })
        except Exception as e:
            logger.error(f"Error listando buckets S3: {e}")

        # Listar volúmenes EBS
        try:
            volumes = self.ec2_client.describe_volumes()
            for volume in volumes['Volumes']:
                name_tag = next((tag['Value'] for tag in volume.get('Tags', [])
                               if tag['Key'] == 'Name'), 'Unnamed')

                storage.append({
                    'id': volume['VolumeId'],
                    'name': name_tag,
                    'provider': 'aws',
                    'type': 'ebs',
                    'size_gb': volume['Size'],
                    'status': volume['State']
                })
        except Exception as e:
            logger.error(f"Error listando volúmenes EBS: {e}")

        return storage

    def create_load_balancer(self, name: str, **kwargs) -> Dict[str, Any]:
        """Crea Application Load Balancer"""
        try:
            # Crear subnets (simplificado)
            subnets = kwargs.get('subnets', [])

            response = self.elb_client.create_load_balancer(
                Name=name,
                Subnets=subnets,
                SecurityGroups=kwargs.get('security_groups', []),
                Scheme='internet-facing',
                Type='application',
                IpAddressType='ipv4'
            )

            lb = response['LoadBalancers'][0]

            return {
                'id': lb['LoadBalancerArn'],
                'name': name,
                'provider': 'aws',
                'type': 'alb',
                'dns_name': lb['DNSName'],
                'status': 'active'
            }

        except Exception as e:
            logger.error(f"Error creando load balancer en AWS: {e}")
            raise

    def get_costs(self) -> Dict[str, Any]:
        """Obtiene costos usando Cost Explorer"""
        try:
            # Costos del último mes
            import datetime
            end_date = datetime.date.today()
            start_date = end_date - datetime.timedelta(days=30)

            response = self.cost_client.get_cost_and_usage(
                TimePeriod={
                    'Start': start_date.isoformat(),
                    'End': end_date.isoformat()
                },
                Granularity='MONTHLY',
                Metrics=['BlendedCost']
            )

            total_cost = 0
            if response['ResultsByTime']:
                total_cost = float(response['ResultsByTime'][0]['Total']['BlendedCost']['Amount'])

            return {
                'total': total_cost,
                'currency': 'USD',
                'period': f"{start_date} to {end_date}",
                'breakdown': {}  # Implementar desglose por servicio
            }

        except Exception as e:
            logger.error(f"Error obteniendo costos de AWS: {e}")
            return {'total': 0, 'error': str(e)}