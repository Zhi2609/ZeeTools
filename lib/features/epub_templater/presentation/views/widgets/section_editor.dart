import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/theme/app_dimensions.dart';
import '/common/widgets/app_text_field.dart';
import '/common/widgets/confirm_dialog.dart';
import '/common/widgets/form_page.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/outlined_dropdown.dart';
import '/common/widgets/responsive_row.dart';
import '/common/widgets/toggle_field.dart';
import '../../../data/epub_template_builder.dart';
import '../../../domain/section_kind.dart';
import '../../../domain/template_section.dart';
import '../../cubit/epub_templater_cubit.dart';

class SectionEditor extends StatelessWidget {
  const SectionEditor({super.key});

  @override
  Widget build(BuildContext context) {
    final section = context.select((EpubTemplaterCubit c) => c.state.selected);
    if (section == null) return const Center(child: Text('Selecciona o añade una sección.'));
    return _SectionForm(key: ValueKey('${section.key}-${section.kind.name}-${context.select((EpubTemplaterCubit c) => c.state.revision)}'), section: section);
  }
}

class _SectionForm extends StatelessWidget {
  const _SectionForm({super.key, required this.section});

  final TemplateSection section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<EpubTemplaterCubit>();
    final s = section;
    void update(TemplateSection Function(TemplateSection s) f) => cubit.updateSection(s.key, f);
    final isTitlePage = s.kind.layout == SectionLayout.titlePage;

