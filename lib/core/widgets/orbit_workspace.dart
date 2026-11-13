import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/orbit_theme.dart';
import '../theme/orbit_motion.dart';

/// The shared Home surface, used by list cards and detail sections.
class OrbitSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  const OrbitSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(12),
      this.margin,
      this.onTap});

  static BoxDecoration get decoration => BoxDecoration(
        color: OrbitColors.cardSurface.withValues(alpha: .94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .72)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1006244D), blurRadius: 16, offset: Offset(0, 5))
        ],
      );

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Container(
        width: double.infinity,
        margin: margin,
        decoration: decoration,
        child: Material(
            type: MaterialType.transparency,
            child: onTap == null
                ? content
                : InkWell(
                    onTap: onTap,
                    borderRadius: BorderRadius.circular(20),
                    child: content)));
  }
}

/// A mountain header over the original WorkHub palette, with a normal Scaffold
/// so keyboard, back navigation, scrolling and floating actions retain their behavior.
class OrbitWorkspaceScaffold extends StatelessWidget {
  final AppBar? appBar;
  final String subtitle;
  final Widget? body, floatingActionButton;
  final Color? backgroundColor;
  final IconData? headerIcon;
  final Color? floatingActionButtonColor;
  const OrbitWorkspaceScaffold(
      {super.key,
      this.appBar,
      this.subtitle = '',
      this.body,
      this.floatingActionButton,
      this.backgroundColor,
      this.headerIcon,
      this.floatingActionButtonColor});

  @override
  Widget build(BuildContext context) {
    final bar = appBar;
    final title = bar?.title;
    final titleWidget = title is Text
        ? Text(title.data ?? title.textSpan?.toPlainText() ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontFamily: 'Roboto',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white))
        : title;
    final theme = Theme.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light),
      child: Stack(fit: StackFit.expand, children: [
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            OrbitColors.primaryNavyDark,
            OrbitColors.scaffoldBackground,
            OrbitColors.scaffoldBackground
          ],
          stops: [0, .45, 1],
        ))),
        Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 250,
            child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0, .58, 1]).createShader(bounds),
                child: Image.asset('assets/images/dashboard_mountains.png',
                    fit: BoxFit.cover, alignment: Alignment.topCenter))),
        Theme(
            data: theme.copyWith(
              floatingActionButtonTheme:
                  theme.floatingActionButtonTheme.copyWith(
                backgroundColor: floatingActionButtonColor,
              ),
              cardTheme: CardThemeData(
                  color: OrbitColors.cardSurface,
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: .72)))),
              inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                fillColor: OrbitColors.cardSurface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: OrbitColors.cardBorder)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: OrbitColors.cardBorder)),
              ),
            ),
            child: Scaffold(
              backgroundColor: backgroundColor ?? Colors.transparent,
              appBar: bar == null
                  ? null
                  : AppBar(
                      key: bar.key,
                      toolbarHeight: (subtitle.isEmpty ? 60.0 : 72.0) +
                          (MediaQuery.textScalerOf(context).scale(20) - 20)
                              .clamp(0, 40),
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0,
                      scrolledUnderElevation: 0,
                      systemOverlayStyle: const SystemUiOverlayStyle(
                          statusBarColor: Colors.transparent,
                          statusBarIconBrightness: Brightness.light),
                      automaticallyImplyLeading: bar.automaticallyImplyLeading,
                      leadingWidth: bar.leadingWidth,
                      leading: (bar.leading == null
                              ? null
                              : Center(
                                  child: SizedBox(
                                      height: 48, child: bar.leading))) ??
                          (headerIcon == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.only(
                                      left: 12, top: 12, bottom: 12),
                                  child: DecoratedBox(
                                      decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: .10),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: .25))),
                                      child: Icon(headerIcon,
                                          color: Colors.white, size: 24)))),
                      title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (titleWidget != null) titleWidget,
                            if (subtitle.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(subtitle,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontFamily: 'Roboto',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w400,
                                      height: 1.2,
                                      color: Colors.white70))
                            ]
                          ]),
                      actions: bar.actions,
                      bottom: bar.bottom,
                    ),
              floatingActionButton: floatingActionButton,
              body: body == null ? null : OrbitEntrance(child: body!),
            )),
      ]),
    );
  }
}

/// Detail screens share surfaces while preserving the supplied fields, controls
/// and discussion widgets in their original order.
class OrbitDetailList extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  const OrbitDetailList(
      {super.key,
      required this.children,
      this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 28)});

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[];
    var group = <Widget>[];
    void flush() {
      while (group.isNotEmpty && group.first is SizedBox) {
        group.removeAt(0);
      }
      while (group.isNotEmpty && group.last is SizedBox) {
        group.removeLast();
      }
      if (group.isEmpty) return;
      sections.add(OrbitSurface(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: group)));
      sections.add(const SizedBox(height: 12));
      group = <Widget>[];
    }

    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      if (i == 0 && child is Container) {
        sections.add(child);
        sections.add(const SizedBox(height: 12));
      } else if (child is Divider) {
        flush();
      } else {
        group.add(child);
      }
    }
    flush();
    return SingleChildScrollView(
        padding: padding,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: sections));
  }
}
