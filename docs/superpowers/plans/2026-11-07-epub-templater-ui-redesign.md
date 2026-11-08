# Rediseño de la Interfaz de Plantillas EPUB (Fase 1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rediseñar la barra superior, la estructura de secciones y el editor de sección de Plantillas EPUB para ofrecer una interfaz clara, guiada y con divulgación progresiva, adoptando un preset inicial de Novela Ligera.

**Architecture:** Se actualiza el dominio de `TemplateProject` para ofrecer el preset inicial de 8 secciones (Novela Ligera). Se rediseña `ProfileBar` para mostrar botones con texto (`Abrir perfil`, `Guardar perfil`) y el botón principal `Generar EPUB` visible en la cabecera. Se reestructura `SectionsPanel` con paneles colapsables por división (`BookMatter`) y badges de estado `Omitida del índice` (`inToc`). Se transforma `SectionEditor` en cuatro tarjetas modulares con subtítulos de ayuda y un bloque colapsable de opciones avanzadas (`ExpansionTile`).

**Tech Stack:** Flutter / Dart, `flutter_bloc`, `freezed`, Material 3 (`SegmentedButton`, `ExpansionTile`, `MenuAnchor`).

**Spec:** `docs/superpowers/specs/2026-11-07-epub-templater-ui-redesign.md`

## Global Constraints

- Dart SDK 3.8+, Flutter 3.x
- Mantener compatibilidad estricta con el generador EPUB (`epub_template_builder.dart`) sin romper esquemas de serialización JSON en perfiles existentes.
- Mantener todos los identificadores semánticos y claves de estado del Cubit (`EpubTemplaterCubit`).
- No utilizar placeholders ni `TODO` en el código productivo ni en las pruebas.
- Todos los cambios deben pasar la suite completa de pruebas (`flutter test`).

## Review Focus

1. **Persistencia y carga de perfiles existentes:** Los perfiles creados con versiones anteriores deben cargarse y guardarse sin pérdida de campos ni fallos de deserialización.
2. **Reordenación por arrastre entre divisiones:** Al arrastrar una sección a otra división colapsada o expandida, se debe actualizar correctamente `matter` y el orden en el spine.
3. **Sincronización bidireccional de `inToc`:** Alternar el checkbox en `SectionsPanel` o en la tarjeta de `SectionEditor` debe reflejar inmediatamente el cambio en ambos lugares (checkbox marcado/desmarcado y badge `Omitida del índice`).
4. **Acción de Generar EPUB sin SpeedDial:** El botón en la barra superior debe invocar la validación de errores y el selector de guardado de archivos de la misma forma que el anterior FAB.
5. **Diálogo de confirmación en acciones destructivas:** Restablecer proyecto y eliminar perfil deben requerir confirmación modal explícita antes de ejecutar la mutación.

---

### Task 1: Preset por Defecto Novela Ligera en `TemplateProject` y `EpubTemplaterCubit`

**Files:**
- Modify: `lib/features/epub_templater/domain/template_project.dart:25-56`
- Modify: `lib/features/epub_templater/presentation/cubit/epub_templater_cubit.dart:39-47`
- Test: `test/epub_template_builder_test.dart`

**Interfaces:**
- Consumes: `SectionKind`, `TemplateSection.of(kind, {number})`, `BookMetadata.initial()`.
- Produces:
  - `TemplateProject.initial()`: retorna un `TemplateProject` con exactamente 8 secciones canónicas de Novela Ligera (`cover`, `illustrations`, `titlePage`, `prologue`, `chapter 1`, `chapter 2`, `epilogue`, `afterword`).
  - `TemplateProject.allSections()`: preservado para perfiles completos.

- [ ] **Step 1: Escribir el test que valida el preset Novela Ligera**

