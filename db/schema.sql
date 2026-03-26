CREATE TABLE fts_main_chunks.docs(
    docid BIGINT,
    "name" INTEGER,
    len BIGINT
);

CREATE TABLE fts_main_chunks.fields(
    fieldid BIGINT,
    field VARCHAR
);

CREATE TABLE fts_main_chunks.stats(
    num_docs BIGINT,
    avgdl DOUBLE
);

CREATE TABLE fts_main_chunks.stopwords(
    sw VARCHAR
);

CREATE TABLE fts_main_chunks.terms(
    docid BIGINT,
    fieldid BIGINT,
    termid BIGINT
);

CREATE TABLE documents(
    doc_id INTEGER DEFAULT(nextval('doc_id_seq')) PRIMARY KEY, 
    origin VARCHAR UNIQUE, "text" VARCHAR
);

CREATE TABLE metadata(
    embedding_size INTEGER, 
    embed_func BLOB, 
    "name" VARCHAR, 
    title VARCHAR
);

CREATE TABLE embeddings(
    doc_id INTEGER, 
    chunk_id INTEGER DEFAULT(nextval('chunk_id_seq')), 
    "start" INTEGER, 
    "end" INTEGER, 
    context VARCHAR, 
    embedding FLOAT[768], 
    FOREIGN KEY (doc_id) REFERENCES documents(doc_id), 
    PRIMARY KEY(doc_id, "start", "end")
);

CREATE MACRO fts_main_chunks.match_bm25 (
    docname,
    query_string,
    fields := NULL,
    k := 1.2,
    b := 0.75,
    conjunctive := FALSE
) AS (
    (
        WITH tokens AS (
            SELECT
                DISTINCT stem(UNNEST(fts_main_chunks.tokenize(query_string)), 'porter') AS t
        ),
        fieldids AS (
            SELECT
                fieldid
            FROM
                fts_main_chunks.fields
            WHERE
                CASE
                    WHEN (
                        (
                            fields IS NULL
                        )
                    ) THEN (1)
                    ELSE (
                        field = ANY(SELECT * FROM (SELECT UNNEST(string_split(fields, ','))) AS fsq)
                    )
                END
        ),
        qtermids AS (
            SELECT
                termid
            FROM
                fts_main_chunks.dict AS dict ,
                tokens
            WHERE
                (
                    dict.term = tokens.t
                )
        ),
        qterms AS (
            SELECT
                termid,
                docid
            FROM
                fts_main_chunks.terms AS terms
            WHERE
                (
                    CASE
                        WHEN (
                            (
                                fields IS NULL
                            )
                        ) THEN (1)
                        ELSE (
                            fieldid = ANY(SELECT * FROM fieldids)
                        )
                    END
                    AND (
                        termid = ANY(SELECT qtermids.termid FROM qtermids)
                    )
                )
        ),
        term_tf AS (
            SELECT
                termid,
                docid,
                count_star() AS tf
            FROM
                qterms
            GROUP BY
                docid,
                termid
        ),
        cdocs AS (
            SELECT
                docid
            FROM
                qterms
            GROUP BY
                docid
            HAVING
                CASE
                    WHEN (conjunctive) THEN (
                        (
                            count(DISTINCT termid) = (
                                SELECT
                                    count_star()
                                FROM
                                    tokens
                            )
                        )
                    )
                    ELSE 1
                END
        ),
        subscores AS (
            SELECT
                docs.docid,
                len,
                term_tf.termid,
                tf,
                df,
                (
                    log((((((SELECT num_docs FROM fts_main_chunks.stats) - df) + 0.5) / (df + 0.5)) + 1)) * (
                        (
                            tf * (
                                k + 1
                            )
                        ) / (
                            tf + (
                                k * (
                                    (
                                        1 - b
                                    ) + (
                                        b * (
                                            len / (
                                                SELECT
                                                    avgdl
                                                FROM
                                                    fts_main_chunks.stats
                                            )
                                        )
                                    )
                                )
                            )
                        )
                    )
                ) AS subscore
            FROM
                term_tf ,
                cdocs ,
                fts_main_chunks.docs AS docs ,
                fts_main_chunks.dict AS dict
            WHERE
                (
                    (
                        term_tf.docid = cdocs.docid
                    )
                        AND (
                            term_tf.docid = docs.docid
                        )
                            AND (
                                term_tf.termid = dict.termid
                            )
                )
        ),
        scores AS (
            SELECT
                docid,
                sum(subscore) AS score
            FROM
                subscores
            GROUP BY
                docid
        )
        SELECT
            score
        FROM
            scores ,
            fts_main_chunks.docs AS docs
        WHERE
            (
                (
                    scores.docid = docs.docid
                )
                    AND (
                        docs."name" = docname
                    )
            )
    )
);

CREATE MACRO fts_main_chunks.tokenize (s) AS (
    string_split_regex(regexp_replace(lower(strip_accents(CAST(s AS VARCHAR))), '[0-9!@#$%^&*()_+={}\[\]:;<>,.?~\\/\|''''"`-]+', ' ', 'g'), '\s+')
);

CREATE VIEW chunks AS
SELECT
    d.origin AS origin,
    e.*,
    d."text"[e."start":e."end"] AS "text"
FROM
    documents AS d
INNER JOIN embeddings AS e
        USING (doc_id);

CREATE INDEX store_hnsw_cosine_index ON
embeddings
    USING HNSW (embedding);

CREATE INDEX store_hnsw_ip_index ON
embeddings
    USING HNSW (embedding);

CREATE INDEX store_hnsw_l2sq_index ON
embeddings
    USING HNSW (embedding);
