#!/usr/bin/env python3
"""
Demo del Sistema de Clustering con Servidores Simulados
Muestra la funcionalidad completa del sistema con datos de ejemplo
"""

from unlimited_cluster_fossflow_manager import UnlimitedClusterManager
import time

def main():
    """Función principal de demostración con servidores simulados"""
    print("🚀 Iniciando Demo del Sistema de Clustering Ilimitado con FossFlow")
    print("📝 Creando cluster con servidores simulados...")
    
    # Crear gestor del cluster
    cluster_manager = UnlimitedClusterManager()
    
    # Agregar servidores de ejemplo en modo simulación
    servers_data = [
        ("web1", "Servidor Web Principal", "web", "192.168.1.10", "us-east-1"),
        ("web2", "Servidor Web Secundario", "web", "192.168.1.11", "us-east-1"),
        ("db1", "Base de Datos Principal", "database", "192.168.1.20", "us-east-1"),
        ("db2", "Base de Datos Réplica", "database", "192.168.1.21", "us-east-1"),
        ("lb1", "Load Balancer", "load_balancer", "192.168.1.5", "us-east-1"),
        ("cache1", "Redis Cache", "cache", "192.168.1.30", "us-east-1"),
        ("monitor1", "Sistema de Monitoreo", "monitoring", "192.168.1.40", "us-east-1"),
        ("backup1", "Servidor de Backup", "backup", "192.168.1.50", "us-east-1"),
        ("dns1", "Servidor DNS", "dns", "192.168.1.53", "us-east-1"),
        ("security1", "Firewall/Security", "security", "192.168.1.1", "us-east-1")
    ]
    
    print("🔧 Agregando servidores al cluster...")
    for server_id, name, server_type, ip, region in servers_data:
        result = cluster_manager.add_server(server_id, name, server_type, ip, region, simulate=True)
        if result:
            print(f"  ✅ {server_id} ({name}) agregado correctamente")
        else:
            print(f"  ❌ Error al agregar {server_id}")
    
    # Conectar servidores
    connections_data = [
        ("lb1", "web1", "http"),
        ("lb1", "web2", "http"),
        ("web1", "db1", "database"),
        ("web2", "db1", "database"),
        ("db1", "db2", "replication"),
        ("web1", "cache1", "cache"),
        ("web2", "cache1", "cache"),
        ("monitor1", "web1", "monitoring"),
        ("monitor1", "db1", "monitoring"),
        ("backup1", "db1", "backup"),
        ("dns1", "web1", "dns"),
        ("dns1", "web2", "dns"),
        ("security1", "lb1", "firewall"),
        ("security1", "web1", "firewall"),
        ("security1", "db1", "firewall")
    ]
    
    print("\n🔗 Estableciendo conexiones entre servidores...")
    for from_server, to_server, conn_type in connections_data:
        result = cluster_manager.connect_servers(from_server, to_server, conn_type)
        if result:
            print(f"  ✅ Conexión {from_server} -> {to_server} ({conn_type})")
        else:
            print(f"  ❌ Error en conexión {from_server} -> {to_server}")
    
    # Crear clusters
    clusters_data = [
        ("production_cluster", ["web1", "web2", "db1", "db2", "lb1", "cache1"]),
        ("monitoring_cluster", ["monitor1", "backup1"]),
        ("infrastructure_cluster", ["dns1", "security1"])
    ]
    
    print("\n🏗️ Creando clusters lógicos...")
    for cluster_name, server_ids in clusters_data:
        result = cluster_manager.create_cluster(cluster_name, server_ids)
        if result:
            print(f"  ✅ Cluster '{cluster_name}' creado con {len(server_ids)} servidores")
        else:
            print(f"  ❌ Error al crear cluster '{cluster_name}'")
    
    # Generar dashboard interactivo
    print("\n📊 Generando dashboard interactivo...")
    dashboard_file = cluster_manager.generate_interactive_dashboard("demo_cluster_dashboard.html")
    
    # Mostrar estadísticas
    stats = cluster_manager.get_cluster_stats()
    print(f"\n📈 Estadísticas del Cluster:")
    print(f"   Total de servidores: {stats['total_servers']}")
    print(f"   Total de conexiones: {stats['total_connections']}")
    print(f"   Total de clusters: {stats['total_clusters']}")
    print(f"   Servidores activos: {stats['active_servers']}")
    print(f"   CPU promedio: {stats['average_cpu']}%")
    print(f"   Memoria promedio: {stats['average_memory']}%")
    print(f"   Disco promedio: {stats['average_disk']}%")
    
    print(f"\n   Servidores por tipo:")
    for server_type, count in stats['servers_by_type'].items():
        print(f"     {server_type}: {count}")
    
    print(f"\n   Servidores por región:")
    for region, count in stats['servers_by_region'].items():
        print(f"     {region}: {count}")
    
    # Iniciar actualizaciones en tiempo real
    cluster_manager.start_real_time_updates()
    
    print(f"\n🎯 Dashboard interactivo generado: {dashboard_file}")
    print("🌐 Abra el archivo en un navegador para visualizar y gestionar el cluster")
    print("🔄 Las actualizaciones en tiempo real están activas")
    
    # Exportar configuración
    cluster_manager.export_cluster_config("demo_cluster_config.json")
    print("💾 Configuración exportada a demo_cluster_config.json")
    
    # Generar reporte estático
    from fossflow import FossFlowVisualizer
    visualizer = FossFlowVisualizer()
    report_file = visualizer.generate_static_report(
        cluster_manager.generate_fossflow_data(), 
        "demo_cluster_report.html"
    )
    print(f"📄 Reporte estático generado: {report_file}")
    
    print("\n✅ Demo del sistema de clustering ilimitado con FossFlow completado!")
    print("🎉 El sistema está listo para uso con servidores reales o simulados")
    
    # Mantener el sistema corriendo para demostrar actualizaciones en tiempo real
    print("\n⏰ Manteniendo sistema activo por 30 segundos para demostrar actualizaciones...")
    try:
        time.sleep(30)
        print("⏰ Demostración completada. El sistema seguirá corriendo en segundo plano.")
    except KeyboardInterrupt:
        print("\n⏹️ Demostración interrumpida por el usuario.")

if __name__ == "__main__":
    main()