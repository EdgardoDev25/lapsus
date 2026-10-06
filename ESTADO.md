# Lapsus — Estado del proyecto

Qué quedó integrado en la app, qué no y qué se descartó.
Última versión: **0.2.0** · 2026-10-05 · iPhone 16 Pro Max.

**Leyenda**
- ✅ Integrado y confirmado por Edgar en el iPhone
- 🧪 Integrado, **sin compilar todavía o sin prueba** en el iPhone
- ⏳ Pendiente (se quiere hacer)
- 🚫 Descartado o fuera del alcance por ahora

---

## 1. Base y compilación

| Qué | Estado | Nota |
|---|---|---|
| App nativa SwiftUI (iOS 17+), XcodeGen | 🧪 | Misma cadena que SoundFast. El documento de planificación decía Flutter; se cambió a SwiftUI porque es lo que ya funciona sin Mac. |
| Compilación en GitHub Actions | ⏳ | Falta crear el repositorio en GitHub. |
| Ícono (blob con degradado Aurora) | 🧪 | Generado; se puede rediseñar. |
| Tipografía Mulish del diseño | ⏳ | Por ahora usa la del sistema (SF Pro). |

## 2. Timer (Fases 1 y 2 del plan)

| Qué | Estado | Nota |
|---|---|---|
| Ilustración central como único control (tocar = iniciar/pausar/reanudar) | 🧪 | Vibración distinta al iniciar y al pausar. |
| Tres estilos: blob orgánico, ondas, partículas | 🧪 | Cambian de color, energía y respiración según el estado, con transición suave. |
| Cronómetro del bloque actual + total del día | 🧪 | En pausa muestra cuánto llevas pausado. |
| Modal "¿Qué hacías?" obligatorio, multi-selección, nota opcional | 🧪 | 24 categorías en 7 grupos con color e ícono. |
| Buscador en el modal (sin importar tildes) | 🧪 | 0.2.0. Enter con un solo resultado lo marca; si no existe, ofrece crearla ahí mismo. |
| Pausas fijadas arriba del modal | 🧪 | 0.2.0. Mantener presionada una opción → Fijar arriba. También desde Ajustes. |
| Historial de hoy (línea de tiempo) | 🧪 | |
| Finalizar día: ¿Trabajaste hoy? → resumen → tareas | 🧪 | Si estabas en pausa, el día termina cuando empezó la pausa. |
| Reabrir jornada cerrada por error | 🧪 | El rato desde el cierre queda como pausa y se clasifica. |
| Horas extra (solo con el día cerrado), con su propio cierre y tareas | 🧪 | Acento dorado. Se pueden retomar. |
| Jornada que pasa la medianoche | 🧪 | Se respeta hasta que la cierres; luego abre el día nuevo. |
| Persistencia local (JSON) | 🧪 | Sobrevive a cerrar la app: los tiempos se calculan con horas de inicio, no con un contador. |

## 3. Historial

| Qué | Estado | Nota |
|---|---|---|
| Mapa de calor del mes (horas vs. meta) | 🧪 | Navegable por meses. |
| Días recientes: fila compacta o abierta con línea de tiempo, tareas y horas extra | 🧪 | |

## 4. Estadísticas (Fase 3, primera parte)

| Qué | Estado | Nota |
|---|---|---|
| Focus ratio de la semana + meta cumplida | 🧪 | La meta usa el horario que tenía cada día. |
| Racha de días cumpliendo la meta | 🧪 | Los días sin registro y los días libres según el horario no rompen la racha. |
| Barras de horas por día con "mejor" y "flojo" (+ horas extra en dorado) | 🧪 | |
| Insights automáticos por reglas | 🧪 | |
| Dona "¿Qué te roba el tiempo?" por grupo | 🧪 | |
| Semana actual vs. anterior | 🧪 | |
| Deep work (bloque más largo) y horas extra | 🧪 | |
| Top distracciones con tendencia | 🧪 | |
| Mapa de calor horario (¿cuándo te distraes?) | ⏳ | |
| Histograma de duración de pausas | ⏳ | |
| Tendencia de focus 4–8 semanas | ⏳ | |

## 5. Ajustes

| Qué | Estado | Nota |
|---|---|---|
| Horario de trabajo por día (entrada, salida, descanso; cada día distinto o libre) | 🧪 | 0.2.0. Reemplaza la "meta diaria" fija: la meta de cada día sale del horario. |
| Cambiar el horario no altera días anteriores | 🧪 | 0.2.0. Cada día guarda una copia de su horario al crearse; el cambio aplica desde hoy. |
| Categorías: crear, editar (nombre, grupo, tipo, ícono), ocultar, fijar | 🧪 | 0.2.0. Las usadas se ocultan en vez de borrarse para no perder el historial. |
| Avisos al inicio y al final del horario | 🧪 | 0.2.0. Notificación semanal por día activo. |
| Temas Aurora, Medianoche, Atardecer, Bosque, Minimal + color propio | 🧪 | |
| Claro / oscuro / auto | 🧪 | |
| Estilo de ilustración | 🧪 | Con vista previa animada. |
| Formato 24 h, vibración | 🧪 | |
| Recordatorio "¿Sigues en pausa?" | 🧪 | Notificación local, minutos configurables. |
| Exportar CSV | 🧪 | |
| Exportar PDF | ⏳ | |
| Borrar todos los datos | 🧪 | Con confirmación. |

## 6. Siguiente

| Qué | Estado | Nota |
|---|---|---|
| Onboarding (4 pasos, el último con el horario opcional) | 🧪 | 0.2.0. Hecho a partir del estilo de la app: el diseño `LapsusOnboarding` no venía en el archivo exportado. Se puede volver a ver desde Ajustes. |
| Diseño exacto del timer (`LapsusTimer`) | ⏳ | Tampoco venía; el timer se hizo a partir del documento y las pantallas de apoyo. |
| Recordatorio de cierre de jornada y resumen diario | ⏳ | |
| Live Activity / widget (reloj en pantalla bloqueada) | ⏳ | Necesita una extensión aparte. |

---

## Historial de versiones

- **0.2.0** (2026-10-05) — Horario por día (con copia por día para no alterar estadísticas pasadas),
  onboarding con horario opcional, categorías editables, buscador y fijadas en "¿Qué hacías?",
  avisos de inicio/fin de horario.
- **0.1.0** (2026-10-05) — Primera versión: timer con máquina de estados, modal de pausas,
  cierre del día, horas extra, historial, estadísticas, ajustes y CSV.
