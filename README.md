# Lapsus

Cronómetro de jornada laboral para iPhone (SwiftUI nativo) que, en cada pausa,
pregunta qué hiciste y con eso arma tus estadísticas de productividad.
Se desarrolla **sin Mac**, con la misma cadena que SoundFast: se compila en la
nube (GitHub Actions o Codemagic) y se instala desde Windows con Sideloadly y
un Apple ID gratuito.

## Estructura

| Ruta | Qué es |
|---|---|
| `Lapsus/App/` | Arranque, tema (paletas claro/oscuro) y vibraciones |
| `Lapsus/Model/` | Días, sesiones, pausas, categorías, guardado local, estadísticas y CSV |
| `Lapsus/Views/` | Timer, modal "¿Qué hacías?", cierre del día, Historial, Stats, Ajustes |
| `project.yml` | Definición del proyecto; XcodeGen genera el `.xcodeproj` al compilar |
| `scripts/build-ipa.sh` | Compila sin firmar y deja `build/Lapsus.ipa` |
| `.github/workflows/build-ios.yml` | Compilación en GitHub Actions (cada push a `main`, o manual) |
| `codemagic.yaml` | Compilación en Codemagic (manual desde su panel) |
| `diseno/` | Diseño de Claude Design y documento de planificación (solo referencia) |

## Obtener el .ipa

**GitHub Actions:** pestaña *Actions* → *Compilar iOS* → última ejecución →
*Artifacts* → `Lapsus-build-N`. Se descarga un `.zip`; adentro está `Lapsus.ipa`.

## Instalar en el iPhone

Igual que SoundFast: Sideloadly → arrastrar `Lapsus.ipa` → Apple ID → *Start*.
La firma gratuita vence a los 7 días; se reinstala el mismo `.ipa` y los datos se conservan.

Ojo: el Apple ID gratis permite **3 apps instaladas a la vez** con este método.

## Cómo funciona

- **Tocar la ilustración** inicia, pausa y reanuda. No hay botón de play.
- **Al reanudar** aparece "¿Qué hacías en esta pausa?": hay que marcar al menos una
  categoría (24, en 7 grupos) y opcionalmente una nota. No se puede saltar.
- **Finalizar día** (arriba a la derecha): "¿Trabajaste hoy?" → resumen → tareas realizadas.
- **Horas extra**: solo aparecen con el día cerrado; dorado, con su propio cierre.
- Si la jornada sigue abierta después de medianoche, se respeta hasta que la cierres.
- Todo se guarda en el iPhone (`Application Support/Lapsus/dias.json`). Sin cuenta ni servidor.

## Estado

Qué está integrado, qué falta y el historial de versiones: ver [ESTADO.md](ESTADO.md).
