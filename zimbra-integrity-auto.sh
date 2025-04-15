#!/bin/bash

LOGFILE="/opt/zimbra/zimbra-integrity-full.log"
MYSQL="/opt/zimbra/bin/mysql"
MYSQL_PWD=$(/opt/zimbra/bin/zmlocalconfig -s -m nokey zimbra_mysql_password)
DBNAME="zimbra"
ZMMAILBOX="/opt/zimbra/bin/zmmailbox"
ZMPROV="/opt/zimbra/bin/zmprov"
ZM_BLOBCHECK="/opt/zimbra/libexec/zmblobchk"

echo "==== Zimbra FULL AUTO-INTEGRITY CHECK ====" | tee "$LOGFILE"
echo "Início: $(date)" | tee -a "$LOGFILE"

echo -e "\n>> Parando serviços Zimbra exceto MySQL..." | tee -a "$LOGFILE"
zmcontrol stop >> "$LOGFILE" 2>&1
sleep 5

echo -e "\n>> Iniciando MySQL standalone..." | tee -a "$LOGFILE"
/opt/zimbra/libexec/zmmysqld >/dev/null 2>&1 &
sleep 10

### DATABASE CHECK
echo -e "\n==============================" | tee -a "$LOGFILE"
echo ">> 1. VERIFICAÇÃO E REPARO DO BANCO DE DADOS" | tee -a "$LOGFILE"
echo "==============================" | tee -a "$LOGFILE"

TABLES=$($MYSQL -u root --password="$MYSQL_PWD" -e "SHOW TABLES IN $DBNAME;" | tail -n +2)

for TABLE in $TABLES; do
    echo "=== TABELA: $TABLE ===" | tee -a "$LOGFILE"
    $MYSQL -u root --password="$MYSQL_PWD" -e "CHECK TABLE $DBNAME.$TABLE;" >> "$LOGFILE" 2>&1
    $MYSQL -u root --password="$MYSQL_PWD" -e "REPAIR TABLE $DBNAME.$TABLE;" >> "$LOGFILE" 2>&1
    $MYSQL -u root --password="$MYSQL_PWD" -e "ANALYZE TABLE $DBNAME.$TABLE;" >> "$LOGFILE" 2>&1
    $MYSQL -u root --password="$MYSQL_PWD" -e "OPTIMIZE TABLE $DBNAME.$TABLE;" >> "$LOGFILE" 2>&1
    echo "--------------------------" | tee -a "$LOGFILE"
done

echo -e "\n>> Encerrando MySQL standalone..." | tee -a "$LOGFILE"
killall mysqld >> "$LOGFILE" 2>&1
sleep 5

echo -e "\n>> Reiniciando Zimbra..." | tee -a "$LOGFILE"
zmcontrol start >> "$LOGFILE" 2>&1
sleep 10

### BLOBS CHECK + AUTO RECOVER
echo -e "\n==============================" | tee -a "$LOGFILE"
echo ">> 2. VERIFICAÇÃO E REPARO DE BLOBs (MENSAGENS)" | tee -a "$LOGFILE"
echo "==============================" | tee -a "$LOGFILE"

$ZM_BLOBCHECK -m all --recover >> "$LOGFILE" 2>&1

### INDEX CHECK + AUTO REINDEX
echo -e "\n==============================" | tee -a "$LOGFILE"
echo ">> 3. VERIFICAÇÃO E REINDEXAÇÃO AUTOMÁTICA" | tee -a "$LOGFILE"
echo "==============================" | tee -a "$LOGFILE"

MAILBOXES=$($ZMPROV -l gaa)

for MBOX in $MAILBOXES; do
    echo "-> Verificando index para: $MBOX" | tee -a "$LOGFILE"
    RESULT=$($ZMMAILBOX -z -m "$MBOX" verifyIndex 2>&1)
    echo "$RESULT" >> "$LOGFILE"
    
    if echo "$RESULT" | grep -q "ERROR"; then
        echo "⚠️ Problema de índice encontrado. Reindexando $MBOX..." | tee -a "$LOGFILE"
        $ZMMAILBOX -z -m "$MBOX" reIndex >> "$LOGFILE" 2>&1
    else
        echo "✔️ Índice OK para $MBOX" | tee -a "$LOGFILE"
    fi
done

echo -e "\n==============================" | tee -a "$LOGFILE"
echo ">> FINALIZAÇÃO" | tee -a "$LOGFILE"
echo "==============================" | tee -a "$LOGFILE"
echo "Término: $(date)" | tee -a "$LOGFILE"

echo ""
echo "✅ Verificações e reparos completos! Log salvo em: $LOGFILE"
