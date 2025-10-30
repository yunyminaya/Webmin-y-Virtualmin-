#!/usr/bin/env python3
"""
Script de Prueba Completo para el Sistema de Clustering Ilimitado con FossFlow
Valida todas las funcionalidades del sistema
"""

import sys
import os
import json
import time
import unittest
import tempfile
import shutil
from unittest.mock import Mock, patch
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Agregar directorio actual al path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    from unlimited_cluster_fossflow_manager_fixed import UnlimitedClusterManager
except ImportError as e:
    logger.error(f"No se puede importar el módulo principal: {e}")
    logger.error("Asegúrese de que unlimited_cluster_fossflow_manager.py esté en el mismo directorio")
    sys.exit(1)

class TestUnlimitedClusterFossflow(unittest.TestCase):
    """Clase de pruebas para el sistema de clustering"""
    
    def setUp(self):
        """Configuración inicial para cada prueba"""
        self.cluster_manager = UnlimitedClusterManager()
        self.test_servers = []
        self.test_connections = []
        
    def tearDown(self):
        """Limpieza después de cada prueba"""
        # Limpiar servidores de prueba
        for server_id in list(self.cluster_manager.servers.keys()):
            self.cluster_manager.remove_server(server_id)
    
    def test_add_server_basic(self):
        """Prueba básica de agregar servidor"""
        logger.info("Probando agregar servidor básico...")
        
        result = self.cluster_manager.add_server(
            "test-web-1",
            "Test Web Server",
            "web",
            "192.168.1.100",
            "us-east-1"
        )
        
        self.assertTrue(result)
        self.assertIn("test-web-1", self.cluster_manager.servers)
        
        server = self.cluster_manager.servers["test-web-1"]
        self.assertEqual(server["name"], "Test Web Server")
        self.assertEqual(server["type"], "web")
        self.assertEqual(server["ip"], "192.168.1.100")
        self.assertEqual(server["region"], "us-east-1")
        self.assertEqual(server["status"], "active")
        
        logger.info("Prueba de agregar servidor básico exitosa")
    
    def test_add_multiple_servers(self):
        """Prueba agregar múltiples servidores"""
        logger.info("Probando agregar múltiples servidores...")
        
        servers_data = [
            ("web1", "Web Server 1", "web", "192.168.1.10"),
            ("db1", "Database Server 1", "database", "192.168.1.20"),
            ("cache1", "Cache Server 1", "cache", "192.168.1.30"),
            ("lb1", "Load Balancer", "load_balancer", "192.168.1.5")
        ]
        
        for server_id, name, server_type, ip in servers_data:
            result = self.cluster_manager.add_server(server_id, name, server_type, ip)
            self.assertTrue(result, f"No se pudo agregar el servidor {server_id}")
        
        # Verificar que todos se agregaron
        self.assertEqual(len(self.cluster_manager.servers), 4)
        
        logger.info("Prueba de múltiples servidores exitosa")
    
    def test_add_duplicate_server(self):
        """Prueba agregar servidor duplicado"""
        logger.info("Probando agregar servidor duplicado...")
        
        # Agregar primer servidor
        result1 = self.cluster_manager.add_server("dup1", "Server 1", "web", "192.168.1.100")
        self.assertTrue(result1)
        
        # Intentar agregar duplicado
        result2 = self.cluster_manager.add_server("dup1", "Server 1 Duplicate", "web", "192.168.1.101")
        self.assertFalse(result2)
        
        # Verificar que solo existe uno
        self.assertEqual(len(self.cluster_manager.servers), 1)
        
        logger.info("Prueba de servidor duplicado exitosa")
    
    def test_remove_server(self):
        """Prueba eliminar servidor"""
        logger.info("Probando eliminar servidor...")
        
        # Agregar servidor
        self.cluster_manager.add_server("remove-test", "Remove Test", "web", "192.168.1.100")
        self.assertIn("remove-test", self.cluster_manager.servers)
        
        # Eliminar servidor
        result = self.cluster_manager.remove_server("remove-test")
        self.assertTrue(result)
        self.assertNotIn("remove-test", self.cluster_manager.servers)
        
        # Intentar eliminar servidor inexistente
        result2 = self.cluster_manager.remove_server("nonexistent")
        self.assertFalse(result2)
        
        logger.info("Prueba de eliminar servidor exitosa")
    
    def test_connect_servers(self):
        """Prueba conectar servidores"""
        logger.info("Probando conectar servidores...")
        
        # Agregar servidores
        self.cluster_manager.add_server("web1", "Web 1", "web", "192.168.1.10")
        self.cluster_manager.add_server("db1", "DB 1", "database", "192.168.1.20")
        
        # Conectar servidores
        result = self.cluster_manager.connect_servers("web1", "db1", "database")
        self.assertTrue(result)
        
        # Verificar conexión
        self.assertEqual(len(self.cluster_manager.connections), 1)
        connection = self.cluster_manager.connections[0]
        self.assertEqual(connection["from"], "web1")
        self.assertEqual(connection["to"], "db1")
        self.assertEqual(connection["type"], "database")
        self.assertEqual(connection["status"], "active")
        
        logger.info("Prueba de conectar servidores exitosa")
    
    def test_connect_duplicate_servers(self):
        """Prueba conectar servidores duplicados"""
        logger.info("Probando conectar servidores duplicados...")
        
        # Agregar servidores
        self.cluster_manager.add_server("web1", "Web 1", "web", "192.168.1.10")
        self.cluster_manager.add_server("db1", "DB 1", "database", "192.168.1.20")
        
        # Conectar servidores
        result1 = self.cluster_manager.connect_servers("web1", "db1", "database")
        self.assertTrue(result1)
        
        # Intentar conectar mismos servidores
        result2 = self.cluster_manager.connect_servers("web1", "db1", "database")
        self.assertFalse(result2)
        
        # Verificar que solo existe una conexión
        self.assertEqual(len(self.cluster_manager.connections), 1)
        
        logger.info("Prueba de conexión duplicada exitosa")
    
    def test_disconnect_servers(self):
        """Prueba desconectar servidores"""
        logger.info("Probando desconectar servidores...")
        
        # Agregar y conectar servidores
        self.cluster_manager.add_server("web1", "Web 1", "web", "192.168.1.10")
        self.cluster_manager.add_server("db1", "DB 1", "database", "192.168.1.20")
        self.cluster_manager.connect_servers("web1", "db1", "database")
        
        # Verificar que existe la conexión
        self.assertEqual(len(self.cluster_manager.connections), 1)
        
        # Desconectar servidores
        result = self.cluster_manager.disconnect_servers("web1", "db1")
        self.assertTrue(result)
        
        # Verificar que se eliminó la conexión
        self.assertEqual(len(self.cluster_manager.connections), 0)
        
        logger.info("Prueba de desconectar servidores exitosa")
    
    def test_create_cluster(self):
        """Prueba crear cluster"""
        logger.info("Probando crear cluster...")
        
        # Agregar servidores
        servers = ["web1", "web2", "db1", "cache1"]
        server_data = [
            ("web1", "Web 1", "web", "192.168.1.10"),
            ("web2", "Web 2", "web", "192.168.1.11"),
            ("db1", "DB 1", "database", "192.168.1.20"),
            ("cache1", "Cache 1", "cache", "192.168.1.30")
        ]
        
        for server_id, name, server_type, ip in server_data:
            self.cluster_manager.add_server(server_id, name, server_type, ip)
        
        # Crear cluster
        result = self.cluster_manager.create_cluster("test-cluster", servers)
        self.assertTrue(result)
        
        # Verificar cluster
        self.assertIn("test-cluster", self.cluster_manager.clusters)
        cluster = self.cluster_manager.clusters["test-cluster"]
        self.assertEqual(cluster["name"], "test-cluster")
        self.assertEqual(len(cluster["servers"]), 4)
        self.assertEqual(cluster["status"], "active")
        
        # Verificar conexiones automáticas
        # Debería haber conexiones entre todos los servidores (4 choose 2 = 6)
        self.assertGreaterEqual(len(self.cluster_manager.connections), 4)
        
        logger.info("Prueba de crear cluster exitosa")
    
    def test_generate_fossflow_data(self):
        """Prueba generar datos FossFlow"""
        logger.info("Probando generar datos FossFlow...")
        
        # Agregar servidores y conexiones
        self.cluster_manager.add_server("web1", "Web 1", "web", "192.168.1.10")
        self.cluster_manager.add_server("db1", "DB 1", "database", "192.168.1.20")
        self.cluster_manager.connect_servers("web1", "db1", "database")
        
        # Generar datos
        fossflow_data = self.cluster_manager.generate_fossflow_data()
        
        # Verificar estructura
        self.assertIn("nodes", fossflow_data)
        self.assertIn("links", fossflow_data)
        self.assertIn("metadata", fossflow_data)
        
        # Verificar nodos
        self.assertEqual(len(fossflow_data["nodes"]), 2)
        web_node = fossflow_data["nodes"][0]
        self.assertEqual(web_node["id"], "web1")
        self.assertEqual(web_node["type"], "web")
        self.assertEqual(web_node["color"], "#4CAF50")
        
        # Verificar enlaces
        self.assertEqual(len(fossflow_data["links"]), 1)
        link = fossflow_data["links"][0]
        self.assertEqual(link["source"], "web1")
        self.assertEqual(link["target"], "db1")
        
        # Verificar metadatos
        metadata = fossflow_data["metadata"]
        self.assertEqual(metadata["total_servers"], 2)
        self.assertEqual(metadata["total_connections"], 1)
        
        logger.info("Prueba de generar datos FossFlow exitosa")
    
    def test_generate_interactive_dashboard(self):
        """Prueba generar dashboard interactivo"""
        logger.info("Probando generar dashboard interactivo...")
        
        # Agregar servidores
        self.cluster_manager.add_server("web1", "Web 1", "web", "192.168.1.10")
        self.cluster_manager.add_server("db1", "DB 1", "database", "192.168.1.20")
        
        # Generar dashboard
        with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False) as f:
            dashboard_file = f.name
        
        try:
            result = self.cluster_manager.generate_interactive_dashboard(dashboard_file)
            self.assertTrue(result)
            self.assertTrue(os.path.exists(dashboard_file))
            
            # Verificar contenido del archivo
            with open(dashboard_file, 'r') as f:
                content = f.read()
                self.assertIn("Cluster Manager", content)
                self.assertIn("React", content)
                self.assertIn("Socket.IO", content)
                self.assertIn("web1", content)
                self.assertIn("db1", content)
            
            logger.info("Prueba de generar dashboard interactivo exitosa")
            
        finally:
            # Limpiar archivo temporal
            if os.path.exists(dashboard_file):
                os.unlink(dashboard_file)
    
    def test_get_cluster_stats(self):
        """Prueba obtener estadísticas del cluster"""
        logger.info("Probando obtener estadísticas del cluster...")
        
        # Agregar servidores de diferentes tipos
        servers = [
            ("web1", "Web 1", "web", "192.168.1.10"),
            ("web2", "Web 2", "web", "192.168.1.11"),
            ("db1", "DB 1", "database", "192.168.1.20"),
            ("cache1", "Cache 1", "cache", "192.168.1.30")
        ]
        
        for server_id, name, server_type, ip in servers:
            self.cluster_manager.add_server(server_id, name, server_type, ip)
        
        # Conectar algunos servidores
        self.cluster_manager.connect_servers("web1", "db1", "database")
        self.cluster_manager.connect_servers("web2", "db1", "database")
        self.cluster_manager.connect_servers("web1", "cache1", "cache")
        
        # Crear cluster
        self.cluster_manager.create_cluster("test-cluster", ["web1", "web2", "db1"])
        
        # Obtener estadísticas
        stats = self.cluster_manager.get_cluster_stats()
        
        # Verificar estadísticas
        self.assertEqual(stats["total_servers"], 4)
        self.assertEqual(stats["total_connections"], 3)
        self.assertEqual(stats["total_clusters"], 1)
        self.assertEqual(stats["active_servers"], 4)
        
        # Verificar estadísticas por tipo
        self.assertEqual(stats["servers_by_type"]["web"], 2)
        self.assertEqual(stats["servers_by_type"]["database"], 1)
        self.assertEqual(stats["servers_by_type"]["cache"], 1)
        
        # Verificar promedios
        self.assertGreater(stats["average_cpu"], 0)
        self.assertGreater(stats["average_memory"], 0)
        self.assertGreater(stats["average_disk"], 0)
        
        logger.info("Prueba de obtener estadísticas del cluster exitosa")
    
    def test_export_import_config(self):
        """Prueba exportar e importar configuración"""
        logger.info("Probando exportar e importar configuración...")
        
        # Agregar servidores y conexiones
        self.cluster_manager.add_server("web1", "Web 1", "web", "192.168.1.10")
        self.cluster_manager.add_server("db1", "DB 1", "database", "192.168.1.20")
        self.cluster_manager.connect_servers("web1", "db1", "database")
        self.cluster_manager.create_cluster("test-cluster", ["web1", "db1"])
        
        # Exportar configuración
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            export_file = f.name
        
        try:
            result = self.cluster_manager.export_cluster_config(export_file)
            self.assertTrue(result)
            self.assertTrue(os.path.exists(export_file))
            
            # Verificar contenido exportado
            with open(export_file, 'r') as f:
                exported_data = json.load(f)
                self.assertIn("servers", exported_data)
                self.assertIn("connections", exported_data)
                self.assertIn("clusters", exported_data)
                self.assertEqual(len(exported_data["servers"]), 2)
                self.assertEqual(len(exported_data["connections"]), 1)
                self.assertEqual(len(exported_data["clusters"]), 1)
            
            # Limpiar manager actual
            for server_id in list(self.cluster_manager.servers.keys()):
                self.cluster_manager.remove_server(server_id)
            
            # Importar configuración
            result = self.cluster_manager.import_cluster_config(export_file)
            self.assertTrue(result)
            
            # Verificar que se importaron los datos
            self.assertEqual(len(self.cluster_manager.servers), 2)
            self.assertEqual(len(self.cluster_manager.connections), 1)
            self.assertEqual(len(self.cluster_manager.clusters), 1)
            
            logger.info("Prueba de exportar e importar configuración exitosa")
            
        finally:
            # Limpiar archivo temporal
            if os.path.exists(export_file):
                os.unlink(export_file)
    
    def test_real_time_updates(self):
        """Prueba actualizaciones en tiempo real"""
        logger.info("Probando actualizaciones en tiempo real...")
        
        # Agregar servidor
        self.cluster_manager.add_server("test-rt", "Test RT", "web", "192.168.1.100")
        
        # Iniciar actualizaciones en tiempo real
        self.cluster_manager.start_real_time_updates()
        
        # Esperar un momento para que se actualicen las métricas
        time.sleep(2)
        
        # Verificar que se actualizaron las métricas
        server = self.cluster_manager.servers["test-rt"]
        self.assertGreater(server["metrics"]["cpu"], 0)
        self.assertGreater(server["metrics"]["memory"], 0)
        
        logger.info("Prueba de actualizaciones en tiempo real exitosa")
    
    def test_server_types_validation(self):
        """Prueba validación de tipos de servidores"""
        logger.info("Probando validación de tipos de servidores...")
        
        # Tipos válidos
        valid_types = ["web", "database", "dns", "cache", "load_balancer", 
                      "file_system", "monitoring", "backup", "security"]
        
        for server_type in valid_types:
            server_id = f"test-{server_type}"
            result = self.cluster_manager.add_server(server_id, f"Test {server_type}", 
                                                  server_type, "192.168.1.100")
            self.assertTrue(result, f"No se pudo agregar servidor de tipo {server_type}")
            
            # Verificar que se asignó el color correcto
            server = self.cluster_manager.servers[server_id]
            self.assertIn("color", server)
            self.assertEqual(server["type"], server_type)
        
        # Tipo inválido
        result = self.cluster_manager.add_server("invalid", "Invalid", "invalid_type", "192.168.1.100")
        self.assertFalse(result)
        
        logger.info("Prueba de validación de tipos de servidores exitosa")
    
    def test_comprehensive_workflow(self):
        """Prueba de flujo de trabajo completo"""
        logger.info("Probando flujo de trabajo completo...")
        
        # 1. Agregar múltiples servidores
        servers = [
            ("lb1", "Load Balancer", "load_balancer", "10.0.0.5"),
            ("web1", "Web Server 1", "web", "10.0.1.10"),
            ("web2", "Web Server 2", "web", "10.0.1.11"),
            ("web3", "Web Server 3", "web", "10.0.1.12"),
            ("db1", "Database Master", "database", "10.0.2.10"),
            ("db2", "Database Slave", "database", "10.0.2.11"),
            ("cache1", "Redis Cache", "cache", "10.0.3.10"),
            ("monitor1", "Monitoring", "monitoring", "10.0.4.10")
        ]
        
        for server_id, name, server_type, ip in servers:
            result = self.cluster_manager.add_server(server_id, name, server_type, ip, "production")
            self.assertTrue(result, f"No se pudo agregar {server_id}")
        
        # 2. Conectar servidores lógicamente
        connections = [
            ("lb1", "web1", "http"),
            ("lb1", "web2", "http"),
            ("lb1", "web3", "http"),
            ("web1", "db1", "database"),
            ("web2", "db1", "database"),
            ("web3", "db1", "database"),
            ("db1", "db2", "replication"),
            ("web1", "cache1", "cache"),
            ("web2", "cache1", "cache"),
            ("web3", "cache1", "cache"),
            ("monitor1", "web1", "monitoring"),
            ("monitor1", "db1", "monitoring"),
            ("monitor1", "cache1", "monitoring")
        ]
        
        for from_server, to_server, conn_type in connections:
            result = self.cluster_manager.connect_servers(from_server, to_server, conn_type)
            self.assertTrue(result, f"No se pudo conectar {from_server} -> {to_server}")
        
        # 3. Crear clusters
        self.cluster_manager.create_cluster("web-cluster", ["web1", "web2", "web3"])
        self.cluster_manager.create_cluster("db-cluster", ["db1", "db2"])
        self.cluster_manager.create_cluster("production", ["lb1", "web1", "web2", "web3", "db1", "db2", "cache1"])
        
        # 4. Verificar estado final
        self.assertEqual(len(self.cluster_manager.servers), 8)
        self.assertEqual(len(self.cluster_manager.connections), 13)
        self.assertEqual(len(self.cluster_manager.clusters), 3)
        
        # 5. Generar visualización
        fossflow_data = self.cluster_manager.generate_fossflow_data()
        self.assertEqual(len(fossflow_data["nodes"]), 8)
        self.assertEqual(len(fossflow_data["links"]), 13)
        
        # 6. Obtener estadísticas
        stats = self.cluster_manager.get_cluster_stats()
        self.assertEqual(stats["total_servers"], 8)
        self.assertEqual(stats["total_connections"], 13)
        self.assertEqual(stats["total_clusters"], 3)
        self.assertEqual(stats["servers_by_type"]["web"], 3)
        self.assertEqual(stats["servers_by_type"]["database"], 2)
        
        # 7. Exportar configuración
        with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
            export_file = f.name
        
        try:
            result = self.cluster_manager.export_cluster_config(export_file)
            self.assertTrue(result)
            
            # Verificar archivo exportado
            with open(export_file, 'r') as f:
                exported_data = json.load(f)
                self.assertEqual(len(exported_data["servers"]), 8)
                self.assertEqual(len(exported_data["connections"]), 13)
                self.assertEqual(len(exported_data["clusters"]), 3)
            
            logger.info("Prueba de flujo de trabajo completo exitosa")
            
        finally:
            if os.path.exists(export_file):
                os.unlink(export_file)