    return FormPage(
      header: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.medium),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                s.matter.label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.medium),
            Expanded(
              child: Text(
                s.effectiveTocLabel.isEmpty ? s.kind.label : s.effectiveTocLabel,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              tooltip: 'Duplicar',
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () => cubit.duplicateSection(s.key),
            ),
            IconButton(
              tooltip: 'Eliminar',
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
              onPressed: () async {
                final confirmed = await confirmAction(
                  context,
                  title: 'Eliminar sección',
                  message: 'Se perderán «${s.effectiveTocLabel}», su configuración y las imágenes asignadas.',
                  confirmLabel: 'Eliminar',
                );
                if (confirmed) cubit.removeSection(s.key);
              },
            ),
          ],
        ),
      ),
      sections: [
        // Tarjeta 1: Qué es esta sección
        FormSection(
          title: 'Qué es esta sección',
          subtitle: 'El tipo decide su lugar y su comportamiento en el libro.',
          icon: Icons.info_outline,
          children: [
            ResponsiveRow(
              children: [
                OutlinedDropdown<SectionKind>(
                  label: 'Tipo',
                  value: s.kind,
                  onChanged: (kind) {
                    if (kind != null && kind != s.kind) cubit.changeKind(s.key, kind);
                  },
                  items: [for (final kind in SectionKind.values) DropdownMenuItem(value: kind, child: Text(kind.label))],
                ),
                AppTextField(
                  label: 'Archivo',
                  value: s.fileName,
                  suffix: const Padding(padding: EdgeInsets.all(AppPadding.medium), child: Text('.xhtml')),
                  error: sanitizeFileName(s.fileName) != s.fileName.trim() ? 'Solo letras, números, «-» y «_»' : null,
                  onChanged: (v) => update((s) => s.copyWith(fileName: v)),
                ),
              ],
            ),
          ],
        ),

        // Tarjeta 2: Cómo se ve en la página
        FormSection(
          title: 'Cómo se ve en la página',
          subtitle: 'Lo que el lector verá al empezar la sección.',
          icon: Icons.auto_stories_outlined,
          children: [
            ResponsiveRow(
              children: [
                AppTextField(
                  label: isTitlePage ? 'Título de la obra' : 'Título visible',
                  value: s.title,
                  hint: isTitlePage ? 'Vacío: el título del libro en su idioma' : null,
                  onChanged: (v) => update((s) => s.copyWith(title: v)),
                ),
                AppTextField(
                  label: isTitlePage ? 'Subtítulo de la obra' : 'Subtítulo',
                  value: s.subtitle,
                  helper: 'Aparece debajo, en letra más pequeña.',
                  onChanged: (v) => update((s) => s.copyWith(subtitle: v)),
                ),
              ],
            ),
            ResponsiveRow(
              children: [
                ToggleField(
                  label: 'Mostrar el título en la página',
                  helper: 'Si lo desmarcas, se oculta visualmente pero se conserva para el índice y lectores de pantalla.',
                  value: !s.hideHeading,
                  onChanged: (show) => update((s) => s.copyWith(hideHeading: !show)),
                ),
                if (s.kind.layout == SectionLayout.text)
                  OutlinedDropdown<HeadingStyle>(
                    label: 'Imagen junto al título',
                    value: s.headingStyle,
                    helper: switch (s.headingStyle) {
                      HeadingStyle.text => 'Ninguna, solo texto.',
                      HeadingStyle.imageBefore || HeadingStyle.imageAfter => 'Adorno pequeño (clase logo) junto al título.',
                      HeadingStyle.imageTitle => 'La imagen sustituye al título visible; el encabezado queda oculto para el índice.',
                      HeadingStyle.separatorPage => 'Se generan dos archivos: el índice apunta a la imagen a página completa y el título visible abre el siguiente.',
                    },
                    onChanged: (v) => update((s) => s.copyWith(headingStyle: v ?? HeadingStyle.text)),
                    items: [for (final style in HeadingStyle.values) DropdownMenuItem(value: style, child: Text(style.label))],
                  ),
              ],
            ),
          ],
        ),

        // Tarjeta Condicional: Advertencia de contenido
        if (s.kind.layout == SectionLayout.notice)
          FormSection(
            title: 'Advertencia de contenido',
            subtitle: 'Aviso para el lector antes de comenzar la obra.',
            icon: Icons.warning_amber_rounded,
            children: [
              OutlinedDropdown<ContentWarning>(
                label: 'Tipo',
                value: s.warning,
                helper: s.warning.text,
                onChanged: (v) => update((s) => s.copyWith(warning: v ?? ContentWarning.explicit)),
                items: [for (final w in ContentWarning.values) DropdownMenuItem(value: w, child: Text(w.label))],
              ),
            ],
          ),

        // Tarjeta 3: Aparece en el índice
        FormSection(
          title: 'Aparece en el índice',
          subtitle: 'La tabla de contenidos del libro.',
          icon: Icons.toc_outlined,
          children: [
            ResponsiveRow(
              flex: isTitlePage ? const [2, 1] : const [2, 4],
              children: [
                ToggleField(
                  label: 'Incluir en el índice',
                  value: s.inToc,
                  helper: isTitlePage ? 'Como «${s.effectiveTocLabel}».' : null,
                  onChanged: (v) => update((s) => s.copyWith(inToc: v)),
                ),
                if (!isTitlePage)
                  AppTextField(
                    label: 'Nombre en el índice',
                    value: s.tocLabel,
                    hint: s.copyWith(tocLabel: '').effectiveTocLabel,
                    helper: 'Vacío: usa el título de la sección. También es el título del documento.',
                    onChanged: (v) => update((s) => s.copyWith(tocLabel: v)),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.small),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Nivel en el índice', style: theme.textTheme.labelMedium),
                const SizedBox(height: AppSpacing.small),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Principal (h1)')),
                    ButtonSegment(value: 2, label: Text('Subnivel (h2)')),
                    ButtonSegment(value: 3, label: Text('Sub-subnivel (h3)')),
                  ],
                  selected: {s.level.clamp(1, 3)},
                  onSelectionChanged: (v) => update((s) => s.copyWith(level: v.first)),
                ),
              ],
            ),
          ],
        ),

        // Tarjeta 4: Opciones avanzadas (Colapsable)
        FormSection(
          title: 'Opciones avanzadas',
          subtitle: 'Tipo semántico (epub:type), división del libro y accesibilidad (ARIA). Ya vienen bien configurados.',
          icon: Icons.tune_outlined,
          collapsible: true,
          initiallyExpanded: false,
          children: [
            const SizedBox(height: AppSpacing.small),
            Text('División del libro', style: theme.textTheme.labelMedium),
            const SizedBox(height: AppSpacing.small),
            SegmentedButton<BookMatter>(
              showSelectedIcon: false,
              segments: [for (final m in BookMatter.values) ButtonSegment(value: m, label: Text(m.label), tooltip: m.epubType)],
              selected: {s.matter},
              onSelectionChanged: (v) => update((s) => s.copyWith(matter: v.first)),
            ),
            const SizedBox(height: AppSpacing.medium),
            ResponsiveRow(
              children: [
                OutlinedDropdown<String>(
                  label: 'epub:type',
                  value: epubTypeRoles.containsKey(s.epubType) ? s.epubType : '',
                  helper: s.role.isEmpty ? 'Sin rol ARIA equivalente' : 'Rol ARIA: ${s.role}',
                  onChanged: (v) => update((s) => s.copyWith(epubType: v ?? '')),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('Ninguno')),
                    for (final type in epubTypeRoles.keys) DropdownMenuItem(value: type, child: Text(type)),
                  ],
                ),
                AppTextField(
                  label: 'Etiqueta ARIA',
                  value: s.ariaLabel,
                  helper: 'Vacío: la sección se etiqueta con su encabezado (aria-labelledby).',
                  onChanged: (v) => update((s) => s.copyWith(ariaLabel: v)),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
