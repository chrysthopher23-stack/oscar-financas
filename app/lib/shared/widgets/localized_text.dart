import 'package:flutter/material.dart' as material;

import '../../core/localization/app_locale.dart';
import '../../core/localization/language_brain.dart';

/// Drop-in localized text for product copy. User-entered and unknown strings are
/// preserved exactly; only reviewed product phrases are translated.
final class Text extends material.StatelessWidget {
  const Text(
    this.data, {
    super.key,
    this.translate = true,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  final String data;
  final bool translate;
  final material.TextStyle? style;
  final material.StrutStyle? strutStyle;
  final material.TextAlign? textAlign;
  final material.TextDirection? textDirection;
  final material.Locale? locale;
  final bool? softWrap;
  final material.TextOverflow? overflow;
  final material.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final material.TextWidthBasis? textWidthBasis;
  final material.TextHeightBehavior? textHeightBehavior;
  final material.Color? selectionColor;

  @override
  material.Widget build(material.BuildContext context) => material.Text(
    translate ? uiText(context, data) : data,
    style: style,
    strutStyle: strutStyle,
    textAlign: textAlign,
    textDirection: textDirection,
    locale: locale,
    softWrap: softWrap,
    overflow: overflow,
    textScaler: textScaler,
    maxLines: maxLines,
    semanticsLabel: semanticsLabel == null
        ? null
        : uiText(context, semanticsLabel!),
    textWidthBasis: textWidthBasis,
    textHeightBehavior: textHeightBehavior,
    selectionColor: selectionColor,
  );
}

String uiText(material.BuildContext context, String source) => uiTextForLocale(
  SupportedAppLocale.resolve(material.Localizations.localeOf(context)),
  source,
);

String uiTextForLocale(SupportedAppLocale locale, String source) =>
    LanguageBrain(locale).reviewedText(source);
