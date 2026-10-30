import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../application/app_info_loader.dart';

class AppInfoScreen extends StatefulWidget {
  const AppInfoScreen({super.key, required this.loader});
  final AppInfoLoader loader;

  @override
  State<AppInfoScreen> createState() => _AppInfoScreenState();
}

class _AppInfoScreenState extends State<AppInfoScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.loader.load());
  }

  @override
  void dispose() {
    unawaited(widget.loader.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(text.appTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: StreamBuilder<AppInfoState>(
            stream: widget.loader.states,
            initialData: widget.loader.state,
            builder: (context, snapshot) {
              final state = snapshot.requireData;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.appInformation,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 24),
                  if (state.phase == AppInfoPhase.idle ||
                      state.phase == AppInfoPhase.loading)
                    Text(text.loading, semanticsLabel: text.loading),
                  if (state.info case final info?) ...[
                    Text(info.appName),
                    Text('${text.versionLabel}: ${info.version}'),
                    Text('${text.buildLabel}: ${info.buildNumber}'),
                    Text('${text.applicationIdLabel}: ${info.applicationId}'),
                  ],
                  if (state.phase == AppInfoPhase.unavailable) ...[
                    Text(text.unavailable, semanticsLabel: text.unavailable),
                    const SizedBox(height: 16),
                    Semantics(
                      label: text.retrySemanticLabel,
                      button: true,
                      child: ExcludeSemantics(
                        child: FilledButton(
                          onPressed: widget.loader.retry,
                          child: Text(text.retry),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
