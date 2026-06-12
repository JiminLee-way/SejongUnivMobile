import 'package:flutter/material.dart';

class OfficialBrandLogo extends StatelessWidget {
  const OfficialBrandLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.color,
    this.colorBlendMode,
    this.fallbackColor,
    this.fallbackColorBlendMode,
    this.filterQuality = FilterQuality.high,
    this.semanticLabel,
    this.excludeFromSemantics = false,
  });

  static const officialAsset = 'assets/images/sejong_logo.png';
  static const fallbackAsset = 'assets/images/app_mark.png';

  final double? width;
  final double? height;
  final BoxFit fit;
  final AlignmentGeometry alignment;
  final Color? color;
  final BlendMode? colorBlendMode;
  final Color? fallbackColor;
  final BlendMode? fallbackColorBlendMode;
  final FilterQuality filterQuality;
  final String? semanticLabel;
  final bool excludeFromSemantics;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      officialAsset,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      color: color,
      colorBlendMode: colorBlendMode,
      filterQuality: filterQuality,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      errorBuilder: (_, _, _) => Image.asset(
        fallbackAsset,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        color: fallbackColor ?? color,
        colorBlendMode: fallbackColorBlendMode ?? colorBlendMode,
        filterQuality: filterQuality,
        semanticLabel: semanticLabel,
        excludeFromSemantics: excludeFromSemantics,
      ),
    );
  }
}
