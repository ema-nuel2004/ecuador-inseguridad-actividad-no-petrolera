# Inseguridad, toques de queda y actividad económica no petrolera en Ecuador

Este repositorio estima la relación entre inseguridad y actividad económica no petrolera en Ecuador usando datos mensuales entre enero de 2022 y marzo de 2026.

La variable económica principal es el IMAEc no petrolero del Banco Central del Ecuador. También se construye un índice de actividad vulnerable a inseguridad a partir de manufactura, construcción, comercio y servicios. El objetivo es medir la parte de la economía más cercana a empresas, consumidores, movilidad cotidiana y actividad presencial, evitando que el petróleo domine la interpretación.

## Pregunta de investigación

¿El aumento de la inseguridad y las restricciones de movilidad se asocian con una desaceleración de la actividad económica no petrolera en Ecuador?

## Hipótesis

H1. Un aumento de homicidios se asocia con menor crecimiento mensual de la actividad no petrolera.

H2. El efecto debe ser más visible en sectores vulnerables a la inseguridad: comercio, servicios, construcción y manufactura.

H3. Los toques de queda afectan negativamente la actividad económica al reducir horarios efectivos de operación, movilidad y demanda presencial.

H4. El efecto debe ser más débil en el IMAEc petrolero, usado como placebo, porque este responde más a factores extractivos, productivos y externos que a la movilidad social cotidiana.

## Archivos esenciales

Los archivos necesarios ya están incluidos en `data/essential/`:

- `bce_imaec_202603.xlsx`: archivo oficial del IMAEc a marzo de 2026.
- `bce_imaec_202603_extracted.csv`: extracción ordenada del archivo oficial del BCE.
- `homicidios_mensual_2022_2026.csv`: serie mensual armonizada de homicidios para el análisis.
- `curfews_ecuador_2022_2026.csv`: base de toques de queda y restricciones relevantes.
- `analysis_cutoff.csv`: fecha de corte del análisis, fijada en marzo de 2026.

## Metodología

Se estima una familia de modelos OLS sobre crecimiento mensual logarítmico:

```text
Δlog(IMAEc no petrolero_t) = β1 Homicidios_t + β2 ToqueDeQueda_t + β3 Δlog(IMAEc petrolero_t) + controles estacionales + tendencia + ε_t
```

También se estima:

- un modelo para actividad vulnerable;
- un modelo con rezagos distribuidos de homicidios y toques de queda;
- un placebo usando el IMAEc petrolero como variable dependiente;
- ventanas descriptivas tipo event study alrededor de toques de queda.

Los errores estándar se calculan con Newey-West para mejorar la inferencia ante autocorrelación y heterocedasticidad en datos mensuales.

## Conclusión del modelo

El panel efectivo contiene 51 observaciones mensuales entre enero de 2022 y marzo de 2026. La fecha de corte se fija en marzo de 2026 porque el archivo oficial del IMAEc usado en esta versión llega hasta ese mes. El proyecto inicialmente buscaba llegar hasta mayo de 2026 por el último toque de queda, pero esa extensión debe añadirse cuando el BCE publique los índices de abril y mayo.

En el modelo base, el coeficiente de homicidios anualizados por cada 100.000 habitantes sobre el crecimiento mensual no petrolero es -0.0081, con p-valor 0.7047. La intensidad de toque de queda tiene un coeficiente de -9.8014, con p-valor 0.1485. En el modelo de actividad vulnerable, el coeficiente de homicidios es -0.0208, con p-valor 0.4772. El placebo petrolero permite contrastar si la relación se concentra en la economía no petrolera y socialmente expuesta.

La interpretación económica es que la inseguridad puede operar como un shock de demanda y de oferta: reduce movilidad, limita horarios, eleva costos de protección, deteriora expectativas y afecta más a sectores que dependen del contacto presencial. El petróleo se controla por separado porque su dinámica puede ocultar este canal social.

## Cómo ejecutar

En R:

```r
source("seguridad_economia_ecuador.R")
```

El script lee los archivos locales, reconstruye el panel, estima los modelos y genera tablas, gráficos y conclusiones en `outputs/` y `conclusions/`.

## Resultados generados

- `outputs/tables/model_coefficients_newey_west.csv`
- `outputs/tables/diagnosticos_econometricos.csv`
- `outputs/tables/efectos_acumulados_rezagos.csv`
- `outputs/figures/actividad_no_petrolera_vulnerable.png`
- `outputs/figures/homicidios_mensuales.png`
- `outputs/figures/coeficientes_principales.png`
- `conclusions/conclusion_econometrica_actualizada.md`
