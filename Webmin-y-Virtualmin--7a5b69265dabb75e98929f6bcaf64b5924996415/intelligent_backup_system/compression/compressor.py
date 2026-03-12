#!/usr/bin/env python3
"""
Módulo de Compresión Adaptativa
Implementa compresión LZ4/Zstandard adaptativa basada en el tipo de datos
para el sistema de backup inteligente de Webmin/Virtualmin
"""

import lz4.frame
import zstandard as zstd
import gzip
import bz2
import os
import time
from typing import Dict, List, Tuple, Optional, BinaryIO
from enum import Enum
from dataclasses import dataclass
import logging
import struct

class CompressionAlgorithm(Enum):
    """Algoritmos de compresión soportados"""
    LZ4 = "lz4"
    ZSTD = "zstd"
    GZIP = "gzip"
    BZIP2 = "bzip2"
    NONE = "none"

@dataclass
class CompressionResult:
    """Resultado de una operación de compresión"""
    algorithm: CompressionAlgorithm
    original_size: int
    compressed_size: int
    compression_ratio: float
    compression_time: float
    data: Optional[bytes] = None

@dataclass
class CompressionStats:
    """Estadísticas de compresión"""
    total_original_size: int = 0
    total_compressed_size: int = 0
    total_compression_time: float = 0.0
    algorithms_used: Dict[CompressionAlgorithm, int] = None

    def __post_init__(self):
        if self.algorithms_used is None:
            self.algorithms_used = {alg: 0 for alg in CompressionAlgorithm}

