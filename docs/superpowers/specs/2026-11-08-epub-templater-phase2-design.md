# Especificación de Diseño: Rediseño de la Interfaz de Plantillas EPUB (Fase 2)

**Fecha:** 2026-11-08  
**Estado:** Propuesta en revisión  
**Módulo:** `features/epub_templater`  
**Rama:** `feature/epub-templater-ui-phase-2`  
**Objetivo:** Rediseñar la experiencia de usuario de las pestañas **Metadatos**, **Imágenes** y **Fuentes y CSS** en el creador de plantillas EPUB de ZeeTools, aplicando divulgación progresiva, claridad semántica y asistencia activa al usuario para reducir la sobrecarga cognitiva.

---

## 1. Contexto y Diagnóstico

Tras la culminación de la Fase 1 (Barra superior, panel de estructura de secciones y editor modular de sección), las tres pestañas secundarias presentan oportunidades concretas de mejora identificadas en el brainstorming:

1. **Pestaña Metadatos (`metadata_form.dart`):**
   * **Sobrecarga de idiomas alternativos:** `_Alternates` genera simultáneamente campos para español, inglés y variantes romanizadas en paralelo para título y serie, independientemente de si el usuario los necesita o no.
   * **Opacidad en ordenación de autores (`fileAs`):** Aunque el sistema calcula automáticamente el formato `"Apellido, Nombre"`, el usuario no siempre entiende qué hace el campo o cuándo se actualiza.
   * **Indicadores de campos pendientes:** El contador numérico en la pestaña o sección no detalla claramente la naturaleza de los campos pendientes.

2. **Pestaña Imágenes (`images_form.dart`):**
   * **Falta de categorización visual:** Todas las secciones con imágenes aparecen en una lista plana idéntica, sin distinguir claramente entre la cubierta, pliegos de ilustraciones a página completa y viñetas/encabezados de capítulo.
   * **Controles de optimización poco asistidos:** `SegmentedButton<QualityMode>` carece de texto explicativo sobre el impacto de cada modo en el peso y calidad final del EPUB.

3. **Pestaña Fuentes y CSS (`fonts_form.dart`):**
   * **Niveles de encabezado abstractos:** Se ofrece una lista genérica `h1` a `h9` mediante chips, sin indicar su función real en la maquetación del libro.
   * **Previsualización tipográfica deficiente:** Solo muestra un titular corto de muestra, sin reflejar cómo rinde la tipografía en un bloque de párrafo de lectura real.
   * **Copia de clases y CSS propio:** La clase CSS generada se muestra como texto estático sin un botón rápido para copiarla al portapapeles, y el área de "CSS propio" carece de un aviso que aclare que el CSS base ya está completamente construido por la plantilla.

---

## 2. Objetivos y No-Objetivos

### Objetivos:
- Implementar **divulgación progresiva** en idiomas alternativos (título y serie): mostrar por defecto solo el idioma principal (y el requerido según la configuración) con un botón explícito `+ Añadir otro idioma`.
- Mejorar la experiencia en **autores y personas**: indicar visualmente la deducción automática de `fileAs` ("Apellido, Nombre") con opción de sincronización/restablecimiento si el usuario la modificó.
- Ofrecer **filtros rápidos** en la pestaña de Imágenes (`Todas`, `Ilustraciones`, `Capítulos / Texto`) y descripciones breves del modo de compresión (`Lossless`, `Equilibrada`, `Máxima`).
- Transformar los selectores de niveles tipográficos en **niveles semánticos editoriales** (`h1: Título de capítulo`, `h2: Subtítulo / Parte`, `h3: Encabezado menor`).
- Enriquecer la previsualización tipográfica (título + párrafo de muestra de 2-3 líneas) y añadir botón `Copiar clase` (`.font-...`).
- Explicar de forma visible el propósito del editor de "CSS propio" para evitar confusión sobre estilos base.

