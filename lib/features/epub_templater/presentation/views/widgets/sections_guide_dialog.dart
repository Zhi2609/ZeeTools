import 'package:flutter/material.dart';

import '/common/theme/app_dimensions.dart';
import '../../../domain/section_kind.dart';

class SectionsGuideDialog extends StatelessWidget {
  const SectionsGuideDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => const SectionsGuideDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.large)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: DefaultTabController(
          length: BookMatter.values.length,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.large, AppPadding.large, AppPadding.small),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppPadding.small),
                        child: Icon(Icons.menu_book_outlined, size: 22, color: theme.colorScheme.onPrimaryContainer),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.medium),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guía de secciones del libro', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text(
                            'Función editorial de cada archivo y cuándo conviene incluirlo.',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              TabBar(
                tabs: [
                  for (final matter in BookMatter.values)
                    Tab(text: matter.label),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    for (final matter in BookMatter.values)
                      _MatterSectionsList(matter: matter),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppPadding.medium),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cerrar'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MatterSectionsList extends StatelessWidget {
  const _MatterSectionsList({required this.matter});

  final BookMatter matter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kinds = SectionKind.values.where((k) => k.matter == matter).toList();

    return ListView.separated(
      padding: const EdgeInsets.all(AppPadding.large),
      itemCount: kinds.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.small),
      itemBuilder: (context, i) {
        final kind = kinds[i];
        final distinction = _editorialDistinction(kind);

        return Card(
          elevation: 0,
          color: theme.colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppPadding.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(kind.label, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(width: AppSpacing.small),
                    Text('.xhtml', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        kind.inToc ? 'En el índice' : 'Fuera del índice',
                        style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: theme.colorScheme.outline),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(kind.editorialHelp, style: theme.textTheme.bodyMedium),
                if (distinction != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(AppPadding.small),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, size: 16, color: theme.colorScheme.secondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            distinction,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static String? _editorialDistinction(SectionKind kind) => switch (kind) {
    SectionKind.dedication => 'Diferencia: Es un mensaje íntimo a personas reales. No es parte de la historia ni explica el libro.',
    SectionKind.epigraph => 'Diferencia: Es una cita literaria o frase poética de otro autor para sugerir el tono de la obra.',
    SectionKind.preface => 'Diferencia: Texto directo del autor o editor a los lectores sobre el contexto o elaboración del libro (no ficción).',
    SectionKind.prologue => 'Diferencia: Es el primer capítulo narrativo de la ficción; transcurre antes de los eventos del capítulo 1.',
    SectionKind.notice => 'Diferencia: Obligatorio si la novela toca temas no aptos para menores o sensibles (gore, violencia, etc.).',
    SectionKind.synopsis => 'Diferencia: Resumen comercial similar al de la contraportada para dar contexto antes de empezar.',
    SectionKind.colophon => 'Diferencia: Muestra los logos y créditos del equipo traductor/editorial; suele dejarse fuera del índice.',
    _ => null,
  };
}
