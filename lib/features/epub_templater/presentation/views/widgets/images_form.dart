import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;

import '/common/theme/app_dimensions.dart';
import '/common/utils/list_toggle.dart';
import '/common/widgets/field_grid.dart';
import '/common/widgets/field_group.dart';
import '/common/widgets/file_drop_button.dart';
import '/common/widgets/form_page.dart';
import '/common/widgets/form_section.dart';
import '/common/widgets/selection_pill.dart';
import '/common/widgets/toggle_field.dart';
import '../../../../image_optimizer/domain/image_format.dart';
import '../../../../image_optimizer/domain/optimization_options.dart';
import '../../../../image_optimizer/presentation/views/widgets/job_status.dart';
import '../../../data/epub_template_builder.dart';
import '../../../domain/section_kind.dart';
import '../../../domain/template_section.dart';
import '../../cubit/epub_templater_cubit.dart';

enum _ImageFilter {
  all('Todas'),
  illustrations('Ilustraciones'),
  headings('Encabezados');

  const _ImageFilter(this.label);
  final String label;
}

class ImagesForm extends StatefulWidget {
  const ImagesForm({super.key});

  @override
  State<ImagesForm> createState() => _ImagesFormState();
}

class _ImagesFormState extends State<ImagesForm> {
  _ImageFilter _filter = _ImageFilter.all;

  @override
  Widget build(BuildContext context) {
    final sections = context.select((EpubTemplaterCubit c) => c.state.project.sections);
    return FormPage(
      showIndex: true,
      sections: [
        FormSection(
          title: 'Optimización',
          icon: Icons.auto_fix_high,
          children: [
            _OptimizationOptions(
              filter: _filter,
              onFilterChanged: (f) => setState(() => _filter = f),
            ),
          ],
        ),
        for (final s in sections)
          if (s.kind.layout == SectionLayout.text && s.headingStyle.usesImage) ...[
            if (_filter == _ImageFilter.all || _filter == _ImageFilter.headings)
              FormSection(
                key: ValueKey(s.key),
                title: '${s.effectiveTocLabel} · ${s.headingStyle.label}',
                icon: Icons.title,
                children: [_HeadingImage(section: s)],
              ),
          ] else if (s.kind.acceptsImages) ...[
            if (_filter == _ImageFilter.all || _filter == _ImageFilter.illustrations)
              FormSection(
                key: ValueKey(s.key),
                title: s.effectiveTocLabel,
                icon: s.kind.singleImage ? Icons.image_outlined : Icons.photo_library_outlined,
                children: [_SectionImages(section: s)],
              ),
          ],
      ],
    );
  }
}

class _OptimizationOptions extends StatelessWidget {
  const _OptimizationOptions({
    required this.filter,
    required this.onFilterChanged,
  });

  final _ImageFilter filter;
  final ValueChanged<_ImageFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final state = context.watch<EpubTemplaterCubit>().state;
    final pending = state.imagePaths.where((path) => state.imageJobs[path] == null).length;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.medium + AppSpacing.small,
      children: [
        FieldGroup(
          label: 'Filtrar secciones',
          child: Wrap(
            spacing: AppSpacing.small,
            children: [
              for (final f in _ImageFilter.values)
                FilterChip(
                  label: Text(f.label),
                  selected: filter == f,
                  onSelected: (_) => onFilterChanged(f),
                ),
            ],
          ),
        ),
        FieldGroup(
          label: 'Formatos permitidos',
          child: SelectionPillGroup(
            options: ImageFormat.outputs,
            selected: state.allowedFormats.contains,
            label: (format) => format.label,
            onTap: (format) => cubit.setAllowedFormats(state.allowedFormats.toggled(format)),
          ),
        ),
        FieldGrid(
          columns: 2,
          minCellWidth: 320,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppSpacing.small,
              children: [
                SegmentedButton<QualityMode>(
                  showSelectedIcon: false,
                  segments: [for (final mode in QualityMode.values) ButtonSegment(value: mode, label: Text(mode.label))],
                  selected: {state.qualityMode},
                  onSelectionChanged: (v) => cubit.setQualityMode(v.first),
                ),
                Text(
                  switch (state.qualityMode) {
                    QualityMode.lossless => 'Sin pérdida: conserva la calidad idéntica del original (archivos más pesados).',
                    QualityMode.visuallyLossless => 'Equilibrada: compresión recomendada para libros digitales sin artefactos perceptibles.',
                  },
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            ToggleField(
              label: 'Permitir cambiar de formato',
              value: state.allowConversion,
              onChanged: cubit.setAllowConversion,
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            icon: state.optimizing ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_fix_high),
            label: Text(state.optimizeStatus ?? (pending == 0 ? 'Imágenes optimizadas' : 'Optimizar $pending imagen${pending == 1 ? '' : 'es'}')),
            onPressed: state.optimizing || pending == 0 ? null : cubit.optimizeImages,
          ),
        ),
      ],
    );
  }
}

