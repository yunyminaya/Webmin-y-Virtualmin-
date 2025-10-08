#!/usr/bin/env python3
"""
Script de Prueba Simple del Sistema de Backup Inteligente
Prueba básica de funcionalidades individuales
"""

import os
import sys
import tempfile
import shutil
import time
from pathlib import Path

def test_basic_functionality():
    """Prueba básica de funcionalidades individuales"""
    print("=== PRUEBA BÁSICA DE FUNCIONALIDADES ===")

    # Agregar el directorio del sistema al path
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'intelligent_backup_system'))

    try:
        # Probar importación de módulos básicos
        print("Probando importaciones...")

        # Importar deduplicator
        import deduplication.deduplicator as dedup_mod
        print("✓ Deduplicator importado")

        # Importar compressor
        import compression.compressor as comp_mod
        print("✓ Compressor importado")

        # Importar encryptor
        import encryption.encryptor as enc_mod
        print("✓ Encryptor importado")

        # Importar storage
        import storage.storage_manager as stor_mod
        print("✓ Storage manager importado")

        # Importar verifier
        import verification.verifier as ver_mod
        print("✓ Verifier importado")

        # Importar incremental
        import core.incremental_backup as inc_mod
        print("✓ Incremental backup importado")

        # Importar restorer
        import restoration.restorer as rest_mod
        print("✓ Restorer importado")

        # Importar monitoring
        import monitoring.integration as mon_mod
        print("✓ Monitoring integration importado")

        # Probar instancias básicas
        print("\nProbando instancias...")

        # Deduplicator
        deduplicator = dedup_mod.BlockDeduplicator()
        print("✓ Deduplicator instanciado")

        # Compressor
        compressor = comp_mod.AdaptiveCompressor()
        print("✓ Compressor instanciado")

        # Encryptor
        encryptor = enc_mod.AES256Encryptor()
        print("✓ Encryptor instanciado")

        # Storage Manager
        storage_manager = stor_mod.StorageManager()
        print("✓ Storage manager instanciado")

        # Verifier
        verifier = ver_mod.IntegrityVerifier()
        print("✓ Verifier instanciado")

        # Incremental Engine
        incremental_engine = inc_mod.IncrementalBackupEngine()
        print("✓ Incremental engine instanciado")

        # Restorer
        restorer = rest_mod.GranularRestorer("/tmp")
        print("✓ Restorer instanciado")

        # Monitoring
        monitoring = mon_mod.MonitoringIntegration()
        print("✓ Monitoring integration instanciado")

        print("\n=== TODAS LAS IMPORTACIONES Y INSTANCIAS EXITOSAS ===")
        return True

    except Exception as e:
        print(f"❌ ERROR: {e}")
        import traceback
        traceback.print_exc()
        return False

def test_compression_basic():
    """Prueba básica de compresión"""
    print("\n=== PRUEBA BÁSICA DE COMPRESIÓN ===")

    try:
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'intelligent_backup_system'))
        import compression.compressor as comp_mod

        compressor = comp_mod.AdaptiveCompressor()

        # Datos de prueba
        test_data = b"This is test data for compression testing. " * 100

        # Comprimir
        result = compressor.compress_data(test_data)
        print(f"Original: {result.original_size} bytes")
        print(f"Comprimido: {result.compressed_size} bytes")
        print(f"Ratio: {result.compression_ratio:.2f}")

        # Descomprimir
        decompressed = compressor.decompress_data(result.data, result.algorithm)
        assert decompressed == test_data, "Los datos deben ser idénticos"

        print("✓ Compresión básica funcionando")
        return True

    except Exception as e:
        print(f"❌ ERROR en compresión: {e}")
        return False

def test_encryption_basic():
    """Prueba básica de encriptación"""
    print("\n=== PRUEBA BÁSICA DE ENCRIPTACIÓN ===")

    try:
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'intelligent_backup_system'))
        import encryption.encryptor as enc_mod

        encryptor = enc_mod.AES256Encryptor()

        # Datos de prueba
        test_data = b"Sensitive data to encrypt"

        # Encriptar
        encrypted = encryptor.encrypt_data(test_data)
        print(f"Datos encriptados: {len(encrypted.data)} bytes")

        # Desencriptar
        decrypted = encryptor.decrypt_data(encrypted.data)
        assert decrypted.data == test_data, "Los datos deben ser idénticos"

        print("✓ Encriptación básica funcionando")
        return True

    except Exception as e:
        print(f"❌ ERROR en encriptación: {e}")
        return False

def test_deduplication_basic():
    """Prueba básica de deduplicación"""
    print("\n=== PRUEBA BÁSICA DE DEDUPLICACIÓN ===")

    try:
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'intelligent_backup_system'))
        import deduplication.deduplicator as dedup_mod

        with tempfile.TemporaryDirectory() as temp_dir:
            # Crear archivos de prueba
            test_dir = Path(temp_dir) / "test"
            test_dir.mkdir()

            # Archivo con contenido duplicado
            duplicate_content = "This is duplicate content. " * 50
            (test_dir / "file1.txt").write_text(duplicate_content)
            (test_dir / "file2.txt").write_text(duplicate_content)  # Contenido idéntico
            (test_dir / "file3.txt").write_text("Unique content here.")

            deduplicator = dedup_mod.BlockDeduplicator()

            # Procesar
            stats = deduplicator.deduplicate_directory(str(test_dir))

            print(f"Bloques totales: {stats.total_blocks}")
            print(f"Bloques únicos: {stats.unique_blocks}")
            print(f"Bloques duplicados: {stats.duplicated_blocks}")

            assert stats.duplicated_blocks > 0, "Debe haber duplicados"
            print("✓ Deduplicación básica funcionando")
            return True

    except Exception as e:
        print(f"❌ ERROR en deduplicación: {e}")
        return False

def main():
    """Función principal"""
    print("=== PRUEBA SIMPLE DEL SISTEMA DE BACKUP INTELIGENTE ===")

    start_time = time.time()

    results = []
    results.append(test_basic_functionality())
    results.append(test_compression_basic())
    results.append(test_encryption_basic())
    results.append(test_deduplication_basic())

    total_time = time.time() - start_time

    passed = sum(results)
    total = len(results)

    print("\n=== RESULTADOS FINALES ===")
    print(f"Pruebas pasadas: {passed}/{total}")
    print(f"Tiempo total: {total_time:.2f} segundos")
    print("\nFuncionalidades básicas probadas:")
    print("✓ Importaciones de módulos")
    print("✓ Instanciación de clases")
    print("✓ Compresión básica")
    print("✓ Encriptación básica")
    print("✓ Deduplicación básica")

    if passed == total:
        print("\n🎉 TODAS LAS PRUEBAS BÁSICAS PASARON EXITOSAMENTE")
        return True
    else:
        print(f"\n❌ {total - passed} PRUEBAS FALLARON")
        return False

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)