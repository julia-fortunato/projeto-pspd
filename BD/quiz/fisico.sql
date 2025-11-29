CREATE TABLE quiz (
    id SERIAL PRIMARY KEY,
    texto VARCHAR(255) NOT NULL,
    indiceResposta INTEGER,
    explicacao VARCHAR(255)
);

CREATE TABLE alternativas (
    quiz_id INTEGER NOT NULL,
    alternativa VARCHAR(255) NOT NULL,
    CONSTRAINT fk_quiz
        FOREIGN KEY(quiz_id)
        REFERENCES quiz(id)
        ON DELETE CASCADE
);
