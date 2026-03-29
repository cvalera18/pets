# PetBond — Roadmap

> Nombre provisional en el repo: "Pets" · Nombre real del producto: **PetBond**
> Última actualización: 2026-03-29
> Rama activa: `feature/phase1`

---

## Estado actual

La arquitectura base está generada y el proyecto arranca sin errores.

**Lo que existe y funciona:**
- `autoloads/` — EventBus, GameConfig, SaveSystem, NotificationManager registrados en project.godot
- `systems/save/` — BaseSaveProvider (interfaz abstracta) + LocalSaveProvider (JSON local)
- `resources/PetStats.gd` — recurso con 4 stats, decaimiento en tiempo real, señales via EventBus
- `scenes/main/` — navegación entre pantallas + ciclo de vida de la app (pausa/cierre)
- `scenes/room/` — pantalla principal, instancia Pet y HUD, autosave
- `scenes/pet/` — entidad mascota, ticks de decaimiento, manejo de interacciones
- `scenes/hud/` — barras de stats + botones de acción conectados via EventBus
- `i18n/en.po` + `i18n/es.po` — claves base definidas

**Stats definitivas:** hambre · felicidad · energía · afecto
(`hunger` · `happiness` · `energy` · `affection` en el código)

---

## Decisiones de diseño confirmadas

- La mascota **no muere** — si los stats llegan a 0 se pone triste/apagada, pero no hay game over.
  Esto reduce la fricción y mejora la retención.
- **Fase 1 es single player**, sin backend. El componente social es Fase 2.
- Modelo de negocio: **cosmética in-app** (skins, accesorios, decoración) + expansion packs de especies.
  No hay suscripción ni pay-to-win.

---

## Milestones

### v0.1 — Prototipo jugable (semanas 1–3)
> Objetivo: validar que el loop de cuidado es divertido antes de agregar complejidad.

- [ ] Resolver discrepancia de stats (ver arriba)
- [ ] Subir `DECAY_MULTIPLIER` a `20.0` en `GameConfig.gd` para pruebas rápidas
- [ ] Asignar `SpriteFrames` placeholder a `Pet.tscn` → nodo `Sprite`
      (vale un rectángulo de color; sin esto la mascota es invisible)
- [ ] Verificar loop completo:
  - Las barras del HUD bajan solas en tiempo real
  - Cada botón sube la stat correcta
  - Al cerrar y reabrir, los valores persisten (save funciona)
  - La mascota reacciona visualmente cuando un stat está bajo (animación `sad` / `critical`)
- [ ] Implementar que la mascota "no muere": cuando hunger/energy/etc llegan a 0,
      cambiar a estado triste pero no terminar el juego

### v0.2 — IA de personalidad (semanas 4–5)
> Objetivo: que la mascota sienta única según cómo la criaste.

- [ ] Diseñar el árbol de rasgos de personalidad (decisión manual — no de código)
      Ejemplos: juguetona, tímida, glotona, dormilona, afectuosa...
- [ ] Implementar `PersonalitySystem.gd` — rasgos que emergen según el historial de acciones del jugador
      (ej: si siempre alimentás antes que jugar → rasgo "glotona")
- [ ] Los rasgos deben modificar el comportamiento visible: animaciones, reacciones, velocidad de decay
- [ ] Guardar rasgos activos en el save (bloque `"personality"` en SaveSystem)

### v0.3 — MVP completo (semana 6)
> Objetivo: listo para testear con usuarios reales.

- [ ] Notificaciones locales funcionando en dispositivo físico (ver Fase 4 abajo)
- [ ] Pantalla de onboarding / nombre de la mascota (primer arranque)
- [ ] Pantalla de ajustes: toggle idioma ES/EN, toggle notificaciones
- [ ] Customización básica: al menos 2–3 skins seleccionables (sin tienda aún)
- [ ] Pulido visual mínimo: theme de UI aplicado, fondo del cuarto con arte real

### v1.0 — Soft launch
- [ ] Arte final de la mascota + animaciones completas
- [ ] Sistema de evolución: la mascota cambia de aspecto según rasgos acumulados
- [ ] Tienda in-app (cosmética): skins, accesorios, decoración
- [ ] Eventos de temporada (Navidad, Halloween, etc.)
- [ ] Pulido de audio: música ambient cozy + SFX de interacciones
- [ ] Submit a Play Store + App Store

