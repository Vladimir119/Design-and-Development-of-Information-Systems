CREATE TABLE counter (
    id INTEGER PRIMARY KEY,
    visits BIGINT NOT NULL DEFAULT 0
);

INSERT INTO counter (id, visits) VALUES (1, 0);
