/// The words of a typed recovery phrase: what is between its spaces, once a
/// line break or space at either end is dropped. The import check and any
/// word count shown while typing both use this, so they agree.
List<String> recoveryPhraseWords(String phrase) => phrase.trim().split(' ').where((word) => word.isNotEmpty).toList();
