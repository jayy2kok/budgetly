import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../config/theme.dart';
import '../providers/sms_provider.dart';

class SmsConsentDialog extends ConsumerWidget {
  const SmsConsentDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.message_rounded,
            size: 48,
            color: context.colors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Sync Bank Messages',
            textAlign: TextAlign.center,
            style: GoogleFonts.ibmPlexSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: context.colors.textMain,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Budgetly can automatically track your expenses by securely analyzing bank SMS messages. We extract the merchant and amount to categorize your spending. We ignore personal messages.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              height: 1.5,
              color: context.colors.textDim,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () async {
              ref.read(smsProvider.notifier).markConsentPrompted();
              final granted =
                  await ref.read(smsProvider.notifier).requestPermission();
              if (context.mounted) {
                Navigator.of(context).pop();
                if (granted) {
                  ref.read(smsProvider.notifier).syncInboxMessages();
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              'Allow SMS Access',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () {
              ref.read(smsProvider.notifier).markConsentPrompted();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(
              foregroundColor: context.colors.textDim,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              'Not Now',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
