#!/usr/bin/env python3
"""
Script de diagnóstico para integración de funciones Pro y clustering FossFlow
"""

import os
import json
import subprocess
import sys
from pathlib import Path

def log_debug(message, level="INFO"):
    """Función de logging para diagnóstico"""
    timestamp = subprocess.run(['date', '+%Y-%m-%d %H:%M:%S'], 
                              capture_output=True, text=True).stdout.strip()
    print(f"[{timestamp}] [{level}] DEBUG_PRO: {message}")

def check_pro_status():
    """Verificar el estado de las funciones Pro"""
    log_debug("Verificando estado de funciones Pro...")
    
    pro_status_file = "pro_status.json"
    if os.path.exists(pro_status_file):
        with open(pro_status_file, 'r') as f:
            pro_status = json.load(f)
        
        log_debug(f"Tipo de licencia: {pro_status.get('virtualmin_pro_status', {}).get('license_type', 'UNKNOWN')}")
        log_debug(f"Estado de licencia: {pro_status.get('virtualmin_pro_status', {}).get('license_status', 'UNKNOWN')}")
        
        activated_features = pro_status.get('activated_features', {})
        for feature, status in activated_features.items():
            feature_status = status.get('status', 'UNKNOWN')
            log_debug(f"Función {feature}: {feature_status}")
            
            # Verificación específica de clustering
            if feature == 'enterprise_features':
                cluster_mgmt = status.get('cluster_management', False)
                load_balancing = status.get('load_balancing', False)
                log_debug(f"  - Cluster management: {cluster_mgmt}")
                log_debug(f"  - Load balancing: {load_balancing}")
    else:
        log_debug("Archivo pro_status.json no encontrado", "ERROR")
        return False
    
    return True

def check_pro_scripts():
    """Verificar existencia y permisos de scripts Pro"""
    log_debug("Verificando scripts Pro...")
    
    pro_scripts = [
        "pro_activation_master.sh",
        "activate_all_pro_features.sh", 
        "pro_features_advanced.sh",
        "pro_dashboard.sh"
    ]
    
    all_exist = True
    for script in pro_scripts:
        if os.path.exists(script):
            is_executable = os.access(script, os.X_OK)
            log_debug(f"Script {script}: {'EJECUTABLE' if is_executable else 'NO EJECUTABLE'}")
            if not is_executable:
                all_exist = False
        else:
            log_debug(f"Script {script}: NO EXISTE", "ERROR")
            all_exist = False
    
    return all_exist

def check_clustering_integration():
    """Verificar integración del sistema de clustering"""
    log_debug("Verificando integración de clustering...")
    
    # Verificar script de clustering FossFlow
    clustering_script = "unlimited_cluster_fossflow_manager.py"
    if os.path.exists(clustering_script):
        log_debug(f"Script de clustering FossFlow encontrado: {clustering_script}")
        
        # Verificar si se puede importar
        try:
            import importlib.util
            spec = importlib.util.spec_from_file_location("cluster_manager", clustering_script)
            cluster_module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cluster_module)
            log_debug("Script de clustering FossFlow importado correctamente")
            
            # Verificar si tiene las clases necesarias
            if hasattr(cluster_module, 'UnlimitedClusterManager'):
                log_debug("Clase UnlimitedClusterManager encontrada")
            else:
                log_debug("Clase UnlimitedClusterManager NO encontrada", "ERROR")
                return False
        except Exception as e:
            log_debug(f"Error al importar script de clustering: {str(e)}", "ERROR")
            return False
    else:
        log_debug(f"Script de clustering FossFlow NO encontrado: {clustering_script}", "ERROR")
        return False
    
    # Verificar directorios de clustering Pro
    pro_clustering_dirs = [
        "pro_clustering",
        "cluster_visualization",
        "cluster_infrastructure"
    ]
    
    for dir_name in pro_clustering_dirs:
        if os.path.exists(dir_name):
            log_debug(f"Directorio de clustering encontrado: {dir_name}")
        else:
            log_debug(f"Directorio de clustering NO encontrado: {dir_name}", "WARNING")
    
    return True

