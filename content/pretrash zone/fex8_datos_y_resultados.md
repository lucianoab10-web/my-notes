# Movimiento de un carrito con Tracker: datos y resultados

Fuente: `fex8.xlsx` (hoja «Hoja1», conjunto `masa_A`).
Figuras (misma carpeta que este archivo): `grafico_1_D_vs_t.png` y `grafico_2_x_vs_t.png`.

## 1. Contexto

- Se grabó un carrito con Tracker y se obtuvo su posición en función del tiempo (x e y).
- Método analítico (leyes de Newton, a partir de la masa y de la aceleración de gravedad): **a = 2,70 m/s²**.
- Método algebraico: se ajusta x(t) = x₀ + v₀·t + ½·a·t² a los datos de Tracker mediante una rectificación, resuelta con el método de los promedios y con mínimos cuadrados.
- Ambos métodos dan valores similares de aceleración (sección 7).
- Hay 43 datos (filas 3 a 45 del Excel), de t = 0 a 0,7 s, con un paso de 1/60 s (60 cuadros por segundo).
- Unidades: el Excel no las indica. Se asumen segundos y metros, coherentes con una aceleración cercana a 2,6 m/s².

## 2. Datos (columnas A y B, filas 3 a 45)

Grupo: 1 = filas 3–22 (p = 20 puntos), ref. = fila 23 (punto de referencia), 2 = filas 24–45 (22 puntos).

| Fila | Grupo |      t (s) |       x (m) |
| ---: | :---: | ---------: | ----------: |
|    3 |   1   |          0 | 0,005648104 |
|    4 |   1   | 0,01666667 | 0,006045364 |
|    5 |   1   | 0,03333333 | 0,007962411 |
|    6 |   1   |       0,05 |  0,00921696 |
|    7 |   1   | 0,06666667 |  0,01186491 |
|    8 |   1   | 0,08333333 |    0,014443 |
|    9 |   1   |        0,1 |  0,01798073 |
|   10 |   1   |  0,1166667 |  0,02233019 |
|   11 |   1   |  0,1333333 |   0,0274136 |
|   12 |   1   |       0,15 |  0,03329273 |
|   13 |   1   |  0,1666667 |  0,03928791 |
|   14 |   1   |  0,1833333 |  0,04685409 |
|   15 |   1   |        0,2 |  0,05438731 |
|   16 |   1   |  0,2166667 |  0,06208676 |
|   17 |   1   |  0,2333333 |  0,07127793 |
|   18 |   1   |       0,25 |  0,08060328 |
|   19 |   1   |  0,2666667 |  0,09113571 |
|   20 |   1   |  0,2833333 |   0,1023651 |
|   21 |   1   |        0,3 |   0,1139071 |
|   22 |   1   |  0,3166667 |   0,1264779 |
|   23 | ref.  |  0,3333333 |   0,1388149 |
|   24 |   2   |       0,35 |   0,1523693 |
|   25 |   2   |  0,3666667 |   0,1666318 |
|   26 |   2   |  0,3833333 |   0,1821586 |
|   27 |   2   |        0,4 |   0,1985495 |
|   28 |   2   |  0,4166667 |   0,2153255 |
|   29 |   2   |  0,4333333 |   0,2322492 |
|   30 |   2   |       0,45 |   0,2513059 |
|   31 |   2   |  0,4666667 |    0,270511 |
|   32 |   2   |  0,4833333 |   0,2900032 |
|   33 |   2   |        0,5 |   0,3098817 |
|   34 |   2   |  0,5166667 |   0,3314154 |
|   35 |   2   |  0,5333333 |   0,3536947 |
|   36 |   2   |       0,55 |   0,3764263 |
|   37 |   2   |  0,5666667 |   0,4007046 |
|   38 |   2   |  0,5833333 |   0,4256522 |
|   39 |   2   |        0,6 |    0,451009 |
|   40 |   2   |  0,6166667 |   0,4780884 |
|   41 |   2   |  0,6333333 |   0,5060558 |
|   42 |   2   |       0,65 |   0,5359165 |
|   43 |   2   |  0,6666667 |   0,5663886 |
|   44 |   2   |  0,6833333 |   0,5973732 |
|   45 |   2   |        0,7 |    0,630273 |

Notas:

- La celda A23 está vacía en el Excel. El tiempo de esa fila es t₁ = 0,3333333 s (celda G23) y, junto con x₁ = 0,1388149 m (celda B23), forma el punto de referencia (t₁, x₁), el dato central de los 43.
- Los valores están tal como se guardan en las celdas; el Excel los muestra con 6 decimales por el formato de celda.
- La columna C (y) no se incluye aquí. Sus valores van de 0,003100053 m a 0,00828801 m.

## 3. Gráficos

![Gráfico 1: D en función de t](pretrash%20zone/grafico_1_D_vs_t.png)

**Figura 1.** D(t) = (x(t) − x₁)/(t − t₁) en función de t (Gráfico 1 del Excel). Son 42 puntos: se excluye el punto de referencia, donde D no está definida. En el Excel este gráfico no tiene valores de X asignados (Excel usa el número de punto); aquí se grafica contra t, como dice su título.

![Gráfico 2: x en función de t](pretrash%20zone/grafico_2_x_vs_t.png)

**Figura 2.** Posición x en función del tiempo t, 43 puntos (Gráficos 2 y 3 del Excel, que son idénticos).

## 4. Método de rectificación

Se parte de x(t) = a·t² + b·t + c y de un punto de referencia (t₁, x₁) = (0,3333333 s; 0,1388149 m). Para los demás puntos:

