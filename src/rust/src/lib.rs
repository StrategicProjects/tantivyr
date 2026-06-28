//! extendr bindings for the Tantivy full-text search engine.
//!
//! The FFI surface is intentionally thin: a single [`TantivyIndex`] object that
//! owns the tantivy `Index`, a lazily created `IndexWriter` and an
//! `IndexReader`. Data crosses the boundary as plain R vectors / lists; all the
//! tidyverse ergonomics live on the R side.

use std::cell::RefCell;

use extendr_api::prelude::*;

use tantivy::collector::{Count, TopDocs};
use tantivy::query::{AllQuery, BooleanQuery, Occur, Query, QueryParser};
use tantivy::schema::{Field, Schema, Value};
use tantivy::snippet::SnippetGenerator;
use tantivy::DateTime;
use tantivy::{Index, IndexReader, IndexWriter, Order, ReloadPolicy, TantivyDocument, Term};

/// extendr 0.9's prelude does not export a one-argument `Result`.
type Result<T> = std::result::Result<T, Error>;

mod analyzer;
mod schema;
mod stopwords;

use analyzer::register_analyzer;
use schema::{build_schema, metas_from_schema, FieldKind, FieldMeta, FieldSpec};

/// Convert any error into an extendr (R) error.
fn rerr<E: std::fmt::Display>(e: E) -> Error {
    Error::Other(e.to_string())
}

/// A live tantivy index plus the metadata needed to move data to and from R.
struct TantivyIndex {
    index: Index,
    schema: Schema,
    metas: Vec<FieldMeta>,
    reader: IndexReader,
    writer: RefCell<Option<IndexWriter>>,
    heap: usize,
}

impl TantivyIndex {
    fn finish(index: Index, metas: Vec<FieldMeta>, heap: usize) -> Result<Self> {
        // (Re)register the custom analyzers referenced by the schema.
        let schema = index.schema();
        for (_, entry) in schema.fields() {
            if let tantivy::schema::FieldType::Str(opts) = entry.field_type() {
                if let Some(indexing) = opts.get_indexing_options() {
                    register_analyzer(&index, indexing.tokenizer());
                }
            }
        }
        let reader = index
            .reader_builder()
            .reload_policy(ReloadPolicy::Manual)
            .try_into()
            .map_err(rerr)?;
        Ok(TantivyIndex {
            index,
            schema,
            metas,
            reader,
            writer: RefCell::new(None),
            heap,
        })
    }

    fn meta(&self, name: &str) -> Result<&FieldMeta> {
        self.metas
            .iter()
            .find(|m| m.name == name)
            .ok_or_else(|| Error::Other(format!("Unknown field '{name}'")))
    }

    fn field(&self, name: &str) -> Result<Field> {
        self.schema.get_field(name).map_err(rerr)
    }

    /// Ensure a writer exists and run `f` against it.
    fn with_writer<T>(&self, f: impl FnOnce(&IndexWriter) -> Result<T>) -> Result<T> {
        let mut guard = self.writer.borrow_mut();
        if guard.is_none() {
            let writer = self.index.writer(self.heap).map_err(rerr)?;
            *guard = Some(writer);
        }
        f(guard.as_ref().unwrap())
    }

    /// Build tantivy documents from a list of R columns (one per `field_names`).
    fn build_documents(
        &self,
        field_names: &[String],
        columns: &List,
    ) -> Result<Vec<TantivyDocument>> {
        if field_names.len() != columns.len() {
            return Err(Error::Other(
                "Number of field names must match number of columns".into(),
            ));
        }
        // Determine number of rows from the first column.
        let nrow = columns.elt(0).map(|c| c.len()).unwrap_or(0);
        let mut docs: Vec<TantivyDocument> = (0..nrow).map(|_| TantivyDocument::default()).collect();

        for (j, name) in field_names.iter().enumerate() {
            let meta = self.meta(name)?;
            let col = columns.elt(j).map_err(rerr)?;
            match meta.kind {
                FieldKind::Text | FieldKind::Json => {
                    let vals = col_string(&col)?;
                    for (i, v) in vals.into_iter().enumerate() {
                        if let Some(s) = v {
                            if meta.kind == FieldKind::Json {
                                // best-effort: store/-index JSON text verbatim
                                docs[i].add_text(meta.field, s);
                            } else {
                                docs[i].add_text(meta.field, s);
                            }
                        }
                    }
                }
                FieldKind::Bool => {
                    let vals = col_bool(&col)?;
                    for (i, v) in vals.into_iter().enumerate() {
                        if let Some(b) = v {
                            docs[i].add_bool(meta.field, b);
                        }
                    }
                }
                FieldKind::I64 => add_numeric(&col, &mut docs, |d, v| d.add_i64(meta.field, v as i64))?,
                FieldKind::U64 => add_numeric(&col, &mut docs, |d, v| d.add_u64(meta.field, v as u64))?,
                FieldKind::F64 => add_numeric(&col, &mut docs, |d, v| d.add_f64(meta.field, v))?,
                FieldKind::Date => add_numeric(&col, &mut docs, |d, v| {
                    d.add_date(meta.field, DateTime::from_timestamp_secs(v as i64))
                })?,
            }
        }
        Ok(docs)
    }
}

