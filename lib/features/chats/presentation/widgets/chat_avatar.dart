import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class ChatAvatar extends StatelessWidget {
  const ChatAvatar({
    super.key,
    this.imageUrl,
    this.icon = Icons.person_outline,
    this.radius = 22,
  });

  final String? imageUrl;
  final IconData icon;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.border,
        child: Icon(icon, color: AppColors.grey, size: radius),
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: url,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) =>
            CircleAvatar(radius: radius, backgroundColor: AppColors.border),
        errorWidget: (context, url, error) => CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.border,
          child: Icon(icon, color: AppColors.grey, size: radius),
        ),
      ),
    );
  }
}
