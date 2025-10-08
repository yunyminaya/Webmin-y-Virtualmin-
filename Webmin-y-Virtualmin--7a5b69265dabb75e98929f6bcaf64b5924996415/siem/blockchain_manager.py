#!/usr/bin/env python3
"""
Gestor de blockchain para integración con SIEM
Maneja la adición de logs desde la base de datos SIEM y operaciones de blockchain
"""

import sqlite3
import json
import time
from datetime import datetime
from blockchain import Blockchain

class BlockchainManager:
    def __init__(self, siem_db="siem_events.db", blockchain_file="blockchain.json", block_size=3):
        self.siem_db = siem_db
        self.blockchain_file = blockchain_file
        self.state_file = blockchain_file.replace('.json', '_state.json')
        self.blockchain = Blockchain(block_size=block_size)
        self.blockchain.load_from_file(blockchain_file)
        self.last_processed_id = self.load_state()

    def load_state(self):
        """Carga el estado desde archivo"""
        try:
            if os.path.exists(self.state_file):
                with open(self.state_file, 'r') as f:
                    state = json.load(f)
                    return state.get('last_processed_id', 0)
        except:
            pass
        # Fallback: obtener desde blockchain
        max_id = 0
        for block in self.blockchain.chain:
            for log in block.logs:
                if log.get("id", 0) > max_id:
                    max_id = log["id"]
        return max_id

    def save_state(self):
        """Guarda el estado en archivo"""
        state = {
            'last_processed_id': self.last_processed_id
        }
        try:
            with open(self.state_file, 'w') as f:
                json.dump(state, f)
        except Exception as e:
            print(f"Error saving state: {e}")

    def get_new_logs_from_siem(self):
        """Obtiene nuevos logs desde la base de datos SIEM"""
        try:
            conn = sqlite3.connect(self.siem_db)
            cursor = conn.cursor()

            # Obtener logs no procesados por blockchain
            cursor.execute("""
                SELECT id, timestamp, source, event_type, severity, message, raw_log,
                       ip_address, user_agent, session_id, correlation_id, tags
                FROM events
                WHERE id > ?
                ORDER BY id
            """, (self.last_processed_id,))

            logs = []
            for row in cursor.fetchall():
                log_data = {
                    "id": row[0],
                    "timestamp": row[1],
                    "source": row[2],
                    "event_type": row[3],
                    "severity": row[4],
                    "message": row[5],
                    "raw_log": row[6],
                    "ip_address": row[7],
                    "user_agent": row[8],
                    "session_id": row[9],
                    "correlation_id": row[10],
                    "tags": row[11]
                }
                logs.append(log_data)

            conn.close()
            return logs

        except sqlite3.Error as e:
            print(f"Error al acceder a la base de datos SIEM: {e}")
            return []

    def process_new_logs(self):
        """Procesa nuevos logs desde SIEM y los agrega a la blockchain"""
        new_logs = self.get_new_logs_from_siem()
        if not new_logs:
            return 0

        added_count = 0
        for log in new_logs:
            self.blockchain.add_log(log)
            self.last_processed_id = max(self.last_processed_id, log["id"])
            added_count += 1

        # Guardar la blockchain actualizada
        self.blockchain.save_to_file(self.blockchain_file)
        self.save_state()
        return added_count

    def verify_integrity(self):
        """Verifica la integridad de la blockchain y compara con SIEM"""
        # Verificar cadena
        if not self.blockchain.is_chain_valid():
            return {"valid": False, "error": "Cadena de bloques corrupta"}

        # Verificar que todos los logs en blockchain existan en SIEM
        blockchain_logs = []
        for block in self.blockchain.chain:
            blockchain_logs.extend(block.logs)

        try:
            conn = sqlite3.connect(self.siem_db)
            cursor = conn.cursor()

            mismatches = []
            for log in blockchain_logs:
                cursor.execute("SELECT COUNT(*) FROM events WHERE id = ?", (log["id"],))
                count = cursor.fetchone()[0]
                if count == 0:
                    mismatches.append(f"Log ID {log['id']} no encontrado en SIEM")

            conn.close()

            return {
                "valid": len(mismatches) == 0,
                "blockchain_logs": len(blockchain_logs),
                "mismatches": mismatches,
                "chain_valid": True
            }

        except sqlite3.Error as e:
            return {"valid": False, "error": f"Error de base de datos: {e}"}

    def forensic_search(self, filters=None, start_time=None, end_time=None):
        """Búsqueda forense en la blockchain"""
        # Buscar en blockchain
        blockchain_results = self.blockchain.search_logs(filters)

        # Filtrar por tiempo si se especifica
        if start_time or end_time:
            filtered_results = []
            for result in blockchain_results:
                log_time = datetime.fromisoformat(result["log"]["timestamp"])
                if start_time and log_time < start_time:
                    continue
                if end_time and log_time > end_time:
                    continue
                filtered_results.append(result)
            blockchain_results = filtered_results

        return blockchain_results

    def get_timeline(self, start_time=None, end_time=None):
        """Obtiene timeline inmutable de logs"""
        return self.blockchain.get_timeline(start_time, end_time)

    def get_stats(self):
        """Obtiene estadísticas del sistema blockchain"""
        stats = self.blockchain.get_stats()
        stats["last_processed_id"] = self.last_processed_id
        stats["siem_db"] = self.siem_db
        stats["blockchain_file"] = self.blockchain_file
        return stats

    def force_mine_pending(self):
        """Fuerza la creación de un bloque con logs pendientes"""
        if self.blockchain.pending_logs:
            self.blockchain.mine_pending_logs()
            self.blockchain.save_to_file(self.blockchain_file)
            return True
        return False

def main():
    """Función principal para ejecutar desde línea de comandos"""
    import sys

    if len(sys.argv) < 2:
        print("Uso: python3 blockchain_manager.py <comando> [opciones]")
        print("Comandos:")
        print("  process    - Procesa nuevos logs desde SIEM")
        print("  verify     - Verifica integridad de la blockchain")
        print("  stats      - Muestra estadísticas")
        print("  mine       - Fuerza minado de bloque pendiente")
        print("  search <filtro_json> - Busca logs con filtros JSON")
        return

    manager = BlockchainManager()

    command = sys.argv[1]

    if command == "process":
        count = manager.process_new_logs()
        print(f"Procesados {count} nuevos logs")

    elif command == "verify":
        result = manager.verify_integrity()
        print(json.dumps(result, indent=2))

    elif command == "stats":
        stats = manager.get_stats()
        print(json.dumps(stats, indent=2))

    elif command == "mine":
        success = manager.force_mine_pending()
        print(f"Bloque minado: {success}")

    elif command == "search" and len(sys.argv) > 2:
        try:
            filters = json.loads(sys.argv[2])
            results = manager.forensic_search(filters)
            print(json.dumps(results, indent=2, default=str))
        except json.JSONDecodeError:
            print("Filtro JSON inválido")

if __name__ == "__main__":
    main()