En `test/epub_template_builder_test.dart`, agregar prueba para la composición de `TemplateProject.initial()`:
```dart
test('TemplateProject.initial genera las 8 secciones canónicas de Novela Ligera', () {
  final project = TemplateProject.initial();
  expect(project.sections.length, 8);
  expect(project.sections.map((s) => s.kind), [
    SectionKind.cover,
    SectionKind.illustrations,
    SectionKind.titlePage,
    SectionKind.prologue,
    SectionKind.chapter,
    SectionKind.chapter,
    SectionKind.epilogue,
    SectionKind.afterword,
  ]);
  expect(project.sections[4].fileName, 'capitulo01');
  expect(project.sections[5].fileName, 'capitulo02');
});
```

- [ ] **Step 2: Ejecutar el test para comprobar que falla**

Ejecutar:
```bash
cd ZeeTools && flutter test test/epub_template_builder_test.dart
```
Esperado: FALLO (actualmente genera 18 secciones).

- [ ] **Step 3: Modificar `TemplateProject.initial()` y `EpubTemplaterCubit`**

En `lib/features/epub_templater/domain/template_project.dart`:
```dart
  factory TemplateProject.initial() => TemplateProject(
    metadata: BookMetadata.initial(),
    fonts: const [
      EmbeddedFont(family: 'Times New Roman', headingLevels: [1]),
    ],
    sections: [
      TemplateSection.of(SectionKind.cover),
      TemplateSection.of(SectionKind.illustrations),
      TemplateSection.of(SectionKind.titlePage),
      TemplateSection.of(SectionKind.prologue),
      TemplateSection.of(SectionKind.chapter),
      TemplateSection.of(SectionKind.chapter, number: 2),
      TemplateSection.of(SectionKind.epilogue),
      TemplateSection.of(SectionKind.afterword),
    ],
  );
```

En `lib/features/epub_templater/presentation/cubit/epub_templater_cubit.dart`:
Asegurar que en la primera ejecución guarde el perfil de 'Novela ligera' y 'Todas las secciones', inicializando el borrador en `TemplateProject.initial()`:
```dart
    if (draft == null && profiles.isEmpty) {
      draft = TemplateProject.initial();
      profiles = {
        'Novela ligera': draft,
        allSectionsProfile: TemplateProject.allSections(),
      };
      _profilesRepo.saveProfiles(profiles);
    }
```

- [ ] **Step 4: Ejecutar el test para verificar que pasa**

Ejecutar:
```bash
cd ZeeTools && flutter test test/epub_template_builder_test.dart
```
Esperado: PASS.

- [ ] **Step 5: Confirmar cambios en Git**

```bash
git -C ZeeTools add lib/features/epub_templater/domain/template_project.dart lib/features/epub_templater/presentation/cubit/epub_templater_cubit.dart test/epub_template_builder_test.dart
git -C ZeeTools commit -m "feat(templater): establecer preset de 8 secciones para novela ligera por defecto"
```

---

### Task 2: Rediseño de la Barra Superior de Perfiles y Botón Generar EPUB

**Files:**
- Modify: `lib/features/epub_templater/presentation/views/widgets/profile_bar.dart`
- Modify: `lib/features/epub_templater/presentation/views/epub_templater_view.dart`
- Test: `test/epub_templater_view_test.dart`

**Interfaces:**
- Consumes: `EpubTemplaterCubit`, `EpubTemplaterState.profiles`, `EpubTemplaterState.generating`.
- Produces:
  - `ProfileBar`: incluye botones con texto visible `Abrir perfil`, `Guardar perfil`, botón destructivo `Eliminar perfil`, botón `Restablecer` con confirmación, y botón destacado `Generar EPUB` (`onGenerate`).

- [ ] **Step 1: Escribir test de interfaz para los nuevos botones visibles de `ProfileBar`**

En `test/epub_templater_view_test.dart`, añadir o actualizar prueba de presencia de botones visibles:
```dart
testWidgets('ProfileBar muestra botones con texto y botón Generar EPUB', (tester) async {
  await pumpView(tester);
  expect(find.widgetWithText(OutlinedButton, 'Abrir perfil'), findsOneWidget);
  expect(find.widgetWithText(OutlinedButton, 'Guardar perfil'), findsOneWidget);
  expect(find.widgetWithText(FilledButton, 'Generar EPUB'), findsOneWidget);
});
```

