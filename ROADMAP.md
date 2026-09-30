# PetBond — Roadmap

> Nombre provisional en el repo: "Pets" · Nombre real del producto: **PetBond**
> Última actualización: 2026-09-29 (Fase 1 del análisis de juego: caricias)
> Rama activa: `main`

---

## Estado actual

El juego está **jugable, con personalidad, rediseñado y corriendo en un teléfono real**.
El loop de cuidado funciona de punta a punta, con persistencia, personalidad
emergente y una capa visual completa en estilo **Fieltro** (fieltro y costuras) —
todo **procedural, sin un solo asset de arte raster**. Ya hay build de Android
probada en dispositivo (Xiaomi, Android 16, Vulkan).

**Implementado y funcionando:**
- **Loop core** — 4 stats (hambre · felicidad · energía · afecto) con decaimiento en
  tiempo real, "no muere" (triste en vez de game over), persistencia con autosave.
  Sin barra fija: un costurero (abajo a la derecha) abre un abanico de acciones
  (Comida, Juguetes), y el plato y la canasta de juguetes de la habitación abren su
  bandeja al tocarlos.
- **Mochi decide (Fase 2, en curso)** — se duerme sola cuando está cansada (antes de
  noche) y despierta descansada; si la despiertas se enoja un rato. Al estar ausente
  las stats bajan hasta un piso "tranquila" (45) y solo bajan más tras días de
  descuido. Jugar = una varita con pluma que sostienes del mango: Mochi la acecha, se
  agacha y salta cuando la dejas quieta (`scenes/pet/PetPlay.gd`,
  `scenes/play/FeatherWand.gd`). En Modo de prueba la siesta dura ~30 s.
  Alimentar = la barra muestra 4 comidas de fieltro (atún, pollo, croquetas, zanahoria)
  que arrastras al plato; Mochi come cuando quiere. Cada gata ama una comida, rechaza
  otra («¡Puaj!») y le gustan las demás; los gustos se descubren y quedan marcados
  (`resources/Tastes.gd`, `scenes/play/FoodBowl.gd`, `theme/felt/FeltFood.gd`).
  Lenguaje corporal: con hambre le da zarpazos al plato y maúlla; aburrida se va
  trotando y vuelve con la varita en la boca, la deja en el piso y la levantas
  tocándola; con ganas de mimos se restriega en el aire, y se restriega contra tu dedo
  si lo dejas quieto en su cabeza (`scenes/pet/PetGestures.gd`). Dormida se acuesta.
  Su día: nace con un temperamento (tranquila↔inquieta, independiente↔pegote,
  `resources/Temperament.gd`) y sigue una rutina con el reloj real (`systems/Routine.gd`):
  desayuno temprano, ratos de locura a media mañana, siesta de tarde, más mimosa al
  atardecer. En su tiempo libre se acicala, se estira con un bostezo o corre de un lado
  al otro. Los rasgos (glotona…) son sus costumbres y también empujan lo que hace.
- **Mochi no habla** — lo que quiere es un dibujo en su burbuja, lo que siente es un
  símbolo que salta sobre su cabeza y los gestos se enseñan con una mano fantasma
  (`theme/felt/FeltPicto.gd`, `scenes/effects/ReactionPop.gd`, `scenes/hud/GhostHand.gd`).
  Diseño en el canvas, fila «Sin palabras · y el costurero».
- **Caricias táctiles (Fase 1 del rediseño de juego)** — el afecto se gana acariciando
  a Mochi, no con un botón: zonas (mejillas, cabeza, lomo a favor del pelo), cosas que
  le molestan (a contrapelo, brusco, panza trampa, cola), ronroneo con sonido y
  vibración por el canal multimedia, y ojos/cabeza que siguen tu dedo
  (`scenes/pet/PetTouch.gd`, `systems/Haptics.gd`). Ajuste "Vibración" en Ajustes.
- **HUD despejado** — las barras se abren desde una pestaña de íconos (con alerta si
  algo está crítico) y la stat que sube asoma sola un momento.
- **Mochi (la mascota)** — gata naranja atigrada con collar y cascabel, armada como
  **rig de recorte**: 22 piezas SVG (`assets/mochi/`) colgadas de pivotes
  (`scenes/pet/MochiRig.gd`) con acabado de fieltro por shader. Caras por ánimo
  (feliz · contenta · dormida · triste), idle (respiración, balanceo, cola, cabeza,
  parpadeo, tic de oreja) y sombra pegada al piso.
- **Personalidad emergente (v0.2, primera parte)** — rasgos que surgen del historial
  de cuidado (glotona · juguetona · dormilona · mimosa) y modifican decay, ganancias,
  tinte del pelaje y movimiento. Etiqueta en el HUD + aviso al descubrirla.
- **Feel / juice** — textos flotantes y partículas como recortes de fieltro, haptics,
  SFX procedurales (`AudioManager`).