fn add_numeric(
    col: &Robj,
    docs: &mut [TantivyDocument],
    mut f: impl FnMut(&mut TantivyDocument, f64),
) -> Result<()> {
    let vals = col_f64(col)?;
    for (i, v) in vals.into_iter().enumerate() {
        if let Some(x) = v {
            f(&mut docs[i], x);
        }
    }
    Ok(())
}

// --- column readers (R vector -> Vec<Option<T>>) -------------------------------

fn col_f64(obj: &Robj) -> Result<Vec<Option<f64>>> {
    match obj.rtype() {
        Rtype::Doubles => {
            let d = Doubles::try_from(obj.clone()).map_err(rerr)?;
            Ok(d.iter().map(Option::<f64>::from).collect())
        }
        Rtype::Integers => {
            let d = Integers::try_from(obj.clone()).map_err(rerr)?;
            Ok(d.iter()
                .map(|x| Option::<i32>::from(x).map(|v| v as f64))
                .collect())
        }
        Rtype::Logicals => {
            let d = Logicals::try_from(obj.clone()).map_err(rerr)?;
            Ok(d.iter()
                .map(|x| Option::<bool>::from(x).map(|b| if b { 1.0 } else { 0.0 }))
                .collect())
        }
        _ => Err(Error::Other("Expected a numeric column".into())),
    }
}

fn col_string(obj: &Robj) -> Result<Vec<Option<String>>> {
    let s = Strings::try_from(obj.clone()).map_err(rerr)?;
    Ok(s.iter()
        .map(|x| {
            if x.is_na() {
                None
            } else {
                Some(x.as_ref().to_string())
            }
        })
        .collect())
}

fn col_bool(obj: &Robj) -> Result<Vec<Option<bool>>> {
    let b = Logicals::try_from(obj.clone()).map_err(rerr)?;
    Ok(b.iter().map(Option::<bool>::from).collect())
}

/// Convert a `Logicals` argument to a plain `Vec<bool>` (NA -> false).
fn lgl(l: Logicals) -> Vec<bool> {
    l.iter().map(|x| x.is_true()).collect()
}

// --- output column buffers (-> R vectors) -------------------------------------

enum ColumnBuf {
    Txt(Vec<Option<String>>),
    Num(Vec<Option<f64>>),
    Bool(Vec<Option<bool>>),
}

impl ColumnBuf {
    fn new(kind: FieldKind, n: usize) -> Self {
        match kind {
            FieldKind::Text | FieldKind::Json => ColumnBuf::Txt(Vec::with_capacity(n)),
            FieldKind::Bool => ColumnBuf::Bool(Vec::with_capacity(n)),
            _ => ColumnBuf::Num(Vec::with_capacity(n)),
        }
    }

    fn into_robj(self) -> Robj {
        match self {
            ColumnBuf::Txt(v) => Strings::from_values(
                v.into_iter()
                    .map(|o| o.map(Rstr::from).unwrap_or_else(Rstr::na)),
            )
            .into(),
            ColumnBuf::Num(v) => Doubles::from_values(
                v.into_iter()
                    .map(|o| o.map(Rfloat::from).unwrap_or_else(Rfloat::na)),
            )
            .into(),
            ColumnBuf::Bool(v) => Logicals::from_values(
                v.into_iter()
                    .map(|o| o.map(Rbool::from).unwrap_or_else(Rbool::na)),
            )
            .into(),
        }
    }
}

