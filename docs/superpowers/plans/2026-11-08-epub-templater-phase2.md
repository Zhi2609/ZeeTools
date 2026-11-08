# Rediseño de Plantillas EPUB (Fase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rediseñar la experiencia de usuario de las pestañas Metadatos, Imágenes y Fuentes y CSS en el creador de plantillas EPUB de ZeeTools mediante divulgación progresiva, claridad semántica y asistencia activa al usuario.

**Architecture:** Modificaciones en la capa de presentación de Flutter (`features/epub_templater/presentation/views/widgets/`). Se actualizan `metadata_form.dart`, `images_form.dart` y `fonts_form.dart`, preservando intacta la capa de dominio (`TemplateProject`, `BookMetadata`, `EmbeddedFont`) y la compatibilidad con perfiles existentes.

**Tech Stack:** Flutter 3, Dart 3, `flutter_bloc`, `shared_preferences`, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-11-08-epub-templater-phase2-design.md`

## Global Constraints

- Todas las ejecuciones de comandos deben emplear `BypassSandbox: true` debido a las restricciones de configuración local del entorno.
- El formato y serialización JSON de `TemplateProject`, `BookMetadata` y `EmbeddedFont` no deben romperse ni modificarse.
- Se debe mantener 100% de pase en toda la suite de pruebas (`flutter test`) y 0 advertencias en `dart analyze`.
- Seguir metodología TDD rigurosa: escribir prueba que falle primero, verificar fallo, escribir código mínimo, verificar pase y hacer commit.

## Review Focus

1. **Idiomas alternativos requeridos vs opcionales:** Si el idioma del libro es japonés o requiere romanización, el campo obligatorio debe ser visible siempre y señalarse como 'Obligatorio' cuando esté vacío; los idiomas opcionales no deben saturar la vista.
2. **Restablecimiento de `fileAs` en autores:** Al modificar el nombre se recalcula automáticamente si no se ha personalizado a mano; si se personalizó, el botón de sincronización `sync` debe restablecer el valor a `fileAsFor(name)`.
3. **Filtro de secciones en imágenes:** Si el usuario selecciona el filtro "Ilustraciones", las secciones de texto sin pliegos de imagen completa no deben mostrarse en el formulario.
4. **Descripciones de QualityMode:** Al cambiar entre `Lossless`, `Balanced` y `Smallest`, la leyenda explicativa debe actualizarse de inmediato sin provocar desbordamientos de pantalla.
5. **Niveles de encabezado semánticos en Fuentes:** Los niveles h1, h2, h3 deben mostrar etiquetas legibles descriptivas sin romper la selección múltiple en el estado del cubit.

---

### Task 1: Divulgación Progresiva en Idiomas Alternativos de Metadatos

**Files:**
- Modify: `lib/features/epub_templater/presentation/views/widgets/metadata_form.dart:268-312, 500-520`
- Modify / Test: `test/epub_templater_view_test.dart:464-480`

**Interfaces:**
- Consumes: `List<LocalizedText> items`, `String main`, `String? requiredLang`, `OriginalLanguage? original`, `String noun`, `withLocalizedText()`, `localizedText()`.
- Produces: Componente `_Alternates` con divulgación progresiva que renderiza campos requeridos y con contenido, más el botón `+ Añadir $noun en otro idioma` con menú de selección.

- [ ] **Step 1: Write the failing test for progressive disclosure of alternates**

En `test/epub_templater_view_test.dart`, adaptar y ampliar la prueba de equivalentes obligatorios y opcionales:

```dart
testWidgets('divulgación progresiva: solo muestra idiomas requeridos o con texto y permite añadir opcionales', (tester) async {
  cubit.updateMetadata((m) => m.copyWith(title: 'Wandering Witch', language: 'ja'));
  await pumpView(tester, size: const Size(1280, 3000));
  await tester.tap(find.text('Metadatos'));
  await tester.pumpAndSettle();

  // El campo obligatorio (japonés) siempre es visible y marcado como obligatorio si está vacío
  expect(find.widgetWithText(TextFormField, 'Título en japonés'), findsOneWidget);
  expect(find.descendant(of: find.widgetWithText(TextFormField, 'Título en japonés'), matching: find.text('Obligatorio')), findsOneWidget);

  // Los campos opcionales sin contenido (español, inglés) están ocultos por defecto
  expect(find.widgetWithText(TextFormField, 'Título en español'), findsNothing);
  expect(find.text('+ Añadir título en otro idioma'), findsOneWidget);

  // Al pulsar añadir otro idioma, se despliega el menú y permite agregarlo
  await tester.tap(find.text('+ Añadir título en otro idioma'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Español').last);
  await tester.pumpAndSettle();

  // Ahora el campo de español es visible
  expect(find.widgetWithText(TextFormField, 'Título en español'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart --name "divulgación progresiva"
```
Expected: FAIL con "Expected: findsNothing, Actual: 1" o "+ Añadir título en otro idioma not found".

- [ ] **Step 3: Implement progressive disclosure in `_Alternates`**

Modificar `_Alternates` en `lib/features/epub_templater/presentation/views/widgets/metadata_form.dart`:
- Mantener un conjunto de idiomas activos en `items` (los que tienen texto) más `requiredLang` más cualquier idioma añadido en la sesión (`_extraLangs`).
- Ofrecer un botón `+ Añadir $noun en otro idioma` (`PopupMenuButton` o `MenuAnchor`) con los idiomas disponibles que aún no están visibles.
- Añadir botón de eliminación en cada campo opcional visible para retirarlo si está vacío o si el usuario desea quitarlo.

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart --name "divulgación progresiva"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ZeeTools/lib/features/epub_templater/presentation/views/widgets/metadata_form.dart ZeeTools/test/epub_templater_view_test.dart
git commit -m "feat(epub_templater): add progressive disclosure for metadata alternate languages"
```

---

### Task 2: Asistencia Visual y Sincronización de `fileAs` en Creadores y Personas

**Files:**
- Modify: `lib/features/epub_templater/presentation/views/widgets/metadata_form.dart:655-675`
- Test: `test/epub_templater_view_test.dart:354-370`

**Interfaces:**
- Consumes: `Actor actor`, `fileAsFor(name)`, `widget.onChanged`.
- Produces: Campo `Nombre para ordenar` con indicación visual de generación automática (`auto_mode`) y botón de sincronización (`sync`) para restablecer a `fileAsFor(actor.name)`.

- [ ] **Step 1: Write the failing test for `fileAs` sync and indicator**

En `test/epub_templater_view_test.dart`, actualizar la prueba existente `'el nombre para ordenar se habilita con el nombre y se deduce mientras no se edite'`:

```dart
testWidgets('el nombre para ordenar se deduce automáticamente y permite restablecer con botón sync', (tester) async {
  await pumpView(tester, size: const Size(1280, 3000));
  await tester.tap(find.text('Metadatos'));
  await tester.pumpAndSettle();

  await tester.enterText(find.widgetWithText(TextFormField, 'Nombre en romaji').first, 'Nanasawa Matari');
  await tester.pumpAndSettle();
  expect(cubit.state.project.metadata.actors.first.fileAs, 'Matari, Nanasawa');
  expect(find.byTooltip('Generado automáticamente a partir del nombre'), findsWidgets);

  // Editamos manualmente el nombre para ordenar
  await tester.enterText(find.widgetWithText(TextField, 'Nombre para ordenar').first, 'Nanasawa');
  await tester.pumpAndSettle();
  expect(cubit.state.project.metadata.actors.first.fileAs, 'Nanasawa');
  expect(find.byTooltip('Restablecer orden automático a "Matari, Nanasawa"'), findsOneWidget);

  // Pulsamos el botón de restablecer orden automático
  await tester.tap(find.byTooltip('Restablecer orden automático a "Matari, Nanasawa"'));
  await tester.pumpAndSettle();
  expect(cubit.state.project.metadata.actors.first.fileAs, 'Matari, Nanasawa');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart --name "el nombre para ordenar se deduce"
```
Expected: FAIL con "Tooltip not found".

- [ ] **Step 3: Implement `fileAs` indicator and sync button in `_ActorEditor`**

En `metadata_form.dart`:
```dart
final autoFileAs = fileAsFor(actor.name);
final isAuto = actor.fileAs.trim().isEmpty || actor.fileAs == autoFileAs;

AppTextField(
  label: 'Nombre para ordenar',
  value: actor.fileAs,
  hint: 'Apellido, Nombre',
  enabled: actor.name.trim().isNotEmpty,
  suffix: actor.name.trim().isEmpty
      ? null
      : isAuto
          ? const Tooltip(
              message: 'Generado automáticamente a partir del nombre',
              child: Icon(Icons.auto_mode, size: 18),
            )
          : IconButton(
              tooltip: 'Restablecer orden automático a "$autoFileAs"',
              icon: const Icon(Icons.sync, size: 18),
              onPressed: () => widget.onChanged(actor.copyWith(fileAs: autoFileAs)),
            ),
  onChanged: (v) => widget.onChanged(actor.copyWith(fileAs: v)),
)
```

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart --name "el nombre para ordenar se deduce"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ZeeTools/lib/features/epub_templater/presentation/views/widgets/metadata_form.dart ZeeTools/test/epub_templater_view_test.dart
git commit -m "feat(epub_templater): add fileAs auto-mode indicator and sync button in actor editor"
```

---

### Task 3: Filtros de Sección y Asistencia de Optimización en Imágenes

**Files:**
- Modify: `lib/features/epub_templater/presentation/views/widgets/images_form.dart:25-99`
- Test: `test/epub_templater_view_test.dart`

**Interfaces:**
- Consumes: `QualityMode`, `TemplateSection`, `EpubTemplaterCubit`.
- Produces: `ImagesForm` con `FilterChip` de filtrado (`Todas`, `Ilustraciones`, `Encabezados`) y descripciones contextuales bajo el selector de calidad.

- [ ] **Step 1: Write the failing test for images filtering and quality description**

En `test/epub_templater_view_test.dart`, añadir prueba para los filtros y leyenda de calidad:

```dart
testWidgets('pestaña imágenes: permite filtrar secciones y muestra ayuda de modos de calidad', (tester) async {
  await pumpView(tester, size: const Size(1280, 1000));
  await tester.tap(find.text('Imágenes'));
  await tester.pumpAndSettle();

  // Comprueba que los chips de filtrado están presentes
  expect(find.widgetWithText(FilterChip, 'Todas'), findsOneWidget);
  expect(find.widgetWithText(FilterChip, 'Ilustraciones'), findsOneWidget);

  // Comprueba la descripción del modo de calidad actual
  expect(find.textContaining('Equilibrada: compresión recomendada para libros digitales'), findsOneWidget);

  // Cambiar a Sin pérdida actualiza la descripción
  await tester.tap(find.text('Sin pérdida'));
  await tester.pumpAndSettle();
  expect(find.textContaining('Conserva la calidad idéntica del original'), findsOneWidget);

  // Filtrar por ilustraciones solo muestra la cubierta e ilustraciones, ocultando encabezados
  await tester.tap(find.widgetWithText(FilterChip, 'Ilustraciones'));
  await tester.pumpAndSettle();
  expect(find.text('Cubierta'), findsOneWidget);
  expect(find.text('Ilustraciones'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart --name "pestaña imágenes: permite filtrar"
```
Expected: FAIL con "FilterChip 'Todas' not found".

- [ ] **Step 3: Implement filtering and quality help in `images_form.dart`**

En `images_form.dart`:
- Convertir `ImagesForm` a `StatefulWidget` con enum `_ImageFilter { all, illustrations, headings }`.
- Agregar barra de `FilterChip` (`Todas`, `Ilustraciones`, `Encabezados`) calculando conteos de secciones.
- Filtrar la lista de `FormSection` según el filtro seleccionado.
- En `_OptimizationOptions`, añadir texto descriptivo bajo `SegmentedButton<QualityMode>` mapeando cada valor a su explicación editorial en tamaño `bodySmall`.

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart --name "pestaña imágenes: permite filtrar"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ZeeTools/lib/features/epub_templater/presentation/views/widgets/images_form.dart ZeeTools/test/epub_templater_view_test.dart
git commit -m "feat(epub_templater): add filter chips and quality mode guidance to images form"
```

---

### Task 4: Niveles Semánticos, Muestra Tipográfica, Copia de Clase y Aviso CSS Propio

**Files:**
- Modify: `lib/features/epub_templater/presentation/views/widgets/fonts_form.dart:30-165`
- Test: `test/epub_templater_view_test.dart:337-353`

**Interfaces:**
- Consumes: `EmbeddedFont font`, `GenericFamily`, `EpubTemplaterCubit`.
- Produces: Tarjeta `_FontCard` con niveles semánticos (`h1 · Capítulos`, `h2 · Subtítulos`, etc.), previsualización de titular + párrafo de lectura, botón `Copiar clase` con feedback, y aviso aclaratorio en `FormSection(title: 'CSS propio')`.

- [ ] **Step 1: Write failing test for fonts semantic levels, typography sample, and copy class**

En `test/epub_templater_view_test.dart`, adaptar y ampliar la prueba existente de fuentes:

```dart
testWidgets('fuentes: niveles semánticos, muestra tipográfica completa y copia de clase', (tester) async {
  await pumpView(tester);
  await tester.tap(find.text('Fuentes y CSS'));
  await tester.pumpAndSettle();
  expect(find.text('Times New Roman'), findsOneWidget);

  // Muestra de párrafo de lectura presente
  expect(find.textContaining('En un rincón apartado de la biblioteca'), findsOneWidget);

  // Niveles semánticos descriptivos
  expect(find.widgetWithText(SelectionPill, 'h1 · Capítulos'), findsOneWidget);
  expect(find.widgetWithText(SelectionPill, 'h2 · Subtítulos'), findsOneWidget);

  await tester.tap(find.widgetWithText(SelectionPill, 'h2 · Subtítulos'));
  await tester.pumpAndSettle();
  expect(cubit.state.project.fonts.single.headingLevels, [1, 2]);

  // Botón de copiar clase
  expect(find.byTooltip('Copiar clase CSS'), findsOneWidget);
  await tester.tap(find.byTooltip('Copiar clase CSS'));
  await tester.pumpAndSettle();
  expect(find.textContaining('copiada al portapapeles'), findsOneWidget);

  // Aviso de CSS propio
  expect(find.textContaining('La plantilla ya incluye y genera todo el CSS base'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart --name "fuentes: niveles semánticos"
```
Expected: FAIL con "SelectionPill 'h1 · Capítulos' not found".

- [ ] **Step 3: Implement semantic levels, preview sample, copy button, and CSS notice in `fonts_form.dart`**

En `fonts_form.dart`:
- Definir mapeo de etiquetas semánticas:
  `1: 'h1 · Capítulos', 2: 'h2 · Subtítulos', 3: 'h3 · Encabezados menores'`.
  Ofrecer selector expandible o pills directas para niveles 1-3 y botón "+ Otros (h4-h6)".
- En `_FontCard`, incorporar tras el titular un párrafo de lectura de 2-3 líneas con estilo `fontFamily: font.family`.
- Añadir `IconButton` con icono `Icons.copy` y tooltip `"Copiar clase CSS"` que copie al portapapeles y muestre `SnackBar`.
- En `FontsForm`, añadir `subtitle: 'La plantilla ya incluye y genera todo el CSS base del libro. Usa este espacio únicamente para añadir reglas adicionales o sobrescribir estilos existentes.'` en la sección de CSS propio.

- [ ] **Step 4: Run test to verify it passes**

Run:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart --name "fuentes: niveles semánticos"
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add ZeeTools/lib/features/epub_templater/presentation/views/widgets/fonts_form.dart ZeeTools/test/epub_templater_view_test.dart
git commit -m "feat(epub_templater): add semantic heading levels, reading sample, copy class button, and css guidance"
```

---

### Task 5: Verificación Integral y Pruebas de Regresión

**Files:**
- Test: Toda la suite de `test/`
- Check: Análisis estático de Dart

- [ ] **Step 1: Run all tests in the repository**

Run:
```bash
cd ZeeTools && flutter test
```
Expected: Todos los tests pasan (90+ tests pasando, 0 fallos).

- [ ] **Step 2: Run static analysis**

Run:
```bash
cd ZeeTools && dart analyze
```
Expected: `No issues found!`.

- [ ] **Step 3: Final verification commit**

```bash
git status
```
Verificar que la rama `feature/epub-templater-ui-phase-2` está limpia y lista para revisión.
