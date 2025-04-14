#!/bin/bash

# Definindo o arquivo de log no diretório do Zimbra
LOG_FILE="/opt/zimbra/log/zimbra_mobile_operator_check.log"

# Função para registrar no log
log_message() {
    echo "$(date '+%a %b %d %T %Y') - $1" | tee -a "$LOG_FILE"
}

# Verifica se o script tem permissão para escrever no log
if ! touch "$LOG_FILE" 2>/dev/null; then
  echo "Erro: não é possível escrever em $LOG_FILE. Execute como root ou altere o caminho do log."
  exit 1
fi

# Iniciando o processo
log_message "Iniciando validação da coluna mobile_operator"

# Parando todos os serviços do Zimbra
log_message "Parando todos os serviços do Zimbra..."
su - zimbra -c "zmcontrol stop"

# Iniciando apenas o MySQL
log_message "Iniciando apenas o MySQL..."
su - zimbra -c "mysql.server start"

# Backup da tabela mobile_devices
log_message "Fazendo backup da tabela mobile_devices para /opt/zimbra/log/mobile_devices_backup.sql..."
su - zimbra -c "/opt/zimbra/bin/mysql -u zimbra -p\$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra -e 'SELECT * INTO OUTFILE \"/opt/zimbra/log/mobile_devices_backup.sql\" FROM mobile_devices;'"

# FLUSH da tabela mobile_devices
log_message "FLUSH TABLES mobile_devices..."
su - zimbra -c "/opt/zimbra/bin/mysql -u zimbra -p\$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra -e 'FLUSH TABLES mobile_devices;'"

# Verificando e tentando DROPAR a coluna mobile_operator
log_message "Tentando DROP da coluna mobile_operator..."
su - zimbra -c "/opt/zimbra/bin/mysql -u zimbra -p\$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra -e 'ALTER TABLE mobile_devices DROP COLUMN IF EXISTS mobile_operator;'"
log_message "Verificando se houve warnings..."
su - zimbra -c "/opt/zimbra/bin/mysql -u zimbra -p\$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra -e 'SHOW WARNINGS;'"

# Tentando ADICIONAR a coluna mobile_operator
log_message "Tentando ADD da coluna mobile_operator..."
su - zimbra -c "/opt/zimbra/bin/mysql -u zimbra -p\$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra -e 'ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);'"
log_message "Verificando se houve warnings..."
su - zimbra -c "/opt/zimbra/bin/mysql -u zimbra -p\$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra -e 'SHOW WARNINGS;'"

# Validando se a coluna pode ser DROPADA novamente
log_message "Validando se a coluna pode ser DROPADA novamente..."
su - zimbra -c "/opt/zimbra/bin/mysql -u zimbra -p\$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra -e 'ALTER TABLE mobile_devices DROP COLUMN IF EXISTS mobile_operator;'"
log_message "Verificando se houve warnings..."
su - zimbra -c "/opt/zimbra/bin/mysql -u zimbra -p\$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra -e 'SHOW WARNINGS;'"

# Reiniciando os serviços do Zimbra
log_message "Reiniciando os serviços do Zimbra..."
su - zimbra -c "zmcontrol start"

log_message "Validação concluída com sucesso."
