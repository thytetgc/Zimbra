#!/bin/bash

# Obter a senha do MySQL do Zimbra
MYSQL_PASS=$( /opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password )

# Verificar se a senha foi obtida corretamente
if [ -z "$MYSQL_PASS" ]; then
    echo "Erro: Não foi possível obter a senha do MySQL."
    exit 1
fi

# Conectar ao MySQL e criar a tabela schema_version
mysql -u zimbra -p"$MYSQL_PASS" -e "
    CREATE TABLE IF NOT EXISTS zimbra.schema_version (
        name VARCHAR(64) NOT NULL PRIMARY KEY,
        value VARCHAR(64) NOT NULL
    );

    -- Inserir a versão 113 na tabela schema_version (caso não exista)
    INSERT INTO zimbra.schema_version (name, value)
    SELECT 'version', '113'
    WHERE NOT EXISTS (SELECT 1 FROM zimbra.schema_version WHERE name = 'version');
    
    -- Verificar a versão inserida
    SELECT * FROM zimbra.schema_version;
"

# Verificar se o comando foi executado com sucesso
if [ $? -eq 0 ]; then
    echo "A tabela schema_version foi criada e a versão foi configurada com sucesso para 113."
else
    echo "Erro ao executar o script de criação da tabela schema_version."
    exit 1
fi