fn push_value(buf: &mut ColumnBuf, doc: &TantivyDocument, meta: &FieldMeta) {
    let v = doc.get_first(meta.field);
    match buf {
        ColumnBuf::Txt(col) => col.push(v.and_then(|x| x.as_str().map(|s| s.to_string()))),
        ColumnBuf::Bool(col) => col.push(v.and_then(|x| x.as_bool())),
        ColumnBuf::Num(col) => col.push(match meta.kind {
            FieldKind::I64 => v.and_then(|x| x.as_i64()).map(|x| x as f64),
            FieldKind::U64 => v.and_then(|x| x.as_u64()).map(|x| x as f64),
            FieldKind::F64 => v.and_then(|x| x.as_f64()),
            FieldKind::Date => v
                .and_then(|x| x.as_datetime())
                .map(|d| d.into_timestamp_secs() as f64),
            _ => None,
        }),
    }
}

impl TantivyIndex {
    /// Create a new on-disk index in `path` (the directory must be empty).
    fn create_in_dir(
        path: &str,
        names: Vec<String>,
        kinds: Vec<String>,
        stored: Logicals,
        indexed: Logicals,
        fast: Logicals,
        tokenizers: Vec<String>,
        heap_mb: f64,
    ) -> Result<Self> {
        let specs = make_specs(&names, &kinds, &lgl(stored), &lgl(indexed), &lgl(fast), &tokenizers)?;
        let (schema, metas) = build_schema(&specs);
        std::fs::create_dir_all(path).map_err(rerr)?;
        let index = Index::create_in_dir(path, schema).map_err(rerr)?;
        TantivyIndex::finish(index, metas, mb(heap_mb))
    }

    /// Create a new in-memory index (lost when the object is garbage-collected).
    fn create_in_ram(
        names: Vec<String>,
        kinds: Vec<String>,
        stored: Logicals,
        indexed: Logicals,
        fast: Logicals,
        tokenizers: Vec<String>,
        heap_mb: f64,
    ) -> Result<Self> {
        let specs = make_specs(&names, &kinds, &lgl(stored), &lgl(indexed), &lgl(fast), &tokenizers)?;
        let (schema, metas) = build_schema(&specs);
        let index = Index::create_in_ram(schema);
        TantivyIndex::finish(index, metas, mb(heap_mb))
    }

    /// Open an existing on-disk index.
    fn open_in_dir(path: &str, heap_mb: f64) -> Result<Self> {
        let index = Index::open_in_dir(path).map_err(rerr)?;
        let metas = metas_from_schema(&index.schema());
        TantivyIndex::finish(index, metas, mb(heap_mb))
    }

    /// Add documents (a list of equal-length columns, one per `field_names`).
    fn add(&self, field_names: Vec<String>, columns: List) -> Result<f64> {
        let docs = self.build_documents(&field_names, &columns)?;
        let n = docs.len();
        self.with_writer(|w| {
            for doc in docs {
                w.add_document(doc).map_err(rerr)?;
            }
            Ok(())
        })?;
        Ok(n as f64)
    }

    /// Delete documents whose `field` (numeric/date) equals `value`.
    fn delete_numeric(&self, field: String, value: f64) -> Result<()> {
        let meta = self.meta(&field)?.clone();
        let term = match meta.kind {
            FieldKind::I64 => Term::from_field_i64(meta.field, value as i64),
            FieldKind::U64 => Term::from_field_u64(meta.field, value as u64),
            FieldKind::F64 => Term::from_field_f64(meta.field, value),
            FieldKind::Bool => Term::from_field_bool(meta.field, value != 0.0),
            FieldKind::Date => {
                Term::from_field_date(meta.field, DateTime::from_timestamp_secs(value as i64))
            }
            _ => return Err(Error::Other(format!("Field '{field}' is not numeric"))),
        };
        self.with_writer(|w| {
            w.delete_term(term);
            Ok(())
        })
    }

    /// Delete documents whose text `field` exactly equals `value`.
    ///
    /// Reliable only for fields indexed with the `raw` tokenizer.
    fn delete_text(&self, field: String, value: String) -> Result<()> {
        let f = self.field(&field)?;
        let term = Term::from_field_text(f, &value);
        self.with_writer(|w| {
            w.delete_term(term);
            Ok(())
        })
    }

    /// Commit pending additions / deletions and refresh the reader.
    fn commit(&self) -> Result<()> {
        let mut guard = self.writer.borrow_mut();
        if let Some(writer) = guard.as_mut() {
            writer.commit().map_err(rerr)?;
        }
        drop(guard);
        self.reader.reload().map_err(rerr)?;
        Ok(())
    }

    /// Number of committed (searchable) documents.
    fn num_docs(&self) -> f64 {
        self.reader.searcher().num_docs() as f64
    }

