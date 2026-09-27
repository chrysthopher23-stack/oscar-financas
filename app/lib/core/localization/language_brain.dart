import 'app_locale.dart';
import 'brains/pt_br.dart';
import 'brains/en_us.dart';
import 'brains/de_de.dart';
import 'brains/fr_fr.dart';
import 'brains/hi_in.dart';

/// A selected language owns all interface copy. Missing copy is an error,
/// never a request to another language. User data must bypass this class.
final class LanguageBrain {
  const LanguageBrain(this.locale);
  final SupportedAppLocale locale;

  Map<String, String> get messages => switch (locale) {
    SupportedAppLocale.ptBr => ptBrMessages,
    SupportedAppLocale.enUs => enUsMessages,
    SupportedAppLocale.deDe => deDeMessages,
    SupportedAppLocale.frFr => frFrMessages,
    SupportedAppLocale.hiIn => hiInMessages,
  };

  String message(String key, [Map<String, String> arguments = const {}]) {
    final template = messages[key];
    if (template == null) {
      throw StateError('Missing product message in ${locale.tag}: $key');
    }
    return template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (match) {
      final name = match[1]!;
      if (!arguments.containsKey(name)) {
        throw ArgumentError('Missing argument $name for $key');
      }
      return arguments[name]!;
    });
  }

  String reviewedText(String source) {
    if (const {
      'Oscar Finanças',
      'Oscar Score',
      'CoinMarketCap',
      'ETFs',
      'BRL',
      'USD',
      'EUR',
      'INR',
      r'R$',
      r'US$',
      'Plus',
      'Pro',
    }.contains(source)) {
      return source;
    }
    final value = messages[source];
    if (value != null) return value;
    // A widget may receive copy already formatted by this same brain.
    if (messages.values.contains(source)) return source;
    for (final entry in messages.entries.where((e) => e.key.contains('{'))) {
      final names = <String>[];
      final match = _pattern(entry.key, names).firstMatch(source);
      if (match != null) {
        return message(entry.key, {
          for (var i = 0; i < names.length; i++) names[i]: match[i + 1]!,
        });
      }
      if (_pattern(entry.value, []).hasMatch(source)) return source;
    }
    // Numbers, currency symbols and redaction marks have no language content.
    if (RegExp(r'^[\d\s.,:;/()%+−–\-·•₹€$]*$').hasMatch(source)) return source;
    if (RegExp(
      r'^(?:(?:BRL|USD|EUR|INR|R\$|US\$|\$|€|₹)\s*[· ]?\s*)?[\d\s.,+−\-]+\s*(?:BRL|USD|EUR|INR|R\$|US\$|€|\$|₹)?$',
    ).hasMatch(source)) {
      return source;
    }
    throw StateError('Unregistered product copy in ${locale.tag}: $source');
  }

  static RegExp _pattern(String template, List<String> names) {
    var offset = 0;
    final pattern = StringBuffer('^');
    for (final match in RegExp(r'\{(\w+)\}').allMatches(template)) {
      pattern.write(RegExp.escape(template.substring(offset, match.start)));
      pattern.write('(.+?)');
      names.add(match[1]!);
      offset = match.end;
    }
    pattern.write(RegExp.escape(template.substring(offset)));
    pattern.write(r'$');
    return RegExp(pattern.toString(), dotAll: true);
  }
}
