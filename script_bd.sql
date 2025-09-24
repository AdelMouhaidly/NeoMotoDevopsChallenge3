-- =============================================================================
-- NeoMoto API - Script DDL do Banco de Dados
-- DevOps Challenge 3 - FIAP
-- Sistema de Gestão de Frota de Motos
-- =============================================================================

-- Configurações iniciais do banco
SET timezone = 'UTC';

-- Criação de extensões úteis
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements";

-- Comentário no banco de dados
COMMENT ON DATABASE neomoto IS 'Sistema de gestão de frota de motos NeoMoto - Controle de filiais, veículos e manutenções';

-- =============================================================================
-- TABELA: Filiais
-- Descrição: Armazena as unidades físicas que organizam a frota de motos
-- =============================================================================

CREATE TABLE IF NOT EXISTS "Filiais" (
    "Id" uuid NOT NULL DEFAULT uuid_generate_v4(),
    "Nome" character varying(120) NOT NULL,
    "Endereco" character varying(200) NOT NULL,
    "Cidade" character varying(50) NOT NULL,
    "Uf" character varying(2) NOT NULL DEFAULT 'SP',
    
    -- Chave primária
    CONSTRAINT "PK_Filiais" PRIMARY KEY ("Id")
);

-- Comentários na tabela Filiais
COMMENT ON TABLE "Filiais" IS 'Unidades físicas da empresa que organizam a frota de motos';
COMMENT ON COLUMN "Filiais"."Id" IS 'Identificador único da filial (UUID)';
COMMENT ON COLUMN "Filiais"."Nome" IS 'Nome da filial (até 120 caracteres)';
COMMENT ON COLUMN "Filiais"."Endereco" IS 'Endereço completo da filial (até 200 caracteres)';
COMMENT ON COLUMN "Filiais"."Cidade" IS 'Cidade onde a filial está localizada (até 50 caracteres)';
COMMENT ON COLUMN "Filiais"."Uf" IS 'Unidade Federativa da filial (2 caracteres, padrão SP)';

-- Índices para performance
CREATE INDEX IF NOT EXISTS "IX_Filiais_Nome" ON "Filiais" ("Nome");
CREATE INDEX IF NOT EXISTS "IX_Filiais_Cidade" ON "Filiais" ("Cidade");

-- =============================================================================
-- TABELA: Motos
-- Descrição: Armazena os veículos da frota associados a uma filial
-- =============================================================================

CREATE TABLE IF NOT EXISTS "Motos" (
    "Id" uuid NOT NULL DEFAULT uuid_generate_v4(),
    "Placa" character varying(20) NOT NULL,
    "Modelo" character varying(50) NOT NULL,
    "Ano" integer NOT NULL,
    "FilialId" uuid NOT NULL,
    
    -- Chave primária
    CONSTRAINT "PK_Motos" PRIMARY KEY ("Id"),
    
    -- Chave estrangeira para Filiais
    CONSTRAINT "FK_Motos_Filiais_FilialId" FOREIGN KEY ("FilialId") 
        REFERENCES "Filiais" ("Id") ON DELETE RESTRICT,
    
    -- Constraints de validação
    CONSTRAINT "CK_Motos_Ano" CHECK ("Ano" >= 2000 AND "Ano" <= 2100),
    CONSTRAINT "CK_Motos_Placa" CHECK (LENGTH("Placa") >= 7)
);

-- Comentários na tabela Motos
COMMENT ON TABLE "Motos" IS 'Veículos da frota associados a uma filial específica';
COMMENT ON COLUMN "Motos"."Id" IS 'Identificador único da moto (UUID)';
COMMENT ON COLUMN "Motos"."Placa" IS 'Placa do veículo (única no sistema, até 20 caracteres)';
COMMENT ON COLUMN "Motos"."Modelo" IS 'Modelo da moto (até 50 caracteres)';
COMMENT ON COLUMN "Motos"."Ano" IS 'Ano de fabricação da moto (entre 2000 e 2100)';
COMMENT ON COLUMN "Motos"."FilialId" IS 'Referência à filial proprietária da moto';

-- Índices para performance e integridade
CREATE UNIQUE INDEX IF NOT EXISTS "IX_Motos_Placa" ON "Motos" ("Placa");
CREATE INDEX IF NOT EXISTS "IX_Motos_FilialId" ON "Motos" ("FilialId");
CREATE INDEX IF NOT EXISTS "IX_Motos_Modelo" ON "Motos" ("Modelo");