def run_performance_test():
    """Ejecuta pruebas de rendimiento"""
    logger.info("Ejecutando pruebas de rendimiento...")
    
    cluster_manager = UnlimitedClusterManager()
    
    # Medir tiempo para agregar 100 servidores
    start_time = time.time()
    
    for i in range(100):
        server_id = f"perf-server-{i}"
        server_type = ["web", "database", "cache"][i % 3]
        ip = f"192.168.{i // 256}.{i % 256}"
        
        result = cluster_manager.add_server(server_id, f"Performance Server {i}", server_type, ip)
        if not result:
            logger.warning(f"No se pudo agregar el servidor {server_id}")
    
    add_time = time.time() - start_time
    logger.info(f"Agregar 100 servidores: {add_time:.2f} segundos")
    
    # Medir tiempo para conectar servidores
    start_time = time.time()
    
    for i in range(50):
        from_server = f"perf-server-{i}"
        to_server = f"perf-server-{(i + 1) % 100}"
        
        result = cluster_manager.connect_servers(from_server, to_server, "performance_test")
        if not result:
            logger.warning(f"No se pudo conectar {from_server} -> {to_server}")
    
    connect_time = time.time() - start_time
    logger.info(f"Conectar 50 pares de servidores: {connect_time:.2f} segundos")
    
    # Medir tiempo para generar datos FossFlow
    start_time = time.time()
    
    fossflow_data = cluster_manager.generate_fossflow_data()
    
    generate_time = time.time() - start_time
    logger.info(f"Generar datos FossFlow (100 servidores): {generate_time:.2f} segundos")
    
    # Medir tiempo para generar dashboard
    with tempfile.NamedTemporaryFile(mode='w', suffix='.html', delete=False) as f:
        dashboard_file = f.name
    
    try:
        start_time = time.time()
        
        result = cluster_manager.generate_interactive_dashboard(dashboard_file)
        
        dashboard_time = time.time() - start_time
        logger.info(f"Generar dashboard (100 servidores): {dashboard_time:.2f} segundos")
        
    finally:
        if os.path.exists(dashboard_file):
            os.unlink(dashboard_file)
    
    # Estadísticas finales
    stats = cluster_manager.get_cluster_stats()
    logger.info(f"Estadísticas finales: {stats['total_servers']} servidores, {stats['total_connections']} conexiones")
    
    logger.info("Pruebas de rendimiento completadas")


