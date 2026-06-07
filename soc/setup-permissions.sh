#!/bin/bash
# Relancer ce script après chaque restart de Grafana
# Les permissions de dossiers ne se provisionnent pas via fichier dans Grafana OSS

GRAFANA_URL="http://198.199.70.48:3000"
ADMIN_PASS="SedadSOC2024!"

echo "Attente Grafana..."
until curl -s -o /dev/null -w "%{http_code}" -u "admin:$ADMIN_PASS" "$GRAFANA_URL/api/org" | grep -q "200"; do
  sleep 3
done
echo "Grafana prêt."

echo ""
echo "Application des permissions de dossiers..."
for pair in "folder-trackpay:1:TrackPay SOC" "folder-financeapp:2:FinanceApp SOC" "folder-nova:3:Nova SSO SOC" "folder-rssbank:4:RSS Bank SOC"; do
  folder_uid="${pair%%:*}"
  rest="${pair#*:}"
  team_id="${rest%%:*}"
  name="${rest#*:}"

  curl -s -X POST \
    -u "admin:$ADMIN_PASS" \
    -H "Content-Type: application/json" \
    -d "{\"items\": [{\"role\": \"Admin\", \"permission\": 4},{\"teamId\": $team_id, \"permission\": 1}]}" \
    "$GRAFANA_URL/api/folders/$folder_uid/permissions" > /dev/null
  echo "  ✓ $name → team $team_id uniquement"
done

echo ""
echo "Permissions appliquées avec succès."
echo "IMPORTANT: Ne pas tester les logins depuis ce script (cause lockout)."