-- =============================================================================
-- TABELA: Manutencoes
-- Descrição: Armazena o histórico de manutenções realizadas nas motos
-- =============================================================================

CREATE TABLE IF NOT EXISTS "Manutencoes" (
    "Id" uuid NOT NULL DEFAULT uuid_generate_v4(),
    "MotoId" uuid NOT NULL,
    "Data" timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "Descricao" character varying(200) NOT NULL,
    "Custo" numeric(10,2) NOT NULL DEFAULT 0,
    
    -- Chave primária
    CONSTRAINT "PK_Manutencoes" PRIMARY KEY ("Id"),
    
    -- Chave estrangeira para Motos
    CONSTRAINT "FK_Manutencoes_Motos_MotoId" FOREIGN KEY ("MotoId") 
        REFERENCES "Motos" ("Id") ON DELETE CASCADE,
    
    -- Constraints de validação
    CONSTRAINT "CK_Manutencoes_Custo" CHECK ("Custo" >= 0),
    CONSTRAINT "CK_Manutencoes_Data" CHECK ("Data" <= CURRENT_TIMESTAMP + INTERVAL '1 day')
);

-- Comentários na tabela Manutencoes
COMMENT ON TABLE "Manutencoes" IS 'Histórico de manutenções realizadas nas motos da frota';
COMMENT ON COLUMN "Manutencoes"."Id" IS 'Identificador único da manutenção (UUID)';
COMMENT ON COLUMN "Manutencoes"."MotoId" IS 'Referência à moto que recebeu a manutenção';
COMMENT ON COLUMN "Manutencoes"."Data" IS 'Data e hora da manutenção (com timezone)';
COMMENT ON COLUMN "Manutencoes"."Descricao" IS 'Descrição detalhada da manutenção realizada (até 200 caracteres)';
COMMENT ON COLUMN "Manutencoes"."Custo" IS 'Custo da manutenção em reais (numeric 10,2)';

-- Índices para performance
CREATE INDEX IF NOT EXISTS "IX_Manutencoes_MotoId" ON "Manutencoes" ("MotoId");
CREATE INDEX IF NOT EXISTS "IX_Manutencoes_Data" ON "Manutencoes" ("Data" DESC);
CREATE INDEX IF NOT EXISTS "IX_Manutencoes_Custo" ON "Manutencoes" ("Custo");

-- =============================================================================
-- DADOS DE EXEMPLO (SEED DATA)
-- Inserção de registros iniciais para demonstração
-- =============================================================================

-- Inserir filiais de exemplo
INSERT INTO "Filiais" ("Id", "Nome", "Endereco", "Cidade", "Uf") VALUES
    ('11111111-1111-1111-1111-111111111111', 'Filial Centro', 'Rua Augusta, 1000', 'São Paulo', 'SP'),
    ('22222222-2222-2222-2222-222222222222', 'Filial Zona Sul', 'Av. Paulista, 2000', 'São Paulo', 'SP'),
    ('33333333-3333-3333-3333-333333333333', 'Filial Zona Norte', 'Rua Voluntários da Pátria, 3000', 'São Paulo', 'SP')
ON CONFLICT ("Id") DO NOTHING;

-- Inserir motos de exemplo
INSERT INTO "Motos" ("Id", "Placa", "Modelo", "Ano", "FilialId") VALUES
    ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'ABC1D23', 'Honda CG 160', 2022, '11111111-1111-1111-1111-111111111111'),
    ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'EFG4H56', 'Yamaha Factor 150', 2021, '11111111-1111-1111-1111-111111111111'),
    ('cccccccc-cccc-cccc-cccc-cccccccccccc', 'IJK7L89', 'Honda Biz 125', 2020, '22222222-2222-2222-2222-222222222222'),
    ('dddddddd-dddd-dddd-dddd-dddddddddddd', 'MNO0P12', 'Yamaha XTZ 150', 2023, '22222222-2222-2222-2222-222222222222'),
    ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', 'QRS3T45', 'Honda Titan 160', 2022, '33333333-3333-3333-3333-333333333333')
ON CONFLICT ("Id") DO NOTHING;

