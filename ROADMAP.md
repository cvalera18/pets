# PetBond — Roadmap

> Nombre provisional en el repo: "Pets" · Nombre real del producto: **PetBond**
> Última actualización: 2026-06-25
> Rama activa: `main` (sincronizada con `origin/main`)

---

## Estado actual

El juego está **jugable, pulido y fiel al diseño**. El loop de cuidado funciona de
punta a punta, con juego, persistencia y una capa visual/feel completa — todo
**procedural, sin un solo asset de arte raster**.

**Implementado y funcionando:**
- **Loop core** — 4 stats (hambre · felicidad · energía · afecto) con decaimiento en
  tiempo real, 4 acciones (alimentar/jugar/dormir/mimar), "no muere" (sad en vez de
  game over), persistencia con autosave.
- **Mascota (Mochi)** — dibujada procedural en `scenes/pet/Mochi.gd` (`_draw`):
  respiración/bob/parpadeo + caras por mood (happy/sleep/sad). Sin spritesheet.
- **Feel / juice** — texto flotante, partículas/bursts, haptics, SFX procedurales
  (`AudioManager`).
- **Progresión de vínculo** — XP + niveles de bond, chip "Nivel N" + barra de progreso.
- **Logros** — 5 hitos (primer cuidado, bond 3/5, cuidador 50/200).
- **Pensamientos idle** — burbujas con lo que "piensa" la mascota.
- **Ciclo día/noche** — tinte por hora con blend multiply (atardecer/noche).
- **Onboarding** (nombre) y **Ajustes** (idioma ES/EN, notif, sonido, volumen, modo
  de prueba de decay, borrar datos).
- **Rediseño visual completo** — replica el handoff de Claude Design (cozy pastel):
  `CozyRoom` (habitación procedural), HUD restilado (tarjetas, barras con gradiente
  vía shader, botones con círculo gradiente + labio 3D, name pill), fuentes reales
  (Fredoka/Quicksand), íconos SVG. Auditado: 0 assets raster necesarios.
- **Tests** — `tests/TestRunner.tscn` (PetStats, migraciones de save, logros).
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
- **Restricción de producción**: dev solo, sin artista. La estrategia probada es
  hacer TODO procedural/vectorial en código (el diseño es 100% vector → se reproduce
  con `StyleBoxFlat`/`GradientTexture2D`/shaders/`_draw`). Un gato ilustrado sería
  opcional, nunca un bloqueante.

---

## Lo que sigue — re-priorizado

El loop core (v0.1) y la mayoría del MVP visual (v0.3) están **hechos**. Lo que falta
se parte en **profundidad** (lo que hace único al juego) y **ship-readiness** (poder
testear con gente real). Orden recomendado:

1. **🧬 Personalidad emergente (v0.2)** — *el diferenciador*. Rasgos que surgen del
   historial de cuidado (glotona, dormilona, juguetona…) y modifican reacciones,
   animaciones y velocidad de decay. 100% código, sin arte. Es lo que convierte el
   loop genérico en "PetBond".
2. **📱 Build en Android (Fase 4)** — el juego nunca tocó un teléfono. Hacerlo pronto
   (no al final) para descubrir problemas de export/touch/orientación/rendimiento y
   poder testear con usuarios reales. Hay skill `android-cli`.
3. **🎨 Skins procedurales (v0.3)** — como Mochi es procedural, las skins también:
   paletas de pelaje, patrones y accesorios en código. Suma customización + siembra
   el modelo de negocio, sin cuello de botella de arte.
4. **🔔 Notificaciones en device (Fase 5)** — retención. Requiere (2) primero.
5. **🎵 Música ambient cozy** — los SFX existen; falta la música de fondo que completa
   el feel.
6. **v1.0** — evolución por rasgos, tienda in-app, eventos de temporada.
7. **v2.0** — social/backend (Supabase; hay stub en `SaveSystem`).

---

## Milestones

### v0.1 — Prototipo jugable ✅ HECHO
Loop de cuidado validado: barras decaen en tiempo real, cada acción sube su stat,
persistencia OK, estados sad/critical, "no muere".

