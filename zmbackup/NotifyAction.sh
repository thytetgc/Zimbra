#!/bin/bash
################################################################################
# Mail Notification
################################################################################

################################################################################
# notify_begin: Function to notify when the backup process began through e-mail.
# Options:
#    $1 -> Inform the backup's session name;
#    $2 -> Infomr the type of backup is in execution.
################################################################################
function notify_begin()
{
  if [[ "$ENABLE_EMAIL_NOTIFY" == "all" || "$ENABLE_EMAIL_NOTIFY" == "start" ]]; then
    printf "Subject: Zmbackup - Rotina de backup para $1 Começou em $(date)" > $MESSAGE
    printf "\nSaudações Administrador," >> $MESSAGE
    printf "\n\nEsta é uma mensagem automática para informar que o processo para o backup $2 agendado começou agora." >> $MESSAGE
    printf " Dependendo da quantidade de contas e/ou dados a serem copiados, esse processo pode levar algumas horas antes da conclusão." >> $MESSAGE
    printf "\nNão se preocupe, iremos informá-lo quando o processo terminar." >> $MESSAGE
    printf "\n\nSaudações," >> $MESSAGE
    printf "\nZmbackup Team" >> $MESSAGE
    ERR=$((sendmail -f $EMAIL_SENDER $EMAIL_NOTIFY < $MESSAGE ) 2>&1)
    if [[ $? -eq 0 ]]; then
      logger -i -p local7.info "Zmbackup: Mensagem enviada para $EMAIL_NOTIFY para notificar sobre a rotina de backup iniciada."
    else
      logger -i -p local7.info "Zmbackup: Não é possível enviar e-mail para $EMAIL_NOTIFY - $ERR."
    fi
  fi
}


################################################################################
# notify_finishOK: Function to notify when the backup process finish - SUCCESS.
# Options:
#    $1 -> Inform the backup's session name;
#    $2 -> Inform the type of backup is in execution;
#    $3 -> Inform the status of the bacup. Valid Options:
#        - FAILURE - For some reason Zmbackup can't conclude this session;
#        - SUCCESS - Zmbackup concluded the session with no problem;
#        - CANCELED - The administrator canceled the session for some reason.
################################################################################
function notify_finish()
{
  if [[ "$ENABLE_EMAIL_NOTIFY" == "all" ]] || [[ "$ENABLE_EMAIL_NOTIFY" == "finish" && "$3" == "SUCCESS" ]] || [[ "$ENABLE_EMAIL_NOTIFY" == "error" && "$3" == "FAILURE" ]] ; then

    # Loading the variables
    if [[ "$3" == "SUCCESS" ]]; then
      SIZE=$(du -h $WORKDIR/$1 2> /dev/null | awk {'print $1'}; exit ${PIPESTATUS[0]})
      if [[ $? -eq 0 ]]; then
        if [[ "$1" == "mbox"* ]]; then
          QTDE=$(ls $WORKDIR/$1/*.tgz | wc -l)
        else
          QTDE=$(ls $WORKDIR/$1/*.ldiff | wc -l)
        fi
      else
        SIZE=0
        QTDE=0
      fi
    else
      SIZE=0
      QTDE=0
    fi

    # The message
    printf "Subject: Zmbackup - Rotina de backup para $1 Completo em $(date) - $3" > $MESSAGE
    printf "\nSaudações Administrador," >> $MESSAGE
    printf "\n\nEsta é uma mensagem automática para informar que o processo para o backup $2 agendado terminou agora." >> $MESSAGE
    printf "\nAqui algumas informações sobre esta sessão:" >> $MESSAGE
    printf "\n\nTamanho: $SIZE" >> $MESSAGE
    printf "\nContas: $QTDE" >> $MESSAGE
    printf "\nStatus: $3" >> $MESSAGE
    printf "\n\nSaudações," >> $MESSAGE
    printf "\nZmbackup Team" >> $MESSAGE
    printf "\n\nResumo dos arquivos:\n" >> $MESSAGE
    cat $TEMPSESSION >> $MESSAGE
    ERR=$((sendmail -f $EMAIL_SENDER $EMAIL_NOTIFY < $MESSAGE ) 2>&1)
    if [[ $? -eq 0 ]]; then
      logger -i -p local7.info "Zmbackup: Mensagem enviada para $EMAIL_NOTIFY para notificar sobre a conclusão da rotina de backup."
    else
      logger -i -p local7.info "Zmbackup: Não é possível enviar e-mail para $EMAIL_NOTIFY - $ERR."
    fi
  fi
}
