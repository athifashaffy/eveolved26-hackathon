import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class SignaAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final String greeting;
  final bool showAvatar;
  final VoidCallback? onBack;
  final String? title;
  final Widget? trailing;

  const SignaAppBar({
    super.key,
    this.userName = 'Sarah M.',
    this.greeting = 'Welcome back',
    this.showAvatar = true,
    this.onBack,
    this.title,
    this.trailing,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.88),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTint(opacity: 0.06),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 20,
          right: 20,
          bottom: 8),
      child: SizedBox(
        height: 64,
        child: Row(
          children: [
            if (onBack != null)
              GestureDetector(
                onTap: onBack,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.arrow_back_rounded,
                      color: AppColors.primary, size: 24),
                ),
              ),
            if (showAvatar && onBack == null)
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryContainer.withOpacity(0.1),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0] : 'S',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryContainer,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    )
                  else ...[
                    Text(greeting.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.labelUppercase(size: 10)),
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.transparent,
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: AppColors.onSurfaceVariant),
                ),
          ],
        ),
      ),
    );
  }
}
