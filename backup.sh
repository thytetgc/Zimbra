#!/bin/bash
clear

echo [`date +'%d.%m.%Y %H:%M'`] Iniciando Backup ...
         echo "+-------------------------------------------------+OK"

echo [`date +'%d.%m.%Y %H:%M'`] Exportar configuração atual [1/4] ...
su - zimbra -c '/Scripts_Zimbra/_Export_Dados'
         echo "+-------------------------------------------------+OK"

# Diretórios para fazer backup, /etc /root /var
source='/opt/zimbra/backup/'

# Senha para compactação
senha='q|?a)N2#8d^JS^lm2EF29g*D$l#}aIu('

# Pasta para Excluir do backup
#exclude=''

# Diretório de backup, /Backup
#backup=/Backup/"`hostname`"
backup=/Backup
mkdir -p $backup

# Definição de Variavel
datum=$(date +'%Y%m%d')
dateinametar=$backup/"`hostname -a`"-backup$datum.tar
dateinamezip=$backup/"`hostname -a`"-backup$datum.zip

# -----------------------------------------------------
function f_delFiles()
# -----------------------------------------------------
# $1 Diretório de backup
{
  loeschdatum=$(date --date='7 days ago' +'%Y%m%d')
  rm $1/"`hostname -a`"-backup$loeschdatum.*
}

echo [`date +'%d.%m.%Y %H:%M'`] Exclundo arquivos em $backup, com mais de 7 dias [2/4] ...
f_delFiles $backup
         echo "+-------------------------------------------------+OK"

echo [`date +'%d.%m.%Y %H:%M'`] Salve $source em $dateiname [3/4] ...
tar -Pcf $dateinametar $source
zip -P $senha -r $dateinamezip $dateinametar
rm $dateinametar
         echo "+-------------------------------------------------+OK"

echo [`date +'%d.%m.%Y %H:%M'`] Sincronizar com armazenamento online [4/4] ...
bash /Scripts/upload.sh
         echo "+-------------------------------------------------+OK"

echo [`date +'%d.%m.%Y %H:%M'`] Pronto!
         echo "+-------------------------------------------------+OK"