- [ ] **Step 2: Ejecutar el test para comprobar que falla**

Ejecutar:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart -n "ProfileBar muestra botones con texto"
```
Esperado: FALLO (los botones aún son `IconButton`).

- [ ] **Step 3: Implementar el rediseño en `ProfileBar` y `EpubTemplaterView`**

En `lib/features/epub_templater/presentation/views/widgets/profile_bar.dart`:
- Recibir callback opcional o función `onGenerate`.
- Transformar los iconos de guardar y cargar en botones legibles:
  - `OutlinedButton.icon(icon: Icon(Icons.download_outlined), label: Text('Abrir perfil'), onPressed: exists ? () => cubit.loadProfile(_name) : null)`
  - `OutlinedButton.icon(icon: Icon(Icons.save_outlined), label: Text(exists ? 'Sobrescribir' : 'Guardar perfil'), onPressed: _name.trim().isEmpty ? null : () => cubit.saveProfile(_name))`
- Agregar `FilledButton.icon(icon: Icon(Icons.save_alt), label: Text('Generar EPUB'), onPressed: onGenerate)` destacado.
- Agregar confirmación clara a `IconButton(icon: Icon(Icons.restart_alt))` antes de `cubit.resetProject()`.
- Agregar tooltips descriptivos a todos los botones auxiliares.

En `lib/features/epub_templater/presentation/views/epub_templater_view.dart`:
- Conectar `ProfileBar(onGenerate: _generate)`.
- Remover `_fabNotifier` y la asignación del SpeedDial/FAB.

- [ ] **Step 4: Ejecutar el test para comprobar que pasa**

Ejecutar:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart -n "ProfileBar muestra botones con texto"
```
Esperado: PASS.

- [ ] **Step 5: Confirmar cambios en Git**

```bash
git -C ZeeTools add lib/features/epub_templater/presentation/views/widgets/profile_bar.dart lib/features/epub_templater/presentation/views/epub_templater_view.dart test/epub_templater_view_test.dart
git -C ZeeTools commit -m "feat(templater): rediseñar barra superior con botones visibles y generar EPUB integrado"
```

---

### Task 3: Rediseño del Panel de Estructura del Libro (`SectionsPanel`)

**Files:**
- Modify: `lib/features/epub_templater/presentation/views/widgets/sections_panel.dart`
- Test: `test/epub_templater_view_test.dart`

**Interfaces:**
- Consumes: `EpubTemplaterCubit`, `TemplateProject.sections`, `TemplateSection.inToc`, `BookMatter`.
- Produces:
  - `SectionsPanel`: lista de divisiones colapsables (`ExpansionTile`), conteo `X de Y en el índice`, items con badge `Omitida del índice` y checkbox sincronizado con `inToc`.

- [ ] **Step 1: Escribir test para acordeones de división y badge `Omitida del índice`**

En `test/epub_templater_view_test.dart`:
```dart
testWidgets('SectionsPanel muestra divisiones con conteos y badge Omitida al desmarcar índice', (tester) async {
  await pumpView(tester);
  expect(find.textContaining('Estructura del libro'), findsOneWidget);
  expect(find.textContaining('CUERPO DE LA OBRA'), findsOneWidget);

  // Al desmarcar inToc se visualiza la badge 'Omitida del índice'
  final firstSection = cubit.state.project.sections.first;
  cubit.updateSection(firstSection.key, (s) => s.copyWith(inToc: false));
  await tester.pumpAndSettle();

  expect(find.text('Omitida del índice'), findsWidgets);
});
```

- [ ] **Step 2: Ejecutar el test para comprobar que falla**

