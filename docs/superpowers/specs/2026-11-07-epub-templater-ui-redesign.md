# Especificación de Diseño: Rediseño de la Interfaz de Plantillas EPUB (Fase 1)

**Fecha:** 2026-11-07  
**Estado:** Propuesta aprobada en Brainstorming  
**Módulo:** `features/epub_templater`  
**Objetivo:** Rediseñar la experiencia de usuario del creador de plantillas EPUB en ZeeTools, eliminando la sobrecarga cognitiva mediante divulgación progresiva (*progressive disclosure*), acciones explícitas con texto visible, preajuste inicial de Novela Ligera y organización modular en tarjetas.

---

## 1. Contexto y Justificación

Actualmente, el módulo de Plantillas EPUB presenta dificultades para los usuarios:
* **Iconos mudos y ambiguos:** En la barra de perfiles y en las filas de las secciones hay botones de acción sin texto visible ni ayuda descriptiva (el icono del ojo no explicaba claramente si la sección era omitida del libro o del índice).
* **Sobrecarga de información:** El editor de secciones muestra simultáneamente configuraciones elementales junto a configuraciones avanzadas de accesibilidad (ARIA, `epub:type`, divisiones de libro).
* **Configuración inicial abrumadora:** Al arrancar se cargaban hasta 18-23 secciones por defecto, obligando a los usuarios de novelas ligeras y obras comunes a depurar decenas de campos antes de empezar.
* **Acciones críticas escondidas:** El botón fundamental "Generar EPUB" dependía de un SpeedDial/FAB flotante que no ofrecía una visibilidad clara del flujo de trabajo.

---

## 2. Alcance (Fase 1: Secciones y Barra Superior)

Esta primera fase aborda:
1. **Preajuste inicial de proyecto:** Configuración inicial limpia y orientada a novelas ligeras.
2. **Barra superior de perfiles y acciones globales:** Botones visibles con etiquetas, confirmación para acciones destructivas y botón primario destacado "Generar EPUB".
3. **Panel de Estructura del Libro (Columna Izquierda):** Acordeones colapsables por división, indicador semántico para inclusión en el índice de contenidos (`inToc`), badge `Omitida del índice` y botón destacado `+ Añadir sección`.
4. **Editor de Sección Modular (Columna Derecha):** Cuatro tarjetas temáticas (*Qué es esta sección*, *Cómo se ve en la página*, *Aparece en el índice* y *Opciones avanzadas* colapsable).

*(Las fases posteriores abordarán los rediseños específicos de las pestañas Metadatos, Imágenes y Fuentes/CSS).*

---

## 3. Especificación Detallada de Componentes

### 3.1. Preset Inicial por Defecto (`TemplateProject.initial()`)
* **Archivo:** `lib/features/epub_templater/domain/template_project.dart`
* **Comportamiento:**
  * Al iniciar un nuevo proyecto o invocar "Restablecer todo", la plantilla contendrá únicamente las 8 secciones representativas de una novela ligera:
    1. **Cubierta** (`SectionKind.cover`)
    2. **Ilustraciones** (`SectionKind.illustrations`)
    3. **Página de título / Portadilla** (`SectionKind.titlePage`)
    4. **Prólogo** (`SectionKind.prologue`)
    5. **Capítulo 1** (`SectionKind.chapter`, n.º 1)
    6. **Capítulo 2** (`SectionKind.chapter`, n.º 2)
    7. **Epílogo** (`SectionKind.epilogue`)
    8. **Palabras del autor** (`SectionKind.afterword`)
  * `TemplateProject.allSections()` se mantendrá disponible internamente para casos avanzados o pruebas.

### 3.2. Barra Superior y Acciones Globales (`ProfileBar` y `EpubTemplaterView`)
* **Archivos:**
  * `lib/features/epub_templater/presentation/views/widgets/profile_bar.dart`
  * `lib/features/epub_templater/presentation/views/epub_templater_view.dart`
* **Componentes y Comportamiento:**
  1. **Selector de Perfil:**
     * `TextField` con `MenuAnchor` para seleccionar un perfil guardado o ingresar uno nuevo.
     * Botón con texto **`Abrir perfil`** (icono `Icons.folder_open_outlined`): solo habilitado si el nombre corresponde a un perfil existente.
     * Botón con texto **`Guardar perfil`** (icono `Icons.save_outlined`): habilitado si hay texto escrito en el campo.
  2. **Acciones de Soporte (con Tooltip explícito):**
     * `IconButton` **`Importar metadatos de un EPUB`** (`Icons.upload_file_outlined`).
     * `IconButton` **`Abrir carpeta de perfiles`** (`Icons.folder_shared_outlined`).
     * `IconButton` **`Restablecer plantilla`** (`Icons.restart_alt`): solicita diálogo de confirmación antes de restablecer al preset de Novela Ligera.
     * `IconButton` **`Eliminar perfil`** (`Icons.delete_outline`): separado a la derecha con estilo visual de advertencia, habilitado solo cuando el perfil existe y con confirmación obligatoria.
  3. **Acción Principal destacada ("Generar EPUB"):**
     * Se coloca en la barra superior como un `FilledButton.icon` (`Icons.save_alt`, texto "Generar EPUB").
     * Si `generating == true`, muestra un spinner circular o estado de carga deshabilitado.
     * Elimina la dependencia del FAB/SpeedDial flotante de la vista para este flujo.

