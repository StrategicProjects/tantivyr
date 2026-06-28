//! Translate R-side field specifications into a tantivy [`Schema`].

use tantivy::schema::{
    DateOptions, Field, IndexRecordOption, NumericOptions, Schema, SchemaBuilder, TextFieldIndexing,
    TextOptions,
};

/// The logical type of a field, mirrored on the R side.
#[derive(Clone, Copy, PartialEq, Eq, Debug)]
pub enum FieldKind {
    Text,
    I64,
    U64,
    F64,
    Bool,
    Date,
    Json,
}

impl FieldKind {
    pub fn from_str(s: &str) -> Option<Self> {
        Some(match s {
            "text" => FieldKind::Text,
            "i64" => FieldKind::I64,
            "u64" => FieldKind::U64,
            "f64" => FieldKind::F64,
            "bool" => FieldKind::Bool,
            "date" => FieldKind::Date,
            "json" => FieldKind::Json,
            _ => return None,
        })
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            FieldKind::Text => "text",
            FieldKind::I64 => "i64",
            FieldKind::U64 => "u64",
            FieldKind::F64 => "f64",
            FieldKind::Bool => "bool",
            FieldKind::Date => "date",
            FieldKind::Json => "json",
        }
    }
}

/// Resolved metadata kept on the index for indexing and result assembly.
#[derive(Clone, Debug)]
pub struct FieldMeta {
    pub name: String,
    pub kind: FieldKind,
    pub stored: bool,
    pub field: Field,
}

/// A single field specification coming from R.
pub struct FieldSpec {
    pub name: String,
    pub kind: FieldKind,
    pub stored: bool,
    pub indexed: bool,
    pub fast: bool,
    pub tokenizer: String,
}

fn numeric_options(spec: &FieldSpec) -> NumericOptions {
    let mut opts = NumericOptions::default();
    if spec.stored {
        opts = opts.set_stored();
    }
    if spec.indexed {
        opts = opts.set_indexed();
    }
    if spec.fast {
        opts = opts.set_fast();
    }
    opts
}

fn text_options(spec: &FieldSpec) -> TextOptions {
    let mut opts = TextOptions::default();
    if spec.stored {
        opts = opts.set_stored();
    }
    if spec.indexed {
        let tokenizer = if spec.tokenizer.is_empty() {
            "default".to_string()
        } else {
            spec.tokenizer.clone()
        };
        let indexing = TextFieldIndexing::default()
            .set_tokenizer(&tokenizer)
            .set_index_option(IndexRecordOption::WithFreqsAndPositions);
        opts = opts.set_indexing_options(indexing);
    }
    if spec.fast {
        opts = opts.set_fast(None);
    }
    opts
}

/// Build a tantivy schema together with the resolved field metadata.
pub fn build_schema(specs: &[FieldSpec]) -> (Schema, Vec<FieldMeta>) {
    let mut builder: SchemaBuilder = Schema::builder();
    let mut metas = Vec::with_capacity(specs.len());

    for spec in specs {
        let field = match spec.kind {
            FieldKind::Text => builder.add_text_field(&spec.name, text_options(spec)),
            FieldKind::Json => builder.add_json_field(&spec.name, text_options(spec)),
            FieldKind::I64 => builder.add_i64_field(&spec.name, numeric_options(spec)),
            FieldKind::U64 => builder.add_u64_field(&spec.name, numeric_options(spec)),
            FieldKind::F64 => builder.add_f64_field(&spec.name, numeric_options(spec)),
            FieldKind::Bool => builder.add_bool_field(&spec.name, numeric_options(spec)),
            FieldKind::Date => {
                let mut opts = DateOptions::default();
                if spec.stored {
                    opts = opts.set_stored();
                }
                if spec.indexed {
                    opts = opts.set_indexed();
                }
                if spec.fast {
                    opts = opts.set_fast();
                }
                builder.add_date_field(&spec.name, opts)
            }
        };
        metas.push(FieldMeta {
            name: spec.name.clone(),
            kind: spec.kind,
            stored: spec.stored,
            field,
        });
    }

    (builder.build(), metas)
}

/// Recover field metadata from an already-built schema (re-opened index).
pub fn metas_from_schema(schema: &Schema) -> Vec<FieldMeta> {
    schema
        .fields()
        .map(|(field, entry)| {
            let kind = match entry.field_type() {
                tantivy::schema::FieldType::Str(_) => FieldKind::Text,
                tantivy::schema::FieldType::I64(_) => FieldKind::I64,
                tantivy::schema::FieldType::U64(_) => FieldKind::U64,
                tantivy::schema::FieldType::F64(_) => FieldKind::F64,
                tantivy::schema::FieldType::Bool(_) => FieldKind::Bool,
                tantivy::schema::FieldType::Date(_) => FieldKind::Date,
                tantivy::schema::FieldType::JsonObject(_) => FieldKind::Json,
                _ => FieldKind::Text,
            };
            FieldMeta {
                name: entry.name().to_string(),
                kind,
                stored: entry.is_stored(),
                field,
            }
        })
        .collect()
}