Ejecutar:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart -n "SectionsPanel muestra divisiones"
```
Esperado: FALLO.

- [ ] **Step 3: Implementar `SectionsPanel` y `_SectionTile` rediseñados**

En `lib/features/epub_templater/presentation/views/widgets/sections_panel.dart`:
1. Cabecera del panel:
   - Título: `Text('Estructura del libro', style: theme.textTheme.titleMedium)`
   - Subtítulo informativo: `Text('Marca para incluir en el índice de contenidos. Arrastra :: para reordenar.', style: theme.textTheme.bodySmall)`
   - Conteo general: `${sections.where((s) => s.inToc).length} de ${sections.length} secciones en el índice`.
   - Botón `+ Añadir` (`FilledButton.tonalIcon` o `OutlinedButton.icon`) con el menú de tipos.
2. Agrupación por divisiones:
   - Para cada `BookMatter` (`front`, `body`, `back`):
     - Acordeón `ExpansionTile` inicialmente expandido (`initiallyExpanded: true`), con título formateado `PRELIMINARES · ${countInToc} DE ${totalCount}` en estilo `labelMedium`.
     - Lista reordenable interna para las secciones de esa división.
3. Item de sección (`_SectionTile`):
   - Arrastre a la izquierda: `Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.drag_indicator, size: 18))` con tooltip *"Arrastra para reordenar"*.
   - Icono y textos: título principal y subtítulo `${s.fileName}.xhtml · ${s.kind.label}`.
   - A la derecha:
     - Si `!s.inToc`: badge visual tipo pill `Container` con borde/color tenue y texto `Omitida del índice` en `labelSmall`.
     - `Checkbox` vinculado a `s.inToc`, con tooltip `s.inToc ? 'Incluida en el índice' : 'Omitida del índice'`.

- [ ] **Step 4: Ejecutar el test para comprobar que pasa**

Ejecutar:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart -n "SectionsPanel muestra divisiones"
```
Esperado: PASS.

- [ ] **Step 5: Confirmar cambios en Git**

```bash
git -C ZeeTools add lib/features/epub_templater/presentation/views/widgets/sections_panel.dart test/epub_templater_view_test.dart
git -C ZeeTools commit -m "feat(templater): rediseñar panel de estructura con divisiones colapsables e indicador omitida"
```

---

### Task 4: Rediseño del Editor de Sección Modular (`SectionEditor`)

**Files:**
- Modify: `lib/features/epub_templater/presentation/views/widgets/section_editor.dart`
- Test: `test/epub_templater_view_test.dart`

**Interfaces:**
- Consumes: `EpubTemplaterCubit`, `TemplateSection`.
- Produces:
  - `SectionEditor`: formulario dividido en tarjetas: *Qué es esta sección*, *Cómo se ve en la página*, *Aparece en el índice*, y *Opciones avanzadas* (`ExpansionTile`).

- [ ] **Step 1: Escribir test para la tarjeta de índice y el bloque colapsable de opciones avanzadas**

En `test/epub_templater_view_test.dart`:
```dart
testWidgets('SectionEditor contiene tarjetas modulares y opciones avanzadas colapsable', (tester) async {
  await pumpView(tester);
  expect(find.text('Qué es esta sección'), findsOneWidget);
  expect(find.text('Cómo se ve en la página'), findsOneWidget);
  expect(find.text('Aparece en el índice'), findsOneWidget);
  expect(find.text('Opciones avanzadas'), findsOneWidget);

  // Opciones avanzadas inicia colapsado (no se ve epub:type inicialmente)
  expect(find.widgetWithText(DropdownButtonFormField, 'epub:type'), findsNothing);

  // Al desplegar Opciones avanzadas se hace visible
  await tester.tap(find.text('Opciones avanzadas'));
  await tester.pumpAndSettle();
  expect(find.text('Etiqueta ARIA'), findsOneWidget);
});
```

- [ ] **Step 2: Ejecutar el test para comprobar que falla**