### 3.3. Panel de Estructura del Libro (`SectionsPanel`)
* **Archivo:** `lib/features/epub_templater/presentation/views/widgets/sections_panel.dart`
* **Componentes y Comportamiento:**
  1. **Cabecera del Panel:**
     * Título "Estructura del libro" con contador general (ej. `7 de 8 secciones en el índice`).
     * Botón destacado `+ Añadir` con desplegable organizado por división (`BookMatter`).
     * Texto orientativo tenue: *"Las secciones desmarcadas se generan en el libro pero no aparecen en el índice de contenidos. Arrastra :: para reordenar."*
  2. **Agrupación en Paneles Colapsables:**
     * Las secciones se agrupan bajo sus tres divisiones canónicas:
       * `PRELIMINARES`
       * `CUERPO DE LA OBRA`
       * `PÁGINAS FINALES`
     * Cada división se presenta con encabezado tipo acordeón (`ExpansionTile` o similar) mostrando el conteo parcial (ej. `CUERPO DE LA OBRA · 2 DE 2`).
  3. **Elementos de Sección (`_SectionTile`):**
     * Asidero para reordenar `::` (`ReorderableDragStartListener`) con tooltip *"Arrastra para reordenar"*.
     * Icono representativo del layout de la sección.
     * Título visible y nombre del archivo (ej. `capitulo01.xhtml`).
     * Control de índice (`inToc`):
       * `inToc == true`: Checkbox seleccionado `[✓]` con tooltip *"Incluida en el índice de contenidos"*.
       * `inToc == false`: Checkbox desmarcado `[ ]`, badge visual tipo pill `Omitida del índice` y texto de la fila ligeramente atenuado para dar feedback inmediato.

### 3.4. Editor de la Sección Seleccionada (`SectionEditor`)
* **Archivo:** `lib/features/epub_templater/presentation/views/widgets/section_editor.dart`
* **Componentes y Comportamiento:**
  1. **Encabezado del Editor:**
     * Subtítulo con la división (`matter.label`) y el título actual en tamaño destacado.
     * Acciones: Botón `Duplicar` y botón `Eliminar sección` (con confirmación).
  2. **Tarjeta 1: "Qué es esta sección"**
     * Subtítulo: *"El tipo decide su lugar y su comportamiento en el libro."*
     * `Tipo`: Selector desplegable de `SectionKind`.
     * `Nombre del archivo`: Campo de texto con sufijo `.xhtml` y saneamiento/validación de caracteres no válidos.
  3. **Tarjeta 2: "Cómo se ve en la página"**
     * Subtítulo: *"Lo que el lector verá al empezar la sección."*
     * `Título`: Título visible en el encabezado.
     * `Subtítulo (opcional)`: Texto secundario.
     * `Imagen junto al título`: Selector desplegable (`HeadingStyle`: ninguna, adorno anterior/posterior, imagen como título).
     * Checkbox `Mostrar el título en la página`: Con ayuda explicativa *"Si lo desmarcas, se oculta visualmente pero se conserva para el índice y lectores de pantalla"*.
  4. **Tarjeta 3: "Aparece en el índice"**
     * Subtítulo: *"La tabla de contenidos del libro."*
     * Checkbox `Incluir en el índice` (sincronizado bidireccionalmente con `s.inToc`).
     * `Nombre en el índice`: Campo de texto con placeholder tenue del título actual y ayuda *"Vacío: usa el título de la sección"*.
     * `Nivel en el índice`: Selector segmentado (`SegmentedButton` o tabs de opciones):
       * `Principal (h1)` (Nivel 1)
       * `Subnivel (h2)` (Nivel 2)
       * `Sub-subnivel (h3)` (Nivel 3)
       *(Permitiendo compatibilidad con niveles 4–6 si un perfil existente los contiene).*
  5. **Tarjeta 4: "Opciones avanzadas" (Colapsable / `ExpansionTile`, cerrado por defecto)**
     * Subtítulo: *"Tipo semántico (epub:type), división del libro y accesibilidad (ARIA). Ya vienen bien configurados por defecto."*
     * Selector desplegable `epub:type`.
     * Selector de `División del libro` (`BookMatter`).
     * Campo `Etiqueta ARIA` con texto de ayuda.
  6. **Tarjeta Condicional de Advertencia:**
     * Aparece únicamente si el layout es de aviso (`SectionLayout.notice`), permitiendo seleccionar el tipo de advertencia de contenido.

---

## 4. Estrategia de Pruebas y Verificación

1. **Pruebas Unitarias de Dominio:**
   * Verificar que `TemplateProject.initial()` inicializa con las 8 secciones de Novela Ligera y los niveles correctos.
   * Verificar que `TemplateProject.allSections()` sigue conteniendo todas las secciones para pruebas y migraciones.
2. **Pruebas de Widgets (`test/epub_templater_view_test.dart` y `test/section_editor_test.dart`):**
   * Actualizar pruebas que interactúen con la barra de perfiles y verificar los botones con texto visible.
   * Verificar que al pulsar el checkbox del índice en una sección, se actualice el estado `inToc` y se muestre la badge `Omitida del índice`.
   * Verificar que el bloque "Opciones avanzadas" esté colapsado inicialmente y se despliegue al interactuar.
   * Verificar que el botón "Generar EPUB" invoque la generación de la plantilla.
3. **Ejecución de la Suite Completa:**
   * Garantizar que `flutter test` pase al 100% sin regresiones.
