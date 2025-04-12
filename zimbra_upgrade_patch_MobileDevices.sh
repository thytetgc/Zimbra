#!/bin/bash

# Função para checar se a coluna 'mobile_operator' existe
check_column_exists() {
    echo "Verificando se a coluna 'mobile_operator' existe na tabela 'mobile_devices'..."
    result=$(/opt/zimbra/bin/mysql -u zimbra -p$(/opt/zimbra/bin/zmlocalconfig -s -m nokey mysql_root_password | awk '{print $2}') -e "SHOW COLUMNS FROM zimbra.mobile_devices LIKE 'mobile_operator';" -s -N)

    if [[ -z "$result" ]]; then
        echo "Coluna 'mobile_operator' não existe. Adicionando..."
        add_column
    else
        echo "Coluna 'mobile_operator' já existe. Nenhuma ação necessária."
    fi
}

# Função para adicionar a coluna 'mobile_operator'
add_column() {
    /opt/zimbra/bin/mysql -u zimbra -p$(/opt/zimbra/bin/zmlocalconfig -s -m nokey mysql_root_password | awk '{print $2}') -e "ALTER TABLE zimbra.mobile_devices ADD COLUMN mobile_operator VARCHAR(512);"
    if [[ $? -eq 0 ]]; then
        echo "Coluna 'mobile_operator' adicionada com sucesso!"
    else
        echo "Erro ao adicionar a coluna 'mobile_operator'."
        exit 1
    fi
}

# Função para atualizar o schema para versão 113
update_schema_version() {
    echo "Atualizando o schema para versão 113..."
    /opt/zimbra/bin/mysql -u zimbra -p$(/opt/zimbra/bin/zmlocalconfig -s -m nokey mysql_root_password | awk '{print $2}') -e "UPDATE zimbra.schema_version SET value = '113' WHERE name = 'version';"
    if [[ $? -eq 0 ]]; then
        echo "Schema atualizado para versão 113 com sucesso!"
    else
        echo "Erro ao atualizar o schema."
        exit 1
    fi
}

# Executa as funções
check_column_exists
update_schema_version

echo "Preparação para upgrade concluída. Agora você pode rodar o instalador do Zimbra."