class AdaptiveCompressor:
    """
    Compresor adaptativo que selecciona el mejor algoritmo
    basado en el tipo de datos y características del contenido
    """

    def __init__(self, benchmark_samples: int = 1024):
        """
        Inicializar el compresor adaptativo

        Args:
            benchmark_samples: Número de muestras para benchmarking
        """
        self.benchmark_samples = benchmark_samples
        self.logger = logging.getLogger(__name__)

        # Configuraciones de compresión
        self.zstd_compressor = zstd.ZstdCompressor(level=3)
        self.zstd_decompressor = zstd.ZstdDecompressor()

        # Umbrales para selección automática
        self.thresholds = {
            'text_ratio': 0.7,  # Ratio de datos de texto
            'compression_speed_priority': 0.8,  # Prioridad velocidad vs ratio
            'min_size_for_compression': 1024,  # Tamaño mínimo para comprimir
        }

    def _detect_content_type(self, data: bytes) -> str:
        """
        Detectar el tipo de contenido usando magic numbers y análisis

        Args:
            data: Datos a analizar

        Returns:
            Tipo de contenido detectado
        """
        if len(data) < 4:
            return "unknown"

        # Magic numbers básicos
        magic_numbers = {
            b'\x89PNG': 'png',
            b'\xFF\xD8\xFF': 'jpeg',
            b'\x42\x4D': 'bmp',
            b'\x47\x49\x46\x38': 'gif',
            b'\x25\x50\x44\x46': 'pdf',
            b'\x50\x4B\x03\x04': 'zip',
            b'\x52\x61\x72\x21': 'rar',
            b'\x1F\x8B': 'gzip',
            b'\x42\x5A\x68': 'bzip2',
        }

        # Verificar magic numbers
        for magic, content_type in magic_numbers.items():
            if data.startswith(magic):
                return content_type

        # Análisis de entropía para detectar texto vs binario
        if self._is_text_data(data):
            return "text"

        return "binary"

    def _is_text_data(self, data: bytes, sample_size: int = 1024) -> bool:
        """
        Determinar si los datos son principalmente texto

        Args:
            data: Datos a analizar
            sample_size: Tamaño de muestra

        Returns:
            True si es principalmente texto
        """
        sample = data[:sample_size]
        text_chars = 0
        total_chars = len(sample)

        for byte in sample:
            if 32 <= byte <= 126 or byte in (9, 10, 13):  # Printable ASCII + whitespace
                text_chars += 1

        text_ratio = text_chars / total_chars if total_chars > 0 else 0
        return text_ratio > self.thresholds['text_ratio']

    def _compress_lz4(self, data: bytes) -> Tuple[bytes, float]:
        """Comprimir usando LZ4"""
        start_time = time.time()
        compressed = lz4.frame.compress(data)
        compression_time = time.time() - start_time
        return compressed, compression_time

    def _compress_zstd(self, data: bytes) -> Tuple[bytes, float]:
        """Comprimir usando Zstandard"""
        start_time = time.time()
        compressed = self.zstd_compressor.compress(data)
        compression_time = time.time() - start_time
        return compressed, compression_time

    def _compress_gzip(self, data: bytes) -> Tuple[bytes, float]:
        """Comprimir usando GZIP"""
        start_time = time.time()
        compressed = gzip.compress(data)
        compression_time = time.time() - start_time
        return compressed, compression_time

    def _compress_bzip2(self, data: bytes) -> Tuple[bytes, float]:
        """Comprimir usando BZIP2"""
        start_time = time.time()
        compressed = bz2.compress(data)
        compression_time = time.time() - start_time
        return compressed, compression_time

    def _benchmark_algorithms(self, data: bytes) -> Dict[CompressionAlgorithm, CompressionResult]:
        """
        Hacer benchmark de todos los algoritmos en una muestra de datos

        Args:
            data: Datos de muestra

        Returns:
            Diccionario con resultados de cada algoritmo
        """
        results = {}

        # LZ4 - Muy rápido, buena compresión para datos repetitivos
        try:
            compressed, comp_time = self._compress_lz4(data)
            results[CompressionAlgorithm.LZ4] = CompressionResult(
                algorithm=CompressionAlgorithm.LZ4,
                original_size=len(data),
                compressed_size=len(compressed),
                compression_ratio=len(data) / len(compressed) if compressed else 1.0,
                compression_time=comp_time
            )
        except Exception as e:
            self.logger.warning(f"Error benchmarking LZ4: {e}")

        # Zstandard - Balance velocidad/ratio
        try:
            compressed, comp_time = self._compress_zstd(data)
            results[CompressionAlgorithm.ZSTD] = CompressionResult(
                algorithm=CompressionAlgorithm.ZSTD,
                original_size=len(data),
                compressed_size=len(compressed),
                compression_ratio=len(data) / len(compressed) if compressed else 1.0,
                compression_time=comp_time
            )
        except Exception as e:
            self.logger.warning(f"Error benchmarking ZSTD: {e}")

        # GZIP - Estándar, buen ratio pero más lento
        try:
            compressed, comp_time = self._compress_gzip(data)
            results[CompressionAlgorithm.GZIP] = CompressionResult(
                algorithm=CompressionAlgorithm.GZIP,
                original_size=len(data),
                compressed_size=len(compressed),
                compression_ratio=len(data) / len(compressed) if compressed else 1.0,
                compression_time=comp_time
            )
        except Exception as e:
            self.logger.warning(f"Error benchmarking GZIP: {e}")

        # BZIP2 - Mejor ratio pero muy lento
        try:
            compressed, comp_time = self._compress_bzip2(data)
            results[CompressionAlgorithm.BZIP2] = CompressionResult(
                algorithm=CompressionAlgorithm.BZIP2,
                original_size=len(data),
                compressed_size=len(compressed),
                compression_ratio=len(data) / len(compressed) if compressed else 1.0,
                compression_time=comp_time
            )
        except Exception as e:
            self.logger.warning(f"Error benchmarking BZIP2: {e}")

        return results

    def _select_best_algorithm(self, benchmark_results: Dict[CompressionAlgorithm, CompressionResult],
                             content_type: str) -> CompressionAlgorithm:
        """
        Seleccionar el mejor algoritmo basado en benchmarks y tipo de contenido

        Args:
            benchmark_results: Resultados del benchmark
            content_type: Tipo de contenido detectado

        Returns:
            Algoritmo seleccionado
        """
        if not benchmark_results:
            return CompressionAlgorithm.NONE

        # Para archivos muy pequeños, no comprimir
        if benchmark_results[CompressionAlgorithm.LZ4].original_size < self.thresholds['min_size_for_compression']:
            return CompressionAlgorithm.NONE

        # Estrategias por tipo de contenido
        if content_type == 'text':
            # Para texto: priorizar ratio de compresión sobre velocidad
            best_result = max(benchmark_results.values(),
                            key=lambda x: x.compression_ratio)
            return best_result.algorithm

        elif content_type in ['png', 'jpeg', 'gif', 'bmp']:
            # Para imágenes: LZ4 es generalmente mejor que recomprimir
            return CompressionAlgorithm.LZ4

        elif content_type in ['pdf', 'zip', 'rar', 'gzip', 'bzip2']:
            # Para archivos ya comprimidos: LZ4 para velocidad
            return CompressionAlgorithm.LZ4

        else:
            # Para datos binarios generales: balance velocidad/ratio
            # Usar ZSTD como default inteligente
            if CompressionAlgorithm.ZSTD in benchmark_results:
                return CompressionAlgorithm.ZSTD
            else:
                # Fallback a LZ4
                return CompressionAlgorithm.LZ4

    def compress_data(self, data: bytes, force_algorithm: Optional[CompressionAlgorithm] = None) -> CompressionResult:
        """
        Comprimir datos usando el mejor algoritmo automáticamente

        Args:
            data: Datos a comprimir
            force_algorithm: Forzar un algoritmo específico (opcional)

        Returns:
            Resultado de la compresión
        """
        original_size = len(data)

        # Si los datos son muy pequeños, no comprimir
        if original_size < self.thresholds['min_size_for_compression']:
            return CompressionResult(
                algorithm=CompressionAlgorithm.NONE,
                original_size=original_size,
                compressed_size=original_size,
                compression_ratio=1.0,
                compression_time=0.0,
                data=data
            )

        # Detectar tipo de contenido
        content_type = self._detect_content_type(data)

        # Si se fuerza un algoritmo, usarlo
        if force_algorithm:
            algorithm = force_algorithm
        else:
            # Hacer benchmark para seleccionar el mejor
            benchmark_results = self._benchmark_algorithms(data)
            algorithm = self._select_best_algorithm(benchmark_results, content_type)

        # Aplicar compresión
        start_time = time.time()

        try:
            if algorithm == CompressionAlgorithm.LZ4:
                compressed_data, _ = self._compress_lz4(data)
            elif algorithm == CompressionAlgorithm.ZSTD:
                compressed_data, _ = self._compress_zstd(data)
            elif algorithm == CompressionAlgorithm.GZIP:
                compressed_data, _ = self._compress_gzip(data)
            elif algorithm == CompressionAlgorithm.BZIP2:
                compressed_data, _ = self._compress_bzip2(data)
            else:
                compressed_data = data

            compression_time = time.time() - start_time
            compressed_size = len(compressed_data)
            compression_ratio = original_size / compressed_size if compressed_size > 0 else 1.0

            return CompressionResult(
                algorithm=algorithm,
                original_size=original_size,
                compressed_size=compressed_size,
                compression_ratio=compression_ratio,
                compression_time=compression_time,
                data=compressed_data
            )

        except Exception as e:
            self.logger.error(f"Error comprimiendo datos: {e}")
            # Fallback: devolver datos sin comprimir
            return CompressionResult(
                algorithm=CompressionAlgorithm.NONE,
                original_size=original_size,
                compressed_size=original_size,
                compression_ratio=1.0,
                compression_time=time.time() - start_time,
                data=data
            )

    def decompress_data(self, compressed_data: bytes, algorithm: CompressionAlgorithm) -> bytes:
        """
        Descomprimir datos

        Args:
            compressed_data: Datos comprimidos
            algorithm: Algoritmo usado para comprimir

        Returns:
            Datos descomprimidos
        """
        try:
            if algorithm == CompressionAlgorithm.LZ4:
                return lz4.frame.decompress(compressed_data)
            elif algorithm == CompressionAlgorithm.ZSTD:
                return self.zstd_decompressor.decompress(compressed_data)
            elif algorithm == CompressionAlgorithm.GZIP:
                return gzip.decompress(compressed_data)
            elif algorithm == CompressionAlgorithm.BZIP2:
                return bz2.decompress(compressed_data)
            else:
                return compressed_data
        except Exception as e:
            self.logger.error(f"Error descomprimiendo datos: {e}")
            raise

    def compress_file(self, input_path: str, output_path: str,
                     force_algorithm: Optional[CompressionAlgorithm] = None) -> CompressionResult:
        """
        Comprimir un archivo completo

        Args:
            input_path: Ruta al archivo de entrada
            output_path: Ruta al archivo de salida
            force_algorithm: Algoritmo forzado (opcional)

        Returns:
            Resultado de la compresión
        """
        with open(input_path, 'rb') as f:
            data = f.read()

        result = self.compress_data(data, force_algorithm)

        # Guardar datos comprimidos
        with open(output_path, 'wb') as f:
            # Escribir header con información del algoritmo
            header = struct.pack('!I', result.algorithm.value)
            f.write(header)
            f.write(result.data)

        return result

    def decompress_file(self, input_path: str, output_path: str) -> CompressionResult:
        """
        Descomprimir un archivo

        Args:
            input_path: Ruta al archivo comprimido
            output_path: Ruta al archivo de salida

        Returns:
            Resultado de la descompresión
        """
        with open(input_path, 'rb') as f:
            # Leer header
            header_size = struct.calcsize('!I')
            header = f.read(header_size)
            algorithm_value = struct.unpack('!I', header)[0]

            try:
                algorithm = CompressionAlgorithm(algorithm_value)
            except ValueError:
                raise ValueError(f"Algoritmo desconocido: {algorithm_value}")

            compressed_data = f.read()

        # Descomprimir
        start_time = time.time()
        decompressed_data = self.decompress_data(compressed_data, algorithm)
        decompression_time = time.time() - start_time

        # Guardar datos descomprimidos
        with open(output_path, 'wb') as f:
            f.write(decompressed_data)

        return CompressionResult(
            algorithm=algorithm,
            original_size=len(compressed_data),
            compressed_size=len(decompressed_data),
            compression_ratio=len(decompressed_data) / len(compressed_data) if compressed_data else 1.0,
            compression_time=decompression_time,
            data=decompressed_data
        )

    def get_compression_stats(self, data_samples: List[bytes]) -> Dict[str, any]:
        """
        Obtener estadísticas de compresión para muestras de datos

        Args:
            data_samples: Lista de muestras de datos

        Returns:
            Diccionario con estadísticas
        """
        stats = CompressionStats()
        algorithm_performance = {alg: [] for alg in CompressionAlgorithm}

        for sample in data_samples[:self.benchmark_samples]:
            benchmark_results = self._benchmark_algorithms(sample)

            for algorithm, result in benchmark_results.items():
                stats.total_original_size += result.original_size
                stats.total_compressed_size += result.compressed_size
                stats.total_compression_time += result.compression_time
                stats.algorithms_used[algorithm] += 1

                algorithm_performance[algorithm].append(result.compression_ratio)

        # Calcular promedios
        avg_ratios = {}
        for algorithm, ratios in algorithm_performance.items():
            if ratios:
                avg_ratios[algorithm] = sum(ratios) / len(ratios)
            else:
                avg_ratios[algorithm] = 1.0

        return {
            'total_samples': len(data_samples),
            'total_original_size': stats.total_original_size,
            'total_compressed_size': stats.total_compressed_size,
            'average_compression_ratio': stats.total_original_size / stats.total_compressed_size if stats.total_compressed_size > 0 else 1.0,
            'total_compression_time': stats.total_compression_time,
            'algorithms_used': dict(stats.algorithms_used),
            'average_ratios_by_algorithm': {alg.value: ratio for alg, ratio in avg_ratios.items()}
        }