- **Progresión de vínculo** — XP + niveles, barra de progreso y aviso al subir de nivel.
- **Logros** — 5 hitos (primer cuidado, vínculo 3/5, cuidador 50/200) con aviso.
- **Pensamientos** — burbuja de fieltro con el dibujo de lo que necesita o de lo que le gusta.
- **Ciclo día/noche** — tinte multiply sobre la habitación y Mochi; el bastidor
  bordado cambia de sol a luna.
- **Onboarding** (nombre) y **Ajustes** (idioma ES/EN, notificaciones, sonido,
  volumen, modo de prueba, borrar partida con confirmación).
- **Rediseño "Fieltro" (v2)** — diseñado en un canvas de Claude Design
  (https://claude.ai/artifact/SrFL1PQzgsz7YEqbgoYjjs) y llevado a Godot como tema
  global editable (`theme/felt_theme.tres`), componentes `@tool` (`theme/felt/`) y
  pantallas `.tscn`. Fuente Mali (OFL).
- **Android (Fase 4)** — export headless, instalación por adb inalámbrico, verificado
  en dispositivo real.
- **Tests** — `tests/TestRunner.tscn` (PetStats, migraciones de save, logros,
  personalidad, caricias, caza, gustos, lenguaje corporal, rutina, temperamento): 89/89.
- **i18n** — `es.po` + `en.po`, español neutro latinoamericano.

**Stats definitivas:** hambre · felicidad · energía · afecto
(`hunger` · `happiness` · `energy` · `affection` en código).

> Nota: las convenciones técnicas, gotchas y cómo correr/probar viven en `CLAUDE.md`
> (local, gitignored).

---

## Decisiones de diseño confirmadas

- La mascota **no muere** — si los stats llegan a 0 se pone triste/apagada, pero no
  hay game over. Reduce fricción, mejora retención.
- **Fase 1 es single player**, sin backend. Lo social es v2.0.
- Modelo de negocio: **cosmética in-app** (skins, accesorios, decoración) + expansion
  packs de especies. Sin suscripción ni pay-to-win.
- **Restricción de producción**: dev solo, sin artista. Todo se hace procedural o
  vectorial en código. Mochi es un rig de piezas SVG, así que las skins, los
  accesorios y los spritesheets salen del mismo rig (recolorear piezas, sumar
  piezas, o renderizar fotogramas desde Godot).
- **Estilo visual: Fieltro** — elegido entre tres direcciones (Pegatina, Fieltro,
  Lámpara) y validado primero con una prueba en Godot.

---

## Lo que sigue — re-priorizado

El loop core (v0.1), la personalidad (v0.2, primera parte), el rediseño y la build de
Android están **hechos**. Desde el 2026-09-29 el orden lo marca el análisis de juego
(documento "PetBond — Análisis y ideas de juego", con tablero de ideas): pasar de
mantener barras a **una gata con vida propia**, pensada para criarse de a dos.

1. **✋ Fase 1 · Tocar** ✅ — caricias por zonas, ronroneo con vibración, mirada.
2. **🐾 Fase 2 · Mochi decide** 🟡 — hecho: barras a demanda, dormir como consecuencia
   (sin botón Dormir), piso en vez de cero al estar ausente, jugar con la varita, comer
   desde el plato con gustos por gata, lenguaje corporal (pide comida, trae la varita,
   pide mimos, se restriega contra el dedo), sin palabras (pictogramas y mano
   fantasma), costurero en vez de barra, se acuesta a dormir, temperamento y rutina con
   el reloj real. Falta: zona de caricias favorita, Libreta de Mochi, notificaciones
   narradas, parpadeo lento.
3. **🎁 Fase 3 · Razones para volver** — "mientras no estabas", regalos, visitas en la
   ventana, sueños, álbum de fotos.
4. **🏠 Fase 4 · La casa** — skins y accesorios (rig por piezas), muro de logros de
   fieltro, habitación panorámica, botones de costura como moneda.
5. **💞 Fase 5 · De a dos** — backend (Supabase; stub en `SaveSystem`), rastros del
   otro, Mochi mensajera, momento juntos. Se apoya en un registro de eventos con autor.

Transversal: notificaciones en device, música ambient, más poses del rig (animación
estilo stop-motion a 12 fps).

---

## Milestones

### v0.1 — Prototipo jugable ✅ HECHO
Loop de cuidado validado: barras decaen en tiempo real, cada acción sube su stat,
persistencia OK, estados sad/critical, "no muere".

### v0.2 — IA de personalidad ✅ HECHO (primera parte)
> Objetivo: que la mascota se sienta única según cómo la criaste.
- [x] Diseñar el árbol de rasgos (glotona · juguetona · dormilona · mimosa + equilibrada)
- [x] `Personality` (autoload) — rasgos que emergen del historial de acciones (EWMA,
      dominancia con histéresis)
- [x] Los rasgos modifican decay, ganancias, tinte y movimiento
- [x] Guardar rasgos en el save (bloque `"personality"`, esquema v4 + migración)
- [ ] Siguiente parte: reacciones y animaciones propias de cada rasgo

### v0.3 — MVP completo 🟡 CASI
- [x] Onboarding / nombre
- [x] Ajustes (idioma, notif, sonido, volumen, etc.)
- [x] Pulido visual / tema de UI / habitación (rediseño Fieltro)
- [ ] Customización: 2–3 skins seleccionables (procedurales, sin tienda aún)
- [ ] Notificaciones locales en dispositivo físico (ver Fase 5)

### v1.0 — Soft launch
- [ ] Sistema de evolución: la mascota cambia de aspecto según rasgos acumulados
- [ ] Tienda in-app (cosmética): skins, accesorios, decoración
- [ ] Eventos de temporada (Navidad, Halloween…)
- [ ] Música ambient cozy (los SFX ya están)
- [ ] Submit a Play Store + App Store

### v2.0 — Fase social
- [ ] Backend (Supabase — stub listo en `SaveSystem.gd`)
- [ ] Mascota compartida entre dos usuarios (amigos/parejas a distancia)
- [ ] Sincronización asíncrona + notificaciones cruzadas

---

## Fase 4 — Primera build en dispositivo físico

### Android ✅ HECHO
- [x] Android Studio para SDK + JDK (JBR) + `cmdline-tools`
- [x] Keystore de debug (local, gitignored)
- [x] Preset `Android` (export estándar, `com.cvalera.petbond`, arm64-v8a + x86_64)
- [x] Export headless, instalación por adb inalámbrico, verificado en Xiaomi
      (orientación, toque, rendimiento Vulkan)

### iOS (requiere Mac + Apple Developer $99/año)
- [ ] `Export → iOS` → proyecto `.xcodeproj`, firmar en Xcode, instalar en device
- [ ] Verificar que el permiso de notificaciones aparece bien

---

## Fase 5 — Notificaciones locales
> Ya hay build de Android para probarlas (en el editor no funcionan).

- [ ] Plugin de notificaciones Android + iOS
- [ ] Completar los `TODO` en `autoloads/NotificationManager.gd` con las llamadas del plugin
- [ ] Probar en device físico
- [ ] Respetar el toggle de opt-out (ya guardado en settings)

---

## Diseño pendiente (decisiones manuales, no de código)

- [x] Árbol de rasgos de personalidad (v0.2)
- [x] Dirección visual (Fieltro, en el canvas de Claude Design)
- [ ] Árbol de evolución: qué formas toma la mascota y bajo qué condiciones
- [ ] Catálogo de skins procedurales (paletas/patrones/accesorios) y precios

---

## Referencia rápida de arquitectura

| Si necesitas...                        | Ve a...                             |
|----------------------------------------|-------------------------------------|
| Cambiar tasas de decaimiento           | `autoloads/GameConfig.gd`           |
| Ajustar la personalidad                | `autoloads/Personality.gd` (`_TABLE`) |
| Añadir una nueva pantalla              | escena `.tscn` + `scenes/main/Main.gd` → `SCREENS` |
| Añadir una señal global nueva          | `autoloads/EventBus.gd`             |
| Cambiar cómo se guarda / migraciones   | `systems/save/LocalSaveProvider.gd` + `SaveSystem.gd` |
| Añadir una interacción nueva           | `scenes/pet/Pet.gd` + `scenes/hud/HUD.tscn` / `HUD.gd` |
| Zonas y gestos de caricia              | `scenes/pet/PetTouch.gd` (+ tuning en `GameConfig`) |
| Vibración                              | `systems/Haptics.gd` (no `Input.vibrate_handheld`) |
| Sueño (cuándo se duerme/despierta)     | `scenes/pet/Pet.gd` (sección Sleep) + `GameConfig` |
| Juego con la varita                    | `scenes/pet/PetPlay.gd` (caza) · `scenes/play/FeatherWand.gd` (varita) |
| Piso de stats al estar ausente         | `resources/PetStats.gd` (`offline_floor`) + `GameConfig` |
| Comida, plato y gustos                 | `resources/Tastes.gd` · `scenes/play/FoodBowl.gd` · `Pet.gd` (sección Food) |
| Tocar colores                          | `theme/Palette.gd`                  |
| Tocar paneles, botones, barras, fuentes | `theme/felt_theme.tres` (editor de temas) · `theme/felt/` |
| Tocar a Mochi (forma, caras, pivotes)  | `assets/mochi/*.svg` · `scenes/pet/MochiRig.gd` |
| Añadir un ícono                        | `assets/icons/*.svg` (+ `.import` con `importer="keep"`) |
| Añadir una string de UI                | `i18n/en.po` + `i18n/es.po`         |
| Activar save en la nube (v2)           | `GameConfig.FEATURE_CLOUD_SAVE = true` + implementar `SupabaseSaveProvider` |
| Convenciones, gotchas, cómo correr     | `CLAUDE.md` (local)                 |
