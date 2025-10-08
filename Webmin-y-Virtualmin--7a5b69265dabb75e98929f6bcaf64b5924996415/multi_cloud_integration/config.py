import os
import json
from typing import Dict, Any

class MultiCloudConfig:
    """Configuración para integración multi-nube"""

    def __init__(self, config_file: str = "multi_cloud_config.json"):
        self.config_file = config_file
        self.config = self._load_config()

    def _load_config(self) -> Dict[str, Any]:
        """Carga configuración desde archivo JSON o variables de entorno"""
        config = {
            "aws": {
                "access_key_id": os.getenv("AWS_ACCESS_KEY_ID"),
                "secret_access_key": os.getenv("AWS_SECRET_ACCESS_KEY"),
                "region": os.getenv("AWS_DEFAULT_REGION", "us-east-1")
            },
            "azure": {
                "subscription_id": os.getenv("AZURE_SUBSCRIPTION_ID"),
                "client_id": os.getenv("AZURE_CLIENT_ID"),
                "client_secret": os.getenv("AZURE_CLIENT_SECRET"),
                "tenant_id": os.getenv("AZURE_TENANT_ID")
            },
            "gcp": {
                "project_id": os.getenv("GCP_PROJECT_ID"),
                "credentials_file": os.getenv("GOOGLE_APPLICATION_CREDENTIALS")
            },
            "general": {
                "backup_regions": ["us-east-1", "us-west-2", "eu-west-1"],
                "cost_optimization_threshold": 0.8,
                "migration_timeout": 3600
            }
        }

        # Cargar desde archivo si existe
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, 'r') as f:
                    file_config = json.load(f)
                    self._merge_config(config, file_config)
            except Exception as e:
                print(f"Error cargando configuración: {e}")

        return config

    def _merge_config(self, base_config: Dict, file_config: Dict):
        """Fusiona configuración del archivo con la base"""
        for provider, settings in file_config.items():
            if provider in base_config:
                base_config[provider].update(settings)

    def get_provider_config(self, provider: str) -> Dict[str, Any]:
        """Obtiene configuración para un proveedor específico"""
        return self.config.get(provider, {})

    def get_general_config(self) -> Dict[str, Any]:
        """Obtiene configuración general"""
        return self.config.get("general", {})

    def save_config(self):
        """Guarda configuración actual en archivo"""
        with open(self.config_file, 'w') as f:
            json.dump(self.config, f, indent=2)

# Instancia global de configuración
config = MultiCloudConfig()