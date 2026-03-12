#!/usr/bin/env python3

# Script para generar dinámicamente el inventario de Ansible
# basado en los outputs de Terraform

import json
import sys
import os
from pathlib import Path

def load_terraform_outputs(terraform_outputs_file):
    """Cargar los outputs de Terraform desde un archivo JSON"""
    try:
        with open(terraform_outputs_file, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError) as e:
        print(f"Error al cargar outputs de Terraform: {e}")
        sys.exit(1)

def generate_inventory(terraform_outputs):
    """Generar el inventario de Ansible basado en los outputs de Terraform"""
    
    # Inicializar estructura del inventario
    inventory = {
        "all": {
            "children": {
                "web_servers": {
                    "hosts": {},
                    "vars": {
                        "ansible_user": "ubuntu",
                        "ansible_ssh_private_key_file": "~/.ssh/virtualmin_key",
                        "ansible_ssh_common_args": "-o StrictHostKeyChecking=no"
                    }
                },
                "database_servers": {
                    "hosts": {},
                    "vars": {
                        "ansible_user": "ubuntu",
                        "ansible_ssh_private_key_file": "~/.ssh/virtualmin_key",
                        "ansible_ssh_common_args": "-o StrictHostKeyChecking=no"
                    }
                },
                "monitoring_servers": {
                    "hosts": {},
                    "vars": {
                        "ansible_user": "ubuntu",
                        "ansible_ssh_private_key_file": "~/.ssh/virtualmin_key",
                        "ansible_ssh_common_args": "-o StrictHostKeyChecking=no"
                    }
                },
                "load_balancers": {
                    "hosts": {},
                    "vars": {
                        "ansible_user": "ubuntu",
                        "ansible_ssh_private_key_file": "~/.ssh/virtualmin_key",
                        "ansible_ssh_common_args": "-o StrictHostKeyChecking=no"
                    }
                }
            },
            "vars": {
                "environment": terraform_outputs.get("environment", {}).get("value", "production"),
                "region": terraform_outputs.get("region", {}).get("value", "us-east-1"),
                "project_name": "virtualmin-enterprise",
                "domain": terraform_outputs.get("domain", {}).get("value", "example.com")
            }
        }
    }
    
    # Procesar outputs de Terraform y agregar hosts al inventario
    
    # Servidores web
    if "web_server_ips" in terraform_outputs:
        web_ips = terraform_outputs["web_server_ips"]["value"]
        web_names = terraform_outputs.get("web_server_names", {}).get("value", [])
        
        for i, ip in enumerate(web_ips):
            hostname = web_names[i] if i < len(web_names) else f"web-server-{i+1}"
            inventory["all"]["children"]["web_servers"]["hosts"][hostname] = {
                "ansible_host": ip,
                "server_role": "web",
                "server_id": i + 1
            }
    
    # Servidores de base de datos
    if "database_server_ips" in terraform_outputs:
        db_ips = terraform_outputs["database_server_ips"]["value"]
        db_names = terraform_outputs.get("database_server_names", {}).get("value", [])
        
        for i, ip in enumerate(db_ips):
            hostname = db_names[i] if i < len(db_names) else f"db-server-{i+1}"
            inventory["all"]["children"]["database_servers"]["hosts"][hostname] = {
                "ansible_host": ip,
                "server_role": "database",
                "server_id": i + 1
            }
    
    # Servidores de monitoreo
    if "monitoring_server_ips" in terraform_outputs:
        monitoring_ips = terraform_outputs["monitoring_server_ips"]["value"]
        monitoring_names = terraform_outputs.get("monitoring_server_names", {}).get("value", [])
        
        for i, ip in enumerate(monitoring_ips):
            hostname = monitoring_names[i] if i < len(monitoring_names) else f"monitoring-server-{i+1}"
            inventory["all"]["children"]["monitoring_servers"]["hosts"][hostname] = {
                "ansible_host": ip,
                "server_role": "monitoring",
                "server_id": i + 1
            }
    
    # Balanceadores de carga
    if "load_balancer_ips" in terraform_outputs:
        lb_ips = terraform_outputs["load_balancer_ips"]["value"]
        lb_names = terraform_outputs.get("load_balancer_names", {}).get("value", [])
        
        for i, ip in enumerate(lb_ips):
            hostname = lb_names[i] if i < len(lb_names) else f"load-balancer-{i+1}"
            inventory["all"]["children"]["load_balancers"]["hosts"][hostname] = {
                "ansible_host": ip,
                "server_role": "load_balancer",
                "server_id": i + 1
            }
    
    # Agregar variables específicas del entorno
    environment = terraform_outputs.get("environment", {}).get("value", "production")
    
    if environment == "production":
        inventory["all"]["vars"].update({
            "enable_backup": True,
            "backup_retention_days": 30,
            "enable_monitoring": True,
            "enable_security_hardening": True
        })
    elif environment == "staging":
        inventory["all"]["vars"].update({
            "enable_backup": False,
            "enable_monitoring": True,
            "enable_security_hardening": False
        })
    
    return inventory