-- Inserir manutenções de exemplo
INSERT INTO "Manutencoes" ("Id", "MotoId", "Data", "Descricao", "Custo") VALUES
    ('ffffffff-ffff-ffff-ffff-ffffffffffff', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', CURRENT_TIMESTAMP - INTERVAL '10 days', 'Troca de óleo e filtro', 120.00),
    ('gggggggg-gggg-gggg-gggg-gggggggggggg', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', CURRENT_TIMESTAMP - INTERVAL '5 days', 'Ajuste de corrente e lubrificação', 80.00),
    ('hhhhhhhh-hhhh-hhhh-hhhh-hhhhhhhhhhhh', 'cccccccc-cccc-cccc-cccc-cccccccccccc', CURRENT_TIMESTAMP - INTERVAL '2 days', 'Substituição de pastilha de freio', 150.00),
    ('iiiiiiii-iiii-iiii-iiii-iiiiiiiiiiii', 'dddddddd-dddd-dddd-dddd-dddddddddddd', CURRENT_TIMESTAMP - INTERVAL '15 days', 'Revisão geral dos 10000 km', 250.00),
    ('jjjjjjjj-jjjj-jjjj-jjjj-jjjjjjjjjjjj', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee', CURRENT_TIMESTAMP - INTERVAL '7 days', 'Troca de pneus dianteiro e traseiro', 320.00)
ON CONFLICT ("Id") DO NOTHING;

-- =============================================================================
-- VIEWS ÚTEIS PARA RELATÓRIOS
-- =============================================================================

-- View com resumo de motos por filial
CREATE OR REPLACE VIEW "vw_ResumoMotosFilial" AS
SELECT 
    f."Nome" AS "NomeFilial",
    f."Cidade",
    f."Uf",
    COUNT(m."Id") AS "TotalMotos",
    COUNT(CASE WHEN m."Ano" >= 2022 THEN 1 END) AS "MotosNovas",
    COUNT(CASE WHEN m."Ano" < 2022 THEN 1 END) AS "MotosAntigas"
FROM "Filiais" f
LEFT JOIN "Motos" m ON f."Id" = m."FilialId"
GROUP BY f."Id", f."Nome", f."Cidade", f."Uf"
ORDER BY f."Nome";

COMMENT ON VIEW "vw_ResumoMotosFilial" IS 'Resumo da quantidade de motos por filial, separadas por idade';

-- View com histórico de manutenções
CREATE OR REPLACE VIEW "vw_HistoricoManutencoes" AS
SELECT 
    f."Nome" AS "NomeFilial",
    m."Placa",
    m."Modelo",
    man."Data",
    man."Descricao",
    man."Custo"
FROM "Manutencoes" man
INNER JOIN "Motos" m ON man."MotoId" = m."Id"
INNER JOIN "Filiais" f ON m."FilialId" = f."Id"
ORDER BY man."Data" DESC;

COMMENT ON VIEW "vw_HistoricoManutencoes" IS 'Histórico completo de manutenções com informações da moto e filial';

-- =============================================================================
-- FUNÇÕES ÚTEIS
-- =============================================================================

-- Função para calcular custo total de manutenções por moto
CREATE OR REPLACE FUNCTION fn_CustoTotalManutencoes(moto_id uuid)
RETURNS numeric(10,2) AS $$
BEGIN
    RETURN COALESCE(
        (SELECT SUM("Custo") FROM "Manutencoes" WHERE "MotoId" = moto_id),
        0
    );
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION fn_CustoTotalManutencoes(uuid) IS 'Calcula o custo total de manutenções para uma moto específica';

-- =============================================================================
-- ESTATÍSTICAS E INFORMAÇÕES DO BANCO
-- =============================================================================

-- Exibir estatísticas das tabelas
DO $$
BEGIN
    RAISE NOTICE '=== ESTATÍSTICAS DO BANCO NEOMOTO ===';
    RAISE NOTICE 'Total de Filiais: %', (SELECT COUNT(*) FROM "Filiais");
    RAISE NOTICE 'Total de Motos: %', (SELECT COUNT(*) FROM "Motos");
    RAISE NOTICE 'Total de Manutenções: %', (SELECT COUNT(*) FROM "Manutencoes");
    RAISE NOTICE 'Custo Total de Manutenções: R$ %', (SELECT COALESCE(SUM("Custo"), 0) FROM "Manutencoes");
END $$;

-- =============================================================================
-- SCRIPT CONCLUÍDO
-- Data de criação: 2024-09-24
-- Versão: 1.0
-- Descrição: DDL completo do sistema NeoMoto para gestão de frota de motos
-- =============================================================================