### v0.2 — IA de personalidad ⬅️ PRÓXIMO
> Objetivo: que la mascota se sienta única según cómo la criaste.
- [ ] Diseñar el árbol de rasgos (decisión manual — ver "Diseño pendiente")
- [ ] `PersonalitySystem.gd` — rasgos que emergen del historial de acciones
      (ej: siempre alimentar antes que jugar → "glotona")
- [ ] Los rasgos modifican comportamiento visible: animaciones, reacciones, decay
- [ ] Guardar rasgos en el save (bloque `"personality"`, nueva migración)

### v0.3 — MVP completo 🟡 CASI
- [x] Onboarding / nombre
- [x] Ajustes (idioma, notif, sonido, volumen, etc.)
- [x] Pulido visual / tema de UI / habitación
- [ ] Customización: 2–3 skins seleccionables (procedurales, sin tienda aún)
- [ ] Notificaciones locales en dispositivo físico (ver Fase 5)

### v1.0 — Soft launch
- [ ] Sistema de evolución: la mascota cambia de aspecto según rasgos acumulados
- [ ] Tienda in-app (cosmética): skins, accesorios, decoración
- [ ] Eventos de temporada (Navidad, Halloween…)
- [ ] Música ambient cozy (los SFX ya están)
- [ ] (Opcional) arte ilustrado de la mascota si se decide ir más allá del procedural
- [ ] Submit a Play Store + App Store

### v2.0 — Fase social
- [ ] Backend (Supabase — stub listo en `SaveSystem.gd`)
- [ ] Mascota compartida entre dos usuarios (amigos/parejas a distancia)
- [ ] Sincronización asíncrona + notificaciones cruzadas

---

## Fase 4 — Primera build en dispositivo físico
> Hacerlo pronto, no al final — mejor descubrir problemas de export temprano.

### Android (empezar por aquí · skill `android-cli`)
- [ ] `Project → Install Android Build Template` en Godot
- [ ] Android Studio para SDK + JDK
- [ ] Keystore de debug: `keytool -genkey -v -keystore debug.keystore ...`
- [ ] `Export → Android`: package name (`com.cvalera.petbond`), keystore, SDK path
- [ ] Exportar `.apk`, instalar por USB, verificar orientación/touch/rendimiento

### iOS (requiere Mac + Apple Developer $99/año)
- [ ] `Export → iOS` → proyecto `.xcodeproj`, firmar en Xcode, instalar en device
- [ ] Verificar que el permiso de notificaciones aparece bien

---

## Fase 5 — Notificaciones locales
> Una vez que haya builds en dispositivo (en el editor no funcionan).

- [ ] Plugin de notificaciones Android + iOS
- [ ] Completar los `TODO` en `autoloads/NotificationManager.gd` con las llamadas del plugin
- [ ] Probar en device físico
- [ ] Respetar el toggle de opt-out (ya guardado en settings)

---

## Diseño pendiente (decisiones manuales, no de código)

- [ ] Árbol de rasgos de personalidad: lista de rasgos y cómo se activan (input para v0.2)
- [ ] Árbol de evolución: qué formas toma la mascota y bajo qué condiciones
- [ ] Catálogo de skins procedurales (paletas/patrones/accesorios) y precios
- [ ] Mood board cozy (solo si se decide explorar arte ilustrado en v1.0)

---

## Referencia rápida de arquitectura

| Si necesitas...                        | Ve a...                             |
|----------------------------------------|-------------------------------------|
| Cambiar tasas de decaimiento           | `autoloads/GameConfig.gd`           |
| Añadir una nueva pantalla              | `scenes/main/Main.gd` → `SCREENS`   |
| Añadir una señal global nueva          | `autoloads/EventBus.gd`             |
| Cambiar cómo se guarda / migraciones   | `systems/save/LocalSaveProvider.gd` + `SaveSystem.gd` |
| Añadir una interacción nueva           | `scenes/pet/Pet.gd` + `scenes/hud/HUD.gd` |
| Tocar colores / fuentes / íconos       | `theme/Palette.gd` · `autoloads/Fonts.gd` · `autoloads/Icons.gd` |
| Añadir una string de UI                | `i18n/en.po` + `i18n/es.po`         |
| Activar save en la nube (v2)           | `GameConfig.FEATURE_CLOUD_SAVE = true` + implementar `SupabaseSaveProvider` |
| Convenciones, gotchas, cómo correr     | `CLAUDE.md` (local)                 |
