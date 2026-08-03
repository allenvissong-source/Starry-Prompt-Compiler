/// A caller-supplied locale tag used by macros / regex when they need to
/// format numbers or dates deterministically.
///
/// The value is stored verbatim as a string (e.g. `'en_US'`, `'zh_CN'`) rather
/// than parsed, because the prompt compiler must never assume a specific
/// locale library at compile-time; consumers of the tag (typically `intl`) do
/// the parsing themselves.
class LocaleTag {
  const LocaleTag([this.tag = 'en_US']);

  final String tag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LocaleTag && other.tag == tag;

  @override
  int get hashCode => tag.hashCode;

  @override
  String toString() => 'LocaleTag($tag)';
}
