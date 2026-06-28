//! Embedded stop-word lists (Snowball) so the package works fully offline.
//!
//! Only the languages most relevant to the package's target use cases are
//! embedded. Other Snowball languages stem fine but, if `stopwords = TRUE` is
//! requested for them, the filter is silently skipped (warned about on the R
//! side).

/// Portuguese stop words (Snowball list).
pub const PT_STOPWORDS: &[&str] = &[
    "de", "a", "o", "que", "e", "do", "da", "em", "um", "para", "com", "nao",
    "não", "uma", "os", "no", "se", "na", "por", "mais", "as", "dos", "como",
    "mas", "ao", "ele", "das", "à", "seu", "sua", "ou", "quando", "muito",
    "nos", "já", "eu", "também", "só", "pelo", "pela", "até", "isso", "ela",
    "entre", "depois", "sem", "mesmo", "aos", "seus", "quem", "nas", "me",
    "esse", "eles", "você", "essa", "num", "nem", "suas", "meu", "às", "minha",
    "numa", "pelos", "elas", "qual", "lhe", "deles", "essas", "esses", "pelas",
    "este", "dele", "tu", "te", "vocês", "vos", "lhes", "meus", "minhas",
    "teu", "tua", "teus", "tuas", "nosso", "nossa", "nossos", "nossas", "dela",
    "delas", "esta", "estes", "estas", "aquele", "aquela", "aqueles",
    "aquelas", "isto", "aquilo", "estou", "está", "estamos", "estão", "estive",
    "esteve", "estivemos", "estiveram", "era", "eram", "fui", "foi", "fomos",
    "foram", "seja", "sejam", "ser", "tenho", "tem", "temos", "tém", "tinha",
    "tinham", "tive", "teve", "tivemos", "tiveram", "há", "havia", "hei",
    "está", "estava", "estavam", "sou", "somos", "são", "e", "the",
];

/// English stop words (Snowball list).
pub const EN_STOPWORDS: &[&str] = &[
    "i", "me", "my", "myself", "we", "our", "ours", "ourselves", "you", "your",
    "yours", "yourself", "yourselves", "he", "him", "his", "himself", "she",
    "her", "hers", "herself", "it", "its", "itself", "they", "them", "their",
    "theirs", "themselves", "what", "which", "who", "whom", "this", "that",
    "these", "those", "am", "is", "are", "was", "were", "be", "been", "being",
    "have", "has", "had", "having", "do", "does", "did", "doing", "a", "an",
    "the", "and", "but", "if", "or", "because", "as", "until", "while", "of",
    "at", "by", "for", "with", "about", "against", "between", "into", "through",
    "during", "before", "after", "above", "below", "to", "from", "up", "down",
    "in", "out", "on", "off", "over", "under", "again", "further", "then",
    "once", "here", "there", "when", "where", "why", "how", "all", "any",
    "both", "each", "few", "more", "most", "other", "some", "such", "no", "nor",
    "not", "only", "own", "same", "so", "than", "too", "very", "s", "t", "can",
    "will", "just", "don", "should", "now",
];

/// Return the embedded stop-word list for a Snowball language code, if any.
pub fn stopwords_for(code: &str) -> Option<Vec<String>> {
    let list = match code {
        "pt" => PT_STOPWORDS,
        "en" => EN_STOPWORDS,
        _ => return None,
    };
    Some(list.iter().map(|s| s.to_string()).collect())
}