Ejecutar:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart -n "SectionEditor contiene tarjetas modulares"
```
Esperado: FALLO.

- [ ] **Step 3: Implementar el rediseño en `SectionEditor`**

En `lib/features/epub_templater/presentation/views/widgets/section_editor.dart`:
1. Cabecera con división, nombre actual, botón `Duplicar` y botón `Eliminar sección` (con diálogo `confirmAction`).
2. Tarjeta 1: `FormSection(title: 'Qué es esta sección', subtitle: 'El tipo decide su lugar y su comportamiento en el libro.')`:
   - Desplegable de `SectionKind`.
   - `AppTextField` de archivo `.xhtml` con sufijo y saneamiento.
3. Tarjeta 2: `FormSection(title: 'Cómo se ve en la página', subtitle: 'Lo que el lector verá al empezar la sección.')`:
   - `AppTextField` de título visible.
   - `AppTextField` de subtítulo con ayuda *"Aparece debajo, en letra más pequeña"*.
   - Selector `HeadingStyle` (si `SectionLayout.text`).
   - `ToggleField` o `CheckboxListTile`: *"Mostrar el título en la página"* con ayuda explicativa.
4. Tarjeta 3: `FormSection(title: 'Aparece en el índice', subtitle: 'La tabla de contenidos del libro.')`:
   - `ToggleField`: *"Incluir en el índice"*.
   - `AppTextField` de nombre en el índice con placeholder tenue del título actual.
   - `SegmentedButton<int>` para el nivel:
     - 1: `Principal (h1)`
     - 2: `Subnivel (h2)`
     - 3: `Sub-subnivel (h3)`
5. Tarjeta 4: `Card` o `Material` con `ExpansionTile`:
   - Título: *"Opciones avanzadas"*
   - Subtítulo: *"Tipo semántico (epub:type), división del libro y accesibilidad (ARIA). Ya vienen bien configurados."*
   - `initiallyExpanded: false`.
   - Contenido:
     - Selector `BookMatter`.
     - Selector `epub:type`.
     - `AppTextField` para `Etiqueta ARIA`.

- [ ] **Step 4: Ejecutar el test para comprobar que pasa**

Ejecutar:
```bash
cd ZeeTools && flutter test test/epub_templater_view_test.dart -n "SectionEditor contiene tarjetas modulares"
```
Esperado: PASS.

- [ ] **Step 5: Confirmar cambios en Git**

```bash
git -C ZeeTools add lib/features/epub_templater/presentation/views/widgets/section_editor.dart test/epub_templater_view_test.dart
git -C ZeeTools commit -m "feat(templater): reorganizar editor de sección en tarjetas modulares con opciones avanzadas colapsables"
```

---

### Task 5: Actualización Integral de la Suite de Tests y Verificación Final

**Files:**
- Modify: `test/epub_templater_view_test.dart`
- Modify: `test/plugins_test.dart` (si aplica)

**Interfaces:**
- Consumes: Toda la suite de widgets y cubits de `epub_templater`.
- Produces: Suite completa de pruebas ejecutándose en verde al 100%.

- [ ] **Step 1: Ajustar expectativas en `test/epub_templater_view_test.dart`**

Actualizar los tests que buscaban etiquetas anteriores:
- Actualizar el conteo inicial en `secciones: lista inicial, añadir y editar la seleccionada`: ahora inicia con 8 secciones de Novela Ligera en lugar de todas las secciones.
- Actualizar los finders de `Guardar perfil` y `Cargar perfil` para encontrar los nuevos `OutlinedButton`.
- Verificar que las pruebas de reordenación y eliminación sigan cumpliendo sus aserciones.

- [ ] **Step 2: Ejecutar la suite completa de tests de ZeeTools**

Ejecutar:
```bash
cd ZeeTools && flutter test
```
Esperado: `All tests passed!` (85+ tests pasando).

- [ ] **Step 3: Ejecutar análisis estático para garantizar código limpio**

Ejecutar:
```bash
cd ZeeTools && flutter analyze
```
Esperado: `No issues found!`.

- [ ] **Step 4: Confirmar la actualización de tests en Git**

```bash
git -C ZeeTools add test/
git -C ZeeTools commit -m "test(templater): actualizar suite de pruebas para el rediseño de secciones y barra de perfiles"
```
