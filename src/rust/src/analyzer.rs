//! Text analyzers (tokenizer + filter chains) for stemming and stop words.
//!
//! Each stemming text field uses a named analyzer. The name encodes everything
//! needed to rebuild the analyzer when an existing on-disk index is re-opened,
//! because tantivy persists the tokenizer *name* (not its definition) in the
//! schema. Naming scheme:
//!
//! * `default` — tantivy's built-in (simple tokenizer + lowercaser). No stemming.
//! * `raw`     — tantivy's built-in raw tokenizer (exact, untokenized).
//! * `tnt_<code>`        — lowercase + stem in `<code>` (e.g. `tnt_pt`).
//! * `tnt_<code>_stop`   — same, plus stop-word removal.

use tantivy::tokenizer::{
    Language, LowerCaser, RemoveLongFilter, SimpleTokenizer, Stemmer, StopWordFilter, TextAnalyzer,
};
use tantivy::Index;

use crate::stopwords::stopwords_for;

/// Map a Snowball language code to a tantivy [`Language`].
pub fn language_from_code(code: &str) -> Option<Language> {
    Some(match code {
        "ar" => Language::Arabic,
        "da" => Language::Danish,
        "nl" => Language::Dutch,
        "en" => Language::English,
        "fi" => Language::Finnish,
        "fr" => Language::French,
        "de" => Language::German,
        "el" => Language::Greek,
        "hu" => Language::Hungarian,
        "it" => Language::Italian,
        "no" => Language::Norwegian,
        "pt" => Language::Portuguese,
        "ro" => Language::Romanian,
        "ru" => Language::Russian,
        "es" => Language::Spanish,
        "sv" => Language::Swedish,
        "ta" => Language::Tamil,
        "tr" => Language::Turkish,
        _ => return None,
    })
}

/// Build a [`TextAnalyzer`] for a given language code and stop-word flag.
fn build_analyzer(code: &str, stopwords: bool) -> Option<TextAnalyzer> {
    let language = language_from_code(code)?;
    let mut builder = TextAnalyzer::builder(SimpleTokenizer::default())
        .filter(RemoveLongFilter::limit(40))
        .filter(LowerCaser)
        .dynamic();
    if stopwords {
        if let Some(words) = stopwords_for(code) {
            builder = builder.filter_dynamic(StopWordFilter::remove(words));
        }
    }
    builder = builder.filter_dynamic(Stemmer::new(language));
    Some(builder.build())
}

/// Ensure the analyzer identified by `name` is registered on `index`.
///
/// Built-in tantivy tokenizers (`default`, `raw`, `whitespace`, `en_stem`) are
/// left untouched. Custom `tnt_*` analyzers are (re)built and registered.
pub fn register_analyzer(index: &Index, name: &str) {
    let Some(rest) = name.strip_prefix("tnt_") else {
        return; // built-in tokenizer; nothing to register
    };
    let (code, stopwords) = match rest.strip_suffix("_stop") {
        Some(code) => (code, true),
        None => (rest, false),
    };
    if let Some(analyzer) = build_analyzer(code, stopwords) {
        index.tokenizers().register(name, analyzer);
    }
}