```
D = (x − x₁)/(t − t₁) = a·t + (a·t₁ + b)        →   D = m·t + n
m = a            n = a·t₁ + b
b = n − m·t₁     c = x₁ − a·t₁² − b·t₁
x₀ = c           v₀ = b           a_exp = 2m
```

Aquí a es el coeficiente de t² (a = ½·a_exp). Unidades: m en m/s², n y b en m/s, c en m. Se rectifican los 42 puntos con D definida: grupo 1 (p = 20, filas 3–22) y grupo 2 (22 puntos, filas 24–45).

## 5. Método de los promedios

Sumas de D y de t por grupo (celdas F5:I5). El encabezado «∑x» del Excel corresponde a ΣD.

| Suma | Grupo 1 (filas 3–22) | Grupo 2 (filas 24–45) |
| ---- | -------------------: | --------------------: |
| Σt   |            3,1666667 |             11,550000 |
| ΣD   |        11,6806303906 |            23,5202610 |

Sistema de ecuaciones (D = m·t + n sumado en cada grupo):

```
11,6806303906 = 3,1666667·m + 20·n
23,5202610    = 11,550000·m + 22·n
```

Solución general y resultado:

```
m = (ΣD₁·22 − ΣD₂·20) / (Σt₁·22 − Σt₂·20)
n = (Σt₁·ΣD₂ − Σt₂·ΣD₁) / (Σt₁·22 − Σt₂·20)

m = 1,3229216 m/s²        n = 0,3745689 m/s        (celdas F6 y G6)
```

Valores con cifras significativas según las reglas de multiplicación/división (menor número de cs) y suma/resta (menor número de decimales).

## 6. Método de mínimos cuadrados (tal como está en el Excel)

| Suma | Valor | Celda |
|---|---:|:---:|
| Σt | 14,7166667 | H9 |
| ΣD | 35,2008913473 | F10 |
| Σ(t·D) | 14,7699679647 | F11 |
| Σt² | 7,1069444309 | F12 |
| N usado en las fórmulas | 43 | F8, G8 |

```
m = (N·Σ(tD) − Σt·ΣD) / (N·Σt² − (Σt)²)
n = (Σt²·ΣD − Σt·Σ(tD)) / (N·Σt² − (Σt)²)

m = 1,315109 m/s²        n = 0,3685318 m/s        (celdas F8 y G8)
```

Ver la observación 1 de la sección 8 sobre N y Σt².

## 7. Resultados (rango L3:T5 del Excel)

Valores para el informe, con el número de cifras significativas entre paréntesis.

| Método            |         m = a |   b = n − m·t₁ | c = x₁ − a·t₁² − b·t₁ | x₀ = c (m) | v₀ = b (m/s) | a_exp = 2m (m/s²) |
| ----------------- | ------------: | -------------: | --------------------: | ---------: | -----------: | ----------------: |
| Promedios         | 1,3229216 (8) |  −0,066405 (5) |          0,013959 (5) |   0,013959 |    −0,066405 |     2,6458432 (8) |
| Mínimos cuadrados |  1,315109 (7) | −0,0698379 (6) |          0,015971 (5) |   0,015971 |   −0,0698379 |      2,630218 (7) |

Modelos x(t) = x₀ + v₀·t + ½·a_exp·t², con t en s y x en m:

```
Promedios:          x(t) = 0,013959 − 0,066405·t + 1,3229216·t²     (a_exp = 2,6458432 m/s²)
Mínimos cuadrados:  x(t) = 0,015971 − 0,0698379·t + 1,315109·t²     (a_exp = 2,630218 m/s²)
```

El coeficiente de t² es ½·a_exp = m.

Valores completos de las celdas (sin redondear):

| Celda | Magnitud | Valor |
|---|---|---:|
| N4 | b, promedios | −0,0664049225693 |
| O4 | c, promedios | 0,0139586124856 |
| N5 | b, mínimos cuadrados | −0,0698378567958 |
| O5 | c, mínimos cuadrados | 0,0159709902731 |
| F8 | m, mínimos cuadrados | 1,31510931126 |
| G8 | n, mínimos cuadrados | 0,368531766034 |

### Comparación con el método analítico (a = 2,70 m/s²)

| Método            | a_exp (m/s²) | Diferencia con 2,70 (m/s²) | Error relativo |
| ----------------- | -----------: | -------------------------: | -------------: |
| Promedios         |    2,6458432 |                       0,05 |            2 % |
| Mínimos cuadrados |     2,630218 |                       0,07 |            3 % |

La diferencia sigue la regla de la suma/resta (2 decimales, por el 2,70). El error relativo es diferencia / 2,70 × 100, con 1 cs.

## 8. Observaciones para revisar antes de redactar

1. **Mínimos cuadrados (F8, G8).** Las fórmulas usan N = 43 y Σt² (F12 = SUM(J3:J45)) incluye J23 = t₁². En cambio, Σt (H9) y las sumas de D no incluyen la fila 23, porque A23 y D23 están vacías. Con 42 puntos y sumas coherentes (N = 42 y sin J23) resulta m = 1,324348, n = 0,374069 y a_exp = 2,648695 m/s², sin redondear por cifras significativas. Los valores del Excel son m = 1,315109, n = 0,3685318 y a_exp = 2,630218 m/s².
2. **Texto de T4 y T5.** El texto escrito en esas celdas usa «(1/2)·m·t²». El término correcto es m·t² (porque a_exp = 2m y el término es ½·a_exp·t²), y en T5 falta «·t» en el término lineal. Comprobación en t = 0,7 s: el dato es x = 0,630273 m; el modelo de promedios da 0,6157 m, el de mínimos cuadrados 0,6115 m, y con ½·m en lugar de m el modelo de promedios daría 0,2916 m. En este archivo se usan los modelos corregidos.
