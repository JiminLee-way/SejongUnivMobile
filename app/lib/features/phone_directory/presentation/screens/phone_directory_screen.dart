import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/phone_directory/domain/entities/phone_directory_models.dart';
import 'package:sejong_smart_campus/features/phone_directory/presentation/providers/phone_directory_providers.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/mesh_background.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_refresh.dart';
import 'package:sejong_smart_campus/shared/widgets/sejong_sub_app_bar.dart';

/// 교내 전화번호 — 학과사무실 브라우즈(기본) + 교직원 실시간 검색(검색어 입력 시).
///
/// 검색어가 비어 있으면 Supabase 학과사무실을 단과대학별로 보여주고, 입력되면
/// sjapp 교직원 검색으로 전환한다. 행 탭 → 다이얼러(tel:).
class PhoneDirectoryScreen extends ConsumerStatefulWidget {
  const PhoneDirectoryScreen({super.key});

  @override
  ConsumerState<PhoneDirectoryScreen> createState() =>
      _PhoneDirectoryScreenState();
}

class _PhoneDirectoryScreenState extends ConsumerState<PhoneDirectoryScreen> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;

  /// 확정된 검색어(디바운스 후). 빈 문자열이면 브라우즈 모드.
  String _keyword = '';
  PhoneSearchType _type = PhoneSearchType.all;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _commit(value);
    });
  }

  void _commit(String value) {
    final next = value.trim();
    if (next == _keyword) return;
    setState(() => _keyword = next);
  }

  void _submit() {
    _debounce?.cancel();
    _commit(_ctrl.text);
  }

  void _clear() {
    _debounce?.cancel();
    _ctrl.clear();
    if (_keyword.isEmpty) return;
    setState(() => _keyword = '');
  }

  void _setType(PhoneSearchType type) {
    if (type == _type) return;
    setState(() => _type = type);
  }

  Future<void> _onRefresh() async {
    if (_keyword.isEmpty) {
      ref.invalidate(deptOfficesProvider);
      await ref
          .read(deptOfficesProvider.future)
          .catchError((_) => <DeptOffice>[]);
    } else {
      final query = (keyword: _keyword, type: _type);
      ref.invalidate(staffSearchProvider(query));
      await ref
          .read(staffSearchProvider(query).future)
          .catchError((_) => StaffSearchResult.empty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final searching = _keyword.isNotEmpty;
    final topInset = SejongSubAppBar.heightFor(context);
    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      body: MeshBackground(
        child: Stack(
          children: [
            Positioned.fill(
              child: SejongRefresh(
                onRefresh: _onRefresh,
                topInset: topInset,
                child: ListView(
                  padding: EdgeInsets.only(
                    top: topInset + 12,
                    bottom: 40 + MediaQuery.paddingOf(context).bottom,
                  ),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.marginMobile,
                      ),
                      child: _SearchField(
                        controller: _ctrl,
                        onChanged: _onChanged,
                        onSubmit: _submit,
                        onClear: _clear,
                      ),
                    ),
                    // 유형 칩은 검색 중에만 — 브라우즈 모드에선 학과사무실 목록이
                    // _type을 안 쓰므로 칩이 보이면 '눌러도 안 먹는' 죽은 컨트롤이 된다.
                    if (searching) ...[
                      const SizedBox(height: 12),
                      _TypeChips(selected: _type, onSelect: _setType),
                      const SizedBox(height: 16),
                      _StaffResults(keyword: _keyword, type: _type),
                    ] else ...[
                      const SizedBox(height: 16),
                      const _OfficeBrowse(),
                    ],
                  ],
                ),
              ),
            ),
            const Align(
              alignment: Alignment.topCenter,
              child: SejongSubAppBar(title: '교내 전화번호'),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════ 검색 입력 ═══════════════════════════════

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmit,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: (_) => onSubmit(),
      style: AppTypography.bodyMd,
      decoration: InputDecoration(
        hintText: '이름·학과·전화번호 검색',
        hintStyle: AppTypography.bodyMd.copyWith(
          color: AppColors.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIcon: const Icon(
          Symbols.search,
          size: 20,
          color: AppColors.secondary,
        ),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Symbols.close, size: 20),
              color: AppColors.secondary,
              tooltip: '지우기',
              onPressed: onClear,
            );
          },
        ),
        filled: true,
        fillColor: AppColors.surfaceContainerLow.withValues(alpha: 0.85),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _TypeChips extends StatelessWidget {
  const _TypeChips({required this.selected, required this.onSelect});

  final PhoneSearchType selected;
  final ValueChanged<PhoneSearchType> onSelect;

  @override
  Widget build(BuildContext context) {
    const types = PhoneSearchType.values;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.marginMobile,
        ),
        itemCount: types.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = types[i];
          final sel = type == selected;
          return Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => onSelect(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary
                      : Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  border: Border.all(
                    color: sel
                        ? AppColors.primary
                        : AppColors.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  type.label,
                  style: AppTypography.labelMd.copyWith(
                    color: sel ? AppColors.onPrimary : AppColors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════ 학과사무실 브라우즈 ═══════════════════════════

class _OfficeBrowse extends ConsumerWidget {
  const _OfficeBrowse();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deptOfficesProvider);
    return async.when(
      loading: () => const _LoadingBlock(),
      error: (e, _) =>
          const _MessageBlock(icon: Symbols.error, text: '학과사무실 정보를 불러오지 못했어요'),
      data: (offices) {
        if (offices.isEmpty) {
          return const _MessageBlock(icon: Symbols.info, text: '표시할 번호가 없어요');
        }
        // 단과대학별 그룹 + 특별사무실 분리. (sort_order가 단과대학별로 연속이라
        // 첫 등장 순서를 그대로 쓰면 시드된 순서가 유지된다.)
        final byCollege = <String, List<DeptOffice>>{};
        final specials = <DeptOffice>[];
        for (final o in offices) {
          if (o.isSpecial) {
            specials.add(o);
          } else {
            (byCollege[o.college ?? '기타'] ??= <DeptOffice>[]).add(o);
          }
        }
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in byCollege.entries) ...[
                _SectionHeader(title: entry.key),
                const SizedBox(height: 8),
                _PhoneCard(
                  rows: [
                    for (final o in entry.value)
                      _PhoneRowData(
                        title: o.department,
                        subtitle: o.subMajor,
                        phone: o.phone,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (specials.isNotEmpty) ...[
                const _SectionHeader(title: '특별 사무실'),
                const SizedBox(height: 8),
                _PhoneCard(
                  rows: [
                    for (final o in specials)
                      _PhoneRowData(
                        title: o.department,
                        subtitle: o.subMajor,
                        phone: o.phone,
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════ 교직원 검색 결과 ═══════════════════════════

class _StaffResults extends ConsumerWidget {
  const _StaffResults({required this.keyword, required this.type});

  final String keyword;
  final PhoneSearchType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      staffSearchProvider((keyword: keyword, type: type)),
    );
    return async.when(
      loading: () => const _LoadingBlock(),
      error: (e, _) =>
          const _MessageBlock(icon: Symbols.error, text: '검색 중 문제가 생겼어요'),
      data: (result) {
        if (result.contacts.isEmpty) {
          return const _MessageBlock(
            icon: Symbols.search_off,
            text: '검색 결과가 없어요',
          );
        }
        // 소속 학과별로 묶는다(첫 등장 순서 유지).
        final byDept = <String, List<StaffContact>>{};
        for (final c in result.contacts) {
          final key = c.department.isEmpty ? '기타' : c.department;
          (byDept[key] ??= <StaffContact>[]).add(c);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.marginMobile,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ResultCount(
                total: result.total,
                shown: result.contacts.length,
                hasMore: result.hasMore,
              ),
              const SizedBox(height: 12),
              for (final entry in byDept.entries) ...[
                _SectionHeader(title: entry.key),
                const SizedBox(height: 8),
                _PhoneCard(
                  rows: [
                    for (final c in entry.value)
                      _PhoneRowData(
                        title: c.name,
                        subtitle: c.position.isEmpty ? null : c.position,
                        phone: c.phone,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ResultCount extends StatelessWidget {
  const _ResultCount({
    required this.total,
    required this.shown,
    required this.hasMore,
  });

  final int total;
  final int shown;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    final text = hasMore ? '검색 결과 $total명 중 $shown명' : '검색 결과 $total명';
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: AppTypography.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

// ═══════════════════════════ 공통 카드/행/상태 ═══════════════════════════

/// 한 행의 표시 데이터. 학과사무실/교직원 둘 다 같은 행 위젯을 쓴다.
class _PhoneRowData {
  const _PhoneRowData({
    required this.title,
    this.subtitle,
    required this.phone,
  });

  final String title;
  final String? subtitle;
  final String phone;
}

class _PhoneCard extends StatelessWidget {
  const _PhoneCard({required this.rows});

  final List<_PhoneRowData> rows;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: AppRadius.lg,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const _RowDivider(),
            _PhoneRow(data: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.data});

  final _PhoneRowData data;

  @override
  Widget build(BuildContext context) {
    final subtitle = data.subtitle;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _dial(context, data.phone),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Flexible(
                      child: Text(
                        data.title,
                        style: AppTypography.headlineMd.copyWith(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          subtitle,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11.5,
                            letterSpacing: 0,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                data.phone,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Symbols.call,
                size: 18,
                color: AppColors.primary,
                fill: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.outline.withValues(alpha: 0.12),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: AppTypography.labelMd.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 56,
        horizontal: AppSpacing.marginMobile,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 전화번호로 다이얼러를 연다. tel: 스킴은 다이얼러가 없는 기기(에뮬레이터/태블릿)
/// 에서 launchUrl이 false를 반환하거나 예외를 던질 수 있어 둘 다 처리한다.
Future<void> _dial(BuildContext context, String rawPhone) async {
  final digits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (digits.isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  void fail() =>
      messenger?.showSnackBar(const SnackBar(content: Text('전화 앱을 열 수 없어요')));
  try {
    final ok = await launchUrl(
      Uri(scheme: 'tel', path: digits),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) fail();
  } catch (_) {
    fail();
  }
}
