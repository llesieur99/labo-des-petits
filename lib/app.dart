import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/audio/manifeste_audio.dart';
import 'core/identite.dart';
import 'core/audio/say_kit.dart';
import 'core/micro/mic_kit.dart';
import 'core/parent/reglages.dart';
import 'core/progression/depot.dart';
import 'features/shell/portail_app.dart';
import 'features/shell/shell_controller.dart';
import 'theme/theme_enfant.dart';

/// L'app : les services en Provider, le thème, et le portail.
class JeuxEnfantsApp extends StatefulWidget {
  final Reglages reglages;
  final SayKit say;
  final DepotProgression depot;
  final ShellController shell;
  final Micro micro;

  const JeuxEnfantsApp({
    super.key,
    required this.reglages,
    required this.say,
    required this.depot,
    required this.shell,
    required this.micro,
  });

  @override
  State<JeuxEnfantsApp> createState() => _JeuxEnfantsAppState();
}

class _JeuxEnfantsAppState extends State<JeuxEnfantsApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// L'app ne parle jamais dans la poche du parent : dès qu'elle passe en
  /// arrière-plan, la voix se coupe.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      widget.say.stopper();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<Reglages>.value(value: widget.reglages),
        Provider<SayKit>.value(value: widget.say),
        Provider<RepertoireClips>.value(value: widget.say.repertoire),
        Provider<DepotProgression>.value(value: widget.depot),
        Provider<Micro>.value(value: widget.micro),
        ChangeNotifierProvider<ShellController>.value(value: widget.shell),
      ],
      child: MaterialApp(
        title: Identite.nom,
        debugShowCheckedModeBanner: false,
        theme: themeEnfant(),
        home: const PortailApp(),
      ),
    );
  }
}