    /// Count documents matching a query (and optional filter).
    fn count(&self, query: String, default_fields: Vec<String>, filter: String) -> Result<f64> {
        let searcher = self.reader.searcher();
        let q = self.make_query(&query, &default_fields, &filter)?;
        let n = searcher.search(&*q, &Count).map_err(rerr)?;
        Ok(n as f64)
    }

    /// Run a search and return columns: `score`, every stored field, and one
    /// `__hl_<field>` column per requested highlight field.
    #[allow(clippy::too_many_arguments)]
    fn search(
        &self,
        query: String,
        limit: f64,
        default_fields: Vec<String>,
        filter: String,
        highlight: Vec<String>,
        snippet_chars: f64,
        order_by: String,
        order_desc: bool,
    ) -> Result<List> {
        let searcher = self.reader.searcher();
        let q = self.make_query(&query, &default_fields, &filter)?;
        let limit = limit.max(0.0) as usize;

        // Collect (score, address) honouring the requested ordering.
        let hits: Vec<(Option<f64>, tantivy::DocAddress)> = if order_by.is_empty() {
            searcher
                .search(&*q, &TopDocs::with_limit(limit).order_by_score())
                .map_err(rerr)?
                .into_iter()
                .map(|(s, a)| (Some(s as f64), a))
                .collect()
        } else {
            let meta = self.meta(&order_by)?.clone();
            let order = if order_desc { Order::Desc } else { Order::Asc };
            match meta.kind {
                FieldKind::F64 => searcher
                    .search(
                        &*q,
                        &TopDocs::with_limit(limit).order_by_fast_field::<f64>(&order_by, order),
                    )
                    .map_err(rerr)?
                    .into_iter()
                    .map(|(_, a)| (None, a))
                    .collect(),
                FieldKind::U64 => searcher
                    .search(
                        &*q,
                        &TopDocs::with_limit(limit).order_by_fast_field::<u64>(&order_by, order),
                    )
                    .map_err(rerr)?
                    .into_iter()
                    .map(|(_, a)| (None, a))
                    .collect(),
                FieldKind::I64 => searcher
                    .search(
                        &*q,
                        &TopDocs::with_limit(limit).order_by_fast_field::<i64>(&order_by, order),
                    )
                    .map_err(rerr)?
                    .into_iter()
                    .map(|(_, a)| (None, a))
                    .collect(),
                FieldKind::Date => searcher
                    .search(
                        &*q,
                        &TopDocs::with_limit(limit)
                            .order_by_fast_field::<DateTime>(&order_by, order),
                    )
                    .map_err(rerr)?
                    .into_iter()
                    .map(|(_, a)| (None, a))
                    .collect(),
                _ => {
                    return Err(Error::Other(format!(
                        "Cannot order by non-numeric field '{order_by}'"
                    )))
                }
            }
        };

        let n = hits.len();

        // Snippet generators for highlight fields.
        let mut snip_gens = Vec::new();
        for name in &highlight {
            let f = self.field(name)?;
            let mut sg = SnippetGenerator::create(&searcher, &*q, f).map_err(rerr)?;
            if snippet_chars > 0.0 {
                sg.set_max_num_chars(snippet_chars as usize);
            }
            snip_gens.push((name.clone(), sg));
        }

        // Prepare output buffers: score + every stored field + highlights.
        let stored: Vec<FieldMeta> = self.metas.iter().filter(|m| m.stored).cloned().collect();
        let mut score_buf: Vec<Option<f64>> = Vec::with_capacity(n);
        let mut field_bufs: Vec<ColumnBuf> =
            stored.iter().map(|m| ColumnBuf::new(m.kind, n)).collect();
        let mut hl_bufs: Vec<Vec<Option<String>>> =
            snip_gens.iter().map(|_| Vec::with_capacity(n)).collect();

        for (score, addr) in hits {
            score_buf.push(score);
            let doc: TantivyDocument = searcher.doc(addr).map_err(rerr)?;
            for (buf, meta) in field_bufs.iter_mut().zip(stored.iter()) {
                push_value(buf, &doc, meta);
            }
            for (k, (_, sg)) in snip_gens.iter().enumerate() {
                let snip = sg.snippet_from_doc(&doc);
                let html = snip.to_html();
                hl_bufs[k].push(if html.is_empty() { None } else { Some(html) });
            }
        }

        // Assemble the named list of columns.
        let mut names: Vec<String> = Vec::with_capacity(1 + stored.len() + snip_gens.len());
        let mut values: Vec<Robj> = Vec::with_capacity(names.capacity());

        names.push("score".to_string());
        values.push(
            Doubles::from_values(
                score_buf
                    .into_iter()
                    .map(|o| o.map(Rfloat::from).unwrap_or_else(Rfloat::na)),
            )
            .into(),
        );
        for (meta, buf) in stored.iter().zip(field_bufs.into_iter()) {
            names.push(meta.name.clone());
            values.push(buf.into_robj());
        }
        for ((name, _), buf) in snip_gens.into_iter().zip(hl_bufs.into_iter()) {
            names.push(format!("__hl_{name}"));
            values.push(
                Strings::from_values(
                    buf.into_iter()
                        .map(|o| o.map(Rstr::from).unwrap_or_else(Rstr::na)),
                )
                .into(),
            );
        }

        List::from_names_and_values(names, values).map_err(rerr)
    }

