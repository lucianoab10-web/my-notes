---
title: Política de privacidad — Sincronización de apuntes de Luciano
description: Uso de los datos de Google Drive en el sincronizador personal de apuntes de Luciano.
---

# Política de privacidad

**Aplicación:** Sincronización de apuntes de Luciano  
**Titular:** Luciano, responsable de la cuenta de Google que autoriza la conexión.  
**Última actualización:** 10 de noviembre de 2026.

## Finalidad

Esta aplicación se utiliza para la sincronización personal de apuntes y archivos seleccionados entre el equipo del titular y Google Drive, y para preparar determinadas notas y enlaces para sus sitios de apuntes en GitHub Pages.

## Datos a los que accede

La conexión utiliza el permiso de acceso a archivos de Google Drive que requiere su configuración de rclone. Este permiso permite un acceso amplio a los archivos de la cuenta. El flujo de sincronización configurado trabaja con las carpetas seleccionadas por el titular, incluida `compartidos-varios`.

Para realizar estas tareas se utilizan el contenido de los archivos y sus metadatos, como nombres, rutas, identificadores, tamaños y fechas de modificación.

## Uso de los datos

Los datos se utilizan para comparar copias, subir o actualizar archivos, localizar documentos, generar sus enlaces y mantener las carpetas sincronizadas. Según la configuración utilizada, la sincronización puede mover y eliminar archivos de la carpeta de destino.

Los procesos pueden generar registros locales con nombres de archivos, resultados de las operaciones y mensajes de error.

## Almacenamiento y publicación

Los archivos sincronizados se almacenan en Google Drive. Los apuntes originales y la configuración de rclone se conservan en el equipo del titular.

Las notas seleccionadas para publicación se copian a repositorios de GitHub y se muestran mediante GitHub Pages. Los enlaces a documentos de Drive pueden aparecer en esas notas. Los visitantes pueden acceder a los documentos cuando sus permisos de Drive lo permitan.

La carpeta `compartidos` se utiliza como selección de contenido para compartir. Los archivos personales ajenos a esa selección no se incluyen en este flujo. Las referencias identificadas expresamente como privadas se muestran sin enlace en el sitio público.

Las credenciales de autorización de rclone se almacenan localmente y no se incluyen en las notas publicadas ni en sus páginas.

## Conservación y control

El titular administra las copias, los permisos y la eliminación de archivos en su equipo, Google Drive y GitHub. GitHub puede conservar versiones anteriores en el historial de los repositorios.

El acceso de la aplicación puede retirarse desde las [conexiones de la cuenta de Google](https://myaccount.google.com/connections). Retirar el permiso impide nuevas operaciones autorizadas con esa conexión; no elimina las copias que ya existan en Drive o GitHub.

## Contacto

Para consultas sobre esta aplicación, utiliza el correo de asistencia indicado en su ficha y pantalla de autorización de Google.

[Volver a la página de la aplicación](https://lucianoab10-web.github.io/my-notes/sincronizador/).