### No-Objetivos:
- No modificar el esquema de serialización JSON de `TemplateProject` ni romper compatibilidad con perfiles existentes.
- No alterar los algoritmos de compresión de imágenes ni los procesadores de fuentes en `image_optimizer` o `system_fonts`.
- No añadir generadores o "chips de inserción" de reglas CSS genéricas en la caja de CSS propio (el CSS base ya lo maneja el builder).

---

## 3. Especificación Detallada de Componentes

### 3.1. Pestaña de Metadatos (`metadata_form.dart`)

#### A. Divulgación Progresiva de Idiomas Alternativos (`_Alternates`)
* **Comportamiento actual:** Genera automáticamente campos para español, inglés y variantes romanizadas/nativas de golpe.
* **Nuevo comportamiento:**
  - Si el idioma del libro requiere un equivalente obligatorio (ej. japonés con romanización/español obligatorio en `requiredLang`), ese campo se muestra visible permanentemente con su etiqueta de requerido o advertencia.
  - Los idiomas opcionales que tengan texto introducido se renderizan en pantalla con un botón de eliminar (icono papelera/cruz).
  - Debajo se muestra un botón discreto: `+ Añadir título en otro idioma` / `+ Añadir serie en otro idioma`.
  - Al pulsar el botón, un menú contextual (`MenuAnchor` o desplegable) permite seleccionar un idioma disponible (ej. Inglés, Español, Romanizado, etc.) y enfocar de inmediato el nuevo campo de texto.

#### B. Asistencia en el Campo `fileAs` de Creadores (`_ActorEditor`)
* **Comportamiento:**
  - El campo `fileAs` mantiene el auto-llenado derivado de `fileAsFor(name)`.
  - Cuando el usuario edita el nombre, `fileAs` se sincroniza automáticamente a menos que haya sido personalizado a mano.
  - Se añade un icono/botón sufijo en `fileAs`:
    - Si coincide con la deducción automática: icono tenue `Icons.auto_mode` con tooltip *"Generado automáticamente a partir del nombre"*.
    - Si fue editado manualmente: botón `IconButton` `Icons.sync` con tooltip *"Restablecer orden automático a '${fileAsFor(name)}'"* para devolverlo al valor calculado.

#### C. Claridad en Tarjetas y Conteo de Pendientes
* Cada sección de `FormSection` muestra de forma destacada el conteo de errores con estilo semántico: `X campos pendientes` o `Requiere atención` cuando haya problemas sin resolver.

---

### 3.2. Pestaña de Imágenes (`images_form.dart`)

#### A. Filtro Rápido de Secciones con Imágenes
* Al inicio de la lista de secciones de imágenes (debajo del bloque de opciones de optimización), incorporar una barra de filtros con `FilterChip`:
  - `Todas (N)`
  - `Ilustraciones a página (N)`: Secciones de tipo `SectionKind.cover`, `SectionKind.illustrations`, etc.
  - `Encabezados de texto (N)`: Secciones de texto con viñeta o imagen en título (`s.headingStyle.usesImage`).
* Al pulsar un chip se filtra la visualización de las secciones correspondientes en el formulario, permitiendo enfocarse en ilustraciones sin desplazarse por todo el libro.

#### B. Asistencia en Opciones de Optimización
* **Modos de calidad:** Debajo del `SegmentedButton<QualityMode>`, incorporar un texto informativo dinámico según la opción seleccionada:
  - `Lossless`: *"Conserva la calidad idéntica sin pérdida; mayor tamaño de archivo."*
  - `Equilibrada` (Balanced): *"Reducción notable del peso visual sin artefactos perceptibles (recomendado para EPUB).*
  - `Máxima` (Smallest): *"Prioriza el menor peso posible, ideal para lectores de tinta electrónica o límites de distribución."*
* **Botón de acción:** Mantener el botón destacado `Optimizar X imágenes pendientes` con indicador de progreso activo si está ejecutándose.

