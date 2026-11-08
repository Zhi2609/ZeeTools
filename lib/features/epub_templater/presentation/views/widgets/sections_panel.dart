import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/common/theme/app_dimensions.dart';
import '/common/widgets/toggle_field.dart';
import '../../../domain/section_kind.dart';
import '../../../domain/template_section.dart';
import '../../cubit/epub_templater_cubit.dart';

typedef _Row = ({BookMatter? header, TemplateSection? section});

// Índice de secciones en el orden del spine, agrupado por división. Soltar una
// sección bajo otro separador la cambia de división.
class SectionsPanel extends StatefulWidget {
  const SectionsPanel({super.key});

  @override
  State<SectionsPanel> createState() => _SectionsPanelState();
}

class _SectionsPanelState extends State<SectionsPanel> {
  final Set<BookMatter> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = context.read<EpubTemplaterCubit>();
    final sections = context.select((EpubTemplaterCubit c) => c.state.project.sections);
    final selectedKey = context.select((EpubTemplaterCubit c) => c.state.selectedKey);
    final inTocCount = sections.where((s) => s.inToc).length;

    final rows = <_Row>[
      for (final matter in BookMatter.values) ...[
        (header: matter, section: null),
        if (!_collapsed.contains(matter))
          for (final s in sections.where((s) => s.matter == matter)) (header: null, section: s),
      ],
    ];

    void onReorder(int oldIndex, int newIndex) {
      final moved = rows[oldIndex].section;
      if (moved == null) return;
      final reordered = [...rows];
      reordered.insert(newIndex, reordered.removeAt(oldIndex));
      var matter = BookMatter.front;
      var position = 0;
      for (final row in reordered) {
        if (row.header case final header?) {
          matter = header;
          position = 0;
        } else if (row.section!.key == moved.key) {
          cubit.moveSection(moved.key, matter, position);
          return;
        } else {
          position++;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.medium, AppPadding.medium, AppPadding.small),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Estructura del libro', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text('$inTocCount de ${sections.length} secciones en el índice', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  ),
                  AddSectionButton(onSelected: cubit.addSection),
                ],
              ),
              const SizedBox(height: AppSpacing.small),
              Text(
                'Marca para incluir en el índice. Arrastra :: para reordenar.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppPadding.large, 0, AppPadding.large, AppPadding.medium),
          child: ToggleField(
            label: 'Comentarios de guía',
            value: context.select((EpubTemplaterCubit c) => c.state.project.guideComments),
            onChanged: cubit.setGuideComments,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ReorderableListView.builder(
            buildDefaultDragHandles: false,
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rows.length,
            onReorderItem: onReorder,
            itemBuilder: (context, i) => switch (rows[i]) {
              (header: final matter?, section: _) => _MatterHeader(
                key: ValueKey(matter),
                matter: matter,
                first: i == 0,
                isCollapsed: _collapsed.contains(matter),
                inTocCount: sections.where((s) => s.matter == matter && s.inToc).length,
                totalCount: sections.where((s) => s.matter == matter).length,
                onToggleCollapse: () {
                  setState(() {
                    if (_collapsed.contains(matter)) {
                      _collapsed.remove(matter);
                    } else {
                      _collapsed.add(matter);
                    }
                  });
                },
              ),
              (header: _, section: final s?) => _SectionTile(
                key: ValueKey(s.key),
                section: s,
                index: i,
                selected: s.key == selectedKey,
                onTap: () => cubit.select(s.key),
                onToggleToc: () => cubit.updateSection(s.key, (s) => s.copyWith(inToc: !s.inToc)),
              ),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ],
    );
  }
}

class _MatterHeader extends StatelessWidget {
  const _MatterHeader({
    super.key,
    required this.matter,
    required this.first,
    required this.isCollapsed,
    required this.inTocCount,
    required this.totalCount,
    required this.onToggleCollapse,
  });

  final BookMatter matter;
  final bool first;
  final bool isCollapsed;
  final int inTocCount;
  final int totalCount;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onToggleCollapse,
      child: Padding(
        padding: EdgeInsets.fromLTRB(AppPadding.large, first ? AppPadding.medium : AppPadding.large, AppPadding.large, AppPadding.small),
        child: Row(
          children: [
            Icon(isCollapsed ? Icons.chevron_right : Icons.expand_more, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.small),
            Expanded(
              child: Text(
                '${matter.label.toUpperCase()} · $inTocCount DE $totalCount',
                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddSectionButton extends StatelessWidget {
  const AddSectionButton({super.key, required this.onSelected});

  final ValueChanged<SectionKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SectionKind>(
      tooltip: 'Añadir sección',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final matter in BookMatter.values) ...[
          PopupMenuItem<SectionKind>(enabled: false, height: 32, child: Text(matter.label, style: Theme.of(context).textTheme.labelSmall)),
          for (final kind in SectionKind.values.where((k) => k.matter == matter))
            PopupMenuItem(
              value: kind,
              child: Text(kind.label),
            ),
        ],
      ],
      child: FilledButton.tonalIcon(
        onPressed: null, // PopupMenuButton handles tap
        icon: const Icon(Icons.add, size: 16),
        label: const Text('Añadir'),
      ),
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    super.key,
    required this.section,
    required this.index,
    required this.selected,
    required this.onTap,
    required this.onToggleToc,
  });

  final TemplateSection section;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleToc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = section;
    final isDimmed = !s.inToc;

    return ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -4),
      minVerticalPadding: AppPadding.small,
      selected: selected,
      onTap: onTap,
      contentPadding: EdgeInsets.only(left: AppPadding.medium * s.level.clamp(1, 4), right: AppPadding.small),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Tooltip(
              message: 'Arrastra para reordenar',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(Icons.drag_indicator, size: 18, color: theme.colorScheme.outline),
              ),
            ),
          ),
          Icon(
            Icons.article_outlined,
            size: 18,
            color: isDimmed ? theme.disabledColor : theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      title: Text(
        s.effectiveTocLabel.isEmpty ? s.kind.label : s.effectiveTocLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isDimmed ? TextStyle(color: theme.disabledColor) : null,
      ),
      subtitle: Text(
        '${s.href} · ${s.kind.label}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: isDimmed ? TextStyle(color: theme.disabledColor.withValues(alpha: 0.7)) : null,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!s.inToc) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Text(
                'Omitida del índice',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline, fontSize: 10),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Tooltip(
            message: s.inToc ? 'Quitar del índice' : 'Mostrar en el índice',
            child: Checkbox(
              value: s.inToc,
              onChanged: (_) => onToggleToc(),
            ),
          ),
        ],
      ),
    );
  }
}
