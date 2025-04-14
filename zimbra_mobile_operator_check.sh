#!/bin/bash

LOG_FILE="/tmp/zimbra_mobile_operator_check.log"
BACKUP_FILE="/tmp/mobile_devices_backup.sql"

echo "[$(date)] Iniciando validação da coluna mobile_operator" | tee $LOG_FILE

echo "[$(date)] Parando todos os serviços do Zimbra..." | tee -a $LOG_FILE
su - zimbra -c "zmcontrol stop"

echo "[$(date)] Iniciando apenas o MySQL..." | tee -a $LOG_FILE
su - zimbra -c "mysql.server start"

MYSQL_CMD="/opt/zimbra/bin/mysql -u zimbra -p$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password) zimbra"

echo "[$(date)] Fazendo backup da tabela mobile_devices para $BACKUP_FILE..." | tee -a $LOG_FILE
$MYSQL_CMD -e "SELECT * FROM mobile_devices INTO OUTFILE '$BACKUP_FILE';"

echo "[$(date)] FLUSH TABLES mobile_devices..." | tee -a $LOG_FILE
$MYSQL_CMD -e "FLUSH TABLES mobile_devices;"
$MYSQL_CMD -e "SHOW WARNINGS;" >> $LOG_FILE

echo "[$(date)] Tentando DROP da coluna mobile_operator..." | tee -a $LOG_FILE
$MYSQL_CMD -e "ALTER TABLE mobile_devices DROP COLUMN IF EXISTS mobile_operator;"
$MYSQL_CMD -e "SHOW WARNINGS;" >> $LOG_FILE

echo "[$(date)] Tentando ADD da coluna mobile_operator..." | tee -a $LOG_FILE
$MYSQL_CMD -e "ALTER TABLE mobile_devices ADD COLUMN mobile_operator VARCHAR(512);"
$MYSQL_CMD -e "SHOW WARNINGS;" >> $LOG_FILE

echo "[$(date)] Validando se pode dropar novamente..." | tee -a $LOG_FILE
$MYSQL_CMD -e "ALTER TABLE mobile_devices DROP COLUMN IF EXISTS mobile_operator;"
$MYSQL_CMD -e "SHOW WARNINGS;" >> $LOG_FILE

echo "[$(date)] Reiniciando serviços do Zimbra..." | tee -a $LOG_FILE
su - zimbra -c "zmcontrol restart"

echo "[$(date)] Script finalizado. Logs em: $LOG_FILE"
