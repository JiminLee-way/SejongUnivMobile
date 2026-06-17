import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:sejong_smart_campus/core/theme/app_tokens.dart';
import 'package:sejong_smart_campus/core/theme/app_typography.dart';
import 'package:sejong_smart_campus/features/library/domain/entities/seat_reservation.dart';
import 'package:sejong_smart_campus/shared/widgets/glass_card.dart';
import 'package:sejong_smart_campus/shared/widgets/shimmer.dart';

/// 좌석 예약 카드 — 홈/도서관 양쪽에서 동일 디자인으로 사용.
///
/// owner: features/library (좌석 도메인의 일부)
/// consumers: features/home, features/library
///
/// [header]는 카드 상단에 얹는 선택적 컨텍스트 한 줄 (홈에서는 "다음 강의"
/// 라인). 라이브러리 화면에서는 null로 두고 좌석 정보만 노출.
class SeatCard extends StatelessWidget {
  const SeatCard({
    super.key,
    required this.reservation,
    this.header,
    this.onReturn,
    this.onExtend,
    this.busy = false,
  });
  final SeatReservation reservation;
  final Widget? header;
  final bool busy;

  /// 반납 버튼 핸들러. null이면 버튼이 비활성(탭 무시).
  final VoidCallback? onReturn;

  /// 연장 버튼 핸들러. null이면 버튼이 비활성(탭 무시).
  final VoidCallback? onExtend;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderRadius: 24,
      // 헤더가 있을 때(홈 hero) 위 패딩을 22로 — 아래 22 갭과 대칭이 되어
      // "다음 강의" 라인이 외측 보더와 InnerGlassPanel 상단 보더의 정중앙에
      // 위치. 라이브러리 목록 사용처(헤더 없음)는 기본 16 패딩 유지.
      padding: header != null
          ? const EdgeInsets.fromLTRB(16, 22, 16, 16)
          : const EdgeInsets.all(16),
      child: Stack(
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // GlassCard 위 패딩 22와 대칭 — 헤더가 외측 보더와 InnerGlassPanel
              // 상단 보더의 정중앙. flip 버튼(top:22+size:36 = bottom 58)과 inner
              // panel(top: 22+16+22 = 60) 클리어런스도 함께 확보.
              if (header != null) ...[header!, const SizedBox(height: 22)],
              InnerGlassPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Symbols.chair_alt,
                          fill: 1,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reservation.roomName,
                            style: AppTypography.labelMd,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // RepaintBoundary로 페이드 무한 반복이 상위 카드의
                        // 다른 영역을 매 프레임 invalidate하지 않게 격리.
                        RepaintBoundary(
                          child:
                              Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '이용중',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.onPrimary,
                                      ),
                                    ),
                                  )
                                  .animate(
                                    onPlay: (c) => c.repeat(reverse: true),
                                  )
                                  .fade(
                                    begin: 1,
                                    end: 0.55,
                                    duration: 2000.ms,
                                    curve: Curves.easeInOut,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '남은 시간',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              busy
                                  ? const _CountdownSkeleton()
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: _CountdownText(
                                        reservation: reservation,
                                      ),
                                    ),
                            ],
                          ),
                        ),
                        _OutlinedButton(
                          label: '반납',
                          onTap: busy ? null : onReturn,
                        ),
                        const SizedBox(width: 8),
                        _PrimaryButton(
                          label: '연장',
                          onTap: busy ? null : onExtend,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 매초 자기 자신만 setState하는 leaf — 부모 카드/리스트는 rebuild 안 함.
class _CountdownText extends StatefulWidget {
  const _CountdownText({required this.reservation});
  final SeatReservation reservation;

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _format(widget.reservation.remaining(DateTime.now())),
      style: AppTypography.timer,
      maxLines: 1,
    );
  }
}

class _CountdownSkeleton extends StatelessWidget {
  const _CountdownSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4, bottom: 2),
      child: Shimmer(child: ShimmerBox(width: 150, height: 34, radius: 10)),
    );
  }
}

EdgeInsets _compactButtonPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w < 380
      ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
      : const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
}

class _OutlinedButton extends StatelessWidget {
  const _OutlinedButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: _compactButtonPadding(context),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(label, style: AppTypography.labelMd),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: _compactButtonPadding(context),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.2),
              offset: const Offset(0, 1),
              blurRadius: 0,
            ),
          ],
        ),
        child: Text(
          label,
          style: AppTypography.labelMd.copyWith(color: AppColors.onPrimary),
        ),
      ),
    );
  }
}
