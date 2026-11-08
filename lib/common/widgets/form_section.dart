import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

// Tarjeta con título que agrupa campos relacionados; [issues] cuenta los que tienen algún problema.
class FormSection extends StatelessWidget {
  const FormSection({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
    this.trailing,
    this.issues = 0,
    this.collapsible = false,
    this.initiallyExpanded = true,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final IconData? icon;
  final Widget? trailing;
  final int issues;
  final bool collapsible;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (collapsible) {
      return Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.medium + AppSpacing.small),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.small, AppPadding.large, AppPadding.small),
          childrenPadding: const EdgeInsets.fromLTRB(AppPadding.large, 0, AppPadding.large, AppPadding.large),
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          leading: icon == null
              ? null
              : DecoratedBox(
                  decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(AppRadius.medium)),
                  child: Padding(
                    padding: const EdgeInsets.all(AppPadding.small + AppPadding.tiny),
                    child: Icon(icon, size: 18, color: theme.colorScheme.onSecondaryContainer),
                  ),
                ),
          title: Text(title, style: theme.textTheme.titleMedium),
          subtitle: subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ),
          trailing: trailing == null && issues == 0
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (issues > 0) IssueCount(count: issues),
                    ?trailing,
                    const Icon(Icons.expand_more),
                  ],
                ),
          children: children,
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.medium + AppSpacing.small),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppPadding.large, AppPadding.medium + AppPadding.small, AppPadding.large, AppPadding.large),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppSpacing.medium + AppSpacing.small,
          children: [
            Row(
              spacing: AppSpacing.medium + AppSpacing.small,
              children: [
                if (icon case final icon?)
                  DecoratedBox(
                    decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, borderRadius: BorderRadius.circular(AppRadius.medium)),
                    child: Padding(
                      padding: const EdgeInsets.all(AppPadding.small + AppPadding.tiny),
                      child: Icon(icon, size: 18, color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle case final subtitle?)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
                if (issues > 0) IssueCount(count: issues),
                ?trailing,
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class const IssueCount({super.key, required final int count}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: count == 1 ? 'Un campo por revisar' : '$count campos por revisar',
      child: Badge(label: Text('$count')),
    );
  }
}