def check_fossflow_integration():
    """Verificar integración con FossFlow"""
    log_debug("Verificando integración con FossFlow...")
    
    fossflow_dir = "fossflow"
    if os.path.exists(fossflow_dir):
        log_debug(f"Directorio FossFlow encontrado: {fossflow_dir}")
        
        # Verificar archivos clave de FossFlow
        fossflow_files = [
            "fossflow/__init__.py",
            "fossflow/core.py",
            "fossflow/visualizer.py"
        ]
        
        for file_path in fossflow_files:
            if os.path.exists(file_path):
                log_debug(f"Archivo FossFlow encontrado: {file_path}")
            else:
                log_debug(f"Archivo FossFlow NO encontrado: {file_path}", "WARNING")
    else:
        log_debug(f"Directorio FossFlow NO encontrado: {fossflow_dir}", "ERROR")
        return False
    
    return True

def test_clustering_functionality():
    """Probar funcionalidad básica del clustering"""
    log_debug("Probando funcionalidad de clustering...")
    
    try:
        # Intentar crear una instancia del gestor de clustering
        import importlib.util
        clustering_script = "unlimited_cluster_fossflow_manager.py"
        
        if os.path.exists(clustering_script):
            spec = importlib.util.spec_from_file_location("cluster_manager", clustering_script)
            cluster_module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(cluster_module)
            
            # Crear instancia (el constructor no acepta el parámetro simulate)
            manager = cluster_module.UnlimitedClusterManager()
            
            # Probar añadir un servidor simulado usando los parámetros correctos
            result = manager.add_server(
                "test-server-1",
                "Servidor de Prueba",
                "web",
                "192.168.1.100",
                simulate=True
            )
            if result:
                log_debug("Prueba de clustering: SERVIDOR AÑADIDO CORRECTAMENTE")
                
                # Probar generar visualización
                try:
                    viz_data = manager.generate_fossflow_data()
                    if viz_data:
                        log_debug("Prueba de visualización: DATOS GENERADOS CORRECTAMENTE")
                        return True
                    else:
                        log_debug("Prueba de visualización: NO SE GENERARON DATOS", "ERROR")
                except Exception as e:
                    log_debug(f"Error en prueba de visualización: {str(e)}", "ERROR")
            else:
                log_debug("Prueba de clustering: ERROR AL AÑADIR SERVIDOR", "ERROR")
        else:
            log_debug("Script de clustering no encontrado para prueba", "ERROR")
    except Exception as e:
        log_debug(f"Error en prueba de clustering: {str(e)}", "ERROR")
    
    return False

def main():
    """Función principal de diagnóstico"""
    log_debug("INICIANDO DIAGNÓSTICO DE INTEGRACIÓN PRO Y CLUSTERING")
    log_debug("=" * 60)
    
    results = {
        'pro_status': check_pro_status(),
        'pro_scripts': check_pro_scripts(),
        'clustering_integration': check_clustering_integration(),
        'fossflow_integration': check_fossflow_integration(),
        'clustering_functionality': test_clustering_functionality()
    }
    
    log_debug("=" * 60)
    log_debug("RESUMEN DE DIAGNÓSTICO:")
    
    all_passed = True
    for test_name, result in results.items():
        status = "PASS" if result else "FAIL"
        log_debug(f"  {test_name}: {status}")
        if not result:
            all_passed = False
    
    log_debug("=" * 60)
    if all_passed:
        log_debug("DIAGNÓSTICO COMPLETO: TODAS LAS PRUEBAS PASARON")
        log_debug("El sistema de integración Pro y clustering parece funcional")
    else:
        log_debug("DIAGNÓSTICO COMPLETO: ALGUNAS PRUEBAS FALLARON")
        log_debug("Se requieren correcciones en la integración del sistema")
    
    log_debug("=" * 60)
    
    return 0 if all_passed else 1

if __name__ == "__main__":
    sys.exit(main())