def write_inventory_file(inventory, output_file):
    """Escribir el inventario a un archivo"""
    try:
        with open(output_file, 'w') as f:
            json.dump(inventory, f, indent=2)
        print(f"Inventario generado exitosamente: {output_file}")
    except IOError as e:
        print(f"Error al escribir el archivo de inventario: {e}")
        sys.exit(1)

def write_dynamic_inventory_script(inventory, output_script):
    """Escribir un script de inventario dinámico compatible con Ansible"""
    script_content = f"""#!/usr/bin/env python3

import json
import sys

# Inventario estático generado desde los outputs de Terraform
inventory = {json.dumps(inventory, indent=4)}

if len(sys.argv) == 2 and sys.argv[1] == "--list":
    print(json.dumps(inventory, indent=2))
elif len(sys.argv) == 3 and sys.argv[1] == "--host":
    # Ansible solicita variables para un host específico
    host = sys.argv[2]
    host_vars = None
    
    # Buscar el host en el inventario
    for group in inventory.get("all", {}).get("children", {}).values():
        if host in group.get("hosts", {}):
            host_vars = group["hosts"][host]
            break
    
    # Variables del grupo
    group_vars = {}
    for group in inventory.get("all", {}).get("children", {}).values():
        if host in group.get("hosts", {}):
            group_vars = group.get("vars", {})
            break
    
    # Variables globales
    all_vars = inventory.get("all", {}).get("vars", {})
    
    # Combinar todas las variables
    combined_vars = {}
    combined_vars.update(all_vars)
    combined_vars.update(group_vars)
    combined_vars.update(host_vars)
    
    print(json.dumps(combined_vars, indent=2))
else:
    print("Uso: {sys.argv[0]} --list o {sys.argv[0]} --host <hostname>")
    sys.exit(1)
"""
    
    try:
        with open(output_script, 'w') as f:
            f.write(script_content)
        
        # Hacer el script ejecutable
        os.chmod(output_script, 0o755)
        print(f"Script de inventario dinámico generado: {output_script}")
    except IOError as e:
        print(f"Error al escribir el script de inventario dinámico: {e}")
        sys.exit(1)

def main():
    """Función principal"""
    # Verificar argumentos
    if len(sys.argv) < 2:
        print("Uso: python3 generate_inventory.py <terraform_outputs.json> [output_file]")
        sys.exit(1)
    
    terraform_outputs_file = sys.argv[1]
    
    # Determinar archivo de salida
    if len(sys.argv) >= 3:
        output_file = sys.argv[2]
    else:
        output_file = "inventory.ini"
    
    # Verificar que el archivo de outputs exista
    if not os.path.exists(terraform_outputs_file):
        print(f"Error: El archivo {terraform_outputs_file} no existe")
        sys.exit(1)
    
    # Cargar outputs de Terraform
    terraform_outputs = load_terraform_outputs(terraform_outputs_file)
    
    # Generar inventario
    inventory = generate_inventory(terraform_outputs)
    
    # Escribir archivo de inventario estático
    write_inventory_file(inventory, output_file)
    
    # Escribir script de inventario dinámico
    script_name = os.path.splitext(output_file)[0] + "_dynamic.py"
    write_dynamic_inventory_script(inventory, script_name)
    
    # Generar archivo de configuración de Ansible con rutas de inventario
    ansible_config = """[defaults]
inventory = {inventory_file}
host_key_checking = False
retry_files_enabled = False
roles_path = roles
library = library
filter_plugins = filter_plugins
log_path = ../logs/ansible.log

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=no
pipelining = True
""".format(inventory_file=output_file)
    
    with open("ansible.cfg", 'w') as f:
        f.write(ansible_config)
    
    print("Archivo de configuración de Ansible generado: ansible.cfg")

if __name__ == "__main__":
    main()