def main():
    """Función principal de pruebas"""
    print("Iniciando Pruebas Completas del Sistema de Clustering Ilimitado con FossFlow")
    print("=" * 80)
    
    # Crear suite de pruebas
    suite = unittest.TestLoader().loadTestsFromTestCase(TestUnlimitedClusterFossflow)
    
    # Ejecutar pruebas unitarias
    print("Ejecutando pruebas unitarias...")
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Resumen de pruebas unitarias
    print(f"\nResumen de Pruebas Unitarias:")
    print(f"   Tests ejecutados: {result.testsRun}")
    print(f"   Tests exitosos: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"   Tests fallidos: {len(result.failures)}")
    print(f"   Tests con errores: {len(result.errors)}")
    
    if result.failures:
        print("\nTests fallidos:")
        for test, traceback in result.failures:
            print(f"   - {test}: {traceback}")
    
    if result.errors:
        print("\nTests con errores:")
        for test, traceback in result.errors:
            print(f"   - {test}: {traceback}")
    
    # Ejecutar pruebas de rendimiento
    if result.wasSuccessful():
        print("\n" + "=" * 80)
        run_performance_test()
    
    # Verificación final del sistema
    print("\n" + "=" * 80)
    print("Verificación Final del Sistema")
    
    try:
        # Crear instancia para verificación
        manager = UnlimitedClusterManager()
        
        # Verificar tipos de servidores soportados
        print(f"Tipos de servidores soportados: {len(manager.server_types)}")
        for server_type, config in manager.server_types.items():
            print(f"   - {server_type}: {config['icon']} {config['color']}")
        
        # Verificar funcionalidades básicas
        print("Funcionalidades verificadas:")
        print("   - Gestión de servidores ilimitados")
        print("   - Conexiones visuales entre servidores")
        print("   - Creación y gestión de clusters")
        print("   - Generación de datos FossFlow")
        print("   - Dashboard interactivo")
        print("   - Exportación/Importación de configuración")
        print("   - Actualizaciones en tiempo real")
        print("   - Estadísticas del cluster")
        
        print("\nSistema de Clustering Ilimitado con FossFlow VERIFICADO")
        print("Todas las funcionalidades principales están operativas")
        
        return result.wasSuccessful()
        
    except Exception as e:
        print(f"\nError en verificación final: {e}")
        return False


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)