---

### 3.3. Pestaña de Fuentes y CSS (`fonts_form.dart`)

#### A. Mapeo Semántico de Encabezados
* Sustituir la fila abstracta `h1` a `h9` en `_FontCard` por los roles semánticos recomendados para EPUB:
  - `h1` → `h1 · Capítulos y secciones principales`
  - `h2` → `h2 · Subtítulos y partes`
  - `h3` → `h3 · Encabezados menores`
  - *Niveles adicionales (h4–h6):* Disponibles mediante un botón secundario "+ Otros niveles (h4–h6)" para casos avanzados de no-ficción o enciclopedias.

#### B. Muestra Tipográfica Realista
* Sustituir el simple texto `"Título de ejemplo — Capítulo 1"` por un bloque de previsualización integral en la tarjeta de la fuente:
  - **Título:** Texto con estilo titular en la fuente configurada.
  - **Cuerpo de muestra (2-3 líneas):** *"En un rincón apartado de la biblioteca, las páginas del tomo antiguo susurraban historias jamás contadas a la luz tenue de los candiles."*
  - Permite verificar inmediatamente legibilidad tanto en títulos como en texto corrido.

#### C. Botón "Copiar Clase CSS"
* Al lado del nombre de clase generado (`.font-custom-1`), incluir un botón `IconButton(icon: Icon(Icons.copy))` con tooltip *"Copiar clase CSS"*, que copia al portapapeles `.font-...` y muestra un `SnackBar` o feedback visual *"Clase copiada al portapapeles"*.

#### D. Nota Aclaratoria en Editor de CSS Propio
* Añadir un `subtitle` descriptivo en `FormSection`:
  > *"El CSS base del libro ya está generado y preconfigurado automáticamente. Usa este editor únicamente para añadir reglas adicionales o sobrescribir estilos existentes."*

---

## 4. Plan de Verificación y Pruebas (TDD)

1. **Pruebas de Componentes (Widget Tests):**
   * `metadata_form_test.dart`:
     - Comprobar que los idiomas alternativos opcionales están ocultos por defecto y se muestran tras pulsar `+ Añadir otro idioma`.
     - Comprobar que `fileAs` se deduce automáticamente y que el botón de resincronización funciona si se modifica a mano.
   * `images_form_test.dart`:
     - Comprobar que los chips de filtrado (`Todas`, `Ilustraciones`, `Encabezados`) muestran u ocultan las secciones correspondientes.
     - Comprobar que la leyenda explicativa del modo de calidad cambia al seleccionar diferentes modos.
   * `fonts_form_test.dart`:
     - Comprobar que los niveles semánticos de título muestran las etiquetas editoriales (`h1 · Capítulos...`).
     - Comprobar que el botón de copiar clase copia el texto al portapapeles.
     - Comprobar que el texto de muestra de párrafo se renderiza con la familia de fuente configurada.
2. **Pruebas de Regresión:**
   * Ejecutar la suite completa `flutter test` en `ZeeTools` para asegurar que los 90 tests existentes continúan pasando sin fallos.
   * Ejecutar `dart analyze` para asegurar 0 advertencias o errores de tipado.

---

## 5. Criterios de Aceptación

- [ ] Los idiomas alternativos opcionales no saturan la vista de Título y Serie salvo que se soliciten explícitamente.
- [ ] La deducción de `fileAs` es transparente para el usuario y permite restablecerse fácilmente.
- [ ] La pestaña de Imágenes permite filtrar entre ilustraciones completas y encabezados de texto.
- [ ] Las fuentes se asignan a niveles semánticos comprensibles y su muestra tipográfica incluye tanto título como párrafo.
- [ ] La clase de cada fuente puede copiarse con un solo clic.
- [ ] La caja de CSS propio incluye la advertencia contextual clara sobre el CSS base.
- [ ] Toda la suite de pruebas unitarias y de widgets pasa al 100%.
