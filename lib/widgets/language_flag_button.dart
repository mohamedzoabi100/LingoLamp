import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/language_provider.dart';

/// Language picker button that displays the current language flag
class LanguageFlagButton extends StatelessWidget {
  const LanguageFlagButton({super.key});

  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();

    return IconButton(
      tooltip: 'Change language',
      icon: Text(
        languageProvider.currentLanguageFlag,
        style: const TextStyle(fontSize: 22),
      ),
      onPressed: () => _openLanguageSheet(context),
    );
  }

  void _openLanguageSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _LanguageSelectionSheet(),
    );
  }
}

/// Bottom sheet for language selection
class _LanguageSelectionSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final languageProvider = context.watch<LanguageProvider>();
    final supportedLanguages = LanguageProvider.getSupportedLanguages();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.language, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Select Language',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: supportedLanguages.length,
              itemBuilder: (context, index) {
                final entry = supportedLanguages[index];
                final languageCode = entry.key;
                final languageData = entry.value;
                final isCurrent = languageCode == languageProvider.currentLanguage;

                return ListTile(
                  leading: Text(
                    languageData['flag']!,
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(
                    languageData['name']!,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: isCurrent 
                    ? Icon(Icons.check, color: Theme.of(context).primaryColor)
                    : null,
                  onTap: () async {
                    await languageProvider.setLanguage(languageCode);
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 