    /// Return schema information as parallel vectors (for R-side introspection).
    fn schema_info(&self) -> Result<List> {
        let mut names = Vec::new();
        let mut kinds = Vec::new();
        let mut stored = Vec::new();
        let mut indexed = Vec::new();
        let mut tokenizers = Vec::new();
        for (field, entry) in self.schema.fields() {
            let _ = field;
            names.push(entry.name().to_string());
            stored.push(entry.is_stored());
            let (kind, idx, tok) = match entry.field_type() {
                tantivy::schema::FieldType::Str(o) => {
                    let tok = o
                        .get_indexing_options()
                        .map(|i| i.tokenizer().to_string())
                        .unwrap_or_default();
                    (FieldKind::Text, o.get_indexing_options().is_some(), tok)
                }
                tantivy::schema::FieldType::I64(o) => (FieldKind::I64, o.is_indexed(), String::new()),
                tantivy::schema::FieldType::U64(o) => (FieldKind::U64, o.is_indexed(), String::new()),
                tantivy::schema::FieldType::F64(o) => (FieldKind::F64, o.is_indexed(), String::new()),
                tantivy::schema::FieldType::Bool(o) => {
                    (FieldKind::Bool, o.is_indexed(), String::new())
                }
                tantivy::schema::FieldType::Date(o) => {
                    (FieldKind::Date, o.is_indexed(), String::new())
                }
                tantivy::schema::FieldType::JsonObject(_) => (FieldKind::Json, true, String::new()),
                _ => (FieldKind::Text, false, String::new()),
            };
            kinds.push(kind.as_str().to_string());
            indexed.push(idx);
            tokenizers.push(tok);
        }
        let values: Vec<Robj> = vec![
            Strings::from_values(names).into(),
            Strings::from_values(kinds).into(),
            Logicals::from_values(stored.into_iter().map(Rbool::from)).into(),
            Logicals::from_values(indexed.into_iter().map(Rbool::from)).into(),
            Strings::from_values(tokenizers).into(),
        ];
        List::from_names_and_values(["name", "kind", "stored", "indexed", "tokenizer"], values)
            .map_err(rerr)
    }
}

impl TantivyIndex {
    /// Build a combined query from a user query string and an optional filter.
    fn make_query(
        &self,
        query: &str,
        default_fields: &[String],
        filter: &str,
    ) -> Result<Box<dyn Query>> {
        let default: Vec<Field> = default_fields
            .iter()
            .map(|n| self.field(n))
            .collect::<Result<_>>()?;
        let parser = QueryParser::for_index(&self.index, default);

        let main: Box<dyn Query> = if query.trim().is_empty() {
            Box::new(AllQuery)
        } else {
            parser.parse_query(query).map_err(rerr)?
        };

        if filter.trim().is_empty() {
            Ok(main)
        } else {
            let fq = parser.parse_query(filter).map_err(rerr)?;
            Ok(Box::new(BooleanQuery::new(vec![
                (Occur::Must, main),
                (Occur::Must, fq),
            ])))
        }
    }
}

fn mb(heap_mb: f64) -> usize {
    let bytes = (heap_mb.max(15.0) * 1_000_000.0) as usize;
    bytes.max(15_000_000)
}

