#!/bin/bash

# Skript zur Überprüfung von Firewalls unter Debian 12
# Muss mit sudo ausgeführt werden für vollständige Informationen

# Farbdefinitionen für die Ausgabe
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funktion zur Überprüfung der sudo-Rechte
check_sudo() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Warnung: Dieses Skript sollte mit sudo ausgeführt werden für vollständige Informationen${NC}"
        read -p "Möchten Sie trotzdem fortfahren? (j/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Jj]$ ]]; then
            exit 1
        fi
    fi
}

# Funktion zur Überprüfung von iptables/nftables
check_iptables_nft() {
    echo -e "\n${YELLOW}=== Prüfe iptables/nftables ===${NC}"
    
    # Prüfe ob iptables oder nftables installiert ist
    if command -v iptables &> /dev/null || command -v nft &> /dev/null; then
        echo -e "Firewall-Tools gefunden:"
        command -v iptables && iptables --version
        command -v nft && nft --version
        
        # Aktive Regeln prüfen
        echo -e "\n${YELLOW}Aktive Regeln:${NC}"
        
        # iptables-Regeln
        if command -v iptables &> /dev/null; then
            echo -e "\n${YELLOW}iptables-Regeln:${NC}"
            iptables -L -n -v --line-numbers
        else
            echo -e "${RED}iptables nicht installiert${NC}"
        fi
        
        # nftables-Regeln
        if command -v nft &> /dev/null; then
            echo -e "\n${YELLOW}nftables-Regeln:${NC}"
            nft list ruleset
        else
            echo -e "${RED}nftables nicht installiert${NC}"
        fi
        
        # Überprüfe ob Firewall aktiv ist
        local active=0
        if command -v iptables &> /dev/null; then
            if iptables -L INPUT | grep -qv "Chain INPUT (policy ACCEPT)"; then
                active=1
            fi
        fi
        
        if command -v nft &> /dev/null; then
            if nft list ruleset | grep -q "hook input"; then
                active=1
            fi
        fi
        
        if [ $active -eq 1 ]; then
            echo -e "\n${GREEN}Eine Firewall ist aktiv konfiguriert${NC}"
        else
            echo -e "\n${YELLOW}Firewall-Tools installiert, aber keine aktiven Regeln gefunden${NC}"
        fi
    else
        echo -e "${RED}Weder iptables noch nftables sind installiert${NC}"
    fi
}

# Funktion zur Überprüfung von UFW
check_ufw() {
    echo -e "\n${YELLOW}=== Prüfe UFW (Uncomplicated Firewall) ===${NC}"
    
    if command -v ufw &> /dev/null; then
        echo -e "UFW installiert: $(ufw --version)"
        
        ufw_status=$(ufw status 2>&1)
        if echo "$ufw_status" | grep -q "Status: active"; then
            echo -e "\n${GREEN}UFW ist aktiv${NC}"
            echo -e "\n${YELLOW}UFW Regeln:${NC}"
            ufw status numbered
        else
            echo -e "\n${YELLOW}UFW ist installiert aber inaktiv${NC}"
        fi
    else
        echo -e "${RED}UFW ist nicht installiert${NC}"
    fi
}

# Funktion zur Überprüfung von firewalld
check_firewalld() {
    echo -e "\n${YELLOW}=== Prüfe firewalld ===${NC}"
    
    if command -v firewalld &> /dev/null || systemctl list-unit-files | grep -q firewalld; then
        echo -e "firewalld gefunden"
        
        if systemctl is-active firewalld &> /dev/null; then
            echo -e "\n${GREEN}firewalld ist aktiv${NC}"
            echo -e "\n${YELLOW}Aktive Zonen:${NC}"
            firewall-cmd --list-all-zones
        else
            echo -e "\n${YELLOW}firewalld ist installiert aber inaktiv${NC}"
        fi
    else
        echo -e "${RED}firewalld ist nicht installiert${NC}"
    fi
}

# Funktion zur Überprüfung von nftables Service
check_nftables_service() {
    echo -e "\n${YELLOW}=== Prüfe nftables Service ===${NC}"
    
    if systemctl list-unit-files | grep -q nftables; then
        echo -e "nftables Service gefunden"
        
        if systemctl is-active nftables &> /dev/null; then
            echo -e "\n${GREEN}nftables Service ist aktiv${NC}"
        else
            echo -e "\n${YELLOW}nftables Service ist installiert aber inaktiv${NC}"
        fi
    else
        echo -e "${RED}nftables Service ist nicht installiert${NC}"
    fi
}

# Hauptfunktion
main() {
    echo -e "${YELLOW}\n=== Debian 12 Firewall Checker ===${NC}"
    echo -e "Datum: $(date)\n"
    
    check_sudo
    check_iptables_nft
    check_ufw
    check_firewalld
    check_nftables_service
    
    echo -e "\n${YELLOW}=== Zusammenfassung ===${NC}"
    
    # Installationsstatus
    echo -n "Firewall-Tools installiert: "
    if command -v iptables &> /dev/null || command -v nft &> /dev/null || command -v ufw &> /dev/null || command -v firewalld &> /dev/null; then
        echo -e "${GREEN}Ja${NC}"
    else
        echo -e "${RED}Nein${NC}"
    fi
    
    # Aktivstatus
    echo -n "Firewall aktiv: "
    if (command -v iptables &> /dev/null && iptables -L INPUT | grep -qv "Chain INPUT (policy ACCEPT)") || \
       (command -v nft &> /dev/null && nft list ruleset | grep -q "hook input") || \
       (command -v ufw &> /dev/null && ufw status | grep -q "Status: active") || \
       (command -v firewalld &> /dev/null && systemctl is-active firewalld &> /dev/null); then
        echo -e "${GREEN}Ja${NC}"
    else
        echo -e "${RED}Nein${NC}"
    fi
    
    echo -e "\n${YELLOW}=== Empfehlung ===${NC}"
    echo -e "Für besseren Schutz sollten Sie eine Firewall aktivieren:"
    echo -e "1. UFW (einfach): sudo apt install ufw && sudo ufw enable"
    echo -e "2. nftables (fortgeschritten): sudo apt install nftables"
    echo -e "3. firewalld (für komplexe Setups): sudo apt install firewalld"
}

main
