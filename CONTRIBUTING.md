# 🤝 GUÍA DE CONTRIBUCIÓN

¡Gracias por tu interés en contribuir al proyecto **Webmin y Virtualmin Instalador Universal**!

## 📋 ANTES DE CONTRIBUIR

### Requisitos Previos
- Conocimiento básico de Bash scripting
- Experiencia con sistemas Ubuntu/Debian
- Familiaridad con Webmin/Virtualmin
- Acceso a un entorno de pruebas

## 🚀 CÓMO CONTRIBUIR

### 1. Fork del Repositorio
```bash
# Clona tu fork
git clone https://github.com/TU_USUARIO/Webmin-y-Virtualmin-.git
cd Webmin-y-Virtualmin-

# Configura el repositorio original como upstream
git remote add upstream https://github.com/yunyminaya/Webmin-y-Virtualmin-.git
```

### 2. Crear una Rama
```bash
# Crea una rama para tu feature/fix
git checkout -b feature/nombre-descriptivo
# o
git checkout -b fix/descripcion-del-bug
```

### 3. Realizar Cambios
- Mantén el estilo de código existente
- Añade comentarios descriptivos
- Prueba tus cambios en múltiples entornos
- Actualiza la documentación si es necesario

### 4. Pruebas
```bash
# Ejecuta las pruebas del sistema
./test_sistema_completo.sh

# Pruebas específicas de funciones
./test_funciones_macos.sh

# Pruebas de túneles
./test_exhaustivo_tuneles.sh --full
```

### 5. Commit y Push
```bash
# Añade los cambios
git add .

# Commit con mensaje descriptivo
git commit -m "feat: descripción clara del cambio"
# o
git commit -m "fix: descripción del bug corregido"

# Push a tu fork
git push origin feature/nombre-descriptivo
```

### 6. Pull Request
1. Ve a GitHub y crea un Pull Request
2. Describe claramente los cambios realizados
3. Incluye capturas de pantalla si es relevante
4. Menciona issues relacionados con `#numero`

## 📝 ESTÁNDARES DE CÓDIGO

### Bash Scripts
```bash
#!/bin/bash
# Descripción del script
# Autor: Tu Nombre
# Fecha: YYYY-MM-DD

set -euo pipefail  # Modo estricto

# Variables globales en MAYÚSCULAS
VERSION="1.0.0"
LOG_FILE="/tmp/script.log"

# Funciones con nombres descriptivos
function verificar_sistema() {
    # Código aquí
}

# Logging consistente
function log_info() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $1" | tee -a "$LOG_FILE"
}
```

### Documentación
- Usa Markdown para toda la documentación
- Incluye ejemplos de uso
- Mantén la consistencia con el estilo existente
- Añade emojis para mejorar la legibilidad

## 🐛 REPORTAR BUGS

### Información Requerida
1. **Sistema Operativo**: Ubuntu/Debian versión
2. **Versión del Script**: Commit hash o versión
3. **Descripción del Error**: Qué esperabas vs qué ocurrió
4. **Logs**: Incluye logs relevantes
5. **Pasos para Reproducir**: Lista detallada

### Template de Bug Report
```markdown
**Descripción del Bug**
Descripción clara y concisa del problema.

**Pasos para Reproducir**
1. Ejecutar '...'
2. Ver error en '...'
3. El error aparece

**Comportamiento Esperado**
Qué debería haber pasado.

**Capturas de Pantalla**
Si aplica, añade capturas.

**Información del Sistema**
- OS: [ej. Ubuntu 20.04]
- Versión del Script: [ej. v2.1.0]
- Logs: [pega logs relevantes]
```

## 💡 SUGERIR FEATURES

### Antes de Sugerir
1. Revisa issues existentes
2. Considera si es útil para la mayoría de usuarios
3. Piensa en la implementación

### Template de Feature Request
```markdown
**¿Tu feature request está relacionada con un problema?**
Descripción clara del problema.

**Describe la solución que te gustaría**
Descripción clara de lo que quieres que pase.

**Describe alternativas consideradas**
Otras soluciones o features consideradas.

**Contexto adicional**
Cualquier otro contexto sobre la feature request.
```

## 🏷️ CONVENCIONES DE COMMITS

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

- `feat:` Nueva funcionalidad
- `fix:` Corrección de bug
- `docs:` Cambios en documentación
- `style:` Cambios de formato (no afectan funcionalidad)
- `refactor:` Refactorización de código
- `test:` Añadir o modificar tests
- `chore:` Tareas de mantenimiento

### Ejemplos
```bash
git commit -m "feat: añadir soporte para CentOS 8"
git commit -m "fix: corregir instalación de PHP en Debian 11"
git commit -m "docs: actualizar README con nuevas instrucciones"
```

## 🔍 PROCESO DE REVISIÓN

1. **Revisión Automática**: GitHub Actions ejecuta tests
2. **Revisión Manual**: Mantenedores revisan el código
3. **Feedback**: Se proporcionan comentarios si es necesario
4. **Merge**: Una vez aprobado, se hace merge

## 📞 CONTACTO

- **Issues**: Para bugs y feature requests
- **Discussions**: Para preguntas generales
- **Email**: Para temas sensibles

## 📄 LICENCIA

Al contribuir, aceptas que tus contribuciones se licencien bajo la misma licencia MIT del proyecto.

---

¡Gracias por hacer este proyecto mejor! 🎉