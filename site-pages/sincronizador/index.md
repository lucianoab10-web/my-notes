---
title: Sincronización de apuntes de Luciano
description: Herramienta personal para sincronizar apuntes y archivos seleccionados con Google Drive.
---

# Sincronización de apuntes de Luciano

Esta aplicación es una herramienta de uso personal de Luciano para mantener una copia de sus apuntes y archivos seleccionados en Google Drive y preparar determinados contenidos para sus sitios de apuntes en GitHub Pages.

La sincronización se ejecuta en su equipo mediante rclone y scripts de PowerShell. La autorización de Google corresponde a esta conexión personal; los visitantes de los sitios de apuntes no necesitan autorizar la aplicación.

## Funciones

- Sincronizar la carpeta local de Obsidian `compartidos` con la carpeta `compartidos-varios` de Google Drive.
- Consultar nombres, rutas, identificadores, tamaños y fechas de los archivos para mantener las copias y generar enlaces a documentos.
- Subir, actualizar, mover y eliminar archivos en Drive según la configuración de sincronización elegida por el titular.
- Preparar notas seleccionadas y enlaces a documentos para su publicación en GitHub Pages.

## Acceso a Google Drive

La conexión solicita el permiso de acceso a archivos de Google Drive utilizado por rclone. Este permiso es amplio; el flujo configurado trabaja con las carpetas seleccionadas por el titular.

La visibilidad de cada archivo depende de sus permisos de Drive. Las notas y los enlaces publicados en los sitios de GitHub Pages son accesibles para sus visitantes.

## Privacidad y contacto

Consulta la [política de privacidad](privacidad.md) para conocer cómo se accede, utiliza, almacena y comparte la información.

El correo de asistencia de esta aplicación se indica en su ficha y pantalla de autorización de Google.
