#!/usr/bin/env bash
#
# ---------------------------------------------------------------------
# Script Name: nc-scan.sh
# Date: 10/09/2023
#
# ---------------------------------------------------------------------
# Descrição:  Um script Bash simples  que executa uma varredura 
#             em um bloco de endereços IP em busca de portas abertas. 
#             Ele gera um relatório dos endereços IP com as portas 
#             acessíveis dentro do intervalo de endereços IP especificado. 
#             Os resultados são salvos em um arquivo.
#
# --------------------------------------------------------------------- 
# Historico:
# 
# (V1.0) - Manual da ferramenta / Uso
#	 - Varredura de portas em bloco IP 
#	 - opçoes de saida
# 	 - relatório detalhado 
# ---------------------------------------------------------------------

# Manual da ferramenta
exibir_ajuda () {
	echo "NOME:"
	echo "  nc-scan.sh - Varredura de portas TCP/UDP em bloco /24 com relatório"
	echo ""
	echo "SINOPSE:"
	echo "  nc-scan.sh -b bloco_ip [-r intervalo] [-h]"
	echo ""
	echo "OPÇÕES:"
	echo "  -b bloco_ip   Bloco de IP a ser escaneado (exemplo: 192.168.1.0/24)"
	echo "  -r intervalo  Intervalo de portas (exemplo: 1-65535) (opcional)"
	echo "  -h            Exibir ajuda"
	echo ""
	echo "USO:"
	echo "  - Varredura de portas em um bloco de IPs (intervalo padrão 1-65535)"
	echo "    bash ./nc-scan.sh -b 192.168.0.0/24"
	echo ""
	echo "  - Varredura de IPs em um bloco com intervalo específico de portas."
	echo "    bash ./nc-scan.sh -b 192.168.0.0/24 -r 20-2000"
	exit 1
}

# Manual de opções/uso da ferramenta
ajuda_uso=$(exibir_ajuda | awk ' NR >= 7 && NR <= 17')

# Verifique se o Netcat (nc) está instalado no sistema.
if ! command -v nc &>/dev/null; then
	read -p "O script requer que nc (Netcat) esteja instalado, deseja instalar? [S/n]: " OPT
	case "$OPT" in
		[Ss]*)
			sudo apt update
			sudo apt install netcat-openbsd -y
			exit 1
			;;
		*)
			exit 1
			;;
	esac
fi

# Define os valores padrões
bloco=""
range=""

# Analisa as opções da linha de comando
while getopts ":b:r:h" opcao;do
	case "$opcao" in
		b) bloco="$OPTARG";;
		r) range="$OPTARG";;
		h) exibir_ajuda;;
	#	\?) echo "ERRO opção inválida: $OPTARG";;
		*) echo -e "Erro: Parametro inválido\n"; echo "$ajuda_uso"; exit 1 ;;
	esac
done

# Trata saida de erros
if [ $# -eq 0 ];then
	echo "$ajuda_uso"
	exit 1
fi

if [ -z $bloco ] && [ $# -eq 1 ];then
	echo -e "Erro: nenhum bloco especificado!\n"
	echo "$ajuda_uso"
	exit 1
fi

if [ -n "$bloco" ] && [ $# -eq 3 ];then
	echo -e "Erro: Range de portas não especificado\n"
	echo "$ajuda_uso"
	exit 1
fi

# Diretório onde os resultados das varreduras serão armazenados.
SCAN_DIR="$HOME/scans"

# Nome do arquivo de varredura com data/hora
ARQ_SCAN="scan_$(date +%d%m%Y%H%M).txt"

# Caminho completo até o arquivo de varredura
OUT_SCAN="$SCAN_DIR/$ARQ_SCAN"

if [ ! -d $SCAN_DIR ];then
	mkdir $SCAN_DIR
fi

# Função para validar um bloco de endereços ip /24
valida_bloco() {

	local bloco="$1"  
	local padrao="^[0-9]{1,3}.[0-9]{1,3}.[0-9]{1,3}.0\/24$"  # Padrão para a notação CIDR /24

  # Verifica se o bloco de sub-rede segue o padrão
  if [[ ! $bloco =~ $padrao ]]; then
	  echo -e "Erro:  Bloco de sub-rede inválido: $bloco"
	  echo -e "       Permitido apenas sub-redes /24 \n"
	  echo "$ajuda_uso"
	  exit 1
  fi

  local port_inicial=$(echo $range | awk -F '[-]' '{print $1}')
  local port_final=$(echo $range | awk -F '[-]' '{print $2}')

  # Executa a varredura de portas dentro do intervalo especificado em um bloco de IPs.
  executa_bloco_range(){
	  prange_inicial=$1
	  prange_final=$2
	  local ip_saida=$(echo $bloco | awk -F '[.]' '{print $1"."$2"."$3"."}')
	  for octeto in $(seq 1 254); do
		  bloco_ip="$ip_saida$octeto"
		  for port in $(seq $prange_inicial $prange_final);do
			  nc -zv "$bloco_ip" "$port" 2>&1 | awk '/succeeded/{print $3,$4,$5,$6}' >> $OUT_SCAN
		  done
	  done
  }

  if [ -n "$bloco" ] && [ -n "$range" ];then
	  executa_bloco_range "$port_inicial $port_final"
  else
	  executa_bloco_range 1 65535
  fi
}

# Main
valida_bloco "$bloco" 
