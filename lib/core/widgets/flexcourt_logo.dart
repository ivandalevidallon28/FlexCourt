import 'package:flutter/material.dart';

import '../constants/assets.dart';

class FlexCourtLogo extends StatelessWidget {
  const FlexCourtLogo({
    super.key,
    this.height = 120,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.flexCourtLogo,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'FlexCourt',
    );
  }
}