### v2.0 — Fase Social
- [ ] Backend (Supabase — ya hay un stub listo en `SaveSystem.gd`)
- [ ] Mascota compartida entre dos usuarios (amigos/parejas a distancia)
- [ ] Sincronización asíncrona de estado
- [ ] Notificaciones cruzadas ("tu amigo alimentó a la mascota")

---

## Fase 1 — Verificar el loop core
> Parte de v0.1. Sin esto no tiene sentido avanzar.

- [ ] Subir `DECAY_MULTIPLIER` a `20.0` en `autoloads/GameConfig.gd`
- [ ] Agregar sprite placeholder a `scenes/pet/Pet.tscn`
- [ ] Correr, probar los 4 botones, cerrar, reabrir, verificar persistencia
- [ ] Volver `DECAY_MULTIPLIER` a `1.0`

---

## Fase 2 — Integrar el arte del equipo
> Cuando lleguen los assets.

- [ ] **Mascota** — `Pet.tscn` → nodo `Sprite`: crear `SpriteFrames` con animaciones:
      `idle` / `happy` / `sad` / `eat` / `play` / `sleep` / `critical`
- [ ] **Fondo del cuarto** — `Room.tscn` → nodo `Background`: asignar textura del fondo;
      ajustar posición del `PetSpawnPoint` según composición
- [ ] **UI Theme** — crear Theme resource, definir fuentes + colores + estilos,
      asignarlo en `HUD.tscn`

---

## Fase 3 — Pantallas que faltan

- [ ] **Onboarding / nombre de la mascota** — nueva escena `scenes/ui/Onboarding.tscn`,
      registrar en `Main.SCREENS`, mostrar solo cuando `!SaveSystem.has_save()`
- [ ] **Settings** — toggle idioma + toggle notificaciones; guardar en bloque `settings` del save
- [ ] **Splash / pantalla de carga** — cubre el arranque, especialmente importante en mobile

---

## Fase 4 — Primera build en dispositivo físico
> Hacerlo antes de que el juego esté terminado — mejor descubrir problemas de export temprano.

### Android (empezar por aquí)
- [ ] `Project → Install Android Build Template` en Godot
- [ ] Instalar Android Studio para obtener SDK + JDK
- [ ] Crear keystore de debug: `keytool -genkey -v -keystore debug.keystore ...`
- [ ] `Project → Export → Android`: configurar package name (`com.tuequipo.petbond`), keystore, SDK path
- [ ] Exportar `.apk` e instalar en dispositivo por USB
- [ ] Verificar orientación, touch y rendimiento

### iOS (requiere Mac + Apple Developer $99/año)
- [ ] `Export → iOS` genera un proyecto `.xcodeproj`
- [ ] Abrir en Xcode, firmar con cuenta Developer, instalar en dispositivo
- [ ] Verificar que el pedido de permiso de notificaciones aparece correctamente

---

## Fase 5 — Notificaciones push locales
> Una vez que haya builds corriendo en dispositivo.

- [ ] Instalar plugin de notificaciones para Android
- [ ] Instalar plugin de notificaciones para iOS (godot-ios-plugins)
- [ ] Completar los `TODO` en `autoloads/NotificationManager.gd` con las llamadas del plugin
- [ ] Probar en dispositivo físico (en el editor no funcionan)
- [ ] Respetar el toggle de opt-out del usuario guardado en settings

---

## Diseño pendiente (decisiones manuales, no de código)

Estas cosas las define el equipo, no Claude Code:

- [ ] Mood board de estética visual cozy (referencia visual para el arte)
- [ ] Árbol de evolución: qué formas puede tomar la mascota y bajo qué condiciones
- [ ] Lista de rasgos de personalidad posibles y cómo se activan
- [ ] Definir las 4 stats finales (ver nota de discrepancia arriba)

---

## Referencia rápida de arquitectura

| Si necesitas...                        | Ve a...                             |
|----------------------------------------|-------------------------------------|
| Cambiar tasas de decaimiento           | `autoloads/GameConfig.gd`           |
| Añadir una nueva pantalla              | `scenes/main/Main.gd` → `SCREENS`  |
| Añadir una señal global nueva          | `autoloads/EventBus.gd`             |
| Cambiar cómo se guarda                 | `systems/save/LocalSaveProvider.gd` |
| Añadir una interacción nueva           | `scenes/pet/Pet.gd` + `scenes/hud/HUD.gd` |
| Añadir una string de UI                | `i18n/en.po` + `i18n/es.po`        |
| Activar save en la nube (v2)           | `GameConfig.FEATURE_CLOUD_SAVE = true` + implementar `SupabaseSaveProvider` |