#[allow(clippy::too_many_arguments)]
fn make_specs(
    names: &[String],
    kinds: &[String],
    stored: &[bool],
    indexed: &[bool],
    fast: &[bool],
    tokenizers: &[String],
) -> Result<Vec<FieldSpec>> {
    let n = names.len();
    if [kinds.len(), stored.len(), indexed.len(), fast.len(), tokenizers.len()]
        .iter()
        .any(|&l| l != n)
    {
        return Err(Error::Other("Schema specification vectors differ in length".into()));
    }
    let mut specs = Vec::with_capacity(n);
    for i in 0..n {
        let kind = FieldKind::from_str(&kinds[i])
            .ok_or_else(|| Error::Other(format!("Unknown field type '{}'", kinds[i])))?;
        specs.push(FieldSpec {
            name: names[i].clone(),
            kind,
            stored: stored[i],
            indexed: indexed[i],
            fast: fast[i],
            tokenizer: tokenizers[i].clone(),
        });
    }
    Ok(specs)
}

// --- extendr free-function surface --------------------------------------------
//
// The index is moved into an `ExternalPtr` and handed back to R. All R-facing
// calls take that pointer and forward to the methods above. This avoids the
// `#[extendr] impl` macro, which cannot express fallible constructors.

type IdxPtr = ExternalPtr<TantivyIndex>;

#[extendr]
#[allow(clippy::too_many_arguments)]
fn tnt_create_in_dir(
    path: &str,
    names: Vec<String>,
    kinds: Vec<String>,
    stored: Logicals,
    indexed: Logicals,
    fast: Logicals,
    tokenizers: Vec<String>,
    heap_mb: f64,
) -> Result<IdxPtr> {
    let idx =
        TantivyIndex::create_in_dir(path, names, kinds, stored, indexed, fast, tokenizers, heap_mb)?;
    Ok(ExternalPtr::new(idx))
}

#[extendr]
#[allow(clippy::too_many_arguments)]
fn tnt_create_in_ram(
    names: Vec<String>,
    kinds: Vec<String>,
    stored: Logicals,
    indexed: Logicals,
    fast: Logicals,
    tokenizers: Vec<String>,
    heap_mb: f64,
) -> Result<IdxPtr> {
    let idx = TantivyIndex::create_in_ram(names, kinds, stored, indexed, fast, tokenizers, heap_mb)?;
    Ok(ExternalPtr::new(idx))
}

#[extendr]
fn tnt_open_in_dir(path: &str, heap_mb: f64) -> Result<IdxPtr> {
    Ok(ExternalPtr::new(TantivyIndex::open_in_dir(path, heap_mb)?))
}

#[extendr]
fn tnt_add_(idx: IdxPtr, field_names: Vec<String>, columns: List) -> Result<f64> {
    idx.add(field_names, columns)
}

#[extendr]
fn tnt_delete_numeric_(idx: IdxPtr, field: String, value: f64) -> Result<()> {
    idx.delete_numeric(field, value)
}

#[extendr]
fn tnt_delete_text_(idx: IdxPtr, field: String, value: String) -> Result<()> {
    idx.delete_text(field, value)
}

#[extendr]
fn tnt_commit_(idx: IdxPtr) -> Result<()> {
    idx.commit()
}

#[extendr]
fn tnt_num_docs_(idx: IdxPtr) -> f64 {
    idx.num_docs()
}

#[extendr]
fn tnt_count_(idx: IdxPtr, query: String, default_fields: Vec<String>, filter: String) -> Result<f64> {
    idx.count(query, default_fields, filter)
}

#[extendr]
#[allow(clippy::too_many_arguments)]
fn tnt_search_(
    idx: IdxPtr,
    query: String,
    limit: f64,
    default_fields: Vec<String>,
    filter: String,
    highlight: Vec<String>,
    snippet_chars: f64,
    order_by: String,
    order_desc: bool,
) -> Result<List> {
    idx.search(
        query,
        limit,
        default_fields,
        filter,
        highlight,
        snippet_chars,
        order_by,
        order_desc,
    )
}

#[extendr]
fn tnt_schema_info_(idx: IdxPtr) -> Result<List> {
    idx.schema_info()
}

/// Tantivy version string.
/// @export
#[extendr]
fn tantivy_version() -> String {
    tantivy::version_string().to_string()
}

extendr_module! {
    mod tantivyr;
    fn tnt_create_in_dir;
    fn tnt_create_in_ram;
    fn tnt_open_in_dir;
    fn tnt_add_;
    fn tnt_delete_numeric_;
    fn tnt_delete_text_;
    fn tnt_commit_;
    fn tnt_num_docs_;
    fn tnt_count_;
    fn tnt_search_;
    fn tnt_schema_info_;
    fn tantivy_version;
}
