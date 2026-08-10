[[FEXINF1]]
## Análisis del problema: ¿Cuántos porotos caben en un saco de porotos?

Antes de los postulados, nota que tus 6 ya son sólidos — pero hay un pequeño problema estructural: mezclan **dos estrategias distintas** sin conectarlas bien. Te explico y luego propongo los 5 que faltan.

---

### El problema tiene dos rutas posibles

**Ruta A — Masa:** `N = masa_saco / masa_poroto`

**Ruta B — Volumen:** `N = volumen_saco × fracción_llenado / volumen_poroto`

Tus postulados 1–2 son Ruta A. Los postulados 3–7 apuntan a Ruta B (usando las papas como _analogía de escala_ para estimar el volumen del saco, lo cual es inteligente). El problema es que los postulados aún no conectan las dos rutas ni permiten verificar la consistencia entre ambas. Eso es justamente lo que deben hacer los 5 que agregarás.

---

### Los 5 postulados que te propongo agregar

**Postulado 8 — ¿Cuánto pesa un poroto individualmente en volumen?** Es decir, ¿cuál es el volumen de un poroto individual? Esto cierra la Ruta B: ya tienes el volumen del saco (postulado 6) y el espacio vacío (postulado 7), pero aún necesitas el volumen unitario del poroto para dividir.

**Postulado 9 — ¿Cuántas papas caben en un kilo de papas?** Esto ya lo tienes como postulado 3, pero necesitas usarlo para estimar el _volumen de una papa individual_, y de ahí por analogía geométrica aproximar el volumen de un poroto. El puente lógico entre la papa y el poroto debe explicitarse como postulado.

**Postulado 10 — ¿Qué fracción del volumen del saco es espacio vacío?** El postulado 7 lo pregunta cualitativamente, pero este lo convierte en número: para esferas empacadas al azar, el vacío ronda el 36–40%. Para porotos (que son más irregulares y se acomodan mejor), puedes estimar entre 30–35%. Este número entra directamente en la fórmula de Ruta B.

**Postulado 11 — ¿Es consistente la Ruta A con la Ruta B?** Este es el postulado de _verificación cruzada_, el más valioso pedagógicamente. Una vez que obtienes N por volumen y N por masa, ¿coinciden en el mismo orden de magnitud? Si no coinciden, hay un error de estimación en algún paso anterior. Fermi mismo usaba este tipo de chequeo.

**Postulado 12 (o el que cierra) — ¿Cuál es la densidad del poroto individual?** Para conectar masa y volumen del poroto en un solo objeto, necesitas saber si el poroto flota o se hunde en agua — lo que te da su densidad aproximada. Un poroto seco se hunde, así que su densidad es mayor que 1 g/cm³, probablemente entre 1,2 y 1,4 g/cm³. Esto permite pasar de masa a volumen unitario sin medirlo directamente.

---

### Estructura final sugerida

```
Ruta A (masa):        postulados 1, 2, 12
Ruta B (volumen):     postulados 3, 4, 5, 6, 7, 8, 9, 10
Verificación:         postulado 11
```

Lo más elegante del problema es que tienes **dos caminos independientes** hacia la misma respuesta, y la confianza en tu estimación aumenta si ambos convergen en el mismo orden de magnitud.