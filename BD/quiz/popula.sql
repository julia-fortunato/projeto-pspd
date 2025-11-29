DO $$
DECLARE
    q1_id INTEGER;
    q2_id INTEGER;
    q3_id INTEGER;
    q4_id INTEGER;
    q5_id INTEGER;
BEGIN
    -- ==================================================
    -- Tópico: Visão Geral de Clusters
    -- ==================================================
    
    INSERT INTO quiz (texto, indiceResposta, explicacao)
    VALUES ('Qual é o objetivo principal de um cluster de computadores?', 1, 'Clusters combinam múltiplos computadores (nós) para trabalhar em conjunto, melhorando o desempenho e/ou a disponibilidade.')
    RETURNING id INTO q1_id;

    INSERT INTO alternativas (quiz_id, alternativa) VALUES
    (q1_id, 'Reduzir o consumo de energia de um único servidor'),
    (q1_id, 'Aumentar o desempenho ou a disponibilidade'),
    (q1_id, 'Facilitar o desenvolvimento de software desktop'),
    (q1_id, 'Melhorar a segurança de redes Wi-Fi');

    -- ==================================================
    -- Tópico: Message Brokers (RabbitMQ)
    -- ==================================================

    INSERT INTO quiz (texto, indiceResposta, explicacao)
    VALUES ('Qual padrão de mensageria é implementado pelo RabbitMQ?', 3, 'AMQP (Advanced Message Queuing Protocol) é um padrão aberto para middleware de mensageria que o RabbitMQ implementa.')
    RETURNING id INTO q2_id;

    INSERT INTO alternativas (quiz_id, alternativa) VALUES
    (q2_id, 'HTTP/2'),
    (q2_id, 'MQTT'),
    (q2_id, 'gRPC'),
    (q2_id, 'AMQP');

    -- ==================================================
    -- Tópico: Apache Kafka
    -- ==================================================

    INSERT INTO quiz (texto, indiceResposta, explicacao)
    VALUES ('Qual é a principal característica do Apache Kafka que o diferencia de brokers tradicionais?', 2, 'Kafka foi projetado como uma plataforma de streaming distribuída, baseada em um log de commits distribuído, imutável e tolerante a falhas.')
    RETURNING id INTO q3_id;

    INSERT INTO alternativas (quiz_id, alternativa) VALUES
    (q3_id, 'Ele só permite comunicação síncrona'),
    (q3_id, 'Ele apaga as mensagens imediatamente após o consumo'),
    (q3_id, 'É uma plataforma de streaming distribuída baseada em logs'),
    (q3_id, 'Funciona apenas com a linguagem de programação Java');

    -- ==================================================
    -- Tópico: gRPC
    -- ==================================================

    INSERT INTO quiz (texto, indiceResposta, explicacao)
    VALUES ('Por padrão, qual formato de serialização de dados o gRPC utiliza?', 3, 'gRPC usa Protocol Buffers (Protobuf), um formato binário de alto desempenho, para serializar e desserializar os dados das mensagens.')
    RETURNING id INTO q4_id;

    INSERT INTO alternativas (quiz_id, alternativa) VALUES
    (q4_id, 'JSON'),
    (q4_id, 'XML'),
    (q4_id, 'YAML'),
    (q4_id, 'Protocol Buffers (Protobuf)');
    
    -- ==================================================
    -- Tópico: Paralelismo e Distribuição
    -- ==================================================

    INSERT INTO quiz (texto, indiceResposta, explicacao)
    VALUES ('O que o Teorema CAP afirma sobre sistemas distribuídos?', 1, 'O Teorema CAP (Consistency, Availability, Partition tolerance) afirma que um sistema distribuído só pode garantir duas dessas três propriedades simultaneamente.')
    RETURNING id INTO q5_id;

    INSERT INTO alternativas (quiz_id, alternativa) VALUES
    (q5_id, 'Que um sistema sempre pode garantir Consistência, Disponibilidade e Tolerância a Partições'),
    (q5_id, 'Que é impossível garantir mais de duas das três: Consistência, Disponibilidade e Tolerância a Partições'),
    (q5_id, 'Que a latência da rede é o fator mais importante em um sistema'),
    (q5_id, 'Que todos os dados devem ser criptografados');

END $$;