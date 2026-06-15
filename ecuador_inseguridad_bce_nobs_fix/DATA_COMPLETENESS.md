# Cobertura de datos

La ventana econométrica se fija en enero de 2022 a marzo de 2026.

El archivo oficial del IMAEc incluido en este repositorio corresponde a marzo de 2026. Por esa razón, aunque el objetivo inicial era cubrir hasta mayo de 2026 por el último episodio de toque de queda, los modelos no se extienden más allá de marzo de 2026. La extensión a abril o mayo debe hacerse cuando el Banco Central del Ecuador publique esos índices.

La serie de homicidios se incluye como una serie mensual armonizada para ejecución econométrica. Sus restricciones de construcción se documentan en `data/sources/homicidios_series_constraints.csv`. Cuando se disponga del XLSX oficial descargado desde Datos Abiertos, puede reemplazarse la serie mensual sin cambiar la lógica del modelo.

El criterio adoptado es evitar imputar IMAEc no publicado por el BCE. La frontera del análisis la define la variable económica principal, no la disponibilidad de eventos de seguridad posteriores.