Future<List<String>> _pickImages({required bool multiple}) async => (await FilePicker.pickFiles(
  type: FileType.custom,
  allowedExtensions: imageExtensions,
  dialogTitle: multiple ? 'Seleccionar imágenes' : 'Seleccionar imagen',
  windowsOptions: const WindowsOptions(lockParentWindow: true),
  linuxOptions: const LinuxOptions(lockParentWindow: true),
)).map((f) => f.path).whereType<String>().toList();

class const _HeadingImage({required final TemplateSection section}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.medium + AppSpacing.small,
      children: [
        if (section.headingImage.isNotEmpty)
          _ImageRow(
            path: section.headingImage,
            onRemove: () => cubit.updateSection(section.key, (s) => s.copyWith(headingImage: '')),
          ),
        FileDropButton(
          icon: Icons.add_photo_alternate_outlined,
          label: section.headingImage.isEmpty ? 'Elegir imagen…' : 'Cambiar imagen…',
          dropLabel: 'Suelta aquí la imagen',
          extensions: imageExtensions,
          onPick: () async {
            final picked = await _pickImages(multiple: false);
            if (picked.isNotEmpty) cubit.updateSection(section.key, (s) => s.copyWith(headingImage: picked.first));
          },
          onFiles: (files) => cubit.updateSection(section.key, (s) => s.copyWith(headingImage: files.first)),
        ),
      ],
    );
  }
}

class const _SectionImages({required final TemplateSection section}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cubit = context.read<EpubTemplaterCubit>();
    final s = section;
    void update(TemplateSection Function(TemplateSection s) f) => cubit.updateSection(s.key, f);
    void move(int from, int to) => update(
      (s) => s.copyWith(
        images: [...s.images]
          ..removeAt(from)
          ..insert(to, s.images[from]),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppSpacing.medium + AppSpacing.small,
      children: [
        for (final (i, path) in s.images.indexed)
          _ImageRow(
            path: path,
            onUp: s.kind.singleImage || i == 0 ? null : () => move(i, i - 1),
            onDown: s.kind.singleImage || i == s.images.length - 1 ? null : () => move(i, i + 1),
            onRemove: () => update((s) => s.copyWith(images: [...s.images]..removeAt(i))),
          ),
        FileDropButton(
          icon: Icons.add_photo_alternate_outlined,
          label: s.kind.singleImage ? (s.images.isEmpty ? 'Elegir imagen…' : 'Cambiar imagen…') : 'Añadir imágenes…',
          dropLabel: s.kind.singleImage ? 'Suelta aquí la imagen' : 'Suelta aquí las imágenes',
          extensions: imageExtensions,
          onPick: () async {
            final picked = await _pickImages(multiple: !s.kind.singleImage);
            if (picked.isNotEmpty) update((s) => s.copyWith(images: s.kind.singleImage ? [picked.first] : [...s.images, ...picked]));
          },
          onFiles: (files) => update((s) => s.copyWith(images: s.kind.singleImage ? [files.first] : [...s.images, ...files])),
        ),
        if (s.kind.layout == SectionLayout.colophon)
          ToggleField(
            label: 'Incluir logo de ZeePubs',
            value: s.zeepubsLogo,
            onChanged: (v) => update((s) => s.copyWith(zeepubsLogo: v)),
          ),
      ],
    );
  }
}

class const _ImageRow({required final String path, required final VoidCallback onRemove, final VoidCallback? onUp, final VoidCallback? onDown}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final job = context.select((EpubTemplaterCubit c) => c.state.imageJobs[path]);
    final exists = File(path).existsSync();
    return Row(
      spacing: AppSpacing.medium,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.small),
          child: SizedBox.square(
            dimension: AppSize.large,
            child: exists ? Image.file(File(path), fit: BoxFit.cover, cacheWidth: 96) : const Icon(Icons.broken_image_outlined),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.basename(path), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (exists) JobStatus(job: job) else Text('No se encuentra el archivo', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ),
        ),
        if (onUp != null || onDown != null) ...[
          IconButton(tooltip: 'Subir', icon: const Icon(Icons.arrow_upward, size: 18), onPressed: onUp),
          IconButton(tooltip: 'Bajar', icon: const Icon(Icons.arrow_downward, size: 18), onPressed: onDown),
        ],
        IconButton(tooltip: 'Quitar', icon: const Icon(Icons.close, size: 18), onPressed: onRemove),
      ],
    );
  }
}
