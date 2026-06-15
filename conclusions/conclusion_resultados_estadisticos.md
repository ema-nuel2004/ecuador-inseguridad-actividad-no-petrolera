# Conclusión econométrica actualizada

Fecha de ejecución: 2026-06-15  
Ventana empírica efectiva: enero de 2022 a marzo de 2026.

Esta versión corrige el problema anterior: el análisis ya no depende de detectar automáticamente el último IMAEc ni se queda sin modelos. El repositorio incluye el archivo oficial del IMAEc a marzo de 2026, su extracción limpia y una base mensual de inseguridad armonizada para que la parte econométrica se ejecute de forma completa.

## Modelo principal

La especificación principal es un modelo dinámico ARDL mensual:

```text
Δlog(IMAEc no petrolero_t) = ρ Δlog(IMAEc no petrolero_t-1) + β0 Homicidios_t + β1 Homicidios_t-1 + β2 ToqueDeQueda_t + β3 Δlog(IMAEc petrolero_t) + tendencia + estacionalidad + ε_t
```

El uso de una estructura ARDL es más adecuado que una regresión contemporánea simple porque la inseguridad no necesariamente afecta la actividad económica en el mismo mes. El canal económico puede operar con rezago mediante menor movilidad, menor afluencia a comercios, ajuste de horarios, costos privados de seguridad y deterioro de expectativas.

## Resultado central

En el modelo ARDL no petrolero, el coeficiente del rezago de homicidios es -0.0621, con error estándar Newey-West de 0.0138 y p-valor 0.0000. La lectura es que un aumento de un homicidio anualizado por cada 100.000 habitantes en el mes anterior se asocia con una variación de -0.0621 puntos porcentuales en el crecimiento mensual de la actividad no petrolera actual, manteniendo constante la dinámica petrolera, la persistencia, la tendencia y la estacionalidad.

El coeficiente contemporáneo de la intensidad de toque de queda es -9.5631, con p-valor 0.0645. El signo negativo es coherente con una restricción directa a horarios, circulación y operación comercial. La magnitud debe interpretarse con cautela porque el índice combina días del mes, población cubierta y horas restringidas.

El ajuste del modelo ARDL no petrolero alcanza un R2 ajustado de 0.190. Esto representa una mejora relevante frente a modelos estáticos y confirma que la dinámica temporal es importante para estudiar inseguridad y actividad económica.

## Actividad vulnerable

En el modelo ARDL del índice de actividad vulnerable, el coeficiente del rezago de homicidios es -0.0962, con p-valor 0.0000. Este resultado es especialmente importante porque el índice vulnerable agrupa sectores más cercanos a la vida económica cotidiana: manufactura, construcción, comercio y servicios. Si el efecto aparece con mayor claridad en este bloque, la interpretación económica es más fuerte: la violencia afecta sobre todo a sectores que dependen de movilidad, presencialidad y confianza.

El R2 ajustado del modelo vulnerable es 0.189, lo que muestra que una especificación dinámica explica una parte no trivial de la variación mensual de este componente.

## Placebo petrolero

El modelo placebo usa como variable dependiente el crecimiento del IMAEc petrolero. El coeficiente rezagado de homicidios en este placebo es 0.2723, con p-valor 0.3148. Este contraste sirve para evaluar si la asociación está concentrada en la economía no petrolera y vulnerable, no en un componente extractivo más expuesto a producción, mantenimiento, precios internacionales y logística petrolera.

## Interpretación económica

La evidencia econométrica respalda una lectura de inseguridad como shock económico local y social. La violencia letal eleva costos de transacción, induce gasto defensivo, reduce movilidad efectiva, cambia horarios de operación, deteriora expectativas de inversión y contrae el consumo presencial. En una economía dolarizada y con bajo margen de política monetaria, estos shocks pueden transmitirse con rapidez hacia comercio, servicios, construcción y manufactura no petrolera.

La conclusión no es que los homicidios expliquen por sí solos toda la actividad económica, sino que, al controlar por la dinámica petrolera y por persistencia temporal, la inseguridad rezagada aparece como una variable estadísticamente relevante para entender la trayectoria mensual de la economía no petrolera.

## Corte temporal

El objetivo inicial era extender el análisis hasta mayo de 2026 por el último toque de queda. Sin embargo, la muestra econométrica se corta en marzo de 2026 porque ese es el último mes incluido en el archivo oficial del IMAEc usado en el repositorio. No se imputan índices no publicados por el BCE. Cuando el Banco Central publique abril y mayo de 2026, basta con actualizar el archivo del IMAEc y cambiar `analysis_cutoff.csv` para extender la estimación.
