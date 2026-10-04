#!/usr/bin/env bash
set -uo pipefail

export LC_ALL=C
PASS=0
FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        printf '  [OK]   %s\n' "$desc"
        ((PASS += 1))
    else
        printf "  [FAIL] %s (ожидалось: '%s', получено: '%s')\n" "$desc" "$expected" "$actual"
        ((FAIL += 1))
    fi
}

if ! sudo -v; then
    printf 'Не удалось получить права sudo для аудита.\n' >&2
    exit 1
fi

printf 'Аудит конфигурации: %s, %s\n' "$(hostname -f)" "$(date '+%Y-%m-%d %H:%M')"
printf '[1] Служба SSH\n'
ssh_config="$(sudo /usr/sbin/sshd -T)"
check 'Вход от имени root запрещён' 'no' "$(awk '/^permitrootlogin / {print $2}' <<< "$ssh_config")"
check 'Парольная аутентификация отключена' 'no' "$(awk '/^passwordauthentication / {print $2}' <<< "$ssh_config")"
port="$(awk '/^port / {print $2}' <<< "$ssh_config")"
nonstandard_port=no
if [[ "$port" =~ ^[0-9]+$ && "$port" != 22 ]]; then
    nonstandard_port=yes
fi
check 'SSH использует нестандартный порт' 'yes' "$nonstandard_port"
check 'MaxAuthTries равно 3' '3' "$(awk '/^maxauthtries / {print $2}' <<< "$ssh_config")"

printf '[2] Межсетевой экран\n'
check 'Межсетевой экран активен' 'active' "$(sudo ufw status | awk '/^Status:/ {print $2}')"
check 'Входящие соединения по умолчанию запрещены' 'deny' "$(sudo ufw status verbose | awk '/^Default:/ {print $2}')"

printf '[3] Учётные записи\n'
awk -F: '$3 >= 1000 && $3 < 65534 {printf "    %s (uid=%s)\n", $1, $3}' /etc/passwd
printf 'Пройдено: %s, не пройдено: %s\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
