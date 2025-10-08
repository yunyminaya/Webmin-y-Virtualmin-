#!/usr/bin/env python3
"""
Blockchain para logs inmutables y auditoría en Webmin/Virtualmin
Implementa cadena de bloques privada con hashing SHA-256 y consenso simple
"""

import hashlib
import json
import time
from datetime import datetime
import os

class Block:
    def __init__(self, index, timestamp, logs, previous_hash, nonce=0):
        self.index = index
        self.timestamp = timestamp
        self.logs = logs  # Lista de diccionarios con logs
        self.previous_hash = previous_hash
        self.nonce = nonce
        self.hash = self.calculate_hash()

    def calculate_hash(self):
        """Calcula el hash SHA-256 del bloque"""
        block_string = json.dumps({
            "index": self.index,
            "timestamp": self.timestamp,
            "logs": self.logs,
            "previous_hash": self.previous_hash,
            "nonce": self.nonce
        }, sort_keys=True, default=str)
        return hashlib.sha256(block_string.encode()).hexdigest()

    def mine_block(self, difficulty=4):
        """Proof-of-work simple"""
        target = "0" * difficulty
        while self.hash[:difficulty] != target:
            self.nonce += 1
            self.hash = self.calculate_hash()
        return self.hash

    def to_dict(self):
        """Convierte el bloque a diccionario para serialización"""
        return {
            "index": self.index,
            "timestamp": self.timestamp,
            "logs": self.logs,
            "previous_hash": self.previous_hash,
            "nonce": self.nonce,
            "hash": self.hash
        }

    @classmethod
    def from_dict(cls, data):
        """Crea un bloque desde diccionario"""
        block = cls(
            data["index"],
            data["timestamp"],
            data["logs"],
            data["previous_hash"],
            data["nonce"]
        )
        block.hash = data["hash"]
        return block

class Blockchain:
    def __init__(self, difficulty=4, block_size=10):
        self.chain = []
        self.pending_logs = []
        self.difficulty = difficulty
        self.block_size = block_size  # Número de logs por bloque
        self.create_genesis_block()

    def create_genesis_block(self):
        """Crea el bloque génesis"""
        genesis_block = Block(0, time.time(), [], "0", 0)
        genesis_block.mine_block(self.difficulty)
        self.chain.append(genesis_block)

    def get_latest_block(self):
        """Obtiene el último bloque"""
        return self.chain[-1]

    def add_log(self, log_data):
        """Agrega un log a la lista pendiente"""
        self.pending_logs.append(log_data)
        if len(self.pending_logs) >= self.block_size:
            self.mine_pending_logs()

    def mine_pending_logs(self):
        """Crea un nuevo bloque con los logs pendientes"""
        if not self.pending_logs:
            return

        new_block = Block(
            len(self.chain),
            time.time(),
            self.pending_logs.copy(),
            self.get_latest_block().hash
        )
        new_block.mine_block(self.difficulty)
        self.chain.append(new_block)
        self.pending_logs = []  # Limpiar logs pendientes

    def is_chain_valid(self):
        """Verifica la integridad de la cadena"""
        for i in range(1, len(self.chain)):
            current_block = self.chain[i]
            previous_block = self.chain[i-1]

            # Verificar hash del bloque actual
            if current_block.hash != current_block.calculate_hash():
                return False

            # Verificar que apunta al hash anterior correcto
            if current_block.previous_hash != previous_block.hash:
                return False

            # Verificar proof-of-work
            if current_block.hash[:self.difficulty] != "0" * self.difficulty:
                return False

        return True

    def search_logs(self, filters=None):
        """Busca logs en la cadena con filtros opcionales"""
        results = []
        for block in self.chain:
            for log in block.logs:
                match = True
                if filters:
                    for key, value in filters.items():
                        if key not in log or log[key] != value:
                            match = False
                            break
                if match:
                    results.append({
                        "block_index": block.index,
                        "block_hash": block.hash,
                        "log": log
                    })
        return results

    def get_timeline(self, start_time=None, end_time=None):
        """Obtiene timeline de logs entre timestamps"""
        timeline = []
        for block in self.chain:
            if start_time and block.timestamp < start_time:
                continue
            if end_time and block.timestamp > end_time:
                continue
            for log in block.logs:
                timeline.append({
                    "timestamp": log.get("timestamp", block.timestamp),
                    "block_index": block.index,
                    "log": log
                })
        # Ordenar por timestamp
        timeline.sort(key=lambda x: x["timestamp"])
        return timeline

    def save_to_file(self, filename="blockchain.json"):
        """Guarda la cadena en archivo JSON"""
        chain_data = [block.to_dict() for block in self.chain]
        with open(filename, 'w') as f:
            json.dump(chain_data, f, indent=2, default=str)

    def load_from_file(self, filename="blockchain.json"):
        """Carga la cadena desde archivo JSON"""
        if not os.path.exists(filename):
            return
        with open(filename, 'r') as f:
            chain_data = json.load(f)
        self.chain = [Block.from_dict(data) for data in chain_data]

    def get_stats(self):
        """Obtiene estadísticas de la cadena"""
        total_blocks = len(self.chain)
        total_logs = sum(len(block.logs) for block in self.chain)
        chain_size = len(json.dumps([block.to_dict() for block in self.chain]))
        return {
            "total_blocks": total_blocks,
            "total_logs": total_logs,
            "chain_size_bytes": chain_size,
            "pending_logs": len(self.pending_logs),
            "is_valid": self.is_chain_valid()
        }